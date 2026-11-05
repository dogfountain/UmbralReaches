# r30 critique: game design (veteran designer's read of the code and data)

Read from the working tree on 2026-11-04 (many files modified and not committed, including
`core/world/boss_arena.gd`, which someone changed while this review was running: see finding 1).
Godot was not run. Line numbers are for the current working tree.

## Verdict

The pieces are good. The telegraph rule ("no red, no hit") holds everywhere. The enemies are
varied and each has a counter (shield, sigil, burrow, swarm, the heap that has to be Marked). The
traversal kit is deep, and the director's rest/tide/ambush layer is a real Souls-style structure.

The **risk loop is hollow**, though. Gloom is the health bar, but filling it costs almost nothing:
- the Shade that is meant to end you dies to one bolt;
- death refills Gloom and sends you to the fire;
- a 24-second-cooldown Ward makes you untouchable to bosses and heals 84 Gloom;
- the same Ward also counts as a full rest.

Boss fights are short enough that their best patterns are seen once. The player is never asked
to choose a checkpoint, a risk or a build that hurts. The one hard blocker, the henge seal shutting
in the player's face, has a correct cause and a partial fix in the tree, but the henge's geometry
still lets the fight leak. Fix the loop (findings 2-6) before adding any content. Every later
night will inherit it.

Severity: **Critical** (blocks play or breaks the core loop), **High** (clearly hurts most
players), **Medium** (hurts some, or wastes a good system), **Low** (polish).

---

## Critical

### 1. The Thorn Henge seal closes in front of the player and locks them out of the fight (the reported bug)

**Cause.** In `core/world/thorn_henge.gd:246-247`:
```gdscript
var seal := WardSeal.make(self, "henge", gp + gout * 0.05, gout, 3.3, 4.6, "thorn", "The thorn seal")
var arena := BossArena.make(self, "thornwarden", "The Thornwarden", C, R - 0.6, Thornwarden, ...)
```
- The **seal** (the gate) stands on the menhir ring, at `RING` = **10.5 m** from the centre
  (`gp`, line 164).
- The arena's **trigger radius** is `R - 0.6` = **12.4 m**.
- The stair arrives at the terrace edge, at `R` = **13 m** (`gate2`, line 66).
- HEAD's `BossArena._physics_process` started the fight as soon as the player was within 12.4 m
  horizontally and above `-1 m` relative to the floor (line 128).

So the fight started on the last steps and the terrace lip, 1.9 m *outside* the gate:
1. The boss rose inside the ring.
2. `gate.close()` put a 3.3 x 5.8 m thorn wall (`ward_seal.gd:44`, `size.y + 1.2`) between the
   player and the boss.

The Realm makes it worse. The stair swings round the hill and arrives slantwise
(`_realm_head_dir`). Its inner edge (the flight is 3.9 m wide) passes inside 12.4 m while it is
still within 1 m below the plateau, so the trigger can fire on the steps themselves. The fight then
stays active: the boss is leashed inside the ring, and nothing resets it until you go past
`radius + LEAVE` = **18.4 m**. From the player's side you are on the stair, the boss bar and title
card are up, and the gate is shut in your face.

**A partial fix is in the tree.** `core/world/boss_arena.gd` (untracked, changed 20:38 during
this review) adds `GATE_CLEAR := 1.5` and `_past_gate()`. The fight starts only once the player is
1.5 m inside the gate's line, on the arena's side, and only for a gate within `radius + 2` of the
centre. That is the right test, and it leaves the Ossuary and summit alone: their gates are 19.9 m
and 33 m away, so they are skipped. Keep it.

**What is still wrong, and the full fix.**
- **The henge does not contain the fight.** The 22-stone ring has one gap (the gate). The other
  21 stones stand about 3.1 m apart, centre to centre, and the moss skirt has radius 0.58, so
  roughly 2 m gaps remain (confirm on the GLB collision). The only solid wall is the bramble hedge
  at `HEDGE` 12.2 m, and **its gap is outside the seal** (line 190, half-angle 0.32 rad = a 7.7 m
  chord). Mid-fight, a player can step between two stones into the annulus and walk out through
  the hedge gap past the closed seal. The arena then resets at 18.4 m: an exit that resets the
  boss, and a gate that seals nothing.
  - *Fix:* move the seal to the stair head, across the hedge gap:
    `WardSeal.make(self, "henge", head - dir3 * 0.4, -dir3, 4.6, 4.6, ...)`, facing up the
    flight.
  - Narrow the hedge gap to match: half-angle `asin(2.4 / HEDGE)` ≈ 0.2 rad. The Realm's slantwise
    arrival needs the seal turned to `dir3`, which the line above already does.
  - Leave the trilithon as dressing.
  - `_past_gate` then measures from the hedge line. The fight starts 1.5 m inside the hedge, the
    whole ring is the arena, and the seal really seals.
