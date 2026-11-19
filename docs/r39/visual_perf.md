# r39 visual and performance: the brutal critique, then the fix (live checklist)

Luke, 18 Nov: "After combat you need to do a visual agent, same model with extra, brutally critiquing looks and performance
to improve." Brief: `docs/r39/briefs/visual_perf.md`. Branch `visual-perf` in `/Users/luke/UmbralReaches_visual` (from
master 6e482d4c). This file is the live checklist: every finding, its evidence, its fix and the commit. Resume from
"State" below.

Scratch `<S>` = `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/visual_perf/`:
`gd.sh` runs Godot under the machine lock with a watchdog, an isolated HOME and the clone's warm Realm cache; `cap.sh` the
play-through capture (one section a run), `ma.sh` the map audit's shot harness, `profile.sh` the profile, `bl.sh` Blender
under its lock, `pc.sh` the parse check. `base/` holds the baseline evidence (`perf_tour.log`, `play/<section>/`,
`ma/`), `after/` the re-capture, `pairs/` the kept before/after pairs.

## State

- [x] baseline perf tour (`<S>/base/perf_tour.log`; the harness fixed first: a conversation opened by itself froze every
      later view, see H1)
- [x] baseline stills and strips (`<S>/base/play/`: regions_a/b, places, villagers, spells, wanderer, bosses, ui, warmth,
      enemies_a)
- [x] the inherited P0s reproduced and fixed (below; P1 found with `zz/visual_probe.tscn` and closed, P2 not reproducible; P4 the Count door improved but not closed: see "Not fixed")
- [x] profile of the worst places (`<S>/base/profile_hitch.log`, `profile_attrib.log`, `spawn_cost.log`)
- [x] critique written by seat (below)
- [x] every fix made (the rest are in "Not fixed", each with its reason)
- [x] one re-capture pass (`<S>/after/play/`: regions_a/b, places, spells, bosses_a, ui; `<S>/after/ma/`, `ma2/`: the models' places and the Ossuary's interiors) and one final perf tour (`<S>/after/perf_tour.log`)
- [x] the tests at the end: `tools/run_tests.sh --quick` 27 of 27; the 27 world tests that cover what the pass touched (crypt_r34, floor_fight, raids_r34, boss, arena_gate, placement, realm_lore, world_poi, places_r34, r36_world, towns, village, layout_r34, lore_codex, trail_route, spawns, encounters, lamps, star_crater, combat_qa, combat_r31, grounded, robust, world_r30, world_r33, nav, nav_reach) 26 of 27 at first: encounters_test's camp-refills check looked in the rest's own frame, and the refill now raises its pawns one a frame; the test waits the queued frames (3eeb272b, the check unchanged) and passes

## Harness fixes (not findings; they made the evidence trustworthy)

| ID | What | Fix |
|---|---|---|
| H1 | `zz/perf_tour`: a found start's conversation opened by itself near Reedholm and paused the tree; every later view (the towns, the Far Reaches, the path) measured one frozen camera ("120 fps, 2126 draws" everywhere) | the tour closes a self-opened dialogue or offer and unpauses (`_unpause`), and holds Gloom and wounds at 0 (the wanderer was hollowed mid-tour at the Long Arches) |
| H2 | `zz/combat_strip`: the walk-in start for a boss stood at the arena's radius + 14 m at deck height; the 1.6x summit's radius put it over the rift, so every Ascended Warden fight began with a fall into the lava (the inherited "Warden-fight lava burn", see P3) | the start steps in until a ray finds ground |

## Inherited from the map audit and the combat pass (P0: fixed first)

