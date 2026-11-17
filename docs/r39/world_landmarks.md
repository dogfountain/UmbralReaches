# The world pass: landmarks, ground and surfaces

Luke, 17 Nov: bigger set pieces you can walk inside and on top of, each with its own light and a reward; terrain that
is no longer soft dunes; each region its own flower; "increase model detail at no perf cost". Everything below is in the
game, built at Realm build time by the existing wonders stage (`core/world/realm/realm_wonders.gd`, before the terrain
stamp, the flora, the dress and the nav bake), so the flora keeps off every site, the ground settles to the floors and the
nav mesh includes the stairs and decks. Nothing runs per frame. No new asset files: all geometry is the OssKit's boxes
(one mesh per material, collision from the same faces) and prisms from the new `wonders/r39/wonder_kit.gd`.

Exact positions are chosen at build by `WK.find`/`find_any` (flattest open ground that touches no town, way, other region
or registered site, relief limits eased pass by pass so a landmark always exists). Each prints one line:
`WONDER <name> at (x, z) ...` in the engine log: read those for the capture coordinates. The search areas are below.

Shared: `wonders/r39/wonder_kit.gd` (finder, tubes, beams, fire = two flame cards + halo + one unshadowed light that
fades from 70 m, lit window glass, chests, discovery banner), new OssKit materials `stone_big`, `ruin_big`, `brick_big`,
`wood_big`, `bark`, `chalk` (the masonry scale tier: a colossal work's courses are 2-3 times a house's).

## The ten features

1. **The Sleeper** (`the_sleeper.gd`): an 80 m colossus on its back in the Kings' Barrows (search around (-326, 118..196);
   fallbacks in the Long Arches at (-30, 350)). Legs, hips, a hollow torso (the heart-hall: a furnace on a dais, a reliquary
   chest, lit slits), a wound in the east flank with a stair from the ground, two flights inside the chest up to the roof
   deck (three oculi), a neck stair to the head (lit eyes, a 9-spike crown, two horns), the right arm out 34 m across the
   heather as a bridge to an open hand holding a bonfire (an iron chest), a fire on the crown, a beacon over the face.
   From afar: crown spikes, a bonfire cupped in a hand, a shaft of light. ~230 boxes, one mesh per material; 3 chests, ~14
   lights (each fading 38-70 m), 6 fires.
2. **The Hollow King** (`hollow_king.gd`): a dead oak 44 m tall in the Southwood (search around (170, 340)); terraced flat.
   Bark-faceted trunk 16 m round at the root, a doorway to a hollow hall (fire, root seats, a reliquary chest), 8 buttress
   roots, four walk-in root houses with lit windows, a 28-flight railed stair winding to a deck in the fork (cresset fire, a
   reliquary chest), nine forking limbs hung with lanterns, a beacon on the crown. 4 chests, ~18 lights.
3. **The Salt Ship** (`salt_ship.gd`): a 44 m two-masted merchantman stranded on the White Pans (search around (214, 196)),
   heeled 9 degrees, planked in 23 stations x 4 strakes with rotted gaps and ribs showing, a deck with an open hatch, a
   plank ramp to a breach in the low bulwark, a stern castle with a cabin (lit stern windows, an iron chest), a stern-lantern
   fire 14 m up, the mainmast stub with a yard, a torn pale sail and a masthead lamp, a hold with a stair, lamp and reliquary
   chest, salt drifts and timber shores. 2 chests.
4. **The Wardens' Line** (`wardens_line.gd`, `wardens_cresset.gd`): six 12 m keep towers 30-45 m off the Pilgrims' Road at
   x = -338, -232, -128, 124, 226, 330 (west to east), each with a door facing the road, lit slit windows, a hall with a
   chest, four flights wound round the inside, a crenellated roof. The cresset on each roof is COLD until the wanderer lights
   it with E (saved in `Travel.system_state("r39_wardens")`): flame, warm lights and a far beacon switch on, a cold pilot
   glow switches off. Lighting all six pays out once (40 ash, 5 iron, 3 relic fragments) with a toast. The sixth tower holds a
   reliquary chest. Unlit, a tower costs a few meshes and one fading pilot light.
5. **The Chain Span** (`chain_span.gd`): a 56 m chain bridge between two gate pylons (9.5 m piers, a lintel, a fire on each
   pier head: four fires), found by scanning the Far Reaches (outside the old Marches) for the deepest gulf; deck of boards
   sagging 2.4 m, four iron cables in 24 prisms with hangers, rails, lanterns every 8 m, a midspan platform (keeper's
   brazier, bench, an iron chest) and a toll hut with a chest at the west gate.
