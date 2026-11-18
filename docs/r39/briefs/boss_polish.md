# r39 brief: polish every boss heavily, in every way, and grow its arena 1.6x

Luke, 18 Nov, after the five bosses were rebuilt in Blender (the Bone Abbot, the Anchoress, the Ascended Warden, the
Speaking Crown, the Thornwarden): "just polish all bosses in all ways heavily, spawn an agent for each boss. And
expand their arenas 1.6x." He also said the Anchoress keeps her chains (her 48k triangles stay; no measurable frame
cost). Earlier the same day: "the bosses look bad and are static"; "all models in the game should be blender";
the Abbot was "decent". The regular enemies stay as they are (do not touch them).

You are one of five agents; each owns one boss end to end. Read this brief end to end, then your own section, then
`docs/r39/boss_rework_plan.md`, `AGENTS.md` and `.cursor/skills/umbral-donts`. Keep a live checklist at
`docs/r39/boss_polish_<boss>.md` (your backlog with a tick per item and a line on what you did); it is how the lead
resumes you if your context runs out. This should take you many hours. Do not report until your backlog is exhausted.

## Where you work

- Your own APFS clone of the repository, already on your branch: `/Users/luke/UmbralReaches_boss_<boss>`
  (branch `boss-polish-<boss>`). Work only there (`cd` into it for every command; never touch
  `/Users/luke/UmbralReaches` itself). Commit there; do not push; the lead fetches your branch from that folder.
- The `.godot` import cache is already there; `godot --headless --path . --import --quit` after adding assets.

## What you own (only these; edit nothing else)

- Your boss script(s) in `core/enemy/` and its old `*_body.gd` (the fallback), your `tools/blender/vb_<boss>.py`,
  its `art/blender/vb_<boss>.blend` and `art/models/bosses/vb_<boss>.glb` (+ `.import`), any new files you add
  for your boss (VFX scenes, shaders, sounds, helper scripts named for your boss), and your arena's files (listed
  in your section).
- Your boss's entry in `RealmLayout.RAIDS` (`core/world/realm/realm_layout.gd`) if your arena is a raid site: only
  your own two lines.
- Shared files are READ-ONLY for you: `tools/blender/vb_kit.py`, `core/enemy/clip_rig.gd`, `core/enemy/boss_kit.gd`,
  `core/enemy/enemy.gd`, `core/world/boss_arena.gd`, the other bosses. If you need a kit helper, copy it into your own
  script. If you need a change in `clip_rig.gd` or `boss_kit.gd` (for example spring bones in ClipRig), write the exact
  patch into your checklist under "For the lead" and work round it meanwhile; the lead applies it to all.

## The bar

- The villagers' build style Luke approved: chunky, painted, readable forms; vertex tint plus baked AO, worn with
  `DwarfLook.material_boss` through `ClipRig`'s `villager_look`. Enshrouded is the reference for craft and density
  (secondary and tertiary forms, wear, trims, layered materials), not for copying anything.
- "Fix until happy": render, look at every image at full size with the Read tool, be hard on it, fix, render again.
  Nothing crude, floating, intersecting, cone-like, flat or toy-like. No "partly worked".
- Animation smoothing is critical: no pops, snaps or stepping; anticipation, follow-through and settle on every
  move; verify with frame strips in game (`tools/play_capture.sh bosses_a|bosses_b|bosses_c`, `OUT=<scratch>`), at the
  moments that matter, frame by frame.
