# Umbral Reaches: world, models, textures critique (environment / tech art seat)

Evidence base: the night-grade captures in `.../968888c4.../scratchpad/play/` (places/, regions_a/, regions_b/, perf.txt), plus `world/realm/realm_ground.gdshader`, `core/world/realm/rock_kit.gdshader`, `world/zones/foliage.gdshader`, `core/world/canopy_shell.gdshader`, `core/world/far_detail.gd`, `core/world/mesh_chunks.gd`, `world/areas/ossuary/oss_kit.gd`, `core/world/realm/prop_models.gd`, `docs/world_density.md`, `docs/far_reaches.md`. Read-only; nothing was run. I only had stills, so "flat/samey" calls on terrain come from the vistas, not a heightmap analysis.

## Headline

The world is wide, well-planned and cheap (avg 8.5 ms, 874 draws; perf.txt). The problem is not quantity. It is surface quality at close range and silhouette quality at mid range. Props and masonry read as clean primitives (boxes with a texture), the trees read as one repeated green blob, and the night grade crushes most of what material work exists. Luke's "Enshrouded detail at no perf cost" ask is best answered by baking and by shader-side layering on shaders you already own, not by more geometry.

---

## 1. LANDSCAPING

**Strengths.** `vista_realm_from_se.png` is the best image in the set: the Crowns wall, the hanging chain, a lit hub and a dark ridge read as a place. `vista_east_marches.png` (tower on a mound, walled waystation behind, mere in front) is a proper composition: a tall silhouette, a mid-ground, a lit window to pull the eye. The hub-from-south shot (`vista_hearth_from_south.png`) frames the village through trees with a path funnelling to it. Landmark navigation from spawn works.

**Findings**

- **P1: the terrain between landmarks is soft, rounded dunes.** `region_downs_0.png` and `vista_west_marches.png` show the same smooth-hump ground over and over. Slope is carried by the shader (cliff triplanar kicks in at ~34 deg) but the mesh itself has no break lines: no terraces, no rock outcrops growing out of slopes, no cut banks, no gullies along the roads. A 2 m grid (`realm_land.gd` `_old_step = 2.0`) cannot hold a sharp edge. Fix: add a stamped "bench and scarp" pass: a noise-gated ridged term (abs(noise) inverted) added to height where slope is already mid, so slopes break into 1-3 m steps with a cliff-layer band; plus rock-kit outcrops seeded on the break line (the kit already exists, `rock_kit.gd`). Effort: M (2-3 days). Cost: bake-time only, same triangle count.
- **P1: the Crowns wall is a single smoothed mountain ribbon.** In `vista_realm_from_se.png` and `vista_crowns_from_road.png` the back wall is a handful of large blue-grey planes with a thin spike row on top. It is a good backdrop but has no mid-scale structure: no buttresses, ledges, snow/ice streaks, no waterfalls (one faint white streak at upper centre). At 400 m it needs 3 tonal bands (dark base, lighter faces, pale cap). Fix: a world-height-driven ramp in the ground shader's far branch (`fz` branch, `realm_ground.gdshader` ~l.327) for pale ledges and dark crevice streaks keyed to `wpos.y` and slope, free (already in the far path). Effort: S.
- **P2: region transitions are laid by the biome splat only.** Heath to ash to fen blend along noise edges, which reads as a colour change, not a landform change. `region_foundry_0.png` (ash) is the best case because the cracked-basalt layer is strongly distinct. Fen vs meadow (`region_fen_0.png`, `region_downs_0.png`) are both dark-blue turf with grass tufts. Fix: distinct flora silhouette per biome (see section 3 of the plan), not more textures.
- **P2: sightlines inside woods are closed.** `close_oak.png` is nearly black: bark trunk fills the screen, tiny grass. `region_moor_0.png` has an overhanging canopy filling a third of the frame. Cameras under tree crowns lose the world. Fix: a camera-side canopy fade is already thought of (near_fade 1.6 m in `realm_foliage.gdshader`); extend it to crown-card fade at ~4 m when the camera is below a crown. Effort: S.
- **Dead flat:** the Hearth plaza surround, the downs and the pans are laterally flat (hub plaza in `close_hearth.png` is a perfect slab). A pure slab with a square flag grid at village scale is the least "Enshrouded" thing in the set (their plazas are cobbled, uneven, with stairs and kerbs).

## 2. FULLNESS

