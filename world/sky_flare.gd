extends MeshInstance3D
## Moon-locked anamorphic flare. Sits on the camera so it does not parallax off the sky disc.

var moon: DirectionalLight3D
var dist := 24.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # r36 smooth: rides the camera every frame


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or moon == null:
		return
	var dir := moon.global_basis.z.normalized()
	if dir.y < -0.08:
		visible = false
		return
	visible = true
	global_position = cam.global_position + dir * dist
