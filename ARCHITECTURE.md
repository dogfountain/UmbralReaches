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
  loading screen         ui/loading_screen.gd  waits for the build + shader warm-up (the tour of views, each heading
                                              with and without the lantern's light state; then beside the panels the
                                              pipeline sweep, core/world/pipeline_warm.gd), then lifts
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
| `core/world/realm/rift/` | The Ashen Rift's built pieces (`RealmRift`), the endgame at the far north-east beyond Lastlight (`realm/endgame.gd`: built round the old chasm under Hearthward on a loan of the north-east's ground, then moved `Endgame.O` east; `realm/endgame_ground.gd` gives home its own ground back). `scorch.gd` is the burn and the flows round it, `plume.gd` the smoke column (dressed by `realm/rift_rim.gd`). `crossing.gd` is the ruined pilgrims' viaduct from the south rim to the summit ward. `threshold.gd` is the terraced pilgrims' threshold down to the starwater, with the two lantern pillars called the Watchers. `chapel.gd` is the small Pilgrims' Chapel at the foot of the west wall, where the starfall pours. `tower_stair.gd` is the Pilgrims' Stair down the crossing's third tower to the chapel. `starlit_stone.gd` is the rift's paler stone, with a little starlight in it. `features.gd` is the rift's set dressing: basalt organ pipes, cooled islands, ash fields and fissures. |
| `core/world/realm/lamps/` | The Realm's lamps, placed by `lamp_places.gd` after the settlements are dressed. A kindled lamp (`lamp.gd`) is a light the wanderer lights with the staff gesture (E); it burns for the rest of the night and the save remembers it. A kept light (`lamps_kept.gd`) is a light others keep, already lit: a pilgrim's camp on the Downs, a ferryman's lamp on the Sorrow, a hunter's lantern in the Thornwood, a window lit in a ruin. Neither is gameplay light. `-- --no-lamps` turns them off. |
| `core/life/wildlife/boss_themes.gd` | r35 composed (synthesised) themes for the three bosses and the ending bell, rendered on a worker thread and cached through `GenCache`. |
| `core/life/` | Living-world systems, each started as a Realm module: `progression/` (Kindling: ash -> upgrades, `UpgradeDB`), `village/`, `wildlife/` (beasts, birds, weather, soundscape), `secrets/`, `encounters/` (tiers, elites, Gloom tide, its own HUD; `spawn_rules.gd` is the one rule set for where any hostile may stand: safe places and towns, ways, water, slope, lips, rocks; `ambush_sites.gd` picks the road ambushes from the land). |
| `core/story/` | Story director (`story.gd`, group `story`, added by Tavern), quests (`quest_db`, `quest_book`, `quest_world`), `dialogue_db`, objective line, the tracked task (`quest_track.gd`, group `quest_track`) and its trail (`quest_trail.gd`, `trail_route.gd`), the new player's guide (`guide.gd`, group `guide`, a child of the director; its words in `guide_lines.gd`). |
| `core/npc/` | Dwarf NPCs at the Keg (`dwarf_*`, `bartender`, `keg_scenes`, `npc_voice`). |
| `core/vfx/` | Static FX helpers: `Vfx`, `Sfx` (voice pool), `SpellFx`, `Synth`/`StaffSfx` (procedural audio), hit text. They parent to `current_scene`. Creatures: `EnemyAudio` plays the takes rendered by `tools/gen_enemy_sfx.py` (`enemy_bank.gd` is generated): per voice set idle/alert/windup/attack/hurt/stagger/die, footfalls by body type and ground, hit materials, the wanderer's parry/block/dodge; it picks without repeats, spaces cries per creature and per set, caps the pool and ranks by priority. Buses: enemy voices -> `Voices` (gentle compressor) -> `SFX` (the place's reverb, `Ambience.PLACES`/`ROOMS`) -> `Master` (soft compressor, hard limiter). |
| `core/util/` | `Groups`, `Layers`, `ProcMesh`, `save_dir.gd` (the `--save-dir` seam), `mesh_merge.gd` (props merged per material), `mesh_stamp.gd` (copies of a few modelled meshes stamped into one mesh at build time: the briar wall). |
| `core/debug/` | Boot diagnostics, perf watch, deep-dive recorder. |
| `ui/` | HUD, settings menu, loading screen, `character_screen.gd` (r35/r36: one key, four tabs: gear, charms, relics, staff), Satchel, Kindling (`growth.gd`), Journal (`codex.gd`), quest log, dialogue, shop, hotbar, hints. |
| `world/` | `main.tscn` / `main.gd` (the night), `areas/ossuary/` (streamed Ossuary: built in its own local coordinates, the node carries the frame in `oss_frame.gd` (a quarter turn under the Waiting Field); `oss_world.gd` places kit nodes by local numbers), `zones/ascension/` (baked meshes), `lab/` (light lab). |
| `zz/` | Tests (`*_test.tscn`), probes, shot generators. Not shipped. |
| `tools/` | Bakers, texture/audio generators, `run_tests.sh`. Not shipped. |

