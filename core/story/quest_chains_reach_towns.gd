extends RefCounted
## The Far Reaches' towns' tasks (docs/far_reaches.md; the people are core/life/village/village_reach_towns.gd), in the
## quest_chains.gd manner: one const a task, listed by the shared tables in their `# --- the towns ---` blocks.
## Existing step kinds only (slay, collect, gather, place, visit, find, turnin).
##
##   rh_lamps   Boats Not Home (Aud Corle, Reedholm)     the drowned in the meres; the lost boat's lamp at the heron stones
##   fm_tithe   The Last Tithe (Reeve Penn, Fallowmere)  three tally-pots in the drowned strips, set back in the barn's porch
##   ll_gate    The Knocking at the East Gate (Serjeant Coyle, Lastlight)   listen at the gate; what knocks, outside it
##   ll_oil     Oil for the Last Lamp (Old Isolde, Lastlight)   pilgrims' tallow off the drowned of the Nave
## House style (docs/LORE.md): terse, concrete, dark.

const ZONES := [["reedholm", "Reedholm"], ["fallowmere", "Fallowmere"], ["lastlight", "Lastlight"]]

const ORDER := ["rh_lamps", "fm_tithe", "ll_gate", "ll_oil"]

const GIVER_NAMES := {"corle": "Aud Corle", "penn": "Reeve Penn", "coyle": "Serjeant Coyle", "isolde": "Old Isolde",
	"hobb": "Hobb Wade", "siany": "Siany", "gorse": "Gorse", "ebba": "Ebba Sallow", "hesper": "Hesper Lark", "cobb": "Cobb Lark",
	"dilly": "Dilly", "wystan": "Brother Wystan", "vell": "Mother Vell", "fenn": "Fenn", "wat": "Wat", "maudlin": "Sister Maudlin"}

const QUESTS := {
	"rh_lamps": {"name": "Boats Not Home", "giver": "corle", "where": "Aud Corle, on the net-hall's gallery in Reedholm", "zone": "reedholm",
		"offer": true,
		"text": "Reedholm's lamp book has kept one count since the Night: boats not home by dark. Tam Wade's is the last line in it. He rowed past the heron stones for the big pike and the drowned came up out of the meres to meet him. Aud Corle wants the meres cleared enough for the boats to go out, and Tam's lamp brought back off the stones, so the book can close his line.",
		"steps": [
			{"kind": "slay", "of": 5, "region": "reedmere", "label": "The drowned of the meres", "at": Vector2(-300.0, 340.0),
				"text": "Put down the drowned that walk the Reedmere ({n}/{of})"},
			{"kind": "find", "text": "Take Tam Wade's lamp from the heron stones in the south mere"},
			{"kind": "turnin", "who": "corle", "text": "Bring the lamp to Aud Corle in Reedholm"},
		],
		"reward": {"ash": 18, "items": {"grave_iron": 1}},
		"choose": [{"slot": "lantern", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
		"outcome": {"": "Aud wrote one line under Tam's: brought home. Then she lit the lamp from the book's own candle and hung it at the jetty with the others, and counted thirty-one."}},
	"fm_tithe": {"name": "The Last Tithe", "giver": "penn", "where": "Reeve Penn, in the tithe barn's porch at Fallowmere", "zone": "fallowmere",
		"offer": true,
		"text": "Every strip at Fallowmere owed the Order a tithe, and every tithe was cut in a tally stick and kept in a pot in its strip until the reeve came round. The reeve still comes round. Three pots are out in the drowned strips to the south, where the dead the Night left unburied keep the fields now. Penn wants the tallies back in the barn, so the roll can be read whole one last time.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Bring in the three tally-pots from the drowned strips ({n}/{of})"},
			{"kind": "place", "text": "Set the tallies on the tithe board in the barn's porch"},
			{"kind": "turnin", "who": "penn", "text": "Tell Reeve Penn the roll is whole"},
		],
		"reward": {"ash": 16, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "focus", "rarity": 1}, {"slot": "vestment", "rarity": 1}],
		"outcome": {"": "Penn read the roll in the porch that night, strip by strip, name by name. Brother Wystan stood at the barn door with his spade. At the last name, something in the far strips lay down."}},
	"ll_gate": {"name": "The Knocking at the East Gate", "giver": "coyle", "where": "Serjeant Coyle, at the East Gate in Lastlight", "zone": "lastlight",
		"offer": true,
		"text": "Lastlight's east gate was barred the night the sky turned and nobody has lifted a bar since. Some nights something knocks on it from the far side, slow, the way a tired pilgrim knocks. Coyle won't open the gate. He will let you out the postern to find what knocks, and he will be very grateful if it stops.",
		"steps": [
			{"kind": "visit", "at": Vector2(351.0, 62.8), "r": 5.0, "text": "Stand at the East Gate and listen"},
			{"kind": "slay", "of": 6, "region": "lastlight,bellfall", "label": "Whatever knocks", "at": Vector2(300.0, -10.0),
				"text": "Put down what prowls round Lastlight's walls and up the Bellfall track ({n}/{of})"},
			{"kind": "turnin", "who": "coyle", "text": "Tell Serjeant Coyle the knocking has stopped"},
		],
		"reward": {"ash": 20},
		"choose": [{"slot": "girdle", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"": "Coyle checked the bars, the chain and the portcullis, and then he did it again. Then he sat on the gate's step with his back to it, which nobody in Lastlight had seen him do."}},
	"ll_oil": {"name": "Oil for the Last Lamp", "giver": "isolde", "where": "Old Isolde, at the lamp tower in Lastlight", "zone": "lastlight",
		"offer": true, "avail": "met:isolde",
		"text": "The salt carters brought the lamp-oil, and the carters have stopped. Isolde has been burning the inn's tallow and the shrine's candles, and those are nearly done. The pilgrims who drowned in the unfinished cathedral to the south carried candles up the road and never burned them. They hold them still.",
		"steps": [
			{"kind": "collect", "of": 4, "chance": 0.6, "region": "nave", "label": "Pilgrims' tallow", "at": Vector2(318.0, 162.0),
				"text": "Take the pilgrims' tallow off the drowned of the Nave ({n}/{of})"},
			{"kind": "turnin", "who": "isolde", "text": "Bring the tallow to Old Isolde at the lamp tower"},
		],
		"reward": {"ash": 18, "items": {"ember_shard": 2}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 1}],
		"outcome": {"": "Isolde rendered the tallow in the tower's own kettle and climbed with it, all hundred and twelve steps, without stopping. The lamp went white for an hour. Fenn on the road gate swore he could see his shadow on the Crowns."}},
}

