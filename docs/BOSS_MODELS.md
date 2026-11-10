# Boss models: the redesign brief

The five bosses are the next art job, after the six creature bodies (merged 10 Nov, `tools/blender/grunt_body.py`).
Luke's verdict on the current ones: they "look horrible". This page says what is wrong, what we learned
rebuilding the creatures, the method to use, and a brief for each boss.

**This is a handoff brief. Delete it (keep one line in `docs/DECISIONS.md`) once the work is merged.**

## Where they stand

| Boss | Base kind / rig | In-game scale | Built by | Model now | Triangles |
|---|---|---|---|---|---|
| Thornwarden | Leaper (`QuadRig`) | 2.6x | `tools/blender/boss_thornwarden.py` | `art/models/boss_thornwarden.glb` | 39.9k, 16 rigid parts |
| Bone Abbot (Osric) | Ossuant (`HunchRig`) | 2.6x | `tools/blender/boss_bone_abbot.py` | `art/models/boss_bone_abbot.glb` | 40.0k, 16 rigid parts |
| Ascended Warden | Husk (`HunchRig`) | 5x (about 9 m) | `tools/blender/boss_ascended_warden.py` | `art/models/boss_ascended_warden.glb` | 40.0k, 9 rigid parts |
| The Speaking Crown (Fallen Hierarch) | Husk (`HunchRig`) | 3.4x | `tools/blender/boss_hierarch.py` | `art/models/boss_hierarch.glb` | 32.3k, 9 rigid parts |
| The Anchoress | Wretch (`HunchRig`) | 1x | code: `core/enemy/anchoress.gd` `_make_parts()` (`CreatureMesh`) over the wretch body | none | n/a |

How the game dresses them (`core/enemy/enemy_body.gd` `dress()`): a kind listed in `EnemyBody.MODELS` gets
the **rigid** boss GLB, one mesh per rig socket parented to that joint (`_dress_model`). Otherwise
`GruntModel.dress()` (`core/enemy/grunt_model.gd`) gives the **skinned** grunt body. The Anchoress takes the
wretch's skinned body and adds code-built hood, chain and lamp parts on its sockets.

## What is wrong with them

- **Rigid parts, so cracks at every joint.** Each limb segment is its own mesh, so knees, elbows and the
  waist open and overlap as the rig moves. At 2.6x to 5x every crack is half a metre wide.
- **Primitives stuck together.** These are the same faults Luke rejected in the creatures: ball joints,
  egg heads, sausage limbs, a mannequin under the costume.
- **Code-built parts on the Anchoress.** Its hood, chain and lamp are `CreatureMesh` blobs and tubes. This
  is the box art the asset bar rejects (hero assets are modelled in Blender and render-reviewed).
- **Never reviewed in the game's real light.** At night, under the creature shader, from the player's eye.

## Lessons from the creature rounds (do not relearn these)

1. **Change the method, not the parameters.** Two rounds of tuning primitives got nowhere. One continuous
   surface per body fixed it in one round.
2. **A loft, not a stack.** Torsos built from stacked ellipsoids leave a ring at every seam. Loft
   cross-sections instead (`Skel.loft`, Catmull-Rom between keys). Use `axis="z"` for a quadruped trunk.
3. **The head is a loft too.** A sphere with dents never reads as a face. The skull-shaped loft in
   `head_masses()` works: wide cranium, temples pinched at the eyes, cheekbones, a jaw that juts, a small
   chin. Sockets, brow, mouth and cheeks are then sculpted in (`head_sculpt`).
4. **Arms are separate surfaces.** Where an arm touches the torso in the rest pose, the voxel remesh fuses
   them, and the posed arm tears the flank into a web of skin. Build the arms as their own skin objects that
   overlap inside the shoulder (`sk.arms`), and give them their own weights: the torso never takes arm
   bones, the arms take only arm bones plus the chest. Keep thighs thin enough that the legs don't fuse
   (inner-thigh gap at least about 4 cm).
5. **The posture is the rig's job.** Stoop, crouch and splay come from `posture({...})` in the boss script.
   Don't model them into the mesh: the rig stacks on top, and the skeleton contract stays fixed. To make a
   creature squat, raise its crouch in the script (the spitter now uses 0.6).
