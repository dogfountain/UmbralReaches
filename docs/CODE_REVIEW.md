# Code review, 10 November 2026

A critique of the shipping code (`autoload/`, `core/`, `ui/`, `world/`: 465 scripts, about 142,000 lines) and the
test tooling (`zz/`, `tools/`). Part 1 is the critique. Part 2 turns each finding into a task an agent can do
without guessing: the files, the change, and the check that proves it is done.

## How far this review goes

This is not a line-by-line audit of 465 files. What was done:

| Depth | What |
| --- | --- |
| Read in full | `autoload/travel.gd`, `autoload/light_grid.gd`, `core/world/session_state.gd`, `tools/run_tests.sh`, `ARCHITECTURE.md`, both `.cursor/rules` files, `docs/PILLARS.md`, `docs/DECISIONS.md` |
| Read the main logic | `core/player/player.gd` (the whole physics tick), `core/enemy/enemy.gd` (the tick, targeting, separation), `core/world/realm/realm.gd` (the build order), `core/player/player_vitals.gd` (Gloom), `core/story/quest_runner.gd`, the quest audit in `core/story/quest_chains.gd`, `world/main.gd` (boot), `core/life/encounters/director.gd` (posts and bells), `core/world/world_lanes.gd` (the scatter cull), `core/world/realm/flora_cache.gd` |
| Scanned by script, every file | function lengths, timer callbacks, dynamic calls, static variables, per-frame tree scans, signal connections, group strings, command-line reads |
| Not read | `core/player/character_rig.gd`, the UI pages, the villager, the boss scripts, the Ossuary, the wildlife, the VFX and audio code. Claims about these rest on the scans only. |

Two things said in the first, shorter review turned out wrong on reading and are corrected here: `enemy.gd` is not
a tangle (see S4), and the timer callbacks are not a crash risk (see S3).

---

# Part 1. The critique

## Strengths (keep these)

**S1. The save system is careful.** `autoload/travel.gd` writes to a temp file and renames it, keeps a backup,
carries a format version, keeps keys it does not know, and type-checks every value on load so a damaged save
loads what it can (`load_game`, lines 406 to 461). Saves are throttled three ways (`save_game`, `save_soon`,
`save_lazy`) so a fight is not interrupted.

**S2. Static state is policed.** `core/world/session_state.gd` lists every static that holds a node or a
callable, resets night state on teardown, and `tools/run_tests.sh` fails when a new one appears unlisted.

**S3. Delayed callbacks are safe.** Of 72 one-line `create_timer(...).timeout.connect(...)` callbacks, the ones
sampled all capture an instance id and re-resolve it, or check `is_inside_tree()` first
(`core/life/progression/skills/nova.gd:42`, `core/enemy/attack_kit.gd:50`, `core/enemy/quiller.gd:110`). This is
the usual source of "freed object" crashes in Godot, and it is handled consistently.

**S4. The enemy is a real state machine.** `core/enemy/enemy.gd` is 2,314 lines, but it has an explicit state
enum (line 9), its longest function is 111 lines, thinking is throttled (`think_hz`), and the tick reads top to
bottom. It is long, not tangled.

**S5. Quest data is validated.** `QuestChains.audit()` (`core/story/quest_chains.gd`, from line 996) checks every
quest: known step kinds, a giver, a place for each visit, pickup counts, turn-ins, known rares and raids. The
quest tests fail on any miss.

**S6. The test runner is well made.** Isolated HOME per test, a watchdog, longest-first ordering from remembered
times, and failure on any script error, not only on a test's own FAIL line.

**S7. Rules that hold.** Five autoloads and no more. Zero TODO or FIXME comments. A lint ratchet that stops four
bad patterns from growing.

## Findings, most serious first

### F1. Placement fails silently, about thirty times in every boot

Every world builder places things by ray against whatever is already built, and when a spot is taken it prints a
line and carries on. A normal boot prints about 30 such lines (lore walls, cairns, lamps, terrace tiers "dropped").
Because 30 skips are normal, a new one is invisible.

- There are 30 `print(... skip ...)` sites in 16 files and 5 `push_warning` sites, each with its own wording.
- Nothing compares this run's skips with the last run's.
- Yesterday four bugs came from this and none raised an error: the brine-wife's notice post
  (`core/life/encounters/director.gd` `_post`), the gate bell (`_place_bells`), the lantern pillars' candles
  deleted by `WorldLanes.cull_scatter` (`core/world/world_lanes.gd:402`), and a Threshold terrace tier.

