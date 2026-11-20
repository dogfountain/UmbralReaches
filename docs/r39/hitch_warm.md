# r39 lane C: hitch-warm (shaders, boss builds, the Hollow Lantern's spikes)

Brief: `docs/r39/briefs/load_speed.md` (Lane C). Branch `hitch-warm`. Scratch: the session scratchpad `hitch_warm/`.
Probe tools (all in `zz/perf_tour.gd`, windowed): `--hitches --probe` (what a slow frame did), `--bosses` (each arena: 6 s
at its warm ring, then the pull; prints the worst frame of each window; the arena prints `BOSSPULL <id> <ms>`), and
`PSO ...` lines (pipeline compiles by kind at the start of play and at the end).

## Checklist

- [x] Baseline tour (`--hitches --probe --loading`), 79 hitch records over 20 ms; the repeating ones named below
- [x] PE2: named (bisect by muting scripts: `quest_trail.gd`; timed: the stale check's `NavAssist.ready()` walked every nav probe in one call, 17 ms, and again inside `_build`, 8 ms); fix: `NavAssist._all_joined` asks at most 6 probes per physics frame (`core/enemy/nav_assist.gd`). Re-check pending
- [ ] Boss ahead of the pull: staged boss in `BossArena` (`_stage_boss`, `_stage_draw`, `_wake_staged`): written
- [ ] Boss pull measured (`--bosses`): under 4 ms
- [ ] Pipelines: the first views' compiles named, warmed
- [ ] Final tour: PSO count and hitch list after
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
`BossKit.warm` stage 0 also asks a worker to instance the glb (`ClipRig.instance_ahead`), which `ClipRig._build` takes if
it is ready (never waited for: waiting hung the main thread, found by a 0 % CPU run). `BossArena.staging = false`
(perf_tour `--bosses --no-stage`) is the old behaviour, for the before numbers.
