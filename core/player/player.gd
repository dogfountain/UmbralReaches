class_name Player
extends CharacterBody3D
## Third-person wanderer: movement, orbit camera, lantern, Gloom, interaction, autopilot (demo/tests).

## Components (core/player/player_*.gd): the state stays on Player, the logic lives here.
var autopilot_ctl: PlayerAutopilot = null
var targeting: PlayerTargeting = PlayerTargeting.new(self)
var camera_ctl: PlayerCamera = PlayerCamera.new(self)
var vitals: PlayerVitals = PlayerVitals.new(self)
var locomotion: PlayerLocomotion = PlayerLocomotion.new(self)
var traversal: PlayerTraversal = PlayerTraversal.new(self)
var evasion: PlayerEvasion = PlayerEvasion.new(self)

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var accel := 14.0               ## ground, rest -> walk (exponential rate; ~0.16 s to 90 %)
@export var sprint_accel := 6.5         ## ground, walk -> sprint: a run builds up over ~0.3 s
@export var decel := 14.0               ## ground, stopping: exponential part ...
@export var decel_bite := 8.0           ## ... plus this constant m/s², so the stop has no long tail
@export var coast := 6.0                ## sprint released while moving: ease back down to walk
@export var turn_rate := 13.0           ## rad/s the run swings toward the stick at walk pace ...
@export var turn_rate_sprint := 8.0     ## ... and at a full sprint (wider arcs, keeps speed)
@export var skid_angle := 2.2           ## a reversal sharper than this (rad) brakes instead of arcing
@export var air_accel := 8.5            ## air steering; weaker than ground but enough to correct a jump
@export var air_drag := 0.6             ## no stick in the air: momentum is kept, barely bled
@export var jump_velocity := 5.2
@export var gravity := 16.0
@export var coyote_time := 0.13         ## grace to still jump just after walking off an edge
@export var jump_buffer := 0.15         ## a jump pressed just before landing still fires
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
var invert_y := false
@export var stick_sensitivity := 2.6
@export var pitch_min := -1.0
@export var pitch_max := 0.6
@export_group("Gloom")
@export var gloom_max := 100.0
@export var gloom_rate_dark := 3.0      ## per second away from light: ~33 s of open dark fills the bar, so the Shade is a real chance
@export var gloom_rate_rift := 5.0      ## per second in the Ashen Rift proper: ~20 s to a Shade
@export var gloom_drain_lit := 12.0     ## per second inside a fire (a ward drains at its own rate)
@export var rift_z := -40.0             ## world z beyond which the rift rate may apply (plus region "rift")
@export var rift_enabled := true
@export var interact_range := 2.8

## r35 (docs/critique/r35_full.md "Decisions"): one rule per bar.
##   Gloom  = the dark's clock only: it gathers away from light (and as spells' cost), a fire drains
##            it, and at gloom_max a Shade takes shape and hunts you. The Shade's touch hollows you.
##   Wounds = what blows do: foes, bosses, their hazards, long falls, lava. A fire mends them, kills
##            and spent Resonance mend a little. At wounds_max you are hollowed.
var gloom := 0.0
var wounds := 0.0
@export var wounds_max := 120.0         ## ~5 plain strikes (25) from whole to hollowed
@export var wounds_mend_lit := 14.0     ## per second inside a fire (scaled like the Gloom drain by lit_mult)
var checkpoint := Vector3.ZERO
var ward_drain_left := 0.0              ## Gloom the current Lantern Ward may still drain (LanternWard sets it)

const SPRINT_DARK_MULT := 1.5           ## sprinting in the dark gathers Gloom this much faster (noise)
const SLIDE_EVADE := 0.22               ## a slide's first moments pass under strikes, like a roll
var _ash_banked := -1                   ## grave ash held at the last fire; above it is "carried"
var autopilot := false
var hollow_count := 0
var _wait := 0.0
var _waiting := false
var _yaw := 0.0
var _pitch := -0.18
var _t := 0.0
var _shade: Shade
var _shade_lock := 0.0
var _hollowing := false
var _coyote := 0.0
var _buffered_jump := 0.0
var _fov_burst_want := 0.0
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
var _shake := 0.0
const BOLT := preload("res://core/player/magic_bolt.tscn")
# r31 combat and traversal (Enshrouded pass): Breath, staff arts, the Tether line, the cloak-glide
const Stamina := preload("res://core/player/stamina.gd")
const StaffArts := preload("res://core/player/staff_arts.gd")
const Grapple := preload("res://core/player/grapple.gd")
const BreathMeter := preload("res://ui/breath_meter.gd")
const PERFECT_T := 0.2                  ## a dodge roll that a blow meets this early is a perfect dodge
const FALL_HURT_V := 16.0               ## landings harder than this (m/s down, ~6 m) wound you ...
const FALL_GLOOM := 2.6                 ## ... this much per m/s over (halved when rolled out), never to wounds_max
const GLIDE_SINK := 2.3                 ## m/s down under the spread robe
const GLIDE_SPEED := 8.8
const GLIDE_TURN := 2.6                 ## rad/s
const GLIDE_MIN_H := 1.6                ## need this much air under the feet to open the robe
const LOCK_AIM_RANGE := 40.0
const CLOSE_ASSIST_COS := 0.82          ## aim assist up close: ~35 degrees at 1 m, narrowing to ASSIST_COS by 9 m
var _stam: Node
var _arts: Node
var _grapple: Node
var _gliding := false
var _glide_k := 0.0
var _dodge_roll := false
var _face_yaw := 0.0
var _rolled_landing := false
var glides := 0                         ## tests
var falls_hurt := 0.0                   ## tests: Gloom from the last hard landing

@export_group("Rift Step")
@export var step_range := 7.5           ## metres per teleport (shortened by walls, settled onto ground)
@export var step_reveal := 0.1          ## seconds unseen at the far end before the body re-forms
@export var step_evade := 0.35          ## untouchable window from the moment you tear out
@export var slide_land_min := 2.0       ## a slide held through a landing needs only this much speed
@export var slide_land_gain := 0.35     ## and converts this share of the fall speed into slide speed
const COMBAT_FACE_TIME := 1.4           ## after a cast the body faces the camera, not the motion

var _book: SkillBook
var _wish_len := 0.0
var _step_t := 0.0
var _evade_t := 0.0
var _combat_t := 0.0

