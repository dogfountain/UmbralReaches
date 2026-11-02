# Umbral Reaches: dark-fantasy look review (rev 2, against the owner's reference clip)

> **Current focus (owner decision, 31 Oct 2026): engine, lighting and shadows. No modelling work for now.** Start at section 0.6. Items tagged PARKED or OUT OF FOCUS below are not to be worked on.


Handoff for an implementing agent. Snapshot 31 Oct 2026, v0.1, Godot 4.7.2.
Method: design-critique pass over code, shaders, bake scripts and README metrics, plus frame analysis of the owner's reference clip. **The game itself was not run and no game screenshots were viewed.** Verify every visual claim with `tools/capture.gd` stills before and after each change. The owner's roadmap doc was not available.

## 0. Revision note: what changed from rev 1

Rev 1 blamed (a) the hue-collapse grade and (b) missing gore. Measuring the reference shows both were over-weighted:
- The reference is itself **blue/violet-dominant**: 81-87% of its coloured pixels fall in 200-290 degrees (see 2.2). The README reports 91-99% for the game. Hue share alone is a **minor** gap. (Different crops and thresholds, so indicative only.)
- The reference contains **no blood, no bones, no red**. Its darkness comes from gothic architecture, hero lighting, grotesque creatures, and surface detail.
- The big gaps are lighting (hero lights, bloom, flare, light shafts through windows), architecture, material fidelity, character/creature scale, and camera. Rev 1's gameplay items (consequence, threat, audio) remain valid but are second to the look.

Owner statement: "the game is meant to look like this: light coming through windows, lens flare, the dark fantasy look; mine is way off." Owner memory also says: vibrant colour, purple vortex skies, WoW-like scope. Keep the vortex sky.

## 0.5 Rev 3 status audit (31 Oct 2026, 17:41 UTC)

Re-check of the project after another agent started implementing this doc. Source review only: **nothing was rendered**, no game screenshots exist in the project, and `world/main.tscn` / `bake_info.gd` still carry the 15:28 bake stamp (no rebake yet). Files were still being rewritten while I read (`shade.gd`, `default_loadout.gd`, `main.gd` at 17:38; both character files are back to their original behaviour), so re-run the greps below before acting on any item.

### Status by feature

| Item | Status | Evidence |
| --- | --- | --- |
| F1 Hero light and bloom | **Done, unverified visually** | `atmosphere.gd::_fog`: `glow_bloom` 0.04 -> 0.18, `glow_intensity` 0.82 -> 1.05, `glow_hdr_threshold` 1.05 -> 0.94, blend SCREEN, exposure 0.84 -> 0.92. Shared by both zones. 4.5x the old bloom on top of HDR emitters (lava, glimmers, crystals, flames): check for global haze |
| F2 Window light shafts | **Written, not wired** | Fog anisotropy 0.28 -> 0.68 is live. The window spots/gobos exist only in `core/world/gothic.gd`, which nothing calls |
| F3 Flare/starburst | **Partial** | Staff-orb starburst is live (`flare.gdshader`, `staff_piece.gd`). Window starbursts are in the unwired kit. Sky starburst is ineffective (defect D7) |
| F4 Gothic kit | **Written, not wired, with defects** | `grep -rn -i gothic` finds no caller in any `.gd`, `.tscn` or `project.godot`. See defects D1-D6 |
| F5 Materials | **Barely started** | `stone.tres`: roughness 0.62, metallic 0.07, rim 0.58. SSR enabled (28 steps). No new textures (`art/textures` unchanged since 10:32, `gen_textures.py` untouched), no roughness maps, no wet patches. At roughness 0.62 SSR will show almost nothing; its only mirror-like surface (the pond) is alpha-blended and unwired |
| F6 Grade | **Done, with one bug** | Hue test below. Bug D8 (chroma pass) |
| F7 Camera/DoF | **Partial** | Far DoF (20 m, 14 m transition) with menu toggle; FOV default 58 -> 54 (existing `user://settings.cfg` keeps the old value); spring arm 4.4 -> 3.7 set at runtime in `main.gd`. No authored framing yet (nave unwired). 20 m onset will soften every arch beyond the first |
| F8 Characters/creatures | **Not started** | `default_loadout.gd` and `shade.gd` are functionally the original. `grotesque.gd` is a static sphere-and-cylinder prop inside the unwired kit |
| F9 Sky | **Partial** | Stars ~0.6% of pixels (was sparser). Starbursts invisible (D7) |
| G1 Scarce light | **Tiny start** | `glimmers.gd` wisps 22 -> 12; up to 20 mushroom point-lights unchanged; no fuel, no hazards |
| G2-G6 | **Not started** | No consequence for Hollowing, no shade states, no rift presence, no audio autoload (project.godot autoloads are still Events, LightGrid, InputSetup, Settings, Travel), no lore |

### Grade verification (hue stage replicated in Python, flat colours, indicative)

| Colour | In | Old output | New output |
| --- | --- | --- | --- |
| blood red `#8B0A0A` | 0 | 321 (magenta) | 346 |
| necrotic green `#7A8F2A` | 73 | 143 | 98 |
| foliage green `#2F6B3A` | 131 | 169 | 145 |
| teal window `#20D8C0` | 172 | 188 | **172 (preserved)** |
| bone `#C9B27A` | 43 | 18 | 34 |
| flesh `#C98A7A` | 12 | 327 | 356 |

