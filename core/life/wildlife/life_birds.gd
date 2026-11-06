extends "res://core/life/wildlife/life_group.gd"
## Perching birds (life system): crows on the henge stones and the graves, owls on oak branches,
## herons at the fen pools. One MultiMesh per group; every bird is a small state machine:
##   PERCH   head turns, pecks (crows), tracks the player (owls), stalks and strikes (herons)
##   FLEE    takes off away from the threat (wings beat: custom.x -> 1)
##   CIRCLE  crows wheel above the roost until it is quiet, then RETURN to their own perch
##   MOVE    owls and herons fly to another perch (another tree / another pool) and land there
##   AWAY    flown off out of sight; comes back once the player has gone
##   HUNT    owls: a field mouse in the grass below has its attention (head follows it, low)...
##   DIVE    ...a silent glide down onto it...
##   MANTLE  ...wings spread over the catch on the ground (or the mouse got away), then back up
## Owl groups keep their own field mice (a second MultiMesh) foraging in the open ground under their
## trees: they scurry and stop to nibble, bolt for cover from you or from a diving owl, and come out
## again later. Owls also leave pellets and the odd feather under their trees (tracks.gd).
## Sounds: crows caw, owls hoot (and answer each other), herons croak as they take off.

enum { PERCH, FLEE, CIRCLE, RETURN, MOVE, AWAY, HUNT, DIVE, MANTLE }
enum { M_FORAGE, M_RUN, M_HIDE, M_CAUGHT }

var perches: Array = []         ## [Vector3, yaw]; the first `count` are home perches
var birds: Array[Dictionary] = []
var mmi: MultiMeshInstance3D
var stubs: MultiMeshInstance3D   ## owls: the branch stubs they sit on
var _call: AudioStreamPlayer3D
var _wings: AudioStreamPlayer3D
var _call_t := 0.0
var flee_r := 7.0
var speed := 6.0
var size := 1.0                 ## crows are big carrion crows / ravens
var mice: Array[Dictionary] = []
var mice_mmi: MultiMeshInstance3D
var hunts := 0                  ## dives made (tests)
var catches := 0
var _hunt_t := 0.0
var _squeak: AudioStreamPlayer3D
var _mice_live := true          ## the mice are simulated (near enough to be seen, or being hunted)
var _still := false             ## the birds have nothing to redraw between ticks (see _is_still)
var _gp := PackedVector3Array()   ## glide copies, per bird: origin (relative to center), velocity,
var _gv := PackedVector3Array()   ## and 8 floats: head, head_to, pitch, pitch_to, -, fly, hop, fold
var _gf := PackedFloat32Array()
var _gm := PackedInt32Array()     ## birds that move between ticks
var _wheel := false               ## every crow circling: the glide turns the roost instead
var _gs := PackedInt32Array()     ## birds that do not
var _mp := PackedVector3Array()   ## mice: origin, velocity, stride
var _mv := PackedVector3Array()
var _mg := PackedFloat32Array()
var _mr := PackedFloat32Array()   ## metres left to its spot (the glide stops there)
var _mice_still := true         ## nor the mice
var _mice_dirty := true
var _mice_acc := 0.0
var _mice_stepped := false
var _mice_lag := 0.0            ## time between the mice's last write and the last tick
var _head_rs := 3.5             ## head turn rate (rad/s): crows 14, owls and herons 3.5
var _pitch_rs := 9.0            ## pitch rate (rad/s): owls 3
const MICE_SEEN := 16.0          ## a 6 cm mouse past ~16 m is a few pixels in the grass: they wait there


func _init() -> void:
	cheap_glide = true


