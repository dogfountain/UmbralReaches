extends Spitter
## Cinder Caster (r34, the Founder's Pits): the bell-founders' hollowed, their throat-sacs full of slag
## instead of bile. It never spits straight: every shot is a CINDER HURL -- a long cast (the bar reads
## "Cinder Hurl"), a wide disc filling under you, and a burning patch of slag where it lands that
## stays a while. Break the cast (any blow) or step out of the disc; do not fight in the slag.
## In a pack it stands behind the Bulwarks by the furnace (Spitter's guard-keeping), so the answer
## is to go round the shields or shoot the caster first -- WoW's "kill the caster behind the tank".
## On the Spitter's rig and modelled body, darker and ember-rimmed, the sac glowing orange.
## No class_name (project rule): EnemySpawner.KIN and Tiers.KIND_PATHS load it by path.

const Variants := preload("res://core/life/encounters/variants.gd")
const EMBER := Color(2.4, 0.75, 0.15)
const SLAG := Color(0.16, 0.13, 0.12)
const HURL_R := 2.1
const BURN_T := 4.0
var look_kind := "spitter"         ## Variants dress it as a spitter
static var _mat: ShaderMaterial
static var _sac_mat: ShaderMaterial
static var _slag_parts: Dictionary = {}


func _init() -> void:
	super._init()
	max_hp = 3
	hp = 3.0
	walk_speed = 2.5
	kite_min = 7.0
	kite_max = 12.0
	fire_range = 18.0
	lob_windup = 1.15                # a long, readable cast: the interrupt window
	lob_flight = 0.9
	spit_cooldown = 3.4
	spit_gloom = 14.0
	hp_bar_y = 2.0
	poise = 1.2
	spit_cast = "Cinder Hurl"


func _build() -> void:
	super._build()
	name = "CinderCaster"
	if _rig:
		_rig.scale = Vector3(0.95, 1.02, 0.95)
	_tint()
	_slag()


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
		_mat.set_shader_parameter("rim_col", Color(1.3, 0.45, 0.12))
		_mat.set_shader_parameter("rim_amount", 0.4)
		_mat.set_shader_parameter("eye_col", EMBER)
		_mat.set_shader_parameter("pulse_rate", 1.6)
	for mi in _flesh:
		if is_instance_valid(mi) and mi != _sac:
			mi.material_override = _mat
	if _sac and _sac.mesh and _sac.mesh.material is ShaderMaterial:
		if _sac_mat == null:
			_sac_mat = (_sac.mesh.material as ShaderMaterial).duplicate() as ShaderMaterial
			_sac_mat.set_shader_parameter("glow", Color(1.0, 0.38, 0.06))
			_sac_mat.set_shader_parameter("skin", Color(0.32, 0.2, 0.13))
		_sac.material_override = _sac_mat


## A crust of slag over its shoulders and back, cracked through with ember (CreatureMesh parts, cached).
func _slag() -> void:
	if _rig == null:
		return
	if _slag_parts.is_empty():
		_slag_parts = Variants.cached("cinder_slag_v1", _build_slag, "res://core/enemy/cinder_caster.gd")
	var mat := Variants.material("cinder", "spitter", EMBER)
	var got: Array[MeshInstance3D] = []
	got.append_array(_flesh)
	for sock: String in _slag_parts:
		var at := _rig.socket(sock)
		if at == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Slag_" + sock
		mi.mesh = _slag_parts[sock]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(mi)
		got.append(mi)
	set_flesh(got)


static func _build_slag() -> Dictionary:
	var parts := {}
	var c := Variants.cm(5517)
	for k in 5:
		var a := -0.9 + 0.45 * float(k)
		var at := Vector3(sin(a) * 0.12, 0.12 - 0.05 * absf(a), 0.08 + cos(a) * 0.04)
		c.plate(at, Vector3(0.07, 0.03, 0.06), Vector3(sin(a) * 0.5, 1.0, 0.6), SLAG, 1.0, 0.25)
		c.tube(PackedVector3Array([at + Vector3(-0.04, 0.03, 0.0), at + Vector3(0.0, 0.035, 0.02), at + Vector3(0.04, 0.03, 0.0)]),
			PackedFloat32Array([0.004, 0.006, 0.004]), 4, Color(2.2, 0.7, 0.15), 0.0, 0.0, 1.0)
	parts["chest"] = c.commit()
	for side: String in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var a2 := Variants.cm(5518 + (1 if side == "l" else 2))
		a2.plate(Vector3(sx * 0.02, 0.04, 0.0), Vector3(0.075, 0.035, 0.075), Vector3(sx * 0.4, 1.0, 0.0), SLAG, 1.0, 0.3)
		a2.blob(Vector3(sx * 0.04, 0.07, 0.0), Vector3(0.012, 0.01, 0.03), Basis.IDENTITY, Color(2.2, 0.7, 0.15), 0.0, 0.0, 1.0, 3, 6)
		parts["shoulder_" + side] = a2.commit()
	return parts


## Every shot is a hurl (it ignores the straight spit).
func _on_state(next: int) -> void:
	if next != WINDUP:
		super._on_state(next)
		return
	_lobbing = true
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", lob_windup)
	_glint = 1.0
	begin_cast("Cinder Hurl", lob_windup, true)
	Sfx.play_stream(Synth.voice(voice_family(), "tell"), global_position + Vector3.UP, -2.0, 0.8)
	if _p:
		var target := _lob_target()
		set_meta(&"lob_at", target)
		AttackKit.zone(self, target, lob_windup + lob_flight, spit_gloom, {"radius": HURL_R, "color": AttackKit.RED, "fx": "blast", "release": lob_windup,
			"on_land": AttackKit.linger.bind(target, HURL_R * 0.8, BURN_T, 4.0 * Tiers.dmg_of(self), 0.5, EMBER)})


func _lob() -> void:
	var to: Vector3 = get_meta(&"lob_at", _p.global_position if _p else global_position)
	var from := _sac.global_position if _sac else global_position + Vector3.UP * 1.45
	AttackKit.lob(from, to, lob_flight, EMBER)
	Sfx.play("res://art/audio/spit.wav", from, -3.0, 0.6)
	_lobbing = false


func _spit() -> void:
	_lob()


func _ichor() -> Color:
	return Color(0.3, 0.1, 0.03)
