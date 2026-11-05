# r34 layout: the doubled Realm (for the phase-2 agents)

Written by the layout agent (r34 phase 1). The numbers below are the code's: `core/world/realm/realm_layout.gd`
is the contract (BOUNDS, REGIONS, PATHS, RAIDS, SLOTS, OSSUARY_HALL); this file explains it. If you must
deviate, say so in your report. Checked by `zz/layout_r34_test` (bounds, regions reachable by a way, raid
floors flat and clear, slots usable, nothing in the void, the minimap). Maps: `zz/layout_r34_map.tscn`
(top-down PNG + a density census), `zz/layout_r34_shots.tscn` (windowed views from a free camera).

## Bounds

| | r33 | r34 |
|---|---|---|
| `BOUNDS` (playable xz) | `Rect2(-110, -150, 220, 230)` = 50,600 m² | `Rect2(-155, -150, 310, 325)` = **100,750 m²** (x -155..155, z -150..175) |
| `OUTER` (horizon ring) | `Rect2(-200, -240, 400, 410)` | `Rect2(-244, -240, 488, 504)` (60-90 m past every edge) |
| terrain grid (2 m) | 121 x 127 from (-120, -160) | 165 x 173 from (-164, -160) (`RealmLand.GX0/GZ0/GNX/GNZ`) |

The north edge did not move (the Crowns and the summit). The world grew 45 m west, 45 m east and 95 m
south. Every fixed point stayed: the spawn brazier, `PLAYER_START`, the tavern, the Ossuary AABB, the
summit platform, the ward, the Crossing. The invisible walls (`Zone/RealmBounds`), the edge cliffs
(`RealmWayfinding.edges`), the minimap and the Journal map all read `BOUNDS`. New shapes in the land:
low rims inside the west and east edges, the southern downs (z 148..175 rise ~7 m), and the horizon ring.

Anything else that hard-coded the old extent was moved to `BOUNDS`/`OUTER` (weather's lightning clamp,
`zz/realm_sweep`, the secrets' Thornwood rect, the road's gates). Still on old numbers (not mine, harmless,
phase 2 may widen): `life_director._place_elk` scans x -104..104; `weather.MIST_REGIONS` has no mist over
the new regions; `gather.gd` lays the same number of ash blooms / grave iron over twice the ground.

## Regions

Region ids are what `RealmLayout.region_at`, the discovery banner, the Journal (`LoreDB.PLACE_INFO`),
the encounter tiers (`tiers.gd REGION_BASE`, defaults to 1 for an unknown id) and the ambience
(`ambience.gd REGION_SCAPE`) key on. Each REGIONS entry now carries a suggested `tier` and (new ones) a
`purpose`. Biomes are the existing set (the ground shader has seven layers; no new biome).

