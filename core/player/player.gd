class_name Player
extends CharacterBody3D
## Third-person wanderer: movement, orbit camera, lantern, Gloom, interaction, autopilot (demo/tests).

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var accel := 14.0               ## ground, speeding up
@export var decel := 20.0               ## ground, stopping -- crisper than starting
@export var air_accel := 4.0            ## weaker control once the feet leave the floor
@export var jump_velocity := 5.2
@export var gravity := 16.0
@export var coyote_time := 0.1          ## grace to still jump just after walking off an edge
@export var jump_buffer := 0.12         ## a jump pressed just before landing still fires
@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 2.6
@export var pitch_min := -1.0
@export var pitch_max := 0.6
@export_group("Gloom")
@export var gloom_max := 100.0
@export var gloom_rate_dark := 2.0      ## per second away from light (was 3.6; 1.8× slower)
@export var gloom_rate_rift := 3.5      ## per second near the rift (was 6.3; 1.8× slower)
@export var gloom_drain_lit := 12.0     ## per second inside a light zone
@export var rift_z := -40.0             ## world z beyond which the rift rate applies
@export var rift_enabled := true
@export var interact_range := 2.8

var gloom := 0.0
var checkpoint := Vector3.ZERO
var autopilot := false
var hollow_count := 0

var _waypoints: Array[Marker3D] = []
var _wp := 0
var _wait := 0.0
var _waiting := false
var _yaw := 0.0
var _pitch := -0.18
var _t := 0.0
var _shade: Shade
var _shade_lock := 0.0
var _shade_warned := false
var _hollowing := false
var _coyote := 0.0
var _buffered_jump := 0.0
var _fov_kick := 0.0
var _land_dip := 0.0
var _was_floor := true
var _rig_height := 1.55

const SPRINT_FOV_KICK := 6.0
var _interact_target: Interactable
var _hint := ""
var _cast_cd := 0.0
const CAST_CD := 0.42
const HEAVY_CD := 1.15
const BOLT := preload("res://core/player/magic_bolt.tscn")

@onready var _visual: CharacterRig = $Visual
@onready var _rig: Node3D = $CameraRig
@onready var _pitch_node: Node3D = $CameraRig/Pitch
@onready var _arm: SpringArm3D = $CameraRig/Pitch/SpringArm
@onready var _cam: Camera3D = $CameraRig/Pitch/SpringArm/Camera


func _ready() -> void:
	add_to_group(Groups.PLAYER)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.PROPS
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(46.0)
	_arm.spring_length = 3.7
	if Travel.pending:
		global_position = Travel.spawn
		_yaw = Travel.yaw
		gloom = Travel.gloom
		hollow_count = Travel.hollow_count
		Travel.consume()
		Events.gloom_changed.emit(gloom, gloom_max)
	else:
		_yaw = _rig.rotation.y
	checkpoint = global_position
	_rig_height = _rig.position.y
	# Interpolated cameras: rig is top-level so look isn't stuck on the 60 Hz physics tick.
	_rig.top_level = true
	_rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rig.global_position = global_position + Vector3(0.0, _rig_height, 0.0)
	_rig.global_rotation = Vector3(0.0, _yaw, 0.0)
	if _visual:
		_visual.rotation.y = _yaw
	_arm.add_excluded_object(get_rid())
	_arm.position.x = 0.95
	_cam.h_offset = 0.12
	_visual.driven = true
	_visual.set_process(false)
	_visual.walk_speed = walk_speed
	_visual.sprint_speed = sprint_speed


