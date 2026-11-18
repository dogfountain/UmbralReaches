# r39 brief: critique the look and the performance brutally, then improve both

Luke, 18 Nov: "After combat you need to do a visual agent, same model with extra, brutally critiquing looks and performance to improve."

You are that agent. You start after the map audit and the combat pass have been merged into master. You own two things across the whole game:
- **How it looks:** the grade, light, materials, shaders, sky, fog, foliage, water, VFX, characters and creatures on screen, the UI's look.
- **How it runs:** frame rate, 1% lows, hitches, load time, memory.

Read this brief end to end. Then read:
- `AGENTS.md`;
- `docs/PILLARS.md`;
- `docs/r39/CRITIQUE.md` (its world, light, performance and QA seats);
- `docs/r39/4_light_visuals.md`, `docs/r39/light_backlog.md` and `docs/r39/3_world_models_textures.md`;
- `docs/r39/map_audit.md` and `docs/r39/combat_fix.md` (what was just fixed, and what they left for you);
- `.cursor/skills/umbral-donts`, `umbral-culling` and `umbral-nights`;
- the last fifty rows of `docs/DECISIONS.md`.

Keep a live checklist at `docs/r39/visual_perf.md`, with every finding, its evidence, its fix and the commit. It is how the lead resumes you. This should take you many hours. Do not report until every finding is fixed, or marked not fixable with the reason.

## Luke's direction (binding)

- **Art direction:** push the look toward Enshrouded's style, to an extent: painterly, rich materials, a graded night that still reads. World of Warcraft is a fair source of ideas (not its assets or names).
- **Dark night, bright landmarks:** a darker moon and dark land. Fires, windows and mystery lights at landmarks read from afar.
- **Asset bar:** every model is authored in Blender with render review. Code-built kits and box art are rejected. You may author and replace models (the map audit's F28 list of code-built models is yours: Climb towers, Wardens' towers, Titan wardens, the Sleeper, hermit caches, stepped cairns, and the rest). Regular enemy models stay as they are (Luke: "no regular enemies stay same for now").
- **Icons:** every icon is painted 2D icon art from the in-house kit, never glyph shapes.
- **Animation:** smoothing is critical: no pops, snaps or stepping. Interpolate low-rate updates.
- **Frame stutter is Luke's top complaint.** Any visual gain that costs a hitch is a loss.
- **Never:** never enable dynamic resolution (the code stays in, off). Never rebake `world/main.tscn`. Never cut content.

## The critique: brutal, by seat

Measure and capture first:
- **Perf:** one baseline perf tour (`zz/perf_tour`) and one profile of the worst places: frame times, 1% lows, every spike over 8 ms with its cause, draw calls, primitives, shadow cost, VRAM, load time.
- **Look:** stills and short strips at each region's best and worst views, through the real camera and grade. Reuse `zz/map_audit_shots` (its grid and places) and `tools/play_capture.sh`.

Read every image at full size.

Write the critique into `docs/r39/visual_perf.md` from each seat below. Nothing is "fine". For each finding: what, where, why it matters, and what good looks like (name the reference).

**Art director**
- Does the game have one look?
- Palette and value structure.
- Where it falls short of Enshrouded.

**Lighting artist**
- The grade (CRITIQUE.md: one teal hue).
- Moonlight and shadows, GI and fog.
- Sources without light and light without sources.
- Landmarks that should read from afar.

**Environment and material artist**
- Masonry (CRITIQUE: a voxel grid), wood, ground and terrain blends.
- Tree crowns (flat domes).
- Grass (the loudest thing in the frame).
- Repetition and tiling.

**Tech artist**
- Shader quality and cost.
- LODs and impostors.
- Pop-in, z-fighting, shimmer and aliasing.
- Material count and variants.

**Character and VFX artist**
- The wanderer, villagers, bosses on screen.
- Spell and hit VFX, telegraphs, weather, particles.

**UI artist**
- HUD, menus, map, icons, fonts, readability on the night.

**Performance engineer**
- Every hitch:
  - first-use shader compiles (pre-warm behind the loading screen);
  - streaming;
  - GC;
  - the light director.
- CPU per frame, GPU per pass.
- Draw calls, shadow casters.
- The Realm's build time and warm boot.

## Improving it

Then fix every finding, worst first, end to end. Luke wants work massive and finished, not "partly worked".

**Rules**
- **Perf budget:** a visual change must not lower the 1% lows or add a spike. Pay for quality with savings elsewhere: LODs, impostors, merged draws, cheaper shadows.
- **Re-capture (Luke, 18 Nov):** captures follow the same rule as tests. Make every fix first, then ONE re-capture pass of everything you changed. The same goes for one final perf tour to compare with the baseline. A single short measurement that settles a specific doubt is fine.
- **Tests:** none while you build. When every fix is in, run `tools/run_tests.sh --quick`, then the world tests that cover what you touched. Then fix what they find.
- **Code:** typed calls, not `.call("name")`/`has_method`. Run `tools/lint.sh` any time. Follow Godot practice (AGENTS.md).

## Where you work and machine rules

- **Clone:** your own APFS clone on your branch, made by the lead from master after the combat merge. Its path is given in your prompt. Commit there with plain messages, never push; the lead merges.
- **Locks:** one Godot and one Blender process on the machine at a time. Take `mkdir /tmp/umbral_godot.lock` (retry every 30 s) around every Godot run and `/tmp/umbral_blender.lock` around every Blender run. `rmdir` the lock when done, also on failure. Never wait with a pgrep loop.
- **Watchdogs:** give every run a watchdog. If a run fails to load (a parse error), kill it at once rather than letting it hold the lock.
- **Scratch:** use `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/visual_perf/`. Keep the before/after pairs and delete the rest as you go (the disk filled once).
- **Commits** come only from Luke: never add a `Co-Authored-By` line or any AI attribution.

## Report

Only when the checklist is done, report:
- your branch and commits;
- the headline findings by seat;
- what you fixed, with before/after paths;
- the perf baseline against the final tour (average, 1% lows, worst spikes, load time);
- what you could not fix and why;
- the test results.
