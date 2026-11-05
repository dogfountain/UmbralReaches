# Critique A: combat (r29)

Lens: enemies, bosses, encounters, skills, staff, progression, balance, readability, hit feel.
Method: the existing harnesses (combat_duel, enemy_kin, skill_test, progression_test,
encounters_test, boss_test, combat_shots) plus four new tools:

- `zz/critA_probe.tscn` (headless): every kind and boss against a real Player. **tells**: each hit on
  a still player is matched to the last ground telegraph made before it (lead = red-to-hit, the
  reaction window; a hit with no red in the 2.5 s before it is "blind"). **ttk**: a player who only
  aims and fires (held Rift Bolt, or a full Lance whenever ready) -- time to kill, shots, dps, and
  the Gloom taken standing still.
- `zz/critA_harden.tscn` (headless, a test: `HARDEN ok`): pins every odd state fixed below.
- `zz/critA_color_shot.tscn` (windowed): telegraphs and health bars in candidate colours, through
  the real camera and grade, in the open and in grass.
- density script (scratchpad): camps within 22 m of each realm path.

Severity: S1 breaks or looks broken, S2 clearly hurts, S3 polish. **Fixed** = done in A's files.

## Readability

1. **S1 Red telegraphs and enemy health bars render blue.** The night grade (world/post/grade:
   hue_pull 1.0 into 205-236 deg, warm protected only 8-66 deg) pulls every red into its blue band.
   Enemy health bars were solid deep-blue blocks; the "red" attack cones were pink-lilac discs
   whose HDR fill tonemapped to near-white (`shots/critA_warband_before.png`: a pack's cones read
   as one pale blob; `shots/critA_color_before_1.png`: left disc = the old red, first bar = the old
   bar). The game's one rule, "no red on the ground, no hit", had no red in it. **Fixed**: the
   danger colour is an ember red-orange (2.6, 0.55, 0.1) the grade keeps (SpellFx.DANGER_RED,
   AttackKit.RED, BossKit.THORN, husk slam/charge, burrower); the fill is drawn at the colour's
   saturated peak (only the outline and the travelling front stay HDR-hot), so hues survive the
   tonemap: ember = melee/slam, lime = the Chanter's sigil, teal = acid / Old Sunk, bone = the
   Abbot, lavender = the Warden. Health bars: ember fill, gold trail. `shots/critA_telegraph_before|after.png`,
   `shots/critA_warband_before|after.png`. Register to E: protect bright reds, or confirm red is out.
2. **S1 Telegraphs vanish in grass and under slopes.** The zone is a flat quad 8 cm off the ground,
   depth-tested: tall meadow grass hid it completely, and uphill halves of a disc sank into the
   ground (`shots/critA_color_before_1.png`, the far row in the grass is gone). **Fixed**: the
   shader tests depth itself; anything up to 1.4 m in front of it (grass, a shrub, the rise of a
   slope, your own robe) shows the outline and the moving front through it, without the fill (no
   orange paint over the wanderer); more than 1.4 m (a wall) hides it as before. Cost: it samples
   the depth texture (the bolt flare already forces that copy in any fight).
3. **S2 The tell and the blow disagreed.** A windup ended at the next 10 Hz think, so every strike
   landed 0-100 ms after its red had filled (probe: wretch 0.42 s tell, lead 0.41-0.53 s), and a
   hit-stop froze the tell clock while the red kept filling. **Fixed**: base windups strike on the
   physics frame the red fills (harden: worst 13 ms over 4 windups, was up to 100); hit-stop keeps
   the tell clock running. Spitter/Chanter keep their own WINDUP (a spit, a sigil).
4. **S2 Creature tells were masked by your own casting** (D's measurement: -28..-32 dBFS at 9 m,
   13-17 dB under the bolt). **Fixed**: every tell +6 dB (all <= max_db 3).
5. **S2 Hotbar names unreadable** (F: ~7 px at 1280x720, names ran into each other). **Fixed**: 17 pt,
   outlined, one word a line, shown again after a loadout swap. `shots/critA_hotbar_before|after.png`.
6. **S2 Boss/elite world health bars were all notch.** One notch per hit point: at 45-120 HP the
   0.86 m bar was frame colour end to end. **Fixed** (`Enemy.hp_segments`: one notch per ~10 % above
   12 HP; director and tiers use it too).