func setup(k: String, perch_list: Array, count: int, seed_v: int, branch_xfs: Array = [], prey: Array[Vector3] = []) -> void:
	kind = k
	rng.seed = seed_v
	perches = perch_list
	count = mini(count, perches.size())
	var s := Vector3.ZERO
	for p: Array in perches:
		s += p[0] as Vector3
	center = s / float(maxi(perches.size(), 1))
	position = center
	match kind:
		"crow":
			flee_r = 7.0
			speed = 7.0
			active_r = 85.0
			size = 1.3
		"owl":
			flee_r = 9.0
			speed = 6.0
			active_r = 75.0
		"heron":
			flee_r = 13.0
			speed = 5.0
			active_r = 110.0
	_head_rs = 14.0 if kind == "crow" else 3.5
	_pitch_rs = 3.0 if kind == "owl" else 9.0
	mmi = LifeKit.group(kind, count)
	add_child(mmi)
	for i in count:
		var p: Array = perches[i]
		birds.append({"perch": i, "pos": p[0], "yaw": float(p[1]), "state": PERCH, "t": rng.randf_range(0.5, 3.0),
			"head": 0.0, "head_to": 0.0, "pitch": 0.0, "pitch_to": 0.0, "fly": 0.0, "vel": Vector3.ZERO,
			"target": p[0], "ang": rng.randf_range(0.0, TAU), "circle_t": 0.0, "gait": 0.0, "hop": 0.0, "walk": false, "delay": 0.0, "prey": 0})
	if not branch_xfs.is_empty():
		stubs = LifeKit.group("branch", branch_xfs.size())
		stubs.name = "OwlBranches"
		stubs.material_override = LifeKit.material("branch")
		add_child(stubs)
		for i in branch_xfs.size():
			var xf: Transform3D = branch_xfs[i]
			xf.origin -= center
			stubs.multimesh.set_instance_transform(i, xf)
			stubs.multimesh.set_instance_custom_data(i, Color(0, 0, 0, 0))
	match kind:
		"crow":
			_call = voice("crow", -8.0, 9.0, 80.0)          # r29: was -13, 11 dB under the owls
			_wings = voice("flap", -14.0, 5.0, 35.0)
		"owl":
			_call = voice("owl", -12.0, 12.0, 95.0)
			_wings = voice("flap", -20.0, 4.0, 25.0)
		"heron":
			_call = voice("heron", -8.0, 10.0, 80.0)
			_wings = voice("flap", -16.0, 6.0, 40.0)
	_call_t = rng.randf_range(4.0, 14.0)
	if kind == "owl" and not prey.is_empty():
		mice_mmi = LifeKit.group("mouse", prey.size())
		mice_mmi.name = "FieldMice"
		mice_mmi.visibility_range_end = 32.0
		add_child(mice_mmi)
		for q in prey:
			mice.append({"home": q, "pos": q, "yaw": rng.randf_range(-PI, PI), "state": M_FORAGE, "t": rng.randf_range(0.5, 3.0),
				"target": q, "gait": 0.0, "pitch": -0.3, "head": 0.0, "mv": Vector3.ZERO, "rem": 0.0})
		_squeak = voice("scape:squeak_soft", -18.0, 4.0, 30.0)
		_hunt_t = rng.randf_range(20.0, 45.0)
	_write()


func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b in birds:
		if int(b.state) != AWAY:
			out.append(b.pos)
	return out


func busy() -> bool:
	for b in birds:
		if int(b.state) != PERCH and int(b.state) != AWAY:
			return true
	if _mice_live:
		for m in mice:
			if int(m.state) == M_RUN:
				return true
	return false


func prey_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m in mice:
		if int(m.state) == M_FORAGE or int(m.state) == M_RUN:
			out.append(m.pos)
	return out


func perched_count() -> int:
	var n := 0
	for b in birds:
		if int(b.state) == PERCH:
			n += 1
	return n


func rest() -> void:
	for i in birds.size():
		var b: Dictionary = birds[i]
		if int(b.state) == PERCH:
			continue
		var home := i if kind == "crow" else int(b.perch)
		b.perch = home
		b.pos = (perches[home] as Array)[0]
		b.yaw = float((perches[home] as Array)[1])
		b.vel = Vector3.ZERO
		b.state = PERCH
		b.fly = 0.0
		b.walk = false
		b.delay = 0.0
	for m in mice:
		m.state = M_FORAGE
		m.pos = m.home
		m.mv = Vector3.ZERO
	_write()
	_still = false
	_mice_dirty = true


func alarm(at: Vector3, strength: float) -> void:
	var hit := false
	for b in birds:
		if int(b.state) == HUNT:
			b.state = PERCH
		if int(b.state) != PERCH:
			continue
		var reach := 22.0 + 30.0 * strength
		if (b.pos as Vector3).distance_to(at) > reach:
			continue
		if kind == "owl" and rng.randf() > 0.35 + 0.5 * strength:
			continue
		_take_off(b, at)
		hit = true
	if hit:
		alarms += 1


