extends Node3D
## A landmark beacon's placement (r30): the night's camera far plane is 82 m (Atmosphere), so a
## column 150 m away was simply not drawn. Past NEAR metres this node is scaled about the camera by
## NEAR / distance (a homothety centred on the eye projects to exactly the same picture), so the
## column is drawn NEAR metres out at its true size and place on screen. Its children are the
## column's meshes in local space, foot at the origin. Up close it stands where it is.

const NEAR := 64.0

var anchor := Vector3.ZERO              ## the column's true foot (world)


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # r36 smooth: moved in _process, drawn as set (interpolated, it judders between ticks)
	add_to_group(&"landmark_beacon")      # the HUD compass (ui/compass.gd) lists these
	top_level = true
	global_position = anchor


func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var rel := anchor - eye
	var d := rel.length()
	var k := 1.0 if d <= NEAR else NEAR / d
	global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(k, k, k)), eye + rel * k)