var _air_jumps_left := 1
var _jump_rising := false
var _sliding := false
var _slide_cd := 0.0
var _slide_dir := Vector3.FORWARD
var _slide_blend := 0.0
var _cam_drop := 0.0
var _col: CollisionShape3D
var _col_h := 1.7
var _col_y := 0.85
var _slide_fx: GPUParticles3D
var _slide_sfx: AudioStreamPlayer3D
var _charge_fx: GPUParticles3D
var _charge_orb: MeshInstance3D
var _charge_halo: MeshInstance3D
var _charge_light: OmniLight3D
var _charge_sfx: AudioStreamPlayer3D
var _charge_was_full := false
var _charge_c := 0.0                    ## the SkillBook's charge (physics tick); drawn per frame
var _tp_offset := Vector3.ZERO          ## camera trails the body across a teleport, decays fast
# --- movement feel ---
const STEP_MAX := 0.45                  ## ledges up to this tall are walked straight up (no ramp needed)
const MANTLE_MAX := 1.1                 ## ledge top this far above the feet (with a jump: ledges up to ~2.4 m)
const MANTLE_TIME := 0.24
const APEX_GRAVITY := 0.62              ## gravity scale near the top of a held jump (a little hang)
const FALL_GRAVITY := 1.3               ## gravity scale while falling (snappier landings)
const SLIDE_HOP_BOOST := 1.08           ## jumping out of a slide keeps its speed, plus a little
const STEP_DOWN := 0.5                  ## walking off a drop this small keeps you on the ground
const SLOPE_UPHILL_SLOW := 0.32         ## speed lost per unit of uphill grade (25 deg: -13 %)
const SLOPE_DOWNHILL_GAIN := 0.08
const LAND_SLOW_V := 7.5                ## landings harder than this (m/s down) cost speed briefly
const ARM_LEN := 3.7                    ## camera distance (stair spring length)
const ARM_PROBE := 0.24                 ## camera collision sphere
var _grounded := true                   ## on the floor this frame (move_and_slide, or glued down a step)
var _glued := false
var _vis_off := Vector3.ZERO            ## visual-only offset: step-ups/downs ease instead of popping
var _vis_off_v := Vector3.ZERO
var _cam_off := Vector3.ZERO            ## the same for the camera pivot, slower
var _cam_off_v := Vector3.ZERO
var _cam_off_prev := Vector3.ZERO       ## last tick's value: _process interpolates like the body does
var _last_pos := Vector3.INF            ## where physics left the body: a bigger jump = moved from outside
var _land_slow := 0.0
var _run_blend := 0.0                   ## 0 walk .. 1 full sprint (camera, turn rate)
var _mantle_t := -1.0
var _slide_latch := false               ## a held key slides once; release to arm the next
var _slide_queued := false              ## slide held in the air: drop into it on landing
var _air_vy := 0.0                      ## last airborne vertical speed (landing -> slide bonus)
var _aim_ring: MeshInstance3D
var _safe_ground := Vector3.INF          ## last flat ground stood on for 0.25 s (lava recovery)
var _ground_t := 0.0
var _burn_cd := 0.0

const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const SFX_JUMP := "res://art/audio/jump_air.wav"
const SFX_STEP := "res://art/audio/step_blink.wav"
const SFX_HURT := "res://art/audio/hurt.wav"
const SFX_NOVA := "res://art/audio/nova_boom.wav"
const SFX_LANCE := "res://art/audio/lance_fire.wav"
const VIOLET := Color(1.3, 0.6, 3.0)
const EMBER := Color(2.6, 0.9, 0.3)

@onready var _visual: CharacterRig = $Visual
## r36: the horse the wanderer sits (core/world/mount/horse.gd), or null.
var riding: Node3D = null
@onready var _rig: Node3D = $CameraRig
@onready var _pitch_node: Node3D = $CameraRig/Pitch
@onready var _arm: SpringArm3D = $CameraRig/Pitch/SpringArm
@onready var _cam: Camera3D = $CameraRig/Pitch/SpringArm/Camera


func _ready() -> void:
	add_child(targeting)
	add_child(camera_ctl)
	add_child(vitals)
	add_child(locomotion)
	add_child(traversal)
	add_child(evasion)
	add_to_group(Groups.PLAYER)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.PROPS
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true             # slope speed is ours (SLOPE_*), not a side effect of the solver
	_arm.spring_length = ARM_LEN
	_arm.collision_mask = 0                 # the arm's own probe snaps; _update_arm eases it instead
	# SpringArm3D moves its camera only on physics ticks (internal physics process): at 120 fps
	# every zoom (running, sliding, easing back from a wall) stepped on alternate frames and read
	# as sub-60. _update_arm places the camera every rendered frame instead.
	_arm.set_physics_process_internal(false)
	if Travel.pending:
		global_position = Travel.spawn
		_yaw = Travel.yaw
		gloom = Travel.gloom
		wounds = Travel.wounds
		hollow_count = Travel.hollow_count
		Travel.consume()
		Events.gloom_changed.emit(gloom, gloom_max)
		Events.wounds_changed.emit(wounds, wounds_max)
	else:
		_yaw = _rig.rotation.y
		hollow_count = Travel.saved_hollows
		# continue from the last kindled brazier of this night (savegame)
		var saved := Travel.checkpoint_for(owner.scene_file_path if owner else "")
		if saved != Vector3.INF:
			global_position = saved
	checkpoint = global_position
	_ash_banked = Travel.count("grave_ash")
	Events.enemy_killed.connect(vitals._on_enemy_killed)
	Events.skill_cast.connect(_on_skill_cast)
	_rig_height = _rig.position.y
	# Interpolated cameras: rig is top-level so look isn't stuck on the 60 Hz physics tick.
	_rig.top_level = true
	_rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rig.global_position = global_position + Vector3(0.0, _rig_height, 0.0)
	_rig.global_rotation = Vector3(0.0, _yaw, 0.0)
	if _visual:
		_visual.rotation.y = _yaw
	_arm.add_excluded_object(get_rid())
	_arm.position.x = SHOULDER
	_cam.h_offset = 0.12
	_visual.driven = true
	_visual.set_process(_visual.has_merged_body())     # it blends the body's bones between ticks
	_visual.walk_speed = walk_speed
	_visual.sprint_speed = sprint_speed
	_setup_interact_sensor()
	_col = get_node_or_null("Collision") as CollisionShape3D
	if _col and _col.shape is CapsuleShape3D:
		_col.shape = _col.shape.duplicate()          # we resize it for the slide
		_col_h = (_col.shape as CapsuleShape3D).height
		_col_y = _col.position.y
	locomotion._setup_movement_fx()
	_aim_ring = SpellFx.target_ring()
	add_child(_aim_ring)
	_book = SkillBook.new()
	_book.name = "SkillBook"
	add_child(_book)
	_stam = Stamina.new()
	_stam.name = "Stamina"
	add_child(_stam)
	_arts = StaffArts.new()
	_arts.name = "StaffArts"
	add_child(_arts)
	_grapple = Grapple.new()
	_grapple.name = "Grapple"
	add_child(_grapple)
	if owner != null and get_tree().current_scene == owner:
		var hud_layer := CanvasLayer.new()
		hud_layer.name = "BreathLayer"
		hud_layer.layer = 9
		var meter := BreathMeter.new()
		meter.player = self
		hud_layer.add_child(meter)
		add_child(hud_layer)


