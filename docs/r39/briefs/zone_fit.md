# r39 brief: make everything fit the map (entrances, stairs, landmarks)

Luke, 20 Nov: "there are so many places where things don't fit into the map, like the stairs to the thorn boss, the top
of the stairs don't even connect to the boss floor. Look at all the entrances to everything, and all landmarks to
confirm they fit into the map."

The arenas grew 1.6x and the world was reshaped round them (r39); the r39 map audit (`docs/r39/map_audit.md`) judged
views, not joins. This pass checks every JOIN: where a built thing meets the ground or another built thing.

## Scope: every one of these, none skipped

1. **Boss arenas** (`core/world/boss_arena.gd`, `core/world/realm/realm_bosses.gd`, the arena builders): the Thornwarden
   first (its stair's top does not meet the arena floor), then every other boss: the approach, every stair or ramp
   from bottom step to the floor, the gate, the floor's edge against the ground.
2. **Every entrance**: dungeon and crypt doors (Ossuary, the barrows, the Lower Count, the secrets' crypts and cists),
   building doors (Hearthward, the reach towns, outposts, chapels, the tavern), cave mouths, gates, postern and
   shortcut stairs, bridges' two ends, ladders, lifts. A door's sill meets the ground or its steps; the way in is
   walkable; nothing blocks it.
3. **Every landmark and wonder** (`core/world/realm/wonders/*`, `realm_pois*.gd`, `lore/*`, `doubled_realm_places.gd`,
   the Far Reaches' towns and vistas): its base sits in the ground (no floating plinth, no buried door, no gap
   showing under a wall, no slope cutting through a floor), its stairs and paths join the roads.

## What counts as broken

- A stair, ramp or path whose end is more than ~0.15 m above or below what it should join, or leaves a gap a player
  can see or fall into.
- A floor, plinth or wall base floating over the ground or buried so a door or step is under the soil.
- An entrance the player can't walk in through (blocked by a tree, rock, wall, collision, or too steep).
- Collision that does not match the mesh (invisible steps, walking through a wall, falling through a stair).
- A road that ends short of the thing it leads to, or runs into a wall.

## How

- **Measure, don't eyeball:** for each join, read the built geometry and the ground height (raycasts / `RealmLand`
  height) at the join and print the gap. Write a probe that lists every entrance, stair top/bottom and base in the
  Realm with its gap, and sort by worst. Then look at the worst with screenshots (`tools/map_audit.sh --section=spots
  --spot=name:x,y,z`), at full size, from the player's height and from the side.
- **Walk it:** for every stair and entrance, a headless walk (the bake's walker in `zz/realm_walks.gd` or a short probe)
  from the road up/in to the floor/inside. A snag or fall is a failure. The bake already snags at the henge stair foot
  (-31, 4) leg 3: fix that too.
- **Fix the cause, not the symptom:** if the ground was reshaped under a fixed stair, either fit the stair to the ground
  (length, step count, landing) or flatten the ground pad round it; whichever keeps the design. Keep each fix local:
  the flora scatter is one random stream per layer, so a keep-out change reshuffles trees realm-wide. Prefer fixing the
  structure or a local ground pad over keep-outs; where a designed spot needs trees cleared, clear only its own.
- **Keep the design:** fit, don't remove. No cut content, no moved bosses or landmarks unless one truly can't fit
  where it is (say so in the report).

## Rules

- **Clone:** work only in your clone (path in your prompt), on branch `zone-fit`. Plain commit messages, small
  commits; never push; the lead merges. **Commits come only from Luke: never add a Co-Authored-By line or any AI
  attribution.**
- **Build every fix first, then check once.** Probing and screenshots to FIND problems at the start are the audit; after
  that, fix everything with no re-shoots in between. At the end: the gap probe and the walks once, and one re-shoot of
  the fixed spots. **Do not run any tests** (no `run_tests.sh`, no `--quick`): the lead runs the one suite after
  merging. Parse-check headless so it loads.
- **Godot lock:** one Godot process on the machine at a time; another agent (the fps pass) shares it.
  - `mkdir /tmp/umbral_godot.lock` before every Godot run (retry every 30 s); `rmdir` after, also on failure.
    `tools/map_audit.sh` already does this.
  - Stale only if `pgrep -x godot` (never `pgrep -f`) shows no Godot for 60 s.
  - Watchdog every run (`sleep N; kill PID` in the background; macOS has no `timeout`). Kill only your own PIDs, never
    `pkill`; never wait with a pgrep loop. Keep runs short so the other agent gets turns.
  - Parse-check headless before any windowed run; windowed runs use `--always-on-top`.
- **Placement cache:** any edit under core/world, core/life or core/enemy makes the next load cold (~25-50 s).
- **Never:** dynamic resolution; rebake `world/main.tscn`; cut content; new shadowed lights; non-in-house assets.
  New or reshaped models (a stair, a plinth) are authored in Blender with a render review (`.cursor/skills/umbral-blender`;
  `/tmp/umbral_blender.lock`, same rules) unless the piece is already code-built ground or kit geometry.
- **Frame stutter is Luke's top complaint:** add no per-frame work and no mid-play builds.
- **Code:** typed calls (no `.call("x")`/`has_method`), files under 1000 lines, `tools/lint.sh` clean.
- **Scratch:** `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/zone_fit/`.
  Delete what you don't need.
- Live checklist: `docs/r39/zone_fit.md`: every join checked, its gap before and after, its fix.

## Report

When every join in scope is fixed and re-checked: branch and commits; the gap table (worst first, before -> after);
the walks (snags before -> after); the fixed spots' shots (paths); anything left and why.