func tick(dt: float, ctx: Dictionary) -> void:
	var startled := false
	var pl: Vector3 = ctx.player
	var fr := flee_r * (1.6 if float(ctx.player_speed) > 5.5 else 1.0)
	var head_rate := dt * _head_rs
	var pitch_rate := dt * _pitch_rs
	for b in birds:
		var st := int(b.state)
		if st == PERCH or st == HUNT:
			if (b.pos as Vector3).distance_to(pl) < fr:
				b.state = PERCH
				_take_off(b, pl)
				startled = true
			elif st == HUNT:
				_watch_prey(b, dt, ctx)
			else:
				_perched(b, dt, ctx)
		elif st == DIVE or st == MANTLE:
			_dive(b, dt, ctx)
		elif st == AWAY:
			b.t = float(b.t) - dt
			var home: Vector3 = (perches[int(b.perch)] as Array)[0]
			if float(b.t) <= 0.0 and home.distance_to(ctx.player) > 35.0:
				b.pos = home + Vector3(0, 12, 0)
				b.state = RETURN
		else:
			_fly(b, dt, ctx)
		var hd := float(b.head)
		var ht := float(b.head_to)
		if hd != ht:
			var nh := turn(hd, ht, head_rate)
			b.head = ht if absf(wrap_angle(ht - nh)) < 0.0005 else nh
		var pt := float(b.pitch)
		var ptt := float(b.pitch_to)
		if pt != ptt:
			b.pitch = move_toward(pt, ptt, pitch_rate)
	if startled:
		alarms += 1
		# one bird going up takes the whole roost with it (crows), or the pair (owls)
		for b in birds:
			if int(b.state) == PERCH and kind == "crow":
				_take_off(b, ctx.player, rng.randf_range(0.0, 0.35))
	if kind == "owl" and not mice.is_empty():
		# the mice are simulated within MICE_SEEN of the camera: past that (and with no owl after one) they
		# wait where they are. Measured to the mice, not the roost: a field can lie well off the owls' trees,
		# and its mice never noticed a wanderer standing among them
		_mice_live = false
		var cam: Vector3 = ctx.cam
		for m in mice:
			if (m.home as Vector3).distance_to(cam) < MICE_SEEN:
				_mice_live = true
				break
		if not _mice_live:
			for b in birds:
				var st := int(b.state)
				if st == HUNT or st == DIVE or st == MANTLE:
					_mice_live = true
					break
		# the mice decide at ~7.5 Hz (the glide carries them in between)
		_mice_acc += dt
		_mice_stepped = false
		if _mice_live and _mice_acc >= 1.0 / 7.5:
			_mice_step(_mice_acc, ctx)
			_mice_acc = 0.0
			_mice_stepped = true
		_hunt_t -= dt
		if _hunt_t <= 0.0:
			_hunt_t = rng.randf_range(35.0, 80.0)
			_start_hunt(ctx)
	_calls(dt, ctx)
	# a still roost that stays still has nothing new to draw: skip the write (a discrete change, a
	# mouse coming out of hiding, marks itself dirty)
	var was_b := _still
	var was_m := _mice_still
	_still = _is_still()
	_mice_still = _mice_are_still()
	var wb := not (was_b and _still) or not _lrows.is_empty()   # one more write lands the settling span
	var wm := (_mice_stepped and not (was_m and _mice_still)) or _mice_dirty
	if wb or wm:
		_write(0.0, wb, wm, false)
	_mice_lag = 0.0 if wm else _mice_lag + dt
	_mice_dirty = false


## Nothing would move between ticks: no flight, heads and pitch settled, no hop, no mouse running
## (the director's glide then has nothing to redraw).
func _is_still() -> bool:
	for b in birds:
		var st := int(b.state)
		if st == AWAY:
			continue
		if (b.vel as Vector3) != Vector3.ZERO or float(b.head) != float(b.head_to) or float(b.pitch) != float(b.pitch_to) or float(b.hop) > 0.0:
			return false
		if (st == PERCH or st == HUNT) and float(b.fly) > 0.0:
			return false
		if bool(b.walk):
			return false
	return true


func _mice_are_still() -> bool:
	if _mice_live:
		for m in mice:
			if (m.mv as Vector3) != Vector3.ZERO:
				return false
	return true


# --- the owl's hunt ----------------------------------------------------------------------------------

func _start_hunt(ctx: Dictionary) -> void:
	if float((ctx.weather as Dictionary).get("rain", 0.0)) > 0.6 or bool(ctx.get("tide", false)):
		return
	var best := -1
	var bm := -1
	var bd := INF
	for i in birds.size():
		var b: Dictionary = birds[i]
		if int(b.state) != PERCH or (b.pos as Vector3).distance_to(ctx.player) < 14.0:
			continue
		for j in mice.size():
			var m: Dictionary = mice[j]
			if int(m.state) != M_FORAGE or (m.pos as Vector3).distance_to(ctx.player) < 6.0:
				continue
			var d := (m.pos as Vector3).distance_to(b.pos)
			if d < bd and d < 30.0:
				bd = d
				best = i
				bm = j
	if best < 0:
		return
	var o: Dictionary = birds[best]
	o.state = HUNT
	o.prey = bm
	o.t = rng.randf_range(2.5, 4.5)


