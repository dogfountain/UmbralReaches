# Critique B: the player and controls (r29)

Lens: movement and traversal, the camera, the wanderer's animation, input and controller support,
game feel, the HUD, the first minutes. Luke plays at 120-144 Hz, so anything that moves only on the
60 Hz physics tick counts as S1.

All runs used the isolated HOME (scratchpad `critB/home`) and held `Travel._busy`. Five other agents
were rendering at the same time, so frame rates in windowed runs are noisy. Logs are in the
scratchpad (`critB/logs/*.log`).

## How it was measured

- **New probe `zz/first_minutes.tscn`** (`-- --loading [--cap=120] [--tag=x] [--no-shots]`). It
  loads the real night with its loading screen and logs when the cover lifts and when the title card,
  the controls card and the narration first show, with shots of each. It then plays a scripted run
  from the real spawn: idle, walk, sprint, jump, slide, roll, reversal, stop, Rift Step, double jump,
  stick orbit and strafe. For each segment and each channel (camera position, camera angle, FOV,
  camera roll, pivot pitch, body, body yaw, staff orb) it compares the motion on rendered frames that
  had a physics tick against frames that had none, normalised by frame time. Read "tick ratio" as:
  about 1 means the channel moves on every rendered frame; 0 means it moves only on physics ticks,
  i.e. it steps at 60 Hz. Caveat: below about 110 fps, most frames carry a tick and the ratio reads
  low for every channel. Compare runs only at the same frame rate.
- `zz/move_course` (21 legs, now 26), `zz/trav_realm`, `zz/move_seq` (filmstrips),
  `zz/move_char_shot` (studio sheet), `zz/smooth_probe`, and code reading.

## Findings (worst first). F = fixed in this pass, R = in the register for its owner, O = open

### S1

1. **F: a roll into a wall left the wanderer crouched for good, ignoring the stick.** At the end
   of a roll the stand-up test (`test_move` up 0.6 m) counts the wall the body is touching as a
   ceiling, so `_roll_t` was reset to 98 % every tick, forever. Evidence: first_minutes "before" at
   (0, 1.8, -23.6), the parapet at the end of the opening path: `roll 0.54`, velocity 0, for 4+ s
   through the reverse, stop and Rift Step segments. Fix: `_headroom()` runs a shape query with the
   full capsule, 4 cm thinner and lifted off the floor. If there is truly no room (a low slab), the
   wanderer stays low and **crawls** along the stick, in the slide's low pose, until it can stand.
   The slide does the same when it ends under something. Tests: move_course `rollwall`, `crawl`.
2. **F: the camera's FOV kick, strafe roll and landing dip stepped at 60 Hz.** All three were set
   in `_update_camera` on the physics tick, and the camera rig is not interpolated. The sprint FOV
   kick, the slide and Rift Step widenings and the landing dip all ratcheted at 120-144 Hz.
   Evidence: tick ratio for `fov` was 0.00 in sprint, slide, roll, Rift Step, air jump and orbit.
   After the fix it is 1.12 (same-fps run; logs `first_base2` vs `first_a1`). Fix: the tick only
   sets targets; `_cam_frame()` eases FOV, roll and dip every rendered frame.
3. **F: the Lance's charge visuals jittered against the staff head.** The ember orb, its halo,
   its light, its particles and the aim ring were placed from `SkillBook._physics_process` at the
   staff driver's tick position, while the staff itself is drawn interpolated. Fix: the tick stores
   the charge; `_frame_fx()` places everything per frame at `CharacterRig.muzzle_drawn()` (the orb's
   interpolated transform). Staff orb channel tick ratio: 1.0 to 1.2 in every segment.
4. **F: the robe's cloth inputs stepped at 60 Hz.** Hem kick, boot cover, walk phase, stride and
   torso basis were `set_instance_shader_parameter` calls made on the physics tick, while the bones
   are blended per frame. Fix: the merged body keeps the last two ticks and `_push_cloth(f)` blends
   them each rendered frame (walk phase as an angle), sending only values that changed.
5. **F: the thigh pierced the robe at a sprint, and the legs showed through the front at a walk.**
   The robe shader only moved the hem near the feet, so a forward knee went straight through the
   front panel. Fix: robe_skin.gdshader gets the hips and knees (instance uniforms 11-14). The front
   panel may no longer hang behind the line from the hip to a forward knee, and below the knee it
   falls back toward its own hang, with a lateral falloff so it tents. Shots:
   `shots/critB_robe_sprint_before|after.png`, `shots/critB_robe_sheet_before|after.png` (walk and
   sprint rows). The identity is unchanged: robe pieces, void face, staff in hand_r, wave shader.