All on-screen text (banners, narration and lesson subtitles, toasts, the objective) posts to
`ui/text_director.gd`, a child of the HUD: lanes, priorities, a busy rule while narration or a
dialogue box is up, and one discovery banner per 90 s. Encounter banners, secrets banners and
`world_events.gd` still draw on their own (to route next). A lesson written with `{action}` tokens
(`"{jump} Jump"`) draws its keys as painted caps (`ui/key_cap.gd`, art `ui/icons/key`), and so does
the world prompt's `[E]`.

**The tracked task and its trail** (docs/quest_trail.md). One way of guiding, always in place. `QuestBook.follow(id)`
(the ledger's Track; story key `follow`, "" = default, `QuestBook.MAIN` = the story's own way, "The Night's Road") picks the one
task the HUD follows; nothing picked: the guided first act's step while the guide is on, else the newest task, else
the story. `core/story/quest_track.gd` (group `quest_track`, a child of the story director) resolves it four times a second:
`current()` = {id, title, text, kind, art, label, key, target, foot}, where the step is (a task's own map target from
`quest_markers.gd`, a pickup, the person to speak to, a seal, a boss's arena, the region of its foes; the story's step
from `guide.gd story_step()`). It is the one source `ui/waypoint.gd` (a painted mark over the place, with its distance),
`ui/compass.gd` (its mark on the strip), `core/story/objective_line.gd` (the tracked task's block behind its painted
pin, or the story's spine) and the map pin read. `core/story/quest_trail.gd` (group `quest_trail`) lays the marks:
the route runs along the ways first (`trail_route.gd`: an A* over `RealmLayout.PATHS` and the walkway lanes), joined to
the player and the place by navigation-mesh legs (asynchronous queries) or straight lines, and by the mesh alone where the
ways do not help; it is rebuilt only when the step, the place, or the wanderer's position changes by a lot (at most
every 1.5 s, never per frame). Marks every ~13 m and at turns, the next four within ~46 m, six pooled `Decal`s, seated once,
faded in as you near them and out once passed; none in a fight, a lock-on, talk, narration, a menu or the opening.
There is no setting for it. **The guide** (`core/story/guide.gd`, story flag `guide` set by the staged opening; off for older saves,
after the act, or with Settings > Interface > Guidance off) now only teaches: the next step's banner, the first
controls on painted key caps, Hearthward's people calling out and pointing the way (`villager_point.gd`) and answering
"Which way?". Its `story_step()` (the spine objective and its place) is always resolved: it is the place of the story's way.

**The slice.** `core/util/slice.gd` (`Slice.full()`): the full night is the default. `-- --slice`
(or Engine meta `full_night` set to false) gives the 30-minute slice instead: no horses, Kindled
Watch, roaming events, faction tiers, daily bounties, attunement gates or gear
raise/reforge/salvage. See docs/DECISIONS.md.

Who creates UI today (there is no single UI root): `main.tscn` (HUD, SettingsMenu), `main.gd`
(Satchel), `progression.gd` (Kindling, combo readout), `story.gd` (dialogue, quest log, shop),
`realm_lore.gd` (Journal), `encounters/director.gd` (encounter HUD), `boss_arena.gd` (boss bar),
`secrets/panel.gd`, `hud.gd` (hotbar, objective line, compass, waypoint), `zone.gd` (loading screen).

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
No depth pre-pass on macOS (`project.godot`, `enable.macos=false`; other platforms keep it): the Apple GPU removes hidden opaque pixels itself (docs/DECISIONS.md, 16 Nov).

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
maze) are not in the mesh. The mesh is baked in tiles that the server joins one by one over seconds;
`NavAssist.ready()` is true only once the map answers for a point inside every tile (a map missing a
tile answers from the nearest one it has), and until then enemies steer flat.

## Pack

Linux `.pck` into `Umbral Reaches.app/Contents/Resources` (`.cursor/skills/umbral-pack`). Never
headless-save `world/main.tscn` (to remove nodes, edit it as text). Binding do-not-undo:
`.cursor/rules/umbral-constraints.mdc`, `.cursor/skills/umbral-donts`.
