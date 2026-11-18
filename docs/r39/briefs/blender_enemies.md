# r39 brief: every rank-and-file enemy modelled and animated in Blender

Luke, 18 Nov: "the bosses look bad and are static"; "modeled blender assets like all other assets, all models in the
game should be blender". After the Bone Abbot and the Anchoress were rebuilt that way he said "Abbot is decent,
finish everything else". The bosses are the lead's (the main session). The enemies are yours.

Read this brief end to end, then `docs/r39/boss_rework_plan.md` (the program; the section "Every model in Blender"),
`AGENTS.md`, `.cursor/skills/umbral-donts`, and the two finished examples before you write a line:
- `tools/blender/vb_kit.py`: the shared kit (lathe, loft, tube, blob with `power` for dressed stone, the villagers'
  vertex data, the armature, posing about rig axes, `key_clip` with Bezier keys and follow-through cloth chains,
  additive chains for things that hang from a hand, the GLB export, the turnaround and posed review renders);
- `tools/blender/vb_bone_abbot.py` and `tools/blender/vb_anchoress.py`: a body built part by part, weights per part,
  a skeleton with cloth chains, an `aim()` that points a held thing in the world whatever the arm does, the clips;
- `core/enemy/clip_rig.gd`: the rig that plays the clips in game (`ClipRig.fit`, `telegraph`, `strike`, `howl`,
  `stagger`, `flinch`, `collapse`, `boss_move`, the `villager_look` dressing with `DwarfLook.material_boss`);
- `core/enemy/anchoress.gd` `_build()` and `_rite()`: how a fight builds on the Blender model and falls back to the old
  body when the GLB is missing.

## What you own

- New scripts `tools/blender/vb_<kind>.py`, one per enemy kind, on `vb_kit.py`. You may extend `vb_kit.py`, but keep
  every existing function's behaviour (the lead re-exports the bosses from it): add parameters with defaults.
- New models `art/models/foes/vb_<kind>.glb` (+ their `.import`) and scenes `art/blender/vb_<kind>.blend`.
- The `_build()` of each enemy script in `core/enemy/` (wretch, husk, crawler, leaper, spitter, ossuant, shade, gaunt,
  quiller, bulwark, chanter, burrower, mite, tollman, pilgrim, cinder_caster, brood_mother) and a small lookup like
  `BossKit.AUTHORED` for foes (put it in `core/enemy/grunt_model.gd` as `const AUTHORED := {...}`; the prefetch and
  warm paths that load grunt GLBs should load these instead when present).
- Your checklist: `docs/r39/blender_enemies_backlog.md` (create it; keep it current after every kind; it is how the
  lead resumes you if your context runs out).

You do NOT touch: the bosses (`bone_abbot`, `anchoress`, `ascended_warden`, `hierarch_voice`, `thornwarden` and their
`*_body.gd`), `clip_rig.gd` beyond small additive changes you list in your report, the AI or the numbers of any
fight, lighting, quests, UI, `world/main.tscn` (never headless-rebake it).

## The bar

- The villagers' build style, which Luke approved for the bosses: soft, chunky, painted, readable forms; sRGB tint and
  baked AO in the vertex colour, UV in metres, UV2.x the material layer (`vb_kit.LAYER`), worn in game with
  `DwarfLook.material_boss` through `ClipRig`'s `villager_look`. Not the old metaball sculpts, not boxes and tubes.
- Each kind its own creative design that fits its lore (read the header comment of its script in `core/enemy/` and
  its current GLB's design notes in `tools/blender/grunt_*.py` / `biped_*.py`), a silhouette you can tell apart in
  the dark at 30 m, colour breaks and materials (cloth, bone, iron, wood, chitin, wax) and secondary detail that reads
  at a person's size: hems, straps, buckles, rags, horns, tusks, wear, moss.
- One continuous skinned mesh per kind with real anatomy and drapery, weighted across the joints so nothing cracks.
- Size and proportions keep each kind's collision and reach: match the old rest height and stance (measure the
  current GLB in Blender or read the kind's `scale`/`cap` in its `_build`), so the fights still work.
- Budget: 6k-18k triangles per kind (a mite 3-5k, a brood mother up to 25k); one body material and at most one glow
  material (two draw calls); no textures beyond the shared villager detail maps.
- Animation smoothing is critical (memory, 17 Nov): no pops or snaps. Bezier keys with anticipation, overshoot and
  settle; looping clips that close on the same pose; cloth chains on skirts, rags and tails with follow-through.

## The clips every kind needs

`idle` (alive: breath, weight shift, the head looking round; looping), `walk` (looping, stride matched to
`walk_stride`), `run` where the kind runs (looping; set `run_at` / `run_stride` in `ClipRig.fit`), `windup` +
`windup_hold` (the tell, held until the blow) and `strike` (the blow lands in the first 0.1-0.2 s), `stagger`,
`howl` (the call / cast), `death` (falls and stays down). Kinds with their own moves get clips named for them and the
kind calls `boss_move(&"<clip>", dur)` the way `anchoress.gd` `_rite()` does, falling back when it returns false:
the spitter's spit, the leaper's leap (`air` and `land` clips are read by `ClipRig._locomote`), the burrower's dig
and surface, the tollman's bell toll (the bell can be a bone), the chanter's chant, the bulwark's shield bash and
its shield breaking (the shield must still be breakable: read `bulwark.gd` for how it finds and removes the shield
node, and keep that working, for example a separate mesh on a bone named as before), the cinder caster's cast, the
brood mother's lob, spray and brood, the quiller's volley, the pilgrim's prayer. Four-legged kinds (crawler, mite,
burrower, brood mother, quiller if quadruped) get a quadruped skeleton; map their sockets in `ClipRig.fit` (`body`,
`front`, `muzzle`, `head`, `tail`) the way the fight code reads them (grep `socket(` in the kind's script and in
`enemy.gd` for the names it needs: weak points, muzzles, the hit flash).

