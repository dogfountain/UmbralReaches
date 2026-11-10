class_name PlayerTraversal
extends Node
## Ledge hang and climb, vault, wall kick, mantle, steep slopes and beams.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Stamina := preload("res://core/player/stamina.gd")

var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _hang_n := Vector3.ZERO       ## out of the wall, flat
var _hang_top := 0.0
var _hang_t := 0.0
var _hang_push := 0.0
var _hang_jump_buf := false
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _climb_len := Player.CLIMB_TIME
var _vault_len := 0.42
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO
var _vault_apex := 0.0
var _vault_v := Vector3.ZERO
var _beam_frame := 0


func _init(p: Player) -> void:
	player = p


func is_hanging() -> bool:
	return player._hang


func _trav_busy() -> bool:
	return player._hang or player._climb_t >= 0.0 or player._vault_t >= 0.0 or player._roll_t >= 0.0


## Drop every traversal state (teleports, respawns, lava).

func _end_traverse() -> void:
	player.evasion._end_glide()
	if player._grapple != null:
		player._grapple.cancel()
	player._hang = false
	player._climb_t = -1.0
	player._vault_t = -1.0
	player._mantle_t = -1.0                          # r29: a lava throw mid-mantle was dragged back by the mantle tick
	player._kick_lock = 0.0
	player.locomotion._end_slide()
	if player._roll_t >= 0.0:
		player._roll_t = -1.0
		player.locomotion._set_capsule(player._col_h)
	player._crawl = false
	player._steep_t = 0.0
	player._beam_on = false
	if player._step_t > 0.0:                         # moved during a Rift Step's reveal: show the body now
		player._step_t = 0.0
		player._visual.visible = true
	player._visual.hang = 0.0
	if player._visual.has_method("cancel_move"):
		player._visual.cancel_move()


# --- ledge hang and climb ---------------------------------------------------------------------------

## In the air, against a wall whose top is above mantle height but within the hands' reach: catch it.

func _try_grab(wish: Vector3) -> bool:
	if player._regrab > 0.0 or player.velocity.y > 1.5 or player._sliding or player._hollowing or player._roll_t >= 0.0:
		return false
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var dir := Vector3.ZERO
	if wish.length_squared() > 0.04:
		dir = Vector3(wish.x, 0.0, wish.z).normalized()
	elif flat.length() > 1.0:
		dir = flat.normalized()
	else:
		return false
	var chest := player.global_position + Vector3.UP * 1.3
	var hit := player.locomotion._ray(chest, chest + dir * 0.8)
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	var nf := Vector3(n.x, 0.0, n.z)
	if absf(n.y) > 0.35 or nf.length() < 0.3 or nf.normalized().dot(-dir) < 0.5:
		return false
	nf = nf.normalized()
	var face: Vector3 = hit.position
	var over := face - nf * 0.22
	var top_hit := player.locomotion._ray(Vector3(over.x, player.global_position.y + Player.GRAB_MAX + 0.4, over.z), Vector3(over.x, player.global_position.y + Player.GRAB_MIN - 0.05, over.z))
	if top_hit.is_empty() or (top_hit.normal as Vector3).y < 0.75:
		return false
	var top: float = (top_hit.position as Vector3).y
	var rise := top - player.global_position.y
	if rise < Player.GRAB_MIN or rise > Player.GRAB_MAX:
		return false
	# the face must run right up to the lip (not a sloped bank or a step back)
	var lip := player.locomotion._ray(Vector3(face.x, top - 0.12, face.z) + nf * 0.3, Vector3(face.x, top - 0.12, face.z) - nf * 0.3)
	if lip.is_empty():
		return false
	var lip_p: Vector3 = lip.position
	var hang_pos := Vector3(lip_p.x, top - Player.HANG_DROP, lip_p.z) + nf * Player.WALL_GAP
	if not player.locomotion._fits(hang_pos):
		return false
	_start_hang(hang_pos, nf, top)
	return true


func _start_hang(pos: Vector3, nf: Vector3, top: float) -> void:
	player.locomotion._end_slide()
	player.locomotion._ease_shift(pos - player.global_position)          # the skin and the camera glide into the hang
	player.global_position = pos
	player._visual.position = player.global_basis.inverse() * player._vis_off
	player.velocity = Vector3.ZERO
	player._hang = true
	_hang_n = nf
	_hang_top = top
	_hang_t = 0.0
	_hang_jump_buf = false
	_hang_push = 0.0
	player._grounded = false
	player._jump_rising = false
	player._air_jumps_left = player.air_jumps
	player._kick_n = Vector3.ZERO
	player._visual.rotation.y = atan2(nf.x, nf.z)
	player._visual.hang = 1.0
	Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, 7), pos + Vector3.UP * Player.HANG_DROP, -6.0, 0.8, 0.03)
	StaffSfx.play("tap", pos + Vector3.UP * Player.HANG_DROP, -12.0, 0.85)
	player.camera_ctl.kick(0.2)


