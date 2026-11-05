# Equipment, loot and crafting: what we learned from Enshrouded

Owner: the gear layer (`core/items/gear_db.gd`, `gear_stats.gd`, `gear_runtime.gd`, `gear_drop.gd`,
`ui/gear_panel.gd`, test `zz/gear_test.tscn`). Inspiration only. No names, items, characters, UI art
or content were taken.

## What Enshrouded does (research summary, Nov 2026)

- **Slots.** Five armour slots (head, chest, arms, legs, feet), a separate set of cosmetic slots, and
  two ring slots. Weapons go on a hotbar of melee, ranged and magic (wands, staves).
- **Archetypes.** Every armour piece is melee, ranged or magic. Each one leans its stats that way:
  health and block, stamina, or mana and spell damage. Gear is the main way a build commits to a class.
- **Rarity.** Common, Uncommon, Rare, Epic, Legendary. Higher rarity means more and stronger perks,
  and more upgrade levels.
- **Perks / affixes.** Weapons roll perks such as an elemental damage type, leech, crit, bonus damage
  against a creature family, or durability regained on a kill. Since later updates, rings carry
  rarity-scaled upgrades too.
- **Upgrades.** A craftsman NPC at the base spends **Runes** (salvaged from gear or found) to enhance
  equipment. The top levels of rare gear also take a scarce **Legendary Rune**, made from 25 Runes.
  Gems socket into high-tier weapons after that.
- **Sets.** Armour comes in named five-piece sets per archetype and biome. Sources disagree on whether
  a full set gives a bonus. Per-piece effects are what actually define a build.
- **Crafting.** Each archetype has its own NPC crafter at the base (smith, hunter, alchemist) with a
  recipe list. Materials come from biomes and gathering.
- **Loot.** Gear drops by region, from chests, from shroud lairs and dungeons, and from enemy types.
  Some named lore weapons are found once.
- **Durability.** Weapons have durability (a perk restores it on kills).

Sources: enshrouded.wiki.gg (Weapons, Armor), pindrop.gg armour pages, gamerguides.com (salvage and
enhance), 4netplayers ring guide, pindrop legendary-rune guide.

## What we took

