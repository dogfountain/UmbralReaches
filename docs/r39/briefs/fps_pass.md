# r39 brief: raise the average fps (the worst views first)

Luke, 20 Nov: "Raise the average fps". This comes after the load work, the boss staging and the streaming removal.

**Master:** c1cf7357, deployed. **Mac:** M4 Pro, 120 Hz display.

## Where we stand

The last perf tour (zz/perf_tour.tscn, Balanced, fov 90, 1600x1000, vsync off):
- path average 111 fps, 1% low 85;
- views near 120 fps: probably the display pacing frames, so their real cost is hidden. Use `--stress=2` to compare GPU cost.

The worst views:

| view | fps | 1% low | scripts ms | render-cpu ms | rest(gpu) ms | draws |
|---|---|---|---|---|---|---|
| t_reedholm | 85.9 | 62.2 | 2.96 | 3.21 | 5.46 | 2372 |
| t_ll_road | 92.6 | 71.3 | 3.10 | 2.71 | 4.98 | 1600 (2.0 M prims) |
| r_spawn_west | 93.6 | 71.1 | 3.02 | 2.83 | 4.83 | 2569 |
| t_fallowmere | 95.2 | 69.8 | 2.94 | 2.91 | 4.66 | 1896 |
| r37_far_east | 97.0 | 69.6 | 2.56 | 2.86 | 4.90 | 2057 |
| r_orchard_save | 98.0 | 74.6 | 2.67 | 2.65 | 4.89 | 2290 (Luke's save) |
| fr_kings_barrows | 102.2 | 76.5 | 2.13 | 1.94 | 5.71 | 1176 |
| r_downs_w_n | 102.9 | 75.7 | 2.40 | 2.52 | 4.79 | 2253 |
| t_lastlight | 104.1 | 74.0 | 2.87 | 2.46 | 4.29 | 1294 |
| r37_marches | 105.0 | 79.3 | 2.45 | 2.81 | 4.26 | 1959 |

Good views run scripts ~1.8 ms, render-cpu ~1.7-2.0 ms and draws ~1000-1500.

The towns and spawn pay roughly 1 ms more scripts and 1 ms more render CPU. That points to:
- villagers, crowds and life;
- lights;
- more, smaller draws.

## Goal

1. **Raise the tour's average fps and 1% lows**, worst views first.
   - Targets: every tour view at 1% low 85 or more, every listed view at 105 fps or more, and the path average up.
   - With `--stress=2`, GPU cost drops where you cut it.
2. **Script time:** profile with `--blame` and `--probe` at the town views. Cut per-frame GDScript the player can't see:
   - villagers, NPC look-at and animation;
   - life directors, wildlife, encounters, lights, FadeGuard, waypoints, the HUD;
   - work done every frame that could run at a lower rate, or be dt-damped and interpolated (no visible stepping; see `animation-smoothing` in `.cursor/skills/umbral-player`);
   - work done for things far away or off screen.
   - Also take out the encounters (10-16 ms) and wildlife (21 ms) spikes noted in `docs/r39/hitch_warm.md`.
3. **Render CPU and draws:** with `--census` at the worst views, find what adds the draws:
   - merge small static meshes per area: `mesh_chunks` already does this, so find what escapes it;
   - tighten `visibility_range` on small clutter;
   - fix shadow casters that don't need to cast;
   - check omni light counts per view (`light_director`).
4. **GPU:** use `--attrib` at the two worst views to name each render feature's cost. Cheapen what costs much and shows little. Don't flatten the look: dark night, bright landmarks, Enshrouded-style grade.
5. **Finish the physics-interpolation audit:** about 14 `MultiMeshInstance3D.new()` sites aren't covered by `interp_audit_test` yet. Turn interpolation off on every static one and extend the test.

## Hard rules

- **Never enable dynamic resolution**, nor any automatic resolution or quality scaling driven by frame rate. The fixed 960-row render-height cap stays as it is.
- **No visible quality loss:**
  - no new pop-in;
  - no cut content, no fewer villagers, no lower density where the player looks;
  - draw ranges may tighten only where the cut is hidden (fog, fade, impostors).
- **No new hitches.** Frame stutter is Luke's top complaint. A higher average with a worse 1% low is a failure.
- **Smoothness:** no animation stepping from lowering an update rate. Interpolate between updates, and check with strips if you touch animation.
- Never rebake `world/main.tscn`.
- No new shadowed lights.
- In-house assets only.
- **Flora:** don't change placement rules. The scatter reshuffles realm-wide on any keep-out change.
- **Code:** typed calls (no `.call("x")`/`has_method`), files under 1000 lines, `tools/lint.sh` clean.

## How to work

- **Clone:** work only in your clone (path in your prompt), on branch `fps-pass`. Plain commit messages, small commits. Never push; the lead merges.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Measuring:**
  - Once at the start: the full perf tour with `--stress=2`, plus a plain run. Also `--blame`/`--probe --hitches` at t_reedholm and r_spawn_west, `--census` there, and `--attrib` at the two worst.
  - Build every change.
  - Once at the end: the same runs. Short targeted runs that settle a doubt are fine.
  - **No test suite while you build.** At the end, run `tools/run_tests.sh --quick`, then the world tests that cover what you touched (`interp_audit_test`, the life/villager/encounter tests, `perf_*`-related tests). Fix what they find without loosening a check silently.
- **Godot lock:** one Godot process on the machine at a time.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run, retrying every 30 s while it exists. `rmdir` it after, also on failure.
  - Stale lock: if `pgrep -x godot` (never `pgrep -f`) shows no Godot for 60 s, the lock is stale; remove it.
  - Give every run a watchdog. macOS has no `timeout`: start a background `sleep N; kill PID`.
  - Parse-check headless before any windowed run (`godot --headless --path . --import --quit`, then check for Parse Error).
  - Windowed runs use `--always-on-top`, or macOS throttles a hidden window to 0% CPU. Check its CPU 20-30 s in.
  - Kill only your own Godot by PID; never `pkill`. Never wait with a pgrep loop.
- **Placement cache:** any edit under core/world, core/life or core/enemy makes the next load cold (~25-50 s). Expect that, and don't fight it.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/fps_pass/`. Delete what you don't need at the end.
- **Live checklist:** keep it at `docs/r39/fps_pass.md`, with before/after numbers and each change, so you can be resumed.

## Report

Only when the pass is done end to end, report:
- the branch and its commits;
- before/after per view: fps, 1% low, scripts, render-cpu, gpu (plain and `--stress=2`), draws;
- what each change bought;
- anything you judged not worth it, and why;
- the test results.
