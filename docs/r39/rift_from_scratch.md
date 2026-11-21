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
 z -71 ...crest spires...+------------------------------+  WARD LANDING x -4..9.6 [25.2] (fixed), beacon; the summit's
                         |  seal (0,-70.9)              |  own stairs go on north
 z -64.6                 +----------- .-exit-. ---------+  vent basin [19.4] behind -> the LAVAFALL down the cleft (x 17.5)
                                    /  WELL-  \                       ||
         THE WARD CRAG             |  shaft r 6.55:    |              ||   east strip of lava
         (modelled basalt)         |  the WARD STAIR,  |              ||
                                   |  2.5 turns round  |              ||
 z -51                              \  an open well   /               ||
 z -48.3 ---------- south face: (W1) .. [DOOR] .. (W2), (W3) high ----||-- the fall's foot, a boil
                (W) Watcher    molten lake       F [-12.4] two fires
 z -37      chapel                        CINDER ISLE [-12.4]  camp, fire
             ^ branch                    / B1
 z -28       |               isle I1 ===/                (E) Watcher, on its plinth in the crust (15, -23.5)
 z -24   L2 [-8.7] --D3--> FOOT [-12.4] ==C1==/            crust plain: the seams thin out southward
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
- **The Ward Stair** (-12.4 to 25.2; round 2b, section 8): wound up inside the Ward Crag. A door in the crag's south face over F, a round
  shaft cut down through the rock (13 m across), 114 steps two and a half turns round its wall about an open well, a fire at the well's
  foot, three windows out through the face with a fire in each. Outside, nothing climbs: a door, three lit windows, the well-head.
- **The Ward Landing** (25.2, fixed): on the crag's top beside the well-head; the summit's own stairs start at its north edge.

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
Side-by-side (`after2/m_side_by_side.png`, from `after2/m23_mat_way_v2` and `after/m24`..`m26`): the Cinder Way's parapet (stone) and
flags (hewn) at the Lip, Hearthward's market cross, the henge's stones, Lastlight's curtain wall.

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
- [x] re-shoot once (`after/`, 26 views: the rim road, the Lip, every landing, the air, lava level, the materials) and looked at every
  shot. What they showed, and what was done:
  - it reads as a new place: from the rim road the Lip's fires, the black plain, the Watchers and the Z of fires up the Ward Crag; from
    the air the molten channel and the pool under the crag, the crust going black towards the Lip (`r01`, `a15`, `a17`)
  - the flags and steps wore the ember rock: a name test took `__ashlar` for `__ash` (fixed: exact set names; the flags and steps are
    now the Realm's `hewn`, the parapets its `stone`)
  - the chasm's haze was still the starwater's violet mist (`l06`, `v19`): now the lava's smoke, ash-grey, lit dull red from below
  - the walk's floor contact lapses going down D2 and D3 at the debug drive's sprint (8.3 m between contacts, `falls_hurt` 0, the legs
    on L2 and the Foot reached at their heights: not a fall). The collision was a slab per tread with an edge at every joint; it is now one
    slab per straight run, and the lapse is the same: the drive's speed down a 26 degree run, not the geometry
  - two lava-level cameras stood inside the Cinder Isle and behind a stack (`v20`, `v21`): moved for the check below
- [x] verification of those fixes (`after2/`, 11 views) and the walk again
- [x] parse check (`tools/parse_all.gd`: 0 bad), `tools/lint.sh` clean
- [x] round 2 and 2b (sections 6 and 8): the lake, the lavafall, the dressing, the plinths, the loading view and the toast; the Ward
  Stair inside the crag; built, then walked and re-shot once (`after5/`)

## 6. Round 2 (Luke, on the shots: "send it back"; the route stays)

| Ask | Done |
|---|---|
| A big lava pit that makes sense: crust only at the village end, a broad molten lake from the Foot north, bright and moving, drifting crust plates with glowing cracks, wall to wall round the islands, brightest under the crag and the summit | `lava.gdshader`: each plate has an id; in the hot reaches about two in three are open lava (swirling with the current, hotter veins, a darker skin that tears, the seam against a raft the hottest) and the rest crust rafts drifting with their glowing cracks; the crust shelf by the rock is a narrow lip in the lake; brighter again under the crag and the summit. `realm_rift.gd`: crusted south of z -16, molten north of z -30 (from the Foot on). Islands spread through the lake at least 8.5 m apart |
| The lavafall out of a cleft in the Ward Crag, reading from the rim as the source | `rift_kit.py` sec_fall: a basin at a vent on the crag's south-east shoulder, a channel to the lip, a chute cut down the corner between two basalt cheeks (the "ash" rock, glowing in its cracks along the fall), the falling sheet (40 m, LavaWorks' fall shader: crawl in the channel, a rush with crust rafts past the lip). Vent embers and smoke; a boil and splash at its foot; two of the lava's glow lights moved onto the fall's foot and the crag face beside it (no new light) |
| No loose white cubes; dense modelled dressing | the Watchers' model rubble (plain boxes) dropped; `rift_rocks.py` boulders, cooled spatter, heaved crust slabs; `features.gd` crowds the walls' feet every metre or two and rings every island, the Watchers' plinths, the way's isles, the Foot and the crag's foot (MultiMesh a variant, no collision); shores every 5-8 m |
| The Watchers' plinths meet the basalt | the pillars sit 0.18 m into the basalt table (no daylight under a tread) |
| The loading view by the Spindle; the pool's toast | the view stands at the Ward Stair's door, the lavafall beside it (round 2b); "The dark water gives you back." |

