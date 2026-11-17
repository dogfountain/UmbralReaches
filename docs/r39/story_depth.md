# Story depth (r39-sound branch): readables, regional tasks, barks, favours, the ending, a recurring stranger

Luke: "why are all agents done so soon, this is not in depth at all". This is the second wave of the story seat's work (the first, on
branch r39-story, is docs/r39/story_quests_npcs.md). It is entirely data plus four small nodes, nothing per frame, and all of it is
reached through the existing systems (the quest verbs, the village cast, the lore index, the dialogue box). The bell canon holds: eight
road bells, the rim's three are the Order's, one answered bell opens the door. Nothing here was run in the engine by its author.

## B2. Readables: sixty-nine writings through the world, in the journal

`core/world/realm/lore/story_texts.gd` adds 53 placed writings (and 16 beside the landmarks, below) to the lore corpus; the journal
(J, Writings and Stories) lists them by region like every other. Three new series: **The Hierarch's Hand** (six leaves of Aurel's private
book, from "the Stair is nearly done" to the dawn of the Night and the torn last line), **The Founder's Ledger** (eight leaves, one at each
country where she hung a bell: Kin, Mason's, Fog, the Tenor, Ash, Passing, Ferry and the Shut-Out Bell), **Scratched on the Road** (six
waystone and gatepost scratches). The rest are single writings for every region of the Realm and the Reaches, from Hearthward's curfew
notice to the saltpans' silence. `story_readables.gd` (added by the story director) puts a small carrier (a slate or a page) and the
inscription at each place only while the wanderer is within 90 m, finds the floor with one ray, and frees it past 130 m (at most two a
tick), so nothing stands at rest. Reach: walk anywhere; each region has its line within a short walk of its centre; read with E.
**Cost:** a handful of tiny props near the player, a 2 s tick; nothing built at load; reading state is the existing codex save.
**Check:** that carriers find a floor (steep or watery places are skipped silently); the journal tabs show the new series.

## B8. Lore for the world team's landmarks (sixteen more readables)

`LANDMARKS` in the same file keys texts to the landmark host's name: the Sleeper (3), the Hollow King (2), the Salt Ship (2), the Wardens'
Line (3), the Chain Span (2), the Titan Gates (2), the hermit caches (2), plus two roadside scenes standing on the road itself. The placer
puts them beside the landmark's walls, on the side the wanderer comes from, when within 70 m. The Sleeper is the Order's first colossus, pushed
on the first night; the Hollow King's hollow was the Rooted's kings' tomb; the Salt Ship came to the pans a mile a winter; the Wardens were ordered
by Edict II to put out their cressets; the Titans are the Rooted's and the Order only gave them helms. **Cost:** one carrier per text, made once
per landmark on approach and kept (at most about twenty-five props in a night). **Check:** the hosts are in the group `world_poi` with meta `wonder`.

## B1. Regional questlines (five, eight steps each)

`core/story/quest_chains_regions.gd`: for regions that had no long task. Each is clues, a trail (tracks), a coal taken (find), a long lantern walk,
more clues, a vigil, a choice at a place (three picks, three outcomes, a light or stone left), a turn-in. **The Cutters' Debt** (Ebba Sallow,
Reedholm; the Lanternwood: whose is the light of the caps), **The Cairns' Count** (Burl, Lastlight; the Thousand Cairns and the lamp tower),
**What the Oak Remembers** (Hesper Lark, Fallowmere; the Southwood and the Hollow King's hall), **The Brine Road** (Ardel Wick, Saltmarket; the White Pans
and the Salt Ship, the coal carried to the Spire), **The Arches' Last Page** (Reeve Penn; the dry channel to the castellum). Each is offered once the giver's earlier
task is handed in. Pick keys are `qp:<id>:<pick>`, readable by any hub or bark.

## B4. Favours for the named people (four) and the Late Ringer (B6)

