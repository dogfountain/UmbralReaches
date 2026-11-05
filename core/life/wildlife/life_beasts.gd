extends "res://core/life/wildlife/life_group.gd"
## Ground animals (life system): red deer at the Thornwood's edges (hinds and a stag), foxes by the
## village and the chapel, rats in the Ossuary, and the great elk standing on a ridge. Each is a small
## state machine written into one MultiMesh per mesh kind (custom: head yaw, gait phase, head pitch):
##   GRAZE  head down, a step now and then, looks up and about
##   ALERT  head up and turned to the threat (you, or a hollowed thing), ears and eyes on it
##   FLEE   the whole herd bolts away from it, bounding, and settles 35-55 m off
##   HIDE   rats vanish into the crypt's cracks; the elk walks off over its ridge
##   STALK / POUNCE / EAT   foxes hunting voles: a slow creep, a freeze with the head cocked, a high
##          arcing leap nose-first into the grass, and either a meal or a shake of the head
## Fright is graded: a disturbance far off (a spell, thunder, a kill, the rift surging) only brings
## heads up toward it for a few seconds (`startle`); close, the herd bolts. One hind in each herd is the
## sentinel and spends more time head-up; the stag bellows now and then; an undisturbed herd drifts
## slowly to new grass. Running and walking animals leave hoof- and paw-prints (tracks.gd).
## Ground height: RealmLand's grid, corrected by a ray now and then while moving.

enum { GRAZE, ALERT, WALK, FLEE, HIDE, STALK, POUNCE, EAT }

const STEP_UP := 0.9              ## the most ground can rise under a running animal between probes
var animals: Array[Dictionary] = []
var mmis := {}                  ## mesh kind -> MultiMeshInstance3D
var alert_r := 26.0
var flee_r := 15.0
var run_speed := 7.5
var walk_speed := 0.7
var graze_pitch := -1.65
var bound := 0.16
var gait_k := 2.6               ## gait radians per metre
var home_r := 4.0
var floor_y := NAN              ## rats: the crypt floor they live on (NAN = terrain)
var stride := 0.8               ## metres between prints
var startles := 0               ## times heads came up at something far off (tests)
var pounces := 0                ## fox leaps (tests)
var catches := 0
var bellows := 0
var drifts := 0
var _snort: AudioStreamPlayer3D
var _call: AudioStreamPlayer3D
var _feet: AudioStreamPlayer3D
var _herd_flee := 0.0
var _sentinel := 0
var _sent_t := 20.0
var _drift_t := 60.0
var _home0 := Vector3.ZERO


