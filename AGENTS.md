# Umbral Reaches

Godot **4.7.2** Forward+ prototype. Playable night: the Realm round Hearthward, booted from `world/main.tscn`.

**Phase: consolidation. No new systems. Fix, cut, polish, playtest. Read `docs/PILLARS.md` first.** Decisions are logged in `docs/DECISIONS.md`. The critique being written now: `docs/THE_NIGHT.md`.

## How this project is built

Follow official Godot practice, not Unity/Unreal:

- Feature folders (`core/player`, `core/world`, `ui`). Files `snake_case`, nodes `PascalCase`.
- Autoloads are persistent services, not a phone book of live nodes. Gameplay uses **signals** (`Events`) and **groups** (`Groups.*`).
- `Player` is the controller; `CharacterRig` is the skin. `Zone` is the shared night shell.
- Static architecture is baked; the wanderer, portals, glimmers, and shades spawn at runtime.

Cursor rules in `.cursor/rules/` are binding. Current truth: `ARCHITECTURE.md`. Learned playbook lives in `.cursor/skills/` (`umbral-pack`, `umbral-donts`, `umbral-nights`, `umbral-culling`, `umbral-player`, `umbral-pipeline`, `umbral-blender`, `umbral-unreal`, `unreal-export`). Blender modeling copies (`blender-modeler`, `godot-export`, …) are MIT from [arjun988/blender-skills](https://github.com/arjun988/blender-skills); `umbral-donts` still wins. Unreal Mac port: `umbral-unreal` + `unreal-export`.

## Everyday commands

```sh
godot --headless --path . --import --quit
tools/run_tests.sh        # zz/*_test.tscn, isolated HOME, fails on SCRIPT ERROR / Parse Error / FAIL
godot --headless --path . --export-pack "Linux" "/tmp/Umbral Reaches.pck"
```

Do not headless-rebake `main.tscn`.