`quest_chains_favours.gd`: **Col's Boots** (find, clues, a coal lit home, whose boots they are), **The Candle on the Sill** (Wenna: a shrine's flame walked to the
green, a vigil, where it stands), **Whose Stitches** (Nan, about Pell's shoe: clues, a night's watch, what to leave), **The Ash-Wife's Weights** (Grisel: three weights
found, the scale). The Late Ringer (`village_cast_wanderer.gd`, `quest_chains_wanderer.gd`): **Iorweth**, the last ringer, a stranger who meets the wanderer five times, each at
a bell or stair, as five cast entries present only while the task `last_ringer` is at his step (so he is never in two places). The task is ten steps (talk, clues at the Yard, talk,
a vigil at the shut-out bell, the rope's end taken, talk, clues at the last bell's stone, a choice there, talk, turn-in). He is Ione's father, half-hollow, and the last meeting
is the lore's rule come true: once the door is shut a half-hollow man walks home. Reach: kindle one fire, walk east on the road from the green: he is a hooded man with a rope.
**Cost:** walk islands only, no camps, no props; his five cast entries are filtered by a condition on refresh events.

## B7. The four doors' payoffs

`quest_chains_door_payoffs.gd`: after each door task, a second one at the same threshold: a watch, a scene read whose words follow the pick (three scenes each: what the barrow,
the castellum, the witch's door and the Nave answered), and a last choice to take what was left or leave it. Offered by the same givers.

## B3. Barks and small scenes

`village_barks.gd` with `village_bark_db.gd`: about sixty barks and eight scenes. A bark is a line for a person (or anyone near) when a condition in the village's language holds: bosses,
kindled fires, bells, any task's pick, and the reads the barker tracks itself: the eclipse, the cold hours, the last tenth of the night, the wanderer wounded or nearly hollowed, and the
wanderer's horse by its name. Scenes are two people within 9 m of each other taking turns (Nan and Col, Hild and Fennick, Perrin and Odile, Ione and Wenna, Lowe and Tamsin, Agathe and Cadoc ...).
One bark per ~18 s at most, only while nothing else is said, each with a ten-minute memory; a scene once a night. Shown as a subtitle with a few syllables of the speaker's babble. **Cost:** a 2 s tick over
the villagers within 14 m; no per-frame work.

## B5. The ending: the long walk, six verdicts, the credits

`quest_chains_ending.gd`: once the keep has told the ending, he asks for one last favour: walk the valley once more (the Stair's foot, the First Hearth, the Shrine of the Lost, Maud's door, the first
lamp-post). Each stop is a scene whose words follow the wanderer's picks (the third edict, the lamps, the roll, the shoe, Maud's door, the boots, the horn, the wall), so every combination reads as its own
epilogue. Then the keep gives one of six verdicts (mercy; nearly mercy; the stone left as cut; a great deal of silence; scratched; the plain one) and, after it, the credits, in the world's voice, nine lines
ending "Hearthward keeps its fire." Reach: finish the game, speak to the keep, take "The Long Walk", walk the five places, turn it in, talk to him again.

## Structure

`quest_chains_added.gd` merges every file of the story seat's tasks, pickups, conversations and giver names at first use: `Chains.ORDER`, `QUESTS`, `PICKUPS`, `GIVER_NAMES` and `DialogueDB.CONV` became
static vars over the old const tables (quest_chains.gd kept under 1000 lines). Anything reading them as constants in another file's const expression would break: none was found by grep. To add a file, list it in `FILES`.

## What the lead must check

1. `QuestChains.audit()` and `DialogueDB.audit()` (every new id, giver, pickup and conversation target), `zz/story_test`, `zz/act2_test`, and any test that counts the quests or reads `Chains.QUESTS` in a const.
2. Place floors (`QuestWorld.report "no floor for ..."`) for the new pickups and clues: the Lanternwood ring, the Cairn Tower's foot, the Hollow King's hall, the pans and the Salt Ship's stern, the castellum, the Yard, the Crossing's foot.
3. The cast: Iorweth's five entries appear and vanish with the task (check the refresh events cover a `qat:` change).
4. Readables: carriers appear near the player and not elsewhere; the journal shows 69 more writings and three new series.
5. Barks: one at a time, never over a conversation, no repeats within ten minutes.
6. The keep's hub (more choices) and the credits chain read cleanly after the long walk.

## Third wave: every named person has a task

Audit of the casts (village_cast*, towns, east marches, travellers, the Keg's patrons, the story's five) against `"giver"` and `turnin` in the quest files. Who has what now:

