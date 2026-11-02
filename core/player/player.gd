class_name Player
extends CharacterBody3D
## Third-person wanderer: movement, orbit camera, lantern, Gloom, interaction, autopilot (demo/tests).

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var accel := 14.0               ## ground, speeding up
@export var decel := 20.0               ## ground, stopping -- crisper than starting
@export var air_accel := 6.5            ## air steering; weaker than ground but enough to correct a jump
@export var jump_velocity := 5.2
@export var gravity := 16.0
@export var coyote_time := 0.1          ## grace to still jump just after walking off an edge
@export var jump_buffer := 0.12         ## a jump pressed just before landing still fires
@export var air_jumps := 1               ## extra jumps before landing (rift-step double jump)
@export var air_jump_velocity := 5.8
@export var jump_cut := 0.5             ## release jump while rising -> vertical speed x this
@export_group("Slide")
@export var slide_boost := 1.3          ## entry speed = max(current * this, sprint * 1.15)
@export var slide_min_speed := 3.4      ## need at least a brisk walk to drop into a slide
@export var slide_friction := 4.2       ## m/s² on the flat
@export var slide_slope_gain := 13.0    ## extra m/s² per unit of downhill slope
@export var slide_max_time := 1.2       ## on the flat; downhill extends it
@export var slide_cooldown := 0.35
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
var _interact_near: Array[Interactable] = []
var _hint := ""
var _debug_drive := false
var _debug_wish := Vector3.ZERO
var _debug_sprint := false
var _gloom_emit := 0.0
var _gloom_emit_t := 0.0
var _shake := 0.0
const BOLT := preload("res://core/player/magic_bolt.tscn")

@export_group("Rift Step")
@export var step_range := 7.5           ## metres per teleport (shortened by walls, settled onto ground)
@export var step_reveal := 0.1          ## seconds unseen at the far end before the body re-forms
@export var step_evade := 0.35          ## untouchable window from the moment you tear out
@export var slide_land_min := 2.0       ## a slide held through a landing needs only this much speed
@export var slide_land_gain := 0.35     ## and converts this share of the fall speed into slide speed
const COMBAT_FACE_TIME := 1.4           ## after a cast the body faces the camera, not the motion

var _book: SkillBook
var _step_t := 0.0
var _evade_t := 0.0
var _combat_t := 0.0

var _air_jumps_left := 1
var _jump_rising := false
var _sliding := false
var _slide_t := 0.0
var _slide_cd := 0.0
var _slide_dir := Vector3.FORWARD
var _slide_speed := 0.0
var _slide_air := 0.0
var _slide_blend := 0.0
var _cam_drop := 0.0
var _col: CollisionShape3D
var _col_h := 1.7
var _col_y := 0.85
var _slide_fx: GPUParticles3D
var _slide_sfx: AudioStreamPlayer3D
var _charge_fx: GPUParticles3D
var _charge_sfx: AudioStreamPlayer3D
var _charge_was_full := false
var _tp_offset := Vector3.ZERO          ## camera trails the body across a teleport, decays fast
var _slide_latch := false               ## a held key slides once; release to arm the next
var _slide_queued := false              ## slide held in the air: drop into it on landing
var _air_vy := 0.0                      ## last airborne vertical speed (landing -> slide bonus)
var _aim_ring: MeshInstance3D
var _safe_ground := Vector3.INF          ## last flat ground stood on for 0.25 s (lava recovery)
var _ground_t := 0.0
var _burn_cd := 0.0

const SFX_JUMP := "res://art/audio/jump_air.wav"
const SFX_STEP := "res://art/audio/step_blink.wav"
const SFX_HURT := "res://art/audio/hurt.wav"
const SFX_NOVA := "res://art/audio/nova_boom.wav"
const SFX_LANCE := "res://art/audio/lance_fire.wav"
const VIOLET := Color(1.3, 0.6, 3.0)
const EMBER := Color(2.6, 0.9, 0.3)

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
	_setup_interact_sensor()
	_col = get_node_or_null("Collision") as CollisionShape3D
	if _col and _col.shape is CapsuleShape3D:
		_col.shape = _col.shape.duplicate()          # we resize it for the slide
		_col_h = (_col.shape as CapsuleShape3D).height
		_col_y = _col.position.y
	_setup_movement_fx()
	_aim_ring = SpellFx.target_ring()
	add_child(_aim_ring)
	_book = SkillBook.new()
	_book.name = "SkillBook"
	add_child(_book)


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


