extends RefCounted
## Five people with lives, camped at fires of their own along the night's story (docs/STORY.md). Each is a
## giver of a long task (core/story/quest_chains_story.gd), each has a hub that changes with what the wanderer has done, and
## each keeps a schedule: the fire at dusk, a watch on the ground they care for at midnight, a long sit at the fire before dawn.
## Their camps are village_cast.gd OUTPOSTS (a fire, a seat and the style's dressing, found by village.gd _outposts()).
##   Perrin Aldwyn   the third desk's scribe who cut the Hierarch's edicts; at the Chapel's yard                 (aurel_edicts)
##   Odile Frane     a lamplighter's widow, by the Pilgrims' Road east of Hearthward                              (lamp_road)
##   Ione Marsh      the Ninth Company's youngest, the tenth name nobody finished; in the Glimmer Glade           (name_on_roll)
##   Cantor Lowe     the choirmaster who chose the boy for the Fallen Hierarch's horn; at the Siege Lines         (horn_end)
##   Tamsin Hale     a Lastlight baker who carried bread to the Anchorholds' cells for nine winters               (vow_cell)
## Data only. Voices stay babble. No class_name.

const OUTPOSTS := {
	"perrin": {"near": [Vector2(-92.0, 56.0), Vector2(-60.0, 44.0), Vector2(-84.0, 66.0)], "region": "chapel", "style": "necropolis", "look": Vector2(-78.0, 51.0)},
	"odile": {"near": [Vector2(58.0, 62.0), Vector2(46.0, 60.0), Vector2(72.0, 62.0), Vector2(34.0, 60.0)], "region": "road", "style": "moor", "look": Vector2(112.0, 70.0)},
	"ione": {"near": [Vector2(-30.0, 16.0), Vector2(-44.0, 16.0), Vector2(-32.0, 0.0), Vector2(-46.0, 2.0)], "region": "glade", "style": "holds", "look": Vector2(-46.0, -38.0)},
	"lowe": {"near": [Vector2(-170.0, 170.0), Vector2(-176.0, 182.0), Vector2(-164.0, 160.0), Vector2(-168.0, 196.0)], "region": "siege", "style": "necropolis", "look": Vector2(-206.0, 148.0)},
	"tamsin": {"near": [Vector2(196.0, -72.0), Vector2(200.0, -82.0), Vector2(188.0, -90.0), Vector2(190.0, -64.0)], "region": "anchorholds", "style": "holds", "look": Vector2(214.0, -132.0)},
}