- **Split trigger and leash.** Give `BossArena` a `trigger_radius` (default `radius`) separate
  from the leash `radius`. Henge: trigger 10.5 (the stone ring), leash 12.4. That makes "the fight
  begins when you step through the stones" true without depending on gate geometry.
- **The hedge can be climbed** (verify in play). It is a 4.2 m box (line 204):
  - a held jump plus the air jump puts the feet at about 1.97 m (measured with the player's
    gravity, apex and air-jump values), and `GRAB_MAX` 2.25 then reaches 4.22 m;
  - a wall kick off the hedge (`KICK_UP` 6.4) adds about 1.4 m more.

  Raise the hedge collision to 6.0 m, or tag it `no_grab` meta and have `_try_grab` and
  `_can_wallkick` skip it.
- **Test.** `ThornHenge.stair_pts` already exists. Add a `boss_test` leg that walks foot, landing,
  head and inside, and asserts:
  - the arena is not active at `head`;
  - it is active at `stair_pts[4]`;
  - the seal is shut and the player is on the inner side of it.
- **Polish.** The thorn seal pops in and out with no motion: `close()` and `release()` tween
  `position:y` from 0 to 0 for the "thorn" look. Tween `_vis.scale.y` 0.02 → 1 over 0.45 s with
  `TRANS_BACK` (the thorns erupt), and the reverse on release.

### 2. The fail state does not threaten: the Shade dies to one bolt, and death heals

Evidence:
- `shade.gd:408-411`: any `take_hit` calls `dissipate()`. A single 1-damage Rift Bolt, or any
  blast within 1.8 m of the hurtbox, unmakes it.
- `player.gd:716` / `:745`: at full Gloom a new Shade is held back only 2 s after a bolt kills
  one. Gloom stays at max, and further hits do nothing (`add_gloom` clamps).
- `player.gd:785-791` `_respawn_now`: `gloom = 0`. A hollowing is a free full heal plus a teleport
  to the fire. No ash is lost and no state is kept.

The player-facing problem: past 100 Gloom the game becomes "turn round and click every ~5 s". Up
to 100 it is cosmetic. Taking hits has no lasting cost, so reading tells only matters in boss
fights. Even there a death costs only the walk back (finding 7).

Fix (pick a coherent set):
- **Bolts drive the Shade back but do not unmake it.** On a bolt hit:
  - knock it back 8 m and stun it for 1.5 s;
  - reduce its `REACH` approach for 2 s.

  Only light unmakes it: a lit brazier, a Ward, or Nova (keep "Nova unmakes shades" as the panic
  answer, at 7 s cooldown).
- **Each Shade that is driven off comes back faster.** `speed` 5.2 → +0.6 per return, capped at
  7.2. Sprint is 7.5, so running to a fire still works but walking does not.
- **Over-cap hits matter.** A hit taken at full Gloom adds 1 s to a "Hollowing" meter shown on the
  Gloom bar. 3 s of it, or a Shade touch, hollows you.
- **Hollowing costs something recoverable.** Drop the ash carried since the last kindle (or 50 %
  of `grave_ash`) as an ash-mound at the death spot. Walking to it returns the ash; dying again
  first loses it. This makes "push on or go back to the fire" a real decision and gives the run
  back its tension. A softer alternative: respawn with 35 Gloom, not 0.

### 3. Lantern Ward is a 7-second boss immunity plus a near-full heal every 24 s

Evidence:
- `lantern_ward.gd:7-8,113`: `LIFE` 7 s, `RADIUS` 7 m, registered with `LightGrid`.
- `enemy.gd:966` `_light_barrier()` runs for **every** enemy, bosses included. `BossKit.embiggen`
  (`boss_kit.gd:221`) only clears `light_averse`, and pounces are redirected outside the light
  (`enemy.gd:958`).
- `player.gd:42`: drain inside light is 12 Gloom/s, so one Ward drains 84 Gloom.
  - With Long Wick (10 s): 120.
  - With the Oath of the Hearth (+60 %): 19.2/s.
