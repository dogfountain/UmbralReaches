# r39 grounding and placement audit: live checklist

Brief: `docs/r39/briefs/grounding.md`. Luke, 21 Nov: objects not flat on the ground, the world looks unfinished; widened: audit every map piece (objects under
arenas, smoke into the sky) and judge each place as a composed scene.

## Tools (zz/, tools/)
- `zz/ground_probe.gd`: walks every placed static (MeshInstance3D, MultiMesh instances read from their buffers, and the kits' colliders as welded islands of faces
  = the boxes as built) and writes one TSV row each: base against the TERRAIN body (rays), slope under it, tilt, way, water, overhead solid, region, site; a second
  file lists every particle emitter / beacon / plume. Needs a real renderer (headless MultiMeshes and meshes are empty).
- `tools/ground_rank.py`: groups the rows by placing system and kind, counts per region, picks the worst spots by quota (float, tilt, sink, road, under, water,
  buried, lone), at least 10 m apart, off the Ossuary area and the Rift (other agents').
- `zz/ground_shots.gd`: one run = probe + rank + a still of each of the 60 worst spots at 1920 px from the wanderer's height on the downhill side + every sky effect
  from 60, 150 and 300 m. `--probe=file.tsv --rank=spots.json --out=dir --tag=before|after`; the after run reuses `spots_used_before.json` so the cameras are identical.

## Fixes at the source (build-time only, no per-frame work)
- [x] `core/world/realm/ground_seat.gd`: seat a rigid piece on its lowest 8 cm of vertices (a round stone is not asked to touch with its side), never lifted unless
  buried past 0.55 m; a piece whose origin is set above the ground on purpose (plinth, deck: more than 0.2 m over it) is left alone.
- [x] Lore and wayside stone models and rocks (`lore_kit.gd` prop / rock); wayside clutter, one transform for all parts of a prop (`wayside_build.gd`).
- [x] Wonder kit props (`wonder_kit.gd prop / prop_xf`: the yards', squares', camps', halls' crates, barrels, benches) and whole prop models (`prop_models.gd add`).
- [x] Site dress (`site_dress.gd _put`): four footprint corners, the lowest sits, ground falling over 0.5 m under a prop is refused (re-placed).
- [x] Settlement yards: the whole 7 m scene (fence rows) on its lowest ground; scenes on more than 0.55 m of fall are refused.
- [x] Fallen logs and stumps (`flora_layers.gd`): seated after every test (the random stream is untouched).
- [x] Thorn Henge's bramble wall (`henge_raid.gd`): its foot carried down where the land falls away from the arena's level (up to 4.5 m of thicket hung in the air).
- [x] `villager.gd` `_pose_chop`: a villager with no block anchor returned Vector3.INF and made 80 "cannot be normalized" warnings and 32 zero-basis errors per run.
- [ ] Flora stones were tried and put back: seating them on the build-time ground buried 20% of them by the whole cap (their final ground is not the build grid).
- [ ] Buildings' footing skirts (found_block.glb), per-segment fences in the kit walls, the Reedholm town bodies, the March Wall: not done (see the report).

## Measured (zz/ground_probe.gd, same rules before and after; tools/ground_compare.py)
The probe's float is dominated by props that stand on decks and walls, moss and glints that hang on purpose, so counts barely move: see the report's
numbers for the slope and hover floats of small MultiMesh props (1314 -> 1298), and the shots, which are the proof.

## Round 2: the visual audit (340 places, three views each)
`zz/ground_shots.gd --places[=from:count] | --place-ids=a,b,c` shoots every place (WorldLanes.sites merged within 18 m, lore landmarks, camps, fires; the Ossuary's area, the
Rift and the Summit left out): approach at 1.7 m, close 3/4, high; full-size JPGs and a strip per place. `places_<n>.txt` maps the number to the place.
Strips for all 340 are in the scratchpad (places1 = 0..59, places2 = 60..339). About 45 strips were read closely, the rest skimmed; at night most views are dark
and wayside/camp cameras end up in grass, so the table below is what could be judged, not a clean bill for the rest.

| place | what was wrong | fixed |
|---|---|---|
| Hearthward east, near the Almonry (035 view 0) | a lit barrel with ember patches hangs ~0.9 m in the air between two walls; its source is not the Keg's prop barrels (not in the probe) | n (open: find the owner) |
| the Keg (094), Hearthward square (300), chapel (097), Lastlight inn (081), Reedholm (076, 078) | read as designed scenes; the Keg's two barrels beside the door sat on the site's lowest ground (FinalSeat now puts MultiMesh props on the settled ground: 127 of 1553 moved) | y (barrels) |
| Wardens' towers 1-6 (138-141) | their flames, fire halos and candles were deleted by cull_scatter inside the tower sites (a torch at each foot is back in 138) | y |
| The Sleeper, Chain Span, kings' undercroft, castellum cisterns, witch's cellar, hermit caches, Hollow King, titan gates, Hall nave crypt | the same: Flames / FireHalos / Candles batches culled | y |
| Weirford inn and watch hut, necro mausoleum, orchard heart | Halos / Flames / Candles batches culled | y |
| Lamplighters' Spire | the Footing batches (found_block.glb) culled (29 instances) | y |
| Saltmarket yards, Reach towns' yards | Yard_barrel / Yard_crate batches culled (37 + 45 instances), Kerbs and Racks at the Saltworks (29) | y |
| Thorn Henge arena | RaidLitter stones culled (75) | y |
| wayfarers' WayLamps | a live pool, its slots culled | y |
| Thorn Henge wall | the bramble thicket hung up to 4.5 m over the land | y (round 1) |
| the 340 places, in general | no floating or sunk prop other than the barrel above was visible in the strips read; many views are dark or inside grass | - |

cull_scatter now prints `CULL_SCATTER n of m from <batch> (site <name>)` for every batch outside the flora. Outside the Ossuary and the Rift 543 instances were deleted; after
the marking 7 remain (rock outcrops, which are scatter). The Ossuary's 5150 are the Ossuary agent's. The Rift's AshDrift (70) was left.