func _watch_prey(b: Dictionary, dt: float, _ctx: Dictionary) -> void:
	var m: Dictionary = mice[int(b.prey)]
	if int(m.state) != M_FORAGE and int(m.state) != M_RUN:
		b.state = PERCH
		b.t = rng.randf_range(1.0, 3.0)
		return
	var to: Vector3 = (m.pos as Vector3) - (b.pos as Vector3)
	b.head_to = clampf(wrap_angle(yaw_to(to) - float(b.yaw)), -2.3, 2.3)
	b.pitch_to = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.9, 0.2)
	b.t = float(b.t) - dt
	if float(b.t) <= 0.0:
		# off the branch: turn the body toward it and drop
		b.state = DIVE
		b.yaw = yaw_to(Vector3(to.x, 0, to.z))
		b.head_to = 0.0
		b.vel = Vector3.ZERO
		hunts += 1
		say(_wings, b.pos, "", 0.7)


func _dive(b: Dictionary, dt: float, ctx: Dictionary) -> void:
	var m: Dictionary = mice[int(b.prey)]
	if int(b.state) == DIVE:
		var tgt: Vector3 = m.pos
		var p: Vector3 = b.pos
		var to := tgt - p
		var dist := to.length()
		# a shallow glide that steepens at the end: wings spread, few beats
		var want := to / maxf(dist, 0.001) * clampf(dist * 1.6, 2.0, 7.5)
		b.vel = (b.vel as Vector3).lerp(want, clampf(dt * 3.0, 0.0, 1.0))
		p += (b.vel as Vector3) * dt
		b.pos = p
		if Vector2(to.x, to.z).length() > 0.2:
			b.yaw = turn(float(b.yaw), yaw_to(Vector3(to.x, 0, to.z)), dt * 5.0)
		b.fly = move_toward(float(b.fly), 0.55 if dist < 2.5 else 0.85, dt * 3.0)
		b.pitch_to = -0.5
		if dist < 0.35 or (int(m.state) == M_HIDE and dist < 1.2):
			b.state = MANTLE
			b.t = rng.randf_range(2.2, 3.2)
			b.vel = Vector3.ZERO
			b.pos = Vector3(p.x, RL.height_at(p.x, p.z), p.z)
			if int(m.state) == M_FORAGE or int(m.state) == M_RUN:
				if (m.pos as Vector3).distance_to(b.pos) < 0.7 and rng.randf() < 0.7:
					m.state = M_CAUGHT
					m.mv = Vector3.ZERO
					m.t = rng.randf_range(45.0, 90.0)
					catches += 1
					say(_squeak, m.pos, "", rng.randf_range(0.9, 1.15))
				else:
					_mouse_flee(m, b.pos)
			if tracks != null and rng.randf() < 0.35:
				tracks.print_at(b.pos + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)), rng.randf_range(-PI, PI), 3, 240.0)
	else:
		# mantling: wings half open over the prey, head down, then back up to the branch
		b.fly = move_toward(float(b.fly), 0.45, dt * 2.0)
		b.pitch_to = -0.9
		b.t = float(b.t) - dt
		if float(b.t) <= 0.0 or (b.pos as Vector3).distance_to(ctx.player) < flee_r:
			b.state = MOVE
			b.target = (perches[int(b.perch)] as Array)[0]
			b.vel = Vector3(0, 2.5, 0)
			say(_wings, b.pos, "", 0.75)


func _mouse_flee(m: Dictionary, from: Vector3) -> void:
	var away: Vector3 = (m.pos as Vector3) - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	var q: Vector3 = (m.home as Vector3) + away.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6)) * rng.randf_range(1.0, 2.0)
	m.target = Vector3(q.x, RL.height_at(q.x, q.z), q.z)
	m.state = M_RUN


