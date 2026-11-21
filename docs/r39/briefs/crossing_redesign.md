# r39 brief: redesign the Crossing, the stairway over the lava

**Luke, 21 Nov:** "the stairway area is so badly designed, it makes no sense", then "with the lava". That is the Ashen Rift's
Crossing (`core/world/realm/rift/crossing.gd`): the only walkable way from the rift's south rim up to the summit ward.

**The route today:**
1. forecourt and pointed gate;
2. a flight onto the first round tower;
3. an arcaded viaduct ramp out of the lava to the west tower;
4. a fallen column over the gap;
5. a flight to the Spindle;
6. one full turn round the Spindle (ramps, landings, flights on corbels and a colonnade);
7. a flying arch;
8. two flights to the ward landing.

**Joined to it:**
- the Pilgrims' Stair winding down the third tower to the starwater (`rift/tower_stair.gd`);
- the Threshold's terraces, the Watchers and the chapel (`rift/threshold.gd`, `chapel.gd`);
- the summit's approach stairs from the ward landing (`summit_dress.gd`, `endgame*.gd`).

## The job

Luke, after: "it needs a complete redesign". Not a touch-up: the current layout goes wherever it does not serve one clear climb.


**Rebuild it so a player understands it at a glance and it reads as one designed place.**
- **A single legible route:** from the rim, the player can see where they are going: the summit and the next landing. The way on is always readable.
  - No ramps that loop back on themselves without a reason.
  - No stairs that end at a wall, and no "which way now?".
  - Landings where a pilgrim would rest, with a view.
- **Architecture with a logic:** a ruined pilgrims' viaduct.
  - Piers that carry what's above them, arches spanning between them, and stairs that turn at towers.
  - Parapets that run continuous and level or stepped (no sloped-top boxes).
  - Every flight meets its landing flush. Rises and widths are consistent (Metrics: rise <= STEP_MAX, ramps <= 21 deg, clear width >= 3.5 m).
- **The lava as the drama it should be:**
  - the route crosses it on purpose: a span over the flow, a glowing underside, heat haze;
  - not stairs dumped beside it.
  - Keep the Threshold's starwater pool (no lava there, Luke's 9 Nov decision).
- **The Spindle turn:** keep it if it can be made clear, or redesign that climb (a stair tower, switchback flights on the cliff, a bridge chain), whichever reads best.
- **The Pilgrims' Stair and the Threshold** are part of the same place. They must read as a branch off the main route, with a clear junction at the third tower.
- **Build style:** Enshrouded's chunky handcrafted ruin, with a dark night and bright landmarks (fires and braziers at the landings read from the rim).
  - Every new or reshaped model (stair flights, landings, arches, parapets, piers) is authored in Blender with a render review (`.cursor/skills/umbral-blender`, `/tmp/umbral_blender.lock`).
  - No code-built box art.

## How

1. **Critique first, brutally.** Shoot the whole area at full size: from the rim, from every landing, from the player's height going up and coming down, and from the air. List every point where the route confuses, breaks or looks wrong.
2. **Write the new layout in `docs/r39/crossing_redesign.md` before building:** a plan sketch (top-down, with heights), and the route's sequence with each landing's view.
3. **Build it.**
4. **Walk it with the real Player,** from the rim to the ward landing, and down the Pilgrims' Stair to the chapel: no snags, no falls through.
5. **Re-shoot once** and look at every shot yourself.

## Must keep

- The route's start (`RealmLayout.CROSSING_FOOT`) and its end (`RealmLayout.SUMMIT_WARD`, the ward landing top 25.2) where they are, so the summit and the rim stay as they are.
- Everything the rest of the game reads:
  - the seals and gates on the route (if any);
  - quests that point at the Crossing;
  - the chapel secret (`core/life/secrets/site_threshold.gd`);
  - the lava's bank mask (`lava_works.gd`: pier feet must stay visible to it);
  - `WorldLanes` registrations;
  - the walk test points.
- Never cut content: the chapel, the Watchers and the terraces stay.
- No new per-frame work or hitches. Stutter is Luke's top complaint. Merge static pieces, and turn interpolation off on static MultiMeshes.

## Rules

- **Clone:** work only in your clone (path in your prompt), on branch `crossing-redesign`.
  - Plain commit messages, small commits. Never push; the lead merges.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:** critique and plan, then build EVERY piece with no re-shoots in between, then walk and re-shoot once.
  - **Do not run any tests** (no `run_tests.sh`, no `--quick`). The lead runs the one suite after merging.
  - Parse-check headless so it loads.
- **Godot lock:** one Godot process on the machine at a time, shared with the shader-warm agent.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` after, also on failure.
  - The lock is stale only if `pgrep -x godot` (never `-f`) shows no Godot for 60 s.
  - Watchdog every run with a background `sleep N; kill PID`. Kill only your own PIDs; never `pkill`; no pgrep wait loops.
  - Windowed runs: parse-check headless first, then use `--always-on-top`. Keep runs short.
- **Never:**
  - dynamic resolution;
  - rebaking `world/main.tscn`;
  - new shadowed lights;
  - non-in-house assets.
- **Flora:** don't change keep-outs elsewhere. A change reshuffles trees realm-wide.
- **Code:** typed calls, files under 1000 lines, `tools/lint.sh` clean.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/crossing/`.
- **Live checklist:** `docs/r39/crossing_redesign.md`.

## Report

When the new Crossing is built, walked and re-shot:
- the commits;
- the critique list, each item with how the redesign answers it;
- the before/after shot paths (rim, each landing, air);
- the walk results;
- what's left and why.
