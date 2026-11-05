# Enemies, encounters and bosses: Enshrouded vs Umbral Reaches (r31)

This is a design comparison. It is not a copy. No Enshrouded enemy, name, faction or encounter is
used. We took their structural ideas and rebuilt them in our setting: the hollowed of the Gloom,
the Thornwood, the Barrows, the Stair.

Sources (read 2026-11-05):
- pindrop.gg enemy and boss data: [enemies](https://pindrop.gg/enshrouded/enemies),
  [Fell bosses](https://pindrop.gg/enshrouded/bosses/faction/fell)
- enshrouded.wiki.gg: [Fell Thunderbrute](https://enshrouded.wiki.gg/wiki/Fell_Thunderbrute),
  [Fell Critter Queen](https://enshrouded.wiki.gg/wiki/Fell_Critter_Queen)
- BisectHosting boss guide, Prima's Elixir Well walkthrough, and community combat guides
  (4netplayers, Sportskeeda)

## 1. What Enshrouded does

| Area | Enshrouded |
|---|---|
| Roster | 8 factions, about 400 templates. Each faction has its own damage resistances (Fell weak to fire, and so on). Every faction covers the same roles: melee soldiers, shield-bearers, archers and marksmen, casters and summoners, heavies, swarms (critters, bats, spiders). |
| Scaling | Each faction has a level band (Fell 1-53, Scavengers 1-46). The band rises by region, so the same archetype reappears tougher further out. |
| Stagger | Hits, and especially parries, fill a stun meter. A stunned enemy is open, and burst damage goes into that window. |
| Weak spots | Headshots with bows or wands. Some bosses have a stun point exposed only during one move: you shoot the Wispwyvern's mouth during its roar or summon stance. |
| Camps | Scavenger and Vukah camps mix melee, ranged and a caster. A leader (a Matron, a Brawler) stands with an escort, and guides say to clear the escort first. |
| Points of interest | Elixir Wells and Shroud Roots are held by named minibosses (the Thunderbrute and the Critter Queen), often repeated across regions, sometimes in pairs. The Critter Queen keeps spawning critters. |
| Bosses | They have a big-telegraph melee or charge, summons, a ranged phase, and a defensive "curl up" low on health. Each boss has its own arena. |

## 2. Where we stood (r30)

We already had most of the systemic layer:
- Every move telegraphs on the ground ("no red, no hit").
- Attack tokens (two attackers at once, the rest circle).
- Flankers work to your side, guards stand between you and casters, and supports kite behind a
  guard.
- Packs call each other, the badly hurt flee once, and enemies are provoked by a hit.
- Walls are followed round instead of walked into.
- Regional tiers and variants, named elites with bounties, tides, ambushes.
- Three bosses with phase floors (a signature move seen twice) and an intro grace.

What was missing compared with Enshrouded:
- **Readable stagger.** Poise existed, but it was invisible, and a stagger gave no damage reward.
- **Weak points.** The only "hit here" was the Bulwark's open flank.
- **Pack morale and alerting.** Packs called each other once, but nothing raised a whole area,
  and a pack never fell back to regroup.
- **Archetype gaps.** We had no marksman (spitters lob slow orbs), no hit-and-run skirmisher, and
  no alarm-raiser.
- **Minibosses at places.** Elites roam haunts with bounties, but no point of interest had a
  guardian.
- **Scaling.** The night deepened as the wanderer upgraded (r30 critique 12), so spending ash
  made enemies tougher.
- **Boss mastery.** None of the three bosses had a move-specific stun point.

## 3. Took, adapted, skipped

### Took and adapted

**Visible poise meter and the BROKEN window** (`core/enemy/enemy.gd`, `health_bar.gdshader`)
- A gold strip along the underside of each health bar fills as poise damage builds toward a
  stagger. It drains with the poise window.
- A stagger leaves the enemy **broken** for about 1.6 s. The bar's frame burns gold, a "broken"
  pop appears, and every blow does x1.3 damage.
- Bosses are only broken by their weak point (2.6 s, x1.2), never by plain poise, so the r30 chip
  and floor rules hold exactly.

**Weak points** (`enemy.gd`: `weak_socket`, `weak_offset`, `weak_r`, `weak_open`, `_on_weak_hit`)
- A glowing ember-gold knot rides on a rig socket.
- A projectile that bursts on it, or within 0.45 m of it, deals x1.6 damage and twice the poise.
  On an ordinary foe, it also breaks any tell in progress.
- The Lash and the Step do not count; this is Enshrouded's headshot.
- Which kinds have one:
  - Husk family (Husk, Bulwark, Ossuant): a knot between the shoulder blades, so circle the
    guard. This combines with the Bulwark's shield.
  - Spitter: its sac.
  - Chanter: the corpse-light at its staff's head.
  - Quiller: its skull.
  - Tollman: its bell.
  - Brood-Mother: her sac.

**Pack morale: retreat and regroup** (`enemy.gd`: `_tell_fallen`, `_ally_fell`, `_regroup_move`)
- When two packmates fall within 14 m in a few seconds, the survivors pull back to the pack's
  middle on the far side from you.
- One of them howls ("they regroup"). They hold for 2.4 s facing you, then come again rallied.
- This happens once per life. Tide hunters, elites, guardians and swarms do not regroup.

**Alerting** (`Enemy.toll(tree, at, r, by)` and the new **Tollman**)
- This adapts camp alarms: a bell-ringer can raise everything in earshot, including camps out of
  sight.
- Those who answer hunt for 14 s past their usual leash (`_hunt_t`).

**New kinds**, all on existing rigs and the modelled grunt GLBs, each with its own tint:

| Kind | File | Role | How it plays |
|---|---|---|---|
| **Gaunt** | `core/enemy/gaunt.gd` (Wretch body, drawn long and pale) | hit-and-run skirmisher | It never queues in the attack ring. It stalks at 7 m toward your off-side (away from the camera's forward). Then it **darts**: a red lane fills through you (0.55 s) and it runs the lane at 11.5 m/s and out the far side. It is winded where it stops (the punish window). It has its own turn pool, so it does not take a melee token from a Husk. |
| **Quiller** | `core/enemy/quiller.gd` (Ossuant body, cold rim) | marksman | It kites at 9-14 m behind its packmates. A long narrow red lane fills from its feet past you (0.85 s), then the shard flies the whole lane at once. A blow on the draw spoils it. It springs back 5.5 m when you close inside 4 m. With no line on you, it strafes for one; it never lobs, so cover works. |
| **Tollman** | `core/enemy/tollman.gd` (Chanter body, ember-gold, an iron hand-bell) | alarm-raiser | When it sees you, it runs toward its pack and rings: three tolls over 2.4 s, with gold rings on the ground and no red. If it finishes, everything within 34 m comes. A hit spoils the toll and staggers it. Up close it clangs (a small red disc). |
| **Brood-Mother** | `core/enemy/brood_mother.gd` (Spitter body at 1.7x) | swarm-spawner guardian | She lobs acid in pairs, and sprays a fan of 3 orbs (5 when enraged) when you close. Every 10 s (7 s enraged) she squats and her sac swells for 1.6 s, then three mites burst out (at most six alive). A burst on the sac while it swells **ruptures the brood**: no mites, and she is broken. She enrages at half health. |

**Guardians at points of interest** (`core/life/encounters/guardians.gd`)
- This is the Elixir Well / Shroud Root idea in our terms: a named, bigger guardian with an
  escort holds a place.
- **API for the world agent:**
  - Put any Node3D in group `&"guardian_site"` (`Guardians.GROUP`). Optional metas:
    - `"guardian"`: an id, `brood_mother`, `tithe_knight`, `sexton` or `pale_stalker`. If unset,
      one is picked by the site's region.
    - `"site_key"`: a stable save key.
  - Or call `Guardians.add_site(at, id, key)`.
  - Sites are re-read every director tick.
  - Four fallback sites hold until the world names its own. A fallback is skipped when another
    site is within 45 m.
- Guardians:
  - The Brood-Mother (her own kind).
  - The Tithe-Knight: a Bulwark at 1.45x. Its escort is a Chanter, a Wretch and a **Tollman**.
  - The Sexton of the Barrows: an Ossuant at 1.4x, escorted by two Quillers.
  - The Pale Stalker: a Gaunt at 1.35x, escorted by two Gaunts.
- Behaviour:
  - A guardian rises within 55 m and goes back to its site, healed, past 95 m.
  - It shows on the elite name bar.
  - At half health it **enrages**: a roar, two of its kin called, faster, with chains and
    feints. Telegraphs are never shortened.
  - When it falls, it pays 14-16 grave ash (doubled in the Deeper Night) with a "GUARDIAN FELLED"
    banner.
  - It stays down until the Deeper Night (saved as `encounters.slain["g:<key>"]`).
- Guardians respect fires but not the wanderer's Lantern Ward, like elites.

**Region scaling** (`core/life/encounters/tiers.gd`)
- This fixes r30 critique 12. `night_depth()` is now only bosses felled plus 2 per Deeper Night;
  the wanderer's upgrades no longer harden the world.
- New `Tiers.behave(e, tier)`: past tier 1, each tier adds chain chance (+0.06, cap 0.6; flankers
  and combo kinds) and feint chance (+0.04, cap 0.35). Telegraph times never change.
- Regional mixed-pack pools now draw the new kinds. For example, Quillers in the fen, barrows,
  summit and ossuary; Gaunts on the road, Thornwood, henge and crags; Tollmen at the chapel and
  rift.
- Six roaming camps carry them (`enemy_spawner.gd`). The Thornwood war band now rides with a
  Tollman and a Gaunt. Seal camps are unchanged.

**Deeper boss phases.** The r30 phase floors, intro grace, models, lights and upright crozier are
untouched. Each boss gained a move-specific stun point and new moves:

| Boss | New | Counter |
|---|---|---|
| Thornwarden | **Heart-knot**: it opens at its breast for the lanes' windup. A burst there tears the volley out of the ground and it is broken. **Bramble lash** (both phases): stand in its blind half or under it for 1 s and a thorn ring fills round its body. **Snare** (phase II, every 11 s): a ring of thorn discs round *you*, open only toward it, then it pounces into the middle. | Shoot the knot. Don't farm its back. Leave the snare through the gap, under the leap, or Rift Step out. |
| Bone Abbot | **Tithe** (phase II, every 7.5 s at range): a line of bone discs walks out from it to where you stand. **Reliquary** (phase III): it burns open for each Requiem. Two bursts on it break the song: the unrisen rings fade and it is broken. The Requiem still counts toward the floor. | Step off the line sideways. Shoot the reliquary during the Requiem. |
| Ascended Warden | **Halo**: it opens while its hands are up for a fan. A burst there scatters the volley; the cone fades and no orbs fly. **Eclipse** (phase III, every 12 s): the whole dais fills dark-gold for 2.6 s, except two pillars of its light at the blink points furthest from it (`BossKit.zone` "holes"). | Shoot the halo. Stand in its light. |

### Skipped (and why)

- **Elemental resistances per faction.** Our damage model has no damage types to resist yet (the
  bolt cores are afflictions, not types). Weak points carry the "hit it right" lesson instead.
  Revisit when the COMBAT agent adds damage types.
- **Parry-driven stun meter.** The parry belongs to player.gd (COMBAT agent). The visible meter
  fills from any poise damage. A riposte already staggers, so it now also opens the broken
  window.
- **Level numbers and level bands.** We keep named tiers, which suit a night that deepens. HP
  scaling stays as it was; behaviour now scales too.
- **Respawning minibosses.** Guardians stay down per cycle (our camps refill at a rest, but a
  felled guardian is a landmark cleared).
- **A navmesh.** Wall-following (r30) and the new strafe-for-line and dart lanes have covered
  every test layout so far. A navmesh over the streamed Realm is a world-agent-scale job.
- **New Blender models.** Every new kind reuses a modelled grunt GLB (Wretch, Ossuant, Chanter,
  Spitter) with its own material tint, posture, scale and parts (bell, sac light). That is the
  same quality as the r30 bodies and costs no new asset pipeline.

## 4. Tests and shots

- `zz/enemies_r31_test` (49 checks) covers:
  - weak-point and broken multipliers, and the bar's poise and broken uniforms;
  - regroup;
  - Gaunt dart and token pool; Quiller lane hit and spring-back; Tollman toll waking a far camp,
    and the spoiled toll; Brood-Mother brood, rupture, hatch and enrage;
  - guardians: group site, API site, spawn, escort, enrage, name bar, payment, banner, staying
    down;
  - the boss moves and their weak points; eclipse holes;
  - depth independent of upgrades; depth buying behaviour, not shorter tells.
- These still pass: `enemy_ai_test`, `encounters_test`, `boss_test`, `r30_design_test`.
- Studio: `zz/combat_studio.tscn -- --only=gaunt,quiller,tollman,brood_mother`.
- In-game sets in `zz/combat_shots.tscn`: `--set=r31` (gaunt, quiller, tollman, husk pack) and
  `--set=brood`.

## 5. Left for later

- Point real points of interest at `guardian_site` (WORLD agent) and retire the fallbacks.
- Damage types and faction resistances, once the combat side has types.
- An Enshrouded-style "defensive curl" low-HP beat for guardians (a shell that a heavy hit
  cracks).
- A shield-bearer that *moves* to body-block the wanderer's bolts for a caster, beyond standing
  on the line. This needs a projectile-intercept check in magic_bolt.gd (COMBAT agent).
