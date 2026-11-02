---
name: umbral-culling
description: Fixes grass pop, lava disappearing, thin water, and MultiMesh frustum culls in Umbral Reaches. Use when foliage pops, meshes vanish up close, visibility_range, extra_cull_margin, custom_aabb, ForestFloor, or occlusion looks wrong.
---

# Culling traps

Godot visibility range on a `GeometryInstance3D` is distance to the **node origin**, not each MultiMesh instance.

ForestFloor chunks (`grass_X_Y`, ferns, caps) are parented at world origin. Instance transforms hold the real positions. A 16 m `visibility_range_end` hid grass underfoot as soon as the camera left spawn. Fade-self on that range looks like blades popping.

## Forest floor

`atmosphere._cull_geometry` plus `_repair_floor_aabb`:

- Grass / fern / floor MultiMeshes: `visibility_range_end = 0` (disabled).
- Rebuild `custom_aabb` from instance origins and `grow(3.5)`.
- `extra_cull_margin` ≥ 14. Do **not** force foliage margin to 0.
- `ignore_occlusion_culling = true` on floor MultiMeshes (box occluders from collision eat nearby blades).

Do not recenter ForestFloor nodes to "fix" range. Vale hide-under-bridge and `seat_props` treat instance origins as world points while the node sits at 0.

## Other meshes that vanished

| What | Cause | Fix already in code |
| --- | --- | --- |
| Lava crust | `atmosphere` matched name `Surface`, set vis ~57 m, wiped extra_cull | Skip Lava subtree; huge `custom_aabb`; extra_cull 80; vis 0 |
| Vale river | Baked strip height ~0 → empty AABB | `vale.gd` `_show_river()` |
| Headless-baked MultiMesh | Instance data / AABB wiped | Never headless-rebake `main.tscn` / `vale.tscn` |

`push_pos` in `foliage.gdshader` **parts** grass around the player. That is not pop. Do not remove `world_vertex_coords` (it avoids per-vertex `inverse(MODEL_MATRIX)`).

## Atmosphere cull rules

Skip vis-range on terrain, water, river, glass, mirror, nave, masonry, flare, flame, fire, coals, lava, ember, and anything under a `Lava` ancestor. Keep glow budget tight (see `umbral-donts`). Leaves: do not drop `alpha_cut` or use `layer_fill` — that turned cards into squares.

When something "only renders when I am on top of it", assume wiped AABB or vis-range-to-origin before assuming the shader is wrong.
