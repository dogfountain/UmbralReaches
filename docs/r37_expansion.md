# r37: the Outer Marches

Luke, 6 Nov 2026: double the Realm's area and fill the new ground with what the game already does
(bosses, mini-bosses, people, quests, secrets, lore, camps, fires), with landmarks unlike anything on
the map now and new assets made in-house. The numbers are in `core/world/realm/realm_layout.gd`
(BOUNDS, OLD_BOUNDS, REGIONS, RAIDS, SLOTS, BASE_PATHS, RIVER, LAKE_*, WELL_*, MARCH_*): that file is
the contract.

## The shape

The old Realm (x -155..155, z -150..175) is unchanged. It grows to x -260..260, z -150..240
(520 x 390 m, 2.0x the area): past the West and East Gates into the **Outer Marches**, and south of
the Waiting Field into the **Southern Downs**. The Crowns stay the north wall the whole width.

The r34 edge rims at x +-155 become the **March Wall**: the old Realm's boundary wall, gates where the
Pilgrims' Road crosses it, breaches where tracks do. Beyond it the Marches: the country the Order
shut out.

| Region | Where | Landmark (new kind of place) | Content |
| --- | --- | --- | --- |
| Weirford | road x -205 | a living outpost town at the river crossing: stone bridge, weir, watermill, inn, smithy, stables | 6-8 people with routines, quest hub, watch post (sword NPCs), fire |
| The Sorrow's Banks | west, north of town | a river valley (the Sorrow) with fords and alder banks; a drowned shrine | camps, rares, a secret, fire |
| The Empty Plinth | NW at the Crowns' foot | the moss valley the Hierarch's colossus stood in: his plinth, the two stone feet still on it, a hauling ramp, the furrow of rollers south | camp, a rare (the Moss-Mason), fire |
| The Siege Lines (the Fallen Hierarch) | SW | the toppled colossus (about 60 m) lies at the middle of earthwork rings, palisades, rotted trebuchets and a siege tower you climb, all drawn round it; walk its body; the head split open | BOSS in the broken crown (RAIDS "hierarch"), 3 camps, named mini-boss (the siege-captain), fire |
| Stillwater | east | a cold lake under a bluff; the Lamplighters' Spire, a climbable beacon tower; relighting its lamp is a quest | camp, sunken boat-house, a secret, fire |
| The Anchorholds | NE in the Crowns' face | hermits' cells cut into the cliff, ladders, walkways, a cliff chapel | BOSS on the cliff terrace (RAIDS "anchorhold"), fire |
| Saltmarket | east road fork | a salt-workers' hamlet | 4-6 people, trader, quests, fire |
| The White Pans | SE | salt flats: evaporation pans, timber derricks, a salt-works, crystal crusts (biome "salt") | 2 camps, named mini-boss, a secret |
| The Southern Downs | south strip | open chalk downs, a shepherds' hut and fold | 2 camps, rares |
| The Grandmother Oak | south-west | a colossal hollow dead oak: a stair inside the trunk, walks along the great limbs | named mini-boss, a secret at the top, fire |
| The Well of Echoes | south-east | an open sinkhole ~40 m across, 24 m deep, a waterfall in, a ledge path down to a pool and a cave | named mini-boss below, a secret, fire |

Totals: 2 bosses, 4 named mini-bosses (elite_kit), ~14 camps, rares per region, 10-14 people,
8-10 quest chains, 5 secrets, a fire per region (Ember Road stops), lore and codex places for all.

## Rules for every agent

- **Existing systems only.** BossKit/BossArena for bosses, elite_kit for mini-bosses, rares, camps
  (encounters tiers/variants/guardians), village/villager routines and talk, watch posts, stables,
  quest_chains step kinds, secrets sites, lore_db and the codex, braziers/fire_spot for fires. No new
  autoloads, no new frameworks. A boss is a new script on BossKit over an existing rig family
  (hunch_rig, quad_rig, grunt_model, creature_mesh) with new in-house meshes; that is allowed this round.
- **Assets are made, not downloaded.** Blender by script (tools/blender, the umbral-blender skill),
  procedural textures and bakes, realistic (docs: the Enshrouded-level bar). No CC0, no downloads.
- **Budgets.** 120 fps on this Mac in the new ground; ~1.5M primitives in view; every big landmark has
  LODs and a low-detail far mesh (see Far detail). The Realm build must stay under ~40 s (it is ~23 s).
- **The pillars** (docs/PILLARS.md): the dark is the clock, warmth is earned (the Spire's lamp is lit
  by the player, never for free), the world teaches.