func setup(k: String, spots: Array[Vector3], seed_v: int) -> void:
	kind = k
	rng.seed = seed_v
	var s := Vector3.ZERO
	for p in spots:
		s += p
	center = s / float(maxi(spots.size(), 1))
	position = center
	var kinds: Array[String] = []
	match kind:
		"deer":
			for i in spots.size():
				kinds.append("stag" if i == 0 and rng.randf() < 0.75 else "deer")
			active_r = 110.0
			_snort = voice("snort", -10.0, 8.0, 70.0)
			_call = voice("scape:bellow", -9.0, 14.0, 140.0)
			_feet = voice("scape:hooves", -12.0, 7.0, 60.0)
		"fox":
			kinds.assign(Array(spots.map(func(_p: Vector3) -> String: return "fox")))
			alert_r = 18.0
			flee_r = 9.0
			run_speed = 6.5
			walk_speed = 0.9
			graze_pitch = -0.7
			bound = 0.08
			gait_k = 6.0
			active_r = 80.0
			stride = 0.35
			_call = voice("scape:vixen", -12.0, 10.0, 110.0)
			_feet = voice("scape:pounce", -14.0, 4.0, 30.0)
		"rat":
			kinds.assign(Array(spots.map(func(_p: Vector3) -> String: return "rat")))
			alert_r = 6.0
			flee_r = 3.5
			run_speed = 2.6
			walk_speed = 0.5
			graze_pitch = -0.35
			bound = 0.01
			gait_k = 40.0
			home_r = 2.5
			active_r = 40.0
			_snort = voice("squeak", -16.0, 3.0, 25.0)
		"hare":                          # r33 world: the heath's hares, a small skittish herd
			kinds.assign(Array(spots.map(func(_p: Vector3) -> String: return "hare")))
			alert_r = 16.0
			flee_r = 8.5
			run_speed = 9.0
			walk_speed = 0.45
			graze_pitch = -0.55
			bound = 0.1
			gait_k = 5.0
			home_r = 3.0
			active_r = 70.0
			stride = 0.5
		"elk":
			kinds.assign(Array(spots.map(func(_p: Vector3) -> String: return "elk")))
			alert_r = 60.0
			flee_r = 48.0
			run_speed = 1.6
			walk_speed = 0.5
			graze_pitch = -1.2
			bound = 0.02
			gait_k = 1.5
			active_r = 260.0
			stride = 1.1
			_call = voice("scape:bellow", -6.0, 20.0, 220.0)
	var counts := {}
	for kk in kinds:
		counts[kk] = int(counts.get(kk, 0)) + 1
	for kk: String in counts:
		var g := LifeKit.group(kk, int(counts[kk]))
		# no visibility range: on a MultiMesh whose node moves every frame it hid the whole herd in
		# plain view (renders 2026-11-04). The director already hides and freezes far groups.
		if kk == "elk":                 # herds stay shadowless: 4 cascades of 3-4k-tri deer cost more than they show
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(g)
		mmis[kk] = g
	var idx := {}
	for i in spots.size():
		var kk: String = kinds[i]
		var slot := int(idx.get(kk, 0))
		idx[kk] = slot + 1
		animals.append({"mesh": kk, "slot": slot, "pos": spots[i], "home": spots[i], "yaw": rng.randf_range(-PI, PI),
			"state": GRAZE, "t": rng.randf_range(0.5, 4.0), "head": 0.0, "head_to": 0.0, "pitch": graze_pitch, "pitch_to": graze_pitch,
			"gait": 0.0, "target": spots[i], "speed": 0.0, "ray_t": 0.0, "gy": spots[i].y, "hide_t": 0.0,
			"look_t": 0.0, "roar_t": rng.randf_range(30.0, 110.0), "k": 0.0, "from": spots[i], "step_d": 0.0, "foot": 0, "hunt_t": rng.randf_range(8.0, 25.0)})
	_home0 = center
	_sent_t = rng.randf_range(15.0, 35.0)
	_drift_t = rng.randf_range(40.0, 90.0)
	_write(true)


func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for a in animals:
		if int(a.state) != HIDE:
			out.append(a.pos)
	return out


func busy() -> bool:
	for a in animals:
		var st := int(a.state)
		if st == FLEE or st == WALK or st == STALK or st == POUNCE:
			return true
	return false


func fleeing() -> int:
	var n := 0
	for a in animals:
		if int(a.state) == FLEE or int(a.state) == HIDE:
			n += 1
	return n


func rest() -> void:
	for a in animals:
		if int(a.state) == FLEE:
			a.pos = a.target
			if kind != "rat" and kind != "elk":
				a.home = a.pos
		if int(a.state) == POUNCE or int(a.state) == STALK:
			a.pos = a.target if int(a.state) == POUNCE else a.pos
		if int(a.state) != HIDE:
			a.state = GRAZE
			a.speed = 0.0
			a.pitch = graze_pitch
			a.pitch_to = graze_pitch
	_write(true)


## Graded: close, they bolt; further off, heads come up toward it and they watch a while.
func alarm(at: Vector3, strength: float) -> void:
	var d := _lead_pos().distance_to(at)
	if d < 18.0 + 30.0 * strength:
		_bolt(at)
	elif d < 60.0 + 110.0 * strength:
		startle(at, strength)


## Heads up toward `at` (a far sound, a flash): ALERT for a few seconds, no running.
func startle(at: Vector3, strength := 0.5) -> void:
	var any := false
	for a in animals:
		var st := int(a.state)
		if st == HIDE or st == FLEE:
			continue
		if st == POUNCE:
			continue
		if st == STALK and strength < 0.7:      # r34 merge: a fox on a hunt ignores a far, faint sound
			continue
		a.state = ALERT
		a.speed = 0.0
		a.look_t = rng.randf_range(3.0, 6.0) + strength * 4.0
		var rel := wrap_angle(yaw_to(at - (a.pos as Vector3)) - float(a.yaw))
		a.head_to = clampf(rel, -1.4, 1.4)
		a.pitch_to = 0.25 if kind != "rat" else 0.1
		if absf(rel) > 1.3:
			a.yaw = float(a.yaw) + rel * 0.5          # half turn toward it
		any = true
	if any:
		startles += 1


