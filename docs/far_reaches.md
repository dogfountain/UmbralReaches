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
