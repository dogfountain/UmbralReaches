extends RefCounted
## The East Reach's tasks (docs/far_reaches.md "The Reaches' tasks"; data only, no class_name; quest_chains.gd lists each in the
## blocks marked `# --- the reaches ---`). Lastlight's people give and close them; they carry the wanderer from the walled
## waystation to the Bellfall, the Drowned Nave and the Thousand Cairns. Task verbs (docs/QUEST_VERBS.md) and picks that leave props.
##   er_ringers_candle  The Candle for the Ringers (Sister Maudlin)  MAIN: a candle walked to the Bellfall (lantern_walk), the cairn read (clues), the Tollman, set or doused
##                                                                   and the Nave's west door (the dungeon hook: HOOKS.drowned_nave)
##   er_nave_fire       The One at the Nave Fire (Fenn)              after the candle: walk the man at the Nave's fire home by the road
##                                                                   (an escort), to the shrine at Lastlight
##   er_halter_bell     The Bell on the Bridle (Wat)                 a mare's halter-bell carried south to the Cairn Tower, against the clock
##   er_inn_slate       The Last Lamp's Slate (Mother Vell)          the tokens off the turned-back; the One Who Counted; the debtors read (clues); the slate: a choice
##   er_rope            The Rope Rung Right (Sister Maudlin)         quest_chains_deepen_c.gd: the ringers' rope-marks and the ropes in order, at the Nave's shore
## House style: terse, concrete, dark.

const ZONE := ["eastreach", "The East Reach"]

## Where a thread ends at a dungeon's entrance (see the west file's HOOKS).
const HOOKS := {
	"drowned_nave": {"quest": "er_ringers_candle", "step": 4, "at": Vector2(300.0, 154.0), "r": 14.0, "cond": "q:er_ringers_candle:4", "done": "qd:er_ringers_candle"},
}

