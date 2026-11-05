# r30 critique: the storyteller

Read-only review of the story and how it is delivered. Sources: AGENTS.md, docs/STORY.md,
docs/LORE.md, docs/HANDOFF.md, docs/critique/register.md, then every text table the player can see:
`core/story/*`, `core/life/village/village_talk_db.gd` + `village_cast.gd` + `village_shop.gd`,
`core/npc/keg_scenes.gd`, `core/world/realm/lore_db.gd` + `lore/lore_more.gd`,
`core/life/secrets/pages.gd`, `core/life/encounters/elites.gd` + `director.gd` + `deeper_bell.gd`,
`core/items/item_db.gd`, the bosses (`core/enemy/*`, `boss_arena.gd`, `thorn_henge.gd`,
`summit_dress.gd`, `world/areas/ossuary/*`), `core/life/secrets/reactivity.gd`, the HUD/loading
strings, `zz/trailer.gd` (the three title cards). No game run was needed; nothing was edited.

## Verdict

The prose is the best thing in the project. The house style (terse, concrete, dark) holds across
about 200 written beats by several authors. Maud's three letters, Brother Lisle's Tally ("Add him."),
Nan's chalk circles, Oswin's forty-first stone and the hearthstone's "in mouths when the pots broke"
are as good as anything in the genre. The motifs (up and down, bells, counting, three knocks, faces,
doors) are real motifs: they recur without being explained.

The **spine** is much weaker than the side stories, and the weakness is structural, not in the
writing:

- the wanderer has no stake;
- the keep gives away every revelation in the second minute;
- the three bosses are mute, and their rooms carry no text;
- the "heart and crown" key does nothing in play;
- the climax arrives as four toasts that contradict each other and the sky.

The canon has also drifted in a few load-bearing places: who comes back down, the bells, Edda's
coals, how long ago the Night was. And the Deeper Night undoes the ending without a frame.

The good news is that almost every fix is a text or data edit, and the strongest premise the game
could have is already built into the wanderer's model. Nobody has said it out loud yet.