func _tick_hang(delta: float, wish: Vector3) -> void:
	player._tick_always(delta)
	_hang_t += delta
	player.velocity = Vector3.ZERO
	var along := _hang_n.cross(Vector3.UP).normalized()
	var lat := wish.dot(along) if wish.length_squared() > 0.04 else 0.0
	var into := wish.dot(-_hang_n) if wish.length_squared() > 0.04 else 0.0
	var ready := _hang_t > 0.18
	if not ready and Input.is_action_just_pressed("jump"):
		_hang_jump_buf = true                        # pressed during the catch: it is not lost
	if ready and (Input.is_action_just_pressed("jump") or _hang_jump_buf):
		_hang_jump_buf = false
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
		var step := along * signf(lat) * Player.SHIMMY * delta
		if _ledge_at(player.global_position + step):
			player.global_position += step
			shimmy = signf(lat)
	player._visual.hang = 1.0
	player._visual.hang_shimmy = lerpf(player._visual.hang_shimmy, -shimmy, 1.0 - exp(-10.0 * delta))
	player.locomotion._ease_tick(delta)
	player.casting._animate(delta, Vector3.ZERO)
	player._cam_air_prev = player._cam_air
	player._cam_air = lerpf(player._cam_air, 0.0, 1.0 - exp(-8.0 * delta))
	player._air_base = player.global_position.y


## Is the ledge still under the hands (and the wall still there) with the body at `pos`?

func _ledge_at(pos: Vector3) -> bool:
	var face := player.locomotion._ray(pos + Vector3.UP * (Player.HANG_DROP - 0.12), pos + Vector3.UP * (Player.HANG_DROP - 0.12) - _hang_n * (Player.WALL_GAP + 0.3))
	if face.is_empty():
		return false
	var over: Vector3 = (face.position as Vector3) - _hang_n * 0.22
	var top := player.locomotion._ray(Vector3(over.x, _hang_top + 0.3, over.z), Vector3(over.x, _hang_top - 0.3, over.z))
	if top.is_empty() or absf((top.position as Vector3).y - _hang_top) > 0.12:
		return false
	return player.locomotion._fits(pos)


func _let_go(push: float) -> void:
	player._hang = false
	player._visual.hang = 0.0
	player._regrab = 0.25
	player.velocity = _hang_n * push + Vector3.DOWN * 1.5
	player._air_base = player.global_position.y


func _hang_kick(wish: Vector3) -> void:
	player._hang = false
	player._visual.hang = 0.0
	player._regrab = 0.3
	var out := _hang_n * Player.KICK_OUT
	if wish.length_squared() > 0.04:
		out = (out + Vector3(wish.x, 0.0, wish.z).normalized() * 2.0).limit_length(Player.KICK_OUT * 1.1)
	player.velocity = Vector3(out.x, Player.KICK_UP * 0.9, out.z)
	player._jump_rising = true
	player._kick_n = _hang_n
	player._kick_lock = 0.22
	player._visual.rotation.y = atan2(-out.x, -out.z)
	player._visual.play_move(&"wallkick", 0.42)
	Sfx.play(Player.SFX_JUMP, player.global_position + Vector3.UP * 1.5, -6.0)


## From the hang up onto the ledge, if there is room to stand up there.

func _try_climb() -> bool:
	# stand well onto the top if it is deep, else on the wall's crown (then it's a balance)
	var stand := Vector3.INF
	for depth: float in [0.42, 0.3, 0.2]:
		var on := Vector3(player.global_position.x, _hang_top, player.global_position.z) - _hang_n * (Player.WALL_GAP + depth)
		var deck := player.locomotion._ray(on + Vector3.UP * 0.4, on + Vector3.DOWN * 0.3)
		if deck.is_empty() or (deck.normal as Vector3).y < 0.7:
			continue
		var at: Vector3 = (deck.position as Vector3) + Vector3.UP * 0.03
		if player.locomotion._fits(at):
			stand = at
			break
	if stand == Vector3.INF:
		return false
	player._hang = false
	player._visual.hang = 0.0
	_climb_from = player.global_position
	_climb_to = stand
	player._climb_t = 0.0
	_climb_len = Player.CLIMB_TIME
	player._visual.play_move(&"climb", Player.CLIMB_TIME)
	Sfx.play(Player.SFX_JUMP, player.global_position + Vector3.UP * 1.6, -9.0, 0.8)
	return true