const QUESTS := {
	"er_ringers_candle": {"name": "The Candle for the Ringers", "giver": "maudlin", "zone": "eastreach", "offer": true,
		"where": "Sister Maudlin, at the pilgrims' shrine in Lastlight",
		"text": "Sister Maudlin has knelt at the shrine nine winters, facing the shut gate. Her brother Tobin rang the lowest rope on the Stair, and when the sky turned the bells stopped top first, and the ringers on the bottom ropes came down the road to Lastlight and knocked. Coyle's father barred the gate. Maudlin keeps one candle for them that is never allowed to burn out, and she has begun to doubt it is lit for the right ones. She will have it walked down to the Bellfall, where they went to ring, and set on the Nave's step, or put out there. She does not know which she wants.",
		"steps": [
			{"kind": "find", "text": "Take Maudlin's candle from the shrine"},
			{"kind": "lantern_walk", "from": "er_candle", "to": Vector2(322.0, 100.0), "r": 8.0, "time": 150.0, "label": "Maudlin's candle",
				"relight": "Maudlin will light another from the shrine.",
				"arrive": "You hold the candle at the Bellfall's west lip, and the flame leans, steadily, toward the crater. It has never been this far from the gate.",
				"text": "Walk the candle out by the road gate and down to the Bellfall's west lip, flame to windward ({t} s). A run, a roll, a blow or deep water puts it out"},
			{"kind": "clues", "at": Vector2(331.0, 103.0), "r": 12.0, "need": 2, "label": "The Ringers' Cairn",
				"text": "Read the Ringers' Cairn: which rope each of them pulled ({n}/{of} read)",
				"clues": [
					{"key": "low", "at": Vector2(327.0, 101.5), "prop": "mark", "name": "the smallest hand", "text": "A hand pressed in soot on the lowest stone, small and square, the thumb crooked at the joint. Under it, cut with a spoon-handle: SEVEN. The lowest rope. A rope a boy could reach."},
					{"key": "mid", "at": Vector2(334.0, 99.0), "name": "a worn rope-sling", "text": "A rope-sling of tarred hemp laid across a stone, the wear in it deep on one side. A left-handed ringer, strong. Cut under: FOUR. His hand is on the stone beside it, and the soot has run, as if the hand was lifted and put back."},
					{"key": "high", "at": Vector2(331.0, 107.0), "prop": "mark", "name": "the largest hand", "text": "The largest hand, the fingers spread. ONE. The highest rope, the one that was never rung from the bottom of the Stair. His is the only hand on the cairn with nothing cut beside it. He did not think he would be asked."},
				]},
			{"kind": "slay", "of": 1, "rares": ["cracked_tollman"], "at": Vector2(352.0, 119.0), "label": "The Cracked Tollman",
				"text": "Put down the Cracked Tollman, who rings the Ringers back to their rope, on the crater's south rim"},
			{"kind": "place", "text": "Decide the candle at the step of the Drowned Nave's west door, down nave_track: set it, or put it out"},
			{"kind": "turnin", "who": "maudlin", "text": "Tell Sister Maudlin what answered at the Nave"},
		],
		"alt": {"set": {5: "Tell Sister Maudlin the candle is set"}, "douse": {5: "Tell Sister Maudlin the candle is out"}},
		"reward": {"ash": 40, "items": {"relic_fragment": 2, "ember_shard": 1}},
		"choose": [{"set": "bell", "slot": "lantern", "rarity": 3}, {"set": "bell", "slot": "focus", "rarity": 3}, {"set": "bell", "slot": "vestment", "rarity": 3}],
		"leaves": {"set": {"at": Vector2(298.0, 150.5), "prop": "lantern_lit"}, "douse": {"at": Vector2(349.5, 58.5), "prop": "lantern"}},
		"outcome": {
			"set": "Maudlin heard it out on her knees, and when you had finished she put the candle's horn cup in your hand and closed your fingers on it. 'Tobin rang the lowest rope,' she said. 'He would not have stopped for a gate. He would have gone on to ring whatever there was.' She turned, on her knees, away from the east for the first time in nine winters, toward the road they had come in by. 'Tell Coyle I will not be facing it,' she said. 'Tell him I will be listening for the other way.' A candle burns on the Nave's step, and nobody has been sent to keep it.",
			"douse": "Maudlin heard it out on her knees. When you said the candle was out, she did not move. 'Nine winters,' she said, 'I have kept a flame for them that they never asked for.' She did not light another. The horn cup stands cold on the shrine's step. 'Let them find the dark,' she said. 'They will know their way in it.' She turned, slowly, from the gate, and she was still kneeling when the lamp tower's light went white.",
			"": "Maudlin heard it out on her knees, and turned away from the east for the first time in nine winters."}},
	"er_nave_fire": {"name": "The One at the Nave Fire", "giver": "fenn", "zone": "eastreach", "offer": true, "avail": "qd:er_ringers_candle|qp:ll_gate:answer",
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
		"text": "Every pilgrim who stopped at the Last Lamp owed Vell's family a night, chalked on the slate behind the bar, and none of them came back to pay it. Three hundred years of names stand on the slate and Vell has never rubbed one out. The pilgrims who turned back on the Thousand Cairns turned back in debt, and the ones who rise there still hold their tokens, the pewter discs the inn gave for a bed, in their fists. Something among them keeps count of every stone. Vell wants the tokens back on her counter, and each one read before the slate is touched: she has never looked whose they are.",
		"steps": [
			{"kind": "collect", "of": 5, "chance": 0.7, "kinds": ["pilgrim"], "region": "cairns", "label": "The Last Lamp's tokens", "at": Vector2(346.0, 270.0),
				"text": "Take the Last Lamp's pewter tokens off the turned-back who rise on the north cairns ({n}/{of})"},
			{"kind": "slay", "of": 1, "rares": ["cairn_counter"], "at": Vector2(318.0, 252.0), "label": "The One Who Counted",
				"text": "Put down the One Who Counted, who has added every turned-back pilgrim to his stones and never been paid"},
			{"kind": "clues", "at": Vector2(326.5, 51.5), "r": 7.0, "need": 2, "label": "The tokens' debtors",
				"text": "Lay the tokens out on the Last Lamp's counter and read whose they were ({n}/{of} read)",
				"clues": [
					{"key": "coyle", "at": Vector2(325.0, 50.0), "prop": "mark", "name": "a token cut M. COYLE", "text": "A token scratched M. COYLE on its rim, in a small careful hand. A night's bed, owed. The Serjeant's aunt, if the name is right: she sang the low part in the Order's choir, and went up the road the year before the Night."},
					{"key": "vell", "at": Vector2(329.0, 52.0), "prop": "mark", "name": "a token with a bell on it", "text": "A token with a bell stamped on its face, the Vell mark, the inn's own. A Vell's. Somebody of this house took a bed in her own inn, owed herself a night, and went up the road without paying it."},
					{"key": "stranger", "at": Vector2(327.0, 54.5), "name": "a token with no name", "text": "A token with nothing on it at all. Not a name, not a mark. Newer than the others, and warmer. It is the one the One Who Counted held longest."},
				]},
			{"kind": "place", "text": "Set the tokens before the slate, and decide what the slate says"},
			{"kind": "turnin", "who": "vell", "text": "Tell Mother Vell what the slate says now"},
		],
		"alt": {"forgive": {4: "Tell Mother Vell the slate is clean"}, "keep": {4: "Tell Mother Vell the slate stands"}, "paid": {4: "Tell Mother Vell the slate is paid"}, "stranger": {4: "Tell Mother Vell the stranger's night is forgiven"}},
		"reward": {"ash": 26, "items": {"ember_shard": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"leaves": {"forgive": {"at": Vector2(326.5, 52.5), "prop": "lantern_lit"}, "keep": {"at": Vector2(326.5, 52.5), "prop": "slate"}, "paid": {"at": Vector2(326.5, 52.5), "prop": "page"}, "stranger": {"at": Vector2(326.5, 52.5), "prop": "mark"}},
		"outcome": {
			"forgive": "Vell wiped the slate with her sleeve, bar to hem, and the chalk of three hundred years hung in the lamplight like breath. 'There,' she said. 'Paid in full.' Nobody in the Last Lamp said a word, and the stew was free until the lamp tower paled. In the morning the first line on the clean slate was in her own hand: nobody owes.",
			"keep": "Vell set the tokens in a row on the shelf above the slate and did not rub out a name. 'They will want to know it was written down,' she said. 'A debt is a way of being remembered.' She charged you for the stew, and meant it kindly.",
			"paid": "Vell chalked PAID across the whole slate in one big stroke, and every name under it stayed legible. 'That is the best of both,' she said. 'They are owed nothing, and they are not forgotten.' She set the five tokens in the window, where the road could see them.",
			"stranger": "Vell chalked PAID across the slate, and then, below it, in a different hand, small, the stranger's night, and wrote under it: forgiven. She would not say whose. The nameless token sits by the lamp, and she sets a bed for it at the end of the room every night, turned down.",
			"": "Vell turned the tokens over in her palm, one by one, and put them on the shelf."}},
}

const PICKUPS := {
	"er_candle": {"quest": "er_ringers_candle", "step": 0, "near": Vector2(349.5, 57.5), "kind": "lantern_lit", "name": "Maudlin's candle", "verb": "Take",
		"say": "A stub of tallow in a horn cup, the ninth of its line: Maudlin has relit it from the last every night since the Night, and the horn has gone brown as a tooth. The flame leans, steadily, away from the shut gate and toward the south."},
	"er_door": {"quest": "er_ringers_candle", "step": 4, "near": Vector2(299.0, 152.0), "kind": "place", "name": "the Nave's west door", "verb": "Set the candle on", "conv": "er_slate",
		"say": "The Nave's west door."},
	"er_halter": {"quest": "er_halter_bell", "step": 0, "near": Vector2(313.0, 71.0), "kind": "mark", "name": "the halter-bell", "verb": "Take",
		"say": "A small brass bell on a strap of cracked leather, the name cut in it filled with nine winters of stable dust: ISOBEL R., RIDING EAST. The mare puts her nose against your sleeve as you lift it, and takes it away again, and keeps looking at the door."},
	"er_tower": {"quest": "er_halter_bell", "step": 2, "near": Vector2(327.0, 337.0), "kind": "place", "name": "the Cairn Tower's foot", "verb": "Hang the bell at",
		"say": "At the tower's foot the first cairn is no higher than a table, and a rag-pole leans from it with seven rags knotted on, bleached to the colour of the heath. You hang the bell on the pole. It does not ring. Out on the north cairns something does, once, a small brass answer, and then every cairn on the heath goes on being a cairn."},
	"er_slate": {"quest": "er_inn_slate", "step": 3, "near": Vector2(326.5, 53.5), "kind": "place", "name": "the slate behind the bar", "verb": "Set the tokens before", "conv": "er_slate",
		"say": "The slate behind the bar."},
}

## The east's place choices live in this one conversation (a registered id: dialogue_db.gd lists it); its start list branches on
## the step a task is at, so each pickup's `conv: "er_slate"` opens its own scene. The slate's own is "at".
const CONVS := {
	"er_slate": {"name": "The Last Lamp's Slate", "start": [["qat:er_ringers_candle:4", "candle"], ["qat:ll_gate:3", "gate"], ["qat:ll_oil:4", "wick"],
			["qat:er_rope:2", "rope"], ["qat:er_inn_slate:3", "at"], ["", "gone"]], "nodes": {
		"candle": {"say": "The Nave's west front stands over the black water, its portal's step awash and its door long gone, the dark inside as deep as the vault. You hold Maudlin's candle over the step. The flame leans in, away from you, toward whatever is waiting at the far end of the nave.", "who": "", "choices": [
			{"text": "Set the candle on the step, lit, for the ringers.", "to": "set"},
			{"text": "Put it out. They have kept the dark long enough to know it.", "to": "douse"},
			{"text": "Not yet.", "to": ""},
		]},
		"set": {"say": "You set the candle on the step, and for the length of a breath the water holds the flame's reflection without a ripple. Then a sound comes up the nave, very low and very slow: one bell-rope, drawn.", "who": "", "do": "qp:er_ringers_candle:set,qa:er_ringers_candle", "next": ""},
		"douse": {"say": "You pinch the wick between finger and thumb. The dark takes the step back, and the water goes out of the reflection. Then a sound comes up the nave, low and slow, and it is not a bell-rope. It is a long breath let go.", "who": "", "do": "qp:er_ringers_candle:douse,qa:er_ringers_candle", "next": ""},
		"gate": {"say": "The East Gate's bar is as thick as a man's waist, iron-shod, set in brackets nobody could lift alone. Behind you the postern's latch hangs on its hook. In front of you the planks are cold, and have been knocked on. A word would carry through them.", "who": "", "choices": [
			{"text": "Open the postern, and let the knocking in.", "to": "open"},
			{"text": "Hold the bar. A bar is a bar.", "to": "hold"},
			{"text": "Answer it. Through the wood.", "to": "answer"},
			{"text": "Not yet.", "to": ""},
		]},
		"open": {"say": "You lift the postern's latch. The dark stands at the sill with a draught on its back. Nothing comes over it. A great deal of patience goes out of the night, and you shut the postern again before it can be missed.", "who": "", "do": "qp:ll_gate:open,qa:ll_gate", "next": ""},
		"hold": {"say": "You set your shoulder to the bar and hold it. The fourth knock comes and does not finish. Whatever stood on the far side lifts its hand off the wood, and the bar stops humming.", "who": "", "do": "qp:ll_gate:hold,qa:ll_gate", "next": ""},
		"answer": {"say": "You say it through the planks, low: you are heard. It is not much. It is enough. Out in the dark a voice says four words, in the Nave's cadence, and does not say them again.", "who": "", "do": "qp:ll_gate:answer,qa:ll_gate", "next": ""},
		"wick": {"say": "The east wick leans toward the shut gate, a hand's breadth of tallow-soaked cord, as if somebody on the other side were drawing on it. Isolde's voice, from the stair above: 'It is lit for the road. It is the gate that wants it.'", "who": "", "choices": [
			{"text": "Light it. Let the gate see the road is kept.", "to": "lit"},
			{"text": "Leave it dark. The gate has had its share.", "to": "dark"},
			{"text": "Not yet.", "to": ""},
		]},
		"lit": {"say": "You hold the taper to the east wick. It takes, and leans hard toward the gate, and on the far side of the wall something sets down a very heavy burden.", "who": "", "do": "qp:ll_oil:lit,qa:ll_oil", "next": ""},
		"dark": {"say": "You pinch the east wick and leave it dark. The tower's white goes slightly yellow on the gate's side. Isolde, from the stair, says nothing, and goes on climbing.", "who": "", "do": "qp:ll_oil:dark,qa:ll_oil", "next": ""},
		"rope": {"say": "Four ropes hang over the black water from a gantry nobody built, frayed at the ends, their last feet trailing in it. The lowest is rung now, and the next, and the next, and the highest, and the whole shore hums like a plucked wire. One of them still moves. It is yours to still, or to pull.", "who": "", "choices": [
			{"text": "Still the lowest rope with your hand, and let the others hang. Let the ringers rest.", "to": "low"},
			{"text": "Pull the highest rope once more, hard, for the ones who rang from above.", "to": "high"},
			{"text": "Not yet.", "to": ""},
		]},
		"low": {"say": "You close your hand on the lowest rope. The hum goes out of the others one by one, top to bottom, and when it is stilled the shore is quiet. Down the road, very far, a gate hears a different sort of silence.", "who": "", "do": "qp:er_rope:low,qa:er_rope", "next": ""},
		"high": {"say": "You haul the highest rope down, and it comes with a crack: the old hemp parts at the sheave, and the length of it falls into the water and sinks. The ringing stops all at once, all of it, as at a blow. Something in the Nave lets go a breath it has held for nine winters.", "who": "", "do": "qp:er_rope:high,qa:er_rope", "next": ""},
		"at": {"say": "The slate behind the Last Lamp's bar, three hundred years of names down both its faces in chalk, a night owed against each. You lay five pewter tokens on the counter under it, and they are cold in a way the room is not.", "who": "", "choices": [
			{"text": "Wipe it clean. They owe nothing.", "to": "forgive"},
			{"text": "Leave the names, and set the tokens by them.", "to": "keep"},
			{"text": "Chalk PAID across all of it.", "to": "paid"},
			{"text": "Chalk PAID, and write the nameless one's night forgiven by hand.", "to": "stranger", "if": "qc:er_inn_slate:stranger"},
			{"text": "Not yet.", "to": ""},
		]},
		"forgive": {"say": "You take the rag from its nail and wipe, bar to hem. The chalk lifts off in one long breath and hangs in the lamplight, and the slate is black and new as the day it was hung. Behind you, somewhere in the dark of the inn, a very large number of people sit down.", "who": "", "do": "qp:er_inn_slate:forgive,qa:er_inn_slate", "next": ""},
		"keep": {"say": "You line the tokens up on the shelf below the slate, one under each of five names, and leave every other name where it stands. They are not forgiven. They are accounted for.", "who": "", "do": "qp:er_inn_slate:keep,qa:er_inn_slate", "next": ""},
		"paid": {"say": "You take the chalk and write PAID, once, across the whole slate, as big as the slate will hold. Every name under it stays legible. The tokens on the counter go warm in your palm, the way a coin does that has been spent.", "who": "", "do": "qp:er_inn_slate:paid,qa:er_inn_slate", "next": ""},
		"stranger": {"say": "You write PAID across the slate, and then, in the corner where a name would go, in your own hand, forgiven. The nameless token goes warm, and then still. In the dark of the inn a chair is drawn out at the room's far end, and nobody sits in it.", "who": "", "do": "qp:er_inn_slate:stranger,qa:er_inn_slate", "next": ""},
		"gone": {"say": "The slate behind the bar says what you left it saying.", "who": "", "next": ""},
	}},
}
