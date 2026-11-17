# World backlog (r39-world2): resume from here

Spec: docs/r39/briefs/world_models.md (the brief; supersedes shorter messages). Hard rule: NO PERFORMANCE COST (bake at build, LODs
and visibility ranges, merged meshes and MultiMesh, no new shadowed lights, light cap, net draws and primitives per region do not rise).

## Part A
- [x] A1 Compass: relevance filter (ui/compass_feed.gd), the wanderer's own marks (Wayfarer WayMark) as a kind, Minimal/Standard/Full,
      docs/r39/compass.md. [ ] settings row resync after Reset to Defaults (the option is built once; `_hud_checks` covers checks only)
- A2 Game-wide model pass
  - [x] landmarks: dress helpers, ashlar relief with LODs, wall-foot debris
  - [x] bosses: Warden, Crown, Thornwarden, Anchoress, Bone Abbot ornaments
  - [x] villagers: belt, buckle, pouch, patches, yoke (villager_wear.gd); [ ] hair/hands/tool variants
  - [ ] tavern dwarves secondary forms
  - [x] code-built cottages: sills, shutters, lanterns, ridge cap, garden fence (cottage_detail.gd); [ ] stalls, fences, wells, carts
  - [ ] OssKit/ruins: enable debris and carved bands for ruin kits game-wide
  - [ ] common enemies (enemy_body.gd / creature_mesh.gd)
  - [ ] trees and flora (bark, roots, deadwood), [ ] rocks and cliffs (facets, strata, lichen)
  - [x] water edges: docks, shore stones, bridges, fords (waterworks.gd); [x] far views: far hulls for the towers and the ship

## Part B (world)
- [x] B1 four deep halls (deep_halls.gd, dungeon_kit.gd)
- [x] B2 seven caves (caves.gd)
- [x] B3 region signature props (region_dressing.gd)
- [x] B4 lived-in settlements (settlement_yards.gd, module "yards")
- [x] B5 water (waterworks.gd)
- [x] B6 verticality (climbs.gd)
- [~] B7 far views: far hulls done for towers and the ship; [ ] horizon cards / mountains
- [x] B8 ground marks: ruts and puddles (ground_marks.gd); [ ] litter layer (flora `litter` exists; the ground shader fetch is a cost, left)
- [x] B9 thirty-two hidden finds (hidden_finds.gd)
- [x] B10 boss-scale avenues (titan_gates.gd: five obelisk pairs per approach)
- [ ] B11+ continue the critique (docs/r39/3_world_models_textures.md): dither on far leaves (light seat), per-region palettes, etc.
