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

## doubled again (docs/r37_expansion.md): the Outer Marches west and east of the old gates, and
## the southern downs. The old Realm (x -155..155, z -150..175) is OLD_BOUNDS; nothing in it moves.
const BOUNDS := Rect2(-260.0, -150.0, 520.0, 390.0)        ## playable xz (x -260..260, z -150..240); r34: 310 x 325
const OLD_BOUNDS := Rect2(-155.0, -150.0, 310.0, 325.0)    ## the r34 Realm, inside the March Wall
const OUTER := Rect2(-352.0, -240.0, 704.0, 572.0)         ## terrain extent incl. the horizon ring (4 m lattice)
const LAVA_Y := -15.5                                       ## the rift's lava surface (LavaWorks)

## Fixed points (do not move: the kept brazier, tavern, Ossuary and summit depend on them).
const SPAWN := Vector3(0.0, 0.0, 33.0)                     ## the spawn brazier (Zone/Braziers/Sanctuary)
## New game: on the Pilgrims' Road at waystone III, facing Hearthward (docs/STORY.md known gap).
## The Sanctuary fire stays SPAWN; Continue / kindle still wake at the last checkpoint.
const PLAYER_START := Vector3(-16.0, 0.15, 55.5)
const TAVERN := Rect2(10.0, 25.6, 16.0, 9.2)               ## Tavern.X0..X1, Z0..Z1 (+ yard east to x 29)
## relocation (Luke, 14 Nov: "the ossuary is in a terrible place ... all bosses are on the top of the map"):
## the Ossuary no longer hangs on the rift's east wall. It stands under the Waiting Field: a quarried bone
## pit cut into the field's south slope (the Pilgrims' Landing at its north lip, the bank to the south),
## the Counting Stair and the Bone Abbot's pit hall under the bank. Its builders keep their own (local)
## coordinates and the Ossuary node carries the frame (world/areas/ossuary/oss_frame.gd); these are the
## world volumes. The old site on the rift's east wall is left bare (OSSUARY_OLD: RealmLand's kept core).
## "Inside the Ossuary" checks use in_ossuary() (the pit or the hall), never one AABB round both.
const OSSUARY_OLD := AABB(Vector3(2.0, -6.0, -110.0), Vector3(30.0, 32.0, 88.0))   ## the old site (the rift's kept east wall)
const OSSUARY := AABB(Vector3(-63.0, -33.4, 146.0), Vector3(108.0, 56.0, 46.0))   ## the pit and its tiers: x -63..45, y -33..23, z 146..192
const OSSUARY_HALL := AABB(Vector3(-6.0, -45.4, 177.0), Vector3(56.0, 32.0, 56.0))   ## x -6..50, y -45..-13, z 177..233: the pit hall, under the downs
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
	# the two Marches bosses (docs/r37_expansion.md). The West agent builds the Hierarch's fight in
	# the toppled statue's broken crown; the East agent the Anchoress's on the cliff terrace.
	{"id": "hierarch", "c": Vector2(-214.0, -104.0), "r": 24.0, "y": 4.0, "fall": 12.0, "mode": "level",
		"gate": Vector2(-200.0, -82.0), "boss": "r37_hierarch"},
	{"id": "anchorhold", "c": Vector2(214.0, -132.0), "r": 18.0, "y": 16.0, "fall": 20.0, "mode": "level",
		"gate": Vector2(206.0, -114.0), "boss": "r37_anchoress"},
]

