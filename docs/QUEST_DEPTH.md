# Quest depth (17 Nov)

Luke: "As a story designer review the game, quests should be more in depth and meaningful with more unique things
to do." The story designer's review and the plan the writers build from. New verbs: docs/QUEST_VERBS.md
(clues, tracks, lantern_walk, order, vigil). Existing systems and in-house assets only; content is thin, so
reshape or add, never cut; the five dailies stay.

## The critique

The prose is strong; the structure is one beat and a hand-in, and the choices are gear.

- **Verbs.** Of ~390 steps in 119 quests: turnin 114, find 58, slay 48, visit 28, cond 28, carry 19, place 18,
  gather 17, collect 9, defend 6, talk 6, escort 4, seal 3. 114 of 119 end by walking back to the giver; 81 are three
  steps or fewer; 48 are only slay / collect / gather / find and a hand-in. Nothing is examined, followed, watched
  over or done in an order.
- **Repetition.** "Something named walks the ground at night, put it down" is holds_turf, quarry_chisel,
  moor_hennet, orchard_pippin, mere_ferryman, field_last, founder_clapper and the eight bell keepers. The seven r34
  countries share one template (a slay, a gather, a visit-and-slay, a carry, a rare, a daily). "Carry a lit thing
  before it dies" is 19 quests that play the same.
- **Choices.** 101 quests offer a `choose`, all gear picks. Ten carry a real story pick (edda_tongs, forty_first,
  keg_thief, names_yard, slow_way, the_latch, pans_hauler, wr_stand_down, ds_witchs_price, er_inn_slate) and it pays
  off as one `say_if` line. No pick changes another quest's availability, a step, a boss line or a prop.
- **Characters.** The long runs (Agathe 9, Ysolt / Jory / Cadoc 8, Ruan / Linnet / Elspeth 7) are the template, not
  arcs. Hearthward's people have almost none (Hild, Nan, Harrow, Hesk 1 each); Maud, Wenna, Pell, Col and Bet have
  none. LORE.md's best material has no quest: Maud's three knocks, Wenna's journal, the Ninth Company, Lisle's
  Tally, Corvin's rite, the Song of the Ring, "One is still on the Stair".
- **The story.** Tasks sit beside it: only names_under, the_latch, full_peal and the attunements touch the door.
  None changes a boss line or the ending. 118 of 119 pay ash; no reward opens a place, a door or a person's place.

Consequences need no new engine: `qp:`, `qd:` and `att:` in a later quest's `avail`, a hub `say_if`, a `stands`
prop chosen by the pick, and the keep's `news_2` and `end_4b`.

## The plan: 30 quests deepened

Verbs: **C** clues, **T** tracks, **L** lantern_walk, **O** order, **V** vigil.