func _unhandled_input(event: InputEvent) -> void:
	if autopilot:
		return
	if event is InputEventJoypadButton and event.is_action_pressed("sprint"):
		_sprint_latch = not _sprint_latch      # pad: L3 latches the sprint until you stop (holding a stick click hurts)
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_instance_valid(_lock):
		_lock_flick += event.relative.x                     # locked: a hard flick moves the lock
		_lock_flick_t = 0.25
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_recentre = false
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0), pitch_min, pitch_max)
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact"):
		if not (_interact_target == null and _grapple != null and _grapple.try_fire()):
			_try_interact()                    # r31: nothing to use here: the Tether line bites a marked anchor
	elif event.is_action_pressed("lock_on"):
		targeting._toggle_lock()
	elif event.is_action_pressed("target_next"):
		targeting.cycle_target()


func _process(delta: float) -> void:
	if _first_frame:
		_first_frame = false
		# the night just showed (the loading screen held this node until now): take the mouse, so the
		# first move of it turns the view instead of moving a cursor until some click (r29). Only in
		# the real game, never under a zz/ harness, and never from a window in the background.
		if not autopilot and owner != null and get_tree().current_scene == owner and DisplayServer.window_is_focused():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not autopilot:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if is_instance_valid(_lock):
			if absf(look.x) > 0.75 and _lock_flick_t <= 0.0:
				_lock_flick = signf(look.x) * 100.0      # stick flick: next target that side
				_lock_flick_t = 0.4
			look = Vector2.ZERO
		var mag := look.length()
		_look_hold = _look_hold + delta if absf(look.x) > 0.9 else 0.0
		if mag > 0.15:
			_recentre = false
			# r29: a response curve (fine aim near the centre, full speed at the rim) and, held hard
			# over, a turn that speeds up so a 180 doesn't take 1.2 s
			look = look / mag * pow(mag, 1.6)
			var boost := 1.0 + 0.6 * smoothstep(0.2, 0.6, _look_hold)
			_yaw -= look.x * stick_sensitivity * boost * delta
			_pitch = clampf(_pitch - look.y * stick_sensitivity * 0.8 * delta * (-1.0 if invert_y else 1.0), pitch_min, pitch_max)
	var body_xf := get_global_transform_interpolated()
	# grass parts around the body where it is DRAWN (r29: set on the tick, the parting stepped at 60 Hz)
	RenderingServer.global_shader_parameter_set("push_pos", body_xf.origin)
	if is_instance_valid(_lock):
		targeting._lock_view(delta, body_xf.origin)
	elif _recentre:
		var behind := _visual.global_rotation.y
		_yaw = lerp_angle(_yaw, behind, 1.0 - exp(-9.0 * delta))
		_pitch = lerpf(_pitch, -0.18, 1.0 - exp(-6.0 * delta))
		if absf(angle_difference(_yaw, behind)) < 0.02:
			_recentre = false
	_cam_drop = lerpf(_cam_drop, 0.55 * _slide_blend, 1.0 - exp(-12.0 * delta))
	_tp_offset = _tp_offset.lerp(Vector3.ZERO, 1.0 - exp(-20.0 * delta))
	# stairs: the view glides up/down instead of stepping. The offset is stepped on physics ticks
	# and interpolated with the same fraction as the body, so a pop and its cancel land together.
	var fr := Engine.get_physics_interpolation_fraction()
	var cam_off := _cam_off_prev.lerp(_cam_off, fr)
	cam_off.y += lerpf(_cam_air_prev, _cam_air, fr)
	cam_off += _look_ahead_prev.lerp(_look_ahead, fr)
	_rig.global_position = body_xf.origin + Vector3(0.0, _rig_height - _cam_drop, 0.0) + cam_off + _tp_offset
	_rig.global_rotation = Vector3(0.0, _yaw, 0.0)
	camera_ctl._cam_frame(delta)
	_pitch_node.rotation.x = _pitch - _land_dip * 0.12 + _shake
	camera_ctl._update_arm(delta)
	_frame_fx()


