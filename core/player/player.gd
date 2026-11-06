class_name Player
extends CharacterBody3D
## Third-person wanderer: movement, orbit camera, lantern, Gloom, interaction, autopilot (demo/tests).

## Components (core/player/player_*.gd): the state stays on Player, the logic lives here.
var autopilot_ctl: PlayerAutopilot = null

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
var _gloom_zone_t := 0.0
var _in_rift := false
var _in_fight := false
var _ash_banked := -1                   ## grave ash held at the last fire; above it is "carried"
var _ash_mound: Node3D
var autopilot := false
var hollow_count := 0
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
var _fov_want := 0.0                    ## speed FOV kick target (physics tick); eased per rendered frame
var _fov_burst := 0.0                   ## a sudden widening (Rift Step, slide entry), eased per frame
var _fov_burst_want := 0.0
var _land_dip_want := 0.0
var _shake_want := 0.0
var _roll_want := 0.0
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
var _glide_dir := Vector3.FORWARD
var _glide_speed := 0.0
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
var _cam_len := ARM_LEN
var _run_blend := 0.0                   ## 0 walk .. 1 full sprint (camera, turn rate)
var _mantle_t := -1.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _cam_roll := 0.0
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
	Events.enemy_killed.connect(_on_enemy_killed)
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
	_setup_movement_fx()
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
		_toggle_lock()
	elif event.is_action_pressed("target_next"):
		cycle_target()


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
		_lock_view(delta, body_xf.origin)
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
	_cam_frame(delta)
	_pitch_node.rotation.x = _pitch - _land_dip * 0.12 + _shake
	_update_arm(delta)
	_frame_fx()


func _physics_process(delta: float) -> void:
	_t += delta
	if _last_pos != Vector3.INF and global_position.distance_squared_to(_last_pos) > 4.0:
		_on_teleported()                        # tests, respawns, travel: plain global_position works
	_cam_off_prev = _cam_off
	_spring3(true, 11.0, delta)                 # critically damped: no velocity kick on a step
	_shade_lock = maxf(0.0, _shade_lock - delta)
	_evade_t = maxf(0.0, _evade_t - delta)
	_combat_t = maxf(0.0, _combat_t - delta)
	if _mantle_t >= 0.0:
		_tick_mantle(delta)
		return
	if _step_t > 0.0:
		_tick_step(delta)
		return
	if _grapple != null and _grapple.pulling():
		_grapple.tick(delta)
		_grounded = false
		_animate(delta, Vector3(velocity.x, 0.0, velocity.z))
		_update_gloom(delta)
		return
	if _gliding and (_hang or _climb_t >= 0.0 or _vault_t >= 0.0):
		_end_glide()

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
				_update_gloom(delta)
				return
	if _visual.ride > 0.0:
		_visual.ride = move_toward(_visual.ride, 0.0, delta * 4.0)

	if sprint and _stam != null:
		# r31 Breath: winded, no sprint; hunted (a foe awake near), the sprint spends it
		if _stam.winded or (_arts != null and (_arts.guarding() or _arts.busy())):
			sprint = false
		elif _stam.in_fight() and _grounded and wish.length_squared() > 0.04 and not autopilot:
			_stam.drain(Stamina.SPRINT_COST * delta)
	_lock_tick(delta)
	if _climb_t >= 0.0:
		_tick_climb(delta)
		return
	if _hang:
		_tick_hang(delta, wish)
		return
	if _vault_t >= 0.0:
		_tick_vault(delta)
		return
	if not autopilot and not _hollowing and Input.is_action_just_pressed("dodge") and _try_dodge(wish):
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
		horiz = _tick_roll(delta, wish)
		velocity.x = horiz.x
		velocity.z = horiz.z
	elif _arts != null and _arts.phase() >= 0 and _grounded:
		horiz = _arts.drive(wish)                 # r31: a staff strike steps in to its target
		velocity.x = horiz.x
		velocity.z = horiz.z
	elif _gliding:
		horiz = _tick_glide(delta, wish)
		velocity.x = horiz.x
		velocity.z = horiz.z
	elif _sliding:
		horiz = _tick_slide(delta, wish)
	elif not _grounded and _steep_t > 0.0 and velocity.y <= 0.5:
		horiz = _tick_steep(delta, wish, Vector3(velocity.x, 0.0, velocity.z))
		velocity.x = horiz.x
		velocity.z = horiz.z
	else:
		var target := wish * (sprint_speed if sprint else walk_speed) * _book.move_scale() * (float(_arts.move_scale()) if _arts != null else 1.0)
		var cur := Vector3(velocity.x, 0.0, velocity.z)
		if _grounded:
			target *= _slope_scale(target) * (1.0 - _land_slow)
			if _beam_k > 0.3:
				# balancing: careful steps along it, the stick's sideways push mostly ignored
				target -= _beam_side * target.dot(_beam_side) * 0.85 * _beam_k
				target = target.limit_length(walk_speed * 0.72)
			horiz = _ground_move(cur, target, delta)
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
			_slide_input(horiz, wish)
			if _try_vault(horiz, wish):
				return
	_run_blend = lerpf(_run_blend, clampf((horiz.length() - walk_speed) / maxf(sprint_speed - walk_speed, 0.1), 0.0, 1.0) if _grounded else _run_blend, 1.0 - exp(-5.0 * delta))

	# Coyote time and jump buffering: without them, a jump pressed one frame early or one frame
	# late is silently dropped, which is most of what made the movement feel unresponsive.
	_coyote = coyote_time if _grounded else maxf(0.0, _coyote - delta)
	_buffered_jump = maxf(0.0, _buffered_jump - delta)
	if not autopilot and not _hollowing:
		if Input.is_action_just_pressed("jump"):
			if _can_wallkick(wish):
				_wall_kick(wish)
			elif _steep_t > 0.0 and not _grounded and _coyote <= 0.0:
				var off := Vector3(_steep_n.x, 0.0, _steep_n.z).normalized()   # leap off the slope
				velocity = Vector3(velocity.x, 0.0, velocity.z) * 0.6 + off * 3.0 + Vector3.UP * jump_velocity
				_steep_t = 0.0
				_jump_rising = true
				_visual.jump_start()
			elif _gliding:
				_end_glide()                     # r31: fold the robe, drop
			elif _coyote <= 0.0 and not _grounded and _air_jumps_left > 0 and (_stam == null or _stam.spend(Stamina.AIR_JUMP)):
				_air_jump(wish, sprint)
			elif _coyote <= 0.0 and not _grounded and _can_glide():
				_start_glide()                   # r31: out of jumps in the air: spread the robe
			else:
				_buffered_jump = jump_buffer
		# variable height: let go while rising and the arc flattens
		if _jump_rising and not Input.is_action_pressed("jump") and velocity.y > 0.0:
			velocity.y *= jump_cut
			_jump_rising = false
	if _buffered_jump > 0.0 and _coyote > 0.0:
		if _sliding:
			_end_slide()                 # slide-hop: the slide's speed carries into the jump, plus a little
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
		var lift := _updraft(global_position)
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
			if _try_step_up(pre_h, delta):
				velocity.x = pre_h.x             # a riser doesn't eat the stride
				velocity.z = pre_h.z
		elif wish.length_squared() > 0.1 and _try_mantle(wish):
			return
		elif not _grounded and _try_grab(wish):
			return
	if not _grounded and was_grounded and velocity.y <= 0.0 and not _jump_rising and global_position.y <= y0 + 0.002:
		_step_down()
	_note_contacts(delta)
	_land(was_grounded, vy_before)
	_beam_probe(horiz)
	_beam_k = move_toward(_beam_k, 1.0 if _beam_on else 0.0, delta * (8.0 if _beam_on else 3.0))
	var steep_on := not _grounded and _steep_t > 0.0 and velocity.y <= 0.5
	_steep_k = move_toward(_steep_k, 1.0 if steep_on else 0.0, delta * (6.0 if steep_on else 4.0))
	if not steep_on and _steep_k <= 0.0 and not _sliding and _slide_fx.emitting:
		_slide_fx.emitting = false
		_slide_sfx.stop()
	_visual.steep = _steep_k
	_visual.beam = _beam_k
	_cam_feel_tick(delta)
	_spring3(false, 22.0, delta)
	_visual.position = global_basis.inverse() * _vis_off
	if not _grounded:
		_air_vy = velocity.y
		_ground_t = 0.0
	elif get_floor_normal().y > 0.85 and not _sliding:
		_ground_t += delta
		if _ground_t > 0.25:
			_safe_ground = global_position
	_burn_cd = maxf(0.0, _burn_cd - delta)

	_update_camera(delta, horiz, sprint, vy_before)
	_sprint_held = sprint
	_animate(delta, horiz)
	_update_gloom(delta)
	_scan_interactables()
	_fall_t = _fall_t + delta if not _grounded and velocity.y < -1.0 and _steep_t <= 0.0 and not _gliding else 0.0
	if _gliding and (_grounded or is_on_ceiling()):
		_end_glide()
	_glide_k = move_toward(_glide_k, 1.0 if _gliding else 0.0, delta * (5.0 if _gliding else 7.0))
	_visual.set("glide", _glide_k)
	if global_position.y < -40.0 or _fall_t > FALL_RESCUE_T:
		_fell_out()      # fell into the chasm, or through the world
	_stuck_tick(delta, wish)


## Lava: a heavy Gloom burn and a throw back to the last solid ground (see Lava).
func lava_burn(amount: float) -> void:
	if _burn_cd > 0.0 or _hollowing:
		return
	_burn_cd = 1.0
	var from := global_position
	add_wounds(amount)                        # r35: lava wounds (it filled the Gloom before the split)
	Events.player_hurt.emit(amount, from)
	_end_traverse()
	Vfx.burst(from + Vector3.UP * 0.6, SpellFx.EMBER_HOT, {"count": 50, "life": 0.7, "speed": Vector2(3.0, 8.0), "size": 0.05, "gravity": -8.0, "trail": 0.08, "dir": Vector3.UP, "spread": 50.0})
	_end_slide()
	var to := _safe_ground if _safe_ground != Vector3.INF else checkpoint
	teleport(to + Vector3.UP * 0.1)
	SpellFx.rift_in(to)
	kick(0.8)
	Events.toast.emit("The molten dark spits you back out.")


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


## A strike or pounce passed through you during a Rift Step: slow time, stagger and mark the
## attacker, and arm a free Rift Lash on your next bolt.
func on_evaded(attacker: Node) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var at := global_position + Vector3.UP * 2.0
	if _arts != null and _arts.parrying() and _evade_t <= 0.0:
		_arts.parry(attacker)                   # r31: the staff turned it aside
		_surge(&"parry")
		return
	if _evade_roll and _dodge_roll and _roll_t >= 0.0 and _roll_t <= PERFECT_T and now >= _riposte_cd:
		_perfect_dodge(attacker)                # r31: rolled the instant it landed
		_surge(&"dodge")
		return
	if _evade_roll:
		HitText.pop(at, "evaded", Color(0.6, 0.75, 1.0))    # a plain roll: through it, no riposte
		return
	if now < _riposte_cd:
		HitText.pop(at, "evaded", Color(0.6, 0.75, 1.0))
		return
	_riposte_cd = now + 1.5
	_riposte_ready = true
	_surge(&"riposte")
	HitText.pop(at, "RIPOSTE", Color(1.3, 0.75, 2.6), true)
	Hints.once(&"riposte", "RIPOSTE: stepping through a blow makes your next bolt a Rift Lash.")
	if attacker.has_method("add_mark"):
		attacker.add_mark(2)
	if attacker.has_method("riposted"):
		attacker.riposted()
	Sfx.play("res://art/audio/mark_tick.wav", at, 0.0, 0.7, 0.02)
	SpellFx.shell(global_position + Vector3.UP, 0.3, 2.2, Color(1.2, 0.5, 2.8), 0.3)
	kick(0.5)
	TimeSlow.request(get_tree(), 0.35, 0.22)


## r33: a parry, a perfect dodge or a riposte lights Rift Surge (CombatState).
func _surge(reason: StringName) -> void:
	var cs := combat()
	if cs != null:
		cs.call("proc_surge", reason)


func consume_riposte() -> bool:
	var r := _riposte_ready
	_riposte_ready = false
	return r


