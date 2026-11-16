# The Far Reaches' tasks

Luke, 14 Nov 2026: "there's too little content in the game." The Far Reaches (docs/far_reaches.md) had places, camps, rares,
guardians and sixteen villagers, but four tasks between them. This pass audits each Reach and gives it a main thread and side
tasks tied to its own places, people and rares: thirteen new one-time tasks, made only from systems that exist (step kinds,
pickups, lamps, rares, escort and defend, found-in-the-world starts, conversation choices). Data:
`core/story/quest_chains_far_reaches_west.gd`, `_south.gd`, `_east.gd`, listed in `quest_chains.gd` under
`# --- the reaches ---`; their pickups' conversations in `dialogue_db.gd`; the givers' reactions in the towns' CONV
(`village_reach_towns.gd`). Each file's QUESTS, PICKUPS, CONVS, HOOKS and ZONE are its own.

## The audit (before this pass)

What each region offers, and what touched it. "Touched by" lists every task whose steps name the region or one of its places.

| Reach | Region | What it offers (places, people, enemies) | Touched by |
|---|---|---|---|
| West | The Greyfell | Broken Keep (garrison camps, castellan, chests), fell shrine, Crown Beacon (kindle), Muster Stones, Sentry's Rest, Signal Cairn; rare *the Sentry Who Was Never Relieved* | nothing |
| West | The Lanternwood | ring of giant caps (the Cap-Mother), Last Milestone and toll-house, Lantern Stones, Mosswife's Shrine, Cutters' Hollow; rare *Wick, the Lamp-Grown* | nothing |
| West | The Kings' Barrows | the King's Barrow (open door, chest, the Barrow-King), Stone Row, Queen's Mound, Robbers' Trench; rare *the Crownless King* | nothing |
| West | The Reedmere | Reedholm (Aud Corle, Hobb Wade, Siany, Gorse, Ebba Sallow), the heron stones (the Reed-Reeve), Eel-Wife's Landing, Fishers' Graves; rare *the Heron-Wife* | `rh_lamps` |
| South | Fallowmere | Penn, Hesper, Cobb, Dilly, Wystan; tithe barn, strips, scarecrow field (the Scarecrow), Fallow Beacon, Tithe Cart; rare *the Tithe-Taker* | `fm_tithe` |
| South | The Long Arches | the aqueduct (walkable), the castellum and its chest (the Water-Bailiff), Arches Beacon, Masons' Yard, Dry Cistern; rare *Spill* | nothing |
| South | The Southwood | the burners' ruin and clamps, the witch's hollow (the Hollow-Witch), Nail Shrine, Hob's Stack; rare *the Last Charcoal-Burner* | nothing |
| East | Lastlight | Mother Vell, Old Isolde, Serjeant Coyle, Fenn, Wat, Sister Maudlin; the shut East Gate, the lamp tower, the stable, the shrine | `ll_gate`, `ll_oil` |
| East | The Bellfall | the eighth bell in its crater (chest, the Eighth Ringer), Shard Field, Ringers' Cairn, Scorch Watch; rare *the Cracked Tollman* | `ll_gate` (its slay counts here) |
| East | The Drowned Nave | the flooded cathedral (the Precentor), Saints' Wait, Masons' Lodge; rare *the Bell-Rope Nun* | `ll_oil` (tallow off its drowned) |
| East | The Thousand Cairns | the Cairn Tower and its chest (the Cairn-Warden), Counting Cairn, Turning Stone; rare *the One Who Counted* | nothing |

Six of the eleven regions had no task at all, and the Bellfall and the Nave only a clause of one. None of the Reaches had a
thread across its own landmarks, no task was closed by a different person from the one who gave it, no Reach rare was wanted by
anyone, and none used the Reaches' lamps (the three beacons) or a conversation choice.

## The new tasks

`★` main thread; a hook marks a step that ends at a boss dungeon's entrance (see below). Rewards are in line with the tales
(ash 22 to 40, relic fragments, ember shards, a choice of gear; mains pay rarity-3 set pieces). No new items: the gear is the
existing sets (kindler, ferryman, bell) and every item named is already painted.