func _physics_process(delta: float) -> void:
	_t += delta
	if _last_pos != Vector3.INF and global_position.distance_squared_to(_last_pos) > 4.0:
		locomotion._on_teleported()                        # tests, respawns, travel: plain global_position works
	_cam_off_prev = _cam_off
	camera_ctl._spring3(true, 11.0, delta)                 # critically damped: no velocity kick on a step
	_shade_lock = maxf(0.0, _shade_lock - delta)
	_evade_t = maxf(0.0, _evade_t - delta)
	_combat_t = maxf(0.0, _combat_t - delta)
	if _mantle_t >= 0.0:
		traversal._tick_mantle(delta)
		return
	if _step_t > 0.0:
		evasion._tick_step(delta)
		return
	if _grapple != null and _grapple.pulling():
		_grapple.tick(delta)
		_grounded = false
		_animate(delta, Vector3(velocity.x, 0.0, velocity.z))
		vitals._update_gloom(delta)
		return
	if _gliding and (_hang or _climb_t >= 0.0 or _vault_t >= 0.0):
		evasion._end_glide()

	var wish := Vector3.ZERO
	var sprint := false
	if not _hollowing:
		if _debug_drive:
			wish = _debug_wish
			sprint = _debug_sprint
		elif autopilot:
			var cmd := _ap()._autopilot(delta)
			wish = cmd[0]
			sprint = cmd[1]
		else:
			var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			wish = Basis(Vector3.UP, _yaw) * Vector3(v.x, 0.0, v.y)
			if v.length_squared() < 0.04:
				_sprint_latch = false
			sprint = Input.is_action_pressed("sprint") or _sprint_latch
	_wish_len = wish.length()
	# r36 on horseback (core/world/mount/horse.gd): the horse takes the wish; jump gets down
	if riding != null:
		if not is_instance_valid(riding) or _hollowing:
			riding = null
		else:
			if Input.is_action_just_pressed("jump"):
				riding.call("dismount")
			else:
				riding.call("drive", self, wish, sprint, delta)
				_grounded = true
				_visual.ride = move_toward(_visual.ride, 1.0, delta * 4.0)
				_visual.animate(Vector3.ZERO, true, delta)
				vitals._update_gloom(delta)
				return
	if _visual.ride > 0.0:
		_visual.ride = move_toward(_visual.ride, 0.0, delta * 4.0)

	if sprint and _stam != null:
		# r31 Breath: winded, no sprint; hunted (a foe awake near), the sprint spends it
		if _stam.winded or (_arts != null and (_arts.guarding() or _arts.busy())):
			sprint = false
		elif _stam.in_fight() and _grounded and wish.length_squared() > 0.04 and not autopilot:
			_stam.drain(Stamina.SPRINT_COST * delta)
	targeting._lock_tick(delta)
	if _climb_t >= 0.0:
		traversal._tick_climb(delta)
		return
	if _hang:
		traversal._tick_hang(delta, wish)
		return
	if _vault_t >= 0.0:
		traversal._tick_vault(delta)
		return
	if not autopilot and not _hollowing and Input.is_action_just_pressed("dodge") and evasion._try_dodge(wish):
		pass
	_slide_cd = maxf(0.0, _slide_cd - delta)
	_land_slow = move_toward(_land_slow, 0.0, delta * 2.2)
	if not Input.is_action_pressed("slide"):
		_slide_latch = false
		_slide_queued = false
	if _grounded:
		_air_jumps_left = air_jumps
	var horiz: Vector3
	if _roll_t >= 0.0:
		horiz = evasion._tick_roll(delta, wish)
		velocity.x = horiz.x
		velocity.z = horiz.z
	elif _arts != null and _arts.phase() >= 0 and _grounded:
		horiz = _arts.drive(wish)                 # r31: a staff strike steps in to its target
		velocity.x = horiz.x
		velocity.z = horiz.z
	elif _gliding:
		horiz = evasion._tick_glide(delta, wish)
		velocity.x = horiz.x
		velocity.z = horiz.z
	elif _sliding:
		horiz = locomotion._tick_slide(delta, wish)
	elif not _grounded and _steep_t > 0.0 and velocity.y <= 0.5:
		horiz = traversal._tick_steep(delta, wish, Vector3(velocity.x, 0.0, velocity.z))
		velocity.x = horiz.x
		velocity.z = horiz.z
	else:
		var target := wish * (sprint_speed if sprint else walk_speed) * _book.move_scale() * (float(_arts.move_scale()) if _arts != null else 1.0)
		var cur := Vector3(velocity.x, 0.0, velocity.z)
		if _grounded:
			target *= locomotion._slope_scale(target) * (1.0 - _land_slow)
			if _beam_k > 0.3:
				# balancing: careful steps along it, the stick's sideways push mostly ignored
				target -= _beam_side * target.dot(_beam_side) * 0.85 * _beam_k
				target = target.limit_length(walk_speed * 0.72)
			horiz = locomotion._ground_move(cur, target, delta)
			if _beam_k > 0.3 and _beam_mid != 0.0:
				horiz += _beam_side * _beam_mid * 8.0 * _beam_k      # eased back toward the middle
		elif target.length_squared() > 0.0001 and _kick_lock <= 0.0:
			# air: steer toward the stick, never faster than you already were (or a sprint)
			horiz = cur.lerp(target, 1.0 - exp(-air_accel * delta))
			horiz = horiz.limit_length(maxf(cur.length(), sprint_speed))
		else:
			horiz = cur * exp(-air_drag * delta)
		velocity.x = horiz.x
		velocity.z = horiz.z
		if not autopilot and not _hollowing:
			locomotion._slide_input(horiz, wish)
			if traversal._try_vault(horiz, wish):
				return
	_run_blend = lerpf(_run_blend, clampf((horiz.length() - walk_speed) / maxf(sprint_speed - walk_speed, 0.1), 0.0, 1.0) if _grounded else _run_blend, 1.0 - exp(-5.0 * delta))

	# Coyote time and jump buffering: without them, a jump pressed one frame early or one frame
	# late is silently dropped, which is most of what made the movement feel unresponsive.
	_coyote = coyote_time if _grounded else maxf(0.0, _coyote - delta)
	_buffered_jump = maxf(0.0, _buffered_jump - delta)
	if not autopilot and not _hollowing:
		if Input.is_action_just_pressed("jump"):
			if traversal._can_wallkick(wish):
				traversal._wall_kick(wish)
			elif _steep_t > 0.0 and not _grounded and _coyote <= 0.0:
				var off := Vector3(_steep_n.x, 0.0, _steep_n.z).normalized()   # leap off the slope
				velocity = Vector3(velocity.x, 0.0, velocity.z) * 0.6 + off * 3.0 + Vector3.UP * jump_velocity
				_steep_t = 0.0
				_jump_rising = true
				_visual.jump_start()
			elif _gliding:
				evasion._end_glide()                     # r31: fold the robe, drop
			elif _coyote <= 0.0 and not _grounded and _air_jumps_left > 0 and (_stam == null or _stam.spend(Stamina.AIR_JUMP)):
				locomotion._air_jump(wish, sprint)
			elif _coyote <= 0.0 and not _grounded and evasion._can_glide():
				evasion._start_glide()                   # r31: out of jumps in the air: spread the robe
			else:
				_buffered_jump = jump_buffer
		# variable height: let go while rising and the arc flattens
		if _jump_rising and not Input.is_action_pressed("jump") and velocity.y > 0.0:
			velocity.y *= jump_cut
			_jump_rising = false
	if _buffered_jump > 0.0 and _coyote > 0.0:
		if _sliding:
			locomotion._end_slide()                 # slide-hop: the slide's speed carries into the jump, plus a little
			var hv := Vector2(velocity.x, velocity.z) * SLIDE_HOP_BOOST
			hv = hv.limit_length(sprint_speed * 1.7)
			velocity.x = hv.x
			velocity.z = hv.y
		velocity.y = jump_velocity
		_buffered_jump = 0.0
		_coyote = 0.0
		_jump_rising = true
		_grounded = false
		_glued = false
		_visual.jump_start()
	if not _grounded and _gliding:
		var lift := evasion._updraft(global_position)
		var want_vy := lift if lift > 0.0 else -GLIDE_SINK
		velocity.y = move_toward(velocity.y, want_vy, (16.0 if velocity.y < want_vy - 4.0 else 9.0) * delta)
	elif not _grounded:
		var g := gravity
		if velocity.y < 0.0:
			g *= FALL_GRAVITY
		elif _jump_rising and Input.is_action_pressed("jump") and velocity.y < 1.6:
			g *= APEX_GRAVITY
		velocity.y -= g * delta
	elif velocity.y <= 0.0:
		_jump_rising = false
	var vy_before := velocity.y
	var was_grounded := _grounded
	var pre_h := Vector3(velocity.x, 0.0, velocity.z)
	var y0 := global_position.y
	move_and_slide()
	_grounded = is_on_floor()
	_glued = false
	if not autopilot and not _hollowing:
		if _grounded:
			if locomotion._try_step_up(pre_h, delta):
				velocity.x = pre_h.x             # a riser doesn't eat the stride
				velocity.z = pre_h.z
		elif wish.length_squared() > 0.1 and traversal._try_mantle(wish):
			return
		elif not _grounded and traversal._try_grab(wish):
			return
	if not _grounded and was_grounded and velocity.y <= 0.0 and not _jump_rising and global_position.y <= y0 + 0.002:
		locomotion._step_down()
	traversal._note_contacts(delta)
	locomotion._land(was_grounded, vy_before)
	traversal._beam_probe(horiz)
	_beam_k = move_toward(_beam_k, 1.0 if _beam_on else 0.0, delta * (8.0 if _beam_on else 3.0))
	var steep_on := not _grounded and _steep_t > 0.0 and velocity.y <= 0.5
	_steep_k = move_toward(_steep_k, 1.0 if steep_on else 0.0, delta * (6.0 if steep_on else 4.0))
	if not steep_on and _steep_k <= 0.0 and not _sliding and _slide_fx.emitting:
		_slide_fx.emitting = false
		_slide_sfx.stop()
	_visual.steep = _steep_k
	_visual.beam = _beam_k
	camera_ctl._cam_feel_tick(delta)
	camera_ctl._spring3(false, 22.0, delta)
	_visual.position = global_basis.inverse() * _vis_off
	if not _grounded:
		_air_vy = velocity.y
		_ground_t = 0.0
	elif get_floor_normal().y > 0.85 and not _sliding:
		_ground_t += delta
		if _ground_t > 0.25:
			_safe_ground = global_position
	_burn_cd = maxf(0.0, _burn_cd - delta)

	camera_ctl._update_camera(delta, horiz, sprint, vy_before)
	_sprint_held = sprint
	_animate(delta, horiz)
	vitals._update_gloom(delta)
	_scan_interactables()
	_fall_t = _fall_t + delta if not _grounded and velocity.y < -1.0 and _steep_t <= 0.0 and not _gliding else 0.0
	if _gliding and (_grounded or is_on_ceiling()):
		evasion._end_glide()
	_glide_k = move_toward(_glide_k, 1.0 if _gliding else 0.0, delta * (5.0 if _gliding else 7.0))
	_visual.set("glide", _glide_k)
	if global_position.y < -40.0 or _fall_t > FALL_RESCUE_T:
		vitals._fell_out()      # fell into the chasm, or through the world
	vitals._stuck_tick(delta, wish)


