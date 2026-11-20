# r39 lane B: load-stream (build near the wanderer first, the rest behind)

Live checklist for `docs/r39/briefs/load_speed.md` Lane B. Branch `load-stream`.

## Baseline (warm cache, `godot --path . -- --loading`, M4 Pro, 20 Nov)

| | |
|---|---|
| first frame | 1.8 s |
| Realm built (modules) | 17.4 s after the build starts |
| flora emit (`FLORA ... nodes`) | 1.77 s (10,600 multimeshes, 1,416 colliders) |
| post-build render pass + merge (settle) | 3.8 s + 1.1 s (188 frames) |
| warm tour / panels / steady | 2.5 s / 1.5 s / 0.6 s |
| control (`LOADING done`) | about 28 s of wall time |

## Design

- `core/world/realm/realm_stream.gd` (`RealmStream`, one node per night under the zone): builders hand it small jobs
  with a position; jobs inside RING_R (150 m) of the wanderer run at once, the rest are queued and run nearest-first
  (re-sorted as the wanderer moves), BUDGET_US = 2 ms a frame in play, 9 ms under the loading screen, nothing on a frame
  over 22 ms. `ensure(pos, r)` builds a ring now; `focus(pos, s)` builds a respawn's fire ring during its fade.
- Headless and the tests keep build-all-now (no stream node is made; `submit` runs in place). `--stream` turns the
  stream on headless, `--build-all` turns it off in a window.
- The placement data stays global: `RealmFlora._final_items` / stones / canopy are kept until the last piece is built.
- Flora (`flora_emit.gd`): one piece per (kind, chunk), stone batch, canopy shell; same order as before when built in place.
  Chunks built late get the host's detail level (`late`) and the secrets' cleared discs (`Kit.clear_in_chunk`).
- Consumers that read flora nodes during the build now read data: `LifePlace.trunks` reads the `trunks` meta the emit
  lists before any node exists; `Kit.flush_flora` keeps its discs as `clear_discs` meta for the chunks still to come;
  `FloraFight` re-collects when `flora_serial` changed.
- Jumps: `PlayerLocomotion.teleport` calls `ensure` for the target (fast travel, tether, respawn); a hollowing calls
  `focus` on the fire at once, so the ring is built during the fade out.

## Checklist

- [x] baseline measured
- [x] RealmStream + flora emission streamed, consumers moved to data
- [x] teleport / respawn ring
- [ ] terrain tiles
- [ ] post-build render pass and merge out of the settle
- [ ] loading screen gated on the ring
- [ ] equality: trunks from data = trunks from nodes
- [ ] end measurement, tests
