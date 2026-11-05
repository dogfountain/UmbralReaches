class_name RealmLayout
extends RefCounted
## THE CONTRACT for the redesigned zone ("the Realm", docs/REALM_PLAN.md). Every module places
## against these numbers and this macro height, so the modules can be built in parallel and still
## meet. Change a value here only by agreement (it moves everyone). World units: metres, +Y up,
## the spawn brazier at (0, 0, 33). Bounds are about twice the old playable area.
##
## `macro_height(x, z)` is the designed landform (no small detail). RealmLand turns it into the
## terrain mesh (adding detail noise, path carving and site stamps); everyone else asks
## `RealmLayout.ground(space, x, z)` once the terrain exists, or `macro_height()` before it does.

const BOUNDS := Rect2(-155.0, -150.0, 310.0, 325.0)        ## playable xz (x -155..155, z -150..175); r34: was 220 x 230
const OUTER := Rect2(-244.0, -240.0, 488.0, 504.0)         ## terrain extent incl. the horizon ring (4 m lattice)
const LAVA_Y := -15.5                                       ## the rift's lava surface (LavaWorks)

## Fixed points (do not move: the kept brazier, tavern, Ossuary and summit depend on them).
const SPAWN := Vector3(0.0, 0.0, 33.0)                     ## the spawn brazier (Zone/Braziers/Sanctuary)
const PLAYER_START := Vector3(0.0, 0.15, 26.5)
const TAVERN := Rect2(10.0, 25.6, 16.0, 9.2)               ## Tavern.X0..X1, Z0..Z1 (+ yard east to x 29)
const OSSUARY := AABB(Vector3(2.0, -6.0, -110.0), Vector3(30.0, 32.0, 88.0))   ## streamed crypt (keep)
## r34 layout: room reserved for the Bone Abbot's pit hall (~50 m), wholly underground east of the
## crypt, under the rift's east shelf, the Crowns' foot and the north fen (the ground above it stays
## higher than -2; its top is 4 m below that). The Ossuary agent builds it and joins it to the crypt;
## "inside the Ossuary" checks should use in_ossuary() (OSSUARY or this box), never one AABB round
## both (that would take in the fen's surface). See docs/r34/layout.md.
const OSSUARY_HALL := AABB(Vector3(26.0, -38.0, -124.0), Vector3(56.0, 32.0, 56.0))   ## x 26..82, y -38..-6, z -124..-68
const SUMMIT := Vector3(0.0, 24.5, -83.5)                  ## summit platform holder (keep)
const SUMMIT_DAIS := Vector3(0.0, 27.35, -103.9)           ## Ascended Warden's fighting dais (r 14)
const SUMMIT_WARD := Vector3(0.0, 25.2, -70.9)             ## where the crossing arrives; the summit seal

## r34 layout: raid-sized boss floors (WoW raid rooms: 55-65 m across). RealmLand levels (or, at the
## summit, clears) the ground; RealmBosses registers each as a level terrace site "raid_<id>" so the
## flora, lore and rocks keep out. The boss agents build the rooms on them; nothing else may.
##   c      centre xz          r      floor radius (m)       y   floor height
##   fall   skirt width (m) from the floor's edge back to the natural ground
##   mode   "level": the land is cut and filled to y (the henge hill's crown)
##          "clear": the land is only cut down to y - 0.8 (the summit: a built deck over the chasm,
##                   the Crowns cut back into a cirque behind it)
##   gate   xz of the way in (the floor's rim where the approach arrives)
const RAIDS := [
	{"id": "henge", "c": Vector2(-86.0, -24.0), "r": 31.0, "y": 9.0, "fall": 12.0, "mode": "level",
		"gate": Vector2(-56.0, -16.0), "boss": "thornwarden"},
	{"id": "summit", "c": Vector2(0.0, -118.0), "r": 28.0, "y": 27.35, "fall": 10.0, "mode": "clear",
		"gate": Vector2(0.0, -90.0), "boss": "ascended_warden"},
]

