extends CharacterRig
## A boss built the way Hearthward's people are (17 Nov, Luke: "reduce boss to simple model like villager, these models
## suck"): a VillagerRig (core/life/village/villager_rig.gd: one soft-skinned procedural surface, the tavern dwarves'
## 15 bones, two-bone arm IK, tools held in the fist), posed here by formula instead of a routine. It answers the same
## calls Enemy and BossKit make on the other rigs (animate / telegraph / strike / flinch / stagger / howl / collapse /
## socket / muzzle / dress), so a boss changes rig without its fight changing.
## No class_name (project rule): const VillagerBossRig := preload("res://core/enemy/villager_boss_rig.gd")
##
## Poses (villager model space: front -Z, the origin on the floor, `k` the body's size):
##   idle     the weight on one leg, breathing, the staff planted, the left hand's tool held out
##   walk     the villagers' heel-toe gait at the old's pace (npc_life.gd walk_legs), the staff set down with the stride
##   windup   the staff hauled up over the right shoulder, the body drawn up and back; held, it trembles
##   strike   the staff brought over and down in front with a step and a crouch into it, a ring, then back
##   stagger  thrown back off the blow, then folded over the staff, righted
##   howl     the staff thrust up overhead, the left hand lifted after it, the head back
##   death    the knees go, a moment kneeling on the staff, then forward onto the ground
## Hit flash, glint and the dissolve are an additive overlay with the flesh shaders' instance uniforms (the villager
## shader has none); the dissolve also fades the body out.

const VRig := preload("res://core/life/village/villager_rig.gd")
const Life := preload("res://core/npc/npc_life.gd")

const B_ROOT := 0
const B_SPINE := 1
const B_CHEST := 2
const B_HEAD := 3
const B_JAW := 4
const B_HAND_R := 7
const B_HAND_L := 10
const B_THIGH_R := 11
const B_SHIN_R := 12
const B_THIGH_L := 13
const B_SHIN_L := 14
const B_LID := 15
const GAIT := [0.26, 0.6, 0.011, 0.16]          ## the old's gait: thigh swing, knee fold, pelvis bob, arm swing
const STRIKE_LEN := 1.25
const STAGGER_LEN := 1.8
const DEATH_LEN := 2.6
const SOCKETS := {"pelvis": 1, "body": 1, "chest": 2, "front": 2, "head": 3, "hand_r": 7, "hand_l": 10}
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

## VillagerRig build options (villager_rig.gd KEYS): set before the rig is added.
var opts := {}
## A script extending VillagerRig with `made(opts)` (the boss's own head and trimmings in the
## villagers' style, core/enemy/abbot_body.gd), or null for a plain villager. Its `glints` ([bone, rest point, radius,
## colour]: eyes, candle flames) are lit here as small glow parts carried with their bones.
var body_script: GDScript
## How far forward the body is bent at rest (the old stoop).
var stoop := 0.14
## Height it floats above the floor (body units; 0 = it walks). A floating boss's legs never step: it drifts, bobbing.
var hover := 0.0


## Put an enemy on this rig (as ClipRig.fit does for a glb): `body` a BossBody script (core/enemy/boss_body.gd),
## `vopts` its build options, `opts`: stoop, hover, scale (float, on top of the boss's embiggen), cap (the collision
## capsule's height factor). Dresses the enemy's flesh and returns the rig.
static func fit(e: Node, body: GDScript, vopts := {}, opts := {}) -> CharacterRig:
	var rig: CharacterRig = (load("res://core/enemy/villager_boss_rig.gd") as GDScript).new()
	rig.set("body_script", body)
	rig.set("opts", vopts if not vopts.is_empty() else {"seed": 1, "sex": "m", "age": "adult"})
	rig.set("stoop", float(opts.get("stoop", 0.04)))
	rig.set("hover", float(opts.get("hover", 0.0)))
	var en: Variant = e
	en.attach_rig(rig)
	rig.scale = Vector3.ONE * float(opts.get("scale", 1.0))
	var col := e.get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D and opts.has("cap"):
		var cap := col.shape as CapsuleShape3D
		cap.height = 1.7 * float(opts.cap)
		col.position.y = cap.height * 0.5
	var r: Variant = rig
	en.set_flesh(r.dress(&""))
	return rig

