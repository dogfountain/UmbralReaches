# Umbral Reaches

Godot **4.7.2** Forward+ prototype. Playable night: the Realm round Hearthward, booted from `world/main.tscn`.

**Phase: the Far Reaches (Luke, 15 Nov): the Realm doubled again to 740 x 548 m, existing systems only, in-house assets. Read `docs/PILLARS.md`, `docs/r37_expansion.md` and `docs/far_reaches.md` first.** Decisions are logged in `docs/DECISIONS.md`.

## How this project is built

Follow official Godot practice, not Unity/Unreal:

- Feature folders (`core/player`, `core/world`, `ui`). Files `snake_case`, nodes `PascalCase`.
- Autoloads are persistent services, not a phone book of live nodes. Gameplay uses **signals** (`Events`) and **groups** (`Groups.*`).
- `Player` is the controller; `CharacterRig` is the skin. `Zone` is the shared night shell.
- Static architecture is baked; the wanderer, portals, glimmers, and shades spawn at runtime.

Cursor rules in `.cursor/rules/` are binding. Current truth: `ARCHITECTURE.md`. Learned playbook lives in `.cursor/skills/` (`umbral-pack`, `umbral-donts`, `umbral-nights`, `umbral-culling`, `umbral-player`, `umbral-pipeline`, `umbral-blender`). Blender modeling copies (`blender-modeler`, `godot-export`, …) are MIT from [arjun988/blender-skills](https://github.com/arjun988/blender-skills); `umbral-donts` still wins.

## Everyday commands

```sh
godot --headless --path . --import --quit
tools/run_tests.sh --quick  # the world-free tier (tools/fast_tests.txt), ~30 s: run on every change
tools/run_tests.sh        # every zz/*_test.tscn (before a merge); isolated HOME, one shared Realm cache
                          # (.godot/realm_cache_tests); fails on SCRIPT ERROR / Parse Error / FAIL
godot --headless --path . --export-pack "Linux" "/tmp/Umbral Reaches.pck"
```

Do not headless-rebake `main.tscn`.
