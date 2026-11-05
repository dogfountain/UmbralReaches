extends "res://core/life/wildlife/life_group.gd"
## A flock of lapwings on the open heath and the meadow (life system r28). They feed spread over a
## patch of open ground (run a few steps, stop, tip forward to pick at the turf), and when something
## comes too close the whole flock lifts at once, calling, wheels together above the field in a loose
## ball that breathes in and out, and settles again 20-40 m off, staying near the ground it knows.
##   FEED  on the ground: run-stop-peck round the flock's patch
##   UP    wheeling: a leader circles, each bird holds a drifting slot round it
##   LAND  the leader glides down to the new patch, the birds drop to their places and fold
## One MultiMesh; tests read `state`, `lifts`, `positions()`.

enum { FEED, UP, LAND }

var birds: Array[Dictionary] = []
var mmi: MultiMeshInstance3D
var state := FEED
var lifts := 0
var patch := Vector3.ZERO       ## where the flock feeds now
var home := Vector3.ZERO        ## the ground it knows (new patches stay within 30 m)
var flee_r := 12.0
var _t := 0.0
var _lead := Vector3.ZERO
var _lead_ang := 0.0
var _land := Vector3.ZERO
var _call: AudioStreamPlayer3D
var _wings: AudioStreamPlayer3D
var _call_t := 8.0


func _init() -> void:
	cheap_glide = true


func setup(at: Vector3, n: int, seed_v: int) -> void:
	kind = "plover"
	rng.seed = seed_v
	center = at
	home = at
	patch = at
	position = at
	active_r = 95.0
	mmi = LifeKit.group("plover", n)
	add_child(mmi)
	for i in n:
		var q := _spot_in(patch, 3.5)
		birds.append({"pos": q, "yaw": rng.randf_range(-PI, PI), "t": rng.randf_range(0.2, 2.0), "target": q, "pitch": 0.0, "pitch_to": 0.0,
			"head": 0.0, "fly": 0.0, "vel": Vector3.ZERO, "slot": Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)).normalized() * rng.randf_range(1.0, 3.2),
			"ph": rng.randf_range(0.0, TAU), "gait": 0.0, "delay": rng.randf_range(0.0, 0.25), "land": q})
	_call = voice("scape:peewit", -12.0, 9.0, 80.0)
	_wings = voice("flap", -14.0, 6.0, 40.0)
	_write()


func _spot_in(c: Vector3, r: float) -> Vector3:
	for k in 12:
		var a := rng.randf_range(0.0, TAU)
		var q := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, r)
		if LifePlace.open_ground(q.x, q.z):
			return Vector3(q.x, RL.height_at(q.x, q.z), q.z)
	return Vector3(c.x, RL.height_at(c.x, c.z), c.z)


func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b in birds:
		out.append(b.pos)
	return out


func busy() -> bool:
	return state != FEED


func rest() -> void:
	if state == FEED:
		return
	state = FEED
	patch = _land if _land != Vector3.ZERO else patch
	for b in birds:
		b.pos = _spot_in(patch, 3.5)
		b.fly = 0.0
		b.vel = Vector3.ZERO
	_write()


func alarm(at: Vector3, strength: float) -> void:
	if state == FEED and patch.distance_to(at) < 25.0 + 50.0 * strength:
		_lift(at)


func _lift(from: Vector3) -> void:
	state = UP
	lifts += 1
	alarms += 1
	_t = rng.randf_range(9.0, 15.0)
	_lead = patch + Vector3(0, 2.0, 0)
	_lead_ang = rng.randf_range(0.0, TAU)
	# the new patch: away from the threat, 20-40 m, open ground, near home
	var away := patch - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	_land = patch
	for k in 14:
		var d := away.rotated(Vector3.UP, rng.randf_range(-1.2, 1.2)) * rng.randf_range(20.0, 40.0)
		var q := patch + d
		if q.distance_to(home) < 30.0 and LifePlace.open_ground(q.x, q.z) and RealmLayout.path_dist(Vector2(q.x, q.z)) > 3.0:
			_land = Vector3(q.x, RL.height_at(q.x, q.z), q.z)
			break
	if _land == patch:
		_land = home
	for b in birds:
		b.delay = rng.randf_range(0.0, 0.3)
	say(_wings, patch, "", rng.randf_range(0.9, 1.1))
	say(_call, patch + Vector3(0, 3, 0), "", rng.randf_range(0.95, 1.05))