func _unhandled_input(event: InputEvent) -> void:
	if autopilot:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, pitch_min, pitch_max)
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("heavy_cast"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not (event is InputEventMouseButton):
			_try_cast(true)
	elif event.is_action_pressed("cast"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not (event is InputEventMouseButton):
			_try_cast(false)


func _process(delta: float) -> void:
	if not autopilot:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look.length() > 0.15:
			_yaw -= look.x * stick_sensitivity * delta
			_pitch = clampf(_pitch - look.y * stick_sensitivity * delta, pitch_min, pitch_max)
	var body_xf := get_global_transform_interpolated()
	_rig.global_position = body_xf.origin + Vector3(0.0, _rig_height, 0.0)
	_rig.global_rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_node.rotation.x = _pitch - _land_dip * 0.12


func _physics_process(delta: float) -> void:
	_t += delta
	_cast_cd = maxf(0.0, _cast_cd - delta)
	_shade_lock = maxf(0.0, _shade_lock - delta)

	var wish := Vector3.ZERO
	var sprint := false
	if not _hollowing:
		if has_meta("force_wish"):
			# In-game walk recorder / tests: world-space wish unit vector.
			wish = get_meta("force_wish") as Vector3
			sprint = bool(get_meta("force_sprint")) if has_meta("force_sprint") else false
		elif autopilot:
			var cmd := _autopilot(delta)
			wish = cmd[0]
			sprint = cmd[1]
		else:
			var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			wish = Basis(Vector3.UP, _yaw) * Vector3(v.x, 0.0, v.y)
			sprint = Input.is_action_pressed("sprint")

	var target := wish * (sprint_speed if sprint else walk_speed)
	# Separate rates: stopping bites harder than starting, and air control is weaker than ground.
	var rate := air_accel
	if is_on_floor():
		rate = accel if wish.length() > 0.01 else decel
	var horiz := Vector3(velocity.x, 0.0, velocity.z).lerp(target, 1.0 - exp(-rate * delta))
	velocity.x = horiz.x
	velocity.z = horiz.z

	# Coyote time and jump buffering: without them, a jump pressed one frame early or one frame
	# late is silently dropped, which is most of what made the movement feel unresponsive.
	_coyote = coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	_buffered_jump = maxf(0.0, _buffered_jump - delta)
	if not autopilot and not _hollowing:
		if Input.is_action_just_pressed("jump"):
			_buffered_jump = jump_buffer
		elif Input.is_action_pressed("jump") and is_on_floor() and velocity.y <= 0.0:
			_buffered_jump = jump_buffer
	if _buffered_jump > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffered_jump = 0.0
		_coyote = 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	var vy_before := velocity.y
	move_and_slide()

	_update_camera(delta, horiz, sprint, vy_before)
	_animate(delta, horiz)
	_update_gloom(delta)
	_scan_interactables()
	RenderingServer.global_shader_parameter_set("push_pos", global_position)   # grass parts around the player
	if global_position.y < -40.0:
		_respawn_now()   # fell into the chasm


func set_checkpoint(at: Vector3) -> void:
	checkpoint = at


func start_autopilot(markers: Array[Marker3D]) -> void:
	_waypoints = markers
	_wp = 0
	_waiting = false
	autopilot = true


# --- Camera ------------------------------------------------------------------

## The spring arm used to sit perfectly still whatever the player did. Two cheap reactions:
## the view opens up at a sprint, and the camera dips on a hard landing. Base FOV stays
## Settings.fov, so the settings menu remains the one source of truth and the kick rides on top.

func _update_camera(delta: float, horiz: Vector3, sprint: bool, vy_before: float) -> void:
	var running := sprint and horiz.length() > walk_speed * 0.6
	_fov_kick = lerpf(_fov_kick, SPRINT_FOV_KICK if running else 0.0, 1.0 - exp(-6.0 * delta))
	_cam.fov = Settings.fov + _fov_kick

	if is_on_floor() and not _was_floor:
		_land_dip = clampf(-vy_before / 9.0, 0.0, 1.0)
	_was_floor = is_on_floor()
	_land_dip = move_toward(_land_dip, 0.0, delta * 3.0)


# --- Animation ---------------------------------------------------------------

func _animate(delta: float, horiz: Vector3) -> void:
	if horiz.length() > 0.2:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-horiz.x, -horiz.z), 1.0 - exp(-10.0 * delta))
	_visual.animate(velocity, is_on_floor(), delta)


# --- Gloom and the shade -----------------------------------------------------

func _update_gloom(delta: float) -> void:
	if _hollowing:
		return
	var lit := LightGrid.is_lit(global_position)
	var dark := gloom_rate_rift if rift_enabled and global_position.z < rift_z else gloom_rate_dark
	var rate := -gloom_drain_lit if lit else dark
	var prev := gloom
	gloom = clampf(gloom + rate * delta, 0.0, gloom_max)
	if not is_equal_approx(prev, gloom):
		Events.gloom_changed.emit(gloom, gloom_max)
	if gloom >= gloom_max and not is_instance_valid(_shade) and _shade_lock <= 0.0:
		_spawn_shade()
	if lit and is_instance_valid(_shade):
		_shade.dissipate()


func add_gloom(amount: float) -> void:
	gloom = clampf(gloom + amount, 0.0, gloom_max)
	Events.gloom_changed.emit(gloom, gloom_max)


func _spawn_shade() -> void:
	var s := Shade.new()
	var host := get_tree().current_scene
	if host == null:
		return
	host.add_child(s)
	var behind := Basis(Vector3.UP, _yaw) * Vector3(0.0, 0.0, 1.0)
	s.global_position = global_position + behind * 16.0 + Vector3.UP * 1.2
	s.target = self
	_shade = s
	s.tree_exiting.connect(_on_shade_leaving)
	Events.shade_spawned.emit()
	if not _shade_warned:
		_shade_warned = true
		Events.toast.emit("The dark has taken shape. Find light.")


func note_shade_bolt() -> void:
	_shade_lock = 2.0


