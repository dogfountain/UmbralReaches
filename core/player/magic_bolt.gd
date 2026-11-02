class_name MagicBolt
extends CharacterBody3D
## Violet bolt from the staff. Flies until it hits the world or a shade, then bursts.

const SPEED := 28.0
const LIFE := 2.6
const BLAST := 1.2
const HIT_DMG := 1.0
const FLARE_SHADER := preload("res://world/flare.gdshader")
const MOTE := preload("res://art/materials/rift_mote_particle.tres")
const IMPACT_SFX := preload("res://art/audio/bolt_impact.wav")

var direction := Vector3.FORWARD
var speed := SPEED
var blast := BLAST
var hit_dmg := HIT_DMG
var heavy := false
var marks := 0            ## Umbral Marks applied per hit (Rift Bolt)
var pierce := false       ## pass through bodies, burst only on the world (full Ember Lance)

var _age := 0.0
var _spent := false
var _core: MeshInstance3D
var _aura: MeshInstance3D
var _light: OmniLight3D
var _trail: GPUParticles3D
var _hurt: Area3D
var _hurt_shape: SphereShape3D
var _hit_ids: Dictionary = {}
var _pooled := false
var _sfx: AudioStreamPlayer3D
var _excepted: Array[PhysicsBody3D] = []

static var _core_mesh: SphereMesh
static var _core_mesh_h: SphereMesh
static var _aura_mesh: SphereMesh
static var _aura_mesh_h: SphereMesh
static var _glow: Material
static var _glow_h: Material
static var _shell: Material
static var _shell_h: Material
static var _trail_pm: ParticleProcessMaterial
static var _burst_pm: ParticleProcessMaterial
static var _trail_quad: QuadMesh
static var _burst_quad: QuadMesh
static var _shock_mesh: SphereMesh
static var _shock_mat: StandardMaterial3D
static var _flare_mesh: QuadMesh


func _ready() -> void:
	name = "MagicBolt"
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.HURTBOX
	motion_mode = MOTION_MODE_FLOATING
	var col := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.14
	col.shape = ball
	add_child(col)
	_hurt = Area3D.new()
	_hurt.name = "Hurt"
	_hurt.collision_layer = 0
	_hurt.collision_mask = Layers.HURTBOX
	_hurt.monitoring = true
	_hurt.monitorable = false
	var hcol := CollisionShape3D.new()
	_hurt_shape = SphereShape3D.new()
	_hurt_shape.radius = 1.05
	hcol.shape = _hurt_shape
	_hurt.add_child(hcol)
	add_child(_hurt)
	_ensure_shared()
	_build_visual()


func arm(is_heavy: bool) -> void:
	heavy = is_heavy
	if heavy:
		hit_dmg = 3.0
		blast = 2.6
		speed = 18.0
	else:
		hit_dmg = HIT_DMG
		blast = BLAST
		speed = SPEED
	_age = 0.0
	_spent = false
	_hit_ids.clear()
	_pooled = false
	marks = 0
	pierce = false
	for b in _excepted:
		if is_instance_valid(b):
			remove_collision_exception_with(b)
	_excepted.clear()
	if _aura:
		_aura.scale = Vector3.ONE
	if _hurt_shape:
		_hurt_shape.radius = 1.35 if heavy else 1.05
	if _core:
		_core.visible = true
		_core.mesh = _core_mesh_h if heavy else _core_mesh
		_core.material_override = _glow_h if heavy else _glow
	if _aura:
		_aura.mesh = _aura_mesh_h if heavy else _aura_mesh
		_aura.material_override = _shell_h if heavy else _shell
	if _trail:
		_trail.emitting = true
	if _light:
		_light.light_color = Color("#FF7A4A") if heavy else Color("#A98BFF")
		_light.light_energy = 1.85 if heavy else 1.15
		_light.omni_range = 5.4 if heavy else 3.8
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


## Skill-facing arm: heavy look + explicit numbers. Missing keys keep arm()'s defaults.
func arm_with(cfg: Dictionary) -> void:
	arm(bool(cfg.get("heavy", false)))
	hit_dmg = float(cfg.get("dmg", hit_dmg))
	blast = float(cfg.get("blast", blast))
	speed = float(cfg.get("speed", speed))
	marks = int(cfg.get("marks", 0))
	pierce = bool(cfg.get("pierce", false))
	if pierce and _aura:
		_aura.scale = Vector3.ONE * 1.5


