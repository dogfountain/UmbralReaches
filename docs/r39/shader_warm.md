# r39 shader / pipeline pre-warm (live checklist)

Brief: `docs/r39/briefs/shader_warm.md`. Branch `shader-warm` in `/Users/luke/UmbralReaches_warm` (from master 34c4545c).
Scratch `<S>` = the session scratchpad `shader_warm/`: `gd.sh` runs Godot under the machine lock with a watchdog and an
isolated HOME (`fresh:NAME` = a new HOME, no shader or pipeline cache: cold; `keep:NAME` = the same HOME again: warm), a
copy of Luke's save and settings each run; `base/` the baseline logs, `after/` the final ones.

## Tools (zz only)

- `zz/pso_watch.gd` (added by the perf tour): the five pipeline counters every frame. In play, each frame that compiled
  prints `PSO+ <window> t frame <ms> <kind>+n cam`; frames over 16 ms are counted with and without a compile (in that
  frame or the one before); `PSOPLAY` is the summary (in-play delta by kind, slow frames, per window).
  `--psolog` also names the suspects (geometry in the frustum or within 30 m whose pipeline key was never in view) and the
  render state (directional lights, fog, ambient, omni/spot lights in view, shadowed, dual paraboloid, projector, soft).
- `zz/perf_moments.gd` (`--moments`): the map, a horse mounted and ridden, the first fight (five kinds woken, every
  slotted spell cast), every other spell, the Ember Road; `MOMENT <name> ... PSO ...` per window.
- `zz/spec_probe.tscn`: a lab that changes one scene state at a time and prints what it compiled.
- `--clean-quit`: the tour quits like a player (not a kill), so the engine's exit-time cache writes happen.

## Checklist

- [x] harness: PsoWatch, moments, the probe, clean quit (717c4793, 6ae95f13, 91bd75fa)
- [x] baseline, cold and warm: `--loading` tour, `--bosses`, `--moments`; the compile log (`--psolog`) of each
- [x] where the compiles come from (the log, three probes)
- [x] the engine's options (ubershaders, shader cache, the Metal pipeline cache)
- [x] fixes (2a649a74, 85da5df2)
- [ ] final, cold and warm (`<S>/after/`)
- [ ] tests: not run here (the lead runs the one suite after merging)

## Baseline (before, 21 Nov morning; `<S>/base/`)