var _v: Node3D                                   ## the VillagerRig
var _mode := &"idle"
var _mt := 0.0                                   ## seconds in the mode
var _mlen := 0.0                                 ## the mode's length (windup: its rise)
var _gait := 0.0
var _walk := 0.0
var _flinch := 0.0
var _flinch_side := 0.0
var _dead := false
var _sock_nodes := {}
var _fx: ShaderMaterial
var _k := 1.0
## The lantern's glass (the villager's glow part, carried with its hand), or null: a boss hangs its light on it.
var lantern_node: Node3D
var _glints: Array = []                           ## [MeshInstance3D, bone, rest point]


func _build() -> void:
	_sockets.clear()
	_equipped.clear()
	var body: Variant = body_script.new() if body_script != null else null
	_v = body.made(opts) if body != null else VRig.create(opts)
	_v.name = "Villager"
	add_child(_v)
	_k = float(_v.get("k"))
	for n: String in SOCKETS:
		var s := Node3D.new()
		s.name = "Socket_" + n
		add_child(s)
		_sockets[n] = s
		_sock_nodes[n] = s
	lantern_node = _v.get("glow") as Node3D
	for gl: Array in (_v.get("glints") if _v.get("glints") != null else []):
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
		_v.add_child(mi)
		_glints.append([mi, int(gl[0]), gl[1]])
		if lantern_node == null and int(gl[0]) == B_CHEST and float(gl[2]) > 0.02:
			lantern_node = mi                       # a burning heart: the boss hangs its light there
	_pelvis = _sockets["pelvis"]
	_chest = _sockets["chest"]
	_head = _sockets["head"]
	var sh := Shader.new()
	sh.code = FX_CODE
	_fx = ShaderMaterial.new()
	_fx.shader = sh
	(_v.get("mesh_instance") as MeshInstance3D).material_overlay = _fx
	_pose(0.0, Vector3.ZERO)


## The body wears the flesh uniforms on its overlay (hit flash, glint, dissolve).
func dress(_kind: StringName) -> Array[MeshInstance3D]:
	var mi := _v.get("mesh_instance") as MeshInstance3D
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var out: Array[MeshInstance3D] = [mi]
	return out


func animate(vel: Vector3, _on_floor: bool, delta: float) -> void:
	if delta <= 0.0 or _v == null:
		return
	_t += delta
	_mt += delta
	_flinch = move_toward(_flinch, 0.0, delta * 3.0)
	if not _dead and _mode != &"windup":
		var done := (_mode == &"strike" and _mt >= STRIKE_LEN) or (_mode == &"stagger" and _mt >= STAGGER_LEN) or (_mode == &"howl" and _mt >= _mlen)
		if done:
			_set_mode(&"idle")
	_pose(delta, vel)


func _set_mode(m: StringName, length := 0.0) -> void:
	_mode = m
	_mt = 0.0
	_mlen = length


func cast(_sound := "") -> void:
	telegraph(0.6)


func telegraph(dur: float) -> void:
	if _dead:
		return
	_set_mode(&"windup", clampf(dur * 0.7, 0.25, 0.9))


func strike() -> void:
	if _dead:
		return
	_set_mode(&"strike")


func howl(dur: float) -> void:
	if _dead:
		return
	_set_mode(&"howl", maxf(dur, 0.4))


func flinch(amount: float, side := 0.0) -> void:
	_flinch = clampf(maxf(_flinch, amount), 0.0, 1.0)
	_flinch_side = side


func stagger() -> void:
	if _dead:
		return
	_flinch = 1.0
	_set_mode(&"stagger")


