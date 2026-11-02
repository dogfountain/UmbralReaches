# Umbral Reaches

Godot **4.7.2** Forward+ prototype. Playable night: Stair of Ascension (`world/main.tscn`). Crimson Vale removed — next night TBD.

## How this project is built

Follow official Godot practice, not Unity/Unreal:

- Feature folders (`core/player`, `core/world`, `ui`). Files `snake_case`, nodes `PascalCase`.
- Autoloads are persistent services, not a phone book of live nodes. Gameplay uses **signals** (`Events`) and **groups** (`Groups.*`).
- `Player` is the controller; `CharacterRig` is the skin. `Zone` is the shared night shell.
- Static architecture is baked; the wanderer, portals, glimmers, and shades spawn at runtime.

Cursor rules in `.cursor/rules/` are binding. Learned playbook lives in `.cursor/skills/` (`umbral-pack`, `umbral-donts`, `umbral-nights`, `umbral-culling`, `umbral-player`, `umbral-pipeline`, `umbral-blender`, `umbral-unreal`, `unreal-export`). Blender modeling copies (`blender-modeler`, `godot-export`, …) are MIT from [arjun988/blender-skills](https://github.com/arjun988/blender-skills); `umbral-donts` still wins. Unreal Mac port: `umbral-unreal` + `unreal-export`. Pipeline traps also live in `AGENT_HANDOVER.md` — prefer the skills when the two disagree. Critique and in-place polish: `docs/perfecting_umbral_reaches.md`.

## Everyday commands

```sh
godot --headless --path . --import --quit
godot --headless --path . --export-pack "Linux" "/tmp/Umbral Reaches.pck"
```

Do not headless-rebake `main.tscn`.