func tick(dt: float, ctx: Dictionary) -> void:
	_herd_flee = maxf(0.0, _herd_flee - dt)
	var bolt_from := Vector3.INF
	var pl: Vector3 = ctx.player
	var fast := float(ctx.player_speed) > 5.5
	for a in animals:
		var st := int(a.state)
		var p: Vector3 = a.pos
		var tp := threat_at(p, ctx, 1.9)
		var td := _td
		var fr := flee_r * (1.5 if fast and tp == pl else 1.0)
		if st == HIDE:
			a.hide_t = float(a.hide_t) - dt
			var back_r := 110.0 if kind == "elk" else 8.0
			if float(a.hide_t) <= 0.0 and (a.home as Vector3).distance_to(ctx.player) > back_r:
				a.pos = a.home
				a.state = GRAZE
				_dirty = true
				a.t = rng.randf_range(1.0, 3.0)
			continue
		a.look_t = maxf(0.0, float(a.look_t) - dt)
		if st != FLEE and td < fr:
			bolt_from = tp
		elif st == GRAZE or st == WALK or st == ALERT or st == STALK or st == EAT:
			if td < alert_r:
				if st != ALERT:
					a.state = ALERT
					a.speed = 0.0
				var rel := wrap_angle(yaw_to(tp - p) - float(a.yaw))
				a.head_to = clampf(rel, -1.4, 1.4)
				a.pitch_to = 0.2 if kind != "rat" else 0.1
				# turn the body a little toward it too, ready to run
				if absf(rel) > 1.2:
					a.yaw = turn(float(a.yaw), yaw_to(tp - p), dt * 0.8)
					_dirty = true
			elif st == ALERT and float(a.look_t) <= 0.0:
				a.state = GRAZE
				a.t = rng.randf_range(2.0, 5.0)
		_step(a, dt, ctx)
	if bolt_from != Vector3.INF:
		_bolt(bolt_from)
	_herd_life(dt, ctx)
	# a herd standing still that stays still has nothing new to draw
	var was := _still
	_still = _is_still()
	if not (was and _still) or _dirty:
		_write()
	_dirty = false


## Nothing would move between ticks: everyone standing, heads, pitch and feet settled.
func _is_still() -> bool:
	for a in animals:
		var st := int(a.state)
		if st == HIDE:
			continue
		if st == FLEE or st == WALK or st == STALK or st == POUNCE:
			return false
		if float(a.head) != float(a.head_to) or float(a.pitch) != float(a.pitch_to):
			return false
		var g := float(a.gait)
		if g != roundf(g / PI) * PI:
			return false
	return true


## The herd as a whole: a sentinel that keeps watch, the stag's bellow, a slow drift to new grass.
func _herd_life(dt: float, ctx: Dictionary) -> void:
	if animals.is_empty() or kind == "rat":
		return
	_sent_t -= dt
	if _sent_t <= 0.0:
		_sent_t = rng.randf_range(18.0, 40.0)
		_sentinel = (_sentinel + 1) % animals.size()
		for i in animals.size():
			animals[i].sent = animals.size() > 1 and i == _sentinel
	var calm := true
	for a in animals:
		if int(a.state) != GRAZE and int(a.state) != WALK:
			calm = false
			break
	var quiet := bool(ctx.get("quiet", false))
	# the bellow: a stag (or the elk) raises its head and roars, the others look up
	for a in animals:
		if String(a.mesh) != "stag" and String(a.mesh) != "elk":
			continue
		a.roar_t = float(a.roar_t) - dt
		if float(a.roar_t) <= 0.0:
			a.roar_t = rng.randf_range(60.0, 140.0)
			if calm and not quiet and _call != null and int(a.state) == GRAZE:
				a.pitch_to = 0.6
				a.head_to = 0.0
				a.t = 3.2
				bellows += 1
				say(_call, (a.pos as Vector3) + Vector3(0, 1.4, 0), "", rng.randf_range(0.92, 1.05))
	if kind == "fox" and not quiet:
		var f: Dictionary = animals[0]
		f.roar_t = float(f.roar_t) - dt
		if float(f.roar_t) <= 0.0:
			f.roar_t = rng.randf_range(70.0, 160.0)
			if int(f.state) == GRAZE and _call != null and (f.pos as Vector3).distance_to(ctx.player) > 15.0:
				say(_call, (f.pos as Vector3) + Vector3(0, 0.4, 0), "", rng.randf_range(0.95, 1.08))
				f.pitch_to = 0.4
				f.t = 2.0
	# drift: an undisturbed herd wanders on to new grass, staying near where it lives
	if kind == "deer" and calm:
		_drift_t -= dt
		if _drift_t <= 0.0:
			_drift_t = rng.randf_range(50.0, 110.0)
			var lead := _lead_pos()
			for k in 8:
				var ang := rng.randf_range(-PI, PI)
				var off := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(4.0, 9.0)
				var q := lead + off
				if q.distance_to(_home0) > 26.0 or not _ok(q.x, q.z):
					continue
				drifts += 1
				for a in animals:
					var h: Vector3 = (a.home as Vector3) + off
					if _ok(h.x, h.z):
						a.home = Vector3(h.x, a.pos.y, h.z)
						a.target = a.home
						a.state = WALK
				break