func _process(delta: float) -> void:
	if not autopilot:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look.length() > 0.15:
			_yaw -= look.x * stick_sensitivity * delta
			_pitch = clampf(_pitch - look.y * stick_sensitivity * delta, pitch_min, pitch_max)
	var body_xf := get_global_transform_interpolated()
	_cam_drop = lerpf(_cam_drop, 0.55 * _slide_blend, 1.0 - exp(-12.0 * delta))
	_tp_offset = _tp_offset.lerp(Vector3.ZERO, 1.0 - exp(-20.0 * delta))
	_rig.global_position = body_xf.origin + Vector3(0.0, _rig_height - _cam_drop, 0.0) + _tp_offset
	_rig.global_rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_node.rotation.x = _pitch - _land_dip * 0.12 + _shake
	_shake = move_toward(_shake, 0.0, delta * 0.12)   # ~0.15 s for a full kick


func _physics_process(delta: float) -> void:
	_t += delta
	_shade_lock = maxf(0.0, _shade_lock - delta)
	_evade_t = maxf(0.0, _evade_t - delta)
	_combat_t = maxf(0.0, _combat_t - delta)
	if _step_t > 0.0:
		_tick_step(delta)
		return

	var wish := Vector3.ZERO
	var sprint := false
	if not _hollowing:
		if _debug_drive:
			wish = _debug_wish
			sprint = _debug_sprint
		elif autopilot:
			var cmd := _autopilot(delta)
			wish = cmd[0]
			sprint = cmd[1]
		else:
			var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			wish = Basis(Vector3.UP, _yaw) * Vector3(v.x, 0.0, v.y)
			sprint = Input.is_action_pressed("sprint")

	_slide_cd = maxf(0.0, _slide_cd - delta)
	if not Input.is_action_pressed("slide"):
		_slide_latch = false
		_slide_queued = false
	if is_on_floor():
		_air_jumps_left = air_jumps
	var horiz: Vector3
	if _sliding:
		horiz = _tick_slide(delta, wish)
	else:
		var target := wish * (sprint_speed if sprint else walk_speed) * _book.move_scale()
		# Separate rates: stopping bites harder than starting, and air control is weaker than ground.
		var rate := air_accel
		if is_on_floor():
			rate = accel if wish.length() > 0.01 else decel
		horiz = Vector3(velocity.x, 0.0, velocity.z).lerp(target, 1.0 - exp(-rate * delta))
		if not is_on_floor():
			horiz = horiz.limit_length(maxf(Vector3(velocity.x, 0.0, velocity.z).length(), sprint_speed))
		velocity.x = horiz.x
		velocity.z = horiz.z
		if not autopilot and not _hollowing:
			_slide_input(horiz, wish)

	# Coyote time and jump buffering: without them, a jump pressed one frame early or one frame
	# late is silently dropped, which is most of what made the movement feel unresponsive.
	_coyote = coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	_buffered_jump = maxf(0.0, _buffered_jump - delta)
	if not autopilot and not _hollowing:
		if Input.is_action_just_pressed("jump"):
			if _coyote <= 0.0 and not is_on_floor() and _air_jumps_left > 0:
				_air_jump(wish, sprint)
			else:
				_buffered_jump = jump_buffer
		# variable height: let go while rising and the arc flattens
		if _jump_rising and not Input.is_action_pressed("jump") and velocity.y > 0.0:
			velocity.y *= jump_cut
			_jump_rising = false
	if _buffered_jump > 0.0 and _coyote > 0.0:
		if _sliding:
			_end_slide()                 # slide-hop: the slide's speed carries into the jump
		velocity.y = jump_velocity
		_buffered_jump = 0.0
		_coyote = 0.0
		_jump_rising = true
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y <= 0.0:
		_jump_rising = false
	var vy_before := velocity.y
	move_and_slide()
	if not is_on_floor():
		_air_vy = velocity.y
		_ground_t = 0.0
	elif get_floor_normal().y > 0.85 and not _sliding:
		_ground_t += delta
		if _ground_t > 0.25:
			_safe_ground = global_position
	_burn_cd = maxf(0.0, _burn_cd - delta)

	_update_camera(delta, horiz, sprint, vy_before)
	_animate(delta, horiz)
	_update_gloom(delta)
	_scan_interactables()
	RenderingServer.global_shader_parameter_set("push_pos", global_position)   # grass parts around the player
	if global_position.y < -40.0:
		_respawn_now()   # fell into the chasm


