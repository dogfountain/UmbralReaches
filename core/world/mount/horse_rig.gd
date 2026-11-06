extends Node3D
## A horse's body (art pass): the skinned glTF built by tools/blender/horse_build.py, its one baked
## atlas as a StandardMaterial3D, and a procedural gait on its Skeleton3D, driven from a stride phase.
## Walk, trot and gallop are blended by speed; each hoof follows a path (a stance that slides back, a
## swing that lifts and reaches), a two-bone solve bends knee and hock, the back drops to keep the
## hooves on the ground, the head nods, the mane and tail trail, the lantern swings.
## Load by path (no class_name):  const HorseRig := preload("res://core/world/mount/horse_rig.gd")
##   rig = HorseRig.new(); rig.setup("palfrey", DB.BREEDS["palfrey"]); add_child(rig)
##   rig.pose(phase, speed, graze, dt)      (phase in radians, one stride per TAU)
##   rig.freq(speed)                         (strides per second at a speed: advance the phase by TAU * it)

const LEGS := ["fl", "fr", "hl", "hr"]
## leg phase offsets (fraction of a stride) in LEGS order, duty (stance share), reach (m, half sweep),
## lift (m), and the stride length (m) of each gait
const GAITS := {
	"walk": {"off": [0.25, 0.75, 0.0, 0.5], "duty": 0.66, "lift": 0.075, "stride": 1.95, "reach": 0.34},
	"trot": {"off": [0.0, 0.5, 0.5, 0.0], "duty": 0.46, "lift": 0.13, "stride": 3.4, "reach": 0.42},
	"gallop": {"off": [0.52, 0.64, 0.0, 0.12], "duty": 0.3, "lift": 0.2, "stride": 5.4, "reach": 0.5},
}
const BONES := ["root", "hips", "barrel", "chest", "neck1", "neck2", "neck3", "head", "ear_r", "ear_l", "tail0", "tail1", "tail2", "tail3",
	"lantern", "mane1", "mane2", "mane3", "fl_up", "fl_low", "fl_fet", "fr_up", "fr_low", "fr_fet", "hl_up", "hl_low", "hl_fet", "hr_up", "hr_low", "hr_fet"]

static var _mats := {}

var breed := ""
## West marches: a breed that wears another breed's textures (the Weir Cob: the garron's, dyed dun in material())
const TEX_ALIAS := {"weir_cob": "garron"}
var skel: Skeleton3D
var mesh_inst: MeshInstance3D
var last_dy := 0.0                     ## the back's drop this frame (m): the rider rides it
var walk_s := 2.4
var trot_s := 6.0
var gallop_s := 10.0
var size := 1.0                        ## withers height over the palfrey's: strides, lifts
var _bi := {}                          ## bone name -> index
var _rest_g := {}                      ## bone name -> rest global basis (skeleton space)
var _rest_p := {}                      ## bone name -> rest global origin
var _rest_l := {}                      ## bone name -> rest local position
var _par := {}                         ## bone name -> parent name ("" none)
var _wrot := {}                        ## bone name -> its world rotation this pose (scratch)
## The leap, set by horse.gd before each pose: `air` 1 while off the ground, `vy` its vertical speed
## (+ climbing), `gather` 0..1 the crouch before the push-off, `land` 0..1 the squat after touchdown.
var air := 0.0
var vy := 0.0
var gather := 0.0
var land := 0.0
var _fold_f := 0.0                     ## extra pastern fold on the forelegs in the leap
var _fold_h := 0.0
var _air_w := 0.0                      ## air eased 0..1 (the legs blend into and out of the leap pose)
var _t := 0.0
var _flick := 0.0
var _flick_t := 3.0
var _lan := Vector2.ZERO               ## lantern angle (x fore-aft, z side) and velocity
var _lan_v := Vector2.ZERO
var _prev_dy := 0.0
var _seed := 0.0
var _legs := {}                        ## leg -> {up, low, fet, hip, knee, fet_p, toe, l1, l2, sign}