## Regions: [id, name, centre xz, radius or rect, biome, lore one-liner]. Biomes drive flora,
## ground material and props. Radii are soft (RealmLand blends 15-25 m between biomes).
## r34 layout: "tier" is the suggested encounter tier (core/life/encounters/tiers.gd REGION_BASE) and
## "purpose" what the place is for (docs/r34/layout.md); the seven r34 regions fill the new ground.
const REGIONS := [
	{"id": "hearth", "name": "Hearthward", "c": Vector2(6, 38), "r": 34.0, "blobs": [{"c": Vector2(-170, -80), "r": 16.0}], "biome": "meadow", "tier": 0,
		"lore": "The last kindled village: the Kindled Keg, the spawn brazier, cottages gone quiet."},
	{"id": "road", "name": "The Pilgrims' Road", "rect": Rect2(-260, 50, 520, 30), "biome": "heath", "tier": 0,
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
	{"id": "ossuary", "name": "The Ossuary", "rect": Rect2(-62, 148, 106, 38), "biome": "ruin", "tier": 2,
		"purpose": "the necropolis's charnel house: a quarried bone pit under the Waiting Field's slope, the monastery stepping down its wall over a still pool, the Counting Stair and the Abbot's hall beneath",
		"lore": "Boss: the Bone Abbot. Seal 'oss_gallery'. Streamed area (world/areas/ossuary): the Pilgrims' Landing at the Waiting Field's west end, the bone bridge, the tiers."},
	{"id": "summit", "name": "The Summit of Ascension", "c": Vector2(0, -104), "r": 42.0, "biome": "crag", "tier": 3,
		"lore": "Boss: the Ascended Warden, last priest of the ascension. Seal 'summit'."},
	{"id": "crags", "name": "The Crowns", "rect": Rect2(-260, -150, 520, 40), "biome": "crag", "tier": 2,
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
		"purpose": "the pilgrims' necropolis: ranks of graves and tombs on a slope facing the mountain; the tomb at its head, and below the slope's brow the quarry of the Ossuary",
		"lore": "Those who died on the road before the Stair lie here in ranks, all facing the mountain, waiting."},
	{"id": "mere", "name": "Corvin's Mere", "rect": Rect2(64, 90, 86, 62), "biome": "fen", "tier": 1,
		"purpose": "a drowned water-meadow: causeways, islets, floating lamps, a half-sunk chapel",
		"lore": "Brother Corvin rowed fire out here to the sunk dead. Some of his lamps still float."},
	# --- the Outer Marches and the southern downs (docs/r37_expansion.md) --------------------
	# West Marches (the West agent)
	{"id": "weirford", "name": "Weirford", "c": Vector2(-205, 66), "r": 26.0, "biome": "meadow", "tier": 1,
		"purpose": "a living outpost at the river crossing: inn, mill on the weir, smithy, stables, a watch post",
		"lore": "The last town the Order did not burn: it ground the abbey's flour, and kept its head down."},
	{"id": "sorrow", "name": "The Sorrow's Banks", "rect": Rect2(-258, -62, 100, 104), "blobs": [{"c": Vector2(-232, 52), "r": 18.0}], "biome": "oldforest", "tier": 2,
		"purpose": "wooded river valley north of Weirford: alder banks, fords, a drowned shrine, rares",
		"lore": "The river comes down off the Crowns grey with ash and does not clear until the weir."},
	{"id": "hierarch", "name": "The Fallen Hierarch", "rect": Rect2(-258, -140, 92, 78), "biome": "heath", "tier": 3,
		"purpose": "a colossal toppled statue (about 60 m) in a moss valley at the Crowns' foot; the boss in its broken crown",
		"lore": "The Order raised him taller than the Stair. The night he fell, the sky began to turn."},
	{"id": "siege", "name": "The Siege Lines", "rect": Rect2(-258, 110, 100, 130), "blobs": [{"c": Vector2(-172, 232), "r": 22.0}], "biome": "ruin", "tier": 2,
		"purpose": "earthwork rings, palisades, rotted trebuchets and a siege tower where the Marches fought the Order",
		"lore": "The Marches came against the gates with timber and fire. The gates held; the Marches did not."},
	# East Marches (the East agent)
	{"id": "stillwater", "name": "Stillwater", "rect": Rect2(160, -50, 98, 116), "biome": "fen", "tier": 2,
		"purpose": "a cold lake under a bluff; the Lamplighters' Spire, a climbable beacon tower whose lamp you relight",
		"lore": "The lamplighters kept a flame on the Spire so the Marches could find the road at night."},
	{"id": "anchorholds", "name": "The Anchorholds", "rect": Rect2(166, -150, 92, 96), "blobs": [{"c": Vector2(186, -72), "r": 18.0}], "biome": "crag", "tier": 3,
		"purpose": "hermits' cells cut into the Crowns' face, ladders and walkways; the boss on the cliff terrace",
		"lore": "Anchorites walled themselves into the rock to pray the sky still. One of them is still praying."},
	{"id": "saltmarket", "name": "Saltmarket", "c": Vector2(212, 92), "r": 18.0, "biome": "heath", "tier": 1,
		"purpose": "a salt-workers' hamlet at the east road's fork: a handful of people, a trader, a fire",
		"lore": "Salt keeps meat and keeps the hollowed off a threshold. Saltmarket sells both kinds."},
	{"id": "saltpans", "name": "The White Pans", "rect": Rect2(160, 112, 98, 128), "blobs": [{"c": Vector2(172, 104), "r": 16.0}], "biome": "salt", "tier": 2,
		"purpose": "pale salt flats: evaporation pans, timber derricks, a salt-works, crystal crusts; open and strange",
		"lore": "Flat as a table and white as bone. The wind writes on it and the sun is never there to read it."},
	# the southern downs (the South agent)
	{"id": "downs", "name": "The Southern Downs", "rect": Rect2(-155, 175, 310, 65), "biome": "heath", "tier": 1,
		"purpose": "open chalk downs south of the Waiting Field, between the oak and the well",
		"lore": "Sheep country once. The shepherds' huts still stand; the shepherds walked north and did not come back."},
	{"id": "oak", "name": "The Grandmother Oak", "c": Vector2(-70, 206), "r": 30.0, "biome": "oldforest", "tier": 2,
		"purpose": "a colossal hollow dead oak: a stair inside the trunk, walks along the great limbs, a secret at the top",
		"lore": "Older than the Order, older than the henge. The Rooted say the first fire was carried out of it."},
	{"id": "well", "name": "The Well of Echoes", "c": Vector2(72, 204), "r": 30.0, "biome": "crag", "tier": 2,
		"purpose": "an open sinkhole about 40 m across and 24 m deep, a waterfall into it, a ledge path down to a pool and a cave",
		"lore": "Drop a stone and count. Nobody has ever counted to the end of the echoes."},
]

## the Sorrow (West Marches): the river's centreline from the Crowns to the south edge, with the
## bed's half width. RealmLand carves the channel and the water stands in it in stepped reaches (the
## weir at Weirford is one step); the road crosses on a bridge at the weir. The Foundation agent owns it.
const RIVER := {"w": 6.0, "pts": [Vector2(-212, -56), Vector2(-208, -40), Vector2(-204, -30),
	Vector2(-214, 10), Vector2(-208, 46), Vector2(-205, 60), Vector2(-222, 84), Vector2(-240, 110), Vector2(-250, 140),
	Vector2(-254, 180), Vector2(-254, 240)]}
## The river's course as built. The first cut ran the Sorrow through the Fallen Hierarch's
## raid floor and down siege_track's line; it now rises from a spring west of weir_track's end (the Crowns'
## run-off goes underground in the statue's valley), keeps to the west of every slot, crosses the road once at
## Weirford (z~64) and leaves by the south-west edge. Water stands in reaches: RIVER_L0 at the head, falling
## by RIVER_STEPS = [z, drop] (the weir at z 60 drops 0.5 m; the lowest reach, -0.5, keeps its banks above the flora's water line). The bed is RIVER_DEPTH under the surface.
const RIVER_L0 := 0.6
const RIVER_STEPS := [[-14.0, 0.2], [30.0, 0.2], [60.0, 0.5], [120.0, 0.1], [170.0, 0.1]]
const RIVER_DEPTH := 1.35
## Stillwater's lake (East Marches): an elliptical basin, its surface, and the Spire's bluff.
const LAKE_C := Vector2(206.0, 4.0)
const LAKE_R := Vector2(30.0, 40.0)          ## semi-axes x, z
const LAKE_Y := -0.9                          ## the water line (as the fen's pools)
const SPIRE_C := Vector2(242.0, 6.0)          ## the Lamplighters' Spire on its bluff (~12 m above the water)
## the Well of Echoes' sinkhole (the southern downs).
const WELL_C := Vector2(72.0, 204.0)
const WELL_R := 20.0                          ## the rim radius; the floor pool ~24 m below the downs
## the March Wall: the old Realm's west and east boundary, from the Crowns' foot (z -112) to the south
## edge. It follows the land: one polyline (x, z; z ascending) per side that swings out onto knolls and
## ridges and back, straight only where the road crosses (the gates, x +-155). The line itself is
## RealmMarch (wall_x); MARCH_WALL_X is the old Realm's nominal edge (OLD_BOUNDS), where the r34 downs' rise fades out.
const MARCH_WALL_X := 155.0
const MARCH_GATES := [Vector2(-155, 67), Vector2(155, 68)]


## r34 layout: suggested slots for phase 2 in the new ground (docs/r34/layout.md): a fire (an Ember Road
## stop), places of interest, camps. Checked by zz/layout_r34_test (inside the region, on dry walkable
## ground off the ways and sites; "poi_wet" may stand in water). Builders may move a slot a few metres.
const SLOTS := {
	# --- (docs/r37_expansion.md): builders may move a slot a few metres; a region agent may edit
	# only its own regions' entries here.
	"weirford": [
		{"kind": "fire", "at": Vector2(-196, 74), "note": "the town's square, east of the bridge"},
		{"kind": "poi_wet", "at": Vector2(-207, 56), "note": "the mill on the weir"},
		{"kind": "poi", "at": Vector2(-190, 60), "note": "the inn, the smithy, the stables"}],
	"sorrow": [
		{"kind": "fire", "at": Vector2(-190, -20), "note": "a ford on weir_track"},
		{"kind": "poi_wet", "at": Vector2(-208, -40), "note": "the drowned shrine in the river"},
		{"kind": "camp", "at": Vector2(-240, -10), "note": "the west bank"},
		{"kind": "camp", "at": Vector2(-178, -50), "note": "the east bank"}],
	"hierarch": [
		{"kind": "fire", "at": Vector2(-193, -80), "note": "where weir_track reaches the valley, 4 m off its line"},
		{"kind": "poi", "at": Vector2(-236, -84), "note": "the statue's hand, palm up"},
		{"kind": "camp", "at": Vector2(-186, -118), "note": "under the Crowns"}],
	"siege": [
		{"kind": "fire", "at": Vector2(-219, 127), "note": "beside siege_track at the outer earthwork"},
		{"kind": "poi", "at": Vector2(-236, 170), "note": "the siege tower"},
		{"kind": "poi", "at": Vector2(-196, 210), "note": "the trebuchet line"},
		{"kind": "camp", "at": Vector2(-180, 150), "note": "the palisade"},
		{"kind": "camp", "at": Vector2(-240, 218), "note": "the south rings"}],
	"stillwater": [
		{"kind": "fire", "at": Vector2(220, 52), "note": "the lake's south shore, off spire_track"},
		{"kind": "poi", "at": Vector2(242, 6), "note": "the Lamplighters' Spire"},
		{"kind": "poi_wet", "at": Vector2(196, -14), "note": "a sunken boat-house"},
		{"kind": "camp", "at": Vector2(172, -36), "note": "the north shore"}],
	"anchorholds": [
		{"kind": "fire", "at": Vector2(209, -83), "note": "the foot of the cliff, a few metres off anchor_track's bend"},
		{"kind": "poi", "at": Vector2(214, -132), "note": "the cliff terrace: the lower cells, the timber walk, the chapel and the Anchoress's room"},
		{"kind": "camp", "at": Vector2(180, -82), "note": "the scree at the cliff's foot"}],
	"saltmarket": [
		{"kind": "fire", "at": Vector2(218, 98), "note": "the hamlet's yard"},
		{"kind": "poi", "at": Vector2(214, 95), "note": "the hamlet: houses, drying shed, the trader's stall"}],
	"saltpans": [
		{"kind": "poi", "at": Vector2(232, 168), "note": "the salt-works, its pans and derricks"},
		{"kind": "poi", "at": Vector2(238, 212), "note": "the crystal crust"},
		{"kind": "camp", "at": Vector2(178, 196), "note": "the west pans"},
		{"kind": "camp", "at": Vector2(240, 140), "note": "the east pans"}],
	"downs": [
		{"kind": "poi", "at": Vector2(0, 196), "note": "a shepherds' hut and fold"},
		{"kind": "camp", "at": Vector2(-120, 214), "note": "the west downs"},
		{"kind": "camp", "at": Vector2(126, 214), "note": "the east downs"}],
	"oak": [
		{"kind": "fire", "at": Vector2(-44, 196.4), "note": "beside downs_track, in the oak's shade"},
		{"kind": "poi", "at": Vector2(-70, 206), "note": "the Grandmother Oak"}],
	"well": [
		{"kind": "fire", "at": Vector2(44, 196.4), "note": "beside downs_track, east of the hut"},
		{"kind": "poi_wet", "at": Vector2(72, 204), "note": "the Well of Echoes (its pool is in the pit)"}],
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
		{"kind": "poi", "at": Vector2(0, 141), "note": "the mausoleum at the head of the way, on the brow above the Ossuary's quarry"},
		{"kind": "poi", "at": Vector2(-26, 118), "note": "the pilgrims' ranks"},
		{"kind": "camp", "at": Vector2(-30, 140), "note": "the west tombs"},
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
	# west_way's last turn meets the henge stair on its own axis, 2.5 m out (thorn_henge.gd's lane): a straight run to the
	# foot passed 0.3 m from the north pinnacle and walked into it
	{"id": "west_way", "w": 1.8, "pts": [Vector2(-4, 30), Vector2(-20, 24), Vector2(-38, 10), Vector2(-46, -2), Vector2(-47.6, -10.8), Vector2(-50, -10)]},
	{"id": "east_way", "w": 1.8, "pts": [Vector2(26, 22), Vector2(42, 10), Vector2(58, -12), Vector2(72, -34), Vector2(78, -42)]},
	{"id": "fen_descent", "w": 1.6, "pts": [Vector2(78, -42), Vector2(62, -56), Vector2(54, -59.5)]},   # ends at the fen's fire (the Threshold); the Ossuary no longer waits at its end
	{"id": "road", "w": 2.2, "pts": [Vector2(-255, 62), Vector2(-232, 64), Vector2(-205, 66), Vector2(-180, 66), Vector2(-150, 67), Vector2(-104, 64), Vector2(-72, 60), Vector2(-40, 58), Vector2(-6, 54), Vector2(2, 44), Vector2(40, 60), Vector2(104, 66), Vector2(150, 68), Vector2(180, 70), Vector2(212, 74), Vector2(240, 72), Vector2(255, 70)]},
	{"id": "chapel_lane", "w": 1.4, "pts": [Vector2(-60, 58), Vector2(-68, 52)]},
	{"id": "rift_rim", "w": 2.0, "pts": [Vector2(0, 22), Vector2(0, 4), Vector2(0, -3)]},   # ends where the approach flight begins (it ran on into the forecourt's body)
	# r34
	{"id": "west_track", "w": 1.4, "pts": [Vector2(-118, 65), Vector2(-124, 44), Vector2(-132, 22), Vector2(-138, -6), Vector2(-138, -40), Vector2(-132, -66), Vector2(-126, -84)]},
	{"id": "moor_track", "w": 1.4, "pts": [Vector2(124, 67), Vector2(130, 44), Vector2(134, 18), Vector2(132, -18), Vector2(130, -46), Vector2(128, -72), Vector2(130, -86)]},
	{"id": "necropolis_way", "w": 1.8, "pts": [Vector2(-6, 54), Vector2(-5, 74), Vector2(-3, 96), Vector2(0, 112), Vector2(0, 128)]},
	{"id": "orchard_lane", "w": 1.4, "pts": [Vector2(-98, 63), Vector2(-102, 84), Vector2(-108, 104), Vector2(-112, 122)]},
	{"id": "mere_causeway", "w": 1.6, "pts": [Vector2(92, 65), Vector2(96, 84), Vector2(100, 104), Vector2(104, 120)]},
	{"id": "south_track", "w": 1.4, "pts": [Vector2(-112, 122), Vector2(-80, 132), Vector2(-40, 134), Vector2(0, 128), Vector2(40, 134), Vector2(76, 128), Vector2(104, 120)]},
	# the Marches (docs/r37_expansion.md)
	{"id": "weir_track", "w": 1.4, "pts": [Vector2(-196, 66), Vector2(-192, 36), Vector2(-188, 0), Vector2(-188, -40), Vector2(-196, -76), Vector2(-200, -82)]},
	{"id": "siege_track", "w": 1.4, "pts": [Vector2(-214, 65), Vector2(-216, 100), Vector2(-214, 128), Vector2(-206, 160), Vector2(-196, 190)]},
	{"id": "spire_track", "w": 1.4, "pts": [Vector2(212, 74), Vector2(214, 52), Vector2(226, 30), Vector2(236, 14)]},
	{"id": "anchor_track", "w": 1.4, "pts": [Vector2(180, 70), Vector2(174, 40), Vector2(172, 0), Vector2(178, -40), Vector2(196, -70), Vector2(204, -84), Vector2(205, -102), Vector2(206, -108)]},
	{"id": "salt_track", "w": 1.4, "pts": [Vector2(212, 74), Vector2(214, 104), Vector2(206, 140), Vector2(202, 180), Vector2(196, 212)]},
	{"id": "downs_track", "w": 1.4, "pts": [Vector2(-196, 190), Vector2(-150, 196), Vector2(-110, 190), Vector2(-44, 192), Vector2(0, 190), Vector2(44, 192), Vector2(110, 186), Vector2(160, 200), Vector2(196, 212)]},
	# the Crowns' foot, east-west: the two boss corners are joined to the old north (through the wall's breaches)
	{"id": "crowns_west", "w": 1.4, "pts": [Vector2(-196, -76), Vector2(-178, -72), Vector2(-164, -76), Vector2(-150, -74), Vector2(-140, -70), Vector2(-132, -66)]},
	{"id": "crowns_east", "w": 1.4, "pts": [Vector2(196, -70), Vector2(182, -74), Vector2(168, -72), Vector2(156, -68), Vector2(146, -67), Vector2(138, -66), Vector2(131, -69), Vector2(128, -72)]},
	{"id": "oss_lane", "w": 1.4, "pts": [Vector2(-40, 134), Vector2(-41.5, 141), Vector2(-40, 147.5)]},          # from south_track to the Ossuary's Pilgrims' Landing
	{"id": "downs_link", "w": 1.4, "pts": [Vector2(40, 134), Vector2(50, 158), Vector2(48, 176), Vector2(44, 192)]},     # the Waiting Field to the downs, east of the mausoleum
]

## r35 (docs/critique/r35_full.md: "the south half is a grid of rectangles and straight roads"): the
## southern tracks and lanes wander between their vertices. Every vertex (junctions, gates, the sites
## laid along them) stays exactly where BASE_PATHS puts it; between two, the line swings up to MEANDER m
## to either side and back to zero at both ends. Everything that walks PATHS gets the wandering line.
## The main road keeps its line: its waystones and cart stand a fixed step beside it (lore/road.gd).
const MEANDER_IDS := {"west_track": 2.4, "moor_track": 2.4, "necropolis_way": 2.2, "orchard_lane": 2.2,
	"mere_causeway": 2.0, "south_track": 2.6, "weir_track": 2.4, "siege_track": 2.4, "spire_track": 2.0,
	"anchor_track": 2.4, "salt_track": 2.2, "crowns_west": 2.2, "crowns_east": 2.2, "downs_track": 2.8, "downs_link": 1.6}
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
const OSSUARY_GATE := Vector3(-40.0, 5.2, 147.5)          ## the Pilgrims' Landing: where the lane ends and the bone bridge begins (OssFrame.LANDING)


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
	return final_shape(x, z, macro_dry(x, z))


## macro_height without the water shapes (the river's bed, the lake, the Well): RealmLand adds its detail
## noise and hollow floors to this, then final_shape, so the floors cannot lift a riverbed.
static func macro_dry(x: float, z: float) -> float:
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
	h = lerpf(h, 0.5, 0.7 * _rect_w(p, Rect2(-258, 50, 516, 30), 10.0) * (1.0 - hearth))       # on across the Marches (identical inside the old Realm)
	# the southern downs and low rims inside the old west and east edges (the edge cliffs stood on them).
	# the rim along the March Wall's line (a crest 3.5 m high that falls away outward; the line bends: wall_x), the
	# downs' rise stays for the old Realm's width and fades out over the Marches (|x| 155..180), and the
	# new edges (x +-260, z 240) get their own low rims in _marches. Inside OLD_BOUNDS nothing moves.
	var xout := maxf(absf(x) - MARCH_WALL_X, 0.0)
	h += smoothstep(148.0, 175.0, z) * 7.0 * (1.0 - smoothstep(0.0, 25.0, xout))
	# the rim stays where it stood, and the wall's line gets its own crest where it leaves it
	h += maxf(_crest(MARCH_WALL_X - absf(x)), _crest(RealmMarch.wall_x(-1 if x < 0.0 else 1, z) - absf(x)))
	# the Crowns (north wall) and the summit crag. It was once one ruled cliff (foot on z -110, crest
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
	# the Outer Marches and the southern downs (zero inside OLD_BOUNDS, eased in over 12 m outside it)
	var m37 := smoothstep(0.0, 12.0, _out_dist(p, OLD_BOUNDS))
	if m37 > 0.0:
		h = _marches(p, h, m37)
	# horizon ring
	var out := _out_dist(p, BOUNDS)
	h += smoothstep(0.0, 60.0, out) * 28.0
	return post_detail(x, z, h)


## r34: shapes that must survive the detail noise (RealmLand calls this after its noise, and again after
## the kept core's old heights): the Saints' Quarry's benches and the raid floors.
static func post_detail(x: float, z: float, h: float) -> float:
	return raid_shape(x, z, marches_detail(x, z, quarry_cut(x, z, h)))


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


# ------------------------------------------------------------------------------------------- ground

## landform anchors the region agents build on (Foundation agent). The raid floors, RIVER, LAKE_*,
## SPIRE_C and WELL_* above are the rest of the contract.
const PANS := Rect2(160.0, 112.0, 98.0, 128.0)             ## the White Pans' flat
const OAK_C := Vector2(-70.0, 206.0)                       ## the Grandmother Oak's knoll
const SPIRE_Y := LAKE_Y + 12.0                             ## the Spire's bluff top (a plateau r 8, walls to r 20)
const WELL_FLOOR_Y := -17.0                                ## the sinkhole's floor; its pool stands 0.8 m above it
const WELL_POOL_Y := -16.2
const WELL_POOL_R := 9.0                                   ## the floor's flat, with the pool, radius
const SIEGE_RINGS := [{"c": Vector2(-218.0, 168.0), "r": 29.0}, {"c": Vector2(-218.0, 168.0), "r": 64.0}]   ## low banks, ditches outside
const SIEGE_RECT := Rect2(-258.0, 110.0, 100.0, 130.0)


## The Marches' and the downs' macro shape (m = 0 inside OLD_BOUNDS, 1 from 12 m out). Smooth, cheap.
static func _marches(p: Vector2, h: float, m: float) -> float:
	var x := p.x
	var z := p.y
	# low rims at the new edges (the edge cliffs and the invisible walls stand on them)
	var ex := 1.0 - smoothstep(0.0, 20.0, minf(x - BOUNDS.position.x, BOUNDS.end.x - x))
	var ez := 1.0 - smoothstep(0.0, 20.0, BOUNDS.end.y - z)
	h += m * 4.0 * maxf(ex, ez)
	# the Sorrow's valley tilts down to Weirford (so the river is not perched on the plain)
	var rd := river_near(x, z).x
	if rd < 80.0:
		h += m * (1.0 - smoothstep(20.0, 70.0, rd)) * 2.6 * clampf((40.0 - z) / 100.0, 0.0, 1.0)
	# the Fallen Hierarch: a moss valley under the Crowns, flanks rising round the toppled statue
	var hv := _rect_w(p, Rect2(-258.0, -140.0, 92.0, 78.0), 12.0)
	h += m * hv * 11.0 * smoothstep(24.0, 60.0, p.distance_to(Vector2(-214.0, -104.0)))
	# the Anchorholds: the Crowns' face stands higher here, so the terrace (y 16) is a shelf cut into a wall
	var ah := _rect_w(p, Rect2(172.0, -150.0, 86.0, 70.0), 18.0)
	h += m * ah * 10.0 * smoothstep(-70.0, -130.0, z)
	# towns: Weirford and Saltmarket sit on flat ground
	h = lerpf(h, 0.6, m * 0.85 * _bump(p, Vector2(-205.0, 66.0), 36.0))
	h = lerpf(h, 0.6, m * 0.85 * _bump(p, Vector2(212.0, 92.0), 30.0))
	# the White Pans: flat and pale
	h = lerpf(h, 0.3, m * 0.92 * _rect_w(p, PANS, 16.0))
	# the Southern Downs: rolling chalk on the downs' rise, and the Grandmother Oak's knoll
	var dw := _rect_w(p, Rect2(-155.0, 175.0, 310.0, 65.0), 24.0)
	h += m * dw * (2.4 * sin(x * 0.043 + 1.1) * sin(z * 0.052 + 0.4) + 1.3 * sin(x * 0.021 - z * 0.033))
	h += m * 3.2 * _bump(p, OAK_C, 30.0)
	# cross-ridges, and the knolls the March Wall's spurs end on
	for rg: Dictionary in RealmMarch.RIDGES:
		var rw := RealmMarch.ridge_w(p, rg)
		if rw > 0.0:
			h += m * rw * float(rg.h) * lerpf(0.3, 1.0, smoothstep(1.5, 15.0, path_dist(p)))
	for sp: Dictionary in RealmMarch.SPURS:
		h += m * 3.6 * _bump(p, sp.tip, 12.0)
	# the Crowns' peaks beyond the old Realm: the wall keeps climbing to the new corners
	h += m * (26.0 * _bump(p, Vector2(-156.0, -166.0), 36.0) + 30.0 * _bump(p, Vector2(-222.0, -168.0), 38.0)
		+ 24.0 * _bump(p, Vector2(150.0, -166.0), 34.0) + 32.0 * _bump(p, Vector2(216.0, -170.0), 38.0))
	return h


## The March Wall's crest, 3.5 m high, by metres inside (+) or outside (-) its line.
static func _crest(din: float) -> float:
	return (1.0 - smoothstep(0.0, 20.0, din)) * 3.5 if din >= 0.0 else (1.0 - smoothstep(0.0, 16.0, -din)) * 3.5


## Shapes that must survive the detail noise in the Marches: the pans' evaporation beds and bunds, the
## siege lines' banks and ditches (RealmLand calls post_detail after its noise).
static func marches_detail(x: float, z: float, h: float) -> float:
	var p := Vector2(x, z)
	var m := smoothstep(0.0, 12.0, _out_dist(p, OLD_BOUNDS))
	if m <= 0.0:
		return h
	var pn := _rect_w(p, PANS.grow(-6.0), 10.0)
	if pn > 0.0:
		var u := fposmod(x + 7.0, 20.0)
		var v := fposmod(z + 3.0, 14.0)
		var e := minf(minf(u, 20.0 - u), minf(v, 14.0 - v))
		h += m * pn * ((1.0 - smoothstep(0.5, 1.7, e)) * 0.3 - 0.1 * smoothstep(1.7, 3.2, e))
	var sg := _rect_w(p, SIEGE_RECT.grow(8.0), 14.0)
	if sg > 0.0:
		for ring: Dictionary in SIEGE_RINGS:
			var c: Vector2 = ring.c
			var d := p.distance_to(c)
			var r: float = ring.r
			if absf(d - r) > 14.0:
				continue
			var a := atan2(z - c.y, x - c.x)
			var gap := 1.0 - smoothstep(0.55, 0.85, sin(a * 3.0 + r))         # breaches in the rings
			var bank := 1.9 * exp(-pow((d - r) / 2.4, 2.0))
			var ditch := 1.3 * exp(-pow((d - r - 4.8) / 2.1, 2.0))
			h += m * sg * gap * (bank - ditch)
	return h


## Water and basins, applied last (after RealmLand's hollow floors, which would lift them): the Sorrow's
## channel, Stillwater's basin and the Spire's bluff, the Well of Echoes' sinkhole.
static func final_shape(x: float, z: float, h: float, river := true) -> float:
	var p := Vector2(x, z)
	if x < -168.0:
		if river:
			h = river_shape(x, z, h)
	elif x > 170.0 and x < 262.0:
		h = lake_shape(p, h)
	elif x > 50.0 and x < 95.0 and z > 180.0:
		h = well_shape(p, h)
	if x > -70.0 and x < 52.0 and z > 128.0 and z < 196.0:
		h = OssFrame.pit_shape(p, h)
	return h


# --- the Sorrow ----------------------------------------------------------------------------------

static var _rv := PackedVector2Array()           ## the centreline, a Catmull-Rom of RIVER.pts every ~3 m
static var _rv_s := PackedFloat32Array()         ## arc length at each sample


## Build the river's samples (call once, on the main thread, before any threaded height pass).
static func prepare() -> void:
	if not _rv.is_empty():
		return
	var pts: Array = RIVER.pts
	var n := pts.size()
	var out := PackedVector2Array()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		var steps := maxi(2, int(p1.distance_to(p2) / 3.0))
		for k in steps:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / float(steps)))
	out.append(pts[n - 1])
	var ss := PackedFloat32Array()
	var acc := 0.0
	for i in out.size():
		if i > 0:
			acc += out[i].distance_to(out[i - 1])
		ss.append(acc)
	_rv_s = ss
	_rv = out


