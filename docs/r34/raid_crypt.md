# r34 crypt raid: the Bone Abbot in the pit hall

Written by the crypt agent (r34 phase 2). Code: `world/areas/ossuary/oss_hall.gd` (the Counting Stair and
the pit hall, built at runtime by the Ossuary), `world/areas/ossuary/ossuary.gd` (the Counting Door, the
arena, the reward), `core/enemy/bone_abbot.gd` (the fight), `core/enemy/tally_reliquary.gd` (the
intermission's targets). Test: `zz/crypt_r34_test` (`-- --sim` for a scripted kill-time run). Shots:
`zz/crypt_r34_shots.tscn -- --out=<dir>` (`crypt_*.png`).

Design references: WoW raid rooms and encounters (a raid door that shuts on the pull, phases with an
intermission, a room-changing mechanic, adds with priorities, a soft enrage and a final burn, boss
emotes and cast bars), Enshrouded's look (warm candle-gold against cold dark, no neon). Adapted for one
player: every hit is told on the ground first and can be stepped out of, sheltered from or broken.

## The way down

| piece | where | notes |
|---|---|---|
| gallery seal `oss_gallery` | (21, 8.4, -66.7) | unchanged: the bone portcullis and its two guard camps |
| pit stair, charnel pit | (16, 4.2, -86), r 11 | unchanged, but no longer the arena; the chain lift still stands in it, held until the Abbot falls |
| the Counting Door | pit's east gap (~9 deg), threshold to x 29.2, z -84 | a gatehouse front on the bank (tally strokes over the door, skulls, lantern brackets), a walled cut (`fen_cuts` entry `oss_count_door`). The 2 m terrain grid cannot step from the cut to the bank over the door, so once the Realm is done the four ground triangles between are lifted (`Ossuary.punch_terrain`) |
| the Counting Stair | shaft x 29.2..36.4, z -97.2..-82.2, y 4.2 -> -32 | a scissor stair: eight 9 m flights (4.5 m each, 17 risers), landings north and south, a tally of strokes on every landing's wall (the flight's number). A grilled slit at the fifth landing (y -18.4) looks into the hall under its vault |
| the raid door | a corridor from the stair's foot (east door) through the hall's WSW wall, radial at ~146 deg | two bone grilles (arena gates): `abbot_gate` in the wall and `abbot_door` at the floor's edge. The fight starts 1.5 m past the inner one |

The walk from the pit floor to the inner grille is ~40 s (the test walks it with physics).

## The pit hall (`OSSUARY_HALL` reserve, x 26..82, y -38..-6, z -124..-68)