The new grade does what F6 asked: greens stay green, cyan window light is protected, warm hues survive. RC-E is resolved apart from D8.

### New defects found (fix before or while wiring)

| # | Sev | Defect | Evidence / fix |
| --- | --- | --- | --- |
| D0 | **P0** | **The gothic kit is never instantiated.** Windows, arches, pond and guardian do not exist in the game | Call `load("res://core/world/gothic.gd").raise(self)` from `main.gd::_ready` **before** `atmosphere.apply(...)` and `refresh_lights()`, so the new lights get distance-fade and are in the cached light list |
| D1 | P0 | **Arch ribs are dashed, not continuous.** 12 boxes of 0.32 m along a 6.7 m (nave) / 8.0 m (gate) arc cover only 53% / 44% of it, leaving 0.29-0.40 m gaps | `_arch()`: set box tangent length to `arc / (segs-1) * 1.1` (or sweep a continuous extruded profile with `SurfaceTool`) |
| D2 | P0 | **Four of five arches stand on air.** Columns sit at x = +/-3.2 but the stair is `WIDTH 5.0` (edge at 2.5) and the terrain beside it is a 20 m chasm. Only the gate arch (z = 15.4, on ground) is grounded | Put columns on the stair edge (x = +/-2.5 with a plinth), or add buttress/pier geometry down into the chasm like the existing support pillars |
| D3 | P0 | **Windows have no walls.** Landing window at x = 4.15 floats in the chasm; gate window floats 1.3-5.5 m above ground; summit window is a free-standing frame | Add masonry mass (ruined wall, buttress, tower stub) behind each window so it reads as architecture. Reference windows sit inside thick masonry |
| D4 | P1 | Guardian at x = 2.4 on a landing whose edge is x = 2.5, scaled ~1.85x: hands overhang the drop | Move inward to x about 1.0 or scale/pose to fit |
| D5 | P1 | Gobo texture is rebuilt per window with 128x256 `set_pixel` calls in GDScript (about 98k pixel writes at load for 3 windows) | Build once (static cache), or ship it as a PNG; generate mipmaps |
| D6 | P1 | `main.gd::_apply_settings` loops all `OmniLight3D` and sets `shadow_enabled = shadows` unless meta `glimmer`; the window omnis (meta `hero`, intended unshadowed) will be turned into shadowed omnis at High quality. Also: `MirrorPond` is alpha-blended so SSR will not reflect on it; `_polish_stone()` mutates shared `stone.tres` at runtime (already saved in the file) and its overlay loop does nothing | Skip `hero` omnis in the loop; make the pond opaque (or use a proper reflective water shader); delete `_polish_stone` |
| D7 | P1 | **Sky starbursts do not render.** The burst is computed on a 210-cell grid but masked by the 780-cell star hash. Simulation at 1080p/54 deg FOV: 2,919 bright-star pixels, **0.03 px of visible burst per bright star** (a burst should span tens of pixels) | Compute burst from the star's own cell centre, or place a few dozen real starburst quads/sprites in the sky pass |
| D8 | P1 | **Chroma block undoes part of the grade.** `grade.gdshader` samples raw `screen_tex` for R and B and blends 32% of those ungraded values into the graded colour, diluting tint/saturation and skewing hue at the edges | Offset-sample the screen into `c` **before** sharpen and grading, then grade once |
| D9 | P2 | `gothic.gd` duplicates stair constants (`RUN`, `RISE`, `BREAK`, `LANDING` match `bake_main.gd` today; `WIDTH` is not shared) | Move constants to one `StairLayout` const file used by both |
| D10 | P2 | `flare.gdshader` writes both `ALBEDO` and `EMISSION` and uses `ALPHA = a`, so brightness scales about a^2 and has no screen-edge/occlusion fade | Drive only `EMISSION`, add an alpha fade at depth edges |

### Next steps

Superseded by section 0.6 (owner scope change: engine, lighting, shadows only).

*Note: section 2.1's "Game now" column describes the state before the 17:30-17:40 edits; this audit supersedes it where they differ.*

## 0.6 Scope change and engine/lighting/shadows plan (owner decision, 31 Oct 2026)

**Decision:** no modelling for now. Focus is the engine, lighting and shadows.

- **PARKED (do not touch):** gothic geometry (arch ribs, columns, walls, spires; defects D1-D4, D9), `grotesque.gd`, player/shade/creature models, texture and prop generation.
- **OUT OF FOCUS:** gameplay items G2-G6 (consequence, enemy behaviour, rift, audio, lore).
- **Use the existing `gothic.gd` as a greybox light rig.** Wire it (D0) so there are windows to light, and ignore how the geometry looks. Anything new for testing must be primitives only (CSG boxes/spheres), not art.
- Everything below is runtime/engine/post work and needs **no rebake** unless it says so. Note `atmosphere.gd` is the *effective* source for fog, glow and exposure: it overwrites `environment.tres` at startup (see L12).

### Findings, ranked (evidence from source, nothing rendered)

