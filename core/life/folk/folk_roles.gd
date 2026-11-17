extends RefCounted
## What each of the folk does (folk_actor.gd asks `tick` every frame it is awake). A role sets the person's goal and
## speed, the act to pose, where to face; the actor does the rest. Roles:
##   sweeper     sweeps a doorstep in long strokes, pauses to straighten and look out
##   porter      carries a sack between two points, waits at each end
##   waterbearer carries a bucket between the well and a door
##   kid_*       three children: a game of tag round the green (the one who is it chases, the others dodge and flip
##               direction; a tag is a cheer) alternating with hide and seek (the seeker counts with eyes covered,
##               the others run to the braziers and crouch, the seeker visits each spot and finds them)
##   watchman    a slow round of the green with a lantern, stopping at the braziers to raise it and peer out
##   fiddler     plays a tune on the Keg's step, rests between tunes
##   dancer      dances to the fiddle round a small ring, stands and listens when he rests
##   mourner     kneels at the graves, now and then rises and stands a while
##   netmender   mends a net on her knees
##   talk_a/b    two people on logs, in talk: the speaker's hands tell it, the other nods
## Every person: a wave at the wanderer in front and near (more often the better the village regards him), a nod to
## anyone passing, the eclipse (a look up, a hand to the chest), and the alarm (everyone runs for the Keg). Static.
const Cast := preload("res://core/life/village/village_cast.gd")

const GREEN := Vector2(0.0, 33.0)          ## the green round the spawn brazier
const RING := 4.3                          ## the children's ring
const ROUND := 6.3                         ## the watchman's


static func node_pos(id: String, fallback: Vector2) -> Vector2:
	var n: Dictionary = Cast.NODES
	return n.get(id, fallback)


static func ring_point(r: float, ang: float) -> Vector2:
	return GREEN + Vector2(cos(ang), sin(ang)) * r


static func init(a: Variant) -> void:
	a.act = "stand"
	a.data["soc_t"] = float(absi(hash(a.id)) % 100) * 0.01


static func tick(a: Variant, dt: float) -> void:
	var ctx: Dictionary = a.ctx
	if bool(ctx.get("alarm", false)):
		_flee(a)
		return
	_social(a, dt)
	if float(ctx.get("eclipse", 0.0)) > 0.5:
		a.has_goal = false
		a.act = "eclipse"
		a.face = float(ctx.get("moon_yaw", 0.0))
		return
	match String(a.role):
		"sweeper":
			_sweeper(a)
		"porter":
			_shuttle(a, "sack")
		"waterbearer":
			_shuttle(a, "bucket")
		"watchman":
			_watchman(a, dt)
		"fiddler":
			_fiddler(a, dt)
		"dancer":
			_dancer(a, dt)
		"mourner":
			_mourner(a)
		"netmender":
			a.act = "mend"
			a.has_goal = false
		"talk_a", "talk_b":
			_talker(a, dt)
		"kid":
			pass                                     # the game moves the children (Roles.game, run by the stage)


## Everyone runs for the Keg's door when the alarm is up (the Gloom tide); the stage hides whoever arrives.
static func _flee(a: Variant) -> void:
	var door: Vector2 = node_pos("keg_in", Vector2(17.6, 23.6))
	a.goal = door
	a.has_goal = true
	a.speed = 3.4
	a.act = "run"
	if Vector2(a.global_position.x, a.global_position.z).distance_to(door) < 1.2:
		a.hold(true)


## The wave and the nod, decided twice a second (a few distance tests), played as overlays.
static func _social(a: Variant, dt: float) -> void:
	var soc: float = float(a.data.get("soc_t", 0.0)) - dt
	if soc > 0.0:
		a.data["soc_t"] = soc
		return
	a.data["soc_t"] = 0.5
	var ctx: Dictionary = a.ctx
	var pp: Vector3 = ctx.get("player", Vector3.INF)
	var me: Vector3 = (a as Node3D).global_position
	if pp != Vector3.INF and float(a.wave_cd) <= 0.0 and float(a.wave_t) <= 0.0 and String(a.act) != "run" and String(a.act) != "mourn":
		var d := me.distance_to(pp)
		var front: float = (pp - me).normalized().dot(-(a as Node3D).global_basis.z)
		if d < 9.0 and d > 2.0 and front > 0.2:
			# the better the village regards him, the readier the wave (0.3 of the time with no regard, nearly always at full)
			var chance := 0.3 + 0.65 * float(ctx.get("regard", 0.0))
			if randf() < chance:
				a.start_wave()
			else:
				a.wave_cd = 20.0
	if float(a.nod_t) <= 0.0:
		for o: Variant in ctx.get("folk", []):
			if o != a and o.awake and not o.held and (o as Node3D).global_position.distance_to(me) < 2.6 and (o.spd > 0.3 or a.spd > 0.3):
				a.start_nod()
				break


# --- the roles -------------------------------------------------------------------------------------

static func _sweeper(a: Variant) -> void:
	a.has_goal = false
	a.face = PI
	var c := fposmod(float(a._t), 30.0)
	a.act = "sweep" if c < 22.0 else "stand"