func tick(dt: float, ctx: Dictionary) -> void:
	match state:
		FEED:
			var tp := threat_at(patch, ctx, 1.4)
			var fr := flee_r * (1.6 if float(ctx.player_speed) > 5.5 else 1.0)
			var near := false
			# the flock spreads ~4 m round its patch: nothing within fr + 6 of it, nothing near any bird
			if _td < fr + 6.0:
				for b in birds:
					if (b.pos as Vector3).distance_to(tp) < fr:
						near = true
						break
			if near:
				_lift(tp)
			else:
				for b in birds:
					_feed(b, dt)
		UP:
			_t -= dt
			_wheel(dt, ctx, false)
			if _t <= 0.0:
				state = LAND
				_t = 0.0
				# each bird's own place on the new patch, fixed now (a moving slot is never reached)
				for b in birds:
					var sl: Vector3 = b.slot
					var q := _land + Vector3(sl.x, 0, sl.z) * 1.6
					if not LifePlace.open_ground(q.x, q.z):
						q = _land
					b.land = Vector3(q.x, RL.height_at(q.x, q.z), q.z)
		LAND:
			_t += dt
			_wheel(dt, ctx, true)
	_calls(dt, ctx)
	var was := _still
	_still = _is_still()
	if not (was and _still) or not _lrows.is_empty():   # one more write lands the settling span
		_write(false)


func _is_still() -> bool:
	if state != FEED:
		return false
	for b in birds:
		var p: Vector3 = b.pos
		var to: Vector3 = (b.target as Vector3) - p
		if Vector2(to.x, to.z).length() > 0.05 or float(b.pitch) != float(b.pitch_to) or float(b.fly) > 0.0:
			return false
	return true


func _feed(b: Dictionary, dt: float) -> void:
	b.fly = move_toward(float(b.fly), 0.0, dt * 3.0)
	b.t = float(b.t) - dt
	var p: Vector3 = b.pos
	var to: Vector3 = (b.target as Vector3) - p
	to.y = 0.0
	var d := to.length()
	if d > 0.05:
		# a quick run on twinkling legs
		var stp := minf(d, dt * 1.6)
		b.yaw = turn(float(b.yaw), yaw_to(to), dt * 9.0)
		# height eased toward the target's (set once when it was chosen) instead of a terrain
		# lookup per bird per tick: over a step of a metre the turf is flat enough
		var ty: float = (b.target as Vector3).y
		p += to / d * stp
		p.y = lerpf(p.y, ty, stp / d)
		b.pos = p
		b.gait = fmod(float(b.gait) + stp * 40.0, TAU * 64.0)
		b.pitch_to = 0.0
	elif float(b.t) <= 0.0:
		var r := rng.randf()
		if r < 0.45:
			var tq: Vector3 = _spot_in(patch, 4.0) if (b.pos as Vector3).distance_to(patch) > 4.5 else (b.pos as Vector3) + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			tq.y = RL.height_at(tq.x, tq.z)
			b.target = tq
			b.t = rng.randf_range(0.3, 0.9)
		elif r < 0.8:
			b.pitch_to = -0.75                     # tip forward and pick
			b.t = rng.randf_range(0.25, 0.6)
		else:
			b.pitch_to = 0.15
			b.head = rng.randf_range(-1.0, 1.0)
			b.t = rng.randf_range(0.6, 1.6)
	elif float(b.pitch_to) < 0.0 and float(b.t) < 0.1:
		b.pitch_to = 0.0
	b.pitch = move_toward(float(b.pitch), float(b.pitch_to), dt * 10.0)


func _wheel(dt: float, ctx: Dictionary, landing: bool) -> void:
	var tm := float(ctx.time)
	var mid := (patch + _land) * 0.5
	if not landing:
		_lead_ang += dt * 0.7
		var r := 11.0 + 3.0 * sin(_lead_ang * 0.6)
		var want := mid + Vector3(cos(_lead_ang) * r, 9.0 + 2.5 * sin(_lead_ang * 1.7), sin(_lead_ang) * r)
		_lead = _lead.lerp(want, clampf(dt * 1.5, 0.0, 1.0))
	else:
		_lead = _lead.move_toward(_land + Vector3(0, 0.3, 0), dt * 6.0)
	var spread := 1.0 + 0.45 * sin(tm * 0.9)        # the ball breathes
	var down := 0
	for b in birds:
		if float(b.delay) > 0.0:
			b.delay = float(b.delay) - dt
			continue
		var p: Vector3 = b.pos
		var slot: Vector3 = (b.slot as Vector3).rotated(Vector3.UP, tm * 0.5 + float(b.ph)) * spread
		var tgt := _lead + slot
		if landing:
			tgt = b.land
			if _t > 12.0:                       # a straggler: put it down
				p = tgt
		var to := tgt - p
		var dist := to.length()
		var sp := 9.0 if not landing else clampf(dist * 1.5, 1.0, 8.0)
		var want := to / maxf(dist, 0.001) * minf(sp, dist * 4.0)
		b.vel = (b.vel as Vector3).lerp(want, clampf(dt * 3.0, 0.0, 1.0))
		p += (b.vel as Vector3) * dt
		b.pos = p
		var v: Vector3 = b.vel
		if Vector2(v.x, v.z).length() > 0.3:
			b.yaw = turn(float(b.yaw), yaw_to(v), dt * 6.0)
		b.fly = move_toward(float(b.fly), 1.0 if not landing or dist > 0.8 else 0.0, dt * 4.0)
		b.pitch = 0.0
		if landing and dist < 0.15:
			b.pos = tgt
			b.vel = Vector3.ZERO
			b.fly = 0.0
			down += 1
	if landing and down >= birds.size():
		state = FEED
		patch = _land
		for b in birds:
			b.target = b.pos
			b.t = rng.randf_range(0.5, 2.0)


