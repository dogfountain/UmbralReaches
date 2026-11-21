# r39 brief: shader / pipeline pre-warm (no first-sight stalls)

Luke, 21 Nov: "Shader pre-warm". Master is 5d93aca6 and it is deployed. Frame stutter is Luke's top complaint.

## Where we stand

Read `docs/r39/hitch_warm.md` (lane C) and `docs/r39/fps_pass.md` first.

### What exists

- **The loading screen's warm tour** (`ui/loading_screen.gd`, phase "warm") draws every world material once under the cover. It also covers:
  - panels (`ui/panel_warm.gd`), loot (`ui/loot_warm.gd`) and night life (`core/world/night_life/night_warm.gd`);
  - spells, the attack and boss kits, and the horse rig.
- **BossArena** builds the boss hidden on the approach (`_stage_boss`) and gives it one speck-sized first draw (`_stage_draw`).
- **`zz/perf_tour.gd`** prints `PSO at start of play` / `at end` counts (canvas/mesh/surface/draw/spec), plus `--hitches --probe`, `--bosses` and `--loading`.

### What is left

- Pipeline counts at the start of play and at the end of a `--bosses` tour go from ~992 to ~1245. That is **~250 specialisation compiles in play**: a material seen for the first time under a new light, shadow or fog state, at a view or a spawn.
- **Known stalls:**
  - The Thornwarden's staged first draw compiles two pipelines: **76-136 ms on a cold shader cache** (seen once a cache is cleared).
  - `spec+11` on each boss pull's visible parts (boss at full size, bar, rift), then frames of 15-18 ms.
  - MapSketch's charcoal cue (a GPUParticles3D): 38 ms.
  - A spitter spawn: `spec+9`, 14.6 ms.
  - A few `spec+2/+3` at views.
- **A real player meets each of these once per shader cache state:** after an update, a driver change, or a first launch.

## Goal

**Zero frames over 16 ms from pipeline or shader compiles in play, on a COLD cache.**
- Isolated HOME, with Godot's shader cache and the pipeline cache deleted before the run.
- Measure: the perf tour with `--loading` (the real loading screen first), the `--bosses` tour, the first fight, a spell of each school, a fast travel, the map, and a horse mount.
- Report the in-play `PSO` delta: it should be near 0.

### How (find what actually works in Godot 4.7 Forward+ on Metal, then build it end to end)

1. **Find where the compiles come from.**
   - Log each in-play compile with its material/shader and the render state behind it: omni/spot count, shadows, fog, the specialisation bits.
   - Use the RenderingServer / RenderingDevice stats, `--hitches` (it names the pipelines compiled per slow frame), and the engine's verbose output.
2. **Read the engine's own options and use what helps:**
   - the ubershader / background compile settings;
   - `rendering/shader_compiler/shader_cache/*`;
   - the RenderingDevice pipeline cache (`rendering/rendering_device/pipeline_cache/*`), and whether it persists on Metal;
   - `RenderingServer` pipeline compile hints;
   - whether a project setting change alone removes most stalls.
3. **Widen the warm tour to the states play reaches.** Each material under:
   - the light counts play uses (0, a few, the max omni per object);
   - shadowed and unshadowed;
   - fog and volumetric fog;
   - the boss arena's lighting;
   - particles and VFX at their real draw modes;
   - every enemy kind's spawn effects;
   - the map, the UI panels' shaders.

   Draw them small, behind the cover, and spread over frames, so the loading screen keeps animating.
4. **Cache what can be cached on disk,** so a second launch is fast. Measure the first launch and a warm launch.
5. **Load time:**
   - Today: ~15-17 s to playable headless, 25 s to realm_done windowed.
   - Pre-warm may add a little on a cold cache only, at most +3 s. A warm cache must load no slower than today.
   - Report both.
6. **The boss pulls:** no `spec` compile in the pull. Warm the pull's visible parts (boss at full size in its arena light, the bar, the rift) on the approach, at the speck, or under the loading screen.

## Rules

- **Clone:** work only in your clone (path in your prompt), on branch `shader-warm`.
  - Plain commit messages, small commits. Never push; the lead merges.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:**
  1. Measure once at the start: a cold-cache `--loading` tour, the `--bosses` tour, and the compile log from step 1 of How.
  2. Build every fix, with no re-measures in between. Short diagnostic runs that a fix needs to choose its approach are fine.
  3. Measure once at the end (cold and warm cache).
- **Do not run any tests** (no `run_tests.sh`, no `--quick`). The lead runs the one suite after merging. Parse-check headless so it loads.
- **Godot lock:** one Godot process on the machine at a time.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` after, also on failure.
  - Stale only if `pgrep -x godot` (never `pgrep -f`) shows no Godot for 60 s.
  - Watchdog every run with a background `sleep N; kill PID` (macOS has no `timeout`). Kill only your own PIDs, never `pkill`. Never wait with a pgrep loop.
  - Windowed runs: parse-check headless first, then `--always-on-top` (a hidden window is throttled to 0% CPU). Check CPU 20-30 s in.
- **Cold-cache runs** use an isolated HOME in your scratch. Never delete Luke's real caches under `~/Library/Application Support/UmbralReaches` or the Godot editor's.
- **Never:**
  - dynamic resolution;
  - rebaking `world/main.tscn`;
  - cutting content or lowering visual quality;
  - new shadowed lights;
  - per-frame work in play.
- **Code:** typed calls (no `.call("x")`/`has_method`), files under 1000 lines, `tools/lint.sh` clean. Follow AGENTS.md and `.cursor/skills/umbral-donts`.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/shader_warm/`. Delete what you don't need.
- **Live checklist:** `docs/r39/shader_warm.md`, with before/after numbers.

## Report

When done end to end, report:
- the commits;
- per run, cold and warm cache: in-play PSO delta, frames over 16 ms and their causes, and load time to playable;
- what each change bought;
- the project settings changed;
- what's left and why.