| Task | Giver / turn-in | Where | Steps | Kinds | The turn |
|---|---|---|---|---|---|
| ★ **Stand Down** (`wr_stand_down`) | Aud Corle | the heron stones (Reedmere), the ring of giant caps (Lanternwood), the fell shrine under the Broken Keep (Greyfell) | satchel from the reeds; carry its route slip to the ring; put down the Sentry Who Was Never Relieved; deal with the order at the shrine (read it, burn it, or leave it sealed); tell Aud | find, visit, rare slay, place with a **choice** | the order says STAND DOWN AND COME EAST AND BE COUNTED: a garrison that never got it is the only one that lived |
| **A Lamp for the Kings' Door** (`wr_kings_lamp`) | Siany | the jetty, the barrow road, the King's Barrow's open door | take the king's lamp; carry it up the barrow road (120 s); set it on the threshold *(hook)*; tell Siany | find, carry, place | the lamp book began as the kings' lamp book; the stone was rolled from the inside |
| **Cold Light** (`wr_cold_light`) | Ebba Sallow | the ring of giant caps; Ebba's punt slip | put down Wick, the Lamp-Grown; cut three cold caps; hang them in the punt's bow; tell Ebba | rare slay, gather, place | the caps light nothing: a boat should be seen from boats and from nowhere else |
| **The Fourth Stone** (`wr_fourth_stone`) | Hobb Wade | the heron stones | go out and read the verse; touch the herons in the order it gives (a four-step **puzzle**, wrong order starts over); put down the Heron-Wife; tell Hobb | visit, puzzle conversation, rare slay | the fourth bird takes the oar; Hobb puts one on the stone for Tam |
| **Tansy's Boat** (`wr_tansys_boat`, FOUND) | Ebba Sallow | the Last Milestone's toll-house; Ebba's slip | read the toll-keeper's ledger (the task starts at the toll-house); cut Alma Tansy's name in her boat; tell Ebba | find, place | Alma paid for the boat and went east the day before the Night |
| ★ **The Water Road** (`ds_water_road`) | Reeve Penn | the Fallow Beacon, the dry channel under the Arches, the castellum, the Arches Beacon | kindle the Fallow Beacon; put down Spill; read the water-keeper's last page at the castellum *(hook)*; kindle the Arches Beacon; tell Penn | lamp (cond), rare slay, find, lamp (cond) | the keeper's page: LIT IT ANYWAY. IT MAY HELP SOMEONE FIND US |
| **The One I Didn't Make** (`ds_unmade`) | Dilly | the far strips and the scarecrow field | look at the scarecrow nobody made; put down the Tithe-Taker; turn the scarecrow to the road; tell Dilly | find, rare slay, place | the face is Dilly's own chalk, carried about by a reeve's coat the Order's last reeve wore to the Stair |
| **The Witch's Price** (`ds_witchs_price`) | Hesper Lark | the farmhouse door, the burners' ruin, the Hollow-Witch's door | take the door-nail; walk the wood past the burners' ruin; drive the nail and ask (bread, the far strips, or nothing: a **choice**) *(hook)*; tell Hesper | find, visit, place with a choice | what the witch takes is not told; the outcome differs three ways |
| **Cobb's Clapper** (`ds_clapper`) | Cobb Lark | the south strip, the castellum's water-bell | take the clapper from the furrow; hang it in the water-bell; hold the castellum 40 s while the bell tolls; tell Cobb | find, place, **defend** | the dry channel runs for the length of a breath |
| ★ **The Candle for the Ringers** (`er_ringers_candle`) | Sister Maudlin | Lastlight's shrine, the Bellfall's west lip, the crater's south rim, the Drowned Nave's west door | take Maudlin's candle; carry it to the Bellfall (120 s); put down the Cracked Tollman; set the candle on the Nave's step *(hook)*; tell Maudlin | find, carry, rare slay, place | one bell-rope drawn in the dark; Maudlin turns to face the road, not the gate |
| **The One at the Nave Fire** (`er_nave_fire`, after the candle) | Fenn / Maudlin | the Nave's north-shore fire, nave_track, the road gate, the shrine | sit by the man at the fire; **escort** Tobin up the road to the shrine (ambushes on the road); tell Maudlin | visit, escort, turn-in elsewhere | Tobin, the lowest rope, who kept a little warmth; Coyle opens the postern, not the gate |
| **The Bell on the Bridle** (`er_halter_bell`) | Wat | the stable, the cairn road, the Cairn Tower | take the mare's halter-bell; carry it south to the tower's foot (150 s; a horse would help); hang it on the rag-pole; tell Wat | find, carry, place | she only wanted to know it had arrived |
| **The Last Lamp's Slate** (`er_inn_slate`) | Mother Vell | the north cairns, the One Who Counted's round, the inn's counter | take the inn's tokens off the turned-back (5); put down the One Who Counted; set the tokens before the slate (wipe it, keep it, or write PAID: a **choice**); tell Vell | collect, rare slay, place with a choice | three hundred years of debts, and what to do with them |