func _on_enemy_killed(e: Node) -> void:
	if _hollowing or not (e is Node3D) or not is_inside_tree():
		return
	var at := (e as Node3D).global_position + Vector3.UP * 1.0
	if at.distance_to(global_position) > 28.0:
		return
	var now := Time.get_ticks_msec() * 0.001
	_chain = _chain + 1 if now < _chain_until else 1
	_chain_until = now + CHAIN_WINDOW
	mend(minf(KILL_RELIEF + 2.0 * float(_chain - 1), 14.0))   # r35: a kill mends Wounds
	if _chain >= 2:
		HitText.pop(global_position + Vector3.UP * 2.3, "chain x%d" % _chain, Color(1.2, 0.6, 2.6), _chain >= 4)
	Vfx.arc(at, global_position + Vector3.UP * 1.2, Color(1.2, 0.55, 2.8), 0.35, 0.18)
	Vfx.burst(global_position + Vector3.UP * 1.1, Color(1.3, 0.6, 3.0), {"count": 12, "life": 0.4, "speed": Vector2(0.5, 1.5), "size": 0.04, "gravity": -1.0, "radius": 0.3})


func set_view(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


func debug_drive(wish: Vector3, sprint := false) -> void:
	_debug_drive = wish.length_squared() > 0.0001
	_debug_wish = wish
	_debug_sprint = sprint


func cast_impulse() -> void:
	_shake_want = maxf(_shake_want, deg_to_rad(0.15))


# --- Camera ------------------------------------------------------------------

## The spring arm used to sit perfectly still whatever the player did. Two cheap reactions:
## the view opens up at a sprint, and the camera dips on a hard landing. Base FOV stays
## Settings.fov, so the settings menu remains the one source of truth and the kick rides on top.

## Physics tick: only the TARGETS (speed kick, strafe roll) and the landing event are decided here;
## _cam_frame eases FOV, roll and the landing dip every rendered frame (r29: set on the tick, they
## stepped at 60 Hz on a 120-144 Hz screen -- a sprint's FOV kick visibly ratcheted).
func _update_camera(_delta: float, horiz: Vector3, _sprint: bool, vy_before: float) -> void:
	# FOV follows real speed (walk 0 -> sprint full kick -> slides and hops a bit beyond)
	var spd := horiz.length()
	_fov_want = clampf((spd - walk_speed) / maxf(sprint_speed - walk_speed, 0.1), 0.0, 1.6) * SPRINT_FOV_KICK
	# a slight roll into strafes (max ~1.4 degrees)
	var right := Basis(Vector3.UP, _yaw) * Vector3.RIGHT
	var lateral := Vector3(velocity.x, 0.0, velocity.z).dot(right)
	_roll_want = clampf(-lateral / sprint_speed, -1.0, 1.0) * deg_to_rad(1.4)
	if _grounded and not _was_floor:
		var dip := clampf(-vy_before / 9.0, 0.0, 1.0)
		_land_dip_want = maxf(_land_dip_want, dip)
		if dip > 0.25:                           # a real drop: the staff's ferrule strikes the ground too
			StaffSfx.play("tap", global_position, lerpf(-12.0, -4.0, dip), 0.92)
	_was_floor = _grounded


## Rendered frame: FOV kick, strafe roll and the landing dip ease toward their targets here.
func _cam_frame(delta: float) -> void:
	# punches (kick, landing dip, the Rift Step's widening) arrive over ~3 frames instead of in one:
	# set on a physics tick, a one-frame snap of up to 7 degrees read as a hitch at 144 Hz
	var snap := 1.0 - exp(-38.0 * delta)
	_fov_kick = lerpf(_fov_kick, _fov_want, 1.0 - exp(-6.0 * delta))
	_fov_burst = lerpf(_fov_burst, _fov_burst_want, snap)
	_fov_burst_want *= exp(-4.0 * delta)
	var fov := Settings.fov + maxf(_fov_kick, _fov_burst)
	if absf(_cam.fov - fov) > 0.0001:
		_cam.fov = fov
	_cam_roll = lerpf(_cam_roll, _roll_want, 1.0 - exp(-5.0 * delta))
	_cam.rotation.z = _cam_roll
	_land_dip = lerpf(_land_dip, _land_dip_want, snap)
	_land_dip_want = move_toward(_land_dip_want, 0.0, delta * 3.0)
	_shake = lerpf(_shake, _shake_want, snap)
	_shake_want = move_toward(_shake_want, 0.0, delta * 0.12)   # ~0.15 s for a full kick


# --- Animation ---------------------------------------------------------------

func _animate(delta: float, horiz: Vector3) -> void:
	# casting / locked on: square up or twist the chest toward the aim; otherwise face the run
	# (quick to turn from a walk, a wider sweep at a sprint; the body leans into it, see the rig)
	if _roll_t < 0.0 and _vault_t < 0.0 and not _hang and _climb_t < 0.0:
		_facing(delta, horiz if _steep_k < 0.5 else Vector3(_steep_n.x, 0.0, _steep_n.z), _sprint_held)
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
		_look_foe = _nearest_foe()
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


## The closest living enemy within 14 m that isn't behind the wanderer (for the head's look-at).
func _nearest_foe() -> Enemy:
	var best: Enemy = null
	var bd := 14.0 * 14.0
	var fwd := -_visual.global_basis.z
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var to := e.global_position - global_position
		var d := to.length_squared()
		if d < bd and Vector2(to.x, to.z).normalized().dot(Vector2(fwd.x, fwd.z).normalized()) > -0.3:
			bd = d
			best = e
	return best


func _on_skill_cast(id: StringName) -> void:
	_visual.cast_pose(id)


# --- Gloom and the shade -----------------------------------------------------

func _update_gloom(delta: float) -> void:
	if _hollowing:
		return
	_gloom_zone_t -= delta
	if _gloom_zone_t <= 0.0:
		_gloom_zone_t = 0.25
		_in_fight = boss_fight_active(get_tree())
		_in_rift = _rift_here()
	# r30: a fire drains at the player's rate; a Lantern Ward at its own (4/s, at most 25 a cast);
	# inside a live boss arena the dark does not gather on its own (the boss is the pressure);
	# the rift rate is the Ashen Rift itself, not everything north of z -40.
	var drain := LightGrid.drain_at(global_position)
	var lit := drain != 0.0
	var rate := gloom_rate_rift if _in_rift else gloom_rate_dark
	if drain < 0.0:
		rate = -gloom_drain_lit
	elif drain > 0.0:
		var want := drain * gloom_drain_lit / 12.0
		rate = -want if ward_drain_left > 0.0 and gloom > 0.0 else 0.0
		ward_drain_left = maxf(0.0, ward_drain_left + rate * delta)
	elif _in_fight:
		rate = 0.0
	elif _sprint_held and _run_blend > 0.6 and _grounded:
		rate *= SPRINT_DARK_MULT
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
		_shade.unmake_by_light()
	# r35: a fire mends Wounds (a Lantern Ward does not: it only holds the dark back)
	if drain < 0.0 and wounds > 0.0:
		var before := wounds
		wounds = maxf(0.0, wounds - wounds_mend_lit * delta)
		_wounds_emit_t += delta
		if wounds <= 0.0 or before - _wounds_emit >= 0.5 or _wounds_emit_t >= 0.1:
			_emit_wounds()


func add_gloom(amount: float) -> void:
	gloom = clampf(gloom + amount, 0.0, gloom_max)
	Events.gloom_changed.emit(gloom, gloom_max)


var _wounds_emit := 0.0
var _wounds_emit_t := 0.0

func _emit_wounds() -> void:
	_wounds_emit = wounds
	_wounds_emit_t = 0.0
	Events.wounds_changed.emit(wounds, wounds_max)


## Raw Wounds (positive hurts, negative mends) with no hit reaction. At wounds_max you are hollowed.
## Blows from the world go through take_wound (grace window, guard, the reaction); this is for
## mending and for scripted hurts that do their own show (lava, a long fall, a crypt push-back).
func add_wounds(amount: float) -> void:
	if _hollowing:
		return
	wounds = clampf(wounds + amount, 0.0, wounds_max)
	_emit_wounds()
	if wounds >= wounds_max - 0.01:
		hollow()


## Kills, spent Resonance, Nova motes and the like: a little of the hurt closes.
func mend(amount: float) -> void:
	if amount > 0.0 and wounds > 0.0:
		add_wounds(-amount)


## True while any BossArena (or arena-like node in the "boss_arena" group) has a live fight.
static func boss_fight_active(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for a in tree.get_nodes_in_group(&"boss_arena"):
		if bool(a.get("_active")):
			return true
	return false


## The Ashen Rift proper: the chasm region and its crossing, not the Ossuary under the fen or the
## summit platform (both used to take the rift rate because they lie north of z -40).
func _rift_here() -> bool:
	if not rift_enabled or global_position.z >= rift_z + 28.0:
		return false
	var p := global_position
	if RealmLayout.OSSUARY.has_point(p):
		return false
	if Vector2(p.x - RealmLayout.SUMMIT.x, p.z - RealmLayout.SUMMIT.z).length() < 26.0:
		return false
	return String(RealmLayout.region_at(p.x, p.z).get("id", "")) == "rift"


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


func note_shade_unmade() -> void:
	_shade_lock = 2.0


## A bolt or spell passed through the Shade. The first time, say what does work.
func note_shade_passed() -> void:
	Hints.once(&"shade_drive", "Bolts pass through the Shade. Run for a fire or a lantern: only light unmakes it.")


## r35: a blow from the world (a foe, a boss, their hazards). It wounds; it no longer fills the Gloom.
## Two strikes inside HURT_GRACE count once; a held guard turns most of a blow from the front.
func take_wound(amount: float, from_pos := Vector3.INF) -> void:
	if _hollowing:
		return
	if Time.get_ticks_msec() * 0.001 < _hurt_grace_until:
		return                                   # two strikes landing together count once
	_hurt_grace_until = Time.get_ticks_msec() * 0.001 + HURT_GRACE
	if _arts != null:
		amount = _arts.absorb(amount, from_pos)   # r31: a held guard turns most of a blow from the front
	if _book != null:
		_book.on_hurt(amount)                    # r33: a hard blow interrupts a cast, a light one pushes it back
	kick(clampf(amount / 30.0, 0.3, 1.0))
	Sfx.play(SFX_HURT, global_position + Vector3.UP, -3.0)
	Events.player_hurt.emit(amount, from_pos)
	_visual.hurt_react(from_pos, amount)
	if not has_meta("heard_strike"):
		set_meta("heard_strike", true)
		Events.toast.emit("They wound. A fire closes what they open.")
	add_wounds(amount)                           # last: at wounds_max this hollows


func _on_shade_leaving() -> void:
	_shade = null


func hollow() -> void:
	if _hollowing:
		return
	_hollowing = true
	hollow_count += 1
	_drop_ash()
	Travel.saved_hollows = hollow_count
	Travel.save_soon()
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
	teleport(checkpoint)                      # no interpolation streak across the map, no stale state
	_release_lock()
	if _stam != null:
		_stam.refill()
	if _arts != null:
		_arts.cancel()
	gloom = 0.0
	wounds = 0.0
	Events.gloom_changed.emit(gloom, gloom_max)
	_emit_wounds()
	if is_instance_valid(_shade):
		_shade.queue_free()
	Events.respawned.emit(checkpoint)


## Hollowing costs the ash carried since the last fire: it is left in a mound where you fell.
## Walk back to it to take it up; be hollowed again first and it is gone.
func _drop_ash() -> void:
	if is_instance_valid(_ash_mound):
		_ash_mound.queue_free()               # the old mound is lost
	_ash_mound = null
	var have := Travel.count("grave_ash")
	if _ash_banked < 0 or _ash_banked > have:
		_ash_banked = have
	var carried := have - _ash_banked
	if carried <= 0:
		return
	var host := get_tree().current_scene if is_inside_tree() else null
	if host == null:
		return
	Travel.items["grave_ash"] = _ash_banked
	Travel.save_soon()
	var at := global_position if _grounded or _safe_ground == Vector3.INF else _safe_ground
	var m := Node3D.new()
	m.set_script(ASH_MOUND)
	m.set("amount", carried)
	host.add_child(m)
	m.global_position = at
	_ash_mound = m
	Hints.once(&"ash_mound", "Your carried ash lies where you fell. Walk back to it.")


## Off the bottom of the world or falling for ages: not a death. Back to the last solid ground
## stood on (else the checkpoint) with a little Gloom for it; r29: it used to respawn at the
## brazier with the Gloom wiped, a free cleanse for jumping into the chasm.
func _fell_out() -> void:
	_fall_t = 0.0
	var to := _safe_ground if _safe_ground != Vector3.INF else checkpoint
	if to.y < -38.0:
		to = checkpoint
	teleport(to + Vector3.UP * 0.1)
	add_gloom(8.0)
	SpellFx.rift_in(to)
	kick(0.5)
	Events.toast.emit("The dark gives you back. It keeps a little.")


## Stuck inside geometry (pushed in by a moving platform, a bad spawn, a seam): after a second of
## pushing the stick without moving while the capsule overlaps the world, lift the body out, or
## put it back on the last safe ground.
func _stuck_tick(delta: float, wish: Vector3) -> void:
	if _hollowing or autopilot or _trav_busy() or _mantle_t >= 0.0 or wish.length_squared() < 0.25:
		_stuck_t = 0.0
		_stuck_from = global_position
		return
	if _stuck_from == Vector3.INF or global_position.distance_squared_to(_stuck_from) > 0.0225:
		_stuck_from = global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t < 1.0:
		return
	_stuck_t = 0.0
	if _headroom() or (_col and (_col.shape as CapsuleShape3D).height < _col_h):
		return                                  # just a wall in the way, or crouched under something
	for up: float in [0.3, 0.6, 1.0, 1.5]:
		var at := global_position + Vector3.UP * up
		if _headroom(at):
			print("Player: freed from geometry at %s (+%.1f m)" % [global_position, up])
			teleport(at)
			return
	if _safe_ground != Vector3.INF and _headroom(_safe_ground):
		print("Player: stuck at %s, back to safe ground %s" % [global_position, _safe_ground])
		teleport(_safe_ground + Vector3.UP * 0.05)


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
	var lk := lock_target()
	if lk and lk.is_alive():
		var chest := lk.global_position + Vector3.UP * (lk.hp_bar_y * 0.55)
		var to := chest - muzzle
		if to.length() > 0.2 and to.length() < LOCK_AIM_RANGE and _ray(muzzle, chest).is_empty():
			return to.normalized()
	return _assist(muzzle, _aim_from(muzzle))


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


## r33 combat: CombatState (statuses, crits, Resonance, Rift Surge, the remembered target). See the
## HUD contract at the top of core/skills/combat_state.gd.
func combat() -> Node:
	return _book.combat if _book != null else null


## r33: how hard the wanderer is being steered this tick (0..1): a rooted cast cancels on it.
func move_intent() -> float:
	return _wish_len


## r33: the current (remembered) target, null if none.
func current_target() -> Node3D:
	var cs := combat()
	return cs.call("get_target") as Node3D if cs != null else null


func skills_locked() -> bool:
	return _hollowing or autopilot or _step_t > 0.0 or _mantle_t >= 0.0 or _trav_busy() \
			or (_arts != null and (_arts.busy() or _arts.guarding())) or (_grapple != null and _grapple.pulling())


## r31: what stops the staff arts and the Tether line (spells being busy does not).
func skills_locked_for_arts() -> bool:
	return _hollowing or autopilot or _step_t > 0.0 or _mantle_t >= 0.0 or _trav_busy() or (_grapple != null and _grapple.pulling())


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


## Camera punch, 0..1. Rides the existing land-dip pitch channel.
func kick(amount: float) -> void:
	_shake_want = maxf(_shake_want, deg_to_rad(0.15 + 1.1 * clampf(amount, 0.0, 1.0)))


# --- r31 combat and traversal surface (Breath, staff arts, Tether line, cloak-glide) ------------

func stamina() -> Node:
	return _stam


func arts() -> Node:
	return _arts


func grapple() -> Node:
	return _grapple


func is_gliding() -> bool:
	return _gliding


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


## A dodge roll met a blow in its first PERFECT_T seconds: time slows, Breath comes back, the
## attacker is Marked and the next strike or bolt is a riposte.
func _perfect_dodge(attacker: Node) -> void:
	var now := Time.get_ticks_msec() * 0.001
	_riposte_cd = now + 1.5
	_riposte_ready = true
	if _stam != null:
		_stam.refund(Stamina.PERFECT_REFUND)
	var at := global_position + Vector3.UP * 2.0
	HitText.pop(at, "PERFECT DODGE", Color(1.5, 1.2, 0.6), true)
	Hints.once(&"perfect_dodge", "PERFECT DODGE: roll the instant a blow lands. Breath back, and your next strike or bolt is a riposte.")
	if attacker and is_instance_valid(attacker) and attacker.has_method("add_mark"):
		attacker.add_mark(1)
	StaffSfx.play("perfect", at, -4.0)
	SpellFx.shell(global_position + Vector3.UP, 0.3, 2.0, Color(1.6, 1.2, 0.6), 0.3)
	hitstop(0.2, 0.3)


## Gloom from a hard landing: the jolt lets the dark in. Rolled out, half; never to the cap.
func _fall_hurt(impact: float) -> void:
	var rolled := _rolled_landing
	_rolled_landing = false
	falls_hurt = 0.0
	if impact <= FALL_HURT_V or autopilot or _hollowing:
		return
	var g := minf((impact - FALL_HURT_V) * FALL_GLOOM, 30.0) * (0.5 if rolled else 1.0)
	g = minf(g, maxf(0.0, wounds_max - 1.0 - wounds))     # a fall wounds; it never hollows on its own
	if g <= 0.0:
		return
	falls_hurt = g
	add_wounds(g)
	HitText.pop(global_position + Vector3.UP * 2.2, "jarred +%d" % int(round(g)), Color(0.9, 0.6, 0.55))
	Hints.once(&"fall_hurt", "Long drops jar the dark in. Roll as you land (dodge), or open the robe to glide (jump again in the air).")
	_visual.hurt_react(Vector3.INF, g)
	kick(clampf(g / 20.0, 0.3, 1.0))


func _can_glide() -> bool:
	if _grounded or _hang or _sliding or _roll_t >= 0.0 or _hollowing or _gliding:
		return false
	if _stam != null and not _stam.can(Stamina.GLIDE):
		return false
	return _ray(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * GLIDE_MIN_H).is_empty()


func _start_glide() -> void:
	_gliding = true
	glides += 1
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_glide_dir = flat.normalized() if flat.length() > 0.5 else -_visual.global_basis.z
	_glide_dir.y = 0.0
	_glide_dir = _glide_dir.normalized()
	_glide_speed = maxf(flat.length(), 5.5)
	_jump_rising = false
	velocity.y = maxf(velocity.y, -4.0)
	if _arts != null:
		_arts.cancel()
	StaffSfx.play("swish", global_position + Vector3.UP * 1.2, -6.0, 0.6)
	Vfx.burst(global_position + Vector3.UP * 1.0, Color(0.05, 0.03, 0.09, 0.55), {"count": 12, "life": 0.6, "speed": Vector2(0.5, 1.5), "size": 0.3, "gravity": 0.4, "additive": false, "radius": 0.5})
	Hints.once(&"glide", "Gliding on the robe: steer with the stick; jump folds it, slide dives. It spends Breath. Lit fires lift you.")


func _end_glide() -> void:
	_gliding = false


func _tick_glide(delta: float, wish: Vector3) -> Vector3:
	if _stam != null:
		_stam.holding = true
		_stam.drain(Stamina.GLIDE * delta)
		if _stam.winded:
			_end_glide()
			return _glide_dir * _glide_speed * 0.6
	var want := _glide_dir
	if wish.length_squared() > 0.04:
		want = Vector3(wish.x, 0.0, wish.z).normalized()
	var a := atan2(_glide_dir.x, _glide_dir.z)
	var b := atan2(want.x, want.z)
	var turn := clampf(angle_difference(a, b), -GLIDE_TURN * delta, GLIDE_TURN * delta)
	_glide_dir = Vector3(sin(a + turn), 0.0, cos(a + turn))
	var top := GLIDE_SPEED + (1.5 if wish.length_squared() > 0.04 and want.dot(_glide_dir) > 0.7 else 0.0)
	_glide_speed = move_toward(_glide_speed, top, 4.0 * delta)
	return _glide_dir * _glide_speed


## Rising air under a glide: any node in the "updraft" group (meta "radius" 3 m, "height" 16 m,
## "lift" 6 m/s), and every lit fire (a brazier's breath: 2.4 m round, 12 m high).
func _updraft(at: Vector3) -> float:
	var best := 0.0
	for n in get_tree().get_nodes_in_group("updraft"):
		var u := n as Node3D
		if u == null:
			continue
		var r := float(u.get_meta("radius", 3.0))
		var h := float(u.get_meta("height", 16.0))
		var d := Vector2(at.x - u.global_position.x, at.z - u.global_position.z).length()
		if d < r and at.y > u.global_position.y - 1.0 and at.y < u.global_position.y + h:
			best = maxf(best, float(u.get_meta("lift", 6.0)))
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		var fire := n as Node3D
		if fire == null or not bool(fire.get("lit")):
			continue
		var d := Vector2(at.x - fire.global_position.x, at.z - fire.global_position.z).length()
		if d < 2.4 and at.y > fire.global_position.y and at.y < fire.global_position.y + 12.0:
			best = maxf(best, 5.0)
	return best


func _grapple_begin() -> void:
	_end_glide()
	_end_slide()
	if _arts != null:
		_arts.cancel()
	if _roll_t >= 0.0:
		_roll_t = -1.0
		_set_capsule(_col_h)
	_hang = false
	_climb_t = -1.0
	_vault_t = -1.0
	_visual.hang = 0.0
	_grounded = false


func _grapple_end() -> void:
	_air_jumps_left = air_jumps                 # a haul refreshes the air jump: anchor, jump, glide
	_jump_rising = false
	_grounded = false


func is_evading() -> bool:
	return _evade_t > 0.0 or (_arts != null and _arts.parrying())


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
	_evade_roll = false
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
	var keep := maxf(Vector2(velocity.x, velocity.z).length(), sprint_speed * 0.9)   # keep the run going
	velocity = Vector3(dir.x, 0.0, dir.z) * keep
	_step_t = step_reveal
	_evade_t = step_evade
	_visual.visible = false
	_visual.rotation.y = atan2(-dir.x, -dir.z)
	_mark_path(from, to)
	_last_pos = to                            # our own move (the camera swoops via _tp_offset), not a teleport
	Sfx.play(SFX_STEP, from, -6.0)
	Sfx.play(SFX_STEP, to, -2.0)
	_fov_burst_want = maxf(_fov_burst_want, 12.0)
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


func _step_burst() -> void:
	var at := global_position + Vector3.UP * 1.0
	Vfx.burst(at, Color(0.02, 0.01, 0.04, 0.85), {"count": 18, "life": 0.7, "speed": Vector2(0.4, 1.6), "size": 0.45, "gravity": 0.6, "radius": 0.35, "additive": false, "turbulence": true})
	Vfx.burst(at, VIOLET, {"count": 22, "life": 0.45, "speed": Vector2(1.5, 3.5), "size": 0.04, "gravity": 0.0, "radius": 0.3, "trail": 0.07})


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


# --- Movement: double jump, slide ----------------------------------------------------------

func _setup_movement_fx() -> void:
	_slide_fx = Vfx.emitter(Color(0.55, 0.5, 0.7, 0.55), {"count": 40, "life": 0.5, "speed": Vector2(0.5, 2.0), "size": 0.18, "gravity": -1.0, "dir": Vector3.UP, "spread": 60.0, "additive": false, "radius": 0.2})
	add_child(_slide_fx)
	var sparks := Vfx.emitter(Color(1.6, 0.9, 2.4), {"count": 24, "life": 0.25, "speed": Vector2(2.0, 4.0), "size": 0.03, "gravity": -8.0, "dir": Vector3.UP, "spread": 70.0, "trail": 0.05})
	sparks.name = "Sparks"
	_slide_fx.add_child(sparks)
	_slide_sfx = AudioStreamPlayer3D.new()
	_slide_sfx.bus = &"SFX"
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
	# the Lance gathering at the staff head: an ember orb that swells with the charge, with its light
	_charge_orb = MeshInstance3D.new()
	_charge_orb.name = "ChargeOrb"
	var orb := SphereMesh.new()
	orb.radius = 0.5
	orb.height = 1.0
	orb.radial_segments = 16
	orb.rings = 8
	_charge_orb.mesh = orb
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.albedo_color = Color(3.2, 1.3, 0.45)
	_charge_orb.material_override = om
	_charge_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charge_orb.top_level = true
	_charge_orb.visible = false
	add_child(_charge_orb)
	_charge_halo = MeshInstance3D.new()
	_charge_halo.name = "ChargeHalo"
	_charge_halo.mesh = orb
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(1.6, 0.5, 0.15, 0.35)
	hm.cull_mode = BaseMaterial3D.CULL_FRONT
	_charge_halo.material_override = hm
	_charge_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charge_halo.top_level = true
	_charge_halo.visible = false
	add_child(_charge_halo)
	_charge_light = OmniLight3D.new()
	_charge_light.light_color = Color(1.0, 0.5, 0.2)
	_charge_light.shadow_enabled = false
	_charge_light.top_level = true
	_charge_light.visible = false
	_charge_light.set_meta("light_class", "player_orb")
	add_child(_charge_light)
	_charge_sfx = AudioStreamPlayer3D.new()
	_charge_sfx.bus = &"SFX"
	var charge: AudioStream = StaffSfx.stream("lance_charge")   # seamless synthesised loop
	if charge == null:
		charge = Sfx.stream("res://art/audio/lance_charge.wav")
	if charge is AudioStreamWAV and (charge as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
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
	if not _grounded:
		if _gliding:
			_end_glide()                         # r31: dive out of the glide
			velocity.y = minf(velocity.y, -6.0)
		_slide_queued = true
		_visual.hold_tuck(0.6)
		return
	if _slide_queued:
		_slide_queued = false
		_slide_latch = true
		_try_slide(horiz, wish, slide_land_min, slide_land_gain * maxf(0.0, -_air_vy))
	elif Settings.using_pad and is_instance_valid(_lock) and wish.length_squared() < 0.04:
		pass                                     # r31: pad, locked on, stick idle: B is the guard (StaffArts)
	elif Input.is_action_just_pressed("slide") and (is_instance_valid(_lock) and not Input.is_action_pressed("sprint") \
			or horiz.length() < slide_min_speed and wish.length_squared() > 0.04):
		_slide_latch = true                      # slow, or squared up to a foe: the slide key rolls
		_try_dodge(wish)
	elif not _slide_latch and _try_slide(horiz, wish, slide_min_speed, 0.0):
		_slide_latch = true


func _try_slide(horiz: Vector3, wish: Vector3, min_speed: float, bonus: float) -> bool:
	var speed := horiz.length()
	if _slide_cd > 0.0 or not _grounded or speed < min_speed:
		return false
	_sliding = true
	_slide_t = 0.0
	_slide_air = 0.0
	_evade_t = maxf(_evade_t, SLIDE_EVADE)     # r30: the slide's start passes under a strike (no riposte)
	_evade_roll = true
	_slide_dir = (horiz if speed > 0.1 else wish).normalized()
	_slide_speed = maxf(speed * slide_boost, sprint_speed * 1.15) + bonus
	_set_capsule(1.0)
	_slide_fx.emitting = true
	(_slide_fx.get_node("Sparks") as GPUParticles3D).emitting = true
	_slide_sfx.play()
	_fov_burst_want = maxf(_fov_burst_want, 8.0)
	kick(0.3 + minf(bonus * 0.05, 0.3))
	return true


func _tick_slide(delta: float, wish: Vector3) -> Vector3:
	_slide_t += delta
	_slide_blend = move_toward(_slide_blend, 1.0, delta * 8.0)
	var downhill := 0.0
	if _grounded:
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
		if _grounded and not _headroom():
			_end_slide()
			_set_capsule(1.1)                     # slid under something: stay low, crawl out (see _tick_roll)
			_roll_t = ROLL_TIME * 0.98
			_roll_len = ROLL_TIME
			_roll_dir = _slide_dir
			_roll_evade = false
			_crawl = true
			_visual.play_move(&"roll", ROLL_TIME)
		else:
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


## On the ground this frame, including being held down a stair edge (_step_down).
func is_grounded() -> bool:
	return _grounded


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
var _hang_n := Vector3.ZERO       ## out of the wall, flat
var _hang_top := 0.0
var _hang_t := 0.0
var _hang_push := 0.0
var _regrab := 0.0
var _climb_t := -1.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _climb_len := CLIMB_TIME
var _vault_t := -1.0
var _vault_len := 0.42
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO
var _vault_apex := 0.0
var _vault_v := Vector3.ZERO
var _roll_t := -1.0
var _roll_len := ROLL_TIME
var _roll_dir := Vector3.FORWARD
var _roll_speed := 0.0
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
var _beam_frame := 0
var _lock: Enemy = null
var _lock_flick := 0.0
var _lock_flick_t := 0.0
var _lock_lost := 0.0
var _lock_los_t := 0.0
var _lock_mark: MeshInstance3D
var _recentre := false
var _twist := 0.0
var _air_base := 0.0
var _cam_air := 0.0
var _cam_air_prev := 0.0
var _look_ahead := Vector3.ZERO
var _look_ahead_prev := Vector3.ZERO
var _thin_hold := 0.0
var _crawl := false               ## the roll's low capsule held under something (no room to stand)
var _sprint_latch := false
var _look_hold := 0.0
var _first_frame := true
var _fight_k := 0.0
var _arm_q: PhysicsShapeQueryParameters3D
var _thin_q: PhysicsShapeQueryParameters3D
var _thin_ray: PhysicsRayQueryParameters3D   ## reused by _thin_occluder (r35: five rays, no allocation each)
var _tall_q: PhysicsShapeQueryParameters3D
const THIN_RAYS := 5                          ## rays across the boom's width for the thin-occluder test
const THIN_HALF_W := 0.45                     ## m either side of the boom they span
const SHOULDER := 0.95                        ## the camera boom's offset over the right shoulder (m)
const SHOULDER_NEAR := 1.8                    ## a shoulder camera closer than this swings in behind the wanderer
const SIGHT_HIDDEN := 4                       ## of the six sight rays (chest and head x three) blocked = hidden
var _sight_ray: PhysicsRayQueryParameters3D
var _sight_hold := 0.0
var _shoulder_k := 1.0                        ## 1 = boom over the shoulder, 0 = swung in behind the wanderer
const CRAWL_SPEED := 1.6
const FALL_RESCUE_T := 6.0        ## falling this long (through the world, off the map): back to safe ground
var _fall_t := 0.0
var _stuck_t := 0.0
var _stuck_from := Vector3.INF


func is_hanging() -> bool:
	return _hang


func is_rolling() -> bool:
	return _roll_t >= 0.0


func lock_target() -> Enemy:
	return _lock if is_instance_valid(_lock) else null


func _trav_busy() -> bool:
	return _hang or _climb_t >= 0.0 or _vault_t >= 0.0 or _roll_t >= 0.0


## Drop every traversal state (teleports, respawns, lava).
func _end_traverse() -> void:
	_end_glide()
	if _grapple != null:
		_grapple.cancel()
	_hang = false
	_climb_t = -1.0
	_vault_t = -1.0
	_mantle_t = -1.0                          # r29: a lava throw mid-mantle was dragged back by the mantle tick
	_kick_lock = 0.0
	_end_slide()
	if _roll_t >= 0.0:
		_roll_t = -1.0
		_set_capsule(_col_h)
	_crawl = false
	_steep_t = 0.0
	_beam_on = false
	if _step_t > 0.0:                         # moved during a Rift Step's reveal: show the body now
		_step_t = 0.0
		_visual.visible = true
	_visual.hang = 0.0
	if _visual.has_method("cancel_move"):
		_visual.cancel_move()


## The skin's glide after a position snap (hang, step-up), for ticks that skip the main path.
func _ease_tick(delta: float) -> void:
	_spring3(false, 22.0, delta)
	_visual.position = global_basis.inverse() * _vis_off


func _ray(a: Vector3, b: Vector3, mask := Layers.WORLD) -> Dictionary:
	var space := get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, mask, [get_rid()]))


## The capsule would stand at `pos` without touching anything.
func _fits(pos: Vector3) -> bool:
	if _col == null:
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _col.shape
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * _col_y)
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	q.margin = 0.0
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# --- ledge hang and climb ---------------------------------------------------------------------------

