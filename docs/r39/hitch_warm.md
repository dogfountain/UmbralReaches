# r39 lane C: hitch-warm (shaders, boss builds, the Hollow Lantern's spikes)

Brief: `docs/r39/briefs/load_speed.md` (Lane C). Branch `hitch-warm`. Scratch: the session scratchpad `hitch_warm/`.
Probe tools (all in `zz/perf_tour.gd`, windowed): `--hitches --probe` (what a slow frame did), `--bosses` (each arena: 6 s
at its warm ring, then the pull; prints the worst frame of each window; the arena prints `BOSSPULL <id> <ms>`), and
`PSO ...` lines (pipeline compiles by kind at the start of play and at the end).

## Checklist

- [x] Baseline tour (`--hitches --probe --loading`), 79 hitch records over 20 ms; the repeating ones named below
- [x] PE2: named (bisect by muting scripts: `quest_trail.gd`; timed: the stale check's `NavAssist.ready()` walked every nav probe in one call, 17 ms, and again inside `_build`, 8 ms); fix: `NavAssist._all_joined` asks at most 6 probes per physics frame (`core/enemy/nav_assist.gd`). Re-check pending
- [x] Boss ahead of the pull: staged boss in `BossArena` (`_stage_boss`, `_stage_draw`, `_wake_staged`)
- [x] Boss pull measured (`--bosses`): Thornwarden 38.8 -> 1.4 ms, Speaking Crown 11.1 -> 1.7, Anchoress 11.2 -> 0.9 (Bone Abbot and Ascended Warden pulls did not start in the tour: their gates/bells)
- [~] Pipelines: the boss's first draw is warmed (the staged speck), the rift emitters are built ahead; the general first-view compiles are NOT reduced (see below)
- [x] Final tour run (with the loading screen): numbers below
- [ ] Tests: quick tier, the boss / arena / night_life world tests

## Findings

### Baseline (before)

- Tour `--hitches --probe --loading`, 79 `HITCH` records over 20 ms in 570 s (settle 5, points 62, path 6). Most of the
  points ones are 20-25 ms frames with a 19-20 ms "draw" part and no scripts, at 1 s spacing: the machine was shared with
  other lanes' runs, so they are noise here, not the game. The ones with a cause:
  - scripts spikes: Encounters 13-15 ms (a rest's refill), the Hollow Lantern's subtree 8 ms regularly and 17-27 ms now and
    then (PE2), Wildlife 20 ms once at the start;
  - first-use pipeline compiles: `spec+6` (MapSketch's charcoal cue, a GPUParticles3D, 38 ms), the Thornwarden pull
    (`spec+2`, `spec+4`, 26 ms of scripts then a 59 ms frame), a spitter spawn (`spec+9`, 14.6 ms), a few `spec+2/+3`.

### PE2, the 27 ms script spike (it was never the Hollow Lantern)

The probe put it under `HollowLantern/Story` because the quest director is a child of the Keg's Story node. Muting the
Story children's scripts in two halves (`--mute=`) then singly named `quest_trail.gd` (muting it removes the spike; muting
`quest_markers.gd` + `quest_track.gd` does not). Timed inside `QuestTrail._tick`: `TrailRoute.route` is 0.2-0.4 ms
(`zz/trail_cost.tscn`), the spike is the `stale` expression: `NavAssist.ready()` -> `_all_joined()` asked
`map_get_closest_point` for every probe the navigation mesh has in one call (17 ms; 8 ms again inside `_build`), the
first time the mesh had merged. The previous pass's A* change was a wrong guess. Enemies share the same call
(`enemy.gd`, `shade.gd`), so the fix is in `NavAssist`: six probes a physics frame.

### Boss ahead of the pull

`BossArena._warm_step` stages 0-4 as before; step 5 `_stage_boss()` builds the real boss (hidden, process off, out of the
enemy group, collision 0); step 6 `_stage_draw()` shows it as a speck for its first draw (replaces `BossKit.warm_rig`'s
throwaway: one build, not two); `_begin()` wakes it (`_wake_staged`) in the pull. The fight starts exactly where it did.
(A worker that instanced the glb ahead was tried and dropped: waiting for it hung the main thread, and a worker still running at quit crashed the headless boss tests at exit.) `BossArena.staging = false`
(perf_tour `--bosses --no-stage`) is the old behaviour, for the before numbers.

### NavAssist (the real PE2 cause)

`NAVREADY 17.2 ms joined 5/5`: `NavigationServer3D.map_get_closest_point` walks every polygon of the map, ~3.4 ms a probe;
the first `ready()` after the mesh merged asked all five in one call. A cap of six did nothing (5 probes); the cap is now
ONE probe a look (`PROBES_PER_LOOK`), so the check costs 3.4 ms a physics frame for five frames. (Enemies share the call.)

### Boss pull, before and after (`zz/perf_tour.tscn -- --bosses`, windowed 1600 x 1000, `BOSSPULL` lines)

| boss | before (built in the pull) | after (staged) |
|---|---|---|
| Thornwarden | 38.8 ms (first 223 ms, un-warmed) | 1.4 ms (the build moved to the approach: 8.4 ms in one frame) |
| Speaking Crown | 11.1 | 1.7 |
| Anchoress | 11.2 | 0.9 |

The pull's `Events.boss_engaged` was 19 ms for the Thornwarden (FloraFight's `find_children` over the woods): now collected
a slice a frame from `Events.boss_warming`. The gate's `rift_in` (7.6 ms first use) is built ahead far below the world.
Frames over 16 ms that remain around a pull (4-10 a pull): the first one is a first-draw `spec+11` compile of the pull's
visible parts (boss at full size, bar, rift), then about 6 frames of 15-18 ms while the rise effects overdraw (CPU render
6-7 ms, the scene is the same size as before the pull: GPU and effects, not a build). Not fixed.

### PSO counts

`PSO at start of play` / `at end` (canvas/mesh/surface/draw/spec): 14/176/534/3/266 = 993 at the start and 1243 at the end
of the `--bosses` tour before; 992 and 1245 after. Unchanged: this pass did not reduce the engine's specialisation
compiles (the loading screen's warm tour already covers the materials; the leftover `spec+N` come from first sight of a
material under a new light/shadow/fog state at a view or a spawn, which needs a per-state warm this pass did not build).
