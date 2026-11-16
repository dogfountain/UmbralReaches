# Architecture — last verified 2026-11-10

Godot **4.7.2** Forward+ / Jolt, typed GDScript. One playable night: the **Realm** (the redesigned
Stair of Ascension zone), booted from `world/main.tscn` + `world/main.gd`. This file is a map of
the code as it is, not a wish list; `docs/THE_NIGHT.md` is the current critique.

## Boot and teardown

```
ui/title_boot.tscn (the project's main scene): ui/title_screen.gd -- Continue / New Game / Settings / Quit,
                         picks a save slot, then loads world/main.tscn. Skipped headless and under any
                         harness flag (--bench, --perf-baseline, --no-title, ...).
world/main.tscn (baked: Zone, Player, HUD, SettingsMenu, WorldEnvironment, Moon, Grade)
  Zone._ready            core/world/zone.gd   opens ui/loading_screen.gd, wires Settings + Events
  main.gd _ready         world/main.gd        Gothic, Atmosphere, Glimmers, EnemySpawner.seed_realm,
                                              AreaStreamer (Ossuary), PerfWatch, LavaWorks, Satchel,
                                              Ambience, then finish_zone_setup() (BoltPool, lights, kindles)
  Glimmers._ready        core/world/glimmers.gd  awaits Realm.build(root)
  Realm.build            core/world/realm/realm.gd  retire baked stair layers -> land -> rift -> bosses
                         -> Tavern (adds Story) -> lore -> TerrainStamp -> flora -> SummitDress
                         -> assets -> progression -> village -> life -> secrets -> encounters -> cull
  loading screen         ui/loading_screen.gd  waits for the build + shader warm-up, then lifts
teardown (quit, or the Deeper Night rebuilding in-process)
  main.gd _exit_tree     SessionState.reset_night()  (core/world/session_state.gd)
```

`-- --realm-modules=land,flora` builds only those modules.

## Folders (owner, entry point, state)

