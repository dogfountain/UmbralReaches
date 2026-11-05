# r34 places: points of interest, fires, secrets, lore in the new ground

Written by the PLACES agent (r34 phase 2). Positions below are **as built** (headless build of the
current tree); the builder searches round each preference for clear ground, so they can move a few
metres if the ground or the camps change. Read them in code from `RealmPoisR34.spots[id].at` and
`RealmPoisR34.floors[floor_id]` rather than hard-coding.

Code: `core/world/realm/realm_pois_r34.gd` (reserved and built by `realm_pois.gd`, same API and
groups as r31), fires in `core/world/realm/realm_bosses.gd` (`R34_FIRES`), lore texts in
`core/world/realm/lore_db.gd`, lore scenes in `core/world/realm/lore/r34_places.gd`, secrets in
`core/life/secrets/site_r34.gd`. Test: `zz/places_r34_test` (also climbs every route with the wanderer).

## How to hook in (the r31 contract)

- Each place: Node3D `RealmPois/Poi_<id>` in group `"world_poi"`, metas `poi` (id), `title`, `line`,
  `centre` (Vector3, ground), `radius`, **`region`**, `r34` (true). Climbable ones have `route`,
  `walk`, `approach`.
- Fighting floors: Node3D in `"miniboss_site"` and `"guardian_site"`, metas `id`, `poi`, `radius`,
  `region`, `floor_y`, `site_key` = `"poi_<floor id>"`, no `guardian` meta (picked by region). Each is
  levelled by the stamp (WorldLanes terrace `poi_floor_<id>`), 3.5 m+ off camps, 9 m+ off fires.
  **The Rooted Holds have no floor** (a haven; Old Rook circles it).
- Chests: group `"loot_chest"`, meta `chest_id`, `tier`; loot in `RealmPoisR34.LOOT`.
- Discovery: every place is a subzone (`sub_poi_<id>`); the EXTRA spots below are subzones `sub_<id>`.
- World events: surges can rise at every place and every EXTRA spot.

## Places (14)

| id | name | region | centre (built) | chest (tier) | fighting floor (built) | climb / traversal |
|---|---|---|---|---|---|---|
| `quarry_crane` | The Unfinished Stair | quarry | (-125.5, 0.9, -100.7) | `quarry_jib` (iron) on the crane deck | `quarry_pit` (-137.5, 0.9, -101.0) r 7 | four giant blocks to the deck (8 m); grapples on the mast and jib; perch off the deck |
| `quarry_winch` | The Winch-House | quarry | (-138.5, 1.0, -114.7) | `quarry_winch` (wood) | — | block to the roof; grapple post; tread-wheel and rope |
| `holds_hall` | The Hall-Mound | holds | (-124.0, 1.0, 10.0) | `holds_hall` (iron) by the high seat | — (haven) | walk the earth banks to the turf ridge; grapple on the gable |
| `holds_houses` | The Earth-Houses | holds | (-118.0, -0.6, 25.8) | `holds_house` (wood) inside the open house | — (haven) | three walk-in turf domes |
| `foundry_furnace` | The Bell Furnace | foundry | (131.4, 2.5, -113.0) | `foundry_relic` (reliquary) on the charging floor (14.5 m) | `foundry_floor` (114.5, 3.1, -114.3) r 7 | outside stairs, a broken flight (corbel grab); the mouth's updraft lifts a glider to the top; perch |
| `foundry_pits` | The Casting Pits | foundry | (126.7, 2.8, -95.5) | `foundry_mould` (iron) in the fourth bell's mould | — | two warm pits with updrafts, a gantry |
| `moor_tor` | The Cairn Tor | moor | (141.0, 13.9, -24.0) | `moor_tor` (iron) on the watcher's seat | `moor_foot` (144.5, 8.8, -11.0) r 6.5 | two stone steps to the seat; nine guide-cairns |
| `moor_shrine` | The Lanternless Shrine | moor | (142.3, 6.6, 16.3) | `moor_shrine` (wood) in the niche | — | |
| `orchard_press` | The Press-House | orchard | (-128.0, 0.6, 132.0) | `orchard_loft` (iron) in the loft | `orchard_yard` (-111.8, 1.3, 128.7) r 6.5 | vats to the loft (4.4 m); grapple on the gable |
| `orchard_heart` | The Mother Tree | orchard | (-84.2, 0.8, 116.3) | `orchard_hollow` (wood) in the hollow trunk | `orchard_ring` (-68.2, 0.9, 116.3) r 6 | walk into the burned giant |
| `necro_mausoleum` | The First Pilgrims' Tomb | necropolis | (5.0, 0.5, 141.7) | `necro_vault` (reliquary) in the vault | `necro_forecourt` (22.0, 1.0, 140.2) r 7 | a small interior: tomb house, stair down into the burial vault; a block run up the west side to the roof; perch |
| `necro_ranks` | The Pilgrims' Ranks | necropolis | (-17.2, -0.8, 113.8) | `necro_lodge` (wood) in the warden's lodge | — | the Ninth Rank secret is behind it |
| `mere_chapel` | The Half-Sunk Chapel | mere | (79.0, -1.3, 112.0) | `mere_loft` (iron) in the bell loft (8 m) | `mere_hummock` (96.0, 0.3, 112.0) r 6.5 | plank causeway from the bank; tracery heaps, the wall top, two corbels to the loft; floating lamps; perch |
| `mere_landing` | Corvin's Landing | mere | (136.3, 0.6, 125.7) | `mere_landing` (wood) in the loft | `mere_bank` (137.7, 0.6, 138.7) r 6 | stair to the loft; jetty; Corvin's Sluice lever |

