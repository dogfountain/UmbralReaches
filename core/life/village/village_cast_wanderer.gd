extends RefCounted
## The Late Ringer (docs/STORY.md "the recurring wanderer"): one stranger who meets the wanderer five times across the night, always somewhere
## a bell or a stair is near, and each time remembers a little more. He is Iorweth, the last ringer of the Stair: the door half-took him, and he
## came down not quite hollow, like the wanderer, and has been walking toward a bell ever since. He is five cast entries with one rig, each
## present only while the task `last_ringer` is at his step (VState.test over `qat:`), so he is never in two places and always where the task
## says. Walk islands, no camps: he carries his own fire. Voices are babble. Data only. No class_name.
##   iorweth_1  the Pilgrims' Road east of Hearthward        before the task (a fire kindled): asks the way to a bell
##   iorweth_2  the Kindlers' Yard gate                        step 0: remembers ringing
##   iorweth_3  the Spire's foot, by the shut-out bell        steps 2-4: the bell he could not ring
##   iorweth_4  the Crossing's foot                            steps 5-7: the last bell's stone
##   iorweth_5  Hearthward's green                             steps 8-9 and after: home

const NODES := {
	"iw1_a": Vector2(30.0, 64.0), "iw1_b": Vector2(38.0, 65.0),
	"iw2_a": Vector2(-72.0, 44.0), "iw2_b": Vector2(-78.0, 42.0),
	"iw3_a": Vector2(236.0, 19.0), "iw3_b": Vector2(244.0, 21.0),
	"iw4_a": Vector2(310.0, -48.0), "iw4_b": Vector2(316.0, -48.0),
	"iw5_a": Vector2(6.0, 44.0), "iw5_b": Vector2(10.0, 44.0),
}

const EDGES := [["iw1_a", "iw1_b"], ["iw2_a", "iw2_b"], ["iw3_a", "iw3_b"], ["iw4_a", "iw4_b"], ["iw5_a", "iw5_b"]]