| ID | What | Reproduced | Cause | Fix | Commit |
|---|---|---|---|---|---|
| P1 MA1 | The pit hall's wall can be walked through (falls to y -58) | yes: `zz/visual_probe --only=hallwalk` (walking out on 72 bearings, a shove fan at 4 m/s): the body leaves the hall at the three chapels (NE, SE, NW), +-5 degrees off their axes, and falls to y -51 .. -60; `--only=chapel,apse,probebody,deadzone`: walking into an apse it loses every contact at 42.9 m (the floor and both walls at once) and sinks through the floor; a body put at rest there falls; rays and shape queries still meet the floor (its faces are there, `VaultBody`) and convex boxes laid over the same floor and walls do not hold it either; a fresh CharacterBody's own `test_move` fails in the same band (the last ~1 m of each apse) | not found to the engine line: Jolt's motion queries lose the apse's end (the floor's last metre, its end and the walls round it) for a body standing there, while space queries keep it; not the visibility gate, not the occluders, not degenerate faces (removed anyway), not the internal-edge setting | the apses' ends closed by a charnel wall of skulls 2.6 m high (past a mantle) 1.4 m deep behind each Tally, so no body stands in the band; the walls' feet sunk into the floor slab; the apses' floors and walls also as convex solids; zero-area faces out of every OssKit collision; and a catch band under the whole hall's footprint returns any body that gets under the floor (tested: a body put under the floor is back on the inner disc in 5 frames). After: the walk fan stops at the charnel walls (r 42.1, at floor level), no fall | 490d5b3c, 667b8178 |
| P2 MA4 | The Crown's siege yard drops the wanderer through the ground near (-216.8, 169.7) | not reproduced: `zz/visual_probe --only=crown,crownwalk`: no hole in a 1 m ray grid to 46 m round the yard (0 of ~6,600), the Rift Step fan from rings to 31 m never ends under the ground, and walking out on 72 bearings for 5 s from the yard's centre, (-207.5, 171.6) and (-216.8, 169.7) never goes under the land (0 of 216) | the one mechanism that can put the body under the ground there is the Rift Step's landing in a crevice's mouth (the capsule settled inside the rocks and the depenetration pushed it down; the same rocks put the camera in the stone, MA2) | a Rift Step backs its landing off along the step until the body has headroom (`player_evasion._rift_target`) | 8931b182 |
| P3 | ~8.3 s into every Ascended Warden fight a 35-wound lava burn at (314.1, -15.2, -60.6) | yes (`<S>/p0/warden_tp.log`: a teleport trace) | the harness (H2): `_stand(far)` put the wanderer over the rift at f386; he fell into the lava at f509 and was thrown back to the spawn; the strip then stood him on the deck. No game code moved him | H2 | 333c7cfe |
| P4 F27 | The Count door: a pale void through the CountCut down the Counting Stair | yes (`<S>/pairs/P4_count_door_before.jpg`): right of the shaft a pale flat sheet with a black curve | not the occluders (`--no-occluders` shows the same), not a hole in the collision (`visual_probe --only=countdoor`: every ray from the threshold's eye meets the door's front or the bank); the quarry's east face south of the shaft has no wall, and the pit's pool there is the Realm's open-water sheet, which takes the vortex sky (pale) | a face of great rock slabs from the pool to the crest on the bank's foot south of the shaft (`ossuary.gd _count_bank`, clear of the threshold, the stair and the gallery), the cut's face and cap carried over the whole lifted hole (`_count_skirt`), and a black still-water face over the pit's pool. **Not closed**: the re-capture (`pairs/P4_count_door_after.jpg`) shows the bank's new face from the side and from above, but from the threshold's own eye, right of the shaft, the pale sheet still shows where the door's south side should be; the rays meet the door's front there (`CountDoorBody`) and its mesh is present and drawn (`--only=countvis`), so what draws the sheet over it is still to find (the Realm's water sheet, `FenWater`, is the suspect). Left for the Ossuary's own round, with the probe sections to start from | d04baa63 |
| P5 MA2 | The Crown's earthwork puts the camera inside rock | by code | the boom's full-shoulder pivot stood inside the rock beside the wanderer; the arm's sphere cast started there and finds nothing from inside a solid | the pivot must be seen from the head (a ray), else the boom swings in behind the wanderer (`player_camera.gd _shoulder_tick`) | 8931b182 |
| P6 MA3 | The henge's 16 great stones crowd the camera | `bosses_a/thornwarden_p1_thornstorm_3q.png` (a stone and its briars fill the right third) | the stones are 2.6 m wide and solid to the boom | the camera passes through them (`Groups.CAMERA_PASS`, the boom's casts exclude them) and they dissolve near the lens (`RockKit.fade_material`: a fine dither 3.5 -> 1.2 m, its own shader so no other rock loses early depth) | 8931b182 |
| P7 | A frame of ~960 pipelines, 120-140 ms, ~6 s after load: the post-build mesh merge | `base/perf_tour.log`: "ATMOS merged 2977 static meshes into 2701 (850.6 ms)" in ONE frame under the cover (the bar froze); without the cover (every harness) it lands in play | (a) the pass ran in one frame; (b) the merged meshes were plain float arrays where their glTF pieces were compressed (16-bit positions, octahedral normals): a second vertex format for every material, so every material compiled its pipelines again the first time a merged mesh drew | the merge yields every 5 ms (`MeshMerge.SLICE_US`, the scan of held meshes too) and a merged mesh keeps its pieces' attribute compression (`_compressed`: the format joins the merge key), so it draws with the pipelines its pieces already compiled | ccf49b2b |
| P8 | The first `boss_engaged` costs 18.6 ms once | by probe (`zz/visual_probe --only=engaged`: every listener called alone costs 0.13 ms in all) | not the listeners: the pull's frame raises the boss's name card (BossTitle: 64 px glyphs rasterised for the first time) and the bar's outlined labels | the loading cover warms a name card with every letter and the bar's three label sizes (`panel_warm.gd _boss_cards`) | 9b6e3999 |
| P9 | The Rift Step's tear ~3 m from the lens covers a fifth of the frame for 0.3 s | `combat/V1/warden_s43.jpg` | the departure tear of a forward step stands 3 m in front of the camera; its black void and sixteen half-metre smoke cards blot the view | the void thins from 7 m in and is gone by 2 m, the seam thins to a third (`rift_tear.gdshader`); the dark puff is smaller and fainter near the lens (`SpellFx.rift_out`) | d50e43f2 |
| P10 | A large white blob at the wanderer's hands in combat strips | `combat/R8/flank2_s04.jpg`; `base/play/spells/wanderer_cast_lance_full_3q.png` #8-#14 | the Ember Lance's charge orb and its halo: a white-hot 0.46 m sphere (colour 4.2, 3.4, 2.4 at full) and a 1 m additive halo, bloomed | a coal: 0.26 m at full, ember-orange (hotter, not whiter), the halo 0.4 m and fainter (`player_casting.gd _charge_vis`) | 2479cb1d |
| P11 | Pale orbs at eye level (pit hall, Hearthward meadow) | `pairs/F01_pit_hall_after.jpg`, `F20_meadow_post_after.jpg`; `places/close_oak.png` (fireflies) | the moths (`light_moths.gd`) and the fireflies (`firefly.gdshader`) are soft round additive dots with no near falloff: one passing within a metre of the lens is a fist-sized ball | moths are drawn as moths (two pairs of wings) and fade out within 2.6 m of the camera (pixel distance fade); fireflies fade within 2.5 m | bee1a99b |
| P12 | The pit hall is nearly black away from the reliquary | `places/arena_bone_abbot.png`, `pairs/F01_pit_hall_after.jpg` | the hall's own seven lamps lost LightDirector's budget to the hundred candle clusters near the camera; the bays' pools ended at the balustrade, the corona's was spent on the vault; and east of local x 86 (the NE and SE chapels, a third of the floor) the hall was not drawn at all (its visibility gate dated from before the hall grew) | the hall's lamps keep first place in the budget (meta `ld_prio`), the corona +1/3, the bays' pools to 13.5 m, the mound's ring to 9 m (no new lights); the gate covers the whole hall's box | 490d5b3c, 667b8178 (gate) |
| P13 | The Resonance popup ran off the screen | `combat/V1/warden_s41.jpg`: now two lines, inside the view, but a 12-letter pink word set big over the boss | the word popped big (RESONANCE_BIG) at the shoulder, so it sat over the foe | small, muted violet, beside the wanderer on the screen's left (`skill_book.gd`) | 9280eb6b |

## The critique (by seat)

Evidence: `<S>/base/play/` (the play-through capture at night through the real camera and grade: 32 + 48 region stills,
30 places, the spell, wanderer, villager, boss and UI strips), the map audit's and the combat pass's kept sheets, and
`<S>/base/perf_tour.log` (53 views, vsync off; the Mac's display still caps at 120). Nothing below is fine. Format:
**ID (severity)**, what, where, why it matters, what good looks like, the fix (filled in as it lands).

### Art director

- **AD1 (P0) The world is built in two styles, and the worse one is everywhere.** Hearthward's timber, plaster and slate
  (`places/close_hearth.png`, `regions_a/region_hearth_1.png`) are the game; the kit-built ruins, towers, cairns, cells,
  plinths and walls (`region_rift_0`, `region_foundry_0`, `region_quarry_0`, `regions_b/region_southwood_0`,
  `region_anchorholds_0`, `region_lanternwood_0`) are box art with a checkerboard texture. From 20 m every kit wall reads
  as a pixel grid (`tex/rev_old/oss_ruin_far.png`). Enshrouded's ruins are the opposite: chunky, worn, rounded stones that
  catch light on their arrises, the same family as its houses. Fix: the kit's masonry sets rebuilt (EN1) and the F28
  structures modelled in Blender (M1-).
- **AD2 (P1) One hue band.** Most unlit frames sit in a single blue-teal band: grass teal-mint, leaves teal, stone blue,
  sky violet-blue (`region_road_0`, `region_thornwood_0`, `vista_west_marches`). Warm exists only at fires. Enshrouded's
  night keeps local colour (moss green, wood brown, stone grey-ochre) under a cool key. Fix: LA1, EN3, EN4.
- **AD3 (P1) Out-of-palette accents that read as UI, not world**: neon-cyan mushroom gills (`region_lanternwood_0`), a
  pure green glimmer orb on the square (`close_hearth`), radioactive-green moss on the summit deck (`region_summit_0`), blue
  ring "eyes" on the quarry's frames (`region_quarry_0`), the summit orb's white eight-ray star (`vista_realm_from_se`).
- **AD4 (P1) Clay and void materials.** Smooth untextured shapes: the summit's bell and statue (`region_summit_0`), the
  King's Barrow dome (`region_kingsbarrows_0`), the Cairns' bowl, the chapel's grey skeps (`region_chapel_0`), pure black
  roofs, frames and plinths (the kit's "dark" key: `region_glade_0` well roof, henge plinths, quarry frames).
- **AD5 (P2) The sky outshouts the land.** The vortex swirl is the brightest, most saturated thing in half the frames
  (`region_road_0`, `region_hearth_0`); the land under it is murk. It is the game's identity (keep it), but the land must
  hold its own: AD1, LA3.

### Lighting artist

- **LA1 (P1) Grass is still the loudest thing in the frame.** Pale mint tips over half the screen in every meadow
  (`region_hearth_0`, `region_rift_1`, `region_downs_0`), brighter than the path and the props. Good: grass darker than
  what stands in it, its tips catching the moon, not glowing. Fix: the grass value and tip lift down, green kept.
- **LA2 (P1) Pale orbs everywhere**: seventeen landmark "far glows" (`landmark_beacon.gd`) are 1.1-degree soft white balls
  sprinkled over every vista and the sky (`vista_realm_from_se`, `region_downs_0`, `region_hearth_1`); plus moths and
  fireflies near the lens (P11). They read as lens dust, not as places, and nothing tells a fire from a mystery. Good: a far
  fire is a small saturated flickering point; a mystery a cold, slow one. Fix: a 0.6-degree point in its own saturated
  colour with a short halo, flame flicker for warm ones, and a place's glow thins past 300-460 m (a great one's arena
  keeps its).
- **LA3 (P1) Landmarks do not read from afar.** From the summit (`vista_realm_from_se`) the Realm is a blue field with a
  few window specks; the towns are dim (`vista_hearth_from_south`); the Wardens' towers' cressets, the cells and the camps
  give nothing. Luke's direction: dark land, bright landmarks. Fix: LA2, and real light at the places (M-series models
  carry lit windows and fires).
- **LA4 (P1) The pit hall is black away from its mound** (P12).
- **LA5 (P2) The moon on the horizon blows out** into a white disc with a ray (`regions_b/region_saltmarket_0`,
  `region_rift_0`) and the summit orb is a white star (`vista_realm_from_se`). Good: a pale disc under the glow threshold.
- **LA6 (P2) A horizontal light streak** across the Holds' wall (`region_holds_0`): a window cone through the volumetric
  fog seen edge-on.
- **LA7 (P2) The rift's smoke column is a smooth dark sheet**, a black curtain over the summit and the Ascended Warden's
  arena (`places/arena_ascended_warden.png`, `region_rift_0/1`). Good: a column that is lit from below by the lava and
  breaks up into puffs, thin at its edges.

### Environment and material artist

- **EN1 (P0) Masonry reads as a voxel grid.** Root cause found in the textures themselves (`art/textures/oss_ashlar`,
  `oss_ruin`, `oss_brick`, `oss_floor`): perfectly rectangular flat-faced blocks, a strong per-block value jitter (0.24 on
  the ashlar) and black joints (the ruin's mortar was 0.01), so at 20 m the joints and the light/dark blocks make a
  checkerboard (`<S>/tex/rev_old/oss_ruin_far.png`). Every kit wall in the Realm uses these four sets. Good: Enshrouded's
  rounded, worn stones whose arrises catch the light. Fix: `tools/gen_arch_textures.py` masonry rebuilt: corner-rounded,
  pillowed faces that lean out of plane, worn lighter arrises, the per-block jitter cut to 0.07-0.09, joints a recessed
  grey mortar, rubble split into thinner stones, pale lichen rosettes on the faces (`<S>/tex/rev/oss_ruin_far.png`).
- **EN2 (P1) Kit box art everywhere** (the F28 list and more): stepped-block cairns and cells (`region_anchorholds_0`),
  box robots with orange slits (`places/arena_thornwarden.png`), cone flames on black box plinths (`region_henge_0`),
  stacked-block ruin walls by the road (`region_road_0`, with a pure black block in a pillar), the brick-box tines in the
  Crown's skull (`region_siege_0`), the mushroom house (`region_lanternwood_0`). Fix: M-series (Blender).
- **EN3 (P1) Tree crowns are one teal hue** (`region_thornwood_0`, `vista_west_marches`), bright on top; the far crowns are
  domes. Good: dark cores, lit tops, hue drift olive to blue-green.
- **EN4 (P2) Ground is one value** between places: the henge floor a flat dark disc (`region_henge_1`), the downs smooth
  dunes (`region_downs_0`), the Anchorholds a tiled beach. Litter and contrast missing.
- **EN5 (P2) Bark speckle**: the great oak's bark is a noise of white specks at night (`places/close_oak.png`).
- **EN6 (P2) The paving at the Ossuary's landing** is cartoon flags at 2 m with drawn cracks (`region_ossuary_0`).

### Tech artist

- **TA1 (P1) Near-camera canopy cards** are black stippled shapes over the top of the frame under trees
  (`region_moor_0`); the near fade dithers at a coarse pitch.
- **TA2 (P1) A floating terrain slab with a straight cut edge** on the far north-west horizon (`vista_realm_from_se`,
  top left): the far terrain ring/skirt ends in the air.
- **TA3 (P1) Rock shader cost**: `rock_kit.gdshader` samples about two dozen textures a pixel (four triplanar sets, the
  detail normal, moss twice), on every rock and cliff.
- **TA4 (P2) Moths' MultiMesh warns every frame** about physics interpolation (`light_moths.gd:107`, 14 warnings a run).
- **TA5 (P2) The boss arena stills are broken again**: the Bone Abbot's "arena" view is the pit hall's outer shell in a
  blue void (`bosses_a/bone_abbot_arena_0.png`, `places/arena_bone_abbot.png`): the harness camera stands outside the
  buried hall.

### Character and VFX artist

- **CV1 (P1) The Ember Lance's charge is a white blob** (P10): a white-hot sphere and a 1 m additive halo at the staff
  head; its release flash a pink-orange ellipse with a white diamond (`spells/wanderer_cast_lance_full_3q.png` #15).
- **CV2 (P1) Deck-wide telegraphs flood the floor**: the Thornstorm and the Sky Breaks paint the whole floor a flat bright
  orange (`bosses_a/thornwarden_p1_thornstorm_3q.png`, `combat/V1/warden_s41.jpg`), the ground under them gone. Good: a big
  zone keeps the ground readable (a hatch, a strong rim, the safe pools cut out).
- **CV3 (P2) Villager portraits**: Fennick's beard still renders as shards (`villagers/villager_talk_1_fennick_a.png`).
- **CV4 (P2) The Rift Step's tear** (P9).

### UI artist

- **UI1 (P1) The Resonance word** (P13): pink, big, centred over the boss for its whole life.

### Performance engineer

Baseline (`<S>/base/perf_tour.log`, 53 views, vsync off, 1600 x 1000, Balanced): 114-120 fps everywhere (the display caps
at 120), 1% lows 92-107 except **r_downs_w_n 68.0** (a 30.7 ms frame), **r_thorn_in 81.7** (21.6 ms), **fr_lanternwood
86.8** (18.8 ms); draws 700-2289, primitives 0.73-1.97 M; per frame scripts 1.6-2.7 ms, render CPU 1.3-2.6 ms, the rest
(the GPU wait) 3.8-5.4 ms. Load: the Realm built in 17.4 s, the cover lifted 30.6 s after the process started.

- **PE1 (P0) The mesh merge** (P7).
- **PE2 (P1) Script spikes of 23-27 ms with no node added** (`perf_tour.log` HITCH at t 20.86 and 85.29: scripts 26.9 and
  26.5 ms): some system does a whole job in one frame about once a minute. To name with the probe.
- **PE3 (P1) An enemy spawn builds its creature in one frame**: 16.3 ms of scripts for a burrower (HITCH t 12.56), 22.2 ms
  for the Thornwarden and a 41 ms frame (HITCH t 43.60).
- **PE4 (P1) First-view pipeline compiles**: `PSO spec+9`, 18.6 ms of draw (HITCH t 178.80).
- **PE5 (P1) The opening's teardown**: the deferred flush frees the opening camera and its cover in one frame, 11.6 ms
  (HITCH t 53.95); a 12.3 ms deferred flush on the path too.
- **PE6 (P2) Load**: 17.4 s to build, 30.6 s to the lifted cover; the settle phase rendered the whole world behind the
  cover each frame while the post-build pass ran (7.9 s over 225 frames).
- **PE7 (P2) The first boss pull** (P8).

### Models (the map audit's F28, Luke's asset bar)

| ID | Model | Where it is built | Status |
|---|---|---|---|
| M1 | Wardens' towers (6) | `wonders/r39/wardens_line.gd` | `wonder_wardens_tower.glb` (`tools/blender/wonder_towers.py`, 31k tris): coursed masonry, moulded plinth, string courses, machicolated parapet, merlons, window reveals, stair turret, deck; the kit's boxes lay the colliders with `OssKit.visual` off; lit windows, cressets, chests the kit's. 361b9aaf |
| M2 | Climb towers (6) | `wonders/r39/climbs.gd` | `wonder_climb_tower.glb` (11k): the stair cores in dressed masonry with real treads, the broken crown. 361b9aaf |
| M3 | Hermit caches (16: lean-to, cell, ring) | `wonders/r39/hermit_caches.gd` | `hermit_leanto/cell/ring.glb` (`wonder_hermit.py`): a lean-to on a dry-stone wall, an anchorite's cell of coursed rubble under stone slabs, a ring of faceted menhirs round a capstone table; the flagged pad and the crook pole. 361b9aaf |
| M4 | Titan wardens | `wonders/r39/titan_gates.gd` | `titan_warden_l/_r.glb` (`wonder_titans.py`): an armoured warden of hewn stone on a coursed plinth (surcoat, belt, pauldrons, great helm and crest, kite shield, spear, fire bowl); `titan_obelisk_5..9`, `titan_kerb`. 361b9aaf |
| M5 | The Sleeper | `wonders/r39/the_sleeper.gd` | `wonder_sleeper.glb` (`wonder_sleeper.py`, 28k tris): sabatons toe-up, greaves, knee cops, cuisses, the hips' lames and studded belt, the breastplate's flanks in coursed masonry (the slits, the torn wound), ribs of plate, the deck's slabs and oculi, the folded left arm and fist, the pauldron, vambrace and gauntlet curled round the fire basin, the gorget, the great helm face-up (rim, visor, nose ridge, brows, breaths, grille), the crown of nine spikes and two horns. The heart-hall's floor, flights, ribs, dais, furnace and the dressing stay the kit's. 5f78791d |
| M6 | Stepped cairns, haystacks, notice boards, lamp-post boxes (the regions' signature props, 35 kinds) | `wonders/r39/region_dressing.gd` | `art/models/props/sig_<kind>.glb` (`signature_props.py`, render-reviewed twice: the weak first pass of the ballista, bell, carved stone, column stub, pillar, scarecrow, plough, helmet cairn, boat, eel trap, posts and clamp rebuilt), one MultiMesh per part per cell (`WK.prop_xf`). c3d7f572 |
| M7 | Anchoress's cairns | `realm_pois_east_marches.gd` | `anchor_cairn.glb` (flat laid slabs). 361b9aaf |
| M8 | The yards' market stalls, cross and salt heaps | `site_props.gd` (`market_props.gd`'s kit boxes) | the square's own `market_stall_a/b/c`, `market_cross` and a modelled `sig_saltheap`; the code builders deleted. 221548fd |
| M9 | Found already modelled (the audit read them by their look): the King's Barrow (`vista_barrow.glb`), the Choir House (`rift_choir_house.py`), the anchorite cells and the cliff chapel (`Cell_Portal`, `Cell_Slit`, `Chapel_Front` pieces), the crystal crust (`Crystal_A/B`), the salt-works' heaps (`Salt_Heap`) | | nothing to rebuild; their materials are the AD4/EN4 notes |
| M10 | The First Pilgrims' mausoleum | `realm_pois_doubled_realm.gd _necro_mausoleum` | `necro_mausoleum.glb` (`necro_mausoleum.py`, 10k tris): the podium in coursed masonry on a plinth under a cornice, the vault's deck and three coffins, the tomb house with corner pilasters, a lintelled door under a tympanum with a cross, the flat roof on its cornice with the stepped attic, the porch's columns and entablature, the climb's fallen ashlar; the vault floor, both stairs and the candles stay the kit's. d9e44408 |
| M11 | Left: the chasm's stair-stepped walls, the Lanternwood mushroom house, the witch's houses, the salt-sack stairs, the Spire's plinth box, the castellum pyramid, the henge's briar wall (procedural CreatureMesh tubes) | various | not done in this pass (see "Not fixed"). (The capstan's buttresses are the sky chain's modelled "hewn buttresses": nothing to rebuild.) |

## The fixes (worst first; each ticks when the re-capture shows it)

| id | fix | files | commit | re-capture |
|---|---|---|---|---|
| AD1, EN1 | the kit's four masonry sets rebuilt: rounded, pillowed stones, worn arrises, split stones, lichen, recessed mortar; the per-block jitter cut (no checkerboard at 20 m) | `tools/gen_arch_textures.py`, `art/textures/oss_{ashlar,brick,ruin,floor}_*` | 1a8df053 | `pairs/region_rift_0_before_after.jpg` |
| AD1, EN2 | the F28 structures modelled (M1-M10) | see Models | 361b9aaf, c3d7f572, 5f78791d, 221548fd, d9e44408 | `pairs/model_*.jpg` (in game), `model_*_review*.png` (Blender), `arena_thornwarden_before_after.jpg` |
| AD2, LA1, EN3 | the foliage's tint pulled from teal toward a darker green, a darker trunk base, tips lit a little, less backlight on the ground cover | `art/materials/realm_foliage*.tres` | 81a28342 | `pairs/region_hearth_0_before_after.jpg`, `region_thornwood_0_before_after.jpg` |
| AD3 | the Lanternwood caps' glow greyed toward the night | `realm_pois_west_reach.gd` | 1375bc7f | `pairs/region_lanternwood_0_before_after.jpg` |
| LA2, LA3 | far glows: small saturated points in their own colour, a short halo, a flame's flicker for warm ones, thinning past 300-460 m | `landmark_beacon.gd` | 1375bc7f | `pairs/vista_realm_from_se_before_after.jpg` |
| LA5 | the star crater's halo without its cross streak, warmer and fainter rays | `crater_shaders.gd` | 1375bc7f | `pairs/vista_realm_from_se_before_after.jpg` (the white star gone) |
| LA7 | the rift's plume thins within 24-62 m of the camera | `rift/plume.gdshader` | 1375bc7f | `pairs/region_rift_0_before_after.jpg` |
| LA4 | the pit hall lit (P12) | `oss_hall.gd`, `light_director.gd` | 490d5b3c | `pairs/P12_oss_hall_floor_before_after.jpg`, `P12_oss_hall_door_before_after.jpg` |
| TA4 | the moths' MultiMesh not physics-interpolated (the per-frame warning) | `light_moths.gd` | bee1a99b | |
| TA5 | the capture harness shoots a roofed arena from inside | `zz/play_capture.gd` | 61bec5cc | `pairs/TA5_abbot_arena_before_after.jpg`, `arena_bone_abbot_before_after.jpg` |
| CV1 | the charge orb (P10) | `player_casting.gd` | 2479cb1d | `pairs/P10_lance_full_3q_before_after.jpg` |
| CV2 | deck-sized telegraphs hatch their fill (about half the ground shows), the outline, ring and front unchanged | `core/vfx/danger_zone.gdshader` | 45cfcbc9 | `pairs/CV2_P6_thornstorm_before_after.jpg` |
| CV4 | the Rift Step's tear (P9) | `rift_tear.gdshader`, `spell_fx.gd` | d50e43f2 | |
| UI1 | the Resonance word (P13) | `skill_book.gd` | 9280eb6b | |
| PE1 | the merge (P7) | `mesh_merge.gd`, `atmosphere.gd` | ccf49b2b | |
| PE2 | a rest's refill raises one pawn a frame (the Encounters' 13.5 ms); the trail's A* without a GDScript cost hook (a per-edge script call gone; the final tour shows it was not the 27 ms spike, which is the Hollow Lantern's subtree and stays: see Perf) | `enemy_spawner.gd`, `trail_route.gd` | 9c95179e | final tour: the spikes remain (t 19.6, 85.4 s) |
| PE7 | the first pull's text (P8) | `ui/panel_warm.gd` | 9b6e3999 | |

## Not fixed in this pass (and why)

- **P4 (P0) The Count door's pale sheet is still seen from the threshold** (`<S>/pairs/P4_count_door_after.jpg`): the bank's
  face south of the shaft is now closed (rock slabs, seen from the side and above) and the pool has a black face, but from
  the threshold's own eye the door's south side shows the pale sheet; the collision there is whole and the door's mesh is
  present and drawn (`visual_probe --only=countdoor,countvis`). What draws over it was not found in this pass (the Realm's
  water sheet `FenWater`, whose box covers the spot, is the suspect).
- **PE2 (P1) Two 27 ms script spikes in the tour** (t 19.6 s at r_downs_w_n, t 85.4 s): the profile puts them in the Hollow
  Lantern's subtree (its Story director and Keg scenes); the trail A* change (9c95179e) was a wrong guess for them.

- **The rest of F28 (M11)**: the chasm's stair-stepped walls, the Lanternwood mushroom house (`mushroom_mesh.gd`, a
  procedural mesh), the witch's houses, the salt-sack stairs, the Spire's plinth box (a terrain-fitted foundation), the
  castellum pyramid, the henge's briar wall. Each is a modelled asset with its own render review (Luke's bar, 18 Nov) fitted to colliders that
  must not move; this pass spent its model time on the most-seen ones (the Sleeper, the towers, the titans, the hermits,
  the 35 signature props, the yards' stalls, the mausoleum). They are the next model round's list.
- **PE4 (P1) First-view pipeline compiles** (`PSO spec+9`, a 21 ms frame at t 178.8 s in both tours): Godot's ubershader path
  specialises pipelines the first time a material meets a new state; warming every specialisation behind the cover is
  engine-level work (the project's own warm-up covers the UI and the bosses). Left as measured. (PE5, the opening's 22 ms
  teardown frame, does not appear in the final tour.)
- **PE3 (P1) Enemy spawns build their creature in the frame they appear** (`<S>/base/spawn_cost.log`, `zz/spawn_cost.tscn`):
  a regular kind's first spawn costs 12-15 ms of `add_child` (warm 1.4-7 ms), a boss 10-17 ms warm; the Thornwarden's
  first build (no warm-up) 223 ms. The arenas already pay their bosses' first-use costs on the approach
  (`BossArena._warm_step`), and the refills are now spread one a frame (9c95179e), but the pull's own frame still builds
  the boss (`BossArena._begin`: new, add, gates, bar, title, signals in one frame). Splitting it changes the arena's
  contract (rooms, the HUD, the tests read the boss in the pull's frame); not safe in a visual pass.
- **TA2 (P1) The far horizon slab** seen from the summit (`vista_realm_from_se`, top left): the horizon ring's far
  mountains read as a slab with a straight underside against the sky. A skirt or a change to the ring's heightfield is
  terrain work (`realm_land.gd` and its land cache, every terrain test) outside this pass.
- **TA3 (P1) The rock shader's two dozen samples a pixel**: the GPU attribution at the worst views (`profile_attrib.log`)
  does not put the rocks among the costs (lights, flora, the moon's shadow, soft shadows, glow); left as measured.
- **LA6 (P2)** the window cone's streak across the Holds' wall, **EN4-EN6 (P2)** the ground's single value, the oak's
  bark speckle, the Ossuary landing's cartoon flags, **CV3 (P2)** Fennick's beard shards: second-order, left for a
  materials round.

## Perf: the baseline against the final tour

Both `zz/perf_tour.tscn -- --hitches --loading` (vsync off, 1600 x 1000, Balanced, the display capping at 120):
`<S>/base/perf_tour.log` and `<S>/after/perf_tour.log`; the per-view table is `<S>/pairs/perf_compare.txt`.

| | baseline | final |
|---|---|---|
| mean fps over the 47 views | 118.1 | 118.1 |
| mean 1% low | 98.9 | 98.9 |
| lowest 1% low | 68.0 (r_downs_w_n) | 71.9 (r_downs_w_n) |
| mean worst frame | 11.2 ms | 11.2 ms |
| r_thorn_in / fr_lanternwood / r_glade 1% low | 81.7 / 86.8 / 91.9 | 85.5 / 89.6 / 99.3 |
| r_downs_w_w / fr_southwood 1% low | 102.6 / 102.9 | 93.0 / 94.4 (one 14.8 / 13.4 ms frame each; p99 unchanged, 9.6 / 9.9 ms) |
| path: spawn / east 1% low, worst | 98.3, 16.1 ms / 90.0, 14.1 ms | 97.2, 18.3 ms / 92.8, 12.4 ms |
| hitches over 15 ms in the tour | 8 (settle 62, burrower spawn 23, script spike 31, Thornwarden spawn 41, opening teardown 22, script spike 32, PSO 22, path 21) | 7 (settle 59, burrower spawn 23, script spike 31, Thornwarden spawn 42 + 21, script spike 33, PSO 21): the opening teardown's 22 ms is gone |
| Realm built / to realm_done | 17.4 s / 30.6 s | 17.5 s / 31.9 s (the merge is spread over frames under the cover: 1.2 s of wall time where it froze the bar for 0.85 s in one frame) |
| the post-load merge frame (P7) | 850 ms in one frame under the cover (120-140 ms where no cover) | at most a 5 ms slice a frame |
| draws / primitives | | within +-1 % draws everywhere; primitives +0.5 .. +9 % at the modelled places (fr_long_arches +9 %, fr_southwood +9 %: the Sleeper, the climb towers, the hermits) |

Read: no average loss; the lows rose at the three worst views and fell by one frame at two (r_downs_w_w and fr_southwood, a
single 13-15 ms frame in a 4 s window each; the frame-to-frame spread is unchanged, so these are one-off frames, not a
heavier scene). A short re-check of just those views (`<S>/logs/perf_check.log`) had no such frame (worst 10.8 / 11.3 ms),
and fr_southwood's GPU time is lower than the baseline's (4.91 against 5.13 ms) for all the Sleeper's +9 % primitives. The two remaining 27 ms script spikes (t 19.6 and 85.4 s) are in the Hollow Lantern's subtree (its Story
and Keg scenes, `idle: HollowLantern 26.0` in the profile): the trail's A* change was not their cause; they are left for
the next perf round with the probe line to start from.
