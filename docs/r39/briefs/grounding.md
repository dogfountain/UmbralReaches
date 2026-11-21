# r39 brief: every object sits on the ground (the world looks finished)

**Luke, 21 Nov:** "theres so many places in these benchmarks where i see objects not flat on the ground and so on, world looks so unfinished".

**What is wrong:** props, buildings, rocks, ruins, crates, fences, signs, lamps, camp pieces, wayside places, yards, lore sites and dress.
- They float over the ground on a slope (a corner or a whole side in the air).
- They sink so a base, door or step is buried.
- They stand bolt upright on a steep slope where the base shows a gap.
- They intersect each other, or stand in a road or in water.
- Ground clutter hovers on uneven terrain.

They are placed by many systems:

| System | Where |
|---|---|
| Wayside places | `core/world/realm/realm_wayside.gd`, wayside_* |
| Lore sites | `lore/*` |
| Places of interest | `realm_pois*.gd` |
| Settlement yards | `settlement_yards*.gd` |
| Dress zones | `dress_zones.gd`, `wonders/r39/wonder_dress.gd`, `site_props.gd` |
| Camps | `core/enemy/enemy_spawner.gd` settle |
| Market and night props | `market_props.gd`, `prop_models.gd` |
| Lamps | `lamps/*` |
| Flora rocks, stumps, logs and stones | `flora_*` |
| Wonder kits | `wonders/*` |
| The towns | `reach_towns*.gd` |

The terrain is also settled under some floors (`TERRAIN_SETTLE`).

## The job

1. **Measure everything.** Write a realm-wide grounding probe.
   - **What it checks:** every placed static object's footprint against the terrain under it: the base's corners (from its AABB at the base, in its own transform) against the ground height, with rays on the terrain body only.
   - **What it reports:**
     - float (worst corner gap over ~0.08 m);
     - sink (a base, door or sill below ground by more than its bury allowance);
     - tilt need (slope under the footprint beyond what the object should stand upright on);
     - overlaps with other solids;
     - placement in roads or water.
   - **Coverage:** MultiMesh instances count, read per instance. Group the findings by placing system and kind, and sort them by how visible they are (size times gap; near roads and landmarks first).
   - **Screenshots:** shoot the worst 40 at full size from the player's height, as proof.
2. **Fix it at the source,** per placing system, not one by one. Choose per kind of object:
   - **Small props** (crates, barrels, stones, stumps, signs, clutter): sit on the lowest footprint corner and bury the rest, or align to the ground normal for things that would lie on it (logs, rocks, planks, bones). Dt-free, build-time only.
   - **Buildings and big rigid pieces:** a foundation or plinth skirt that reaches the ground on the low side (in-house, Blender-made skirt or footing pieces, as found_block.glb does at the Spire), or a local terrain pad, flattened under it. Never a visible floating edge.
   - **Fences and walls on slopes:** follow the ground per segment (stepped or sheared posts), not one straight line in the air.
   - **Rejection rules for placements** that can't be grounded well: too steep, on a road, in water. Re-place them nearby instead; don't cut them (content is thin).
3. **Re-measure** with the probe, and re-shoot the same 40 spots.

## Must keep

- Everything placed stays in the world, at about the same spot.
- **Flora placement rules don't change.** The scatter is one random stream per layer: a keep-out change reshuffles trees realm-wide. Grounding the trees, rocks and logs that already stand is fine.
- The placement cache keys everything automatically (any code edit makes the next load cold). That is expected.
- No new per-frame work. Grounding is build-time.
- **Load time:** at most +1 s on a cold build, and a warm (cached) build no slower. Cache what you compute through the existing placement cache, and report the load laps.

## Rules

- **Clone:** work only in your clone (path in your prompt), on branch `grounding`.
  - Plain commit messages, small commits. Never push; the lead merges.
  - **Commits come only from Luke: never add a Co-Authored-By line or any AI attribution.**
- **Order:** measure and shoot once at the start; build every fix with no re-measures in between; measure and shoot once at the end.
  - **Do not run any tests** (no `run_tests.sh`, no `--quick`). The lead runs the one suite after merging, and CI runs on the push.
  - Parse-check headless.
- **Godot lock:** one Godot process on the machine at a time, shared with three other agents.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` after, also on failure.
  - The lock is stale only if `pgrep -x godot` (never `-f`) shows no Godot for 60 s.
  - Give every run a watchdog: a background `sleep N; kill PID`. Kill only your own PIDs; never `pkill`; no pgrep wait loops.
  - **Keep every run to a few minutes:** others are waiting. Don't use test scenes as tools.
  - Blender uses `/tmp/umbral_blender.lock` the same way.
- **Other agents' areas:** the Ossuary (`world/areas/ossuary/*`), the Ashen Rift and Crossing (`core/world/realm/rift/*`, `realm_rift.gd`, `lava_works.gd`) and the loading screen are being redesigned by other agents. Stay out of those files. Report findings there instead.
- **Never:**
  - dynamic resolution;
  - rebaking `world/main.tscn`;
  - new shadowed lights;
  - cutting content;
  - non-in-house assets.
- **Code:** typed calls, files under 1000 lines, `tools/lint.sh` clean.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/grounding/`
- **Live checklist:** `docs/r39/grounding.md`.

## Report

When done end to end:
- the commits;
- the probe's before/after counts per system and kind (float, sink, tilt, overlap, road/water) and the worst gaps;
- the 40 spots' before/after shot paths;
- the load laps;
- what's left and why.