7. **S2 The Ascended Warden smeared across the dais on every blink** (teleport with physics
   interpolation on: one frame of streak at 120-144 Hz). Same for the Faceless Penitent's step and
   the fall-out reset of any enemy. **Fixed** (reset_physics_interpolation).
8. S3 The wanderer covers the enemy directly ahead in melee (every frame of the warband strips).
   Register to B (camera).
9. S3 The Warden's zones are lavender, the player's own Nova/Well discs are violet. They differ in
   outline and fill, but at a glance they are one family. Not changed (an art call; a pale gold
   "judgement" would separate them).
10. S3 Mites tell for 0.3 s (probe: lead 0.27-0.42 s), below a comfortable reaction time; they
   nibble 5 Gloom, so it reads as a swarm pressure, not a dodge test. Kept.
11. Probe, every kind: **0 blind hits** -- no hit without red first (spitter orbs: the lane fills,
   the orb is visible).

## Odd states (hardening)

12. **S1 Burrower stranded underground.** Anything that took it out of its dig other than its own
   surfacing (the fall-out reset to home, a state change) left it invisible, without collision and
   out of the enemy group forever: its camp never cleared, a seal could never open. **Fixed**: any
   state change while under brings it up first; while under it is in group `burrowed`, so the
   pack's last-blow beat ("the pack is broken") waits for it.