## In the air, against a wall whose top is above mantle height but within the hands' reach: catch it.
func _try_grab(wish: Vector3) -> bool:
	if _regrab > 0.0 or velocity.y > 1.5 or _sliding or _hollowing or autopilot or _roll_t >= 0.0:
		return false
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var dir := Vector3.ZERO
	if wish.length_squared() > 0.04:
		dir = Vector3(wish.x, 0.0, wish.z).normalized()
	elif flat.length() > 1.0:
		dir = flat.normalized()
	else:
		return false
	var chest := global_position + Vector3.UP * 1.3
	var hit := _ray(chest, chest + dir * 0.8)
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	var nf := Vector3(n.x, 0.0, n.z)
	if absf(n.y) > 0.35 or nf.length() < 0.3 or nf.normalized().dot(-dir) < 0.5:
		return false
	nf = nf.normalized()
	var face: Vector3 = hit.position
	var over := face - nf * 0.22
	var top_hit := _ray(Vector3(over.x, global_position.y + GRAB_MAX + 0.4, over.z), Vector3(over.x, global_position.y + GRAB_MIN - 0.05, over.z))
	if top_hit.is_empty() or (top_hit.normal as Vector3).y < 0.75:
		return false
	var top: float = (top_hit.position as Vector3).y
	var rise := top - global_position.y
	if rise < GRAB_MIN or rise > GRAB_MAX:
		return false
	# the face must run right up to the lip (not a sloped bank or a step back)
	var lip := _ray(Vector3(face.x, top - 0.12, face.z) + nf * 0.3, Vector3(face.x, top - 0.12, face.z) - nf * 0.3)
	if lip.is_empty():
		return false
	var lip_p: Vector3 = lip.position
	var hang_pos := Vector3(lip_p.x, top - HANG_DROP, lip_p.z) + nf * WALL_GAP
	if not _fits(hang_pos):
		return false
	_start_hang(hang_pos, nf, top)
	return true


