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
| The Bellfall | E, under Lastlight's south wall (the Crowns' east corner is the endgame's) | 3 | the eighth bell fallen into a scorched crater | 2 camps, a rare, fire |
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

## The endgame, moved (the Ashen Rift, the Crossing, the Threshold, the summit)

Luke, 16 Nov: first "it makes no sense [the lava] to be next to the starting village at all", then "Why is there still a
purple lava area, that's literally the final boss, why would it be next to the village". The whole end of the night left
Hearthward's country for the Realm's far north-east, beyond Lastlight, where the pilgrims' road turned to the mountain:
the chasm with its lava and its starwater Threshold, the Crossing, the Summit of Ascension and the Ascended Warden's
deck, the rim's secrets and writings, the burn, the flows, the Choir House and the smoke column. Hearthward now sits in
ordinary country: open meadow and hill run from its north edge up to the Crowns' foot, the Thornwood's oaks on the west.

How it moved (`core/world/realm/endgame.gd`, Endgame): a pure shift east by `Endgame.O` = (310, 0, 0) along the Crowns,
so north stays north and the mountain still stands behind the summit (a peak is added behind the old place too). The
forecourt is at (310, -7), 33 m north of Lastlight's north postern; the complex spans x 268..352 (east of the nav seam).
- RealmLayout's anchors (SUMMIT, SUMMIT_DAIS, SUMMIT_WARD, CROSSING_FOOT, OSSUARY_OLD, the summit raid, the rift and
  summit regions, rift_rim) and the macro shapes under them carry `+ Endgame.O`; RealmLand reads the baked chasm where it
  was baked (`Endgame.back_x`).