func _bolt(from: Vector3) -> void:
	if _herd_flee > 0.0:
		return
	_herd_flee = 4.0
	alarms += 1
	if OS.has_feature("editor") and "--life-debug" in OS.get_cmdline_user_args():
		print("LIFE_BOLT %s %s from %s" % [name, kind, from])
	# the herd runs together: one direction away from the threat, each to its own spot near the end
	var away := center - from
	for a in animals:
		if int(a.state) != HIDE:
			away = (a.pos as Vector3) - from
			break
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var dist := rng.randf_range(35.0, 55.0)
	match kind:
		"rat":
			dist = rng.randf_range(2.0, 4.0)
		"elk":
			dist = 30.0
		"fox":
			dist = rng.randf_range(25.0, 40.0)
		"hare":
			dist = rng.randf_range(22.0, 34.0)
	var goal := _goal(_lead_pos(), away, dist)
	for a in animals:
		if int(a.state) == HIDE:
			continue
		if int(a.state) == POUNCE:
			a.pos = a.target
		var off := Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)) if kind != "rat" else Vector3.ZERO
		if kind == "hare":                   # hares scatter: each its own way off the line
			off = away.rotated(Vector3.UP, rng.randf_range(-1.0, 1.0)) * rng.randf_range(4.0, 9.0)
		var g := goal + off
		if not _ok(g.x, g.z):
			g = goal
		a.target = g
		a.state = FLEE
		a.head_to = 0.0
		a.pitch_to = 0.25 if kind == "deer" else 0.0
		a.t = 0.0
	if _snort != null:
		say(_snort, _lead_pos(), "", rng.randf_range(0.9, 1.15))
	if _feet != null and kind != "fox":
		say(_feet, _lead_pos(), "", rng.randf_range(0.9, 1.1))


func _lead_pos() -> Vector3:
	for a in animals:
		if int(a.state) != HIDE:
			return a.pos
	return center


## A valid spot about `dist` along `dir` from p (swinging up to ~80 degrees either way), or p.
func _goal(p: Vector3, dir: Vector3, dist: float) -> Vector3:
	for k in 9:
		var ang := (float((k + 1) / 2) * 0.35) * (1.0 if k % 2 == 0 else -1.0)
		var d := dir.rotated(Vector3.UP, ang)
		for f: float in [1.0, 0.7, 0.45]:
			var q := p + d * dist * f
			if _ok(q.x, q.z) and _ok(p.x + (q.x - p.x) * 0.5, p.z + (q.z - p.z) * 0.5):
				return Vector3(q.x, _ground(q.x, q.z, p.y), q.z)
	return p


func _ok(x: float, z: float) -> bool:
	if kind == "rat":
		if space == null:
			return true
		var y := LifePlace.floor_below(space, x, floor_y + 1.2, z, 3.0)
		return not is_nan(y) and absf(y - floor_y) < 0.35
	if kind == "elk":
		return RealmLayout.OUTER.has_point(Vector2(x, z))
	return LifePlace.open_ground(x, z)


## The floor under (x, z): probed from `reach` above `fallback`. Running, that is a body's step-up:
## probed from 6 m, a deer passing a boulder or a wall took its top for the ground and leapt 5 m.
func _ground(x: float, z: float, fallback: float, reach := 6.0) -> float:
	if kind == "rat":
		return floor_y
	if space != null:
		var y := LifePlace.floor_below(space, x, fallback + reach, z, reach + 8.0)
		if not is_nan(y):
			return y
	return RL.height_at(x, z)