const CAST := {
	"iorweth_1": {"name": "Iorweth", "title": "A late pilgrim with a bell-rope round his waist", "when": "kindled:1,!q:last_ringer,!qd:last_ringer", "camp": "outpost",
		"rig": {"seed": 6707, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "r": "staff", "l": "lantern", "girth": 0.92,
			"cloth": Color(0.3, 0.3, 0.32), "cloth2": Color(0.4, 0.37, 0.32), "hair_c": Color(0.5, 0.46, 0.4), "skin": Color(0.74, 0.58, 0.46), "leather": Color(0.34, 0.22, 0.12)},
		"home": "iw1_a", "speed": 0.8, "fearless": true,
		"schedule": {"dusk": "wait", "work": "wait", "midnight": "wait", "late": "wait"},
		"routines": {"wait": [{"act": "look_up", "at": "iw1_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [8.0, 12.0]},
			{"act": "idle", "at": "iw1_b", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [5.0, 8.0]}, {"act": "kneel", "at": "iw1_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [10.0, 16.0]}]}},
	"iorweth_2": {"name": "Iorweth", "title": "A late pilgrim with a bell-rope round his waist", "when": "qat:last_ringer:0|qat:last_ringer:1", "camp": "outpost",
		"rig": {"seed": 6707, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "r": "staff", "l": "lantern", "girth": 0.92,
			"cloth": Color(0.3, 0.3, 0.32), "cloth2": Color(0.4, 0.37, 0.32), "hair_c": Color(0.5, 0.46, 0.4), "skin": Color(0.74, 0.58, 0.46), "leather": Color(0.34, 0.22, 0.12)},
		"home": "iw2_a", "speed": 0.8, "fearless": true,
		"schedule": {"dusk": "wait", "work": "wait", "midnight": "wait", "late": "wait"},
		"routines": {"wait": [{"act": "look_up", "at": "iw2_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [8.0, 12.0]},
			{"act": "idle", "at": "iw2_b", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [5.0, 8.0]}, {"act": "kneel", "at": "iw2_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [10.0, 16.0]}]}},
	"iorweth_3": {"name": "Iorweth", "title": "A late pilgrim with a bell-rope round his waist", "when": "qat:last_ringer:2|qat:last_ringer:3|qat:last_ringer:4", "camp": "outpost",
		"rig": {"seed": 6707, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "r": "staff", "l": "lantern", "girth": 0.92,
			"cloth": Color(0.3, 0.3, 0.32), "cloth2": Color(0.4, 0.37, 0.32), "hair_c": Color(0.5, 0.46, 0.4), "skin": Color(0.74, 0.58, 0.46), "leather": Color(0.34, 0.22, 0.12)},
		"home": "iw3_a", "speed": 0.8, "fearless": true,
		"schedule": {"dusk": "wait", "work": "wait", "midnight": "wait", "late": "wait"},
		"routines": {"wait": [{"act": "look_up", "at": "iw3_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [8.0, 12.0]},
			{"act": "idle", "at": "iw3_b", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [5.0, 8.0]}, {"act": "kneel", "at": "iw3_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [10.0, 16.0]}]}},
	"iorweth_4": {"name": "Iorweth", "title": "A late pilgrim with a bell-rope round his waist", "when": "qat:last_ringer:5|qat:last_ringer:6|qat:last_ringer:7", "camp": "outpost",
		"rig": {"seed": 6707, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "r": "staff", "l": "lantern", "girth": 0.92,
			"cloth": Color(0.3, 0.3, 0.32), "cloth2": Color(0.4, 0.37, 0.32), "hair_c": Color(0.5, 0.46, 0.4), "skin": Color(0.74, 0.58, 0.46), "leather": Color(0.34, 0.22, 0.12)},
		"home": "iw4_a", "speed": 0.8, "fearless": true,
		"schedule": {"dusk": "wait", "work": "wait", "midnight": "wait", "late": "wait"},
		"routines": {"wait": [{"act": "look_up", "at": "iw4_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [8.0, 12.0]},
			{"act": "idle", "at": "iw4_b", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [5.0, 8.0]}, {"act": "kneel", "at": "iw4_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [10.0, 16.0]}]}},
	"iorweth_5": {"name": "Iorweth", "title": "A late pilgrim with a bell-rope round his waist", "when": "qat:last_ringer:8|qat:last_ringer:9|qd:last_ringer", "camp": "outpost",
		"rig": {"seed": 6707, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "r": "staff", "l": "lantern", "girth": 0.92,
			"cloth": Color(0.3, 0.3, 0.32), "cloth2": Color(0.4, 0.37, 0.32), "hair_c": Color(0.5, 0.46, 0.4), "skin": Color(0.74, 0.58, 0.46), "leather": Color(0.34, 0.22, 0.12)},
		"home": "iw5_a", "speed": 0.8, "fearless": true,
		"schedule": {"dusk": "wait", "work": "wait", "midnight": "wait", "late": "wait"},
		"routines": {"wait": [{"act": "look_up", "at": "iw5_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [8.0, 12.0]},
			{"act": "idle", "at": "iw5_b", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [5.0, 8.0]}, {"act": "kneel", "at": "iw5_a", "face": Vector2(0.0, -104.0) + Endgame.O2, "t": [10.0, 16.0]}]}},
}

const CONV := {
	"iorweth_1": {"name": "Iorweth", "start": [["!met:iorweth_1", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Mind the rope. It is not for you. It is for a bell I cannot find. I used to know where it hung.", "next": "meet2"},
		"meet2": {"say": "I am looking for a bell. I rang one, a long time ago, and I cannot recall which, or where, or whose it was. I only know that I stopped, and that was wrong.", "do": "met:iorweth_1", "next": "hub"},
		"hub": {"say_if": [
			["", "The road was longer than I remembered. The lamps were out. Somebody has lit one, I think, a long way back."]], "choices": [
			{"text": "Who are you?", "to": "who", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"who": {"say": "Walk with me a while, if you like. I do not mind the silence. I have had nine winters of it.", "next": "hub"},
	}},
	"iorweth_2": {"name": "Iorweth", "start": [["!met:iorweth_2", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Here. I knew this gate. I came down the Stair and this was the first gate I knew.", "next": "meet2"},
		"meet2": {"say": "There was a rope round my waist when I came down. I do not know why I kept it. A ringer keeps his rope. That is the rule, I think. I was a ringer.", "do": "met:iorweth_2", "next": "hub"},
		"hub": {"say_if": [
			["", "The graves in this yard are very tidy. I should like to be tidy. I am not, yet."]], "choices": [
			{"text": "Who are you?", "to": "who", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"who": {"say": "I rang the last bell. The one that was rung longest. I think it was longest because I could not stop. I was afraid of what the silence would be.", "next": "hub"},
	}},
	"iorweth_3": {"name": "Iorweth", "start": [["!met:iorweth_3", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "A bell, at the foot of a lamp. Facing the dark. I know that bell. I have never touched it.", "next": "meet2"},
		"meet2": {"say": "It was cast for the country the Order shut out. I did not know that when I rang my own. I thought mine was the last. It was not. It was only the last above.", "do": "met:iorweth_3", "next": "hub"},
		"hub": {"say_if": [
			["", "You ring it, if you like. I have not the right. I rang the wrong way round, the night of the Night. The bells stopped top first, and I did not stop."]], "choices": [
			{"text": "Who are you?", "to": "who", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"who": {"say": "If I put my hand on it, I will remember. I would rather remember with someone standing by.", "next": "hub"},
	}},
	"iorweth_4": {"name": "Iorweth", "start": [["!met:iorweth_4", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "This is the stone. It has my name on it, finished with a nail. Somebody has been kind to me in a way I did not earn.", "next": "meet2"},
		"meet2": {"say": "I was Iorweth. I had a daughter, Ione, who was five. She was in the Ninth Company, I think. Forty days late. I was not there to be late for. I was on the Stair, ringing, because a man said he would hold the door.", "do": "met:iorweth_4", "next": "hub"},
		"hub": {"say_if": [
			["", "I did not go through. I could not. I turned round, and I came down hollow, and then I came down warm. It is you, I think, who is warm. It was you, then, on the Stair, behind me. Another late one."]], "choices": [
			{"text": "Who are you?", "to": "who", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"who": {"say": "The last of you is through. That is what he said. I think I was the last of mine. I think you are the last of yours.", "next": "hub"},
	}},
	"iorweth_5": {"name": "Iorweth", "start": [["!met:iorweth_5", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Home. A green, a fire, a candle on a stone. I know the smell. It is all right to sit down.", "next": "meet2"},
		"meet2": {"say": "Ione is in the Glade, you say. She keeps a small fire. She was five. She cut a name, half-cut, three letters. I-O-N. And I was not there to cut the rest. I will go to her, in the morning, in my own time, with my hands empty.", "do": "met:iorweth_5", "next": "hub"},
		"hub": {"say_if": [
			["qd:last_ringer", "Ione has a rope on her wall now, and I have a seat by her fire. Neither of us says much. It is enough."],
			["", "The bells have stopped, and I find I do not mind. I thought I would mind. I rang for nine winters in my head."]], "choices": [
			{"text": "Who are you?", "to": "who", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"who": {"say": "Thank you for walking the Stair behind me. I did not know you were there. You were very quiet.", "next": "hub"},
	}},
}