- `skill_ward.gd` cooldown 24 s (17 s at rank II).

The player-facing problem: melee bosses cannot touch you for 7 s in every 24. In Thornwarden
phase 1 the boss literally circles the ring while you shoot it. The Ward also wipes most of the
health bar each time, so the safest play is "Ward, stand, shoot". It bypasses every telegraph the
team built.

Fix:
- Bosses (and elites) ignore `_light_barrier`: `if boss: return` at the top. They respect fires,
  not the wanderer's own lantern.
- The Ward drains at its own rate: 4/s, at most 25 Gloom per cast. Expose it as
  `LightGrid.register(self, RADIUS, {"drain": 4.0, "rest": false})`, have
  `Player._update_gloom` read the zone's drain, and keep 12/s for braziers.
- Ordinary enemies still siege its edge (that interaction is good). Tune it as a 4-5 s breather,
  not a fortress.

### 4. A Lantern Ward (or a Mirror) counts as a full rest: the camps refill and the tide breaks

Evidence:
- `director.gd:252-262` `_rest_tick` uses `LightGrid.is_lit(pos)`. After moving 25 m from the
  last rest, 3 s in *any* registered light calls `rest("stood")`. That runs:
  - `spawner.refill(24)`: every killed roaming pawn more than 24 m away comes back;
  - the "You rest by the fire..." toast;
  - a reset of the tide clock.
- 1.5 s in the light (`SAFE_STAND`) ends a Gloom tide.

The player-facing problem: casting your Ward in the field silently respawns every camp on the map
behind you. The Gloom tide ("reach a lit fire") is broken by pressing F. Both undo the director's
main structure.

Fix: only fires rest. Have `LightGrid` carry a zone kind (`"fire" | "ward" | "mirror"`) and expose
`LightGrid.is_fire(pos)`. `_rest_tick` and the tide-break test use `is_fire`; everything else
(drain, shade, enemy slinking) keeps `is_lit`.

---

## High

### 5. The checkpoint is set only the first time a fire is kindled

Evidence: `brazier.gd:58-69`. Interacting with a **lit** brazier opens the attune menu and returns.
`set_checkpoint` is only reached on the unlit → lit path. No other caller moves the checkpoint
except the zone load (`zone.gd:117`, `main.gd:252`).

The player-facing problem: your respawn is the *last fire you lit*, not the last fire you rested
at. Kindle the Threshold (the fen) and then go back to fight the Thornwarden from the HengeFire,
and every death sends you across the map to the fen. Players will read this as a bug.

Fix: resting sets the checkpoint. In `Brazier.interact()` on a lit fire, call
`by.set_checkpoint(spawn_point())` before opening the satchel. Also set it from the director's
`rest("stood")`: pass the brazier, or look up the nearest `Brazier` within its `light_radius`. Toast
"The fire will remember you." once per change.

### 6. Passive Gloom gain makes the Abbot and Warden fights a 28-second timer to a Shade

Evidence:
- `player.gd:43,704`: the rift rate of 3.5/s applies to **every** position with `z < -40`, not to
  the rift itself. That covers the Ossuary pit (z -86), the Lower Count, the summit and the dais
  (z -104).
- The arenas have no registered light. 100 / 3.5 is **28.6 s** to full Gloom without a single hit
  (45 s with Banked Coals III).
- The r29 kill times put the Warden at 13-19 s at 60 HP. Now at 120 HP it is about 26-38 s at
  rank 0.

The player-facing problem: in the two hardest fights the dark fills on its own. Add 22-42 per boss
hit, and the Shade turns up mid-fight in almost every attempt, then every ~5 s (finding 2). That is
noise on top of the boss's own patterns. The z-test is also a hidden rule that players cannot see
on the map.

Fix:
- Scope the rift rate to the rift: `RealmLayout.region_at(x, z).id in ["rift"]` (the ashen rift
  proper), not `z < rift_z`.
- Inside an active `BossArena`, passive dark gain is 0. The boss is the pressure. Expose
  `BossArena.active_at(pos)` and check it in `_update_gloom`.
- Optional, and better: put two unlit **arena braziers** on each arena rim, kindled mid-fight with
  E. They are tactical light (enemies slink, bosses are not barred, per finding 3) that drains
  12/s, and they go out when the fight resets.