func setup(b: String, d: Dictionary) -> void:
	breed = b
	walk_s = float(d.walk)
	trot_s = float(d.trot)
	gallop_s = float(d.gallop)
	size = float(d.get("size", 1.0))
	_seed = float(hash(b) % 1000) * 0.01
	var ps := load(String(d.model)) as PackedScene
	var root := ps.instantiate()
	add_child(root)
	skel = _find(root, "Skeleton3D") as Skeleton3D
	mesh_inst = _find(root, "MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		mesh_inst.material_override = material(b)
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_inst.extra_cull_margin = 1.5
		mesh_inst.visibility_range_end = 120.0
	if skel == null:
		return
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		_bi[n] = i
	for n: String in _bi:
		var i: int = _bi[n]
		var gp := skel.get_bone_global_rest(i)
		_rest_g[n] = gp.basis
		_rest_p[n] = gp.origin
		_rest_l[n] = skel.get_bone_rest(i).origin
		var p := skel.get_bone_parent(i)
		_par[n] = skel.get_bone_name(p) if p >= 0 else ""
	for l: String in LEGS:
		var up := l + "_up"
		var low := l + "_low"
		var fet := l + "_fet"
		if not (_bi.has(up) and _bi.has(low) and _bi.has(fet)):
			continue
		var hip: Vector3 = _rest_p[up]
		var knee: Vector3 = _rest_p[low]
		var fp: Vector3 = _rest_p[fet]
		# which side of the hip->fetlock line the knee sits (front: forward, hind: behind)
		var line := fp - hip
		var side := signf((knee - hip).z * line.y - (knee - hip).y * line.z)
		_legs[l] = {"up": up, "low": low, "fet": fet, "hip": hip, "knee": knee, "fet_p": fp, "l1": (knee - hip).length(), "l2": (fp - knee).length(), "side": side}


static func material(b: String) -> StandardMaterial3D:
	if _mats.has(b):
		return _mats[b]
	var m := StandardMaterial3D.new()
	var pre := "res://art/textures/horse_%s_" % String(TEX_ALIAS.get(b, b))
	m.albedo_texture = load(pre + "albedo.png")
	m.normal_enabled = true
	m.normal_texture = load(pre + "normal.png")
	m.normal_scale = 1.0
	var orm := load(pre + "orm.png") as Texture2D
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = orm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 1.0
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission_texture = load(pre + "emit.png")
	m.emission_energy_multiplier = 1.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED          # hair locks are one-sided ribbons
	m.rim_enabled = true
	m.rim = 0.2
	m.rim_tint = 0.4
	if b == "weir_cob":                                    # --- west marches --- a warm dun over the garron's coat
		m.albedo_color = Color(1.14, 0.98, 0.8)
	_mats[b] = m
	return m


static func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null


## Strides per second at `speed` (the gait's stride length grows with speed; at a standstill nothing).
func freq(speed: float) -> float:
	var g := _blend(speed)
	return speed / maxf(float(g.stride) * size, 0.5)


## The gait parameters at a speed: walk below `walk_s`, blending to trot, then to gallop.
func _blend(speed: float) -> Dictionary:
	var a: Dictionary
	var b: Dictionary
	var t: float
	if speed <= walk_s:
		return {"off": GAITS.walk.off, "duty": GAITS.walk.duty, "lift": float(GAITS.walk.lift) * clampf(speed / walk_s, 0.25, 1.0), "stride": GAITS.walk.stride,
			"reach": float(GAITS.walk.reach) * clampf(speed / walk_s, 0.15, 1.0)}
	if speed <= trot_s:
		a = GAITS.walk
		b = GAITS.trot
		t = smoothstep(walk_s, walk_s + (trot_s - walk_s) * 0.55, speed)
	else:
		a = GAITS.trot
		b = GAITS.gallop
		t = smoothstep(trot_s, trot_s + (gallop_s - trot_s) * 0.7, speed)
	var off := []
	for i in 4:
		var oa: float = a.off[i]
		var ob: float = b.off[i]
		var dlt := fposmod(ob - oa + 0.5, 1.0) - 0.5
		off.append(fposmod(oa + dlt * t, 1.0))
	return {"off": off, "duty": lerpf(a.duty, b.duty, t), "lift": lerpf(a.lift, b.lift, t), "stride": lerpf(a.stride, b.stride, t), "reach": lerpf(a.reach, b.reach, t)}


## Pose the skeleton: stride phase `ph` (radians), the horse's `speed`, head `graze` (0 up .. 0.7 down), `dt`.
func pose(ph: float, speed: float, graze: float, dt: float, accel := Vector2.ZERO) -> void:
	if skel == null:
		return
	_t += dt
	var k := clampf(speed / gallop_s, 0.0, 1.0)
	var g := _blend(speed)
	var moving := speed > 0.15
	_air_w = lerpf(_air_w, air, 1.0 - exp(-18.0 * maxf(dt, 0.001)))
	var aw := _air_w
	var sv := clampf(vy / 7.0, -1.0, 1.0)                   # +1 leaving the ground .. 0 apex .. -1 arriving
	var rise_w := maxf(sv, 0.0)
	var fall_w := clampf(-sv * 1.4, 0.0, 1.0)                # reaching for the ground
	var tuck := clampf(1.0 - absf(sv - 0.15) * 1.3, 0.0, 1.0)
	_fold_f = tuck * aw * 1.1
	_fold_h = (rise_w * 0.5 + tuck * 0.3) * aw
	var cyc := ph / TAU
	var sz := size
	# --- legs: foot targets, then how far the back must drop to reach them
	var tgt := {}
	var swing := {}
	var need := 0.0
	for i in 4:
		var l: String = LEGS[i]
		if not _legs.has(l):
			continue
		var L: Dictionary = _legs[l]
		var fp: Vector3 = L.fet_p
		var dz := 0.0
		var dy := 0.0
		var sw := 0.0
		if moving:
			var u := fposmod(cyc + float(g.off[i]), 1.0)
			var duty: float = g.duty
			var s_reach: float = float(g.reach) * sz
			if u < duty:
				dz = s_reach * (1.0 - 2.0 * u / duty)                    # stance: the hoof slides back under the body
			else:
				sw = (u - duty) / (1.0 - duty)
				var e := sw * sw * (3.0 - 2.0 * sw)
				dz = -s_reach + 2.0 * s_reach * e                         # swing: it comes forward
				dy = sin(sw * PI) * float(g.lift) * sz * (1.0 + 0.4 * sin(sw * PI))
			var amp := clampf(speed / 1.2, 0.0, 1.0)
			dz *= amp
			dy *= amp
		swing[l] = sw
		if aw > 0.001:
			var front := l.begins_with("f")
			var ay: float
			var az: float
			if front:
				ay = (0.42 * tuck + 0.1 * fall_w) * sz                  # knees up, cannons folded back under the chest
				az = (0.24 * tuck - 0.42 * fall_w) * sz                 # then reaching forward to land
			else:
				ay = (0.14 * rise_w + 0.12 * tuck) * sz
				az = (0.4 * rise_w + 0.1 * tuck - 0.22 * fall_w) * sz   # trailing on the push, forward on the way down
			dy = lerpf(dy, ay, aw)
			dz = lerpf(dz, az, aw)
		var tp := fp + Vector3(0, dy, dz)
		tgt[l] = tp
		need = maxf(need, ((tp - L.hip).length() - (float(L.l1) + float(L.l2)) * 0.985))
	var drop := clampf(need, 0.0, 0.2) if moving else 0.0
	# body motion: a bounce twice a stride, a rock at the gallop
	var bounce := 0.0
	var pitch := 0.0
	if moving:
		bounce = absf(sin(ph * 2.0 + 0.6)) * (0.012 + 0.05 * k) * sz - 0.015 * k
		pitch = sin(ph * 2.0 + 0.6) * (0.012 + 0.05 * k)
		if speed > trot_s:
			pitch += sin(ph) * 0.05 * k
	# the leap: haunches drop and the forehand lifts in the gather, push up through the climb, nose down to land
	pitch += (0.16 * gather + 0.2 * rise_w * aw - 0.14 * fall_w * aw - 0.05 * land)
	bounce *= 1.0 - aw
	last_dy = bounce - drop - (0.1 * gather + 0.09 * land) * sz
	# --- the bones (world-aligned rotations about X, accumulated down the chains)
	_wrot.clear()
	var root_off := Vector3(0, last_dy, 0)
	_pose_bone("root", 0.0, 0.0, root_off)
	_pose_bone("hips", pitch * 0.6)
	_pose_bone("barrel", pitch * 0.3 + sin(ph * 2.0 + 1.0) * 0.012 * k)
	_pose_bone("chest", -pitch * 0.4)
	var br := sin(_t * 1.9 + _seed) * 0.01                      # breathing
	var head_run := -0.1 * k + sin(ph * 2.0 + 2.2) * 0.07 * k    # the head carried out and nodding
	head_run += -0.22 * tuck * aw - 0.1 * gather               # the neck stretched out over the jump, tucked in the gather
	var gz := graze
	_pose_bone("neck1", -gz * 0.5 + head_run * 0.35 + br)
	_pose_bone("neck2", -gz * 0.62 + head_run * 0.3)
	_pose_bone("neck3", -gz * 0.45 + head_run * 0.25)
	_pose_bone("head", -gz * 0.25 + head_run * 0.1 + 0.05 * k)
	# ears: a flick now and then, laid back at the gallop
	_flick_t -= dt
	if _flick_t <= 0.0:
		_flick_t = randf_range(2.0, 6.0)
		_flick = 1.0
	_flick = maxf(0.0, _flick - dt * 3.0)
	_pose_bone("ear_r", -0.15 * k + sin(_flick * 9.0) * 0.18 * _flick, 0.0)
	_pose_bone("ear_l", -0.15 * k + sin(_flick * 7.0) * 0.1 * _flick, 0.0)
	# tail: lifted at speed, swaying, each joint lagging
	var tl := -0.35 * k
	_pose_bone("tail0", tl, sin(_t * 1.3 + _seed) * 0.12 + sin(ph) * 0.05 * k)
	_pose_bone("tail1", tl * 0.8 + sin(ph * 2.0 + 0.5) * 0.08 * k, sin(_t * 1.7 + 1.0) * 0.14)
	_pose_bone("tail2", tl * 0.6 + sin(ph * 2.0 + 1.0) * 0.1 * k, sin(_t * 1.9 + 2.0) * 0.16)
	_pose_bone("tail3", tl * 0.4 + sin(ph * 2.0 + 1.5) * 0.12 * k, sin(_t * 2.3 + 3.0) * 0.18)
	# mane: tips trail back with speed, a slow stir
	for j in 3:
		var nm := "mane%d" % (j + 1)
		_pose_bone(nm, -0.55 * k - sin(ph * 2.0 - float(j) * 0.7) * 0.12 * k + sin(_t * 1.5 + float(j)) * 0.04, sin(_t * 1.1 + float(j) * 1.3) * 0.05 + sin(ph * 2.0 - float(j)) * 0.06 * k)
	# lantern: a damped pendulum shaken by the stride and the horse's acceleration
	var shake := Vector2(sin(ph * 2.0 + 0.4) * 0.5 * k, sin(ph + 1.2) * 0.4 * k)
	var force := Vector2(-accel.x * 0.05, -accel.y * 0.05) + shake * 3.0
	_lan_v += (force - _lan * 38.0 - _lan_v * 3.2) * dt
	_lan += _lan_v * dt
	_lan = _lan.clamp(Vector2(-0.8, -0.8), Vector2(0.8, 0.8))
	_pose_bone("lantern", _lan.x, _lan.y)
	# legs
	for i in 4:
		var l: String = LEGS[i]
		if not _legs.has(l):
			continue
		var L: Dictionary = _legs[l]
		_leg(L, tgt[l] + Vector3(0, drop * 0.0, 0), float(swing[l]), k, l.begins_with("f"))


## Two-bone solve in the sagittal plane (y up, z fore-aft) to put the fetlock on `target`.
func _leg(L: Dictionary, target: Vector3, sw: float, k: float, front: bool) -> void:
	var hip: Vector3 = L.hip + Vector3(0, last_dy, 0)
	var rel := target - hip
	var d := maxf(Vector2(rel.y, rel.z).length(), 0.001)
	var l1: float = L.l1
	var l2: float = L.l2
	d = minf(d, (l1 + l2) * 0.999)
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var dir := Vector2(rel.y, rel.z).normalized()                    # (y, z)
	var perp := Vector2(-dir.y, dir.x)
	# the side the knee bends to (kept from the rest pose)
	var sgn: float = L.side
	var knee2 := dir * a + perp * h * sgn
	# rest directions (y, z) of the two segments
	var r1 := Vector2((L.knee as Vector3).y - (L.hip as Vector3).y, (L.knee as Vector3).z - (L.hip as Vector3).z)
	var r2 := Vector2((L.fet_p as Vector3).y - (L.knee as Vector3).y, (L.fet_p as Vector3).z - (L.knee as Vector3).z)
	var n1 := knee2
	var n2 := dir * d - knee2
	# rotation about +X taking a (y, z) direction to another: angle from atan2(z, y)
	var a1 := atan2(n1.y, n1.x) - atan2(r1.y, r1.x)
	var a2 := atan2(n2.y, n2.x) - atan2(r2.y, r2.x)
	# the pastern and hoof: kept level on the ground, folded back and up in the swing
	var fold := -sin(sw * PI) * (0.5 + 0.5 * k) * (0.9 if front else 0.55) - (_fold_f if front else _fold_h)
	_pose_bone(L.up, a1, 0.0, Vector3.ZERO, true)
	_pose_bone(L.low, a2, 0.0, Vector3.ZERO, true)
	_pose_bone(L.fet, fold, 0.0, Vector3.ZERO, true)


## Pose `bone` with a rotation about X (and Z): accumulated onto its parent's, or absolute (the legs,
## solved in world space). Parents are posed first.
func _pose_bone(bone: String, ax: float, az := 0.0, off := Vector3.ZERO, absolute := false) -> void:
	if not _bi.has(bone):
		return
	var par: String = _par[bone]
	var pw: Basis = _wrot[par] if par != "" and _wrot.has(par) else Basis.IDENTITY
	var r := Basis(Vector3.RIGHT, ax) * Basis(Vector3.FORWARD, az)
	var w: Basis = r if absolute else pw * r
	_wrot[bone] = w
	var pg: Basis = pw * (_rest_g[par] as Basis) if par != "" else Basis.IDENTITY
	var local: Basis = pg.inverse() * (w * (_rest_g[bone] as Basis))
	var i: int = _bi[bone]
	skel.set_bone_pose_rotation(i, local.get_rotation_quaternion())
	if bone == "root":
		skel.set_bone_pose_position(i, (_rest_l[bone] as Vector3) + off)
