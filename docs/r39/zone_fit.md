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

## Entrances walked (the real Player, from the road side to inside)

- Grandmother Oak: door (-70.4, 15.9, 199.6), 7 bearings at 20 m and 8 m: all reach the door, the trunk's centre and the first tread's side. The inner stair
  was not walked up (`oakstair` found its treads but the walk's waypoints did not follow the tread radius: not verified).
- Hollow King: door (222.2, 350) from 5 of 7 bearings (the other two started over the Witch's Cellar's stair trench): reaches the hollow's centre.
- Mother Tree (-84.2, 116.3): reachable only through its 1.4 m gap; a line 0.8 m off the middle stops at the shell. Reaches the chest from the north.
- Halls and caves: foot to the bottom of every flight (the last leg stops at the first room's front wall).
- Henge stair, Spire stair, Chain Span stairs, the quarry crane and winch stairs: foot to head.

## Left (not fixed)

- "The massive tree" blocked: none of the three giant trees (Grandmother Oak, Hollow King, Mother Tree) is blocked at its door in the walks; which one
  Luke meant is not known. The Mother Tree's way in is 1.4 m wide and a line 0.8 m off its middle stops at the shell.
- Warden towers' door stairs (towers 2, 3, 4: feet 0.25-0.95 over the ground; the sites' cut and falloff lowers the ground the builder sampled), the
  Salt Ship's gangway foot (-1.04) and ClimbStair 1's foot (-1.36, on a 48 degree hillside): measured, not fixed.
- The Oak's inner stair, the Hierarch's and Anchorhold's approaches and the Ossuary's Lower Count stair were measured by probe only (no walk).
- Capsule sweeps through doors read tread edges as walls: the `ROOM ... BLOCKED` lines of the probe are leads, not findings.
