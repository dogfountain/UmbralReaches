# r39: the Ashen Rift, from scratch (21 Nov)

Luke on the first redesign (`crossing_redesign.md`): "Do the materials match the rest of the game, make the platforms lower, and why is it
half water half lava?? Or please redesign it from scratch, this is literally just a location change with minor adjustments."
Brief: `docs/r39/briefs/rift_from_scratch.md`. Shots: the scratch folder's `rift/before/` and `rift/after/` (1600 x 900).

## 1. What failed, against his words (`before/`)

| Shot | What it shows | Why it fails |
|---|---|---|
| `r01_rim_road` | the Watchers' violet lanterns either side of the view, the Spindle, the helix, the bridge on piers | the same towers-and-Spindle composition as the old Stair: a location change |
| `a08_air_se`, `a10_top` | a violet starwater pool beside an orange pit | "half water half lava": two elements in one rift, the join a straight line at z -46 |
| `l05`, `l06`, `a19_air_e_low` | the causeway and the helix 16-37 m over the lava on tall piers; the summit's disc on square piers behind | "make the platforms lower": the walk is a viaduct, never near the fire |
| `l07_ward_back`, `v13_lava_mid` | pale tinted ashlar with a cold glow (`starlit_stone`, `_mat(...)` tints + emission), box basalt pipes | "do the materials match": the stone glows grey-violet like no other place; the basalt is code boxes |
| `v13_lava_mid`, `l07` | the lava as orange swirl rings, the same everywhere | no source, no flow, no crust: a tiled sheet, not a pit |

## 2. The concept: the Cinder Way