## Regions: [id, name, centre xz, radius or rect, biome, lore one-liner]. Biomes drive flora,
## ground material and props. Radii are soft (RealmLand blends 15-25 m between biomes).
## r34 layout: "tier" is the suggested encounter tier (core/life/encounters/tiers.gd REGION_BASE) and
## "purpose" what the place is for (docs/r34/layout.md); the seven r34 regions fill the new ground.
const REGIONS := [
	{"id": "hearth", "name": "Hearthward", "c": Vector2(6, 38), "r": 34.0, "biome": "meadow", "tier": 0,
		"lore": "The last kindled village: the Kindled Keg, the spawn brazier, cottages gone quiet."},
	{"id": "road", "name": "The Pilgrims' Road", "rect": Rect2(-155, 50, 310, 30), "biome": "heath", "tier": 0,
		"lore": "The old road the ascension pilgrims walked in, lined with waystones and their dead."},
	{"id": "chapel", "name": "Chapel of the First Kindling", "c": Vector2(-72, 52), "r": 22.0, "biome": "ruin", "tier": 1,
		"lore": "Where the first fire was lit against the gloom; roofless now, its saints defaced."},
	{"id": "thornwood", "name": "The Thornwood", "rect": Rect2(-150, -66, 120, 111), "biome": "oldforest", "tier": 1,
		"lore": "Ancient oaks the Thornwarden keeps; the pagan henge on its hill predates the ascension."},
	{"id": "henge", "name": "Thorn Henge", "c": Vector2(-86, -24), "r": 32.0, "biome": "oldforest", "tier": 1,
		"lore": "Boss: the Thornwarden. Seal 'henge'."},
	{"id": "fen", "name": "The Hollow Fen", "rect": Rect2(40, -80, 70, 115), "biome": "fen", "tier": 1,
		"lore": "Black pools and drowned graves where the hollowed were laid when the crypt was full."},
	{"id": "barrows", "name": "The Barrow Field", "c": Vector2(78, -42), "r": 20.0, "biome": "fen", "tier": 2,
		"lore": "Grave mounds of the abbey's lay brothers; the path down to the Ossuary starts here."},
	{"id": "rift", "name": "The Ashen Rift", "rect": Rect2(-30, -118, 60, 106), "biome": "ash", "tier": 2,
		"lore": "The wound the ascension tore in the land; lava where the pilgrims' stair once stood."},
	{"id": "ossuary", "name": "The Ossuary", "rect": Rect2(2, -110, 30, 88), "biome": "ash", "tier": 2,
		"lore": "Boss: the Bone Abbot. Seal 'oss_gallery'. Streamed area (world/areas/ossuary)."},
	{"id": "summit", "name": "The Summit of Ascension", "c": Vector2(0, -104), "r": 42.0, "biome": "crag", "tier": 3,
		"lore": "Boss: the Ascended Warden, last priest of the ascension. Seal 'summit'."},
	{"id": "crags", "name": "The Crowns", "rect": Rect2(-155, -150, 310, 40), "biome": "crag", "tier": 2,
		"lore": "The mountain wall the sky turns inward over; the world's northern edge."},
	{"id": "glade", "name": "The Glimmer Glade", "c": Vector2(-38, 8), "r": 18.0, "biome": "glade", "tier": 0,
		"lore": "Bioluminescent clearing between the village and the Thornwood; a shrine to the lost."},
	# --- r34: the new ground --------------------------------------------------------------------
	{"id": "quarry", "name": "The Saints' Quarry", "rect": Rect2(-155, -130, 50, 62), "biome": "crag", "tier": 2,
		"purpose": "terraced pit cut into the Crowns' foot: vertical exploration, a camp on the benches, stone and ore",
		"lore": "Where the Order cut four thousand steps for the Stair, bench by bench into the mountain."},
	{"id": "holds", "name": "The Rooted Holds", "c": Vector2(-134, 12), "r": 18.0, "biome": "heath", "tier": 1,
		"purpose": "a heather clearing deep in the west wood: the Rooted's turf-roofed earth-houses, a hall-mound, a fire",
		"lore": "The earth-houses of the Rooted, the Keg-folk's kin, half sunk in the heather; empty since before the road."},
	{"id": "foundry", "name": "The Founder's Pits", "rect": Rect2(108, -112, 47, 46), "biome": "ash", "tier": 2,
		"purpose": "slag heaps and casting pits under the rim: the bell furnace, a hard camp, a relic",
		"lore": "Under the rim the Founder cast the three great bells; the pits are still warm."},
	{"id": "moor", "name": "The Lanternless Moor", "rect": Rect2(124, -66, 31, 106), "biome": "heath", "tier": 1,
		"purpose": "open high heath with a tor: long sight lines, wind, cairns, roaming rares",
		"lore": "The faithful crossed it in the dark by the Hierarch's word; the moor kept those who stumbled."},
	{"id": "orchard", "name": "The Cinder Orchard", "rect": Rect2(-150, 90, 82, 62), "biome": "ash", "tier": 1,
		"purpose": "rows of burned fruit trees on ash: foraging, a press-house ruin, a night event ground",
		"lore": "The abbey's orchard, fired on the Order's word the winter the Kindlers were named heretics."},
	{"id": "necropolis", "name": "The Waiting Field", "rect": Rect2(-44, 98, 86, 58), "biome": "ruin", "tier": 1,
		"purpose": "the pilgrims' necropolis: ranks of graves and tombs on a slope facing the mountain, a crypt door",
		"lore": "Those who died on the road before the Stair lie here in ranks, all facing the mountain, waiting."},
	{"id": "mere", "name": "Corvin's Mere", "rect": Rect2(64, 90, 86, 62), "biome": "fen", "tier": 1,
		"purpose": "a drowned water-meadow: causeways, islets, floating lamps, a half-sunk chapel",
		"lore": "Brother Corvin rowed fire out here to the sunk dead. Some of his lamps still float."},
]