func set_checkpoint(at: Vector3) -> void:
	checkpoint = at
	_ash_banked = Travel.count("grave_ash")   # what you carry is banked at a fire
	Travel.note_checkpoint(owner.scene_file_path if owner else "", at)


const ASH_MOUND := preload("res://core/player/ash_mound.gd")
const Hints := preload("res://ui/hints.gd")
const KILL_RELIEF := 6.0        ## Wounds each kill mends (r35; it drained Gloom before the split)
const CHAIN_WINDOW := 4.0       ## kills this close together chain; each link mends 2 more
const HURT_GRACE := 0.35        ## seconds after a hit during which further hits are ignored
const ASSIST_COS := 0.9945      ## aim assist cone: ~6 degrees either side of the crosshair
const ASSIST_RANGE := 32.0
var _hurt_grace_until := 0.0
var _chain := 0
var _chain_until := 0.0
var _riposte_ready := false
var _riposte_cd := 0.0


func debug_drive(wish: Vector3, sprint := false) -> void:
	_debug_drive = wish.length_squared() > 0.0001
	_debug_wish = wish
	_debug_sprint = sprint


# --- Animation ---------------------------------------------------------------

func _animate(delta: float, horiz: Vector3) -> void:
	# casting / locked on: square up or twist the chest toward the aim; otherwise face the run
	# (quick to turn from a walk, a wider sweep at a sprint; the body leans into it, see the rig)
	if _roll_t < 0.0 and _vault_t < 0.0 and not _hang and _climb_t < 0.0:
		targeting._facing(delta, horiz if _steep_k < 0.5 else Vector3(_steep_n.x, 0.0, _steep_n.z), _sprint_held)
	if _crawl:
		_slide_blend = move_toward(_slide_blend, 1.0, delta * 6.0)    # crawling out from under: the low pose
	elif not _sliding:
		_slide_blend = move_toward(_slide_blend, 0.0, delta * 6.0)
	_visual.slide = _slide_blend
	if _sliding:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-_slide_dir.x, -_slide_dir.z), 1.0 - exp(-12.0 * delta))
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = 0.2
		_look_foe = targeting._nearest_foe()
	if is_instance_valid(_lock):
		_visual.look_at_point = _lock.global_position + Vector3.UP * (_lock.hp_bar_y * 0.6)
	elif _look_foe and is_instance_valid(_look_foe) and _look_foe.is_alive():
		_visual.look_at_point = _look_foe.global_position + Vector3.UP * (_look_foe.hp_bar_y * 0.6)
	elif _cam:
		_visual.look_at_point = _cam.global_position - _cam.global_basis.z * 30.0
	_visual.animate(velocity, _grounded, delta)
	_last_pos = global_position


var _look_t := 0.0
var _look_foe: Enemy
var _sprint_held := false


func _on_skill_cast(id: StringName) -> void:
	_visual.cast_pose(id)