func _mice_step(dt: float, ctx: Dictionary) -> void:
	for m in mice:
		var st := int(m.state)
		var p: Vector3 = m.pos
		m.t = float(m.t) - dt
		match st:
			M_FORAGE:
				var dp := Vector2(ctx.player.x - p.x, ctx.player.z - p.z).length()
				if dp < 4.5 or (float(ctx.player_speed) > 5.5 and dp < 8.0):
					_mouse_flee(m, ctx.player)
					continue
				if float(m.t) <= 0.0:
					if rng.randf() < 0.55:
						var a := rng.randf_range(-PI, PI)
						var q: Vector3 = (m.home as Vector3) + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.2, 1.3)
						m.target = Vector3(q.x, RL.height_at(q.x, q.z), q.z)
						m.t = rng.randf_range(0.6, 1.4)
					else:
						m.target = p
						m.pitch = -0.6 if rng.randf() < 0.6 else 0.15     # nibble, or sit up and look
						m.head = rng.randf_range(-0.8, 0.8)
						m.t = rng.randf_range(0.8, 2.5)
				_mouse_move(m, dt, 0.7)
			M_RUN:
				if _mouse_move(m, dt, 2.2):
					m.state = M_HIDE
					m.t = rng.randf_range(10.0, 22.0)
			M_HIDE, M_CAUGHT:
				if float(m.t) <= 0.0 and (m.home as Vector3).distance_to(ctx.player) > 12.0:
					m.state = M_FORAGE
					m.pos = m.home
					_mice_dirty = true
					m.t = rng.randf_range(1.0, 3.0)


func _mouse_move(m: Dictionary, dt: float, sp: float) -> bool:
	var p: Vector3 = m.pos
	var to: Vector3 = (m.target as Vector3) - p
	to.y = 0.0
	var d := to.length()
	if d < 0.04:
		m.mv = Vector3.ZERO
		return true
	var stp := minf(d, sp * dt)
	m.mv = to / d * minf(sp, d / maxf(dt, 0.001))
	m.rem = d - stp
	m.yaw = turn(float(m.yaw), yaw_to(to), dt * 10.0)
	p += to / d * stp
	p.y = (m.target as Vector3).y
	m.pos = p
	m.gait = fmod(float(m.gait) + stp * 60.0, TAU * 64.0)
	m.pitch = -0.2
	return false


func _perched(b: Dictionary, dt: float, ctx: Dictionary) -> void:
	b.fly = move_toward(float(b.fly), 0.0, dt * 3.0)
	b.t = float(b.t) - dt
	var to_p: Vector3 = ctx.player - (b.pos as Vector3)
	match kind:
		"crow":
			if float(b.t) <= 0.0:
				var r := rng.randf()
				if r < 0.45:
					b.head_to = rng.randf_range(-1.3, 1.3)
					b.pitch_to = 0.0
					b.t = rng.randf_range(0.4, 1.6)
				elif r < 0.75:
					b.pitch_to = -0.9                       # peck
					b.t = rng.randf_range(0.25, 0.5)
				else:
					b.yaw = float(b.yaw) + rng.randf_range(-1.2, 1.2)   # hop round
					b.hop = 0.25
					b.pitch_to = 0.0
					b.t = rng.randf_range(0.8, 2.0)
			if float(b.pitch_to) < 0.0 and float(b.t) < 0.1:
				b.pitch_to = 0.0
			b.hop = maxf(0.0, float(b.hop) - dt)
		"owl":
			var d := to_p.length()
			if d < 32.0 and rng.randf() > 0.002:
				# the owl watches you: its head follows you round, up to ~130 degrees
				var rel := wrap_angle(yaw_to(to_p) - float(b.yaw))
				b.head_to = clampf(rel, -2.3, 2.3)
				b.pitch_to = clampf(atan2(to_p.y, Vector2(to_p.x, to_p.z).length()), -0.6, 0.4)
			elif float(b.t) <= 0.0:
				b.head_to = rng.randf_range(-2.0, 2.0) if rng.randf() < 0.7 else 0.0
				b.pitch_to = rng.randf_range(-0.3, 0.15)
				b.t = rng.randf_range(2.0, 6.0)
		"heron":
			if float(b.t) <= 0.0:
				var r := rng.randf()
				if r < 0.3:
					b.pitch_to = -1.15                      # strike
					b.t = 0.5
				elif r < 0.55:
					# stalk to a nearby perch of the same pool (a free one)
					var j := _free_perch(b.pos, 1.0, 6.0)
					if j >= 0:
						b.perch = j
						b.target = (perches[j] as Array)[0]
						b.state = MOVE
						b.fly = 0.0
						b.walk = true
					b.t = rng.randf_range(4.0, 9.0)
				else:
					b.head_to = rng.randf_range(-0.9, 0.9)
					b.pitch_to = rng.randf_range(-0.35, 0.1)
					b.t = rng.randf_range(2.5, 7.0)
			elif float(b.pitch_to) < -1.0 and float(b.t) < 0.25:
				b.pitch_to = -0.1