## r34 layout: suggested slots for phase 2 in the new ground (docs/r34/layout.md): a fire (an Ember Road
## stop), places of interest, camps. Checked by zz/layout_r34_test (inside the region, on dry walkable
## ground off the ways and sites; "poi_wet" may stand in water). Builders may move a slot a few metres.
const SLOTS := {
	"quarry": [
		{"kind": "fire", "at": Vector2(-120, -83), "note": "the pit's mouth, beside west_track's end"},
		{"kind": "poi", "at": Vector2(-128, -104), "note": "the pit floor: unfinished steps, a crane, squared blocks"},
		{"kind": "poi", "at": Vector2(-144, -118), "note": "a high bench under the west wall: the cutters' shelter"},
		{"kind": "camp", "at": Vector2(-110, -100), "note": "the east benches"},
		{"kind": "camp", "at": Vector2(-139, -89), "note": "the west benches"}],
	"holds": [
		{"kind": "fire", "at": Vector2(-125, 15), "note": "beside west_track at the clearing's edge"},
		{"kind": "poi", "at": Vector2(-139, 11), "note": "the hall-mound"},
		{"kind": "poi", "at": Vector2(-133, 1), "note": "a row of earth-houses"},
		{"kind": "camp", "at": Vector2(-137, 22), "note": "the north holds"}],
	"foundry": [
		{"kind": "fire", "at": Vector2(123, -76), "note": "at moor_track's end, under the first slag heap"},
		{"kind": "poi", "at": Vector2(135, -105), "note": "the bell furnace, cut into the rim"},
		{"kind": "poi", "at": Vector2(132, -90), "note": "the casting pits"},
		{"kind": "camp", "at": Vector2(147, -85), "note": "between the heaps"},
		{"kind": "camp", "at": Vector2(115, -102), "note": "the west bench"}],
	"moor": [
		{"kind": "fire", "at": Vector2(126, -8), "note": "beside moor_track, under the tor"},
		{"kind": "poi", "at": Vector2(142, -24), "note": "the tor: a cairn and a lookout over the fen"},
		{"kind": "poi", "at": Vector2(145, 14), "note": "a lanternless shrine"},
		{"kind": "camp", "at": Vector2(145, -50), "note": "the north moor"},
		{"kind": "camp", "at": Vector2(148, 33), "note": "the south moor"}],
	"orchard": [
		{"kind": "fire", "at": Vector2(-99, 104), "note": "beside orchard_lane"},
		{"kind": "poi", "at": Vector2(-128, 132), "note": "the press-house ruin"},
		{"kind": "poi", "at": Vector2(-86, 122), "note": "the burned rows' heart (a night event ground)"},
		{"kind": "camp", "at": Vector2(-136, 104), "note": "the west rows"},
		{"kind": "camp", "at": Vector2(-80, 142), "note": "the south rows"}],
	"necropolis": [
		{"kind": "fire", "at": Vector2(8, 108), "note": "at the field's gate, off necropolis_way"},
		{"kind": "poi", "at": Vector2(0, 147), "note": "the mausoleum at the top of the field: a crypt door"},
		{"kind": "poi", "at": Vector2(-26, 118), "note": "the pilgrims' ranks"},
		{"kind": "camp", "at": Vector2(-30, 146), "note": "the west tombs"},
		{"kind": "camp", "at": Vector2(28, 114), "note": "the east tombs"}],
	"mere": [
		{"kind": "fire", "at": Vector2(103, 98), "note": "the mere's north bank, near mere_causeway"},
		{"kind": "poi_wet", "at": Vector2(84, 112), "note": "the half-sunk chapel in the west mere"},
		{"kind": "poi", "at": Vector2(132, 124), "note": "Corvin's landing: a boat-house on the east bank"},
		{"kind": "camp", "at": Vector2(137, 102), "note": "the east bank"},
		{"kind": "camp", "at": Vector2(118, 144), "note": "the south bank"}],
	"road": [
		{"kind": "camp", "at": Vector2(-128, 74), "note": "the West Gate's approach"},
		{"kind": "camp", "at": Vector2(131, 58), "note": "the East Gate's approach"}],
}