## Workflow per kind (in this order)

1. Read the kind's script, its old GLB script and its current look (render the old GLB's turnaround in Blender if it
   helps). Write the design in two or three sentences at the top of `vb_<kind>.py`.
2. Build the body, skeleton and weights; export with `--renders <scratch dir> --no-ao` while iterating
   (`blender -b -P tools/blender/vb_<kind>.py -- --out <scratch>/x.glb --renders <scratch>`).
3. Review every render at full size: the turnaround (front, 3/4, side, back), the head close-up and posed frames of
   each clip. Be hard on it: anything crude, floating, intersecting, cone-like or flat goes back. Fix and re-render
   until it is good (Luke: "fix until happy"; no "partly worked").
4. Key the clips; render posed frames of each at the key moments and fix poses that read wrong (the sign conventions
   are in the Abbot script: X pitch, Y yaw, Z roll; `aim()` for held things).
5. Final export with AO into `art/models/foes/`, then wire the kind's `_build()` to `ClipRig.fit(...)` with
   `villager_look: true` when the GLB exists (else the old path), hook its own moves, keep its weak point on the right
   socket and offset.
6. Import (`godot --headless --path . --import --quit`) and check it in motion: `tools/play_capture.sh enemies_a`
   (sections enemies_a..d cover the kinds; `OUT=<scratch>`), read the strips frame by frame for pops, sliding feet,
   intersections and the tell reading before the blow. Fix and recapture.
7. Commit the kind on your branch (one commit per kind, a message that says what it looks like and which clips it
   has). Tick it in the backlog.

## Rules

- Commits come only from Luke: never add a `Co-Authored-By` line or any AI attribution to a commit message.
- One Godot process at a time on the machine: before any Godot run (import, tests, captures) take the lock
  `mkdir /tmp/umbral_godot.lock` (retry every 30 s if it exists) and `rmdir` it after. Never run the full suite;
  run `tools/run_tests.sh --quick` once at the end and the enemy tests `enemies_r31_test enemies_r33_test
  enemy_audio_test combat_qa_test` once at the end.
- Blender runs are light; keep at most one Blender process running.
- Never wait on a process with a pgrep loop. Delete scratch renders and captures when a kind is done (keep the disk
  clean; the Mac filled up once).
- Do not merge into master or push master. Push your own branch. The lead reviews your renders and merges.
- Zero perf cost: compare draw calls and triangles with the old GLB per kind and say so in the backlog; nothing
  allocates per frame; GLBs prefetch where the old ones did.

## Backlog (in this order; each item is done when its acceptance holds)

1. wretch (the most common foe): hunched hollowed villager in rags; idle, walk, run, windup/hold, strike (claw
   swipe), stagger, howl, death; acceptance: strips of enemies_a show every clip with no pop.
2. husk, 3. gaunt, 4. ossuant, 5. pilgrim, 6. chanter (chant clip), 7. tollman (bell toll), 8. bulwark (shield bash,
   breakable shield), 9. cinder_caster (cast), 10. quiller (volley), 11. spitter (spit), 12. leaper (leap: air,
   land), 13. crawler (quadruped), 14. mite (small quadruped, swarm), 15. burrower (dig, surface),
   16. shade (spectral: a glow material is fine for its wisps), 17. brood_mother (lob, spray, brood; the biggest).
For each: the design note, the renders reviewed, the clips listed, the triangle count against the old GLB, the
capture section checked, the commit hash.

## Report

Do not report until the backlog is exhausted. Then report: the branch name, the commit per kind, the triangle and
draw-call comparison, what you changed in `vb_kit.py` or `clip_rig.gd`, the scratch paths of the final turnaround
sheets for the lead to review, and anything that did not reach the bar (say so plainly).