## 8. Round 2b: the Ward Stair inside the crag (Luke: "why are there stairs going back and forth so high")

The four traverses stacked up the crag's south face (30 + 30 + 30 + 23 steps, three switchbacks) are gone. Of the three ways offered:

- **(a) climbing gradually along the rift.** The end is fixed 37.6 m over the Foot and the way from the Foot to the crag is about 55 m
  long. To spread the height over it the causeway would leave the Foot already rising 1 in 1.5 and stand 15-25 m over the lake by the
  Cinder Isle: round 1's "make the platforms lower" undone, and the bridges would be viaducts on piers again (the Crossing he rejected).
- **(b) one grand straight stair.** 114 risers at 0.68 m treads is a 77 m run (about 90 m with landings): longer than the crag is deep.
  It would start back at the Foot and fly over the lake on arches, a 37 m ladder seen side-on from the rim: the very mass he objected to.
- **(c) chosen: the stair inside the crag.** From outside nothing climbs: the crag shows a door at the foot of its south face, three lit
  windows and the well-head on its top. Inside, a round shaft 13 m across, cut down through the rock, with the stair wound two and a half
  turns round its wall about an open well: 114 risers of 0.33 m, treads 0.66 m at the walk's middle, 3.1 m clear, a parapet on the well
  side, the first turn's treads standing on solid masonry down to the floor. A fire at the well's foot (seen from the well-head 37 m
  down), a lit fire in each window. The windows look out over the lake at 1, 4 and 18 m. It keeps the way low over the lava, the end
  height and the rest of the route as they were, and turns the climb into the set piece.

What changed with it: the lavafall's cleft moved east (x 13 to 17.5) so the shaft's wall stays whole, with the two glow lights and a
boil; the climb's foot F is now a forecourt before the door (B2 lands on it); the ward landing widened east to the well-head (x -4..9.6),
the stair's top flat opening onto it through a gap in the well-head's parapet; the crag's skyline broken with teeth and knuckles.
Systems: the stair's collision is one helical ramp through the tread middles (no lip anywhere), a body per turn so the trail's ray
seats every turn; its lane goes round the helix and the landing's lane starts more than 5 m from every turn (no route jumps a turn);
the quest pins that stood on the traverses moved onto F, the Foot and the landing (section 5); bats over the well-head.

**The lake, looked at again.** From the air the lake read as dull ground with lava in patches. It was not the shader: drawn flat green,
the lava sheet showed only in those patches, so rock stood over the rest. The Watchers' plinths were basalt tables 18 m across, the
roughened feet of the Descent's ledge and the causeway's isles bulged 2-3 m out at the waterline, and the crag's foot stood in the pool
as sixteen blocks. Now: the plinths are just wide enough for the pillars' own 7 m bases (`rift_rocks.py`), every rock mass keeps within
0.45 m of its blocks at the lava (`rift_kit.py` `_waterline`), the crag's foot is nine blocks close in, two islands and three crust
rafts instead of six and six. The lava's bank map (the crust shelf and the bright contact line along the rock) cast its rays from 1.2 m
over the surface, inside every thick rock, and found almost no bank: they start 6 m up now (`lava_works.gd`).

**Walk and shots (built first, then tested once).** `zz/realm_rift_walk.gd` with the real Player:
- rim to the dais: the Lip, the Descent, the causeway, F, in at the door, 60 legs round the shaft to the top flat (no drop of more
  than a metre on the stair), the ward landing, the summit's stairs, the Warden's dais: 90 legs, no burns
- `--stair`: the branch to the chapel door and the kneeling stone (floor -11.97); `--lava`: off the Cinder Isle's open edge, burned once
  and given back on the isle
- re-shot once (`after5/`, 32 views: the 26 with the climb's six replaced by the door, the well's foot, a window, high on the stair,
  the landing back and up; the three of the fall and the lake; three of the crag from the lake, the well-head, mid-stair). From the rim
  and the lake the crag shows the door, the lit windows and the lavafall, no stairs; the window looks out past its fire to the west
  Watcher; the well reads as a spiral to the sky from its foot.

