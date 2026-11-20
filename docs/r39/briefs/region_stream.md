# r39 brief: real region streaming (pre-built regions, loaded off the main thread)

Luke, 20 Nov: "start on 1". Option 1 was real streaming, the way a shipped open world loads:
1. bake each region into finished pieces ahead of time;
2. load them in the background, off the main thread;
3. make each region a few big batches, so adding one is cheap.

The goal is loading that feels like Cyberpunk's, without adding hitches in play.

## Why the last attempt failed (read `docs/r39/load_stream.md` first)

Lane B streamed the flora's node building into play and measured it. Adding one flora `MultiMeshInstance3D` costs:
- 0.11 ms in the build's own run of adds;
- 0.33 ms under the loading screen;
- **2.4 ms on average (9-12 ms worst) while the player plays.** An empty node costs ~4 us.

Pumping the rest during play gave 69-107 frames over 16 ms. So it ships switched off (`--stream` turns it on), and today control comes at ~28 s:
- the Realm builds in ~15 s, most of it main-thread node and mesh building (lane A, `docs/r39/load_bake.md`): assets 1.8-3.5 s, lore 0.9-1.3, wonders 0.7-1.1, wayside build 1.4, flora 0.9-1.8, bosses 0.7, life 0.7, rift 0.55;
- render pass and merge 1.3-1.6 s;
- the warm-up tour.

What *was* kept and is yours to build on:
- `core/world/realm/realm_stream.gd`: ring jobs, nearest-first queue, `ensure(pos, r)`, `focus(pos, s)`, the slow-frame counter;
- flora emit split into pieces;
- flora readers working from data (`LifePlace.trunks` meta, `clear_discs`, `FloraFight` re-collect on `flora_serial`);
- the teleport and respawn hooks;
- the loading screen's `post_ready`/`post_done` split.

## Step 1: find out why an add costs 2.4 ms in play, before building anything

The whole design depends on this. Measure it, don't guess. Candidates:
- the render thread syncing on a MultiMesh buffer upload;
- AABB recomputation;
- the visibility and cull structures;
- shadow-caster registration;
- `FadeGuard`, `LightDirector` or groups reacting to `child_entered_tree`;
- the physics server for colliders.

Test the alternatives in a small probe scene with the real night running:
- adding pre-instanced subtrees;
- `RenderingServer` instances made directly (and from a worker thread, with `rendering/driver/threads/thread_model` checked);
- toggling `visible` on pre-added hidden cells;
- MultiMesh buffers set before entering the tree;
- adding through `call_deferred` batches;
- fewer, bigger MultiMeshes per cell.

Write the numbers into your checklist. Pick the design from the measurements.

## Step 2: pre-built regions

**Cells:** use the terrain tiles' grid (`terrain_tiles.gd`, 64 m) or 128 m cells, whichever the measurements favour.

**At bake time** (`-- --bake-cache`, the deploy step in `.cursor/skills/umbral-pack`), each cell's static content is saved as a finished resource in the Realm cache through `GenCache`, so the `_salts.bin` manifest and the fingerprints still decide trust:
- its flora as a few merged MultiMeshes per look;
- its static props and dressing merged (`core/util/mesh_merge.gd`);
- its static colliders.

**At run time:**
- **Kept global, as now:** the data stays built for the whole Realm: placement (lane A's `placement_cache.gd`), sites, quests, the map, nav, enemies, interactables and NPCs. Tests, the waypoint and the map need it.
- **Loaded on control:** the cells within ~150-200 m of the player load before control.
- **Background:** the rest load nearest-first with `ResourceLoader.load_threaded_request` (or the cheapest path step 1 found). They are instanced off the tree on a worker where Godot allows it, and only the final cheap step happens on the main thread under a strict per-frame budget.

**Draw ranges:** cells come in before they can be seen. Use the existing draw ranges and `far_detail.gd`'s impostors and shells, so nothing pops in sight.

**Teleport and respawn:** `ensure` / `focus` finish the target ring under the fade.

**Defaults:** headless and the tests keep a build-all default.

**Cache miss:** a cache miss (an edit, a cold first run) falls back to today's build-all path, never a broken world.

## Targets

- Control under 12 s from "Continue" on a warm cache on this Mac. Report the wall-clock time from process start.
- Zero frames over 16 ms caused by streaming in the first two minutes of play, and while walking or riding fast across the Realm. Measure with the slow-frame counter, `fight_bench` and the stutter probe.
- Same world: a test that builds a region streamed and built-all and compares node counts, transforms and collider shapes.
- **No regression** in steady-state fps or 1% lows on the perf tour (`zz/perf_tour`): one run at the start, one at the end.

If a target can't be met, say so plainly with the measurements. Don't ship a hitchy stream: switch it off by default as lane B did, and report.

## Lanes running beside you

A `hitch-warm` agent is finishing in its own clone:
- shader pre-warm behind the loading screen;
- bosses built ahead of the pull (`boss_kit.gd`, `boss_arena.gd`);
- `core/vfx/*`;
- a small warm hook in the loading screen.

Stay off those files. Where you must touch the loading screen, keep the change small and say so in the commit. The lead will ask you to merge master once it lands.

## Rules

- **Clone:** work only in your clone, on your branch (path in your prompt). Plain commit messages; never push; the lead merges. **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Godot lock:** one Godot process on the machine at a time, shared with the lead and the other agent.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` it after, also on failure.
  - If you kill one of your runs, `rmdir` the lock yourself.
  - In your wait loop, treat the lock as stale and remove it if `pgrep -x godot` finds nothing for 60 s straight (not `pgrep -f`, which matches shells).
  - Watchdog every run.
  - Windowed runs use `--always-on-top`; check CPU 20-30 s in and kill the run under ~20% (a window behind others is throttled to 0%).
  - Never start a second wait loop on the same file; kill your leftovers.
- **Measuring:** measure at the start (the step 1 probe, one baseline load and one perf tour) and once at the end; short runs that settle a doubt are fine. No test suite or batches while building. Run the tests once at the end (`--quick`, then the world tests you touched), and fix what they find without loosening checks silently.
- **Never:** never enable dynamic resolution; never rebake `world/main.tscn`; never cut content.
- **Flora:** don't change placement rules (the flora scatter is one random stream per layer).
- **Stutter is Luke's top complaint.**
- **Code:** typed calls, `tools/lint.sh` (the ratchet fails files over 1000 lines). Follow Godot practice (AGENTS.md).
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/region_stream/`. Delete what you don't need.

## Report

Keep a live checklist at `docs/r39/region_stream.md`. Report only when done end to end:
- branch and commits;
- the step 1 findings;
- the design chosen;
- before/after time to control, frames over 16 ms and steady fps;
- the cache size added;
- files touched outside your lane;
- what you could not do and why;
- test results.