| id | name | centre | size | biome | tier | purpose |
|---|---|---|---|---|---|---|
| hearth | Hearthward | (6, 38) | r 34 | meadow | 0 | village, spawn (kept) |
| road | The Pilgrims' Road | (0, 65) | 310 x 30 (x -155..155, z 50..80) | heath | 0 | the spine; gates now at x +-145 |
| chapel | Chapel of the First Kindling | (-72, 52) | r 22 | ruin | 1 | kept |
| thornwood | The Thornwood | (-90, -10.5) | 120 x 111 (x -150..-30, z -66..45) | oldforest | 1 | grew west to the edge |
| henge | Thorn Henge | **(-86, -24)** (was (-72, -18)) | r 32 | oldforest | 1 | Thornwarden raid (below) |
| fen | The Hollow Fen | (75, -22.5) | 70 x 115 | fen | 1 | kept |
| barrows | The Barrow Field | (78, -42) | r 20 | fen | 2 | kept |
| rift | The Ashen Rift | (0, -65) | 60 x 106 | ash | 2 | kept |
| ossuary | The Ossuary | (17, -66) | 30 x 88 | ash | 2 | kept; pit hall reserve below |
| summit | The Summit of Ascension | **(0, -104)** r **42** (was (0, -95) r 30) | | crag | 3 | Ascended Warden raid (below); the circle now owns the raid floor and still the ward |
| crags | The Crowns | (0, -130) | 310 x 40 | crag | 2 | the north wall |
| glade | The Glimmer Glade | (-38, 8) | r 18 | glade | 0 | kept |
| **quarry** | **The Saints' Quarry** | (-130, -99), pit floor at (-127, -104) | 50 x 62 (x -155..-105, z -130..-68) | crag | 2 | a pit cut in benches (3.3 m treads, 3.2 m risers) into a spur of the Crowns: vertical exploration, a camp on the benches, stone and ore. "Where the Order cut four thousand steps for the Stair." |
| **holds** | **The Rooted Holds** | (-134, 12) | r 18 | heath | 1 | a heather clearing (a hollow at y ~2.5) deep in the west wood: the Rooted's turf-roofed earth-houses (the Keg-folk's kin), a hall-mound, a fire |
| **foundry** | **The Founder's Pits** | (131.5, -89) | 47 x 46 (x 108..155, z -112..-66) | ash | 2 | a bench at the Crowns' foot (y ~3) with three slag heaps (121,-84), (145,-99), (141,-75): the bell furnace, casting pits, a hard camp, a relic |
| **moor** | **The Lanternless Moor** | (139.5, -13) | 31 x 106 (x 124..155, z -66..40) | heath | 1 | high swelling heath (+4.5 m) with a tor at (141, -24) (+7 m): long sight lines, wind, cairns, roaming rares |
| **orchard** | **The Cinder Orchard** | (-109, 121) | 82 x 62 (x -150..-68, z 90..152) | ash | 1 | a gentle shelf of burned fruit-tree rows on ash: foraging, a press-house ruin, a night event ground |
| **necropolis** | **The Waiting Field** | (-1, 127) | 86 x 58 (x -44..42, z 98..156) | ruin | 1 | the pilgrims' necropolis on a slope rising 5 m south, every grave facing the mountain; a mausoleum/crypt door at the top |
| **mere** | **Corvin's Mere** | (107, 121) | 86 x 62 (x 64..150, z 90..152) | fen | 1 | a drowned water-meadow: several meres between hummocks (west half wet, east banks dry), causeways, floating lamps, a half-sunk chapel |

Lore lines and Journal text for the new ids are in `LoreDB.PLACE_INFO` (they fit LORE.md: the Order's
quarry, the Rooted, the Founder's bells, Edict I, the Kindlers made heretics, the pilgrims, Brother
Corvin). The Ninth Company's three places (scenes.gd) still stand in the Thornwood; the Rooted Holds are
not theirs.

## Ways (RealmLayout.PATHS)

Kept: `east_way`, `fen_descent`, `chapel_lane`, `rift_rim`. Changed: `west_way` now ends at the moved
henge stair's foot (-50, -10) (bends at (-46, -2)); `road` runs on to (-150, 67) and (150, 68).

| id | half width | from | to | through |
|---|---|---|---|---|
| west_track | 1.4 | the road (-118, 65) | the quarry's mouth (-126, -84) | the Rooted Holds (-132, 22), the west wood (x -138) |
| moor_track | 1.4 | the road (124, 67) | the Founder's Pits (130, -86) | the moor (x 130-134) past the tor |
| necropolis_way | 1.8 | the road at (-6, 54) | the Waiting Field's top (0, 128) | south across the plain |
| orchard_lane | 1.4 | the road (-98, 63) | the orchard (-112, 122) | |
| mere_causeway | 1.6 | the road (92, 65) | the mere (104, 120) | raised over the water (causeway rule) |
| south_track | 1.4 | the orchard (-112, 122) | the mere (104, 120) | the Waiting Field (0, 128): the southern loop |

All ways are one network (checked), lie on the ground inside the bounds and never climb more than
0.75 m per metre. Lanterns line only the three r30 spokes (`RealmWayfinding.LANTERN_PATHS`); phase 2
may add the new ways. There is deliberately **no way across the Hollow Fen to the moor**: every line
tried there pushed the fen's dressed places off their ground (the Drowned Belfry's search, the drowned
graves at (70, -4), the barrow stones). The moor and the Founder's Pits are reached up moor_track from
the road's east end. A fen-to-moor footbridge is a phase-2 option if the fen's builders move with it.

## Raid floors (RealmLayout.RAIDS)

