class_name RealmReaches
extends RefCounted
## The Far Reaches (docs/far_reaches.md): the Realm doubled again, from 520 x 390 m (the Outer Marches and the
## Southern Downs, MARCH_BOUNDS) to 740 x 548 m (RealmLayout.BOUNDS: x -370..370, z -150..398). A ring of new
## country round the Marches: the West Reach beyond the Sorrow, the East Reach beyond the Pans and the
## Anchorholds, the Deep South below the downs' scarp. The Crowns stay the north wall the whole width.
##
## This file is the contract for that ground, the way RealmLayout is for the rest: RealmLayout appends REGIONS,
## PATHS, SLOTS, MEANDER and IDS to its own tables and calls shape() for the landform. Nothing inside
## MARCH_BOUNDS moves except where the new ground meets it (the downs fall away south in a scarp; the Sorrow runs
## on to the new south edge). No class here references RealmLayout's constants (they reference these).

const MARCH_BOUNDS := Rect2(-260.0, -150.0, 520.0, 390.0)    ## the Marches' Realm (the Outer Marches and the downs)

## Regions (RealmLayout.REGIONS' schema). Tiers rise with the distance from Hearthward, one step past the Marches:
## the country round the towns 2 (the towns themselves are safe places: SpawnRules.SAFE), the wild between them 3,
## the far corners 4 (the Greyfell, the Bellfall, the Thousand Cairns). Tiers.REGION_BASE keeps the same numbers.
const REGIONS := [
	# --- the West Reach (beyond the Sorrow) ---------------------------------------------------------------
	{"id": "greyfell", "name": "The Greyfell", "rect": Rect2(-370, -150, 110, 100), "blobs": [{"c": Vector2(-272, -66), "r": 16.0}], "biome": "crag", "tier": 4,
		"purpose": "a high grey fell at the Crowns' west corner; the Order's Broken Keep on its crag, a garrison that never stood down",
		"lore": "The Order's last keep in the west watched the pass for a sky that never came. Its garrison still keeps the watch."},
	{"id": "lanternwood", "name": "The Lanternwood", "rect": Rect2(-370, -50, 110, 118), "biome": "oldforest", "tier": 3,
		"purpose": "a deep old wood where cold fungus lights the ground blue; wisps, a ring of giant caps, the road's last milestone",
		"lore": "Nothing burns in the Lanternwood and nothing needs to. The light grows out of the dead."},
	{"id": "kingsbarrows", "name": "The Kings' Barrows", "rect": Rect2(-370, 68, 110, 168), "biome": "heath", "tier": 3,
		"purpose": "a long heather ridge of great barrows and a stone row; the King's Barrow is open",
		"lore": "Before the Order, before the Rooted, kings were laid on this ridge with their faces to the west. One door stands open."},
	{"id": "reedmere", "name": "The Reedmere", "rect": Rect2(-370, 236, 150, 162), "biome": "fen", "tier": 3,
		"purpose": "where the Sorrow spreads into reed meres; Reedholm's stilt-houses and the heron fishers",
		"lore": "The Sorrow loses its banks here and forgets it was a river. The Reedholm folk fish it by lamp."},
	# --- the Deep South (below the downs' scarp) -----------------------------------------------------------
	{"id": "fallow", "name": "Fallowmere", "rect": Rect2(-220, 240, 128, 158), "biome": "meadow", "tier": 2,
		"purpose": "a farming hamlet in the low fields: the tithe barn, the fold, hedged strips gone to seed",
		"lore": "Fallowmere grew the Order's bread. Half its fields are fallow now, and the other half are graves."},
	{"id": "arches", "name": "The Long Arches", "rect": Rect2(-92, 240, 184, 158), "biome": "heath", "tier": 3,
		"purpose": "the Order's great aqueduct striding across a dry valley; its castellum and the broken span",
		"lore": "The Order carried the Crowns' snow south to the fields on a road of arches. The water stopped when the sky did."},
	{"id": "southwood", "name": "The Southwood", "rect": Rect2(92, 240, 170, 158), "biome": "oldforest", "tier": 3,
		"purpose": "a dark wood of hollies and oaks; the charcoal burners' ruin, the witch's hollow, the things that hunt it",
		"lore": "The charcoal burners stayed when the town went north. Their stacks still smoke on nights without wind."},
	# --- the East Reach (beyond the Pans and the Anchorholds) ----------------------------------------------
	{"id": "bellfall", "name": "The Bellfall", "rect": Rect2(306, 84, 64, 38), "biome": "crag", "tier": 3,
		"purpose": "a crater in the fields under Lastlight's south wall where the eighth bell came down: the bell, cracked, half sunk in scorched rock (the Crowns' east corner is the Stair's: Endgame)",
		"lore": "The Founder cast seven bells for the Stair. The eighth was cast in the sky, and the sky let it fall."},
	{"id": "lastlight", "name": "Lastlight", "rect": Rect2(260, -40, 110, 136), "biome": "meadow", "tier": 2,
		"purpose": "the walled waystation at the road's east end: a gate that stays shut, an inn, a watch, travellers",
		"lore": "The last lamp the pilgrims saw before the road turned to the mountain. Lastlight still lights it."},
	{"id": "nave", "name": "The Drowned Nave", "rect": Rect2(260, 96, 110, 138), "biome": "fen", "tier": 3,
		"purpose": "a cathedral the Order never finished, its nave flooded to the knee; moon shafts through the broken vault",
		"lore": "They built the nave first and the floor last. The water came in before the floor did."},
	{"id": "cairns", "name": "The Thousand Cairns", "rect": Rect2(260, 234, 110, 164), "biome": "heath", "tier": 4,
		"purpose": "a high windy heath of cairns, one for every pilgrim who turned back; the Cairn Tower at its crown",
		"lore": "Every stone is a pilgrim who turned for home. Nobody has counted them, and nobody should."},
]

