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
