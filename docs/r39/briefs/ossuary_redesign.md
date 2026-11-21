# r39 brief: redesign the Ossuary

**Luke, 21 Nov:** "the ossuary makes no sense and has no presence". This is a complete redesign: no touch-up.

**What it is today** (`world/areas/ossuary/*`: `ossuary.gd`, `oss_frame.gd`, `oss_hall.gd`, `oss_deep.gd`, `oss_lift.gd`, `oss_pool.gd`, `oss_world.gd`, `oss_kit.gd`): a candlelit burial monastery stepping down the wall of a quarried bone pit, cut into the Waiting Field's south slope. The route runs:
1. the Pilgrims' Landing;
2. a bone bridge over a dark pool;
3. the gate hall (bell tower);
4. a north stair to the niche gallery;
5. a north stair to the charnel pit;
6. the chapel, with the Lower Count under it;
7. the Counting Door;
8. the Counting Stair (eight flights down);
9. the Pit Hall, the Bone Abbot's raid room, under the Southern Downs.

## The job

**Presence.** The Ossuary is a landmark. From the field and the roads round it, it must read at a distance as a great charnel monastery:
- a silhouette on the skyline: bell tower, buttresses, a lantern-lit facade over the pit;
- warm windows and candle glow, so it reads at night from afar (dark night, bright landmarks);
- an approach that builds anticipation.

**Sense.** Inside, the route reads at a glance:
- each tier has a purpose and a view of the next;
- the descent is one legible spine (gate hall, gallery, charnel, chapel, the deep, the Abbot);
- stairs land flush and lead somewhere visible;
- no dead ends that mean nothing, and no "where now?".

Its architecture follows a logic: piers carry tiers, arches span, ossuary niches line real walls, the pool sits at the bottom of a quarried pit.

**Keep (fit, don't cut):**
- **Content:**
  - the Bone Abbot's raid room and its fight;
  - the Lower Count secrets;
  - the counterweight lift;
  - the Sexton;
  - the Counting Door's puzzle;
  - the chests, the quests that point here and the seals.
- **What other systems read:**
  - `OssFrame` (the area's world frame; remember it is a quarter turn, `OssFrame.YAW`);
  - `RealmLayout.oss_pit_shape`;
  - the Landing's world point;
  - WorldLanes registrations;
  - the walk-test points;
  - the secrets' site registrations.
- **The room's coordinates:** the Abbot's arena may move only if the boss arena, its seal and the tests move with it.

**Build style:** Enshrouded's chunky handcrafted build style, with Luke's dark night and bright landmarks.
- Every new or reshaped model is authored in Blender with a render review (`.cursor/skills/umbral-blender`, `/tmp/umbral_blender.lock`).
- No code-built box art.

## How

1. **Critique first, brutally.** Shoot the Ossuary at full size: from the field and the roads (100-300 m), from the Landing, and from each tier at player height, going down and coming up. Also shoot from the air and inside the Pit Hall.
2. **Plan before building**, in `docs/r39/ossuary_redesign.md`:
   - the silhouette;
   - the route spine with heights;
   - each tier's purpose and view;
   - what moves and what stays.
3. **Build every piece** with no re-shoots in between.
4. **Walk it with the real Player:** from the Landing to the Pit Hall, and every branch (the Lower Count, the lift). No snags, no falls through, no blocked doors.
5. **Re-shoot once** and look at every shot yourself.

## Rules

- **Clone:** work only in your clone (path in your prompt), on branch `ossuary-redesign`.
  - Plain commit messages, small commits. Never push; the lead merges.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Do not run any tests** (no `run_tests.sh`, no `--quick`). The lead runs the one suite after merging, and CI runs on the push.
- **Parse-check** headless so it loads.
- **Godot lock:** one Godot process on the machine at a time, shared with two other agents (shader-warm, crossing-redesign).
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` after, also on failure.
  - The lock is stale only if `pgrep -x godot` (never `pgrep -f`) shows no Godot for 60 s.
  - Watchdog every run with a background `sleep N; kill PID`.
  - Kill only your own PIDs. Never `pkill`; no pgrep wait loops.
  - Windowed runs: parse-check headless first, then use `--always-on-top`.
  - Keep runs short.
- **Never:**
  - dynamic resolution;
  - rebaking `world/main.tscn`;
  - new shadowed lights;
  - cut content;
  - per-frame work or mid-play builds that hitch (stutter is Luke's top complaint). Merge static pieces, and keep static MultiMeshes off physics interpolation.
- **Flora:** don't change keep-outs elsewhere.
- **Code:** typed calls, files under 1000 lines, `tools/lint.sh` clean.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/ossuary/`.
- **Live checklist:** `docs/r39/ossuary_redesign.md`.

## Report

When the new Ossuary is built, walked and re-shot, report:
- the commits;
- the critique list, each item with how the redesign answers it;
- before/after shot paths (far views, the Landing, each tier, the Pit Hall, the air);
- walk results;
- what's left, and why.