const CAST := {
	"perrin": {"name": "Perrin", "title": "Perrin Aldwyn, scribe of the third desk", "when": "", "camp": "outpost",
		"rig": {"seed": 6101, "sex": "m", "age": "old", "garment": "coat", "hat": "brim", "hair": "short", "beard": "short", "r": "staff", "girth": 0.9,
			"cloth": Color(0.2, 0.2, 0.24), "cloth2": Color(0.34, 0.3, 0.26), "hair_c": Color(0.7, 0.68, 0.64), "skin": Color(0.78, 0.58, 0.46), "leather": Color(0.3, 0.2, 0.12)},
		"home": "perrin_fire", "speed": 0.7,
		"schedule": {"dusk": "copy", "work": "copy", "midnight": "vigil", "late": "copy"},
		"routines": {
			"copy": [{"act": "read", "at": "perrin_seat", "face": "@fire_perrin", "t": [20.0, 30.0]},
				{"act": "warm", "at": "perrin_fire", "face": "@fire_perrin", "t": [8.0, 12.0]}],
			"vigil": [{"go": "perrin_w1"}, {"act": "kneel", "at": "perrin_w2", "face": "@out_perrin", "t": [16.0, 24.0]}, {"go": "perrin_w3"}, {"go": "perrin_fire"}],
		}},
	"odile": {"name": "Odile", "title": "Odile Frane, a lamplighter's widow", "when": "", "camp": "outpost",
		"rig": {"seed": 6202, "sex": "f", "age": "old", "garment": "dress", "apron": "linen", "hat": "kerchief", "hair": "bun", "l": "lantern", "girth": 1.06,
			"cloth": Color(0.34, 0.28, 0.24), "cloth2": Color(0.44, 0.4, 0.34), "hair_c": Color(0.74, 0.72, 0.68), "skin": Color(0.8, 0.6, 0.47), "leather": Color(0.36, 0.24, 0.13)},
		"home": "odile_fire", "speed": 0.8,
		"schedule": {"dusk": "camp", "work": "round", "midnight": "camp", "late": "round"},
		"routines": {
			"camp": [{"act": "warm", "at": "odile_fire", "face": "@fire_odile", "t": [8.0, 12.0]},
				{"act": "sit", "at": "odile_seat", "face": "@fire_odile", "t": [18.0, 26.0], "seat": 0.36}],
			"round": [{"go": "odile_w1"}, {"act": "tend", "at": "odile_w2", "face": "@out_odile", "t": [12.0, 18.0]}, {"act": "look_up", "at": "odile_w3", "face": "@out_odile", "t": [6.0, 9.0]}, {"go": "odile_fire"}],
		}},
	"ione": {"name": "Ione", "title": "Ione Marsh, of the Ninth Company", "when": "", "camp": "outpost",
		"rig": {"seed": 6303, "sex": "f", "age": "adult", "garment": "dress", "hood": true, "hair": "wild", "girth": 0.88,
			"cloth": Color(0.3, 0.3, 0.32), "cloth2": Color(0.4, 0.38, 0.34), "hair_c": Color(0.3, 0.2, 0.12), "skin": Color(0.84, 0.64, 0.5), "leather": Color(0.34, 0.22, 0.12)},
		"home": "ione_fire", "speed": 0.9,
		"schedule": {"dusk": "camp", "work": "ring", "midnight": "ring", "late": "camp"},
		"routines": {
			"camp": [{"act": "warm", "at": "ione_fire", "face": "@fire_ione", "t": [8.0, 12.0]},
				{"act": "sit", "at": "ione_seat", "face": "@fire_ione", "t": [18.0, 26.0], "seat": 0.36}],
			"ring": [{"go": "ione_w1"}, {"act": "mourn", "at": "ione_w2", "face": "@out_ione", "t": [14.0, 22.0]}, {"go": "ione_w3"}, {"go": "ione_fire"}],
		}},
	"lowe": {"name": "Lowe", "title": "Cantor Lowe, who chose the boy", "when": "", "camp": "outpost",
		"rig": {"seed": 6404, "sex": "m", "age": "old", "garment": "robe", "hood": true, "r": "staff", "beard": "long", "girth": 1.0,
			"cloth": Color(0.24, 0.2, 0.2), "cloth2": Color(0.4, 0.34, 0.28), "hair_c": Color(0.8, 0.78, 0.72), "skin": Color(0.76, 0.56, 0.44), "leather": Color(0.34, 0.22, 0.12)},
		"home": "lowe_fire", "speed": 0.7,
		"schedule": {"dusk": "camp", "work": "listen", "midnight": "listen", "late": "camp"},
		"routines": {
			"camp": [{"act": "warm", "at": "lowe_fire", "face": "@fire_lowe", "t": [8.0, 12.0]},
				{"act": "sit", "at": "lowe_seat", "face": "@fire_lowe", "t": [18.0, 26.0], "seat": 0.36}],
			"listen": [{"go": "lowe_w1"}, {"act": "look_up", "at": "lowe_w2", "face": "@out_lowe", "t": [14.0, 20.0]}, {"act": "kneel", "at": "lowe_w3", "face": "@out_lowe", "t": [10.0, 16.0]}, {"go": "lowe_fire"}],
		}},
	"tamsin": {"name": "Tamsin", "title": "Tamsin Hale, who brings the bread", "when": "", "camp": "outpost",
		"rig": {"seed": 6505, "sex": "f", "age": "adult", "garment": "dress", "apron": "linen", "hat": "kerchief", "hair": "bun", "l": "lantern", "girth": 1.16,
			"cloth": Color(0.36, 0.32, 0.28), "cloth2": Color(0.46, 0.42, 0.36), "hair_c": Color(0.34, 0.22, 0.12), "skin": Color(0.82, 0.6, 0.46), "leather": Color(0.4, 0.26, 0.13)},
		"home": "tamsin_fire", "speed": 0.9,
		"schedule": {"dusk": "camp", "work": "bread", "midnight": "camp", "late": "bread"},
		"routines": {
			"camp": [{"act": "warm", "at": "tamsin_fire", "face": "@fire_tamsin", "t": [8.0, 12.0]},
				{"act": "sit", "at": "tamsin_seat", "face": "@fire_tamsin", "t": [18.0, 26.0], "seat": 0.36}],
			"bread": [{"go": "tamsin_w1"}, {"act": "tend", "at": "tamsin_w2", "face": "@out_tamsin", "t": [10.0, 14.0]}, {"go": "tamsin_w3"}, {"go": "tamsin_fire"}],
		}},
}