- Binding don'ts stay (.cursor/rules, the umbral-donts skill): glow levels, four stair fires, no
  Engine.time_scale = 0, never headless-rebake world/main.tscn, NPC voices stay babble, and so on.
- Put new content in new files named for your area (e.g. `realm_pois_west_marches.gd`,
  `quest_chains_west_marches.gd`, `site_west_marches.gd`). Where a shared registry must list it (quest chains,
  lore_db, elites, guardians, realm_bosses, codex), add ONE block marked `# --- r37 <area> ---` at the
  end of the list, so the lead can merge four branches cleanly.

## Far detail (the Foundation agent)

Things must not pop into existence on the horizon. The camera sees `FarDetail.VIEW_FAR` = 420 m (it was 82); the fog
swallows the world by then. Terrain is whole (one mesh + the horizon ring); trees go near mesh -> `@far` mesh
(cross-faded) -> a canopy shell per forest chunk, all to the horizon; everything else the Realm builds gets a
visibility range by size with a dither fade (< 1.5 m ends 70 m, < 5 m 130 m, < 14 m 240 m, bigger never ends);
grass and small clutter keep their short ranges and thin out. Nothing is a hard cut.

For a landmark (tower, wall, statue, hall) give it a far mesh and register it (core/world/far_detail.gd):
`var far := FarDetail.hull(aabb, taper, color)` (a ~12-triangle box, tapered to a point for a tower or a roof; or
your own 100-300 triangle Mesh) then `FarDetail.register(host_node, far, local_xf, near_end := 90.0)`. It draws
from `near_end` out to the horizon and fades the host's own meshes out at the same distance (`FarDetail.near_ends`
does that alone). A registered mesh sits in group `cull_skip`: nothing re-ranges it. Meshes bigger than 14 m with
no registered far mesh are never ranged, so they draw at full detail out to 420 m: give big landmarks LODs
(MeshChunks) or a far mesh.

## The ground, as built (the Foundation agent)