func _tick_climb(delta: float) -> void:
	player._climb_t += delta
	var u := clampf(player._climb_t / _climb_len, 0.0, 1.0)
	# up first (the pull and the press), then over onto the ledge
	var up_u := smoothstep(0.0, 0.62, u)
	var fwd_u := smoothstep(0.38, 1.0, u)
	player.global_position = Vector3(lerpf(_climb_from.x, _climb_to.x, fwd_u), lerpf(_climb_from.y, _climb_to.y, up_u), lerpf(_climb_from.z, _climb_to.z, fwd_u))
	player.velocity = Vector3.ZERO
	player._visual.rotation.y = lerp_angle(player._visual.rotation.y, atan2(_hang_n.x, _hang_n.z), 1.0 - exp(-12.0 * delta))
	player.locomotion._ease_tick(delta)
	player.casting._animate(delta, Vector3.ZERO)
	player._tick_always(delta)
	player._cam_air_prev = player._cam_air
	player._air_base = player.global_position.y
	if u >= 1.0:
		player._climb_t = -1.0
		player.velocity = -_hang_n * 0.4
		player._grounded = true
		player._regrab = 0.3
		player._air_jumps_left = player.air_jumps


# --- vault -------------------------------------------------------------------------------------------

## Running at a wall between knee and chest height that is thin, with ground beyond: over it in
## one movement, keeping the speed. (Deeper tops are ledges: jump and mantle, or climb.)

func _try_vault(horiz: Vector3, wish: Vector3) -> bool:
	var spd := horiz.length()
	if spd < Player.VAULT_SPEED or wish.length_squared() < 0.25 or not player._grounded or player._hollowing:
		return false
	var dir := horiz / spd
	if Vector3(wish.x, 0.0, wish.z).normalized().dot(dir) < 0.7:
		return false
	var knee := player.global_position + Vector3.UP * 0.32
	var hit := player.locomotion._ray(knee, knee + dir * (0.45 + spd * 0.09))
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	var nf := Vector3(n.x, 0.0, n.z)
	if absf(n.y) > 0.3 or nf.length() < 0.3 or nf.normalized().dot(-dir) < 0.6:
		return false
	var face: Vector3 = hit.position
	var y0 := player.global_position.y
	var over := face + dir * 0.12
	var top_hit := player.locomotion._ray(Vector3(over.x, y0 + Player.VAULT_MAX + 0.3, over.z), Vector3(over.x, y0 + Player.VAULT_MIN - 0.05, over.z))
	if top_hit.is_empty() or (top_hit.normal as Vector3).y < 0.7:
		return false
	var top: float = (top_hit.position as Vector3).y
	var rise := top - y0
	if rise < Player.VAULT_MIN or rise > Player.VAULT_MAX:
		return false
	# how thick: walk along the top until it ends
	var depth := -1.0
	for k in range(1, 12):
		var d := 0.12 + 0.1 * float(k)
		var p := face + dir * d
		var h := player.locomotion._ray(Vector3(p.x, top + 0.3, p.z), Vector3(p.x, top - 0.25, p.z))
		if h.is_empty():
			depth = d - 0.05
			break
	if depth < 0.0 or depth > Player.VAULT_DEPTH:
		return false
	# ground beyond, not far down, and room to land
	var lx := face + dir * (depth + 0.9)
	var land := player.locomotion._ray(Vector3(lx.x, top + 0.3, lx.z), Vector3(lx.x, y0 - 2.4, lx.z))
	if land.is_empty() or (land.normal as Vector3).y < 0.7:
		return false
	var to: Vector3 = (land.position as Vector3) + Vector3.UP * 0.03
	if not player.locomotion._fits(to):
		return false
	var apex := top + 0.14
	if player.test_move(Transform3D(player.global_basis, Vector3(player.global_position.x, apex, player.global_position.z)), Vector3(to.x - player.global_position.x, 0.0, to.z - player.global_position.z)):
		return false                              # something in the way over the top
	player.locomotion._end_slide()
	_vault_from = player.global_position
	_vault_to = to
	_vault_apex = apex
	_vault_v = dir * maxf(spd, player.walk_speed)
	var run := Vector2(to.x - player.global_position.x, to.z - player.global_position.z).length()
	_vault_len = clampf(run / maxf(spd, 4.0), 0.3, 0.55)
	player._vault_t = 0.0
	player.velocity = _vault_v
	var side := 1.0 if (Basis(Vector3.UP, player._yaw) * Vector3.RIGHT).dot(dir) >= 0.0 else -1.0
	player._visual.rotation.y = atan2(-dir.x, -dir.z)
	player._visual.play_move(&"vault", _vault_len, side)
	Sfx.play(Player.SFX_JUMP, player.global_position + Vector3.UP, -8.0, 0.9)
	StaffSfx.play("swish", player.global_position + Vector3.UP * 1.2, -10.0)
	return true