**One element.** The whole rift is lava. It is born in the north, under the summit (the falls off the east wall at z -70 and -88, and
the lava boiling up out of the channel's floor), runs south down the east channel into a molten pool at the foot of the Ward Crag, and
spreads over the rift's floor towards the village, cooling as it goes: by the south rim it is a plain of black crust with thin red seams.

**One route, low, then one climb.**

```
  game coords (chasm on x 0, z south; heights in [ ])                         N
                                                                              ^
  x:       -24      -18        -10        -3    4     10     16      24
 z -71 .....................+---------+   WARD LANDING x -4..4 [25.2] (fixed), fires + beacon
                            |  T4 --->|   (the summit's own stairs go on north)
 z -64   S3 [17.6] <-------T3---------+------+ S2 [7.6]    east channel x 10..28: molten, flowing south
         |                                   |              falls off the east wall (z -70, -88), a boil (z -78)
 z -55   S1 [-2.4] -------T2---------------->+
         |   THE WARD CRAG (modelled basalt)  |
 z -51   +<-------T1------------------------ F [-12.4] fire          a boil at the pool's edge (12, -46.5)
                (W) Watcher   molten pool      \  B2 (low arch over the fire channel)
 z -37      chapel                        CINDER ISLE [-12.4]  camp, fire
             ^ branch                    / B1
 z -28       |               isle I1 ===/                (E) Watcher, on its plinth in the crust (16, -24)
 z -24   L2 [-8.7] --D3--> FOOT [-12.4] ==C1==/            crust plain, cooling: the seams thin out southward
           |  D2
 z -8    L1 [-4.1] <---D1--- THE LIP [0.6] = CROSSING_FOOT, two fires; the rim road arrives from the south
```

- **The Lip** (rim, y 0.6): a paved terrace at the rim road's end with a balustrade and two fires. From it the whole way reads: the
  Descent's fires to the left, the black plain, the Watchers, the Cinder Isle's fire, and the zig-zag of fires up the Ward Crag.
- **The Descent** (0.6 to -12.4): three flights on a basalt ledge built against the south-west corner (14, 14 and 11 steps, 0.33 m
  risers: west along the rim, north down the west wall, east onto the plain), two landings, a parapet on the drop side and the rock on
  the other. Low and in the rock, not on piers.
- **The Foot** (-12.4): a shelf at the west wall's foot. The **chapel branch** leaves it north along the wall to the Pilgrims' Chapel.
- **The Cinder Way** (-12.6 to -12.3, 2.9-3.2 m over the lava): a stone causeway on natural basalt islands across the crust plain, two
  low bridges (one segmental arch each) over glowing channels, the **Cinder Isle** in the middle (a rest, a fire, the seal guards' camp).
- **The Ward Stair** (-12.4 to 25.2): four long traverses cut into the Ward Crag's south face (30, 30, 30, 23 steps), switchback landings
  at the ends (S1 west, S2 east over the channel, S3 west), a fire at each: a Z of fires on a dark cliff, read from the rim.
- **The Ward Landing** (25.2, fixed): on the crag's north-east shoulder; the summit's own stairs start at its north edge.

Metrics: risers 0.33 m (<= STEP_MAX 0.45), treads 0.68 m (26 deg flights; no ramps), 3.6 m clear between parapets, parapets wherever a
side drops. Landings are level. The walk is never more than 3.2 m over the lava until the climb, and the climb is cut into rock.

**Hot to cool.** Molten (white-gold channels, few rafts): the east channel and the pool under the crag (z < -44). Then thickening crust
with orange seams (z -44 .. -28). Then black crust, the seams thin and dim, many cold plates (z > -28). The lava's four glow lights
move north with the heat (none over the south rim). Heat shimmer over the pool and the channel.

**Content.**
- **The Watchers** stand on modelled basalt plinths (`rift_rocks.glb` Plinth) either side of the Cinder Way's middle, facing the village:
  the west one at the molten pool's edge under the crag (-2, -43.2), the east one in the crust (15, -23.5).
- **The Pilgrims' Chapel** stays where it was cut, in the west wall north of the Foot (its secret intact); no starfall now: the doorway
  looks out over the cooled crust. Reached by the branch from the Foot (7 m along the wall). Quest and secret texts updated (section 5).
- **The camp**: the seal guards hold the Cinder Isle and the Ward Landing.

## 3. Materials (the same as the rest of the Realm)

| Part | Material | Where else it is used |
|---|---|---|
| Parapets, bridges' arches, fire plinths | `WestKit.mat("stone")` untinted, no emission (the r37 set) | Hearthward's gate, market cross and cottages (`village_gate.glb`, `cottage_*.glb`: `__stone`), the West Marches landmarks |
| Steps, the Lip's and the landings' flags, the causeway decks | `WestKit.mat("hewn")` untinted (the r37 dressed grain for modelled single stones) | the beacons, the modelled masonry of the ruined landmarks (`masonry_lib.py`) |
| Basalt: the Descent's ledge, the Ward Crag, islands, shores, plinths | `RockKit.material("basalt")`, `("ash")` where the foot meets the lava | the rift's rim (`rift_rim.gd`), the Realm's cliffs and boulders |
| Fire baskets | the iron set `WestKit.mat("iron")` | every West Marches lamp and brazier |

The old `starlit_stone` (a tinted, glowing kit stone) and the Crossing's tinted `_mat()` copies are gone from the rift.
Side-by-side (`after/m*`): the Cinder Way's stone next to Hearthward's gate and the henge's stones.

## 4. Build checklist (live)

- [x] look: `before/` (20 shots: rim, landings, air, lava level), the terrain grid (`grid_before.json`, 1 m)
- [x] plan (this file)
- [x] Blender: loose basalt (`tools/blender/rift_rocks.py` -> `art/models/rift_rocks.glb`: islands, crust plates, shores, stacks, the plinth)
- [x] Blender: the route (`tools/blender/rift_kit.py` + `rift_lib.py` -> `art/models/rift_way.glb` + `rift_way_layout.json`): Lip, Descent, Foot, chapel branch, Cinder Way (two isles, two bridges), Ward Crag + Ward Stair, Ward Landing; reviewed in Workbench renders (`bl/way/`)
- [x] `rift/crossing.gd` rewritten: place the route, materials, collision, fires, sites, flights, lanes
- [x] `rift/features.gd` rewritten: modelled shores, plates, islands, stacks (no code basalt); fissures, vents, ash kept
- [x] `rift/threshold.gd` rewritten: the Watchers on plinths, the chapel; terraces, starfalls, tower stair, Ossuary piers and the box basalt gone (`tower_stair.gd`, `oss_remains.gd`, `basalt.gd`, `crossing.glb`, `terrace_bay.glb` and their kits deleted)
- [x] lava: one element (`lava.gdshader` cooling gradient and the swirl fix, `lava_works.gd` cooling, glow lights, boils, `lava.gd`), heat haze moved
- [x] dependants: camps, bats, minimap, world map, trail lanes, discovery, perf tour, walk probes and the threshold walk test's points; `rift/pit.gd` cuts the rim back from the first landing
- [x] texts: quest, secret, lore, region (section 5)
- [x] walk with the Player (`zz/realm_rift_walk.gd`, the real Player's debug drive, `--realm-modules=land,rift`):
  - rim to the dais: Lastlight's postern, the rim road, the Lip, D1-D3, the Foot, the causeway, both bridges, the Cinder Isle, T1-T4 and
    the switchback landings, the ward landing, the summit's stairs, the Warden's dais: 45 legs, no burns
  - `--stair`: the Lip, the Descent, the Foot, the branch along the wall, the chapel's forecourt, the door, the kneeling stone (floor -11.97)
  - `--lava`: over the causeway to the Cinder Isle and off its open north-east edge into the pool: burned once and given back on the isle
    (on the floor, y -12.42), as everywhere
  - first pass fixes: a 0.33 m lip at every flight's foot and at the Lip's steps (the collision is now one ramp through the tread middles,
    no step-up needed), the branch met the chapel's walled forecourt corner (it now arrives on its east side, where the old quay did)
- [ ] re-shoot once (`after/`) and look at every shot; material side-by-side
- [ ] parse check, `tools/lint.sh`

## 5. Texts changed

| Where | What it said | Now |
|---|---|---|
| `quest_chains_threshold.gd` The Pilgrims' Chapel, offer | "...a chapel where the light falls into the starwater... a stair wound round the third tower of the crossing... a quay... The light comes down across the door like a curtain" | "...a chapel at the bottom of the rift, where the stair comes down off the rim and the fire has gone to crust... the last cool stone before the crossing. A path goes off along the wall to its door..." |
| same, step 1 | "Take the stair round the crossing's third tower down to the starwater, follow the quay, and step through the light into the chapel" | "Take the pilgrims' stair down off the rim to its foot, and the path along the west wall to the chapel's door" |
| `pages.gd` sc_landing (the kneeling stone) | "We cut this where the light comes down... Eleven came back down the tower stair." | "We cut this at the foot of the stair, on the last cool stone... Forty-one of us went over the fire... Eleven came back across the crust." |
| `quest_chains_regions3.gd` The Watch on the Rim | "Go up the Rift's path to the Pilgrims' Threshold"; clue "the chapel under the starfall"; marks "the rim path", "...starwater at its edge" | "Go down into the Rift to the Pilgrims' Threshold, at the foot of the pilgrims' stair"; "the chapel at the stair's foot"; marks on the Cinder Isle, the stair's foot and its first turn ("black crust all the way back to the rim, and the fire coming down the channel under the crag"); the clues and marks moved onto the Foot, the isle and the stair |
| same, Lamps for the Last Mile | the Crossing's foot's clues and the cold lamp out over the old bridge; "a line of sockets down the whole mile" | at the foot of the Ward Stair (the shoes, the candle, the slate); the sockets on the causeway, the isle and up to the rim; the mile ends on the Lip |
| `lore_db.gd` the Ashen Rift | "only its threshold holds starwater. The Crossing is what is left." | "By the threshold it has cooled to a black crust; under the summit it still runs. The Crossing is what the pilgrims cut after: a stair down, a road over the crust, a stair up the crag." |
| `realm_layout.gd` region "rift" | "starwater at its threshold" | "crusted black at its threshold" |
| `realm_discovery.gd` The Crossing | "what the Stair left standing" | "the cinder way to the ward" (its area follows the new route) |