## The walked network: polylines (xz) with a half width. RealmLand carves/levels them and keeps
## flora off; RealmLore lines them with waystones; enemies patrol near, never on, them.
## r34 layout: the road runs on to the new edges (gates at x +-145); five new ways reach the new
## regions, and the south track joins the three southern places into a loop with the road. (No way
## crosses the Hollow Fen to the moor: every line tried there moved the fen's dressed places -- the
## belfry, the drowned graves, the barrow stones. The moor and the Pits are reached from the road.)
const BASE_PATHS := [
	{"id": "west_way", "w": 1.8, "pts": [Vector2(-4, 30), Vector2(-20, 24), Vector2(-38, 10), Vector2(-46, -2), Vector2(-50, -10)]},
	{"id": "east_way", "w": 1.8, "pts": [Vector2(26, 22), Vector2(42, 10), Vector2(58, -12), Vector2(72, -34), Vector2(78, -42)]},
	{"id": "fen_descent", "w": 1.6, "pts": [Vector2(78, -42), Vector2(62, -56), Vector2(44, -62), Vector2(34, -66)]},
	{"id": "road", "w": 2.2, "pts": [Vector2(-150, 67), Vector2(-104, 64), Vector2(-72, 60), Vector2(-40, 58), Vector2(-6, 54), Vector2(2, 44), Vector2(40, 60), Vector2(104, 66), Vector2(150, 68)]},
	{"id": "chapel_lane", "w": 1.4, "pts": [Vector2(-60, 58), Vector2(-68, 52)]},
	{"id": "rift_rim", "w": 2.0, "pts": [Vector2(0, 22), Vector2(0, 4), Vector2(0, -8)]},
	# r34
	{"id": "west_track", "w": 1.4, "pts": [Vector2(-118, 65), Vector2(-124, 44), Vector2(-132, 22), Vector2(-138, -6), Vector2(-138, -40), Vector2(-132, -66), Vector2(-126, -84)]},
	{"id": "moor_track", "w": 1.4, "pts": [Vector2(124, 67), Vector2(130, 44), Vector2(134, 18), Vector2(132, -18), Vector2(130, -46), Vector2(128, -72), Vector2(130, -86)]},
	{"id": "necropolis_way", "w": 1.8, "pts": [Vector2(-6, 54), Vector2(-5, 74), Vector2(-3, 96), Vector2(0, 112), Vector2(0, 128)]},
	{"id": "orchard_lane", "w": 1.4, "pts": [Vector2(-98, 63), Vector2(-102, 84), Vector2(-108, 104), Vector2(-112, 122)]},
	{"id": "mere_causeway", "w": 1.6, "pts": [Vector2(92, 65), Vector2(96, 84), Vector2(100, 104), Vector2(104, 120)]},
	{"id": "south_track", "w": 1.4, "pts": [Vector2(-112, 122), Vector2(-80, 132), Vector2(-40, 134), Vector2(0, 128), Vector2(40, 134), Vector2(76, 128), Vector2(104, 120)]},
]