## Lava: a heavy Gloom burn and a throw back to the last solid ground (see Lava).
func lava_burn(amount: float) -> void:
	if _burn_cd > 0.0 or _hollowing:
		return
	_burn_cd = 1.0
	var from := global_position
	add_gloom(amount)
	Events.player_hurt.emit(amount, from)
	Vfx.burst(from + Vector3.UP * 0.6, SpellFx.EMBER_HOT, {"count": 50, "life": 0.7, "speed": Vector2(3.0, 8.0), "size": 0.05, "gravity": -8.0, "trail": 0.08, "dir": Vector3.UP, "spread": 50.0})
	_end_slide()
	var to := _safe_ground if _safe_ground != Vector3.INF else checkpoint
	global_position = to + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	SpellFx.rift_in(to)
	kick(0.8)
	Events.toast.emit("The molten dark spits you back out.")


func set_checkpoint(at: Vector3) -> void:
	checkpoint = at


func set_view(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


func debug_drive(wish: Vector3, sprint := false) -> void:
	_debug_drive = wish.length_squared() > 0.0001
	_debug_wish = wish
	_debug_sprint = sprint


func cast_impulse() -> void:
	_shake = deg_to_rad(0.15)


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
	if _combat_t > 0.0:
		# Casting: face where the crosshair is, strafe and backpedal instead of spinning away.
		_visual.rotation.y = lerp_angle(_visual.rotation.y, _yaw, 1.0 - exp(-14.0 * delta))
	elif horiz.length() > 0.2:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-horiz.x, -horiz.z), 1.0 - exp(-10.0 * delta))
	if not _sliding:
		_slide_blend = move_toward(_slide_blend, 0.0, delta * 6.0)
	_visual.slide = _slide_blend
	if _sliding:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-_slide_dir.x, -_slide_dir.z), 1.0 - exp(-12.0 * delta))
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
		_gloom_emit_t += delta
		if absf(gloom - _gloom_emit) >= 0.5 or _gloom_emit_t >= 0.1:
			Events.gloom_changed.emit(gloom, gloom_max)
			_gloom_emit = gloom
			_gloom_emit_t = 0.0
	else:
		_gloom_emit_t = 0.0
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
	s.target = self
	s.global_position = global_position + behind * 16.0 + Vector3.UP * Shade.HOVER
	_shade = s
	s.tree_exiting.connect(_on_shade_leaving)
	Events.shade_spawned.emit()
	if not _shade_warned:
		_shade_warned = true
		Events.toast.emit("The dark has taken shape. Find light.")


func note_shade_bolt() -> void:
	_shade_lock = 2.0


func add_gloom_from_enemy(amount: float, from_pos := Vector3.INF) -> void:
	add_gloom(amount)
	kick(clampf(amount / 30.0, 0.3, 1.0))
	Sfx.play(SFX_HURT, global_position + Vector3.UP, -3.0)
	Events.player_hurt.emit(amount, from_pos)
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
	if not is_inside_tree():
		return
	_respawn_now()
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
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

func _setup_interact_sensor() -> void:
	var sense := Area3D.new()
	sense.name = "InteractSensor"
	sense.collision_layer = 0
	sense.collision_mask = Layers.INTERACT
	sense.monitoring = true
	sense.monitorable = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.2
	cs.shape = sph
	sense.add_child(cs)
	add_child(sense)
	sense.area_entered.connect(_on_interact_in)
	sense.area_exited.connect(_on_interact_out)


func _on_interact_in(area: Area3D) -> void:
	var it := area.get_parent() as Interactable
	if it and not _interact_near.has(it):
		_interact_near.append(it)


func _on_interact_out(area: Area3D) -> void:
	var it := area.get_parent() as Interactable
	if it:
		_interact_near.erase(it)