func collapse(_back := false) -> void:
	if _dead:
		return
	_dead = true
	_set_mode(&"death")
	set_process(true)            # the dissolve runs after the Enemy stops animating the body


func _process(_delta: float) -> void:
	if not _dead or _v == null:
		set_process(false)
		return
	var mi := _v.get("mesh_instance") as MeshInstance3D
	var d := float(mi.get_instance_shader_parameter(&"dissolve"))
	mi.transparency = clampf(d * 1.15, 0.0, 1.0)
	var g := _v.get("glow") as MeshInstance3D
	if g:
		g.transparency = mi.transparency
	for gl: Array in _glints:
		(gl[0] as GeometryInstance3D).transparency = mi.transparency


## The top of the staff (spells leave from it), else the head.
func muzzle() -> Vector3:
	if _v == null:
		return global_position + Vector3.UP
	var r: Variant = _v
	r.fk_all()
	var at: Variant = _v.get("muzzle_at")
	if at is Array and not (at as Array).is_empty():
		return _v.to_global(r.carry(int(at[0]), at[1]))
	var grip: Vector3 = (r.grip as Array)[0]
	var ax: Vector3 = (r.grip_ax as Array)[0]
	return _v.to_global(r.carry(B_HAND_R, grip + ax * 0.42 * _k))


# =====================================================================================================
# posing
# =====================================================================================================

