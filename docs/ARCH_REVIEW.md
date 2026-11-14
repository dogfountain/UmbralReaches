# The Realm, read as architecture (14 Nov 2026)

A review of the 400-still survey (`zz/map_survey -- --name=realm400 --step=40 --png`, every 40 m of the Realm,
aerial and eye level both ways) for how the places are made, not only for faults: massing and proportion,
silhouette, material, how a building meets the ground, streets and squares as rooms, landmarks and sightlines.

## Fixed in this pass

| Place | What it read as | Change |
|---|---|---|
| Hearthward square | two strips of flagstone in the dirt: the roads' wear had painted earth over the paving, so the square had no floor | inside a square the road wear is a faint trace (`realm_land`: wear x (1 - 0.8 pave)); the square is one paved floor the roads arrive in |
| Every square | tall grass clumps mid-square (abandonment, in the middle of a town that is lived in) and 42-58 straw wisps lying across the stones like map marks | low plants at 2 % in a square's core and 20 % at its rim (were 8 % / 30 %); 10-16 wisps of straw |
| Plaster walls (the chapel above Hearthward, the Hollow Lantern) | leopard print: the bare-brick patches of the 2 m plaster tile repeated across a facade | a 3.3 m tile: fewer, larger patches that read as spalling |
| Stillwater's willows | a green curtain wall: 1.8x as tall, overlapping crowns, a hedge with no tree in it | willows grow 2x wide but 1.3x tall, 6.5 m apart (were 5.5): each a dome with its fall of strands |
| Moonlit slate roofs (Weirford) | blown out white where the roof faced between the eye and the moon | slate's specular 0.15; the masonry, bark and iron moonlight rims scaled to the brighter moon (x0.35) |

## The March Wall, rebuilt (14 Nov; items 1, 2 and 6 below)

The kit (`tools/blender/r37_wall.py`, `r37_wall_gate.py`, `r37_wall_town.py`, helpers in `r37_wall_lib.py`; run through
`r37_south.py --only wall`) is rebuilt as masonry that has a section and a rhythm:

| Part | Now |
|---|---|
| Bay (A, E plain; B repaired; C half fallen; D the stair bay) | a coarse, battered footing, a weathered water table, the body, a string course, a corbel table under an oversailing parapet with crenels and merlons (1.05 m breastwork, 0.95 m merlons), a buttress or pilaster strips, dressed arrow loops, repairs in warmer stone, vertex-colour weathering (damp foot, soot under the corbels, rain streaks) |
| Tower | stands 3.5 m forward of the curtain and 7 m above its walk: plinth, quoins, two string courses, machicolated corbel table, a deck with its own parapet, a roofed stair turret, pointed doors on the walk and (raised, with steps) on the inner face |
| Gatehouse | twin drum towers with a rear block each, a deep pointed passage of voussoirs (5.6 m clear, as before) with three ribs, a portcullis in its groove, both leaves swung back, a machicolated gate room and a crest between the drums; a lantern hung from the vault and a bracket lantern on each face, followers of the gate posts (they kindle with them), and a faint cold fill (`Lamp.cold_fill`) that makes the arch read as an opening until they do |
| Breach | the standing end steps down through its core to rubble; a fan of fallen ashlar, merlons and corbels |
| Weirford's face | one bay is the stair bay: a landing under a door in the parapet and a stair (solid collision) out into the town; the first bay south of the gate has a timber lean-to at its foot |

## For the next round (design work, not settings)

1. **(done 14 Nov, see above)** **The March Wall reads as wallpaper.** One block size, one course height, no string course, plinth batter,
   corbelled parapet or machicolation; at the gates the gatehouse is the same wall made taller. A wall this long
   needs rhythm: towers that step forward, a battered base, a parapet that oversails on corbels, and gatehouses
   with a deep arch and a portcullis slot. (Blender kit pieces: wall bay, tower, gatehouse.)
2. **(done 14 Nov)** **The gate passages are black voids.** The kindled gate posts stand 6 m inside; until they are lit the one
   opening in the wall reads as a hole. A recessed arch with a lit keystone lamp (or a lantern hung in the vault,
   kindled with the posts) would make the gate legible from the road.
3. **Hearthward's square has one wall.** (Done, 14 Nov: `core/world/realm/lore/hearthward_square.gd`. The Hollow
   Lantern holds the east; two awninged stalls and a third against the wall close the west and the south-east; a
   roofed timber gate stands where the road's two arms meet, with a low stone wall each side; a stepped market cross
   stands off the brazier. The road to the stair stays open. Models: `tools/blender/props_market.py`.)
4. **The White Pans have no middle ground.** Between the wanderer and the mountains there is a flat white floor
   and lamp posts at prop scale. Salt sheds, drying racks, carts and heaps at building scale would give the
   flat a depth and a measure.
5. **A lamp post on the chapel's axis.** It stands dead centre in front of the facade; it belongs to one side
   of the approach.
6. **(done 14 Nov)** **Weirford beside its gate.** The houses now stand at WoW scale (1.4-1.6x) but the gatehouse beside them
   reads as a sheer wall: the town and the wall do not meet (no lean-to, no stair, no wall walk).
7. **Building scale outside Weirford.** Only Weirford was rebuilt at WoW proportions; Saltmarket and the
   outposts are still the old size beside trees that are now twice as big. (Hearthward's five cottages and ruins
   are 1.4-1.45 x since 14 Nov: `scale_pilot.gd` HW; its forge lean-to is still the old size.)

## Good, keep

- The chapel ruin (the Chapel of the First Kindling): pointed arches, buttresses, a broken skyline, a stone
  plinth that grounds it; the best silhouette in the Realm.
- Hearthward's axis: the road runs straight to the Pilgrims' stair between the two great braziers.
- Weirford's quay: a coursed stone embankment with a parapet, the mill and its wheel as the anchor.
- The salt crystal clusters in the pans and the Star Crater: strong, readable shapes against the night.
