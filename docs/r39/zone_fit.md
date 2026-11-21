# r39 zone fit: every join measured (entrances, stairs, landmarks)

Brief: `docs/r39/briefs/zone_fit.md`. Branch `zone-fit` (clone `/Users/luke/UmbralReaches_zonefit`). Live checklist.

Luke, 20 Nov: stairs to the thorn boss do not meet the boss floor; entrances and landmarks do not fit the map; two entrances
(the massive tree, the lighthouse) are blocked.

## Method

`zz/zone_fit_probe.gd/.tscn` boots the real Realm and measures joins (it also stays up as a command server, `--cmd=<dir>`:
`floor`, `grid`, `axis`, `ray`, `near`, `mesh`, `sweep`, `walk` (the real Player), `walkstair`, `oakstair`, `shot`):

- `stairs`: every flight `OssKit` built (`OssKit.record`): foot against the floor 1.2 m before it, head against the floor 1 m past it
  (tower chains and ruined stairs read as gaps by design; every one was read before being counted)
- `portals`, `raids`, `sites` (levelled sites against the ground round them), `rooms` (a ray fan from each Interiors room and walled
  site finds its doors; a capsule sweeps through each), `thresholds` (deep halls and caves)
- walks drive the real Player through a door or up a stair; a walk that stops is a snag

Capsule sweeps are unreliable on stairs (a tread edge reads as a wall); a walk is the ground truth for blockage.

## Findings and fixes (worst first; gaps are metres, floor found by a ray against the floor the stair should join)