### 7. Boss fights end before their patterns are learned (and the runbacks punish dying)

Evidence:
- HP is 72 / 90 / 120 (`thornwarden.gd:22`, `bone_abbot.gd:33`, `ascended_warden.gd:25`).
- A held Rift Bolt at rank 0 is (1+1+2) / (3 x 0.28 s) = **4.76 dps**, every shot an AoE with a
  1.8 m blast that also Marks.
- Late game with Kindled Will III (+30 %), the Clapper (+8 %), the Lash oath and Lodestar, this
  reaches about 7-8 dps.
- Phase 3 of the Abbot (22.5 HP) lasts about 3-5 s, and the Requiem fires once at 2.2 s
  (`bone_abbot.gd:66`). Warden phase 3 (36 HP) is about 5 s, two blinks.
- Runbacks: the nearest fire to the Warden is StairFoot at (-5, -2), about 105 m of Crossing and
  stair from the dais at (0, 27.35, -103.9). The nearest to the Abbot is the Threshold at (47, -55),
  roughly 45 m plus the fen stair and the gallery. There is no fire on the summit.

The player-facing problem: the bosses' signature mechanics (the Requiem, the Cage, the Warden's
double fans and halo ring) are seen once or not at all, so there is no mastery arc. When a fight
does go wrong, the runback is long.

Fix:
- **HP:** 110 / 160 / 220.
- **Bosses take 0.7x from non-heavy bolts.** Add `boss_chip := 0.7` in `Enemy.take_hit` when
  `boss and not from.heavy`. Lance, Nova detonations and Shatter stay full, so charged and combo
  play is how you kill a boss.
- **Phase floors:** a phase cannot end before it has run its signature move twice. Clamp
  `hp >= next_mark * max_hp + 1` until the phase's move counter reaches 2, and show "warded" (the
  existing `_ward_t` look) while clamped, so it reads as a rule, not a bug. Suggested counters:
  - Thornwarden phase 2: two lane volleys.
  - Abbot phase 3: two Requiems.
  - Warden phase 2: two judgements; phase 3: two double fans.
- **A summit fire:** a checkpoint brazier on the summit platform at (0, 25.4, -78), outside the
  dais. It also answers HANDOFF's "the summit dais is lit only by the player's lantern".

### 8. The final boss telegraphs in the player's own colour

Evidence:
- `boss_kit.gd:10` `HOLY := Color(1.4, 0.6, 2.6)` is used for every Warden zone (blink ring,
  judgement lanes, fan cone).
- `player.gd:166` `VIOLET := Color(1.3, 0.6, 3.0)` is the bolt; the Nova is `#C04DFF` and the
  Lash discs are VIOLET.
- The Abbot's lethal cage centre and grave-fire pools are `GRAVE_FIRE (1.1, 0.5, 2.4)`, also
  violet.
- r29 critique A item 9 noted it as S3 and left it as "an art call".

The player-facing problem: the busiest fight in the game, full of your own violet bursts, draws its
danger in the same hue. "No red, no hit" turns into "no violet, no hit", in a sea of violet.

Fix:
- Judgement and halo become pale gold: `HOLY := Color(2.4, 1.9, 0.8)`. Hue is about 45°, inside
  the grade's protected warm band at that brightness (`grade.gdshader` warm 8-66°).
- The Abbot's `GRAVE_FIRE` becomes bone-green, or the ember used for cages.
- Then make it a rule: **enemy danger is never in the 250-290° hue band.** Add a check to
  `critA_harden` that every `BossKit.zone` / `AttackKit.zone` colour stays out of it.

### 9. Holding LMB is the dominant strategy; the Lance is a downgrade

Evidence:
- `skill_bolt.gd`: 0.28 s cooldown, no Gloom cost, AoE blast 1.8 m (2.3 m at rank I), Marks on
  every hit, and every 3rd bolt is a 2-damage Lash. The Lash also staggers windups
  (`enemy.gd` `take_hit`: `dmg >= 2.0 and winding`).
- `skill_lance.gd`: full charge 4 damage, 0.9 s charge plus a 1.4 s cooldown. That is a 2.3 s
  cycle, about 1.7 dps, and it costs 4 Gloom. A charge also blocks the bolt
  (`SkillBook` `HOLD_REPEAT` requires `_charging < 0`).

The player-facing problem: the "heavy" verb is worse at everything except piercing. The game's best
combat idea (Mark, then a heavy or Nova payoff) is optional, because the held bolt both marks and
stuns.

