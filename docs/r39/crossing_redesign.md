# r39: the Crossing, redesigned (21 Nov)

Luke: "the stairway area is so badly designed, it makes no sense", "with the lava", "it needs a complete redesign".
Brief: `docs/r39/briefs/crossing_redesign.md`. Code: `core/world/realm/rift/crossing.gd` (placement), `tools/blender/crossing_*.py`
(the Blender kit -> `art/models/crossing.glb`, `art/models/crossing_layout.json`).

## 1. The critique of the old Crossing (full-size shots, `shots_before/` in the scratch folder)

Shot from the rim, every landing, the player's height going up, and the air (`a1`..`a6`, `01`..`15`). What confused or broke, and what answers it:

| # | What was wrong (shot) | The redesign |
|---|---|---|
| 1 | **A zig-zag with no reason** (`a5_top`: from above the route is forecourt -> T1 -> T2 on the west -> T3 on the east -> Spindle: four heading changes in 40 m, each tower a stop that is not a place). | One axis. The Causeway runs straight at T3, then straight on north to the ward: the only turn is the climb round the Spindle, and it returns to the same line. |
| 2 | **A gap with a log across it** (`08_column`: the fallen column, no parapet, a snapped pier: a puzzle on the way to a boss, not a pilgrims' viaduct). | Gone. The Causeway is an unbroken three-bay arcade; the ruin is in the masonry (broken courses, missing copings), not in the way. |
| 3 | **Ramps, stairs and flats alternate round the Spindle** (`11_spindle_12`: a tilted slab with a parapet that slopes with it; the next stretch is steps, then a ramp again). | One helix of steps (49) with the same tread and riser all the way, three level rest landings with a fire and a bench each. |
| 4 | **The turn stacks over itself** (`a5_top`, `12_L6a`: the last flights, a mid landing, a flying arch and the L4 flight all in the same 12 m; L6a/L6b go over L4 with a block of "fill" under them). | The helix's top lands on the Spindle Gate (a stone block over the stair's first turn: the way in passes *under* the way out, through an arch, as in a stair tower). The way on is one flight over a real two-bay bridge. |
| 5 | **Parapets sloped with the ramps** (`11_spindle_12`: a sloping coping, the broken top a random few blocks). | Parapets are level or stepped (a block per two treads, a flat coping, a post at each change). |
| 6 | **Nothing says where to go** (`01_rim_approach`: from the rim the way on is hidden behind the gate; no light on the route; the summit not visible). | The forecourt gate frames the Causeway's first flight; every landing has a lit fire (forecourt, T3, three on the Spindle, the Gate, the ward landing): a column of fires climbing to the ward from the rim. |
| 7 | **The lava is beside the route, not under it** (`a1_air_se`: the walk is over the starwater until z -46; the viaduct is not over the lava at all, the lava is only a view). | The climb *is* the lava crossing: T3 (z -40) is the last place over starwater; everything from the Spindle on (the helix's piers standing in the flow, the Gate, the bridge's pier P2, the ward landing's foot) stands in lava, with fire on the undersides. |
| 8 | **The Pilgrims' Stair is a side effect** (`09_t3`: the stair leaves T3's east side through a gap in the parapet, no sign, the way north and the way down look the same). | T3 is the junction: the way down is a freestanding Pilgrims' arch with a violet lantern at the stair's head; the way on is a pair of fire posts. Three openings, three different things. |
| 9 | **Box art** (the tower plinths, arcades, parapets were code boxes in a four-line stone). | Every piece is hand-cut ashlar from Blender: coursed blocks, voussoirs, quoin posts, corbels. |
| 10 | **Walk snags the old design needed special cases for** (the lane "audited against the deck above it", clipped hints, T2's parapet camp). | The walk is a single line: no stretch lies over another except the Spindle's stair over the flight in, 12 m clear. |

## 2. The new route, top-down (rift coordinates: x east, z south; chasm on x 0; walk heights in brackets)

```
 z -71 +-----------+  WARD LANDING  8 x 9.2 m  [25.2]   (fixed)      fires: 2 posts + a beacon (SE)
       |  landing  |  the summit's approach stairs start from its north edge
 z -62 +--+--------+
          |   BRIDGE  (x -1.4)  14 steps, 2 bays of arch on pier P2 in the lava   [21.2 -> 25.2]
          |
 z -52 +--+--+  SPINDLE GATE  block x -5.3..1.3 (the roof is the top landing [21.2], fires)
       |  ^  |  the stair's first turn passes under it, through a pointed arch
 z -50 +--+--+
          |  \___ helix R 6.5, 49 steps, 3 landings (N, W, S), round the basalt Spindle (-8.3,-50)
          |  /
 z -43.5 -+  flight north (L4)  9 steps [5.6 -> 8.0]
 z -40  ( T3 )  PILGRIMS' GATE  round tower r 3.5 [5.6]   -> Pilgrims' arch + stair down (E side, -35 deg)
          |                                                   to the quay and the chapel (unchanged)
          |   CAUSEWAY  3 bays x 7.5 m, two/three tiers of pointed arches over the starwater,
          |             19 steps in three flights + landings at the piers   [0.6 -> 5.6]
 z -14  +--+--+  forecourt gate (a pointed arch over the first flight)
 z -7   |     |  FORECOURT 9 x 7 m [0.6] on a two-tier arch over the pool's mouth, the Watchers either side
 z -4.6 +-----+  apron, 3 steps to the rim path  CROSSING_FOOT (0, 0.6, -8)   (fixed)
```

Height profile (walk level against distance along the route):

```
 25.2                                                              ___ ward
 21.2                                                  ___/ gate, bridge
 18..                                       helix (49 steps, landings 11.2 / 14.5 / 17.7)
  8.0                                 L4 /
  5.6              T3 ______________/
  0.6  forecourt ___/  causeway
        0        26 m      46 m       ~100 m              ~155 m (path length)
```

Landing by landing (what you see, what a pilgrim does):

1. **Forecourt (0.6):** the gate's pointed arch frames the Causeway's first flight climbing to a lit tower; the Watchers' violet lanterns either side, the starwater below, the lava a red glow far ahead. Fire posts at the gate piers.
2. **Causeway piers (2.2 and 3.8):** flats 3 m wide at each pier, a lamp post at the middle ones. Looking back: the forecourt gate and the rim. Looking on: T3's two fires and, high behind it, the Spindle's fires climbing.
3. **T3, the Pilgrims' Gate (5.6):** three ways. East: the Pilgrims' arch with a violet lantern, the stair winding down to the pool (the chapel branch). North: two fire posts and the flight into the Spindle. South: back. First view of the lava and the whole climb.
4. **Spindle, north landing (11.2):** a bench, a fire; the ward landing's fires straight ahead; the summit above.
5. **Spindle, west landing (14.5):** the rift's west wall and the Choir House's glow; the lava river below.
6. **Spindle, south landing (17.7):** looking back over T3 and the Threshold: the Watchers, the starwater, the village's hills.
7. **Spindle Gate roof (21.2):** the top landing; two fires; the bridge and the ward landing a flight away over the lava.
8. **Ward landing (25.2):** the summit's stairs ahead, the whole crossing behind and below.

## 2b. The lava pit (Luke, later the same day: "the lava pit is small and just doesn't make sense")

Today's pit: a 40 m trench (walls at |x| 20-25 at y 0..4, the lava sheet 92 x 130 m already under it), the flow a strip between organ-pipe banks. Planned with the Crossing:

- **Bigger:** `rift/pit.gd` draws the walls back between the Spindle and the ward landing (z -50 .. -86): RealmLand samples the baked wall profile up to 8 m nearer the middle, so the lava lies in a bowl up to 16 m wider (about 56 m rim to rim), the helix and the Gate standing out in open flow. The kept ends do not move: nothing south of z -48 (the starwater pool, the Watchers, the terraces, the forecourt, the rim road) and nothing north of z -84 (the summit's pillars, the ward).
- **A source and a flow:** the three falls on the west wall (z -60, -82, -104: LavaWorks finds each lip on the real rock, so they follow the drawn-back wall) and the east falls feed the bowl; the west flows (rift/scorch.gd) run down the berm into it. The bowl is the widest where the falls land (z -60 .. -82) and narrows to the channel south (the cooling river) and north under the summit.
- **A crust edge cooling to basalt, glowing cracks:** the bank mask samples the real rock at the lava line, so the new banks get the crust shelf and contact rim for free; the basalt cliffs, organ pipes, crust islands and fissures (rift/features.gd) are placed by rays on the new ground.
- **Kept:** the lava's light (the Glow lights, the underglow), the kill volume and burn handling (the 92 x 130 m sheet already covers the widened bowl), the bank mask, LightGrid, sound.
- **The Crossing spans it:** the route's lava stretch (the helix's piers, the Gate, the bridge's pier P2, the ward landing's foot) now stands in a pit that is visibly wide.

## 3. What is kept (and read by the rest of the game)

The forecourt's footprint and `CROSSING_FOOT`; the ward landing's footprint and `SUMMIT_WARD` (top 25.2); T3 at (-1.8, -40), r 3.5, deck 5.6 with the parapet opened at -35 deg for the Pilgrims' Stair (`rift/tower_stair.gd`, the chapel and the quay, untouched); the Spindle (basalt stack, collision cylinder, centre (-8.3, -50), r 4.1) and its site; the pier feet reaching the lava line (the bank mask); the `rift_*` sites and flights and the three `rift_crossing*` lanes in `WorldLanes`; the walk-test points (updated: `zz/realm_rift_walk.gd`, `zz/threshold_walk_test.gd --full`, `zz/perf_tour.gd`, the loading screen's cameras, the minimap's deck line); the seal guards' camps (moved from T2 to the Spindle's west landing and the ward landing).

## 4. Build checklist (live)

- [x] critique shots (`shots_before/`, 25 views) and the chasm probe (walls |x| 20..33 at y 0..12)
- [x] plan (this file)
- [x] Blender kit: lib (masonry, arches, ring blocks), deck (profiles, stepped parapets, arcades), towers, spindle, sections
- [x] sections: forecourt, causeway (4 bays, the last one arching over the Pilgrims' Stair's ring), T3, flight north, helix, Spindle Gate, two-bay bridge, ward landing (render review of each; `tools/blender/crossing_kit.py`)
- [x] `crossing.gd`: place the GLB, materials, collision layers, fires, sites, lanes, the Spindle stack, the lava's underglow
- [x] dependants: enemy camps (T2 -> the Pilgrims' Gate), minimap line, walk tests (`zz/realm_rift_walk.gd`, `threshold_walk_test --full`), perf tour
- [x] walk it with the Player: `realm_rift_walk` rim -> summit dais (44 legs ok) and `--stair` T3 -> Pilgrims' Stair -> quay -> chapel door (35 legs ok)
- [x] re-shoot once (`shots_after/`, 27 views) and looked at
- [x] parse check, lint (`tools/lint.sh` clean)