func add_gloom_from_enemy(amount: float) -> void:
	add_gloom(amount)
	if not has_meta("heard_strike"):
		set_meta("heard_strike", true)
		Events.toast.emit("They do not kill. They fill the dark.")


func _on_shade_leaving() -> void:
	_shade = null


func hollow() -> void:
	if _hollowing:
		return
	_hollowing = true
	hollow_count += 1
	_shade_warned = false
	Events.hollowed.emit()
	await get_tree().create_timer(0.9).timeout
	_respawn_now()
	await get_tree().create_timer(0.4).timeout
	_hollowing = false


func _respawn_now() -> void:
	global_position = checkpoint
	velocity = Vector3.ZERO
	gloom = 0.0
	Events.gloom_changed.emit(gloom, gloom_max)
	if is_instance_valid(_shade):
		_shade.queue_free()
	Events.respawned.emit(checkpoint)


# --- Interaction -------------------------------------------------------------

func _scan_interactables() -> void:
	var best: Interactable = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		var it := node as Interactable
		if it == null or not it.can_interact():
			continue
		var reach := it.interact_reach()
		if reach <= 0.0:
			reach = interact_range
		var d := global_position.distance_to(it.global_position)
		if d < reach and d < best_d:
			best_d = d
			best = it
	_interact_target = best
	var hint := best.interact_text() if best else ""
	if hint != _hint:
		_hint = hint
		Events.interact_hint.emit(hint)


func _try_interact() -> void:
	if is_instance_valid(_interact_target) and _interact_target.can_interact():
		_visual.cast()
		_interact_target.interact(self)


func _try_cast(heavy := false) -> void:
	if _hollowing or _cast_cd > 0.0 or _visual == null:
		return
	var host := get_tree().current_scene
	if host == null:
		return
	_cast_cd = HEAVY_CD if heavy else CAST_CD
	_visual.cast()
	var bolt := BOLT.instantiate() as MagicBolt
	bolt.heavy = heavy
	if heavy:
		bolt.hit_dmg = 3.0
		bolt.blast = 2.6
		bolt.speed = 18.0
	host.add_child(bolt)
	var muzzle := _visual.muzzle()
	var look := _look_target()
	var cam_fwd := -_cam.global_transform.basis.z.normalized()
	var aim := look - muzzle
	if aim.length_squared() < 0.04 or aim.normalized().dot(cam_fwd) < 0.12:
		aim = cam_fwd
	else:
		aim = aim.normalized()
	bolt.global_position = muzzle + aim * 0.28
	bolt.direction = aim
	bolt.add_collision_exception_with(self)


## Screen-center hit (the HUD crosshair). Parallel-to-camera from the staff orb
## misses around the edges up close — OTS offset. Converge on this point instead.
func _look_target() -> Vector3:
	var center := get_viewport().get_visible_rect().get_center()
	var from := _cam.project_ray_origin(center)
	var dir := _cam.project_ray_normal(center)
	var far := from + dir * 96.0
	var space := get_world_3d().direct_space_state
	if space == null:
		return far
	var q := PhysicsRayQueryParameters3D.create(from, far)
	q.collision_mask = Layers.WORLD | Layers.PROPS | Layers.HURTBOX
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return far
	return hit.position


# --- Autopilot (demo recording and smoke tests) -----------------------------
# Each Marker3D may carry metadata: wait (s), kindle (bool), sprint (bool), pitch (rad), shot (bool).

func _autopilot(delta: float) -> Array:
	if _wp >= _waypoints.size():
		if autopilot:
			autopilot = false
			Events.autopilot_finished.emit()
		return [Vector3.ZERO, false]
	var m := _waypoints[_wp]
	_pitch = lerpf(_pitch, float(m.get_meta("pitch", -0.12)), 1.0 - exp(-1.5 * delta))
	if _waiting:
		if m.get_meta("kindle", false) and _interact_target != null:
			_try_interact()   # keep trying while waiting: arrival can land a few cm outside interact range
		if m.has_meta("yaw"):
			_yaw = lerp_angle(_yaw, float(m.get_meta("yaw")), 1.0 - exp(-1.5 * delta))
		_wait -= delta
		if _wait <= 0.0:
			_waiting = false
			_wp += 1
		return [Vector3.ZERO, false]
	var to := m.global_position - global_position
	to.y = 0.0
	if to.length() < 0.6:
		Events.autopilot_reached.emit(m.name)
		if m.get_meta("kindle", false):
			_try_interact()
		var w := float(m.get_meta("wait", 0.0))
		if w > 0.0:
			_waiting = true
			_wait = w
		else:
			_wp += 1
		return [Vector3.ZERO, false]
	var dir := to.normalized()
	_yaw = lerp_angle(_yaw, atan2(-dir.x, -dir.z), 1.0 - exp(-2.0 * delta))
	return [dir, bool(m.get_meta("sprint", false))]
