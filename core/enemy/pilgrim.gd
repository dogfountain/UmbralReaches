extends Wretch
## Risen Pilgrim (r34, the Waiting Field): the pilgrims who died on the road were buried facing the
## mountain, to wait. Some got up. A Pilgrim lies under its own grave, sunk to the shoulders and bowed,
## until you walk among the stones:
##   rise    within RISE_R (or when struck, or when its packmate is pulled) the ground heaves round it
##           and it climbs out (RISE_T, no attack while it does: the beat to back off or strike first)
##   walk    then a slow, upright pilgrim with a staff-arm: a two-blow chain, an honest tell, no feint
## WoW's "dormant until you step close" graveyard mobs, in the valley's story. It is on the Wretch's
## rig and modelled body, upright, hooded, with a rope girdle and a stub of candle at its breast
## (candle-gold rim and eyes, so a field of them reads apart from the grey Wretches).
## No class_name (project rule): EnemySpawner.KIN and Tiers.KIND_PATHS load it by path.

const Variants := preload("res://core/life/encounters/variants.gd")
const GruntModel := preload("res://core/enemy/grunt_model.gd")
const RISE_R := 14.0
const RISE_T := 1.15
const SUNK := 1.3
const CLOTH := Color(0.33, 0.29, 0.24)
const CANDLE := Color(0.95, 0.9, 0.78)
const FLAME := Color(2.4, 1.5, 0.45)
var look_kind := "wretch"          ## Variants dress it as a wretch

var dormant := true                ## lying in its grave (tests and the spawner may clear it)
var _rising := -1.0                ## seconds into the rise (-1: not rising)
var _rig_y := 0.0
static var _mat: ShaderMaterial
static var _parts: Dictionary = {}


func _init() -> void:
	super._init()
	if GruntModel.has(&"pilgrim"):
		body_kind = &"pilgrim"           # its own modelled body (hooded cloak, candle, staff): no parts stuck on
	max_hp = 8
	hp = 4.0
	walk_speed = 2.7
	chase_range = 11.0
	hunt_leash = 14.0
	strike_gloom = 24.0
	windup_time = 0.55               # slower and plainer than a Wretch's rake
	combo_max = 1
	combo_chance = 0.45
	combo_windup = 0.4
	feint_chance = 0.0
	role = &""                        # not a flanker: it walks straight at you
	poise = 1.6
	mass = 1.0
	hp_bar_y = 2.0


func _build() -> void:
	super._build()
	name = "Pilgrim"
	posture({"hunch": 0.18, "crouch": 0.12, "arm_reach": 0.25, "head_jut": 0.35, "limp": 0.45, "sway": 0.25, "twitch": 0.15, "splay": 0.1})
	if _rig:
		_rig.scale = Vector3(0.96, 1.06, 0.96)
		_rig_y = _rig.position.y
	_tint()
	_dress()
	if dormant:
		_sink(1.0)


func _voice_pitch() -> float:
	return 0.9


## Candle-gold rim on its own copy of the Wretch's body material.
func _tint() -> void:
	if _mat == null:
		var base: Material = null
		for mi in _flesh:
			if is_instance_valid(mi) and mi.material_override != null:
				base = mi.material_override
				break
		if not (base is ShaderMaterial):
			return
		_mat = (base as ShaderMaterial).duplicate() as ShaderMaterial
		_mat.set_shader_parameter("rim_col", Color(1.0, 0.78, 0.42))
		_mat.set_shader_parameter("rim_amount", 0.3)
		_mat.set_shader_parameter("eye_col", Color(1.9, 1.35, 0.45))
	for mi in _flesh:
		if is_instance_valid(mi):
			mi.material_override = _mat


## Hood, rope girdle, the candle stub: CreatureMesh parts through the shared GenCache.
func _dress() -> void:
	if _rig == null or GruntModel.has(&"pilgrim"):
		return
	if _parts.is_empty():
		_parts = Variants.cached("pilgrim_parts_v2", _build_parts, "res://core/enemy/pilgrim.gd")
	var mat := Variants.material("pilgrim", "wretch", Color(1.9, 1.35, 0.45))
	var got: Array[MeshInstance3D] = []
	got.append_array(_flesh)
	for sock: String in _parts:
		var at := _rig.socket(sock)
		if at == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Pilgrim_" + sock
		mi.mesh = _parts[sock]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(mi)
		got.append(mi)
	set_flesh(got)


