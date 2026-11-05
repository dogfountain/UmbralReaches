# Enshrouded vs Umbral Reaches: art direction, lighting, materials, HUD, feedback

ENS art pass (2026-11-05). Luke allowed pushing the look toward Enshrouded's "to an extent". We keep our
own night, story, names and designs. No Enshrouded asset, character, location or UI art is copied:
what follows are principles, rebuilt with our own shaders and code.

## What Enshrouded does (from reviews, guides and its public material)

- **Lighting is the strongest feature.** Reviewers single out the lighting as what carries the
  look. The engine is Keen's own voxel engine (Holistic, Vulkan) with dynamic GI fed by the voxel world.
- **Nights are dark, and torches matter.** Most areas need a torch at night. It avoids the
  "moon-washed" grey night of many survival games. Warm torch and fire pools against cool
  blue-teal night is the core value structure.
- **The Shroud is a coloured volumetric fog** (teal) that lies in valleys and ruins. Fog height and
  colour carry danger and depth.
- **Materials are stylised-realistic and clean.** Textures read smooth or painted rather than gritty
  photo-noise. Moss and lichen give the detail, and foliage is dense, saturated and varied in hue.
- **HUD:** a compass strip at the top with diamond markers for tracked quests and waypoints, a quest
  tracker that can be contextual, vitals bottom left, and an action bar. Damage numbers carry
  qualifiers ("Effective" / "Resisted").
- **Sound:** distinct footstep surfaces, satisfying harvest and mining hits, and per-biome music. The
  Shroud shifts the ambience (birdsong gives way to crows and monsters).

## Where we stood (before)

`shots/look_*_ensA_before.png`, sheet `shots/look_sheet_ensA_before.png`.

- The grade (world/post) carried a "crunchy PS2" finish: unsharp mask 1.85 (clamp 0.11), RGB
  grain 0.038, chroma split 0.0018, saturation x1.6. Gravel, grass and the wanderer's robe sizzled.
  This was the main thing that read as un-Enshrouded: noise instead of paint (r30 critique 13).
- Warm light survived the grade only when bright and saturated. A lantern on grey ground mixes
  with the blue moon into a low-saturation warm grey, which was pulled blue, so **the player's lantern
  lit no warm pool**. That is the opposite of Enshrouded's torch-at-night look.
- Open ground under the moon was bright and flat (`brightness` 1.35), leaving no room for light pools.
- Foliage was one flat green per atlas texel, with a small sine mottle.
- Hits: a violet spark burst (the grade turned it blue) and a plain floating number.
- HUD: objective lines top right (story), plain-text pickup lines. No compass.

## Took / adapted / skipped

