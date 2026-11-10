class_name PlayerEvasion
extends Node
## Dodge roll, Rift Step, the cloak-glide, updrafts and the Tether pull hooks.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

const Hints := preload("res://ui/hints.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Stamina := preload("res://core/player/stamina.gd")

var _glide_dir := Vector3.FORWARD
var _glide_speed := 0.0
var _roll_speed := 0.0
var _evade_set := false                ## the roll's i-frame window has been stamped
var _unseen := false                  ## Rift Step: the body stays hidden until the evade grace ends
const MARK_REACH := 1.2               ## a foe this close to the step's line is marked


func _init(p: Player) -> void:
	player = p


func is_gliding() -> bool:
	return player._gliding


func _can_glide() -> bool:
	if player._grounded or player._hang or player._sliding or player._roll_t >= 0.0 or player._hollowing or player._gliding:
		return false
	if player._stam != null and not player._stam.can(Stamina.GLIDE):
		return false
	return player.locomotion._ray(player.global_position + Vector3.UP * 0.1, player.global_position + Vector3.DOWN * Player.GLIDE_MIN_H).is_empty()


func _start_glide() -> void:
	player._gliding = true
	player.glides += 1
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	_glide_dir = flat.normalized() if flat.length() > 0.5 else -player._visual.global_basis.z
	_glide_dir.y = 0.0
	_glide_dir = _glide_dir.normalized()
	_glide_speed = maxf(flat.length(), 5.5)
	player._jump_rising = false
	if player._arts != null:       # the fall eases into the sink (Player tick), it is not set in one frame
		player._arts.cancel()
	StaffSfx.play("swish", player.global_position + Vector3.UP * 1.2, -6.0, 0.6)
	Vfx.burst(player.global_position + Vector3.UP * 1.0, Color(0.05, 0.03, 0.09, 0.55), {"count": 12, "life": 0.6, "speed": Vector2(0.5, 1.5), "size": 0.3, "gravity": 0.4, "additive": false, "radius": 0.5})
	Hints.once(&"glide", "Gliding on the robe: steer with the stick; jump folds it, slide dives. It spends Breath. Lit fires lift you.")


func _end_glide() -> void:
	player._gliding = false


func _tick_glide(delta: float, wish: Vector3) -> Vector3:
	if player._stam != null:
		player._stam.holding = true
		player._stam.drain(Stamina.GLIDE * delta)
		if player._stam.winded:
			_end_glide()
			return _glide_dir * _glide_speed * 0.6
	var want := _glide_dir
	if wish.length_squared() > 0.04:
		want = Vector3(wish.x, 0.0, wish.z).normalized()
	var a := atan2(_glide_dir.x, _glide_dir.z)
	var b := atan2(want.x, want.z)
	var turn := clampf(angle_difference(a, b), -Player.GLIDE_TURN * delta, Player.GLIDE_TURN * delta)
	_glide_dir = Vector3(sin(a + turn), 0.0, cos(a + turn))
	var top := Player.GLIDE_SPEED + (1.5 if wish.length_squared() > 0.04 and want.dot(_glide_dir) > 0.7 else 0.0)
	_glide_speed = move_toward(_glide_speed, top, 4.0 * delta)
	return _glide_dir * _glide_speed


## Rising air under a glide: any node in the "updraft" group (meta "radius" 3 m, "height" 16 m,
## "lift" 6 m/s), and every lit fire (a brazier's breath: 2.4 m round, 12 m high).

func _updraft(at: Vector3) -> float:
	var best := 0.0
	for n in player.get_tree().get_nodes_in_group("updraft"):
		var u := n as Node3D
		if u == null:
			continue
		var r := float(u.get_meta("radius", 3.0))
		var h := float(u.get_meta("height", 16.0))
		var d := Vector2(at.x - u.global_position.x, at.z - u.global_position.z).length()
		if d < r and at.y > u.global_position.y - 1.0 and at.y < u.global_position.y + h:
			best = maxf(best, float(u.get_meta("lift", 6.0)))
	for n in player.get_tree().get_nodes_in_group(Groups.BRAZIER):
		var fire := n as Node3D
		if fire == null or not bool(fire.get("lit")):
			continue
		var d := Vector2(at.x - fire.global_position.x, at.z - fire.global_position.z).length()
		if d < 2.4 and at.y > fire.global_position.y and at.y < fire.global_position.y + 12.0:
			best = maxf(best, 5.0)
	return best


func _grapple_begin() -> void:
	_end_glide()
	player.locomotion._end_slide()
	if player._arts != null:
		player._arts.cancel()
	if player._roll_t >= 0.0:
		player._roll_t = -1.0
		player.locomotion._set_capsule(player._col_h)
	player._hang = false
	player._climb_t = -1.0
	player._vault_t = -1.0
	player._visual.hang = 0.0
	player._grounded = false


func _grapple_end() -> void:
	player._air_jumps_left = player.air_jumps                 # a haul refreshes the air jump: anchor, jump, glide
	player._jump_rising = false
	player._grounded = false


func is_evading() -> bool:
	return player._evade_t > 0.0 or (player._arts != null and player._arts.parrying())


func can_shadowstep() -> bool:
	return not player._hollowing and player._step_t <= 0.0


## Rift Step: tear out here, tear in up to `step_range` metres along the move direction (camera
## forward with no input). A capsule sweep stops it short of walls; the far end settles onto
## whatever ground is within 3 m below, so stairs and slopes land cleanly and a gap is crossed
## in the air. Vertical speed is cancelled, so a mid-air step is also a brief hang.

func shadowstep() -> bool:
	if not can_shadowstep():
		return false
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Basis(Vector3.UP, player._yaw) * Vector3(v.x, 0.0, v.y)
	if dir.length_squared() < 0.04:
		dir = Basis(Vector3.UP, player._yaw) * Vector3.FORWARD
	dir = dir.normalized()
	player.locomotion._end_slide()
	player._evade_roll = false
	var from := player.global_position
	var to := _rift_target(dir)
	if Vector2(to.x - from.x, to.z - from.z).length() < 0.8:
		return false                          # nose to a wall: refuse rather than burn the cooldown
	SpellFx.rift_out(from)
	player.global_position = to
	player.reset_physics_interpolation()
	player._tp_offset += from - to                   # camera swoops across the gap instead of hard-cutting
	SpellFx.rift_seam(from, to)
	_corridor(from, to)
	SpellFx.rift_in(to)
	var keep := maxf(Vector2(player.velocity.x, player.velocity.z).length(), player.sprint_speed * 0.9)   # keep the run going
	player.velocity = Vector3(dir.x, 0.0, dir.z) * keep
	player._step_t = player.step_reveal
	player._evade_t = player.step_evade
	player._visual.visible = false
	_unseen = true
	player._visual.rotation.y = atan2(-dir.x, -dir.z)
	_mark_path(from, to)
	player._last_pos = to                            # our own move (the camera swoops via _tp_offset), not a teleport
	Sfx.play(Player.SFX_STEP, from, -6.0)
	Sfx.play(Player.SFX_STEP, to, -2.0)
	player._fov_burst_want = maxf(player._fov_burst_want, 12.0)
	player.camera_ctl.kick(0.25)
	return true


func _rift_target(dir: Vector3) -> Vector3:
	var from := player.global_position
	var space := player.get_world_3d().direct_space_state
	if space == null or player._col == null:
		return from + dir * player.step_range
	var lift := Vector3.UP * 0.5              # clear stair risers and small lips
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = player._col.shape
	q.transform = Transform3D(player._col.global_basis, player._col.global_position + lift)
	q.motion = dir * player.step_range
	q.collision_mask = player.collision_mask
	q.exclude = [player.get_rid()]
	q.margin = 0.04
	var frac: PackedFloat32Array = space.cast_motion(q)
	var safe: float = frac[0] if frac.size() > 0 else 1.0
	var dest := from + lift + dir * player.step_range * safe
	var r := PhysicsRayQueryParameters3D.create(dest + Vector3.UP * 0.4, dest + Vector3.DOWN * 3.0, player.collision_mask, [player.get_rid()])
	var hit := space.intersect_ray(r)
	if not hit.is_empty():
		dest = (hit.position as Vector3) + Vector3.UP * 0.02
	return dest


## The violet that marks: the same 1.2 m to either side that _mark_path uses.
func _corridor(from: Vector3, to: Vector3) -> void:
	var pts := PackedVector3Array()
	for i in 12:
		pts.append((from + Vector3.UP).lerp(to + Vector3.UP, float(i) / 11.0))
	Vfx.ribbon(pts, MARK_REACH * 2.0, MARK_REACH * 2.0, Color(0.6, 0.3, 1.6, 0.22), 0.35)


func _mark_path(from: Vector3, to: Vector3) -> void:
	var a := from + Vector3.UP
	var b := to + Vector3.UP
	for node in player.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var c := e.global_position + Vector3.UP * 0.9
		if c.distance_to(Geometry3D.get_closest_point_to_segment(c, a, b)) < MARK_REACH:
			e.add_mark(1)
			Vfx.burst(c, SpellFx.VIOLET_HOT, {"count": 16, "life": 0.35, "speed": Vector2(2.0, 4.5), "size": 0.04, "gravity": -3.0, "trail": 0.06})


## The body stays unseen for `step_reveal` at the far end, then re-forms out of the tear.

func _tick_step(delta: float) -> void:
	player._step_t -= delta
	if player._step_t <= 0.0:
		player._step_t = 0.0
		_tick_unseen()
	player._tick_always(delta)


## The body re-forms when the grace (step_evade) ends, not before: it is not hittable-looking while
## blows still miss.
func _tick_unseen() -> void:
	if _unseen and player._evade_t <= 0.0 and player._step_t <= 0.0:
		_unseen = false
		player._visual.visible = true
		_step_burst()


func _step_burst() -> void:
	var at := player.global_position + Vector3.UP * 1.0
	Vfx.burst(at, Color(0.02, 0.01, 0.04, 0.85), {"count": 18, "life": 0.7, "speed": Vector2(0.4, 1.6), "size": 0.45, "gravity": 0.6, "radius": 0.35, "additive": false, "turbulence": true})
	Vfx.burst(at, Player.VIOLET, {"count": 22, "life": 0.45, "speed": Vector2(1.5, 3.5), "size": 0.04, "gravity": 0.0, "radius": 0.3, "trail": 0.07})


func is_rolling() -> bool:
	return player._roll_t >= 0.0


# --- dodge roll ----------------------------------------------------------------------------------------

## A tucked roll along the stick (or a backstep with no stick): brief i-frames, keeps the run, no
## cooldown beyond its own length. Distinct from the Rift Step: no riposte, no marks, stays visible.

func _try_dodge(wish: Vector3) -> bool:
	if player._roll_cd > 0.0 or player._roll_t >= 0.0 or not player._grounded or player._hollowing or player.traversal._trav_busy() or player._mantle_t >= 0.0 or player._step_t > 0.0:
		return false
	if player._stam != null and not player._stam.spend(Stamina.HOP if wish.length_squared() < 0.04 else Stamina.ROLL):
		return false                            # r31: no Breath, no roll
	if player._arts != null:
		player._arts.cancel()                          # a roll cancels a strike or a guard
	if player._book != null:
		player._book.cancel_lock()                     # ... and the cast lock, so a spell can follow the roll at once
	player._dodge_roll = true
	_evade_set = false
	player.locomotion._end_slide()
	player._roll_t = 0.0
	player._roll_evade = true
	if wish.length_squared() < 0.04:
		var back := player._visual.global_basis.z
		player._roll_dir = Vector3(back.x, 0.0, back.z).normalized()
		player._roll_len = Player.HOP_TIME
		_roll_speed = 5.6
		player.velocity.y = 2.4
		player._grounded = false
		player._visual.play_move(&"hop", Player.HOP_TIME)
	else:
		player._roll_dir = Vector3(wish.x, 0.0, wish.z).normalized()
		player._roll_len = Player.ROLL_TIME
		_roll_speed = maxf(Player.ROLL_DIST / Player.ROLL_TIME * 1.25, Vector2(player.velocity.x, player.velocity.z).length())
		player._visual.rotation.y = atan2(-player._roll_dir.x, -player._roll_dir.z)
		player._visual.play_move(&"roll", Player.ROLL_TIME)
		player.locomotion._set_capsule(1.1)
	StaffSfx.play("swish", player.global_position + Vector3.UP, -10.0, 0.85)
	EnemyAudio.player("dodge", player.global_position + Vector3.UP, -6.0)
	Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, 7), player.global_position, -8.0, 0.8, 0.03)
	return true


