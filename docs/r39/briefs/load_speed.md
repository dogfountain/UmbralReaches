# r39 brief: load like a shipped open world, and take the hitches out

Luke, 20 Nov. He asked why the game loads slower than Cyberpunk, which is 100+ GB. The lead's answer:
- Cyberpunk reads a finished, pre-baked world and streams only what's near you, with precompiled shaders.
- Umbral Reaches re-solves much of its world in GDScript on every start. The Realm builds in ~17.5 s, the realm-done mark is ~31.9 s, and the whole 740 x 548 m Realm builds at once.
- Shaders compile on first sight (21 ms hitches).

The fixes:
1. bake every placement result into the cache;
2. stream by region;
3. move heavy work to threads or C++;
4. precompile/pre-warm the shaders.

Luke: "do all, spawn sonnet agents, maybe this will help with hitches".

Three agents run in parallel, each in its own clone and lane. **Stay in your lane's files.** Where you must touch a shared file, keep the change small and say so in the commit, so the lead can merge the three branches.

## Everyone reads first

- `AGENTS.md`, `ARCHITECTURE.md`, `.cursor/skills/umbral-culling`, `umbral-pack` and `umbral-donts`.
- The `DECISIONS.md` rows on opt-load (16 Nov: the warm boot went 44 -> 14 s; what was cached and why) and on the frame pacing.
- `docs/r39/visual_perf.md`: its perf rows, PE2 (the Hollow Lantern's 27 ms script spikes), the PSO compiles and the boss built in the pull frame.
- Code:
  - the cache: `core/world/realm/gen_cache.gd`, `land_cache.gd`, `flora_cache.gd`;
  - streaming that exists: `core/world/area_streamer.gd`, which streams the Ossuary and interiors;
  - the shell and draw management: `core/world/zone.gd`, `mesh_chunks.gd`, `fade_guard.gd`, `light_director.gd`, `far_detail.gd`.
- The load log: run the night once (`zz/perf_tour` or a `--quit-after` boot) and read the REALM / FLORA laps / WAYSIDE / WONDER / ENEMYSPAWNER / REALM_NAV / ATMOS timing lines. They name where the 30 s goes.

## Lane A: `load-bake` (bake the placed world, then thread what is left)

**Owns:** the placement passes and the cache.
- `core/world/realm/realm_wayside.gd` and wayside_*, `wonders/*`, `lore/*`, `realm_pois*.gd`, `realm_bosses.gd`, `doubled_realm_places.gd`, `lamps/*`;
- `core/enemy/enemy_spawner.gd` placement (settling);
- `core/life/secrets/*` placement;
- `gen_cache.gd`, `land_cache.gd`, `flora_cache.gd`, `zz/storage_cache.gd`, `zz/realm_walks.gd` (the bake).

**Goal:** a warm boot reads results instead of solving them.
- **Profile first:** one load with every pass timed.
- **Cache every deterministic placement pass:** the wayside plan, wonders, lore sites, POIs, camps settled on the ground, secrets, lamps, ambush sites, quest spots.
- **Cache keys** follow the existing fingerprint scheme (`_salts.bin`). A layout or generator edit must invalidate exactly what it changes: never a stale world.
- **Then move whatever is still heavy onto `WorkerThreadPool`:** pure-data passes (sampling, scoring, path distances) off the main thread, with only node creation on it. C++ (GDExtension) only if a profiled hot loop still dominates after caching; say why in DECISIONS.md.
- **Equality:** a cached boot and a fresh solve must give identical results. Add a test that builds both and compares the placement lists.
- **Target:** realm-done under 12 s on a warm cache on this Mac (M4 Pro). Report the before and after laps.

## Lane B: `load-stream` (build near the wanderer first, the rest behind)

**Owns:** the build order and presentation.
- `core/world/zone.gd`'s load sequence and loading screen, `area_streamer.gd`, `mesh_chunks.gd`, `far_detail.gd`, `fade_guard.gd`, `flora_emit.gd`;
- the terrain tiles (`terrain_tiles.gd`), the realm builder's node instancing;
- `ui/` loading screen code.

**Goal:** the player gets control as soon as the ground round them is ready.
- **Load data, stream nodes.** The placement data stays global, because quests, the map, the waypoint and the tests need all of it. What streams is the node/mesh instancing and emission:
  - Build the ~150 m round the spawn or save point first and hand over control.
  - Instance the rest in sliced background work, nearest first, under a per-frame budget (~2 ms on the main thread).
  - Nothing in sight pops in: rings are built before they come into view (use the draw ranges and the far-detail impostors already there).
- **Correctness:** physics and nav near the player are ready before control. Enemies, quest objects and interactables are never missing when you get there.
- **Tests:** they keep building the whole Realm, so give them a "build all now" switch that is the default headless.
- **Fast travel and death respawn:** these jump far, so the target ring must be ready before the fade lifts.
- **Target:** control in under 10 s from "Continue". No frame over 16 ms while the background build runs (measure with the frame-pacing tools: `fight_bench`, the stutter probe).

## Lane C: `hitch-warm` (shaders and the remaining hitches)

**Owns:**
- shader and material warm-up: a pipeline/PSO pre-warm behind the loading screen or a first-launch pass, every material, particle and VFX variant, the boss materials;
- `core/enemy/boss_kit.gd` warm and build, `core/world/boss_arena.gd`;
- the Hollow Lantern's subtree (PE2 in `visual_perf.md`);
- `core/vfx/*`.

**Goal:** no first-use hitch anywhere.
- **Every material/shader variant the night can show** is compiled before play. Cover:
  - the distinct material/mesh-format/light-count combinations: draw each once offscreen or use Godot 4's pipeline cache;
  - the first fight's VFX, the boss titles and bars, the weather, the lava, water and glass.
- **The boss's build:** build it ahead of the pull, sliced over frames as the wanderer nears the arena. The pull must cost under 4 ms. Today it is 10-17 ms, and 223 ms for the Thornwarden's first un-warmed build. Keep the arena's spawn timing that other systems read: change when the nodes are made, not when the fight starts.
- **The two 27 ms script spikes in the Hollow Lantern:** find and fix them.
- **Target:** zero frames over 16 ms on the perf tour's first views and on each boss pull. Report the PSO count and the spike list before and after.

## Rules for all three

- **Clone:** work only in your own clone, on your branch (path in your prompt). Plain commit messages; never push; the lead merges. **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Measuring:** measure once at the start (one load profile, one perf tour or stutter probe, as your lane needs). Build every change. Measure once at the end.
  - A short run that settles a specific doubt is fine.
  - No test suite or test batches while you build. At the end run `tools/run_tests.sh --quick`, then the world tests that cover what you touched, and fix what they find without loosening a check silently.
- **Godot lock:** one Godot process on the machine at a time, shared by all three agents and the lead.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s while it exists); `rmdir` it after, also on failure.
  - Give every run a watchdog. Kill a run that fails to load (parse error) at once.
  - Never wait with a pgrep loop.
  - Keep runs short (minutes) so the others get turns.
- **Never:**
  - never enable dynamic resolution;
  - never rebake `world/main.tscn`;
  - never cut content;
  - no new shadowed lights.
- **Frame stutter is Luke's top complaint.** A faster load that adds hitches in play is a failure.
- **Flora:** the scatter is one random stream per layer, so any keep-out change reshuffles trees realm-wide. Don't change placement rules; cache and stream what exists.
- **Code:** typed calls, not `.call("x")`/`has_method`. Run `tools/lint.sh` any time. Follow Godot practice (AGENTS.md).
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/<your lane>/`. Delete what you don't need.

## Report

Only when your lane is done end to end, report:
- branch and commits;
- the before/after numbers (load laps, time to control, frames over 16 ms, PSO compiles, boss pull cost);
- what you changed in files outside your lane;
- what you could not do and why;
- the test results.

Keep a live checklist at `docs/r39/<your lane>.md` so you can be resumed.