## 9. Round 2c: a wider pit, a heavier fall (lead: "from the air the lava is a small patch round one Watcher")

- **The floor widened.** `rift/pit.gd` draws the east wall back 11 to 15 m (lobed) from the crust plain's north end (z -12..-22) all the
  way to the summit's approach, joining the bowl that already opened north of z -51. The lake's east shore moves from about x 19 to
  about x 31 (the kept core reaches x +30): the floor under the lava from ~32 m to ~45 m across, molten wall to wall round the isles and
  the causeway. The west wall stays: the Descent's ledge, the Foot, the branch and the chapel are built into it. Nothing within 9 m of
  the centreline moves (the Lip, the rim road); the old Ossuary's site on the east wall is bare rock (RealmLayout.OSSUARY_OLD); the
  summit and the ward are north of the bowl's closing. The bed is the old chasm's floor (-18 to -21), under the lava everywhere.
- **What follows the new bowl.** The lava sheet (92 m) and its kill volume already reach x +46; the bank map, the shores, the walls'
  dressing and the falls read the ground; the islands' area and the crust rafts' reach east into the new lake; the heat shimmer covers
  it; a glow light and a boil over the east lake; the rim's spatter and the east fissures stand on the moved lip (`rift_rim.gd`,
  `features.gd`), and the scorch's burn follows it (`scorch.gd`). The Cinder Isle's camp and the rim camps are where they were.
- **The lavafall.** A 3 m sheet at the vent, 4.6 m at the lip, 5.6 m at the foot (it was 1.6 to 3 m), in a cleft as wide; a splash
  pool at its foot: a low broken rim of spatter round where it lands, glowing along its lip, open to the lake; droplets thrown up and
  falling back, a hot veil and fumes over it (`crossing.gd`), the boil and the brightest glow light there.
- **The crust.** Crusted black only under the Lip now (COOL_Z -13), molten from the Foot north (HOT_Z -22): the crust had covered the
  lake's whole south third, and in the new east bowl it read as a red plain.
- **Walk and shots.** Built first (the way in Blender, the import, the parse check), then walked once: rim to the dais 90 legs, no
  burns; the chapel branch to the kneeling stone; off the Cinder Isle into the lava, burned once and given back. Shot once (`after6/`);
  the cooling constants were then moved (no change to anything walked) and the views shot again (`after7/`). From the air (`a15`, `a17`)
  the lake now runs molten from the causeway to the east wall (x 9..30) and round the west Watcher, the crag standing in it with the
  lavafall pouring broad down its south-east corner (`f27`, `f28`, `r01`, `r03`); the dark left in `a17` is the west side's built rock
  (the Descent's ledge, the Foot, the branch, the chapel) and the east bowl's slope above the shore.

## 7. What is left

- **The lake's west half** between the Foot and the west Watcher is still mostly the Descent's and the branch's rock (by design: the west
  wall carries the ledge, the Foot and the chapel). If more lava is wanted there, the branch could run on a narrower base.
- The east bowl's new wall is a long even slope in the kept core's blend band (x 30..45): reads as a red bank from low on the Way.
- `c31_well_down` frames the top flat, not the well (the camera sits over the well's north edge): the well from above shows in the
  Blender review (`bl/way10/rift_way_6`) and from below in `l10`.
- Not run: the test suite (the lead runs it after merging).

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
| `quest_chains_regions3.gd` The Watch on the Rim, marks 2 and 3 (round 2b) | "The stair up the crag... on the first step, going up"; "The first turn of the stair... the fire coming down the channel under the crag" | "The door into the crag, and the stair wound up inside it... on the threshold, going in" (on F); "The well-head on the crag's top... the fire pouring out of the crag's side into the lake. The wind comes up the well..." (on the ward landing) |
| same, Lamps for the Last Mile (round 2b) | the shoes "at the foot of the crag's stair", the candle "in a niche", the slate "nailed to the rock" up the first traverse | on F before the door: "at the crag's door", "in a gap of the parapet", "nailed to the rock beside the door"; the cold lamp on F |
| `quest_chains_story.gd` The Third Edict (round 2b) | the scribe's desk, the edict stones and the vigil on the traverses ("the scribe's desk at the Crossing's foot") | on the ward landing: "the scribe's desk at the stair's head"; the wax tablet mark on the bridge to F |
| `quest_chains_wanderer.gd` The Last Ringer, `story_texts.gd`, `village_cast_wanderer.gd` (round 2b) | the last bell's stone and Iorweth's spot on the second switchback | on the Foot ("the Crossing's foot, where there is a stone with a name on it"): unchanged words |
