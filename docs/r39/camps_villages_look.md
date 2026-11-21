# r39 camps and villages look: live checklist

Brief: `docs/r39/briefs/camps_villages_look.md`. Luke, 21 Nov: "the world is unpolished, so many map pieces just have objects randomly placed" ... "The biggest thing is you need to fix camps and villages".

## Tools
- `zz/ground_shots.gd --look=camps,towns,posts,outposts|all [--look-ids=n,.. | --look-names=a,..] --out=dir --tag=before|after`: six views per place, five under a **review light
  rig** (a shadowless sun and a fill lamp on the camera, added in this tool only, never in the game) and one normal night view: 0 approach at 1.7 m, 1 and 2 three-quarter from two
  sides, 3 inside the centre, 4 high, 5 the night. No camera in a wall (nothing within 1.4 m of the eye, nothing in the first 3 m of the line, the target seen). Writes `looks.txt`
  (number -> place), `lk_<n>_<view>_<tag>.jpg` and `strip_<n>_<tag>.jpg`; the after run reuses `spots_used_before.json` with `--no-fx --spots=` so the cameras are identical.

## Done
- [x] Shot every camp (EnemySpawner.REALM_CAMPS + the Reaches': 85 of them outside the Ossuary and the Rift), the 11 settlement places, the 4 watch posts (96 + 11 places, 6 views each).
- [x] Critique (below).
- [x] `core/world/realm/camp_dress.gd`: every camp dressed by what it is, once the spawner has settled it on the final ground (`EnemySpawner._camp_view` -> `CampDress.build`).
- [x] Blender kit `tools/blender/props_camp.py` -> `art/models/props/camp_*.glb` (nine models, render-reviewed).
- [x] `settlement_yards.gd`: yards are anchored to a house (see below).
- [x] The floating lit barrel: found and fixed (see below).
- [ ] Re-shoot of the changed places (one run) and the before/after pairs.

## What the audit found (the rules that made the scatter)
1. **Enemy camps had no dressing at all** (only the Marches' seven had a lean-to and a cold ring). 85 of 85 shot places were bare ground with foes on it; wayside, site_dress and the
   region builders all keep OFF a camp (KEEP_CAMP), so nothing was ever built for one.
2. **Yards were random** (`settlement_yards.gd`): a random angle and radius in the town's disc, a random heading, a kind cycled through a list: pens in the green, a smithy facing nothing,
   washing lines behind nobody's house. Saltmarket, Weirford and the Holds had no yards at all.
3. **The Reeds' yard barrels (and every upright lore barrel: cottages, the old forge)** were merged into the lore kit's mesh on the build's ground; `TerrainStamp.settle` then lowered the
   yard by 0.9 m and the barrel hung in the air with its embers. That is the floating lit barrel by the Almonry (Hearthward east): `lore_kit.gd barrel` (the cottage and the Reeds' yard
   barrels) now batches the modelled barrel into a MultiMesh in group `final_seat` (`lore/lore_barrels.gd`), which `FinalSeat.settle` puts on the ground the settle leaves.

## The new placement rules
- **Camps** (`camp_dress.gd`): the archetype comes from who is in the camp (a seal: post; pilgrims/ossuants: vigil; mostly beasts: den; a patrol's home: halt; else bivouac, with a lookout
  and a palisade when it is big or armed). Everything is placed on rings round the fire, turned to it: seats on the fire's ring, tents behind it (opposite the way in, bedrolls under them), the
  store and the cart beyond, the rack and the lookout on the approach side, the palisade either side of a gap where the way comes in. Every spot is tested (ground, water, a way, a site, a slope,
  a collider, the foes' places and patrol line, the camp's own footprints) and a prop that finds none is dropped. Flames and coals are the glow shader and flame cards with **no light**
  (no new lights, none shadowed); visible from 380 m. Static: one WonderKit per 96 m cell, props fade at 150 m. `--no-camp-dress` turns it off.
- **Yards** (`settlement_yards.gd`): a yard belongs to a house: against its back (the side furthest from the lanes, the walks and the ways), 4.9 m out from the wall, its x along the wall and its
  +z turned away from it; the house's own site is allowed 2 m of berth, every other 3.6 m, and the walks and lanes stay clear as before. Saltmarket, Weirford and the Holds get yards.
- **Barrels** (`lore_barrels.gd`): see above.

## New models (Blender, `tools/blender/props_camp.py`, in `art/models/props/`)
| model | what | tris |
|---|---|---|
| camp_tent | lean-to of canvas on a ridge pole and two forked posts, guys and pegs, a closed end | 248 |
| camp_bedroll | mat, folded blanket, rolled pillow | 168 |
| camp_rack | weapon rack: two A-frames, two bars, five spears, two round shields | 316 |
| camp_spit | the cooking place: nine stones round the ash, lashed tripod, chain, iron pot | 378 |
| camp_watch | lookout: splayed braced legs, railed platform at 3.6 m, ladder, pitched roof, lantern hook (6 m) | 972 |
| camp_stakes | palisade bay: seven sharpened stakes lashed to two rails, braces | 288 |
| camp_hides | drying frame with two stretched hides | 168 |
| camp_den | beasts' den: leaning branches and ribs over a hollow, bones | 354 |
| camp_log | a sitting log | 104 |

## Critique: settlements (before)
| place | what was wrong | what changed |
|---|---|---|
| Hearthward square (000) | a designed square (cross, stalls, well, gate, lamps); views 1, 2 and 5 put the camera in a wall: a tool fault, fixed | none needed |
| Hearthward east / Almonry (001) | the floating lit barrel behind the Reeds' house; house backs bare | barrels grounded (final seat); yards anchored to house backs |
| Hearthward Keg (002) | reads as designed (the barrels were seated last round) | none |
| Reedholm (003) | stilt houses read; the ground between them bare, decks with nothing on them, yards in the reeds | yards anchored to the (non-stilt) houses that have a back; the town's own clutter list is kept |
| Fallowmere (004) | farm cottages and the barn read; the green and the strips empty, yards scattered | yards anchored to the cottages' and farmhouse's backs |
| Fallowmere barn and farm (005) | barn and farmhouse fine; the yard scenes round them faced nothing | anchored yards |
| Lastlight (006) | walled town, designed, lit; yards random inside the walls | anchored yards |
| Weirford (007) / inn and smithy (008) | leaning black boards by the walls (kit rail stubs), barrels and crates dumped on the bank, no yards | yards anchored to the inn, smithy, mill house and watch hut |
| Saltmarket (009) | the square is bare gravel with props only at its edges; nothing behind the houses | yards anchored to the houses |
| Rooted Holds (010) | the outpost clearing | yards on the houses' backs |
| watch posts (096-099) | designed (post, lantern, tabard); the Saltmarket post sits in the saltworks | none |

## Critique: camps (before; one line per place, numbers are `looks.txt` numbers)
| # | camp | what was wrong | what changed |
|---|---|---|---|
| 011 | -46,20 (henge) | a seal's guard stood on bare ground: no post, no fire, nothing to say what they guard | post: fire in a stone ring, seats, tent, two weapon racks, lookout on the approach, palisade either side of the way in |
| 012 | -26,-9 (henge) | a seal's guard stood on bare ground: no post, no fire, nothing to say what they guard | post: fire in a stone ring, seats, tent, two weapon racks, lookout on the approach, palisade either side of the way in |
| 013 | -152,-38 (bulwark,chanter) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 014 | -104,28 (leaper,husk) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 015 | -80,-88 (mite,mite) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 016 | -66,24 (wretch,spitter) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 017 | 94,-10 (ossuant,wretch) | pilgrims standing in a field: nothing says why they wait | vigil: a ring of headstones turned inward |
| 018 | 86,-75 (burrower,spitter) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 019 | 63,18 (wretch,leaper) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 020 | 70,2 (husk) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 021 | 43,-6 (wretch,crawler) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 022 | 99,-34 (ossuant,ossuant) | pilgrims standing in a field: nothing says why they wait | vigil: a ring of headstones turned inward |
| 023 | 60,-68 (bulwark,quiller) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 024 | 80,49 (chanter,husk) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 025 | 275,-10 (quiller,leaper) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 026 | 356,-10 (wretch,crawler) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 027 | -111,-99 (husk,leaper) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 028 | -139,-89 (leaper,husk) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 029 | -119,-116 (husk,husk) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 030 | 137,-98 (bulwark,cinder) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 031 | 115,-102 (cinder,wretch) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 032 | 141,-51 (gaunt,gaunt) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 033 | 142,32 (gaunt,crawler) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 034 | 144,2 (husk,wretch) | a patrol's home was a patch of grass: no fire, no rest place, no reason to be there | halt: ring fire with spit, two seats, a bedroll, a small store |
| 035 | 137,102 (spitter,husk) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 036 | 118,144 (husk,spitter) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 037 | 118,108 (spitter,spitter) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 038 | 132,58 (chanter,husk) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 039 | -164,-62 (leaper,wretch) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 040 | -140,56 (wretch,crawler) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 041 | 126,214 (gaunt,leaper) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 042 | -240,-10 (husk@drowned,spitter) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 043 | -178,-50 (crawler,gaunt) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 044 | -187,-102 (husk@stonebound,bulwark@stonebound) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 045 | -240,168 (husk@stonebound,bulwark@stonebound) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 046 | -240,218 (leaper,husk) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 047 | -216,226 (gaunt,gaunt) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 048 | -196,228 (cinder,bulwark) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 049 | 172,-36 (husk,spitter) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 050 | 246,-28 (gaunt,wretch) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 051 | 188,44 (spitter,husk) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 052 | 228,-18 (gaunt,spitter) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 053 | 229,-72 (bulwark,chanter) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 054 | 246,-65 (bulwark,quiller) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 055 | 184,-60 (leaper,gaunt) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 056 | 170,122 (wretch,crawler) | foes standing on grass: no fire, bedding, store or lookout; a scatter of nothing | bivouac: spit fire in a stone ring (banked flames, coals), seats, lean-to tent(s) with bedrolls, store, rack if armed, hides in the woods, a cart |
| 057 | 178,196 (burrower,burrower) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 058 | 246,118 (cinder,wretch) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 059 | 210,214 (husk,husk) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 060 | -326,-70 (the keep's gate) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 061 | -342,-90 (the keep's west bailey) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 062 | -276,-96 (the scree east of the crag) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 063 | -298,-86 (the fell watch) | a patrol's home was a patch of grass: no fire, no rest place, no reason to be there | halt: ring fire with spit, two seats, a bedroll, a small store |
| 064 | -346,-34 (the deep wood's nest) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 065 | -282,-30 (the wood's north edge) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 066 | -356,58 (the Last Milestone) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 067 | -312,42 (the road's last stretch) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 068 | -311,170 (between the barrows) | pilgrims standing in a field: nothing says why they wait | vigil: a ring of headstones turned inward |
| 069 | -294,134 (the stone row) | pilgrims standing in a field: nothing says why they wait | vigil: a ring of headstones turned inward |
| 070 | -296,196 (the ridge's south shoulder) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 071 | -338,178 (the ridge round) | a patrol's home was a patch of grass: no fire, no rest place, no reason to be there | halt: ring fire with spit, two seats, a bedroll, a small store |
| 072 | -352,250 (the north meres) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 073 | -252,352 (the east reeds) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 074 | -262,318 (the ford's far bank) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 075 | -196,366 (the far fields) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 076 | -186,250 (the waste under the scarp) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 077 | -212,314 (the ford road) | a patrol's home was a patch of grass: no fire, no rest place, no reason to be there | halt: ring fire with spit, two seats, a bedroll, a small store |
| 078 | 30,368 (the valley under the arches) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 079 | 58,284 (the broken span's rubble) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 080 | -30,354 (the west piers) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 081 | 14,332 (the valley road) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 082 | 120,268 (the burners' clearing) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 083 | 252,293 (the holly brakes) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 084 | 243,260 (the wood's north-east edge) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 085 | 174,384 (the deep wood's nest) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 086 | 332,110 (the crater's west lip) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 087 | 334,125 (the crater's east floor) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 088 | 250,-48 (the round below bell_link) | a patrol's home was a patch of grass: no fire, no rest place, no reason to be there | halt: ring fire with spit, two seats, a bedroll, a small store |
| 089 | 268,16 (under the rift's west berm) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 090 | -268,74 (the road west of Weirford) | a patrol's home was a patch of grass: no fire, no rest place, no reason to be there | halt: ring fire with spit, two seats, a bedroll, a small store |
| 091 | 349,127 (the nave's east shore) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |
| 092 | 298,212 (the nave's south shore) | pilgrims standing in a field: nothing says why they wait | vigil: a ring of headstones turned inward |
| 093 | 346,270 (the north cairns) | pilgrims standing in a field: nothing says why they wait | vigil: a ring of headstones turned inward |
| 094 | 302,368 (the south cairns) | beasts on open ground, no den, no bones: a spawn point, not a lair | den: a branch-and-rib den (two for a big pack) behind the foes, away from the way |
| 095 | 350,338 (the windward cairns) | a war band on bare ground: no fire, beds, lookout, palisade or store; it read as a spawn point | bivouac + lookout on the approach + palisade bays round the way in |

## Outposts
The outposts (`village_props.outpost`: a fire, a seat, the region's dressing) could not be shot before the build: the shot tool listed them at (0, 0) (fixed in the tool afterwards:
`village.outpost_at`) and a before pass was not allowed once the build had begun. They are left as they were.

## Before / after pairs
(filled after the one re-shoot)

## Left
(filled at the end)