Every step has a world position the quest trail can read: `visit` / `carry` / `slay` / `cond` / `defend` / `escort` carry `at`
or `to` in the step (the escort's `at` is its last point and `path` the road), and `find` / `gather` / `place` use their
pickup's `near`; `talk` and `turnin` point at the person. The pickups with a conversation (the shrine, the heron stones, the
witch's door, the slate) open `dialogue_db.gd`'s CONV entries of the same name; their last choice runs `qp:` (the pick) and
`qa:` (the step), so an outcome and an `alt` step text follow the pick.

## Where the threads end at a dungeon

Another lane builds one boss dungeon per Reach (the King's Barrow, the castellum or the witch's hollow, the Drowned Nave). No
task here goes inside; each ends a step at the entrance and leaves a hook the dungeon lane can read, in the file's `HOOKS`:

| Dungeon | Hook (`HOOKS` key) | Reached when | Done when |
|---|---|---|---|
| the King's Barrow | `kings_barrow` (`quest_chains_far_reaches_west.gd`) | `q:wr_kings_lamp:2` (the lamp is to be set on the open door, `at` (-345, 167)) | `qd:wr_kings_lamp` |
| the castellum | `castellum` (south) | `q:ds_water_road:2` (the keeper's page at the castellum, `at` (-60, 346)) | `qd:ds_water_road` |
| the witch's hollow | `witchs_hollow` (south) | `q:ds_witchs_price:2` (the nail at the witch's door, `at` (224, 360)) | `qd:ds_witchs_price` |
| the Drowned Nave | `drowned_nave` (east) | `q:er_ringers_candle:3` (the candle on the Nave's west step, `at` (300, 154)) | `qd:er_ringers_candle` |

Each `cond` is a QuestDB / VillageState term, so a dungeon quest can use it in `avail`, a door can test it with
`QuestDB.test`, and the `at` / `r` are where the step's pin stands: the dungeon lane replaces them with its real entrance (the
quest's `place` pickup near, `HOOKS.at` and the step's text move together). A dungeon's own boss can be asked for with a
`cond: "boss:<id>"` step in a follow-up task; nothing here waits on a dungeon being built.

## What a test should check

- `QuestChains.audit()` and `DialogueDB.audit()` (zz/story_test, zz/quests_*): every id is in ORDER, every pickup has its step,
  every rare is in RARE_IDS and rares.gd, every conversation's targets exist.
- The pickups find a floor (`QuestWorld.report` prints "no floor for ..."): the satchel and the heron stones stand in the south
  mere, the king's door and the Nave's step on terraces, the punt's bow and Ebba's boat on Reedholm's decks.
- The found task `wr_tansys_boat` starts when the wanderer comes within 9 m of the toll-house; a carry that runs out of time
  falls back one step; the escort's ambushes on nave_track and its arrival at the shrine; the defend at the castellum.
