extends RefCounted
## Baked bark for TreeGen trunks: furrows that meander up the trunk,
## shaded in vertex colour and tilted in the vertex normal, patches of lichen on the ridges, stains,
## stripped wood on dead trunks. Pure functions of an angle, a height along the trunk and two noise values
## (TreeGen.Gen passes them from its own noise), built once into the cached mesh: nothing is computed at
## runtime, and the far (@far) trees skip it. Edit this file and bump the rev note in tree_gen.gd, whose
## source hash is what keys the GenCache entries.

const OAK := 0          ## deep furrows, lichen on the ridges (oak, willow, yew, fruit, windtree)
const BIRCH := 1        ## smooth pale bark with dark scarred patches
const PINE := 2         ## broad plates and deep furrows
const DEAD := 3         ## weathered grey wood with stripped patches (snags, logs, stumps)

const LICHEN := Color(0.66, 0.74, 0.52)
const BARE := Color(0.78, 0.7, 0.6)


## Bark style for a species and variant.
static func style_of(sp: String, v: int) -> int:
	match sp:
		"birch":
			return BIRCH
		"pine", "cypress":
			return PINE
		"snag", "deadpine":
			return DEAD
		"log", "stump":
			return OAK if v == 0 else DEAD
	return OAK


## Sides for a trunk ring (0 = leave the caller's count: thin trunks and saplings keep theirs).
static func trunk_sides(r: float) -> int:
	if r < 0.15:
		return 0
	return clampi(roundi(r * 26.0) + 8, 10, 20)


## The tint a style's patches blend toward.
static func tint(st: int) -> Color:
	return BARE if st == DEAD else LICHEN


## (radius multiplier, normal tilt along the ring, brightness, patch amount) at ring angle `a`, `along`
## metres up the trunk. `ph` is the trunk's phase, n1 a slow 3D noise (patches), n2 a ring-periodic noise
## (the furrows' meander). The ring seam stays closed: every term is periodic in `a`.
static func detail(st: int, a: float, along: float, ph: float, n1: float, n2: float) -> Vector4:
	var n := 7.0
	var depth := 0.09
	match st:
		BIRCH:
			n = 5.0
			depth = 0.016
		PINE:
			n = 5.0
			depth = 0.13
		DEAD:
			n = 6.0
			depth = 0.11
	var arg := a * n + ph + (n2 - 0.5) * 3.4 + sin(along * 0.45 + ph) * 0.8
	var u := 0.5 + 0.5 * sin(arg)
	if st == DEAD:
		u = u * u
	var ridge := u * u * (3.0 - 2.0 * u)
	var mult := 1.0 - depth * (1.0 - ridge)
	var slope := depth * n * 0.5 * cos(arg) * 6.0 * u * (1.0 - u) / mult
	var shade := 1.0
	var patch := 0.0
	match st:
		OAK:
			shade = lerpf(0.7, 1.1, ridge) * lerpf(0.88, 1.1, n2)
			patch = smoothstep(0.64, 0.8, n1) * 0.55 * (0.35 + 0.65 * ridge)
		BIRCH:
			shade = (1.0 - 0.5 * smoothstep(0.56, 0.7, n1)) * lerpf(0.88, 1.0, ridge)
		PINE:
			shade = lerpf(0.62, 1.1, ridge) * lerpf(0.9, 1.1, n2)
			patch = smoothstep(0.72, 0.86, n1) * 0.3
		DEAD:
			var strip := smoothstep(0.6, 0.68, n1)
			shade = lerpf(0.66, 1.02, ridge) * lerpf(0.82, 1.08, n2)
			patch = strip * 0.6
			mult += 0.025 * strip
	return Vector4(mult, slope, shade, patch)