func _start_hang(pos: Vector3, nf: Vector3, top: float) -> void:
	_end_slide()
	_ease_shift(pos - global_position)          # the skin and the camera glide into the hang
	global_position = pos
	_visual.position = global_basis.inverse() * _vis_off
	velocity = Vector3.ZERO
	_hang = true
	_hang_n = nf
	_hang_top = top
	_hang_t = 0.0
	_hang_push = 0.0
	_grounded = false
	_jump_rising = false
	_air_jumps_left = air_jumps
	_kick_n = Vector3.ZERO
	_visual.rotation.y = atan2(nf.x, nf.z)
	_visual.hang = 1.0
	Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, 7), pos + Vector3.UP * HANG_DROP, -6.0, 0.8, 0.03)
	StaffSfx.play("tap", pos + Vector3.UP * HANG_DROP, -12.0, 0.85)
	kick(0.2)


func _tick_hang(delta: float, wish: Vector3) -> void:
	_hang_t += delta
	velocity = Vector3.ZERO
	var along := _hang_n.cross(Vector3.UP).normalized()
	var lat := wish.dot(along) if wish.length_squared() > 0.04 else 0.0
	var into := wish.dot(-_hang_n) if wish.length_squared() > 0.04 else 0.0
	var ready := _hang_t > 0.18 and not autopilot
	if ready and Input.is_action_just_pressed("jump"):
		if into < -0.4:
			_hang_kick(wish)                       # pulling away: kick off the wall
		else:
			_try_climb()
		return
	if ready and (Input.is_action_just_pressed("slide") or Input.is_action_just_pressed("dodge")):
		_let_go(1.0)
		return
	_hang_push = _hang_push + delta if into > 0.6 else 0.0
	if ready and _hang_push > 0.12 and _try_climb():
		return
	if ready and into < -0.7 and _hang_t > 0.45:
		_let_go(1.5)
		return
	var shimmy := 0.0
	if absf(lat) > 0.3:
		var step := along * signf(lat) * SHIMMY * delta
		if _ledge_at(global_position + step):
			global_position += step
			shimmy = signf(lat)
	_visual.hang = 1.0
	_visual.hang_shimmy = lerpf(_visual.hang_shimmy, -shimmy, 1.0 - exp(-10.0 * delta))
	_ease_tick(delta)
	_animate(delta, Vector3.ZERO)
	_update_gloom(delta)
	_cam_air_prev = _cam_air
	_cam_air = lerpf(_cam_air, 0.0, 1.0 - exp(-8.0 * delta))
	_air_base = global_position.y


