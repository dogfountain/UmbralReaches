# r39 combat: the brutal critique, then the fix (live checklist)

Luke, 18 Nov: "Spawn another extra agent to fix combat." Brief: `docs/r39/briefs/combat_fix.md`. Branch `combat-fix` in
`/Users/luke/UmbralReaches_combat`. This file is the live checklist: every finding, its evidence, its fix and the
commit. Resume from "State" below.

## State (19 Nov: every finding fixed or handed on; the re-capture read; the tests last)

Done:
- [x] Resumed after the map audit's merge (master merged into `combat-fix`, LFS objects copied, reimported).
- [x] Captured every fight (`A`-`E5`, `P1`, `P2`), read every sheet and log, wrote the critique below by seat.
- [x] Made every fix (the table at the end), then one re-capture pass of all of it (`R1`-`R8`) and read it; its
      leftovers and the new findings it showed (QA6 the gold ghost, EB9, UX7-UX11, GF9, MA4) fixed and checked in short
      runs (`X2`-`X5`, `V1`, `V2`, `P3`).
- [x] The one test run (19 Nov, JOBS=1 under the lock): the quick tier 27 of 27, combat_qa, combat_r31, combat_r33,
      floor_fight, boss, enemies_r34, raids_r34, crypt_r34 all PASS, combat_duel "COMBAT ok" (82 checks). The one
      failure was the static lint: the flash-light pool kept its host in a Node-typed static; it keeps the host's
      instance id now and Vfx.release() forgets the pool (the quick tier and combat_qa re-run after it). No test was
      changed.

Not fixed here, and why:
- The fight bot still clears regular packs nearly untouched (CD1): it is the harness's aim-assisted bot, held bolt and
  perfect Rift Steps, not a player; the foes' side (twice the blows, a rhythm, spacing) is done.
- PF1: the ~960-pipeline frame ~6 s after load is the world's post-build mesh merge (not a fight's); the rest was the
  harness's own JPG writes. The first pull's `boss_engaged` costs 18.6 ms once; left for the perf owner.
- QA7: one lava burn the logs cannot explain (not seen again).
- MA1-MA4 are the map audit's (collision of the pit hall's wall, the Crown's earthwork and yard; the henge's spacing).

Machine/lint notes for the fixer:
- `tools/lint.sh` is a ratchet: `core/enemy/enemy.gd` has a line cap of 2352 (baseline 2302 + 50; 2344 now), so any
  change there must be net zero lines or move code out; `character_rig.gd` has 47 lines of room, `ui/unit_frames.gd`
  39. No new `.call("x")`, `has_method(`, `.get("_x")`, and no round tags (r12, r39...) in comments of shipping code.
- Scratch: `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/combat/`
  (`gd.sh`, `calc/ttk.py` the TTK table, `calc/logsum.py` the log summariser). Never write captures into `shots/`.

## Harness: zz/combat_strip.tscn

Fights in the real night (world/main.tscn) through the real player camera, grade and HUD, a scripted wanderer, and
a per-physics-frame log. `--fights=name=spec;...` where spec is a set (pack warband r31 brood burrow casters), kinds
joined by `+` (`kind@dist@bearing`, an elite by its id), or `boss:<id>[@hp ratio]` (pulled in its own arena).
`--bot=stand|dodge|fight|melee`, `--secs`, `--every` (physics frames per captured frame; 0 = none),
`--full=hits` (full-size frames on every telegraph, hurt and kill). Writes `<fight>_sNN.jpg` contact sheets (9 cells,
frame number in each), `<fight>.log` and `summary.txt`. The log has, per frame: every telegraph's first frame, size,
shape and whether the wanderer stands inside it as DRAWN; the frame it fills; every enemy state change (windup length,
distance, whether the attacker is on screen); every HP change; every hurt with the zones drawn at that moment
(frames after full, inside-drawn, progress, fade) and the attacker's state and screen position; casts; kills; spikes.


## Captures (18 Nov, 23:10-23:45; scratch `combat/<batch>/`)

| batch | what | bot |
| --- | --- | --- |
| `A` | wretch husk crawler leaper ossuant bulwark gaunt pilgrim mites burrower, one at a time, 8 s | stand (takes every blow) |
| `B` | spitter chanter quiller tollman cinder caster brood mother; elites Hobb, Old Sunk, Briar Hart, Root-Wife, 9 s | stand |
| `C`, `C2` | singles (wretch husk bulwark leaper brood) and packs (pack warband r31 casters burrow mites) | fight (held bolt, Lance every 5 s, Nova on 3 marks, Rift Step out of red at 60 %) |
| `D` | wretch husk bulwark Hobb, a three-pack | melee (staff chain) |
| `E1`-`E5` | the five bosses in their 1.6x arenas, 135 s each, life stepped to phase II and III at 45 s and 90 s | fight |
| `P1`, `P2` | packs and every boss with no frame capture (honest frame times) | fight |
| `R1`-`R8` | the re-capture pass of everything fixed (19 Nov): `R1` singles, `R2` packs, `R3`-`R7` the five bosses (135 s, phases stepped), `R8` flankers (a wretch behind; a leaper and a Gaunt off-side) | stand / fight |
| `X2`-`X5`, `P3`, `V1`, `V2` | short runs to settle a doubt: the gold ghost A/B (`X2`-`X4`), the Gaunt and the lesson column (`X5`), a pull probe with no capture (`P3`), the leftovers (`V1` the Warden from 60 %, `V2` the Anchoress, Thornwarden and Crown in melee) | fight / melee |

