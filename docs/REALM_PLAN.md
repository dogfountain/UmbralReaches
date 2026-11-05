# The Realm — zone redesign plan

Luke's brief (2026-11-03): redesign the zone from scratch except the **spawn brazier** and the
**tavern**; about **2x the area and denser**; far more vegetation, lore, landmarks; raise model
quality everywhere. Keep the three bosses, their seals, relics and the save format, rebuilt into
the new layout. A lava area stays but need not be a stairway; the old stair kit may be reused.

## How it is built

- `core/world/realm/realm.gd` (`Realm`) is the entry. **Off by default** until integration:
  run with `godot --path . -- --realm` (all modules) or `-- --realm --realm-modules=land,flora`.
  `glimmers.gd` calls `Realm.build(root)` instead of the old assembly when `--realm` is on.
- `core/world/realm/realm_layout.gd` (`RealmLayout`) is **the contract**: bounds, regions,
  paths, anchors and `macro_height(x, z)`. Everyone places against it. Only the lead edits it;
  ask (in your report) if you need a change.
- Each module is one script with `static func build(root: Node) -> void` (may `await`), loaded
  by path; missing/broken modules are skipped. Pipeline order (Realm.build):
  1 retire old layers → 2 **land** → 3 **rift** → 4 **bosses** → Tavern (kept) → 5 **lore** →
  TerrainStamp.apply (site floors) → 6 **flora** → SummitDress (kept) → 7 **assets** → cull.
- `Realm.retire()` hides and disables: Stair, Sanctuary, Ruins, Boulders, Forest (GiantTrunks,
  Canopy), DeadTrees, ForestFloor, RiftCrystals, RiftDebris, CrystalLights (+ their bodies).
  `WorldLanes.legacy = false` switches off the stair-era LANES / FIXED_LANES / FOOTPRINTS.

## The map (RealmLayout)

Playable x -110..110, z -150..80 (old: ~120 x 176). Spawn brazier at (0, 0, 33).

| Region | Where | Biome | Content |
|---|---|---|---|
| Hearthward | c (6,38) r 34 | meadow | spawn brazier, Kindled Keg (kept), cottages gone quiet, well, gardens, fences, a shrine |
| Pilgrims' Road | z 50..80, full width | heath | the old road: waystones, pilgrim graves, a broken cart, milestones |
| Chapel of the First Kindling | c (-72,52) r 22 | ruin | roofless chapel, defaced saints, graveyard, the first fire's hearth |
| Glimmer Glade | c (-38,8) r 18 | glade | bioluminescent clearing, shrine to the lost |
| Thornwood | x -110..-30, z -70..45 | oldforest | ancient oaks, brambles, roots, mushrooms; **Thorn Henge** moved to (-72,-18) on its hill |
| Hollow Fen | x 40..110, z -80..35 | fen | black pools, dead willows, drowned graves, will-o-wisps |
| Barrow Field | c (78,-42) r 20 | fen | grave mounds; **fen_descent** path down to the **Ossuary** gate (34,4,-66) |
| Ashen Rift | x -30..30, z -118..-12 | ash | lava (kept chasm heights), falls, basalt; **the Crossing** to the summit |
| Summit | c (0,-95) r 30 | crag | kept: platform, dais, Ascended Warden; ward at (0,25.2,-70.9) |
| The Crowns | z -150..-110 | crag | mountain wall, the world's north edge |

Paths (`RealmLayout.PATHS`): west_way (spawn → henge foot), east_way (spawn → barrows),
fen_descent (barrows → Ossuary gate), road, chapel_lane, rift_rim (spawn → crossing foot).
Progression: henge seal + Ossuary (Bone Abbot) → summit ward opens → the Warden.

## Modules and owners (each agent edits only its own files)