| id | giver | becomes (beats in order) | choice -> what it changes later |
|---|---|---|---|
| **A: Hearthward, Keg, Thornwood, fen, Ossuary** | | | |
| keg_thief | keep | T ale-drops from the back keg to the green; C mug-ring, chalk circle, small boot-print; ask Nan | told / covered / rats (exists) -> told: Nan tells the keep next; covered: the circle stays as a prop and Nan offers alms_loaf as a debt; rats: the trap catches Fennick's boot |
| names_yard | abel | C each slate's hiding place says who hid it (Maren Coyle, Tam, Sister Ide); cut them at the Yard | confess / deep -> which names the Yard keeps; Lastlight's Serjeant Coyle asks after "Maren" |
| forty_first | oswin | T Oswin's chalk waystones west along the road; find him at stone 40; escort | truth / faith -> faith: stone 41 is a lit post; truth: threshold_chapel reads "go home" |
| slow_way | harrow | T lamp-oil drips and bare prints down the fen; lay the hollowed man to rest; L the lantern lit round the fen's water to the Keg | truth / mercy -> truth: Ostrin trims it on the counter; mercy: he walks it to the fen fire and his stool stays empty |
| spire_lamps | fennick | climb the Spire; V hold its cold lamp while the sky turns once | tell Fennick "out" or "burning" (Fennick's arc) |
| ring_heart | wyck | C the four Song-of-the-Ring stones; O touch them in verse order (wrong wakes a thorn); boss | nobody's / a Rooted's heart -> Wyck's burial words, Ruan's keeper_leave hub |
| bead_count | abel | C the beads' numbers against the Tally posts; judge: is Lisle one of them? | add Lisle / strike him -> the Yard stone, Agathe's roll, the count the Abbot calls (1090 or 1089) |
| drowned_bell | brannoc | L wade to the belfry (swimming puts it out: go round by the causeway); take the tongue | keep it / hang it back -> full_peal text, Brannoc's bench |
| unpaid_toll | hesk | T bell-rope drag marks to the axe; C three axe-marks; fight | the axe to Hild / to the brother's cairn -> Hild's line, the Ruan reconciliation |
| **B: the seven countries and the Marches** | | | |
| quarry_last | jory | C three tool-marks on the 4001st block, one unfinished Q-with-a-tail; judge | read Jory the prayer / the mark -> cutters_pledge outcome |
| moor_shrine | ysolt | L a hooded flame along the cairns at walking pace | leave it burning (defy the edict) / snuff it, carry the wick home -> moor_niches; the shrine lit or dark |
| mere_light | cadoc | L ferry-lamp to the chapel; O light eyes, mouth, heart (Corvin's rite; wrong wakes the nave) | the third light for Aldous / for the sunk -> mere_ferryman (Cadoc's arc) |
| orchard_press | linnet | C burnt casks, a Kindler's initials, a pot of coals; accuse | the Order / her grandmother's coal -> Linnet's lines, the old tree |
| field_ranks | agathe | V the stones turn at night; hold the head of the ranks until they stop | face them to the mountain / the gate -> still_climbing, the Landing's pilgrims |
| spire_coal | ardel | after the lamp is lit, V the lake road's lanterns answer one by one | "it is lit" / "it is kept" -> bell_spire; lanterns stand |
| salt_widow | marl | T two sets of prints, hers dragging; C Corra Vane's rake and ring | lay the rake at her feet (no fight) / put her down -> the second grave stone; Marl's lines |
| shepherd_strays | dunstan | O raise the three cairns in the flock's fog order; T strays to the Bell-Wether | put it down / ring its bell at the fold -> drover_tally |
| oak_song | ruan | O sing the oak's knots in Ruan's order (wrong wakes the Root-Wife); climb | alone / with Ruan's words -> Ruan's line (Rooted arc) |
| well_answer | cadoc | C three marks on the ledge; V hold it while the Answerer calls in Cadoc's voice | put it down / answer with a name -> Cadoc sleeps or still hears it |
| wf_lights | ennis | T drift lines to each votive boat; place; V at the drowned shrine while they gutter | name the three missing / leave them nameless -> Ennis's line, a stands prop |
| wf_crown | tolliver | the rubbings become C; judge the boy who held the note | silence the Crown / let the note end -> plinth_lamp |
| **C: the Far Reaches** | | | |
| rh_lamps | corle | T wake-marks to each missing boat; C its lamp-book line | write "home" or "lost" -> wr_stand_down hub |
| wr_fourth_stone | hobb | the puzzle becomes O; V wait for the fourth bird | the oar for Tam / for Hodge -> Hodge's line |
| fm_tithe | penn | C three tally sticks accuse, the last one Penn himself | read the roll in full / strike his own line -> Penn's water_road line, the reeve's coat in ds_unmade |
| ds_unmade | dilly | C coat seams, a chalk face that is Dilly's; T chalk lines down the strips | turn him to the road / burn the coat -> Penn's reply |
| ds_witchs_price | hesper | T burners' marks through the Southwood; C three older nails | bread / strips / nothing -> the price shows later (a stands prop) |
| er_ringers_candle | maudlin | L the candle; C the Ringers' Cairn shows which rope each pulled | set it / douse it at the Nave step -> er_nave_fire, the Rope signature |
| ll_gate | coyle | V hold the shut gate while the knocking comes (three, slow); C scratches and tokens thrown over | open the postern / hold / answer -> who offers er_nave_fire |
| er_inn_slate | vell | C the tokens' debtors (Maren Coyle's, a Vell's, a stranger's) | wipe / keep / PAID + forgive the stranger -> the slate's text |
| ll_oil | isolde | L the oil to the tower without sprinting; O light the three wicks in order | all three / leave one dark -> the east road's lights |

## Five arcs

