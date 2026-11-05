# Combat, movement and mechanics: Enshrouded vs Umbral Reaches (r31)

This pass compares the moment-to-moment feel with Enshrouded and borrows ideas, not content.
Names, numbers, art and UI are ours. Code: `core/player/stamina.gd`, `core/player/staff_arts.gd`,
`core/player/grapple.gd`, `core/player/grapple_anchor.gd`, `ui/breath_meter.gd`, plus hooks in
`core/player/player.gd`, `core/player/character_rig.gd` (poses) and `core/skills/skill_book.gd`.
Test: `zz/combat_r31_test.tscn`.

## What Enshrouded does (research summary)

- **One stamina bar for everything physical.** Sprint, dodge roll, melee swings, blocking, the
  glider and the grappling hook all draw on it. A dodge roll costs a lot. Holding block drains
  stamina and stops its recovery.
- **Block and parry.** Blocking works with or without a shield and costs stamina. A well-timed
  block is a **parry**: it costs no stamina, interrupts the attack and fills the enemy's stun bar.
  Parry power varies by weapon (shields are best, two-handers worst). A stunned enemy is open to a
  heavy punish.
- **Hybrid builds.** Melee light chains and charged heavies, bows (with headshot "skill shots"),
  and staves that spend mana. The skill tree reshapes the kit: dodge and stamina perks, glider
  efficiency, an Updraft spell, and Double Jump (moved to the centre of the tree in a later
  update so any build can take it).
- **Traversal.** A glider spends stamina; run out and you drop, and fall damage is real. A
  grappling hook bites glowing grapple points (40 stamina; an upgrade costs less and reaches
  further). Updrafts lift a glide.
- **Target lock and hit feedback.** Lock-on, stagger and stun bars, knockback, hit pauses.

