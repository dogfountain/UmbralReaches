# World density: the wayside and the flora's layers

Luke, 15 Nov 2026: "increase the world's density ... richer flora per biome, more props and ruins, more points of
interest, so that something worth walking to is always in view". Across the whole doubled Realm (the old ground and
the eleven Far Reaches regions), made of existing systems and in-house assets only.

## What is built

**The wayside** (`core/world/realm/realm_wayside.gd` plans, `wayside_kit.gd` lays each place out, `wayside_build.gd`
builds, `wayside_themes.gd` holds the data): the small places between the landmarks, in 29 kinds: fallen field walls,
sheep folds, ruined cottages, wayside shrines (a ruin marker, a wayside cross or a defaced saint), standing stones and rings, cairn fields, broken carts with
their spilled load, cold camps (a fire ring, a lean-to, a bedroll, stores), wells, grave plots, woodpiles, saints on
plinths or fallen, masons' blocks and column drums, battle ground (spears, shields, a banner, bones), bell shards,
barrows (some with a door), charcoal clamps, field corners (fence or wall, a rick, a scarecrow, a plough), milestones,
jetties with eel traps and a sunk boat, the ribs of something very big, and a lookout (a stair of fallen blocks up a
ruined watch-tower stump, a glide perch on top) on most regions' most prominent rise; and the modelled ruins the first
wayside scatter used (modelled low walls, a fallen boundary marker by a lone grave, Order steles, wall piers, the
roofless ruin shrine, a ruin sunk in a mere, the handcart), folded into the same planner. Each kind lays itself out as
data with its own variation (counts, sizes, ruin, what was spilled), so no two read the same.

Where they stand is planned, in passes:
- **ways**: every way is walked; wherever nothing worth a look stands within 30 m, a place goes up beside it (4-25 m
  off the edge, alternating sides), so the road always has something in view;
- **milestones** every ~115 m along the new ground's ways;
- **open ground** filled the same way to 44 m, the emptiest spots first;
- **lookouts** on each listed region's most prominent rise;
- **dressing**: the minor kinds spread over every suitable spot ~19 m apart (the Far Reaches in full, the Marches 80 %,
  the old valley 40 %);
- **names, boxes, writings**: each region's named places (`NAMED`, ~3 per Far Reaches region, 1 per Marches region)
  are matched to planned places of the right kind (or forced in near its ways); they are discoveries (group
  `world_poi`: the subzone banner, discovery XP, a world-event site). Every themed region gets 1-2 boxes (LootChest,
  small: a handful of grave ash, now and then iron or a bloom); writings (`lore/wayside_texts.gd`, 62 texts, merged by
  `lore_index.gd`) go on carriers fitting the kind: a rune stone, a page on a crate, a grave marker, a waystone, a
  stone tablet, a notice board.

A place keeps off the ways, every registered site, camps (13 m), fires (12 m), outposts (11 m), the region builders'
slots (poi 23 m, camp 14 m, fire 12 m), raid floors, towns, water (a jetty wants it), steep ground and the nav tiles'
seams (x +-262, z 86 / 246); a region in `Themes.SKIP` (towns' squares, the boss and set-piece ground) is left alone.
Its region's taste picks the kind (`Themes.REGIONS`, by where it stands: beside a way, in the open, in a wood), never
the same kind twice within 110 m.

The plan runs at the flora's start (`flora_layers.gd plan`, called by RealmFlora.build before its fingerprint), when
every landmark, lore stone and wonder is registered; the solid pieces' ground is registered as open-air sites (no
stamp, so the ground stays as it is) and every place keeps trees off itself; in a wood it cuts its own clearing.
It is built after the flora (REACH_POIS: `realm_wayside.gd build`) a 96 m chunk at a time, drawn as few meshes as the
materials allow (`wayside_build.gd`): the kit's boxes one mesh per material, the stone and prop models through
PropModels (one mesh per material set, with LODs), the RockKit stones and the site props' clutter merged by material,
so a chunk in view costs about a dozen draws however many places stand in it. The big masses (walls, towers, stones,
the stone models) fade out 110 m from their chunk's middle (the integrator's range), the small things (timber, iron,
cloth, clutter, carvings) at 0.45 of it (FadeGuard scales both by 1.5: ~165 m and ~75 m), so a chunk farther off costs
only its few big draws; a lookout stands alone and reads to 220 m. Measured (16 Nov, on the world branch at c588528,
paired runs of `zz/density_shots --perf` with and without `--no-density`, draws exact, frame times noisy under the
shared load): at the fight bench's spot 16-61 draws fewer in all four directions (1,137-1,607 against 1,198-1,661);
in the Far Reaches' views +1 to +45 (their totals 400-780, under the hub's 1,150-1,600); median frame time 8.10 against
8.16 ms over the ten views. The flora's layers add 0-4 draws (they go into the flora's own MultiMeshes). Writings,
boxes and glide perches stay nodes. `-- --no-wayside` turns the places off and leaves the flora's layers.

**The flora's layers** (`core/world/realm/flora_layers.gd`, run inside the scatter after the undergrowth, into the
flora's own buffers, from their own random streams):
- **feet**: round two trees in three, by biome: ferns and moss on the shady side, a ring of mushrooms, roots; tall
  grass and flowers round a lone tree; heather round the fell pines; reeds and moss in the fen;
- **verges**: a broken band of tall grass and flowers along every way (bracken and bramble in woods, heather on the
  heath, reeds by water, dead brush in the ash), gapped by noise;
- **thickets** at woods' broken edges (a sapling, shrubs, bramble, fern), **deadfall** in deep shade (a log with fungus
  along it, moss, ferns, a stump), **fungus rings** round stumps in the Lanternwood;
- **drifts**: patches of one flower on open ground (each chunk draws one variant), gorse clumps on the heath;
- **glades**: the clearings the wayside cuts: flowers in the light, a rim of bracken, bramble and shrub;
- **creep**: what grows on and round each wayside place (`Themes.KINDS creep`).

The Far Reaches' region looks (`flora_looks_marches.gd`) were enriched: Fallowmere's fields gone to seed, the
Lanternwood's fungus, litter and deadfall, the Southwood's bramble and litter, lilies on the Reedmere's and the Nave's
open water, the Thousand Cairns covered in cairns.

A hollow under the fen's water level with no water in it (the Long Arches' dry valley, the Bellfall crater's floor,
Fallowmere's low fields) used to grow nothing; the flora now follows the real water (`flora_tables.gd wet`).

## Switches and tools

- `-- --no-density`: the world without the wayside and the flora's layers (A/B; the flora cache keys on it).
- `zz/density_map.tscn -- --out=<dir>`: the Realm from above at 1 px = 1 m (undergrowth, grass, trees, sites, the
  wayside's places by kind, named ones ringed, boxes and writings marked) and the coverage along the ways.
- `zz/density_shots.tscn -- --out=<dir> [--places=N] [--region=a,b]`: a still at every named place and N more per region.
