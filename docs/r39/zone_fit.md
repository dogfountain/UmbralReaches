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

## Findings and fixes (worst first)

| # | Where | Join | Gap before | Fix | Gap after | Blocked before / after |
|---|---|---|---|---|---|---|
| 1 | Thorn Henge stair head (-45.1, 9.0, 4.0) | top step against the raid floor | floor 1 m past the head 8.02 (0.98 below); 1.4 m past 8.25 | the terrain stamp's 0.55 m "pins" under the flight stop 6.6 m short of the head; a paved apron (4.6 x 6 m, flush with the head) carries the join past the raid door; flight end caps cut flush (see 3) | 0.00 (apron), head gap 0.00 | no / no |
| 2 | Thorn Henge stair foot (-34.7, 5.3, 0.5) | first riser against the road | ground 0.36 below the foot; first riser 0.62 | the foot is set into the lowest ground 0-3 m out along the road's side | -0.18 (riser 0.46 -> a step the walk takes) | snag (bake, leg 3) / walk reaches the head |
| 3 | every flight registered with `register_flight` (halls, caves, henge, sky chain, climbs, rift) | the stamp's end cap cut 0.35 m under the floor, so the ground met every stair top and foot 0.35 low | -0.35 (halls, caves, climbs) | `TerrainStamp`: past a flight's ends the cut is flush (`WorldLanes.past_end`) | see the table below | no / no |
| 4 | Lamplighters' Spire (242, 6): the "lighthouse" | the door faced the nearest way, SW, over an 8 m cliff: its steps hung 6-7 m over the ground; no way up | door unreachable (walk could not get up) | the door faces the south spur; a 14 m stone stair down the spur (`_spire_stair`), `spire_track` ends at its foot | walk foot -> plinth -> door passes | blocked / open |
| 5 | Chain Span stairs (both ends) | top step 1.2 m short of the deck, foot 0.7 above the road side | head gap -2.23 / -1.50, foot -0.69 | head reaches the deck's first beam; foot set into the lower ground | see below | gap / open |

(table continues as the passes finish)

## Entrances checked

(filled at the end: every door, with its walk)

## Left

(filled at the end)