| Folder | What lives there |
| --- | --- |
| `autoload/` | Five services: `Events` (signals only), `Settings` (settings.cfg), `Travel` (scene change + fade, savegame.cfg, inventory, kindles, checkpoints, story/systems blobs), `LightGrid` (safe-light registry), `InputSetup` (InputMap). |
| `core/player/` | `Player` (`player.gd`: state, signals, exports, the tick order and thin forwarders; the logic lives in child components: `PlayerLocomotion`, `PlayerTraversal`, `PlayerEvasion`, `PlayerCamera`, `PlayerTargeting`, `PlayerVitals` (Gloom, Wounds, hollowing), `PlayerCasting`, `PlayerInteraction`, `PlayerMount`, and `PlayerAutopilot` (built only for demos/tests)), `CharacterRig` (skin: skeleton, sockets, stride, cloth, staff; also the base of the enemy rigs), wanderer mesh/texture generators, `MagicBolt` + `BoltPool` (Zone-owned). |
| `core/skills/` | `SkillBook` + `Skill` subclasses (bolt, lance, nova, step, tether, ward, well, familiar), `Afflict` (burn/chill manager), `Combo` feed, `Aim`. |
| `core/items/` | `ItemDB` (all carryables) and `EquipmentPiece` data (staff, lantern, gauntlets, boots). |
| `core/enemy/` | `Enemy` base + kinds (husk, leaper, spitter, crawler, …) and bosses (Thornwarden, Bone Abbot, Ascended Warden), rigs (`hunch_rig`, `quad_rig`), `EnemyBody`, `EnemySpawner` (camps, seal guards; the Far Reaches' camps in `realm_camps_reaches.gd`; camps are set again on the settled ground once the Realm is done), `AttackKit`. |
| `core/world/` | `Zone` shell, interactables (Brazier, WardSeal, MirrorGate, Reliquary, ChainLift), `BossArena`, `Tavern`, `ThornHenge`, `Atmosphere`, `Ambience`, `AreaStreamer` + `Area`, `TerrainStamp`, `WorldLanes` (site registry), `SessionState` (night-state registry). |
| `core/world/mount/` | r36 horses: `HorseDB` (breeds), `Horse` (the mount; the wanderer sits it), `Stables` (hitching posts, the [H] call). Built by `EnemySpawner` with the watch. |
| `core/world/watch/` | r36 the Kindled Watch: `WatchPosts` (where four posts stand, one `build` call) and `Watch` (three watchmen on villager rigs, assaults by the dark, holds pay grave ash and gear). Asleep beyond 70 m. |
| `core/world/roam/` | r36 `RoamEvents`: processions, incursions, rift tears and kneeling pilgrims near the wanderer, one at a time, each with a map pin. |
| `core/world/night/` | r36 `ReachState`: the act (1 to 5), pressure, bells rung or carried, quiet countries, the three factions (`FACTIONS` is the single source for their zones, regions and bells). |
| `core/world/realm/` | The procedural world: `Realm` (module runner), `realm_land/rift/bosses/lore/flora/assets`, `RealmLayout`, `RockKit`, `TreeGen`, `GenCache` (disk cache; `flora_cache` keeps the flora's whole placement in it, keyed on the registered keep-outs and a sparse ground re-sample, so a warm launch skips the scatter; `flora_emit` makes the nodes, `flora_tables` holds the rates), `lore/` (landmarks, inscriptions, `CodexStore`), `realm_wayfinding` (r30 lanterns, edges, watchtower), `realm_pois` + `loot_chest` (r31 places: Drowned Belfry, Charcoal Hollow, Almonry, Watchers' Spire; chests, guardian sites, Tether anchors, updrafts, glide perches). |
| `core/world/realm/wonders/` | The "wonders" Realm module (`realm_wonders.gd`, run after the lore and before the terrain stamp): landmarks seen from far off. `sky_chain.gd` is the Order's chain on the Crowns' foot, wound round a capstan; `upward_falls.gd` is the Sorrow's river climbing seven steps above Weirford; `star_crater.gd` is a star's crater of fused glass in the White Pans. Each file has `static func build(root)`. `-- --no-wonders` turns them all off. |
| `core/world/realm/rift/` | The Starwater Rift's built pieces (`RealmRift`; the chasm by Hearthward, starwater to the summit's foot) and the Ashen Rift's (the lava, out in the far north-east: `scorch.gd` the gash, flows and burn, `ash_lava.gd` the lava sheet, `plume.gd` the smoke column; dressed by `realm/rift_rim.gd`). `crossing.gd` is the ruined pilgrims' viaduct from the south rim to the summit ward. `threshold.gd` is the terraced pilgrims' threshold down to the starwater, with the two lantern pillars called the Watchers. `chapel.gd` is the small Pilgrims' Chapel at the foot of the west wall, where the starfall pours. `tower_stair.gd` is the Pilgrims' Stair down the crossing's third tower to the chapel. `starlit_stone.gd` is the rift's paler stone, with a little starlight in it. `features.gd` is the rift's set dressing: basalt organ pipes, cooled islands, ash fields and fissures. |
| `core/world/realm/lamps/` | The Realm's lamps, placed by `lamp_places.gd` after the settlements are dressed. A kindled lamp (`lamp.gd`) is a light the wanderer lights with the staff gesture (E); it burns for the rest of the night and the save remembers it. A kept light (`lamps_kept.gd`) is a light others keep, already lit: a pilgrim's camp on the Downs, a ferryman's lamp on the Sorrow, a hunter's lantern in the Thornwood, a window lit in a ruin. Neither is gameplay light. `-- --no-lamps` turns them off. |
| `core/life/wildlife/boss_themes.gd` | r35 composed (synthesised) themes for the three bosses and the ending bell, rendered on a worker thread and cached through `GenCache`. |
| `core/life/` | Living-world systems, each started as a Realm module: `progression/` (Kindling: ash -> upgrades, `UpgradeDB`), `village/`, `wildlife/` (beasts, birds, weather, soundscape), `secrets/`, `encounters/` (tiers, elites, Gloom tide, its own HUD; `spawn_rules.gd` is the one rule set for where any hostile may stand: safe places and towns, ways, water, slope, lips, rocks; `ambush_sites.gd` picks the road ambushes from the land). |
| `core/story/` | Story director (`story.gd`, group `story`, added by Tavern), quests (`quest_db`, `quest_book`, `quest_world`), `dialogue_db`, objective line. |
| `core/npc/` | Dwarf NPCs at the Keg (`dwarf_*`, `bartender`, `keg_scenes`, `npc_voice`). |
| `core/vfx/` | Static FX helpers: `Vfx`, `Sfx` (voice pool), `SpellFx`, `Synth`/`StaffSfx` (procedural audio), hit text. They parent to `current_scene`. Creatures: `EnemyAudio` plays the takes rendered by `tools/gen_enemy_sfx.py` (`enemy_bank.gd` is generated): per voice set idle/alert/windup/attack/hurt/stagger/die, footfalls by body type and ground, hit materials, the wanderer's parry/block/dodge; it picks without repeats, spaces cries per creature and per set, caps the pool and ranks by priority. Buses: enemy voices -> `Voices` (gentle compressor) -> `SFX` (the place's reverb, `Ambience.PLACES`/`ROOMS`) -> `Master` (soft compressor, hard limiter). |
| `core/util/` | `Groups`, `Layers`, `ProcMesh`, `save_dir.gd` (the `--save-dir` seam). |
| `core/debug/` | Boot diagnostics, perf watch, deep-dive recorder. |
| `ui/` | HUD, settings menu, loading screen, `character_screen.gd` (r35/r36: one key, four tabs: gear, charms, relics, staff), Satchel, Kindling (`growth.gd`), Journal (`codex.gd`), quest log, dialogue, shop, hotbar, hints. |
| `world/` | `main.tscn` / `main.gd` (the night), `areas/ossuary/` (streamed Ossuary: built in its own local coordinates, the node carries the frame in `oss_frame.gd` (a quarter turn under the Waiting Field); `oss_world.gd` places kit nodes by local numbers), `zones/ascension/` (baked meshes), `lab/` (light lab). |
| `zz/` | Tests (`*_test.tscn`), probes, shot generators. Not shipped. |
| `tools/` | Bakers, texture/audio generators, `run_tests.sh`. Not shipped. |

