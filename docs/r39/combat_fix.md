# r39 combat: the brutal critique, then the fix (live checklist)

Luke, 18 Nov: "Spawn another extra agent to fix combat." Brief: `docs/r39/briefs/combat_fix.md`. Branch `combat-fix` in
`/Users/luke/UmbralReaches_combat`. This file is the live checklist: every finding, its evidence, its fix and the
commit. Resume from "State" below.

## State (paused 18 Nov, 20:35, by Luke's order: combat runs only after the map audit is merged)

Done:
- [x] Brief, pillars, CRITIQUE, boss plan, skills and the last DECISIONS rows read; the combat code read (enemy.gd,
      attack_kit, boss_kit, clip_rig, the five bosses' move code, player casting/vitals/targeting/camera, skills,
      tiers, elites, the danger shader, the hurt wash).
- [x] Harness written, NOT yet run once: `zz/combat_strip.tscn` (see "Harness" below). The first run was queued behind
      the lock and cancelled at the pause; nothing was captured yet.

Next, in order (resume here):
1. Rebase/merge `combat-fix` onto master once the map audit is merged (the arenas' surroundings may have moved).
2. First harness run to shake it out (it has never run; expect small script errors):
   `gd.sh 300 <scratch>/t1/run.log -- --path . res://zz/combat_strip.tscn -- --out=<scratch>/t1 "--fights=wretch_stand=wretch@6;pack_fight=pack" --bot=stand --secs=8 --every=6 --full=hits`
   (`gd.sh` is in the scratch folder: it takes /tmp/umbral_godot.lock, retrying every 30 s, runs godot with a hard
   timeout and always frees the lock. Run it with run_in_background and wait for the notification.)
3. Capture batches (each run under ~3 min): A stand-bot singles (wretch husk crawler leaper ossuant bulwark gaunt
   pilgrim mite burrower); B stand-bot ranged/casters (spitter chanter quiller tollman cinder_caster brood_mother) and
   elites (hobb, old_sunk, briar_hart: the harness spawns `elite_<id>.gd` by name); C fight-bot packs (pack warband
   r31 casters burrow); D melee-bot (wretch husk bulwark); E-I each boss in its arena, `boss:<id>` and later phases
   with `boss:<id>@0.6` / `@0.3` (thornwarden bone_abbot ascended_warden anchoress hierarch); a perf run with
   `--every=0` for one big pack and each boss.
4. Read every sheet at full size, run `calc/logsum.py` on the logs (scratch), write the critique below by seat.
5. Fix worst first; verify each with a fresh strip/log; tests once at the end (the list in the brief).

Machine/lint notes for the fixer:
- `tools/lint.sh` is a ratchet: `core/enemy/enemy.gd` is at its line cap (2352 = baseline 2302 + 50), so any
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
- **GF6 (P2) Being hit has no weight** (AN5). **GF7 (P2)** a kill's "SHELTERED"/"evaded" world text is drawn huge and
  clipped at the screen edge when the camera is close (`E1/thornwarden_s28.jpg` "HELTERED").

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
- **UX6 (P2)** "CHAIN x9" combo text drawn 4x larger than the boss name over the fight (`C2/f_warband_s01.jpg`).

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
- **QA5 (P2)** The base enemy's knockback, hitstop and death are fine in the strips; no double hits found (HURT_GRACE
  holds); no i-frame failures in the logs (every "evaded" was inside the step's 0.35 s).

### Performance

- **PF1 (P1) A 120-150 ms hitch at every fight's first frames** (`A`-`E5`, worst per batch 120-148 ms) — to be read in
  `P1`/`P2` (no capture) and attributed.
- **PF2 (P2)** Vfx.light: a new OmniLight3D per flash (hit stars, swipes, deaths, landings, bolt impacts), freed 0.3 s
  later: light churn every hit (QA4). SpitOrb: a new Area3D + light per orb (seven per Radiant Fan).

## The fixes (worst first; each ticks when the re-capture pass shows it)

| id | fix | files | commit | re-capture |
| --- | --- | --- | --- | --- |
| EB3/AN1 | ClipRig plays a stretched (24 fps-exported, 30 fps-keyed) model at 30/24: `clip_rate`, read off the clip lengths (all whole 24ths), applied to `advance` and to every authored length (`_len`) so boss_move/telegraph/howl/strike/locomotion keep their seconds | clip_rig.gd | | |
| EB1 | danger shader: `inner_m` (a ring's open middle) and four safe pools (`hole0..3`), cut out and outlined pale; SpellFx.danger turns opts "holes" into them (so Bloom, Echo, Verdict, Flare, Eclipse, Tolling now draw their safe ground) | danger_zone.gdshader, spell_fx.gd | | |
| EB2 | the Undertow draws its 30 m reach with the four cairns' lees cut out (and hits nothing past it); the Thornstorm draws round the Warden at its real 34 m with the four nearest stones' lees cut out; the Sky Breaks is cast and drawn for its last 3 s with the lit pylons' rings cut out | anchoress.gd, thornwarden.gd, ascended_warden.gd | | |
| EB4 | a held fight resumes anywhere on its floor (radius, not the Crown's 20 m pull at the skull); holding takes back the boss's moves in the air and its cast bar | boss_arena.gd | | |
| GF2/AN3 | the melee cone fills over windup + STRIKE_AT (full on the blow's frame); the rake's arc is drawn with the blow | enemy.gd | | |
| GF3/QA1 | the blow tests the cone as drawn (the rig's yaw), not the yaw it is turning to | enemy.gd | | |
| CD1 | melee kinds take twice the blows (wretch 6, husk 10, crawler 4, leaper 8, ossuant 8, bulwark 12, pilgrim 8, burrower 6, gaunt 4); the fragile support kinds stay one/two-hit kills | the kinds | | |
| CD2/AI1 | after a strike a foe waits `attack_gap` (1.1 s x0.8-1.3; shorter each deeper tier) circling at the ring before its next tell; its lunge stops at max(0.75 reach, 1.1 m), not in the wanderer | enemy.gd, tiers.gd | | |
| GF1 | a plain bolt's impact dome 0.64 m over 0.2 s (was 1.3 m, 0.32 s), its shell and ring smaller; the Lash's dome 0.9 m and its shell thin and quick (the ground disc keeps the true radius) | magic_bolt.gd | | |
| GF4 | every pounce's disc fills over the coil and the flight (full as it lands; it was full 0.9 s early) | enemy.gd | | |
| GF5 | a tell lights the attacker: glint held at 1 through a windup, a coil or a tell-bearing special; the flesh and grunt shaders add an ember rim with it | enemy.gd, flesh.gdshader, grunt_pbr.gdshader | | |
| EB5 | the Radiant Fan keeps its 32 m cone when tracking and holds it while the orbs cross it | ascended_warden.gd | | |
| EB6 | the Bramble Lash reaches round the whole 11 m body (LASH_R 4.6 -> 8.0) | thornwarden.gd | | |
| EB7 | the henge's close is a 10 s cast bar (the Sky Breaks: EB2) | thornwarden.gd | | |
| AN2 | the Anchoress's swing strikes 0.26 s before its lane lands (the clip's slam on the landing) | anchoress.gd | | |
| AN4 | a great one's hit flash scales with the blow (0.3 for a plain bolt) and lights the rim, not the whole body | enemy.gd, villager_boss_rig.gd | | |
| GF6/AN5 | a blow of 24+ catches the world for 0.05-0.1 s and shoves the wanderer off it | player_vitals.gd | | |
| GF7/UX6 | world text near the camera shrinks (to half at 3 m): "SHELTERED", the kill chain, no longer run off the screen | hit_text.gd | | |
| UX1 | a close lock tips the view down (up to 0.26 rad at 1.5 m) | player_targeting.gd | | |
| UX4 | the lock aims at an airborne foe's ground height | player_targeting.gd | | |
| EB8 | the lock aims no higher than 3 m over a foe's feet (a 9 m boss: the floor and its red stay in frame) | player_targeting.gd | | |
| UX5 | a camera pressed short by a wall lifts over the hood (up to 0.85 m, as far as the space above allows) | player_camera.gd | | |
| UX2 | in a fight the lesson and narration lines start 500 px higher (under the frames, off the ground round you); village barks wait for the fight's end | text_director.gd, dialogue.gd, village_barks.gd | | |
| UX3 | ThreatCues: painted edge marks (new icons hud/threat_melee, hud/threat_ranged, tools/icon_kit/threat_hud.py) turned toward a foe winding up out of view, swelling with its tell | ui/threat_cues.gd, hud.gd | | |
| SB1 | each Remembrance level: +3 Wounds (120 -> 210 at 30) and +1.5 % spell power; a level-up refreshes them | kindling.gd, hearth.gd | | |
| QA4/PF2 | Vfx.light reuses a fixed pool of 12 OmniLights (hidden when out) instead of new/free per flash | vfx.gd | | |
| PF3 | NavAssist: a query searches 160 polygons per metre to the goal (at least 4096, not the whole 75k mesh), and a query that teaches nothing doubles the wait before the next (to 4 s): the Crown's yard hitched 25 ms of physics every 0.58 s | nav_assist.gd | | |
