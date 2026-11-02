class_name MagicBolt
extends CharacterBody3D
## Violet bolt from the staff. Flies until it hits the world or a shade, then bursts.

const SPEED := 28.0
const LIFE := 2.6
const BLAST := 1.2
const HIT_DMG := 1.0

var direction := Vector3.FORWARD
var speed := SPEED
var blast := BLAST
var hit_dmg := HIT_DMG
var heavy := false

var _age := 0.0
var _spent := false
var _core: MeshInstance3D
var _light: OmniLight3D
var _trail: GPUParticles3D
var _probe := SphereShape3D.new()
var _hit_ids: Dictionary = {}
static var _burst_pool: Array[GPUParticles3D] = []


func _ready() -> void:
	name = "MagicBolt"
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.HURTBOX
	motion_mode = MOTION_MODE_FLOATING
	var col := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.22 if heavy else 0.14
	col.shape = ball
	add_child(col)
	_build_visual()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= LIFE:
		explode(global_position)
		return
	if _hurt_radius(1.35 if heavy else 1.05):
		explode(global_position)
		return
	var hit := move_and_collide(direction * speed * delta)
	if hit:
		_apply_hit(hit.get_collider())
		explode(hit.get_position())


func explode(at: Vector3) -> void:
	if _spent:
		return
	_spent = true
	global_position = at
	_hurt_radius(blast)
	if _core:
		_core.visible = false
	if _trail:
		_trail.emitting = false
	_burst(at)
	var flash := _light
	if flash:
		flash.light_energy = 2.4
		flash.omni_range = 7.0
		var tw := create_tween()
		tw.tween_property(flash, "light_energy", 0.0, 0.28)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	queue_free()


func _hurt_radius(radius: float) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	_probe.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = global_transform
	q.collision_mask = Layers.HURTBOX
	q.collide_with_bodies = true
	q.collide_with_areas = true
	var any := false
	for item in space.intersect_shape(q, 8):
		if _apply_hit(item.get("collider")):
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
			n.take_hit(hit_dmg, self)
			return true
		n = n.get_parent()
	return false


func _build_visual() -> void:
	var core_col := Color(1.7, 0.55, 0.42) if heavy else Color(1.35, 0.7, 3.4)
	var glow := ProcMesh.glow_mat(core_col)
	var core_r := 0.16 if heavy else 0.09
	_core = ProcMesh.mesh(self, "Core", ProcMesh.sphere(core_r, core_r * 2.0, 12, 8), glow, Vector3.ZERO, Vector3.ZERO, false)
	var shell := ProcMesh.glow_mat(Color(0.85, 0.32, 0.22, 0.5) if heavy else Color(0.55, 0.28, 1.15, 0.45))
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var aura_r := 0.28 if heavy else 0.16
	ProcMesh.mesh(self, "Aura", ProcMesh.sphere(aura_r, aura_r * 2.0, 10, 6), shell, Vector3.ZERO, Vector3.ZERO, false)

	_light = OmniLight3D.new()
	_light.name = "BoltLight"
	_light.light_color = Color("#FF7A4A") if heavy else Color("#A98BFF")
	_light.light_energy = 1.85 if heavy else 1.15
	_light.omni_range = 5.4 if heavy else 3.8
	_light.shadow_enabled = false
	_light.set_meta("light_class", "player_orb")
	add_child(_light)

	_trail = _particles(false)
	add_child(_trail)
	var flare := MeshInstance3D.new()
	flare.name = "Flare"
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	var fmat := ShaderMaterial.new()
	fmat.shader = load("res://world/flare.gdshader")
	fmat.set_shader_parameter("color", Color(1.05, 0.62, 2.8))
	q.material = fmat
	flare.mesh = q
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flare)


func _burst(at: Vector3) -> void:
	var bang := _take_burst()
	bang.global_position = at
	bang.restart()
	bang.emitting = true

	var shock := MeshInstance3D.new()
	shock.name = "Shock"
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	sphere.radial_segments = 14
	sphere.rings = 8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.72, 0.42, 1.35, 0.55)
	mat.disable_receive_shadows = true
	shock.mesh = sphere
	shock.material_override = mat
	shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var host2 := get_tree().current_scene
	if host2:
		host2.add_child(shock)
		shock.global_position = at
	var tw := shock.create_tween()
	tw.set_parallel(true)
	tw.tween_property(shock, "scale", Vector3.ONE * 6.5, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.32)
	tw.chain().tween_callback(shock.queue_free)


func _take_burst() -> GPUParticles3D:
	for p in _burst_pool:
		if is_instance_valid(p) and not p.emitting:
			return p
	var bang := _particles(true)
	var host := get_tree().current_scene
	if host:
		host.add_child(bang)
	else:
		add_child(bang)
	_burst_pool.append(bang)
	return bang


func _particles(burst: bool) -> GPUParticles3D:
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
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.11) if burst else Vector2(0.07, 0.07)
	q.material = load("res://art/materials/rift_mote_particle.tres")
	p.draw_pass_1 = q
	return p
