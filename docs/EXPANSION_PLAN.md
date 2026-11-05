# Expansion pass (r28): six agents, each expanding an existing feature heavily

Luke asked for six agents, each deepening what the game already has. They work **at the same time
in one checkout**, so file ownership below is binding. The lead (main session) reviews, integrates
shared files, runs the full suite, checks performance and repacks.

## Ownership

| Agent | Expands | Owns (may create/edit) |
|---|---|---|
| **A Combat & enemies** | enemy variety and AI, attack patterns, telegraphs, elites, bosses, camps, hit feedback | `core/enemy/*`, `core/life/encounters/*`, `core/vfx/synth.gd`, `zz/combat_*`, new `zz/enemy_*` |
| **B Skills, staff & progression** | skill depth (ranks that change behaviour, new unlockable skills, loadout), staff/orb upgrades, Marks combos, charms, relics, items | `core/skills/*`, `core/player/magic_bolt.gd`, `core/player/bolt_pool.gd`, `core/vfx/spell_fx.gd`, `core/vfx/vfx.gd`, `core/vfx/staff_sfx.gd`, `core/life/progression/*`, `core/items/*`, `ui/hotbar.gd`, `ui/growth.gd`, `ui/satchel.gd`, new `zz/skill_*` |
| **C Movement, traversal & player animation** | traversal moves (ledges, walls, momentum), lock-on/strafe, locomotion and combat animation quality, camera feel | `core/player/*` except B's files, `zz/move_*`, new `zz/trav_*` |
| **D Exploration, secrets & lore** | more secrets and puzzles, hidden places, a deeper Ossuary, lore and the Journal | `core/life/secrets/*`, `core/world/realm/lore/*`, `core/world/lore_scrap.gd`, `world/areas/ossuary/*`, `ui/codex.gd`, new `zz/secret_*` |
| **E Village, NPCs, quests & story** | quest chains, villager requests, trading, branching dialogue with consequences, NPC routines, tavern life | `core/life/village/*`, `core/story/*`, `core/npc/*`, `ui/dialogue.gd`, the NPC section of `core/world/tavern.gd`, new `zz/quest_*` |
| **F Living world & soundscape** | wildlife behaviours and new creatures, weather events, night phenomena, regional ambience and music layers | `core/life/wildlife/*`, `core/world/ambience.gd`, `art/audio/life/*`, new `zz/world_*` |

**Shared seams** (edit with the Edit tool only, small additions, never rewrite the file):
- `core/player/player.gd`: owned by C. B may add new functions only, at the end of the file under
  a `# --- skills hooks (B) ---` heading. A may add an enemy-facing hook the same way under
  `# --- combat hooks (A) ---`.
- `autoload/input_setup.gd`: anyone may add a new action with one `_keys/_mouse/_pad` line. Check
  the current bindings first and do not reuse a key. Taken: WASD/arrows, Shift, Space, E, LMB/R,
  RMB, Q, F, C, Ctrl, Tab/I, F1-F4, F8, F9, F11, F2/Esc. Free suggestions: Z, X, V, G, T, B,
  middle mouse, mouse wheel.
- `autoload/events.gd`: new signals may be added (one line each).

**Lead only** (ask in your report; do not edit): `world/main.gd`, `world/main.tscn`,
`core/world/zone.gd`, `core/world/realm/realm.gd`, `core/world/atmosphere.gd`,
`core/world/light_policy.gd`, `world/post/*`, `ui/loading_screen.gd`, `ui/settings_menu.gd`,
`ui/hud.gd`, `autoload/settings.gd`, `autoload/travel.gd`, `export_presets.cfg`, `project.godot`,
`docs/HANDOFF.md`. New UI goes in your own CanvasLayer script under your owned folders (or a new
`ui/<yours>.gd`).

## Rules (binding, from Luke and AGENTS.md)

- Godot 4.7.2, typed GDScript. **No `class_name` in new scripts** (preload by path).
  Deterministic generated meshes and textures go through GenCache
  (`core/world/realm/gen_cache.gd`).
- **Never headless-rebake `world/main.tscn`.** Everything new is built at runtime.
- Do not restyle the hub stair, the spawn/sanctuary textures or the wanderer's identity (robe
  pieces, void face, staff in hand_r, wave shader). No anti-aliasing. Glow budget is fixed. The
  colour grade, moon, fog and ambient values belong to the lead.
- **Saves:** run every windowed or headless test with an isolated home so user:// is never Luke's:
  `HOME=<your scratch>/home godot --path . ...`. Also set `Travel._busy = true` in any new test.
  Never write `settings.cfg` or `codex.cfg` in Luke's folder. If you must use the real folder, back
  up `~/Library/Application Support/UmbralReaches/{savegame.cfg,savegame.cfg.bak,settings.cfg}`
  first and restore them byte-for-byte.
- `rm` only explicit full paths, never globs or variables. Don't commit, stay on master, no branches.
  Never pkill Godot (Luke's editor or game may be open). Run long renders and tests in the
  background and poll; there is no `timeout` command on macOS.
- **Performance budget** (Luke plays at Cinematic, 120-144 Hz): hub stress fps must not drop more
  than 3 % because of your work. Measure before and after with
  `zz/perf_tour.tscn -- --points-only --preset=2 --stress=2 --only=r_spawn_west,r_meadow,r_tavern_in`.
  Scripts at most +0.1 ms per frame in the hub. ≤ 900 draws, ≤ 1.5 M primitives. Nothing new may
  hitch: build at load (the loading screen covers it) or spread work over frames.
- **New shaders, enemies or effects:** list them in your report, and the lead adds them to the
  loading screen's warm-up.
- Other agents render windowed at the same time, so treat single fps numbers as noisy. Repeat a
  measurement, or compare A/B in alternation.
- Keep every existing test green: `zz/check`, `realm_audit`, `move_course`, `combat_duel`,
  `boss_test`, `story_test`, `village_test`, `secrets_test`, `progression_test`,
  `encounters_test -- --fresh`, `life_test`, plus whatever covers your area. Add a test for your new
  features.
- Show your work: before/after renders in `shots/` named `<agent>_<what>_before|after.png`.

## Report (each agent, at the end)

What you added (player-facing first), files touched, tests run and their results, before/after
fps, new shaders/enemies/effects for the warm-up, requests for lead-only files, and known gaps.