All on-screen text (banners, narration and lesson subtitles, toasts, the objective) posts to
`ui/text_director.gd`, a child of the HUD: lanes, priorities, a busy rule while narration or a
dialogue box is up, and one discovery banner per 90 s. Encounter banners, secrets banners and
`world_events.gd` still draw on their own (to route next).

**The slice.** `core/util/slice.gd` (`Slice.full()`): the full night is the default. `-- --slice`
(or Engine meta `full_night` set to false) gives the 30-minute slice instead: no horses, Kindled
Watch, roaming events, faction tiers, daily bounties, attunement gates or gear
raise/reforge/salvage. See docs/DECISIONS.md.

Who creates UI today (there is no single UI root): `main.tscn` (HUD, SettingsMenu), `main.gd`
(Satchel), `progression.gd` (Kindling, combo readout), `story.gd` (dialogue, quest log, shop),
`realm_lore.gd` (Journal), `encounters/director.gd` (encounter HUD), `boss_arena.gd` (boss bar),
`secrets/panel.gd`, `hud.gd` (hotbar, objective line), `zone.gd` (loading screen).

## Rules that hold

- Feature folders; files `snake_case`, nodes `PascalCase`. Most scripts have no `class_name` and
  are preloaded by path; anything another feature calls should be reached through a typed ref
  (`preload` const or `class_name`), not `.call("name")`.
- Gameplay talks through `Events` signals and `Groups.*`. 21 more group names are still raw strings
  (`story`, `bolt_pool`, `boss_arena`, `progression`, …).