## The new regions' ids (RealmLayout appends them to MARCHES_IDS: their names meet along long waves).
const IDS := ["greyfell", "lanternwood", "kingsbarrows", "reedmere", "fallow", "arches", "southwood", "bellfall", "lastlight", "nave", "cairns"]

## Suggested slots (RealmLayout.SLOTS' schema; checked by zz/layout_r34_test). Builders may move a slot a few
## metres; a region agent edits only its own regions' entries.
const SLOTS := {
	"greyfell": [
		{"kind": "fire", "at": Vector2(-310, -66), "note": "fell_track's head, under the keep's crag"},
		{"kind": "poi", "at": Vector2(-318, -108), "note": "the Broken Keep on its crag"},
		{"kind": "poi", "at": Vector2(-281, -122), "note": "the fell shrine under the Crowns"},
		{"kind": "camp", "at": Vector2(-337, -101), "note": "the keep's west bailey (on its terrace)"},
		{"kind": "camp", "at": Vector2(-288, -98), "note": "the scree east of the crag"}],
	"lanternwood": [
		{"kind": "fire", "at": Vector2(-292, 14), "note": "beside fell_track in a lit clearing"},
		{"kind": "poi", "at": Vector2(-330, -8), "note": "the ring of giant caps"},
		{"kind": "poi", "at": Vector2(-350, 44), "note": "the Last Milestone at the road's west end"},
		{"kind": "camp", "at": Vector2(-295, 44), "note": "the deep wood"},
		{"kind": "camp", "at": Vector2(-282, -30), "note": "the wood's north edge"}],
	"kingsbarrows": [
		{"kind": "fire", "at": Vector2(-318, 96), "note": "barrow_track at the ridge's north end"},
		{"kind": "poi", "at": Vector2(-345, 152), "note": "the King's Barrow, its door open"},
		{"kind": "poi", "at": Vector2(-300, 128), "note": "the stone row along the ridge"},
		{"kind": "camp", "at": Vector2(-311, 170), "note": "between the barrows"},
		{"kind": "camp", "at": Vector2(-296, 196), "note": "the ridge's south shoulder"}],
	"reedmere": [
		{"kind": "fire", "at": Vector2(-316, 302), "note": "Reedholm's landing"},
		{"kind": "poi_wet", "at": Vector2(-310, 279), "note": "Reedholm's stilt-houses (the net-hall's pool)"},
		{"kind": "poi_wet", "at": Vector2(-340, 360), "note": "the heron stones in the mere"},
		{"kind": "camp", "at": Vector2(-252, 352), "note": "the east reeds"},
		{"kind": "camp", "at": Vector2(-351, 257), "note": "the north meres"}],
	"fallow": [
		{"kind": "fire", "at": Vector2(-146, 292), "note": "the hamlet's green"},
		{"kind": "poi", "at": Vector2(-164, 306), "note": "the hamlet: the tithe barn, the farmhouse, the fold"},
		{"kind": "poi", "at": Vector2(-120, 356), "note": "the drowned strips and the scarecrow field"},
		{"kind": "camp", "at": Vector2(-196, 366), "note": "the far fields"}],
	"arches": [
		{"kind": "fire", "at": Vector2(-24, 318), "note": "beside arches_way under the arches"},
		{"kind": "poi", "at": Vector2(0, 342), "note": "the Long Arches over the valley"},
		{"kind": "poi", "at": Vector2(-60, 352), "note": "the castellum, the aqueduct's water tower"},
		{"kind": "camp", "at": Vector2(30, 368), "note": "the valley floor south of the arches"},
		{"kind": "camp", "at": Vector2(60, 286), "note": "the broken span's rubble"}],
	"southwood": [
		{"kind": "fire", "at": Vector2(150, 296), "note": "beside arches_way at the wood's edge"},
		{"kind": "poi", "at": Vector2(169, 330), "note": "the charcoal burners' ruin"},
		{"kind": "poi", "at": Vector2(226, 362), "note": "the witch's hollow"},
		{"kind": "camp", "at": Vector2(120, 268), "note": "the burners' clearing"},
		{"kind": "camp", "at": Vector2(249, 290), "note": "the holly brakes"},
		{"kind": "camp", "at": Vector2(243, 260), "note": "the wood's north-east edge"}],
	"bellfall": [
		{"kind": "fire", "at": Vector2(322, 96), "note": "bellfall_way at the crater's west lip"},
		{"kind": "poi", "at": Vector2(350, 102), "note": "the fallen bell in its crater"},
		{"kind": "camp", "at": Vector2(332, 110), "note": "the crater's west lip"},
		{"kind": "camp", "at": Vector2(336, 123), "note": "the crater's south apron (outside the bell's site, 10 m+ inside BOUNDS)"}],
	"lastlight": [
		{"kind": "fire", "at": Vector2(318.5, 55.5), "note": "the town's yard, inside the gate (off bell_track)"},
		{"kind": "poi", "at": Vector2(322, 40), "note": "Lastlight: the inn, the lamp tower, the watch"},
		{"kind": "poi", "at": Vector2(356, 62.8), "note": "the shut East Gate at the road's end (on the curtain's line)"},
		{"kind": "camp", "at": Vector2(268, 16), "note": "under the rift's west berm, off bell_link"}],
	"nave": [
		{"kind": "fire", "at": Vector2(296, 112), "note": "nave_track on the mere's north shore"},
		{"kind": "poi_wet", "at": Vector2(318, 162), "note": "the Drowned Nave"},
		{"kind": "camp", "at": Vector2(349, 127), "note": "the east shore"},
		{"kind": "camp", "at": Vector2(289, 207), "note": "the south shore"}],
	"cairns": [
		{"kind": "fire", "at": Vector2(300, 286), "note": "southwood_way's end on the heath"},
		{"kind": "poi", "at": Vector2(327, 324), "note": "the Cairn Tower"},
		{"kind": "camp", "at": Vector2(346, 270), "note": "the north cairns"},
		{"kind": "camp", "at": Vector2(302, 368), "note": "the south cairns"}],
}

