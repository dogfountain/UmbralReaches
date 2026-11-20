# r39 brief: the horse is janky — make riding smooth

Luke, 20 Nov: "Horse is janky."

**The code:** `core/world/mount/`, about 2,900 lines:
- `horse.gd` (the mount);
- `horse_move.gd` (motion);
- `horse_rig.gd` (skin and animation);
- `horse_bond.gd`, `stables.gd`, `courier.gd`, `horse_race*.gd`.

**Tools:**
- `zz/horse_studio`, `zz/horse_seq` (sequence strips);
- `zz/horse_slide_test`, `horse_course_test`, `horse_walls_test`;
- `zz/combat_strip` as the pattern for frame strips.

## Find every source of jank, then fix them all

Watch a ride before judging. Make frame strips (every frame, or every 2nd, at 60+ fps) of these, from the follow camera at full size:
- mount and dismount;
- walk -> trot -> canter -> gallop and back down;
- sharp turns at each gait;
- stopping hard;
- slopes up and down, steps and kerbs;
- roads, bridges and town streets;
- colliding with a wall, a tree or a fence;
- riding through water;
- the camera at each gait;
- the rider on the saddle.

Look for, and print numbers for:
- **pops and snaps:** animation blend jumps, gait changes without a crossfade, the root or hooves teleporting;
- **foot sliding:** hoof speed vs ground speed, per gait;
- **stepping:** anything updated at a low rate and not interpolated (physics vs render, ground-follow rays, IK);
- **jitter:**
  - body pitch and roll on uneven ground, not smoothed;
  - the camera fighting the horse's motion;
  - the rider not locked to the saddle bone;
- **turning:** turning that's instant, or a body that snaps to the velocity's facing;
- **collision:** stuck on small edges, bouncing on stairs, sinking into or floating over the ground;
- **mount and dismount:** popping into place.

**Fix the causes** following `animation-smoothing` and `umbral-player` (`.cursor/skills/umbral-player`):
- dt-damped blends;
- velocity-driven gait blend with matched stride speeds;
- smoothed ground normal and height;
- render-side interpolation of physics motion;
- a camera follow that's critically damped;
- a rider bound to the saddle every frame after the horse pose.

Riding must feel weighty and smooth, like a good open-world RPG mount, not floaty and not twitchy.

## Rules

- **Clone:** work only in your clone, on branch `horse-feel`. Plain commit messages, small commits; never push. **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:** diagnose first, with strips and numbers. Then build EVERY fix with no re-captures in between. Then capture the same strips once at the end and compare before/after.
  - **Do not run any tests** (no `run_tests.sh`, no `--quick`). The lead runs the one suite after merging.
  - Parse-check headless so it loads.
- **Godot lock:** one Godot process on the machine at a time, shared with other agents.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run, retrying every 30 s. `rmdir` it after, also on failure.
  - The lock is stale only if `pgrep -x godot` (never `-f`) has shown no Godot for 60 s.
  - Watchdog every run: background `sleep N; kill PID`.
  - Kill only your own PIDs, never `pkill`. No pgrep wait loops.
  - Windowed runs: parse-check headless first, then use `--always-on-top`. Keep runs short.
- **Blender:** the horse model stays. If an animation clip itself is broken (bad loop, foot plant), fix it in Blender with a render review, under `/tmp/umbral_blender.lock` (same rules).
- **Never:**
  - per-frame work that costs a hitch (frame stutter is Luke's top complaint);
  - dynamic resolution;
  - rebaking `world/main.tscn`;
  - cutting content.
- **Code:** typed calls, files under 1000 lines, `tools/lint.sh` clean.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/horse_feel/`
- **Live checklist:** `docs/r39/horse_feel.md`.

## Report

When done end to end:
- the commits;
- every jank found: its cause, its fix, and its before -> after numbers;
- the strip paths (before and after);
- anything left, and why.