func _take_off(b: Dictionary, from: Vector3, delay := 0.0) -> void:
	var p: Vector3 = b.pos
	var away := p - from
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
	away = away.normalized()
	b.walk = false
	b.delay = delay
	b.pitch_to = 0.0
	b.head_to = 0.0
	match kind:
		"crow":
			b.state = FLEE
			b.target = center + away * rng.randf_range(4.0, 9.0) + Vector3(rng.randf_range(-3, 3), rng.randf_range(9.0, 14.0), rng.randf_range(-3, 3))
			b.circle_t = rng.randf_range(16.0, 30.0)
		"owl", "heron":
			var j := _free_perch(p, 22.0 if kind == "owl" else 25.0, 120.0, from)
			if j >= 0:
				b.perch = j
				b.state = MOVE
				b.target = (perches[j] as Array)[0]
			else:
				b.state = FLEE
				b.target = p + away * 60.0 + Vector3(0, 18, 0)
				b.circle_t = 0.0
	b.vel = Vector3(away.x, 1.6, away.z) * 2.5
	if delay <= 0.0:
		say(_wings, p, "", rng.randf_range(0.9, 1.15))
		if kind == "heron" or (kind == "crow" and rng.randf() < 0.6):
			say(_call, p, "", rng.randf_range(0.92, 1.08))


## A perch nobody sits on, between min_d and max_d from p, preferring ones far from `avoid`.
func _free_perch(p: Vector3, min_d: float, max_d: float, avoid := Vector3.INF) -> int:
	var taken := {}
	for b in birds:
		taken[int(b.perch)] = true
	var best := -1
	var best_s := -INF
	for j in perches.size():
		if taken.has(j):
			continue
		var q: Vector3 = (perches[j] as Array)[0]
		var d := q.distance_to(p)
		if d < min_d or d > max_d:
			continue
		var s := -d * 0.2 + rng.randf() * 3.0
		if avoid != Vector3.INF:
			s += minf(q.distance_to(avoid), 40.0)
		if s > best_s:
			best_s = s
			best = j
	return best


func _fly(b: Dictionary, dt: float, ctx: Dictionary) -> void:
	if float(b.get("delay", 0.0)) > 0.0:
		b.delay = float(b.delay) - dt
		if float(b.delay) <= 0.0:
			say(_wings, b.pos, "", rng.randf_range(0.9, 1.15))
		return
	var st := int(b.state)
	var walk := bool(b.get("walk", false))
	var p: Vector3 = b.pos
	var tgt: Vector3 = b.target
	if st == CIRCLE:
		b.ang = float(b.ang) + dt * 0.55
		var r := 9.0 + 3.0 * sin(float(b.ang) * 0.7)
		tgt = center + Vector3(cos(float(b.ang)) * r, 12.0 + 2.5 * sin(float(b.ang) * 1.9), sin(float(b.ang)) * r)
		b.circle_t = float(b.circle_t) - dt
		var calm := center.distance_to(ctx.player) > 16.0
		if float(b.circle_t) <= 0.0 and calm:
			b.state = RETURN
	elif st == RETURN:
		tgt = (perches[int(b.perch)] as Array)[0]
		if tgt.distance_to(ctx.player) < flee_r * 1.5:
			b.state = CIRCLE if kind == "crow" else FLEE
			b.circle_t = rng.randf_range(6.0, 12.0)
	var to := tgt - p
	var dist := to.length()
	var landing := st == RETURN or st == MOVE
	if walk:
		# herons stalk on foot
		var stp := minf(dist, dt * 0.35)
		if dist > 0.01:
			b.yaw = turn(float(b.yaw), yaw_to(to), dt * 2.0)
			p += to / dist * stp
			p.y = lerpf(p.y, tgt.y, stp / dist)          # the target perch's height, no lookup per tick
			b.gait = float(b.gait) + stp * 9.0
		b.pos = p
		b.pitch_to = -0.25
		if dist < 0.05:
			b.walk = false
			b.state = PERCH
			b.gait = 0.0
			b.yaw = float((perches[int(b.perch)] as Array)[1])
		return
	# flight: aim high on long hops, settle near the end
	if landing and dist > 6.0:
		tgt += Vector3(0, minf(dist * 0.3, 10.0), 0)
		to = tgt - p
	var sp := speed * (clampf(dist / 3.0, 0.25, 1.0) if landing else 1.0)
	var want := to.normalized() * sp if dist > 0.001 else Vector3.ZERO
	b.vel = (b.vel as Vector3).lerp(want, clampf(dt * 2.2, 0.0, 1.0))
	p += (b.vel as Vector3) * dt
	b.pos = p
	var v: Vector3 = b.vel
	if Vector2(v.x, v.z).length() > 0.3:
		b.yaw = turn(float(b.yaw), yaw_to(v), dt * 4.0)
	b.fly = move_toward(float(b.fly), 1.0 if dist > 0.6 or not landing else 0.4, dt * 4.0)
	if st == FLEE and dist < 2.0:
		if kind == "crow":
			b.state = CIRCLE
		else:
			b.state = AWAY
			b.t = rng.randf_range(35.0, 70.0)
	if landing and (b.pos as Vector3).distance_to((perches[int(b.perch)] as Array)[0]) < 0.25:
		b.pos = (perches[int(b.perch)] as Array)[0]
		b.vel = Vector3.ZERO
		b.yaw = float((perches[int(b.perch)] as Array)[1])
		b.state = PERCH
		b.t = rng.randf_range(1.0, 3.0)