## Ways (RealmLayout.BASE_PATHS' schema). The road itself runs on to the new edges (RealmLayout's road entry).
## Junctions sit exactly on another way's vertex.
const PATHS := [
	{"id": "fell_track", "w": 1.4, "pts": [Vector2(-300, 56.4), Vector2(-298, 30), Vector2(-300, 0), Vector2(-306, -30), Vector2(-310, -56), Vector2(-312, -78)]},
	{"id": "barrow_track", "w": 1.4, "pts": [Vector2(-330, 52), Vector2(-326, 80), Vector2(-318, 110), Vector2(-320, 150), Vector2(-318, 190), Vector2(-320, 232), Vector2(-318, 272), Vector2(-316, 296)]},
	{"id": "reed_ford", "w": 1.4, "pts": [Vector2(-316, 296), Vector2(-292, 304), Vector2(-266, 306), Vector2(-236, 302), Vector2(-196, 298), Vector2(-152, 296)]},
	{"id": "fallow_way", "w": 1.6, "pts": [Vector2(-150, 196), Vector2(-150, 230), Vector2(-148, 262), Vector2(-152, 296)]},
	{"id": "arches_way", "w": 1.6, "pts": [Vector2(-152, 296), Vector2(-110, 310), Vector2(-60, 318), Vector2(0, 322), Vector2(60, 318), Vector2(110, 306), Vector2(150, 302), Vector2(200, 296)]},
	{"id": "arches_link", "w": 1.4, "pts": [Vector2(110, 186), Vector2(104, 226), Vector2(84, 262), Vector2(66, 294), Vector2(60, 318)]},
	{"id": "salt_south", "w": 1.4, "pts": [Vector2(196, 212), Vector2(204, 240), Vector2(206, 268), Vector2(200, 296)]},
	{"id": "southwood_way", "w": 1.4, "pts": [Vector2(200, 296), Vector2(236, 288), Vector2(270, 282), Vector2(300, 280), Vector2(320, 300), Vector2(326, 316)]},
	# Lastlight's yard out through the north postern to the rift's forecourt (rift_rim, RealmLayout): the end of the road
	{"id": "bell_track", "w": 1.4, "pts": [Vector2(318, 66), Vector2(304, 36), Vector2(310, 22)]},
	{"id": "nave_track", "w": 1.4, "pts": [Vector2(290, 70), Vector2(292, 96), Vector2(296, 122), Vector2(300, 140)]},
	{"id": "cairn_track", "w": 1.4, "pts": [Vector2(300, 140), Vector2(286, 168), Vector2(282, 200), Vector2(290, 236), Vector2(300, 280)]},
	# the Anchorholds' foot round the rift's west berm to its forecourt
	{"id": "bell_link", "w": 1.4, "pts": [Vector2(196, -70), Vector2(226, -78), Vector2(258, -82), Vector2(263, -52), Vector2(266, -22), Vector2(266, 2), Vector2(284, 6), Vector2(310, 4)]},
	# nave_track to the eighth bell's crater under Lastlight's south wall
	{"id": "bellfall_way", "w": 1.2, "pts": [Vector2(292, 96), Vector2(308, 96), Vector2(322, 99)]},
]