func _pose(dt: float, vel: Vector3) -> void:
	var r: Variant = _v
	var k := _k
	r.reset()
	var breath := (0.5 - 0.5 * cos(_t * 2.1)) * 0.03
	var sw := sin(_t * 0.7)
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -stoop * 0.4))
	r.q(B_CHEST, Quaternion(Vector3.RIGHT, -stoop * 0.6 + breath))
	var head_pitch := stoop * 0.7
	# the walk: ground speed as the body walks it (a boss three times the size covers three times the ground a stride)
	var size := maxf(global_basis.get_scale().y, 0.01)
	var speed := Vector2(vel.x, vel.z).length() / size
	var moving := speed > 0.12 and _mode in [&"idle", &"howl"] and not _dead and hover <= 0.0
	_walk = move_toward(_walk, 1.0 if moving else 0.0, dt * 3.0)
	var stride: float = Life.calib_stride(r, GAIT[0])
	if _walk > 0.001:
		_gait = fposmod(_gait + speed * dt / maxf(stride * maxf(_walk, 0.35), 0.01), 1.0)
	var off := _legs(k, sw) if hover <= 0.0 else hover + 0.035 * sin(_t * 1.3)
	var sr := cos(TAU * _gait) * _walk
	# the staff and the left hand's tool at rest: planted as he walks, held out before him standing
	var plant := 0.06 * sr
	var g_r := Vector3(0.27, 1.0, -0.2 - plant) * k
	var d_r := Vector3(0.04, 1.0, 0.22 - plant)
	var u_r := Vector3(0, 0, -1)
	if _v.get("hang_r") == true:
		# a tool that hangs from the fist (the Anchoress's anchor on its chain): held low and out, the chain down; the
		# wind-up then hauls it up over the shoulder and the strike brings it over and down like a crook
		g_r = Vector3(0.25, 0.9 + 0.02 * sr, -0.16 - plant) * k
		d_r = Vector3(0.05 * sr, -1.0, -0.12)
		u_r = Vector3(0, 0, -1)
	var g_l := Vector3(-0.24, 0.84 + 0.02 * absf(sr), -0.2 + 0.05 * sr) * k
	var d_l := Vector3(0, 0, -1)
	var u_l := Vector3(0, -1, 0)
	var shift := Vector3.ZERO
	var lean := 0.0
	var arch := 0.0
	match _mode:
		&"windup":
			var u := clampf(_mt / maxf(_mlen, 0.05), 0.0, 1.0)
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			var tr := sin(_t * 37.0) * 0.006 * smoothstep(0.9, 1.0, u)
			g_r = g_r.lerp(Vector3(0.22, 1.66 + tr, 0.1) * k, e)
			d_r = d_r.lerp(Vector3(0.12, 0.42, 0.9), e)
			u_r = u_r.lerp(Vector3(0, 0.4, -1), e)
			g_l = g_l.lerp(Vector3(-0.3, 1.22, -0.3) * k, e)
			arch = 0.16 * e
			head_pitch -= 0.1 * e
			off -= 0.025 * k * sin(PI * minf(u * 1.6, 1.0))
		&"strike":
			var u := _mt / STRIKE_LEN
			var hit := smoothstep(0.0, 0.12, u)                      # the blow
			var back := smoothstep(0.45, 0.95, u)                     # and back to the stance
			var ring := exp(-9.0 * maxf(u - 0.12, 0.0)) * sin(TAU * 3.0 * maxf(u - 0.12, 0.0) / 0.3) * (1.0 - back)
			var w := hit * (1.0 - back)
			var up_g := Vector3(0.22, 1.66, 0.1) * k
			var dn_g := Vector3(0.1, 0.78 + 0.02 * ring, -0.62) * k
			var g := up_g.lerp(dn_g, hit)
			g_r = g.lerp(g_r, back)
			d_r = Vector3(0.12, 0.42, 0.9).lerp(Vector3(0.0, -0.42, -0.9), hit).lerp(d_r, back)
			u_r = Vector3(0, 0.4, -1).lerp(Vector3(0, 0.9, -0.4), hit).lerp(u_r, back)
			g_l = Vector3(-0.3, 1.22, -0.3).lerp(Vector3(-0.36, 1.0, 0.12), hit).lerp(g_l / k, back) * k
			lean = 0.42 * w
			head_pitch -= 0.3 * w
			shift = Vector3(0, 0, -0.14 * k * w)
			off += _crouch(0.32 * w)
		&"stagger":
			var u := _mt / STAGGER_LEN
			var hitb := exp(-6.0 * u) * (1.0 - smoothstep(0.0, 0.03, -u))
			var fold := smoothstep(0.1, 0.3, u) * (1.0 - smoothstep(0.7, 0.98, u))
			var loll := sin(TAU * 1.4 * u + 0.5) * fold
			arch = 0.3 * hitb - 0.1 * fold
			lean = 0.38 * fold
			head_pitch += -0.35 * hitb + 0.5 * fold + 0.12 * loll
			g_r = g_r.lerp(Vector3(0.18, 0.95, -0.42) * k, fold)
			d_r = d_r.lerp(Vector3(0.0, 1.0, 0.35), fold)
			g_l = g_l.lerp(Vector3(-0.18, 1.0, -0.4) * k, fold)
			shift = Vector3(0, 0, 0.12 * k * hitb)
			off += _crouch(0.25 * fold)
		&"howl":
			var u := clampf(_mt / maxf(_mlen, 0.2), 0.0, 1.0)
			var up := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.82, 1.0, u))
			var q := sin(_t * 41.0) * 0.008 * up
			g_r = g_r.lerp(Vector3(0.2, 1.95 + q, -0.08) * k, up)
			d_r = d_r.lerp(Vector3(0.05, 1.0, 0.1), up)
			g_l = g_l.lerp(Vector3(-0.3, 1.55 + q, -0.32) * k, up)
			arch = 0.2 * up
			head_pitch -= 0.55 * up
		&"death":
			# he sags onto the staff, knees soft, head down; then goes over forward like a felled tree, the legs
			# straightening under him (down on his knees the robe could not follow the thighs, and tipped over from
			# there the folded legs stood up in the air)
			var u := clampf(_mt / DEATH_LEN, 0.0, 1.0)
			var sag := smoothstep(0.05, 0.35, u) * (1.0 - smoothstep(0.5, 0.75, u))
			var over := smoothstep(0.45, 0.8, u)
			over = over * over * (3.0 - 2.0 * over)
			head_pitch += 0.55 * smoothstep(0.05, 0.4, u)
			lean = 0.35 * sag + 0.1 * over
			off += _crouch(0.3 * sag)
			off = lerpf(off, 0.0, smoothstep(0.25, 0.6, u)) if hover > 0.0 else off       # a floating body sinks first
			g_r = g_r.lerp(Vector3(0.2, 0.85, -0.4) * k, smoothstep(0.05, 0.35, u))
			d_r = d_r.lerp(Vector3(0.0, 1.0, 0.25), smoothstep(0.05, 0.35, u))
			g_l = g_l.lerp(Vector3(-0.26, 0.7, -0.25) * k, smoothstep(0.05, 0.35, u))
			_v.rotation.x = -1.42 * over
			shift = Vector3(0, 0.1 * k * over, 0)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -lean * 0.45 + arch * 0.4))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.RIGHT, -lean * 0.55 + arch * 0.6))
	if _walk > 0.001:
		var c := cos(TAU * _gait)
		r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.UP, -0.06 * c * _walk) * Quaternion(Vector3.FORWARD, 0.035 * c * _walk))
		r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.1 * c * _walk))
	r.hold(0, g_r, d_r, u_r)
	r.hold(1, g_l, d_l, u_l)
	r.q(B_HEAD, Quaternion(Vector3.RIGHT, -head_pitch))
	r.q(B_LID, Quaternion(Vector3.RIGHT, 0.25))          # heavy lids: he does not blink at you
	if not _dead:
		_v.rotation = Vector3(-_flinch * 0.1, 0.0, _flinch * _flinch_side * 0.12)
	_v.position = Vector3(shift.x, off, shift.z) if not _dead else Vector3(0, off * cos(_v.rotation.x), 0) + shift
	r.apply()
	r.update_glow()
	if not _glints.is_empty():
		r.fk_all()
		for gl: Array in _glints:
			(gl[0] as Node3D).position = r.carry(int(gl[1]), gl[2])
	_place_sockets()


