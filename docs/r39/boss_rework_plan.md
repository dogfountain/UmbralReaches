# The great ones: a plan to make the bosses look good and move (18 Nov)

Luke, 18 Nov: "the bosses look bad and are static". This is the plan; nothing in it is built yet.

## What is wrong (from the code and the trailer footage)

**They are static.** Five bosses (Bone Abbot, Ascended Warden, Anchoress, Speaking Crown on `VillagerBossRig`;
the Thornwarden on `BeastRig`) share one pose vocabulary of six modes: idle, windup, strike, stagger, howl, death
(`villager_boss_rig.gd` `BLEND`, `beast_rig.gd`).
- Every signature move looks the same. The Abbot's Tolling, Bone Rain and Requiem, the Warden's Flare, Eclipse and
  Gale all call the same `howl` (both arms up); everything else is the one generic wind-up and strike.
- The Anchoress and the Speaking Crown never call their rig at all (`anchoress.gd`, `hierarch_voice.gd`: no
  `_rig.call`): her swings, toll, rockfall and undertow, its edicts, echo and falling crown, are the base enemy's
  wind-up/strike or nothing. They stand still while the floor lights up round them.
- The idle is a slow breath and a stoop. No weight shifts, no head following you, no hands, no hover drift.
- Nothing hangs or swings. Robes, mantles, the Abbot's candles and cord, the Anchoress's chain and anchor, the
  Warden's mandorla are rigid parts of one skinned mesh: a house-sized robe that never moves reads as a statue.

**They look bad.** The bodies are code-built from villager primitives (`*_body.gd`: lofts, tubes, blobs).
- At 3-5x scale the villager detail maps and smooth lofts become flat grey cones (the Anchoress is a plain bell of
  cloth with tube arms; the Crown a bell with a ring; the Warden a white cone with a halo).
- One material family, few colour breaks, no cloth folds, hems, trims or wear: nothing for the eye at size.
- Silhouettes are similar (four of five are a robed cone), so you cannot tell them apart in the dark.
- With the emissive rims gone (18 Nov, the grey sheen), some read too dark where no fire reaches them.
- Note the standing bar (memory, 9 Nov): hero assets are modelled in Blender with a render review; code-built and
  box art were rejected. The current bosses are code-built, which is the root of the "look bad".

## Goals (and limits)
- Keep Luke's direction: the villagers' build *style* (soft, chunky, painted, readable), each boss its own creative
  design, 4-5x a person. Not the old sculpted look, not copies of anything.
- Every boss alive at rest and every move its own readable pose with anticipation, follow-through and settle.
- Animation smoothing rules hold (memory 17 Nov): no pops or snaps, dt-damped blends, verified with frame strips at
  60 and 144 Hz.