func _step(a: Dictionary, dt: float, _ctx: Dictionary) -> void:
	var st := int(a.state)
	a.t = float(a.t) - dt
	var p: Vector3 = a.pos
	match st:
		GRAZE:
			a.speed = 0.0
			if kind == "fox":
				a.hunt_t = float(a.hunt_t) - dt
				if float(a.hunt_t) <= 0.0 and float(a.t) <= 0.0:
					a.hunt_t = rng.randf_range(14.0, 35.0)
					_stalk(a)
					return
			if float(a.t) <= 0.0:
				var r := rng.randf()
				var sentinel := bool(a.get("sent", false))
				if sentinel and r < 0.6:
					a.pitch_to = 0.2                    # the sentinel: head up, scanning
					a.head_to = rng.randf_range(-1.3, 1.3)
					a.t = rng.randf_range(2.0, 4.5)
				elif r < 0.35:
					a.pitch_to = 0.1                    # head up, a look round
					a.head_to = rng.randf_range(-1.0, 1.0)
					a.t = rng.randf_range(1.5, 4.0)
				elif r < 0.65 and kind != "elk":
					var ang := rng.randf_range(-PI, PI)
					var q := (a.home as Vector3) + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.5, home_r)
					if _ok(q.x, q.z):
						a.target = Vector3(q.x, p.y, q.z)
						a.state = WALK
					a.t = rng.randf_range(3.0, 7.0)
				else:
					a.pitch_to = graze_pitch * rng.randf_range(0.85, 1.0)
					a.head_to = rng.randf_range(-0.3, 0.3)
					a.t = rng.randf_range(3.0, 8.0)
		WALK:
			a.pitch_to = graze_pitch * 0.4
			if _move(a, dt, walk_speed):
				a.state = GRAZE
				a.t = rng.randf_range(1.0, 3.0)
				a.pitch_to = graze_pitch
		FLEE:
			if _move(a, dt, run_speed):
				if kind == "rat" or kind == "elk":       # back to the old haunt once it is quiet
					a.state = HIDE
					a.hide_t = rng.randf_range(12.0, 25.0) if kind == "rat" else 40.0
				else:
					a.home = a.pos
					a.state = ALERT
					a.t = 2.0
		ALERT:
			a.speed = move_toward(float(a.speed), 0.0, dt * 6.0)
		STALK:
			# creep low toward the rustle, then freeze with the head cocked, then leap
			a.pitch_to = -0.55
			if float(a.k) < 0.0:
				a.head_to = sin(float(a.t) * 5.0) * 0.12 + 0.3 * signf(sin(float(a.from.x)))
				if float(a.t) <= 0.0:
					_pounce(a)
			elif _move(a, dt, 0.28):
				a.k = -1.0
				a.t = rng.randf_range(0.8, 1.8)
				a.speed = 0.0
		POUNCE:
			a.k = float(a.k) + dt / 0.72
			var k := minf(float(a.k), 1.0)
			var from: Vector3 = a.from
			var to: Vector3 = a.target
			a.pos = from.lerp(to, k)
			a.pitch_to = lerpf(0.5, -1.2, k)
			a.pitch = float(a.pitch_to)
			if k >= 1.0:
				pounces += 1
				say(_feet, to, "", rng.randf_range(0.9, 1.1))
				if tracks != null:
					for side: float in [-1.0, 1.0]:
						tracks.print_at(to + Vector3(-cos(float(a.yaw)), 0, sin(float(a.yaw))) * 0.06 * side, float(a.yaw), 1, 120.0)
				a.state = EAT
				if rng.randf() < 0.45:
					catches += 1
					a.t = rng.randf_range(2.5, 4.0)
					a.pitch_to = -1.35
					a.head_to = 0.0
					a.roar_t = maxf(float(a.roar_t), 20.0)
				else:
					a.t = 1.4                           # missed: a shake of the head
					a.pitch_to = -0.2
		EAT:
			if float(a.pitch_to) > -1.0:
				a.head_to = sin(float(a.t) * 18.0) * 0.5 * clampf(float(a.t) - 0.4, 0.0, 1.0)
			if float(a.t) <= 0.0:
				a.state = GRAZE
				a.home = a.pos
				a.head_to = 0.0
				a.t = rng.randf_range(2.0, 5.0)
	var hd := float(a.head)
	var ht := float(a.head_to)
	if hd != ht:
		a.head = turn(hd, ht, dt * 2.5)
	var pt := float(a.pitch)
	var ptt := float(a.pitch_to)
	if pt != ptt:
		a.pitch = move_toward(pt, ptt, dt * 1.6)
	var st2 := int(a.state)
	if st2 != FLEE and st2 != WALK and st2 != STALK:
		# feet settle: ease the gait to a standing pose (legs straight at sin = 0)
		var g := float(a.gait)
		var gs := roundf(g / PI) * PI
		if g != gs:
			a.gait = move_toward(g, gs, dt * 4.0)