| Person | Tasks (giver) |
|---|---|
| Hild, Fennick, Oswin, Nan, Wyck, Abel | existing tasks; Nan also gives **Whose Stitches** (Pell's shoe) |
| Col Wright | existing + **Col's Boots** |
| Bet Reed | **A Letter for Ewan** (new, third wave) |
| Wenna Ashby | existing + **The Candle on the Sill** |
| Pell | does not speak; her task is Nan's, and she answers it (the keep's ending reads it) |
| Grisel | **The Ash-Wife's Weights** |
| Ruan, Jory, Ysolt, Elspeth, Linnet, Agathe, Cadoc, Dunstan | the seven countries' long runs (template), plus Agathe in **The Name on the Roll** |
| Osk, Cassel, Ennis, Wren/Sedge, Tolliver | the Marches' tasks (unchanged) |
| Dorrit Marl | **Dorrit's Reckoning** (new) |
| Gwyn the ostler | **The Weir Cob's Debt** (new) |
| Bryn Gale | existing |
| Ansel Tansy | **The Stone in Tansy's Boot** (new) |
| Marra Quill | **Marra's Count** (new) |
| Corle, Siany, Ebba, Hobb (Hodge Wade), Penn, Hesper, Cobb, Dilly, Vell, Isolde, Coyle, Fenn, Burl, Maudlin | the towns' tasks, plus the five regional tasks (Ebba, Burl, Hesper, Ardel, Penn) and the four doors' tasks and their payoffs (Siany, Penn, Hesper, Maudlin) |
| Gorse | **Gorse's Eel-Weirs** (new) |
| Brother Wystan | **Brother Wystan's Page** (new) |
| Marl, Teasel, Orrin, Ardel, Pip, Nella | the east marches' tasks; Ardel also **The Brine Road** |
| Hesk, Ostrin Harrow, Brannoc, the keep | the Keg's tasks; the keep also **The Long Walk** |
| Perrin, Odile, Ione, Lowe, Tamsin | their long tasks (first wave) |
| Iorweth (five stations, and a sixth at Ione's fire afterwards) | **The Last Ringer's Road** |

Relationships: each new task's outcomes and the barks name a neighbour (Bet and Nan, Gwyn and Dorrit, Tansy and Marra, Gorse and Siany, Perrin and Odile, Ione and Iorweth, Lowe and Tamsin, Agathe and Cadoc), and
six more two-person scenes were added. `zz/sound_rework_test` now fails on any bark or scene that names a task, pick, boss or speaker that does not exist (all barks that did were corrected: Ysolt's `moor_shrine:wick`, Cadoc's `mere_light:aldous`).
**Check:** the seven new tasks' floors (Reeds' cottage, Weirford's mill and stables, the weir track, the east road, Reedholm's landing, Fallowmere's barn strips) and that Bet, Dorrit, Gwyn, Gorse and Wystan are in the cast at the time their tasks are offered.

## Fourth wave: the critique's remaining items

- **Three more long tasks** (`quest_chains_regions2.gd`, eight steps each, clues / tracks / lantern walk / vigil / a choice, a light or stone left): **The Rim's Three** (Brannoc; the Crowns: Hope, Patience and Homecoming, a coal brought down from the last, where three bells belong: stay, come down, be recast), **The 4001st Step** (Jory; the Saints' Quarry: the brothers' last block, laid as the step before the first, broken, or left for the brother), **The Cold Tenor** (Elspeth; the Founder's Pits and Hild's forge: Edda's fire and the Founder's furnace made one for a night, and what the tenor is for).
- **Aurel and the Anchoress answer more of what was done:** his phase II line changes with three bells answered, his last words with the name written in the roll; the Anchoress's last prayer remembers bread and the name said at the wall. The Thornwarden and the Abbot now die without cursing (the moral weight of the first two kills).
- **The Deeper Night's warning** is in the keep's voice (director.gd `bell_note`): it says it is not a punishment but the valley asking whether you would walk it again.
- **The pilgrim Oswin is now Joram** in every name, line, task and the lore; his id stays `oswin`, so no save key or flag moves. The collision list in LORE.md is Osric / Ostrin and Hesk / Hild / Hobb / Harrow.
- **Solemn babble:** a grave line (two of the grave words, or one and a trailing ellipsis) slows, drops and softens the speaker's babble (`dialogue.gd`); the voices stay babble.
- **Creature voices:** windup, stagger and flee layers added for all fifteen families (`family_voices.gd`).

## Fifth wave: the whole night on paper (a new save, opening to credits)

**Minute 0-3, arrival.** Black lifts, zone card, subtitle 1 (the road ends; the Stair, the sky it opened), the HUD and guide arrive with the objective "Find the keep in the Kindled Keg", the compass and waypoint. Subtitle 2 (the cold comes down the mountain), then nine seconds on, the *drain*: the Gloom tide's own signal for eleven seconds (the green's people go in, the Keg looks at its door, one very low bell stroke, two subtitle lines), then it lets go. Subtitle 3 names the keep. Readables are within a short walk of the spawn (the noticeboard's curfew, Nan's mug tag). *Nothing to do?* No: the objective, the compass and a villager pointing.
**The keep.** Meet: the Order of the Open Sky and the Hierarch are named in his first answer (canon fix); "where do I start" gives the four fires and the two doors. First fire: the rising bell (first stroke), the keep's `first_fire` objective, Aurel's first line once the keep has met you. Journal: the readables, the Chronicle's "The first fire". Guide "what next" runs until Brannoc has been spoken to after both keepers.
**Doors, either order.** Thornwarden: Ring's titan gates (landmark readables), seal, fight (theme, emotes, the death line, Aurel's line on his fall); Abbot: Ossuary room (interior bed), Tally readables, the pick of `bead_count` changes his first count; each fall is a stinger and a silence. After both: objective "speak to Brannoc, then answer one bell" and the keep's hub names the others past the Lines. *Dead end found and fixed:* the nearest bell (Ruan's) was offered only after her whole chain; it now asks nothing first, so the main path never waits on an optional chain. *Contradiction found and fixed:* the objective, the keep and Brannoc all said "four" and "the Marches' among them"; all now say one, any of the eight.
**The peal.** One bell answered (ring or carry) and Brannoc's task is handed in; the ward on the Crossing opens to heart, crown and a bell; the guards, then the Warden: Aurel's wake line, each answered bell rung in, phases with his lines by the third edict's pick, his last words. If the player never did The Third Edict he still speaks (default lines). The ending beat (silence, the bell, the card) is unchanged; the keep's last conversation now reads the picks.
**Side lines on that path** (none gates it): the long tasks, the favours, the regions' tasks, the Late Ringer (from the first fire to Ione's fire), the doors and their payoffs, readables and barks.
**The four doors.** King's Barrow: `wr_stand_down` (Reedholm) then `wr_kings_lamp`, then `wr_door_kings`, then its payoff. Castellum: `ds_water_road` then `ds_door_castellum` then its payoff. Witch: `ds_witchs_price` then `ds_door_witch` then its payoff. Drowned Nave: `er_ringers_candle` then `er_door_nave` then its payoff. Each needs only the previous task in its own chain; each pays a rarity-2 piece; each leaves a light or stone.
**After the door.** The keep tells the ending, offers The Long Walk (five scenes keyed to the picks), then speaks a verdict (six) and the credits (nine lines) and the credits stinger plays; the Deeper Night bell's warning is in his voice.

**Checks of the canon and of each other** (grepped): eight road bells everywhere (seven for the countries and the Shut-Out one), the rim's three are the Order's, forty small bells Brannoc's; "nine winters" throughout; Ione's father (the last ringer) rang on the Stair the week the Night began and is half-hollow, consistent with the lore's rule; Aurel's third edict, the scribe who cut it short, the scratched line "one is still on the Stair" and the stone at the Crossing's foot agree; Edda's apron, the First Hearth and Hild's forge agree.
**Open (not contradictions):** the Rift's rim and the summit approach now have **The Watch on the Rim** (Coyle) and **Lamps for the Last Mile** (Isolde), both offered after Lastlight's earlier tasks; the world seat's landmark placements decide whether the readables beside them appear.
