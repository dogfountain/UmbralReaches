class_name RealmRelief
extends RefCounted
## The Realm's relief at the large scale (the vistas pass): the shapes that make the doubled Realm read from a
## ridge or a road bend. RealmLayout.macro_dry calls these; everything here is pure math on xz, thread-safe.
##
## - horizon(): the ring beyond BOUNDS is a mountain range, not a uniform 28 m swell: a crest that rises and
##   falls round the map (saddles, peaks, taller corners), and passes where the world runs on: the road's west
##   and east ends (the Last Milestone, the shut East Gate) and the Sorrow's gorge out of the Reedmere.
##   The Crowns (north) keep their own wall; the range takes over round the other three sides.
## - scarp(): the downs' south edge (RealmReaches.SCARP_Z) is an escarpment, not a 40 m ramp: a lip, a face
##   steep enough for the ground shader's cliff rock and the strata ledges, a talus foot; the line wanders
##   (spurs and combes), and where a way goes down it becomes a combe with a gentler fall.
## The rectangles of earlier landforms are warped at their source (RealmLayout._mwarp on their rects).

const SCARP_LINE := 263.0           ## the face's middle (z), before its wander
const SCARP_DROP := 7.0             ## what RealmReaches.shape takes off over SCARP_Z (it stays the floor's height)
const LIP := 3.6                    ## the crest the downs rise to before the fall
const FACE := 15.0                  ## the face's depth (m of z) away from the ways
const COMBE := 52.0                 ## and where a way goes down it
const PASSES := [                   ## [xz on the edge, half width, depth (0..1 of the range's rise)]
	[Vector2(-370.0, 52.0), 46.0, 0.72],     # the road's west end, past the Last Milestone
	[Vector2(370.0, 60.0), 40.0, 0.78],      # behind the shut East Gate
	[Vector2(-330.0, 398.0), 36.0, 0.86],    # the Sorrow's gorge out of the Reedmere
]

static var _n_crest: FastNoiseLite
static var _n_peak: FastNoiseLite


static func _init_noise() -> void:
	if _n_crest != null:
		return
	var a := FastNoiseLite.new()
	a.seed = 9137
	a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	a.frequency = 0.011
	a.fractal_type = FastNoiseLite.FRACTAL_FBM
	a.fractal_octaves = 3
	var b := FastNoiseLite.new()
	b.seed = 4410
	b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	b.frequency = 0.015
	b.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	b.fractal_octaves = 3
	_n_peak = b
	_n_crest = a


## Height the horizon ring adds at p, out metres outside BOUNDS (0 inside). The old ring was
## smoothstep(0, 60, out) * 28 everywhere; the first ~12 m keep that (the edge rims and the invisible walls
## stand on it), then the range climbs to its crest, which varies along the edge.
static func horizon(p: Vector2, out: float) -> float:
	var base := smoothstep(0.0, 60.0, out) * 28.0
	if out <= 0.0:
		return 0.0
	_init_noise()
	var b := RealmLayout.BOUNDS
	# the Crowns are the north wall already: the range fades in from their foot
	var north := smoothstep(b.position.y + 10.0, b.position.y + 70.0, p.y)
	# a crest along the edge: rises and falls (saddles, shoulders), with ridged peaks on it
	var c := _n_crest.get_noise_2d(p.x, p.y) * 0.5 + 0.5
	var pk := _n_peak.get_noise_2d(p.x * 0.8, p.y * 0.8)
	var crest := 22.0 + 30.0 * smoothstep(0.25, 0.85, c) + 16.0 * maxf(pk, 0.0)
	# the corners stand tallest (the south-west and south-east teeth; the north corners are the Crowns')
	var cx := absf(p.x) - b.end.x
	var cz := p.y - b.end.y
	var corner := smoothstep(-80.0, 10.0, minf(cx, cz))
	crest += 22.0 * corner
	# the crest stands 40-75 m out (the ring ends 92 m out): a foreslope, then the ridge line
	var at := lerpf(40.0, 75.0, c)
	var rise := smoothstep(6.0, at, out)
	rise = 1.0 - (1.0 - rise) * (1.0 - rise)
	var range_h := crest * rise
	# passes where the world runs on out of the map
	var gap := 0.0
	for ps: Array in PASSES:
		var e: Vector2 = ps[0]
		var along := absf(p.y - e.y) if absf(e.x) >= b.end.x - 1.0 else absf(p.x - e.x)
		gap = maxf(gap, float(ps[2]) * (1.0 - smoothstep(float(ps[1]) * 0.35, float(ps[1]), along)))
	range_h *= 1.0 - gap
	return lerpf(base, maxf(base * 0.7, range_h), north) if north < 1.0 else maxf(base * (1.0 - gap * 0.6), range_h)


## The downs' south scarp, over what RealmReaches.shape made (it took SCARP_DROP off across SCARP_Z for
## |x| < 155, fading by 180). This puts that same drop back over a short face on a wandering line and adds the
## lip; the floor below and the downs above keep the heights they had.
static func scarp(p: Vector2, h: float, m: float) -> float:
	var x := p.x
	var z := p.y
	if m <= 0.0 or z < 200.0 or z > 330.0:
		return h
	var wide := 1.0 - smoothstep(0.0, 25.0, maxf(absf(x) - 155.0, 0.0))
	if wide <= 0.0:
		return h
	var sz := RealmReaches.SCARP_Z
	var was := SCARP_DROP * smoothstep(sz.x, sz.y, z)
	# the line wanders: spurs out over the floor and combes back into the downs
	var line := SCARP_LINE + 7.0 * sin(x * 0.043 + 0.6) + 4.0 * sin(x * 0.117 - 1.3) + 2.0 * sin(x * 0.29 + 0.2)
	var near_way := 1.0 - smoothstep(10.0, 42.0, RealmLayout.path_dist(p))
	var face := lerpf(FACE, COMBE, near_way)
	var t := clampf((z - (line - face * 0.5)) / face, 0.0, 1.0)
	# a steep upper face and a talus foot that runs out over the floor
	var fall := 1.0 - pow(1.0 - t, 1.6)
	var now := SCARP_DROP * fall
	var lip := LIP * exp(-pow((z - (line - face * 0.5 - 4.0)) / 7.0, 2.0)) * (1.0 - near_way * 0.8)
	return h + m * wide * ((was - now) + lip)
