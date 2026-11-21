# r39 camps and villages run smooth (live checklist)

Brief: `docs/r39/briefs/camps_villages_perf.md`. Branch `camps-villages-perf` in `/Users/luke/UmbralReaches_cperf` (from master
523a5be1). Scratch `<S>` = the session scratchpad `camps_perf/`: `gd.sh` runs Godot under the machine lock with a watchdog, a
20 MB log cap and an isolated HOME.

Luke (21 Nov, overriding the brief's "measure first"): build everything, then test once; no Godot runs of any kind while
building (no measuring, diagnostic or debug runs). So the "before" is the existing numbers (`docs/r39/fps_pass.md`,
`hitch_warm.md`, `shader_warm.md`) and, for the new camp and town runs, the same harness on master's code, run back to back
with the branch at the end. Every fix below is built from the code and those logs; parse checks only (headless).

## State

- [x] harness: `zz/perf_camps.gd` (`--camps`, `--towns`), the `t_hearthward` view
- [x] fixes built (below)
- [x] parse check (headless: every changed script loads), `tools/lint.sh` clean
- [ ] one measurement set at the end: master + harness, then the branch (camp passes, town rides, town views)
- [ ] tests: not run here (the lead runs the one suite after merging)

## Harness

`zz/perf_tour.tscn -- --camps --towns --hitches=16 --probe --probe-ms=6` (`zz/perf_camps.gd`):
- **camps**: 18 camps across the regions (war bands, nests, patrols, risen graves, the guardians' places with their escorts,
  two elites' haunts, the Far Reaches), each crossed from 120 m out on its far side from Hearthward, straight through its
  centre and 60 m past, at a sprint (14) or a gallop (4); the foes awake as in play (they wake, call and fight).
- **towns**: Hearthward, Weirford, Saltmarket, Lastlight, Fallowmere, Reedholm: on a horse from 150 m out at a gallop to the
  centre, a full turn of the camera (4 s), then 60 m out the far side.
- A 1.5 s settle after each teleport is not recorded. Per window: frames, fps, 1% low, worst, frames over 16 ms; each slow
  frame with its distance from the centre and its scripts; the tour's `--hitches --probe` adds what it did.
- Town views: the points tour `--only=t_reedholm,t_fallowmere,t_lastlight,t_ll_road,r_spawn_west,t_hearthward,r_orchard_save`.

## What the code and the logs say (no run before the fixes)

- **Guardians, elites, rares built on approach** (`guardians.gd tick` at 55 m, `director.gd _elite_tick` at 72 m,
  `rares.gd` at 95 m): a whole creature in one frame, 1.4-7 ms warm (`docs/r39/visual_perf.md` PE3, `zz/spawn_cost.tscn`),
  the 10-15 ms script frames the fps pass's path met at every camp (`--probe-ms=12`: Encounters). The rares had no limit: a
  teleport built every rare in reach in one frame. Each also appeared from nothing at that distance (a pop).
- **The spawner's half-second tick** walked all ~400 camp slots on one frame and woke every pawn of a camp in it.
- **First-use audio loads**: EnemyAudio and Sfx read each take from disk on the main thread the first time it plays (534
  creature takes): a fight's first seconds load a dozen (each kind's alert, wind-up, strike, hurt, its steps, the hits).
- **Wildlife first shows**: a group's first show walks its meshes for its fade (F7 of the fps pass capped it at four a scan).
- **A guardian's enrage**: two kin built in one frame of the fight.
- **Villages: a change of the village's phase** began all ~85 people's next routine in one frame; each walk planned over the
  network re-read every sample's floor (two rays a sample, ~170 for 60 m) and rebuilt the network's id table (every node).
- **The village's danger check** walked every foe in the Realm once a second on an unphased clock.
- **The folk** of a town woke on one tick as the wanderer rode in (each shown and posed for the first time that frame).
- **The light budget**: a cut light followed the camera's distance every frame (a renderer call per light per frame on the
  move: ~60-150 cut lights in a town).

## Fixes (each: what, why, commit)

- [x] C1 guardians, escorts, elites and rares built ahead, asleep (`core/life/encounters/staging.gd`, new): behind the loading
      cover a few a frame; each stands at its post like a camp pawn and only wakes when the old rule would have built it
      (or the moment it is hurt or alerted). Out of reach an untouched group sleeps where it stands; a hurt, enraged or dead
      group is freed as before and built again asleep once the wanderer is 15 m past the owner's FAR, one a tick. The
      loading screen and the tour wait for `foes_staged`. A rare's shimmer and motes show only once it has risen.
- [x] C2 the spawner's slots in turn, a share a frame (a whole pass every 0.5 s as before), at most one pawn woken or put to
      sleep a frame and four shown or hidden (`enemy_spawner.gd`)
- [x] C3 every creature take and the top-level one-shots loaded on the loader's threads behind the cover
      (`core/vfx/audio_prefetch.gd`, new; `EnemyAudio.keep`, `Sfx.keep`)
- [x] C4 wildlife: a hidden group's fade walked ahead, one a frame (`life_director.gd`)
- [x] C5 a guardian's enrage kin a frame apart (`guardians.gd enrage`); the guardians' site refresh only when the group or the
      API changed (it walked every site four times a second)
- [x] V1 the village begins at most two routines a frame (`village.gd`); the danger check on its own phase, over the foe index
      (the awake foes and the resting ones near Hearthward) instead of the whole group
- [x] V2 the walking network keeps each leg's floor heights (read once, ahead under the cover, a sliver a frame after) and its
      id table (`village_nav.gd`); forgotten on the settle and when a restoration is built
- [x] V3 a town's folk woken one a frame (`folk_stage.gd`)
- [x] V4 a cut light goes 10 m further in and leaves the per-frame set; the budget pass (every 0.2 s) puts it back when the
      camera has closed half of that (`light_director.gd`)
- [x] V5 villagers past 152 m (nothing of them drawn) stop processing and are stepped from the village every sixteenth frame
      with the time saved up, as their own far step did (`village.gd`): ~55 calls a frame that only counted the time
- [x] C6 roaming events (a procession, an incursion: five foes) and the Watch's assaults (three to seven) raise their foes one
      a frame (`roam_events.gd`, `watch.gd`); the mid-fight calls for help (the brood, the elites' calls, the siege
      captain's conscripts) through `BossKit.summon_spread`, one a frame
- [x] C7 `FoeIndex.around`: the scans that walked all ~400 foes a tick (the horse's shoulder and trample every physics tick
      of a ride, the head's look 5 Hz, Breath's fight check 4 Hz, the music's sense, the HUD's lesson check 4 Hz) walk the
      awake foes and the resting ones near; the waiting foes are kept out of Groups.ENEMY (staging.gd), so the ~130 built
      ahead add nothing to any scan

## Before / after

(filled after the one measurement set)

## Not done, and why

(filled at the end)
