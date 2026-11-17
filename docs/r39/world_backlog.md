# World backlog (r39-world2): resume from here

Spec: docs/r39/briefs/world_models.md. Hard rule: no performance cost (bake at build, GenCache, ranges, merged meshes, light cap 72).
Branch r39-world2, worktree /Users/luke/UmbralReaches/.claude/worktrees/r39-world2 (never the r39-sound worktree).

## Done (each its own commit; see git log)
- A1 compass: relevance filter, own marks (WayMark), Minimal/Standard/Full, resync after reset, docs/r39/compass.md
- Landmarks: Sleeper, Hollow King, Salt Ship, Wardens' Line, Chain Span, Titan Gates + avenues, hermit caches, outcrops, roadside scenes
- Fix pass (first measurement): typed `:=`, bounded WK.place, terraces, GenCache kit snapshots (WK.cached/fp), light cap, no tree_clear
- B1 deep halls (4), B2 caves (7), B3 region signature props (11 regions), B4 yards (module "yards"), B5 waterworks (9 docks, 3 bridges, 2 fords),
  B6 climbs (6 towers, 6 cut stairs), B7 far hulls for towers/ship, B8 ground marks (ruts, puddles), B9 32 hidden finds, B10 avenues
- Models: bosses (Warden, Crown, Thornwarden, Anchoress, Abbot ornaments), villagers (villager_wear.gd), cottages (cottage_detail.gd),
  props (+1 variant each: site_props_more.gd), kit masonry tone/moss patchwork, prop weathering (prop_weather.gd), crown tops, region flowers
- Reviewed and found already at the bar (no change): tavern dwarves (braids with rings, belt, pouch, knife, patches, bracers: dwarf_rig.gd),
  common enemies (ribs, stitches, bandages, girdles, rags, glands: enemy_body.gd). Adding more there would be noise, not depth.

## Done in the continuation (each its own commit)
- Merge of master over the lead's revert (world files kept from r39-world2)
- Trees and undergrowth: baked bark, burls, rootlets, new oak/pine/birch/deadwood variants, undergrowth variants (tree_bark.gd, tree_surf.gd split)
- Rocks: strata bands and lichen in vertex colour, scar facets (rock_kit.gd + shader)
- Acoustic zones for every interior (WK.acoustic) and per-crown tree fade_end
- Ruins: capped debris, carved band, crown stones (oss_kit.gd); props: variants as per-zone windows (no extra draws)
- Cottages: eave fascia and roof moss; masonry edge wear; crown value clumps; bark material specular

## Not done (precise)
1. Far-leaf dither itself (alpha-to-coverage in realm_foliage.gdshader) belongs to the light seat; tree_gen supplies `fade_end` per crown.
2. Horizon cards / mountains (B7 rest): the far plane is 420 m and the ring already carries the silhouette.
3. Ground litter map + layer (T6) and masonry detail-normal layering (T3): each adds a shader fetch (a cost), left.
4. Stalls, fences, wells beyond what exists; decals (T7); texture-array packing (T10); hitch warm-up (lead).
5. Water edges beyond the docks/bridges/fords already built.

## Per-pass cost statement (triangles / draws, and what pays for it)
See docs/r39/world_landmarks.md ("Third pass", "Fix pass"). Summary: landmarks add about 8 material draws each in their own frustum only;
flames are one MultiMesh per kit; small scenes are cell-grouped and range-faded (110-150 m); underground complexes fade at 110-120 m;
towers/ship swap to a 12-triangle hull beyond 150 m; model passes (bosses, villagers, cottages) are baked mesh detail inside existing meshes
(bosses and villagers: one mesh each, more triangles per body, no extra draws; cottages: kit boxes merged into the existing per-material
meshes, no extra draws); props: +1 MultiMesh per prop kind per zone (the only draw rise, bounded).