This is the root cause of most "is anything being verified?" moments. Task T1 fixes it.

### F2. The world is code, and the build is one long order-dependent sequence

- Shipping code has 4 scenes and 3 resources against 465 scripts. The rule in
  `.cursor/rules/godot-architecture.mdc` says "new content is a scene or a Resource".
- About 6,250 hand-typed `Vector2`/`Vector3` positions sit in `core/world/realm`, `core/life` and `core/story`.
- `Realm.build` (`core/world/realm/realm.gd:150`) runs about 20 steps in a fixed order. Each step sees only what
  earlier steps built, so adding a site changes what later steps can place (F1).
- Sites are plain dictionaries in `WorldLanes.sites` with no owner. "This prop belongs to this site" is a meta
  flag (`site_owned`) that each builder must remember to set; the candles were deleted because one did not.
- A place cannot be looked at without building the whole Realm (14 s warm on the M4).

Moving everything to scenes is not realistic now. T1 (make failures loud) and T6 (give sites owners) take most
of the risk out without a rewrite.

### F3. Weak typing where systems meet

- 640 string `.call("…")`, 1,521 `.get("…")`, 204 `.set("…")`, 246 `has_method` checks. Only 115 of 465 scripts
  have a `class_name`.
- A rename breaks at run time. Yesterday `zz/loot_r33_test.gd` crashed because a UI field was renamed in a
  rework three days earlier; nothing noticed until the full suite ran.
- Worst files: `ui/unit_frames.gd` (107), `ui/growth.gd` (85), `core/life/encounters/director.gd` (60),
  `core/story/quest_world.gd` (57), `core/life/village/villager.gd` (56).
- Much of it is forced by load cycles: 7 places carry a "no preload: a cycle" comment and use `load()` plus a
  dynamic call instead (`core/world/realm/realm.gd:168`, `core/life/secrets/director.gd:29`,
  `autoload/travel.gd:305`).
- The lint baseline is slack: `tools/lint.sh` reports counts below baseline in 37 places, so 37 files could
  regress without failing.

### F4. `Travel` is the save file, the inventory and some game rules, not only travel

`autoload/travel.gd` (695 lines) holds scene travel, the save and its slots, the whole inventory (`give`,
`count`), loot-bag restoration (a `_process` that polls twice a second), and game rules: what a boss kill pays,
which relic variant a boss's relic arrives attuned to (lines 81 to 88 and 260 to 263). 79 files read `Travel.`
directly. The rules file says autoloads are services. Three specific risks:

- **A save requested during a scene change is dropped.** `save_game()` returns at once when `_busy` (line 375)
  and nothing retries. A boss kill or a seal that lands during the fade is not written until the next save.
- **On Windows the rename may not be atomic.** `_write_save` (line 664) relies on `DirAccess.rename_absolute`
  replacing the save in one step. If Godot's Windows rename removes the old file first, a crash in between leaves
  no main save, and the backup is copied only once a session (line 676), so it can be hours old. The good `.tmp`
  file would still be on disk, but `_read_save` (line 644) never looks at it. **Not verified: needs a check on
  the Windows PC.** T3 makes it safe either way.
- **Saves are `ConfigFile`s,** which can construct objects while parsing. For a local single-player save that is
  low risk; do not load a save from anywhere else.

### F5. The player's states are an implicit chain of early returns

`Player._physics_process` (`core/player/player.gd:387`, 243 lines) has no state enum. Mantle, step, grapple,
climb, hang, vault, roll, glide, slide, steep, riding and hollowing are separate timers and flags, checked in a
fixed order with eleven early `return`s.

- Each early return must remember the per-frame duties itself. Gloom is ticked in eight separate places
  (`player.gd:407` and `:618`, `player_traversal.gd:171`, `:252`, `:347`, `:562`, `player_evasion.gd:222`,
  `player_mount.gd:39`). All eight are present today. The next new state that forgets it stops the game's clock
  (Pillar 1) with no error.
- The interact scan, the fall rescue and the stuck check (lines 619 to 627) do not run in the early-return
  states at all.
- The "components" are files, not components: all state lives on `Player` as underscore-private fields, the
  components read and write those fields, and `Player` calls the components' underscore-private methods
  (`locomotion._tick_slide`, `evasion._tick_roll`). The 56 `.get("_private")` lint hits are a symptom.

### F6. Tests are slow, load-sensitive, leave gigabytes behind, and nothing runs them automatically

- 74 tests; 56 boot the whole world (30 to 170 s each).
- Two tests (`rebuild_test`, `world_weather_test`) fail when the machine is loaded and pass alone; `raids_r34`
  did the same until its fixed wait became a poll.
