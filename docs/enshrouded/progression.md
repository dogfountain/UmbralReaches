# Progression, economy, Hearthward and the rest loop: Enshrouded vs Umbral Reaches

We used Enshrouded as a reference for depth, not as content. None of its names, NPCs, places or
items are used. Everything below is written in our own setting: Hearthward, the Kindlers, grave
ash, the Gloom, and the wanderer the door half-took (docs/LORE.md, docs/STORY.md, the r30
storyteller's canon).

## What Enshrouded does (research summary)

- **Levels and a skill tree.** XP comes from almost everything: combat, exploring, crafting and
  quests. Each level gives a skill point, and so do the world's big objectives. The tree has three
  colour-coded archetype regions plus a core. It is a wide constellation where neighbouring nodes
  unlock each other, and the capstones sit deep in each region. You can respec at the base altar.
- **The Flame Altar.** The base's heart. Upgrading the Flame with rare materials raises the
  shroud timer (how long you survive in the hostile fog) and the number of altars you can place.
  It also gates progress into deeper shroud.
- **Survivors and their stations.** Rescued craftspeople live at your base. Each one opens a
  crafting station and recipes (smith, hunter, alchemist, farmer, carpenter), so the base gets
  more useful as you rescue more of them.
- **Survival buffs, not needs.** Food takes slots, by default up to three dishes at once, one per
  food type, and a skill adds a fourth. Each dish is a timed stat buff. Resting near the base's
  fire with shelter, warmth and comfort gives **Rested**: a long timed stamina buff whose length
  grows with the base's comfort score (furniture quality and variety).
- **Risk and reward.** The shroud timer pushes you back out of the fog. The best materials and
  the skill-point objectives live inside it.

## What we took, adapted and skipped

| Enshrouded | Umbral Reaches (this pass) | Status |
|---|---|---|
| XP from everything -> levels -> skill points | **Memory** from deeds (kill 3, kindle a fire 40, break a seal 50, a keeper 150, settle a task 60, a keepsake 25, a homecoming in Hearthward 30) fills **Remembrances**. Each Remembrance, and each of the three keepers put down, is one point. In the story, walking the valley gives the wanderer back what the door took. | Adapted |
| Three-colour constellation tree, respec at the altar | **The Paths** (Kindling, PATHS tab): three columns, each a read-down chain of 8 steps. **The Hearth** (survival at fires, meals, rest), **The Rift** (spell power, recovery, Marks, Lash), **The Road** (speed, the Step, ash-gleaning). Steps cost 1-3 points, 39 in all against roughly 18-20 earned in a full run, so builds differ. **Unremember** at Hearthward's fire costs ash. | Adapted (chains, not a mesh: it reads clearer) |
| Flame Altar tiers: shroud time, altar count | **The Hearthfire**, the green's brazier, has 5 tiers (Banked, Drawing, Roaring, Blazing, Beacon). Each tier is raised **only at Hearthward's fire** with grave ash and relic fragments, gated on valley fires kindled and keepers down. Every tier gives **+Gloom held** (our shroud timer) and **light reach**: every kindled fire's sanctuary radius grows (+1/+2/+3/+4.5 m), and so does the light's visible range. | Adapted |
| Survivors open crafting stations | The Hearthfire **opens Hearthward's trades** using our existing villagers and their stories: **Hild's forge** (tier I: fire-baskets and bellows for the braziers, shoeing the staff, a grate for the green, and smelting ash into **ember shards** for the equipment system's gear), **Bet Reed's garden** (tier II plus Bet home: tonics), **Brannoc's hand-bells** (tier III: walk between kindled fires), **the beacon** (tier IV: Rested lasts twice as long). The village talk unlocks with it: Hild and Bet get "make / grow" choices, gated on `v:svc_*`, and a teaser line while the fire is low. | Adapted |
| Food slots (3, one per type; +1 by skill) | **Meals**: three kinds (Hearty = Gloom held, Warming = Gloom drift and fire mending, Sharp = power and recovery). You can have 2 dishes at once, one per kind, and 3 with the *Pilgrim's Appetite* step. The Keg's slate sells bread and dripping, fen-eel stew and mulled ale (cheap, 5-6 min). Bet's garden sells bramble-honey cake, feverfew tonic and bitter rue (stronger, 8-9 min). Re-eating is refused until a dish wears thin. | Adapted |
| Rested from shelter, warmth and comfort | **Rested**: come home from the dark (40 m out), then stand 3 s at the green's fire or inside the Kindled Keg. Gloom gathers 12% slower and spells recover 4% sooner. It lasts 4 min + 30 s per **comfort** point. Comfort = the Hearthfire's own + every village homecoming (VillageCast.RESTORE) + Hild's works. The Long Rest step, the grate and the beacon lengthen it. So restoring Hearthward is now worth something mechanically. | Adapted |
| Fast travel between altars and spires | **Brannoc's bells** (tier III, 24 ash once). At any kindled fire, the Kindling's HEARTH tab lists the other kindled fires. Ring and walk; the fire you arrive at becomes your checkpoint. | Adapted |
| Crafting economy and material tiers | Grave ash is the one currency, now with real sinks: the Hearthfire (126 ash + 5 fragments in all), Hild's works (96), meals, smelting (6 ash -> 1 `ember_shard`, the gear smith's metal: `core/items/gear_runtime.gd` reads `Travel.count("ember_shard")`), Unremember, plus the old Kindling (~620) and Grisel's projects. The *Ash-Gleaner* step adds a second pinch every 5th kill. | Adapted (ItemDB id `ember_shard` is the agreed bridge) |
| Base building, furniture placement | Skipped. Hearthward is hand-built and story-driven. The village rebuilds through RESTORE and Grisel's projects, and now drives comfort. | Skipped |
| Hunger and thirst | Skipped. They are a chore in a night-pilgrimage game. Food only ever helps. | Skipped |
| Stamina-scaling Rested | Not wired. The combat agent's Breath (`core/player/stamina.gd`) exposes `regen_scale` / `breath_max` as the gear hook. Rested should add to Breath regen once that hook can be stacked by several systems. | Left |
| Weapon/armour crafting | The equipment agent's area. We only produce its shards. | Not ours |

## How it plays

1. You wake on the green. The Hearthfire is **Banked**. Hild says she can't forge "on this fire",
   and Bet says nothing grows "in this cold".
2. Kindle the Stair-foot fire. Kills, the kindle and keepsakes fill memory, and a toast says
   "Something comes back to you. Remembrance 1". Spend the point on a Path anywhere ([K], PATHS).
3. Back on the green with 16 ash, feed the Hearthfire: **Drawing**. Every kindled fire's
   sanctuary grows 1 m, you hold 8 more Gloom, and Hild's forge opens (banner "HEARTHWARD /
   Hild's forge").
4. Coming home from the dark and standing by the fire (or in the Keg) gives **Rested** for 4-9
   minutes depending on how restored Hearthward is. Eat bread and stew at the Keg before a long
   push.
5. Two fires kindled plus a relic fragment gives **Roaring**: once Bet Reed is home, her garden
   opens. After the Thornwarden, **Blazing** brings Brannoc's bells: walk between kindled fires.
   After two keepers with all four fires, **Beacon**: Rested doubles and fires reach 4.5 m further.

## Where it lives

- `core/life/progression/paths_db.gd`: the Paths, memory and levels (data, pure).
- `core/life/progression/hearth_db.gd`: the Hearthfire tiers, trades, Hild's works, meals,
  Rested and comfort (data, pure).
- `core/life/progression/hearth.gd`: the runtime (group `hearth`), added by `progression.gd`.
  It gathers memory, takes and gives back steps, raises tiers, sets the `v:svc_*` village flags,
  applies fire reach, counts meals and Rested down, gleans ash and walks between fires.
- `core/life/progression/kindling.gd`: `refresh()` folds `PathsDB.apply` and `HearthDB.apply`
  into `UpgradeDB.live`. It also applies move/jump/step-evade and counts any bent mod as "owned".
- `core/world/brazier.gd`: `set_reach(r)` (additive). The r30 checkpoint and remember logic is
  untouched.
- `core/life/village/village_shop.gd`: the merchants `hild` and `bet`, and meals on the Keg's
  slate (rows from hearth_db, bought through hearth.gd). `village_talk_db.gd`: Hild and Bet's
  trade choices.
- `ui/growth.gd`: the PATHS and HEARTH tabs. `ui/shop.gd`: Kindling glyphs and a per-row `sub`
  line.
- Tests: `zz/hearth_test.tscn` (`tools/run_tests.sh hearth`). Shots: `zz/hearth_shot.tscn`
  (`-- --out=<dir>`).

State: `Travel.system_state("hearth")` holds `{tier, works, meals, rested, gleaned}`.
`Travel.system_state("progression")` gains `{memory, paths}`. Both are saved in `[systems]`.

## What is left

- The HUD shows no Rested or meal icons yet. Today there is a toast, and the HEARTH tab lists
  the timers.
- Breath (stamina) does not feel Rested yet (see above).
- Brannoc's own dialogue (core/story, not ours) does not mention the bells. It could add a
  "bells" choice gated on `v:svc_bells`.
- Paths are chains. A later pass could add cross-links between the Paths at depth 4, as
  constellation bridges.
- Camps can still be farmed for ash (r30 finding 23). The gleaner makes that slightly stronger.
  Diminishing ash per camp per rest is still worth doing in the encounter director.