## The legs: walking, or standing with the weight on one leg. Returns the pelvis drop.
func _legs(k: float, sw: float) -> float:
	var r: Variant = _v
	if _walk > 0.001:
		return Life.walk_legs(r, _gait, _walk, GAIT[0], GAIT[1], float(GAIT[2]) * k)
	r.q(B_THIGH_R, Quaternion(Vector3.BACK, sw * 0.012) * Quaternion(Vector3.RIGHT, 0.04 * maxf(sw, 0.0)))
	r.q(B_THIGH_L, Quaternion(Vector3.BACK, sw * 0.012) * Quaternion(Vector3.RIGHT, 0.04 * maxf(-sw, 0.0)))
	r.q(B_SHIN_R, Quaternion(Vector3.RIGHT, -0.03 - 0.1 * maxf(sw, 0.0)))
	r.q(B_SHIN_L, Quaternion(Vector3.RIGHT, -0.03 - 0.1 * maxf(-sw, 0.0)))
	return -0.006 * absf(sw) * k


## Bend both knees by `a` (the thighs forward, the shins back twice as far): the drop that keeps the feet on the floor.
func _crouch(a: float) -> float:
	var r: Variant = _v
	for bt: int in [B_THIGH_R, B_THIGH_L]:
		r.q(bt, (r.get_q(bt) as Quaternion) * Quaternion(Vector3.RIGHT, a))
		r.q(bt + 1, (r.get_q(bt + 1) as Quaternion) * Quaternion(Vector3.RIGHT, -2.0 * a))
	return -Life.leg_len(r) * 0.5 * (1.0 - cos(a)) * 2.0


func _place_sockets() -> void:
	var sk := _v.get("skeleton") as Skeleton3D
	if sk == null:
		return
	var rel := _v.transform * sk.transform                 # skeleton space -> this rig's space
	for n: String in _sock_nodes:
		var b: int = SOCKETS[n]
		var xf := rel * sk.get_bone_global_pose(b)
		(_sock_nodes[n] as Node3D).transform = Transform3D(Basis.IDENTITY.scaled(xf.basis.get_scale()), xf.origin)