func _calls(dt: float, ctx: Dictionary) -> void:
	_call_t -= dt
	if _call_t > 0.0 or bool(ctx.get("quiet", false)) or birds.is_empty():
		return
	var b: Dictionary = birds[rng.randi() % birds.size()]
	var near := center.distance_to(ctx.cam) < 70.0
	match kind:
		"crow":
			_call_t = rng.randf_range(9.0, 24.0)
			if near and int(b.state) == PERCH:
				say(_call, b.pos, "crow", rng.randf_range(0.9, 1.1))
				b.head_to = rng.randf_range(-0.4, 0.4)
				b.pitch_to = 0.35
				b.t = 1.2
		"owl":
			_call_t = rng.randf_range(14.0, 34.0) * (1.0 + float((ctx.weather as Dictionary).get("rain", 0.0)) * 2.0)
			if near and int(b.state) == PERCH:
				say(_call, b.pos, "owl" if rng.randf() < 0.65 else "owl2", rng.randf_range(0.95, 1.04))
		"heron":
			_call_t = rng.randf_range(40.0, 90.0)
			if near and int(b.state) == PERCH:
				say(_call, b.pos, "heron", rng.randf_range(0.85, 1.0))


var _buf := PackedFloat32Array()
var _mbuf := PackedFloat32Array()


## Between logic ticks a moving group is redrawn where its velocity takes it (no 30 Hz stepping on
## a 144 Hz screen); the next tick corrects any drift.
## Between ticks only what moves is touched in the buffer the tick wrote: a moving bird's origin
## (along its velocity), its head and pitch while they are still turning, a mouse's origin and
## stride. Read from packed copies the tick made (dictionary reads were most of the cost).
func glide(ahead: float, span: float) -> void:
	if _wheel:
		# a whole roost wheeling: they all circle the roost at the same rate, so the glide turns the
		# drawn roost about its centre instead of redrawing every bird (one transform, not 6 rows)
		mmi.rotation.y = -0.55 * ahead
	elif not _lrows.is_empty():
		# r30: drawn between the last two ticks (life_group.lerp_draw), not guessed ahead along the
		# velocity: the guess kept turn and climb for the next tick, so every course change kinked
		send(mmi.multimesh, lerp_draw(ahead / maxf(span, 1.0 / 480.0)))
	if not _mice_still and mice_mmi != null and _mice_live:
		var ma := ahead + _mice_lag
		for i in mini(mice.size(), _mp.size()):
			var o := _mp[i]
			var v := _mv[i]
			if v != Vector3.ZERO:
				var vl := v.length()
				var tm := minf(ma, _mr[i] / maxf(vl, 0.001))
				o += v * tm
				var j := i * 16
				_mbuf[j + 3] = o.x
				_mbuf[j + 7] = o.y
				_mbuf[j + 11] = o.z
				_mbuf[j + 14] = _mg[i] + vl * tm * 60.0
		send(mice_mmi.multimesh, _mbuf)


## `snap` (setup, rest): no older tick to draw from; a tick passes false.
func _write(_ahead := 0.0, do_birds := true, do_mice := true, snap := true) -> void:
	# the box is ours, from the positions we know: the automatic one follows the instance buffer,
	# which Metal can hand back stale, and then culls birds that are plainly in view
	if do_birds:
		_write_birds(0.0, snap)
	if mice_mmi != null and _mice_live and do_mice:
		_write_mice(0.0)