6. **F: a lava throw during a mantle dragged the wanderer back.** `_end_traverse()` cleared hang,
   climb, vault and roll, but not `_mantle_t`, so the next mantle tick pulled the body back along the
   mantle path. It now clears every state: mantle, slide, crawl, beam, steep, kick lock and the Rift
   Step reveal, and cancels the rig's move pose (`CharacterRig.cancel_move()`). Test: move_course
   `mantle_tp`.

### S2

7. **F: respawns streaked across the map** (register, from F). `_respawn_now` set the position
   with no interpolation reset and left traversal state and the lock alive. It now calls
   `teleport()` and releases the lock. The lava throw uses `teleport()` too.
8. **F: the chasm was a free Gloom wipe.** Falling below y -40 respawned you at the brazier with
   Gloom 0. Now it puts you back on the last safe ground with +8 Gloom and a toast. Test:
   move_course `fallout`.
9. **F: there was no catch for a fall through the world above y -40, and none for being stuck in
   geometry.** A fall that lasts 6 s now triggers the same rescue (the summit is about 100 m up).
   After 1 s of pushing the stick without moving while the capsule overlaps the world, the body is
   lifted out (+0.3 to +1.5 m) or put back on safe ground; this prints a line, it is not an error.
   Test: move_course `unstuck`.
10. **F: the title card played under the loading screen.** It was visible at 1.03 s and the cover
    lifted at 5.41 s, so the player saw only its fade (`shots/critB_first_before_00_lift.png`). It
    now waits for the cover to lift (`shots/critB_first_after_title.png`).
11. **F: the controls hint did not work** (register, from F and C).
    - It was one keyboard-only line of about 200 characters (1707 px) under the objectives.
    - It was cut off on the 1600-wide canvas that small windows get.
    - It stayed up over every menu.
    - It faded 16 s after the HUD loaded, which left about 11 s of play under the loading screen.

    Now it is a four-line card (the longest line is about 75 characters). It uses whatever the
    current bindings are, switches to pad names as soon as a pad is used, appears when the night
    shows, hides while a menu, the Satchel or a conversation is open, and leaves after 20 s of play.
    Time spent in menus does not count.
12. **F: first-time tips, each shown once, when the moment comes.** Running for 1.5 s shows slide
    and slide-leap; hanging from a ledge shows climb, kick off and let go; a foe within 16 m shows
    lock-on and roll; Gloom over 55 says what firelight does. Tips only start after the card.
13. **F: the mouse was not captured when the night began.** The first mouse move moved a cursor,
    not the view, until some click. The player now captures the mouse on its first frame after the
    loading screen. This only happens in the real game (never under a zz harness) and only when the
    window has focus.
14. **F: pad play had several problems.**
    - Sprint meant holding L3 down; it now latches until you stop.
    - The look stick was linear with no curve, and a 180 took 1.2 s. It now has a response curve
      (^1.6) and a 1.6x turn boost when held hard over. Vertical look is at 0.8x.
    - View/Back opened the developer stats overlay; it is F3 only now.
    - The Kindling menu had no pad binding; it is now on D-pad right.
15. **F: toasts overwrote each other.** A second toast in the same moment hid the first, for
    example "They do not kill..." together with a quest toast. Toasts now queue: at most 4, repeats
    are dropped, and a queue shortens each one's hold.
16. **F: snap camera moves.**
    - A mantle carried the view up to 1.1 m in 0.24 s. Part of each tick's rise now goes into the
      eased camera offset. Ledge cam jerk: 0.087 to 0.063 max, 0.012 to 0.010 rms.
    - A vault carried the view over the whole arc. It now rises only 65 % of the hop. Vault cam
      jerk: 0.22-0.24 to 0.155 max, 0.033 to 0.026 rms.
    - The kick, the landing dip (up to 7 degrees) and the Rift Step's 12-degree widening each
      landed in one frame. They now arrive over about 3 frames (rate 38/s), still punchy.
17. **F: the lock-on target hid behind the robe up close** (register, from A). The lock aimed the
    view from the body, but the camera sits 0.95 m to the right, so a foe 3 m away projected onto
    the robe's right edge. The lock now aims from the camera pivot, which puts the target on the
    crosshair, clear of the wanderer (bolts aim there too). In a close fight (locked on, or a foe
    within 4.5 m), the view rises 0.32 m and the boom grows 0.45 m.
18. **F: the crosshair stayed on screen over conversations and menus.** It is hidden now. The HUD
    runs while the tree is paused so it can do that.

### S3

19. **F: footsteps sounded the same on every surface** (register, from D). One short ray per 0.3 s
    picks the surface, and each surface sets its own pitch and level: grass, fen, ash, stone
    (anything built), wood (boards, decks, docks, bridges), and water, which adds a low slap.
20. **F: the grass parted around the body at 60 Hz.** `push_pos` was set on the physics tick;
    it is now set every rendered frame from the drawn body position.