| Enshrouded trait | Verdict | What we did |
| --- | --- | --- |
| Clean, painted surfaces, no photo-noise | **Took** | Grade: sharpen 1.85 -> 0.95, clamp 0.11 -> 0.05, grain 0.038 -> 0.018, chroma 0.0018 -> 0.0008, saturation 1.6 -> 1.36 (r30 critique 13). |
| Warm torch pools vs cool night | **Adapted** | Grade `warm_lean`: pixels where red leads blue (r > 1.5 b) are lit by a warm source and keep part of their hue (0.7). `warm_saturation` 1.55 on protected warm vs 1.36 elsewhere. Player lantern pool wider (LightPolicy `player_lantern` x1.12 energy, x1.4 range; no shadow, so cheap). Open ground darker (`brightness` 1.2). |
| Dark nights, no moon-wash | **Adapted** | Darker open ground, and exposure 1.2 -> 1.12: the calmer saturation turns saturated blue chroma into luma (desaturated blue is brighter), so without it every view read ~5 luma brighter. The moon key stays: azure moonlight is ours. |
| Coloured volumetric fog in hollows | **Adapted** | Height haze below y 1.2 (`fog_height_density` 0.025: plain depth fog, free). Volumetric density 0.011 -> 0.012. Anisotropy 0.32 -> 0.5 and moon fog energy 1.35 -> 1.45: forward scatter makes the moon side glow and shafts read. Ours stays azure/indigo (the Shroud's teal is theirs). |
| Saturated, varied foliage | **Took** | `realm_foliage.gdshader`: each plant or crown leans yellow-green or blue-green (instance hash + a broad world patch), and leaves run dark at the held base to light at the free tip (UV2.x): a painted value ramp. Greens are protected by the grade, so the variation survives. |
| Moss and lichen detail on ground | **Adapted** | `realm_ground.gdshader`: a mid-scale drift layer between moss-green and cold slate patches, and the layers' AO darkens the albedo itself (`cavity` 0.45): dark seams, lit tops. |
| Magic reads apart from the world | **Took (r30 critique 3b)** | Grade `violet_protect` 0.6: bright, saturated violet (250-300 deg, S > 0.6, V > 0.5) keeps part of its hue and skips the split tone. Dull violets (the sky's cast) are still pulled. |
| Hit feedback: flash + sparks + punchy numbers | **Took** | `Vfx.impact(at, color, dir, big)`: a 0.15 s four-point flash star (warm white core, the hit's colour at the tips), sparks thrown away from the blow, a warm core puff, and a short flash light on big hits. Enemy hits use it. `HitText` numbers punch in (x1.7 -> x1 in 0.12 s, back-eased), and big hits get a warm outline. |
| Compass strip with markers | **Adapted** | `ui/compass.gd`: 180 deg band at the top centre, ticks every 15, the four winds in Cinzel (north in lantern gold), our landmark beacons as diamonds in their own colour with distance (pinned, dimmed, to the band's end when behind you), and the nearest four braziers (hollow ember diamond = cold, gold dot = lit). Our own engraved style, not theirs. |
| Pickup popups | **Adapted** | Satchel feed lines sit on a dark plate with an edge in the item's own colour and fade in. Fixed: the "merge a burst of ash" test never matched once the total was appended (now by item id). |
| Damage qualifiers ("Effective" / "Resisted") | Skipped here | Combat agent's area. HitText already shows "warded", "staggered". |
| Voxel GI, digging, building | Skipped | Not our game. SDFGI/VoxelGI cost too much at 120 Hz on this map size. |
| Teal Shroud colour, biome palettes, UI art | Skipped | Theirs. |
| Per-biome music, Shroud ambience shift | Skipped here | Audio agent / world_sound. Ambience already has zones (core/world/ambience.gd). |

## Files

- `world/post/grade.gdshader`: new uniforms `warm_saturation`, `warm_lean`, `warm_lean_lo`, `violet_protect` (all default to the old behaviour).
- `world/post/grade_material.tres`: retuned values (above).
- `core/world/atmosphere.gd`: `HAZE_TOP` / `HAZE_DENSITY` height haze, volumetric density and anisotropy, moon fog energy, exposure 1.12.
- `core/world/light_policy.gd`: `player_lantern` ILLUM.
- `world/realm/realm_ground.gdshader`: `cavity`, `patch_hue`, `brightness` 1.2.
- `core/world/realm/flora/realm_foliage.gdshader`: `hue_var`, `tip_light`, `base_dark`.
- `core/vfx/vfx.gd`: `impact()` (new; existing API untouched). `core/vfx/hit_text.gd`: punch-in.
- `core/enemy/enemy.gd`: `take_hit` calls `Vfx.impact` (one line, in place of the violet burst).
- `ui/compass.gd` (new, no class_name, 500 px wide so it clears the objective lines), hooked by one line in `ui/hud.gd`. Beacons join group `landmark_beacon` (one line in `core/world/realm/landmark_beacon.gd`) so the compass never searches the tree.
- `ui/satchel.gd`: pickup toast plate and merge fix.

## Measurements

Shots (zz/look_shots, real camera and grade, HUD off, isolated HOME): `shots/look_<view>_ensA_before.png`
and `shots/look_<view>_ensA_after.png`, sheets `shots/look_sheet_ensA_before.png` / `_after.png`.
Combat (zz/trailer `--only=fight_otc,fight_side`, Movie Maker): `shots/ensA_fight_after_sheet.png`
(flash stars at the hits). HUD with the compass: `shots/ensA_hud_compass.png`. The world agent was
adding geometry in parallel, so some views (fen willows, thornwood, meadow shrubs) changed between
the two sets for reasons other than this pass.

Mean luma / saturation (ffmpeg signalstats, 0-255), before | after:

| view | before | after |
| --- | --- | --- |
| spawn | Y 59.8 S 26.6 | Y 63.1 S 22.2 |
| meadow | Y 46.6 S 21.2 | Y 47.0 S 17.6 |
| thornwood | Y 33.4 S 14.8 | Y 33.3 S 12.4 |
| henge | Y 44.2 S 23.0 | Y 47.2 S 19.7 |
| fen | Y 50.6 S 23.9 | Y 52.4 S 14.3 |
| crossing | Y 42.6 S 19.7 | Y 45.1 S 16.8 |
| tavern | Y 40.0 S 18.3 | Y 41.9 S 15.3 |
| summit | Y 42.7 S 37.8 | Y 45.2 S 37.6 |

Same night value; less neon chroma (the point of the calmer grade); warm pools and foliage hue
variation are local, so they barely move the means.

GPU cost: zz/perf_tour `--points-only --stress=2` (2x2 pixels, so the GPU is the bottleneck and fps
compares GPU cost), with the three changed shaders A/B'd in memory (`--shader=` swapping in the
originals). Steady points, new vs old fps: spawn_west 104.1 / 102.9, thorn_edge 102.2 / 100.7, meadow
100.0 / 99.7, fen 107.0 / 108.6, glade 96.2 / 97.7, spindle 96.8 / 97.0, summit 101.0 / 100.5,
barrows 95.1 / 96.1, chapel 95.1 / 95.1, tavern_in 91.8 / 90.9, henge 97.3 / 98.0, rim 87.2 / 86.8.
Differences are within run noise (+-2 %). Several windows in the runs were disturbed by other
processes on the GPU (e.g. a whole leg at ~52 fps) and are left out. At 2x2 pixels every point stays
above 86 fps (<= 11.6 ms), so at the real resolution the frame is far inside the 8.3 ms budget for
120 Hz. The environment changes (height haze, anisotropy, density) do not change the froxel grid
or the pass count, and the compass is a few hundred 2D draw calls' worth of lines.

## Left / next

- The thorn hedges at the henge now read red-brown rather than violet-brown (the warm-lean term
  keeps red that leads blue). It suits a bramble hedge; if the lead wants them dark again, lower
  `warm_lean` or raise `warm_lean_lo`.
- The player's lantern pool is still small (the rig drives the light's energy to 1.85 every
  frame, so LightPolicy's energy factor is overwritten; only the range change holds). A bigger warm
  pool would need character_rig.gd to scale its flicker by the ILLUM energy.
- The summit dais view is a uniform blue fog box (world geometry or a FogVolume): not touched.
- Damage qualifiers ("resisted" / "weak") and per-biome music: other agents' areas.
- The wanderer's robe still glows neon-blue; it is the wanderer's own shader (do not restyle).