func _write_birds(ahead: float, snap := true) -> void:
	var n := birds.size()
	_wheel = kind == "crow" and n > 0
	for b in birds:
		if int(b.state) != CIRCLE or float(b.delay) > 0.0:
			_wheel = false
			break
	if mmi.rotation.y != 0.0:
		mmi.rotation.y = 0.0
	if _buf.size() != n * 16:
		_buf.resize(n * 16)
	if _gp.size() != n:
		_gp.resize(n)
		_gv.resize(n)
		_gf.resize(n * 8)
	_gm.clear()
	_gs.clear()
	var vmax := 0.0
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var up := Vector3.UP
	var sc := Vector3.ONE * size
	for i in n:
		var b: Dictionary = birds[i]
		var p: Vector3 = b.pos
		var fly := float(b.fly)
		var hop := float(b.hop)
		var head := float(b.head)
		var pitch := float(b.pitch)
		var bst := int(b.state)
		if ahead > 0.0:
			# where the next tick will have it: along its velocity, the head and pitch eased on
			if float(b.delay) <= 0.0:
				p += (b.vel as Vector3) * ahead
			head = turn(head, float(b.head_to), _head_rs * ahead)
			pitch = move_toward(pitch, float(b.pitch_to), _pitch_rs * ahead)
			hop = maxf(0.0, hop - ahead)
			if bst == PERCH or bst == HUNT:
				fly = move_toward(fly, 0.0, 3.0 * ahead)
		lo = lo.min(p)
		hi = hi.max(p)
		var lift := sin(clampf(hop / 0.25, 0.0, 1.0) * PI) * 0.06 if hop > 0.0 else 0.0
		var cd := Color(fly, head, float(b.gait), pitch)
		var away := bst == AWAY
		# packed copies for the glide (origin relative to the group, velocity, head/pitch and goals)
		var v0: Vector3 = b.vel if float(b.delay) <= 0.0 and not away else Vector3.ZERO
		vmax = maxf(vmax, v0.length())
		_gp[i] = p - center
		_gv[i] = v0
		var q := i * 8
		_gf[q] = head
		_gf[q + 1] = float(b.head_to)
		_gf[q + 2] = pitch
		_gf[q + 3] = float(b.pitch_to)
		_gf[q + 4] = 0.0
		_gf[q + 5] = fly
		_gf[q + 6] = hop
		_gf[q + 7] = 1.0 if (bst == PERCH or bst == HUNT) and fly > 0.0 else 0.0
		if v0 != Vector3.ZERO or hop > 0.0 or _gf[q + 7] > 0.5 or head != _gf[q + 1] or pitch != _gf[q + 3]:
			_gm.append(i)
		else:
			_gs.append(i)
		if fly > 0.3 and not away:
			var v: Vector3 = b.vel
			var basis := Basis(up, float(b.yaw)).scaled(sc) * Basis(Vector3.RIGHT, clampf(v.y * 0.12, -0.5, 0.6))
			put(_buf, i, basis, p - center + Vector3(0, lift, 0), cd)
		else:
			put_yaw(_buf, i, float(b.yaw), size * (0.001 if away else 1.0), p - center + Vector3(0, lift, 0), cd)
	# padded for where the older tick had a bird (<= 0.25 s back along its velocity)
	var pad := Vector3(1.2, 0.6, 1.2) + Vector3.ONE * vmax * 0.25
	# drawn one tick behind (see glide); a wheeling roost is drawn at the newer tick and turned
	var draw := lerp_shift(_buf, snap)
	commit(mmi.multimesh, _buf if _wheel else draw, AABB(lo - center - pad, hi - lo + pad * 2.0 + Vector3(0, 0.8, 0)))


func _write_mice(ahead: float) -> void:
	var m_n := mice.size()
	if _mbuf.size() != m_n * 16:
		_mbuf.resize(m_n * 16)
		_mp.resize(m_n)
		_mv.resize(m_n)
		_mr.resize(m_n)
		_mg.resize(m_n)
	var mlo := Vector3(INF, INF, INF)
	var mhi := -mlo
	for i in m_n:
		var m: Dictionary = mice[i]
		var mp: Vector3 = m.pos
		var mg := float(m.gait)
		_mp[i] = mp - center
		_mv[i] = m.mv
		_mr[i] = float(m.get("rem", 0.0))
		_mg[i] = mg
		mlo = mlo.min(mp)
		mhi = mhi.max(mp)
		var st := int(m.state)
		put_yaw(_mbuf, i, float(m.yaw), 0.001 if st == M_HIDE or st == M_CAUGHT else 1.0, mp - center, Color(0.0, float(m.head), mg, float(m.pitch)))
	# padded for a glide's reach (a running mouse, 2.2 m/s, up to ~0.35 s past its step)
	commit(mice_mmi.multimesh, _mbuf, AABB(mlo - center - Vector3(1.3, 0.3, 1.3), mhi - mlo + Vector3(2.6, 0.8, 2.6)))