## r35 (docs/critique/r35_full.md: "the south half is a grid of rectangles and straight roads"): the
## southern tracks and lanes wander between their vertices. Every vertex (junctions, gates, the sites
## laid along them) stays exactly where BASE_PATHS puts it; between two, the line swings up to MEANDER m
## to either side and back to zero at both ends. Everything that walks PATHS gets the wandering line.
## The main road keeps its line: its waystones and cart stand a fixed step beside it (lore/road.gd).
const MEANDER_IDS := {"west_track": 2.4, "moor_track": 2.4, "necropolis_way": 2.2, "orchard_lane": 2.2,
	"mere_causeway": 2.0, "south_track": 2.6}
const MEANDER_STEP := 6.0
static var PATHS: Array = _meander(BASE_PATHS)


static func _meander(base: Array) -> Array:
	var out: Array = []
	for path: Dictionary in base:
		var amp := float(MEANDER_IDS.get(String(path.id), 0.0))
		if amp <= 0.0:
			out.append(path)
			continue
		var src: Array = path.pts
		var pts: Array = [src[0]]
		var walked := 0.0
		var seed_f := float(String(path.id).hash() % 1000) * 0.01
		for i in src.size() - 1:
			var a: Vector2 = src[i]
			var b: Vector2 = src[i + 1]
			var ab := b - a
			var ln := ab.length()
			var side := Vector2(-ab.y, ab.x) / maxf(ln, 0.001)
			var n := maxi(1, int(ln / MEANDER_STEP))
			for k in range(1, n):
				var t := float(k) / float(n)
				var s := walked + ln * t
				var wave := sin(s * TAU / 34.0 + seed_f) * 0.7 + sin(s * TAU / 13.0 + seed_f * 2.3) * 0.3
				pts.append(a + ab * t + side * amp * wave * sin(PI * t))
			pts.append(b)
			walked += ln
		var np := path.duplicate()
		np["pts"] = pts
		out.append(np)
	return out

## The crossing (RealmRift): a walkable ruined viaduct from the rift's south rim to the summit ward,
## built from the old stair kit (stair_step / stair_column / stair_platform .glb) and OssKit stone.
## It replaces the hub stair's job (the only way up) but must not read as a stairway: broken arches,
## platforms, ramps, a gap bridged by a fallen column, switchbacks round basalt pillars.
const CROSSING_FOOT := Vector3(0.0, 0.6, -8.0)
const CROSSING_HEAD := SUMMIT_WARD

## Boss / landmark anchors (centre on the ground; y from the terrain).
## r34: the henge moved 14 m west and 6 m north onto a broader hill so its raid floor (RAIDS "henge",
## r 31) clears the Glimmer Glade and west_way; the stair foot moved with it.
const HENGE_C := Vector2(-86.0, -24.0)                     ## ThornHenge.C xz (r33: (-72, -18))
const HENGE_STAIR_FOOT := Vector2(-50.0, -10.0)            ## end of west_way
const CHAPEL_C := Vector2(-72.0, 52.0)
const GLADE_C := Vector2(-38.0, 8.0)
const BARROWS_C := Vector2(78.0, -42.0)
const OSSUARY_GATE := Vector3(34.0, 4.0, -66.0)            ## where fen_descent meets the crypt (RealmBosses)


## r34: inside the streamed crypt or its reserved pit hall.
static func in_ossuary(p: Vector3) -> bool:
	return OSSUARY.has_point(p) or OSSUARY_HALL.has_point(p)


## r34: the raid footprint record for a boss arena id ("henge", "summit"), or {}.
static func raid(id: String) -> Dictionary:
	for r: Dictionary in RAIDS:
		if r.id == id:
			return r
	return {}


