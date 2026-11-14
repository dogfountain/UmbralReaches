extends RefCounted
## tales, the east: four one-time tales of the White Pans, Saltmarket, the brine works and the Pump Tower
## (data only, no class_name; quest_chains.gd lists each in the blocks marked `# --- tales ---`).
## Existing step kinds only (find, carry, slay, defend, cond, turnin); the choices are a pickup's conversation.
##   pans_hauler    What the Hauler Carried    FOUND: a dead hauler at the Brine Road's end (the letter in his hand),
##                                             the brine-clerk's strongroom, a tally to give whole or torn; Pip
##   pans_pan       The Last Good Pan          Nella: seed-salt carried to the second field and held while it takes
##   salt_barrel    Orrin's Barrel             Orrin: clear the road, carry a keg across both gates to
##                                             the Grey Heron before the Watch bars the door (a horse's errand); Dorrit
##   bitter_mother  The Bitter Mother          Teasel: the first brine-wife's skimmer, her marks on the Pump Tower, and her
##                                             rest on the pans
## A `found_at` task is not offered by anybody: quest_world.gd starts it when the wanderer comes within `found_r`.
## House style (docs/LORE.md): terse, concrete, dark.

const QUESTS := {
	"pans_hauler": {"name": "What the Hauler Carried", "giver": "pip", "zone": "saltpans", "offer": true,
		"where": "a hauler against a salt-cart, at the end of the Brine Road",
		"found_at": Vector2(209.5, 185.0), "found_r": 7.0, "found_prop": "staff",
		"found_say": "A hauler sits against a cart-wheel at the end of the Brine Road, grey with salt to the collar, his pole and satchel beside him. One hand is shut on a folded paper.",
		"text": "A hauler lies dead against his cart at the Brine Road's end, and the letter in his hand is for Pip. He says he counted what the Order's clerk took, and left the count in the clerk's strongroom on the crust. He says nobody is to burn it.",
		"steps": [
			{"kind": "find", "text": "Take the letter from the dead hauler's hand, by the cart at the Brine Road's end"},
			{"kind": "cond", "cond": "secret:solved:salt_vault", "at": Vector2(241.0, 207.0), "label": "The brine-clerk's strongroom", "past": "The strongroom is already open.",
				"text": "Open the brine-clerk's strongroom on the White Pans' crystal crust; the valves turn in the order the slate gives"},
			{"kind": "find", "text": "Take the clerk's tally from the strongroom"},
			{"kind": "turnin", "who": "pip", "text": "Take the tally to Pip"},
		],
		"alt": {"whole": {3: "Give Pip the whole tally"}, "torn": {3: "Give Pip the tally, one page short"}},
		"reward": {"ash": 22, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
		"stands": {"at": Vector2(209.5, 185.0), "kind": "lantern_lit"},
		"outcome": {"whole": "Pip read it to the last page standing in the road, then carried the oilcloth up to Marl's door. Nobody has said what was said. The door has stood open since, and Marl salts the step as he did before.",
			"torn": "Pip read what was left, twice, and put it away. His father did not run, and Marl is the reeve who kept the pans. Both are true. Pip has stopped asking which is heavier."}},
	"pans_pan": {"name": "The Last Good Pan", "giver": "nella", "zone": "saltpans", "offer": true, "avail": "kindled:1",
		"where": "Nella Crake, at the pans' edge by Saltmarket",
		"text": "Forty pans, Nella says, and one still comes up white. The rest she rakes for the look of it. The good pan wants a seed of last year's salt set in its bed, and a night when nobody walks across it. Somebody always does.",
		"steps": [
			{"kind": "find", "text": "Take the block of seed-salt from Nella's heap at Saltmarket's fire"},
			{"kind": "carry", "from": "pan_seed", "to": Vector2(240.0, 202.0), "r": 8.0, "time": 60.0, "label": "Seed-salt",
				"lost": "The seed has sweated away in your hands. Nella has cut another.",
				"text": "Carry the seed-salt down the Brine Road to the last good pan, in the second field, before it sweats away ({t} s)"},
			{"kind": "defend", "at": Vector2(240.0, 202.0), "time": 70.0, "hp": 24.0, "label": "The last good pan", "noun": "pan", "prop": "mark",
				"waves": [{"at": 8.0, "kinds": ["wretch", "gaunt"], "n": 2, "say": "Pan-walkers come up out of the glare, rakes on their shoulders."},
					{"at": 30.0, "kinds": ["wretch", "gaunt"], "n": 3, "say": "More, out of the white."},
					{"at": 52.0, "kinds": ["wretch", "husk"], "n": 3, "say": "The last of them come straight at the pan."}],
				"lost": "The seed is trampled out of its bed. Nella's heap has another block.",
				"held": "The seed has taken. The ones left at the pan's edge stand with their rakes grounded, waiting to be told it is done. They never meant to cross it.",
				"text": "Stand by the pan while the seed takes, and keep the rakers off the bed ({t} s)"},
			{"kind": "turnin", "who": "nella", "text": "Tell Nella the pan is taking"},
		],
		"reward": {"ash": 24, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "girdle", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"stands": {"at": Vector2(240.0, 202.0), "kind": "mark"},
		"outcome": {"": "Nella went down at first light, stood at the pan's edge, and said \"Done,\" to the whole white field. Along the bunds a line of rakers sat down where they stood. The pan has gone white from the edges in."}},
	"salt_barrel": {"name": "Orrin's Barrel", "giver": "orrin", "zone": "saltmarket", "offer": true, "avail": "kindled:1",
		"where": "Orrin Vail, at his stall in Saltmarket",
		"text": "Orrin Vail owes the Grey Heron a keg of salt, nine winters old: three nights' bread when his caravan was shut out. He has carried to Hearthward and back since the Night and never once past the West Gate. The road between is the hollowed's, and the Heron's door and his nerve shut at about the same hour. Ride, if you can ride.",
		"steps": [
			{"kind": "slay", "of": 3, "region": "road", "label": "The road's hollowed", "at": Vector2(150.0, 66.0),
				"text": "Clear the hollowed off the Pilgrims' Road, so the keg is not taken off you on the way ({n}/{of})"},
			{"kind": "find", "text": "Take Orrin's sealed keg from his stall"},
			{"kind": "carry", "from": "salt_barrel", "to": Vector2(-188.0, 66.0), "r": 9.0, "time": 75.0, "label": "Salt keg",
				"lost": "The wax has cracked in the cold and the Heron's door is barred. Orrin has sealed another.",
				"text": "Carry the keg across the whole Marches to the Grey Heron at Weirford, before the Watch bars the door ({t} s). A horse would help"},
			{"kind": "turnin", "who": "dorrit", "text": "Give the keg to Dorrit Marl, at the Grey Heron"},
		],
		"reward": {"ash": 26, "items": {"ember_shard": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}],
		"outcome": {"": "Dorrit broke the wax and looked in. Grey ash, fine as flour. \"Maud Vail,\" she said. \"Three nights free, and she stayed all three and the rest.\" She wrote nothing new in the ledger. She set the keg on the shelf over the hearth, where the warm is."}},
	"bitter_mother": {"name": "The Bitter Mother", "giver": "teasel", "zone": "saltpans", "offer": true, "avail": "kindled:1",
		"where": "Teasel Dray, at the drying shed",
		"text": "Before Teasel there was a brine-wife on the pans who taught her the trade, and walked out onto the white the winter the Order's tithe-gang came, and did not walk back. She is out there still, and bitter as the brine, and she has taken three rakers. Teasel wants her skimmer in her hand and the marks on the Pump Tower read, to know what she meant by it.",
		"steps": [
			{"kind": "find", "text": "Take the first brine-wife's skimmer from the drying shed's peg"},
			{"kind": "find", "text": "Read the marks at the Pump Tower's foot, at the end of the Brine Road"},
			{"kind": "cond", "cond": "elite:brine_wife", "at": Vector2(232.0, 180.0), "label": "The Bitter Mother", "past": "The Bitter Mother is already at rest.",
				"text": "Put the Bitter Mother to rest on the White Pans, with her skimmer in your hand"},
			{"kind": "place", "text": "Lay her skimmer on the white where she fell"},
			{"kind": "turnin", "who": "teasel", "text": "Tell Teasel what the marks said"},
		],
		"reward": {"ash": 30, "items": {"relic_fragment": 1, "ember_shard": 1}},
		"choose": [{"slot": "vestment", "rarity": 3}, {"slot": "focus", "rarity": 3}],
		"stands": {"at": Vector2(231.0, 181.0), "kind": "staff"},
		"outcome": {"": "Teasel read the marks twice, with a finger, as one reads a child's letters. \"Not mad,\" she said. \"Keeping a gate.\" She salted the grave of a woman who had been salting the pans against her own people for nine winters, and then she raked the white, all night, in a straight line."}},
}

const PICKUPS := {
	"pans_letter": {"quest": "pans_hauler", "step": 0, "near": Vector2(210.0, 184.0), "kind": "page", "name": "a hauler's letter", "verb": "Take",
		"say": "The paper is addressed PIP, in a hauler's square hand. \"If this reaches you I did not run. I counted what the clerk took, a barrel in two, every week since the Night, and Marl signed for each. The count is in the clerk's strongroom on the crust. The valves go as the slate says. Do not let anyone burn it.\""},
	"pans_tally": {"quest": "pans_hauler", "step": 2, "near": Vector2(240.0, 205.0), "kind": "page", "name": "the clerk's tally", "verb": "Take", "conv": "r38_tally",
		"say": "The clerk's tally."},
	"pan_seed": {"quest": "pans_pan", "step": 0, "near": Vector2(218.0, 98.0), "camp": "marl", "kind": "mark", "name": "a block of seed-salt", "verb": "Take",
		"say": "A block of salt as big as a loaf, grey-white, sweating in the cold: last year's crop from the good pan. Nella has cut her mark in its end, and a second mark under it, older, that she will not explain."},
	"salt_barrel": {"quest": "salt_barrel", "step": 1, "near": Vector2(218.0, 98.0), "camp": "marl", "kind": "mark", "name": "Orrin's keg", "verb": "Take",
		"say": "A small keg bound in tarred rope, the bung sealed in wax. VAIL cut in the head, and under it a second name, planed off. It is heavier than salt. Orrin does not look at it."},
	"skimmer_shed": {"quest": "bitter_mother", "step": 0, "near": Vector2(218.0, 98.0), "camp": "marl", "kind": "staff", "name": "the brine-wife's skimmer", "verb": "Take",
		"say": "A long-handled skimmer on the shed's peg, the bowl worn thin as a leaf. Salt has crusted the grip in the shape of a hand. Teasel has never hung anything else on that peg."},
	"tower_marks": {"quest": "bitter_mother", "step": 1, "near": Vector2(217.0, 183.0), "kind": "page", "name": "marks on the Pump Tower", "verb": "Read",
		"say": "Cut low in the Pump Tower's footing, a tally of wagons, forty strokes, and one word over and over: SHUT. Under them, in the brine-wife's hand: I SHUT THE GATE ON THEM AND STAYED TO KEEP IT SHUT. LET NONE RAKE AFTER ME."},
	"skimmer_lay": {"quest": "bitter_mother", "step": 3, "near": Vector2(231.0, 180.0), "kind": "place", "name": "the white where she fell", "verb": "Lay the skimmer on",
		"say": "You lay the skimmer on the crust with its bowl to the Tower. The white takes the grip, and the shape of the hand in it, and for a moment the whole flat is quiet."},
}

const CONVS := {
	"r38_tally": {"name": "The Clerk's Tally", "start": [["!qat:pans_hauler:2", "gone"], ["", "at"]], "nodes": {
		"at": {"say": "A ledger of the Order's salt-tithe in oilcloth, dry as the day it was shut in. BARRELS WON, BARRELS OWED, column on column: half of everything went north. Every page is signed MARL P., for Saltmarket, and under each signature, in the hauler's hand, a tick.", "who": "", "choices": [
			{"text": "Carry it to Pip whole.", "to": "whole"},
			{"text": "Tear out the pages Marl signed, and carry the rest.", "to": "torn"},
			{"text": "Leave it for now.", "to": ""},
		]},
		"whole": {"say": "You tie the oilcloth as you found it. It is lighter than half a village's winters has any right to be.", "who": "", "do": "qp:pans_hauler:whole,qa:pans_hauler", "next": ""},
		"torn": {"say": "The pages come away with a sound like crust breaking. You fold them into your coat. What is left still says half went north. It no longer says who agreed.", "who": "", "do": "qp:pans_hauler:torn,qa:pans_hauler", "next": ""},
		"gone": {"say": "The strongroom lies open, and the shelf where the tally was is bare.", "who": "", "next": ""},
	}},
}
