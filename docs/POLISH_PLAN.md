# Polish + performance pass — three parallel agents (2026-11-04)

Luke's brief: improve the assets of the important things (NPCs, main character, staff,
animations) AND optimise: in the hub he sits at ~107 fps, which isn't good enough.

## Luke's settings (judge everything with these)
`settings.cfg`: Cinematic preset (quality_preset 2, detail 2), window 1920x1080, vsync on, fps
cap 144, render_scale 1.0 (3D height capped at 960 rows -> 0.89), shadows High, SSAO, SSR,
glow, fog on, motion blur 0.35, fov 90. Display 120 Hz ProMotion.

## Baseline (lead, `zz/perf_tour -- --points-only --preset=2 --stress=2`, all systems on)
Hub stress fps: r_spawn_west 65.4 (1% low 38.6, one 35 ms frame), r_spawn_north 62.7.
Plain windowed: 119-120 (display-capped), draws 656-780, prims 0.9-1.05 M (shadow 0.32-0.48 M),
scripts 0.9-1.1 ms (0.5-0.7 before the five life systems). The life systems added ~100 draws and
~200k prims at the hub.
GPU attribution at r_spawn_west (stress, Cinematic, ms of a 14.5 ms frame):
Terrain 2.61 | Player 2.31 | flora 1.86 (leaf cards 1.58, undergrowth 0.53) | SSR 1.76 |
moon shadow 1.46 | motion blur 1.33 | point/spot lights (70) 1.27 | SSAO 0.64 | glow 0.58 |
player lights 0.45 | lava glows 0.36 | sky 0.36 | RealmLore 0.34 | grade 0.31 | window rig 0.21 |
vol fog 0.20 | render scale 100->50%: 5.94.
**Target:** hub stress fps >= 90 (+40 %) on Cinematic with no visible loss; plain windowed at
Luke's 1920x1080 settings holds the 120 Hz display (no frame > 16 ms in the hub after load);
scripts <= 0.8 ms in the hub.

## Ownership (edit ONLY your files; the other two agents work in this checkout now)
| Agent | Owns |
|---|---|
| **character** (main character, staff, wanderer animation) | `core/player/*` (player.gd, character_rig.gd, wanderer_gen/tex/piece/staff.gd, robe_wave/void_face shaders, magic_bolt.gd only if visuals), `art/models/staff*`, `hand_lantern*`, `zz/move_*`, `zz/char_*`. **Also owns the Player's render cost (2.31 ms GPU, ~54 draws + ~98 shadow draws): it must go DOWN while detail goes up.** |
| **npc** (villagers, tavern dwarves, their animation) | `core/npc/*`, `core/life/village/*`, the NPC section of `core/world/tavern.gd`, `core/story/*` (portraits only), `zz/village_*`, `zz/story_*`, `zz/npc_*` |
| **perf** (everything else that costs frame time) | `core/world/atmosphere.gd` (quality/culling, not colour values), `light_policy.gd`, `mesh_chunks.gd`, `autoload/settings.gd` (presets), `core/world/realm/realm_flora.gd` + `flora/*` shaders (render cost only), `world/realm/realm_ground.gdshader` + `core/world/realm/realm_land.gd` (terrain cost only), `core/vfx/motion_blur.gd`, `core/life/wildlife/*`, `core/life/encounters/*` + `core/life/secrets/*` + `core/life/progression/*` (script/render cost only), `core/debug/*`, `zz/perf_*` |

Shared-file rule: smallest possible hook in a file you don't own, report it, never revert others.

## Binding rules
- Look stays: colour grade / moon / fog / ambient values (r21) are the lead's; glow budget fixed
  (0.62 / 0.06 / 1.15, levels 0-1); no anti-aliasing. Prove "no visible loss" with
  `zz/look_shots.tscn -- --tag=x` before/after and the hub spot shots.
- The wanderer keeps its identity: hooded robe pieces, dark void face, staff in `hand_r`, wave
  shader cloth, blue rune veins, lantern; no purple arcane_robe shader.
- Never rebake `world/main.tscn`. No `class_name` in new scripts. Deterministic generated meshes
  and textures go through GenCache. `rm` only explicit paths, never globs or variables. Don't
  delete assets. Don't commit.
- **Luke's save:** every test/render you write or run sets `Travel._busy = true` so it never writes
  `savegame.cfg`; never write `codex.cfg` or `settings.cfg` (perf_tour already keeps settings in
  memory). If something does touch the save, say so in the report; the lead keeps a copy.
- Windowed renders from three agents overlap and can stop rendering when covered: check frames
  differ; run perf measurements only when no other Godot process is running (`ps` first) and
  repeat a run that looks off.

## Verify, then report
`zz/check` bad=0, `zz/realm_audit` AUDIT PASS, your system tests (move_course, story_test,
village_test, life_test, ...), and the perf numbers with `zz/perf_tour -- --points-only --preset=2
--stress=2 --only=r_spawn_west,r_spawn_north,r_tavern_in,r_meadow` (+ `--attrib=r_spawn_west`).
Final report: before/after numbers and shots, files, tests, gaps, edits outside your files.