const PICKUPS := {
	"rh_tam_lamp": {"quest": "rh_lamps", "step": 1, "near": Vector2(-326.0, 352.0), "kind": "lantern", "name": "Tam Wade's lamp", "verb": "Take",
		"say": "A boat's lamp on a hook of iron, wedged in the reeds where the channel runs between two of the stones. Cold. T.W. cut in the brass of the hood. On the stone above it the heron's beak points straight down at it."},
	"fm_tally_a": {"quest": "fm_tithe", "step": 0, "near": Vector2(-118.0, 346.0), "kind": "page", "name": "a tally-pot", "verb": "Take",
		"say": "A clay pot sunk to its lip in the strip, a bundle of notched hazel sticks in it. Eleven winters of notches, then a stick with no notches at all, and a name cut on it instead."},
	"fm_tally_b": {"quest": "fm_tithe", "step": 0, "near": Vector2(-134.0, 362.0), "kind": "page", "name": "a tally-pot", "verb": "Take",
		"say": "The pot is cracked and the sticks inside are black with the wet. Someone has re-cut the notches with a fingernail, deep, over and over, as though the count had to be kept by any hand at all."},
	"fm_tally_c": {"quest": "fm_tithe", "step": 0, "near": Vector2(-108.0, 366.0), "kind": "page", "name": "a tally-pot", "verb": "Take",
		"say": "The last pot, in the far strip under a scarecrow that faces the wrong way. Its sticks are new. Somebody has been keeping the tally since the reeve stopped coming this far."},
	"fm_tally_place": {"quest": "fm_tithe", "step": 1, "near": Vector2(-176.4, 291.6), "kind": "place", "name": "the tithe board", "verb": "Set the tallies on",
		"say": "You lay the three bundles on the board in the porch, beside eleven winters of others. The barn is very quiet. From the dark of it comes the smell of seed corn, and nothing else, which is the right answer."},
}