## A hard landing while moving: roll it out (no i-frames, no lost speed).

func _land_roll(dir: Vector3, speed: float) -> void:
	player._dodge_roll = false
	player._rolled_landing = true
	_evade_set = false
	player.locomotion._end_slide()
	player._roll_t = 0.0
	player._roll_evade = false
	player._roll_dir = dir
	player._roll_len = Player.ROLL_TIME
	_roll_speed = maxf(speed, player.walk_speed * 1.2)
	player._visual.rotation.y = atan2(-dir.x, -dir.z)
	player._visual.play_move(&"roll", Player.ROLL_TIME)
	player.locomotion._set_capsule(1.1)


func _tick_roll(delta: float, wish := Vector3.ZERO) -> Vector3:
	player._roll_t += delta
	var u := clampf(player._roll_t / player._roll_len, 0.0, 1.0)
	var evade_end := Player.ROLL_EVADE.y * (player._roll_len / Player.ROLL_TIME)
	if player._roll_evade and not player._crawl and player._roll_t >= Player.ROLL_EVADE.x and player._roll_t <= evade_end:
		if not _evade_set:
			_evade_set = true                           # one window, set once, counting down
			player._evade_t = maxf(player._evade_t, evade_end - player._roll_t)
		player._evade_roll = true
	var spd := _roll_speed * lerpf(1.0, 0.55, u * u)
	if u >= 1.0:
		player._roll_t = -1.0
		player._roll_cd = Player.ROLL_CD
		if player._col and (player._col.shape as CapsuleShape3D).height < player._col_h:
			if player.locomotion._headroom():
				player.locomotion._set_capsule(player._col_h)
				player._crawl = false
			else:
				# under something: stay low and crawl along the stick until there is room to stand.
				# (r29: the old test_move counted a wall the roll ended against as a ceiling, so a roll
				# into any wall froze the wanderer crouched, deaf to the stick, for good.)
				player._roll_t = player._roll_len * 0.98
				player._crawl = true
				var w := Vector3(wish.x, 0.0, wish.z)
				if w.length_squared() < 0.04:
					return Vector3.ZERO
				player._roll_dir = w.normalized()
				return player._roll_dir * Player.CRAWL_SPEED
		return player._roll_dir * minf(spd, player.sprint_speed)
	return player._roll_dir * spd