6. **Gear positions must follow the body.** When the body changed shape, gear placed at fixed coordinates
   floated off it (the spitter's spines and straps). Place gear relative to the skeleton.
7. **Watch the triangle budget.** With a fixed body budget, `grunt_kit.budget()` hit its 0.03 floor and
   crushed the gear to hexagonal sticks. Give the body a moderate budget (the bake carries the detail) and
   keep the gear count down.
8. **The Blender sheets lie about value.** The review lights wash skin out to plaster. Judge colour on the
   atlas and in the game, not on the sheet.
9. **The capture camera can shoot the back.** `zz/creature_shots.gd` now takes `near_front` and
   `near_back` views. Check both, and crop to the creature at full size before judging.
10. **Parallel Blender exports plus editing the kit mid-run broke the bake** ("No valid selected objects").
    Don't edit `grunt_kit.py` while exports are running.

## The method

Build each boss as one **skinned** body, the same way the creatures are now built, and load it through
`GruntModel` instead of the rigid path:

1. **Body.** `grunt_body.humanoid(opt)` gives a lofted torso and neck, a skull-loft head, and limbs as skin
   chains. For the Thornwarden, use the leaper's `axis="z"` trunk loft in `grunt_quad.py`. Add
   boss-specific masses and lofts for silhouette (hump, robe bell, antler bases). New boss-only helpers go
   in `tools/blender/boss_body.py`, which imports `grunt_body`. Don't fork `grunt_body`.
2. **Fuse, then sculpt.** `build_skin()` does Skin modifier, subdivision, voxel remesh and corrective
   smooth. Then `Sculpt` adds bumps, ridges, bands and noise in rig space. At boss scale use a finer voxel
   for the head and hands (about 0.004).
3. **Bake high to low.** Use `make_low()` per surface and `grunt_kit.export_skinned(..., pairs=PAIRS)`.
   Normal and AO are baked from the high poly; gear keeps its procedural bump.
4. **Cloth and gear** (robes, copes, veils, crozier, antlers, chains) are separate meshes, weighted with
   `envelope_weights` or rigid to one bone. Robes must swing with the legs, not crack: weight a robe to
   the pelvis and the hips in bands down its length.
5. **Held things stay rigid.** The Abbot's crozier must be a mesh named `boss_hand_r` (exported as a rigid
   part) because `bone_abbot.gd` finds `Boss_hand_r` and turns it upright each frame. Extend
   `export_skinned`'s `rigid` map for it. The Bulwark's `shield_chest` is the precedent.
6. **Wire it into the game.**
   - Add the boss kind to `GruntModel.KINDS` with its shader family (dust for the Abbot, heat for the
     Thornwarden, wet for the Husk-born and the Anchoress).
   - Remove the kind from `EnemyBody.MODELS`. Delete the old rigid GLB, its textures, its `.blend` and
     `boss_reexport.py` once nothing uses them.
   - Check `has()` and `_tex()` name the textures `boss_<name>_*`.
7. **Budget.** About 40k triangles per boss (the current budget), and one 4096 atlas if 2048 blurs at 5x.
   Godot generates the lower LODs on import. No new lights; the scripts already add the Reliquary and Halo
   lights. Draw calls stay flat: one skinned body plus at most one rigid part.
8. **Export to scratch** (`GRUNT_OUT=/private/tmp/claude-501/bosses/glb`) until the review passes. Only
   then copy into `art/`.

### Contracts not to break

- **Rig and sockets.** Keep the bone names and rest positions (`boss_kit.SOCKETS` for the hunch rig,
  `quad_sockets()` for the Thornwarden). The game scales the boss with `BossKit.embiggen`: model it at
  1x.
- **Script-added lights and weak points sit on sockets.**
  - Abbot: Reliquary light at `chest` + (0, -0.06, -0.36), so the reliquary cage must glow there.
  - Warden: Halo light at `head` + (0, 0.14, 0.22), behind the head, where the mandorla belongs.
  - Spitter-style weak points are spheres the script adds.

  Keep the model's glowing parts where those lights are.
- **Height.** Within 15% of the current model at 1x, so hit boxes, arenas and the Warden's `ASCEND_H` still
  fit.

## The brief for each boss

