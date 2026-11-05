# Backend / performance critique (r30)

Reviewer: performance and backend optimisation. Read-only review of the working tree on 2026-11-04,
Godot 4.7.2, Apple M4 Pro. No project file was changed apart from this report.

## Verdict

**The CPU side is healthy. GDScript is not why the game misses 120 Hz.** With the Realm built,
standing at spawn, every `_process` and `_physics_process` together costs **0.89 ms per frame
(mean), 1.9 ms at p99**. In a 5-enemy fight it is **0.97 ms mean, 3.4 ms at p99 on frames that run a
physics tick**. That leaves most of an 8.33 ms frame free. The danger to a stutter-sensitive 120 Hz
player is elsewhere:

1. **One-off main-thread hitches on gameplay events.** A save costs 3.2–3.5 ms and runs 0.6 s
   after every kill. A Shade spawn measured 15.5 ms when its shared data was not yet built.
2. **Low-rate updates drawn without interpolation.** These visibly step at 120 Hz: birds and
   flocks, villager limbs, enemies past 16 m, and the herds' new interpolation whenever the tick
   rate changes.
3. **A pacing setting.** `physics_jitter_fix` is left at its default 0.5 while physics interpolation
   is on.
4. **GPU cost**, mainly the grade running at output resolution. That is the one big measured GPU
   regression in `docs/perf_baseline.md`.