## Is the ledge still under the hands (and the wall still there) with the body at `pos`?
func _ledge_at(pos: Vector3) -> bool:
	var face := _ray(pos + Vector3.UP * (HANG_DROP - 0.12), pos + Vector3.UP * (HANG_DROP - 0.12) - _hang_n * (WALL_GAP + 0.3))
	if face.is_empty():
		return false
	var over: Vector3 = (face.position as Vector3) - _hang_n * 0.22
	var top := _ray(Vector3(over.x, _hang_top + 0.3, over.z), Vector3(over.x, _hang_top - 0.3, over.z))
	if top.is_empty() or absf((top.position as Vector3).y - _hang_top) > 0.12:
		return false
	return _fits(pos)


func _let_go(push: float) -> void:
	_hang = false
	_visual.hang = 0.0
	_regrab = 0.45
	velocity = _hang_n * push
	_air_base = global_position.y


func _hang_kick(wish: Vector3) -> void:
	_hang = false
	_visual.hang = 0.0
	_regrab = 0.3
	var out := _hang_n * KICK_OUT
	if wish.length_squared() > 0.04:
		out = (out + Vector3(wish.x, 0.0, wish.z).normalized() * 2.0).limit_length(KICK_OUT * 1.1)
	velocity = Vector3(out.x, KICK_UP * 0.9, out.z)
	_jump_rising = true
	_kick_n = _hang_n
	_kick_lock = 0.22
	_visual.rotation.y = atan2(-out.x, -out.z)
	_visual.play_move(&"wallkick", 0.42)
	Sfx.play(SFX_JUMP, global_position + Vector3.UP * 1.5, -6.0)


## From the hang up onto the ledge, if there is room to stand up there.
func _try_climb() -> bool:
	# stand well onto the top if it is deep, else on the wall's crown (then it's a balance)
	var stand := Vector3.INF
	for depth: float in [0.42, 0.3, 0.2]:
		var on := Vector3(global_position.x, _hang_top, global_position.z) - _hang_n * (WALL_GAP + depth)
		var deck := _ray(on + Vector3.UP * 0.4, on + Vector3.DOWN * 0.3)
		if deck.is_empty() or (deck.normal as Vector3).y < 0.7:
			continue
		var at: Vector3 = (deck.position as Vector3) + Vector3.UP * 0.03
		if _fits(at):
			stand = at
			break
	if stand == Vector3.INF:
		return false
	_hang = false
	_visual.hang = 0.0
	_climb_from = global_position
	_climb_to = stand
	_climb_t = 0.0
	_climb_len = CLIMB_TIME
	_visual.play_move(&"climb", CLIMB_TIME)
	Sfx.play(SFX_JUMP, global_position + Vector3.UP * 1.6, -9.0, 0.8)
	return true


func _tick_climb(delta: float) -> void:
	_climb_t += delta
	var u := clampf(_climb_t / _climb_len, 0.0, 1.0)
	# up first (the pull and the press), then over onto the ledge
	var up_u := smoothstep(0.0, 0.62, u)
	var fwd_u := smoothstep(0.38, 1.0, u)
	global_position = Vector3(lerpf(_climb_from.x, _climb_to.x, fwd_u), lerpf(_climb_from.y, _climb_to.y, up_u), lerpf(_climb_from.z, _climb_to.z, fwd_u))
	velocity = Vector3.ZERO
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(_hang_n.x, _hang_n.z), 1.0 - exp(-12.0 * delta))
	_ease_tick(delta)
	_animate(delta, Vector3.ZERO)
	_update_gloom(delta)
	_cam_air_prev = _cam_air
	_air_base = global_position.y
	if u >= 1.0:
		_climb_t = -1.0
		velocity = -_hang_n * 1.2
		_grounded = true
		_regrab = 0.3
		_air_jumps_left = air_jumps


# --- vault -------------------------------------------------------------------------------------------

## Running at a wall between knee and chest height that is thin, with ground beyond: over it in
## one movement, keeping the speed. (Deeper tops are ledges: jump and mantle, or climb.)
func _try_vault(horiz: Vector3, wish: Vector3) -> bool:
	var spd := horiz.length()
	if spd < VAULT_SPEED or wish.length_squared() < 0.25 or not _grounded or _hollowing or autopilot:
		return false
	var dir := horiz / spd
	if Vector3(wish.x, 0.0, wish.z).normalized().dot(dir) < 0.7:
		return false
	var knee := global_position + Vector3.UP * 0.32
	var hit := _ray(knee, knee + dir * (0.45 + spd * 0.09))
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	var nf := Vector3(n.x, 0.0, n.z)
	if absf(n.y) > 0.3 or nf.length() < 0.3 or nf.normalized().dot(-dir) < 0.6:
		return false
	var face: Vector3 = hit.position
	var y0 := global_position.y
	var over := face + dir * 0.12
	var top_hit := _ray(Vector3(over.x, y0 + VAULT_MAX + 0.3, over.z), Vector3(over.x, y0 + VAULT_MIN - 0.05, over.z))
	if top_hit.is_empty() or (top_hit.normal as Vector3).y < 0.7:
		return false
	var top: float = (top_hit.position as Vector3).y
	var rise := top - y0
	if rise < VAULT_MIN or rise > VAULT_MAX:
		return false
	# how thick: walk along the top until it ends
	var depth := -1.0
	for k in range(1, 12):
		var d := 0.12 + 0.1 * float(k)
		var p := face + dir * d
		var h := _ray(Vector3(p.x, top + 0.3, p.z), Vector3(p.x, top - 0.25, p.z))
		if h.is_empty():
			depth = d - 0.05
			break
	if depth < 0.0 or depth > VAULT_DEPTH:
		return false
	# ground beyond, not far down, and room to land
	var lx := face + dir * (depth + 0.9)
	var land := _ray(Vector3(lx.x, top + 0.3, lx.z), Vector3(lx.x, y0 - 2.4, lx.z))
	if land.is_empty() or (land.normal as Vector3).y < 0.7:
		return false
	var to: Vector3 = (land.position as Vector3) + Vector3.UP * 0.03
	if not _fits(to):
		return false
	var apex := top + 0.14
	if test_move(Transform3D(global_basis, Vector3(global_position.x, apex, global_position.z)), Vector3(to.x - global_position.x, 0.0, to.z - global_position.z)):
		return false                              # something in the way over the top
	_end_slide()
	_vault_from = global_position
	_vault_to = to
	_vault_apex = apex
	_vault_v = dir * maxf(spd, walk_speed)
	var run := Vector2(to.x - global_position.x, to.z - global_position.z).length()
	_vault_len = clampf(run / maxf(spd, 4.0), 0.3, 0.55)
	_vault_t = 0.0
	velocity = _vault_v
	var side := 1.0 if (Basis(Vector3.UP, _yaw) * Vector3.RIGHT).dot(dir) >= 0.0 else -1.0
	_visual.rotation.y = atan2(-dir.x, -dir.z)
	_visual.play_move(&"vault", _vault_len, side)
	Sfx.play(SFX_JUMP, global_position + Vector3.UP, -8.0, 0.9)
	StaffSfx.play("swish", global_position + Vector3.UP * 1.2, -10.0)
	return true


func _tick_vault(delta: float) -> void:
	_vault_t += delta
	var u := clampf(_vault_t / _vault_len, 0.0, 1.0)
	var h := Vector3(_vault_from.x, 0.0, _vault_from.z).lerp(Vector3(_vault_to.x, 0.0, _vault_to.z), u)
	var y: float
	if u < 0.42:
		var a := u / 0.42
		y = lerpf(_vault_from.y, _vault_apex, 1.0 - (1.0 - a) * (1.0 - a))
	else:
		var b := (u - 0.42) / 0.58
		y = lerpf(_vault_apex, _vault_to.y, b * b)
	global_position = Vector3(h.x, y, h.z)
	velocity = _vault_v
	_ease_tick(delta)
	_animate(delta, _vault_v)
	_update_gloom(delta)
	# the view rises only part of the hop over the wall, like a jump's (r29: it rode the whole arc,
	# the bumpiest camera on the movement course)
	_cam_air_prev = _cam_air
	_air_base = minf(_vault_from.y, _vault_to.y)
	var up := global_position.y - _air_base
	_cam_air = lerpf(_cam_air, -minf(maxf(up, 0.0) * 0.65, 1.1), 1.0 - exp(-16.0 * delta))
	if u >= 1.0:
		_vault_t = -1.0
		velocity = _vault_v
		_grounded = true
		_air_base = global_position.y


# --- wall kick -----------------------------------------------------------------------------------------

## A tall wall touched (or right beside you) in the air, and not the one you just kicked off.
func _can_wallkick(wish: Vector3) -> bool:
	if _grounded or _hollowing or _coyote > 0.0:
		return false
	var n := Vector3.ZERO
	if _wall_t > 0.0:
		n = _wall_n
	else:
		for d: Vector3 in [Vector3(velocity.x, 0.0, velocity.z), Vector3(wish.x, 0.0, wish.z)]:
			if d.length_squared() < 0.01:
				continue
			var c := global_position + Vector3.UP * 0.9
			var hit := _ray(c, c + d.normalized() * 0.7)
			if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.3:
				continue
			var hn: Vector3 = hit.normal
			n = Vector3(hn.x, 0.0, hn.z).normalized()
			break
	if n == Vector3.ZERO:
		return false
	if _kick_n != Vector3.ZERO and n.dot(_kick_n) > 0.7:
		return false
	# tall enough to kick: wall above the head too (parapets and kerbs don't count)
	var head := global_position + Vector3.UP * 1.65
	if _ray(head, head - n * 0.75).is_empty():
		return false
	_wall_n = n
	return true


func _wall_kick(wish: Vector3) -> void:
	if _stam != null:
		_stam.drain(Stamina.WALL_KICK)          # r31: costs Breath, never refused (a kick is a save)
	var n := _wall_n
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var along := flat - n * flat.dot(n)
	var out := n * KICK_OUT + along * 0.55
	if wish.length_squared() > 0.04:
		out += Vector3(wish.x, 0.0, wish.z).normalized() * 1.2
	out = out.limit_length(sprint_speed)
	velocity = Vector3(out.x, KICK_UP, out.z)
	_jump_rising = true
	_kick_n = n
	_wall_t = 0.0
	_regrab = 0.15
	_kick_lock = 0.22                             # the kick's line holds a moment before the stick steers
	_visual.rotation.y = atan2(-out.x, -out.z)
	_visual.play_move(&"wallkick", 0.42)
	var at := global_position + Vector3.UP * 0.6 - n * 0.35
	Vfx.burst(at, Color(0.16, 0.15, 0.17, 0.5), {"count": 10, "life": 0.5, "speed": Vector2(0.5, 1.6), "size": 0.16, "gravity": -0.3, "dir": n, "spread": 60.0, "additive": false})
	Sfx.play(SFX_JUMP, at, -5.0, 0.95)
	Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, 7), at, -4.0, 0.85, 0.03)
	kick(0.2)


## Remember walls touched in the air (wall kick) and slopes too steep to stand on (steep slide).
func _note_contacts(delta: float) -> void:
	_wall_t = maxf(0.0, _wall_t - delta)
	_steep_t = maxf(0.0, _steep_t - delta)
	if _grounded:
		_kick_n = Vector3.ZERO
		return
	if _steep_t <= 0.0 and velocity.y <= 0.0 and get_slide_collision_count() == 0 and _hang == false:
		# stepped off onto a slope too steep to stand on: take to it instead of free-falling past it
		var c := global_position + Vector3.UP * 0.2
		var hit := _ray(c, c + Vector3.DOWN * 0.9)
		if not hit.is_empty():
			var hn: Vector3 = hit.normal
			if hn.y >= 0.3 and hn.y < 0.72:
				_steep_t = 0.12
				_steep_n = hn
				velocity.y = minf(velocity.y, -4.0)
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if absf(n.y) < 0.3:
			_wall_t = 0.15
			_wall_n = Vector3(n.x, 0.0, n.z).normalized()
		elif n.y >= 0.3 and n.y < 0.72 and _steep_t <= 0.0:
			# a capsule rolling off a stair nose touches its edge at a slant too: only a real slope
			# (the ground under the body is itself that steep) counts
			var c := global_position + Vector3.UP * 0.3 + Vector3(n.x, 0.0, n.z).normalized() * 0.15
			var hit := _ray(c, c + Vector3.DOWN * 1.0)
			if not hit.is_empty() and (hit.normal as Vector3).y < 0.72 and (hit.normal as Vector3).y >= 0.3:
				_steep_t = 0.12
				_steep_n = hit.normal
		elif n.y >= 0.3 and n.y < 0.72:
			_steep_t = 0.12
			_steep_n = n


