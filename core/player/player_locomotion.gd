class_name PlayerLocomotion
extends Node
## Move feel: ground accel, jump, double jump, slide, landing, step-up and step-down, teleport.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

const StaffSfx := preload("res://core/vfx/staff_sfx.gd")

var _slide_t := 0.0
var _slide_speed := 0.0
var _slide_air := 0.0
var _tall_q: PhysicsShapeQueryParameters3D


func _init(p: Player) -> void:
	player = p


# --- Movement: double jump, slide ----------------------------------------------------------

func _setup_movement_fx() -> void:
	player._slide_fx = Vfx.emitter(Color(0.55, 0.5, 0.7, 0.55), {"count": 40, "life": 0.5, "speed": Vector2(0.5, 2.0), "size": 0.18, "gravity": -1.0, "dir": Vector3.UP, "spread": 60.0, "additive": false, "radius": 0.2})
	player.add_child(player._slide_fx)
	var sparks := Vfx.emitter(Color(1.6, 0.9, 2.4), {"count": 24, "life": 0.25, "speed": Vector2(2.0, 4.0), "size": 0.03, "gravity": -8.0, "dir": Vector3.UP, "spread": 70.0, "trail": 0.05})
	sparks.name = "Sparks"
	player._slide_fx.add_child(sparks)
	player._slide_sfx = AudioStreamPlayer3D.new()
	player._slide_sfx.bus = &"SFX"
	var scrape := Sfx.stream("res://art/audio/slide_scrape.wav")
	if scrape is AudioStreamWAV:
		var w := (scrape as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
		scrape = w
	player._slide_sfx.stream = scrape
	player._slide_sfx.volume_db = -8.0
	player.add_child(player._slide_sfx)
	player._charge_fx = Vfx.emitter(Color(2.4, 0.8, 0.25), {"count": 40, "life": 0.45, "speed": Vector2(0.0, 0.3), "size": 0.045, "gravity": 0.6, "radius": 0.75, "radial": -9.0, "swirl": 4.0, "damping": 0.5, "trail": 0.08})
	player._charge_fx.top_level = true
	player.add_child(player._charge_fx)
	# the Lance gathering at the staff head: an ember orb that swells with the charge, with its light
	player._charge_orb = MeshInstance3D.new()
	player._charge_orb.name = "ChargeOrb"
	var orb := SphereMesh.new()
	orb.radius = 0.5
	orb.height = 1.0
	orb.radial_segments = 16
	orb.rings = 8
	player._charge_orb.mesh = orb
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.albedo_color = Color(3.2, 1.3, 0.45)
	player._charge_orb.material_override = om
	player._charge_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player._charge_orb.top_level = true
	player._charge_orb.visible = false
	player.add_child(player._charge_orb)
	player._charge_halo = MeshInstance3D.new()
	player._charge_halo.name = "ChargeHalo"
	player._charge_halo.mesh = orb
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(1.6, 0.5, 0.15, 0.35)
	hm.cull_mode = BaseMaterial3D.CULL_FRONT
	player._charge_halo.material_override = hm
	player._charge_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player._charge_halo.top_level = true
	player._charge_halo.visible = false
	player.add_child(player._charge_halo)
	player._charge_light = OmniLight3D.new()
	player._charge_light.light_color = Color(1.0, 0.5, 0.2)
	player._charge_light.shadow_enabled = false
	player._charge_light.top_level = true
	player._charge_light.visible = false
	player._charge_light.set_meta("light_class", "player_orb")
	player.add_child(player._charge_light)
	player._charge_sfx = AudioStreamPlayer3D.new()
	player._charge_sfx.bus = &"SFX"
	var charge: AudioStream = StaffSfx.stream("lance_charge")   # seamless synthesised loop
	if charge == null:
		charge = Sfx.stream("res://art/audio/lance_charge.wav")
	if charge is AudioStreamWAV and (charge as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var c := (charge as AudioStreamWAV).duplicate() as AudioStreamWAV
		c.loop_mode = AudioStreamWAV.LOOP_FORWARD
		c.loop_begin = int(0.6 * float(c.mix_rate))
		c.loop_end = int(c.get_length() * float(c.mix_rate))
		charge = c
	player._charge_sfx.stream = charge
	player._charge_sfx.volume_db = -7.0
	player.add_child(player._charge_sfx)


func _air_jump(wish: Vector3, sprint: bool) -> void:
	player._air_jumps_left -= 1
	player.velocity.y = player.air_jump_velocity
	player._jump_rising = true
	if wish.length_squared() > 0.01:
		# the second jump re-aims: lets you correct a bad first jump or chase a pouncer down
		var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
		var speed := maxf(flat.length(), player.sprint_speed if sprint else player.walk_speed)
		var aimed := flat.lerp(wish.normalized() * speed, 0.7)
		player.velocity.x = aimed.x
		player.velocity.z = aimed.z
	player._visual.air_tuck()
	var feet := player.global_position + Vector3.UP * 0.1
	Vfx.ring(feet, 1.1, Color(1.2, 0.55, 2.8), 0.32, 0.12)
	Vfx.burst(feet, Color(1.4, 0.65, 3.0), {"count": 24, "life": 0.4, "speed": Vector2(1.5, 3.5), "size": 0.04, "dir": Vector3.DOWN, "spread": 70.0, "gravity": 0.0, "trail": 0.06})
	Vfx.burst(feet, Color(0.04, 0.02, 0.08, 0.6), {"count": 10, "life": 0.6, "speed": Vector2(0.5, 1.2), "size": 0.3, "dir": Vector3.DOWN, "spread": 80.0, "gravity": 0.3, "additive": false})
	Sfx.play(Player.SFX_JUMP, feet, -5.0)


## Held slide key: on the ground it slides once per press (and keeps trying until fast enough,
## which doubles as an input buffer through the cooldown); in the air it crouches and queues,
## and the landing drops straight into a slide that banks part of the fall speed.

func _slide_input(horiz: Vector3, wish: Vector3) -> void:
	if not Input.is_action_pressed("slide"):
		return
	if not player._grounded:
		if player._gliding:
			player.evasion._end_glide()                         # r31: dive out of the glide
			player.velocity.y = minf(player.velocity.y, -6.0)
		player._slide_queued = true
		player._visual.hold_tuck(0.6)
		return
	if player._slide_queued:
		player._slide_queued = false
		player._slide_latch = true
		_try_slide(horiz, wish, player.slide_land_min, player.slide_land_gain * maxf(0.0, -player._air_vy))
	elif Settings.using_pad and is_instance_valid(player._lock) and wish.length_squared() < 0.04:
		pass                                     # r31: pad, locked on, stick idle: B is the guard (StaffArts)
	elif Input.is_action_just_pressed("slide") and (is_instance_valid(player._lock) and not Input.is_action_pressed("sprint") \
			or horiz.length() < player.slide_min_speed and wish.length_squared() > 0.04):
		player._slide_latch = true                      # slow, or squared up to a foe: the slide key rolls
		player.evasion._try_dodge(wish)
	elif not player._slide_latch and _try_slide(horiz, wish, player.slide_min_speed, 0.0):
		player._slide_latch = true


func _try_slide(horiz: Vector3, wish: Vector3, min_speed: float, bonus: float) -> bool:
	var speed := horiz.length()
	if player._slide_cd > 0.0 or not player._grounded or speed < min_speed:
		return false
	player._sliding = true
	_slide_t = 0.0
	_slide_air = 0.0
	player._evade_t = maxf(player._evade_t, Player.SLIDE_EVADE)     # r30: the slide's start passes under a strike (no riposte)
	player._evade_roll = true
	player._slide_dir = (horiz if speed > 0.1 else wish).normalized()
	_slide_speed = maxf(speed * player.slide_boost, player.sprint_speed * 1.15) + bonus
	_set_capsule(1.0)
	player._slide_fx.emitting = true
	(player._slide_fx.get_node("Sparks") as GPUParticles3D).emitting = true
	player._slide_sfx.play()
	player._fov_burst_want = maxf(player._fov_burst_want, 8.0)
	player.camera_ctl.kick(0.3 + minf(bonus * 0.05, 0.3))
	return true


func _tick_slide(delta: float, wish: Vector3) -> Vector3:
	_slide_t += delta
	player._slide_blend = move_toward(player._slide_blend, 1.0, delta * 8.0)
	var downhill := 0.0
	if player._grounded:
		_slide_air = 0.0
		var n := player.get_floor_normal()
		var down := Vector3(n.x, 0.0, n.z)            # horizontal part of the normal points downhill
		downhill = down.dot(player._slide_dir)
		_slide_speed += downhill * player.slide_slope_gain * delta
	else:
		_slide_air += delta
	_slide_speed = maxf(0.0, _slide_speed - player.slide_friction * delta * (1.0 - clampf(downhill * 3.0, 0.0, 0.9)))
	if wish.length_squared() > 0.01:
		var w := wish.normalized()
		var turn := clampf(player._slide_dir.signed_angle_to(w, Vector3.UP), -3.2 * delta, 3.2 * delta)
		player._slide_dir = player._slide_dir.rotated(Vector3.UP, turn)
		_slide_speed *= 1.0 - 0.15 * absf(turn) / (PI * 0.5)       # a hard turn costs about 15 % per 90 degrees
	var horiz := player._slide_dir * _slide_speed
	player.velocity.x = horiz.x
	player.velocity.z = horiz.z
	player._slide_fx.global_position = player.global_position + Vector3.UP * 0.05
	player._slide_sfx.pitch_scale = 0.7 + 0.06 * _slide_speed
	var limit := player.slide_max_time + maxf(0.0, downhill) * 3.0
	var held := Input.is_action_pressed("slide") or _slide_t < 0.3
	if _slide_speed < 2.4 or _slide_t > limit or _slide_air > 0.35 or not held:
		if player._grounded and not _headroom():
			_end_slide()
			_set_capsule(1.1)                     # slid under something: stay low, crawl out (see _tick_roll)
			player._roll_t = Player.ROLL_TIME * 0.98
			player._roll_len = Player.ROLL_TIME
			player._roll_dir = player._slide_dir
			player._roll_evade = false
			player._crawl = true
			player._visual.play_move(&"roll", Player.ROLL_TIME)
		else:
			_end_slide()
	return horiz


func _end_slide() -> void:
	if not player._sliding:
		return
	player._sliding = false
	player._slide_cd = player.slide_cooldown
	_set_capsule(player._col_h)
	player._slide_fx.emitting = false
	(player._slide_fx.get_node("Sparks") as GPUParticles3D).emitting = false
	player._slide_sfx.stop()


func _set_capsule(h: float) -> void:
	if player._col == null or not (player._col.shape is CapsuleShape3D):
		return
	var cap := player._col.shape as CapsuleShape3D
	cap.height = maxf(h, cap.radius * 2.0)
	player._col.position.y = player._col_y - (player._col_h - cap.height) * 0.5


## On the ground this frame, including being held down a stair edge (_step_down).

func is_grounded() -> bool:
	return player._grounded


func is_sliding() -> bool:
	return player._sliding


## The skin's glide after a position snap (hang, step-up), for ticks that skip the main path.

func _ease_tick(delta: float) -> void:
	player.camera_ctl._spring3(false, 22.0, delta)
	player._visual.position = player.global_basis.inverse() * player._vis_off


func _ray(a: Vector3, b: Vector3, mask := Layers.WORLD) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, mask, [player.get_rid()]))