func _scan_interactables() -> void:
	var best: Interactable = null
	var best_d := INF
	var i := 0
	while i < _interact_near.size():
		var it := _interact_near[i]
		if not is_instance_valid(it):
			_interact_near.remove_at(i)
			continue
		i += 1
		if not it.can_interact():
			continue
		var reach := it.interact_reach()
		if reach <= 0.0:
			reach = interact_range
		var d := global_position.distance_squared_to(it.global_position)
		if d < reach * reach and d < best_d:
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


## Spawn one staff bolt toward the crosshair. cfg keys (all optional): heavy, dmg, blast, speed,
## marks (Umbral Marks per hit), pierce. Skills call this; it owns aim, pooling and the gesture.
func fire_bolt(cfg: Dictionary) -> MagicBolt:
	if _hollowing or _visual == null:
		return null
	var host := get_tree().current_scene
	if host == null:
		return null
	_visual.cast()
	var pool := get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	var bolt: MagicBolt
	if pool:
		bolt = pool.take()
	else:
		bolt = BOLT.instantiate() as MagicBolt
		host.add_child(bolt)
	var muzzle := _visual.muzzle()
	var aim := _aim_from(muzzle)
	var up := Vector3.UP
	if absf(aim.dot(up)) > 0.95:
		up = Vector3.RIGHT
	bolt.transform = Transform3D(Basis.looking_at(aim, up), muzzle + aim * 0.28)
	bolt.direction = aim
	bolt.arm_with(cfg)
	bolt.add_collision_exception_with(self)
	var heavy := bool(cfg.get("heavy", false))
	var col := EMBER if heavy else VIOLET
	Vfx.burst(muzzle + aim * 0.2, col, {"count": 16 if heavy else 8, "life": 0.22, "speed": Vector2(1.5, 4.0), "size": 0.05, "dir": aim, "spread": 35.0, "gravity": 0.0, "trail": 0.05})
	Vfx.light(muzzle, Color(col.r, col.g, col.b) * 0.5, 2.5 if heavy else 1.2, 4.5, 0.12)
	if heavy:
		Sfx.play(SFX_LANCE, muzzle, -2.0)
	return bolt


func _aim_from(muzzle: Vector3) -> Vector3:
	var look := _look_target()
	var cam_fwd := -_cam.global_transform.basis.z.normalized()
	var aim := look - muzzle
	if aim.length_squared() < 0.04 or aim.normalized().dot(cam_fwd) < 0.12:
		return cam_fwd
	return aim.normalized()


# --- Skills surface -------------------------------------------------------------------------

func skills() -> SkillBook:
	return _book


func skills_locked() -> bool:
	return _hollowing or autopilot or _step_t > 0.0


func note_combat() -> void:
	_combat_t = COMBAT_FACE_TIME


func set_charge_glow(c: float) -> void:
	if _visual:
		_visual.charge = c
	_update_aim_ring(c)
	if _charge_fx == null:
		return
	var on := c > 0.0
	if on != _charge_fx.emitting:
		_charge_fx.emitting = on
		if on:
			_charge_sfx.play()
		else:
			_charge_sfx.stop()
			_charge_was_full = false
	if on:
		_charge_fx.global_position = _visual.muzzle()
		_charge_fx.amount_ratio = 0.35 + 0.65 * c
		_charge_sfx.pitch_scale = 0.8 + 0.5 * c
		if c >= 1.0 and not _charge_was_full:
			_charge_was_full = true      # full charge: a ring snap tells you it will pierce
			Vfx.ring(_visual.muzzle(), 0.7, Color(2.6, 1.8, 1.0), 0.25, 0.14, -_cam.global_basis.z)
			Vfx.burst(_visual.muzzle(), Color(2.8, 1.6, 0.8), {"count": 18, "life": 0.3, "speed": Vector2(2.0, 4.0), "size": 0.04, "trail": 0.06, "gravity": 0.0})


## Lance aim: a round marker where the throw will land, sized to the blast it will have now.
func _update_aim_ring(c: float) -> void:
	if _aim_ring == null:
		return
	if c <= 0.0:
		_aim_ring.visible = false
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var muzzle := _visual.muzzle()
	var aim := _aim_from(muzzle)
	var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + aim * 60.0, Layers.WORLD | Layers.PROPS, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_aim_ring.visible = false
		return
	_aim_ring.visible = true
	SpellFx.place_ring(_aim_ring, hit.position, hit.normal, lerpf(2.0, 3.2, c), c)