## Down a slope too steep to stand on: a controlled slide (speed builds to a cap, a little
## steering across it), the rig's surfing crouch, dust and scrape. Jump leaves it outward.
func _tick_steep(delta: float, wish: Vector3, cur: Vector3) -> Vector3:
	var down := Vector3(_steep_n.x, 0.0, _steep_n.z).normalized()
	var across := down.cross(Vector3.UP)
	var h := cur + down * gravity * 0.6 * delta
	if wish.length_squared() > 0.04:
		h += across * wish.dot(across) * 3.0 * delta
	h = h.limit_length(STEEP_MAX_V)
	velocity.y = maxf(velocity.y, -STEEP_MAX_V)
	_slide_fx.global_position = global_position + Vector3.UP * 0.05
	if not _slide_fx.emitting:
		_slide_fx.emitting = true
		_slide_sfx.play()
	_slide_sfx.pitch_scale = 0.6 + 0.05 * h.length()
	return h


# --- beams -------------------------------------------------------------------------------------------

## On something narrow (both sides open air): balance. Checked every other tick, two short rays
## (two more on the beam to find its middle and lean you back toward it).
func _beam_probe(horiz: Vector3) -> void:
	_beam_frame += 1
	if not is_on_floor() or _glued or _sliding or _roll_t >= 0.0:
		_beam_on = false
		return
	if _beam_frame % 2 != 0:
		return
	var fwd := horiz.normalized() if horiz.length() > 0.3 else -_visual.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	_beam_side = fwd.cross(Vector3.UP).normalized()
	var base := global_position + Vector3.UP * 0.25
	var drop := Vector3.DOWN * 0.6
	var l := _ray(base - _beam_side * BEAM_W, base - _beam_side * BEAM_W + drop)
	var r := _ray(base + _beam_side * BEAM_W, base + _beam_side * BEAM_W + drop)
	_beam_on = l.is_empty() and r.is_empty()
	if _beam_on:
		# and standing on something right under the middle (not mid-way down a stair)
		var c := _ray(base, base + Vector3.DOWN * 0.4)
		_beam_on = not c.is_empty() and (c.position as Vector3).y > global_position.y - 0.1
	if not _beam_on:
		_beam_mid = 0.0
		return
	var lh := not _ray(base - _beam_side * 0.15, base - _beam_side * 0.15 + drop).is_empty()
	var rh := not _ray(base + _beam_side * 0.15, base + _beam_side * 0.15 + drop).is_empty()
	_beam_mid = (0.0 if lh == rh else (-0.12 if lh else 0.12))


# --- dodge roll ----------------------------------------------------------------------------------------

## A tucked roll along the stick (or a backstep with no stick): brief i-frames, keeps the run, no
## cooldown beyond its own length. Distinct from the Rift Step: no riposte, no marks, stays visible.
func _try_dodge(wish: Vector3) -> bool:
	if _roll_cd > 0.0 or _roll_t >= 0.0 or not _grounded or _hollowing or _trav_busy() or _mantle_t >= 0.0 or _step_t > 0.0:
		return false
	if _stam != null and not _stam.spend(Stamina.HOP if wish.length_squared() < 0.04 else Stamina.ROLL):
		return false                            # r31: no Breath, no roll
	if _arts != null:
		_arts.cancel()                          # a roll cancels a strike or a guard
	if _book != null:
		_book.cancel_lock()                     # ... and the cast lock, so a spell can follow the roll at once
	_dodge_roll = true
	_end_slide()
	_roll_t = 0.0
	_roll_evade = true
	if wish.length_squared() < 0.04:
		var back := _visual.global_basis.z
		_roll_dir = Vector3(back.x, 0.0, back.z).normalized()
		_roll_len = HOP_TIME
		_roll_speed = 5.6
		velocity.y = 2.4
		_grounded = false
		_visual.play_move(&"hop", HOP_TIME)
	else:
		_roll_dir = Vector3(wish.x, 0.0, wish.z).normalized()
		_roll_len = ROLL_TIME
		_roll_speed = maxf(ROLL_DIST / ROLL_TIME * 1.25, Vector2(velocity.x, velocity.z).length())
		_visual.rotation.y = atan2(-_roll_dir.x, -_roll_dir.z)
		_visual.play_move(&"roll", ROLL_TIME)
		_set_capsule(1.1)
	StaffSfx.play("swish", global_position + Vector3.UP, -8.0, 0.85)
	Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, 7), global_position, -8.0, 0.8, 0.03)
	return true


## A hard landing while moving: roll it out (no i-frames, no lost speed).
func _land_roll(dir: Vector3, speed: float) -> void:
	_dodge_roll = false
	_rolled_landing = true
	_end_slide()
	_roll_t = 0.0
	_roll_evade = false
	_roll_dir = dir
	_roll_len = ROLL_TIME
	_roll_speed = maxf(speed, walk_speed * 1.2)
	_visual.rotation.y = atan2(-dir.x, -dir.z)
	_visual.play_move(&"roll", ROLL_TIME)
	_set_capsule(1.1)


func _tick_roll(delta: float, wish := Vector3.ZERO) -> Vector3:
	_roll_t += delta
	var u := clampf(_roll_t / _roll_len, 0.0, 1.0)
	if _roll_evade and not _crawl and _roll_t >= ROLL_EVADE.x and _roll_t <= ROLL_EVADE.y * (_roll_len / ROLL_TIME):
		_evade_t = maxf(_evade_t, 0.02)
		_evade_roll = true
	var spd := _roll_speed * lerpf(1.0, 0.55, u * u)
	if u >= 1.0:
		_roll_t = -1.0
		_roll_cd = ROLL_CD
		if _col and (_col.shape as CapsuleShape3D).height < _col_h:
			if _headroom():
				_set_capsule(_col_h)
				_crawl = false
			else:
				# under something: stay low and crawl along the stick until there is room to stand.
				# (r29: the old test_move counted a wall the roll ended against as a ceiling, so a roll
				# into any wall froze the wanderer crouched, deaf to the stick, for good.)
				_roll_t = _roll_len * 0.98
				_crawl = true
				var w := Vector3(wish.x, 0.0, wish.z)
				if w.length_squared() < 0.04:
					return Vector3.ZERO
				_roll_dir = w.normalized()
				return _roll_dir * CRAWL_SPEED
		return _roll_dir * minf(spd, sprint_speed)
	return _roll_dir * spd


## Room to stand at the body's spot: the full capsule, a little thinner and lifted off the floor so
## a wall it leans on or the ground under it doesn't count (test_move from a touching start does).
func _headroom(at := Vector3.INF) -> bool:
	if _col == null or not (_col.shape is CapsuleShape3D):
		return true
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	if _tall_q == null:
		var cap := CapsuleShape3D.new()
		cap.radius = (_col.shape as CapsuleShape3D).radius - 0.04
		cap.height = maxf(_col_h - 0.08, cap.radius * 2.0 + 0.01)
		_tall_q = PhysicsShapeQueryParameters3D.new()
		_tall_q.shape = cap
		_tall_q.exclude = [get_rid()]
		_tall_q.margin = 0.0
	_tall_q.collision_mask = collision_mask
	var p := global_position if at == Vector3.INF else at
	_tall_q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (_col_h * 0.5 + 0.04))
	return space.intersect_shape(_tall_q, 1).is_empty()


# --- target lock -------------------------------------------------------------------------------------

func _toggle_lock() -> void:
	if is_instance_valid(_lock):
		_release_lock()
		return
	var t := _remembered_target()              # r33: the target you had is the one you lock back onto
	if t == null:
		t = _pick_target(0)
	if t:
		_set_lock(t)
	else:
		_recentre = true                         # nothing to lock: swing the view behind the wanderer


func _set_lock(t: Enemy) -> void:
	_lock = t
	var cs := combat()
	if cs != null:
		cs.call("set_target", t)               # r33: the lock is the target (remembered after it lets go)
	_lock_lost = 0.0
	_visual.lock = true
	if _lock_mark == null:
		_lock_mark = _make_lock_mark()
	_lock_mark.visible = true
	Sfx.play("res://art/audio/mark_tick.wav", global_position + Vector3.UP, -12.0, 1.2, 0.02)


func _release_lock() -> void:
	_lock = null
	_visual.lock = false
	if _lock_mark:
		_lock_mark.visible = false


## r33: the remembered target when it is still a fair pick (alive, in range, in sight).
func _remembered_target() -> Enemy:
	var t := current_target() as Enemy
	if t == null or not is_instance_valid(t) or not t.is_alive():
		return null
	if global_position.distance_to(t.global_position) > LOCK_RANGE:
		return null
	if not _ray(global_position + Vector3.UP * 1.4, t.global_position + Vector3.UP * (t.hp_bar_y * 0.55)).is_empty():
		return null
	return t


## r33 combat, Tab-style: the next foe nearest-first in front of the view (wraps to the nearest); the
## camera locks onto it. Returns the new target or null.
func cycle_target() -> Enemy:
	var cam_xf := _cam.global_transform
	var fwd := -cam_xf.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	var near: Array = []
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var to := e.global_position - global_position
		var d := to.length()
		if d > LOCK_RANGE:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if d > 2.5 and flat.length_squared() > 0.0001 and flat.normalized().dot(fwd) < 0.0:
			continue                           # behind you: Tab picks what you can see
		near.append([d, e])
	if near.is_empty():
		return null
	near.sort_custom(func(a, b): return a[0] < b[0])
	var cur := current_target()
	var start := 0
	for k in near.size():
		if near[k][1] == cur:
			start = k + 1
			break
	for n in near.size():
		var e: Enemy = near[(start + n) % near.size()][1]
		if e == cur and near.size() > 1:
			continue
		if _ray(global_position + Vector3.UP * 1.4, e.global_position + Vector3.UP * (e.hp_bar_y * 0.55)).is_empty():
			_set_lock(e)
			return e
	return null


## The foe nearest the middle of the view (side 0), or the next one left (-1) / right (+1) of the
## current target, in sight and within LOCK_RANGE.
func _pick_target(side: int) -> Enemy:
	var cam_xf := _cam.global_transform
	var fwd := -cam_xf.basis.z
	var right := cam_xf.basis.x
	var cur_s := 0.0
	if side != 0 and is_instance_valid(_lock):
		cur_s = (_lock.global_position - cam_xf.origin).normalized().dot(right)
	var best: Enemy = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive() or e == _lock:
			continue
		var chest := e.global_position + Vector3.UP * (e.hp_bar_y * 0.55)
		var to := chest - cam_xf.origin
		var d := to.length()
		if global_position.distance_to(e.global_position) > LOCK_RANGE or d < 0.5:
			continue
		var dir := to / d
		var dot := dir.dot(fwd)
		var s := dir.dot(right)
		var score := 0.0
		if side == 0:
			if dot < 0.45:
				continue
			score = (1.0 - dot) * 12.0 + d * 0.04
		else:
			if dot < 0.0 or (s - cur_s) * float(side) <= 0.02:
				continue
			score = absf(s - cur_s) * 6.0 + d * 0.03
		if score >= best_score:
			continue
		if not _ray(global_position + Vector3.UP * 1.4, chest).is_empty():
			continue
		best_score = score
		best = e
	return best


