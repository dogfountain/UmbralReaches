# r39 lane C: hitch-warm (shaders, boss builds, the Hollow Lantern's spikes)

Brief: `docs/r39/briefs/load_speed.md` (Lane C). Branch `hitch-warm`. Scratch: the session scratchpad `hitch_warm/`.
Probe tools (all in `zz/perf_tour.gd`, windowed): `--hitches --probe` (what a slow frame did), `--bosses` (each arena: 6 s
at its warm ring, then the pull; prints the worst frame of each window; the arena prints `BOSSPULL <id> <ms>`), and
`PSO ...` lines (pipeline compiles by kind at the start of play and at the end).

## Checklist

- [x] Baseline tour (`--hitches --probe --loading`), 79 hitch records over 20 ms; the repeating ones named below
- [ ] PE2: the Hollow Lantern's ~27 ms script spike named and fixed
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
