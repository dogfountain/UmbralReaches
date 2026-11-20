# r39 lane A: load-bake (bake the placed world, then thread what is left)

Brief: `docs/r39/briefs/load_speed.md`. Branch `load-bake`. Live checklist: tick as each lands.

## The cache

`core/world/realm/placement_cache.gd` (new) is the one door every cached placement pass goes through.

- **Key** = SHA-256 of: the pass name, the `--no-*` switches, the salt of every script under `core/world`, `core/life`, `core/enemy`,
  `world/areas/ossuary` (one code hash: any edit re-solves every pass, never a stale world), the ground digest, the layout tables,
  the camps/slots/raids, the reserved places, `WorldLanes.sites` as registered so far (every earlier pass left the same world), and
  whatever the pass names in `extra` (braziers, the flora fingerprint, the camps).
- **Store** = `GenCache.save_var/load_var` (the `_salts.bin` manifest decides trust in an exported pack, as for the land cache).
- **Off**: `-- --no-placement-cache` or `UMBRAL_NO_PLACEMENT_CACHE=1` (the A/B for the load laps).
- **Equality**: `PlacementCache.verify = true` (zz/placement_cache_test) solves on a hit and compares; on a miss it compares the solve with
  what it reads back from disk. `PCACHE` line in the load log lists each pass: hit / miss / match / MISMATCH.

## Passes

- [x] wayside plan (`realm_wayside.gd` `plan_now`: `_solve` / `_adopt`)
- [x] camps planted on the ground (`enemy_spawner.gd` `_camp_picks`)
- [x] camps settled on the final ground (`enemy_spawner.gd` `_settle_picks`)
- [x] ambush sites (`ambush_sites.gd` `plan_stored`)
- [x] site dress spots (`site_dress.gd` `_zone`), terrain settle floor samples (`terrain_stamp.gd` `_floor_picks`)
- [x] wonders: already stored per family (`wonders/r39/wonder_plan.gd`); what is left is node creation
- [x] secrets' flora clearance: threaded (`secrets/kit.gd` `flush_flora`, 138 -> 55 ms)
- [x] lore, POIs, lamps, nav: profiled, no search worth storing (lamps 65 ms; lore 0.9 s and POIs 1.5 s are node/mesh building; nav is cached, 50 ms)
- [x] equality test `zz/placement_cache_test`

## Profile and laps

Headless, this Mac, everything else cached (land, flora, nav): `REALM built in`
- before (`--no-placement-cache`): 12253 ms. Wayside plan 786, camps plant 142, terrain settle 854, site dress 392, ambush 35, camps settle 24.
- after: 10397 ms. Those passes: 0 / 13 / 156 / 34 / 1.5 / 2 ms.
- cold (every entry missing): ~21 s (land and flora rebuild); a realm-folder edit re-solves land (9 s) and flora (11 s) as well.
- The 16.2 s the lead saw is the same build under load/windowed; what is left (assets 1.8 s, flora emit .6, lore .9, bosses .7, life .7,
  wonders .7, rift .55) is node and mesh building on the main thread: lane B (streaming) territory.

## Files touched outside the lane

- `core/world/realm/realm.gd`: `PlacementCache.reset()` at the build's start and the `PCACHE` summary line (3 lines).
- `core/life/encounters/director.gd`, `core/enemy/enemy_spawner.gd`: the ambush and camp passes (these are the lane's placement code).

## Not done / why

- Windowed timing: a windowed Godot in the background is throttled by macOS, so only headless laps are reported.
- C++: nothing profiled is a hot loop after caching.
- The shipped `art/realm_cache` is not re-baked here (binary, and every lane's edit invalidates land/flora): bake after the three merges.