## Physics tick: drop the lock when the target dies, goes far, or stays out of sight; a dead
## target hands the lock to the next one in view.
func _lock_tick(delta: float) -> void:
	_regrab = maxf(0.0, _regrab - delta)
	_roll_cd = maxf(0.0, _roll_cd - delta)
	_kick_lock = maxf(0.0, _kick_lock - delta)
	if _lock == null:
		return
	if not is_instance_valid(_lock) or not _lock.is_alive():
		var nxt := _pick_target(0)
		if nxt:
			_set_lock(nxt)
		else:
			_release_lock()
		return
	if global_position.distance_to(_lock.global_position) > LOCK_RANGE + 6.0 or _hollowing:
		_release_lock()
		return
	_lock_los_t -= delta
	if _lock_los_t <= 0.0:
		_lock_los_t = 0.2
		var seen := _ray(global_position + Vector3.UP * 1.4, _lock.global_position + Vector3.UP * (_lock.hp_bar_y * 0.55)).is_empty()
		_lock_lost = 0.0 if seen else _lock_lost + 0.2
		if _lock_lost > 1.4:
			_release_lock()


## Render frame: the view swings onto the target (framing the wanderer and the foe), the mark sits
## on it; a hard flick of the mouse or stick moves the lock to the next foe that side.
func _lock_view(delta: float, body: Vector3) -> void:
	_lock_flick_t = maxf(0.0, _lock_flick_t - delta)
	_lock_flick = move_toward(_lock_flick, 0.0, delta * 360.0)     # only a quick flick adds up
	if absf(_lock_flick) > 90.0:
		var nxt := _pick_target(int(signf(_lock_flick)))
		_lock_flick = 0.0
		_lock_flick_t = 0.0
		if nxt:
			_set_lock(nxt)
	var tp := _lock.get_global_transform_interpolated().origin + Vector3.UP * (_lock.hp_bar_y * 0.55)
	# aim from the camera's own pivot (over the right shoulder), not the body: the target then sits
	# on the crosshair, clear of the wanderer, instead of hiding behind the robe up close (r29)
	var pivot := body + Vector3.UP * 1.3 + Basis(Vector3.UP, _yaw) * Vector3(_arm.position.x, 0.0, 0.0)
	var to := tp - pivot
	if Vector2(to.x, to.z).length() < 1.2:
		to = tp - (body + Vector3.UP * 1.3)     # right on top of it: the shoulder offset would spin the view
	var flat := Vector2(to.x, to.z).length()
	if flat > 0.4:
		var rate := 7.0 if flat > 3.0 else 4.0
		_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), 1.0 - exp(-rate * delta))
	var want_pitch := clampf(atan2(to.y, maxf(flat, 1.0)) * 0.6 - 0.2, pitch_min, 0.15)
	_pitch = lerpf(_pitch, want_pitch, 1.0 - exp(-4.0 * delta))
	if _lock_mark:
		_lock_mark.global_position = tp + Vector3.UP * 0.15


func _make_lock_mark() -> MeshInstance3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5)
			var r := absf(d.x) + absf(d.y)                 # a diamond
			var a := clampf(1.0 - absf(r - 24.0) / 3.5, 0.0, 1.0) + clampf(1.0 - r / 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.fixed_size = true
	m.disable_fog = true
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = Color(1.4, 0.75, 2.6, 0.9)
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var mi := MeshInstance3D.new()
	mi.name = "LockMark"
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return mi


## Where the upper body should look: the lock target, else the camera's aim. Facing and twist:
## locked on (walking) or standing in a fight, the body squares up to the aim and steps round;
## running while casting, the legs keep to the run and the chest turns toward the aim (up to
## ~65 degrees, beyond which the body turns and back-pedals).
func _facing(delta: float, horiz: Vector3, sprint_held: bool) -> void:
	var locked := is_instance_valid(_lock)
	var aim_yaw := _yaw
	if locked:
		var to := _lock.global_position - global_position
		aim_yaw = atan2(-to.x, -to.z)
	var spd := horiz.length()
	var want_twist := 0.0
	if _sliding or _roll_t >= 0.0 or _hang or _climb_t >= 0.0 or _vault_t >= 0.0:
		_twist = lerpf(_twist, 0.0, 1.0 - exp(-10.0 * delta))
		_visual.twist = _twist
		return
	if _arts != null and _arts.phase() >= 0:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, _face_yaw, 1.0 - exp(-24.0 * delta))   # r31: squared to the strike
		_twist = lerpf(_twist, 0.0, 1.0 - exp(-10.0 * delta))
		_visual.twist = _twist
		return
	if locked or _combat_t > 0.0:
		var move_yaw := atan2(-horiz.x, -horiz.z)
		var free_run := spd > 2.2 and (not locked or (sprint_held and spd > walk_speed * 1.05))
		var diff := angle_difference(move_yaw, aim_yaw)
		if free_run and absf(diff) < 1.9:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, move_yaw, 1.0 - exp(-lerpf(15.0, 9.0, _run_blend) * delta))
			want_twist = clampf(angle_difference(_visual.rotation.y, aim_yaw), -1.15, 1.15)
		else:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, aim_yaw, 1.0 - exp(-14.0 * delta))
	elif spd > 0.2:
		var rate := lerpf(15.0, 9.0, _run_blend)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-horiz.x, -horiz.z), 1.0 - exp(-rate * delta))
	_twist = lerpf(_twist, want_twist, 1.0 - exp(-10.0 * delta))
	_visual.twist = _twist


# --- camera feel ---------------------------------------------------------------------------------------

## Physics tick: the jump hold (the view rises only part of a jump's height, then settles when you
## land, wherever that is) and the look-ahead (the view leads a run across the screen).
func _cam_feel_tick(delta: float) -> void:
	_cam_air_prev = _cam_air
	_look_ahead_prev = _look_ahead
	var want := 0.0
	if _grounded or _hang:
		_air_base = global_position.y
	else:
		var up := global_position.y - _air_base
		if up > 0.0:
			want = -minf(up * 0.45, 1.1)
		else:
			_air_base = global_position.y           # below the take-off: follow the fall at once
	_cam_air = lerpf(_cam_air, want, 1.0 - exp(-(14.0 if want < _cam_air else 9.0) * delta))
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var right := Basis(Vector3.UP, _yaw) * Vector3.RIGHT
	var lead := right * flat.dot(right) * 0.065 * (0.4 + 0.6 * _run_blend)
	if is_instance_valid(_lock):
		lead = Vector3.ZERO
	_look_ahead = _look_ahead.lerp(lead.limit_length(0.45), 1.0 - exp(-2.5 * delta))


## A thin thing between the camera and the wanderer (a post, a lantern pole, a sapling) is ignored
## instead of yanking the camera in: the camera's own spot must be clear and it must cover less than
## half of the wanderer's width (THIN_RAYS parallel rays across +-THIN_HALF_W, fewer than half
## blocked). r35: it used to be "one of two edge rays gets through", so a stele or a raid standing
## stone off to one side passed as a pole: the camera stayed behind it and the stone hid the wanderer
## (shots/critB_first_review_seg_strafe.png) or filled half the screen in the henge raid.
func _thin_occluder(from: Vector3, dir: Vector3, want: float) -> bool:
	var space := get_world_3d().direct_space_state
	var cam_at := from + dir * want
	if _thin_q == null:
		var sph := SphereShape3D.new()
		sph.radius = ARM_PROBE
		_thin_q = PhysicsShapeQueryParameters3D.new()
		_thin_q.shape = sph
		_thin_q.collision_mask = Layers.WORLD
		_thin_q.exclude = [get_rid()]
	var q := _thin_q
	q.transform = Transform3D(Basis.IDENTITY, cam_at)
	if not space.intersect_shape(q, 1).is_empty():
		return false
	if _thin_ray == null:
		_thin_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Layers.WORLD, [get_rid()])
	var side := _arm.global_basis.x.normalized()
	var blocked := 0
	for i in THIN_RAYS:
		var a := from + side * lerpf(-THIN_HALF_W, THIN_HALF_W, float(i) / float(THIN_RAYS - 1))
		_thin_ray.from = a
		_thin_ray.to = a + dir * want
		if not space.intersect_ray(_thin_ray).is_empty():
			blocked += 1
			if blocked * 2 >= THIN_RAYS:
				return false
	return true


# --- movement feel: step-up and mantle -----------------------------------------------------------

## Walk straight up small ledges (stair risers, kerbs, plinth edges) instead of stopping dead.
## Test: blocked at foot level, clear STEP_MAX higher, ground found just ahead within the step.
func _try_step_up(horiz: Vector3, delta: float) -> bool:
	if horiz.length() < 0.6 or not is_on_wall() or _sliding:
		return false
	var dir := horiz.normalized()
	var wall_n := get_wall_normal()
	var flat_n := Vector3(wall_n.x, 0.0, wall_n.z)
	# a capsule meets a step's edge with its rounded bottom, so the contact normal tilts up:
	# judge the contact by its horizontal direction only
	if flat_n.length() < 0.2 or flat_n.normalized().dot(-dir) < 0.35:
		return false                               # glancing contact
	var lift := Vector3.UP * STEP_MAX
	var probe := dir * 0.38                         # a capsule radius ahead: land on the step, not its edge
	var fwd := dir * maxf(horiz.length() * delta, 0.06)
	if test_move(global_transform, lift):
		return false                               # no headroom
	var up := global_transform.translated(lift)
	if test_move(up, probe):
		return false                               # still blocked higher: a real wall
	var col := KinematicCollision3D.new()
	if not test_move(up.translated(probe), -lift, col):
		return false
	if col.get_normal().y < 0.7:
		return false
	var rise := STEP_MAX - col.get_travel().length()
	if rise < 0.03:
		return false
	global_position += Vector3.UP * (rise + 0.01) + fwd
	# stand on the tread, not balanced on its nose (a capsule's round bottom slides back off it)
	var extra := Vector3.ZERO
	var below := KinematicCollision3D.new()
	for k in 5:
		if test_move(global_transform.translated(extra), Vector3.DOWN * 0.1, below) and below.get_normal().y >= 0.75:
			break
		if test_move(global_transform.translated(extra), dir * 0.06):
			break
		extra += dir * 0.06
	global_position += extra
	velocity.y = 0.0
	_ease_shift(Vector3.UP * (rise + 0.01) + extra)   # body pops up; the skin and camera glide after it
	_visual.step_bump(rise)
	return true


## Moved from outside (global_position set by a test, a respawn, a lava throw): drop the smoothing
## state so the skin and the camera don't glide across the jump, and re-test the ground.
func _on_teleported() -> void:
	_vis_off = Vector3.ZERO
	_vis_off_v = Vector3.ZERO
	_cam_off = Vector3.ZERO
	_cam_off_v = Vector3.ZERO
	_cam_off_prev = Vector3.ZERO
	_glued = false
	_grounded = is_on_floor()
	_land_slow = 0.0
	_end_traverse()
	_air_base = global_position.y
	_cam_air = 0.0
	_cam_air_prev = 0.0


## Teleport helper: same as setting global_position, plus no interpolation streak.
func teleport(pos: Vector3, keep_velocity := false) -> void:
	global_position = pos
	if not keep_velocity:
		velocity = Vector3.ZERO
	reset_physics_interpolation()
	_on_teleported()
	_last_pos = pos


## Critically damped spring toward 0 (exact, any frame rate) for the camera or the visual offset.
func _spring3(cam: bool, w: float, dt: float) -> void:
	var x := _cam_off if cam else _vis_off
	var v := _cam_off_v if cam else _vis_off_v
	if x.length_squared() < 0.0000003 and v.length_squared() < 0.00003:
		x = Vector3.ZERO
		v = Vector3.ZERO
	else:
		var e := exp(-w * dt)
		var j := v + w * x
		x = (x + j * dt) * e
		v = (v - w * j * dt) * e
	if cam:
		_cam_off = x.limit_length(0.8)
		_cam_off_v = v
	else:
		_vis_off = x.limit_length(0.6)
		_vis_off_v = v


## Shift the body by `d` without the skin or the view jumping: both ease after it.
func _ease_shift(d: Vector3) -> void:
	_vis_off -= d
	_cam_off -= d


## Walking off a small drop (a stair going down, a kerb): settle straight onto the lower ground
## instead of a little fall each tread. The shape cast stops on a stair nose too (the capsule's
## round bottom rolls off it smoothly frame by frame). Real drops (> STEP_DOWN) fall as before.
func _step_down() -> void:
	if _mantle_t >= 0.0 or _hollowing:
		return
	# real floor under the middle of the body, not just a corner beside it
	var space := get_world_3d().direct_space_state
	var c := global_position + Vector3.UP * 0.3
	var ray := PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * (STEP_DOWN + 0.32), collision_mask, [get_rid()])
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.69:
		return
	var col := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3.DOWN * STEP_DOWN, col):
		return
	if col.get_normal().y < 0.3:
		return                                     # a wall, not ground
	var drop := col.get_travel()
	global_position += drop
	velocity.y = 0.0
	_grounded = true
	_glued = true
	_ease_shift(drop)


