# Horse feel (r39, branch horse-feel)

Luke, 20 Nov: "Horse is janky." Evidence: `zz/horse_ride_cap` (the real Realm, the player's own camera, live input at a fixed
60 fps: walk to sprint, turns, a pack of husks, mount, dismount) and `zz/horse_feel_probe` (per-frame numbers at 144 fps over
60 Hz physics, studio course with a kerb, 12 degree ramps and a wall). Strips: scratchpad `horse_feel/ride_before` and `ride_after`.

| Jank | Cause | Fix | Before -> after |
|---|---|---|---|
| Camera bobbed with the gait | pivot was the rider's seat (rider spring plus back drop) | camera follows the horse's interpolated root, low-passed height, 0.3 s blend in and out (`PlayerMount.camera_origin`) | probe cam high-pass 4-10 cm -> 0; cam jerk 0.4-1.0 -> 0.07 cm |
| Boom flicked sideways at a gallop | shoulder swing was a first-order lag: full speed in the first frame | critically damped spring, slower while riding | cam jerk in the sprint 10.7-13.2 -> 0.7 cm |
| Dismount was a teleport | the rider was set down 1.1 m aside and 1.4 m lower in one frame | brake to a walk, then the mount climb run backwards; camera glides | rider jump 120 cm -> smooth; camera 112 cm -> 4.4 cm per frame |
| Mount stopped at each waypoint | one smoothstep per segment | one Catmull-Rom spline, eased only at the ends | no stop-start (mount pivot jerk unchanged, 4.4 cm: tick skips of the harness) |
| Body flat on slopes | only the heading was applied | pitch and roll from four ground rays, damped, drawn interpolated; rises over a step are ignored | 12 degree ramp: pitch 0 -> 12 degrees; course cam jerk 165 -> 7.5 cm, root jerk 23 -> 7.5 cm |
| Kerbs popped, ledges glided | 14/s exponential ground follow; no fall | critically damped follow (never more than 15 cm in the ground), a drop over 0.5 m falls under gravity | course root jerk as above |
| Never banked or led with the head | `rig.turn` was never set | set from the turn rate | bank now 0 -> up to 11 degrees |
| Hips fell in one frame | back drop envelope had no attack | DROP_ATTACK 4 m/s | rider-to-barrel frame jump 6.8 -> 4.8 cm (144 fps) |
| Turn rate stepped at 8 m/s; sharp turns cost nothing | `0.6 if speed > 8` | smoothstep 6-10 m/s; gallop gives up to 40 percent pace in a sharp turn | |
| Rider yaw lagged the horse in turns | 12/s lag | locked (40/s), seat follows the tilted saddle | |
| Wall hit stopped dead | 0.2 s | 0.4 s | |

## Round 2 (lead review)

| Jank | Cause | Fix | Before -> after (ride capture, 60 fps unless noted) |
|---|---|---|---|
| Camera slammed into the horse's back through trees | the boom's length was cut to the wall in one frame (`min(.., reach + 0.25)`), a "thin" trunk was passed through and then cut when the pass ended, the swinging view and the carried pivot met trunks with no warning | the boom looks ahead by the view's turn rate and the pivot's velocity (5 + 4 sphere casts out to 0.45 s, counted less the farther off: the target length slides in), in-spring at 12/s, the hard clamp is only the real reach now, no thin pass-through while riding, the shoulder swings in behind the horse before it passes a trunk (look-ahead on the shoulder ray) | camera jerk, palfrey: sprint 12.9 -> 0.56, walk to sprint 17.7 -> 0.79, gentle turns 17.7 -> 1.7 and 3.2, the pack 17.7 -> 0.82 cm; draught right gentle 294 -> 3.5; sharp full-stick camera swings 24 (palfrey) -> 52-94 cm (see left) |
| Rider floated off the saddle (rider vs barrel) | the hips fell 10 cm in 30 ms at the gallop (the legs' reach peaks), the rider's soft spring and ripple filter then disagreed with the back | the back height is drawn through a stiff damped spring (45/s), the rider's seat spring is stiffer (450) and its back filter faster | rider vs barrel jump per frame: 144 fps probe 6.8 -> 2.3 cm, trot 4.9 -> 1.9; ride capture 60 fps 11.2 -> 5.5 cm (palfrey), 4.1 (draught), 4.9 (garron) |
| Right turn 15 cm root jerk | not the harness: the slide along a face turned the line of travel 30 degrees in one tick when the probe met a tree | the deflection is eased (10/s) | 144 fps right gentle 7.4 -> 1.05 cm; 60 fps 15.7 -> 2.7 cm |
| Mount | (checked) no stop or pop in the strip; jerk 1.1 cm at 144 fps (4.4 at 60) is the spline's start | none needed | |

Draught and garron were run through the same capture (ride_after5/draught, garron): sprint, gentle turns and the pack under 4 cm camera jerk for all three breeds.

Left: full-stick camera swings (240 degrees per second) through forest still pull the length in by up to a metre in a frame when the look-ahead sees a trunk too late (52-94 cm at 60 fps, about 10-15 cm at 144 fps); the pivot still enters a trunk the horse brushes within a few centimetres. Trunks are WORLD cylinders in the flora chunk bodies, so a layer for thin ones was not added: the existing thin-occluder ray test remains for the wanderer on foot.