func _calls(dt: float, ctx: Dictionary) -> void:
	_call_t -= dt
	if _call_t > 0.0 or bool(ctx.get("quiet", false)):
		return
	_call_t = rng.randf_range(14.0, 40.0) if state == FEED else rng.randf_range(2.0, 4.0)
	if state != FEED or rng.randf() < 0.35:
		var b: Dictionary = birds[rng.randi() % birds.size()]
		say(_call, b.pos, "", rng.randf_range(0.95, 1.08))


var _buf := PackedFloat32Array()
var _still := false


## Between logic ticks the flock is drawn part way from its older tick to its newer (r30:
## life_group.lerp_draw), never guessed ahead along a velocity: a wheeling ball turns every tick, and
## the guess kinked at each one.
func glide(ahead: float, span: float) -> void:
	if _lrows.is_empty():
		return
	send(mmi.multimesh, lerp_draw(ahead / maxf(span, 1.0 / 480.0)))


## `snap` (setup, rest): both ticks at this pose; a tick passes false.
func _write(snap := true) -> void:
	var n := birds.size()
	if _buf.size() != n * 16:
		_buf.resize(n * 16)
	if _gp.size() != n:
		_gp.resize(n)
		_gv.resize(n)
		_gf.resize(n * 6)
	_gm.clear()
	_gs.clear()
	var vmax := 0.0
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in n:
		var b: Dictionary = birds[i]
		var p: Vector3 = b.pos
		var fly := float(b.fly)
		var gait := float(b.gait)
		var pitch := float(b.pitch)
		lo = lo.min(p)
		hi = hi.max(p)
		var cd := Color(fly, float(b.head), gait, pitch)
		if fly > 0.3:
			var v: Vector3 = b.vel
			put(_buf, i, Basis(Vector3.UP, float(b.yaw)) * Basis(Vector3.RIGHT, clampf(v.y * 0.1, -0.5, 0.5)), p - center, cd)
		else:
			put_yaw(_buf, i, float(b.yaw), 1.0, p - center, cd)
		# packed copies for the glide: feeding, the run to its spot (rem = metres left, > 0);
		# in the air, its velocity (rem = 0: no limit)
		_gp[i] = p - center
		var q := i * 6
		var v2 := Vector3.ZERO
		var rem := 0.0
		if state == FEED:
			var to: Vector3 = (b.target as Vector3) - p
			to.y = 0.0
			var d := to.length()
			if d > 0.05:
				v2 = to / d * 1.6
				rem = d
		elif float(b.delay) <= 0.0:
			v2 = b.vel
		_gv[i] = v2
		vmax = maxf(vmax, v2.length())
		_gf[q] = rem
		_gf[q + 1] = gait
		_gf[q + 2] = pitch
		_gf[q + 3] = float(b.pitch_to)
		_gf[q + 4] = fly
		_gf[q + 5] = 0.0
		if v2 != Vector3.ZERO or (state == FEED and (pitch != float(b.pitch_to) or fly > 0.0)):
			if state == FEED and v2 == Vector3.ZERO:
				_gf[q] = 0.0001          # settling a peck in place: no motion, still ease
			_gm.append(i)
		else:
			_gs.append(i)
	var pad := Vector3(0.6, 0.4, 0.6) + Vector3.ONE * vmax * 0.25        # back to the older tick
	commit(mmi.multimesh, lerp_shift(_buf, snap), AABB(lo - center - pad, hi - lo + pad * 2.0 + Vector3(0, 0.4, 0)))


var _gp := PackedVector3Array()
var _gv := PackedVector3Array()
var _gf := PackedFloat32Array()
var _gm := PackedInt32Array()
var _gs := PackedInt32Array()


const LifePlace := preload("res://core/life/wildlife/life_place.gd")