## True while any BossArena (or arena-like node in the "boss_arena" group) has a live fight.
static func boss_fight_active(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for a in tree.get_nodes_in_group(&"boss_arena"):
		if bool(a.get("_active")):
			return true
	return false


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
		match _interact_target.interact_feel():
			&"cast":
				_visual.cast()               # fires, wards and bells take the staff's magic
			&"talk":
				_visual.cast_pose(&"greet")  # people get a nod, not a spell in the face
			_:
				_visual.cast_pose(&"reach")
		_interact_target.interact(self)


## Spawn one staff bolt toward the crosshair. cfg keys (all optional): heavy, dmg, blast, speed,
## marks (Umbral Marks per hit), pierce. Skills call this; it owns aim, pooling and the gesture.
func fire_bolt(cfg: Dictionary) -> MagicBolt:
	if _hollowing or _visual == null:
		return null
	var host := get_tree().current_scene
	if host == null:
		return null
	# the staff's own voice: a lash for the empowered 3rd bolt; the Lance plays its throw below;
	# cfg.sound overrides (a staff core's own cast sound)
	var voice := "" if bool(cfg.get("heavy", false)) else ("lash" if bool(cfg.get("empower", false)) else "bolt")
	_visual.cast(String(cfg.get("sound", voice)))
	var pool := get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	var bolt: MagicBolt
	if pool:
		bolt = pool.take()
	else:
		bolt = BOLT.instantiate() as MagicBolt
		host.add_child(bolt)
	var muzzle := _visual.muzzle()
	var aim := _combat_aim(muzzle)
	if cfg.has("dir"):
		aim = (cfg.dir as Vector3).normalized()      # r36: a fanned throw (the Slag Heart's Scatter)
	var up := Vector3.UP
	if absf(aim.dot(up)) > 0.95:
		up = Vector3.RIGHT
	bolt.transform = Transform3D(Basis.looking_at(aim, up), muzzle + aim * 0.28)
	bolt.direction = aim
	bolt.arm_with(cfg)
	bolt.add_collision_exception_with(self)
	var heavy := bool(cfg.get("heavy", false))
	# r33 combat: a Lance spends Resonance (SkillBook.cast_power) and scars; a Rift Bolt builds it
	if heavy:
		bolt.hit_dmg *= _book.cast_power
		bolt.scar = 2 if _book.cast_spent >= 3 else 1
	else:
		bolt.resonant = 2 if bool(cfg.get("empower", false)) else 1
	var col := EMBER if heavy else VIOLET
	Vfx.burst(muzzle + aim * 0.2, col, {"count": 16 if heavy else 8, "life": 0.22, "speed": Vector2(1.5, 4.0), "size": 0.05, "dir": aim, "spread": 35.0, "gravity": 0.0, "trail": 0.05})
	Vfx.light(muzzle, Color(col.r, col.g, col.b) * 0.5, 2.5 if heavy else 1.6, 4.5, 0.12)
	# the orb flashes as the shot leaves it: a quick bright pulse and a ring along the aim
	SpellFx.shell(muzzle, 0.05, 0.4, Color(col.r, col.g, col.b) * (0.45 if heavy else 0.8), 0.1)
	Vfx.ring(muzzle + aim * 0.25, 0.55 if heavy else 0.32, col, 0.16, 0.08, aim)
	if heavy:
		StaffSfx.play("lance_fire", muzzle, -1.0)
		StaffSfx.play("swish", muzzle, -6.0)
	return bolt


## Soft aim assist: if an enemy's chest is within ~6 degrees of the aim and in clear sight, aim
## at it. Narrow on purpose -- it fixes near misses, it does not pick targets for you.
func _assist(muzzle: Vector3, aim: Vector3) -> Vector3:
	var best := aim
	var best_dot := -1.0
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var chest := e.global_position + Vector3.UP * (e.hp_bar_y * 0.55)
		var to := chest - muzzle
		var d := to.length()
		if d < 0.3 or d > ASSIST_RANGE:
			continue
		var dir := to / d
		# r31: up close the over-the-shoulder crosshair and the staff disagree by tens of degrees, so
		# the cone widens with nearness (~35 deg at 1 m) and narrows back to ~6 deg by 9 m. The pick is
		# by margin inside each foe's own cone, so a near foe off-centre does not steal from a far one
		# dead on the crosshair.
		var cone := lerpf(CLOSE_ASSIST_COS, ASSIST_COS, clampf((d - 1.0) / 8.0, 0.0, 1.0))
		var dt := dir.dot(aim)
		var flat_aim := Vector2(aim.x, aim.z).normalized()
		if d < 4.0:
			dt = maxf(dt, Vector2(dir.x, dir.z).normalized().dot(flat_aim))   # a squat foe under the crosshair
		if dt - cone <= best_dot or dt < cone:
			continue
		var q := PhysicsRayQueryParameters3D.create(muzzle, chest, Layers.WORLD, [get_rid()])
		if space and not space.intersect_ray(q).is_empty():
			continue
		best_dot = dt - cone
		best = dir
	return best


## r31: where a bolt goes. Locked on, straight at the target's chest (in sight); otherwise the
## crosshair, nudged by the assist.
func _combat_aim(muzzle: Vector3) -> Vector3:
	var lk := targeting.lock_target()
	if lk and lk.is_alive():
		var chest := lk.global_position + Vector3.UP * (lk.hp_bar_y * 0.55)
		var to := chest - muzzle
		if to.length() > 0.2 and to.length() < LOCK_AIM_RANGE and locomotion._ray(muzzle, chest).is_empty():
			return to.normalized()
	return _assist(muzzle, _aim_from(muzzle))


func _aim_from(muzzle: Vector3) -> Vector3:
	var look := targeting._look_target()
	var cam_fwd := -_cam.global_transform.basis.z.normalized()
	var aim := look - muzzle
	if aim.length_squared() < 0.04 or aim.normalized().dot(cam_fwd) < 0.12:
		return cam_fwd
	return aim.normalized()


# --- Skills surface -------------------------------------------------------------------------

func skills() -> SkillBook:
	return _book


## r33 combat: CombatState (statuses, crits, Resonance, Rift Surge, the remembered target). See the
## HUD contract at the top of core/skills/combat_state.gd.
func combat() -> Node:
	return _book.combat if _book != null else null


## r33: how hard the wanderer is being steered this tick (0..1): a rooted cast cancels on it.
func move_intent() -> float:
	return _wish_len


func skills_locked() -> bool:
	return _hollowing or autopilot or _step_t > 0.0 or _mantle_t >= 0.0 or traversal._trav_busy() \
			or (_arts != null and (_arts.busy() or _arts.guarding())) or (_grapple != null and _grapple.pulling())


## r31: what stops the staff arts and the Tether line (spells being busy does not).
func skills_locked_for_arts() -> bool:
	return _hollowing or autopilot or _step_t > 0.0 or _mantle_t >= 0.0 or traversal._trav_busy() or (_grapple != null and _grapple.pulling())


func note_combat() -> void:
	_combat_t = COMBAT_FACE_TIME


## Called by the SkillBook on its physics tick. The ember orb, its light, the particles and the
## Lance's landing ring are PLACED every rendered frame (_frame_fx) at the staff head as it is drawn:
## placed here they stepped at 60 Hz against the interpolated staff (r29).
func set_charge_glow(c: float) -> void:
	if _visual:
		_visual.charge = c
	_charge_c = c
	if c <= 0.0 and _aim_ring:
		_aim_ring.visible = false
	if _charge_fx == null:
		return
	var on := c > 0.0
	if on != _charge_fx.emitting:
		if on:
			_charge_fx.global_position = _muzzle_drawn()
		_charge_fx.emitting = on
		if on:
			_charge_sfx.play()
		else:
			_charge_sfx.stop()
			_charge_was_full = false
	if not on:
		_charge_vis(0.0)
	if on:
		_charge_fx.amount_ratio = 0.35 + 0.65 * c
		_charge_sfx.pitch_scale = 0.8 + 0.5 * c
		if c >= 1.0 and not _charge_was_full:
			_charge_was_full = true      # full charge: a ring snap tells you it will pierce
			Vfx.ring(_visual.muzzle(), 0.7, Color(2.6, 1.8, 1.0), 0.25, 0.14, -_cam.global_basis.z)
			Vfx.burst(_visual.muzzle(), Color(2.8, 1.6, 0.8), {"count": 18, "life": 0.3, "speed": Vector2(2.0, 4.0), "size": 0.04, "trail": 0.06, "gravity": 0.0})


## Rendered frame: everything that rides the staff head while charging.
func _frame_fx() -> void:
	if _charge_c <= 0.0 or _visual == null:
		return
	var at := _muzzle_drawn()
	if _charge_fx:
		_charge_fx.global_position = at
	_charge_vis(_charge_c, at)
	_update_aim_ring(_charge_c, at)


## Where the staff orb is DRAWN this frame (the rig's bones are blended between ticks).
func _muzzle_drawn() -> Vector3:
	if _visual.has_method("muzzle_drawn"):
		return _visual.muzzle_drawn()
	return _visual.muzzle()


## The ember orb at the staff head: swells with the charge, flickers, and burns white at full.
func _charge_vis(c: float, at := Vector3.INF) -> void:
	if _charge_orb == null:
		return
	var on := c > 0.0
	_charge_orb.visible = on
	_charge_halo.visible = on
	_charge_light.visible = on
	if not on:
		return
	if at == Vector3.INF:
		at = _muzzle_drawn()
	var t := Time.get_ticks_msec() * 0.001
	var flick := 1.0 + 0.08 * sin(t * 37.0) + 0.05 * sin(t * 23.0 + 1.3)
	var full := c >= 1.0
	var r := lerpf(0.05, 0.2, smoothstep(0.0, 1.0, c)) * flick * (1.15 if full else 1.0)
	_charge_orb.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r * 2.0), at)
	_charge_halo.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r * 4.2), at)
	(_charge_orb.material_override as StandardMaterial3D).albedo_color = Color(3.2, 1.3, 0.45).lerp(Color(4.2, 3.4, 2.4), 0.6 if full else 0.0)
	(_charge_halo.material_override as StandardMaterial3D).albedo_color.a = 0.22 + 0.25 * c
	_charge_light.global_position = at
	_charge_light.light_energy = (0.6 + 2.2 * c) * flick
	_charge_light.omni_range = 2.5 + 2.5 * c