## Designed landform. Smooth, deterministic, cheap: the land's big shapes only.
## - meadow basin round Hearthward at ~0, the Pilgrims' Road plain south at ~0.5
## - Thornwood: rolling hills to ~9, Thorn Henge on a broad hilltop (its raid floor levelled at 9)
## - Hollow Fen: low, -1.5 .. 0, with pools below the water line (-0.9)
## - the Ashen Rift: the kept chasm (old baked terrain) down to below the lava
## - the summit crag under the summit platform, and the Crowns rising to ~45 at the north edge
## - r34: the Lanternless Moor's high heath and tor, the Founder's Pits' bench and slag heaps, the
##   Saints' Quarry's benches cut into the Crowns' foot (post_detail), Corvin's Mere's basin, the
##   Waiting Field's slope, the Cinder Orchard's shelf, the southern downs and low rims at the edges
## - outside BOUNDS the ground climbs into a horizon ring of hills so the edge is never seen
static func macro_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := 0.0
	# rolling base
	h += sin(x * 0.031 + 0.7) * cos(z * 0.027 - 0.4) * 1.6 + sin(x * 0.011 - z * 0.017) * 1.2
	# Thornwood hills, Henge hill
	var tw := _rect_w(p, Rect2(-150, -66, 120, 111), 22.0)
	h += tw * (4.0 + 3.0 * sin(x * 0.07) * sin(z * 0.06))
	h += 5.0 * _bump(p, HENGE_C, 56.0)
	# Hollow Fen hollow
	h -= 1.8 * _rect_w(p, Rect2(40, -80, 70, 115), 18.0)
	# r34: the Lanternless Moor (high swelling heath, a tor near its middle)
	var mo := _rect_w(p, Rect2(124, -66, 31, 106), 14.0)     # its rise ends by x 110: the Barrow Field's secrets keep their ground
	h += mo * (4.5 + 1.8 * sin(z * 0.045 + 1.3) * cos(x * 0.05))
	h += 7.0 * _bump(p, Vector2(141, -24), 17.0)
	# r34: the Founder's Pits (a bench at the Crowns' foot, three slag heaps)
	var fo := _rect_w(p, Rect2(108, -112, 47, 46), 14.0)
	h = lerpf(h, 3.0, fo * 0.8)
	h += 4.5 * _bump(p, Vector2(121, -84), 9.0) + 3.5 * _bump(p, Vector2(145, -99), 8.0) + 3.0 * _bump(p, Vector2(141, -75), 7.0)
	# r34: Corvin's Mere (a broad shallow basin: pools fill it below the water line)
	var me := _rect_w(p + _warp(p), Rect2(64, 90, 86, 62), 16.0)
	# meres between hummocks and causeway banks, not one lake (wildlife's frogs keep to a pool's shore)
	var mf := sin(x * 0.11 + 0.5) * sin(z * 0.13 - 0.3) + 0.6 * sin(x * 0.067 - z * 0.083 + 1.1) + 0.4 * sin((x + z) * 0.19)
	h -= me * (0.7 + 1.1 * mf)
	# r34: the Waiting Field (graves on a slope rising south, facing the mountain)
	var ne := _rect_w(p + _warp(p), Rect2(-44, 98, 86, 58), 16.0)
	h += ne * clampf((z - 100.0) / 55.0, 0.0, 1.0) * 5.0
	# r34: the Cinder Orchard (a gentle shelf)
	var oc := _rect_w(p + _warp(p), Rect2(-150, 90, 82, 62), 16.0)
	h = lerpf(h, 1.4 + 0.8 * sin(x * 0.05) * cos(z * 0.04), oc * 0.6)
	# r34: the Saints' Quarry's hill: a spur of the Crowns that quarry_cut benches down into a pit
	h += 11.0 * _bump(p, QUARRY_C, 46.0)
	# r34: the Rooted Holds (a hollow clearing in the west wood)
	h = lerpf(h, 2.5, 0.7 * _bump(p, Vector2(-134, 12), 24.0))
	# hearth basin and the road plain: pulled flat towards 0 / 0.5
	var hearth := _bump(p, Vector2(6, 38), 40.0)
	h = lerpf(h, 0.0, hearth)
	h = lerpf(h, 0.5, 0.7 * _rect_w(p, Rect2(-155, 50, 310, 30), 10.0) * (1.0 - hearth))
	# r34: the southern downs and low rims inside the west and east edges (the edge cliffs stand on them)
	h += smoothstep(148.0, 175.0, z) * 7.0
	var din := minf(x - BOUNDS.position.x, BOUNDS.end.x - x)
	h += (1.0 - smoothstep(0.0, 20.0, din)) * 3.5
	# the Crowns (north wall) and the summit crag. r35: it was one ruled cliff (foot on z -110, crest
	# 45 m everywhere). The foot now recesses north (never south of -110: nothing in the valley moves),
	# the crest rises and falls (~32-56 m), and peaks stand beyond the edge -- the tallest behind the
	# summit, so the Stair's top has a mountain to stand against instead of a flat wall.
	var keep_mid := 1.0 - _bump(Vector2(x, 0.0), Vector2.ZERO, 34.0)          # the rift and summit stay as built
	var recess := clampf(5.5 + 4.5 * sin(x * 0.043 + 0.4) + 2.5 * sin(x * 0.121 + 2.1), 0.0, 12.0) * keep_mid
	var north := clampf((-110.0 - recess - z) / 40.0, 0.0, 1.0)
	var crest := 0.82 + 0.3 * (0.5 + 0.5 * sin(x * 0.067 + 1.2)) + 0.12 * sin(x * 0.19)
	h += north * north * 45.0 * crest
	h += 40.0 * _bump(p, Vector2(0, -166), 46.0) + 22.0 * _bump(p, Vector2(-72, -160), 30.0) + 26.0 * _bump(p, Vector2(86, -163), 32.0)
	h = maxf(h, 24.2 * _bump(p, Vector2(0, -95), 34.0) - 2.0)
	# the rift: the kept chasm. Inside the rift rect the baked terrain is authoritative (RealmLand
	# keeps the old heights there); this is only the macro shape for planning.
	var rift := _rect_w(p, Rect2(-24, -118, 48, 106), 10.0) * (1.0 - _bump(p, Vector2(0, -95), 30.0))
	h = lerpf(h, -18.0, rift * 0.9)
	# horizon ring
	var out := _out_dist(p, BOUNDS)
	h += smoothstep(0.0, 60.0, out) * 28.0
	return post_detail(x, z, h)


