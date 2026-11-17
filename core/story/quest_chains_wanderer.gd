extends RefCounted
## The Last Ringer's Road: the Late Ringer's arc (village_cast_wanderer.gd). Iorweth meets the wanderer five times and each meeting is a step of
## this task: talk, clues, a vigil, a find, talk, clues, a choice at a place, talk, and home. Offered by him on the Pilgrims' Road after the first fire;
## the end writes the thing the whole night has been walking toward: a half-hollow man walks home, as the lore says he may once the door is shut.
## House style (docs/LORE.md). No class_name. Registered through quest_chains_added.gd.

const GIVER_NAMES := {"iorweth_1": "Iorweth", "iorweth_2": "Iorweth", "iorweth_3": "Iorweth", "iorweth_4": "Iorweth", "iorweth_5": "Iorweth"}

const ORDER := ["last_ringer"]

const QUESTS := {
	"last_ringer": {"name": "The Last Ringer's Road", "giver": "iorweth_1", "zone": "road", "offer": true, "avail": "kindled:1",
		"where": "A late pilgrim with a bell-rope, on the Pilgrims' Road east of Hearthward",
		"text": "A pilgrim stands in the road east of the green with a bell-rope round his waist and no bell. He does not remember his name, or the bell, or why he stopped ringing. He asks nothing of you but company on a walk: to the Kindlers' Yard, where he knew the gate; to the Spire's foot, where there is a bell; to the Crossing's foot, where there is a stone with a name on it; and home, if there is one. It will take the whole night.",
		"steps": [
			{"kind": "talk", "who": "iorweth_2", "text": "Walk with the late pilgrim to the Kindlers' Yard gate, and speak with him there"},
			{"kind": "clues", "at": Vector2(-76.0, 39.0), "r": 10.0, "need": 2, "label": "The Kindlers' Yard",
				"text": "Read the Yard for what a ringer leaves behind ({n}/{of} read)",
				"clues": [
					{"key": "rope", "at": Vector2(-77.0, 40.0), "name": "a frayed rope on a stake", "text": "A bell-rope, hung on a stake by the gate, its end frayed to a brush: a ringer's, the fibre worn bright where a hand held it, a thumb's width at a time. It has hung here nine winters and nobody has cut it down."},
					{"key": "bell", "at": Vector2(-75.0, 38.0), "name": "a hand-bell with no clapper", "text": "A small brass hand-bell on a grave, the clapper missing. Whoever left it knew that a bell with no clapper is a bell that cannot be rung in anger. The grave under it is a ringer's. The date is the Night."},
					{"key": "scrap", "at": Vector2(-76.0, 41.0), "prop": "mark", "name": "a scratched scrap", "text": "A slate shard under the stake, scratched with a nail: I RANG UNTIL I COULD NOT HEAR THEM. THEN I RANG FOR THE QUIET. THEN I CAME DOWN. I do not know which of those was the sin."},
				]},
			{"kind": "talk", "who": "iorweth_3", "text": "Go with him east to the Lamplighters' Spire, to the bell at its foot, and hear what he says there"},
			{"kind": "vigil", "at": Vector2(242.0, 14.0), "r": 9.0, "time": 50.0, "gloom": 0.6, "label": "The shut-out bell", "noun": "bell", "prop": "lantern_lit",
				"waves": [{"at": 10.0, "kinds": ["husk"], "n": 2, "say": "The bell is untouched, and the dark leans in to hear it not be rung."},
					{"at": 28.0, "kinds": ["gaunt", "husk"], "n": 3, "say": "A man's voice, close by, very low: it was always the next one. It was always the one after."},
					{"at": 40.0, "kinds": ["husk"], "n": 2, "say": "Behind you, someone puts a hand on the bell, and does not pull."}],
				"held": "The bell is quiet. The man beside it has his hand on its shoulder. He has not rung it. He is, you notice, breathing.", "away": "Go back to the bell. A ringer's watch is kept at the bell.",
				"text": "Stand with the late pilgrim at the shut-out bell while he decides ({t} s)"},
			{"kind": "find", "text": "Take the rope's end from the bell's yoke, where a ringer once tied it"},
			{"kind": "talk", "who": "iorweth_4", "text": "Go north with him to the Crossing's foot, the last bell's stone, and speak with him"},
			{"kind": "clues", "at": Vector2(318.0, -60.0), "r": 10.0, "need": 2, "label": "The last bell's stone",
				"text": "Read the last bell's stone for the name finished with a nail ({n}/{of} read)",
				"clues": [
					{"key": "name", "at": Vector2(317.0, -59.0), "name": "the name cut short", "text": "RANG LAST AND LONGEST. The ringer's name is cut off where the Stair broke, and finished, in a different hand, with a nail: HE WAS CALLED IORWETH. He is warm, the nail says. He is not to be pitied. He did not stop."},
					{"key": "child", "at": Vector2(319.0, -61.0), "name": "a child's three letters", "text": "A very small mark on the stone's foot, cut with a thumbnail by a hand that could not have been taller than the stone: I O N. Three letters, and the stone has worn round them as it would round a living thing."},
					{"key": "rope", "at": Vector2(318.0, -58.0), "prop": "mark", "name": "a knotted cord", "text": "A knotted cord round the stone's neck, with eleven knots, one for each year he had been a ringer. There is a twelfth knot, unfinished. He had been going to tie it that morning."},
				]},
			{"kind": "place", "text": "Decide what the last bell's stone is for: ring it for him, let him ring it, or leave it still"},
			{"kind": "talk", "who": "iorweth_5", "text": "Walk him home to Hearthward's green, and speak with him there"},
			{"kind": "turnin", "who": "iorweth_5", "text": "Tell Iorweth the road is walked"},
		],
		"alt": {"ring": {9: "Tell Iorweth you rang the stone for him"}, "his": {9: "Tell Iorweth he rang it himself"}, "still": {9: "Tell Iorweth you left the stone still"}},
		"reward": {"ash": 50, "items": {"relic_fragment": 3, "ember_shard": 2}},
		"choose": [{"set": "bell", "slot": "lantern", "rarity": 3}, {"set": "kindler", "slot": "vestment", "rarity": 3}, {"set": "ferryman", "slot": "focus", "rarity": 3}],
		"leaves": {"ring": {"at": Vector2(318.5, -61.5), "prop": "lantern_lit"}, "his": {"at": Vector2(318.5, -61.5), "prop": "lantern_lit"}, "still": {"at": Vector2(318.5, -61.5), "prop": "mark"}},
		"outcome": {"ring": "Iorweth sat on the green's stone with the rope in his lap, and said very little. 'You rang it,' he said. 'In the right order. Bottom to top.' He ran the rope through his hands. 'I have been listening for that for nine winters. I did not know I was, until I heard it.' He wept, without any fuss, like a man letting a long breath go.",
			"his": "'I rang it myself.' Iorweth held up his hands and looked at them. 'The right way, the last time. I found I still knew how. They were not even shaking.' He laughed, to his own surprise. 'A ringer does not forget. A ringer is only made to stop.'",
			"still": "'You left it.' Iorweth nodded slowly. 'There is a bell I do not need to ring. I did not know that was permitted.' He put the rope round his own neck, loosely, like a scarf, and sat in the lee of the green's fire, and was a man who had no particular business anywhere.",
			"": "Iorweth sat by the green's fire and said nothing for a long time."}},
}

