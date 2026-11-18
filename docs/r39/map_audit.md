# r39 map audit: the whole Realm, shot everywhere, critiqued, fixed

Brief: `docs/r39/briefs/map_audit.md`. Branch `map-audit` (clone `/Users/luke/UmbralReaches_map_audit`). This file is the live
checklist: every finding, its location, a screenshot, its fix and the commit. Resume from "State" below.

## State

- [x] harness built (`zz/map_audit_shots.gd/.tscn`, `tools/map_audit.sh`; measured probe `zz/map_audit_probe.gd/.tscn`)
- [x] grid shot (40 m, 266 points x 5 views) and read (raw notes: `<scratch>/notes.md`, one line per sheet)
- [x] named places shot and read (619 places merged from 900+ names: regions, slots, POIs, beacons, fires, lore, secrets, chests, lamps, raids, gates, ways' ends and junctions)
- [x] interiors shot and read (52: every Interiors room, every acoustic volume, the deep halls' and caves' stairs, the Ossuary's 18 stations)
- [x] measured probe run (`zz/map_audit_probe.gd`: holes, floating/sunk props, lights in the air, ways blocked or under water)
- [x] critique written (below)
- [ ] fixes, worst first (Luke, 18 Nov 20:50, via the lead: **do NOT re-shoot after each fix.** Make every fix first (F1..F30,
      T1..T8) from code, probes and notes; then ONE re-shoot pass of all the fixed spots, read those, fix what is still wrong,
      then the one test run. Short headless probes/censuses to settle a specific doubt are fine; no capture run per fix)
- [ ] one re-shoot pass of every fixed spot, read, fix the leftovers
- [ ] tests once at the end (`--quick`, then the world tests the brief lists)

Scratch: `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/map_audit/`
(`<region>/<spot>.jpg` contact sheets: N, E, S, W eye views, the aerial and an info card with a locator map; `full/` the frames).

## Lead-reported test failures on master 8fec6c51 (from the arenas' 1.6x growth; fix in this pass, re-check at the end)

| # | Test | Failure | Where | Fix | Commit |
|---|---|---|---|---|---|
| T1 | lore_codex_test / placement_test | the abbey bounds wall (`lore/wilds.gd` tw_bounds, (-56,58)..(-48,36)) finds no clear spot: codex tw_boundary not placed | west of Hearthward | | |
| T2 | lore_codex_test / placement_test | rare kin_caller (`core/enemy/rares.gd`, spots moved 31 m west with the Holds to (-166,23)...) finds no haunt | the Rooted Holds | | |
| T3 | realm_lore_test | tw_cutter floats 3.5 m at (-103.2, 4.0, 35.9) (the woodsmen's camp, wilds.gd `_woodsmen`) | Thornwood edge | | |
| T4 | realm_lore_test | site hw_garden_n on a path and overlapping henge_stair (stair foot now (-34.7, 0.5)) | Hearthward north-west | | |
| T5 | realm_lore_test | site glade_shrine overlaps henge_titan_1 (Titan wardens inside the raid wall; Glade at (-28, 32)) | Glimmer Glade | | |
| T6 | realm_lore_test | sites tw_ring and nc_grave are "in the rift" | ? | | |
| T7 | robust_test | brazier HoldsFire spawn point (-167.2, 5.7, 15.3) inside a solid (`realm_bosses.gd` HoldsFire candidates) | the Rooted Holds | | |
| T8 | nav_test | "behind it, the wretch reaches her within 2 m inside 40 s with the mesh (0 of 2)" (wall case near (33..44, -19..-30), the Fen postern) | the Fen postern | | |

## What was shot

- **Grid:** 266 points, 40 m apart over the whole of BOUNDS (x -360..360, z -140..380): four eye-level views (1.7 m, FOV 90)
  and an oblique view from 25 m up (60 m where the Crowns are in the way). 1,330 frames.
- **Places:** 619 spots (every region, slot, world POI, landmark beacon, fire, lore stone, secret, chest, lamp, raid floor,
  gate and approach, March Wall gate, deep-hall and cave door, watch post, stable, ways' ends and junctions; names within 8 m
  merged): four eye-level views AT the place from its four sides and one aerial. 3,095 frames.
- **Interiors:** 52 stations (the Keg, Weirford's inn, cottages and watch hut, the Holds' hall, the Spire, the four deep
  halls and five caves (stair, middle, reward room), 18 acoustic volumes (towers, hollows, the Sleeper's heart, the ship's
  hold, the Nave crypt), 18 Ossuary stations: landing, bridge, gate hall, gallery, pit, chapel, the Lower Count, the
  Counting Stair top/middle/foot, the pit hall's door, floor, centre and tier). 260 frames.
- Total: **937 spots, 4,685 frames**, every contact sheet read at full size. All at night through the game's own grade.
- Measured probe over the same build: no holes in the terrain anywhere (0 of 101,000 2 m points); 0 shadowed lights;
  176 way samples blocked, 10 under water; 28 lights with nothing within 1.2 m (all accounted for below).

Harness notes (not world findings): on a slope an aerial's near plane started inside tree crowns (fixed: near 5 m up there);
`RealmLayout.ground` falls back to the macro height when a rock or roof is the first thing its ray meets, which put a few
place eyes under the ground (Grandmother Oak N/E, grid (120, 340)); fixed (`_gy` excludes non-terrain hits).

## The critique

### Creative director

The Realm has three or four places that are genuinely good: Hearthward's square, the Keg, Weirford, the Pilgrims' Landing
with the bone bridge and the Lantern of the Dead, the Long Arches from the south, the Drowned Nave's vault, the Upward Falls,
the Cairns. Everything else is a theme park of boxes lit by accident. The night is supposed to be the clock and warmth is
supposed to be earned (pillar 2), yet the most luminous objects in the game are **unlit**: every cold brazier wears a white
fog-ball brighter than a lit lamp; secrets glow like street lights; the meadow fire (the first fire of the night) is drowned in
a pink 5 m bloom, a look Luke rejected by name ("wide fire bloom", umbral-donts). Meanwhile the places people actually live
(Fallowmere, Lastlight, the Broken Keep with its garrison) are pitch black from every side. The map tells the player the
opposite of the pillars: the empty ruins shine, the inhabited towns are dead.

The 18 Nov arena growth broke the west: the Rooted Holds and west_track were moved onto the West March Wall's line, so the
"heather clearing deep in the west wood" is a ditch against an 8 m brick wall, the track runs inside the wall for 80 m, and
the Holds' fire, hall and camp are in or against the masonry. The Thorn Henge's floor became a 100 m car park with the
original 15 m ring lost in the middle; the Thornwood's heart is gone. The Glimmer Glade's name moved to Hearthward's back yard
while its shrine stayed on the henge hill under a Titan warden. Two landmarks are built inside each other twice (the Salt
Ship inside the salt-works; cave 4 inside the Sleeper) and a Wardens' tower stands in the East March Wall.

The r39 "wonders" pass reads as a code generator's: six identical climb towers with debris cubes floating round their tops,
seven identical hermit shacks, ten identical slit-window Wardens' towers whose full-bright orange window quads are visible in
nearly every frame of the Realm, a "Sleeper" that is a stepped block tower, Titan wardens that are box robots with orange
slit eyes. Luke's bar (18 Nov) is "every model authored in Blender with a render review": none of these are.

### Level designer

- The ways network has holes: west_track blocked by the March Wall (z -31..44), siege_track wading 1.3 m in the Sorrow at
  Weirford, anchor_track through the east spur's tower, downs_track through the West March Wall at z 191, southwood_way into
  the Cairn Tower, salt_track under the Salt Ship, the fell track ending wedged in boulders, the road's west end in a rock wall.
- No junction anywhere has a signpost; a player at any of ~30 junctions cannot tell where a way goes. (Pillar 3: the world
  teaches; it doesn't here.)
- The old rift ground north of Hearthward (x -60..60, z -120..-10) is 120 x 110 m of empty meadow holding the Charcoal Hollow,
  the Watchers' Spire and the Ninth Company's ring, none of them on a way (66-84 m off).
- Named places 50-75 m from any way, unlit and unmarked: the fell shrine, the heron stones, the gleaners, the Hierarch's hand,
  the Hollow King, the witch's hollow, the fallen saint, cave 3 on the rift berm's crest, the Crowns' beacon on the crag.
- Arenas don't read as arenas: the henge floor is a bare disc; the Anchoress's terrace is a 58 x 36 m cobble sheet with pines
  standing on it; the Speaking Crown's skull reads as a cave mouth; the summit deck has pines over its north wing.
- Camps at many slots are bare grass (a camp is its enemies only); one stands on a 30 degree scree (anchorholds camp_2).
- The Lanternless Moor ("open high heath, long sight lines") is a wooded strip under the East March Wall.

### Environment artist

- Black untextured boxes and slabs everywhere: rubble cubes, a black hexagonal plate on the henge stair-foot's paving, black
  sign-boards, black logs on Lastlight's green, black boat hulls, the pans as pure black rectangles, black cubes floating
  round tower tops.
- Flat full-bright orange quads as windows, lanterns (the Chain Span's cube lanterns), "paddle" signs, the Sleeper's heart,
  cave hangings; a salmon rectangle as the Nave crypt's light well; a cyan rectangle on the mere chapel.
- Cart ruts are hard black stripes painted on every way, through gate arches, across the Anchoress's paved terrace.
- The salt kit's crazed-tile ground bleeds into the mere's bank, Saltmarket's yard, the Southwood path and the Nave crypt's gate.
- Lava flows are flat orange cards on slopes; a vertical lava "spill" card stands like a door by the Crossing.
- Interiors: Weirford's inn is a 20 x 13 m empty plaster box with a hearth; its three cottages are the same empty box. The
  deep halls and caves have doorways opening onto the night sky (one-sided terrain seen from underground), ceilings and
  walls breaking the surface on the hillsides above, and flat blue murk inside.
- Repetition: climb towers x6, Wardens' towers x10 (two of them 20 m apart at the Nave), hermit caches x7, all identical.

### Lighting artist

- **Volumetric glow balls** are the single worst lighting defect: small fill lights near the ground light the froxel fog
  into 3-6 m blobs (the meadow fire, the henge raid door, the Singing Stones, every unlit brazier, every secret glint,
  lamps, the Ossuary's gate hall and Lower Count). Root cause: `light_policy.gd` gives the default "fill" class a
  volumetric energy of 1.15, 2.5x a lit beacon and 5x a lamp.
- Inhabited places unlit from afar (Fallowmere, Lastlight, the Broken Keep).
- Underground rooms take the outdoor night's blue ambient and haze (no Interiors room registered): every deep hall is blue fog.
- The Ossuary's bone chapel is flooded magenta; the Counting Stair is fogged blue-violet.
- Near unlit props crush to pure black silhouettes (no material reads under 3 m from the camera).

### Tech artist

- The Bone Abbot's pit hall does not render in any of 5 stations (door, floor, centre, tier, stair foot): through the
  stair's door there is only the underside of the terrain. To verify against the hall's visibility tick (its local box
  was not grown with the 1.6x hall).
- Single-sided terrain + dungeon door gaps = windows onto the sky from underground.
- A mist card's hard top edge cuts across views (the north wood (-40,-100), the aqueduct's arches (-22,336)); the eye inside
  a mist bank turns Fallowmere's north view white.
- The Ossuary pit's fog volume has a hard edge (a flat pale wall where the pit's far face should be).
- The Upward Falls' spray fan blows out the Empty Plinth's north view.

### Technical QA (measured, with coordinates)

- Ways blocked (probe): west_track x 18 samples (-157..-167, z -31..44, MarchWallBody_-1); downs_track (-162..-170, 191);
  anchor_track (175.6, 49) east spur tower; southwood_way (324.9, 312.8) Cairn Tower; salt_track (212, 168) Salt Ship;
  road (-364.5, 48.2) edge rocks; road (4.8, 45.2) a Hearthward prop body.
- Ways under water: siege_track (-215.9, 69.7..80.8) 1.1-1.3 m; reed_ford (-283.9, 305.6) 1.35 m.
- Overlaps: Salt Ship / salt-works (229, 170); cave 4 / the Sleeper (118, 343); WardensTower on the East March Wall (152, 104).
- Floating: climb-tower iron debris "nothing under" at (272.2, 16.6, 330.6), (-357.7, 49.9, -130), (150.8, 21.7, 264.4),
  (71.6, 18.3, 364.8), (341, 17.9, -85.1); hermit-cache iron (8.0, 8.8, 280.5); the Salt Ship's hold chest 3.6 m over the
  ground (221.1, 3.8, 172.3); the Ossuary chapel's roof slabs over a gap.
- The lead's eight failing test cases (T1-T8 above).

### Player

"I spawn in a lovely village and walk north to the first fire and there's a giant pink cloud next to it. Every fire I haven't
lit glows white so I can't tell which ones I lit. The road signs are black boards with nothing on them. The towers all look the
same and they all have glowing orange slits. I went down into a crypt and it was blue fog and I could see the sky through the
wall. The inn in Weirford is empty. The Rooted Holds are a ditch next to a wall. The henge is a parking lot. The boss in the
Ossuary's pit hall: I walked down the Counting Stair and through the door there was nothing."

## Findings, worst first

Severity: **S1** broken (blocks, overlaps, invisible, holes), **S2** wrong (placement, lighting that breaks a pillar),
**S3** weak (craft, readability). Sheets: `<scratch>/map_audit/<region>/<spot>.jpg`.

| ID | Sev | Where | Finding | Sheet | Fix | Commit |
|---|---|---|---|---|---|---|
| F1 | S1 | Ossuary pit hall (local C 75,-32,-80; world (6,-39,226)) | The Bone Abbot's 1.6x hall does not render from its own door, floor, centre or tier: the stair's door opens onto the terrain's underside | interiors/oss_hall_floor.jpg, oss_stair_foot.jpg | | |
| F2 | S1 | West March Wall z -40..52 | west_track runs inside the wall for ~80 m (probe: 18 blocked samples); the Rooted Holds' hall, earth-houses, camp, kin stone and fire are against/in the wall; the Holds' hall room is open to the sky with the wall through it (T2, T7) | holds/reg_holds.jpg, interiors/room_holds_hall.jpg | | |
| F3 | S2 | everywhere (light_policy fill class) | Volumetric glow balls round unlit braziers, secrets, lamps, the meadow fire (pink 5 m bloom), the henge raid door (5 m white sphere), the Singing Stones (3 m cyan ball) | hearth/fire_StairFoot.jpg, road/secret_Singer_0.jpg, thornwood/poi_titan_gate_henge.jpg | | |
| F4 | S1 | White Pans (229,170) | The Salt Ship is built inside the r37 salt-works: derrick through the hull, shed roof through the deck, salt heap in the hold; salt_track under the hull | saltpans/poi_salt_ship.jpg, interiors/vol_02_ships_hold.jpg | | |
| F5 | S1 | Southwood (118,343) | Cave 4's stair and mouth are inside the Sleeper's block mass | southwood/door_Cave4.jpg, interiors/stair_Cave4.jpg | | |
| F6 | S1 | East March Wall (152,104) | A Wardens' tower stands in the March Wall (the wall's courses fill its room); another (-142,104) stands against the West March Wall's tower; two (270,104),(286,116) are 20 m apart | interiors/vol_06_tower.jpg, vol_05_tower.jpg | | |
| F7 | S1 | Glimmer Glade (-28,32) / henge skirt (-45.5,17.5) | The Shrine of the Lost stayed on the henge hill's skirt under a Titan warden; the Glade region moved to Hearthward's west yard and has nothing of the glade (T5) | thornwood/lore_Lore_gl_shoe.jpg, glade/reg_glade.jpg | | |
| F8 | S1 | ways | siege_track wades 1.1-1.3 m in the Sorrow at (-215.9,70..81); downs_track blocked by the West March Wall at z 191; anchor_track through the east spur tower (175.6,49); southwood_way into the Cairn Tower (324.9,312.8); fell_track ends wedged in boulders (-312,-78); the road's west end in edge rocks (-366,48) | probe; greyfell/way_fell_track_end.jpg, lanternwood/way_road_start.jpg | | |
| F9 | S1 | deep halls & caves (9) | Doorways open onto the night sky from underground; rooms/ceilings break the surface (caves 1, 2, 4, the undercroft, the cisterns); no Interiors room: the outdoor blue haze fills every room; sconces and hangings are flat orange quads; the Nave crypt's light well is a salmon rectangle | interiors/vol_10..17, stair_*.jpg, arches/poi_cave_1.jpg, kingsbarrows/poi_kings_undercroft.jpg | | |
| F10 | S1 | climb towers x6, hermit cache 3 | Black iron debris cubes float in the air round the tower tops (probe: nothing under 4 m+) | arches/poi_climb_tower_2.jpg, southwood/poi_climb_tower_4.jpg | | |
| F11 | S2 | Saints' Quarry, Anchoress's terrace, summit deck, fires under willows | Designed spots not clearing their own trees: a pine forest on the quarry floor; pines on/over the Anchoress's terrace and the summit deck's north wing; willows over the foundry junction fire (123,-76), Reedholm's landing fire (-316,302), the Stillwater fire (220,52) | quarry/reg_quarry.jpg, anchorholds/raid_anchorhold_floor.jpg, summit/raid_summit_floor.jpg, foundry/slot_foundry_fire_0.jpg | | |
| F12 | S2 | Thorn Henge floor (-86,-24) | The 1.6x floor is a 100 m bare disc; the 15 m ring is lost in the middle; nothing between ring and rim | henge/reg_henge.jpg | | |
| F13 | S2 | Ossuary chapel (30,169) | Flooded magenta; its roof slabs float over a visible gap | interiors/oss_chapel.jpg | | |
| F14 | S2 | towns | Fallowmere, Lastlight and the Broken Keep unlit from every side (no inhabited window or hearth glow) | fallow/poi_town_fallowmere.jpg, lastlight/poi_town_lastlight.jpg, greyfell/poi_broken_keep.jpg | | |
| F15 | S2 | Weirford interiors | The inn, three cottages and the watch hut are the same empty plaster box | interiors/room_bld_inn.jpg, room_bld_cot_a.jpg | | |
| F16 | S2 | everywhere | Cart ruts painted as hard black stripes, through gates and across the Anchoress's paved terrace | road/march_gate_0.jpg, anchorholds/raid_anchorhold_gate.jpg | | |
| F17 | S2 | rift berm, Anchorholds, the Crossing | Lava flows as flat orange cards on slopes (250,-91),(280,-60); a vertical lava spill card by the forecourt (282,-23.6) | anchorholds/poi_way_ah_chain.jpg, rift/secret_Cache_spill.jpg | | |
| F18 | S2 | Empty Plinth (-212,-101) | The Sorrow spring's spray fan blows out the north view | plinth/reg_plinth.jpg | | |
| F19 | S2 | old rift ground (x -60..60, z -120..-10) | Empty 120 x 110 m meadow; the Charcoal Hollow, the Watchers' Spire and the Ninth Company's ring are not on any way | crags/poi_charcoal.jpg, crags/poi_spire.jpg | | |
| F20 | S2 | ~30 junctions | No signposts at any junction | hearth/way_necropolis_way_start.jpg, saltpans/way_salt_track_end.jpg | | |
| F21 | S2 | mist cards | A mist card's hard edge across the views at (-40,-100) and (-22,336); Fallowmere's north view white inside a mist bank (-160,300) | crags/g01_08, arches/poi_way_la_fountain.jpg, fallow/g11_05 | | |
| F22 | S3 | everywhere | Black untextured boxes/slabs (rubble cubes, the henge stair-foot's black hexagon (-31,4), black sign-boards, Lastlight's black logs (320,60), black hulls, black pans) | thornwood/fire_Shrine.jpg, lastlight/g05_17 | | |
| F23 | S3 | everywhere | Flat full-bright orange quads: Wardens' tower window slits, the Chain Span's cube lanterns (-333,20), "paddle" sign-boards, the Sleeper's heart, cave 4's hangings | lanternwood/poi_chain_span.jpg, arches/lore_Lore_wy_la_way.jpg, interiors/vol_00_heart-hall.jpg | | |
| F24 | S3 | the pilgrim's camp (-102,167) | The kept fire is an orange cone with no light; the sleeper, pack and bedroll are boxes | downs/secret_@Node3D@15396.jpg | | |
| F25 | S3 | ash mound | A glossy black lozenge with neon orange stripes | downs/lore_Lore_r37s_down_grave.jpg | | |
| F26 | S3 | salt kit | The crazed salt-tile ground bleeds into the mere bank (136,126), Saltmarket's yard, the Southwood path (200,260) and the Nave crypt's gate (267,120) | mere/poi_mere_landing.jpg, nave/door_Hall_nave_crypt.jpg | | |
| F27 | S3 | Ossuary pit | The pit's fog box has a hard edge (a pale wall where the far face should be) | interiors/oss_count_door.jpg | | |
| F28 | S3 | code-built models (flag) | climb towers, Wardens' towers, hermit caches, the Sleeper, Titan wardens, the capstan's buttresses, stepped cairns, the chasm's stair-stepped walls, the Choir House, the Lanternwood mushroom house, the witch's houses, the salt-sack stairs, the plinth box, the mausoleum, the castellum pyramid, the anchorite cells/chapel, the King's Barrow dome, haystack domes, salt heaps, the crystal crust, notice boards, sign-posts, lamp-post boxes, the briar tubes | (many) | | |
| F29 | S3 | glimmers | Glimmer orbs float inside the Keg and every cottage | interiors/room_tavern.jpg | | |
| F30 | S3 | the summit seal (310,-70.9) | A flat translucent purple rectangle with ripple rings | summit/fire_SummitFire.jpg | | |