## The capsule would stand at `pos` without touching anything.

func _fits(pos: Vector3) -> bool:
	if player._col == null:
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = player._col.shape
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * player._col_y)
	q.collision_mask = player.collision_mask
	q.exclude = [player.get_rid()]
	q.margin = 0.0
	return player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Room to stand at the body's spot: the full capsule, a little thinner and lifted off the floor so
## a wall it leans on or the ground under it doesn't count (test_move from a touching start does).

func _headroom(at := Vector3.INF) -> bool:
	if player._col == null or not (player._col.shape is CapsuleShape3D):
		return true
	var space := player.get_world_3d().direct_space_state
	if space == null:
		return true
	if _tall_q == null:
		var cap := CapsuleShape3D.new()
		cap.radius = (player._col.shape as CapsuleShape3D).radius - 0.04
		cap.height = maxf(player._col_h - 0.08, cap.radius * 2.0 + 0.01)
		_tall_q = PhysicsShapeQueryParameters3D.new()
		_tall_q.shape = cap
		_tall_q.exclude = [player.get_rid()]
		_tall_q.margin = 0.0
	_tall_q.collision_mask = player.collision_mask
	var p := player.global_position if at == Vector3.INF else at
	_tall_q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (player._col_h * 0.5 + 0.04))
	return space.intersect_shape(_tall_q, 1).is_empty()


