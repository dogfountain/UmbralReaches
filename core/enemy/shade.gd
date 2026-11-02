class_name Shade
extends Node3D
## Born when Gloom reaches its cap. Drifts after the player; light unmakes it; its touch Hollows.

var target: Player
var speed := 5.2
var _t := 0.0
var _dying := false
var _body: Node3D


func _ready() -> void:
	add_to_group(Groups.SHADE)
	_body = Node3D.new()
	add_child(_body)
	var robe_mat := StandardMaterial3D.new()
	robe_mat.albedo_color = Color("#05040D")
	robe_mat.roughness = 1.0
	robe_mat.rim_enabled = true
	robe_mat.rim = 1.0
	robe_mat.rim_tint = 1.0
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(4.0, 1.2, 0.35)   # ember, HDR so it blooms

	var robe := CylinderMesh.new()
	robe.top_radius = 0.18
	robe.bottom_radius = 0.02
	robe.height = 1.9
	robe.radial_segments = 9
	_add_mesh(robe, robe_mat, Vector3(0.0, 0.0, 0.0))
	var hood := SphereMesh.new()
	hood.radius = 0.3
	hood.height = 0.62
	hood.radial_segments = 10
	hood.rings = 6
	_add_mesh(hood, robe_mat, Vector3(0.0, 1.05, 0.0))
	var eye := SphereMesh.new()
	eye.radius = 0.035
	eye.height = 0.07
	_add_mesh(eye, eye_mat, Vector3(-0.09, 1.05, -0.24))
	_add_mesh(eye, eye_mat, Vector3(0.09, 1.05, -0.24))

	var smoke := GPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.gravity = Vector3(0.0, 0.4, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.02, 0.01, 0.06, 0.55)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	g.gradient = grad
	sm.albedo_texture = g
	q.material = sm
	smoke.draw_pass_1 = q
	_body.add_child(smoke)

	var hb := StaticBody3D.new()
	hb.name = "Hurt"
	hb.collision_layer = Layers.HURTBOX
	hb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.55
	cs.shape = sph
	cs.position = Vector3(0.0, 0.6, 0.0)
	hb.add_child(cs)
	add_child(hb)

	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func take_hit(_dmg: float, _from: Node = null) -> void:
	if is_instance_valid(target):
		target.note_shade_bolt()
	dissipate()


func _add_mesh(mesh: Mesh, mat: Material, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)


func _physics_process(delta: float) -> void:
	_t += delta
	_body.position.y = sin(_t * 2.2) * 0.12
	if _dying or not is_instance_valid(target):
		return
	var goal := target.global_position + Vector3.UP * 0.9
	var to := goal - global_position
	var d := to.length()
	if d < 1.1:
		if not _blocked(target):
			target.hollow()
			dissipate()
		return
	global_position += to / d * speed * delta
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > 0.01:
		_body.rotation.y = atan2(-flat.x, -flat.z)
	if LightGrid.is_lit(global_position):
		dissipate()


func _blocked(player: Player) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3.UP * 0.9
	var to := player.global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Layers.WORLD
	return not space.intersect_ray(q).is_empty()


func dissipate() -> void:
	if _dying:
		return
	_dying = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
