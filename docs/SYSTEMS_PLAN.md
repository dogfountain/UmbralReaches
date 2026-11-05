# Systems pass — six parallel agents (2026-11-03)

Luke's brief: heavily improve the game's systems, each agent owning one area, improving logic,
assets, models and textures in it. Fix the tavern NPCs; make the main character more detailed.

## Ownership (edit ONLY your files; others are working in this checkout at the same time)

| Agent | Owns |
|---|---|
| **combat** | `core/skills/*`, `core/enemy/*` (enemies, bosses, CreatureMesh, flesh shader), `core/player/magic_bolt.gd`, `core/vfx/*`, `core/world/boss_arena.gd`, `core/items/item_db.gd` (stats only), `ui/hotbar.gd`, combat tests `zz/combat_*` |
| **movement** (incl. the main character) | `core/player/*` except `magic_bolt.gd` (player.gd, character_rig, robe/cloth, camera), `art/models/robe_*`, `staff`, `boot`, `gauntlet`, `hand_lantern`, `arcane_*` materials, `robe.tres`, `mantle.tres`, `autoload/input_setup.gd`, tests `zz/move_*` |
| **lore** | `core/world/realm/lore/*`, `core/world/realm/realm_lore.gd`, `core/world/realm/lore_db.gd`, `docs/LORE.md`, `core/world/lore_scrap.gd`, a new codex/journal UI `ui/codex.gd`, item flavour text in `core/items/item_db.gd` (`desc` fields only), tests `zz/lore_*` |
| **story** (incl. the tavern NPCs) | `core/npc/*` (DwarfRig, DwarfNpc, Bartender), the NPC part of `core/world/tavern.gd` (`_patrons`, PATRONS, chairs; not its architecture), new `core/story/*` (quests, dialogue, story state), `ui/dialogue.gd`, `autoload/travel.gd` (story fields only; keep the save format backward compatible), `docs/STORY.md`, tests `zz/story_*` |
| **optimisation** (runtime) | `core/world/mesh_chunks.gd`, `core/world/light_policy.gd`, `core/world/atmosphere.gd` (culling/quality; not its colours), `core/world/realm/realm_flora.gd` (render settings, chunking, ranges only), `core/debug/*`, `autoload/settings.gd` (quality presets), `zz/perf_*`, `zz/mesh_census*` |
| **storage** (disk, memory, saves) | `*.import` files, `core/world/realm/gen_cache.gd`, `art/realm_cache/`, `tools/*` texture generators (formats/sizes), `export_presets.cfg` (filters), the save file format in `autoload/travel.gd` (save/load functions only; coordinate with story via your report), `zz/storage_*` |

Shared-file rule: if you need a change in a file you do not own, make the smallest possible
hook, say exactly what and why in your report, and never revert others' edits.

## Binding rules (Luke)
- Never headless-rebake `world/main.tscn`; build at runtime. No anti-aliasing. Glow budget fixed
  (intensity 0.62, bloom 0.06, threshold 1.15, levels 0-1). Colour grade/lighting (r21) belongs to
  the lead: don't retune it.
- The main character keeps its identity: robe pieces, dark void face, staff in `hand_r`, wave
  shader cloth, no purple `arcane_robe.gdshader`. More detail and better motion are wanted.
- Keep the spawn brazier and tavern architecture as they are. Don't add `class_name` to new
  scripts (preload by path). `rm` only explicit full paths, never globs; don't delete assets —
  list candidates in your report. Don't commit (Luke runs git).
- boss_test writes the real save: copy `~/Library/Application Support/UmbralReaches/savegame.cfg`
  aside before and restore it after. Don't touch `settings.cfg`.
- Performance budget: ≤ 900 draws, ≤ 1.5 M prims in any view; ~110+ fps windowed 1600x1000.
- Generated meshes/textures: deterministic builders should use GenCache
  (`core/world/realm/gen_cache.gd`) so load time stays ~3.4 s.

## Verify before you report
`godot --headless --path . res://zz/check.tscn` → CHECK DONE bad=0; `zz/realm_audit.tscn` →
AUDIT PASS; your own tests; renders via `zz/spot_shot.tscn -- --at= --look= --name= [--times=]`,
`zz/look_shots.tscn`, `zz/model_shot.tscn`, `zz/tile.gd`; view PNGs. macOS has no `timeout`:
background + poll the log + kill. Final report: files changed, what improved (before/after shots),
test output, perf/size numbers, known gaps, any edits outside your files.