The wildlife "glide" was redesigned during this review: herds now interpolate in the working tree.
That is the right design. Two details still make it step (#3).

No Critical findings. Five High, nine Medium, nine Low.

## How this was measured

Everything ran headless on a **copy** of the project in the scratchpad, never on the project itself.
Dev runs write `res://art/realm_cache` (see #10), so running in place would have changed project
files. The copy ran with `HOME=/private/tmp/claude-501/perf_home`, so it never touched Luke's save,
settings or codex.

- `zz/critD_lifeprof.tscn` (unchanged tool), and two scratch probes that exist only in the copy:
  - **bx_probe:** census, save cost, `find_children` cost.
  - **bx_stamp:** per-frame script time from first-in-line and last-in-line stamp nodes, for
    `_process` and `_physics_process` separately. It runs 12 s idle at spawn, then 30 s of a fight
    against a 5-enemy camp at (−80, 6, −56) with `Engine.max_fps = 120`, and logs `Events`.
- Luke's own app logs were read, never written:
  `~/Library/Application Support/UmbralReaches/logs/godot2026-11-04T19.12.29.log`.
- The shipped binary was checked: it is a **release template**. It refuses `--remote-debug` with
  "compiled without debug".
- **I did not measure GPU time.** Only headless and Movie Maker runs were allowed, and neither
  reports it. GPU statements below cite `docs/perf_baseline.md` and HANDOFF figures.
- `perf_tour --blame` cannot run headless: `_cal_step` waits on `Engine.get_frames_drawn()`, which
  never advances. I stopped my own run (my PID).

| Measurement (headless, M4 Pro) | Value |
|---|---|
| Nodes under the night / object count | 9,445 / 19,340 |
| Nodes with process / physics on | 102 / 78 |
| MeshInstance3D / MultiMeshInstance3D / MM instances | 2,459 / 2,278 / 48,390 |
| Lights (shadowed) / GPUParticles3D / FogVolume / AudioStreamPlayer3D | 101 (1) / 110 / 16 / 210 |
| Enemies in group / awake idle / awake in the fight | 56 / 7 / 11 |
| Scripts per frame, idle (all frames) | mean 0.89, p90 1.49, p99 1.92, max 3.32 ms |
| Idle, frames with a physics tick vs without | mean 1.28 vs 0.50 ms |
| Fight, frames with a physics tick vs without | mean 1.45 / p99 3.44 vs mean 0.49 / p99 1.13 ms |
| Worst fight frame | **15.5 ms physics**, the frame `shade_spawned` fired (t = 9.70 s) |
| `Travel.save_game()` | **3.20–3.48 ms** (of which `find_children` over 9,445 nodes: 2.04–2.27 ms) |
| Wildlife director (lifeprof) | median 161 µs, p90 471 µs, worst 1,385 µs per frame |
| Realm build, Luke's 19:12 log | 4,438 ms; loading screen done at 5.01 s; Ossuary 294.6 ms |

---

## Findings

### Critical

None found.

### High

#### 1. `physics_jitter_fix` is still 0.5 with physics interpolation on

- **Evidence:** `project.godot` `[physics]` sets `common/physics_interpolation=true` but never sets
  `physics_jitter_fix`. No game code changes it either. Only the unused phantom_camera addon sets
  it to 0 (`addons/phantom_camera/scripts/managers/phantom_camera_manager.gd:79`), and addons are
  excluded from the export.
- **Why it matters:** Godot's documentation for this setting says to set it to 0 when physics
  interpolation is used. Jitter fix nudges how many physics ticks land in each frame. At 120 fps
  over 60 Hz physics you want a steady 1, 0, 1, 0 pattern and a smooth interpolation fraction.
  Jitter fix can produce 2-tick and 0-tick runs when frame times wobble. Those show up as small
  hitches in the interpolated body and camera, exactly what Luke reports as "feels under 60".
- **Cost:** none to fix.
- **Fix:** add `common/physics_jitter_fix=0.0` under `[physics]`. Re-run `zz/smooth_probe` with
  `--vsync=0 --cap=120` before and after, and compare camera and body step jitter.

#### 2. Every save walks the whole scene tree and parses the save four times, on the main thread, 0.6 s after every kill

- **Evidence: the trigger chain.**
  - `autoload/travel.gd:61-63`: a kill calls `give("grave_ash", …, false)`.
  - `:223` → `save_soon()` → `:253-259`: `save_game()` 0.6 s later.
  - Direct `save_game()` calls also come from secrets (`core/life/secrets/state.gd:50`), kindling
    (`kindling.gd:439`), encounters (`director.gd:583`), relics (`save_now`), seals and bosses.
- **Evidence: what each save does.**
  - `_remember_kindles` (`travel.gd:174-185`) runs `scene.find_children("*", "Node", true, false)`
    over all 9,445 nodes, only to find lit braziers.
  - `_base_cfg` (`:406-411`) encodes and re-parses the last config.
  - `_write_save` (`:429-446`) writes it, reads the temp back and parses it, then loads and parses
    the old save again just to decide whether to copy `.bak`.
- **Measured:** 3.2–3.5 ms per save (2.0–2.3 ms of that is the tree walk). At 120 Hz that is 40 % of
  a frame, landing in the middle of combat.
- **Fix (about 1 hour):**
  - Keep a brazier registry: a `Groups.BRAZIER` group, or have braziers register on `_ready`. The
    walk becomes O(braziers).
  - Keep `_loaded_cfg` as the canonical object instead of encode-then-parse.
  - Drop the `prev.load()` validation and track a `_last_write_ok` flag instead.
  - Optionally move `cfg.save` and the rename into a `WorkerThreadPool` task.
  - Let ash from kills ride a longer debounce (rest, area change, quit, or a 10 s timer). Key items
    keep `save_now`.

#### 3. Herd interpolation still steps when the tick rate changes, and birds and flocks still guess ahead

- **What changed:** during this review the working tree switched herds from extrapolation to
  interpolation between the last two ticks (`core/life/wildlife/life_beasts.gd:596-652`, "r30").
  That is the right design. A 10–30 Hz "brain" with drawing one tick behind is cheap and continuous
  at any refresh rate. My assessment of the old guess-ahead glide matches the new comment: it never
  carried height or turn forward, so every tick on a slope or in a turn popped the deer.
- **Remaining defect 1: the span is the last tick's span.** `al = ahead / _tick_dt` (`:623`), with
  `_tick_dt` set from the *previous* tick's dt (`:199`). The director changes the next interval
  with distance and view (`life_director.gd:614-631`): 30 Hz within 16 m, 7.5 Hz from 16–45 m while
  moving, 5 Hz out of view.
  - A deer crossing 16 m outward: the drawing reaches the newer pose after 33 ms, then holds for
    100 ms. That is a stall followed by a jump.
  - Crossing inward: the next tick arrives before `al` reaches 1, so the remaining fraction is
    skipped. That is a pop.
- **Remaining defect 2: the accumulator resets to zero.** The director does `_acc[k] = 0.0` after a
  tick (`life_director.gd:649`) instead of subtracting the interval. At 120 fps a 1/30 s interval
  therefore spans 4 or 5 frames depending on float rounding. Interpolation then reaches `al = 1`
  one frame early on some ticks and holds: a 1-frame hitch every few ticks.
- **Birds and flocks:** these still extrapolate along their velocity at the tick:
  - `life_birds.gd:679-701`: `_gp[i] + _gv[i] * ahead`, no turn and no height change.
  - `life_flock.gd:270-280`: the same.
  At 15 Hz near and 7.5 Hz further out, every course change is a kink.
- **Fix (about 2 hours):**
  - Pass the interval the director will use next to `glide(acc, interval)` and use
    `al = acc / interval`.
  - Keep the phase: `_acc[k] -= interval`, clamped to at most one interval.
  - Port the two-snapshot interpolation to `life_birds` and `life_flock`. The wheeling roost's
    rotation trick can stay.
  - Simpler alternative for herds: per lifeprof, deer cost about 17 µs per group per tick, so a
    *moving* herd in view under 45 m can simply tick every frame (interval 0) for under 0.1 ms in
    total. Keep 30/7.5 Hz with interpolation only for idle or far groups.

#### 4. Other rate-LODs that skip interpolation, and step at 120 Hz

- **Enemies past 16 m freeze their pose but keep moving.** `_rig.animate(...)` only runs when
  `_dist < 16.0` (`core/enemy/enemy.gd:987`, and `:944/:982`), yet `move_and_slide` moves the body
  every tick. A pack running in from 16–46 m (`sleep_range`) glides as statues.
  - **Fix:** animate at 15–20 Hz past 16 m. The rig already blends bones between captures
    (`character_rig.gd:1439-1446`, `_apply_bones(f)`), so feed it `animate()` on alternate ticks
    instead of none.
- **Villagers past 11 m pose at stepped rates with no bone interpolation.** Rates are 30 Hz walking
  at 11–20 m, 12 Hz past 20 m, 5 Hz past the freeze radius while walking, and 2 Hz off-screen
  (`core/npc/npc_life.gd:152-167`, used by `villager.gd:476-482`). The root moves every frame but the
  legs step at 12 Hz.
  - **Fix:** apply the CharacterRig scheme: keep the previous and current pose and blend in
    `_process`.
- **Weather** steps at 40 Hz (`weather.gd:187-196`): the rain emitter follow, sway and fog offsets.
  Probably invisible; listed so it is a conscious choice.
- **Cost:** a few hundred µs at most. The CPU headroom is there.

#### 5. The grade runs at output resolution, the largest measured GPU regression

- **Evidence:** `docs/perf_baseline.md` "1.6 + 2.2" table. Moving the grade from the 960-row 3D
  buffer to the canvas (about 1920×1205) took sanctuary GPU from **4.90 to 6.74 ms**. The 1 % low
  fell from 117.5 to 85.7 fps; summit went from 4.58 to 6.65 ms.
- **Per-pixel cost** (`world/post/grade.gdshader`): 7 screen-texture fetches (3 for chroma, 4 for
  the unsharp mask), two `rgb2hsv` → `hsv2rgb` round trips, two `pow`, a full-frame backbuffer copy
  from `hint_screen_texture`, and grain.
- **Overlap with FSR:** the 3D upscale is now FSR 1 with RCAS sharpening (register line 41), so the
  grade's unsharp mask sharpens a second time.
- **Fix (about half a day):**
  - Move the colour work (hue pull, split tone, contrast, vignette, gloom and hurt) into a
    `CompositorEffect` (post-tonemap compute) or a full-screen spatial quad at internal resolution.
  - Leave only grain (and chroma if it must stay) on the canvas.
  - Or, at minimum: drop the 4-tap unsharp in favour of RCAS (`fsr_sharpness`), and replace the HSV
    round trip with a 2D chroma rotation in YCoCg space.
- **Expected gain:** 1–1.5 ms GPU at 120 Hz. **Re-measure first:** the baseline numbers predate the
  r29 FSR and output changes.

### Medium

#### 6. Shade spawn hitch

- **Measured:** 15.5 ms in one physics frame, exactly when `shade_spawned` fired (`player.gd:727-745`
  → `Shade._ready`, `core/enemy/shade.gd:43-66`, `:322-370`). In the shipped game the loading
  warm-up pre-builds the shared meshes (`loading_screen.gd:280`), so part of this goes away.
- **Work still done on every spawn:**
  - `load("…shade_whisper.wav").duplicate()` (`shade.gd:55`) copies the whole sample buffer.
  - A new `GradientTexture2D` is built on the CPU.
  - A `Decal`, a `FogVolume`, two `OmniLight3D`s and two new `GPUParticles3D` emitters are added.
- **Fix (about 1 hour):**
  - Make the looped WAV a static, built once.
  - Make the gradient texture static.
  - Build one hidden Shade at load and reuse it (`Shade.take()` / `release()`), or at least spawn
    on `call_deferred` outside the physics step.
- **Verify** with `zz/perf_tour --hitches --loading` by forcing a Shade.

#### 7. Vfx burst pool keyed on hit damage, so the cache grows without bound and pooling fails

- **Evidence:** the key is `"%s|%s" % [color, opts]` (`core/vfx/vfx.gd:47`, `_proc` key `:114`). The
  hit burst puts damage into the options: `"count": 10 + int(dmg * 4.0)` and `"speed": Vector2(1.5,
  3.8 + dmg)` (`enemy.gd:277`). Damage carries multipliers from cores, charms, ranks and elites, so
  it takes many values.
- **Effect:**
  - Each distinct damage value is a new preset: a new `ParticleProcessMaterial` kept forever in the
    static `_procs`, plus a new `GPUParticles3D` node with its GPU buffers.
  - The 6-per-preset pool is mostly bypassed.
  - A Dictionary is turned into a string on every burst.
- **Fix (30 minutes):** quantise to 2–3 sizes (small, medium, big) or key on a preset name. Scale
  the count with `amount_ratio` at play time.

#### 8. Enemy flesh is always alpha-tested

- **Evidence:** `core/enemy/flesh.gdshader:75-78` writes `ALPHA = 1.0;` and
  `ALPHA_SCISSOR_THRESHOLD = 0.5;` unconditionally.
- **Effect:** every enemy body in every pass (depth prepass, shadow, colour) runs as alpha-scissor,
  only so the death dissolve can work. The prepass then runs the fragment shader, including the two
  `vnoise` calls for `d`. On Apple's tile-based GPUs, a discard path stops the hardware skipping
  hidden fragments for those draws.
- **Fix (1 hour):**
  - Make two materials from one shader file, with `#define DISSOLVE` around the alpha lines (or a
    shader include).
  - Bodies use the opaque one.
  - `Enemy._die()` swaps `material_override` on the `_flesh` parts to the dissolve variant.
- **Expected gain:** small per enemy, but it applies to every enemy at all times.

#### 9. Load time is still 4.4 s of build, and most of it is cacheable

- **Evidence:** Luke's 19:12 app log: `REALM built in 4438 ms`, loading done at 5.01 s.
  - Flora 987 ms, lore 762, rift 594, cull scatter 434, land 418.
  - `AREA load ossuary 294.6 ms`; post-build 370 ms over 29 frames.
- **Why it is cacheable:** the meshes are already in GenCache. What remains is placement, which is
  deterministic for a given seed and generator source: physics-ray placement loops (flora, lore),
  `WorldLanes.cull_scatter`, and stamping.
- **Fix (1–2 days):**
  - Cache each module's placement output (transform buffers, kept instance indices) in GenCache,
    salted by the generators *and* by `realm_land.gd`.
  - Where cache misses still need ground, use `RealmLand.height_at` instead of rays.
- **Expected gain:** about 2 s off every launch.

#### 10. Every dev and test run rewrites the shipped cache

- **Evidence:** `GenCache.dev()` is true for any run of the editor binary from the project folder
  (`core/world/realm/gen_cache.gd:36-40`). Such runs write `res://art/realm_cache/` and rewrite
  `_salts.bin` (`:71-80`, `:98-101`). That includes every `zz/` test.
- **Consequences:**
  - The git working tree churns.
  - Luke's 19:06 log shows the cache carrying **22 stale entries (7.8 MB) and 155 duplicate
    geometries**.
  - His `user://realm_cache` holds 15 `mesh_chunks` entries the pack did not have, which were
    rebuilt on first launch.
- **Fix (1 hour):**
  - Write to `res://` only with an explicit `--bake-cache` flag (or in a dedicated
    `zz/storage_cache --bake`); otherwise write to `user://`.
  - Run prune and bake as a step of the umbral-pack skill.
  - Dedupe geometry by content hash at save time.

#### 11. Wildlife ticks bunch onto the same frames

- **Evidence:** `_cache_groups` sets `_acc[k] = 0.0` for every group at once
  (`life_director.gd:737`). Every group with the same interval then ticks on the same frame.
- **Measured (lifeprof):** director median 161 µs, but p90 471 µs and worst 1,385 µs.
- **Fix (5 minutes):** seed `_acc[k] = interval * fract(k * 0.618)`.
- **Related:** several systems scan all enemies independently:
  - `life_director` (2 Hz), `scape_music._sense` (2 Hz), the encounters director, `village._mode_now`.
  - `Enemy._update_separation` for each awake enemy at 10 Hz, over all 56 enemies, sleeping ones
    included.
  They are cheap today (`get_nodes_in_group(enemy)` is 0.5 µs). If the enemy count grows, one
  shared enemy index on the Zone (positions refreshed at 10 Hz, a coarse grid) would replace all
  five.

#### 12. Lava bank re-map takes 2.5 ms per frame during play

- **Evidence:** `SLICE_US := 2500` (`core/world/lava_works.gd:18`); maps run twice
  (`:59-61`, `:79-81`).
- **Luke's log:** the first map (901 ms of rays) finishes under the loading cover. The second,
  `unchanged … (76 ms of rays)`, runs after the cover lifts, about 30 frames at +2.5 ms.
  Headless runs saw it reach 350 ms, about 140 frames.
- **Fix (30 minutes):**
  - Once the cover is gone, slice at 1,000 µs.
  - Skip the re-map unless the Ossuary area was actually (re)loaded in the meantime: hash its
    collision shape count, or listen to `AreaStreamer`.

#### 13. Physics on alternate frames at 120 fps

- **Measured (fight):** frames with a physics tick average 1.45 ms of script (p99 3.44); frames
  without average 0.49 ms (p99 1.13).
- **Why it is Medium, not High:** at present the CPU is pipelined behind a GPU that takes 5–7 ms,
  so this is hidden. It becomes visible stutter only if the GPU gets faster than the CPU (Luke runs
  shadows off).
- **Fix:** after #1, run `smooth_probe` and `perf_tour --luke --hitches`. If alternate-frame cost
  shows up, set `physics_ticks_per_second=120` when the cap is 120 or more (about +0.6 ms CPU per
  frame), or move idle enemies' `move_and_slide` to think rate (see #18).

#### 14. The hotbar redraws every frame

- **Evidence:** `ui/hotbar.gd:36-64` calls `queue_redraw()` unconditionally, after building a
  signature string every frame. `_draw` re-issues the whole bar: rects, arcs, polygons,
  `draw_string`, and `draw_string_outline` for the names.
- **Fix (30 minutes):** redraw only while a cooldown is running, a ready-pulse is above 0, the name
  fade is live, or the signature changed. The HUD gloom bar already does this (`hud.gd:231-233`).

### Low

#### 15. LightGrid loops over untyped dictionaries in the enemy physics path

- **Evidence:** `autoload/light_grid.gd:21-50`. `repel()` runs twice per enemy per tick
  (`_light_barrier`); `is_lit()` runs per think and per aim.
- **Measured:** 0.38 µs per call with 1 zone. It grows linearly with lit braziers and wards.
- **Fix:** keep zone centres and radii in a `PackedVector3Array` and a `PackedFloat32Array`.
  Braziers do not move.

#### 16. Vfx.ribbon allocates a new material and mesh on every call

- **Evidence:** `vfx.gd:339-373` creates a new `StandardMaterial3D` and `ImmediateMesh` per call. It
  is used by every enemy swipe (`enemy.gd` `_swipe_fx`) and twice per `arc`.
- **Fix:** share one material per blend mode and fade through vertex alpha, or pool 8
  MeshInstances.

#### 17. Per-frame light and audio pokes

- **Light flicker:** `brazier.gd:140-157` and `glimmers.gd:71-77` set `light_energy` every frame.
  The flicker could live in the flame shader, with the light updated at 30 Hz.
- **Audio bus writes:** `ambience.gd:402-445` (`_rooms`) writes the bus volume, lowpass cutoff and
  effect-enabled flags every frame even when muffle is 0.
- **Fix:** write only on change. Small either way.

#### 18. Idle awake enemies still run `move_and_slide` at 60 Hz

- **Evidence:** `enemy.gd` `_move`. Idle awake enemies within 46 m still slide every tick.
- **Fix:** while `IDLE` and on the floor with zero intent, skip the slide. Small now (7–11 awake).

#### 19. Mirror glass builds a mipmapped screen copy

- **Evidence:** `world/portal_glass.gdshader:5` uses `filter_linear_mipmap`, which forces a mip
  chain of the screen copy whenever a mirror is on screen.
- **Fix:** `filter_linear` is enough for a vortex refraction.

#### 20. Frame pacing setup on Luke's machine

- **Current settings:** `vsync=false`, `fps_limit=120` on the 144 Hz VRR AOC (his `settings.cfg`,
  read only). Godot's sleep-based limiter paces less evenly than the display.
- **Fix:** with Variable Refresh on (HANDOFF r25), try V-Sync on with the cap at 120, and confirm
  with `smooth_probe --vsync=1 --cap=120`.
- **Also:** with V-Sync on, `effective_max_fps` sets max_fps equal to the refresh
  (`settings.gd:271-276`). A cap 2–3 fps under the refresh avoids queueing on fixed-refresh panels.

#### 21. Exit leaks

- The log at exit reports "3 ObjectDB instances leaked" and 2 DummyShader RIDs (realm_ground
  globals). These are already in the register, as log noise only.

#### 22. Export pack

- It is a release template (good).
- The pack ships the stale and duplicate cache entries from #10 (about 8 MB stale).
- `texture_format/s3tc_bptc` for a macOS app is fine on Apple Silicon.
- The 215 MB pack loads under the 5 s cover.

#### 23. Profiling instrumentation left in hot loops

- **Evidence:** `life_director._process` (`:567-689`) calls `Time.get_ticks_usec()` 2–3 times per
  active group per frame. It also builds the `ctx` Dictionary (`:591`) and a `moths.keys()` array
  (`_rescan`) every frame, and sorts a 120-entry ring every 120 frames.
- **Fix:** guard the instrumentation behind `OS.is_debug_build()` or a flag. It costs tens of µs.

---

## Top 10 to do first

1. **#1:** set `physics/common/physics_jitter_fix=0.0`, then confirm with `zz/smooth_probe`. One
   line, aimed directly at the "feels under 60" complaint.
2. **#2:** add a brazier registry to `Travel._remember_kindles` and stop the save's re-parse and
   `.bak` re-load, so saves drop from about 3.4 ms to about 0.3 ms. Give kill ash a longer debounce.
3. **#3:** for wildlife, interpolate over the *next* interval, keep the accumulator phase, port
   two-snapshot interpolation to birds and flocks, and let moving herds in view tick every frame.
4. **#11:** stagger the wildlife tick phases (one line); the director's p90 and worst frames drop.
5. **#5:** re-measure the grade with `perf_tour --attrib --feat=grade`, then move the colour math
   to internal resolution and drop the unsharp in favour of RCAS. Expect 1–1.5 ms GPU.
6. **#6:** make the Shade's WAV and gradient static and reuse one Shade. That removes the 15 ms
   spawn frame.
7. **#4:** animate enemies past 16 m at 15–20 Hz through the existing bone blend, and blend
   villager poses between updates.
8. **#7:** quantise Vfx burst presets, ending unbounded `_procs` growth and per-hit emitter
   allocation.
9. **#10:** require an explicit bake flag before dev runs write `res://art/realm_cache`; prune and
   bake as part of packing.
10. **#9:** cache flora, lore and cull-scatter placements in GenCache, saving about 2 s per launch.
    Then **#8**, the opaque flesh variant.