## These ways wander between their vertices (RealmLayout.MEANDER_IDS' schema: metres of swing).
const MEANDER := {"fell_track": 2.4, "barrow_track": 2.6, "reed_ford": 2.0, "fallow_way": 2.2, "arches_way": 2.4, "arches_link": 2.0,
	"salt_south": 2.0, "southwood_way": 2.4, "bell_track": 2.2, "nave_track": 2.0, "cairn_track": 2.4, "bell_link": 2.0, "bellfall_way": 1.4}

## The Sorrow runs on from the old south edge (-254, 240) across the Reedmere to the new south edge
## (RealmLayout.RIVER takes these after its own points).
const RIVER_ON := [Vector2(-262, 268), Vector2(-280, 296), Vector2(-298, 326), Vector2(-316, 358), Vector2(-328, 398)]

## Landform anchors the region agents build on.
const KEEP_C := Vector2(-318.0, -108.0)      ## the Broken Keep's crag (a knoll ~13 m over the fell)
const CRATER_C := Vector2(350.0, 102.0)      ## the Bellfall crater (under Lastlight's south wall): floor ~5 m down, a rim 3 m up
const CRATER_R := 13.0
const NAVE_C := Vector2(318.0, 164.0)        ## the Drowned Nave's mere (fen pools at the fen's water line)
const NAVE_R := Vector2(30.0, 44.0)
const TOWN_E := Vector2(322.0, 44.0)         ## Lastlight's flat
const TOWN_F := Vector2(-160.0, 300.0)       ## Fallowmere's flat
const ARCH_Z := 342.0                        ## the aqueduct's line (it runs east-west); the valley under it is x ~0
const SCARP_Z := Vector2(250.0, 290.0)       ## the downs' rise falls away south between these z


