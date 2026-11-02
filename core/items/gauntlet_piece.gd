class_name GauntletPiece
extends EquipmentPiece
## A dark leather palm under a silver cuff. Hard pieces, so it reads as a grip instead of a ball.


const GAUNTLET_GLB := "res://art/models/gauntlet.glb"
const Check := preload("res://core/debug/check.gd")


func build(socket: Node3D) -> Node3D:
	if socket == null:
		push_error("GauntletPiece.build socket null")
		return Node3D.new()
	var root := ProcMesh.node(socket, "Gauntlet", offset)
	root.rotation_degrees = rotation_deg
	if Check.attach_glb(root, GAUNTLET_GLB, "GauntletMesh") != null:
		return root
	push_error("GauntletPiece: %s failed, using ProcMesh" % GAUNTLET_GLB)
	var leather := ProcMesh.std_mat(Color("#0a090c"), 0.92, 0.0)
	var metal := ProcMesh.std_mat(Color("#5a5753"), 0.34, 1.0)
	leather.normal_enabled = true
	leather.normal_texture = load("res://art/textures/ground_normal.png")
	leather.normal_scale = 0.7
	leather.uv1_triplanar = true
	leather.uv1_scale = Vector3(4, 4, 4)
	metal.normal_enabled = true
	metal.normal_texture = load("res://art/textures/rock_normal.png")
	metal.normal_scale = 0.45
	metal.uv1_triplanar = true
	metal.uv1_scale = Vector3(5, 5, 5)
	ProcMesh.mesh(root, "Palm", ProcMesh.sphere(0.042, 0.07, 14, 8), leather)
	ProcMesh.mesh(root, "Cuff", ProcMesh.cyl(0.046, 0.05, 0.038, 14, 1), metal, Vector3(0.0, 0.038, 0.0))
	ProcMesh.mesh(root, "Knuckle", ProcMesh.cyl(0.03, 0.028, 0.018, 10, 1), metal, Vector3(0.0, -0.006, -0.03), Vector3(1.15, 0.0, 0.0))
	ProcMesh.mesh(root, "Plate", ProcMesh.box(Vector3(0.05, 0.018, 0.036)), metal, Vector3(0.0, 0.01, -0.02))
	for i in 3:
		var x := (float(i) - 1.0) * 0.016
		ProcMesh.mesh(root, "Finger%d" % i, ProcMesh.cyl(0.01, 0.008, 0.042, 7, 1), leather, Vector3(x, -0.02, -0.04), Vector3(0.95, 0.0, 0.0))
		ProcMesh.mesh(root, "Nail%d" % i, ProcMesh.box(Vector3(0.01, 0.006, 0.014)), metal, Vector3(x, -0.03, -0.062), Vector3(0.4, 0.0, 0.0))
	return root