## Hubs: each says something different for what the wanderer has done. The tasks they give are added to the hub by
## QuestGiver.merge (the accept and turn-in screens), so none is listed here.
const CONV := {
	"perrin": {"name": "Perrin Aldwyn", "start": [["!met:perrin", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Don't read over my shoulder. I am copying the word of the Hierarch, and I was never any good at it. I copy it, and I burn the copy, and I copy it again.", "next": "meet2"},
		"meet2": {"say": "Perrin Aldwyn. Scribe of the Order of the Open Sky, third desk. I cut the edicts onto the steles. Nine winters, and I have not once cut them again. They sit in my head like a splinter in a thumb.", "do": "met:perrin", "next": "hub"},
		"hub": {"say_if": [
			["boss:ascended_warden", "Down, is he? Then the door is shut and I am a scribe with no Hierarch. I find I mind. Sit. I will write you in, whatever name you like. There is a roll for it, if you have heard of the roll."],
			["qp:aurel_edicts:follow", "I wrote it back in, under your hand. 'And then I follow.' I never thought I should have the right to cut that line. I am not sure I had."],
			["qp:aurel_edicts:scratch", "Scratched out. Well. Nobody will cut it again. That is its own mercy, I suppose. There is no clerk left to be afraid of it."],
			["qp:aurel_edicts:leave", "You left it as I cut it. A fair judge. I wanted somebody to leave it, and I wanted somebody not to, and you have done me the courtesy of being the first."],
			["qat:aurel_edicts:7", "You have been to the Crossing. I can see it on your hands: stone-dust, and the look. Tell me what the stele says now. Tell me honestly."],
			["bosses:1", "One of the keepers fallen. He will have noticed. He notices, in his way. Does he speak to you? He used to speak to the whole Stair at once, kindly, in the plural."],
			["", "I sit here at dusk because the Kindlers never ask a man what he believes. I copy; I burn the copies; I copy again. It is a kind of prayer."],
		], "choices": [
			{"text": "What is a scribe doing out here?", "to": "why", "once": true},
			{"text": "You cut the third edict?", "to": "third", "once": true},
			{"text": "Did he go mad?", "to": "mad", "once": true, "if": "met:perrin"},
			{"text": "Goodbye.", "to": ""},
		]},
		"why": {"say": "Waiting to be needed. The Order kept a copy of everything, in the abbey, and the abbey's roof came in. I am the last copy. A man who is the last copy of something cannot leave it.", "next": "hub"},
		"third": {"say": "At dawn on the Night, in the Hierarch's own words, with the bells already starting. He said it slowly, so I would get it. I cut the half I dared. A scribe cuts what is safe to read aloud, and the rest sounded like a threat, and I was afraid of him.", "next": "third2"},
		"third2": {"say": "I have copied that half-line ten thousand times since, in my head, in the dark. I cannot get it to come out as a threat. Every time it comes out as a promise. I would like someone to go and see what is on the stone. I would like it to be someone who can read.", "next": "hub"},
		"mad": {"say": "No. That is what I cannot get past. He was the sanest man on the Stair that morning, and the kindest, and he apologised to the choir for the cold. A mad man I could have forgiven.", "next": "hub"},
	}},
	"odile": {"name": "Odile Frane", "start": [["!met:odile", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Mind the lantern. It is not lit. It is not lit because I have not decided who it is for.", "next": "meet2"},
		"meet2": {"say": "Odile Frane. My Ned kept the road's lamps, from the East Gate to the West, three hundred and eleven of them, and I carried his oil. The evening before the Night the Hierarch's riders put every one of them out, by edict. No fire below the Stair.", "do": "met:odile", "next": "meet3"},
		"meet3": {"say": "Ned lit them again behind the riders. He went up with the faithful the next morning, to be thanked. I carry the oil. I do not know what else to carry.", "next": "hub"},
		"hub": {"say_if": [
			["qp:lamp_road:stair", "They face the mountain. All of them, down the whole road. I walk it at dusk and the road is a long throat of light going up. Ned would have said that was showing off, and been pleased."],
			["qp:lamp_road:home", "They face the village. The whole road leans toward Hearthward like a congregation. Nobody going up will thank you. Everybody coming down will."],
			["qat:lamp_road:10", "You have walked it, the whole road, with a coal in a lantern, and not once did it go out. I would not have believed it of anybody. Come and sit, and tell me how it looked from the middle."],
			["bosses:2", "Two of the three down. The road is quieter. The dark has less to lean on. Perhaps it is a good night for oil."],
			["kindled:1", "A fire kindled, and word of it on the road already. The pilgrims' lamp-posts have stood nine winters waiting for someone with a coal and no orders. I will not ask who gave you yours."],
			["", "Three hundred and eleven lamps, and a widow with a bottle of oil. It has the sound of a joke, and I have stopped telling it."],
		], "choices": [
			{"text": "Who forbade the lamps?", "to": "who", "once": true},
			{"text": "Why not light them yourself?", "to": "self", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"who": {"say": "The Hierarch, in his second edict: on the Night, no fire below the Stair. It was meant kindly. A lit lamp is a thing the eye rests on, and he wanted every eye on the sky. He did not think about the people walking in the dark.", "next": "hub"},
		"self": {"say": "I tried. I stood at the first post at dusk with the coal in my hand, and my hand would not do it. Twelve times, in nine winters. A lamp lit by a woman who is afraid is a small thing, and the dark can tell.", "next": "hub"},
	}},
	"ione": {"name": "Ione Marsh", "start": [["!met:ione", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "You are standing where the ring was. It is all right. Everybody does. It is only ash.", "next": "meet2"},
		"meet2": {"say": "Ione. The Ninth Company's youngest, and the tenth name nobody finished: my mother was cutting it when she stopped. I was five. I did not burn my token because I could not find it, and I did not go hollow because I was lucky.", "do": "met:ione", "next": "hub"},
		"hub": {"say_if": [
			["qp:name_on_roll:entered", "You wrote yourself in. A stranger's name in the roll beside my mother's. I think she would have liked it. She always said a roll is a thing you can be added to."],
			["qp:name_on_roll:mother", "My mother's name, in the roll, where I wanted it. In your hand, not mine. I could not have held the knife steady."],
			["qp:name_on_roll:blank", "You left a line blank, for one who has not decided. I find I am not angry. A blank line is the most honest thing in the Order's whole book."],
			["boss:ascended_warden", "It is quiet in the glade tonight. Nobody is waiting on a bell. I did not know I had been, until I stopped."],
			["bosses:1", "The kindled one. They say you went into the Thornwood, or down the crypt. You came back warm. Mother used to say the warm ones are always the last."],
			["", "I keep the fire small. A big fire says somebody is expecting company. A small one says it is all right if nobody comes."],
		], "choices": [
			{"text": "What happened to the Ninth?", "to": "ninth", "once": true},
			{"text": "Who was your father?", "to": "father", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"ninth": {"say": "Forty days late. We reached the rim and there was no Stair. We camped in the wood to see if it would grow back. Mother Seren drew the ring and had us burn our tokens, so that if the sky called us we should not go. Some of us did not wake. I watched.", "next": "hub"},
		"father": {"say": "He went up the Stair the week before. He was always early. There is a line on the third stele, in a different hand: One is still on the Stair. I have decided it is him. Nobody has told me otherwise, and I should like very much for nobody to.", "next": "hub"},
	}},
	"lowe": {"name": "Cantor Lowe", "start": [["!met:lowe", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Hush. Listen. No, not that. Under that. Do you hear it? Nine winters, and it has not dropped a hair from the pitch.", "next": "meet2"},
		"meet2": {"say": "Lowe. Choirmaster, once. The Marches wanted a voice that could be heard across the whole Lines, and I knew a boy with perfect pitch and no fear of heights. I trained him. I chose him. I carried the stool up myself.", "do": "met:lowe", "next": "hub"},
		"hub": {"say_if": [
			["qp:horn_end:sung", "I sang it down with you. Every verse. It was the first time in nine winters I had stood anywhere near that horn and not wished to be struck dead. The boy's note stopped on the last line. It stopped, as a note should."],
			["qp:horn_end:broke", "You broke the horn. Nobody should have to. But it is broken, and the note is broken with it, and I cannot say I am sorry, and I cannot say I am not."],
			["qp:horn_end:left", "You left it ringing. I will not tell you that was wrong. It is the pitch. It is what I taught him. It would be a dishonour to the boy to be told he held it for nothing."],
			["boss:r37_hierarch", "It is quiet. I keep waking at night because it is quiet. I think I shall sleep, in a year or two."],
			["", "I sit and I listen. Somebody must. It is the only part of the choir's work I can still do."],
		], "choices": [
			{"text": "Who was the boy?", "to": "boy", "once": true},
			{"text": "Can the note be stopped?", "to": "stop", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"boy": {"say": "Tavi. Nine years old, with a throat like a flute and a stool sawn down to his height. He sat in the horn the first day and sang the Hierarch's edict, all of it, to the Lines, and the Lines stopped to listen. Then the statue fell.", "next": "hub"},
		"stop": {"say": "A note is a promise to keep singing it. You stop it by finishing the line. Nobody has told Tavi what the last line is. The verse was cut off when the statue fell, and a boy will go on holding a note until someone says: that is enough.", "next": "hub"},
	}},
	"tamsin": {"name": "Tamsin Hale", "start": [["!met:tamsin", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Don't go near the wall. She does not like to be looked at while she eats.", "next": "meet2"},
		"meet2": {"say": "Tamsin Hale, baker's daughter, of Lastlight. I bring bread up the cliff road once a week. It has been nine winters. The bread is gone in the morning. That is how I know she is alive, or how I know something is.", "do": "met:tamsin", "next": "hub"},
		"hub": {"say_if": [
			["qp:vow_cell:bread", "I left the loaf at the wall, as you did, and in the morning there was a second thing beside the basket: a link of chain, polished. I have it on a nail by the oven. I have never been thanked so well."],
			["qp:vow_cell:name", "You said her name through the wall. Nobody has said it to her for nine winters, and she answered. She told you the one word it is safe to tell a stranger. I will not ask. I wanted it to be yours."],
			["qp:vow_cell:break", "The wall is down. I knew it would be. A wall comes down in the end; a vow does not, and now she has nothing to hold it by but herself. I will bring the bread out into the open, if there is anyone left to eat it."],
			["boss:r37_anchoress", "The bread comes back. Every week, the basket, untouched. I keep baking. I do not know what else a baker is for."],
			["", "A loaf a week, and a prayer for whoever takes it. The Anchorholds are a hard country. I would not walk it for a stranger. I walk it for someone I have never seen."],
		], "choices": [
			{"text": "Who is she?", "to": "who", "once": true},
			{"text": "Does she speak?", "to": "speak", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"who": {"say": "They call her the Anchoress. She took the vow first and she took it hardest: no door, no sky, no leaving. The rest came out when the wall cracked, hollow. She stayed. I think that is the difference between faith and its shape.", "next": "hub"},
		"speak": {"say": "Once, to a pilgrim who passed in the first winter. She said: not yet. Not yet. That is all anyone has heard. I have decided she is not talking to us.", "next": "hub"},
	}},
}