func _stalk(a: Dictionary) -> void:
	var q := Vector3.INF
	for k in 8:
		var fwd := Vector3(-sin(float(a.yaw)), 0, -cos(float(a.yaw))).rotated(Vector3.UP, rng.randf_range(-0.8, 0.8) + float(k) * 0.8)
		var c: Vector3 = (a.pos as Vector3) + fwd * rng.randf_range(1.2, 2.6)
		var c2: Vector3 = c + fwd * 1.7
		if _ok(c.x, c.z) and _ok(c2.x, c2.z):
			q = c
			break
	if q == Vector3.INF:
		a.hunt_t = 3.0
		return
	a.target = Vector3(q.x, (a.pos as Vector3).y, q.z)
	a.state = STALK
	a.k = 0.0
	a.from = a.pos
	# r34 merge: time for the whole creep (0.28 m/s from a standstill over up to 2.6 m took longer than
	# the old flat 6 s, so most stalks ran out a metre short and the fox never leapt)
	a.t = 4.0 + Vector2(q.x - (a.pos as Vector3).x, q.z - (a.pos as Vector3).z).length() / 0.28


func _pounce(a: Dictionary) -> void:
	# r34 merge: a few angles round the head's line before giving up (the busier r34 ground put a site
	# margin dead ahead of most finished stalks, so foxes stalked and never leapt)
	var q := Vector3.INF
	for off: float in [0.0, 0.45, -0.45, 0.9, -0.9]:
		var fwd := Vector3(-sin(float(a.yaw) + off), 0, -cos(float(a.yaw) + off))
		var c: Vector3 = (a.pos as Vector3) + fwd * rng.randf_range(1.1, 1.7)
		if _ok(c.x, c.z):
			q = c
			if off != 0.0:
				a.yaw = float(a.yaw) + off
			break
	if q == Vector3.INF:
		a.state = GRAZE
		a.t = 1.0
		return
	a.from = a.pos
	a.target = Vector3(q.x, _ground(q.x, q.z, (a.pos as Vector3).y), q.z)
	a.k = 0.0
	a.state = POUNCE
	if tracks != null:
		tracks.print_at(a.pos, float(a.yaw), 1, 120.0)


## Move toward target; true when there.
func _move(a: Dictionary, dt: float, sp: float) -> bool:
	var p: Vector3 = a.pos
	var to: Vector3 = a.target - p
	to.y = 0.0
	var d := to.length()
	if d < 0.3:
		return true
	a.speed = move_toward(float(a.speed), sp, dt * sp * 1.5)
	var want := yaw_to(to)
	a.yaw = turn(float(a.yaw), want, dt * (4.0 if sp > 2.0 else 1.6))
	var fwd := Vector3(-sin(float(a.yaw)), 0, -cos(float(a.yaw)))
	var step := minf(float(a.speed) * dt, d)
	p += fwd * step
	a.gait = fmod(float(a.gait) + step * gait_k, TAU * 64.0)
	a.ray_t = float(a.ray_t) - dt
	if float(a.ray_t) <= 0.0:
		a.ray_t = 0.15
		a.gy = _ground(p.x, p.z, p.y, STEP_UP)
	# height eases to the ground at a rate a body can manage (not a fraction per tick: at 7.5 Hz far
	# off that was the whole way in one tick, so a deer jumped onto whatever the probe found)
	var dy := float(a.gy) - p.y
	p.y += clampf(dy * clampf(dt * 8.0, 0.0, 1.0), -dt * 6.0, dt * 3.0)
	a.pos = p
	if tracks != null and kind != "rat":
		a.step_d = float(a.step_d) + step
		var sl := stride * (1.6 if sp > 2.0 else 1.0)
		if float(a.step_d) >= sl:
			a.step_d = 0.0
			a.foot = 1 - int(a.foot)
			var right := Vector3(cos(float(a.yaw)), 0, -sin(float(a.yaw)))
			var w := (0.12 if kind != "elk" else 0.22) * (1.0 if int(a.foot) == 0 else -1.0)
			tracks.print_at(p + right * w, float(a.yaw), 1 if kind == "fox" or kind == "hare" else 0, 150.0 if sp > 2.0 else 90.0)
	return false