## Camera punch, 0..1. Rides the existing land-dip pitch channel.
func kick(amount: float) -> void:
	_shake = maxf(_shake, deg_to_rad(0.15 + 1.1 * clampf(amount, 0.0, 1.0)))


func is_evading() -> bool:
	return _evade_t > 0.0


func can_shadowstep() -> bool:
	return not _hollowing and _step_t <= 0.0


## Rift Step: tear out here, tear in up to `step_range` metres along the move direction (camera
## forward with no input). A capsule sweep stops it short of walls; the far end settles onto
## whatever ground is within 3 m below, so stairs and slopes land cleanly and a gap is crossed
## in the air. Vertical speed is cancelled, so a mid-air step is also a brief hang.
func shadowstep() -> bool:
	if not can_shadowstep():
		return false
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Basis(Vector3.UP, _yaw) * Vector3(v.x, 0.0, v.y)
	if dir.length_squared() < 0.04:
		dir = Basis(Vector3.UP, _yaw) * Vector3.FORWARD
	dir = dir.normalized()
	_end_slide()
	var from := global_position
	var to := _rift_target(dir)
	if Vector2(to.x - from.x, to.z - from.z).length() < 0.8:
		return false                          # nose to a wall: refuse rather than burn the cooldown
	SpellFx.rift_out(from)
	global_position = to
	reset_physics_interpolation()
	_tp_offset += from - to                   # camera swoops across the gap instead of hard-cutting
	SpellFx.rift_seam(from, to)
	SpellFx.rift_in(to)
	velocity = Vector3(dir.x, 0.0, dir.z) * walk_speed
	_step_t = step_reveal
	_evade_t = step_evade
	_visual.visible = false
	_visual.rotation.y = atan2(-dir.x, -dir.z)
	_mark_path(from, to)
	Sfx.play(SFX_STEP, from, -6.0)
	Sfx.play(SFX_STEP, to, -2.0)
	_fov_kick = maxf(_fov_kick, 12.0)
	kick(0.25)
	return true


func _rift_target(dir: Vector3) -> Vector3:
	var from := global_position
	var space := get_world_3d().direct_space_state
	if space == null or _col == null:
		return from + dir * step_range
	var lift := Vector3.UP * 0.5              # clear stair risers and small lips
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _col.shape
	q.transform = Transform3D(_col.global_basis, _col.global_position + lift)
	q.motion = dir * step_range
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	q.margin = 0.04
	var frac: PackedFloat32Array = space.cast_motion(q)
	var safe: float = frac[0] if frac.size() > 0 else 1.0
	var dest := from + lift + dir * step_range * safe
	var r := PhysicsRayQueryParameters3D.create(dest + Vector3.UP * 0.4, dest + Vector3.DOWN * 3.0, collision_mask, [get_rid()])
	var hit := space.intersect_ray(r)
	if not hit.is_empty():
		dest = (hit.position as Vector3) + Vector3.UP * 0.02
	return dest


func _mark_path(from: Vector3, to: Vector3) -> void:
	var a := from + Vector3.UP
	var b := to + Vector3.UP
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var c := e.global_position + Vector3.UP * 0.9
		if c.distance_to(Geometry3D.get_closest_point_to_segment(c, a, b)) < 1.2:
			e.add_mark(1)
			Vfx.burst(c, SpellFx.VIOLET_HOT, {"count": 16, "life": 0.35, "speed": Vector2(2.0, 4.5), "size": 0.04, "gravity": -3.0, "trail": 0.06})


## The body stays unseen for `step_reveal` at the far end, then re-forms out of the tear.
func _tick_step(delta: float) -> void:
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.0
		_visual.visible = true
		_step_burst()
	_update_gloom(delta)
	RenderingServer.global_shader_parameter_set("push_pos", global_position)