| Module | Owner files | Done when |
|---|---|---|
| **land** | `core/world/realm/realm_land.gd`, `world/realm/*.gdshader`, `art/materials/realm_ground*.tres`, tools it adds | new terrain over the whole map from macro_height + detail; old rift/Ossuary/summit heights kept in their rects; flat at spawn (y≈0, r 8) and tavern; paths carved and worn; fen pools (water); biome ground materials; horizon ring; nodes named `Terrain` / `TerrainBody` (regular grid, trimesh) so TerrainStamp/SeatProps work |
| **rift** | `core/world/realm/realm_rift.gd`, `core/world/lava_works.gd` | wider lava basin with falls, basalt columns, ash fields, glowing fissures; **the Crossing**: walkable ruined viaduct from (0,0.6,-8) up to the ward landing at (0,25.2,-70.9) (a platform there ≥ 6x6 m at y 25.2 for the summit's own approach stairs), built from `stair_step/column/platform.glb` + OssKit, not a straight stairway; lava kill volume covers the new lava; walk test |
| **bosses** | `core/world/realm/realm_bosses.gd`, `thorn_henge.gd`, `ward_seal.gd`, `enemy_spawner.gd` (add `seed_realm` + `REALM_CAMPS`), Ossuary entrance only in `world/areas/ossuary/ossuary.gd`, braziers repositioning (not the spawn one), `zz/realm_*` tests, `zz/boss_test.gd` realm variant | henge at HENGE_C with its stair from west_way's end; Ossuary reachable on foot via fen_descent; summit ward at the Crossing head; camps per region (seal guards for henge/oss_gallery/summit as before + roaming packs); checkpoint braziers at sensible places; `boss_test -- --realm` 27/27 and route walks pass |
| **lore** | `core/world/realm/realm_lore.gd`, `core/world/realm/lore_db.gd`, `docs/LORE.md`, prop builders it adds under `core/world/realm/lore/` | a written mythos consistent with the bosses/items; Hearthward village (not the tavern), chapel, glade shrine, barrows, road waystones, graves, statues; 25+ readable inscriptions (LoreScrap); every building registers a WorldLanes site |
| **flora** | `core/world/realm/realm_flora.gd`, `core/world/realm/tree_gen.gd`, `art/materials/realm_foliage*.tres`, generated textures `art/textures/realm_*` (+ the tools that make them) | 5+ tree species of high quality (ancient oak, pine, pale birch, fen willow, dead snag), shrubs, ferns, grass, flowers, mushrooms; densities by biome; trunks collide; nothing on paths/sites/Crossing/lava; chunked MultiMeshes |
| **assets** | `core/world/realm/realm_assets.gd`, `core/world/realm/rock_kit.gd`, `art/models/*` replacements via tools, `art/materials/*` (not lava, not realm_*) | `RockKit` (procedural high-quality boulders/cliffs/basalt, styles granite/basalt/mossy/ash) available early for others; upgraded menhir, cairn, rune slab, twisted root, fallen branch, lantern, stone frame, mirror frame (not the spawn brazier, not the tavern); material pass |

Lead (me): `realm.gd`, `realm_layout.gd`, `glimmers.gd` / `main.gd` hooks, integration, the
default switch, docs/HANDOFF.md, the final survey.

## Rules (binding, from Luke)

- **Never headless-rebake `world/main.tscn`.** Everything is built at runtime by scripts.
- No anti-aliasing. Glow budget fixed (intensity 0.62, bloom 0.06, threshold 1.15, levels 0-1).
- Don't restyle the player robe. Keep the spawn brazier and the tavern as they are.
- `rm` only explicit full paths, never globs. Don't commit (Luke runs git).
- **Don't add `class_name`** to new scripts (parallel `--editor` runs race on the class cache):
  use `const X := preload("res://...")` / `load()`. RealmLayout and Realm are already registered.
- Several agents work in this checkout at once: edit only your files; never revert someone
  else's change; run Godot with `-- --realm --realm-modules=<yours and what you need>`.
- Don't touch the player's save or settings: `boss_test` writes `user://savegame.cfg`
  (`~/Library/Application Support/UmbralReaches/`); back it up and restore it if you run it.
- Performance budget (whole zone, 1600x1000 window): ≤ 900 draw calls and ≤ 1.5 M primitives
  in any view; LODs on solid meshes, **never on leaf/grass cards** (they collapse); visibility
  ranges on small props; MultiMesh chunks 16-24 m; collision only where you can walk into it.
- Verify visually: `zz/spot_shot.tscn -- --realm --at=x,y,z --look=x,y,z --name=n`,
  `zz/survey.tscn -- --realm --only=x0,z0,x1,z1 --out=dir`, `zz/tile.gd` for sheets.
  Headless first; renders when a visual matters. Kill render processes rather than waiting.
- Report at the end: files changed, how to test, the shots that show it, known gaps.
