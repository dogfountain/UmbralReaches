# Animation smoothing (branch r39-anim)

Goal: nothing that moves pops, snaps, steps or twitches, at 60, 120 or 144 Hz, with physics interpolation on
(`physics/common/physics_interpolation=true`). The audit found the wanderer, the camera, the horses and the wildlife
already smoothed with `1 - exp(-k dt)` springs and tick interpolation. The remaining sources of choppy or snapping motion
were: skinned rigs posed on the physics tick whose BONES are not interpolated by the engine (only node transforms
are), poses that are pure functions of a mode or an act (a change of mode or act is a jump), impulses that set a
value in one frame (flinch, reel, tuck, hit), and the tavern dwarves, which were posed at 30/20/12 Hz with no
blending at all. Nothing was run; a lead must film the cases below.

## Systems touched

| System | Before | After | Files |
|---|---|---|---|
| Villager boss rig (Abbot, Warden, Anchoress, Crown) | pose = f(mode): wind-up cut by a stagger, a death from a strike, a howl out of a walk all snapped; flinch set in one frame and decayed linearly; bones posed on the 60 Hz tick | every mode change is a slerp from the pose last shown over 0.05 to 0.3 s with an eased weight; flinch is a critically damped spring (omega 14) kicked by an impulse; the skeleton is drawn between the last two ticks each rendered frame | `core/enemy/pose_smooth.gd` (new), `core/enemy/villager_boss_rig.gd` |
| Beast boss rig (Thornwarden) | same, plus a Dictionary allocated every tick | same fixes; the euler pose table is reused (no per-tick allocation); the root bone's position is interpolated too | `core/enemy/beast_rig.gd` |
| ClipRig (glb bosses and foes) | `AnimationPlayer` advanced manually on the tick, skeleton stepped at 60 Hz; flinch set in one frame; clip speed re-set every tick from a noisy ground speed; idle/walk flickered at the speed threshold | skeleton interpolated between ticks (rotation slerp, position lerp) every rendered frame; spring flinch; clip pace smoothed (rate 6/s); hysteresis 0.2 up, 0.1 down on idle <-> walk | `core/enemy/clip_rig.gd` |
| HunchRig, QuadRig (grunts) | flinch and reel set to 1.0 in one tick | rise at 18/s and 9/s to a target that decays as before (about 55 and 110 ms, a snap that still reads as a hit) | `core/enemy/hunch_rig.gd`, `core/enemy/quad_rig.gd` |
| Villagers | an act change posed the new act at once; low-rate (30/20/12 Hz) poses eased with a full smoothstep per interval (the limbs stopped and started at the update rate) | a crossfade from the pose on screen over 0.28 s on every act change (`xfade_check` / `xfade_apply`); the ease between low-rate updates is a third of a smoothstep (velocity does not jump at the knots, a steady walk does not pulse); the span is 8 percent longer than the interval so a late update does not stall the blend; fidget arms touch the rig only while the gesture is live | `core/npc/npc_life.gd`, `core/life/village/villager.gd`, `core/life/village/villager_fidgets.gd` |
| Tavern dwarves | posed at the distance rate with NO blending between poses (steps at 30/20/12 Hz) and acts popped | same blend_from / blend_to / blend_step as the villagers, plus the act crossfade (key: act, or trip phase) | `core/npc/dwarf_npc.gd` |
| Wanderer | double-jump tuck and hit react (pelvis dip, shoulder drop) were set to full in one frame | both rise to their target at 14/s and 16/s and then decay as before | `core/player/character_rig.gd` |
| Living Night (this branch's predecessor) | moths used the tick position of the player (stepped against the interpolated body); the tell light followed its caster from `_process` | moths use `get_global_transform_interpolated()`; the tell light is placed in `_physics_process` (interpolated by the engine) and reset on a new cast | `core/world/night_life/light_moths.gd`, `telegraph_glow.gd` |

Audited and left alone (already smooth): the camera rig (every follow, FOV, roll, arm length and shake term is
`lerp(.., 1 - exp(-k dt))`), the wanderer's gait, foot IK, stop settle, hit spring and cloth (tick-captured bones drawn with
the interpolation fraction, `render_placed` for mounts), the horse rig (posed in `_process` from the interpolated
transform, exp smoothing throughout), wildlife flocks and herds (drawn between the last two ticks,
`life_group.lerp_draw`).

## Verify by filming (frame strips at 60 and 144 Hz; compare the same shot before and after)

1. **Abbot, Warden, Anchoress, Crown**: start a fight, let the boss wind up and hit it so it staggers mid wind-up
   (wanderer's heavy strike); then kill it from a strike. Expect: no one-frame jump of the staff arm or the body; the
   stagger and the fall start as a short blend. 144 Hz: no 60 Hz stepping of the arms in the walk.
2. **Thornwarden** (Thornwood arena): the lunge into a stagger, the howl, the death on its side. Expect the legs and
   head to blend between modes, the root to move without steps.
3. **A ClipRig boss or foe** (any glb enemy, for example a Bone Abbot clip model if present): walk it slowly past the
   threshold of walking (strafe at the edge of its aggro) to check no flicker between idle and walk; a heavy hit.
   Expect smooth limbs at 144 Hz.
4. **Grunts** (a hunch or quad foe): hit it once, hit it hard to stagger. Expect the flinch to rise quickly but not
   in one frame.
5. **Hearthward villagers**: stand 12 to 30 m from a crowd and watch walkers and workers (smith, lamplighter): no
   stepping at the update rate; watch an act change (sitting to walking, kneeling to standing, a fidget starting) for
   pops of the arms and torso.
6. **The Kindled Keg**: from a seat or the door watch the dwarves 4 to 15 m away (a toast, a dice throw, a trip to
   the bar): previously stepped at 12 to 30 Hz; now continuous.
7. **Wanderer**: a double jump (tuck), a hit from the front and from behind while standing and while running:
   no one-frame pelvis dip.
8. **Moths (Living Night)**: stand still by a fire while turning the camera and then walk off: the moths round the
   lantern must stay glued to the lantern at 144 Hz; the amber tell light under a caster must track it without lag.

## What to check in the engine (nothing here was run)

- `PoseSmooth` (`core/enemy/pose_smooth.gd`) compiles and `var _sm: Smooth` types resolve (preload const as a type).
- The boss skeleton draw in `_process` (`_draw_bones`) does not fight the dissolve (`transparency` writes) and the
  cloth springs of ClipRig still work: their modifiers run on the interpolated pose.
- `Engine.get_physics_interpolation_fraction()` semantics on a boss that is posed every other tick (LOD): the held
  pose shows as posed (`f = 1`) one tick after the last pose.
- Frame time: boss `_process` is 16 quaternion slerps; the ClipRig capture is one pass over the bones per tick and a
  slerp per bone per frame (50 to 100 bones). Expect no measurable cost; check `fight_bench`.