- The Crossing, the Threshold and the chasm's features read the world round them while they build (rays at their own
  walls and piers, their sites, the instances near them), so they still build at home, on a copy of the north-east's
  ground: RealmLand lends home the ground 310 m east while the rift module runs (`Endgame.borrow`, after the terrain's
  splat and pools are made from the land's own heights), `Endgame.settle` then moves RealmRift and everything it
  registered (sites, flights, lanes, the chapel's marks) east, and `endgame_ground.gd` gives home its own heights back
  and remakes the terrain's mesh and collision (once a boot, a few hundred ms). So every piece stands on the ground it
  was placed on: the burn's lift, the Choir House's terrace and the berms are under it while it builds.
- main.gd shifts the baked lava sheet, its haze and motes; LavaWorks works round the sheet's own centre.
- Built later in world coordinates: the summit's dressing and deck (RealmLayout anchors), the rim lore (`lore/rim.gd`),
  the rim secrets (`site_rim.gd` builds at home with its ground, flora clearings and sites read where it stands:
  `Kit.shift`; `site_breath.gd`'s search starts at the moved rim), the Crossing's own fire (`CrossingFire`), the rim camps, the quest steps,
  the pilgrims who look up at the summit, the minimap's Crossing, the ambience's rift room.
- The burn (`rift/scorch.gd`) is the original field around the moved chasm; its west flows turn south so the Choir House
  (on a levelled terrace under the west berm) stays east of the nav seam. The smoke column (`rift/plume.gd`) rises out
  of the lava in the chasm's north-east corner again and is gone 325 m out (FadeGuard's x1.5 counted: Lastlight and the
  Anchorholds' way see it, Hearthward and its country do not).
- Ways: `rift_rim` runs from `bell_track` (Lastlight's yard out of the north postern) to the forecourt; `bell_link` comes
  round the rift's west berm from the Anchorholds' foot to the forecourt.
- The Bellfall gave the Crowns' east corner to the Stair: its crater (smaller, `CRATER_C` (350, 102)) lies in the fields
  under Lastlight's south wall, with its fire, camps, rare, guardian and its own way (`bellfall_way` off nave_track),
  tier 3; its region (306..370 x 84..122) takes the flat west approach too. Four named wayside places: the crater is
  crowded by its camps, fire and landmark, so a region with no room left for a named place has it on the ground just
  round it (`realm_wayside.gd` `_force(..., spill)`). The smoke over its floor still rises from drawn, glowing cracks.
- The first act's first fire stays at home: `StairFoot` (its node name, kept for saves) is the meadow fire at the end of
  `north_lane` (rift_rim's old first leg), north of Hearthward's green; its name, the keep's, the guide's and the
  villagers' lines, the quest and the pilgrims' stone by the lane say meadow, not stair. Oswin's forty-first waystone
  is at the head of north_lane, where the long road east to the Stair begins.
- Also moved east with the endgame: the Deeper Night's bells, the spawner's haven at the Crossing fire and the rim camps, the
  Crossing and Stair-foot subzones, the chasm's bats, the starwater surge, the pilgrims' processions, the loading
  screen's three endgame shots, the world map's summit tower, Agathe's gaze. (The wayside still keeps off the old
  chasm's ground at home, so its plan elsewhere is unchanged; the moved chasm is the `rift` region it skips.)
- Tiers: the rift and the summit are 4 (the far corner). The old chasm's ground at home is open meadow and oak wood.

`--no-scorch` builds the rift without the burn round it (A/B).

## The towns

Three places people still live, built by `core/world/realm/reach_towns.gd` (REACH_POIS; plan `reach_towns_plan.gd`,
dressing `reach_towns_dress.gd`), modelled by script in Blender (`tools/blender/reach_towns.py` and its
`reach_town_*.py`: `art/models/reach_towns.glb`, collision boxes and numbers in `reach_towns_boxes.gd`), at
World-of-Warcraft proportions like the scale pilot (doors near 3 m, storeys near 4 m).

- **Reedholm** (the Reedmere): the fishers' town on piles over the pools between the end of barrow_track and the
  Sorrow. The net-hall, two fisher's houses and a long house with a net-loft under deep reed thatch with crossed
  ridge-poles, boardwalks and the decks' links, the landing (its bank raised clear of the water: a terrace) with the
  kept jetty lamps and the heron pole, the smokehouse, racks, punts, traps; the plank footbridge where reed_ford
  crosses the river. People: Aud Corle (the lamp book; task *Boats Not Home*), Hobb Wade, Siany, Gorse (sells),
  Ebba Sallow (who owes Ansel Tansy's sister a boat).
- **Fallowmere** (the low fields): round the meeting of reed_ford, fallow_way and arches_way under the scarp. The
  Order's tithe barn (buttressed, a wagon porch, one bay stripped to its rafters), the farmhouse, two cottages, the
  dovecote, ricks, the fold, the hurdled strips with stooks and scarecrows. People: Reeve Penn (task *The Last
  Tithe*), Hesper and Cobb Lark, Dilly, Brother Wystan.
- **Lastlight** (the road's east end): a walled waystation, curtain and four round towers round x 293..356,
  z 26..81; the road gate (west), the shut East Gate on the road's line (barred, chained, portcullis down), a postern
  for bell_track; the inn (the Last Lamp), the lamp tower whose lantern burns all night, the stable, the watch house
  and its platform, the store, the pilgrims' shrine, the yard and its fire (moved off bell_track to (318.5, 55.5)).
  People: Mother Vell (sells), Old Isolde (task *Oil for the Last Lamp*), Serjeant Coyle (task *The Knocking at the
  East Gate*), Fenn, Wat, Sister Maudlin.

Each town's buildings are merged into one mesh per material (a town is about a dozen draws) and fade at 230 m to one
merged far silhouette; small things keep their own short ranges. Each town's people walk their own island of the
village network (the boards are decks it walks on). `-- --no-towns` builds the Realm without them (A/B).
Tools: `zz/town_map` (a plan of a rect: heights, water, ways, sites, camps), `zz/town_probe` (what stands at points).
## The Reaches' tasks

Luke, 14 Nov: too little content. The Reaches had four tasks (the towns'); each now has a main thread and side tasks tied to its
own places, people and rares: thirteen one-time tasks, given and closed by the towns' people (docs/QUESTS_far_reaches.md has the
audit, every task and the dungeon hooks). `core/story/quest_chains_far_reaches_west.gd`, `_south.gd`, `_east.gd`.
- **West** (Reedholm's people): *Stand Down* (Aud Corle; the Order's last order, carried from the heron stones through the
  Lanternwood's ring to the fell shrine and the Sentry Who Was Never Relieved: read it, burn it or leave it sealed), *A Lamp for the
  Kings' Door* (Siany; the lamp book's first lamp, carried to the King's Barrow's open door), *Cold Light* (Ebba Sallow; Wick, the
  Lamp-Grown, and caps for the punts), *The Fourth Stone* (Hobb Wade; the heron stones' verse, a small puzzle, the Heron-Wife),
  *Tansy's Boat* (found at the Last Milestone's toll-house).
- **Deep South** (Fallowmere's people): *The Water Road* (Reeve Penn; the Fallow and Arches beacons, Spill, the water-keeper's page
  at the castellum), *The One I Didn't Make* (Dilly; the scarecrow nobody made and the Tithe-Taker), *The Witch's Price* (Hesper
  Lark; a door-nail driven into the Hollow-Witch's stone: a choice), *Cobb's Clapper* (Cobb Lark; the water-bell, held while it
  tolls).
- **East** (Lastlight's people): *The Candle for the Ringers* (Sister Maudlin; the Bellfall's Cracked Tollman and the Drowned Nave's
  west door), *The One at the Nave Fire* (Fenn; an escort home), *The Bell on the Bridle* (Wat; a timed carry to the Cairn Tower),
  *The Last Lamp's Slate* (Mother Vell; the turned-back's tokens, the One Who Counted, a choice about the slate).
Where a Reach's boss dungeon is built (the King's Barrow, the castellum or the witch's hollow, the Drowned Nave), a thread ends a step
at its entrance and leaves a hook (`HOOKS` in each file: a `q:<task>:<step>` term true once the wanderer has been sent there, and
`qd:<task>` once it is handed in); nothing waits on a dungeon being built.

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