## The landforms' own noises (made when the script loads, on the main thread; only read after: thread-safe).
static var _n_fell := _noise(6201, 0.021, 3, false)
static var _n_hill := _noise(6202, 0.027, 3, false)
static var _n_mere := _noise(6203, 0.045, 2, false)
static var _n_edge := _noise(6204, 0.9, 2, false)
static var _n_ridge := _noise(6205, 0.028, 3, true)
## Tors on the Thousand Cairns' heath: [centre, height]. Clear of its slots and ways by 25 m and more.
const TORS := [[Vector2(290.0, 250.0), 3.4], [Vector2(352.0, 300.0), 3.8], [Vector2(285.0, 332.0), 3.0], [Vector2(345.0, 356.0), 3.6], [Vector2(320.0, 386.0), 2.8]]
## The Crowns' peaks at the new corners: [centre, height, radius].
const PEAKS := [[Vector2(-300.0, -170.0), 30.0, 38.0], [Vector2(-352.0, -162.0), 34.0, 42.0], [Vector2(300.0, -170.0), 32.0, 38.0], [Vector2(354.0, -164.0), 30.0, 40.0]]


static func _noise(seed_n: int, freq: float, octaves: int, ridged: bool) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_n
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED if ridged else FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


## The Far Reaches' macro shape over whatever RealmLayout made of the ground so far. m is 1 outside the old
## Realm (RealmLayout.marches_mask); the shapes below are local to their own regions. Each region's rect is read
## through the same wander its biome edge has (RealmLayout._warp + _mwarp), so a fell or a wood ends where its
## ground cover does and never along a ruled line; the shapes on them are noise, not sine grids.
static func shape(p: Vector2, h: float, m: float) -> float:
	if m <= 0.0:
		return h
	var x := p.x
	var z := p.y
	# the Marches' ground (inside MARCH_BOUNDS, where the West, East and South Marches' places stand) keeps the shapes it
	# was tuned to: the wander and the noise come in over the first 24 m beyond it
	var reach := smoothstep(0.0, 24.0, _out_dist(p, MARCH_BOUNDS))
	var q := p + (RealmLayout._warp(p) + RealmLayout._mwarp(p)) * reach
	var pad := _slot_free(p) * reach      # the noise lies down round every slot (its pad stays level and dry)
	var r := 0.0
	# the Greyfell: a high fell climbing to the Crowns, the keep's crag on it
	r = _rect_w(q, Rect2(-370, -150, 110, 100), 26.0)
	if r > 0.0:
		var was := 2.2 * sin(x * 0.061 + 0.3) * cos(z * 0.052)           # (the shape the Marches' edge was tuned to)
		h += r * (5.0 + lerpf(was, 3.2 * _n_fell.get_noise_2d(x, z) * pad, reach)) * smoothstep(-30.0, -110.0, z)
	h += _crag(p)
	# the Lanternwood: rolling forest hills
	r = _rect_w(q, Rect2(-370, -50, 110, 118), 22.0)
	if r > 0.0:
		var was := 2.4 * sin(x * 0.083 + 1.0) * sin(z * 0.071 - 0.6)
		h += r * (2.6 + lerpf(was, 3.0 * _n_hill.get_noise_2d(x, z) * pad, reach))
	# the Kings' Barrows: a long heather ridge north-south, the barrows along its back; its crest wanders and its
	# east face (to the Sorrow) is the steeper
	r = _rect_w(q, Rect2(-370, 68, 110, 168), 20.0)
	if r > 0.0:
		var dx := x + 328.0 + 6.0 * sin(z * 0.037) + 5.0 * _n_fell.get_noise_2d(x * 0.6, z * 0.6 + 200.0) * reach
		var ridge := exp(-pow(dx / lerpf(24.0, 17.0 if dx > 0.0 else 27.0, reach), 2.0))
		h += r * ridge * (6.5 + 1.6 * _n_hill.get_noise_2d(x, z + 90.0) * pad) * smoothstep(70.0, 110.0, z) * (1.0 - smoothstep(210.0, 240.0, z))
	# the Reedmere: a broad wet basin of meres between hummocks (the fen's pools fill it below its water line)
	r = _rect_w(q, Rect2(-370, 244, 150, 154), 24.0)
	if r > 0.0:
		var mf := lerpf(-0.75, _n_mere.get_noise_2d(x, z) * 1.45 + 0.25 * sin((x - z) * 0.17), pad)
		h = lerpf(h, -0.9 - 0.7 * mf, r * 0.85)
	# the downs' scarp: the Marches' downs rise falls away south of the Waiting Field's country (RealmLayout keeps the
	# rise; this takes it back down over SCARP_Z, so the deep south is low country again; RealmRelief.scarp makes the
	# drop an escarpment on a wandering line)
	var scarp := smoothstep(SCARP_Z.x, SCARP_Z.y, z) * (1.0 - smoothstep(0.0, 25.0, maxf(absf(x) - 155.0, 0.0)))
	h -= 7.0 * scarp
	# Fallowmere: low flat fields
	h = lerpf(h, 0.7 + 0.4 * sin(x * 0.05) * cos(z * 0.06), 0.8 * _bump(p, TOWN_F, 60.0))
	# the Long Arches: a broad dry valley running south under the aqueduct (its line deepest at x 0), its floor open
	# and level, the bed of the stream that dried when the sky did winding down it. Cut by raising its sides (RealmLand
	# floors any dry hollow under -0.6 m flat, which had made the old sunk valley one broad pan).
	r = _rect_w(q, Rect2(-92, 256, 184, 142), 24.0)
	if r > 0.0:
		var vx := x - 8.0 * sin(z * 0.03) - 6.0 * _n_fell.get_noise_2d(x * 0.4, z * 0.4 + 600.0)
		var sides := 7.5 * (1.0 - exp(-pow(vx / 44.0, 4.0) * 0.6)) + 1.4 * _n_hill.get_noise_2d(x, z + 700.0) * smoothstep(30.0, 60.0, absf(vx)) * pad
		var bed := -0.45 * exp(-pow((vx - 5.0 * sin(z * 0.085 + 0.7)) / 3.2, 2.0))
		h += r * (sides + bed) * smoothstep(262.0, 300.0, z)
	# the Southwood: wooded hills and hollows
	r = _rect_w(q, Rect2(92, 248, 170, 150), 24.0)
	if r > 0.0:
		h += r * (3.0 + (2.8 * _n_hill.get_noise_2d(x + 500.0, z) + 1.1 * _n_fell.get_noise_2d(x, z + 300.0)) * pad)
	# the Bellfall: a crater with a raised, broken lip and a hummocky apron of what it threw out
	var dc := p.distance_to(CRATER_C)
	if dc < CRATER_R + 24.0:
		var u := (p - CRATER_C) / maxf(dc, 0.01) * 1.8
		var rr := CRATER_R * (1.0 + 0.11 * _n_edge.get_noise_2d(u.x, u.y))
		var lip_h := 3.0 * (1.0 + 0.4 * _n_edge.get_noise_2d(u.x + 7.0, u.y - 3.0) * pad)
		var bowl := -5.0 * (1.0 - smoothstep(rr * 0.2, rr, dc))
		var lip := lip_h * exp(-pow((dc - rr) / 7.0, 2.0))
		var ejecta := 1.2 * _n_hill.get_noise_2d(x * 2.2, z * 2.2) * pad * smoothstep(rr + 4.0, rr + 10.0, dc) * (1.0 - smoothstep(rr + 10.0, rr + 22.0, dc))
		h += (bowl + lip + ejecta) * smoothstep(CRATER_R + 24.0, CRATER_R + 9.0, dc)
	# Lastlight: the waystation's flat
	h = lerpf(h, 0.6, 0.85 * _bump(p, TOWN_E, 46.0))
	# the Drowned Nave: a basin the fen floods (pools at the fen's water line), its shore uneven
	var ex := (x - NAVE_C.x) / NAVE_R.x
	var ez := (z - NAVE_C.y) / NAVE_R.y
	var en := sqrt(ex * ex + ez * ez)
	if en < 1.7:
		var un := Vector2(ex, ez) / maxf(en, 0.01) * 1.6
		en *= 1.0 + 0.11 * _n_edge.get_noise_2d(un.x + 20.0, un.y)
		h = lerpf(h, -1.5, 1.0 - smoothstep(0.85, 1.5, en))
	# the Thousand Cairns: a high windy heath, tors standing out of it
	r = _rect_w(q, Rect2(262, 236, 108, 162), 28.0)
	if r > 0.0:
		h += r * (4.5 + 2.2 * _n_fell.get_noise_2d(x + 900.0, z) * pad)
		for t: Array in TORS:
			h += r * float(t[1]) * _bump(p, t[0], 10.0)
	# the Crowns' peaks at the new corners: ridged, spurs and gullies down them
	for pk: Array in PEAKS:
		var b := _bump(p, pk[0], float(pk[2]))
		if b > 0.0:
			h += float(pk[1]) * b * (0.72 + 0.45 * _n_ridge.get_noise_2d(x, z))
	return h


