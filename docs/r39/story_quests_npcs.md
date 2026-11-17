# Story, quests, people, voice (the story seat's build, r39)

Built from the critique in `docs/r39/2_story_meaning_fantasy.md`. Everything here is data and code that plays; nothing needs
a second pass. Nothing was run in the engine by the author (the lead runs Godot and the suite after the merge): the in-engine
checklist is at the end. Branch `r39-story`.

## 1. One bell canon, and the peal as the climax

- **Canon.** The Founder cast **eight** bells for the roads: seven for the far countries and the eighth, at the Spire, for the
  country the Order shut out. (The rim's three, Hope, Patience and Homecoming, are the Order's, cast first; Brannoc's forty and
  the Hierarch's great bell are his.) "Three is a peal" is the rim's; "four of the eight" no longer exists anywhere.
- **The door needs one bell.** `Chains.BELLS_NEEDED = 1`; `QuestBook.peal_open(need)` is `bells() >= need`. Any of the eight
  opens the summit ward and the dais; the Marches' bell is no longer the door's own price. Objective line, keep, Brannoc,
  `BossArena.no_peal` and the founders_peal task all say one.
- **Every bell after the first is a hand off the Warden.** A tongue carried to the Keg costs him 5% of his life (as before), a
  bell rung where it hangs 3% (`WardenPeal.RING_HOLD`); the multiplier is floored at 0.6.
- **The scene.** When the Ascended Warden wakes (`core/enemy/warden_peal.gd`, called from `ascended_warden.gd`), Aurel says
  his wake line, then each answered bell rings in, one by one, from the bottom up (the bell's name, rung or carried, a stroke a
  step higher than the last: `BellVoice`), then the total ("The Founder's peal is in him..."). No bells: "the sky is quiet as a
  held breath".
- Reach it: kill the Thornwarden and the Bone Abbot, answer any one bell (Gammer Ruan's Kin Bell at the Rooted Holds is the
  nearest), turn it in to Brannoc, cross the Crossing, face the Warden. Files: `quest_chains.gd`, `quest_book.gd`,
  `quest_db.gd`, `dialogue_db.gd`, `boss_arena.gd`, `warden_peal.gd`, `ascended_warden.gd`; tests `zz/act2_test.gd`,
  `zz/story_test.gd` updated.

## 2. Aurel's voice through the night

`core/story/aurel_voice.gd` (added by the story director). The Hierarch speaks to the last of the pilgrims from the sky: a
subtitle line (`Aurel: "..."`) with one low bell stroke and a few syllables of old-man babble pitched down (the kept voices; only
the integration is new). Eighteen lines, each once per cycle (flag `aurel_<id>`, saved with the story): the first fire, all
four, each of the four bosses falling (Thornwarden, Bone Abbot, the Speaking Crown, the Anchoress), the first bell and the third,
the Rift and the summit entered (`region_discovered`), the first time the wanderer is hollowed, the Reaches' threads closed, the
Lamp-Road lit, the third edict restored, left or scratched (The Third Edict's pick), the Deeper Night, and one unprompted line
after nine quiet minutes. Lines wait: no conversation, no boss theme, 75 s since the last. Inside the arena
(`core/story/aurel_lines.gd`): wake, ascension, phase II, phase III (by the edict pick) and his last words (by the pick) as quoted
emotes. Reach it: play; the first line comes with the first fire.

## 3. The rising peal of the fires

`core/story/kindle_bells.gd`: each of the four braziers rings a bell, each higher than the last (root, major third, fifth,
octave); the fourth rings the whole phrase bottom to top. Outpost and Reaches fires ring the low stroke softly. The bell
(`core/story/bell_voice.gd`) is rendered once on a worker thread at the director's start (no main-thread synth).

## 4. The premise shown: the drain

`core/story/drain_beat.gd`: on a new game, nine seconds after the opening's second line, the Gloom tide's own signal is raised
for eleven seconds with nothing hunting in it. The green's people go indoors, the Keg falls quiet and every face turns to the
door, the road's walkers hurry; one very low stroke; two subtitle lines. Then it lets go and they come back. The keep's first
answer now names the Order of the Open Sky and the Hierarch.

## 5. The Anchoress and the Speaking Crown, woven in

- Themes: `boss_themes.gd` gains `r37_anchoress` (E aeolian, the chain's off-beat ticks, the anchor's toll, a wordless alto,
  the lantern a bell a bar) and `r37_hierarch` (one horn holds D under everything, a boy's thin voice far above; the high stem adds
  the horn's own flat second beating against it). All five bosses now have a theme.
- Last words: the Crown ("The note stops. In the throat of the skull a child's stool, and nothing on it."), the Anchoress ("I can
  stop."), Aurel by the third edict's pick. Emotes of both Marches bosses and the Abbot and Thornwarden rewritten to one register
  (a present-tense narrator, one concrete image, no ability names, no instructions beyond the telegraph).
- Each fight opens by what the wanderer did: The Vow's Cell (bread -10% life, name -15%, breach: no change, her line changes) and
  What the Horn Was For (sung -15%, broke / left: the opening line changes). The Bone Abbot's first count changes by the Tally
  post's pick (add Lisle / strike him).
- The keep has two new hub lines (`others_1`, `voice_1`) that name the two bosses past the Lines and the voice.

## 6. Five people with lives (`core/life/village/village_cast_story.gd`)

Each camps at an outpost fire (`village_cast.gd` OUTPOSTS, found by `village.gd _outposts`), has a rig, a schedule (fire at dusk,
a watch on the ground they care for at midnight, a sit before dawn), a hub that changes with what the wanderer has done, a task
they give and a turn-in. Their hubs read the picks of the tasks and the bosses.

| Who | Where | Gives |
|---|---|---|
| Perrin Aldwyn, scribe of the third desk | Chapel yard (chapel region) | The Third Edict |
| Odile Frane, lamplighter's widow | Pilgrims' Road east of Hearthward (road region) | The Lamp-Road |
| Ione Marsh, the Ninth Company's youngest | Glimmer Glade | The Name on the Roll |
| Cantor Lowe, who chose the boy | Siege Lines, by the skull | What the Horn Was For |
| Tamsin Hale, the baker | Anchorholds' cliff road | The Vow's Cell |

Also: Old Isolde (Lastlight) and Sister Agathe have new hub lines reacting to the Lamp-Road and the roll.

## 7-11. Five long tasks (`core/story/quest_chains_story.gd`)

All use the task verbs (clues, tracks, order, vigil, lantern_walk), end by a choice made at a place (the pickups' scenes in `CONVS`),
leave something standing, pay a rarity-3 set piece, and are read by the ending (`end_4s`, `end_4t`).

- **The Third Edict** (Perrin; after the first boss; 8 steps): the copy-book in the Chapel's nave; the road's edict stones; the
  scribe's flight (a trail from Lastlight to the Crossing); the scribe's desk at the Crossing's foot; the three stones touched in order;
  a vigil at the third stone while Aurel speaks; the choice: **restore** "and then I follow", **leave** it, **scratch** it out
  (`qp:aurel_edicts`). Changes Aurel's night lines, phase III and last words, Perrin's hub and the ending.
- **The Lamp-Road** (Odile; after the first fire; 11 steps): three jars of oil; a coal from Hild's forge walked west to the first
  post; a vigil there; a coal from that lamp walked the whole road east; Old Isolde asked what her tower sees; a coal from the tower
  walked the whole road home to the Stair-foot post; the choice: the lamps face the **Stair** or **home**. Leaves six lit lanterns
  along the road for the pick (`verb_world.gd` now lets a pick leave a string of lights: keys `pick`, `pick+1`, ...).
- **The Name on the Roll** (Ione; after two fires or a boss; 8 steps): the Ninth's ring read; Agathe asked; her page of the roll;
  the lay brothers' chalk-ticks (a count falling 33 to 1) to the Barrow Field; the Tally post read; the choice: write **the
  wanderer's own name**, **Ione's mother's**, or leave the line **blank**; a vigil reading the roll in the ring.
- **What the Horn Was For** (Lowe; after two bosses; 8 steps): the Empty Plinth read; the hauling furrow followed south; the skull's
  gate; the boy's slate and stall; a vigil listening to the note; the choice: **sing** the last line, **break** the horn, **leave** it; face
  the Speaking Crown; tell Lowe.
- **The Vow's Cell** (Tamsin; after two bosses; 7 steps): the bread-baskets up the cliff road; the cells read; a vigil at the wall;
  Tamsin's loaf; the choice: **bread**, **name**, or **breach**; face the Anchoress; tell Tamsin.

## 12. The four doors, closed (`core/story/quest_chains_doors.gd`)

The Reaches' threads stopped at four dungeon entrances that do not exist. Four tasks close them as stories at the threshold: **The
Door Left Ajar** (Siany; King's Barrow), **The Bailiff's Last Page** (Penn; castellum), **What the Witch Asked** (Hesper; the witch's
door), **The Ringers' Door** (Maudlin; the Drowned Nave). Each is offered once the earlier task is handed in: read what the lamp shows
(visit, clues), keep the light through a night (vigil), decide what the door is for (three choices; each leaves a light, a stone or a
page), tell the giver. They answer the `HOOKS` in the three Reach files without needing a dungeon.

## 13. Place sounds

`ambience.gd`: three new soundscapes. **chapel** (the First Hearth's crackle under the village's quiet, a far bell), **ring** (the oaks
over a low hum from the chasm bed), **tally** (the Barrow Field's drip, a bittern, a rare bone). Region mapping: chapel to `chapel`,
henge to `ring`, barrows to `tally`. `zz/world_sound_test.gd` accepts `ring` at the end of its crossfade walk.

## How to reach everything in a fresh night

Kindle the meadow brazier: the first bell rings, then Aurel (after the keep). Walk the road west of the Chapel for Perrin and east of
the green for Odile (Odile needs one fire, Perrin one boss). Ione is in the Glade (two fires or a boss). Lowe and Tamsin wait past
the Lines after two bosses (west Siege Lines; the Anchorholds' cliff road). The doors open after the earlier Reach task is handed in.

## What the lead must check in the engine

1. `QuestChains.audit()`, `DialogueDB.audit()` and `zz/story_test`, `zz/act2_test`, `zz/quest*` pass (counts of quests / pickups may be
   asserted; the new ids are listed above). `tools/lint.sh` passes in the worktree.
2. The five camps found a clear spot (`REALM_VILLAGE ... no clear spot for perrin|odile|ione|lowe|tamsin's outpost` in the log): near
   lists are in `village_cast_story.gd` OUTPOSTS; the Realm cache keys include the outposts' `near` (flora keeps them bare), so the
   cache must be rebaked once.
3. Each pickup finds a floor (`QuestWorld.report "no floor for ..."`): the Crossing's foot (310, -58..-68), the Siege Lines' gate
   (-190, 158), the Anchorholds' wall (206, -112..-116), the road posts, the barrow, castellum, witch and Nave doors.
4. The lantern walks (three on the Lamp-Road, the longest ~360 m) can be walked without the lantern dying on a slope; the relight
   pickups work.
5. The opening's drain: `Events.gloom_tide(true)` for 11 s on a fresh game; check the green's villagers go in and come back, the
   Keg looks at the door then laughs, the HUD's tide bar does not appear, and `Director.tide_on` is untouched.
6. The Warden's wake: the bell strokes ring (the bell must have rendered by then), the emote line sequence reads with the arena's name
   card, and the 0.6 floor on his life with all eight bells.
7. The keep's hub does not overflow with the two new choices; the ending's `end_4s` / `end_4t` chain reads.
8. `boss_theme_test` renders the two new themes (seam, peak, no NaN).
