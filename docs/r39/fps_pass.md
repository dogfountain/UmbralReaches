# r39 fps pass (live checklist)

Brief: `docs/r39/briefs/fps_pass.md`. Branch `fps-pass` in `/Users/luke/UmbralReaches_fps` (from master 7ea1a813).
Scratch `<S>` = `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/fps_pass/`:
`gd.sh` runs Godot under the machine lock with a watchdog and an isolated HOME (a copy of Luke's save and settings, fresh
each run: the brief's numbers were taken on them, and without them the night is the staged opening with a third fewer
draws); `table.py` turns the tour's PERF lines into tables; `base/` holds the baseline logs, `after/` the final ones.

Luke (20 Nov, mid-pass): measure the baseline once, then build every fix with no runs in between; measure and test once
at the end.

## State

- [x] baseline: two plain tours (points), one `--stress=2` tour, the fixed path, `--blame` at t_reedholm and r_spawn_west,
      `--hitches=14 --probe` at the worst views, `--census` at seven views (`<S>/base/`)
- [ ] every fix built (list below), committed one by one
- [ ] after: the same runs (`<S>/measure_after.sh`), plus `--attrib` at t_reedholm and r_spawn_west
- [ ] tests: `tools/run_tests.sh --quick`, then interp_audit, the village / life / encounter tests and the perf-related ones

## Baseline (Balanced, fov 90, 1600x1000, vsync off; mean of two plain runs; GPU column = fps at 2x2 the pixels)

| view | fps | 1% low | scripts ms | render-cpu ms | rest(gpu) ms | fps --stress=2 | draws |
|---|---|---|---|---|---|---|---|
| t_reedholm | 112.8 | 48.6 | 1.98 | 2.48 | 4.41 | 77.3 | 2362 |
| t_ll_road | 127.2 | 78.5 | 1.92 | 2.02 | 3.93 | 65.5 | 1619 |
| r_spawn_west | 89.8 | 57.8 | 2.79 | 2.70 | 5.66 | 76.5 | 2555 |
| t_fallowmere | 131.0 | 70.0 | 1.83 | 2.17 | 3.65 | 78.2 | 1890 |
| r37_far_east | 123.8 | 56.0 | 1.83 | 2.31 | 3.94 | 80.8 | 2044 |
| r_orchard_save | 105.8 | 56.0 | 2.29 | 2.50 | 4.66 | 68.7 | 2263 |
| fr_kings_barrows | 136.0 | 95.3 | 1.62 | 1.65 | 4.08 | 59.0 | 1150 |
| r_downs_w_n | 111.5 | 62.5 | 2.12 | 2.43 | 4.41 | 78.2 | 2258 |
| t_lastlight | 148.7 | 86.8 | 1.83 | 1.83 | 3.08 | 82.7 | 1312 |
| r37_marches | 126.0 | 72.9 | 1.88 | 2.31 | 3.75 | 73.1 | 1926 |
| r_barrows | 111.0 | 53.7 | 1.94 | 2.44 | 4.64 | 65.5 | 2333 |
| r_downs_w_s | 143.7 | 56.9 | 1.79 | 1.75 | 3.42 | 73.4 | 1542 |
| r37_river | 118.9 | 70.2 | 2.17 | 2.13 | 4.11 | 55.7 | 1783 |

All 47 views: mean 135.5 fps, mean 1% low 78.5, 30 views under a 1% low of 85. `--stress=2` mean 73.3 fps. The path
(route fixed, below): 140.4 fps, 1% low 66.8. The run-to-run spread is large (t_reedholm 115.0 then 110.7 fps; the
brief's own run had it at 85.9), so only differences well past ~5 % are read as real.

## What the baseline says

- **The 1% lows are spikes, not the average.** Almost every view averages 110-150 fps; its 1% low is a handful of
  15-25 ms frames. `--hitches=14` at r_orchard_save and r_barrows: the long frames come every 0.5 s (0.21, 0.78, 1.27,
  1.78, 2.30 ... s), and the frame before each runs 5-6 ms of scripts against 3.5 normally. A dozen systems keep a
  half-second timer that starts at the same moment at load (`_t = 0.5` reset), so they all fire on one frame.
- **Scripts** (`--blame`, base 2.47 ms at t_reedholm, 2.85 at r_spawn_west; the tool's noise is about 0.1 ms):
  villager.gd x85 0.45 / 0.43 ms (the whole Realm's villagers, most of them 300 m away), folk_actor.gd x34 0.26 / 0.21,
  then life_director, fixture_pool, living_windows, unit_frames, ember_post x36 at 0.12-0.19 each at the spawn.
- **Canvas draws**: the HUD issues 430-456 canvas draw calls every frame (the tour's draws are 3D visible + shadow +
  canvas: 1683 + 421 + ~450 at the spawn).
- **3D draws** (`--census`): RealmPois is the largest part at every view (300-440 draws), then RealmLore (100-220), the
  lamps (40-70), RealmWayfinding (50-100), the flora's species by chunk.
- **GPU** (`--stress=2`): the open vistas cost the most pixels (r37_river, fr_kings_barrows, fr_cairns, r34_moor), not the
  towns; r_spawn_west's rest (5.7 ms) barely grows at 4x pixels, so it is geometry (2.1 M primitives, 690 k in shadows).
- **Harness**: the tour's path was broken: the spindle and summit legs were still in the rift's old home frame after it
  moved to `Endgame.O`, so the run stood at the spindle against a wall for 35 legs of 14 s (eight minutes of the path's
  frames). PerfWatch also ran its own `--census` (hiding the zone's parts) in the middle of the tour's.

## Fixes (each: what, why, commit)

- [ ] F1 harness: the path's spindle and summit legs in the Endgame frame; `--probe-ms`, `--seconds`, `--census-split`,
      canvas draws in every PERF line and the HUD's parts in the census; PerfWatch's census only with `--fps-log`
- [ ] F2 the physics-interpolation audit finished: the fourteen MultiMeshInstance3D builders it missed are off
      interpolation (nine were on), and `interp_audit_test` reads every script in the game instead of a list
- [ ] F3 villagers past 150 m (nothing of them drawn) step every sixteenth frame and are not posed
- [ ] F4 the Living Night's folk step every fourth frame past 55 m (as the villagers do)
- [ ] F5 the half-second ticks spread over the frames (each timer keeps its own phase)
- [ ] F6 encounters: at most one elite or guardian built per tick (two or three in one tick were the 10-27 ms frames)
- [ ] F7 wildlife: a camera jump switches its groups on a few a scan (each first show walks the group for its fade)
- [ ] F8 the HUD's canvas draws
- [ ] F9 3D draws at the worst views (RealmPois, lamps, lore)

## Not done, and why

(filled in as the pass goes)
