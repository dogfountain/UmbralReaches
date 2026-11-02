class_name BootPiece
extends EquipmentPiece
## A short leather boot: cuff, last, and a squared toe so it reads under the hem.


const BOOT_GLB := "res://art/models/boot.glb"
const Check := preload("res://core/debug/check.gd")


func build(socket: Node3D) -> Node3D:
	if socket == null:
		push_error("BootPiece.build socket null")
		return Node3D.new()
	var root := ProcMesh.node(socket, "Boot", offset)
	root.rotation_degrees = rotation_deg
	if Check.attach_glb(root, BOOT_GLB, "BootMesh") != null:
		return root
	push_error("BootPiece: %s failed, using ProcMesh" % BOOT_GLB)
	var leather := ProcMesh.std_mat(Color("#0c0a0d"), 0.88, 0.0)
	var sole := ProcMesh.std_mat(Color("#070608"), 0.95, 0.0)
	var metal := ProcMesh.std_mat(Color("#5a5753"), 0.36, 1.0)
	leather.normal_enabled = true
	leather.normal_texture = load("res://art/textures/ground_normal.png")
	leather.normal_scale = 0.8
	leather.uv1_triplanar = true
	leather.uv1_scale = Vector3(3.2, 3.2, 3.2)
	ProcMesh.mesh(root, "Shaft", ProcMesh.cyl(0.062, 0.07, 0.13, 12, 2), leather, Vector3(0.0, 0.08, 0.0))
	ProcMesh.mesh(root, "Cuff", ProcMesh.cyl(0.068, 0.066, 0.03, 12, 1), leather, Vector3(0.0, 0.145, 0.0))
	ProcMesh.mesh(root, "Last", ProcMesh.cyl(0.055, 0.06, 0.07, 12, 1), leather, Vector3(0.0, 0.03, -0.035), Vector3(1.15, 0.0, 0.0))
	ProcMesh.mesh(root, "Toe", ProcMesh.sphere(0.05, 0.055, 10, 5), leather, Vector3(0.0, 0.028, -0.07))
	ProcMesh.mesh(root, "Sole", ProcMesh.cyl(0.058, 0.062, 0.02, 12, 1), sole, Vector3(0.0, 0.008, -0.02))
	ProcMesh.mesh(root, "Heel", ProcMesh.cyl(0.05, 0.048, 0.03, 10, 1), sole, Vector3(0.0, 0.0, 0.02))
	ProcMesh.mesh(root, "Strap", ProcMesh.box(Vector3(0.08, 0.016, 0.012)), leather, Vector3(0.0, 0.11, -0.04))
	ProcMesh.mesh(root, "Buckle", ProcMesh.cyl(0.016, 0.016, 0.01, 8, 1), metal, Vector3(0.0, 0.11, -0.06), Vector3(1.2, 0.0, 0.0))
	ProcMesh.mesh(root, "EyeL", ProcMesh.sphere(0.006, 0.008, 6, 3), metal, Vector3(-0.018, 0.12, -0.05))
	ProcMesh.mesh(root, "EyeR", ProcMesh.sphere(0.006, 0.008, 6, 3), metal, Vector3(0.018, 0.12, -0.05))
	return root
