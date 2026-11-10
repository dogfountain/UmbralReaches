# Code review, 10 November 2026

A critique of the shipping code (`autoload/`, `core/`, `ui/`, `world/`: 465 scripts, about 142,000 lines) and the
test tooling (`zz/`, `tools/`). Part 1 is the critique. Part 2 lists the work still open.

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

26 shipping files are named after a development round (`realm_pois_doubled_realm.gd`, `site_east_marches.gd`,
`quest_chains_west_marches.gd`), and 907 comments carry a round tag ("r36:"). A reader has to know the project's
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

# Part 2. Open work

Tasks T1 to T6 and the fall-rescue fix, the tests-on-push Action, the harness move out of `world/main.gd`, the
LightGrid grid, the first typing pass and the unused-asset sweep are done and merged (10 Nov); their handoffs are
removed. Still open:

- **Dead code, sweeps 2 and 3:** the legacy stair (code and `world/main.tscn`), unreferenced scripts and scenes,
  then unused functions in live scripts.
- **Split `Travel` (F4):** boss rewards and relic rules out of the autoload.
- **Rename the round-named files (F9).**
- **Typing (F3), second pass:** the files after the first three; `ui/unit_frames.gd` stays partly dynamic for its test fakes.
