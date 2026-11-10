class_name LoreScrap
extends Interactable
## A short inscription. One toast. E to read.


const StoneProps := preload("res://core/world/realm/lore/stone_props.gd")

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
	# the in-house tablet model (tools/blender/props_stones.py), dressed with the tiling stone set
	var ps := load("res://art/models/props/lore_tablet_weathered.glb") as PackedScene
	if ps != null:
		var m := ps.instantiate() as Node3D
		m.name = "Tablet"
		add_child(m)
		StoneProps.dress(m)
		return
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