func _step_burst() -> void:
	var at := global_position + Vector3.UP * 1.0
	Vfx.burst(at, Color(0.02, 0.01, 0.04, 0.85), {"count": 18, "life": 0.7, "speed": Vector2(0.4, 1.6), "size": 0.45, "gravity": 0.6, "radius": 0.35, "additive": false, "turbulence": true})
	Vfx.burst(at, VIOLET, {"count": 22, "life": 0.45, "speed": Vector2(1.5, 3.5), "size": 0.04, "gravity": 0.0, "radius": 0.3, "trail": 0.07})


func nova_fx(radius: float, detonated: Array) -> void:
	_visual.cast()
	Sfx.play(SFX_NOVA, global_position, 0.0)
	var at := global_position + Vector3.UP * 0.9
	SpellFx.nova(global_position, radius)     # round disc drawn at exactly the damage radius
	for e in detonated:
		var en := e as Node3D
		if en == null or not is_instance_valid(en):
			continue
		var hit := en.global_position + Vector3.UP * 1.0
		Vfx.arc(at, hit, Color(1.8, 1.0, 3.2), 0.28, 0.35)
		Vfx.burst(hit, Color(2.0, 1.1, 3.4), {"count": 26, "life": 0.4, "speed": Vector2(2.5, 6.0), "size": 0.05, "trail": 0.08, "gravity": -4.0})


# --- Movement: double jump, slide ----------------------------------------------------------