Heights inside OLD_BOUNDS are the r34 heights (the rim at x +-155 is a 3.5 m crest, the March Wall's line; the
downs' 7 m rise stays for |x| < 155 and fades out over x 155..180). Use `RealmLayout.ground(space, x, z)` for
heights. What each place stands on:
- The Sorrow: `RIVER.pts` (re-routed: it rises from a spring at (-212, -56), crosses the road once at Weirford
  z~64, leaves at (-254, 240)). Channel half width 6 m, bed `RIVER_DEPTH` under the water. Reaches stand at
  `RealmLayout.river_level(z)`: 0.6 at the head, falling by `RIVER_STEPS`; the weir is the 0.5 m drop at z 60.
  `RealmLayout.river_mask(x, z)` is 1 in the channel (the road is not levelled across it: build the bridge deck
  from the banks, ~0.5). `Land.water_y_at(x, z)` and `Land.in_water(x, z)` answer for every kind of water.
- Stillwater: the basin is cut at `LAKE_C`/`LAKE_R`, water at `LAKE_Y` (-0.9), 5 m deep at the middle; the Spire's
  bluff is a plateau (r 8 m) at `SPIRE_Y` = 11.1 with steep walls into the lake. spire_track runs over the lake's
  south-east corner on a causeway (paths never go under water).
- The Well: pit centred `WELL_C`, floor `WELL_FLOOR_Y` -17, pool `WELL_POOL_Y` -16.2 inside r 9, walls steep up to the
  rim at r `WELL_R`. The pit gives way within 4 m of a path, so downs_track passes on the rim (a drop beside it).
- White Pans: `PANS` is flat (0.3) with shallow evaporation beds and 0.3 m bunds on a 20 x 14 m lattice; biome "salt"
  (own ground textures, footsteps, wind ambience, sparse dead brush). Weirford and Saltmarket are flattened (0.6).
- Siege Lines: one earthwork ring round the fallen Hierarch (`SIEGE_RINGS`, centre his skull (-206, 148), r 43): a 2.1 m
  bank and a ditch outside, open at the bearings listed as breaches, running out at the river and at the March Wall's
  foot. The old Hierarch valley (now the Empty Plinth's) keeps its 11 m flanks, with no raid floor in it. The Anchorholds' face is
  10 m higher so the terrace (y 16) is a shelf. The Grandmother Oak stands on a 3 m knoll (`OAK_C`).
- Encounter tiers for every new region are in `Tiers.REGION_BASE`; mist banks, ambience, flora looks (RealmFlora
  `LOOKS`), wildlife (extra herds, foxes, hares, owls, frogs and flocks from their own streams) cover the new ground.

## West Marches (the West agent)

Built in `core/world/realm/realm_pois_west_marches.gd` (reserve before the stamp and flora, build after), hooked by
the `# --- west marches ---` blocks in the shared registries. Assets are made by script in `tools/blender`
(`r37_west_textures.py`: seamless procedural PBR sets; `r37_west.py`: statue, mill, bridge, palisade, trebuchets,
siege tower; `boss_hierarch.py`: the boss) and placed through `west_marches_kit.gd` (tiling `art/textures/r37_*`
sets over `<part>__<set>` meshes, `<asset>-colonly` collision, vertex-colour macro tone).

- **Weirford** (road x -205): the stone bridge over the Sorrow, the weir and a working mill (the wheel turns:
  `mill_wheel_spin.gd`), the Grey Heron inn, the smithy, two cottages, stables (the Weir Cob, `horse_db.gd`), the watch
  post (`watch_posts.gd` "weirford", three sword watchmen), a covered well, a stall, lit windows without lights, an
  Ember Road fire (`WeirfordFire`). Eight people with routines and babble talk: `village_cast_west_marches.gd`
  (merged by `village.gd` `cast_all()` and the nodes/edges), `village_talk_west_marches.gd`.
- **The Sorrow's Banks**: the drowned shrine in the river (a chest and the secret *Aldith's Walk*,
  `core/life/secrets/site_west_marches.gd`: an iron ring raises a sunk walk to a lamp-islet and a box), ford posts,
  two camps, a rare (the Drowned Reeve), a fire (`SorrowFire`).
- **The Fallen Hierarch** (moved from the north-west valley to the middle of the Siege Lines, Luke 14 Nov: the bosses
  ring the spawn, one in each quarter; `core/world/realm/realm_pois_hierarch.gd` builds him, the hand and the plinth).
  The story: the Marches could not take the Order's gates, so they pulled its colossus off his plinth and hauled him
  south on rollers to their lines, and dug in round him. `r37_statue.glb` (head shell ~28 k tris, torso and arm ~10 k, debris; the engine
  generates mesh LODs on import) plus a separate ~1.6 k-tri far mesh node `StatueFar` (meta `far_mesh`, fades in from
  330 m while the near model fades out from 420 m; the Foundation's far-detail hook can replace it). The skull is a
  hollow bowl split open round the raid floor; the body lies away from it (`BODY_DIR`); the open hand is a POI with a
  stair of fallen blocks and a chest. Boss: **the Speaking Crown** (`core/enemy/hierarch_voice.gd`, a Husk rig with
  `boss_hierarch.glb`, 640 HP, 3 phases; room `core/world/hierarch_raid.gd`; id `r37_hierarch`, trophy `crown_shard`).
- **The Empty Plinth** (`r37_plinth.glb`, `tools/blender/r37_west.py --only plinth`): a stepped ashlar plinth with a dentil
  course and a band of cut letters, the Hierarch's two stone feet in the hem of his robe, cut through the shin (iron armature
  standing out of the breaks, chains wound round the ankles), a timber hauling ramp up its south face (walkable, to the
  feet), and five iron-bound rollers (`r37_roller.glb`) lying south of its ramp. Lore plaque `r37w_plinth`,
  the Watch notice, the mason's grave, the choirmaster's note; the camp, the fire (`HierarchFire`) and the Moss-Mason stay.
- **The Siege Lines**: the earthwork ring's palisade arcs and north gate (siege_track passes through it), three rotted
  trebuchets behind the palisade with every arm cocked on the skull (`r37_trebuchet.glb`), a four-storey siege tower on the
  east flank with its stairs built in (a chest on top) and its ramp running down toward the skull, three more camps, a rare
  (the Gate-Breaker), the mini-boss **Captain Varr, the Wall-Breaker** (`elite_siege_captain.gd`,
  `Elites.ELITES["siege_captain"]`), a fire (`SiegeFire`) outside the north gate. siege_track now arrives at the Speaking
  Crown's gate on the east side of the skull and runs on to the downs.
- **Quests** (`quest_chains_west_marches.gd`): The Stopped Wheel, The Lamp on the Lines, Lights for the Sunk, and
  The Voice in the Head (after the Wheel; ends in the boss). Lore: `lore/west_marches_texts.gd` (22 texts, a series,
  four codex places), placed by `lore/west_marches_places.gd` and the POIs.

Tuning notes: the statue's head is oversized so the raid floor (r 24) fits inside it; the whole figure is about
100 m long rather than 60. The bosses ring the spawn (0, 33): north the Ascended Warden's summit, north-east the Anchoress,
west the Thorn Henge, south-west the Hierarch, south the Ossuary. Switches: `--no-r37-west` (places, writings, secret).
