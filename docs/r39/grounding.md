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
- [x] `core/world/realm/ground_seat.gd`: seat a rigid piece on its footing (Footing base points), lowest standing point on the ground, never lifted unless buried
  past 0.55 m; a piece whose origin is set above the ground on purpose (plinth, deck) is left alone.
- [x] Lore and wayside stone models and rocks (`lore_kit.gd` prop / rock): seated. Wayside clutter (`wayside_build.gd`): one transform for all parts of a prop.
- [x] Wonder kit props (`wonder_kit.gd prop / prop_xf`): the yards', squares', camps', halls' crates, barrels, benches.
- [x] `prop_models.gd add` (whole models: lamps, benches, fingerposts, cairns, stones).
- [x] Site dress (`site_dress.gd _put`): the footprint's four corners, lowest corner sits, ground falling over 0.7 m under it is refused (re-placed).
- [x] Settlement yards: the whole 7 m scene (fence rows) on its lowest ground; scenes on more than 0.55 m of fall are refused.
- [x] Fallen logs and stumps (`flora_layers.gd`): seated on their footing after every test (the random stream is untouched).
- [x] Thorn Henge's bramble wall (`henge_raid.gd`): the wall's foot carried down to the ground where the land falls away from the arena's level (up to 4.5 m of hanging thicket).
- [ ] see the report for the rest.