func _setup_movement_fx() -> void:
	_slide_fx = Vfx.emitter(Color(0.55, 0.5, 0.7, 0.55), {"count": 40, "life": 0.5, "speed": Vector2(0.5, 2.0), "size": 0.18, "gravity": -1.0, "dir": Vector3.UP, "spread": 60.0, "additive": false, "radius": 0.2})
	add_child(_slide_fx)
	var sparks := Vfx.emitter(Color(1.6, 0.9, 2.4), {"count": 24, "life": 0.25, "speed": Vector2(2.0, 4.0), "size": 0.03, "gravity": -8.0, "dir": Vector3.UP, "spread": 70.0, "trail": 0.05})
	sparks.name = "Sparks"
	_slide_fx.add_child(sparks)
	_slide_sfx = AudioStreamPlayer3D.new()
	var scrape := Sfx.stream("res://art/audio/slide_scrape.wav")
	if scrape is AudioStreamWAV:
		var w := (scrape as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
		scrape = w
	_slide_sfx.stream = scrape
	_slide_sfx.volume_db = -8.0
	add_child(_slide_sfx)
	_charge_fx = Vfx.emitter(Color(2.4, 0.8, 0.25), {"count": 40, "life": 0.45, "speed": Vector2(0.0, 0.3), "size": 0.045, "gravity": 0.6, "radius": 0.75, "radial": -9.0, "swirl": 4.0, "damping": 0.5, "trail": 0.08})
	_charge_fx.top_level = true
	add_child(_charge_fx)
	_charge_sfx = AudioStreamPlayer3D.new()
	var charge := Sfx.stream("res://art/audio/lance_charge.wav")
	if charge is AudioStreamWAV:
		var c := (charge as AudioStreamWAV).duplicate() as AudioStreamWAV
		c.loop_mode = AudioStreamWAV.LOOP_FORWARD
		c.loop_begin = int(0.6 * float(c.mix_rate))
		c.loop_end = int(c.get_length() * float(c.mix_rate))
		charge = c
	_charge_sfx.stream = charge
	_charge_sfx.volume_db = -7.0
	add_child(_charge_sfx)


func _air_jump(wish: Vector3, sprint: bool) -> void:
	_air_jumps_left -= 1
	velocity.y = air_jump_velocity
	_jump_rising = true
	if wish.length_squared() > 0.01:
		# the second jump re-aims: lets you correct a bad first jump or chase a pouncer down
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var speed := maxf(flat.length(), sprint_speed if sprint else walk_speed)
		var aimed := flat.lerp(wish.normalized() * speed, 0.7)
		velocity.x = aimed.x
		velocity.z = aimed.z
	_visual.air_tuck()
	var feet := global_position + Vector3.UP * 0.1
	Vfx.ring(feet, 1.1, Color(1.2, 0.55, 2.8), 0.32, 0.12)
	Vfx.burst(feet, Color(1.4, 0.65, 3.0), {"count": 24, "life": 0.4, "speed": Vector2(1.5, 3.5), "size": 0.04, "dir": Vector3.DOWN, "spread": 70.0, "gravity": 0.0, "trail": 0.06})
	Vfx.burst(feet, Color(0.04, 0.02, 0.08, 0.6), {"count": 10, "life": 0.6, "speed": Vector2(0.5, 1.2), "size": 0.3, "dir": Vector3.DOWN, "spread": 80.0, "gravity": 0.3, "additive": false})
	Sfx.play(SFX_JUMP, feet, -5.0)


## Held slide key: on the ground it slides once per press (and keeps trying until fast enough,
## which doubles as an input buffer through the cooldown); in the air it crouches and queues,
## and the landing drops straight into a slide that banks part of the fall speed.
func _slide_input(horiz: Vector3, wish: Vector3) -> void:
	if not Input.is_action_pressed("slide"):
		return
	if not is_on_floor():
		_slide_queued = true
		_visual.hold_tuck(0.6)
		return
	if _slide_queued:
		_slide_queued = false
		_slide_latch = true
		_try_slide(horiz, wish, slide_land_min, slide_land_gain * maxf(0.0, -_air_vy))
	elif not _slide_latch and _try_slide(horiz, wish, slide_min_speed, 0.0):
		_slide_latch = true


func _try_slide(horiz: Vector3, wish: Vector3, min_speed: float, bonus: float) -> bool:
	var speed := horiz.length()
	if _slide_cd > 0.0 or not is_on_floor() or speed < min_speed:
		return false
	_sliding = true
	_slide_t = 0.0
	_slide_air = 0.0
	_slide_dir = (horiz if speed > 0.1 else wish).normalized()
	_slide_speed = maxf(speed * slide_boost, sprint_speed * 1.15) + bonus
	_set_capsule(1.0)
	_slide_fx.emitting = true
	(_slide_fx.get_node("Sparks") as GPUParticles3D).emitting = true
	_slide_sfx.play()
	_fov_kick = maxf(_fov_kick, 8.0)
	kick(0.3 + minf(bonus * 0.05, 0.3))
	return true


func _tick_slide(delta: float, wish: Vector3) -> Vector3:
	_slide_t += delta
	_slide_blend = move_toward(_slide_blend, 1.0, delta * 8.0)
	var downhill := 0.0
	if is_on_floor():
		_slide_air = 0.0
		var n := get_floor_normal()
		var down := Vector3(n.x, 0.0, n.z)            # horizontal part of the normal points downhill
		downhill = down.dot(_slide_dir)
		_slide_speed += downhill * slide_slope_gain * delta
	else:
		_slide_air += delta
	_slide_speed = maxf(0.0, _slide_speed - slide_friction * delta * (1.0 - clampf(downhill * 3.0, 0.0, 0.9)))
	if wish.length_squared() > 0.01:
		var w := wish.normalized()
		var turn := clampf(_slide_dir.signed_angle_to(w, Vector3.UP), -1.4 * delta, 1.4 * delta)
		_slide_dir = _slide_dir.rotated(Vector3.UP, turn)
	var horiz := _slide_dir * _slide_speed
	velocity.x = horiz.x
	velocity.z = horiz.z
	_slide_fx.global_position = global_position + Vector3.UP * 0.05
	_slide_sfx.pitch_scale = 0.7 + 0.06 * _slide_speed
	var limit := slide_max_time + maxf(0.0, downhill) * 3.0
	var held := Input.is_action_pressed("slide") or _slide_t < 0.3
	if _slide_speed < 2.4 or _slide_t > limit or _slide_air > 0.18 or not held:
		_end_slide()
	return horiz


func _end_slide() -> void:
	if not _sliding:
		return
	_sliding = false
	_slide_cd = slide_cooldown
	_set_capsule(_col_h)
	_slide_fx.emitting = false
	(_slide_fx.get_node("Sparks") as GPUParticles3D).emitting = false
	_slide_sfx.stop()


func _set_capsule(h: float) -> void:
	if _col == null or not (_col.shape is CapsuleShape3D):
		return
	var cap := _col.shape as CapsuleShape3D
	cap.height = maxf(h, cap.radius * 2.0)
	_col.position.y = _col_y - (_col_h - cap.height) * 0.5


func is_sliding() -> bool:
	return _sliding


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
