extends Enemy
## A TALLY (r34 crypt, docs/r34/raid_crypt.md): one of the three reliquaries the Bone Abbot raises in
## the pit hall's chapels while he lies in the mound (his intermission, "The Count Is Taken"). An iron
## casket on bone legs, a skull in a cage of grave-light; a thread of that light runs from it to the
## mound: it feeds him. Break all three and the count breaks early; each still standing when he rises
## heals him and hardens his blows (BoneAbbot._end_intermission). It never moves and never strikes.
## No class_name (project rule): the Abbot loads it by path.

const GRAVE := Color(0.62, 0.8, 0.68)

var feed_to := Vector3.INF          ## the mound's top: the thread's far end
var _beam: MeshInstance3D
var _core: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0
static var _beam_mat: StandardMaterial3D
static var _core_mat: StandardMaterial3D


func _init() -> void:
	max_hp = 7
	glow_col = Color(2.2, 1.8, 1.2)
	hp = 7.0
	walk_speed = 0.0
	chase_range = 0.0
	strike_range = 0.0
	sleep_range = 999.0
	hunt_leash = 999.0
	light_averse = false
	can_call = false
	can_flee = false
	mass = 100.0
	poise = 999.0
	hp_bar_y = 2.7
	gravity = 0.0


func _build() -> void:
	name = "Tally"
	set_meta(&"display_name", "Tally of the Count")
	set_meta(&"no_leash", true)
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.75
		cap.height = 2.3
		col.shape = cap
		col.position.y = 1.15
	var iron := OssKit.mat("iron")
	var bone := OssKit.mat("bone")
	if _core_mat == null:
		_core_mat = StandardMaterial3D.new()
		_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_core_mat.albedo_color = GRAVE
		_core_mat.emission_enabled = true
		_core_mat.emission = GRAVE
		_core_mat.emission_energy_multiplier = 1.1
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.albedo_color = Color(GRAVE.r * 0.55, GRAVE.g * 0.55, GRAVE.b * 0.55, 0.6)
		_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# casket on four bone legs, a crown of iron bars, the skull inside, its grave-light
	_part(Vector3(0, 0.75, 0), Vector3(1.0, 0.5, 0.7), iron)
	_part(Vector3(0, 1.03, 0), Vector3(0.9, 0.06, 0.6), bone)
	for x: float in [-0.42, 0.42]:
		for z: float in [-0.27, 0.27]:
			_part(Vector3(x, 0.25, z), Vector3(0.1, 0.5, 0.1), bone)
			_part(Vector3(x * 0.85, 1.55, z * 0.85), Vector3(0.05, 1.0, 0.05), iron)
	_part(Vector3(0, 2.07, 0), Vector3(0.82, 0.06, 0.55), iron)
	var sk := MeshInstance3D.new()
	sk.mesh = OssKit.skull_mesh()
	sk.material_override = bone
	sk.scale = Vector3.ONE * 2.2
	sk.position = Vector3(0, 1.12, 0)
	_visual.add_child(sk)
	_core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	_core.mesh = sm
	_core.material_override = _core_mat
	_core.position = Vector3(0, 1.62, 0)
	_visual.add_child(_core)
	_light = OmniLight3D.new()
	_light.light_color = GRAVE
	_light.omni_range = 3.5
	_light.light_energy = 0.4
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.7, 0)
	add_child(_light)
	_beam = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 1.0)
	_beam.mesh = bm
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	add_child(_beam)


func _part(at: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	_visual.add_child(mi)


func _physics_process(delta: float) -> void:
	if _state == DEAD:
		return
	_t += delta
	velocity = Vector3.ZERO
	_flash_visual(delta)
	_tick_hp_trail(delta)
	if _hp_bar:
		_hp_bar.visible = true
		_tick_bar_poise()
	var pulse := 0.5 + 0.5 * sin(_t * 3.1)
	if _light:
		_light.light_energy = 0.35 + 0.2 * pulse
	if _core:
		_core.scale = Vector3.ONE * (0.9 + 0.25 * pulse)
	if _beam and feed_to != Vector3.INF:
		var a := global_position + Vector3.UP * 1.62
		var d := feed_to - a
		if d.length() > 0.5:
			_beam.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT).scaled(Vector3(1.0 + pulse * 0.6, 1.0 + pulse * 0.6, d.length())), a + d * 0.5)
	if marks > 0:
		_mark_t -= delta
		if _mark_t <= 0.0:
			marks = 0
			_refresh_pips()


func _die() -> void:
	if _beam:
		_beam.visible = false
	if _light:
		_light.visible = false
	Vfx.burst(global_position + Vector3.UP * 1.6, GRAVE, {"count": 40, "life": 0.8, "speed": Vector2(2.0, 6.0), "size": 0.05, "gravity": -3.0, "trail": 0.06})
	Vfx.burst(global_position + Vector3.UP * 1.0, Color(0.85, 0.8, 0.7), {"count": 30, "life": 0.9, "speed": Vector2(2.0, 5.5), "size": 0.07, "gravity": -9.0, "additive": false})
	HitText.pop(global_position + Vector3.UP * 3.2, "the tally breaks", GRAVE, true)
	super._die()


func _hit_sound() -> String:
	return "bone"


func voice_family() -> String:
	return "reliquary"


func _ichor() -> Color:
	return Color(0.75, 0.7, 0.6)


func rank() -> String:
	return "elite"
