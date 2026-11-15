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

## Regions (RealmLayout.REGIONS' schema). Tiers rise with the distance from Hearthward: the three towns are
## the safe places (1), the wild ground between them 2, the far corners and the fells under the Crowns 3.
const REGIONS := [
	# --- the West Reach (beyond the Sorrow) ---------------------------------------------------------------
	{"id": "greyfell", "name": "The Greyfell", "rect": Rect2(-370, -150, 110, 100), "blobs": [{"c": Vector2(-272, -66), "r": 16.0}], "biome": "crag", "tier": 3,
		"purpose": "a high grey fell at the Crowns' west corner; the Order's Broken Keep on its crag, a garrison that never stood down",
		"lore": "The Order's last keep in the west watched the pass for a sky that never came. Its garrison still keeps the watch."},
	{"id": "lanternwood", "name": "The Lanternwood", "rect": Rect2(-370, -50, 110, 118), "biome": "oldforest", "tier": 2,
		"purpose": "a deep old wood where cold fungus lights the ground blue; wisps, a ring of giant caps, the road's last milestone",
		"lore": "Nothing burns in the Lanternwood and nothing needs to. The light grows out of the dead."},
	{"id": "kingsbarrows", "name": "The Kings' Barrows", "rect": Rect2(-370, 68, 110, 168), "biome": "heath", "tier": 3,
		"purpose": "a long heather ridge of great barrows and a stone row; the King's Barrow is open",
		"lore": "Before the Order, before the Rooted, kings were laid on this ridge with their faces to the west. One door stands open."},
	{"id": "reedmere", "name": "The Reedmere", "rect": Rect2(-370, 236, 150, 162), "biome": "fen", "tier": 2,
		"purpose": "where the Sorrow spreads into reed meres; Reedholm's stilt-houses and the heron fishers",
		"lore": "The Sorrow loses its banks here and forgets it was a river. The Reedholm folk fish it by lamp."},
	# --- the Deep South (below the downs' scarp) -----------------------------------------------------------
	{"id": "fallow", "name": "Fallowmere", "rect": Rect2(-220, 240, 128, 158), "biome": "meadow", "tier": 1,
		"purpose": "a farming hamlet in the low fields: the tithe barn, the fold, hedged strips gone to seed",
		"lore": "Fallowmere grew the Order's bread. Half its fields are fallow now, and the other half are graves."},
	{"id": "arches", "name": "The Long Arches", "rect": Rect2(-92, 240, 184, 158), "biome": "ruin", "tier": 2,
		"purpose": "the Order's great aqueduct striding across a dry valley; its castellum and the broken span",
		"lore": "The Order carried the Crowns' snow south to the fields on a road of arches. The water stopped when the sky did."},
	{"id": "southwood", "name": "The Southwood", "rect": Rect2(92, 240, 170, 158), "biome": "oldforest", "tier": 3,
		"purpose": "a dark wood of hollies and oaks; the charcoal burners' ruin, the witch's hollow, the things that hunt it",
		"lore": "The charcoal burners stayed when the town went north. Their stacks still smoke on nights without wind."},
	# --- the East Reach (beyond the Pans and the Anchorholds) ----------------------------------------------
	{"id": "bellfall", "name": "The Bellfall", "rect": Rect2(260, -150, 110, 110), "biome": "crag", "tier": 3,
		"purpose": "a crater at the Crowns' east corner where the eighth bell came down: the bell, cracked, half sunk in scorched rock",
		"lore": "The Founder cast seven bells for the Stair. The eighth was cast in the sky, and the sky let it fall."},
	{"id": "lastlight", "name": "Lastlight", "rect": Rect2(260, -40, 110, 136), "biome": "meadow", "tier": 1,
		"purpose": "the walled waystation at the road's east end: a gate that stays shut, an inn, a watch, travellers",
		"lore": "The last lamp the pilgrims saw before the road turned to the mountain. Lastlight still lights it."},
	{"id": "nave", "name": "The Drowned Nave", "rect": Rect2(260, 96, 110, 138), "biome": "fen", "tier": 3,
		"purpose": "a cathedral the Order never finished, its nave flooded to the knee; moon shafts through the broken vault",
		"lore": "They built the nave first and the floor last. The water came in before the floor did."},
	{"id": "cairns", "name": "The Thousand Cairns", "rect": Rect2(260, 234, 110, 164), "biome": "heath", "tier": 3,
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
		{"kind": "camp", "at": Vector2(-344, -96), "note": "the keep's west bailey"},
		{"kind": "camp", "at": Vector2(-288, -98), "note": "the scree east of the crag"}],
	"lanternwood": [
		{"kind": "fire", "at": Vector2(-292, 14), "note": "beside fell_track in a lit clearing"},
		{"kind": "poi", "at": Vector2(-330, -8), "note": "the ring of giant caps"},
		{"kind": "poi", "at": Vector2(-350, 44), "note": "the Last Milestone at the road's west end"},
		{"kind": "camp", "at": Vector2(-340, 22), "note": "the deep wood"},
		{"kind": "camp", "at": Vector2(-282, -30), "note": "the wood's north edge"}],
	"kingsbarrows": [
		{"kind": "fire", "at": Vector2(-318, 96), "note": "barrow_track at the ridge's north end"},
		{"kind": "poi", "at": Vector2(-345, 152), "note": "the King's Barrow, its door open"},
		{"kind": "poi", "at": Vector2(-300, 128), "note": "the stone row along the ridge"},
		{"kind": "camp", "at": Vector2(-344, 120), "note": "between the barrows"},
		{"kind": "camp", "at": Vector2(-296, 196), "note": "the ridge's south shoulder"}],
	"reedmere": [
		{"kind": "fire", "at": Vector2(-316, 302), "note": "Reedholm's landing"},
		{"kind": "poi_wet", "at": Vector2(-328, 296), "note": "Reedholm's stilt-houses"},
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
		{"kind": "camp", "at": Vector2(130, 352), "note": "the burners' clearing"},
		{"kind": "camp", "at": Vector2(212, 318), "note": "the holly brakes"},
		{"kind": "camp", "at": Vector2(243, 260), "note": "the wood's north-east edge"}],
	"bellfall": [
		{"kind": "fire", "at": Vector2(318, -60), "note": "bell_track at the crater's south lip"},
		{"kind": "poi", "at": Vector2(318, -100), "note": "the fallen bell in its crater"},
		{"kind": "camp", "at": Vector2(290, -112), "note": "the crater's west floor"},
		{"kind": "camp", "at": Vector2(346, -88), "note": "the crater's east rim"}],
	"lastlight": [
		{"kind": "fire", "at": Vector2(310, 50), "note": "the town's yard, inside the gate"},
		{"kind": "poi", "at": Vector2(322, 40), "note": "Lastlight: the inn, the lamp tower, the watch"},
		{"kind": "poi", "at": Vector2(361, 58), "note": "the shut East Gate at the road's end"},
		{"kind": "camp", "at": Vector2(296, -12), "note": "bell_track's lower bend"}],
	"nave": [
		{"kind": "fire", "at": Vector2(296, 112), "note": "nave_track on the mere's north shore"},
		{"kind": "poi_wet", "at": Vector2(318, 162), "note": "the Drowned Nave"},
		{"kind": "camp", "at": Vector2(344, 126), "note": "the east shore"},
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
	{"id": "bell_track", "w": 1.4, "pts": [Vector2(318, 66), Vector2(304, 36), Vector2(300, 6), Vector2(304, -24), Vector2(314, -48), Vector2(318, -68)]},
	{"id": "nave_track", "w": 1.4, "pts": [Vector2(290, 70), Vector2(292, 96), Vector2(296, 122), Vector2(300, 140)]},
	{"id": "cairn_track", "w": 1.4, "pts": [Vector2(300, 140), Vector2(286, 168), Vector2(282, 200), Vector2(290, 236), Vector2(300, 280)]},
	{"id": "bell_link", "w": 1.4, "pts": [Vector2(196, -70), Vector2(226, -78), Vector2(258, -82), Vector2(290, -80), Vector2(314, -48)]},
]

## These ways wander between their vertices (RealmLayout.MEANDER_IDS' schema: metres of swing).
const MEANDER := {"fell_track": 2.4, "barrow_track": 2.6, "reed_ford": 2.0, "fallow_way": 2.2, "arches_way": 2.4, "arches_link": 2.0,
	"salt_south": 2.0, "southwood_way": 2.4, "bell_track": 2.2, "nave_track": 2.0, "cairn_track": 2.4, "bell_link": 2.0}

## The Sorrow runs on from the old south edge (-254, 240) across the Reedmere to the new south edge
## (RealmLayout.RIVER takes these after its own points).
const RIVER_ON := [Vector2(-262, 268), Vector2(-280, 296), Vector2(-298, 326), Vector2(-316, 358), Vector2(-328, 398)]

## Landform anchors the region agents build on.
const KEEP_C := Vector2(-318.0, -108.0)      ## the Broken Keep's crag (a knoll ~13 m over the fell)
const CRATER_C := Vector2(318.0, -100.0)     ## the Bellfall crater: floor ~7 m down, a rim 4 m up
const CRATER_R := 30.0
const NAVE_C := Vector2(318.0, 164.0)        ## the Drowned Nave's mere (fen pools at the fen's water line)
const NAVE_R := Vector2(30.0, 44.0)
const TOWN_E := Vector2(322.0, 44.0)         ## Lastlight's flat
const TOWN_F := Vector2(-160.0, 300.0)       ## Fallowmere's flat
const ARCH_Z := 342.0                        ## the aqueduct's line (it runs east-west); the valley under it is x ~0
const SCARP_Z := Vector2(250.0, 290.0)       ## the downs' rise falls away south between these z


## The Far Reaches' macro shape over whatever RealmLayout made of the ground so far. m is 1 outside the old
## Realm (RealmLayout.marches_mask); the shapes below are local to their own regions.
static func shape(p: Vector2, h: float, m: float) -> float:
	if m <= 0.0:
		return h
	var x := p.x
	var z := p.y
	var r := 0.0
	# the Greyfell: a high fell climbing to the Crowns, the keep's crag on it
	r = _rect_w(p, Rect2(-370, -150, 110, 100), 26.0)
	if r > 0.0:
		h += r * (5.0 + 2.2 * sin(x * 0.061 + 0.3) * cos(z * 0.052)) * smoothstep(-30.0, -110.0, z)
		h += 12.0 * _bump(p, KEEP_C, 30.0)
	# the Lanternwood: rolling forest hills
	r = _rect_w(p, Rect2(-370, -50, 110, 118), 22.0)
	if r > 0.0:
		h += r * (2.6 + 2.4 * sin(x * 0.083 + 1.0) * sin(z * 0.071 - 0.6))
	# the Kings' Barrows: a long heather ridge north-south, the barrows along its back
	r = _rect_w(p, Rect2(-370, 68, 110, 168), 20.0)
	if r > 0.0:
		var ridge := exp(-pow((x + 328.0 + 6.0 * sin(z * 0.037)) / 24.0, 2.0))
		h += r * ridge * 6.5 * smoothstep(70.0, 110.0, z) * (1.0 - smoothstep(210.0, 240.0, z))
	# the Reedmere: a broad wet basin of meres between hummocks (the fen's pools fill it)
	r = _rect_w(p, Rect2(-370, 244, 150, 154), 22.0)
	if r > 0.0:
		var mf := sin(x * 0.09 + 0.2) * sin(z * 0.11 - 0.5) + 0.6 * sin(x * 0.057 - z * 0.071 + 0.9) + 0.4 * sin((x - z) * 0.17)
		h = lerpf(h, -0.9 - 0.7 * mf, r * 0.85)
	# the downs' scarp: the Marches' downs rise falls away south of the Waiting Field's country (RealmLayout keeps the
	# rise; this takes it back down over SCARP_Z, so the deep south is low country again)
	var scarp := smoothstep(SCARP_Z.x, SCARP_Z.y, z) * (1.0 - smoothstep(0.0, 25.0, maxf(absf(x) - 155.0, 0.0)))
	h -= 7.0 * scarp
	# Fallowmere: low flat fields
	h = lerpf(h, 0.7 + 0.4 * sin(x * 0.05) * cos(z * 0.06), 0.8 * _bump(p, TOWN_F, 60.0))
	# the Long Arches: a dry valley running south under the aqueduct (deepest at x 0)
	r = _rect_w(p, Rect2(-92, 256, 184, 142), 20.0)
	if r > 0.0:
		var vx := x - 8.0 * sin(z * 0.03)
		h += r * (-6.0 * exp(-pow(vx / 34.0, 2.0)) + 2.5 * (1.0 - exp(-pow(vx / 70.0, 2.0)))) * smoothstep(262.0, 300.0, z)
	# the Southwood: wooded hills
	r = _rect_w(p, Rect2(92, 248, 170, 150), 22.0)
	if r > 0.0:
		h += r * (3.0 + 2.6 * sin(x * 0.067 - 0.4) * sin(z * 0.059 + 1.2) + 1.2 * sin(x * 0.13 + z * 0.09))
	# the Bellfall: a crater with a raised lip, the Crowns rising behind it
	var dc := p.distance_to(CRATER_C)
	if dc < CRATER_R + 30.0:
		var bowl := -7.0 * (1.0 - smoothstep(CRATER_R * 0.2, CRATER_R, dc))
		var lip := 4.5 * exp(-pow((dc - CRATER_R) / 7.0, 2.0))
		h += (bowl + lip) * smoothstep(CRATER_R + 30.0, CRATER_R + 10.0, dc)
	# Lastlight: the waystation's flat
	h = lerpf(h, 0.6, 0.85 * _bump(p, TOWN_E, 46.0))
	# the Drowned Nave: an elliptical basin the fen floods (pools at the fen's water line)
	var en := sqrt(pow((x - NAVE_C.x) / NAVE_R.x, 2.0) + pow((z - NAVE_C.y) / NAVE_R.y, 2.0))
	if en < 1.6:
		h = lerpf(h, -1.5, 1.0 - smoothstep(0.85, 1.5, en))
	# the Thousand Cairns: a high windy heath
	r = _rect_w(p, Rect2(262, 236, 108, 162), 26.0)
	if r > 0.0:
		h += r * (4.5 + 1.8 * sin(x * 0.05 + 0.8) * cos(z * 0.047 - 0.2))
	# the Crowns' peaks at the new corners
	h += 30.0 * _bump(p, Vector2(-300, -170), 38.0) + 34.0 * _bump(p, Vector2(-352, -162), 42.0)
	h += 32.0 * _bump(p, Vector2(300, -170), 38.0) + 30.0 * _bump(p, Vector2(354, -164), 40.0)
	return h


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
