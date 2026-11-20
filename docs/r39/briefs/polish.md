# r39 brief: polish the game

Luke, 20 Nov: "Also polish the game."

This is a polish pass over everything a player touches in the first hours. Other agents own some areas; stay out of them:
- **fps-pass:** performance;
- **zone-fit:** stairs, entrances and landmark bases meeting the map;
- **horse-feel:** riding.

Regular enemy models stay as they are.

## How

1. **Critique first, brutally,** as the critique panel: creative, design, combat, animation, art, environment, tech art, sound, UX, QA, perf-feel.
   - Play the opening and the first hours through capture runs: `tools/capture.gd`, `tools/play_capture.sh`, `tools/map_audit.sh --section=spots`. Keep them short; no 40-minute bot runs.
   - Check the screens at full size:
     - title, loading, the first minutes, Hearthward;
     - the first fight, a camp, a dungeon entrance, a boss approach;
     - the menus (inventory, map, quests, skills, settings), dialogue, shops, death and respawn, fast travel;
     - the night's end.
   - List every rough edge with a screenshot or frame. Read `docs/r39/CRITIQUE.md` and the r39 backlogs (`opening_backlog.md`, `light_backlog.md`, `story_sound_backlog.md`, `world_backlog.md`) and carry over what is still open.
2. **Fix them all, end to end.**
   - **Feedback:** hit reads, pickups, level-up, quest steps, UI sounds.
   - **Transitions and fades:** no hard cuts, no flashes, no pale or grey frames.
   - **UI:** alignment, consistent spacing and fonts, clipped or overlapping text, painted icons everywhere (no glyph shapes).
   - **Animation:** pops and snaps. Smoothing is critical: dt-damped blends, nothing stepping.
   - **Sound:** gaps, levels, abrupt cut-offs.
   - **Lighting and art:** dark night with bright landmarks; the Enshrouded-style grade.
   - **Bugs** the critique turns up.
   - **Leftovers from the visual pass:**
     - the Count door's pale void;
     - the summit horizon slab;
     - the pit hall's skull walls (flat, bright orange);
     - the boxy Sleeper;
     - the remaining code-built models: chasm walls, mushroom house, witch houses, salt-sack stairs, plinth box, castellum pyramid, briar wall.

   New or rebuilt models are made in Blender with a render review.
3. **Re-shoot once at the end,** after everything is fixed.

## Rules

- **Clone:** work only in your clone, on branch `polish`. Plain commit messages, small commits; never push. **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:** critique first, then build every fix with no re-shoots in between, then re-shoot once.
  - **Do not run any tests** (no `run_tests.sh`, no `--quick`). The lead runs the one suite after merging.
  - Parse-check headless so it loads.
- **Godot lock:** one Godot process on the machine at a time, shared with three other agents.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run, retrying every 30 s. `rmdir` it after, also on failure.
  - The lock is stale only if `pgrep -x godot` (never `-f`) has shown no Godot for 60 s.
  - Watchdog every run.
  - Kill only your own PIDs, never `pkill`. No pgrep wait loops.
  - Windowed runs: parse-check first, then use `--always-on-top`. Keep runs short.
  - **Blender:** use `/tmp/umbral_blender.lock` with the same rules.
- **Never:**
  - dynamic resolution;
  - rebaking `world/main.tscn`;
  - cutting content ("content is thin": reshape or add, never cut);
  - new shadowed lights;
  - non-in-house assets;
  - per-frame work or mid-play builds that cause hitches (stutter is Luke's top complaint).
- **Code:** typed calls, files under 1000 lines, `tools/lint.sh` clean. Follow AGENTS.md and `.cursor/skills/umbral-donts`.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/`
- **Live checklist:** `docs/r39/polish.md`. List every issue found, with its fix and commit.

## Report

When every listed issue is fixed:
- the commits;
- the issue list: each with its fix, and before/after shot paths;
- what's left, and why.
