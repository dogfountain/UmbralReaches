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
## leg phase offsets (fraction of a stride) in LEGS order, duty (stance share),
## lift (m), and the stride length (m) of each gait. The sweep of a stance is stride x duty (so the planted hoof
## is still while the horse moves on); the hips ride the pitching spine and the back sinks to keep every hoof in reach
const GAITS := {
	"walk": {"off": [0.25, 0.75, 0.0, 0.5], "duty": 0.68, "lift": 0.085, "stride": 1.5},
	"trot": {"off": [0.0, 0.5, 0.5, 0.0], "duty": 0.46, "lift": 0.14, "stride": 2.9},
	"gallop": {"off": [0.52, 0.64, 0.0, 0.12], "duty": 0.3, "lift": 0.2, "stride": 3.8},
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
var heft := 1.0                        ## how heavy it moves (horse_db): cadence, nod, how lazily tail and mane follow
var turn := 0.0                        ## the horse's yaw rate (rad/s, + left), set by horse.gd: the bank and the head's lead
var body_pitch := 0.0                  ## outputs for the rider to follow, with lag (+ nose up)
var body_roll := 0.0
var rock := 0.0                        ## the gallop's gather/extension (-1..1) for the rider's hip-hinge
var _bank := 0.0
var _turn_s := 0.0
var _acc_s := 0.0
var _tail_a: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _tail_v: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _mane_a: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _mane_v: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
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
	heft = float(d.get("heft", 1.0))
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


## The legs (indices into LEGS) whose hoof plants as the stride phase goes from `ph0` to `ph1` at `speed`:
## the instant each leg's stance begins in pose(). Four beats at the walk, two at the trot, the gallop's
## hind-hind-fore-fore with the suspension as the silence between strides. horse.gd times the hoofbeats off it.
func footfalls(ph0: float, ph1: float, speed: float) -> Array[int]:
	var out: Array[int] = []
	if speed < 0.6 or ph1 <= ph0:
		return out
	var off: Array = _blend(speed).off
	for i in 4:
		var o: float = off[i]
		if floorf(ph1 / TAU + o) > floorf(ph0 / TAU + o):
			out.append(i)
	return out


## The gait parameters at a speed: walk below `walk_s`, blending to trot, then to gallop.
func _blend(speed: float) -> Dictionary:
	var a: Dictionary
	var b: Dictionary
	var t: float
	if speed <= walk_s:
		return {"off": GAITS.walk.off, "duty": GAITS.walk.duty, "lift": float(GAITS.walk.lift) * clampf(speed / walk_s, 0.25, 1.0), "stride": GAITS.walk.stride}
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
	return {"off": off, "duty": lerpf(a.duty, b.duty, t), "lift": lerpf(a.lift, b.lift, t), "stride": lerpf(a.stride, b.stride, t)}


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
	_fold_f = tuck * aw * 1.5
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
			var s_reach: float = float(g.stride) * float(g.duty) * 0.5 * sz      # half the sweep = half the ground the stance covers: the planted hoof is still
			if u < duty:
				dz = -s_reach * (1.0 - 2.0 * u / duty)                   # stance: the planted hoof travels from the front of its sweep to the back (+z is aft)
			else:
				sw = (u - duty) / (1.0 - duty)
				var e := sw * sw * (3.0 - 2.0 * sw)
				dz = s_reach - 2.0 * s_reach * e                          # swing: it comes forward
				dy = sin(sw * PI) * float(g.lift) * sz * (1.0 + 0.4 * sin(sw * PI))
			var amp_l := clampf(speed / 1.2, 0.0, 1.0)
			dz *= amp_l
			dy *= amp_l
		swing[l] = sw
		if aw > 0.001:
			var front := l.begins_with("f")
			var ay: float
			var az: float
			if front:
				ay = (0.5 * tuck + 0.1 * fall_w) * sz                  # knees up, cannons folded back under the chest
				az = (0.24 * tuck - 0.42 * fall_w) * sz                 # then reaching forward to land
			else:
				ay = (0.14 * rise_w + 0.12 * tuck) * sz
				az = (0.75 * rise_w + 0.1 * tuck - 0.22 * fall_w) * sz   # trailing on the push, forward on the way down
			dy = lerpf(dy, ay, aw)
			dz = lerpf(dz, az, aw)
		var tp := fp + Vector3(0, dy, dz)
		tgt[l] = tp
		need = maxf(need, ((tp - L.hip).length() - (float(L.l1) + float(L.l2)) * 0.985))
	var drop := clampf(need, 0.0, 0.38) if moving else 0.0
	# --- gait weights and the stride's own timing
	var ww := 1.0 - smoothstep(walk_s, walk_s + (trot_s - walk_s) * 0.55, speed)
	var gw := smoothstep(trot_s, trot_s + (gallop_s - trot_s) * 0.7, speed)
	var tw := maxf(1.0 - ww - gw, 0.0)
	var amp := clampf(speed / 1.2, 0.0, 1.0) if moving else 0.0
	var hs := 1.0 / sqrt(heft)                                   # heavy horses move the body less, and later
	var flex := cos(TAU * (cyc - 0.83))                          # the gallop's gather (-) and extension (+) round the suspension
	var dtc := clampf(dt, 0.0, 0.033)
	if dt > 0.0005:
		_acc_s = lerpf(_acc_s, accel.x, 1.0 - exp(-6.0 * dt))
		_turn_s = lerpf(_turn_s, turn, 1.0 - exp(-9.0 * dt))
	var acc := clampf(_acc_s / 6.0, -1.0, 1.0)
	# --- body motion: a rock at the walk, a two-beat bounce at the trot, a gathered / extended suspension at the gallop
	var bounce := 0.0
	var pitch := 0.0
	var roll := 0.0
	bounce = amp * sz * hs * (ww * 0.014 * sin(ph * 2.0 + 0.6) + tw * 0.05 * (absf(sin(ph * 2.0 + 0.6)) - 0.64) + gw * 0.075 * flex)
	pitch = amp * (ww * 0.035 * sin(ph * 2.0 + 0.6) + tw * 0.035 * sin(ph * 2.0 + 0.6) + gw * (0.075 * flex + 0.03 * sin(ph * 2.0 + 0.6))) * hs
	roll = amp * (ww * 0.04 + tw * 0.012) * sin(ph + 0.3) * hs + amp * gw * 0.03 * sin(ph + 1.0)
	# starts and stops: the haunches coil under a start, sit down into a halt
	pitch += 0.07 * maxf(acc, 0.0) + 0.09 * maxf(-acc, 0.0)
	# turns: the body banks into it (the horse leans left into a left turn)
	var bank_want := clampf(atan(speed * turn / 9.8) * 0.9, -0.2, 0.2)
	_bank = lerpf(_bank, bank_want, 1.0 - exp(-5.0 * maxf(dt, 0.001)))
	roll -= _bank
	# the leap: haunches drop and the forehand lifts in the gather, the hindquarters push through the climb,
	# the nose tips down over the top, the forehand reaches for the ground and takes the landing
	pitch += 0.28 * gather + (0.5 * rise_w - 0.25 * tuck) * aw - 0.42 * fall_w * aw - 0.09 * land
	bounce *= 1.0 - aw
	last_dy = bounce - drop - (0.13 * gather + 0.1 * land) * sz
	body_pitch = pitch
	body_roll = roll
	# --- the bones (world-aligned rotations about X, accumulated down the chains)
	_wrot.clear()
	var root_off := Vector3(0, last_dy, 0)
	_pose_bone("root", 0.0, 0.0, root_off)
	var fx := gw * flex * amp
	rock = fx
	_pose_bone("hips", pitch * 0.6 + 0.07 * fx, roll * 0.8)
	_pose_bone("barrel", pitch * 0.3 - 0.1 * fx + sin(ph * 2.0 + 1.0) * 0.012 * k, roll * 0.2)
	_pose_bone("chest", -pitch * 0.4 - 0.05 * fx, 0.0)
	var br := sin(_t * 1.9 + _seed) * 0.01                      # breathing
	# the head: a nod once a stride at the walk, lightly at the trot, deep at the gallop, carried out with speed
	var nod := amp * (ww * 0.22 * sin(ph + 0.5) * heft + tw * 0.05 * sin(ph * 2.0 + 2.2) - gw * 0.3 * sin(TAU * (cyc - 0.35)))
	var head_run := -0.1 * k + nod
	head_run += -0.22 * tuck * aw - 0.1 * gather - 0.14 * land   # the neck stretched out over the jump, tucked in the gather
	head_run += 0.2 * maxf(-acc, 0.0) - 0.05 * maxf(acc, 0.0)    # up and bracing into a halt
	var gz := graze
	var lead := _turn_s * 0.28                                     # the head leads into the turn
	_pose_bone("neck1", -gz * 0.5 + head_run * 0.35 + br, 0.0, Vector3.ZERO, false, lead * 0.2)
	_pose_bone("neck2", -gz * 0.62 + head_run * 0.3, 0.0, Vector3.ZERO, false, lead * 0.3)
	_pose_bone("neck3", -gz * 0.45 + head_run * 0.25, 0.0, Vector3.ZERO, false, lead * 0.3)
	_pose_bone("head", -gz * 0.25 + head_run * 0.1 + 0.05 * k, -_bank * 0.25, Vector3.ZERO, false, lead * 0.2)
	# ears: a flick now and then, laid back at the gallop
	_flick_t -= dt
	if _flick_t <= 0.0:
		_flick_t = randf_range(2.0, 6.0)
		_flick = 1.0
	_flick = maxf(0.0, _flick - dt * 3.0)
	_pose_bone("ear_r", -0.15 * k + sin(_flick * 9.0) * 0.18 * _flick, 0.0)
	_pose_bone("ear_l", -0.15 * k + sin(_flick * 7.0) * 0.1 * _flick, 0.0)
	# tail and mane: chains of springs, each joint softer and later than the last, shaken by the body's own
	# vertical and sideways motion, streaming out and up with speed
	var vyb := clampf((last_dy - _prev_dy) / maxf(dt, 0.001), -4.0, 4.0) if dt > 0.0005 else 0.0
	if dt > 0.0005:
		_prev_dy = last_dy
	var drive := Vector2(-vyb * 0.09 + acc * -0.12 - sin(ph * 2.0 + 0.5) * 0.04 * k, -accel.y * 0.012 + sin(_t * 1.3 + _seed) * 0.1 + sin(ph) * 0.06 * k)
	var lift := -0.4 * k - 0.1 * gw
	for j in 4:
		var kj := (70.0 - 11.0 * float(j)) / heft
		var cj := 2.0 * sqrt(kj) * 0.32
		var tgt_j := Vector2(lift * (1.0 - 0.18 * float(j)), 0.0) + drive * (0.7 + 0.35 * float(j)) + Vector2(sin(_t * 1.7 + float(j)) * 0.03, sin(_t * (1.7 + 0.2 * float(j)) + 1.0 + float(j)) * 0.07)
		if dtc > 0.0:
			_tail_v[j] += ((tgt_j - _tail_a[j]) * kj - _tail_v[j] * cj) * dtc
			_tail_a[j] = (_tail_a[j] + _tail_v[j] * dtc).clamp(Vector2(-0.9, -0.7), Vector2(0.9, 0.7))
		_pose_bone("tail%d" % j, _tail_a[j].x, _tail_a[j].y)
	for j in 3:
		var km := (46.0 - 8.0 * float(j)) / heft
		var cm := 2.0 * sqrt(km) * 0.3
		var tgt_m := Vector2(-0.5 * k, 0.0) + Vector2(drive.x * 0.8 - nod * 0.4, drive.y * 0.5) + Vector2(sin(_t * 1.5 + float(j)) * 0.04, sin(_t * 1.1 + float(j) * 1.3) * 0.05)
		if dtc > 0.0:
			_mane_v[j] += ((tgt_m - _mane_a[j]) * km - _mane_v[j] * cm) * dtc
			_mane_a[j] = (_mane_a[j] + _mane_v[j] * dtc).clamp(Vector2(-0.9, -0.6), Vector2(0.9, 0.6))
		_pose_bone("mane%d" % (j + 1), _mane_a[j].x, _mane_a[j].y)
	# lantern: a damped pendulum shaken by the stride and the horse's acceleration
	var shake := Vector2(sin(ph * 2.0 + 0.4) * 0.5 * k, sin(ph + 1.2) * 0.4 * k)
	var force := Vector2(-accel.x * 0.05, -accel.y * 0.05) + shake * 3.0
	_lan_v += (force - _lan * 38.0 - _lan_v * 3.2) * dt
	_lan += _lan_v * dt
	_lan = _lan.clamp(Vector2(-0.8, -0.8), Vector2(0.8, 0.8))
	_pose_bone("lantern", _lan.x, _lan.y)
	# legs
	var hips := {}
	var extra := 0.0
	for i in 4:
		var l: String = LEGS[i]
		if not _legs.has(l):
			continue
		var L: Dictionary = _legs[l]
		hips[l] = skel.get_bone_global_pose(_bi[L.up]).origin
		extra = maxf(extra, ((tgt[l] as Vector3) - (hips[l] as Vector3)).length() - (float(L.l1) + float(L.l2)) * 0.985)
	# the hip joints ride the pitching, rolling spine: solve from where they are now, and sink the back a little
	# further if a hoof would be left short of its place on the ground
	if extra > 0.0 and moving:
		extra = minf(extra, 0.4)
		last_dy -= extra
		_pose_bone("root", 0.0, 0.0, Vector3(0, last_dy, 0))
		for l: String in hips:
			hips[l] = (hips[l] as Vector3) - Vector3(0, extra, 0)
	for i in 4:
		var l: String = LEGS[i]
		if not _legs.has(l):
			continue
		_leg(_legs[l], tgt[l], float(swing[l]), k, l.begins_with("f"), hips[l])


## Two-bone solve in the sagittal plane (y up, z fore-aft) to put the fetlock on `target`.
func _leg(L: Dictionary, target: Vector3, sw: float, k: float, front: bool, hip: Vector3) -> void:
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
func _pose_bone(bone: String, ax: float, az := 0.0, off := Vector3.ZERO, absolute := false, ay := 0.0) -> void:
	if not _bi.has(bone):
		return
	var par: String = _par[bone]
	var pw: Basis = _wrot[par] if par != "" and _wrot.has(par) else Basis.IDENTITY
	var r := Basis(Vector3.UP, ay) * Basis(Vector3.RIGHT, ax) * Basis(Vector3.FORWARD, az)
	var w: Basis = r if absolute else pw * r
	_wrot[bone] = w
	var pg: Basis = pw * (_rest_g[par] as Basis) if par != "" else Basis.IDENTITY
	var local: Basis = pg.inverse() * (w * (_rest_g[bone] as Basis))
	var i: int = _bi[bone]
	skel.set_bone_pose_rotation(i, local.get_rotation_quaternion())
	if bone == "root":
		skel.set_bone_pose_position(i, (_rest_l[bone] as Vector3) + off)