## r34: shapes that must survive the detail noise (RealmLand calls this after its noise, and again after
## the kept core's old heights): the Saints' Quarry's benches and the raid floors.
static func post_detail(x: float, z: float, h: float) -> float:
	return raid_shape(x, z, quarry_cut(x, z, h))


## r34: the Saints' Quarry: benches 6 m wide and 3.2 m high cut down into whatever stands higher,
## round a floor at y 1 (an ellipse, longer east-west), so the Crowns' foot is stepped like a stair
## that was never finished. Ground already lower is left alone.
const QUARRY_C := Vector2(-127.0, -104.0)
static func quarry_cut(x: float, z: float, h: float) -> float:
	var q := Vector2((x - QUARRY_C.x) * 0.8, z - QUARRY_C.y)
	var d := q.length()
	if d > 52.0:
		return h
	var t := maxf(0.0, d - 11.0) / 6.0
	var lv := floorf(t)
	var bench := 1.0 + 3.2 * (lv + smoothstep(0.55, 1.0, t - lv))     # 3.3 m tread, 2.7 m riser
	var w := 1.0 - smoothstep(40.0, 52.0, d)
	if x < BOUNDS.position.x + 4.0:
		w *= smoothstep(BOUNDS.position.x - 6.0, BOUNDS.position.x + 4.0, x)    # the west rim stays a wall
	return lerpf(h, minf(h, bench), w)


## r34: the raid floors (RAIDS): "level" pulls the ground to y inside r and blends back over `fall`;
## "clear" only cuts it down to y - 0.8 inside r + 2 (the summit's deck stands over the chasm).
static func raid_shape(x: float, z: float, h: float) -> float:
	var p := Vector2(x, z)
	for r: Dictionary in RAIDS:
		var d := p.distance_to(r.c)
		var rr: float = r.r
		var fall: float = r.fall
		if d > rr + 2.0 + fall:
			continue
		var w := 1.0 - smoothstep(rr + 2.0, rr + 2.0 + fall, d)
		if String(r.mode) == "clear":
			h = lerpf(h, minf(h, float(r.y) - 0.8), w)
		else:
			h = lerpf(h, float(r.y), w)
	return h


