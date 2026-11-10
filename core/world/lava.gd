class_name Lava
extends Area3D
## The molten floor of the chasm. Touching it burns (a big Gloom hit) and throws you back to
## the last ground you stood on; it only Hollows you if that burn fills the Gloom bar.
## The bone bridge's broken span and the Ember Rift islands need a miss to cost, not reload.

const LAVA_GLOOM := 35.0
const Rift := preload("res://core/world/realm/realm_rift.gd")


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	# Top face used to sit flush with the crust; lift it so the capsule overlaps on contact.
	var shape := get_node_or_null("Shape") as CollisionShape3D
	if shape:
		shape.position.y += 1.2
	_reveal()


func _reveal() -> void:
	var group := get_parent()
	if group == null:
		return
	for node in group.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		gi.ignore_occlusion_culling = true
		gi.visibility_range_end = 0.0
		gi.extra_cull_margin = 80.0
		if gi is MeshInstance3D:
			(gi as MeshInstance3D).custom_aabb = AABB(Vector3(-52.0, -10.0, -80.0), Vector3(104.0, 36.0, 160.0))
	var surface := group.get_node_or_null("Surface") as MeshInstance3D
	if surface != null:
		var mat := surface.material_override as ShaderMaterial
		if mat:
			mat = mat.duplicate() as ShaderMaterial
			mat.set_shader_parameter("emission_energy", 7.4)
			mat.set_shader_parameter("hot_color", Color(1.0, 0.28, 0.04))
			mat.set_shader_parameter("core_color", Color(1.0, 0.78, 0.28))
			surface.material_override = mat
	for node in group.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		light.light_energy = 5.4
		light.omni_range = 48.0
		light.set_meta("light_class", "lava")


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(Groups.PLAYER):
		return
	if RealmLayout.OSSUARY_HALL.has_point(body.global_position):
		return       # r34 crypt: the kill box's east corner reaches under the bank, where the pit hall is (no lava there)
	var star := body.global_position.z > Rift.STAR_Z
	if body.has_method("lava_burn"):
		body.lava_burn(LAVA_GLOOM * (0.5 if star else 1.0), star)
	elif body.has_method("hollow"):
		Events.toast.emit("The molten dark takes you.")
		body.hollow()