## Between two points with a wait at each: `home` (where it starts) and `other` (set by the stage).
static func _shuttle(a: Variant, carry: String) -> void:
	var d: Dictionary = a.data
	var home: Vector2 = d.get("home", Vector2.ZERO)
	var other: Vector2 = d.get("other", home)
	var here := Vector2(a.global_position.x, a.global_position.z)
	var to_other: bool = bool(d.get("to_other", true))
	var tgt := other if to_other else home
	var wait: float = float(d.get("wait", 0.0))
	if wait > 0.0:
		d["wait"] = wait - get_dt(a)
		a.has_goal = false
		a.act = "stand"
		return
	if here.distance_to(tgt) < 0.25:
		d["to_other"] = not to_other
		d["wait"] = 4.0 + float(absi(hash(a.id)) % 5)
		a.has_goal = false
		a.act = "stand"
		return
	a.goal = tgt
	a.has_goal = true
	a.speed = 1.15
	a.act = carry


static func get_dt(a: Variant) -> float:
	return minf(float((a as Node).get_process_delta_time()), 0.1)


static func _watchman(a: Variant, dt: float) -> void:
	var d: Dictionary = a.data
	var here := Vector2(a.global_position.x, a.global_position.z) - GREEN
	var ang := atan2(here.y, here.x)
	var stop: float = float(d.get("stop", 0.0))
	if stop > 0.0:
		# at a brazier: the lantern raised and the head sweeping, then on
		d["stop"] = stop - dt
		a.has_goal = false
		a.act = "lantern"
		d["len"] = 4.4
		a.face = atan2(-cos(ang), -sin(ang))             # looking outward over the green
		return
	a.act = "walk"
	a.speed = 0.85
	a.goal = ring_point(ROUND, ang + 0.35)               # always a little ahead round the ring: a steady circuit
	a.has_goal = true
	var until: float = float(d.get("until", 6.0)) - dt
	d["until"] = until
	if until <= 0.0:
		d["until"] = 14.0 + float(absi(hash(a.id)) % 6)
		d["stop"] = 4.4


static func _fiddler(a: Variant, dt: float) -> void:
	a.has_goal = false
	a.act = "fiddle"
	var c := fposmod(float(a._t), 54.0)
	var playing := c < 42.0
	a.phase = move_toward(float(a.phase), 1.0 if playing else 0.0, dt * 0.9)
	a.ctx["music"] = float(a.phase)
	a.face = float(a.data.get("face", 0.0))


static func _dancer(a: Variant, dt: float) -> void:
	var d: Dictionary = a.data
	var home: Vector2 = d.get("home", Vector2.ZERO)
	var music: float = float(a.ctx.get("music", 0.0))
	if music > 0.5:
		var ang: float = float(d.get("ang", 0.0)) + dt * 0.8
		d["ang"] = ang
		a.goal = home + Vector2(cos(ang), sin(ang)) * 0.9
		a.has_goal = true
		a.speed = 0.75
		a.act = "dance"
	else:
		a.goal = home
		a.has_goal = true
		a.speed = 0.6
		a.act = "stand"
		a.face = float(d.get("face", 0.0))


static func _mourner(a: Variant) -> void:
	a.has_goal = false
	a.face = float(a.data.get("face", 0.0))
	var c := fposmod(float(a._t), 70.0)
	a.act = "mourn" if c < 58.0 else "stand"


## A seated pair: one speaks for a few seconds while the other listens, then they swap.
static func _talker(a: Variant, dt: float) -> void:
	var d: Dictionary = a.data
	a.has_goal = false
	a.act = "sit_talk"
	a.face = float(d.get("face", 0.0))
	d["seat"] = 0.46
	if String(a.role) == "talk_a":
		var left: float = float(d.get("turn", 3.0)) - dt
		var a_speaks: bool = bool(d.get("a_speaks", true))
		if left <= 0.0:
			a_speaks = not a_speaks
			left = randf_range(3.5, 7.0)
			d["a_speaks"] = a_speaks
		d["turn"] = left
		a.ctx["talk_a"] = a_speaks
	var speaks: bool = bool(a.ctx.get("talk_a", true)) == (String(a.role) == "talk_a")
	var tgt := 1.0 if speaks else 0.0
	d["talk"] = lerpf(float(d.get("talk", 0.0)), tgt, 1.0 - exp(-4.0 * dt))


# --- the children's games --------------------------------------------------------------------------

## Run by the stage every frame the children are awake. `kids` are the three FolkActors (role "kid"); `g` is the game's
## state (a Dictionary kept by the stage). Tag, then hide and seek, then tag.
static func game(kids: Array, g: Dictionary, dt: float) -> void:
	if bool(kids[0].ctx.get("alarm", false)):
		return
	g["t"] = float(g.get("t", 0.0)) + dt
	if float(kids[0].ctx.get("eclipse", 0.0)) > 0.5:
		for k: Variant in kids:
			k.has_goal = false
			k.act = "eclipse"
			k.face = float(k.ctx.get("moon_yaw", 0.0))
		return
	var mode: String = g.get("mode", "tag")
	if mode == "tag":
		_tag(kids, g, dt)
		if float(g.t) > 70.0:
			g["mode"] = "seek"
			g["t"] = 0.0
			g["stage"] = "count"
			g["spot"] = 0
	else:
		_seek(kids, g, dt)
		if float(g.t) > 80.0 or String(g.get("stage", "")) == "done":
			g["mode"] = "tag"
			g["t"] = 0.0
			g["it"] = (int(g.get("it", 0)) + 1) % 3
			g["pause"] = 0.0