- No perf cost: per boss at most +2 draw calls, cloth by bone springs on the CPU only for the boss on screen, no new
  per-frame allocation (the Thornwarden's pose table fix stays).

## The work

### 1. A move library per boss (the "static" fix; biggest win, no new art needed)
- `VillagerBossRig.play(move, dur)`: data-driven poses per boss (a table of keyed poses: hands, spine, head, root,
  per key a time and an ease), on top of the existing smoothing. The six shared modes stay as the fallback.
- Each fight calls its own moves at the right moment (the same hook points that fill the floor red now):
  - **Bone Abbot:** Tolling (crozier struck on the floor twice, the body jolting), Bone Rain (claw raised, fingers
    spread, a slow turn), Grave Spikes (crozier driven down, crouch), Sweep (a wide two-handed scythe of the
    crozier), Requiem (arms out, head back, rising onto the toes), Tithe (beckoning claw), the intermission sink.
  - **Ascended Warden:** Fan (a sword-arm sweep left to right tracking the cone), Judgement (two-handed overhead),
    Mandorla Flare (the halo flung wide, arms opening), Eclipse (hands cupped over the head, slow), Gale (both
    arms pushing forward, robe streaming), Ascend/Descend (float up with legs trailing, land with a crouch).
  - **Anchoress:** Swing and Double Swing (the anchor hauled up over the shoulder, a full-body heave, the chain
    whipping), Chain Ring (the anchor spun round her on its chain), Toll (the anchor dropped like a bell clapper),
    Rockfall (a stamp that shakes her), Undertow (a two-handed haul toward her).
  - **Speaking Crown:** Edict (the horn-head tipping back and the mouth opening, the husk bracing), Echo (a
    shudder), Falling Crown (the head shaking, shedding), Verdict, the Husk fist and rake.
  - **Thornwarden (BeastRig):** Pounce, Lash, Snare, Thornstorm (rearing), Thorn Lanes (raking the ground), Rooting
    (legs sinking in), Bloom, Sap Mending (curling up).
- Telegraph poses hold until the floor marker fills, so the body and the danger agree.

### 2. Life at rest
- Idle layer: weight shifts foot to foot every few seconds, head and eyes tracking the wanderer (clamped), hands
  flexing on the weapon, a size-scaled breath (a big chest moves visibly), hover drift for floaters.
- Turn in place with steps (no sliding), stride and pelvis bob scaled to the body.
- Hit reactions by side and weight (a small flinch on light hits, a stagger lean on heavy).

### 3. Secondary motion
- Spring bones (a damped spring per chain, computed only while the boss is on screen): robe hem (a ring of 6-8
  bones), mantle edge, sleeves, the Abbot's cord and tally bones, candles, the Anchoress's chain and anchor
  (pendulum with the swing), the Warden's halo (lags turns), the Thornwarden's tail and thorns.
- Skinned onto the existing skeleton as extra bones; the mesh skin weights extended for the hem and mantle.

### 4. The look (models)
- Rebuild each body as a modelled hero asset in Blender, in the villagers' style, skinned to the same skeleton and
  exported to GLB, with a render review before integration (the 9 Nov bar). Each gets:
  - a distinct silhouette (no more four cones): the Abbot hunched and horned, the Warden tall and winged by the
    mandorla, the Anchoress broad and chained, the Crown a husk with a huge horn, the Thornwarden low and long;
  - cloth that reads at size: big folds, layered hems, torn edges, trims and belts, painted wear;
  - colour breaks and materials (cloth, bone, iron, wax, stone) with detail tiles scaled for a 4-5x body;
  - phase states as visible change (cracks that glow, a torn robe, a broken crown) by material params, not swaps.
- Tooling: the Claude Blender connector (Anthropic + Blender Lab) would let this be modelled live in an open scene
  with renders checked each step; without it the existing headless `tools/blender/boss_*.py` path still works.
- Lighting: a boss-local warm key and fill tied to each arena's own fires, so they read without emissive rims.

### 5. Verification
- Per move: a frame strip at 60 and 144 Hz (play_capture bosses sections), checked for pops.
- A boss smoothness probe like `smooth_probe` for the bones (repeats and jumps per frame).
- The tests that cover the fights (boss_test, raids_r34, the boss theme test) and the full suite.
- Perf: draw calls and frame time in each arena against today's numbers.
- A trailer shot per boss showing a signature move, reviewed frame by frame before it is sent.

## Order
1. The move library and idle life for the four villager-rig bosses (no art; the biggest visible change). Then
   the Thornwarden's beast moves.
2. Spring-bone secondary motion.
3. The model rebuild, boss by boss (Abbot first: the most fights), each with a render review before it goes in.
4. Phase visuals and arena lighting.
5. Film every move, test, measure, then a short boss trailer.

## Decided (Luke, 18 Nov)
- "Modeled blender assets like all other assets, all models in the game should be blender." The bosses are rebuilt
  in Blender (step 4 above is in), and the same rule now covers every model in the game (below).
- Seen in the trailer: two bosses showed no animation at all. They are the Anchoress and the Speaking Crown (no rig
  calls in their fights); they go first in step 1.

## Every model in Blender (the game-wide program)
Today about 123 scripts build geometry in code through the kits (OssKit boxes, WonderKit, DwarfMesh / CreatureMesh
lofts, RockKit, TreeGen): 65 in the Realm's places and POIs, 19 in the r39 wonders (the landmarks), 25 in life (villagers,
wildlife, secrets), 13 enemies and bosses, 6 people (the dwarves), 5 in the Ossuary. 730 GLBs already exist under
art/models (112 props). Each family moves to Blender-authored GLBs, one at a time, each with a turnaround render
reviewed at full size before it goes in:
1. **Bosses** (this plan): skeleton, mesh and keyframed clips in Blender, one boss at a time, shown to Luke before
   the next.
2. **Enemies and the people** (grunts, villagers, dwarves, wildlife): one skinned mesh each on a shared skeleton per
   body type, clips in Blender; the villager look kept as the style.
3. **Landmarks** (the Sleeper, the Hollow King, the Salt Ship, the Wardens' towers, the Chain Span, the Titan Gates,
   the caves and deep halls): modelled set pieces with near and far meshes; their placement code stays and loads
   the GLBs instead of building boxes.
4. **Architecture and POIs** (cottages, towns, ruins, the Ossuary): a modular Blender kit (walls, roofs, doors,
   stairs, trims) so the existing layout code assembles modelled pieces.
5. **Props, rocks and trees** (crates, barrels, stalls, boulders, cliffs, trees, undergrowth): Blender libraries with
   LODs, swapped in by key so the scatter and dressing code is unchanged.
Rules for every family: in-house only, the villager/Enshrouded-style look, LODs and a far mesh, no new draw calls
per instance (MultiMesh stays), GenCache for anything derived, and the frame-time tour against today's numbers
after each family lands.

## Still to decide
- The Blender connector (Anthropic + Blender Lab) for live modelling with renders each step, or the headless
  `tools/blender` scripts as now?
