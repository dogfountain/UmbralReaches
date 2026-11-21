# r39 brief: camps and villages look designed and finished

**Luke, 21 Nov:** "the world is unpolished, so many map pieces just have objects randomly placed" ... "The biggest thing is you need to fix camps and villages".

Master is e3be9ed2. The map audit's verdicts are in `docs/r39/grounding.md`, and its shot tool is `zz/ground_shots.gd` (`--places=`, `--place-ids=`).

## Scope

**Every enemy camp and every village/town:**
- Hearthward;
- Reedholm, Fallowmere, Lastlight;
- the outposts;
- the Weirford, Saltmarket, Holds and other settlements;
- every camp in `EnemySpawner.REALM_CAMPS` and the encounter posts.

## The job

1. **See them properly.**
   - **Light the shots:** the audit's night shots were too dark to judge. Shoot with a review light rig, a bright fill light added only in the shot tool, never in the game. Also take one normal night shot per place, to judge the real mood.
   - **Views per place:** player height on the main approach, 3/4 from two sides, one inside the centre, and one high.
   - **Camera rules:** no cameras in grass or walls (ray-check and push out).
2. **Critique each one brutally,** as a level designer, against the Enshrouded build style and Luke's dark night with bright landmarks.
   - **Does it read as a designed place,** with a purpose?
     - A camp has a fire as its heart, sleeping spots, a lookout, loot, a reason to be where it is, and a path in.
     - A village has a centre, streets, yards with work going on, and lights.
   - **What's wrong with it:**
     - random scatter;
     - props floating, sunk, clipping or inside other things;
     - empty plinths, box stand-ins, flat boards, missing textures, gaps;
     - fences that don't close or follow the ground;
     - paths blocked;
     - things facing nothing.

   Write one line per place in `docs/r39/camps_villages_look.md`.
3. **Fix them all.** Build each camp and town as a designed scene:
   - **Fix the placement rules** that make the scatter, so it composes everywhere, not one place at a time:
     - props cluster round their purpose and face it;
     - tents and bedrolls round the fire;
     - stalls along the street;
     - yards behind houses.
   - **Ground every prop** using the merged GroundSeat and FinalSeat.
   - **Fill the gaps** with in-house props and Blender-authored ones (render review) where a scene needs one: a camp's lookout, a palisade, a weapon rack, a cooking spit, a cart.
   - **Lights:** each camp and village reads at night from afar (a fire, lanterns, lit windows), with no new shadowed lights.
   - Also fix the floating lit barrel near the Almonry at Hearthward east (~(26, 37)). Its owner is unknown: find it.
4. **Re-shoot only the changed places, once,** with the same lit views plus the night view. Show before/after pairs, and look at every shot.

## Must keep

- Every camp's spawn slots, seals, patrols and loot.
- Every villager routine's anchors and nav (`village_reach_towns.gd` NODES/EDGES, `village_cast.gd`). A prop must never stand on a villager's walk or a door's approach.
- The quests that point at these places.
- **No per-frame cost:** another agent is optimising camps and villages at the same time. Use static merged meshes, `WorldLanes.own()` for batches you place, and visibility ranges.
- **Don't change flora keep-outs** outside the place's own footprint.

## Rules

- **Clone:** work only in your clone (path in your prompt), on branch `camps-villages-look`.
  - Plain commit messages, small commits. Never push; the lead merges.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:** shoot and critique once, then build EVERY fix with no re-shoots in between, then re-shoot once.
- **Tests:** don't run any tests (no `run_tests.sh`, no `--quick`, no test scenes as tools). The lead runs the one suite after merging. Parse-check headless.
- **Godot lock:** one Godot process on the machine at a time, shared with the other agents.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` after, also on failure.
  - The lock is stale only if `pgrep -x godot` (never `-f`) shows no Godot for 60 s.
  - Give every run a watchdog: a background `sleep N; kill PID`. Kill only your own PIDs, never `pkill`. No pgrep wait loops.
  - Windowed runs: parse-check first, then `--always-on-top`, and watch the first 60 s of the log for errors.
  - Cap every log at about 20 MB.
- **Blender:** use `/tmp/umbral_blender.lock` the same way.
- **Stay out of:**
  - the Ashen Rift files (another agent);
  - perf code: the encounters director's tick, villager LOD, `light_director` caps (the perf agent owns them).
- **Never:**
  - dynamic resolution;
  - rebaking `world/main.tscn`;
  - cutting content;
  - new shadowed lights.
- **Code:** typed calls, files under 1000 lines, `tools/lint.sh` clean.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/camps_look/`
- **Live checklist:** `docs/r39/camps_villages_look.md`.

## Report

- The commits.
- The per-place critique table: place, what was wrong, what you changed.
- The before/after pairs (paths).
- New models made.
- What's left, and why.