Landmark beacons (faint, `landmark_beacon` group, meta `poi`): the furnace, the tomb, the chapel, the crane.

## Named spots without a building (`RealmPoisR34.EXTRA`: subzones and surge grounds)

| id | name | at (xz) |
|---|---|---|
| `quarry_benches` | The Cutters' Benches | (-112, -112) |
| `moor_cairns` | The Guide-Cairns | (136, -46) |
| `orchard_rows` | The Black Rows | (-118, 112) |
| `field_ranks` | The Long Ranks | (14, 126) |
| `mere_reeds` | The Lamp-Reeds | (116, 136) |

## Fires (Ember Road stops and checkpoints)

`Zone/Braziers/<name>`, copies of a valley fire made unlit by `RealmBosses._r34_fires` (kindles
restored by name). Names on the Road and the map come from the region ("The Saints' Quarry fire").

| name | region | at (xz) | nearest camp (built) |
|---|---|---|---|
| `QuarryFire` | quarry | (-120, -83) | 18.4 m |
| `HoldsFire` | holds | (-138, 15.5) (moved off the slot: the holds stand east of west_track) | 24.7 m |
| `FoundryFire` | foundry | (123, -76) | 26.1 m |
| `MoorFire` | moor | (126, -8) | 20.6 m |
| `OrchardFire` | orchard | (-99, 104) | 22.5 m |
| `FieldFire` | necropolis | (8, 108) | 20.9 m |
| `MereFire` | mere | (103, 98) | 18.0 m |

## Secrets (`core/life/secrets/site_r34.gd`, state in the secrets' own save)

| id | name | where (built) | kind |
|---|---|---|---|
| `cutters_nook` | The Cutters' Nook | a 6.6 m stack of offcuts on the pit floor ~12 m from the crane deck, (-129, 7.6, -112) | climb-only: the Tether from the crane deck, or a glide off it; strongbox + page |
| `ninth_rank` | The Ninth Rank | three graves behind the Pilgrims' Ranks | puzzle: light the grave-lamps in the order the warden's slate gives (Ilse, Tam, the child); the end tomb's lid slides off its cache |
| `corvin_sluice` | Corvin's Sluice | a high islet off Corvin's Landing's jetty | lever in the boat-house raises a sunk stone walk; Corvin's lamp-box |

## Lore

61 new texts in `LoreDB.TEXTS` (regions quarry, holds, foundry, moor, orchard, necropolis, mere: 8-9
placed stones each), two new series (`founder`: the Founder's Daybook, 3 parts; `lamplog`: Corvin's
Lamp-Log, 3 parts), four secret pages in `pages.gd`. The seven region ids are in `LoreDB.REGION_ORDER`
(the Journal's Places tab). Dressing in `r34_places.gd`: the Waiting Field's grave blocks, guide-cairns
every 26 m along moor_track, the orchard's row-stones, lamp-posts in the mere.