Silhouette first: each must read from 20 m at night against the sky, before any detail.

**Thornwarden** (2.6x, quad). A stag-boar of the hedge. Today it reads as a box on stilts.
- Build the leaper's hound trunk heavier: a humped wither, a deep chest, heavy haunches.
- Bark shingles as sculpted plates in the high poly, not separate boxes. Moss in the seams.
- An ember heart splitting the chest (an emissive crack).
- A deer-skull mask with ember eye sockets.
- The antler crown as lofted branches wound with bramble. It is the silhouette, so keep it big and
  readable.
- Legs thick, ending in splayed root feet.
- No ball hips (use the leaper's flat thigh masses).

**Bone Abbot, Osric** (2.6x, Ossuant base). A skeletal priest.
- Reuse the new ossuant's real skull and open ribcage, scaled up in detail, not size.
- A cassock and cope as cloth that hangs from the shoulders and swings at the hem.
- A closed mitre with gilt bands.
- A caged reliquary candle at the breast, glowing at the Reliquary light.
- The crozier of fused vertebrae as a rigid `boss_hand_r`.
- Bone tones varied as on the ossuant.

**Ascended Warden** (5x, Husk base, floats). The last priest. At 9 m, every surface is close to the camera.
- A bell robe of pale linen to the ground, with no legs. The robe is the body, so loft it as one surface with
  folds sculpted in.
- A white-gold mask with slit eyes and a hairline crack.
- A veil.
- Long open hands in gilt bracers, with fingers that read at distance.
- The mandorla behind the head is light. Keep it a thin emissive ring or plate, not a mesh blob.
- Use the 4096 atlas here first.

**The Speaking Crown** (3.4x, Husk base). A cantor fused with the colossus's stone.
- A cope of cracked masonry to the ground.
- Broad stone pauldrons and gauntlets of fitted blocks.
- For a head, a great stone speaking-horn, its mouth ringed with the tiara's broken tines and an ember in
  its throat.
- Stone, so the rigid look is right for the plates. Weight each block to one bone, but the cope must flex
  at the waist.

**The Anchoress** (1x, wretch base). A hermit in chains with a lantern.
- Replace the code-built `_make_parts()` with Blender gear on the new wretch body:
  - a grey wool hood
  - a rope across the mouth
  - salt on the brow
  - chain wrapped over the shoulders
  - a shawl
  - a pendant cairn-stone
  - the lamp on its chain
- Give her her own kind in `GruntModel.KINDS` so the wretch's sack and sticks don't show under the hood
  (today she inherits the wretch body).
- Then delete `_make_parts()` and its `CreatureMesh` use.

## Review loop (each boss, before any merge)

1. **Sheets.** `tools/blender/grunt_turnaround.py`: front, three-quarter, side, head, neutral and night. Plus a
   body-only still with the gear hidden. Look for ball joints, egg heads, seams, floating gear and
   faceting.
2. **In game.** Copy into the worktree's `art/` and import (`godot --headless --path . --import --quit`).
   Then run `HOME=<scratch> godot --path . res://zz/creature_shots.tscn -- --out=<dir> --only=boss_...` and
   judge `near_front` and `near_back` cropped to the boss at full size: posed, lit, at night. Watch for
   skin webs when the arms move.
3. **Fix until happy.** No "partly worked" merges.
4. **Tests.** `TESTS_FILE` with `boss`, `enemies_r31`, `enemies_r33`, `enemies_r34`, `enemy_ai` and
   `encounters`. Plus a short check of each boss fight's arena (reach, hit boxes, the crozier upright, the
   Warden ascending).
5. **Merge, push, clean up.**
   - Commit, merge and push.
   - Delete the worktree, the scratch exports and the old rigid assets.
   - Delete this brief.

## Order

1. **Bone Abbot.** It is closest to the finished ossuant, so it proves the skinned boss path and the rigid
   crozier.
2. **Thornwarden.** It proves the quad.
3. **Anchoress.** Gear only, on an existing body.
4. **Speaking Crown.**
5. **Ascended Warden.** The largest, and it needs the 4096 atlas.

Work one boss at a time per set of files. Two agents can run in parallel only on different bosses and
different new files. Neither edits `grunt_body.py` or `grunt_kit.py` while the other's exports are running.