const PICKUPS := {
	"lr_tongue": {"quest": "last_ringer", "step": 4, "near": Vector2(241.0, 15.0), "kind": "mark", "name": "the rope's end", "verb": "Take",
		"say": "At the bell's yoke, a rope's end is knotted: a ringer's knot, the sort you cannot untie with a hand that is in a hurry. It comes away in yours in a long loose curl, as if it had only been waiting to be asked."},
	"lr_stone": {"quest": "last_ringer", "step": 7, "near": Vector2(318.5, -61.0), "kind": "place", "name": "the last bell's stone", "verb": "Answer", "conv": "story_last_ringer",
		"say": "The last bell's stone."},
}

const CONVS := {
	"story_last_ringer": {"name": "The Last Bell's Stone", "start": [["qat:last_ringer:7", "here"], ["", "gone"]], "nodes": {
		"here": {"say": "The stone stands at the Crossing's foot with its cut name and its thumbnail letters and its eleven knots. Behind you, a man with a rope round his waist is not looking at it. He is looking, very carefully, at his feet. The rope's end is in your hand.", "who": "", "choices": [
			{"text": "Tie the rope to the stone's yoke, and ring it, bottom to top, for him.", "to": "ring"},
			{"text": "Put the rope's end in his hand, and stand back.", "to": "his"},
			{"text": "Coil the rope on the stone's step. Leave it still.", "to": "still"},
			{"text": "Not yet.", "to": ""}]},
		"ring": {"say": "You rope it to the yoke and haul. The note comes up through the stone, low, and goes on and on up the empty Stair to the Crowns. Eleven strokes, one for every year. Behind you, someone lets out a very long breath.", "who": "", "do": "qp:last_ringer:ring,qa:last_ringer", "next": ""},
		"his": {"say": "You put it in his hand. He closes his fingers. For a long moment nothing happens. Then he ties the twelfth knot, the one that was unfinished, and rings, once, the right way up, with his own two hands.", "who": "", "do": "qp:last_ringer:his,qa:last_ringer", "next": ""},
		"still": {"say": "You coil the rope on the step, and lay the cut end across it, and stand back. The stone is warm. It does not need ringing. It is a stone with a name on it, and the name is finished.", "who": "", "do": "qp:last_ringer:still,qa:last_ringer", "next": ""},
		"gone": {"say": "The stone stands as you left it.", "who": "", "next": ""}}},
}