func reset_idle() -> void:
	_spent = true
	_age = 0.0
	_hit_ids.clear()
	_pooled = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if _trail:
		_trail.emitting = false
	if _core:
		_core.visible = true
	if _light:
		_light.light_energy = 1.15


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= LIFE:
		explode(global_position)
		return
	if _hurt_near() and not pierce:
		explode(global_position)
		return
	var hit := move_and_collide(direction * speed * delta)
	if hit:
		var col := hit.get_collider()
		var hurt := _apply_hit(col)
		if pierce and hurt and col is PhysicsBody3D:
			add_collision_exception_with(col)
			_excepted.append(col as PhysicsBody3D)
		else:
			explode(hit.get_position())


func explode(at: Vector3) -> void:
	if _spent:
		return
	_spent = true
	global_position = at
	if _hurt_shape:
		_hurt_shape.radius = blast
	_hurt_near()
	if _core:
		_core.visible = false
	if _trail:
		_trail.emitting = false
	_burst(at)
	_play_impact()
	var flash := _light
	if flash:
		flash.light_energy = 2.4
		flash.omni_range = 7.0
		var tw := create_tween()
		tw.tween_property(flash, "light_energy", 0.0, 0.28)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	var pool := get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	if pool:
		pool.release(self)
	else:
		queue_free()


func _hurt_near() -> bool:
	if _hurt == null:
		return false
	var any := false
	for n in _hurt.get_overlapping_bodies():
		if _apply_hit(n):
			any = true
	for n in _hurt.get_overlapping_areas():
		if _apply_hit(n):
			any = true
	return any


func _apply_hit(node: Object) -> bool:
	var n := node as Node
	while n:
		if n.has_method("take_hit"):
			var id := n.get_instance_id()
			if _hit_ids.has(id):
				return true
			_hit_ids[id] = true
			if marks > 0 and n.has_method("add_mark"):
				n.add_mark(marks)
			n.take_hit(hit_dmg, self)
			return true
		n = n.get_parent()
	return false


func _build_visual() -> void:
	_core = MeshInstance3D.new()
	_core.name = "Core"
	_core.mesh = _core_mesh
	_core.material_override = _glow
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_aura = MeshInstance3D.new()
	_aura.name = "Aura"
	_aura.mesh = _aura_mesh
	_aura.material_override = _shell
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)
	_light = OmniLight3D.new()
	_light.name = "BoltLight"
	_light.light_color = Color("#A98BFF")
	_light.light_energy = 1.15
	_light.omni_range = 3.8
	_light.shadow_enabled = false
	_light.set_meta("light_class", "player_orb")
	add_child(_light)
	_trail = make_particles(false)
	add_child(_trail)
	var flare := MeshInstance3D.new()
	flare.name = "Flare"
	flare.mesh = _flare_mesh
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flare)


