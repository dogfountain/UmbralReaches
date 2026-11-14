# Decisions

A ledger. Newest at the bottom. Status: adopted, open, reversed.

| Date | Decision | Status |
| --- | --- | --- |
| 2026-11-05 | Phase = consolidation. No new systems; fix, cut, polish, playtest. | Adopted |
| 2026-11-05 | Target = a 30-minute slice first; everything else sits behind a `--full` flag. | Reversed 2026-11-06 |
| 2026-11-05 | The four pillars in `docs/PILLARS.md` are the test for what ships. | Adopted |
| 2026-11-05 | Horses are hidden from the slice behind `--full`. | Reversed 2026-11-06 |
| 2026-11-05 | Bells: all seven stay for now (four of seven wake the summit door). | Open |
| 2026-11-05 | Item level, gear sets and rested XP stay (Luke, 5 Nov). Do not cut them. | Adopted |
| 2026-11-06 | The full night is the default (Luke). The 30-minute slice stays available with `-- --slice` for first-time players and tests. | Adopted |
| 2026-11-06 | Consolidation ends: the Realm doubles to 520 x 390 m (the Outer Marches, the Southern Downs), filled with existing systems and in-house assets (docs/r37_expansion.md). Bosses may be new BossKit scripts over existing rigs. | Adopted |
| 2026-11-06 | Far detail: big things stay loaded at very low detail and fade in, rather than popping in at range. | Adopted |
| 2026-11-06 | On horseback the jump key makes the horse jump; you get down with the interact key. | Adopted |
| 2026-11-06 | r37 Foundation: the camera sees 420 m (was 82); trees cross-fade near -> far -> a canopy shell per chunk; the Realm's other meshes get size-ranged dither-fade visibility (FarDetail); the Sorrow is re-routed off the Hierarch's raid floor and siege_track; the old Realm's heights, trees, undergrowth and wildlife streams are kept, the new ground draws from streams of its own. | Adopted |
| 2026-11-06 | Creature sound is rendered in-house by `tools/gen_enemy_sfx.py` (numpy; layered body / formant voice / transient / tail; 3-4 takes per act per voice set) and played by `EnemyAudio`; no samples, no downloads. Open-air reverb follows the region (open land, wood, cliff, the Well); rooms still override it. | Adopted |
| 2026-11-07 | Lamps: ~70 small lights the wanderer kindles (hanging lamps, candle niches, standing lanterns, tower cressets) and four others keep (a pilgrim's fire, the ferryman's lamp, a hunter's shuttered lantern, a window lit in the press-house). They are comfort and wayfinding, never gameplay light: not in LightGrid, no Gloom cleansing, no rest or checkpoint, so the dark stays the clock. Unlit until lit, saved (State "lamps"), a little ash for each first light, lit ones marked on the map with a tally. | Adopted |
| 2026-11-14 | The Ossuary moves from the rift's east wall (beside the stair boss) to the Waiting Field: a quarried bone pit cut into the field's south slope, the tiers hung on piers over a still pool, the Counting Stair and the Bone Abbot's hall under the Southern Downs. The summit stays the finale at the top of the map; the chain lift and the fen door are gone. Luke: "all bosses are on the top of the map" (ring plan; the Hierarch moves to the Siege Lines). | Adopted |
| 2026-11-14 | The Fallen Hierarch's fight moves from the north-west valley to the Siege Lines (Luke: all the bosses were in the north): the Marches hauled the colossus south to their lines and dug in round him. The valley becomes The Empty Plinth (tier 2), his plinth and feet left standing; the Siege Lines are tier 3. | Adopted |
| 2026-11-14 | The March Wall and its gates are rebuilt as masonry with a section (battered footing, string course, corbelled parapet), forward towers and drum-towered gatehouses with a lit vault; Weirford gets a stair and a lean-to against the wall (docs/ARCH_REVIEW.md). | Adopted |
