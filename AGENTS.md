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

**Commits come only from Luke:** never add a `Co-Authored-By:` line (Claude, Cursor or any AI) or a "Generated with" footer to a commit message or PR.

## Code graph: use it before every change

`tools/code_graph.py` indexes how this project really links (preload/load paths and their consts, `"res://"` path strings,
class_name, extends, autoloads, `Events` signals, groups, scenes, `Class.func()` calls). It rebuilds itself when files change.
**Before editing a script, and before moving, renaming or deleting anything:**

```sh
tools/code_graph.py impact <file>     # what could break, and which zz tests reach it (run those at the end)
tools/code_graph.py who <file|Class>  # every link into it
tools/code_graph.py signal <name>     # who declares, emits and connects (Events.x or local)
tools/code_graph.py group <name>      # who adds, looks up and tests a group (string or Groups.CONST)
tools/code_graph.py find <symbol>     # where a func/const/var/signal/class is defined
```

Use its answers instead of guessing names or grepping by hand, and name what it showed in the commit when a change reaches
other files. Briefs for agents carry this rule.

## Everyday commands

```sh
godot --headless --path . --import --quit
tools/run_tests.sh --quick  # the world-free tier (tools/fast_tests.txt), ~30 s: run on every change
tools/run_tests.sh        # every zz/*_test.tscn (before a merge); isolated HOME, one shared Realm cache
                          # (.godot/realm_cache_tests); fails on SCRIPT ERROR / Parse Error / FAIL
godot --headless --path . --export-pack "Linux" "/tmp/Umbral Reaches.pck"
```

Do not headless-rebake `main.tscn`.