Fix:
- Lance full charge 6.5 damage (Perfect +30 % = 8.5), cooldown 1.0 s, Gloom cost 0 (or 2).
- Add **staff heat to the bolt.** After 2.0 s of continuous hold the interval goes 0.28 → 0.42 s,
  and it recovers 1 s after release. The orb dims as it heats, using the existing
  `set_charge_glow`.
- Rhythm (tap, tap, Lash, then Lance or Nova) becomes faster than holding. Combined with
  finding 7's boss chip, this gives the kit a skill ceiling.

### 10. Nothing outside the seal camps can keep up with a sprint, and sprinting is free

Evidence:
- `player.gd:7`: sprint 7.5 m/s with no stamina.
- The fastest regular is the mite at 4.4 (leapers 4.2 plus a 13 m pounce on a 2.8 s cooldown).
- `enemy.gd:26,31`: `chase_range` 11, `hunt_leash` 14.
- The Shade is 5.2.

The player-facing problem: every roaming fight is optional. Run the paths, and camps give up after
14 m. Only tide hunters (`hunt_leash` 999) follow. Combined with finding 2, there is no reason to
fight except the seals and ash.

Fix:
- Sprinting in the dark gathers Gloom 1.5x (`gloom_rate_dark * 1.5` while `_run_blend > 0.6` and
  not lit). That fits the fiction (you are making noise in the dark) and makes "fight or run" a
  cost.
- `hunt_leash` 14 → 20 m for wretches and leapers, so a pack chases you 2-3 s longer.
- Leapers get a "pursuit" pounce: `leap_cooldown` 2.8 → 1.6 while the player sprints away.

### 11. Dodge on a gamepad is context-dependent, and the slide gives no protection

Evidence:
- `input_setup.gd:41`: the dodge is V on keyboard only.
- On a pad, B rolls only "when slow (< 3.4 m/s) or locked and not sprinting"
  (`player.gd:1326-1330`); otherwise B slides, and the slide has no evade window.
- Rift Step is on Y (`input_setup.gd:24`), so the thumb has to leave the right stick.

The player-facing problem: on a pad, the escape button sometimes slides you into the pounce, with
no i-frames, depending on a speed threshold you cannot see. Pad players will lose the
"read the tell, dodge" contract that the whole enemy design relies on.

Fix:
- Give the slide's first 0.22 s the roll's evade: `_evade_t = 0.22`, `_evade_roll = true`, so no
  riposte. Pressing B is then always safe; the slide is the fast dodge and the roll the slow one.
- Default pad layout: Rift Step on RB (Nova to Y), so the dodge-like step is a shoulder button.

---

## Medium

### 12. Stronger players face a harder world (the progression rubber band)

`tiers.gd:50-55` `night_depth()`:
- +1 per boss slain (fine);
- +1 when the wanderer has 8+ upgrades (`tier >= 8`);
- +2 per NG+.

Upgrading makes every region harder, with enemy HP up to x3.0 and Gloom per blow up to x1.6
(`TIERS`). The player's survivability barely grows: +15 max Gloom per Hearth rank, up to +45.

Problem: spending ash raises enemy HP, so upgrades feel smaller and saving ash would be the better
play.

Fix: drop the progression term. Keep depth tied to bosses and NG+. If the late game needs teeth,
add enemy *behaviour* by depth (combo chance, feints), not HP.

### 13. A boss arrives already attacking

`BossArena._begin` (`boss_arena.gd:159+`) spawns the boss active, while the title card
(`zone_entered`) and the bar appear. The Thornwarden spawns 4.5 m off centre with the player about
9-10 m away, inside its 15 m pounce. Its first move can come before the title card fades.

Fix: an intro beat for every boss. On `_begin`:
- set `_ward_t = 1.8` and `RECOVER` with `_state_t = -1.8`, as `BossKit.transition` does;
- play `BossKit.roar` at 1.2 s;
- start attacks at 1.8 s.

Optionally lock the camera to the boss for 1.0 s on the title card.

### 14. The Ossuary lift breaks sequence and holds the Abbot fight open

Evidence:
- `ossuary.gd:22,705`: the ChainLift runs forever from the pit floor, 4.2 m from `PIT_C`, so
  inside the Abbot's arena, up to 26.56 m at the summit's mid tier, with a stair onto the summit.
