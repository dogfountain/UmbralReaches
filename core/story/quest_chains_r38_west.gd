extends RefCounted
## tales, the west and north-west: four one-time tales of the Empty Plinth, the Saints' Quarry, the Waiting Field's
## Landing and the Lanternless Moor (data only, no class_name; quest_chains.gd lists each in the blocks marked `# --- tales ---`).
##   plinth_lamp     A Lamp for the Palm      FOUND: a lamp left at the mason's grave under the Empty Plinth; carry it along the
##                                            haul's furrow south to the Fallen Hierarch's open hand (Tolliver)
##   cutters_pledge  The Cutters' Pledge      Jory: the quarry clerk's roll, the benches' ghosts, the nook above the crane
##   landing_staves  A Staff for Each         Agathe: the pilgrims' staves left at the Pilgrims' Landing, set at the ranks' head
##   moor_niches     Three Niches             Ysolt: the moor's cairn-niches, the middle one held, the last one read
## `found_at` tasks start when the wanderer comes within `found_r` (quest_world.gd). House style: terse, concrete, dark.

const QUESTS := {
	"plinth_lamp": {"name": "A Lamp for the Palm", "giver": "tolliver", "zone": "plinth", "offer": true,
		"where": "a mason's grave under the Empty Plinth",
		"found_at": Vector2(-238.0, -94.0), "found_r": 12.0,
		"found_say": "A mason's grave in the moss under the plinth, a chisel laid across the stone with its edge turned. Beside it someone has left a lamp, trimmed and filled, and not lit.",
		"text": "Somebody leaves a lamp at the mason's grave under the Empty Plinth, trimmed and filled and unlit, and nobody has said who. The mason's cousin cut a line in the Hierarch's palm: the palm was to face down. It has always faced up, and nothing has ever been put in it. The furrow of the haul runs south from the plinth to the hand.",
		"steps": [
			{"kind": "find", "text": "Take the lamp left at the mason's grave"},
			{"kind": "carry", "from": "plinth_lamp", "to": Vector2(-232.0, 189.0), "r": 10.0, "time": 65.0, "label": "The mason's lamp",
				"lost": "The lamp has burned down on the road. There is another at the mason's grave.",
				"text": "Follow the furrow of the haul south, past Weirford, to the Fallen Hierarch's open hand before the lamp burns down ({t} s)"},
			{"kind": "place", "text": "Set the lamp in the Hierarch's open palm"},
			{"kind": "turnin", "who": "tolliver", "text": "Tell Tolliver the palm has a lamp in it"},
		],
		"reward": {"ash": 30, "items": {"relic_fragment": 1, "ember_shard": 1}},
		"choose": [{"slot": "lantern", "rarity": 3}, {"slot": "focus", "rarity": 3}],
		"stands": {"at": Vector2(-236.0, 193.0), "kind": "lantern_lit"},
		"outcome": {"": "Tolliver sat down on the stall's box. \"Faced up the whole time,\" he said. \"And I drew it facing down, eleven yards out, and never once looked at the hand.\" He did not say what he would have put in it. He put his own lamp beside yours on the stall, and lit it."}},
	"cutters_pledge": {"name": "The Cutters' Pledge", "giver": "jory", "zone": "quarry", "offer": true,
		"where": "Jory Quell, at his fire by the Saints' Quarry",
		"text": "Jory says the cutters were dismissed the day the four-thousandth step was set, and he has said it for nine winters. There was a roll kept in the clerk's hut of who stood and who went home. The quarry's ghosts are still working the benches, and a shelter above the crane deck can only be reached by those who do not take the stairs.",
		"steps": [
			{"kind": "find", "text": "Take the clerk's roll from the hut under the high bench"},
			{"kind": "slay", "of": 5, "region": "quarry", "label": "Cutters still at work", "at": Vector2(-124.0, -100.0),
				"text": "Put down the cutters still working the benches, so the roll can be read in quiet ({n}/{of})"},
			{"kind": "cond", "cond": "secret:found:cutters_nook", "at": Vector2(-124.0, -110.0), "label": "The cutters' nook", "past": "The cutters' nook is already found.",
				"text": "Find the cutters' shelter on the offcuts by the crane deck; the Tether or a long glide from the deck reaches it"},
			{"kind": "turnin", "who": "jory", "text": "Read Jory the roll"},
		],
		"reward": {"ash": 26, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "girdle", "rarity": 2}, {"slot": "focus", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"stands": {"at": Vector2(-127.0, -101.0), "kind": "slabs"},
		"outcome": {"": "Sixty-one marks and a line: STOOD, AT THE THIRD BELL, AND WENT HOME. Jory's mark was not among them. \"I cut on,\" he said. \"They put down their picks and I took the foreman's and cut the step. Nobody dismissed us. I did it alone.\" He set his mark at the foot of the roll, last. \"Late,\" he said. \"Still counts.\""}},
	"landing_staves": {"name": "A Staff for Each", "giver": "agathe", "zone": "necropolis", "offer": true,
		"where": "Sister Agathe, at the gate of the Waiting Field",
		"text": "Agathe has told herself for nine winters that the pilgrims who left their staves at the Pilgrims' Landing were turned back at the bone bridge, and went home. The staves are still leaning there. She wants them carried up to the head of the ranks, and set in the ground, and counted. She cannot make the walk down the lane.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Gather the pilgrims' staves from the south track, the lane's turn, and the Landing's rail ({n}/{of})"},
			{"kind": "slay", "of": 4, "region": "necropolis", "label": "Risen at the Landing", "at": Vector2(-40.0, 140.0),
				"text": "Put back what rises at the Landing as you leave it ({n}/{of})"},
			{"kind": "place", "text": "Set the staves in the ground at the head of the ranks"},
			{"kind": "turnin", "who": "agathe", "text": "Tell Agathe the staves are counted"},
		],
		"reward": {"ash": 26, "items": {"relic_fragment": 1}},
		"choose": [{"set": "tally", "slot": "vestment", "rarity": 3}, {"set": "tally", "slot": "girdle", "rarity": 3}],
		"stands": {"at": Vector2(-15.0, 113.0), "kind": "staff"},
		"outcome": {"": "Agathe took the staves one at a time and read each name to the field. By morning every stone in the first row had turned a hand's breadth from the mountain, toward the staves. \"Not turned back,\" she said. \"Told to leave them. Light, for the bridge. They went in unarmed, and they went in counted.\""}},
	"moor_niches": {"name": "Three Niches", "giver": "ysolt", "zone": "moor", "offer": true,
		"where": "Ysolt, at her fire under the tor",
		"text": "The faithful crossed the moor by the cairns, and where one of them stumbled a niche was cut in a cairn and a name put in it. Ysolt has three niches to keep and her knees keep her at the fire. She wants them lit in order, south to north, as the stumblers walked, with the middle one held while it takes. Garron knows the cairns. Ride him, if you have the ash.",
		"steps": [
			{"kind": "cond", "cond": "secret:lamps:moor_cairn_0", "at": Vector2(131.0, 48.0), "label": "The south niche", "text": "Kindle the south cairn-niche on the moor, beside the track"},
			{"kind": "defend", "at": Vector2(136.0, -5.0), "time": 45.0, "hp": 22.0, "label": "The middle niche", "noun": "niche", "prop": "cairn",
				"waves": [{"at": 6.0, "kinds": ["wretch", "gaunt"], "n": 2, "say": "Shapes come up the moor toward the cairn."},
					{"at": 26.0, "kinds": ["wretch", "gaunt"], "n": 3, "say": "More, out of the heather."}],
				"lost": "The niche's stones are scattered. It will have to be set again.", "held": "The middle niche is set, and burns on its own.",
				"text": "Hold the middle cairn-niche while it is set; keep the dark off it ({t} s)"},
			{"kind": "cond", "cond": "secret:lamps:moor_cairn_4", "at": Vector2(132.0, -55.0), "label": "The north niche", "text": "Go north and kindle the last cairn-niche, at the moor's far end"},
			{"kind": "find", "text": "Read the name cut in the north niche"},
			{"kind": "turnin", "who": "ysolt", "text": "Tell Ysolt whose name is in the north niche"},
		],
		"reward": {"ash": 28, "items": {"ember_shard": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}],
		"stands": {"at": Vector2(136.0, -5.0), "kind": "ward"},
		"outcome": {"": "Ysolt looked north along the line of three lights a long time. \"My name,\" she said. \"I cut it myself, the winter my knees went, so it would be ready.\" She laughed, shortly. \"Now it's lit. It will have to wait.\""}},
}

