extends RefCounted
## Act II's signature tasks (data only; quest_chains.gd lists each in its QUESTS and ORDER, and its
## pickups in PICKUPS, so the ledger, the audit and the world find them). No class_name.
## The seven far countries' chains share one template (slay, gather, collect, carry, a rare, a daily);
## each country gets one task of a different shape, built from the existing step kinds only:
##   bounds_beaten  The Rooted Holds   walk the bounds: three ward-stones, in order (visit, visit, visit)
##   quarry_stone   The Saints' Quarry set a founding-stone where it belongs (find, visit, place)
##   moor_fires     The Lanternless Moor  a flame relayed cairn to cairn (carry, find, carry)
##   founder_pour   The Founder's Pits  a timed pour, before the bronze sets (carry against the clock)
##   orchard_stand  The Cinder Orchard  carry the scion to the old tree, then hold it while it takes (carry, slay)
##   field_round    The Waiting Field  the sexton's round, end to end, with what rises on the way (visit, slay, visit)
##   mere_ferry     Corvin's Mere      the ferry's last crossing, out and back (carry, find, carry)
## Every step that goes somewhere has a place for the map; every task pays and offers gear.
## House style (docs/LORE.md): terse, concrete, dark.

const BOUNDS := {"name": "Beating the Bounds", "giver": "ruan", "where": "Gammer Ruan, at her fire in the Rooted Holds", "zone": "holds",
	"offer": true, "avail": "qd:holds_turf",
	"text": "Once a year the Rooted walked their bounds, stone to stone, and said each name aloud so the ground would know whose it was. Nobody has walked them since the young ones went. My knees say no. Say the names for me, at the Holds' stone, the wood's, and the glade's. In that order; the ground is particular.",
	"steps": [
		{"kind": "visit", "at": Vector2(-141.0, 4.0), "r": 8.0, "label": "The Holds' ward-stone", "text": "Begin the bounds at the Holds' ward-stone, west of the fire"},
		{"kind": "visit", "at": Vector2(-66.0, 30.0), "r": 8.0, "label": "The wood's ward-stone", "text": "Walk on to the ward-stone under the Thornwood's oaks"},
		{"kind": "visit", "at": Vector2(-44.0, 4.0), "r": 8.0, "label": "The glade's ward-stone", "text": "Close the bounds at the ward-stone in the Glimmer Glade"},
		{"kind": "turnin", "who": "ruan", "text": "Tell Gammer Ruan the bounds are walked"},
	],
	"reward": {"ash": 18, "items": {"relic_fragment": 1}},
	"choose": [{"set": "kindler", "slot": "focus", "rarity": 2}, {"set": "kindler", "slot": "vestment", "rarity": 2}, {"set": "kindler", "slot": "girdle", "rarity": 2}],
	"outcome": {"": "Ruan had you say the three names back to her at the fire, and corrected one. Then she turned a bed face up, the first in nine years, and did not say whose."}}