## Nearest point on the river's centreline: Vector3(distance, z of that point, arc length). INF away.
static func river_near(x: float, z: float) -> Vector3:
	if x > -164.0 or x < -272.0:
		return Vector3(INF, 0.0, 0.0)
	if _rv.is_empty():
		prepare()
	var p := Vector2(x, z)
	var best := INF
	var bz := 0.0
	var bs := 0.0
	for i in _rv.size() - 1:
		var a := _rv[i]
		var ab := _rv[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			bz = q.y
			bs = lerpf(_rv_s[i], _rv_s[i + 1], t)
	return Vector3(sqrt(best), bz, bs)


## Half width of the bed at arc length s (a spring pool at the head widens into the river).
static func river_w(s: float) -> float:
	return float(RIVER.w) * lerpf(0.45, 1.0, smoothstep(0.0, 16.0, s))


## The water surface of the reach at z (hw 0: the stepped surface the water stands at; hw > 0 smooths the
## steps over 2 hw metres, for the bed and the banks).
static func river_level(z: float, hw := 0.0) -> float:
	var l := RIVER_L0
	for st: Array in RIVER_STEPS:
		var zb: float = st[0]
		var t := (1.0 if z >= zb else 0.0) if hw <= 0.0 else smoothstep(zb - hw, zb + hw, z)
		l -= float(st[1]) * t
	return l


static func river_shape(x: float, z: float, h: float) -> float:
	var nr := river_near(x, z)
	var d := nr.x
	if d > 22.0:
		return h
	var w := river_w(nr.z)
	var bed := river_level(nr.y, 2.0) - RIVER_DEPTH
	var bank := river_level(nr.y, 9.0) + 0.55
	var target := lerpf(bed, bank, smoothstep(w * 0.5, w + 1.4, d))
	return lerpf(h, target, 1.0 - smoothstep(w + 1.5, w + 15.0, d))


## 0..1: how much of the point is the river's channel (paths are not levelled across it, no flora in it).
static func river_mask(x: float, z: float) -> float:
	if x > -164.0 or x < -272.0:
		return 0.0
	var nr := river_near(x, z)
	if nr.x > 14.0:
		return 0.0
	return 1.0 - smoothstep(river_w(nr.z) + 0.6, river_w(nr.z) + 3.5, nr.x)


# --- Stillwater, the Spire's bluff -----------------------------------------------------------------

static func lake_e(p: Vector2) -> float:
	return sqrt(pow((p.x - LAKE_C.x) / LAKE_R.x, 2.0) + pow((p.y - LAKE_C.y) / LAKE_R.y, 2.0))


static func lake_shape(p: Vector2, h: float) -> float:
	var e := lake_e(p)
	if e < 1.3:
		var bed := LAKE_Y - 5.0 * smoothstep(1.0, 0.45, e)
		# a shore that stays above the water all round (the bluff, below, is the only wall)
		var shore := maxf(h, LAKE_Y + 0.45)
		var inside := 1.0 - smoothstep(0.92, 1.12, e)
		var ring := 1.0 - smoothstep(1.0, 1.3, e)
		h = lerpf(h, shore, ring * 0.9)
		h = lerpf(h, bed, inside)
	var db := p.distance_to(SPIRE_C)
	if db < 22.0:
		h = lerpf(h, SPIRE_Y, 1.0 - smoothstep(8.0, 20.0, db))
	return h


# --- the Well of Echoes ------------------------------------------------------------------------------

static func well_shape(p: Vector2, h: float) -> float:
	var d := p.distance_to(WELL_C)
	if d > WELL_R + 8.0:
		return h
	# the downs track skirts the rim: the pit gives way where a path is
	var open := smoothstep(0.5, 4.5, path_dist(p))
	var wall := smoothstep(WELL_POOL_R, WELL_R, d)
	var pit := lerpf(WELL_FLOOR_Y, h, lerpf(1.0, wall, open))
	# a low lip round the rim
	return pit + 0.5 * exp(-pow((d - WELL_R - 1.5) / 2.0, 2.0)) * open


## The standing water level at xz, or NAN where the fen's own pools (LAKE_Y) rule: the river's reach (over its
## whole floodplain), the lake, the Well's pit. RealmLand floods the cells of the ground that dips below it.
static func water_level_at(x: float, z: float) -> float:
	if x < -168.0:
		var nr := river_near(x, z)
		if nr.x < river_w(nr.z) + 16.0:
			return river_level(nr.y)
	elif x > 170.0 and x < 262.0:
		if lake_e(Vector2(x, z)) < 1.4:
			return LAKE_Y
	elif x > 50.0 and x < 95.0 and z > 180.0:
		if Vector2(x, z).distance_to(WELL_C) < WELL_R + 5.0:
			return WELL_POOL_Y
	if x > -70.0 and x < 52.0 and z > 136.0 and z < 196.0:
		if OssFrame.pit_d(Vector2(x, z)) < 4.0:
			return OssFrame.ORIGIN.y + OssFrame.POOL_Y
	return NAN


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
		var q := p
		if String(r.id) in MARCHES_IDS:
			q += _mwarp(p)                     # the Marches' names meet along wandering lines
		var w := _rect_w(q, r.rect, 18.0)
		if r.has("blobs"):
			for b: Dictionary in r.blobs:
				w = maxf(w, _circle_w(p, b.c, float(b.r)))
		return w
	return _circle_w(p, r.c, float(r.r))


## A circle's plateau weight: 1.0 within 0.8 r of the centre, falling to 0 at 1.4 r.
static func _circle_w(p: Vector2, c: Vector2, rr: float) -> float:
	var t := clampf(1.0 - (p.distance_to(c) - rr * 0.8) / (rr * 0.6), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _area(r: Dictionary) -> float:
	if r.has("rect"):
		return (r.rect as Rect2).get_area()
	return PI * float(r.r) * float(r.r)


static func region_weight(r: Dictionary, x: float, z: float) -> float:
	var p := Vector2(x, z)
	var w: float
	if r.has("rect"):
		w = _rect_w(p + _warp(p) + (_mwarp(p) if String(r.id) in MARCHES_IDS else Vector2.ZERO), r.rect, 18.0)      # ragged land edges
		if r.has("blobs"):
			for b: Dictionary in r.blobs:
				w = maxf(w, _bump(p, b.c, float(b.r) * 1.4))
	else:
		w = _bump(p, r.c, float(r.r) * 1.4)
	if w > 0.0 and String(r.id) in MARCHES_IDS:
		w *= marches_mask(p)                         # the Marches' land never bleeds into the old Realm's biomes
	return w


## The regions added beyond OLD_BOUNDS (the Outer Marches and the Southern Downs).
const MARCHES_IDS := ["weirford", "sorrow", "hierarch", "siege", "stillwater", "anchorholds", "saltmarket", "saltpans", "downs", "oak", "well"]


## 0 inside OLD_BOUNDS, easing to 1 over 12 m outside it.
static func marches_mask(p: Vector2) -> float:
	return smoothstep(0.0, 12.0, _out_dist(p, OLD_BOUNDS))


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
## (Minus the path's half width: distance to the path's edge.) Called tens of thousands of times by
## the build, so the segments of PATHS (immutable once made) are kept as packed arrays with a grid
## of the segments near each cell; the result is exactly the full scan's.
static func path_dist(p: Vector2) -> float:
	if _seg_a.is_empty():
		_build_segs()
	var cx := int(floorf((p.x - BOUNDS.position.x) / _SEG_CELL))
	var cz := int(floorf((p.y - BOUNDS.position.y) / _SEG_CELL))
	if cx >= 0 and cz >= 0 and cx < _seg_gw and cz < _seg_gh:
		var best := INF
		for j in _seg_cells[cz * _seg_gw + cx] as PackedInt32Array:
			best = minf(best, _seg_d(p, j))
		# a segment not listed in this cell is further than _SEG_REACH from all of it
		if best <= _SEG_REACH - _seg_wmax:
			return best
	var best := INF
	for j in _seg_a.size():
		best = minf(best, _seg_d(p, j))
	return best


static func _seg_d(p: Vector2, j: int) -> float:
	var a := _seg_a[j]
	var ab := _seg_ab[j]
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t) - _seg_w[j]


const _SEG_CELL := 8.0
const _SEG_REACH := 16.0
static var _seg_a := PackedVector2Array()
static var _seg_ab := PackedVector2Array()
static var _seg_w := PackedFloat64Array()
static var _seg_wmax := 0.0
static var _seg_cells: Array = []        # PackedInt32Array per cell
static var _seg_gw := 0
static var _seg_gh := 0


static func _build_segs() -> void:
	var boxes: Array[Rect2] = []
	for path: Dictionary in PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			_seg_a.append(a)
			_seg_ab.append(b - a)
			_seg_w.append(float(path.w))
			_seg_wmax = maxf(_seg_wmax, float(path.w))
			boxes.append(Rect2(a, Vector2.ZERO).expand(b))
	_seg_gw = int(ceilf(BOUNDS.size.x / _SEG_CELL))
	_seg_gh = int(ceilf(BOUNDS.size.y / _SEG_CELL))
	_seg_cells.resize(_seg_gw * _seg_gh)
	for cz in _seg_gh:
		for cx in _seg_gw:
			var cell := Rect2(BOUNDS.position + Vector2(cx, cz) * _SEG_CELL, Vector2(_SEG_CELL, _SEG_CELL)).grow(_SEG_REACH + 0.01)
			var ids := PackedInt32Array()
			for j in boxes.size():
				if boxes[j].intersects(cell, true):
					ids.append(j)
			_seg_cells[cz * _seg_gw + cx] = ids


## The path segments that can come within `margin` of rect r (by their bounds): [a, b, w] each. A
## caller testing many points of r against path_dist(q) < margin needs only these (the others are
## further than margin from every point of r).
static func path_segs_near(r: Rect2, margin: float) -> Array:
	var out: Array = []
	for path: Dictionary in PATHS:
		var pts: Array = path.pts
		var w := float(path.w)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if Rect2(a, Vector2.ZERO).expand(b).grow(w + margin + 0.01).intersects(r, true):
				out.append([a, b, w])
	return out


## r35: a smooth, deterministic offset (up to ~7 m) so rectangular regions' land and shapes meet
## along wandering lines instead of ruled ones. Only for painting and landform, never for names.
static func _warp(p: Vector2) -> Vector2:
	return Vector2(sin(p.y * 0.09 + 1.3) + 0.6 * sin(p.y * 0.21 + p.x * 0.05),
		sin(p.x * 0.08 + 0.4) + 0.6 * sin(p.x * 0.19 - p.y * 0.06)) * 4.4


## The Marches' own wander (long waves, up to ~12 m): their regions' edges are not ruled lines.
static func _mwarp(p: Vector2) -> Vector2:
	return Vector2(sin(p.y * 0.047 + 2.1) + 0.7 * sin(p.y * 0.113 + p.x * 0.031),
		sin(p.x * 0.052 - 0.9) + 0.7 * sin(p.x * 0.131 + p.y * 0.041)) * 6.5


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
