# Architecture — last verified 2026-11-02

Godot **4.7.2** Forward+ / Jolt. Playable night: Stair of Ascension (`world/main.tscn`).

## Layout

Feature folders (`core/player`, `core/world`, `core/enemy`, `ui`, `world`, `autoload`). Files `snake_case`, nodes `PascalCase`. New content is a scene or a Resource.

**Autoloads (five):** `Events`, `Settings`, `Travel`, `LightGrid`, `InputSetup`. No GameManager. No AudioManager — sounds live on the node that makes them.

## Runtime vs bake

`main.tscn` is static architecture. Runtime (or `tools/bake_dress.gd` → `world/zones/ascension/dress.tscn`) adds WindowRig, occluders, lantern/brazier GLBs, glimmers, enemies. **Never `--headless` save `main.tscn`** (MultiMesh AABB wipe).

## Player / combat

`Player` owns move, camera, gloom. `CharacterRig` owns skeleton, sockets, stride, cloth. Talk through `animate()`, `cast()`, `equip()`, `set_view()`, `debug_drive()`. Staff in `hand_r`. Bolts come from `BoltPool` on the Zone.

## Rendering

Glow budget: intensity 0.62, bloom 0.06, HDR threshold 1.15, levels 0 and 1 only. Internal height cap 960. Stretch `canvas_items`. No AA. Far DoF off. Player lantern shadows off. ForestFloor is 16 m cells; vis-range is node-origin distance.

## Physics

Layers: WORLD 1, PLAYER 2, HURTBOX 4, INTERACT 8, PROPS 16. Groups: `Groups.*`. Pause with `get_tree().paused`, not `Engine.time_scale`.

## Pack

Linux `.pck` into `Umbral Reaches.app/Contents/Resources`. See `.cursor/skills/umbral-pack`. Binding do-not-undo: `.cursor/rules/umbral-constraints.mdc`.