func _tick_vault(delta: float) -> void:
	player._vault_t += delta
	var u := clampf(player._vault_t / _vault_len, 0.0, 1.0)
	var h := Vector3(_vault_from.x, 0.0, _vault_from.z).lerp(Vector3(_vault_to.x, 0.0, _vault_to.z), u)
	var y: float
	if u < 0.42:
		var a := u / 0.42
		y = lerpf(_vault_from.y, _vault_apex, 1.0 - (1.0 - a) * (1.0 - a))
	else:
		var b := (u - 0.42) / 0.58
		y = lerpf(_vault_apex, _vault_to.y, b * b)
	player.global_position = Vector3(h.x, y, h.z)
	player.velocity = _vault_v
	player.locomotion._ease_tick(delta)
	player.casting._animate(delta, _vault_v)
	player._tick_always(delta)
	# the view rises only part of the hop over the wall, like a jump's (r29: it rode the whole arc,
	# the bumpiest camera on the movement course)
	player._cam_air_prev = player._cam_air
	player._air_base = minf(_vault_from.y, _vault_to.y)
	var up := player.global_position.y - player._air_base
	player._cam_air = lerpf(player._cam_air, -minf(maxf(up, 0.0) * 0.65, 1.1), 1.0 - exp(-16.0 * delta))
	if u >= 1.0:
		player._vault_t = -1.0
		player.velocity = _vault_v
		player._grounded = true
		player._air_base = player.global_position.y


# --- wall kick -----------------------------------------------------------------------------------------

## A tall wall touched (or right beside you) in the air, and not the one you just kicked off.

func _can_wallkick(wish: Vector3) -> bool:
	if player._grounded or player._hollowing:
		return false
	var n := Vector3.ZERO
	if player._wall_t > 0.0:
		n = player._wall_n
	else:
		for d: Vector3 in [Vector3(player.velocity.x, 0.0, player.velocity.z), Vector3(wish.x, 0.0, wish.z)]:
			if d.length_squared() < 0.01:
				continue
			var c := player.global_position + Vector3.UP * 0.9
			var hit := player.locomotion._ray(c, c + d.normalized() * 0.7)
			if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.3:
				continue
			var hn: Vector3 = hit.normal
			n = Vector3(hn.x, 0.0, hn.z).normalized()
			break
	if n == Vector3.ZERO:
		return false
	if player._kick_n != Vector3.ZERO and n.dot(player._kick_n) > 0.7:
		return false
	# tall enough to kick: wall above the head too (parapets and kerbs don't count)
	var head := player.global_position + Vector3.UP * 1.65
	if player.locomotion._ray(head, head - n * 0.75).is_empty():
		return false
	player._wall_n = n
	return true


func _wall_kick(wish: Vector3) -> void:
	if player._stam != null:
		player._stam.drain(Stamina.WALL_KICK)          # r31: costs Breath, never refused (a kick is a save)
	var n := player._wall_n
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var along := flat - n * flat.dot(n)
	var out := n * Player.KICK_OUT + along * 0.55
	if wish.length_squared() > 0.04:
		out += Vector3(wish.x, 0.0, wish.z).normalized() * 1.2
	out = out.limit_length(player.sprint_speed)
	player.velocity = Vector3(out.x, Player.KICK_UP, out.z)
	player._jump_rising = true
	player._kick_n = n
	player._wall_t = 0.0
	player._regrab = 0.15
	player._kick_lock = 0.22                             # the kick's line holds a moment before the stick steers
	player._visual.rotation.y = atan2(-out.x, -out.z)
	player._visual.play_move(&"wallkick", 0.42)
	var at := player.global_position + Vector3.UP * 0.6 - n * 0.35
	Vfx.burst(at, Color(0.16, 0.15, 0.17, 0.5), {"count": 10, "life": 0.5, "speed": Vector2(0.5, 1.6), "size": 0.16, "gravity": -0.3, "dir": n, "spread": 60.0, "additive": false})
	Sfx.play(Player.SFX_JUMP, at, -5.0, 0.95)
	Sfx.play("res://art/audio/step_%d.wav" % randi_range(0, 7), at, -4.0, 0.85, 0.03)
	player.camera_ctl.kick(0.2)


