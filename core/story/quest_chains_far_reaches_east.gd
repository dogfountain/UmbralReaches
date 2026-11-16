extends RefCounted
## The East Reach's tasks (docs/far_reaches.md "The Reaches' tasks"; data only, no class_name; quest_chains.gd lists each in the
## blocks marked `# --- the reaches ---`). Lastlight's people give and close them; they carry the wanderer from the walled
## waystation to the Bellfall, the Drowned Nave and the Thousand Cairns. Existing step kinds only; every step names a place.
##   er_ringers_candle  The Candle for the Ringers (Sister Maudlin)  MAIN: a shrine candle carried to the Bellfall, the Cracked Tollman,
##                                                                   and the Nave's west door (the dungeon hook: HOOKS.drowned_nave)
##   er_nave_fire       The One at the Nave Fire (Fenn)              after the candle: walk the man at the Nave's fire home by the road
##                                                                   (an escort), to the shrine at Lastlight
##   er_halter_bell     The Bell on the Bridle (Wat)                 a mare's halter-bell carried south to the Cairn Tower, against the clock
##   er_inn_slate       The Last Lamp's Slate (Mother Vell)          the inn's tokens off the turned-back; the One Who Counted; the slate: a choice
## House style: terse, concrete, dark.

const ZONE := ["eastreach", "The East Reach"]

## Where a thread ends at a dungeon's entrance (see the west file's HOOKS).
const HOOKS := {
	"drowned_nave": {"quest": "er_ringers_candle", "step": 3, "at": Vector2(300.0, 154.0), "r": 14.0, "cond": "q:er_ringers_candle:3", "done": "qd:er_ringers_candle"},
}

