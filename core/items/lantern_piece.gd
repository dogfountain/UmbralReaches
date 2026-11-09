class_name LanternPiece
extends EquipmentPiece
## Hand lantern: chain, cage, glow bulb and its warm OmniLight3D. Held in the left hand.

@export var iron_color := Color("#1A1A22")
@export var glow_color := Color(5.0, 2.6, 0.9)
@export var light_color := Color("#FFB347")


const LANTERN_GLB := "res://art/models/hand_lantern.glb"
const Check := preload("res://core/debug/check.gd")


func build(socket: Node3D) -> Node3D:
	if socket == null:
		push_error("LanternPiece.build socket null")
		return Node3D.new()
	var root := ProcMesh.node(socket, node_name if node_name != "Piece" else "Lantern", offset)
	root.rotation_degrees = rotation_deg
	if Check.attach_glb(root, LANTERN_GLB, "LanternMesh") == null:
		push_error("LanternPiece: %s failed, using ProcMesh" % LANTERN_GLB)
		var iron := ProcMesh.std_mat(iron_color, 0.45, 0.8)
		ProcMesh.mesh(root, "Chain", ProcMesh.cyl(0.006, 0.006, 0.16, 4), iron, Vector3(0, -0.08, 0), Vector3.ZERO, false)
		ProcMesh.mesh(root, "Cage", ProcMesh.cyl(0.05, 0.065, 0.15, 6), iron, Vector3(0, -0.24, 0))
		ProcMesh.mesh(root, "Glow", ProcMesh.sphere(0.04, 0.08), ProcMesh.glow_mat(glow_color), Vector3(0, -0.24, 0), Vector3.ZERO, false)

	var light := OmniLight3D.new()
	light.name = "LanternLight"
	light.light_color = light_color
	light.light_energy = 1.15
	light.omni_range = 5.5
	light.shadow_enabled = false
	light.shadow_bias = 0.15
	light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	light.set_meta("light_class", "player_lantern")
	light.position = Vector3(0, -0.24, 0)
	root.add_child(light)
	return root