WoW raid rooms are 55-65 m across. The land is shaped for them; the boss agents build the rooms. Each
is registered by `RealmBosses._reserve_raids` as site `raid_<id>` before the stamp, lore and flora, so
nothing (trees, lore, camps, gather nodes, rocks) is planted on it. Round sites are judged by their
circle (`WorldLanes.site_hits_rect`) in `intrudes`, the audit, lore's `clear_of` and the flora for
`raid_*` (older round sites keep their box, so the rest of the world grew exactly as before).

| id | centre | r | floor y | mode | entrance | notes |
|---|---|---|---|---|---|---|
| henge | (-86, -24) | 31 (62 m) | 9.0 | level: the hill's crown is cut and filled flat to 9.0 inside r 33, the skirt falls 12 m to the wood (r 45) | the pilgrim stair from `HENGE_STAIR_FOOT` (-50, -10) (y ~5), head on the floor's rim, ~(-57, -17) | `ThornHenge.STAIR_R` = 31: the stair now arrives at the raid floor's rim; the terrace (R 13), ring, hedge (12.2), seal and the current arena (r 12.4) are unchanged at the centre. Grow the arena outward to r ~30; the hedge mouth faces the stair. HengeFire stands on the stair's landing (outside). |
| summit | (0, -118) | 28 (56 m) | 27.35 (the dais deck) | clear: no ground above 26.55 inside r 30; the Crowns are cut back into a cirque behind it (rising from r 30 to r 40, past the north edge) | the cathedral deck / dais front at (0, -90); the Ossuary lift jetty at (6.4..11.7, -89) is just outside the rim | under the floor is the chasm (lava -15.5) and the old summit crag (~22): build a deck on piers, as the r 14 dais (centre (0,-103.9)) is now. The dais lies inside the circle. The site's `owners` (SummitAltar, Area_ossuary) mark the monument and the lift as already belonging. |

