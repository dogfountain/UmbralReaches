---
name: umbral-pipeline
description: Godot bake, Blender export, texture gen, and CLI traps for Umbral Reaches. Use when baking, exporting glTF, adding class_name, generating textures, running -s tools, or when MultiMeshes come back empty.
---

# Pipeline

Godot **4.7.2** Forward+, Jolt. Traps that already cost real time:

1. **Never `--headless` bake** `main.tscn` / `vale.tscn`. MultiMesh instance data and AABBs wipe; forest floor vanishes. The old bake tool is removed. To remove nodes from `main.tscn`, edit it as text (cut the `[node]` sections and the sub-resources only they used); Godot must never save it headless.
2. **`godot --check-only` hangs.** Do not use it.
3. **Do not pkill** the owner's Godot editor.
4. A new `class_name` is invisible to `-s` tools until `godot --headless --path . --editor --quit` rescans.
5. `world/zones/ascension/terrain_mesh.res` and `terrain_shape.res` were baked by a tool since removed; do not hand-edit them.
6. Homebrew Python 3.15 has **no numpy**. Texture gen: use `/tmp/umbral-tex` (or another venv that has numpy), not system `python3`.

## When a rebake is actually required

Changes to bake scripts, `height()`, foliage placement, materials built in `_materials()`, or the baked environment. **Not** required for player, rig, UI, shaders applied at runtime, or `atmosphere` / `vale_dress` / `glimmers`. Prefer runtime dress.

After a GPU bake, MultiMeshes still need an explicit `custom_aabb`. Empty AABB = every instance culled. See `umbral-culling`.

## Blender / glTF

- `art/blender/` has `.gdignore`. Godot will import `.blend` if it can see it.
- Export glTF with `export_apply=True`, `export_yup=True`.
- Do not put `.blend` under `art/materials/` or `art/models/`.

## Everyday (no bake)

```sh
tools/run_tests.sh                     # headless suite, isolated HOME, fails on script errors
godot --headless --path . --import --quit
godot --headless --path . --export-pack "Linux" "/tmp/Umbral Reaches.pck"
```

Then follow `umbral-pack`. Look-dev stills: `tools/capture.gd` (~45 s/view under software; pass `--only=`).

## Architecture reminders

Five autoloads only: `Events`, `Settings`, `Travel`, `LightGrid`, `InputSetup`. No GameManager. No AudioManager — sound lives on the node that makes it. Groups over `get_parent()`. Spawn into `get_tree().current_scene`. Pause with `get_tree().paused`, never `Engine.time_scale = 0`.
