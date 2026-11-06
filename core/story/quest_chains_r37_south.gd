extends RefCounted
## The South pass's three task chains (data only; quest_chains.gd lists each one at the end of its
## tables, in a block marked r37 south, so the ledger, the audit and the world find them). No class_name.
##   shepherd_strays  Dunstan Pike, the shepherd who stayed (a camp at the fold on the southern downs):
##                    raise the flock's three fallen marker-cairns, put down the Bell-Wether who still leads
##                    them, tell him the road is marked
##   oak_song         Gammer Ruan of the Rooted Holds: go and look at the Grandmother Oak, put down the
##                    Root-Wife who keeps its roots, climb to the crown for what the Rooted hid there
##   well_answer      Cadoc the ferryman, whose mere lies north of the Well: stand on the rim, put down the
##                    Answerer on the landing, find the listener's cairn behind the falls
## Steps use the existing kinds (gather, slay with a named rare, visit, cond on an elite or a secret,
## turnin); the cairns are ground pickups on the open downs.

const ZONES := [["downs", "The Southern Downs"], ["oak", "The Grandmother Oak"], ["well", "The Well of Echoes"]]

const ORDER := ["shepherd_strays", "oak_song", "well_answer"]

const GIVERS := {"dunstan": "Dunstan Pike"}

const RARE_IDS := ["bell_wether", "flint_hound"]

const QUESTS := {
	"shepherd_strays": {"name": "The Flock's Road", "giver": "dunstan", "where": "Dunstan Pike, at his fold on the southern downs", "zone": "downs",
		"offer": true,
		"text": "Three cairns marked the flock's road home across the downs, and all three are down. In fog the flock followed the cairns. Without them the Bell-Wether leads, and what follows it is not a flock any longer. Dunstan wants the road marked, and the Bell-Wether put down.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Raise the three fallen sheep-walk cairns on the southern downs ({n}/{of})"},
			{"kind": "slay", "of": 1, "rares": ["bell_wether"], "at": Vector2(-30.0, 222.0), "label": "The Bell-Wether",
				"text": "Put down the Bell-Wether, who still leads the flock"},
			{"kind": "turnin", "who": "dunstan", "text": "Tell Dunstan the flock's road is marked"},
		],
		"reward": {"ash": 22, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "vestment", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"": "Dunstan stood a long while at the fold gate, looking south along the cairns. \"There,\" he said. \"Now if any of them are coming home they know which way.\""}},
	"oak_song": {"name": "What the Oak Kept", "giver": "ruan", "where": "Gammer Ruan, at her fire in the Rooted Holds", "zone": "oak",
		"offer": true, "avail": "kindled:1",
		"text": "The first fire was carried out of the Grandmother Oak, in a knot of its own heart, and the Rooted hid the knot where the Order would not climb. Ruan is too old for the stair. She wants to know the oak is whole, that something does not wear its roots, and that the knot is still where they left it.",
		"steps": [
			{"kind": "visit", "at": Vector2(-70.0, 206.0), "r": 16.0, "label": "The Grandmother Oak", "text": "Go to the Grandmother Oak on the southern downs, and look up"},
			{"kind": "cond", "cond": "elite:root_wife", "text": "Put down the Root-Wife, who keeps the oak's roots"},
			{"kind": "cond", "cond": "secret:found:oak_crown", "text": "Climb the stair inside the oak to its crown, and find what the Rooted hid"},
			{"kind": "turnin", "who": "ruan", "text": "Tell Gammer Ruan what the oak kept"},
		],
		"reward": {"ash": 30, "items": {"relic_fragment": 2}},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "girdle", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"": "Ruan held her hands out for the leaf, and read it with her thumbs. \"It listened,\" she said. \"Nine springs it sang to us and I never once sang back. Well. Somebody has.\""}},
	"well_answer": {"name": "What Answers", "giver": "cadoc", "where": "Cadoc the ferryman, at his fire on Corvin's Mere", "zone": "well",
		"offer": true, "avail": "kindled:2",
		"text": "Cadoc hears it on still nights from across the mere, the Well, calling his name back to him a breath after the dead called it. He will not row that way. He wants whatever answers put down, and to know what it was listening for.",
		"steps": [
			{"kind": "visit", "at": Vector2(72.0, 204.0), "r": 26.0, "label": "The Well of Echoes", "text": "Walk to the Well of Echoes, south of the mere, and look down"},
			{"kind": "cond", "cond": "elite:well_answer", "text": "Go down the ledge and put down the Answerer, on the landing by the cave"},
			{"kind": "cond", "cond": "secret:found:well_listener", "text": "Find the listener's cairn, on the ledge where the falls pour across it"},
			{"kind": "turnin", "who": "cadoc", "text": "Tell Cadoc what answered"},
		],
		"reward": {"ash": 30, "items": {"relic_fragment": 1, "ember_shard": 1}},
		"choose": [{"slot": "vestment", "rarity": 2}, {"slot": "girdle", "rarity": 2}, {"slot": "focus", "rarity": 2}],
		"outcome": {"": "Cadoc listened to all of it with the oar across his knees. \"Then it was never the dead calling me,\" he said. \"It was only practising. I think I can sleep, now. Don't tell the lamps.\""}},
}

const PICKUPS := {
	"cairn_down_1": {"quest": "shepherd_strays", "step": 0, "near": Vector2(-96.0, 226.0), "kind": "cairn", "name": "a fallen sheep-walk cairn", "verb": "Raise",
		"say": "Four stones and a fifth for luck, spilled across the chalk. You stack them the way the flock's road wants them, the top stone turned north."},
	"cairn_down_2": {"quest": "shepherd_strays", "step": 0, "near": Vector2(-6.0, 227.0), "kind": "cairn", "name": "a fallen sheep-walk cairn", "verb": "Raise",
		"say": "The middle cairn, scattered by something with hooves. The stones are warm on one side, and there is a bell-note in the wind."},
	"cairn_down_3": {"quest": "shepherd_strays", "step": 0, "near": Vector2(40.0, 229.0), "kind": "cairn", "name": "a fallen sheep-walk cairn", "verb": "Raise",
		"say": "The last cairn, nearest the Well. A tuft of wool has caught in the stones. You raise them again; the wool stays."},
}