## RealmLand's detail noise and strata lie down here (RealmLand._designed_w): 1 within 7 m of a Far Reaches slot (eased
## out by 13 m) and on the keep's crag top, so a slot's pad and the keep's floor are level ground.
static func calm(x: float, z: float) -> float:
	var p := Vector2(x, z)
	if MARCH_BOUNDS.grow(-2.0).has_point(p):
		return 0.0
	var w := 1.0 - smoothstep(7.0, 10.5, p.distance_to(KEEP_C))
	for id: String in SLOTS:
		for s: Dictionary in SLOTS[id]:
			w = maxf(w, 1.0 - smoothstep(7.0, 13.0, p.distance_to(s.at)))
	return w


static func _out_dist(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()


## 1 away from the Far Reaches' slots, 0 within 9 m of one (eased out by 22 m).
static func _slot_free(p: Vector2) -> float:
	var f := 1.0
	for id: String in SLOTS:
		for s: Dictionary in SLOTS[id]:
			var d := p.distance_to(s.at)
			if d < 22.0:
				f = minf(f, smoothstep(9.0, 22.0, d))
	return f


## The Broken Keep's crag: a flat top (the keep's, ~10 m across its middle) 13 m over the fell, a broken cliff round
## it falling to a scree apron, and on the bearing of fell_track's end a ramp up instead of the face.
static func _crag(p: Vector2) -> float:
	var d := p.distance_to(KEEP_C)
	if d > 48.0:
		return 0.0
	var u := (p - KEEP_C) / maxf(d, 0.01)
	var edge := 10.5 + 2.4 * _n_edge.get_noise_2d(u.x * 1.6 + 40.0, u.y * 1.6)
	var top := 13.0
	var cliff := 1.0 - smoothstep(edge, edge + 5.5, d)
	var talus := 1.0 - smoothstep(edge + 2.0, edge + 26.0, d)
	var hh := top * maxf(cliff, talus * 0.36)
	var to_track := (Vector2(-312.0, -78.0) - KEEP_C).normalized()
	var ramp_w := smoothstep(0.84, 0.97, u.dot(to_track)) if d > 0.5 else 0.0
	var ramp := top * clampf(1.0 - (d - edge + 1.0) / 22.0, 0.0, 1.0)
	return lerpf(hh, maxf(hh, ramp), ramp_w)


## RealmLand's path profiles: a Far Reaches way that starts or ends on an earlier way takes that way's height at the
## junction and blends to its own over 14 m (two profiles that disagree left a step across the older way).
## `done` are the profiles made so far; `near(profile, x, z)` is RealmLand._path_near ([distance, height]).
static func pin_junctions(id: String, res: Array[Vector2], prof: PackedFloat32Array, done: Array, near: Callable) -> PackedFloat32Array:
	if not MEANDER.has(id):
		return prof
	for end: int in [0, res.size() - 1]:
		var q := res[end]
		for pr: Dictionary in done:
			var nr: Vector2 = near.call(pr, q.x, q.y)
			if nr.x > 1.0:
				continue
			var dir := 1 if end == 0 else -1
			var k := end
			var walked := 0.0
			while k >= 0 and k < res.size() and walked < 14.0:
				prof[k] = lerpf(prof[k], nr.y, 1.0 - smoothstep(0.0, 14.0, walked))
				if k + dir >= 0 and k + dir < res.size():
					walked += res[k].distance_to(res[k + dir])
				k += dir
			break
	return prof


static func _bump(p: Vector2, c: Vector2, r: float) -> float:
	var t := clampf(1.0 - p.distance_to(c) / r, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _rect_w(p: Vector2, r: Rect2, fall: float) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	var t := clampf(1.0 - Vector2(dx, dz).length() / fall, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
