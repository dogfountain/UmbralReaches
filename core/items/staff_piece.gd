class_name StaffPiece
extends EquipmentPiece
## The violet-tipped staff: shaft, three-pronged head, glowing orb with trail/burst particles.
## Overrides build() instead of using the generic single-primitive path -- the pattern any future
## compound item (a two-handed weapon, a banner, a held relic) follows.

@export var orb_color := Color(1.3, 0.55, 3.2)
@export var orb_core_color := Color(4.0, 3.2, 6.0)
@export var light_color := Color("#A98BFF")


const STAFF_GLB := "res://art/models/staff.glb"
const Check := preload("res://core/debug/check.gd")


func build(socket: Node3D) -> Node3D:
	if socket == null:
		push_error("StaffPiece.build socket null")
		return Node3D.new()
	var root := ProcMesh.node(socket, node_name if node_name != "Piece" else "Staff", offset)
	if Check.attach_glb(root, STAFF_GLB, "StaffMesh") == null:
		push_error("StaffPiece: %s failed, using ProcMesh shaft" % STAFF_GLB)
		var wood := StandardMaterial3D.new()
		wood.albedo_texture = load("res://art/textures/bark_albedo.png")
		wood.normal_enabled = true
		wood.normal_texture = load("res://art/textures/bark_normal.png")
		wood.uv1_triplanar = true
		wood.uv1_scale = Vector3(3, 3, 3)
		wood.albedo_color = Color(0.55, 0.5, 0.62)
		wood.roughness = 0.8
		ProcMesh.mesh(root, "Shaft", ProcMesh.cyl(0.024, 0.032, 1.85, 8, 3), wood, Vector3(0, 0.33, 0))

	# Head stays where the rig bobs and spins the orb. The mesh cradle is built around this point.
	var head := ProcMesh.node(root, "Head", Vector3(0, 1.27, 0))
	var orb := ProcMesh.node(head, "Orb", Vector3(0, 0.17, 0))
	ProcMesh.mesh(orb, "Shell", ProcMesh.sphere(0.07, 0.14, 18, 10), ProcMesh.glow_mat(orb_color), Vector3.ZERO, Vector3.ZERO, false)
	ProcMesh.mesh(orb, "Core", ProcMesh.sphere(0.035, 0.07, 12, 6), ProcMesh.glow_mat(orb_core_color), Vector3.ZERO, Vector3.ZERO, false)
	var iron := ProcMesh.std_mat(Color("#3a3634"), 0.38, 0.85)
	ProcMesh.mesh(orb, "RingA", ProcMesh.cyl(0.09, 0.09, 0.012, 16, 1), iron, Vector3.ZERO, Vector3(1.2, 0.0, 0.0), false)
	ProcMesh.mesh(orb, "RingB", ProcMesh.cyl(0.078, 0.078, 0.01, 14, 1), iron, Vector3.ZERO, Vector3(0.0, 0.0, 1.1), false)
	ProcMesh.mesh(head, "ProngL", ProcMesh.cyl(0.01, 0.006, 0.16, 8, 1), iron, Vector3(-0.05, 0.12, 0.0), Vector3(0.4, 0.0, 0.35), false)
	ProcMesh.mesh(head, "ProngR", ProcMesh.cyl(0.01, 0.006, 0.16, 8, 1), iron, Vector3(0.05, 0.12, 0.0), Vector3(0.4, 0.0, -0.35), false)

	var orb_light := OmniLight3D.new()
	orb_light.name = "OrbLight"
	orb_light.light_color = light_color
	orb_light.light_energy = 1.3
	orb_light.omni_range = 4.5
	orb_light.shadow_enabled = false
	orb_light.set_meta("light_class", "player_orb")
	orb.add_child(orb_light)
	orb.add_child(_magic_particles(false))
	orb.add_child(_magic_particles(true))
	var flare := MeshInstance3D.new()
	flare.name = "Starburst"
	var fq := QuadMesh.new()
	fq.size = Vector2(0.7, 0.7)
	var fmat := ShaderMaterial.new()
	fmat.shader = load("res://world/flare.gdshader")
	fmat.set_shader_parameter("color", Color(1.1, 0.7, 3.2))
	fq.material = fmat
	flare.mesh = fq
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(flare)
	return root


func _magic_particles(burst: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Burst" if burst else "Trail"
	p.amount = 32 if burst else 48
	p.lifetime = 0.9 if burst else 1.3
	p.one_shot = burst
	p.emitting = not burst
	p.explosiveness = 0.95 if burst else 0.0
	p.local_coords = false            # world-space: motes stay behind as the staff moves = a trail
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05 if burst else 0.11
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.4 if burst else 0.03
	pm.initial_velocity_max = 3.0 if burst else 0.18
	pm.gravity = Vector3(0, -0.4, 0) if burst else Vector3(0, 0.22, 0)
	pm.damping_min = 2.0 if burst else 0.0
	pm.damping_max = 3.0 if burst else 0.2
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 1.0, 1.0))
	ramp.add_point(0.35, Color(0.75, 0.45, 1.0, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.45, 0.2, 1.0, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.055, 0.055) if not burst else Vector2(0.07, 0.07)
	q.material = load("res://art/materials/rift_mote_particle.tres")
	p.draw_pass_1 = q
	return p
