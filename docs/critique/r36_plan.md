# r36: depth, story, a living world (plan)

Luke's request (5 Nov 2026): make the world more alive and dynamic, deepen the story to hours of
content, improve the quests, add variability (spells, equipment), add depth at no performance cost,
critique and harden as we go, and fix what needs fixing.

## Decisions (Luke, 5 Nov 2026)

- **Story:** three acts. Act I as now (two seals, Thornwarden, Bone Abbot). Act II: the summit
  ward wakes but the door hears no bell; the Founder's seven bells are scattered across the seven
  r34 regions, one each, each a short story with a keeper, a choice and a mini-boss. Act III: the
  Warden, then a valley changed by what was done for the Deeper Night.
- **Variability:** all four. Spell variants found in the world (play changes, not numbers), gear
  that changes play, random affixes on drops, and new spells taught by the story.
- **Living world:** outposts where NPCs fight enemies with swords; a horse, with different kinds
  from different places; grindy to an extent; roaming world events; the night progresses; NPC
  routines; faction reactions.
- **How:** one area at a time in this session, each finished, tested and reported before the
  next, so the work can stop cleanly at any step.

## Order

1. **Act II spine: the Founder's seven bells.** Ties the r34 regions into the main story (the
   r35 critique's "the story didn't grow with the world").
2. **Spell variants and new spells.**
3. **Gear that changes play, plus rolled affixes** (affixes kept few and legible: the r35 critique
   called the gear panel stat soup).
4. **Outposts and roaming world events** (pooled, capped, asleep when far: no cost at rest).
5. **Horses**, a kind per place.
6. **The night progresses, NPC routines, faction reactions.**
7. **The grind loop and a hardening sweep** (repeatables, bounties, rares; code-health and
   text-collision fixes from r35).

Every step: tests in `zz/`, the full suite, a perf A/B where it touches the frame, and a short
report. Commits only when Luke says.

## Rules for the content

- House style (docs/LORE.md): terse, concrete, dark. Reuse names already in the cast before adding
  new ones (r35 critique: proper-noun density).
- Depth before breadth: extend the existing systems (QuestDB kinds, relic variants, GearDB,
  village state) rather than add parallel ones.
- No per-frame cost for anything far away: events and outposts sleep with the camps' sleep range.

## Implemented: step 1, Act II (the Founder's peal)

- **The spine.** Once both Act I bosses are down, Brannoc offers *The Founder's Peal*: his mother
  cast seven bells for the road up, and the summit door was hung to a bell. The summit ward and the
  Warden's arena now need **four of the seven** as well as heart and crown
  (`WardSeal.requires_bells`, `BossArena.requires_bells`, `BossArena.no_peal`). The keep sends
  you to Brannoc. *The Ward on the Crossing* (Act III) is offered once the peal is handed in.
- **Seven bell quests**, one per far country, from that country's own giver, each after its
  region's chain (`bell_holds` … `bell_mere` in `quest_chains.gd`, `BELLS`, `BELLS_NEEDED`):
  1. Put down the bell's **keeper**, a new named rare that haunts it (seven in `rares.gd`,
     `BELL_KEEPERS`).
  2. **At the bell, choose** (a conversation opened by the bell itself, `dialogue_db.gd`):
     **ring it here** for that country, or **lift the tongue out for Hearthward**.
  3. Tell the giver: their outcome line follows the choice.
- **What the choice does.** Each carried tongue rings at the Keg as the Warden wakes: he starts
  5% down per tongue (35% for all seven) and the fight opens on "Far below, Hearthward rings four
  bells." A rung bell stays with its country; in step 6 (the night progresses) rung bells will
  quiet their regions.
- **The ending remembers.** A new line in the keep's last conversation (`end_4c`) speaks to all
  seven, to the moor and mere bells rung, or to the Passing Bell.
