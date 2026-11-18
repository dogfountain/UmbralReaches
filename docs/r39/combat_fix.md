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

## Findings so far, from the code (each still needs its strip/log before it counts)

Format: **id** seat, severity (P0 broken / P1 bad / P2 weak). What, evidence, fix, commit.

- **C1** Animator/QA, P0. Every Blender boss clip plays 1.25x slow. vb_kit keys at 30 fps (`tools/blender/vb_kit.py`
  FPS = 30, frame = 1 + t*30) in a scene exported at 24 fps: every GLB clip is 1.25x its authored length plus 1/24 s
  (abbot idle 6.0 -> 7.54 s, strike 1.25 -> 1.62; first key of every track at 0.0417 s). The fight code was timed
  to the AUTHORED times (Crown verdict jolts 1.4/2.3/3.2 = its rings; Thornstorm crash 3.2 = STORM_TIME; abbot sweep
  1.05 = its zone), so every boss body lands 0.3-0.8 s after its red. Fix (code only, no re-export): ClipRig reads
  the first key time of a track; 1/24 s means a 30-fps-keyed clip in a 24 fps export: advance the player and report
  lengths at 30/24 (a correct future export reads 1/30 and plays at 1.0). Verify: strike/move strips per boss.
- **C2** Encounter/QA, P1. Most boss moves call `boss_move(clip, 0.0)` (natural length) whatever their cast time;
  with C1 fixed most match (authored to the game's times), the rest need their `dur` (check each in strips:
  thornwarden mend 3.7 vs 3.0, anchoress swing `_strike_after(1.15)` + slam 0.26 vs zone 1.3, echo 1.0 vs 1.3...).
- **C3** Game feel/UX, P0. The danger shader draws no "holes": six boss moves paint their SAFE ground red (Thornwarden
  Bloom, Crown Echo and Verdict: rings drawn as full discs, nothing marks the gaps; Warden Flare, Eclipse and the
  Abbot's Tolling: a column/ring marks the pool but the red fill covers it). Fix: inner radius and up to four hole
  discs as instance uniforms in danger_zone.gdshader, set by SpellFx.danger from opts "holes" (discarded inside,
  a pale safe contour), the fill travelling inner -> outer on a ring.
- **C4** QA, P0. Ascended Warden Radiant Fan: created r 32 m, but `_track_fan` rewrites the transform with
  `Basis.from_scale(Vector3(20, 1, 20))`: the drawn cone shrinks to 20 m on its first tracked frame (size_m stays 32,
  so its outline widths are off too) while the orbs fly on. Fix: keep the cone's own radius.
- **C5** QA/UX, P0. Thornstorm draws a 30 m disc on the arena centre, but wounds anywhere within 34 m of the BOSS
  unless sheltered. The Anchoress's Undertow draws no red at all (a decorative 14 m ring) and wounds everywhere
  unsheltered. Both break "no red on the ground, no hit". Fix: the zone drawn is the zone that hits (centre/radius
  of the real test; the lee drawn as holes via C3).
- **C6** Combat/QA, P1. Base melee strike: the cone fills over the windup, the blow lands STRIKE_AT 0.2 s (12 frames)
  later while the cone is already fading; the cone tracks the wanderer all windup and is drawn at the rig's smoothed
  yaw while the hit tests `_face_dir` (the target yaw): a fast circle can be outside the drawn cone and still hit.
  Log: HURT lines (frames after FULL, inside_drawn).
- **C7** Encounter, P1. Thornwarden (SCALE 3.8, ~9 m long) keeps player-sized ranges: Bramble Lash LASH_R 4.6 and the
  inherited leaper tail sweep `d > 2.6` fire only when the wanderer is under its body. Scale to its body.
- **C8** Systems, P1. The wanderer's survivability never grows (wounds_max 120 fixed: no level, gear or path raises
  it; no damage reduction) while each boss felled raises every camp's tier (hp x1 -> x3, blows x1 -> x1.6): a
  wretch hollows you in 4.8 blows at Dusk and 3.0 at Umbral Night. Fix candidate: Remembrance level raises
  wounds_max (and/or the tier's blow multiplier is offset by level), so danger is met by growth.
- **C9** Combat designer, P1 (to confirm in the fight-bot logs). Trash dies before it can tell: held Rift Bolt
  ~4.8 dps vs wretch 3 hp (0.6 s), husk 5 (1.0 s), even Umbral Night under 2 s (calc/ttk.py). The windup/feint/poise/
  parry/guard game never comes up; bosses take ~3 min of uptime (560-760 hp). Check TTK in logs first.
- **C10** UX, P1. No off-screen threat cue: flankers circle to your side, the Gaunt stalks your off-side (110 deg
  from the camera's forward) and darts, the hurt wash only tells you after. God of War 2018's edge arrows (ember
  melee, teal ranged) filling with the tell. Painted icon via tools/gen_icons.py (Blender lock). Log: "OFFSCREEN" on
  WINDUP/HURT lines.
- **C11** Game feel, P2 (to confirm). Being hit has no weight on the wanderer: no hit-stop, no shove, only a torso
  rock, a kick and the wash; a 30-wound blow and a 5-wound nibble feel alike.
- By design (Luke, r35), not to be reverted: a walk-out holds a boss fight without healing (BossArena._hold_fight).

## Findings from the captures

(pending: nothing captured yet)