Windowed 1600x1000, Balanced (the tour's default), Luke's save; cold = a fresh isolated HOME (no shader cache, no
pipeline cache); warm = the same HOME again. "In play" = from the cover lifting to the end. Control = `LOADING done`
(wall, from process start); the tour's own `PERF load` in brackets.

| run | in-play PSO delta (canvas/mesh/surface/draw/spec) | frames over 16 ms (with a compile) | worst compile frame | control |
|---|---|---|---|---|
| moments cold | 0/0/1/0/91 = 92 | 23 (2) | 21.0 ms (fight, spec+1) | 29.6 s (27.3) |
| moments warm | 0/0/1/0/99 = 100 | 19 (4) | 22.7 ms (fight) | 28.5 s (26.0) |
| bosses cold | 0/0/1/0/40 = 41 | 26 (5) | 24.1 ms (Thornwarden pull, spec+4) | 30.7 s (28.1) |
| bosses warm | 0/0/1/0/40 = 41 | 17 (6) | 25.4 ms (Thornwarden pull, spec+4) | 29.0 s (26.4) |
| tour cold (points + path) | 0/0/1/1/122 = 124 | 109 (5) | 46.2 ms (teleport to r_thorn_deep, spec+6) | 31.1 s (28.5) |
| tour warm | 0/0/1/1/121 = 123 | 53 (3) | 40.2 ms (the same teleport) | 28.5 s (26.0) |

Moments (cold): map none (its 70 ms frame is the map's own open, not a compile), mount spec+14, fight spec+26, spells
spec+2, travel spec+25. Bosses: 5-12 compiles at each approach (the staged speck and BossKit.warm draw there), 1-12 in each
pull. The tour: 1-11 at nearly every view, the Far Reaches and the r34/r37 ground included (the warm tour's 19 views are
the old Realm's middle). Pipelines at the start of play ~1490-1500 either way.

Cold and warm hardly differ: Metal keeps no pipeline cache of Godot's (below), and the OS's own Metal caches (per user,
not per HOME) serve the driver either way; the shader cache saves 1.2-2.6 s of the load.

## Findings

### What a pipeline is keyed on (Forward+ in 4.7.2 on Metal; `zz/spec_probe.tscn`, `<S>/base/spec_probe*.log`)

The engine's own shader source (in the binary) lists the Forward+ specialisation constants: forward GI, light projector,
positional soft shadows, directional soft shadows, decal/projector mipmaps, depth fog, bicubic lightmaps, the shadow
sample counts; and per draw: MultiMesh, 2D MultiMesh, colours, custom data, legacy fog blending, area lights. The probe
changes one state at a time in a lab of seven materials and counts what compiles:

| change | compiles | so |
|---|---|---|
| a light with a size (0.3 m, no shadow) out of every box's reach, then in reach | 0, then spec+7 | per instance: a light with a size **touching** it |
| a projector spot out of reach (it touched only the floor), then in reach | spec+1, then +6 | per instance: a projector light touching it |
| a soft light in view but touching nothing | 0 | not the frame, the instance |
| soft and projector together | spec+7 | the pair is a state of its own |
| shadowed spot, first of the shadowed lights | 0 | shares the moon's shadow pipelines |
| omni, dual paraboloid / cube shadow, size 0, first | surface+9 spec+4 / spec+3 | passes of their own; the colour pass unchanged |
| moon's shadow off | spec+7 | (not reached in play: the moon always casts) |
| fog, volumetric fog, a second directional light, a 0.01 speck | 0 | no |
| mirrored instance (scale x -1) | spec+2 | the other face's cull: a pipeline of its own |
| instance transparency 0.5 | **draw+5** spec+5 | a blended draw compiles its ubershader AT DRAW TIME (a stall) |

**The wanderer's lantern** (`wanderer_lantern.gd`: `light_size` 0.35, range 4.5 m) touches whatever stands near the
wanderer, so in play every material near him is drawn in the "soft" state; the interiors' window shafts are soft and
projector (0.28 m and the gobo), the hero spots projector. The warm tour's camera tours far from the frozen wanderer, so
it compiled almost only the plain state: in play each material met near the wanderer compiled again. The compile log
(`--psolog`, moments + bosses + tour) agrees: of 145 in-play compile frames, 126 (87 %) had nothing new in view (a state,
not a material); the rest named a fade-self node inside its fade band (drawn blended) or a Far Reaches material the views
never pass (the towns' hurdles and stooks, the star crater's case).

Spec compiles are the engine's background compiles (the frame draws with the ubershader meanwhile): they rarely made a
frame slow on their own (5 compile frames over 16 ms in a whole tour). A **draw** compile (a blended instance, never
prepared) is synchronous. The world holds ~25,000 geometry nodes but only ~380 distinct pipeline keys (`PSOKEYS`).

### The engine's options

- Ubershaders / background compiles: always on in 4.7 Forward+ (no project setting); the counters' "spec" is that path.
- `rendering/shader_compiler/shader_cache/*`: on, compressed, zstd (defaults, kept). It saves 1.2-2.6 s of a load.
- `rendering/rendering_device/pipeline_cache/*`: on by default, but the Metal driver writes no cache file (no file after
  a run, nor after a player's quit: `--clean-quit`, below). Luke's own `vulkan/pipelines.forward_plus.apple_m4_pro.cache`
  (151 MB, 16 Nov) is from the MoltenVK days. Every launch builds its pipelines again; the OS's Metal caches make that fast.
- No RenderingServer API takes pipeline hints. No setting removes the state compiles without changing the look (the
  lantern's size, or positional soft shadows off, would).

## Fixes

- [x] **The pipeline sweep** (`core/world/pipeline_warm.gd`, new; 85da5df2).
      - Collected over the tour's frames (1,200 nodes a frame; the whole tree, sub-viewports and 2D layers skipped), plus
        every geometry node added from the tour's start until the sweep draws (`node_added`): the combat set (keyed when
        it is cleared, before it is freed), and what the post-build merge, spawns and swaps add after the walk passed
        their branch (the first final run's compile log named a split mesh of the merge, made after the walk).
      - One record per distinct combination of: the shader (a shader material's) or the material itself (a standard
        material's generated shader cannot be read back; a guess from its features collided: 14 in-play compiles left
        against 8 keyed by material); the surface's vertex format and primitive; the kind (mesh, MultiMesh with or without
        colours and custom data, CPU/GPU particles as a MultiMesh of their draw pass, sprites and labels as a copy of the
        node); skinned; shadow casting; mirrored; fading (fade-self ranges, instance transparency, every foe's and boss's
        part, whose death fades it); overlay and next passes. ~1,730 records for the ~25,000 geometry nodes.
      - Drawn beside the panels phase in a lab 1,400 m under the land: bare RenderingServer instances of the world's own
        meshes and materials in 0.42 m cells (a rest skeleton for a skinned one, a blended twin for a fading one, a
        mirrored scale for a mirrored one), 324 a frame, each batch once per colour-pass light state (the lantern's size,
        plain, the gobo projector, both), with the shadowed lights play has on in every frame (a fire's dual paraboloid
        on High shadows, a cube omni, a shadowed spot). 2,970 stand-ins, six batches, 24 frames: inside the panels
        phase's 1.7 s, so it adds no time of its own.
- [x] **The combat set under the lantern's state**: a light of the lantern's kind on the warm camera every other frame
      while the set is on show (foes, bosses, horses, spells: the real skinned bodies and effects).
- [x] **The tour's views at one frame a heading** (was two): a heading's first frame asks for every pipeline in view and
      the sweep covers the states (A/B on a warm cache: two frames a heading left as many in-play compiles, 18 against
      14 in the moments and 8 against 8 in the bosses, and cost 0.9 s). This pays for the sweep's pipelines on every
      launch (Metal keeps no pipeline cache).
- [x] **The Ember Road's wisp and trail** in the combat set (`FireFlight.build_wisp`, split out of `_make_wisp`;
      2a649a74). It did not move the road's count (6 before and after it; keying standard materials by instance took
      it to 1); kept, as the trail's own emitter is otherwise first built on a first flight.
- [x] LightDirector leaves the warm-up's lights alone (`ld_gov`): its shadow policy would have taken their maps away.

Tried and dropped (diagnostic A/Bs, `<S>/diag/`): a light of the lantern's kind on the camera at every heading, 120 m
(in-play 2-3 compiles, but +1.0-1.3 s of load: it paired with the whole view every other frame); the sweep alone with no
lantern-kind frames and unskinned stand-ins (46: a skinned body is drawn from its skinned copy, a format of its own).
## After (21 Nov; the final set `<S>/after/`, after 4eb08a98; the same runs as the baseline)

| run | in-play PSO delta (canvas/mesh/surface/draw/spec) | frames over 16 ms (with a compile) | control (tour's load) | cover's own part |
|---|---|---|---|---|
| moments cold | 92 -> **9** (0/0/1/0/8) | 23 (2) -> 11 (**0**) | 29.6 -> 31.6 s (27.3 -> 29.2) | 6.22 -> 6.42 s |
| moments warm | 100 -> **8** (0/0/1/0/7) | 19 (4) -> 8 (**0**) | 28.5 -> 27.7 s (26.0 -> 25.3) | 6.00 -> 6.12 s |
| bosses cold | 41 -> **2** (0/0/1/0/1) | 26 (5) -> 16 (1*) | 30.7 -> 29.9 s (28.1 -> 27.3) | 7.04 -> 6.25 s |
| bosses warm | 41 -> **1** (0/0/1/0/0) | 17 (6) -> 17 (1*) | 29.0 -> 27.8 s (26.4 -> 25.3) | 5.96 -> 6.17 s |
| tour cold | 124 -> **1** (0/0/1/0/0) | 109 (5) -> 21 (**0**) | 31.1 -> 29.7 s (28.5 -> 27.2) | 7.07 -> 6.31 s |
| tour warm | 123 -> **9** (1/0/1/0/7) | 53 (3) -> 15 (1*) | 28.5 -> 27.9 s (26.0 -> 25.5) | 6.79 -> 5.78 s |

\* The bosses' one: the frame after the calibration's surface compile (below), the first frame of the teleport into
the Ossuary (18-19 ms). The warm tour's one: this run played the staged opening (its camera and title layer were freed
at r_glade, `-P/OpeningCam`), and when the HUD showed again one canvas pipeline compiled in a 17.6 ms frame, 7.1 ms of
it the deferred frees; its spec compiles (7) are background ones in 7-11 ms frames. "Cover's own part" is from the
tour's start (settle -> warm) to control, the part this lane changes; the Realm build before it moved by up to 3 s
between runs with other sessions' work on the machine.

The first final set (`<S>/after1/`, before 4eb08a98) had the same picture: moments 8 / 8, bosses 2 / 2, tour 10 / 1.
The last change (the sweep listening through the tour) added no record in any run (`PIPEWARM ... records after the nodes
added during the tour` equals the walk's count), so the cold tour's 10 -> 1 is variance between cold runs.

### The first final set (`<S>/after1/`)

| run | in-play PSO delta (canvas/mesh/surface/draw/spec) | frames over 16 ms (with a compile) | control (tour's load) | pipelines at play |
|---|---|---|---|---|
| moments cold | 92 -> **8** (0/0/1/0/7) | 23 (2) -> 10 (**0**) | 29.6 -> 31.9 s (27.3 -> 29.5) | 1489 -> 2737 |
| moments warm | 100 -> **8** (0/0/1/0/7) | 19 (4) -> 7 (**0**) | 28.5 -> 27.6 s (26.0 -> 25.2) | 1491 -> 2738 |
| bosses cold | 41 -> **2** (0/0/1/0/1) | 26 (5) -> 15 (2*) | 30.7 -> 30.0 s (28.1 -> 27.5) | 1499 -> 2738 |
| bosses warm | 41 -> **2** (0/0/1/0/1) | 17 (6) -> 14 (2*) | 29.0 -> 27.7 s (26.4 -> 25.3) | 1488 -> 2738 |
| tour cold | 124 -> **10** (0/0/1/0/9) | 109 (5) -> 19 (3*) | 31.1 -> 29.8 s (28.5 -> 27.3) | 1502 -> 2737 |
| tour warm | 123 -> **1** (0/0/1/0/0) | 53 (3) -> 20 (1*) | 28.5 -> 27.6 s (26.0 -> 25.2) | 1499 -> 2825 |

\* None of these is the compile's own. "With a compile" counts a slow frame with a compile in it or in the frame before:
- the first frame after the tour's calibration (90 frames at twice the render scale, then back): one *surface* compile
  in every run, before and after; the frame after it is 16.5-19 ms. A harness artefact (play never changes the scale).
- the Thornwarden's pull: spec+1 in the pull's own frame (9-10 ms); the next frame (24-25 ms: draw 10.8 ms, render CPU
  3.9, no compile in it) is the pull itself, as before (24.1-25.4 ms then, with spec+4 in it).
- the tour's teleport to r_thorn_deep (42 ms; 46 and 40 before): the staged Thornwarden built that frame (22 ms of
  scripts), a camp spawned, a new view (draws 1464 -> 2121); spec+1 in it (spec+6 before).

Nothing compiles between the cover lifting and the tour's first measured frame ("PSOWATCH cover lifted" = "live").
The remaining compiles are background spec compiles in 7-15 ms frames (the moments: one at the mount, two in the fight,
one on the road, three as the harness moves between moments).

Load: the cover's own part (from the tour's start to control) is 6.04-6.36 s against 5.96-7.07 s before; the
Realm build before it varied by up to 3 s between runs (other sessions' work on the machine), so control moves with it:
warm 0.9-1.3 s faster in every pair, cold between 2.3 s slower and 1.3 s faster. The control runs settle it: the old
loading screen (34c4545c) and the new one back to back, alternating, in the same machine state, a warm cache each
(`<S>/after1/control_*.log`):

| run | control | tour's load | in-play PSO delta |
|---|---|---|---|
| old, a | 28.41 s | 26.01 s | 93 |
| new, a | 27.84 s | 25.40 s | 10 |
| old, b | 28.56 s | 26.12 s | 90 |
| new, b | 27.64 s | 25.22 s | 8 |

The new loading screen lifts 0.6-0.9 s sooner (the tour at one frame a heading pays for the sweep, which fits inside
the panels phase), with a tenth of the in-play compiles. Cold, the cover's own part is 6.25-6.36 s against 6.22-7.07 s
before: the cold limit (+3 s) holds with room.

Both final sets ran at a 120 fps cap that came on between the diagnostic runs and them: code-identical diagnostic runs
were uncapped (the road's window 1,525-1,653 frames; here 1,300-1,318), and the old loading screen's control runs were
capped the same (1,321): the machine's, not the code's. The views' fps cannot be compared with the baseline's; the
compile counts and the slow frames can.

## Not done, and why

- **A Godot pipeline cache on Metal**: none in 4.7.2 (no file after a run or a player's quit, no "PSO cache" line in
  `--verbose`); no setting turns one on. Every launch builds its pipelines again from the shader cache, fast because the
  OS keeps its own Metal caches per user. A true first launch after a macOS or driver update (the OS caches cold too)
  could not be measured: that cache is Luke's (`$(getconf DARWIN_USER_CACHE_DIR)/com.apple.metal`), shared with the
  editor, and not ours to delete.
- **The map's first open** (a 70 ms frame in every run, before and after): no pipeline compiles in it; it is the map's
  own work on opening (`world_map.gd` `open`: the fog, the marks, the layout), not this lane's.
- **Particle process shaders** (compute) are not in the pipeline counters; the combat set's bursts and emitters (and now
  the road's wisp) still build theirs under the cover, as before.
- **What is left in play** (the final set): 7-8 background spec compiles in the moments (one at the mount, one or two
  in the fight, one on the road, the rest as the harness moves between moments), 1 in the Thornwarden's pull, 7 in one
  warm tour that played the staged opening; all in 7-15 ms frames, the ubershader drawing meanwhile. The compile log
  names no material for them ("nothing new in view"): a state the sweep's stand-ins do not reproduce exactly. A light of
  the lantern's kind over every view (A/B "full") took them to 2-3 but cost 1.0-1.3 s of every load; not kept.
- **The staged opening's end**: one canvas pipeline when its title layer goes and the HUD shows (17.6 ms frame, 7.1 ms of
  it the frees), seen once in twelve final runs; the HUD's hidden state under the opening is not warmed.
- **The calibration's surface compile**: the perf tour's own 90 frames at twice the render scale leave one surface
  compile on the first measured frame in every run, before and after; play does not change the scale.
- **Slow frames that are not compiles** (unchanged by this lane): the Thornwarden's pull frame (24-25 ms: the rise, the
  turn, the bar), the staged boss's build on the approach (22 ms of scripts, the hitch-warm lane's), teleports.
