class_name MeshPiece
extends EquipmentPiece
## A wearable mesh. The glb is authored in the socket's local space (Godot Y up).


@export var scene_path := ""


const Check := preload("res://core/debug/check.gd")


func build(socket: Node3D) -> Node3D:
	if socket == null:
		push_error("MeshPiece.build socket null path=%s" % scene_path)
		return Node3D.new()
	var root := ProcMesh.node(socket, node_name if node_name != "Piece" else "Mesh", offset)
	root.rotation_degrees = rotation_deg
	if scene_path == "":
		push_error("MeshPiece.build empty scene_path")
		return root
	if Check.attach_glb(root, scene_path, "Mesh") == null:
		push_error("MeshPiece.build attach failed %s" % scene_path)
	return root
