# The Far Reaches: the Realm doubled again

Luke, 15 Nov 2026: make the world 2x its size and fill the new ground with existing systems (regions, landmarks,
towns, flora, wildlife, encounters, lore); re-landscape the lava rift so it belongs; give the Ossuary its own area;
more density, more life, better enemy placement and progression; vistas, landmarks seen from afar, set pieces.
The numbers are in `core/world/realm/realm_reaches.gd` (RealmReaches): that file is the contract for the new ground,
the way `realm_layout.gd` is for the rest. RealmLayout appends its REGIONS, PATHS, SLOTS, MEANDER and IDS and calls
`RealmReaches.shape()` for the landform.

## The shape

The Marches' Realm (x -260..260, z -150..240, `RealmReaches.MARCH_BOUNDS`, 520 x 390 m) grows to x -370..370,
z -150..398 (740 x 548 m, 2.0x the area): the **West Reach** beyond the Sorrow, the **East Reach** beyond the White
Pans and the Anchorholds, and the **Deep South** below the downs, whose rise now falls away in a scarp between z 250
and 290 so the south is low country again. The Crowns stay the north wall the whole width, with new peaks at the
corners. The Sorrow runs on from the old south edge through the Reedmere to the new one. The road runs on west and
east to the new edges.

| Region | Where | Tier | Landmark | Content |
| --- | --- | --- | --- | --- |
| The Greyfell | NW, x -370..-260, z -150..-50 | 3 | the Broken Keep on its crag (the Order's western keep, garrison never stood down); the fell shrine | 2 camps (garrison), a rare, fire |
| The Lanternwood | W, z -50..68 | 2 | a deep wood lit by cold fungus: the ring of giant caps; the road's Last Milestone | 2 camps, wisps, fire |
| The Kings' Barrows | W, z 68..236 | 3 | a heather ridge of great barrows; the King's Barrow is open; a stone row | 2 camps, a rare, fire |
| The Reedmere | SW, x -370..-220, z 236..398 | 2 | the Sorrow spread into meres: Reedholm's stilt-houses (people); the heron stones | 2 camps, villagers, fire |
| Fallowmere | S, x -220..-92 | 1 | a farming hamlet (people): tithe barn, farmhouse, fold, drowned strips | 1 camp, villagers, fire |
| The Long Arches | S, x -92..92 | 2 | the Order's aqueduct striding across a dry valley; the castellum; the broken span | 2 camps, fire |
| The Southwood | S, x 92..262 | 3 | a dark wood: the charcoal burners' ruin, the witch's hollow | 3 camps, a rare, fire |
| The Bellfall | NE, x 260..370, z -150..-40 | 3 | the eighth bell fallen into a scorched crater | 2 camps, a rare, fire |
| Lastlight | E, z -40..96 | 1 | the walled waystation at the road's east end: inn, lamp tower, watch; the shut East Gate | villagers, watch, fire |
| The Drowned Nave | E, z 96..234 | 3 | an unfinished cathedral flooded to the knee, moon shafts through the vault | 2 camps, fire |
| The Thousand Cairns | SE, z 234..398 | 3 | a high windy heath of cairns; the Cairn Tower | 2 camps, a rare, fire |

Ways (all `RealmReaches.PATHS`, meandering): fell_track (road to the keep), barrow_track (road down the ridge to
Reedholm), reed_ford (Reedholm across the Sorrow to Fallowmere: a bridge at the river), fallow_way (the downs to
Fallowmere), arches_way (Fallowmere east under the aqueduct to the Southwood), arches_link (the downs to the arches),
salt_south (the Brine Road on to the Southwood), southwood_way (on to the Cairns), bell_track (Lastlight to the
crater), nave_track and cairn_track (the road south past the Nave to the Cairns), bell_link (the Anchorholds' foot to
the crater). A Far Reaches way that starts or ends on an older way takes its height there (RealmReaches.pin_junctions).

Landform anchors: `KEEP_C` (the keep's crag), `CRATER_C` / `CRATER_R` (the Bellfall), `NAVE_C` / `NAVE_R` (the
flooded basin: the fen's own pools fill it, wading depth), `TOWN_E` (Lastlight's flat), `TOWN_F` (Fallowmere's
flat), `ARCH_Z` (the aqueduct's line across the valley, deepest at x 0), `SCARP_Z` (the downs' south scarp).

## Systems the contract already wires

Bounds, terrain grid and horizon ring (`realm_land.gd`), the nav bake (now seven tiles: the West and East Reaches
beyond x +-262 and three bands of the middle; nothing should be built across x +-262 or z 86 / 246), the world map
sheet, region tiers and rosters (`tiers.gd`), journal entries (`lore_db.gd` PLACE_INFO), the eleven fires
(`realm_bosses.gd` R34_FIRES), ground cover per region (`flora_looks_marches.gd`), slots (checked by
`zz/layout_r34_test`). Wildlife, weather, ambience, discovery and the minimap read BOUNDS and regions and follow.

## Rules for every builder

The r37 rules hold (docs/r37_expansion.md "Rules for every agent"): existing systems only, assets made in-house
(hero landmarks modelled in Blender by script with a turnaround render reviewed before integration), far meshes and
LODs for big things (FarDetail), the pillars, the don'ts. New content goes in new files named for the area; shared
registries (EnemySpawner.REALM_CAMPS, elites, rares, lore, codex, quest chains, village casts) get one block per area
at the end of the list.

## The Ashen Rift, re-landscaped (the lava area)

Luke: the lava "feels out of place" (a straight slot of fire cut into green meadow and oak wood). The chasm, the
Crossing, the summit and the Threshold stay where they are; the country round them now tells how it burned. One field,
`core/world/realm/rift/scorch.gd` (x -104..104, z -156..8), drives it all:

- **The burn**: deepest at the lip, reaching out in tongues downwind (east-south-east, the foliage wind) and up the
  wood's slope; a ring of dying wood and dry turf round it; dying back to nothing by the starwater mouth (Hearthward
  stays green), Thorn Henge's hill kept green. The ground turns to ash country (RealmLand `_splat`), the ring's grass
  dries and the burn's goes to ash drifts, cinders and dead brush, trees in the burn stand as charred snags, the ring's
  crowns go rust (RealmFlora, four one-line hooks), `biome_at` answers "ash" there (footsteps, weather, wildlife).
