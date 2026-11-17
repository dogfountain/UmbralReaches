extends RefCounted
## The Far Reaches' towns' tasks (docs/far_reaches.md; the people are core/life/village/village_reach_towns.gd), in the
## quest_chains.gd manner: one const a task, listed by the shared tables in their `# --- the towns ---` blocks.
## The task verbs (docs/QUEST_VERBS.md) deepen them: clues, tracks, lantern_walk, order, vigil; a pick each task remembers
## (`qp:`), and what it leaves standing (`leaves`). The choices at a place are in the conversations the east, south and west
## files host (er_slate, ds_nail_door, wr_order: their start lists branch on the step).
##
##   rh_lamps   Boats Not Home (Aud Corle, Reedholm)     the drowned; wake-marks (tracks) to the stones, the lamp book's line (clues);
##                                                       Siany's lamp: home or lost (Aud writes it)
##   fm_tithe   The Last Tithe (Reeve Penn, Fallowmere)  three tally-pots; the sticks accuse (clues), the last is Penn's own: read or strike
##   ll_gate    The Knocking at the East Gate (Coyle)    a vigil at the shut gate, the scratches and thrown tokens (clues); open the
##                                                       postern, hold the bar, or answer (answered: Fenn's task opens early)
##   ll_oil     Oil for the Last Lamp (Old Isolde)       tallow; a taper walked to the tower (lantern_walk); the three wicks in
##                                                       order; the east wick lit or left dark
## House style (docs/LORE.md): terse, concrete, dark.

const ZONES := [["reedholm", "Reedholm"], ["fallowmere", "Fallowmere"], ["lastlight", "Lastlight"]]

const ORDER := ["rh_lamps", "fm_tithe", "ll_gate", "ll_oil"]

const GIVER_NAMES := {"corle": "Aud Corle", "penn": "Reeve Penn", "coyle": "Serjeant Coyle", "isolde": "Old Isolde",
	"hobb": "Hobb Wade", "siany": "Siany", "gorse": "Gorse", "ebba": "Ebba Sallow", "hesper": "Hesper Lark", "cobb": "Cobb Lark",
	"dilly": "Dilly", "wystan": "Brother Wystan", "vell": "Mother Vell", "fenn": "Fenn", "wat": "Wat", "maudlin": "Sister Maudlin"}

