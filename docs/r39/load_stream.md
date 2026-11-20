# r39 lane B: load-stream (build near the wanderer first, the rest behind)

Live checklist for `docs/r39/briefs/load_speed.md` Lane B. Branch `load-stream`. Honest summary first:

**The streaming works, and it is off by default, because it cannot meet the play-time budget.** What shipped on by
default is the loading screen no longer waiting for the post-build passes before its tour (about 2 s of wall time).
The time-to-control target (under 10 s) is not met: control is ~28 s (baseline ~30 s), and the 16 s Realm build is
unchanged by this lane.

## Measured (warm caches, `godot --path . --always-on-top -- --loading`, M4 Pro, 20 Nov)

| | baseline (c725b70a) | lane A merged + this lane (default) |
|---|---|---|
| Realm built (from the build's start) | 17.4 s | 14.7-16.1 s (lane A's caches; machine load varies) |
| settle (render pass + merge) | 4.0 s, before the tour | ran beside the tour: 1.3-1.6 s |
| control (`LOADING done`, wall from process start) | ~30.3 s | 28.15 s (f2.log) |

Streaming experiments (`--stream`, flora only; placement data global, nodes streamed, 170 m build ring):

| | ring first, queue pumped in play | ring first, queue drained under the cover | all at once (default) |
|---|---|---|---|
| flora nodes | 0.45 s ring + 25-28 s of slices over 75-83 s | 0.45 s + 2.4 s | 1.77-1.86 s in the build |
| control (wall) | 26.5-26.8 s | 30.1 s | 28.15 s (with the passes beside the tour) |
| frames over 16 ms (after a slice) / worst | 69-107 / 32-35 ms in 5,600-6,400 frames | 0 | none |
| worst piece | 9-12 ms | 14-20 ms (hidden) | |

Why streaming into play does not fit: `ch.add_child(MultiMeshInstance3D)` of a flora batch costs 0.11 ms in the build's own
block of adds (no frame drawn between), 0.33 ms when frames are being drawn under the cover, and 2.4 ms on average (up to
9 ms) while the wanderer plays; an empty Node3D or an unranged MultiMeshInstance3D added to the same chunk costs 4 us, so
it is the flora's mesh/material instance creation meeting a busy GPU. A `custom_aabb` on the MultiMesh (to avoid a buffer
read-back) did not change it. One add per frame still gave 69 slow frames; the budget cannot hold, so by the brief's own rule
(a faster load that adds hitches is a failure) the default builds everything in the build.

## What is in

- `core/world/realm/realm_stream.gd` (`RealmStream`): one node per night; `submit(root, pos, job, tier)` runs a job now (inside
  `RING_R` = 170 m of the wanderer, tier -1 = always, or when there is no stream) or queues it; `start_pumping()` runs the
  queue nearest-first (re-sorted as the wanderer moves), `BUDGET_US` 2 ms a frame in play, 9 ms under the cover, no slice on a
  frame already slow; `ensure(pos, r)` builds a ring now; `focus(pos, s)` prioritises a respawn's fire during its fade;
  `drain()`. Counts the frames over 16 ms that follow a slice. On only with `--stream` (or `RealmStream.force_on`, the test).
- `flora_emit.gd`: the emit is pieces (a kind's mesh in a chunk, a stone batch, a canopy shell); built in place in the old
  order (one piece per kind and chunk, all its meshes) or, with a stream, one per mesh. Tall trees and shells are always
  built at once (they show to the horizon). Chunks built late get the host's detail level and the secrets' cleared discs.
- Consumers moved off flora nodes: `LifePlace.trunks` reads the emit's `trunks` meta (equal to the cylinders, tested);
  `Kit.flush_flora` keeps its discs as `clear_discs` meta (lane A's threaded scan kept) and `Kit.clear_in_chunk` clears late
  chunks; `FloraFight` re-collects when the host's `flora_serial` changed.
- Jumps: `PlayerLocomotion.teleport` calls `ensure` for the target; a hollowing calls `focus` on the fire at once.
- The loading screen: the settle phase waits for `post_ready` (occluder, flora detail, light policy) and the tour starts;
  the render pass and the merge (`atmosphere.gd` PASS_COVER_US, `mesh_merge.gd` SLICE_COVER_US: 24 ms slices under the cover,
  2 ms in play) run beside it; `steady` waits for `post_done` (and the stream's drain when there is one). Wall-clock stamps
  on the `LOADING` lines.
- `zz/stream_test.tscn` (stream forced on, headless): ring built, far undergrowth queued, a teleport builds its ring,
  drain empties the queue, node counts equal the emit's, trunk records equal the cylinders.

## What is not done, and why

- Control under 10 s: the build is 15-16 s of main-thread node and mesh building spread over every module (assets 3.5 s,
  lore 1.3, wonders 1.1, wayside 1.4, village 0.5, life 0.75, bosses 0.8, rift 0.65 ...). Those are the places' own builders
  (lane A's files; they register sites that the flora placement reads, and add chests, discovery and quest objects), so they were
  not deferred; and anything added to the scene while frames are drawn would meet the same 2-9 ms adds.
- The terrain tiles are not streamed: the terrain is drawn by its tiles alone (the whole mesh has no render layer), so a
  tile missing is a hole; and the tour needs them. Their cut is not on the profile's top.
- Flora pieces in play were measured only with `--stream-play`'s equivalent (the streamed drain in s4-s10 logs).

## Checklist

- [x] baseline measured (warm, wall-clock)
- [x] RealmStream + flora emission as pieces, consumers moved to data
- [x] teleport / respawn ring
- [x] render pass and merge beside the tour
- [x] streaming measured in play and under the cover; default off
- [x] merged lane A (kit.gd conflict resolved: lane A's threaded scan + discs kept)
- [ ] tests (quick + stream, flora_r34, secrets, life)
