extends CharacterRig
## A four-legged boss posed by formula (17 Nov: bosses "simple like the villager"): a BeastBody (core/enemy/beast_body.gd,
## the villagers' style on a beast's skeleton) driven here. It answers the calls Enemy and BossKit make on the other
## rigs (animate / telegraph / strike / flinch / stagger / howl / collapse / socket / muzzle / dress), so a boss
## changes rig without its fight changing.
##   idle     breathing, the head and tail slow
##   walk/run a diagonal trot, a bounding lope past `run_at`; the gait is paced by the ground covered (no skating)
##   air/land a pounce in flight (forelegs reaching, hind legs thrown back), a crouch as it lands
##   windup   coiled low, head down, tail up; held, it trembles
##   strike   a lunge and a snap, then back
##   stagger  thrown back, the forelegs buckling, righted
##   howl     the head thrown back, the jaws open
##   death    the legs fold, it goes down on its side
## No class_name (project rule): const BeastRig := preload("res://core/enemy/beast_rig.gd")

const BB := preload("res://core/enemy/beast_body.gd")
const Smooth := preload("res://core/enemy/pose_smooth.gd")
## Seconds a change of mode is blended over (pose_smooth.gd): short into a blow, long out of one and into a death.
const BLEND := {&"idle": 0.24, &"windup": 0.14, &"strike": 0.05, &"stagger": 0.08, &"howl": 0.2, &"death": 0.3}
const STRIKE_LEN := 0.95
const STAGGER_LEN := 1.6
const DEATH_LEN := 2.2
const LAND_LEN := 0.32
const SOCKETS := {"pelvis": 1, "body": 2, "chest": 3, "front": 4, "head": 5, "tail": 7}
const FX_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
instance uniform float hit_flash = 0.0;
instance uniform float glint = 0.0;
instance uniform float dissolve = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = vec3(1.0, 0.95, 0.88) * hit_flash * 0.5 + vec3(1.0, 0.52, 0.16) * (glint * 0.4 * rim + dissolve * (0.3 + 1.4 * rim));
}
"""

var body_script: GDScript
var opts := {}
## Body units of ground one gait cycle covers: walking, running; the speed (body units / s) the lope begins at.
var walk_stride := 0.9
var run_stride := 1.9
var run_at := 0.95

var _q_b: Node3D
var _q_sk: Skeleton3D
var _q_mode := &"idle"
var _q_mt := 0.0
var _q_mlen := 0.0
var _q_gait := 0.0
var _q_walk := 0.0
var _q_run := 0.0
var _q_air := 0.0
var _q_land_t := 0.0
var _q_was_floor := true
var _q_flinch := 0.0
var _q_flinch_v := 0.0                            ## a critically damped spring: a blow kicks its speed, it settles without a snap
var _sm: Smooth                                   ## mode crossfade and tick interpolation (pose_smooth.gd)
var _sm_frame := -10
var _R := {}                                      ## the euler pose per bone, reused every tick (no allocation)
var _q_flinch_side := 0.0
var _q_dead := false
var _q_glints: Array = []
var _q_sock_nodes := {}


## Put an enemy on this rig: `body` a BeastBody script; opts: scale (float), walk_stride, run_stride, run_at.
static func fit(e: Node, body: GDScript, opts := {}) -> CharacterRig:
	var rig: CharacterRig = (load("res://core/enemy/beast_rig.gd") as GDScript).new()
	rig.set("body_script", body)
	for key: String in ["walk_stride", "run_stride", "run_at"]:
		if opts.has(key):
			rig.set(key, float(opts[key]))
	var en: Variant = e
	en.attach_rig(rig)
	rig.scale = Vector3.ONE * float(opts.get("scale", 1.0))
	var r: Variant = rig
	en.set_flesh(r.dress(&""))
	return rig


func _build() -> void:
	_sockets.clear()
	_equipped.clear()
	var body: Variant = body_script.new()
	_q_b = body.made(opts)
	add_child(_q_b)
	_q_sk = _q_b.get("skeleton") as Skeleton3D
	_sm = Smooth.new(BB.BONES.size(), 2)
	for n: String in SOCKETS:
		var s := Node3D.new()
		s.name = "Socket_" + n
		add_child(s)
		_sockets[n] = s
		_q_sock_nodes[n] = s
	for gl: Array in (_q_b.get("glints") as Array):
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = float(gl[2])
		sm.height = float(gl[2]) * 2.2
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = gl[3]
		m.emission_enabled = true
		m.emission = gl[3]
		m.emission_energy_multiplier = 2.2
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_q_sk.add_child(mi)
		_q_glints.append([mi, int(gl[0]), gl[1]])
	_pelvis = _sockets["pelvis"]
	_chest = _sockets["chest"]
	_head = _sockets["head"]
	var sh := Shader.new()
	sh.code = FX_CODE
	var fx := ShaderMaterial.new()
	fx.shader = sh
	(_q_b.get("mesh_instance") as MeshInstance3D).material_overlay = fx
	_pose(0.0, Vector3.ZERO)


func dress(_kind: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = [_q_b.get("mesh_instance") as MeshInstance3D]
	return out


func animate(vel: Vector3, on_floor: bool, delta: float) -> void:
	if delta <= 0.0 or _q_b == null:
		return
	_t += delta
	_q_mt += delta
	var sp := Smooth.spring(_q_flinch, _q_flinch_v, 0.0, 14.0, delta)
	_q_flinch = sp.x
	_q_flinch_v = sp.y
	if on_floor and not _q_was_floor:
		_q_land_t = LAND_LEN
	_q_was_floor = on_floor
	_q_land_t = maxf(_q_land_t - delta, 0.0)
	_q_air = move_toward(_q_air, 0.0 if on_floor else 1.0, delta * 6.0)
	if not _q_dead and _q_mode != &"windup":
		var done := (_q_mode == &"strike" and _q_mt >= STRIKE_LEN) or (_q_mode == &"stagger" and _q_mt >= STAGGER_LEN) or (_q_mode == &"howl" and _q_mt >= _q_mlen)
		if done:
			_set_mode(&"idle")
	_pose(delta, vel)


func _set_mode(m: StringName, length := 0.0) -> void:
	if _sm != null and m != _q_mode:
		_sm.mode_changed(float(BLEND.get(m, 0.15)))
	_q_mode = m
	_q_mt = 0.0
	_q_mlen = length


func cast(_sound := "") -> void:
	telegraph(0.6)


func telegraph(dur: float) -> void:
	if not _q_dead:
		_set_mode(&"windup", clampf(dur * 0.6, 0.2, 0.8))


func strike() -> void:
	if not _q_dead:
		_set_mode(&"strike")


func howl(dur: float) -> void:
	if not _q_dead:
		_set_mode(&"howl", maxf(dur, 0.4))


func flinch(amount: float, side := 0.0) -> void:
	_q_flinch_v += clampf(amount, 0.0, 1.0) * 38.0
	_q_flinch_side = side


func stagger() -> void:
	if not _q_dead:
		_q_flinch_v += 38.0
		_set_mode(&"stagger")


func collapse(_back := false) -> void:
	if _q_dead:
		return
	_q_dead = true
	_set_mode(&"death")
	set_process(true)


func _process(_delta: float) -> void:
	if _q_b == null:
		return
	_draw_bones()
	if not _q_dead:
		return
	var mi := _q_b.get("mesh_instance") as MeshInstance3D
	var d := clampf(float(mi.get_instance_shader_parameter(&"dissolve")) * 1.15, 0.0, 1.0)
	mi.transparency = d
	for gl: Array in _q_glints:
		(gl[0] as GeometryInstance3D).transparency = d


## The skeleton between the last two committed ticks (bone poses are not physics-interpolated: posed at 60 Hz they
## would step on a faster screen). A tick that was not posed shows the last pose as it is.
func _draw_bones() -> void:
	if _q_sk == null or _sm == null or not _sm.primed:
		return
	var live := is_physics_interpolated_and_enabled() and Engine.get_physics_frames() - _sm_frame < 2
	var f := Engine.get_physics_interpolation_fraction() if live else 1.0
	for i in _sm.n:
		_q_sk.set_bone_pose_rotation(i, _sm.sample_q(i, f))
	_q_sk.set_bone_pose_position(BB.B_ROOT, _sm.sample_v(1, f))


func muzzle() -> Vector3:
	var at: Array = _q_b.get("muzzle_at") if _q_b else []
	if at.is_empty():
		return global_position + Vector3.UP
	var b: Variant = _q_b
	return _q_sk.to_global(b.carry(int(at[0]), at[1]))


# =====================================================================================================
# posing: per-bone rotations (pitch, yaw, roll; radians) and the root's offset, built fresh each frame
# =====================================================================================================

func _pose(dt: float, vel: Vector3) -> void:
	var R := _R
	R.clear()
	var rot_z := 0.0
	var root := Vector3.ZERO
	var size := maxf(global_basis.get_scale().y, 0.01) if is_inside_tree() else 1.0
	var speed := Vector2(vel.x, vel.z).length() / size
	var moving := speed > 0.1 and _q_mode in [&"idle", &"howl"] and not _q_dead and _q_air < 0.5
	_q_walk = move_toward(_q_walk, 1.0 if moving else 0.0, dt * 3.0)
	_q_run = move_toward(_q_run, 1.0 if (moving and speed >= run_at) else 0.0, dt * 2.5)
	var stride := lerpf(walk_stride, run_stride, _q_run)
	if _q_walk > 0.001:
		_q_gait = fposmod(_q_gait + speed * dt / maxf(stride, 0.05), 1.0)
	var breath := sin(_t * 1.9) * 0.02
	_add(R, BB.B_CHEST, Vector3(breath, 0, 0))
	_add(R, BB.B_NECK, Vector3(0.05 * sin(_t * 0.6), 0.12 * sin(_t * 0.37), 0))
	_add(R, BB.B_TAIL, Vector3(0.1 * sin(_t * 0.9), 0.25 * sin(_t * 1.1), 0))
	_add(R, BB.B_TAIL + 1, Vector3(0.1 * sin(_t * 0.9 - 0.6), 0.3 * sin(_t * 1.1 - 0.7), 0))
	_add(R, BB.B_TAIL + 2, Vector3(0.1 * sin(_t * 0.9 - 1.2), 0.35 * sin(_t * 1.1 - 1.4), 0))
	# the gait: a diagonal trot, a bounding lope (fore pair, then hind pair) as it runs
	if _q_walk > 0.001:
		for i in 4:
			var trot_ph: float = [0.0, 0.5, 0.5, 0.0][i]
			var lope_ph: float = [0.0, 0.08, 0.5, 0.58][i]
			var ph := lerpf(trot_ph, lope_ph, _q_run)
			var a := TAU * (_q_gait + ph)
			var amp := lerpf(0.36, 0.6, _q_run) * _q_walk
			var lift := maxf(cos(a), 0.0) * _q_walk
			var front := i < 2
			_add(R, BB.B_LEG + 2 * i, Vector3(amp * sin(a), 0, 0))
			_add(R, BB.B_LEG + 2 * i + 1, Vector3((-0.9 if front else 0.8) * lift, 0, 0))
		var c2 := cos(TAU * 2.0 * _q_gait)
		root.y += (-0.025 - 0.02 * _q_run) * absf(c2) * _q_walk
		_add(R, BB.B_HIPS, Vector3(0.08 * _q_run * sin(TAU * _q_gait), 0, 0))
		_add(R, BB.B_CHEST, Vector3(-0.08 * _q_run * sin(TAU * _q_gait), 0, 0))
	# a pounce in flight, and the crouch it lands into
	if _q_air > 0.001:
		for i in 4:
			var front := i < 2
			_add(R, BB.B_LEG + 2 * i, Vector3((0.9 if front else -0.85) * _q_air, 0, 0))
			_add(R, BB.B_LEG + 2 * i + 1, Vector3((-0.3 if front else 0.5) * _q_air, 0, 0))
		_add(R, BB.B_NECK, Vector3(0.15 * _q_air, 0, 0))
		_add(R, BB.B_TAIL, Vector3(0.4 * _q_air, 0, 0))
	if _q_land_t > 0.0:
		root.y += _crouch(R, 0.45 * sin(PI * _q_land_t / LAND_LEN))
	match _q_mode:
		&"windup":
			var u := clampf(_q_mt / maxf(_q_mlen, 0.05), 0.0, 1.0)
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			var tr := sin(_t * 31.0) * 0.012 * smoothstep(0.9, 1.0, u)
			root.y += _crouch(R, 0.55 * e)
			_add(R, BB.B_CHEST, Vector3(-0.12 * e, 0, tr))
			_add(R, BB.B_NECK, Vector3(-0.3 * e, 0, 0))
			_add(R, BB.B_HEAD, Vector3(0.25 * e, 0, 0))
			_add(R, BB.B_TAIL, Vector3(0.6 * e, 0, 0))
			_add(R, BB.B_JAW, Vector3(0.15 * e, 0, 0))
		&"strike":
			var u := _q_mt / STRIKE_LEN
			var hit := smoothstep(0.0, 0.18, u)
			var back := smoothstep(0.45, 0.95, u)
			var w := hit * (1.0 - back)
			root += Vector3(0, 0.04 * w, -0.3 * w)
			for i in 4:
				var front := i < 2
				_add(R, BB.B_LEG + 2 * i, Vector3((0.7 if front else -0.6) * w, 0, 0))
				_add(R, BB.B_LEG + 2 * i + 1, Vector3((-0.2 if front else 0.3) * w, 0, 0))
			_add(R, BB.B_NECK, Vector3(0.1 * w, 0, 0))
			_add(R, BB.B_HEAD, Vector3(-0.25 * w, 0, 0))
			_add(R, BB.B_JAW, Vector3(0.55 * (smoothstep(0.0, 0.12, u) - smoothstep(0.16, 0.3, u)) + 0.1 * w, 0, 0))
		&"stagger":
			var u := _q_mt / STAGGER_LEN
			var hitb := exp(-6.0 * u)
			var buckle := smoothstep(0.1, 0.3, u) * (1.0 - smoothstep(0.7, 0.98, u))
			root += Vector3(0, -0.12 * buckle, 0.15 * hitb)
			_add(R, BB.B_CHEST, Vector3(0.25 * hitb - 0.15 * buckle, 0, 0.1 * sin(u * 14.0) * buckle))
			_add(R, BB.B_LEG, Vector3(0.5 * buckle, 0, 0))
			_add(R, BB.B_LEG + 1, Vector3(-1.1 * buckle, 0, 0))
			_add(R, BB.B_LEG + 2, Vector3(0.5 * buckle, 0, 0))
			_add(R, BB.B_LEG + 3, Vector3(-1.1 * buckle, 0, 0))
			_add(R, BB.B_HEAD, Vector3(0.3 * buckle, 0.4 * sin(u * 18.0) * buckle, 0))
		&"howl":
			var u := clampf(_q_mt / maxf(_q_mlen, 0.2), 0.0, 1.0)
			var up := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.82, 1.0, u))
			var q := sin(_t * 37.0) * 0.015 * up
			_add(R, BB.B_NECK, Vector3(0.75 * up, 0, 0))
			_add(R, BB.B_HEAD, Vector3(0.35 * up + q, 0, 0))
			_add(R, BB.B_JAW, Vector3(0.5 * up, 0, 0))
			_add(R, BB.B_LEG, Vector3(-0.15 * up, 0, 0))
			_add(R, BB.B_LEG + 2, Vector3(-0.15 * up, 0, 0))
			_add(R, BB.B_TAIL, Vector3(-0.3 * up, 0, 0))
		&"death":
			var u := clampf(_q_mt / DEATH_LEN, 0.0, 1.0)
			var fold := smoothstep(0.05, 0.4, u)
			var over := smoothstep(0.35, 0.75, u)
			root.y += _crouch(R, 1.0 * fold)
			_add(R, BB.B_NECK, Vector3(-0.4 * fold, 0, 0))
			_add(R, BB.B_HEAD, Vector3(0.3 * fold, 0, 0))
			rot_z = 1.35 * over
			root.y += 0.12 * over
	# commit: the mode's pose, crossfaded from the last if the mode just changed (pose_smooth.gd)
	_sm.raw_v[0] = Vector3(-_q_flinch * 0.08, 0.0, _q_flinch * _q_flinch_side * 0.1) if not _q_dead else Vector3(0.0, 0.0, rot_z)
	var rest0: Vector3 = (_q_b.get("rests") as Array)[BB.B_ROOT]
	_sm.raw_v[1] = rest0 + root
	for i in _sm.n:
		_sm.raw_q[i] = Quaternion.from_euler(R.get(i, Vector3.ZERO))
	_sm.commit(dt if dt > 0.0 else 0.0166)
	_sm_frame = Engine.get_physics_frames()
	_q_b.rotation = _sm.cur_v[0]
	for i in _sm.n:
		_q_sk.set_bone_pose_rotation(i, _sm.cur_q[i])
	_q_sk.set_bone_pose_position(BB.B_ROOT, _sm.cur_v[1])
	var bv: Variant = _q_b
	for gl: Array in _q_glints:
		(gl[0] as Node3D).position = bv.carry(int(gl[1]), gl[2])
	_place_sockets()


static func _add(R: Dictionary, b: int, e: Vector3) -> void:
	R[b] = (R.get(b, Vector3.ZERO) as Vector3) + e


## All four legs folded by `a` (the upper forward, the lower back twice as far): the root's drop.
func _crouch(R: Dictionary, a: float) -> float:
	for i in 4:
		var front := i < 2
		_add(R, BB.B_LEG + 2 * i, Vector3(a * (0.8 if front else 0.9), 0, 0))
		_add(R, BB.B_LEG + 2 * i + 1, Vector3(-a * (1.5 if front else 1.7), 0, 0))
	return -0.42 * (1.0 - cos(a))


func _place_sockets() -> void:
	var rel := _q_b.transform * _q_sk.transform
	for n: String in _q_sock_nodes:
		var gp := _q_sk.get_bone_global_pose(int(SOCKETS[n]))
		(_q_sock_nodes[n] as Node3D).transform = Transform3D(Basis.IDENTITY, (rel * gp).origin)
