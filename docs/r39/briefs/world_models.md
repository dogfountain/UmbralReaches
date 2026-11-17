# r39 brief: the world, its models, its landmarks and the compass

The owner (Luke) asked for this round in his own words:
- "Massive new props and models… crazy features that make a person feel immersed… in depth and end to end 100%".
- "Increase model detail at no perf cost, like the Enshrouded world".
- "The compass… displays too much info… it shows too many fires".
- "Improve the models of all the new models… more in depth… and improve the world".
- "The deeper models shouldn't just be for what was created now, this should be game wide".
- "Why are all agents done so soon… this should take 10 hours".
- "Make at least 1000 word docs for each agent".

This brief is your full spec. Read it end to end, then work through it in order. Keep docs/r39/world_backlog.md as your live checklist; it is how the lead resumes you if your context runs out.

## Who you are and what you own

You are the environment art director and world builder of Umbral Reaches, a Godot 4.7.2 Forward+ open-world night RPG. The Realm is 740 x 548 m.

You own:
- realm geography, terrain, roads' surroundings, POIs and landmarks (core/world/realm/ and the r39 wonders);
- props and their models (prop_models.gd, dressed props, OssKit);
- flora and trees (tree_gen.gd, flora/);
- world shaders and materials;
- water and far views;
- the compass feed (ui/compass_feed.gd, ui/compass.gd);
- the mesh-building functions of villagers, tavern dwarves, enemies' procedural bodies and the five bosses.

Those last are now free: the animation agent has finished. Never touch posing or animation functions.

You do NOT edit:
- global lighting (atmosphere, light_director, light_policy, the grade) or the far-beacon system (the light seat);
- quests, dialogue or lore (the story seat);
- the opening, HUD layout beyond the compass, or the map (the opening seat).

You do own the light-bearing geometry of your own landmarks: fires, glass and emissive parts.

## The bar

The style is the game's own: chunky, readable, procedural forms (DwarfMesh/VMesh primitives and OssKit), richly layered materials, Enshrouded as the reference for density and craft. Detail comes from:
- secondary and tertiary forms: trim, ornament, damage, wear, ropes, chains, moss, debris, carving, interior dressing;
- baked vertex-colour and material variation;
- not from runtime cost.

Every model family you touch must look clearly richer at 5 m and read better at 50 m. The bar:

1. **Volume and variety.** Many variants per prop family, chosen by seed, so nothing repeats in a row. Every region dressed so no two look alike.
2. **End to end.** Collision and footing on everything you can walk on, navigation kept clear, roads, towns and quests never blocked, LOD and visibility ranges, materials and lights fixtures, and rewards where promised. Everything is built at Realm build time through the existing builders and GenCache.
3. **Performance.**
   - No runtime hitches: frame stutter is Luke's top complaint.
   - Triangle budgets kept: write the cost per landmark in the doc.
   - MultiMesh for repeats, visibility ranges like the existing code, nothing allocated per frame.
   - Never dynamic resolution, and never a headless rebake of main.tscn.
4. **Documentation.** docs/r39/world_landmarks.md gets, for each item: what it is, coordinates, how it reads from afar, its cost, its files and what to check.

## Workflow

- Work in /Users/luke/UmbralReaches/.claude/worktrees/r39-world2. Run `git merge master` now and before each big item.
- Do not run Godot or the tests; the lead does. Run tools/lint.sh after every item and fix what it flags. The ratchet fails on new `.call(`, `has_method`, private gets and any file over 1000 lines, so split into new files.
- Commit after each item. Never add Co-Authored-By or AI attribution, never write "claude" anywhere.
- Do not send a final report until every item below is done to the bar. When the list runs out, take the next most valuable item from docs/r39/3_world_models_textures.md and keep going.

## Part A: finish the current work

### A1. The compass

Feed the player's own marks into the compass (master: core/story/wayfarer.gd, Wayfarer.WayMark with anchor and tint). They should fade and merge like the rest. Make the settings row resync after "Reset to Defaults". Check it does not overlap the quest trail. Write docs/r39/compass.md.

### A2. The game-wide model pass, every family, prioritised by what the player sees most

1. **Villagers and tavern dwarves:**
   - layered clothing edges, stitching and patches;
   - belts, pouches and tools;
   - wear;
   - better hands and faces where they read poorly.
2. **Hearthward and the towns:**
   - cottages, with roof overhangs, ridges, chimneys and moss;
   - doors and windows, with frames, shutters and sills;
   - market stalls, fences, wells and carts.
3. **The Ossuary kit and ruins:** broken edges, fallen blocks, carved detail and tone patchwork everywhere they are used.
4. **Common enemies' procedural bodies:** secondary forms that read in combat.
5. **The Bone Abbot:** bring it to match the other four bosses' new ornament.
6. **Trees and flora:** bark detail, roots, deadwood, undergrowth variety, and the far-leaf dither left for the light seat.
7. **Rocks and cliffs:** faceted silhouettes, strata, lichen.
8. **Water edges:** shore rocks, reeds, wet bands.
9. **Far views:** landmark silhouettes, the horizon and the mountains.

## Part B: the world backlog

### B1. The four dungeon doors as real interiors

The King's Barrow, the castellum, the witch's door and the Drowned Nave each become a multi-room explorable interior:
- traversal;
- set dressing;
- light fixtures;
- a reward room;
- a hook the story seat can hang its payoff on.

### B2. Caves and grottos

Six or more off the road, each with an interior, crystals or roots, water, and a find inside.

### B3. Regional signature

Each region gets its own set piece and dressing pass, covering props, flora, ground and ruins, so no two regions look alike.

### B4. Lived-in settlements

Hearthward and the Reach towns get backyards, workshops, gardens, laundry lines, animal pens, graveyards and market clutter.

### B5. Water

Streams with banks, bridges and fords, waterfalls, mills, and docks at the salt pans and the fen.

### B6. Verticality

Climbable ruins, towers and cliff paths to views and secrets.

### B7. Far views

Every landmark's silhouette reads from a distance, with horizon detail.

### B8. The ground

A litter layer, paths worn into the grass, tracks and puddles.

### B9. Exploration rewards

Thirty or more hidden finds across the map, each with environmental clues leading to it.

### B10. Boss-scale architecture

Build it around each arena's approach, so the 7.6-8.8 m bosses are foreshadowed by the scale of their places.

### B11 onward

Then work down your critique.

## What the lead will verify

The lead merges your branch, imports it, runs the full suite and the land-cache rebuild, reads the WONDER log lines for coordinates, and captures each landmark and family at 5 m and 50 m at night. It compares frame time against the regions_a numbers (about 8.5 ms average). Put coordinates and the exact things to check in your doc.

Anything that cannot be found from the doc, or that costs a hitch, is sent back.