const PICKUPS := {
	"plinth_lamp": {"quest": "plinth_lamp", "step": 0, "near": Vector2(-236.0, -96.0), "kind": "lantern_lit", "name": "the lamp at the mason's grave", "verb": "Take",
		"say": "The lamp is cold, but the wick is fresh and the oil is sweet, and it takes your flame at the first touch. Whoever trimmed it meant it carried, and carried south."},
	"plinth_palm": {"quest": "plinth_lamp", "step": 2, "near": Vector2(-238.0, 194.0), "kind": "place", "name": "the open palm", "verb": "Set the lamp in",
		"say": "You climb the fallen blocks to the palm and set the lamp in the hollow of it, facing up, as the hand was always meant to hold nothing. The flame stands straight. Somewhere in the skull the held note wavers, and does not stop, and for the length of a breath is not alone."},
	"cutters_roll": {"quest": "cutters_pledge", "step": 0, "near": Vector2(-136.0, -100.0), "kind": "page", "name": "the clerk's roll", "verb": "Take",
		"say": "The roll is a long strip of parchment, rolled on a peg of ash and tied with a bootlace. Sixty-one names down the left, a mark by each, a line at the foot in the clerk's hand. A dry hand has smoothed the foot flat many times, and put it back."},
	"staff_a": {"quest": "landing_staves", "step": 0, "near": Vector2(-84.0, 133.0), "kind": "staff", "name": "a pilgrim's staff", "verb": "Take",
		"say": "A staff leaning in the hedge of the south track, a name burned in its crook and BACK AT DUSK under it. The ferrule is bright. It was stood here carefully, upright, by someone who meant to return."},
	"staff_b": {"quest": "landing_staves", "step": 0, "near": Vector2(-41.5, 141.0), "kind": "staff", "name": "a pilgrim's staff", "verb": "Take",
		"say": "A staff at the lane's turn, stood against a post. Cut in it, and cut again: GONE UP. The cut has been gone over with a thumbnail so many times it shines."},
	"staff_c": {"quest": "landing_staves", "step": 0, "near": Vector2(-38.0, 146.0), "kind": "staff", "name": "a pilgrim's staff", "verb": "Take",
		"say": "A staff by the Landing's rail, tagged in the Order's square hand: LEAVE THE STAFF. THE BRIDGE IS LIGHT. COUNTED. Under the tag, where a mourner would put a candle, a stack of seven other tags, all the same."},
	"staves_place": {"quest": "landing_staves", "step": 2, "near": Vector2(-15.0, 113.0), "kind": "place", "name": "the head of the ranks", "verb": "Set the staves at",
		"say": "You set the staves in the ground at the head of the ranks, one to a rank, as many as there are. The ground takes them without a sound. All down the slope the stones lean, very slightly, as if listening."},
	"niche_name": {"quest": "moor_niches", "step": 3, "near": Vector2(129.0, -57.0), "kind": "slate", "name": "the name in the north niche", "verb": "Read",
		"say": "A slate set in the north niche, the name cut plain and recent in a hand that has cut a good many: YSOLT, KEEPER OF THESE, WHO WALKED ALL OF THEM. The edges of the cut are still white."},
}