## Remember walls touched in the air (wall kick) and slopes too steep to stand on (steep slide).

func _note_contacts(delta: float) -> void:
	player._wall_t = maxf(0.0, player._wall_t - delta)
	player._steep_t = maxf(0.0, player._steep_t - delta)
	if player._grounded:
		player._kick_n = Vector3.ZERO
		return
	if player._steep_t <= 0.0 and player.velocity.y <= 0.0 and player.get_slide_collision_count() == 0 and player._hang == false:
		# stepped off onto a slope too steep to stand on: take to it instead of free-falling past it
		var c := player.global_position + Vector3.UP * 0.2
		var hit := player.locomotion._ray(c, c + Vector3.DOWN * 0.9)
		if not hit.is_empty():
			var hn: Vector3 = hit.normal
			if hn.y >= 0.3 and hn.y < 0.72:
				player._steep_t = 0.12
				player._steep_n = hn
				player.velocity.y = minf(player.velocity.y, -4.0)
	for i in player.get_slide_collision_count():
		var n := player.get_slide_collision(i).get_normal()
		if absf(n.y) < 0.3:
			player._wall_t = 0.28
			player._wall_n = Vector3(n.x, 0.0, n.z).normalized()
		elif n.y >= 0.3 and n.y < 0.72 and player._steep_t <= 0.0:
			# a capsule rolling off a stair nose touches its edge at a slant too: only a real slope
			# (the ground under the body is itself that steep) counts
			var c := player.global_position + Vector3.UP * 0.3 + Vector3(n.x, 0.0, n.z).normalized() * 0.15
			var hit := player.locomotion._ray(c, c + Vector3.DOWN * 1.0)
			if not hit.is_empty() and (hit.normal as Vector3).y < 0.72 and (hit.normal as Vector3).y >= 0.3:
				player._steep_t = 0.12
				player._steep_n = hit.normal
		elif n.y >= 0.3 and n.y < 0.72:
			player._steep_t = 0.12
			player._steep_n = n


## Down a slope too steep to stand on: a controlled slide (speed builds to a cap, a little
## steering across it), the rig's surfing crouch, dust and scrape. Jump leaves it outward.

func _tick_steep(delta: float, wish: Vector3, cur: Vector3) -> Vector3:
	var down := Vector3(player._steep_n.x, 0.0, player._steep_n.z).normalized()
	var across := down.cross(Vector3.UP)
	var h := cur + down * player.gravity * 0.6 * delta
	if wish.length_squared() > 0.04:
		h += across * wish.dot(across) * 3.0 * delta
	h = h.limit_length(Player.STEEP_MAX_V)
	player.velocity.y = maxf(player.velocity.y, -Player.STEEP_MAX_V)
	player._slide_fx.global_position = player.global_position + Vector3.UP * 0.05
	if not player._slide_fx.emitting:
		player._slide_fx.emitting = true
		player._slide_sfx.play()
	player._slide_sfx.pitch_scale = 0.6 + 0.05 * h.length()
	return h


# --- beams -------------------------------------------------------------------------------------------

## On something narrow (both sides open air): balance. Checked every other tick, two short rays
## (two more on the beam to find its middle and lean you back toward it).