- Zero perf cost beyond what a boss already costs: at most two draw calls for the body (body + glow), no new
  per-frame allocation, lights within the arena's budget (no new shadowed lights), nothing that hitches on first use
  (prefetch through the arena's warm-up). Frame stutter is Luke's top complaint.
- The fight must still work: its tests pass, every mechanic reads (the body and the red on the floor agree), and its
  numbers scale with the bigger arena.

## Polish, in all ways (your backlog starts from these; add what your own critique finds)

1. **Critique first.** Capture your boss's section in game and render its turnaround. Write a hard critique in your
   checklist as each of: creative director, combat designer, animator, character artist, environment artist,
   tech artist, VFX, sound, UX, QA, perf. Each finding becomes a backlog item with acceptance criteria.
2. **Model.** More craft: silhouette from 40 m, secondary forms (trims, straps, buckles, folds, tears, wear), tertiary
   detail (studs, stitching, chips, moss, wax drips, rust), colour breaks, a face or mask that holds a close-up.
   Phase states as visible change (cracks that glow, torn cloth, broken parts) by extra geometry shown or hidden,
   or by vertex data the material reads, not by swapping models.
3. **Animation.** Every clip re-keyed and checked in strips; more life at rest (weight shifts, breath scaled to size,
   head tracking), turn in place, hit reactions, a proper intro (the boss rising or turning to you as the fight starts)
   and a long death. Secondary motion on cloth, chains, tails and halos (keyed follow-through now; spring bones if the
   lead applies your ClipRig patch).
4. **Moves and VFX.** Each move reads at a glance: a tell, a strike and a settle in the body, and effects that match
   (dust, sparks, embers, light) using the game's existing Vfx/SpellFx/BossKit calls. No new shader per effect unless
   unavoidable.
5. **Sound.** Footsteps, cloth, chains, voice per move through the existing Sfx/Synth systems (read `docs/r39/sound.md`).
6. **The arena, 1.6x.** Grow the floor radius 1.6x (and everything placed by it: walls, pillars, cairns, pylons,
   stones, cover, lights, the gate) and rescale the fight's radii that refer to the room (ring sizes, lane lengths,
   arena_r, pull ranges, spawn points) so it plays as well or better. Check the bigger footprint against its
   neighbours: roads, towns, other POIs, cliffs, water, the approach path and the nav bake. Dress the new ground
   (in-house props and Blender assets only), keep the lighting "dark night, bright landmarks" (fires and mystery lights
   that read from afar).
7. **Verification.** Your boss's capture section clean and every strip reviewed; the tests that cover your fight pass
   (see your section); `tools/lint.sh` passes (it is a ratchet: never add `.call("x")`, `has_method(`, `.get("_x")`
   or round tags; a file over 1000 lines may not grow more than 50 lines); `tools/run_tests.sh --quick` passes.

## Machine rules (Luke's PC crashed once under too many processes)

- At most one Godot and one Blender process on the machine at a time, shared with the other agents and the lead:
  before any Godot run take `mkdir /tmp/umbral_godot.lock` (retry every 30 s while it exists), `rmdir` it when the run
  ends, also on failure; before any Blender run the same with `/tmp/umbral_blender.lock`. Hold a lock only for the
  run itself. Never wait on a process with a pgrep loop.
- Never run the full suite (the lead does). Never rebake `world/main.tscn`.
- Scratch goes in `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/<boss>/`;
  delete renders and captures as each item is done (the disk filled once).
- Commits come only from Luke: never add a `Co-Authored-By` line or any AI attribution to a commit message.

## Report (only when the backlog is exhausted)

Your branch and its commits, what changed in the model, animation, moves, sound and arena, the arena's old and new
radius and what you moved, triangles and draw calls before and after, the tests you ran and their results, your
"For the lead" patches, the scratch paths of final turnaround sheets and strips for the lead to review, and anything
that did not reach the bar, said plainly.

---

## The Bone Abbot (`abbot`)

Owns: `core/enemy/bone_abbot.gd`, `abbot_body.gd`, `tools/blender/vb_bone_abbot.py`, his glb/blend, and his crypt:
the Ossuary's pit hall `world/areas/ossuary/oss_hall.gd` and what builds round it (`oss_frame.gd`, `oss_kit.gd`
where it places the hall's own pieces, `oss_deep.gd` only if the hall reaches it). The crypt is an interior: grow the
hall's floor and the mound 1.6x across, keep the stair and lift that lead into it working, keep the Ossuary's other
rooms and the land around it (`core/world/realm/ossuary_ground.gd` is read-only; if the bigger hall needs the land
fingerprint changed, say so for the lead). The fight reads `Hall.WC`, `Hall.MOUND_TOP` and the bell positions: keep
them consistent. Tests: `boss_test crypt_r34_test boss_theme_test quests_r34_test`. Capture: `bosses_a`.
Ideas from the critique so far: the robe read greyish under the crypt's key light; the toll should feel heavier (the
body jolting at each strike of the bell); Bone Rain and Tithe are weaker poses than the rest.