static func _build_parts() -> Dictionary:
	var parts := {}
	var h := Variants.cm(4411)
	# a deep hood, open at the face (-Z)
	h.blob(Vector3(0.0, 0.075, 0.05), Vector3(0.17, 0.165, 0.175), Basis.IDENTITY, CLOTH, 1.0, 0.06, 0.0, 7, 12, 0.8)
	h.tube(PackedVector3Array([Vector3(-0.13, -0.1, -0.05), Vector3(-0.14, 0.08, -0.09), Vector3(0.0, 0.22, -0.08), Vector3(0.14, 0.08, -0.09), Vector3(0.13, -0.1, -0.05)]),
		PackedFloat32Array([0.026, 0.03, 0.032, 0.03, 0.026]), 5, CLOTH, 1.0, 0.05, 0.0, Vector2.ONE, 0.8)
	# the hood's point, fallen back
	h.tube(PackedVector3Array([Vector3(0.0, 0.2, 0.1), Vector3(0.0, 0.16, 0.22), Vector3(0.0, 0.06, 0.28)]), PackedFloat32Array([0.06, 0.035, 0.0]), 6, CLOTH, 1.0, 0.05, 0.0, Vector2.ONE, 0.8)
	parts["head"] = h.commit()
	var c := Variants.cm(4412)
	var f := Variants.chest_front("wretch")
	# a pilgrim's mantle over the shoulders and the rope girdle
	c.blob(Vector3(0.0, 0.13, 0.03), Vector3(0.27, 0.1, 0.2), Basis.IDENTITY, CLOTH, 1.0, 0.08, 0.0, 5, 10, 0.8)
	c.blob(Vector3(0.0, 0.0, 0.08), Vector3(0.22, 0.2, 0.12), Basis.IDENTITY, CLOTH, 1.0, 0.08, 0.0, 5, 10, 0.8)    # the mantle down the back
	var rope := PackedVector3Array()
	var rr := PackedFloat32Array()
	for i in 9:
		var a := TAU * float(i) / 8.0
		rope.append(Vector3(cos(a) * 0.15, -0.2, sin(a) * 0.12))
		rr.append(0.012)
	c.tube(rope, rr, 4, Color(0.45, 0.36, 0.24), 0.0, 0.05, 0.0)
	c.tube(PackedVector3Array([Vector3(0.1, -0.2, -0.09), Vector3(0.12, -0.32, -0.1), Vector3(0.11, -0.42, -0.09)]),
		PackedFloat32Array([0.01, 0.01, 0.008]), 4, Color(0.45, 0.36, 0.24), 0.0, 0.05, 0.0)
	# the candle stub at its breast, lit
	c.tube(PackedVector3Array([Vector3(0.0, -0.04, -f - 0.04), Vector3(0.0, 0.04, -f - 0.045)]), PackedFloat32Array([0.018, 0.016]), 6, CANDLE, 1.0, 0.02, 0.0)
	c.blob(Vector3(0.0, 0.065, -f - 0.045), Vector3(0.01, 0.022, 0.01), Basis.IDENTITY, FLAME, 0.0, 0.0, 1.0, 4, 6)
	parts["chest"] = c.commit()
	return parts


# --- the grave ------------------------------------------------------------------------------------

func _sink(k: float) -> void:
	if _rig == null:
		return
	_rig.position.y = _rig_y - SUNK * k
	_rig.rotation.x = 0.4 * k                    # bowed toward the mountain


## Rise now (a hit, a pull, you walking in). The ground heaves; RISE_T later it can fight.
func rise() -> void:
	if not dormant or _rising >= 0.0 or _state == DEAD:
		return
	_rising = 0.0
	Vfx.burst(global_position + Vector3.UP * 0.2, Color(0.2, 0.16, 0.12, 0.95), {"count": 30, "life": 0.9, "speed": Vector2(1.5, 4.5), "size": 0.12, "gravity": -9.0, "additive": false, "radius": 0.5})
	Sfx.play_stream(Synth.get_stream("burrow"), global_position, -2.0, 0.8)
	say("windup", global_position + Vector3.UP, -4.0, _voice_pitch())


func is_risen() -> bool:
	return not dormant


func _think() -> void:
	if dormant:
		_wish = Vector3.ZERO
		if _rising >= 0.0:
			return
		if _p != null and _dist <= RISE_R and absf(_p.global_position.y - global_position.y) < 4.0:
			rise()
		return
	super._think()


func _physics_process(delta: float) -> void:
	if _rising >= 0.0 and _state != DEAD:
		_rising += delta
		var k := clampf(_rising / RISE_T, 0.0, 1.0)
		_sink(1.0 - k * k * (3.0 - 2.0 * k))
		if k >= 1.0:
			_rising = -1.0
			dormant = false
			_sink(0.0)
			_set_state(CHASE if _p != null and _dist <= chase_range * 1.4 else IDLE)
	super._physics_process(delta)


func alerted(by: Node) -> void:
	if dormant:
		if _p != null and _dist <= RISE_R:          # a grave you have left stays in the ground
			rise()
		return
	super.alerted(by)


func take_hit(dmg: float, from: Node = null) -> void:
	if dormant:
		rise()
	super.take_hit(dmg, from)


## A rest refills the field: a pilgrim that walked back to its grave lies down again.
func _end_evade() -> void:
	super._end_evade()
	if not dormant and _rising < 0.0:
		dormant = true
		_sink(1.0)