## The named place at xz: the most specific region wins (r30). The small landmark circles (the chapel,
## the henge, the barrows, the summit, the glade) all sit inside a larger rect whose weight is 1.0
## all through, and the old "first highest weight" pick gave them 0 % of their own ground: no banner,
## no Journal discovery, the wrong encounter tier. Each circle now owns its ground out to 0.8 of its
## radius (falling off to 1.4 r), and where two places both hold full weight the smaller one wins.
## The codex (ui/codex.gd) and the encounter tiers use this; biome_at keeps the landform blend.
static func region_at(x: float, z: float) -> Dictionary:
	var best := {}
	var best_s := 0.0
	for r: Dictionary in REGIONS:
		var sc := place_score(r, x, z)
		if sc > best_s:
			best_s = sc
			best = r
	return best


## Selection score for region_at: a plateau weight plus a tiny bonus for being small.
static func place_score(r: Dictionary, x: float, z: float) -> float:
	var w := place_weight(r, x, z)
	if w <= 0.0:
		return 0.0
	return w + 0.01 * (1.0 - clampf(_area(r) / 60000.0, 0.0, 1.0))


## 1.0 inside a rect or within 0.8 r of a circle's centre, then a smooth falloff (rect: 18 m, circle:
## to 1.4 r, where region_weight also ends).
static func place_weight(r: Dictionary, x: float, z: float) -> float:
	var p := Vector2(x, z)
	if r.has("rect"):
		return _rect_w(p, r.rect, 18.0)
	var rr := float(r.r)
	var d := p.distance_to(r.c)
	var t := clampf(1.0 - (d - rr * 0.8) / (rr * 0.6), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _area(r: Dictionary) -> float:
	if r.has("rect"):
		return (r.rect as Rect2).get_area()
	return PI * float(r.r) * float(r.r)


static func region_weight(r: Dictionary, x: float, z: float) -> float:
	var p := Vector2(x, z)
	if r.has("rect"):
		return _rect_w(p + _warp(p), r.rect, 18.0)      # r35: ragged land edges (names keep the plain rect)
	return _bump(p, r.c, float(r.r) * 1.4)


## The landform biome (footsteps, weather, wildlife, ambience): the heaviest region by its blend
## weight, as RealmLand painted the ground. Not region_at: a place's name may sit on another's land
## (the summit circle reaches over the rift's ash, whose lava ambience must stay).
static func biome_at(x: float, z: float) -> String:
	var best := {}
	var best_w := 0.0
	for r: Dictionary in REGIONS:
		var w := region_weight(r, x, z)
		if w > best_w:
			best_w = w
			best = r
	return String(best.get("biome", "meadow"))


## Ground height from the real terrain (after RealmLand), or the macro shape before it exists.
static func ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	if space:
		# nudged a few mm: a ray exactly on a terrain grid edge can slip through the trimesh (Jolt)
		x += 0.0037
		z += 0.0029
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 120, z), Vector3(x, -60, z), 1))
		if hit and String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
	return macro_height(x, z)


## Distance from p to the nearest path centreline (and which path), for keeping things off paths.
static func path_dist(p: Vector2) -> float:
	var best := INF
	for path: Dictionary in PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t) - float(path.w))
	return best


## r35: a smooth, deterministic offset (up to ~7 m) so rectangular regions' land and shapes meet
## along wandering lines instead of ruled ones. Only for painting and landform, never for names.
static func _warp(p: Vector2) -> Vector2:
	return Vector2(sin(p.y * 0.09 + 1.3) + 0.6 * sin(p.y * 0.21 + p.x * 0.05),
		sin(p.x * 0.08 + 0.4) + 0.6 * sin(p.x * 0.19 - p.y * 0.06)) * 4.4


static func _bump(p: Vector2, c: Vector2, r: float) -> float:
	var t := clampf(1.0 - p.distance_to(c) / r, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _rect_w(p: Vector2, r: Rect2, fall: float) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	var d := Vector2(dx, dz).length()
	var t := clampf(1.0 - d / fall, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _out_dist(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()
