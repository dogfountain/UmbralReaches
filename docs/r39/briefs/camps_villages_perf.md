# r39 brief: camps and villages run smooth

**Luke, 21 Nov:** "The biggest thing is you need to fix camps and villages" (asked about frame rate and smoothness).

Master is e3be9ed2. It holds the fps pass, the shader pre-warm, the Ossuary redesign and the map audit, all merged and unmeasured together.

## Known costs

From `docs/r39/fps_pass.md`, `docs/r39/shader_warm.md` and `docs/r39/hitch_warm.md`.

- **Camps:**
  - The encounters director runs 10-15 ms script frames as you pass camps.
  - Guardians and elites are built when you come near (one per 4 Hz tick since the fps pass).
  - Camp spawns cost a frame of their own.
  - Wildlife groups showing for the first time cost a frame.
- **Villages and towns:** Reedholm, Fallowmere, Lastlight, Hearthward and the west spawn are the lowest fps views.
  - About 85 villagers, Living Night folk and wayfarers.
  - Lit windows, fixture lights, ember posts.
  - Yards and market props (543 restored props now draw again after the cull_scatter fix).
  - The west spawn's 1% low is 81.
  - Measured before the fixes: scripts about 2-3 ms and render CPU about 2.5 ms in towns, against under 2 ms elsewhere.
- **Unmeasured since:** the restored props, the abbey, the skull heap and the final seat pass.

## Goal

**No hitch and a high, steady frame rate in and around every camp and every village.**

- **No frame over 16 ms** when:
  - walking or riding into, through and past any camp, from far away to inside it;
  - a camp's foes rising or spawning;
  - an elite or guardian appearing;
  - a fight starting;
  - entering or leaving a town at a run;
  - turning the camera round in a town.
- **The town views** (t_reedholm, t_fallowmere, t_lastlight, t_ll_road, r_spawn_west, Hearthward square, r_orchard_save): 1% low of 100 or more and an average of 130 or more. Report against `docs/r39/fps_pass.md`'s table.
- **No look or content loss:** no fewer villagers, no visible pop-in, no animation stepping (dt-damped and interpolated updates only). Never dynamic resolution.

## How

1. **Measure first, once.** Use the perf tour (`zz/perf_tour.gd`: `--hitches --probe`, `--blame`, `--census`, `--stress=2`, `--moments`) and the PSO watch.
   - Add a scripted run: approach each camp from 120 m at a sprint, pass through and leave, then ride into each town and turn round in it.
   - Name each frame over 16 ms and what it did: scripts by subtree, spawns, node adds, pipeline compiles, physics.
2. **Then fix every cause found.** Likely candidates:
   - **Spread spawns over frames:** pre-build a camp's foes hidden on approach, the way bosses are staged, or pool them.
   - Wake the AI gradually.
   - **Encounters:** cheaper per-tick checks; spatial grids instead of scans.
   - **Crowds:** villager and folk LOD (a cheaper pose path between 20 and 55 m).
   - **Town draws:** merge town props into fewer draws (MeshMerge cells by town), and give the restored props' batches visibility ranges.
   - **Lights:** in towns, cap shadowed or extra lights per view through `light_director`.
   - **Collisions:** settle yard and stall props into static colliders, not bodies.
   - Warm the camp foes' materials under the lantern state (shader-warm's sweep should already cover it: verify).
3. **Re-measure once,** with the same runs, and report before and after.

## Rules

- **Clone:** work only in your clone (path in your prompt), on branch `camps-villages-perf`.
  - Plain commit messages, small commits. Never push; the lead merges.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:**
  1. Measure once. Short diagnostic runs that choose an approach are fine.
  2. Build every fix, with no re-measures in between.
  3. Measure once at the end.
- **Tests:** do not run any tests (no `run_tests.sh`, no `--quick`). The lead runs the one suite after merging, and CI runs on the push. Parse-check headless.
- **Godot lock:** one Godot process on the machine at a time, shared with the other agents.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` after, also on failure.
  - The lock is stale only if `pgrep -x godot` (never `-f`) shows no Godot for 60 s.
  - Watchdog every run with a background `sleep N; kill PID`. Kill only your own PIDs; never `pkill`; no pgrep wait loops.
  - Windowed runs: parse-check first, `--always-on-top`, and watch the first 60 s of the log for errors.
  - Cap every log, about 20 MB.
- **Stay out of** the Ashen Rift files (another agent) and the camp and village LOOK work (another agent: placement, props, composition). You own perf only.
  - If a fix needs a placement change, keep it minimal and say so.
- **Never:** dynamic resolution; rebaking `world/main.tscn`; cutting content; new shadowed lights.
- **Code:** typed calls, files under 1000 lines, `tools/lint.sh` clean.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/camps_perf/`
- **Live checklist:** `docs/r39/camps_villages_perf.md`.

## Report

- The commits.
- Every frame over 16 ms found, with its cause and its fix.
- The before/after table: each camp pass (worst frame, frames over 16 ms) and each town view (fps, 1% low, scripts, render-cpu, gpu, draws).
- What's left, and why.
