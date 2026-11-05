# Bringing the Realm to life — five parallel systems (2026-11-03)

Luke's brief: five agents, each working on a different way to bring the game to life, with
depth and progression. Read docs/HANDOFF.md, docs/LORE.md, docs/STORY.md, docs/REALM_PLAN.md,
docs/SYSTEMS_PLAN.md first: this builds on all of them.

## The five systems (each owns ONLY its folder + named files)

| System | Owns | The player feels |
|---|---|---|
| **progression** | `core/life/progression/*`, `ui/growth.gd` (new), `core/items/item_db.gd` (new items/upgrades; keep existing ids and stats), `ui/satchel.gd` (only to add its tab/hook) | growing stronger: grave ash spent at lit braziers on lasting upgrades (Gloom capacity, spell power, new skill ranks/variants, relic slots), unlockable skills, gear found in the world, a clear sense of build choices |
| **village** | `core/life/village/*`, NPCs it adds (new scripts under its folder; may reuse `core/npc/dwarf_rig.gd` / `dwarf_mesh.gd` by preload, not edit them) | Hearthward coming back to life: villagers with schedules (the smith at her forge, a lamplighter, a pilgrim, a hermit in the Thornwood), a trader taking ash, lost souls you save (`Travel.saved_hollows`) returning to the village, cottages relit and repaired as you progress |
| **life** (wildlife, weather, ambience) | `core/life/wildlife/*` (+ weather nodes it creates), new audio under `art/audio/life/` (generated) | a world that breathes: owls, moths round lanterns, bats, crows on the henge, fen frogs and herons, deer that flee, fish in pools; weather fronts (drizzle, mist banks rolling in the fen, wind gusts bending grass, distant thunder); creatures react to the player and to danger |
| **secrets** (world reactivity, exploration) | `core/life/secrets/*` | exploring pays: hidden places, rune/bell puzzles, shortcuts that open, caches and relic fragments, optional elite guardians; the world visibly changes after each boss (the Thornwood's brambles wither, the fen clears, the vortex sky calms in stages) |
| **encounters** (danger, pacing, endgame) | `core/life/encounters/*`, `core/enemy/enemy_spawner.gd` (additions only; keep REALM_CAMPS + seals), new enemy variants as data/subclasses under its folder | a night that pushes back: a rising "Gloom tide" that sends hunting packs, ambushes on the roads, named elite hollowed with bounties, regional difficulty tiers that scale with progression, rest/respawn rhythm at braziers, a post-game "Deeper Night" (NG+) |

## How it plugs in (already wired by the lead)
- **Build:** `Realm.build` runs each system last, in this order: progression, village, life,
  secrets, encounters. Write `static func build(root: Node) -> void` (may `await`) in
  `core/life/<folder>/<file>.gd` as listed in `core/world/realm/realm.gd` MODULES. Until the file
  exists it is skipped. Test one with `-- --realm-modules=land,rift,bosses,lore,flora,<yours>`.
- **Save:** `Travel.system_state("<id>")` returns your own dictionary (saved in [systems]); mutate
  it and call `Travel.save_game()`. Never touch other keys or other sections.
- **Talking to each other:** through the `Events` autoload signals that exist (read
  autoload/events.gd) and Travel state; if you need a new signal, add it to `autoload/events.gd`
  as ONE line with a comment naming your system (several agents may add lines: append only, never
  reorder or remove). Read others' state read-only (e.g. encounters may read progression's tier).
- **HUD/UI:** add your own CanvasLayer/Control from your build; a one-line hook in `ui/hud.gd` only
  if unavoidable (report it).

## Do NOT edit (others' or locked)
The optimisation agent is still finishing in: `core/world/mesh_chunks.gd`, `light_policy.gd`,
`atmosphere.gd`, `core/world/realm/realm_flora.gd`, `autoload/settings.gd`, `core/debug/*`,
`zz/perf_*`. Also locked: the colour grade (`world/post/*`), `world/main.tscn` (never rebake),
`core/player/*`, `core/enemy/*` except encounters' additions to enemy_spawner.gd, `core/npc/*`,
`core/story/*`, `core/world/realm/*` (realm.gd, layout, land, rift, bosses, lore, flora, assets),
`autoload/travel.gd` (use system_state), the tavern building, the spawn brazier.

## Binding rules
No anti-aliasing; glow budget fixed (intensity 0.62, bloom 0.06, threshold 1.15, levels 0-1);
don't retune the grade/moon/fog. No `class_name` in new scripts (preload by path). Generated meshes
and textures go through GenCache (`core/world/realm/gen_cache.gd`) so warm load stays ~3.4 s.
Budget: ≤ 900 draws, ≤ 1.5 M prims in any view, ~110+ fps windowed. `rm` only explicit paths,
never globs; don't delete assets. Don't commit. boss_test writes the real save: back up
`~/Library/Application Support/UmbralReaches/savegame.cfg` (+ `.bak`) first and restore after;
never write `codex.cfg`/`settings.cfg` from tests. Windowed renders from several agents overlap
and can stop rendering when covered — check that your frames actually differ.

## Verify, then report
`zz/check.tscn` → CHECK DONE bad=0; `zz/realm_audit.tscn` → AUDIT PASS; `zz/boss_test.tscn`
27/27 (save backed up); your own `zz/<system>_*` tests; renders via `zz/spot_shot.tscn`,
`zz/look_shots.tscn`, `zz/tile.gd`. godot = /opt/homebrew/bin/godot; macOS has no `timeout`
(background + poll + kill). Final report: what the player now experiences, files, tests, shots,
perf/load impact, gaps, any edit outside your files.