- **The bell itself.** A bell on a timber frame (`quest_props.gd` "bell"), with its own map pin.
- **Tests.** New `zz/act2_test` (data, counting, the ward and arena gates, the Crossing's
  availability, the Warden's share). `quests_r34_test` plays every bell (ring it), and
  `boss_test` and `raids_r34_test` answer four bells before the summit. Renders: `zz/bells_shots`.
- **Cost.** Data and one conversation per bell. The seven keepers are rares, so they sleep beyond
  95 m like the others. No per-frame work.

## Implemented: step 2, spell variants and a new spell

- **Every spell now has a play-changing pair.** Before, only Rift Bolt (Thorn Heart) and Umbral
  Nova (Bone Reliquary) had variants. Each of the seven bell keepers now drops a relic that changes
  one more spell. A relic arrives attuned to its first variant; switch at a kindled fire, as before
  (`Reliquary.VARIANTS`, `TEXT`, `SPELL_OF`, `Reliquary.variant`; the hook is in `Travel.give`).

  | Relic (keeper) | Spell | Variants |
  |---|---|---|
  | Kin-Caller's Lamp | Lantern Ward | **Hearth**: mends 2 Wounds/s in its light, burns 2 s shorter · **Cinder**: its edge burns foes that cross it |
  | Slag Heart | Ember Lance | **Scatter**: a fan of three at half strength · **Brand**: the burst Marks twice, 15% softer |
  | Fog-Shepherd's Crook | Rift Step | **Harrow**: Marks round the arrival, recovers 30% faster · **Mist**: the start fogs over and slows |
  | Unpaid Fare | Rift Tether | **Anchor**: pins the foe 2.5 s, two Marks · **Haul**: drags you to it, landing with a shock |
  | Ash Seed | Umbral Well | **Bloom**: pushes foes out and slows harder · **Wander**: drifts after the nearest foe |
  | The Passing Rope | Bound Shade | **Swarm**: three weaker shades · **Vigil**: one keeps watch where it was bound, longer and faster |
  | The Last Mark | Founder's Peal | **Toll**: one narrow stroke, double damage and stagger · **Carillon**: three rings all round |

- **A new spell: the Founder's Peal** (`core/skills/skill_peal.gd`). Brannoc teaches it when *The
  Founder's Peal* is handed in (the quest reward's `spell`, `Kindling.gift`). It is a cone of sound:
  a blow, a Mark and a stagger, and it knocks spit out of the air. Three ranks: Wide Stroke,
  Resonance, Great Bell. It has its own hotbar glyph. After the gift the Kindling also teaches it
  (`learn.story`).
- **Tests.** A `variants` section in `zz/skill_test`: every variant is cast against live foes and its
  effect checked, the relic attunes on pickup, and the Peal's gift, cone, Toll and Carillon are
  covered. Cinder Ward is not checked behaviourally.
- **Cost.** All cast-time work. The mist, ward rite and well wander tick only while their spell
  stands (seconds), over the enemy group, like the existing ward aura.

## Implemented: steps 3 to 7, and Act III

- **Gear (step 3).** Hallowed pieces (half the time) and better (always) roll a **trait**, a line
  that changes how you play (`GearDB.TRAITS`). Most switch on behaviours the spells already have.
  Three are new:
  - **kill_spark**: a kill takes 1 s off every spell's recovery, one time in four.
  - **ash_hunger**: kills give more ash.
  - **peal_echo**: the Peal rings twice.

  New affixes for the Shade, Tether, Peal and ash finding.
- **The Kindled Watch and roaming events (step 4).** Four watch-posts (`core/world/watch`), three
  watchmen each, with swords (villager rigs; chop and kneel). Hollowed assault a post while you are
  near (`Enemy.focus`). A post that holds pays ash, and every third hold its quartermaster gives
  gear. A post whose watchmen all go down falls for a while. Roaming events
  (`core/world/roam`), one at a time, each with a map pin:
  - a procession on the road
  - an incursion on a lit brazier
  - a rift tear
  - a living pilgrim to bring home
- **Horses (step 5).** Four breeds, each kept in its own place and bought with grave ash at its rail
  (`core/world/mount`):
  - a palfrey at Hearthward
  - a moor garron at Ysolt's
  - a fen pony on the mere
  - a pit draught at the Founder's Pits

  Each is built on the deer's GPU-animated rig. You ride by walk, trot or gallop with a seated pose;
  jump or [E] gets you down, and [H] calls your horse.
- **The night progresses (step 6)** (`core/world/night/reach_state.gd`):
  - **Acts:** the act sets the pressure, which moves roaming-event timing and assault size.
  - **Rung bells:** a rung bell quiets its country (camps return 3x slower) and stands lit.
  - **Factions:** three factions (the Rooted, the Kindlers, the road folk) give a gift at Friend.
    At Kin, their camps return more slowly and their watchmen stand longer.
  - **Reactive givers:** the seven region givers react to what was done with their bell.
- **The grind and hardening (step 7).** The keep's daily bounties: the Keg's tab, a named rare's
  head, and the bell keepers who come back. F8/F9 now work only in the editor or with `--dev`.
  Horses have rider safety.
- **Act III: the door.** After the Warden, Brannoc says *shut is not latched*:
  1. **Shut Is Not Latched:** at the dais you latch the door, leave it on the latch, or break the
     latch.
  2. **Those Still Climbing:** Agathe asks you to put down the ones who came down with their hands
     out.
  3. **Names Under the Door:** a name from each of four far fires, cut into the dais stone.
  4. **The Full Peal:** all seven bells, for Brannoc.

  An epilogue with the keep ends on one of three title cards, by the latch choice. Act 5's valley
  follows the latch: latched presses less, broken is only night, and on the latch the ones above
  come home (more pilgrims on the roads).
- **Not done.** The Keg patrons still never stand up. The Deeper Night does not yet carry the latch
  choice.
