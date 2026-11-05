# Architect critique (r30)

Read-only review of the whole tree on 2026-11-04 (working copy, not HEAD). Lens: module boundaries,
coupling, dependency direction, ownership, data vs code, error handling, testability, dead code,
docs. Godot was not run; every claim below is from the source, `git` (read-only) and file listings.

## Verdict

The game works, and in places it is careful: the atomic save in `autoload/travel.gd`, the
type-checked settings loader, per-system save sections, BoltPool, and the GenCache salts. But the
architecture in `ARCHITECTURE.md` and `.cursor/rules/` no longer describes the program.
"Five autoloads, signals and groups, Player = controller, new content is a scene or a Resource"
holds only in the letter. In practice there is:

- a second layer of hidden singletons: 295 `static var`s, plus 21 undeclared group names used as
  a service locator;
- a world generator (`Realm`) that boots the gameplay systems and their UI;
- about 340 stringly-typed `.call("…")` sites standing in for typed dependencies;
- two scripts over 2,200 lines (`player.gd`, `character_rig.gd`).

The root cause is structural. `world/main.tscn` is a 1.5 MB baked scene that must not be re-saved.
The Player lives inline in it, and only 2 gameplay `.tscn` files exist. So every new feature has
been built in code and attached at runtime, wherever it was convenient. The most urgent problem
is not code, though: **68 % of the shipping GDScript is untracked by git, and the repo has no
remote.**

Scale: 260 shipping `.gd` files / 78.7k lines (`core` `ui` `world` `autoload`), plus 125 `zz/`
scripts (21.7k) and 17 `tools/` scripts (3.4k). There are 5 autoloads and 22 `Events` signals.

---

## Findings

### Critical

**1. Most of the game exists only as untracked files on one disk.**
- Evidence:
  - `git ls-files` tracks 24.9k of the 78.7k shipping GDScript lines. These are untracked
    (`git status` `??`): all of `core/life/` (74 files, 21.7k lines), `core/story/`,
    `core/world/realm/` (10.8k), `core/npc/*` (except bartender), most of `core/skills/`,
    `core/enemy/` (bone_abbot, boss_kit, chanter, thornwarden, …), `ui/codex|dialogue|growth|loading_screen|quest_log|satchel|shop.gd`,
    `world/areas/ossuary/oss_deep.gd`, all of `zz/`, and `docs/critique/`.
  - 159 tracked files are modified, +11,400/−1,410 lines.
  - Last commit: 2026-11-03 07:49. `git remote` is empty, and `master` is the only branch.
- Why it matters:
  - One `rm`, one disk fault or one bad agent edit loses the Realm, the story, the village and
    every test, and nothing can restore them.
  - It also makes every review, this one included, a review of a moving target.
- Fix:
  - Luke commits now, in a few logical commits (realm, life systems, story/npc, ui, zz/tests),
    after the `.gitignore` additions in #21.
  - Add a private remote (or at least a `git bundle` to another disk) and push after each round.
  - Add a pre-pack step to `umbral-pack` that refuses to pack with untracked `*.gd` under
    `core/ ui/ world/ autoload/`.

**2. Hidden global state: 295 `static var`s act as undeclared singletons.**
- Evidence: `static var` counts per file include
  - `core/world/realm/realm_flora.gd` 25, `core/player/magic_bolt.gd` 21, `core/world/realm/realm_land.gd` 18,
    `core/vfx/vfx.gd` 12, `core/world/realm/lore/lore_kit.gd` 9.

  Many of them are session state, not caches:
  - `core/life/secrets/state.gd:18-21` (`sites`, `elites`, **`host: Node3D`**, `quiet`)
  - `core/life/secrets/reactivity.gd:25-26` (`_host: Node3D`)
  - `core/world/realm/lore/codex_store.gd:15-20` (the Journal's read-state, with its own file)
  - `core/life/progression/upgrade_db.gd:22` (`live`)
  - `core/life/village/village_shop.gd:62-63`, `core/life/village/village_state.gd:18-20` (`sandbox`, `kindled_override`)
  - `core/enemy/enemy_spawner.gd:80-90` (seal bookkeeping and hooks)
  - `core/enemy/enemy.gd:132,145` (pack alarms, attack tokens)
  - `core/world/world_lanes.gd:40-46` (the site registry)
  - `core/world/thorn_henge.gd:9-18` (mutable "constants" `C`, `FOOT`)
  - `core/world/realm/realm.gd:60-72`

  This has already cost real bugs:
  - The Deeper Night rebuilt a third of the world missing because `WorldLanes.sites` survived
    the reload (`docs/critique/F.md:31-40`).
  - The register is a long list of "leaked at exit" fixes for statics holding materials,
    streams and process materials (`docs/critique/register.md`, lines on dwarf_look, Synth,
    StaffSfx, npc_voice, Vfx).
  - The cleanup is itself reflective. `Realm._STATIC_CACHES` (`core/world/realm/realm.gd:105-125`)
    names static vars of 9 files as strings and clears them with `s.get(v)` and `s.set(v, null)`.
    Rename one of them and the leak silently returns.
- Why it matters:
  - The "five autoloads, no phone book" rule is defeated: there are dozens of process-lifetime
    stores with no owner, no reset and no lifecycle.
  - Any second build of a night in the same process (NG+, tests, a future second night) inherits
    stale state.
  - Statics that hold `Node`s dangle after a scene change.
- Fix:
  1. Classify every static.
     - (a) Immutable, resource-like caches (meshes, materials, WAVs) stay static, but go through
       ONE `core/util/res_cache.gd` with `get_or_build(key, fn)` and a single `release_all()`,
       called from `Zone._exit_tree` and from the root's `tree_exiting`. Delete
       `_STATIC_CACHES` and the per-file `release()` functions.
     - (b) Session or night state moves onto instance nodes owned by the Zone: a
       `NightState` node, or each system's own runtime node (`Secrets`, `Progression`,
       `EncounterDirector`, …), reached through a typed accessor. Reset is then automatic when
       the night is freed.
  2. Forbid `static var` of type `Node`/`Node3D`/`Callable`.
  3. Add a lint to `tools/` (grep `^static var` outside an allowlist file) that fails the test
     run when the count grows.

