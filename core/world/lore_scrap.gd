class_name LoreScrap
extends Interactable
## A short inscription. One toast. E to read.


var body := ""
var _read := false


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	if find_children("*", "MeshInstance3D", true, false).is_empty():
		_build()


func can_interact() -> bool:
	return true


func interact_text() -> String:
	var key := Interactable.prompt_key()
	return "[%s]  Read the inscription" % key if not _read else "[%s]  Read again" % key


func interact(_by: Node) -> void:
	_read = true
	if body != "":
		Events.toast.emit(body)


func _build() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.22, 0.16, 0.18)
	stone.roughness = 0.92
	stone.rim_enabled = true
	stone.rim = 0.28
	var slab := BoxMesh.new()
	slab.size = Vector3(0.42, 0.62, 0.08)
	ProcMesh.mesh(self, "Tablet", slab, stone, Vector3(0.0, 0.34, 0.0), Vector3(-0.18, 0.0, 0.0), true)
	var mark := StandardMaterial3D.new()
	mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.albedo_color = Color(0.95, 0.42, 0.38)
	var line := BoxMesh.new()
	line.size = Vector3(0.22, 0.012, 0.02)
	ProcMesh.mesh(self, "Mark", line, mark, Vector3(0.0, 0.48, 0.05), Vector3.ZERO, false)
	var body_col := StaticBody3D.new()
	body_col.name = "Body"
	body_col.collision_layer = Layers.WORLD
	body_col.collision_mask = 0
	add_child(body_col)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.46, 0.66, 0.14)
	col.shape = box
	col.position = Vector3(0.0, 0.33, 0.0)
	body_col.add_child(col)