const QUESTS := {
	"rh_lamps": {"name": "Boats Not Home", "giver": "corle", "where": "Aud Corle, on the net-hall's gallery in Reedholm", "zone": "reedholm",
		"offer": true,
		"text": "Reedholm's lamp book has kept one count since the Night: boats not home by dark. Tam Wade's is the last line in it. He rowed past the heron stones for the big pike and the drowned came up out of the meres to meet him. Aud Corle wants the meres cleared enough for the boats to go out, the wake-marks followed to where each boat lay, and Tam's lamp brought back off the stones. What the book says under his line is the finder's to say: home, or lost.",
		"steps": [
			{"kind": "slay", "of": 5, "region": "reedmere", "label": "The drowned of the meres", "at": Vector2(-300.0, 340.0),
				"text": "Put down the drowned that walk the Reedmere ({n}/{of})"},
			{"kind": "tracks", "r": 12.0, "label": "The boats' wakes",
				"text": "Follow the wake-marks out of the landing to where the missing boats lay ({n}/{of})",
				"marks": [
					{"at": Vector2(-323.0, 313.0), "text": "A keel dragged through the reed-roots, wet yet, nine winters on. The Alder. Her lamp-hook is still in the mud, torn off at the bolt."},
					{"at": Vector2(-327.0, 325.0), "text": "Two more hulls' worth of flattened reed beside it, side by side, as if the Plover and the Second Wife had gone out together and neither wanted to be first."},
					{"at": Vector2(-329.0, 337.0), "text": "A pike-line, cut, trailing down into the black. The knot is Tam's: a fisher's knot with a turn too many, because he never trusted a plain one."},
					{"at": Vector2(-327.0, 346.0), "text": "The wakes end at the lowest stone. Nothing floats here. Everything that went out came to rest round one lamp-hook, as at a table."},
				]},
			{"kind": "clues", "at": Vector2(-331.0, 350.0), "r": 10.0, "need": 2, "label": "The lamp book's line",
				"text": "Read what the stones kept of Tam's last night ({n}/{of} read)",
				"clues": [
					{"key": "page", "at": Vector2(-334.0, 345.0), "prop": "page", "name": "a page nailed to a stone", "text": "A page of the lamp book, nailed to the lowest slab with a boat-nail: T. WADE. PUNT. ONE LAMP, LIT. NOT HOME. In another hand under it, smaller: lit when he left. Lit for whom?"},
					{"key": "notches", "at": Vector2(-322.0, 349.0), "name": "notches on a gunwale", "text": "A gunwale snag at the waterline, notched like a tally. Pike, pike, pike. The last notch is cut half through, as if the knife was taken from him."},
					{"key": "hook", "at": Vector2(-328.0, 357.0), "name": "the heron's beak", "text": "The heron on the nearest stone points its beak straight down at a lamp-hook wedged between two slabs. The hook is bright. Somebody has wiped it, long ago, and not the drowned."},
				]},
			{"kind": "find", "text": "Take Tam Wade's lamp from the heron stones in the south mere"},
			{"kind": "talk", "who": "siany", "text": "Hang Tam's lamp at the jetty with Siany, and say whether he is home"},
			{"kind": "turnin", "who": "corle", "text": "Tell Aud Corle what the book should say"},
		],
		"alt": {"home": {5: "Tell Aud Corle to write him home"}, "lost": {5: "Tell Aud Corle to write him lost"}},
		"reward": {"ash": 18, "items": {"grave_iron": 1}},
		"choose": [{"slot": "lantern", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
		"leaves": {"home": {"at": Vector2(-322.0, 302.5), "prop": "lantern_lit"}, "lost": {"at": Vector2(-322.0, 302.5), "prop": "lantern"}},
		"outcome": {
			"home": "Siany lit Tam's lamp from her own and hung it at the jetty's end. Aud wrote one line under his: brought home. Then she counted thirty-one, and let the lamp burn, and did not ask what it burned for.",
			"lost": "Siany hung Tam's lamp at the jetty's end and did not light it. Aud wrote one line under his: lost, and found. 'It is a different thing,' she said. 'The book can hold both.' The thirty-first hangs dark among the lit ones, and nobody has trimmed it.",
			"": "Aud wrote one line under Tam's: brought home. Then she lit the lamp from the book's own candle and hung it at the jetty with the others, and counted thirty-one."}},
	"fm_tithe": {"name": "The Last Tithe", "giver": "penn", "where": "Reeve Penn, in the tithe barn's porch at Fallowmere", "zone": "fallowmere",
		"offer": true,
		"text": "Every strip at Fallowmere owed the Order a tithe, and every tithe was cut in a tally stick and kept in a pot in its strip until the reeve came round. The reeve still comes round. Three pots are out in the drowned strips to the south, where the dead the Night left unburied keep the fields now. Penn wants the tallies back in the barn, so the roll can be read whole one last time. He has not said what is on the sticks. He has read the rest, once, and has not asked to read these.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Bring in the three tally-pots from the drowned strips ({n}/{of})"},
			{"kind": "place", "text": "Set the tallies on the tithe board in the barn's porch"},
			{"kind": "clues", "at": Vector2(-177.0, 293.0), "r": 8.0, "need": 2, "label": "The tally sticks",
				"text": "Read the sticks on the porch's board: who owed, and what ({n}/{of} read)",
				"clues": [
					{"key": "lark", "at": Vector2(-174.0, 291.0), "prop": "page", "name": "a stick cut LARK", "text": "A stick cut LARK, the notches thin: Cobb's father paid short eleven winters running. Under it, in the Order's clerk-hand: forgiven by the reeve, not by the Order."},
					{"key": "strips", "at": Vector2(-180.5, 290.5), "name": "a stick of the far strips", "text": "A stick with no name, only a strip's number. Each year's notch is a little deeper than the last, as if somebody pressed harder to keep the count from sliding off. The last is cut through the wood."},
					{"key": "penn", "at": Vector2(-177.5, 295.5), "prop": "page", "name": "a stick cut PENN", "text": "A stick cut PENN, ALDOUS. Eleven winters of tithe paid in full, and a twelfth in a different hand, the reeve's own, a little crooked: OWED. Seed corn, nine bushels, lent to the far strips against a harvest that did not come. His own line, in his own hand."},
				]},
			{"kind": "place", "text": "Read the roll out at the tithe board, and decide whether Penn's own line is read with it"},
			{"kind": "turnin", "who": "penn", "text": "Tell Reeve Penn the roll is whole"},
		],
		"alt": {"full": {4: "Tell Reeve Penn the roll was read in full"}, "strike": {4: "Tell Reeve Penn his line is struck"}},
		"reward": {"ash": 16, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "focus", "rarity": 1}, {"slot": "vestment", "rarity": 1}],
		"leaves": {"full": {"at": Vector2(-175.0, 293.5), "prop": "lantern_lit"}, "strike": {"at": Vector2(-175.0, 293.5), "prop": "slate"}},
		"outcome": {
			"full": "Penn read the roll in the porch that night, strip by strip, name by name, and his own at the last in his own voice. Brother Wystan stood at the barn door with his spade. At the last name, something in the far strips lay down. Penn left a lamp lit on the board for the rest of the night, and the porch has not been dark since.",
			"strike": "You scored the reeve's line through with the clerk's knife. Penn read the roll without it, strip by strip, name by name. At the last name something in the far strips lay down, a breath later than it should. Penn wiped the slate on the board with his sleeve and went to bed, and slept, and did not thank you.",
			"": "Penn read the roll in the porch that night, strip by strip, name by name. Brother Wystan stood at the barn door with his spade. At the last name, something in the far strips lay down."}},
	"ll_gate": {"name": "The Knocking at the East Gate", "giver": "coyle", "where": "Serjeant Coyle, at the East Gate in Lastlight", "zone": "lastlight",
		"offer": true,
		"text": "Lastlight's east gate was barred the night the sky turned and nobody has lifted a bar since. Some nights something knocks on it from the far side, slow, the way a tired pilgrim knocks. Coyle won't open the gate. He will have you stand it with him through a knocking, read what has been left at the foot of it, and put down what prowls the walls. What the gate does after that, he says, is not his to say. He will be very grateful if it stops.",
		"steps": [
			{"kind": "vigil", "at": Vector2(349.5, 62.8), "r": 6.0, "time": 40.0, "gloom": 0.5, "label": "The knocking", "noun": "gate",
				"waves": [{"at": 12.0, "kinds": ["wretch"], "n": 1, "say": "One knock. Then a pause long enough to be a question."},
					{"at": 24.0, "kinds": ["wretch"], "n": 1, "say": "Two. Slower. Whoever it is has all night."},
					{"at": 34.0, "kinds": ["husk"], "n": 1, "say": "Three. The wood does not move. The bar hums."}],
				"held": "The third knock fades into the bar. Whatever stands on the far side has not gone.", "away": "Go back to the gate. A watch is stood where it was set.",
				"text": "Stand at the East Gate and hear the knocking out: three, slow ({t} s)"},
			{"kind": "clues", "at": Vector2(348.5, 64.0), "r": 8.0, "need": 2, "label": "What was thrown over",
				"text": "Read what the gate's foot keeps: scratches and the things thrown over ({n}/{of} read)",
				"clues": [
					{"key": "scratch", "at": Vector2(347.0, 61.0), "name": "scratches on the gate", "text": "Tally scratches low on the inside planks, in fives. Whoever made them stood on the inside. They are older than the Night by three years, and the bar is newer than the scratches."},
					{"key": "token", "at": Vector2(347.5, 66.5), "prop": "mark", "name": "a pewter token", "text": "A Last Lamp token, pewter, thrown over the gate from outside and landed in the gutter. A night's bed, owed, never claimed. Somebody has been paying the inn by throwing it back."},
					{"key": "shoe", "at": Vector2(351.0, 66.0), "name": "a child's shoe", "text": "A child's shoe, on its side against the gate's foot. No child here is small enough to be its owner. The sole is worn through on the left, as by a long walk toward a closed door."},
				]},
			{"kind": "slay", "of": 6, "region": "lastlight,bellfall", "label": "Whatever knocks", "at": Vector2(300.0, -10.0),
				"text": "Put down what prowls round Lastlight's walls and up the Bellfall track ({n}/{of})"},
			{"kind": "place", "text": "Decide the bar: lay your hand on it and say what the gate does"},
			{"kind": "turnin", "who": "coyle", "text": "Tell Serjeant Coyle what you did at the gate"},
		],
		"alt": {"open": {4: "Tell Serjeant Coyle the postern was opened"}, "hold": {4: "Tell Serjeant Coyle the bar held"}, "answer": {4: "Tell Serjeant Coyle you answered"}},
		"reward": {"ash": 20},
		"choose": [{"slot": "girdle", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"leaves": {"open": {"at": Vector2(348.5, 66.5), "prop": "lantern"}, "hold": {"at": Vector2(348.5, 66.5), "prop": "cairn"}, "answer": {"at": Vector2(348.5, 66.5), "prop": "slate"}},
		"outcome": {
			"open": "You lifted the postern's latch for the length of a breath and let the dark come to the sill. Nothing stepped over it. A cold lamp stands on the step where it stopped. Coyle checked the bars, the chain and the portcullis, and then he did it again, and left the postern's latch off its hook for the rest of the night.",
			"hold": "You held the bar and the knocking stopped at the fourth knock, in the middle of it, like a hand lifted off. Coyle sat on the gate's step with his back to it, which nobody in Lastlight had seen him do. A cairn stands at the gate's foot now, and nobody has asked who built it.",
			"answer": "You said a word through the planks. Four, as it turned out: the same four a man says on the Nave's shore every night. The knocking stopped, and there is a name chalked on a slate by the gate that was not there before, in your hand. Coyle read it twice and did not rub it out.",
			"": "Coyle checked the bars, the chain and the portcullis, and then he did it again. Then he sat on the gate's step with his back to it, which nobody in Lastlight had seen him do."}},
	"ll_oil": {"name": "Oil for the Last Lamp", "giver": "isolde", "where": "Old Isolde, at the lamp tower in Lastlight", "zone": "lastlight",
		"offer": true, "avail": "met:isolde",
		"text": "The salt carters brought the lamp-oil, and the carters have stopped. Isolde has been burning the inn's tallow and the shrine's candles, and those are nearly done. The pilgrims who drowned in the unfinished cathedral to the south carried candles up the road and never burned them. They hold them still. She wants the tallow, and a taper lit at the Nave's own fire carried up to the tower without a run, and then the tower's three wicks lit in the order the road comes: the west wick for the road, the south for the Nave, the east last.",
		"steps": [
			{"kind": "collect", "of": 4, "chance": 0.6, "region": "nave", "label": "Pilgrims' tallow", "at": Vector2(318.0, 162.0),
				"text": "Take the pilgrims' tallow off the drowned of the Nave ({n}/{of})"},
			{"kind": "find", "text": "Light a taper at the fire on the Nave's north shore"},
			{"kind": "lantern_walk", "from": "ll_nave_flame", "to": Vector2(347.4, 59.0), "r": 6.0, "label": "The lamp tower",
				"relight": "Light another at the Nave's fire.",
				"arrive": "You hold the taper to the tower's foot. It takes the draught of the stair and stands straight. The tallow rides heavy in your pack.",
				"text": "Carry the lit taper up to the lamp tower at Lastlight. Walk it: a run, a roll, a blow or deep water puts it out"},
			{"kind": "order", "at": Vector2(347.4, 56.0), "label": "The tower's three wicks",
				"text": "Light the tower's three wicks in the order the road comes, as Isolde taught: west, south, east",
				"things": [
					{"key": "west", "at": Vector2(343.4, 54.0), "prop": "lantern", "name": "the west wick", "verb": "Light", "text": "The west wick takes. The road to the pans, and the carters who will not come, light up under it."},
					{"key": "south", "at": Vector2(347.4, 59.5), "prop": "lantern", "name": "the south wick", "verb": "Light", "text": "The south wick takes, a low yellow. For the Nave, and everyone who held a candle in it."},
					{"key": "east", "at": Vector2(351.6, 57.5), "prop": "lantern", "name": "the east wick", "verb": "Light", "text": "The east wick takes, and leans hard toward the shut gate, as if something on the other side were drawing on it."},
				],
				"order": ["west", "south", "east"],
				"wrong": "The wick gutters and the whole tower dims a breath. Isolde's voice, from above and a long way off: 'The road comes from the west.' Begin again.",
				"done": "West, south, east. The tower holds its breath, and its light comes up white."},
			{"kind": "place", "text": "Decide the east wick: leave it lit for the gate, or leave it dark"},
			{"kind": "turnin", "who": "isolde", "text": "Bring the tallow to Old Isolde at the lamp tower"},
		],
		"alt": {"lit": {5: "Tell Old Isolde all three wicks are lit"}, "dark": {5: "Tell Old Isolde the east wick is dark"}},
		"reward": {"ash": 18, "items": {"ember_shard": 2}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 1}],
		"leaves": {"lit": {"at": Vector2(353.5, 59.5), "prop": "lantern_lit"}, "dark": {"at": Vector2(353.5, 59.5), "prop": "lantern"}},
		"outcome": {
			"lit": "Isolde rendered the tallow in the tower's own kettle and climbed with it, all hundred and twelve steps, without stopping. The lamp went white for an hour, and the east wick burned with it, leaning at the gate. Fenn on the road gate swore he could see his shadow on the Crowns, and then, a little later, that something on the far side of the gate could see it too.",
			"dark": "Isolde rendered the tallow in the tower's own kettle and climbed with it, all hundred and twelve steps, without stopping. She trimmed the east wick low and left it unlit, and the lamp went white on two sides only. 'It is a light for the road,' she said. 'The gate has had its share.' Fenn on the road gate swore he could see his shadow on the Crowns, and nothing at all on the gate's side.",
			"": "Isolde rendered the tallow in the tower's own kettle and climbed with it, all hundred and twelve steps, without stopping. The lamp went white for an hour. Fenn on the road gate swore he could see his shadow on the Crowns."}},
}