- The arena reset checks only horizontal distance and `pd.y < -6` (`boss_arena.gd`), never
  height above.

Problems:
- (a) After the Abbot, the lift skips the summit ward, the Crossing and its seal camps (the
  climactic ascent). The arena's "requires" message then reads "Two seals still hold below."
  (hardcoded, `boss_arena.gd:136`) even when one boss is down.
- (b) Mid-fight, riding the lift up leaves the fight active with the player 22 m above it. The
  boss bar stays up, and the boss's 3D `_dist` > 18 stops its attacks: a stalemate.

Fix:
- The lift only runs once the Abbot is slain (deck parked at the top until then), or its top
  landing is behind the summit ward.
- `_reset` also when `pd.y > ceiling + 4`.
- Build the message from the count of missing bosses:
  `"Nothing answers. %s seal%s still hold%s below." % [["", "One", "Two"][n], "" if n == 1 else "s", "s" if n == 1 else ""]`.

### 15. The summit arena "closes" a gate 33 m away

`summit_dress.gd:125`: `arena.gate = ward`, the Crossing's ward. The fight resets at 20 m
(`radius + LEAVE`), so the ward never contains anything. Its reappearance re-blocks the way you
celebrated opening, and a player who walks back sees the seal up again.

Fix: `arena.gate = null`, or build a light veil across the dais junction (the gap in the
parapet) and use that.

### 16. Combat knowledge is never taught in play

`hud.gd:420-441` tips cover hang, slide, lock-on and Gloom only. The systems that make combat deep
have no tip:
- Marks and Nova detonation;
- the Lash rhythm (the 3-pip readout is the only hint);
- breaking a windup with a heavy hit;
- the Rift Step riposte;
- the Ossuant heap;
- Bulwark flanking;
- fireflies dimming near enemies.

`_tips_done` is per session, not saved.

Fix: state-triggered tips, saved in `Travel.story` flags:
- the first foe with 3 Marks: "Q: Umbral Nova detonates Marks";
- the first enemy windup within 6 m: "Hit the red with a Lash or a Lance to break it";
- the first evaded strike during a step: "RIPOSTE: your next bolt is a Lash";
- the first Ossuant heap: "Mark it, or strike the heap";
- the first Bulwark block: "Circle the shield".

Each fires once and is logged to the Journal as a "Lesson" page.

### 17. Phase lines and seal progress share one toast queue

`hud.gd:293-316`: one toast line, a 2.6 s hold and a 4-deep queue that drops extras. During a
boss these all compete:
- the phase line (`BossKit.roar` → `Events.toast`);
- "%s weakens -- n of m";
- "chain xN" goes to HitText, but kill and "it will rise" text do not;
- the first-hit lesson "They do not kill...".

Fix: the boss's phase line goes under the boss bar name (`BossArena._bar_name`, a second line)
for 3 s, not to the toast. Seal progress goes in the objective line (it already polls), not a
toast.

### 18. The Abbot's own "it will rise" is unreachable

`BoneAbbot extends Ossuant`, so at 0 HP with no Marks he heaps and reforms at 50 %
(`ossuant.gd:99`). Every bolt Marks (`MARK_LIFE` 5 s), so in practice he never rises. The Lance
does not Mark, but it is rarely the killing blow.

Problem: a thematic beat that could be the fight's climax ("finish the count") is dead code. The
boss bar would also jump from 0 back to 45 if it ever fired.

Fix: make it intentional and on-theme.
- At 0 HP the Abbot always heaps once, unless he carries **3 Marks**: "The count is finished."
- If he heaps, he reforms at 15 % with the Requiem at once, and the bar shows "IV".
- This turns the Mark system into the final verb of the fight.

### 19. The world's tells are never surfaced

Evidence:
- `life_director.gd:763-772`: fireflies dim to 15 % within 16 m of an enemy.
- `life_group.gd:66,115`: herds and birds react to enemies.
- Ambushes rise after 0.9 s (`director.gd:~455`) with no warning beyond the burst.

Problem: good reactive systems that do no gameplay work, because the player is never told that
quiet fireflies mean danger.

Fix:
- Crows or lapwings flush from the verge 2.5 s before an ambush triggers (`life_director.alarm`
  at the ambush spot when the player is 14 m from it), and the ambush rises at 6 m as now.
- One Journal writing ("Ostrin: when the fireflies go dark, so should you") plus a tip the first
  time a dimmed cluster is within 10 m.