13. **S2 Boss zones outlived the boss.** BossKit zones belonged to nobody: a phase change (whose
   doc promises "its tells in flight are cancelled"), the boss's death, or an arena reset (you
   leave, the boss is freed) all let the Requiem rings, the cage and the lanes land afterwards.
   **Fixed**: `BossKit.zone(..., {"by": self})` binds the zone to its maker; cancel_moves (phase
   change, death, freed) takes it back, the red fades, nothing lands. A plain stagger or riposte of
   a boss does NOT cancel its set pieces (ordinary foes' moves still break on a stagger). Harden: 5
   checks. Elites (Old Sunk's ring, the Briar Hart) are bound too.
14. **S2 Hauled foes struck from a stale tell.** The Rift Tether froze a foe's physics mid-windup or
   mid-charge; it landed at your feet with its cone already full (or a husk resumed running a lane
   whose red was 10 m away) and struck point-blank. **Fixed**: `Enemy.hauled()` breaks its tell,
   charge, pounce and combo; it lands off balance (0.45 s).
15. **S2 Umbral Nova, its Implosion, its Echo and the Lash's rune pull reached through floors**
   (no height test: the Ossuary's levels, the stair's flights). **Fixed**: within 3 m up or down.
16. **S2 The Warden kept fighting through its phase-change reel**: blinked (cutting the reel short in
   phase 3), called judgement, and a fan already winding up still fired. **Fixed**.
17. **S2 "Lambda capture at index 0 was freed"** errors (F): timers that captured nodes. **Fixed**: ids
   everywhere (BossKit zone/transition, director ambush wake, briar slows x3, Nova implode/echo/
   motes in both scripts, Tether self-haul, Bound Shade dart, Vfx._reclaim after a scene change).
18. **S3 A huge blow launched enemies** (knockback scaled by uncapped damage: a Shatter or a debug
   999 slid a boss 20 m). **Fixed**: capped at 6 damage.
19. S3 A Rift Step through a boss's landing zone was a bare "evaded", through anyone else's a
   riposte. **Fixed** (deepen): it is a riposte (Marks, a free Lash, the boss reels).
20. S3 Synth/StaffSfx PCM caches held at exit (F/D). **Fixed**: released when the root leaves the
   tree (app close only, not scene changes).
21. S3 One Lance across both Abbot thresholds runs two transitions back to back (the second toast
   replaces the first). Kept: rare, and both beats still read.

## Balance and the difficulty curve

22. **S2 Bosses died before they could show themselves.** Held Rift Bolt, standing still:

    | | HP | ttk (bolt) | ttk (lance+bolt) | Gloom taken |
    |---|---|---|---|---|
    | Thornwarden | 36 | 8.8 s | 8.2 s | 48-74 |
    | Bone Abbot | 45 | 13.9 s | 13.1 s | 80-164 |
    | Ascended Warden | 60 | 19.2 s | 13.5 s | 48-107 |

    The Abbot's phase 3 (the Requiem, every 9 s, below a quarter) lasted ~3.5 s: one cast at most.
    **Fixed**: 72 / 90 / 120 HP (see "after" below); Deeper Night still x1.3 per cycle on top.
23. **S2 Elites** (8-20 HP) died in 2-4 s for their bounty. **Fixed**: x1.5 (12-30). Register to F:
    the Sexton (secrets kit, base x5 = 15-25 HP) is the same story.
24. S3 Ordinary kinds die in ~0.3-1.2 s of held bolt at 10 m (wretch 0.8 s, husk 1.2, bulwark 2.8);
    a lone foe often dies before it arrives. Facetanked, a wretch fills ~196 Gloom / 10 s, a husk
    160, a leaper 180 (two Shades' worth): the pressure is in packs reaching you, not singles. Kept
    (packs, spitters, chanters and the tide carry the threat); worth a playtest.
25. **S2 Encounter density.** Camps within 22 m of each path (enemies per 100 m): west_way 19,
   fen_descent 18, rift_rim 27, road 4 (much of it is the haven), **east_way 3.6** -- the leg from
   Hearthward to the fen had no camp within 18 m of it. And the Barrow Field camp had been skipped
   at plant every run ("inside site secrets_barrow"). **Fixed**: the Barrow Field pair moved 16 m
   north onto clear ground; a wretch/crawler/spitter camp added 9 m off east_way's first stretch.
   Ambushes (director) already cover every path every 42 m.

## Elsewhere (registered)

- E: the grade turns every red blue (also blood, hit sparks, hurt bursts).
- B: melee camera covers the foe ahead; character_rig.gd:1320 parse error broke every scene (16:3x).
- F: the Sexton's health.

## After

`zz/critA_probe` after the changes (held bolt / lance+bolt, standing still, rank 0):

| | HP | ttk before | ttk after | Gloom taken (still) |
|---|---|---|---|---|
| Thornwarden | 36 -> 72 | 8.8 / 8.2 s | 16.5 / 15.1 s | 124-136 |
| Bone Abbot | 45 -> 90 | 13.9 / 13.1 s | 21.3 / 19.7 s | 156-342 |
| Ascended Warden | 60 -> 120 | 19.2 / 13.5 s | 28.2 / 24.7 s | 89-96 |
| Hobb (elite) | 14 -> 21 | ~3 s | 4.7 / 4.4 s | 0 at 10 m |
| Old Sunk (elite) | 20 -> 30 | ~4.5 s | 6.6 / 6.2 s | 0 at 10 m |

These are floors (a player who never moves and never misses); with dodging, a boss now runs about
40-90 s. Sustained bolt dps is ~4.3-4.9 against everything, so ranks, oaths and cores scale it.

Tells after (lead = red appears -> blow lands, a still player): wretch 0.50/0.50 (min/median; was
0.41/0.53 -- the spread is gone), husk 0.66, crawler 0.50, leaper 0.50, ossuant 0.61, bulwark 0.71,
burrower 0.50, mite 0.36, spitter 1.35, chanter 1.50, Thornwarden 0.76, Warden 0.76, Hobb 0.53,
Old Sunk 0.66. Blind hits: 0 for every kind. (The Abbot's min 0.05 is the matcher picking a newer,
unrelated zone made just before an older one landed: it lays many at once.)

## Tests

All green with the changes: combat_duel (COMBAT ok), enemy_kin (KIN ok), skill_test (PASS),
progression_test (PASS, no camp skipped), encounters_test (fails=0), boss_test (all PASS),
critA_harden (HARDEN ok, 16 checks), quit_probe (exit 0; its 2 DummyShader leaks are C's
dwarf_look, registered by F).

## Register answered (to:A)

hotbar names (F), freed lambda captures (F), creature tells +6 dB (D), boosts over max_db 3 (D),
Synth/StaffSfx caches at exit (D/F), Satchel + Kindling menu sounds (F), empty warm-up tween
(B: AttackKit.linger), pad glyphs on the hotbar (B). All fixed.

## Open

- E: the grade still turns every other red blue (blood, hit sparks, hurt bursts).
- B: melee camera covers the foe ahead.
- F: the Sexton's health.
- Performance: not A/B-measured. Nothing in the hub changed (the hotbar adds a few outlined
  strings for its first 14 s); in a fight the danger shader samples the depth texture, which the
  bolt flare already makes Godot copy.
- Ordinary foes die in about 1 s at range: the fights lean on packs. Worth a playtest before any
  change to bolt damage.
