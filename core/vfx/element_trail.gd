extends RefCounted
## Lightweight ribbon trail (MIT). Trails VFX (Vefects) is Store EULA —
## drop that pack under res://Vefects/ yourself if you want their presets.
## This attaches a void-violet ribbon to the staff tip without fighting CharacterRig.

static func attach_to_player(player: Node) -> void:
	if player == null:
		return
	var rig := player.get_node_or_null("Visual") as CharacterRig
	if rig == null or not rig.has_method("socket"):
		return
	var hand: Node3D = rig.socket("hand_r")
	if hand == null:
		return
	if hand.get_node_or_null("ElementTrail") != null:
		return
	var trail := GPUParticles3D.new()
	trail.name = "ElementTrail"
	trail.amount = 24
	trail.lifetime = 0.45
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 12.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.2
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.04
	mat.scale_max = 0.09
	mat.color = Color(0.45, 0.2, 0.95, 0.7)
	trail.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.03
	draw.height = 0.06
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.55, 0.25, 1.0)
	dm.emission_enabled = true
	dm.emission = Color(0.42, 0.12, 0.95)
	dm.emission_energy_multiplier = 1.2
	draw.material = dm
	trail.draw_pass_1 = draw
	hand.add_child(trail)
