# World, exploration and environment density: Enshrouded vs Umbral Reaches (r31)

This pass compares how the two worlds are laid out, dressed and rewarded, and borrows ideas, not
content. Every place, name, text and model below is ours (the valley's night, the Order, the
Rooted, the fen dead). Code: `core/world/realm/realm_pois.gd`, `core/world/realm/loot_chest.gd`,
the density pass in `core/world/realm/realm_flora.gd`, seven readable stones in
`core/world/realm/lore_db.gd`, hooks in `realm_bosses.gd` (reserve) and `realm_wayfinding.gd` (build).
Test: `zz/world_poi_test.tscn`. Shots: `zz/world_poi_shots.tscn`.

## What Enshrouded does (research summary)

- **Hand-built places on a sculpted landform.** Keen's world team blocks a biome out as a rough
  sculpt, drops in placeholder points of interest, then shapes the land between them. The props that
  define a place are placed by hand. Minor props (furniture, plants, loot spots) are picked from
  pools of valid options. Some places start as a story idea, and some stories are written for a place.
- **Every place pays.** Chests come in tiers (wooden, silver, gold) with random contents. A
  community tracker counts thousands of them. Many are hidden: a false wall, a vase in front of a
  door, a balance beam between two grapple points with a chest under it. Ancient Vaults hide
  craftspeople to rescue. Shroud Roots and Elixir Wells are held by named mini-bosses.
- **Verticality is the point.** Grapple points, updrafts, jump pads and climbing walls run into
  the hundreds or thousands (counts from the game files). The glider turns height into distance.
  Ancient Spires are tall towers you climb to reveal the map and glide off. A long trip is a chain
  of short ones: hook to a point, glide off a ridge, catch an updraft.
- **Routes are not forced.** The glider, movement skills and terrain editing let players reach
  places the designers did not plan for. Hard areas are foreshadowed by dramatic landmarks, and
  fog zones gate by danger rather than walls.
- **Landmarks you can reach.** If you can see it on the horizon, you can usually go there. Spires,
  ruined castles and volcano pillars anchor each biome's skyline.
- **Environmental storytelling by timeline.** Ruins show how long ago the fall was and who was
  fleeing. Some places look less ruined because people left in a hurry.
- **Dense, layered vegetation.** Grass carpets even the forest floor. Ferns and bushes crowd the
  wood edges, flowers drift in meadows, and stones and roots break up the ground. Moss and
  overgrowth reclaim the ruins.

