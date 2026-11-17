# The Night, Made Whole

A handbook of fixes, smoothing, animation, and hardening for the packed Umbral Reaches app.

Written 6 November 2026, from the playable bundle at `/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app` (packed 10:39, Linux `.pck` inside the Mac bundle) and from the Godot 4.7.2 source that pack is built from. The shared docs connector was not in this session, so the handbook lives here as Markdown. It is one hundred sheets on the body, the fight, and the hearth, then the roads, then the rest of the night: fires, the door, the bosses' rooms, the lift, the shade, the Kindling, the journal, the weather, and the Deeper Night, then the systems that were still only named: the two roads between fires, death, the bells, the tasks, the meals, the Hearthfire, the chests, the secret places, the ossuary, the guardians, the named hunts, the tollman, the lamps, and the book of keys, then the lantern itself, the wounds, the Paths, the oaths, the forge of gear, the spells the night teaches, the camps, the writings, the village lamps, the music, the variants, the henge and the summit, the tether rings, the water, and Resonance. Then the assets that can look the same, or cleaner, without spending a frame: the summit rocks, the boss surfaces, and the maps that never became GPU textures. Then the named walks that were still only a kind name, and the draws that repeat a picture the eye already has. Then the walks a person takes with you, the day a daily thinks it is, and the numbers and the breath arc that keep painting after the eye has left them. Then the ash a quit erases, the choir that does not heal, the floor that is gone while you are still standing on it, and the widgets that redraw a still picture. Then the tasks whose sentences name a thing the valley does not keep, the rites whose glow is wider than the safe ground, the song and the sac and the crypt's extra lamp, the numbers a burn keeps throwing, and the plate that redraws while you stand still. Then the wound plate wearing the gloom's name, a Warden who starts the fight already in the air, a rung bell whose pool is wider than its breath, and a toll whose ring is half its earshot. Then a kindled fire whose glow outruns the sanctuary, a camp that closes wounds, and a heap of bones the lock will not leave. Then a rake wider than its red, a blow past the paint, and a shade that bursts past its disc. Then a step whose line is thinner than its mark, a ring that reaches behind the staff, and a block whose word outruns the plate. Then a bolt that swings at a lock you are not facing, a riposte spent before the staff arrives, a surge whose ring is not twice itself, and a kill that closes the plate without a word. Then a channel a nick rewinds, a light blow that keeps the heavy one out, marks that vanish whole, and a stack that closes the plate without a word. Then a nova's ring that misses the tenth a stack, a perfect dodge that leaves you winded, a fall whose lesson names the dark, and a scar that counts in tenths. Then a staff that draws its heavy in the air, a tether that misses the body the bolt hits, a wound number that rounds the plate, and a lash a boss treats as a plain bolt. Then the compass offering two doors, a bell that can eat the walk home, a continue that is a rest, and a sky still turning under the last sentence. Then a door that wants a peal the compass never names, a lamp in the hand the shade does not fear, an oath that calls a ward a mend, and a gate the slot counts twice. Then a feint that fills a Strike bar, a bag a quit leaves behind, a drag the toast calls seven and a half, and a peal that lets a great one stand. Then the hits that skip the roll, a prompt through a wall, an erase tip that says the night carries on, and a checkbox that calls a wound the gloom. Then a frame that rounds the plate, a row named Waygates, a scar lit past its burn, and a root that lasts a moment. Then a shade that carries its own lantern, an orb that whites out the statue, motes brighter than a candle, flames with no wax under them, masks the crypt still samples from RAM, and a horse with no ground under its hooves. Then a lantern glass burning at four and a half, a hall lit past its own wall, eyes at six times the threshold, and four bowls on one altar. Then two circles round one green, a gleaner paid in chances, a kill the plate ignores past 28 m, a step that slows and calls it a root, two seconds a set leaves off its card, a memory table the night does not pay, a lance the panel calls four, a number line that skips the mods it already owns, an ember line that forgets the rest of the bar, a spring whose crest outruns its card, and a rift that takes the dark's discount. Then a Hearthfire card that counts the live reach and only the tier's gloom, a lodestar's second leap at half of seventy percent, a red tell the lesson gives to the lash and the lance, a shield a tap chips, a Kindling foot that still names W and Space, one word for a half and a quarter, a brood the body cannot spoil, and a slag patch that keeps its Dusk number. Then a letter that says twenty while the footer says forty, mites hatched at the Dusk body, two crawlers called at that same body, kin called at half who stay on the kind's own init, the six hunts and the eighteen named on every row, every legal line the forge can print, and the tasks and the camps as they stand. Then a walk, then an index by file. Set in 11 point on A4 it is a long working book: the sheets are the queue, the walk is how they meet in the valley, and the index is how you find the line.

This is a consolidation book. The phase, decided 5 November and still in force, is fix, cut, polish, and playtest. Nothing in these sheets adds a system, an autoload, a new enemy kind, or a new mesh for the wanderer.

---

## How to read a sheet

Every sheet has the same shape.

**See.** What the hands and eyes meet in the app.

**Where.** The file and the numbers as they stand this morning.

**Change.** The smallest edit that makes the two systems already in the night meet in the middle.

**Prove.** How to know it in the app, and which existing test still has to pass.

**Stay.** The thing this sheet must not drag back in.

Bands, used in the order of work at the end:

- **A.** Felt in the first ten minutes, or a real break (a menu that leaves the night live, a horse that deletes a pack, a tell that paints the wrong ground).
- **B.** Felt every fight and every climb.
- **C.** The picture, the mix, the village, the horse as a ride.
- **D.** Hardening a playtester may never see: leaks, static puzzle state, a save that can point at the wrong slot.

---

## Sheet 1 — The night this book is about

**See.** You launch the app, pass the title, and stand in Hearthward with a staff, a lantern, and a bar of gloom. The valley is one night. Light you did not earn does not get to glow.

**Where.** `ui/title_boot.tscn` loads `world/main.tscn`. `world/main.gd` dresses the night and calls `finish_zone_setup()` last. `Realm.build` retires the baked stair layers and raises land, rift, bosses, the tavern, lore, the terrain stamp, flora, the summit dress, progression, the village, life, secrets, encounters, and the cull. The full night is the default. `-- --slice` is the thirty-minute cut. That reversal is in `docs/DECISIONS.md` (6 November).

**Change.** Treat every sheet as a change to this boot, not as a feature beside it. If a sheet needs a new signal, a new group, or a new menu root, it does not belong in this pass.

**Prove.** A normal launch reaches the hearth with the loading cover already gone, the mouse captured, and the wanderer on solid ground.

**Stay.** Five autoloads: Events, Settings, Travel, LightGrid, InputSetup. Pause is `get_tree().paused`. The glow budget stays intensity 0.62, bloom 0.06, HDR threshold 1.15, levels 0 and 1.

---

## Sheet 2 — What this pass is allowed to touch

**See.** The robe, the void face, the staff in the right hand, the four stair fires, and the dark of the valley are the game. Polish that keeps them and makes the body, the blows, and the screen agree.

**Where.** Binding list: `.cursor/skills/umbral-donts/SKILL.md` and `.cursor/rules/umbral-constraints.mdc`. Pillars: `docs/PILLARS.md`. Item level, gear sets, and rested XP stay, by the decision of 5 November. They get fitted to the dark, not cut.

**Change.** When a sheet and a rejected look argue, the rejection wins. Runtime dress over a rebake. Hide one node over deleting a class of props.

**Prove.** After a pack, the wanderer is still robe pieces, wave-shader cloth, a dark face, and a one-hand staff. The stair still has StairFoot, Shrine, Landing, and Threshold, and no fifth fire.

**Stay.** No `gothic_bay.glb` or `toad.glb` as level meshes. No bead-arches, blob guardians, mint panes, paper-strip robes, cape, hem, asymmetric sleeves, silver cloth, or the purple arcane robe shader. No far depth of field. No player-lantern shadows. No headless rebake of `world/main.tscn`. Internal height cap 960. Arch walkable stays `ARCH_W` 1.16 and `ARCH_Y0` 0.46.

---

## Sheet 3 — How a number in this book should move

**See.** The night already eases a lot of things on the rendered frame: camera field of view, cloth uniforms, the spring on a step-up, the merged bones between physics ticks. The hits that remain are the places where two of those systems use different thresholds and the body snaps across the gap.

**Where.** Physics is 60 Hz. The display Luke plays on is 120 Hz, with the frame capped at 144 and vsync on, Cinematic preset, 1920×1080, 3D height capped at 960. A value that changes inside `_physics_process` and is only read by a bone will be interpolated by the skeleton blend and can stay. A value that resizes a capsule, places a hurt shape, or paints a telegraph will pop, because those are not interpolated.

**Change.** Prefer moving an existing ease, buffer, or threshold so the two systems meet. A new tween for a single pose is the wrong tool when `exp(-k * delta)` is already next to the pop.

**Prove.** Any feel change is judged in the app at those settings, then `tools/run_tests.sh` still ends `ALL n PASS` before a pack.

**Stay.** Tests and renders set `Travel._busy = true` so they never write the owner's `savegame.cfg`.

---

## Sheet 4 — The first second after the cover lifts

**See.** The cover comes off and several voices speak at once: a title card, a region line, a controls card, and sometimes the opening narration. The night has already been told three ways before you have taken a step.

**Where.** `ui/loading_screen.gd` holds the player on `PROCESS_MODE_DISABLED` while the tree keeps running. Wildlife, villagers, ambience, and the warm-up camera move under the cover, so beds and spots thrash before you can hear the place. `core/story/story.gd` now waits for the cover before the opening line, which is the right hook. `ui/hud.gd` then queues seven lessons (`move`, `jump2`, `hang`, `slide`, `lock`, `gloom`, `roll`) into the same lane as narration. A fresh night can sit on "WASD move" for about 5.6 seconds over the hotbar.

**Change.** Pause the tree for the loading tour and keep only the loading canvas on `PROCESS_MODE_ALWAYS`. Hold every lesson until the cover has gone and the title card's tween has finished. One key after the build phase may jump the cover to its fade, so a long warm tour can be left.

**Prove.** A new game shows the place, then the title, then one controls card, then the first lesson. The wind bed does not swoop across the map during the tour.

**Stay.** The world still teaches. A lesson that restates a sentence already shown by the place waits. The card stays four lines, device-aware, hidden while a menu has the mouse, and gone after about twenty seconds of play.

---

## Sheet 5 — Lessons that name the wrong key

**See.** You rebind a key, or you pick up the pad, and the hint still says WASD or A. The night taught you a control you do not have.

**Where.** `ui/hud.gd` `_pk` / `_key` hardcodes pad labels ("A", "B", "L3", "R3") and reads only the first `InputEventKey` for the keyboard. `ui/hints.gd` `key` does the same and ignores the pad. `InputSetup` already knows the live event. Settings writes rebinds into `Settings.bindings`. After a rebind, the stored "already shown" flag keeps the old sentence.

**Change.** Read `InputSetup.event_name` of the first event for the device in hand. On a successful rebind, clear the matching `tip_*` flag so the next hint prints the new key.

**Prove.** Bind interact to a different key, then walk up to an unlit brazier. The prompt and the next lesson name that key. On a pad, the same prompt names the pad button.

**Stay.** `toggle_settings` stays reserved. Axis rows that cannot be rebound yet are labelled as fixed (RT, LT, the sticks) so the Controls page stops looking unfinished. That labelling is sheet 86.

---

## Sheet 6 — The walk

**See.** From a stand, a tap to the side dies. From a run, a hard reverse brakes on the old line and the robe barely notices. In the air, a jump keeps the speed you had when your feet left, including the blend between walk and sprint.

**Where.** `player.gd` exports: walk 4.5, sprint 7.5, accel 14 (about 0.16 s to most of a walk), sprint accel 6.5 (about 0.3 s from walk to sprint), decel 14 plus a bite of 8, coast 6, turn 13 / 8 rad/s, skid 2.2 rad, air accel 8.5, air drag 0.6. `PlayerLocomotion._ground_move` snaps direction below about 2 m/s and multiplies speed by the stick's dot, so a 90° tap from a creep zeroes you. A reversal past the skid angle brakes at `decel * 1.3` with no extra pose. `_run_blend` freezes for the whole jump.

**Change.** Use the turn-rate path down to about 0.3 m/s. While the skid brake is active, multiply the torso-pitch target `CharacterRig` already springs from `_local_acc` by about 1.8, so the robe rocks into the stop. Ease `_run_blend` toward live horizontal speed in the air with the same `exp(-5 * delta)` used on the ground. Raise air drag to about 2 when the stick is idle, and keep 8.5 while it is held, so a mistimed jump bleeds and a steered jump carries.

**Prove.** Creep, tap sideways, and you turn instead of stopping. Sprint, reverse, and the hood and hem answer the stop. Jump from a sprint and the gait in the air follows the stick you hold now.

**Stay.** Walk 4.5 and sprint 7.5 stay. They are the speeds the vault, the slide, and the enemy lead all assume.

---

## Sheet 7 — The jump's hang

**See.** A held jump floats, then kinks, then falls. A tap and a late release feel like the same jump. If you hold jump through a long fall, you do not jump when you land.

**Where.** `APEX_GRAVITY` 0.62 and `FALL_GRAVITY` 1.3 in `player.gd`. The hang applies only while rising, jump held, and `velocity.y < 1.6`. That cutoff ends the float while you are still going up. Releasing jump multiplies `velocity.y` by `jump_cut` 0.5 once. The buffer (`0.15`) fills only on `is_action_just_pressed`. Coyote is `0.13`.

**Change.** Drive the apex scale with a smoothstep from 0 to about 2.2 on `velocity.y`, so the float dies as the rise dies. On release, move `velocity.y` toward about 2.2 over 0.08 s instead of halving it once. While jump is held and you are airborne, keep refreshing `_buffered_jump`, so a hold through a fall still hops on landing.

**Prove.** A tap is a short hop. A hold hangs and comes down without a corner in the arc. Hold jump off a long drop and you leave the ground the frame you arrive.

**Stay.** Jump velocity 5.2 and air-jump 5.8 stay. Gravity 16 stays. The second jump is still a choice you spend, not a glide.

---

## Sheet 8 — Slopes and the steep

**See.** You walk a ramp, then one step steeper the feet give up and you are in a slide. Losing the ground for a single frame on that slide drops you into a fall, and the entry of the slide sets your fall speed in one tick.

**Where.** Uphill scale 0.32 per unit grade, downhill 0.08 (`PlayerLocomotion._slope_scale`). `floor_max_angle` is 46°. Contact memory treats a normal steeper than about 44° as the steep slide, so the walkable band and the slide band overlap the wrong way. `_note_contacts` remembers the steep for 0.12 s. Entry sets `velocity.y = min(vy, -4)` at once. Cap is `STEEP_MAX_V` 10. `_steep_k` already eases at 6/s.

**Change.** Walk up to about 48°. The steep slide starts only below about 50°, with a few degrees of overlap where speed eases from one mode into the other. Hold the steep contact for 0.28 s. Ease `velocity.y` toward −4 over 0.1 s. Let `_steep_k` remain the only blend on the pose.

**Prove.** A ramp you can see as walkable stays walkable. A face that is clearly a slide takes you, without a one-frame fall when the capsule kisses a seam.

**Stay.** The steep pose can stay a crouch. The cap at 10 m/s stays, so a mountainside is a ride and not a launcher.

---

## Sheet 9 — Landing

**See.** A medium drop slows you as if the speed had never been there: you skate through the landing. A harder drop rolls if you were moving, and folds the knees if you were still, with no shared wind-up. Dust, slow, roll, and a wound are four different ideas of "that was high."

**Where.** `PlayerLocomotion._land`. Impacts above `LAND_SLOW_V` 7.5 set `_land_slow` up to 0.5, or 0.75 past `ROLL_LAND_V` 11, recovered at 2.2/s. The slow multiplies the target speed, so current velocity keeps going. Dust from about 5, slow from 7.5, roll from 11, wounds from `FALL_HURT_V` 16 (about 6 m), at 2.6 wounds per extra m/s, halved if you rolled, and capped so a fall cannot hollow you by itself.

**Change.** Apply about half the landing slow to horizontal velocity immediately, and keep the rest as the recover. Use one scale: dust from 6, slow from 8, the roll offered from 10, wounds from 14. In `_pose_roll`, hold the compress until about 12% of the roll so a moving hard landing shows the knees before the spin.

**Prove.** Drop from a roof you can survive. The body dips, the speed actually comes off, and you can tell a bruise from a wound by the height.

**Stay.** A roll on a hard landing still has its i-frames off. It is a recovery, not a free dodge. Sheet 13 keeps that.

---

## Sheet 10 — The air jump and the tuck

**See.** The second jump throws your horizontal speed at the stick in one frame. The tuck on the rig is already a smooth thing. The velocity is not.

**Where.** `PlayerLocomotion._air_jump` lerps horizontal velocity 70% toward the stick in a single physics frame. `air_tuck()` sets `_tuck = 1`, and the rig decays it at 2.2/s.

**Change.** Ease the horizontal redirect with `exp(-12 * delta)` over about 0.15 s. Keep the tuck.

**Prove.** Air-jump across your own sprint and the body turns with the tuck, instead of sliding sideways and posing afterwards.

**Stay.** The air jump still costs `Stamina.AIR_JUMP` (8). It still requires the coyote to be spent and the feet to be off the ground.

---

## Sheet 11 — Breath

**See.** You can roll until you are empty, and the only answer is the word "winded." The body does not stumble. Sprint costs breath only when a foe is inside 18 m, polled every quarter second, so a fight at the edge of that ring flickers the drain.

**Where.** `stamina.gd`. Breath max 100, regen 34/s after 0.55 s, winded until 40. Sprint 8/s inside `FIGHT_R` 18. Roll 22, hop 14, air jump 8, glide 8/s. `can()` allows a spend at half cost, so the last roll empties you and sets winded.

**Change.** On the winded transition, set a short `_land_slow` around 0.35 and call the rig's existing `hurt_react` with a small amount. That is a stumble of about 0.15 s, using poses that already exist.

**Prove.** Empty the bar with rolls in a fight. The last one still happens, and the next step is heavy until the bar climbs past 40.

**Stay.** Breath stays a fight resource. Out of combat, sprint is free. That is the right call for a valley you have to cross.

---

## Sheet 12 — The slide as a slide

**See.** A sprint slide is over before it feels like a commitment. Steering a slide in a new direction takes longer than the slide lasts. The capsule is already crouched while the robe is still standing. A lip on the stair ends it.

**Where.** `player.gd` slide exports: boost 1.3 or at least sprint × 1.15, minimum speed 3.4, friction 4.2, slope gain 13, max time 1.2 plus three times the downhill, cooldown 0.35. `_tick_slide` ends below 2.4 m/s, so a flat sprint slide dies inside a second. Steering is clamped to 1.4 rad/s. `_try_slide` snaps the capsule height to 1.0 the frame the slide starts, while `slide_blend` eases at 8/s and the pose reads that blend. Any air time over 0.18 s kills the slide. `STEP_DOWN` is 0.5, so a stair nose is exactly the kind of miss that ends it.

**Change.** Drop flat friction to about 2.8 so a sprint slide holds nearer 1.2 s, and keep the slope gain. Raise the steer clamp to about 3.2 rad/s and bleed about 15% of speed per 90° of turn. Drive capsule height from `slide_blend`. Allow 0.35 s of air, and if you re-ground above `slide_min_speed`, keep the slide.

**Prove.** Sprint, slide, and steer around a brazier. The robe and the capsule crouch together. A single step does not stand you up.

**Stay.** Cooldown 0.35 stays. The slide is a burst, not a second sprint.

---

## Sheet 13 — The slide as a dodge

**See.** The first moments of a slide pass under a strike, and the banner says "evaded." A roll in that same window can be a perfect dodge. The slide cannot.

**Where.** `SLIDE_EVADE` is 0.22, set once in `_try_slide`. `PlayerVitals.on_evaded` requires `_roll_t <= PERFECT_T` (0.2). A slide only takes the plain evade branch.

**Change.** Give the first 0.12 s of a slide the same perfect-dodge branch the roll uses.

**Prove.** Slide under a wretch's rake as the red commits. You get the perfect-dodge answer, once, at the start, and a late slide is only a pass-under.

**Stay.** The rest of the slide stays an evade window, not a parry. Staff-art parry is its own timing (sheet 40).

---

## Sheet 14 — The roll's commitment

**See.** You press the dodge late in a roll's cooldown and nothing happens. You press it on the way off a kerb and nothing happens. The roll itself starts at full speed, while the pose waits a moment before the spin, so the body slides and then tumbles.

**Where.** `ROLL_TIME` 0.55, `ROLL_DIST` 4.4, i-frames `ROLL_EVADE` from 0.04 to 0.3, hop 0.36 s at 5.6 m/s with `velocity.y = 2.4`, cooldown 0.3 after the roll ends. Active i-frames are about 0.26 s inside a 0.55 s commitment, then a 0.3 s lockout, and no buffer. `_try_dodge` requires `_grounded`. Coyote does not count. Entry speed is about 10 m/s with no ease-in. The pose already delays the spin with `smoothstep(0.06, 0.86, u)`.

**Change.** Store a 0.12 s dodge buffer the way jump does, and fire it when the cooldown ends if you are still on the ground. Treat coyote as ground for the roll, and spend the same `Stamina.ROLL` (22). Ramp speed from the current velocity up to the peak over about 0.06 s so the tuck and the burst agree. Move the pose's spin start toward 0.12 so the compress reads.

**Prove.** Tap dodge a fraction early, land, and you roll. Dodge off a kerb during coyote and you roll. The spin starts with the speed.

**Stay.** The window stays inside the roll. A roll is not invincible for its whole 0.55 s.

---

## Sheet 15 — I-frames between ticks

**See.** A hit that lands between physics frames can catch you inside the window that was supposed to be safe. The code re-stamps a tiny evade time every tick, so the protection is a chain of short stamps instead of one window.

**Where.** `PlayerEvasion._tick_roll` sets `_evade_t = 0.02` each physics frame inside the window.

**Change.** Set `_evade_t` to the remaining window (`ROLL_EVADE.y - _roll_t`) once, and let it count down.

**Prove.** `zz` combat tests still pass, and a bolt that overlaps the roll during the window does not wound. A bolt after 0.3 s does.

**Stay.** The slide's own evade stamp (sheet 13) stays a single set at the start, with the perfect-dodge slice at the front.

---

## Sheet 16 — Standing up after a roll into a wall

**See.** A roll into a low ceiling or a wall drops you into a crawl. With no stick you freeze there. You stand only when the next roll-loop happens to notice headroom.

**Where.** No headroom snaps `_roll_t` to `ROLL_TIME * 0.98` and `CRAWL_SPEED` 1.6. A wish shorter than 0.04 returns zero, so a dead stick holds the crouch. `_headroom()` is the stand test.

**Change.** While crawling, slide along the wall's tangent at 1.6 even with no stick. Stand on the frame `_headroom()` is true.

**Prove.** Roll into the Keg's porch and into a crypt pier. You come out of the crouch the moment the ceiling allows, and you are not glued to the wall.

**Stay.** The crawl remains the answer to a real low ceiling. Headroom stays the authority.

---

## Sheet 17 — The glide

**See.** Out of jumps, with clear air, the robe opens and the fall speed becomes −4 in one frame. The blend on the rig eases. The vertical speed does not. If the height check fails, the jump press can fall into a buffer that will never fire, and nothing tells you.

**Where.** `PlayerEvasion._start_glide` needs jumps spent and clear air of `GLIDE_MIN_H` 1.6, then sets `velocity.y = max(vy, -4)`. Sink is `GLIDE_SINK` 2.3, speed `GLIDE_SPEED` 8.8, turn `GLIDE_TURN` 2.6 rad/s. `_glide_k` eases at 5/s in and 7/s out. The player tick already eases vertical speed toward the glide sink once gliding (sheet 7's neighbour, around the updraft branch). The pop is the frame you enter.

**Change.** Ease `velocity.y` toward −4 over about 0.15 s on entry. If the height check fails, spend nothing and use the same refusal flash stamina already shows.

**Prove.** Step off a high perch with no jumps left. The robe opens and the fall eases into the sink. Step off a kerb and you do not enter a glide, and the jump you still held is not swallowed.

**Stay.** Glide costs 8 breath per second. It remains the third thing, after the jump and the air jump.

---

## Sheet 18 — The step that is neither a step nor a vault

**See.** A kerb around half a metre stops you. It is too tall to walk up and too short to vault. You bonk, then a moment later, once you are fast enough, you vault the same stone.

**Where.** Step-up `STEP_MAX` 0.45. Vault from `VAULT_MIN` 0.50 to 1.25. Mantle 0.30–1.10 and only while `is_on_wall()` and airborne. Grab from `GRAB_MIN` 1.1 to `GRAB_MAX` 2.25. Vault needs speed ≥ 3.8 and a wish aligned at least 0.7, and you must be grounded. Walk speed is 4.5, so a full walk vaults, but the accel ramp spends a tenth of a second under 3.8.

**Change.** Set `VAULT_MIN` to 0.42 so it overlaps the step-up. Lower `VAULT_SPEED` to 3.2. Remember a bonk for 0.1 s and vault next frame if you are still pushing.

**Prove.** Walk at a 0.47 m kerb and you go over it, either as a step or as a low vault, without a stop. Sprint at a waist-high rail and you vault.

**Stay.** Step-up remains the quiet path for anything the capsule can walk. Vault remains a speed commitment. Grab remains the high band, from 1.1 up.

---

## Sheet 19 — The step-up and the feet

**See.** You walk a step and the skin lags, which is good, and the feet stretch, which is not. The rig is still offset while the foot rays hit the real ground.

**Where.** `PlayerLocomotion._try_step_up` teleports by the rise plus a centimetre, then up to five 6 cm nudges, then `_ease_shift`. The camera spring is `w = 11` and the visual spring is `w = 22`. Foot IK runs on the real ground.

**Change.** While `_vis_off` is longer than about 2 cm, blend the gait IK weight `_plant_k` down with that offset, so the feet ride the eased rig.

**Prove.** Walk the stair and a porch. The legs stay under the robe during the rise.

**Stay.** The teleport-plus-spring stays. It is what keeps the step from being a ramp you have to author.

---

## Sheet 20 — Step-down and the double dip

**See.** On a stair nose the camera dips twice. Floor snap and step-down both decide you have dropped, on successive frames.

**Where.** `_step_down` glues drops up to `STEP_DOWN` 0.5 and uses the same ease. `floor_snap_length` is also 0.5.

**Change.** If `is_on_floor()` after `move_and_slide`, skip `_step_down`.

**Prove.** Walk down the porch steps and the Keg stair. One dip per step.

**Stay.** A real drop deeper than the snap still plays the landing (sheet 9).

---

## Sheet 21 — The vault's arc

**See.** The vault is a curve in the code and a polyline on a 120 Hz screen. You land already "grounded," so a short landing ray pops you to a stand. You leave at walk speed even if you entered at a sprint.

**Where.** `PlayerTraversal._tick_vault` places the body on a piecewise curve (apex at `u = 0.42`) and returns before `move_and_slide`. Exit sets `_vault_t = -1`, velocity to `_vault_v`, and `_grounded = true` in one tick. Mantle's exit, nearby, forces `walk_speed` (sheet 22).

**Change.** Sample the vault curve in `_process` from `_vault_t` and the physics interpolation fraction, the same way the camera offset is already interpolated. On exit, leave `_grounded` false for one frame and let `move_and_slide` plus `_land` play the dip. Keep `max(walk_speed, incoming horizontal × 0.85)` so a sprint vault stays a sprint.

**Prove.** Vault a rail at the hearth and at a sprint on the road. The arc is smooth, you dip on the landing, and you come off near the speed you took in.

**Stay.** Vault still needs the wish aligned. It is not a sideways hop.

---

## Sheet 22 — The mantle

**See.** You jump at a wall, peak a few centimetres off the face, and neither mantle nor grab. A mantle that starts during a step-up leaves the camera offset stuck. The pose runs longer than the body. The view bumps because the spring is faster than the rise the comment wanted.

**Where.** `_try_mantle` requires `is_on_wall()` this frame and `velocity.y ≤ 3.5`. Grab's chest ray is 0.8 m and is used when you are clearly in the air. `_tick_mantle` does not call `_ease_tick`. `MANTLE_TIME` is 0.24 s, and `play_move(&"mantle", MANTLE_TIME * 1.5)` runs the pose for 0.36 s. Exit velocity is forced to `walk_speed`. Sixty percent of each rise is stuffed into `_cam_off.y`, then a spring at `w = 11` (time constant about 0.09 s) pulls it back. The comment wants about 0.4 s.

**Change.** When `is_on_wall()` is false, probe with the same 0.8 m chest ray grab uses. Call `_ease_tick` during the mantle. Use `w = 6` on the vertical camera offset for the mantle, or skip that spring while `_mantle_t` is live. On exit, keep the greater of walk speed and 85% of the incoming horizontal speed. Start the mantle pose at `u = 0.15` so the hands plant before the hips rise (the pose itself is sheet 36).

**Prove.** Jump at a wall you can see a handhold on. You catch it. The camera rises with you and settles, and a sprint into the mantle does not become a walk at the top.

**Stay.** Mantle time stays short. It is a catch, not a climb. Climb stays the long pull (sheet 24).

---

## Sheet 23 — The hang

**See.** You catch a ledge and the body is in the hang pose on the same frame. A jump pressed in the first 0.18 s is dropped. Shimmy at 1.3 m/s with no accel, and a ledge that drifts more than 12 cm stops you dead in the hang instead of letting you drop. Letting go leaves you floating off the lip.

**Where.** `_start_hang` sets `hang = 1` and snaps `rotation.y`. `_tick_hang` lockout is 0.18 s and only `just_pressed` counts. Shimmy speed `SHIMMY` 1.3, stick threshold 0.3. `_ledge_at` fails above 0.12 m of top drift. `_let_go` sets velocity to the hang normal times 1.0 or 1.5, with no downward component. `_regrab` is 0.45, long enough to fall past a second grip.

**Change.** Ramp `hang` from 0 to 1 over 0.12 s. Buffer jump for the 0.18 s lockout. Ease shimmy with the existing `hang_shimmy` blend. If the ledge fails for 0.15 s while the stick is held outward, let go. On let-go, set `velocity.y = -1.5` and `_regrab = 0.25`.

**Prove.** Catch the crypt gallery lip and the tavern porch. The hands arrive, a jump during the catch still climbs or drops as you asked, and releasing falls.

**Stay.** You still cannot grab through a lit window just because the ray hit a frame. The ledge test stays.

---

## Sheet 24 — The climb onto the crown

**See.** You pull up and the exit shoves you forward at 1.2 m/s along the opposite of the hang normal. On a narrow crown that walks you off the far side.

**Where.** `_tick_climb`. `up_u = smoothstep(0, 0.62, u)`, `fwd_u = smoothstep(0.38, 1, u)`, `CLIMB_TIME` 0.62. Exit velocity is `-_hang_n * 1.2`.

**Change.** Exit along the ledge normal at about 0.4 m/s, and play `_land` if the deck faces up.

**Prove.** Climb onto a wall top and onto a narrow stone. You stay on it.

**Stay.** The two smoothsteps stay. They are the pull and the knee, and they read.

---

## Sheet 25 — The wall kick that coyote steals

**See.** Near the ground, a jump off a wall does the coyote hop instead of the kick. The kick's outward speed is then capped at sprint while the upward speed is not. The leg hits the wall in the pose after the velocity has already changed.

**Where.** `_can_wallkick` returns false while `_coyote > 0`. The jump press then takes the coyote jump. `_wall_t` lives 0.15 s. `KICK_UP` is 6.4, `KICK_OUT` is 5, then horizontal speed is limited to `sprint_speed` 7.5. `_kick_lock` is 0.22 s and freezes air steering. `play_move(&"wallkick", 0.42)` puts the push in the first tenth of `_pose_wallkick`.

**Change.** Test the wall kick before coyote. Extend `_wall_t` to 0.28 s. Lengthen the pose's push to about 0.16 of the 0.42 s so the foot meets the wall as the velocity changes. Hold that pose push until about 55% of the move (sheet 36), matching the 0.22 s lock.

**Prove.** Fall along a wall close to the floor and jump. You kick. Fall along a tall face and jump. You kick, and the foot is on the stone when you leave it.

**Stay.** One kick, then the lock, then steering returns. A wall is not a ladder.

---

## Sheet 26 — The beam

**See.** A narrow top twitches under you. Every other physics tick a probe adds a sideways kick with no damping, and most of your strafe is deleted, so you vibrate down the centre.

**Where.** `_beam_probe` runs every other tick. `_beam_mid` is 0 or ±0.12, added as `side * mid * 8 * _beam_k`. Speed is cut to `walk * 0.72` and 85% of lateral input is removed.

**Change.** Replace the kick with a spring toward the midline, stiffness about 20 and damping about 8.

**Prove.** Walk a bridge rail or a crypt beam. You drift back to the middle and you can still steer.

**Stay.** The speed cut on a beam stays. A beam is not a sprint.

---

## Sheet 27 — The grapple line

**See.** The rope steps. The body arrives and reverses. Both are the physics tick showing through.

**Where.** `grapple.gd`. Accel 60 to `SPEED` 21, pop `POP_UP` 6.2 and `POP_OUT` 3.5, stuck cancel 0.2 s, arrive radius 0.7. `_draw_line` uses `muzzle()` on the physics tick. Arrival sets a pop velocity at once.

**Change.** Draw the line in `_process` from `muzzle_drawn()`. On arrival, set velocity to about 0.65 of the haul for one frame, then add the pop.

**Prove.** Fire a tether at a far anchor and at a near one. The line is smooth at 120 Hz. You arrive without a one-frame backwards jerk.

**Stay.** Stuck cancel at 0.2 s stays, so a grapple into a corner lets go.

---

## Sheet 28 — Feet that skate

**See.** At a sprint the planted foot slides. This is the main foot pop in the whole night.

**Where.** `_gait_legs` and `_leg_ik` run inside `animate`, on the physics tick (`character_rig.gd`). `_process` only lerps bone transforms between those poses. At 7.5 m/s the body moves about 12 cm per tick, and a planted foot slides across half of that before the next solve. The skeleton blend hides some of it and leaves the rest, which reads as a skate, especially on the stone of the hearth.

**Change.** Solve the two-bone IK in `_process` from the interpolated pelvis, or counter-move the foot bone by the interpolation fraction so a planted foot stays on its world point between ticks.

**Prove.** Sprint past the hearth fire and along the meadow lane. The sole that is down stays down. `zz/move_course` still passes.

**Stay.** The planted-foot gait stays. This sheet makes it true between frames. It does not replace it with clips.

---

## Sheet 29 — Starting and stopping the cycle

**See.** A slow walk shuffles in place. The cycle starts above 0.6 m/s. Between 0.35 and 0.6 you get corrective steps and no stride. Takeoff keeps a mushy fraction of the walk for about 0.15 s. A moving landing plants both feet on the world point under the airborne foot in one frame, and the trailing foot pops.

**Where.** `STEP_KEYS` map speed to step length: 0 → 0.30, 1.5 → 0.52, 3 → 0.78, 4.5 → 1.0, 7.5 → 1.5, 11 → 1.8 metres. Airborne target stride is × 0.3 while `_air` ramps at 6/s. `_gait_advance` starts the cycle above 0.6 and settles after 0.06 s under 0.35. `_land_feet` plants both feet at once, then a landing above 0.6 forces the phase.

**Change.** Lower cycle entry to 0.35, and require 0.12 s under 0.25 before the settle. On the first airborne frame, snap the target stride toward 0.15, and keep the existing 0.28 s jump extension. On landing, plant the leading foot immediately and swing the other in over 0.12 s with the existing `_swing_foot`.

**Prove.** Creep. The feet step. Stop. They settle. Jump and land while moving. One foot catches, the other swings through.

**Stay.** The key table stays. Step length at a walk and at a sprint is already in a good range.

---

## Sheet 30 — IK against a pose that has already decided

**See.** Slide, air, and the tuck all start, and for a few frames the feet are still glued to the walk. Then they pop into the pose.

**Where.** `_plant_k` moves at 9/s in and 14/s out. Slide overlay and air forward-kinematics run, then `_gait_legs` still has weight for about 0.07 s.

**Change.** Zero `_plant_k` on the frame `slide > 0.2` or the feet leave the ground. Skip `_gait_legs` as soon as the mount blend `ride` exceeds about 0.05, so sitting a horse does not IK the feet to the ground for the first half of the mount (sheet 92).

**Prove.** Enter a slide and a jump from a full stride. The feet leave the ground with the pose. Mount, and the feet are on the horse immediately.

**Stay.** On ordinary ground the plant weight still eases in, so a stop does not snap the soles.

---

## Sheet 31 — The slide pose leads with the knees

**See.** The slide blend takes an eighth of a second to arrive, and the pose follows it. There is no anticipate. The capsule, after sheet 12, will crouch with the blend. The body should drop with the knees first.

**Where.** `_pose_overlay` lerps the legs to a seated split by `slide`. Tuck already adds hip bend.

**Change.** On slide entry, set `_tuck` to about 0.8 for the opening so the knees lead the pelvis.

**Prove.** Slide from a standstill creep (the slow-slide roll path) and from a sprint. Both read as a drop, then a travel.

**Stay.** The seated split stays the pose. This sheet only orders it.

---

## Sheet 32 — Cloth on a turn, and the hood on a catch

**See.** A steady sprint nails the hem. A step-up or a mantle, the moves that should toss the hood, zero the hood's acceleration and the hood stays still.

**Where.** `cloth_lag` is forced to zero unless stride is under 0.2, or you are landing, or airborne, or acceleration exceeds 10. `_hood_tick` zeroes acceleration above 90, which is a step-up or a mantle.

**Change.** Feed a small lag from lateral turn only, `_turn * 0.02`, always, capped at 0.06, so a hard turn drags the hem and a straight sprint stays quiet. Clamp the hood's acceleration instead of zeroing it.

**Prove.** Sprint a circle around the hearth. The hem trails the turn. Mantle a wall. The hood answers.

**Stay.** The wave shader stays the cloth. No silver, no cape, no extra cloth mesh. The trail on the staff still quiets toward 0.16 amount and 0.38 life at a sprint.

---

## Sheet 33 — Standing still

**See.** A long stand is a very slow drift, then a one-frame fidget of the hands. Breath on the chest vanishes the moment the stride exceeds half.

**Where.** `_idle_life` weight shift is `sin(t * 0.43)`, a period of about fifteen seconds. Idle acts wait 5–10 s, then cut off at 5/s when you move. The regrip is `pow(sin(t * 0.23), 12)`, a spike. Chest breath is 0.012–0.018 and only while `idle > 0`.

**Change.** Use a sway nearer `sin(t * 1.1)`. Smooth the regrip with a smoothstep over 0.2 s. Keep a breath of about 0.006 at all speeds.

**Prove.** Stand at the fire for twenty seconds. The weight moves, the hands regrip, the chest moves. Walk. The breath is still there, smaller.

**Stay.** Idle acts stay rare. A wanderer who performs every five seconds becomes a mascot.

---

## Sheet 34 — Cast poses when the bolts chain

**See.** Rift Bolt's cooldown is 0.28 s. The cast pose is 0.42 s and a repeat restarts near the beginning, so a chain skips the pull-back. You see a series of flicks with no ready. Facing a target yaws 60% in one frame and then eases.

**Where.** `cast_pose` and `_cast_tick`. Bolt envelope is `smoothstep(0, 0.16) * (1 - smoothstep(0.32, 1))` over `CAST_LEN` 0.42, with a recoil kick from 0.14 to 0.6. Repeats restart at 16% of the length. `_face_now` lerps yaw 60% in one frame, then `exp(-24)`.

**Change.** Restart a repeat at about 0.35 of the length so each bolt has a short pull-back. Replace the 0.6 yaw snap with `exp(-18 * delta)`.

**Prove.** Hold the bolt on a wretch. Each shot has a small ready. The chest turns onto the target without a pop.

**Stay.** Bolt cooldown 0.28 stays. The chain is the feel of the weapon. The pose fits the chain. It does not slow it.

---

## Sheet 35 — Channels that have no pose until they resolve

**See.** Umbral Well and the Bound Shade root you, and the staff pose arrives only when the skill actually fires. The channel itself is a stand.

**Where.** `skill_book.gd` `_begin`. Well `cast_time` 0.6, familiar `cast_time` 1.0, rooted after `MOVE_GRACE` 0.2 s of movement above 0.3. `cast_pose` is applied when `skill_cast` fires, which is after `try_cast`.

**Change.** Call `cast_pose` when `_casting` starts, and hold the pose blend at 1 until `cast_stopped`.

**Prove.** Cast the well and the shade from a stand and from a walk. The staff is in the channel for the whole root.

**Stay.** Moving past the grace still cancels. The world teaches that a long cast is a stand.

---

## Sheet 36 — Hang, climb, vault, and wall-kick poses

**See.** Hang is a full-body lerp that is already finished if `hang` snaps to 1 (sheet 23 ramps it). Climb starts from "arms already up." Mantle calls the climb pose from 0.35, so the hands are high before they plant. The wall-kick leg retracts while you are still locked to the kick vector.

**Where.** `_pose_hang`, `_pose_climb`, mantle's call `_pose_climb(0.35 + 0.65 * u)`, `_pose_vault` fades by `smoothstep(0.7, 1)`, `_pose_wallkick` ends its push by `u = 0.45` of 0.42 s (about 0.19 s) while `_kick_lock` is 0.22 s.

**Change.** Start the mantle pose at 0.15. Hold the wall-kick push until `u = 0.55`. Vault's fade can stay.

**Prove.** Mantle, climb, and kick against the tavern wall. Hands first, then hips. The kick leg stays on the wall for the lock.

**Stay.** These stay procedural poses on the existing rig. No new clips, no new bones.

---

## Sheet 37 — Air, fall, and glide on the same hips

**See.** The fall pose arrives late because `_air` is still ramping. The glide opens the arms and the legs stay on the air pose, so the hips fight.

**Where.** `_land` is at least 0.25 and decays at 3.5/s. `_land_hard` decays at 1.5/s and never plays if a roll started (`animate` skips it when `move_playing() == &"roll"`). The air pose adds knee drive from `vy / 5` and a fall reach from `-vy / 9`, scaled by `_air`. Glide lerps the arms with `glide` and both write the hips.

**Change.** Set `_air = 1` the first frame the feet leave the ground. Multiply the air-pose hip add by `(1 - glide)`.

**Prove.** Step off the porch into a glide. The fall pose is there at once, then the glide takes the hips as the robe opens.

**Stay.** A hard landing that becomes a roll still uses the roll. Sheet 9 only asks the roll to show a compress first.

---

## Sheet 38 — The staff art lunges before the staff moves

**See.** A light hits at 0.13 s and a finisher at 0.21 s, and the body is already at full lunge speed until the hit, then brakes over 0.15 s. The staff is behind the feet. The guard pose is up in about 0.07 s, and the parry window is 0.2 s, so the window is open before the staff is across the body.

**Where.** `staff_arts.gd` `drive` and `CHAIN`. Guard `_guard_k` rises at 14/s. `PARRY_WIN` is 0.2.

**Change.** Ramp the lunge with `smoothstep(0, hit_at * 0.5, t)`. Open the parry window only once `_guard_k > 0.65`, and keep the 0.2 s length from that moment.

**Prove.** Chain the staff on a husk. The step and the swing arrive together. A parry pressed as the guard arrives is the parry. A parry pressed before the staff is across is early.

**Stay.** Hit times stay. The combo's rhythm is the weapon.

---

## Sheet 39 — Where the bolt is born

**See.** The charge orb was fixed to draw on the rendered frame. The bolt and the tether still spawn at the physics muzzle. At 120 Hz the shot appears a frame off the hand. The ribbon's head is interpolated and its tail is a 60 Hz history, so the first segment kinks.

**Where.** `player_casting.gd` spawns with `muzzle()`. The charge orb path already uses the drawn muzzle. `magic_bolt.gd` `_update_streak` interpolates the head. `_push_hist` stores physics positions.

**Change.** Spawn bolts and the tether from `muzzle_drawn()`. Push the interpolated head into the history from `_process`, or start the ribbon at `_hist[1]` so the kinked first segment is gone.

**Prove.** Hold a charged lance and fire a bolt while turning. The shot leaves the orb. The ribbon is one curve.

**Stay.** Bolts still come from the Zone's `BoltPool`. The rig never owns them.

---

## Sheet 40 — The bolt meets the body early

**See.** A skill bolt detonates about a metre short of the chest. The streak stops in the air. A tap lance aimed at a far wall dies short of the aim ring, so the ring promised a hit the bolt cannot keep.

**Where.** `magic_bolt.gd` proximity sphere radius 1.05 (heavy 1.35), tested before `move_and_collide`. Overlap against a 0.35 m capsule starts about 1.4 m from the chest. Speed for a skill bolt is 34. `LIFE` is 2.6 s. A tap lance at 18 m/s dies at 46.8 m. The aim ring rays 60 m and draws `BLAST_MIN` 3.0.

**Change.** Set the light radius to 0.32 and the heavy radius to 0.45, and let `move_and_collide` plus the blast resolve the hit. Cap the ring ray at `speed * 2.6`, or raise tap speed to 24 so 2.6 s covers the ring.

**Prove.** Bolt a wretch at contact range and at the edge of the ring. The burst is on the body. A tap aimed at a far stone either reaches the ring or the ring shortens to the bolt.

**Stay.** Life 2.6 s can stay if the ring tells the truth. The pool cap work is sheet 55.

---

## Sheet 41 — The camera yanks and crawls

**See.** A doorway pulls the camera in on one frame and lets it back out over most of a second. A thin pole forces full length for 0.15 s, and if you strafe from that pole onto a wall inside the window the camera is inside the wall. Looking down keeps the full boom and clips the ground. Looking up shortens it.

**Where.** `PlayerCamera._update_arm`. Pull-in is `exp(-28 * delta)`, ease-out is `exp(-3.2 * delta)`, minimum length 0.5. Arm length shortens only when pitch is positive, down to 0.62 of `ARM_LEN` 3.7. `pitch_min` is about 57° down, `pitch_max` about 34° up. Thin poles set `_thin_hold = 0.15`.

**Change.** Ease out at `exp(-8 * delta)`, about 0.3 s. Clear `_thin_hold` when the sphere at the camera point is not clear. Shorten the boom on downward pitch with the same 0.62 curve.

**Prove.** Walk through the Keg door, under a tree, and look down the stair. The camera comes back promptly, stays out of the wall, and does not bury itself in the steps.

**Stay.** The camera collides with `Layers.WORLD` only. Flora dither inside 1.6 m stays the answer for leaves. A missing collider on a dressing piece is a dressing fix (sheet 78), not a camera that starts ignoring props.

---

## Sheet 42 — Field of view, roll, and the hit that does not move you

**See.** Sprinting widens the view. A slide or a Rift Step punches a burst on top, and when the burst falls through the speed kick the field of view kinks. Strafe roll is about 1.4° and nearly invisible. A wound shakes the camera about a degree, while a landing dips it by up to about 7°.

**Where.** FOV kick eases at `exp(-6)` toward `SPRINT_FOV_KICK` 6°, up to 1.6× by speed. Slide sets `_fov_burst_want = 8`, Rift Step 12, snapped in at `exp(-38)` and decayed at `exp(-4)`. The frame takes `max(kick, burst)`. Strafe roll max 1.4°, eased at `exp(-5)`. `kick(1)` is about 1.25°. Landings use `_land_dip`. Wounds call `kick()`.

**Change.** Add the kick and the burst, capped at 14°. Raise strafe roll to about 3.5° at a full lateral sprint, same ease. Drive a wound through `_land_dip_want` (about 0.35 at a full wound) and keep `kick` for a smaller, higher-frequency buzz at about three times the current angle, so a hit has a dip and a shudder.

**Prove.** Sprint, slide, step. The view widens and narrows in one motion. Strafe and you lean. Take a hit and the horizon answers. Take a landing and it is still the bigger dip.

**Stay.** Field of view baseline stays 90. Motion blur stays a settings value (0.35 on Cinematic). This sheet does not add blur to sell a hit.

---

## Sheet 43 — Lead and the death of a lock

**See.** The camera's lateral lead arrives late and, when a lock ends, leaves late. When a target dies or walks out of sight, the view swings around behind you as if you had asked to recentre.

**Where.** Look-ahead is `0.065 * speed`, capped at 0.45 m, eased at `exp(-2.5)`, about 0.9 s. Recentre eases yaw toward the body's back at `exp(-9)` and pitch toward −0.18 at `exp(-6)`, and it runs on a failed lock as well as on an empty toggle. `_lock_tick` drops a lost target after 1.4 s.

**Change.** Ease the lead at `exp(-6)`. Recentre only on the explicit empty toggle.

**Prove.** Sprint a curve. The view leads within a step. Kill a locked wretch. The camera stays where you were looking.

**Stay.** The jump hold on the camera is already in good shape (rises at `exp(-9)`, settles at `exp(-14)`, cap 1.1 m). Leave it.

---

## Sheet 44 — Lock-on

**See.** A tall foe cannot be looked up at while locked. Inside 1.2 m the aim pivot swaps from the shoulder to the body and the yaw spins. Small mouse looks do nothing, then a target pops. The stick swaps targets the moment it passes three quarters, and you cannot nudge the view at all while locked.

**Where.** `PlayerTargeting._lock_view`. Yaw eases at 7, or 4 inside 3 m. Pitch eases at 4 and is clamped to 0.15 rad (about 9°) after a reduced atan. Inside 1.2 m the pivot switches. Locked mouse look accumulates pixels and swaps only past 90 px inside 0.25 s, decaying at 360 px/s. Stick `|x| > 0.75` swaps immediately and zeroes look.

**Change.** Raise the lock pitch cap to about 0.45. Crossfade the pivot over 0.2 s. Break the lock when accumulated yaw would have passed about 0.35 rad, and keep the swap at 90 px. Require the stick to return under 0.4 before another swap.

**Prove.** Lock a husk, a leaper, and the Bone Abbot. You can see the head. Step inside an arm's length and the view does not spin. A hard mouse turn drops the lock. A flick of the stick changes target once.

**Stay.** Lock remains middle mouse and the right stick. The shoulder offset that keeps the crosshair off the robe stays (boom x 0.95, `h_offset` 0.12). Sheet 45 makes that offset follow the shoulder swap.

---

## Sheet 45 — The shoulder

**See.** When the boom swings in because the wall is on that side, the body sits left of frame. The horizontal offset stays 0.12 even when the boom is centred.

**Where.** `_shoulder_tick`. `SHOULDER` 0.95, hidden if at least 4 of 6 rays hit, hold 0.5 s, swing in at `exp(-9)`, swing out at `exp(-2.5)`. `h_offset` is 0.12 in `player.gd`.

**Change.** Multiply `h_offset` by `_shoulder_k`.

**Prove.** Strafe along the Keg wall until the shoulder swaps, then step back out. The wanderer stays on the crosshair's open side the whole way.

**Stay.** Over-the-shoulder stays the camera. This sheet keeps it honest when the side changes.

---

## Sheet 46 — The stick

**See.** A small stick deflection does nothing, then the curve is steep, then a boost arrives late. A 180° turn at full stick takes about 1.2 s before the boost, which is a long time in a fight.

**Where.** Deadzone 0.15 is a step. Curve is `pow(mag, 1.6)`, then `stick_sensitivity` 2.6 rad/s, pitch × 0.8, plus a 1.6× boost after the stick has been hard over for 0.2–0.6 s. Full stick without the boost is about 149°/s. Sensitivity is a saved slider from 1 to 5.

**Change.** Use `pow(mag, 1.25)`. Start the boost at 0.05 s. Soften the deadzone so the first motion above it is small, matching the curve, instead of a step up to the curve's first value.

**Prove.** On a pad, look slowly across the hearth, then flick. Slow is slow. A flick comes up at once.

**Stay.** The slider stays the owner's control. This sheet changes the curve under it.

---

## Sheet 47 — Gloom on the body

**See.** The dark fills in about 33 seconds, the rift in about 20, and the bar stair-steps. The robe does not know. You can be one tick from a shade and look the same as you did at the fire.

**Where.** `gloom_rate_dark` 3.0, `gloom_rate_rift` 5.0, lit drain 12/s, sprint in the dark × 1.5 when `_run_blend > 0.6`. The bar emits when gloom moves by at least 0.5 or 0.1 s has passed. `CharacterRig` never reads gloom or wounds. A kill still drains 6, with a violet wisp, inside 28 m.

**Change.** Emit every change under 0.2. Drive a rune-style uniform on the robe, 0 at empty and about 0.4 at full, so the cloth darkens before the shade. Keep it under the glow budget: a uniform on the existing shader, not a new light.

**Prove.** Walk out of the hearth light. The bar moves smoothly and the robe cools. Step back in. Both recover.

**Stay.** Rates stay. The dark is the clock. A slower gloom would make the valley a walk.

---

## Sheet 48 — The shade and the hollow

**See.** At 100 a shade steps out 16 m behind you, a toast appears, and the body does not flinch. Hollowing waits 0.9 s, teleports, waits 0.4 s, and during the wait you can still slide and fall.

**Where.** `_spawn_shade`, `_shade_lock` 2 s after it is unmade. `hollow` zeroes wish and still runs `move_and_slide`.

**Change.** On spawn, call `kick` and `hurt_react` from the shade's position. While `_hollowing`, hold `_land_hard` and skip `move_and_slide`.

**Prove.** Fill the bar on purpose, away from a save you care about. The arrival is a blow. The collapse holds still, then you are at the last fire.

**Stay.** The shade remains the price of the dark. Touching a hollow still returns you to the last kindled brazier. Lava still hollows on contact.

---

## Sheet 49 — A killing blow with no freeze

**See.** The hit that matters, the one that drops a body, skips the freeze and the shudder. The dissolve starts while the fold is only partway down, so a wretch burns standing.

**Where.** `enemy.gd` `take_hit` sets `_hitstop = 6` on a kill, then `_die()` sets `DEAD`. The dead branch calls `_tick_dying` and never reads `_hitstop`, and it zeroes `_visual.position`. Dissolve starts at 0.25 s and runs 0.95 s. `HunchRig._fold` at 1.6/s is only about 0.4 deep by 0.25 s.

**Change.** Play the 6 frames of freeze and the shudder, then start `_tick_dying`. Delay the dissolve to about 0.55 s so the fold is near done before the burn.

**Prove.** Bolt a hurt wretch to death at the hearth. It freezes, folds, then goes. `zz/combat_duel` still passes.

**Stay.** Hit-stop lengths for living hits stay 2, 4, and 6 frames by damage tier. This sheet gives the kill the 6 it already asked for.

---

## Sheet 50 — Poise, and what a knot is for

**See.** A glowing knot deals 1.6× damage and twice that as poise, which is what the comment in `enemy.gd` says. On a Chanter (poise 0.9) or a Spitter (default 2.6) the first bolt that finds the knot staggers them out of their tell. On a Bulwark (4.5) it nearly does. The knot is a reward. On a light body it is also a delete.

**Where.** `WEAK_MULT` 1.6. A weak hit adds poise once beside the knot, then `take_hit` adds poise again for every hit. Together that is twice the damage dealt. The gold strip under the bar shows the meter. A stagger spends it and leaves the body `BROKEN` for a beat (`BROKEN_MULT` 1.3, bosses 1.2).

**Change.** Keep the twice-poise rule. If a knot on a Chanter or a Spitter should open them up and still let the tell finish when the hit was light, raise that kind's poise so one 1.6× bolt fills the strip and a second breaks it. Leave Bulwark and the bosses on their current numbers until you have felt the light kinds.

**Prove.** Shoot a Chanter's knot once. You see "weak point," the strip fills, and the sigil still has a moment. Shoot it again. It breaks.

**Stay.** Bosses open their knots only during certain moves. That gate stays.

---

## Sheet 51 — The swing and the moment of damage

**See.** A rake connects at the top of the backswing. You are hit, and then the arm comes through. Hit-stop freezes the body and still lets the windup clock run, so a red disc can finish during the freeze and the swing starts a tenth of a second late.

**Where.** `enemy.gd` `_resolve_strike` deals damage at `_state_t >= 0.06`. The rake pose (`RAKE_TIME` 0.32) peaks at the end of that half-period. While `_hitstop > 0` the physics tick returns before the windup-to-strike check, and it still advances `_state_t` for `WINDUP` and `LEAP_PREP`. `SpellFx.danger` fills in real time.

**Change.** Resolve the strike at about 0.20 s, and drive the lunge from the start of `STRIKE` until that frame so the chest is forward when the gloom lands. While hit-stop is up, advance the danger's remaining life by the same frames, or allow the state change on the frame the clock crosses the windup even during the freeze, and hold the disc in step with the body.

**Prove.** Stand in a wretch's arc and watch one rake. The red fills, the arm comes through, the hit and the pose meet. Hit the wretch during its tell. The disc and the body wait together.

**Stay.** "No red, no hit" stays the rule. A feint still drops the red. Sheet 64 keeps a feint from resetting the arms to the bottom.

---

## Sheet 52 — Flinch, reel, and the quad that does not reel

**See.** A light bolt's flinch is a blink after the freeze. A hunchback's reel ends before the stagger lock does, so the last fifth of a punish is a still mannequin. A leaper, a crawler, a mite, and a burrower lock for 1.1 s and tilt about 17° for a fifth of a second.

**Where.** `flinch()` is called with `0.35 + dmg * 0.22` and `HunchRig` decays that at 4.5/s. It does not tick during hit-stop. `_reel` decays at 1.1/s and is gone by about 0.91 s while `STAGGER_TIME` is 1.1 s. `quad_rig.gd` `stagger` only sets `_flinch = 1`, decayed at 4.5/s, gone in about 0.22 s.

**Change.** Decay the hunch flinch at about 2.2/s, and keep at least 0.45 even for a 1-damage bolt. Decay the hunch reel at about 0.75/s so it is still about 0.2 when the chase resumes. On the quad, add a `_reel` that decays at about 0.9/s, drop the belly by about `body_height * 0.35 * _reel`, and splay the legs.

**Prove.** Stagger a wretch and a leaper with the same lance. Both reel for the whole punish. A bolt on a healthy wretch moves the shoulder after the freeze, long enough to read.

**Stay.** Stagger time stays 1.1 s. The punish window is the combat. The pose should fill it.

---

## Sheet 53 — Death that leaves the frame

**See.** A mite dies and is thrown off the screen before the fold. A large body, the Warden especially, shudders by a fixed fraction of a metre that disappears inside its own scale.

**Where.** Death knock is `(6.5 or 3.2) / mass`. A mite at mass 0.35 leaves at about 9 m/s, and the fold only starts in earnest after 0.25 s (sheet 49 asks to wait longer). Hit-stop offset is `0.035 * _hitstop` metres, near 0.21 m on the whole visual. The Warden's scale is 5.

**Change.** Cap horizontal death knock at about 4.5 m/s for mass under 0.6, and keep the upward `velocity.y = 3.2` only when `_last_dmg >= 3`. Scale the shudder by `maxf(rig.scale.x, 1)` and cap it near 0.08 m times that scale.

**Prove.** Kill a mite at your feet. It folds where it died. Hit the Warden. The dais body actually recoils.

**Stay.** Mass still scales knock on ordinary bodies. A husk still steps back. A mite still hops from a heavy lance. It stays in frame.

---

## Sheet 54 — The painted arc and the arc that hits

**See.** The red on the ground is smaller than the hit. You stand where the paint ended and the rake still finds you. A wretch commits from further out than its lunge can close, so it whiffs after a tell you respected.

**Where.** The windup mesh uses `half_angle = strike_arc` and `radius = strike_range + 0.45`. The hit uses `strike_arc + 10°` and `strike_range + 0.5`. A Wretch paints 75° out to 1.90 m and hits 85° out to 1.95 m. Commit happens when distance is within `strike_range + 2.0` (3.45 m for that wretch). The lunge is capped by the room in front, and the hit is 0.06 s later, so they close about 0.3 m and miss.

**Change.** Paint `strike_arc + 10` and `strike_range + 0.5`. Commit at `strike_range + 0.45`, and keep the lunge as velocity until the hit frame from sheet 51.

**Prove.** Stand on the paint's edge. You are hit. Stand one step outside it. You are not. A wretch that starts its tell reaches you.

**Stay.** The extra tenth of a metre and the extra ten degrees are the hit. The paint matches them. It does not grow past them.

---

## Sheet 55 — Pools that grow for the whole night

**See.** A long fight, or a prism staff that splits bolts, slowly allocates. The burst sparks do the same. By the time you reach the summit the pool is larger than the cap you read in the source.

**Where.** `BoltPool` `CAP` 12 only prewarms. `take()` instantiates when `_free` is empty, and `release()` appends with no cap. `explode` waits 0.55 s before release. Prism splits at 0.1 s into two more bolts. A held bolt at 0.28 s with splits needs more than 12 live nodes. `BURST_CAP` and `SHOCK_CAP` are 6, and a burst still emitting (life 0.45 s) causes another particles node to be appended. `release_shared` runs on exit, and the register still records a `ParticlesShaderRD` leak from a process material kept alive. `magic_bolt.gd` builds a new `ParticleProcessMaterial` per burst kind.

**Change.** Refuse to instantiate past 24 live bolts, and if the pool is empty skip the split. Reuse the oldest emitting burst once the cap is full. In `release_shared`, drop the process material before the node, and free the textures it owns. Keep the loading screen from building a second set of the same kinds.

**Prove.** Hold prism bolts for a minute in the meadow, then quit. The log's particle-shader line is gone, and the live bolt count never climbs without bound. `zz/skill_test` still sees the split.

**Stay.** The pool stays on the Zone. Bolts are not spawned by the rig.

---

## Sheet 56 — The leap disc and the place you will be

**See.** A leaper crouches, a disc appears under your feet, and the body lands where you were running. At a sprint that is several metres outside the paint. The disc then lives out its whole tell and finishes as the real jump starts.

**Where.** `LEAP_PREP` drops a 1.5 m disc on the player's current feet for `leap_prep` only. `_pounce` aims at `player + velocity * flight_time * leap_lead`. Leaper prep is 0.5 s, apex 2.1, gravity 16, flight about 1.02 s, lead 0.55. At 7.5 m/s the landing is about 4.2 m outside the disc. The hit test is `reach < 1.7`. Leaving `LEAP_PREP` does not free `_danger`. Only leaving `WINDUP` does.

**Change.** Place the disc on the predicted landing, update it until the last 0.15 s of the crouch, then freeze it, at radius 1.7. Free the feet-disc when entering `AIRBORNE`, once the landing disc exists.

**Prove.** Sprint past a leaping leaper. The disc leads you, locks, and the body comes down on it. Standing still, the disc is under you.

**Stay.** The lead coefficient stays. The disc tells the truth about it.

---

## Sheet 57 — The Thornwarden's slam

**See.** The Warden of the thorns crouches on a small disc, jumps, and the real circle, the one that hurts, appears once it is already in the air.

**Where.** `thornwarden.gd`. Crouch uses `leap_prep` 0.7 s and the base 1.5 m feet-disc. The damaging zone is `SLAM_R` 3.2, or `SLAM_R2` 5.0 in phase 2, gloom 22 or 30, spawned after `launch_at`, for the flight.

**Change.** Spawn the slam zone at the predicted landing when the crouch starts, and extend its life through the flight. Use the same predict-and-freeze as sheet 56.

**Prove.** The Thornwarden pounces. You see the circle you have to leave before the feet leave the ground.

**Stay.** Phase-2 radius 5.0 stays. The tell grows with the fight. It grows on time.

---

## Sheet 58 — Spit, charge, and the lane

**See.** A spitter paints a lane and the orb arrives somewhere else, because you moved and the lane did not. A husk's charge paints a lane and hits in a circle wider than the paint. A dodged slam still kicks the camera if you are merely nearby.

**Where.** `spitter.gd` builds one rect, half-width 0.45, length frozen, while the body keeps yawing. The orb aims at `player + velocity * t * 0.5` with `t = distance / 9`. At a sprint and 12 m the orb is metres off the paint. `husk.gd` charge half-width is 0.85 and the hit is `to.length() < 1.25` around the body. The slam zone is `SLAM_R * scale.x` centred 1.5 m in front, and `kick(0.45)` fires if you are within 6 m. Charge dust is a 4-particle burst every other physics frame, about thirty bursts a second.

**Change.** Each windup frame, rebuild the spit rect along the led point the orb will use, half-width about 0.55. Hit the charge only inside the same rect you painted. Call `kick` on the slam only when the player is inside that disc. Emit one charge puff every 0.08 s.

**Prove.** Strafe a spitter. The lane tracks, then the orb follows it. Dodge a husk charge by standing just outside the paint. You are clear, and the camera is calm. Eat the slam. The camera answers.

**Stay.** Spit speed 9 stays. The lane is what changes.

---

## Sheet 59 — Spit that passes through you

**See.** An orb can step through the body on a hitch. An orb you were invincible inside of, when the roll ends and you are still overlapping it, never wounds and never pops.

**Where.** `spit_orb.gd` steps `global_position += velocity * delta` with no ray. `SPEED` 9, shape radius 0.24. A 30 Hz hitch is about 0.3 m plus your own speed. `_on_body` returns without popping when `is_evading()`, and `body_entered` will not fire again while the shapes overlap.

**Change.** Raycast the segment each frame against world, player, and props, and pop on the hit point. If they were evading, ignore that enter, and on later frames, while still overlapping and no longer evading, apply the wound once.

**Prove.** Roll through an orb and stop inside its radius as the roll ends. It pops and wounds once. A fast sidestep at the edge still pops on the shell, not a metre past it.

**Stay.** Life 3.4 s stays. An orb that misses still dies on its own.

---

## Sheet 60 — The fan, the sigil, and the tithe

**See.** The Warden's fan paints a cone and then fires at where you are now, so a sprint leaves the paint while the centre bolt follows you. A phase-3 double fan is a crowd of full lights. A Chanter's sigil stays dangerous for a second after the pose has gone idle. The Bone Abbot's arms drop before the later spikes of the tithe.

**Where.** `ascended_warden.gd` bakes the cone once: radius 20, half-angle 33°, life `FAN_WINDUP` 0.85. On fire, 7 orbs aim at the player then, spread ±30° in 10° steps. Each orb is a full `SpitOrb` (light 1.3, range 3.2, fog 0.4). Fourteen of those in a second is a lighting spike and a readability spike. `chanter.gd` telegraphs `SIGIL_CAST` 0.5 s, and the disc stays up for `SIGIL_CAST + SIGIL_FALL` (1.5 s) at radius 1.8. The Chanter is in `RECOVER` for the last second. `bone_abbot.gd` telegraphs 0.7 s. Zones land at `0.75 + 0.16 * i`.

**Change.** Rewrite the fan's yaw toward the player each physics frame, freeze it for the last 0.2 s, and fire along that frozen yaw. Give fan orbs light energy 0.35 and no fog, and keep a full light on the centre bolt only. Pass 1.5 s to the Chanter's telegraph and stay in `WINDUP` until the fall ends. Telegraph the Abbot for the full cast, and call `strike()` as each zone lands.

**Prove.** Sprint across the Warden's fan. The cone tracks, locks, and the bolts agree with the lock. The sigil's arms stay up while the disc is live. The Abbot's crozier and the spikes meet.

**Stay.** Seven bolts and the phase-3 double stay. The fight's budget is the lights, not the count. Glow stays at 0.62 / 0.06 / 1.15.

---

## Sheet 61 — The tail, the furrow, and the shroud that blinks

**See.** A leaper's tail hurts, and then the body turns. A burrower's path is a scatter of brown particles, and the disc appears only when it stops. A Chanter's shroud beam is a new arc ten times a second, so it flickers.

**Where.** `leaper.gd` deals the tail from an `AttackKit` zone at `SWEEP_TELL` 0.55 s, radius `2.5 * scale`. The spin runs another 0.3 s, and `strike()` fires when the spin finishes. `burrower.gd` emits 5 particles every 0.09 s at `TUNNEL_SPEED` 7, and the disc (`ERUPT_R` 1.7, tell 0.75 s) appears at the stop. `chanter.gd` builds a fresh `Vfx.arc` every 0.2 s of think time for `CHANNEL` 1.1 s.

**Change.** Start the tail's yaw at 0.25 s into the tell and call `strike()` at 0.55 s, when the zone lands. On each burrow tick, drop a flat decal of radius about 0.45 and life 0.4 s so the path is a line. Keep one shroud arc and move its end for the whole channel.

**Prove.** The tail hits as it passes. The burrow reads as a seam in the ground. The shroud is one beam.

**Stay.** Swarm caps and channel length stay. This is timing and a line, not a new attack.

---

## Sheet 62 — Tells that shake, feet that float, paws that knife

**See.** A hunchback's windup holds and does not tremble, despite the comment that says it trembles. At a full stride the foot is a few centimetres off the ground because the pelvis drop uses the rest leg. A leaper's paw follows the shin and cuts into the floor. A feint drops the arms and raises them again, so the fake and the real swing look like two separate decisions.

**Where.** `hunch_rig.gd` `_tick_poses` holds `_wind` after 55% and adds no shake. `QuadRig` already uses `sin(_t * 40) * 0.06`. Pelvis drop uses `hip_rest` and `knee_rest` while the posed hip adds `±0.42 * stride` on 0.42 m bones. `quad_rig.gd` never rotates the foot joint. `telegraph()` sets `_wind_t = 0` on every call. Wretch `feint_chance` is 0.22 over 0.3 s, then the real windup is 0.42 s.

**Change.** Add `sin(_t * 28) * 0.05 * _wind` on the shoulder while `_wind > 0.85`. Drop the pelvis by the lower of the two solved foot heights each frame. Set `foot.rotation.x` to the negative of hip plus knee so the paw stays flat. If `_wind > 0.6` when a new telegraph starts, set `_wind_t` partway through so a feint that becomes a swing stays reared.

**Prove.** Watch a wretch feint and then swing. The arms stay up and shake. Watch a leaper walk. The paws are flat. Watch a husk at full stride. The down foot meets the ground.

**Stay.** Feint chance stays. The lie is the missing red, not a second windup from the hips.

---

## Sheet 63 — Sleep, packs, and the bodies that hop

**See.** A tell in the air still resolves after the body has been slept by distance. A pack orbits too far out to feel like a fight, two at a time, while the rest circle at a stroll. Mites pop higher than their own bodies. Crawlers hop with no coil. A burrower reads as a large mite until it digs. Crossing 16 m halves a stride in one frame.

**Where.** `sleep()` sets `PROCESS_MODE_DISABLED` and does not call `cancel_moves()`. `AttackKit` timers live on the tree. Sleep range is 46 m, mite 40, boss 80. `MAX_ATTACKERS` is 2, `WAIT_RING` is 2.9 m, strike ranges are 0.85–1.6 m. Orbit is `0.7 * walk_speed`. `launch_at(..., 0.55)` is every crawler's hop. A mite's scale is 0.5 and its bar is at 0.55, hop cooldown 0.75 s. Burrower reuses the crawler rig (`body_height` 0.34, `body_len` 0.72, `stride_len` 0.42) at scale 1.18 with `walk_speed` 3.2, so the cycle is about 2.4 Hz. Full animation rate inside 16 m, every other physics frame until 46 m.

**Change.** `cancel_moves()` and finish the cast inside `sleep()`. Pull `WAIT_RING` in to about 2.15 m and raise the orbit scale from 0.7 to 0.9. Use hop apex 0.28 for mites and 0.55 for crawlers, and set a small squash for 0.08 s, waiting one think (0.1 s) before `launch_at`. Give the burrower `body_len` about 1.05, `body_height` 0.48, `stride_len` 0.75, `hip_spread` 0.22 so a cycle sits nearer 1.4 Hz. Keep full rate out to 28 m.

**Prove.** Walk away from a winding husk. The tell dies with the body. Stand in a camp of five. Two swing, and the others are close enough to matter. A mite's hop is a mite's hop. A burrower on the surface has a longer back.

**Stay.** Two attackers stay. The token is what keeps a pack from being a blender. Sleep ranges stay.

---

## Sheet 64 — The bulwark's shield and the spitter in the light

**See.** A bulwark eats shots from a wide cone while turning slowly, so a step past the shield still plinks. Nothing on the shield flashes, so the angle is a guess. A spitter inside a ward keeps lobbing. Melee leaves the light. The spitter does not.

**Where.** `GUARD_ARC` 0.3 is a dot, about ±72°. `turn_rate` is 3 against the usual 10. `spitter.gd` never reads `_lit_t`. Melee drops aggro after 2.5 s in light and sets `_calm_t` 3.5 s. Inside `fire_range` 15 the spit wish is only slowed by 0.45.

**Change.** Raise the guard dot to about 0.55 (about ±57°) and flash the shield emission for 0.08 s on a block. After `_lit_t > 2.5`, stop new spit windups and kite to the light's edge the way melee does.

**Prove.** Circle a bulwark. Past the shield's edge, bolts land, and a blocked bolt flashes the face of the shield. Drop a ward on a spitter. It stops and leaves.

**Stay.** The slow turn stays. The shield is a facing, not a turret.

---

## Sheet 65 — Nav that mills, and a camp that wakes on the hit

**See.** A husk can mill for a full second on a gate the mesh does not know, then get no path and try the straight line again. A bolt into a camp at the edge of earshot staggers one body, and the others stand asleep until the spawner's half-second tick.

**Where.** `nav_assist.gd`. A stall is less than 30% of expected speed over `STALL_T` 1.0 s. A path that bends under `BEND` 1.5 m is thrown away. Dynamic walls are not in the mesh, by design. `_provoke` alerts idle enemies inside `ALARM_R` 18 m, at most once per second, and does not wake `PROCESS_MODE_DISABLED` sleepers.

**Change.** Drop `STALL_T` to 0.45 s. If the query is discarded while `stalled` is still true, commit to the existing sidestep for 0.6 s. From `_provoke`, call `wake()` on idle allies inside 18 m.

**Prove.** Pull a camp from outside its sleep bubble with one bolt. They stand up on the hit. A husk at a closed briar sidesteps within half a second.

**Stay.** One nav query per 0.5 s stays. The mesh stays a late Realm module. Dynamic walls stay out of it.

---

## Sheet 66 — Heat, the lash, and the third bolt

**See.** After two seconds of fire the bolt slows to a 0.42 s cooldown, and the chain still counts, which is fine. The third bolt, the lash, sounds like the first until it hits.

**Where.** `skill_bolt.gd`. Cooldown 0.28, chain window 0.9, lash every third shot (damage 2.0, blast 3.2, speed 38). `HEAT_AFTER` 2.0 turns the cooldown into 0.42 (`HEAT_SLOW` 1.5) until the trigger is up for `HEAT_COOL` 1.0. Cast sound is `StaffSfx` "bolt" at −3 dB every shot. Lash impact is +1 dB.

**Change.** Play "lash" at −1 dB on the empowered shot so the third bolt is a different attack before it lands.

**Prove.** Count three bolts on an open target. The third cast is the loud one. Wait a second and the chain falls off, as it does now.

**Stay.** Heat stays. A held trigger is a choice.

---

## Sheet 67 — The lance that fires itself

**See.** You hold the lance, it fills, and 0.9 s later it fires on its own. The only "full" is one ring at the muzzle. Pierce starts at charge 0.98, which is almost the same moment as full, and then overcharge is a silent wait.

**Where.** `skill_lance.gd` and `player_casting.gd`. Charge 0.9 s, `OVERCHARGE` 0.9 s, then it fires (1.8 s held). The charge orb's light is `0.6 + 2.2 * c`.

**Change.** Pulse the muzzle ring once more at 0.15 s into overcharge, and hold the orb's light at about 3.4 so the auto-fire is a peak you can see.

**Prove.** Hold the lance toward the meadow. You see full, you see the peak, then it goes. Release at full and it pierces, as now.

**Stay.** The self-fire stays. A held lance is a weapon, not a menu.

---

## Sheet 68 — Nova, well, tether, ward, shade, step, peal

**See.** Nova's damage, shove, and flash are one frame, so the disc and the blow are the same instant. A long tether is a blur and a short one is a jerk. The familiar's darts sit under your own bolts. The ward plants quieter than a bolt impact. The well opens at the same level as nova and then is a single short arc. Rift Step's arrival is quieter than the leave. The Carillon schedules three rings from a loop variable the lambda reads when it fires.

**Where.** Nova cooldown 7, gloom 6, shove 10 falling to half at 6 m, `kick(1.0)`. Tether `t = clamp(distance / 22, 0.22, 0.6)`. A hook just outside 2.3 m takes 0.22 s. A 24 m hook is forced into 0.6 s. Familiar cooldown 22, channel 1.0, life 14, dart every 1.1 s (0.75 at rank I), dart sound −6 dB against a player bolt at −3. Ward cooldown 24, life 7, radius 7, chime −2 dB. Well open and collapse at 0 dB, arc life 0.35. Step untouchable 0.35, body hidden 0.1, range 7.5, cooldown 2.1, departure −6, arrival −2. `skill_peal.gd` `_carillon` loops `for k in 3` and the timer lambda uses `k` for radius and pitch.

**Change.** Show nova's disc, wait 0.05 s, then hit, shove, and kick. Use `clamp(distance / 22, 0.18, 1.15)` so a long haul lasts about a second and stays readable. Play familiar darts at −3 dB and the dive at −1. Play the ward chime at +1 dB and pulse the totem light up to about 2.5 for 0.2 s on plant. Hold a thin column from the hand to the well for the open, at half nova's particle count, and drop the open sound to −2 dB. Raise the step's arrival to 0 dB and play "step_shock" at −2 at the landing. Copy `k` into a local before the Carillon timer connects, the same capture habit this project already uses for nodes that might be gone, so the three rings keep their own radius and pitch. Confirm in the app that the rings already grow; the local is the form that stays correct if they do.

**Prove.** Cast each of the seven once at the practice of a meadow camp. Nova reads, the tether crosses, the shade is audible, the ward chimes above the bolt, the well is a column, the step lands loud, and the Carillon's three rings widen.

**Stay.** Cooldowns and gloom costs stay. Ranks stay behaviour, not a second toolbar of numbers.

---

## Sheet 69 — Two slows, one speed

**See.** Briar cuts a body to 45% for 2.2 s. Anchor pins it for 2.5 s. Whichever timer fires last writes the original speed back and cancels the other. A pinned, briared wretch walks out early, or a briar ends and the pin's restore puts the speed back while the pin should still hold.

**Where.** `magic_bolt.gd` `_briar` and `skill_tether.gd` `_anchor` both store the restore time in meta `briar_until` and the original speed in `briar_base`.

**Change.** Store `anchor_until` and `briar_until` separately, and restore `walk_speed` only when both times have passed.

**Prove.** Briar a wretch and pin it, in both orders. It stays until the later of the two ends, then walks at its own speed once.

**Stay.** The two effects stay stackable. They stop sharing a single slot.

---

## Sheet 70 — Toll, volume, and the voices in a swarm

**See.** The Peal's Toll asks for two staggers and calls `stagger()` twice in one frame, so the second does not add time and the "broken" line and the sound play twice. A mite's tell is as loud as a husk's. Three mites winding together sit on top of your own cast. A boss toll that asks for +4 dB is clamped to the same +3 as a roar.

**Where.** `skill_peal.gd` `_stroke`, `staggers = 2`. `Sfx` voices never set `max_db` (engine default 3). `BossKit.roar` asks +3. The Abbot's chant asks +4. Every kind's tell is about −1 dB, a husk slam at +1. `STACK_S` 0.04 s ducks the third voice 8 dB, which is still louder than a bolt at −3.

**Change.** On a second stagger in the same frame, subtract about 0.6 s from `_state_t` and skip the text and the second sound. Set `max_db = 6` on the voice pool so a toll can sit a decibel above a roar. Scale tell volume with the body's height: mites near −13 dB, husks near −1.

**Prove.** Toll a husk. One "broken," one sound, a longer reel. Walk into three mites. Their tells are small. The Abbot's chant sits above his roar.

**Stay.** Tell pitches stay per family. This sheet is level, not a new voice.

---

## Sheet 71 — What you see in the first ten minutes

**See.** From the hearth, four languages share one view: dense grass cards, a tiled terrain, bevelled block buildings, and clay people. The ground's shadow collapses toward one blue. Edges crawl. Past the pad, grass changes density in patches while you can still read the blades. Toward the wood, a tree swaps models. The Keg's ceiling, once you go in, is a black grid.

**Where.** This is the seam the rendering notes and the r35 critique already name. It is still what the eye meets, because the fixes that landed were the ones with a measured cost: lava vanishing, grass vanishing underfoot, moon acne, white brazier sheets, the grade eating saturated reds. Those stay fixed. The remaining seams are the ones that do not have a single knob.

**Change.** Spend the picture pass on three things, in this order: the Keg ceiling (sheet 78), the grass-chunk step (sheet 74), and the water sheet's flat bounds (sheet 76). Leave the four-language read alone until those three are dull. A new ground shader will not make the clay and the blocks agree, and it is how a look gets rewritten.

**Prove.** Stand at the spawn fire, walk the meadow lane, enter the Keg, and look down the road toward the fen. You can name which of the three seams is gone.

**Stay.** The signed look of the hearth stone and the robe stays. Colour grade, moon, fog, and ambient values stay the lead's. Glow stays locked.

---

## Sheet 72 — The frame you actually have

**See.** At Luke's settings the hub holds the 120 Hz display. Under a stress load it does not hold 90. The last measured cinematic stress pass sat near 83 at the meadow and about 76 inside the tavern, up from a baseline near 65, still short of the 90 the polish plan asked for.

**Where.** `docs/POLISH_PLAN.md` and the later handoff numbers. The expensive slices at the old stress frame were terrain, the player, flora (mostly leaf cards), SSR, the moon shadow, motion blur, and the crowd of point lights. Scripts were already under a millisecond before anyone reaches for a new thread. `docs/EXPANSION_PLAN.md` caps later work at a 3% drop on the spawn, the meadow, and the tavern interior, and at 900 draws and 1.5 million primitives.

**Change.** Judge every picture sheet with `zz/perf_tour.tscn -- --points-only --preset=2 --stress=2 --only=r_spawn_west,r_meadow,r_tavern_in`. A sheet that misses 90 and also drops those three by more than 3% does not land. The path to 90 is fewer leaf-card pixels and fewer lights in the tavern and the meadow, not a higher glow and not a bigger shadow map.

**Prove.** Before and after numbers on those three points, plus a still of the hearth that a person can set beside the previous still.

**Stay.** The retired stair bench in `docs/perf_baseline.md` is not this hub. Do not tune against it.

---

## Sheet 73 — Edges, sharpen, and blur

**See.** With no anti-aliasing, a 3D image capped at 960 rows, FSR sharpness at 2.0, and the grade sharpening again, grass and fences shimmer as soon as you move. Cinematic motion blur at 0.35 then smears everything past about 7 m. Turning AA on stacks a third soften/sharpen and puts the jaggies back in a different shape.

**Where.** `zone.gd` uses FSR when the scale is under 1, `fsr_sharpness = 2.0`. Height cap 960 on a 1080 window is scale 0.889. `grade.gdshader` sharpen is a live knob (the material sits under the default in the shader). `settings.gd` `matching_preset` ignores `aa_mode`, `render_scale`, and `native_output`, so MSAA plus Cinematic still reads as Cinematic. Motion blur's interleaved gradient is fixed to the pixel, so a long smear shows a static diagonal. The blur hides itself when the camera is still, which is correct, and costs about 1.33 ms when it runs.

**Change.** Scale the grade's sharpen down when AA is on, and drop FSR sharpness when AA is on. When `matching_preset()` is −1, show Custom, and do not let a stored preset index overwrite the fields. Offset the blur hash by frame index only while TAA is on. Keep native output behind a confirm that it will miss 120 Hz on a 4K panel. The comment in settings already records 60–70 fps fullscreen on that panel.

**Prove.** Walk the meadow on Cinematic with AA off, then with FXAA. The grass shimmers less with FXAA, and it does not go soft and sharp at once. The preset row says Custom when you have left the defaults.

**Stay.** AA default stays Off. Far depth of field stays off. `dof_enabled` stays forced false.

---

## Sheet 74 — Grass in patches

**See.** Walking the meadow, a patch of grass thins while it is still close enough to read. It is not blades popping under your feet. That bug was the old forest floor, and it stays retired. This is a whole chunk changing density.

**Where.** Undergrowth chunks are 24 m, trees 32 m (`realm_flora.gd`). Cards cull from the chunk centre. Grass end is about 38 m, times 1.12 on Cinematic detail, plus a 6 m fade band in the shader, and ground cards also thin from 16 m down to 60% kept. The near edge of a chunk is about 17 m closer than its centre, so a patch can thin around 20 m in front of you. Big trees swap to `@far` meshes at 38 m from the chunk centre, hysteresis 3 m, fade disabled. Along the axis the nearest trunk can swap around 22 m away.

**Change.** Measure the fade from the camera to the plant, or push the chunk's fade start out so the near edge is still fully dense at 20 m. Crossfade the tree swap over the 3 m hysteresis instead of cutting. Do both behind the existing detail scale so the low preset can stay thinner.

**Prove.** Walk the lane from the hearth to the wood and back. Density falls off with distance, and a single patch does not step. A tree near the path changes mesh without a pop. Stress fps on `r_meadow` stays inside the 3% band.

**Stay.** Do not recenter flora nodes. Do not copy the old 14 m floor margin onto Realm chunks. Do not turn on engine fade-self on the dense grass. That path cost milliseconds.

---

## Sheet 75 — The ground, the moon, and the lights that may shadow

**See.** The valley floor is one mesh the camera is always inside, so it never frustum-culls, and it casts the moon. That is a large, steady cost, and it is also why the night has a ground shadow at all. Small props still try to join that map. The moon's reach is 30 m, so a far tree card in the shadow map is wasted.

**Where.** Terrain is 165 × 173 vertices, a 2 m grid, about 56 thousand triangles (`realm_land.gd`). High shadows: atlas 1024, a hard filter, bias 0.06, normal bias 2.5, 30 m, two splits. Braziers never shadow. The player lantern never shadows. Tiny meshes under 0.45 m are stripped. Far cards named as foliage strips are forced shadow-off. A 2048 atlas, a soft filter, and four splits were measured and rejected.

**Change.** Keep the terrain in the moon map. Extend the tiny-mesh reject and the far-card reject to any prop whose contribution at 30 m is a speck, using the same 0.45 m test on the scaled bounds. Do not raise the atlas.

**Prove.** The hearth ground still has a moon shadow. A crate of pebbles and a distant canopy do not add shadow draws. `r_spawn_west` stress stays inside the band.

**Stay.** Four stair fires, unshadowed. Player lantern, unshadowed. Froxels stay 24×12. SSAO quality stays 0. SSIL stays off.

---

## Sheet 76 — Water, and the lava you already fixed

**See.** Fen pools, from above, read as dark holes. Edge-on, a sheet with no thickness can leave the frustum. At the crypt mouth the lava plane pops, because the hall hides the whole river while you are below the floor line. That pop is a choice. The old "lava vanished at 57 m" bug is not this, and it stays fixed.

**Where.** `FenWater` is one sheet at y = −0.9, shadows off, no grown bounds. Shore fade is 0.25 m of depth. Looking down keeps about 5% of the sky reflection (`sky_floor`), and extra sheen fades in from 70 m to 260 m. `cull_back` on a flat sheet drops it from underneath. Lava has `visibility_range_end = 0`, an 80 m margin, and a custom AABB. Emission 7.4 was left on purpose. `oss_hall.gd` hides the lava node below y = 0 inside the hall, on a 0.3 s tick, so the river does not cut the vault.

**Change.** Give the fen sheet a grown vertical bound, a few metres, so a glance along it stays in frame. Raise the downward sky a little, enough that a pool at your feet has a skin, and keep the far sheen. Leave the hall's lava hide, and if the mouth pop is the thing you hate, fade the plane over the 0.3 s you already tick instead of toggling the node.

**Prove.** Look along a fen pool and down into it. It stays a surface. Walk into the crypt mouth. The river leaves without a one-frame cut, or it leaves as it does now and you have chosen that.

**Stay.** Do not restore the Vale river. Do not "fix" lava by raising bloom. Lava lights stay class `lava`.

---

## Sheet 77 — Fog, particles, and the things that are already cheap

**See.** "Volumetric fog" off still leaves distance fog and height haze, so the night goes flat and the row told you the fog was off. Flames are never thinned, which is correct. Everything else in the air is already on a short budget.

**Where.** `set_fog` disables the volumetric half. Depth fog density 0.0055 and the height haze stay on. Particle keep ratios are already low, with a floor, and flames are skipped by name. The realm pass gives other particles a 48 m range.

**Change.** Name the row so a person knows height fog stays. If a preset is meant to kill the air, say so in the preset, and keep the hearth's own lights as the thing that still blooms inside the locked glow.

**Prove.** Toggle the row at the hearth. The label matches the picture.

**Stay.** Fog volumes stay capped. Gothic shafts stay off while the Realm is on. Do not add a fourth window bay to match the four lanterns. Gothic is three spots, and it is off in the live night.

---

## Sheet 78 — The Keg, inside

**See.** The ceiling is a black void with a faint grid. The hearth light paints the keep and the patrons a flat orange. From inside, the window panes show the night through their leading because they are drawn one-sided. The camera, talking to Hild, can sit under the forge awning, because that roof has no world collider and the camera only collides with world.

**Where.** `tavern.gd` builds at runtime. Three unshadowed omnis, class `fill`, so their energy and range are multiplied. The taproom light sits below the jetty slab. `oss_kit.gd` vertex-AO tints a downward face dark, and wood uses vertex colour as albedo, which is how a ceiling becomes a grid. The forge note is still open in `docs/critique/register.md`: a world collider on the awning, owned with the village dressing.

**Change.** In the tavern interior pass, lift only the underside's shade so the rafters take the hearth. Keep the light count at three. Add the awning collider. Do not rebake `main.tscn`.

**Prove.** Stand at the bar and look up. You see timber. Talk to Hild. The camera is not in the planks. A before/after still of the taproom is the proof, plus the tavern stress point inside the 3% band.

**Stay.** Fill class stays, so the lights still fade at 28 m and do not follow you down the road. No bounced global illumination pass. The orange is the hearth. The ceiling just has to receive it.

---

## Sheet 79 — The screen is a stack of voices

**See.** Gloom, a prompt, a title, a hotbar, objectives, a compass, a minimap, an XP strip, unit frames, combat text, a crosshair, and a debug block share one canvas. The prompt sits on the cast bar. Banners claim a rectangle big enough to cover the compass and the objectives. Encounter lines draw at a different height than the rectangle they reserved, so two headlines share the screen while the director believes the lane is clean.

**Where.** `ui/hud.gd`, `ui/text_director.gd` `lane_rect` (a 1100×300 rect from y = 112), `encounter_hud.gd` banners. The director's discovery rule is one banner per 90 s, and a busy rule while narration or a dialogue is up. Encounter banners, secrets, and world events still draw on their own.

**Change.** Cut the legacy gloom bar once the unit frame is the default. Stop the crosshair while a cast bar or a lesson is up. Move the prompt to one reserved row above the hotbar and let the director own that row. Shrink a banner's claim to the pixels it uses, and pass the real label rect into `begin`. Hide objectives for the whole claim.

**Prove.** Kindle a fire while a lesson is up, while a tide line is up, and while a title card is up. You can read each one, and none of them share a line.

**Stay.** The director stays the owner. Do not add a second toast system. Item level and the XP strip stay, by decision. They sit under the map, not through it (sheet 80).

---

## Sheet 80 — Compass, map, objectives, frames

**See.** The compass redraws every frame, including while it is invisible. The hotbar redraws every frame for a name that faded fourteen seconds ago. The objective block is large enough to cover the compass on a short window. The minimap shares a corner with the XP strip and the toasts. Unit frames, at 1159 lines, draw the plate, the target, the boss, casts, buffs, and the encounter layout, and they move the tide line even when the frames are turned off.

**Where.** `ui/compass.gd`, `ui/hotbar.gd`, `ui/objective_line.gd` (a 596×386 block), `ui/minimap.gd` (a 220 px disc), `ui/xp_bar.gd`, `ui/unit_frames.gd` `_tick_encounter_layout`. Text scale reaches labels built with `scaled()`. Compass, hotbar, frames, the XP bar, the encounter HUD, and the loading screen use fixed sizes, so the text slider lies.

**Change.** Redraw the compass when yaw or the marks change, and the hotbar when cooldown, pulse, or the device changes. Cap the objective at three lines and start it under the compass. Inset the map above the XP strip. Keep toasts to two short lines. Reposition the tide line only while frames are on. Apply `px()` in those draw paths, or hide the text slider until they do. Drop buffs on the plate that repeat the hotbar.

**Prove.** Resize the window and move the text slider. Every combat label follows. Turn frames off. The tide line sits where the gloom label expects it. Open the map corner. The disc, the strip, and a toast do not overlap.

**Stay.** The frames stay one control until a playtest shows the draw is the cost. Splitting the file is a cut of reach, not a new HUD.

---

## Sheet 81 — Loading, and the bar that crawls

**See.** The loading bar lags the real work. Twenty-two stops repeat the village. You cannot skip a tour you have seen.

**Where.** `ui/loading_screen.gd` `VIEWS`. The bar moves at 1.2 per second toward a target, so it trails the phase. Layer 120. One technical hint line.

**Change.** Drive the shown progress from stops completed. Drop repeated headings (spawn, cart, and meadow are three stops on the same materials). After the build phase, one key jumps to the fade (sheet 4). One line of place text per stop is enough.

**Prove.** A cold start and a continue. The bar arrives with the cover. A second launch can be skipped once the world exists.

**Stay.** The cover still waits for the build and the shader warm-up. Skipping does not drop you into an uncompiled meadow.

---

## Sheet 82 — Menus that leave the night alive

**See.** You open a bag and you can still strike. You open a note in the world and walking away is the only close. You open the character sheet over a shop and the night unpauses. Closing a hosted page recaptures the mouse and plays the back sound, and the Kindling celebrates a hearth you did not just light.

**Where.** `ui/loot_window.gd` frees the mouse and does not set `paused`. `encounter_hud.gd` `show_note` is layer 12, ignores the mouse, and does not pause. `ui/character_screen.gd` `close` always clears pause. `growth.gd`, `gear_panel.gd`, `satchel.gd`, and `codex.gd` each clear pause on close. `growth.gd` `close_menu` calls `celebrate()` on the hearth. `character_screen.gd` repairs pause only after the hosted close.

**Change.** Pause the tree for the bag and for the note, remember who paused it, and consume Esc and interact. Store the previous pause the way dialogue already does. If a page is hosted, leave pause and the mouse to the character screen. Skip `celebrate()` and the back sting when hosted.

**Prove.** Open a bag beside a wretch. The wretch waits. Close the character sheet onto a shop. The shop still owns the mouse. Change a Kindling page. The hearth does not cheer.

**Stay.** Dialogue, shop, and settings keep their own pause memory. This sheet makes the others match them.

---

## Sheet 83 — Settings on top of a menu, and keys the page cannot show

**See.** F2 opens Settings on top of the Kindling. Esc during a conversation closes the conversation and does not mean "back up one line." The Controls page shows a dash for RT and LT because a stick axis is not a button it knows how to draw. Grade, render scale, and fullscreen toggles do not mark the input handled, so a rebind on that key fires the game action too.

**Where.** `ui/settings_menu.gd`. Esc is ignored when another menu has paused, and F2 is not. `ui/dialogue.gd` treats `toggle_settings` as close. `InputSetup.REBINDABLE` and `slot_of` return empty for `InputEventJoypadMotion`. `zone.gd` `_unhandled_input` for the view toggles. The old "Controls is read-only" note is stale. Rebinding of keys works and saves.

**Change.** While the tree is paused and Settings is closed, ignore `toggle_settings`. Use Esc for the dialogue only. Label RT, LT, and the sticks as fixed, or accept one axis in the pad column. Call `set_input_as_handled()` on the view toggles. Restore the mouse capture only when no other menu is open.

**Prove.** Open Kindling, press F2. Settings does not stack. Talk to Brannoc, press Esc. You step back in the conversation. The Controls page has no mystery dashes. Bind nothing to the grade key and then press it. Only the grade changes.

**Stay.** `toggle_settings` stays reserved. Mouse-wheel and extra buttons can wait. Axes are the hole that makes the page look unfinished.

---

## Sheet 84 — Presets that lie, quietly

**See.** Cinematic turns on reflections and a heavy blur, and the row does not say so. A file can say "cinematic" and "shadows off" at once, and the stored index wins over the fields. The fog row is sheet 77.

**Where.** `settings.gd` `PRESETS` and `matching_preset`. `load_settings` reads `quality_preset` and `shadow_quality` independently. The r29 critique saw preset 2 with shadows 0 in a real file.

**Change.** Name the row "Cinematic" with the cost in the same line, or keep SSR out of the one-click preset and leave it a toggle. On load, if the fields match no preset, show Custom and keep the fields.

**Prove.** Load a settings file that mixes a preset index with shadows off. The menu says Custom and the night keeps the shadows you saved.

**Stay.** The glow budget is applied in `atmosphere.gd` after presets. A preset cannot raise it. Leave that force in place.

---

## Sheet 85 — Saves that must survive a quit

**See.** The night writes the whole save, copies a backup, and renames, on the main thread, including during a fight. The slot pointer and the HUD layout write in place. A quit in that window can reopen the wrong night, or a HUD that forgot you. A continue from a backup shows the backup's date with no mark.

**Where.** `travel.gd` `_write_save` uses a temp, then `copy_absolute` to `.bak`, then rename. `_slots_cfg` is a direct `ConfigFile.save`. `hud_prefs.gd` `save` is the same. `slot_summary` uses the mtime of whichever file loaded. Atomic temp-plus-rename already exists for `settings.cfg`.

**Change.** Skip the backup copy when a write has already succeeded this session, and if the rename fails leave the previous main file untouched and warn once. Write `slots.cfg` and `hud.cfg` through a temp rename. When the path that loaded is the `.bak`, say so on the title line.

**Prove.** `zz` save tests still round-trip. Kill the process during a save in a scratch home and the next launch loads a complete slot. A backup continue is labelled.

**Stay.** Three slots stay. `-- --fresh` still ignores the save. Erase stays two-step.

---

## Sheet 86 — A new night that remembers the old puzzle

**See.** Erase, or the Deeper Night rebuilding in the same process, and a shrine you had half-played is still half-played. A shop remembers the previous slot's stock. The HUD's "is this a new game" cache survives the rebuild.

**Where.** `SessionState.reset_night` clears the Realm registries, releases caches, and drops the secrets host, the reactivity host, and the spawner hooks. It does not clear `site_wood.gd` `_knelt`, `site_glade.gd` `_seq` and `_mouths`, `site_fen.gd` `lit`, `site_r34.gd` `_lit`, or `site_rim.gd` `_seq`. `village_shop.gd` `_sold` is kept across a rebuild on purpose, keyed by night rather than by slot. `HudPrefs._loaded` is process-lifetime.

**Change.** Clear those site statics in the release `reset_night` already calls. Key the shop's sold list by `Travel.slot`, or clear it in `use_slot`. Reset the HUD cache from `reset_night`. Call `reset_night` from `erase_save` before the title.

**Prove.** `zz/rebuild_test` and a manual erase. A new slot starts with cold shrines, a full shop, and a new-game lesson state. The other slot, loaded again, still has its own progress.

**Stay.** Village state that is the save stays in the save. This sheet is the statics that are not the save.

---

## Sheet 87 — The mix when a menu is open

**See.** Any pause stops the beds, the spots, and the music, so a menu is a hard cut to silence. A click inside the Keg is wet, because the UI shares the SFX bus and the SFX bus grows a reverb indoors.

**Where.** `ambience.gd` uses the inherited process mode. `_make_buses` adds the reverb. `ui/ui_sound.gd` plays on SFX. Kinds today are move, tab, confirm, back, and tick. The title plays confirm. Loot take and the dialogue's existing voice tick have no UI tick.

**Change.** Set ambience to `PROCESS_MODE_ALWAYS` and duck the beds while paused. Add a UI bus next to the buses settings already ensures, and point `UiSound` at it. Play `tick` on the dialogue steps that already exist, and `confirm` on a loot take.

**Prove.** Open settings at the hearth and inside the Keg. The wind continues, quieter. The click is dry in both rooms. A conversation ticks.

**Stay.** Music stays on its own bus. Master, effects, ambience, and music sliders stay. No new audio autoload. World sounds stay on the node that makes them.

---

## Sheet 88 — Footsteps, hooves, and the sound of getting on

**See.** Grass, boards, fen, and stone are one thud at different pitches. A horse's hooves are a shovel. Mounting plays the ward chime, quietly and pitched down, and it is still a spell.

**Where.** `character_rig.gd` `_footstep` has eight stone samples. `SURF_TONE` changes pitch and level per surface (grass, fen, ash, stone, wood, and a slap in water). `horse.gd` `_hooves` plays `VAudio` "dig". `mount` plays `ward_chime.wav` at −14 dB and pitch 0.6.

**Change.** Widen the pitch split per surface on the eight files you have, so boards and grass sit further apart, before anyone records a new library. Play the horse's feet from the step randomizer at a lower pitch, two beats per stride. Mount with a low step, or with nothing.

**Prove.** Walk stone, the Keg floor, and the meadow with your eyes shut. They are not the same note. Ride. The hooves are hooves. Mount. You do not hear a ward.

**Stay.** Eight files stay until a recording pass is a decision of its own. Surface detection stays the ray you already cast.

---

## Sheet 89 — Villagers, and the walk to the door

**See.** A hammer pops between poses because the work cycle is sampled on a 12 Hz tick. In a gloom tide, people vanish into the Keg. The routine already knows the door. The body skips it. A watchman eats a blow every 1.6 s and never flinches.

**Where.** `villager.gd` `_after_step` falls to 12 Hz, then 2 Hz off screen. Work poses are phase snaps inside `_pose`. `npc_life.gd` already blends legs. The tide sends people in for 40–70 s and then hides them. `watch.gd` reuses the villager rig. Assaults are a timer and `take_hit`.

**Change.** Drive hammer, chop, and dig from the blended clock, not only from the pose tick. Play the walk to the door, then hide. Call the rig's existing hurt pose when a watchman's health drops.

**Prove.** Watch a smith through a full swing. Watch a tide. People reach the door. Watch a post take a hit. The body answers.

**Stay.** Pose rate still falls with distance. A smith at the far end of the lane does not get a full-rate skeleton. No new villager system. `villager.gd` stays the routine.

---

## Sheet 90 — Patrons, and the ceiling they sit under

**See.** Dwarves in the taproom pose every frame, which is right, because they are close. An argument and a dice trip still step the whole body on the keg interval. The mug hand should be the part that moves between those steps.

**Where.** `dwarf_npc.gd` `_process` uses `Life.interval_keg`. The blend the villagers use for legs is the tool.

**Change.** Blend the mug hand the way villagers blend legs. Leave the body step for the things that are actually steps.

**Prove.** Sit through a dice game. The cup moves. The dwarf does not quantize.

**Stay.** Close patrons stay full rate. That cost is the price of a readable taproom, and sheet 78 is the picture they sit in.

---

## Sheet 91 — Getting on and getting off

**See.** You mount, and your gait dies the frame you sit. The climb is a linear blend. Jumping off teleports you 1.1 m to the side. Calling the horse puts it on the ground three metres behind you in one frame. The toast is the cue.

**Where.** `player_mount.gd` `ride_tick` animates with a zero velocity while mounted, so the stride stops cold. `ride` moves at 4/s both ways. Jump calls `dismount` and returns on the same frame. `stables.gd` places the horse behind you. The horse itself has a mount timeline (`MOUNT_T`) that already moves the rider from the ground to the seat. Sheet 30 skips foot IK as soon as `ride` exceeds a trace, which is the other half of the sit.

**Change.** Ease `ride` with `exp(-8 * delta)`. On dismount, play that timeline backwards before the teleport, then add a small hop (`velocity.y` about 3) and a short shove back so you leave the barrel instead of appearing beside it. On call, move the horse in over about a second from off the path, and keep the toast.

**Prove.** Mount, ride three lengths, jump off. You climb, you sit, you swing down. Whistle from the lane. The horse arrives.

**Stay.** The horse still will not go where `drive` refuses (sheet 93). The call does not summon it through a wall.

---

## Sheet 92 — The rider and the camera

**See.** The rider's visual yaw follows the horse. The player node, and therefore the camera, do not. A gallop turn leaves you looking off the shoulder at the world beside the road.

**Where.** `horse.gd` `drive` eases `vis.global_rotation.y` toward `_yaw` and sets `p.velocity` along the horse. Look stays on the player. The comment in that function is explicit that the player node turns with the camera, which is why the rider yaw is in world space. That split is correct at a walk and wrong at a gallop.

**Change.** While speed is high, add a small yaw assist on the camera toward the horse's yaw. At a walk, leave the camera free.

**Prove.** Gallop a bend on the west road. You are looking down the road. Walk the same bend. You can look at the ditch.

**Stay.** Mouse look stays available at every speed. The assist is a lead, not a lock.

---

## Sheet 93 — A horse that stops, and a horse that deletes

**See.** A wall, a step, or a drop sets speed to zero in one tick. A breed that tramples, above a gallop, hits every enemy in front for 1.0 damage on every physics frame. A draught horse deletes a pack in a tenth of a second, and shoves them as it goes.

**Where.** `horse.gd` `drive`. A wall ray, a rise above `climb`, or a drop below −6 m assigns `speed = 0`. `_trample` runs when the breed has `trample` and `speed > 6`, and calls `take_hit(1.0, rider)` plus a shove of 9 on every enemy inside `1.6 * scale` in front.

**Change.** Ease speed to 0 over about 0.2 s, and slide along the wall when the ray hits. Damage each enemy from the trample at most once per second.

**Prove.** Ride a draught horse through the meadow camp at a gallop. Bodies fly and live. Ride into the Keg's porch. You scrub to a stop along the wall.

**Stay.** Bosses are already excluded. The trample stays a draught-horse verb. It stops being a blender.

---

## Sheet 94 — The chanter test, and the fight it describes

**See.** `zz/enemy_kin` still fails the chanter: the shroud check wants a packmate, and the slip check wants a landing four metres off. In the night, a shroud skips allies who are still idle, and a slip refuses a lit floor or a ray that misses, then waits 2 s. Sigils also refuse a lit player. The test encodes the fight as if the meadow were dark and the ally were already chasing.

**Where.** `chanter.gd` `_pick_ally`, `_start_slip`, `_think`. `zz/enemy_kin.gd` `_chanter_works`. The register still has this open.

**Change.** Teach the test to stand in the dark with a chasing ally. Keep the fight's rules.

**Prove.** `zz/enemy_kin` passes, and a chanter in a lit ward still will not sigil you (sheet 64 is the spitter's version of the same idea).

**Stay.** Do not weaken the slip or the shroud to satisfy the test.

---

## Sheet 95 — Lines that are too long, and the cuts that pay

**See.** A handful of scripts are past a thousand lines, and the lint will not let them grow by more than fifty. The ones that hurt the night are not long because they are long. They are long because a dead block, a second gloom bar, and a private reach into another HUD are still inside them.

**Where.** The lint in `tools/lint.sh` ratchets `.call`, `has_method`, private gets, and round-tag comments against `tools/lint_baseline.txt`, and holds files over 1,000 lines. The long ones in the playable night include `character_rig.gd`, `enemy.gd`, `growth.gd`, `realm_flora.gd`, `villager.gd`, `unit_frames.gd`, `codex.gd`, `life_director.gd`, `weather.gd`. `settings_menu.gd` still carries a dead `KEY_ROWS` block beside the live bindings page.

**Change.** Delete the dead key block. Cut the legacy gloom bar (sheet 79). Stop unit frames from writing encounter-HUD privates (sheet 80). The next time a villager pose breaks, move only the work poses. Leave `life_director.gd` and `weather.gd` unless a playtest shows a pop. Do not split a file to satisfy a number.

**Prove.** `tools/lint.sh` is clean, and the line counts on those three cuts have gone down. Run `tools/lint.sh --update` only after a count has fallen.

**Stay.** No new `class_name` as a way to make a file feel smaller. Typed preloads stay the seam.

---

## Sheet 96 — Lambdas, leaks, and the quit log

**See.** This project has already been bitten by a lambda that captured a node and fired after the node was gone. The fix, used in the combat pass, is to capture an instance id and resolve it inside the lambda. A few timers are still the old shape. The quit log still mentions a particle shader (sheet 55) and, historically, voices and materials held in statics. Most of those statics now release. The particle one is the survivor to confirm.

**Where.** `docs/critique/register.md` records the capture pattern and the remaining particle line. `SessionState.reset_night` and `Realm.release_caches` are the teardown. `Sfx`, `Synth`, and `StaffSfx` clear on the tree exiting the app, not on a scene change, so a rebuild does not throw away streams it will need a second later. That split is correct.

**Change.** Any new timer that closes over a node takes an id. Any new static that holds a material or a stream gets a `release()` reached from the existing teardown. Confirm the particle line with one windowed quit after sheet 55.

**Prove.** A scratch-home quit log has no "lambda capture" error and no `ParticlesShaderRD` leak.

**Stay.** Do not clear the synth caches on every scene change. The comment in the register explains why.

---

## Sheet 97 — Text that arrives in a pile

**See.** A banner in all capitals is softened. A banner in mixed case, an elite name forced to capitals, and a quest line are not. Two systems still decide their own type size, so the text slider (sheet 80) and the sentence rule disagree.

**Where.** `text_director.gd` `sentence` only rewrites strings that are entirely uppercase. `encounter_hud.gd` `show_elite` uppercases the title. Quest banners pass mixed case.

**Change.** Run the same case rule on elite names and quest banners. One discovery headline at a time, which the director already wants, once their rectangles are honest (sheet 79).

**Prove.** Pull an elite and accept a quest in the same minute. You get one headline, in sentence case, then the other.

**Stay.** Proper names stay as the lore spells them. The rule is about shouting, not about renaming Brannoc.

---

## Sheet 98 — The order for a week

**See.** A hundred sheets is a pile. The night gets better if a week does the ones your hands meet, in an order that does not make you repack five times for one feeling.

**Where.** Bands from the front of this book. The pack is `tools/run_tests.sh`, then the Linux `.pck` into the Downloads app, then `codesign` and `touch`, then you quit and relaunch. Script and shader changes do not need a rebake.

**Change.** Do them in this order.

1. **A, the breaks.** Sheet 82 (bags and notes pause). Sheet 93 (the trample and the wall). Sheet 69 (two slows). Sheet 55 (the pool and the particle leak). Sheet 94 (the chanter test, without changing the fight). Sheet 85 and 86 (save and the cold shrine).
2. **A, the first ten minutes.** Sheet 4 and 5 (the cover, the lessons, the keys). Sheet 79 and 80 (one screen). Sheet 78 (the Keg ceiling and the awning). Sheet 28 (the skating foot).
3. **B, the body.** Sheets 6 through 27, in pairs: walk and jump, slide and roll, the ledge gap, hang and climb, the camera yank, the lock. Prove each pair in the app before the next.
4. **B, the fight.** Sheets 49 through 65, then 66 through 70. Tells before new cast juice. A tell that paints the wrong ground is a lie. A louder nova is a luxury.
5. **C, the picture and the ride.** Sheets 73, 74, 76, then the horse (91–93) and the villagers (89–90) and the mix (87–88).
6. **D, as you touch the file.** Sheets 95 and 96. Do not take a week for them.

**Prove.** Each band ends with the suite green and a pack. You play that pack. The next band starts from what you felt, not from the next sheet number.

**Stay.** If a sheet fails the pillar test (the dark is the clock, warmth is earned, the world teaches, small and finished), drop the sheet. A smoother menu that adds a paragraph of tutorial has failed.

---

## Sheet 99 — What a pack has to survive

**See.** The app you play is a signed Mac bundle loading a Linux pack. A good week that never packs is a week you cannot feel. A pack that rebakes the main scene wipes the MultiMesh bounds and the night comes back empty in the distance.

**Where.** `.cursor/skills/umbral-pack/SKILL.md`. Godot is the Homebrew binary or the app binary. Bundle id `com.umbralreaches.prototype`. Tests run in a scratch home. `godot --check-only` hangs. The owner's Godot editor stays up.

**Change.** Before a pack that follows a generator change (rocks, trees, flora, lore), prune the realm cache and bake it in the scratch home the skill names. Before a pack that is only scripts, shaders, and the player, skip that bake. Always run the suite. Copy the `.pck`, codesign, touch, and say the time.

**Prove.** You quit the app, relaunch, and the sheet you just did is in your hands. Finder may keep the old icon for a moment. The time on the bundle is the proof.

**Stay.** Export preset Linux. Do not rewrite the Mach-O. Do not lipo, strip, or rezip. Do not export preset macOS.

---

## Sheet 100 — How to know the night is finished enough

**See.** The consolidation ends when a person can play the night they already have and believe it. Not when every sheet is ticked. The sheets are a queue. The night is the test.

**Where.** Pillars in `docs/PILLARS.md`. The full night is the default. The slice remains for a first sitting and for tests. Horses, the watch, roaming events, bells, item level, and rested XP stay in that full night, and they stay answerable to the dark.

**Change.** Hold the packed app to this list, and stop adding sheets once it is true.

- You can walk, sprint, jump, slide, roll, and climb the hearth, the porch, and the crypt mouth without a pop in the feet, the capsule, or the camera.
- A tell on the ground is the hit. A kill freezes, folds, and then is gone. A knot is a reward and still leaves a light enemy a moment of its tell.
- The first minute speaks once. A bag pauses the night. A save survives a quit. A new slot is a new slot.
- The Keg has a ceiling. The meadow does not change grass in squares at your feet. A horse stops on a wall and does not erase a camp.
- The glow is still 0.62, 0.06, 1.15. The robe is still the robe. The four fires are still the four fires.
- `tools/run_tests.sh` ends `ALL n PASS` on the pack you are playing.

**Prove.** Play from the title to the first bell, or to the Thornwarden if the bell is further than the evening allows. Write down the one thing that still snags. That note replaces the next ten sheets.

**Stay.** Small and finished beats a night that is wide and half-built. This book is finished when the night is. It is not finished when it is long.

---

# Part II — The night, walked

The sheets are a queue. This part is the same night in the order your hands meet it, from the title to the first boss, with the sheet numbers beside the moment. Read it once with the app open. Mark the sentence that is still true after you have played. That mark is the next pack.

## The title

Three slots, Continue, New Game, Settings, Quit. Continue is the night you left. New Game is a cold hearth. The date on a slot is the file's time, and if that file was the backup it should say so (sheet 85). Erase is two steps, and after it the shrines, the shop, and the lesson flags are cold (sheet 86). Settings from the title is the same menu as F2, with the same buses and the same lie if a preset index and the fields disagree (sheet 84).

A new game and a continue take the same cover. The difference is where you stand when it lifts, and whether a lesson is waiting.

## Under the cover

The build is the Realm: land, rift, bosses, the tavern, lore, the stamp, flora, the summit, the village, life. The bar should arrive with that work, not crawl after it (sheet 81). While the cover is up the tree should be paused, so the wind does not tour the valley ahead of you (sheet 4). One key, after the world exists, may lift the cover. The first launch of a pack still waits for the shaders. A skip that drops you into an uncompiled meadow is a failed skip.

You come out with the mouse captured. The title card speaks. The controls card waits until that card has gone. The first lesson waits until the card has gone (sheet 4). If you are on a pad, the lesson names the pad (sheet 5). If you rebound interact last night, the lesson names the key you rebound.

## Standing at the fire

Hearthward's own fire is the Sanctuary fire. The four stair fires are StairFoot, Shrine, Landing, and Threshold, and they are save keys. You can see the robe, the void face, the staff in the right hand, the lantern. None of that is in this book as a rebuild.

Stand for twenty seconds. The weight should move, the hands regrip, the chest breathe (sheet 33). The gloom bar, if you are in the light, drains. It should move in small steps, not half-point jumps (sheet 47). The compass should sit still while you stand still (sheet 80). The objective, if you have one, is three lines under the compass, not through it.

Look down. The boom should shorten so the steps do not fill the lens (sheet 41). Look up. It already shortens. Strafe. A few degrees of roll is enough to feel the lean and not enough to sicken (sheet 42).

## The first steps

Walk. Below a fast creep the feet should be in a cycle, not a shuffle (sheet 29). A sideways tap from that creep should turn you, not zero you (sheet 6). Sprint. The field of view widens with the speed and does not kink when some other burst falls through it (sheet 42). The hem trails a hard turn and stays quiet on a straight line (sheet 32). The planted foot stays planted between frames (sheet 28). That last one is the foot pop of the whole night. If you fix one animation and leave, fix that.

Stop hard. The robe rocks into the skid (sheet 6). Jump. A tap is short, a hold hangs without a corner, and a hold through a long fall still hops when you land (sheet 7). In the air the walk-to-sprint blend follows the stick you hold now, and a released stick bleeds (sheet 6). The second jump redirects over a short ease, with the tuck you already have (sheet 10).

The porch step is the step-up. The skin lags, the feet stay under the robe (sheet 19), and coming down is one dip (sheet 20). A kerb near half a metre is either a step or a low vault, and a walk that is almost fast enough still vaults a moment later if you kept pushing (sheet 18). The vault's arc is smooth at 120 Hz, the landing dips, and a sprint comes off the far side still near a sprint (sheet 21).

## The door

The Keg door yanks the camera today and then crawls back. It should come back in about a third of a second, and a thin post should not leave you inside the wall (sheet 41). Inside, look up. The ceiling is the black grid. The underside of the jetty needs to take the hearth, and the light count stays three (sheet 78). The click of the menu, once you open it, should be dry. The wind should keep going, quieter (sheet 87). The floor should not be the same thud as the road (sheet 88).

Talk to someone. Esc steps back in the line. F2 does not open Settings on top of the conversation (sheet 83). The forge awning, if you talk to Hild there, needs a world collider so the camera is not in the planks (sheet 78). A patron's mug moves between the body's steps (sheet 90). A smith's hammer is one swing, not a 12 Hz pop (sheet 89).

Open a bag beside the door. The night pauses (sheet 82). Open the character sheet over a shop and close it. The shop still has the mouse. Change a Kindling page. The hearth does not celebrate (sheet 82).

## The lane

Walk toward the meadow. Grass should thin with distance, and a single 24 m patch should not step while you can still read the blades (sheet 74). A tree on the way to the wood should change mesh across a short fade, not a cut (sheet 74). The ground keeps its moon shadow. Pebbles and far cards stay out of that map (sheet 75). Edges: with AA off the grass shimmers; with FXAA it shimmers less and does not get a second sharpen fighting the first (sheet 73). The preset row tells the truth about Custom (sheet 84). The fog row tells the truth about the haze that stays (sheet 77).

This is also where the frame is judged. Stress on the spawn, the meadow, and the tavern interior, cinematic, and a sheet that costs more than about 3% does not land (sheet 72). The glow you are looking at is still 0.62, 0.06, 1.15.

## The first camp

They sleep until you are close, or until a bolt wakes the ones in earshot (sheet 65). Two of them swing. The others orbit close enough to be in the fight (sheet 63). A wretch's red matches the rake, and the rake reaches you if it started from a fair distance (sheet 54). The arm and the damage meet (sheet 51). A feint keeps the arms up and drops the red (sheet 62). The windup, if you hit it, waits with the disc (sheet 51).

A kill freezes, folds, then burns (sheet 49). A mite dies in frame (sheet 53). A leaper's disc is where it will land, and it locks late in the crouch (sheet 56). A spitter's lane is the orb (sheet 58), and the orb cannot step through you or ignore you because you rolled inside it (sheet 59). A husk's charge is the paint, and a dodged slam does not kick the camera (sheet 58). A bulwark's shield has an edge, and the edge flashes when it holds (sheet 64). A chanter in your ward does not draw a sigil on you, and a knot on a chanter fills the strip and leaves the tell a moment (sheets 50 and 64).

Your own bolt leaves the hand you see (sheet 39) and bursts on the body, and the aim ring ends where the bolt ends (sheet 40). The third bolt sounds like the lash before it lands (sheet 66). A held lance shows you the peak before it fires itself (sheet 67). Nova, the long tether, the shade's dart, the ward's chime, the well's column, the step's arrival, and the Carillon's three widening rings are one pass (sheet 68). Briar and a pin both finish (sheet 69).

Roll. The buffer catches an early press, coyote counts, the spin waits for the compress, and the i-frames are one window (sheets 14 and 15). A roll into the porch crouches and then stands when the ceiling allows (sheet 16). A slide crouches with the robe, steers, survives a step, and the first instant can be the perfect dodge (sheets 12 and 13). Empty the breath and the last roll stumbles (sheet 11).

## The dark between fires

Leave the light. The bar moves and the robe cools (sheet 47). Sprint in the dark costs more, as it does now. At the top of the bar the shade arrives as a blow, not only a toast (sheet 48). If you hollow, you hold still and then you are at the last fire. A fall's dust, slow, roll, and wound are one ladder of height (sheet 9). Lava still hollows on contact. That is the clock. The rates stay.

The four fires are the climb. Kindling one is warmth you earned. The prompt sits above the hotbar, in the director's row, and it keeps the brazier you are facing until another is clearly nearer (sheet 79, and the interaction hysteresis in the player notes). A lesson never covers that prompt.

## A wall, a beam, a rope

The crypt mouth and the tavern wall are the traversal test. A jump near the ground off a wall is a kick, and the foot is on the stone when you leave (sheet 25). A catch ramps the hands in, remembers a jump pressed during the catch, and a let-go falls (sheet 23). The pull-up leaves you on the crown (sheet 24). A mantle from a sprint stays a sprint, and the camera rises with you (sheet 22). A beam springs you to the middle (sheet 26). A grapple line is drawn on the rendered frame and the arrival does not reverse (sheet 27). Out of jumps, high enough, the glide eases in. Off a kerb, it refuses and tells you (sheet 17). A steep face eases into the slide and does not drop you for one missed frame (sheet 8).

## The horse

Whistle. It comes in along the path (sheet 91). Mount. You climb, the feet leave the ground IK at once (sheet 30), and the sound is a step or silence (sheet 88). Gallop a bend and the camera leads down the road. Walk the same bend and you can look at the ditch (sheet 92). A wall scrubs you to a stop. A draught horse through a camp hits each body about once a second (sheet 93). Jump off. You swing down.

Hooves are the step randomizer, two beats a stride, lower than your own feet (sheet 88).

## Water and the crypt

Look along a fen pool and down into it. It stays a surface, with a skin, and the far sheen can stay the far sheen (sheet 76). At the crypt mouth the lava leaves. If it pops, fade it over the tick the hall already uses. The old vanish-at-a-distance bug stays fixed, and the emission on the river stays.

Inside, a tell that was in the air when you walked out of range dies with the sleeper (sheet 63). Bone props fade with distance as they do now. The hall is not moonlit, on purpose.

## The Thornwarden

The crouch paints the slam you have to leave, before the feet leave the ground (sheet 57). Phase two is the larger circle, on the same timing. The kill is the freeze and the fold (sheet 49). The shudder is visible on a body that size (sheet 53).

If the evening ends at the Warden instead, the fan tracks and locks, the side bolts are small lights, and the centre bolt keeps a full one (sheet 60). The toll sits a little above the roar (sheet 70).

## Back at the fire

Quit. Launch. The slot is the night you left, on solid ground, and a mid-write quit did not point you at the other slot (sheet 85). A Deeper Night rebuild in the same process is a cold shrine where the shrine was cold, and your other slot still has its own stock (sheet 86).

The quit log, once, in a scratch home: no lambda-capture line, no particle-shader leak (sheets 55 and 96).

## What you pack

Suite green. Linux pack into the Downloads app. Codesign, touch, the time (sheet 99). You quit and relaunch. The sheet you did is in your hands. The robe is the robe. The four fires are the four fires. The glow is the glow.

Then one sentence, written down, of the thing that still snags (sheet 100). That sentence is the next sheet. The other ninety-nine can wait.

---

# Part III — Index by file

Use this when you are already in a file. The sheet is the work. The line numbers in the sheets are the morning of 6 November 2026 and will drift. Trust the function name.

### `core/player/player.gd`

Walk, sprint, air drag, run blend: sheet 6. Apex, fall, jump cut, buffer: sheet 7. Slopes' home is the locomotion file; the exports live here. Landing thresholds: sheet 9. Slide numbers and slide-hop: sheets 12 and 13. Roll numbers: sheet 14. Glide sink: sheet 17. Step, vault, mantle, grab bands: sheets 18 and 22. Camera offsets and shoulder: sheets 41, 43, 45. Stick curve: sheet 46. Gloom rates: sheet 47. Shade and hollow: sheet 48. Facing snap: sheet 34.

### `core/player/player_locomotion.gd`

Ground move and skid: sheet 6. Slope scale: sheet 8. Land: sheet 9. Air jump: sheet 10. Slide tick, capsule, air time: sheets 12 and 13. Step-up and step-down: sheets 19 and 20. Steep: sheet 8. Beam correction's consumer is the player tick; the probe is traversal.

### `core/player/player_evasion.gd`

Roll window, buffer, coyote, i-frame stamp, crawl: sheets 14, 15, 16. Glide entry: sheet 17. Shadow-step fade belongs with the step reveal already in this file; the sheet that names the pop is 17's neighbour in the evasion notes, and the arrival sound is sheet 68.

### `core/player/player_traversal.gd`

Vault curve and exit: sheet 21. Mantle probe, ease, camera: sheet 22. Hang, shimmy, let-go: sheet 23. Climb exit: sheet 24. Wall kick against coyote: sheet 25. Beam spring: sheet 26.

### `core/player/player_camera.gd`

Arm pull-in and pitch: sheet 41. Field of view add, strafe roll, hurt dip: sheet 42. Lead: sheet 43. Shoulder rays: sheet 45.

### `core/player/player_targeting.gd`

Lock pitch, pivot, mouse break, stick swap: sheet 44.

### `core/player/player_vitals.gd`

Perfect dodge, gloom emit, shade, hollow, wound kick, fall ladder: sheets 13, 47, 48, 42, 9.

### `core/player/player_casting.gd` and `core/player/magic_bolt.gd`

Drawn muzzle, ribbon history: sheet 39. Proximity radius and aim ring: sheet 40. Pool growth and burst reuse: sheet 55. Briar meta: sheet 69.

### `core/player/player_mount.gd` and `core/player/stamina.gd`

Mount blend and dismount hop: sheets 30 and 91. Winded stumble: sheet 11.

### `core/player/character_rig.gd`

Foot IK between ticks, cycle gates, landing feet, plant weight: sheets 28, 29, 30. Slide tuck: sheet 31. Cloth and hood: sheet 32. Idle and breath: sheet 33. Cast restart: sheet 34. Hang, mantle, wall-kick poses: sheet 36. Air and glide hips: sheet 37. Footstep pitch: sheet 88.

### `core/player/staff_arts.gd` and `core/player/grapple.gd`

Lunge ramp and parry open: sheet 38. Line and arrival: sheet 27.

### `core/skills/`

Bolt lash: sheet 66. Lance peak: sheet 67. Nova, tether, familiar, ward, well, step, peal: sheet 68. Anchor meta: sheet 69. Toll's second stagger: sheet 70.

### `core/enemy/enemy.gd`

Kill freeze, strike time, hit-stop versus the disc, paint versus hit, commit range: sheets 49, 51, 54. Flinch and reel: sheet 52. Death knock and shudder: sheet 53. Weak point: sheet 50. Sleep cancels: sheet 63. Provoke wakes: sheet 65. Tell level: sheet 70.

### `core/enemy/hunch_rig.gd` and `core/enemy/quad_rig.gd`

Reel, tremble, pelvis, paw, feint: sheets 52 and 62.

### Kind files

`thornwarden.gd` sheet 57. `spitter.gd` and `husk.gd` sheet 58. `spit_orb.gd` sheet 59. `ascended_warden.gd`, `chanter.gd`, `bone_abbot.gd` sheet 60. `leaper.gd`, `burrower.gd` sheet 61. `mite.gd`, `crawler.gd` sheet 63. `bulwark.gd` sheet 64. `nav_assist.gd` sheet 65.

### `core/world/atmosphere.gd`, `light_policy.gd`, flora, land, water, lava

Glow force: sheet 2 and 75. Fog row's partner: sheet 77. Grass chunks: sheet 74. Moon and tiny casters: sheet 75. Fen sheet: sheet 76. Lava stays as it was fixed.

### `core/world/tavern.gd` and the forge dressing

Ceiling shade and the three fills: sheet 78. Awning collider with the village dressing.

### `core/world/ambience.gd`, `core/vfx/sfx.gd`, `ui/ui_sound.gd`

Pause duck and UI bus: sheet 87. `max_db`: sheet 70.

### `core/world/mount/horse.gd`, `horse_db.gd`, and `stables.gd`

Call, mount sound, hooves, yaw, wall, trample: sheets 88, 91, 92, 93. The prompt that stays "Ride", because the scan never runs while mounted: sheet 101. Space dismounts and the horse never hops: sheet 102. The four breeds: sheet 103. Buy, call, boss: sheet 104.

### `core/world/watch/watch.gd` and `watch_posts.gd`

The timer fight, the chop with no attacker, the first assault: sheet 105. Pay and the lantern that is not a fire: sheet 106.

### `core/life/village/village_cast.gd` and `village_props.gd`

The seven camps and their mirror fires: sheet 107.

### `core/world/roam/roam_events.gd` and `core/world/night/reach_state.gd`

Procession, incursion, tear, pilgrim: sheet 108. Acts, quiet bells, factions: sheet 109.

### `core/life/encounters/director.gd` and `bounty_post.gd`

Tide, ambush, the board: sheet 110.

### `core/life/progression/hearth.gd`, `level.gd`, `core/items/gear_db.gd`

The two rests: sheet 111. The ledger: sheet 112.

### `core/life/secrets/director.gd` and `core/life/wildlife/`

Hum, banner, an elite that rises twice: sheet 113. Herds and the hart: sheet 114. Weather: sheet 128.

### The rest of the night

Mounted staff: sheet 116. A lit fire you cannot rest at: sheet 117. Relics: sheet 118. The ward and the four bells: sheet 119. Boss rooms: sheet 120. The two raids: sheet 121. The lift, including on a horse: sheet 122. The shade: sheet 123. Kindling, cores, charms: sheet 124. The keep's conversation: sheet 125. Marks and the two maps: sheet 126. Gathering: sheet 127. The Deeper Night: sheet 129. The crossing: sheet 130.

### Still only named, until Part VIII

Two roads between fires, and a horse that snaps back: sheet 132. Hollow, the ash mound, the fall: sheet 133. The seven bells and the latch: sheet 134. Tasks: sheet 135. Meals and the gloom bar: sheet 136. The Hearthfire: sheet 137. Chests and bags: sheet 138. Secret places: sheet 139. The ossuary walked: sheet 140. Guardians: sheet 141. The named hunts: sheet 142. The tollman: sheet 143. Lamps that look like rest: sheet 144. Place names and the surge: sheet 145. The one book: sheet 146. The coal: sheet 147.

### Part IX

The lantern that is not a light: sheet 148. Wounds: sheet 149. Remembrance and the Paths: sheet 150. Oaths: sheet 151. Raise, reforge, salvage: sheet 152. The four teachings: sheet 153. Camps: sheet 154. Writings: sheet 155. Hearthward's lamps and roofs: sheet 156. Beds, phrases, and the boss themes: sheet 157. Variants: sheet 158. The henge stair and the summit deck: sheet 159. Tether rings: sheet 160. Water underfoot: sheet 161. Resonance: sheet 162.

### Part X — the same picture, less cost

The summit is a hundred unique copies of two rocks: sheet 163. The two pillars are the same file twice: sheet 164. A boss is one body drawn as many surfaces: sheet 165. Grunt maps are already capped: sheet 166. Roughness and occlusion that stay in RAM: sheet 167. Tavern and cloth maps with no mip chain: sheet 168. Files the night never loads: sheet 169. What must not be "improved": sheet 170.

### Part XI — the walks still unnamed, and the draws that repeat

A rare's pin and the ring it will not enter: sheet 171. What a merchant pays: sheet 172. Graves in the Waiting Field: sheet 173. The dart and the rib: sheet 174. The Abbot's three caskets: sheet 175. The disc that redraws every frame: sheet 176. Health bars with no end: sheet 177. Blooms that keep emitting across the valley: sheet 178.

### Part XII — someone walks with you, and a picture that will not stop

Oswin and the last half-metre: sheet 179. A daily and the machine's midnight: sheet 180. Father Harrow: sheet 181. Marks on the bar: sheet 182. Numbers through the hill: sheet 183. The breath arc while it is hidden: sheet 184. The sky that waits, and does not say so: sheet 185.

### Part XIII — a save, a hymn, a floor, a still widget

The ash a quit erases: sheet 186. The choir that sings him whole: sheet 187. The stone that is already gone: sheet 188. The henge's knots and the plate: sheet 189. An empty canvas: sheet 190. The strip along the bottom: sheet 191.

### Part XIV — sentences, rites, and numbers that keep going

What the valley actually keeps: sheet 192. A count with no ground, and a task already finished: sheet 193. The Tolling's glow: sheet 194. The Reckoning's plate: sheet 195. Rain and Requiem: sheet 196. Sheltered, over and over: sheet 197. The song on the Warden: sheet 198. The sac, and the kin: sheet 199. The crypt's extra lamp: sheet 200. A burn's numbers, and the ice: sheet 201. A still plate, and fog on the road lamps: sheet 202.

### Part XV — the plate, the door, and the size of a ring

Blows land on the wound plate: sheet 203. Seven tongues and the first phase: sheet 204. The rung bell's pool: sheet 205. The toll's earshot: sheet 206. The peal's ball of light: sheet 207. The burrower's disc, and the mite at the edge: sheet 208.

### Part XVI — the circle, the camp, and the heap

The fire's glow and its sanctuary: sheet 209. A camp that closes the plate: sheet 210. Three lights past their own rings: sheet 211. The bones that will rise: sheet 212.

### Part XVII — a step past the red

The rake and its wedge: sheet 213. A quarter metre past the paint: sheet 214. The gaunt's circle: sheet 215. The shade's disc, and the dart behind you: sheet 216.

### Part XVIII — the line, the ring, and the word

The step's corridor: sheet 217. The finisher's circle: sheet 218. A heavy drawn too soon: sheet 219. The word blocked: sheet 220.

### Part XIX — the bolt, the riposte, and the kill

A lock that takes the bolt: sheet 221. A riposte spent on the backswing: sheet 222. The surge's ring: sheet 223. A kill that mends in silence: sheet 224.

### Part XX — the channel, the window, and the pips

A nick, and a guard, take the channel: sheet 225. The lighter blow is the one that counts: sheet 226. Marks go out all at once: sheet 227. A stack closes the plate in silence: sheet 228.

### Part XXI — the ring, the breath, and the scar

The nova's tenth: sheet 229. Breath back, still winded: sheet 230. The fall's lesson: sheet 231. A scar that counts in tenths: sheet 232.

### Part XXII — the air, the chain, and the tenth

A heavy drawn in the air: sheet 233. The tether and the lock: sheet 234. The plate's fraction: sheet 235. A lash on a boss: sheet 236.

### Part XXIII — whether the night is one night

Two doors at once: sheet 237. The bell before the keg: sheet 238. Continue is a rest: sheet 239. The sky under the last sentence: sheet 240.

### Part XXIV — the door, the lamp, the oath, the slot

A peal the corner never names: sheet 241. The lamp the shade does not fear: sheet 242. A ward called a mend: sheet 243. The gate counted twice: sheet 244.

### Part XXV — the bar, the bag, the toast, the great one

A Strike bar on a feint: sheet 245. The bag a quit leaves: sheet 246. Seven and a half: sheet 247. A great one left standing: sheet 248.

### Part XXVI — the roll, the wall, the tip, the word

Hits that skip the roll: sheet 249. A prompt through the wall: sheet 250. The night the tip says carries on: sheet 251. A wound called gloom: sheet 252.

### Part XXVII — the number, the row, the scar, the root

The frame's whole number: sheet 253. A row named Waygates: sheet 254. A scar lit past its burn: sheet 255. A root that lasts a moment: sheet 256.

### Part XXVIII — the picture on the body

The shade's lantern: sheet 257. The statue's white orb: sheet 258. Motes past the candle: sheet 259. Flames with no wax: sheet 260. Masks still in RAM: sheet 261. A horse with no ground: sheet 262.

### Part XXIX — the lights that walk with you

The glass in the hand: sheet 263. The hall past its wall: sheet 264. Eyes at six: sheet 265. Four bowls on one altar: sheet 266.

### Part XXX — the circle, the chance, the card

Two circles round one green: sheet 267. A gleaner paid in chances: sheet 268. A kill the plate ignores past 28 m: sheet 269. A step that slows: sheet 270. Two seconds off the card: sheet 271. The table the night does not pay: sheet 272. A lance called four: sheet 273. The number line: sheet 274. The ember's Now: sheet 275. The spring's crest: sheet 276. The rift's discount: sheet 277. A frozen foe and the well: sheet 278.

### Part XXXI — sentences that already agree

Read against the live Kindling on 6 November. Leave them. The next free sheet is 291.

### Part XXXII — the card, the leap, the tell

The Hearthfire's two lines: sheet 279. The lodestar's second leap: sheet 280. What breaks a red tell: sheet 281. The bulwark's boards: sheet 282. The Kindling foot: sheet 283. One word for two songs: sheet 284. The brood the body cannot spoil: sheet 285. A patch that keeps its Dusk number: sheet 286.

### Part XXXIII — the bodies at Dusk

The camp bodies before a tier and before a variant. A sheet named beside a picture already owns it.

### Part XXXIV — the same body, seven times

Life, wound, and walk on every row. The teeth. The variants the rows draw. The country each body starts in. The second blow that shares a row's wound.

### Part XXXV — the named ones

The guardian half-rate. The next free sheet is 291.

### Part XXXVI — the letter, the hatch, the kin

Twenty measures: sheet 287. The mites she hatches: sheet 288. The count's two crawlers: sheet 289. The kin called at half: sheet 290.

### Part XXXVII — the six hunts, on every row

Life, the blow, and the Deeper Night form. The letter in Part XXXVI is the change. The rest of the notice already matches the move.

### Part XXXVIII — eighteen names, on every row

The half-rate again, with the rare's own 1.2 on the rake, and the variant added after. Spawn passes the umbral flag false, so the 1.6 and the 1.06 stay with the hunts.

### Part XXXIX — every line the forge can print

The base, the item level, the cost, and both ends of every affix, at every legal level. Sheet 268 still owns the gleaner's wording.

### Part XL — the tasks as they stand

Each task, each step, the count it asks, and the pay. A number that already matches its condition stays a number.

### Part XLI — the camps as planted

Where the file puts a pack, and which kinds it names. The row they wear is Part XXXIV, once `region_at` has spoken.

### `core/life/village/villager.gd`, `core/npc/dwarf_npc.gd`, `core/world/watch/watch.gd`

Work cycles, the door, the mug, the flinch: sheets 89 and 90.

### `ui/hud.gd`, `ui/text_director.gd`, `ui/unit_frames.gd`, and the corner widgets

One voice on the screen: sheets 79, 80, 97. Lessons and keys: sheets 4 and 5. The plate that redraws while it is still: sheet 202.

### `ui/loading_screen.gd`, `ui/loot_window.gd`, `ui/settings_menu.gd`, `ui/dialogue.gd`, `ui/growth.gd`, `ui/character_screen.gd`

Cover and bar: sheets 4 and 81. Pause ownership: sheet 82. Settings stack, Esc, axes, presets: sheets 83 and 84. The conversation itself: sheet 125. Kindling, cores, charms: sheet 124. Dead `KEY_ROWS`: sheet 95.

### `autoload/travel.gd`, `autoload/settings.gd`, `core/world/session_state.gd`

Atomic slots and the backup label: sheet 85. Cold statics, shop stock, erase: sheet 86. Preset match: sheet 84.

### `zz/enemy_kin.gd`

The chanter section: sheet 94. Change the test's setup. Leave the fight.

### `tools/run_tests.sh`, `tools/lint.sh`, `.cursor/skills/umbral-pack/SKILL.md`

The gate and the pack: sheets 95 and 99.

---

# Part IV — Numbers worth keeping in your head

These are the values the sheets keep, because other systems assume them.

| What | Value | Why it stays |
| --- | --- | --- |
| Walk / sprint | 4.5 / 7.5 | Vault, slide, and enemy lead are tuned to them |
| Jump / air jump / gravity | 5.2 / 5.8 / 16 | The hang changes shape, not height |
| Gloom, dark / rift / lit | 3.0 / 5.0 / 12 per second | The dark is the clock |
| Kill drain | 6 within 28 m | Warmth from a blow you earned |
| Glow | 0.62, bloom 0.06, threshold 1.15, levels 0 and 1 | Binding |
| Internal height | 960 (810 only on the lowest detail) | Binding |
| Camera far | 82 m | The valley's draw |
| Moon shadow | 1024, 30 m, two splits, bias 0.06, normal bias 2.5 | Measured; larger maps were rejected |
| Stair fires | StairFoot, Shrine, Landing, Threshold | Save keys |
| Bolt cooldown | 0.28 s, heat 0.42 after 2 s | The weapon's rhythm |
| Attackers in a pack | 2 | The fight stays readable |
| Slots | 3, plus a backup beside each | The night you left |
| Autoloads | Events, Settings, Travel, LightGrid, InputSetup | The architecture |

These are the values the sheets move, because two systems already disagree.

| Gap | Today | After |
| --- | --- | --- |
| Step-up vs vault | 0.45 then 0.50 | Overlap at 0.42 |
| Coyote vs wall kick | Kick suppressed while coyote is live (0.13 s) | Kick tested first; wall memory 0.28 s |
| Slide steer vs slide length | 1.4 rad/s inside a slide under a second | About 3.2 rad/s, friction about 2.8 on the flat |
| Hit shake vs land dip | About 1° vs about 7° | A wound dips and shudders; the landing stays the bigger dip |
| Arm ease out vs pull in | `exp(-3.2)` vs `exp(-28)` | Ease out nearer `exp(-8)` |
| Painted arc vs hit arc | Paint is the base arc and range | Paint includes the +10° and the +0.5 m the hit already uses |
| Leap disc vs landing | Disc under the feet, radius 1.5 | Disc on the predicted landing, radius of the hit |
| Trample | 1.0 damage every physics frame above speed 6 | Once per enemy per second |
| Bolt pool | Cap 12 prewarmed, then unbounded | Refuse past 24, and skip a split the pool cannot hold |

---

# Part V — A week, written as mornings

Five mornings. Each one ends in the suite and, if the suite is green, a pack you actually launch. Leave the owner's Godot editor alone. Tests use a scratch home.

**Morning 1. Breaks.** Bags and notes pause the tree (82). The horse stops on a wall and tramples once a second (93). While you are on it, the prompt still says Ride and Space gets you off instead of hopping (101, 102). Briar and anchor keep their own clocks (69). The bolt pool stops growing and the particle material is released (55). The chanter test stands in the dark (94). The save and the cold shrine (85, 86). Play for ten minutes with a bag, a horse, and a quit.

**Morning 2. The first minute and the foot.** The cover pauses the world, the lessons wait, the keys are true (4, 5). One row for the prompt, banners that claim only their own pixels (79, 80). The Keg ceiling and the awning (78). The planted foot solved between ticks (28). Walk the hearth, enter the Keg, sprint the lane. Write the sentence that still snags.

**Morning 3. The body.** Walk and jump (6, 7). Slide and roll (12, 13, 14, 15). The kerb (18, 19, 20). Hang and climb (22, 23, 24). The camera (41, 42, 43, 44). One pair, then the app, then the next pair. `zz/move_course` at the end.

**Morning 4. The fight.** Kill freeze and the fold (49). Paint and commit (54). Leaps, spit, charge (56, 57, 58, 59). The fan, the sigil, the tithe (60). Flinch and reel (52). Then the casts (66, 67, 68). A camp at the meadow is the test, then the Thornwarden if the morning is still yours. `zz/combat_duel` and `zz/skill_test`.

**Morning 5. Picture and ride, only what the stress numbers allow.** Sharpen against AA (73). Grass distance (74). The fen sheet (76). Mount, camera lead, hooves (91, 92, 88). Villagers to the door (89). Measure `r_spawn_west`, `r_meadow`, `r_tavern_in` before and after. Anything past about 3% comes back out.

Mornings after that are sheet 100. One snag, one pack. The lint and the lambdas (95, 96) happen when you are already in the file.

---

The night you packed this morning already has the pillars, the save, the tells, the robe, and the four fires. These sheets are the places where two of those systems still disagree by a tenth of a second, a tenth of a metre, or a single frame. Close the gap. Leave the night.

---

# Part VI — The roads

The first hundred sheets read the wanderer, the blows, and Hearthward. This part is what that reading skipped, taken from the same source: the ride, the four breeds, the Kindled Watch, the seven camps, the events that start themselves, the factions, the tide, the two rests, the gear ledger, the secrets, and the herds. Same shape as a sheet. Same rule: no new system.

## Sheet 101 — The prompt still says Ride

**See.** You are on the horse. The bottom of the screen still says press E to ride it. You are already riding it.

**Where.** `horse.gd` `interact_text` does know the difference. If `rider` is set it returns "[E] Get down". If the breed is owned and nobody is up, it returns "[E] Ride the …". The bug is that the second string is the last one the HUD ever received. `player.gd` calls `mount.ride_tick` and, when that returns true, returns out of `_physics_process` before `interaction._scan_interactables()`. The scan is the only thing that emits `Events.interact_hint`. Mount sets `rider` and `p.riding` in the same call, so the very next tick is already on the early return. The hint stays on the sentence from the frame before you swung up, for the whole climb (`MOUNT_T` 1.15 s) and the whole ride. E is not on that early return. `_unhandled_input` still calls `_try_interact` on the stale target, which is the horse, and `interact()` sees `rider` and dismounts. The label says Ride. The key gets you off.

**Change.** Run the interact scan while mounted. While `rider` is the player, `can_interact()` on that horse returns false, so a brazier or a person in reach can win the prompt. The horse is always within its own 2.6 m, because you are sitting on its origin. If it stays eligible it will beat every fire you ride up to. When the scan finds nothing else, `ride_tick` sets the hint itself to "[E] Get down". Clearing the hint to empty and leaving E dead is the wrong fix. You still have to be able to get off.

**Prove.** Buy or call the palfrey, press E, and look at the prompt before the swing finishes. It says Get down. Ride up to a cold stair fire. The prompt says Kindle. Ride back into the empty lane. It says Get down. Press E there. You are on the ground. Press E on the fire. It kindles, and you are still in the saddle until you choose to get off.

**Stay.** The buy line stays "[E] Buy the … (n grave ash)" until you own it. The first press that spends the ash still does not mount you. That second press is the ride. Sheets 102 and 103.

---

## Sheet 102 — The horse does not jump

**See.** Space on foot is a jump. Space on the horse puts you on the ground beside it. There is no hop. A lip the breed will not climb is a full stop, and the key you reach for is the key that unsaddles you.

**Where.** `player.gd` says "jump gets down". `PlayerMount.ride_tick` does it: `Input.is_action_just_pressed("jump")` calls `dismount()` and returns false, before `drive()`. `dismount()` teleports you 1.1 m to the side. `drive()` never reads jump. It sticks the horse to a ground ray every tick (`lerpf` of y toward the hit, `exp(-14)`), and a rise above the breed's `climb` sets `speed = 0` in one frame (sheet 93). The gait phase is written from speed. A hop that only sets `velocity.y` on the player will be erased, because the next line of `drive()` writes `p.global_position` to the seat.

**Change.** After `MOUNT_T` (1.15 s), Space starts a hop on the horse and does not dismount. About 0.45 s, peak near 1.1 m, the same for every breed so the verb is one verb. During it, skip the ground glue and the climb-stop, keep the gait phase running, and add the hop to the seat height `drive()` already computes. Landing plays the existing step, quiet. Get down stays E, which sheet 101 has finally labelled. During the swing into the saddle, ignore Space. Cancelling the mount on frame two is a different accident.

**Prove.** Gallop the west road and press Space at a low bank. The horse leaves the ground and comes down still under you. Press E. Then you are off. Press Space in the first second of mounting. You stay in the swing.

**Stay.** A boss still pulls you off, with the toast it already has. A hop is not a second climb stat. Garron still walks a taller step. Palfrey still does not. Sheet 103.

---

## Sheet 103 — Four horses, one sentence

**See.** The stables sell four animals and the ride treats them as one. You learn the difference by hitting a wall, or by walking into the mere and sinking.

**Where.** `horse_db.gd`.

| Breed | Where | Ash | Walk / trot / gallop | Turn | Climb | Extra |
| --- | --- | --- | --- | --- | --- | --- |
| Pilgrim's Palfrey | Hearthward's yard, (22, 46) | 40 | 2.6 / 6.5 / 11 | 2.6 | 0.75 | the fast one |
| Moor Garron | Ysolt's fire under the tor, (128, −6) | 60 | 2.4 / 6.0 / 9.5 | 2.9 | 1.05 | the one that steps up |
| Fen Pony | Cadoc's bank, (104, 90) | 50 | 2.4 / 6.2 / 10 | 3.1 | 0.8 | `wade`: the mere does not drop it to a walk |
| Pit Draught | the Founder's Pits, (112, −66) | 80 | 2.2 / 5.5 / 9 | 1.9 | 0.9 | the only `trample` |

`drive()` slows to `walk` in `RealmLand.in_water` unless `wade` is set. The draught's trample is sheet 93. The meshes are the wildlife horse builds in `life_kit.gd` (scales about 1.42, 1.3, 1.6, 1.15), gait on the GPU from the phase. They are not a new body to sculpt.

**Change.** The hitching line you already have is the place the difference is said, in the giver's mouth, once. Ysolt's line names the stone. Cadoc's names the water. The pits' line already says nothing hollowed stands in its way. Fennick's names the road. Do not add a stat card on the horse. The gallop numbers can stay. What the hands need is the hop from sheet 102, the stop from sheet 93 eased rather than zeroed, and a trot that does not share a number with the herd's spook. Herds bolt when `player_speed` passes 5.5 (`life_beasts.gd`). Garron trot is 6.0, palfrey trot is 6.5, draught trot is 5.5. A sitting trot empties the meadow. Raise the herd's fast threshold to about 8, so a trot is a pass and a gallop is the thing that lifts heads. The player node is the seat, so the herd already sees the horse's speed. It does not need a new alarm.

**Prove.** Ride each breed on its own ground. The palfrey is the road. The garron takes the tor step the palfrey stops on. The pony keeps a trot where the mere takes the others to a walk. The draught shoves a wretch and does not delete the pack. A trot past the meadow deer turns heads. A gallop sends them.

**Stay.** Prices stay. One owned list, one "last ridden" for the call. No fifth breed. No horse armour.

---

## Sheet 104 — Buying, calling, and the fight that unsaddles you

**See.** The first E at a rail spends the ash and leaves you standing. The toast says you may ride it or call it. The second E is the mount. H anywhere else drops the last horse on the ground three metres behind you, already there. A boss's ring pulls you off with a toast and no time to turn the animal.

**Where.** `horse.gd` `interact`: not owned, and you have the ash, deducts it, appends the breed, sets `ride`, toasts, and returns without `mount()`. `stables.gd` `_unhandled_input` on `mount` (H): refuses if you are already up, if you own nothing, if a boss fight is active, or if the ground behind you is more than 2.5 m off your height. Otherwise it writes `global_position` to the ray hit. `drive()` calls `dismount()` the frame `Player.boss_fight_active` is true.

**Change.** The buy toast is enough. Do not also mount on the paying press. The call is the one that should take a second. Sheet 91 already moves the horse in from off the path. Keep that, and play the hoof from sheet 88 when it arrives, not the ward chime. On a boss ring, turn the horse and walk it out for about a second, then dismount at the edge. The toast can stay. A pop-off in the centre of the disc is the same class of teleport as the side-step dismount.

**Prove.** Pay for the palfrey. You are on your feet, poorer, and the prompt now says Ride. Whistle from the west road. You hear it before you see it. Walk a summon into the Thornwarden's ground. The horse leaves, and you get down at the lip, facing the fight.

**Stay.** No horse in the crypt if the ground test fails. The toast "Nothing can reach you here" stays. H does not stack a second horse.

---

## Sheet 105 — The watch is a timer wearing a coat

**See.** Four posts stand on the roads: the West Road, the Pits' Gate, the Orchard Way, the Mere Way. Three watchmen in two coats, a sword that is the villager chop, a lantern that is not a fire. Stand there and the dark arrives as a toast. The fight that follows does not look like the fight you have with a wretch.

**Where.** `watch_posts.gd` `POSTS`. `watch.gd`. Wake at 70 m, sleep again past 80 m if no wave is up. Assaults only while you are inside 55 m, the first about 30 s after the script starts (`_next` begins at 30), then every 80–140 s. Three hollowed, plus more for each hold the post has survived, times `ReachState.pressure()`, clamped 3 to 7. They spawn 15 m out along `face` and `focus` a watchman. A watchman inside 1.8 m plays chop and, when the cycle crosses 0.62 of `SWING` 1.7 s, calls `take_hit(1.1, null)`. The `null` is why the flinch has no direction. A hollowed inside its own strike range ticks 1 damage onto the watchman every 1.6 s, whether or not it is in a swing. At 0 the watchman kneels. At no one standing, the post falls for 150 s and the wave is cleared. They rise at full health. Sheet 89 asked for a hurt pose. The pose is the small part.

**Change.** The cut lands when the chop pose is at the body, and `take_hit` gets the watchman as `from`, so the hollowed flinches away from the blade. The hollowed's damage on a watchman uses the same strike moment the player already trusts (sheet 51), not a clock that runs because two radii overlap. A kneel is the downed pose you have. Standing back up is a short rise, not a pop from kneel to idle at full health. The first assault waits until you have been inside the ring long enough to see the post, about ten seconds of presence, and the 30 s default does not fire while you are still on the road toward it.

**Prove.** Ride to the West Road post and stop. You see three people before the toast. A chop connects when the blade is in the hollowed. A wound on a watchman reads on the body. Leave. They sleep. Come back after a fall. They get up.

**Stay.** Two attackers on the player's own fight stay the player's rule. This wave is the post's, capped at 7, asleep past 70 m. No new soldier AI. The chop is still the villager chop.

---

## Sheet 106 — What the watch pays, and what its light is

**See.** A hold is a toast and 6 grave ash. Every third hold, another toast and a random piece of gear from a quartermaster who is not standing there. The lantern on the hook does not keep the dark off you. You can lose a post, ride off, and the only record is a line you already clicked past.

**Where.** `_held` gives `grave_ash` 6, and on `n % 3 == 0` rolls `GearDB.make` at rarity 1, or 2 if the post has held six times. Both lines are `Events.toast`. The lantern is built in `_build_post` and the comment is explicit: a plain light, not a safe light, because the watch has to do the keeping. State is `Travel.system_state("watch")`, `held` counts and `fallen` times. It saves. The map pin is `map_kind` watch.

**Change.** One toast, spoken as the post. "The West Road holds." The ash is in that sentence. The third hold names the piece in the same sentence. Route it through the text director so it does not land on top of a tide line (sheet 79). The lantern stays a lantern. The first time you stand in it and your gloom does not drain, a watchman line is the lesson, not a systems tip. They have the kneel and the idle. One of them can say it.

**Prove.** Hold the post once. One line, the ash in it. Hold it to the third. The piece is named once. Open the map. The post is on it. Stand under the hook at full gloom. It still fills, and somebody tells you the fire is the thing that doesn't.

**Stay.** The pay stays 6 ash and a piece every third hold. Item level on that piece stays, by the decision of 5 November. No quartermaster NPC. The sentence is the quartermaster.

---

## Sheet 107 — Seven camps, and a fire you did not light

**See.** Past the watches, seven people keep camps: Ruan in the Holds, Jory at the quarry, Ysolt on the moor, Elspeth at the foundry, Linnet in the orchard, Agathe in the necropolis, Cadoc on the mere. A fire, a seat, a short walk. They do not flee when the tide comes. The fire is already burning when you arrive.

**Where.** `village_cast.gd` `OUTPOSTS` and the seven `camp: "outpost"` people. `village.gd` `_outposts` looks for a clear disc, tries a smaller walk if the Holds or the quarry will not take the large one, and if it finds nothing appends "no clear spot" to a report and skips that person. `village_props.gd` `outpost` builds the dressing by style, a flame, a smoke, and `LightGrid.register(..., 5.5, MIRROR)`. Mirror light drains gloom and turns ordinary foes. It is not a rest and not a checkpoint. The comment says so, so the giver is not standing in a fight. Jory's chop is on a block. The others tend, sit, mourn, walk. They are awake whenever the village is. They are not the Kindled Watch.

**Change.** If a camp fails to place, that failure wants a line in the same report the realm audit already prints, and a playtest that walks all seven. A missing Ysolt is a missing horse as well as a missing quest, because her fire is where the garron is sold. The fire stays lit. It is theirs. The prompt must not say Kindle. The first time you stop in one, the giver's existing talk is the place that says this light is not a bed and not a save. Mirror radius 5.5 stays. Do not promote it to a brazier to make the pillar comfortable. The pillar is kept by whose fire it is.

**Prove.** Walk the seven regions. Each giver is at a fire you can stand in. Gloom falls. The checkpoint does not move. Jory's hammer is one swing (sheet 89). None of them vanish in a tide.

**Stay.** `--no-r34-outposts` stays a perf switch, not a shipping mode. No eighth camp. The styles stay the dressing they have.

---

## Sheet 108 — Something happens, out of sight

**See.** A toast, a pin, and a thing you were not in the room for. A procession singing toward the Stair. Hollowed at the edge of a fire you lit. A tear that keeps shedding crawlers and leapers until six are dead. A pilgrim on their knees who stands up when you are close and walks home. Miss it for four minutes and it ends itself. Quit and it was never saved.

**Where.** `roam_events.gd`. One at a time. First after 150 s, then every 200–360 s, divided by `ReachState.pressure()` when one ends. Placed 35–70 m out, not in light, not more than 12 m above or below you. Twelve rays, then it gives up and tries again in 30 s. An incursion instead wants a lit brazier between about 21 and 98 m. Life of an event is `LAST` 240 s. Procession: five wretches and husks, patrol a 35 m line toward (0, −104), pin stuck to the first. Incursion: five at 11 m around the fire, wretches and spitters. Tear: a violet light (energy 6, range 14, life 1.2 s) and a burst, then a crawler or a leaper every 3.5 s, at most three alive, six kills. They spawn at y + 1 and fall. Pilgrim: kneels, at 3.5 m stands, toasts, gives 10 ash and a relic fragment, walks 40 m, and the pin goes. Rewards on a win are 14 / 12 / 16 ash, and the tear adds two ember shards. `save_soon` on the end, because the ash is the save. The event itself is not. Act III with the latch open biases the pick toward the pilgrim.

**Change.** The pin is the teacher. The toast is one line and it goes through the director, not over a banner. The procession's pin rides the file, not only the first body, so killing the leader does not park the marker on a corpse while the rest walk. The tear's spawn sits on the ground ray the other events already use. A pilgrim who has stood up is a person walking, and the fragment is in the toast. An event that expires because you never came keeps its pin until the last five seconds and then lets go. It does not need to be saved. A thing that lives four minutes is allowed to be gone when you come back tomorrow.

**Prove.** Wait out of combat past the first two minutes with the map open. A pin appears. Walk to each kind once, by forcing them in the existing test if you do not want to wait. The procession reads as a file. The tear's creatures stand on the ground. The pilgrim's line plays, and you have the fragment.

**Stay.** One event. The 2 s check while none is running. No event inside a boss fight (`boss_fight_active` already blocks the start). The slice still has none of this. `--slice` stays the quiet night.

---

## Sheet 109 — The valley changes, and mostly by toast

**See.** After the two keepers fall, a toast says the dark is looking. Bells rung where they hung leave a frame, a small warm light, and a country that refills its camps more slowly. Three factions, the Rooted, the Kindlers, and the road folk, become friends and then kin by arithmetic, and hand you a gift you did not see anyone give.

**Where.** `reach_state.gd`. Act 1 until both Thornwarden and Bone Abbot are down, act 2 through the peal, act 3 when that quest is done, act 4 after the Warden. `pressure()` is 1, 1, 1.3, 1.5, 1.2 across those, and lower if the latch is shut. It scales watch waves and shortens the roam wait. A rung bell (`Book.pick == "rung"`) lights a frame at the pickup, `LightGrid` mirror radius 2.5, "enough to stand beside, not to shelter in." A fresh ring swings. A loaded one hangs. Quiet multiplies camp respawn by 3. Kin, tier at standing ≥ the kin threshold, multiplies by 2 again, and watchmen in that country have 1.5× health. Standing is +2 per finished quest in the faction's zones, +3 for a bell rung there, +1 for a tongue carried, and every carried tongue also counts for the Kindlers. Friend gives the items in `FACTIONS[f].gift` and a toast. None of this is a person in the road.

**Change.** The act toast can stay. It is the chapter. The friend gift should be a line from someone you already talk to in that country, the next time you speak, not a parcel from the air. The quiet bell is the good object. Leave the swing, the small radius, and the refusal to be a checkpoint. What you should be able to notice, without a menu, is the camp that is not back yet and the bell you can see. If a kin country's watchmen simply have more health and nothing about them reads as kept, the 1.5× is a spreadsheet. A kept post can fly the banner it already builds, and that is the whole tell.

**Prove.** Ring a bell and leave it. The frame is there after a reload, still, with the small light. Clear a camp in that country and the next one is late. Reach friend with the Kindlers by doing their work, then talk to someone in Hearthward. The gift is in the conversation. The toast stack on the road is one line shorter.

**Stay.** The choice to ring or carry stays the quest's choice. Carried tongues still weaken the Warden. Factions stay off in `--slice`. Do not add a reputation bar.

---

## Sheet 110 — The tide, the ambush, and the board

**See.** Stay off the fires and the dark eventually hunts you. A warning, then a banner, then waves, then a fire ends it if you stand in the light a second and a half. Paths also hide a step that raises a pack under you. A board by the road and a notice at a haunt ask to be read, and the reader lets the night keep moving.

**Where.** `encounters/director.gd`. Tide every 330 s, faster as tiers climb, floor 200 s. Warning at 25 s. Three waves, 36 s apart. The tide gives up at 150 s. Hunters' home is rewritten to where you are, so they do not leash. `SAFE_STAND` 1.5 s in a lit fire breaks it. Haven (Hearthward, 34 m) and the Ossuary never start one. Ambushes sit on paths about every 6 m of walk, skipped near fires and the haven, at least 42 m apart, trigger radius 6 m, cooldown 360 s, and 75 s between any two. One fixed ambush on the mere causeway. `bounty_post.gd` is an Interactable. Reading frees the glint and opens the encounters reader. Sheet 82 already says that reader does not pause.

**Change.** The warning toast and the banner are one voice, the director's. "Reach a lit fire" is the whole instruction, and it is already the right one. Keep it off the compass. An ambush on a gallop (sheet 103's 11 m/s) at a 6 m radius is a pop you cannot have seen. Stretch the trigger to the edge of the headlight you would have had on foot, or plant the bodies a step earlier in the direction you are moving, so a horse does not materialise them under the hooves. The board pauses, as sheet 82 said, and the next notice is the same key. Walking away can stay the close for a note nailed in a field. The board in the road is a menu.

**Prove.** Stand in the meadow dark until the warning. One line. Reach a fire and hold it. The tide breaks. Gallop a path you have not walked. The ambush is in front of you, not in the horse. Read the board. The night waits.

**Stay.** The haven stays empty of this system's spawns. Three waves stay. The tide is the clock, and it is allowed to be slow.

---

## Sheet 111 — Two rests, one toast

**See.** You stand at the hearth and the night tells you that you are rested: gloom gathers slower, spells come back sooner, for a counted time. The XP bar grows a pale stretch that the sentence never mentions. Kills then pay twice until that stretch is gone. They are the same rest and they are not the same sentence.

**Where.** `hearth.gd` `rest_here` fills `hs().rested` to a comfort duration and, in the same call, sets `rested_xp` through `LevelDB.rest_pool`. The toast names comfort and the seconds. It does not name memory. `level.gd`: kill XP is 3 / 5 / 15 / 25 / 40 by kind of foe, doubled while the pool lasts, the bonus taken out of the pool. A rest adds half a level and caps at a level and a half. Quests, seals, kindles, and bosses do not draw on it. `ui/xp_bar.gd` draws `rested_frac`. Both survive the save. Item level, gear sets, and this rested XP stay, by the decision of 5 November.

**Change.** Add the memory to the toast you already emit. One clause. The bar is the picture of it. When the pool hits zero, the line "You are no longer rested" is wrong if the timed comfort is still up, and it is wrong the other way if the bar is empty while the buff remains. Split the sentences. Comfort ending says the fire's ease is gone. The pool ending says nothing, because the bar already went out, unless both end together, in which case one line can carry both.

**Prove.** Rest at the hearth on a save with room in the pool. The toast mentions the bar. Kill a wretch. The gain is doubled and the pale stretch shrinks. Stand until comfort ends. The words match which one ended.

**Stay.** The numbers stay. Half a level a rest, cap a level and a half, kills only. No second rest currency. Gear sets are not this sheet.

---

## Sheet 112 — The gear is a ledger

**See.** Four slots that are already on the body: a cup under the orb, a stole, the lantern's glass, a cord. The piece has a name. Under the name, a list of percents. Two pieces of a set wake a sentence. Four wake a bigger one. The list is what you read. The sentence is what you came for.

**Where.** `gear_db.gd`. Rarities Worn through Umbral, 0 to 3 affixes, max level 2 through 6. Nineteen affixes, each a mod the spells already have: step range, lance width, lash, ward life, gloom held, ash found. Sets are Kindler's Regalia, Ferryman's Weeds, and the others in that const. Two worn and four worn. Legends on Umbral pieces flip a flag a spell already checks. `gear_runtime.gd` raises a piece at a fire, reforges an affix, salvages. No durability. The character screen is one key and four tabs. The r35 critique called this stat soup. It still is, because the lines are still the page.

**Change.** The card shows the name, the set, and the one line that changes a verb ("Rift Step reaches further", "the Lash hits harder"). The percents of power and cooldown live on the second look, the same page you already open to reforge. A set bonus is drawn as the sentence in `SETS`, not as another +10%. Raising a level at the fire can stay a number. It is the decision you asked to keep. It does not need to be the first thing the eye hits.

**Prove.** Loot a Kindled girdle and a second Ferryman piece. The card tells you what changed in the hand. Reforge. The full list is there when you ask for it.

**Stay.** Four slots. No new paper doll. No durability. Item level stays. Do not add a fifth affix family.

---

## Sheet 113 — A hum, then a banner, then it gets up again

**See.** Somewhere off the path a low sound plays once. Walk in and a banner counts a secret found. Some of those places, when their condition is true and you are close, raise a named elite. Walk away before it dies and the next time you come it rises again, as if the first meeting had not happened.

**Where.** `secrets/director.gd`. Sites in `State.sites`. Within `radius + 13` m and 12 m of height, one hum at −13 dB. Inside the radius and 8 m of height, `State.mark("found")`, a louder hum, and a banner "secret found · n of m". Elites whose `when` is true spawn inside 26 m, toast "%s rises.", and are kept in `_live`. If the node is gone and the id was not marked killed, `_live` forgets it and the next pass spawns another. A kill marks `elites` and it stays down. The static puzzle progress that survives a rebuild is sheet 86. This respawn is the one that happens in a single night, because you took a path around.

**Change.** An elite that has risen is committed for the night even if you leave, the way a camp you have woken stays woken until it sleeps by distance and then stands as the same body. If the distance sleep is the right tool, use it. Do not roll a new one. The banner waits for the director the way the other headlines now should (sheet 79). The hum is the find. Keep it quieter than a bolt.

**Prove.** Walk to a secret you have not found. Hum, then the count, and they do not share the screen with a quest banner. Pull its elite and leave the region. Come back. The same fight is there, or it is waiting asleep, and it is not a second introduction.

**Stay.** Found stays found in the save. Killed stays killed. The hum does not become a map pin. The world already refused the pin on purpose.

---

## Sheet 114 — Herds, a hart, and a gallop

**See.** Deer, elk, fox, hare. A trot lifts their heads because the trot is just over the line that means "running." A gallop sends them. The white hart is a rare watch from the edge of the wood, then a walk into the trees and a few glowing prints. Meteors and a rift surge move the sky on long timers. None of this knows a horse from a woman, which is right, as long as the horse's walk is not a panic.

**Where.** `life_beasts.gd`: `player_speed > 5.5` is fast. The player position is the seat while mounted, so the herd measures the horse. `phenomena.gd`: showers every several minutes, a surge every several minutes, wisps in fen, old forest, glade, and ruin when you are alone, the hart very rarely at 40 m. Alarms on a surge and on thunder are by kind. A horse is not in that match. The hart's look was already pushed off the flat white that read as a placeholder. Do not reopen the mesh.

**Change.** The threshold move is sheet 103. Leave the hart's distance and its decision to leave. A wisp that leads you to a secret you have already found should prefer one you have not, which is a sort on the list the director already keeps, not a new guide. A surge may keep startling herds. It should not restart a wisp you are in the middle of following.

**Prove.** Trot the meadow. Heads up, no bolt. Gallop. They go. If a hart is forced from the debug trigger, it watches and leaves. A wisp, if one is up, still ends at a place.

**Stay.** The sky, the grade, and the fog are not this. Phenomena stay offsets. No mounted combat music. No herd that rides with you.

---

## Sheet 115 — What this pass still refuses

**See.** The roads are busier than the first hundred sheets admitted. They are still one night. A watch, a camp, a pin, a horse, a bar of memory.

**Where.** Slice hides horses, the watch, roaming events, faction tiers, bounties, and the gear raise. The full night is the default. The pillars are still the test. Warmth at an outpost is theirs. Warmth at a brazier is yours. The dark between them is the clock, including on a horse, because `ride_tick` already calls `_update_gloom`.

**Change.** Sheets 101 and 102 first. They are the two things the hands hit. Then 105, because a watch that fights on a timer teaches the wrong fight. Then 108 and 109, because a toast is not a place. The rest can wait for the morning you are in that file.

**Prove.** The same as sheet 100, plus one ride from Hearthward to a watch and one camp fire you did not light. Write the sentence that still snags.

**Stay.** No new autoload. No new breed. No reputation bar. No fifth gear slot. The robe, the four stair fires, and the glow, untouched.

---

# Part VII — The rest of the night

What is still outside the sheets: the staff while you are mounted, the fires after they are lit, the door that counts bells, the rooms the bosses fight in, the lift, the shade, the Kindling, the conversation, the journal's map, the weather, the gather, and the night that begins again after the Warden. Same rule. No new system.

## Sheet 116 — The staff on a horse

**See.** The hotbar is still on the screen. A bolt can leave. A held lance does not fill in the hand the way it does on foot, and the body does not square up to the thing you are shooting. A roll does not happen. Space gets you off (sheet 102).

**Where.** `SkillBook` is its own node. Its `_physics_process` is not the player tick the ride returns from, and `skills_locked()` does not mention `riding`. So the slots still see their buttons. `ride_tick` returns out of the player tick before `casting._animate`. That function is what turns the chest toward the aim, picks a foe to look at, and drives the rig from real velocity. The ride calls `animate(Vector3.ZERO, ...)` instead, so the pose is the seat. `cast_pose` still arrives, because it comes from the `skill_cast` signal, not from that tick. Dodge, slide, and the staff arts are on the player tick after the return, so they do not run. Lock-on is in `_unhandled_input`, so it does.

**Change.** Keep the instant bolt. It is the right weapon from a saddle. Run the facing and the look-at from `ride_tick`, aimed along the camera, so the chest and the shot agree. A held charge should call the same `set_charge_glow` path it uses on foot, or the lance should refuse on a horse with the flash the book already uses for a refused cast. Do not also enable the roll. The saddle is not a dodge. Space stays the hop from sheet 102.

**Prove.** Gallop, lock a wretch, and bolt it. The shot leaves the staff you can see, toward the crosshair. Hold the lance. Either it fills, or the slot flashes and does not pretend to. Press the dodge. Nothing. Press E. You get down.

**Stay.** Gloom still ticks in `ride_tick`. A boss still unsaddles you (sheet 104). No mounted melee.

---

## Sheet 117 — A lit fire will not remember you

**See.** You kindle a brazier and it becomes your checkpoint. You come back later, stand in it, and press E to rest. If you own no relic, nothing is offered. The fire is lit and the prompt is empty. If you do own one, the prompt says "Attune your relics" and opens the satchel. The checkpoint moves as a side effect of that, with a toast the attune screen is already covering.

**Where.** `brazier.gd` `can_interact` returns true when the fire is unlit, or when it is lit and `Travel.relics` is not empty. A lit fire and an empty relic list is not usable. `interact` on a lit fire calls `remember()`, which is the rest that moves the checkpoint and toasts "The fire will remember you," and then opens the satchel in attune mode. The prompt text for every lit fire is the attune line. The kindle line is only for a dark bowl. `remember` itself is fine: it refuses a move of less than a metre and says so once.

**Change.** A lit fire is always usable. The prompt is "Rest" when you are not standing on this checkpoint, and it is quiet when you already are. Rest calls `remember` and does not open the satchel. Attune is a second line, or the same key only when the satchel is what you opened on purpose from the character screen. The kindle sentence can stay. It already tells you to stand in the fire.

**Prove.** Kindle the Stair-foot fire, ride to the Landing, kindle that, die, and confirm you return to the Landing. Walk back to the Stair-foot fire with an empty relic list. The prompt says Rest. Press it. The toast says the fire will remember you, and no menu opens. With a relic, Rest still does not open the satchel.

**Stay.** The four named fires keep their names in the kindle toast. A mirror fire at a camp (sheet 107) is still not a brazier and still has no prompt. Outpost light is not this.

---

## Sheet 118 — Relics, taken once

**See.** A relic on an altar is a take. It leaves the world, it is saved, and from then on its two behaviours are swapped at a fire. The fire currently pretends that swap is the only thing a lit fire is for (sheet 117).

**Where.** `reliquary.gd`. `interact` attunes on the take. `variant()` is what the spells read. The pair for each relic is the table already shipped in the r36 work: hearth or cinder ward, scatter or brand lance, and the rest. Swapping is `Reliquary.attune`, also called from the satchel when it was opened with `open_menu(true)`.

**Change.** The take stays a take, with its toast, and the altar stays empty. The swap moves to the satchel's relic row, opened from the character screen, at a fire or not. A fire is a rest (sheet 117). Standing in one can still be required for the swap if you want the cost. The prompt on the bowl should not be the only door.

**Prove.** Take a relic. It is gone from the altar after a reload. Open the satchel's relic row and swap. The next cast is the other behaviour. Press E on a lit fire. You rest.

**Stay.** Two variants, not a tree. No third behaviour on a relic. The spell change stays a change of play, not a percent.

---

## Sheet 119 — The door that counts

**See.** The summit ward and the Warden's ground stay shut until four of the seven bells are answered. Walk in early and one toast tells you. Walk in again and it does not. The door itself does not show a count.

**Where.** `boss_arena.gd` checks `requires_bosses`, then `requires_bells`. `QuestBook.bells()` counts a bell once its choice is made, rung or carried, even before you hand the quest in. The toast is `no_peal(rung, requires_bells)`, and `_warned` makes it once per visit. `ward_seal.gd` listens to `quest_changed` and refreshes when the count is met. A seal's guardian progress is its own toast, "n of m guardians fallen," with a small scale pulse.

**Change.** The door shows the count in the place: four marks, filled as bells are answered, using the ward mesh that already rebuilds in `_refresh`. The toast can say the same words once. A second approach, after you have rung another, should be allowed to speak again, because `_warned` currently survives the bells you gained while you were away. Clear it when `bells()` changes.

**Prove.** Walk to the summit with one bell. You see one mark of four, and you hear it once. Ring a second. Walk up again. The door shows two, and it may speak once more. At four it opens. The guardian line on the earlier seals still pulses.

**Stay.** Four of seven stays the gate. Carried and rung both count. The Warden still loses hold for tongues at the Keg. That is a different sentence, spoken in his room, not on this door.

---

## Sheet 120 — The room, not the move

**See.** The tells in sheets 56 through 61 are the swings. The room around them is a separate thing: a bar that renames itself on a phase, an emote under the cast bar, and a fight that pauses if you walk out instead of resetting.

**Where.** `boss_arena.gd`. Leaving past `radius + LEAVE`, or dropping 6 m, calls `_hold_fight`. The comment says a walk-out pauses and does not reset. The phase bar flashes and can append "I", "II", "III", or a `phase_titles` name. `emote()` puts a line up for 5 s, warm, under the cast bar. That is a second headline channel beside the text director (sheet 79).

**Change.** Phase changes and emotes go through the director, in the banner lane, for the 5 s they already last. The bar keeps the notches and the name. It does not also print a title across the middle of the screen. A paused walk-out should hide the bar. Coming back shows it where the health was, not from full.

**Prove.** Start the Thornwarden, leave the ring, come back. The health is where you left it and the bar was gone while you were out. A phase change is one line, in the lane, not over the cast.

**Stay.** The pause-not-reset stays. It is the right mercy. The moves stay the moves in the earlier sheets.

---

## Sheet 121 — Two raids

**See.** The Thornwarden's ring and the Warden's summit are not only health bars. One builds a maze of briar. The other has pylons and a falling star. Attuning before the fight, by handing in that boss's chain, loosens something, and a toast says so in the abstract: he will hold back a hand, his count is short, his bell will ring wrong.

**Where.** `henge_raid.gd` and `summit_raid.gd` build the rooms and expose `room_begin`, `room_reset`, `room_won`. `quest_book.gd` `attuned()` is a story flag, `attuned_` plus the boss id. `ATTUNE_TOAST` is the three sentences. The raid reads the flag and decides what it costs the boss. The toast is the whole explanation.

**Change.** The toast can stay as the promise. The room has to show the promise on the first cycle of the mechanic: one briar that does not grow, one pylon that is already dark, one bell that visibly cracks. Whatever the flag already changes, make that change a thing in the room in the first ten seconds, not a number on a later swing. `room_reset` on a death should put that tell back, so a retry still teaches.

**Prove.** Hand in the Thornwarden's chain, enter, and you can point at the thing the attune removed. Die. It is still gone. Enter without the chain. It is there.

**Stay.** No third raid. The attune stays a quest hand-in, not a menu toggle.

---

## Sheet 122 — The lift, and a horse in it

**See.** The crypt lift is a cage that waits, rises, waits, and falls. On foot it carries you, because the deck is an animatable body. There is no call and no prompt. Miss it and you wait out the rest of the cycle. On a horse the rails are walls, and the horse's own ground ray fights the deck.

**Where.** `chain_lift.gd`. `travel_time` 7 s, `dwell` 3 s, deck 2.6 m square, open to the west. `sync_to_physics` is on. The chain mesh orientation is built with a branch that is hardcoded `if false`, so the chain uses the second basis every time. `horse.gd` `drive` raycasts `Layers.WORLD` for a wall at chest height and sets `speed = 0` on a hit, and every tick writes the rider's position to the seat from its own ground ray.

**Change.** Leave the on-foot ride. It is the right kind of platform. Add nothing but a small lamp or a worn mark on the calling floor so the wait is a place and not a guess. The dead branch in the chain basis should be deleted the next time that function is open, and the chain that remains should be the one you can see attached to the deck. A horse that enters the cage gets down, with the same toast a boss uses, or the wall test ignores the deck's own rails while the seat is over the slab. Do not try to make the horse a passenger of a 2.6 m cage. The dismount is the honest fit.

**Prove.** Ride the lift on foot from the hall to the deep floor and back. You stay on the deck. Ride a horse onto it. You are on your feet on the deck, and the horse is not wedged in the rails.

**Stay.** Travel time and dwell stay. The lift is not a fast travel.

---

## Sheet 123 — The shade is not a foe

**See.** At full gloom a shade arrives (sheet 48). You shoot it. The bolt bursts as if it had struck something, and the shade is untouched. Only light unmakes it. Nothing in the moment says that, except the absence of a wound.

**Where.** `shade.gd` `take_hit` ignores damage and, if you are the target, calls `note_shade_passed()`. `unmake_by_light` is the only end. The body bobs, the mask looks at you, the arms reach. Lights on it pulse. A kill freeze never runs because it never dies by `take_hit`.

**Change.** A bolt that passes does not play the hit burst or the damage number. It can flare and go on, or fizzle with no punch. As the shade enters a light that will unmake it, the dissolve parameter that already exists on the skins should climb before `unmake_by_light`, so the lesson is the fire eating it. The arrival flinch from sheet 48 stays.

**Prove.** Fill the bar on purpose. Bolt the shade. No wound number. Step into a fire with it on you. It thins, then it is gone, and the lockout before the next one is the 2 s the light already grants.

**Stay.** It is still not a health bar. Light is still the only answer. Do not give it a poise.

---

## Sheet 124 — Ash, a core, a charm

**See.** Grave ash is the feed for the Kindling. The first time you hold enough, one toast tells you to feed a fire, and it does not tell you again. A staff core you pick up slots itself into the orb if the orb is empty, and a toast says every bolt is changed. A charm slots itself into the first free socket, with no toast at all.

**Where.** `kindling.gd` `_on_item`. Ash uses `st.told`, once, at 6 or more. A core with `core_of == ""` assigns and toasts. A charm appends to `worn` while `worn.size() < slots` and only calls `refresh()`. After a boss, a 7 s timer toasts that the fires will take more ash. The Kindling itself is the long menu in `ui/growth.gd`: embers, spells, oaths, relics, charms, staff, loadout. Sheet 82 already stops a hosted page from celebrating the hearth.

**Change.** The ash line stays once. The core line stays, and it names the change in the verb ("bolts split", "bolts chain"), not only "changed." A charm that auto-wears gets the same one line, naming the charm. A charm that does not fit, because the sockets are full, gets one line too, or it sits in the bag in silence and you will not know you found it. The menu can stay large. The first look on a charm row is the verb, as with gear (sheet 112).

**Prove.** Pick up the first core on an empty orb. The toast says what the bolt now does. Fill the charm sockets, find another. You are told it is in the bag. Open the Kindling at a fire. The new charm is there, unworn.

**Stay.** Auto-wear on an empty socket stays. It is a kindness. Item level and the paths stay. No new tab.

---

## Sheet 125 — The conversation

**See.** The keep, and anyone else with a talk id, opens a box along the bottom. The world pauses. A portrait of that speaker types the line. Choices are in the box. Esc steps back (sheet 83). The portrait is a real rig in a small view, jaw moving while the letters arrive.

**Where.** `story.gd` `talk` resolves the node from `dialogue_db.gd` against the world. `ui/dialogue.gd` types at 52 characters a second, plays a voice on the UI bus side of the pause because the box is `PROCESS_MODE_ALWAYS`, and frees the mouse. The bartender leans and gestures on his own tick while his line types. Opening narration waits for the cover (sheet 4), then another delay.

**Change.** A click or the interact key should finish the line that is still typing, and a second press advances. At 52 a second a long line holds you. The skip is the courtesy. Do not skip a choice. The portrait stays. It is the one place a face is allowed to perform. While the box is up, the horse prompt and the fire prompt are gone because the tree is paused and the HUD already hides for a menu. Confirm that, and if a prompt leaks through, it is the same bug as the banners in the old register.

**Prove.** Talk to the keep. A long line completes on E, and the next E advances. A choice does not select itself on the key that skipped the type. The portrait's mouth matches the line. Leave the conversation. The night is as you left it, including a horse that was standing still.

**Stay.** The pause stays. Dialogue is not a real-time parry. The writing stays the house voice. This sheet does not add lines.

---

## Sheet 126 — Marks, and a second map

**See.** A task puts a mark on the giver and a pin on the place. The compass and the minimap both read `map_marker`. The journal has its own Map tab, inside the character screen, beside Places, Writings, Stories, Wenna's journal, and Relics. Two maps, one night.

**Where.** `quest_markers.gd` rebuilds marks from the live quests, including `main:` objectives, and adds the node to `map_marker` with a label. `ui/codex.gd` tabs include Map. The minimap is sheet 80. Daily marks are a flag on the same mark.

**Change.** The compass and the corner map are the map you use while walking. The journal map can stay as the one you open to remember the whole valley. They must use the same pins. A watch, a horse, a rung bell, a roam event, and a quest target are already `map_marker`. The journal map should read that group and not a second list. If it already does, the work is only to check a pin that exists in the corner and is missing in the book. A daily and a story mark that share a person need two labels or one combined label, not a flicker as `refresh` replaces the meta.

**Prove.** Accept a quest, call the horse, and have a roam pin up. All three show on the compass and in the journal map. Complete the quest. Its pin is gone in both.

**Stay.** No fog of war. No revealed-percentage. The journal stays a book. Sheet 80 still caps the walking objective at three lines.

---

## Sheet 127 — Picking something up

**See.** Ash blooms and grave-iron are in the world. The prompt is a verb and a name. Take it and it is in the bag. Memory ticks by 5 for a gather, with no line of its own, which is right. The ash toast from sheet 124 is the one that speaks, once.

**Where.** `gather_node.gd` `interact_text` is "[key] verb label". `gather()` pays the item. `level.gd` awards `gather` 5 memory. Nodes can be spent and, if they regrow, `_set_ready` is the switch.

**Change.** A spent node has no prompt and no collision for the interact sensor, so you do not get "gather" on a bare stalk. A regrow should be visible before it is usable: the same mesh, dim, then the prompt returns with the mesh. Do not toast every node. The bar is the notice.

**Prove.** Gather one. The prompt goes. Walk away and back. It stays gone until it should return, and you can see that it has returned before the prompt says so.

**Stay.** Five memory. No node mini-game. No tool requirement.

---

## Sheet 128 — Rain on the right surface

**See.** The night is not always the same weather. Clear, mist, gusts, drizzle, storm. Rain streaks around the camera, except under a roof. The bed changes for open ground, leaves, water, and roof. Thunder arrives late by distance, which is the right physics and easy to miss if the flash and the sound feel unrelated.

**Where.** `weather.gd`. States blend mist, rain, wind, thunder. `surface` is what the rain is hitting around the camera. Tops are about −10 dB, raised once already so a storm is not a whisper. A flash calls `pulse()` on the ambient. Herds answer thunder (sheet 114). The Keg's interior is the roof case that matters. If the ceiling test misses, the taproom rains.

**Change.** Confirm the roof test from inside the Keg, under the awning, and in the crypt. A miss is a point in the test, not a new weather state. The thunder's delay stays. The flash should be the same event the sound is waiting on, so a distant strike is a small flash and a late crack, and a close one is both at once. Do not add a weather HUD.

**Prove.** Stand in the doorway of the Keg in a storm. Outside, rain. Inside, the roof bed and no streaks in the face. A far strike cracks late. A near one does not.

**Stay.** The grade and the fog density are touched only through the blends weather already owns. No seasons.

---

## Sheet 129 — The night after the Warden

**See.** Ring the cracked bell and the valley starts again. Bosses and seals reset. What you carry, you keep. Fires you kindled stay lit. The journal stays. Elites come back harder. A banner says the deeper night. The world is rebuilt in the same process, which is how a third of the realm once went missing, and why `reset_night` exists.

**Where.** `director.gd` `begin_deeper_night`. Increments `ng`, clears slain, bosses, and seals, files the ending flags under a per-cycle name, sets `deeper`, saves, banners, and after 2.5 s `Travel.go` back to the start. `session_state.gd` `reset_night` is what must run on that teardown. Sheet 86 is the static puzzles that reset still misses. The HUD mark is sheet 80's problem when frames are off. `bell_note` explains the bell in a reader: ring it and the three rise again, seals close, everything comes back harder, you keep what you carry.

**Change.** The note is the right teacher. It already says what happens. The ring should be a second press, as the note's footer says, and the first press must not also be the interact that starts the rebuild. After the banner, the 2.5 s wait is the beat. `reset_night` runs before the new build, including the puzzle statics from sheet 86. A kindled fire that stays lit is correct. Say so in the note, which it nearly does ("what you carry, you keep"), and add the fires to that sentence if a playtest shows people expect them dark.

**Prove.** Ring it on a finished night. You are at the start. The robe and the bag are yours. The bosses are up. A shrine puzzle from the previous cycle is cold. The save reloads into that deeper night, not back into the victory.

**Stay.** No third mode. The slice does not offer the bell. Tiers get harder by the table already in `tiers.gd`. Do not add a chapter select.

---

## Sheet 130 — The crossing

**See.** Between you and the high door the viaduct is broken. A fallen column is the bridge. The flight up to the Spindle is the last walk before the ward. It is architecture, and it is also a jump.

**Where.** `rift/crossing.gd` builds the gap, the column, the rails, the towers. Sheet 18 is the kerb that is neither a step nor a vault. This gap is that sheet at the scale of the whole night. A horse stops where `climb` says stop (sheet 103). The column is the path that has to be true on foot first.

**Change.** Walk it on foot and on the palfrey, and fix the one lip that fails sheet 18's overlap, here, rather than retuning the global vault for a single stone. The rails should read as rails in the camera (sheet 41) and not as a wall that swallows the view for a second. The horse may refuse the column. That is allowed. The refusal should be the eased stop from sheet 93, on the near side, not a pop halfway along a mesh the ray thinks is a wall.

**Prove.** Cross on foot without a surprise slide into the rift. Ride at it. You stop on the near stone, still mounted, and you can turn around.

**Stay.** The column stays the bridge. Do not fill the gap. Do not add a second lift here. The ward at the top is sheet 119.

---

## Sheet 131 — What is actually left

**See.** The title, the three slots, and the two-step wipe of an occupied slot are in good shape. The combo readout draws only while a chain is alive and then gets out of the way. The mirror gate is a scene-change prop from the older nights. The live night does not ask you to step through one.

**Where.** `ui/title_screen.gd`. `ui/combo_readout.gd` reads `combo.gd` and fades. `mirror.gd` still replaces a hardcoded "[E]" and calls `Travel.go`. Seat code still knows the type, so a gate in a baked scene would still be a gate.

**Change.** Leave the title. Leave the combo readout unless a chain's line covers the crosshair, in which case it sits higher and not larger. Do not bring mirror gates back as travel. If one is still reachable in the realm, it is a leftover and it should not be the way between regions. The regions are a walk.

**Prove.** New Game on an occupied slot asks twice. A combo in a fight prints and leaves. No region transition is a loading-screen door.

**Stay.** Three slots. The combo window stays a window. The valley stays one scene.

The book now covers the body, the fight, the screen, the save, the picture, the horse, the watches, the camps, the events, the factions, the fires, the door, the rooms, the lift, the shade, the Kindling, the talk, the maps, the weather, the gather, and the night after the Warden. Part VIII is the set that was still only a name in that list.

---

# Part VIII — Named, and not yet walked

These are features the night already plays, and the earlier sheets only brushed. Same shape. Same rule. Where two systems do one job, the sheet keeps one.

## Sheet 132 — Two roads, and the horse that undoes both

**See.** Beside a lit fire is an iron post. Its prompt is "The Ember Road," and it opens a list of the other fires. Pick one and you burn down into a wisp, fly the valley, and stand up out of the far fire, which then remembers you. Later, once the Hearthfire is blazing, the Kindling sells the same trip again: hang Brannoc's hand-bells and a menu teleports you, with a toast that a bell answered. Ride to either of them and the trip does not survive the saddle.

**Where.** `ember_post.gd` sits about 2.3 m off the bowl, reach 1.4, and opens `fire_road.gd` whenever its fire is lit. No hearth tier is consulted. `fire_flight.gd` hides the player, disables their process, and `teleport`s them to the far spawn at the start of the flight and again at the end. `hearth.gd` `walk` is the second trip: it requires the bells service and the `bells` work, then `teleport`s and calls `remember`. `player_locomotion.gd` `teleport` moves the body and does not clear `riding`. The next physics frame, `ride_tick` still returns true and glues you to the horse, which never left. The player's interact range is 2.8, so the bowl and the post are both legal from the gap between them, and the nearer one wins.

**Change.** One road. The post is it. Brannoc's purchase wakes that post: until the bells are hung the cage stays dark iron and has no prompt, and the Hearth tab's sentence matches that. The instant `walk()` goes. The flight stays, including the refusal while something is hunting inside 18 m or a boss is up. Before the flight starts, and before any other teleport, get down. The horse stays where it stood. You arrive on your feet. Call it after, the way H already calls. Standing on the post, the prompt is the road. Standing in the bowl, the prompt is Rest (sheet 117). They do not trade places across one step.

**Prove.** Before the bells, the post is quiet. After, fly from the Stair-foot fire to the Landing on foot. You are at the Landing, and it is your checkpoint. Do it from the saddle. You arrive on your feet, and the horse is still at the Stair. Press H. It comes. Drift from the post to the bowl. The prompt changes once, from the road to Rest.

**Stay.** The flight is not a loading door and not a mirror gate (sheet 131). Cold fires stay grey in the list. The horse does not ride the wisp.

---

## Sheet 133 — Hollow, the mound, and the fall

**See.** The bar fills, or the wounds do, or the lava does, and you are hollowed. There is a short lock, then you are at the last fire, gloom and wounds cleared. The ash you had not yet banked is a mound where you fell, and a hint tells you once. Hollow again before you walk back and that mound is gone. Fall off the world and it is a different mercy: you are put back on the last solid ground with a little gloom, and a line that the dark gives you back.

**Where.** `player_vitals.gd` `hollow` sets `_hollowing`, drops the ash, waits 0.9 s, `teleport`s to `checkpoint`, clears gloom and wounds, frees the shade, waits 0.4 s, and clears the flag. `ride_tick` is not behind that flag. It runs whenever `riding` is set, including through the lock, because the wish is zeroed and the ride still returns. So a death in the saddle teleports you, then the horse pulls you back to the place you died. `_drop_ash` frees the previous mound before making the next. `_fell_out` teleports to `_safe_ground` unless that ground is below −38, then the checkpoint, and adds 8 gloom. It uses the same `teleport`.

**Change.** Hollow and the fall both get down first, same as sheet 132. The horse remains. The 0.9 s is a fade to the fire, not a freeze in place while the horse keeps the seat. The mound is one, and the hint stays once. A second hollow may still erase it. That is the cost, and the line the first time should say the next death takes it. Do not bank the ash for them.

**Prove.** Fill the bar on the horse, away from the fire. You wake at the fire, on your feet. The horse is where you left it. The mound is there. Take it. Fall the rift on foot. You are back on the lip, gloom a little higher, and you were not hollowed.

**Stay.** Lava still hollows. A hollow still costs the unbanked ash. The shade is still sheet 123. No death screen, no corpse run beyond the mound.

---

## Sheet 134 — Seven bells, and the latch

**See.** Each of the seven bells is a choice you make standing at it. Ring it for the people who kept it, or lift the tongue for Hearthward. Leave it, and it is still a choice you have not made. The door at the summit counts either (sheet 119). After the Warden, the latch under the door in the sky is three more: turn it, leave it, or break it. The words say a bolt goes home, or the door would open from the other side, or the line of it fades. The sky has to agree.

**Where.** `dialogue_db.gd` nodes `bell_holds` through `bell_mere`, and `door_latch`. The pickup in `quest_world.gd` opens the conversation and does not advance the task itself. `qp:` stores rung or carried. `quest_props.gd` `ring_bell` swings a `Sway` child. The carried line says the bell hangs dumb. The gone line, if you come back, says it hangs where you left it, which is true for a ringing and a lie for a tongue you took. `story.gd` emits a zone title for the latch from the flag, after you have told the keep.

**Change.** Ringing swings the bell you are looking at, once, on the choice, not only if some other caller remembers. Carrying removes the tongue mesh from that bell. Coming back, the gone line matches what is there: dumb and empty, or still hung because you rang it. The latch choice changes the line in the sky in the same beat as the sentence, before you walk back to the Keg to hear it again. The summit count (sheet 119) still treats both bell answers as one mark.

**Prove.** Ring the Holds bell. It swings, and a later visit still has its tongue. Carry the quarry tongue. The bell is empty, and the gone line does not say you left it hanging whole. Latch the door. The line in the sky changes while you are standing on the dais.

**Stay.** Four of seven still opens the ward. Carried tongues still loosen the Warden. No eighth bell. The words stay the words.

---

## Sheet 135 — The tasks

**See.** Someone offers a task in a panel: their words, what they want, what it pays, accept or decline. The night pauses. A banner says the task is new. The corner list shows the spine and whatever you have tracked, then fades after a few seconds unless you hold the view key. L opens the ledger, which pauses again, and from there you track one or abandon one by pressing twice. A count ticks in its own toast. Turn-in is another panel, and sometimes a choice of gear.

**Where.** `ui/quest_offer.gd` pauses. `ui/quest_log.gd` banners on `quest_changed`, posts count lines, and the ledger is L. `objective_line.gd` polls twice a second, shows for `SHOW_S` 6, and hides while a banner is up or while the opening hold is on. Y (`show_objective`) keeps it. Tracking is per task. Pins are sheet 126.

**Change.** The corner list is the tracked task only, plus the spine line if there is one, and it keeps the three-line cap from sheet 80. A change fades it in. It leaves after the 6 s. Holding the key brings that same short list back, not every task you own. The ledger is where the rest live. Accept and turn-in stay pauses. Abandon stays a second press. The gear choice at the end stays a choice of things, and the card leads with what it does (sheet 112).

**Prove.** Accept one task. The corner names it, then gets out of the way. Hold the key. It comes back, and it is still one task. Track a second in the ledger. The corner follows the one you tracked. Decline is still decline, and the giver will say it again.

**Stay.** No quest markers beyond the pins that already exist. No daily board in the corner. The slice still hides the long chains.

---

## Sheet 136 — What the Keg puts in you

**See.** The keep sells a mug, a round for the room, a rumour, bread, stew, and a mulled ale. Bet, once her garden is open, sells the same ideas for longer. A mug at the counter takes 14 gloom off on the spot. Bread raises how much gloom you can hold, for six minutes. Stew makes the dark slower. Mulled ale makes spells hit harder. You can keep two kinds at once. Stand in the Keg's own light, where gloom is already falling, and the mug does nothing you can see.

**Where.** `village_shop.gd` `ale` calls `add_gloom(-14)`. `hearth_db.gd` `MEALS` is the timed set: bread `gloom_add` 12 for 360 s, stew `dark_mult` 0.9, mulled `power` 0.06, and Bet's longer copies. `BELLY` is 2. `hearth.gd` counts them down in play time and folds them into the mods. The gloom bar draws the pool. It does not mark a meal. A round plays `keg_scenes` `round` and raises a little standing with the room.

**Change.** The mug is for the walk, or it is not worth the ash. If it stays, drinking it is a visible drop on the bar, which means it has to be able to matter: let it be carried out of the light, or have the keep's line say it does nothing while you are standing in his fire. A meal moves the cap mark on the gloom bar when it starts, and the mark goes back when it ends. Stew is the bar filling slower, which the number already does. Do not add a row of buff icons. The round stays a scene in the room. Rumours stay one sentence from the keep, and they point at a person who is actually there.

**Prove.** Buy the mug at a full bar in the doorway, walk into the dark, and you can point at the difference. Eat the bread. The bar's top moves. Wait it out. The top moves back. Two kinds, not three.

**Stay.** Item level and rested XP stay. These are not a second of either. No hunger. No third belly slot.

---

## Sheet 137 — The Hearthfire

**See.** Hearthward's own fire on the green is a thing you raise, at that fire, with ash and fragments and the valley in a certain state. Each step makes every kindled fire's sanctuary larger, lets you hold more gloom, and makes a rest last longer. Drawing opens Hild. Roaring opens Bet. Blazing is the bells (sheet 132). Beacon is the last. Hild also sells works, once each: baskets, bellows, a shoe for the staff, a grate, fire-dogs. Paths can be unremembered there, for ash, and the points come back.

**Where.** `hearth_db.gd` `TIERS` and `WORKS`. `hearth.gd` `raise` spends, saves, toasts, and applies reach. `apply_reach` is what actually widens `Brazier` sanctuaries. `unremember` refunds path steps and not the ash. The toast is the whole teaching: "The Hearthfire: DRAWING," and a sentence.

**Change.** The green's fire shows the step in the place. Banked, drawing, roaring, blazing, beacon are five looks on that one fire, inside the glow budget, so you can see which night you are in before you open the tab. A raise is that change, then the toast. Hild's baskets are a visible iron on the bowls you have lit, not only a metre on a radius. Unremember stays at this fire only, and the line says the ash does not return. The bells line in this tab is the post from sheet 132, not a second trip.

**Prove.** Raise it once, at the green, with the need met. The fire looks different. A kindled bowl down the road shelters a step further, and you can feel the gloom stop. Raise it from the Landing. It refuses, and says the green.

**Stay.** Five steps, not a renown track. No new merchant. The four stair fires stay the four. Sanctuary growth is still their light, still earned by the raising.

---

## Sheet 138 — A chest, and a bag

**See.** A box in the world opens once. The lid swings, a chime, a toast of what you got. Gear comes out as "a piece of gear" in that sentence and as a lit bag on the ground, which you then open into the loot window. The window does not pause (sheet 82). An elite leaves the bag and not the box. Walk out of the area with the bag still there and the contents go into the satchel anyway.

**Where.** `loot_chest.gd` `open` gives items directly, toasts `TIER_NAME` plus the list, and `drop_at` for the rolled piece. The toast appends the words "a piece of gear" rather than the piece. `loot_bag.gd` is the shaft and the name, and the window is `ui/loot_window.gd`. Leaving the tree auto-grants what is left.

**Change.** The chest's toast names the items and does not also say "a piece of gear" while a bag is sitting in front of you with the real name. Open the bag and the window is the take. One presentation. The auto-take when a bag would be lost stays, so a streamed hall cannot eat a drop. An opened chest stays open on the next visit, lid up, no prompt.

**Prove.** Open an iron chest. The toast lists what entered the bag. The bag's name is the piece. Take it. Reload. The chest is open and silent. Kill a named hunt, leave the bag, come back from far enough that the place rebuilt. The piece is in the satchel.

**Stay.** No locked-chest minigame. No rarity explosion. The window's pause is sheet 82, and this sheet does not reopen it.

---

## Sheet 139 — Secret places

**See.** Off the road are small works: lamps to light in an order, a beam and a mirror, a writing under a stone, a company that was already told. Close in and there is a hum (sheet 113). Use one and a panel reads, in the corner of the eye, and it does not pause the night. Walk off, read something else, or get hit, and it closes. A banner says you found the place. The prompt on a lamp can name the carving for you.

**Where.** `secrets/` sites, `touch.gd` for the prompt, `beam.gd` for the ribbon, `panel.gd` for the reader. `CLOSE_DIST` is 4.5. It never pauses. Solved state is `secrets/state.gd`, and sheet 86 is the static half of that surviving a rebuild. Rewards are once.

**Change.** The carving is the instruction. The prompt may repeat the word cut into the lamp once you are in reach, and it does not name a lamp you cannot see. The reader stays unpaused, because a secret is a place you are standing in, and a hit still closes it. A beam that is solved stays solved on the next visit, including after the Deeper Night teardown (sheet 86). The hum and the banner stay as they are in sheet 113.

**Prove.** Solve the fen lamps. Leave. The solution is still there. Open a writing, walk four metres. It closes. Get hit while reading. It closes. A lamp you have not walked up to is not named in the corner.

**Stay.** No quest arrow to a secret. No map completion. The glow on a beam stays under the threshold.

---

## Sheet 140 — The ossuary, walked

**See.** You come in from the fen, through a gatehouse and a stair cut in the cliff, into a gallery. A bone bridge has a broken span. The pit is a round drop with a parapet. One cage goes up toward the summit. Another, after the Abbot, goes down into the count and back up to the gallery. The raid hall is deeper still, eight flights under the bank. Sheet 122 is the cage. This is the building around it.

**Where.** `ossuary.gd`. Hall at 12.6, gallery at 8.4, pit at 4.2, `PIT_WALL` 1.3 so a vault does not throw you into the lava. `FEN_GATE` is the door from the descent. `oss_deep.gd` is the lower count. `oss_hall.gd` is the pit hall. The chain lift is `LIFT_AT`.

**Change.** Walk the fen door to the gallery to the pit to the lift, on foot, and fix the one lip that fails sheet 18, here, the way sheet 130 does for the column. The parapet stays too high to vault. The broken span is a jump you can see, with a landing, not a hope. Both cages get you down before they move (sheet 122). The hall that hides the lava from sheet 76 still hides it while you are on these stairs.

**Prove.** Enter from the fen. You are indoors, and the descent is behind a door you could find again. Cross the bone span. You land. Stand at the parapet. You do not fall into the pit by a vault. Ride the cage you meant to ride.

**Stay.** No new stair. Gothic stays lights. The Abbot's room is sheet 120. Do not rebake `main.tscn` to fix a lip. The lip is a runtime probe or a moved collision, same as the other kerbs.

---

## Sheet 141 — Guardians

**See.** A nest, a barrow, a shrine has someone standing on it. They are bigger than the kind they came from, they have a name, and a few of their own are with them. Come close and they are simply there. Leave far enough and they are back on the spot, whole. At half their strength they change, and some of them call. When they fall they pay ash, and they stay down until the Deeper Night.

**Where.** `guardians.gd`. `NEAR` 55, `FAR` 95. The table is brood-mother, tithe-knight, sexton, pale stalker, stonewright, and the rest of `GUARDIANS`, each with an escort and some with `enrage_call`. A site is a node in `guardian_site`, or one of the fallbacks when the world named nothing nearby. The name bar is the encounters bar.

**Change.** Rising at 55 m is fine if you can see them at 55 m. A gallop that closes 55 m before the escort has a pose is the ambush problem from sheet 110, and the same rule applies: they are in the world before you are on them. The half-health call is a tell you can name, a gesture, then the add. Leashing back to full health is honest if they walk home. A pop back to the stone at full bar is a cheat you can see. Dead stays dead until sheet 129.

**Prove.** Walk up on the sexton. You saw the escort before you were in the ring. Leave. They go home, and if you return quickly they are not full unless they had the time. Drop one to half. The call has a beat. Kill them, reload. They are still down.

**Stay.** No new guardian kind. No map icon beyond a pin if the site is already a place. Ash on death stays the payment.

---

## Sheet 142 — The named

**See.** Five people have notices. Hobb knocks three times on the east road. Lisle counts on the fen and gets up if you do not mark him. The briar hart lands and the ground bleeds thorns. The others are the same shape: a haunt, a trait, a note at the Keg, ash, and a trophy the board can show even when the bag does not know the item yet. In the Deeper Night they come back colder, with more life, under a new title. You can meet them before you have read the note.

**Where.** `elites.gd` `ELITES`. Haunts, traits, notes, `ng_only` for the Faceless Penitent. `dress` puts the glow and the parts on. The board is sheet 110. Trophy ids live in the encounters state if `ItemDB` does not know them.

**Change.** The trait is the fight, and it plays before you have been to the Keg. Hobb's three knocks are the tell. Lisle's rise is a thing you see fail once, then the mark stops it. The hart's thorns come after the landing, with time to step off, as the note already begs. The note at the board is the rumour, not the tutorial. A trophy the item list does not know still shows on the board with its name, and it does not become a blank row in the satchel.

**Prove.** Walk the east road at night without reading the board. Hobb knocks, and the knocks are the warning. Mark Lisle. He stays down. Skip the mark. He gets up, and you saw him getting up. The hart's ring is late enough to leave.

**Stay.** Five on the first night. The Penitent waits for the Deeper Night. No sixth. The notes stay in the keep's voice.

---

## Sheet 143 — The one who does not fight

**See.** A hooded ringer sees you, turns, and runs. A gold ring spreads on the ground. The bell tolls three times. Nothing about that ring is red, and nothing about it hurts. If the third toll lands, the camp beyond wakes and hunts you past its leash. Hit the ringer during the toll and the toll spoils. Up close, the bell is a short clang with a disc.

**Where.** `tollman.gd`. `RING` 2.4 s, three tolls, `TOLL_R` 34. `GOLD` is an HDR colour. Clang tell 0.6, radius 2.3. It rings again 14 s after a finished toll, 4 s after a spoiled one. Two blows kill it. Light-averse. The bell is the weak point, which is the knot rule from sheet 50.

**Change.** The gold ring must not read as a ward or a heal. It is the sound's footprint: dim, on the ground, gone when the toll is spoiled. The teaching is the running away and the bell, then the camp. A blow during the 2.4 s is the interrupt, and the stagger sells it. The clang is a real disc with the red the other discs use (sheet 56), because that one does hit. Do not give the toll a damage number. Its cost is the camp.

**Prove.** Let one finish. The camp comes, and you were not wounded by the ring. Hit one mid-toll. The ring dies, and the camp stays asleep. Stand in the clang. That one hurts, and the disc was red first.

**Stay.** It still does not chase to swing. It calls. No elite tollman. The gold stays under the bloom threshold.

---

## Sheet 144 — Lamps that look like rest

**See.** The three spokes have a warm lamp every twenty-six metres. An unlit brazier wears a pale tongue you can see from across a field, so you can find the bowl. Glimmers dot the ground. Stand under a way-lamp and the gloom still climbs. The picture said you were safe.

**Where.** `realm_wayfinding.gd` places `WayLamp` omnis, energy 1, range 7.5, no shadow, and does not register them with `LightGrid`. They skip a stretch that already has a brazier within 9 m. `unkindled_glow.gd` is a cold additive tongue, hidden once the fire is lit, with no light of its own. `glimmers.gd` scatters small omnis tagged glimmer. Safe light is still only what `LightGrid` knows: fires, mirrors, the player's lantern.

**Change.** A way-lamp stays a way-mark. Dim it until it reads as a coal in a stone, not as a brazier, and keep it off the gloom grid. The unkindled tongue stays cold and blue-pale, clearly not the warm fire it will become, so kindling is a change of colour and not a second flame on top of a flame. Glimmers stay specks. None of these become rest.

**Prove.** Stand under a way-lamp in the dark. The bar climbs. Walk to an unlit bowl you could see. It was cold, and kindling makes it warm. Stand in that fire. The bar falls.

**Stay.** The roads stay readable. Do not delete the lamps to win the pillar. Do not register them as sanctuary. Glow budget unchanged.

---

## Sheet 145 — The name of the place, and the surge

**See.** The first time you enter a region, a carved band gives you the name and a line. Later it is the name alone, shorter. A gloom surge is the same band in violet: a shaft somewhere in the valley, a few minutes to arrive, three waves if you do, and it is gone if you leave or if you are hollowed. It will not start during a boss or during the tide, and not in Hearthward.

**Where.** `discovery_banner.gd` queues region, subzone, and event plates, and waits while the HUD title is up. `world_events.gd`: first surge between 200 and 320 s, then every 420 to 660, `CALL_FOR` 180, arrive inside 15 m, leave past 46 m, three waves, 24 ash. The shaft is a beacon-style column. The tide is sheet 110.

**Change.** The carved name waits until the opening pile (sheet 4) is done, then it is the one line. A surge uses that same plate and does not also toast and also banner in the text director. One call. The shaft is the place. Leaving past 46 m on a gallop is very fast. The lose radius should be the site you walked away from, not a three-second sprint, or a horse crossing the edge should not fail a surge you are still fighting. Hollowing still fails it. That is the death.

**Prove.** Enter the fen the first time, after the cover has gone. One carved name. A surge calls. You can see the shaft and the plate agrees. Ride through the edge of it and back. It is still yours. Ignore one. It fades, and the next is not soon.

**Stay.** No event tracker. No world-quest log. The tide and the surge do not run together, which the code already wants. Keep that.

---

## Sheet 146 — One book, many doors

**See.** Tab or I opens the character screen. It has four tabs: Wanderer, Kindling, Pack, Journal. Inside them are gear, charms, relics, the staff, embers, spells, loadout, oaths, paths, the hearth, the bag, Wenna, stories, writings, places, the map, and the tasks. Q and E change pages. O, K, J, and L jump. Esc closes. A fire that used to open the Kindling now opens this, at that page. Closing clears the pause, which sheet 82 already requires.

**Where.** `ui/character_screen.gd` `TABS`. Hosted panels hide their own strips. The old keys still open their page. `growth.gd` is still the Kindling body. `codex.gd` is still the journal body. The screen owns the mouse and the pause.

**Change.** The four tabs are the navigation, and the old letters may keep working, but the hint line shows one way: the bumps for tabs, the shoulders for pages, Esc to leave. Do not print O, K, J, L, Tab, and I as if they were six different books. A page you were not sent to opens on its first child, not on a stale hosted page from an hour ago. The map inside the journal is sheet 126. The hearth page is sheet 137. Gear leads with the verb (sheet 112).

**Prove.** Press I. You are in the book, paused, and the hint names the bumps and Esc. Press K. You are on the Kindling. Close. The night was paused and now is not. Open from a lit fire's old path. You land on the hearth page, not on a spell you looked at last night.

**Stay.** One screen. Do not split it back into five menus. No fifth tab.

---

## Sheet 147 — The coal

**See.** Some tasks put a coal in your hands and a place it has to reach. It burns down in real time. Menus pause it, which is right. A hollow puts it out, and the task steps back so you can take another from the fire. There is no coal in the hand while this is true. The toast is the whole object.

**Where.** `quest_runner.gd`. Kind `carry`, `left` counted down in `_process`, and `_on_hollowed` gutters it with "went out with you," then `advance` to the previous step. The comment says the coal is from the step before, and the lost line can name the green's fire.

**Change.** While a coal is live, the hand that is not the staff holds a coal, a small warm mesh, and the gloom bar is not asked to explain it. The toast on gutter stays. If the timer is the tension, the coal's light dims as `left` falls, so the last seconds are visible before the line. A hollow still guts it. Do not let the timer run under a pause.

**Prove.** Take the coal. You can see it. Open the book. It does not burn while you read. Come out. It is dimmer than when you left only by the time you were walking. Die. The line says it went out, and the hand is empty. Fetch another. The task allows it.

**Stay.** One coal. No inventory slot for it. No second timer on the HUD. The fire it came from is the fire in the task, not a new one.

These sixteen were the gap: travel, death, the bells, the work the village gives you, the fire on the green, the loot, the secrets, the crypt, the champions, the lamps, the names, the book, and the coal. Part IX is what was still walking around underneath them.

---

# Part IX — The light in the hand, and the night around it

## Sheet 148 — The lantern is a picture

**See.** The left hand carries a horn lantern. It throws a warm pool about eight metres across, and the pool flickers. Stand in a field inside that pool and the gloom bar still climbs. Hollowed things walk through the light as if it were not there. The only lantern that the night believes is the one you plant with the ward spell, and that one lasts seven seconds.

**Where.** `wanderer_lantern.gd` builds `LanternLight` at energy 1.85, range 8, shadows off. `character_rig.gd` swings it and adds a little sine to the energy. `light_policy.gd` may widen that class further. `LightGrid.drain_at` only knows registered zones. The held lantern is never registered. `player_vitals.gd` treats drain 0 as dark, a negative drain as a fire, and a positive drain as a ward. `lantern_ward.gd` is the positive one: radius 7, 4 gloom a second, at most 25 a cast, not a rest, and bosses walk through it.

**Change.** The horn stays in the hand. Pull its range and energy down until it reads as light for the sleeve and the ground at your feet, not as a brazier you are carrying. Do not register it. A personal sanctuary in the open would retire the clock. The ward remains the lantern the valley counts, short, capped, and not a camp. Sheet 144's way-lamps are the same lie at a larger scale. This one is on the body.

**Prove.** Stand in the dark and look at your hand. You can see. The bar climbs. Plant a ward. The bar falls, then the ward ends and the bar climbs again. A wretch does not shy from the horn. It does shy from a fire.

**Stay.** No player-lantern shadows. The left hand stays the lantern, including while sheet 147's coal is a second thing that must leave when the coal does. The robe, the void face, and the staff in the right hand stay.

---

## Sheet 149 — Wounds

**See.** The plate on the screen is not gloom. Gloom is the other bar. This one is how hurt you are. About five plain blows fill it, and a full plate hollows you. A kill mends a little. A long fall bruises and is not allowed to hollow you by itself. A fire mends faster if you have sworn for that or bought the bellows. The robe looks the same at one wound and at the last.

**Where.** `wounds_max` is 120. `add_wounds` hollows at the cap. `take_wound` is the blow, with the grace and the guard. `mend` closes some on a kill, on spent Resonance, and on a few oaths. Falls are capped in `player_vitals.gd` so a drop cannot finish you alone. `unit_frames.gd` draws the plate as `wounds_max - wounds`. `CharacterRig` does not read wounds. Sheet 47 is the gloom the cloth ignores. This is the same absence for blood.

**Change.** The plate stays the plate. The hem and the sleeve take a second, quieter dark as the plate empties, the way sheet 47 asks the cloth to know the gloom, and the two must not be the same colour. A mend at a fire eases that dark back. A hollow still clears both. Do not add a third bar.

**Prove.** Take two blows. The plate drops and the cloth frays. Stand in a fire. Both recover, and you can tell which is gloom and which is the wound. Fall from a roof you can survive. The plate moves. You are not back at the checkpoint.

**Stay.** Five blows is still the neighbourhood of a life. Lava still hollows. The fall cap stays.

---

## Sheet 150 — Remembrance

**See.** Kills, kindled fires, seals, finished tasks, and a homecoming fill a bar. The bar is memory. When it fills, something comes back: a level, a chime, a column of motes, and a line that you have a step to spend on the Paths. There are three paths. The Hearth holds more gloom and rests longer. The Rift hits harder. The Road moves. You spend the point in the book. You can buy the points back only at the green's fire, and the ash does not return.

**Where.** `paths_db.gd` and `level.gd`. Need is 40 + 8 per level, cap 30. A boss down is an extra point. `hearth.gd` `give_memory` toasts "Remembrance %d" and `_ding` plays `ward_chime.wav` at pitch 1.15. That file is also the mount, the chest, the flight, and the ward. `unremember` is sheet 137.

**Change.** The toast can stay, and it already names the book. The chime should not be the ward's chime. A remembrance is a lower, longer note, once. The path row leads with the verb the node already has ("hold more", "gather slower"), and the percent sits behind it, as with gear. Unremember stays at the green and still says the ash is gone.

**Prove.** Fill a level on a kill. You hear one note that is not the chest and not the horse. Open the Paths. The top step says what it does before it says 6%. Buy the points back at the Landing. It refuses.

**Stay.** Three columns. Memory is not ash. No fourth path. Item level and rested XP stay beside this. They are not this.

---

## Sheet 151 — Oaths

**See.** Three times, the Kindling offers two vows. You pay ash and keep one. Forswearing is free and the ash is gone. The vows are not percents in a vacuum. One makes fires mend you much faster. One mends wounds on a kill. One makes the lance charge faster. One makes the step come back twice as quickly. Nothing on the body shows which one you swore.

**Where.** `upgrade_db.gd` `OATHS`, tiers 1–3, costs 12, 20, 30. `kindling.gd` `why_not_oath` and the swear. Forswear erases the key and does not refund. The effects land in the mods table the skills already read.

**Change.** Before the second press that forswears, the line says the ash does not come back. The sworn vow is a mark you can see: a notch on the staff, or one word under the plate, not a buff icon. The other vow of that tier stays visible in the book as the one you did not take, so a later visit knows it was a choice. Do not add a fourth tier.

**Prove.** Swear the Hearth at a fire. Fires mend faster, and you can point at the mark. Forswear. The confirm says the ash is gone. The mark is gone. The other vow is still offered, and it costs ash again.

**Stay.** One vow per tier. No respec that returns the ash. The words of the vows stay.

---

## Sheet 152 — Raise, reforge, salvage

**See.** At a kindled fire the gear page offers Raise, Reforge, and Salvage. Away from a fire you can still wear and still salvage, and salvage asks twice. Raise spends ash and ember shards and adds a level, up to a cap by rarity. Reforge spends shards, and a fragment on the better pieces, and rerolls one affix. The error when you are short of shards tells you to salvage. The slice hides the three buttons. The full night is the default, so they are on.

**Where.** `gear_panel.gd` keys U, Y, X. `Slice.full()` hides them. `gear_runtime.gd` `upgrade`, `reforge`, `salvage`. `gear_db.gd`: raise cost `4 + 4*(level+1) + 3*rarity` ash and `(level+1)*(1+rarity)` shards. Salvage returns 1, 2, 4, 7, or 12 shards plus the level. Worn pieces with an empty affix list cannot be reforged. A fire is required for raise and reforge. Salvage is not.

**Change.** The second press on salvage names the shards you will get, then does it. Raise shows the new level on the piece's name in the same moment, not only in a percent downstream. Reforge shows the affix that left and the one that arrived, one line, the verb first. The "salvage for shards" line can stay. It is the teacher. Do not enable raise in a field.

**Prove.** Raise a piece at the Stair-foot fire. The name's level ticks. Walk away and press U. It refuses. Salvage a spare. The first press names the shards. The second pays them. Reforge one affix. You can say which line changed.

**Stay.** The slice still hides the buttons. No fifth slot. No durability. Item level stays.

---

## Sheet 153 — Four spells the night teaches

**See.** You start with the bolt. The other four slots are empty. Talk to the keep and the ward arrives. Kill something and the lance arrives. Break a seal and the step arrives. Drop a great one and the nova arrives. Each of those is a toast that names a key. Press an empty slot before that and it says it has not been taught.

**Where.** `upgrade_db.gd` `TAUGHT_LATER`: lance, nova, ward, step. `kindling.gd` teaches ward from the keep's line, lance on the first kill, step on `seal_broken`, nova on the first great one. `TEACH_LINES` are the four sentences. `skill_sealed.gd` returns "Not yet taught." An old save with no `taught` key is treated as knowing all four.

**Change.** The toast stays one line, and it waits until the kill's own banner has left, so the teaching is not under the death. The slot that was empty shows its glyph and holds the name the way the hotbar already holds a name, then lets it fade. Pressing a sealed slot shakes that slot. It does not also toast over whatever else is on screen. A fresh night is the only night that is missing them. Do not teach a fifth spell for ash before the night has given these.

**Prove.** A new slot-one night. The keep, one kill, one seal, one great one. Four arrivals, each after its moment, each on its own slot. Press the empty one before the keep. The slot refuses, and the screen does not grow a second headline.

**Stay.** The bolt remains the start. Ranking a taught spell at the Kindling stays. The slice does not remove the four.

---

## Sheet 154 — A camp comes back

**See.** You clear a pack on the road. You walk a short way, turn around, and they are there again. A lit fire on the spot holds them off. Stand on the spot and they wait. Leave, and ten seconds is enough.

**Where.** `enemy_spawner.gd`. `RESPAWN` is 10 s, times `ReachState.respawn_mult` (a rung bell's country is three times that, so thirty seconds). `KEEP_CLEAR` is 7 m. A lit cell retries in 1.5 s instead of spawning. Seal camps are the same timer, and a seal's progress is the kills, not the timer. A pawn that is still alive is not doubled.

**Change.** A cleared roaming slot stays down long enough to leave and come back on foot, on the order of a minute and a half, and the bell's multiplier still applies on top. The lit-fire hold stays. The 7 m hold stays. Seal camps may stay short if the seal is the reason you are there. They should not refill under you while you are reading the seal's own toast. Ten seconds is why a road never feels cleared.

**Prove.** Kill a road pack. Walk to the bend and back inside half a minute. The ground is empty. Wait the longer time away from the spot. They are back, and they were not born at your feet. Kindle nothing. The rule did not require a fire.

**Stay.** Camps stay camps. No leash change from sheet 65. Quiet bells still slow the country. Do not make them stay dead until the Deeper Night. That is the guardians (sheet 141) and the named (sheet 142).

---

## Sheet 155 — Writings

**See.** A waystone, a page, a board. Until you have read it, a small glint sits on it out to about twenty-six metres. The prompt says read it. The page opens on the screen while the night keeps moving. Read it again and the page closes. The first time, it is in the journal. A series that you finish pays once. The glint goes out.

**Where.** `inscription.gd` and `codex.gd` `show_reading`. `CodexStore` is `codex.cfg`, per slot, wiped on a new game of that slot. The reader does not pause. E on the same stone closes it. The foot line offers the journal key. `note_read` pays a finished series through the secrets' loot-once flag.

**Change.** The glint stays the "unread" mark, and it stays under the glow threshold. The reader stays unpaused, same as a secret's panel, and a hit or a few metres of walk closes it, same rule as sheet 139. The series count in the footer is enough. Do not toast the whole text if the panel is up. A new game of the slot starts with a dark journal, which the wipe already does. Do not share one journal across the three slots.

**Prove.** Read a waystone. The glint dies. The page is in the journal under Writings. Walk off. The page closes. Start a new game in that slot. The waystone glints again.

**Stay.** No map pin on every stone. No percentage of writings found. The words stay the words.

---

## Sheet 156 — Oil, a roof, a lamp that goes out

**See.** Grisel sells oil, more oil, slates, and thatch. The oil is supposed to lengthen Fennick's round: more lamps on the bend, the forge, the well. The slates and the thatch are roofs you can stand under. Lamps also burn down over a village night, and Fennick lights them again when his round reaches them. Kindling three valley fires completes the "longer round" by itself, so the oil may never be the thing you bought, and the toast does not say which cause it was.

**Where.** `village_cast.gd` `WARES` and the restore rows. `lamps_more` when is `kindled:3|v:oil`. The shop's oil requires the project not already restored. `village_state.gd` `test` treats `|` as or. `village.gd` burns `fuel` down across `CYCLE` 600 s and `light_lamp` only when Fennick's act is "light", or when the restore first applies. Roofs are overlays: `reed_roof`, `harrow_roof`.

**Change.** The longer round is the oil. Three kindled fires do not set that flag. When the oil is bought, Fennick's next pass lights the new lamps, and the toast can wait until the first of them catches, so you see it. A lamp still burns down. His round still brings it back. That is the life of the village, and it should stay. A roof you paid for is on the house before the toast finishes. None of these village lamps become a gloom sanctuary.

**Prove.** Buy the oil before you have three valley fires. Walk with Fennick. A lamp that was dark is lit, and your gloom still climbs under it. Kindle three fires without the oil. His round is the old round. Pay for the thatch. The Harrows have a roof.

**Stay.** No more building. The village is not a base. Oil does not register with `LightGrid`. Sheet 144 still applies to anything that only looks safe.

---

## Sheet 157 — What the valley is playing

**See.** The meadow, the wood, the fen, the crossing, the summit, the crypt, and the newer countries each have a bed. Walking from one into the next crossfades. Under that, a lyre and a pad: quiet while you explore, warmer when you are by a fire or in the Keg with nothing hunting, darker with a heartbeat when something is close, and one rising phrase when the last of them falls. A great one has a theme in two layers. The high layer comes in on the later phase. The first time you pull one, the theme is not ready yet, and the danger pad covers those seconds.

**Where.** `ambience.gd` beds, fade 2.5 s, regions blended over about 18 m. `scape_music.gd`: danger inside 20 m, rest inside 9 m of a fire or in the tavern under y 6, relief on the way out of danger. `boss_themes.gd` renders on a worker when the fight begins, cached after. Fade in 2.5, out 3.5, holds while the boss is inside 70 m. The Music bus is the slider. People in the village babble on their own clock (`npc_voice.gd`, `villager.gd` `CHATTY`), quieter when they mourn, louder when they sell.

**Change.** The first pull of a great one should not be a different piece from the second. Warm the three themes during the loading cover, the way the voice banks already can prewarm, so the downbeat is there when the fight starts. The danger pad remains the bed for ordinary packs. A babble does not play under a conversation with that person. The crossfade of the beds stays. A door, the Keg's, muffles the outside, which the room bus already wants. Confirm it from sheet 78's doorway.

**Prove.** Walk meadow to fen. The bed changes without a cut. Rest at a fire. The lyre is the warmer one. Pull the Thornwarden the first time in a session. The theme is already playing. Talk to Fennick while he was muttering. Only the conversation is heard.

**Stay.** No recorded score. No combat playlist. The three themes stay the three. Village babble stays babble, not new lines.

---

## Sheet 158 — A wretch that is not the same wretch

**See.** Some of them are scarred, some wear iron, the tide's are violet, the quarry's carry stones, the mere's wear weeds and sunk stones. The Deeper Night cracks them with cold light. If the extra pieces are small, they are the same fight with more life, and the variant was a number.

**Where.** `variants.gd`. Scarred, ironclad, and tideborn come from the tier. Stonebound and drowned are regional and keep the kind's own body, with a tint and added parts. Deeper is the later night. Quadrupeds get the same ideas along the back. Stats change before the body is dressed. The look is sockets and a glow on the flesh.

**Change.** Each variant has one readable mass at the distance you meet them, about twenty metres: the iron across the chest, the stones on the back, the weeds, the violet on the shoulders. The glow stays inside the budget. The name, if a bar appears, can say the variant. The body has to have said it first. A regional variant does not also roll a tier variant on the same pawn. One costume.

**Prove.** Meet a stonebound husk and an ordinary husk in the same hour. You can say which is which before the first blow. A tide pack reads violet against the road. A deeper one, after the bell, reads cold, and it is not the tide's violet.

**Stay.** No new kind. The base moves stay the moves in sheets 56 through 64. Variants are a look and a number on top of a kind that already exists.

---

## Sheet 159 — The stair up to the ring, and the deck at the top

**See.** The Thornwarden's hill is a flight cut into the slope, a gate, then a level floor and the stones. The summit is a mossy deck, a statue, pillars, and the place the ossuary cage arrives. Both are walks, the way the crossing and the crypt are walks. The fight on the ring is sheet 120. The cage is sheet 122.

**Where.** `thorn_henge.gd` builds the terrace and the flight before the ground stamp, so the cut is real. `summit_dress.gd` seats the platform, the mage, and the pillars at runtime, and cuts a lane so the lift jetty is not full of rocks. `LIFT_LANE` is that hole.

**Change.** Walk the flight on foot and on the palfrey. The lips are sheet 18's job, here, one at a time. The horse may refuse the flight. It stops on the near step, still mounted, as on the column (sheet 130). The jetty meets the deck with a floor, not a gap and not a rock. The statue stays a statue. Do not replace it with a person.

**Prove.** Climb to the ring without a surprise slide off the flight. Ride at the flight. You stop at the bottom. Take the cage to the summit. You step off onto stone, and the lane is clear.

**Stay.** The henge mesh stays. The summit pieces stay the pieces already dressed. No gothic rebuild. No fifth stair fire.

---

## Sheet 160 — Rings the tether can hold

**See.** The tether is a line to a ring, then a haul. The nearest ring to the crosshair, inside its reach, is the one. You arrive under it and come up past it. Sheet 27 is the line's feel. This is whether the valley has rings where a haul is the way up.

**Where.** `grapple.gd` searches group `grapple_anchor`, default reach 24 m. `grapple_anchor.gd` is the ring and a faint glow. `realm_pois.gd` and `site_r34.gd` place some, with a shorter reach on the poi ones (18 m) and a stand point. A baked prop can join the group without the script.

**Change.** Every ring you can bite is a ring you can see before you are in the air: the glow is enough at the reach, and it is not a light. The land point is a floor. A haul that ends inside a rock is a bad stand, and that ring moves until the stand is clear. Do not add rings to make the roads optional. A ring is for a face you were not meant to walk: a pit lip, a gallery, a cut. The roads stay walked.

**Prove.** Look at a placed ring from inside its reach. The line takes it, and you arrive on stone. Look at a bare cliff that has no ring. The tether does not invent one. The glow is not a safe light.

**Stay.** No grapple swing. No new anchor type. Sheet 27 still owns the jerk and the ribbon.

---

## Sheet 161 — Water underfoot

**See.** The fen and the mere are a sheet you can walk. The step sounds wet. You do not slow. A horse with the fen pony's wade is the one that was told about water. Everyone else, on foot, is as fast on the pool as on the road. The sheet is thin, and looking up from under it can lose it. That part is sheet 76.

**Where.** `character_rig.gd` sets the surface to water when `in_water` is true, and the footstep is the wet one. `player` movement does not read that flag. `horse.gd` slows unless the breed wades. The sheet sits at y = −0.9.

**Change.** On foot, water is a drag, not a swim. While `in_water`, horizontal speed comes down about a fifth, the wet step stays, and a jump still leaves. You cannot dive. The pony's wade remains the breed that ignores the drag. A horse that does not wade keeps the slow it already has. Do not thicken the sheet into a volume.

**Prove.** Walk off the fen path into the pool. The steps slap, and you are slower. Jump. You leave the water. Ride the fen pony through it. It is not the slow one. Ride the palfrey. It is.

**Stay.** No breath bar for water. No swim stroke. The render fix in sheet 76 stays the render fix.

---

## Sheet 162 — Resonance

**See.** Bolts build a stack. A lance or a nova spends the stack. The lance hits harder for it, the spend closes wounds (sheet 228), and at three or more it gives breath. A crit is a little more likely while you are holding it. Eight seconds and it is gone. If the unit frames are off, none of that has a picture. The staff does not know.

**Where.** `combat_state.gd`. Resonance max 5, duration 8 s, refreshed on a new stack. Spenders are the lance and the nova. The lance takes 10% damage a stack. The nova's ring does not (sheet 229). The spend closes 1.5 wounds a stack (sheet 228), and breath comes back at 3+. Crit base 8%, plus 1% a stack. `unit_frames.gd` has an icon case for it. `CharacterRig` never reads it. Sheet 80 already wants the frame to drop icons that repeat the hotbar. This one does not repeat the hotbar.

**Change.** Five pips on the orb, the gem that already sits over the bolt slot, filling as the stacks do and emptying when they expire or when you spend them. The frame may keep its icon while frames are on. The orb is the tell when they are off. Spending is the flash the orb already knows how to do for a cast. Do not add a counter in the middle of the screen.

**Prove.** Chain the bolt. The orb fills. Wait. It empties, and you can see the last second. Spend it with the lance. The orb empties at once, and the wound plate steps back by 1.5 a stack. Turn the frames off. The orb still fills.

**Stay.** Five stacks. Eight seconds. No new spender. The lance and the nova remain the two that eat it.

The lantern, the wound, the memory, the vow, the forge, the four spells, the camp, the stone you read, the village's own lamps, the beds, the variant, the two climbs, the ring, the water, and the stack on the orb. That is the night's remaining play. The picture's cost is a different list, and it starts at sheet 163.

---

## Part X — The same picture, for less

These sheets are the ones that may change a mesh or a texture import. Every one of them has to come out the same on screen, or cleaner, and it has to cost the same frame or a cheaper one. A denser rock, a fourth material, a bigger map, a new light, and a retopology of the wanderer are not in this part. The glow stays at intensity 0.62, bloom 0.06, threshold 1.15, levels 0 and 1. The internal height stays 960. The moon atlas stays 1024. Nothing here is a reason to rebake `world/main.tscn`.

Counted 6 November from the glTF accessors and the `.import` files, not from a guess at the frame. Grunt and boss source PNGs are larger than the size the importer already keeps. The numbers below are the ones the night can actually pay.

---

## Sheet 163 — The summit is two rocks, copied until they filled the budget

**See.** The deck at the top is moss, cobble, and a rail. It reads as one place. It is not one mesh. It is a pile of unique copies of the same stones, and it is the heaviest model in the project.

**Where.** `art/models/mossy_platform.glb`, seated by `summit_dress.gd` (`PLATFORM`). 879,461 triangles, 502,280 vertices, 112 meshes, 3 materials (`CobbleDais`, `CathedralMoss`, `CathedralStone`), 4 images. Grouped by name: moss rocks 661,453 triangles, the `low` copies 189,912, `StoneRail` 13,124, `CobbleDais` 6,976, and the rest under 3,000 each. That is about eighty-two copies of an 8,000-triangle moss rock and about nineteen copies of a 9,826-triangle rock, each stored as its own mesh. The file is 21.7 MB. The moss albedo and normal are the same bytes as `art/textures/import/rock_moss_diff.jpg` and `rock_moss_nor.jpg`, and the same bytes again beside `summit_pillar.glb`.

**Change.** Keep the two rock meshes, the rail, the dais, the three materials, and the moss maps. Instance the rocks. One moss rock and one `low` rock, placed where the copies already sit, is the same deck at roughly thirty thousand triangles instead of eight hundred and eighty thousand. Hidden faces on the underside of a rock that never sees the camera can go. Do not sculpt a new stone. Do not add a material. The collision path already simplifies this mesh (`GenCache.convex_shape`); the picture is the part that stayed dense.

**Prove.** Stand on the deck and walk the rim, the same walk as sheet 159. The silhouette, the moss, and the rail match a still from before the swap. `zz/perf_tour.tscn` on the summit side of the stress set does not go up. Primitive count for this one node drops by an order of magnitude. The 3% gate in sheet 72 still applies, because this node is large enough that a bad swap would show.

**Stay.** Same platform. Same textures. No gothic kit. No extra scatter. Sheet 159 still owns the walk, the statue, and the lift lane.

**Band.** A, because this one file is a large share of the 1.5 M primitive budget by itself.

---

## Sheet 164 — The two pillars are the same file, twice

**See.** Two stone pillars stand on the mid terrace. They are the same pillar.

**Where.** `summit_pillar.glb`, two instances in `summit_dress.gd` at (±7.2, 2.05, −6.8), scale 0.85. Each file is 66,721 triangles across 9 meshes: one `low` at 25,826 and four moss rocks at about 8,000 each. Two materials, the same moss images as the platform. Two of them is about 133,000 triangles of unique rock that the platform already paid for.

**Change.** The pillar uses the same two rock meshes as sheet 163, plus its own stone shaft if that shaft is actually a different shape. Two instances of one cleaned pillar, not two copies of four unique rocks. If the shaft is the only new shape, the rocks are the platform's rocks.

**Prove.** From the deck, both pillars match the still. Draw count for the pair falls. Nothing else on the terrace moves.

**Stay.** Two pillars, not a ring of them. Do not replace them with `gothic_bay.glb`.

**Band.** B.

---

## Sheet 165 — One boss, many surfaces

**See.** A great one is one body. The file is a body split into a head, a chest, and a limb per bone.

**Where.** `enemy_body.gd` loads the three glbs. Triangles, from the accessors: Thornwarden 89,918 across 16 meshes (body 46,593, head 8,626, four legs split foot/knee/hip, tail 1,342). Bone Abbot 89,967 across 16 (chest 29,850, head 19,778, a second right hand at 13,090). Ascended Warden 89,984 across 9 (head 28,964, chest 14,086). No images inside the glbs. The maps live in `art/textures/` and the importer already caps albedo, normal, and ORM at 2048, and the emit maps at 1024. Source PNGs are 4096. The night never uploads the 4096.

**Change.** Surfaces that share one material and one skeleton become one surface. The pose does not change. The triangle count does not go up. Interior faces that cannot catch the camera, if a pass finds them, come off. The emit maps can follow the grunt emit cap (512) after one close still of each rune: they are masks, and most of the 4096 source is empty. Do not author a new 4k map. Do not add a material to "read better." A boss at this internal height is a few hundred pixels tall even in a close fight. 2048 is already finer than that frame. The next cut, 2048 down to 1024, lands only when a face still of each boss matches.

**Prove.** Pull each boss. The silhouette and the runes match. The surface count on the skinned mesh drops. A frame capture at the pull does not add a hitch from a new shader. Sheet 72's gate on the boss rooms.

**Stay.** Do not resculpt them. Do not give them a second costume. Variant glow stays inside the budget in sheet 158.

**Band.** B.

---

## Sheet 166 — The grunts are already at the right map size

**See.** A wretch is one skinned body. Up close it is still small in a 960-tall picture.

**Where.** `grunt_model.gd` dresses one glb per kind when the albedo exists. Ten kinds, about 18,000 to 26,000 triangles, one mesh, textures outside the file. Every grunt albedo, normal, and ORM import has `process/size_limit=1024`. Emit maps are capped at 512. The source PNGs are 2048 and about 5 MB each on disk. That disk size is not the VRAM size.

**Change.** Leave the limits. Do not raise them for a sharper wretch: at this height a grunt is well under two hundred pixels, and 1024 is already more than the screen can show. Do not add triangles to the body. A model improvement on a grunt, if one is ever done, is a smoothing group or a shared material, and it has to come in under the current triangle count. The procedural `CreatureMesh` path stays the fallback when a map is missing.

**Prove.** Any grunt still, before and after a later material tweak, matches. The import limit lines stay at 1024 and 512.

**Stay.** No new grunt mesh. No batching system. The old `wretch_head.glb` and `husk_head.glb` are named only by `core/debug/boot_diag.gd`. They are not the live body.

**Band.** D, as a hold. The work is to not undo a cap that is already right.

---

## Sheet 167 — Roughness and occlusion that never became GPU textures

**See.** Bark, the robe, and the tavern walls look as they look. Under that, the masks are full uncompressed images in RAM, while the colour maps beside them are already compressed for the GPU.

**Where.** `compress/mode=0` and `vram_texture` false, so they stay in RAM:

- `bark_rough.png` and `bark_giant_rough.png` are sampled, triplanar, on the trees, and they stay uncompressed. `bark_ao.png` and `bark_giant_ao.png` are still dependencies of those materials, but `SurfaceDetail.apply()` in `atmosphere.gd` sets `ao_enabled` false and clears `ao_texture` before the first picture. The occlusion maps are loaded and then unused. Do not turn that occlusion back on to justify the file.
- `robe_rough.png`, 1024, on the wanderer, who is in every frame.
- The tavern set: `tavern_beam`, `tavern_iron`, `tavern_plaster`, `tavern_slate`, `tavern_stone`, `tavern_wood`, each with an `_ao` and a `_rough` at 1024.
- The dwarf set in `art/textures/`: beard, cloth, leather, skin, each `_ao` and `_rough`. `lore_kit.gd` loads `dwarf_cloth_albedo.png` for cloth. Skin albedo is 512. The colour and normal maps of this set are GPU textures. The masks are not.

A 1024 RGBA image uncompressed is four megabytes before mips. The colour maps next to them are already `compress/mode=2`. Grunt and boss maps are already mode 2. This list is the hole.

**Change.** Drop the occlusion ext_resources from `bark.tres` and `bark_giant.tres`. The picture already has that pass off. Set the roughness maps that are still sampled, and the robe, tavern, and dwarf masks, to `compress/mode=2`, the way `bark_albedo.png` and `robe_albedo.png` already are. Roughness is one channel. The close-up of bark, of the robe hem, and of a tavern beam has to match a still. If a still shows a block in the roughness, that one map stays uncompressed and the others still move. Do not pack a new atlas and do not repaint them. Do not re-enable occlusion.

**Prove.** The tavern room and a stand of trees, the two places sheet 72 already times (`r_tavern_in`, and the meadow where the trunks are). Frame time does not rise. A still of the robe hem matches.

**Stay.** Do not retopologise the robe to celebrate the smaller map. `robe_torso.glb` stays 26,260 triangles and five materials. Sheet 2 still forbids rewriting the wanderer.

**Band.** A for the robe and the bark, because they are on screen for the whole night. B for the tavern masks.

---

## Sheet 168 — Maps with no smaller versions

**See.** A beam down the length of the Keg, and cloth on a cottage, shimmer when they get small. The full map is what the GPU keeps reading.

**Where.** `mipmaps/generate=false` on maps that are actually sampled in the world, not on UI:

- Every tavern albedo and normal listed in sheet 167, plus their masks.
- `dwarf_beard`, `dwarf_cloth`, `dwarf_leather`, `dwarf_skin` albedo and normal, and their masks.
- `robe_rough.png`.
- `bark_giant_ao.png` and `bark_giant_rough.png`.
- `moss_hang.png` and `branch_card.png`.

`bark_albedo`, `bark_normal`, `bark_rough`, `leaves_card`, `grass_card`, and the land array already generate mips. `land_albedo.png` is 1024×9216, nine stacked layers, `compress/mode=2`, mips on. That array is the ground. It is not a candidate for a shrink.

**Change.** Turn mip generation on for the tavern, dwarf, robe roughness, and giant-bark masks. Up close, mip 0 is the same picture. Farther off, the shimmer goes and the sample gets cheaper. `branch_card.png` and `moss_hang.png` are alpha cards. Mips on an alpha card can halo. Those two wait for one still of a branch against the sky. If the edge fringes, they stay as they are. Do not flip them in the same pass as the tavern.

**Prove.** Look down the Keg. The beams stay sharp at the near end and stop crawling at the far end. A cottage cloth at thirty metres matches a still more cleanly, not more softly in a way you can name. Frame time on `r_tavern_in` does not rise.

**Stay.** No new tavern material. The foliage atlas stays the atlas. Sheet 74 still owns grass distance.

**Band.** B.

---

## Sheet 169 — Files the night does not load

**See.** Nothing. These do not appear in the valley. They still sit in `art/models/`, and Godot still imports them.

**Where.** No gameplay script loads them:

- `dwarf_patron_a.glb`, `dwarf_patron_b.glb`, `dwarf_patron_c.glb`, `dwarf_bartender.glb`. About 5,000 triangles each and 4.7 MB each, because each embeds fifteen images. The tavern dwarves are built by `dwarf_mesh.gd`. The PNGs extracted beside the glbs are byte-identical to `art/textures/dwarf_*` and `tavern_iron_*`, and their imports are uncompressed with no mips. Five copies of each beard, cloth, skin, leather, and iron map.
- `gothic_bay.glb`, 92,485 triangles, 4.7 MB. Rejected as a level mesh.
- `toad.glb`, 13,136 triangles. The toadstool in the world is `mushroom_mesh.gd`, not this file.
- `wretch_head.glb` and `husk_head.glb`, named only by the boot diagnostic.

The moss JPEGs extracted beside `mossy_platform.glb` and `summit_pillar.glb` are a third and fourth copy of the same two files in `art/textures/import/`. The glb is what the summit loads. The loose copies are not a second look.

**Change.** Leave the bytes in the tree. Do not put the dwarf glbs, `gothic_bay.glb`, or `toad.glb` on a load path. Point the summit materials at one moss albedo and one moss normal, and stop importing the duplicate extracts as their own uncompressed textures. A `.gdignore` on the unreferenced glbs and their sidecar PNGs keeps the editor from importing sixty textures the night never samples. Do not delete the files. `docs/POLISH_PLAN.md` already says the unused set stays in the tree.

**Prove.** A night still builds. The tavern dwarves still render. A search of `res://` loads finds no new reference to those glbs. Import time and the loose texture count drop. Frame time is unchanged, because these were not in the frame.

**Stay.** `gothic_bay.glb` does not become a hall. `toad.glb` does not become a level mesh. The procedural dwarves stay the dwarves.

**Band.** D.

---

## Sheet 170 — What "better models" must not mean

**See.** The temptation, once a budget appears, is to spend it on detail. These sheets exist so that budget is not spent.

**Where.** Locked, and already listed in sheet 2 and in `.cursor/rules/umbral-constraints.mdc`: the wanderer's robe pieces and the void face, the shade, the staff in `hand_r`, gothic as lights only, the glow numbers, far depth of field off, the player lantern's shadows off, four stair fires, no headless rebake of `world/main.tscn`. The moon is atlas 1024, bias 0.06, normal bias 2.5, 30 m, two splits. A 2048 atlas and a soft filter were already measured and rejected. Small props are already cheap: a menhir is 828 triangles, a cairn 540, a stair step 140, `rock_a` and `rock_b` 80. Adding geometry to those is a spend.

**Change.** A model change in this part is a deleted unseen face, a welded surface, or an instanced copy. A texture change is a smaller upload of a map the camera cannot tell apart, or a mip chain on a map that was sampling its full size from across a room. If a still is different in a way you can point at, the change waits. Sheet 72 remains the clock: about 3% on `r_spawn_west`, `r_meadow`, and `r_tavern_in`, stress, Cinematic.

**Prove.** The stills match. The tour does not regress. No new autoload, no new shader on the robe, no new light.

**Stay.** This whole part.

**Band.** A, as a gate on 163 through 169.

The deck is the one that matters. Two rocks, instanced, are the same summit. The robe's roughness map and the bark roughness are the ones the night samples on every frame and still keeps in RAM. The bark occlusion maps are loaded and then switched off. Everything else on this list is the same kind of cut: fewer unique copies, a mip the camera was already owed, a file that was never on screen. None of it is a reason to add a triangle.

---

## Part XI — Walks that were only a name, and draws that repeat

The night already has sheets for camps, elites, and the tollman. These are the bodies that still only had a script: the named rares, the graves in the Waiting Field, the two who never take a melee token, and the three caskets in the Abbot's count. The other half is cost. Each of these draws is a picture you already have, painted again.

---

## Sheet 171 — The pin, and the ring the body will not enter

**See.** The map marks a named hollowed: Gutterwick, Mother Sallow, the Last Pilgrim, the bell keepers, and the rest of that table. You walk to the pin. Nothing is standing on it. You wait. It still does not come. Walk out and come back through the middle distance and it is there, silver, on its beat.

**Where.** `rares.gd`. A body is spawned only when you are between 30 m and 95 m of its haunt (`NEAR` 95, and `d > 30`). Inside 30 m the tick refuses. The marker stays in `map_marker` the whole time, and it hides only after a kill, for `RESPAWN` 480 s. Past 130 m from both the haunt and the body, the body is freed whole, not killed, and can return. A lit haunt is skipped, which is right: a fire is not where a rare walks. The silver omni on the body is range 3.2, energy 0.7, shadows off, and it is not in `LightGrid`.

**Change.** The pin means a body you can meet. Spawning inside the 30 m hole, including while you stand on the haunt, is the same spawn the band already uses. The 95 m wake and the 130 m fade stay. A lit haunt still has no body, and then the pin is hidden too, so a fire does not advertise a fight that the light forbids. The shimmer stays a marker, not a safe light.

**Prove.** Ride to a pin and stop on it. The named body is there, or the pin is gone because the ground is lit. Kill it. The pin leaves. Come back before eight minutes. It is still gone. After that, it can return, and standing on the haunt does not keep it in the dark.

**Stay.** No new rare. The 480 s and the heal-on-leaving-the-valley stay. Do not register the shimmer with `LightGrid`.

**Band.** A. The pin is a promise the spawn band breaks.

---

## Sheet 172 — What the merchant pays

**See.** Grisel and the Keg take grave ash for wares, and they buy what you are not wearing. The sell list opens on the cheapest piece. A named piece leaves for a few ash. The ninth thing you sell falls off a shelf of eight, with no second ask. An ember shard, which the fire charged you six ash to smelt, sells back for one.

**Where.** `ui/shop.gd` tabs Wares, Sell, Buy back. `vendor.gd` `sell_rows` sorts rarity ascending. The comment above that sort says best first. `loot_db.gd`: a piece pays `2 + 3 * rarity + level`, plus 4 if it is named. `BUYBACK_CAP` is 8. `SELL_ITEM` pays 1 for an ember shard, 5 for a relic fragment, 1 for an ash-bloom, 2 for grave-iron. `hearth_db.gd` `SMELT` is 6 ash for one shard. The shop's own fragment is 14. Salvage, sheet 152, asks twice. Sell does not.

**Change.** The list leads with the piece you would miss: higher rarity, then a name, then level. A named piece, or a rarity of 2 or more, asks once, the way salvage already asks. The buyback row says when the shelf is full and the next sale will drop the oldest. A material sells for less than the night charged to make it or to buy it, and the row says that number. It may still sell. The price table stays. Buyback stays eight.

**Prove.** Open Sell with a grey piece and a named one. The named one is first. Confirm it. It is on Buy back at the same ash. Sell eight more. The row told you the first would leave. Sell a shard. The row says it cost 6 and pays 1.

**Stay.** No new currency. Worn gear still cannot be sold. The slice can keep hiding the forge buttons. This shelf is the full night's merchant, and it already pauses.

**Band.** B.

---

## Sheet 173 — Graves that stand up after you have gone past

**See.** The Waiting Field is stones, and some of the stones are people lying in them, bowed toward the mountain, a candle on the breast. Walk in and the ground heaves and they climb out. On a horse at a gallop the heave finishes behind you. They were a picture, and then they were a fight you are no longer looking at.

**Where.** `pilgrim.gd`. Dormant until `RISE_R` 6.5 m, or a hit, or a packmate's call (`alerted` rises a sleeper). The climb is `RISE_T` 1.15 s, and it does not swing during that. Sunk depth 1.3 m. The candle is a mesh and a rim colour. It is not an omni, and it is not a safe light. A gallop is 11 m/s (sheet 103). At that speed 6.5 m is about half a second, and the climb takes longer than the pass.

**Change.** The heave starts far enough that a gallop still has the body in front of the camera while it climbs: about 14 m, which is one second of that gallop plus the climb you already have. The climb stays 1.15 s and still does not swing. A grave you have already left, beyond the new radius, does not get a free rise from a packmate you never touched. Hit one and that one rises. The candle stays a candle.

**Prove.** Ride the palfrey through the field. You see the ground move before the body is beside the horse. Stop and let one finish. It stands and it can swing. Ride past without stopping. The ones behind you stay in the ground.

**Stay.** No new grave kind. Do not give the candle a light. The hood and the rope stay the costume they are.

**Band.** B.

---

## Sheet 174 — The one that runs through you, and the one that leaves

**See.** A gaunt does not wait in the ring. It walks your off-side, drops, and a lane paints through you. Then it runs the lane. A quiller stays back and draws a rib, and a long red thread shows where the shard will go. Step into either of them and the quiller simply jumps away. That jump has a puff of dust and no thread.

**Where.** `gaunt.gd`. Own token pool `dart`, so it does not take a husk's turn. Tell `DART_TELL` 0.55 s, then `DART_SPEED` 11.5 along a lane of half-width 0.7, so the paint is 1.4 across. A hit during the tell breaks it. The run does not break. The rake itself is a circle; sheet 215. `quiller.gd` extends the spitter. The throw is `DRAW` 0.85 s, a lane of half-width 0.42 and `LANE_LEN` 17 m, and a blow on the draw spoils it. The landing adds a pad; sheet 214. Inside 4 m, `_spring_back` calls `launch_at` for `HOP_BACK` 5.5 m. Dust, a flee voice, no zone.

**Change.** The dart's lane is already the right tell. Leave its width and its 0.55 s. The quiller's escape is the move you meet when you do the thing the throw asked for, which is to step in. That spring gets the same kind of thread as the throw, short, along the jump, painted before the body leaves. The throw's thread stays a thread. Do not widen it into a road.

**Prove.** Let a gaunt stalk. The lane is on the ground before the body moves, and a bolt in that half-second stops it. Close on a quiller. A short lane shows the jump, and then it is gone. Stand in the throw's thread. The shard comes down all of it.

**Stay.** No new attack. The gaunt still does not queue for a melee token. The quiller's skull stays the knot.

**Band.** B.

---

## Sheet 175 — The count, and the three caskets

**See.** The Abbot sinks into the mound and the line says to break three Tallies. They stand in the chapels. A thread of grave-light runs from each to the mound. Waves climb out while you do it. Leave a casket up and, when he rises, it has been feeding him.

**Where.** `bone_abbot.gd`. Intermission at 66%, `INTER_TIME` 45 s, 35 s if you are attuned. `TALLY_HEAL` is 6% of his pool for each casket still standing, then clamped with `minf` to `max_hp * INTER_AT`, which is the same 66% line he just crossed. He is untouchable in the mound, so his pool is already on that line, and the add is clamped back off the bar. The toast still says he was fed. Breaking all three ends the count early. `tally_reliquary.gd` does not move and does not strike. It has an omni, range 5, energy 1.2, shadows off, and a thin beam to the mound. The omni is not in `LightGrid`. The transition line already names the three.

**Change.** The 6% has to land on the bar. The clamp is his full pool, not the 66% line that only decided when the count began. Three standing caskets are 18%, and the toast and the bar agree. The thread is the instruction, and it has to read from the mound to the chapel that still stands. A broken one goes dark, beam and omni together. The omni is a marker on a casket, dim enough that it is not a place you go to feel safe. Gloom still ticks in it, the way it ticks in a way-lamp (sheet 144). The 45 s and the early end stay.

**Prove.** Enter the count. Three threads. Break one. That thread is gone and the cast still shows the time. Break the other two. He rises, the toast says unfed, and the bar is where he sank. Leave all three. He rises, the toast says fed by 3, and the bar is 18% higher than the line he sank from.

**Stay.** No fourth casket. No safe pocket in the chapel. Sheet 120 still owns leaving the room.

**Band.** B.

---

## Sheet 176 — The disc redraws the valley every frame

**See.** The minimap is a disc in the corner. It already knows where you are. While you are looking at it, it paints the whole disc again on every frame, and twice a second it walks every spawner, seal, arena, brazier, and beacon in the tree to rebuild a list that has not changed.

**Where.** `ui/minimap.gd` `_process`. If the disc is hidden or the tree is paused it returns. Otherwise it writes the shader centre and calls `queue_redraw()` every frame. `_scan` is 0.5 s, and `_rescan` uses `get_nodes_in_group` across those groups. Sheet 80 already stops the compass doing this while it is invisible. The disc still does it while it is visible.

**Change.** Redraw when the picture would move by a pixel: you moved, the camera yawed, a mark was added or removed, or the range key changed. A still camera and a still body do not repaint. The group walk runs when a mark can have changed (a fire lit, a seal opened, a rare killed, a quest pin), not on a timer that ignores whether anything happened. While the disc is faded, neither runs. The disc looks the same the moment you move.

**Prove.** Stand still with the disc up. It is not redrawing every frame. Turn. It turns. Kindle a fire. The mark changes without waiting on a stale list. Hide it. The group walk stops.

**Stay.** No fog of war. No second map. Sheet 80 still owns the compass and the hotbar.

**Band.** C. It does not add a draw. It stops one.

---

## Sheet 177 — Bars that have no distance

**See.** Every hollowed carries a small plate. In a fight you can read it. Across a field you cannot, and it is still drawn, and it is drawn through the hill, because the bar is told to ignore distance and occlusion.

**Where.** `enemy.gd` `_make_hp_bar` sets `visibility_range_end` to 0 and `ignore_occlusion_culling` true. `_pin_visuals` does it again and raises `extra_cull_margin`, which is why a bar stopped popping off at a door frame. Sleep is 46 m (sheet 63's distance, `sleep_range`). A bar past the fight is a quad the eye is not using. Shadows on the bar are already off.

**Change.** Give the bar an end at the distance a notch is still a notch, about 28 m, with a few metres of margin so it fades instead of popping. Keep occlusion ignored, and keep the extra cull margin. The door-frame bug stays fixed. A body asleep at 46 m no longer sends a plate. A body in front of you at melee range is unchanged.

**Prove.** Fight a wretch. The plate is there. Walk out until it is a speck. It is gone before the body sleeps, and it comes back as you return, without a one-frame missing plate at a lintel.

**Stay.** Do not put the plates on a shared canvas as a new HUD. One quad on the body stays the plate.

**Band.** C.

---

## Sheet 178 — Flowers that keep burning across the valley

**See.** Ash-blooms and grave-iron sit where the gather pass put them. Up close they are a ring of pale flowers or a rusted stone, with a few motes. You only ever see the ones near you. All of them, spent or not aside, keep a particle emitter alive for the whole night, and each one builds its own materials.

**Where.** `gather.gd` lays `BLOOMS` 32 and `IRON` 24. `gather_node.gd` builds the mesh in `_build` and adds `Vfx.emitter` of 10 motes with no visibility range. `ProcMesh.std_mat` and `glow_mat` return a new `StandardMaterial3D` every call, so each node owns its own copy of the same stone, the same petal, the same vein. A spent node hides `_vis`, which is the right switch (sheet 127). A live node on the far side of the fen does not.

**Change.** One stone material, one petal, one vein, shared by every node of that kind. The mote emitter gets a visibility end around 22 m, in line with the distance a bloom is actually a bloom and not a point. Inside that, the picture matches. Past it, the emitter is not simulating. Do not thin the flowers you are standing on. Do not change the 300 s respawn or the five memory.

**Prove.** Gather a bloom at your feet. It still has motes, then it hides, as sheet 127 asks. Stand in the meadow and the fen's nodes are not among the live particle systems. A still of one bloom matches.

**Stay.** No new plant. No tool requirement. The nodes stay off the walked paths, which `gather.gd` already enforces.

**Band.** C.

The pin that will not spawn, the shelf that pays one ash for a six-ash shard, the grave that stands up behind a gallop, the jump with no thread, and the three threads in the crypt. That is the play this part adds. The disc, the plates, and the far motes are the same picture drawn less often. None of these sheets adds a light, a triangle, or a system.

---

## Part XII — A person beside you, and a picture that keeps going

These are walks the night already has a person for, and two draws that continue after there is nothing new to show.

---

## Sheet 179 — Oswin stops, and the stone may be the wrong point

**See.** Oswin walks with you to the forty-first stone. On a horse he falls behind and stands there. Nothing says he has stopped. At the stone he is sent to one point, and the kneel looks at another, about a metre and a half away. If the last half-metre is inside the stone, he never kneels. He also never catches up, because the unseen catch-up only fires when he is more than three metres off.

**Where.** `quest_chains.gd` `ESCORT`: the walk point is (−1.9, 17.4), the stone is (−2.9, 16.4), reach 4.5, `wait_r` 16. `quest_world.gd` follows the player on step 0, and on step 1 sets `follow` to the stair point, then kneels only once he is inside 0.5 m of it. The kneel aim is `_stone3()`, the other point. `villager.gd` `_follow`: speed 1 m/s, 2 m/s when he is more than five metres off, gap 2.6 behind a person and 0.15 behind a point. He waits past 16 m. The pop forward needs four seconds stuck and a distance over `gap + 3`, and both him and the landing must be outside the camera. A gallop is 11 m/s (sheet 103).

**Change.** One point, the stone. He kneels when he has closed to the gap he already stops at, or when he has been stuck against the stone, whichever comes first. The 0.5 m test against a second point goes. When he waits, one line, his, says he is waiting. He does not pop into view. He walks the catch-up he already has once you are still and he is inside the wait radius again.

**Prove.** Ride ahead. He stops, and you hear it. Walk back. He comes. At the stone he puts his hands on that stone, not on the empty ground a metre beside it. A wall in the last step does not leave him shifting forever.

**Stay.** He still will not match a gallop. The choice at the stone, truth or vigil, stays sheeted with the quest's own words. No mount for him.

**Band.** A. The walk can end with him never kneeling.

---

## Sheet 180 — A daily thinks the day is the machine's

**See.** Fennick's ash, Grisel's road, and the other dailies say every night. You hand one in. The village night turns, the cart restocks, and the mark over his head does not. Leave the app open past midnight and the mark returns in the middle of the same walk, with no night between.

**Where.** `quest_book.gd` `today()` is `Time.get_date_string_from_system()`, stored on the quest as `day`. `repeatable` is a daily that is done and whose stored day is not that string. `village.gd` `CYCLE` is 600 s, and `nights` increments when the clock rolls. `village_shop.gd` `_restock` clears `_sold` when `nights` changes. The two clocks are not the same counter. The daily's own text says every night.

**Change.** A daily's day is the village night count, the same integer the cart already uses. Handing it in stamps that night. The next time `nights` advances, the mark may return. The operating system's date is not read. A session that crosses midnight does not refresh the board. A new evening at the green does.

**Prove.** Hand Fennick his ash. Wait out a village night without closing the app. The mark is back, and the cart has restocked too. Set the machine clock across midnight during one village night. The mark stays down.

**Stay.** No calendar UI. The slice still hides dailies. One daily per giver at a time, which the mark pass already enforces.

**Band.** B.

---

## Sheet 181 — The man in the reeds, and a step that can skip him

**See.** Ostrin wants his father's lantern. The fen objective is a search. Walk in and a man is already there, a hole for a face, and two lines speak at once: the narrator, and a banner with his name. If the body cannot be made, the quest does not wait. It toasts the lantern step, as if the fight had happened.

**Where.** `quest_chains.gd` `slow_way`. Step 0 is the search, step 1 is the kill, step 2 is the lantern. `HOLLOW.wake` is 24 m, nine health, a husk. `quest_world.gd` `_wake_hollow` on that distance advances step 0 and narrates, and also calls the quest log's `banner`. If the script will not instantiate, `advance("slow_way", 2)` jumps to the lantern and toasts that step. `advance` always toasts the step it lands on.

**Change.** One voice. The banner is the name, and the narrator does not also speak in the same second (sheet 79). He is in the reeds at a distance you can see on a gallop, the same rule as a camp in sheet 110, so 24 m is the wake only if the body was already standing. A failed wake leaves the step where it is and says the reeds would not give him up. It does not toast the lantern.

**Prove.** Ride the fen road. You see him before you are on him, and one line names him. Kill him. The lantern is the next step. If the body is forced to fail, the objective is still the man, and the toast is not the lantern.

**Stay.** Nine health. He stays a husk. The two endings, truth and mercy, stay the quest's.

**Band.** B.

---

## Sheet 182 — Three beads, and no clock on them

**See.** A bolt leaves a violet bead over a body, up to three. A nova, a lance, a tether spend them. Five seconds after the last bolt they are simply gone. Nothing on the bead says the last second is the last second. The beads are not the health bar, so a bar that ends at a distance (sheet 177) can leave three beads hanging over a body whose plate has already gone.

**Where.** `enemy.gd`. `MARK_MAX` 3, `MARK_LIFE` 5 s, refreshed by `add_mark`. `_refresh_pips` shows one sphere per stack. The spheres are not given the bar's range. The hint at three marks names the nova once. Spenders are the nova, the well, the tether at rank 3, and the shade's last breath. The bolt writes one mark, and the third shot in a chain writes two.

**Change.** The beads fade across the last second, and they hide with the plate. A fresh bolt fills them again, which is the refresh the timer already does. Three stays the cap. The hint stays the one sentence.

**Prove.** Chain the bolt. Three beads. Wait. The last second is visible, then they are gone. Walk out until the plate fades. The beads are gone with it. Spend them with the nova. They empty on the hit.

**Stay.** Five seconds. Three marks. No mark counter on the orb. Resonance is sheet 162, and it is a different stack.

**Band.** C.

---

## Sheet 183 — Numbers that paint through the hill

**See.** A hit throws a number. In a crowd the newest hit is the one you miss, because the pool is full and a new number is dropped. Against the mound, the number for a tally on the far side paints through the stone.

**Where.** `hit_text.gd`. Pool of 24 `Label3D`, life 0.7 s. At 24, `pop` returns without showing. `no_depth_test` is true, so a number is drawn over whatever is between it and the camera. Outline 14, font size 72, pixel size 0.0042. Boss feeds and combo words use the same pool.

**Change.** When the pool is full, the oldest number is the one that yields, so the hit you just landed is the one on screen. Depth test on, so a number behind the mound stays behind the mound. The life, the size, and the cap stay. Do not add a second combat feed.

**Prove.** Hit a pack until the air is full of numbers. The latest hit is among them. Stand so the mound is between you and a tally. Its number does not paint on the near stone. A number in the open air still reads.

**Stay.** No damage log. The cap stays 24. Sheet 70 still owns how loud a swarm is.

**Band.** C. Depth on is fewer pixels. The pool does not grow.

---

## Sheet 184 — The breath arc, after the breath is full

**See.** The arc beside the crosshair shows while you are spending breath, and it fades when you are full. Once it is gone, it is still being painted.

**Where.** `ui/breath_meter.gd` `_process` calls `queue_redraw()` on every frame, after it has already set `visible` false when `_alpha` is under 0.01. The fade rates are 6 up and 1.2 down. Sheet 11 is the winded stumble. This is only the widget.

**Change.** While the arc is hidden and the breath is full and no flash is up, do not redraw. Redraw across the fade, and while it is on screen. A full bar that is invisible is not a picture.

**Prove.** Stand still until the arc is gone. It is not in the redraw. Sprint. It comes back on the same curve. Stop. It leaves, and the redraws stop with it.

**Stay.** The arc stays off the centre. No breath number. Winded colour stays the one sheet 11 already uses.

**Band.** C.

---

## Sheet 185 — The sky waits, and the line does not say how long

**See.** Light the four pylons while the Warden is in the air, or the sky breaks. Do the founder's bell first and the wait is longer. The line says the bell rings in you. It does not say you have been given time. The Abbot's count, sheet 175, does say it comes up short, and that one is ten seconds shorter. This one is fifteen seconds longer, and the emote is the only teacher.

**Where.** `ascended_warden.gd`. `ASCEND_TIME` 60 s. Attuned, the end is 75 s (`+ 15` when `_attuned`). The emote on the pull is "The founder's bell rings in you." Four pylons, stars, a 55-wound break if you are outside a lit ring when the sky goes. The constant is still named `SKY_GLOOM`. Sheet 203 is why that number is on the plate. Lighting all four brings him down early, blinded, the same shape as breaking the Abbot's caskets. `thornwarden.gd` says the song is weak and then takes three quarters instead of half while the speakers live. That one already has the words.

**Change.** The bell line gains the time, in the sentence it already speaks: the sky will hold. Do not change the 15 s. Do not change the 60. The count of pylons he already emotes ("n of 4") stays the progress.

**Prove.** Pull him unattuned. The sky's cast matches 60 s. Pull him attuned. The line says the sky holds, and the cast matches 75 s. Light all four before either end. He comes down, and the break does not land.

**Stay.** No new pylon. Attuning still does not trivialise the gale or the eclipse. Sheet 121 still owns the two raids as raids.

**Band.** C.

Oswin can fail to kneel, a daily can return because the laptop clock moved, and the fen can skip a man and toast his lantern. The beads, the numbers, and the breath arc are pictures that outlive the moment they were for. The Warden's extra fifteen seconds is already in the fight. It is not yet in the sentence.

---

## Part XIII — What a quit keeps, and what a still picture costs

---

## Sheet 186 — The ash a quit erases

**See.** You hollow. The hint says the ash you had not banked is where you fell. You walk back and it is in you again, with no number and no prompt. Quit to the title before you walk back, and continue. The heap is gone, and so is the ash. A second hollow does the same thing on purpose. A quit was not that.

**Where.** `player_vitals.gd` `_drop_ash`. Carried ash is `Travel.count("grave_ash")` minus `_ash_banked`. The count is written down to the banked amount, then `Travel.save_soon()` runs, then a mound is added to the live scene with `amount` set to what was taken out. `ash_mound.gd` says it is not written to the save. Take is automatic inside 1.8 m and 2 m of height. There is no toast of the number. The mound's omni is energy about 0.9, range 3.2, shadows off, and it is not in `LightGrid`. Sheet 133 is the second hollow freeing the previous mound. This is the save that already fired.

**Change.** The save that runs at the drop includes the mound: where it is, and how much. A continue puts the heap back. Taking it clears that record and puts the ash in the bag, and the toast names the number. The light stays a marker, not a rest. A second hollow still frees the old heap, and that loss is what gets saved.

**Prove.** Hollow with ash in the bag. Quit to the title. Continue. The heap is where you fell, and the bag does not already hold it. Walk onto it. The toast says how much came back, and a second continue does not give it again. Hollow twice without walking back. The first heap is gone in the save too.

**Stay.** Unbanked ash still leaves the body. Banking at a fire still keeps it. No new currency.

**Band.** A. A quit is not a death, and it currently spends the ash anyway.

---

## Sheet 187 — The choir sings him whole, and does not

**See.** Two chanters rise at the edge of the floor. The line says the choir sings him whole. His bar does not move. Your bolts do less, and his rites come a little sooner. Kill them and a number says the hymn falters. The first line promised a heal. The fight is a ward.

**Where.** `bone_abbot.gd` `_summon_choir`. Two chanters, `CHOIR_HP` 4, named Choir of the Count. The emote is "The Choir sings him whole." `_tick_choir` sets `_hymn` while any of them live, and refreshes `_shroud_t` to 0.3 s. `enemy.gd` `take_hit` halves damage while that timer is up. The same tick multiplies rite timers by 1.2, which is a fifth sooner, matching the comment. Nothing adds to his health. The pop on the way in is "hymned". The pop on the way out is "the hymn falters".

**Change.** The emote says he is warded while they sing, and that killing them ends it. "Whole" goes, unless a heal is actually added, and it is not. The half and the fifth stay. The two pops stay, and "hymned" can say warded so it matches the emote. The threads that already run from them to him are the picture of the ward.

**Prove.** Let the choir rise. His bar does not step up. A bolt that would stagger a chanter of his size does about half. Kill both. The next bolt is the full one, and the line says the hymn failed. The bar still has not been healed by the song.

**Stay.** Two singers. Four health each. No third. Sheet 175 still owns the caskets.

**Band.** B.

---

## Sheet 188 — The stone is gone while you are standing on it

**See.** In the last phases the floor remembers. A wedge of it shakes, then drops, and the pit throws you back up onto the inner disc. The paint underfoot is a few discs. The wedge is the whole slice. He leaves that slice the moment the shake starts, while the stone is still under you.

**Where.** `oss_hall.gd` `collapse`. `fallen[i]` is set true at the start of the warning, and `floor_under` is false from then. The mesh keeps its collider until the shake tween ends and `_set_solid` turns it off. The warning paint is three pairs of discs, radius 2.6, not the wedge from the inner rim to 18.5 m. `bone_abbot.gd` `_keep_on_floor` runs from phase 3 and, when `floor_under` is false, puts him on the inner disc at once. The catch at `DEEP_Y` calls `teleport` and `add_wounds(18)`. The line is "the dead push you back up". Eighteen wounds can hollow you if the plate was already near full. The throw is a teleport, so a saddle still on you is sheet 132.

**Change.** `floor_under` stays true until the collider goes. He stands the shake with you, and he leaves when the stone leaves. The paint is the wedge, the same shape that will drop, for the warning you already have. The eighteen wounds and the throw stay. The line can name the plate, since gloom is not what moved.

**Prove.** Stand on a wedge when it starts. The stone is still there, he is still on it, and the paint covers the slice you are on. When it goes, you are on the inner disc and the plate stepped. He is on the disc too, not a second earlier. Ride the drop. You are not pulled back into the pit by the horse.

**Stay.** The inner disc never falls. Eight sectors. No new hole. Sheet 76 still owns the lava's version of a throw.

**Band.** A. The tell and the floor disagree for the whole warning.

---

## Sheet 189 — The knots close, and the plate is the quiet part

**See.** The Thornwarden roots. Heart-knots beat in the ring. Burn them before the henge closes. Leave them and he is healed, a number says so, and your plate drops with no word of its own.

**Where.** `thornwarden.gd` `_end_rooting`. `KNOT_TIME` is 55 s. Each knot still up heals him 5% of his pool, capped at full, and calls `take_wound(16 * left)`. The emote is "The henge closes on the knots you left." The pop is the heal number only. Three knots left are 48 wounds, on a plate of 120. Burning all of them reels him and does not cut you.

**Change.** The same pop, or the emote, names the plate as well as the heal. The 5% and the 16 stay. The 55 s stays. A clean burn stays a reel and no cut.

**Prove.** Leave one knot. He gains the 5%, and you can see the 16 on the plate in the same moment. Burn them all. Your plate does not move for the closing, and he reels.

**Stay.** Three knots. No fourth. Sheet 185's bell line is the other raid's sentence. This one already has a sentence. It is short a number.

**Band.** B.

---

## Sheet 190 — An empty canvas, every frame

**See.** Wounds and heals float at your shoulder for about a second. Between fights the canvas is empty. It is still redrawn on every frame the night is unpaused.

**Where.** `ui/combat_text.gd` `_process`. `visible` is set true whenever the tree is not paused. The redraw runs when there are pops or when `visible` is true, which is the whole night. `_draw` returns at once when `_pops` is empty. Life is 1.15 s. Cap is 14. In-world numbers are sheet 183. This is the screen-space layer.

**Change.** Redraw only while a pop is alive, and through the frame it dies. An empty list does not submit the canvas. The cap, the life, and the kinds stay.

**Prove.** Stand in the meadow with no fight. This layer is not redrawing. Take a hit. The red number comes and goes. When it is gone, the redraws stop.

**Stay.** No second combat log. HudPrefs can still hide the layer. Sheet 183 still owns the numbers on the foe.

**Band.** C.

---

## Sheet 191 — The strip along the bottom, while nothing is moving

**See.** The memory strip sits on the bottom edge. It eases when you gain, and for three seconds it shows the number. After that it is a still engraving. It is redrawn every frame anyway.

**Where.** `ui/xp_bar.gd` `_process` calls `queue_redraw()` whenever `_info` is not empty, after the fill has lerped and after `_num_t` has counted down. The read of the hearth is already only twice a second. The strip is 9 pixels tall. Sheet 111 is the rested stretch on this same bar. This is only the redraw.

**Change.** Redraw while the eased fill is still moving, and while the number is up. A settled strip waits for the next gain. The twice-a-second read can stay. It is cheap beside a full-width redraw.

**Prove.** Stand still after a kill's number has faded. The strip is not redrawing. Gain again. It eases, the number shows, and then it rests.

**Stay.** The rested stretch stays. No level number in the middle of the screen. Sheet 111 still owns the sentence.

**Band.** C.

A quit currently spends the ash the mound was holding. The choir's line promises a heal the bar does not show. The crypt floor is marked fallen for the whole warning, so he leaves a stone you are still standing on. The knots cut the plate and only announce his heal. The combat canvas and the memory strip keep painting after they have stopped changing. None of this adds a light or a system.

## Part XIV — sentences, rites, and numbers that keep going

The book of tasks is one runner and sixty-six names. Most of them are a count, a seal, a visit, and a turn-in, and they already move when the world says they do. This part is the places where the sentence, the paint, or the number disagrees with the hit. The birds, the pond, and the flocks already slow down as you leave them. They are named with the plate, so they are not left as if nobody looked.

### 192. What the valley actually keeps

**See.** Finish Edda's tongs and the tongs are on the stone, or by the anvil. Finish the names and the slates are cut in the yard. Finish the keg's thief and a mug sits by the green's fire. Tell Ostrin the truth and his father's lantern burns on the counter; show him mercy and it sits cold. Send Oswin home and his staff is left on the road. Those five are in the world.

**Where.** `core/story/quest_world.gd` `_sync_props` builds a prop for `edda_tongs`, `names_yard`, `keg_thief`, `slow_way`, and `forty_first` when the pick is `truth`. The other outcomes are the sentence in the journal. Four of those sentences name a thing and a place. One Loaf: the loaf by the green's fire, inside a chalk circle. The Drowned Bell: the tongue hung over the Keg's door. Mother's Order: the warm tongue in the chimney. What the Oaks Keep: the thorn buried face down by Wyck's fire. Nothing in `_sync_props` builds them.

**Change.** Those four get a prop on the same path as the mug, at the place the sentence already names, or the sentence stops naming a spot you can walk to and look at. The rest of the book stays journal lines. A count of hollowed does not need a trophy in the road.

**Prove.** Lay the loaf quest to rest and look by the green's fire. The loaf is there, in the circle, or the line no longer says it is. The same for the drowned tongue, the warm tongue, and Wyck's thorn. The tongs, the slates, the mug, the lantern, and the staff still appear for the picks they already follow.

**Stay.** The five props that exist keep their places. No new quest, and no prop for every name in the book.

**Band.** B.

### 193. A count with no ground, and a task already finished

**See.** Abel asks for tally-beads off the bone-walkers of the fen and the Barrow Field. A bone-walker who falls in the ossuary still fills the count. Hesk asks for tollmen riding with the war bands. A tollman who falls anywhere fills his. And a task whose work is already done — the Thornwarden already cut, the fallen bells already rung, four Founder's bells already answered — still reads as work ahead, then completes itself while you are standing at the fire.

**Where.** `core/story/quest_runner.gd` `in_region` returns true when the step has no region. `bead_count` asks for `ossuant` and names no region. `unpaid_toll` asks for `tollman` and names no region. A step that does name a region, such as the road's six, only counts inside that ground. `check` runs every quarter-second. A `cond` step calls `QuestDB.test`. `boss:thornwarden`, `secret:solved:bells`, and `bells:4` are already true if the save says so, and `advance` toasts whatever step you land on.

**Change.** The bead step counts bone-walkers in the fen and the Barrow Field, the ground the sentence names. The toll step counts tollmen in the wood. A condition that is already true is spoken in the past when you accept it: the heart is already cut, the bells are already rung, and the toast is the next thing, not a claim that you just did the old one.

**Prove.** With the bead task active, put down a bone-walker in the ossuary. The count does not move. Put one down in the fen. It does. Accept Mother's Order after the rim bells are already solved. The accept line says they are already rung, and you are on the tongue.

**Stay.** A named rare still counts wherever it falls. That is the bounty. The quarter-second check stays.

**Band.** A.

### 194. The Tolling's glow

**See.** He raises the crozier and the hall fills, except a sound-shadow behind the mound and the mound's own foot. The safe shadow is a ring about three metres across. The light standing in that shadow reaches about ten. You can be standing in the glow, outside the ring, and take the toll.

**Where.** `core/enemy/bone_abbot.gd` `_tolling`. The hole is `SHADOW_R` 3.2, centred `SHADOW_AT` 6.6 behind the mound, and the mound's foot is a second hole of `MOUND_R + 0.4`. The zone radius is 27.5 and the toll is `TOLL_GLOOM` 45, and `BossKit.zone` lands that 45 on the wound plate. Sheet 203 is the naming. The column is drawn at `SHADOW_R * 0.8`. The ring matches the hole. The light's range is `SHADOW_R * 3.0`, energy 2.4, for `TOLL_TIME` 3.6 seconds. The mound's hole has no ring.

**Change.** The shadow's light reaches the ring and stops. The mound's foot gets the same ring, for the same three and a half seconds, at the radius of its hole. The toll stays 45. The safe ground stays the two holes.

**Prove.** Stand in the glow and outside the ring. The toll lands. Stand inside the ring. It does not. Stand on the mound's foot, inside the new ring. It does not. The light does not outlive the toll.

**Stay.** Four bells, one shadow behind the one he names. No second safe pocket. The light is not a rest and it is not registered.

**Band.** A.

### 195. The Reckoning's plate

**See.** Discs appear. Stand in one and it is counted. Miss one and a risen faithful comes up, and the line says the count is short. What you actually take is wounds: fourteen for each disc you missed. The constant and the comment both call it gloom. The gold light on a disc reaches five metres. The disc you must stand in is a metre and a half.

**Where.** `core/enemy/bone_abbot.gd`. `PLATE_R` is 1.5. `SHORT_GLOOM` is 14. `_end_plates` calls `take_wound(SHORT_GLOOM * short * dmg_mult)`. The pop is `the count is short by N`. Each disc gets a light of energy 1.6 and range 5 for `RECKON_TIME` 9.5 seconds. The ring is the disc. The column is `PLATE_R * 0.55`, so the column sits inside the ring. Standing in the gold, outside the ring, does not count. Attuned, he asks for one fewer disc. That part is already in the cast.

**Change.** The pop names the wounds: fourteen on the plate for each miss, and the total when several are missed. Each disc's light reaches about twice the ring, so the glow and the disc are the same patch of floor. Fourteen stays fourteen. The column can stay inside the ring; the ring is the tell.

**Prove.** Miss one disc. The plate takes fourteen, and the pop says so. Stand in the gold and outside the ring. It is not counted. Stand in the ring. It is. Three misses are forty-two on the plate, and the line adds them.

**Stay.** He still raises one of the faithful per missed disc. The attuned count still comes up one short. These lights die with the rite.

**Band.** A.

### 196. Rain and Requiem

**See.** Bone Rain's bar lasts two seconds. The dust on those discs stays five. Requiem's bar lasts 2.4 seconds. The outer ring is still landing at 2.2, and the grave-fire drips at about 2.5, after the bar has gone. You are still in the rite, and the bar says he is done.

**Where.** `core/enemy/bone_abbot.gd` `_bone_rain`: `RAIN_TIME` 2.0, then `AttackKit.linger` for 5.0 seconds at `RAIN_R - 0.6`. `_requiem`: `BossKit.cast` for 2.4 seconds, ring delays 1.0, 1.6, and 2.2, and the two drips on timers at 2.5 and 2.8 seconds.

**Change.** The Rain bar stays up for the dust, with the name still on it, and comes down when the linger does. The Requiem bar stays up until the last drip has landed. The discs, the gaps, and the damage stay as they are.

**Prove.** Rain: the name is still up while the dust can hurt you, and it is gone when the dust is. Requiem: the last drip happens while the bar is still up. Neither rite gains a light.

**Stay.** Three rain fields, one of them under you. Requiem's rings still offset so the gaps sit where the last discs were.

**Band.** B.

### 197. Sheltered, over and over

**See.** The Gale of the Door pushes you unless you are in the lee of a lit pylon. The lee is painted. While you stand in it, the word "sheltered" pops about five times a second for the whole five seconds. That is enough to fill the pool of floating numbers and throw the rest away.

**Where.** `core/enemy/ascended_warden.gd` `_tick_gale`. `GALE_TIME` is 5. The shelter test is `gale_shelter`. Every 0.18 seconds, if you are sheltered, `HitText.pop` says sheltered. The pool in `hit_text.gd` is 24. The emote at the start is "The door behind him opens a crack." The eclipse already says "the ring is spent" once, when the ring you used goes out. The eclipse's safe ring matches the hole. Its column is drawn a little inside that ring.

**Change.** "Sheltered" once, when you enter the lee, and not again until you leave it and come back. The lee marks stay for the whole gale. The opening line names the rings: the lit pylons are the lee. The push stays `GALE_SPEED` 3.

**Prove.** Stand in a lit ring for the whole gale. You see the word once. Step out and back in. You see it once more. Other numbers during the gale still appear. The push still happens in the open.

**Stay.** A ring you hid in during the eclipse is still spent, and it still says so once. The gale still does not push you while you are evading.

**Band.** A.

### 198. The song on the Warden

**See.** A Thornspeaker answers and your blows drop to half. If Ruan's stones are kept, they drop to three quarters. The attuned fight already says the song is weak. The ordinary call only says a Thornspeaker answers. You learn the half by watching the bar.

**Where.** `core/enemy/thornwarden.gd`. While a living Thornspeaker summoned by him is up, damage taken is multiplied by 0.75 if attuned and by 0.5 otherwise. The attuned emote is already "The ward-stones hold. Its song is weak." The call emote is "A Thornspeaker answers the call." Briarlings are crawlers by another name, capped with his other adds.

**Change.** The call line says the song is up and your blows are halved, in the same breath as the answer. The attuned line stays the one that says the song is weak. The numbers stay 0.5 and 0.75.

**Prove.** Unattuned, when the speaker rises, the line names the half, and the bar agrees. Attuned, the line still says the song is weak, and the bar takes three quarters. Kill the speaker. The next blow is a full one, and the line is gone.

**Stay.** Knots, the heal, and the plate are sheet 189. Briarlings keep the crawler's tells. No new add.

**Band.** A.

### 199. The sac, and the kin

**See.** The brood-mother squats and the sac swells gold for a second and a half. A bolt on the sac ruptures it: no mites, and she reels. The hint says so, once, for the whole night. While it is happening the cast bar does not name it. The four kin — bulwark, chanter, burrower, mite — are costumes on the bodies you already fight. The mite's sac reads as a light. It is emission on the mesh.

**Where.** `core/enemy/brood_mother.gd`. `BROOD_TELL` is 1.6. `weak_r` is 0.2, and 0.28 once she is enraged. `_on_weak_hit` is the rupture. A hit that is not the sac returns without breaking the brood. `Hints.once` is the only sentence. No cast name is set for those 1.6 seconds. The sac already has an omni, energy 1.2, range 4, shadows off. `core/enemy/kin_look.gd` builds parts on the shared grunt body, one material per kin. No omni in that file.

**Change.** For those 1.6 seconds the bar reads Brood, the way a cinder caster's bar reads Cinder Hurl. The hint stays for the first time. The sac's own light stays as it is. The kin stay costumes. The mite does not gain a light to match the word in the comment.

**Prove.** When she broods, the bar says Brood. A bolt on the body, missing the sac, does not rupture it. A bolt on the sac does, and no mites come. A mite in a dark corner is a glow on the mesh, and the light list does not grow.

**Stay.** Each brood is three mites, and six of hers can live at once. Enraged, the brood comes every seven seconds instead of ten, and the spray widens to five. The cinder caster's bar already says Cinder Hurl. Its landing disc is the tell, and the slag that stays is the smaller circle inside it. The guardians' leash is sheet 141. Do not resculpt the shared bodies.

**Band.** B.

### 200. The crypt's extra lamp

**See.** Corvin's posts are an eye, a mouth, a heart, a hand, and a crown. The rite is the first three and no others. Light the hand and it stays lit. Nothing says you have gone outside the rite. The grate simply does not move. The other secret places already answer you. The singing stones play the phrase, and a wrong note that is not the start of it tells you they have gone quiet. Ansel's wrong stone says it is cold under your knees. The fallen bells are Homecoming, then Patience, then Hope, and that is the same order Mother's Order asks for. The hermit's perch is the breath. The ninth stone waits until the three letters are read.

**Where.** `core/life/secrets/site_fen.gd`. `RITE` is eye, mouth, heart. Lighting any post toggles it and plays a hum or a clank. The solved check is "these three and no more." A hand or a crown left on keeps the sizes from matching, and the only feedback is `State.refresh(false)`. `site_glade.gd` toasts the quiet stones. `site_wood.gd` toasts the cold stone. `site_rim.gd` `ORDER` is great, middle, treble, the same bells as `founder_peal`. `site_breath.gd` is the vent. `site_company.gd` checks the three letters.

**Change.** Lighting the hand or the crown toasts that the rite names three, and that lamp goes out. Eye, mouth, and heart stay as you set them. The order stays.

**Prove.** Light the hand. It goes out, and the line names the three. Light eye, mouth, heart, and no others. The grate lifts, and the line is the one it already says. A wrong note at the singing stones, and a wrong kneel at Ansel's, still speak.

**Stay.** The puzzles still remember that they are solved. Sheet 86 is that memory. The barrow still waits on the bells. No new secret, and no marker you did not earn.

**Band.** A.

### 201. A burn's numbers, and the ice

**See.** A burning foe throws a damage number every half-second, a third of a point each time, until the burn ends. A frozen foe says "frozen." The lance, the nova, and the well's horizon shatter that ice for double damage. The staff does not. Nothing says so. You hit the ice with the staff, the ice stays, and the blow is an ordinary one.

**Where.** `core/skills/afflict.gd`. `TICK` is 0.5 and `BURN_DMG` is 0.3. Each tick calls `take_hit`, and `enemy.gd` pops a number for every `take_hit`. `CHILL_SLOW` is 0.7, `FREEZE_AT` is 3, `FREEZE_TIME` is 1.2. `shatter` returns 2 and clears the ice. The lance's bolt, the nova, and the well when it is the horizon call it. The staff arts do not. The combo line already says SHATTER and "x2 damage" when a shatter lands.

**Change.** The burn still ticks, and the motes still play. The tick does not raise a floating number. The first tick can say "burning" once. The frozen pop, once a night, adds that the lance, the nova, and the well's horizon shatter it. The staff stays an ordinary blow against the ice.

**Prove.** Burn one foe for several seconds. You see one "burning," and the health still steps down. Freeze one and hit it with the staff. The ice stays, and the damage is single. Hit it with the lance, the nova, or the well's horizon. The ice breaks, the combo says shatter, and the damage is double.

**Stay.** Three chills freeze. The freeze lasts 1.2 seconds. Chill and the Thorn Heart's roots still share one speed, so they do not fight. No new spender.

**Band.** A.

### 202. A still plate, and fog on the road lamps

**See.** The unit plate redraws every frame while it is on screen, including while your health, your gloom, and the foe's bar are sitting still. The way-lamps along the paths are small pools, seven and a half metres, one every twenty-six. They are filed as fill, so each one also paints volumetric fog at the fill default. They are not a rest. The fog is the part you can take off without moving the pool on the stone.

**Where.** `ui/unit_frames.gd` `_process` calls `queue_redraw()` whenever the plate's alpha is above zero, and rescans every 0.25 seconds. `core/world/realm/realm_wayfinding.gd` builds each lamp at energy 1, range 7.5, shadows off, `light_class` fill, then `LightPolicy.apply_fade`. Fill falls through to the default in `core/world/light_policy.gd`: fade begins at 28 metres, and `light_volumetric_fog_energy` is 1.15. The player lantern already sets that fog energy to 0, for the same reason: a froxel on a small moving or repeated light.

**Change.** The plate redraws when gloom, wounds, health, a cast, a buff, or the target changes, and while a number on it is still moving. A settled plate waits. After the fade is applied, a way-lamp sets its volumetric fog energy to 0. The pool, the spacing, and the fade stay. Crystals and bowls that share the fill class keep their fog. The lamps stay off the light grid, so they never become a rest.

**Prove.** Stand still with the plate up and no combat. It is not redrawing. Take a hit. It redraws, then settles. Walk a way-lamp at night. The pool is on the stone, and the fog along that lamp is gone. A crystal's fog is still there. Gloom does not drain because you stood by a way-lamp.

**Stay.** The birds, the pond, and the flocks already tick slower with distance, and a group behind you is not redrawn. Leave that director as it is. The journal map redraws when you open it or pick a place. The Kindling cards redraw when you choose one. The combo line redraws while a name is up. The portrait viewport already turns off when the conversation closes. Those are not this sheet. Sheet 80 still owns the compass and the hotbar. The breath arc, the combat canvas, the memory strip, and the minimap are sheets 184, 190, 191, and 176.

**Band.** B.

The tasks that are a count, a seal, and a turn-in share one runner, and they already complete when the world says so. The four sentences and the bead count are the ones that disagree with the valley. The rites above are the ones whose glow, bar, or line disagrees with the hit. The animals already slow down as you leave them. The journal map redraws when you open it. None of these sheets are in the game yet. None of them adds a light, a system, or a mesh.

## Part XV — the plate, the door, and the size of a ring

A blow has been a wound since the plate existed. The constants still say gloom, so the wrong bar is the one a reader watches. The same habit shows up in the sizes: a pool, a ring, and a flash drawn larger than the thing they are teaching.

### 203. Blows land on the wound plate

**See.** The dark fills the gloom bar. A fire empties it. A strike, a spit, a boss's landing, the Tolling, and the sky when it breaks all move the other bar, the wound plate. The numbers in the scripts are still named gloom. Forty-five from the Tolling is more than a third of the plate. Fifty-five from the sky is close to half. The plate holds one hundred and twenty. Watch the gloom bar for either of those and it sits still while you are already on the way to a hollow.

**Where.** `core/player/player_vitals.gd` `take_wound` adds wounds and says, once, "They wound. A fire closes what they open." `wounds_max` is 120. `BossKit.zone` and `AttackKit.zone` call `take_wound` with the argument they still call gloom. So do spit, a melee strike, the Reckoning's missed plates (sheet 195), the knots (sheet 189), and `SKY_GLOOM` 55 on the Warden (sheet 185). The gloom bar moves in `_update_gloom`: the dark at 3 a second, the rift at 5, a registered fire at `gloom_drain_lit` 12. Two blows inside `HURT_GRACE` 0.35 seconds count as one wound.

**Change.** The numbers stay. The plate is the one that shows them, in the float or in the first toast, so a 45 and a 55 are read as wounds. The gloom bar keeps the dark and the fires. A rename of the constants can wait. The player should not have to know the old word.

**Prove.** Stand in the Tolling, outside the safe ring. The wound plate jumps by 45 and the gloom bar does not. Stand in the open dark. The gloom bar climbs and the plate does not. Eat the sky outside a pylon. The plate takes 55. Two spits in the same third of a second still count once.

**Stay.** Fires still mend the plate and still empty the gloom bar. A Lantern Ward still holds the dark back and still does not mend. Do not put blows back on the gloom bar.

**Band.** A.

### 204. Seven tongues and the first phase

**See.** Every tongue you carry to Hearthward takes a twentieth off the Warden's life, and the line names how many bells rang below. At seven tongues that is thirty-five percent. His second phase begins at sixty-five percent of a full bar. Seven tongues put him on that line before you have swung, and the summit room is there, so the first thing he does is leave the ground. The bar, meanwhile, looks pre-wounded against a life total that never shrank.

**Where.** `core/enemy/ascended_warden.gd`. `BELL_HOLD` is 0.05. On wake, `hp` becomes `max_hp * (1.0 - BELL_HOLD * carried)` and `max_hp` stays. `phase_marks` are 0.65 and 0.3. The first physics frame, if `hp <= max_hp * 0.65` and the room exists, calls `_ascend()`. Seven carried is exactly 0.65. The emote is "Far below, Hearthward rings N. He holds the door with less." Sheet 134 is the choice at the bell. This is what that choice does to the fight.

**Change.** The same fraction comes off `max_hp`, and the bar starts full on that smaller life. Phase two is still sixty-five percent of the life he actually has, so seven tongues are a shorter fight and still a first phase. The line names the share: a twentieth a bell. 0.05 stays. Seven stays about a third.

**Prove.** Face him with no tongues. The bar is full and he is on the ground. Face him with seven. The bar is full, shorter, and he is still on the ground until you have taken him to two thirds of that shorter life. The line says a twentieth a bell. One tongue is a small cut and the same shape.

**Stay.** Carried tongues still loosen him. Rung bells still do not. Attuning still adds the fifteen seconds from sheet 185. No eighth bell.

**Band.** A.

### 205. The rung bell's pool

**See.** Ring a Founder's bell where it hangs and the country quiets. A bell stands lit on that ground, and the toast calls it a place to breathe. The warm pool on the stones reaches about six and a half metres. The breath, the push that keeps the hollowed off, and the gloom leaving the bar, are a circle of two and a half. Stand in the outer glow and the picture says you are in the light. The dark is still climbing.

**Where.** `core/world/night/reach_state.gd` `_light_bell`, only when the pick is `rung`. The omni is energy 1.2, range 6.5, shadows off, fade beginning at 60. `LightGrid.register` is radius 2.5, kind `mirror`, drain left at the default. A mirror drains gloom at the fire's rate and shoves ordinary foes, and `is_fire` is false, so it is not a rest and it does not move the checkpoint. Camps in that country already come back three times slower. A carried tongue never builds this node. The pickup goes away with the step, and nothing stands where the bell was. Sheet 134 is the dumb frame that carried choice still owes.

**Change.** The pool and the circle are one radius. Two and a half metres is the breath you already wrote down, so the omni range comes down to meet it. Energy, the mirror, and the missing rest stay. A carried bell is sheet 134: the frame remains, the tongue does not, and there is no mirror on it.

**Prove.** Ring the Holds bell and stand at four metres, inside the old glow and outside the circle. The gloom bar still climbs, and a hollowed thing can reach you. Step into the two and a half. The bar falls, the hollowed keep off, and the checkpoint does not move. Carry the quarry tongue. A frame is there, silent, with no pool.

**Stay.** The country's camps stay slow. The bell still swings once when you ring it fresh. It is not a second Hearthfire.

**Band.** A.

### 206. The toll's earshot

**See.** A Tollman rings three times. Gold spreads on the ground, and nothing about it hurts. When the third toll lands, everything of the dark within earshot wakes and hunts past its leash. The gold you were watching never reached that far. The widest ring during the ringing is fifteen metres. The ring on the landing is seventeen. The earshot is thirty-four. A camp at twenty metres was outside every ring you saw, and it comes anyway.

**Where.** `core/enemy/tollman.gd` `_toll_fx` draws a ring of radius `3.0 + 4.0 * k` for tolls one, two, and three: 7, 11, and 15. `_finish_toll` draws `TOLL_R * 0.5` with `TOLL_R` 34, then `Enemy.toll` wakes living non-boss foes inside the full 34. Sheet 143 is the colour, the interrupt, and the clang's red disc. This is only the size.

**Change.** The ring that lands with the third toll is the thirty-four metre earshot, drawn dim on the ground, and gone with the toll. The three earlier rings can stay the bell getting louder. None of them deal a wound. The small light on the bell stays at range 6 for under half a second. Bosses stay asleep to it.

**Prove.** Let one finish with a camp between twenty and thirty metres. That camp was inside the landing ring, and it comes. A camp past thirty-four stays down. Hit him during the 2.4 seconds. No ring remains, and the camp stays down. You take no wound from the gold.

**Stay.** The clang stays the red disc from sheet 143. Two blows still kill him. The gold stays under the bloom threshold.

**Band.** A.

### 207. The peal's ball of light

**See.** Brannoc's peal is a cone in front of you. Foes in the cone take a blow and a Mark. The picture that goes with it is a ball of warm light, nine metres or eleven, bright for a third of a second, centred a step ahead. A foe beside you can be standing in that ball and take nothing. A foe out at the edge of the cone can take the blow where the ball has already fallen off.

**Where.** `core/skills/skill_peal.gd`. `REACH` is 9 and `REACH_WIDE` is 11. `HALF` is 37.5 degrees to either side, 55 once the peal is ranked. `_stroke` tests that cone. `_stroke_fx` calls `Vfx.light` with energy 3, range equal to the reach, for 0.3 seconds, from a point two metres along your facing. The light is not registered, so it does not drain gloom and it is not a rest. Gloom cost is 0. The carillon, the relic's other shape, draws a ring at `CAR_R` 6, and the blow is that same ring.

**Change.** The flash stays inside the cone: along the facing, and no wider than the cone is at that distance. The carillon's ring stays a ring, because that blow is a ring. Energy can stay a short flash. It stays off the light grid. The cone's reach and the half-angles stay.

**Prove.** Strike with a foe beside you, inside the old ball and outside the cone. He takes nothing, and the flash does not cover him. Strike with a foe in the cone at the far edge. He takes the blow, and the flash reached him. Gloom does not fall because you struck the peal. The carillon still matches its six metres.

**Stay.** Rank three still doubles bosses and still slows. The echo trait still rings a second time at half strength. No new spell.

**Band.** B.

### 208. The burrower's disc, and the mite at the edge

**See.** A burrower goes under, and a disc fills where it will come up. That disc is the wound. It is drawn amber, the colour of dirt, while every other disc that wounds you is red. A mite at the far edge of being seen is a frozen body: the mesh is still drawn, and the creature is already asleep.

**Where.** `core/enemy/burrower.gd`. The erupt is `AttackKit.zone` for `TELL` 0.75 seconds, radius `ERUPT_R` 1.7, damage `strike_gloom * 1.2` (21.6 on the plate, sheet 203), colour `Color(2.4, 0.78, 0.14)`, effect dirt. Underground it drops its collision, leaves the enemy group, and hides. It will not tunnel into a lit cell. `core/enemy/mite.gd` sets every mesh `visibility_range_end` to `VIS_RANGE` 45. `sleep_range` is 40. Sleep stops the brain and leaves the body visible. Clang and the other hurting discs use `AttackKit.RED` (sheet 143).

**Change.** The erupt disc uses that same red. The dirt stays in the burst around it. The radius and the three quarters of a second stay. A mite's draw distance ends where its sleep begins, at 40, so a mite you can see is a mite that is awake. Shadows on a mite stay off.

**Prove.** Let a burrower surface. The disc was red before it hit, and the plate takes the wound if you were in it. Stand in a lit ring. It does not tunnel in. Walk toward a mite. It is moving when it appears. At forty metres it is gone, not frozen.

**Stay.** Three mites from a brood, six alive at once (sheet 199). A burrower underground still cannot be hit. No new kin.

**Band.** B.

The gloom bar is the dark and the fires. The wound plate is the blow, including the ones whose constants still say gloom. Seven tongues shorten the Warden and still leave him a first phase. A rung bell's pool matches the small circle that actually breathes. The toll's last ring is the distance that wakes the camp. The peal's flash fits its cone. A hurting disc is red, and a mite you can see is awake. None of this is in the game yet.

## Part XVI — the circle, the camp, and the heap

The night's promise is that the warm circle is the safe circle. On a kindled fire the glow runs past the sanctuary. On a giver's camp and a rung bell, the small circle that empties the gloom bar also closes wounds. Three other lights are drawn past the ring that actually does the work. A bone-walker falls into a heap the lock will not drop.

### 209. The fire's glow and its sanctuary

**See.** A kindled fire is the safe ground: gloom leaves, wounds close, ordinary foes keep off, and the checkpoint moves if you are close enough to be remembered. The warm pool on the ground is larger than that ground. Stand in the outer glow and the bar is still climbing. A wretch will walk up to you there. The hearth can widen every fire, and the glow widens with it, and the gap stays the same share.

**Where.** `core/world/brazier.gd`. The sanctuary registered with `LightGrid` is `light_radius` 11. The light's authored range when lit is `lit_range` 14.5. `core/world/light_policy.gd` multiplies a beacon's range by 1.22, so the pool is 14.5 × 1.22, about 17.7 metres. Foes, the gloom test, and `lit_at` all use 11. `set_reach` says the warm circle should read as far as it holds, and it scales `lit_range` by the same ratio as the sanctuary, so a Hearthfire that adds metres keeps the pool about three fifths larger than the circle that holds. Unlit, the bowl is the fill class: a base range of 2.5, times 1.35, and it is not registered. Shadows on the fire stay off.

**Change.** After that 1.22, the pool equals `light_radius`. The base range written for a lit fire is the sanctuary divided by 1.22, and `set_reach` keeps that pairing when the hearth widens it. Energy stays. The unlit coal stays a small coal. The sanctuary stays 11 until the hearth adds to it.

**Prove.** Kindle a fire at the first hearth, before any widening. At 14 metres the gloom bar still climbs and a hollowed thing can reach you. At 9 metres the bar falls, the plate closes, and the foe keeps off. Raise the hearth until the sanctuary grows. The pool grows with it and still ends where the sanctuary ends.

**Stay.** Four stair fires, and the Hearthward fire beside them. No new light. The moon still carries the shadow. Glow budget unchanged.

**Band.** A.

### 210. A camp that closes the plate

**See.** A giver's camp and a rung bell are a breath, not a hearth. Ordinary foes keep off them. They do not move the checkpoint. Stand in either one with a wound open and the plate closes, at the same pace as a kindled fire, and the gloom bar empties at the fire's twelve a second. The Hollow One comes apart there too. The horn lantern in your hand does none of this. Sheet 148 is that lantern. Sheet 205 is the rung bell's pool being wider than its circle. This is what the circle does to the plate.

**Where.** `LightGrid.register` of a mirror leaves `drain` at the default, and `drain_at` returns −1 for any negative drain. `player_vitals.gd` treats a negative drain as a fire: gloom leaves at `gloom_drain_lit` 12, and wounds close at `wounds_mend_lit` 14 a second. A positive drain, the Lantern Ward, holds the dark back and the comment there says it does not mend. `is_fire` is the checkpoint and the tide. A mirror is not a fire. The seven outposts are `village_props.gd` `outpost`, radius 5.5. The rung bell is `core/world/night/reach_state.gd`, radius 2.5. Wyck's fire in the Thornwood is a light and a flame, and it is not registered, so it does none of this. The shade unmakes whenever `drain_at` is not zero. The hint on a passing bolt says to run for a fire or a lantern.

**Change.** The wound mend asks `is_fire`. A mirror can keep emptying gloom, holding foes off, and unmaking the shade. It does not close the plate. Rates stay 12 and 14, and they stay on the real fires. The horn in the hand stays a picture (sheet 148).

**Prove.** Take a wound and stand in Ruan's camp. Gloom falls. The plate does not. The shade, if it is up, comes apart. The checkpoint does not move. Stand at Wyck's fire. The bar still climbs. Walk to a kindled fire. The plate closes. Stand in the horn lantern's own pool, in the open. Gloom climbs and the shade keeps coming.

**Stay.** The camp stays a place the giver can stand. The rung bell stays a mirror. Neither becomes a second Hearthfire. Sheet 205 still matches the bell's pool to its circle.

**Band.** A.

### 211. Three lights past their own rings

**See.** The Lantern Ward draws a ring on the ground, and that ring is the circle that drains gloom and turns lesser foes. The light on the totem reaches past the ring. The Umbral Well draws a disc, and the pull and the marks live in that disc. The violet light reaches past the disc. A giver's camp fire is the same inch, smaller: the pool is a metre past the circle that actually holds.

**Where.** `core/skills/lantern_ward.gd`. `RADIUS` is 7. The ring and the rune are that radius. `LightGrid.register` is that radius, kind ward, drain 4. The omni range is `RADIUS * 1.6`, 11.2, volumetric fog energy 1.4, shadows off. `core/skills/umbral_well.gd` pulls and marks inside `radius` 4.5, and `SpellFx.disc` is drawn at that radius. The omni range is `radius * 1.7`, and the energy climbs to 1.6, or 2.4 while it burns. It is not registered. `village_props.gd` builds the camp omni at range 6.5 and registers 5.5.

**Change.** Each of those lights ends on its own circle. The ward's omni range is 7. The well's omni range is its radius. The camp's omni range is 5.5. Energy, the ward's drain, and the well's pull stay. The ward's fog can stay on the one planted light. None of the three join the fire list.

**Prove.** Plant a ward and stand at 9 metres, inside the old glow and outside the ring. Gloom does not leave, and a mite can cross. Step inside the ring. Gloom leaves at the ward's rate. Open a well on a foe standing just outside the disc. He is not pulled, and the violet ends at the disc. Put him in the disc. He is pulled. At a camp, the glow ends where the foes stop.

**Stay.** One ward at a time. The well's life and its collapse stay. A shot is still taken from a quarter past the disc. Bosses still walk through a ward. Sheet 68 still owns the plant's chime.

**Band.** B.

### 212. The bones that will rise

**See.** A bone-walker falls and the line says it will rise. The bar vanishes. The lock stays on the heap, because the heap is still alive to the game. Four seconds later it stands with half its life, and nothing on the bar counted those seconds. A Mark on it when it falls, or any blow on the heap, ends it. The hint says so, once.

**Where.** `core/enemy/ossuant.gd`. `_die` with no marks sets `_heap`, state `DEAD`, hides `_hp_bar`, and pops "it will rise." `is_alive` stays true while the heap exists, so `player_targeting.gd` keeps the lock. `REFORM_TIME` is 4. `_reform` sets `hp` to half of `max_hp` and shows the bar again. `take_hit` on the heap calls `_shatter`. The flesh glint speeds up as the four seconds run. `Hints.once` is `ossuant_heap`.

**Change.** The bar stays on the heap and fills toward that half over the four seconds, so the rise is a bar you can see. The lock can stay: there is something to look at. A blow still shatters it. A Mark on the killing blow still skips the heap. The words stay "it will rise."

**Prove.** Drop one with no Mark. The lock holds, and the bar climbs for four seconds to half. Strike the heap. It ends, and the bar does not come back. Drop one that is Marked. There is no heap. Walk away and come back inside the four seconds. It is still rising on the same bar.

**Stay.** Half life on the rise. Four seconds. No second life after a shatter. The bead count is sheet 193.

**Band.** B.

A kindled fire's pool ends where the sanctuary ends, including after the hearth widens it. A camp and a rung bell empty gloom and unmake the shade, and the plate waits for a real fire. The ward, the well, and the camp light stop at their own circles. A bone-walker on the ground is a bar filling toward half, and a blow still ends it. None of this is in the game yet.

## Part XVII — a step past the red

The danger shader says the outline is the exact ground the blow will take. A camp rake is ten degrees wider than that outline. Every zone that lands through the shared test adds a pad the paint does not draw. A gaunt's lane is a lane, and the rake is a circle around the body. A bound shade's last breath, and the dart it looses when you are looking away, both reach past the picture.

### 213. The rake and its wedge

**See.** A wretch rears, and a red wedge fills on the ground in front of it. The wedge follows the body as it turns with you. Step just outside the edge and the claw still finds you. The same wedge is on a husk, a mite, and a bulwark, each with its own reach and its own angle, and each blow sits past its own red.

**Where.** `core/enemy/enemy.gd` `_on_state`. The wedge is `SpellFx.danger` at radius `strike_range + 0.45` and half-angle `strike_arc`. `danger_zone.gdshader` draws that outline and discards the rest. `_resolve_strike` hits inside `strike_range + 0.5`, and inside `strike_arc + 10` degrees. A wretch is range 1.45 and arc 75, so the paint is 1.90 m at 75 degrees and the blow is 1.95 m at 85 degrees. At that rim the extra ten degrees is about a third of a metre of shoulder. A husk is 1.55 and 85. A mite is 0.85 and 60. A bulwark is 1.6 and 55. Inside 0.6 m the cone test is skipped. The claw flourish in `_swipe_fx` is `strike_range * 0.85` and `strike_arc * 0.8`, inside the wedge. The red is parented to the body and its yaw is copied from the rig each physics frame, and the blow aims with `_face_dir`.

**Change.** The blow uses the wedge's own numbers: reach `strike_range + 0.45`, half-angle `strike_arc`. The ten degrees and the five centimetres come off. Inside 0.6 m the blow still counts. The claw flourish stays inside the wedge. The red keeps following the rig.

**Prove.** Let a wretch rear and stand just outside the wedge, inside its reach, and hold still. You are clear. Step onto the red. The plate takes the wound as the fill completes. Do the same at the side of a husk's wider wedge. The edge you can see is the edge that hits.

**Stay.** Windup times stay. A feint still rears with no red. Breaking the tell still cancels the blow. Sheet 58 still owns the husk's charge and its slam.

**Band.** A.

### 214. A quarter metre past the paint

**See.** A quiller draws a rib and a narrow thread fills down the lane. Stand just beside that thread and the shard still takes you. A sigil, a slam, and a landing disc do the same at their rim: the outline is the picture, and the blow is a step past it. The shader's own note says the outline is the area that will be hit.

**Where.** `core/enemy/boss_kit.gd` `inside`. A lane hits when the side offset is within `rect.x + 0.25`, and a quarter metre past either end. A disc hits within `radius + 0.2`. A cone adds `0.08` rad, about five degrees, on top of its half-angle. `AttackKit.zone` lands through that test. The paint is `SpellFx.danger` at the rect or the radius with no pad. A quiller's thread is half-width 0.42, so the paint is 0.84 across and the shard reaches 1.34 across. Sheet 174 is the thread and the spring. This is the pad on the landing.

**Change.** `inside` uses the painted rect, the painted radius, and the painted half-angle. The quarter metre, the 0.2, and the five degrees come off. A hole cut in a zone stays a hole. Height stays the zone's own `h`.

**Prove.** Stand just beside a quiller's thread, close enough to see the rib. The shard passes. Stand in the thread. It hits. Stand on the rim of a chanter's sigil, on the paint. It hits. Stand a boot past that rim. It does not.

**Stay.** Sheet 60 still owns the sigil's extra second. Sheet 208 still owns the burrower's colour. The quiller's spring is still sheet 174. Do not widen the thread to hide the pad.

**Band.** A.

### 215. The gaunt's circle

**See.** A gaunt drops, and a lane paints through you. Then it runs. The lane is the tell sheet 174 left in place. The body rakes in a circle around itself, wider than that lane, so a step off the paint is still a hit when it passes.

**Where.** `core/enemy/gaunt.gd`. The lane is `SpellFx.danger` with rect half-width 0.7 and half-length `_dart_len * 0.5`. The paint is 1.4 m across. `_special_frame` wounds once when the flat distance to the body is under 1.15, in any direction, with no test of the lane. The run is `DART_SPEED` 11.5 after `DART_TELL` 0.55. A blow during the tell still breaks it.

**Change.** The rake tests the same rect the lane already drew. One pass still wounds once. The half-width stays 0.7. The 0.55 s and the speed stay.

**Prove.** Stand just beside the paint as the body passes. The plate stays. Stand in the lane. It rakes you once as the body passes. A bolt during the tell still stops the run.

**Stay.** It still does not take a melee token. The spring on a quiller is still sheet 174. No new attack.

**Band.** B.

### 216. The shade's disc, and the dart behind you

**See.** A bound shade at the end of its time dives, and a violet disc opens where it lands. A marked body standing past that disc still loses its marks. Earlier, while it is circling, a dart goes to the foe under the crosshair. Look at empty sky and the next dart goes to whoever is nearest, including a body behind you.

**Where.** `core/skills/bound_shade.gd`. Last Breath draws `SpellFx.disc` and a shell at `DIVE_R` 3. The burst skips a body only when the feet are more than `DIVE_R + 0.8` from the chest point it dived at, so on the ground, for a body of ordinary height, the marks reach about two thirds of a metre past the disc. The heavier hit, 2 plus the marks, is the inner test under 1.8 of that same chest point. The light on the dive is range `DIVE_R * 2.4` for 0.35 s. A dart aims with `Aim.pick` at cone 0.8, about 37 degrees either side, out to `REACH` 16. If that finds no one, `Aim.nearest` takes the closest body within 9 m and does not look at the crosshair. Sheet 68 owns the dart's volume.

**Change.** The burst measures along the ground and ends at `DIVE_R`. The heavier heart stays the inner circle. The flash stays a flash. A dart looses only when the crosshair's cone has a foe. An empty cone holds the dart.

**Prove.** Rank the shade to its last breath and dive it onto a marked body. A second marked body standing on the violet loses its marks. One standing past the disc keeps them. Look at the sky with one foe behind you. The shade does not loose. Look at the foe. The dart goes.

**Stay.** Life 14 s, and the jar's extra 6, stay. One shade, or two at the second rank. The dive still wants a body within 14 m or it simply fades.

**Band.** B.

The red on the ground is the blow. A rake ends on its own wedge. A quiller's thread, a sigil, and a landing disc end on their own outline. A gaunt rakes the lane it painted. A bound shade's disc is the burst, and a dart waits until the crosshair has someone. None of this is in the game yet.

## Part XVIII — the line, the ring, and the word

A Rift Step marks a corridor the violet thread does not cover, and the body comes back while the grace is still up. The third swing and the heavy draw a full circle, and the blow is the front of it. The heavy's arms finish their draw while the blow is still growing. A guard says blocked, and a quarter of the wound still reaches the plate.

### 217. The step's corridor

**See.** You tear out and a violet thread runs to where you arrive. A body standing off that thread still takes a mark. A disc opens at your feet, wider than the mark at the landing, and it marks no one by itself. The body is gone for a tenth of a second. Blows keep missing until a third of a second has passed, and for that last quarter-second you are standing there.

**Where.** `core/player/player_evasion.gd` `shadowstep`. The seam is `SpellFx.rift_seam`: a ribbon from 0.1 m across at the leave to 0.9 m across at the arrival. `_mark_path` marks a living foe whose chest is within 1.2 m of that segment. `SpellFx.rift_in` draws a disc of radius 1.6 at the landing. `step_reveal` is 0.1. `step_evade` is 0.35, and it starts at the same moment, so the body is visible again while `_evade_t` still has a quarter-second to run. The range stays 7.5, shortened by a wall. The Ferryman's Hook marks the same 1.2 beside a chain whose glow is 0.32 m across (`tether_chain.gd` `_draw_glow`).

**Change.** The seam is drawn 1.2 m to either side, the distance the mark already uses, with the thin thread kept inside it. The landing disc is that same 1.2. The body stays unseen until the grace ends. The grace stays 0.35. The Hook's glow, on the throw, is the same corridor as its mark.

**Prove.** Step past a foe standing a metre off the thread. The violet covers him and he takes a mark. Stand another a metre and a half off the landing. The disc does not reach him and he takes none. Step as a wretch's red is about to fill. The rake lands while you are still unseen. Once the body is back, the next rake reaches the plate.

**Stay.** A step into a wall still refuses and does not spend the cast. Sheet 68 still owns the arrival's volume. The range stays 7.5.

**Band.** A.

### 218. The finisher's circle

**See.** The third swing of the staff, and a heavy, stamp a full circle on the ground. A body standing in the back of that circle, behind you, is inside the picture and outside the blow. The front of the same circle is the blow.

**Where.** `core/player/staff_arts.gd` `_land_blow`. The finisher's centre is `reach` 1.1 m in front, and its radius is 2.0. A heavy's centre is 1.2 m in front, and its radius runs from 2.1 to 3.0 with the charge. `Vfx.ring` draws that radius as a full circle. The blow then keeps a foe only when the direction from you is at least `arc`: −0.2 on the finisher, about a hundred degrees to either side, and −0.3 on a heavy, a little wider. Inside 0.6 m that test is skipped. The first two swings use a tighter arc, 0.26, and they draw no circle.

**Change.** The ring is the front of the circle, cut on that same arc, out to the same radius. The rear of the circle is not drawn. Inside 0.6 m the blow still counts. The first two swings stay as they are.

**Prove.** Finish a chain with a foe in front of you, inside the ring. He takes the blow. Put one behind you, inside where the old ring reached. The ring does not cover him, and he does not take it. A heavy does the same with its larger ring.

**Stay.** The finisher's damage stays 2.3, and the marks it spends stay the cudgel. A heavy's damage still runs from 3 to 6.5. Sheet 38 still owns the lunge and the parry.

**Band.** A.

### 219. A heavy drawn too soon

**See.** Hold the staff and the arms go up over the shoulder. They are there, and the draw is still going. Release then and the circle on the ground is the smaller one. Hold until the draw is actually full and the circle is the large one, and the arms have looked the same for the whole second half.

**Where.** `staff_arts.gd`. The draw starts after `HEAVY_HOLD` 0.36 s, then `_heavy_c` climbs to 1 over `HEAVY_FULL` 0.85 s. Damage runs from 3 to 6.5, the ring from 2.1 to 3.0, and a second mark arrives only at 0.99. `character_rig.gd` `_combat_pose` feeds the arms with `smoothstep(0.0, 0.4, wind)`, so the pose is finished at two fifths of that climb. The tremble keeps growing with `wind`. At two fifths the blow is 4.4 and the ring is about 2.5. At the top they are 6.5 and 3.

**Change.** The arms' blend runs with the charge from 0 to 1, so the staff is overhead when the release is the large ring. The tremble stays, and it belongs to the last of the draw. The numbers on the blow stay.

**Prove.** Hold until the arms first look finished, and release. The ring is the large one and the blow is the heavy one. Release halfway up. The ring is the halfway ring, and the arms are at that same height.

**Stay.** The 0.36 s before a hold becomes a heavy stays, so a tap is still a light. A heavy still wants the ground. Sheet 218 cuts the ring to the front.

**Band.** B.

### 220. The word blocked

**See.** The staff comes across and a wretch's rake meets it. The line says blocked. The plate still opens, by a quarter of that rake, and a large share of the breath goes with it. From the side, past the staff, the same rake arrives whole and the word does not come.

**Where.** `staff_arts.gd` `absorb`. `BLOCK_KEEP` is 0.25, so a quarter of the wound is returned and the rest is turned. The pop on a turn is the word "blocked". The turned share drains breath at `BLOCK_COST` 2 per point. A wretch's rake is 25, so the plate takes 6.25 and the breath loses 37.5. `GUARD_COS` is 0.17, about eighty degrees to either side of the facing. Past that, the whole amount returns and there is no pop. Empty breath sets `BROKEN_TIME` 0.9 and the line is "GUARD BROKEN", and that one does let the whole blow through.

**Change.** The pop on a held blow is the number that reached the plate. The quarter stays. The breath cost stays. The eighty degrees stay. "GUARD BROKEN" stays the line for an empty breath, and that blow still arrives whole.

**Prove.** Guard a wretch's rake from the front. The plate moves by a quarter of it, the breath falls, and the number over you is that quarter. Step out to the side of the staff and take the same rake. The plate takes all of it. Empty the breath on a guard and the next rake is the whole one, with the broken line.

**Stay.** A parry is still a parry, in the first 0.2 s, and it still spends none of the blow. Sheet 38 still opens that window when the staff is across. The guard still wants the ground.

**Band.** A.

A step's violet is the corridor that marks, and the body returns when a blow can land again. A finisher's ring, and a heavy's, is the front of the circle that hits. The arms reach the top of the draw as that circle reaches its size. A block names the quarter that got through. None of this is in the game yet.

## Part XIX — the bolt, the riposte, and the kill

The primary is a bolt until a body is in the staff's reach, and then it is the staff. A riposte, a surge, and a kill each tell you what the next moment is worth. The lock, the backswing, the ring, and the silence each spend that promise early.

### 221. A lock that takes the bolt

**See.** A mite is locked and standing at your hip, and you have turned to loose a bolt down the path. The staff swings at the mite instead. The same thing happens with a locked body on the far side of a wall, close enough that the lock still knows it.

**Where.** `staff_arts.gd` `claims_primary` and `_find_close`. A foe in front, within `CLOSE_R` 2.7 and about seventy degrees of the look (`CLOSE_COS` 0.34), in sight, makes the primary a strike. A lock is taken first, out to `CLOSE_R + 0.8` (3.5 m) and within 2.2 m of height, with no look test and no sight test. While a strike is already playing, the primary stays the staff so the chain can continue.

**Change.** A lock takes the staff on the same terms as any other body: in that front cone, in sight, inside 2.7 m. A lock behind you, or through a wall, leaves the bolt a bolt. The staff key still swings on its own, out to `PICK_R` 3.6, including at nothing.

**Prove.** Lock a mite, turn your back, and stand within three and a half metres. The bolt leaves. Put the mite on the other side of a wall, still locked and still that close, and look toward the wall. The bolt leaves. Face the mite in the open, inside 2.7 m. The staff takes the trigger, and a swing already going still chains off that same trigger.

**Stay.** The close staff stays. It is how a body in your face becomes a fight. Sheet 38 still owns the lunge those swings take. The chain buffer of 0.32 s stays.

**Band.** A.

### 222. A riposte spent on the backswing

**See.** You step through a blow and the line says the next bolt is a Rift Lash. You are close, so the primary is the staff, and the swing starts. It meets nothing. The next bolt is an ordinary bolt. A parry says the next strike or the next bolt, and a miss spends that too.

**Where.** `player_vitals.gd` `on_evaded` sets `_riposte_ready` and the hint names the next bolt. A parry and a perfect dodge set the same flag and name the next strike or bolt. `staff_arts.gd` `_begin` and `heavy` call `consume_riposte` as the swing starts, before `_land_blow`. A miss never reads the flag, and it is already clear. `skill_bolt.gd` spends it on a bolt that has left the staff. A landed staff riposte hits at 2.5 times.

**Change.** The staff spends the flag in `_land_blow`, when something is actually hit. A miss leaves it armed. A bolt still spends it as the shot leaves. One flag still serves the step, the parry, and the perfect dodge: the next thing that connects is the riposte.

**Prove.** Step through a wretch's rake, then swing at empty air. The bolt slot stays lit, and the next bolt is the lash. Do it again and land the staff. That blow is the heavy one, and the bolt after it is ordinary. Parry, miss, and the same lash is still waiting.

**Stay.** The step still marks the attacker twice and still calls `riposted`. The parry window stays 0.2 s (sheet 38). The lash on every third bolt stays (sheet 66), and a riposte landing on that third bolt is still one lash.

**Band.** A.

### 223. The surge's ring

**See.** The line says a crit or a parry lights Rift Surge, and that the next Nova bursts double. A perfect dodge lights it too, and so does stepping through a blow. The Nova's own hit is unchanged. On a clean foe the surge adds one point, which happens to make two where there was one. On a marked foe the ring stays one plus the marks, and that same one point sits beside it.

**Where.** `combat_state.gd` `proc_surge`. The hint is the crit and the parry. A crit lights it two times in five (`SURGE_ON_CRIT` 0.4), and not again for `SURGE_ICD` 3 s. A parry, a perfect dodge, and a step-through each call `_surge` and light it outright. It lasts 10 s, or until a fitting spell is cast. `surge_fits` is the Lance, the Nova, and any spell with a cast time. The Nova's ring in `skill_nova.gd` is `1 + marks` and never reads the surge. `nova_burst` adds `NOVA_BURST` 0.35 a resonance stack, doubled, plus 1, when a surge is spent. With no stacks that extra is exactly 1. The Lance does throw at full charge, and the well (0.6 s) and the familiar (1.0 s) do skip their root.

**Change.** The hint names the four ways it lights, and says a crit is a chance. It says the Nova gains one point, and that the resonance crumb of 0.35 a stack is what doubles. The Lance still throws at full charge. A cast that had a root still arrives at once.

**Prove.** Roll a blow in the first instant and the surge line appears, with no crit. Mark a foe four times, spend no resonance, and Nova. The hit is 5 plus the surge's 1. An unmarked foe with no stacks goes from 1 to 2, and that is the one extra point. Cast the well while the surge holds and it arrives without the 0.6 s root.

**Stay.** The bolt does not spend a surge. The 10 s and the one-use stay. Sheet 68 still owns the Nova's reach.

**Band.** A.

### 224. A kill that mends in silence

**See.** A mite drops at your feet and the wound plate closes. Nothing names the amount. A second kill, a few seconds later, closes a little more, and the only word is "chain".

**Where.** `player_vitals.gd` `_on_enemy_killed`. Inside 28 m, a kill calls `mend` with `KILL_RELIEF` 6, plus 2 for each earlier link, capped at 14. The window is `CHAIN_WINDOW` 4 s. The pop is "chain xN", and only when the chain is already 2 or more. The first kill moves the plate and says nothing. `mend` only closes wounds.

**Change.** Every kill inside that 28 m pops the number of wounds that closed. From the second kill, the chain count sits with that number. The 6, the extra 2 a link, the cap of 14, and the 4 s stay.

**Prove.** Open the plate, drop a mite at your feet, and the plate closes by 6 with that number over you. Drop another before four seconds pass. The plate closes by 8, and the chain count is in the same line. A kill past 28 m leaves the plate where it was.

**Stay.** The violet arc back to the wanderer stays. A kill during a hollow still mends nothing. Sheet 203 still owns which bar the wounds are.

**Band.** B.

The bolt stays a bolt until the body you would strike is in front of you and in sight. A riposte is spent by the blow that lands. A surge says what it adds to the ring, and a kill names the wounds it closes. None of this is in the game yet.

## Part XX — the channel, the window, and the pips

A rooted cast, a pair of blows in the same third of a second, the three pips over a body, and a stack of Resonance each keep a number the fight is using. The channel, the window, the pips, and the stack each spend it where you cannot see.

### 225. A nick, and a guard, take the channel

**See.** The well is rooting. A mite touches you and the channel jumps backward, with no word. You raise the staff to meet the rake that is coming, and the channel is simply gone.

**Where.** `skill_book.gd` `on_hurt`. `HARD_HIT` is 20, read as wounds after the guard (sheet 203). At 20 or more the line is "INTERRUPTED" and that slot waits `LOCKOUT` 1.5 s. Under 20, `_cast_t` loses `PUSHBACK` 0.3 s and nothing is said. A mite is 5. A crawler is 14. The well is a 0.6 s root, so one nick is half of it. A wretch is 25, so the rake is the hard line. `skills_locked` is true while the staff is guarding or a strike is playing. The book then calls `_stop_cast` with "cancel", and that reason draws no line. "moved" is the soft cancel that speaks. A roll does not lock skills.

**Change.** A rewind says so, in the same small voice as "moved". A guard or a strike that takes the channel uses that voice too. The hard blow stays "INTERRUPTED", with the second and a half. The root stays.

**Prove.** Channel the well and let a mite touch you. The bar steps back by about a third of a second and a word is there. Channel it and raise the guard. The channel stops and the word is there. Eat a wretch's rake during the well. The line is still "INTERRUPTED", and the slot waits a second and a half.

**Stay.** Walking out of the root still says "moved" (sheet 35). A roll with the stick held still says "moved". The well's 0.6 s and the shade's 1.0 s stay.

**Band.** A.

### 226. The lighter blow is the one that counts

**See.** A mite nicks you, and inside the same third of a second a wretch's rake arrives. The plate takes the nick. The rake is gone, and a channel that was up only rewinds, where the rake alone would have broken it.

**Where.** `take_wound` returns at once while `HURT_GRACE` 0.35 s is still running (sheet 203). The return sits above the guard, the channel, and `add_wounds`, so the second amount is never read. The first arrival is the whole window. A mite is 5. A wretch is 25. Two blows still count once. The one that is kept is whichever landed first.

**Change.** The window still collapses two blows into one. The one it keeps is the heavier. A lighter blow arriving second leaves the first in place. A heavier one replaces it, and the plate and the channel see the difference.

**Prove.** Let a mite touch you and take a wretch's rake before the third of a second is gone. The plate takes 25. If the well was rooting, the line is "INTERRUPTED". Two mites in that same window still count once. Two spits still count once, as sheet 203 already asks.

**Stay.** The 0.35 s stays. It is there so two overlapping hit shapes do not wound you twice. Sheet 220 still owns what a guard does to the blow that is actually kept.

**Band.** A.

### 227. Marks go out all at once

**See.** Three violet pips sit over a wretch, full, and the line says Nova will spend them. They stay full. Then they are gone together, and the Nova is a plain ring.

**Where.** `enemy.gd`. `MARK_MAX` is 3. `MARK_LIFE` is 5 s, one clock for the set, reset by every new mark. `_refresh_pips` only shows or hides them. A wretch is rank normal, and a normal foe draws no unit frame, so those pips are the clock. The hint at three marks names the detonation and not the five seconds.

**Change.** The pips dim with the time that is left, and the last moment is thin. A new mark restores them. The hint, once, names the five seconds. The cap of three and the five seconds stay.

**Prove.** Put three marks on a wretch and wait. The pips thin, and at five seconds they are gone. Land another bolt at four seconds and they are full again. Nova while they are up still pays one blow a mark.

**Stay.** The finisher still takes the marks before it leaves its own (sheet 218). An elite's frame may keep its own clock. The pips are what a wretch shows you.

**Band.** B.

### 228. A stack closes the plate in silence

**See.** A bolt lands, then Nova. The gloom bar takes the Nova's cost. The wound plate closes by a little, and nothing names it. Three bolts, then Nova, and the word is "RESONANCE", with no amount.

**Where.** A landed bolt builds 1 Resonance, a lash 2 (`player_casting.gd`), and a landed staff blow builds 1. Nova and the Lance spend every stack. `RES_GLOOM` is 1.5 and the comment says it pushes gloom back. `_spend` calls `mend`, which only closes wounds. Under 3 stacks there is no pop. At 3 or more the pop is "RESONANCE xN", and breath comes back at `RES_BREATH` 4 a stack. The Nova's own gloom cost, 6, still hits the gloom bar.

**Change.** Every spend names the wounds that closed, one stack the same as five. At three or more, the breath that came back sits with that number. 1.5 a stack stays. The breath at three or more stays. The Nova's 6 stays on the gloom bar.

**Prove.** Wound yourself, land one bolt, and Nova. The gloom bar climbs by 6 and the plate closes by 1.5, with that number over you. Land three bolts and Nova. The plate closes by 4.5, the breath comes back by 12, and both numbers are in the line.

**Stay.** Sheet 224 still owns a kill's mend. A spend with no wounds open still shows nothing to close. Do not move this mend onto the gloom bar.

**Band.** B.

A channel says when a nick or a guard takes it. Two blows in one window keep the heavier. The pips thin as their five seconds run. A stack of Resonance names the wounds it closes. None of this is in the game yet.

## Part XXI — the ring, the breath, and the scar

The lance spends a stack and the blow grows. The nova spends the same stack and the ring stays the size it was. A perfect dodge gives breath back and can leave the body winded. A long drop teaches the wrong bar. A scar left by the lance counts itself out loud.

### 229. The nova's tenth

**See.** Five bolts, then the lance, and the throw is half again what a tap would be. Five bolts, then Nova, and the ring is still one, plus the marks. A foe already sundered takes that ring at the same size. A gold crit can land on the lance. It has nowhere to land on the ring.

**Where.** Spenders are promised 10% damage a stack. `try_cast` sets `cast_power` to `1 + 0.10` a stack, and the lance multiplies its bolt by that. `skill_nova.gd` hits with `take_hit(1 + marks)` and never reads `cast_power`. That `take_hit` also skips `CombatState.deal`, so the ring misses the crit roll (8%, times 1.6) and Sundered's extra 15%. The crumb in `nova_burst` does go through `deal`, so the small extra can crit and can take the 15%. The same skip sits on the peal, the haul's shock, the echo, and the kindled flare, when those are the spell in hand. The bolt and the staff already go through `deal`.

**Change.** The ring multiplies by `cast_power`, then goes through `deal`, the way the lance already does. One stack makes the ring 1.1. Five make it 1.5. A body that is already sundered takes the extra 15% on that ring. A crit can come up gold on it. The crumb stays the crumb. The base of one plus the marks stays.

**Prove.** Hold five stacks and Nova an unmarked foe. The ring is 1.5. Nova a foe that is already sundered, with no stacks. The ring is 1.15. The lance at five stacks is still half again its charge. A gold crit can sit on the ring the way it sits on the lance.

**Stay.** Sheet 223 still owns what a surge adds, which is one point and a doubled crumb. Sheet 228 still owns the wounds the spend closes. The first nova still applies Sundered for the hits that follow it.

**Band.** A.

### 230. Breath back, still winded

**See.** One roll is left in the bar. You spend it as the blow lands, inside the first instant, and the line says perfect dodge. Breath comes back. Sprint and the next roll are still refused, and the word that stuck is winded.

**Where.** A roll costs 22. `can()` lets it start at half that, so anything from 11 to 22 breath empties the bar and sets winded. A perfect dodge and a parry each refund `PERFECT_REFUND` 18. Winded clears only when breath is back over `WINDED_UNTIL` 40. Eighteen sits under forty, so the refund leaves the flag set. A parry while the bar is under 22 does the same: breath rises by 18 and the body stays winded.

**Change.** A perfect dodge's refund, and a parry's, clears winded. Eighteen stays the amount. Waiting the bar out still takes 40. A roll that empties you and was not perfect still leaves you winded until 40.

**Prove.** With the bar between 11 and 22, roll a mite's blow in the first instant. The perfect line shows, breath is 18, and you can sprint. Parry a blow while winded and under 22 breath. Breath rises by 18 and the winded word is gone. Roll the bar empty with no foe in the way. You are winded until the bar passes 40, as now.

**Stay.** Sheet 11 still owns the stumble, and the 40 gate for ordinary recovery. The perfect window stays the first 0.2 s of the roll. The parry window stays 0.2 s (sheet 38).

**Band.** A.

### 231. The fall's lesson

**See.** The first long drop tells you the dark got in. The gloom bar sits still. The wound plate moves, and the number over you is "jarred."

**Where.** The hint `fall_hurt` says "Long drops jar the dark in." `_fall_hurt` calls `add_wounds`. The rate is `FALL_GLOOM` 2.6 wounds for each m/s past `FALL_HURT_V` 16, halved if you rolled, and capped so the fall cannot hollow you. Sheet 9 is that ladder. The sentence still names the dark. Sheet 203 is which bar a wound uses.

**Change.** The hint names the plate. The ladder stays. The pop keeps the number it already shows.

**Prove.** Drop from a height that jars. The plate takes the number, the gloom bar does not, and the line you are taught names the plate.

**Stay.** A fall still cannot hollow you by itself. Rolling the landing still halves it. Sheet 9 still owns the heights.

**Band.** B.

### 232. A scar that counts in tenths

**See.** The lance hits, and then for six seconds a tenth of a point floats off the body, once a second. Sometimes that tenth comes up gold. A wretch has no frame, so the drip is the only sign a scar was left.

**Where.** Every lance sets `scar` to 1, or 2 when three or more stacks were spent. `ember_scar` ticks every 1.0 s for `tick_dmg` 0.25 a stack, for 6 s, through `deal`. `deal` may crit that tick, and `take_hit` pops a number for it. A quarter-point prints to a tenth. Sheet 201 already asked a burn's half-second ticks to stop throwing numbers. This is the lance's own tick, on that same pipe.

**Change.** The tick still takes the health. It does not raise a number, and it does not come up gold. The lance's own impact number stays. One word, "scar," the first time a night, is enough.

**Prove.** Lance a wretch and watch for six seconds. The bar steps down and no tenth floats off. The impact number was the one on the hit. Burn a foe the way sheet 201 asks and that drip is quiet too.

**Stay.** One stack, or two when the spend was three or more. Six seconds. Three stacks is still the cap. Sheet 201 still owns the burn.

**Band.** B.

The nova's ring takes the tenth a stack, and a crit can land on it. A perfect dodge gives the breath back and the body with it. A long drop teaches the plate. A scar ticks on the health and keeps its numbers to itself. None of this is in the game yet.

## Part XXII — the air, the chain, and the tenth

The staff, the tether, the number over a wound, and a boss's answer to a lash each keep a rule the other hand already broke. The heavy starts before your feet arrive. The chain asks the crosshair. The float rounds. The lash is counted as a plain bolt.

### 233. A heavy drawn in the air

**See.** You jump and hold the staff. Nothing happens while you are up. Your feet arrive, you let go, and the swing that comes out is a heavy. It costs the heavy's breath.

**Where.** `staff_arts.gd` `_read_input`. A press sets `_hold` to 0 and it climbs whether or not you are grounded. The draw starts when `_hold` passes `HEAVY_HOLD` 0.36 and the feet are on the ground. A jump is longer than that third of a second, so the first grounded frame with the key still down begins the draw. Letting go then calls `heavy` at whatever charge that frame had, and `heavy` spends `Stamina.HEAVY` 26. A light is `Stamina.STRIKE` 9. Releasing while you are still in the air calls `request_strike`, which returns before the swing because you are airborne, and the press is gone.

**Change.** Time in the air does not count toward the heavy. Leaving the ground clears the hold. Landing with the key still down starts it from zero, so the third of a second is on the ground again. A let-go inside that third is a light. A let-go in the air swings nothing.

**Prove.** Jump, hold the staff the whole way, and let go as you land. The swing is a light, and the breath it costs is 9. Stay on the ground and hold past a third of a second. The heavy draws, and it still costs 26. Let go while you are still in the air. Nothing swings.

**Stay.** The guard still wants the ground (sheet 220). Holding it through a jump still raises it when your feet arrive, and the parry window is that arrival. Sheet 219 still owns the draw once it has started on the ground.

**Band.** A.

### 234. The tether and the lock

**See.** A body is locked, up the steps, and the bolt flies into it. The tether thrown at that same body snaps back, and the slot sits for a second. The crosshair was never on the chest. The bolt did not need it to be.

**Where.** A locked bolt aims at the chest, in sight, out to `LOCK_AIM_RANGE` 40 (`player_casting.gd` `_combat_aim`). The tether uses `Aim.pick` on the camera, cone `CONE` 0.955, about seventeen degrees, and never reads the lock. The lock's own pitch is `atan * 0.6 - 0.2`, capped at 0.15 rad, so a chest a storey up sits outside that cone while the mark is still on the body. A miss refunds the cooldown down to `MISS_CD` 1 s. Up close, with nothing locked, the bolt's assist opens to about thirty-five degrees (`CLOSE_ASSIST_COS` 0.82) and the tether stays at seventeen.

**Change.** A lock inside the tether's reach, and in sight, is the hook. The seventeen-degree cone stays for a throw with nothing locked. A miss still costs one second.

**Prove.** Lock a wretch on the step above you and throw the tether. The chain takes them. Clear the lock, look past the cone, and throw. The chain snaps back and the slot is ready in a second.

**Stay.** The reach stays 18 m, and 24 m at the first rank. A boss still hauls you to them. Sheet 217 still owns the hook's glow. Sheet 44 still owns the lock's pitch.

**Band.** A.

### 235. The plate's fraction

**See.** A guarded rake puts a number over you and a larger one on the plate. A burrower's landing does the same. The float is a whole. The plate keeps the tenth.

**Where.** `combat_text.gd` `_on_hurt` pops `roundi(amount)` for any wound of 0.5 or more. `take_wound` adds the amount as it arrived. A blocked wretch is 25 times `BLOCK_KEEP` 0.25, which is 6.25, and the float says 6. A burrower's landing is 18 times 1.2, which is 21.6, and the float says 22. Sheet 220 asks the word "blocked" to become the amount that got through. This float is the other number, and it is already rounded.

**Change.** The float is the amount the plate took. A fraction stays a tenth. A whole stays a whole. The block's word and this float are that one amount, so a guarded blow does not say it twice.

**Prove.** Guard a wretch's rake. The plate moves by 6.25 and the number over you is 6.25. Stand in a burrower's landing. The plate moves by 21.6 and the number is 21.6. A mite's 5 still reads 5.

**Stay.** Wounds under half a point still stay quiet. Sheet 203 still owns which bar. Sheet 220 still owns the quarter and the breath the guard spends.

**Band.** A.

### 236. A lash on a boss

**See.** The third bolt is the lash, and on a wretch it hits for 2. On a boss that same lash hits for 1.4. A plain bolt that would be 1 hits for 0.7. Nothing says the boss is treating them as the same kind of shot.

**Where.** `BossKit.absorb`. A `MagicBolt` that is not `heavy` is multiplied by `BOLT_CHIP` 0.7, and the number you see is that reduced hit. The lash sets `empower` and does not set `heavy`, so it is chipped with the plain bolt. The lance is heavy, so it is whole. The staff and the nova are not bolts, so they are whole. The comment calls the chip the reason a held trigger is not how a boss falls.

**Change.** A lash lands whole. A plain bolt stays at seven tenths, and the first one in a boss fight says so once. The lance, the staff, and the nova stay whole.

**Prove.** Lash a wretch and the Warden. Both take 2. Hit the Warden with a plain bolt. The number is 0.7, and the line has named it. Hit him with the lance. It is the lance's own damage.

**Stay.** Seven tenths stays the plain bolt's tax. Heat still slows a held trigger (sheet 66). The phase floor still turns a blow that would cross it, and that word is still "warded."

**Band.** B.

A hold in the air does not draw the heavy. The tether takes the body the bolt is already hitting. The number over a wound is the amount on the plate. A lash lands on a boss the way it lands on a wretch. None of this is in the game yet.

## Part XXIII — whether the night is one night

The spine is already in the valley. Meet the keeper. Break a seal. Cut the Thornwarden. Take the crown. Carry both to the summit. Shut the door. Walk home. A cracked bell can begin the night again, harder, with what you carry. That is a whole night. These four are the places it speaks as two nights at once.

### 237. Two doors at once

**See.** You ask where to start. He says the four fires, then pick a door: the thorn seal west, or the gallery through the fen, both before you are done. You can also walk out without asking. The corner, either way, posts both seals as orders, and later posts the climb and the fight as two more. He offered a choice. The corner offers a list.

**Where.** `dialogue_db.gd` `start_1` and `start_2`. "I'll find my own way" sets `met_keep` as well, so the list appears without the speech. `quest_db.gd`: `thorn_seal` and `oss_seal` both open on `flag:met_keep`. `summit_seal` and `warden` both open when the Thornwarden and the Bone Abbot are down. `story.gd` `objectives` keeps up to three main lines. A seal you break before the line exists still counts. The four fires are the side line. `west_way` ends on the thorn seal. `east_way` and the fen descent end on the gallery.

**Change.** While both seals are shut, one line uses his sentence: pick a door, and it names both places. Breaking one replaces that line with that fight, and the other door becomes the next line. Either door first still counts. After both keepers, the corner has one line. Until four Founder's bells have been answered, that line is the peal in sheet 241. The fires stay beside this.

**Prove.** Ask where to start, then leave. One door line, his, and the fires beside it. Walk out of a fresh night without asking. The same one line. Break the gallery first. It counts, and the thorn is what remains. With both keepers down and three bells rung, the corner does not yet say to shut the door.

**Stay.** Both doors stay in the valley. No new path. Sheet 80 still owns how many lines the corner will hold.

**Band.** A.

### 238. The bell before the keg

**See.** The Warden falls. The compass says to walk back to the keg. A cracked bell on the summit is already awake, and a second one down in the valley. Press it, read the note, press it again. The night rebuilds. The walk home, and the mug the keeper was going to pour, are gone for this cycle.

**Where.** `deeper_bell.gd`. `awake` is `bosses_slain` having `ascended_warden`. The second press inside 8 s calls `begin_deeper_night`, which clears `bosses_slain` and the seals. `return` in the objective list needs that boss flag, and the keeper's last talk (`end_1`) needs it too. `BELLS` places one cluster near the origin and one at the summit, about `(±4.5, 27.35, -80)`, between the dais and the ward. Neither press asks for `ending_told`.

**Change.** The press that rings waits until the keeper has been told. Until then the bell still speaks, and the note says the keeper is pouring at the keg. After that mug, the second press rings, and the three rise.

**Prove.** Fell the Warden and press the summit bell twice. The valley stays. Walk to the keg and take the last talk. Come back, or use the bell where the road leaves north of the green. The second press rebuilds the night, and what you carry is still yours.

**Stay.** Two presses stay, so a brush of the hand does not begin it. The deeper night still keeps items, relics, fires, and the journal. Sheet 129 still owns what that night changes.

**Band.** A.

### 239. Continue is a rest

**See.** You quit on the stair, gloom high, the plate open. Continue puts you at the last fire you kindled. The bar is empty. The plate is clear. The slot you pressed named the fires, the keepers, and a date.

**Where.** `save_game` writes kindles, relics, checkpoints, seals, bosses, items, hollows, story, and systems. It does not write gloom or wounds. On a continue, `player.gd` wakes at `checkpoint_for` the scene, and gloom and wounds stay at 0. A scene change is the path that copies them, through `Travel.go`. The slot line is fires, keepers, and the file's date (`slot_summary`).

**Change.** The slot line names the wake: the last fire. Waking there is a rest, so the empty bar and the clear plate match a body that slept at that fire. The stair you quit on stays behind you. That is the cost, and the line should say the fire.

**Prove.** Kindle the Shrine, climb past it, quit, continue. You are at the Shrine. The slot you chose said so. The bar and the plate are clear. Bosses, fires, and the satchel are the ones you left.

**Stay.** Sheet 85 still owns a save that survives the write. Sheet 186 still owns the ash a quit leaves on the ground. A hollow already wakes you clear at that same fire. Continue is that rest without the fade. Do not start saving a body in mid-air or inside a boss.

**Band.** B.

### 240. The sky under the last sentence

**See.** The Warden falls. A sentence says the sky has stopped turning. Above you it is still turning. The stop arrives later, after the words have already asked to be read.

**Where.** `reactivity.gd`. The three calms are 0.2, 0.2, and 0.6. The Warden's share tweens the sky from 0.4 to 1 over 9 s when the target is at least 0.99. `story.gd` starts the ending 1.5 s after the fall, and the first line is "The sky stops turning." The spin is `sky_time * spin_speed`, and that speed is still coming down through the sentence.

**Change.** The first line waits until the spin has eased. The 9 s stay, so the sky still comes to rest instead of snapping. The bell and the two lines after it stay in the order they have.

**Prove.** Fell the Warden and leave the line up. When it is on the screen, the sky is still. Read on. The bell comes after, as it does now.

**Stay.** The earlier calms stay a fifth each. The sky still eases. It does not jump. The ending is still one beat on the summit, and you can still walk away from it.

**Band.** A.

The compass asks you to pick a door, in his sentence, on one line. The cracked bell waits until the keeper has poured. Continue says which fire you will wake at, and the wake is a rest. The last sentence is said when the sky is still. The night under that is the one already built. None of this is in the game yet.

## Part XXIV — the door, the lamp, the oath, the slot

The valley already has the two ways, the fires, and the climb. What a person trusts next is the sentence in the corner, the light in the hand, the vow at the fire, and the line on the slot. Each of those is a little ahead of the night, or a little behind it.

### 241. A peal the corner never names

**See.** Both keepers are down. The corner says to carry the heart and the crown to the summit ward, and to shut the door. You climb. The veil stays. Nothing in the corner mentioned a bell. Step onto the dais and a toast says the door hears none, and wants four.

**Where.** `summit_dress.gd` sets `requires_bells` to `Chains.BELLS_NEEDED`, which is 4, on the summit ward and on the Warden's arena. `ward_seal.gd` `bosses_ok` stays false until `QuestBook.bells()` reaches that, and a closed ward does not say why. `boss_arena.gd` `no_peal` is the toast, once, when you have already walked in. `quest_db.gd` opens `summit_seal` and `warden` on the two bosses alone. The keeper's hub, when both are down and the peal is short, tells you to ask Brannoc. The seven bell quests already exist.

**Change.** Until four bells have been answered, the one summit line from sheet 237 is the peal: four of the Founder's bells, and Brannoc has the first of them. At four, that line becomes the climb. Stand at the veil short of four and it says the same sentence the dais already says, once. The four, and the seven you may choose among, stay.

**Prove.** Fell both keepers with three bells rung. The corner names the peal, and the count. Touch the veil. It says the door wants four. Ring the fourth. The corner names the climb. The veil opens when the guardians are down, as it does now.

**Stay.** Sheet 193 still owns a bell task that completes itself because the save already holds it. No eighth bell. The door still wants a peal, not every bell in the valley.

**Band.** A.

### 242. The lamp the shade does not fear

**See.** The shade forms. The line says to run for a fire or a lantern, because only light unmakes it. The lamp is already in your hand. A way-lamp is burning on the stone beside the path. You stand in both. The shade keeps coming. The light that actually ends it is a kindled fire, or the Lantern Ward once you have set it down.

**Where.** `player_vitals.gd` `Hints.once` `shade_drive`. The shade unmakes when `LightGrid.drain_at` is not zero. Registered lights are a brazier, a Lantern Ward, an outpost mirror, and a rung bell. `wanderer_lantern.gd` is an omni, energy 1.85, range 8, and it is not registered. `realm_wayfinding.gd` builds a way-lamp every 26 m, range 7.5, and sheet 202 already keeps those off the grid. The teach toast says "The Keep's fire takes to your lantern," and the spell you receive is the ward.

**Change.** The first shade names a kindled fire, and the Lantern Ward if you have been taught it. It does not say "a lantern." The teach toast says the ward is a fire you set, and that the lamp in the hand is a lamp between casts. The hand lantern and the way-lamps stay off the grid.

**Prove.** Fill the bar in the dark, lamp in hand, standing at a way-lamp. The shade comes. Cast the ward, or step into a kindled fire. It unmakes. Gloom does not drain because you stood by the way-lamp. The hint you saw the first time named the fire and the ward.

**Stay.** Sheet 202 still owns the way-lamp fog, and the plate that redraws while it is still. No new light. The lamp in the hand still swings. Its shadows stay off.

**Band.** A.

### 243. A ward called a mend

**See.** You swear the Oath of the Hearth. It says fire takes the gloom off you and mends you sixty percent faster, and it names braziers, wards, and every warm light. At a brazier both bars do move that much faster. Inside a plain Lantern Ward the gloom leaves faster. The plate holds. The Kin lamp's Hearth rite is the other ward: it mends two wounds a second, and that line already says so. A feverfew tonic and a stole say the fire takes the gloom off faster, and they leave the plate out of the sentence, though the plate moves too.

**Where.** `kindling.gd` `apply` multiplies `gloom_drain_lit` and `wounds_mend_lit` by `lit_mult`. The oath sets `lit_mult` to 1.6. A fire is a negative drain, so both bars use that. A ward is a positive drain: gloom leaves at `drain * gloom_drain_lit / 12`, and the mend runs only when `drain < 0`. The ward's own cap stays 25. `ward_rite.gd` `HEARTH_MEND` is 2 a second while you stand inside the ward's radius, and `ward.gd` advances `_t` by `HEARTH_SHORT` 2. `gear_db.gd` prints "Fire takes Gloom off %d%% faster." `gear_stats.gd` prints "fire clears Gloom." Feverfew and the ash-bloom posset say the fire takes it off, and name no plate. The bellows, the Heart-Stone, and the path node already say the gloom and the mend, and they do not mention a ward.

**Change.** The oath says a fire takes the gloom and mends the plate, sixty percent faster, and a ward takes the gloom faster and does not mend. The four short lines name the plate at the same percent. The cap of 25 stays. A meal can still sit on top of the oath.

**Prove.** Swear the oath. Stand in a brazier. Both bars move at the fire's rate times 1.6. Cast a plain ward with the plate open. Gloom leaves. The plate holds. Attune the Kin lamp to Hearth and stand in that ward. The plate closes at 2 a second, and the ward burns 2 s shorter. Read the stole, the feverfew, and the posset. Each names the plate as well as the gloom. The bellows line can stay as it is.

**Stay.** Sheet 210 still owns a mirror that mends because it was registered like a fire. A plain ward stays a light. The Kin lamp's Hearth rite stays a flat 2 wounds a second, its own line, and it stays off the checkpoint. Item level, gear sets, and rested XP stay.

**Band.** B.

### 244. The gate counted twice

**See.** You kindle the ossuary gate, and the fires you already had. The slot on the title counts that gate as two fires. Continue lights it once.

**Where.** `save_game` stores every lit brazier under the scene in `lit_by_path`, by name, and the ossuary area also stores `ossuary/OssuaryGate` in `area_lit` when that brazier kindles. `slot_summary` adds the name counts and then the size of `area_lit`. The valley's own fires are only in the first list. The gate is in both. Sanctuary starts lit, so a fresh file that has saved once already has one name, and that one is honest.

**Change.** The slot counts a fire once. A name already in `lit_by_path` is not added again because `area_lit` remembers it for the stream. The gate still relights when the ossuary streams back in. The line from sheet 239 still names the fire you will wake at.

**Prove.** Kindle the Shrine and the ossuary gate. The slot says those two, plus Sanctuary if it was already burning, and it does not add an extra for the gate. Continue. The gate is lit. Kindle nothing else, save again. The number does not climb.

**Stay.** Sheet 85 still owns the write. The four valley fires stay the kindling line. The gate is not a fifth of those four.

**Band.** B.

The climb waits on the peal the keeper already mentioned. The shade runs from a fire and from a ward, and the lamp in the hand stays a lamp. The oath tells the truth about which bar a ward moves. The slot counts the gate once. None of this is in the game yet.

### 245. A Strike bar on a feint

**See.** You lock a wretch. It rears, and the bar under its health says Strike. A moment later the bar says BREAK. There is no red on the ground. The rear drops, the bar starts over, and the red arrives with the second fill. The arms already stay up through the fake. The bar is telling you the fake is the blow.

**Where.** `ui/unit_frames.gd` `_cast_of` treats state 2 and state 8 as the same bar: the name is Strike, or Flurry when a chain is already going, and the fill is `_state_t / _cur_windup`. `_cur_windup` stays the real windup, 0.42 on a wretch. `enemy.gd` FEINT lasts 0.3 s. `_on_state` telegraphs 0.3 and does not spawn `_danger`. The word BREAK is drawn once the fill passes 0.15 and the bar is marked interruptible, so it comes up about a sixteenth of a second into the fake. A hit of 2 or more during FEINT can still stagger the body, because winding includes the fake. `feint_chance` is 0.22 on a wretch. A champion is at least 0.12, and an enrage is 0.2. The frame is up for any lock, including a normal foe. Sheet 62 owns the arms and the missing red.

**Change.** While the state is FEINT the bar says Feint and fills across the 0.3 s the fake lasts. BREAK waits for the red. The Strike bar and the red start together on the real windup, and that fill uses the real windup. A heavy hit can still stagger the body. The bar stops promising it during the fake.

**Prove.** Lock a wretch and wait for a rear with no red. The bar says Feint, fills, and ends with the rear. The red and the word Strike arrive together. A Lash during the fake can still drop the arms. A Lash during the red still breaks the tell. A guardian does the same with its own chance.

**Stay.** Feint chance stays. The fake stays 0.3 s with no red. Sheet 62 still owns the arms. Windup times stay.

**Band.** A.

### 246. The bag a quit leaves

**See.** Quit Game says it saves and closes. A named hunt is dead and the bag is still on the ground. Continue. The piece is not in the satchel, and the bag is not where you left it.

**Where.** `ui/settings_menu.gd` the confirm calls `Settings.flush`, `Travel.save_now`, and `get_tree().quit`. `save_game` writes `items` as they are. `loot_bag.gd` `_exit_tree` stores whatever entries are left and does not save. The tree frees the bag after that write, on the way out. Closing the window from the dock does the same: `Travel._notification` saves on `WM_CLOSE_REQUEST` while the bag is still in the tree. `_finish`, when you empty the bag yourself, does call `save_soon`. Sheet 138 already keeps the pour for a place that streams out, and that pour is what runs after the write. Sheet 85 owns the atomic write. Sheet 186 is the ash heap, the same shape for a different pile.

**Change.** The save records every loot bag still in the world: where it is, and what is in it. Continue puts each bag back. Taking it clears that record. `_exit_tree` still pours a bag the save did not keep, so a streamed hall cannot eat a drop, and it does not pour a bag the save already wrote. One grant.

**Prove.** Kill a named hunt. Leave the bag. Quit. Continue. The bag is where you left it, and the satchel does not already hold the piece. Take it. Quit again. Continue. It is not given a second time. Empty the bag before you quit. Continue has the piece once, and no bag.

**Stay.** Sheet 138 still owns the chest toast and the stream-out pour. Sheet 186 still owns the ash heap. The quit still saves. No new satchel.

**Band.** A.

### 247. Seven and a half

**See.** You attune Implosion. The line says it drags everything within 7.5 m. The ring on the ground is wider than that. The Deep Reliquary rite says the drag was 9.5 and becomes 13, and the ring agrees with the rite.

**Where.** `reliquary.gd` `TEXT` for implosion says "within 7.5 m". `skill_nova.gd` `PULL_R` is 9.5, and `SpellFx.implosion` draws that radius. `core/life/progression/skills/nova.gd` uses 13 when the deep rite is owned and `PULL_R` otherwise. The rite line in `upgrade_db.gd` already says "13 m (was 9.5)". Wake's 3 s, and the rite's 5 s, already match.

**Change.** The toast says 9.5. With the rite bought, the toast says 13. The ring stays the number in the sentence.

**Prove.** Attune Implosion with the rite unbought. A foe at 8 m is pulled. A foe at 10 m is left. Read the rite. It still says the old reach was 9.5. Buy it. A foe at 12 m is pulled. A foe at 14 m is left. Wake still lasts 3 s, and 5 s after the rite.

**Stay.** The detonation still waits 0.35 s. The rite's sentence stays. Harrow's 3.5 m and its 30% already match the refund. Do not retune them.

**Band.** B.

### 248. A great one left standing

**See.** The Kindling says every foe in the peal's cone takes a blow and a Mark and is staggered. A wretch in the cone reels. The Thornwarden, the Abbot, and the Warden take the blow and the Mark and keep their feet. Toll says the stroke staggers twice. A lesser foe is asked twice in one frame. A great one is not asked.

**Where.** `upgrade_db.gd` the peal's text. `skill_peal.gd` `_stroke` calls `stagger` only when `not e.boss`. Toll passes `staggers` 2. Rank III doubles the hit on a boss and then slows every foe it struck, boss included, by half for 2 s. Sheet 70 owns the second stagger landing in the same frame, so the reel does not grow. Sheet 207 owns the cone against the ball the stroke paints.

**Change.** The sentence says a lesser foe is staggered, and a great one keeps its feet. Toll says a lesser foe is staggered twice, and a great one keeps its feet. Rank III stays the harder blow on the great ones, and the slow on everyone the stroke hit.

**Prove.** Peal a wretch and the Warden in one cone. The wretch reels. The Warden takes the blow and the Mark and does not reel. Toll the same pair. The wretch's reel is the longer one sheet 70 asks for. The Warden still keeps its feet, and the blow is twice as heavy. At rank III the Warden is slowed, and the blow is twice as heavy again on top of Toll.

**Stay.** The cone, the reach, and the Mark stay. Sheet 207 still owns the painted ball. A boss stays on its feet. The fix is the sentence, and the longer reel sheet 70 already asked for.

**Band.** A.

The bar tells the truth about the fake. The bag you left is there when you come back. The toast and the ring share one radius. A great one keeps its feet, and the sentence says so. None of this is in the game yet.

### 249. The hits that skip the roll

**See.** The well's book says the collapse is 1, plus half for each Mark. The shade's dart says 0.5. Rend says 1.5. The cinder edge says 0.6. The reel says 1 for each Mark. Those hits land on the number in the book. A Sundered foe, a crit, and a stack of Resonance leave them where they were. The nova's ring, the peal, the haul's shock, the echo, and the kindled flare are already sheet 229.

**Where.** `umbral_well.gd` `_collapse` calls `take_hit` with `1 + 0.5 * marks`, and a hungry shard calls `take_hit` with 1. `bound_shade.gd` calls `take_hit` with `DART_DMG` 0.5. `rift_rend.gd` calls `take_hit` with 1.5. `ward_rite.gd` calls `take_hit` with `CINDER_DMG` 0.6. `skill_tether.gd` `_arrive` calls `take_hit` with the Mark count inside `REEL_R` 2.5. None of them call `CombatState.deal`. `deal` is where Sundered adds 15% and a crit, at 8% and times 1.6, is rolled. The bolt and the staff already go through `deal`. The well keeps its Marks on the collapse unless the horizon spends them. The book's 1 and 0.5 are what the code adds before the skip.

**Change.** Those hits go through `deal`, the way the bolt does. The printed number stays the base, before the crit and before the 15%. The well still keeps its Marks unless the horizon spends them. The 1, the half, the 0.5, the 1.5, and the 0.6 stay the base.

**Prove.** Sunder a wretch, open a well on him with one Mark, and let it collapse. The plate loses 1.5 times 1.15, and a crit, when it rolls, is that times 1.6 and shows gold. A plain foe, with no sunder and no crit, still loses 1.5. A shade's dart on a sundered foe is 0.5 times 1.15. Rend, the cinder's edge, and a reel of two Marks follow the same rule on their own bases. The horizon still spends the Marks and still shatters a frozen foe.

**Stay.** Sheet 229 still owns the nova's ring and the four it named. The well's light stays off the grid. Sheet 211 owns that light. Do not retune the printed numbers.

**Band.** A.

### 250. A prompt through the wall

**See.** You stand against the Keg's wall. Someone on the other side is a couple of metres away. The prompt is theirs. You press the key and nod at a person you cannot see. The staff already leaves a lock alone when a wall is in the way. The use key does not ask.

**Where.** `player_interaction.gd`. The sensor is a sphere of radius 3.2 on the interact layer. `_scan` keeps the nearest `can_interact` inside that thing's reach, or `player.interact_range` 2.8, by distance from centre to centre. There is no world ray. Sheet 221 is the staff, and the lock it refuses through a wall. The horse's call already refuses a summon through a wall.

**Change.** Skip an interactable when a world ray hits between your chest and its chest. The prompt is the nearest one that ray can reach. A door you are facing still wins. A fire you can see still wins.

**Prove.** Stand against the keg wall with a person within 2.8 m on the far side. The prompt stays empty. Step through the door. The prompt is theirs. Stand where you can see a cold fire, with a person behind the same wall. The prompt is the fire.

**Stay.** The reach stays 2.8. Sheet 221 still owns the staff. The call still refuses a horse through a wall. No new interact system.

**Band.** B.

### 251. The night the tip says carries on

**See.** Erase Saved Progress says the save and the journal go, and that the night you are in carries on as it is. The next launch, it says, starts from the beginning. You confirm. You are on the title. The slot is empty. The night you were in is gone.

**Where.** `ui/settings_menu.gd`. The tip is "Deletes the save and the Journal. The night you are in carries on as it is; the next launch starts from the beginning. Settings are kept." The confirm calls `Travel.erase_save`, toasts "Progress erased. Returning to the title.", and after 0.8 s calls `Travel.to_title`.

**Change.** The tip says the save and the journal are deleted and you return to the title. Settings stay.

**Prove.** Change a setting. Read the tip. Confirm the erase. You are on the title, the slot is empty, and the setting is still the one you changed.

**Stay.** The two-step confirm stays, and it still lapses. Settings are kept. The toast can stay.

**Band.** B.

### 252. A wound called the gloom

**See.** The checkbox is called Combat Text. The line under it says the gloom blows put on you, and the kills take off, at your shoulder. You take a hit. The red number is a wound. The bar named Gloom does not move by it.

**Where.** `ui/settings_menu.gd` the Combat Text check: "The Gloom blows put on you and kills take off, at your shoulder". `combat_text.gd` pops the wounds a blow opened and the wounds a kill, a spent stack, or a fire closed. The file says these were gloom before the split. Sheet 203 is the plate that still wears the gloom's name in the fight. Sheet 235 is the float that rounds the same wounds.

**Change.** The line says the wounds a blow opens and a kill closes, at your shoulder. The numbers stay the tenths sheet 235 asks for.

**Prove.** Read the row. Take a hit. The red number matches the plate. The gloom bar is the other meter, and it sits still through that hit. Turn the row off. The numbers stop. Turn it on. They return.

**Stay.** The checkbox still owns the layer. Sheet 203 still owns the plate's name. Sheet 235 still owns the rounding of the float. The gloom bar keeps its name.

**Band.** B.

The printed number can crit, and it can take the extra from a sunder. The prompt stops at the wall. The erase tip says you will be on the title. The checkbox says wounds. None of this is in the game yet.

### 253. The frame's whole number

**See.** A blocked rake puts 6.25 on the plate. The frame reads 114 / 120. A foe with more than ten health is rounded the same way, so a pool that is not whole reads as a whole.

**Where.** `ui/unit_frames.gd` `_draw_player` prints `roundi` of the health left, which is `wounds_max` minus wounds, over `roundi` of the pool. `wounds_max` is 120. 120 minus 6.25 is 113.75, and that rounds to 114. `_num` prints a foe's health as a whole number once it is 10 or more, and as a tenth below that. Sheet 235 is the float over your shoulder, which rounds the same 6.25 to 6. This is the plate on the frame.

**Change.** The frame shows a tenth when the pool is not whole, the same rule the float keeps after sheet 235. A whole number stays whole. A mite under ten already has its tenth.

**Prove.** Guard a wretch. The plate moves by 6.25 and the frame reads 113.8 / 120. A whole 100 still reads 100. A mite's bar still shows a tenth. The float from sheet 235 reads 6.25 on that same guard.

**Stay.** Sheet 235 still owns the float. One health number on the frame. The gloom bar stays the other meter.

**Band.** B.

### 254. A row named Waygates

**See.** The tracking rows include Waygates, and Traders & teachers. Turn Waygates off. The little gate on each fire goes, and a rung bell goes with it. The flame on a lit fire stays, because that mark is a different row that the menu never names. There is no teacher on the map for the other row to hide.

**Where.** `ui/hud_prefs.gd` `TRACK` puts `travel` under the name Waygates, and `vendor` plus `trainer` under Traders & teachers. `brazier.gd` sets `map_kind` to travel, and `ui/minimap.gd` also drops a flame or an ash mark on every brazier from the brazier group. That flame is kind `fire`, which is not in `TRACK`, so `tracks` leaves it on. `reach_state.gd` sets a rung bell to `map_kind` travel and labels it "A rung bell". The travel picture is a gate. No node in the night sets `map_kind` to trainer. Vendors do: the stable is one.

**Change.** The row is named Fires & bells, and it is the gate mark plus the rung bell. The flame on a lit bowl can stay; the row's name tells you the gate is the same fire. The other row is named Traders. A teacher is not added to fill the old word.

**Prove.** With the row on, a lit fire shows its flame and its gate, and a rung bell shows the gate with its label. Turn the row off. The gate and the bell go. The flame on the lit fire stays. The Traders row hides the stable and leaves the fires alone. Nothing in the valley was a teacher.

**Stay.** No new tracking menu. No new pin on the seals. Sheet 176 still owns how often the disc redraws. The ember post stays the road.

**Band.** B.

### 255. A scar lit past its burn

**See.** A full-charge lance leaves the ground burning for 3 s, and the Kindling already says so. The scorch and the Mark live in a disc about two and a half metres across. The light on that patch reaches more than twice as far, so the ground looks on fire where you are safe.

**Where.** `cinder_scar.gd`. `RADIUS` is 2.6. `_scorch` hurts and marks inside that radius. The omni is `player_orb`, energy 2.2, range `RADIUS * 2.2` (5.7), shadows off, and the class leaves volumetric fog at 0 and distance fade off. Life is 3 s. The disc `SpellFx` draws is the 2.6. Sheet 232 is the other scar, the one on the body that counts in tenths. This is the patch on the ground.

**Change.** The omni range is 2.6. Energy stays 2.2 so the embers still read. Shadows stay off. Volumetric fog stays off. It does not join the fire list, and it does not take the fade rules of a hand-orb that has to stay bright in the muzzle. A scar you have walked away from can fade with distance. The 3 s and the 0.5 a tick stay.

**Prove.** Throw a full charge at your feet. Inside the disc you are scorched. At 4 m the ground is dark and you are not marked. The light is gone with the patch, about 3 s later. A tap that is not a full charge still leaves no patch.

**Stay.** The Kindling line stays, because the 3 s is true. Sheet 232 still owns the debuff on the body. Glow, bloom, and the height cap stay where they are. One short light, no shadow.

**Band.** B.

### 256. A root that lasts a moment

**See.** The Bramble Ward says it roots whatever crosses its light, slowed hard, and marked once. You watch a wretch cross the ring. It slows, and it is walking again before you have finished the cast that followed. A briar bolt, which uses the same word, holds much longer.

**Where.** `upgrade_db.gd` the bramble rite: "roots what crosses its light in brambles: slowed hard, and Marked once." `ward_aura.gd` `_root` sets `walk_speed` to 0.45 of the stored base and `briar_until` to 900 ms from now. The Mark is once, behind `_rooted`. A Thorn Heart bolt in `magic_bolt.gd` `_briar` is the same 0.45 for 2.2 s. Sheet 69 owns those two clocks when a pin and a bolt share one slot. This rite is the third writer, and its own sentence.

**Change.** The rite's sentence says the cross slows them for a moment and marks them once. The 0.9 s and the 0.45 stay. The Mark stays once.

**Prove.** Buy the rite. Plant a ward. Walk a wretch across the ring. It slows, it takes one Mark, and it is back to its own speed in about a second. A second cross, while the first moment is over, can mark it again. Read the rite. It says a moment, and a Mark.

**Stay.** Sheet 69 still splits the pin from the bolt. This rite stays a snag. It does not become a second pin. No new root.

**Band.** B.

The frame shows the tenth the plate kept. The row names the fires and the bells it actually hides. The scar's light ends on the burn. The rite says the snag lasts a moment. None of this is in the game yet.

## Part XXVIII — the picture on the body

Sheets 71 through 78 and 163 through 170 already own the first look, the frame, and the heavy files. These six are the bodies you stand next to. The meshes stay.

### 257. The shade's lantern

**See.** The gloom fills and the shade comes. The mask and the rags are the dark. Two points of light come with them: the eyes blow out to white, and a violet pool about nine metres across walks the ground in front of the thing that is supposed to be the dark.

**Where.** `shade.gd` `_mat("eye")` is unshaded, albedo `Color(5.0, 1.5, 0.45)`. The glow threshold is 1.15, so each eye is a bloom source. A second pair of sparks uses `Color(3.0, 0.9, 0.3)`. The mask also carries an omni, range 2.2, energy 0.6. `_core_light` is another omni, colour `(0.55, 0.3, 1.0)`, energy 2.0, range 9.0, class `fill`, sitting under the hem. `Atmosphere.apply` has already run, so those numbers stay as written and neither light fades with distance. A fog volume 4.2 by 3.6 and a 7 m shadow decal travel with the body. The shroud shader's ember `vec3(3.2, 0.9, 0.25)` is a thin hem edge, the same idea as a candle's hot core. Sheet 48 owns the bolt that bursts on a body it cannot hurt. Sheet 170 keeps the mesh.

**Change.** The eyes stay the tell, at a colour just over the threshold, about 1.3 on the hot channel. The sparks come down with them. One omni, the mask, range about 2, shadows off, volumetric fog at 0. The 9 m violet pool goes. The fog volume, the shadow decal, the shroud, the mask, and the rags stay.

**Prove.** Fill the bar on purpose. The eyes are two points. The ground in front of the shade stays the night's own dark, with the pool of shadow under the hem. Step into a fire. It still thins, as sheet 48 asks. The shroud is the same cloth.

**Stay.** Do not resculpt the shade. Do not add a shader. The hem ember stays a sparkle. Glow, bloom, and the height cap stay where they are.

**Band.** A.

### 258. The statue's white orb

**See.** The summit deck has a stone mage, a ring of candles, and an orb in the staff. The orb is a white disc. A cold pool about nine metres across sits on the paving, wider than the candles and wider than the figure.

**Where.** The monument on the deck is `mage_statue.gd`. The orb material has emission `(0.45, 0.62, 1.0)` at multiplier 3.0, so the whole sphere is over the 1.15 threshold. The omni starts at energy 1.6, pulses around that, range 9, volumetric fog 0.7, class `fill`. The rune band is unshaded `Color(0.7, 0.85, 1.6)`, so the blue channel blooms along the pedestal. Twenty-four candle quads use `candle_flame.gdshader`, whose comment keeps the body under the threshold and lets only the core (`vec3(2.4, 1.5, 0.7)`) bloom. `summit_dress.gd` refuses to dress the summit if `summit_mage.glb` is missing, `realm.gd` preloads that file, and nothing instances it. `_paint_mage` and `_dress_orb_light` have no caller. Sheet 159 owns the walk and keeps the statue a statue.

**Change.** The orb's emission multiplier sits just over the threshold, about 1.15, so the sphere stays a sphere. The omni range comes in to about 3.5, fog energy 0, shadows off, energy left near 1.6. The rune's channels sit near 1.1, so the band stays a line. Dressing the summit no longer waits on `summit_mage.glb`, and the preload of that file goes. The file stays on disk. The code statue stays the monument.

**Prove.** Stand on the dais. The orb is a pale sphere with a small hot centre. The candles still flicker. The paving outside a few metres of the figure is the deck's own light. Removing the glb from the load list still leaves the statue where it stands.

**Stay.** Sheet 159 still owns the flight and the deck. Do not swap in the glb. Do not add a person. Gothic stays lights only. The candle shader stays.

**Band.** B.

### 259. Motes past the candle

**See.** Three wisps drift over the valley, and a few bright buds sit in the grass. Each wisp is a blown-out point, hotter than the candle you just walked past. A bud's spots burn the same way. The little light around them is tame next to the pixel.

**Where.** `world/main.gd` builds `Glimmers` with `skip_shards = true` and palettes whose channels run up to 3.3 (`Color(1.55, 0.55, 3.3)` and its kin). `_scatter_wisps` makes three unshaded spheres at `palette * 1.2`, plus an additive halo of the raw colour, plus an omni whose colour is clamped to 1. The omni is class `glimmer`, energy about 1.15 to 1.85, range about 4.8 to 7, and `_process` multiplies energy by `LightPolicy.energy_mult` (1.15). `_scatter_buds` plants about four mushrooms and writes custom data `(palette.rgb, 2.8)`. `cap.gdshader` uses that alpha as `emit` and, on a spot, multiplies the raw palette by `emit * (0.7 + 0.8)`. The candle shader is the rule already written for a small flame: body under 1.15, a small core over it. The diamond shards stay skipped.

**Change.** A wisp's body and halo use the candle's rule. The hue stays. The three stay. A bud's emit comes down so the cap sits under the threshold and only a small centre clears it. The glimmer omnis stay, shadows off, fog at 0, and they keep their distance fade. The shards stay off.

**Prove.** Walk the meadow at night. A wisp is a coloured mote with a soft disc, and the grass around it is not a second sun. A bud reads as a mushroom with a warm tip. No octahedron scatter comes back. The candle in the crypt still has the hotter core.

**Stay.** Sheet 71 still leaves the four languages of the valley alone. This is the brightness of three motes and four buds. No new plant. No new light.

**Band.** B.

### 260. Flames with no wax

**See.** From the summit, looking down into the crypt, the candles are still burning. Walk closer and the flames have wax and bone under them. From the rail, a lot of those flames are floating. The skulls and the candles have already gone.

**Where.** `oss_kit.gd` sets skulls to fade by 34 m, long bones by 30 and 22, wax candles by 55, and both `Flames` and `Halos` by 120. The comment above the skulls says a skull is a few pixels past about 30 m. The flame shader and the halo stay correct up close. The range is what leaves the fire in the air.

**Change.** Flames and halos use the wax range, 55. The shader stays, including the hot core. Skulls and bones keep the short ranges they have.

**Prove.** Stand on the summit rail and look into the crypt. A flame you can see has a candle under it. Walk in. The same flame still flickers on the same wax. A skull still fades before you can count its teeth.

**Stay.** The crypt's thousands of bones stay instanced. Do not raise the skull range to match the old flame range. No new candle light.

**Band.** B.

### 261. Masks the crypt still samples

**See.** The ossuary stone, the bone piles, and the statue read with a baked shadow in the paint. That paint is still a full image in memory. A dressed root beside the path pays for a second occlusion map that the trunk beside it already dropped.

**Where.** Sheet 167 compresses the tavern, robe, bark, and dwarf masks, and records that `SurfaceDetail.apply` turns AO off on `bark.tres`. These imports are still `compress/mode=0` and `vram_texture` false: `oss_ashlar`, `oss_plaster`, `oss_floor`, `oss_slate`, `oss_bone`, and `oss_statue`, both the AO and the roughness. Their albedo maps are already GPU textures (`mode=2`). `oss_kit.gd` `_tri` turns AO on whenever the png exists, and `mage_statue.gd` does the same for the figure and the pedestal. `realm_assets.gd` `_mat("bark")` and `_mat("wood")` load `bark_ao.png` onto the roots, the fallen branches, and the lantern posts, which is a material `SurfaceDetail` never sees.

**Change.** Those ossuary AO and roughness imports become VRAM textures the way sheet 167's set did. The crypt keeps the AO sample, because it is using it. The runtime bark and the lantern-post wood drop the AO sample, so a root matches a trunk. If a still of the bone pile reads the same with AO off, that one map can follow the trunk. Colour, normal, and the triplanar scale stay.

**Prove.** Walk the crypt and the statue. The stone and the bone look as they do today. The import line for `oss_ashlar_ao` is a VRAM texture. A fallen branch and a trunk share the painted bark, with no occlusion texture on either.

**Stay.** Sheet 167 still owns the tavern and robe masks, and the bark tres stays stripped. Do not raise a size cap. Do not recompress a map whose still goes soft.

**Band.** B.

### 262. A horse with no ground

**See.** A villager at the hearth throws a moon shadow. The palfrey beside them does not. From the saddle the horse reads a little above the lane, because nothing ties the hooves to the ground.

**Where.** `villager_rig.gd` sets `cast_shadow` on. `life_kit.gd` `group` sets `cast_shadow` off for every creature multimesh, and the four horse meshes (`horse_palfrey`, `horse_garron`, `horse_draught`, `horse_fenpony`) go through it. `horse.gd` only bobs that instance. Sheet 75 keeps the moon atlas at 1024 and refuses a new caster. The shade already puts its contact on the ground with a decal, not a shadow map.

**Change.** One dark decal under the hooves, parented to the horse, no shadow map and no new light. It moves with the bob. The four coats stay. `cast_shadow` stays off. The deer and the moths stay as they are.

**Prove.** Stand beside the palfrey in the hearth moon. A soft patch sits under the hooves and travels when the horse does. A villager still has a real moon shadow. The meadow frame does not pick up a new shadow caster.

**Stay.** Sheet 103 still owns the four breeds and their ground. Sheet 75 still owns the moon. Do not sculpt a new horse. Do not turn the herd into casters.

**Band.** B.

The shade is a dark with two points of light. The statue's orb stays a sphere. A mote follows the candle. A flame has wax under it. The crypt's masks live on the GPU, and a root matches a trunk. The horse meets the ground. None of this is in the game yet.

## Part XXIX — the lights that walk with you

The candle shader already keeps a flame's body under the glow threshold of 1.15 and lets a small core through. These four are lights that do not.

### 263. The glass in the hand

**See.** The horn drum in the lantern is a white-hot pane in the corner of every frame. The ground for about eleven metres around your feet is warm, as if a camp were walking with you. The shade still comes. Sheet 242 already says this lamp is not the light that unmakes it.

**Where.** `wanderer_gear.gdshader` adds `glass_color * g1.y * glass_energy * lantern_glow` to the emission. `glass_color` is `(1.0, 0.6, 0.26)`, `glass_energy` is 4.5, and `wanderer_body.gd` sets the drum's own glow from 0.55 at the rim to 1.0 at the middle. `character_rig.gd` sets `lantern_glow` to the omni's energy divided by 1.85. The omni is authored at energy 1.85 and range 8, class `player_lantern`. The rig is dressed before `Atmosphere.apply`, and `apply_illumination` multiplies that class by 1.12 and 1.4, so the live light is about energy 2.07 and range 11.2, with distance fade off and volumetric fog at 0. The drum's middle then emits about `(5.0, 3.0, 1.3)`. Shadows stay off. It is not registered with `LightGrid`.

**Change.** `glass_energy` comes down to about 1.15, so the middle of the drum sits just over the threshold and the rim of the glass stays under it. The authored range comes in to about 4.5, so the class multiply leaves a pool of about 6 m, the body and the ground under it. Authored energy stays 1.85. Shadows stay off. Fog stays off. It stays off the fire list.

**Prove.** Stand in the meadow at night. The drum is a warm pane with a small hot centre. The grass past about 6 m is the night's own dark. Fill the bar. The shade still comes, and a kindled fire still ends it, as sheet 242 asks.

**Stay.** Sheet 242 still owns the hint and the registration. Do not put this lamp on the grid. Do not give it a shadow. The staff's runes may still brighten while you cast. Glow, bloom, and the height cap stay where they are.

**Band.** A.

### 264. The hall past its wall

**See.** The Abbot's hall is a noon made of candle colour. Stand just outside the wall and the path is still that colour. A kindled brazier, which is the brightest honest fire in the valley, is a small thing next to the lamp over the mound.

**Where.** `oss_hall.gd` `_lights`. The floor radius is 18.5 and the wall is 22.5. `Corona` is authored at energy 9 and range 30, 12.5 m above the centre. `MoundFoot` is 8 and 9.5. Eight `Gallery` lights are 7 and 13. The door is 6 and 9. Three tally lights are 3.5 and 8.5. Each is class `fill`, and `_omni` calls `apply_illumination`, which multiplies energy by 1.55 and range by 1.35. The corona becomes about energy 14 and range 40.5. The wall's base is about 26 m from that lamp, so the pool runs on the order of 15 m past the stone. A gallery light becomes about energy 11 and range 18, eight of them inside a floor of 18.5. A kindled brazier is `lit_energy` 4.6 and the beacon class multiplies energy by 1.0 (sheet 209). Shadows on all of these stay off. The deep's four lights are created hidden.

**Change.** The corona's range, after the fill multiply, ends at the wall. Authored range about 19 does that. Its energy, after the multiply, sits near the brazier's 4.6, so the authored energy is about 3. The eight gallery lights become local to a bay: authored range about 6, authored energy about 2. The mound foot, the door, and the three tallies come down with them, each still a lamp you can see, none of them a second corona. The count stays. Shadows stay off. The candles of sheet 260 stay.

**Prove.** Stand in the middle of the hall. You can read the mound and the galleries. Step outside the wall. The path is the night, and the door's own lamp is the light on the threshold. The frame inside the hall is quieter than it is today. No new light, and no shadow on these lamps.

**Stay.** The hall stays one room. The Abbot's floor and the catch stay sheet 188's. Do not rebake the ossuary. Gothic stays lights only.

**Band.** A for the corona, because it paints past the building. B for the gallery lamps.

### 265. Eyes at six

**See.** A wretch's eyes and seams, and a boss's, blow out to white the way the shade's eyes did. A windup makes them hotter again. The body around the glow is still readable. The glow is a blob.

**Where.** `grunt_pbr.gdshader` and `boss_pbr.gdshader` both set `emit_energy` to 6 and multiply the emission map by it, then by `(1.0 + glint * 2.5)` on a windup. A texel of 1.0 is emission 6, and a texel of 0.2 already clears 1.15. `flesh.gdshader` is the body used when the model is missing, and its eye channel is `UV2.x * eye_energy` with `eye_energy` 5, times the same glint. `EnemyBody.dress` takes the boss glb first and `GruntModel` next, so the two PBR shaders are the bodies on the night when those files are present. Sheet 166 keeps their maps at the caps they already have. Sheet 257 is the shade's own eyes and its 9 m light.

**Change.** `emit_energy` on both PBR shaders comes down to about 1.3, so a near-white texel just clears the threshold and a darker gland stays a gland. The glint multiply stays, so a windup still flares. `eye_energy` on the fallback flesh comes down the same way. If a still of one kind's seams goes out, that kind keeps a higher uniform and the white eyes still come down. No new map and no new light.

**Prove.** Meet a wretch in the meadow and the Thornwarden in the ring. The eyes are points. On a windup they flare and the face around them stays a face. A still of each matches the read you had, with the blob gone.

**Stay.** Sheet 166 still owns the texture caps. Do not resculpt a grunt or a boss. Do not raise an emit map to buy back the brightness.

**Band.** A.

### 266. Four bowls on one altar

**See.** The thorn ring has an ember over the altar and a fire at each mouth of the inner hedge. Standing on the altar, the mouths and the heart are the same colour. The heart already covers the floor.

**Where.** `henge_raid.gd`. `HeartLight` is energy 1.0 and range 28, and the floor radius is 31, so the heart is the room. It calls `apply_fade` and does not call `apply_illumination`, so those numbers stay. The four bowls sit at the inner mouths, each energy 2.0 and range 10, the same fade and the same skipped multiply. A range of 10 from the mouth reaches the altar. The moon shaft stays a separate spot, range 80, energy 1.6, shadows off. The bowls' flame quads are additive and already a little over the threshold (`albedo` `(1.3, 0.55, 0.2)`). Sheet 159 owns the walk up to this floor.

**Change.** Each bowl's range comes in to about 3.5, so the mouth has a fire and the altar keeps the heart. Energy stays 2. They stay off `apply_illumination`, so the fill class does not widen them later. Shadows stay off. The heart stays energy 1 and range 28. The moon shaft stays.

**Prove.** Stand in a mouth. The bowl lights the stones beside you. Stand on the altar. The heart is the light, and the four mouths are four small fires. The maze at the wall is as bright as the heart already made it. The frame in the ring does not gain a light.

**Stay.** The stones stay the stones. The raid door stays the seal. Do not add a fifth fire, and do not register these bowls as a rest.

**Band.** B.

The lantern's glass is a pane with a hot centre, and its pool ends around your feet. The hall's light ends at the wall. A wretch's eyes are points, and they flare on the windup. A mouth of the henge is a small fire. None of this is in the game yet.

### 267. Two circles round one green

**See.** Walk out from the green until the houses thin. One system has already decided you are in the wild. The other still treats that ground as Hearthward. A tide can arm where a surge will not be planted, and the holds are safe from one and open to the other.

**Where.** Both use the centre `(4, 36)`. `director.gd` `HAVEN_R` is 34. Inside that, and inside the Keg's rectangle grown by 6, and inside 21 m of the holds at `(-134, 12)`, `_in_haven` refuses the director's tides, ambushes, and elites. `world_events.gd` names its own circle "encounters' haven" and sets `HAVEN_R` to 40. A surge site is kept only when it stands more than 40 m from that centre, and between 30 and 150 m from you. The two files do not read each other's constant.

**Change.** One radius, one centre, and the same extra ground. The surge picker uses the director's 34 m, the grown Keg rectangle, and the holds. The comment on the surge names that shared ground. 34 stays the haven. The holds stay a haven for both.

**Prove.** From the green, walk out to 36 m. You are outside the director's circle, so a tide can arm, and you are inside the surge's circle, so it will not plant a site on that ground. After the change, both agree at that step. Walk to the holds. Neither plants there.

**Stay.** The haven stays a place the night does not fill with its own fights. No new event kind. The Keg's ceiling stays with sheet 78.

**Band.** B.

### 268. The gleaner's chance

**See.** A vestment reads "Foes give 6% more grave ash." A hundred kills beside you leave about six extra pinches, and a great one leaves none. The line reads as a larger pinch every time.

**Where.** `gear_db.gd` affix `ash_find` rolls between 0.04 and 0.08 and prints it with the percent format, "Foes give %d%% more grave ash." `kindling.gd` `_kill_traits` adds one pinch when `randf()` falls under that value. The same function returns before the pinch when the body carries `boss_id`, and when the body is more than 28 m away. Ash-Gleaner's every fifth kill is a different counter, in `hearth.gd` `_on_killed`, and that one does count a great one.

**Change.** The affix line says a chance of one extra pinch: "About 6 kills in a hundred leave one more pinch of grave ash, beside you." The roll stays a chance. A great one stays unpaid by this affix. The every-fifth pinch stays its own card.

**Prove.** Wear a piece that rolled 6%. Kill twenty wretches at your feet. The extra pinches land near one in twenty, and the toast is one pinch at a time. Kill the Thornwarden beside you. This affix adds nothing. The fifth-kill pinch still can.

**Stay.** Sheet 186 still owns the ash mound you quit on. Do not turn the chance into a flat percent of a larger drop.

**Band.** B.

### 269. A kill past 28 metres

**See.** Ember Heart says every kill mends 1 Wound. You drop a wretch at the far tree and the plate does not move. You drop one at your feet and it closes by one. A great one at your feet closes it too. The spark and the extra pinch stay quiet for that great one.

**Where.** `kindling.gd` `_on_killed` reads `kill_relief` and calls `mend` only when the body is within 28 m. That is Ember Heart's 1, the Oath of the Hollow's 4, the Lay Brother four-piece's 2, and a Reaper affix. `_kill_traits` uses the same 28 m and, before that, returns on `boss_id`. So `kill_spark` (one kill in four, 1 s off every slot) and `ash_hunger` (one more pinch) and `ash_find` never pay a great one. The chain mend in sheet 224 already uses 28 m for its own 6. This is the sentence on the card.

**Change.** Ember Heart, the Hollow, the four-piece, and the Reaper say "a kill beside you, within 28 m." The spark, the hunger, and the gleaner's chance say the same, and they say a great one does not pay them. The 28 m stays. The boss skip stays on those three traits. The plate-mend stays willing to close on a great one you fought in reach.

**Prove.** With Ember Heart, kill a wretch past 28 m. The plate stays. Kill one inside it. The plate closes by 1. Kill a keeper inside it. The plate closes by whatever relief you wear. The spark does not tick, and no bonus pinch arrives from the hunger.

**Stay.** Sheet 224 still owns the chain of 6 that grows inside the same circle. Do not add a second radius.

**Band.** B.

### 270. A step that slows

**See.** The Briar Antler says the step roots what it passes, for 2 s. A wretch in the tear keeps walking, at a little under half speed, for those 2 s. The legend and the trait use the same word and leave the time off.

**Where.** `item_db.gd` Briar Antler: "Rift Step roots what it passes in brambles for 2 s." `gear_db.gd` trait `step_briar` and the Rope of the Stair say "roots" and give no time. `step.gd` `_briar_path` takes a foe within 1.4 m of the segment, sets `walk_speed` to 0.45 of the stored base, and stamps `briar_until` two seconds out. It does not mark. Sheet 256 already changed the ward's "roots" to a moment and a Mark. This is the step, and its numbers are the 2 s and the 0.45.

**Change.** The antler, the trait, and the rope say the tear slows what it passes to a little under half speed for 2 s, within about a metre and a half of the line. The 2 s stays. The 0.45 stays. It does not become a pin, and it does not gain a Mark.

**Prove.** Wear the antler. Step through a wretch. It keeps its feet and covers the ground at about half speed, then walks off after 2 s. A wretch a few metres off the line never slows. The ward's own snare stays sheet 256.

**Stay.** Sheet 69 still splits the briar clock from the anchor's pin. Do not weld them.

**Band.** B.

### 271. Two seconds off the card

**See.** Ferryman's Weeds at four pieces, and the hook trait, tell you the tether marks the chain. The hook charm, on its own card, also says the tether comes back 2 s sooner. Wear the set and the slot agrees with the charm. The set's sentence never said it.

**Where.** `item_db.gd` Ferryman's Hook: "Marks everything along its chain, and recovers 2 s sooner." `gear_db.gd` ferryman `four` and trait `hook` name the marks and the chalk and leave the time out. `kindling.gd` subtracts 2 from the tether's cooldown when `hook` is set, before the global recovery multiplier. `growth.gd` `_stats` already prints that shorter recovery. The charm and the panel are the same night. The set and the trait are the cards that skip it.

**Change.** The four-piece sentence and the trait gain the clause the charm already has: the tether recovers 2 s sooner. The 2 s stays a subtraction on the tether only. The marks along the chain stay.

**Prove.** Wear the four pieces and open the tether's card. The sentence names the marks and the 2 s. The Now line's recovery is 4 s before any other haste (the stock 6, minus 2). Take the set off. The sentence and the 6 s return together.

**Stay.** The charm's own text already tells the truth. Do not take the 2 s off the charm to make the set look complete.

**Band.** C.

### 272. The table the night does not pay

**See.** `paths_db.gd` still carries a `MEMORY` table, and its comment says the hearth pays that table. A discovery, a gather, a tough, an elite, and a rare all pay memory. None of them are keys in that table. The night pays a different list, and the test still locks the old kill number.

**Where.** `PathsDB.MEMORY` is kill 3, kindle 40, seal 50, boss 150, quest 60, keepsake 25, home 30. `level.gd` `XP` is the list `hearth.gd` `give_memory` actually uses, via `LevelDB.xp_for`. It adds tough 5, elite 15, umbral 25, rare 40, discover 20, gather 5. The shared keys match. `zz/hearth_test.gd` still asserts ten kills against `PathsDB.MEMORY.kill`. `level.gd`'s own header still calls `MEMORY` the XP.

**Change.** `LevelDB.XP` is the only table. The path file's comment points at it. The hearth test reads `LevelDB.XP.kill`. `PathsDB.MEMORY` goes. The amounts the night already pays stay, including the five sources the old table never named.

**Prove.** Kindling a fire still pays 40. A gather still pays 5. A rare still pays 40. The hearth test fails if either table drifts, because there is one table. Adding a deed means adding it to `XP` and to the listener that calls `give_memory`.

**Stay.** Sheet 111 still owns the rested pool that doubles a kill and leaves a quest alone. Item level, gear sets, and rested XP stay.

**Band.** C.

### 273. A full lance called four

**See.** Open Ember Lance in the Kindling. The Now line says a full charge hits for 4. You hold it and the wretch takes six and a half, and a perfect throw on the snap takes more. The oath of the pyre makes a full charge half again on top of that, and the line still ends at 4.

**Where.** `growth.gd` `_stats` for `lance` prints the top of the damage pair as `4.0 * power`. `skill_lance.gd` `DMG_FULL` is 6.5, and the comment above it says the old value was 4. `lance.gd` `cast` lerps from the tap (2.0, or 2.5 at Wide Ember) up to `DMG_FULL`, then multiplies by power, then by 1.5 when the charge is full and `pyre` is set, then by `PERFECT_MULT` 1.3 when Quick Draw's snap is still inside 0.2 s. The charge time on that same line, `0.9` scaled by rank and `lance_charge`, matches `max_charge`. The burst pair, 3.0 to 4.6 plus Wide Ember's metre and `lance_blast`, matches `BLAST_MIN` and `BLAST_MAX`.

**Change.** The top of the damage pair is `DMG_FULL` (6.5) times power, and times 1.5 when the pyre is sworn. The tap stays 2.0, or 2.5 at Wide Ember. The "; Perfect +30%" suffix stays, and it stays off the printed top, because the snap is a moment and the line is the charge. Charge time and burst stay as they are.

**Prove.** With no pyre and power 1, the Now line reads 2.0 to 6.5. A full charge's float is 7 (the plate's rounding is sheet 235) on a fresh wretch, from 6.5. Swear the pyre. The line's top reads 9.8, and a full charge hits for 9.75 before a perfect snap. A tap still reads 2.0.

**Stay.** Sheet 236 still chips a lash on a boss and leaves a heavy lance whole. Do not put the boss chip on this line.

**Band.** A.

### 274. The number line

**See.** The Kindling's Now line sits under a paragraph that still has last year's counts. Short Wick's own rank sentence says a mote mends 2 Wounds. The Now line says the mote is 2 Gloom. Step-Weaver is on the path, and the step's recovery still prints the stock 2.1 s. The peal's line says it staggers, on a card you can open while looking at a keeper.

**Where.** `growth.gd` `_stats`. Nova's suffix is `"; motes 2 Gloom"` once rank is II or more. `nova.gd` `_motes` calls `mend(MOTE_GLOOM)` with `MOTE_GLOOM` 2. Short Wick's rank text already says "mends 2 Wounds." The step line is `2.1 * cd * (0.5 if door else 1.0)` and never reads `step_cd`, and its untouchable time is 0.35 or 0.60 and never reads `step_evade_add`. The peal line ends in "staggers" with no exception. `skill_peal.gd` `_stroke` calls `stagger` only when `not e.boss`. The familiar life is `14 + 6 if jar` and never reads `shade_life`. The bolt's lash clause prints damage and marks and skips the burst, which is 3.2, plus 0.5 at Keen, plus 0.8 at Deep Marks. The stock paragraphs (`_stock_text`, and the tether, well, and familiar `text` fields) keep rank-0 counts: every 3rd bolt, tether 18 m, well 3 s, familiar every 1.1 s. The Now line beside them has already moved.

**Change.** The mote suffix says "motes mend 2 Wounds." The step's recovery multiplies by `step_cd`, and its untouchable time adds `step_evade_add`. The peal says it staggers ordinary foes. The familiar's seconds add `shade_life`. The lash clause names its burst. The paragraphs that still quote a rank-0 count leave the count to the Now line, so the bolt stops saying "every 3rd" on a page whose Now line says "every 2nd." The Now line is the one place a count lives.

**Prove.** Swear nothing, take Short Wick, and read the nova card. The rank sentence and the Now line both say 2 Wounds. Wear Edda's Ferrule. The step's recovery prints 1.68 s (2.1 × 0.8) and the paragraph does not still say a different recovery. Open the peal beside a keeper and the line does not promise a stagger. A lantern with a longer shade adds those seconds to the familiar's Now line.

**Stay.** Sheet 228 still owns the mote against the gloom bar. Sheet 248 still owns the peal's own paragraph that says every foe is staggered. Sheet 229 still owns the nova ring skipping the tenth a stack. Sheet 211 still owns the ward's light past the ring the boost actually uses. Do not teach a boss stagger to make the old word true.

**Band.** A.

### 275. The ember's Now

**See.** Hearth-Warmth at one rank says "Now: 115 Gloom." Warm Hands is also taken, and the bar holds 125. Banked Coals says "Now: 88% drift" while Slow Breath has the dark moving slower than that. The per-rank sentence under the title is the true one. The Now line is the ember alone, printed as the whole night.

**Where.** `growth.gd` `_ember_value`. Warmth prints `100 + 15 * rank`. Banked prints `100 - 12 * rank` as a percent of drift. Will prints `10 * rank` as damage. Quick prints `7 * rank` as recovery. `upgrade_db.gd` `mods` starts from those same rates, and then paths, oaths, charms, gear, and the Hearthfire add and multiply. `kindling.apply` writes the sum onto the player. The per line on the card ("+15 Gloom held", "12% slower in the dark and by the Rift", "+10% damage", "7% sooner") matches the ember's own term.

**Change.** The Now line reads the live bar, the live dark rate, the live spell power, and the live recovery, the numbers `apply` already wrote. Next shows those numbers with one more rank of this ember and the rest of the night left as it is. The per sentence stays the ember's own term.

**Prove.** Take Warm Hands and one rank of Hearth-Warmth. The card's Now reads 125 Gloom, and the bar agrees. Next reads 140. Take Slow Breath as well as one rank of Banked Coals. Now reads the multiplied rate, about 83% of the original dark, and the per sentence still says this ember is the 12%.

**Stay.** The ember costs and gates stay. Do not fold a path's percent into the per sentence.

**Band.** B.

### 276. The spring's crest

**See.** High Spring says you jump 6% higher, and walk and run 4% faster. The run is 4% faster. A held jump clears about 12% more air than it did. The jump you make in the air is the old one.

**Where.** `paths_db.gd` `w_spring` sets `jump_mult` 1.06 and `move_mult` 1.04. `add_fx` multiplies both, because both keys end in `_mult`. `kindling.apply` sets `jump_velocity` to the base 5.2 times `jump_mult`, and sets walk and sprint to their bases times `move_mult`. It does not touch `air_jump_velocity` (5.8). `player.gd` puts `jump_velocity` straight into `velocity.y`. Gravity is 16 while you rise, and 16 × 0.62 once a held jump is under 1.6 upward. A held crest from 5.2 is about 0.89 m. The same crest from 5.2 × 1.06 is about 1.00 m. Releasing early multiplies the rise by `jump_cut` 0.5 and shortens both jumps together.

**Change.** The card keeps "6% higher." `jump_mult` becomes the square root of 1.06, so the held crest rises 6% and the upward speed rises by about 3%. Walk and run stay a straight 4% on the two speeds. The air jump stays 5.8 until a card names it.

**Prove.** Hold the jump against a post you can mark. The crest is about 6% above the old mark, and a tap of the key still cuts both jumps in half. A sprint across the green is 4% quicker. The second jump, in the air, matches the old crest.

**Stay.** Sheet 10 still owns the air jump itself. Light Feet' 5% and this 4% keep multiplying, so both cards together are about 9% on the speeds, each card telling its own share.

**Band.** B.

### 277. The rift's discount

**See.** Slow Breath, Road-Hardened, and the Forty-First Stone all say the dark gathers slower. Step into a rift with any of them and the rift is slower by the same share. Banked Coals already says "in the dark and by the Rift." The path cards do not.

**Where.** Those three nodes set `dark_mult` to 0.94, 0.92, and 0.94. `add_fx` multiplies. `kindling.apply` writes `gloom_rate_dark` and `gloom_rate_rift` both times `dark_mult`. The same key is on the stew (`0.9`), the feverfew (`0.85`), the posset (`0.88`), and Maud's Candle-Stub (`0.9`). Banked Coals' per sentence already names both places, and its 0.88 at one rank is the same single multiplier. The rift rate is 5.0 and the dark rate is 3.0 before any of this. A 6% card takes the rift to 4.7. The fire half of the feverfew and the posset stays with sheet 243.

**Change.** The three path cards, the stew, the feverfew, the posset, and Maud's Candle-Stub name the rift the way Banked Coals already does. One multiplier stays on both rates. The percents stay.

**Prove.** Take Slow Breath only. Stand in the dark and the bar climbs at 2.82 a second. Stand in a rift and it climbs at 4.7. The card says both. Stack Road-Hardened and both rates take the next 8% off what remains.

**Stay.** The sprint in the dark keeps its own extra rate from the walk sheet. Do not fold that into these cards.

**Band.** C.

### 278. A frozen foe and the well

**See.** The Rime Core says the lance and the nova hit a frozen foe twice as hard. They do. A well that has learned Event Horizon does too, and the ice breaks. The card stops at the lance and the nova, so the well's last moment is a surprise.

**Where.** `afflict.gd` `shatter` returns 2 and clears the freeze. `nova.gd` multiplies the ring by it. `magic_bolt.gd` multiplies by it only when the bolt is heavy, and the heavy bolt is the lance. `umbral_well.gd` `_collapse` multiplies by it only when `horizon` is set. A plain bolt skips that line. A well that has not reached the rank skips it too. The core's sentence names the lance and the nova.

**Change.** The sentence adds the well's Event Horizon beside the lance and the nova. The double stays 2, and it still breaks the ice. A plain bolt stays a single hit. A plain well's collapse stays a single hit. A staff blow stays off this sentence, because the staff never calls `shatter`.

**Prove.** Chill a wretch three times so it locks. A lance and a nova each hit for twice the card and the ice goes. Freeze another. A horizon well's collapse hits twice and the ice goes. A rift bolt on a frozen wretch hits once and leaves the ice. A well you have not ranked to Event Horizon hits once.

**Stay.** The chill is still 30% off speed for 2 s, and the lock is still 1.2 s at a crawl of 2% speed. Do not put the double on the staff or on an ordinary bolt.

**Band.** C.

Two circles share a centre and keep different ground. A gleaner is a chance of one more pinch. A kill past 28 m leaves the plate where it was. A step slows, and the card says so. The set names the two seconds the charm already named. One table pays every deed. A full lance reads six and a half. The Now line is the only count on the card, and it reads the mods it skipped. An ember's Now is the bar you actually hold. A held jump crests 6% higher. The rift is on the dark's card. A horizon well doubles a frozen foe, and the core says so. None of this is in the game yet.

### Part XXXI — sentences that already agree

Read on 6 November against the live Kindling, the paths, the oaths, the charms, the sets, and the works. Each line below was checked to the function that pays it. Leave it. A later sheet repeats one of these only when it brings a new number. The next free sheet is 291. Sheet 243 still owns the oath that calls a ward a mend. Sheet 256 still owns the ward's "roots." Sheet 248 still owns the peal paragraph. Sheet 228 still owns the mote against the gloom bar. Sheet 229 still owns the nova ring and `cast_power`.

### How a path key lands

`paths_db.gd` `add_fx` multiplies a key that ends in `_mult`, except `lance_charge_mult` and `step_cd_mult`, which multiply `lance_charge` and `step_cd`. Every other key adds. `kindling.refresh` builds `mods()` first (embers, oaths, charms, then gear) and then calls `PathsDB.apply`, then `HearthDB.apply`. A path percent is its own factor on top of what was already there. Hearthfire meals and works use the same rule in `HearthDB._fx`: a `_mult` key multiplies, anything else adds.

### Warm Hands

"+10 Gloom held." `gloom_add` 10, added. `gloom_max` is the exported 100 plus every `gloom_add`, including Hearth-Warmth's 15 a rank and the Hearthfire's tier. The card's ten is ten of that sum.

### Slow Breath

"Gloom gathers 6% slower in the dark." `dark_mult` 0.94, multiplied onto both rates. The rift half of the sentence is sheet 277. The 6% is the node's own factor.

### Coal-Carrier

"Fire takes the Gloom off you and mends you 20% faster." `lit_mult` 1.2, multiplied. `apply` writes both `gloom_drain_lit` and `wounds_mend_lit` times `lit_mult`. A fire's relief is both bars. The oath that pulls a ward into this sentence stays sheet 243.

### Long Rest

"Rested lasts 50% longer." `rest_add` 0.5, added, and `rest_secs` returns the base seconds times `(1 + rest_add)`. The grate's 0.25 and the beacon's extra 1.0 sit on the same key. The card is this node's half.

### Pilgrim's Appetite

"Room for a third meal." `belly` 1, added. `BELLY` is 2. `hearth.gd` `belly()` is that sum, and a third kind is refused at the cap. One of each kind stays the rule under the card.

### Ember Heart

"Every kill mends 1 Wound." `kill_relief` 1, added, and `mend` pays it. The 28 m on that pay is sheet 269. The wound, rather than the gloom bar, is what `mend` closes.

### Wide Hearth

"Every kindled fire's sanctuary reaches 1.5 m further." `reach_add` 1.5, added. `apply_reach` passes the tier's reach plus this add into `brazier.set_reach`, which moves the LightGrid radius and scales `lit_range` with it. The card's metre and a half is the path's own add, on top of the Hearthfire's tier.

### Edda's Hands

"+20 Gloom held, and Lantern Ward burns 2 s longer." `gloom_add` 20 and `ward_life` 2, both added. The ward's burn is `LIFE` 7 plus the rank's 3 plus `ward_life`. The 2 s is this node.

### Splinter of Sky

"+5% damage from every spell." `power` 0.05, added onto the 1.0 that already holds Kindled Will's 0.10 a rank. A bolt, a lance, a nova, and a peal all read `power`. The card's 5% is 0.05 of that multiplier.

### Quick Hands

"Every spell recovers 4% sooner." `cd` −0.04, added. `apply` sets each tuned cooldown to its vanilla time times `max(0.4, cd)`. At the stacks the night can actually wear, the result stays above that floor. The card's 4% is four points off the multiplier.

### Deep Marks, the path

"Umbral Nova deals 0.15 more for every Mark it detonates." `mark_dmg` 0.15, added. `nova.gd` sets `per` to 1.0, or 1.5 with the tally, plus `mark_dmg`, and a marked foe takes `1 + marks * per`. The ring's skip of the tenth a stack stays sheet 229. This 0.15 is inside `per` either way.

### Heavy Lash

"Rift Bolt's Lash hits 15% harder." `lash_power` 0.15, added onto the 1.0 `mods` starts with. `bolt.gd` multiplies a lash by `lash_power` and leaves an ordinary bolt alone. A naked node is a lash at 1.15. Hobb's knuckles add their own 0.25 on the same key. The boss chip of 0.7 stays sheet 236.

### Short Fuse

"Ember Lance charges 10% faster." `lance_charge_mult` 0.9. `add_fx` multiplies that into `lance_charge`. `apply` sets `max_charge` to 0.9, times 0.75 at Quick Draw, times `lance_charge`. The card's 10% is this factor.

### Wide Ember, the path

"Ember Lance bursts 0.4 m wider." `lance_blast` 0.4, added. `lance.gd` adds `lance_blast` to the lerped blast. The rank's own extra metre is a different +1, at Wide Ember the rank. Both can be worn. Each card tells its own metres.

### Open Hand

"+8% damage from every spell." `power` 0.08, added, the same key as Splinter of Sky. Worn together they are 0.13 on top of Kindled Will, and each card says its own share.

### What the Door Kept

"Every spell recovers 8% sooner, and +5% damage." `cd` −0.08 and `power` 0.05, both added. Same two keys as Quick Hands and Splinter of Sky. The shares stack by addition. Each card keeps its own number.

### Light Feet

"Walk and run 5% faster." `move_mult` 1.05, multiplied onto `walk_speed` and `sprint_speed`. High Spring's 1.04 multiplies after it. Both cards together are about 9% on the two speeds. The jump is High Spring's own card.

### Long Stride, the path

"Rift Step reaches 1 m further." `step_range` 1, added. `apply` sets the player's `step_range` to the base 7.5, plus 2 at the rank, plus every `step_range`. The card's metre is this node. The Forty-First Stone adds its own 1.5 on the same key.

### Ash-Gleaner

"Every 5th kill leaves a second pinch of grave ash." `glean` is a flag. `hearth.gd` `_on_killed` counts `gleaned` and pays one `grave_ash` when the count is a multiple of 5. A great one counts toward the five. The 28 m and the boss skip in sheet 269 belong to the traits and to `kill_relief`, and this counter is the one that does not use them.

### Slip the Hand

"Untouchable 0.1 s longer after a Rift Step." `step_evade_add` 0.1, added. `apply` sets `step_evade` to 0.35, or 0.60 at Slip the rank, plus this add. `shadowstep` writes that into `_evade_t`. The card's tenth is this node. The Now line that forgot to print it is sheet 274.

### Step-Weaver

"Rift Step recovers 10% sooner." `step_cd_mult` 0.9, folded into `step_cd` by `add_fx`. The step's cooldown is the vanilla 2.1, halved when the door is sworn, times `step_cd`, times the global `cd`. The card's 10% is this factor. The Now line that skipped `step_cd` is sheet 274.

### Road-Hardened

"Gloom gathers 8% slower in the dark." `dark_mult` 0.92, multiplied, both rates. The rift clause is sheet 277. The 8% is the node's own factor, taken off whatever Slow Breath and Banked Coals have already left.

### The Forty-First Stone

"Rift Step reaches 1.5 m further and recovers 15% sooner; Gloom gathers 6% slower." `step_range` 1.5 added, `step_cd_mult` 0.85 folded into `step_cd`, `dark_mult` 0.94 multiplied. Three keys, three consumers, three shares. The rift clause on the third share is sheet 277.

### Hearth-Warmth

"+15 Gloom held" a rank, three ranks. `mods` starts `gloom_add` at `15 * rank`. The per sentence matches. The Now line that prints `100 + 15 * rank` as if it were the whole bar is sheet 275.

### Banked Coals

"Gloom gathers 12% slower in the dark and by the Rift," a rank, three ranks. `dark_mult` starts at `1 - 0.12 * rank`. One multiplier, both rates, and the sentence already names both. The Now line's "88% drift" at one rank, blind to every other discount, is sheet 275.

### Kindled Will

"+10% damage from every spell," a rank, three ranks. `power` starts at `1 + 0.1 * rank`. Paths and charms add after that. The per sentence is this ember's tenth a rank.

### Quickened Flame

"Every spell recovers 7% sooner," a rank, two ranks. `cd` starts at `1 - 0.07 * rank`. The per sentence matches. Open Sky, once sworn, subtracts a further 0.15 in `mods` before the paths run.

### Charm Cord

"Wear a third charm," one rank. The ember's max is 1 and its gate is 1. The third socket is this ember. It was left as a socket, and the socket is what the card names.

### Oath of the Hollow

"Every kill mends 4 more Wounds." `mods` adds 4 to `kill_relief` when the oath is sworn. `mend` pays the sum. The 28 m is sheet 269. The word "more" matches an add on top of Ember Heart and a Reaper piece.

### Oath of the Lash

"Every 2nd bolt in a chain, not every 3rd." `lash_every` is set to 2. `bolt.gd` lashes when the chain count divides by `_every()`, and the default in `mods` is 3. The Now line already prints "2nd" from that key. The stock paragraph that can still say "every 3rd" on the same card is sheet 274.

### Oath of the Pyre

"Charges 30% faster, and a full charge hits 50% harder." `mods` sets `pyre` and multiplies `lance_charge` by 0.7. `lance.gd` multiplies a full charge's damage by 1.5 when `pyre` is set, and leaves a tap alone. The 30% and the 50% both match. The Now line that still tops out at 4, and forgets the 1.5, is sheet 273.

### Oath of the Tally

"1.5 damage for every Mark it detonates (was 1)." `tally` is set. `nova.gd` uses 1.5 as `per` before `mark_dmg` is added. The was-1 matches the untallied `per`. The ring's other skip stays sheet 229.

### Oath of the Open Door

"Recovers twice as fast, and every step mends 3 Wounds." The step's cooldown is halved when `door` is set, and `step.gd` calls `mend(3)` on a step that landed. The Splinter of the Door legend sets the same flag and the same two promises. The halving happens before `step_cd`.

### Keen

"20% faster," burst "1.8 to 2.3," and a bend toward a foe near the aim. Rank I multiplies speed by 1.2 (34 becomes about 41, a lash's 38 becomes about 46) and adds 0.5 to blast, and sets `seek`. The ordinary burst is the pair the card names.

### Deep Marks, the rank

"3 Marks," "0.8 m wider," and a rune that drags in to the burst. A lash at rank II sets marks to 3 and adds 0.8 to blast, and hooks `_rune_pull`. An ordinary bolt stays at one mark. The Now line's missing burst width is sheet 274. The rank sentence itself has the 0.8.

### Through

"Ordinary bolts pass through bodies, marking each one. The Lash still bursts." Rank III sets `pierce` on the bolt after it is armed, and only when it is not a lash. The lash still takes the burst path.

### Quick Draw

"Charges 25% faster" and a perfect throw at "+30%." Rank I multiplies `max_charge` by 0.75. `PERFECT_MULT` is 1.3, and the window is `PERFECT` 0.2 s after the snap. The white snap is that window.

### Wide Ember, the rank

"Bursts 1 m wider; a tap hits 25% harder." Rank II adds 1 to the blast and lifts the tap from 2.0 to 2.5. Three cinders are the rank's third clause, thrown from the burst. The path's own 0.4 m is the other card.

### Cinder Scar, the rank

"A full charge leaves the ground burning for 3 s." The scar's life is 3 s. Sheet 255 still owns the light that spills past the 2.6 m burn. The duration on the card matches the scar.

### Wider Ring

"7.2 m (was 6)," and an echo "half a second later: 0.5 damage." `radius()` returns 7.2 at rank I, `ECHO_DELAY` is 0.5, and the echo hits for `ECHO_DMG` 0.5 times power. The base radius on `skill_nova.gd` is 6.

### Short Wick, the rank sentence

"Recovers in 5.5 s (was 7). … mends 2 Wounds." `apply` sets the nova's cooldown to 5.5 at rank II, from a vanilla 7. `_motes` calls `mend(2)`. The rank sentence is the true one. The Now suffix that says Gloom is sheet 274.

### Undertow

"Past 2.5 m … dragged in to you instead of thrown out." `UNDERTOW_MIN` is 2.5. Past it, the shove points back toward you. `SHOVE` is 10, the inward shove is capped at 11, and from 2.5 m out to the ring that cap still covers the gap. Inside 2.5 m the shove stays outward.

### Long Wick

"3 s longer (10 s)," and a pulse "every 2 s." Rank I adds 3 to the ward's 7. `WardAura.PULSE` is 2. The pulse throws foes in the band from `RADIUS - 3` to `RADIUS + 1`. The light past that ring stays sheet 211. The 10 s and the 2 s match.

### Close Watch

"17 s (was 24)," and "other spells recover 30% faster" while you stand in the ward. `apply` sets the ward's cooldown to 17 at rank II. `BOOST` is 1.3, and it ticks every slot except the ward itself, while `boost_until` is live. The aura refreshes that stamp when you are inside `LanternWard.RADIUS`.

### Mirror Flame

"Spit that reaches the ward's light is turned back on the nearest spitter, and Marks it." Rank III sets `mirror`. The aura pops an `ENEMY_SHOT` inside the ward's radius and returns fire. The radius it uses is the ring.

### Long Stride, the rank

"9.5 m (was 7.5)," and a shock "within 2.5 m." `apply` adds 2 to `step_range` at rank I. `SHOCK_R` is 2.5 and `SHOCK_DMG` is 0.5. The arrival throws what stands in that disc.

### Slip, the rank

"0.6 s (was 0.35)," and "the first bolt within 1.5 s is a Rift Lash." Rank II sets the base evade to 0.6, and `SLIP` is 1.5. `bolt.gd` consumes that window. Slip the Hand's extra tenth is the path, added after the 0.6.

### Rend

"1.5 damage and a Mark to all within 3 m." `rift_rend.gd` waits `DELAY` 0.4 s, then hits for `DMG` 1.5 times power and `add_mark(1)` inside `RADIUS` 3, flat, with a little vertical room. The deal-skip on that hit stays with sheet 249. The numbers on the card match.

### Rift Tether, the ranks

Long Chain is 24 m against a base 18. Fork is a second foe within 6 m. Reel is 1 damage per mark inside 2.5 m. `growth.gd` prints 24 or 18, and 2 or 1 dragged, from those ranks. The base paragraph that can still say 18 m on the same card is sheet 274. The rank sentences themselves match.

### Umbral Well, the collapse

The learned text says the collapse is "1 damage, +0.5 per Mark." `_collapse` does that when Event Horizon is off: `1 + 0.5 * marks`. Horizon spends the marks and uses `1 + marks * (1 + mark_dmg)`, which is the rank's "as Umbral Nova does." Deeper Pull's 5.5 m and 4 s match the rank against a base 4.5 m and 3 s. The Now line prints those.

### Bound Shade, the ranks

The base is `LIFE` 14, a dart every 1.1 s, `DART_DMG` 0.5 and a mark. Keen Eyes sets the rate to 0.75 and turns seek on. Twin Shades binds two. The jar charm adds 6 s and the burst inside 1.5 m at 0.5, and its own card says both. The Now line that forgets `shade_life` is sheet 274.

### The Founder's Peal, the cone

Reach 9, or 11 at rank I. Half-angles 37.5 and 55, which is a 75-degree cone and a 110-degree cone, and `_stats` prints 75 and 110. Damage is `DMG` 1 times power, plus the resonance term at rank II. The stagger exception for a great one is sheet 248 and the Now line's wording is sheet 274. The degrees match.

### Ferryman's Hook, the charm

"Marks everything along its chain, and recovers 2 s sooner." The flag `hook` does both: the tether marks along the chain, and `apply` subtracts 2 from that cooldown. The set and the trait that share the flag and skip the seconds are sheet 271. This card already has them.

### Ember Rosary

"A Mark for every second it burns." Burn ticks every 0.5 s. The rosary marks on every even tick, so the first mark lands at 1 s and the next at each second after. The card's second matches the even ticks.

### Sexton's Wisp-Jar

"Stays 6 s longer," and "0.5 more to all within 1.5 m." `skill_familiar.gd` adds 6 to `LIFE` when `jar` is set. `bound_shade.gd` bursts for `0.5 * power` inside 1.5 m when the dart's target already held a mark. Both numbers match the card.

### Edda's Ferrule

"Recovers 20% sooner," and "every foe within 2 m … takes a Mark." `step_cd` 0.8 multiplies the step's cooldown. `_ferrule` marks inside 2 m of the arrival. The Now line that forgot `step_cd` is sheet 274. The charm's own sentence has the 20% and the 2 m.

### Hobb's knuckles

"The Lash hits 25% harder." `lash_power` gains 0.25. A naked charm takes a lash from 1.0 to 1.25. Heavy Lash's 0.15 adds on the same key when the path is taken too.

### Lisle's Tally Board

"0.25 more for every Mark it detonates." `mark_dmg` gains 0.25, the same key as the path's 0.15 and the ferryman two-piece's 0.15. Nova's `per` includes the sum.

### The Heart-Stone

"+10 Gloom held, and fire … 15% faster." `gloom_add` 10 and `lit_mult` 1.15. The gloom adds. The 1.15 multiplies both the drain and the mend, the same pair Coal-Carrier uses.

### Cinder Censer

"Ember Lance bursts 0.6 m wider." `lance_blast` gains 0.6, the same key as the path's 0.4 and the Kindler four-piece's 0.6. Each card says its own metres.

### The Scraped Face

"Every spell recovers 5% sooner." `cd` gains −0.05. It sits on the same multiplier as Quick Hands and Quickened Flame.

### Kindler's Regalia

Two pieces: "charges 10% faster," from `lance_charge` mul −0.1, which `gear_stats.fold` turns into a multiply by 0.9. Four pieces: blast `+0.6`, and the `rosary` flag. The 10% and the 0.6 match. The rosary's second is the Ember Rosary's second.

### Lay Brother's Tally

Two pieces: "+15 Gloom held," added. Four pieces: the `tally` flag, so nova's `per` is 1.5, and `kill_relief` +2. The oath's 1.5 and this four-piece share the flag. The 2 wounds are an add, and the 28 m on them is sheet 269.

### Bellwright's Garb

Two pieces: "the Lash hits 20% harder," `lash_power` +0.2. Four pieces: `cd` −0.05, and `lash_every` set to 2. A naked four-piece lashes every second bolt and takes 5% off recovery. The set's 20% is 0.2 on the lash multiplier.

### The legend of the Door

"Recovers twice as fast, and every step mends 3 Wounds." The Splinter sets `door`. That is the oath's flag, and the oath's two effects are what the legend names.

### The legend of the lamp

"Stays 6 s longer, and its darts burst on a Marked foe." The Glass of the Unlit Lamp sets `jar`. The seconds and the burst are the wisp-jar's, and that card has the 1.5 m and the 0.5 the legend leaves in the word "burst."

### Iron fire-baskets

"Every kindled fire's sanctuary reaches 1 m further." `reach_add` 1, added, the same key as Wide Hearth's 1.5 and the fire-dogs' 0.5. `set_reach` grows the sanctuary and the light together. The card's metre is this work.

### Bellows for the fires

"25% faster." `lit_mult` 1.25, multiplied onto the drain and the mend. The same pair as Coal-Carrier. A fire is what the card names.

### Shod the staff

"+6% damage from every spell." `power` 0.06, added. The same key as Kindled Will and the rift paths.

### A fire-grate for the green

"Rested lasts 25% longer, and +10 Gloom held." `rest_add` 0.25 and `gloom_add` 10. `rest_secs` multiplies by `(1 + rest_add)`, so this work is a quarter on its own, and Long Rest's half stacks with it by addition inside that one factor.

### Grave-iron fire-dogs

"0.5 m further, and +6 Gloom held," for 4 grave-iron. `reach_add` 0.5 and `gloom_add` 6. The price in iron is the work's cost. The metres and the gloom match.

### The Count

"Every Mark Umbral Nova detonates takes 0.6 s off its recovery." When the rite is known, `_count_refund` subtracts `0.6 * marks` from the nova's cooldown after the cast has set it. The 0.6 matches.

### Deep Reliquary

"13 m (was 9.5). Wake lingers 5 s (was 3)." The progression nova reads 13 when `deep` is set, and 9.5 otherwise, and the wake follows the same flag out to 5 s. Sheet 247 still owns the toast that says 7.5 for a pull whose disc is 9.5. This rite's own 13 and 5 match.

### Open Sky

"15% sooner, and you hold 20 more Gloom." `mods` subtracts 0.15 from `cd` and adds 20 to `gloom_add` when the rite's rank is above zero. Both land before the paths add their own shares.

### What a kill pays

`level.gd` `XP`, paid by `hearth.gd`: a common kill 3, tough 5, elite 15, a Deeper Night elite 25, a rare 40, a keeper 150, a quest 60, a seal 50, a kindled fire 40, a homecoming 30, a keepsake 25, a first banner 20, a gather 5. The rested pool doubles only the kill sources, and sheet 111 owns that split. The duplicate table that does not pay is sheet 272.

### What a rest fills

`REST_FILL` is half a level and `REST_CAP` is a level and a half, measured on the current level's need. While the pool lasts, a kill's memory is doubled and the bonus is spent out of the pool. The toast and the bar stay with the sheet that already owns them. `REST_FX` is `dark_mult` 0.88 and `cd` −0.04, and the Kindling's comfort line says 12% and 4%, which is that pair.

### What it costs to unremember

`UNREMEMBER_PER` is 3 grave ash for each path node you have taken. The points come back and the ash does not. It is offered at Hearthward's fire. The cost line in `why_not_unremember` prints that product.

### What the gear fold does

`gear_stats.fold` multiplies a "mul" by `max(0.2, 1 + v)`, adds an "add," and takes the min on a "set." Kindler's −0.1 is a multiply by 0.9, which is the 10% the two-piece names. A "set" of `lash_every` to 2 takes the lower of the current value and 2, so an oath already at 2 stays at 2.

### What the panel already prints true

A plain bolt's damage is `power`, its burst is 1.8 plus 0.5 at Keen, and its speed is 34 times 1.2 at Keen. A nova's ring is 6 or 7.2, its recovery is 7 or 5.5 times `cd`, and its per-mark figure includes `mark_dmg` and the tally. A ward's burn is 7 plus 3 at Long Wick plus `ward_life`, and its recovery is 24 or 17 times `cd`. A step's reach is 7.5 plus 2 at the rank plus `step_range`. A tether's reach is 18 or 24. A well's disc is 4.5 or 5.5 and its hold is 3 or 4. A familiar's dart is 0.5 times power, every 1.1 s or every 0.75 s. A peal's cone is 75 or 110 degrees. Those fragments of `_stats` match. The fragments that do not are sheets 273 and 274.

### Black bread and dripping

"Hearty: +12 Gloom held for 6 minutes." `secs` is 360, which is six minutes of play. `gloom_add` 12 is added by `HearthDB._fx` for as long as the dish has time left. One hearty at a time. The twelve and the six minutes match.

### Fen-eel stew

"Warming: Gloom gathers 10% slower for 6 minutes." `secs` 360. `dark_mult` 0.9 multiplies both rates. The 10% and the six minutes match. Naming the rift on this card is sheet 277.

### Mulled ale

"Sharp: +6% damage from every spell for 5 minutes." `secs` 300. `power` 0.06 is added. The 6% and the five minutes match. It shares the power key with Kindled Will and the rift paths, and the ale's own share is the 0.06.

### Bramble-honey cake

"Hearty: +22 Gloom held for 9 minutes." `secs` 540. `gloom_add` 22 is added. Nine minutes is 540 seconds. The cake replaces bread if bread was the hearty already in the belly, because a kind already eaten is replaced.

### Feverfew tonic

"Gloom gathers 15% slower, and fire takes it off 15% faster, for 9 minutes." `secs` 540. `dark_mult` 0.85 and `lit_mult` 1.15. The dark percent and the nine minutes match. The fire clause also mends, and that wording stays with sheet 243. The rift on the dark half stays with sheet 277.

### Bitter rue

"Spells recover 7% sooner and hit 4% harder, for 8 minutes." `secs` 480. `cd` −0.07 is added and `power` 0.04 is added. Eight minutes is 480 seconds. Both shares match the sentence.

### Ash-bloom posset

"Gloom gathers 12% slower, and fire takes it off 10% faster, for 8 minutes. Takes 2 ash-blooms." `secs` 480. `dark_mult` 0.88 and `lit_mult` 1.1. The mats are two `ash_bloom`. The percents, the eight minutes, and the two blooms match. The fire clause's wound half stays with sheet 243. The rift on the dark half stays with sheet 277.

### Bloom-and-honey bannock

"Hearty: +28 Gloom held for 11 minutes. Takes 3 ash-blooms." `secs` 660. `gloom_add` 28 is added. Eleven minutes is 660 seconds. The mats are three `ash_bloom`. The twenty-eight, the eleven minutes, and the three blooms match.

### How a dish is worn

`BELLY` is 2, and Pilgrim's Appetite adds one. `hearth.gd` refuses another kind once the belly is full, and a second dish of a kind you already hold replaces that kind. `HearthDB.apply` folds a meal's fx only while `left` is above zero. The minutes on the cards are the `secs` the buy writes into `left`.

### Smelt ash into an ember shard

`SMELT` is 6 grave ash for 1 ember shard, and the shop builds its sentence from those two numbers, so the row cannot drift from the spend. `smelt` spends the ash and gives the shard. Six for one is the dear way. The iron trade is the cheap way, and its card says so.

### Smelt grave-iron into ember shards

"2 grave-iron and a pinch of ash into 2 ember shards." The trade's price is 1 ash, its mats are 2 `grave_iron`, and its gives are 2 `ember_shard`. `trade` spends the price and the mats, then gives the shards. Two shards from ash alone would be 12 ash. One ash and two iron is the cheaper row the sentence describes.

### Distil ash-blooms

"Six ash-blooms down to a hard pale bead" the fires take as a relic fragment. The trade gives 1 `relic_fragment` for 6 `ash_bloom`, and the row's price beside that sentence is 4 ash. The six and the one bead match. The 4 ash is the price on the row, not a second number hidden in the pot.

### Cinder Core, the bolt

"0.3 damage every half second for 2 s." A cinder bolt calls `Afflict.burn` for 2.0 seconds at `BURN_DMG` 0.3, and `TICK` is 0.5. Four ticks, 0.3 each, is the sentence. The rosary's mark on every even tick stays with the Ember Rosary above.

### Cinder Core, the kindled lance

The same card says an Ember Lance on a marked foe "kindles the Marks." `_kindle_marks` hits for 0.5 times the marks times power, and then burns for 2.5 s at 0.3 × 1.3. The parenthetical names that flare. The bolt's own 2 s and 0.3 stay the bolt. The hotter burn is the lance's, and it stays.

### Rime Core, the chill

"Slow by 30% for 2 s, and the third chill freezes them in place for 1.2 s." `CHILL_SLOW` is 0.7, so a chilled foe keeps 70% of its speed, for `CHILL_TIME` 2 s, and each new chill refreshes that window and adds a stack. The third stack sets `frozen` to `FREEZE_TIME` 1.2 and drops walk speed to 2% of base, which over that second and a fifth is a few centimetres. The 30%, the 2 s, the third, and the 1.2 s match. The double on a lance, a nova, and a horizon well is sheet 278.

### What a rest costs in standing

`hearth_db.gd` `REST_STAND` is 3 seconds at Hearthward's fire or inside the Keg's rectangle before the comfort buff fills. The director's own `REST_STAND` is also 3 seconds of standing in a lit fire before it counts a rest of its own. A tide breaks sooner: the director's `SAFE_STAND` is 1.5 seconds in a lit fire. Those are three different jobs, and each constant matches its own job. The comfort line's 12% and 4% stay with `REST_FX`.

### What the beacon adds

The beacon's work text says rested lasts as long again. `rest_secs` adds 1.0 to `rest_add` when that service is open, which doubles the seconds on top of Long Rest and the grate. The "as long again" is that extra 1.0. It stacks by addition inside the one factor, the same way the grate's quarter and Long Rest's half do.

### The Hearthfire, tier by tier

`TIERS` is what `apply` and the Kindling's hearth page read. Banked is the fire you find: reach 0, gloom 0, comfort 0. Drawing adds 1 m, 8 gloom, comfort 2, for 16 ash, and opens the smith. Roaring adds 2 m, 16 gloom, comfort 4, for 26 ash and 1 fragment, and opens the herbs. Blazing adds 3 m, 24 gloom, comfort 6, for 36 ash and 2 fragments, once three fires are kindled and one keeper is down, and opens the bells. Beacon adds 4.5 m, 34 gloom, comfort 9, for 48 ash and 2 fragments, once four fires are kindled and two keepers are down, and opens the beacon. Each reach is added to the brazier's own radius by `apply_reach`. Each gloom is added to `gloom_add`. Comfort is the tier's number plus every homecoming plus every work, and a full rest is 240 seconds plus 30 a comfort point, times `(1 + rest_add)`.

### What each tier opens

The smith is Hild, at tier I: baskets, bellows, and the ash smelt. The garden is Bet, at tier II, and it also wants her home. The bells are tier III: a bell at every kindled fire, and a ring that walks you to another. The beacon is tier IV: rested as long again, which is the extra 1.0 on `rest_add` already checked above, and the valley's fires at the 4.5 m add, which is the largest reach in the table. The sentences on those four services match the tier that unlocks them.

### What a piece costs to raise

`gear_db.gd` `upgrade_cost`, while the piece is under its cap, asks ash `4 + 4 * (level + 1) + 3 * rarity` and shards `(level + 1) * (1 + rarity)`. A Worn piece at level 0 asks 8 ash and 1 shard. A Reliquary piece, rarity 3, at level 0 asks 17 ash and 4 shards. An Umbral piece, rarity 4, at level 0 asks 20 ash and 5 shards. The panel that prints the pair is reading this function. The formula is the price.

### How high a piece can go

`RARITY` caps the level at 2 Worn, 3 Kindled, 4 Hallowed, 5 Reliquary, 6 Umbral. Strength on the same row is 1.0, 1.25, 1.5, 1.8, 2.1, and `affix_value` scales a roll by that strength and by another 10% a level. At the cap, `upgrade_cost` returns empty and the raise is refused. The names and the caps are that table.

### What salvage and a raise spend

Raising spends the ash and the shards the cost names, and it refuses with the count you are short. `salvage_value` gives shards back: 1, 2, 4, 7, or 12 by rarity from Worn up to Umbral, plus the piece's level. A Hallowed piece at level 2 comes back as 6 shards. The raise and the salvage share `ember_shard`. Smelting ash and smelting iron are the two ways onto that pile, and both were checked above.

### Raising the Hearthfire

`why_not_raise` walks the next tier in order. It names `need_text` until the valley test passes, then the fragments, then the ash, and it allows the spend only at Hearthward's own fire: within 9 m of `(0, 33)`. The spend takes the tier's ash and fragments, steps the tier by one, widens every kindled fire, and saves. At Beacon the refusal is "The Hearthfire burns as high as it will." The order of those sentences is the order of the checks.

### Maud's Candle-Stub

"Gloom gathers 10% slower in the dark." `dark_mult` 0.9 multiplies both rates. The 10% matches. The rift on the card is sheet 277, with the path nodes and the meals that share the key.

### Pell's Red Thread

"Rift Step reaches 1.5 m further." `step_range` gains 1.5, the same add as the Forty-First Stone. The metre and a half is this charm's own share.

### Corvin's Lamp-Glass

"Lantern Ward burns 2 s longer." `ward_life` gains 2. The ward's burn is 7, plus 3 at Long Wick, plus this 2, plus any other `ward_life`. The charm's own two seconds match.

### Lisle's Tally-Bead

"Every kill mends 2 more Wounds." `kill_relief` gains 2. `mend` pays the sum. The 28 m on that pay is sheet 269. The word "more" is the add.

### Clapper of the Last Bell

"+8% damage from every spell." `power` gains 0.08, the same add as Open Hand. The charm's own 8% matches.

### Woodsman's Ring

"Ember Lance charges 15% faster." `lance_charge` is multiplied by 0.85. A charge at 0.85 of its time is 15% sooner. Quick Draw's 0.75 and the pyre's 0.7 multiply on the same key, each card keeping its own share.

### Chip of the First Waystone

"Lantern Ward and Umbral Well hold 1.5 s longer." `ward_life` and `well_life` each gain 1.5. The ward adds it to its burn. The well adds it to its life. Both halves of the sentence match.

### Nan's Chalk

"The hook and a Bound Shade's darts lay 2 Marks, not 1." The flag `chalk` is what `skill_tether.gd` and `skill_familiar.gd` read, and both lay 2 marks when it is set and 1 when it is not. The ferryman four-piece sets the same flag. The two and the one match.

### What Hild's works cost

The baskets are 18 ash, at the smith's tier. The bellows are 22 ash, one tier later. Shod the staff is 26 ash and 1 fragment. The grate is 30 ash and 1 fragment, and Hild refuses it until the Hearthfire is III. The fire-dogs are 10 ash and 4 grave-iron, and they can be bought as soon as the smith is open. Each price is the `price` on that work, and a fragment or a mat is the extra the row names. The metres and the gloom those works pay were checked with the works themselves.

### Where a raise is allowed

Hearthward's own fire is the brazier within 9 m of `(0, 33)`. That circle is the home test. It is not the encounter haven at `(4, 36)`, and it is not the 34 m or the 40 m around that other point. Sheet 267 keeps those two havens as one circle. This 9 m is the only ground that will take the Hearthfire's ash. A kindled fire anywhere else can still be sat at, fed, and walked from. The raise stays on the green.

The sentences in this part already match the night that pays them. The next free sheet is 291. The sheets in Part XXX are still the ones the night has not taken.

## Part XXXII — the card, the leap, the tell

The Hearthfire's summary and its raise line count different fires. A lodestar's second leap keeps half of the seventy percent the core promised. A red tell breaks on a blow of 2, and the lesson names two weapons. A bulwark's boards take the lance and leave the body for later. The Kindling foot still prints W and Space. The Thornwarden's song uses one word for a half and a quarter. A brood's body will not spoil the hatch. A slag patch, an acid pool, and a tollman's clang stay at their Dusk numbers after the tier has deepened every other blow.

### 279. The Hearthfire's two lines

**See.** The card on the Hearth page says how far kindled fires reach, and how much gloom you hold. The raise line under it says what you have now, and what the next tier gives. Take Wide Hearth and the card grows. The raise line stays on the tier. Take Warm Hands and the bar grows. Both lines stay on the tier's gloom, which at a banked fire is zero.

**Where.** `ui/growth.gd`, the hearth card and the hearth detail. The card prints `HearthDB.reach(hs, live reach_add)`, which is the tier's own reach plus every `reach_add` on the live mods, and then `TIERS[t].gloom`, which is only the tier. Comfort is the live `comfort()`. The detail prints the next tier's reach and gloom beside the current tier's reach and gloom. Banked is 0 m and 0 gloom. Drawing is 1 m and 8. Wide Hearth adds 1.5 to `reach_add`. Warm Hands adds 10 to `gloom_add`. Edda's Hands adds 20. Open Sky adds 20. The baskets add 1 m. The fire-dogs add 0.5 m and 6 gloom. The grate adds 10 gloom. A meal adds its own gloom for its minutes. The card at a banked fire with Wide Hearth and Warm Hands reads "+1.5 m" and "+0 Gloom held." The detail, offering Drawing, reads "reach +1.0 m (now +0.0); Gloom held +8 (now +0)." The bar is already 110.

**Change.** Both lines use the live sanctuary and the live gloom above 100. The detail's next numbers are those live totals plus only the next tier's own delta. At the example, the card reads +1.5 m and +10 gloom, and the detail reads reach +2.5 (now +1.5) and gloom +18 (now +10). Comfort stays the live call. The tier's own share can stay in the lore. The two lines agree with each other and with the bar.

**Prove.** Bank the fire. Take Warm Hands and Wide Hearth. The card and the detail's "now" both read +1.5 m and +10 gloom. Preview Drawing. It offers +2.5 m and +18 gloom. Raise it. The card reads +2.5 m and +18 gloom. Eat a gloom meal. The card and the detail rise by that meal, and they still match.

**Stay.** Sheet 275 still owns the ember line that prints one rank as the whole bar. The home test stays the 9 m around `(0, 33)`. Wide Hearth stays 1.5. Warm Hands stays 10. A raise still spends the tier's ash on the green.

**Band.** A.

### 280. The lodestar's second leap

**See.** The Lodestar core says a bolt leaps to the next foe within 9 m, twice, at 70% each leap. The first leap is 70%. The second is 70% of that 70%, which is 49% of the bolt that hit the first body. At a plain bolt the third wretch shows 0.5.

**Where.** `upgrade_db.gd` the Lodestar text. `magic_bolt.gd` `_leap`. `LEAP_RANGE` is 9, `LEAPS` is 2, `LEAP_DMG` is 0.7. The strike lands at the current `hit_dmg`, and the leap then does `hit_dmg *= 0.7` for the next body. A bolt of 1 hits for 1, then 0.7, then 0.49. The leap picks the nearest living foe inside 9 m that this bolt has not already hit, in any direction. The core's "the next within 9 m" is that nearest body. Sheet 236 still chips a bolt that is not heavy, so this prove is three wretches, where a bolt is a whole bolt.

**Change.** Each leap hits for 70% of the bolt that struck the first foe. The second leap stores that first damage and multiplies it by 0.7, instead of multiplying the already reduced hit. Two leaps, 9 m, and the nearest body stay.

**Prove.** Three wretches inside 9 m of each other, power at 1. The first takes 1. The next two each take 0.7, and both numbers read 0.7. A fourth wretch past 9 m is left out. A second leap that would have been 0.49 is gone.

**Stay.** The lash still does not split, which is the Prism's sentence. A boss still chips a plain bolt, sheet 236. The leap still will not hit a body this bolt has already hit.

**Band.** B.

### 281. What breaks a red tell

**See.** A wretch rears, and the lesson says to hit the red with a lash or a lance. A plain bolt leaves the tell up. So does the staff's first swing. The staff's third swing breaks it, and the lesson never named the staff. A chanter's tell dies to the plain bolt, because his poise is under that bolt. On a boss the same lash is chipped below the line that breaks a tell, and the lance still clears it.

**Where.** `enemy.gd` `_resolve` of a windup, and the hint `break_windup`. A blow breaks the red at once when the damage that landed is at least 2, or when poise fills. Poise starts at 2.6 and drains at `poise / 2.5` a second. A plain bolt is 1. A lash is 2. A lance, tap or full, is heavy, so sheet 236 leaves it whole: the tap is 2 and the full charge is 6.5. The staff is 1.2, then 1.2, then 2.3. A chanter's poise is 0.9, a tollman's is 0.8, a mite's is 0.5. `Hints.once` for a cast says a lesser caster breaks to any blow, and a great one breaks to a heavy blow. `_interrupts` uses the damage after absorb: a lesser foe breaks to any blow, and a boss breaks to a weak point, or to damage of 2 or more, or to a heavy bolt. A lash of 2 on a boss becomes 1.4 before that test, so it misses the line. The lance is heavy and does not. The staff is not a bolt, so the third swing of 2.3 still clears it.

**Change.** The windup lesson says a blow of 2 or more breaks the red at once, and a lighter blow breaks it when that body's poise fills. It names the lash and the lance and the staff's last swing for a camp body, and it says a boss chips the lash under that line while the lance and the last swing still clear it. A plain bolt still does not break a fresh wretch. The cast lesson says any blow on a lesser caster, and on a great one a blow that still counts as 2 after the chip, or the lance, or the knot. The 2, the poise values, and the chip stay.

**Prove.** A wretch's red. A plain bolt leaves it. A lash breaks it. The staff's first swing leaves it. The third breaks it. A chanter's red dies to one plain bolt. The Warden, mid-cast: a lash leaves the cast, a lance breaks it, and the knot breaks it. The line has named those three cases.

**Stay.** Sheet 213 still owns the wedge being wider than its paint. Sheet 236 still owns the seven tenths. Sheet 50 still owns the knot's 1.6 and the poise that follows it. Sheet 245 still owns a feint that fills a bar with no red. The tells do not get shorter.

**Band.** A.

### 282. The bulwark's boards

**See.** The lesson says the shield turns blows from the front, and that a lance breaks it. A full lance does. The body behind it takes nothing from that throw. A tap, which is also a lance, chips a third of the boards and leaves them up. Any front blow chips them. Circling still walks the blow onto the body.

**Where.** `bulwark.gd` `_absorb`. `SHIELD_HP` is 6. A blow from in front, dot of facing at least 0.3, about seventy degrees to either side, subtracts its damage from the shield, or twice that when the damage is 3 or more, and returns 0 to the body. A full lance is 6.5, so the boards take 13 and break, and the 6.5 never reaches the life. A tap is 2, so the boards go from 6 to 4. A lash of 2 does the same. The staff's last swing is 2.3 and chips 2.3, under the double. While the state is `RECOVER` and the timer is still negative, the boards are down and the body takes the blow. A stagger starts that timer at `-(1.1 - 0.55)`, so the first half-second of the reel is an open body. The hint is `bulwark`.

**Change.** The lesson says any front blow chips a shield of 6, a blow of 3 or more chips twice, and a full lance breaks the boards in one throw and leaves the body for the next blow. A tap chips 2. Circling still walks past the boards. A broken bulwark takes the blow on the body while the reel's timer is negative. The 6 and the double stay.

**Prove.** Face one. A full lance pops the boards and the life bar does not move. The next bolt moves it. A tap moves the boards by 2 and the life bar stays. Step to the flank and a bolt moves the life bar at once. Stagger it and hit during the first half-second. The life bar moves while the boards are still in the air.

**Stay.** The shield's edge and its flash stay with the early sheet that owns them. Poise stays 4.5. The charge stays, at this body's wound of 30 times 1.2. Four stair fires and the glow budget stay where they are.

**Band.** B.

### 283. The Kindling foot

**See.** The foot of the Kindling says W, A, S, D, Space, Q, E, K, and Esc. Rebind walk to the arrows and the cards follow the arrows, and the foot still says W. The character screen's own hint says Tab closes it. I closes it too.

**Where.** `ui/growth.gd` builds the foot as a fixed string. Choosing a card reads `move_forward`, `move_back`, `move_left`, `move_right`, and the ui arrows. Kindling a card reads `jump` and `ui_accept`. While the character screen is up, `growth` returns early on `kindling`, `toggle_settings`, `inventory`, `skill_nova`, and `interact`, and the screen owns those. `ui/character_screen.gd` pages on the physical Q and E keys, steps the four tabs on the physical 1 through 4, and closes on `inventory`, `toggle_settings`, or pad B. `inventory` is Tab and I. `kindling` is K. `toggle_settings` is Esc. Sheet 5 already teaches the HUD to read the live key. This foot and this hint were left as letters. Q and E stay letters because the screen reads those physical keys, so a rebind of nova and interact does not move the pages, and the foot is right about those two by that fact.

**Change.** The foot is built from the live labels of the four move keys, jump, kindling, and inventory, the same way sheet 5 builds a lesson. Q and E stay Q and E, and the character screen's hint keeps them, because those are the physical keys. The close word uses the inventory label, so Tab and I both appear. The physical 1 through 4 stay. Pad B and the shoulders stay.

**Prove.** Bind the move keys to the arrows, jump to another key, and kindling to J. Leave Q and E. The cards move on the arrows, a card kindles on the jump key, J and I both leave, and the pages stay on Q and E. The foot names those keys. The character screen's hint names I beside Tab.

**Stay.** Sheet 5 still owns the HUD lessons and the interact prompt. The character screen still pauses and still owns the mouse. Hosted pages still hide the Kindling's own tab strip.

**Band.** B.

### 284. One word for a half and a quarter

**See.** Finish the ward-stones and the Thornwarden comes up with "Its song is weak." A speaker is still standing. You hit him and the word is "shrouded," the same word as the fight where the song takes half. The weak song takes a quarter.

**Where.** `thornwarden.gd` `_absorb`. While `speakers()` is above zero, damage is multiplied by 0.75 if `QuestBook.attuned("thornwarden")` and by 0.5 otherwise, and the float says "shrouded" either way. The engage line is "The ward-stones hold. Its song is weak." when attuned, and "The Thornwarden rises from the ring." when it is not. A rooted keeper still returns 0 and says "rooted: burn the knots." After the song, `BossKit.absorb` still chips a plain bolt and still holds the phase floor. A lance is heavy, so it is the clean read: 6.5 becomes 3.25 under the half, and 4.875 under the quarter.

**Change.** Attuned, the float says the song is thin. Unattuned, it keeps "shrouded." The 0.75 and the 0.5 stay. The rooted line stays. The chip and the floor stay.

**Prove.** Unattuned, a speaker up, a lance lands as 3.25 and the word is shrouded. Attuned, the same lance lands as 4.875 and the word says the song is thin. No speakers: the lance is 6.5 and neither word appears. A blow that would cross the phase floor still says "warded."

**Stay.** The song still comes off when the speakers die. Attuning still weakens it to a quarter. Sheet 236 still owns the plain bolt's seven tenths on top of this. The phases stay at 70% and 35% of 600.

**Band.** B.

### 285. The brood the body cannot spoil

**See.** The lesson for a red tell is to hit it. The brood-mother squats, the sac swells, and the hint says to burst a bolt on the sac. A lash on the body, the blow that breaks a wretch's tell, lets the mites come.

**Where.** `brood_mother.gd`. `_special_breakable` returns false, so the shared windup rule does not cut this hatch. `_on_weak_hit` ruptures it only while the state is `SPECIAL` and `_brooding` is set, and that is any hit that finds the sac, staff included. The hint names a bursting bolt. The swell is `BROOD_TELL` 1.6 s. A finished hatch is `mini(3, 6 - living)`, so three mites, or fewer so the living count stays at six. The next hatch is 10 s, or 7 s once enraged. Enrage is half of 44, and walk speed goes from 2.2 to 2.2 times 1.15. The first timer starts at 5 s. Life is 44. A spit is 16 wounds. Poise is 7.

**Change.** The hint says a blow on the body leaves the hatch, and a hit on the sac ruptures it. The staff counts when it finds the sac. The body still does not. The 1.6, the three, and the six stay.

**Prove.** Lash the body while the sac is swelling. Three mites come. Do it again and hit the sac with a bolt. The word is "the brood ruptures," and that swell adds no mite. At six mites already up, a finished hatch adds none.

**Stay.** The sac stays the weak point. Enrage stays at half. Sheet 281 still owns every other red tell. A mite is still one life at Dusk, and the tier table below is what gives it more.

**Band.** A.

### 286. A patch the night does not deepen

**See.** The tier deepens a body's life, and it deepens the wound of a rake, a spit, a slam, and a charge. Stand in a cinder caster's slag after the night has deepened and the landing has grown. The patch under it still pays 4 a tick, the Dusk number. A tollman's clang is 14 on the hearth road and 14 in a country the table has already made harder.

**Where.** `Tiers.scale_stats` multiplies `strike_gloom` and `spit_gloom` by the row's `dmg`. A husk's slam is `strike_gloom * 1.15`, so it deepens with him. A spitter's orb is `spit_gloom`, and the lob's landing is `spit_gloom * 1.2`, so those deepen. The acid that stays is `linger` with the literal 3, every 0.5 s across 3.2 s, six ticks. The brood-mother's lob uses that same literal 3, and the linger she leaves when the sac ruptures is the literal 3 across 3 s, six ticks. A cinder hurl's landing is `spit_gloom`, and the slag tick is the literal 4 across 4 s, eight ticks. A tollman's clang is the literal 14. His think never fires the spit he inherited, so the scaled spit export has nothing to do. The clang is the blow, and the tier never sees it.

**Change.** Each of those literals is multiplied by the `dmg` of the tier already stored on the pawn, `enc_tier`, and by 1 when that meta is absent. Dusk stays 3, 4, and 14. Umbral is 1.6, so an acid tick is 4.8, a slag tick is 6.4, a rupture tick is 4.8, and a clang is 22.4. A landing that already reads `spit_gloom` keeps the multiplier it already has. Telegraph times stay the body's own.

**Prove.** A Dusk spitter's orb is 10 and his pool is 3 a tick. An Umbral spitter's orb is 16 and his pool is 4.8 a tick. A Dusk cinder landing is 14 and the slag is 4. An Umbral landing is 22.4 and the slag is 6.4. A tollman's clang is 14 at Dusk and 22.4 at Umbral. A husk's rake is 32 at Dusk and 51.2 at Umbral, which the tier was already doing.

**Stay.** The Bone Abbot's rain and his grave-fire are literals on his own fight, and this sheet does not take them. Sheet 203 still owns the plate. The tick stays at half a second. The tier still does not shorten a tell.

**Band.** B.

The card and the detail count the same fire. A lodestar's two leaps are each seventy percent of the first bolt. A red tell breaks on the blow that landed, and the lesson names that blow. A full lance spends itself on the boards. The Kindling foot names the keys you have. The weak song says it is thin. A brood breaks on the sac. A patch deepens with the landing. None of this is in the game yet.

## Part XXXIII — the bodies, as they stand

Read on 6 November from the scripts that build them. These are the bodies at Dusk, before `Tiers.scale_stats` and before a variant. The tier multiplies life and the wound and then the pace, and the variant adds life and poise after that and multiplies pace again. Telegraph times stay the body's own. A blow's number is wounds on the plate of 120, sheet 203, even where the export is still named gloom. Two blows inside 0.35 s count as one. The fill counts below are blows that land outside that grace. A plain bolt at power 1 is 1. A lash is 2. A lance tap is 2 and a full lance is 6.5, and both are heavy. The staff is 1.2, then 1.2, then 2.3. Sheet 236 chips a bolt that is not heavy when the body is a boss. Camp bodies take the bolt whole.

The sheets named beside a picture already own the change. Leave those. The next free sheet is 291.

### How a tier deepens a body

`Tiers.scale_stats` runs first. Life becomes `max(base, round(base * hp))`, and from Deep Night on, if that rounded life is still the base, it gains 1. The wound on `strike_gloom`, and on `spit_gloom` where the body has one, is multiplied by `dmg`. Walk speed is multiplied by `pace`. Then `behave` runs. Tier 0 and tier 1 add no chains and no feints. From Deep Night, a body that already chains, or any flanker, has `combo_max` of at least 1, and its chain chance rises by 0.06 per tier past the first, capped at 0.6. Anything with a strike range gains 0.04 feint chance per tier past the first, capped at 0.35. A pilgrim's own feint is 0, and a gaunt's own chain is 0. The late night gives them those teeth. That is the deepening the tier file describes. Sheet 245 still owns the red a feint owes. The tells do not get shorter.

Dusk is 1.0 life, 1.0 wound, 1.0 pace, and no variant. The hearth, the road, and the glade start here. Night is 1.25, 1.1, 1.03, and a quarter of pawns may be scarred. The chapel, the thornwood, the henge, the fen, the holds, the moor, the orchard, the necropolis, and the mere start here, plus whatever the night has deepened. Deep Night is 1.5, 1.2, 1.05. Black Night is 1.8, 1.3, 1.07. The barrows, the ossuary, the rift, the crags, the quarry, and the foundry start at Deep Night's number only when the night's depth is still zero; their base in the table is 2, which is Deep Night's row. Hollow Night is 2.1, 1.4, 1.09. The summit starts at 3, which is Black Night, before any boss has fallen. Deeper Night is 2.5, 1.5, 1.11. Umbral Night is 3.0, 1.6, 1.13. Depth is bosses slain this cycle, plus two per Deeper Night cycle. The row clamps at Umbral.

A mite is 1 life. Night rounds 1.25 back to 1, so a mite in the chapel is still one bolt. Deep Night rounds 1.5 to 2, and from there the mite takes two plain bolts. A wretch is 3. Night rounds 3.75 to 4. Deep Night rounds 4.5 to 5. Black Night rounds 5.4 to 5. Hollow Night rounds 6.3 to 6. Deeper Night rounds 7.5 to 8. Umbral Night is 9. A full lance of 6.5 still ends a wretch through Hollow Night, where he has 6. From Deeper Night he has 8, and that lance leaves him standing.

The comment on the tier table still says the wound multiplier is "Gloom per blow." The number lands on the plate.

### What a variant adds

`Variants.pre` runs after the tier. It adds a flat life, adds a flat poise, and multiplies the already scaled walk speed by its pace. The mesh scale is applied when the body is dressed. A slam or a sweep that reads `_rig.scale` grows with that. The shared rake reads `strike_range` and stays at the body's reach.

Scarred adds 1 life, 0.6 poise, pace 1.0, scale 1.06. Ironclad adds 2 life, 1.6 poise, pace 0.94, scale 1.08. Tide-born adds 0 life, 0 poise, pace 1.12, scale 1.0. Deeper adds 2 life, 1.0 poise, pace 1.05, scale 1.14. Stone-bound adds 2 life, 2.2 poise, pace 0.9, scale 1.06, and it keeps the body's own mesh with a stone rim. Drowned adds 1 life, 0.6 poise, pace 0.96, scale 1.0, and it keeps the mesh with a fen rim. Stone-bound is the quarry's husk, bulwark, and leaper. Drowned is the mere's husk, wretch, and ossuant.

A Dusk wretch with no variant is the block below. A scarred one on top of Dusk is 4 life and poise 3.2. An ironclad one is 5 life and poise 4.2, walking at 3.6 times 0.94. The staff chain of 4.7 ends a plain wretch and a scarred one, and leaves an ironclad with a scrap of life.

### The shared rake

`strike_arc` is a half-angle. The default is 75°, so the fan is 150°. The default reach is 1.35, the default windup is 0.42 s, the default lunge is 4.5, the default poise is 2.6, the default recover is 0.55 s. Sleep is 46 m. The hit, as it stands, is reach plus 0.5 m and the half-angle plus 10°, or any blow inside 0.6 m, and the body must be within 1.8 m of height. Sheet 213 owns painting that hit. A full sprint is 7.5. A wretch's 0.42 s tell, if you are already at that sprint, is 3.15 m of ground.

Poise that a single plain bolt fills, so the tell dies with the bolt: a mite at 0.5, a tollman at 0.8, a chanter at 0.9. A quiller at 1.6 and a pilgrim at 1.6 and a gaunt at 1.8 need more than one bolt, or one lash. A wretch at 2.6, a husk's child at the husk's 3.2, a bulwark at 4.5, and a brood-mother at 7 do not fall over to one bolt. The instant break at damage of 2 still cuts a windup on any of them, boss chip aside.

### The wretch

Life 3. Walks at 3.6. Chase 12, leash 15. The rake is 25 wounds at reach 1.45, half-angle 75°, windup 0.42, lunge 5.0, poise 2.6. Chain chance 0.35, up to two further rakes, each windup 0.32. Feint chance 0.22. Sheet 245 owns the feint's bar. Sheet 213 owns the wedge.

Three plain bolts end it. A lash and a bolt end it. A full lance ends it. The staff's first two swings leave 0.6, and the third ends it. One rake is 25 of 120. Four rakes are 100. The fifth is 125 and fills the plate.

### The husk

Life 5. Walks at 2.35. Chase 10, leash 13. The rake is 32 wounds at reach 1.55, half-angle 85°, windup 0.6, lunge 3.5, poise 3.2. The slam is a disc of radius 2.2 times the rig scale, windup 0.85, wound 32 times 1.15, which is 36.8. The charge starts between 5 and 10 m, windup 0.9, runs at 9.5, length `min(distance + 2.5, 11)`, and the hit while it runs is within 1.25 m of the body, wound 32 times 1.2, which is 38.4. Sheet 58 owns the lane and the slam's picture. The wounds above are what the code pays today.

Five plain bolts end it. A full lance ends it. The staff chain of 4.7 leaves 0.3. Three rakes are 96. The fourth is 128 and fills the plate. Three charges are 115.2. The fourth fills it. One charge is close to a third of the plate on its own.

### The gaunt

Extends the wretch, so the reach stays 1.45, the half-angle stays 75°, the lunge stays 5.0, and the windup stays 0.42 unless a dart replaces them. Life 2. Walks at 4.3. Chase 14, leash 17. Poise 1.8. Its own `combo_max` is 0 and its feint is 0. From Deep Night the tier gives a flanker a chain. The dart's tell is 0.55 s, the run is 11.5, and the hit is within 1.15 m of the body for 22 wounds. Sheet 215 owns the lane against the circle.

Two plain bolts end it. One lash ends it. One lance tap ends it. The staff's first swing leaves it, and the second ends it. Six darts are 132 and fill the plate. Five are 110.

### The pilgrim

Extends the wretch, so the reach is 1.45 and the half-angle is 75° and the lunge is 5.0. Life 4. Walks at 2.7. Chase 11, leash 14. The rake is 24 wounds, windup 0.55, poise 1.6. Its own chain is one extra rake at chance 0.45, windup 0.4. Its own feint is 0, and Deep Night begins to add some. It lies dormant until you are inside 6.5 m, or until it is struck, or until a packmate is pulled. The rise takes 1.15 s and it does not attack during the rise.

Four plain bolts end it. Two lashes end it. A full lance ends it. The staff chain of 4.7 ends it. Five rakes are 120 exactly.

### The crawler

Life 2. Walks at 3.4. Chase 11, leash 13. The rake is 14 wounds at reach 1.15. It hops 3.4 m and it pounces between 3.5 and 8.5, apex 1.1, prep 0.32, cooldown 3.2. Poise is the default 2.6. Half-angle is the default 75°.

Two plain bolts end it. One lash ends it. Eight rakes are 112. The ninth is 126 and fills the plate.

### The mite

Life 1. Walks at 4.4. Chase 13, leash 16. The rake is 5 wounds at reach 0.85, half-angle 60°, windup 0.3, lunge 3.5, recover 0.45, poise 0.5. The hop is 1.8. The pounce is 2.2 to 4.8, apex 0.6, prep 0.3. One plain bolt ends it at Dusk, and the tell dies with the bolt because poise is 0.5. The file calls the rake a nibble. Twenty-four of them fill the plate, the same 120 one wretch fills in five rakes. Five mites, landing outside the grace, are one wretch's rake. Sheet 208 owns the mite at the edge of sight. The early mite sheet owns the death in a frame.

### The leaper

Life 4. Walks at 4.2. Chase 15, leash 19. The rake is 28 wounds at reach 1.6. Poise is the default 2.6. The pounce is 4.5 to 13, apex 2.1, prep 0.5, cooldown 2.8. The tail is a disc of radius 2.5 times the rig scale, tell 0.55, wound 28 times 0.8, which is 22.4, and the spin runs on for 0.32 after the tell. A variant's scale multiplies that disc. It does not multiply the rake.

Four plain bolts end it. Two lashes end it. A full lance ends it. The staff chain ends it. Four rakes are 112. The fifth is 140 and fills the plate. Five sweeps are 112. The sixth fills it.

### The spitter

Life 1. Walks at 2.8. Chase 16, leash 16. It does not melee. It keeps 6 to 10 m and spits to 15. The orb is 10 wounds, windup 0.6, cooldown 2.4. The lob's disc is radius 1.7, windup 0.7, flight 1.0, and the zone pays 12. The acid that stays is `linger` at 1.7 times 0.85, life 3.2 s, 3 wounds every 0.5 s. That is six ticks, 18 wounds, if you stand in it, on top of the 12. One plain bolt ends the body at Dusk. Twelve orbs fill the plate. The early spit sheet owns the orb's picture.

### The chanter

Extends the spitter. Life 2. Walks at 2.6. Keeps 7 to 11 m. Poise 0.9, so one plain bolt breaks a tell and leaves him at 1 life. The second bolt ends him. The sigil is 14 wounds, radius 1.8, cast 0.5 plus a fall of 1.0, and sheet 60 owns the second of that where the pose has already gone idle. Sheet 214 owns the quarter metre past the paint. The shroud is 6 s at half damage, channel 1.1, and any blow on him breaks that working. The slip is a tell of 0.4 inside 3.5 m, and `_special` of that cast is not interruptible. It deals no wound. It is him leaving.

Nine sigils fill the plate. A shrouded packmate takes half, which is the same half the float on the Thornwarden uses for a different song. This one is 6 seconds and it ends when he does, or when the time does.

### The quiller

Extends the spitter and replaces the spit. Life 2. Walks at 3.0. Chase 18, leash 20. Keeps 9 to 14 m. The rib is 18 wounds down a lane built at length 17, draw 0.85, cooldown 3.2. Poise 1.6. Inside 4 m it springs back 5.5. Sheet 214 owns the thread against the hit. Sheet 174 owns the spring. It sets the lob aside.

Two plain bolts end it. One lash ends it. Six ribs are 108. The seventh is 126 and fills the plate.

### The cinder caster

Extends the spitter. Life 3. Walks at 2.5. Keeps 7 to 12 m and hurls to 18. The hurl is 14 wounds, radius 2.1, windup 1.15, flight 0.9, cooldown 3.4. The cast name is "Cinder Hurl." Poise is 1.2. It is not a boss, so any blow breaks the cast. The slag that stays is radius 2.1 times 0.8, which is 1.68, for 4 s, at 4 wounds every 0.5 s. That is eight ticks, 32 wounds, if you stand the whole patch, on top of the 14 if you ate the landing. One hurl you stand in is 46, more than a third of the plate. The comment's advice to step out of it is the arithmetic. The foundry's camps are where this body is in the pool.

Three plain bolts end it. A full lance ends it. The staff's third swing, after the first two have landed, ends it. A single bolt during the 1.15 s cast spoils the hurl.

### The burrower

Life 3. The walk is set to 3.0 and then to 3.2, so it walks at 3.2. Chase 14, leash 18. The rake is 18 wounds. Between 4.5 and 14 m, and not in a light, it digs. The tunnel is 7 m/s for at most 2.6 s. The disc at the stop is radius 1.7, tell 0.75, wound 18 times 1.2, which is 21.6. Underground it is not a target. Sheet 208 owns the colour of that disc. Sheet 214 owns the pad past the paint. Cooldown on the burrow is 7 s after it starts, and the first wait is 1.2.

Three plain bolts end it. A full lance ends it. Six rakes are 108. The seventh fills the plate. Five eruptions are 108. The sixth is 129.6 and fills it.

### The ossuant

Extends the husk, so the reach is 1.55, the half-angle is 85°, the poise is 3.2, and the slam and the charge are still there, at this body's wound. Life 4. Walks at 2.7. The rake is 28. The windup is 0.55. The slam is 28 times 1.15, which is 32.2, on the husk's 2.2 disc. The charge hit is 28 times 1.2, which is 33.6, on the husk's 1.25 m test. At 0 life with no mark it heaps for 4 s and rises at half, which is 2. Sheet 212 owns the bar on that heap. A mark on the killing blow, or any hit on the heap, ends it.

Four plain bolts end the standing body. A full lance ends it. Four rakes are 112. The fifth fills the plate. Three charges are 100.8. The fourth fills it. Kill it unmarked and leave the heap. It stands at 2, and one lash ends that.

### The bulwark

Extends the husk with the slam turned off and the charge windup set to 1.0. Life 6. Walks at 2.0. The rake is 30 wounds at reach 1.6, half-angle 55°, windup 0.65, poise 4.5. The charge still runs, and its hit is 30 times 1.2, which is 36. The boards are sheet 282: 6 points, double chip at 3 or more, a full lance breaks them and deals 0 to the life, a tap chips 2. From the flank the lance's 6.5 ends the body in one throw. From the front that same throw only breaks the boards, and the body still has 6.

Four rakes are 120 exactly, if they reached the body. Three charges are 108. The fourth fills the plate.

### The tollman

Extends the spitter and does not spit. Life 2. Walks at 3.1. Chase 16, leash 18. Keeps 8 to 13 m. Poise 0.8, so one plain bolt staggers him and leaves him at 1. The second ends him. A lash ends him in one. The ring is 2.4 s and three tolls, and the wake at the end is 34 m. Sheet 206 owns that earshot against the gold ring you see. Any blow during the ring spoils it. A finished toll waits 14 s. A spoiled one waits 4. The clang is a disc of radius 2.3, tell 0.6, wound 14. Nine clangs fill the plate.

The hint says to hit him before the third toll. The third toll and the wake are the same moment, when the 2.4 s elapse. A blow on the first or the second spoils it. A blow as the third is sounding, if it lands before the finish, spoils it too.

### The brood-mother

Life 44. Walks at 2.2, and at half life walks at 2.2 times 1.15. Chase 18, leash 12. Keeps 5 to 9 m and spits to 18, wound 16, cooldown 2.6. Poise 7. The hatch, the cap of six, and the sac are sheet 285. A rupture also lays a linger of radius 1.6 for 3 s at 3 wounds every 0.5 s, six ticks, 18 wounds if you stand in it. Forty-four plain bolts end her at Dusk, before any guardian tier. A full lance of 6.5 is seven throws to 45.5, so the seventh ends her if none of it was wasted on the phase of a body that is not using the boss floor. She is not marked `boss` in her init. The chip of sheet 236 is for a boss. She takes the bolt whole.

### The Thornwarden

Life 600. Walks at 5. The rake export is 38 wounds, before a boss chip and before the song. Phases at 70% and at 35%, and those are the phase marks, so the floor sits just above 420 and just above 210 until the signature has been seen twice. The song is sheet 284. The mend is 6% of max over 3 s, every 26 s, when that mend is allowed to finish. The storm pays 48. The knots have 55 s. The slam's picture is an early sheet; the radius on the body is 3.2, and a later phase has its own larger one. Three rakes of 38 are 114. The fourth is 152 and fills the plate, song and chip aside. Two storms are 96. The third is 144 and fills it.

### The Warden

Life 760. Walks at 2.4. The rake export is 42. Phases at 65% and at 30%. Sheet 204 owns seven tongues against that first line: each tongue is `BELL_HOLD` 0.05 off the current life, and the max stays, so seven tongues put him on the 65% line before you have swung. The sky is 55, sheet 203. Two rakes are 84. The third is 126 and fills the plate, chip aside. Two skies are 110. The third fills it with room to spare. The fan's picture is sheet 60: radius 20, half-angle 33°, windup 0.85.

### The Bone Abbot

Life 620. The intermission mark is 66% of that life. A tally heals 6% of max, and the choir he summons sits at 4 life each. The Tolling pays 45, sheet 203. A missed plate of the Reckoning pays 14, and sheet 195 owns that count. The tithe's spikes pay 22 at radius 1.5, and sheet 60 owns the arms against the later spikes. Three Tollings are 135 and fill the plate. Nine missed plates are 126 and fill it. The scale on the body is 2.6.

### What one evening costs at Dusk

Start the plate at 0. These are Dusk bodies, power 1, blows outside the 0.35 s grace.

A mite pack of five, each landing once, is 25. That is one wretch. The mites die to five bolts, one each. The wretch dies to three bolts and has already put the same 25 on you in a single rake.

A spitter you ignore for four orbs is 40, and if two of those were lobs you stood in, add 12 for each landing and up to 18 for each pool. One bolt was the whole answer. He has 1 life.

A chanter's sigil is 14. Stand in three of them and you are at 42, and he himself dies to two bolts. The shroud he put on the husk beside him cuts your bolts on that husk in half for 6 s. The husk's rake is still a full 32 on you.

A husk who lands one charge is 38.4. A second is 76.8. A third is 115.2, and you are one charge from a hollow with a body that a full lance would have ended when he still had 5 life.

A bulwark faced head-on spends your full lance on 6 points of boards and returns none of it to a body of 6. The same lance from the flank ends him. The lesson after sheet 282 says this in the hint. Until that sheet is in, the hint says the lance breaks it, and the body is still there.

A cinder caster you stand under for the landing and the whole slag is 14 plus 32, which is 46. Step out when the disc lands and you paid 14, or nothing if you were already clear. The cast is 1.15 s of interrupt on a body of poise 1.2.

A tollman who finishes is not a wound at all. He is every hollowed inside 34 m. The clang, if you are the one who closed in, is 14. Two bolts end him at Dusk. The hint's third toll is the wake.

A brood-mother's spit is 16. Her hatch is three mites, 5 each if they reach you, 15, and the cap holds the rest. The sac during the 1.6 s is the interrupt that sheet 285 asks the hint to name. The body is 44 plain bolts, or seven full lances.

### The watch

A post wakes inside 70 m and calls an assault only inside 55 m. Assaults are 80 to 140 s apart, and the first wait after the post builds is 20 to 40 s. The dark walks in from 15 m. A watchman has 10 life, on the post's own array. A hollowed beside him, inside that foe's strike range plus half a metre, deals 1 to that life, then again every 1.6 s. The 1 is not the wound that foe would put on you. His cut is 1.1 at reach 1.8, on a swing of 1.7, landing at 0.62 of that swing. He chases a foe from the wave who is still within 18 m of the post, which is the 14 m guard plus 4. A hold pays 6 grave ash, and the toast says so. Every third hold, the count modulo 3, also stores a piece of gear: rarity 1, Kindled, when the count is 3, and rarity 2, Hallowed, when the count is 6 or more. On a hold, every watchman gains 5 life, capped at 10, and a man who was down stands if that brings him above 0. A fallen post stays down for 150 s. The toast says the watchmen will get up again. It does not say 150. The lantern on the hook is energy 1.1, range 7, shadows off, and it is not registered. The file says the dark is not kept off by it. That matches the grid: stand in the glow and the gloom bar still climbs. The picture is a hook-lamp. Sheet 211's three lights are the ward, the well, and the camp, and this lantern is not one of them.

### The lift

The deck is 2.6 on a side and 0.3 thick. The trip is 7 s and the dwell at each end is 3 s. `sync_to_physics` carries a standing body. The lantern on the column is energy 1.2, range 6, class fill, and it is not registered. No player sentence names the 7 or the 3. The ride is the deck.

### What this part leaves

The wedge, the pad past a disc, the gaunt's lane, the shade's dart, the ossuary heap, the toll's earshot, the Warden's seven tongues, the Tolling, the sky, the Reckoning's plates, the knot on a chanter, the mite at the edge of sight, the feint's missing red, and the plain bolt's tax on a boss are already sheets. The numbers in this part are the bodies those sheets sit on. A later sheet repeats one of them only when it brings a new number. Dusk is the body. The tier and the variant are the night around it. The tells stay the length they were given.

The next free sheet is 291. The sheets in Part XXXII are still the ones the night has not taken.

## Part XXXIV — the same body, seven times

The bodies in Part XXXIII are Dusk. This part is those bodies after `Tiers.scale_stats`, one row at a time, before a variant adds its flat life. Life is `max(base, round(base * hp))`, halfway rounded away from zero. From Deep Night on, a result that is still the base gains 1. On this table that extra life never fires: every camp body rounds upward from Deep Night on. The wound is the Dusk wound times `dmg`. Walk is the Dusk walk times `pace`, printed here to the hundredth; the night keeps the full product. Poise stays the body's own. Telegraph times stay the body's own. A plain bolt is still 1, a lash is still 2, a full lance is still 6.5, and the staff chain is still 4.7, because the tier scales the hollowed and the wanderer's blows stay hers. Two blows inside 0.35 s still count as one. The plate is still 120.

A full lance ends a body of 6 or less and leaves the rest on a body of 7 or more. The staff chain ends a body of 4 or less. The count of blows that fill the plate is the first count whose product reaches 120, blows landing outside the grace.

### The wretch

Dusk life 3, Dusk rake 25, walk 3.6, poise 2.6. Reach 1.45, half-angle 75°, windup 0.42, lunge 5. Those times and that reach stay at every row. Chain chance starts at 0.35 and feint at 0.22, and the teeth section is where the later rows add to them.

Dusk. Life 3, from 3 times 1. Walk 3.6. The rake pays 25. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 100, and the next, the 5th, fills it.

Night. Life 4, from 3 times 1.25. Walk 3.71. The rake pays 27.5. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 110, and the next, the 5th, fills it.

Deep Night. Life 5, from 3 times 1.5. Walk 3.78. The rake pays 30. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 3 of them leave the plate at 90, and the next, the 4th, fills it.

Black Night. Life 5, from 3 times 1.8. Walk 3.85. The rake pays 32.5. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 3 of them leave the plate at 97.5, and the next, the 4th, fills it.

Hollow Night. Life 6, from 3 times 2.1. Walk 3.92. The rake pays 35. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 3 of them leave the plate at 105, and the next, the 4th, fills it.

Deeper Night. Life 8, from 3 times 2.5. Walk 4. The rake pays 37.5. 8 plain bolts end it. A full lance leaves 1.5. The staff chain leaves 3.3. 3 of them leave the plate at 112.5, and the next, the 4th, fills it.

Umbral Night. Life 9, from 3 times 3. Walk 4.07. The rake pays 40. 9 plain bolts end it. A full lance leaves 2.5. The staff chain leaves 4.3. 2 of them leave the plate at 80, and the next, the 3rd, fills it.

### The husk

Dusk life 5, Dusk rake 32, walk 2.35, poise 3.2. Reach 1.55, half-angle 85°, windup 0.6, lunge 3.5. The slam is this rake times 1.15 and the charge hit is this rake times 1.2, so both deepen with the rake. Sheet 58 still owns the pictures.

Dusk. Life 5, from 5 times 1. Walk 2.35. The rake pays 32. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 3 of them leave the plate at 96, and the next, the 4th, fills it.

Night. Life 6, from 5 times 1.25. Walk 2.42. The rake pays 35.2. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 3 of them leave the plate at 105.6, and the next, the 4th, fills it.

Deep Night. Life 8, from 5 times 1.5. Walk 2.47. The rake pays 38.4. 8 plain bolts end it. A full lance leaves 1.5. The staff chain leaves 3.3. 3 of them leave the plate at 115.2, and the next, the 4th, fills it.

Black Night. Life 9, from 5 times 1.8. Walk 2.51. The rake pays 41.6. 9 plain bolts end it. A full lance leaves 2.5. The staff chain leaves 4.3. 2 of them leave the plate at 83.2, and the next, the 3rd, fills it.

Hollow Night. Life 11, from 5 times 2.1. Walk 2.56. The rake pays 44.8. 11 plain bolts end it. A full lance leaves 4.5. The staff chain leaves 6.3. 2 of them leave the plate at 89.6, and the next, the 3rd, fills it.

Deeper Night. Life 13, from 5 times 2.5. Walk 2.61. The rake pays 48. 13 plain bolts end it. A full lance leaves 6.5. The staff chain leaves 8.3. 2 of them leave the plate at 96, and the next, the 3rd, fills it.

Umbral Night. Life 15, from 5 times 3. Walk 2.66. The rake pays 51.2. 15 plain bolts end it. A full lance leaves 8.5. The staff chain leaves 10.3. 2 of them leave the plate at 102.4, and the next, the 3rd, fills it.

### The gaunt

Dusk life 2, Dusk dart 22, walk 4.3, poise 1.8. The dart's tell stays 0.55 s and the run stays 11.5. The hit stays within 1.15 m. Sheet 215 still owns the lane. His own chain count is 0 until the teeth section.

Dusk. Life 2, from 2 times 1. Walk 4.3. The dart pays 22. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 5 of them leave the plate at 110, and the next, the 6th, fills it.

Night. Life 3, from 2 times 1.25. Walk 4.43. The dart pays 24.2. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 96.8, and the next, the 5th, fills it.

Deep Night. Life 3, from 2 times 1.5. Walk 4.51. The dart pays 26.4. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 105.6, and the next, the 5th, fills it.

Black Night. Life 4, from 2 times 1.8. Walk 4.6. The dart pays 28.6. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 114.4, and the next, the 5th, fills it.

Hollow Night. Life 4, from 2 times 2.1. Walk 4.69. The dart pays 30.8. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 3 of them leave the plate at 92.4, and the next, the 4th, fills it.

Deeper Night. Life 5, from 2 times 2.5. Walk 4.77. The dart pays 33. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 3 of them leave the plate at 99, and the next, the 4th, fills it.

Umbral Night. Life 6, from 2 times 3. Walk 4.86. The dart pays 35.2. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 3 of them leave the plate at 105.6, and the next, the 4th, fills it.

### The pilgrim

Dusk life 4, Dusk rake 24, walk 2.7, poise 1.6. Reach stays 1.45. The rise stays 1.15 s inside 6.5 m, with no attack during it. His own feint is 0 until the teeth section.

Dusk. Life 4, from 4 times 1. Walk 2.7. The rake pays 24. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 96, and the next, the 5th, fills it.

Night. Life 5, from 4 times 1.25. Walk 2.78. The rake pays 26.4. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 4 of them leave the plate at 105.6, and the next, the 5th, fills it.

Deep Night. Life 6, from 4 times 1.5. Walk 2.84. The rake pays 28.8. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 4 of them leave the plate at 115.2, and the next, the 5th, fills it.

Black Night. Life 7, from 4 times 1.8. Walk 2.89. The rake pays 31.2. 7 plain bolts end it. A full lance leaves 0.5. The staff chain leaves 2.3. 3 of them leave the plate at 93.6, and the next, the 4th, fills it.

Hollow Night. Life 8, from 4 times 2.1. Walk 2.94. The rake pays 33.6. 8 plain bolts end it. A full lance leaves 1.5. The staff chain leaves 3.3. 3 of them leave the plate at 100.8, and the next, the 4th, fills it.

Deeper Night. Life 10, from 4 times 2.5. Walk 3. The rake pays 36. 10 plain bolts end it. A full lance leaves 3.5. The staff chain leaves 5.3. 3 of them leave the plate at 108, and the next, the 4th, fills it.

Umbral Night. Life 12, from 4 times 3. Walk 3.05. The rake pays 38.4. 12 plain bolts end it. A full lance leaves 5.5. The staff chain leaves 7.3. 3 of them leave the plate at 115.2, and the next, the 4th, fills it.

### The crawler

Dusk life 2, Dusk rake 14, walk 3.4, poise 2.6. Reach stays 1.15. The hop stays 3.4 m and the pounce stays 3.5 to 8.5, prep 0.32.

Dusk. Life 2, from 2 times 1. Walk 3.4. The rake pays 14. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 8 of them leave the plate at 112, and the next, the 9th, fills it.

Night. Life 3, from 2 times 1.25. Walk 3.5. The rake pays 15.4. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 7 of them leave the plate at 107.8, and the next, the 8th, fills it.

Deep Night. Life 3, from 2 times 1.5. Walk 3.57. The rake pays 16.8. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 7 of them leave the plate at 117.6, and the next, the 8th, fills it.

Black Night. Life 4, from 2 times 1.8. Walk 3.64. The rake pays 18.2. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 6 of them leave the plate at 109.2, and the next, the 7th, fills it.

Hollow Night. Life 4, from 2 times 2.1. Walk 3.71. The rake pays 19.6. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 6 of them leave the plate at 117.6, and the next, the 7th, fills it.

Deeper Night. Life 5, from 2 times 2.5. Walk 3.77. The rake pays 21. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 5 of them leave the plate at 105, and the next, the 6th, fills it.

Umbral Night. Life 6, from 2 times 3. Walk 3.84. The rake pays 22.4. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 5 of them leave the plate at 112, and the next, the 6th, fills it.

### The mite

Dusk life 1, Dusk rake 5, walk 4.4, poise 0.5. Reach stays 0.85, half-angle 60°, windup 0.3. One bolt still ends a Night mite, because 1.25 rounds back to 1. From Deep Night the life is 2 and the bolt is no longer the whole answer.

Dusk. Life 1, from 1 times 1. Walk 4.4. The rake pays 5. One plain bolt ends it. A full lance ends it. The staff chain ends it. 23 of them leave the plate at 115, and the next, the 24th, fills it.

Night. Life 1, from 1 times 1.25. Walk 4.53. The rake pays 5.5. One plain bolt ends it. A full lance ends it. The staff chain ends it. 21 of them leave the plate at 115.5, and the next, the 22nd, fills it.

Deep Night. Life 2, from 1 times 1.5. Walk 4.62. The rake pays 6. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 19 of them leave the plate at 114, and the next, the 20th, fills it.

Black Night. Life 2, from 1 times 1.8. Walk 4.71. The rake pays 6.5. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 18 of them leave the plate at 117, and the next, the 19th, fills it.

Hollow Night. Life 2, from 1 times 2.1. Walk 4.8. The rake pays 7. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 17 of them leave the plate at 119, and the next, the 18th, fills it.

Deeper Night. Life 3, from 1 times 2.5. Walk 4.88. The rake pays 7.5. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 15 of them leave the plate at 112.5, and the next, the 16th, fills it.

Umbral Night. Life 3, from 1 times 3. Walk 4.97. The rake pays 8. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 14 of them leave the plate at 112, and the next, the 15th, fills it.

### The leaper

Dusk life 4, Dusk rake 28, walk 4.2, poise 2.6. Reach stays 1.6. The pounce stays 4.5 to 13, prep 0.5. The tail is this rake times 0.8 on a disc of 2.5 times the rig scale.

Dusk. Life 4, from 4 times 1. Walk 4.2. The rake pays 28. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 112, and the next, the 5th, fills it.

Night. Life 5, from 4 times 1.25. Walk 4.33. The rake pays 30.8. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 3 of them leave the plate at 92.4, and the next, the 4th, fills it.

Deep Night. Life 6, from 4 times 1.5. Walk 4.41. The rake pays 33.6. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 3 of them leave the plate at 100.8, and the next, the 4th, fills it.

Black Night. Life 7, from 4 times 1.8. Walk 4.49. The rake pays 36.4. 7 plain bolts end it. A full lance leaves 0.5. The staff chain leaves 2.3. 3 of them leave the plate at 109.2, and the next, the 4th, fills it.

Hollow Night. Life 8, from 4 times 2.1. Walk 4.58. The rake pays 39.2. 8 plain bolts end it. A full lance leaves 1.5. The staff chain leaves 3.3. 3 of them leave the plate at 117.6, and the next, the 4th, fills it.

Deeper Night. Life 10, from 4 times 2.5. Walk 4.66. The rake pays 42. 10 plain bolts end it. A full lance leaves 3.5. The staff chain leaves 5.3. 2 of them leave the plate at 84, and the next, the 3rd, fills it.

Umbral Night. Life 12, from 4 times 3. Walk 4.75. The rake pays 44.8. 12 plain bolts end it. A full lance leaves 5.5. The staff chain leaves 7.3. 2 of them leave the plate at 89.6, and the next, the 3rd, fills it.

### The spitter

Dusk life 1, Dusk orb 10, walk 2.8, poise 2.6. He does not melee. The orb below is the scaled spit. The lob's landing is that orb times 1.2. The acid tick stays 3 until sheet 286. Windup stays 0.6 and the lob's windup stays 0.7.

Dusk. Life 1, from 1 times 1. Walk 2.8. The orb pays 10. One plain bolt ends it. A full lance ends it. The staff chain ends it. 11 of them leave the plate at 110, and the next, the 12th, fills it.

Night. Life 1, from 1 times 1.25. Walk 2.88. The orb pays 11. One plain bolt ends it. A full lance ends it. The staff chain ends it. 10 of them leave the plate at 110, and the next, the 11th, fills it.

Deep Night. Life 2, from 1 times 1.5. Walk 2.94. The orb pays 12. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 9 of them leave the plate at 108, and the next, the 10th, fills it.

Black Night. Life 2, from 1 times 1.8. Walk 3. The orb pays 13. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 9 of them leave the plate at 117, and the next, the 10th, fills it.

Hollow Night. Life 2, from 1 times 2.1. Walk 3.05. The orb pays 14. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 8 of them leave the plate at 112, and the next, the 9th, fills it.

Deeper Night. Life 3, from 1 times 2.5. Walk 3.11. The orb pays 15. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 7 of them leave the plate at 105, and the next, the 8th, fills it.

Umbral Night. Life 3, from 1 times 3. Walk 3.16. The orb pays 16. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 7 of them leave the plate at 112, and the next, the 8th, fills it.

### The chanter

Dusk life 2, Dusk sigil 14, walk 2.6, poise 0.9. The sigil's radius stays 1.8 and the pose stays 0.5 plus 1.0. Sheet 60 still owns the idle second. The shroud stays 6 s at half. Poise stays 0.9, so one plain bolt still breaks the tell and leaves 1 life until the row gives him 3 or more.

Dusk. Life 2, from 2 times 1. Walk 2.6. The sigil pays 14. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 8 of them leave the plate at 112, and the next, the 9th, fills it.

Night. Life 3, from 2 times 1.25. Walk 2.68. The sigil pays 15.4. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 7 of them leave the plate at 107.8, and the next, the 8th, fills it.

Deep Night. Life 3, from 2 times 1.5. Walk 2.73. The sigil pays 16.8. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 7 of them leave the plate at 117.6, and the next, the 8th, fills it.

Black Night. Life 4, from 2 times 1.8. Walk 2.78. The sigil pays 18.2. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 6 of them leave the plate at 109.2, and the next, the 7th, fills it.

Hollow Night. Life 4, from 2 times 2.1. Walk 2.83. The sigil pays 19.6. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 6 of them leave the plate at 117.6, and the next, the 7th, fills it.

Deeper Night. Life 5, from 2 times 2.5. Walk 2.89. The sigil pays 21. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 5 of them leave the plate at 105, and the next, the 6th, fills it.

Umbral Night. Life 6, from 2 times 3. Walk 2.94. The sigil pays 22.4. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 5 of them leave the plate at 112, and the next, the 6th, fills it.

### The quiller

Dusk life 2, Dusk rib 18, walk 3, poise 1.6. The draw stays 0.85 and the lane length stays 17. Sheet 214 still owns the thread. The spring back stays 5.5 inside 4 m.

Dusk. Life 2, from 2 times 1. Walk 3. The rib pays 18. 2 plain bolts end it. A full lance ends it. The staff chain ends it. 6 of them leave the plate at 108, and the next, the 7th, fills it.

Night. Life 3, from 2 times 1.25. Walk 3.09. The rib pays 19.8. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 6 of them leave the plate at 118.8, and the next, the 7th, fills it.

Deep Night. Life 3, from 2 times 1.5. Walk 3.15. The rib pays 21.6. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 5 of them leave the plate at 108, and the next, the 6th, fills it.

Black Night. Life 4, from 2 times 1.8. Walk 3.21. The rib pays 23.4. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 5 of them leave the plate at 117, and the next, the 6th, fills it.

Hollow Night. Life 4, from 2 times 2.1. Walk 3.27. The rib pays 25.2. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 100.8, and the next, the 5th, fills it.

Deeper Night. Life 5, from 2 times 2.5. Walk 3.33. The rib pays 27. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 4 of them leave the plate at 108, and the next, the 5th, fills it.

Umbral Night. Life 6, from 2 times 3. Walk 3.39. The rib pays 28.8. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 4 of them leave the plate at 115.2, and the next, the 5th, fills it.

### The cinder caster

Dusk life 3, Dusk hurl 14, walk 2.5, poise 1.2. The cast stays 1.15 s and the disc stays 2.1. The landing below is the scaled spit. The slag tick stays 4 until sheet 286. Any blow still breaks the cast, because he is not a boss and his poise of 1.2 is the tell's other door.

Dusk. Life 3, from 3 times 1. Walk 2.5. The hurl pays 14. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 8 of them leave the plate at 112, and the next, the 9th, fills it.

Night. Life 4, from 3 times 1.25. Walk 2.58. The hurl pays 15.4. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 7 of them leave the plate at 107.8, and the next, the 8th, fills it.

Deep Night. Life 5, from 3 times 1.5. Walk 2.62. The hurl pays 16.8. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 7 of them leave the plate at 117.6, and the next, the 8th, fills it.

Black Night. Life 5, from 3 times 1.8. Walk 2.68. The hurl pays 18.2. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 6 of them leave the plate at 109.2, and the next, the 7th, fills it.

Hollow Night. Life 6, from 3 times 2.1. Walk 2.73. The hurl pays 19.6. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 6 of them leave the plate at 117.6, and the next, the 7th, fills it.

Deeper Night. Life 8, from 3 times 2.5. Walk 2.78. The hurl pays 21. 8 plain bolts end it. A full lance leaves 1.5. The staff chain leaves 3.3. 5 of them leave the plate at 105, and the next, the 6th, fills it.

Umbral Night. Life 9, from 3 times 3. Walk 2.82. The hurl pays 22.4. 9 plain bolts end it. A full lance leaves 2.5. The staff chain leaves 4.3. 5 of them leave the plate at 112, and the next, the 6th, fills it.

### The burrower

Dusk life 3, Dusk rake 18, walk 3.2, poise 2.6. The tunnel stays 7 m/s for at most 2.6 s, between 4.5 and 14 m, and it still refuses a light. The eruption is this rake times 1.2 on a disc of 1.7. Sheet 208 still owns the colour.

Dusk. Life 3, from 3 times 1. Walk 3.2. The rake pays 18. 3 plain bolts end it. A full lance ends it. The staff chain ends it. 6 of them leave the plate at 108, and the next, the 7th, fills it.

Night. Life 4, from 3 times 1.25. Walk 3.3. The rake pays 19.8. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 6 of them leave the plate at 118.8, and the next, the 7th, fills it.

Deep Night. Life 5, from 3 times 1.5. Walk 3.36. The rake pays 21.6. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 5 of them leave the plate at 108, and the next, the 6th, fills it.

Black Night. Life 5, from 3 times 1.8. Walk 3.42. The rake pays 23.4. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 5 of them leave the plate at 117, and the next, the 6th, fills it.

Hollow Night. Life 6, from 3 times 2.1. Walk 3.49. The rake pays 25.2. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 4 of them leave the plate at 100.8, and the next, the 5th, fills it.

Deeper Night. Life 8, from 3 times 2.5. Walk 3.55. The rake pays 27. 8 plain bolts end it. A full lance leaves 1.5. The staff chain leaves 3.3. 4 of them leave the plate at 108, and the next, the 5th, fills it.

Umbral Night. Life 9, from 3 times 3. Walk 3.62. The rake pays 28.8. 9 plain bolts end it. A full lance leaves 2.5. The staff chain leaves 4.3. 4 of them leave the plate at 115.2, and the next, the 5th, fills it.

### The ossuant

Dusk life 4, Dusk rake 28, walk 2.7, poise 3.2. He keeps the husk's reach of 1.55, half-angle 85°, slam, and charge, at this rake. The windup is his own 0.55. The heap stays 4 s and rises at half the life of that row. Sheet 212 still owns the bar.

Dusk. Life 4, from 4 times 1. Walk 2.7. The rake pays 28. 4 plain bolts end it. A full lance ends it. The staff chain ends it. 4 of them leave the plate at 112, and the next, the 5th, fills it.

Night. Life 5, from 4 times 1.25. Walk 2.78. The rake pays 30.8. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. 3 of them leave the plate at 92.4, and the next, the 4th, fills it.

Deep Night. Life 6, from 4 times 1.5. Walk 2.84. The rake pays 33.6. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 3 of them leave the plate at 100.8, and the next, the 4th, fills it.

Black Night. Life 7, from 4 times 1.8. Walk 2.89. The rake pays 36.4. 7 plain bolts end it. A full lance leaves 0.5. The staff chain leaves 2.3. 3 of them leave the plate at 109.2, and the next, the 4th, fills it.

Hollow Night. Life 8, from 4 times 2.1. Walk 2.94. The rake pays 39.2. 8 plain bolts end it. A full lance leaves 1.5. The staff chain leaves 3.3. 3 of them leave the plate at 117.6, and the next, the 4th, fills it.

Deeper Night. Life 10, from 4 times 2.5. Walk 3. The rake pays 42. 10 plain bolts end it. A full lance leaves 3.5. The staff chain leaves 5.3. 2 of them leave the plate at 84, and the next, the 3rd, fills it.

Umbral Night. Life 12, from 4 times 3. Walk 3.05. The rake pays 44.8. 12 plain bolts end it. A full lance leaves 5.5. The staff chain leaves 7.3. 2 of them leave the plate at 89.6, and the next, the 3rd, fills it.

### The bulwark

Dusk life 6, Dusk rake 30, walk 2, poise 4.5. Reach stays 1.6, half-angle 55°, windup 0.65. The boards stay 6 and still take a full lance without moving this life, which is sheet 282. The charge hit is this rake times 1.2. From the flank the lance's 6.5 is measured against the life below.

Dusk. Life 6, from 6 times 1. Walk 2. The rake pays 30. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. 3 of them leave the plate at 90, and the next, the 4th, fills it.

Night. Life 8, from 6 times 1.25. Walk 2.06. The rake pays 33. 8 plain bolts end it. A full lance leaves 1.5. The staff chain leaves 3.3. 3 of them leave the plate at 99, and the next, the 4th, fills it.

Deep Night. Life 9, from 6 times 1.5. Walk 2.1. The rake pays 36. 9 plain bolts end it. A full lance leaves 2.5. The staff chain leaves 4.3. 3 of them leave the plate at 108, and the next, the 4th, fills it.

Black Night. Life 11, from 6 times 1.8. Walk 2.14. The rake pays 39. 11 plain bolts end it. A full lance leaves 4.5. The staff chain leaves 6.3. 3 of them leave the plate at 117, and the next, the 4th, fills it.

Hollow Night. Life 13, from 6 times 2.1. Walk 2.18. The rake pays 42. 13 plain bolts end it. A full lance leaves 6.5. The staff chain leaves 8.3. 2 of them leave the plate at 84, and the next, the 3rd, fills it.

Deeper Night. Life 15, from 6 times 2.5. Walk 2.22. The rake pays 45. 15 plain bolts end it. A full lance leaves 8.5. The staff chain leaves 10.3. 2 of them leave the plate at 90, and the next, the 3rd, fills it.

Umbral Night. Life 18, from 6 times 3. Walk 2.26. The rake pays 48. 18 plain bolts end it. A full lance leaves 11.5. The staff chain leaves 13.3. 2 of them leave the plate at 96, and the next, the 3rd, fills it.

### The tollman

Dusk life 2, Dusk clang none, walk 3.1, poise 0.8. The ring stays 2.4 s and the wake stays 34 m. Sheet 206 still owns the earshot. Poise stays 0.8. The clang stays 14 at every row until sheet 286, because it is a literal and his think never fires the spit the tier scales.

Dusk. Life 2, from 2 times 1. Walk 3.1. The clang stays 14. 2 plain bolts end it. A full lance ends it. The staff chain ends it. Fourteen on a clang is the Dusk blow at every row: nine of them are 126 and fill the plate.

Night. Life 3, from 2 times 1.25. Walk 3.19. The clang stays 14. 3 plain bolts end it. A full lance ends it. The staff chain ends it. Fourteen on a clang is the Dusk blow at every row: nine of them are 126 and fill the plate.

Deep Night. Life 3, from 2 times 1.5. Walk 3.26. The clang stays 14. 3 plain bolts end it. A full lance ends it. The staff chain ends it. Fourteen on a clang is the Dusk blow at every row: nine of them are 126 and fill the plate.

Black Night. Life 4, from 2 times 1.8. Walk 3.32. The clang stays 14. 4 plain bolts end it. A full lance ends it. The staff chain ends it. Fourteen on a clang is the Dusk blow at every row: nine of them are 126 and fill the plate.

Hollow Night. Life 4, from 2 times 2.1. Walk 3.38. The clang stays 14. 4 plain bolts end it. A full lance ends it. The staff chain ends it. Fourteen on a clang is the Dusk blow at every row: nine of them are 126 and fill the plate.

Deeper Night. Life 5, from 2 times 2.5. Walk 3.44. The clang stays 14. 5 plain bolts end it. A full lance ends it. The staff chain leaves 0.3. Fourteen on a clang is the Dusk blow at every row: nine of them are 126 and fill the plate.

Umbral Night. Life 6, from 2 times 3. Walk 3.5. The clang stays 14. 6 plain bolts end it. A full lance ends it. The staff chain leaves 1.3. Fourteen on a clang is the Dusk blow at every row: nine of them are 126 and fill the plate.

### The brood-mother

She is a guardian, and guardians use the half-rate life in Part XXXV. The camp rows above do not apply to her. At Dusk that half-rate is still 44 life and a spit of 16, which is the body in Part XXXIII. Her escorts are the exception: they go through `Tiers.scale_stats`, the full camp row.

### The teeth the later rows add

Poise, reach, and the length of a tell stay. From Deep Night the pack gets chains and feints. `behave` uses `k = tier - 1`, capped at 5, and tiers 0 and 1 return before any of it. A body that already chains, or any flanker, gets `combo_max` of at least 1, and its chain chance rises by 0.06 times k, capped at 0.6. Anything with a strike range gains 0.04 feint chance times k, capped at 0.35. A gaunt is a flanker with his own chain at 0, so the late night gives him a chain. A pilgrim has a strike range and his own feint at 0, so the late night gives him feints. Sheet 245 still owns the red those feints owe.

The wretch.

Dusk: the body's own.

Night: the body's own.

Deep Night: chain 0.41, feint 0.26.

Black Night: chain 0.47, feint 0.3.

Hollow Night: chain 0.53, feint 0.34.

Deeper Night: chain 0.59, feint 0.35.

Umbral Night: chain 0.6, feint 0.35.

The pilgrim.

Dusk: the body's own.

Night: the body's own.

Deep Night: chain 0.51, feint 0.04.

Black Night: chain 0.57, feint 0.08.

Hollow Night: chain 0.6, feint 0.12.

Deeper Night: chain 0.6, feint 0.16.

Umbral Night: chain 0.6, feint 0.2.

The gaunt.

Dusk: the body's own.

Night: the body's own.

Deep Night: chain 0.06, feint 0.04.

Black Night: chain 0.12, feint 0.08.

Hollow Night: chain 0.18, feint 0.12.

Deeper Night: chain 0.24, feint 0.16.

Umbral Night: chain 0.3, feint 0.2.

The husk.

Dusk: the body's own.

Night: the body's own.

Deep Night: chain stays 0, feint 0.04.

Black Night: chain stays 0, feint 0.08.

Hollow Night: chain stays 0, feint 0.12.

Deeper Night: chain stays 0, feint 0.16.

Umbral Night: chain stays 0, feint 0.2.

A husk's own `combo_max` is 0 and he is not a flanker, so the chain chance stays 0 and `combo_max` stays 0. His feint still rises, because he has a strike range. The slam and the charge were already his, at every row.

### A variant on top of a row

`Variants.pre` runs after the row. It adds a flat life, adds a flat poise, and multiplies the row's walk by its pace. Scarred is +1 life, +0.6 poise, pace 1, scale 1.06. Ironclad is +2 life, +1.6 poise, pace 0.94, scale 1.08. The scale grows a slam or a sweep that reads the rig, and the rake's reach stays the body's. Night draws scarred. Deep Night through Hollow Night draw scarred and ironclad. Deeper Night and Umbral Night draw ironclad and deeper. A scarred line under Umbral is the add on its own. The pool at that row does not roll it. The life below is the row's life plus the flat add. The wound is the row's wound, because a variant does not multiply it.

The wretch, scarred and ironclad.

Dusk, scarred. Life 4. Poise 3.2. Walk 3.6. The rake is still 25. A full lance ends it.

Dusk, ironclad. Life 5. Poise 4.2. Walk 3.38. The rake is still 25. A full lance ends it.

Umbral Night, scarred. Life 10. Poise 3.2. Walk 4.07. The rake is still 40. A full lance leaves 3.5.

Umbral Night, ironclad. Life 11. Poise 4.2. Walk 3.82. The rake is still 40. A full lance leaves 4.5.

The husk, scarred and ironclad.

Dusk, scarred. Life 6. Poise 3.8. Walk 2.35. The rake is still 32. A full lance ends it.

Dusk, ironclad. Life 7. Poise 4.8. Walk 2.21. The rake is still 32. A full lance leaves 0.5.

Umbral Night, scarred. Life 16. Poise 3.8. Walk 2.66. The rake is still 51.2. A full lance leaves 9.5.

Umbral Night, ironclad. Life 17. Poise 4.8. Walk 2.5. The rake is still 51.2. A full lance leaves 10.5.

The gaunt, scarred and ironclad.

Dusk, scarred. Life 3. Poise 2.4. Walk 4.3. The dart is still 22. A full lance ends it.

Dusk, ironclad. Life 4. Poise 3.4. Walk 4.04. The dart is still 22. A full lance ends it.

Umbral Night, scarred. Life 7. Poise 2.4. Walk 4.86. The dart is still 35.2. A full lance leaves 0.5.

Umbral Night, ironclad. Life 8. Poise 3.4. Walk 4.57. The dart is still 35.2. A full lance leaves 1.5.

The pilgrim, scarred and ironclad.

Dusk, scarred. Life 5. Poise 2.2. Walk 2.7. The rake is still 24. A full lance ends it.

Dusk, ironclad. Life 6. Poise 3.2. Walk 2.54. The rake is still 24. A full lance ends it.

Umbral Night, scarred. Life 13. Poise 2.2. Walk 3.05. The rake is still 38.4. A full lance leaves 6.5.

Umbral Night, ironclad. Life 14. Poise 3.2. Walk 2.87. The rake is still 38.4. A full lance leaves 7.5.

The crawler, scarred and ironclad.

Dusk, scarred. Life 3. Poise 3.2. Walk 3.4. The rake is still 14. A full lance ends it.

Dusk, ironclad. Life 4. Poise 4.2. Walk 3.2. The rake is still 14. A full lance ends it.

Umbral Night, scarred. Life 7. Poise 3.2. Walk 3.84. The rake is still 22.4. A full lance leaves 0.5.

Umbral Night, ironclad. Life 8. Poise 4.2. Walk 3.61. The rake is still 22.4. A full lance leaves 1.5.

The mite, scarred and ironclad.

Dusk, scarred. Life 2. Poise 1.1. Walk 4.4. The rake is still 5. A full lance ends it.

Dusk, ironclad. Life 3. Poise 2.1. Walk 4.14. The rake is still 5. A full lance ends it.

Umbral Night, scarred. Life 4. Poise 1.1. Walk 4.97. The rake is still 8. A full lance ends it.

Umbral Night, ironclad. Life 5. Poise 2.1. Walk 4.67. The rake is still 8. A full lance ends it.

The leaper, scarred and ironclad.

Dusk, scarred. Life 5. Poise 3.2. Walk 4.2. The rake is still 28. A full lance ends it.

Dusk, ironclad. Life 6. Poise 4.2. Walk 3.95. The rake is still 28. A full lance ends it.

Umbral Night, scarred. Life 13. Poise 3.2. Walk 4.75. The rake is still 44.8. A full lance leaves 6.5.

Umbral Night, ironclad. Life 14. Poise 4.2. Walk 4.46. The rake is still 44.8. A full lance leaves 7.5.

The spitter, scarred and ironclad.

Dusk, scarred. Life 2. Poise 3.2. Walk 2.8. The orb is still 10. A full lance ends it.

Dusk, ironclad. Life 3. Poise 4.2. Walk 2.63. The orb is still 10. A full lance ends it.

Umbral Night, scarred. Life 4. Poise 3.2. Walk 3.16. The orb is still 16. A full lance ends it.

Umbral Night, ironclad. Life 5. Poise 4.2. Walk 2.97. The orb is still 16. A full lance ends it.

The chanter, scarred and ironclad.

Dusk, scarred. Life 3. Poise 1.5. Walk 2.6. The sigil is still 14. A full lance ends it.

Dusk, ironclad. Life 4. Poise 2.5. Walk 2.44. The sigil is still 14. A full lance ends it.

Umbral Night, scarred. Life 7. Poise 1.5. Walk 2.94. The sigil is still 22.4. A full lance leaves 0.5.

Umbral Night, ironclad. Life 8. Poise 2.5. Walk 2.76. The sigil is still 22.4. A full lance leaves 1.5.

The quiller, scarred and ironclad.

Dusk, scarred. Life 3. Poise 2.2. Walk 3. The rib is still 18. A full lance ends it.

Dusk, ironclad. Life 4. Poise 3.2. Walk 2.82. The rib is still 18. A full lance ends it.

Umbral Night, scarred. Life 7. Poise 2.2. Walk 3.39. The rib is still 28.8. A full lance leaves 0.5.

Umbral Night, ironclad. Life 8. Poise 3.2. Walk 3.19. The rib is still 28.8. A full lance leaves 1.5.

The cinder caster, scarred and ironclad.

Dusk, scarred. Life 4. Poise 1.8. Walk 2.5. The hurl is still 14. A full lance ends it.

Dusk, ironclad. Life 5. Poise 2.8. Walk 2.35. The hurl is still 14. A full lance ends it.

Umbral Night, scarred. Life 10. Poise 1.8. Walk 2.82. The hurl is still 22.4. A full lance leaves 3.5.

Umbral Night, ironclad. Life 11. Poise 2.8. Walk 2.66. The hurl is still 22.4. A full lance leaves 4.5.

The burrower, scarred and ironclad.

Dusk, scarred. Life 4. Poise 3.2. Walk 3.2. The rake is still 18. A full lance ends it.

Dusk, ironclad. Life 5. Poise 4.2. Walk 3.01. The rake is still 18. A full lance ends it.

Umbral Night, scarred. Life 10. Poise 3.2. Walk 3.62. The rake is still 28.8. A full lance leaves 3.5.

Umbral Night, ironclad. Life 11. Poise 4.2. Walk 3.4. The rake is still 28.8. A full lance leaves 4.5.

The ossuant, scarred and ironclad.

Dusk, scarred. Life 5. Poise 3.8. Walk 2.7. The rake is still 28. A full lance ends it.

Dusk, ironclad. Life 6. Poise 4.8. Walk 2.54. The rake is still 28. A full lance ends it.

Umbral Night, scarred. Life 13. Poise 3.8. Walk 3.05. The rake is still 44.8. A full lance leaves 6.5.

Umbral Night, ironclad. Life 14. Poise 4.8. Walk 2.87. The rake is still 44.8. A full lance leaves 7.5.

The bulwark, scarred and ironclad.

Dusk, scarred. Life 7. Poise 5.1. Walk 2. The rake is still 30. A full lance leaves 0.5.

Dusk, ironclad. Life 8. Poise 6.1. Walk 1.88. The rake is still 30. A full lance leaves 1.5.

Umbral Night, scarred. Life 19. Poise 5.1. Walk 2.26. The rake is still 48. A full lance leaves 12.5.

Umbral Night, ironclad. Life 20. Poise 6.1. Walk 2.12. The rake is still 48. A full lance leaves 13.5.

A guardian does not take scarred or ironclad from this dice. Her look, when she has one, is the variant on her own row, and Part XXXV has those two.

### Where the row starts

A region's base is `REGION_BASE`, plus bosses slain this cycle, plus two per Deeper Night cycle, clamped to the last row. One slain boss steps every country up one row. Two steps the hearth from Dusk to Deep Night. The summit starts at Black Night before anyone has fallen, and one boss puts it on Hollow Night. The pool is who can stand in that country. A regional variant replaces the dice for the kinds it names.

The hearth starts at Dusk, base 0. The pool is wretch, crawler. One slain boss moves it to Night.

The road starts at Dusk, base 0. The pool is wretch, crawler, husk, burrower, gaunt. One slain boss moves it to Night.

The glade starts at Dusk, base 0. The pool is crawler, wretch. One slain boss moves it to Night.

The chapel starts at Night, base 1. The pool is wretch, husk, spitter, chanter, tollman. One slain boss moves it to Deep Night.

The thornwood starts at Night, base 1. The pool is crawler, leaper, wretch, spitter, chanter, gaunt. One slain boss moves it to Deep Night.

The henge starts at Night, base 1. The pool is leaper, crawler, gaunt. One slain boss moves it to Deep Night.

The fen starts at Night, base 1. The pool is ossuant, spitter, wretch, burrower, quiller. One slain boss moves it to Deep Night.

The holds starts at Night, base 1. The pool is crawler, wretch. One slain boss moves it to Deep Night.

The moor starts at Night, base 1. The pool is gaunt, gaunt, wretch, crawler, husk. One slain boss moves it to Deep Night. The gaunt is in the pool twice, so a mixed draw leans to him.

The orchard starts at Night, base 1. The pool is burrower, mite, crawler, burrower, wretch. One slain boss moves it to Deep Night. The burrower is in the pool twice.

The necropolis starts at Night, base 1. The pool is pilgrim, pilgrim, ossuant, chanter, quiller. One slain boss moves it to Deep Night. The pilgrim is in the pool twice.

The mere starts at Night, base 1. The pool is husk, spitter, wretch, spitter, ossuant. One slain boss moves it to Deep Night. The husk, the wretch, and the ossuant wear Drowned: +1 life, +0.6 poise, pace 0.96, on top of the Night row.

The barrows starts at Deep Night, base 2. The pool is ossuant, husk, spitter, bulwark, quiller. One slain boss moves it to Black Night.

The ossuary starts at Deep Night, base 2. The pool is ossuant, husk, bulwark, quiller. One slain boss moves it to Black Night.

The rift starts at Deep Night, base 2. The pool is husk, spitter, leaper, bulwark, chanter, tollman. One slain boss moves it to Black Night.

The crags starts at Deep Night, base 2. The pool is leaper, husk, burrower, gaunt. One slain boss moves it to Black Night.

The quarry starts at Deep Night, base 2. The pool is husk, leaper, leaper, wretch, bulwark. One slain boss moves it to Black Night. The husk, the bulwark, and the leaper wear Stone-bound: +2 life, +2.2 poise, pace 0.9, on top of the Deep Night row. The leaper is in the pool twice.

The foundry starts at Deep Night, base 2. The pool is cinder caster, bulwark, wretch, cinder caster, gaunt. One slain boss moves it to Black Night. The cinder caster is in the pool twice. His slag tick is still the Dusk 4 until sheet 286, while his hurl has already taken Deep Night's 1.2.

The summit starts at Black Night, base 3. The pool is husk, spitter, leaper, bulwark, chanter, quiller. One slain boss moves it to Hollow Night.

### The second blow, by row

A slam, a charge, a tail, an eruption, and a lob are the body's scaled wound times a fixed share. The share stays. The row changes the wound under it. The plate is still 120, and the count below is blows outside the 0.35 s grace.

The husk's slam. The disc stays 2.2 times the rig scale, windup 0.85. Sheet 58 still owns the picture.

Dusk. The slam pays 36.8. 3 leave the plate at 110.4, and the 4th fills it.

Night. The slam pays 40.48. 2 leave the plate at 80.96, and the 3rd fills it.

Deep Night. The slam pays 44.16. 2 leave the plate at 88.32, and the 3rd fills it.

Black Night. The slam pays 47.84. 2 leave the plate at 95.68, and the 3rd fills it.

Hollow Night. The slam pays 51.52. 2 leave the plate at 103.04, and the 3rd fills it.

Deeper Night. The slam pays 55.2. 2 leave the plate at 110.4, and the 3rd fills it.

Umbral Night. The slam pays 58.88. 2 leave the plate at 117.76, and the 3rd fills it.

The husk's charge. The hit stays within 1.25 m of the body, the run stays 9.5, and it still starts between 5 and 10 m.

Dusk. The charge pays 38.4. 3 leave the plate at 115.2, and the 4th fills it.

Night. The charge pays 42.24. 2 leave the plate at 84.48, and the 3rd fills it.

Deep Night. The charge pays 46.08. 2 leave the plate at 92.16, and the 3rd fills it.

Black Night. The charge pays 49.92. 2 leave the plate at 99.84, and the 3rd fills it.

Hollow Night. The charge pays 53.76. 2 leave the plate at 107.52, and the 3rd fills it.

Deeper Night. The charge pays 57.6. 2 leave the plate at 115.2, and the 3rd fills it.

Umbral Night. The charge pays 61.44. 1 leave the plate at 61.44, and the 2nd fills it.

The leaper's tail. The disc stays 2.5 times the rig scale, tell 0.55, and the spin still runs 0.32 after it.

Dusk. The tail pays 22.4. 5 leave the plate at 112, and the 6th fills it.

Night. The tail pays 24.64. 4 leave the plate at 98.56, and the 5th fills it.

Deep Night. The tail pays 26.88. 4 leave the plate at 107.52, and the 5th fills it.

Black Night. The tail pays 29.12. 4 leave the plate at 116.48, and the 5th fills it.

Hollow Night. The tail pays 31.36. 3 leave the plate at 94.08, and the 4th fills it.

Deeper Night. The tail pays 33.6. 3 leave the plate at 100.8, and the 4th fills it.

Umbral Night. The tail pays 35.84. 3 leave the plate at 107.52, and the 4th fills it.

The burrower's eruption. The disc stays 1.7 and the tell stays 0.75. Sheet 208 still owns the colour.

Dusk. The eruption pays 21.6. 5 leave the plate at 108, and the 6th fills it.

Night. The eruption pays 23.76. 5 leave the plate at 118.8, and the 6th fills it.

Deep Night. The eruption pays 25.92. 4 leave the plate at 103.68, and the 5th fills it.

Black Night. The eruption pays 28.08. 4 leave the plate at 112.32, and the 5th fills it.

Hollow Night. The eruption pays 30.24. 3 leave the plate at 90.72, and the 4th fills it.

Deeper Night. The eruption pays 32.4. 3 leave the plate at 97.2, and the 4th fills it.

Umbral Night. The eruption pays 34.56. 3 leave the plate at 103.68, and the 4th fills it.

The spitter's lob. The landing disc stays 1.7. The acid tick stays 3 until sheet 286.

Dusk. The lob pays 12. 9 leave the plate at 108, and the 10th fills it.

Night. The lob pays 13.2. 9 leave the plate at 118.8, and the 10th fills it.

Deep Night. The lob pays 14.4. 8 leave the plate at 115.2, and the 9th fills it.

Black Night. The lob pays 15.6. 7 leave the plate at 109.2, and the 8th fills it.

Hollow Night. The lob pays 16.8. 7 leave the plate at 117.6, and the 8th fills it.

Deeper Night. The lob pays 18. 6 leave the plate at 108, and the 7th fills it.

Umbral Night. The lob pays 19.2. 6 leave the plate at 115.2, and the 7th fills it.

The ossuant's slam. He inherited the husk's disc. The wound is his rake of 28 times the share.

Dusk. The slam pays 32.2. 3 leave the plate at 96.6, and the 4th fills it.

Night. The slam pays 35.42. 3 leave the plate at 106.26, and the 4th fills it.

Deep Night. The slam pays 38.64. 3 leave the plate at 115.92, and the 4th fills it.

Black Night. The slam pays 41.86. 2 leave the plate at 83.72, and the 3rd fills it.

Hollow Night. The slam pays 45.08. 2 leave the plate at 90.16, and the 3rd fills it.

Deeper Night. The slam pays 48.3. 2 leave the plate at 96.6, and the 3rd fills it.

Umbral Night. The slam pays 51.52. 2 leave the plate at 103.04, and the 3rd fills it.

The ossuant's charge. The 1.25 m test is the husk's. The wound is his rake times 1.2.

Dusk. The charge pays 33.6. 3 leave the plate at 100.8, and the 4th fills it.

Night. The charge pays 36.96. 3 leave the plate at 110.88, and the 4th fills it.

Deep Night. The charge pays 40.32. 2 leave the plate at 80.64, and the 3rd fills it.

Black Night. The charge pays 43.68. 2 leave the plate at 87.36, and the 3rd fills it.

Hollow Night. The charge pays 47.04. 2 leave the plate at 94.08, and the 3rd fills it.

Deeper Night. The charge pays 50.4. 2 leave the plate at 100.8, and the 3rd fills it.

Umbral Night. The charge pays 53.76. 2 leave the plate at 107.52, and the 3rd fills it.

The bulwark's charge. The windup on this charge is his own 1.0. The boards are sheet 282 and are not this hit.

Dusk. The charge pays 36. 3 leave the plate at 108, and the 4th fills it.

Night. The charge pays 39.6. 3 leave the plate at 118.8, and the 4th fills it.

Deep Night. The charge pays 43.2. 2 leave the plate at 86.4, and the 3rd fills it.

Black Night. The charge pays 46.8. 2 leave the plate at 93.6, and the 3rd fills it.

Hollow Night. The charge pays 50.4. 2 leave the plate at 100.8, and the 3rd fills it.

Deeper Night. The charge pays 54. 2 leave the plate at 108, and the 3rd fills it.

Umbral Night. The charge pays 57.6. 2 leave the plate at 115.2, and the 3rd fills it.

## Part XXXV — the named ones

A guardian's life is the half-rate. `Guardians._scale` sets life to `round(base * (0.5 + 0.5 * tier.hp))`, halfway away from zero. At Dusk the factor is 1 and the written life stands. At Umbral the factor is 2, so she doubles, where a camp pawn of the same base would triple. The wound still takes the full `dmg` of the row. Walk does not take the camp's pace. A champion also multiplies `strike_gloom` by 1.3, adds 4 poise, sets feint to at least 0.12, refuses to flee, and sleeps at 60 m. The brood-mother skips champion. `behave` is not called, so the camp's extra chains stay with the camps. Her escorts are camp pawns. The mesh scale changes the rig and the capsule. The kind's strike reach stays the kind's.

### Brood-Mother

Written life 44. Poise 7. Walk 2.2. She is not a champion, so the 1.3 does not touch her, and her feint stays 0. The spit is 16 times the row's dmg. Walk stays 2.2 until her own enrage, at half life, multiplies it by 1.15. Ash is 14. Her countries are the thornwood, the glade, the fen, the crags, and the orchard. Her three mite escorts use the camp row, the full `scale_stats`, and Part XXXIV is their life.

Dusk. Life 44. The spit pays 16. A full lance leaves 37.5.

Night. Life 50. The spit pays 17.6. A full lance leaves 43.5.

Deep Night. Life 55. The spit pays 19.2. A full lance leaves 48.5.

Black Night. Life 62. The spit pays 20.8. A full lance leaves 55.5.

Hollow Night. Life 68. The spit pays 22.4. A full lance leaves 61.5.

Deeper Night. Life 77. The spit pays 24. A full lance leaves 70.5.

Umbral Night. Life 88. The spit pays 25.6. A full lance leaves 81.5.

### Tithe-Knight

Written life 34. Poise 8.5. Walk 2. A bulwark champion. The mesh scale is 1.45. Feint is at least 0.12. The rake is 30 times 1.3 times the row's dmg. The boards are still 6, and a full lance from the front still spends itself on them. Ash is 16. Chase is at least 15 and the leash is 16. Fleeing is off.

Dusk. Life 34. The rake pays 39. A full lance leaves 27.5.

Night. Life 38. The rake pays 42.9. A full lance leaves 31.5.

Deep Night. Life 43. The rake pays 46.8. A full lance leaves 36.5.

Black Night. Life 48. The rake pays 50.7. A full lance leaves 41.5.

Hollow Night. Life 53. The rake pays 54.6. A full lance leaves 46.5.

Deeper Night. Life 60. The rake pays 58.5. A full lance leaves 53.5.

Umbral Night. Life 68. The rake pays 62.4. A full lance leaves 61.5.

### Sexton of the Barrows

Written life 30. Poise 7.2. Walk 2.7. An ossuant champion. The mesh scale is 1.4. The rake is 28 times 1.3 times the row's dmg, and the husk's slam and charge use that rake. The heap is still 4 s and still rises at half of this row's life. Ash is 16.

Dusk. Life 30. The rake pays 36.4. A full lance leaves 23.5.

Night. Life 34. The rake pays 40.04. A full lance leaves 27.5.

Deep Night. Life 38. The rake pays 43.68. A full lance leaves 31.5.

Black Night. Life 42. The rake pays 47.32. A full lance leaves 35.5.

Hollow Night. Life 47. The rake pays 50.96. A full lance leaves 40.5.

Deeper Night. Life 53. The rake pays 54.6. A full lance leaves 46.5.

Umbral Night. Life 60. The rake pays 58.24. A full lance leaves 53.5.

### Pale Stalker

Written life 18. Poise 5.8. Walk 4.3. A gaunt champion. The mesh scale is 1.35. The dart is 22 times 1.3 times the row's dmg. The tell stays 0.55 and the run stays 11.5. Ash is 14. Feint is 0.12.

Dusk. Life 18. The dart pays 28.6. A full lance leaves 11.5.

Night. Life 20. The dart pays 31.46. A full lance leaves 13.5.

Deep Night. Life 23. The dart pays 34.32. A full lance leaves 16.5.

Black Night. Life 25. The dart pays 37.18. A full lance leaves 18.5.

Hollow Night. Life 28. The dart pays 40.04. A full lance leaves 21.5.

Deeper Night. Life 32. The dart pays 42.9. A full lance leaves 25.5.

Umbral Night. Life 36. The dart pays 45.76. A full lance leaves 29.5.

### Stonewright

Written life 40. Poise 9.4. Walk 2.12. A husk champion in stone-bound, so the variant's +2 life and +2.2 poise land after the half-rate, and the walk is 2.35 times 0.9. The mesh scale is 1.5. The rake is 32 times 1.3 times the row's dmg. Ash is 18. The quarry is her country.

Dusk. Life 42. The rake pays 41.6. A full lance leaves 35.5.

Night. Life 47. The rake pays 45.76. A full lance leaves 40.5.

Deep Night. Life 52. The rake pays 49.92. A full lance leaves 45.5.

Black Night. Life 58. The rake pays 54.08. A full lance leaves 51.5.

Hollow Night. Life 64. The rake pays 58.24. A full lance leaves 57.5.

Deeper Night. Life 72. The rake pays 62.4. A full lance leaves 65.5.

Umbral Night. Life 82. The rake pays 66.56. A full lance leaves 75.5.

### Bell-Founder

Written life 42. Poise 8.5. Walk 2. A bulwark champion. The mesh scale is 1.5. The rake is 30 times 1.3 times the row's dmg. The boards stay 6. Ash is 18. The foundry is his country. His cinder escorts are the camp row.

Dusk. Life 42. The rake pays 39. A full lance leaves 35.5.

Night. Life 47. The rake pays 42.9. A full lance leaves 40.5.

Deep Night. Life 53. The rake pays 46.8. A full lance leaves 46.5.

Black Night. Life 59. The rake pays 50.7. A full lance leaves 52.5.

Hollow Night. Life 65. The rake pays 54.6. A full lance leaves 58.5.

Deeper Night. Life 74. The rake pays 58.5. A full lance leaves 67.5.

Umbral Night. Life 84. The rake pays 62.4. A full lance leaves 77.5.

### Vigil-Keeper

Written life 30. Poise 4.9. Walk 2.6. A chanter champion. The mesh scale is 1.45. Champion's 1.3 lands on `strike_gloom`, and a chanter's strike is 0, so the sigil is the spit, 14 times the row's dmg, with no 1.3 on it. The shroud stays 6 s at half. Ash is 16. The necropolis is her country.

Dusk. Life 30. The sigil pays 14. A full lance leaves 23.5.

Night. Life 34. The sigil pays 15.4. A full lance leaves 27.5.

Deep Night. Life 38. The sigil pays 16.8. A full lance leaves 31.5.

Black Night. Life 42. The sigil pays 18.2. A full lance leaves 35.5.

Hollow Night. Life 47. The sigil pays 19.6. A full lance leaves 40.5.

Deeper Night. Life 53. The sigil pays 21. A full lance leaves 46.5.

Umbral Night. Life 60. The sigil pays 22.4. A full lance leaves 53.5.

### Drowned Deacon

Written life 36. Poise 7.8. Walk 2.26. A husk champion in drowned, so +1 life and +0.6 poise land after the half-rate, and the walk is 2.35 times 0.96. The mesh scale is 1.45. The rake is 32 times 1.3 times the row's dmg. Ash is 16. The mere is his country.

Dusk. Life 37. The rake pays 41.6. A full lance leaves 30.5.

Night. Life 42. The rake pays 45.76. A full lance leaves 35.5.

Deep Night. Life 46. The rake pays 49.92. A full lance leaves 39.5.

Black Night. Life 51. The rake pays 54.08. A full lance leaves 44.5.

Hollow Night. Life 57. The rake pays 58.24. A full lance leaves 50.5.

Deeper Night. Life 64. The rake pays 62.4. A full lance leaves 57.5.

Umbral Night. Life 73. The rake pays 66.56. A full lance leaves 66.5.

### Ash-Sow

Written life 36. Poise 6.6. Walk 3.2. A burrower champion. The mesh scale is 1.5. The rake is 18 times 1.3 times the row's dmg, and the eruption is that rake times 1.2. The tunnel stays 7 m/s. Ash is 16. The orchard is her country.

Dusk. Life 36. The rake pays 23.4. A full lance leaves 29.5.

Night. Life 41. The rake pays 25.74. A full lance leaves 34.5.

Deep Night. Life 45. The rake pays 28.08. A full lance leaves 38.5.

Black Night. Life 50. The rake pays 30.42. A full lance leaves 43.5.

Hollow Night. Life 56. The rake pays 32.76. A full lance leaves 49.5.

Deeper Night. Life 63. The rake pays 35.1. A full lance leaves 56.5.

Umbral Night. Life 72. The rake pays 37.44. A full lance leaves 65.5.

### Sedge-Mother

Written life 22. Poise 6.6. Walk 2.8. A spitter champion. The mesh scale is 1.45. The 1.3 lands on a strike of 0, so the orb is 10 times the row's dmg. The lob landing is that orb times 1.2. The acid tick stays 3 until sheet 286. Ash is 16. The mere is her country.

Dusk. Life 22. The orb pays 10. A full lance leaves 15.5.

Night. Life 25. The orb pays 11. A full lance leaves 18.5.

Deep Night. Life 28. The orb pays 12. A full lance leaves 21.5.

Black Night. Life 31. The orb pays 13. A full lance leaves 24.5.

Hollow Night. Life 34. The orb pays 14. A full lance leaves 27.5.

Deeper Night. Life 39. The orb pays 15. A full lance leaves 32.5.

Umbral Night. Life 44. The orb pays 16. A full lance leaves 37.5.

The half-rate is why a brood-mother in the thornwood, which starts at Night, is 50 life and spits for 17.6, and a camp wretch beside her nest is the Night wretch of Part XXXIV, 4 life and a rake of 27.5. Her mites, on the camp row, are still 1 life at Night. The same ground holds two scales at once. A wretch in the barrows at depth 0 is the Deep Night row, 5 life and a rake of 30. A mite in the orchard at depth 0 is still 1 life. One slain boss moves that orchard to Deep Night, and the mite has 2. A clang on the summit is still 14 until sheet 286. Dusk in Part XXXIII is the body these rows multiply. The tells stay the length they were given.

The next free sheet is 291. The sheets in Part XXXII are still the ones the night has not taken.

## Part XXXVI — the letter, the hatch, the kin

Read on 6 November from `elites.gd`, `director.gd`, `brood_mother.gd`, `elite_lisle.gd`, `guardians.gd`, and `boss_kit.gd`. Four places a player meets a number, or a body, the rest of that fight has already left behind. The next free sheet is 291.

### 287. Twenty measures

**See.** Hobb's letter promises twenty measures of ash at the Keg. On the first night the line under the letter says 20 grave ash, and the banner pays 20. After the bell the letter still says twenty. The line under it says 40, and the banner pays 40.

**Where.** `elites.gd`, Hobb's note. `director.gd` `_show_notice` builds the footer from the data's ash times 2 when `ng()` is above 0, and `_on_killed` pays that same number. Hobb's ash on the data is 20. The other five letters leave the measure to the footer. Lisle is 24, the hart 22, Old Sunk 26, the cantor 20, the penitent 30, and each of those doubles the same way once the Deeper Night has begun.

**Change.** The letter drops the measure. The footer keeps the live pay.

**Prove.** Read Hobb before the bell. The letter has no count of ash, and the footer says 20 grave ash. Ring the bell and read him again. The footer says 40, and felling him pays 40. Lisle's footer says 24, then 48, and his letter still leaves the measure there.

**Stay.** Three knocks stay. The data's 20 stays the first-night pay. The doubling stays.

**Band.** B.

### 288. The mites she hatches

**See.** The three mites that walk in with the brood-mother match the night. The mites that burst from the sac are the body from the kind's own init, on every row: life 1, a rake of 5, walk 4.4.

**Where.** `guardians.gd` builds her escort with `scale_stats` at her tier, then `region_variant`. `brood_mother.gd` hatches with `BossKit.summon` and then `alerted`. `scale_stats` is the escort's call. A mite's `_init` is life 1, rake 5, walk 4.4. On a mite, `scale_stats` leaves Night at 1 life and a rake of 5.5. Deep is 2 life and a rake of 6. Black and Hollow stay at 2 life, with rakes 6.5 and 7. Deeper and Umbral are 3 life, with rakes 7.5 and 8. Walk takes the row's pace: 4.4 times 1.03, 1.05, 1.07, 1.09, 1.11, 1.13, which is 4.532, 4.62, 4.708, 4.796, 4.884, 4.972. Sheet 285 owns the sac and the count. The three who walk in with her are the camp row in Part XXXV.

**Change.** Each mite the summon returns goes through `scale_stats` at her `enc_tier`, and through `region_variant`, the same two calls the escort loop makes. The count stays `mini(3, 6 - living)`.

**Prove.** At Night a hatch and an escort are both 1 life. At Deep a hatch is 2 life, rake 6, walk 4.62, the same as an escort mite on that row. At Umbral a hatch is 3 life and a rake of 8. The sac still ruptures the way sheet 285 says, and a ruptured brood still births none.

**Stay.** Her own enrage, walk times 1.15 at half of her life, stays hers. The escort three stay the camp row. Sheet 286 stays the linger under the rupture.

**Band.** B.

### 289. The count's two crawlers

**See.** Lisle calls two crawlers at half his life. They arrive as the crawler's own init on every row: life 2, a rake of 14, walk 3.4. A camp crawler has already left those numbers on the Night row.

**Where.** `elite_lisle.gd` `take_hit` calls `BossKit.summon` with `crawler.gd`, count 2, ring 3.2. `summon` sets the leash, the chase, and the owner. The camp planter is where `scale_stats` runs, and this call is the plain summon. `crawler.gd` `_init` is life 2, rake 14, walk 3.4, poise the default 2.6. `scale_stats` on that body: Night life 3 and rake 15.4; Deep life 3 and rake 16.8; Black life 4 and rake 18.2; Hollow life 4 and rake 19.6; Deeper life 5 and rake 21; Umbral life 6 and rake 22.4. Walk is 3.4 times the row's pace. Lisle's own life is the half-rate in Part XXXVII. `EliteKit.scale` stores his `enc_tier`.

**Change.** The two crawlers take `scale_stats` at Lisle's `enc_tier`, and `region_variant` at the spot they rose. They stay two. The call stays once.

**Prove.** On the Dusk row they are life 2 and a rake of 14, as now. On the Night row they are life 3 and a rake of 15.4, the camp crawler of that row. On the Umbral row they are life 6 and a rake of 22.4. Marking Lisle still ends the heap the way sheet 212 says, and the third fall is still the last.

**Stay.** The roar and the half-life test stay. `behave` rides along inside `scale_stats`, which is what a crawler planted on that row already has. On Night that function returns before it adds a chain.

**Band.** B.

### 290. The kin called at half

**See.** The escort that walks in with a guardian is the camp row. The two that answer at half health are the kind's own init.

**Where.** `guardians.gd` `enrage` summons two of `enrage_call` and calls `alerted`. The escort loop above that function is the one that calls `scale_stats` and `region_variant`. The callers, and the kind they ask for: the Tithe-Knight a wretch, the Sexton an ossuant, the Pale Stalker a gaunt, the Stonewright a leaper, the Bell-Founder a cinder, the Vigil-Keeper a pilgrim, the Drowned Deacon a wretch, the Ash-Sow a mite, the Sedge-Mother a spitter. The Brood-Mother has no `enrage_call`. Her hatch is sheet 288. The init bodies: a wretch is life 3, rake 25, walk 3.6; an ossuant is life 4, rake 28, walk 2.7; a gaunt is life 2, dart 22, walk 4.3; a leaper is life 4, rake 28, walk 4.2; a cinder is life 3, hurl 14, walk 2.5; a pilgrim is life 4, rake 24, walk 2.7; a mite is life 1, rake 5, walk 4.4; a spitter is life 1, orb 10, walk 2.8. A Deep wretch on the camp row is life 5 and a rake of 30. The two the Tithe-Knight calls stay life 3 and a rake of 25. `_scale` stores `enc_tier` on the guardian.

**Change.** Each summoned kin takes `scale_stats` at the guardian's `enc_tier`, and `region_variant` at the spot, the same two calls the escort loop makes. The count stays two. The guardian's own walk times 1.12 stays.

**Prove.** Drop the Tithe-Knight to half on a Deep row. The two wretches are life 5 and a rake of 30, the camp wretch of that row, and the wretch in his escort was already that row. Drop the Ash-Sow to half on an Umbral row. The two mites are life 3 and a rake of 8. On the Dusk row the called wretches are still life 3 and a rake of 25.

**Stay.** The Abbot's choir sets its own life to 4 after the summon, and this sheet leaves that choir. The Brood-Mother's hatch stays sheet 288. Part XXXV stays the guardian's own half-rate.

**Band.** B.

The letter, the hatch, and the two calls are the changes. Everything after this part is the night as it stands, counted from the same files, so a later sheet can cite the row instead of opening it again.

## Part XXXVII — the six hunts, on every row

`EliteKit.stats` sets the written life, adds 1.5 poise, and multiplies the kind's strike by 1.25. `spawn_elite` then calls `EliteKit.scale` at `tier_at` of the haunt that won. Life is that written life times (0.5 + 0.5 times the row's health), rounded half away from zero. The Deeper Night form multiplies that product by 1.6 before the rounding, doubles the ash, and multiplies walk by 1.06. Strike and spit take the row's full damage. Walk stays the kind's walk on the first night. The camp pace in Part XXXIV stays with the camps. The row you meet is `region_base` of whatever `region_at` returns for the haunt, plus the night's depth. The country named here is the one on the data. One slain boss steps every country up one row, and each Deeper Night cycle steps it two more before the 1.6.

### Hobb, Who Knocks Thrice

the Pilgrims' Road, east of Hearthward. The data names the country `road`, whose base row is Dusk. The trait on the notice: Knocks thrice: a three-blow chain, each blow with its own tell. Mesh scale 1.28. Poise 4.1 on every row. First-night walk 3.6. The banner pays 20 grave ash, and 40 once the Deeper Night has begun. The footer uses that same pay.

He is a wretch with the elite's 1.25 on the rake, then the row's damage on top of that. Reach 1.7, windup 0.45, lunge 5.5. His own combo is off and his feint is off, and the three knocks are his chain of three, each with its own tell. The note's three knocks match the chain. The twenty measures are sheet 287.

Dusk. First night, life 21. The rake pays 31.25. 21 plain bolts end it. 11 lashes of 2 end it. After 10, 1 life is left. 4 full lances of 6.5 end it. After 3, 1.5 life is left. 5 staff chains of 4.7 end it. After 4, 2.2 life is left. The Deeper Night form on this row is life 34, walk 3.816. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left.

Night. First night, life 24. The rake pays 34.375. 24 plain bolts end it. 12 lashes of 2 end it. After 11, 2 life is left. 4 full lances of 6.5 end it. After 3, 4.5 life is left. 6 staff chains of 4.7 end it. After 5, 0.5 life is left. The Deeper Night form on this row is life 38, walk 3.816. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left.

Deep Night. First night, life 26. The rake pays 37.5. 26 plain bolts end it. 13 lashes of 2 end it. After 12, 2 life is left. 4 full lances of 6.5 end it. After 3, 6.5 life is left. 6 staff chains of 4.7 end it. After 5, 2.5 life is left. The Deeper Night form on this row is life 42, walk 3.816. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left.

Black Night. First night, life 29. The rake pays 40.625. 29 plain bolts end it. 15 lashes of 2 end it. After 14, 1 life is left. 5 full lances of 6.5 end it. After 4, 3 life is left. 7 staff chains of 4.7 end it. After 6, 0.8 life is left. The Deeper Night form on this row is life 47, walk 3.816. 47 plain bolts end it. 24 lashes of 2 end it. After 23, 1 life is left. 8 full lances of 6.5 end it. After 7, 1.5 life is left. 10 staff chains of 4.7 end it. After 9, 4.7 life is left.

Hollow Night. First night, life 33. The rake pays 43.75. 33 plain bolts end it. 17 lashes of 2 end it. After 16, 1 life is left. 6 full lances of 6.5 end it. After 5, 0.5 life is left. 8 staff chains of 4.7 end it. After 7, 0.1 life is left. The Deeper Night form on this row is life 52, walk 3.816. 52 plain bolts end it. 26 lashes of 2 end it. After 25, 2 life is left. 8 full lances of 6.5 end it. After 7, 6.5 life is left. 12 staff chains of 4.7 end it. After 11, 0.3 life is left.

Deeper Night. First night, life 37. The rake pays 46.875. 37 plain bolts end it. 19 lashes of 2 end it. After 18, 1 life is left. 6 full lances of 6.5 end it. After 5, 4.5 life is left. 8 staff chains of 4.7 end it. After 7, 4.1 life is left. The Deeper Night form on this row is life 59, walk 3.816. 59 plain bolts end it. 30 lashes of 2 end it. After 29, 1 life is left. 10 full lances of 6.5 end it. After 9, 0.5 life is left. 13 staff chains of 4.7 end it. After 12, 2.6 life is left.

Umbral Night. First night, life 42. The rake pays 50. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left. The Deeper Night form on this row is life 67, walk 3.816. 67 plain bolts end it. 34 lashes of 2 end it. After 33, 1 life is left. 11 full lances of 6.5 end it. After 10, 2 life is left. 15 staff chains of 4.7 end it. After 14, 1.2 life is left.

### Brother Lisle, the Counted

the fen descent, by the Tally posts. The data names the country `barrows`, whose base row is Deep Night. The trait on the notice: Calls the count at half strength: two crawlers answer. Rises from the heap unless marked. Mesh scale 1.22. Poise 4.7 on every row. First-night walk 2.7. The banner pays 24 grave ash, and 48 once the Deeper Night has begun. The footer uses that same pay.

He is an ossuant with the elite's 1.25 on the rake. The heap is sheet 212: he rises at most twice, and the third fall forces a mark. At half of this row's life he calls two crawlers, once. Those two are sheet 289. Slam is this rake times 1.15. Charge is this rake times 1.2.

Dusk. First night, life 18. The rake pays 35. 18 plain bolts end it. 9 lashes of 2 end it. After 8, 2 life is left. 3 full lances of 6.5 end it. After 2, 5 life is left. 4 staff chains of 4.7 end it. After 3, 3.9 life is left. The Deeper Night form on this row is life 29, walk 2.862. 29 plain bolts end it. 15 lashes of 2 end it. After 14, 1 life is left. 5 full lances of 6.5 end it. After 4, 3 life is left. 7 staff chains of 4.7 end it. After 6, 0.8 life is left. Slam 40.25. Charge 42.

Night. First night, life 20. The rake pays 38.5. 20 plain bolts end it. 10 lashes of 2 end it. After 9, 2 life is left. 4 full lances of 6.5 end it. After 3, 0.5 life is left. 5 staff chains of 4.7 end it. After 4, 1.2 life is left. The Deeper Night form on this row is life 32, walk 2.862. 32 plain bolts end it. 16 lashes of 2 end it. After 15, 2 life is left. 5 full lances of 6.5 end it. After 4, 6 life is left. 7 staff chains of 4.7 end it. After 6, 3.8 life is left. Slam 44.275. Charge 46.2.

Deep Night. First night, life 23. The rake pays 42. 23 plain bolts end it. 12 lashes of 2 end it. After 11, 1 life is left. 4 full lances of 6.5 end it. After 3, 3.5 life is left. 5 staff chains of 4.7 end it. After 4, 4.2 life is left. The Deeper Night form on this row is life 36, walk 2.862. 36 plain bolts end it. 18 lashes of 2 end it. After 17, 2 life is left. 6 full lances of 6.5 end it. After 5, 3.5 life is left. 8 staff chains of 4.7 end it. After 7, 3.1 life is left. Slam 48.3. Charge 50.4.

Black Night. First night, life 25. The rake pays 45.5. 25 plain bolts end it. 13 lashes of 2 end it. After 12, 1 life is left. 4 full lances of 6.5 end it. After 3, 5.5 life is left. 6 staff chains of 4.7 end it. After 5, 1.5 life is left. The Deeper Night form on this row is life 40, walk 2.862. 40 plain bolts end it. 20 lashes of 2 end it. After 19, 2 life is left. 7 full lances of 6.5 end it. After 6, 1 life is left. 9 staff chains of 4.7 end it. After 8, 2.4 life is left. Slam 52.325. Charge 54.6.

Hollow Night. First night, life 28. The rake pays 49. 28 plain bolts end it. 14 lashes of 2 end it. After 13, 2 life is left. 5 full lances of 6.5 end it. After 4, 2 life is left. 6 staff chains of 4.7 end it. After 5, 4.5 life is left. The Deeper Night form on this row is life 45, walk 2.862. 45 plain bolts end it. 23 lashes of 2 end it. After 22, 1 life is left. 7 full lances of 6.5 end it. After 6, 6 life is left. 10 staff chains of 4.7 end it. After 9, 2.7 life is left. Slam 56.35. Charge 58.8.

Deeper Night. First night, life 32. The rake pays 52.5. 32 plain bolts end it. 16 lashes of 2 end it. After 15, 2 life is left. 5 full lances of 6.5 end it. After 4, 6 life is left. 7 staff chains of 4.7 end it. After 6, 3.8 life is left. The Deeper Night form on this row is life 50, walk 2.862. 50 plain bolts end it. 25 lashes of 2 end it. After 24, 2 life is left. 8 full lances of 6.5 end it. After 7, 4.5 life is left. 11 staff chains of 4.7 end it. After 10, 3 life is left. Slam 60.375. Charge 63.

Umbral Night. First night, life 36. The rake pays 56. 36 plain bolts end it. 18 lashes of 2 end it. After 17, 2 life is left. 6 full lances of 6.5 end it. After 5, 3.5 life is left. 8 staff chains of 4.7 end it. After 7, 3.1 life is left. The Deeper Night form on this row is life 58, walk 2.862. 58 plain bolts end it. 29 lashes of 2 end it. After 28, 2 life is left. 9 full lances of 6.5 end it. After 8, 6 life is left. 13 staff chains of 4.7 end it. After 12, 1.6 life is left. Slam 64.4. Charge 67.2.

### The Briar Hart

deep in the Thornwood, under the Crowns. The data names the country `thornwood`, whose base row is Night. The trait on the notice: Pounces far; where it lands, a ring of thorns erupts a moment later. Mesh scale 1.3. Poise 4.1 on every row. First-night walk 4.2. The banner pays 22 grave ash, and 44 once the Deeper Night has begun. The footer uses that same pay.

He is a leaper with the elite's 1.25 on the rake. Leap max 15, prep 0.55, cooldown 3.2. Where he lands, a ring of radius 2.8 fills for 0.8 s and pays this rake times 0.7. The note says to step off where he comes down, and the ring is that landing.

Dusk. First night, life 21. The rake pays 35. 21 plain bolts end it. 11 lashes of 2 end it. After 10, 1 life is left. 4 full lances of 6.5 end it. After 3, 1.5 life is left. 5 staff chains of 4.7 end it. After 4, 2.2 life is left. The Deeper Night form on this row is life 34, walk 4.452. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left. The landing ring pays 24.5.

Night. First night, life 24. The rake pays 38.5. 24 plain bolts end it. 12 lashes of 2 end it. After 11, 2 life is left. 4 full lances of 6.5 end it. After 3, 4.5 life is left. 6 staff chains of 4.7 end it. After 5, 0.5 life is left. The Deeper Night form on this row is life 38, walk 4.452. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left. The landing ring pays 26.95.

Deep Night. First night, life 26. The rake pays 42. 26 plain bolts end it. 13 lashes of 2 end it. After 12, 2 life is left. 4 full lances of 6.5 end it. After 3, 6.5 life is left. 6 staff chains of 4.7 end it. After 5, 2.5 life is left. The Deeper Night form on this row is life 42, walk 4.452. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left. The landing ring pays 29.4.

Black Night. First night, life 29. The rake pays 45.5. 29 plain bolts end it. 15 lashes of 2 end it. After 14, 1 life is left. 5 full lances of 6.5 end it. After 4, 3 life is left. 7 staff chains of 4.7 end it. After 6, 0.8 life is left. The Deeper Night form on this row is life 47, walk 4.452. 47 plain bolts end it. 24 lashes of 2 end it. After 23, 1 life is left. 8 full lances of 6.5 end it. After 7, 1.5 life is left. 10 staff chains of 4.7 end it. After 9, 4.7 life is left. The landing ring pays 31.85.

Hollow Night. First night, life 33. The rake pays 49. 33 plain bolts end it. 17 lashes of 2 end it. After 16, 1 life is left. 6 full lances of 6.5 end it. After 5, 0.5 life is left. 8 staff chains of 4.7 end it. After 7, 0.1 life is left. The Deeper Night form on this row is life 52, walk 4.452. 52 plain bolts end it. 26 lashes of 2 end it. After 25, 2 life is left. 8 full lances of 6.5 end it. After 7, 6.5 life is left. 12 staff chains of 4.7 end it. After 11, 0.3 life is left. The landing ring pays 34.3.

Deeper Night. First night, life 37. The rake pays 52.5. 37 plain bolts end it. 19 lashes of 2 end it. After 18, 1 life is left. 6 full lances of 6.5 end it. After 5, 4.5 life is left. 8 staff chains of 4.7 end it. After 7, 4.1 life is left. The Deeper Night form on this row is life 59, walk 4.452. 59 plain bolts end it. 30 lashes of 2 end it. After 29, 1 life is left. 10 full lances of 6.5 end it. After 9, 0.5 life is left. 13 staff chains of 4.7 end it. After 12, 2.6 life is left. The landing ring pays 36.75.

Umbral Night. First night, life 42. The rake pays 56. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left. The Deeper Night form on this row is life 67, walk 4.452. 67 plain bolts end it. 34 lashes of 2 end it. After 33, 1 life is left. 11 full lances of 6.5 end it. After 10, 2 life is left. 15 staff chains of 4.7 end it. After 14, 1.2 life is left. The landing ring pays 39.2.

### Old Sunk, Three Stones

the Hollow Fen, south pools. The data names the country `fen`, whose base row is Night. The trait on the notice: Raises the fen: a wide ring fills under him, then slams. Mesh scale 1.32. Poise 4.7 on every row. First-night walk 2.35. The banner pays 26 grave ash, and 52 once the Deeper Night has begun. The footer uses that same pay.

He is a husk with the elite's 1.25 on the rake, and his slam is off. Every 6.5 s in close he stands for a tell of 1.0 s and the fen pays this rake times 0.9 inside 3.6 m. The charge stays, at this rake times 1.2. The note says to get out of the ring. The three stones are the name. The heart-stone is the trophy.

Dusk. First night, life 30. The rake pays 40. 30 plain bolts end it. 15 lashes of 2 end it. After 14, 2 life is left. 5 full lances of 6.5 end it. After 4, 4 life is left. 7 staff chains of 4.7 end it. After 6, 1.8 life is left. The Deeper Night form on this row is life 48, walk 2.491. 48 plain bolts end it. 24 lashes of 2 end it. After 23, 2 life is left. 8 full lances of 6.5 end it. After 7, 2.5 life is left. 11 staff chains of 4.7 end it. After 10, 1 life is left. The fen ring pays 36. Charge 48.

Night. First night, life 34. The rake pays 44. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left. The Deeper Night form on this row is life 54, walk 2.491. 54 plain bolts end it. 27 lashes of 2 end it. After 26, 2 life is left. 9 full lances of 6.5 end it. After 8, 2 life is left. 12 staff chains of 4.7 end it. After 11, 2.3 life is left. The fen ring pays 39.6. Charge 52.8.

Deep Night. First night, life 38. The rake pays 48. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left. The Deeper Night form on this row is life 60, walk 2.491. 60 plain bolts end it. 30 lashes of 2 end it. After 29, 2 life is left. 10 full lances of 6.5 end it. After 9, 1.5 life is left. 13 staff chains of 4.7 end it. After 12, 3.6 life is left. The fen ring pays 43.2. Charge 57.6.

Black Night. First night, life 42. The rake pays 52. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left. The Deeper Night form on this row is life 67, walk 2.491. 67 plain bolts end it. 34 lashes of 2 end it. After 33, 1 life is left. 11 full lances of 6.5 end it. After 10, 2 life is left. 15 staff chains of 4.7 end it. After 14, 1.2 life is left. The fen ring pays 46.8. Charge 62.4.

Hollow Night. First night, life 47. The rake pays 56. 47 plain bolts end it. 24 lashes of 2 end it. After 23, 1 life is left. 8 full lances of 6.5 end it. After 7, 1.5 life is left. 10 staff chains of 4.7 end it. After 9, 4.7 life is left. The Deeper Night form on this row is life 74, walk 2.491. 74 plain bolts end it. 37 lashes of 2 end it. After 36, 2 life is left. 12 full lances of 6.5 end it. After 11, 2.5 life is left. 16 staff chains of 4.7 end it. After 15, 3.5 life is left. The fen ring pays 50.4. Charge 67.2.

Deeper Night. First night, life 53. The rake pays 60. 53 plain bolts end it. 27 lashes of 2 end it. After 26, 1 life is left. 9 full lances of 6.5 end it. After 8, 1 life is left. 12 staff chains of 4.7 end it. After 11, 1.3 life is left. The Deeper Night form on this row is life 84, walk 2.491. 84 plain bolts end it. 42 lashes of 2 end it. After 41, 2 life is left. 13 full lances of 6.5 end it. After 12, 6 life is left. 18 staff chains of 4.7 end it. After 17, 4.1 life is left. The fen ring pays 54. Charge 72.

Umbral Night. First night, life 60. The rake pays 64. 60 plain bolts end it. 30 lashes of 2 end it. After 29, 2 life is left. 10 full lances of 6.5 end it. After 9, 1.5 life is left. 13 staff chains of 4.7 end it. After 12, 3.6 life is left. The Deeper Night form on this row is life 96, walk 2.491. 96 plain bolts end it. 48 lashes of 2 end it. After 47, 2 life is left. 15 full lances of 6.5 end it. After 14, 5 life is left. 21 staff chains of 4.7 end it. After 20, 2 life is left. The fen ring pays 57.6. Charge 76.8.

### The Cinder Cantor

the Ashen Rift's rim, near the Crossing. The data names the country `rift`, whose base row is Deep Night. The trait on the notice: Spits a fan of three coals; keeps its distance. Mesh scale 1.24. Poise 4.1 on every row. First-night walk 2.8. The banner pays 20 grave ash, and 40 once the Deeper Night has begun. The footer uses that same pay.

He is a spitter who sets his orb to 9 after the kind's 10, so the row multiplies 9 and the elite's 1.25 lands on a strike of 0. The fan is three orbs, spread by 0.26 radians, and the note's three coals are that fan. Kite 7 to 12, fire 17, cooldown 2.8.

Dusk. First night, life 12. The orb pays 9. 12 plain bolts end it. 6 lashes of 2 end it. After 5, 2 life is left. 2 full lances of 6.5 end it. After 1, 5.5 life is left. 3 staff chains of 4.7 end it. After 2, 2.6 life is left. The Deeper Night form on this row is life 19, walk 2.968. 19 plain bolts end it. 10 lashes of 2 end it. After 9, 1 life is left. 3 full lances of 6.5 end it. After 2, 6 life is left. 5 staff chains of 4.7 end it. After 4, 0.2 life is left. Each of the three coals pays 9.

Night. First night, life 14. The orb pays 9.9. 14 plain bolts end it. 7 lashes of 2 end it. After 6, 2 life is left. 3 full lances of 6.5 end it. After 2, 1 life is left. 3 staff chains of 4.7 end it. After 2, 4.6 life is left. The Deeper Night form on this row is life 22, walk 2.968. 22 plain bolts end it. 11 lashes of 2 end it. After 10, 2 life is left. 4 full lances of 6.5 end it. After 3, 2.5 life is left. 5 staff chains of 4.7 end it. After 4, 3.2 life is left. Each of the three coals pays 9.9.

Deep Night. First night, life 15. The orb pays 10.8. 15 plain bolts end it. 8 lashes of 2 end it. After 7, 1 life is left. 3 full lances of 6.5 end it. After 2, 2 life is left. 4 staff chains of 4.7 end it. After 3, 0.9 life is left. The Deeper Night form on this row is life 24, walk 2.968. 24 plain bolts end it. 12 lashes of 2 end it. After 11, 2 life is left. 4 full lances of 6.5 end it. After 3, 4.5 life is left. 6 staff chains of 4.7 end it. After 5, 0.5 life is left. Each of the three coals pays 10.8.

Black Night. First night, life 17. The orb pays 11.7. 17 plain bolts end it. 9 lashes of 2 end it. After 8, 1 life is left. 3 full lances of 6.5 end it. After 2, 4 life is left. 4 staff chains of 4.7 end it. After 3, 2.9 life is left. The Deeper Night form on this row is life 27, walk 2.968. 27 plain bolts end it. 14 lashes of 2 end it. After 13, 1 life is left. 5 full lances of 6.5 end it. After 4, 1 life is left. 6 staff chains of 4.7 end it. After 5, 3.5 life is left. Each of the three coals pays 11.7.

Hollow Night. First night, life 19. The orb pays 12.6. 19 plain bolts end it. 10 lashes of 2 end it. After 9, 1 life is left. 3 full lances of 6.5 end it. After 2, 6 life is left. 5 staff chains of 4.7 end it. After 4, 0.2 life is left. The Deeper Night form on this row is life 30, walk 2.968. 30 plain bolts end it. 15 lashes of 2 end it. After 14, 2 life is left. 5 full lances of 6.5 end it. After 4, 4 life is left. 7 staff chains of 4.7 end it. After 6, 1.8 life is left. Each of the three coals pays 12.6.

Deeper Night. First night, life 21. The orb pays 13.5. 21 plain bolts end it. 11 lashes of 2 end it. After 10, 1 life is left. 4 full lances of 6.5 end it. After 3, 1.5 life is left. 5 staff chains of 4.7 end it. After 4, 2.2 life is left. The Deeper Night form on this row is life 34, walk 2.968. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left. Each of the three coals pays 13.5.

Umbral Night. First night, life 24. The orb pays 14.4. 24 plain bolts end it. 12 lashes of 2 end it. After 11, 2 life is left. 4 full lances of 6.5 end it. After 3, 4.5 life is left. 6 staff chains of 4.7 end it. After 5, 0.5 life is left. The Deeper Night form on this row is life 38, walk 2.968. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left. Each of the three coals pays 14.4.

### The Faceless Penitent

the Kindlers' yard, west of the chapel (the Deeper Night only). The data names the country `chapel`, whose base row is Night. The trait on the notice: Steps through the dark: a tear opens beside you, then he is there. Mesh scale 1.3. Poise 4.1 on every row. First-night walk 3.6. The banner pays 30 grave ash, and 60 once the Deeper Night has begun. The footer uses that same pay.

He is a wretch with the elite's 1.25 on the rake, reach 1.6. He plants only once the Deeper Night has begun (`ng_only`), and the spawn passes the umbral flag, so the life below is the half-rate times 1.6. A step every 8 s, the first wait 4 s, a tell of 0.8 s, and only while you stand in the dark between 5 m and 14 m. The note says to watch for the tear.

Dusk. The form he wears is life 38. The rake pays 31.25. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left. Walk 3.816.

Night. The form he wears is life 43. The rake pays 34.375. 43 plain bolts end it. 22 lashes of 2 end it. After 21, 1 life is left. 7 full lances of 6.5 end it. After 6, 4 life is left. 10 staff chains of 4.7 end it. After 9, 0.7 life is left. Walk 3.816.

Deep Night. The form he wears is life 48. The rake pays 37.5. 48 plain bolts end it. 24 lashes of 2 end it. After 23, 2 life is left. 8 full lances of 6.5 end it. After 7, 2.5 life is left. 11 staff chains of 4.7 end it. After 10, 1 life is left. Walk 3.816.

Black Night. The form he wears is life 54. The rake pays 40.625. 54 plain bolts end it. 27 lashes of 2 end it. After 26, 2 life is left. 9 full lances of 6.5 end it. After 8, 2 life is left. 12 staff chains of 4.7 end it. After 11, 2.3 life is left. Walk 3.816.

Hollow Night. The form he wears is life 60. The rake pays 43.75. 60 plain bolts end it. 30 lashes of 2 end it. After 29, 2 life is left. 10 full lances of 6.5 end it. After 9, 1.5 life is left. 13 staff chains of 4.7 end it. After 12, 3.6 life is left. Walk 3.816.

Deeper Night. The form he wears is life 67. The rake pays 46.875. 67 plain bolts end it. 34 lashes of 2 end it. After 33, 1 life is left. 11 full lances of 6.5 end it. After 10, 2 life is left. 15 staff chains of 4.7 end it. After 14, 1.2 life is left. Walk 3.816.

Umbral Night. The form he wears is life 77. The rake pays 50. 77 plain bolts end it. 39 lashes of 2 end it. After 38, 1 life is left. 12 full lances of 6.5 end it. After 11, 5.5 life is left. 17 staff chains of 4.7 end it. After 16, 1.8 life is left. Walk 3.816.

## Part XXXVIII — eighteen names, on every row

`spawn_rare` sets life to the written number, adds 1.5 poise, and multiplies strike by 1.2. Spit is left alone at that step. `EliteKit.scale` then applies the half-rate to the life and the row's full damage to strike and to spit, with the umbral flag false, so the life stays that half-rate and the walk stays the kind's walk. A variant, when the data names one, is applied after that: stone-bound adds 2 life and 2.2 poise and multiplies walk by 0.9; drowned adds 1 life and 0.6 poise and multiplies walk by 0.96. The row is `tier_at` of the haunt that won. These eighteen are the whole of `RARES`. A beat is 6 m around the haunt. A route is walked at 1.35 m/s. They are present while you are within 95 m, and they leave past 130 m. A fallen one returns after 480 s. A plain bolt pays 1. Sheet 236's chip is the boss absorb, and a rare carries `rare_id`.

### Gutterwick the Lamp-Eater

A wretch. The data's mesh scale is 1.3. It walks a beat of 6 m. The fall pays 30 grave ash, and 1 relic_fragment. The toast: Gutterwick falls. The lamp-oil in its belly burns blue, then out. Poise 4.1. Walk 3.6.

Dusk. Life 22. The rake pays 30. 22 plain bolts end it. 11 lashes of 2 end it. After 10, 2 life is left. 4 full lances of 6.5 end it. After 3, 2.5 life is left. 5 staff chains of 4.7 end it. After 4, 3.2 life is left.

Night. Life 25. The rake pays 33. 25 plain bolts end it. 13 lashes of 2 end it. After 12, 1 life is left. 4 full lances of 6.5 end it. After 3, 5.5 life is left. 6 staff chains of 4.7 end it. After 5, 1.5 life is left.

Deep Night. Life 28. The rake pays 36. 28 plain bolts end it. 14 lashes of 2 end it. After 13, 2 life is left. 5 full lances of 6.5 end it. After 4, 2 life is left. 6 staff chains of 4.7 end it. After 5, 4.5 life is left.

Black Night. Life 31. The rake pays 39. 31 plain bolts end it. 16 lashes of 2 end it. After 15, 1 life is left. 5 full lances of 6.5 end it. After 4, 5 life is left. 7 staff chains of 4.7 end it. After 6, 2.8 life is left.

Hollow Night. Life 34. The rake pays 42. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left.

Deeper Night. Life 39. The rake pays 45. 39 plain bolts end it. 20 lashes of 2 end it. After 19, 1 life is left. 6 full lances of 6.5 end it. After 5, 6.5 life is left. 9 staff chains of 4.7 end it. After 8, 1.4 life is left.

Umbral Night. Life 44. The rake pays 48. 44 plain bolts end it. 22 lashes of 2 end it. After 21, 2 life is left. 7 full lances of 6.5 end it. After 6, 5 life is left. 10 staff chains of 4.7 end it. After 9, 1.7 life is left.

### Mother Sallow

A spitter. The data's mesh scale is 1.3. It walks a beat of 6 m. The fall pays 32 grave ash, and 2 relic_fragment. The toast: Mother Sallow sinks into the fen she nursed. Poise 4.1. Walk 2.8.

The lob is the orb times 1.2. The acid tick under it stays the literal sheet 286 names.

Dusk. Life 18. The orb pays 10. Lob 12. 18 plain bolts end it. 9 lashes of 2 end it. After 8, 2 life is left. 3 full lances of 6.5 end it. After 2, 5 life is left. 4 staff chains of 4.7 end it. After 3, 3.9 life is left.

Night. Life 20. The orb pays 11. Lob 13.2. 20 plain bolts end it. 10 lashes of 2 end it. After 9, 2 life is left. 4 full lances of 6.5 end it. After 3, 0.5 life is left. 5 staff chains of 4.7 end it. After 4, 1.2 life is left.

Deep Night. Life 23. The orb pays 12. Lob 14.4. 23 plain bolts end it. 12 lashes of 2 end it. After 11, 1 life is left. 4 full lances of 6.5 end it. After 3, 3.5 life is left. 5 staff chains of 4.7 end it. After 4, 4.2 life is left.

Black Night. Life 25. The orb pays 13. Lob 15.6. 25 plain bolts end it. 13 lashes of 2 end it. After 12, 1 life is left. 4 full lances of 6.5 end it. After 3, 5.5 life is left. 6 staff chains of 4.7 end it. After 5, 1.5 life is left.

Hollow Night. Life 28. The orb pays 14. Lob 16.8. 28 plain bolts end it. 14 lashes of 2 end it. After 13, 2 life is left. 5 full lances of 6.5 end it. After 4, 2 life is left. 6 staff chains of 4.7 end it. After 5, 4.5 life is left.

Deeper Night. Life 32. The orb pays 15. Lob 18. 32 plain bolts end it. 16 lashes of 2 end it. After 15, 2 life is left. 5 full lances of 6.5 end it. After 4, 6 life is left. 7 staff chains of 4.7 end it. After 6, 3.8 life is left.

Umbral Night. Life 36. The orb pays 16. Lob 19.2. 36 plain bolts end it. 18 lashes of 2 end it. After 17, 2 life is left. 6 full lances of 6.5 end it. After 5, 3.5 life is left. 8 staff chains of 4.7 end it. After 7, 3.1 life is left.

### Wicker Jack, the Grinning

A gaunt. The data's mesh scale is 1.25. It walks a beat of 6 m. The fall pays 30 grave ash, and 1 relic_fragment. The toast: Wicker Jack comes apart in straw and teeth. Poise 3.3. Walk 4.3.

Dusk. Life 20. The dart pays 26.4. 20 plain bolts end it. 10 lashes of 2 end it. After 9, 2 life is left. 4 full lances of 6.5 end it. After 3, 0.5 life is left. 5 staff chains of 4.7 end it. After 4, 1.2 life is left.

Night. Life 23. The dart pays 29.04. 23 plain bolts end it. 12 lashes of 2 end it. After 11, 1 life is left. 4 full lances of 6.5 end it. After 3, 3.5 life is left. 5 staff chains of 4.7 end it. After 4, 4.2 life is left.

Deep Night. Life 25. The dart pays 31.68. 25 plain bolts end it. 13 lashes of 2 end it. After 12, 1 life is left. 4 full lances of 6.5 end it. After 3, 5.5 life is left. 6 staff chains of 4.7 end it. After 5, 1.5 life is left.

Black Night. Life 28. The dart pays 34.32. 28 plain bolts end it. 14 lashes of 2 end it. After 13, 2 life is left. 5 full lances of 6.5 end it. After 4, 2 life is left. 6 staff chains of 4.7 end it. After 5, 4.5 life is left.

Hollow Night. Life 31. The dart pays 36.96. 31 plain bolts end it. 16 lashes of 2 end it. After 15, 1 life is left. 5 full lances of 6.5 end it. After 4, 5 life is left. 7 staff chains of 4.7 end it. After 6, 2.8 life is left.

Deeper Night. Life 35. The dart pays 39.6. 35 plain bolts end it. 18 lashes of 2 end it. After 17, 1 life is left. 6 full lances of 6.5 end it. After 5, 2.5 life is left. 8 staff chains of 4.7 end it. After 7, 2.1 life is left.

Umbral Night. Life 40. The dart pays 42.24. 40 plain bolts end it. 20 lashes of 2 end it. After 19, 2 life is left. 7 full lances of 6.5 end it. After 6, 1 life is left. 9 staff chains of 4.7 end it. After 8, 2.4 life is left.

### Cairnback

A husk. The data's mesh scale is 1.35. It walks a beat of 6 m. The fall pays 40 grave ash, and 3 relic_fragment. The toast: Cairnback settles, a barrow at last. Poise 4.7. Walk 2.35.

Slam is the rake times 1.15, on a disc of the kind's radius times the mesh scale. Charge is the rake times 1.2, and the hit is the kind's 1.25 m test.

Dusk. Life 34. The rake pays 38.4. Slam 44.16. Charge 46.08. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left.

Night. Life 38. The rake pays 42.24. Slam 48.576. Charge 50.688. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left.

Deep Night. Life 43. The rake pays 46.08. Slam 52.992. Charge 55.296. 43 plain bolts end it. 22 lashes of 2 end it. After 21, 1 life is left. 7 full lances of 6.5 end it. After 6, 4 life is left. 10 staff chains of 4.7 end it. After 9, 0.7 life is left.

Black Night. Life 48. The rake pays 49.92. Slam 57.408. Charge 59.904. 48 plain bolts end it. 24 lashes of 2 end it. After 23, 2 life is left. 8 full lances of 6.5 end it. After 7, 2.5 life is left. 11 staff chains of 4.7 end it. After 10, 1 life is left.

Hollow Night. Life 53. The rake pays 53.76. Slam 61.824. Charge 64.512. 53 plain bolts end it. 27 lashes of 2 end it. After 26, 1 life is left. 9 full lances of 6.5 end it. After 8, 1 life is left. 12 staff chains of 4.7 end it. After 11, 1.3 life is left.

Deeper Night. Life 60. The rake pays 57.6. Slam 66.24. Charge 69.12. 60 plain bolts end it. 30 lashes of 2 end it. After 29, 2 life is left. 10 full lances of 6.5 end it. After 9, 1.5 life is left. 13 staff chains of 4.7 end it. After 12, 3.6 life is left.

Umbral Night. Life 68. The rake pays 61.44. Slam 70.656. Charge 73.728. 68 plain bolts end it. 34 lashes of 2 end it. After 33, 2 life is left. 11 full lances of 6.5 end it. After 10, 3 life is left. 15 staff chains of 4.7 end it. After 14, 2.2 life is left.

### Brother Chisel, the Four-Thousandth

A husk. The look is stone-bound. Dress multiplies the rig by 1.06 and the data's scale is applied after that, so the rig is 1.4 times 1.06. The data's mesh scale is 1.4. It walks a beat of 6 m. The fall pays 42 grave ash, and 2 relic_fragment. The toast: Brother Chisel sets down his last stone. The step is finished. Poise 6.9. Walk 2.115.

Slam is the rake times 1.15, on a disc of the kind's radius times the mesh scale. Charge is the rake times 1.2, and the hit is the kind's 1.25 m test.

Dusk. Life 42. The rake pays 38.4. Slam 44.16. Charge 46.08. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left.

Night. Life 47. The rake pays 42.24. Slam 48.576. Charge 50.688. 47 plain bolts end it. 24 lashes of 2 end it. After 23, 1 life is left. 8 full lances of 6.5 end it. After 7, 1.5 life is left. 10 staff chains of 4.7 end it. After 9, 4.7 life is left.

Deep Night. Life 52. The rake pays 46.08. Slam 52.992. Charge 55.296. 52 plain bolts end it. 26 lashes of 2 end it. After 25, 2 life is left. 8 full lances of 6.5 end it. After 7, 6.5 life is left. 12 staff chains of 4.7 end it. After 11, 0.3 life is left.

Black Night. Life 58. The rake pays 49.92. Slam 57.408. Charge 59.904. 58 plain bolts end it. 29 lashes of 2 end it. After 28, 2 life is left. 9 full lances of 6.5 end it. After 8, 6 life is left. 13 staff chains of 4.7 end it. After 12, 1.6 life is left.

Hollow Night. Life 64. The rake pays 53.76. Slam 61.824. Charge 64.512. 64 plain bolts end it. 32 lashes of 2 end it. After 31, 2 life is left. 10 full lances of 6.5 end it. After 9, 5.5 life is left. 14 staff chains of 4.7 end it. After 13, 2.9 life is left.

Deeper Night. Life 72. The rake pays 57.6. Slam 66.24. Charge 69.12. 72 plain bolts end it. 36 lashes of 2 end it. After 35, 2 life is left. 12 full lances of 6.5 end it. After 11, 0.5 life is left. 16 staff chains of 4.7 end it. After 15, 1.5 life is left.

Umbral Night. Life 82. The rake pays 61.44. Slam 70.656. Charge 73.728. 82 plain bolts end it. 41 lashes of 2 end it. After 40, 2 life is left. 13 full lances of 6.5 end it. After 12, 4 life is left. 18 staff chains of 4.7 end it. After 17, 2.1 life is left.

### Clapper, the Bell-Tongue

A cinder. The data's mesh scale is 1.35. It walks a beat of 6 m. The fall pays 40 grave ash, and 2 relic_fragment. The toast: Clapper cracks like a bell poured too cold. Poise 2.7. Walk 2.5.

The hurl is the scaled spit. The slag patch under the landing stays the literal sheet 286 names.

Dusk. Life 22. The hurl pays 14. 22 plain bolts end it. 11 lashes of 2 end it. After 10, 2 life is left. 4 full lances of 6.5 end it. After 3, 2.5 life is left. 5 staff chains of 4.7 end it. After 4, 3.2 life is left.

Night. Life 25. The hurl pays 15.4. 25 plain bolts end it. 13 lashes of 2 end it. After 12, 1 life is left. 4 full lances of 6.5 end it. After 3, 5.5 life is left. 6 staff chains of 4.7 end it. After 5, 1.5 life is left.

Deep Night. Life 28. The hurl pays 16.8. 28 plain bolts end it. 14 lashes of 2 end it. After 13, 2 life is left. 5 full lances of 6.5 end it. After 4, 2 life is left. 6 staff chains of 4.7 end it. After 5, 4.5 life is left.

Black Night. Life 31. The hurl pays 18.2. 31 plain bolts end it. 16 lashes of 2 end it. After 15, 1 life is left. 5 full lances of 6.5 end it. After 4, 5 life is left. 7 staff chains of 4.7 end it. After 6, 2.8 life is left.

Hollow Night. Life 34. The hurl pays 19.6. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left.

Deeper Night. Life 39. The hurl pays 21. 39 plain bolts end it. 20 lashes of 2 end it. After 19, 1 life is left. 6 full lances of 6.5 end it. After 5, 6.5 life is left. 9 staff chains of 4.7 end it. After 8, 1.4 life is left.

Umbral Night. Life 44. The hurl pays 22.4. 44 plain bolts end it. 22 lashes of 2 end it. After 21, 2 life is left. 7 full lances of 6.5 end it. After 6, 5 life is left. 10 staff chains of 4.7 end it. After 9, 1.7 life is left.

### Gorse-Wife Hennet

A gaunt. The data's mesh scale is 1.3. It walks a route. The fall pays 36 grave ash, and 1 relic_fragment. The toast: Hennet falls in the heather. The wind does not stop for her. Poise 3.3. Walk 4.3.

Dusk. Life 24. The dart pays 26.4. 24 plain bolts end it. 12 lashes of 2 end it. After 11, 2 life is left. 4 full lances of 6.5 end it. After 3, 4.5 life is left. 6 staff chains of 4.7 end it. After 5, 0.5 life is left.

Night. Life 27. The dart pays 29.04. 27 plain bolts end it. 14 lashes of 2 end it. After 13, 1 life is left. 5 full lances of 6.5 end it. After 4, 1 life is left. 6 staff chains of 4.7 end it. After 5, 3.5 life is left.

Deep Night. Life 30. The dart pays 31.68. 30 plain bolts end it. 15 lashes of 2 end it. After 14, 2 life is left. 5 full lances of 6.5 end it. After 4, 4 life is left. 7 staff chains of 4.7 end it. After 6, 1.8 life is left.

Black Night. Life 34. The dart pays 34.32. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left.

Hollow Night. Life 37. The dart pays 36.96. 37 plain bolts end it. 19 lashes of 2 end it. After 18, 1 life is left. 6 full lances of 6.5 end it. After 5, 4.5 life is left. 8 staff chains of 4.7 end it. After 7, 4.1 life is left.

Deeper Night. Life 42. The dart pays 39.6. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left.

Umbral Night. Life 48. The dart pays 42.24. 48 plain bolts end it. 24 lashes of 2 end it. After 23, 2 life is left. 8 full lances of 6.5 end it. After 7, 2.5 life is left. 11 staff chains of 4.7 end it. After 10, 1 life is left.

### Old Pippin, the Ash-Grub

A burrower. The data's mesh scale is 1.4. It walks a beat of 6 m. The fall pays 36 grave ash, and 1 relic_fragment. The toast: Old Pippin curls up in the ash, and is still. Poise 4.1. Walk 3.2.

The eruption is the rake times 1.2, on the kind's disc of 1.7 after a tell of 0.75 s.

Dusk. Life 32. The rake pays 21.6. Eruption 25.92. 32 plain bolts end it. 16 lashes of 2 end it. After 15, 2 life is left. 5 full lances of 6.5 end it. After 4, 6 life is left. 7 staff chains of 4.7 end it. After 6, 3.8 life is left.

Night. Life 36. The rake pays 23.76. Eruption 28.512. 36 plain bolts end it. 18 lashes of 2 end it. After 17, 2 life is left. 6 full lances of 6.5 end it. After 5, 3.5 life is left. 8 staff chains of 4.7 end it. After 7, 3.1 life is left.

Deep Night. Life 40. The rake pays 25.92. Eruption 31.104. 40 plain bolts end it. 20 lashes of 2 end it. After 19, 2 life is left. 7 full lances of 6.5 end it. After 6, 1 life is left. 9 staff chains of 4.7 end it. After 8, 2.4 life is left.

Black Night. Life 45. The rake pays 28.08. Eruption 33.696. 45 plain bolts end it. 23 lashes of 2 end it. After 22, 1 life is left. 7 full lances of 6.5 end it. After 6, 6 life is left. 10 staff chains of 4.7 end it. After 9, 2.7 life is left.

Hollow Night. Life 50. The rake pays 30.24. Eruption 36.288. 50 plain bolts end it. 25 lashes of 2 end it. After 24, 2 life is left. 8 full lances of 6.5 end it. After 7, 4.5 life is left. 11 staff chains of 4.7 end it. After 10, 3 life is left.

Deeper Night. Life 56. The rake pays 32.4. Eruption 38.88. 56 plain bolts end it. 28 lashes of 2 end it. After 27, 2 life is left. 9 full lances of 6.5 end it. After 8, 4 life is left. 12 staff chains of 4.7 end it. After 11, 4.3 life is left.

Umbral Night. Life 64. The rake pays 34.56. Eruption 41.472. 64 plain bolts end it. 32 lashes of 2 end it. After 31, 2 life is left. 10 full lances of 6.5 end it. After 9, 5.5 life is left. 14 staff chains of 4.7 end it. After 13, 2.9 life is left.

### The Last Pilgrim

A pilgrim. The data's mesh scale is 1.3. It walks a route. The fall pays 38 grave ash, and 2 relic_fragment. The toast: The Last Pilgrim kneels, facing the mountain, and does not get up. Poise 3.1. Walk 2.7.

Dusk. Life 28. The rake pays 28.8. 28 plain bolts end it. 14 lashes of 2 end it. After 13, 2 life is left. 5 full lances of 6.5 end it. After 4, 2 life is left. 6 staff chains of 4.7 end it. After 5, 4.5 life is left.

Night. Life 32. The rake pays 31.68. 32 plain bolts end it. 16 lashes of 2 end it. After 15, 2 life is left. 5 full lances of 6.5 end it. After 4, 6 life is left. 7 staff chains of 4.7 end it. After 6, 3.8 life is left.

Deep Night. Life 35. The rake pays 34.56. 35 plain bolts end it. 18 lashes of 2 end it. After 17, 1 life is left. 6 full lances of 6.5 end it. After 5, 2.5 life is left. 8 staff chains of 4.7 end it. After 7, 2.1 life is left.

Black Night. Life 39. The rake pays 37.44. 39 plain bolts end it. 20 lashes of 2 end it. After 19, 1 life is left. 6 full lances of 6.5 end it. After 5, 6.5 life is left. 9 staff chains of 4.7 end it. After 8, 1.4 life is left.

Hollow Night. Life 43. The rake pays 40.32. 43 plain bolts end it. 22 lashes of 2 end it. After 21, 1 life is left. 7 full lances of 6.5 end it. After 6, 4 life is left. 10 staff chains of 4.7 end it. After 9, 0.7 life is left.

Deeper Night. Life 49. The rake pays 43.2. 49 plain bolts end it. 25 lashes of 2 end it. After 24, 1 life is left. 8 full lances of 6.5 end it. After 7, 3.5 life is left. 11 staff chains of 4.7 end it. After 10, 2 life is left.

Umbral Night. Life 56. The rake pays 46.08. 56 plain bolts end it. 28 lashes of 2 end it. After 27, 2 life is left. 9 full lances of 6.5 end it. After 8, 4 life is left. 12 staff chains of 4.7 end it. After 11, 4.3 life is left.

### The Ferryman Without a Boat

A husk. The look is drowned. Its variant scale is 1, so the rig is the data's scale alone. The data's mesh scale is 1.35. It walks a route. The fall pays 40 grave ash, and 2 relic_fragment. The toast: The Ferryman goes under. Nobody pays the fare tonight. Poise 5.3. Walk 2.256.

Slam is the rake times 1.15, on a disc of the kind's radius times the mesh scale. Charge is the rake times 1.2, and the hit is the kind's 1.25 m test.

Dusk. Life 37. The rake pays 38.4. Slam 44.16. Charge 46.08. 37 plain bolts end it. 19 lashes of 2 end it. After 18, 1 life is left. 6 full lances of 6.5 end it. After 5, 4.5 life is left. 8 staff chains of 4.7 end it. After 7, 4.1 life is left.

Night. Life 42. The rake pays 42.24. Slam 48.576. Charge 50.688. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left.

Deep Night. Life 46. The rake pays 46.08. Slam 52.992. Charge 55.296. 46 plain bolts end it. 23 lashes of 2 end it. After 22, 2 life is left. 8 full lances of 6.5 end it. After 7, 0.5 life is left. 10 staff chains of 4.7 end it. After 9, 3.7 life is left.

Black Night. Life 51. The rake pays 49.92. Slam 57.408. Charge 59.904. 51 plain bolts end it. 26 lashes of 2 end it. After 25, 1 life is left. 8 full lances of 6.5 end it. After 7, 5.5 life is left. 11 staff chains of 4.7 end it. After 10, 4 life is left.

Hollow Night. Life 57. The rake pays 53.76. Slam 61.824. Charge 64.512. 57 plain bolts end it. 29 lashes of 2 end it. After 28, 1 life is left. 9 full lances of 6.5 end it. After 8, 5 life is left. 13 staff chains of 4.7 end it. After 12, 0.6 life is left.

Deeper Night. Life 64. The rake pays 57.6. Slam 66.24. Charge 69.12. 64 plain bolts end it. 32 lashes of 2 end it. After 31, 2 life is left. 10 full lances of 6.5 end it. After 9, 5.5 life is left. 14 staff chains of 4.7 end it. After 13, 2.9 life is left.

Umbral Night. Life 73. The rake pays 61.44. Slam 70.656. Charge 73.728. 73 plain bolts end it. 37 lashes of 2 end it. After 36, 1 life is left. 12 full lances of 6.5 end it. After 11, 1.5 life is left. 16 staff chains of 4.7 end it. After 15, 2.5 life is left.

### Old Rook, the Kin-Taker

A gaunt. The data's mesh scale is 1.3. It walks a route. The fall pays 32 grave ash, and 1 relic_fragment. The toast: Old Rook will not come to the Holds' door again. The Rooted can sleep. Poise 3.3. Walk 4.3.

Dusk. Life 20. The dart pays 26.4. 20 plain bolts end it. 10 lashes of 2 end it. After 9, 2 life is left. 4 full lances of 6.5 end it. After 3, 0.5 life is left. 5 staff chains of 4.7 end it. After 4, 1.2 life is left.

Night. Life 23. The dart pays 29.04. 23 plain bolts end it. 12 lashes of 2 end it. After 11, 1 life is left. 4 full lances of 6.5 end it. After 3, 3.5 life is left. 5 staff chains of 4.7 end it. After 4, 4.2 life is left.

Deep Night. Life 25. The dart pays 31.68. 25 plain bolts end it. 13 lashes of 2 end it. After 12, 1 life is left. 4 full lances of 6.5 end it. After 3, 5.5 life is left. 6 staff chains of 4.7 end it. After 5, 1.5 life is left.

Black Night. Life 28. The dart pays 34.32. 28 plain bolts end it. 14 lashes of 2 end it. After 13, 2 life is left. 5 full lances of 6.5 end it. After 4, 2 life is left. 6 staff chains of 4.7 end it. After 5, 4.5 life is left.

Hollow Night. Life 31. The dart pays 36.96. 31 plain bolts end it. 16 lashes of 2 end it. After 15, 1 life is left. 5 full lances of 6.5 end it. After 4, 5 life is left. 7 staff chains of 4.7 end it. After 6, 2.8 life is left.

Deeper Night. Life 35. The dart pays 39.6. 35 plain bolts end it. 18 lashes of 2 end it. After 17, 1 life is left. 6 full lances of 6.5 end it. After 5, 2.5 life is left. 8 staff chains of 4.7 end it. After 7, 2.1 life is left.

Umbral Night. Life 40. The dart pays 42.24. 40 plain bolts end it. 20 lashes of 2 end it. After 19, 2 life is left. 7 full lances of 6.5 end it. After 6, 1 life is left. 9 staff chains of 4.7 end it. After 8, 2.4 life is left.

### The Kin-Caller

A gaunt. The data's mesh scale is 1.4. It walks a beat of 6 m. The fall pays 40 grave ash, and 2 relic_fragment, 1 kin_lamp. The toast: The Kin-Caller lets go of the rope. Poise 3.3. Walk 4.3.

Dusk. Life 30. The dart pays 26.4. 30 plain bolts end it. 15 lashes of 2 end it. After 14, 2 life is left. 5 full lances of 6.5 end it. After 4, 4 life is left. 7 staff chains of 4.7 end it. After 6, 1.8 life is left.

Night. Life 34. The dart pays 29.04. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left.

Deep Night. Life 38. The dart pays 31.68. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left.

Black Night. Life 42. The dart pays 34.32. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left.

Hollow Night. Life 47. The dart pays 36.96. 47 plain bolts end it. 24 lashes of 2 end it. After 23, 1 life is left. 8 full lances of 6.5 end it. After 7, 1.5 life is left. 10 staff chains of 4.7 end it. After 9, 4.7 life is left.

Deeper Night. Life 53. The dart pays 39.6. 53 plain bolts end it. 27 lashes of 2 end it. After 26, 1 life is left. 9 full lances of 6.5 end it. After 8, 1 life is left. 12 staff chains of 4.7 end it. After 11, 1.3 life is left.

Umbral Night. Life 60. The dart pays 42.24. 60 plain bolts end it. 30 lashes of 2 end it. After 29, 2 life is left. 10 full lances of 6.5 end it. After 9, 1.5 life is left. 13 staff chains of 4.7 end it. After 12, 3.6 life is left.

### The Bell-Hewer

A husk. The look is stone-bound. Dress multiplies the rig by 1.06 and the data's scale is applied after that, so the rig is 1.45 times 1.06. The data's mesh scale is 1.45. It walks a beat of 6 m. The fall pays 44 grave ash, and 2 relic_fragment, 1 mason_mark. The toast: The Bell-Hewer stops, mid-stroke, for the first time. Poise 6.9. Walk 2.115.

Slam is the rake times 1.15, on a disc of the kind's radius times the mesh scale. Charge is the rake times 1.2, and the hit is the kind's 1.25 m test.

Dusk. Life 46. The rake pays 38.4. Slam 44.16. Charge 46.08. 46 plain bolts end it. 23 lashes of 2 end it. After 22, 2 life is left. 8 full lances of 6.5 end it. After 7, 0.5 life is left. 10 staff chains of 4.7 end it. After 9, 3.7 life is left.

Night. Life 52. The rake pays 42.24. Slam 48.576. Charge 50.688. 52 plain bolts end it. 26 lashes of 2 end it. After 25, 2 life is left. 8 full lances of 6.5 end it. After 7, 6.5 life is left. 12 staff chains of 4.7 end it. After 11, 0.3 life is left.

Deep Night. Life 57. The rake pays 46.08. Slam 52.992. Charge 55.296. 57 plain bolts end it. 29 lashes of 2 end it. After 28, 1 life is left. 9 full lances of 6.5 end it. After 8, 5 life is left. 13 staff chains of 4.7 end it. After 12, 0.6 life is left.

Black Night. Life 64. The rake pays 49.92. Slam 57.408. Charge 59.904. 64 plain bolts end it. 32 lashes of 2 end it. After 31, 2 life is left. 10 full lances of 6.5 end it. After 9, 5.5 life is left. 14 staff chains of 4.7 end it. After 13, 2.9 life is left.

Hollow Night. Life 70. The rake pays 53.76. Slam 61.824. Charge 64.512. 70 plain bolts end it. 35 lashes of 2 end it. After 34, 2 life is left. 11 full lances of 6.5 end it. After 10, 5 life is left. 15 staff chains of 4.7 end it. After 14, 4.2 life is left.

Deeper Night. Life 79. The rake pays 57.6. Slam 66.24. Charge 69.12. 79 plain bolts end it. 40 lashes of 2 end it. After 39, 1 life is left. 13 full lances of 6.5 end it. After 12, 1 life is left. 17 staff chains of 4.7 end it. After 16, 3.8 life is left.

Umbral Night. Life 90. The rake pays 61.44. Slam 70.656. Charge 73.728. 90 plain bolts end it. 45 lashes of 2 end it. After 44, 2 life is left. 14 full lances of 6.5 end it. After 13, 5.5 life is left. 20 staff chains of 4.7 end it. After 19, 0.7 life is left.

### The Fog-Shepherd

A gaunt. The data's mesh scale is 1.4. It walks a beat of 6 m. The fall pays 40 grave ash, and 2 relic_fragment, 1 fog_crook. The toast: The Fog-Shepherd lies down in the heather. Nobody follows it now. Poise 3.3. Walk 4.3.

Dusk. Life 32. The dart pays 26.4. 32 plain bolts end it. 16 lashes of 2 end it. After 15, 2 life is left. 5 full lances of 6.5 end it. After 4, 6 life is left. 7 staff chains of 4.7 end it. After 6, 3.8 life is left.

Night. Life 36. The dart pays 29.04. 36 plain bolts end it. 18 lashes of 2 end it. After 17, 2 life is left. 6 full lances of 6.5 end it. After 5, 3.5 life is left. 8 staff chains of 4.7 end it. After 7, 3.1 life is left.

Deep Night. Life 40. The dart pays 31.68. 40 plain bolts end it. 20 lashes of 2 end it. After 19, 2 life is left. 7 full lances of 6.5 end it. After 6, 1 life is left. 9 staff chains of 4.7 end it. After 8, 2.4 life is left.

Black Night. Life 45. The dart pays 34.32. 45 plain bolts end it. 23 lashes of 2 end it. After 22, 1 life is left. 7 full lances of 6.5 end it. After 6, 6 life is left. 10 staff chains of 4.7 end it. After 9, 2.7 life is left.

Hollow Night. Life 50. The dart pays 36.96. 50 plain bolts end it. 25 lashes of 2 end it. After 24, 2 life is left. 8 full lances of 6.5 end it. After 7, 4.5 life is left. 11 staff chains of 4.7 end it. After 10, 3 life is left.

Deeper Night. Life 56. The dart pays 39.6. 56 plain bolts end it. 28 lashes of 2 end it. After 27, 2 life is left. 9 full lances of 6.5 end it. After 8, 4 life is left. 12 staff chains of 4.7 end it. After 11, 4.3 life is left.

Umbral Night. Life 64. The dart pays 42.24. 64 plain bolts end it. 32 lashes of 2 end it. After 31, 2 life is left. 10 full lances of 6.5 end it. After 9, 5.5 life is left. 14 staff chains of 4.7 end it. After 13, 2.9 life is left.

### The Slag-Born

A cinder. The data's mesh scale is 1.5. It walks a beat of 6 m. The fall pays 44 grave ash, and 2 relic_fragment, 1 slag_heart. The toast: The Slag-Born cools, and cracks, and is only slag. Poise 2.7. Walk 2.5.

The hurl is the scaled spit. The slag patch under the landing stays the literal sheet 286 names.

Dusk. Life 30. The hurl pays 14. 30 plain bolts end it. 15 lashes of 2 end it. After 14, 2 life is left. 5 full lances of 6.5 end it. After 4, 4 life is left. 7 staff chains of 4.7 end it. After 6, 1.8 life is left.

Night. Life 34. The hurl pays 15.4. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left.

Deep Night. Life 38. The hurl pays 16.8. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left.

Black Night. Life 42. The hurl pays 18.2. 42 plain bolts end it. 21 lashes of 2 end it. After 20, 2 life is left. 7 full lances of 6.5 end it. After 6, 3 life is left. 9 staff chains of 4.7 end it. After 8, 4.4 life is left.

Hollow Night. Life 47. The hurl pays 19.6. 47 plain bolts end it. 24 lashes of 2 end it. After 23, 1 life is left. 8 full lances of 6.5 end it. After 7, 1.5 life is left. 10 staff chains of 4.7 end it. After 9, 4.7 life is left.

Deeper Night. Life 53. The hurl pays 21. 53 plain bolts end it. 27 lashes of 2 end it. After 26, 1 life is left. 9 full lances of 6.5 end it. After 8, 1 life is left. 12 staff chains of 4.7 end it. After 11, 1.3 life is left.

Umbral Night. Life 60. The hurl pays 22.4. 60 plain bolts end it. 30 lashes of 2 end it. After 29, 2 life is left. 10 full lances of 6.5 end it. After 9, 1.5 life is left. 13 staff chains of 4.7 end it. After 12, 3.6 life is left.

### The Ash-Sower

A burrower. The data's mesh scale is 1.5. It walks a beat of 6 m. The fall pays 40 grave ash, and 2 relic_fragment, 1 ash_seed. The toast: The Ash-Sower goes back into the ash it came out of. Poise 4.1. Walk 3.2.

The eruption is the rake times 1.2, on the kind's disc of 1.7 after a tell of 0.75 s.

Dusk. Life 38. The rake pays 21.6. Eruption 25.92. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left.

Night. Life 43. The rake pays 23.76. Eruption 28.512. 43 plain bolts end it. 22 lashes of 2 end it. After 21, 1 life is left. 7 full lances of 6.5 end it. After 6, 4 life is left. 10 staff chains of 4.7 end it. After 9, 0.7 life is left.

Deep Night. Life 48. The rake pays 25.92. Eruption 31.104. 48 plain bolts end it. 24 lashes of 2 end it. After 23, 2 life is left. 8 full lances of 6.5 end it. After 7, 2.5 life is left. 11 staff chains of 4.7 end it. After 10, 1 life is left.

Black Night. Life 53. The rake pays 28.08. Eruption 33.696. 53 plain bolts end it. 27 lashes of 2 end it. After 26, 1 life is left. 9 full lances of 6.5 end it. After 8, 1 life is left. 12 staff chains of 4.7 end it. After 11, 1.3 life is left.

Hollow Night. Life 59. The rake pays 30.24. Eruption 36.288. 59 plain bolts end it. 30 lashes of 2 end it. After 29, 1 life is left. 10 full lances of 6.5 end it. After 9, 0.5 life is left. 13 staff chains of 4.7 end it. After 12, 2.6 life is left.

Deeper Night. Life 67. The rake pays 32.4. Eruption 38.88. 67 plain bolts end it. 34 lashes of 2 end it. After 33, 1 life is left. 11 full lances of 6.5 end it. After 10, 2 life is left. 15 staff chains of 4.7 end it. After 14, 1.2 life is left.

Umbral Night. Life 76. The rake pays 34.56. Eruption 41.472. 76 plain bolts end it. 38 lashes of 2 end it. After 37, 2 life is left. 12 full lances of 6.5 end it. After 11, 4.5 life is left. 17 staff chains of 4.7 end it. After 16, 0.8 life is left.

### The Passing-Ringer

A pilgrim. The data's mesh scale is 1.4. It walks a beat of 6 m. The fall pays 42 grave ash, and 2 relic_fragment, 1 hair_rope. The toast: The Passing-Ringer kneels. One stroke, for itself. Poise 3.1. Walk 2.7.

Dusk. Life 34. The rake pays 28.8. 34 plain bolts end it. 17 lashes of 2 end it. After 16, 2 life is left. 6 full lances of 6.5 end it. After 5, 1.5 life is left. 8 staff chains of 4.7 end it. After 7, 1.1 life is left.

Night. Life 38. The rake pays 31.68. 38 plain bolts end it. 19 lashes of 2 end it. After 18, 2 life is left. 6 full lances of 6.5 end it. After 5, 5.5 life is left. 9 staff chains of 4.7 end it. After 8, 0.4 life is left.

Deep Night. Life 43. The rake pays 34.56. 43 plain bolts end it. 22 lashes of 2 end it. After 21, 1 life is left. 7 full lances of 6.5 end it. After 6, 4 life is left. 10 staff chains of 4.7 end it. After 9, 0.7 life is left.

Black Night. Life 48. The rake pays 37.44. 48 plain bolts end it. 24 lashes of 2 end it. After 23, 2 life is left. 8 full lances of 6.5 end it. After 7, 2.5 life is left. 11 staff chains of 4.7 end it. After 10, 1 life is left.

Hollow Night. Life 53. The rake pays 40.32. 53 plain bolts end it. 27 lashes of 2 end it. After 26, 1 life is left. 9 full lances of 6.5 end it. After 8, 1 life is left. 12 staff chains of 4.7 end it. After 11, 1.3 life is left.

Deeper Night. Life 60. The rake pays 43.2. 60 plain bolts end it. 30 lashes of 2 end it. After 29, 2 life is left. 10 full lances of 6.5 end it. After 9, 1.5 life is left. 13 staff chains of 4.7 end it. After 12, 3.6 life is left.

Umbral Night. Life 68. The rake pays 46.08. 68 plain bolts end it. 34 lashes of 2 end it. After 33, 2 life is left. 11 full lances of 6.5 end it. After 10, 3 life is left. 15 staff chains of 4.7 end it. After 14, 2.2 life is left.

### The Fare-Caller

A husk. The look is drowned. Its variant scale is 1, so the rig is the data's scale alone. The data's mesh scale is 1.4. It walks a beat of 6 m. The fall pays 42 grave ash, and 2 relic_fragment, 1 ferry_coin. The toast: The Fare-Caller goes under without its fare. Poise 5.3. Walk 2.256.

Slam is the rake times 1.15, on a disc of the kind's radius times the mesh scale. Charge is the rake times 1.2, and the hit is the kind's 1.25 m test.

Dusk. Life 41. The rake pays 38.4. Slam 44.16. Charge 46.08. 41 plain bolts end it. 21 lashes of 2 end it. After 20, 1 life is left. 7 full lances of 6.5 end it. After 6, 2 life is left. 9 staff chains of 4.7 end it. After 8, 3.4 life is left.

Night. Life 46. The rake pays 42.24. Slam 48.576. Charge 50.688. 46 plain bolts end it. 23 lashes of 2 end it. After 22, 2 life is left. 8 full lances of 6.5 end it. After 7, 0.5 life is left. 10 staff chains of 4.7 end it. After 9, 3.7 life is left.

Deep Night. Life 51. The rake pays 46.08. Slam 52.992. Charge 55.296. 51 plain bolts end it. 26 lashes of 2 end it. After 25, 1 life is left. 8 full lances of 6.5 end it. After 7, 5.5 life is left. 11 staff chains of 4.7 end it. After 10, 4 life is left.

Black Night. Life 57. The rake pays 49.92. Slam 57.408. Charge 59.904. 57 plain bolts end it. 29 lashes of 2 end it. After 28, 1 life is left. 9 full lances of 6.5 end it. After 8, 5 life is left. 13 staff chains of 4.7 end it. After 12, 0.6 life is left.

Hollow Night. Life 63. The rake pays 53.76. Slam 61.824. Charge 64.512. 63 plain bolts end it. 32 lashes of 2 end it. After 31, 1 life is left. 10 full lances of 6.5 end it. After 9, 4.5 life is left. 14 staff chains of 4.7 end it. After 13, 1.9 life is left.

Deeper Night. Life 71. The rake pays 57.6. Slam 66.24. Charge 69.12. 71 plain bolts end it. 36 lashes of 2 end it. After 35, 1 life is left. 11 full lances of 6.5 end it. After 10, 6 life is left. 16 staff chains of 4.7 end it. After 15, 0.5 life is left.

Umbral Night. Life 81. The rake pays 61.44. Slam 70.656. Charge 73.728. 81 plain bolts end it. 41 lashes of 2 end it. After 40, 1 life is left. 13 full lances of 6.5 end it. After 12, 3 life is left. 18 staff chains of 4.7 end it. After 17, 1.1 life is left.

## Part XXXIX — every line the forge can print

Read from `gear_db.gd` and `gear_stats.gd` on 6 November. These lines already follow the functions. Sheet 268 owns the gleaner's wording, and the percent printed here is what that format still shows. A piece's base is (the slot's level-0 value plus the per-level value times the level) times the rarity's strength. Item level is 8 plus 7 times the rarity index plus 3 times the level. A set adds 3. A named piece adds 4. A legend adds 6. The fold adds an affix whose op is add. A mul affix multiplies its key by the greater of 0.2 and 1 plus the scaled value. Raising a piece from level L costs 4 plus 4 times (L + 1) plus 3 times the rarity index in grave ash, and (L + 1) times (1 plus the rarity index) in ember shards. Salvage returns the rarity's shard count plus the level. The shard counts are 1, 2, 4, 7, 12. Reforging one affix costs 3 times (1 plus the rarity index) shards, and a relic fragment from Hallowed upward. A Worn piece rolls no affix, so it has nothing to reforge. An Umbral piece rolls 3 affixes. A legend on it rolls 2, because the legend takes a line.

### The drop

A roll in [0, 1) walks the weights in order, and the first band whose running total the roll falls under wins. Boss: Worn 0, Kindled 0, Hallowed 0.55, Reliquary 0.35, Umbral 0.10, and the piece always drops. A Deeper Night elite: 0, 0.10, 0.35, 0.40, 0.15, and it always drops. An elite: 0, 0.45, 0.40, 0.13, 0.02, and it always drops. A tough foe: 0.45, 0.40, 0.13, 0.02, 0, with a drop chance of 0.08 before pity. Any other foe: 0.70, 0.25, 0.05, 0, 0, with a drop chance of 0.025 before pity.

### The slot's own line

#### Orb Focus

A Worn Ash-wood Orb-Cup at level 0. The base value is 0.03. The line reads "+3% spell power". Item level 8. The same piece in a set is item level 11. Raising it to level 1 costs 8 grave ash and 1 ember shard. Salvage returns 1 ember shard. Worn rolls zero affixes, and the reforge cost comes back empty.

A Worn Ash-wood Orb-Cup at level 1. The base value is 0.04. The line reads "+4% spell power". Item level 11. The same piece in a set is item level 14. Raising it to level 2 costs 12 grave ash and 2 ember shards. Salvage returns 2 ember shards. Worn rolls zero affixes, and the reforge cost comes back empty.

A Worn Ash-wood Orb-Cup at level 2. The base value is 0.05. The line reads "+5% spell power". Item level 14. The same piece in a set is item level 17. Level 2 is the cap. Salvage returns 3 ember shards. Worn rolls zero affixes, and the reforge cost comes back empty.

A Kindled Bronze Orb-Cradle at level 0. The base value is 0.0375. The line reads "+4% spell power". Item level 15. The same piece in a set is item level 18. Raising it to level 1 costs 11 grave ash and 2 ember shards. Salvage returns 2 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Bronze Orb-Cradle at level 1. The base value is 0.05. The line reads "+5% spell power". Item level 18. The same piece in a set is item level 21. Raising it to level 2 costs 15 grave ash and 4 ember shards. Salvage returns 3 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Bronze Orb-Cradle at level 2. The base value is 0.0625. The line reads "+6% spell power". Item level 21. The same piece in a set is item level 24. Raising it to level 3 costs 19 grave ash and 6 ember shards. Salvage returns 4 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Bronze Orb-Cradle at level 3. The base value is 0.075. The line reads "+8% spell power". Item level 24. The same piece in a set is item level 27. Level 3 is the cap. Salvage returns 5 ember shards. Reforging one affix costs 6 ember shards.

A Hallowed Bell-metal Collar at level 0. The base value is 0.045. The line reads "+5% spell power". Item level 22. The same piece in a set is item level 25. Raising it to level 1 costs 14 grave ash and 3 ember shards. Salvage returns 4 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Bell-metal Collar at level 1. The base value is 0.06. The line reads "+6% spell power". Item level 25. The same piece in a set is item level 28. Raising it to level 2 costs 18 grave ash and 6 ember shards. Salvage returns 5 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Bell-metal Collar at level 2. The base value is 0.075. The line reads "+8% spell power". Item level 28. The same piece in a set is item level 31. Raising it to level 3 costs 22 grave ash and 9 ember shards. Salvage returns 6 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Bell-metal Collar at level 3. The base value is 0.09. The line reads "+9% spell power". Item level 31. The same piece in a set is item level 34. Raising it to level 4 costs 26 grave ash and 12 ember shards. Salvage returns 7 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Bell-metal Collar at level 4. The base value is 0.105. The line reads "+11% spell power". Item level 34. The same piece in a set is item level 37. Level 4 is the cap. Salvage returns 8 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Reliquary Saint's-bone Collar at level 0. The base value is 0.054. The line reads "+5% spell power". Item level 29. The same piece in a set is item level 32. Raising it to level 1 costs 17 grave ash and 4 ember shards. Salvage returns 7 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Saint's-bone Collar at level 1. The base value is 0.072. The line reads "+7% spell power". Item level 32. The same piece in a set is item level 35. Raising it to level 2 costs 21 grave ash and 8 ember shards. Salvage returns 8 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Saint's-bone Collar at level 2. The base value is 0.09. The line reads "+9% spell power". Item level 35. The same piece in a set is item level 38. Raising it to level 3 costs 25 grave ash and 12 ember shards. Salvage returns 9 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Saint's-bone Collar at level 3. The base value is 0.108. The line reads "+11% spell power". Item level 38. The same piece in a set is item level 41. Raising it to level 4 costs 29 grave ash and 16 ember shards. Salvage returns 10 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Saint's-bone Collar at level 4. The base value is 0.126. The line reads "+13% spell power". Item level 41. The same piece in a set is item level 44. Raising it to level 5 costs 33 grave ash and 20 ember shards. Salvage returns 11 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Saint's-bone Collar at level 5. The base value is 0.144. The line reads "+14% spell power". Item level 44. The same piece in a set is item level 47. Level 5 is the cap. Salvage returns 12 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Umbral Starless Orb-Cage at level 0. The base value is 0.063. The line reads "+6% spell power". Item level 36. The same piece in a set is item level 39. Raising it to level 1 costs 20 grave ash and 5 ember shards. Salvage returns 12 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A legend forced onto this slot is Umbral, item level 42 at level 0, and it rolls 2 affixes.

A Umbral Starless Orb-Cage at level 1. The base value is 0.084. The line reads "+8% spell power". Item level 39. The same piece in a set is item level 42. Raising it to level 2 costs 24 grave ash and 10 ember shards. Salvage returns 13 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Starless Orb-Cage at level 2. The base value is 0.105. The line reads "+11% spell power". Item level 42. The same piece in a set is item level 45. Raising it to level 3 costs 28 grave ash and 15 ember shards. Salvage returns 14 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Starless Orb-Cage at level 3. The base value is 0.126. The line reads "+13% spell power". Item level 45. The same piece in a set is item level 48. Raising it to level 4 costs 32 grave ash and 20 ember shards. Salvage returns 15 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Starless Orb-Cage at level 4. The base value is 0.147. The line reads "+15% spell power". Item level 48. The same piece in a set is item level 51. Raising it to level 5 costs 36 grave ash and 25 ember shards. Salvage returns 16 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Starless Orb-Cage at level 5. The base value is 0.168. The line reads "+17% spell power". Item level 51. The same piece in a set is item level 54. Raising it to level 6 costs 40 grave ash and 30 ember shards. Salvage returns 17 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Starless Orb-Cage at level 6. The base value is 0.189. The line reads "+19% spell power". Item level 54. The same piece in a set is item level 57. Level 6 is the cap. Salvage returns 18 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

#### Vestment

A Worn Pilgrim's Stole at level 0. The base value is 5. The line reads "+5 Gloom held". Item level 8. The same piece in a set is item level 11. Raising it to level 1 costs 8 grave ash and 1 ember shard. Salvage returns 1 ember shard. Worn rolls zero affixes, and the reforge cost comes back empty.

A Worn Pilgrim's Stole at level 1. The base value is 7. The line reads "+7 Gloom held". Item level 11. The same piece in a set is item level 14. Raising it to level 2 costs 12 grave ash and 2 ember shards. Salvage returns 2 ember shards. Worn rolls zero affixes, and the reforge cost comes back empty.

A Worn Pilgrim's Stole at level 2. The base value is 9. The line reads "+9 Gloom held". Item level 14. The same piece in a set is item level 17. Level 2 is the cap. Salvage returns 3 ember shards. Worn rolls zero affixes, and the reforge cost comes back empty.

A Kindled Mended Scapular at level 0. The base value is 6.25. The line reads "+6 Gloom held". Item level 15. The same piece in a set is item level 18. Raising it to level 1 costs 11 grave ash and 2 ember shards. Salvage returns 2 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Mended Scapular at level 1. The base value is 8.75. The line reads "+9 Gloom held". Item level 18. The same piece in a set is item level 21. Raising it to level 2 costs 15 grave ash and 4 ember shards. Salvage returns 3 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Mended Scapular at level 2. The base value is 11.25. The line reads "+11 Gloom held". Item level 21. The same piece in a set is item level 24. Raising it to level 3 costs 19 grave ash and 6 ember shards. Salvage returns 4 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Mended Scapular at level 3. The base value is 13.75. The line reads "+14 Gloom held". Item level 24. The same piece in a set is item level 27. Level 3 is the cap. Salvage returns 5 ember shards. Reforging one affix costs 6 ember shards.

A Hallowed Choir Stole at level 0. The base value is 7.5. The line reads "+8 Gloom held". Item level 22. The same piece in a set is item level 25. Raising it to level 1 costs 14 grave ash and 3 ember shards. Salvage returns 4 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Choir Stole at level 1. The base value is 10.5. The line reads "+11 Gloom held". Item level 25. The same piece in a set is item level 28. Raising it to level 2 costs 18 grave ash and 6 ember shards. Salvage returns 5 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Choir Stole at level 2. The base value is 13.5. The line reads "+14 Gloom held". Item level 28. The same piece in a set is item level 31. Raising it to level 3 costs 22 grave ash and 9 ember shards. Salvage returns 6 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Choir Stole at level 3. The base value is 16.5. The line reads "+17 Gloom held". Item level 31. The same piece in a set is item level 34. Raising it to level 4 costs 26 grave ash and 12 ember shards. Salvage returns 7 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Choir Stole at level 4. The base value is 19.5. The line reads "+20 Gloom held". Item level 34. The same piece in a set is item level 37. Level 4 is the cap. Salvage returns 8 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Reliquary Reliquary Pall at level 0. The base value is 9. The line reads "+9 Gloom held". Item level 29. The same piece in a set is item level 32. Raising it to level 1 costs 17 grave ash and 4 ember shards. Salvage returns 7 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Reliquary Pall at level 1. The base value is 12.6. The line reads "+13 Gloom held". Item level 32. The same piece in a set is item level 35. Raising it to level 2 costs 21 grave ash and 8 ember shards. Salvage returns 8 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Reliquary Pall at level 2. The base value is 16.2. The line reads "+16 Gloom held". Item level 35. The same piece in a set is item level 38. Raising it to level 3 costs 25 grave ash and 12 ember shards. Salvage returns 9 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Reliquary Pall at level 3. The base value is 19.8. The line reads "+20 Gloom held". Item level 38. The same piece in a set is item level 41. Raising it to level 4 costs 29 grave ash and 16 ember shards. Salvage returns 10 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Reliquary Pall at level 4. The base value is 23.4. The line reads "+23 Gloom held". Item level 41. The same piece in a set is item level 44. Raising it to level 5 costs 33 grave ash and 20 ember shards. Salvage returns 11 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Reliquary Pall at level 5. The base value is 27. The line reads "+27 Gloom held". Item level 44. The same piece in a set is item level 47. Level 5 is the cap. Salvage returns 12 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Umbral Rift-hem Stole at level 0. The base value is 10.5. The line reads "+11 Gloom held". Item level 36. The same piece in a set is item level 39. Raising it to level 1 costs 20 grave ash and 5 ember shards. Salvage returns 12 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A legend forced onto this slot is Umbral, item level 42 at level 0, and it rolls 2 affixes.

A Umbral Rift-hem Stole at level 1. The base value is 14.7. The line reads "+15 Gloom held". Item level 39. The same piece in a set is item level 42. Raising it to level 2 costs 24 grave ash and 10 ember shards. Salvage returns 13 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Rift-hem Stole at level 2. The base value is 18.9. The line reads "+19 Gloom held". Item level 42. The same piece in a set is item level 45. Raising it to level 3 costs 28 grave ash and 15 ember shards. Salvage returns 14 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Rift-hem Stole at level 3. The base value is 23.1. The line reads "+23 Gloom held". Item level 45. The same piece in a set is item level 48. Raising it to level 4 costs 32 grave ash and 20 ember shards. Salvage returns 15 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Rift-hem Stole at level 4. The base value is 27.3. The line reads "+27 Gloom held". Item level 48. The same piece in a set is item level 51. Raising it to level 5 costs 36 grave ash and 25 ember shards. Salvage returns 16 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Rift-hem Stole at level 5. The base value is 31.5. The line reads "+32 Gloom held". Item level 51. The same piece in a set is item level 54. Raising it to level 6 costs 40 grave ash and 30 ember shards. Salvage returns 17 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Rift-hem Stole at level 6. The base value is 35.7. The line reads "+36 Gloom held". Item level 54. The same piece in a set is item level 57. Level 6 is the cap. Salvage returns 18 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

#### Lantern Glass

A Worn Smoked Horn-Glass at level 0. The base value is 0.5. The line reads "Lantern Ward and Umbral Well hold 0.5 s longer". Item level 8. The same piece in a set is item level 11. Raising it to level 1 costs 8 grave ash and 1 ember shard. Salvage returns 1 ember shard. Worn rolls zero affixes, and the reforge cost comes back empty.

A Worn Smoked Horn-Glass at level 1. The base value is 0.7. The line reads "Lantern Ward and Umbral Well hold 0.7 s longer". Item level 11. The same piece in a set is item level 14. Raising it to level 2 costs 12 grave ash and 2 ember shards. Salvage returns 2 ember shards. Worn rolls zero affixes, and the reforge cost comes back empty.

A Worn Smoked Horn-Glass at level 2. The base value is 0.9. The line reads "Lantern Ward and Umbral Well hold 0.9 s longer". Item level 14. The same piece in a set is item level 17. Level 2 is the cap. Salvage returns 3 ember shards. Worn rolls zero affixes, and the reforge cost comes back empty.

A Kindled Leaded Lamp-Glass at level 0. The base value is 0.625. The line reads "Lantern Ward and Umbral Well hold 0.6 s longer". Item level 15. The same piece in a set is item level 18. Raising it to level 1 costs 11 grave ash and 2 ember shards. Salvage returns 2 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Leaded Lamp-Glass at level 1. The base value is 0.875. The line reads "Lantern Ward and Umbral Well hold 0.9 s longer". Item level 18. The same piece in a set is item level 21. Raising it to level 2 costs 15 grave ash and 4 ember shards. Salvage returns 3 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Leaded Lamp-Glass at level 2. The base value is 1.125. The line reads "Lantern Ward and Umbral Well hold 1.1 s longer". Item level 21. The same piece in a set is item level 24. Raising it to level 3 costs 19 grave ash and 6 ember shards. Salvage returns 4 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Leaded Lamp-Glass at level 3. The base value is 1.375. The line reads "Lantern Ward and Umbral Well hold 1.4 s longer". Item level 24. The same piece in a set is item level 27. Level 3 is the cap. Salvage returns 5 ember shards. Reforging one affix costs 6 ember shards.

A Hallowed Chapel Lamp-Glass at level 0. The base value is 0.75. The line reads "Lantern Ward and Umbral Well hold 0.8 s longer". Item level 22. The same piece in a set is item level 25. Raising it to level 1 costs 14 grave ash and 3 ember shards. Salvage returns 4 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Chapel Lamp-Glass at level 1. The base value is 1.05. The line reads "Lantern Ward and Umbral Well hold 1.0 s longer". Item level 25. The same piece in a set is item level 28. Raising it to level 2 costs 18 grave ash and 6 ember shards. Salvage returns 5 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Chapel Lamp-Glass at level 2. The base value is 1.35. The line reads "Lantern Ward and Umbral Well hold 1.4 s longer". Item level 28. The same piece in a set is item level 31. Raising it to level 3 costs 22 grave ash and 9 ember shards. Salvage returns 6 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Chapel Lamp-Glass at level 3. The base value is 1.65. The line reads "Lantern Ward and Umbral Well hold 1.7 s longer". Item level 31. The same piece in a set is item level 34. Raising it to level 4 costs 26 grave ash and 12 ember shards. Salvage returns 7 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Chapel Lamp-Glass at level 4. The base value is 1.95. The line reads "Lantern Ward and Umbral Well hold 2.0 s longer". Item level 34. The same piece in a set is item level 37. Level 4 is the cap. Salvage returns 8 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Reliquary Vigil Glass at level 0. The base value is 0.9. The line reads "Lantern Ward and Umbral Well hold 0.9 s longer". Item level 29. The same piece in a set is item level 32. Raising it to level 1 costs 17 grave ash and 4 ember shards. Salvage returns 7 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Vigil Glass at level 1. The base value is 1.26. The line reads "Lantern Ward and Umbral Well hold 1.3 s longer". Item level 32. The same piece in a set is item level 35. Raising it to level 2 costs 21 grave ash and 8 ember shards. Salvage returns 8 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Vigil Glass at level 2. The base value is 1.62. The line reads "Lantern Ward and Umbral Well hold 1.6 s longer". Item level 35. The same piece in a set is item level 38. Raising it to level 3 costs 25 grave ash and 12 ember shards. Salvage returns 9 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Vigil Glass at level 3. The base value is 1.98. The line reads "Lantern Ward and Umbral Well hold 2.0 s longer". Item level 38. The same piece in a set is item level 41. Raising it to level 4 costs 29 grave ash and 16 ember shards. Salvage returns 10 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Vigil Glass at level 4. The base value is 2.34. The line reads "Lantern Ward and Umbral Well hold 2.3 s longer". Item level 41. The same piece in a set is item level 44. Raising it to level 5 costs 33 grave ash and 20 ember shards. Salvage returns 11 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Vigil Glass at level 5. The base value is 2.7. The line reads "Lantern Ward and Umbral Well hold 2.7 s longer". Item level 44. The same piece in a set is item level 47. Level 5 is the cap. Salvage returns 12 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Umbral Glass of the Last Lamp at level 0. The base value is 1.05. The line reads "Lantern Ward and Umbral Well hold 1.1 s longer". Item level 36. The same piece in a set is item level 39. Raising it to level 1 costs 20 grave ash and 5 ember shards. Salvage returns 12 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A legend forced onto this slot is Umbral, item level 42 at level 0, and it rolls 2 affixes.

A Umbral Glass of the Last Lamp at level 1. The base value is 1.47. The line reads "Lantern Ward and Umbral Well hold 1.5 s longer". Item level 39. The same piece in a set is item level 42. Raising it to level 2 costs 24 grave ash and 10 ember shards. Salvage returns 13 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Glass of the Last Lamp at level 2. The base value is 1.89. The line reads "Lantern Ward and Umbral Well hold 1.9 s longer". Item level 42. The same piece in a set is item level 45. Raising it to level 3 costs 28 grave ash and 15 ember shards. Salvage returns 14 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Glass of the Last Lamp at level 3. The base value is 2.31. The line reads "Lantern Ward and Umbral Well hold 2.3 s longer". Item level 45. The same piece in a set is item level 48. Raising it to level 4 costs 32 grave ash and 20 ember shards. Salvage returns 15 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Glass of the Last Lamp at level 4. The base value is 2.73. The line reads "Lantern Ward and Umbral Well hold 2.7 s longer". Item level 48. The same piece in a set is item level 51. Raising it to level 5 costs 36 grave ash and 25 ember shards. Salvage returns 16 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Glass of the Last Lamp at level 5. The base value is 3.15. The line reads "Lantern Ward and Umbral Well hold 3.2 s longer". Item level 51. The same piece in a set is item level 54. Raising it to level 6 costs 40 grave ash and 30 ember shards. Salvage returns 17 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Glass of the Last Lamp at level 6. The base value is 3.57. The line reads "Lantern Ward and Umbral Well hold 3.6 s longer". Item level 54. The same piece in a set is item level 57. Level 6 is the cap. Salvage returns 18 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

#### Girdle

A Worn Hempen Cord at level 0. The base value is -0.02. The line reads "Spells recover 2% sooner". Item level 8. The same piece in a set is item level 11. Raising it to level 1 costs 8 grave ash and 1 ember shard. Salvage returns 1 ember shard. Worn rolls zero affixes, and the reforge cost comes back empty.

A Worn Hempen Cord at level 1. The base value is -0.027. The line reads "Spells recover 3% sooner". Item level 11. The same piece in a set is item level 14. Raising it to level 2 costs 12 grave ash and 2 ember shards. Salvage returns 2 ember shards. Worn rolls zero affixes, and the reforge cost comes back empty.

A Worn Hempen Cord at level 2. The base value is -0.034. The line reads "Spells recover 3% sooner". Item level 14. The same piece in a set is item level 17. Level 2 is the cap. Salvage returns 3 ember shards. Worn rolls zero affixes, and the reforge cost comes back empty.

A Kindled Pilgrim's Belt at level 0. The base value is -0.025. The line reads "Spells recover 3% sooner". Item level 15. The same piece in a set is item level 18. Raising it to level 1 costs 11 grave ash and 2 ember shards. Salvage returns 2 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Pilgrim's Belt at level 1. The base value is -0.0338. The line reads "Spells recover 3% sooner". Item level 18. The same piece in a set is item level 21. Raising it to level 2 costs 15 grave ash and 4 ember shards. Salvage returns 3 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Pilgrim's Belt at level 2. The base value is -0.0425. The line reads "Spells recover 4% sooner". Item level 21. The same piece in a set is item level 24. Raising it to level 3 costs 19 grave ash and 6 ember shards. Salvage returns 4 ember shards. Reforging one affix costs 6 ember shards.

A Kindled Pilgrim's Belt at level 3. The base value is -0.0513. The line reads "Spells recover 5% sooner". Item level 24. The same piece in a set is item level 27. Level 3 is the cap. Salvage returns 5 ember shards. Reforging one affix costs 6 ember shards.

A Hallowed Knotted Cincture at level 0. The base value is -0.03. The line reads "Spells recover 3% sooner". Item level 22. The same piece in a set is item level 25. Raising it to level 1 costs 14 grave ash and 3 ember shards. Salvage returns 4 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Knotted Cincture at level 1. The base value is -0.0405. The line reads "Spells recover 4% sooner". Item level 25. The same piece in a set is item level 28. Raising it to level 2 costs 18 grave ash and 6 ember shards. Salvage returns 5 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Knotted Cincture at level 2. The base value is -0.051. The line reads "Spells recover 5% sooner". Item level 28. The same piece in a set is item level 31. Raising it to level 3 costs 22 grave ash and 9 ember shards. Salvage returns 6 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Knotted Cincture at level 3. The base value is -0.0615. The line reads "Spells recover 6% sooner". Item level 31. The same piece in a set is item level 34. Raising it to level 4 costs 26 grave ash and 12 ember shards. Salvage returns 7 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Hallowed Knotted Cincture at level 4. The base value is -0.072. The line reads "Spells recover 7% sooner". Item level 34. The same piece in a set is item level 37. Level 4 is the cap. Salvage returns 8 ember shards. Reforging one affix costs 9 ember shards and 1 relic fragment.

A Reliquary Penitent's Girdle at level 0. The base value is -0.036. The line reads "Spells recover 4% sooner". Item level 29. The same piece in a set is item level 32. Raising it to level 1 costs 17 grave ash and 4 ember shards. Salvage returns 7 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Penitent's Girdle at level 1. The base value is -0.0486. The line reads "Spells recover 5% sooner". Item level 32. The same piece in a set is item level 35. Raising it to level 2 costs 21 grave ash and 8 ember shards. Salvage returns 8 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Penitent's Girdle at level 2. The base value is -0.0612. The line reads "Spells recover 6% sooner". Item level 35. The same piece in a set is item level 38. Raising it to level 3 costs 25 grave ash and 12 ember shards. Salvage returns 9 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Penitent's Girdle at level 3. The base value is -0.0738. The line reads "Spells recover 7% sooner". Item level 38. The same piece in a set is item level 41. Raising it to level 4 costs 29 grave ash and 16 ember shards. Salvage returns 10 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Penitent's Girdle at level 4. The base value is -0.0864. The line reads "Spells recover 9% sooner". Item level 41. The same piece in a set is item level 44. Raising it to level 5 costs 33 grave ash and 20 ember shards. Salvage returns 11 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Reliquary Penitent's Girdle at level 5. The base value is -0.099. The line reads "Spells recover 10% sooner". Item level 44. The same piece in a set is item level 47. Level 5 is the cap. Salvage returns 12 ember shards. Reforging one affix costs 12 ember shards and 1 relic fragment.

A Umbral Girdle of Nine Knots at level 0. The base value is -0.042. The line reads "Spells recover 4% sooner". Item level 36. The same piece in a set is item level 39. Raising it to level 1 costs 20 grave ash and 5 ember shards. Salvage returns 12 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A legend forced onto this slot is Umbral, item level 42 at level 0, and it rolls 2 affixes.

A Umbral Girdle of Nine Knots at level 1. The base value is -0.0567. The line reads "Spells recover 6% sooner". Item level 39. The same piece in a set is item level 42. Raising it to level 2 costs 24 grave ash and 10 ember shards. Salvage returns 13 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Girdle of Nine Knots at level 2. The base value is -0.0714. The line reads "Spells recover 7% sooner". Item level 42. The same piece in a set is item level 45. Raising it to level 3 costs 28 grave ash and 15 ember shards. Salvage returns 14 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Girdle of Nine Knots at level 3. The base value is -0.0861. The line reads "Spells recover 9% sooner". Item level 45. The same piece in a set is item level 48. Raising it to level 4 costs 32 grave ash and 20 ember shards. Salvage returns 15 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Girdle of Nine Knots at level 4. The base value is -0.1008. The line reads "Spells recover 10% sooner". Item level 48. The same piece in a set is item level 51. Raising it to level 5 costs 36 grave ash and 25 ember shards. Salvage returns 16 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Girdle of Nine Knots at level 5. The base value is -0.1155. The line reads "Spells recover 12% sooner". Item level 51. The same piece in a set is item level 54. Raising it to level 6 costs 40 grave ash and 30 ember shards. Salvage returns 17 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

A Umbral Girdle of Nine Knots at level 6. The base value is -0.1302. The line reads "Spells recover 13% sooner". Item level 54. The same piece in a set is item level 57. Level 6 is the cap. Salvage returns 18 ember shards. Reforging one affix costs 15 ember shards and 1 relic fragment.

### Both ends of every affix, at every legal level

The stored roll is one end of the Worn band, snapped to the thousandth. What the piece gives is that roll times the rarity's strength times (1 plus 0.1 times the level). The line is that value through the affix's format. The two ends are the two ends of the band in `AFFIX`. A live piece rolls anywhere between them.

#### power

Worn, level 0, the low end. The stored roll is 0.02. Strength 1 and the level's tenth leave it at 0.02. The line reads "+2% spell power".

The fold adds 0.02 to power.

Worn, level 0, the high end. The stored roll is 0.04. Strength 1 and the level's tenth leave it at 0.04. The line reads "+4% spell power".

The fold adds 0.04 to power.

Worn, level 1, the low end. The stored roll is 0.02. Strength 1 and the level's tenth leave it at 0.022. The line reads "+2% spell power".

The fold adds 0.022 to power.

Worn, level 1, the high end. The stored roll is 0.04. Strength 1 and the level's tenth leave it at 0.044. The line reads "+4% spell power".

The fold adds 0.044 to power.

Worn, level 2, the low end. The stored roll is 0.02. Strength 1 and the level's tenth leave it at 0.024. The line reads "+2% spell power".

The fold adds 0.024 to power.

Worn, level 2, the high end. The stored roll is 0.04. Strength 1 and the level's tenth leave it at 0.048. The line reads "+5% spell power".

The fold adds 0.048 to power.

Kindled, level 0, the low end. The stored roll is 0.02. Strength 1.25 and the level's tenth leave it at 0.025. The line reads "+3% spell power".

The fold adds 0.025 to power.

Kindled, level 0, the high end. The stored roll is 0.04. Strength 1.25 and the level's tenth leave it at 0.05. The line reads "+5% spell power".

The fold adds 0.05 to power.

Kindled, level 1, the low end. The stored roll is 0.02. Strength 1.25 and the level's tenth leave it at 0.0275. The line reads "+3% spell power".

The fold adds 0.0275 to power.

Kindled, level 1, the high end. The stored roll is 0.04. Strength 1.25 and the level's tenth leave it at 0.055. The line reads "+6% spell power".

The fold adds 0.055 to power.

Kindled, level 2, the low end. The stored roll is 0.02. Strength 1.25 and the level's tenth leave it at 0.03. The line reads "+3% spell power".

The fold adds 0.03 to power.

Kindled, level 2, the high end. The stored roll is 0.04. Strength 1.25 and the level's tenth leave it at 0.06. The line reads "+6% spell power".

The fold adds 0.06 to power.

Kindled, level 3, the low end. The stored roll is 0.02. Strength 1.25 and the level's tenth leave it at 0.0325. The line reads "+3% spell power".

The fold adds 0.0325 to power.

Kindled, level 3, the high end. The stored roll is 0.04. Strength 1.25 and the level's tenth leave it at 0.065. The line reads "+7% spell power".

The fold adds 0.065 to power.

Hallowed, level 0, the low end. The stored roll is 0.02. Strength 1.5 and the level's tenth leave it at 0.03. The line reads "+3% spell power".

The fold adds 0.03 to power.

Hallowed, level 0, the high end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.06. The line reads "+6% spell power".

The fold adds 0.06 to power.

Hallowed, level 1, the low end. The stored roll is 0.02. Strength 1.5 and the level's tenth leave it at 0.033. The line reads "+3% spell power".

The fold adds 0.033 to power.

Hallowed, level 1, the high end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.066. The line reads "+7% spell power".

The fold adds 0.066 to power.

Hallowed, level 2, the low end. The stored roll is 0.02. Strength 1.5 and the level's tenth leave it at 0.036. The line reads "+4% spell power".

The fold adds 0.036 to power.

Hallowed, level 2, the high end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.072. The line reads "+7% spell power".

The fold adds 0.072 to power.

Hallowed, level 3, the low end. The stored roll is 0.02. Strength 1.5 and the level's tenth leave it at 0.039. The line reads "+4% spell power".

The fold adds 0.039 to power.

Hallowed, level 3, the high end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.078. The line reads "+8% spell power".

The fold adds 0.078 to power.

Hallowed, level 4, the low end. The stored roll is 0.02. Strength 1.5 and the level's tenth leave it at 0.042. The line reads "+4% spell power".

The fold adds 0.042 to power.

Hallowed, level 4, the high end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.084. The line reads "+8% spell power".

The fold adds 0.084 to power.

Reliquary, level 0, the low end. The stored roll is 0.02. Strength 1.8 and the level's tenth leave it at 0.036. The line reads "+4% spell power".

The fold adds 0.036 to power.

Reliquary, level 0, the high end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.072. The line reads "+7% spell power".

The fold adds 0.072 to power.

Reliquary, level 1, the low end. The stored roll is 0.02. Strength 1.8 and the level's tenth leave it at 0.0396. The line reads "+4% spell power".

The fold adds 0.0396 to power.

Reliquary, level 1, the high end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.0792. The line reads "+8% spell power".

The fold adds 0.0792 to power.

Reliquary, level 2, the low end. The stored roll is 0.02. Strength 1.8 and the level's tenth leave it at 0.0432. The line reads "+4% spell power".

The fold adds 0.0432 to power.

Reliquary, level 2, the high end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.0864. The line reads "+9% spell power".

The fold adds 0.0864 to power.

Reliquary, level 3, the low end. The stored roll is 0.02. Strength 1.8 and the level's tenth leave it at 0.0468. The line reads "+5% spell power".

The fold adds 0.0468 to power.

Reliquary, level 3, the high end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.0936. The line reads "+9% spell power".

The fold adds 0.0936 to power.

Reliquary, level 4, the low end. The stored roll is 0.02. Strength 1.8 and the level's tenth leave it at 0.0504. The line reads "+5% spell power".

The fold adds 0.0504 to power.

Reliquary, level 4, the high end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.1008. The line reads "+10% spell power".

The fold adds 0.1008 to power.

Reliquary, level 5, the low end. The stored roll is 0.02. Strength 1.8 and the level's tenth leave it at 0.054. The line reads "+5% spell power".

The fold adds 0.054 to power.

Reliquary, level 5, the high end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.108. The line reads "+11% spell power".

The fold adds 0.108 to power.

Umbral, level 0, the low end. The stored roll is 0.02. Strength 2.1 and the level's tenth leave it at 0.042. The line reads "+4% spell power".

The fold adds 0.042 to power.

Umbral, level 0, the high end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.084. The line reads "+8% spell power".

The fold adds 0.084 to power.

Umbral, level 1, the low end. The stored roll is 0.02. Strength 2.1 and the level's tenth leave it at 0.0462. The line reads "+5% spell power".

The fold adds 0.0462 to power.

Umbral, level 1, the high end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.0924. The line reads "+9% spell power".

The fold adds 0.0924 to power.

Umbral, level 2, the low end. The stored roll is 0.02. Strength 2.1 and the level's tenth leave it at 0.0504. The line reads "+5% spell power".

The fold adds 0.0504 to power.

Umbral, level 2, the high end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.1008. The line reads "+10% spell power".

The fold adds 0.1008 to power.

Umbral, level 3, the low end. The stored roll is 0.02. Strength 2.1 and the level's tenth leave it at 0.0546. The line reads "+5% spell power".

The fold adds 0.0546 to power.

Umbral, level 3, the high end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.1092. The line reads "+11% spell power".

The fold adds 0.1092 to power.

Umbral, level 4, the low end. The stored roll is 0.02. Strength 2.1 and the level's tenth leave it at 0.0588. The line reads "+6% spell power".

The fold adds 0.0588 to power.

Umbral, level 4, the high end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.1176. The line reads "+12% spell power".

The fold adds 0.1176 to power.

Umbral, level 5, the low end. The stored roll is 0.02. Strength 2.1 and the level's tenth leave it at 0.063. The line reads "+6% spell power".

The fold adds 0.063 to power.

Umbral, level 5, the high end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.126. The line reads "+13% spell power".

The fold adds 0.126 to power.

Umbral, level 6, the low end. The stored roll is 0.02. Strength 2.1 and the level's tenth leave it at 0.0672. The line reads "+7% spell power".

The fold adds 0.0672 to power.

Umbral, level 6, the high end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.1344. The line reads "+13% spell power".

The fold adds 0.1344 to power.

#### cd

Worn, level 0, the low end. The stored roll is -0.03. Strength 1 and the level's tenth leave it at -0.03. The line reads "Spells recover 3% sooner".

The fold adds -0.03 to cd.

Worn, level 0, the high end. The stored roll is -0.015. Strength 1 and the level's tenth leave it at -0.015. The line reads "Spells recover 2% sooner".

The fold adds -0.015 to cd.

Worn, level 1, the low end. The stored roll is -0.03. Strength 1 and the level's tenth leave it at -0.033. The line reads "Spells recover 3% sooner".

The fold adds -0.033 to cd.

Worn, level 1, the high end. The stored roll is -0.015. Strength 1 and the level's tenth leave it at -0.0165. The line reads "Spells recover 2% sooner".

The fold adds -0.0165 to cd.

Worn, level 2, the low end. The stored roll is -0.03. Strength 1 and the level's tenth leave it at -0.036. The line reads "Spells recover 4% sooner".

The fold adds -0.036 to cd.

Worn, level 2, the high end. The stored roll is -0.015. Strength 1 and the level's tenth leave it at -0.018. The line reads "Spells recover 2% sooner".

The fold adds -0.018 to cd.

Kindled, level 0, the low end. The stored roll is -0.03. Strength 1.25 and the level's tenth leave it at -0.0375. The line reads "Spells recover 4% sooner".

The fold adds -0.0375 to cd.

Kindled, level 0, the high end. The stored roll is -0.015. Strength 1.25 and the level's tenth leave it at -0.0187. The line reads "Spells recover 2% sooner".

The fold adds -0.0187 to cd.

Kindled, level 1, the low end. The stored roll is -0.03. Strength 1.25 and the level's tenth leave it at -0.0413. The line reads "Spells recover 4% sooner".

The fold adds -0.0413 to cd.

Kindled, level 1, the high end. The stored roll is -0.015. Strength 1.25 and the level's tenth leave it at -0.0206. The line reads "Spells recover 2% sooner".

The fold adds -0.0206 to cd.

Kindled, level 2, the low end. The stored roll is -0.03. Strength 1.25 and the level's tenth leave it at -0.045. The line reads "Spells recover 5% sooner".

The fold adds -0.045 to cd.

Kindled, level 2, the high end. The stored roll is -0.015. Strength 1.25 and the level's tenth leave it at -0.0225. The line reads "Spells recover 2% sooner".

The fold adds -0.0225 to cd.

Kindled, level 3, the low end. The stored roll is -0.03. Strength 1.25 and the level's tenth leave it at -0.0488. The line reads "Spells recover 5% sooner".

The fold adds -0.0488 to cd.

Kindled, level 3, the high end. The stored roll is -0.015. Strength 1.25 and the level's tenth leave it at -0.0244. The line reads "Spells recover 2% sooner".

The fold adds -0.0244 to cd.

Hallowed, level 0, the low end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.045. The line reads "Spells recover 5% sooner".

The fold adds -0.045 to cd.

Hallowed, level 0, the high end. The stored roll is -0.015. Strength 1.5 and the level's tenth leave it at -0.0225. The line reads "Spells recover 2% sooner".

The fold adds -0.0225 to cd.

Hallowed, level 1, the low end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.0495. The line reads "Spells recover 5% sooner".

The fold adds -0.0495 to cd.

Hallowed, level 1, the high end. The stored roll is -0.015. Strength 1.5 and the level's tenth leave it at -0.0248. The line reads "Spells recover 2% sooner".

The fold adds -0.0248 to cd.

Hallowed, level 2, the low end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.054. The line reads "Spells recover 5% sooner".

The fold adds -0.054 to cd.

Hallowed, level 2, the high end. The stored roll is -0.015. Strength 1.5 and the level's tenth leave it at -0.027. The line reads "Spells recover 3% sooner".

The fold adds -0.027 to cd.

Hallowed, level 3, the low end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.0585. The line reads "Spells recover 6% sooner".

The fold adds -0.0585 to cd.

Hallowed, level 3, the high end. The stored roll is -0.015. Strength 1.5 and the level's tenth leave it at -0.0292. The line reads "Spells recover 3% sooner".

The fold adds -0.0292 to cd.

Hallowed, level 4, the low end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.063. The line reads "Spells recover 6% sooner".

The fold adds -0.063 to cd.

Hallowed, level 4, the high end. The stored roll is -0.015. Strength 1.5 and the level's tenth leave it at -0.0315. The line reads "Spells recover 3% sooner".

The fold adds -0.0315 to cd.

Reliquary, level 0, the low end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.054. The line reads "Spells recover 5% sooner".

The fold adds -0.054 to cd.

Reliquary, level 0, the high end. The stored roll is -0.015. Strength 1.8 and the level's tenth leave it at -0.027. The line reads "Spells recover 3% sooner".

The fold adds -0.027 to cd.

Reliquary, level 1, the low end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.0594. The line reads "Spells recover 6% sooner".

The fold adds -0.0594 to cd.

Reliquary, level 1, the high end. The stored roll is -0.015. Strength 1.8 and the level's tenth leave it at -0.0297. The line reads "Spells recover 3% sooner".

The fold adds -0.0297 to cd.

Reliquary, level 2, the low end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.0648. The line reads "Spells recover 6% sooner".

The fold adds -0.0648 to cd.

Reliquary, level 2, the high end. The stored roll is -0.015. Strength 1.8 and the level's tenth leave it at -0.0324. The line reads "Spells recover 3% sooner".

The fold adds -0.0324 to cd.

Reliquary, level 3, the low end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.0702. The line reads "Spells recover 7% sooner".

The fold adds -0.0702 to cd.

Reliquary, level 3, the high end. The stored roll is -0.015. Strength 1.8 and the level's tenth leave it at -0.0351. The line reads "Spells recover 4% sooner".

The fold adds -0.0351 to cd.

Reliquary, level 4, the low end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.0756. The line reads "Spells recover 8% sooner".

The fold adds -0.0756 to cd.

Reliquary, level 4, the high end. The stored roll is -0.015. Strength 1.8 and the level's tenth leave it at -0.0378. The line reads "Spells recover 4% sooner".

The fold adds -0.0378 to cd.

Reliquary, level 5, the low end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.081. The line reads "Spells recover 8% sooner".

The fold adds -0.081 to cd.

Reliquary, level 5, the high end. The stored roll is -0.015. Strength 1.8 and the level's tenth leave it at -0.0405. The line reads "Spells recover 4% sooner".

The fold adds -0.0405 to cd.

Umbral, level 0, the low end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.063. The line reads "Spells recover 6% sooner".

The fold adds -0.063 to cd.

Umbral, level 0, the high end. The stored roll is -0.015. Strength 2.1 and the level's tenth leave it at -0.0315. The line reads "Spells recover 3% sooner".

The fold adds -0.0315 to cd.

Umbral, level 1, the low end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0693. The line reads "Spells recover 7% sooner".

The fold adds -0.0693 to cd.

Umbral, level 1, the high end. The stored roll is -0.015. Strength 2.1 and the level's tenth leave it at -0.0347. The line reads "Spells recover 3% sooner".

The fold adds -0.0347 to cd.

Umbral, level 2, the low end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0756. The line reads "Spells recover 8% sooner".

The fold adds -0.0756 to cd.

Umbral, level 2, the high end. The stored roll is -0.015. Strength 2.1 and the level's tenth leave it at -0.0378. The line reads "Spells recover 4% sooner".

The fold adds -0.0378 to cd.

Umbral, level 3, the low end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0819. The line reads "Spells recover 8% sooner".

The fold adds -0.0819 to cd.

Umbral, level 3, the high end. The stored roll is -0.015. Strength 2.1 and the level's tenth leave it at -0.041. The line reads "Spells recover 4% sooner".

The fold adds -0.041 to cd.

Umbral, level 4, the low end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0882. The line reads "Spells recover 9% sooner".

The fold adds -0.0882 to cd.

Umbral, level 4, the high end. The stored roll is -0.015. Strength 2.1 and the level's tenth leave it at -0.0441. The line reads "Spells recover 4% sooner".

The fold adds -0.0441 to cd.

Umbral, level 5, the low end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0945. The line reads "Spells recover 9% sooner".

The fold adds -0.0945 to cd.

Umbral, level 5, the high end. The stored roll is -0.015. Strength 2.1 and the level's tenth leave it at -0.0473. The line reads "Spells recover 5% sooner".

The fold adds -0.0473 to cd.

Umbral, level 6, the low end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.1008. The line reads "Spells recover 10% sooner".

The fold adds -0.1008 to cd.

Umbral, level 6, the high end. The stored roll is -0.015. Strength 2.1 and the level's tenth leave it at -0.0504. The line reads "Spells recover 5% sooner".

The fold adds -0.0504 to cd.

#### gloom_add

Worn, level 0, the low end. The stored roll is 4. Strength 1 and the level's tenth leave it at 4. The line reads "+4 Gloom held".

The fold adds 4 to gloom_add.

Worn, level 0, the high end. The stored roll is 8. Strength 1 and the level's tenth leave it at 8. The line reads "+8 Gloom held".

The fold adds 8 to gloom_add.

Worn, level 1, the low end. The stored roll is 4. Strength 1 and the level's tenth leave it at 4.4. The line reads "+4 Gloom held".

The fold adds 4.4 to gloom_add.

Worn, level 1, the high end. The stored roll is 8. Strength 1 and the level's tenth leave it at 8.8. The line reads "+9 Gloom held".

The fold adds 8.8 to gloom_add.

Worn, level 2, the low end. The stored roll is 4. Strength 1 and the level's tenth leave it at 4.8. The line reads "+5 Gloom held".

The fold adds 4.8 to gloom_add.

Worn, level 2, the high end. The stored roll is 8. Strength 1 and the level's tenth leave it at 9.6. The line reads "+10 Gloom held".

The fold adds 9.6 to gloom_add.

Kindled, level 0, the low end. The stored roll is 4. Strength 1.25 and the level's tenth leave it at 5. The line reads "+5 Gloom held".

The fold adds 5 to gloom_add.

Kindled, level 0, the high end. The stored roll is 8. Strength 1.25 and the level's tenth leave it at 10. The line reads "+10 Gloom held".

The fold adds 10 to gloom_add.

Kindled, level 1, the low end. The stored roll is 4. Strength 1.25 and the level's tenth leave it at 5.5. The line reads "+6 Gloom held".

The fold adds 5.5 to gloom_add.

Kindled, level 1, the high end. The stored roll is 8. Strength 1.25 and the level's tenth leave it at 11. The line reads "+11 Gloom held".

The fold adds 11 to gloom_add.

Kindled, level 2, the low end. The stored roll is 4. Strength 1.25 and the level's tenth leave it at 6. The line reads "+6 Gloom held".

The fold adds 6 to gloom_add.

Kindled, level 2, the high end. The stored roll is 8. Strength 1.25 and the level's tenth leave it at 12. The line reads "+12 Gloom held".

The fold adds 12 to gloom_add.

Kindled, level 3, the low end. The stored roll is 4. Strength 1.25 and the level's tenth leave it at 6.5. The line reads "+7 Gloom held".

The fold adds 6.5 to gloom_add.

Kindled, level 3, the high end. The stored roll is 8. Strength 1.25 and the level's tenth leave it at 13. The line reads "+13 Gloom held".

The fold adds 13 to gloom_add.

Hallowed, level 0, the low end. The stored roll is 4. Strength 1.5 and the level's tenth leave it at 6. The line reads "+6 Gloom held".

The fold adds 6 to gloom_add.

Hallowed, level 0, the high end. The stored roll is 8. Strength 1.5 and the level's tenth leave it at 12. The line reads "+12 Gloom held".

The fold adds 12 to gloom_add.

Hallowed, level 1, the low end. The stored roll is 4. Strength 1.5 and the level's tenth leave it at 6.6. The line reads "+7 Gloom held".

The fold adds 6.6 to gloom_add.

Hallowed, level 1, the high end. The stored roll is 8. Strength 1.5 and the level's tenth leave it at 13.2. The line reads "+13 Gloom held".

The fold adds 13.2 to gloom_add.

Hallowed, level 2, the low end. The stored roll is 4. Strength 1.5 and the level's tenth leave it at 7.2. The line reads "+7 Gloom held".

The fold adds 7.2 to gloom_add.

Hallowed, level 2, the high end. The stored roll is 8. Strength 1.5 and the level's tenth leave it at 14.4. The line reads "+14 Gloom held".

The fold adds 14.4 to gloom_add.

Hallowed, level 3, the low end. The stored roll is 4. Strength 1.5 and the level's tenth leave it at 7.8. The line reads "+8 Gloom held".

The fold adds 7.8 to gloom_add.

Hallowed, level 3, the high end. The stored roll is 8. Strength 1.5 and the level's tenth leave it at 15.6. The line reads "+16 Gloom held".

The fold adds 15.6 to gloom_add.

Hallowed, level 4, the low end. The stored roll is 4. Strength 1.5 and the level's tenth leave it at 8.4. The line reads "+8 Gloom held".

The fold adds 8.4 to gloom_add.

Hallowed, level 4, the high end. The stored roll is 8. Strength 1.5 and the level's tenth leave it at 16.8. The line reads "+17 Gloom held".

The fold adds 16.8 to gloom_add.

Reliquary, level 0, the low end. The stored roll is 4. Strength 1.8 and the level's tenth leave it at 7.2. The line reads "+7 Gloom held".

The fold adds 7.2 to gloom_add.

Reliquary, level 0, the high end. The stored roll is 8. Strength 1.8 and the level's tenth leave it at 14.4. The line reads "+14 Gloom held".

The fold adds 14.4 to gloom_add.

Reliquary, level 1, the low end. The stored roll is 4. Strength 1.8 and the level's tenth leave it at 7.92. The line reads "+8 Gloom held".

The fold adds 7.92 to gloom_add.

Reliquary, level 1, the high end. The stored roll is 8. Strength 1.8 and the level's tenth leave it at 15.84. The line reads "+16 Gloom held".

The fold adds 15.84 to gloom_add.

Reliquary, level 2, the low end. The stored roll is 4. Strength 1.8 and the level's tenth leave it at 8.64. The line reads "+9 Gloom held".

The fold adds 8.64 to gloom_add.

Reliquary, level 2, the high end. The stored roll is 8. Strength 1.8 and the level's tenth leave it at 17.28. The line reads "+17 Gloom held".

The fold adds 17.28 to gloom_add.

Reliquary, level 3, the low end. The stored roll is 4. Strength 1.8 and the level's tenth leave it at 9.36. The line reads "+9 Gloom held".

The fold adds 9.36 to gloom_add.

Reliquary, level 3, the high end. The stored roll is 8. Strength 1.8 and the level's tenth leave it at 18.72. The line reads "+19 Gloom held".

The fold adds 18.72 to gloom_add.

Reliquary, level 4, the low end. The stored roll is 4. Strength 1.8 and the level's tenth leave it at 10.08. The line reads "+10 Gloom held".

The fold adds 10.08 to gloom_add.

Reliquary, level 4, the high end. The stored roll is 8. Strength 1.8 and the level's tenth leave it at 20.16. The line reads "+20 Gloom held".

The fold adds 20.16 to gloom_add.

Reliquary, level 5, the low end. The stored roll is 4. Strength 1.8 and the level's tenth leave it at 10.8. The line reads "+11 Gloom held".

The fold adds 10.8 to gloom_add.

Reliquary, level 5, the high end. The stored roll is 8. Strength 1.8 and the level's tenth leave it at 21.6. The line reads "+22 Gloom held".

The fold adds 21.6 to gloom_add.

Umbral, level 0, the low end. The stored roll is 4. Strength 2.1 and the level's tenth leave it at 8.4. The line reads "+8 Gloom held".

The fold adds 8.4 to gloom_add.

Umbral, level 0, the high end. The stored roll is 8. Strength 2.1 and the level's tenth leave it at 16.8. The line reads "+17 Gloom held".

The fold adds 16.8 to gloom_add.

Umbral, level 1, the low end. The stored roll is 4. Strength 2.1 and the level's tenth leave it at 9.24. The line reads "+9 Gloom held".

The fold adds 9.24 to gloom_add.

Umbral, level 1, the high end. The stored roll is 8. Strength 2.1 and the level's tenth leave it at 18.48. The line reads "+18 Gloom held".

The fold adds 18.48 to gloom_add.

Umbral, level 2, the low end. The stored roll is 4. Strength 2.1 and the level's tenth leave it at 10.08. The line reads "+10 Gloom held".

The fold adds 10.08 to gloom_add.

Umbral, level 2, the high end. The stored roll is 8. Strength 2.1 and the level's tenth leave it at 20.16. The line reads "+20 Gloom held".

The fold adds 20.16 to gloom_add.

Umbral, level 3, the low end. The stored roll is 4. Strength 2.1 and the level's tenth leave it at 10.92. The line reads "+11 Gloom held".

The fold adds 10.92 to gloom_add.

Umbral, level 3, the high end. The stored roll is 8. Strength 2.1 and the level's tenth leave it at 21.84. The line reads "+22 Gloom held".

The fold adds 21.84 to gloom_add.

Umbral, level 4, the low end. The stored roll is 4. Strength 2.1 and the level's tenth leave it at 11.76. The line reads "+12 Gloom held".

The fold adds 11.76 to gloom_add.

Umbral, level 4, the high end. The stored roll is 8. Strength 2.1 and the level's tenth leave it at 23.52. The line reads "+24 Gloom held".

The fold adds 23.52 to gloom_add.

Umbral, level 5, the low end. The stored roll is 4. Strength 2.1 and the level's tenth leave it at 12.6. The line reads "+13 Gloom held".

The fold adds 12.6 to gloom_add.

Umbral, level 5, the high end. The stored roll is 8. Strength 2.1 and the level's tenth leave it at 25.2. The line reads "+25 Gloom held".

The fold adds 25.2 to gloom_add.

Umbral, level 6, the low end. The stored roll is 4. Strength 2.1 and the level's tenth leave it at 13.44. The line reads "+13 Gloom held".

The fold adds 13.44 to gloom_add.

Umbral, level 6, the high end. The stored roll is 8. Strength 2.1 and the level's tenth leave it at 26.88. The line reads "+27 Gloom held".

The fold adds 26.88 to gloom_add.

#### dark_mult

Worn, level 0, the low end. The stored roll is -0.05. Strength 1 and the level's tenth leave it at -0.05. The line reads "Gloom gathers 5% slower".

The fold multiplies dark_mult by 0.95, the greater of 0.2 and 1 plus -0.05.

Worn, level 0, the high end. The stored roll is -0.025. Strength 1 and the level's tenth leave it at -0.025. The line reads "Gloom gathers 3% slower".

The fold multiplies dark_mult by 0.975, the greater of 0.2 and 1 plus -0.025.

Worn, level 1, the low end. The stored roll is -0.05. Strength 1 and the level's tenth leave it at -0.055. The line reads "Gloom gathers 6% slower".

The fold multiplies dark_mult by 0.945, the greater of 0.2 and 1 plus -0.055.

Worn, level 1, the high end. The stored roll is -0.025. Strength 1 and the level's tenth leave it at -0.0275. The line reads "Gloom gathers 3% slower".

The fold multiplies dark_mult by 0.9725, the greater of 0.2 and 1 plus -0.0275.

Worn, level 2, the low end. The stored roll is -0.05. Strength 1 and the level's tenth leave it at -0.06. The line reads "Gloom gathers 6% slower".

The fold multiplies dark_mult by 0.94, the greater of 0.2 and 1 plus -0.06.

Worn, level 2, the high end. The stored roll is -0.025. Strength 1 and the level's tenth leave it at -0.03. The line reads "Gloom gathers 3% slower".

The fold multiplies dark_mult by 0.97, the greater of 0.2 and 1 plus -0.03.

Kindled, level 0, the low end. The stored roll is -0.05. Strength 1.25 and the level's tenth leave it at -0.0625. The line reads "Gloom gathers 6% slower".

The fold multiplies dark_mult by 0.9375, the greater of 0.2 and 1 plus -0.0625.

Kindled, level 0, the high end. The stored roll is -0.025. Strength 1.25 and the level's tenth leave it at -0.0312. The line reads "Gloom gathers 3% slower".

The fold multiplies dark_mult by 0.9688, the greater of 0.2 and 1 plus -0.0312.

Kindled, level 1, the low end. The stored roll is -0.05. Strength 1.25 and the level's tenth leave it at -0.0688. The line reads "Gloom gathers 7% slower".

The fold multiplies dark_mult by 0.9313, the greater of 0.2 and 1 plus -0.0688.

Kindled, level 1, the high end. The stored roll is -0.025. Strength 1.25 and the level's tenth leave it at -0.0344. The line reads "Gloom gathers 3% slower".

The fold multiplies dark_mult by 0.9656, the greater of 0.2 and 1 plus -0.0344.

Kindled, level 2, the low end. The stored roll is -0.05. Strength 1.25 and the level's tenth leave it at -0.075. The line reads "Gloom gathers 8% slower".

The fold multiplies dark_mult by 0.925, the greater of 0.2 and 1 plus -0.075.

Kindled, level 2, the high end. The stored roll is -0.025. Strength 1.25 and the level's tenth leave it at -0.0375. The line reads "Gloom gathers 4% slower".

The fold multiplies dark_mult by 0.9625, the greater of 0.2 and 1 plus -0.0375.

Kindled, level 3, the low end. The stored roll is -0.05. Strength 1.25 and the level's tenth leave it at -0.0813. The line reads "Gloom gathers 8% slower".

The fold multiplies dark_mult by 0.9187, the greater of 0.2 and 1 plus -0.0813.

Kindled, level 3, the high end. The stored roll is -0.025. Strength 1.25 and the level's tenth leave it at -0.0406. The line reads "Gloom gathers 4% slower".

The fold multiplies dark_mult by 0.9594, the greater of 0.2 and 1 plus -0.0406.

Hallowed, level 0, the low end. The stored roll is -0.05. Strength 1.5 and the level's tenth leave it at -0.075. The line reads "Gloom gathers 8% slower".

The fold multiplies dark_mult by 0.925, the greater of 0.2 and 1 plus -0.075.

Hallowed, level 0, the high end. The stored roll is -0.025. Strength 1.5 and the level's tenth leave it at -0.0375. The line reads "Gloom gathers 4% slower".

The fold multiplies dark_mult by 0.9625, the greater of 0.2 and 1 plus -0.0375.

Hallowed, level 1, the low end. The stored roll is -0.05. Strength 1.5 and the level's tenth leave it at -0.0825. The line reads "Gloom gathers 8% slower".

The fold multiplies dark_mult by 0.9175, the greater of 0.2 and 1 plus -0.0825.

Hallowed, level 1, the high end. The stored roll is -0.025. Strength 1.5 and the level's tenth leave it at -0.0413. The line reads "Gloom gathers 4% slower".

The fold multiplies dark_mult by 0.9587, the greater of 0.2 and 1 plus -0.0413.

Hallowed, level 2, the low end. The stored roll is -0.05. Strength 1.5 and the level's tenth leave it at -0.09. The line reads "Gloom gathers 9% slower".

The fold multiplies dark_mult by 0.91, the greater of 0.2 and 1 plus -0.09.

Hallowed, level 2, the high end. The stored roll is -0.025. Strength 1.5 and the level's tenth leave it at -0.045. The line reads "Gloom gathers 5% slower".

The fold multiplies dark_mult by 0.955, the greater of 0.2 and 1 plus -0.045.

Hallowed, level 3, the low end. The stored roll is -0.05. Strength 1.5 and the level's tenth leave it at -0.0975. The line reads "Gloom gathers 10% slower".

The fold multiplies dark_mult by 0.9025, the greater of 0.2 and 1 plus -0.0975.

Hallowed, level 3, the high end. The stored roll is -0.025. Strength 1.5 and the level's tenth leave it at -0.0488. The line reads "Gloom gathers 5% slower".

The fold multiplies dark_mult by 0.9513, the greater of 0.2 and 1 plus -0.0488.

Hallowed, level 4, the low end. The stored roll is -0.05. Strength 1.5 and the level's tenth leave it at -0.105. The line reads "Gloom gathers 11% slower".

The fold multiplies dark_mult by 0.895, the greater of 0.2 and 1 plus -0.105.

Hallowed, level 4, the high end. The stored roll is -0.025. Strength 1.5 and the level's tenth leave it at -0.0525. The line reads "Gloom gathers 5% slower".

The fold multiplies dark_mult by 0.9475, the greater of 0.2 and 1 plus -0.0525.

Reliquary, level 0, the low end. The stored roll is -0.05. Strength 1.8 and the level's tenth leave it at -0.09. The line reads "Gloom gathers 9% slower".

The fold multiplies dark_mult by 0.91, the greater of 0.2 and 1 plus -0.09.

Reliquary, level 0, the high end. The stored roll is -0.025. Strength 1.8 and the level's tenth leave it at -0.045. The line reads "Gloom gathers 5% slower".

The fold multiplies dark_mult by 0.955, the greater of 0.2 and 1 plus -0.045.

Reliquary, level 1, the low end. The stored roll is -0.05. Strength 1.8 and the level's tenth leave it at -0.099. The line reads "Gloom gathers 10% slower".

The fold multiplies dark_mult by 0.901, the greater of 0.2 and 1 plus -0.099.

Reliquary, level 1, the high end. The stored roll is -0.025. Strength 1.8 and the level's tenth leave it at -0.0495. The line reads "Gloom gathers 5% slower".

The fold multiplies dark_mult by 0.9505, the greater of 0.2 and 1 plus -0.0495.

Reliquary, level 2, the low end. The stored roll is -0.05. Strength 1.8 and the level's tenth leave it at -0.108. The line reads "Gloom gathers 11% slower".

The fold multiplies dark_mult by 0.892, the greater of 0.2 and 1 plus -0.108.

Reliquary, level 2, the high end. The stored roll is -0.025. Strength 1.8 and the level's tenth leave it at -0.054. The line reads "Gloom gathers 5% slower".

The fold multiplies dark_mult by 0.946, the greater of 0.2 and 1 plus -0.054.

Reliquary, level 3, the low end. The stored roll is -0.05. Strength 1.8 and the level's tenth leave it at -0.117. The line reads "Gloom gathers 12% slower".

The fold multiplies dark_mult by 0.883, the greater of 0.2 and 1 plus -0.117.

Reliquary, level 3, the high end. The stored roll is -0.025. Strength 1.8 and the level's tenth leave it at -0.0585. The line reads "Gloom gathers 6% slower".

The fold multiplies dark_mult by 0.9415, the greater of 0.2 and 1 plus -0.0585.

Reliquary, level 4, the low end. The stored roll is -0.05. Strength 1.8 and the level's tenth leave it at -0.126. The line reads "Gloom gathers 13% slower".

The fold multiplies dark_mult by 0.874, the greater of 0.2 and 1 plus -0.126.

Reliquary, level 4, the high end. The stored roll is -0.025. Strength 1.8 and the level's tenth leave it at -0.063. The line reads "Gloom gathers 6% slower".

The fold multiplies dark_mult by 0.937, the greater of 0.2 and 1 plus -0.063.

Reliquary, level 5, the low end. The stored roll is -0.05. Strength 1.8 and the level's tenth leave it at -0.135. The line reads "Gloom gathers 14% slower".

The fold multiplies dark_mult by 0.865, the greater of 0.2 and 1 plus -0.135.

Reliquary, level 5, the high end. The stored roll is -0.025. Strength 1.8 and the level's tenth leave it at -0.0675. The line reads "Gloom gathers 7% slower".

The fold multiplies dark_mult by 0.9325, the greater of 0.2 and 1 plus -0.0675.

Umbral, level 0, the low end. The stored roll is -0.05. Strength 2.1 and the level's tenth leave it at -0.105. The line reads "Gloom gathers 11% slower".

The fold multiplies dark_mult by 0.895, the greater of 0.2 and 1 plus -0.105.

Umbral, level 0, the high end. The stored roll is -0.025. Strength 2.1 and the level's tenth leave it at -0.0525. The line reads "Gloom gathers 5% slower".

The fold multiplies dark_mult by 0.9475, the greater of 0.2 and 1 plus -0.0525.

Umbral, level 1, the low end. The stored roll is -0.05. Strength 2.1 and the level's tenth leave it at -0.1155. The line reads "Gloom gathers 12% slower".

The fold multiplies dark_mult by 0.8845, the greater of 0.2 and 1 plus -0.1155.

Umbral, level 1, the high end. The stored roll is -0.025. Strength 2.1 and the level's tenth leave it at -0.0578. The line reads "Gloom gathers 6% slower".

The fold multiplies dark_mult by 0.9423, the greater of 0.2 and 1 plus -0.0578.

Umbral, level 2, the low end. The stored roll is -0.05. Strength 2.1 and the level's tenth leave it at -0.126. The line reads "Gloom gathers 13% slower".

The fold multiplies dark_mult by 0.874, the greater of 0.2 and 1 plus -0.126.

Umbral, level 2, the high end. The stored roll is -0.025. Strength 2.1 and the level's tenth leave it at -0.063. The line reads "Gloom gathers 6% slower".

The fold multiplies dark_mult by 0.937, the greater of 0.2 and 1 plus -0.063.

Umbral, level 3, the low end. The stored roll is -0.05. Strength 2.1 and the level's tenth leave it at -0.1365. The line reads "Gloom gathers 14% slower".

The fold multiplies dark_mult by 0.8635, the greater of 0.2 and 1 plus -0.1365.

Umbral, level 3, the high end. The stored roll is -0.025. Strength 2.1 and the level's tenth leave it at -0.0683. The line reads "Gloom gathers 7% slower".

The fold multiplies dark_mult by 0.9317, the greater of 0.2 and 1 plus -0.0683.

Umbral, level 4, the low end. The stored roll is -0.05. Strength 2.1 and the level's tenth leave it at -0.147. The line reads "Gloom gathers 15% slower".

The fold multiplies dark_mult by 0.853, the greater of 0.2 and 1 plus -0.147.

Umbral, level 4, the high end. The stored roll is -0.025. Strength 2.1 and the level's tenth leave it at -0.0735. The line reads "Gloom gathers 7% slower".

The fold multiplies dark_mult by 0.9265, the greater of 0.2 and 1 plus -0.0735.

Umbral, level 5, the low end. The stored roll is -0.05. Strength 2.1 and the level's tenth leave it at -0.1575. The line reads "Gloom gathers 16% slower".

The fold multiplies dark_mult by 0.8425, the greater of 0.2 and 1 plus -0.1575.

Umbral, level 5, the high end. The stored roll is -0.025. Strength 2.1 and the level's tenth leave it at -0.0788. The line reads "Gloom gathers 8% slower".

The fold multiplies dark_mult by 0.9213, the greater of 0.2 and 1 plus -0.0788.

Umbral, level 6, the low end. The stored roll is -0.05. Strength 2.1 and the level's tenth leave it at -0.168. The line reads "Gloom gathers 17% slower".

The fold multiplies dark_mult by 0.832, the greater of 0.2 and 1 plus -0.168.

Umbral, level 6, the high end. The stored roll is -0.025. Strength 2.1 and the level's tenth leave it at -0.084. The line reads "Gloom gathers 8% slower".

The fold multiplies dark_mult by 0.916, the greater of 0.2 and 1 plus -0.084.

#### lit_mult

Worn, level 0, the low end. The stored roll is 0.06. Strength 1 and the level's tenth leave it at 0.06. The line reads "Fire takes Gloom off 6% faster".

The fold multiplies lit_mult by 1.06, the greater of 0.2 and 1 plus 0.06.

Worn, level 0, the high end. The stored roll is 0.12. Strength 1 and the level's tenth leave it at 0.12. The line reads "Fire takes Gloom off 12% faster".

The fold multiplies lit_mult by 1.12, the greater of 0.2 and 1 plus 0.12.

Worn, level 1, the low end. The stored roll is 0.06. Strength 1 and the level's tenth leave it at 0.066. The line reads "Fire takes Gloom off 7% faster".

The fold multiplies lit_mult by 1.066, the greater of 0.2 and 1 plus 0.066.

Worn, level 1, the high end. The stored roll is 0.12. Strength 1 and the level's tenth leave it at 0.132. The line reads "Fire takes Gloom off 13% faster".

The fold multiplies lit_mult by 1.132, the greater of 0.2 and 1 plus 0.132.

Worn, level 2, the low end. The stored roll is 0.06. Strength 1 and the level's tenth leave it at 0.072. The line reads "Fire takes Gloom off 7% faster".

The fold multiplies lit_mult by 1.072, the greater of 0.2 and 1 plus 0.072.

Worn, level 2, the high end. The stored roll is 0.12. Strength 1 and the level's tenth leave it at 0.144. The line reads "Fire takes Gloom off 14% faster".

The fold multiplies lit_mult by 1.144, the greater of 0.2 and 1 plus 0.144.

Kindled, level 0, the low end. The stored roll is 0.06. Strength 1.25 and the level's tenth leave it at 0.075. The line reads "Fire takes Gloom off 8% faster".

The fold multiplies lit_mult by 1.075, the greater of 0.2 and 1 plus 0.075.

Kindled, level 0, the high end. The stored roll is 0.12. Strength 1.25 and the level's tenth leave it at 0.15. The line reads "Fire takes Gloom off 15% faster".

The fold multiplies lit_mult by 1.15, the greater of 0.2 and 1 plus 0.15.

Kindled, level 1, the low end. The stored roll is 0.06. Strength 1.25 and the level's tenth leave it at 0.0825. The line reads "Fire takes Gloom off 8% faster".

The fold multiplies lit_mult by 1.0825, the greater of 0.2 and 1 plus 0.0825.

Kindled, level 1, the high end. The stored roll is 0.12. Strength 1.25 and the level's tenth leave it at 0.165. The line reads "Fire takes Gloom off 17% faster".

The fold multiplies lit_mult by 1.165, the greater of 0.2 and 1 plus 0.165.

Kindled, level 2, the low end. The stored roll is 0.06. Strength 1.25 and the level's tenth leave it at 0.09. The line reads "Fire takes Gloom off 9% faster".

The fold multiplies lit_mult by 1.09, the greater of 0.2 and 1 plus 0.09.

Kindled, level 2, the high end. The stored roll is 0.12. Strength 1.25 and the level's tenth leave it at 0.18. The line reads "Fire takes Gloom off 18% faster".

The fold multiplies lit_mult by 1.18, the greater of 0.2 and 1 plus 0.18.

Kindled, level 3, the low end. The stored roll is 0.06. Strength 1.25 and the level's tenth leave it at 0.0975. The line reads "Fire takes Gloom off 10% faster".

The fold multiplies lit_mult by 1.0975, the greater of 0.2 and 1 plus 0.0975.

Kindled, level 3, the high end. The stored roll is 0.12. Strength 1.25 and the level's tenth leave it at 0.195. The line reads "Fire takes Gloom off 20% faster".

The fold multiplies lit_mult by 1.195, the greater of 0.2 and 1 plus 0.195.

Hallowed, level 0, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.09. The line reads "Fire takes Gloom off 9% faster".

The fold multiplies lit_mult by 1.09, the greater of 0.2 and 1 plus 0.09.

Hallowed, level 0, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.18. The line reads "Fire takes Gloom off 18% faster".

The fold multiplies lit_mult by 1.18, the greater of 0.2 and 1 plus 0.18.

Hallowed, level 1, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.099. The line reads "Fire takes Gloom off 10% faster".

The fold multiplies lit_mult by 1.099, the greater of 0.2 and 1 plus 0.099.

Hallowed, level 1, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.198. The line reads "Fire takes Gloom off 20% faster".

The fold multiplies lit_mult by 1.198, the greater of 0.2 and 1 plus 0.198.

Hallowed, level 2, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.108. The line reads "Fire takes Gloom off 11% faster".

The fold multiplies lit_mult by 1.108, the greater of 0.2 and 1 plus 0.108.

Hallowed, level 2, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.216. The line reads "Fire takes Gloom off 22% faster".

The fold multiplies lit_mult by 1.216, the greater of 0.2 and 1 plus 0.216.

Hallowed, level 3, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.117. The line reads "Fire takes Gloom off 12% faster".

The fold multiplies lit_mult by 1.117, the greater of 0.2 and 1 plus 0.117.

Hallowed, level 3, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.234. The line reads "Fire takes Gloom off 23% faster".

The fold multiplies lit_mult by 1.234, the greater of 0.2 and 1 plus 0.234.

Hallowed, level 4, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.126. The line reads "Fire takes Gloom off 13% faster".

The fold multiplies lit_mult by 1.126, the greater of 0.2 and 1 plus 0.126.

Hallowed, level 4, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.252. The line reads "Fire takes Gloom off 25% faster".

The fold multiplies lit_mult by 1.252, the greater of 0.2 and 1 plus 0.252.

Reliquary, level 0, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.108. The line reads "Fire takes Gloom off 11% faster".

The fold multiplies lit_mult by 1.108, the greater of 0.2 and 1 plus 0.108.

Reliquary, level 0, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.216. The line reads "Fire takes Gloom off 22% faster".

The fold multiplies lit_mult by 1.216, the greater of 0.2 and 1 plus 0.216.

Reliquary, level 1, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.1188. The line reads "Fire takes Gloom off 12% faster".

The fold multiplies lit_mult by 1.1188, the greater of 0.2 and 1 plus 0.1188.

Reliquary, level 1, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.2376. The line reads "Fire takes Gloom off 24% faster".

The fold multiplies lit_mult by 1.2376, the greater of 0.2 and 1 plus 0.2376.

Reliquary, level 2, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.1296. The line reads "Fire takes Gloom off 13% faster".

The fold multiplies lit_mult by 1.1296, the greater of 0.2 and 1 plus 0.1296.

Reliquary, level 2, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.2592. The line reads "Fire takes Gloom off 26% faster".

The fold multiplies lit_mult by 1.2592, the greater of 0.2 and 1 plus 0.2592.

Reliquary, level 3, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.1404. The line reads "Fire takes Gloom off 14% faster".

The fold multiplies lit_mult by 1.1404, the greater of 0.2 and 1 plus 0.1404.

Reliquary, level 3, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.2808. The line reads "Fire takes Gloom off 28% faster".

The fold multiplies lit_mult by 1.2808, the greater of 0.2 and 1 plus 0.2808.

Reliquary, level 4, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.1512. The line reads "Fire takes Gloom off 15% faster".

The fold multiplies lit_mult by 1.1512, the greater of 0.2 and 1 plus 0.1512.

Reliquary, level 4, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.3024. The line reads "Fire takes Gloom off 30% faster".

The fold multiplies lit_mult by 1.3024, the greater of 0.2 and 1 plus 0.3024.

Reliquary, level 5, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.162. The line reads "Fire takes Gloom off 16% faster".

The fold multiplies lit_mult by 1.162, the greater of 0.2 and 1 plus 0.162.

Reliquary, level 5, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.324. The line reads "Fire takes Gloom off 32% faster".

The fold multiplies lit_mult by 1.324, the greater of 0.2 and 1 plus 0.324.

Umbral, level 0, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.126. The line reads "Fire takes Gloom off 13% faster".

The fold multiplies lit_mult by 1.126, the greater of 0.2 and 1 plus 0.126.

Umbral, level 0, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.252. The line reads "Fire takes Gloom off 25% faster".

The fold multiplies lit_mult by 1.252, the greater of 0.2 and 1 plus 0.252.

Umbral, level 1, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.1386. The line reads "Fire takes Gloom off 14% faster".

The fold multiplies lit_mult by 1.1386, the greater of 0.2 and 1 plus 0.1386.

Umbral, level 1, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.2772. The line reads "Fire takes Gloom off 28% faster".

The fold multiplies lit_mult by 1.2772, the greater of 0.2 and 1 plus 0.2772.

Umbral, level 2, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.1512. The line reads "Fire takes Gloom off 15% faster".

The fold multiplies lit_mult by 1.1512, the greater of 0.2 and 1 plus 0.1512.

Umbral, level 2, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.3024. The line reads "Fire takes Gloom off 30% faster".

The fold multiplies lit_mult by 1.3024, the greater of 0.2 and 1 plus 0.3024.

Umbral, level 3, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.1638. The line reads "Fire takes Gloom off 16% faster".

The fold multiplies lit_mult by 1.1638, the greater of 0.2 and 1 plus 0.1638.

Umbral, level 3, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.3276. The line reads "Fire takes Gloom off 33% faster".

The fold multiplies lit_mult by 1.3276, the greater of 0.2 and 1 plus 0.3276.

Umbral, level 4, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.1764. The line reads "Fire takes Gloom off 18% faster".

The fold multiplies lit_mult by 1.1764, the greater of 0.2 and 1 plus 0.1764.

Umbral, level 4, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.3528. The line reads "Fire takes Gloom off 35% faster".

The fold multiplies lit_mult by 1.3528, the greater of 0.2 and 1 plus 0.3528.

Umbral, level 5, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.189. The line reads "Fire takes Gloom off 19% faster".

The fold multiplies lit_mult by 1.189, the greater of 0.2 and 1 plus 0.189.

Umbral, level 5, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.378. The line reads "Fire takes Gloom off 38% faster".

The fold multiplies lit_mult by 1.378, the greater of 0.2 and 1 plus 0.378.

Umbral, level 6, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.2016. The line reads "Fire takes Gloom off 20% faster".

The fold multiplies lit_mult by 1.2016, the greater of 0.2 and 1 plus 0.2016.

Umbral, level 6, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.4032. The line reads "Fire takes Gloom off 40% faster".

The fold multiplies lit_mult by 1.4032, the greater of 0.2 and 1 plus 0.4032.

#### kill_relief

Worn, level 0, the low end. The stored roll is 0.5. Strength 1 and the level's tenth leave it at 0.5. The line reads "Every kill mends 0.5 Wounds".

The fold adds 0.5 to kill_relief.

Worn, level 0, the high end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1. The line reads "Every kill mends 1.0 Wounds".

The fold adds 1 to kill_relief.

Worn, level 1, the low end. The stored roll is 0.5. Strength 1 and the level's tenth leave it at 0.55. The line reads "Every kill mends 0.6 Wounds".

The fold adds 0.55 to kill_relief.

Worn, level 1, the high end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1.1. The line reads "Every kill mends 1.1 Wounds".

The fold adds 1.1 to kill_relief.

Worn, level 2, the low end. The stored roll is 0.5. Strength 1 and the level's tenth leave it at 0.6. The line reads "Every kill mends 0.6 Wounds".

The fold adds 0.6 to kill_relief.

Worn, level 2, the high end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1.2. The line reads "Every kill mends 1.2 Wounds".

The fold adds 1.2 to kill_relief.

Kindled, level 0, the low end. The stored roll is 0.5. Strength 1.25 and the level's tenth leave it at 0.625. The line reads "Every kill mends 0.6 Wounds".

The fold adds 0.625 to kill_relief.

Kindled, level 0, the high end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.25. The line reads "Every kill mends 1.2 Wounds".

The fold adds 1.25 to kill_relief.

Kindled, level 1, the low end. The stored roll is 0.5. Strength 1.25 and the level's tenth leave it at 0.6875. The line reads "Every kill mends 0.7 Wounds".

The fold adds 0.6875 to kill_relief.

Kindled, level 1, the high end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.375. The line reads "Every kill mends 1.4 Wounds".

The fold adds 1.375 to kill_relief.

Kindled, level 2, the low end. The stored roll is 0.5. Strength 1.25 and the level's tenth leave it at 0.75. The line reads "Every kill mends 0.8 Wounds".

The fold adds 0.75 to kill_relief.

Kindled, level 2, the high end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.5. The line reads "Every kill mends 1.5 Wounds".

The fold adds 1.5 to kill_relief.

Kindled, level 3, the low end. The stored roll is 0.5. Strength 1.25 and the level's tenth leave it at 0.8125. The line reads "Every kill mends 0.8 Wounds".

The fold adds 0.8125 to kill_relief.

Kindled, level 3, the high end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.625. The line reads "Every kill mends 1.6 Wounds".

The fold adds 1.625 to kill_relief.

Hallowed, level 0, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 0.75. The line reads "Every kill mends 0.8 Wounds".

The fold adds 0.75 to kill_relief.

Hallowed, level 0, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.5. The line reads "Every kill mends 1.5 Wounds".

The fold adds 1.5 to kill_relief.

Hallowed, level 1, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 0.825. The line reads "Every kill mends 0.8 Wounds".

The fold adds 0.825 to kill_relief.

Hallowed, level 1, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.65. The line reads "Every kill mends 1.7 Wounds".

The fold adds 1.65 to kill_relief.

Hallowed, level 2, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 0.9. The line reads "Every kill mends 0.9 Wounds".

The fold adds 0.9 to kill_relief.

Hallowed, level 2, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.8. The line reads "Every kill mends 1.8 Wounds".

The fold adds 1.8 to kill_relief.

Hallowed, level 3, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 0.975. The line reads "Every kill mends 1.0 Wounds".

The fold adds 0.975 to kill_relief.

Hallowed, level 3, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.95. The line reads "Every kill mends 2.0 Wounds".

The fold adds 1.95 to kill_relief.

Hallowed, level 4, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 1.05. The line reads "Every kill mends 1.0 Wounds".

The fold adds 1.05 to kill_relief.

Hallowed, level 4, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 2.1. The line reads "Every kill mends 2.1 Wounds".

The fold adds 2.1 to kill_relief.

Reliquary, level 0, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 0.9. The line reads "Every kill mends 0.9 Wounds".

The fold adds 0.9 to kill_relief.

Reliquary, level 0, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 1.8. The line reads "Every kill mends 1.8 Wounds".

The fold adds 1.8 to kill_relief.

Reliquary, level 1, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 0.99. The line reads "Every kill mends 1.0 Wounds".

The fold adds 0.99 to kill_relief.

Reliquary, level 1, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 1.98. The line reads "Every kill mends 2.0 Wounds".

The fold adds 1.98 to kill_relief.

Reliquary, level 2, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 1.08. The line reads "Every kill mends 1.1 Wounds".

The fold adds 1.08 to kill_relief.

Reliquary, level 2, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.16. The line reads "Every kill mends 2.2 Wounds".

The fold adds 2.16 to kill_relief.

Reliquary, level 3, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 1.17. The line reads "Every kill mends 1.2 Wounds".

The fold adds 1.17 to kill_relief.

Reliquary, level 3, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.34. The line reads "Every kill mends 2.3 Wounds".

The fold adds 2.34 to kill_relief.

Reliquary, level 4, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 1.26. The line reads "Every kill mends 1.3 Wounds".

The fold adds 1.26 to kill_relief.

Reliquary, level 4, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.52. The line reads "Every kill mends 2.5 Wounds".

The fold adds 2.52 to kill_relief.

Reliquary, level 5, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 1.35. The line reads "Every kill mends 1.4 Wounds".

The fold adds 1.35 to kill_relief.

Reliquary, level 5, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.7. The line reads "Every kill mends 2.7 Wounds".

The fold adds 2.7 to kill_relief.

Umbral, level 0, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.05. The line reads "Every kill mends 1.1 Wounds".

The fold adds 1.05 to kill_relief.

Umbral, level 0, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.1. The line reads "Every kill mends 2.1 Wounds".

The fold adds 2.1 to kill_relief.

Umbral, level 1, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.155. The line reads "Every kill mends 1.2 Wounds".

The fold adds 1.155 to kill_relief.

Umbral, level 1, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.31. The line reads "Every kill mends 2.3 Wounds".

The fold adds 2.31 to kill_relief.

Umbral, level 2, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.26. The line reads "Every kill mends 1.3 Wounds".

The fold adds 1.26 to kill_relief.

Umbral, level 2, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.52. The line reads "Every kill mends 2.5 Wounds".

The fold adds 2.52 to kill_relief.

Umbral, level 3, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.365. The line reads "Every kill mends 1.4 Wounds".

The fold adds 1.365 to kill_relief.

Umbral, level 3, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.73. The line reads "Every kill mends 2.7 Wounds".

The fold adds 2.73 to kill_relief.

Umbral, level 4, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.47. The line reads "Every kill mends 1.5 Wounds".

The fold adds 1.47 to kill_relief.

Umbral, level 4, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.94. The line reads "Every kill mends 2.9 Wounds".

The fold adds 2.94 to kill_relief.

Umbral, level 5, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.575. The line reads "Every kill mends 1.6 Wounds".

The fold adds 1.575 to kill_relief.

Umbral, level 5, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 3.15. The line reads "Every kill mends 3.2 Wounds".

The fold adds 3.15 to kill_relief.

Umbral, level 6, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.68. The line reads "Every kill mends 1.7 Wounds".

The fold adds 1.68 to kill_relief.

Umbral, level 6, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 3.36. The line reads "Every kill mends 3.4 Wounds".

The fold adds 3.36 to kill_relief.

#### step_range

Worn, level 0, the low end. The stored roll is 0.3. Strength 1 and the level's tenth leave it at 0.3. The line reads "Rift Step reaches 0.3 m further".

The fold adds 0.3 to step_range.

Worn, level 0, the high end. The stored roll is 0.6. Strength 1 and the level's tenth leave it at 0.6. The line reads "Rift Step reaches 0.6 m further".

The fold adds 0.6 to step_range.

Worn, level 1, the low end. The stored roll is 0.3. Strength 1 and the level's tenth leave it at 0.33. The line reads "Rift Step reaches 0.3 m further".

The fold adds 0.33 to step_range.

Worn, level 1, the high end. The stored roll is 0.6. Strength 1 and the level's tenth leave it at 0.66. The line reads "Rift Step reaches 0.7 m further".

The fold adds 0.66 to step_range.

Worn, level 2, the low end. The stored roll is 0.3. Strength 1 and the level's tenth leave it at 0.36. The line reads "Rift Step reaches 0.4 m further".

The fold adds 0.36 to step_range.

Worn, level 2, the high end. The stored roll is 0.6. Strength 1 and the level's tenth leave it at 0.72. The line reads "Rift Step reaches 0.7 m further".

The fold adds 0.72 to step_range.

Kindled, level 0, the low end. The stored roll is 0.3. Strength 1.25 and the level's tenth leave it at 0.375. The line reads "Rift Step reaches 0.4 m further".

The fold adds 0.375 to step_range.

Kindled, level 0, the high end. The stored roll is 0.6. Strength 1.25 and the level's tenth leave it at 0.75. The line reads "Rift Step reaches 0.8 m further".

The fold adds 0.75 to step_range.

Kindled, level 1, the low end. The stored roll is 0.3. Strength 1.25 and the level's tenth leave it at 0.4125. The line reads "Rift Step reaches 0.4 m further".

The fold adds 0.4125 to step_range.

Kindled, level 1, the high end. The stored roll is 0.6. Strength 1.25 and the level's tenth leave it at 0.825. The line reads "Rift Step reaches 0.8 m further".

The fold adds 0.825 to step_range.

Kindled, level 2, the low end. The stored roll is 0.3. Strength 1.25 and the level's tenth leave it at 0.45. The line reads "Rift Step reaches 0.4 m further".

The fold adds 0.45 to step_range.

Kindled, level 2, the high end. The stored roll is 0.6. Strength 1.25 and the level's tenth leave it at 0.9. The line reads "Rift Step reaches 0.9 m further".

The fold adds 0.9 to step_range.

Kindled, level 3, the low end. The stored roll is 0.3. Strength 1.25 and the level's tenth leave it at 0.4875. The line reads "Rift Step reaches 0.5 m further".

The fold adds 0.4875 to step_range.

Kindled, level 3, the high end. The stored roll is 0.6. Strength 1.25 and the level's tenth leave it at 0.975. The line reads "Rift Step reaches 1.0 m further".

The fold adds 0.975 to step_range.

Hallowed, level 0, the low end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.45. The line reads "Rift Step reaches 0.4 m further".

The fold adds 0.45 to step_range.

Hallowed, level 0, the high end. The stored roll is 0.6. Strength 1.5 and the level's tenth leave it at 0.9. The line reads "Rift Step reaches 0.9 m further".

The fold adds 0.9 to step_range.

Hallowed, level 1, the low end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.495. The line reads "Rift Step reaches 0.5 m further".

The fold adds 0.495 to step_range.

Hallowed, level 1, the high end. The stored roll is 0.6. Strength 1.5 and the level's tenth leave it at 0.99. The line reads "Rift Step reaches 1.0 m further".

The fold adds 0.99 to step_range.

Hallowed, level 2, the low end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.54. The line reads "Rift Step reaches 0.5 m further".

The fold adds 0.54 to step_range.

Hallowed, level 2, the high end. The stored roll is 0.6. Strength 1.5 and the level's tenth leave it at 1.08. The line reads "Rift Step reaches 1.1 m further".

The fold adds 1.08 to step_range.

Hallowed, level 3, the low end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.585. The line reads "Rift Step reaches 0.6 m further".

The fold adds 0.585 to step_range.

Hallowed, level 3, the high end. The stored roll is 0.6. Strength 1.5 and the level's tenth leave it at 1.17. The line reads "Rift Step reaches 1.2 m further".

The fold adds 1.17 to step_range.

Hallowed, level 4, the low end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.63. The line reads "Rift Step reaches 0.6 m further".

The fold adds 0.63 to step_range.

Hallowed, level 4, the high end. The stored roll is 0.6. Strength 1.5 and the level's tenth leave it at 1.26. The line reads "Rift Step reaches 1.3 m further".

The fold adds 1.26 to step_range.

Reliquary, level 0, the low end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.54. The line reads "Rift Step reaches 0.5 m further".

The fold adds 0.54 to step_range.

Reliquary, level 0, the high end. The stored roll is 0.6. Strength 1.8 and the level's tenth leave it at 1.08. The line reads "Rift Step reaches 1.1 m further".

The fold adds 1.08 to step_range.

Reliquary, level 1, the low end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.594. The line reads "Rift Step reaches 0.6 m further".

The fold adds 0.594 to step_range.

Reliquary, level 1, the high end. The stored roll is 0.6. Strength 1.8 and the level's tenth leave it at 1.188. The line reads "Rift Step reaches 1.2 m further".

The fold adds 1.188 to step_range.

Reliquary, level 2, the low end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.648. The line reads "Rift Step reaches 0.6 m further".

The fold adds 0.648 to step_range.

Reliquary, level 2, the high end. The stored roll is 0.6. Strength 1.8 and the level's tenth leave it at 1.296. The line reads "Rift Step reaches 1.3 m further".

The fold adds 1.296 to step_range.

Reliquary, level 3, the low end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.702. The line reads "Rift Step reaches 0.7 m further".

The fold adds 0.702 to step_range.

Reliquary, level 3, the high end. The stored roll is 0.6. Strength 1.8 and the level's tenth leave it at 1.404. The line reads "Rift Step reaches 1.4 m further".

The fold adds 1.404 to step_range.

Reliquary, level 4, the low end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.756. The line reads "Rift Step reaches 0.8 m further".

The fold adds 0.756 to step_range.

Reliquary, level 4, the high end. The stored roll is 0.6. Strength 1.8 and the level's tenth leave it at 1.512. The line reads "Rift Step reaches 1.5 m further".

The fold adds 1.512 to step_range.

Reliquary, level 5, the low end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.81. The line reads "Rift Step reaches 0.8 m further".

The fold adds 0.81 to step_range.

Reliquary, level 5, the high end. The stored roll is 0.6. Strength 1.8 and the level's tenth leave it at 1.62. The line reads "Rift Step reaches 1.6 m further".

The fold adds 1.62 to step_range.

Umbral, level 0, the low end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.63. The line reads "Rift Step reaches 0.6 m further".

The fold adds 0.63 to step_range.

Umbral, level 0, the high end. The stored roll is 0.6. Strength 2.1 and the level's tenth leave it at 1.26. The line reads "Rift Step reaches 1.3 m further".

The fold adds 1.26 to step_range.

Umbral, level 1, the low end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.693. The line reads "Rift Step reaches 0.7 m further".

The fold adds 0.693 to step_range.

Umbral, level 1, the high end. The stored roll is 0.6. Strength 2.1 and the level's tenth leave it at 1.386. The line reads "Rift Step reaches 1.4 m further".

The fold adds 1.386 to step_range.

Umbral, level 2, the low end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.756. The line reads "Rift Step reaches 0.8 m further".

The fold adds 0.756 to step_range.

Umbral, level 2, the high end. The stored roll is 0.6. Strength 2.1 and the level's tenth leave it at 1.512. The line reads "Rift Step reaches 1.5 m further".

The fold adds 1.512 to step_range.

Umbral, level 3, the low end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.819. The line reads "Rift Step reaches 0.8 m further".

The fold adds 0.819 to step_range.

Umbral, level 3, the high end. The stored roll is 0.6. Strength 2.1 and the level's tenth leave it at 1.638. The line reads "Rift Step reaches 1.6 m further".

The fold adds 1.638 to step_range.

Umbral, level 4, the low end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.882. The line reads "Rift Step reaches 0.9 m further".

The fold adds 0.882 to step_range.

Umbral, level 4, the high end. The stored roll is 0.6. Strength 2.1 and the level's tenth leave it at 1.764. The line reads "Rift Step reaches 1.8 m further".

The fold adds 1.764 to step_range.

Umbral, level 5, the low end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.945. The line reads "Rift Step reaches 0.9 m further".

The fold adds 0.945 to step_range.

Umbral, level 5, the high end. The stored roll is 0.6. Strength 2.1 and the level's tenth leave it at 1.89. The line reads "Rift Step reaches 1.9 m further".

The fold adds 1.89 to step_range.

Umbral, level 6, the low end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 1.008. The line reads "Rift Step reaches 1.0 m further".

The fold adds 1.008 to step_range.

Umbral, level 6, the high end. The stored roll is 0.6. Strength 2.1 and the level's tenth leave it at 2.016. The line reads "Rift Step reaches 2.0 m further".

The fold adds 2.016 to step_range.

#### step_cd

Worn, level 0, the low end. The stored roll is -0.07. Strength 1 and the level's tenth leave it at -0.07. The line reads "Rift Step recovers 7% sooner".

The fold multiplies step_cd by 0.93, the greater of 0.2 and 1 plus -0.07.

Worn, level 0, the high end. The stored roll is -0.035. Strength 1 and the level's tenth leave it at -0.035. The line reads "Rift Step recovers 4% sooner".

The fold multiplies step_cd by 0.965, the greater of 0.2 and 1 plus -0.035.

Worn, level 1, the low end. The stored roll is -0.07. Strength 1 and the level's tenth leave it at -0.077. The line reads "Rift Step recovers 8% sooner".

The fold multiplies step_cd by 0.923, the greater of 0.2 and 1 plus -0.077.

Worn, level 1, the high end. The stored roll is -0.035. Strength 1 and the level's tenth leave it at -0.0385. The line reads "Rift Step recovers 4% sooner".

The fold multiplies step_cd by 0.9615, the greater of 0.2 and 1 plus -0.0385.

Worn, level 2, the low end. The stored roll is -0.07. Strength 1 and the level's tenth leave it at -0.084. The line reads "Rift Step recovers 8% sooner".

The fold multiplies step_cd by 0.916, the greater of 0.2 and 1 plus -0.084.

Worn, level 2, the high end. The stored roll is -0.035. Strength 1 and the level's tenth leave it at -0.042. The line reads "Rift Step recovers 4% sooner".

The fold multiplies step_cd by 0.958, the greater of 0.2 and 1 plus -0.042.

Kindled, level 0, the low end. The stored roll is -0.07. Strength 1.25 and the level's tenth leave it at -0.0875. The line reads "Rift Step recovers 9% sooner".

The fold multiplies step_cd by 0.9125, the greater of 0.2 and 1 plus -0.0875.

Kindled, level 0, the high end. The stored roll is -0.035. Strength 1.25 and the level's tenth leave it at -0.0438. The line reads "Rift Step recovers 4% sooner".

The fold multiplies step_cd by 0.9563, the greater of 0.2 and 1 plus -0.0438.

Kindled, level 1, the low end. The stored roll is -0.07. Strength 1.25 and the level's tenth leave it at -0.0963. The line reads "Rift Step recovers 10% sooner".

The fold multiplies step_cd by 0.9037, the greater of 0.2 and 1 plus -0.0963.

Kindled, level 1, the high end. The stored roll is -0.035. Strength 1.25 and the level's tenth leave it at -0.0481. The line reads "Rift Step recovers 5% sooner".

The fold multiplies step_cd by 0.9519, the greater of 0.2 and 1 plus -0.0481.

Kindled, level 2, the low end. The stored roll is -0.07. Strength 1.25 and the level's tenth leave it at -0.105. The line reads "Rift Step recovers 11% sooner".

The fold multiplies step_cd by 0.895, the greater of 0.2 and 1 plus -0.105.

Kindled, level 2, the high end. The stored roll is -0.035. Strength 1.25 and the level's tenth leave it at -0.0525. The line reads "Rift Step recovers 5% sooner".

The fold multiplies step_cd by 0.9475, the greater of 0.2 and 1 plus -0.0525.

Kindled, level 3, the low end. The stored roll is -0.07. Strength 1.25 and the level's tenth leave it at -0.1138. The line reads "Rift Step recovers 11% sooner".

The fold multiplies step_cd by 0.8862, the greater of 0.2 and 1 plus -0.1138.

Kindled, level 3, the high end. The stored roll is -0.035. Strength 1.25 and the level's tenth leave it at -0.0569. The line reads "Rift Step recovers 6% sooner".

The fold multiplies step_cd by 0.9431, the greater of 0.2 and 1 plus -0.0569.

Hallowed, level 0, the low end. The stored roll is -0.07. Strength 1.5 and the level's tenth leave it at -0.105. The line reads "Rift Step recovers 11% sooner".

The fold multiplies step_cd by 0.895, the greater of 0.2 and 1 plus -0.105.

Hallowed, level 0, the high end. The stored roll is -0.035. Strength 1.5 and the level's tenth leave it at -0.0525. The line reads "Rift Step recovers 5% sooner".

The fold multiplies step_cd by 0.9475, the greater of 0.2 and 1 plus -0.0525.

Hallowed, level 1, the low end. The stored roll is -0.07. Strength 1.5 and the level's tenth leave it at -0.1155. The line reads "Rift Step recovers 12% sooner".

The fold multiplies step_cd by 0.8845, the greater of 0.2 and 1 plus -0.1155.

Hallowed, level 1, the high end. The stored roll is -0.035. Strength 1.5 and the level's tenth leave it at -0.0578. The line reads "Rift Step recovers 6% sooner".

The fold multiplies step_cd by 0.9423, the greater of 0.2 and 1 plus -0.0578.

Hallowed, level 2, the low end. The stored roll is -0.07. Strength 1.5 and the level's tenth leave it at -0.126. The line reads "Rift Step recovers 13% sooner".

The fold multiplies step_cd by 0.874, the greater of 0.2 and 1 plus -0.126.

Hallowed, level 2, the high end. The stored roll is -0.035. Strength 1.5 and the level's tenth leave it at -0.063. The line reads "Rift Step recovers 6% sooner".

The fold multiplies step_cd by 0.937, the greater of 0.2 and 1 plus -0.063.

Hallowed, level 3, the low end. The stored roll is -0.07. Strength 1.5 and the level's tenth leave it at -0.1365. The line reads "Rift Step recovers 14% sooner".

The fold multiplies step_cd by 0.8635, the greater of 0.2 and 1 plus -0.1365.

Hallowed, level 3, the high end. The stored roll is -0.035. Strength 1.5 and the level's tenth leave it at -0.0683. The line reads "Rift Step recovers 7% sooner".

The fold multiplies step_cd by 0.9317, the greater of 0.2 and 1 plus -0.0683.

Hallowed, level 4, the low end. The stored roll is -0.07. Strength 1.5 and the level's tenth leave it at -0.147. The line reads "Rift Step recovers 15% sooner".

The fold multiplies step_cd by 0.853, the greater of 0.2 and 1 plus -0.147.

Hallowed, level 4, the high end. The stored roll is -0.035. Strength 1.5 and the level's tenth leave it at -0.0735. The line reads "Rift Step recovers 7% sooner".

The fold multiplies step_cd by 0.9265, the greater of 0.2 and 1 plus -0.0735.

Reliquary, level 0, the low end. The stored roll is -0.07. Strength 1.8 and the level's tenth leave it at -0.126. The line reads "Rift Step recovers 13% sooner".

The fold multiplies step_cd by 0.874, the greater of 0.2 and 1 plus -0.126.

Reliquary, level 0, the high end. The stored roll is -0.035. Strength 1.8 and the level's tenth leave it at -0.063. The line reads "Rift Step recovers 6% sooner".

The fold multiplies step_cd by 0.937, the greater of 0.2 and 1 plus -0.063.

Reliquary, level 1, the low end. The stored roll is -0.07. Strength 1.8 and the level's tenth leave it at -0.1386. The line reads "Rift Step recovers 14% sooner".

The fold multiplies step_cd by 0.8614, the greater of 0.2 and 1 plus -0.1386.

Reliquary, level 1, the high end. The stored roll is -0.035. Strength 1.8 and the level's tenth leave it at -0.0693. The line reads "Rift Step recovers 7% sooner".

The fold multiplies step_cd by 0.9307, the greater of 0.2 and 1 plus -0.0693.

Reliquary, level 2, the low end. The stored roll is -0.07. Strength 1.8 and the level's tenth leave it at -0.1512. The line reads "Rift Step recovers 15% sooner".

The fold multiplies step_cd by 0.8488, the greater of 0.2 and 1 plus -0.1512.

Reliquary, level 2, the high end. The stored roll is -0.035. Strength 1.8 and the level's tenth leave it at -0.0756. The line reads "Rift Step recovers 8% sooner".

The fold multiplies step_cd by 0.9244, the greater of 0.2 and 1 plus -0.0756.

Reliquary, level 3, the low end. The stored roll is -0.07. Strength 1.8 and the level's tenth leave it at -0.1638. The line reads "Rift Step recovers 16% sooner".

The fold multiplies step_cd by 0.8362, the greater of 0.2 and 1 plus -0.1638.

Reliquary, level 3, the high end. The stored roll is -0.035. Strength 1.8 and the level's tenth leave it at -0.0819. The line reads "Rift Step recovers 8% sooner".

The fold multiplies step_cd by 0.9181, the greater of 0.2 and 1 plus -0.0819.

Reliquary, level 4, the low end. The stored roll is -0.07. Strength 1.8 and the level's tenth leave it at -0.1764. The line reads "Rift Step recovers 18% sooner".

The fold multiplies step_cd by 0.8236, the greater of 0.2 and 1 plus -0.1764.

Reliquary, level 4, the high end. The stored roll is -0.035. Strength 1.8 and the level's tenth leave it at -0.0882. The line reads "Rift Step recovers 9% sooner".

The fold multiplies step_cd by 0.9118, the greater of 0.2 and 1 plus -0.0882.

Reliquary, level 5, the low end. The stored roll is -0.07. Strength 1.8 and the level's tenth leave it at -0.189. The line reads "Rift Step recovers 19% sooner".

The fold multiplies step_cd by 0.811, the greater of 0.2 and 1 plus -0.189.

Reliquary, level 5, the high end. The stored roll is -0.035. Strength 1.8 and the level's tenth leave it at -0.0945. The line reads "Rift Step recovers 9% sooner".

The fold multiplies step_cd by 0.9055, the greater of 0.2 and 1 plus -0.0945.

Umbral, level 0, the low end. The stored roll is -0.07. Strength 2.1 and the level's tenth leave it at -0.147. The line reads "Rift Step recovers 15% sooner".

The fold multiplies step_cd by 0.853, the greater of 0.2 and 1 plus -0.147.

Umbral, level 0, the high end. The stored roll is -0.035. Strength 2.1 and the level's tenth leave it at -0.0735. The line reads "Rift Step recovers 7% sooner".

The fold multiplies step_cd by 0.9265, the greater of 0.2 and 1 plus -0.0735.

Umbral, level 1, the low end. The stored roll is -0.07. Strength 2.1 and the level's tenth leave it at -0.1617. The line reads "Rift Step recovers 16% sooner".

The fold multiplies step_cd by 0.8383, the greater of 0.2 and 1 plus -0.1617.

Umbral, level 1, the high end. The stored roll is -0.035. Strength 2.1 and the level's tenth leave it at -0.0809. The line reads "Rift Step recovers 8% sooner".

The fold multiplies step_cd by 0.9192, the greater of 0.2 and 1 plus -0.0809.

Umbral, level 2, the low end. The stored roll is -0.07. Strength 2.1 and the level's tenth leave it at -0.1764. The line reads "Rift Step recovers 18% sooner".

The fold multiplies step_cd by 0.8236, the greater of 0.2 and 1 plus -0.1764.

Umbral, level 2, the high end. The stored roll is -0.035. Strength 2.1 and the level's tenth leave it at -0.0882. The line reads "Rift Step recovers 9% sooner".

The fold multiplies step_cd by 0.9118, the greater of 0.2 and 1 plus -0.0882.

Umbral, level 3, the low end. The stored roll is -0.07. Strength 2.1 and the level's tenth leave it at -0.1911. The line reads "Rift Step recovers 19% sooner".

The fold multiplies step_cd by 0.8089, the greater of 0.2 and 1 plus -0.1911.

Umbral, level 3, the high end. The stored roll is -0.035. Strength 2.1 and the level's tenth leave it at -0.0956. The line reads "Rift Step recovers 10% sooner".

The fold multiplies step_cd by 0.9044, the greater of 0.2 and 1 plus -0.0956.

Umbral, level 4, the low end. The stored roll is -0.07. Strength 2.1 and the level's tenth leave it at -0.2058. The line reads "Rift Step recovers 21% sooner".

The fold multiplies step_cd by 0.7942, the greater of 0.2 and 1 plus -0.2058.

Umbral, level 4, the high end. The stored roll is -0.035. Strength 2.1 and the level's tenth leave it at -0.1029. The line reads "Rift Step recovers 10% sooner".

The fold multiplies step_cd by 0.8971, the greater of 0.2 and 1 plus -0.1029.

Umbral, level 5, the low end. The stored roll is -0.07. Strength 2.1 and the level's tenth leave it at -0.2205. The line reads "Rift Step recovers 22% sooner".

The fold multiplies step_cd by 0.7795, the greater of 0.2 and 1 plus -0.2205.

Umbral, level 5, the high end. The stored roll is -0.035. Strength 2.1 and the level's tenth leave it at -0.1103. The line reads "Rift Step recovers 11% sooner".

The fold multiplies step_cd by 0.8898, the greater of 0.2 and 1 plus -0.1103.

Umbral, level 6, the low end. The stored roll is -0.07. Strength 2.1 and the level's tenth leave it at -0.2352. The line reads "Rift Step recovers 24% sooner".

The fold multiplies step_cd by 0.7648, the greater of 0.2 and 1 plus -0.2352.

Umbral, level 6, the high end. The stored roll is -0.035. Strength 2.1 and the level's tenth leave it at -0.1176. The line reads "Rift Step recovers 12% sooner".

The fold multiplies step_cd by 0.8824, the greater of 0.2 and 1 plus -0.1176.

#### lash_power

Worn, level 0, the low end. The stored roll is 0.06. Strength 1 and the level's tenth leave it at 0.06. The line reads "The Lash hits 6% harder".

The fold adds 0.06 to lash_power.

Worn, level 0, the high end. The stored roll is 0.12. Strength 1 and the level's tenth leave it at 0.12. The line reads "The Lash hits 12% harder".

The fold adds 0.12 to lash_power.

Worn, level 1, the low end. The stored roll is 0.06. Strength 1 and the level's tenth leave it at 0.066. The line reads "The Lash hits 7% harder".

The fold adds 0.066 to lash_power.

Worn, level 1, the high end. The stored roll is 0.12. Strength 1 and the level's tenth leave it at 0.132. The line reads "The Lash hits 13% harder".

The fold adds 0.132 to lash_power.

Worn, level 2, the low end. The stored roll is 0.06. Strength 1 and the level's tenth leave it at 0.072. The line reads "The Lash hits 7% harder".

The fold adds 0.072 to lash_power.

Worn, level 2, the high end. The stored roll is 0.12. Strength 1 and the level's tenth leave it at 0.144. The line reads "The Lash hits 14% harder".

The fold adds 0.144 to lash_power.

Kindled, level 0, the low end. The stored roll is 0.06. Strength 1.25 and the level's tenth leave it at 0.075. The line reads "The Lash hits 8% harder".

The fold adds 0.075 to lash_power.

Kindled, level 0, the high end. The stored roll is 0.12. Strength 1.25 and the level's tenth leave it at 0.15. The line reads "The Lash hits 15% harder".

The fold adds 0.15 to lash_power.

Kindled, level 1, the low end. The stored roll is 0.06. Strength 1.25 and the level's tenth leave it at 0.0825. The line reads "The Lash hits 8% harder".

The fold adds 0.0825 to lash_power.

Kindled, level 1, the high end. The stored roll is 0.12. Strength 1.25 and the level's tenth leave it at 0.165. The line reads "The Lash hits 17% harder".

The fold adds 0.165 to lash_power.

Kindled, level 2, the low end. The stored roll is 0.06. Strength 1.25 and the level's tenth leave it at 0.09. The line reads "The Lash hits 9% harder".

The fold adds 0.09 to lash_power.

Kindled, level 2, the high end. The stored roll is 0.12. Strength 1.25 and the level's tenth leave it at 0.18. The line reads "The Lash hits 18% harder".

The fold adds 0.18 to lash_power.

Kindled, level 3, the low end. The stored roll is 0.06. Strength 1.25 and the level's tenth leave it at 0.0975. The line reads "The Lash hits 10% harder".

The fold adds 0.0975 to lash_power.

Kindled, level 3, the high end. The stored roll is 0.12. Strength 1.25 and the level's tenth leave it at 0.195. The line reads "The Lash hits 20% harder".

The fold adds 0.195 to lash_power.

Hallowed, level 0, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.09. The line reads "The Lash hits 9% harder".

The fold adds 0.09 to lash_power.

Hallowed, level 0, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.18. The line reads "The Lash hits 18% harder".

The fold adds 0.18 to lash_power.

Hallowed, level 1, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.099. The line reads "The Lash hits 10% harder".

The fold adds 0.099 to lash_power.

Hallowed, level 1, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.198. The line reads "The Lash hits 20% harder".

The fold adds 0.198 to lash_power.

Hallowed, level 2, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.108. The line reads "The Lash hits 11% harder".

The fold adds 0.108 to lash_power.

Hallowed, level 2, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.216. The line reads "The Lash hits 22% harder".

The fold adds 0.216 to lash_power.

Hallowed, level 3, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.117. The line reads "The Lash hits 12% harder".

The fold adds 0.117 to lash_power.

Hallowed, level 3, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.234. The line reads "The Lash hits 23% harder".

The fold adds 0.234 to lash_power.

Hallowed, level 4, the low end. The stored roll is 0.06. Strength 1.5 and the level's tenth leave it at 0.126. The line reads "The Lash hits 13% harder".

The fold adds 0.126 to lash_power.

Hallowed, level 4, the high end. The stored roll is 0.12. Strength 1.5 and the level's tenth leave it at 0.252. The line reads "The Lash hits 25% harder".

The fold adds 0.252 to lash_power.

Reliquary, level 0, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.108. The line reads "The Lash hits 11% harder".

The fold adds 0.108 to lash_power.

Reliquary, level 0, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.216. The line reads "The Lash hits 22% harder".

The fold adds 0.216 to lash_power.

Reliquary, level 1, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.1188. The line reads "The Lash hits 12% harder".

The fold adds 0.1188 to lash_power.

Reliquary, level 1, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.2376. The line reads "The Lash hits 24% harder".

The fold adds 0.2376 to lash_power.

Reliquary, level 2, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.1296. The line reads "The Lash hits 13% harder".

The fold adds 0.1296 to lash_power.

Reliquary, level 2, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.2592. The line reads "The Lash hits 26% harder".

The fold adds 0.2592 to lash_power.

Reliquary, level 3, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.1404. The line reads "The Lash hits 14% harder".

The fold adds 0.1404 to lash_power.

Reliquary, level 3, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.2808. The line reads "The Lash hits 28% harder".

The fold adds 0.2808 to lash_power.

Reliquary, level 4, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.1512. The line reads "The Lash hits 15% harder".

The fold adds 0.1512 to lash_power.

Reliquary, level 4, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.3024. The line reads "The Lash hits 30% harder".

The fold adds 0.3024 to lash_power.

Reliquary, level 5, the low end. The stored roll is 0.06. Strength 1.8 and the level's tenth leave it at 0.162. The line reads "The Lash hits 16% harder".

The fold adds 0.162 to lash_power.

Reliquary, level 5, the high end. The stored roll is 0.12. Strength 1.8 and the level's tenth leave it at 0.324. The line reads "The Lash hits 32% harder".

The fold adds 0.324 to lash_power.

Umbral, level 0, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.126. The line reads "The Lash hits 13% harder".

The fold adds 0.126 to lash_power.

Umbral, level 0, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.252. The line reads "The Lash hits 25% harder".

The fold adds 0.252 to lash_power.

Umbral, level 1, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.1386. The line reads "The Lash hits 14% harder".

The fold adds 0.1386 to lash_power.

Umbral, level 1, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.2772. The line reads "The Lash hits 28% harder".

The fold adds 0.2772 to lash_power.

Umbral, level 2, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.1512. The line reads "The Lash hits 15% harder".

The fold adds 0.1512 to lash_power.

Umbral, level 2, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.3024. The line reads "The Lash hits 30% harder".

The fold adds 0.3024 to lash_power.

Umbral, level 3, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.1638. The line reads "The Lash hits 16% harder".

The fold adds 0.1638 to lash_power.

Umbral, level 3, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.3276. The line reads "The Lash hits 33% harder".

The fold adds 0.3276 to lash_power.

Umbral, level 4, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.1764. The line reads "The Lash hits 18% harder".

The fold adds 0.1764 to lash_power.

Umbral, level 4, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.3528. The line reads "The Lash hits 35% harder".

The fold adds 0.3528 to lash_power.

Umbral, level 5, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.189. The line reads "The Lash hits 19% harder".

The fold adds 0.189 to lash_power.

Umbral, level 5, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.378. The line reads "The Lash hits 38% harder".

The fold adds 0.378 to lash_power.

Umbral, level 6, the low end. The stored roll is 0.06. Strength 2.1 and the level's tenth leave it at 0.2016. The line reads "The Lash hits 20% harder".

The fold adds 0.2016 to lash_power.

Umbral, level 6, the high end. The stored roll is 0.12. Strength 2.1 and the level's tenth leave it at 0.4032. The line reads "The Lash hits 40% harder".

The fold adds 0.4032 to lash_power.

#### mark_dmg

Worn, level 0, the low end. The stored roll is 0.05. Strength 1 and the level's tenth leave it at 0.05. The line reads "+0.05 damage per Mark detonated".

The fold adds 0.05 to mark_dmg.

Worn, level 0, the high end. The stored roll is 0.1. Strength 1 and the level's tenth leave it at 0.1. The line reads "+0.10 damage per Mark detonated".

The fold adds 0.1 to mark_dmg.

Worn, level 1, the low end. The stored roll is 0.05. Strength 1 and the level's tenth leave it at 0.055. The line reads "+0.06 damage per Mark detonated".

The fold adds 0.055 to mark_dmg.

Worn, level 1, the high end. The stored roll is 0.1. Strength 1 and the level's tenth leave it at 0.11. The line reads "+0.11 damage per Mark detonated".

The fold adds 0.11 to mark_dmg.

Worn, level 2, the low end. The stored roll is 0.05. Strength 1 and the level's tenth leave it at 0.06. The line reads "+0.06 damage per Mark detonated".

The fold adds 0.06 to mark_dmg.

Worn, level 2, the high end. The stored roll is 0.1. Strength 1 and the level's tenth leave it at 0.12. The line reads "+0.12 damage per Mark detonated".

The fold adds 0.12 to mark_dmg.

Kindled, level 0, the low end. The stored roll is 0.05. Strength 1.25 and the level's tenth leave it at 0.0625. The line reads "+0.06 damage per Mark detonated".

The fold adds 0.0625 to mark_dmg.

Kindled, level 0, the high end. The stored roll is 0.1. Strength 1.25 and the level's tenth leave it at 0.125. The line reads "+0.12 damage per Mark detonated".

The fold adds 0.125 to mark_dmg.

Kindled, level 1, the low end. The stored roll is 0.05. Strength 1.25 and the level's tenth leave it at 0.0688. The line reads "+0.07 damage per Mark detonated".

The fold adds 0.0688 to mark_dmg.

Kindled, level 1, the high end. The stored roll is 0.1. Strength 1.25 and the level's tenth leave it at 0.1375. The line reads "+0.14 damage per Mark detonated".

The fold adds 0.1375 to mark_dmg.

Kindled, level 2, the low end. The stored roll is 0.05. Strength 1.25 and the level's tenth leave it at 0.075. The line reads "+0.07 damage per Mark detonated".

The fold adds 0.075 to mark_dmg.

Kindled, level 2, the high end. The stored roll is 0.1. Strength 1.25 and the level's tenth leave it at 0.15. The line reads "+0.15 damage per Mark detonated".

The fold adds 0.15 to mark_dmg.

Kindled, level 3, the low end. The stored roll is 0.05. Strength 1.25 and the level's tenth leave it at 0.0813. The line reads "+0.08 damage per Mark detonated".

The fold adds 0.0813 to mark_dmg.

Kindled, level 3, the high end. The stored roll is 0.1. Strength 1.25 and the level's tenth leave it at 0.1625. The line reads "+0.16 damage per Mark detonated".

The fold adds 0.1625 to mark_dmg.

Hallowed, level 0, the low end. The stored roll is 0.05. Strength 1.5 and the level's tenth leave it at 0.075. The line reads "+0.08 damage per Mark detonated".

The fold adds 0.075 to mark_dmg.

Hallowed, level 0, the high end. The stored roll is 0.1. Strength 1.5 and the level's tenth leave it at 0.15. The line reads "+0.15 damage per Mark detonated".

The fold adds 0.15 to mark_dmg.

Hallowed, level 1, the low end. The stored roll is 0.05. Strength 1.5 and the level's tenth leave it at 0.0825. The line reads "+0.08 damage per Mark detonated".

The fold adds 0.0825 to mark_dmg.

Hallowed, level 1, the high end. The stored roll is 0.1. Strength 1.5 and the level's tenth leave it at 0.165. The line reads "+0.17 damage per Mark detonated".

The fold adds 0.165 to mark_dmg.

Hallowed, level 2, the low end. The stored roll is 0.05. Strength 1.5 and the level's tenth leave it at 0.09. The line reads "+0.09 damage per Mark detonated".

The fold adds 0.09 to mark_dmg.

Hallowed, level 2, the high end. The stored roll is 0.1. Strength 1.5 and the level's tenth leave it at 0.18. The line reads "+0.18 damage per Mark detonated".

The fold adds 0.18 to mark_dmg.

Hallowed, level 3, the low end. The stored roll is 0.05. Strength 1.5 and the level's tenth leave it at 0.0975. The line reads "+0.10 damage per Mark detonated".

The fold adds 0.0975 to mark_dmg.

Hallowed, level 3, the high end. The stored roll is 0.1. Strength 1.5 and the level's tenth leave it at 0.195. The line reads "+0.20 damage per Mark detonated".

The fold adds 0.195 to mark_dmg.

Hallowed, level 4, the low end. The stored roll is 0.05. Strength 1.5 and the level's tenth leave it at 0.105. The line reads "+0.11 damage per Mark detonated".

The fold adds 0.105 to mark_dmg.

Hallowed, level 4, the high end. The stored roll is 0.1. Strength 1.5 and the level's tenth leave it at 0.21. The line reads "+0.21 damage per Mark detonated".

The fold adds 0.21 to mark_dmg.

Reliquary, level 0, the low end. The stored roll is 0.05. Strength 1.8 and the level's tenth leave it at 0.09. The line reads "+0.09 damage per Mark detonated".

The fold adds 0.09 to mark_dmg.

Reliquary, level 0, the high end. The stored roll is 0.1. Strength 1.8 and the level's tenth leave it at 0.18. The line reads "+0.18 damage per Mark detonated".

The fold adds 0.18 to mark_dmg.

Reliquary, level 1, the low end. The stored roll is 0.05. Strength 1.8 and the level's tenth leave it at 0.099. The line reads "+0.10 damage per Mark detonated".

The fold adds 0.099 to mark_dmg.

Reliquary, level 1, the high end. The stored roll is 0.1. Strength 1.8 and the level's tenth leave it at 0.198. The line reads "+0.20 damage per Mark detonated".

The fold adds 0.198 to mark_dmg.

Reliquary, level 2, the low end. The stored roll is 0.05. Strength 1.8 and the level's tenth leave it at 0.108. The line reads "+0.11 damage per Mark detonated".

The fold adds 0.108 to mark_dmg.

Reliquary, level 2, the high end. The stored roll is 0.1. Strength 1.8 and the level's tenth leave it at 0.216. The line reads "+0.22 damage per Mark detonated".

The fold adds 0.216 to mark_dmg.

Reliquary, level 3, the low end. The stored roll is 0.05. Strength 1.8 and the level's tenth leave it at 0.117. The line reads "+0.12 damage per Mark detonated".

The fold adds 0.117 to mark_dmg.

Reliquary, level 3, the high end. The stored roll is 0.1. Strength 1.8 and the level's tenth leave it at 0.234. The line reads "+0.23 damage per Mark detonated".

The fold adds 0.234 to mark_dmg.

Reliquary, level 4, the low end. The stored roll is 0.05. Strength 1.8 and the level's tenth leave it at 0.126. The line reads "+0.13 damage per Mark detonated".

The fold adds 0.126 to mark_dmg.

Reliquary, level 4, the high end. The stored roll is 0.1. Strength 1.8 and the level's tenth leave it at 0.252. The line reads "+0.25 damage per Mark detonated".

The fold adds 0.252 to mark_dmg.

Reliquary, level 5, the low end. The stored roll is 0.05. Strength 1.8 and the level's tenth leave it at 0.135. The line reads "+0.14 damage per Mark detonated".

The fold adds 0.135 to mark_dmg.

Reliquary, level 5, the high end. The stored roll is 0.1. Strength 1.8 and the level's tenth leave it at 0.27. The line reads "+0.27 damage per Mark detonated".

The fold adds 0.27 to mark_dmg.

Umbral, level 0, the low end. The stored roll is 0.05. Strength 2.1 and the level's tenth leave it at 0.105. The line reads "+0.11 damage per Mark detonated".

The fold adds 0.105 to mark_dmg.

Umbral, level 0, the high end. The stored roll is 0.1. Strength 2.1 and the level's tenth leave it at 0.21. The line reads "+0.21 damage per Mark detonated".

The fold adds 0.21 to mark_dmg.

Umbral, level 1, the low end. The stored roll is 0.05. Strength 2.1 and the level's tenth leave it at 0.1155. The line reads "+0.12 damage per Mark detonated".

The fold adds 0.1155 to mark_dmg.

Umbral, level 1, the high end. The stored roll is 0.1. Strength 2.1 and the level's tenth leave it at 0.231. The line reads "+0.23 damage per Mark detonated".

The fold adds 0.231 to mark_dmg.

Umbral, level 2, the low end. The stored roll is 0.05. Strength 2.1 and the level's tenth leave it at 0.126. The line reads "+0.13 damage per Mark detonated".

The fold adds 0.126 to mark_dmg.

Umbral, level 2, the high end. The stored roll is 0.1. Strength 2.1 and the level's tenth leave it at 0.252. The line reads "+0.25 damage per Mark detonated".

The fold adds 0.252 to mark_dmg.

Umbral, level 3, the low end. The stored roll is 0.05. Strength 2.1 and the level's tenth leave it at 0.1365. The line reads "+0.14 damage per Mark detonated".

The fold adds 0.1365 to mark_dmg.

Umbral, level 3, the high end. The stored roll is 0.1. Strength 2.1 and the level's tenth leave it at 0.273. The line reads "+0.27 damage per Mark detonated".

The fold adds 0.273 to mark_dmg.

Umbral, level 4, the low end. The stored roll is 0.05. Strength 2.1 and the level's tenth leave it at 0.147. The line reads "+0.15 damage per Mark detonated".

The fold adds 0.147 to mark_dmg.

Umbral, level 4, the high end. The stored roll is 0.1. Strength 2.1 and the level's tenth leave it at 0.294. The line reads "+0.29 damage per Mark detonated".

The fold adds 0.294 to mark_dmg.

Umbral, level 5, the low end. The stored roll is 0.05. Strength 2.1 and the level's tenth leave it at 0.1575. The line reads "+0.16 damage per Mark detonated".

The fold adds 0.1575 to mark_dmg.

Umbral, level 5, the high end. The stored roll is 0.1. Strength 2.1 and the level's tenth leave it at 0.315. The line reads "+0.32 damage per Mark detonated".

The fold adds 0.315 to mark_dmg.

Umbral, level 6, the low end. The stored roll is 0.05. Strength 2.1 and the level's tenth leave it at 0.168. The line reads "+0.17 damage per Mark detonated".

The fold adds 0.168 to mark_dmg.

Umbral, level 6, the high end. The stored roll is 0.1. Strength 2.1 and the level's tenth leave it at 0.336. The line reads "+0.34 damage per Mark detonated".

The fold adds 0.336 to mark_dmg.

#### lance_charge

Worn, level 0, the low end. The stored roll is -0.06. Strength 1 and the level's tenth leave it at -0.06. The line reads "Ember Lance charges 6% faster".

The fold multiplies lance_charge by 0.94, the greater of 0.2 and 1 plus -0.06.

Worn, level 0, the high end. The stored roll is -0.03. Strength 1 and the level's tenth leave it at -0.03. The line reads "Ember Lance charges 3% faster".

The fold multiplies lance_charge by 0.97, the greater of 0.2 and 1 plus -0.03.

Worn, level 1, the low end. The stored roll is -0.06. Strength 1 and the level's tenth leave it at -0.066. The line reads "Ember Lance charges 7% faster".

The fold multiplies lance_charge by 0.934, the greater of 0.2 and 1 plus -0.066.

Worn, level 1, the high end. The stored roll is -0.03. Strength 1 and the level's tenth leave it at -0.033. The line reads "Ember Lance charges 3% faster".

The fold multiplies lance_charge by 0.967, the greater of 0.2 and 1 plus -0.033.

Worn, level 2, the low end. The stored roll is -0.06. Strength 1 and the level's tenth leave it at -0.072. The line reads "Ember Lance charges 7% faster".

The fold multiplies lance_charge by 0.928, the greater of 0.2 and 1 plus -0.072.

Worn, level 2, the high end. The stored roll is -0.03. Strength 1 and the level's tenth leave it at -0.036. The line reads "Ember Lance charges 4% faster".

The fold multiplies lance_charge by 0.964, the greater of 0.2 and 1 plus -0.036.

Kindled, level 0, the low end. The stored roll is -0.06. Strength 1.25 and the level's tenth leave it at -0.075. The line reads "Ember Lance charges 8% faster".

The fold multiplies lance_charge by 0.925, the greater of 0.2 and 1 plus -0.075.

Kindled, level 0, the high end. The stored roll is -0.03. Strength 1.25 and the level's tenth leave it at -0.0375. The line reads "Ember Lance charges 4% faster".

The fold multiplies lance_charge by 0.9625, the greater of 0.2 and 1 plus -0.0375.

Kindled, level 1, the low end. The stored roll is -0.06. Strength 1.25 and the level's tenth leave it at -0.0825. The line reads "Ember Lance charges 8% faster".

The fold multiplies lance_charge by 0.9175, the greater of 0.2 and 1 plus -0.0825.

Kindled, level 1, the high end. The stored roll is -0.03. Strength 1.25 and the level's tenth leave it at -0.0413. The line reads "Ember Lance charges 4% faster".

The fold multiplies lance_charge by 0.9587, the greater of 0.2 and 1 plus -0.0413.

Kindled, level 2, the low end. The stored roll is -0.06. Strength 1.25 and the level's tenth leave it at -0.09. The line reads "Ember Lance charges 9% faster".

The fold multiplies lance_charge by 0.91, the greater of 0.2 and 1 plus -0.09.

Kindled, level 2, the high end. The stored roll is -0.03. Strength 1.25 and the level's tenth leave it at -0.045. The line reads "Ember Lance charges 5% faster".

The fold multiplies lance_charge by 0.955, the greater of 0.2 and 1 plus -0.045.

Kindled, level 3, the low end. The stored roll is -0.06. Strength 1.25 and the level's tenth leave it at -0.0975. The line reads "Ember Lance charges 10% faster".

The fold multiplies lance_charge by 0.9025, the greater of 0.2 and 1 plus -0.0975.

Kindled, level 3, the high end. The stored roll is -0.03. Strength 1.25 and the level's tenth leave it at -0.0488. The line reads "Ember Lance charges 5% faster".

The fold multiplies lance_charge by 0.9513, the greater of 0.2 and 1 plus -0.0488.

Hallowed, level 0, the low end. The stored roll is -0.06. Strength 1.5 and the level's tenth leave it at -0.09. The line reads "Ember Lance charges 9% faster".

The fold multiplies lance_charge by 0.91, the greater of 0.2 and 1 plus -0.09.

Hallowed, level 0, the high end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.045. The line reads "Ember Lance charges 5% faster".

The fold multiplies lance_charge by 0.955, the greater of 0.2 and 1 plus -0.045.

Hallowed, level 1, the low end. The stored roll is -0.06. Strength 1.5 and the level's tenth leave it at -0.099. The line reads "Ember Lance charges 10% faster".

The fold multiplies lance_charge by 0.901, the greater of 0.2 and 1 plus -0.099.

Hallowed, level 1, the high end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.0495. The line reads "Ember Lance charges 5% faster".

The fold multiplies lance_charge by 0.9505, the greater of 0.2 and 1 plus -0.0495.

Hallowed, level 2, the low end. The stored roll is -0.06. Strength 1.5 and the level's tenth leave it at -0.108. The line reads "Ember Lance charges 11% faster".

The fold multiplies lance_charge by 0.892, the greater of 0.2 and 1 plus -0.108.

Hallowed, level 2, the high end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.054. The line reads "Ember Lance charges 5% faster".

The fold multiplies lance_charge by 0.946, the greater of 0.2 and 1 plus -0.054.

Hallowed, level 3, the low end. The stored roll is -0.06. Strength 1.5 and the level's tenth leave it at -0.117. The line reads "Ember Lance charges 12% faster".

The fold multiplies lance_charge by 0.883, the greater of 0.2 and 1 plus -0.117.

Hallowed, level 3, the high end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.0585. The line reads "Ember Lance charges 6% faster".

The fold multiplies lance_charge by 0.9415, the greater of 0.2 and 1 plus -0.0585.

Hallowed, level 4, the low end. The stored roll is -0.06. Strength 1.5 and the level's tenth leave it at -0.126. The line reads "Ember Lance charges 13% faster".

The fold multiplies lance_charge by 0.874, the greater of 0.2 and 1 plus -0.126.

Hallowed, level 4, the high end. The stored roll is -0.03. Strength 1.5 and the level's tenth leave it at -0.063. The line reads "Ember Lance charges 6% faster".

The fold multiplies lance_charge by 0.937, the greater of 0.2 and 1 plus -0.063.

Reliquary, level 0, the low end. The stored roll is -0.06. Strength 1.8 and the level's tenth leave it at -0.108. The line reads "Ember Lance charges 11% faster".

The fold multiplies lance_charge by 0.892, the greater of 0.2 and 1 plus -0.108.

Reliquary, level 0, the high end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.054. The line reads "Ember Lance charges 5% faster".

The fold multiplies lance_charge by 0.946, the greater of 0.2 and 1 plus -0.054.

Reliquary, level 1, the low end. The stored roll is -0.06. Strength 1.8 and the level's tenth leave it at -0.1188. The line reads "Ember Lance charges 12% faster".

The fold multiplies lance_charge by 0.8812, the greater of 0.2 and 1 plus -0.1188.

Reliquary, level 1, the high end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.0594. The line reads "Ember Lance charges 6% faster".

The fold multiplies lance_charge by 0.9406, the greater of 0.2 and 1 plus -0.0594.

Reliquary, level 2, the low end. The stored roll is -0.06. Strength 1.8 and the level's tenth leave it at -0.1296. The line reads "Ember Lance charges 13% faster".

The fold multiplies lance_charge by 0.8704, the greater of 0.2 and 1 plus -0.1296.

Reliquary, level 2, the high end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.0648. The line reads "Ember Lance charges 6% faster".

The fold multiplies lance_charge by 0.9352, the greater of 0.2 and 1 plus -0.0648.

Reliquary, level 3, the low end. The stored roll is -0.06. Strength 1.8 and the level's tenth leave it at -0.1404. The line reads "Ember Lance charges 14% faster".

The fold multiplies lance_charge by 0.8596, the greater of 0.2 and 1 plus -0.1404.

Reliquary, level 3, the high end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.0702. The line reads "Ember Lance charges 7% faster".

The fold multiplies lance_charge by 0.9298, the greater of 0.2 and 1 plus -0.0702.

Reliquary, level 4, the low end. The stored roll is -0.06. Strength 1.8 and the level's tenth leave it at -0.1512. The line reads "Ember Lance charges 15% faster".

The fold multiplies lance_charge by 0.8488, the greater of 0.2 and 1 plus -0.1512.

Reliquary, level 4, the high end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.0756. The line reads "Ember Lance charges 8% faster".

The fold multiplies lance_charge by 0.9244, the greater of 0.2 and 1 plus -0.0756.

Reliquary, level 5, the low end. The stored roll is -0.06. Strength 1.8 and the level's tenth leave it at -0.162. The line reads "Ember Lance charges 16% faster".

The fold multiplies lance_charge by 0.838, the greater of 0.2 and 1 plus -0.162.

Reliquary, level 5, the high end. The stored roll is -0.03. Strength 1.8 and the level's tenth leave it at -0.081. The line reads "Ember Lance charges 8% faster".

The fold multiplies lance_charge by 0.919, the greater of 0.2 and 1 plus -0.081.

Umbral, level 0, the low end. The stored roll is -0.06. Strength 2.1 and the level's tenth leave it at -0.126. The line reads "Ember Lance charges 13% faster".

The fold multiplies lance_charge by 0.874, the greater of 0.2 and 1 plus -0.126.

Umbral, level 0, the high end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.063. The line reads "Ember Lance charges 6% faster".

The fold multiplies lance_charge by 0.937, the greater of 0.2 and 1 plus -0.063.

Umbral, level 1, the low end. The stored roll is -0.06. Strength 2.1 and the level's tenth leave it at -0.1386. The line reads "Ember Lance charges 14% faster".

The fold multiplies lance_charge by 0.8614, the greater of 0.2 and 1 plus -0.1386.

Umbral, level 1, the high end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0693. The line reads "Ember Lance charges 7% faster".

The fold multiplies lance_charge by 0.9307, the greater of 0.2 and 1 plus -0.0693.

Umbral, level 2, the low end. The stored roll is -0.06. Strength 2.1 and the level's tenth leave it at -0.1512. The line reads "Ember Lance charges 15% faster".

The fold multiplies lance_charge by 0.8488, the greater of 0.2 and 1 plus -0.1512.

Umbral, level 2, the high end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0756. The line reads "Ember Lance charges 8% faster".

The fold multiplies lance_charge by 0.9244, the greater of 0.2 and 1 plus -0.0756.

Umbral, level 3, the low end. The stored roll is -0.06. Strength 2.1 and the level's tenth leave it at -0.1638. The line reads "Ember Lance charges 16% faster".

The fold multiplies lance_charge by 0.8362, the greater of 0.2 and 1 plus -0.1638.

Umbral, level 3, the high end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0819. The line reads "Ember Lance charges 8% faster".

The fold multiplies lance_charge by 0.9181, the greater of 0.2 and 1 plus -0.0819.

Umbral, level 4, the low end. The stored roll is -0.06. Strength 2.1 and the level's tenth leave it at -0.1764. The line reads "Ember Lance charges 18% faster".

The fold multiplies lance_charge by 0.8236, the greater of 0.2 and 1 plus -0.1764.

Umbral, level 4, the high end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0882. The line reads "Ember Lance charges 9% faster".

The fold multiplies lance_charge by 0.9118, the greater of 0.2 and 1 plus -0.0882.

Umbral, level 5, the low end. The stored roll is -0.06. Strength 2.1 and the level's tenth leave it at -0.189. The line reads "Ember Lance charges 19% faster".

The fold multiplies lance_charge by 0.811, the greater of 0.2 and 1 plus -0.189.

Umbral, level 5, the high end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.0945. The line reads "Ember Lance charges 9% faster".

The fold multiplies lance_charge by 0.9055, the greater of 0.2 and 1 plus -0.0945.

Umbral, level 6, the low end. The stored roll is -0.06. Strength 2.1 and the level's tenth leave it at -0.2016. The line reads "Ember Lance charges 20% faster".

The fold multiplies lance_charge by 0.7984, the greater of 0.2 and 1 plus -0.2016.

Umbral, level 6, the high end. The stored roll is -0.03. Strength 2.1 and the level's tenth leave it at -0.1008. The line reads "Ember Lance charges 10% faster".

The fold multiplies lance_charge by 0.8992, the greater of 0.2 and 1 plus -0.1008.

#### lance_blast

Worn, level 0, the low end. The stored roll is 0.15. Strength 1 and the level's tenth leave it at 0.15. The line reads "Ember Lance bursts 0.15 m wider".

The fold adds 0.15 to lance_blast.

Worn, level 0, the high end. The stored roll is 0.3. Strength 1 and the level's tenth leave it at 0.3. The line reads "Ember Lance bursts 0.30 m wider".

The fold adds 0.3 to lance_blast.

Worn, level 1, the low end. The stored roll is 0.15. Strength 1 and the level's tenth leave it at 0.165. The line reads "Ember Lance bursts 0.17 m wider".

The fold adds 0.165 to lance_blast.

Worn, level 1, the high end. The stored roll is 0.3. Strength 1 and the level's tenth leave it at 0.33. The line reads "Ember Lance bursts 0.33 m wider".

The fold adds 0.33 to lance_blast.

Worn, level 2, the low end. The stored roll is 0.15. Strength 1 and the level's tenth leave it at 0.18. The line reads "Ember Lance bursts 0.18 m wider".

The fold adds 0.18 to lance_blast.

Worn, level 2, the high end. The stored roll is 0.3. Strength 1 and the level's tenth leave it at 0.36. The line reads "Ember Lance bursts 0.36 m wider".

The fold adds 0.36 to lance_blast.

Kindled, level 0, the low end. The stored roll is 0.15. Strength 1.25 and the level's tenth leave it at 0.1875. The line reads "Ember Lance bursts 0.19 m wider".

The fold adds 0.1875 to lance_blast.

Kindled, level 0, the high end. The stored roll is 0.3. Strength 1.25 and the level's tenth leave it at 0.375. The line reads "Ember Lance bursts 0.38 m wider".

The fold adds 0.375 to lance_blast.

Kindled, level 1, the low end. The stored roll is 0.15. Strength 1.25 and the level's tenth leave it at 0.2063. The line reads "Ember Lance bursts 0.21 m wider".

The fold adds 0.2063 to lance_blast.

Kindled, level 1, the high end. The stored roll is 0.3. Strength 1.25 and the level's tenth leave it at 0.4125. The line reads "Ember Lance bursts 0.41 m wider".

The fold adds 0.4125 to lance_blast.

Kindled, level 2, the low end. The stored roll is 0.15. Strength 1.25 and the level's tenth leave it at 0.225. The line reads "Ember Lance bursts 0.22 m wider".

The fold adds 0.225 to lance_blast.

Kindled, level 2, the high end. The stored roll is 0.3. Strength 1.25 and the level's tenth leave it at 0.45. The line reads "Ember Lance bursts 0.45 m wider".

The fold adds 0.45 to lance_blast.

Kindled, level 3, the low end. The stored roll is 0.15. Strength 1.25 and the level's tenth leave it at 0.2438. The line reads "Ember Lance bursts 0.24 m wider".

The fold adds 0.2438 to lance_blast.

Kindled, level 3, the high end. The stored roll is 0.3. Strength 1.25 and the level's tenth leave it at 0.4875. The line reads "Ember Lance bursts 0.49 m wider".

The fold adds 0.4875 to lance_blast.

Hallowed, level 0, the low end. The stored roll is 0.15. Strength 1.5 and the level's tenth leave it at 0.225. The line reads "Ember Lance bursts 0.22 m wider".

The fold adds 0.225 to lance_blast.

Hallowed, level 0, the high end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.45. The line reads "Ember Lance bursts 0.45 m wider".

The fold adds 0.45 to lance_blast.

Hallowed, level 1, the low end. The stored roll is 0.15. Strength 1.5 and the level's tenth leave it at 0.2475. The line reads "Ember Lance bursts 0.25 m wider".

The fold adds 0.2475 to lance_blast.

Hallowed, level 1, the high end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.495. The line reads "Ember Lance bursts 0.49 m wider".

The fold adds 0.495 to lance_blast.

Hallowed, level 2, the low end. The stored roll is 0.15. Strength 1.5 and the level's tenth leave it at 0.27. The line reads "Ember Lance bursts 0.27 m wider".

The fold adds 0.27 to lance_blast.

Hallowed, level 2, the high end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.54. The line reads "Ember Lance bursts 0.54 m wider".

The fold adds 0.54 to lance_blast.

Hallowed, level 3, the low end. The stored roll is 0.15. Strength 1.5 and the level's tenth leave it at 0.2925. The line reads "Ember Lance bursts 0.29 m wider".

The fold adds 0.2925 to lance_blast.

Hallowed, level 3, the high end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.585. The line reads "Ember Lance bursts 0.58 m wider".

The fold adds 0.585 to lance_blast.

Hallowed, level 4, the low end. The stored roll is 0.15. Strength 1.5 and the level's tenth leave it at 0.315. The line reads "Ember Lance bursts 0.31 m wider".

The fold adds 0.315 to lance_blast.

Hallowed, level 4, the high end. The stored roll is 0.3. Strength 1.5 and the level's tenth leave it at 0.63. The line reads "Ember Lance bursts 0.63 m wider".

The fold adds 0.63 to lance_blast.

Reliquary, level 0, the low end. The stored roll is 0.15. Strength 1.8 and the level's tenth leave it at 0.27. The line reads "Ember Lance bursts 0.27 m wider".

The fold adds 0.27 to lance_blast.

Reliquary, level 0, the high end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.54. The line reads "Ember Lance bursts 0.54 m wider".

The fold adds 0.54 to lance_blast.

Reliquary, level 1, the low end. The stored roll is 0.15. Strength 1.8 and the level's tenth leave it at 0.297. The line reads "Ember Lance bursts 0.30 m wider".

The fold adds 0.297 to lance_blast.

Reliquary, level 1, the high end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.594. The line reads "Ember Lance bursts 0.59 m wider".

The fold adds 0.594 to lance_blast.

Reliquary, level 2, the low end. The stored roll is 0.15. Strength 1.8 and the level's tenth leave it at 0.324. The line reads "Ember Lance bursts 0.32 m wider".

The fold adds 0.324 to lance_blast.

Reliquary, level 2, the high end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.648. The line reads "Ember Lance bursts 0.65 m wider".

The fold adds 0.648 to lance_blast.

Reliquary, level 3, the low end. The stored roll is 0.15. Strength 1.8 and the level's tenth leave it at 0.351. The line reads "Ember Lance bursts 0.35 m wider".

The fold adds 0.351 to lance_blast.

Reliquary, level 3, the high end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.702. The line reads "Ember Lance bursts 0.70 m wider".

The fold adds 0.702 to lance_blast.

Reliquary, level 4, the low end. The stored roll is 0.15. Strength 1.8 and the level's tenth leave it at 0.378. The line reads "Ember Lance bursts 0.38 m wider".

The fold adds 0.378 to lance_blast.

Reliquary, level 4, the high end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.756. The line reads "Ember Lance bursts 0.76 m wider".

The fold adds 0.756 to lance_blast.

Reliquary, level 5, the low end. The stored roll is 0.15. Strength 1.8 and the level's tenth leave it at 0.405. The line reads "Ember Lance bursts 0.41 m wider".

The fold adds 0.405 to lance_blast.

Reliquary, level 5, the high end. The stored roll is 0.3. Strength 1.8 and the level's tenth leave it at 0.81. The line reads "Ember Lance bursts 0.81 m wider".

The fold adds 0.81 to lance_blast.

Umbral, level 0, the low end. The stored roll is 0.15. Strength 2.1 and the level's tenth leave it at 0.315. The line reads "Ember Lance bursts 0.32 m wider".

The fold adds 0.315 to lance_blast.

Umbral, level 0, the high end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.63. The line reads "Ember Lance bursts 0.63 m wider".

The fold adds 0.63 to lance_blast.

Umbral, level 1, the low end. The stored roll is 0.15. Strength 2.1 and the level's tenth leave it at 0.3465. The line reads "Ember Lance bursts 0.35 m wider".

The fold adds 0.3465 to lance_blast.

Umbral, level 1, the high end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.693. The line reads "Ember Lance bursts 0.69 m wider".

The fold adds 0.693 to lance_blast.

Umbral, level 2, the low end. The stored roll is 0.15. Strength 2.1 and the level's tenth leave it at 0.378. The line reads "Ember Lance bursts 0.38 m wider".

The fold adds 0.378 to lance_blast.

Umbral, level 2, the high end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.756. The line reads "Ember Lance bursts 0.76 m wider".

The fold adds 0.756 to lance_blast.

Umbral, level 3, the low end. The stored roll is 0.15. Strength 2.1 and the level's tenth leave it at 0.4095. The line reads "Ember Lance bursts 0.41 m wider".

The fold adds 0.4095 to lance_blast.

Umbral, level 3, the high end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.819. The line reads "Ember Lance bursts 0.82 m wider".

The fold adds 0.819 to lance_blast.

Umbral, level 4, the low end. The stored roll is 0.15. Strength 2.1 and the level's tenth leave it at 0.441. The line reads "Ember Lance bursts 0.44 m wider".

The fold adds 0.441 to lance_blast.

Umbral, level 4, the high end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.882. The line reads "Ember Lance bursts 0.88 m wider".

The fold adds 0.882 to lance_blast.

Umbral, level 5, the low end. The stored roll is 0.15. Strength 2.1 and the level's tenth leave it at 0.4725. The line reads "Ember Lance bursts 0.47 m wider".

The fold adds 0.4725 to lance_blast.

Umbral, level 5, the high end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 0.945. The line reads "Ember Lance bursts 0.95 m wider".

The fold adds 0.945 to lance_blast.

Umbral, level 6, the low end. The stored roll is 0.15. Strength 2.1 and the level's tenth leave it at 0.504. The line reads "Ember Lance bursts 0.50 m wider".

The fold adds 0.504 to lance_blast.

Umbral, level 6, the high end. The stored roll is 0.3. Strength 2.1 and the level's tenth leave it at 1.008. The line reads "Ember Lance bursts 1.01 m wider".

The fold adds 1.008 to lance_blast.

#### ward_life

Worn, level 0, the low end. The stored roll is 0.4. Strength 1 and the level's tenth leave it at 0.4. The line reads "Lantern Ward burns 0.4 s longer".

The fold adds 0.4 to ward_life.

Worn, level 0, the high end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.8. The line reads "Lantern Ward burns 0.8 s longer".

The fold adds 0.8 to ward_life.

Worn, level 1, the low end. The stored roll is 0.4. Strength 1 and the level's tenth leave it at 0.44. The line reads "Lantern Ward burns 0.4 s longer".

The fold adds 0.44 to ward_life.

Worn, level 1, the high end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.88. The line reads "Lantern Ward burns 0.9 s longer".

The fold adds 0.88 to ward_life.

Worn, level 2, the low end. The stored roll is 0.4. Strength 1 and the level's tenth leave it at 0.48. The line reads "Lantern Ward burns 0.5 s longer".

The fold adds 0.48 to ward_life.

Worn, level 2, the high end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.96. The line reads "Lantern Ward burns 1.0 s longer".

The fold adds 0.96 to ward_life.

Kindled, level 0, the low end. The stored roll is 0.4. Strength 1.25 and the level's tenth leave it at 0.5. The line reads "Lantern Ward burns 0.5 s longer".

The fold adds 0.5 to ward_life.

Kindled, level 0, the high end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1. The line reads "Lantern Ward burns 1.0 s longer".

The fold adds 1 to ward_life.

Kindled, level 1, the low end. The stored roll is 0.4. Strength 1.25 and the level's tenth leave it at 0.55. The line reads "Lantern Ward burns 0.6 s longer".

The fold adds 0.55 to ward_life.

Kindled, level 1, the high end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.1. The line reads "Lantern Ward burns 1.1 s longer".

The fold adds 1.1 to ward_life.

Kindled, level 2, the low end. The stored roll is 0.4. Strength 1.25 and the level's tenth leave it at 0.6. The line reads "Lantern Ward burns 0.6 s longer".

The fold adds 0.6 to ward_life.

Kindled, level 2, the high end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.2. The line reads "Lantern Ward burns 1.2 s longer".

The fold adds 1.2 to ward_life.

Kindled, level 3, the low end. The stored roll is 0.4. Strength 1.25 and the level's tenth leave it at 0.65. The line reads "Lantern Ward burns 0.7 s longer".

The fold adds 0.65 to ward_life.

Kindled, level 3, the high end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.3. The line reads "Lantern Ward burns 1.3 s longer".

The fold adds 1.3 to ward_life.

Hallowed, level 0, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.6. The line reads "Lantern Ward burns 0.6 s longer".

The fold adds 0.6 to ward_life.

Hallowed, level 0, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.2. The line reads "Lantern Ward burns 1.2 s longer".

The fold adds 1.2 to ward_life.

Hallowed, level 1, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.66. The line reads "Lantern Ward burns 0.7 s longer".

The fold adds 0.66 to ward_life.

Hallowed, level 1, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.32. The line reads "Lantern Ward burns 1.3 s longer".

The fold adds 1.32 to ward_life.

Hallowed, level 2, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.72. The line reads "Lantern Ward burns 0.7 s longer".

The fold adds 0.72 to ward_life.

Hallowed, level 2, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.44. The line reads "Lantern Ward burns 1.4 s longer".

The fold adds 1.44 to ward_life.

Hallowed, level 3, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.78. The line reads "Lantern Ward burns 0.8 s longer".

The fold adds 0.78 to ward_life.

Hallowed, level 3, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.56. The line reads "Lantern Ward burns 1.6 s longer".

The fold adds 1.56 to ward_life.

Hallowed, level 4, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.84. The line reads "Lantern Ward burns 0.8 s longer".

The fold adds 0.84 to ward_life.

Hallowed, level 4, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.68. The line reads "Lantern Ward burns 1.7 s longer".

The fold adds 1.68 to ward_life.

Reliquary, level 0, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 0.72. The line reads "Lantern Ward burns 0.7 s longer".

The fold adds 0.72 to ward_life.

Reliquary, level 0, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.44. The line reads "Lantern Ward burns 1.4 s longer".

The fold adds 1.44 to ward_life.

Reliquary, level 1, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 0.792. The line reads "Lantern Ward burns 0.8 s longer".

The fold adds 0.792 to ward_life.

Reliquary, level 1, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.584. The line reads "Lantern Ward burns 1.6 s longer".

The fold adds 1.584 to ward_life.

Reliquary, level 2, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 0.864. The line reads "Lantern Ward burns 0.9 s longer".

The fold adds 0.864 to ward_life.

Reliquary, level 2, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.728. The line reads "Lantern Ward burns 1.7 s longer".

The fold adds 1.728 to ward_life.

Reliquary, level 3, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 0.936. The line reads "Lantern Ward burns 0.9 s longer".

The fold adds 0.936 to ward_life.

Reliquary, level 3, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.872. The line reads "Lantern Ward burns 1.9 s longer".

The fold adds 1.872 to ward_life.

Reliquary, level 4, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 1.008. The line reads "Lantern Ward burns 1.0 s longer".

The fold adds 1.008 to ward_life.

Reliquary, level 4, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 2.016. The line reads "Lantern Ward burns 2.0 s longer".

The fold adds 2.016 to ward_life.

Reliquary, level 5, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 1.08. The line reads "Lantern Ward burns 1.1 s longer".

The fold adds 1.08 to ward_life.

Reliquary, level 5, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 2.16. The line reads "Lantern Ward burns 2.2 s longer".

The fold adds 2.16 to ward_life.

Umbral, level 0, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 0.84. The line reads "Lantern Ward burns 0.8 s longer".

The fold adds 0.84 to ward_life.

Umbral, level 0, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 1.68. The line reads "Lantern Ward burns 1.7 s longer".

The fold adds 1.68 to ward_life.

Umbral, level 1, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 0.924. The line reads "Lantern Ward burns 0.9 s longer".

The fold adds 0.924 to ward_life.

Umbral, level 1, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 1.848. The line reads "Lantern Ward burns 1.8 s longer".

The fold adds 1.848 to ward_life.

Umbral, level 2, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.008. The line reads "Lantern Ward burns 1.0 s longer".

The fold adds 1.008 to ward_life.

Umbral, level 2, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.016. The line reads "Lantern Ward burns 2.0 s longer".

The fold adds 2.016 to ward_life.

Umbral, level 3, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.092. The line reads "Lantern Ward burns 1.1 s longer".

The fold adds 1.092 to ward_life.

Umbral, level 3, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.184. The line reads "Lantern Ward burns 2.2 s longer".

The fold adds 2.184 to ward_life.

Umbral, level 4, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.176. The line reads "Lantern Ward burns 1.2 s longer".

The fold adds 1.176 to ward_life.

Umbral, level 4, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.352. The line reads "Lantern Ward burns 2.4 s longer".

The fold adds 2.352 to ward_life.

Umbral, level 5, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.26. The line reads "Lantern Ward burns 1.3 s longer".

The fold adds 1.26 to ward_life.

Umbral, level 5, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.52. The line reads "Lantern Ward burns 2.5 s longer".

The fold adds 2.52 to ward_life.

Umbral, level 6, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.344. The line reads "Lantern Ward burns 1.3 s longer".

The fold adds 1.344 to ward_life.

Umbral, level 6, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.688. The line reads "Lantern Ward burns 2.7 s longer".

The fold adds 2.688 to ward_life.

#### well_life

Worn, level 0, the low end. The stored roll is 0.4. Strength 1 and the level's tenth leave it at 0.4. The line reads "Umbral Well holds 0.4 s longer".

The fold adds 0.4 to well_life.

Worn, level 0, the high end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.8. The line reads "Umbral Well holds 0.8 s longer".

The fold adds 0.8 to well_life.

Worn, level 1, the low end. The stored roll is 0.4. Strength 1 and the level's tenth leave it at 0.44. The line reads "Umbral Well holds 0.4 s longer".

The fold adds 0.44 to well_life.

Worn, level 1, the high end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.88. The line reads "Umbral Well holds 0.9 s longer".

The fold adds 0.88 to well_life.

Worn, level 2, the low end. The stored roll is 0.4. Strength 1 and the level's tenth leave it at 0.48. The line reads "Umbral Well holds 0.5 s longer".

The fold adds 0.48 to well_life.

Worn, level 2, the high end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.96. The line reads "Umbral Well holds 1.0 s longer".

The fold adds 0.96 to well_life.

Kindled, level 0, the low end. The stored roll is 0.4. Strength 1.25 and the level's tenth leave it at 0.5. The line reads "Umbral Well holds 0.5 s longer".

The fold adds 0.5 to well_life.

Kindled, level 0, the high end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1. The line reads "Umbral Well holds 1.0 s longer".

The fold adds 1 to well_life.

Kindled, level 1, the low end. The stored roll is 0.4. Strength 1.25 and the level's tenth leave it at 0.55. The line reads "Umbral Well holds 0.6 s longer".

The fold adds 0.55 to well_life.

Kindled, level 1, the high end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.1. The line reads "Umbral Well holds 1.1 s longer".

The fold adds 1.1 to well_life.

Kindled, level 2, the low end. The stored roll is 0.4. Strength 1.25 and the level's tenth leave it at 0.6. The line reads "Umbral Well holds 0.6 s longer".

The fold adds 0.6 to well_life.

Kindled, level 2, the high end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.2. The line reads "Umbral Well holds 1.2 s longer".

The fold adds 1.2 to well_life.

Kindled, level 3, the low end. The stored roll is 0.4. Strength 1.25 and the level's tenth leave it at 0.65. The line reads "Umbral Well holds 0.7 s longer".

The fold adds 0.65 to well_life.

Kindled, level 3, the high end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.3. The line reads "Umbral Well holds 1.3 s longer".

The fold adds 1.3 to well_life.

Hallowed, level 0, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.6. The line reads "Umbral Well holds 0.6 s longer".

The fold adds 0.6 to well_life.

Hallowed, level 0, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.2. The line reads "Umbral Well holds 1.2 s longer".

The fold adds 1.2 to well_life.

Hallowed, level 1, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.66. The line reads "Umbral Well holds 0.7 s longer".

The fold adds 0.66 to well_life.

Hallowed, level 1, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.32. The line reads "Umbral Well holds 1.3 s longer".

The fold adds 1.32 to well_life.

Hallowed, level 2, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.72. The line reads "Umbral Well holds 0.7 s longer".

The fold adds 0.72 to well_life.

Hallowed, level 2, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.44. The line reads "Umbral Well holds 1.4 s longer".

The fold adds 1.44 to well_life.

Hallowed, level 3, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.78. The line reads "Umbral Well holds 0.8 s longer".

The fold adds 0.78 to well_life.

Hallowed, level 3, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.56. The line reads "Umbral Well holds 1.6 s longer".

The fold adds 1.56 to well_life.

Hallowed, level 4, the low end. The stored roll is 0.4. Strength 1.5 and the level's tenth leave it at 0.84. The line reads "Umbral Well holds 0.8 s longer".

The fold adds 0.84 to well_life.

Hallowed, level 4, the high end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.68. The line reads "Umbral Well holds 1.7 s longer".

The fold adds 1.68 to well_life.

Reliquary, level 0, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 0.72. The line reads "Umbral Well holds 0.7 s longer".

The fold adds 0.72 to well_life.

Reliquary, level 0, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.44. The line reads "Umbral Well holds 1.4 s longer".

The fold adds 1.44 to well_life.

Reliquary, level 1, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 0.792. The line reads "Umbral Well holds 0.8 s longer".

The fold adds 0.792 to well_life.

Reliquary, level 1, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.584. The line reads "Umbral Well holds 1.6 s longer".

The fold adds 1.584 to well_life.

Reliquary, level 2, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 0.864. The line reads "Umbral Well holds 0.9 s longer".

The fold adds 0.864 to well_life.

Reliquary, level 2, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.728. The line reads "Umbral Well holds 1.7 s longer".

The fold adds 1.728 to well_life.

Reliquary, level 3, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 0.936. The line reads "Umbral Well holds 0.9 s longer".

The fold adds 0.936 to well_life.

Reliquary, level 3, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.872. The line reads "Umbral Well holds 1.9 s longer".

The fold adds 1.872 to well_life.

Reliquary, level 4, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 1.008. The line reads "Umbral Well holds 1.0 s longer".

The fold adds 1.008 to well_life.

Reliquary, level 4, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 2.016. The line reads "Umbral Well holds 2.0 s longer".

The fold adds 2.016 to well_life.

Reliquary, level 5, the low end. The stored roll is 0.4. Strength 1.8 and the level's tenth leave it at 1.08. The line reads "Umbral Well holds 1.1 s longer".

The fold adds 1.08 to well_life.

Reliquary, level 5, the high end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 2.16. The line reads "Umbral Well holds 2.2 s longer".

The fold adds 2.16 to well_life.

Umbral, level 0, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 0.84. The line reads "Umbral Well holds 0.8 s longer".

The fold adds 0.84 to well_life.

Umbral, level 0, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 1.68. The line reads "Umbral Well holds 1.7 s longer".

The fold adds 1.68 to well_life.

Umbral, level 1, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 0.924. The line reads "Umbral Well holds 0.9 s longer".

The fold adds 0.924 to well_life.

Umbral, level 1, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 1.848. The line reads "Umbral Well holds 1.8 s longer".

The fold adds 1.848 to well_life.

Umbral, level 2, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.008. The line reads "Umbral Well holds 1.0 s longer".

The fold adds 1.008 to well_life.

Umbral, level 2, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.016. The line reads "Umbral Well holds 2.0 s longer".

The fold adds 2.016 to well_life.

Umbral, level 3, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.092. The line reads "Umbral Well holds 1.1 s longer".

The fold adds 1.092 to well_life.

Umbral, level 3, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.184. The line reads "Umbral Well holds 2.2 s longer".

The fold adds 2.184 to well_life.

Umbral, level 4, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.176. The line reads "Umbral Well holds 1.2 s longer".

The fold adds 1.176 to well_life.

Umbral, level 4, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.352. The line reads "Umbral Well holds 2.4 s longer".

The fold adds 2.352 to well_life.

Umbral, level 5, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.26. The line reads "Umbral Well holds 1.3 s longer".

The fold adds 1.26 to well_life.

Umbral, level 5, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.52. The line reads "Umbral Well holds 2.5 s longer".

The fold adds 2.52 to well_life.

Umbral, level 6, the low end. The stored roll is 0.4. Strength 2.1 and the level's tenth leave it at 1.344. The line reads "Umbral Well holds 1.3 s longer".

The fold adds 1.344 to well_life.

Umbral, level 6, the high end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.688. The line reads "Umbral Well holds 2.7 s longer".

The fold adds 2.688 to well_life.

#### shade_life

Worn, level 0, the low end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.8. The line reads "A Bound Shade stays 0.8 s longer".

The fold adds 0.8 to shade_life.

Worn, level 0, the high end. The stored roll is 1.6. Strength 1 and the level's tenth leave it at 1.6. The line reads "A Bound Shade stays 1.6 s longer".

The fold adds 1.6 to shade_life.

Worn, level 1, the low end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.88. The line reads "A Bound Shade stays 0.9 s longer".

The fold adds 0.88 to shade_life.

Worn, level 1, the high end. The stored roll is 1.6. Strength 1 and the level's tenth leave it at 1.76. The line reads "A Bound Shade stays 1.8 s longer".

The fold adds 1.76 to shade_life.

Worn, level 2, the low end. The stored roll is 0.8. Strength 1 and the level's tenth leave it at 0.96. The line reads "A Bound Shade stays 1.0 s longer".

The fold adds 0.96 to shade_life.

Worn, level 2, the high end. The stored roll is 1.6. Strength 1 and the level's tenth leave it at 1.92. The line reads "A Bound Shade stays 1.9 s longer".

The fold adds 1.92 to shade_life.

Kindled, level 0, the low end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1. The line reads "A Bound Shade stays 1.0 s longer".

The fold adds 1 to shade_life.

Kindled, level 0, the high end. The stored roll is 1.6. Strength 1.25 and the level's tenth leave it at 2. The line reads "A Bound Shade stays 2.0 s longer".

The fold adds 2 to shade_life.

Kindled, level 1, the low end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.1. The line reads "A Bound Shade stays 1.1 s longer".

The fold adds 1.1 to shade_life.

Kindled, level 1, the high end. The stored roll is 1.6. Strength 1.25 and the level's tenth leave it at 2.2. The line reads "A Bound Shade stays 2.2 s longer".

The fold adds 2.2 to shade_life.

Kindled, level 2, the low end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.2. The line reads "A Bound Shade stays 1.2 s longer".

The fold adds 1.2 to shade_life.

Kindled, level 2, the high end. The stored roll is 1.6. Strength 1.25 and the level's tenth leave it at 2.4. The line reads "A Bound Shade stays 2.4 s longer".

The fold adds 2.4 to shade_life.

Kindled, level 3, the low end. The stored roll is 0.8. Strength 1.25 and the level's tenth leave it at 1.3. The line reads "A Bound Shade stays 1.3 s longer".

The fold adds 1.3 to shade_life.

Kindled, level 3, the high end. The stored roll is 1.6. Strength 1.25 and the level's tenth leave it at 2.6. The line reads "A Bound Shade stays 2.6 s longer".

The fold adds 2.6 to shade_life.

Hallowed, level 0, the low end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.2. The line reads "A Bound Shade stays 1.2 s longer".

The fold adds 1.2 to shade_life.

Hallowed, level 0, the high end. The stored roll is 1.6. Strength 1.5 and the level's tenth leave it at 2.4. The line reads "A Bound Shade stays 2.4 s longer".

The fold adds 2.4 to shade_life.

Hallowed, level 1, the low end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.32. The line reads "A Bound Shade stays 1.3 s longer".

The fold adds 1.32 to shade_life.

Hallowed, level 1, the high end. The stored roll is 1.6. Strength 1.5 and the level's tenth leave it at 2.64. The line reads "A Bound Shade stays 2.6 s longer".

The fold adds 2.64 to shade_life.

Hallowed, level 2, the low end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.44. The line reads "A Bound Shade stays 1.4 s longer".

The fold adds 1.44 to shade_life.

Hallowed, level 2, the high end. The stored roll is 1.6. Strength 1.5 and the level's tenth leave it at 2.88. The line reads "A Bound Shade stays 2.9 s longer".

The fold adds 2.88 to shade_life.

Hallowed, level 3, the low end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.56. The line reads "A Bound Shade stays 1.6 s longer".

The fold adds 1.56 to shade_life.

Hallowed, level 3, the high end. The stored roll is 1.6. Strength 1.5 and the level's tenth leave it at 3.12. The line reads "A Bound Shade stays 3.1 s longer".

The fold adds 3.12 to shade_life.

Hallowed, level 4, the low end. The stored roll is 0.8. Strength 1.5 and the level's tenth leave it at 1.68. The line reads "A Bound Shade stays 1.7 s longer".

The fold adds 1.68 to shade_life.

Hallowed, level 4, the high end. The stored roll is 1.6. Strength 1.5 and the level's tenth leave it at 3.36. The line reads "A Bound Shade stays 3.4 s longer".

The fold adds 3.36 to shade_life.

Reliquary, level 0, the low end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.44. The line reads "A Bound Shade stays 1.4 s longer".

The fold adds 1.44 to shade_life.

Reliquary, level 0, the high end. The stored roll is 1.6. Strength 1.8 and the level's tenth leave it at 2.88. The line reads "A Bound Shade stays 2.9 s longer".

The fold adds 2.88 to shade_life.

Reliquary, level 1, the low end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.584. The line reads "A Bound Shade stays 1.6 s longer".

The fold adds 1.584 to shade_life.

Reliquary, level 1, the high end. The stored roll is 1.6. Strength 1.8 and the level's tenth leave it at 3.168. The line reads "A Bound Shade stays 3.2 s longer".

The fold adds 3.168 to shade_life.

Reliquary, level 2, the low end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.728. The line reads "A Bound Shade stays 1.7 s longer".

The fold adds 1.728 to shade_life.

Reliquary, level 2, the high end. The stored roll is 1.6. Strength 1.8 and the level's tenth leave it at 3.456. The line reads "A Bound Shade stays 3.5 s longer".

The fold adds 3.456 to shade_life.

Reliquary, level 3, the low end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 1.872. The line reads "A Bound Shade stays 1.9 s longer".

The fold adds 1.872 to shade_life.

Reliquary, level 3, the high end. The stored roll is 1.6. Strength 1.8 and the level's tenth leave it at 3.744. The line reads "A Bound Shade stays 3.7 s longer".

The fold adds 3.744 to shade_life.

Reliquary, level 4, the low end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 2.016. The line reads "A Bound Shade stays 2.0 s longer".

The fold adds 2.016 to shade_life.

Reliquary, level 4, the high end. The stored roll is 1.6. Strength 1.8 and the level's tenth leave it at 4.032. The line reads "A Bound Shade stays 4.0 s longer".

The fold adds 4.032 to shade_life.

Reliquary, level 5, the low end. The stored roll is 0.8. Strength 1.8 and the level's tenth leave it at 2.16. The line reads "A Bound Shade stays 2.2 s longer".

The fold adds 2.16 to shade_life.

Reliquary, level 5, the high end. The stored roll is 1.6. Strength 1.8 and the level's tenth leave it at 4.32. The line reads "A Bound Shade stays 4.3 s longer".

The fold adds 4.32 to shade_life.

Umbral, level 0, the low end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 1.68. The line reads "A Bound Shade stays 1.7 s longer".

The fold adds 1.68 to shade_life.

Umbral, level 0, the high end. The stored roll is 1.6. Strength 2.1 and the level's tenth leave it at 3.36. The line reads "A Bound Shade stays 3.4 s longer".

The fold adds 3.36 to shade_life.

Umbral, level 1, the low end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 1.848. The line reads "A Bound Shade stays 1.8 s longer".

The fold adds 1.848 to shade_life.

Umbral, level 1, the high end. The stored roll is 1.6. Strength 2.1 and the level's tenth leave it at 3.696. The line reads "A Bound Shade stays 3.7 s longer".

The fold adds 3.696 to shade_life.

Umbral, level 2, the low end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.016. The line reads "A Bound Shade stays 2.0 s longer".

The fold adds 2.016 to shade_life.

Umbral, level 2, the high end. The stored roll is 1.6. Strength 2.1 and the level's tenth leave it at 4.032. The line reads "A Bound Shade stays 4.0 s longer".

The fold adds 4.032 to shade_life.

Umbral, level 3, the low end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.184. The line reads "A Bound Shade stays 2.2 s longer".

The fold adds 2.184 to shade_life.

Umbral, level 3, the high end. The stored roll is 1.6. Strength 2.1 and the level's tenth leave it at 4.368. The line reads "A Bound Shade stays 4.4 s longer".

The fold adds 4.368 to shade_life.

Umbral, level 4, the low end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.352. The line reads "A Bound Shade stays 2.4 s longer".

The fold adds 2.352 to shade_life.

Umbral, level 4, the high end. The stored roll is 1.6. Strength 2.1 and the level's tenth leave it at 4.704. The line reads "A Bound Shade stays 4.7 s longer".

The fold adds 4.704 to shade_life.

Umbral, level 5, the low end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.52. The line reads "A Bound Shade stays 2.5 s longer".

The fold adds 2.52 to shade_life.

Umbral, level 5, the high end. The stored roll is 1.6. Strength 2.1 and the level's tenth leave it at 5.04. The line reads "A Bound Shade stays 5.0 s longer".

The fold adds 5.04 to shade_life.

Umbral, level 6, the low end. The stored roll is 0.8. Strength 2.1 and the level's tenth leave it at 2.688. The line reads "A Bound Shade stays 2.7 s longer".

The fold adds 2.688 to shade_life.

Umbral, level 6, the high end. The stored roll is 1.6. Strength 2.1 and the level's tenth leave it at 5.376. The line reads "A Bound Shade stays 5.4 s longer".

The fold adds 5.376 to shade_life.

#### tether_reach

Worn, level 0, the low end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1. The line reads "Rift Tether reaches 1.0 m further".

The fold adds 1 to tether_reach.

Worn, level 0, the high end. The stored roll is 2. Strength 1 and the level's tenth leave it at 2. The line reads "Rift Tether reaches 2.0 m further".

The fold adds 2 to tether_reach.

Worn, level 1, the low end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1.1. The line reads "Rift Tether reaches 1.1 m further".

The fold adds 1.1 to tether_reach.

Worn, level 1, the high end. The stored roll is 2. Strength 1 and the level's tenth leave it at 2.2. The line reads "Rift Tether reaches 2.2 m further".

The fold adds 2.2 to tether_reach.

Worn, level 2, the low end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1.2. The line reads "Rift Tether reaches 1.2 m further".

The fold adds 1.2 to tether_reach.

Worn, level 2, the high end. The stored roll is 2. Strength 1 and the level's tenth leave it at 2.4. The line reads "Rift Tether reaches 2.4 m further".

The fold adds 2.4 to tether_reach.

Kindled, level 0, the low end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.25. The line reads "Rift Tether reaches 1.2 m further".

The fold adds 1.25 to tether_reach.

Kindled, level 0, the high end. The stored roll is 2. Strength 1.25 and the level's tenth leave it at 2.5. The line reads "Rift Tether reaches 2.5 m further".

The fold adds 2.5 to tether_reach.

Kindled, level 1, the low end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.375. The line reads "Rift Tether reaches 1.4 m further".

The fold adds 1.375 to tether_reach.

Kindled, level 1, the high end. The stored roll is 2. Strength 1.25 and the level's tenth leave it at 2.75. The line reads "Rift Tether reaches 2.8 m further".

The fold adds 2.75 to tether_reach.

Kindled, level 2, the low end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.5. The line reads "Rift Tether reaches 1.5 m further".

The fold adds 1.5 to tether_reach.

Kindled, level 2, the high end. The stored roll is 2. Strength 1.25 and the level's tenth leave it at 3. The line reads "Rift Tether reaches 3.0 m further".

The fold adds 3 to tether_reach.

Kindled, level 3, the low end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.625. The line reads "Rift Tether reaches 1.6 m further".

The fold adds 1.625 to tether_reach.

Kindled, level 3, the high end. The stored roll is 2. Strength 1.25 and the level's tenth leave it at 3.25. The line reads "Rift Tether reaches 3.2 m further".

The fold adds 3.25 to tether_reach.

Hallowed, level 0, the low end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.5. The line reads "Rift Tether reaches 1.5 m further".

The fold adds 1.5 to tether_reach.

Hallowed, level 0, the high end. The stored roll is 2. Strength 1.5 and the level's tenth leave it at 3. The line reads "Rift Tether reaches 3.0 m further".

The fold adds 3 to tether_reach.

Hallowed, level 1, the low end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.65. The line reads "Rift Tether reaches 1.7 m further".

The fold adds 1.65 to tether_reach.

Hallowed, level 1, the high end. The stored roll is 2. Strength 1.5 and the level's tenth leave it at 3.3. The line reads "Rift Tether reaches 3.3 m further".

The fold adds 3.3 to tether_reach.

Hallowed, level 2, the low end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.8. The line reads "Rift Tether reaches 1.8 m further".

The fold adds 1.8 to tether_reach.

Hallowed, level 2, the high end. The stored roll is 2. Strength 1.5 and the level's tenth leave it at 3.6. The line reads "Rift Tether reaches 3.6 m further".

The fold adds 3.6 to tether_reach.

Hallowed, level 3, the low end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.95. The line reads "Rift Tether reaches 2.0 m further".

The fold adds 1.95 to tether_reach.

Hallowed, level 3, the high end. The stored roll is 2. Strength 1.5 and the level's tenth leave it at 3.9. The line reads "Rift Tether reaches 3.9 m further".

The fold adds 3.9 to tether_reach.

Hallowed, level 4, the low end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 2.1. The line reads "Rift Tether reaches 2.1 m further".

The fold adds 2.1 to tether_reach.

Hallowed, level 4, the high end. The stored roll is 2. Strength 1.5 and the level's tenth leave it at 4.2. The line reads "Rift Tether reaches 4.2 m further".

The fold adds 4.2 to tether_reach.

Reliquary, level 0, the low end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 1.8. The line reads "Rift Tether reaches 1.8 m further".

The fold adds 1.8 to tether_reach.

Reliquary, level 0, the high end. The stored roll is 2. Strength 1.8 and the level's tenth leave it at 3.6. The line reads "Rift Tether reaches 3.6 m further".

The fold adds 3.6 to tether_reach.

Reliquary, level 1, the low end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 1.98. The line reads "Rift Tether reaches 2.0 m further".

The fold adds 1.98 to tether_reach.

Reliquary, level 1, the high end. The stored roll is 2. Strength 1.8 and the level's tenth leave it at 3.96. The line reads "Rift Tether reaches 4.0 m further".

The fold adds 3.96 to tether_reach.

Reliquary, level 2, the low end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.16. The line reads "Rift Tether reaches 2.2 m further".

The fold adds 2.16 to tether_reach.

Reliquary, level 2, the high end. The stored roll is 2. Strength 1.8 and the level's tenth leave it at 4.32. The line reads "Rift Tether reaches 4.3 m further".

The fold adds 4.32 to tether_reach.

Reliquary, level 3, the low end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.34. The line reads "Rift Tether reaches 2.3 m further".

The fold adds 2.34 to tether_reach.

Reliquary, level 3, the high end. The stored roll is 2. Strength 1.8 and the level's tenth leave it at 4.68. The line reads "Rift Tether reaches 4.7 m further".

The fold adds 4.68 to tether_reach.

Reliquary, level 4, the low end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.52. The line reads "Rift Tether reaches 2.5 m further".

The fold adds 2.52 to tether_reach.

Reliquary, level 4, the high end. The stored roll is 2. Strength 1.8 and the level's tenth leave it at 5.04. The line reads "Rift Tether reaches 5.0 m further".

The fold adds 5.04 to tether_reach.

Reliquary, level 5, the low end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.7. The line reads "Rift Tether reaches 2.7 m further".

The fold adds 2.7 to tether_reach.

Reliquary, level 5, the high end. The stored roll is 2. Strength 1.8 and the level's tenth leave it at 5.4. The line reads "Rift Tether reaches 5.4 m further".

The fold adds 5.4 to tether_reach.

Umbral, level 0, the low end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.1. The line reads "Rift Tether reaches 2.1 m further".

The fold adds 2.1 to tether_reach.

Umbral, level 0, the high end. The stored roll is 2. Strength 2.1 and the level's tenth leave it at 4.2. The line reads "Rift Tether reaches 4.2 m further".

The fold adds 4.2 to tether_reach.

Umbral, level 1, the low end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.31. The line reads "Rift Tether reaches 2.3 m further".

The fold adds 2.31 to tether_reach.

Umbral, level 1, the high end. The stored roll is 2. Strength 2.1 and the level's tenth leave it at 4.62. The line reads "Rift Tether reaches 4.6 m further".

The fold adds 4.62 to tether_reach.

Umbral, level 2, the low end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.52. The line reads "Rift Tether reaches 2.5 m further".

The fold adds 2.52 to tether_reach.

Umbral, level 2, the high end. The stored roll is 2. Strength 2.1 and the level's tenth leave it at 5.04. The line reads "Rift Tether reaches 5.0 m further".

The fold adds 5.04 to tether_reach.

Umbral, level 3, the low end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.73. The line reads "Rift Tether reaches 2.7 m further".

The fold adds 2.73 to tether_reach.

Umbral, level 3, the high end. The stored roll is 2. Strength 2.1 and the level's tenth leave it at 5.46. The line reads "Rift Tether reaches 5.5 m further".

The fold adds 5.46 to tether_reach.

Umbral, level 4, the low end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.94. The line reads "Rift Tether reaches 2.9 m further".

The fold adds 2.94 to tether_reach.

Umbral, level 4, the high end. The stored roll is 2. Strength 2.1 and the level's tenth leave it at 5.88. The line reads "Rift Tether reaches 5.9 m further".

The fold adds 5.88 to tether_reach.

Umbral, level 5, the low end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 3.15. The line reads "Rift Tether reaches 3.2 m further".

The fold adds 3.15 to tether_reach.

Umbral, level 5, the high end. The stored roll is 2. Strength 2.1 and the level's tenth leave it at 6.3. The line reads "Rift Tether reaches 6.3 m further".

The fold adds 6.3 to tether_reach.

Umbral, level 6, the low end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 3.36. The line reads "Rift Tether reaches 3.4 m further".

The fold adds 3.36 to tether_reach.

Umbral, level 6, the high end. The stored roll is 2. Strength 2.1 and the level's tenth leave it at 6.72. The line reads "Rift Tether reaches 6.7 m further".

The fold adds 6.72 to tether_reach.

#### peal_reach

Worn, level 0, the low end. The stored roll is 0.5. Strength 1 and the level's tenth leave it at 0.5. The line reads "The Founder's Peal carries 0.5 m further".

The fold adds 0.5 to peal_reach.

Worn, level 0, the high end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1. The line reads "The Founder's Peal carries 1.0 m further".

The fold adds 1 to peal_reach.

Worn, level 1, the low end. The stored roll is 0.5. Strength 1 and the level's tenth leave it at 0.55. The line reads "The Founder's Peal carries 0.6 m further".

The fold adds 0.55 to peal_reach.

Worn, level 1, the high end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1.1. The line reads "The Founder's Peal carries 1.1 m further".

The fold adds 1.1 to peal_reach.

Worn, level 2, the low end. The stored roll is 0.5. Strength 1 and the level's tenth leave it at 0.6. The line reads "The Founder's Peal carries 0.6 m further".

The fold adds 0.6 to peal_reach.

Worn, level 2, the high end. The stored roll is 1. Strength 1 and the level's tenth leave it at 1.2. The line reads "The Founder's Peal carries 1.2 m further".

The fold adds 1.2 to peal_reach.

Kindled, level 0, the low end. The stored roll is 0.5. Strength 1.25 and the level's tenth leave it at 0.625. The line reads "The Founder's Peal carries 0.6 m further".

The fold adds 0.625 to peal_reach.

Kindled, level 0, the high end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.25. The line reads "The Founder's Peal carries 1.2 m further".

The fold adds 1.25 to peal_reach.

Kindled, level 1, the low end. The stored roll is 0.5. Strength 1.25 and the level's tenth leave it at 0.6875. The line reads "The Founder's Peal carries 0.7 m further".

The fold adds 0.6875 to peal_reach.

Kindled, level 1, the high end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.375. The line reads "The Founder's Peal carries 1.4 m further".

The fold adds 1.375 to peal_reach.

Kindled, level 2, the low end. The stored roll is 0.5. Strength 1.25 and the level's tenth leave it at 0.75. The line reads "The Founder's Peal carries 0.8 m further".

The fold adds 0.75 to peal_reach.

Kindled, level 2, the high end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.5. The line reads "The Founder's Peal carries 1.5 m further".

The fold adds 1.5 to peal_reach.

Kindled, level 3, the low end. The stored roll is 0.5. Strength 1.25 and the level's tenth leave it at 0.8125. The line reads "The Founder's Peal carries 0.8 m further".

The fold adds 0.8125 to peal_reach.

Kindled, level 3, the high end. The stored roll is 1. Strength 1.25 and the level's tenth leave it at 1.625. The line reads "The Founder's Peal carries 1.6 m further".

The fold adds 1.625 to peal_reach.

Hallowed, level 0, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 0.75. The line reads "The Founder's Peal carries 0.8 m further".

The fold adds 0.75 to peal_reach.

Hallowed, level 0, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.5. The line reads "The Founder's Peal carries 1.5 m further".

The fold adds 1.5 to peal_reach.

Hallowed, level 1, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 0.825. The line reads "The Founder's Peal carries 0.8 m further".

The fold adds 0.825 to peal_reach.

Hallowed, level 1, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.65. The line reads "The Founder's Peal carries 1.7 m further".

The fold adds 1.65 to peal_reach.

Hallowed, level 2, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 0.9. The line reads "The Founder's Peal carries 0.9 m further".

The fold adds 0.9 to peal_reach.

Hallowed, level 2, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.8. The line reads "The Founder's Peal carries 1.8 m further".

The fold adds 1.8 to peal_reach.

Hallowed, level 3, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 0.975. The line reads "The Founder's Peal carries 1.0 m further".

The fold adds 0.975 to peal_reach.

Hallowed, level 3, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 1.95. The line reads "The Founder's Peal carries 2.0 m further".

The fold adds 1.95 to peal_reach.

Hallowed, level 4, the low end. The stored roll is 0.5. Strength 1.5 and the level's tenth leave it at 1.05. The line reads "The Founder's Peal carries 1.0 m further".

The fold adds 1.05 to peal_reach.

Hallowed, level 4, the high end. The stored roll is 1. Strength 1.5 and the level's tenth leave it at 2.1. The line reads "The Founder's Peal carries 2.1 m further".

The fold adds 2.1 to peal_reach.

Reliquary, level 0, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 0.9. The line reads "The Founder's Peal carries 0.9 m further".

The fold adds 0.9 to peal_reach.

Reliquary, level 0, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 1.8. The line reads "The Founder's Peal carries 1.8 m further".

The fold adds 1.8 to peal_reach.

Reliquary, level 1, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 0.99. The line reads "The Founder's Peal carries 1.0 m further".

The fold adds 0.99 to peal_reach.

Reliquary, level 1, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 1.98. The line reads "The Founder's Peal carries 2.0 m further".

The fold adds 1.98 to peal_reach.

Reliquary, level 2, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 1.08. The line reads "The Founder's Peal carries 1.1 m further".

The fold adds 1.08 to peal_reach.

Reliquary, level 2, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.16. The line reads "The Founder's Peal carries 2.2 m further".

The fold adds 2.16 to peal_reach.

Reliquary, level 3, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 1.17. The line reads "The Founder's Peal carries 1.2 m further".

The fold adds 1.17 to peal_reach.

Reliquary, level 3, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.34. The line reads "The Founder's Peal carries 2.3 m further".

The fold adds 2.34 to peal_reach.

Reliquary, level 4, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 1.26. The line reads "The Founder's Peal carries 1.3 m further".

The fold adds 1.26 to peal_reach.

Reliquary, level 4, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.52. The line reads "The Founder's Peal carries 2.5 m further".

The fold adds 2.52 to peal_reach.

Reliquary, level 5, the low end. The stored roll is 0.5. Strength 1.8 and the level's tenth leave it at 1.35. The line reads "The Founder's Peal carries 1.4 m further".

The fold adds 1.35 to peal_reach.

Reliquary, level 5, the high end. The stored roll is 1. Strength 1.8 and the level's tenth leave it at 2.7. The line reads "The Founder's Peal carries 2.7 m further".

The fold adds 2.7 to peal_reach.

Umbral, level 0, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.05. The line reads "The Founder's Peal carries 1.1 m further".

The fold adds 1.05 to peal_reach.

Umbral, level 0, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.1. The line reads "The Founder's Peal carries 2.1 m further".

The fold adds 2.1 to peal_reach.

Umbral, level 1, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.155. The line reads "The Founder's Peal carries 1.2 m further".

The fold adds 1.155 to peal_reach.

Umbral, level 1, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.31. The line reads "The Founder's Peal carries 2.3 m further".

The fold adds 2.31 to peal_reach.

Umbral, level 2, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.26. The line reads "The Founder's Peal carries 1.3 m further".

The fold adds 1.26 to peal_reach.

Umbral, level 2, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.52. The line reads "The Founder's Peal carries 2.5 m further".

The fold adds 2.52 to peal_reach.

Umbral, level 3, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.365. The line reads "The Founder's Peal carries 1.4 m further".

The fold adds 1.365 to peal_reach.

Umbral, level 3, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.73. The line reads "The Founder's Peal carries 2.7 m further".

The fold adds 2.73 to peal_reach.

Umbral, level 4, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.47. The line reads "The Founder's Peal carries 1.5 m further".

The fold adds 1.47 to peal_reach.

Umbral, level 4, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 2.94. The line reads "The Founder's Peal carries 2.9 m further".

The fold adds 2.94 to peal_reach.

Umbral, level 5, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.575. The line reads "The Founder's Peal carries 1.6 m further".

The fold adds 1.575 to peal_reach.

Umbral, level 5, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 3.15. The line reads "The Founder's Peal carries 3.2 m further".

The fold adds 3.15 to peal_reach.

Umbral, level 6, the low end. The stored roll is 0.5. Strength 2.1 and the level's tenth leave it at 1.68. The line reads "The Founder's Peal carries 1.7 m further".

The fold adds 1.68 to peal_reach.

Umbral, level 6, the high end. The stored roll is 1. Strength 2.1 and the level's tenth leave it at 3.36. The line reads "The Founder's Peal carries 3.4 m further".

The fold adds 3.36 to peal_reach.

#### ash_find

Worn, level 0, the low end. The stored roll is 0.04. Strength 1 and the level's tenth leave it at 0.04. The line reads "Foes give 4% more grave ash".

The fold adds 0.04 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Worn, level 0, the high end. The stored roll is 0.08. Strength 1 and the level's tenth leave it at 0.08. The line reads "Foes give 8% more grave ash".

The fold adds 0.08 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Worn, level 1, the low end. The stored roll is 0.04. Strength 1 and the level's tenth leave it at 0.044. The line reads "Foes give 4% more grave ash".

The fold adds 0.044 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Worn, level 1, the high end. The stored roll is 0.08. Strength 1 and the level's tenth leave it at 0.088. The line reads "Foes give 9% more grave ash".

The fold adds 0.088 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Worn, level 2, the low end. The stored roll is 0.04. Strength 1 and the level's tenth leave it at 0.048. The line reads "Foes give 5% more grave ash".

The fold adds 0.048 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Worn, level 2, the high end. The stored roll is 0.08. Strength 1 and the level's tenth leave it at 0.096. The line reads "Foes give 10% more grave ash".

The fold adds 0.096 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Kindled, level 0, the low end. The stored roll is 0.04. Strength 1.25 and the level's tenth leave it at 0.05. The line reads "Foes give 5% more grave ash".

The fold adds 0.05 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Kindled, level 0, the high end. The stored roll is 0.08. Strength 1.25 and the level's tenth leave it at 0.1. The line reads "Foes give 10% more grave ash".

The fold adds 0.1 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Kindled, level 1, the low end. The stored roll is 0.04. Strength 1.25 and the level's tenth leave it at 0.055. The line reads "Foes give 6% more grave ash".

The fold adds 0.055 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Kindled, level 1, the high end. The stored roll is 0.08. Strength 1.25 and the level's tenth leave it at 0.11. The line reads "Foes give 11% more grave ash".

The fold adds 0.11 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Kindled, level 2, the low end. The stored roll is 0.04. Strength 1.25 and the level's tenth leave it at 0.06. The line reads "Foes give 6% more grave ash".

The fold adds 0.06 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Kindled, level 2, the high end. The stored roll is 0.08. Strength 1.25 and the level's tenth leave it at 0.12. The line reads "Foes give 12% more grave ash".

The fold adds 0.12 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Kindled, level 3, the low end. The stored roll is 0.04. Strength 1.25 and the level's tenth leave it at 0.065. The line reads "Foes give 7% more grave ash".

The fold adds 0.065 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Kindled, level 3, the high end. The stored roll is 0.08. Strength 1.25 and the level's tenth leave it at 0.13. The line reads "Foes give 13% more grave ash".

The fold adds 0.13 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 0, the low end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.06. The line reads "Foes give 6% more grave ash".

The fold adds 0.06 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 0, the high end. The stored roll is 0.08. Strength 1.5 and the level's tenth leave it at 0.12. The line reads "Foes give 12% more grave ash".

The fold adds 0.12 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 1, the low end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.066. The line reads "Foes give 7% more grave ash".

The fold adds 0.066 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 1, the high end. The stored roll is 0.08. Strength 1.5 and the level's tenth leave it at 0.132. The line reads "Foes give 13% more grave ash".

The fold adds 0.132 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 2, the low end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.072. The line reads "Foes give 7% more grave ash".

The fold adds 0.072 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 2, the high end. The stored roll is 0.08. Strength 1.5 and the level's tenth leave it at 0.144. The line reads "Foes give 14% more grave ash".

The fold adds 0.144 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 3, the low end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.078. The line reads "Foes give 8% more grave ash".

The fold adds 0.078 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 3, the high end. The stored roll is 0.08. Strength 1.5 and the level's tenth leave it at 0.156. The line reads "Foes give 16% more grave ash".

The fold adds 0.156 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 4, the low end. The stored roll is 0.04. Strength 1.5 and the level's tenth leave it at 0.084. The line reads "Foes give 8% more grave ash".

The fold adds 0.084 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Hallowed, level 4, the high end. The stored roll is 0.08. Strength 1.5 and the level's tenth leave it at 0.168. The line reads "Foes give 17% more grave ash".

The fold adds 0.168 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 0, the low end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.072. The line reads "Foes give 7% more grave ash".

The fold adds 0.072 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 0, the high end. The stored roll is 0.08. Strength 1.8 and the level's tenth leave it at 0.144. The line reads "Foes give 14% more grave ash".

The fold adds 0.144 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 1, the low end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.0792. The line reads "Foes give 8% more grave ash".

The fold adds 0.0792 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 1, the high end. The stored roll is 0.08. Strength 1.8 and the level's tenth leave it at 0.1584. The line reads "Foes give 16% more grave ash".

The fold adds 0.1584 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 2, the low end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.0864. The line reads "Foes give 9% more grave ash".

The fold adds 0.0864 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 2, the high end. The stored roll is 0.08. Strength 1.8 and the level's tenth leave it at 0.1728. The line reads "Foes give 17% more grave ash".

The fold adds 0.1728 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 3, the low end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.0936. The line reads "Foes give 9% more grave ash".

The fold adds 0.0936 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 3, the high end. The stored roll is 0.08. Strength 1.8 and the level's tenth leave it at 0.1872. The line reads "Foes give 19% more grave ash".

The fold adds 0.1872 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 4, the low end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.1008. The line reads "Foes give 10% more grave ash".

The fold adds 0.1008 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 4, the high end. The stored roll is 0.08. Strength 1.8 and the level's tenth leave it at 0.2016. The line reads "Foes give 20% more grave ash".

The fold adds 0.2016 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 5, the low end. The stored roll is 0.04. Strength 1.8 and the level's tenth leave it at 0.108. The line reads "Foes give 11% more grave ash".

The fold adds 0.108 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Reliquary, level 5, the high end. The stored roll is 0.08. Strength 1.8 and the level's tenth leave it at 0.216. The line reads "Foes give 22% more grave ash".

The fold adds 0.216 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 0, the low end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.084. The line reads "Foes give 8% more grave ash".

The fold adds 0.084 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 0, the high end. The stored roll is 0.08. Strength 2.1 and the level's tenth leave it at 0.168. The line reads "Foes give 17% more grave ash".

The fold adds 0.168 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 1, the low end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.0924. The line reads "Foes give 9% more grave ash".

The fold adds 0.0924 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 1, the high end. The stored roll is 0.08. Strength 2.1 and the level's tenth leave it at 0.1848. The line reads "Foes give 18% more grave ash".

The fold adds 0.1848 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 2, the low end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.1008. The line reads "Foes give 10% more grave ash".

The fold adds 0.1008 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 2, the high end. The stored roll is 0.08. Strength 2.1 and the level's tenth leave it at 0.2016. The line reads "Foes give 20% more grave ash".

The fold adds 0.2016 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 3, the low end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.1092. The line reads "Foes give 11% more grave ash".

The fold adds 0.1092 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 3, the high end. The stored roll is 0.08. Strength 2.1 and the level's tenth leave it at 0.2184. The line reads "Foes give 22% more grave ash".

The fold adds 0.2184 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 4, the low end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.1176. The line reads "Foes give 12% more grave ash".

The fold adds 0.1176 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 4, the high end. The stored roll is 0.08. Strength 2.1 and the level's tenth leave it at 0.2352. The line reads "Foes give 24% more grave ash".

The fold adds 0.2352 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 5, the low end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.126. The line reads "Foes give 13% more grave ash".

The fold adds 0.126 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 5, the high end. The stored roll is 0.08. Strength 2.1 and the level's tenth leave it at 0.252. The line reads "Foes give 25% more grave ash".

The fold adds 0.252 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 6, the low end. The stored roll is 0.04. Strength 2.1 and the level's tenth leave it at 0.1344. The line reads "Foes give 13% more grave ash".

The fold adds 0.1344 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

Umbral, level 6, the high end. The stored roll is 0.08. Strength 2.1 and the level's tenth leave it at 0.2688. The line reads "Foes give 27% more grave ash".

The fold adds 0.2688 to ash_find.

Sheet 268 owns this line. The percent above is what the format prints from the scaled roll, and the kill pays one extra pinch when a roll falls under the value.

### The four sets, as they stand

Part XXXI already checked these against the fold. They are here so the forge chapter has the sentences beside the lines above. Two pieces wake the first. Four wake the second.

Kindler's Regalia. Two pieces: Ember Lance charges 10% faster. Four pieces: Ember Lance bursts 0.6 m wider, and a burning foe takes a Mark for every second it burns (as the Ember Rosary).

Ferryman's Weeds. Two pieces: +0.15 damage for every Mark detonated. Four pieces: Rift Tether Marks everything along its chain, and the hook and a Bound Shade's darts lay 2 Marks, not 1.

Lay Brother's Tally. Two pieces: +15 Gloom held. Four pieces: Umbral Nova deals 1.5 damage for every Mark it detonates (as the Oath of the Tally), and every kill mends 2 Wounds.

Bellwright's Garb. Two pieces: The Lash hits 20% harder. Four pieces: Rift Bolt's Lash comes every 2nd bolt in a chain (as the Oath of the Lash), and spells recover 5% sooner.

### The four legends, as they stand

Sheet 256 still owns the ward's roots. These four are the legend lines as written.

Splinter of the Door, on the Orb Focus. Legend: Rift Step recovers twice as fast, and every step mends 3 Wounds.

Shroud of the Sunk, on the Vestment. Legend: Lantern Ward roots what crosses its light in brambles: slowed hard, and Marked once.

Glass of the Unlit Lamp, on the Lantern Glass. Legend: a Bound Shade stays 6 s longer, and its darts burst on a Marked foe.

Rope of the Stair, on the Girdle. Legend: every foe within 2 m of where Rift Step lands takes a Mark, and the step roots what it passes in brambles.

### The named pieces

A named piece has a fixed slot, rarity, and list of affixes. The rolls are still the band above, scaled by that rarity at level 0 until a fire raises it. The name replaces the base name. Item level at level 0 includes the named bonus of 4.

Heartwood Orb-Cup. Orb Focus, Reliquary, affixes lash_power, power, mark_dmg. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. Cut from the oak the thorn grew through. The rings count backward.

Henge-Moss Mantle. Vestment, Reliquary, affixes dark_mult, gloom_add, kill_relief. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. Moss off the standing stones. It still faces north when you lay it down.

Briarwick Glass. Lantern Glass, Reliquary, affixes ward_life, kill_relief, lit_mult. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. A briar grew round this glass and drank the light. You cut it free. It is still thirsty.

Osric's Counting-Cord. Girdle, Reliquary, affixes cd, kill_relief, step_cd. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. One knot for every brother. The Abbot ran out of cord before he ran out of brothers.

Charnel Censer-Glass. Lantern Glass, Reliquary, affixes well_life, mark_dmg, ward_life. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. The light through it is the colour of old teeth.

Abbot's Knuckle-Collar. Orb Focus, Reliquary, affixes mark_dmg, power, lance_blast. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. He wore the first brothers at his throat, so that they would hear him pray.

Stole of the Third Edict. Vestment, Reliquary, affixes gloom_add, lit_mult, power. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. Hierarch Aurel's edicts are stitched into the lining. The third is unpicked.

Latchkeeper's Cord. Girdle, Reliquary, affixes step_range, step_cd, cd. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. It tied the latch to his wrist. His wrist is gone. The knot held.

Orb-Cage of the Turning Sky. Orb Focus, Reliquary, affixes power, lance_charge, lash_power. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. Set the orb in it and the light turns inward, as the sky did.

Gravedigger's Lamp-Glass. Lantern Glass, Hallowed, affixes ward_life, lit_mult. Item level 26 at level 0, and the cap is level 4, where the plain item level would be 34 before the named 4, so 38 with it. Soot on the inside. Earth on the outside. A thumbprint in both.

Pilgrim-Bone Cincture. Girdle, Hallowed, affixes step_range, kill_relief. Item level 26 at level 0, and the cap is level 4, where the plain item level would be 34 before the named 4, so 38 with it. Finger bones strung like beads. The pilgrims gave them freely. Mostly.

Mire-Wick Stole. Vestment, Hallowed, affixes dark_mult, gloom_add. Item level 26 at level 0, and the cap is level 4, where the plain item level would be 34 before the named 4, so 38 with it. Woven from fen-rush and lamp-wick. It smoulders a little when the Gloom is close.

Corpse-Candle Cradle. Orb Focus, Hallowed, affixes lance_charge, power. Item level 26 at level 0, and the cap is level 4, where the plain item level would be 34 before the named 4, so 38 with it. The fen lights that lead walkers astray sat in this, once, and were carried home.

Tollman's Iron Cup. Orb Focus, Reliquary, affixes power, mark_dmg, lash_power. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. Every soul on the Stair paid the toll. He kept one coin from each, and melted them.

Widow's Ash-Veil. Vestment, Reliquary, affixes gloom_add, kill_relief, lit_mult. Item level 33 at level 0, and the cap is level 5, where the plain item level would be 44 before the named 4, so 48 with it. She wore it at every burial in the valley. Then nobody was left to bury her.

## Part XL — the tasks as they stand

66 tasks, in the order `ORDER` keeps them. `step_text` writes the save's count over `{n}`, the wanted count over `{of}`, the bells already answered over `{bells}`, and the coal's seconds, rounded up, over `{t}`. A counted step is a gather, a slay, a collect, or a seal. A seal with no `of` on the step takes its count from `EnemySpawner.seal_total` when the task is running. A carry burns in real seconds and pauses with the menus. The 30-minute slice hides a task whose repeat is daily, and a task that carries a raid. `BELLS_NEEDED` is 4, and the peal's condition is `bells:4`, and the sentence says four. Sheet 193 still owns a count with no ground. A number below that already equals its condition stays a number.

The seven bell tasks are bell_holds, bell_quarry, bell_moor, bell_foundry, bell_orchard, bell_necropolis, bell_mere. Four of them wake the door. All seven are the later condition `bells:7`.

Father Harrow, on The Slow Way Down, wakes within 24.0 m of the lantern and has 9 life. The step says to put the hollowed man to rest, and leaves the life to the body.

Oswin's walk, on The Forty-First Stone, ends within 4.5 m of the stone, and he waits inside 16.0 m.

### Edda's Tongs

Giver Hild, Hild, at Edda's forge. The journal files it under Hearthward. Edda's tongs lie on her stone in the Kindlers' Yard. Hild wants them back on the anvil, and cannot make herself fetch them.

The hand-in pays 10 grave ash.

Step 1, a find. The line is "Find Edda's tongs on her stone in the Kindlers' Yard, west past Abel's dig".

Step 2, a talk. The line is "Bring Edda's tongs to Hild at the forge". The person is Hild.

Step 3, a place. The line is "Lay Edda's tongs back on her stone in the Kindlers' Yard".

The ending `forge`: Hild shod your staff with a ferrule of Edda's iron. The tongs work the forge again.

The ending `stone`: Edda's tongs lie on her stone again. It stays warm.

### The Forty-First Stone

Giver Oswin, Oswin the pilgrim, on the west road. The journal files it under The Pilgrims' Road. Oswin has touched forty waystones on the way to the Stair. He wants to touch the last, and his eyes are bad in the dark.

The hand-in pays 12 grave ash, the charm charm_waystone.

`grant` pays the charm, because `charm_waystone` is in ItemDB. The else of 1 relic_fragment is what that function pays when the charm id is absent.

Step 1, a escort. The line is "Walk Oswin to the forty-first waystone, at the head of the rim road south of the green".

Step 2, a talk. The line is "Speak with Oswin at the forty-first stone". The person is Oswin.

The ending `truth`: You told Oswin the Stair is gone. He took the west road home and left his staff behind.

The ending `faith`: Oswin keeps his vigil at the forty-first stone, waiting for a bell.

### Names for the Yard

Giver Abel the sexton, Abel the sexton, by the Kindlers' Yard. The journal files it under Hearthward. The Order cut numbers where the names should be. A few of the faithful scratched the names back on slates and hid them.

The hand-in pays 15 grave ash, 1 relic_fragment.

Step 1, a gather. The line is "Find the three name-slates: in the Glimmer Glade, on the chapel lane, in the Barrow Field ({n}/{of})". It wants 3.

Step 2, a talk. The line is "Bring the names to Abel at his dig". The person is Abel the sexton.

The ending line: Maren Coyle, Tam, Sister Ide: their names are cut in the Kindlers' Yard, by Edda's stone.

### The Keg's Missing Ale

Giver The keep, The keep of the Kindled Keg. The journal files it under Hearthward. Somebody has been lifting full mugs off the Keg's counter. The keep wants to know who before he starts guessing.

Step 1, a find. The line is "Look behind the Kindled Keg, by the chimney, for signs of the ale thief".

Step 2, a find. The line is "Follow the chalk circles to the green's fire".

Step 3, a talk. The line is "Ask Nan Wright about the chalk circles". The person is Nan Wright.

Step 4, a talk. The line is "Tell the keep what you found". The person is The keep.

After the choice `rats`, a step's line becomes "Tell the keep it was rats".

After the choice `covered`, a step's line becomes "Square Nan's debt with the keep (10 ash)".

The ending `told`: The keep knows it was Nan. He leaves a mug by the green's fire himself now.

The ending `covered`: You paid for Nan's mugs. The keep is watching you; Nan drew you a circle.

The ending `rats`: The keep blames rats. Nan keeps her secret, and her mug by the fire.

### The Slow Way Down

Giver Ostrin Harrow, Ostrin Harrow, at the Keg's bar. The journal files it under The Hollow Fen. Ostrin's father took his lantern down the fen after the bells, six winters gone. Ostrin wants the lantern back, whatever is holding it.

The hand-in pays 20 grave ash, 1 relic_fragment.

Step 1, a reach. The line is "Search the fen by the fen brazier, under the Ossuary's door, for Father Harrow's lantern". The map point is (58.0, -47.0).

Step 2, a kill. The line is "Put the hollowed man by the lantern to rest". The map point is (58.0, -47.0).

Step 3, a find. The line is "Take Father Harrow's lantern".

Step 4, a talk. The line is "Bring the lantern to Ostrin Harrow at the Kindled Keg". The person is Ostrin Harrow.

The ending `truth`: Ostrin knows his father is at rest. The lantern burns on the Keg's counter.

The ending `mercy`: Ostrin thinks his father still walks the fen. The lantern sits cold on the Keg's counter, waiting.

### Ash for the Hearthfire

Giver Old Fennick, Old Fennick, on his lamp round. The journal files it under Hearthward. It repeats daily. The 30-minute slice hides it. The giver's mark and the accept screen start it. The green's fire eats more than it used to. Ash off the hollowed burns slow and hot, if you can stand to carry it. Five handfuls. Every night, if you like. The fire won't stop being hungry.

The hand-in pays 12 grave ash, 2 ember_shard.

Step 1, a collect. The line is "Gather bone ash from the hollowed you put down ({n}/{of})". It wants 5. Each qualifying kill drops it with chance 0.6. The label is Bone ash.

Step 2, a turnin. The line is "Bring the bone ash to Old Fennick". The person is Old Fennick.

The ending line: The green's fire took the bone ash and burned blue for an hour.

### The Road Kept Clear

Giver Grisel, Grisel the ash-wife, at her cart. The journal files it under The Pilgrims' Road. It repeats daily. The 30-minute slice hides it. The giver's mark and the accept screen start it. Nobody buys from a cart they can't reach. The hollowed have the Pilgrims' Road again. Thin them, and I'll thin my prices. A little.

The hand-in pays 10 grave ash, 1 relic_fragment.

Step 1, a slay. The line is "Put down the hollowed on the Pilgrims' Road ({n}/{of})". It wants 6. The count is kept in `road`. The label is Hollowed on the Road. The map point is (-30.0, 62.0).

Step 2, a turnin. The line is "Tell Grisel the road is clear". The person is Grisel.

The ending line: The road is clear for a night. Grisel's cart went out as far as the third waystone.

### A Coal for the Shrine

Giver Old Fennick, Old Fennick, on his lamp round. The journal files it under Hearthward. The giver's mark and the accept screen start it. The shrine in the Glimmer Glade was lit from the green's fire, once, coal to coal. Carry one there. Don't dawdle; a coal won't wait for you, and the dark will try to drink it.

The hand-in pays 10 grave ash.

The hand-in also offers one of: a Kindled Lantern Glass; a Kindled Girdle.

Step 1, a find. The line is "Take a live coal from the green's fire".

Step 2, a carry. The line is "Carry the coal to the shrine brazier in the Glimmer Glade before it dies ({t} s)". The label is Coal. The radius is 5 m. The coal has 100 s, and the line's {t} is the seconds left, rounded up. The delivery point is (-31.0, 4.0).

Step 3, a turnin. The line is "Tell Old Fennick the shrine has the green's fire". The person is Old Fennick.

The ending line: The shrine in the glade burns with the green's fire again, coal to coal.

### A Lamp on the Spire

Giver Old Fennick, Old Fennick, on his lamp round. The journal files it under The Summit of Ascension. It is offered when kindled:1. The giver's mark and the accept screen start it. The Order kept a lamp on the Watchers' Spire, up under the Crowns, to watch the sky turn. I lit it for them as a boy. Go and see if it's still there. Tell me what the sky looks like from up there.

The hand-in pays 14 grave ash.

The hand-in also offers one of: a Hallowed Lantern Glass; a Hallowed Orb Focus.

Step 1, a visit. The line is "Climb to the Watchers' Spire under the Crowns". The label is The Watchers' Spire. The radius is 14 m. The map point is (-52.0, -100.0).

Step 2, a turnin. The line is "Tell Old Fennick what you saw from the Spire". The person is Old Fennick.

The ending line: Fennick listened to all of it with his eyes shut. The lamp on the Spire is out. He knew.

### One Loaf, One Blessing

Giver Nan Wright, Nan Wright, on the green. The journal files it under The Pilgrims' Road. The giver's mark and the accept screen start it. The Almonry on the road gave a loaf to every pilgrim, one a night. Pell always ate hers on the step. There might be one left on the board. There's always one left on the board.

The hand-in pays 8 grave ash.

The hand-in also offers one of: a Kindled Vestment; a Kindled Lantern Glass.

Step 1, a visit. The line is "Go to the Almonry on the Pilgrims' Road". The label is The Almonry. The radius is 12 m. The map point is (46.0, 40.0).

Step 2, a find. The line is "Take the last loaf from the Almonry's board".

Step 3, a turnin. The line is "Bring the loaf to Nan Wright". The person is Nan Wright.

The ending line: Nan put the loaf by the green's fire, inside a chalk circle, beside the mug.

### Thorns at the Door

Giver Wyck, Wyck, at his fire in the Thornwood. The journal files it under The Thornwood. The giver's mark and the accept screen start it. The thorn seal on the Ring's hill has guards. Hollowed things, set like stakes along the wood's edge. Put them down and the seal breaks. Then the Thornwarden will come to see who's knocking.

The hand-in pays 15 grave ash.

The hand-in also offers one of: a Kindled Orb Focus; a Kindled Vestment; a Kindled Girdle.

Step 1, a seal. The line is "Put down the thorn seal's guards on the Thornwood edge ({n}/{of})". The seal is `henge`. The label is Thorn seal guards. The map point is (-50.0, -8.0).

Step 2, a turnin. The line is "Tell Wyck the thorn seal is broken". The person is Wyck.

The ending line: The thorn seal is broken. Wyck felt it in his teeth.

### Smoke Under the Oaks

Giver Wyck, Wyck, at his fire in the Thornwood. The journal files it under The Thornwood. It is offered when qd:thorn_door. The giver's mark and the accept screen start it. Somebody's burning charcoal in the Hollow, deep under the oaks. Three clamps, and nobody tending them. The wood smells it. The hollowed come to it like it's a hearth. Go and see. Thin them on the way.

The hand-in pays 15 grave ash, 1 relic_fragment.

Step 1, a visit. The line is "Find the Charcoal Hollow deep in the Thornwood". The label is The Charcoal Hollow. The radius is 20 m. The map point is (-86.0, -62.0).

Step 2, a slay. The line is "Put down the hollowed in the Thornwood ({n}/{of})". It wants 4. The count is kept in `thornwood`. The label is Hollowed in the Thornwood. The map point is (-84.0, -30.0).

Step 3, a turnin. The line is "Tell Wyck what burns in the Hollow". The person is Wyck.

The ending line: Nobody tends the clamps in the Hollow. They burn anyway. Wyck says that's worse.

### What the Oaks Keep

Giver Wyck, Wyck, at his fire in the Thornwood. The journal files it under The Thornwood. It is offered when qd:thorn_door. The giver's mark and the accept screen start it. The Thornwarden roots in a heart. Cut it out and the wood forgets it was ever kept. I won't say do it. I won't say don't. Bring me a thorn off it, after. I'll bury it face down.

The hand-in pays 25 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the kindler set; a Hallowed Lantern Glass of the kindler set; a Hallowed Vestment of the kindler set.

Step 1, a cond. The line is "Cut the Thorn Heart from the Thornwarden in the Ring". The condition is `boss:thornwarden`. The label is The Thornwarden. The map point is (-72.0, -18.0).

Step 2, a turnin. The line is "Bring a thorn to Wyck". The person is Wyck.

The ending line: Wyck buried the thorn face down by his fire, and sang the verse the abbey chiselled off.

### The Toll Unpaid

Giver Hesk, Hesk the Woodcutter, at the Keg. The journal files it under The Thornwood. The giver's mark and the accept screen start it. Tollmen. Ride with the war bands, ring a bell, and the whole wood comes running. One of 'em had my brother's axe. Put two of 'em down before they ring. Then I'll drink easier.

The hand-in pays 12 grave ash.

The hand-in also offers one of: a Kindled Girdle; a Kindled Orb Focus.

Step 1, a slay. The line is "Put down tollmen riding with the war bands ({n}/{of})". It wants 2. The kinds are tollman. The label is Tollmen. The map point is (-92.0, -30.0).

Step 2, a turnin. The line is "Tell Hesk the tolls are unpaid". The person is Hesk.

The ending line: Hesk drank to his brother, twice. The second was for the axe.

### The Lay Brothers' Beads

Giver Abel the sexton, Abel the sexton, by the Kindlers' Yard. The journal files it under The Hollow Fen. It is offered when met:abel. The giver's mark and the accept screen start it. The bone-walkers in the fen are the lay brothers, still counting. They carry their tally-beads on them. Bring me the beads and the count stops. I'll lay them flat. The beads, I mean. Them too.

The hand-in pays 12 grave ash.

The hand-in also offers one of: a Kindled Vestment of the tally set; a Kindled Girdle of the tally set; a Kindled Lantern Glass of the tally set.

Step 1, a collect. The line is "Take tally-beads from the bone-walkers of the fen and the Barrow Field ({n}/{of})". It wants 4. Each qualifying kill drops it with chance 0.75. The kinds are ossuant. The label is Tally-beads. The map point is (96.0, -30.0).

Step 2, a turnin. The line is "Bring the tally-beads to Abel". The person is Abel the sexton.

The ending line: Abel buried the beads loose, so nobody can count them again.

### The Drowned Bell

Giver Brannoc, Brannoc Bellwright, at the Keg. The journal files it under The Hollow Fen. The giver's mark and the accept screen start it. My grandfather cast the bell in the fen tower. It rang for the sunk. When the water came up it rang by itself for a week. Then it stopped. Go and bring me its tongue. A bell that can't ring can't be made to.

The hand-in pays 14 grave ash.

The hand-in also offers one of: a Kindled Orb Focus of the bell set; a Kindled Vestment of the bell set; a Kindled Girdle of the bell set.

Step 1, a visit. The line is "Wade out to the Drowned Belfry in the Hollow Fen". The label is The Drowned Belfry. The radius is 14 m. The map point is (82.0, -18.0).

Step 2, a find. The line is "Take the bell's iron tongue from the belfry".

Step 3, a turnin. The line is "Bring the bell's tongue to Brannoc". The person is Brannoc.

The ending line: Brannoc hung the drowned bell's tongue over the Keg's door. It doesn't ring. He checks.

### The Count Below

Giver Abel the sexton, Abel the sexton, by the Kindlers' Yard. The journal files it under The Ossuary. It is offered when qd:bead_count. The giver's mark and the accept screen start it. The Abbot's still down there counting. Every one of them a number. Break the gallery seal, go down to his mound and stop him. Then the dead can lie down without being told how many they are.

The hand-in pays 25 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the tally set; a Hallowed Vestment of the tally set; a Hallowed Girdle of the tally set.

Step 1, a seal. The line is "Break the gallery seal in the Ossuary ({n}/{of})". The seal is `oss_gallery`. The label is Gallery seal guards. The map point is (34.0, -66.0).

Step 2, a cond. The line is "Stop the Bone Abbot's count on the charnel floor". The condition is `boss:bone_abbot`. The label is The Bone Abbot. The map point is (17.0, -80.0).

Step 3, a turnin. The line is "Tell Abel the count has stopped". The person is Abel the sexton.

The ending line: Abel dug all night and didn't count once.

### The Ward on the Crossing

Giver The keep, The keep of the Kindled Keg. The journal files it under The Summit of Ascension. It is offered when boss:thornwarden,boss:bone_abbot,qd:founders_peal. The giver's mark and the accept screen start it. Heart and crown, and a peal behind you. The ward on the Crossing will know them. It has guards that don't sleep; put them down and it lets you through. Then the top. I'll keep your stool warm. Come back and sit on it.

The hand-in pays 40 grave ash.

The hand-in also offers one of: a  ; a  ; a  .

Step 1, a seal. The line is "Put down the guards of the summit ward on the Crossing ({n}/{of})". The seal is `summit`. The label is Crossing guards. The map point is (0.0, -70.9).

Step 2, a cond. The line is "Face what holds the door at the summit". The condition is `boss:ascended_warden`. The label is The Ascended Warden. The map point is (0.0, -103.9).

Step 3, a turnin. The line is "Sit on your stool at the Kindled Keg". The person is The keep.

The ending line: The keep poured, and didn't say anything for a long time. Then he said: kindled.

### The Kin-Taker

Giver Gammer Ruan, Gammer Ruan, at her fire in the Rooted Holds. The journal files it under The Rooted Holds. The giver's mark and the accept screen start it. Something walks round the Holds at night, tall as a door, and lifts the turf off the roofs to look in at us. The young ones named it Old Rook, when there were young ones. It took them. Put it down, and I'll sleep with the door open for once.

The hand-in pays 14 grave ash.

The hand-in also offers one of: a Kindled Vestment; a Kindled Girdle.

Step 1, a slay. The line is "Put down Old Rook, the Kin-Taker, on its round of the Holds". It wants 1. The label is Old Rook, the Kin-Taker. The rares are old_rook. The map point is (-140.0, 11.0).

Step 2, a turnin. The line is "Tell Gammer Ruan the Kin-Taker is down". The person is Gammer Ruan.

The ending line: Ruan slept with her door open. In the morning she turned the empty beds face down again, one by one.

### The Keeper's Wards

Giver Gammer Ruan, Gammer Ruan, at her fire in the Rooted Holds. The journal files it under The Rooted Holds. It belongs to the thornwarden attunement. The 30-minute slice hides it. The giver's mark and the accept screen start it. We bound the keeper into the Ring with three ward-stones, one for each way the axe could come. The abbey dug them up and threw them in the wood. While they lie loose it keeps the Ring with all its strength, like a dog with no master. Bring them to my hand.

The hand-in pays 15 grave ash, 1 relic_fragment.

Step 1, a gather. The line is "Find the three ward-stones: in the Holds, under the Thornwood's oaks, in the Glimmer Glade ({n}/{of})". It wants 3.

Step 2, a turnin. The line is "Bring the ward-stones to Gammer Ruan". The person is Gammer Ruan.

The ending line: Ruan set the three wards round her fire, face down, and sang the keeper's verse to them. Not the last verse.

### Heartwood

Giver Gammer Ruan, Gammer Ruan, at her fire in the Rooted Holds. The journal files it under The Rooted Holds. It belongs to the thornwarden attunement. The 30-minute slice hides it. It is offered when qd:keeper_wards. The giver's mark and the accept screen start it. The keeper roots in a heart and feeds the wood from it. The things under the oaks are fat on it. Bring me splinters off them: heartwood, black and warm to hold. I'll burn it in the ward-fire, and the keeper will smell itself in the smoke.

The hand-in pays 15 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus; a Hallowed Lantern Glass.

Step 1, a collect. The line is "Take heartwood splinters from the hollowed under the Thornwood's oaks ({n}/{of})". It wants 5. Each qualifying kill drops it with chance 0.6. The count is kept in `thornwood`. The label is Heartwood splinters. The map point is (-100.0, -40.0).

Step 2, a turnin. The line is "Bring the heartwood to Gammer Ruan". The person is Gammer Ruan.

The ending line: The heartwood burned green in Ruan's fire. The oaks to the east went quiet while it did.

### Keeper, Keep

Giver Gammer Ruan, Gammer Ruan, at her fire in the Rooted Holds. The journal files it under The Rooted Holds. It belongs to the thornwarden attunement. The 30-minute slice hides it. It is offered when qd:keeper_heart. The giver's mark and the accept screen start it. Take a coal from my fire, lit with its own heartwood, up the Ring's stair before it dies. Lay it at the head of the stair. It will know us by it. When you go in to it after, it will fight you with one hand behind its back. Not out of kindness. Out of manners.

The hand-in pays 20 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the kindler set; a Hallowed Vestment; a Hallowed Girdle.

Step 1, a find. The line is "Take a ward-coal from Gammer Ruan's fire".

Step 2, a carry. The line is "Carry the ward-coal to the head of the Ring's stair before it dies ({t} s)". The label is Ward-coal. The radius is 6 m. The coal has 150 s, and the line's {t} is the seconds left, rounded up. The delivery point is (-57.0, -17.0).

Step 3, a turnin. The line is "Tell Gammer Ruan the keeper has its coal". The person is Gammer Ruan.

The ending line: The keeper took the coal. In the Ring it will remember it was asked, not owned: it holds back a hand.

### Masons' Marks

Giver Jory Quell, Jory Quell, at his fire by the Saints' Quarry. The journal files it under The Saints' Quarry. The giver's mark and the accept screen start it. Every cutter cut his mark on the blocks he squared, so the Order could pay him by the stone. They stopped paying on the Night. The marks are still on the blocks nobody carried. Bring me three. I'll know the men by them.

The hand-in pays 14 grave ash.

The hand-in also offers one of: a Kindled Orb Focus; a Kindled Girdle.

Step 1, a gather. The line is "Take the masons' marks off the abandoned blocks in the quarry ({n}/{of})". It wants 3.

Step 2, a turnin. The line is "Bring the marks to Jory Quell". The person is Jory Quell.

The ending line: Jory read the marks with his thumb. Wat, Dunny, his own brother. He said the names, and then the wages owed.

### Picks Put Down

Giver Jory Quell, Jory Quell, at his fire by the Saints' Quarry. The journal files it under The Saints' Quarry. It is offered when qd:quarry_marks. The giver's mark and the accept screen start it. The ones who went up came back down to work. They swing at the benches in the dark, cutting steps for a stair that isn't there any more. Put the picks down. Six of them. They've earned the rest.

The hand-in pays 16 grave ash, 1 relic_fragment.

Step 1, a slay. The line is "Put down the hollowed cutters on the quarry's benches ({n}/{of})". It wants 6. The count is kept in `quarry`. The label is Cutters on the benches. The map point is (-126.0, -100.0).

Step 2, a turnin. The line is "Tell Jory Quell the picks are down". The person is Jory Quell.

The ending line: The benches are quiet. Jory says he can hear the stone settle, now nobody's cutting it.

### The Last Step

Giver Jory Quell, Jory Quell, at his fire by the Saints' Quarry. The journal files it under The Saints' Quarry. It is offered when qd:quarry_picks. The giver's mark and the accept screen start it. One block the Order blessed and never sent: the four thousand and first step. It sits on the pit floor with a prayer cut in the top. Go down and read it to me. My eyes won't do the benches, and I want to know what they wrote on the step after the last one.

The hand-in pays 18 grave ash.

The hand-in also offers one of: a Hallowed Vestment; a Hallowed Lantern Glass.

Step 1, a visit. The line is "Climb down the benches to the quarry's pit floor". The label is The pit floor. The radius is 10 m. The map point is (-128.0, -104.0).

Step 2, a find. The line is "Read the blessed block on the pit floor".

Step 3, a turnin. The line is "Tell Jory Quell what the last step says". The person is Jory Quell.

The ending line: "Here the faithful step off." Jory laughed till he coughed. Then he asked you to say it again.

### The Four-Thousandth

Giver Jory Quell, Jory Quell, at his fire by the Saints' Quarry. The journal files it under The Saints' Quarry. It is offered when qd:quarry_picks. The giver's mark and the accept screen start it. Brother Chisel blessed every step we cut. Four thousand blessings, and he counted them. He came back down with the cutters and he's still at it, on the pit floor, bigger than he was, blessing stone with his fists. He was a kind man. Put him down kindly. Hard, I mean.

The hand-in pays 18 grave ash, 1 relic_fragment.

The hand-in also offers one of: a Hallowed Orb Focus; a Hallowed Girdle.

Step 1, a slay. The line is "Put down Brother Chisel, the Four-Thousandth, on the quarry's floor". It wants 1. The label is Brother Chisel. The rares are brother_chisel. The map point is (-136.0, -112.0).

Step 2, a turnin. The line is "Tell Jory Quell the blessing is done". The person is Jory Quell.

The ending line: Jory cut a small step for Brother Chisel and set it at the pit's mouth. Nobody is to bless it.

### The Cutters' Due

Giver Jory Quell, Jory Quell, at his fire by the Saints' Quarry. The journal files it under The Saints' Quarry. It repeats daily. The 30-minute slice hides it. It is offered when qd:quarry_marks. The giver's mark and the accept screen start it. Nobody pays by the stone now. I pay by the hollowed. Thin the benches and I'll find you something off the shelf. Every night, if you like. They never stop coming down.

The hand-in pays 10 grave ash, 1 ember_shard.

Step 1, a slay. The line is "Put down the hollowed in the Saints' Quarry ({n}/{of})". It wants 5. The count is kept in `quarry`. The label is Hollowed in the quarry. The map point is (-126.0, -100.0).

Step 2, a turnin. The line is "Collect the cutters' due from Jory Quell". The person is Jory Quell.

The ending line: Jory paid you in ember, by the stone, and wrote it in a book nobody keeps.

### Cairns in the Dark

Giver Ysolt the cairn-keeper, Ysolt, at her fire under the tor. The journal files it under The Lanternless Moor. The giver's mark and the accept screen start it. The faithful crossed this moor without lanterns, by the cairns. The edict said lanterns were for doubters. The wind takes a stone a night off every cairn. Three are down to nothing. Raise them, so the next fool in the dark finds his way.

The hand-in pays 14 grave ash.

The hand-in also offers one of: a Kindled Lantern Glass; a Kindled Girdle.

Step 1, a gather. The line is "Raise the three fallen cairns on the moor ({n}/{of})". It wants 3.

Step 2, a turnin. The line is "Tell Ysolt the cairns are standing". The person is Ysolt the cairn-keeper.

The ending line: Ysolt walked out to each cairn in the dark and counted the stones with her hands. She added one.

### The Ones Who Stumbled

Giver Ysolt the cairn-keeper, Ysolt, at her fire under the tor. The journal files it under The Lanternless Moor. It is offered when qd:moor_cairns. The giver's mark and the accept screen start it. The moor kept the ones who fell between the cairns. They still walk it, looking for the next one. They walk into people. Put six of them down, and leave the cairns alone; they'll want them.

The hand-in pays 15 grave ash, 1 relic_fragment.

Step 1, a slay. The line is "Put down the hollowed walking the Lanternless Moor ({n}/{of})". It wants 6. The count is kept in `moor`. The label is The stumbled. The map point is (142.0, -24.0).

Step 2, a turnin. The line is "Tell Ysolt the moor is quieter". The person is Ysolt the cairn-keeper.

The ending line: Ysolt says the wind sounds different with fewer feet in it.

### No Lantern

Giver Ysolt the cairn-keeper, Ysolt, at her fire under the tor. The journal files it under The Lanternless Moor. It is offered when qd:moor_stumbled. The giver's mark and the accept screen start it. There's a shrine on the south moor the Order raised for the first edict. Lanterns are for doubters, it says. Carry a coal there from my fire and set it in the shrine's lap. I've been a doubter forty years. I'd like it said in stone.

The hand-in pays 18 grave ash.

The hand-in also offers one of: a Hallowed Lantern Glass; a Hallowed Orb Focus.

Step 1, a find. The line is "Take a coal from Ysolt's fire".

Step 2, a carry. The line is "Carry the coal to the lanternless shrine on the south moor before it dies ({t} s)". The label is Coal. The radius is 5 m. The coal has 75 s, and the line's {t} is the seconds left, rounded up. The delivery point is (142.5, 16.0).

Step 3, a turnin. The line is "Tell Ysolt the shrine has a light in its lap". The person is Ysolt the cairn-keeper.

The ending line: A coal burns in the lap of the first edict's shrine. From the tor it is the only light on the moor.

### The Gorse-Wife

Giver Ysolt the cairn-keeper, Ysolt, at her fire under the tor. The journal files it under The Lanternless Moor. It is offered when qd:moor_stumbled. The giver's mark and the accept screen start it. Hennet kept the gorse fire on the tor, before the edict. They put it out and her with it. She walks the whole moor now, north to south and back, faster than the wind. She's the one kicking the cairns down. Stop her. I'll raise her a cairn after.

The hand-in pays 16 grave ash, 1 relic_fragment.

The hand-in also offers one of: a Hallowed Lantern Glass; a Hallowed Vestment.

Step 1, a slay. The line is "Put down Gorse-Wife Hennet on her walk across the moor". It wants 1. The label is Gorse-Wife Hennet. The rares are hennet. The map point is (140.0, -4.0).

Step 2, a turnin. The line is "Tell Ysolt the Gorse-Wife is down". The person is Ysolt the cairn-keeper.

The ending line: Ysolt raised a cairn for Hennet under the tor, and put a sprig of gorse on top. It is the only cairn that points nowhere.

### Wind Off the Moor

Giver Ysolt the cairn-keeper, Ysolt, at her fire under the tor. The journal files it under The Lanternless Moor. It repeats daily. The 30-minute slice hides it. It is offered when qd:moor_cairns. The giver's mark and the accept screen start it. The wind takes the stones. Bring me stones. The hollowed carry them in their fists, God knows why. Four. Every night; the wind doesn't rest and neither do I.

The hand-in pays 10 grave ash, 1 ember_shard.

Step 1, a collect. The line is "Take cairn-stones from the hollowed on the moor ({n}/{of})". It wants 4. Each qualifying kill drops it with chance 0.6. The count is kept in `moor`. The label is Cairn-stones. The map point is (142.0, -24.0).

Step 2, a turnin. The line is "Bring the cairn-stones to Ysolt". The person is Ysolt the cairn-keeper.

The ending line: The cairns stand another night.

### Cold Slag

Giver Elspeth Fane, Elspeth Fane, at her fire in the Founder's Pits. The journal files it under The Founder's Pits. The giver's mark and the accept screen start it. Something sleeps in the slag heaps, where the ground's still warm. Hollowed, curled up like dogs at a hearth. I'd like the heaps back. I'd like to stop hearing them breathe in there.

The hand-in pays 14 grave ash.

The hand-in also offers one of: a Kindled Girdle of the bell set; a Kindled Lantern Glass of the bell set.

Step 1, a slay. The line is "Put down the hollowed sleeping in the Founder's slag heaps ({n}/{of})". It wants 5. The count is kept in `foundry`. The label is Hollowed in the slag. The map point is (140.0, -92.0).

Step 2, a turnin. The line is "Tell Elspeth Fane the heaps are quiet". The person is Elspeth Fane.

The ending line: Elspeth sat on the warm slag and ate her bread, which she says she hasn't done since the Night.

### The Bell-Tongue

Giver Elspeth Fane, Elspeth Fane, at her fire in the Founder's Pits. The journal files it under The Founder's Pits. It is offered when qd:founder_slag. The giver's mark and the accept screen start it. Something walks the pits ringing. A cinder-thing with a bell's tongue where its head should be. It was the Founder's striker, the boy who rang the test notes. It still rings them, wrong, every one. Make it stop. I can't hear myself cast.

The hand-in pays 16 grave ash, 1 relic_fragment.

The hand-in also offers one of: a Kindled Orb Focus of the bell set; a Kindled Vestment of the bell set.

Step 1, a slay. The line is "Put down Clapper, the Bell-Tongue, in the Founder's Pits". It wants 1. The label is Clapper, the Bell-Tongue. The rares are clapper. The map point is (124.0, -96.0).

Step 2, a turnin. The line is "Tell Elspeth Fane the pits are quiet". The person is Elspeth Fane.

The ending line: Elspeth struck the cooling furnace once with a hammer, the right note, for the striker. Then she went back to work.

### The Founder's Moulds

Giver Elspeth Fane, Elspeth Fane, at her fire in the Founder's Pits. The journal files it under The Founder's Pits. It belongs to the ascended_warden attunement. The 30-minute slice hides it. The giver's mark and the accept screen start it. She cast the summit's bell in three cheeks of loam and iron. The Hierarch's bell. Brannoc says the thing up there holds the door with it still in its hand. Bring me the moulds. A bell's mould knows its note, and I can teach it a wrong one.

The hand-in pays 15 grave ash, 1 relic_fragment.

Step 1, a gather. The line is "Find the three cheeks of the great bell's mould: by the furnace, in the casting pits, under the slag ({n}/{of})". It wants 3.

Step 2, a turnin. The line is "Bring the mould to Elspeth Fane". The person is Elspeth Fane.

The ending line: Elspeth fitted the cheeks together on the furnace floor. The mould hummed when the wind crossed it.

### Mother's Order

Giver Elspeth Fane, Elspeth Fane, at her fire in the Founder's Pits. The journal files it under The Founder's Pits. It belongs to the ascended_warden attunement. The 30-minute slice hides it. It is offered when qd:founder_moulds. The giver's mark and the accept screen start it. The rim bells fell when the Stair broke. Ring them where they lie, the way she taught: the great bell first, Homecoming, then Patience, then Hope. Bottom to top. Then take the tongue I've cast in her mould, out of the furnace, to her son at the Keg. He'll know what it's for. It's for the door.

The hand-in pays 25 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the bell set; a Hallowed Vestment of the bell set; a Hallowed Lantern Glass of the bell set.

Step 1, a cond. The line is "Ring the fallen bells by the Rift in the Founder's order: Homecoming, Patience, Hope". The condition is `secret:solved:bells`. The label is The Fallen Bells. The map point is (-37.6, -27.0).

Step 2, a find. The line is "Take the bell-tongue Elspeth cast, from the Founder's furnace".

Step 3, a turnin. The line is "Bring the warm tongue to Brannoc Bellwright at the Kindled Keg". The person is Brannoc.

The ending line: Brannoc hung the warm tongue in the Keg's chimney. Up at the summit, the great bell in the Warden's hand will ring wrong, Mother's way.

### A Living Bud

Giver Linnet the grafter, Linnet, at her fire in the Cinder Orchard. The journal files it under The Cinder Orchard. The giver's mark and the accept screen start it. They burned it so the Kindlers would have nothing. Burned wood still has a living eye in it sometimes, under the char. Find me three green buds. I'll graft them on a stock and see what grows from a heresy.

The hand-in pays 12 grave ash.

The hand-in also offers one of: a Kindled Girdle of the kindler set; a Kindled Lantern Glass of the kindler set.

Step 1, a gather. The line is "Find three living buds on the burned trees of the Cinder Orchard ({n}/{of})". It wants 3.

Step 2, a turnin. The line is "Bring the buds to Linnet". The person is Linnet the grafter.

The ending line: Linnet bound the buds into a stock with wax and wool. One of them is already greener.

### The Press-House

Giver Linnet the grafter, Linnet, at her fire in the Cinder Orchard. The journal files it under The Cinder Orchard. It is offered when qd:orchard_buds. The giver's mark and the accept screen start it. The press-house at the west end. The brothers pressed the fruit there and gave the road its cider. Something lives in it now, and it isn't cider. Go and look. Thin them on the way.

The hand-in pays 15 grave ash, 1 relic_fragment.

Step 1, a visit. The line is "Find the press-house at the orchard's west end". The label is The press-house. The radius is 12 m. The map point is (-128.0, 132.0).

Step 2, a slay. The line is "Put down the hollowed in the burned rows ({n}/{of})". It wants 5. The count is kept in `orchard`. The label is Hollowed in the rows. The map point is (-120.0, 122.0).

Step 3, a turnin. The line is "Tell Linnet what lives in the press-house". The person is Linnet the grafter.

The ending line: Nothing lives in the press-house now. Linnet says she'll press something in it next autumn, if there is one.

### Fire Under the Roots

Giver Linnet the grafter, Linnet, at her fire in the Cinder Orchard. The journal files it under The Cinder Orchard. It is offered when qd:orchard_press. The giver's mark and the accept screen start it. A graft takes if the stock is warm. Nothing in this orchard's been warm since they burned it. Carry a coal from my fire to the heart of the rows and lay it under the old tree. It's the Kindlers' fire. The orchard was always theirs.

The hand-in pays 18 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the kindler set; a Hallowed Vestment of the kindler set; a Hallowed Lantern Glass of the kindler set.

Step 1, a find. The line is "Take a coal from Linnet's fire".

Step 2, a carry. The line is "Carry the coal to the old tree at the heart of the rows before it dies ({t} s)". The label is Coal. The radius is 5.5 m. The coal has 70 s, and the line's {t} is the seconds left, rounded up. The delivery point is (-84.5, 117.5).

Step 3, a turnin. The line is "Tell Linnet the old tree is warm". The person is Linnet the grafter.

The ending line: A coal sleeps under the old tree at the heart of the rows. Linnet swears the bark split green by morning.

### The Ash-Grub

Giver Linnet the grafter, Linnet, at her fire in the Cinder Orchard. The journal files it under The Cinder Orchard. It is offered when qd:orchard_press. The giver's mark and the accept screen start it. Something under the rows eats roots. Big as a barrel, and it's had nine winters of nothing but ash to grow fat on. The brothers called the old tree Pippin. I think that's what's left of whoever slept under it. Dig it out.

The hand-in pays 16 grave ash, 1 relic_fragment.

The hand-in also offers one of: a Hallowed Girdle of the kindler set; a Hallowed Orb Focus.

Step 1, a slay. The line is "Put down Old Pippin, the Ash-Grub, under the burned rows". It wants 1. The label is Old Pippin, the Ash-Grub. The rares are old_pippin. The map point is (-96.0, 140.0).

Step 2, a turnin. The line is "Tell Linnet the roots are safe". The person is Linnet the grafter.

The ending line: Linnet planted a seed where the Ash-Grub came up. She says that's the only grave an orchard needs.

### Ash for the Roots

Giver Linnet the grafter, Linnet, at her fire in the Cinder Orchard. The journal files it under The Cinder Orchard. It repeats daily. The 30-minute slice hides it. It is offered when qd:orchard_buds. The giver's mark and the accept screen start it. Ash feeds a root. Ash off the hollowed feeds it hot. Five handfuls from the rows, every night you're passing. It's slow work, an orchard.

The hand-in pays 10 grave ash, 1 ember_shard.

Step 1, a collect. The line is "Gather ash from the hollowed in the Cinder Orchard ({n}/{of})". It wants 5. Each qualifying kill drops it with chance 0.6. The count is kept in `orchard`. The label is Root ash. The map point is (-110.0, 122.0).

Step 2, a turnin. The line is "Bring the root ash to Linnet". The person is Linnet the grafter.

The ending line: Linnet dug the ash in round the grafts with her hands.

### Facing the Mountain

Giver Sister Agathe, Sister Agathe, at the gate of the Waiting Field. The journal files it under The Waiting Field. The giver's mark and the accept screen start it. They're buried facing the Stair, so they'd be first through when the sky called. Something walks the ranks at night and the stones are turning. I turn them back. My back is not what it was. Put the walkers down.

The hand-in pays 14 grave ash.

The hand-in also offers one of: a Kindled Vestment; a Kindled Lantern Glass.

Step 1, a visit. The line is "Walk the pilgrims' ranks in the Waiting Field". The label is The pilgrims' ranks. The radius is 12 m. The map point is (-18.0, 114.0).

Step 2, a slay. The line is "Put down the hollowed walking the Waiting Field ({n}/{of})". It wants 5. The count is kept in `necropolis`. The label is Walkers in the ranks. The map point is (-10.0, 130.0).

Step 3, a turnin. The line is "Tell Sister Agathe the ranks are still". The person is Sister Agathe.

The ending line: Agathe walked the ranks with you after, and turned three stones back to face the mountain. Then, after a while, one away from it.

### The Last Pilgrim

Giver Sister Agathe, Sister Agathe, at the gate of the Waiting Field. The journal files it under The Waiting Field. It is offered when qd:field_ranks. The giver's mark and the accept screen start it. The last pilgrim who died on the road before the Night is buried at the end of the ranks. He got up. He walks the field looking for the gate to the Stair, and he won't believe there isn't one. Put him back in his row. He was always last; let him be first to lie down.

The hand-in pays 16 grave ash, 1 relic_fragment.

The hand-in also offers one of: a Hallowed Orb Focus; a Hallowed Vestment.

Step 1, a slay. The line is "Put the Last Pilgrim back in his rank in the Waiting Field". It wants 1. The label is The Last Pilgrim. The rares are last_pilgrim. The map point is (-12.0, 140.0).

Step 2, a turnin. The line is "Tell Sister Agathe the last of them is lying down". The person is Sister Agathe.

The ending line: Agathe turned the Last Pilgrim's stone to face the village. 'He's seen the mountain,' she said.

### The Pilgrims' Roll

Giver Sister Agathe, Sister Agathe, at the gate of the Waiting Field. The journal files it under The Waiting Field. It belongs to the bone_abbot attunement. The 30-minute slice hides it. The giver's mark and the accept screen start it. Every pilgrim buried here was written in the roll, by name. The Abbot took the books and wrote numbers over them. Three pages got away from him. Find them. A name read aloud at the door of the count is the one thing he can't add up.

The hand-in pays 15 grave ash, 1 relic_fragment.

Step 1, a gather. The line is "Find the three pages of the pilgrims' roll: by the mausoleum, in the ranks, at the lay brothers' lodge in the Barrow Field ({n}/{of})". It wants 3.

Step 2, a turnin. The line is "Bring the roll's pages to Sister Agathe". The person is Sister Agathe.

The ending line: Agathe sewed the three pages together with a hair from her own head. 'Names,' she said. 'Not one number.'

### Cut the Count

Giver Sister Agathe, Sister Agathe, at the gate of the Waiting Field. The journal files it under The Waiting Field. It belongs to the bone_abbot attunement. The 30-minute slice hides it. It is offered when qd:abbot_roll. The giver's mark and the accept screen start it. His bone-walkers carry the count on knotted cords. Every knot is somebody. Cut me four cords off them and the count goes slack. He'll feel it down there, a stitch dropped.

The hand-in pays 15 grave ash.

The hand-in also offers one of: a Hallowed Vestment of the tally set; a Hallowed Girdle of the tally set.

Step 1, a collect. The line is "Cut tally-cords from the bone-walkers of the fen and the Barrow Field ({n}/{of})". It wants 4. Each qualifying kill drops it with chance 0.75. The kinds are ossuant. The label is Tally-cords. The map point is (96.0, -30.0).

Step 2, a turnin. The line is "Bring the tally-cords to Sister Agathe". The person is Sister Agathe.

The ending line: Agathe unpicked every knot, and named nobody. Some things you only undo.

### Called by Name

Giver Sister Agathe, Sister Agathe, at the gate of the Waiting Field. The journal files it under The Waiting Field. It belongs to the bone_abbot attunement. The 30-minute slice hides it. It is offered when qd:abbot_cords. The giver's mark and the accept screen start it. Take the roll down to the Ossuary's fen door and read it, all of it, into the dark. Then he goes to his count and finds it short. A counter who comes up short begins to doubt. A doubting Abbot is half an Abbot.

The hand-in pays 25 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the tally set; a Hallowed Lantern Glass of the tally set; a Hallowed Girdle.

Step 1, a visit. The line is "Read the pilgrims' roll aloud at the Ossuary's fen door". The label is The Ossuary's fen door. The radius is 10 m. The map point is (48.0, -60.0).

Step 2, a turnin. The line is "Tell Sister Agathe the names were read". The person is Sister Agathe.

The ending line: Under the abbey the count stopped, and started again from one, and stopped. The Abbot doubts.

### Corvin's Lamps

Giver Cadoc the ferryman, Cadoc the ferryman, on the mere's north bank. The journal files it under Corvin's Mere. The giver's mark and the accept screen start it. Brother Corvin rowed fire out to the sunk dead, so they'd not lie in the dark. His lamps drift in to the banks now, cold. Bring me three. I'll fill them and row them back out. Somebody has to; he's got no hands.

The hand-in pays 12 grave ash.

The hand-in also offers one of: a Kindled Lantern Glass of the ferryman set; a Kindled Girdle of the ferryman set.

Step 1, a gather. The line is "Find three of Corvin's lamps drifted onto the mere's banks ({n}/{of})". It wants 3.

Step 2, a turnin. The line is "Bring the lamps to Cadoc the ferryman". The person is Cadoc the ferryman.

The ending line: Cadoc filled the lamps from his own oil and set them on the water. They went out toward the chapel without being pushed.

### The Half-Sunk Chapel

Giver Cadoc the ferryman, Cadoc the ferryman, on the mere's north bank. The journal files it under Corvin's Mere. It is offered when qd:mere_lamps. The giver's mark and the accept screen start it. Corvin's chapel is half under now. The things in the water go there to stand in the nave, like a congregation waiting for a sermon. Wade out. Thin the flock.

The hand-in pays 15 grave ash, 1 relic_fragment.

Step 1, a visit. The line is "Wade out to the half-sunk chapel in the west mere". The label is The half-sunk chapel. The radius is 14 m. The map point is (80.0, 112.0).

Step 2, a slay. The line is "Put down the hollowed in Corvin's Mere ({n}/{of})". It wants 5. The count is kept in `mere`. The label is The drowned flock. The map point is (100.0, 124.0).

Step 3, a turnin. The line is "Tell Cadoc the nave is empty". The person is Cadoc the ferryman.

The ending line: The chapel's nave stands empty to the knee in black water. Cadoc says Corvin preached to fish in the end, and the fish listened.

### Light for the Sunk

Giver Cadoc the ferryman, Cadoc the ferryman, on the mere's north bank. The journal files it under Corvin's Mere. It is offered when qd:mere_chapel. The giver's mark and the accept screen start it. Corvin's rite: a light for the eyes, the mouth, the heart. The Abbot's three stones were the other answer. Carry a lit lamp from my fire to the chapel before it gutters. That's all he ever did. It was enough to have his hands taken for.

The hand-in pays 20 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the ferryman set; a Hallowed Vestment of the ferryman set; a Hallowed Lantern Glass of the ferryman set.

Step 1, a find. The line is "Take a lit lamp from Cadoc's fire".

Step 2, a carry. The line is "Carry the lamp to the half-sunk chapel before it gutters ({t} s)". The label is Corvin's lamp. The radius is 7 m. The coal has 90 s, and the line's {t} is the seconds left, rounded up. The delivery point is (79.5, 112.0).

Step 3, a turnin. The line is "Tell Cadoc the chapel has its light". The person is Cadoc the ferryman.

The ending line: A lamp burns in the half-sunk chapel, for the eyes, the mouth, the heart. Cadoc rows past it every night and doesn't look.

### The Other Oar

Giver Cadoc the ferryman, Cadoc the ferryman, on the mere's north bank. The journal files it under Corvin's Mere. It is offered when qd:mere_chapel. The giver's mark and the accept screen start it. Two of us rowed for Corvin. Me and Amos. The night they took Corvin's hands, Amos rowed out alone with the lamps and went over. He walks the banks now without his boat, waiting to be paid. I owe him the fare. Pay it for me.

The hand-in pays 18 grave ash, 1 relic_fragment.

The hand-in also offers one of: a Hallowed Girdle of the ferryman set; a Hallowed Orb Focus of the ferryman set.

Step 1, a slay. The line is "Put down the Ferryman Without a Boat on the mere's east bank". It wants 1. The label is The Ferryman Without a Boat. The rares are ferryman. The map point is (140.0, 128.0).

Step 2, a turnin. The line is "Tell Cadoc the fare is paid". The person is Cadoc the ferryman.

The ending line: Cadoc put two coins on the water by the east bank. They didn't sink straight away.

### Oil for the Lamps

Giver Cadoc the ferryman, Cadoc the ferryman, on the mere's north bank. The journal files it under Corvin's Mere. It repeats daily. The 30-minute slice hides it. It is offered when qd:mere_lamps. The giver's mark and the accept screen start it. The lamps drink oil like the drowned drink dark. The hollowed in the mere carry it in their bellies, from the lamps they ate. Five. Every night. The mere is long.

The hand-in pays 10 grave ash, 1 ember_shard.

Step 1, a collect. The line is "Take lamp-oil from the hollowed in Corvin's Mere ({n}/{of})". It wants 5. Each qualifying kill drops it with chance 0.6. The count is kept in `mere`. The label is Lamp-oil. The map point is (100.0, 124.0).

Step 2, a turnin. The line is "Bring the oil to Cadoc the ferryman". The person is Cadoc the ferryman.

The ending line: Corvin's lamps burn on the mere another night.

### The Founder's Peal

Giver Brannoc, Brannoc Bellwright, at the Keg. The journal files it under The Summit of Ascension. It is offered when boss:thornwarden,boss:bone_abbot. The giver's mark and the accept screen start it. Mother cast seven for the road up. One for each country the pilgrims crossed. When the sky opened they went quiet, top first. The door at the summit hangs from a bell; it won't open to a heart and a crown alone. It opens to a peal. Find me four. Seven, if you've the legs.

The hand-in pays 30 grave ash, 2 ember_shard, the spell peal.

The hand-in also offers one of: a Reliquary Orb Focus of the bell set; a Reliquary Vestment of the bell set; a Reliquary Girdle of the bell set.

Step 1, a cond. The line is "Answer for the Founder's bells ({bells} of 7; four wake the door)". The condition is `bells:4`.

Step 2, a turnin. The line is "Tell Brannoc the door will hear a peal". The person is Brannoc.

The ending line: Brannoc counted the bells on his fingers twice, the second time slower. "She'd have liked you," he said. "She liked people who finished things."

### The Kin Bell

Giver Gammer Ruan, Gammer Ruan, at her fire in the Rooted Holds. The journal files it under The Rooted Holds. It is offered when qd:keeper_leave,q:founders_peal. The giver's mark and the accept screen start it. There's a bell in the Holds the Rooted never asked for. The Founder hung it in our oak anyway, to call the kin home at dusk. Something rings it at night now. With its hands. Put it down. Then decide what the bell's for.

The hand-in pays 30 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus; a Hallowed Vestment; a Hallowed Lantern Glass.

Step 1, a slay. The line is "Put down the Kin-Caller, who rings the Kin Bell". It wants 1. The label is The Kin-Caller. The rares are kin_caller. The map point is (-138.0, 20.0).

Step 2, a find. The line is "Answer for the Kin Bell under the oak".

Step 3, a turnin. The line is "Tell Gammer Ruan what you did with the bell". The person is Gammer Ruan.

After the choice `rung`, a step's line becomes "Tell Gammer Ruan the kin were called home".

After the choice `carried`, a step's line becomes "Tell Gammer Ruan the tongue went to Hearthward".

The ending `rung`: Ruan listened to the last of it with her eyes shut. "That's dusk," she said. "Nine winters late. They'll come or they won't."

The ending `carried`: Ruan looked at the empty bell a long time. "Take the Holds' share up with you, then. Ring it at him."

### The Mason's Bell

Giver Jory Quell, Jory Quell, at his fire by the Saints' Quarry. The journal files it under The Saints' Quarry. It is offered when qd:quarry_chisel,q:founders_peal. The giver's mark and the accept screen start it. The cutters worked to a bell. Start, stop, eat, stop. It still hangs from the quarry crane, and the one who rings it rings start. Always start. They're still cutting. Make him stop.

The hand-in pays 30 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus; a Hallowed Girdle; a Hallowed Lantern Glass.

Step 1, a slay. The line is "Put down the Bell-Hewer at the quarry crane". It wants 1. The label is The Bell-Hewer. The rares are bell_hewer. The map point is (-120.0, -118.0).

Step 2, a find. The line is "Answer for the Mason's Bell on the crane".

Step 3, a turnin. The line is "Tell Jory Quell what you did with the bell". The person is Jory Quell.

After the choice `rung`, a step's line becomes "Tell Jory the cutters heard stop".

After the choice `carried`, a step's line becomes "Tell Jory the tongue went to Hearthward".

The ending `rung`: Jory set his own pick down when he heard it, from habit. Then he laughed, once, and left it there.

The ending `carried`: "Stop, then, at the top," Jory said. "Somebody up there owes the cutters four thousand steps of wages."

### The Wayfarer's Bell

Giver Ysolt the cairn-keeper, Ysolt, at her fire under the tor. The journal files it under The Lanternless Moor. It is offered when qd:moor_hennet,q:founders_peal. The giver's mark and the accept screen start it. The fog bell on the moor. Rung in the murk so pilgrims would walk to it and not into the bog. Nobody's rung it in nine winters, and still they walk to it. Something waits for them there.

The hand-in pays 30 grave ash.

The hand-in also offers one of: a Hallowed Vestment; a Hallowed Girdle; a Hallowed Lantern Glass.

Step 1, a slay. The line is "Put down the Fog-Shepherd at the fog bell". It wants 1. The label is The Fog-Shepherd. The rares are fog_shepherd. The map point is (146.0, -28.0).

Step 2, a find. The line is "Answer for the Wayfarer's Bell on its post".

Step 3, a turnin. The line is "Tell Ysolt what you did with the bell". The person is Ysolt the cairn-keeper.

After the choice `rung`, a step's line becomes "Tell Ysolt the moor has a bell again".

After the choice `carried`, a step's line becomes "Tell Ysolt the tongue went to Hearthward".

The ending `rung`: Ysolt added a stone to the nearest cairn without looking at it. "Now they've something to walk to that isn't the bog."

The ending `carried`: "Then the moor stays dark," Ysolt said. "It's good at it. Make the bell worth it."

### The Tenor

Giver Elspeth Fane, Elspeth Fane, at her fire in the Founder's Pits. The journal files it under The Founder's Pits. It is offered when qd:founder_peal,q:founders_peal. The giver's mark and the accept screen start it. Her own bell. The tenor. She cast it last and best and never hung it: it stood in the pits waiting for the Stair to be finished. It wasn't. Something crawled into it out of the slag to keep warm.

The hand-in pays 30 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the bell set; a Hallowed Lantern Glass of the bell set.

Step 1, a slay. The line is "Put down the Slag-Born curled in the Founder's tenor". It wants 1. The label is The Slag-Born. The rares are slag_born. The map point is (140.0, -90.0).

Step 2, a find. The line is "Answer for the Tenor in the casting pit".

Step 3, a turnin. The line is "Tell Elspeth Fane what you did with the Tenor". The person is Elspeth Fane.

After the choice `rung`, a step's line becomes "Tell Elspeth the Tenor was rung where it was cast".

After the choice `carried`, a step's line becomes "Tell Elspeth the Tenor's tongue went to her son".

The ending `rung`: Elspeth didn't turn from her fire. "First time," she said. "It's a better note than she said it'd be. She always undersold."

The ending `carried`: "Her son should have it," Elspeth said. "He's been ringing nothing in that chimney for nine years."

### The Harvest Bell

Giver Linnet the grafter, Linnet, at her fire in the Cinder Orchard. The journal files it under The Cinder Orchard. It is offered when qd:orchard_pippin,q:founders_peal. The giver's mark and the accept screen start it. The brothers rang the harvest in. The bell hung in the press-house yard and it's still there, under ash, and something grubs round it as if it were a root. Dig it out.

The hand-in pays 30 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the kindler set; a Hallowed Vestment of the kindler set.

Step 1, a slay. The line is "Put down the Ash-Sower in the press-house yard". It wants 1. The label is The Ash-Sower. The rares are ash_sower. The map point is (-98.0, 128.0).

Step 2, a find. The line is "Answer for the Harvest Bell under the ash".

Step 3, a turnin. The line is "Tell Linnet what you did with the bell". The person is Linnet the grafter.

After the choice `rung`, a step's line becomes "Tell Linnet the harvest was rung in".

After the choice `carried`, a step's line becomes "Tell Linnet the tongue went to Hearthward".

The ending `rung`: Linnet said the grafted stock put out a leaf the hour the bell rang. She said it as if she'd caught it cheating.

The ending `carried`: "Nothing to harvest anyway," Linnet said. "Not this year. Take it."

### The Passing Bell

Giver Sister Agathe, Sister Agathe, at the gate of the Waiting Field. The journal files it under The Waiting Field. It is offered when qd:abbot_names,q:founders_peal. The giver's mark and the accept screen start it. One stroke for each soul gone up. The Abbot had it rung day and night till the rope wore through. They've made a new rope. Out of what, I'd rather you saw than I said.

The hand-in pays 30 grave ash.

The hand-in also offers one of: a Hallowed Vestment of the tally set; a Hallowed Girdle of the tally set.

Step 1, a slay. The line is "Put down the Passing-Ringer in the Waiting Field". It wants 1. The label is The Passing-Ringer. The rares are passing_ringer. The map point is (-4.0, 128.0).

Step 2, a find. The line is "Answer for the Passing Bell and its rope".

Step 3, a turnin. The line is "Tell Sister Agathe what you did with the bell". The person is Sister Agathe.

After the choice `rung`, a step's line becomes "Tell Sister Agathe the Field heard its last stroke".

After the choice `carried`, a step's line becomes "Tell Sister Agathe the tongue went to Hearthward".

The ending `rung`: Agathe counted the strokes out loud and stopped at one. "That's for all of them," she said. "He'd have hated it."

The ending `carried`: "Good," Agathe said. "Let it pass him, for once."

### The Ferry Bell

Giver Cadoc the ferryman, Cadoc the ferryman, on the mere's north bank. The journal files it under Corvin's Mere. It is offered when qd:mere_ferryman,q:founders_peal. The giver's mark and the accept screen start it. On the far bank there's a post and a bell: ring it and the ferry comes. Corvin's bell. Somebody's been ringing it from the water side. I don't go.

The hand-in pays 30 grave ash.

The hand-in also offers one of: a Hallowed Orb Focus of the ferryman set; a Hallowed Lantern Glass of the ferryman set.

Step 1, a slay. The line is "Put down the Fare-Caller by the ferry post". It wants 1. The label is The Fare-Caller. The rares are fare_caller. The map point is (132.0, 108.0).

Step 2, a find. The line is "Answer for the Ferry Bell on its post".

Step 3, a turnin. The line is "Tell Cadoc what you did with the bell". The person is Cadoc the ferryman.

After the choice `rung`, a step's line becomes "Tell Cadoc you rang for the ferry".

After the choice `carried`, a step's line becomes "Tell Cadoc the tongue went to Hearthward".

The ending `rung`: Cadoc said he heard it and nearly went. Then he remembered there's no boat. Then he went anyway, as far as his knees.

The ending `carried`: "Then nobody calls me across," Cadoc said. "Good. I'm tired."

### The Keg's Tab

Giver The keep, The keep of the Kindled Keg. The journal files it under Hearthward. It repeats daily. The 30-minute slice hides it. It is offered when flag:met_keep. The giver's mark and the accept screen start it. I keep a tab for the dark. Every hollowed you put down comes off it. Twenty, and I'll stand you ember and a bed. Every night. The tab never closes.

The hand-in pays 18 grave ash, 2 ember_shard.

Step 1, a slay. The line is "Put down hollowed anywhere in the Reaches ({n}/{of})". It wants 20. The label is Hollowed anywhere.

Step 2, a turnin. The line is "Have the keep strike them off the tab". The person is The keep.

The ending line: The keep made twenty marks on the slate behind the bar and wiped them off with his sleeve.

### A Named Head

Giver The keep, The keep of the Kindled Keg. The journal files it under Hearthward. It repeats daily. The 30-minute slice hides it. It is offered when bosses:1. The giver's mark and the accept screen start it. The ones with names walk the same rounds every night. Bring me word one of them's down. Any of them. I pay better for names.

The hand-in pays 22 grave ash, 2 relic_fragment.

The hand-in also offers one of: a Hallowed Orb Focus; a Hallowed Vestment; a Hallowed Lantern Glass; a Hallowed Girdle.

Step 1, a slay. The line is "Put down one of the named rares that walk the Reaches". It wants 1. The label is A named rare. The rares are old_rook, brother_chisel, hennet, clapper, old_pippin, last_pilgrim, ferryman.

Step 2, a turnin. The line is "Tell the keep whose name to cross out". The person is The keep.

The ending line: The keep crossed the name out. It'll be back on the slate tomorrow, in his handwriting.

### The Keepers Come Back

Giver The keep, The keep of the Kindled Keg. The journal files it under Hearthward. It repeats daily. The 30-minute slice hides it. It is offered when q:founders_peal. The giver's mark and the accept screen start it. Brannoc says the things that kept his mother's bells come back to them. Of course they do. Put one down again. He'll pay in iron; I pay in ash.

The hand-in pays 26 grave ash, 2 grave_iron, 2 ember_shard.

The hand-in also offers one of: a Reliquary Orb Focus; a Reliquary Vestment; a Reliquary Lantern Glass; a Reliquary Girdle.

Step 1, a slay. The line is "Put down one of the bells' keepers, wherever it walks". It wants 1. The label is A bell keeper. The rares are kin_caller, bell_hewer, fog_shepherd, slag_born, ash_sower, passing_ringer, fare_caller.

Step 2, a turnin. The line is "Tell the keep which bell is quiet tonight". The person is The keep.

The ending line: Brannoc paid in iron, as promised, and said nothing, which for Brannoc is thanks.

### Shut Is Not Latched

Giver Brannoc, Brannoc Bellwright, at the Keg. The journal files it under The Summit of Ascension. It is offered when boss:ascended_warden,flag:ending_told. The giver's mark and the accept screen start it. Shut, he says. Shut isn't latched. Mother hung that door, and a door she hung is held by its latch, and the latch is in your satchel. Go back up. Put it in the door, or don't. I can't tell you which. I only know which she'd have done, and she was wrong about things.

The hand-in pays 40 grave ash, 3 relic_fragment.

The hand-in also offers one of: a  ; a  ; a  ; a  .

Step 1, a visit. The line is "Climb back to the Warden's dais, under the door". The label is The door in the sky. The radius is 8 m. The map point is (0.0, -103.9).

Step 2, a find. The line is "Decide what the latch is for".

Step 3, a turnin. The line is "Tell Brannoc what you did at the door". The person is Brannoc.

After the choice `latched`, a step's line becomes "Tell Brannoc the door is latched".

After the choice `open`, a step's line becomes "Tell Brannoc the door is left on the latch".

After the choice `broken`, a step's line becomes "Tell Brannoc the latch is broken".

The ending `latched`: Brannoc nodded once. "Then nothing more goes up. And nothing up there comes down. She'd have done that. She liked things finished."

The ending `open`: "On the latch," Brannoc said. "So the ones still climbing can turn round. That's kinder than she was."

The ending `broken`: Brannoc looked at the two halves of the latch for a long time. "Then it's only sky," he said. "Just sky. I don't know if that's better. Nobody does."

### Those Still Climbing

Giver Sister Agathe, Sister Agathe, at the gate of the Waiting Field. The journal files it under The Waiting Field. It is offered when qd:the_latch. The giver's mark and the accept screen start it. Since the door, the ones who were halfway up have been coming down. Not all of them know they're dead. Some walk into the Field and stand in their old places. Some walk into it with their hands out. Put down the ones with their hands out.

The hand-in pays 30 grave ash, 3 ember_shard.

The hand-in also offers one of: a Reliquary Lantern Glass of the tally set; a Reliquary Orb Focus of the tally set.

Step 1, a slay. The line is "Put down the hollowed who came down into the Waiting Field ({n}/{of})". It wants 8. The count is kept in `necropolis`. The label is The ones who came down. The map point is (-4.0, 124.0).

Step 2, a turnin. The line is "Tell Sister Agathe the Field is quiet". The person is Sister Agathe.

The ending line: Agathe counted the ones who stood in their old places and didn't hold out their hands. Forty-one. She left them standing.

### Names Under the Door

Giver The keep, The keep of the Kindled Keg. The journal files it under The Summit of Ascension. It is offered when qd:still_climbing. The giver's mark and the accept screen start it. The dais stone. 'The names of the faithful who went through,' and nothing cut under it. I've been thinking about that. Ask about. Get me a name from every fire in the far country, somebody who went up, and cut them in. Then come and sit down. For good, this time.

The hand-in pays 50 grave ash.

The hand-in also offers one of: a Umbral Orb Focus of the bell set; a Umbral Vestment of the bell set; a Umbral Lantern Glass of the bell set; a Umbral Girdle of the bell set.

Step 1, a gather. The line is "Ask a name of the faithful at the fires of the far country ({n}/{of})". It wants 4.

Step 2, a find. The line is "Cut the names into the dais stone under the door".

Step 3, a turnin. The line is "Sit on your stool at the Kindled Keg". The person is The keep.

The ending line: The keep poured two. He drank his and then, after a while, yours. "Somebody should," he said.

### The Full Peal

Giver Brannoc, Brannoc Bellwright, at the Keg. The journal files it under The Summit of Ascension. It is offered when qd:the_latch. The giver's mark and the accept screen start it. Four woke the door. Seven is what she cast. I'd like to hear it, once, the way she meant it: every bell answered for, top to bottom, or bottom to top, I don't care which. You've the legs. I've watched you.

The hand-in pays 60 grave ash, 5 ember_shard, 5 relic_fragment.

The hand-in also offers one of: a  ; a  ; a  ; a  .

Step 1, a cond. The line is "Answer for all seven of the Founder's bells ({bells} of 7)". The condition is `bells:7`.

Step 2, a turnin. The line is "Tell Brannoc the peal is whole". The person is Brannoc.

The ending line: Brannoc rang the chimney tongue seven times, slowly, and the Keg went quiet for each one. Then he put his head down on the bar and laughed.

Sixty-six tasks, and the counts in the steps are the counts the runner asks for. A seal's number arrives from the camp when the task is live, which is why those steps leave `{of}` for the spawner.

## Part XLI — the camps as planted

The stair camps and the realm camps, in the order `enemy_spawner.gd` plants them. Ground camps are given at y 60 with probe 0, and the ground under them is found once the Realm is built. Probe is how far above the point the search starts. Strict probes straight down and keeps a hit within 4 m, which is how the stair stays off the chasm. A pack of two or more stands on a ring of the line's `r`, or 2.5 m when the line leaves `r` off. A single body with no `r` stands on the centre. A kind written as `kind@look` wears that look. Any other body asks `region_variant` at the ground point, which is how the quarry comes out stone-bound and the mere comes out drowned. The life, the blow, and the walk are the row in Part XXXIV for `tier_at` of that ground point. This list leaves the row unnamed, because the row is `region_at` of the planted point plus the night's depth. A camp with a seal stays down once that seal is broken. A camp whose centre is in the haven, finds no ground, or stands inside a site is erased from that seal's guard list, so the list keeps the camps that rise. The haven test, 12 m around (−3.4, −8.5) and 12 m around (0, −10), skips a camp whose centre lands inside it.

### Stair camps

Stair camp 1. The file's point is (-6.0, 4.0, 18.0). The kinds are wretch, crawler. The ring is the default 2.5 m. Probe is the default 24. Seal `henge`. Once that seal is broken, this camp stays down. The line's note: west corridor.

Stair camp 2. The file's point is (8.5, 4.0, 18.0). The kinds are spitter, wretch. The ring is the default 2.5 m. Probe is the default 24. Seal `henge`. Once that seal is broken, this camp stays down. The line's note: east corridor.

Stair camp 3. The file's point is (-24.0, 4.0, 18.0). The kinds are leaper, crawler. The ring is the default 2.5 m. Probe is the default 24. Seal `henge`. Once that seal is broken, this camp stays down. The line's note: the pilgrim stair's foot.

Stair camp 4. The file's point is (0.0, 10.0, -22.0). The kinds are husk. One body, on the centre. Probe 3. Strict is set, so the search goes straight down and keeps a floor within 4 m. Seal `summit`. Once that seal is broken, this camp stays down. The line's note: mid-stair blocker.

Stair camp 5. The file's point is (0.0, 21.0, -50.0). The kinds are wretch, spitter. The ring is 0.9 m. Probe 3. Strict is set, so the search goes straight down and keeps a floor within 4 m. Seal `summit`. Once that seal is broken, this camp stays down. The line's note: upper stair.

5 stair camps.

### Realm camps

Realm camp 1. The file's point is (-50.0, 60.0, 8.0). The kinds are wretch, crawler. The ring is the default 2.5 m. Probe 0. Seal `henge`. Once that seal is broken, this camp stays down. The line's note: past the glade.

Realm camp 2. The file's point is (-44.0, 60.0, -15.0). The kinds are spitter, wretch. The ring is the default 2.5 m. Probe 0. Seal `henge`. Once that seal is broken, this camp stays down. The line's note: the stair's foot, east of the flight.

Realm camp 3. The file's point is (-54.0, 60.0, -18.8). The kinds are leaper, crawler. The ring is the default 2.5 m. Probe 0. Seal `henge`. Once that seal is broken, this camp stays down. The line's note: the stair's head on the raid floor's rim.

Realm camp 4. The file's point is (-13.0, 6.0, -30.0). The kinds are husk, wretch. The ring is 1.4 m. Probe 3. Strict is set, so the search goes straight down and keeps a floor within 4 m. Seal `summit`. Once that seal is broken, this camp stays down.

Realm camp 5. The file's point is (0.0, 25.4, -68.0). The kinds are spitter, wretch. The ring is 1.4 m. Probe 1.5. Strict is set, so the search goes straight down and keeps a floor within 4 m. Seal `summit`. Once that seal is broken, this camp stays down.

Realm camp 6. The file's point is (-126.0, 60.0, -32.0). The kinds are bulwark, chanter, gaunt, wretch, tollman. The ring is 3 m. Probe 0. The line's note: Thornwood deep.

Realm camp 7. The file's point is (-84.0, 60.0, 22.0). The kinds are leaper, husk. The ring is the default 2.5 m. Probe 0. The line's note: Thornwood west.

Realm camp 8. The file's point is (-82.0, 60.0, -56.0). The kinds are mite, mite, mite, mite, mite. The ring is 1.6 m. Probe 0. The line's note: Thornwood under the Crowns: a swarm nest.

Realm camp 9. The file's point is (-39.0, 60.0, 18.0). The kinds are wretch, spitter. The ring is the default 2.5 m. Probe 0. The line's note: Thornwood's village edge.

Realm camp 10. The file's point is (94.0, 60.0, -10.0). The kinds are ossuant, wretch. The ring is the default 2.5 m. Probe 0. The line's note: Hollow Fen east.

Realm camp 11. The file's point is (86.0, 60.0, -75.0). The kinds are burrower, spitter, burrower. The ring is the default 2.5 m. Probe 0. The line's note: Hollow Fen north: the soft ground.

Realm camp 12. The file's point is (63.0, 60.0, 18.0). The kinds are wretch, leaper. The ring is the default 2.5 m. Probe 0. The line's note: Hollow Fen south.

Realm camp 13. The file's point is (70.0, 60.0, 2.0). The kinds are husk. One body, on the centre. Probe 0. The line's note: a drowned husk off east_way.

Realm camp 14. The file's point is (43.0, 60.0, -6.0). The kinds are wretch, crawler, spitter, tollman. The ring is the default 2.5 m. Probe 0. The line's note: east_way, past the rift's shoulder.

Realm camp 15. The file's point is (99.0, 60.0, -34.0). The kinds are ossuant, ossuant, quiller. The ring is the default 2.5 m. Probe 0. The line's note: Barrow Field.

Realm camp 16. The file's point is (60.0, 60.0, -68.0). The kinds are bulwark, quiller, wretch. The ring is the default 2.5 m. Probe 0. The line's note: above fen_descent.

Realm camp 17. The file's point is (-52.5, 60.0, 67.5). The kinds are husk, gaunt. The ring is the default 2.5 m. Probe 0. The line's note: Pilgrims' Road west.

Realm camp 18. The file's point is (-31.0, 60.0, 68.0). The kinds are burrower, wretch. The ring is the default 2.5 m. Probe 0. The line's note: Pilgrims' Road.

Realm camp 19. The file's point is (77.0, 60.0, 56.5). The kinds are chanter, husk, crawler. The ring is the default 2.5 m. Probe 0. The line's note: Pilgrims' Road east.

Realm camp 20. The file's point is (-35.0, 60.0, -10.0). The kinds are quiller, leaper. The ring is the default 2.5 m. Probe 0. The line's note: rift rim west.

Realm camp 21. The file's point is (22.0, 60.0, -6.0). The kinds are wretch, crawler. The ring is the default 2.5 m. Probe 0. The line's note: rift rim east.

Realm camp 22. The file's point is (-111.0, 60.0, -99.0). The kinds are husk, leaper, leaper. The ring is the default 2.5 m. Probe 0. The line's note: the east benches.

Realm camp 23. The file's point is (-139.0, 60.0, -89.0). The kinds are leaper, husk, wretch. The ring is the default 2.5 m. Probe 0. The line's note: the west benches.

Realm camp 24. The file's point is (-119.0, 60.0, -116.0). The kinds are husk, husk, chanter. The ring is the default 2.5 m. Probe 0. The line's note: the south benches, by the unfinished steps.

Realm camp 25. The file's point is (137.0, 60.0, -98.0). The kinds are bulwark, cinder, bulwark, cinder. The ring is 2.8 m. Probe 0. The line's note: before the bell furnace.

Realm camp 26. The file's point is (115.0, 60.0, -102.0). The kinds are cinder, wretch, gaunt. The ring is the default 2.5 m. Probe 0. The line's note: the west bench.

Realm camp 27. The file's point is (141.0, 60.0, -51.0). The kinds are gaunt, gaunt, wretch. The ring is the default 2.5 m. Probe 0. Patrol points (141, -51), (144, -38), (136, -40). The line's note: the north moor.

Realm camp 28. The file's point is (142.0, 60.0, 32.0). The kinds are gaunt, crawler, crawler. The ring is the default 2.5 m. Probe 0. Patrol points (142, 32), (142, 19), (139, 26). The line's note: the south moor.

Realm camp 29. The file's point is (144.0, 60.0, 2.0). The kinds are husk, wretch. The ring is the default 2.5 m. Probe 0. Patrol points (144, 2), (140, -4). The line's note: under the tor.

Realm camp 30. The file's point is (-136.0, 60.0, 104.0). The kinds are burrower, burrower, crawler. The ring is the default 2.5 m. Probe 0. The line's note: the west rows.

Realm camp 31. The file's point is (-80.0, 60.0, 142.0). The kinds are mite, mite, mite, mite, mite. The ring is 1.6 m. Probe 0. The line's note: the south rows: a nest in the ash.

Realm camp 32. The file's point is (-120.0, 60.0, 112.0). The kinds are burrower, mite, mite, mite. The ring is 1.8 m. Probe 0. The line's note: the press-house rows.

Realm camp 33. The file's point is (-30.0, 60.0, 146.0). The kinds are pilgrim, pilgrim, chanter. The ring is the default 2.5 m. Probe 0. The line's note: the west tombs.

Realm camp 34. The file's point is (28.0, 60.0, 114.0). The kinds are ossuant, pilgrim, ossuant. The ring is the default 2.5 m. Probe 0. The line's note: the east tombs.

Realm camp 35. The file's point is (-12.0, 60.0, 140.0). The kinds are pilgrim, pilgrim, pilgrim, pilgrim. The ring is 3 m. Probe 0. The line's note: a row of graves below the mausoleum.

Realm camp 36. The file's point is (-36.0, 60.0, 124.0). The kinds are chanter, ossuant, quiller. The ring is the default 2.5 m. Probe 0. The line's note: the field's west edge.

Realm camp 37. The file's point is (137.0, 60.0, 102.0). The kinds are spitter, husk, wretch. The ring is the default 2.5 m. Probe 0. The line's note: the east bank.

Realm camp 38. The file's point is (118.0, 60.0, 144.0). The kinds are husk, spitter, husk. The ring is the default 2.5 m. Probe 0. The line's note: the south bank.

Realm camp 39. The file's point is (118.0, 60.0, 108.0). The kinds are spitter, spitter, ossuant. The ring is the default 2.5 m. Probe 0. The line's note: the hummocks east of the causeway.

Realm camp 40. The file's point is (-128.0, 60.0, 74.0). The kinds are husk, gaunt, wretch. The ring is the default 2.5 m. Probe 0. The line's note: the West Gate's approach.

Realm camp 41. The file's point is (132.0, 60.0, 58.0). The kinds are chanter, husk, crawler. The ring is the default 2.5 m. Probe 0. The line's note: the East Gate's approach.

Realm camp 42. The file's point is (-144.0, 60.0, -50.0). The kinds are leaper, wretch, crawler. The ring is the default 2.5 m. Probe 0. The line's note: west_track under the quarry.

Realm camp 43. The file's point is (-135.0, 60.0, 40.0). The kinds are wretch, crawler. The ring is the default 2.5 m. Probe 0. The line's note: west_track north of the Holds.

43 realm camps.

The next free sheet is 291. The sheets in Part XXXVI are still the ones the night has not taken.