static func _ensure_shared() -> void:
	if _core_mesh != null:
		return
	_core_mesh = SphereMesh.new()
	_core_mesh.radius = 0.09
	_core_mesh.height = 0.18
	_core_mesh.radial_segments = 12
	_core_mesh.rings = 8
	_core_mesh_h = SphereMesh.new()
	_core_mesh_h.radius = 0.16
	_core_mesh_h.height = 0.32
	_core_mesh_h.radial_segments = 12
	_core_mesh_h.rings = 8
	_aura_mesh = SphereMesh.new()
	_aura_mesh.radius = 0.16
	_aura_mesh.height = 0.32
	_aura_mesh.radial_segments = 10
	_aura_mesh.rings = 6
	_aura_mesh_h = SphereMesh.new()
	_aura_mesh_h.radius = 0.28
	_aura_mesh_h.height = 0.56
	_aura_mesh_h.radial_segments = 10
	_aura_mesh_h.rings = 6
	_glow = ProcMesh.glow_mat(Color(1.35, 0.7, 3.4))
	_glow_h = ProcMesh.glow_mat(Color(1.7, 0.55, 0.42))
	_shell = ProcMesh.glow_mat(Color(0.55, 0.28, 1.15, 0.45))
	_shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_h = ProcMesh.glow_mat(Color(0.85, 0.32, 0.22, 0.5))
	_shell_h.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_pm = _particle_mat(false)
	_burst_pm = _particle_mat(true)
	_trail_quad = QuadMesh.new()
	_trail_quad.size = Vector2(0.07, 0.07)
	_trail_quad.material = MOTE
	_burst_quad = QuadMesh.new()
	_burst_quad.size = Vector2(0.11, 0.11)
	_burst_quad.material = MOTE
	_shock_mesh = SphereMesh.new()
	_shock_mesh.radius = 0.2
	_shock_mesh.height = 0.4
	_shock_mesh.radial_segments = 14
	_shock_mesh.rings = 8
	_shock_mat = StandardMaterial3D.new()
	_shock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shock_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shock_mat.albedo_color = Color(0.72, 0.42, 1.35, 0.55)
	_shock_mat.disable_receive_shadows = true
	_flare_mesh = QuadMesh.new()
	_flare_mesh.size = Vector2(0.55, 0.55)
	var fmat := ShaderMaterial.new()
	fmat.shader = FLARE_SHADER
	fmat.set_shader_parameter("color", Color(1.05, 0.62, 2.8))
	_flare_mesh.material = fmat


static func make_particles(burst: bool) -> GPUParticles3D:
	_ensure_shared()
	var p := GPUParticles3D.new()
	p.name = "Burst" if burst else "Trail"
	p.amount = 42 if burst else 36
	p.lifetime = 0.45 if burst else 0.35
	p.one_shot = burst
	p.emitting = not burst
	p.explosiveness = 0.95 if burst else 0.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = _burst_pm if burst else _trail_pm
	p.draw_pass_1 = _burst_quad if burst else _trail_quad
	return p


static func make_shock() -> MeshInstance3D:
	_ensure_shared()
	var shock := MeshInstance3D.new()
	shock.name = "Shock"
	shock.mesh = _shock_mesh
	shock.material_override = _shock_mat.duplicate()
	shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shock.visible = false
	return shock


func _burst(at: Vector3) -> void:
	var pool := get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	var bang: GPUParticles3D
	if pool:
		bang = pool.take_burst()
	else:
		bang = make_particles(true)
		var host := get_tree().current_scene
		if host:
			host.add_child(bang)
	bang.global_position = at
	bang.restart()
	bang.emitting = true
	var shock: MeshInstance3D
	if pool:
		shock = pool.take_shock()
	else:
		shock = make_shock()
		var host2 := get_tree().current_scene
		if host2:
			host2.add_child(shock)
	shock.visible = true
	shock.scale = Vector3.ONE
	shock.global_position = at
	var mat := shock.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color.a = 0.55
	var tw := shock.create_tween()
	tw.set_parallel(true)
	tw.tween_property(shock, "scale", Vector3.ONE * 6.5, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if mat:
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.32)
	tw.chain().tween_callback(func() -> void:
		shock.visible = false
		shock.scale = Vector3.ONE
	)


## One player per bolt, made once. The old version added a new AudioStreamPlayer3D on every
## explosion and never freed it, so pooled bolts piled up players.
func _play_impact() -> void:
	if _sfx == null:
		_sfx = AudioStreamPlayer3D.new()
		_sfx.stream = IMPACT_SFX
		_sfx.max_distance = 24.0
		add_child(_sfx)
	_sfx.pitch_scale = randf_range(0.85, 1.12) * (0.8 if heavy else 1.0)
	_sfx.play()


static func _particle_mat(burst: bool) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12 if burst else 0.05
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.4 if burst else 0.05
	pm.initial_velocity_max = 5.4 if burst else 0.2
	pm.gravity = Vector3(0, -1.2, 0) if burst else Vector3.ZERO
	pm.damping_min = 1.6 if burst else 0.4
	pm.damping_max = 3.2 if burst else 1.0
	pm.scale_min = 0.45
	pm.scale_max = 1.15
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 1.0, 1.0))
	ramp.add_point(0.4, Color(0.72, 0.4, 1.15, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.35, 0.12, 0.8, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	return pm