var _bufs := {}                  ## mesh kind -> PackedFloat32Array (kept: no allocation per tick)
var _still := false              ## nothing to redraw between ticks (see _is_still)
var _bl: Array = []              ## the buffers (same order as _bmm), their MultiMeshes, kinds
var _bmm: Array[MultiMesh] = []
var _bkn: Array[String] = []
var _bm := PackedInt32Array()    ## animals whose last two ticks differ: drawn part way between them
var _dirty := true
var _slots := {}                 ## mesh kind -> instance count
## The pose of every animal at the last two ticks. Between ticks the herd is drawn part way from the
## older to the newer: interpolation, one tick (33 ms near) behind. It used to be drawn guessed ahead
## along its heading, but the guess kept height and turn for the next tick to fix, so every tick on a
## slope or in a turn popped the deer up or round: the "jumping" the trailer caught (r30).
var _pp := PackedVector3Array()  ## older tick: world position with the gallop's lift
var _pc := PackedVector3Array()  ## newer tick
var _ap := PackedFloat32Array()  ## older tick, 6 per animal: yaw, tilt, head, gait, pitch, scale
var _ac := PackedFloat32Array()  ## newer tick
var _amk := PackedInt32Array()   ## per animal: index into _bl / _bmm
var _tick_dt := 1.0 / 30.0       ## the span the last glide drew across (zz/herd_smooth_probe reads it)


func near_interval(_moving: bool) -> float:
	return 1.0 / 30.0


## Between ticks: every animal whose last two ticks differ is drawn `ahead / span` of the way from
## the older to the newer (position, heading, gallop tilt, head, stride, pitch), so motion is
## continuous at any frame rate and a tick never shows as a step. `span` is the interval the director
## uses until the NEXT tick (not the last one's), so crossing a rate band neither stalls nor pops.
func glide(ahead: float, span: float) -> void:
	if _bm.is_empty() or _bl.is_empty():
		return
	_tick_dt = maxf(span, 1.0 / 480.0)
	var al := clampf(ahead / _tick_dt, 0.0, 1.0)
	var o := position
	var touched := 0
	for i in _bm:
		var mk := _amk[i]
		_draw_row(_bl[mk], int(animals[i].slot), i, al, o)
		touched |= 1 << mk
	for mk in _bmm.size():
		if touched & (1 << mk):
			send(_bmm[mk], _bl[mk])
	if al >= 1.0 and _still:
		_bm.clear()                     # settled at the newer tick: nothing more to draw till the next


## One animal's row in its buffer, `al` of the way from the older tick to the newer.
func _draw_row(buf: PackedFloat32Array, slot: int, i: int, al: float, o: Vector3) -> void:
	var q := i * 6
	var pos := (_pp[i].lerp(_pc[i], al) if al > 0.0 else _pp[i]) - o
	var yw := lerp_angle(_ap[q], _ac[q], al)
	var tilt := lerpf(_ap[q + 1], _ac[q + 1], al)
	var cd := Color(0.0, lerp_angle(_ap[q + 2], _ac[q + 2], al), lerpf(_ap[q + 3], _ac[q + 3], al), lerpf(_ap[q + 4], _ac[q + 4], al))
	if absf(tilt) > 0.0001:
		put(buf, slot, Basis(Vector3.UP, yw) * Basis(Vector3.RIGHT, tilt), pos, cd)
	else:
		put_yaw(buf, slot, yw, _ac[q + 5], pos, cd)