func _beam_probe(horiz: Vector3) -> void:
	_beam_frame += 1
	if not player.is_on_floor() or player._glued or player._sliding or player._roll_t >= 0.0:
		player._beam_on = false
		return
	if _beam_frame % 2 != 0:
		return
	var fwd := horiz.normalized() if horiz.length() > 0.3 else -player._visual.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	player._beam_side = fwd.cross(Vector3.UP).normalized()
	var base := player.global_position + Vector3.UP * 0.25
	var drop := Vector3.DOWN * 0.6
	var l := player.locomotion._ray(base - player._beam_side * Player.BEAM_W, base - player._beam_side * Player.BEAM_W + drop)
	var r := player.locomotion._ray(base + player._beam_side * Player.BEAM_W, base + player._beam_side * Player.BEAM_W + drop)
	player._beam_on = l.is_empty() and r.is_empty()
	if player._beam_on:
		# and standing on something right under the middle (not mid-way down a stair)
		var c := player.locomotion._ray(base, base + Vector3.DOWN * 0.4)
		player._beam_on = not c.is_empty() and (c.position as Vector3).y > player.global_position.y - 0.1
	if not player._beam_on:
		player._beam_mid = 0.0
		return
	var lh := not player.locomotion._ray(base - player._beam_side * 0.15, base - player._beam_side * 0.15 + drop).is_empty()
	var rh := not player.locomotion._ray(base + player._beam_side * 0.15, base + player._beam_side * 0.15 + drop).is_empty()
	player._beam_mid = (0.0 if lh == rh else (-0.12 if lh else 0.12))


## Jumping at a ledge (top 0.3-1.7 m above the feet) while pushing toward it vaults onto it.

func _try_mantle(wish: Vector3) -> bool:
	if not player.is_on_wall() or player.velocity.y > 3.5 or player._sliding:
		return false
	var dir := Vector3(wish.x, 0.0, wish.z).normalized()
	var wall_n := player.get_wall_normal()
	if wall_n.dot(-dir) < 0.5:
		return false
	var space := player.get_world_3d().direct_space_state
	var probe_top := player.global_position + dir * 0.6 + Vector3.UP * (Player.MANTLE_MAX + 0.4)
	var q := PhysicsRayQueryParameters3D.create(probe_top, probe_top + Vector3.DOWN * (Player.MANTLE_MAX + 0.1), player.collision_mask, [player.get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.75:
		return false
	var top: Vector3 = hit.position
	# the ledge must be deep enough to stand on (no vaulting onto railings over the lava)
	var deep := top + dir * 0.75 + Vector3.UP * 0.5
	var q2 := PhysicsRayQueryParameters3D.create(deep, deep + Vector3.DOWN * 0.8, player.collision_mask, [player.get_rid()])
	var hit2 := space.intersect_ray(q2)
	if hit2.is_empty() or absf((hit2.position as Vector3).y - top.y) > 0.2:
		return false
	var rise := top.y - player.global_position.y
	if rise < 0.3 or rise > Player.MANTLE_MAX:
		return false
	var dest := top + Vector3.UP * 0.05 + dir * 0.15
	var land := Transform3D(player.global_basis, dest)
	if player.test_move(land, Vector3.UP * 0.05):
		return false                               # no room to stand up there
	# head clearance on the way up, tested a little off the wall (touching it counts as a hit)
	var off_wall := player.global_transform.translated(Vector3(wall_n.x, 0.0, wall_n.z).normalized() * 0.06)
	if player.test_move(off_wall, Vector3.UP * (rise + 0.1)):
		return false
	_mantle_from = player.global_position
	_mantle_to = dest
	player._mantle_t = 0.0
	player.velocity = Vector3.ZERO
	player._visual.play_move(&"mantle", Player.MANTLE_TIME * 1.5)
	Sfx.play(Player.SFX_JUMP, player.global_position, -8.0, 0.85)
	player.camera_ctl.kick(0.15)
	return true


func _tick_mantle(delta: float) -> void:
	player._mantle_t += delta
	var u := clampf(player._mantle_t / Player.MANTLE_TIME, 0.0, 1.0)
	# up first, then over: the rise leads the forward move
	var up_u := 1.0 - pow(1.0 - minf(u * 1.4, 1.0), 2.0)
	var fwd_u := smoothstep(0.25, 1.0, u)
	var p := Vector3(lerpf(_mantle_from.x, _mantle_to.x, fwd_u), lerpf(_mantle_from.y, _mantle_to.y, up_u), lerpf(_mantle_from.z, _mantle_to.z, fwd_u))
	# the view takes the pull-up over ~0.4 s instead of 0.24: part of each tick's rise goes into the
	# camera's eased offset (r29)
	player._cam_off.y -= maxf(p.y - player.global_position.y, 0.0) * 0.6
	player.global_position = p
	player.locomotion._ease_tick(delta)
	player.casting._animate(delta, Vector3.ZERO)
	player._tick_always(delta)
	if u >= 1.0:
		player._mantle_t = -1.0
		var dir := Vector3(_mantle_to.x - _mantle_from.x, 0.0, _mantle_to.z - _mantle_from.z).normalized()
		player.velocity = dir * player.walk_speed
		player._air_jumps_left = player.air_jumps
