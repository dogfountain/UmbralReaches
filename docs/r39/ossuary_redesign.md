# The Ossuary, redesigned (r39)

Luke, 21 Nov: "the ossuary makes no sense and has no presence". A complete redesign, not a touch-up. Brief:
`docs/r39/briefs/ossuary_redesign.md`. Live checklist: tick as built.

## Critique (full-size night shots, `zz/oss_shots.tscn`, before: `scratchpad/ossuary/before/`)

| # | What the shots show | The redesign's answer |
|---|---|---|
| C1 | **No skyline.** From south_track, the lane and the downs nothing of the Ossuary reads; the one tower in the region is the Lantern of the Dead on the field. The tiers sit in a trench: their roofs top out 11 m over the field, 40 m back across the pit, behind trees. The "bell tower" is 14 m of black stub. | The **Charnel Abbey**: a church on the south bank behind the quarry's lip, 72 m long, the bell tower 48 m, every lancet lit. It is the tallest lit thing in the south. |
| C2 | **No night read.** Two lit windows and one red ward; the candles end at 55 m; the masonry is black. | ~30 lit lancets, the belfry, the lantern stage, four lucarnes, the rose; all `oss_glow` (unshaded: they never end with distance). The Count's cold flame (the hoard's end) moves into the new tower's lantern: the whole valley sees it. |
| C3 | **The tiers float.** Floors and corbel bands show as thin flat slabs past the walls, piers wear thin 3 m hats (`_pier` caps), nothing shows how the floors are carried. | A pier kit authored in Blender (footing, battered shaft, stepped corbel capital), the same pier under every tier; floors sit on it with a stone fascia (no loose slab edges). |
| C4 | **Three kinds of wall.** Cream plaster boxes, brick piers, grey ashlar: the tiers do not look like one order's work. | One stone (the Order's ashlar: the abbey's, the piers', the tiers' outer faces). Plaster stays only inside, behind the niches. |
| C5 | **Nothing joins the tiers to anything above them.** The bank is bare turf over the gate hall. | The abbey's north wall stands behind the lip, its buttresses mark the tiers' rhythm, its tally bay stands over the Counting Door (the tally cut on the church is the tally on the door). |
| C6 | **The descent is not announced.** The gate hall is a closed box; each stair head is dark; no lamp shows where the way goes. | Every stair head and landing carries the Order's lantern (a glow pane on an iron bracket, a candelabrum pair); the way lantern is the tier's mark. |
| C7 | The chapel reads as four floating frames (its walls are cut by the near plane in one shot, a lit window hangs in the dark). | Same stone, same pier; the chapel gets its gable cap and a lit east window; the floor slab fascia closes it. |
| C8 | Strengths (kept): the bone bridge and its ribs; the charnel mound; the Counting Door and its tally; the Pit Hall (the rotunda, the skull walls, the candle drum: it already has presence). | Kept untouched. |

## The silhouette (new)

`tools/blender/oss_abbey.py` -> `art/models/oss_abbey.glb` + `core/world/realm/oss_abbey_data.gd`;
placed by `world/areas/ossuary/oss_abbey.gd` (local coordinates, built once the Realm's ground is in).

* **The church**: front (north) wall at local x 46.5, eight 6.4 m bays (z -39.8 .. -91), 16 m to the eaves, stepped down the bank in pairs
  of bays (each pair on its own base, a firewall at each step), slate roof, ridge 6.6 m over the eaves. Back wall blind. Closed shell:
  no door opens on the bank (it is the Order's church, the way in is the pit).
* **The bell tower** at the north (west in the world) end, z -35, 48 m: shaft with three stages of lancets, the belfry (eight louvred
  lancets), parapet, an open lantern (the cold flame's seat), a slate spire with four lit lucarnes, the Open Door finial.
* **The east gable**: the great rose, the charnel door, two lancets, stepped barge, skulls in the field, the Open Door at the apex; two
  stair turrets at its corners.
* **Buttresses** at every seam, each with a pinnacle.
* The tally bay (bay 6, over the Counting Door).
* Distance read: static MultiMesh per module (about 40 draws), CULL_SKIP (a landmark never ends), shadows off, no new light node.

## The route spine (local y; world y = local - 7.4)

```
Pilgrims' Landing (12.6)  the lane ends; the gate arch; the steps up from the lane
 | the bone bridge (12.6, 21 m over the pool): the whole descent opens below and ahead; the abbey's tower stands over the hall
GATE HALL (12.6)  porter's hall: the brazier, the first candles. Its north door is the way on; the stair head is lit.
 | north stair (down 4.2)
NICHE GALLERY (8.4)  the first ossuary: two aisles of skull niches; its west arcade looks down on the pit court and the mound;
 |                    the bone portcullis (seal) and the two guard camps; the cage's landing (the Lower Count's way back)
 | north stair (down 4.2)
CHARNEL PIT (4.2)  the court of the dead: the mound, the Count Door east (the tally over it, the abbey's tally above that),
 |                 the chapel north
 +-- CHAPEL (4.2): the Sexton's slab -> THE LOWER COUNT (cells 0 / drum, weighing floor -2) -> the counterweight cage up to the gallery
 +-- COUNTING DOOR -> the Counting Stair (eight flights, 36 m) -> the raid door -> THE PIT HALL (-32): the Bone Abbot
```

Each tier has a view of the next: the bridge shows the hall's door and, beyond it, the abbey; the hall's north door frames the stair
and the gallery's lit arches; the gallery's arcade frames the pit and its mound; the pit's east gap frames the Count Door's lanterns;
the stair's slits look into the hall.

## What moves, what stays

* **Stays (every coordinate)**: OssFrame (ORIGIN, YAW, LANDING, PIT_*, pit_shape), `RealmLayout.oss_pit_shape`/`OSSUARY_GATE`, the
  WorldLanes sites (`oss_pit`, `oss_landing`), the tier floors (12.6 / 8.4 / 4.2), every stair, the pit disc and mound, the chapel, the
  Lower Count (oss_deep.gd), the lift, the Sexton, the Counting Door, the Counting Stair, the Pit Hall and the Abbot's arena, the seals
  (`oss_gallery`, `abbot_door`, `abbot_gate`), the walk-test points, the perf points, the secrets' sites, the quests.
* **Changes**: piers (new kit), tier wall stone, lanterns on the route, the bell tower for the cold flame (`oss_deep.BELFRY`), the new
  abbey (above the bank), tree keep-out along it (`ossuary_ground.gd`).

## Checklist

- [x] critique shots (before)
- [x] plan (this file)
- [x] abbey kit in Blender (tower, bay, blind bay, buttress, roof, gable, turret) + render review
- [x] `oss_abbey.gd` (placement, foundations, collision) + hook in `ossuary.gd`
- [ ] pier kit in Blender, `_pier` / `_undercroft` use it
- [ ] tier walls in one stone; route lanterns
- [ ] walk the real Player: Landing -> Pit Hall, the Lower Count, the lift, the abbey's footprint
- [ ] re-shoot once; look at every frame
- [ ] parse check; lint
