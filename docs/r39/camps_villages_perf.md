# r39 camps and villages run smooth (live checklist)

Brief: `docs/r39/briefs/camps_villages_perf.md`. Branch `camps-villages-perf` in `/Users/luke/UmbralReaches_cperf` (from master
523a5be1). Scratch `<S>` = the session scratchpad `camps_perf/`: `gd.sh` runs Godot under the machine lock with a watchdog, a
20 MB log cap and an isolated HOME.

Luke (21 Nov, overriding the brief's "measure first"): build everything, then test once; no Godot runs of any kind while
building (no measuring, diagnostic or debug runs). So the "before" is the existing numbers (`docs/r39/fps_pass.md`,
`hitch_warm.md`, `shader_warm.md`) and, for the new camp and town runs, the same harness on master's code, run back to back
with the branch at the end. Every fix below is built from the code and those logs; parse checks only (headless).

## State

- [x] harness: `zz/perf_camps.gd` (`--camps`, `--towns`), the `t_hearthward` view, `zz/defer_probe.gd` (`--defer-probe`)
- [x] round 1 fixes (C1-C7, V1-V5) and a first measurement set (with the tour's `--probe`: see "The probe" below)
- [x] lead review (21 Nov): the defer-probe run and a staging off/on A/B, then round 2 built with no runs in between
- [x] round 2 fixes (R1-R7), parse check (headless), `tools/lint.sh` clean
- [x] the final measurement set (no `--probe`): master's game code (523a5be1) vs the branch, back to back, the same HOME,
      cache and save copy (`<S>/final.sh`; `<S>/meas/f_*.log`)
- [x] after the set: the load regression it showed, named and fixed (R8), checked with one short branch load
- [ ] tests: not run here (the lead runs the one suite after merging)

## Harness

`zz/perf_tour.tscn -- --loading --camps --towns --hitches=16` (`zz/perf_camps.gd`), never with `--probe` (below):
- **camps**: 18 camps across the regions (war bands, nests, patrols, risen graves, the guardians' places with their escorts,
  two elites' haunts, the Far Reaches), each crossed from 120 m out on its far side from Hearthward, straight through its
  centre and 60 m past, at a sprint (14) or a gallop (4); the foes awake as in play (they wake, call and fight).
- **towns**: Hearthward, Weirford, Saltmarket, Lastlight, Fallowmere, Reedholm: on a horse from 150 m out at a gallop to the
  centre, a full turn of the camera (4 s), then 60 m out the far side.
- A 1.5 s settle after each teleport is not recorded. Per window: frames, fps, 1% low, worst, frames over 16 ms; each slow
  frame with its distance from the centre and its scripts; `--hitches` adds each frame's phases (scripts, flush, draw).
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

- [x] C1 guardians, escorts, elites and rares built ahead (`core/life/encounters/staging.gd`, new; round 2 rule, 3d2dad3e):
      in play, the nearest missing one within 170 m and outside its owner's rise radius, one on a frame with room
      (`Staging.claim`: the last frame under 10 ms and none built in the last 4 frames; every builder shares it). Built,
      it waits unseen: asleep, `visible = false`, no collision layer, out of Groups.ENEMY (nothing draws, casts, poses, scans
      or hits it). It rises (shown) where and when the old rule built it (55, 72, 95 m); if the builder has not got to it,
      the owner builds it there as before. Out of reach an untouched group waits again where it stands; a hurt, enraged or
      dead group is freed as before. A rare's shimmer and motes show only once it has risen. Nothing is built under the
      loading cover. (Round 1 built them all asleep but drawn under the cover: it cost the GPU in play and 3.8 s of load.)
- [x] C2 the spawner's slots in turn, a share a frame (a whole pass every 0.5 s as before), at most one pawn woken or put to
      sleep a frame and four shown or hidden (`enemy_spawner.gd`)
- [x] C3 every creature take and the top-level one-shots loaded on the loader's threads (`core/vfx/audio_prefetch.gd`, new;
      `EnemyAudio.keep`, `Sfx.keep`); round 2: from the moment the cover lifts, eight requests at a time (636 at once under
      the cover held the loader beside the warm-up's own loads)
- [x] C4 wildlife: a hidden group's fade walked ahead, one a frame, after the cover (`life_director.gd`)
- [x] C5 a guardian's enrage kin a frame apart (`guardians.gd enrage`); the guardians' site refresh only when the group or the
      API changed (it walked every site four times a second)
- [x] V1 the village begins at most two routines a frame (`village.gd`); the danger check on its own phase, over the foe index
      (the awake foes and the resting ones near Hearthward) instead of the whole group
- [x] V2 the walking network keeps each leg's floor heights (read once, ahead, 300 us a frame) and its
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

Round 2 (after the lead's review; built with no runs in between):

- [x] R1 C1's rule above: staged foes invisible with no collision until they rise; built in play on claimed frames (3d2dad3e)
- [x] R2 an ambush's risers built ahead (`core/life/encounters/ambush_prep.gd`, new; 64d26cbf): the nearest open site within
      110 m gets its two to four risers built one a claimed frame, at the site, unseen; when it is sprung each is set on its
      rise spot and shown with the rift-in as before (any it lacks is built as before); a site left 170 m behind lets its
      risers go, one a claimed frame
- [x] R3 camp respawns built ahead (`enemy_spawner.gd`, 0fc0e707): a dead slot's next pawn is built unseen on a claimed frame
      while its respawn timer runs; the respawn (or a rest's refill) only shows it
- [x] R4 nothing beside the warm-up under the cover (4de0fda2): the audio prefetch, the village network's warm-up (300 us a
      frame throughout) and the wildlife fade walk wait for the cover to lift
- [x] R5 `ui/hud_bake.gd` (e6c14383): the bake viewport is resized, its transform and oversampling set, only when they change
- [x] R6 the Tether's anchor mark and line built hidden at start (`core/player/grapple.gd`, 854f47e6), so the warm-up's
      pipeline sweep draws them (riding into Hearthward the mark compiled its pipeline the first time an anchor came in
      reach: a 69.7 ms frame); the ring texture painted once
- [x] R7 the loading screen and the tour no longer wait for `foes_staged` (3d2dad3e)
- [x] R8 (after the final set; de284534) under the loading cover the spawner's pass is whole again and `Staging.claim` gives
      no frame: C2's one-a-frame pass left the ~340 pawns planted awake running their AI for the cover's first ~340 frames
      (the cover lifted 3.9 s later than master's in every branch run since round 1, staging on or off)

## The probe

The first set's camp numbers (640 -> 624 frames over 16 ms) were the tour's own `--probe`: it renumbers ~50k nodes' process
priorities and adds stamp nodes, and that alone made the 35-70 ms deferred-flush stalls (the defer-probe run without it,
`<S>/meas/defer_probe.log`: thornwood 25 frames over 16 ms, worst 28.2; no flush over 10 ms at all). Every number below is
without `--probe`. The lead's list for the flush (the prompts' and chronicle's Controls, combat text's per-frame font size)
was not changed: with the probe off nothing points at them (no flush stall; combat text rasterises a new size's few glyphs
once, under a millisecond). `hud_bake.gd`'s guard (R5) is in.

The staging A/B (round 1, `<S>/meas/ab_off.log`, `ab_on.log`): camp passes 72 frames over 16 ms with staging off, 102 with it
on; the extra were GPU-side (draw 13-20 ms, render CPU ~2 ms): the ~130 staged foes were drawn asleep. Hence R1.

## Final set: master vs branch (21 Nov 17:30-18:15; `<S>/final.sh`, `<S>/meas/f_*.log`)

Master's game code (523a5be1) and the branch's (R1-R7) in the clone in turn, the branch's harness in both, the same HOME, Realm
cache and save copy: town views (master, branch), camp passes and town rides (master, branch), town views again (branch,
master). No `--probe`, `--hitches=16`. R8 came after: one more branch load and views run (`f_after_pts_e.log`).

### Camp passes and town rides (worst frame, frames over 16 ms, fps, 1% low)

| window | worst ms | frames over 16 ms | fps | 1% low |
|---|---|---|---|---|
| thornwood_warband pass | 31.4 -> 29.2 | 16 -> 12 | 108 -> 108 | 57 -> 61 |
| east_way pass | 22.0 -> 15.6 | 1 -> 0 | 105 -> 106 | 74 -> 79 |
| barrow_field pass | 15.3 -> 15.1 | 0 -> 0 | 107 -> 107 | 74 -> 77 |
| quarry_benches pass | 18.6 -> 20.6 | 2 -> 2 | 117 -> 117 | 81 -> 83 |
| founders_pits pass | 15.2 -> 19.7 | 0 -> 1 | 106 -> 112 | 76 -> 80 |
| orchard_nest pass | 21.0 -> 17.4 | 24 -> 5 | 91 -> 103 | 58 -> 68 |
| waiting_graves pass | 22.8 -> 14.8 | 3 -> 0 | 100 -> 108 | 70 -> 79 |
| mere_east pass | 21.1 -> 19.8 | 1 -> 1 | 104 -> 108 | 78 -> 81 |
| siege_lines pass | 35.3 -> 37.0 | 9 -> 6 | 115 -> 116 | 68 -> 69 |
| white_pans pass | 15.8 -> 13.1 | 0 -> 0 | 114 -> 115 | 90 -> 88 |
| keeps_gate pass | 13.1 -> 21.9 | 0 -> 1 | 118 -> 118 | 95 -> 94 |
| stone_row pass | 12.6 -> 12.0 | 0 -> 0 | 118 -> 118 | 91 -> 94 |
| elite_hobb pass | 16.6 -> 16.2 | 1 -> 1 | 102 -> 104 | 73 -> 76 |
| elite_old_sunk pass | 17.4 -> 16.4 | 1 -> 1 | 102 -> 104 | 71 -> 73 |
| downs_patrol pass | 15.6 -> 15.0 | 0 -> 0 | 108 -> 111 | 73 -> 77 |
| arches_valley pass | 15.1 -> 10.8 | 0 -> 0 | 119 -> 119 | 95 -> 97 |
| moor_north pass | 19.0 -> 15.8 | 3 -> 0 | 104 -> 108 | 73 -> 76 |
| ford_road pass | 12.7 -> 11.1 | 0 -> 0 | 117 -> 118 | 92 -> 94 |
| hearthward in | 20.5 -> 17.4 | 6 -> 5 | 98 -> 98 | 62 -> 64 |
| hearthward turn | 16.9 -> 17.4 | 5 -> 1 | 93 -> 97 | 60 -> 65 |
| hearthward out | 13.6 -> 13.8 | 0 -> 0 | 106 -> 108 | 81 -> 81 |
| weirford in | 14.7 -> 15.2 | 0 -> 0 | 104 -> 106 | 75 -> 71 |
| weirford turn | 12.2 -> 11.8 | 0 -> 0 | 106 -> 107 | 83 -> 87 |
| weirford out | 11.0 -> 12.0 | 0 -> 0 | 115 -> 114 | 96 -> 92 |
| saltmarket in | 15.0 -> 14.9 | 0 -> 0 | 103 -> 106 | 78 -> 78 |
| saltmarket turn | 11.2 -> 12.4 | 0 -> 0 | 107 -> 108 | 90 -> 87 |
| saltmarket out | 11.1 -> 10.7 | 0 -> 0 | 114 -> 115 | 95 -> 95 |
| lastlight in | 11.6 -> 11.4 | 0 -> 0 | 115 -> 115 | 94 -> 93 |
| lastlight turn | 11.3 -> 10.9 | 0 -> 0 | 113 -> 113 | 90 -> 93 |
| lastlight out | 10.1 -> 10.7 | 0 -> 0 | 120 -> 120 | 103 -> 103 |
| fallowmere in | 10.8 -> 9.8 | 0 -> 0 | 118 -> 119 | 101 -> 103 |
| fallowmere turn | 10.5 -> 9.9 | 0 -> 0 | 116 -> 116 | 97 -> 102 |
| fallowmere out | 11.6 -> 9.9 | 0 -> 0 | 118 -> 119 | 96 -> 104 |
| reedholm in | 13.3 -> 12.1 | 0 -> 0 | 117 -> 118 | 97 -> 99 |
| reedholm turn | 10.4 -> 10.3 | 0 -> 0 | 115 -> 116 | 98 -> 99 |
| reedholm out | 12.9 -> 9.8 | 0 -> 0 | 120 -> 120 | 100 -> 104 |

Camp passes: 61 -> 30 frames over 16 ms (worst 35.3 -> 37.0, both siege_lines); town rides 11 -> 6. Every pass's fps is
equal or higher; 1% lows higher in 16 of 18 passes (white_pans 90 -> 88, keeps_gate 95 -> 94).

What the slow frames are now (camp passes, by each frame's own record):
- **thornwood_warband, 12 (master 16)**: the run's first frames at 107 m, its start beside the Thornwarden's arena (scripts
  8-10 ms, render CPU 5-8 ms: the arena's key-cap CanvasLayer and the open view), and three at 41 m in the fight. Not the
  camp's foes.
- **siege_lines, 6 (9)**: the 37.0 ms frame (35.3 on master) is a quest offer opening by itself at 82 m (the run walks
  into its giver's reach): the panel's rows and reward cards are built and the game pauses in that frame; the rest are
  8 ms of render CPU in the lines' fight.
- **orchard_nest, 5 (24)**: the nest's fight, 16-17 ms (scripts 4-6, draw 4-5); master's 24 were the same fight plus the
  guardian group's builds as the run came within 55 m (the Bulwark's +167 objects).
- **founders_pits 1 (0), keeps_gate 1 (0), mere_east 1 (1), quarry 2 (2)**: single GPU-side frames (draw 13.6-18.1 ms with
  1.4-2.3 ms of render CPU: the GPU or the drawable), the same kind master shows at east_way and mere_east; no build, no
  script spike in them.
- **elite_hobb, elite_old_sunk, 1 each (1 each)**: 16.2-16.4 ms, scripts 3 ms, draw 4-7 ms.

### Town views (plain, `--loading --points-only`, 4 s each; master's two runs vs the branch's three)

| view | fps | 1% low | master's 1% lows | branch's 1% lows |
|---|---|---|---|---|
| r_spawn_west | 99.8 -> 100.8 | 79.5 -> 77.9 | 77.3, 81.7 | 80.3, 77.0, 76.3 |
| r_orchard_save | 101.8 -> 101.2 | 78.7 -> 75.9 | 80.3, 77.0 | 72.0, 79.2, 76.6 |
| t_reedholm | 105.4 -> 109.2 | 82.8 -> 79.8 | 82.3, 83.2 | 82.9, 80.5, 76.1 |
| t_fallowmere | 118.7 -> 118.6 | 99.7 -> 100.8 | 97.9, 101.4 | 101.9, 100.0, 100.6 |
| t_lastlight | 120.0 -> 119.9 | 103.5 -> 104.2 | 103.0, 103.9 | 104.1, 104.7, 103.8 |
| t_ll_road | 118.1 -> 117.9 | 98.5 -> 98.4 | 98.4, 98.5 | 98.6, 98.7, 98.0 |
| t_hearthward | 114.0 -> 113.9 | 98.8 -> 98.0 | 99.3, 98.4 | 97.8, 97.4, 98.8 |

Worst frames 9.6-15.7 ms on both. Four views equal or up; the three beside camps (r_spawn_west, r_orchard_save, t_reedholm)
1.6-3.0 lower on average, inside one run's spread (master's own two runs differ by 4.4 at r_spawn_west), but leaning
lower: most likely the builder's frames right after the teleport (everything within 170 m of a fresh spot is built over
its first seconds, a 1.4-7 ms build on an 8 ms frame: 10-15 ms, the window's fifth-worst frame). Not attributed by a run.

### Load (the cover's phases, Realm cache warm)

| run | settle | warm | panels | cover lifted | wall |
|---|---|---|---|---|---|
| master (3 runs) | 1.45 s | 2.55-2.65 s | 1.76-1.80 s | 9.11-9.23 s | 28.5-28.7 s |
| branch R1-R7 (3 runs) | 2.77-2.88 s | 4.75-4.82 s | 1.89-1.92 s | 13.04-13.08 s | 33.2-33.3 s (35.5: its first run missed the cache) |
| branch with R8 (1 run) | 1.44 s | 2.76 s | 1.79 s | 9.30 s | 28.7 s |

## Not done, and why

- **The three camp-side town views' 1% lows** (above): within noise but leaning 1.6-3 lower. The next step would be a
  builder that claims a frame only when the frame plus that kind's measured build cost stays under ~12 ms (so in an 8 ms
  town view it waits; the old rule still builds at the rise radius), then the views again. Not built: the set was the one
  set the lead asked for.
- **The quest offer's 35-37 ms frame** (siege_lines, master too): a modal panel opening (the game pauses in that frame);
  `ui/panel_warm.gd` already warms the panel; its rows and cards are built per quest. Out of this pass's scope (UI).
- **The single GPU-side frames** (13-18 ms of draw with ~2 ms of render CPU) on both sides: not attributed.
- **The thornwood start** (render CPU 5-8 ms beside the Thornwarden's arena at 107 m): on both sides; the view, not the camp.
- **The town views' targets** (1% low 100, avg 130): the views run at ~100-120 fps here with 1% lows 76-104 on both sides;
  nothing in this pass moved a standing view's cost (scripts 1.8-2.9, render CPU 1.5-2.7, GPU 4.2-5.0 ms).
- **The round-1 keeps_gate 134 ms frame** (A/B on-run: 120 ms outside every measured phase, beside the map's charcoal cue):
  not seen in the final set (keeps_gate worst 13.1 master, 21.9 branch).