# --- movement feel: step-up and mantle -----------------------------------------------------------

## Walk straight up small ledges (stair risers, kerbs, plinth edges) instead of stopping dead.
## Test: blocked at foot level, clear STEP_MAX higher, ground found just ahead within the step.

func _try_step_up(horiz: Vector3, delta: float) -> bool:
	if horiz.length() < 0.6 or not player.is_on_wall() or player._sliding:
		return false
	var dir := horiz.normalized()
	var wall_n := player.get_wall_normal()
	var flat_n := Vector3(wall_n.x, 0.0, wall_n.z)
	# a capsule meets a step's edge with its rounded bottom, so the contact normal tilts up:
	# judge the contact by its horizontal direction only
	if flat_n.length() < 0.2 or flat_n.normalized().dot(-dir) < 0.35:
		return false                               # glancing contact
	var lift := Vector3.UP * Player.STEP_MAX
	var probe := dir * 0.38                         # a capsule radius ahead: land on the step, not its edge
	var fwd := dir * maxf(horiz.length() * delta, 0.06)
	if player.test_move(player.global_transform, lift):
		return false                               # no headroom
	var up := player.global_transform.translated(lift)
	if player.test_move(up, probe):
		return false                               # still blocked higher: a real wall
	var col := KinematicCollision3D.new()
	if not player.test_move(up.translated(probe), -lift, col):
		return false
	if col.get_normal().y < 0.7:
		return false
	var rise := Player.STEP_MAX - col.get_travel().length()
	if rise < 0.03:
		return false
	player.global_position += Vector3.UP * (rise + 0.01) + fwd
	# stand on the tread, not balanced on its nose (a capsule's round bottom slides back off it)
	var extra := Vector3.ZERO
	var below := KinematicCollision3D.new()
	for k in 5:
		if player.test_move(player.global_transform.translated(extra), Vector3.DOWN * 0.1, below) and below.get_normal().y >= 0.75:
			break
		if player.test_move(player.global_transform.translated(extra), dir * 0.06):
			break
		extra += dir * 0.06
	player.global_position += extra
	player.velocity.y = 0.0
	_ease_shift(Vector3.UP * (rise + 0.01) + extra)   # body pops up; the skin and camera glide after it
	player._visual.step_bump(rise)
	return true