| # | Sev | Finding | Evidence | Fix | Done when |
| --- | --- | --- | --- | --- | --- |
| L1 | P0 | **The shadow toggle overrides the baked light policy.** `main.gd::_apply_settings` (and the same loop in `vale.gd`) sets `shadow_enabled = shadows` on every `OmniLight3D` except those with meta `glimmer`. That turns shadows ON for the 9 crystal lights, 4 lava lights (34 m range), the 4 unlit braziers (energy 0.25, range 2.5), and the staff orb light, all of which are deliberately unshadowed (`bake_main.gd` comments: lava lights "No shadows"). Once wired, the window omnis (meta `hero`) get it too | `main.gd` lines 99-101; `bake_main.gd` ~808-820; light list from `main.tscn`: only the Moon and the Sanctuary brazier are baked with shadows on | Replace the blanket loop with an explicit policy: only lit braziers, the lantern and `hero` spots may cast; everything else forced off. Drive it from one table (`LightPolicy`), not from per-file loops | `tools/light_audit.gd` reports `shadowed_positional` <= 6 in any start-of-game state, and 0 for crystal/lava/unlit-brazier/orb lights |
| L2 | P0 | **Three competing distance-fade settings; the worst one wins.** `bake_main.gd` sets brazier fade 28/16/10, `brazier.gd::_ready` sets 48/22/12, then `atmosphere.gd::_fade_lights` (runs later from the zone root) overwrites every non-player light with 18/12/9 (hero 20/12/9). Braziers, the beacons of the whole level, stop lighting the scene and fog at 18-27 m | Order: children `_ready` first, then root `_ready` -> `atmosphere.apply` | One `LightPolicy` with a class per light (brazier beacon, hero window, fill, glimmer, player). `_fade_lights` must skip lights that declare a class (or set meta `fade_set`) | A lit brazier still lights surfaces and fog at 40 m on the stair; audit output shows one fade triple per class |
| L3 | P0 | **No indirect light and flat reflections.** Ambient and reflections both come from the sky (`ambient_light_source = 3`, `reflected_light_source = 2`). The sky's cubemap pass returns a flat gradient (`vortex.gdshader`, `AT_CUBEMAP_PASS`), so ambient is a uniform violet and wet/specular surfaces reflect a blank colour. Zero `ReflectionProbe`, `VoxelGI`, `LightmapGI`, SDFGI or SSIL in `main.tscn`/`environment.tres`. Windows and braziers cannot bounce or spill | `main.tscn` grep counts 0/0; environment keys listed above | Do in order, benchmarking each: (1) enrich the cubemap pass with a low-frequency vortex/star term so ambient and reflections have direction and colour; (2) `ReflectionProbe` boxes (update mode once, box projection, interior) at stair foot, landing, summit; (3) `VoxelGI` over the landing/nave (needs no UVs, unlike `LightmapGI`; bake in the editor, store `.res`; set `light_bake_mode` per light); (4) SDFGI only as a timed experiment (likely too heavy for 120 fps); (5) optional SSIL | A/B stills in the light lab: opposite wall receives a visible cool bounce from the window with GI on; reflection spheres show the window; cost within the budget table below |
| L4 | P1 | **Window light setup needs engine hygiene** (greybox kit, spec only): gobo `ImageTexture` is rebuilt per window with 32k GDScript `set_pixel` calls (D5), has no mipmaps and no `light_projector_filter` choice; spot `shadow_bias`/`shadow_normal_bias` untuned for thin mullions; an unshadowed omni (3.8) duplicates the spot (6.5) at the same spot; fog energy 3.2-3.6 per light may blow out the froxels; volumetric temporal reprojection is at its default and will ghost around moving lights | `gothic.gd::_lancet`, `_gobo` | Build the gobo once (static cache or PNG) with mipmaps; tune biases on close stills; drop the omni or lower it to a fill; add a local `FogVolume` (teal albedo, higher density) in front of each window to concentrate shafts instead of raising global density; compare `volumetric_fog_temporal_reprojection_amount` values | Shaft visible from 15 m in the light lab and in the real landing view; no ghost trail when the player walks through it; load time unchanged |
| L5 | P1 | **Directional (moon) shadow configuration is minimal.** 2 splits at 2048 (`project.godot`), max distance 22/38 m set in `main.gd`, no `directional_shadow_blend_splits`, default fade and pancake settings, no `soft_shadow_filter_quality` set, and `light_angular_distance = 2.5` in `atmosphere.gd::_moon` turns on soft (PCSS-style) shadows whose cost has never been measured. No shadow bias tuning for the stair risers | `main.gd` 94-98, `atmosphere.gd` `_moon`, `project.godot` | Enable `directional_shadow_blend_splits`; review `directional_shadow_fade_start`; set both `soft_shadow_filter_quality` project settings explicitly; measure the cost of `light_angular_distance` vs a fixed filter; tune `shadow_bias`/`shadow_normal_bias` against close stills of the steps | No visible split seam; no acne/peter-panning on stair risers in `stair_foot`/`landing` stills; moon shadow cost recorded |
| L6 | P1 | **Positional shadow atlas never configured.** Atlas size 2048 with engine-default quadrant subdivisions (not set in `project.godot`), shared by braziers, the lantern and now window spots. Hero spots with gobo/mullion shadows need larger tiles than lantern or brazier shadows | `project.godot` rendering block | Set the four quadrant subdivisions explicitly for the real light mix; inspect with `Viewport.debug_draw = Viewport.DEBUG_DRAW_SHADOW_ATLAS`; raise atlas to 4096 only if the budget allows | Debug view shows each shadowed light in a tile of the size you chose; no shadow pop when the player crosses 12 m |
| L7 | P1 | **Bloom, tonemap and flare are tuned blind.** `glow_bloom` is now 0.18 (was 0.04), threshold 0.94, intensity 1.05, blend SCREEN, exposure 0.92, AgX. HDR emitters (lava, flames, crystals, orb, window glass at 2-4) all cross that threshold, so haze risk is high. No `glow_map` (lens dirt), no `tonemap_white` tuning, window starbursts depend on the unwired kit and the sky starburst is invisible (D7) | `atmosphere.gd::_fog`; D7 simulation | Tune from the light lab against the reference metrics (2.2): very-bright share 0.1-1.8%, median luma 0.06-0.12. Try `tonemap_white`, Filmic/ACES vs AgX, `glow_map` dirt texture, and per-emitter HDR caps. Fix D7 (compute the burst from the star's own cell) or replace with a few billboard sprites. If streaks are wanted later, a `CompositorEffect` is the engine-native route | Palette stats within the 2.2 ranges for 3 landmark stills; no global milky haze at `valley_wide` |
| L8 | P1 | **SSR and DoF are on by default with little payoff.** SSR is on (28 steps) but the stone is roughness 0.62, so almost nothing reflects; the only mirror-like surface is the pond, which is alpha-blended and unreachable by SSR. DoF far blur starts at 20 m, softening every landmark beyond the first | `atmosphere.gd::apply_quality`, `gothic.gd::_pond` | Default SSR off until a low-roughness opaque surface exists; DoF defaults per view (start ~35 m, transition ~25 m) and expose both as "Cinematic" settings; add a Performance preset that turns off SSR, DoF, volumetric shafts | Settings menu has Performance / Balanced / Cinematic; default is Balanced and meets the frame budget |
| L9 | P1 | **SSAO is strong at low quality** (radius 1.55, intensity 2.05, quality 1 = Low) in a scene lit mostly by ambient. It may be darkening crevices more than shadows do, and it costs every frame | `environment.tres`, `project.godot` | A/B with 1.0 / 1.5 intensity; check `ssao_light_affect`; consider SSIL instead if GI stays absent | A/B stills show crevice depth without crushing mid-tones (near-black share stays 24-39%) |
| L10 | P1 | **Volumetric fog cost and injection.** Froxel volume 96 x 48 (project), length 40 m, anisotropy now 0.68. `atmosphere._fade_lights` forces `light_volumetric_fog_energy >= 1.15` on every non-hero light, so every crystal, lava, glimmer and brazier light injects into the fog. That is dozens of lights multiplying the fog cost | `atmosphere.gd` | Per-class fog energy in `LightPolicy`: 0 for tiny fills (glimmers, crystals), > 0 only for beacons and hero lights; measure fog cost with it on/off | Fog cost recorded; no visible loss of brazier glow |
| L11 | P2 | **Renderer defaults worth testing:** debanding for dark fog gradients; no AA by owner preference (see 0.7: do not add FXAA/TAA); anisotropic filtering for stair slabs at grazing angles | `project.godot` | Debanding and anisotropy 4 are already set (Cursor); no AA | Dark gradient in `valley_wide` shows no banding |
| L12 | P2 | **Two sources of truth for the environment.** `environment.tres` (baked: exposure 0.84, glow 0.85 / 0.05) disagrees with `atmosphere.gd::_fog` (exposure 0.92, glow 1.05 / 0.18, anisotropy 0.68), which wins at runtime. The editor preview and a rebake will mislead | both files | Make `bake_main.gd::_environment` call the same values, or document `atmosphere.gd` as the only source and delete the duplicates | Editor preview matches the running game |
| L13 | P2 | **Verify which graphics driver the Mac build uses** (Metal vs Vulkan via MoltenVK). README says "Vulkan or Direct3D 12" and the bake commands force `--rendering-driver vulkan`. Performance numbers differ between drivers | `README.md`, `AGENT_HANDOVER.md` | Record the driver in the F3 overlay and in every benchmark log | Every benchmark row states the driver |
| L14 | P1 | **Post bugs that live in engine code:** D8 (chroma pass mixes ungraded R/B into the graded colour) and D10 (flare shader double-counts brightness) | `grade.gdshader`, `flare.gdshader` | As in the defect table | Grade verified with `palette_stats.py` before/after |

### Light lab and measurement (build this first, then tune)

1. **Light lab scene** (`world/lab/light_lab.tscn`, primitives only): a wall block with a lancet-shaped hole (CSG), one `hero` window light, three spheres at roughness 0.1 / 0.4 / 0.8 (one metallic), an 18% grey card and a colour chart, a floor slab, one brazier. Three fixed cameras: window-facing, shaft-in-fog, reflection spheres. Toggle features from the command line (`--no-ssr --no-dof --no-gi ...`). This lets lighting be tuned without any art.
2. **Audit:** `tools/light_audit.gd` (written, **not yet run**) prints every light, its fade triple, fog energy and shadow state, plus the totals `LIGHTAUDIT total/omni/spot/shadowed_positional/fog_injecting`. Run it before and after every lighting change and keep the diff.
3. **Stills + stats:** `tools/capture.gd` for the three landmark views, then `tools/palette_stats.py`. Compare against section 2.2.
4. **Frame time:** the F8 benchmark with each feature on/off. Use `Viewport.DEBUG_DRAW_SHADOW_ATLAS` and `DEBUG_DRAW_OVERDRAW` for diagnosis. Playtesting and benchmarks run **only on the owner's Mac**. Log everything in `docs/lighting_log.md` (date, change, driver, avg ms, 1% low, shadowed lights, palette numbers).

Suggested frame budget at 120 fps (8.3 ms total at 1080p; **proposed allocations, not measured**): shadows (moon + positional) 1.5 ms, volumetric fog 1.2, SSAO 0.6, SSR 0.6, DoF 0.4, bloom + grade 0.5, GI 1.0. Revise after the first real measurements.

### Order of work

1. L1 + L2 (one `LightPolicy`, correct shadow and fade rules). Cheap, immediate payoff, and it frees budget for everything else.
2. D0 (wire `gothic.gd` greybox) together with the gobo cache and the hero-light exclusion from L1.
3. Light lab, `light_audit.gd` run, benchmark baseline, driver check (L13).
4. L3 steps (1)-(2), then re-measure; L4 shaft tuning with local fog volumes.
5. L5, L6 shadow tuning with close stills.
6. L7 bloom/tonemap/flare tuning against the reference metrics, including D7 and D8.
7. L8-L11 defaults, presets, debanding, AA.
8. L3 steps (3)-(5) (VoxelGI, SDFGI experiment) only if the budget allows.
9. L12 cleanup.

## 0.7 Owner-directed changes made 31 Oct 2026 (evening) and what to verify

Made by Claude directly (not by Cursor). **Nothing here has been run**: there is no Godot in the authoring environment, so every item is unverified until the owner plays it on the Mac.

| Change | Files | Notes |
| --- | --- | --- |
| **Anti-aliasing off, by design** | `project.godot` (`screen_space_aa=0`, `msaa_3d=0`; TAA never enabled) | Owner prefers the hard-edged look. **Do not add FXAA/TAA/MSAA/FSR.** This overrides L11's AA bullet and my earlier L15 proposal. Debanding stays on (it is dither, not AA). |
| FSR upscaling removed | `world/main.gd`, `world/vale.gd` | FSR 1 reconstructs edges, which reads as AA. Scaling is now always bilinear. |
| Internal render height follows the preset | `autoload/settings.gd::render_height_cap()`, `main.gd`, `vale.gd` | Performance/Balanced 1080 (unchanged), **Cinematic 1440**. The auto render-scale budget now follows the cap (before, it would have shrunk 1440 back to ~1080). Cost is unmeasured: if Cinematic drops below target, lower the cap in one place. |
| **Vale recoloured crimson -> violet at load** (no rebake) | new `core/world/vale_palette.gd`, called from `world/vale.gd` | Remaps: sky shader params, moon colour (#8F7DEB), fog light/albedo/emission, 4 fog volumes, terrain/stone/rock/bark/path/roof tints, leaves/grass/fern, water, gems, portal glass, ember and rift motes, red-hue lights (hue >= 330 or <= 14) to violet, mushroom caps (new `violet_amount` uniform in `world/cap.gdshader`). **Fire stays warm** (hearth, lanterns, braziers, flames): it is the one warm accent. |
| Violet sky + directional ambient | `world/sky/ember_skulls.gdshader` | Palette and star/moon colours changed. The cubemap pass now has a bright side facing the moon, so ambient and reflections get a direction (L3 step 1, vale only). |
| Violet grade | `world/post/grade_vale.gdshader`, `grade_vale_material.tres` | Same hue-band method as the stair grade (band 235-305 degrees, pull 0.34, warm and teal protected). No chroma block (avoids D8). |
| Bake script mirrored | `tools/bake_vale.gd` | Same colours, so a rebake matches the runtime result. Rebake still needs a GPU context. |

Cursor had already implemented L1/L2 (`core/world/light_policy.gd`) and the light lab (`world/lab/`) before these changes; they were not touched.

### Verify on the Mac (in this order)

1. Open the project in the editor once (new script, shader uniform) and check the Output panel for errors/warnings from `vale_palette.gd`, `cap.gdshader`, `grade_vale.gdshader`, `ember_skulls.gdshader`.
2. Run the Vale. Check: sky violet with skulls still readable; terrain/stone not muddy grey-purple; no red left except fire; mushroom caps violet; water violet; river fog not a flat purple wall.
3. `tools/capture.gd` on the vale views, then `python3 tools/palette_stats.py shot.png`: target is the reference's blue+violet share of coloured pixels (81-87%), very low warm share, median luma 0.06-0.12. If the Vale is too saturated or too bright, lower `hue_pull`/`split_amount` in `grade_vale_material.tres` before touching the lights.
4. Edges: confirm no softening anywhere (FXAA off). Shimmer on foliage and the stair edges is expected and accepted.
5. Cinematic preset: record frame time at 1440 versus 1080 (F8 benchmark).

### Known risks

- Red-hue light remap only catches lights in the red band; any other red-ish light (e.g. magenta mushroom caps with hue 320-330) keeps its colour.
- Baked multimesh instance colours (cap colours, spots) are still red in the data; only the shader pull hides it. A rebake with the new `bake_vale.gd` does not change instance colours either (palette array in `bake_vale.gd` lines ~695-700 still lists reds).
- Grass and ferns are now cool blue; if the Vale reads too monochrome, raise their green back toward teal (0.45, 0.85, 0.85).

## 1. The reference (what is actually in it)

An 11 s iPhone screen recording of a vertical stylised reel (image-generated look): three scenes with dissolves. Look reference only; **do not reproduce its specific characters** (the gnome fisherman, the frog creature, the wraith).

1. Black pond at night, a luminous spectral fish leaping from it; ripples and a streaked reflection; weeping willow, deep green foliage under blue haze; a gnome fishing on a mossy rock.
2. Tall faceless hooded wraith, pointed hat, long ragged layered sleeves, raising a hand toward a four-point starburst star; dense violet star field; radial cobbled plaza with icy blue-white speckle; stone balustrade with spires; mountains behind.
3. Hulking wet-skinned clawed creature with oversized eyes crouched in a ribbed gothic arch; clustered columns; ashlar masonry; one tall **cyan stained-glass window** glowing in blue mist; cyan light pooling on wet stone and water at the bottom; background arches softly blurred.

## 2. Reference vs game

### 2.1 Qualitative gap table

| Element | Reference | Game now (evidence) |
| --- | --- | --- |
| Hero light | Every shot has one dominant, motivated emissive source (fish, star, window) in a **complementary hue** (cyan/teal against cobalt), big bloom halo, visibly lighting its surroundings | Hero lights are amber braziers (`brazier.gd`, `lit_energy 3.2`). Bloom is timid: `glow_bloom 0.04-0.05`, `glow_hdr_threshold 1.05`, AgX tonemap `exposure 0.84` (`atmosphere.gd`, `bake_main.gd::_environment`) |
| Light through windows | Tracery silhouetted, light shafts into mist | **No windows in the stair zone.** Only one gate arch (`bake_main.gd:507`). Vale has an unshaded amber `vale_window` material (`bake_vale.gd:224`). No `SpotLight3D` anywhere in the project; no `light_projector` gobos |
| Volumetric shafts | Strong forward-scatter haze | `volumetric_fog_anisotropy = 0.28` (`atmosphere.gd`): near-isotropic, so fog glows but does not form shafts |
| Lens/star flare | Four-point starburst on the star; halo on window | None. Grep for `flare/lens` finds only robe hem flare |
| Architecture | Ribbed gothic arches, clustered columns, ashlar, balustrades with spires, radial cobbles | Cylinders and boxes: 14 pillars, 6 wall boxes, a 5-pillar ring (`_ruins`), plain stair slabs |
| Surface response | Very high-frequency masonry; cold specular glints on edges and wet cobbles; deep black crevices | Triplanar tiling Voronoi/fbm textures from `gen_textures.py`; `_triplanar()` takes albedo + normal + tint only (no roughness/specular input). SSR not enabled (no `ssr_` anywhere) |
| Characters | Wraith fills the frame: layered, fringed, streaky cloth, faceless pointed hood; creature has a readable grotesque face, huge hands | Cylinder/sphere primitives; cloth shader removed (`robe_cloth.gdshader` unused); third-person camera 4.4 m back, FOV 58 |
| Sky | Dense violet star field with dust, starburst on a key star | Vortex shader, sparse stars (`step(0.9975)`); keep the vortex, add density and starbursts |
| Camera/depth | Foreground framing (arch, rocks), blurred background, strong vignette | No DoF / `CameraAttributes` anywhere. Vignette exists in the grade shader only |
| Water | Black mirror water, ripples, reflected glow | Stair has lava; Vale river uses `water.gdshader` emission, no reflections |

### 2.2 Measured palette (reference frames, UI cropped)

Script: `tools/palette_stats.py` (this repo). Crop used: top 11%, bottom 24%, right 12% removed. Coloured pixel = S>0.25, V>0.12. Hue shares are of coloured pixels.

| Scene | Coloured | Median luma | Near-black (<0.05) | Very bright (>0.8) | Red | Org/Yel | Green | Teal | Blue | Violet | Magenta |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pond + fish | 65% | 0.114 | 24% | 1.6% | 0 | 0 | 6 | 13 | 81 | 0 | 0 |
| Wraith plaza | 56% | 0.061 | 39% | 0.1% | 0 | 0 | 9 | 10 | 39 | 42 | 0 |
| Gothic arch | 61% | 0.09 | 31% | 1.4% | 0 | 0 | 0 | 13 | 87 | 0 | 0 |

Takeaways (indicative: iPhone screen capture of a compressed reel, and the README uses its own thresholds):
- Cool palette is right and already close: blue+violet 81-87%, green+teal 6-14%, **zero warm**.
- Brightness is not the gap either: median luma 0.06-0.12 with 24-39% near-black, similar to the README's "dark" targets.
- What differs is the **tail**: 1.4-1.8% of pixels are very bright hero-light/bloom in two of three scenes, and the whole frame is full of high-frequency detail.
- The reference has no amber at all. Amber braziers are the game's own gameplay-readability convention (warm = safe). Owner decision: keep amber for safety only and use cyan/teal for "sacred/uncanny" hero lights. This pairing is what gives the reference its look.

## 3. Overall impression

The game currently reads as a clean low-poly night scene with good fog and a nice sky. The reference reads as a **dense, lit, gothic image**: every frame has one thing you cannot look away from and a lot of rough detail around it. The stair-over-chasm composition is already strong; it needs light, architecture, and surface to carry it.

## 4. Root causes (ranked)

1. **RC-A (P0) Lighting pipeline has no hero light, flare or shafts.** Timid bloom, near-isotropic fog, no spot/gobo lights, no starburst, no windows to shine through.
2. **RC-B (P0) No gothic architecture.** Primitive pillars and boxes cannot hold a window, an arch, or a silhouette.
3. **RC-C (P0) Material fidelity.** Tileable low-detail textures, no roughness/specular variation, no wet surfaces, no reflections.
4. **RC-D (P0) Character and creature fidelity and framing.** Placeholder primitives, no cloth, one tiny enemy, no low-angle or foreground-framed camera, no DoF.
5. **RC-E (P1) Grade is secondary**: hue collapse (200-290 pull 0.55, saturation 1.4, blue split-tone) flattens greens and the teal complement. Fix it, but it is not the main cause.
6. **RC-F (P1, from rev 1) Gameplay gives dark no weight**: free death, one stateless chaser, light is permanent, no audio, no lore.

## 5. Issue list

| # | Sev | Area | Issue | Where |
| --- | --- | --- | --- | --- |
| 1 | P0 | Lighting | Bloom too low; no HDR hero emitters; no complementary cyan | `atmosphere.gd`, `bake_main.gd::_environment` |
| 2 | P0 | Lighting | No window light shafts (no spot lights, no gobos, fog anisotropy 0.28) | `atmosphere.gd` |
| 3 | P0 | Lighting | No lens/star flare | none |
| 4 | P0 | Architecture | No windows, arches, tracery, spires, balustrades, clustered columns | `bake_main.gd::_ruins`, `_stair` |
| 5 | P0 | Materials | Albedo+normal only; no roughness/specular maps; no wet look; SSR off | `_triplanar`, `gen_textures.py` |
| 6 | P0 | Character | Primitive body, no cloth, symmetric, glowing mage trim | `default_loadout.gd`, `character_rig.gd` |
| 7 | P0 | Enemies | One tiny shade; no large, grotesque, readable creature | `shade.gd` |
| 8 | P0 | Camera | No DoF, no framing, FOV 58 from 4.4 m back | `bake_main.gd::_player`, `player.gd` |
| 9 | P1 | Grade | Hue collapse and blue wash flatten greens/teal | `grade.gdshader` |
| 10 | P1 | Sky | Few stars, no starbursts | `vortex.gdshader` |
| 11 | P1 | Water | No reflective black water on the stair | none |
| 12 | P1 | Gameplay | Free death, `hollow_count` unused; light permanent | `player.gd`, `brazier.gd` |
| 13 | P1 | Audio | None | new autoload |
| 14 | P1 | Lore | Six toasts, no NPCs/inscriptions | `Events.toast` sites |
| 15 | P2 | HUD | Constants not zone-themed; dev key line visible; default Cinzel; Gloom state colour-only | `ui/hud.gd` |
| 16 | P2 | Motion | No foot IK; no hit/landing weight | `character_rig.gd` |
| 17 | P2 | Code | Delete unused `robe_cloth.gdshader` only if cloth is not reinstated (F8 reinstates it) | |

## 6. What works (do not regress)

- Stair over lava chasm toward the rift sky.
- Cool cobalt/violet palette and the existing `sharpen` pass in the grade (the reference is crisp).
- Fog, vignette, grain, and the warm-light-means-gameplay rule.
- Voice of the text ("Hollowed", "the glass remembers another night").
- Architecture of code: data-driven `EquipmentPiece`, `Events` bus, baked zones.

## 7. Feature list (build order, highest look-per-effort first)

Each item lists acceptance criteria. Gate new rendering features behind `Settings` so a Performance preset keeps the 120 fps goal.

### F1. Hero-light and bloom pass
- Define a **motivated light rule**: each landmark view has one dominant emissive hero source (HDR 4-8), cyan/teal (about hue 165-185) or spectral blue, with an amber brazier as a secondary family.
- Tune `glow_*` (start: `glow_bloom` 0.12-0.25, `glow_intensity` ~1.0, threshold 0.9-1.0, soft-light or screen blend) and test **AgX vs ACES/Filmic** (AgX compresses highlight saturation; reference highlights are punchy). Test exposure 0.84 against 1.0.
- Acceptance: A/B stills at the same view show a visible halo on the hero light; hero pixels (>0.8 luma) are 0.5-2% of frame in hero views (see 2.2); median luma stays near 0.06-0.12.

### F2. Window light shafts
- For each window add a shadowed `SpotLight3D` behind it (cyan), with `light_projector` set to the window tracery as a gobo, and `light_volumetric_fog_energy` 2-4.
- Raise `volumetric_fog_anisotropy` to roughly 0.6-0.8 near these scenes so fog scatters forward into shafts; keep fog length/density budgeted.
- Budget: at most 2 shadowed spots visible at once; distance-fade the rest (same approach as `Brazier`).
- Acceptance: tracery pattern visible in fog and projected on the floor; no per-frame spikes in the F8 benchmark.

### F3. Flare and starburst
- Cheap: additive billboard starburst sprites attached to bright emitters (stars, staff orb, windows), occlusion-faded (raycast or depth test) and distance-scaled.
- Later: a `CompositorEffect` for screen-space streaks/ghosts if sprites are not enough.
- Add 4-point starbursts to the 3-6 brightest vortex stars (sky shader) and to the staff orb.
- Acceptance: a visible starburst on key lights from the player's default camera; no flare through geometry.

### F4. Gothic architecture kit [PARKED: modelling. Wire the existing greybox only, see 0.6]
- New bake functions in `bake_main.gd` (rebake required): `_arches()` (ribbed pointed arches), `_windows()` (tall lancet windows with mullions + emissive glass texture), `_columns()` (clustered shafts with capitals), `_balustrade()` and `_spires()`, `_plaza()` (radial cobble ring, like the wraith scene).
- Replace the 14 plain pillars and 6 wall boxes in `_ruins()`; frame the stair with a **nave of arches** so the player walks through repeated, lit openings toward the rift.
- Put at least one cyan window as the hero light of the landing and one at the summit.
- Acceptance: three landmark views (stair foot, landing, summit) each contain an arch frame and a lit window; draw calls stay within the F3 baseline +15% (measure first).

### F5. Material pass [texture/model generation PARKED; SSR, roughness and rim engine settings stay in scope, see 0.6]
- Extend `gen_textures.py`: ashlar courses with mortar and chips, carved relief tiles, cobble rings, moss in joints, plus **roughness/AO maps**; let `_triplanar()` accept a roughness map.
- Add cool rim lighting on stone (`rim_enabled` with cobalt tint) and wet patches (low roughness variation) near the chasm and plaza.
- Enable SSR (`ssr_enabled`, tuned steps and fade) on a quality preset for wet stone and water.
- Acceptance: stone shows cold glints from the moon and windows; surfaces look wet near water/lava without per-material hacks.

### F6. Grade revision (replaces rev 1's blood-red steering)
- Reduce `hue_pull` (about 0.2), `split_amount`, and the saturation 1.4 boost; let foliage stay green under blue light; add a protected teal/cyan band for hero lights and window glow (the amber/warm band protection stays).
- Add a small radial chromatic aberration and keep vignette, grain, sharpen.
- Acceptance: run `tools/palette_stats.py` on capture stills: blue+violet 80-90% of coloured pixels, green+teal 6-14%, warm below about 5% outside braziers. Update the README palette table to these metrics.

### F7. Camera and depth
- `CameraAttributesPractical` with far DoF (`dof_blur_far_enabled`, distance/transition/amount) behind a setting; keep disabled in the Performance preset.
- Add authored framing: foreground arches/rocks at the stair foot, low-angle vistas at the summit; optional lower camera and tighter FOV at landmark views.
- Acceptance: background arches soften behind the subject in hero stills; DoF cost measured with F8.

### F8. Characters and creatures [PARKED: modelling]
- **Player**: tall asymmetric hooded silhouette: pointed/hooded faceless head, long fringed sleeves, layered tattered cloth hanging from belt/shoulder, one heavier side. Reinstate cloth (`robe_cloth.gdshader` + fringe cards) and build through `EquipmentPiece` sets, not rig code. Reduce glowing trim to one motivated light (lantern or staff).
- **Creature**: add one large grotesque enemy (hunched, wet skin, oversized hands and eyes) as a gate guardian beneath a window; our own design, not the reference's. Show it from a low angle in a landmark view.
- **Shade**: scale up, give it a legible silhouette and telegraph.
- Acceptance: a front-on still of each reads as a distinct, unmistakable silhouette against the background at 1080p.

### F9. Sky
- Increase star density and add dust bands; starbursts on key stars (F3). Keep the vortex.

### G1-G6. Gameplay weight [OUT OF CURRENT FOCUS]
- **G1 Scarce light**: braziers use fuel; thin out harmless wisps/fireflies; some glowing things become hazards.
- **G2 Consequence**: Hollowing drops a retrievable echo, scars the character, raises baseline Gloom; add save/load.
- **G3 Threat**: shade states (stalk, reposition, lunge, flee-from-light), telegraphs, first real bestiary.
- **G4 Rift as presence**: visual corruption with proximity; something vast in the vortex.
- **G5 Audio**: new `Audio` autoload subscribed to `Events`: Gloom-driven layers, brazier crackle, positional shade whispers, Hollowed sting, silence as a tool.
- **G6 Lore and HUD**: lore interactables (same pattern as `Brazier`), zone-themed HUD colours, hide dev key hints, add a non-colour Gloom cue.
- Gore/body props from rev 1 are demoted to minor set dressing: use ruined architecture, toppled statuary and a few fallen figures near the windows rather than blood.

## 8. Constraints and traps

- **Never hand-edit generated files** in `world/zones/ascension/` (`*_mesh.res`, `*_shape.res`, `environment.tres`, `bake_info.gd`). Change `tools/bake_main.gd` and rebake. Fog lives in `_fog()`.
- Bake with a GPU context, not `--headless`; set `custom_aabb` on every baked `MultiMesh`.
- New `class_name` scripts need `godot --headless --path . --editor --quit` before `-s` tools see them.
- Pure script/shader/settings edits need no rebake; architecture, materials built in `_materials()`, and fog/environment do.
- **Performance**: 120 fps minimum at 1080p is unmeasured on hardware. Baseline with F8 before changes. Known suspects: volumetric fog, SSAO, ~139 foliage chunk draw calls. Shadowed spots, SSR and DoF each go behind settings.
- Owner constraint: playtest only on the owner's Mac (M4 Pro). Cloud may bake/export, but no long verification renders there. Return an exported build plus the list of views to check.
- **Proof of change**: capture the same views before and after with `tools/capture.gd`, run `tools/palette_stats.py` on them, and attach both.
- Keep `assets/provenance.csv` updated for every new asset. Do not copy specific existing characters or scenes from the reference; use its lighting and architectural grammar only.
