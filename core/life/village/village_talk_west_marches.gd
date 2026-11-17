extends RefCounted
## What Weirford's people say (West Marches; same shape as village_talk_db.gd CONV; no class_name).
## Warm, and wary: they took in the road's strays for forty years and burned nobody, and they have not
## forgotten which of those two cost them. Conditions and actions as village_talk_db.gd's header.

const CONV := {
	"dorrit": {"name": "Dorrit Marl", "start": [["!met:dorrit", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Door's open. It's always open. That's not hospitality, that's a hinge that went. Sit where the draught is least.", "next": "meet2"},
		"meet2": {"say": "Dorrit. The Grey Heron was my mother's and her mother's, and the weir's older than the pair of them. We feed anyone the road sends. The Order never did like that we didn't ask what they believed.", "do": "met:dorrit", "next": "hub"},
		"hub": {"say_if": [
			["boss:r37_hierarch", "It stopped. The horn. Nine years it hummed on still nights, a low note you felt in the mugs. Tonight the mugs just sit there. I keep listening for it."],
			["qd:wf_crown", "Tolliver came in and bought a round for the whole room. First time. He didn't say what for. He didn't have to."],
			["qd:wf_wheel", "Osk's wheel is turning. You can hear it from the back room. I'd forgotten what the house sounds like when the river's doing its share."],
			["", "Bread, broth, a bed with a lid on the draught. Ash or news, I'm not particular. News is rarer."],
		], "choices": [
			{"text": "What's the river like?", "to": "river", "once": true},
			{"text": "Who keeps the Watch here?", "to": "watch", "once": true},
			{"text": "Anything strange on the road?", "to": "strange", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"river": {"say": "The Sorrow. Comes down off the Crowns grey with ash and doesn't clear until the weir. Above the town it's the dead's, and below it's ours. We keep to the rule.", "next": "hub"},
		"watch": {"say": "Cassel. Eleven men, once. Four now, and the four are worth eleven. They sleep in shifts and they don't talk about the Lines. Don't ask them to.", "next": "hub"},
		"strange": {"say": "There's a head on the hill. You'll have seen it. Lying out there in the moss, big as the Keep, and the top of it open. Something talks in it when the wind's right. I don't go up.", "next": "hub"},
	}},
	"osk": {"name": "Osk", "start": [["!met:osk", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Mind the wheel-race. It's not deep. It's wet and it's cold and I've had to pull more than one pilgrim out of it.", "next": "meet2"},
		"meet2": {"say": "Osk. I grind what the town brings. Barley, mostly. The abbey's flour was always the better money. We don't speak of that.", "do": "met:osk", "next": "hub"},
		"hub": {"say_if": [
			["qd:wf_wheel", "She's turning. Listen. That's a wheel with all her buckets, and the river doing what it's told. You did that. I'll remember it, in flour."],
			["qat:wf_wheel:0", "Hollowed in the fords above, and the Reeve at their head. I can't go up there and I can't grind till the sluice is thrown."],
			["", "The weir's mine to keep. The river's the weir's to keep. We have a good understanding, the river and I, and it's been testing it lately."],
		], "choices": [
			{"text": "Why the weir?", "to": "weir", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"weir": {"say": "A weir's a promise. You hold the river back, and it stays held. The Order thought a river was a road for the dead. Fine. Mine only brings them as far as the stones.", "next": "hub"},
	}},
	"bryn": {"name": "Bryn Gale", "start": [["!met:bryn", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Stand off the apron. Sparks don't care who you are.", "next": "meet2"},
		"meet2": {"say": "Bryn. Hinges, hoops, horseshoes. Swords when the Watch brings the steel. I did the Lines' iron once. Don't ask what for.", "do": "met:bryn", "next": "hub"},
		"hub": {"say_if": [
			["boss:r37_hierarch", "A tine of it. They say you carry a piece. I'd like to see the grain of it, just once. Nobody's let me near the Hierarch's stone since I was a boy."],
			["", "Heat, hammer, quench. The Marches taught me the rest of it, and then they all went to the Lines."],
		], "choices": [
			{"text": "What's the Watch carry?", "to": "watch", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"watch": {"say": "Short swords. A long reach's no good in the lanes, and the lanes are all we've got. I keep them sharp, and I keep a spare in the stall for whoever needs one.", "next": "hub"},
	}},
	"cassel": {"name": "Captain Cassel", "start": [["!met:cassel", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Halt, and then carry on. That's the whole drill. We've never had cause for more.", "next": "meet2"},
		"meet2": {"say": "Cassel. Captain of what's left of Weirford's Watch. We hold the bridge and the bank. What's past the earthworks, I can't speak for. I sent a man to count once.", "do": "met:cassel", "next": "hub"},
		"hub": {"say_if": [
			["qd:wf_watch", "The lamp's on the tower. They'll see it from every ring of the Lines, and they'll know somebody's counting. That's worth a company."],
			["qat:wf_watch:1", "The lamp's lit. Go. It lasts about as long as a hard run, so don't dawdle on the way."],
			["qat:wf_watch:0", "There's a rack by my post. Take a lamp. The tower's south, a hundred paces past the second gate."],
			["", "The Marches dug in to the south and never came out. The old war-band still holds its rings. We keep to our side of the second gate."],
		], "choices": [
			{"text": "What was the Marches' war?", "to": "war", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"war": {"say": "Against the Order. Over the Edicts. We lost. The gates held, and the Marches did not. That's all I'll say. I was nineteen, and I was on the wrong end of the rope.", "next": "hub"},
	}},
	"ennis": {"name": "Sister Ennis", "start": [["!met:ennis", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Softly. They're listening, just under. I don't mind. I only ask you keep your voice below the water-line.", "next": "meet2"},
		"meet2": {"say": "Ennis. I keep the bridge. The river took thirty from Weirford the winter the sky turned, and none were buried. The sunk want a light. I carry one out.", "do": "met:ennis", "next": "hub"},
		"hub": {"say_if": [
			["qp:wf_lights:named,qd:wf_lights", "Thirty boats, thirty lights, and the three names said. I'd not asked what the keels said. I'd have wept for a week. You spared me, and then you read them anyway. There's a lamp on the east bank across from the shrine now. I know whose."],
			["qp:wf_lights:nameless,qd:wf_lights", "Thirty boats, thirty lights. You counted them in and left them as they were: three nameless, in the keels. I haven't looked. I'll not. There's an unlit lamp on the east bank, across from the shrine, standing. For when I can."],
			["qd:wf_lights", "Thirty boats, thirty lights. I'd counted three short, you see. You found them. The river's quieter on the bridge side tonight."],
			["", "A light on the water tells them where the town is. I think it tells them where it isn't, too. I think it says: not that way."],
		], "choices": [
			{"text": "Who are the sunk?", "to": "sunk", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"sunk": {"say": "Millers. Ferrymen. A boy who wanted to see the weir spill. People who fell in and people who walked in, when the sky began to turn. I do the roll each night.", "next": "hub"},
	}},
	"wren": {"name": "Sedge", "start": [["!met:wren", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "You came over the bridge! Did it hum? It hums when someone brave goes over. Mostly it hums when it's wet.", "next": "meet2"},
		"meet2": {"say": "I'm Sedge. Da's the miller. I'm not allowed past the second stone, but I know what's past it anyway. A head, and a hand, and a great big thing in the moss that talks.", "do": "met:wren", "next": "hub"},
		"hub": {"say_if": [
			["boss:r37_hierarch", "It's quiet now. Da says the horn's finally out of breath. I miss it a bit. It was like having a big dog on the hill."],
			["", "Want to see my chalk? I do the stones round the well. If it's not in a circle, it can't come in. Probably."],
		], "choices": [
			{"text": "What does it say, the head?", "to": "says", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"says": {"say": "Nothing you'd want. It says the first bit of something, and then it stops, like it forgot the end. Da says it was only ever given the first bit.", "next": "hub"},
	}},
	"tolliver": {"name": "Old Tolliver", "start": [["!met:tolliver", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "You've the look of someone with a head for heights. Good. Mine's gone, and I built half of what you'll see from the tower.", "next": "meet2"},
		"meet2": {"say": "Tolliver. Engineer to the Marches. I raised the Lines, and a few of the engines on them. The rest of my life's been a long apology to a very large head.", "do": "met:tolliver", "next": "hub"},
		"hub": {"say_if": [
			["boss:r37_hierarch", "Silence. I'd forgotten the shape of it. Thank you. I'd tell you what I owe you, but I'd say it badly, and it'd take until morning."],
			["qp:wf_crown:end,qd:wf_crown", "It stopped. I heard it stop, from the stall, and sat there. No fight: the boy just let go. There's a lamp in the skull's mouth, lit. I put the rubbings on the fire, and then I went and looked at the lamp. It's the first thing I've done for him."],
			["qp:wf_crown:silence,qd:wf_crown", "The horn's quiet. You went in and ended it, and the boy with it, I'd say, though I never saw him. A slate stands in the skull's mouth now. I cut the name on it myself. I didn't know it. I cut it anyway."],
			["qd:wf_crown", "The horn's done. All of it. The Hierarch's voice is where it belongs now: in the stone, saying nothing. You took the last of the First Edict out of it."],
			["qat:wf_crown:4", "The skull's open on the far side. The crown stands in the middle of the floor. It talks. It'll talk to you, and then it'll stop you."],
			["qat:wf_crown:3", "You've looked at where he sat. A stool, and the days. Now it's yours to say. Silence it, and be done: or tell him he can stop. I helped cut the hollow. I'll not tell you which."],
			["qat:wf_crown:2", "Look at where the boy sat, in the skull's mouth. The stool. The tally. Whatever the Order left him to eat. Then you'll know what the note is."],
			["qat:wf_crown:0", "Rubbings. Three. The Hierarch's name was cut in the stone at the hand, the shoulder and the lip. Get me all three and I can tell you which edict it speaks."],
			["", "I know what's in that head. I helped cut the hollow. It was to be a voice. For the Hierarch to speak across the Marches, over a thousand miles of heath."],
		], "choices": [
			{"text": "What's in the head?", "to": "head", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"head": {"say": "The cantor. A boy called Elias, twelve winters, picked for his voice. They sat him in the hollow and told him to hold the note. The statue fell, and the note didn't stop.", "next": "hub"},
	}},
	"gwyn": {"name": "Gwyn", "start": [["!met:gwyn", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Cob's called Hob. Not Hobb. Just the one B. Don't tell the Keg.", "next": "meet2"},
		"meet2": {"say": "Gwyn. I keep the stalls. The cob's for ride, if you've the ash. He knows the fords better than I know my own hands. He's very opinionated about bridges.", "do": "met:gwyn", "next": "hub"},
		"hub": {"say_if": [
			["", "Hooves in the dark, all night. That's the thing about the Marches: everything that walks here is hurrying somewhere else."],
		], "choices": [
			{"text": "Tell me about the cob.", "to": "cob", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"cob": {"say": "Sixteen hands of grievance. He turned the wheel for nine winters and he's never forgiven it. He's very sound on the fords. Give him his head over water.", "next": "hub"},
	}},
}