What works and must not be lost: Maud/Hobb (letters, then the bounty "Maud need never know whose
hands they were", then the keep's "Maud still sits up for it"); the Tally; Father Harrow ("His face
is a hole." / "He lies down in the reeds as if he had only been waiting to be told."); the quest
outcomes that stay in the world (the lantern on the counter, the names in the Yard); Wenna's
post-Warden line "the door is shut, Mother. Come down."; the NPC lines that react to secrets; and
"They do not kill. They fill the dark." as rules-as-lore.

---

## Findings

### Critical

**1. The wanderer has no stake, and the model already tells a story that nobody voices.**
Evidence:
- `core/player/void_face.gdshader:3` "A black void in the cowl".
- `core/player/wanderer_orb.gdshader:3`: a violet orb "with a slow inner swirl". This is the
  vortex's violet. The Ascended Warden's eye is the same violet (`enemy_body.gd:147`, Color(1.5, 0.75, 3.2)).
- Most of the spells are the sky's: Rift Bolt, Umbral Nova, Rift Step, Umbral Well, Rift Tether,
  Bound Shade.
- The wanderer walks back from being hollowed (LORE.md "Powers").
- Abel notices: "The dead don't usually make a habit of it." (`village_talk_db.gd:235`).
- Father Harrow: "His face is a hole." (`quest_world.gd:308`). That is the wanderer's face too.
- The keep only says "kindled, or mad" (`dialogue_db.gd:28`). No one asks who you are or why you
  came, and the ending choice is about Aurel, not about you (`dialogue_db.gd:128-131`).

Problem: the protagonist carries the antagonist's colour and power and has the face of the
hollowed. The fiction never acknowledges any of it, so the player has no personal question to carry
up the Stair. It is the single largest missed story in the game.

Fix: make it canon and seed it lightly. The Third Edict is the hinge: "I will hold the door until
the last of you is through" (`lore_db.gd:174`). The wanderer is a late pilgrim, like the Ninth
Company. They climbed, the door half-took them, and they came down not quite hollow, carrying a
splinter of the open sky in the orb. Aurel is holding the door for *them*. Seed it in four places:
- Nan (new `hub` line, first meeting): "You haven't got a face. That's all right. Pell's hands are cold."
- Abel (`hollows:3`): "Back again. You come back the way they do. Only you come back *warm*."
- Rim Edict III, add a second sentence carved later, in another hand: "One is still on the Stair."
- The Warden fight, phase 3 (finding 4): the orb answers the halo; the orb dims as he dies.

The keep's end conversation then gets a real third choice beside the two about Aurel: "He was
waiting for me." -> "Then he waited for nothing. You're here. Sit." This needs no new system.

**2. The climax is a toast pile-up, and the world contradicts the words.**
Evidence. When the Warden dies, within about 4 s:
- `boss_arena.gd:186` "The Ascended Warden falls."
- `summit_dress.gd:129` "The Ascension seal is yours. The sky turns inward no longer."
- `reactivity.gd:54` "Over the Crowns the sky slows, and slows."
- then `story.gd:332` (4 s timer) narrates "The sky stops turning. / Somewhere above the Crowns, a
  bell rings once."

Against those words:
- The sky does not stop. `reactivity.gd:283` eases spin_speed over 18 s to 18% of its base
  (CALM sums to 1.0, so `1 - 0.82*c`).
- No bell sounds: `_ending` only narrates.
- There is no bell at the summit, yet Brannoc says "nothing up there now but his bell, and it's
  rung" (`dialogue_db.gd:226`).
- The explore music rings "a low bell" at random all game (`scape_music.gd:7,184,191`), which wears
  out the one sound the story saves for its ending.

Problem: the game's thesis image ("the bells stopped; one rings, from the bottom up") is delivered
as the fourth line in a queue of status messages, over a sky that keeps turning, in silence.

Fix:
- Cut the two boss toasts for the Warden only (keep "falls." for the other two).
- Run one beat. The bar drops; 1.5 s of silence; the sky's spin eases to **zero** over the
  narration (spin 0, twist kept); line 1; a single deep bell (Brannoc's: low, long decay, played
  once, non-positional) between lines 1 and 2; line 3.
- Hang Aurel's great bell over the dais, silent through the fight. It is the bell that rings.
- Take the bell voice out of `scape_music` until `ending_seen`. Afterwards it may come back, rarely.
- Keep the Seal's pickup text for the satchel and do not toast it.

### High

**3. The keep tells the whole plot in the second minute.**
Evidence:
- `dialogue_db.gd:35-38`: on first meeting he explains Aurel opening the sky, Edda, all three
  bosses, and that the ward wants "a heart out of the henge and a crown out of the crypt".
- `dialogue_db.gd:117`: "Aurel at the summit, holding the door."
- Brannoc's first two lines name Aurel again (`dialogue_db.gd:214-215`).
- So the Third Edict on the rim (`lore_db.gd:174`), the best reveal in the game, confirms what you
  were told an hour earlier.

Problem: revelations are front-loaded, so the lore the player finds later only repeats. The
Ascended Warden = Aurel should be the spine's reveal, not its premise.

Fix: stage it. The keep knows *what*, not *who*:
- three_1 / three_2: "Three. Something in the Ring that keeps the oaks. The Abbot under the abbey,
  still counting. And whatever stands at the top of the Stair with the door open. The ward on the
  Crossing won't let you near it till the other two are down."
- Brannoc's `meet_2` gated `bosses:1`: "I cast the Hierarch's bell. If that's him up there,
  holding the door, I cast it for nothing."
- The Rift-rim Edict III is the confirmation.
- The bar renames itself in phase 3 (finding 4).
- lore_1 keeps Edda and drops Aurel's name: "Somebody opened the sky at the top of the Stair. It
  opened inward."

**4. The three bosses are not characters; the final one is a mute stranger.**
Evidence:
- Subtitles (`thorn_henge.gd:249`, `ossuary.gd:728`, `summit_dress.gd:126`): "warden of the thorn
  henge" is redundant with its own name; "keeper of the crypt" and "last priest of the ascension"
  are generic.
- Phase lines are mechanical: "The Warden's light turns to judgement." (`ascended_warden.gd:64`).
- Neither Osric nor Aurel is named in a fight.
- The Warden's kit is "blinks round the dais and judges from range" (`ascended_warden.gd:1-9`). It
  expresses nothing of a man "halfway up the sky and stopped, still holding the door open"
  (LORE.md "The three who hold the valley").

Fix: use what the lore already says.
- Subtitles:
  - Thornwarden: "what the Rooted asked to stand"
  - Bone Abbot: "Abbot Osric, still counting"
  - Ascended Warden: "the Hierarch, holding the door"
- Abbot phase lines: "One thousand and ninety. One thousand and ninety-one." and "The Abbot counts
  you among the faithful." (He should count audibly; the Tally is his voice.)
- Warden mechanic: one arm stays raised to the vortex in phases 1-2, with a thin violet thread from
  the hand to the sky. His attacks come from the other hand, so he holds the door while he fights.
  Phase 3 line: "He lets go of the door with one hand." The thread snaps and he fights two-handed
  (this is the "pours out").
- At phase 3 the bar renames to "AUREL, HIERARCH". On death the seal falls out of his opened
  fingers ("his fingers had grown round it", `item_db.gd:22`). The keep's question "Aurel?" then
  has something the player saw.

**5. "Heart and crown" is a key that is never turned.**
Evidence:
- The ward checks `Travel.bosses_slain` only (`ward_seal.gd:75-80`, `boss_arena.gd:133-138`).
  Nothing is brought or placed, although the objective says "Bring heart and crown to the summit
  ward" (`quest_db.gd:27-28`).
- "Nothing answers. Two seals still hold below." is hard-coded, so it says "Two" with one boss
  dead (`boss_arena.gd:137`).
- The Abbot objective says "Recover the Bone Reliquary" (`quest_db.gd:25-26`), but the ward wants
  the Crown (`item_db.gd:18-20`). Taking the Reliquary is optional.
- No line says why an Order ward answers to a Rooted thorn-heart.

Fix:
- Two sockets on the ward, each with an interact: "[E] Lay the Thorn Heart in the ward" and
  "[E] Set the Abbot's Crown in the ward". The ward opens when both are set. The items stay in the
  satchel as relics, or become "set in the ward".
- Toast: "Nothing answers. %s still hold%s below." built from what is missing ("The Ring's heart" /
  "The crypt's crown").
- Objective: "Take the Abbot's crown from the Bone Abbot".
- The reason, as a carved line on the ward: "Let none climb to the door but by the leave of the
  two who keep the valley down: the root, and the count. A." Aurel sealed his door with the valley's
  two powers of *below*. That is thematic, and it makes killing the neutral Thornwarden a choice
  the text admits.

**6. The canon contradicts itself on who comes back down.**
Evidence:
- The keep's ending says "The ones it drank don't come back down" (`dialogue_db.gd:134`).
- But Hobb went up and came down hollow: "Maud's son came down." (`item_db.gd:51`, `elites.gd:71`,
  `pages.gd:58`).
- The hermit "watched them come down hollow" (`pages.gd:82`).
- Wenna's mother went up (LORE.md series table), was sunk in the fen and walked to the Ossuary
  (`lore_db.gd` jn_8, jn_9).
- Pell walks back after the ending (`village_cast.gd:262`).
- The Rooted's saying is literally "what climbs comes down hollow".

Fix: one rule, said once. Those who went all the way through are gone. Those the door half-took
come down hollow. Rewrite end_4: "The ones that went all the way through don't come back. The ones
that came down hollow can lie down now. And Maud can put out her candle and sleep." Add the rule to
LORE.md's "Powers".

**7. The bells are three different stories.**
Evidence:
- Brannoc: "I cast the bells for the Stair. Forty of them." and Aurel's bell "Bigger than this
  room" (`dialogue_db.gd:214-215`).
- The rim secret: "Hope, Patience, Homecoming: the Stair's three bells", cast by a "Founder" who is
  "she" (`pages.gd:32,34,50`).
- Brannoc on the bell puzzle: "the right order, top to bottom" (`dialogue_db.gd:217`). The puzzle
  is great -> middle -> treble (`site_rim.gd:24`), which is "from the bottom up", the line the
  plaque itself ends on.
- The Keg argument "The bell rang up. I heard it go up." plays ungated before the ending
  (`keg_scenes.gd:26`).
- The Deeper Night banner reuses the ending's image: "The bell rings once, from the bottom up."
  (`director.gd:720`).

Fix:
- The Founder is Brannoc's mother. Brannoc meet: "Mother cast the three on the rim. I cast the
  forty small ones for the Stair, and the Hierarch's. I heard them stop, top first."
- Brannoc's peal line: "...the right way, the great bell first, bottom to top. Mother's order."
- Gate ARGUE[0] on `boss:ascended_warden`, or swap it for "The bells stopped top first." /
  "Everything stops top first. Look at you."
- Give the Deeper Night bell its own sound and words (finding 8).

**8. The Deeper Night undoes the ending without a frame, and the ending's flags survive it.**
Evidence:
- `begin_deeper_night` clears bosses and seals (`director.gd:711-716`) but not `Travel.story`.
- So `ending_told` stays set, and the keep's hub opens with "The fire draws by itself now; I've
  nothing to do but pour." while the sky turns again (`dialogue_db.gd:47`, the first say_if).
- `ending_seen` and `ending_card` stay set, so a second Warden kill gets no narration, no
  conversation and no card.
- The bell's text says "the dark it pulled down is still here, and deeper" (`director.gd:703`),
  against the ending's "The cold stays. It no longer pulls."

Fix:
- Frame it: the wanderer rings a *cracked* bell the wrong way up ("top first"), and the door,
  shut, is pulled ajar from below. New banner: "THE DEEPER NIGHT / The cracked bell rings top
  first. Something holds the door again."
- On ring, clear `ending_seen/ending_told/ending_card` into `ending_*_ng<n>` copies.
- Give the keep an `ng` greeting: "You rang it. ...I heard it. Wrong way up. Sit; it's going to be
  a long one."
- Give Hesk, Harrow and Brannoc's hubs a `deeper` line each.

**9. The boss spaces carry no text; the series climax off-stage.**
Evidence:
- No `region` "henge", "summit" or "crags" entry exists in `lore_db.gd` or `lore_more.gd`.
- `thorn_henge.gd`, `summit_dress.gd` and `ossuary.gd` place no Inscription. Only `oss_deep.gd`,
  reached after the Abbot, does.
- Wenna's journal ends "something below is counting in Mother's voice. I have one candle." (jn_9).
  Nothing of Wenna or her mother is in the Ossuary. Her payoff is a line from her after the Abbot
  (`village_talk_db.gd:188-189`).
- The Song's last verse, the Tally and the Edicts all point at rooms that say nothing.

Fix: one or two carriers per boss approach, using the existing Inscription kit.
- Henge stair head (rune): "Keeper, keep. If one comes up the hill with fire, let them by. We were
  wrong about fire." (cut in the Rooted's hand, half under thorn)
- Ossuary gallery niche (Wenna, `jn_10`): "She counted me. I let her. Then I said her name back,
  and she stopped." Put a stub of candle in the niche, still warm.
- In the Abbot's phase 2, one of the two raised Ossuants speaks a woman's "...Wenna?" in the
  formant voice (`npc_voice.gd` already exists).
- The Crossing (a pilgrim's tally scratched on a step): "Step 3,112. Bells stopped. Going on anyway."
- The summit dais (plaque): "HERE THE HIERARCH AUREL OPENED THE DOOR. THE NAMES OF THE FAITHFUL
  WHO WENT THROUGH:" and the rest of the plaque is blank.

**10. The opening is staged at the destination.**
Evidence:
- `PLAYER_START` is (0, 26.5) (`realm_layout.gd:18`), on the green about 18 m from the Keg.
- The first narration line is "The road ends here." (`dialogue_db.gd:240`) and the keep says "You
  walked in off the road" (`dialogue_db.gd:28`), but the player never walked it.
- The road's lore is ordered for walking in. Wenna's page i sits by the pack at the West Gate,
  100 m west (`road.gd:18-30`). The edicts, the "GONE AHEAD" cart and the leaning lamps lie between.
- Objective 1 ("Find the keep") is already done by looking around.

Fix: on a fresh save (the `arrived` flag), start on the road at waystone III, about 25 m west of the
bend, facing the village, with the Keg's windows lit in frame. Run the narration over the walk in.
Let the first readable be the waystone ("III miles. Hearthward: last bread, last bed, last fire
before the Stair."). If the walk is too long, keep the green spawn but turn the camera to the Keg
door and put the first notice ("Pilgrims: the Stair is closed. The Keg has beds.") on the path.

### Medium

**11. Edda's coals change vessel from text to text, and the ferrule contradicts its own quest.**
Evidence:
- Hild says Edda carried the coals "in her apron and burned her hands to the bone"
  (`village_talk_db.gd:56`), and also "carried the coals to the chapel in them" (the tongs, `:33`).
- Ansel saw "a bowl of coals" (`lore_db.gd` ch_ansel_1); the hearthstone says pots and hands.
- Edda's Ferrule is "the iron shoe Edda forged for her husband's walking staff. Hild kept it on
  the anvil-stone" (`item_db.gd:79`). In the quest Hild forges a *new* ferrule from Edda's tongs
  (`village_talk_db.gd:44,48`).

Fix: one image. Edda lifted the coals with her tongs until the jaws burned through, then carried
the rest in her apron. Rewrites:
- Hild `ask`: "She lifted the coals in them till the jaws burned black, then carried the rest in
  her apron."
- Ansel: "...what she had been carved holding: tongs, and in their jaws a coal."
- Ferrule desc: "Iron off the jaws of Edda's tongs, drawn out on Hild's anvil and shrunk onto your
  staff. It rings when it strikes stone."

**12. The timeline is unpinned.**
How long ago the Night was depends on who is talking:
- "Four winters gone" (`dialogue_db.gd:183`); "Four years under the Keg's stair" (`village_talk_db.gd:173`).
- The hermit has climbed the Rift (which only exists since the Night) for "eleven winters"
  (`pages.gd:80`). Oswin has "walked eleven years" (`village_talk_db.gd:93`).
- "My grandfather saw the Door open." (`keg_scenes.gd:31`).
- The Ossuary holds 11,004 counted plus "twice that" uncounted (`pages.gd:73`), against Lisle's
  1,090 (`lore_db.gd:154`) and Wenna living through "the crypt is full" (jn_6).

Fix: choose a number. Nine winters fits most lines, and Pell is "nine winters". Put it in LORE.md's
timeline. Then:
- Ostrin "Six winters gone" (the father left later).
- Col "Nine years".
- Hermit "nine winters".
- Oswin's wife "went ahead the year before the Night", and he set out after.
- The grandfather argue line becomes "My father saw the Door open." / "Your father saw two of
  everything."
- The Tally leaf 1 becomes "awaiting the call, *this shelf*". Then 1,090 is one shelf and 11,004
  the crypt, and the numbers stop fighting.

**13. Names collide.**
- *Warden*: the Thornwarden is "the Warden" to the keep (`dialogue_db.gd:37,117`) and to Wyck
  (`village_talk_db.gd:216`), and then the final boss is the Ascended Warden. Around them sit the
  summit *ward*, Lantern *Ward*, Hearth*ward* and `WardSeal`.
- *Seal*: thorn seal, gallery seal, summit ward, the Ascension *Seal* item, the "seal shard" trophy
  class, and sealed barrows.
- *Os-*: Osric (the Abbot), Oswin (the pilgrim) and Ostrin (at the bar) are three of the most
  important names.
- *H*: Hesk, Hild, Hobb and Harrow.
- Objective 1, "Find the keep of the Kindled Keg" (`quest_db.gd:18`), reads as "find the castle keep".
- "Two crowns! Pay up." (`keg_scenes.gd:36`) against the Crowns (the mountains) and the Abbot's Crown.

Fix:
- NPCs say "the Thornwarden", never "the Warden"; the final boss is "Aurel" or "the Hierarch" in
  speech.
- The Ascension Seal becomes "the Door's Latch" (the desc already calls it the latch).
- Rename Oswin to "Bede" and Ostrin to "Durran Harrow" (only strings change; keep the ids).
- Objective: "Find the keeper of the Kindled Keg in Hearthward". The nameplate stays "The Keep".
- Dice line: "Two skulls! Pay up."

**14. Internal names leak into dialogue.**
- "The fen east of the Threshold brazier" (`dialogue_db.gd:183,192`; `quest_chains.gd:56`).
  "Threshold" is a node name (`realm_bosses.gd:17`) the player never sees.
- The braziers have no names in the world: the toast is "Brazier kindled. Stand in the fire. The
  dark leaves slowly." (`brazier.gd:71`).

Fix:
- Use the keep's own names: "the fen brazier, under the Ossuary's fen door".
- Name each brazier on kindling: "The Barrow Field fire burns. Two of four." The prompt stays
  "Kindle the brazier".

**15. The dwarves are unexplained, and the keep's boast breaks the timeline.**
Evidence:
- Every Keg patron and the keep are dwarves (`tavern.gd:400-410`). Hearthward's people are human
  (`villager_rig.gd:2-3`). Ostrin Harrow's family house is a human cottage in the village.
- No text mentions two peoples. LORE.md only says the keep is "a dwarf".
- "The Keg was here before the Stair" (`dialogue_db.gd:119`), while LORE says Hearthward grew at
  the road's bend in YA 100-290.

Fix: turn the boast into canon. The Keg's folk are the last of the Rooted's kin, who were here
before the road and never looked up. That explains Hesk knowing the Ring's saying, the Keg being
older than the Stair, and why the keep "serves the kindled". It makes Ostrin's mother going up
"with the bells" a convert's tragedy. Lines:
- who_1: "The Keg was here when the Rooted buried face down on that hill. My folk dug the cellar
  before anybody built a Stair to climb."
- Hesk ring_1: "My grandmother's people raised it."

**16. The enemies have no place in the fiction.**
Evidence:
- The lore says the enemies are people the gloom emptied, and ash is "the last of their warmth"
  (LORE.md; `item_db.gd:10-11`).
- In play they are a bestiary (wretch, husk, leaper, spitter, burrower, mite, chanter, bulwark)
  with no in-world identity anywhere a player can read.
- "Kill" is the verb throughout ("Kill the lot and the seal comes apart", `dialogue_db.gd:158`;
  "Kill what hunts you", `satchel.gd:203`).
- Only Father Harrow is framed as a person.

Fix:
- Add a short *What walks* tab or Relics-style entries in the Journal, one line each, written as
  folk names. For example, a mite: "Hearthward calls them lice. When a hollowed one comes apart and
  will not stop, the pieces go on looking for warmth."
- Use "put to rest" in the satchel line and in Hesk's line: "Put the lot to rest and the seal comes
  apart like wet bark."

**17. The ending gathers nothing the player did.**
Evidence:
- `end_1..end_5` (`dialogue_db.gd:127-135`) are the same for every player apart from one cosmetic
  choice.
- The quest outcomes the save already holds (Oswin home or waiting, the lantern lit or cold, Nan's
  secret, Edda's tongs, the names) are never recalled.
- Maud, the character the ending names, never appears. Her window is the obvious last image.

Fix:
- Insert a node `end_4b` with say_if over the outcomes, two lines at most:
  - `qp:slow_way:truth`: "Ostrin hasn't let the lantern go out. Says his father can see it now."
  - `qp:forty_first:truth`: "That pilgrim of yours went home. First one I ever saw."
  - fallback: "The village will want to tell you things. Let them."
- On `ending_told`, put out the candle in Maud's window (the lit-window light at `lamp_maud`) and
  let the region banner read "Hearthward / Maud's window is dark".

**18. Secrets the player finds are never reacted to.**
NPCs react to the oak, crypt, barrow and bells secrets, and to no others (grep of `secret:` in both
talk tables). Two that should get reactions:
- Pell's den slate reads "TOO MANY. GONE HOME." (`pages.gd:56`). Meanwhile the keep keeps saying
  "Pell's mother was in again" (`dialogue_db.gd:92`) and Nan asks after her.
- Hobb's cairn ("I CAN SEE HER CANDLE FROM HERE") has no line from anyone.

Fix:
- Nan, `secret:open:pell`: a choice "Pell turned back. She wrote 'gone home'." -> "...Then why
  isn't she *here*?" This also sets up Pell's return after the ending.
- Keep, news_2, `secret:open:cairn`: "You found his stones. Don't tell her. She'd go up there."

**19. One trailer card is off-canon, and the trailer never lets the world speak.**
Evidence:
- `zz/trailer.gd:77,623,667,760`: "THE SKY TURNS INWARD" is canon. "DESCEND" works with the up and
  down motif.
- "THE DARK REMEMBERS" is wrong for this world. The gloom *empties*; what remembers here is the
  wood and the fire ("the wood remembers", `lore_more.gd`).
- The tavern gets 1.4 s; not one line of the writing appears.

Fix: cards "THE SKY TURNS INWARD" / "WHAT CLIMBS COMES DOWN HOLLOW" / "DESCEND" / "UMBRAL REACHES".
Add one subtitled beat between fights, either the keep's "Fire stays. Hollows do not." or Maud's
"I did not open. I am sorry." over the lit window. A single line sells the tone better than a
fourth fight.

### Low

**20. The mechanical voice intrudes into the fiction.**
- "The thorns wither. A seal shard is yours." (`thorn_henge.gd:252`)
- "Proof the Stair is yours." (`item_db.gd:23`)
- "Whoever has read all three of us: our offering is under the ninth stone." (`lore_more.gd:13`)
- the loading hint "shown to the renderer once" (`loading_screen.gd:172`)
- "%s weakens — %d of %d guardians fallen." (`ward_seal.gd:62`)

Rewrites:
- "The thorns wither. The heart is still beating in your hand."
- "The latch is yours. Without it the door can close, if it wants to."
- Ninth Company: "If you have come this far behind us, our offering is under the ninth stone."
- Loading hints: rotate one-line lore fragments. The `rd_way_*` and `gl_*` texts are already the
  right length.
- Ward: "The thorn seal frays. Three still hold it."

**21. Glimmers have three origins.** Wenna says the keep says they are "what the lost left behind"
(jn_5); the glade stone says "only the light the sky did not swallow" (`lore_db.gd:130`); the
singing stones say the wood's lights "went looking for us" (`pages.gd:78`). That is fine as folk
disagreement, but make it deliberate. Scratch under the glade stone: "The keep says otherwise. The
keep says a lot."

**22. The valley has no name, and "Umbral Reaches" never appears in the fiction.** "Umbral" is only
a spell prefix. Fix: West Gate plaque second sentence: "Pilgrims called the valley the Reaches;
since the Night, the marches call it the Umbral Reaches." Have the keep use "the Reaches" once.

**23. The design docs have drifted from the code.**
- STORY.md's opening lines (`docs/STORY.md:11-12`) and "Only the keep and three patrons talk"
  (`:117`) are stale. Eleven villagers talk now.
- LORE.md has the placeholder "(as before)" (`:103`).
- LORE.md says "Edda's cold forge" (`:86`), but Hild keeps the forge hot.
- LORE.md's "86 writings" is now 86 + 6 + 25 secrets.
- The story canon for villagers, quests, elites and secrets lives only in code. LORE.md needs a
  "People of Hearthward" and a "Bounties" table so the next writer finds Hild, Abel, Nan, the
  Founder and Brother Lisle-as-elite.

**24. Small continuity slips.**
- Maud's candle-stub "she pinched out the night the knocking started" (`item_db.gd:31`) against
  her letter "The candle stayed lit." (`lore_db.gd`, hw_maud_3). The fix is "a stub she burned down
  the night the knocking started".
- Oswin's "Forty-one waystones" against the road's mile-stones XII..III.
- "Beds cost ash" and "The Keg has beds" have no beds behind them.
- Hesk, a woodcutter, never mentions the abbey woodsmen or the Briar Hart their cutting made
  (`elites.gd:38`). One hub line: "The camp cut the thorn. I didn't. Now there's a hart in there
  with a crown on."

---

## Top 10 to do first

1. **Stage the climax as one beat (#2):** cut the Warden toasts, stop the sky at 0, play one bell,
   hang Aurel's bell on the dais, take bells out of the explore music.
2. **Give the wanderer a stake (#1):** canonize the late pilgrim the door half-took; seed it in
   Nan, Abel, Rim Edict III and the Warden's phase 3; add the third ending choice.
3. **Stop the keep spoiling the spine (#3):** remove Aurel's name from lore_1, three_1 and Brannoc's
   meet, and let Edict III and the phase-3 bar rename reveal him.
4. **Make the Warden hold the door in play (#4):** raised arm with a thread to the sky, the phase-3
   let-go, the "AUREL, HIERARCH" bar, the seal falling from opened fingers. Name Osric and count in
   the Abbot fight.
5. **Make heart and crown a key you turn (#5):** two sockets on the ward, the carved reason, the
   true "Nothing answers" message, the Abbot objective about the crown.
6. **Fix the Deeper Night (#8):** reset the ending flags per cycle, give it its own wrong-way-up
   bell and banner, add keep and patron `ng` lines.
7. **Put text in the three boss spaces and pay off Wenna in the Ossuary (#9).**
8. **One rule for who comes back down (#6),** and rewrite end_4.
9. **Unify the bells (#7)** (the Founder is Brannoc's mother; the great bell first), and gate the
   Keg's "bell rang up" argument.
10. **Fix the canon slips players will quote:** Edda's tongs, apron and ferrule (#11), pin the
    timeline (#12), "Threshold brazier" (#14), Warden/Os- name collisions (#13).