## Ground speed model. The run turns toward the stick at a speed-dependent rate (no speed lost
## mid-turn, unlike a straight lerp), a hard reversal skids to a stop first, speeding up is quick
## to a walk and builds to a sprint, and stopping is exponential plus a constant bite.
func _ground_move(cur: Vector3, target: Vector3, delta: float) -> Vector3:
	var speed := cur.length()
	var want := target.length()
	if want < 0.01:
		var s := maxf(0.0, (speed + decel_bite / decel) * exp(-decel * delta) - decel_bite / decel)
		return cur.normalized() * s if speed > 0.0001 else Vector3.ZERO
	var tdir := target / want
	var dir := tdir
	if speed > walk_speed * 0.45:
		dir = cur / speed
		var ang := dir.signed_angle_to(tdir, Vector3.UP)
		if absf(ang) > skid_angle:
			# reversal: brake along the old line, then turn on the spot once slow
			var s := maxf(0.0, (speed + decel_bite / decel) * exp(-decel * 1.3 * delta) - decel_bite / decel)
			return dir * s
		var rate := lerpf(turn_rate, turn_rate_sprint, _run_blend)
		dir = dir.rotated(Vector3.UP, clampf(ang, -rate * delta, rate * delta))
		speed *= lerpf(1.0, maxf(0.0, dir.dot(tdir)), 1.0 - exp(-4.0 * delta))   # cornering bleeds a little
	elif speed > 0.0001:
		speed *= maxf(0.0, (cur / speed).dot(tdir))   # slow: face the stick at once, keep what points that way
	var r := accel
	if speed > want:
		r = coast
	elif speed > walk_speed * 0.98:
		r = sprint_accel
	speed = lerpf(speed, want, 1.0 - exp(-r * delta))
	return dir * speed


## Uphill is slower, downhill a touch quicker (on top of floor_constant_speed).
func _slope_scale(target: Vector3) -> float:
	if target.length_squared() < 0.0001 or not is_on_floor():
		return 1.0
	var n := get_floor_normal()
	var grade := -Vector2(n.x, n.z).dot(Vector2(target.x, target.z).normalized())   # + uphill
	return 1.0 - SLOPE_UPHILL_SLOW * maxf(grade, 0.0) + SLOPE_DOWNHILL_GAIN * maxf(-grade, 0.0)


## Landing weight: hard landings cost speed for a moment, kick up dust and dip the view.
func _land(was_grounded: bool, vy_before: float) -> void:
	if not _grounded or was_grounded:
		return
	var impact := -vy_before
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if impact > ROLL_LAND_V and not _sliding and _roll_t < 0.0 and (flat.length() > 2.5 or Input.is_action_pressed("dodge")):
		_land_roll(flat.normalized() if flat.length() > 0.1 else -_visual.global_basis.z, flat.length())
		kick(0.3)                                # rolled out: no speed lost
	elif impact > LAND_SLOW_V:
		_land_slow = clampf((impact - LAND_SLOW_V) / 10.0, 0.0, 0.5 if impact < ROLL_LAND_V else 0.75)
	_fall_hurt(impact)
	if impact > 5.0:
		var k := clampf((impact - 5.0) / 8.0, 0.0, 1.0)
		Vfx.burst(global_position + Vector3.UP * 0.05, Color(0.16, 0.15, 0.17, 0.55), {"count": 14, "life": 0.6, "speed": Vector2(0.6, 1.8), "size": 0.22, "gravity": -0.4, "dir": Vector3.UP, "spread": 85.0, "additive": false, "radius": 0.3})
		if k > 0.4:
			kick(0.15 + 0.35 * k)


## Camera boom: our own sphere probe (the SpringArm's collision is off). Pulls in fast when
## something comes between, eases back out slowly, shortens when looking up (no ground clipping),
## and lengthens a little at a sprint.
func _update_arm(delta: float) -> void:
	# close fight (locked on, or a foe within ~4.5 m ahead): the view rises and pulls back a little so
	# what is in front of the wanderer reads over the shoulder instead of behind the robe (r29)
	var close := is_instance_valid(_lock) or (is_instance_valid(_look_foe) and _look_foe.is_alive() and _look_foe.global_position.distance_squared_to(global_position) < 20.0)
	_fight_k = move_toward(_fight_k, 1.0 if close else 0.0, delta * (1.6 if close else 0.8))
	var fk := smoothstep(0.0, 1.0, _fight_k)
	_rig.global_position += Vector3.UP * 0.32 * fk
	var want := ARM_LEN * lerpf(1.0, 0.62, clampf(_pitch / pitch_max, 0.0, 1.0))
	want += 0.35 * _run_blend - 0.25 * _slide_blend + 0.45 * fk
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var reach := want
	if space:
		_shoulder_tick(space, want, delta)
		if _arm_q == null:                       # one query object, not two allocations per rendered frame
			var sph := SphereShape3D.new()
			sph.radius = ARM_PROBE
			_arm_q = PhysicsShapeQueryParameters3D.new()
			_arm_q.shape = sph
			_arm_q.collision_mask = Layers.WORLD
			_arm_q.exclude = [get_rid()]
		var q := _arm_q
		q.transform = Transform3D(Basis.IDENTITY, _arm.global_position)
		q.motion = _arm.global_basis.z.normalized() * want
		var frac: PackedFloat32Array = space.cast_motion(q)
		if frac.size() > 0:
			reach = want * frac[0]
		if reach < want - 0.05 and _thin_occluder(_arm.global_position, _arm.global_basis.z.normalized(), want):
			_thin_hold = 0.15                    # a post or a pole: let it pass, don't yank the view in
		_thin_hold = maxf(0.0, _thin_hold - delta)
		if _thin_hold > 0.0:
			reach = want
	reach = maxf(reach, 0.5)
	if reach < _cam_len:
		_cam_len = minf(lerpf(_cam_len, reach, 1.0 - exp(-28.0 * delta)), reach + 0.25)
	else:
		_cam_len = lerpf(_cam_len, reach, 1.0 - exp(-3.2 * delta))
	_arm.spring_length = _cam_len
	_cam.position = Vector3(0.0, 0.0, _cam_len)


## r35: the boom sits SHOULDER m over the right shoulder, and the spring cast only watches the boom,
## so a stele or a raid stone to its left could stand between the camera and the wanderer without
## touching it: the view stayed behind the stone (shots/critB_first_review_seg_strafe.png). Each
## rendered frame this looks at the wanderer from where the full-shoulder camera would stand. When
## most of the body is hidden (SIGHT_HIDDEN of the six rays), or that camera would have to come in
## closer than SHOULDER_NEAR (the offset then pushes the wanderer out of frame), the boom swings in
## behind the wanderer, where the spring cast below handles whatever is still in the way; it swings
## back out once the shoulder view is clear again. Judged from the full-shoulder spot, which does not
## move with the swing, so the swing cannot feed back on itself.
func _shoulder_tick(space: PhysicsDirectSpaceState3D, want: float, delta: float) -> void:
	var dir := _arm.global_basis.z.normalized()
	var piv := _pitch_node.global_transform * Vector3(SHOULDER, _arm.position.y, _arm.position.z)
	if _sight_ray == null:
		_sight_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Layers.WORLD, [get_rid()])
	var r := _sight_ray
	r.from = piv
	r.to = piv + dir * want
	var hit := space.intersect_ray(r)
	var reach := want if hit.is_empty() else maxf(0.0, piv.distance_to(hit.position) - ARM_PROBE)
	var cam_at := piv + dir * reach
	var body := global_position
	var across := (body - cam_at).cross(Vector3.UP)
	across = across.normalized() if across.length_squared() > 0.0001 else _arm.global_basis.x
	var hidden := 0
	for y: float in [1.1, 1.6]:
		for s: float in [-0.3, 0.0, 0.3]:
			r.from = cam_at
			r.to = body + Vector3.UP * y + across * s
			if not space.intersect_ray(r).is_empty():
				hidden += 1
	if hidden >= SIGHT_HIDDEN:
		_sight_hold = 0.5                        # stays in a beat, so the edge of a stone does not flicker it
	_sight_hold = maxf(0.0, _sight_hold - delta)
	var k_want := 0.0 if _sight_hold > 0.0 else smoothstep(SHOULDER_NEAR * 0.5, SHOULDER_NEAR, reach)
	_shoulder_k = lerpf(_shoulder_k, k_want, 1.0 - exp(-(9.0 if k_want < _shoulder_k else 2.5) * delta))
	_arm.position.x = SHOULDER * _shoulder_k


## Jumping at a ledge (top 0.3-1.7 m above the feet) while pushing toward it vaults onto it.
func _try_mantle(wish: Vector3) -> bool:
	if not is_on_wall() or velocity.y > 3.5 or _sliding:
		return false
	var dir := Vector3(wish.x, 0.0, wish.z).normalized()
	var wall_n := get_wall_normal()
	if wall_n.dot(-dir) < 0.5:
		return false
	var space := get_world_3d().direct_space_state
	var probe_top := global_position + dir * 0.6 + Vector3.UP * (MANTLE_MAX + 0.4)
	var q := PhysicsRayQueryParameters3D.create(probe_top, probe_top + Vector3.DOWN * (MANTLE_MAX + 0.1), collision_mask, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.75:
		return false
	var top: Vector3 = hit.position
	# the ledge must be deep enough to stand on (no vaulting onto railings over the lava)
	var deep := top + dir * 0.75 + Vector3.UP * 0.5
	var q2 := PhysicsRayQueryParameters3D.create(deep, deep + Vector3.DOWN * 0.8, collision_mask, [get_rid()])
	var hit2 := space.intersect_ray(q2)
	if hit2.is_empty() or absf((hit2.position as Vector3).y - top.y) > 0.2:
		return false
	var rise := top.y - global_position.y
	if rise < 0.3 or rise > MANTLE_MAX:
		return false
	var dest := top + Vector3.UP * 0.05 + dir * 0.15
	var land := Transform3D(global_basis, dest)
	if test_move(land, Vector3.UP * 0.05):
		return false                               # no room to stand up there
	# head clearance on the way up, tested a little off the wall (touching it counts as a hit)
	var off_wall := global_transform.translated(Vector3(wall_n.x, 0.0, wall_n.z).normalized() * 0.06)
	if test_move(off_wall, Vector3.UP * (rise + 0.1)):
		return false
	_mantle_from = global_position
	_mantle_to = dest
	_mantle_t = 0.0
	velocity = Vector3.ZERO
	_visual.play_move(&"mantle", MANTLE_TIME * 1.5)
	Sfx.play(SFX_JUMP, global_position, -8.0, 0.85)
	kick(0.15)
	return true


func _tick_mantle(delta: float) -> void:
	_mantle_t += delta
	var u := clampf(_mantle_t / MANTLE_TIME, 0.0, 1.0)
	# up first, then over: the rise leads the forward move
	var up_u := 1.0 - pow(1.0 - minf(u * 1.4, 1.0), 2.0)
	var fwd_u := smoothstep(0.25, 1.0, u)
	var p := Vector3(lerpf(_mantle_from.x, _mantle_to.x, fwd_u), lerpf(_mantle_from.y, _mantle_to.y, up_u), lerpf(_mantle_from.z, _mantle_to.z, fwd_u))
	# the view takes the pull-up over ~0.4 s instead of 0.24: part of each tick's rise goes into the
	# camera's eased offset (r29)
	_cam_off.y -= maxf(p.y - global_position.y, 0.0) * 0.6
	global_position = p
	_animate(delta, Vector3.ZERO)
	_update_gloom(delta)
	if u >= 1.0:
		_mantle_t = -1.0
		var dir := Vector3(_mantle_to.x - _mantle_from.x, 0.0, _mantle_to.z - _mantle_from.z).normalized()
		velocity = dir * walk_speed
		_air_jumps_left = air_jumps


# --- component forwarding (public surface kept on Player) -----------------------------------

func _ap() -> PlayerAutopilot:
	if autopilot_ctl == null:
		autopilot_ctl = PlayerAutopilot.new(self)
		add_child(autopilot_ctl)
	return autopilot_ctl

func start_autopilot(markers: Array[Marker3D]) -> void: _ap().start_autopilot(markers)