## Moved from outside (global_position set by a test, a respawn, a lava throw): drop the smoothing
## state so the skin and the camera don't glide across the jump, and re-test the ground.

func _on_teleported() -> void:
	player._vis_off = Vector3.ZERO
	player._vis_off_v = Vector3.ZERO
	player._cam_off = Vector3.ZERO
	player._cam_off_v = Vector3.ZERO
	player._cam_off_prev = Vector3.ZERO
	player._glued = false
	player._grounded = player.is_on_floor()
	player._land_slow = 0.0
	player.traversal._end_traverse()
	player._air_base = player.global_position.y
	player._cam_air = 0.0
	player._cam_air_prev = 0.0


## Teleport helper: same as setting global_position, plus no interpolation streak.

func teleport(pos: Vector3, keep_velocity := false) -> void:
	player.global_position = pos
	if not keep_velocity:
		player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	_on_teleported()
	player._last_pos = pos


## Shift the body by `d` without the skin or the view jumping: both ease after it.

func _ease_shift(d: Vector3) -> void:
	player._vis_off -= d
	player._cam_off -= d


## Walking off a small drop (a stair going down, a kerb): settle straight onto the lower ground
## instead of a little fall each tread. The shape cast stops on a stair nose too (the capsule's
## round bottom rolls off it smoothly frame by frame). Real drops (> STEP_DOWN) fall as before.