## Lance aim: a round marker where the throw will land, sized to the blast it will have now.
func _update_aim_ring(c: float, muzzle: Vector3) -> void:
	if _aim_ring == null:
		return
	if c <= 0.0:
		_aim_ring.visible = false
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var aim := _aim_from(muzzle)
	var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + aim * 60.0, Layers.WORLD | Layers.PROPS, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_aim_ring.visible = false
		return
	_aim_ring.visible = true
	# the circle is the blast the charging skill will really have (Wide Ember, the Cinder Censer...)
	var blast := lerpf(SkillLance.BLAST_MIN, SkillLance.BLAST_MAX, c)
	var si := _book.charging_slot() if _book else -1
	if si >= 0 and si < _book.slots.size() and _book.slots[si] != null and _book.slots[si].has_method("blast_at"):
		blast = float(_book.slots[si].call("blast_at", c))
	SpellFx.place_ring(_aim_ring, hit.position, hit.normal, blast, c)


# --- r31 combat and traversal surface (Breath, staff arts, Tether line, cloak-glide) ------------

func stamina() -> Node:
	return _stam


func arts() -> Node:
	return _arts


func grapple() -> Node:
	return _grapple


## SkillBook asks: is the primary trigger the staff's this tick (a foe in your face)?
func melee_claims_primary() -> bool:
	return _arts != null and _arts.claims_primary()


## Hitstop: the whole world held at `scale` for `sec` real seconds (a strike landing, a parry).
## Stacks with other slow-motion through TimeSlow: the slowest live request wins.
func hitstop(sec: float, scale := 0.05) -> void:
	TimeSlow.request(get_tree(), scale, sec)


func _visual_pose(kind: StringName) -> void:
	if _visual and _visual.has_method("cast_pose"):
		_visual.cast_pose(kind)