Sources: [Deltia's combat tips](https://deltiasgaming.com/?p=106929),
[Sportskeeda: combat mechanics](https://www.sportskeeda.com/esports/enshrouded-combat-mechanics-how-attack-and-defend),
[GamesFuze: parrying](https://gamesfuze.com/guides/how-to-parry-attacks-effectively-in-enshrouded/),
[GameWatcher combat deep dive](https://www.gamewatcher.com/enshrouded-combat-deep-dive),
[TechRaptor: glider](https://techraptor.net/gaming/guides/how-to-get-glider-in-enshrouded),
[xGamingServer: grappling hook](https://xgamingserver.com/blog/enshrouded-grappling-hook-glider-guide/),
[Hack the Minotaur: skill trees](https://hacktheminotaur.com/enshrouded/all-enshrouded-skill-trees/),
[pindrop: Updraft](https://pindrop.gg/enshrouded/skill-tree/skill/updraft),
[games.gg: best skills](https://games.gg/enshrouded/guides/enshrouded-best-skills-guide/).
The sources disagree on some details (the Updraft tree, glider fall-damage immunity), so these
are taken as the general shape, not exact rules.

## Where we stood before r31

- Magic-first: Rift Bolt (held repeat with r30 heat), Ember Lance (charge), Nova, Ward, Rift
  Step, and the learned spells. There was no melee.
- **Close range was bad.** Aim assist was a 6-degree cone that ignored anything within 1.5 m. Over
  the right shoulder, a foe in your face sits tens of degrees off the staff's line, so bolts went
  past it. Lock-on swung the camera but bolts still flew down the crosshair.
- Deep traversal (mantle, ledge grab, vault, wall kick, slide, double jump, roll with i-frames,
  Rift Step), but no glide or grapple, and no cost to any of it. Falls cost nothing.
- Riposte only from a Rift Step through a blow. A plain roll said "evaded" and nothing more.
- Good hit feedback on the enemy side (hitstop tiers, flinch, knockback, poise stagger), but none
  on the player's side.

## What we built

### Breath (stamina): `core/player/stamina.gd`
Gloom stays the "health" (how far the dark has got in). **Breath** is the body's wind.
- 100 Breath. It recovers at 34/s after a 0.55 s pause, and not at all while you hold a guard or
  glide.
- Costs: roll 22, back-hop 14, air jump 8, wall kick 8 (always allowed), staff strike 9,
  finisher 12, heavy 26, guarded blows 2 per Gloom turned, glide 8/s, Tether line 24.
- A move needs half its cost to start, so a last roll is never refused for a sliver. Run dry and
  you are **winded** until 40: no sprint, no roll, the glide folds.
- **Adapted:** sprinting costs Breath only with a foe awake within 18 m (a "hunted run"). Our
  Realm is crossed at a sprint and Gloom already taxes sprinting in the dark, so a travel tax
  would only slow exploring down.
- Gear hook: `breath_max` and `regen_scale` are plain fields for the equipment pass.
- HUD: `ui/breath_meter.gd` draws a thin arc left of the crosshair, only while Breath is not full.
  It flashes red on a refused move and gold on a perfect dodge or parry. A heavy's draw shows as
  an inner ember arc.

### Staff arts (melee): `core/player/staff_arts.gd`
This fixes "close-range targeting is terrible" at the root: up close you should not need to aim.
- **Contextual primary.** Hold the Rift Bolt trigger (LMB / RT) with a foe within 2.7 m in front
  (or the lock target within 3.5 m), and the staff strikes instead of a bolt. Step back and bolts
  resume. No new button is needed to play hybrid.
- **Light chain:** sweep (1.2), backhand (1.2), then an overhead finisher (2.3, wider arc). Each
  strike lunges you up to 1.7 m toward the target and squares you to it. Presses are buffered
  0.32 s. Every strike leaves an Umbral Mark, so melee feeds Nova like bolts do.
  - **RIFT CUDGEL** (new combo): the finisher takes a foe's Marks for +0.7 each. Bolt at range,
    close in, and finish.
- **Heavy:** hold the staff key (G / mouse 4) to draw it back overhead, then release. It hits
  3 to 6.5 in a 2.1 to 3 m ring. A full draw staggers anything that is not a boss.
- **Guard / parry:** hold guard (X / mouse 5; pad: B while locked on with the stick idle).
  - The first 0.2 s **parries**: free (+18 Breath), the attacker reels (`riposted`) and takes a
    Mark, and the next strike or bolt is a riposte. A strike riposte hits x2.5 and staggers.
  - After that the guard **blocks** blows from the front: a quarter of the Gloom gets through and
    the rest costs Breath. Run dry and the **guard breaks** (0.9 s, the full blow lands).
  - A re-press within 0.55 s has no parry window, so mashing does not work.
  - **Taken from Enshrouded:** free parry, blocking costs stamina and stops recovery.
  - **Adapted:** the parry plugs into our existing riposte rather than a stun bar. Enemy poise and
    stagger are the enemies agent's, and a parry calls `riposted()`.
- **Hitstop on the player's side:** `Player.hitstop()` holds the world at 5 % for 45 ms (light),
  75 ms (finisher) or 110 ms (heavy). Perfect dodges and parries get longer, gentler slow motion.
  It never stacks on someone else's slow motion and always gives the time back.
- New rig poses (`CharacterRig.cast_pose`): `strike_a`, `strike_b`, `strike_c`, `heavy`, `parry`,
  plus held blends `guard` and `wind`. These are new motion on the existing rig, not a new model.

### Dodge: perfect dodge
A dodge roll that a blow meets in its first 0.2 s is a **PERFECT DODGE**: 0.2 s of slow motion,
+18 Breath, the attacker is Marked, and a riposte is armed. Later in the roll it is a plain
evade, as before. Rift Step keeps its own riposte.

### Aim at close range and on lock: `player.gd`
- **Locked on:** bolts and the Lance go straight at the target's chest when it is in sight (up to
  40 m), whatever the camera is doing.
- **Not locked:** the assist cone widens with nearness: about 35 degrees at 1 m, narrowing to the
  old 6 degrees by 9 m. It also counts a short foe under the crosshair by flat bearing. Each foe
  is judged by its margin inside its own cone, so a near foe off-centre does not steal the shot
  from a far one on the crosshair.

### Cloak-glide (our glider): `player.gd`
- In the air, with the air jump spent, press jump again to spread the robe. You sink at 2.3 m/s,
  carry about 9 m/s and steer with the stick at 2.6 rad/s. It spends Breath.
  - Jump folds the robe; slide dives out of it; landing, a ledge or running out of Breath ends it.
- **Updrafts:** any node in the `updraft` group (meta `radius`, `height`, `lift`) lifts a glide.
  So does every **lit fire**: the brazier's heat rises.
- Rig blend `glide`: arms flung wide to spread the robe, staff along the arm, body pitched into
  the wind.
- **Adapted:** no separate glider item. The wanderer's robe is the sail, which keeps the
  silhouette rule.

### Fall Gloom: `player.gd`
Landing harder than 16 m/s (about a 6 m drop) jars Gloom in: 2.6 per m/s over, at most 30.
Rolling the landing halves it, and a glide never jars. **Adapted:** a fall never pushes Gloom to
the cap by itself, so a fall is not a death.

### Tether line (our grapple): `core/player/grapple.gd`, `core/player/grapple_anchor.gd`
- The anchor nearest the crosshair (within about 20 degrees and 24 m, in sight) gets a violet
  ring. Interact (E / pad X) bites it when there is nothing else to use. The staff casts a line
  of rift-light and hauls you at up to 21 m/s.
- You arrive just under and in front of the anchor and pop up 6.2 m/s. The air jump is refreshed,
  so the chain anchor, jump, glide works. It costs 24 Breath.
- **API for the world:** any Node3D in the `grapple_anchor` group is an anchor. Optional metas:
  `reach` and `land` (a local offset for where the haul ends). `GrappleAnchor.make(parent, pos)`
  places a dressed rift-iron ring with a faint light; set `bare = true` before adding it to dress
  it yourself.

## What we skipped, and why

- **Separate mana pool.** Gloom is our spell cost, and r30's heat already gates the held bolt.
  A third bar would blur the meaning of both.
- **Stun bar UI.** Enemy poise and stagger live in `enemy.gd` (the enemies agent). We reuse
  `stagger()` and `riposted()` instead of drawing a second meter over every foe.
- **Bows, ammo and weapon classes.** The wanderer's identity is the staff (umbral-donts). The
  staff is both focus and cudgel.
- **Free-climb anywhere with stamina.** Our mantle, ledge grab and wall kick are authored to the
  baked architecture. Free climbing would break the Stair's routes.
- **Skill-tree rewiring.** Breath fields and the Combo hook (`RIFT CUDGEL`, `RIPOSTE STRIKE`) are
  where the progression agent can attach perks: cheaper rolls, a longer parry window, glide
  efficiency, and so on.

## Controls (new)

| Action | Keyboard / mouse | Pad |
| --- | --- | --- |
| Staff strike (contextual) | LMB with a foe close | RT with a foe close |
| Staff strike / hold: heavy | G, mouse 4 | (RT up close) |
| Guard (tap timing = parry) | X, mouse 5 | B held while locked on, stick idle |
| Glide | Jump in the air after the air jump | A |
| Tether line | E at a marked anchor | X |

## Tests

`zz/combat_r31_test.tscn` covers:
- Breath: roll cost, recovery, refusal, winded, the hunted sprint;
- the contextual claim, the chain, its lunge, Marks, the heavy and its stagger;
- the point-blank and locked-on bolt aim;
- parry, block, block from behind, riposte strike, guard break;
- perfect vs late dodge;
- glide: sink, carry, Breath, updraft, a clean landing;
- fall Gloom and its cap;
- the Tether line: mark, bite, haul, pop;
- time scale restored.
