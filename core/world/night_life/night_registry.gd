extends RefCounted
## The night's light sources, one shared table ("navigate the night by light"). Every landmark, settlement,
## window, fire and mystery that should be seen from far away is a row here; LightSignatures draws the far cards and
## the ground pools from it, FixturePool lends real lights to the nearest rows, LivingWindows and MysteryLights
## switch rows on and off. Parallel arrays (no node per source); a row is never removed, only switched off.
## Also the night clock (0 .. 1 over NIGHT_LEN seconds) every system reads.

enum Kind { FIRE, WINDOW, MYSTERY, TOWER, COLD }

const NIGHT_LEN := 1500.0                 ## s: one night, dusk to the grey before dawn, then it comes round again
const START_T := 0.1

static var enabled := true                ## Settings.night_life, mirrored once a second by NightLife
static var clock := START_T               ## 0 .. 1
static var moon_gain := 1.0               ## the moon's phase: its light scales by this (0.6 at a new moon, 1 at full; sky_life.gd)
static var haze := 0.0                    ## 0..1 mist and rain in the air: far cards swell into halos (weather_life.gd)
static var rain := 0.0                    ## 0..1 rain falling: fires gutter and spit
static var gust := 0.0                    ## wind with its gusts: fires lean and flicker harder
static var indoor := 0.0                  ## 0..1 the camera is in a room (Interiors), eased: the outdoor night's mist, moths and pools fade out at the door
static var arena_dim := 1.0               ## a boss arena in use dims the moon to two thirds (arena_light.gd)
static var pulse := 0.0                   ## 0..1 a moment of light (a level, a boss phase) flaring every card; decays by itself
static var flash := 0.0                   ## 0..1 lightning: every landmark flares for the flash
static var gain_mul := 1.0                ## the whole landmark set's brightness: an eclipse raises it, the dark makes them shine
static var pos := PackedVector3Array()    ## where the light is (a metre or so above the ground)
static var ground := PackedFloat32Array() ## the ground's y under it (the pool)
static var kind := PackedInt32Array()
static var gain := PackedFloat32Array()   ## 0 .. 1.2 strength
static var phase := PackedFloat32Array()  ## flicker / pulse offset
static var real := PackedByteArray()      ## 1: a real light already stands there (a brazier): no pool, no lent light
static var on := PackedByteArray()
static var boost := PackedFloat32Array()  ## a transient surge (a fire catching): added to the row's brightness, decays
static var keys := {}                     ## key -> row


static var _wx: Variant = null
static var _wx_ms := -100000


## The Weather node (core/life/wildlife/weather.gd), found by name once it exists: at most one search every twenty seconds
## (a find over the whole tree is not for every half second), shared by every system that reads the fronts.
static func weather(tree: SceneTree) -> Variant:
	if _wx != null and is_instance_valid(_wx):
		return _wx
	_wx = null
	var now := Time.get_ticks_msec()
	if now - _wx_ms < 20000:
		return null
	_wx_ms = now
	var root := tree.current_scene
	if root != null:
		_wx = root.find_child("Weather", true, false)
	return _wx


## The nearest lit fire (a row of kind FIRE that is on) within `reach` metres of `p`, or Vector3.INF (the owls watch the moths round it).
static func nearest_fire(p: Vector3, reach: float) -> Vector3:
	var best := reach * reach
	var at := Vector3.INF
	for i in pos.size():
		if on[i] == 0 or kind[i] != Kind.FIRE:
			continue
		var d2 := p.distance_squared_to(pos[i])
		if d2 < best:
			best = d2
			at = pos[i]
	return at


static func clear() -> void:
	pos.clear()
	ground.clear()
	kind.clear()
	gain.clear()
	phase.clear()
	real.clear()
	on.clear()
	boost.clear()
	keys.clear()
	clock = START_T
	gain_mul = 1.0


static func size() -> int:
	return pos.size()


## Add or update a row by `key`. Returns its index.
static func put(key: String, p: Vector3, k: int, g: float, ground_y: float, has_real := false, lit := true) -> int:
	var i: int = keys.get(key, -1)
	if i < 0:
		i = pos.size()
		keys[key] = i
		pos.append(p)
		ground.append(ground_y)
		kind.append(k)
		gain.append(g)
		phase.append(float(absi(hash(key)) % 1000) * 0.0063)
		real.append(1 if has_real else 0)
		on.append(1 if lit else 0)
		boost.append(0.0)
	else:
		pos[i] = p
		ground[i] = ground_y
		kind[i] = k
		gain[i] = g
		real[i] = 1 if has_real else 0
		on[i] = 1 if lit else 0
	return i


static func has(key: String) -> bool:
	return keys.has(key)


static func set_on(key: String, lit: bool) -> void:
	var i: int = keys.get(key, -1)
	if i >= 0:
		on[i] = 1 if lit else 0


static func is_on(key: String) -> bool:
	var i: int = keys.get(key, -1)
	return i >= 0 and on[i] == 1


## The colour a kind of source burns.
static func colour(k: int) -> Color:
	match k:
		Kind.FIRE:
			return Color(1.0, 0.56, 0.2)
		Kind.WINDOW:
			return Color(1.0, 0.74, 0.38)
		Kind.MYSTERY:
			return Color(0.42, 0.82, 1.0)
		Kind.TOWER:
			return Color(1.0, 0.9, 0.66)
	return Color(0.62, 0.78, 1.0)               # COLD: an unkindled fire, a pale beckoning glint


## 0 .. 1 brightness of a row at time `t` (seconds): a fire gutters, a window is steady, a mystery breathes.
static func shimmer(i: int, t: float) -> float:
	var ph: float = phase[i]
	match int(kind[i]):
		Kind.FIRE:
			var wind := 1.0 + 0.9 * gust
			return 0.86 - 0.08 * rain + (0.09 * sin(t * 7.3 + ph) + 0.05 * sin(t * 17.1 + ph * 2.0)) * wind
		Kind.MYSTERY:
			return 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 0.9 + ph)) * (0.7 + 0.3 * sin(t * 0.23 + ph * 3.0))
		Kind.COLD:
			return 0.45 + 0.35 * (0.5 + 0.5 * sin(t * 1.3 + ph))
		Kind.TOWER:
			return 0.9 + 0.1 * sin(t * 0.5 + ph)
	return 0.94 + 0.06 * sin(t * 3.1 + ph)
