extends RefCounted
## BENCHES AND SCARPS (the world pass: the Far Reaches' ground was soft dunes between landmarks). The new ground
## (outside the old Marches) is stepped, in patches: where a noise mask says so, the height is pulled towards the
## nearest multiple of a bench interval (about 2 m, varying), the way a hillside of cut terraces or tilted strata
## weathers: flat treads, short steep risers, a contour of broken ledges across a slope. Treads read as meadow
## and heath benches you can camp on; the risers are where the outcrops stand (terrain_outcrops.gd, a wonder).
## Pure math on the height grid (the build's _heights, before the carve of the ways): continuous, monotonic, no
## new triangles, no draws, no memory. Kept off the ways (30 m), the towns, the named circular regions, the water's
## edge, the Marches' border (feathered over 20 m) and the map's rim. Cached with the heights (land_cache.gd).
## No class_name: preload by path.

const WATER_Y := -0.9
const FALL_WAYS := 28.0

static var _n: FastNoiseLite
static var _m: FastNoiseLite
static var _circles: Array = []


static func _init_noise() -> void:
	if _n != null:
		return
	_n = FastNoiseLite.new()
	_n.seed = 3917
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.frequency = 0.012
	_m = FastNoiseLite.new()
	_m.seed = 5521
	_m.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_m.frequency = 0.004
	for reg: Dictionary in RealmLayout.REGIONS:
		if reg.has("c") and not reg.has("rect"):
			_circles.append([reg.c, float(reg.r)])
	for t: Array in [[Vector2(-311.0, 281.0), 42.0], [Vector2(-160.0, 300.0), 46.0], [Vector2(324.5, 53.5), 54.0]]:
		_circles.append(t)


## The height at (x, z) with the benches cut into it (h unchanged where the mask is off).
static func shape(x: float, z: float, h: float) -> float:
	_init_noise()
	var mb := RealmReaches.MARCH_BOUNDS
	var dx := maxf(maxf(mb.position.x - x, x - mb.end.x), 0.0)
	var dz := maxf(maxf(mb.position.y - z, z - mb.end.y), 0.0)
	var out_d := sqrt(dx * dx + dz * dz)
	if out_d <= 0.0:
		return h
	var k := smoothstep(0.0, 20.0, out_d)
	k *= smoothstep(WATER_Y + 0.4, WATER_Y + 2.6, h)
	if k <= 0.0:
		return h
	var mask := smoothstep(-0.05, 0.3, _n.get_noise_2d(x, z))
	if mask <= 0.0:
		return h
	k *= mask
	# keep clear of the ways, the towns and the named circular places
	k *= smoothstep(10.0, FALL_WAYS, RealmLayout.path_dist(Vector2(x, z)))
	if k <= 0.0:
		return h
	for e: Array in _circles:
		var d := (e[0] as Vector2).distance_to(Vector2(x, z)) - float(e[1])
		if d < 24.0:
			k *= smoothstep(0.0, 24.0, d)
	if k <= 0.0:
		return h
	var step_m := 1.9 + 0.9 * (_m.get_noise_2d(x, z) * 0.5 + 0.5)
	var t := h / step_m
	var fl := floorf(t)
	var fr := t - fl
	var shaped := (fl + smoothstep(0.58, 0.9, fr)) * step_m
	return lerpf(h, shaped, k * 0.9)
