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

# Fix pass after the first measurement (build time, placement, parse errors)

The lead measured r39-world: the Realm build went from 15.9 s to 62 s; `wonders` 198 ms -> 25 s (the Sleeper's search 17 s, the ship 2.7 s,
the span 3.9 s), flora +8.8 s, the Sleeper and the ship did not place, 2 of 16 caches, 0 outcrops, the henge gate cost two seal guards,
six scripts did not parse. What changed, by construction:

- **Parse errors**: every `:=` from an untyped value is typed (the kit instance is `var k: WK` everywhere, `var n: int = k.commit()`,
  `var title: String`, `var pilot: OmniLight3D`); no `:=` from a Dictionary `.get`, an untyped variable or an array element in the new code.
- **No open-ended searches.** `WK.find` / `find_any` (rings x yaws x hundreds of height reads) are no longer called. `WK.place(cands, half,
  yaws, rel)` tries at most `cands x yaws` spots with 25 height reads each, one registered-site lookup (a 32 m spatial index of
  `WorldLanes.sites`, built once per change of the list) and 25 path distances, and *always returns a spot* (the first clean one, else
  the least bad). Landmarks that need flat ground are **levelled** by a `WorldLanes.register_terrace` under them (the Hollow King,
  the Salt Ship, the Wardens' towers, the hermit caches), so relief no longer matters; the Sleeper's footings follow the ground.
  Hand-chosen candidates: Sleeper (150, 338), (-100, 342), (-292, 130), (170, 322); tree (170, 340), (130, 352), (214, 350); ship
  (214, 196), (196, 214), (232, 170); towers x = -338 ... 330 at z 26 / 104 / 14 / 116; span five fixed crossings. Halls, caves,
  climbs, hermit caches and docks start from anchors **on the ways** (always dry land) walked 45-150 m aside, at most 4-8 offsets each.
- **Outcrops**: one 14 m grid pass over the Far Reaches (about 2,000 cells x 4 height reads), the 90 steepest cells 12 m apart (slope
  0.2-1.4): it always finds them. **No `RealmFlora.tree_clear` entries any more** (90 entries were tested after every tree candidate
  draw: that was the flora's +8.8 s); the sites registered by the wonders went from about 300 to about 200 and a find registers one, not four.
- **GenCache for the geometry** (`wonder_kit.gd cached(key)` / `fp()`): a kit's boxes are GDScript (about 70 microseconds each; the
  new family is about 30,000 boxes: about 2 s on a cache *miss*), deterministic for a place and a seed, so the finished kit
  (surface arrays, collision faces, solids, MultiMesh lists, and the recorded flames, lights, chests, water planes) is saved once under the
  builder's own source salt and restored on every later build; the builders skip their geometry (`if not k.cached(...)`). The key
  holds the builder, the shared sources (kit, OssKit, dress), the placement and a 49-sample terrain signature, so any edit rebuilds.
  A cache **hit** costs reading and decoding a few MB per large landmark and the node creation: **by construction under 300 ms for
  the whole family**; bake once with `--bake-cache` before packing. Relief and wall-foot debris are **off** by default (they multiplied
  the box cost); LODs on landmark meshes are gone (the far hulls and the visibility ranges do that job).
- **Titan gates** now stand 30 m outside the arena's gate and move out 14 m at a time if a registered site (a camp, a fire, a seal
  slot's site) is there; each obelisk skips a spot that hits a site. They no longer stand on the seal guards' ground.
- **Light budget**: lights are recorded and made at commit, capped at 72 for the whole family (`WK.LIGHT_CAP`, reset per Realm build).
- Per-item build cost on a hit: Sleeper, tree, ship, towers, span, gates: one cache read each (milliseconds); halls and caves: one read each;
  region props, yards, finds, docks, roadside, caches: one read per cell or scene. On a miss (first run, or after an edit of that builder):
  the box counts above x 70 microseconds, once.

# Fourth pass: game-wide model depth (world seat, continuation)

## Trees and undergrowth (`tree_gen.gd`, `tree_bark.gd`, `tree_surf.gd`)
**What.** Every tall trunk now carries baked bark: furrows that meander up the trunk (radius and vertex normal, 18-20 sides on the
big trunks instead of 14), per-style shading in vertex colour (oak: deep furrows with lichen on the ridges; birch: smooth pale bark with
dark scarred patches; pine: broad plates; dead wood: weathered grey with stripped, warmer patches), burls on oaks and willows, a rootlet
forking off every other root flare. Logs and stumps get the same bark. Five new variant families so no wood repeats: oak 4 -> 6, pine 3 -> 5,
birch 3 -> 4, deadwood 3 -> 6 (v3 lightning-split trunk, v4 tall bare spike leaning hard with limb stubs, v5 squat rotten tree with shelf fungi;
`snag_2` stays the rift's charred tree). Undergrowth: grass 2 -> 4 (taller, straw-tinted, denser tufts), tallgrass 1 -> 2, flowers 2 -> 4,
heather 1 -> 2, fern 2 -> 3, shrub 2 -> 3, bramble 2 -> 3, mushrooms 2 -> 3, logs 2 -> 3, stumps 2 -> 3.
**Where.** Any wood: the old forest (around the Hearthward, x -60..140 z 20..200), the fen willows, the moors; deadwood in the old forest,
fen, ash, ruins and crag (rates unchanged). Stand 5 m from an oak or pine trunk and look along the bark; look at a birch from 10 m.
**Cost: nothing at runtime.** The detail is geometry and vertex colour in the cached mesh (GenCache, keyed on `tree_gen.gd`'s source hash;
bump the rev comment on the TreeBark preload when `tree_bark.gd` changes). Trees were already per-chunk MultiMeshes with at most two kinds
per 32 m chunk (`_variant(..., per = 2)`) and one kind per 24 m undergrowth chunk, so **more variants do not add draw calls**: they vary
the wood from chunk to chunk. Triangles: an oak trunk goes from about 280 to about 400 near triangles (the old tree is 1.5-4 k), a pine
trunk from about 140 to about 470, a birch trunk about 150 -> 360; the existing LOD generator (25 / 60 degrees) strips them with
distance and the **@far trees skip the bark entirely** (same rng draws, so the far tree is still the same tree). Cold build: about 15 more
kinds at ~25 ms once (cache); warm build: a few more small meshes read from disk.
**Check.** 5 m: ridged bark that catches the moon, no seam down the trunk (the ring is periodic), no gap where a burl or rootlet meets the
trunk, lichen patches on the oaks. 50 m: no change in silhouette, no pop at the 38 m far swap. A deadwood spike leaning at the old forest's
edge reads as a different tree from a split one. Draw calls per region unchanged.

## Rocks and cliffs (`rock_kit.gd`, `rock_kit.gdshader`)
**What.** Every RockKit mesh (boulders, cliff faces, menhirs and grave slabs; granite, mossy and ash styles) now carries **strata bands**
(each layer its own tone with a shadow line under each ledge, baked into vertex alpha) and **lichen patches** (grey-green, noise-broken,
favouring up-facing faces, baked into the blue channel on the styles that have no embers). Boulders get three more faint "scar" facets
that break the outline, slabs and cliffs get the lichen and a band tone of their own. The shader reads them with two multiplies and one
clamp in terms that already existed (the lichen mix, the albedo): no new texture fetch, no new uniform sampler.
**Where.** Everywhere there is stone: the crag (x 180..330, z -60..80), the heath boulders, the walls of the Ossuary's yard, the Far Reaches'
outcrops; grave slabs in the necropolis (x -150, z 90). Walk up to any granite cliff face.
**Cost: nothing at runtime.** Triangles are unchanged (the painting is on the same vertices; the facets are plane cuts of the same
tessellation); the meshes are GenCache'd under `rock_kit.gd`'s source hash, so they rebuild once and load warm; draw calls unchanged.
Cold build: a `_vertex_normals` and two `_fbm` passes per rock (about 2 ms each, once).
**Check.** 5 m: stripes of tone that follow the ledges on a cliff, lichen on the shoulders of boulders, no black or blown-out rock
(vertex alpha is 1 on meshes that do not carry bands, so the basalt columns and the rift's rock are unchanged). 50 m: the facets still read
as a chipped silhouette; nothing shimmers.

## Acoustic zones and per-crown fade (cross-team: sound and light seats)
Every interior registers `AcousticZones.register(aabb, room, label)` through `WK.acoustic(points, room, label)` (wonder_kit.gd; the box round
the given world points; at runtime, outside the kit cache). Builder -> room / bed:
- `deep_halls.gd` (all four, whole complex, 30 x 44 m, 6.8 m): kings_undercroft crypt/crypt; castellum_cisterns hall/hall; witchs_cellar cave/hollow; nave_crypt hall/nave.
- `caves.gd` (seven, the three chambers, 16 x 36 m): cave/cave, the root cave (no. 1) cave/hollow.
- `the_sleeper.gd`: the heart-hall (18 x 26 x 10 m) hall/heart-hall. `salt_ship.gd`: the hold (6.8 x 24 m) cave/ship's hold.
- `wardens_line.gd`: each tower's keep hall (8 x 8 x 11 m) hall/tower. `hollow_king.gd`: the trunk's hollow (11 x 11 x 8 m) cave/hollow.
Boxes are axis-aligned round a turned room, so a corner may reach a little past a wall; they sit under the ground for the halls and caves.
Check: walk in and out of each; the bed and reverb change at the door, not at the surface.
Trees: `TreeGen` kinds now carry `fade_end` (26 m + 1.2 x crown radius, 30-38 m; was a flat 38 m), read by `flora_emit.gd` as the near mesh's end and the far
mesh's start per crown. Wide crowns hold longer, small ones swap sooner: never farther than before, so near triangles do not rise.

## Ruins kits (`oss_kit.gd`, every kit that builds with the `ruin` / `ruin_big` masonry)
**What.** Up to three tall ruin walls per kit (a hash of the wall's place picks about 4 in 10 of the eligible ones) now carry: fallen blocks at the foot
(1-3, thrown to one side), a darker carved band along the long face (a proud course 18 cm high), and two tilted stones on the broken crown. Tone
patchwork (`_grime`) and moss on up faces were already in every kit. The ashlar **relief stays off** (it multiplied the box count); the landmark kits
(`WK`) keep both off (`debris_max = 0`) because their geometry is GenCache'd.
**Where.** Any ruined wall: the Marches' ruins (south and west), the waysides, the fallen halls; look along a long ruin wall at 5 m.
**Cost.** At most 3 x (2 + 1 + 2) = 15 kit boxes per kit (about 1 ms at 70 microseconds a box), merged into the wall's own material mesh: **no extra draw
call**, no extra node; non-solid, so no collision cost and no path blocked. Whole Realm: well under 0.1 s (about 60 ruin kits); no cache needed at that size,
which is why this is the capped form of the debris rather than the uncapped one the landmarks had. At 50 m the band and stones are sub-pixel and merge into
the wall tone.
**Check.** Debris never in a doorway (it is thrown beside the wall, outside its footprint, and is not solid); the band reads as carving, not as a floating plank.

## Prop variants wired in (`site_props_more.gd`, `site_props.gd window`, `site_dress.gd _emit`)
**What.** The six unwired builders are in: crate (stack, rope-bound with a slid lid, tipped with a splinter), barrel (pair, lying, lidded), bench (potted, stool),
cart (loaded, tipped), firewood (chopping block, split-wood rack); sacks keep their pile. Pools per kind: crate 5, barrel 4, bench 3, cart 3, sack 3, firewood 3
(they were 3, 2, 2, 2, 3, 2).
**No draw rise.** Each zone draws a *window* of the pool the size the kind had before (modelled variants + 1: `SiteProps.window`), at an offset from a hash of
the zone's id, so neighbouring yards show different mixes and no kind draws more MultiMeshes in a zone than it did. (Extras have 1-3 material parts like the
modelled ones; a window of extras can differ by a part or two.) Triangles: a variant is 20-150 boxes' worth, built once and shared; instances unchanged.
**Check.** Two yards side by side (Hearthward's yard and the Smith's) show different crates and carts; counts of draws per zone in the regions tour unchanged.

## Hearthward and town buildings (`lore/cottage_detail.gd`)
Checked against the brief's list. Already present: roof overhang (0.45 m with gable verge boards), ridge cap with finials, chimney (stone, cap, pot, smoke), door and window frames,
lintels, sills, fixed shutters, flower boxes, hung lantern, drip stones, garden fence and bed, kit masonry tone patchwork, market stalls/carts/wells (market_props, props above).
New: a **fascia board** along both eaves and **moss patches** on the roof slopes (three on the damp north side, two on the south). All kit boxes merged into the existing
roof/beam/leaf meshes: no new draw call, about 10 boxes a cottage at build time (0.7 ms). Check at 5 m: a dark board under the thatch edge; at 50 m: roofs have a mottled tone.

## Critique items 1-2 (masonry edges, crown value structure)
**OssKit boxes** (`oss_kit.gd`): the eased arris faces are lifted 15 % (they catch the light; vertex colour clamps at 1, so darker stones gain most) and the arris is a touch
larger (up to 4 cm, was 3); per-block tone jitter widened from +-5 % to 0.90-1.03. Same triangles, same draws, bake only. Check at 5 m: block edges read, no checker grid.
**Crowns** (`tree_gen.gd crown_cards`): large lit clumps and shaded hollows (+-14 % value at a 3 m scale) over the existing core/top gradient; bake only, no cost.
Check at 50 m: a crown is no longer one flat value.