## Square the body to `dir` at once (a strike's first frame) and hold it while the strike plays.
func _face_now(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	_face_yaw = atan2(-dir.x, -dir.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _face_yaw, 0.6)


func nova_fx(radius: float, detonated: Array) -> void:
	_visual.cast("")
	StaffSfx.play("nova", global_position, 0.0)
	var at := global_position + Vector3.UP * 0.9
	SpellFx.nova(global_position, radius)     # round disc drawn at exactly the damage radius
	for e in detonated:
		var en := e as Node3D
		if en == null or not is_instance_valid(en):
			continue
		var hit := en.global_position + Vector3.UP * 1.0
		Vfx.arc(at, hit, Color(1.8, 1.0, 3.2), 0.28, 0.35)
		Vfx.burst(hit, Color(2.0, 1.1, 3.4), {"count": 26, "life": 0.4, "speed": Vector2(2.5, 6.0), "size": 0.05, "trail": 0.08, "gravity": -4.0})


# --- traversal (r28): ledge hang + climb, vault, wall kick, steep slopes, beams, dodge roll ---------
# Each is a short state the main tick hands over to (hang, climb and vault place the body
# directly; the roll and the steep slide still go through move_and_slide). The rig gets a pose
# for each (CharacterRig.play_move / hang / steep / beam).

const GRAB_MIN := 1.1             ## ledge top above the feet: lower than this is a mantle
const GRAB_MAX := 2.25            ## the hands reach this high, arms up, from a jump
const HANG_DROP := 2.0            ## feet below the ledge top while hanging
const WALL_GAP := 0.38            ## capsule centre off the wall face while hanging (radius 0.35)
const CLIMB_TIME := 0.62
const SHIMMY := 1.3               ## m/s along a ledge
const VAULT_MIN := 0.5            ## (below this the step-up walks over it)
const VAULT_MAX := 1.25
const VAULT_DEPTH := 1.1          ## thicker than this is a ledge to climb onto, not a wall to vault
const VAULT_SPEED := 3.8          ## at least a run
const KICK_UP := 6.4
const KICK_OUT := 5.0
const ROLL_TIME := 0.55
const ROLL_DIST := 4.4
const ROLL_EVADE := Vector2(0.04, 0.3)   ## untouchable window inside the roll (s)
const HOP_TIME := 0.36
const ROLL_CD := 0.3
const ROLL_LAND_V := 11.0         ## a landing this hard turns into a roll if you are moving
const STEEP_MAX_V := 10.0
const BEAM_W := 0.32              ## both sides this far out are open air: a beam
const LOCK_RANGE := 26.0
var _hang := false
var _regrab := 0.0
var _climb_t := -1.0
var _vault_t := -1.0
var _roll_t := -1.0
var _roll_len := ROLL_TIME
var _roll_dir := Vector3.FORWARD
var _roll_cd := 0.0
var _roll_evade := true
var _evade_roll := false
var _wall_t := 0.0
var _wall_n := Vector3.ZERO
var _kick_n := Vector3.ZERO
var _kick_lock := 0.0
var _steep_t := 0.0
var _steep_n := Vector3.UP
var _steep_k := 0.0
var _beam_k := 0.0
var _beam_on := false
var _beam_mid := 0.0
var _beam_side := Vector3.RIGHT
var _lock: Enemy = null
var _lock_flick := 0.0
var _lock_flick_t := 0.0
var _recentre := false
var _air_base := 0.0
var _cam_air := 0.0
var _cam_air_prev := 0.0
var _look_ahead := Vector3.ZERO
var _look_ahead_prev := Vector3.ZERO
var _crawl := false               ## the roll's low capsule held under something (no room to stand)
var _sprint_latch := false
var _look_hold := 0.0
var _first_frame := true
const THIN_RAYS := 5                          ## rays across the boom's width for the thin-occluder test
const THIN_HALF_W := 0.45                     ## m either side of the boom they span
const SHOULDER := 0.95                        ## the camera boom's offset over the right shoulder (m)
const SHOULDER_NEAR := 1.8                    ## a shoulder camera closer than this swings in behind the wanderer
const SIGHT_HIDDEN := 4                       ## of the six sight rays (chest and head x three) blocked = hidden
var _shoulder_k := 1.0                        ## 1 = boom over the shoulder, 0 = swung in behind the wanderer
const CRAWL_SPEED := 1.6
const FALL_RESCUE_T := 6.0        ## falling this long (through the world, off the map): back to safe ground
var _fall_t := 0.0
var _stuck_t := 0.0


# --- component forwarding (public surface kept on Player) -----------------------------------

func _ap() -> PlayerAutopilot:
	if autopilot_ctl == null:
		autopilot_ctl = PlayerAutopilot.new(self)
		add_child(autopilot_ctl)
	return autopilot_ctl

func start_autopilot(markers: Array[Marker3D]) -> void: _ap().start_autopilot(markers)
func _toggle_lock() -> void: targeting._toggle_lock()
func _set_lock(t: Enemy) -> void: targeting._set_lock(t)
func _release_lock() -> void: targeting._release_lock()
## r33 combat, Tab-style: the next foe nearest-first in front of the view (wraps to the nearest); the
## camera locks onto it. Returns the new target or null.
func cycle_target() -> Enemy: return targeting.cycle_target()
## The foe nearest the middle of the view (side 0), or the next one left (-1) / right (+1) of the
## current target, in sight and within LOCK_RANGE.
func _pick_target(side: int) -> Enemy: return targeting._pick_target(side)
## Render frame: the view swings onto the target (framing the wanderer and the foe), the mark sits
## on it; a hard flick of the mouse or stick moves the lock to the next foe that side.
func _lock_view(delta: float, body: Vector3) -> void: targeting._lock_view(delta, body)
func lock_target() -> Enemy: return targeting.lock_target()
## The closest living enemy within 14 m that isn't behind the wanderer (for the head's look-at).
func _nearest_foe() -> Enemy: return targeting._nearest_foe()
## r33: the current (remembered) target, null if none.
func current_target() -> Node3D: return targeting.current_target()
func set_view(yaw: float, pitch: float) -> void: camera_ctl.set_view(yaw, pitch)
func cast_impulse() -> void: camera_ctl.cast_impulse()
## Camera punch, 0..1. Rides the existing land-dip pitch channel.
func kick(amount: float) -> void: camera_ctl.kick(amount)
## Lava: a heavy Gloom burn and a throw back to the last solid ground (see Lava).
func lava_burn(amount: float) -> void: vitals.lava_burn(amount)
## A strike or pounce passed through you during a Rift Step: slow time, stagger and mark the
## attacker, and arm a free Rift Lash on your next bolt.
func on_evaded(attacker: Node) -> void: vitals.on_evaded(attacker)
## r33: a parry, a perfect dodge or a riposte lights Rift Surge (CombatState).
func _surge(reason: StringName) -> void: vitals._surge(reason)
func consume_riposte() -> bool: return vitals.consume_riposte()
func add_gloom(amount: float) -> void: vitals.add_gloom(amount)
## Raw Wounds (positive hurts, negative mends) with no hit reaction. At wounds_max you are hollowed.
## Blows from the world go through take_wound (grace window, guard, the reaction); this is for
## mending and for scripted hurts that do their own show (lava, a long fall, a crypt push-back).
func add_wounds(amount: float) -> void: vitals.add_wounds(amount)
## Kills, spent Resonance, Nova motes and the like: a little of the hurt closes.
func mend(amount: float) -> void: vitals.mend(amount)
func note_shade_unmade() -> void: vitals.note_shade_unmade()
## A bolt or spell passed through the Shade. The first time, say what does work.
func note_shade_passed() -> void: vitals.note_shade_passed()
## r35: a blow from the world (a foe, a boss, their hazards). It wounds; it no longer fills the Gloom.
## Two strikes inside HURT_GRACE count once; a held guard turns most of a blow from the front.
func take_wound(amount: float, from_pos := Vector3.INF) -> void: vitals.take_wound(amount, from_pos)
func hollow() -> void: await vitals.hollow()
## Hollowing costs the ash carried since the last fire: it is left in a mound where you fell.
## Walk back to it to take it up; be hollowed again first and it is gone.
func _drop_ash() -> void: vitals._drop_ash()
## On the ground this frame, including being held down a stair edge (_step_down).
func is_grounded() -> bool: return locomotion.is_grounded()
func is_sliding() -> bool: return locomotion.is_sliding()
## Teleport helper: same as setting global_position, plus no interpolation streak.
func teleport(pos: Vector3, keep_velocity := false) -> void: locomotion.teleport(pos, keep_velocity)
## The capsule would stand at `pos` without touching anything.
func _fits(pos: Vector3) -> bool: return locomotion._fits(pos)
func _ray(a: Vector3, b: Vector3, mask := Layers.WORLD) -> Dictionary: return locomotion._ray(a, b, mask)
## A tall wall touched (or right beside you) in the air, and not the one you just kicked off.
func _can_wallkick(wish: Vector3) -> bool: return traversal._can_wallkick(wish)
func is_hanging() -> bool: return traversal.is_hanging()
## A tucked roll along the stick (or a backstep with no stick): brief i-frames, keeps the run, no
## cooldown beyond its own length. Distinct from the Rift Step: no riposte, no marks, stays visible.
func _try_dodge(wish: Vector3) -> bool: return evasion._try_dodge(wish)
func is_rolling() -> bool: return evasion.is_rolling()
func _can_glide() -> bool: return evasion._can_glide()
func _start_glide() -> void: evasion._start_glide()
## Rising air under a glide: any node in the "updraft" group (meta "radius" 3 m, "height" 16 m,
## "lift" 6 m/s), and every lit fire (a brazier's breath: 2.4 m round, 12 m high).
func _updraft(at: Vector3) -> float: return evasion._updraft(at)
func is_gliding() -> bool: return evasion.is_gliding()
func _grapple_begin() -> void: evasion._grapple_begin()
func _grapple_end() -> void: evasion._grapple_end()
func is_evading() -> bool: return evasion.is_evading()
func can_shadowstep() -> bool: return evasion.can_shadowstep()
## Rift Step: tear out here, tear in up to `step_range` metres along the move direction (camera
## forward with no input). A capsule sweep stops it short of walls; the far end settles onto
## whatever ground is within 3 m below, so stairs and slopes land cleanly and a gap is crossed
## in the air. Vertical speed is cancelled, so a mid-air step is also a brief hang.
func shadowstep() -> bool: return evasion.shadowstep()
