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

Left: the boom's collision snap in a sharp full-stick camera swing through trees (arm length jumps up to 2 m in one frame, the
camera's occlusion clamp, not the horse); the rider-to-barrel metric stays 11 cm per frame at 60 fps in the ride capture; right
turns show a 15 cm root jerk in both before and after (a tick skipped by the fixed-fps harness: pivot and root agree); the
studio strips (`horse_seq --cam=follow`) were not re-shot.
