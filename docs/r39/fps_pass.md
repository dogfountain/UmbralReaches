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
- [x] batch one built (F1-F9), committed one by one; an intermediate after set (`<S>/after1/`) showed the 1% lows' spikes
      gone at most views and the HUD's 450 canvas draws untouched
- [x] batch two (lead, 20 Nov): the HUD baked (F10), the static merge widened (F11), the summit's rocks joined (F12),
      people's shadows from a lower LOD (F13); short diagnostic runs chose them (`<S>/diag/`: a clean `--census-split`,
      `--merge-why`, `--why-under`, `--casters`, HUD shots)
- [x] after, once (Luke: plain tour, `--stress=2`, the path, `--attrib` at the two worst, the HUD shot; `<S>/after/`), and a
      headless load of the night (`--boot-only`)
- [ ] tests: not run here (Luke: the lead runs the one suite after merging)

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

## After (one plain run against the mean of the baseline's two; `--stress=2` one run each)

| view | fps | 1% low | scripts ms | render-cpu ms | rest(gpu) ms | fps --stress=2 (gpu ms) | draws |
|---|---|---|---|---|---|---|---|
| t_reedholm | 112.8 -> 126.4 | 48.6 -> 58.4 | 1.98 -> 1.80 | 2.48 -> 2.38 | 4.41 -> 3.73 | 77.3 -> 74.8 (8.26 -> 8.81) | 2362 -> 1962 |
| t_ll_road | 127.2 -> 125.5 | 78.5 -> 92.0 | 1.92 -> 1.81 | 2.02 -> 1.89 | 3.93 -> 4.27 | 65.5 -> 65.9 (10.78 -> 10.66) | 1619 -> 1207 |
| r_spawn_west | 89.8 -> 100.7 | 57.8 -> 68.3 | 2.79 -> 2.60 | 2.70 -> 2.58 | 5.66 -> 4.75 | 76.5 -> 76.1 (7.21 -> 7.67) | 2555 -> 2197 |
| t_fallowmere | 131.0 -> 126.0 | 70.0 -> 74.6 | 1.83 -> 1.98 | 2.17 -> 2.29 | 3.65 -> 3.67 | 78.2 -> 78.2 (8.54 -> 8.63) | 1890 -> 1525 |
| r37_far_east | 123.8 -> 139.6 | 56.0 -> 70.1 | 1.83 -> 1.60 | 2.31 -> 2.18 | 3.94 -> 3.37 | 80.8 -> 80.6 (8.02 -> 8.21) | 2044 -> 1620 |
| r_orchard_save | 105.8 -> 114.7 | 56.0 -> 56.7 | 2.29 -> 2.13 | 2.50 -> 2.32 | 4.66 -> 4.27 | 68.7 -> 65.2 (9.35 -> 10.37) | 2263 -> 1886 |
| fr_kings_barrows | 136.0 -> 120.3 | 95.3 -> 79.4 | 1.62 -> 1.71 | 1.65 -> 1.71 | 4.08 -> 4.89 | 59.0 -> 59.0 (12.74 -> 12.77) | 1150 -> 842 |
| r_downs_w_n | 111.5 -> 122.9 | 62.5 -> 48.3 | 2.12 -> 1.89 | 2.43 -> 2.16 | 4.41 -> 4.08 | 78.2 -> 74.4 (7.87 -> 8.85) | 2258 -> 1856 |
| t_lastlight | 148.7 -> 148.7 | 86.8 -> 78.4 | 1.83 -> 1.90 | 1.83 -> 1.89 | 3.08 -> 2.94 | 82.7 -> 82.5 (8.06 -> 8.17) | 1312 -> 921 |
| r37_marches | 126.0 -> 137.9 | 72.9 -> 98.0 | 1.88 -> 1.70 | 2.31 -> 2.24 | 3.75 -> 3.31 | 73.1 -> 73.1 (9.24 -> 9.28) | 1926 -> 1570 |
| r_barrows | 111.0 -> 124.1 | 53.7 -> 86.1 | 1.94 -> 1.74 | 2.44 -> 2.32 | 4.64 -> 4.00 | 65.5 -> 65.7 (10.53 -> 10.65) | 2333 -> 1949 |
| r_downs_w_s | 143.7 -> 156.9 | 56.9 -> 102.6 | 1.79 -> 1.49 | 1.75 -> 1.47 | 3.42 -> 3.42 | 73.4 -> 73.8 (9.63 -> 9.95) | 1542 -> 1194 |
| r37_river | 118.9 -> 127.4 | 70.2 -> 96.3 | 2.17 -> 2.15 | 2.13 -> 2.02 | 4.11 -> 3.69 | 55.7 -> 56.4 (12.91 -> 12.70) | 1783 -> 1430 |