const QUARRY_STONE := {"name": "The Foreman's Stone", "giver": "jory", "where": "Jory Quell, at his fire by the Saints' Quarry", "zone": "quarry",
	"offer": true, "avail": "qd:quarry_picks",
	"text": "A quarry sets a founding-stone the day its first block comes out, the foreman's name cut in it, under the first step. Ours was set up on the benches because the pit wasn't dug yet. The pit's dug. Nobody moved it. It's been sat on the wrong level for sixty years, and I'd like to see it where it belongs before my eyes go.",
	"steps": [
		{"kind": "find", "at": Vector2(-116.0, -96.0), "text": "Lift the foreman's founding-stone from the high bench"},
		{"kind": "visit", "at": Vector2(-128.0, -104.0), "r": 9.0, "label": "The pit floor", "text": "Carry the founding-stone down to the quarry's pit floor"},
		{"kind": "place", "at": Vector2(-127.0, -101.0), "text": "Set the founding-stone at the foot of the last step"},
		{"kind": "turnin", "who": "jory", "text": "Tell Jory Quell the stone is down"},
	],
	"reward": {"ash": 18, "items": {"relic_fragment": 1}},
	"choose": [{"slot": "focus", "rarity": 2}, {"slot": "girdle", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
	"outcome": {"": "Jory made you tell him what the stone said. \"Under the first step,\" he said. \"Well, it's under the last now. Close enough. Nobody ever read the middle.\""}}

const MOOR_FIRES := {"name": "Fire Down the Moor", "giver": "ysolt", "where": "Ysolt, at her fire under the tor", "zone": "moor",
	"offer": true, "avail": "qd:moor_cairns",
	"text": "The faithful crossed this moor by the cairns, and on the worst nights they passed a flame along them, hand to hand, so none of them went in the dark alone. There's nobody to pass it to now. Take it from my fire to the middle cairn, light the next from it, and carry that to the south. One flame, two cairns. Don't let it stop.",
	"steps": [
		{"kind": "find", "at": Vector2(133.0, -12.0), "text": "Take a flame from Ysolt's fire"},
		{"kind": "carry", "from": "moor_flame_fire", "to": Vector2(147.0, 0.0), "r": 5.0, "time": 50.0, "label": "Flame",
			"lost": "The flame has gone out on the moor. Ysolt's fire has more.",
			"text": "Carry the flame to the middle cairn before the wind has it ({t} s)"},
		{"kind": "find", "at": Vector2(147.0, 2.0), "text": "Light a fresh flame at the middle cairn"},
		{"kind": "carry", "from": "moor_flame_mid", "to": Vector2(135.0, 24.0), "r": 5.0, "time": 50.0, "label": "Flame",
			"lost": "The flame has gone out between the cairns. Light another at the middle cairn.",
			"text": "Carry the flame on to the south cairn ({t} s)"},
		{"kind": "turnin", "who": "ysolt", "text": "Tell Ysolt the flame went the whole way"},
	],
	"reward": {"ash": 22, "items": {"ember_shard": 1}},
	"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}],
	"outcome": {"": "Ysolt watched the south cairn from the tor till the flame burned down. \"Two,\" she said. \"Two lit at once. That hasn't been since before the edict.\""}}

const FOUNDER_POUR := {"name": "The Pour", "giver": "elspeth", "where": "Elspeth Fane, at her fire in the Founder's Pits", "zone": "foundry",
	"offer": true, "avail": "qd:founder_slag",
	"text": "Bronze has a minute. Less, in this cold. It comes off the furnace white and it is a bell if you get it to the mould, and a lump if you don't. I've cast thirty-one bells in these pits and my knees have not been up to the heap since the Night. Take the ladle. Run. Don't slop it; it's the last of the good tin.",
	"steps": [
		{"kind": "find", "at": Vector2(128.0, -105.0), "text": "Take the ladle of white bronze from the Founder's furnace"},
		{"kind": "carry", "from": "pour_ladle", "to": Vector2(137.0, -79.0), "r": 4.0, "time": 35.0, "label": "Bronze",
			"lost": "The bronze has set in the ladle. The furnace has more.",
			"text": "Run the bronze to the mould on the slag heap before it sets ({t} s)"},
		{"kind": "turnin", "who": "elspeth", "text": "Tell Elspeth Fane the mould is full"},
	],
	"reward": {"ash": 22, "items": {"ember_shard": 2}},
	"choose": [{"set": "bell", "slot": "focus", "rarity": 2}, {"set": "bell", "slot": "vestment", "rarity": 2}, {"set": "bell", "slot": "lantern", "rarity": 2}],
	"outcome": {"": "Elspeth knocked on the cooling mould with a knuckle and listened. \"Sound,\" she said, and then, quieter, \"Mother would have said sound.\""}}

const ORCHARD_STAND := {"name": "The Graft Takes", "giver": "linnet", "where": "Linnet, at her fire in the Cinder Orchard", "zone": "orchard",
	"offer": true, "avail": "qd:orchard_graft",
	"text": "The old tree is warm, and warm is when a graft takes or doesn't. I've cut a scion from the one living bud. Bind it in yourself; my hands shake. Then stay with it. It takes a quarter of an hour in the open, and everything in the rows that smells green will come to see. They're not to touch it.",
	"steps": [
		{"kind": "find", "at": Vector2(-104.0, 110.0), "text": "Take the scion Linnet has cut and wrapped"},
		{"kind": "carry", "from": "scion_linnet", "to": Vector2(-84.5, 117.5), "r": 5.5, "time": 80.0, "label": "Scion",
			"lost": "The scion has dried in your hand. Linnet has cut another.",
			"text": "Carry the scion to the old tree at the heart of the rows before it dries ({t} s)"},
		{"kind": "slay", "of": 6, "region": "orchard", "label": "What comes for the graft", "at": Vector2(-90.0, 120.0),
			"text": "Stand by the old tree while the graft takes: put down what comes for it ({n}/{of})"},
		{"kind": "turnin", "who": "linnet", "text": "Tell Linnet the graft has taken"},
	],
	"reward": {"ash": 24, "items": {"relic_fragment": 1}},
	"choose": [{"set": "kindler", "slot": "focus", "rarity": 2}, {"set": "kindler", "slot": "vestment", "rarity": 2}, {"set": "kindler", "slot": "lantern", "rarity": 2}],
	"outcome": {"": "Linnet went down the rows at dawn with her thumbnail out. \"Green,\" she said, at the old tree, and then, a long way off, \"Green.\""}}

const FIELD_ROUND := {"name": "The Sexton's Round", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
	"offer": true, "avail": "qd:field_ranks",
	"text": "The sexton walked the ranks end to end every night, and said the count at the gate and again at the last stone, so the field knew nobody was missing. I have the gate. I cannot do the walk, and it must be walked, not skipped to. Go to the head of the ranks and go down them, and whatever gets up on the way, put back.",
	"steps": [
		{"kind": "visit", "at": Vector2(-18.0, 114.0), "r": 8.0, "label": "The head of the ranks", "text": "Begin the round at the head of the pilgrims' ranks"},
		{"kind": "slay", "of": 5, "region": "necropolis", "label": "Risen from the ranks", "at": Vector2(-12.0, 128.0),
			"text": "Go down the ranks and put back what rises on the way ({n}/{of})"},
		{"kind": "visit", "at": Vector2(-12.0, 142.0), "r": 9.0, "label": "The last stone", "text": "Finish the round at the last stone of the ranks"},
		{"kind": "turnin", "who": "agathe", "text": "Say the count with Sister Agathe at the gate"},
	],
	"reward": {"ash": 20, "items": {"relic_fragment": 1}},
	"choose": [{"set": "tally", "slot": "vestment", "rarity": 2}, {"set": "tally", "slot": "girdle", "rarity": 2}, {"set": "tally", "slot": "lantern", "rarity": 2}],
	"outcome": {"": "Agathe said the count at the gate, and you said it back, and for the first time in years there was a voice from the last stone that said it with you."}}

const MERE_FERRY := {"name": "The Last Crossing", "giver": "cadoc", "where": "Cadoc the ferryman, on the mere's north bank", "zone": "mere",
	"offer": true, "avail": "qd:mere_lamps",
	"text": "The ferry ran lit, always: a lamp at the bow going over, another at the stern coming back, so the water knew the boat was full. I can't row it, and I won't do it half. Take my lamp to the east landing. Somebody waits there with another. Bring that one back, lit, and don't let either go out. The mere has been waiting for a full boat nine winters.",
	"steps": [
		{"kind": "find", "at": Vector2(110.0, 99.0), "text": "Take the ferry-lamp from Cadoc's bow-post"},
		{"kind": "carry", "from": "ferry_lamp_out", "to": Vector2(128.0, 114.0), "r": 6.0, "time": 75.0, "label": "Ferry-lamp",
			"lost": "The ferry-lamp has guttered in the wet. Cadoc has another.",
			"text": "Carry the ferry-lamp to the east landing before it gutters ({t} s)"},
		{"kind": "find", "at": Vector2(129.0, 112.0), "text": "Take the passenger's lamp, burning on the east landing"},
		{"kind": "carry", "from": "ferry_lamp_back", "to": Vector2(111.0, 97.0), "r": 6.0, "time": 95.0, "label": "Passenger's lamp",
			"lost": "The passenger's lamp has gone out on the way back. It will be lit on the east landing again.",
			"text": "Carry the passenger's lamp back to Cadoc's landing ({t} s)"},
		{"kind": "turnin", "who": "cadoc", "text": "Tell Cadoc the boat came back full"},
	],
	"reward": {"ash": 24, "items": {"relic_fragment": 1}},
	"choose": [{"set": "ferryman", "slot": "focus", "rarity": 2}, {"set": "ferryman", "slot": "vestment", "rarity": 2}, {"set": "ferryman", "slot": "lantern", "rarity": 2}],
	"outcome": {"": "Cadoc held the passenger's lamp up against the dark and looked at it a long time. \"Full,\" he said. \"There. Now I can take her out, if I ever have the arms.\""}}

const PICKUPS := {
	"foreman_stone": {"quest": "quarry_stone", "step": 0, "near": Vector2(-116.0, -96.0), "kind": "mark", "name": "the foreman's founding-stone", "verb": "Lift",
		"say": "A squared stone the size of a loaf, a name cut in the top and the cutters' mark under it. It has been sat in the same hollow so long the moss has a shape for it. It is heavier than it looks, and you carry it down."},
	"foreman_place": {"quest": "quarry_stone", "step": 2, "near": Vector2(-127.0, -101.0), "kind": "place", "name": "the foot of the last step", "verb": "Set the stone at",
		"say": "You settle the stone against the last step, the name turned up. It sits as if it had been waiting sixty years for the level."},
	"moor_flame_fire": {"quest": "moor_fires", "step": 0, "near": Vector2(133.0, -12.0), "camp": "ysolt", "kind": "coal", "name": "a flame from Ysolt's fire", "verb": "Take",
		"say": "A coal in a hollowed stone, cupped in sheep's wool against the wind. It burns low and level. It does not like the open."},
	"moor_flame_mid": {"quest": "moor_fires", "step": 2, "near": Vector2(147.0, 2.0), "kind": "coal", "name": "the middle cairn's flame", "verb": "Light a flame at",
		"say": "You hold the wool to the old coal until it takes. The cairn's stones are warm on every side. Somebody has been lighting this one for a long time."},
	"pour_ladle": {"quest": "founder_pour", "step": 0, "near": Vector2(128.0, -105.0), "kind": "coal", "name": "a ladle of white bronze", "verb": "Lift",
		"say": "The ladle's iron handle is wound with wet rag, and the bronze in it is the colour of the inside of the sun. The heat comes through the rag. It is already thinking about setting."},
	"scion_linnet": {"quest": "orchard_stand", "step": 0, "near": Vector2(-104.0, 110.0), "camp": "linnet", "kind": "bud", "name": "Linnet's scion", "verb": "Take",
		"say": "A finger of green wood, wrapped in damp wool and waxed at the cut. It has two buds. Linnet has marked one with a thread, which means she has named it."},
	"ferry_lamp_out": {"quest": "mere_ferry", "step": 0, "near": Vector2(110.0, 99.0), "camp": "cadoc", "kind": "lantern_lit", "name": "the ferry-lamp", "verb": "Take",
		"say": "A bow-lamp on a boat-hook, the oil still sweet. It has hung on this post every night for nine winters, lit, and every night Cadoc has put it out himself."},
	"ferry_lamp_back": {"quest": "mere_ferry", "step": 2, "near": Vector2(129.0, 112.0), "kind": "lantern_lit", "name": "the passenger's lamp", "verb": "Take",
		"say": "Another lamp, older, set on the stones where the east landing meets the water. It burns upright, a little steadier than a lamp should in this wind. Nobody is with it. It is waiting for the boat."},
}