## A tick's pose for every animal becomes the newer tick (the old newer becomes the older) and the
## buffers are drawn at the older one, where the last glide left them. `snap` (setup, rest) puts both
## at the new pose: nothing to cross.
func _write(snap := false) -> void:
	# the node follows the herd: visibility range and culling are judged from the node, and a herd
	# that grazed or fled 40 m from its spawn point stopped drawing while it stood in plain view
	var mid := Vector3.ZERO
	for a in animals:
		mid += a.pos as Vector3
	if not animals.is_empty():
		mid /= float(animals.size())
		if not mid.is_equal_approx(position):
			position = mid
	var o := position
	if _bufs.is_empty():
		for a in animals:
			_slots[a.mesh] = int(_slots.get(a.mesh, 0)) + 1
		for k: String in mmis:
			var b := PackedFloat32Array()
			b.resize(int(_slots.get(k, 0)) * 16)
			_bufs[k] = b
	if _bl.is_empty():
		for k: String in mmis:
			_bl.append(_bufs[k])
			_bmm.append((mmis[k] as MultiMeshInstance3D).multimesh)
			_bkn.append(k)
	var na := animals.size()
	if _pc.size() != na:
		_pp.resize(na)
		_pc.resize(na)
		_ap.resize(na * 6)
		_ac.resize(na * 6)
		_amk.resize(na)
		snap = true
	# our own boxes from the positions we know (the automatic box can go stale on Metal)
	var box := {}
	_bm.clear()
	var vmax := 0.0
	for i in na:
		var a: Dictionary = animals[i]
		var p: Vector3 = a.pos
		var st := int(a.state)
		var gait := float(a.gait)
		var lift := 0.0
		var tilt := 0.0
		if st == FLEE:
			lift = absf(sin(gait)) * bound * clampf(float(a.speed) / maxf(run_speed, 0.1), 0.0, 1.0)
			tilt = sin(gait + 1.2) * 0.08
		elif st == POUNCE:
			var k := clampf(float(a.k), 0.0, 1.0)
			lift = sin(k * PI) * 0.85
			tilt = lerpf(0.75, -1.1, k)
		elif st == STALK:
			lift = -0.04
		if st == FLEE or st == WALK or st == STALK:
			vmax = maxf(vmax, float(a.speed))
		var wp := p + Vector3(0.0, lift, 0.0)
		var q := i * 6
		# the older tick is the newer one we had; a long jump (back from hiding, a reset) is not crossed
		if snap or _pc[i].distance_to(wp) > 3.0:
			_pp[i] = wp
			_ap[q] = float(a.yaw)
			_ap[q + 1] = tilt
			_ap[q + 2] = float(a.head)
			_ap[q + 3] = gait
			_ap[q + 4] = float(a.pitch)
			_ap[q + 5] = 0.001 if st == HIDE else 1.0
		else:
			_pp[i] = _pc[i]
			for c in 6:
				_ap[q + c] = _ac[q + c]
			if absf(gait - _ap[q + 3]) > PI * 8.0:
				_ap[q + 3] = gait               # the stride counter wrapped: do not spin the legs back
		_pc[i] = wp
		_ac[q] = float(a.yaw)
		_ac[q + 1] = tilt
		_ac[q + 2] = float(a.head)
		_ac[q + 3] = gait
		_ac[q + 4] = float(a.pitch)
		_ac[q + 5] = 0.001 if st == HIDE else 1.0
		var mk: String = a.mesh
		var mi := _bkn.find(mk)
		_amk[i] = mi
		_draw_row(_bufs[mk], int(a.slot), i, 0.0, o)
		var moved := not _pp[i].is_equal_approx(_pc[i])
		if not moved:
			for c in 5:
				if not is_equal_approx(_ap[q + c], _ac[q + c]):
					moved = true
					break
		if moved:
			_bm.append(i)
		for v: Vector3 in [_pp[i] - o, _pc[i] - o]:
			box[mk] = AABB(v, Vector3.ZERO) if not box.has(mk) else (box[mk] as AABB).expand(v)
	var grow := 1.2 if kind != "rat" and kind != "fox" else 0.5
	var tall := 2.6 * (1.75 if kind == "elk" else 1.0)
	for k: String in mmis:
		var b: AABB = box.get(k, AABB())
		commit((mmis[k] as MultiMeshInstance3D).multimesh, _bufs[k], AABB(b.position - Vector3(grow, 0.3, grow), b.size + Vector3(grow * 2.0, tall, grow * 2.0)))


const LifePlace := preload("res://core/life/wildlife/life_place.gd")