All 47 views: mean fps 135.5 -> 143.4, mean 1% low 78.5 -> 88.7, views under a 1% low of 85: 30 -> 17, mean scripts
1.85 -> 1.71 ms, render-cpu 2.06 -> 1.95 ms, draws 1682 -> 1313 (the HUD's canvas draws 430-456 -> 84-111). The path:
140.4 -> 141.1 fps, 1% low 66.8 -> 77.2. `--stress=2`: mean 73.3 -> 73.2 fps (the GPU's cost unchanged overall).

Read with care:
- **The Far Reaches** (fr_*) read 8-13 % slower in the plain run, but GPU-bound (`--stress=2`) they are unchanged
  (kings_barrows 59.0 -> 59.0, lanternwood 66.2 -> 66.2, cairns 60.7 -> 61.0): not a GPU cost; the last views of a
  single after run, against two baseline runs.
- **The Downs, the orchard and Reedholm cost more GPU at 4x pixels** (downs_w_n 78.2 -> 74.4, orchard 68.7 -> 65.2,
  reedholm 77.3 -> 74.8): batch one left them as they were (`<S>/after1/`), so it is batch two; at 1x they are faster.
  The suspects are the wider merge cells and the split props (coarser occlusion and frustum culling, sorting), to be
  settled with an A/B of `CELL_FAR` / `CELL_K` / the split before merging; not tested here.
- **1% lows** still under 85 at 17 views (downs_w_n 48, meadow 52, orchard 57, reedholm 58, spawn 68 ...): 2-6 frames of
  20-25 ms in a 4 s window; the half-second bursts are gone (batch one), what remains was not named by the probe.

### GPU attribution after (`--attrib`, 2x2 pixels: frame ~13 ms at r_spawn_west, ~15 ms at r_orchard_save)

| feature | r_spawn_west | r_orchard_save |
|---|---|---|
| flora leaf cards | +1.8 ms | +3.6 ms |
| flora undergrowth (range x0.65 / density 60 % would save) | +1.0 (0.4 / 0.35) | +1.8 (0.35 / 0.6) |
| point/spot lights (585-590 governed) | +0.9-1.3 | +1.9 |
| moon shadow (of it the soft angular blocker search) | +1.3 (0.6) | +1.6 (0.8) |
| glow | +0.65 | +0.8 |
| sky background | +0.56 | +0.46 |
| the wanderer | +0.43 | +0.74 |
| grade | +0.41 | +0.40 |
| volumetric fog | +0.35 | +0.23 |
| village / wildlife / particles | +0.22 / +0.05 / +0.11 | +0.37 / +0.22 / +0.14 |
| shadows of flora cards / solids / the other casters | +0.14 / +0.06 / +0.07 | +0.01 / +0.06 / +0.01 |
| mesh LOD threshold x2 | +0.22 | +0.16 |

The leaf cards (alpha-tested: the Apple GPU's hidden-surface removal cannot drop their hidden fragments) are the largest
GPU cost at both, then the lights and the moon's shadow; none was cut here (the look: dark night, the Enshrouded grade).
The shadow casters' own share is small now (people cast from proxies). The headless load (`--boot-only`) builds the night
with no script error (playable at 15.3 s).

## Fixes (each: what, why, commit)

- [x] F1 harness (c17e59f2): the path's spindle and summit legs in the Endgame frame; `--probe-ms`, `--seconds`,
      `--census-split`, canvas draws in every PERF line and the HUD's parts in the census; PerfWatch's own census only
      with `--fps-log` (as its comment said)
- [x] F2 the physics-interpolation audit finished (6b910e18): the fourteen MultiMeshInstance3D builders the test did
      not list; nine were still interpolated (pond rings, marsh lights, eyes, glow buds, oak hollow caps, both warm-up
      draws, the rain glints, the far cards), the Tether's line was eight lines too far down for the check. The test
      now reads every script under core, world, ui and autoload (34 builders), so a new one is checked when written
- [x] F3 villagers past 150 m (nothing of them is drawn: mesh ~103 m, lamp glow ~138 m with FadeGuard's x1.5 and band)
      step every sixteenth frame and are not posed (e56742ad). Inside 150 m nothing changes
- [x] F4 the Living Night's folk step every fourth frame past 55 m with the time saved up, as the villagers already did
      (e56742ad); inside 55 m nothing changes
- [x] F5 the periodic ticks spread over the frames (24597055, ffa10cd4, 85b78397): `core/util/tick_phase.gd` gives
      each timer its own first phase and keeps it (`next` adds the period instead of setting it, so two timers never
      drift into one frame). Twenty-five systems: pets, Kindling, compass, XP bar, vows, quest markers, objective line,
      discovery, region grade, sky life, wanderer life, combat state, scape music, interior beds, world events,
      unkindled glows, rares, life signs, the wildlife's enemy scan, the quest track, the unit frames, the folk stage,
      the encounters' 4 Hz step, the wayfarers' clocks, the living windows, the minimap, the 35 braziers' naps and the
      36 ember posts' re-seats. Kindling finds the fires in the brazier group, not among every interactable
- [x] F6 encounters (e2df9a2e): one guardian or elite built per 4 Hz tick (after a teleport, a respawn or the Ember
      Road two or three were built in one frame), a guardian's escort one every third frame instead of every frame
- [x] F7 wildlife (e2df9a2e): at most four groups shown for the first time per scan (each first show walks the group's
      meshes for its fade; a camera jump did every group in reach at once)
- [x] F8 PerfWatch (b2bb4697): the spike log no longer scans the ~50k-node tree three times inside the frame it logs
      (it did every 60 s); the counts are taken at the end of the build
- [x] F9 fixture pool (ffa10cd4): the free dark lights are skipped, a light is moved only when its row moved

### Batch two

- [x] F10 the HUD's still art baked (8c70626e, 6eb0037d): `ui/hud_bake.gd` draws an owner's art once into a transparent
      SubViewport at the screen's own pixel scale and sub-pixel grid (fonts at the screen's oversampling), and shows it as
      one texture, texel for pixel, with premultiplied alpha; it bakes again only when the owner's signature changes or
      the window resizes. Baked: the hotbar's plate and each slot's picture, the wanderer's unit-frame layers (plate and
      portrait, bars, auras, IN COMBAT), the minimap's bezel, place plate and range tab, the compass strip. The clean
      census had the HUD at 442 canvas draws (hotbar 190, unit frames 111, minimap 89, compass 24); a check run had
      ~290 fewer draws a frame. Shots at r_spawn_west before/after at full size (`<S>/hud/`): the static parts match
      within 1-2 levels (8-bit rounding); the first try drew thin lines on another sub-pixel grid (fixed)
- [x] F11 the static merge widened (d108357f, 6eb0037d): props of several surfaces (261 in the merge roots, each surface
      its own material) are split into one mesh a surface and merged by material; never-fading pieces merge in 64 m
      cells (24); a fading piece's cell is a tenth of its range (6-16 m; it still fades within about one fade band of where
      it did; the near half of a stand-in swap keeps 6 m); a mesh of several surfaces under one override material joins
      its surfaces; a split keeps the vertex format (a new one compiles its pipelines at first sight, P7). Sparse meshes and
      never-fading MultiMesh scatters are chunked in larger cells (`MeshChunks`: the way lanterns were a chunk per lantern,
      137 meshes; the rift's scorch 116 MultiMeshes). Realm-wide the merge makes 3690 candidates into 3186 draws (the same
      set was ~3700); the post-build pass takes ~0.8 s longer, under the loading cover
- [x] F12 the summit's moss rocks (6eb0037d): ~50 rocks of 8-10k triangles were a draw call each wherever the summit is in
      sight (27-39 from the east Marches and Lastlight's road); joined by material and cut into LOD'd cells (cached) in
      their own compressed vertex format: 4 draws
- [x] F13 people's shadows (55266e16): `--casters` named the heaviest shadow casters: villagers, folk and travellers at
      15-24k triangles each (twenty within the moon's reach at Hearthward, sixteen at Reedholm), small clutter almost
      nothing (< 0.6 m: 19 casters, 2k triangles at the spawn). Each person now casts from a ShadowProxy built from one of
      the body's own LODs (`core/life/village/villager_shadow.gd`, ~40 % of the triangles, the body's vertex format and
      material, cached): 4.5-5.5k triangles, as the wanderer's 4.2k proxy; the casters near the spawn 557k -> 265k
- [x] harness: the tour waits for the post-build pass (the loading screen does), `--casters`, `--why-under`, the census
      skips freed nodes (fc3dd2dd, e80b7181)

## Not done, and why

- **The rest of the HUD**: the minimap's marks (~70 draws: they turn with the camera), the compass's marks, the waypoint,
  the boss and target frames (in fights only) still draw directly.
- **Merging past anchors**: the merge stops at nodes a script holds, nodes with metas or groups, and the merge roots
  (`--merge-why`: 262 held, 166 stand-in parents, 88 grouped...); opening those is per-system work.
- **The fire shadow** (the nearest fire's two shadow hemispheres: 128 draws, 186k triangles at the spawn) stays as it is:
  it is the dancers' shadows round Hearthward's fire. People cast it from their proxies now.
- **GPU features**: see the attribution in the after set.
- **The settle frames**: right after the load (under the cover in play) Progression (62 ms), Encounters (26 ms) and
  Wildlife (21 ms at ~2 s) still have one heavy frame each; the probe names the subtree, not the line, and they are hidden
  by the loading screen in play. F6/F7 bound the camera-jump builds.