6. **The Titan Gates** (`titan_gates.gd`): before each raid floor (the Thornwarden's henge, the Hierarch's ring, the
   Anchoress's terrace) two 20 m stone wardens stand 13 m outside the gate, 14 m apart: plinth, body, belt, chest, arms, shield
   facing the approach, a spear to 22 m, a helm with a crest, lit eyes, a fire in a bowl on the head. Boss-scale
   architecture: the 7.6-8.8 m bosses read against figures three times their size.
7. **The Hermit Caches** (`hermit_caches.gd`): sixteen small places 45-140 m off every way, each marked by a 7 m pole with a
   lit lantern, each with an iron chest (ash, iron, now and then a relic fragment): a lean-to camp, a stone cell with a lit
   slit and an altar, or a ring of five menhirs round a fire. Spread at least 90 m apart; each a discovery; each its own kit
   (culls on its own, fades at 200 m).
8. **Benches and scarps** (`terrain_benches.gd`, hooked in `RealmLand._heights`): the Far Reaches' soft dunes are stepped in
   noise patches (about 2 m benches, flat treads and steep short risers), kept off the ways (30 m), towns, named circles and
   water; feathered over 20 m at the Marches' border. Pure math on the height grid: no triangles, no draws, no memory.
9. **The Outcrops** (`terrain_outcrops.gd`): up to 90 stratified cliff faces (RockKit.cliff: cached, LOD'd, convex collision)
   stood on the steep risers of the Far Reaches, turned downhill, trees kept off, faded at 170 m, style by biome.
10. **Region flowers** (`flora_signature.gd`, one line each in `realm_flora.gd` and `flora_layers.gd`): the flowers' colour
    is a per-4 m-cell multiplier by region (Lanternwood cold blue bells, Southwood rust, Fallowmere poppy red, Reedmere marsh
    gold, Cairns pale grey-white, Nave sick teal, Kings' Barrows ling pink, Greyfell snow-white, Arches broom yellow,
    Lastlight cream, the glade moon-white, the moor gorse gold, the holds heather magenta, the barrow fen marsh blue).
11. **Weathering everywhere** (surfaces, free at runtime):
    - `OssKit._grime`: every kit's masonry gets a slow world-position patchwork (+-7 % tone drift, warm/cool shift, moss on the
      up faces where it is damp). The kit already had chamfered arrises, contact AO and per-block tone; this adds the macro
      scale across big walls.
    - `prop_weather.gd` (hooked in `StoneProps.info`): every modelled prop part gets contact dirt at the foot (66 %), dark
      undersides (72 %) and a moss cast on its tops baked once into vertex colour (the prop materials use it as albedo).
    - `tree_gen.gd`: the oak-family crown colour leans yellow-green on the sunlit tops and cool blue-green in the core.

## Cost estimate

CPU at build: finder searches are a few thousand height lookups; each landmark builds 200-1,500 boxes (tens of ms,
GDScript) once, on the build thread, inside the wonders stage; the benches add one noise read and one cached path distance
per height-grid vertex (about 100k; cached with the heights). The 90 outcrops build ~32 cliff meshes (cached on disk by
RockKit). The land cache fingerprint covers `core/world/realm/**`, so the first run after this rebuilds the heights once.
GPU: the colossal landmarks are one mesh per material each (about 8 draws apiece), always drawn when in the frustum (they
are skyline landmarks); the small places fade at 200 m; towers cull on their own. Lights: every fire/lamp is unshadowed
with a distance fade (38-70 m), tagged `light_class lamp` so the light policy sees it. Memory: a few MB of vertex data. No
per-frame work anywhere except the existing flame shader on the flame cards.

## What the lead must check in the engine

`godot --headless --path . --import --quit` first (new scripts need their .uid files). Then read the `WONDER ...` log lines
for coordinates and capture:
- the Sleeper (Kings' Barrows, west): from the road at (-300, 56) looking south-west; then the wound's stair, the heart-hall,
  both interior flights to the roof, the neck stair, the arm bridge to the hand. Check the floors (no gaps at the stair ends),
  that the head's eyes read from above, and that nothing overlaps the Barrows set pieces.
- the Hollow King (Southwood, south-east): the doorway and hollow, the 28-flight stair (rails, no snags on the houses), the
  crown deck; check the terrace (26 m) is flat and trees around are not through the houses.
- the Salt Ship (White Pans): the ramp, the hatch stair, the stern roof steps, the heel (9 degrees: footing must hold).
- the Wardens' Line: all six towers (and that each found ground off the road); light one (E on the roof cresset) and check
  the fire, the beacon, the toast; light all six for the payout; reload and check they stay lit.
- the Chain Span: deck continuity, the end stairs, the midspan chest; find it from the log line.
- the Titan Gates at (-56, -16)+13 m (henge), (-182, 159)+13 m (Hierarch), (206, -114)+13 m (Anchoress): clear of the arena
  gate and its barrier, not on the road.
- Hermit Caches: count in the log (target 16), a few spot checks; lanterns visible from 100 m at night.
- Benches/outcrops: Far Reaches ridgelines at (-320, 120), (160, 340), (320, 300); the roads at their edges must stay level.
- flowers per region; props (the Hearthward gate, forge, well, carts) for the foot dirt; kit walls for the patchwork.
- Perf: the hearth, road and Southwood captures against the numbers in `scratchpad/play/regions_a/perf.txt` (avg 8.5 ms).

Not done here (other seats): lore texts for the new places (the story agent), global lighting and the beacon system (the
light agent), the dither on far leaf cards (shader work in `realm_foliage.gdshader`, not touched).

# Second pass (branch r39-world2)

## The compass
Rebuilt as a relevance filter (`ui/compass_feed.gd`, `ui/compass.gd`, setting in `ui/hud_prefs.gd` and the Display page):
see `docs/r39/compass.md`.

## Deeper models: what was reworked
Secondary and tertiary forms, all build-time geometry (no runtime cost beyond triangles, nothing per frame):
- **Landmarks** (Sleeper, Hollow King, Salt Ship, Wardens' towers, Chain Span, Titan Gates, hermit caches): `wonders/r39/wonder_dress.gd`
  adds rubble heaps, sagging ropes and chains (catenaries in short prisms), hung linen banners with bands and torn hems,
  hanging root-and-ivy strands, barrels and crates, looters' camps, carved bands, cracks. Wonder kits also set `OssKit.relief`:
  every face over 1.2 m both ways is cut into ~1.6 m ashlar cells proud of a darker recessed base (0-5 cm, own tone), so the
  colossal masonry reads as cut stone. Collision is unchanged (the plain boxes).
- **Roadside stories** (`wonders/r39/roadside_tableaux.gd`): 30 scenes beside the ways (overturned cart with an ox's ribs, shrine
  with candles and offerings, gibbet with a caged lantern, toll post, abandoned camp, pilgrim cairn hung with lanterns).
- **Bosses** (`core/enemy/warden_body.gd`, `crown_body.gd`, `thorn_body.gd`, `anchoress_body.gd`): tassels, shoulder plates, robe
  embroidery bands, hem bells and mandorla beads (Warden); bronze bands, studs, bells, lichen, a chipped hem and prayer cords
  (Crown); ridged bark plates, moss strands, bracket fungus, root wraps and knee thorns (Thornwarden); padlocks, prayer
  ribbons and a rosary on the chain windings (Anchoress). Rigs, bones and gameplay sockets are untouched: only primitives bound
  to existing bones were added.
- **All kit masonry in the game** (towns, ruins, the Ossuary): the macro tone and moss patchwork in `OssKit._grime`.
- **All modelled props** (Hearthward's gate, forge, shrine, well, market, carts): contact dirt, dark undersides and moss tops
  in `prop_weather.gd` via `StoneProps.info`.
- **Trees**: sunlit crown tops.
Reviewed and left as they are: the enemies' procedural bodies (`enemy_body.gd` already carries ribs, tatters, girdles, beads,
wraps per kind) and the villagers' and dwarves' mesh builders (the animation agent is in `villager_rig.gd`; no posing or
mesh code was touched there). The Bone Abbot already carries a rosary, tally bones, candles and a crozier of vertebrae.

## World
Roadside stories (above). Check in the engine (the log prints `WONDER roadside_tableaux: N scenes`, expect about 30): walk the
Pilgrims' Road from Hearthward west to (-300, 56) and east to (300, 70), the fell track, the barrow track, the Brine Road;
look for scenes 8-13 m off the way, none on a road or inside a town, each with its light visible at night; the chests (every
third scene) open once; scenes fade at 200 m.

# Third pass: the backlog, the perf rule, and what each item costs

**The rule (Luke: "this must be at no perf cost").** Everything below is built once at Realm build time. Offsets used everywhere:
- `wonder_kit.gd`: every fire is two flame cards + a halo recorded and committed as **one MultiMesh (flames) + one per halo size per
  kit** (no node and no draw per fire); only the toggled Wardens' cresset keeps its own nodes. A global **light cap of 72**
  (`WK.LIGHT_CAP`): past it a lamp or fire is glass/flame only. All lights unshadowed, tagged `light_class lamp`, with distance fades
  (lamps 38 m, fires 70 m).
- Big kit meshes (over 18,000 vertices) get **LODs** (`MeshChunks.with_lods`, build time), so relief and ornament cost less the
  farther they are; `WK.far()` swaps a tower or ship for a 12-triangle hull beyond 150 m (flames and glass stay).
- Small scenes fade out (dither) at 110-150 m and are **built per cell** where dense (yards per 56 m, region props per 96 m, outcrops
  as MultiMeshes per mesh and 96 m cell), so draws per region in view stay at a handful of material meshes per cell, not per prop.
- Underground complexes (halls 120 m, caves 110 m) are culled by range; the surface gates are part of them.
- Net effect per region: landmarks add their material meshes (about 8 each) only in their own region's frustum; every other family
  trades its draws against merged cells. The lead measures; anything that regresses is to be tightened with these same levers.

## New items (all in `core/world/realm/wonders/r39/` unless noted; each logs a `WONDER ...` line with its coordinates)
| Item | What | Where | From afar | Cost and offset |
| --- | --- | --- | --- | --- |
| Deep halls (`deep_halls.gd`, `dungeon_kit.gd`) | King's Undercroft, Castellum Cisterns, Witch's Cellar, Nave Crypt: a stair cut down the hill (WorldLanes flight), a surface gate with two fires, and 7 rooms each (antechamber, pillared hall, two side rooms, end room, a hidden room): sarcophagi / flooded cistern with a plank walk and pump wheels / roots, herbs and a cauldron / knee-deep water and a light well; 3 chests each (reliquary at the end, iron hidden), sconces and fires, group `deep_hall` with `reward_at` / `threshold_at` for the story seat | near (-334, 118), (-60, 365), (226, 340), (300, 190); exact from the log | gate fires | ~50k triangles each with relief, LODs over 18k vertices, fade 120 m; 2-3 merged flame MMs; lights capped |
| Caves (`caves.gd`) | 7 caves: crystal, root, bat, drowned, ember, bone den, fungus; stair, mouth boulders, 3 chambers, pool with stones, stalactites, a find chest each | 60-180 m off the ways, 90 m apart; from the log | none (hidden) | ~15k triangles each (no relief), fade 110 m, LODs |
| Region signatures (`region_dressing.gd`) | 25 prop kinds over 11 Far Reaches regions (ballistae, lantern poles, grave mounds, fish racks, haystacks, fallen arches, charcoal clamps, bell halves, lamp posts, drowned columns, cairns...) | the regions' open ground | glow cards | built per 96 m cell, one kit per cell, fade 140 m |
| Yards (`core/world/realm/settlement_yards.gd`, module "yards") | washing lines, gardens, pens with sheep, smithies with a fire, graveyards, market corners in Hearthward (6, 38), Reedholm, Fallowmere, Lastlight | inside each town circle on open ground | - | per 56 m cell, fade 120 m |
| Water (`waterworks.gd`) | nine docks (boats, nets, lantern posts, shore stones) at the lake, the Reedmere and the Nave's mere; three plank bridges and two fords on the Sorrow | from the log | dock lanterns | per item, fade 150 m |
| Climbs (`climbs.gd`) | 6 broken towers (outside stairs, deck, fire, chest) and 6 cut stairs to viewpoints (landing lantern, seat, chest) | wild ground 40-90 m off ways | tower fires | fade 150 m, stairs with ramp colliders |
| Ground marks (`ground_marks.gd`) | cart ruts along the ways (broken by a hash, off the towns) and glassy puddles in the dips | along every way | - | ~8,500 triangles total, 2 draws per 96 m cell, fade 90-110 m |
| Hidden finds (`hidden_finds.gd`) | 32 caches each at the end of a three-clue trail (stone arrows, blaze posts, ribbons, scratched slabs, lantern stakes) that starts in sight of a road | from the log | - | per kit, fade 130 m |
| Avenues (`titan_gates.gd`) | five pairs of obelisks 12 m apart leading to each of the three raid gates, taller toward the gate, fires on every second pair, kerbs | the approaches of the henge, Hierarch and Anchoress arenas | fires | merged flames, fade none (landmarks), LODs |
| Outcrops, far hulls, perf rework | see above | | | |

## Families reworked in this pass (for the "game-wide" ask)
Landmarks (all), bosses (Warden, Crown, Thornwarden, Anchoress, Bone Abbot), villagers (belt, buckle, pouch, patches, yoke),
code-built cottages (sills, shutters, lanterns, ridge cap, garden fence), all kit masonry (tone and moss patchwork, wall-foot debris
in the landmark kits), all modelled props (weathering baked into vertex colour), the oak-family crowns, region flowers, water
edges (docks, bridges, fords), the ground (ruts, puddles), settlements (yards). Reviewed, not reworked yet: tavern dwarves,
common enemies, stalls/fences/wells/carts, rocks, far horizon cards (listed in `docs/r39/world_backlog.md`).