const QUESTS := {
	"er_ringers_candle": {"name": "The Candle for the Ringers", "giver": "maudlin", "zone": "eastreach", "offer": true,
		"where": "Sister Maudlin, at the pilgrims' shrine in Lastlight",
		"text": "Sister Maudlin has knelt at the shrine nine winters, facing the shut gate. Her brother Tobin rang the lowest rope on the Stair, and when the sky turned the bells stopped top first, and the ringers on the bottom ropes came down the road to Lastlight and knocked. Coyle's father barred the gate. Maudlin keeps one candle for them that is never allowed to burn out, and she has begun to doubt it is lit for the right ones.",
		"steps": [
			{"kind": "find", "text": "Take Maudlin's candle from the shrine"},
			{"kind": "carry", "from": "er_candle", "to": Vector2(322.0, 100.0), "r": 8.0, "time": 120.0, "label": "Maudlin's candle",
				"lost": "The candle has gone out on the road. Maudlin will light another from the shrine.",
				"text": "Carry the candle out by the road gate and down to the Bellfall's west lip before it burns out ({t} s)"},
			{"kind": "slay", "of": 1, "rares": ["cracked_tollman"], "at": Vector2(352.0, 119.0), "label": "The Cracked Tollman",
				"text": "Put down the Cracked Tollman, who rings the Ringers back to their rope, on the crater's south rim"},
			{"kind": "place", "text": "Set the candle on the step of the Drowned Nave's west door, down nave_track"},
			{"kind": "turnin", "who": "maudlin", "text": "Tell Sister Maudlin what answered at the Nave"},
		],
		"reward": {"ash": 40, "items": {"relic_fragment": 2, "ember_shard": 1}},
		"choose": [{"set": "bell", "slot": "lantern", "rarity": 3}, {"set": "bell", "slot": "focus", "rarity": 3}, {"set": "bell", "slot": "vestment", "rarity": 3}],
		"stands": {"at": Vector2(350.5, 58.0), "kind": "lantern_lit"},
		"outcome": {"": "Maudlin heard it out on her knees, and when you had finished she put the candle's horn cup in your hand and closed your fingers on it. 'Tobin rang the lowest rope,' she said. 'He would not have stopped for a gate. He would have gone on to ring whatever there was.' She turned, on her knees, away from the east for the first time in nine winters, toward the road they had come in by. 'Tell Coyle I will not be facing it,' she said. 'Tell him I will be listening for the other way.'"}},
	"er_nave_fire": {"name": "The One at the Nave Fire", "giver": "fenn", "zone": "eastreach", "offer": true, "avail": "qd:er_ringers_candle",
		"where": "Fenn, on the road gate at Lastlight",
		"text": "Fenn says the knocking is not the only sound at night. When the wind is from the south a man's voice comes up the nave road and says the same four words, and when the wind drops Fenn can hear him sitting by the fire on the Nave's north shore. He is not hollow, Fenn says; the hollow do not sit at a fire. He just will not walk the last hundred yards.",
		"steps": [
			{"kind": "visit", "at": Vector2(296.0, 112.0), "r": 10.0, "label": "The Nave's north-shore fire", "text": "Go down nave_track to the fire on the Nave's north shore and sit down by the man who is waiting at it"},
			{"kind": "escort", "at": Vector2(346.0, 57.0), "label": "Tobin", "hp": 24.0,
				"path": [Vector2(296.0, 114.0), Vector2(295.0, 102.0), Vector2(292.0, 90.0), Vector2(294.0, 78.0), Vector2(298.8, 69.6), Vector2(306.0, 68.2), Vector2(332.0, 64.8), Vector2(346.0, 57.0)],
				"ambush": {2: {"kinds": ["wretch"], "n": 2}, 3: {"kinds": ["wretch", "husk"], "n": 2}},
				"rig": {"seed": 7915, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "hair": "short", "beard": "short", "l": "lantern"},
				"text": "Walk Tobin up nave_track to Lastlight's road gate and on to the shrine; keep off him what rises on the road"},
			{"kind": "turnin", "who": "maudlin", "text": "Tell Sister Maudlin who is at her shrine"},
		],
		"reward": {"ash": 28, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"": "Tobin knelt beside his sister at the shrine and did not speak, and she did not turn her head. They stayed like that until the lamp tower's light went white at midnight. In the morning there were two stubs in the horn cup, and Coyle, who had opened the postern for them without being asked and shut it again after, said only that a bar was a bar and a postern was a postern, and that the law of Lastlight had always been the first and had never once forbidden the second."}},
	"er_halter_bell": {"name": "The Bell on the Bridle", "giver": "wat", "zone": "eastreach", "offer": true,
		"where": "Wat, at the stable in Lastlight",
		"text": "Nine winters ago a grey mare came back to Wat's stable with nobody on her and a brass bell on her bridle that was not Wat's, a name cut in the brass. She has stood in the stall since, and every night at the second bell she goes to the door and waits to be let out. Wat does not let her out. He wants the bell taken where she wants to go, and done before dawn, so that he does not have to watch her waiting. A horse would help.",
		"steps": [
			{"kind": "find", "text": "Take the halter-bell from the grey mare's bridle, in the stable"},
			{"kind": "carry", "from": "er_halter", "to": Vector2(327.0, 337.0), "r": 10.0, "time": 150.0, "label": "The halter-bell",
				"lost": "The bell has slipped its strap and lost itself in the heather. Wat has the mare's other halter.",
				"text": "Carry the bell south by the nave and cairn roads to the foot of the Cairn Tower before the mare gives up waiting ({t} s)"},
			{"kind": "place", "text": "Hang the bell on the rag-pole at the Cairn Tower's foot"},
			{"kind": "turnin", "who": "wat", "text": "Tell Wat the bell is hung"},
		],
		"reward": {"ash": 24, "items": {"ember_shard": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
		"stands": {"at": Vector2(327.0, 338.5), "kind": "staff"},
		"outcome": {"": "Wat opened the stall door at the second bell. The mare stood a long time on the threshold, then went out across the yard to the road gate and stopped there, as horses stop at a thing they have decided to finish. 'She will not go,' Wat said. 'She carried it. She only wanted to know it had arrived.' He stood with her until the lamp tower paled. She is a horse again, he says, the sort that wants her oats, and she will not tell him whose bell it was."}},
	"er_inn_slate": {"name": "The Last Lamp's Slate", "giver": "vell", "zone": "eastreach", "offer": true,
		"where": "Mother Vell, at the Last Lamp in Lastlight",
		"text": "Every pilgrim who stopped at the Last Lamp owed Vell's family a night, chalked on the slate behind the bar, and none of them came back to pay it. Three hundred years of names stand on the slate and Vell has never rubbed one out. The pilgrims who turned back on the Thousand Cairns turned back in debt, and the ones who rise there still hold their tokens, the pewter discs the inn gave for a bed, in their fists. Something among them keeps count of every stone.",
		"steps": [
			{"kind": "collect", "of": 5, "chance": 0.7, "kinds": ["pilgrim"], "region": "cairns", "label": "The Last Lamp's tokens", "at": Vector2(346.0, 270.0),
				"text": "Take the Last Lamp's pewter tokens off the turned-back who rise on the north cairns ({n}/{of})"},
			{"kind": "slay", "of": 1, "rares": ["cairn_counter"], "at": Vector2(318.0, 252.0), "label": "The One Who Counted",
				"text": "Put down the One Who Counted, who has added every turned-back pilgrim to his stones and never been paid"},
			{"kind": "place", "text": "Set the tokens on the Last Lamp's counter, under the slate, and decide what the slate says"},
			{"kind": "turnin", "who": "vell", "text": "Tell Mother Vell what the slate says now"},
		],
		"alt": {"forgive": {3: "Tell Mother Vell the slate is clean"}, "keep": {3: "Tell Mother Vell the slate stands"}, "paid": {3: "Tell Mother Vell the slate is paid"}},
		"reward": {"ash": 26, "items": {"ember_shard": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"outcome": {
			"forgive": "Vell wiped the slate with her sleeve, bar to hem, and the chalk of three hundred years hung in the lamplight like breath. 'There,' she said. 'Paid in full.' Nobody in the Last Lamp said a word, and the stew was free until the lamp tower paled. In the morning the first line on the clean slate was in her own hand: nobody owes.",
			"keep": "Vell set the tokens in a row on the shelf above the slate and did not rub out a name. 'They will want to know it was written down,' she said. 'A debt is a way of being remembered.' She charged you for the stew, and meant it kindly.",
			"paid": "Vell chalked PAID across the whole slate in one big stroke, and every name under it stayed legible. 'That is the best of both,' she said. 'They are owed nothing, and they are not forgotten.' She set the five tokens in the window, where the road could see them.",
			"": "Vell turned the tokens over in her palm, one by one, and put them on the shelf."}},
}

const PICKUPS := {
	"er_candle": {"quest": "er_ringers_candle", "step": 0, "near": Vector2(349.5, 57.5), "kind": "lantern_lit", "name": "Maudlin's candle", "verb": "Take",
		"say": "A stub of tallow in a horn cup, the ninth of its line: Maudlin has relit it from the last every night since the Night, and the horn has gone brown as a tooth. The flame leans, steadily, away from the shut gate and toward the south."},
	"er_door": {"quest": "er_ringers_candle", "step": 3, "near": Vector2(299.0, 152.0), "kind": "place", "name": "the Nave's west door", "verb": "Set the candle on",
		"say": "The Nave's west front stands over the black water, its portal's step awash and its door long gone, the dark inside as deep as the vault. You set the candle on the step, and for the length of a breath the water holds the flame's reflection without a ripple. Then a sound comes up the nave, very low and very slow: one bell-rope, drawn."},
	"er_halter": {"quest": "er_halter_bell", "step": 0, "near": Vector2(313.0, 71.0), "kind": "mark", "name": "the halter-bell", "verb": "Take",
		"say": "A small brass bell on a strap of cracked leather, the name cut in it filled with nine winters of stable dust: ISOBEL R., RIDING EAST. The mare puts her nose against your sleeve as you lift it, and takes it away again, and keeps looking at the door."},
	"er_tower": {"quest": "er_halter_bell", "step": 2, "near": Vector2(327.0, 337.0), "kind": "place", "name": "the Cairn Tower's foot", "verb": "Hang the bell at",
		"say": "At the tower's foot the first cairn is no higher than a table, and a rag-pole leans from it with seven rags knotted on, bleached to the colour of the heath. You hang the bell on the pole. It does not ring. Out on the north cairns something does, once, a small brass answer, and then every cairn on the heath goes on being a cairn."},
	"er_slate": {"quest": "er_inn_slate", "step": 2, "near": Vector2(326.5, 53.5), "kind": "place", "name": "the slate behind the bar", "verb": "Set the tokens before", "conv": "er_slate",
		"say": "The slate behind the bar."},
}

const CONVS := {
	"er_slate": {"name": "The Last Lamp's Slate", "start": [["!qat:er_inn_slate:2", "gone"], ["", "at"]], "nodes": {
		"at": {"say": "The slate behind the Last Lamp's bar, three hundred years of names down both its faces in chalk, a night owed against each. You lay five pewter tokens on the counter under it, and they are cold in a way the room is not.", "who": "", "choices": [
			{"text": "Wipe it clean. They owe nothing.", "to": "forgive"},
			{"text": "Leave the names, and set the tokens by them.", "to": "keep"},
			{"text": "Chalk PAID across all of it.", "to": "paid"},
			{"text": "Not yet.", "to": ""},
		]},
		"forgive": {"say": "You take the rag from its nail and wipe, bar to hem. The chalk lifts off in one long breath and hangs in the lamplight, and the slate is black and new as the day it was hung. Behind you, somewhere in the dark of the inn, a very large number of people sit down.", "who": "", "do": "qp:er_inn_slate:forgive,qa:er_inn_slate", "next": ""},
		"keep": {"say": "You line the tokens up on the shelf below the slate, one under each of five names, and leave every other name where it stands. They are not forgiven. They are accounted for.", "who": "", "do": "qp:er_inn_slate:keep,qa:er_inn_slate", "next": ""},
		"paid": {"say": "You take the chalk and write PAID, once, across the whole slate, as big as the slate will hold. Every name under it stays legible. The tokens on the counter go warm in your palm, the way a coin does that has been spent.", "who": "", "do": "qp:er_inn_slate:paid,qa:er_inn_slate", "next": ""},
		"gone": {"say": "The slate behind the bar says what you left it saying.", "who": "", "next": ""},
	}},
}