Sources: [Enshrouded world design team AMA recap](https://enshrouded.com/de-DE/news/enshrouded-world-design-team-reddit-ama-recap),
[Windows Central interactive map](https://windowscentral.com/gaming/enshrouded-interactive-map-every-location-chest-ancient-spire-and-more),
[Ancient Vault guide (gamerguides)](https://www.gamerguides.com/enshrouded/guide/gameplay/basics/all-ancient-vault-locations-and-walkthroughs-in-enshrouded-unlocking-craftspeople),
[chest counts (gamevault)](https://embervale.gamevault.in/locations/chest.html),
[glider and grappling hook guide (xgamingserver)](https://xgamingserver.com/blog/enshrouded-grappling-hook-glider-guide/),
[biomes (enshrouded.wiki.gg)](https://enshrouded.wiki.gg/wiki/Biomes),
[Gamingtrend preview](https://gamingtrend.com/feature/previews/enshrouded-preview-voxels-pickaxes-and-wingsuits),
[Creating the world of Enshrouded (rpgsite)](https://rpgsite.net/news/15193-enshrouded-creating-world-enshrouded-behind-scenes-video).

## Where we stood (r30)

- **Good bones.** A radial plan of village, three spokes and three bosses, with strong
  mid-distance landmarks (the Ossuary over the fen, the henge on its hill, the rift). Short
  critical paths. Lots of lore on the ground.
- **Nothing off the road paid.** Readable stones and the secrets system's ten-plus puzzles existed,
  but there was no chest anywhere in the valley. Loot came only from kills, elites and bosses.
- **One climb in the whole world.** The r30 watchtower by the green was the only climb. Nothing
  rewarded height: no glide (until the combat pass), no anchors, no updraft but the rift's breath.
- **The fen was thin.** 65 of its 103 ten-metre cells held no authored mesh (r30 critique 17), and
  nothing stood up from it to navigate by between the drowned graves and the barrows.
- **The forest floor was bare.** Thornwood grass ran at 0.7/m2 and fern at 0.3. Shrubs gathered
  nowhere in particular, and there were no stones in the turf.

## What we built (r31)

### Four places worth leaving the road for (`realm_pois.gd`)

Each place reserves its ground in `RealmBosses.build`, before the terrain stamp and the flora, like
the r30 watchtower. The stamp levels it and no other module builds there. Placement uses
`LoreKit.search_spot` from a preferred point: clear of paths and sites, level enough, and 9 m from
every camp. Each place is dressed after the flora with its own overgrowth (the flora skips
registered sites, and ruins here are not swept). The first visit raises a banner, and the place is
remembered in `Travel.system_state("world_pois").found`.

| Place | Where | What is there |
|---|---|---|
| **The Drowned Belfry** | Hollow Fen, off east_way | Saint Corvin's bell tower, sunk to its knees in the fen and seen from east_way. A plank causeway on posts leads to it, with sagging boards and runners. Rubble from the fallen nave climbs its face in five jump-and-grabs to the open bell stage (9 m): the cracked bell, a pale lamp and an **iron chest**. Two stones: the bell's plaque, and the ringer's count scratched on the frame. A Tether anchor under the bell beam and a glide perch over the fen. A **guardian floor** on the open fen behind it (the Sexton). |
| **The Charcoal Hollow** | deep Thornwood | The burners who made charcoal for the Founder's bell furnace (it ties into the bells secret). Three clamps still smoulder: ash-rock domes, smoke and an ember glow, and each breathes an **updraft** the cloak-glide rides above the canopy. A lean-to with a **wooden box**, a woodpile, an axe left in a stump, and the burners' tally on a post. The clearing is a **guardian floor** (the Brood-Mother) and replaces the encounters pass's Thornwood fallback nest. |
| **The Almonry** | meadow between Hearthward and the fen | The abbey's roofless bread house for the road. Inside, a stair whose top flight has fallen in, then a jump-and-grab to the loft and the almoner's **iron chest** and book. The east gable still stands to its peak, with an anchor and a perch on it. Its walled yard has a well and the stone alms-table (with its plaque), and is a **guardian floor** (the Tithe-Knight: the tithe and the alms). |
| **The Watchers' Spire** | Thornwood's north edge, under the Crowns | A 16 m watch tower of the Order. Its outer stair wraps the tower five times and is broken twice: a 1.3 m gap with a 1.8 m grab, and a flight that stops 1 m short of its landing. A Tether anchor bridges the first gap. On the roof are the cold beacon cage, a **reliquary chest** and the best glide perch in the valley (16 m over the Thornwood). Two stones: the Order's charge, and a watcher's slate counting the fires going out. A **guardian floor** at its foot (the Pale Stalker) replaces the Crowns fallback. |

### Chests (`loot_chest.gd`)

- **Three tiers:** a burner's wooden box, an iron-banded chest, and a stone reliquary chest with a
  skull on the lid.
- **Opening:** E swings the lid up with a burst of warm motes. A small glowing lock and a few rising
  motes draw the eye to an unopened chest.
- **Once per save:** each chest opens once (`world_pois.chests`) and stays open and empty on the
  next night.
- **Loot:** grave ash and relic fragments go through `Travel.give`. Ids that `ItemDB` does not know
  are skipped, so a table can name items that are added later.
- **Gear (with the equipment pass):** a chest asks the Gear runtime (group `gear`) for
  `roll_chest(tier, chest_id)` if it exists, and otherwise for `roll_drop("elite")` (iron and
  reliquary chests: always a piece) or `roll_drop("tough")` (wooden: sometimes). The piece is laid
  as the gear pass's shaft of light in front of the chest.

### APIs for the other passes

All of these are plain Node3Ds in groups with metas, so nothing needs importing:

- **`guardian_site`** (the enemies pass, `Guardians.GROUP`): each place's fighting floor, with metas
  `guardian` and `site_key`. It is also in **`miniboss_site`**, with metas `radius`, `region` and
  `floor_y`. `RealmPois.miniboss_sites(tree)` lists them. Every floor is tested level, open, inside
  the world and more than its radius + 4 m from any camp.
- **`grapple_anchor`** (the combat pass's Tether line): placed with
  `core/player/grapple_anchor.gd`, so each anchor has the Tether's ring and glow. Metas: `reach`,
  `land` (where the haul ends) and `stand`.
- **`updraft`** (the cloak-glide, `Player._updraft`): metas `radius`, `height` and `lift`.
- **`glide_perch`**: a high lip worth jumping off. Metas: `facing`, `drop`.
- **`world_poi`**: each place, with metas `title`, `line`, `centre`, `radius`, `route` (climb
  stand points) and `walk` (which of them are walked rather than grabbed).

### A denser, layered ground (`realm_flora.gd`)

- **Forest floor:** grass under the oaks rises from 0.7 to 1.3/m2 (canopy still thins it). Fern
  goes from 0.30 to 0.42, moss from 0.10 to 0.14, plus a few flowers in the light.
- **Edges crowd:** shrubs and brambles grow up to 2.6x thicker, and ferns 1.8x, where the canopy is
  broken (cover around 0.35): wood edges and clearing rims. This is the layered "wall of green" look
  of an Enshrouded treeline, and it costs nothing in deep shade or in the open.
- **Open ground:** tall-grass drifts double on the meadow, heath and fen, and flowers rise by about
  40 %.
- **Stones in the turf:** half-buried RockKit boulders (shared, LOD'd meshes), mossy in the wood and
  fen, granite on open ground, ash by the rift. They sit at ankle height with no collision, gather
  in stony patches, and use one rock variant per chunk and style to keep draw calls down. They fade
  out at 44 m.
- **A/B switch:** `-- --no-r31-flora` builds the r30 wood (the old table, no edge crowding, no
  stones). It is a measuring switch, like `--no-r28-secrets`.

Counts (one build): grass 23,753 to 26,807; fern 1,548 to 2,106; shrub 148 to 278; tallgrass
1,080 to 1,587; flowers 304 to 415; moss 678 to 843; stones 0 to about 530.

## Took, adapted, skipped

**Took:**
- hand-placed places that pay (a chest at the top of every climb);
- tiered chests;
- a tower to climb and glide off;
- updrafts from a place's own story (the clamps);
- named mini-bosses holding places;
- denser, layered vegetation at edges.

**Adapted:**
- **Spires.** An Ancient Spire reveals the map. Ours is a watch tower whose roof shows every fire in
  the valley. It reveals nothing mechanically: our map is the journal, and the banner names the
  place.
- **Grapple points.** These are the Tether's anchors (the combat pass's mechanic), placed where a
  climb breaks or a perch is out of reach.
- **Hidden-chest tricks.** Enshrouded hides chests behind false walls. Ours sit at the end of a climb
  or behind a broken stair, so the route is the puzzle. The secrets system keeps the real puzzles.
- **Storytelling by timeline.** Each place shows how its people left: the burners mid-shift (axe in
  the stump, clamps never opened), the almoner still unlocking the door at dusk, the watchers out
  of oil on the tenth night, the ringer who rang the next one twice.

**Skipped:**
- **Voxel terrain editing and digging.** It is not our game.
- **Map-reveal towers and fast travel.** Our valley is small enough to walk, and the checkpoints
  are the fires.
- **Jump pads.**
- **Hundreds of chests.** We have four chests in four authored places. More should come with
  places, not be scattered.
- **Level-gated fog zones.** Our gates are the seals and the night's tiers.

## Measurements

All runs used `zz/perf_tour.tscn` with an isolated HOME, the Balanced preset, fov 90, a
1600x1000 window, vsync off. The eight Realm views were the deep and inner Thornwood, meadow, fen,
road, spawn looking north, barrows and chapel. Other agents were running GPU work at the same time,
so I compared A and B in back-to-back pairs, two rounds each, and took the best of each pair.

**At native resolution:** every view is still at the 120 fps cap. Before: 1% low 103-106, worst
frame 9.8 ms. After: 1% low 103.0-105.3, worst frame 9.8 ms, no frames over 33 ms.

**At `--stress=2` (2x2 pixels, so the GPU is the bottleneck):**

| View | GPU ms, A (`--no-r31-flora`) | GPU ms, B (r31) | Draws A / B | Prims A / B |
|---|---:|---:|---:|---:|
| deep Thornwood | 8.48 | 8.06 | 650 / 611-661 | 849k / 825-870k |
| inner Thornwood | 8.63 | 8.86 | 546 / 558-567 | 683k / 714-728k |
| meadow | 8.20 | 8.18 | 739 / 736-749 | 855k / 847-863k |
| fen | 7.69 | 7.80 | 575 / 596-602 | 496k / 503-512k |
| road | 9.11 | 8.67 | 599 / 608-615 | 778k / 805-822k |
| spawn, looking north | 7.98 | 8.05 | 719 / 730-738 | 796k / 807-817k |

**Cost of the density pass:**
- GPU: at most +0.25 ms at 4x pixels (about +0.06 ms at native), which is within the run-to-run
  noise.
- Draw calls: +10 to +25.
- Primitives: +1 to +6 %.

**Build time:**
- The flora's undergrowth pass grew by about 100 ms.
- The places build in 30-40 ms. Placement adds about 20 ms to the bosses stage.

**The places themselves:** each is one merged OssKit mesh per material, a few RockKit rocks, 4-6
overgrowth MultiMeshes (36-46 m ranges, no shadows) and at most one small unshadowed lamp. The
Charcoal Hollow also has three smoke emitters of 10 particles each.

## What is left

- **More places.** The south heath and the Crowns' east half have none. Candidates are a
  pilgrims' wayhouse on the road plain, a flooded lychgate causeway across the north fen, and a
  rock-cut hermitage on the Crowns. Use the same reserve/build pattern.
- **Hidden chests.** A loose stone in the Almonry hearth, a chest under the belfry causeway that
  needs the Tether to reach. These need an interact-to-reveal piece (the secrets kit has one).
- **More traversal between places.** Fallen-trunk balance beams over Thornwood gullies, a Tether
  chain up the rift's west wall to the Founder's Spill, and updrafts over the lava vents.
- **Flora.** Grass and fern cards are the r19 meshes. Enshrouded's leafier silhouettes need new
  TreeGen variants (broad-leaf shrubs, ivy on ruins, hanging moss), which belongs to the art pass's
  materials.
- **Discovery.** Places raise the banner, but the Journal's Places tab knows only the twelve regions.
  Adding them means extending `LoreDB.PLACE_INFO` and the codex's discovery hook.
