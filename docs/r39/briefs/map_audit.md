# r39 brief: audit the entire map with screenshots, everywhere, then fix it

Luke, 18 Nov: "spawn an opus 5.5 extra agent, to audit the entire maps using screenshots everywhere, and I mean
everywhere, then it must be fixed. The critique must be brutal."

You are that agent. You own the look and the soundness of the whole Realm (740 x 548 m, `RealmLayout.BOUNDS`
x -370..370, z -150..398) and the interiors you can reach (the Ossuary and its pit hall, the deep halls, the caves, the
summit platform, every town). Read this brief end to end, then `AGENTS.md`, `docs/PILLARS.md`, `docs/r37_expansion.md`,
`docs/far_reaches.md`, `.cursor/skills/umbral-donts` and the last fifty rows of `docs/DECISIONS.md`. Keep a live checklist
at `docs/r39/map_audit.md` (every finding, its location, a screenshot path, its fix and the commit); it is how the lead
resumes you if your context runs out. This should take you many hours. Do not report until every finding is fixed or
plainly marked as not fixable with the reason.

## What changed just before you (so you know what is fresh)

The five boss arenas grew 1.6x today and the world was reshaped round them (DECISIONS.md, 18 Nov): the Thorn Henge's
floor is 49.6 m with its stair, guards, camps, the Glimmer Glade, the Rooted Holds (31 m west), Wyck, Ione, the cist,
the Hollow Oak and west_track moved; the Speaking Crown's fight is its skull plus the siege yard; the summit deck and the
Anchoress's terrace are ellipses along the world's north edge; the Bone Abbot's pit hall is 1.6x and moved off the Well.
These areas need your eye most. Also note: the forest scatter is one random stream per layer, so any keep-out change
reshuffles trees across the whole Realm; designed spots must clear their own trees rather than rely on luck.

## Where you work

- Your own APFS clone, already on your branch: `/Users/luke/UmbralReaches_map_audit` (branch `map-audit`). Work only
  there (`cd` into it for every command). Commit on your branch with plain messages; do not push; the lead merges.
- The Godot import cache is in it. Godot 4.7.2: `godot`. Blender: `/opt/homebrew/bin/blender`.

## How to see everything

"Everywhere" means everywhere. Build a capture harness (a new `zz/map_audit_shots.gd` + `.tscn`, modelled on
`zz/play_capture.gd` and `zz/perf_tour.gd`, which already build the real night, hold the save and frame stills) that:
1. walks a grid over the whole of BOUNDS every 40 m (about 250 points): at each, an eye-level shot in four directions
   (1.7 m up, the player's FOV 90) and one oblique shot from 25 m up looking down at 45 degrees;
2. visits every named place: every `RealmLayout.REGIONS` entry, every `SLOTS` entry, every POI (`group poi`), every
   landmark and wonder (r39 wonders, Titan Gates, towers, bridges), every town and outpost, every boss arena (floor,
   gate, approach), every fire, every secret site, the lore stones, the roads' ends and junctions, the March Wall's gates;
   at each, four eye-level views and one aerial;
3. goes inside every interior (the Ossuary's tiers, the Counting Stair, the pit hall, the deep halls, caves, houses you
   can enter, the Keg) and shoots each room;
4. shoots at night with the game's own grade (the real look), and once more with the debug lamp only where the night
   hides a problem;
5. writes a contact sheet per region (`<scratch>/map_audit/<region>/sheet.png`) and an index.
Use the existing tooling first (`tools/play_capture.sh` sections `regions_a regions_b places spots`, the
`zz/*_shots` scenes); write the grid harness yourself. Read EVERY image with the Read tool at full size. Do not sample.

## The critique: brutal, by role

Write it into `docs/r39/map_audit.md` before fixing anything, as each of: creative director, level designer,
environment artist, lighting artist, tech artist, technical QA, and player. Be specific: a location, what is wrong, why
it matters, what good looks like. Nothing is "fine". Look for at least:
- **Broken:** floating or sunk props, buildings and trees; things intersecting each other or the terrain; holes in the
  ground; z-fighting; stretched or missing textures; objects inside walls; roads that run through buildings, rocks or
  water; doors blocked; stairs that cannot be climbed; ladders into nothing; lights hanging in mid-air; invisible walls
  where there should be none and none where there should be one; seams at terrain tiles; LOD pops visible from the road.
- **Placement:** clutter that reads as random; empty stretches with nothing to look at for 100 m; landmarks hidden from
  the roads that should frame them; camps, fires and NPCs on slopes or in each other; repeated props in obvious copies;
  the moved places today (Glade, Holds, cist, oak, camps, Titan wardens on west_way) settled into their new ground.
- **Composition and readability:** can you tell where you are and where to go from every road junction; do landmarks
  read on the skyline ("dark night, bright landmarks": fires, windows and mystery lights at landmarks read from afar);
  does each region look like its own place (biome, palette, architecture); are the boss arenas readable as arenas.
- **Craft:** models that look code-built, boxy, low-effort or out of the villagers' style (Luke: every model is to be
  authored in Blender; flag them all with a location even where you cannot rebuild them in this round).
- **Lighting:** too dark to read, blown out, flat, wrong colour, lights without a source, sources without light.

## Fixing it

Then fix every finding, worst first, end to end. You may edit world placement, layout tables, POI builders, dressing,
lighting placement, terrain shaping and the arenas' surroundings. Every fix is verified by a new screenshot of the same
spot, read at full size, before you tick it. Keep the rules:
- Zero perf cost: no new shadowed lights, lights inside each region's budget (`zz/lamps_test`: 14 in any 40 m disc),
  MultiMesh for repeats, nothing that hitches on first use. Frame stutter is Luke's top complaint.
- Never cut content (Luke: the game is thin already): move it, mend it, or make it better.
- In-house assets only. Dynamic resolution stays off. Never rebake `world/main.tscn`.
- Tests: Luke's standing rule (18 Nov): do not run the test suite or test batches while you build. Shoot, critique and
  fix every region first (screenshots are how you see, so re-shoot the fixed spots); only when every fix is in, run the
  tests once (`tools/run_tests.sh --quick`, then the world tests that cover what you touched: `layout_r34_test
  placement_test places_r34_test enemies_r34_test secrets_test village_test lamps_test nav_reach_test raids_r34_test`)
  and fix what they find. A designed spot that a move broke is fixed properly (it clears its own trees, a slot moves with
  its place), never by loosening a test without saying why in the commit. `tools/lint.sh` (seconds) any time.

## Machine rules

- One Godot and one Blender process on the machine at a time, shared with the lead: take `mkdir /tmp/umbral_godot.lock`
  (retry every 30 s while it exists) around every Godot run and `/tmp/umbral_blender.lock` around every Blender run,
  `rmdir` it when the run ends, also on failure. Never wait with a pgrep loop.
- Scratch in `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/map_audit/`;
  the full grid is thousands of images: keep the contact sheets and the before/after pairs of fixed spots, delete the
  rest as each region is done (the disk filled once).
- Commits come only from Luke: never add a `Co-Authored-By` line or any AI attribution.

## Report

Only when the checklist is done: your branch and commits, how many spots you shot, the critique's headline findings,
what you fixed (with before/after sheet paths), what you could not fix and why, tests run and their results.