### High

**3. The frozen `main.tscn` forces everything into code, and the baked world is loaded only to be hidden.**
- Evidence:
  - The Player subtree (CameraRig/Pitch/SpringArm/Camera), HUD and SettingsMenu are inline in
    `world/main.tscn`: 313 nodes, 1.5 MB, and it "must never be headless-rebaked".
  - `core/world/zone.gd:6-11` hard-codes `$Player/CameraRig/Pitch/SpringArm/Camera`.
  - Outside `zz/` and `example/`, the only scenes are `world/main.tscn`,
    `core/player/magic_bolt.tscn` and `world/lab/light_lab.tscn`. Enemies, NPCs, the village,
    the Ossuary and every UI screen are built in code.
  - `Realm.retire()` (`core/world/realm/realm.gd:31-38,213-225`) hides and disables 16 baked
    layers of the same scene on every boot: Stair, Forest, ForestFloor, Ruins, Boulders, …
    These still load from `world/zones/ascension/*.res` (2.4 MB).
  - `world/main.gd:37-41` instances `dress.tscn` "if it exists", and it does not exist.
- Why it matters:
  - This is the upstream cause of the god-scripts (#4, #5) and of the runtime attach sprawl (#7).
    Nothing can be laid out, inspected or tuned in the editor.
  - Boot loads and parses geometry that it immediately throws away.
  - The "never rebake main.tscn" rule now gates the whole project's structure, not just one bake.
- Fix: in the editor, by hand, not headless:
  1. Save the Player branch as `core/player/player.tscn`, HUD and SettingsMenu as
     `ui/hud.tscn` and `ui/settings_menu.tscn`.
  2. Make a new slim `world/realm_night.tscn`: Zone script, WorldEnvironment, Moon, Grade,
     player instance and a UI root, with no baked stair layers.
  3. Set `run/main_scene` to it.
  4. Keep `main.tscn` only for `--no-realm`, or delete it (see #15).
  5. New entities (each enemy kind, NPC, UI screen) become small `.tscn` files wrapping their
     existing scripts. The scripts can keep building procedural meshes.

**4. `core/player/player.gd` is a 2,674-line god-object.**
- Evidence: 113 functions, 154 member vars, about 50 exports. Responsibilities in one file:
  - movement, slide, double jump (1217-1422) and the traversal suite: hang, climb, vault, wall
    kick, beams, roll (1479-2129), plus step-up and mantle (2388-2674);
  - orbit camera, arm and feel (600-643, 2338-2390, 2463-2615);
  - target lock (2149-2310);
  - Gloom, the shade, hollowing, respawn (698-838);
  - the interaction sensor (839-909);
  - bolt firing and aim assist (910-985);
  - charge and aim-ring VFX (1002-1100);
  - the debug autopilot (1439-1478);
  - save restore through `Travel` (189-200, 516, 771-772).
- Why it matters:
  - Every agent round edits this one file (the register shows A, B and C all in `player.gd`),
    so merge collisions and regressions concentrate here.
  - Nothing in it can be tested without a full Player.
  - The skill doc already disagrees with it (see #20).
- Fix: split into child components that Player creates or holds as typed refs, and move them
  leaf-first, one per PR:
  1. `PlayerAutopilot` → `core/debug/`
  2. `Interactor` (Area3D sensor + `_try_interact`)
  3. `PlayerFx` (slide, charge, aim ring)
  4. `GloomMeter` (Gloom, shade, hollow, respawn; emits Events)
  5. `TargetLock`
  6. `PlayerCamera` (Node3D on CameraRig: arm, feel, recentre, teleport trail)
  7. `Traversal`: a RefCounted state machine with Hang/Climb/Vault/Roll/Mantle/Slide states,
     each `enter/tick/exit`, replacing the `_mantle_t >= 0`, `_step_t > 0` and `_sliding`
     flag cascade in `_physics_process` (310-497).

  Player keeps input routing and the physics orchestration. Target: under 600 lines. Save
  restore moves out of `_ready`: Zone or Travel places the player after instancing.

**5. `CharacterRig` is the wanderer's skin and also the enemy rig base: 2,219 lines, `@tool`, and coupled to the Realm.**
- Evidence:
  - `core/enemy/hunch_rig.gd` and `core/enemy/quad_rig.gd` extend `CharacterRig` and add
    `telegraph/howl/strike/flinch/stagger/collapse`, which the base does not declare. So
    `Enemy` must call them by string: `core/enemy/enemy.gd:299,353,1017,1039,1158,1310,1433`
    (`_rig.call("flinch", …)`).
  - The skin queries the world generator for footsteps: `core/player/character_rig.gd:1353-1369`
    (`RealmLayout.biome_at`, `load("res://core/world/realm/realm_land.gd")…call("in_water")`).
  - The whole 2,219-line file is `@tool` (line 1), so the editor executes it.
  - The rig walks up the tree with `get_parent().has_method("hollow")` (1449).
- Why it matters:
  - Enemies inherit the wanderer's cloth, staff trail, footsteps and legacy pose code.
  - The rig API is unenforced, so a typo in a verb is a silent no-op.
  - The skin depends on the terrain module, which is the wrong direction.
- Fix:
  - Introduce `class_name Rig extends Node3D` with the shared virtual verbs: `animate`, `cast`,
    `equip`, `telegraph`, `strike`, `howl`, `flinch`, `stagger`, `collapse`.
  - `WandererRig` (today's CharacterRig), `HunchRig` and `QuadRig` extend it.
  - `Enemy._rig: Rig` calls the verbs directly.
  - Footstep surface becomes an input: Player passes a `surface: StringName` from its own floor
    ray, or a `SurfaceProbe` Callable set by the Zone.
  - Limit `@tool` to a small `rig_preview.gd`, or drop it.

**6. Stringly-typed late binding replaces the type system.**
- Evidence:
  - Shipping code has about 340 `.call("…")` sites and 121 `has_method`. Top files: oss_deep 39,
    growth 28, encounters/director 25, villager 23, quest_world 15, loading_screen 14, village 14.
  - About 169 of 260 scripts deliberately have no `class_name` and are reached with
    `(load(path) as GDScript).call(...)`, for example `core/world/zone.gd:25`,
    `core/world/tavern.gd:29,40-41`, `core/life/village/village.gd:172,185`,
    `core/life/secrets/director.gd:27-28`, `autoload/travel.gd:365`.
  - Private methods are called across files: `world/areas/ossuary/oss_deep.gd:209-330`
    (`area.call("_wall", …)`, `area.call("_pier", …)`, `area.call("_bone_heap", …)`).
  - Reflection checks for a method that exists: `world/main.gd:47` (`"seed_realm" in
    get_script_method_list()`, while `EnemySpawner.seed_realm` is at enemy_spawner.gd:71).
  - Reflection reaches into other files' private caches: `core/vfx/sfx.gd:146-148`.
  - Tests poke privates: `zz/progression_test.gd:47,59,317` (`Travel.set("_busy", true)`).
  - It does not even buy resilience. One parse error in `character_rig.gd` broke every scene,
    and "all headless tests still PASS, so they do not catch it" (`docs/critique/register.md:28`).
- Why it matters:
  - Renames and signature changes fail at runtime, or silently.
  - The editor cannot find references.
  - The compiler's checking, the reason to use typed GDScript, is switched off at exactly the
    seams between features.
- Fix:
  - One rule: every script that another feature references has a `class_name` and is called
    through typed references. "No class_name" is only for scripts used by their own folder.
  - Make cross-file "privates" public, without the underscore.
  - Replace `ResourceLoader.exists(...)` plus `.call` guards with direct calls.
  - Add the CI gate from #11, which fails on any `SCRIPT ERROR` or `Parse Error` in the log.
    That is the real protection against cascades.
  - Track the `.call("` count in the lint and ratchet it down.

**7. Dependency direction is inverted: the world builder hosts gameplay, gameplay builds UI, and UI is spread over 8+ owners.**
- Evidence:
  - The world generator starts the gameplay systems: `core/world/realm/realm.gd:21-29` lists
    progression, village, life, secrets and encounters as Realm *modules*.
  - A geometry builder creates the story director: `core/world/tavern.gd:481-483`.
  - The story director (domain) creates the dialogue, quest log and shop UI and parents them to
    `/root`: `core/story/story.gd:16-19,36-42,284`.
  - Domain preloads UI: `core/life/progression/progression.gd:8-9`.
  - The encounters director builds its own HUD in `core/` and drives it by string:
    `core/life/encounters/encounter_hud.gd`, `core/life/encounters/director.gd:101-103,290-335,473,540`.
  - A world object opens a UI screen by node name: `core/world/brazier.gd:61-63`
    (`current_scene.get_node_or_null("Satchel").call("open_menu", true)`).
  - Base skills depend on the progression system: `core/skills/afflict.gd:12`, `skill_tether.gd:11`,
    `skill_well.gd:8`, `skill_familiar.gd:9` preload `core/life/progression/upgrade_db.gd`.
  - Player, enemy and vfx depend on a realm module for a generic disk cache (`gen_cache.gd`
    preloaded by `wanderer_*`, `enemy_body`, `kin_look`, `synth`, `staff_sfx`).
  - UI is created by `world/main.tscn` (HUD, Settings), `world/main.gd:54` (Satchel),
    `progression.gd` (Kindling, ComboReadout), `story.gd` (Dialogue, QuestLog, Shop),
    `realm_lore.gd:28` (Codex), `encounters/director.gd`, `boss_arena.gd:211`,
    `secrets/panel.gd`, `hud.gd:151,157` (Hotbar, objective line) and `zone.gd:25` (loading).
    Canvas layers are magic numbers that collide: dialogue and satchel both 60; shop, codex and
    growth all 61.
- Why it matters:
  - You cannot run a system without the world generator, or the world without the systems:
    `--realm-modules` is a workaround.
  - Domain code cannot be tested without UI.
  - Adding a screen means finding which of 8 owners to edit.
  - Nodes parented to `/root` outlive the scene unless someone remembers to free them
    (`story.gd:79-85`).
- Fix: adopt and document a layer rule. Lower layers never reference higher ones:

  `util ← data (items, upgrades, quests) ← domain (player, enemy, skills, story, progression, …) ← world builders ← ui`

  1. Add a `GameSystems` node on the Zone, not in the Realm, that instantiates the domain systems.
     `Realm.build` only builds terrain, flora and lore.
  2. Add one `ui/game_ui.tscn` (Control/CanvasLayer root under the Zone) that instantiates every
     screen, with layer constants in `ui/ui_layers.gd`.
  3. Domain-to-UI traffic goes through `Events`. Add `banner(title, sub, color)`,
     `attune_requested`, `dialogue_requested(conv, npc)` and `tide_changed(level)`.
  4. UI-to-domain stays as direct typed calls.
  5. Move `gen_cache.gd` to `core/util/`, and move skill rank parameters into data (#9) so
     `core/skills` stops importing `core/life`.

**8. The `Travel` autoload is a GameManager in disguise, and persistence is split across four owners.**
- Evidence: `autoload/travel.gd` (452 lines) does scene transition and fade, and also:
  - the save file: format, migration, atomic write (380-446);
  - the inventory: `give/count/items` (212-228);
  - economy rules: ash per kill, boss trophies, a Thornwarden special case (53-63);
  - kindle memory, checkpoints, hollow count;
  - story and systems blobs;
  - erasing the Journal via `load(...codex_store.gd).call("reset")` (365).

  `core/player/player.gd:189-200,516,771` reads and writes it directly. Persistence lives in
  `Travel` (savegame.cfg), `CodexStore` statics (codex.cfg), `Settings` (settings.cfg) and
  `UpgradeDB.live` (derived static). Nothing takes a save path, so tests back up and restore
  Luke's real save byte by byte (`zz/progression_test.gd:51-80`), and safe runs need an
  isolated HOME.
- Why it matters:
  - Game rules sit inside a transport service.
  - Two save files can disagree: a crash between the codex and the progress writes.
  - Tests are dangerous by default.
- Fix:
  - Split it. `Travel` keeps only go/fade/pending spawn.
  - A new `SaveGame` service owns one file with sections (progress, story, systems, codex),
    the atomic write, migration, and a `save_dir` that `--save-dir=` overrides. CodexStore
    becomes a section.
  - Economy (ash per kill, trophies) moves to the Satchel/Progression domain, listening to
    `enemy_killed` and `boss_slain`.
  - That makes six autoloads. Update the rule: a persistence service is a legitimate autoload;
    hiding it in Travel is not.

**9. Content and tuning are hard-coded GDScript dictionaries, and external code mutates Player exports.**
- Evidence:
  - `core/items/item_db.gd` `DEFS`, `core/life/progression/upgrade_db.gd` (425 lines: EMBERS,
    SPELLS, OATHS, CHARMS…), `core/story/quest_db.gd`, `core/story/dialogue_db.gd` (323),
    `core/life/village/village_talk_db.gd` (288) and `core/life/encounters/variants.gd` (389)
    are all untyped `{"key": …}` dictionaries read with `.get("x", default)`.
  - Spell ranks are implemented by swapping the skill script for a subclass
    (`core/life/progression/kindling.gd:20-30`) that branches on `DB.get_mod("nova")` at cast
    time (`core/life/progression/skills/nova.gd:19-25`).
  - `kindling.gd:120-140` snapshots Player's `@export` tuning by reflection (`p.get(k)`) and
    writes new values over it.
  - All player-facing text is in code. There are 0 `tr()` calls.
- Why it matters:
  - A typo in a key is a silent default.
  - Designers cannot tune anything without editing scripts.
  - Two systems writing the same Player fields (Kindling plus anything else later) will fight.
  - The rule "new content is a scene or a Resource" is only honoured by `EquipmentPiece`.
- Fix:
  - Typed Resources (`ItemDef`, `UpgradeDef`, `SpellRankDef`, `QuestDef`) as `.tres` under
    `data/`, or at minimum typed inner classes with a validator run by a test.
  - A `PlayerStats` Resource with base values and a modifier stack (`add_mod(source, stat, op, v)`).
    Player reads computed stats, and no one writes Player exports.
  - Skills read their rank parameters from data instead of subclassing per rank.
  - Wrap text in `tr()` when convenient. Not urgent, but cheap now and expensive later.

**10. The procedural asset pipeline writes into `res://` at runtime, and the export depends on it.**
- Evidence:
  - `core/world/realm/gen_cache.gd:4-12`: dev runs write `res://art/realm_cache/`, and "Run the
    game once from the editor before exporting so the cache is complete".
  - `art/realm_cache` is 78 MB in 1,434 files, untracked. `export_presets.cfg:10` ships it via
    `include_filter`.
  - Runtime-built materials and meshes live in statics instead of `.tres`
    (`core/player/magic_bolt.gd:55-94`, 21 statics; `vfx.gd`; `spell_fx.gd`), which feeds the
    leak-at-exit work.
- Why it matters:
  - Export content depends on which code paths happened to run in the last dev session.
  - Running the game mutates the project folder.
  - Stale entries ship when the salt manifest misses one.
- Fix:
  - Add `tools/bake_realm_cache.gd` as an explicit step in `umbral-pack`, run before export. It
    walks every generator key, writes the cache and fails if any salt is stale.
  - Runtime only ever writes `user://`.
  - Static materials that are not parameterised become `.tres` files and `preload` consts, so
    lifetime is refcounted.

**11. Tests exist but are not a test suite.**
- Evidence:
  - `zz/` has 125 scripts and 21.7k lines, all untracked, mixing tests (23 `*_test`), probes,
    shot generators, studios and perf tours.
  - No runner is committed: `run_suite.sh` lives in a scratchpad (`docs/critique/F.md:22`).
  - Every test re-implements `ok()` and `fails`.
  - Parse errors do not fail tests (register.md:28).
  - Test-only switches live in production: `core/life/secrets/state.gd:21` (`quiet`),
    `core/life/village/village_state.gd:18-20` (`sandbox`, `kindled_override`), Travel `_busy`
    pokes.
  - Tests touch the real save unless HOME is isolated (#8).
- Why it matters:
  - Regressions like the parse-error cascade reach the build.
  - Every agent runs a different subset, by hand.
- Fix:
  - Split `zz/tests/` (pass/fail, headless) from `zz/tools/` (shots, probes, studios).
  - Commit `tools/run_tests.sh`. For each `zz/tests/*_test.tscn` it runs with
    `HOME=$(mktemp -d)` and a timeout, and fails on a nonzero exit or any
    `SCRIPT ERROR|Parse Error|Failed to load script` in the log.
  - Add a shared `zz/lib/check.gd` (ok, eq, near, summary/quit).
  - Replace production test flags with constructor or config injection (`Secrets.new(quiet)`)
    or the `--save-dir` seam.

### Medium

**12. `core/enemy/enemy.gd` (1,433 lines) and deep inheritance contradict "compose, don't inherit".**
- Evidence:
  - The hierarchy runs `Enemy → Husk → Ossuant → BoneAbbot`, `Enemy → Husk → AscendedWarden`,
    `Enemy → Leaper → Thornwarden`, `Enemy → Spitter → Chanter`, `Enemy → Crawler → Mite|Burrower`.
  - The base holds the health bar and pips (476-612), the attack-token pool (1200-1236, static
    `_tokens`), pack calls with a static `_alarms`, flee, ward logic and the final-blow hitstop.
  - The hitstop sets global `Engine.time_scale = 0.3` from an enemy (1344).
- Fix:
  - Make `EnemyHealthBar` a child node, and give `AttackTokens` and pack alarms to a per-zone
    `CombatDirector` node instead of statics.
  - Move hitstop to a Zone-owned `CombatFeel`.
  - Make kinds an `EnemyKind` Resource (stats, rig, voice) plus a small behaviour script per
    special, so bosses do not need four levels of `super`.

**13. Static callable hooks monkey-patch the spawner.**
- Evidence: `core/enemy/enemy_spawner.gd:84-90` (`kind_hook`, `dress_hook`, `hold_for_rest`),
  set by `core/life/encounters/director.gd:119-121` and reset at 139.
- Fix: make them instance properties of the spawner (one per night), or a
  `pawn_spawning(pawn, slot)` signal the director connects to. No static Callables.

**14. Thirty-one ad-hoc command-line flags parsed in 18 files, and debug tooling inside the shipping night script.**
- Evidence:
  - `OS.get_cmdline_user_args()` is parsed in 18 shipping files, with flags like `--no-realm`,
    `--realm-modules=`, `--no-r28-secrets`, `--flora-hide=`, `--scape-off`, `--sfx-trace`,
    `--no-loading`, …
  - `world/main.gd` carries the benchmark, walk recorder, perf baseline, demo and shade test
    (lines 2-30, 66-90 and 150-347 of 347).
- Fix:
  - `core/debug/launch_args.gd`: parse once, with typed accessors (`LaunchArgs.flag(&"no-realm")`,
    `LaunchArgs.value(&"save-dir")`) and a documented list.
  - Move bench, walk-rec, perf-baseline and demo into a `DebugTools` node that the Zone adds
    only in debug builds or under a flag.
  - Delete round-named flags (`--no-r28-secrets`).

**15. A legacy world path is still kept alive.**
- Evidence:
  - `--no-realm` (`core/world/realm/realm.gd:44-48`), `WorldLanes.legacy`
    (`world_lanes.gd:44,438,468`), `DefaultLoadout.use_legacy` (`default_loadout.gd:15-54`),
    `CharacterRig._legacy_pose` (616), `HunchRig._legacy_pose`, `EnemySpawner.seed_stair`, and
    20 `Realm.enabled()` branches.
  - The legacy tests that keep it alive are henge_walk, summit_probe, lanewalk and fit.
  - `tools/bake_main.gd:4` still says "Re-run after layout changes: godot --headless … -s
    tools/bake_main.gd", which directly contradicts the binding never-headless-rebake rule.
- Fix:
  - Decide that the Realm is the game. Delete the legacy branches and their tests.
  - Remove the retired nodes from the scene, by hand in the editor, as part of #3.
  - Delete `bake_main.gd`, or make its first line `push_error` and quit unless `--i-know` is passed.

**16. The loading screen owns gameplay warm-up and is polled by path.**
- Evidence:
  - `ui/loading_screen.gd:300-370` hand-lists every FX, skill, enemy attack and staff core,
    through `ResourceLoader.exists` and `load().call`. An effect missing from the list hitches
    on first use, silently.
  - `core/story/story.gd:69` polls `get_node_or_null("Main/LoadingScreen")` every 0.1 s, coupling
    the story to the root scene's name.
- Fix:
  - Emit `Events.night_revealed` when the cover lifts, and have Story await that signal.
  - Give each FX script a `static func warm(host: Node3D)`, collected in one `core/vfx/warm_list.gd`
    that the loading screen iterates.
  - Measure whether Godot 4.7's pipeline precompilation makes part of the tour unnecessary.

**17. Duplicated subsystems.**
- Evidence:
  - 9 separate PCM→`AudioStreamWAV` encoders, each with its own cache and release:
    `core/vfx/synth.gd:79`, `staff_sfx.gd:91`, `core/life/wildlife/scape_synth.gd:126`,
    `life_synth.gd:66`, `core/life/village/village_audio.gd:90`, `core/npc/npc_voice.gd:231`,
    `core/npc/keg_scenes.gd:460`, `core/life/secrets/kit.gd:606,657`.
  - 5 procedural rigs: CharacterRig, hunch, quad, `dwarf_rig`, and `villager_rig` (which
    extends dwarf_rig by path).
  - 5 or more mesh builders: procmesh, creature_mesh, dwarf_mesh, wanderer_gen, enemy_body.
  - 4 HUD-ish layers: ui/hud, encounter_hud, the boss bar layer, the secrets panel.
  - The Cinzel font is loaded in 5 places (`hit_text.gd:6`, `objective_line.gd:26`,
    `encounter_hud.gd:11`, `secrets/panel.gd:34`, ui) with no `Theme`.
- Fix:
  - `core/audio/synth_core.gd`: oscillators, envelopes, noise, `to_wav(pcm, loop)` and a keyed
    cache under the #2 `res_cache`. The 8 files become recipe tables.
  - `ui/theme.tres`, used by every screen.
  - Fold `CreatureMesh` and `DwarfMesh` onto one tube/blob builder in `core/util/`.

**18. `Sfx`, `Vfx`, `SpellFx` and `Synth` are static managers that parent pooled nodes to `current_scene`.**
- Evidence:
  - `core/vfx/vfx.gd:22-25` (`host()` returns `current_scene`).
  - `core/vfx/sfx.gd:17-30`: a static voice pool, with code to drop "freed or foreign voices".
  - The rule says "No AudioManager", but this is one, without a lifecycle.
- Fix:
  - Make them nodes owned by the Zone, like `BoltPool`: `FxPool` and `SfxPool`, reached through
    the Zone or a group constant.
  - Or make one `Fx` autoload with explicit `_exit_tree` cleanup.
  - Either way, update the rule to match.

**19. The event bus and groups are used unevenly.**
- Evidence:
  - `Events` has 22 signals for 78k lines. `skill_failed` (`autoload/events.gd:18`) is emitted
    (`core/skills/skill_book.gd:183`) and never connected.
  - `toast` is emitted from 39 places and has become a UI API.
  - 21 group names are raw strings that are not in `Groups`: `story` ×9, `bolt_pool` ×7,
    `boss_arena` ×5, `growth`, `codex`, `quest_log`, `progression`, `keep`, `lantern_ward`, …
    They are used as singleton lookup, for example `ui/growth.gd:503-504`
    (`get_first_node_in_group("progression")`).
  - `core/util/groups.gd` says a typo should "fail at parse time".
- Fix:
  - Add every group to `Groups` and to `project.godot [global_group]`, or replace singleton
    lookups with typed refs from the Zone (`zone.systems.progression`).
  - Remove `skill_failed` or connect it.
  - Make domain events that UI shows typed (#7) instead of preformatted toast strings.

**20. The architecture docs and skills are stale enough to mislead agents.**
- Evidence, in `ARCHITECTURE.md` ("last verified 2026-11-02"):
  - Nothing about the Realm, `core/life` (21.7k lines), story, NPCs, skills, Satchel/items,
    persistence, area streaming or GenCache.
  - It describes the `tools/bake_dress.gd → dress.tscn` path, and that file does not exist.
  - It says "No AA", while `autoload/settings.gd:22,42` offers six AA modes.

  In the rules and skills:
  - `.cursor/rules/godot-architecture.mdc:18` still names `world/vale.gd`.
  - `umbral-constraints.mdc:9,15` names `vale.tscn` and `AGENT_HANDOVER.md`, which is now under
    `docs/archive/`.
  - `umbral-player` SKILL says "No step-up — use ramps", but `player.gd:2392` has
    `_try_step_up` with STEP_MAX 0.45.
  - It says "Gloom 3.6/s, 6.3/s", but `player.gd:40-41` has 2.0 and 3.5.
  - It says "cooldown 0.42", but `core/skills/skill_bolt.gd:11` has 0.28.
  - It says `robe_cloth.gdshader`, which does not exist; only its orphan `.uid` does, and the
    shader is `robe_wave`.

  Elsewhere:
  - `README.md` layout lists `core/enemy/ shade.gd` and points to a root `AGENT_HANDOVER.md`.
  - `autoload/settings.gd:3` says world/main.gd applies settings, but `core/world/zone.gd:29` does.
  - `docs/` holds 13 plan docs: HANDOFF (561 lines), CURSOR_FIX_PLAN (464), ZONE_PLAN (406), …
- Fix:
  - Rewrite `ARCHITECTURE.md` as a module map: one paragraph per folder (owner, entry point,
    state, signals in and out), the layer rule from #7, the persistence map from #8 and a
    lifecycle diagram (boot → Realm → systems → UI → teardown).
  - Correct the four skill facts.
  - Move finished plans to `docs/archive/`.
  - Add "last verified" to every skill and rule, and make the critique round re-verify them.

### Low

**21. Repo hygiene.**
- Evidence:
  - `shots/` is 8.7 GB and 2,107 files inside the project, neither ignored nor tracked.
  - There are 4 `*.log` files at the root (`base.log`, `noshadow.log`, `nossao.log`, `nossr.log`),
    and `tools/__pycache__` is tracked (4 `.pyc`).
  - 13 orphan `.uid` files whose source is gone: `core/enemy/shade_beehave.gd.uid`,
    `core/player/robe_cloth.gdshader.uid`, `core/util/sculpt.gd.uid`,
    `core/world/figure_{goblin,king,watcher}.gd.uid`, `core/world/grotesque.gd.uid`,
    `tools/_bone_math_test.gd.uid`, `tools/_priest_pose.gd.uid`, `tools/figure_studio.gd.uid`,
    `world/velvet.gdshader.uid`, `world/wrinkle.gdshader.uid` and
    `addons/phantom_camera/panel/editor.gd.uid`.
  - `dialogue/wastes_intro.dialogue.import` has no source file.
  - Five addons (beehave, dialogue_manager, spatial_gardener, phantom_camera, proton_scatter;
    1,057 tracked files) are all `.gdignore`d and referenced nowhere. `example/` adds 60 more.
  - `assets/provenance.csv` is imported by Godot as a translation table and generates 4
    `.translation` files.
  - The export `exclude_filter` hand-lists individual files (`export_presets.cfg:11`).
- Fix:
  - `.gitignore`: `shots/`, `*.log`, `__pycache__/`, `art/realm_cache/` (unless it moves to
    LFS, see #10).
  - Delete the orphans, the addons and `example/`; they stay in history.
  - Set `assets/provenance.csv.import` to `importer="keep"`, or add `assets/.gdignore`.
  - Move rejected models out of `art/models/` so the filter needs no per-file list.

**22. Every setting is written three times.**
- Evidence: in `autoload/settings.gd`, the fields (30-57), `load_settings` (80-120) and
  `save_settings` (139-170) each list every setting. Buses are created in code (179-186) and
  there is no `default_bus_layout.tres`.
- Fix:
  - A schema table, `const FIELDS := [[&"graphics", &"fog_enabled", &"fog_enabled", null, null], …]`,
    with a generic load and save loop.
  - Commit a bus layout resource.

**23. Canvas layer magic numbers.**
- Evidence: 4, 5, 10, 12, 40, 59, 60 (×2), 61 (×3), 62, 70, 80 and 120, spread over 12 files
  (`ui/*.gd`, `boss_arena.gd:212`, `encounter_hud.gd:58,142`, `secrets/panel.gd:31`, `travel.gd:66`).
- Fix: `ui/ui_layers.gd` with named constants (HUD, COMBAT_HUD, MENUS, DIALOGUE, PAUSE, FADE, LOADING).

**24. LightGrid is an untyped linear scan, called per enemy per physics frame.**
- Evidence: `autoload/light_grid.gd` stores `Array` of Dictionary, and dead nodes stay until
  `clear()`. `repel` is called by every enemy every tick (comment at line 36).
- Fix: a typed inner class, auto-unregister on `tree_exiting`, and the 4 m spatial hash the
  header already promises once the count passes 64. With the Realm's braziers and wards, check
  the count.

**25. Debug bindings ship in release.**
- Evidence: `autoload/input_setup.gd` binds F8 benchmark, F9 demo and F4 render scale
  unconditionally. `release_mouse` is defined with no key "to silence errors" (lines 34-38).
- Fix: bind debug actions only when `OS.is_debug_build()`. Remove `release_mouse` and its
  readers, or give it a key.

**26. Untyped config dictionaries at API seams.**
- Evidence: 177 `: Variant` declarations in shipping code. Examples: `Player.fire_bolt(cfg: Dictionary)`
  (`player.gd:910`), `Vfx.burst(at, col, {"trail": 0.2, "additive": false})`, spawner slots,
  routine steps in `villager.gd:3-8`.
- Fix: small typed config classes (`BurstOpts`, `BoltCfg`) or Resources for the hot APIs.

---

## Top 10 to do first

1. **Commit the working tree and add a remote (#1).** 68 % of the shipping code is untracked and
   there is no remote. Add the `.gitignore` lines from #21 first.
2. **Commit a test runner that fails on script errors (#11, #6):** `tools/run_tests.sh` with an
   isolated HOME per test, a timeout, a nonzero exit and a `SCRIPT ERROR|Parse Error` scan.
   Make it the gate before every pack.
3. **Add a `--save-dir` seam and stop tests touching the real save (#8).** Remove the
   `Travel.set("_busy")` pokes.
4. **Do the static-state audit (#2).** Move the session state in `secrets/state`, `codex_store`,
   `UpgradeDB.live`, `village_shop`, `enemy_spawner` hooks, `WorldLanes` and `thorn_henge` onto
   Zone-owned nodes, and put the caches behind one `res_cache` with one release. Delete
   `Realm._STATIC_CACHES`.
5. **Extract `player.tscn`, `hud.tscn`, `settings_menu.tscn` and a slim realm night scene in the
   editor (#3).** This unfreezes the project's structure and drops the retired stair layers
   from boot.
6. **Add the `Rig` base API (#5).** Delete the `_rig.call("…")` sites in `enemy.gd` and move the
   footstep surface query out of the skin.
7. **Split `player.gd` leaf-first (#4):** autopilot, interactor, FX, gloom, lock, camera,
   traversal state machine.
8. **Invert the bootstrap (#7):** a `GameSystems` node on the Zone creates the life, story and
   progression systems, `Realm` only builds the world, and one `ui/game_ui.tscn` owns every
   screen through `ui_layers.gd`. Domain talks to UI via `Events`.
9. **Split `Travel` into `Travel` plus `SaveGame` (#8), with the codex as a section.** Move the
   economy rules to the domain, then update the "five autoloads" rule.
10. **Rewrite `ARCHITECTURE.md` and fix the stale rules and skills (#20).** Delete the legacy
    `--no-realm` path and neuter `tools/bake_main.gd` (#15) in the same pass, so the docs, the
    rules and the code agree again.