`docs/world_density.md` is thorough (29 wayside kinds, 30 m max gap on ways, 44 m open ground). The captures confirm that something is always on screen. The issue is not emptiness, it is sameness of fill.

- **P1: the fill is the same three items.** Grass tufts, lavender clumps and ruin blocks recur in almost every region image (`region_road_0`, `region_moor_0`, `region_downs_0`, `region_holds_0`). The lavender patch is a stand-out repeat: identical purple sprites show in the moor, road, quarry and downs. Enshrouded varies by biome via distinct ground cover silhouettes and colours. Fix: per-biome ground-cover swap table in `flora_tables.gd`/`flora_looks_marches.gd`: pick one signature plant per region, drop lavender to 1-2 regions. Effort: S-M.
- **P2: ground between things is low-contrast and bare at foot level.** Flora is placed at 0.3-1 m scale, but moss, fallen leaves, roots, pebbles, ground-hugging litter are mostly absent from the first 3 m of the camera. The ground shader has cavity and patch hue but no decal layer. See plan 6.
- **P2: dead zone risk where the Far Reaches are "planner-filled".** The wayside plan places a ruin every ~30 m, so every stretch gets *a* thing, but per-100 m "worth seeing" is uneven: a cairn is not a reward. The plan is by distance, not by interest. Fix: require 1 "set piece" (silhouette over 5 m or lit element) per 150 m of way, and let small kinds (cairn, woodpile) only fill between them. Effort: S, in `realm_wayside.gd` ways pass.
- **P3: tree crowns repeat.** `region_thornwood`, `region_glade`, `vista_crowns_from_road.png`: one oak-shaped blob repeated in rows; the oak pair in the Crowns shot is two copies of the same crown. Variants per species appear to be small in number.

## 3. EXPLORATION