Only the sheets this file names were kept (scratch was pruned); every log is kept.

Every log line quoted below is `<batch>/<fight>.log`; every sheet `<batch>/<fight>_sNN.jpg` (frame numbers on the cells).

## The critique (by seat)

Nothing below is fine. Format: **id** (severity: P0 broken / P1 bad / P2 weak). What is wrong, the evidence, why it
matters, what good looks like, and the fix (filled in as it lands).

### Combat designer

- **CD1 (P0) A held trigger beats every regular foe before it can tell.** `C/f_wretch.log`: the wretch dies at 0.78 s to
  three plain bolts from 12 m and never reaches the wanderer; husk 0.80 s (a bolt on its knot), leaper 0.82 s (a crit
  during its coil), bulwark 2.4 s. `C2`: the fight bot clears a five-pack in 5.7 s, the warband (bulwark, chanter, two
  wretches, three mites) in 4.5 s, the r31 hunters in 11.3 s, the casters in 4.3 s, burrowers 3.1 s: **zero wounds
  taken in every pack**. `calc/ttk.py`: a held Rift Bolt is 4.8 dps; a wretch has 3 hp, a husk 5. Every system built
  since r29 (feints, chains, poise, the parry, the guard, flanking, the pack's tokens) never comes into play: nothing
  lives long enough to use it. Elden Ring and Enshrouded trash takes 3-6 hits and comes in groups that close the gap;
  Hades' trash dies fast but in waves that surround you. Fix: melee kinds take twice the hits (the fragile support
  kinds stay one- and two-hit kills: their fragility IS their design), and a held trigger loses its edge over rhythm
  (heat sooner) so a pack reaches you and the tells matter.
- **CD2 (P1) Melee foes have no rhythm: they strike every 0.75 s from inside your robe.** `A/wretch.log`: hurts at
  f118, f162, f211 (44-49 frames apart); pilgrim f134, f182; Hobb 63 frames. A foe that wins its token winds up again
  the frame its recovery ends: there is no gap to punish, no step back, no circling, and a still wanderer is hollowed
  by one wretch in 4 s. Every blow lands at 0.7-0.9 m centre to centre (`dist 0.81` on every STRIKE), i.e. inside the
  wanderer's capsule, because the lunge carries it to 0.55 x strike_range and it never backs off. Good: a Souls/God of
  War grunt attacks from its reach, then spends 1-2 s repositioning before the next tell. Fix: an attack cooldown
  after each strike (per kind, 1.0-2.0 s, shorter in a deeper night) spent backing to its reach and circling, and the
  lunge stopping at ~1.1 m.
- **CD3 (P1) Packs are not problems, they are queues.** With CD1 the pack never arrives; the "pack is broken" beat,
  regrouping and the Tollman's call only show in the stand-bot runs. Fix with CD1/CD2, then check the warband's
  bulwark-in-front-of-the-chanter problem actually presents (it does in `B` stills).
- **CD4 (P2) Every spell has a reason only on paper.** The bot uses Bolt, Lance and Nova and never needs Ward, Guard or
  the parry: with CD1 nothing threatens it. Not separately fixable; it follows CD1/CD2.

### Encounter and boss designer

- **EB1 (P0) Safe ground is painted red.** The danger shader has no "holes": the Thornwarden's Bloom, the Crown's Echo
  and Verdict draw their rings as full discs (the gaps you must stand in look like the worst place on the floor), and
  the Warden's Flare and Eclipse and the Abbot's Tolling paint red over the very pool their column marks safe.
  `E1/thornwarden_s28.jpg`: the Thornstorm floods the whole henge floor orange; the lee behind the stones is under the
  same orange; the bot survived only by the ray test ("SHELTERED"). Good: WoW/FFXIV donuts, FromSoft's safe pockets:
  the safe shape is cut out of the danger and drawn. Fix: inner radius and up to four safe pools in the shader,
  outlined pale; every move with "holes" gets them drawn.