- **`tools/run_tests.sh` never deletes its run folder** (line 32). 124 run folders totalling 15.7 GB had built
  up in the temp folder since 7 November. They were deleted during this review; the runner still leaks.
- 153 probe and shot scenes share `zz/` with the tests, and 175 files repeat the same "load `main.tscn`, wait for
  `realm_done`" boilerplate.
- There is no CI. A break is found when someone next runs the full suite by hand.
- A `push_warning` does not fail a test. "No clear spot for a bell" was a warning for days.

### F7. Test, demo and benchmark code ships inside the game

- 41 shipping files read command-line flags (76 reads). `world/main.gd` alone carries a walk recorder, a demo
  walk, two benchmarks and a shade smoke test (its header lists six flags).
- A flag changed game data: `--no-title` was part of the flora cache key, so packed test runs rebuilt the plants
  (`core/world/realm/flora_cache.gd:37`, fixed yesterday).
- 235 `print` calls run in the shipped build.
- The legacy baked stair still boots behind `--no-realm`, kept alive by 27 `Realm.enabled()` branches.

### F8. Docs and code have drifted apart

- `ARCHITECTURE.md` says "last verified 2026-11-05 (r36)". It does not list `core/world/realm/wonders/`, the
  lamps, the rift's Threshold files or `zz/bake_cache`.
- The pack recipe disagrees with practice: `AGENTS.md`, `ARCHITECTURE.md` and `umbral-constraints.mdc` all say to
  export the **Linux** preset; yesterday's packed checks used the **macOS** preset. One of them is wrong.
- `docs/PILLARS.md` still says the phase is consolidation and lists "an open world" and "an MMO treadmill" under
  "Not this game". `docs/DECISIONS.md` records the Realm doubling on 6 November, and the game has daily bounties,
  item level and gear sets. Pillar 4 ("small and finished beats big and promised") is being broken by decision,
  and the pillars file does not say so.
- `docs/THE_NIGHT.md`, which `ARCHITECTURE.md` calls "the current critique", is 11,877 lines and is not in git.

### F9. History is baked into names and comments

26 shipping files are named after a development round (`realm_pois_r34.gd`, `site_r37_east.gd`,
`quest_chains_r37_west.gd`), and 907 comments carry a round tag ("r36:"). A reader has to know the project's
history to find the Saltmarket's code. The lint already forbids new round tags; the old ones remain.

### F10. Performance risks to watch on the Windows PC

None of these is measured as a problem today. Each grows with content.

- `LightGrid` (`autoload/light_grid.gd`) scans every light zone linearly, and every enemy calls it three times a
  physics frame. Its own header says to switch to a spatial hash "once zones exceed ~64". The Realm has doubled
  since that was written and the zone count has not been re-measured.
- Eight effects scan every enemy every frame (`core/life/progression/fx/ward_aura.gd:59` and `:72`,
  `rift_rend.gd:37`, `step_mist.gd:38`, `ward_rite.gd:42`, `core/skills/nova_wake.gd:21`,
  `core/enemy/thornwarden.gd:170`, `core/life/wildlife/life_director.gd:746`).
- `Enemy._update_separation` (`core/enemy/enemy.gd:938`) loops over every enemy for each enemy. It should run at
  think rate only; confirm it does.
- 138 scripts have a `_process` or `_physics_process`.
- The save builds and writes on the main thread. It logs when it takes over 8 ms, which is the right instinct;
  watch that log on Windows.

### F11. Smaller things

- **Large files.** `core/player/character_rig.gd` (2,455 lines, 179 variables) and 29 more files over 900 lines.
  Ten functions are over 200 lines: `ui/growth.gd:1057` `_show` (268), `core/world/thorn_henge.gd:59` `_build`
  (264), `core/enemy/enemy_body.gd:279` `_humanoid_parts` (283), `core/life/progression/icons.gd:11` `draw` (291).
- **Raw group strings.** 104 calls still pass a group name as a string literal; 296 use `Groups.*`.
- **Signals are never disconnected** (298 connects, 2 disconnects). Safe while every listener dies with the
  night, which it does today. Worth knowing before anything outlives a night.
- **UI.** One UI scene; 25 scripts draw by hand in `_draw`. No text goes through `tr()`, so the game cannot be
  translated without touching every string. Controller bindings exist.
- **Repo.** 1.8 GB of git data. Commit subjects have a median of 130 characters and a maximum of 613, so
  `git log --oneline` is unreadable.