- **P1: reasons to leave the road are mostly "more props".** The wayside gives places 4-25 m from the way: wells, camps, shrines. They are visible from the road, so you do not need to leave it. Rewards in `docs/world_density.md` are "a handful of grave ash, now and then iron". Fix: tier the boxes: put 1 in 3 rewards 60-120 m off-route behind a visual hook visible only from a vantage (lit window across a mere, a column of smoke, a pale tree). Effort: S-M (data in `wayside_themes.gd`).
- **P2: verticality is thin.** The lookouts and glide perches exist (good), but no caves, undercrofts, second-level ruins in the captures; `region_foundry_0` and `region_quarry_0` are the only ones with level changes. Fix: a "cut" kit: 4 m deep ravine with a bridge, a stair-down tomb door with a lit brazier. Effort: M.
- **P2: navigation by landmark is good from high, weak at ground level.** Fog and 420 m view hide landmarks; `vista_east_marches` works because the camera is high and above the trees. At eye height (`region_road_0`) the horizon is trees. Fix: three or four tall *lit* beacons (the `landmark_beacon.gd` exists) so a landmark breaks the canopy, and a pale-moon-lit tower at each region's centre.
- **P3:** no map-reading rewards (discoverable sightlines like Enshrouded's flame altars).

## 4. SCALE

- **P1: buildings and the villagers' world are human-scale; trees are not tall enough.** In `close_hearth.png` the half-timbered house looks slightly under-scaled against the plaza flags (each ~1.8 m square), and the market stall ceiling is low. In the hub vista (`vista_hearth_from_south`) the trees are 15-20 m, which is fine, but the canopy crowns read as parasols over a hamlet. For 7.6-8.8 m bosses to read as towering, the first 3 m of the world needs *clear* reference objects: doors, barrels, fences, carts. `region_saltpans_0.png` is the best scale image (timber legs, a cart, stone blocks): objects are legible because they are big and chunky. Use that as the template.
- **P1: stone blocks vs. wall brick scale mismatch.** `region_road_0.png`: the foreground ruin blocks are ~0.5 m, the pillar 2.2 m, the house bricks 0.15-0.2 m. The cottage brick looks like a sketch on a roof-height plane. In the Rift/fen towers (`region_rift_0.png`, `region_fen_0.png`) the masonry is a pixel-grid of 0.3 m cells, which reads as voxel art, not as stone. Pick one masonry scale per building class (3 tiers: cottage 0.25 m course, hall 0.4 m, tower 0.6 m) and let the texture scale and block size match.
- **P2: the world's width (740 m) is covered at walking speed in ~2.5 min; with 22 regions, density per region is high but landmarks are 60-100 m apart.** That is fine for the scale of a prototype, but traversal beats feel short in the open. Not a fix for now.
- **P2: boss-size reference.** Between 7.6-8.8 m and 1.8 m player, the ruined arch and wall heights in the fen and rift (`region_rift_0.png` arches ~12 m) are right; but doorways in hub houses are 2 m, so no arena architecture hints at an 8 m creature. Add 6-9 m statues/gates near boss approaches.

## 5. MODELS AND TEXTURES

**What is good.** Hearth materials (timber, plaster, daub with normal and ORM) in `close_hearth.png` look the richest in the set; saltmarket's timber/cobble (`region_saltpans_0.png`) holds up up close. The ground splat shader is sophisticated (9 layers, height-blend, triplanar cliff, far-LOD, scorch). The rock kit shader (triplanar, cavity, lichen, moss caps, ember cracks) is a real asset.

**Findings**

- **P0: masonry reads as pixel grid in the Far Reaches and Rift.** `region_rift_0.png` (square tower, checker pattern), `region_fen_0.png` (black tower, grid), `region_necropolis_0.png` (crypt, darker grid), `region_quarry_0.png`. These are `OssKit` boxes with `vertex_color_use_as_albedo` and a tiled brick texture at triplanar scale (`oss_kit.gd` l.121-141); per-block tint is a hard per-face value, so each block is a flat colour square. At the screen sizes shown the texture reads as a checkerboard. Fix: add micro-variation inside blocks (see plan 1, 2). Effort: M.
- **P1: too dark to see the work.** Masonry in the fen/rift/quarry is near-black at night (the albedos are multiplied by the cold tint and `brightness 0.6`; ground is dark by an owner decision). The Hearth lamps rescue the village, but everywhere else the modelling is invisible. Detail that cannot be seen is wasted; so every detail technique below has to preserve value contrast *inside* the dark range (lift the AO/edge-wear range, not the exposure).
- **P1: leaf cards show dither/screen-door artefacts.** `region_moor_0.png` (top-left foliage), `vista_west_marches.png` (a canopy from above) and `region_crags_0.png` show cross-hatch / stipple patterns on leaves. These are the near-fade dither and the alpha-scissor mip boost (`realm_foliage.gdshader` l.146, `foliage.gdshader` mip_boost). Moving shimmer in motion. Fix: use `alpha_to_coverage` (render_mode `alpha_to_coverage_and_one`) if MSAA is on, or limit near_fade to <1.6 m and replace with a blue-noise threshold. Effort: S-M, risk: moderate (verify at 960 row internal height).
- **P1: tree crowns are one-colour domes.** `vista_crowns_from_road.png`, `vista_hearth_from_south.png`: a single hue of teal-green, almost no value structure inside a crown (no sunlit/shaded clusters, no branch gaps). The far canopy shell (`canopy_shell.gdshader`) matches the near trees, which is why the forest reads as a single mass. Fix: per-leaf-card vertical gradient vertex colour (dark inside, light on top) baked once in `tree_gen.gd`, plus a per-instance hue shift (already done for undergrowth). Effort: S.
- **P2: dark brown bark texture with strong specular streaks (`close_oak.png`).** Bark is 1024^2 tiled at a scale where a texel is ~2 cm: noisy white speckle on moon-lit ridges. Reads as wet and noisy not as bark. Lower specular, widen the normal's low-frequency.
- **P2: ground texture is clean cobble polygons at the same scale everywhere** (`region_quarry_0.png`: a giant voronoi cobble covering the *whole* dirt slope; `region_foundry_0.png`: the same polygons). Layers repeat visibly across a hillside; at the quarry it looks like pavement rather than rock. The macro-variation exists but is brightness-only.
- **P2: consistency.** Three visual languages sit next to each other: chunky painted hub props (`close_hearth.png`), photoreal-ish rock kit with lichen, and the sharp black-box ruins. Style cohesion is the biggest lever for the "Enshrouded" look: Enshrouded props are chunky, bevelled, with hand-painted colour gradients and strong vertical gradient AO.
- **P3: textures are all PNG with compress/mode=2 (VRAM compressed) and mipmaps on.** Good. Total art/textures is 462 MB, art/models 598 MB (many per-NPC/boss maps), so memory is not free; keep any new texture at 512-1024 and share across sets.

---

## 6. LUKE'S ASK: Enshrouded-level detail at near-zero frame cost

**What the project already does** (so I do not propose it again): world-space triplanar on masonry (`OssKit._tri`) and on rocks (`rock_kit.gdshader` with detail normal, moss caps and lichen); a 9-layer height-blended ground texture array with far-LOD that drops normal fetches (`realm_ground.gdshader`); MultiMesh flora with chunking (`flora_emit.gd`, 570k instances); mesh LODs via `ImporterMesh.generate_lods(25, 60)` cached on disk by `GenCache`; a canopy shell for far forests; vertex-colour contact AO and per-block tint baked in `OssKit.box()`; PropModels merges Blender-modelled glb parts into one mesh per material set. So the shaders are good. What is missing is **authoring density** (geometry bevels, baked AO in props) and **layered surface response** in the building/prop materials.

Techniques, in priority order. Cost key: GPU = per-pixel ALU/texture fetches on screen; CPU = per-frame; MEM = VRAM/RAM; Bake = load/cache time only.

### T1. Bevel and edge-wear baked into vertex colour on every OssKit box (HIGHEST value)
- **Adds:** the Enshrouded "chunky, hand-made" look: boxes catch a highlight on every edge, blocks read as individual stones, not texture on a slab. Directly fixes the pixel-grid P0.
- **Where:** `world/areas/ossuary/oss_kit.gd box()` (writes vertex colour: contact AO + tint). Add per-vertex "edge distance" (1 at corner, 0 at face centre; each box face quad already has 4 verts so write distance via a second colour channel, or subdivide each block face to a 3x3 with jittered inner verts for a 0.02-0.04 m chamfer). The material then multiplies albedo by `mix(1, edge_lift, COLOR.a)` and tilts the normal at edges.
- **Cost:** Bake only if done in the mesh; +~8 verts/block (use the existing LOD to drop the chamfer at distance: LOD0 only within 25 m). GPU: 0 extra fetches if encoded in COLOR.a and applied through the existing StandardMaterial vertex-colour path; a tiny custom shader gets one extra mul. MEM: +30% on kit meshes in view (kits are merged by material, a few MB).
- **Risk:** low-medium. Tris on kit meshes rise; keep LOD gen on and check `primitives avg` in perf.txt (currently ~880 K). Gate by `--no-bevel` flag.
- **Effort:** M.

### T2. Per-block jitter in tone, offset and mortar depth (kills the checker look)
- **Adds:** stones that are individually coloured, slightly rotated and with differing face depth ("rich layered materials").
- **Where:** same `box()`; hash on block id into HSV shift (+/-6 % value, +/-4 % hue toward moss or soot) and a +-0.01-0.02 m face push. Already has "per-block tint", so extend range and add a low-frequency world-space term in the material shader.
- **Cost:** Bake only. **Risk:** low. **Effort:** S.

### T3. Triplanar detail-normal + "macro/micro" layering on masonry, wood and plaster materials
- **Adds:** a second, 4-6x finer normal on top of the base normal, plus a coarse (8-15 m) macro value mask that breaks tiling. Moves toward Enshrouded's rich layered surfaces.
- **Where:** `OssKit._tri` / `_daub` (StandardMaterial3D, `detail_enabled`, `detail_mask`, `detail_blend_mode`). Godot's StandardMaterial3D already supports detail albedo+normal with a mask on UV2; use the rock kit's `detail_normal` approach in a small custom shader for buildings so the world-triplanar stays (BaseMaterial's detail uses UV1/UV2, and with triplanar UV1 there is a restriction, so a custom shader based on `rock_kit.gdshader` is the clean route; it already has TRI macro, tri_normal, detail normal).
- **Cost:** GPU: +1 triplanar normal fetch (3 samples) is the cost of the rock shader today; limit to ~25 m by fading `detail_strength` with distance (already how the ground does it) so far pixels pay nothing. CPU 0. MEM: 1 shared 512 detail normal (~0.35 MB).
- **Risk:** low if the distance fade is in. **Effort:** M.

### T4. World-normal and height masks for moss, dirt, snow/frost on all static props
- **Adds:** grounded props: moss on tops, dirt at the base, soot under overhangs. Matches Enshrouded's "everything is weathered and grows in".
- **Where:** `rock_kit.gdshader` already does world-up moss (l.96-105); lift that block into a shared `.gdshaderinc` (e.g. `core/world/weather_mask.gdshaderinc`) and include it in building/prop shaders. Dirt: `dirt = smoothstep(0.5, 0.0, wpos.y - ground_y)` needs ground height; cheaper: bake `COLOR.g` = height-above-foot per vertex (a simple per-mesh min-Y), so bottom 0.4 m gets dirt for free.
- **Cost:** GPU: +1 moss texture fetch only where `up > 0.4` (branch), ~0. Bake: per-vertex float. **Risk:** low. **Effort:** M.

### T5. Vertex-colour AO and gradient on every Blender prop (PropModels and glb)
- **Adds:** each barrel/crate/cart/stone gets grounded contact darkening and top-light gradient: chunky stylised look.
- **Where:** `tools/blender/props_*.py` (bake AO to vertex colour in Blender; Godot imports COLOR), and `prop_models.gd` (already "vertex tone"). Add a second pass at import for meshes with no AO: darken verts within 0.15 m of the mesh floor and verts whose normal points down (code, in `PropModels.add` when appending).
- **Cost:** Bake. GPU 0. **Risk:** very low. **Effort:** S-M.

### T6. Ground decal-by-shader: litter, leaves, pebbles and moss patches in the ground splat
- **Adds:** ground-level richness the grass cannot give (fallen leaves around trees, pebble scatter around ruins, mud rings round wells).
- **Where:** `realm_ground.gdshader` (before l.307 colour modulation). A 9th/10th array layer of "litter" (alpha-masked leaves/twigs, pre-composited in `tools/realm_land_textures.gd`) mixed in by a second vertex weight or by a world-noise mask * proximity to tree roots (the flora layers already know "feet"; write a low-res "litter map" like `scorch_tex`, 1 px = 2 m, R8, 370x274 = 100 kB). Lay litter as cheap albedo+rough only, near branch only (`near_on`).
- **Cost:** GPU: +1 fetch of an R8 map (cached; tiny) + 1 layer fetch within 20 m. MEM ~100 kB map + 1 array layer (~1.4 MB at 1024 BC). **Risk:** low (same pattern as the scorch map). **Effort:** M.

### T7. Real decals for wear and story at place-level (Forward+ `Decal`)
- **Adds:** blood, soot, scorch, worn path patches, mud pools around the wayside places; fast storytelling per place.
- **Where:** `wayside_build.gd`; clustered decals in Forward+ cost per pixel, so cap at ~20 visible and distance fade with `distance_fade_*`.
- **Cost:** GPU small; CPU small; **risk:** medium (many decals under many omni lights inflates cluster cost; Luke's priority is stutter-free, so keep to <=24 and avoid spawning at runtime in view: build with the chunk). **Effort:** M. Use only after T1-T6.

### T8. Better LOD use so near detail can rise
- **Adds:** headroom: near models can be 2-3x denser while far costs fall.
- **Where:** `core/world/mesh_chunks.gd with_lods` uses `generate_lods(25.0, 60.0)` (normal merge angle 25 deg, 60 deg split); wayside meshes only get LODs over 4,000 triangles; PropModels `commit(..., lods)` is opt-in. Fixes: (a) turn LODs on everywhere a prop has more than ~300 tris; (b) set per-set `lod_bias`/`visibility_range` with dither fade (already `FarDetail.generic_range`); (c) generate a *billboard impostor* (8-view octahedral baked once per prop kind in `GenCache`) for tree classes and big ruin pieces, used beyond 100 m instead of the 100-300 tri hull, bringing the crown colour and silhouette closer to the near tree. Impostors are not in the project yet.
- **Cost:** CPU 0; GPU lower than now. MEM: 1 atlas per tree kind (~1-2 MB each at 1024 BC). Bake: seconds, cached.
- **Risk:** medium: impostor popping and lighting mismatch; do it for trees only after T1-T5. **Effort:** L.

### T9. Foliage: more value structure, same cards
- **Adds:** "dense believable foliage": crowns with a dark core and lit top; clusters with hue variance; fewer visible stipple artefacts.
- **Where:** `core/world/realm/tree_gen.gd` (vertex colour per leaf card: gradient by height and distance from trunk), `realm_foliage.gdshader` (already a per-origin hue hash and a world patch); `canopy_shell.gdshader` (add vertical gradient and the same hue patch so the far shell matches).
- **Cost:** Bake. GPU 0. **Risk:** low. **Effort:** S.

### T10. Texture-array packing for props (one array, per-material layer index in COLOR/CUSTOM)
- **Adds:** more distinct materials (iron, rope, moss, daub, cloth) per draw without more draws.
- **Where:** props today are one mesh per material set (PropModels). A single array shader reading a layer id from vertex colour would merge more sets per chunk (fewer draws). Only worth it if draw calls are the bottleneck (max 1501 in `region_road`).
- **Cost:** MEM: one BC array; GPU +0. **Risk:** medium (UV/mip bleed; rework of 112 prop models). **Effort:** L. Low priority.

### T11. Silhouette pass on rocks and large props
- **Adds:** breaks the "smooth blob" boulders (`close_oak`, `region_foundry_0` boulders are smooth domes); more angular facets and stacked slabs.
- **Where:** `rock_kit.gd` (916 lines; has style variants). Add a flat-shaded facet pass (hard-edge chamfer from a Voronoi crack) at bake; the shader already has cavity COLOR.r.
- **Cost:** Bake + ~30% tris on rocks, LOD covers. **Risk:** low. **Effort:** M.

### Do not do / cautions
- No dynamic resolution (Luke's rule); no new per-frame CPU (no runtime-generated decals or LOD builds in view; every bake goes through `GenCache` at load).
- Keep detail fades inside the existing 20-32 m `far_lo/far_hi` pattern so there is no new overdraw at distance.
- Do not widen glow or exposure (umbral-donts). Make the dark range readable by raising *contrast* (AO and wear) rather than lifting brightness.
- The 1% lows in perf.txt are already 60 fps in 9 of 17 regions and there is an 84.5 ms worst frame at `region_hearth` and a 47 ms one at `region_chapel_1`: any new feature must not add first-view hitches (the `hearth` spike is probably the first view after load; confirm it is a cache/shader-compile hitch, not content).

---

## 7. Further critiques

- **P1: frame hitches in the captured run** (`regions_a/perf.txt`): worst 84.5 ms (hearth_0), 47.4 ms (chapel_1 / thornwood), 31.5 ms. Luke's top complaint. These are on first views after the build, so likely lazy shader/pipeline compile or texture upload. Fix: a warm-up pass that renders one frame of each shader/material combination (kit, rock, foliage, ground array) behind the loading screen; verify with `zz` perf tooling. Effort: S-M.
- **P1: draw calls max 1501 on the Pilgrims' Road** while the Crags is 394: the heavy places are the flora-dense woods and hub. Merging kit surfaces further (T10) or raising wayside chunk granularity would trim.
- **P2: star glints in the sky are render artefacts** (blurred coloured squares, `region_downs_0.png`, `vista_west_marches.png`): chromatic dots, look like lens-fringed bokeh. If intentional, tighten; if not, they read as dirt on the lens.
- **P2: the chain hanging down the sky** is a strong landmark but sits in front of the vortex in every view; good, but its link geometry is blocky at distance.
- **P2: lava/ember glow is the only warm colour outside hubs**: good accent, but everything else is teal-blue-green, so regions read as one palette. Give each region one signature colour (Lanternwood cold fungus cyan, Southwood amber windows, Cairns pale grey) in grade or flora tint.
- **P3: hub UI marker (the diamond "!") floats in the world and is lit at full brightness;** fine for gameplay.

## Priority list (do in this order)

| # | Item | Sev | Effort | Cost |
|---|------|-----|--------|------|
| 1 | Per-block jitter + edge chamfer + edge-wear in OssKit.box() (T1, T2) | P0 | M | bake only |
| 2 | Foliage crown value structure and dither cleanup (T9, section 5) | P1 | S-M | 0 |
| 3 | Detail-normal + macro layering on masonry/wood (T3) | P1 | M | +1 fetch near only |
| 4 | Moss/dirt/soot world masks via shared include (T4) | P1 | M | ~0 |
| 5 | Vertex AO/gradient on all props (T5) | P1 | S-M | bake |
| 6 | Hitch warm-up behind loading (section 7) | P1 | S-M | load time |
| 7 | Terrain bench/scarp pass + outcrops on break lines (section 1) | P1 | M | bake |
| 8 | Ground litter map + layer (T6) | P2 | M | tiny |
| 9 | Per-region signature flora and colour; fewer lavender repeats | P2 | S-M | 0 |
| 10 | Masonry scale tiers (cottage/hall/tower) and boss-scale architecture near arenas | P1 | S-M | 0 |
| 11 | LOD everywhere + tree impostors (T8) | P2 | L | lowers far cost |
| 12 | Decals (T7), array packing (T10) | P3 | M-L | cautious |