## The Anchoress (`anchoress`)

Owns: `core/enemy/anchoress.gd`, `anchoress_body.gd`, `tools/blender/vb_anchoress.py`, her glb/blend, her
`RAIDS` entry ("anchorhold", r 18 -> 28.8), and the room built in `core/world/realm/realm_pois_east_marches.gd`
`_anchorholds()` and the functions it calls (only those). The terrace is on a cliff: growing it 1.6x must not cut
into the cliff's road or the Marches' other POIs; the four hermits' cairns (the Undertow's lee) move out with the
floor. Tests: `layout_r34_test raids_r34_test boss_theme_test enemy_audio_test sound_rework_test`. Capture:
`bosses_c`. Ideas: her face (a pale blindfolded face in the hood) is the weakest part; the Undertow should show the
anchor biting the floor and the chain going taut; the Chain Ring should swing the anchor much wider (a longer chain in
the whirl, or the chain paying out); her feet show at the hem as dark lumps.

## The Ascended Warden (`warden`)

Owns: `core/enemy/ascended_warden.gd`, `warden_body.gd`, `warden_peal.gd`, `tools/blender/vb_ascended_warden.py`,
its glb/blend, its `RAIDS` entry ("summit", r 28 -> 44.8), and the summit deck `core/world/summit_raid.gd` and
`core/world/summit_dress.gd`. The deck is built over the chasm with the Crowns cut back behind it ("clear" mode):
a bigger deck needs its supports, rails, broken edges (the Gale pushes you toward them), the four pylons
(`PYLON_R`), the stars and the crossing's arrival (`SUMMIT_WARD`, the seal) to stay right. It is the final boss: the
story's beat (`core/story/story.gd`, read-only) must still fire. Tests: `boss_test boss_theme_test act2_test
story_test`. Capture: `bosses_b`. Ideas: the ivory washed out under its own halo light; the wing rays look like palm
fronds; the mask is plain; the phase III "halo breaks open" should be visible on the model.

## The Speaking Crown (`crown`)

Owns: `core/enemy/hierarch_voice.gd`, `crown_body.gd`, `tools/blender/vb_speaking_crown.py`, its glb/blend, its
`RAIDS` entry ("hierarch", r 24 -> 38.4), and the split skull `core/world/hierarch_raid.gd` (the toppled colossus's
broken crown in the Siege Lines). Growing it 1.6x means the skull's walls, the tiara stones that fall, the cantors'
cracks and the camps of the Siege Lines round it (read the siege POIs; move nothing of theirs: if the skull overlaps
them, say so). Tests: `layout_r34_test raids_r34_test boss_theme_test quests_r34_test`. Capture: `bosses_c`. Ideas:
the body reads toy-like and plain (a grey stone bell with stumpy legs); give it the weight of carved church stone
(reliefs, saints worn smooth, iron bands, a broken edge), bigger meaner fists, and make the horn the focus.

## The Thornwarden (`thornwarden`, started after the first agent finishes)

Owns: `core/enemy/thornwarden.gd`, `thorn_body.gd`, `tools/blender/vb_thornwarden.py`, its glb/blend, its `RAIDS`
entry ("henge", r 31 -> 49.6), and the henge `core/world/henge_raid.gd` and `core/world/thorn_henge.gd` (the stones,
the maze stages, the knots, the altar). The henge sits on a levelled hill crown; growing it 1.6x reaches down the
hill: the ring of standing stones (`STONE_R`), the knots (`KNOT_R`), the maze, the walls and the pilgrim stair must
all move with it. Tests: `boss_test raids_r34_test boss_theme_test`. Capture: `bosses_a`. Ideas: the lower legs read
as stilts; the body is a plain barrel under the bark scales; the antlers need more mass and a silhouette from afar;
the gallop and pounce should feel like a huge animal (weight, overshoot, dust).
