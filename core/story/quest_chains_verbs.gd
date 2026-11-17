extends RefCounted
## Hearthward's tasks that were flat fetches and now use the task verbs (docs/QUEST_VERBS.md), in the
## quest_chains.gd manner: one const a task (listed in QUESTS by name), the pickups they add in PICKUPS. Ids,
## rewards and giver unchanged; only the steps that were "go there / take it" were deepened.
##
##   KEG_THIEF    The Keg's Missing Ale   clues + an accusation: four signs behind the Keg, two read; what was read
##                                        decides what Nan can be told (village_talk_db.gd) and what the keep believes
##   SLOW_WAY     The Slow Way Down       tracks: Father Harrow's lantern-oil from the fen graves to his lantern
##   SPIRE_LAMPS  A Lamp on the Spire     lantern_walk: a lamp lit at the green's fire, carried up to the Spire
##   ALMS_LOAF    One Loaf, One Blessing  vigil: the Almonry's hour kept on its step, the hungry drawn to the loaf
##   DROWNED_BELL The Drowned Bell        order: the belfry's three slates, in the order Brannoc teaches; a wrong
##                                        one wakes the fen. `leaves`: what the belfry keeps afterwards
## House style (docs/LORE.md): terse, concrete, dark.

const KEG_THIEF := {"name": "The Keg's Missing Ale", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "hearth",
	"text": "Somebody has been lifting full mugs off the Keg's counter. The keep wants to know who before he starts guessing.",
	"steps": [
		{"kind": "clues", "at": Vector2(27.5, 32.4), "r": 12.0, "need": 2, "label": "Signs behind the Keg",
			"text": "Search behind the Kindled Keg, by the chimney, for signs of the ale thief ({n}/{of} read)",
			"clues": [
				{"key": "circle", "at": Vector2(27.5, 32.4), "prop": "mug", "name": "a dropped mug",
					"text": "One of the Keg's mugs, dry, on its side. Round it on the flags, a circle in chalk. A child's hand. Another circle further on, toward the green."},
				{"key": "gnaw", "at": Vector2(30.0, 30.6), "prop": "loaf", "name": "a gnawed crust", "false": true,
					"text": "A heel of oat-cake at the chimney foot, gnawed to the rind. Droppings along the wall. Something has been at the back stores. Something small."},
				{"key": "prints", "at": Vector2(25.4, 34.4), "name": "spilled ale",
					"text": "Ale spilled across the flags in a line, dry now, toward the green. Small feet went through it. Bare, narrow. They did not run."},
				{"key": "latch", "at": Vector2(30.4, 34.2), "name": "the back keg",
					"text": "The back keg's bung is out and set down neat on the lid. Rats don't put things back."},
			]},
		{"kind": "find", "text": "Follow the chalk circles to the green's fire"},
		{"kind": "talk", "who": "nan", "text": "Ask Nan Wright about the chalk circles"},
		{"kind": "talk", "who": "keep", "text": "Tell the keep what you found"},
	],
	"alt": {"rats": {3: "Tell the keep it was rats"}, "wrong": {3: "Tell the keep it was rats"}, "covered": {3: "Square Nan's debt with the keep (10 ash)"}},
	"reward": {"items": {"ember_shard": 2, "grave_iron": 1}},     # (no ash: covering Nan costs 10, and a refund would undo the choice)
	"outcome": {"told": "The keep knows it was Nan. He leaves a mug by the green's fire himself now.",
		"covered": "You paid for Nan's mugs. The keep is watching you; Nan drew you a circle.",
		"rats": "The keep blames rats. Nan keeps her secret, and her mug by the fire.",
		"wrong": "You blamed the rats, and the keep set a trap. Nan moved her mug out of its way. Nobody asked her anything."}}