21. **F: small per-frame costs.**
    - `_update_arm` allocated a query and a sphere shape on every rendered frame, and
      `_thin_occluder` on every blocked frame. Both are cached now.
    - The Gloom bar redrew every frame. It now redraws only when its value changes or it pulses.
22. **O: the sprint is still a deep crouch.** The knees bend about 90 degrees, the hood pitches far
    forward and the staff trails low (`shots/char_critB_after1_sprint_side.png`). The robe now
    covers the legs, but the silhouette reads as a scuttle more than a run. The fix would be a
    shorter sprint stride (STEP_KEYS 7.5 -> 1.32 m) with a higher pelvis. That retunes C's r28
    planted-foot gait and its foot-slide numbers, so I left it.
23. **O: foot slide is 9.4 cm per metre travelled** (move_seq loco).
24. **O: the capelet reads as a second hood in the side view** (`char_*_idle_side`, the stacked
    hood silhouette). It is part of the robe's identity, so this is a note only.
25. **O: there is no input rebinding and no stick-sensitivity setting** (the Settings menu is F's).
    In the register.
26. **F (by F): interact prompts said "[E]" on a pad.** F added `Settings.using_pad` and
    `prompt_key()` now follows it; the HUD card and the tips use the same signal.
27. **R: the camera sits under the forge awning while you talk to Hild** (register, from C). The
    camera only collides with Layers.WORLD, and the awning roof looks like decoration with no
    collision. In the register for C, who owns the village.

### Seen elsewhere in the game (in the register)

- **C:** the opening narration line showed at the same moment as the title card
  (`shots/critB_first_after_02_after_3s.png`). C has since held its region banner after the title.
- **A:** the loading warm-up logs `ERROR: Tween (bound to @MeshInstance3D@...) started with no
  Tweeners` in every windowed boot (`first_base.log`).
- **E:** willow curtains and canopy leaves fill the frame when the camera backs into them in the
  fen fight (`shots/critA_warband_before.png`, top of every frame). Flora within about 1.2 m of the
  camera should dither out.
- **F:** the Controls tab in Settings still shows the old pad text for Kindling ("X at a lit fire";
  it is D-pad right now), for the Stats overlay (View no longer opens it) and for Sprint (L3 now
  latches).
- **F:** every windowed run leaks at exit: `1 shaders of type ParticlesShaderRD were never freed`
  plus 1 MaterialStorage Shader RID.

## Numbers

| What | Before | After |
|---|---|---|
| FOV tick ratio (sprint / slide / air jump) | 0.00 / 0.00 / 0.00 | 1.12 / 1.11 / 1.09 |
| Pivot pitch tick ratio, air jump (landing dip) | 0.05 | 0.97 |
| Staff orb tick ratio (walk / sprint) | n/a (driver position) | 1.18 / 1.17 |
| Roll into the end-of-path parapet | stuck crouched 4+ s, deaf to the stick | crawls back out, stands |
| Title card seen after the cover lifts | its last fade only | full (0.35 s after the lift) |
| Controls card width | 1707 px, one line | about 800 px, four lines |
| move_course | 21/21 | 26/26 (5 new hardening legs) |
| Ledge mantle cam jerk (max / rms) | 0.087 / 0.012 | 0.063 / 0.010 |
| Vault cam jerk (max / rms) | 0.22 / 0.033 | 0.155 / 0.026 |

Cost of the new per-frame work, from a micro-benchmark in the real night: `_push_cloth` 3.6 us
(worst case: everything changed), `_cam_frame` 0.4 us, `_update_arm` 1.6 us, `muzzle_drawn` 0.1 us
(only while charging), HUD `_process` 1.2 us, and the surface ray 7.8 us once every 0.3 s. That is
about 6 us per frame against the 100 us budget. `char_cost`: the whole player is +0.59 ms (r24
measured 0.58). Hub stress A/B of the robe drape shader (`perf_tour --shader`, alternated
A B A B; spawn_west fps):

| Run | spawn_west fps |
|---|---|
| A (with the drape) | 57.4, 55.0 |
| B (without) | 78.5, 46.2 |

Those numbers are pure noise from the other agents' renders. The drape adds a few ALU ops per robe
vertex. Draws are 652-724 and primitives at most 1.01 M, both inside the budget.

## Tests (isolated HOME)

- move_course: 26/26, with the 5 new legs rollwall, crawl, mantle_tp, fallout and unstuck.
- trav_realm: 5/5.
- realm_walks: ok. realm_rift_walk: ok.
- skill_test: PASS. combat_duel: all PASS. story_test: PASS. It failed once, only because my
  concurrent combat_duel and skill_test runs shared the same HOME and wrote its save; run alone,
  it passes.
- quit_probe: exit 0. smooth_probe: camera jitter tracks body jitter (frame pacing under load).
- first_minutes (new): the title card and the controls card both show after the cover lifts.