static func _pos2(k: Variant) -> Vector2:
	return Vector2(k.global_position.x, k.global_position.z)


static func _tag(kids: Array, g: Dictionary, dt: float) -> void:
	var it: int = int(g.get("it", 0))
	var pause: float = float(g.get("pause", 0.0))
	if pause > 0.0:
		# a tag: a cheer, then the one who was tagged is it
		g["pause"] = pause - dt
		for i in 3:
			kids[i].has_goal = false
			kids[i].act = "caught"
		return
	var chaser: Variant = kids[it]
	# the nearest of the others, and the runners' dodges
	var best := 1e9
	var prey := -1
	for i in 3:
		if i == it:
			continue
		var d2 := _pos2(chaser).distance_to(_pos2(kids[i]))
		if d2 < best:
			best = d2
			prey = i
	chaser.goal = _pos2(kids[prey])
	chaser.has_goal = true
	chaser.speed = 3.0
	chaser.act = "run"
	var flip: float = float(g.get("flip", 0.0)) - dt
	var dir: float = float(g.get("dir", 1.0))
	if (best < 1.9 and flip <= 0.0) or flip < -6.0:
		dir = -dir
		g["dir"] = dir
		flip = 1.2
	g["flip"] = flip
	for i in 3:
		if i == it:
			continue
		var kid: Variant = kids[i]
		var here := _pos2(kid) - GREEN
		var ang := atan2(here.y, here.x)
		var rad := RING + 0.5 * float(i)
		kid.goal = ring_point(rad, ang + dir * (0.8 if i == 1 else -0.8))
		kid.has_goal = true
		kid.speed = 2.7
		kid.act = "run"
	if best < 0.9:
		g["pause"] = 1.8
		g["it"] = prey


static func _seek(kids: Array, g: Dictionary, dt: float) -> void:
	var it: int = int(g.get("it", 0))
	var seeker: Variant = kids[it]
	var stage: String = g.get("stage", "count")
	var spots: Array = []
	for b: String in ["brazier_w", "brazier_e", "brazier_n"]:
		var bp := node_pos(b, GREEN)
		spots.append(bp + (bp - GREEN).normalized() * 1.1)
	var hiders: Array = []
	for i in 3:
		if i != it:
			hiders.append(kids[i])
	match stage:
		"count":
			var cp := node_pos("brazier_s", GREEN + Vector2(-0.6, -2.3))
			seeker.goal = cp + (cp - GREEN).normalized() * 0.8
			seeker.has_goal = true
			seeker.speed = 2.2
			seeker.face = atan2(-(GREEN.x - cp.x), -(GREEN.y - cp.y))
			var near := _pos2(seeker).distance_to(seeker.goal) < 0.5
			seeker.act = "count" if near else "run"
			if near:
				g["count"] = float(g.get("count", 0.0)) + dt
			for j in hiders.size():
				var h: Variant = hiders[j]
				h.goal = spots[j]
				h.has_goal = true
				h.speed = 3.0
				var there := _pos2(h).distance_to(spots[j]) < 0.35
				h.act = "hide" if there else "run"
				if there:
					h.face = atan2(-(spots[j] as Vector2).x + GREEN.x, -(spots[j] as Vector2).y + GREEN.y)
			if float(g.get("count", 0.0)) > 9.0:
				g["stage"] = "search"
				g["spot"] = 0
				g["wait"] = 0.0
				g["found"] = 0
		"search":
			var si: int = int(g.get("spot", 0))
			if si >= spots.size():
				g["stage"] = "found"
				g["wait"] = 0.0
				return
			var sp: Vector2 = spots[si]
			seeker.goal = sp + (GREEN - sp).normalized() * 1.0
			seeker.has_goal = true
			seeker.speed = 1.5
			var close := _pos2(seeker).distance_to(seeker.goal) < 0.45
			seeker.act = "stand" if close else "walk"
			if close:
				var w: float = float(g.get("wait", 0.0)) + dt
				g["wait"] = w
				seeker.face = atan2(-(sp.x - seeker.global_position.x), -(sp.y - seeker.global_position.z))
				if w > 2.2:
					var h2: Variant = hiders[si] if si < hiders.size() else null
					if h2 != null:
						h2.act = "caught"
						h2.has_goal = false
					g["wait"] = 0.0
					g["spot"] = si + 1
		"found":
			var w2: float = float(g.get("wait", 0.0)) + dt
			g["wait"] = w2
			for i in 3:
				kids[i].has_goal = false
				kids[i].act = "caught"
			if w2 > 2.5:
				g["stage"] = "done"
