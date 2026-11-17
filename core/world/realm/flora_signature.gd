extends RefCounted
## Each region's own flower (the world pass: "lavender everywhere" is over). The flowers' plants are one family of
## meshes and one purple texture; the colour of a place is a multiplier on that texture, so each region gets its
## own signature hue: the Lanternwood's cold blue bells, the Southwood's rust-orange, Fallowmere's poppies, the
## Reedmere's marsh gold, the Cairns' pale grey-white, the Nave's sick teal, the Kings' Barrows' ling pink, the
## Greyfell's snow-white, the Arches' broom yellow, Lastlight's warm cream; in the old valley the glade's moon-white,
## the moor's gorse gold, the holds' heather magenta, the fen's marsh blue. Anywhere else the plain purple stays.
## A per-cell colour (4 m cells, like the grass tint in RealmFlora._tc) blended over 20 m at a region's edge: computed
## once per Realm build (cached with the flora), nothing at runtime. No class_name: preload by path.

## [rect, multiplier] (the texture is a violet near (0.5, 0.3, 0.8): the multiplier is chosen for the result)
const TABLE := [
	[Rect2(-370, -50, 110, 118), Color(0.45, 1.25, 1.65)],        # the Lanternwood: cold blue bells
	[Rect2(92, 240, 170, 158), Color(1.75, 1.3, 0.38)],           # the Southwood: rust and amber
	[Rect2(-220, 240, 128, 158), Color(1.9, 0.38, 0.45)],         # Fallowmere: poppy red
	[Rect2(-370, 236, 150, 162), Color(1.9, 1.9, 0.45)],          # the Reedmere: marsh gold
	[Rect2(260, 234, 110, 164), Color(1.9, 1.9, 2.0)],            # the Thousand Cairns: pale grey-white
	[Rect2(260, 96, 110, 138), Color(0.4, 1.6, 1.35)],            # the Drowned Nave: sick teal
	[Rect2(-370, 68, 110, 168), Color(1.6, 0.62, 1.0)],           # the Kings' Barrows: ling pink
	[Rect2(-370, -150, 110, 100), Color(1.85, 1.9, 2.0)],         # the Greyfell: snow-white
	[Rect2(-92, 240, 184, 158), Color(1.7, 1.5, 0.28)],           # the Long Arches: broom yellow
	[Rect2(260, -40, 110, 136), Color(1.8, 1.5, 1.0)],            # Lastlight: warm cream
	[Rect2(-58, -2, 40, 40), Color(1.7, 1.8, 2.0)],               # the glade: moon-white
	[Rect2(124, -66, 31, 106), Color(1.9, 1.75, 0.4)],            # the moor: gorse gold
	[Rect2(-152, -6, 36, 36), Color(1.55, 0.5, 1.05)],            # the Rooted Holds: heather magenta
	[Rect2(52, -60, 56, 40), Color(0.7, 1.3, 1.9)],               # the barrow fen: marsh blue
]
const FEATHER := 20.0


static func flower_tint(x: float, z: float) -> Color:
	var col := Color(1.0, 1.0, 1.0)
	for e: Array in TABLE:
		var r: Rect2 = e[0]
		var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
		var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
		var w := 1.0 - smoothstep(0.0, FEATHER, sqrt(dx * dx + dz * dz))
		if w > 0.0:
			col = col.lerp(e[1] as Color, w)
	return col