- **Brannoc, the bells:** drowned_bell -> founders_peal -> the_latch -> full_peal. He cast the Hierarch's great bell;
  his tongue choices pay into the latch; at the last he rings the peal at the Keg; a bell hangs over the Keg door.
- **Fennick, the lamp round:** coal_shrine -> spire_lamps (vigil) -> long_round. He shut the gate on the Warden's
  word and has lit the road for those he shut out; the payoff, he lights the gate lantern himself at the ending.
- **Ruan and Hesk, the Rooted come home:** holds_turf -> keeper_wards -> oak_song (order) -> unpaid_toll. Ruan is
  Hesk's grandmother's sister; each returns a door-stone or an axe; she moves her fire, Hesk's stool grows a second.
- **Cadoc, the last crossing:** mere_light (order) -> mere_ferryman -> well_answer (vigil) -> mere_ferry. The rite
  answers the Abbot's three stones; the ferry-lamps burn at both landings and Cadoc finally rows out.
- **Aud Corle, the lamp book:** rh_lamps -> wr_stand_down -> Relief. Reedholm's lamps go out one by one as the
  missing are named home; she writes the Sentry's name; the last page is blank on purpose.

## Six signature quests (new)

1. **Hearthward, "Three Knocks"** (Old Maud): C her three unsent letters; V her back door through the night as the
   knocks come and the Gloom rises. Open (Hobb lies down by her fire), leave it shut (her candle goes out at the
   ending), or answer in her voice (a gentler news_2 and end_4b).
2. **The Realm, "Forty Days Late"** (the Ninth Company): T their stakes from the rim edict to the Thornwood camp;
   C the burned tokens, one unburned. Bury it or carry it, never explained; carried, the ending has a line ("One is
   still on the Stair").
3. **The Marches, "The Seventh Day"** (Teasel, Wren's cell): C Wren's slate and cell; V seven minutes at night in
   the cell, door shut; a bell. Tell Teasel it was the Shut-Out Bell or the door: she walks to the Spire or stays.
4. **West Reach, "Relief"** (after wr_stand_down): V the Sentry's watch at the Signal Cairn; he sits down at dawn.
   Salute and stand down, or keep the watch: the Greyfell's camps go quiet or stay. Corle writes his name.
5. **South Reach, "A Night of Charcoal"** (Hob's Stack; Penn): V tend the clamp through the night; L the charcoal
   lit to the Fallow Beacon, relighting the Water Road. Spare the Last Charcoal-Burner (he keeps the beacons) or not.
6. **East Reach, "The Rope Rung Right"** (Maudlin, the Nave's shore): C the ringers' rope-marks; O ring bottom to
   top (wrong wakes the Bell-Rope Nun). Lowest first (the ringers rest) or highest (it breaks): Maudlin turns to
   face the road; a pilgrim comes up the east road.

## Workstreams (disjoint files)

Before the writers: the r34 countries' quests move out of quest_chains.gd into quest_chains_countries.gd, the
countries' CONV block into village_talk_countries.gd, and quest_chains_deepen_a/b/c.gd are registered in the
merges. Cross-stream reactions read `qd:` / `qp:` only. Name collisions: Wren (Teasel's sister; the Weirford giver is Sedge),
Amos (Cadoc's ferryman; Reeve Aldous Penn keeps Aldous).

| WS | Owns | Quests | Signatures |
|---|---|---|---|
| A | quest_chains.gd (Hearthward, Keg, Thornwood, fen, Ossuary entries), quest_chains_threshold.gd, quest_chains_deepen_a.gd, dialogue_db.gd, village_talk_db.gd | keg_thief, names_yard, forty_first, slow_way, spire_lamps, ring_heart, bead_count, drowned_bell, unpaid_toll | Three Knocks, Forty Days Late |
| B | quest_chains_countries.gd, the signature / bells / sky_chain / marches / star_crater / upward_falls / r38 chain files, quest_chains_deepen_b.gd, village_talk_countries.gd, village_east_marches.gd, village_talk_west_marches.gd | quarry_last ... wf_crown (12) | The Seventh Day |
| C | quest_chains_far_reaches_*.gd, quest_chains_reach_towns.gd, quest_chains_deepen_c.gd, village_reach_towns.gd | rh_lamps ... ll_oil (9) | Relief, A Night of Charcoal, The Rope Rung Right |
