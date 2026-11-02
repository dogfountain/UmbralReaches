---
name: umbral-blender
description: Umbral gate for Blender modeling. Use before any new mesh, glTF, sculpt, prop, staff fitting, or "more detailed models" request. Routes to copied blender-modeler skills after umbral-donts. Never rewrite the wanderer or shade; gothic is lights only.
---

# Umbral Blender

Copied modeling skills live next to this file. They are MIT from [arjun988/blender-skills](https://github.com/arjun988/blender-skills). License: `.cursor/skills/blender-skills-LICENSE.txt`.

**Read `umbral-donts` first.** Those bans win over every Blender skill in this folder.

## Do not

- Rewrite the wanderer or the Shade meshes. Staff, gauntlets, boots, void face, robe pieces + procedural stride stay.
- Instance `gothic_bay.glb` or `toad.glb` as level meshes. Gothic is window lights. Toad is `vale_toad.gd`.
- Restore bead-arches, blob guardians, cape/hem, paper-strip robes, Sketchfab priest, mint glass.
- Put `.blend` under `art/models/`. `art/blender/` has `.gdignore` on purpose.
- Fake world detail with extra shader samples (dual triplanar, AO overlay) on giant trunks. That killed Vale fps.
- Copy in `character-artist`, `creature-artist`, `environment-artist`, or the horror packs from the upstream repo. They would undo this game.

## How detailed models are actually made

Detail is **form hierarchy**, not vertex spam.

1. **Primary** — silhouette from primitives. Scale reference in metres. Name `SM_` immediately. Keep blockout in `COL_Blockout`.
2. **Secondary** — manufacturing cuts. Inset, loop cuts, live Booleans, Bevel. Same bevel width per tier.
3. **Tertiary** — sculpt Multires/Dyntopo *or* baked normals. Do not sculpt panel lines that a Bevel already does.
4. **Game mesh** — retopo the high, unwrap, bake normal/AO onto the low, then export.

Non-destructive stack (bottom → top), from `blender-modeler`:

```
Mirror → Array → Solidify → Boolean (live) → Bevel → Weighted Normal → Subdivision last
```

Apply scale before Booleans. Apply modifiers only at export. Merge by distance 0.0001 m. Recalculate outside normals. Query polycount after each pass.

For this prototype, hero props (staff fittings, braziers, gate iron) can take the full bake path. Forest trunks, grass, and night mass stay baked MultiMesh + 1024 albedo/normal. Do not replace ForestFloor with unique hero trees.

## Route

| Request | Skill to read |
| --- | --- |
| Blockout, modifiers, cleanup | `blender-modeler` |
| Crisp edges, panels, iron, weapons | `hard-surface` |
| Small set-dress props | `prop-artist` |
| Surface damage, organic micro | `sculpting` then `retopology` |
| UVs | `uv-workflow` |
| PBR / bake | `materials`, `texture-workflow`, `lookdev` |
| Polycount, LODs, collision | `asset-optimization`, `lod-pipeline`, `collision-proxy` |
| Godot glTF | `godot-export` **and** the export box below |
| Unreal / UmbralReachesUE glTF | `unreal-export` (same GLB flags; measure 1 m → 100 uu) then `umbral-unreal` to pack |
| Foliage cards | Prefer existing `gen_foliage.py`. `vegetation-artist` only if asked for a new hero plant. |
| Mood | `dark-gritty-mood`, `stylized-style` — colour only, never purple arcane robes |

Shared naming and MCP notes: `.cursor/skills/references/`.

## Export into this repo

Matches `umbral-pipeline`, `godot-export`, and `unreal-export`:

```
art/blender/<asset>.blend     # source, gdignored
art/models/<asset>.glb        # Godot runtime
# shared props also copy → UmbralReachesUE/Content/Raw/Models/
```

glTF: `export_apply=True`, `export_yup=True`, GLB, Principled BSDF only. **Units: 1 BU = 1 m.** Verify in-engine (Godot metres / UE ×100 cm). Then `godot --headless --path . --import --quit`. Do not headless-rebake `main.tscn` / `vale.tscn`. Pack Godot with `umbral-pack`; pack Unreal with `umbral-unreal`.

## MCP

Upstream skills assume Blender MCP. This project does not require it. If MCP is connected, execute in Blender. If not, write bpy under `tools/blender/` and export GLB by hand. Same topology rules either way.

Setup (optional): https://github.com/arjun988/blender-skills — install uv, BlenderMCP addon, Connect in the N-panel.