### 20. The movement kit has no combat payoff

Slide, slide-hop (x1.08), wall kick, vault, ledge grab and beam are deep (`player.gd:1484-2130`),
but in combat only the roll and the step evade. Nothing rewards the jump-and-slide vocabulary in a
fight.

Fix (small and readable):
- A slide passes under leaper pounces and husk charges (the early-slide evade from finding 11).
- An aerial bolt fired at the apex of an air jump is a Lash for free (once per jump).
- A wall kick fired toward an enemy within 4 m gives a 0.3 s "drop" heavy for the next bolt.

Each one teaches itself through the existing HitText ("AERIAL").

### 21. Charms are mostly invisible percentages

`item_db.gd:30-73`: of 15 charms, about 10 are flat +5-15 % stat lines (Gloom gain, damage,
charge speed, ward +2 s). Only the Briar Antler, Ember Rosary and Ferryman's Hook change what you
*do*.

Fix: rework three of the flat ones into verbs, keeping their lore:
- Maud's Candle: your Lantern Ward follows you at walking pace.
- Lamp-Glass: the Ward pulses a 1.0 Nova ring when it ends.
- Clapper: every 10th bolt rings, staggering every foe within 5 m.

Cap the flat ones at one worn.

---

## Low

### 22. The riposte slow-mo changes `Engine.time_scale` globally

`player.gd:552-553`: 0.35 for 0.22 s. That slows the director, the tide timers, music logic and
every `create_timer` that does not ignore time scale, including boss zone timers. It is mostly
harmless. Still, ARCHITECTURE says to pause with `get_tree().paused`, and global time scale is the
same class of global switch. Use a per-actor slow instead: enemy `_hitstop` on the attacker plus
the camera kick, or at least clamp so nested calls cannot leave 0.35 stuck. A scene change during
the window keeps the timer, which is fine.

### 23. Roaming camps can be farmed

Rest (3 s in a fire after walking 25 m away) refills every roaming camp, at 1 ash a kill
(`ItemDB.ASH_PER_KILL`). A 3-pawn camp next to a fire yields 3 ash per ~30 s loop. `upgrade_db`
prices the whole tree at about 620. That is fine for a Souls-like, but say so. If not wanted, give
diminishing ash per slot per rest (1, 1, 0.5, 0...).

### 24. Seal progress is invisible on the seal

`ward_seal.gd:59-66`: a toast and a 4 % scale pulse. Show `n / m` on the seal itself (a ring of m
runes, one dimming per guardian) and on the Journal map, so the player knows which camps still
hold it.

### 25. First-session tips repeat every launch

`_tips_done` is per session (`hud.gd:443`). Save it in `user://settings.cfg` or `Travel.story`
flags.

### 26. The boss bar uses Roman phase numerals the player cannot map

`boss_arena.gd:108`: the bar shows "I/II/III" with notches, which is fine. Add the phase's verb
under it for 3 s ("judgement", "the Requiem") so the notches teach what is coming.

---

## Top 10 to do first

1. **Henge seal (Critical 1):** keep the new `_past_gate`. Move the thorn seal to the hedge gap,
   facing up the stair, and narrow the gap to about 0.2 rad. Split `trigger_radius` 10.5 from the
   leash at 12.4. Raise the hedge collision to 6 m. Add the `stair_pts` boss_test leg.
2. **Only fires rest (Critical 4):** zone kinds in `LightGrid`, and `is_fire()` for rest and
   tide-break.
3. **Bosses ignore the Ward; the Ward drains 4/s, capped at 25 (Critical 3).**
4. **The Shade is driven off by bolts, unmade only by light or Nova, and returns faster; hollowing
   drops your carried ash as a mound (Critical 2).**
5. **Resting at a lit fire sets the checkpoint (High 5).**
6. **Scope the rift Gloom rate to the rift and stop passive gain inside an active arena (High 6).**
7. **Boss HP 110/160/220, 0.7x from plain bolts, phase floors of two signature moves, and a summit
   fire at (0, 25.4, -78) (High 7).**
8. **Warden and Abbot danger colours out of the violet band; add a harden check (High 8).**
9. **Lance 6.5 damage, 1.0 s cooldown, no cost; bolt heat after 2 s of hold (High 9).**
10. **Pad dodge: the slide's first 0.22 s evades, and Rift Step moves to RB (High 11); boss intro
    grace of 1.8 s (Medium 13).**
