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

- B16 Modelled crates, barrels, benches and carts stood pitch black at Saltmarket's doors, lit by a lamp or not (the probe `--near-debug` named the materials: `Dress_crate` on the plain kit wood, texture 0.1 under baked shade 0.55-0.9): the extra variants (`site_props_more.gd`) take the outdoor wood's 2.3 lift, the modelled timber parts 1.6 (`site_props.gd`, outdoors only: the tavern keeps the kit's own). [x]
- B17 The West kit's iron was a full metal: nothing in the night to reflect, so every modelled hoop, hinge and post drew black: 0.4 metallic (`west_marches_kit.gd`). [x]
- B18 The ember post by the first fire (the opening shot looks at it) stood a black pillar on black steps: the kit's night-readable iron and masonry (`ember_post.gd`). [x]
- B19 Fennick's beard read as pale shards in his portrait (CV3): the fringe in the shell's own darker tone, shorter and finer (`villager_rig.gd`). [x]

### Sound
- B14 The slide's scrape and the lance's charge started at full level and stopped dead: `Sfx.loop_on` / `loop_off` (a 90-120 ms rise, a 140-200 ms fall). [x]

### Not fixed (seen, and why)
- The Realm ground's scratched "foil" detail on dunes (Southwood, `sleeper_2`): the ground shader is the fps pass's.
- The starwater's flat blue rectangles round the Watchers' plinths (`rift_thr`): the pool's own look; changing it is lava-shader work.
- The loading screen itself cannot be captured by `polish_flow` (the build holds the main thread; frames come black until the cover lifts).

## Final re-shoot (once, after all fixes)

Before: /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/before/{ui,places,flow,ma2,ma3}. After: /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/after/{ui,places,flow,ma}.
- A1 Count door: pale sheet gone, dark backing now reads as rock (after/ma/interiors/oss_count_door.jpg).
- A3 skull walls: aged per-instance bone tones (after/ma/interiors/oss_hall_floor.jpg).
- A5 chasm walls: terrace bays in rift stone (after/ma/rift/rift_thr.jpg).
- A8 salt stack: modelled stack (after/ma/saltmarket/salt_stack.jpg).
- B1/B2 opening and first fight: no WASD card over the shot, one-line lesson (after/flow/open_03.png, fight_walk_0.png).
- B3/B4 HUD strip and pickup feed clear of the dial (after/ui/hud_exploring, shop_buy).
- Saltmarket crates no longer black (after/places/close_saltmarket.png).
- Not re-checked in shots: A4 furnace, A9 plinth, A10 castellum, A11 briar (after/ma/southwood, stillwater, arches, henge); parse check 994 scripts 0 bad.


## Lead review round (20 Nov): the four shots not inspected, and the "left" list

Shots: /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/after2/ma (audit sheets), /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/after2/flow (travel, night), /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/after3 (free-camera far views, one frame each).

- C1 Henge briar wall read as a thin flat red strip: modules 7 m tall, denser (16 canes of 0.11-0.2 m, 34 tangles, 8 crossing canes), the wall drawn 1.3 x its collision height (7.3 m), an 11.5 m thorn trunk every third segment, emission 0.15 -> 0.05 (the pink wash), the floor strewn with fallen stone (EN4). Seen: after2/ma/thornwood/henge_wall.jpg (14 m from the wall: thorns, depth), after3/henge_wall_far.png (from the floor at the wall: a tall tangle with trunk spikes), after3/henge_far_far.png (the whole ring from above). [x]
- C2 Sleeper: the furnace's gem and every `__wax` part drawn lit (they were candle wax, so the furnace never glowed); seams of ember in the plate (shins, cuisses, hips, left arm, forearm, gorget) and a 13 m flue with a lit mouth and a flame on its crown over the heart. Seen: after2/ma/southwood/sleeper_far.jpg, ground_dune.jpg, after3/sleeper_b_far.png (the striped body reads through the forest from 130 m). The audit's "from W" camera stands inside the flank (an audit artefact; the new embers fill it). [x]
- C3 Castellum chest "floating on a translucent orange box": the audit's own camera lamp (an omni 0.5 m over the lens) lit the fog round the lens into a box beside the nearest prop (the hidden cache `Find1`, a stump with a chest); the lamp now lights no fog (`map_audit_shots.gd`). The far hull (`Tower_Far`) is in no frame the harnesses can reach (the audit caps its range at 34 m and the hills hide it in the free views); checked in the Blender preview only. [x chest; far hull unverified in the game]
- C4 Spire air view's red-orange blob: the Ashen Rift's lava (its first channels show as red lines beside the Spire in after2/ma/lastlight/spire_b.jpg, 257, -19), bloomed and seen from 60 m up; not a defect. [x]
- C5 Hearthward's fire reads from afar: the landmark beacon's warm point on the Sanctuary (`brazier.gd` `_far_glow`); a warm point shows left of the keep in after3/hearth_b_far.png (230 m). [x]
- C6 Starwater's blue rectangles round the Watchers' plinths: the shore line 2x as bright and 3x as wide as it should be (`lava.gdshader`), and the pool's violet lights too strong on the lower treads (`threshold.gd`: 4.0 -> 2.8, a paler violet). Seen: after2/ma/rift/rift_thr.jpg (shader change only: the tread still a bright slab); the light change is not re-shot. [x, light unverified]
- C7 Kit `dark` blocks stood pitch black: 0.26 -> 0.4 albedo (`oss_kit.gd`); the Find1 stump's cap reads in the castellum frame. [x]
- C8 Ground "foil scratches" on dunes: the heath's straw to a softer mip with distance (`realm_ground.gdshader`). Seen: after2/ma/southwood/ground_dune.jpg, after3/sleeper_a_far.png (a pebbled dune, no hatching). [x]
- C9 EN6 flagstones: a second, larger, turned course laid half under the first, and a slow stain (`realm_ground.gdshader`). Not re-shot at the Ossuary's landing. [x, unverified]
- C10 EN4 henge floor a flat dark disc: fallen stones and thrown rocks (`henge_raid.gd` `_litter`, 78 in three shapes): grey stones on the floor in after3/henge_wall_far.png. [x]
- C11 LA6 the window cone's streak: the `shaft` light class's fog energy 1.05 -> 0.55 (`light_policy.gd`). Not re-shot at the Holds. [x, unverified]
- C12 Fast travel flight (after2/flow/travel_*): the Ember Road arc cleared the land by 20 m but not a 25 m crown (frame 20 sits inside leaves): `CLEAR` 20 -> 30 (`fire_flight.gd`), not re-shot. The night's summary read "NIGHT 0 IS OVER" in the harness: `maxi(1, ...)` (`night_panel.gd`). [x]

### Round 2 (21 Nov)
Shots: /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/after4 (free-camera, flow), /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/after5 (free-camera).
- D1 Starwater slab: the plinth's lower tread took five violet lights (two pool lights, Glow0, the two orbs) on a pale stone: the fig material 0.92 -> 0.6, the orb lights 3.0 -> 2.2, Glow0 3.4 -> 2.6 (`threshold.gd`, `lava_works.gd`). after5/plinth_air_r5.png and after4/plinth_s_r4.png show the pool and the base with no slab (the shore line shows as thin outline and a ring). [x]
- D2 Hearthward's fire from afar: a lit-smoke column over the fire (`fire_plume.gd`: an unshaded additive card turning about the vertical, warm at the base, fading up, clear inside 35 m, no light, no shadow, no fog), shown while the fire is lit. Seen as an orange column at 70 and 150 m (after5/hearth_60_r5.png, hearth_150_r5.png) and a thin red one at 300 m (hearth_300_r5.png); then widened (9 -> 12 m), made taller (46 -> 60 m) and brighter (0.6 -> 0.95), not re-shot after that. From the west at 230 m (hearth_230_r5.png) it is hidden by the trees on the ridge. [x]
- D3 Briar wall cost: 8 arcs, each a near mesh (full modules, 5.5k tris) shown within 78 m and a far mesh (BriarLo modules, 550 tris, no thorns) shown beyond 66 m, each its own instance with a visibility range and its own bounds (`henge_raid.gd` `_wall_chunks`, `polish_briar.py` LO). Past 78 m the wall costs ~53k tris spread over arcs culled by the frustum (it was ~530k always). Seen: after4/henge_wall_r4.png (near), henge_far_r4.png / henge_mid_r4.png (far). [x]
- D4 Re-shoots: travel arc at CLEAR 30 (after4/flow/travel_12-22: the camera stays above the crowns), plinth (D1), LA6 holds wall (after4/holds_a_r4.png: no streak; the other two cameras stood in trees), EN6 flags (after5/salt_flags_r5.png: a stained varied course, no longer one grid), castellum far hull (after4/cast_260n_r4.png and cast_crop.png: a dark capped tower at the aqueduct's west end, 260 m north). [x]

### Round 3 (21 Nov)
- E1 Hearthward's plume as smoke: the card's shader is now billowing noise (value-noise fbm climbing and drifting), wider and more diffuse as it rises (11 m at the base to ~18 m near the top), leaning down the wind with a slow curl, strong warm only in the lowest third and an ember-grey smoke above, peak 0.30 (was 0.95), no straight edges (`fire_plume.gd`). Seen at 60, 150 (south) and 300 m: /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/after8/hearth_60_r8.png, hearth_150s_r8.png, hearth_300_r8.png; hearth_150_r8.png from the east. [x]
- E2 The "two beams": `Area.make_brazier` duplicates a dressed fire with its children, so the henge's fire carried a second plume (and a second landmark beacon on the compass); `brazier.gd` now frees a copied `FarPlume` and `Beacon_`, and only the fire at the spawn gets them. [x]
- E3 The Ossuary title card and the Ember Road lesson over the flight: the Area's title card (`area.gd`), the discovery banner and holds (`discovery_banner.gd`, `realm_discovery.gd`), the first-hour and feature lessons (`feature_tips.gd`, `hud.gd`, `text_director.gd`) all wait while a `fire_flight` is up, and a lesson already on screen goes back to the queue when the flight starts. Seen: /private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/polish/after9/flow/travel_00 (before), travel_12 (flight: no card, no lesson), travel_35 (landed). The flow now waits 9 s first so the night's own cards are not what the flight shows. [x]