---

# Part 2. Tasks for agents

Rules for every task: work in a worktree, follow `AGENTS.md` and both `.cursor/rules` files, never headless-save
`world/main.tscn`, no round tags in comments, never wait with a `pgrep` loop, run `tools/lint.sh` and the named
tests, commit on the branch, do not push or merge. Report the commit, the test output, and anything not done.
Do one task per agent. T1 comes first; T2 to T5 do not depend on each other.

## T1. Make skipped placements loud (fixes F1)

**Goal:** one place records every skipped placement, and a test fails when a skip appears that was not there
before.

1. Create `core/world/realm/placement_log.gd` (`extends RefCounted`, no `class_name`):
   - `static var entries: Array[Dictionary] = []`
   - `static func skip(system: String, id: String, at: Vector3, why: String) -> void` appends
     `{"system", "id", "at", "why"}` and prints `PLACEMENT skip <system> <id> at <x,z> (<why>)`.
   - `static func reset() -> void` clears `entries`.
   - `static func keys() -> Array[String]` returns sorted `"<system>/<id>"` strings.
2. Call `PlacementLog.reset()` at the top of `Realm.build` (`core/world/realm/realm.gd:150`), and add
   `PlacementLog.reset()` to `SessionState.reset_night()` (`core/world/session_state.gd`).
3. Find every skip site: `grep -rnE 'print\(.*(skip|dropped|not clear|no clear|NOT BUILT|INCOMPLETE)' core world`
   (30 sites in 16 files) and `grep -rnE 'push_warning\(.*(no clear|no spot)' core world` (5 sites). At each one,
   keep the existing line and add a `PlacementLog.skip(...)` call with a stable id (the thing's own id or name,
   never a counter that changes between runs). Do not change what is placed.
4. At the end of `Realm.build`, just before `root.set_meta("realm_done", true)`, print
   `PLACEMENT %d skipped` with the count.
5. Create `tools/placement_baseline.txt`: the output of `PlacementLog.keys()` from one clean boot, one key a line.
6. Create `zz/placement_test.gd` and `.tscn` (copy the boot pattern from `zz/layout_r34_test.gd`): boot, wait for
   `realm_done`, read the baseline, and print `PLACEMENT FAIL new skip <key>` for every key not in the baseline,
   then `PLACEMENT TEST PASS` or `PLACEMENT TEST FAIL n`. A key in the baseline that no longer skips prints an
   info line only.

**Done when:** `tools/run_tests.sh placement layout_r34 realm_lore encounters` all pass; temporarily registering
a `WorldLanes` site over a lamp's spot makes `placement_test` fail; that temporary change is removed.

## T2. Stop the test runner leaking disk (fixes part of F6)

In `tools/run_tests.sh`:
1. After the final summary loop and before `exit "$failed"`: if `failed` is 0 and `KEEP_LOGS` is unset, run
   `rm -rf "$RUN_DIR"`. If any test failed, keep the folder (its logs are needed).
2. Before creating `RUN_DIR` (line 32), delete run folders older than one day:
   `find "${SCRATCH%/}" -maxdepth 1 -name 'umbral_tests.*' -mtime +1 -exec rm -rf {} +`.
3. Add both behaviours and `KEEP_LOGS=1` to the header comment.

**Done when:** a passing run leaves no `umbral_tests.*` folder; a run with a failing test keeps its folder and
prints its path; `KEEP_LOGS=1` keeps a passing run's folder.

## T3. Harden the save (fixes F4's two save risks)

In `autoload/travel.gd` only.
1. **Dropped saves.** Add `var _save_missed := false`. In `save_game()` (line 374), when `_busy` is true, set
   `_save_missed = true` before returning (leave the `erased` case as it is). At the end of `go()`, right after
   `_busy = false` (line 165), and at the end of `_fail_open()` after its `_busy = false`: if `_save_missed`, clear
   it and call `save_game()`.
2. **Recover from the temp file.** In `_read_save()` (line 644), change the list of paths tried to
   `[SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]`. A `.tmp` that loads and has a `[progress]` section is
   newer than the backup. Keep the existing warnings; `_main_ok` is true only when the path is `SAVE_PATH`.
3. Add to `zz/slots_test.gd` (or a new `zz/save_recover_test.gd` in the same style): write a save, move
   `savegame.cfg` to `savegame.cfg.tmp`, call `Travel.load_game()`, and check the items come back. Second case:
   set `Travel._busy = true`, call `save_game()`, set it false, run the same code path `go()` ends with, and
   check the file was written.

