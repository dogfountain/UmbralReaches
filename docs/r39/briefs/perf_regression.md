# r39 brief: win back the frames today's content cost

Luke asked "so the fps average is better?". The full perf tour on the deployed build (6a117248) says no at the heaviest views.

## The run

- Log: `scratchpad/tour_final/tour_plain.log`.
- Settings: Balanced, fov 90, 1600x1000, vsync off, on a copy of Luke's save.
- This run was paced at 120 fps by the display: 23 of 48 views sit at 118-120. So compare the CPU columns and the views under the cap, not the overall mean.

## Against the fps pass's final table (docs/r39/fps_pass.md, round 2)

| view | fps (fps pass → now) | scripts ms | render-cpu ms | draws |
|---|---|---|---|---|
| r_spawn_west | 110.6 → 99.7 | 2.47 → 2.89 | 2.51 → 2.70 | 2170 → 2263 |
| r_orchard_save | 119.0 → 102.8 | 2.06 → 2.42 | 2.24 → 2.49 | 1884 → 2097 |
| t_reedholm | 129.3 → 112.8 | 1.78 → 1.93 | 2.33 → 2.52 | 1963 → 2126 |
| r_downs_w_n | 126.5 → 109.6 | 1.90 → 2.17 | 2.18 → 2.37 | 1859 → 1981 |
| t_lastlight | 168.7 → 119.5 (cap) | 1.66 → 1.90 | 1.68 → 1.82 | 914 → 941 |

- The mean 1% low is 96.9 against 108.5.
- The path averages 115 fps with a 1% low of 86, against 155 / 100 before.

## What came in since the fps pass

Each could be the cause.

- **The 543 props that cull_scatter used to delete:** flames, halos and candles at the towers, halls and Weirford; yard barrels and crates.
- **Camp dress:** 79 camps, 724 props, 46 fires, 31 kits.
- **Restored yards and FinalSeat.**
- **The Ossuary's abbey:** 10.8 MB GLB, ~30 lit windows.
- **The charnel heap:** 21k triangles.
- **The rift:** the lava lake, heat haze, lavafall, glow lights.
- **Staging:** foes built asleep and invisible.
- **Ambush prep and respawn pre-builds.**
- **The bark pixel-dither near the camera:** a discard in every trunk draw.
- **The horse camera's sphere casts.**

## The job

1. **Name the cost first.**
   - `--census` and `--census-split` at r_spawn_west, r_orchard_save, t_reedholm and r_downs_w_n: what adds the extra ~100-200 draws.
   - `--blame` at the same views: which scripts add the 0.2-0.4 ms.
   - One `--stress=2` tour, for GPU-bound cost that the 120 Hz pacing hides.
   - These runs are the test phase that just ended. After them, no runs until everything is built.
2. **Fix every cause without visible loss:**
   - batches merged and given visibility ranges;
   - camp dress kits culled by distance like the rest;
   - restored flame and candle batches merged per cell, with visibility ranges;
   - staged foes costing nothing while asleep: no process, no physics, out of the tree if need be;
   - heavy new meshes given LODs;
   - the haze costing nothing when the rift is off-screen;
   - and so on.
   - Never dynamic resolution. No content cut.
3. **Measure once at the end.** Use the same plain tour and the `--stress=2` tour. Report against both this run and the fps pass.
   - Targets: scripts, render CPU and draws at or under the fps pass's numbers at these views.
   - The fps under the cap no lower than the fps pass's.

## Rules

- **Code graph:** run `tools/code_graph.py impact <file>` before every edit, and list the zz tests it names in your report. The lead runs the one suite.
- **Clone:** work only in your clone, branch `perf-regression`. Plain commits, never push.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:** diagnose, then build EVERYTHING (no runs), then measure once.
  - **No tests:** no `run_tests.sh`, no `--quick`.
- **Godot runs:**
  - Take the Godot lock and use a watchdog (`scratchpad/camps_perf/gd.sh` does both, and caps logs at 20 MB).
  - Use the copy of Luke's save in `scratchpad/camps_perf/saves_src`.
  - Windowed runs use `--always-on-top`.
  - Never `pkill`.
  - No probe stall numbers: `--probe` itself causes 35-70 ms deferred-flush stalls.
- **Never:** dynamic resolution, rebaking `main.tscn`, new shadowed lights, cut content.
- **Live checklist:** `docs/r39/perf_regression.md`.
