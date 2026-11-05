# r34 overworld raids: the Thornwarden and the Ascended Warden

Written by the raids agent (r34 phase 2). Code: `core/world/henge_raid.gd` (Thorn Henge's room),
`core/world/summit_raid.gd` (the summit deck's room), `core/world/thorn_henge.gd` / `core/world/summit_dress.gd`
(the builders that place them), `core/world/boss_arena.gd` (pull/reset/kill, the boss bar, the emote
line, the room hooks), `core/enemy/boss_kit.gd` (shared moves), `core/enemy/thornwarden.gd`,
`core/enemy/ascended_warden.gd`. Test: `zz/raids_r34_test` (scripted fights). Shots:
`zz/raids_r34_shots.tscn` -> `shots/r34_raids/raid_*.png`.

Design references: WoW raid encounters (raid doors that shut on the pull, phases with an intermission,
an arena-wide mechanic that changes the room, adds with priorities, a soft enrage and a final burn,
boss emotes and cast bars) and Enshrouded's look (warm fire against cold night, readable silhouettes,
no neon). Adapted for one player: every hit is shown on the ground first and can be stepped out of,
sheltered from, or broken; every mechanic is announced on the HUD before it lands.

## Shared plumbing

| | what | where |
|---|---|---|
| Raid door | the gate shuts behind you on the pull (`BossArena._begin` -> `gate.close()`), opens on a wipe/walk-out (`_reset`) or the kill; a progression seal used as a door goes back to its own state (`WardSeal.reopen`) | `boss_arena.gd`, `ward_seal.gd` (unchanged) |
| Room hooks | `BossArena.room` (a Node): `room_begin(boss)` on the pull, `room_reset()` on a reset, `room_won()` on the kill | `boss_arena.gd` |
| Emote line | `BossKit.emote(boss, text, col)` -> `BossArena.emote()`: a WoW raid-warning line under the boss frame (own CanvasLayer 41, so the r33 unit frames that hide the arena's bar do not hide it), 5 s, fading; `arena.last_emote` for tests | `boss_kit.gd`, `boss_arena.gd` |
| Phase label | boss meta `phase_label` names an intermission on the arena bar ("HEART OF THE HENGE", "THE ASCENSION") | `boss_arena.gd` |
| Casts | every named move is a cast (r33 API: `BossKit.cast`, `Enemy.begin_cast`, `Events.enemy_cast_started/_ended`) | unchanged |
| Push | `BossKit.push(player, dir, speed, delta)`: move-and-collide (walls and parapets still stop you) | `boss_kit.gd` |
| HP floor | `BossKit.phase_floor` unchanged (a phase holds above its mark until its signature move was shown twice). `BossKit.absorb` now holds a floor only for a boss *above* it (a boss already below one -- a test, a phase that moved on -- is not made immortal) | `boss_kit.gd` |
| Ember Road | still shut during any fight (`Player.boss_fight_active` reads every arena's `_active`) | unchanged |

API added to `BossKit` (stable, for the Bone Abbot's crypt too): `emote`, `arena`, `room`, `push`,
`EMOTE_COL`. Nothing removed or renamed.

## Thorn Henge: the Thornwarden

### Room (RealmLayout.RAIDS "henge": centre (-86, -24), floor level at y 9.0, r 31)

| feature | radius (m) | what it does |
|---|---|---|
| outer bramble wall | 30.2 | solid, 5.6 m (above a double jump), 96 segments with thorn trunks for a silhouette; one gap |
| raid door | 30.2, at the stair head | the 'henge' progression seal (thorn look) in the wall's mouth (~9.6 m), framed by two 7.4 m uprights and a lintel. Shut while its three guard camps live (unchanged camps on west_way / the hill's foot), shut on the pull, open on a reset or the kill |
| arena (BossArena) | 29 | the fight's ring; leave by 6 m and it resets |
| great stones | 21 | ten 7-8 m standing stones (RockKit slabs, solid): line of sight for the Thornstorm |
| bramble maze | 14.6-28.4 | 18 hidden walls in three stages (`MAZE`): spokes between the inner mouths, arcs before them, spokes fencing each heart-knot's bay. Each wall's line fills red for 1.6 s ("Bramble Eruption", 20 Gloom) before it grows; anyone left in a grown wall is put out to a side |
| inner hedge | 12.2 | ThornHenge's hedge, now with four mouths (inner and outer ring) |
| inner ring, horseshoe, altar | 10.5 / 5.4 / 0 | ThornHenge's (unchanged); the altar is where it roots |
| heart-knot bays | 25.5 at 60 / 180 / 300 deg from the door | the intermission's targets |
| closing briars | 29 -> 16 | the burn: a ring of ember mist that closes 3.25 m every 14 s; outside it, 5 Gloom per half second |

Lighting: an ember heart over the altar (range 28, no shadow), a pale moon shaft on the floor
(SpotLight, 40 deg, no shadow), four fire bowls at the inner mouths (range 10). The room has moods:
rest (low embers), fight, rooted (sap-gold heart, bowls dimmed), bloom (blood-red heart and bowls,
moon down), won. The old violet altar light is off under the Realm.

Checkpoint: HengeFire stays on the pilgrim stair's rest platform, ~37 m from the centre (outside the
door and the arena; a fall never resets you inside the fight).

### Fight (600 HP, was 110; 2.6x scale, was 2.0; leap 20 m)

| phase | HP | abilities (cast name) | the room |
|---|---|---|---|
| I "The Keeper" | 100-70 % | **Bramble Pounce** (landing disc fills for the flight) / **Thornlash Volley** (3 lanes, interruptible: heart-knot on its breast or a heavy blow) / **Bramble Lash** (a second in its blind half: a ring round it) / **Briar Snare** (ring round you, open toward it, then a pounce) / **Thornstorm** (3.2 s, cannot be broken, every 34 s: the whole floor is hit, 48 Gloom, unless a great stone or a grown wall stands between you and it) | open floor |
| Intermission "Heart of the Henge" | at 70 % | roots into the altar, **immune**. Three **heart-knots** (18 HP each, hit like a foe) grow in their bays; maze stage 1 at once, stage 2 at 12 s, stage 3 at 24 s; **Root Eruption** (3 m disc under you, every 5.5 s); Briarlings crawl from living knots every 14 s (4 at most). All knots burned: it tears free, reeling (weak for 5.2 s). Not in 55 s: **The Henge Closes** -- each knot left heals it 5 % and deals 16 Gloom | maze grows; heart turns sap-gold |
| II "The Overgrowth" | 70-35 % | everything from I (volley now 5 lanes), plus **Sap Mending** (3 s, interruptible, below 60 %, every 26 s: heals 6 %) and **Call of the Stones** (every 32 s: two Briarlings and a **Thornspeaker** -- while a Thornspeaker lives the Thornwarden takes half damage: the priority add) | the stage-3 bays wither, the inner maze stays (shelter and obstacles) |
| III "The Last Bloom" | 35-0 % | faster (leap cooldown 1.3 s, volleys and snares sooner); **Bloom of Thorns** (every 15 s: three rings burst outward from it at 1.4 / 2.2 / 3.0 s, 2.5-5, 8.5-11, 14.5-17 m: stand between them) | the maze withers; **the closing briars** shrink the floor (29 -> 16 m) |
| Soft enrage "Overgrowth" | 330 s | +12 % Gloom per 15 s step (x2.2 at most), timers up to 1.5x faster | |

Signature moves for the HP floor: pounces (I), volleys (II), blooms (III).

Expected length: ~4.5-5.5 min (600 HP at ~3.5 DPS of uptime = ~170 s, plus the ~35-45 s intermission,
transitions and adds). The enrage at 5.5 min is the soft wall.

## The Summit: the Ascended Warden

### Room (RealmLayout.RAIDS "summit": centre (0, -118), r 28, deck 27.35)

| feature | where | what it does |
|---|---|---|
| the great deck | r 28, holder centre (0, -34.5) | paved disc (a rose of slate bands and spokes), 1 m slab, its front edge meeting the platform's top deck at z -90 (the mouth) |
| piers | rim (every 4th of 72 segments) and an inner ring at r 15 | stone piers with corbels down to the ground wherever the ground is 2.5 m+ below; none over the Ossuary (its AABB + 3 m) or the platform; the north half sits on the cirque's cut ground |
| the cirque | north, r 30-40 | RealmLand's cut (layout): the Crowns rise behind the deck |
| parapet | rim | coped 0.9 m wall; a 2.5 m screen where it borders the platform; open at the mouth and the Ossuary lift jetty |
| broken edges | east and west (+-8.5 deg) | no parapet: a long fall into the chasm. Two red edge fires mark each gap's ends (one light per edge) |
| mouth veil | z -90 | the arena gate (light look), shut on the pull |
| four pylons | r 17 at 45 / 135 / 225 / 315 deg | 5.7 m obelisks with a gold flame (light range 12). Lit: a 3.2 m ring of light that falling stars never land in, that is an Eclipse pool, and a windbreak against the Gale. Dark: stand in the ring 2.5 s to rekindle (the fill grows on the stone) |
| arena (BossArena) | 27.5 | ceiling 14 (it ascends); leave by 6 m and it resets |

Lighting: a warm-white key shaft from the cirque onto the deck (SpotLight, no shadow), the gold pylons,
the red edge fires, the Warden's halo (range 12). Moods: rest, fight, ascension (shaft cold and low,
pylons out), hierarch (shaft gold and bright, edges brighter), won.

Checkpoint: SummitFire stays at the platform's stair head, ~39 m from the deck's centre (outside
the arena + 6 m). The summit ward (needs both other bosses) and its two guard camps are unchanged.

### Fight (760 HP, was 220; 3.0x scale, was 2.2)

| phase | HP | abilities (cast name) | the room |
|---|---|---|---|
| I "The Hierarch's Judgement" | 100-65 % | **Rift Step** (blink between 8 points every 5 s) / **Radiant Fan** (cone fills 0.85 s, 7 orbs; interruptible: the halo or a heavy blow) / **Judgement** (two crossing lanes on you, every 7 s) / **Mandorla Flare** (2 s, every 19 s: 3.6-16 m round it burns; get under it) | four pylons lit |
| Intermission "The Ascension" | at 65 % | rises 10 m toward the door (immune); **all pylons go out**; **Falling Sky**: a star every 0.9 s at random and every 3 s on you (2.6 m discs, 1.7 s, 18 Gloom, never in a lit ring); two **Gilded Acolytes**. Rekindle all four: it falls back to the deck, blinded (weak 5.2 s). Not in 60 s: **The Sky Breaks** -- 55 Gloom unless you stand in a lit ring | the deck goes dark |
| II "The Door Opened" | 65-30 % | blinks every 3.8 s with an arrival ring; fans; Judgement every 5 s; **Gale of the Door** (1.6 s cast, then 5 s of wind at 3 m/s away from it: walk into it -- you walk at 4.5 -- or stand behind a lit pylon; the broken edges are the price); **Eclipse** (2.8 s, every 24 s: the whole deck but the lit pylons' rings, 34 Gloom; the ring you stood in is spent); **Call the Acolytes** (2 s, interruptible, every 34 s); Mandorla Flare | pylons are spent by eclipses and must be rekindled between them |
| III "Aurel, Hierarch" | 30-0 % | he lets go of the door: **every pylon blazes again**; blinks every 2.6 s with a wider ring and **double fans**; Judgement every 3.8 s; Falling Sky (a star on you every 4 s, one at random every 2.2 s); Eclipse every 20 s; Flare every 16 s | gold light, brighter edges |
| Soft enrage "The Door Closes" | 400 s | as BossKit (Gloom x and timer haste) | |

Signature moves: fans (I), judgements (II), double fans (III). The bar names him "Aurel, Hierarch" in III.

Expected length: ~5-6.5 min (760 HP; blinks and the Gale cost uptime; the Ascension ~30-50 s).

## Numbers that changed

| | r33 | r34 |
|---|---|---|
| Thornwarden HP / scale / arena r | 110 / 2.0 / 12.4 | 600 / 2.6 / 29 |
| Thornwarden phase marks | 0.5 | 0.7, 0.35 (+ intermission at 0.7) |
| Thornwarden soft enrage | 150 s | 330 s |
| Ascended Warden HP / scale / arena r | 220 / 2.2 / 14 | 760 / 3.0 / 27.5 |
| Warden phase marks | 0.6, 0.3 | 0.65, 0.3 (+ intermission at 0.65) |
| Warden soft enrage | 210 s | 400 s |
| SummitDress.DAIS_C / DAIS_R | (0, -20.4) / 14 | (0, -34.5) / 28 (world (0, -118)) |

## Not done / notes

- No boss model was re-exported: the rigs are scaled by `BossKit.embiggen` (capsule, bar, strike range
  and weak points follow the rig).
- The unit-frame boss plate (`ui/unit_frames.gd`, not this area) still prints "Phase II" during an
  intermission; the arena's own bar (hidden by the unit frames) and the emote line name it.
- The bramble meshes go through `GenCache` (key `henge_raid_*`); the shipped cache needs the lead's
  `--bake-cache` before packing or the first run builds them (~0.5-0.9 s).
- `RealmLayout.SUMMIT_DAIS` (layout's constant, the old r 14 dais centre) is left as it was; flora's
  `_disc_field` keys on it, and the raid zone already keeps flora off the deck.