- **EB2 (P0) Hits with no red at all.** `E4/anchoress.log` f2880 and f4203: The Undertow, 44 wounds, "NO ZONE DRAWN"
  both times; it wounds everyone unsheltered anywhere on the terrace. `E3/ascended_warden.log` f6302: The Sky Breaks,
  55 wounds, with no zone (only an emote 10 s before). The Thornstorm's red is a 30 m disc on the henge centre while its
  real test is anything within 34 m of the BOSS (`thornwarden.gd _storm_lands`). Fix: each draws the zone it tests,
  with its shelters as holes (the cairns' lee, the lit pylons' rings, the stones' lee).
- **EB3 (P0) Every Blender boss acts 25 % late.** The vb_kit keys clips at 30 fps in a 24 fps Blender scene: every glb
  clip is 1.25x its authored length (abbot idle 6.0 -> 7.54 s; every track's first key at 1/24 s). The fight code was
  timed to the authored seconds (the Crown's verdict jolts at 1.4/2.3/3.2 = its rings; the Thornstorm's crash at 3.2 =
  STORM_TIME; the Abbot's sweep crosses at 1.05 = its zone), so the body lands 0.3-0.8 s after its red. Fix (code only,
  no re-export): ClipRig reads the first key; 1/24 s means the stretched export: it plays at 30/24.
- **EB4 (P0) The Speaking Crown soft-locks.** `E5/hierarch.log`: the second Edict of Silence (f1311) never ends its
  cast: no CAST END, no damage taken after f1333, no move for the remaining 110 s; the cast bar stays up
  (`E5/hierarch_s40.jpg`). It came after a Rift Step took the wanderer into the yard's earthwork (camera inside rock,
  `E5/hierarch_s15.jpg` f1400-1430). To settle with a STATUS-logged rerun.
- **EB5 (P1) The Warden's Radiant Fan shrinks on its first tracked frame.** Created at 32 m, `_track_fan` rewrites the
  transform with `Basis.from_scale(Vector3(20, 1, 20))`: the drawn cone drops to 20 m while the orbs fly on (size_m stays
  32, so its outline widths are off by 1.6x too). The cone is also gone 0.3 s after the windup while the orbs take
  1.2 s to arrive (`E3` f1640: hurt 17 by an orb, NO ZONE DRAWN).
- **EB6 (P1) Thornwarden's close moves are pup-sized.** At SCALE 3.8 (about 11 m nose to tail) the Bramble Lash
  (LASH_R 4.6, fires inside 4.2 m) and the inherited leaper tail sweep (`d > 2.6` is out) only fire when you stand under
  its belly: its "never stand behind it" signature never shows (no Bramble Lash in 135 s of `E1`).
- **EB7 (P1) Mechanic failures land as damage from nowhere.** The Reckoning's shortfall (42), the henge closing (48),
  the sky breaking (55): announced by an emote, but at the moment of the blow nothing on the ground says it is coming
  or why. Good: WoW's raid frames and FFXIV's "enrage" casts: a named cast bar and a drawn zone counting down. Fix: the
  sky break and the henge's close cast their last seconds as a named cast with the zone drawn (shelters as holes).
- **EB8 (P2) The bosses use their 1.6x arenas, but the camera does not.** The Thornwarden pounces across the henge
  (good), the Warden blinks to its anchors; but a fight against a 9 m boss is played with the lock aimed at its chest:
  the Warden's deck and its lanes sit in the bottom fifth of the frame. See UX.

- **EB9 (P1, re-capture `R5`) The Warden's tells are white on a white deck.** `R5/ascended_warden_s10.jpg` f910-f980: the
  Radiant Fan's 32 m cone turns the summit's pale deck into a white sheet you cannot tell from moonlight on stone;
  `R5/ascended_warden_s69.jpg` f6210-f6290: the Sky Breaks' deck-wide red (now drawn, EB2) barely tints the deck and the
  lit pylons' safe rings cannot be found in it; at the fall the cast bar flashed "INTERRUPTED" (`R5` log f6302) as if the
  wanderer had stopped it. Fix: the Warden's colour (BossKit.HOLY) is a saturated gold, not white-gold; the Sky Breaks'
  bar closes as finished.

### Animator

- **AN1 (P0) = EB3** (every boss clip 25 % slow).
- **AN2 (P1) Boss moves ignore their own cast time.** Most moves call `boss_move(clip, 0.0)` (natural length) whatever
  the cast; with AN1 fixed the authored ones line up, the rest need their `dur` (Thornwarden mend 3.7 s against a 3.0 s
  cast; the Anchoress's swing calls the rig strike at 1.15 s and the slam lands 0.26 s later, after the 1.3 s zone).
- **AN3 (P1) Melee contact lands after the swipe.** `A/husk_s03.jpg`: the rake's arc is drawn at f174-180 (the STRIKE
  frame), the wound lands at f187 (STRIKE_AT 0.2 s): the eye sees the swing pass, then a beat later the blood.
- **AN4 (P1) The boss hit flash whites the whole body out.** `E4/anchoress_s30.jpg`: under a held bolt the Anchoress is
  a white silhouette half the time (VillagerBossRig.FX_CODE adds 0.5 x white over the whole body on every hit, 7/s
  decay, ~3.5 hits/s). Her pose, colour and tells are lost. Good: Elden Ring has no flash; Hades a rim tick. Fix: a rim
  flash scaled by the blow (plain bolts barely register; heavy blows and weak points ring), rate-limited.
- **AN5 (P2) Hit reactions on the wanderer.** A 40-wound crozier and a 5-wound mite nibble play the same torso rock:
  no weight. Fix: a short hit-stop and a shove on heavy blows.

### Game feel / VFX

- **GF1 (P0) The player's own bolts bury the target.** `C/f_brood_s01.jpg`, `C2/f_warband_s01.jpg`, `E1/thornwarden_s26.jpg`:
  every plain bolt spawns a 1.3 m violet dome plus a shell, every third (the Lash) a 3.2 m lightning dome and a ground
  disc; under a held trigger the target (even a 6 m Thornwarden) lives inside a violet sphere and its tells cannot be
  seen. Good: Elden Ring's sorceries pop small at impact; the heavy ones earn the screen. Fix: the plain impact small
  and quick, the Lash's dome thinner and shorter (its ground disc keeps the true radius).
- **GF2 (P0) Melee red lies about when.** `A/*.log`: every base strike lands 12-15 frames after its cone is FULL, with
  the cone at fade 0.35-0.5 (already disappearing). The rule the game teaches ("when the red fills, it lands") is false
  for every melee foe. Fix: the cone fills over windup + STRIKE_AT (full on the frame of the blow); the swipe arc
  spawns with the blow.
- **GF3 (P0) Melee red lies about where.** `E2/bone_abbot.log` f1791: the Abbot's crozier strike wounded the bot 40 at
  2.25 m with `inside_drawn=false`: the cone is drawn at the rig's smoothed yaw, the blow tests `_face_dir`. Fix: the
  blow tests the cone as drawn.
- **GF4 (P1) Leaper and mite pounces fill early.** `A/leaper.log` f101: the pounce's disc is full 56 frames (0.93 s)
  before the landing that wounds; `A/mites.log` +21 frames. The disc fills over the crouch only, then holds full through
  the flight. The Thornwarden's pounce does it right (fills for crouch + flight). Fix: the same for every pounce.
- **GF5 (P1) Foes are invisible at night until they strike.** `A/leaper_full_f0015_tell4965.jpg`, `B/quiller_full_f0076_tell6557.jpg`:
  at 8-11 m a leaper, gaunt or quiller is a black shape in the grass; only its health bar and the lock diamond say it
  is there, and its coil or draw cannot be read. (Dark night is Luke's direction; telegraphs are ours.) Fix: a tell lights
  the attacker: an ember rim on its silhouette over the windup (the flesh shaders' glint, no new material or light).
- **GF8 (P1) The Rift Step's tear blinds the camera.** `R3/thornwarden_s73.jpg` f6640-6650: a step toward the lens puts the
  camera through the departure tear, a screen of white-violet for three frames. Fix: the tear fades out within 2.4 m of
  the camera.
- **GF6 (P2) Being hit has no weight** (AN5). **GF7 (P2)** a kill's "SHELTERED"/"evaded" world text is drawn huge and
  clipped at the screen edge when the camera is close (`E1/thornwarden_s28.jpg` "HELTERED").

- **GF10 (P1, re-capture `V1`) A bolt burst at the lens fills the view.** `V1/warden_s43.jpg` f3940-f3950: shooting
  over the summit's parapet, the bolts burst on its coping a metre from the camera; the Lash's 3 m shell from there is a
  violet lightning wheel over the whole frame, the Warden behind it. Fix: an impact's dome, shell and ring are set
  smaller by its distance to the lens (full from 5 m out, a fifth at the lens); the Lash's ground disc keeps its true
  radius.
- **GF9 (P2, re-capture) The Lance's aim circle stood up across the view.** `R7/hierarch_s64.jpg` f5760-f5800: aimed
  at a wall at the shoulder (the earthwork's crevice), the blast circle lies on the wall a metre from the lens, a 2 m
  ring of ticks over half the frame. Fix: it fades out between 4.5 and 1.5 m from the lens.

### UX

- **UX1 (P0) In melee the camera shows your back, not the foe.** `t1/wretch_stand_full_f0119_hurt1.jpg`,
  `A/husk_s03.jpg`, `D/m_husk_s01.jpg`: at 0.8-1.4 m the attacker stands behind the wanderer's robe; its wind-up pose
  and contact are hidden, and the strike cone lies at the bottom of the frame under the hotbar. The lock aims at the
  foe's chest from shoulder height: almost level, so the ground round your feet is out of frame. Good: Souls and God of
  War raise and tilt the lock camera at close range so foe and ground both read. Fix: a close lock pitches down and
  rises; the foe kept clear of the body by the shoulder.
- **UX2 (P0) Subtitles and lessons sit on the fight.** Village barks ("Hild: ..."), the wanderer's own voice lines on a
  cast ("The lance is a held breath ...") and the combat lessons (40-word paragraphs: "A blow of 2 or more breaks a red
  tell ...", "RIFT SURGE: ...") are drawn in the lower-middle "sub" lane, exactly where the ground tells around you are,
  during the fight they describe (`t1`, `A`, `D`, `E3`, `E4` sheets). Fix: in a fight barks wait, voice lines wait,
  lessons shrink to one line and move above the hotbar's line of sight (or wait for the fight's end).
- **UX3 (P1) No warning from off-screen.** Flankers circle to your side, the Gaunt stalks your off-side (110 deg from
  the camera's forward) and darts, a leaper coils behind; the hurt wash tells you after. Good: God of War 2018's edge
  marks. Fix: painted edge marks (new icons `hud/threat_melee`, `hud/threat_ranged`) turned toward a foe winding up out
  of view, filling with its tell.
- **UX4 (P1) The lock camera chases a leaping foe into the sky.** `A/leaper_s01.jpg` f90-f102: the view tips up to the
  airborne leaper and the landing disc under you leaves the frame for the whole flight. Fix: the lock pitch ignores a
  foe's airborne height (aims at its ground point while it flies).
- **UX5 (P1) The camera in tight places.** `E2/bone_abbot_s11.jpg`: against the pit hall's wall the camera sits on the
  hood (the hood is 40 % of the frame) and the Abbot is a slit; `E1/thornwarden_s26.jpg` f2370-2390: a standing stone
  fills half the frame. `E5/hierarch_s15.jpg` f1400-1430: after a Rift Step the view is inside rock. Partly map audit
  (the pit hall shows the sky and a lake through its wall at f990-1070); the camera's own part: when the arm is pressed
  short, rise and look down over the shoulder instead of crushing into the hood.
- **UX7 (P1, re-capture `R5`) A lock on the risen Warden looks at the sky.** `R5/ascended_warden_s68.jpg` f6120-f6200:
  15 m up through the pylon phase, the lock aims at his chest; the deck (and the Sky Breaks' red with its safe rings)
  is a strip under the hotbar for the whole phase. Fix: the lock aims no higher than 6 m over the wanderer's own feet.
- **UX8 (P1, re-capture) Lifted 500 px, the lesson sat on the boss.** `R6/anchoress_full_f4230_hurt5.jpg`: a three-line
  lesson ("A blow of 2 or more breaks a red tell...") straight under the Anchoress's emote and over her head;
  `R7/hierarch_s64.jpg`: over the Cantor's plate for 20 s; `R6/anchoress_full_f2886_hurt2.jpg`: a voice line across the
  scaffold she stands on. It also crossed the banner lane (the boss emote's), which the director's own overlap check
  forbids. Fix: in a fight the lower lane's lines (lessons, the wanderer's voice) go to a left column (28, 420), at most
  600 px wide, between the banner lane and the toasts, left-aligned.
- **UX9 (P2, re-capture) The gear-gap line under the minimap ran off the screen** ("NO GEAR WORN: GROUND LIKE THIS WANTS
  ITEM LE", every `R6` frame): centred on the dial, wider than it. Fix: it keeps inside the screen's edge.
- **UX10 (P1, re-capture) "RESONANCE x5  mends 75  breath 20" ran across and off the view** (`R7/hierarch_s39.jpg`
  f3550-f3570, `X4/abbot_s04.jpg`): one 32-letter world line popped at the wanderer's head, big. Fix: the gains go on a
  second line, and any long world line is set smaller (by its longest line), not wider than the view.
- **UX11 (P1, re-capture) The wanderer inside a great one's body.** `R6/anchoress_s64.jpg` f5780-f5840: the Anchoress
  walked onto the wanderer (0.91 m from her centre, her capsule 0.64 m: `embiggen` caps every boss's at 1.6x a grunt's so
  it fits its arena's ways); the frame is her skirt, then the inside of her body, then her lantern at the lens. Fix: a
  great one's body is solid to the wanderer out to its footprint (0.45 of the narrower side of its meshes' rest box, at
  least the capsule, at most 2.4 m): one inside is eased out at up to 6 m/s (BossKit.keep_out).
- **UX6 (P2)** "CHAIN x9" combo text drawn 4x larger than the boss name over the fight (`C2/f_warband_s01.jpg`).

### Map audit (handed over, not mine to move)

- **MA1 (P0) The Bone Abbot's pit hall can be left through its wall.** `R4` (first run) STATUS lines f698-f1178: the bot
  backed out of the Crozier Sweep at the floor's edge (29.4 m from the centre), passed 37 m out at y -40.9 and fell,
  thrown up and falling again for the rest of the fight (y -39 to -58), the fight held. `E2/bone_abbot_s11.jpg`: from the
  floor's rim the night sky, a lake and mountains show through the hall's wall at eye level. The 1.6x hall's outer wall
  (36 m) does not close it (no collider, or gaps, between the 29.6 m floor and the wall). Combat's part done: a held
  fight resumes on the floor (EB4).
- **MA2 (P1) The Speaking Crown's siege yard earthwork.** `E5/hierarch_s15.jpg` f1400-1430: a Rift Step out of the yard
  toward the earthwork left the camera inside its rock for the rest of the run (its mesh and its collider disagree, or
  the camera's spring misses it). Combat's part done: the held fight resumes anywhere in the yard (EB4).
- **MA3 (P2) The henge's standing stones crowd the camera** (`E1/thornwarden_s26.jpg`, `R3/thornwarden_s27.jpg`): 16 stones
  2.6 m wide on the 29.8 m ring are the Thornstorm's shelter by design; the camera's lift (UX5) helps, the spacing is the
  room's.

- **MA4 (P0, re-capture `R7`) The Crown's yard lets the wanderer fall through the ground.** `R7/hierarch.log` STATUS
  f5930-f6050: from (-207.5, 0.8, 171.6) a Rift Step west into the earthwork's crevice (`R7/hierarch_s64.jpg`: rock walls
  and an overhang either side of the lens) and then down through the yard to y -7.3, -35.1
  (`R7/hierarch_s66.jpg` f5970-f6020: the yard's underside overhead), at about (-216.8, 169.7), 24 m from the yard's
  centre; the fight held and took up again when the wanderer was put back. With MA2: the earthwork's collision.

### Systems / balance

- **SB1 (P1) Danger follows the bosses, the wanderer never grows to meet it.** Each boss felled raises every camp's tier
  (Tiers: hp x1 -> x3, blows x1 -> x1.6); wounds_max is a flat 120 that no level, Path or gear raises, and nothing
  reduces a blow. A wretch hollows you in 4.8 blows at Dusk and 3.0 at the Umbral Night; Hobb in 3.0 already. Spell
  power grows only by gear (+2-4 % an affix). The deepening is the night's arc (keep it), but the Remembrance must be
  felt in a fight. Fix: each level of the Remembrance adds Wounds (120 -> 210 at 30) and a little spell power (+1.5 %
  a level), so the climb and the deepening meet.
- **SB2 (P1) Trash TTK vs boss TTK.** Trash 0.6-1.0 s, bosses 560-760 hp at ~3.5 dps of uptime (3-4 min) plus phase
  floors and immune intermissions: the bot dealt 82-450 in 135 s. Regular fights are free, bosses are long. Fix: CD1
  raises trash; bosses stay (they read as raids by Luke's design).

### AI programmer

- **AI1 (P1) No spacing: foes stand in the wanderer.** = CD2 (`dist 0.7-0.9` on every strike).
- **AI2 (P1) The Crown and the earthwork** (EB4): a Rift Step from the yard put the wanderer in the earthwork's rock and
  the fight never resumed. Investigate with STATUS lines; part may be map audit (collision of the earthwork).
- **AI3 (P2) The bot ran out of the Crown's arena from an edict**: the cone is 27 m long in a 32 m yard with the skull at
  its back; stepping back never clears it, only a sidestep does. Correct design, worth knowing (no change).

### QA

- **QA1 (P0)** = GF3 (hits outside the drawn cone). **QA2 (P0)** = EB2 (hits with no zone). **QA3 (P0)** = EB4 (soft-lock).
- **QA4 (P1) "BUG, indexing did not unpair geometries from light" and "softshadow_count==0"** in `C/run.log` during
  kills (backtrace: `enemy.gd _die` hiding the health bar, while Vfx.light creates and frees a fresh OmniLight3D per hit,
  per death, per landing). The CRITIQUE's QA seat saw four. Fix: Vfx.light reuses a fixed pool of lights instead of
  new/free each flash.
- **QA6 (P0, found in the re-capture) The bosses drew as gold ghosts.** `X2/abbot_s01.jpg` (and the first `R3`, `R4`
  runs): the Abbot a solid gold-white body from the name card on, with hit_flash, glint and dissolve all 0 on the mesh
  (the harness's LOOK probe) and the light pool ruled out (`X1`, the old vfx.gd: the same). Cause: the villager-look
  glow surface (ClipRig GLOW_CODE) declared its own `dissolve`, so on the same mesh the engine kept that index and the
  flesh overlay read its `dissolve` from a slot nobody writes (the log's "More than one material in instance export the
  same instance shader uniform 'dissolve'" warning, 5 a run): gold whenever that slot held junk, by luck of the buffer
  (`E2` happened to be clean, `X3` too). A master bug, not one of this round's. Fix: the glow shader has no instance
  uniforms; the warning is gone (`X4/run.log`), the Abbot dark with a lit rim on a blow (`X4/abbot_s01.jpg`, `s04`).
- **QA7 (P2) One unexplained lava burn.** `R5/ascended_warden.log` f0505: 35 wounds "from" (314.1, -15.2, -60.6), the
  rift's lava 42 m under the summit, while the STATUS lines a second before and after have the wanderer on the deck
  (y 27.4) and no Rift Step reaches 40 m. Not seen again in any run; logged, not chased.
- **QA5 (P2)** The base enemy's knockback, hitstop and death are fine in the strips; no double hits found (HURT_GRACE
  holds); no i-frame failures in the logs (every "evaded" was inside the step's 0.35 s).

### Performance

- **PF1 (P1) A 120-150 ms hitch at every fight's first frames** (`A`-`E5`, worst per batch 120-148 ms) — to be read in
  `P1`/`P2` (no capture) and attributed.
  Read (`P3`, a pull probe with no frame capture, and every `R` log): (a) every run's ~960-pipeline frame (120-140 ms)
  at ~6 s is the world's own post-build mesh merge ("ATMOS merged 2969 static meshes into 2693"), whatever the fight:
  not combat's, a load-time cost for the perf owner; (b) the rest of the 120-150 ms "pull" frames were the harness's
  own full-size JPG writes (`--full`). Uncaptured, the Thornwarden's and the Anchoress's pulls have no frame over 27 ms;
  the first pull's `boss_engaged` signal costs 18.6 ms once (its listeners' first use), 0.2 ms after.
- **PF2 (P2)** Vfx.light: a new OmniLight3D per flash (hit stars, swipes, deaths, landings, bolt impacts), freed 0.3 s
  later: light churn every hit (QA4). SpitOrb: a new Area3D + light per orb (seven per Radiant Fan).

## The fixes (worst first; each ticks when the re-capture pass shows it)

| id | fix | files | commit | re-capture |
| --- | --- | --- | --- | --- |
| EB3/AN1 | ClipRig plays a stretched (24 fps-exported, 30 fps-keyed) model at 30/24: `clip_rate`, read off the clip lengths (all whole 24ths), applied to `advance` and to every authored length (`_len`) so boss_move/telegraph/howl/strike/locomotion keep their seconds | clip_rig.gd | `d1b6296e` | `R3/run.log` "BOSS rig clip_rate 1.250" |
| EB1 | danger shader: `inner_m` (a ring's open middle) and four safe pools (`hole0..3`), cut out and outlined pale; SpellFx.danger turns opts "holes" into them (so Bloom, Echo, Verdict, Flare, Eclipse, Tolling now draw their safe ground) | danger_zone.gdshader, spell_fx.gd | `d1b6296e` | `R3` Bloom rings drawn with their gaps; `R7/hierarch_s39.jpg` the Echo a ring with its middle open |
| EB2 | the Undertow draws its 30 m reach with the four cairns' lees cut out (and hits nothing past it); the Thornstorm draws round the Warden at its real 34 m with the four nearest stones' lees cut out; the Sky Breaks is cast and drawn for its last 3 s with the lit pylons' rings cut out | anchoress.gd, thornwarden.gd, ascended_warden.gd | `d1b6296e` | `R6/anchoress_full_f2886_hurt2.jpg` the Undertow drawn, a cairn's lee pale; `R5` log f6122 the Sky Breaks drawn 3 s; `R3` the storm round the Warden |
| EB4 | a held fight resumes anywhere on its floor (radius, not the Crown's 20 m pull at the skull); holding takes back the boss's moves in the air and its cast bar | boss_arena.gd | `d1b6296e` | `R7/hierarch.log` casts to the end (no soft-lock); a held fight took up again at f6110 |
| GF2/AN3 | the melee cone fills over windup + STRIKE_AT (full on the blow's frame); the rake's arc is drawn with the blow | enemy.gd | `8f26201a` | `R1`: every melee hit at full +1/+2 f, fade 1.0 (was +13) |
| GF3/QA1 | the blow tests the cone as drawn (the rig's yaw), not the yaw it is turning to | enemy.gd | `8f26201a` | `R1`, `R8`: every hurt inside the drawn zone |
| CD1 | melee kinds take twice the blows (wretch 6, husk 10, crawler 4, leaper 8, ossuant 8, bulwark 12, pilgrim 8, burrower 6, gaunt 4); the fragile support kinds stay one/two-hit kills | the kinds | `8f26201a` | `R2`: a wretch 1.35 s (was 0.78), packs 6-9 s |
| CD2/AI1 | after a strike a foe waits `attack_gap` (1.1 s x0.8-1.3; shorter each deeper tier) circling at the ring before its next tell; its lunge stops at max(0.75 reach, 1.1 m), not in the wanderer | enemy.gd, tiers.gd | `8f26201a` | `R1`, `R8`: blows at 0.97-1.19 m (was 0.7-0.9); a chain, then the gap |
| GF1 | a plain bolt's impact dome 0.64 m over 0.2 s (was 1.3 m, 0.32 s), its shell and ring smaller; the Lash's dome 0.9 m and its shell thin and quick (the ground disc keeps the true radius) | magic_bolt.gd | `8f26201a` | `X4/abbot_s01.jpg`: the bolt's pop small and quick |
| GF4 | every pounce's disc fills over the coil and the flight (full as it lands; it was full 0.9 s early) | enemy.gd | `8f26201a` | `R1/leaper`: full at the landing; `R8/flank2.log` f0094 the hit at 0.93 (it lands on contact, 0.1 s before the disc's end) |
| GF5 | a tell lights the attacker: glint held at 1 through a windup, a coil or a tell-bearing special; the flesh and grunt shaders add an ember rim with it | enemy.gd, flesh.gdshader, grunt_pbr.gdshader | `8f26201a` | `R1`: the tell rim reads at night |
| EB5 | the Radiant Fan keeps its 32 m cone when tracking and holds it while the orbs cross it | ascended_warden.gd | `d1b6296e` | `R5/ascended_warden.log` the cone 32 m and held: the orbs land +72 f after full, inside it |
| EB6 | the Bramble Lash reaches round the whole 11 m body (LASH_R 4.6 -> 8.0) | thornwarden.gd | `d1b6296e` | `R3` the Bramble Lash fires |
| EB7 | the henge's close is a 10 s cast bar (the Sky Breaks: EB2) | thornwarden.gd | `d1b6296e` | `R3` the henge's close a cast bar; `R5` f6122 "The Sky Breaks" 3 s |
| AN2 | the Anchoress's swing strikes 0.26 s before its lane lands (the clip's slam on the landing) | anchoress.gd | `d1b6296e` | `R6/anchoress.log` f5812: the swing lands at its lane's 0.99 |
| AN4 | a great one's hit flash scales with the blow (0.3 for a plain bolt) and lights the rim, not the whole body | enemy.gd, villager_boss_rig.gd | `d1b6296e` | `X4/abbot_s04.jpg` f380: a lit edge on a blow |
| GF6/AN5 | a blow of 24+ catches the world for 0.05-0.1 s and shoves the wanderer off it | player_vitals.gd | `90b07676` | `R5`, `R6` logs: blows of 24-55 shove and catch |
| GF7/UX6 | world text near the camera shrinks (to half at 3 m): "SHELTERED", the kill chain, no longer run off the screen | hit_text.gd | `8f26201a` | `R2`: the chain text no longer runs off the screen |
| UX1 | a close lock tips the view down (up to 0.26 rad at 1.5 m) | player_targeting.gd | `90b07676` | `R1`: the close lock shows the foe and its cone |
| UX4 | the lock aims at an airborne foe's ground height | player_targeting.gd | `90b07676` | `R1/leaper`: the landing disc stays in frame |
| EB8 | the lock aims no higher than 3 m over a foe's feet (a 9 m boss: the floor and its red stay in frame) | player_targeting.gd | `90b07676` | `R4`, `R5`: the floor and its red in frame |
| UX5 | a camera pressed short by a wall lifts over the hood (up to 0.85 m, as far as the space above allows) | player_camera.gd | `90b07676` | `R4`: the camera lifts over the hood at the hall's wall |
| UX2 | in a fight the lesson and narration lines start 500 px higher (under the frames, off the ground round you); village barks wait for the fight's end | text_director.gd, dialogue.gd, village_barks.gd | `90b07676` | superseded by UX8 (the lift still sat on the boss) |
| UX3 | ThreatCues: painted edge marks (new icons hud/threat_melee, hud/threat_ranged, tools/icon_kit/threat_hud.py) turned toward a foe winding up out of view, swelling with its tell | ui/threat_cues.gd, hud.gd | `90b07676` | `R8/flank2_s04.jpg` f216-f264: the mark at the edge toward the Gaunt behind; enlarged after (UX3b) |
| SB1 | each Remembrance level: +3 Wounds (120 -> 210 at 30) and +1.5 % spell power; a level-up refreshes them | kindling.gd, hearth.gd | `90b07676` | `R4`: wounds 0/123 at level 1 |
| QA4/PF2 | Vfx.light reuses a fixed pool of 12 OmniLights (hidden when out) instead of new/free per flash | vfx.gd | `8f26201a` | `R1`-`R7` logs: no "unpair" error in a fight |
| GF8 | the Rift Step's tear fades out within 2.4 m of the camera | rift_tear.gdshader | `952f2098` | `V1/warden_s43.jpg` f3920-f3930: no tear at the lens; one 3 m off still a fifth of the frame for 0.3 s (left as is) |
| GF1b | the Lash's ground disc lies on the ground under a burst on a body or a wall (laid across a body's normal it stood up as a 6 m lightning wheel in front of the foe) | magic_bolt.gd | `952f2098` | not caught in a strip (no Lash burst on a body in view in `R`/`V`); by code |
| AN4b | the boss hit flash is a faint rim (0.4 x rim², a plain bolt 0.15): at 1.0 over the whole body (and 0.3 under a held trigger) every great one was a white silhouette all fight (`R3`, `R4` first runs) | villager_boss_rig.gd, enemy.gd | `952f2098` | `X4/abbot_s04.jpg` f380: a faint lit rim, no white body |
| QA6 | the villager-look glow surface declares no instance uniforms (its `dissolve` took the overlay's slot: the gold ghost); the beast rig's hit flash is the rim one too | clip_rig.gd, beast_rig.gd | `952f2098` | `X4/run.log` no conflict warning; `X4/abbot_s01.jpg` the Abbot dark |
| EB9/UX7 | the Warden's colour is a saturated gold (2.6, 1.5, 0.4), not white-gold; the lock aims no higher than 6 m over the wanderer's feet; the Sky Breaks' bar closes as finished at the fall | boss_kit.gd, player_targeting.gd, ascended_warden.gd | `52c3923e` | `V1/warden_s40.jpg` f3600: the deck gold under the Sky Breaks; `V1` log f3602 its bar ends as finished, the zone full at 3.00 s; `V1/warden_s30.jpg` the risen phase: the deck and the star discs in frame; `V1/warden_s43.jpg` the Radiant Fan's cone gold on the grey deck |
| UX8 | in a fight lessons and the wanderer's voice lines go to a left column (left-aligned, at most 600 px), not lifted over the boss | text_director.gd, dialogue.gd | `52c3923e` | `X5/anch_s03.jpg` f348-f420: the lesson in the left column, the Anchoress clear |
| UX9 | the minimap's gear-gap line keeps inside the screen | minimap.gd | `52c3923e` | `X5/anch_full_f1269_tell6460.jpg`: the whole line inside the screen |
| UX10 | the Resonance spend pops its gains on a second line, from the shoulder (at 2.4 m it rose into the boss bar, `X5/anch_s03.jpg`); a long world line is set smaller by its longest line | skill_book.gd, hit_text.gd | `52c3923e` | `V1/warden_s41.jpg` f3700-f3720: two lines, from the shoulder |
| UX3b | the threat marks 58 px (44 read as a speck in `R8/flank2_s04.jpg`), riding a little further in | threat_cues.gd | `52c3923e` | by code (the size); `R8` showed the marks working |
| UX11 | a great one's body is solid to the wanderer out to its footprint; one inside is eased out | boss_kit.gd, enemy.gd | `52c3923e` | `V2/anch.log`: her footprint 1.98 m, the wanderer at 1.8-2.9 m from her centre in melee (was 0.91); `V2/anch_s06.jpg` the lens outside her skirt, her arms, chain and lantern in frame |
| GF9 | the Lance's aim circle fades out near the lens | target_ring.gdshader | `52c3923e` | not caught in a strip after the fix (no Lance aimed into a wall in `V`); by code |
| GF10 | a bolt's dome, shell and ring at the lens are set smaller by their distance to it | magic_bolt.gd | `52c3923e` | made after `V1`; by code |
| PF3 | NavAssist: a query searches 160 polygons per metre to the goal (at least 4096, not the whole 75k mesh), and a query that teaches nothing doubles the wait before the next (to 4 s): the Crown's yard hitched 25 ms of physics every 0.58 s | nav_assist.gd | `8f26201a` | `R7/hierarch.log`: 2 physics spikes over 15 ms in 135 s (`E5`: 92, every 0.58 s) |