**Done when:** the new checks pass with `tools/run_tests.sh slots save` (and the new test if added), and
`progression`, `quest`, `story` still pass.

## T4. One place for the player's per-frame duties (fixes F5's main risk)

In `core/player/player.gd` and the component files. No behaviour change is intended.
1. Add to `Player`: `func _tick_always(delta: float) -> void` containing exactly `vitals._update_gloom(delta)`.
2. Replace each of the eight direct calls with `player._tick_always(delta)` (or `_tick_always(delta)` inside
   `player.gd`): `player.gd:407` and `:618`, `player_traversal.gd:171`, `:252`, `:347`, `:562`,
   `player_evasion.gd:222`, `player_mount.gd:39`. Find them with
   `grep -n "_update_gloom" core/player/*.gd`; after the change that grep must show only the definition in
   `player_vitals.gd` and the one call inside `_tick_always`.
3. Add a comment above `_physics_process` listing the early-return states in order and stating the rule: every
   branch that returns early calls `_tick_always` first.
4. Do not move the interact scan, fall rescue or stuck check; list in the report which early-return states skip
   them, so Luke can decide.

**Done when:** `tools/run_tests.sh` passes for `grounded`, `progression`, `hearth`, `ride_sync`, `threshold_walk`,
`nav`; Gloom still rises while hanging from a ledge (add one check to an existing player test: hold a hang for
2 s away from light and assert `gloom` increased).

## T5. Bring the docs back in line (fixes F8)

Docs only; no code.
1. `ARCHITECTURE.md`: set the "last verified" date; add rows for `core/world/realm/wonders/` (three wonders, the
   `wonders` module, `--no-wonders`), `core/world/realm/lamps/`, `core/world/realm/rift/` (crossing, threshold,
   chapel, tower stair, starlit stone), `core/world/realm/placement_log.gd` if T1 has landed, and
   `zz/bake_cache.tscn` under Persistence. Read each folder's file headers for the wording; do not invent.
2. **Do not** change the pack recipe. In the report, quote the three places that say "Linux" and note that the
   macOS preset was used on 9 and 10 November, so Luke can settle it.
3. `docs/PILLARS.md`: do not rewrite the pillars. Add one section, "Where the game stands against these
   (10 Nov)", stating plainly: the phase is no longer consolidation (see DECISIONS, 6 Nov); the Realm is
   520 x 390 m; daily bounties, item level and gear sets exist by decision. Remove the two sentences that say
   "in this phase (consolidation)".
4. Leave `docs/THE_NIGHT.md` alone and say in the report that it is untracked.

**Done when:** every path named in `ARCHITECTURE.md` exists (`grep -oE '[a-z_/]+\.gd' ARCHITECTURE.md` and test
each), and the report lists the open questions for Luke.

## T6. Give sites owners (fixes the candle class of bug from F2)

Do this after T1.
1. In `core/world/world_lanes.gd`, add `static func own(node: Node) -> void` that sets `site_owned` meta on
   `node` and on every `MultiMeshInstance3D` under it.
2. `cull_scatter` (line 402) already skips nodes with that meta. Change nothing else there.
3. Call `WorldLanes.own(host)` at the end of every builder that registers a site and places MultiMesh props
   inside it. Find them: files that call both `register_site` and `OssKit` `commit(` or `multimesh(`. The
   Threshold already does this by hand (`core/world/realm/rift/threshold.gd`, the loop after `k.commit`): replace
   that loop with the call.
4. Print one line per builder: `SITES <name> owns N scatter nodes`.

**Done when:** `tools/run_tests.sh layout_r34 flora_r34 grounded places_r34 threshold_walk` pass; the flora count
printed by `rebuild_test` (`flora:`) is unchanged from before the change (the flora itself must never be owned).

## Later, larger, and Luke's call first

These need a decision before anyone starts, so they are not specified as tasks.

- **Typed boundaries (F3):** pick the three worst files and replace dynamic calls with typed references, then
  run `tools/lint.sh --update` to lock the gain.
- **CI and a fast test tier (F6):** a GitHub Action that runs the tests that need no world on every push.
- **Strip harness code from the shipped game (F7):** move demo, bench and recorder code out of `world/main.gd`
  into `zz/`, and retire the legacy stair.
- **Rename the round-named files (F9):** mechanical, but it touches 26 files and every preload of them.
- **Split `Travel` (F4):** inventory and boss rewards out of the autoload.
- **Measure `LightGrid` (F10):** print `LightGrid.count()` at boot and decide on the spatial hash.
