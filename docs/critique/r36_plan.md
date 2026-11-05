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