**Bone Abbot's pit hall** (`RealmLayout.OSSUARY_HALL`): `AABB((26, -38, -124), (56, 32, 56))` = x 26..82,
y -38..-6, z -124..-68, entirely underground east of the crypt (under the rift's east shelf, the Crowns'
foot and the north fen; the ground over it is never below -2, checked). A 50 m hall fits with a floor at
~-32 and a ceiling at ~-10, centred (54, -96). Join it to the crypt from its lower levels (the crypt's
AABB ends at y -6; the Lower Count is there) by a stair or lift down through x 26..32. Keep `OSSUARY`
as it is for "inside the Ossuary" checks and use `RealmLayout.in_ossuary(p)` (OSSUARY or the hall); do
not grow OSSUARY over the fen (its top is y 26: the fen's surface would count as inside). The streamer
(`AreaStreamer`) bounds and `world/areas/ossuary/ossuary.gd BOUNDS` need the hall added as a second box.

## Slots for phase 2 (RealmLayout.SLOTS)

Checked usable by the layout test (inside the region, dry and walkable, 2 m off ways, off sites; `poi_wet`
may stand in water). Move a slot a few metres if a building needs it.

| region | kind | at (xz) | note |
|---|---|---|---|
| quarry | fire | (-120, -83) | the pit's mouth, beside west_track's end |
| quarry | poi | (-128, -104) | the pit floor: unfinished steps, a crane, squared blocks |
| quarry | poi | (-144, -118) | a high bench under the west wall: the cutters' shelter |
| quarry | camp | (-110, -100) | the east benches |
| quarry | camp | (-139, -89) | the west benches |
| holds | fire | (-125, 15) | beside west_track at the clearing's edge |
| holds | poi | (-139, 11) | the hall-mound |
| holds | poi | (-133, 1) | a row of earth-houses |
| holds | camp | (-137, 22) | the north holds |
| foundry | fire | (123, -76) | at moor_track's end, under the first slag heap |
| foundry | poi | (135, -105) | the bell furnace, cut into the rim |
| foundry | poi | (132, -90) | the casting pits |
| foundry | camp | (147, -85) | between the heaps |
| foundry | camp | (115, -102) | the west bench |
| moor | fire | (126, -8) | beside moor_track, under the tor |
| moor | poi | (142, -24) | the tor: a cairn and a lookout over the fen |
| moor | poi | (145, 14) | a lanternless shrine |
| moor | camp | (145, -50) | the north moor |
| moor | camp | (148, 33) | the south moor |
| orchard | fire | (-99, 104) | beside orchard_lane |
| orchard | poi | (-128, 132) | the press-house ruin |
| orchard | poi | (-86, 122) | the burned rows' heart (a night event ground) |
| orchard | camp | (-136, 104) | the west rows |
| orchard | camp | (-80, 142) | the south rows |
| necropolis | fire | (8, 108) | at the field's gate, off necropolis_way |
| necropolis | poi | (0, 147) | the mausoleum at the top of the field: a crypt door |
| necropolis | poi | (-26, 118) | the pilgrims' ranks |
| necropolis | camp | (-30, 146) | the west tombs |
| necropolis | camp | (28, 114) | the east tombs |
| mere | fire | (103, 98) | the mere's north bank, near mere_causeway |
| mere | poi_wet | (84, 112) | the half-sunk chapel in the west mere |
| mere | poi | (132, 124) | Corvin's landing: a boat-house on the east bank |
| mere | camp | (137, 102) | the east bank |
| mere | camp | (118, 144) | the south bank |
| road | camp | (-128, 74) | the West Gate's approach |
| road | camp | (131, 58) | the East Gate's approach |

## Density targets ("the same density")

Measured on the r33 world (`zz/layout_r34_map.tscn` census, region by `region_at`), and on the r34 build
after this phase (the new regions are bare apart from flora and the land):

Per region (area by `region_at` inside BOUNDS; flora = every undergrowth/tree instance; sites =
WorldLanes sites; scraps = lore inscriptions; markers = map markers other than fires):

| region | biome | r33 area m² | r33 flora /m² | r33 trees /1000 m² | r33 sites | r33 scraps | r33 camps |
|---|---|---:|---:|---:|---:|---:|---:|
| hearth | meadow | 3,392 | 1.24 | 0.9 | 17 | 16 | 0 |
| road | heath | 6,128 | 1.67 | 7.0 | 38 | 17 | 3 |
| chapel | ruin | 1,016 | 0.42 | 2.0 | 6 | 15 | 0 |
| thornwood | oldforest | 9,420 | 0.86 | 12.2 | 36 | 19 | 5 |
| glade | glade | 820 | 0.74 | 1.2 | 4 | 9 | 3 |
| fen | fen | 9,284 | 0.61 | 4.5 | 19 | 17 | 7 |
| barrows | fen | 820 | 0.62 | 4.9 | 5 | 5 | 0 |
| crags | crag | 10,720 | 0.66 | 8.3 | 2 | 4 | 0 |
| rift / ossuary / summit | ash / crag | 8,212 | ~0.1 | ~1 | 20 | 1 | 3 |
| **whole r33 world** | | 50,600 | 0.77 | 6.2 | 149 | 104 | 21 |

The r33 world, in the units phase 2 should match:

- **Flora**: comes from the biome tables (`realm_flora.gd UNDER`, `TREE_P`), so it already matches by
  biome: after r34 the whole world holds 99,715 instances (r33: 39,186) and 595 trees (r33: 312). The new
  heath and ruin ground is grassier than the r33 average (moor 2.3/m², Waiting Field 1.8/m², road 1.6/m²;
  orchard on ash 0.4/m²) -- intended (open ground), but it is the main per-frame cost to watch.
- **Places worth a detour** (lore landmark sites + r31 POIs): r33 ~149 sites and 104 inscriptions over
  50,600 m², i.e. **~3 sites and ~2 inscriptions per 1,000 m²**; the dressed regions run 5-15 sites per
  region. Target for each new region: **2-3 POIs** (one big place like the Drowned Belfry, one or two small
  scenes), **6-12 inscriptions/scraps**, plus small sites to ~3 per 1,000 m². The new regions now hold
  0-2 sites each (bare).
- **Fires**: 8 over 50,600 m² (one per ~6,300 m², one per region with a boss or a crossroad). Target: **one
  fire per new region** (the SLOTS "fire" entries): 7 more.
- **Camps**: 21 `REALM_CAMPS` over 50,600 m² = **4.2 per 10,000 m²**, and 4.5 per 100 m of way (r33 ways
  464 m). The new ground is ~50,000 m² with 800 m of new way: target **~20 new camps** (2-3 per new region
  plus 2 on the road's new ends; SLOTS lists 25 spots), keeping 3 m+ off a way and 30 m from grazers.
- **Map markers**: 36 (0.7 per 1,000 m²): one per POI, fire and quest place.
- **Gather nodes** (`core/items/gather.gd` BLOOMS/IRON counts): unchanged counts now spread over twice the
  ground: double them to keep the density.

After phase 1 (this build), census by region (new regions bare apart from land and flora):

| region | area m² | flora /m² | trees /1000 m² | sites | camps |
|---|---:|---:|---:|---:|---:|
| quarry | 3,716 | 0.86 | 13.5 | 2 | 0 |
| holds | 680 (+ the wood round it) | 0.77 | 8.8 | 1 | 0 |
| foundry | 2,436 | 0.52 | 5.3 | 1 | 0 |
| moor | 4,208 | 2.31 | 8.1 | 0 | 0 |
| orchard | 8,340 | 0.40 | 2.4 | 0 | 0 |
| necropolis | 9,088 | 1.76 | 5.6 | 0 | 0 |
| mere | 8,520 | 1.04 | 8.9 | 0 | 0 |
| road (now 310 m long) | 11,348 | 1.63 | 4.4 | 39 | 3 |
| thornwood (now to the west edge) | 11,736 | 0.78 | 9.1 | 30 | 5 |
| henge (raid floor) | 2,128 | 0 | 0 | 2 | 0 |

## Performance

Measured on the owner Mac (M4 Pro), same session, r33 = an exact copy of HEAD 5db9d52 in scratch.

**Realm build** (headless, `REALM built in`, one run each, same machine load):

| | r33 | r34 |
|---|---:|---:|
| total | 4,622-4,867 ms | 6,146-6,908 ms (+~1.9 s, +40 %) |
| land (heights + meshes) | 544 ms (301 + 243) | ~920 ms (545 + 378) |
| flora | 1,046 ms (ground 110, under 719) | ~2,000 ms (ground 226, under 1,352) |
| lore / rift / bosses / assets | 619 / 578 / 169 / 148 | 616 / 738 / 190 / 222 |
| windowed load to realm_done (perf_tour) | 8,360 ms | 11,041 ms |

Land got cheaper per m² (the path lookup now skips far 16-sample runs; the terrain splat and the
horizon ring are built in parallel rows); heights alone would have been ~1.8 s with the old per-sample
scan. Flora scales with area (one ray per m², the undergrowth pass is single-threaded and seeded in
sequence); halving it means threading `_place_under` by rows with per-row seeds (it reshuffles every
plant: a phase-2 decision).

**Frame cost** (`zz/perf_tour.tscn -- --points-only`, windowed 1600x1000, vsync off, Balanced; the 17
r19/r22 views): frame cost and draws did not grow. r33 -> r34 mean over the 17 views: fps 132.3 ->
134.9, scripts 0.75 -> 0.74 ms, render-cpu 1.15 -> 1.11 ms, rest(gpu) 5.67 -> 5.57 ms, draws 942 -> 836
(the henge view 890 -> 642: the raid floor is open ground). Views are bounded by the 82 m far plane and
the per-chunk visibility ranges, so twice the area costs nothing per frame where the density is the same.
The eight new r34 views: 451-660 draws, 136-150 fps, worst frame 10.7-22.4 ms (no frame over 33 ms).
Culling/streaming distances were not changed (no need); flora chunks went 1,643 -> 3,149 multimeshes.

## Fixed baseline failures

- **village_test** (oswin / pell unreachable, 76 off the floor): the r33 ember-post beside Hearthward's
  fire stood on the villagers' `brazier_w` node and cut the `green_w`-`brazier_w` edge. `EmberPost.SEAT_OFFSETS`
  seats the Sanctuary's post at (-2.3, 0, 2.6) (the north-west diagonal, clear of all four walking nodes
  and the respawn spot); other fires keep `OFFSET`.
- **rebuild_test** ("nodes 126 then 116"): not a missing rebuild. The difference was transient Vfx bursts
  (`core/vfx/vfx.gd`, pooled one-shot emitters parented to the scene): the Thornwood's breath vent
  (`core/life/secrets/breath_vent.gd`) puffs one every ~130 ms in its active phase, and the two censuses
  run at different times after their builds. The census now skips `burst_token` emitters. The remaining
  multimesh drift (2390 then 2398, inside the tolerance) is the Ossuary area (`Area_ossuary`, +7, and
  `LowerCount` +1 on the second night): world/areas/ossuary, reported to its owner.