func _step_down() -> void:
	if player._mantle_t >= 0.0 or player._hollowing:
		return
	# real floor under the middle of the body, not just a corner beside it
	var space := player.get_world_3d().direct_space_state
	var c := player.global_position + Vector3.UP * 0.3
	var ray := PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * (Player.STEP_DOWN + 0.32), player.collision_mask, [player.get_rid()])
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.69:
		return
	var col := KinematicCollision3D.new()
	if not player.test_move(player.global_transform, Vector3.DOWN * Player.STEP_DOWN, col):
		return
	if col.get_normal().y < 0.3:
		return                                     # a wall, not ground
	var drop := col.get_travel()
	player.global_position += drop
	player.velocity.y = 0.0
	player._grounded = true
	player._glued = true
	_ease_shift(drop)


## Ground speed model. The run turns toward the stick at a speed-dependent rate (no speed lost
## mid-turn, unlike a straight lerp), a hard reversal skids to a stop first, speeding up is quick
## to a walk and builds to a sprint, and stopping is exponential plus a constant bite.

func _ground_move(cur: Vector3, target: Vector3, delta: float) -> Vector3:
	var speed := cur.length()
	var want := target.length()
	if want < 0.01:
		var s := maxf(0.0, (speed + player.decel_bite / player.decel) * exp(-player.decel * delta) - player.decel_bite / player.decel)
		return cur.normalized() * s if speed > 0.0001 else Vector3.ZERO
	var tdir := target / want
	var dir := tdir
	if speed > 0.3:
		dir = cur / speed
		var ang := dir.signed_angle_to(tdir, Vector3.UP)
		if absf(ang) > player.skid_angle:
			# reversal: brake along the old line, then turn on the spot once slow
			var s := maxf(0.0, (speed + player.decel_bite / player.decel) * exp(-player.decel * 1.3 * delta) - player.decel_bite / player.decel)
			return dir * s
		var rate := lerpf(player.turn_rate, player.turn_rate_sprint, player._run_blend)
		dir = dir.rotated(Vector3.UP, clampf(ang, -rate * delta, rate * delta))
		speed *= lerpf(1.0, maxf(0.0, dir.dot(tdir)), 1.0 - exp(-4.0 * delta))   # cornering bleeds a little
	elif speed > 0.0001:
		speed *= maxf(0.0, (cur / speed).dot(tdir))   # slow: face the stick at once, keep what points that way
	var r := player.accel
	if speed > want:
		r = player.coast
	elif speed > player.walk_speed * 0.98:
		r = player.sprint_accel
	speed = lerpf(speed, want, 1.0 - exp(-r * delta))
	return dir * speed


## Uphill is slower, downhill a touch quicker (on top of floor_constant_speed).

func _slope_scale(target: Vector3) -> float:
	if target.length_squared() < 0.0001 or not player.is_on_floor():
		return 1.0
	var n := player.get_floor_normal()
	var grade := -Vector2(n.x, n.z).dot(Vector2(target.x, target.z).normalized())   # + uphill
	return 1.0 - Player.SLOPE_UPHILL_SLOW * maxf(grade, 0.0) + Player.SLOPE_DOWNHILL_GAIN * maxf(-grade, 0.0)


## Landing weight: hard landings cost speed for a moment, kick up dust and dip the view.

func _land(was_grounded: bool, vy_before: float) -> void:
	if not player._grounded or was_grounded:
		return
	var impact := -vy_before
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if impact > Player.ROLL_LAND_V and not player._sliding and player._roll_t < 0.0 and (flat.length() > 2.5 or Input.is_action_pressed("dodge")):
		player.evasion._land_roll(flat.normalized() if flat.length() > 0.1 else -player._visual.global_basis.z, flat.length())
		player.camera_ctl.kick(0.3)                                # rolled out: no speed lost
	elif impact > Player.LAND_SLOW_V:
		player._land_slow = clampf((impact - Player.LAND_SLOW_V) / 10.0, 0.0, 0.5 if impact < Player.ROLL_LAND_V else 0.75)
	player.vitals._fall_hurt(impact)
	if impact > 5.0:
		var k := clampf((impact - 5.0) / 8.0, 0.0, 1.0)
		Vfx.burst(player.global_position + Vector3.UP * 0.05, Color(0.16, 0.15, 0.17, 0.55), {"count": 14, "life": 0.6, "speed": Vector2(0.6, 1.8), "size": 0.22, "gravity": -0.4, "dir": Vector3.UP, "spread": 85.0, "additive": false, "radius": 0.3})
		if k > 0.4:
			player.camera_ctl.kick(0.15 + 0.35 * k)