- **The flows**: the rift's lips are berms 11-15 m high; the night the rift brimmed the lava broke through them at
  notches and ran down their outer faces: the main flow and a second tongue west onto the flat at the Crowns' foot
  (either side of the Watchers' Spire), two cascades east into the Hollow Fen's edge (steam where they stopped in the
  water). They lift the ground up to 1.35 m (RealmLand `_heights`, after the kept core) and are drawn by the ground
  shader's scorch map: roped black crust, tumuli, a crack network still warm near the lip and in the Choir House.
- **The Choir House** (`tools/blender/rift_choir_house.py`, `art/models/rift_choir_house.glb`): the hall where the
  Stair's choir lodged, in the main west flow; the lava came in at its door, filled the nave to the sills and burst its
  far gable. The Cinder Cantor haunts its nave; its writings are the `rr_*` entries in lore_db.gd.
- **The rift's breath** (`rift/plume.gd`): a lava-lit smoke column rising out of the chasm's north-east corner and
  leaning away downwind, the north of the Realm's far landmark.
- **Dressing** (`core/world/realm/rift_rim.gd`, REACH_POIS): spatter along both lips, bombs, heaved slabs and toe
  rubble on the flows, basalt tors, charred trunks, steam and smoke.
- The lava itself reads as crust rafts drawn out along the current (darker plates, thinner seams, a deeper red).

`--no-scorch` puts the rift back as it was (A/B; the lava's crust look stays).

## The Ossuary's own ground

Luke, 15 Nov: "make sure the ossuary is in its own area". It had a region, but a 38 m strip between the Waiting Field
and the Southern Downs, overlapped by both, the Grandmother Oak and the Well on its corners, downs_track on its south
lip, a 14 m lane for an approach and nothing of its own above ground (the Bone Abbot's map mark fell in the downs).
The downs' middle is the Flock's Road (the sheep-walk cairns, the Bell-Wether's round, the fold), so the Ossuary takes
the open ground on its north-west instead: the gap between the Cinder Orchard and the Waiting Field, which no region
held. The pit, its tiers, the Counting Stair, the Abbot's hall, the gallery seal, the quests and bells are unchanged.

- **Region** (`RealmLayout.REGIONS` "ossuary"): the pit and both its lips (a rect a little smaller than the Waiting
  Field's, so it wins the shared brow; the mausoleum and the field's camps stay the field's) plus four blobs along the
  Lych Way. Its own ground cover (`flora_tables.gd` LOOKS: pale moss and bramble turf, black yews, bone dust), its own
  scape (`ambience.gd` "charnel": the pit's breath, a far bell, whispers, bones; it replaces the rift's lava blurps it
  was left with), tier 2.
- **The Lych Way** (path `lych_way`): from the Pilgrims' Road between its milestone and its lamp, past the Lych Cross
  (the Order's Open Door on a stepped shaft), three coffin stones each cut with a verse of the Bearers' Count, the
  Kindled Watch's post on the Orchard Way (the third stone stands by it), then a hollow way walled with niches of skulls,
  long bones and grave candles (z 101-123), out to the lych gate (its bell tolls when anyone passes under) and south_track.
- **The Bearers' Yard**: the **Lantern of the Dead** (28 m, placed at 1.2 of its model so it clears the field's yews: stepped octagonal base with crossed bones and skulls on its
  faces, the keeper's door, two belts of skulls in the shaft, an open lantern of six bays under a crocketed slate spire
  and the Open Door in iron), the bearers' table at its foot, heaps of the uncounted. The lantern burns the cold
  count-light (flame, a small cold light, a halo through the bays, a landmark beacon on the compass and the horizon)
  until the Bone Abbot falls; then it goes out. Far mesh from 110 m (FarDetail).
- **The Sorting Ground** on the pit's west rim: slabs, skulls and long bones heaped by kind, the sorters' slate and the
  Rule of the Bearers.
- **Encounters** (one block each in REALM_CAMPS and rares.gd): the bearers (two ossuants and a tollman) walk the hollow
  way's south half, the choir (two chanters, an ossuant, a pilgrim) keeps the lantern, the sorters (husk, bulwark,
  quiller) the west rim; the Last Bearer (a rare ossuant) walks the way's head. All keep 14 m+ off the orchard watch's
  post (its watchmen leave the post for foes that close) and out of `RealmLayout.in_ossuary` (Director.fair_ground
  keeps tides and roaming events out of the pit; the yard and the way are open ground).
- **Writings**: 11 (`lore/ossuary_ground_texts.gd`, one block in lore_db.gd; the series "The Bearers' Count"); the
  region's journal text is new.

Assets: `tools/blender/oss_ground.py` -> `art/models/oss_ground.glb` (Lantern, LanternFar, LanternTable, LanternLamp,
LanternFlame, LychGate, LychBell, CoffinStone(B), NicheWall(Low), NichePier, LychCross) and `oss_ground_data.gd`;
skulls, bones and candles are the Ossuary's own (OssKit), weathered for outdoors. Built by
`core/world/realm/ossuary_ground.gd` (REACH_POIS). `-- --no-oss-ground` leaves it out (A/B).
