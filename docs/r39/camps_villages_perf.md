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
- [x] one measurement set at the end (`<S>/meas/`): master's game code with the branch's harness, then the branch, back to back,
      the same HOME and a copy of Luke's save: camp passes and town rides (`--loading --camps --towns --hitches=16 --probe
      --probe-ms=6`), then the town views (`--loading --points-only`, plain); master's code put back in the clone's working tree
      for the before runs (`<S>/code.sh`), the harness (zz/) the branch's in both
- [x] after the set: the staged escorts budgeted (the set showed the load 3.8 s longer); not re-measured
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

## Before / after (21 Nov, 16:20-16:51; `<S>/meas/before_camps.log`, `after_camps.log`, `before_points.log`, `after_points.log`)

### Camp passes and town rides (each window: worst frame, frames over 16 ms, fps, 1% low)

| window | worst ms | frames over 16 ms | fps | 1% low |
|---|---|---|---|---|
| thornwood_warband pass | 59.7 -> 73.3 | 120 -> 186 | 110 -> 92 | 20 -> 15 |
| east_way pass | 51.5 -> 54.8 | 53 -> 29 | 106 -> 96 | 27 -> 33 |
| barrow_field pass | 51.9 -> 53.7 | 44 -> 64 | 112 -> 97 | 30 -> 22 |
| quarry_benches pass | 61.3 -> 57.4 | 62 -> 59 | 128 -> 138 | 28 -> 28 |
| founders_pits pass | 56.4 -> 54.4 | 165 -> 30 | 95 -> 112 | 19 -> 31 |
| orchard_nest pass | 63.2 -> 61.2 | 147 -> 151 | 82 -> 86 | 18 -> 18 |
| waiting_graves pass | 24.3 -> 51.9 | 25 -> 24 | 99 -> 102 | 61 -> 49 |
| mere_east pass | 21.4 -> 50.4 | 2 -> 11 | 110 -> 99 | 73 -> 58 |
| siege_lines pass | 42.1 -> 51.8 | 13 -> 27 | 131 -> 119 | 65 -> 47 |
| white_pans pass | 15.4 -> 25.2 | 0 -> 9 | 134 -> 116 | 84 -> 65 |
| keeps_gate pass | 13.6 -> 18.3 | 0 -> 2 | 141 -> 133 | 87 -> 82 |
| stone_row pass | 15.0 -> 23.3 | 0 -> 4 | 140 -> 133 | 89 -> 79 |
| elite_hobb pass | 28.2 -> 27.8 | 2 -> 4 | 108 -> 97 | 68 -> 64 |
| elite_old_sunk pass | 18.3 -> 22.8 | 5 -> 14 | 102 -> 98 | 66 -> 60 |
| downs_patrol pass | 16.3 -> 20.4 | 1 -> 3 | 118 -> 112 | 72 -> 66 |
| arches_valley pass | 11.9 -> 13.6 | 0 -> 0 | 142 -> 156 | 95 -> 93 |
| moor_north pass | 15.6 -> 23.1 | 0 -> 4 | 111 -> 103 | 69 -> 66 |
| ford_road pass | 16.6 -> 21.7 | 1 -> 3 | 139 -> 128 | 84 -> 81 |
| hearthward in | 33.9 -> 22.7 | 13 -> 13 | 90 -> 89 | 54 -> 55 |
| hearthward turn | 18.0 -> 20.0 | 8 -> 5 | 87 -> 88 | 58 -> 57 |
| hearthward out | 14.9 -> 14.8 | 0 -> 0 | 120 -> 101 | 77 -> 74 |
| weirford in | 14.6 -> 21.1 | 0 -> 3 | 108 -> 101 | 75 -> 66 |
| weirford turn | 13.6 -> 20.0 | 0 -> 1 | 103 -> 103 | 77 -> 66 |
| weirford out | 11.4 -> 20.1 | 0 -> 3 | 140 -> 122 | 92 -> 72 |
| saltmarket in | 15.2 -> 23.4 | 0 -> 5 | 110 -> 98 | 74 -> 62 |
| saltmarket turn | 13.6 -> 13.2 | 0 -> 0 | 99 -> 101 | 75 -> 81 |
| saltmarket out | 13.1 -> 21.5 | 0 -> 3 | 134 -> 114 | 86 -> 75 |
| lastlight in | 12.6 -> 23.2 | 0 -> 2 | 132 -> 120 | 85 -> 76 |
| lastlight turn | 13.2 -> 20.4 | 0 -> 1 | 110 -> 112 | 78 -> 72 |
| lastlight out | 10.9 -> 14.0 | 0 -> 0 | 145 -> 168 | 108 -> 102 |
| fallowmere in | 12.3 -> 24.8 | 0 -> 3 | 139 -> 130 | 92 -> 78 |
| fallowmere turn | 12.0 -> 19.6 | 0 -> 2 | 122 -> 119 | 86 -> 71 |
| fallowmere out | 10.5 -> 12.7 | 0 -> 0 | 142 -> 130 | 98 -> 95 |
| reedholm in | 13.0 -> 20.2 | 0 -> 1 | 142 -> 129 | 96 -> 82 |
| reedholm turn | 12.0 -> 12.9 | 0 -> 0 | 125 -> 123 | 88 -> 84 |
| reedholm out | 10.7 -> 15.9 | 0 -> 0 | 145 -> 173 | 105 -> 96 |
before: windows 36, worst 63.2 ms, frames over 16 ms 661 (passes 640, towns 21), nudges 99
after: windows 36, worst 73.3 ms, frames over 16 ms 666 (passes 624, towns 42), nudges 100

Read with care: one run each, the before first; the tour's `--probe` (a stamp node per subtree) and `--hitches` add ~1 ms of
scripts to every frame of both; the camp passes start where the land lets a sprint through (`nudges`: a run stuck on a rock
was carried 5 m on, ~100 in each run).

**What the slow frames were** (camp passes; each frame over 16 ms by its own record):

| cause | before | after |
|---|---|---|
| a foe built in the frame (a guardian, an elite, a rare, their escort) | 10 (+170, +64, +53 nodes ...) | 3 (respawns, a summon) |
| scripts over 9 ms | 28 | 21 |
| the deferred flush over 15 ms (one frame of 35-70 ms, often in pairs two frames apart) | 147 | 201 |
| the draw over 10 ms with ~2 ms of render CPU (the GPU or the drawable) | 17 | 90 |
| pipeline compile | 2 | 3 |
| 16-30 ms with no single cause (scripts 4-9, flush 5-8, draw 4-8 in a fight) | 485 | 360 |

- **The builds on approach are gone**: the guardians, escorts, elites and rares were built in the frame the wanderer came
  within 55, 72 or 95 m (the orchard nest's +170 and +53 nodes, the elite haunts); now they stand asleep from the load and only
  wake. The founders' pits pass (the Bell-Founder and his cinder casters): 165 -> 30 frames over 16 ms, fps 95 -> 112.
  Staging built 59-60 a run, ~1,200 more nodes asleep (55,030 -> 58,978 at the end of the camps run), none in any foe scan.
- **The biggest cost left is the deferred flush**: one frame of 35-70 ms of the flush (the canvas redraws, the Containers'
  layout passes, every posed skeleton's update and every call_deferred, between the last _process and the draw), in both
  runs, two frames apart, wherever the run fought or ran past interactables and new ground (the warband by the
  Thornwarden's arena, the east way, the barrows, the quarry, the pits, the orchard nest), and in the fights' other frames
  5-8 ms of it. The probe names scripts by subtree, not the flush; `--defer-probe` (zz/defer_probe.gd: every redraw, layout
  pass and skeleton update stamped) was built for it but not run (Luke: one measurement set). The HITCH records round these
  frames list UI built (VBoxContainer Labels and Buttons, key caps of the prompts) and Cue_hurt_body / Cue_landmark_inked /
  Cue_ui_chronicle cues; the unit frames' baked layers re-bake every due frame while the Gloom or Breath or a portrait pop
  changes (their signature carries raw Gloom). Suspects, in order: a baked HUD layer's bake (`ui/hud_bake.gd`: the
  SubViewport is resized and its oversampling set on every bake), the prompts' and chronicle's Controls rebuilt in
  Containers, combat text's font size animated per frame (`ui/combat_text.gd` punch: a new font size each frame).
- **More single GPU-side frames in the after run** (draw 13-20 ms with ~2 ms of render CPU), mostly in the quiet passes and
  the towns (the town rides 21 -> 42 frames over 16 ms, worst 33.9 -> 24.8 ms): not attributed. The after run came second,
  straight after the before run; the staged foes in view add a few draws (the town views' draws are equal).

### Town views (plain, `--loading --points-only`, 4 s at each)

| view | fps | 1% low | worst ms | scripts ms | render-cpu ms | rest(gpu) ms | draws |
|---|---|---|---|---|---|---|---|
| r_spawn_west | 102.5 -> 102.0 | 75.5 -> 69.3 | 13.8 -> 22.0 | 2.71 -> 2.83 | 2.73 -> 2.72 | 4.32 -> 4.25 | 2159 -> 2160 |
| r_orchard_save | 104.6 -> 100.6 | 64.0 -> 56.5 | 19.8 -> 20.0 | 2.37 -> 2.52 | 2.53 -> 2.62 | 4.66 -> 4.80 | 1976 -> 1980 |
| t_reedholm | 110.2 -> 118.0 | 83.8 -> 62.5 | 12.7 -> 20.7 | 2.30 -> 2.19 | 2.45 -> 2.26 | 4.32 -> 4.02 | 1973 -> 1979 |
| t_fallowmere | 133.5 -> 138.9 | 85.4 -> 92.5 | 16.4 -> 15.5 | 2.08 -> 2.04 | 1.92 -> 1.87 | 3.50 -> 3.29 | 1514 -> 1514 |
| t_lastlight | 163.2 -> 163.1 | 103.9 -> 100.6 | 13.0 -> 13.5 | 1.73 -> 1.73 | 1.55 -> 1.54 | 2.85 -> 2.85 | 925 -> 924 |
| t_ll_road | 134.4 -> 135.4 | 97.6 -> 94.1 | 10.6 -> 13.0 | 1.81 -> 1.87 | 1.67 -> 1.68 | 3.95 -> 3.84 | 1204 -> 1204 |
| t_hearthward | 122.4 -> 119.1 | 96.7 -> 86.2 | 10.6 -> 15.1 | 2.17 -> 2.22 | 2.19 -> 2.23 | 3.81 -> 3.95 | 1845 -> 1856 |

Within one run's spread (the fps pass: ~5 % fps, a 1% low is ~5 frames). The views stand still: what changed for them (the
phase change spread, the folk woken one a frame, the walking network's kept floors, the far villagers stepped from the village)
is in moving and over minutes, not in a 4 s stand. Against `docs/r39/fps_pass.md`'s re-measure, master itself reads lower today
(t_reedholm 129.3 -> 110.2 fps on the same code path: the restored props, the abbey, the mound, the final seat since).

### Load

The cover lifted 3.8 s later (27.4 -> 31.2 s to play, the warm runs): the settle phase 1.5 -> 3.1 s and the warm tour
2.6 -> 4.8 s, the staged guardians' escorts built by their coroutine several a frame under the cover (outside the pass's
5 ms budget), beside the audio prefetch. Fixed after the set (1dc5af8a: the pass builds each escort itself, one a call,
inside its budget); not re-measured.

## Not done, and why

- **The deferred-flush stall** (above): the largest hitch near camps, not named; `--defer-probe` is ready
  (`zz/perf_tour.tscn -- --loading --camps=thornwood_warband,founders_pits,orchard_nest --hitches=16 --defer-probe`).
- **The town views' targets** (1% low 100, average 130): not met at r_spawn_west (102 fps, 69), r_orchard_save (101, 57),
  t_hearthward (119, 86), t_reedholm (118, 63); met at t_lastlight, nearly at t_fallowmere and t_ll_road. Their frames are
  scripts 2.2-2.8 + render CPU 2.2-2.7 + GPU 3.8-4.8 ms; no change here moved those (merging town props, a cheaper crowd pose
  and a light cap per view were not built: the fps pass's merge already holds the towns to a dozen draws each, the crowds pose
  at distance rates already, the light budget already caps the local lights).
- **Respawns and ambushes** still build their foe in the frame they rise (one a frame since the fps pass): 1.4-7 ms warm.
- **The GPU-side single frames** of the after run: not attributed (an A/B with staging off is the next check).