| Enshrouded idea | Ours |
|---|---|
| Gear slots that each lean a build | Four slots on things the wanderer already carries: **Orb Focus** (a fitting under the staff's orb: spell power), **Vestment** (Gloom held), **Lantern Glass** (Ward and Well hold longer), **Girdle** (spells recover sooner). Each slot rolls only affixes that suit it: the focus is offence (Lash, Marks, Lance), the vestment is Gloom survival, the girdle is Rift Step and recovery. |
| Five rarity tiers | **Worn, Kindled, Hallowed, Reliquary, Umbral**: 0/1/2/3/3 affixes, raise cap +2..+6, strength x1.0..x2.1. Colours are our own (ash grey, ember amber, pale silver-blue, reliquary violet, rift rose). |
| Random perks | 14 affixes, each one an existing live modifier (`power`, `cd`, `gloom_add`, `dark_mult`, `lit_mult`, `kill_relief`, `step_range`, `step_cd`, `lash_power`, `mark_dmg`, `lance_charge`, `lance_blast`, `ward_life`, `well_life`). Every number the panel shows is a number the spells really use. |
| Rune upgrading + salvage loop | **Ember Shards** (new material) come from salvaging gear. A kindled fire spends grave ash + shards to **raise** a piece (+10% to its affixes and more base each level), or shards (+1 relic fragment for Hallowed+) to **reforge** one affix line. That is the Legendary-Rune idea folded onto the relic fragments we already had. |
| Named sets | Four four-piece sets with **2-worn and 4-worn bonuses** (we made the bonus real, since Enshrouded's is unclear): Kindler's Regalia (Lance/burning), Ferryman's Weeds (Marks/Tether), Lay Brother's Tally (Gloom/Nova), Bellwright's Garb (Lash). The 4-piece bonuses switch on behaviours the game already had (Ember Rosary, Ferryman's Hook + Nan's Chalk, Oath of the Tally, Oath of the Lash). A set can replace an oath or a charm, which frees those choices for something else. |
| Unique legendaries | Four **Umbral legends**, one per slot (Splinter of the Door, Shroud of the Sunk, Glass of the Unlit Lamp, Rope of the Stair). Each turns on a build-defining behaviour: the Open Door's step, bramble Ward, lingering Shade, marking and rooting step. Drops pick a legend you have not found yet. |
| Loot from enemies, elites, bosses | Common foes drop at 2.5% (tough variants 8%), plus a pity of +0.4% for every empty kill. Elites always drop (Kindled+), Deeper Night elites drop better, and each great one drops once: a set piece you lack, or a legend. A drop is a rarity-coloured shaft of light that drifts to you, so you don't have to hunt for it. |
| Gear on the character | Only through the existing equip points. The worn lantern glass tints the lantern's own `LanternLight` toward its rarity colour. A full set or an Umbral glass adds faint motes at the lantern. The wanderer's mesh is untouched (umbral-donts). |

## What we adapted

- **One crafting place, not three NPC crafters.** Raising, reforging and salvaging happen at any
  kindled fire, the same place the Kindling spends ash. Fires are already the game's checkpoint and
  growth spot, so gear doesn't need a base to build. Wearing and planning work anywhere ([O]; it was G until r35, which clashed with the staff strike).
- **No armour values.** The wanderer has no health bar; the pressure is Gloom. "Defence" gear holds
  more Gloom, gathers it slower in the dark, or sheds it at fires and on kills.
- **Charms stay the ring slots.** Our 2-3 charms already work like Enshrouded's rings (unique, found,
  build-bending). Gear sits beside them; it doesn't replace them.
- **A small bag.** 30 pieces. A drop into a full bag is salvaged into shards automatically, so it is
  never lost and the satchel never fills with clutter.

## What we deliberately did not take

- **Durability.** Breaking a pilgrim's staff mid-climb adds chores, not tension. Gloom already does that job.
- **Gem sockets, cosmetic slots, crafting-recipe trees, gathered biome materials.** These are too big for
  a one-night pilgrimage. Our material economy is grave ash, relic fragments and ember shards.
- **Melee/ranged/magic archetypes.** The wanderer is one spell-caster. Builds come from which spells
  and combos gear pushes (Lash, Lance and burning, Marks and Nova, Step), not from weapon class.
- **Item level and gear-score treadmills.** Rarity and raise level are the only power axes, and the
  ceiling is reached within a run.
- **Weapon swapping.** The staff is the wanderer's identity. Its core (Prism, Lodestar, Cinder, Rime)
  remains the weapon choice, and the focus is a fitting on it, not a new weapon.

## How it hooks in (for other agents)

- **Stats.** `UpgradeDB.mods()` calls `GearStats.apply(m)` last (one line). `kindling.gd` treats worn
  gear as "owned" so the tuned skills run (one clause). No edits to `player.gd` or `core/skills/*`.
- **State.** `Travel.system_state("gear")` holds `{bag, worn, next_uid, pity, boss_drops, told}` and
  is saved in `[systems]`. `travel.gd` is unchanged.
- **Runtime and panel.** `progression.gd` adds the `Gear` runtime (group `gear`) and `GearPanel`
  (group `gear_panel`, action `gear` = G).
- **Giving gear from other systems** (quests, secrets): build a piece with
  `GearDB.make(rng, {rarity, slot, set, legend})`, then call `Events.toast.emit(GearRuntime.store(piece))`.

## Left to do

- A pad button for the Gear menu [O] (d-pad is full: up satchel, down journal, left tasks, right Kindling), and a
  row in the settings key list.
- Secrets and quests could award specific set pieces (only enemy and boss drops do now).
- A Keg merchant line that trades shards for a re-roll of a piece's rarity.
- Icons in the list (it uses coloured names now) and a 3D preview of the worn lantern glass.