- **Static state.** `static var` is allowed for immutable caches. Night state in statics must be
  listed and reset in `core/world/session_state.gd`; a `static var` typed Node or Callable must be
  in its `NODE_REFS` (the test runner's lint fails otherwise). Engine-resource caches in world
  builders are released by `Realm.release_caches()`.
- `Player` is the controller, `CharacterRig` the skin: `animate()`, `cast()`, `equip()`,
  `set_view()`, `debug_drive()`. Staff in `hand_r`. Bolts from the Zone's `BoltPool`.
- Pause with `get_tree().paused`, never `Engine.time_scale = 0`.

## Persistence

| File | Owner | Holds |
| --- | --- | --- |
| `slot_N/savegame.cfg` (N = 1..3; + `.bak`, atomic `.tmp` rename; an old root `savegame.cfg` migrates into slot 1) | `Travel` | progress, kindles, checkpoints, items, bosses, seals, `story`, `systems` (per-system sections: progression, village, secrets, …) |
| `settings.cfg` | `Settings` | graphics, display, audio, camera |
| `codex.cfg` | `CodexStore` (static) | Journal read state |
| `user://realm_cache/`, `res://art/realm_cache/` | `GenCache` | procedural meshes/shapes; only `-- --bake-cache` writes `res://`. The shipped cache is baked with `godot --headless --path . res://zz/bake_cache.tscn -- --bake-cache`, which loads the night, waits for the Realm and quits (`zz/bake_cache.gd`). `art/realm_cache/` is gitignored. |

All three cfg files live in `core/util/save_dir.gd`'s folder: `user://` unless `-- --save-dir=` or
`UMBRAL_SAVE_DIR` is given. `tools/run_tests.sh` runs every test with an isolated HOME (some tests read `user://savegame.cfg` directly).

## Rendering

Glow budget (`core/world/atmosphere.gd`): intensity 0.62, bloom 0.06, HDR threshold 1.15, levels 0
and 1 only. Internal height cap 960 (810 on the lowest detail). Stretch `canvas_items`. AA is a setting (`Settings.AA_NAMES`:
Off, FXAA, SMAA, TAA, MSAA 2x/4x), default Off. Far DoF off. Player lantern shadows off.

## Physics

Layers (`core/util/layers.gd`): WORLD 1, PLAYER 2, HURTBOX 4, INTERACT 8, PROPS 16.

## Tests

`tools/run_tests.sh [name …]` runs every `zz/*_test.tscn` headless, each in its own scratch HOME with a
timeout, and fails on a nonzero exit (a PASS line then a deliberate self-kill is allowed), any `FAIL` line, or any `SCRIPT ERROR` /
`Parse Error` / `Failed to load script` in the log (a parse error elsewhere cascades silently
otherwise). It also runs the static lint and `tools/lint.sh`, a ratchet: per file, string `.call("…")`, `has_method`,
`.get("_private")` and round-tag comments may not rise above `tools/lint_baseline.txt`, and a file over
1,000 lines may not grow by more than 50. Run `tools/lint.sh --update` only after counts went down.
Run it before every pack.

Quest data is checked by the `audit()` function in `core/story/quest_chains.gd`.

## Navigation

`RealmNav` (`core/world/realm/realm_nav.gd`) bakes one navigation mesh from WORLD collision as a late
Realm module, on a worker thread, cached through GenCache. Enemies and the Shade keep cheap straight
steering and ask `NavAssist` (`core/enemy/nav_assist.gd`) for a path corner only when the straight
line is walled or they stall (at most one query per 0.5 s). Dynamic walls (briars, gates, the raid
maze) are not in the mesh.

## Pack

Linux `.pck` into `Umbral Reaches.app/Contents/Resources` (`.cursor/skills/umbral-pack`). Never
headless-save `world/main.tscn` (to remove nodes, edit it as text). Binding do-not-undo:
`.cursor/rules/umbral-constraints.mdc`, `.cursor/skills/umbral-donts`.