| # | Where | Join | Before | Fix | After (probe / walk) | Blocked |
|---|---|---|---|---|---|---|
| 1 | Lamplighters' Spire (242, 6), the lighthouse | its door and steps hung over an 8 m cliff (the door faced the nearest way, SW); no way up | door unreachable | door faces the south spur; 14 m stone stair down the spur (`_spire_stair`, flight registered so the stamp cuts it), `spire_track` ends at its foot (238,29)-(243,27) | walk track end -> stair -> plinth -> door interior passes, no snag (shot `spire_a`) | blocked -> open |
| 2 | Cave 3 (Lastlight, 344, -16) | stair 28 m down over 20 m run: a 54 degree wall | walker stuck at y 1.99, 14 m above the floor | `caves.gd`: run lengthened to a stair of at most ~31 degrees (47 m) | walk reaches y -16.37 at the stair's foot | blocked -> open |
| 3 | Thorn Henge stair head (-45.1, 9.0, 4.0), the Thornwarden's | top step against the raid floor | floor 1 m past the head 8.02 (0.98 low), 1.4 m past 8.25; first walk of the top step a 1 m drop | the stamp's 0.55 m pins under the flight stop 6.6 m short of the head; a 4.6 x 6 m paved apron flush with the head carries the join past the raid door | floor 0 .. 6 m past the head 9.00 (0.00); head gap +0.00; walk foot -> head reaches y 8.90 (the closed seal stops it, as it should) (shots `henge_a`, `henge_c`) | no / no |
| 4 | Thorn Henge stair foot (-34.7, 5.1, 0.5) | first riser against the road | ground 0.36 under the foot (riser 0.62: the bake's snag at (-31, 4)) | foot set into the lowest ground 0-3 m out | gap -0.18; walk from (-28, 0.5) reaches the foot and the head | snag / none |
| 5 | Chain Span, both stairs | top step 1.2 m short of the deck's first plank; foot 0.7 over the road side; west foot under a giant-cap prop | head gap -2.23 / -1.50, foot -0.69; walker stopped by the cap | head reaches the deck beam, foot set into the lower of two samples, the cap pieces within 6 m of the foot skipped | head gap -0.19; both walks foot -> deck (y 5.70) pass | blocked -> open |
| 6 | Every cave and hall mouth (5 caves, 4 halls) | threshold 0.3-1.8 m over the ground 1.2 m before it | -0.38 .. -1.58 | `DungeonKit.forecourt`: a paved apron flush with the sill and steps down to the ground | each forecourt flight walks from the ground to the sill (shots `cave3b`, `kings`) | lip -> open |
| 7 | every flight with `register_flight` | the stamp's round cap at each end | ground 0.35 under every stair top; at a hall's deep end an open 3.6 m pit dug onto its first room | `TerrainStamp`/`WorldLanes.end_cap`: the cap at the high end is cut flush with the floor, the cap at the low end is not cut | halls' tops -0.30 .. -0.41 now carried by the forecourt; no pit past the deep end | no / no |

| 8 | Grandmother Oak door (-70.4, 15.9, 199.6) | two fallen boughs (flora colliders, 4.9 and 5.4 m long, 0.7 high) lay across the approach 3.6 m out: the walk from the road stopped at (-70.4, 195.2) | blocked | `oak_door_way` lane keeps scatter off the 22 m approach | walks from the straight-on line and 7 bearings pass; shot `oak_door2` | blocked -> open |
| 9 | Mother Tree (-84.2, 116.3) | the way in 1.4 m between bark; any line 0.8 m off the middle stopped at the shell | clear width about 0.7 m | the shell's collision opened over a 100 degree arc (`_mother_open`), `mother_way` lane | clear for x -84.95 .. -82.45 (2.5 m), 4 bearings walk to the opening and the chest | blocked off-centre -> open |
| 10 | Hollow King door (222.2, 350) | approach lane not reserved | 5 of 7 bearings passed (the other two started over the Witch's Cellar's stair trench and in the Witch's Hollow building) | `hollow_king_door_way` lane | 5 of 5 walked bearings pass | open |
| 11 | The glade fire's ember post and the henge rest fire's ember post | the rest fire's post stood by the stair's landing, in the line of the shot from the flight | post in view of the walking line | `ember_post.gd` SEAT_OFFSETS: glade fire's post to the other side, the henge rest's on its platform corner | shot `henge_a` (post at the platform corner, flight clear) | none |
| 12 | Warden towers' door stairs, Salt Ship ramp, ClimbStair 1 | feet 0.25-1.0 over the ground | -0.95 / -1.04 / -1.36 | feet set 0.8-1.1 m lower / into the ground before them | towers now +0.6 .. +1.0 (buried first steps, a step down onto the stair), Salt ramp +1.4 (the first ramp) / -0.18, ClimbStair 1 -0.83 | step -> walkable (ClimbStair 1 still 0.83 on a 48 degree slope) |

## Boss approaches walked (the real Player)

- Thornwarden: road -> foot -> flights -> head -> the raid floor (y 9.00): no snag.
- Hierarch (the Speaking Crown): siege track end (-181, 146) -> gate (-182.5, 159) -> skull floor (-206, 148): reached.
- Anchorhold (Anchoress): anchor_track end -> gate -> scree ramp -> floor (214, -132) y 15.95: reached.
- Bone Abbot: Pilgrims' Landing -> bone bridge -> gate hall -> gallery -> Lower Count stair (to its head, y -3.20) with the gallery seal released; the Counting Stair's eight flights from -39.2 to -3.18: reached.
- Ascended Warden / Summit: Rift crossing stairs (probed, 0.00 gaps), ward landing -> ApproachStairs -> the deck (y 27.35), around the statue's plinth on its east side; the west side stops at the plinth by design. The chasm between the Crossing's first and second sections is the rift's own gap (an ability, not walked).

## Props on stairs (probe `lampscan`)

A 0.4 m box swept along every built flight's centreline: no lamp or post stands on any of 133 flights; the hits are the closed seals (Summit, Ossuary gallery), tower and hall bodies at the flights' ends, and the Sexton's slab 1.9 m over the Lower Count stair.

## Entrances walked (the real Player, from the road side to inside)

- Grandmother Oak: door from 7 bearings and the straight line; the inner stair's first treads climb to y 16.8 from (-70.5, 202.9) but a straight-line driver stops at the first lip: the whole stair (170 treads) was not walked, its treads were found at 56 of 57 sampled heights.
- Hollow King, Mother Tree: as in the table.
- Halls and caves: foot to the bottom of every flight (the last leg stops at the first room's front wall); each forecourt flight from the ground to the sill.
- Henge stair, Spire stair, Chain Span stairs, the quarry crane and winch stairs: foot to head.

## Left (not fixed)

- The Oak's inner stair above its first treads (not walked).
- ClimbStair 1's foot (-0.83, a 48 degree hillside) and the Salt Ship's inner deck stair foot (-1.04, inside the ship).
- Capsule sweeps through doors read tread edges as walls: the `ROOM ... BLOCKED` lines of the probe are leads, not findings.

## Third round (lead review)

- Mother Tree: rebuilt in Blender (`tools/blender/orchard_mother_tree.py`, split half-angle 0.64 -> 1.35 rad at the foot, roots moved off the way in): 2.2 m clear
  at the inner wall; the code filter was removed, the collision (`MotherCol`) comes from the same mesh. Walks: 4 bearings to the opening, lines x -85.4 .. -82.4
  all reach the chest (3 m wide). Shots `mother_door`, `mother_in`, `mother_side`.
- ClimbStair 1: a level pad under the foot (`climb_stair_foot_1`); the walk from the slope below climbs foot to head (y 3.58 -> 10.70). Shots `c1`, `c1b`.
- Hall and cave stair cuts are hard-edged (no 4 m falloff). The halls' crater round the walls is much smaller, but a pit flank of about 2 m remains beside the
  deepest part of the Witch's Cellar stair (a walker that steps off the slope there stands at y -2). A roofed tunnel was tried and backed out (the terrain's
  grid ramp crosses the tunnel).
- Doorway scan (`doorscan`, box 0.5 x 0.9 m through every door the ray fans find): the hits are building bodies, plus one yard scene (a fence) 3.4 m out of
  Fallowmere's tithe barn door (-176.1, 276.8); not moved (settlement_yards.gd places yards on open ground without knowing doors).
- Grandmother Oak stair: treads missing at the limb doors (65-68, 100-103, 135-138, 160-162, a 0.4-0.6 m riser each, found by `oakscan`); collision ramps added
  (`OAK_STAIR_GAPS`). The real Player climbs from the floor (a lip at the first tread needs a jump) to y 29.5 (tread 65) and stops at the first gap; the whole
  170-tread ascent is NOT verified.

## Fourth round (lead review)

- Cave 3 and every other descent: the real Player walks every hall and cave stair to its bottom (cave 3 to y -14.4 of -16.8). The "respawn at the spawn point" was the
  player's own stuck rescue (`Vitals._stuck_tick`) putting a walker that kept pushing at the first room's wall back on the last safe ground (the cave's threshold, or
  Hearthward when that was the last safe ground): not a fall and not a hole. The caves are back on the soft cut (the hard edge stays for the halls only).
- Grandmother Oak stair: the "missing treads" were the limb-door landings' flat collision plates standing 0.3-0.6 m over the treads before them. The plates now follow the
  flight's slope (`r37_south_oak.py`, re-exported), the invisible ramps are gone. Full ascent with the real Player: floor to the crown (y 51.1), 92 waypoints, 0 stuck;
  and the same stair top to door, 0 stuck.
- Witch's Cellar flank (and every other open stair of the halls and caves): a stone kerb (`DungeonKit.kerb`) runs along both sides beyond the cut's edge, 1.9 m high,
  so nobody steps onto the flank. Shots `kerb1`, `kerb2`, `hall_pit2`, `cave1`.
- Yards keep 6 m off every building site (`settlement_yards.gd`); the tithe barn's door scan no longer lists a yard prop.
