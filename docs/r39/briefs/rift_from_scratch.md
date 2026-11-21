# r39 brief: the Ashen Rift, from scratch (the lava pit and the climb to the summit)

**Luke, 21 Nov, after seeing the first redesign:**
> "Do the materials match the rest of the game, make the platforms lower, and why is it half water half lava?? Or please redesign it from scratch, this is literally just a location change with minor adjustments."

The first attempt (now in master: `core/world/realm/rift/crossing.gd` + `art/models/crossing.glb`, `rift/pit.gd`) kept the old idea. It is the same towers and Spindle in the same places, a starwater pool beside a lava pit, and tall pier platforms. That is rejected.

**Start from a blank page.** You may throw away:
- `crossing.glb` and the Crossing's layout;
- the Spindle stack;
- the third tower;
- the starwater pool;
- the pit's shape.

## Fixed (everything else is yours to redesign)

- **The two ends:**
  - the route starts on the rift's south rim at `RealmLayout.CROSSING_FOOT`, where the rim road arrives;
  - it ends at the summit ward landing, `RealmLayout.SUMMIT_WARD`, top y 25.2. The summit's own approach stairs start there.
- **The rift's region on the map:** don't push into the Ossuary's ground, the village side's fields, or the summit.
- **Content that must survive:** it may move, and may be reshaped to fit the new concept.
  - **The Pilgrims' Chapel and its secret** (`rift/chapel.gd`, `core/life/secrets/site_threshold.gd`). It can be rebuilt in a new spot with its secret intact, as long as the quest and secret texts still read true. Update them if the place changes.
  - **The two Watcher statues** (`art/models/wonders/watchers_*.glb`).
  - **The seal-guard camp.**
  - **Any quest or lore that points into the rift.** Grep for crossing, threshold, rift, spindle, watchers, starwater, chapel and pilgrim, and update every text and pin that names something you change.
- **What other systems read:**
  - `lava_works.gd` (the lava sheet, its bank mask, the kill volume and burn);
  - the light grid;
  - `WorldLanes` registrations;
  - the minimap lines;
  - the walk-test points in `zz/realm_rift_walk.gd` and `zz/threshold_walk_test.gd`.

  Rebuild these to match the new design. Don't break them.

## The design asks

1. **One element: the whole rift is lava. No starwater.**
   - The Ashen Rift is a lava rift. Half water, half lava made no sense to Luke.
   - Luke's 9 Nov concern was lava too close to the village. Answer it with a cooling gradient: toward the south, village end the lava is crusted black and dim, with only thin glowing seams. The molten, bright heart is deep in the rift, toward the summit.
   - The Watchers stand on basalt in it.
2. **A real lava pit, designed:**
   - a big, believable basin with a source (a lavafall from the summit's cliff, or a vent);
   - flows and channels, a molten lake, and crust plates;
   - basalt shelves and islands that read as natural rock, not cubes;
   - heat shimmer over the hot heart.
3. **A climb that makes sense, low over the lava:**
   - the route stays low: causeways, ledges and bridges just above the crust and the flows, not platforms on tall piers;
   - it climbs to the summit late, up the cliff: switchback flights cut into the rock face, or a stair built against it;
   - one clear line you can read from the rim, with landings that rest and look out;
   - a branch to the chapel.

   Metrics: rise <= STEP_MAX, ramps <= 21 deg, clear width >= 3.5 m, parapets where it is exposed.
4. **Materials that match the rest of the game.**
   - Use the stone, rock and kit materials the rest of the Realm already uses. Read what the Hearthward walls, the reach towns, the henge, the Ossuary and the rift's own cliffs use, and use those same textures and materials (OssKit materials, RockKit, `art/materials/*`, the realm stone).
   - No new custom tints that make it look like another game.
   - Put a side-by-side shot of your stone next to Hearthward's and the henge's in the plan.
5. **Build style:** Enshrouded's chunky handcrafted build style; dark night with bright landmarks (fires at landings read from the rim).
   - Every new model is authored in Blender with a render review (`.cursor/skills/umbral-blender`, `/tmp/umbral_blender.lock`).
   - No code-built box art.
   - Basalt is modelled or sculpted, not stacked cubes.

## How

1. **Look at the whole rift as it is now,** with full-size shots from the rim, the air and lava level. Read why each part fails against Luke's words.
2. **Write the concept in `docs/r39/rift_from_scratch.md` before building:**
   - a top-down plan sketch with heights;
   - the lava's hot-to-cool layout;
   - the route line;
   - where the chapel, the Watchers and the camp go;
   - the material list with the side-by-side shot.

   It must be visibly a new design, not the old one moved.
3. **Build everything.**
4. **Walk it with the real Player:**
   - rim to the summit ward landing;
   - the chapel branch;
   - falling into the lava kills and respawns as it does today.
5. **Re-shoot once** (rim, every landing, air, lava level) and look at every shot yourself.

## Rules

- **Clone:** work only in your clone (path in your prompt), on branch `rift-redesign`.
  - Plain commit messages, small commits. Never push; the lead merges.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:** look, plan, build EVERYTHING (no re-shoots in between), walk and re-shoot once.
  - **Do not run any tests**, and don't use test scenes as tools. The lead runs the one suite after merging, and CI runs on the push.
  - Parse-check headless.
- **Godot lock:** one Godot process on the machine at a time, shared with three other agents.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` after, also on failure.
  - Stale only if `pgrep -x godot` (never `-f`) shows no Godot for 60 s.
  - Give every run a watchdog: a background `sleep N; kill PID`. Keep each run to a few minutes.
  - Kill only your own PIDs; never `pkill`; no pgrep wait loops.
  - Blender uses `/tmp/umbral_blender.lock` the same way.
- **Stay out of** the Ossuary files (another agent is redesigning it) and the loading screen.
- **Never:**
  - dynamic resolution;
  - rebaking `world/main.tscn`;
  - new shadowed lights;
  - per-frame work or hitches. Merge static pieces, and keep static MultiMeshes off physics interpolation.
- **Flora:** don't change keep-outs outside the rift.
- **Code:** typed calls, files under 1000 lines, `tools/lint.sh` clean.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/rift/`.
- **Live checklist:** `docs/r39/rift_from_scratch.md`.

## Report

- The commits.
- The concept in a few lines.
- Before/after shot paths: rim, landings, air, lava level, and the material side-by-side.
- Walk results.
- Every quest or lore text you changed.
- What's left, and why.
