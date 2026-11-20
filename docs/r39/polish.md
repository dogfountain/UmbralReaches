# r39 polish pass: live checklist (branch `polish`)

Brief: `docs/r39/briefs/polish.md`. Order: critique (captures) -> every fix -> one re-shoot. No tests run here (the lead runs the suite after merging).
Scratch (shots): `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/` (`before/`, `after/`, `blender/`).

Tick = fixed and committed. Each line: the issue, the fix, the commit.

## A. The visual pass's leftovers (named in the brief)
- [~] A1 The Count door's pale void: two causes closed (not yet seen closed in a shot): the pit's black still-water face grew to cover the Realm's whole sheet (`ossuary.gd _pool`), and `RealmLayout.water_level_at` gave the quarry's lip and cliff foot the fen's -0.9 level (a pale sheet 0.6 m over the threshold's eye, seen under) instead of the pool's. The probe (`map_audit_shots --variants=`) is the check.
- [x] A2 The summit horizon slab (TA2): it was not the terrain ring. The sky shader's two painted far ranges (`world/sky/sky_vistas.gdshaderinc`) were filled to the bottom of the sky and read as a dark slab with a straight underside from a high view; they now fade into the haze a little below their crests. (A first guess, a back slope and a skirt on the ring, was reverted: `Horizon ring ...` and its `Revert`.)
- [x] A3 The pit hall's skull walls (flat, bright orange): every skull and bone has its own tone (ivory, tea, grey, soot) from its place (`OssKit.bone_tone`, a per-instance MultiMesh colour), in a range dark enough that the candle light does not clip the wall to one gold.
- [x] A4 The boxy Sleeper: the exterior and the hand's basin were already the model's; what was left boxy is the heart's furnace (a glowing cube on its corner over four iron sticks): `sleeper_hearths.glb` (Furnace; `tools/blender/polish_hearths.py`), the flame on its chimney.
- [x] A5 The chasm's stair-stepped walls (the Pilgrims' Threshold): each terrace tier wears a modelled bay (`terrace_bay.glb`, `polish_terrace.py`: coursed facing, pilasters, pointed blind arch, coping, balustrade) over its collision boxes (`rift/threshold.gd _bay_look`).
- [~] A6 The Lanternwood mushroom house: the giant caps are modelled already (`vista_caps.glb`); what stayed was the lathed toadstool in `mushroom_mesh.gd`, which only the retired glimmer buds and the stair zone's hero mushrooms use. Nothing in the Realm builds it any more.
- [~] A7 Witch houses: the Hollow's hut is modelled (`vista_southwood.glb`); the cellar below it is a deep hall (the kit's boxes, interior).
- [x] A8 Salt-sack stairs: the works' Block_Stack (five courses of plain boxes stepped back like stairs) is now a modelled stack of cut salt: bevelled loaves, a plank, two sacks and a rope (`salt_stack.glb`, `tools/blender/polish_salt.py`; `east_works_kit.gd many` lays it, the collision table is unchanged).
- [x] A9 The Spire's plinth box: a column of plain boxes per cell; now dressed blocks (`found_block.glb`, `polish_blocks.py`) in courses over the cells' collision (`realm_pois_east_marches.gd _plinth_blocks`, one MultiMesh).
- [x] A10 Castellum pyramid: the far hull (`Tower_Far` in `reach_s_castellum.glb`) was a box under a four-sided pyramid; now corner buttresses, a corbelled cornice and the half-fallen hipped roof (`reach_south_castellum.py far()`).
- [x] A11 Briar wall: `art/models/briar_wall.glb` (`tools/blender/polish_briar.py`: three wall modules and a thorn trunk) laid by `henge_raid.gd` through `MeshStamp` for the outer wall and the maze walls (the CreatureMesh tubes stay as the fallback when the glb is not imported).
- [ ] A12 Second-order leftovers: LA6 window cone streak, EN4 ground value, EN5 oak bark speckle, EN6 Ossuary landing flags, CV3 Fennick's beard shards.

## B. The panel's critique, from the before captures
Shots: `scratchpad/polish/before/` (ui/ places/ flow/ ma/ ma2/ ma3/). The flow (`zz/polish_flow.gd`): title, loading, opening, first fight, death, the Ember Road, the night's end.

### UX / design
- B1 The WASD card drew over the authored opening shot (flow `open_04`): the lesson lane now waits while `opening_shot` is up (`text_director.gd can_begin`, `hud.gd _tips_tick`, the shot joins the group). [x]
- B2 The first fight's lesson was four lines of dense text over the foe and the wanderer, and stayed through the kill (flow `fight_walk_4`): two lines (`enemy.gd`). [x]
- B3 The gear hint strip under the region plate sat on the dial's bezel and its N (ui `hud_exploring`): the plate stack rises a row (`minimap.gd`). [x]
- B4 The pickup feed's plates touched the minimap's rim (ui `shop_buy`): clear by 42 px (`satchel.gd`). [x]
- B5 The objective line's step marks were the glyphs > and a tick, not painted: painted pips (`objective_line.gd`). [x]
- B6 Trait texts broke "1 s" and "28 m" across lines (ui `char_wanderer_gear`): non-breaking spaces (`gear_db.gd`). [x]
- B7 The Chronicle's cost line said "1 countries walked", "1 falls", "1 camps": pluralised (`night_panel.gd`). [x]

- B15 The opening's lens looking straight up saw its constellations as soft smeared squares with colour fringes (the equirect map stretches toward the zenith): the sky fades the map above 53 degrees (`vortex.gdshader`). [x]

### Tech / QA
- B8 SCRIPT ERROR `_pick_hover` index 22 on a PackedByteArray (play_capture ui, `world_map.gd:500`): the cluster list can be one repaint behind the marks; guarded. [x]
- B9 "BUG, indexing did not unpair geometries from light" x 1146 at exit (every run): an engine message when the scenario is torn down with many lit instances; not a gameplay fault, left (QA already logged it).

### Art / environment / tech art
- B10 The first fire's plinth (Hearthward, the first thing seen) rendered as black glitter with green sparks (fps_pass `before_spawn`): the zone's stone material (normal scale 2.35, metallic, rim) under the fire; the kit's masonry now (`dressed_props.gd`). [x]
- B11 The Watch's uniforms were two black cut-outs at night (ui/places `close_saltmarket`): coats lifted from 0.25 to 0.43 (`watch.gd`). [x]
- B12 The far ranges' dark slab (A2). [x]
- B13 Bone walls one flat gold (A3). [x]

### Sound
- B14 The slide's scrape and the lance's charge started at full level and stopped dead: `Sfx.loop_on` / `loop_off` (a 90-120 ms rise, a 140-200 ms fall). [x]

### Not fixed (seen, and why)
- The Realm ground's scratched "foil" detail on dunes (Southwood, `sleeper_2`): the ground shader is the fps pass's.
- The starwater's flat blue rectangles round the Watchers' plinths (`rift_thr`): the pool's own look; changing it is lava-shader work.
- The loading screen itself cannot be captured by `polish_flow` (the build holds the main thread; frames come black until the cover lifts).