const SLOW_WAY := {"name": "The Slow Way Down", "giver": "harrow", "where": "Ostrin Harrow, at the Keg's bar", "zone": "fen",
	"text": "Ostrin's father took his lantern down the fen after the bells, six winters gone. Ostrin wants the lantern back, whatever is holding it.",
	"steps": [
		{"kind": "tracks", "r": 14.0, "label": "Father Harrow's trail",
			"text": "Follow Father Harrow's lantern-oil north from the fen graves into the reeds ({n}/{of})",
			"marks": [
				{"at": Vector2(56.0, 14.0), "text": "A drip of lantern oil on a grave-marker's lip, dried to a skin. Another, a long stride on, going north."},
				{"at": Vector2(58.0, -4.0), "text": "Oil again, and a bootprint pressed in it, the heel dragged. He was not hurrying. He was not stopping, either."},
				{"at": Vector2(60.0, -24.0), "text": "The drops leave the high ground here and go into the reeds. The reeds lie all one way, as if something was pulled through them."},
				{"at": Vector2(60.0, -38.0), "text": "The oil ends. A lantern lies in the reeds ahead, and a man stands over it who is not looking at it."},
			]},
		{"kind": "kill", "text": "Put the hollowed man by the lantern to rest", "at": Vector2(58.0, -47.0)},
		{"kind": "find", "text": "Take Father Harrow's lantern"},
		{"kind": "talk", "who": "harrow", "text": "Bring the lantern to Ostrin Harrow at the Kindled Keg"},
	],
	"reward": {"ash": 20, "items": {"relic_fragment": 1}},
	"choose": [{"slot": "lantern", "rarity": 1}, {"slot": "vestment", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
	"outcome": {"truth": "Ostrin knows his father is at rest. The lantern burns on the Keg's counter.",
		"mercy": "Ostrin thinks his father still walks the fen. The lantern sits cold on the Keg's counter, waiting."}}

const SPIRE_LAMPS := {"name": "A Lamp on the Spire", "giver": "fennick", "where": "Old Fennick, on his lamp round", "zone": "summit",
	"offer": true, "avail": "kindled:1",
	"text": "The Order kept a lamp on the Watchers' Spire, up under the Crowns, to watch the sky turn. I lit it for them as a boy, from the green's fire, and carried it up in my two hands. Don't run with it. A flame can't take a run, or a roll, or a blow, or deep water. Light one, climb, and tell me what the sky looks like from up there.",
	"steps": [
		{"kind": "find", "text": "Light a lamp at the green's fire for the Watchers' Spire"},
		{"kind": "lantern_walk", "from": "spire_flame", "to": Vector2(-52.0, -100.0), "r": 8.0, "label": "The Watchers' Spire",
			"relight": "Light another at the green's fire.",
			"arrive": "You hang the lamp in the Spire's cradle. It takes. The sky turns slowly over it.",
			"text": "Carry the lit lamp up to the Watchers' Spire under the Crowns. Walk it: a run, a roll, a blow or deep water puts it out"},
		{"kind": "turnin", "who": "fennick", "text": "Tell Old Fennick what you saw from the Spire"},
	],
	"reward": {"ash": 14},
	"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}],
	"outcome": {"": "Fennick listened to all of it with his eyes shut. The lamp burned till dawn, he said; he watched it from the green. It is out now. He knew it would be."}}

const ALMS_LOAF := {"name": "One Loaf, One Blessing", "giver": "nan", "where": "Nan Wright, on the green", "zone": "road",
	"offer": true,
	"text": "The Almonry on the road gave a loaf to every pilgrim, one a night. Pell always ate hers on the step. There might be one left on the board. There's always one left on the board. Take it, and sit with it on the step a while, the way she did. Something will want it. Don't give it up.",
	"steps": [
		{"kind": "visit", "at": Vector2(46.0, 40.0), "r": 12.0, "label": "The Almonry", "text": "Go to the Almonry on the Pilgrims' Road"},
		{"kind": "find", "text": "Take the last loaf from the Almonry's board"},
		{"kind": "vigil", "at": Vector2(44.0, 44.0), "r": 9.0, "time": 45.0, "gloom": 0.8, "label": "The Almonry's hour", "noun": "step",
			"prop": "loaf_circle",
			"waves": [{"at": 14.0, "kinds": ["wretch"], "n": 2, "say": "The hungry have smelled the loaf."},
				{"at": 30.0, "kinds": ["wretch"], "n": 2, "say": "More. They keep the Almonry's hours."}],
			"held": "The hour is out. The loaf is whole.", "away": "Go back to the step. A blessing is kept sitting down.",
			"text": "Sit out the Almonry's hour on its step, the loaf in your hands ({t} s)"},
		{"kind": "turnin", "who": "nan", "text": "Bring the loaf to Nan Wright"},
	],
	"reward": {"ash": 8},
	"choose": [{"slot": "vestment", "rarity": 1}, {"slot": "lantern", "rarity": 1}],
	"outcome": {"": "Nan put the loaf by the green's fire, inside a chalk circle, beside the mug."}}

const DROWNED_BELL := {"name": "The Drowned Bell", "giver": "brannoc", "where": "Brannoc Bellwright, at the Keg", "zone": "fen",
	"offer": true,
	"text": "My grandfather cast the bell in the fen tower. It rang for the sunk. When the water came up it rang by itself for a week. Then it stopped. He taught me how he rang them down, one slate at a time, in the order they went under: the ferryman, then the choir, then the child on the stair. Wrong, and the water remembers the wrong one. Go and ring them for him, and bring me the tongue. A bell that can't ring can't be made to.",
	"steps": [
		{"kind": "visit", "at": Vector2(82.0, -18.0), "r": 14.0, "label": "The Drowned Belfry", "text": "Wade out to the Drowned Belfry in the Hollow Fen"},
		{"kind": "order", "at": Vector2(81.5, -19.0), "label": "The belfry's slates",
			"text": "Touch the three slates round the belfry in the order Brannoc taught you",
			"things": [
				{"key": "ferryman", "at": Vector2(86.0, -21.0), "prop": "slate", "name": "the ferryman's slate",
					"text": "The ferryman's slate hums under your palm, low, like an oar in a lock."},
				{"key": "choir", "at": Vector2(79.0, -23.0), "prop": "slate", "name": "the choir's slate",
					"text": "The choir's slate answers: three voices, a hair apart."},
				{"key": "child", "at": Vector2(76.5, -17.5), "prop": "slate", "name": "the child's slate",
					"text": "The child's slate rings once, small and clear. Out in the reeds something heavy settles."},
			],
			"order": ["ferryman", "choir", "child"],
			"wrong": "The slate goes dead under your hand. The water has remembered. Something in it stands up.",
			"wrong_spawns": {"kind": "ossuant", "n": 1},
			"done": "Ferryman, choir, child. The belfry is quiet."},
		{"kind": "find", "text": "Take the bell's iron tongue from the belfry"},
		{"kind": "turnin", "who": "brannoc", "text": "Bring the bell's tongue to Brannoc"},
	],
	"reward": {"ash": 14},
	"choose": [{"set": "bell", "slot": "focus", "rarity": 1}, {"set": "bell", "slot": "vestment", "rarity": 1}, {"set": "bell", "slot": "girdle", "rarity": 1}],
	"leaves": {"": {"at": Vector2(84.0, -15.0), "prop": "slate"}},
	"outcome": {"": "Brannoc keeps the drowned bell's tongue by him. It doesn't ring. He checks."}}

## The pickups these tasks want (quest_chains.gd PICKUPS lists them).
const PICKUPS := {
	"mug_fire": {"quest": "keg_thief", "step": 1, "near": Vector2(-3.3, 34.5), "kind": "mug_full", "name": "a full mug by the fire", "verb": "Look at",
		"say": "A mug of the Keg's ale, full, set down by the fire inside a chalk circle. Waiting for somebody who is not here."},
	"spire_flame": {"quest": "spire_lamps", "step": 0, "near": Vector2(1.4, 33.2), "kind": "lantern_lit", "name": "a lamp at the green's fire", "verb": "Light",
		"say": "You hold the wick to the green's fire until it takes. A small flame, leaning. It will want carrying like something that can be hurt."},
	"bell_tongue": {"quest": "drowned_bell", "step": 2, "near": Vector2(77.0, -12.0), "kind": "clapper", "name": "the bell's iron tongue", "verb": "Take",
		"say": "The clapper lies in the reeds where the water dropped it, a yard of black iron. It is cold, and it hums when you lift it."},
}