const PICKUPS := {
	"rh_tam_lamp": {"quest": "rh_lamps", "step": 3, "near": Vector2(-326.0, 352.0), "kind": "lantern", "name": "Tam Wade's lamp", "verb": "Take",
		"say": "A boat's lamp on a hook of iron, wedged in the reeds where the channel runs between two of the stones. Cold. T.W. cut in the brass of the hood. On the stone above it the heron's beak points straight down at it."},
	"fm_tally_a": {"quest": "fm_tithe", "step": 0, "near": Vector2(-118.0, 346.0), "kind": "page", "name": "a tally-pot", "verb": "Take",
		"say": "A clay pot sunk to its lip in the strip, a bundle of notched hazel sticks in it. Eleven winters of notches, then a stick with no notches at all, and a name cut on it instead."},
	"fm_tally_b": {"quest": "fm_tithe", "step": 0, "near": Vector2(-134.0, 362.0), "kind": "page", "name": "a tally-pot", "verb": "Take",
		"say": "The pot is cracked and the sticks inside are black with the wet. Someone has re-cut the notches with a fingernail, deep, over and over, as though the count had to be kept by any hand at all."},
	"fm_tally_c": {"quest": "fm_tithe", "step": 0, "near": Vector2(-108.0, 366.0), "kind": "page", "name": "a tally-pot", "verb": "Take",
		"say": "The last pot, in the far strip under a scarecrow that faces the wrong way. Its sticks are new. Somebody has been keeping the tally since the reeve stopped coming this far."},
	"fm_tally_place": {"quest": "fm_tithe", "step": 1, "near": Vector2(-176.4, 291.6), "kind": "place", "name": "the tithe board", "verb": "Set the tallies on",
		"say": "You lay the three bundles on the board in the porch, beside eleven winters of others. The barn is very quiet. From the dark of it comes the smell of seed corn, and nothing else, which is the right answer."},
	"fm_roll": {"quest": "fm_tithe", "step": 3, "near": Vector2(-179.0, 292.6), "kind": "place", "name": "the roll", "verb": "Read out", "conv": "ds_nail_door",
		"say": "The roll."},
	"ll_bar": {"quest": "ll_gate", "step": 3, "near": Vector2(349.0, 64.5), "kind": "place", "name": "the gate's bar", "verb": "Put your hand on", "conv": "er_slate",
		"say": "The gate's bar."},
	"ll_nave_flame": {"quest": "ll_oil", "step": 1, "near": Vector2(297.5, 110.5), "kind": "lantern_lit", "name": "a taper at the Nave's fire", "verb": "Light",
		"say": "You hold a taper of pilgrim's tallow to the fire on the Nave's north shore until it takes. The flame leans toward Lastlight, as if it knew the way and was in a hurry."},
	"ll_wick": {"quest": "ll_oil", "step": 4, "near": Vector2(353.5, 58.5), "kind": "place", "name": "the east wick", "verb": "Tend", "conv": "er_slate",
		"say": "The east wick."},
}