| feature | size | notes |
|---|---|---|
| centre / floor | (59, -32, -99) | everything is inside the reserve (checked) |
| wall | 16-gon, inner face r 22.5 (45 m across), 17 m to the cornice, ribbed vault to an oculus at y -8.6 (23 m) | niche rows above the galleries, two blind lancets per side with skull shelves |
| fighting floor | r 18.5 (37 m): inner disc r 10 + eight 45-degree sectors r 10..18.5 | sector 3 (the door's tongue) never falls |
| the Uncounted Deep | y -37.5 under the sectors | bone drifts; a fall throws you back onto the inner disc for 18 Gloom; adds die; the Abbot is set back on stone |
| galleries | tier A r 18.5..20.5 (1.6 m, a bone balustrade: 2.7 m, no mantle), tier B r 20.5..22.5 (4.4 m) | skull walls, femur courses, candles |
| side chapels | SE 45, NE 315, NW 225 deg: 5 m passages to apses at r 27.4 | each holds a Tally plinth (an empty iron cage at rest) |
| bells | E, S, W (190), N, hung at r 21.2, y -20 | bronze lathe meshes; they swing and boom for the Tolling |
| great ossuary mound | r 3.6, 5.6 m: a 2.6 m drum of skulls (past a jumping mantle), two tiers, a femur crown | the Tolling's shelter; the Abbot sinks into it |

Light (all unshadowed omnis): candle-gold corona over the mound (falloff flattened for the room's size),
eight gallery lamps, the mound's foot, the door; grave-light only on the Tallies' plinths and in the deep
once it opens. Buried meshes are on render layer 20 and the moon is told to skip it (the moon's shadow
reaches ~25 m, the hall is 30 m under the fen). While the camera is underground the rift's lava plane
(y -15.5, which reaches x 46 and would cut the vault) is hidden; the lava's kill box (which also reaches
the hall's west half) ignores the hall (`lava.gd` hook).

Streaming: the hall is part of the Ossuary area (already always loaded: `world/main.gd` load_r 400), built
time-sliced in six sections (~120 ms of GDScript in all). `PitHall` is drawn only while the player or the
camera is in the crypt (x 2..86, z -128..-20, y < 14); the stair is always drawn. `area_streamer.gd`
needed no change. Prop cells in the hall are 24 m (`OssKit.chunk`; the Ossuary's own stay 10 m): the
hall commits 240 draw calls in all (505 with 10 m cells). Windowed 1600x1000 on the owner Mac
(`zz/crypt_r34_shots`, indicative: the harness saves a PNG between views): 210-460 draws and 8-19 ms
frames in the hall's views and phases (one wide view over the whole floor: 720 draws, ~16 ms). Outside
the crypt the hall is not drawn, so the overworld's numbers do not change. The Ossuary's title card and the ambience (the crypt's reverb and muffle, no rain) cover
the hall as a second box.

## The fight (620 HP, was 160; 2.6x scale, was 1.8)

| phase | HP | abilities (cast names) |
|---|---|---|
| I the Vespers | 100-66 % | **Crozier Sweep** (75-deg cone, 7.5 m: never stand before him), **Ossuary Ring** (6.5 m round him, every 9 s), **Grave Spikes** (a disc under you), **The Tolling** (3.6 s, 45 Gloom, every 26 s: the bell over your side rings; the whole hall fills but the sound-shadow, a pale pool 6.6 m behind the mound, r 3.2) |
| intermission "The Count Is Taken" | at 66 % | he sinks into the mound (untargetable, a 45 s cast on the bar). Three **Tallies** (7 HP each) rise on the chapels' plinths and feed him on threads of grave-light; the dead climb out of the mound every 10 s (2 Uncounted / 2 Risen Faithful, capped). Break all three and he rises at once; each still standing when the count ends heals him 6 % |
| II the Choir | 66-33 % | **Hymn of the Choir**: two Choir of the Count (Chanters, 4 HP) at the floor's edge away from you; while one lives he takes half damage and every rite is 20 % faster (kill them first). **The Reckoning** (9.5 s, every 34 s): three gold plates; stand on each before the count ends, the bar counts them ("2 of 3 counted"); each missed raises a Risen Faithful and costs 14 Gloom. **Bone Rain** (2 s, every 15 s): three 4 m fields (one under you), then ossuary dust for 5 s. Raise the Faithful (interrupt: a heavy blow or one burst on the reliquary), Tithe Line, Grave Spikes in threes, the Tolling (28 s) |
| III the Requiem | 33-12 % | **The Floor Remembers**: sectors 0, 2, 5, 7 shake for 4 s (red discs) and fall, two at a time. **Requiem** (11 s; only two bursts on the reliquary break it), **Bone Cage**, Bone Rain, the Tolling (24 s), the Reckoning (four plates), the Choir once more, Raise the Faithful |
| IV the Last Count | 12-0 % | sectors 1, 4, 6 fall (the inner disc and the door's tongue remain); he no longer wards himself (+20 % taken); Requiem every 8 s, Bone Rain every 9 s, the Tolling every 18 s |
| soft enrage "The Last Count" | 330 s | BossKit: +12 % Gloom per 15 s step, timers up to 1.5x |

Every named move is an r33 cast (`BossKit.cast`, `Enemy.cast_info`), announced with the r34 emote line
(`BossKit.emote`: the pull, the Tolling and its bell, the intermission, the Choir, the Reckoning, the floor).
The intermission names itself on the bar (`phase_label` "THE COUNT IS TAKEN"); phase IV names him
"Abbot Osric". Phase floors are kept (`BossKit.phase_floor`: I needs two Rings/Tollings, II two
Grave triples/Tithes/Reckonings, III two Requiems; none in IV). At 0 HP he always dies (an Ossuant knits
back unless Marked: not the Abbot), and his adds go down with him. The arena's room hooks restore the
floor on a reset and on the kill.

Attunement (`QuestBook.attuned("bone_abbot")`, Sister Agathe's chain): "his count comes up short" --
one plate fewer in every Reckoning, one fewer of the faithful in each raising and intermission wave, and
the count in the mound runs 10 s shorter. Announced on the pull. Helps, not required.

Mitigation: everything is a telegraphed ground zone or a positional rule; Rift Step through a zone is a
riposte as elsewhere; the Gloom does not gather on its own in a live arena; a fall into the deep costs
Gloom, not a run.

### Length

`zz/crypt_r34_test.tscn -- --sim` (damage applied at a steady rate whenever he is targetable, Tallies and
Choir broken a few seconds after they rise, no movement or mechanics simulated, time x3): at 3.5 dps the
kill is 261 s (intermission at 76 s, II at 98 s, III at 179 s, IV at 233 s); at 5 dps (with 540 HP)
179 s. With real movement (the Tolling's run round the mound, the plates, the Choir's chase) a fight at
~3.5 dps of uptime should land at ~4.5-6 minutes; the enrage at 5.5 min is the soft wall.

## Tests

`crypt_r34_test`: the hall at size inside the reserve, the floor, chapels/bells/sectors, the arena and
grilles at rest, the lift held, the audit; the walk down (physics); the pull and both grilles; the
Tolling (a readable cast; the sound-shadow safe); the intermission (untargetable, three Tallies, adds,
its cast); phase II (unfed, the Choir halves damage, silenced restores it); the Reckoning (plates, the bar
counts them); phase III (four sectors fell, the deep below, a fall thrown back for Gloom); phase IV (seven
fell, the tongue stands, +20 % taken); the enrage; the kill (saved, grilles open, lift released, the Bone
Reliquary before the mound, the floor whole, his dead gone). `boss_test` and `world_r30_test` start the
fight at `Ossuary.abbot_pull_at()`.
