extends RefCounted
## Texts of the secrets (house style of docs/LORE.md: terse, concrete, dark), their names, and
## the items they hand out. No class_name. The journal (ui/codex.gd) only knows lore_db ids, so
## these read in the secrets' own panel and are remembered in Travel.system_state("secrets").pages.

const SECRETS := {
	"bells": {"name": "The Fallen Bells", "region": "rift"},
	"spill": {"name": "The Founder's Spill", "region": "rift"},
	"bridge": {"name": "The Rim Bridge", "region": "rift"},
	"barrow": {"name": "The Upturned Barrow", "region": "barrows"},
	"cist": {"name": "Ansel's Cist", "region": "chapel"},
	"crypt": {"name": "Corvin's Drowned Crypt", "region": "fen"},
	"oak": {"name": "The Hollow Oak", "region": "thornwood"},
	"postern": {"name": "The Lay Brothers' Stair", "region": "fen"},
	"pell": {"name": "Pell's Den", "region": "hearth"},
	"cairn": {"name": "Hobb's Cairn", "region": "crags"},
	# r28 (agent D): the Lower Count under the Ossuary, and new secrets in the valley
	"lower_count": {"name": "The Uncounted Cells", "region": "ossuary"},
	"count_drum": {"name": "The Count Drum", "region": "ossuary"},
	"weighing": {"name": "The Weighing Floor", "region": "ossuary"},
	"hoard": {"name": "The Abbot's Hoard", "region": "ossuary"},
	"singing": {"name": "The Singing Stones", "region": "glade"},
	"breath": {"name": "The Ash-Hermit's Perch", "region": "rift"},
	"company": {"name": "The Ninth Company's Ring", "region": "thornwood"},
	# r34 places (site_doubled_realm.gd): the new ground's hidden things
	"cutters_nook": {"name": "The Cutters' Nook", "region": "quarry"},
	"ninth_rank": {"name": "The Ninth Rank", "region": "necropolis"},
	"corvin_sluice": {"name": "Corvin's Sluice", "region": "mere"},
	# the Pilgrims' Threshold (site_threshold.gd): the ids are the old landing's, the place is the chapel
	"last_landing": {"name": "The Pilgrims' Chapel", "region": "rift"},
	"upward_falls": {"name": "The Upward Falls' Crest", "region": "sorrow"},   # the Upward Falls' crest (site_upward_falls.gd)
	"star_crater": {"name": "The Fallen Star", "region": "saltpans"},
	"sky_chain": {"name": "The Wardens' Tally", "region": "crags"},   # the Sky Chain's bitter end (site_sky_chain.gd)   # the Star-Fall Crater's platform (site_star_crater.gd)
	# --- south marches ---
	"oak_crown": {"name": "The Crown of the Oak", "region": "oak"},
	"well_listener": {"name": "The Listener's Cairn", "region": "well"},
	# --- west marches ---
	"aldith_walk": {"name": "Aldith's Walk", "region": "sorrow"},
	# --- the east marches ---
	"boathouse": {"name": "The Sunken Boat-House", "region": "stillwater"},
	"salt_vault": {"name": "The Brine-Clerk's Vault", "region": "saltpans"},
}

## The ten secrets of r23 (zz/secrets_test walks these; the r28 ones have zz/secret_expansion_test).
const ORIGINAL := ["bells", "spill", "bridge", "barrow", "cist", "crypt", "oak", "postern", "pell", "cairn"]

const TEXTS := {
	"sc_sky_chain": {"title": "Cut into the tally stone", "kind": "carved stone",
	"text": "One thousand and nine links, forged in the Pits and hauled up hand over hand. We count them every dusk from the ring to the sky, and every dusk it comes out one short. The Hierarch says the sky is taking one back. I say the sky is not taking. I say the chain is getting longer. Pilgrims leave their names in the box. Take what helps."},
	"sc_star": {"title": "The surveyors' slate", "kind": "slate",
	"text": "Fall at the first turning. Glass to a depth of eleven spans; the heart keeps its height as the sky keeps its. Warm on the north face. We leaned a ladder to it and the ladder came down glass. Brother Ostric says it is a Wound. Under it, scratched later: I climbed. It is not a wound. It is a window, and whatever is on the other side is not angry. Leave the case. Take it."},
	"sc_upward_falls": {"title": "Cut into the crest's coping", "kind": "carved stone",
	"text": "SURVEY OF THE SORROW, ninth year of the lift. The water climbs the steps at four paces a breath and does not tire. We were to carry it to the abbey. It does not want the abbey. Last night I stood where the sheet leaves the bowl and put my hand in it, and it did not wet me. It went up through my fingers like a held note. The Order will want this written as a success. I have written it as a staircase."},
	"sc_bells": {"title": "The bell-frame", "kind": "carved beam",
		"text": "Hope, Patience, Homecoming: the Stair's three bells, carried up on the backs of the faithful. On the Night they stopped from the top down. The Founder swore they would ring again when the pilgrims came home. From the bottom up."},
	"sc_founder": {"title": "The Founder's ledger", "kind": "ledger leaf",
		"text": "Ash for the mould, bronze for the bell, a name for each. I cast Homecoming last and largest. My boy Brannoc can cast the forty little ones for the Stair. Nobody asked me why. Nobody came down to ask."},
	"sc_barrow_door": {"title": "The barrow door", "kind": "carved stone",
		"text": "SEALED BY ORDER OF ABBOT OSRIC UNTIL THE BELLS RING UP AGAIN. Scratched under it, smaller: they will not."},
	"sc_barrow": {"title": "The upturned dead", "kind": "carved stone",
		"text": "The Rooted laid their dead face down, so they would not look up. The abbey turned this one over to face the sky and sealed him in on a bell's promise. He has waited a long time to be wrong."},
	"sc_ansel_way": {"title": "A penitent's mark", "kind": "carved stone",
		"text": "I knelt where the road counts down: at twelve, at seven, at three. At three I could see the Stair, and I was ashamed, and I stopped. Kneel as I did. A."},
	"sc_ansel_cist": {"title": "Ansel's tin", "kind": "letter",
		"text": "A scraped chisel, a coal wrapped in wet leaves, and this: I took her face. She did not need it. Her hands were full."},
	"sc_rite": {"title": "Corvin's rite", "kind": "carved post",
		"text": "For the sunk: a light for the eyes, a light for the mouth, a light for the heart. None for the hand that weighed them down. None for the crown that counted them."},
	"sc_corvin": {"title": "Corvin's lamp", "kind": "inscription",
		"text": "He lit the sunk so they could see their way up. The Order said up was not theirs to choose. He went on lighting. They took his hands for it, and he went on."},
	"sc_oak": {"title": "The fifth verse", "kind": "old carving",
		"text": "Cut in the heartwood, in the Rooted's hand, a verse no stone carries: The thorn asked for a heart. The oak gave its own, and stood hollow ever after, and kept the wood anyway."},
	"sc_spill": {"title": "The Founder's furnace", "kind": "inscription",
		"text": "She kept her furnace under the rim, where the Order could not see the smoke. The Night cracked it. It has poured ever since. It does not know the bells are cast."},
	"sc_bridge": {"title": "Windlass plate", "kind": "plaque",
		"text": "RIM CROSSING. Wind it in behind you. If the bells ring, wind it out for whoever comes."},
	"sc_postern": {"title": "The postern bar", "kind": "plaque",
		"text": "THE LAY BROTHERS' STAIR. Barred on the fen side, so that what is counted does not climb."},
	"sc_pell": {"title": "A child's slate", "kind": "slate",
		"text": "A red hood, folded small. Four thousand steps in scratched tallies, crossed out. Under them, in a child's hand: TOO MANY. GONE HOME."},
	"sc_hobb": {"title": "Hobb's cairn", "kind": "carved stone",
		"text": "On the top stone: HOBB, SON OF MAUD. I CAN SEE HER CANDLE FROM HERE. The stones under it say nothing. He went on up."},
	# --- the Lower Count (under the Ossuary) ---------------------------------------------------
	"sc_deep_slab": {"title": "The sexton's slab", "kind": "carved stone",
		"text": "HERE THE COUNT GOES DOWN. Cut deep, and under it, scratched with a nail: and the counter with it."},
	"sc_deep_sexton": {"title": "The sexton's day-book", "kind": "ledger leaf",
		"text": "Osric counts the faithful above. I count the ones he will not: the half-burnt, the unbaptised, the ones who came back. Every shelf is owed its number. Every number is owed a name. I have run out of names."},
	"sc_deep_rule": {"title": "The sexton's rule", "kind": "carved stone",
		"text": "Set each wheel to what its shelf holds, and the Abbot's bridge comes up out of the dark. Count true. He weighs a wrong count."},
	"sc_deep_drum": {"title": "The Count Drum", "kind": "inscription",
		"text": "Turn the count and the dead go round. One door, four ways, and one of them to the Abbot's own. He kept the light out of it. Light was the one thing he could not number."},
	"sc_deep_window": {"title": "The pool window", "kind": "plaque",
		"text": "A bronze for catching the lamp the sexton sank in the pool. The Order forbade it: the light below is not the sky's. The sexton polished it every night anyway, and pointed it where he liked."},
	"sc_deep_weigh": {"title": "The Weighing Floor", "kind": "carved stone",
		"text": "Every soul came here before a shelf. Bone on the one pan, the Abbot's stone on the other. None was ever light enough to go up. The stone was hollow. It was full of lead."},
	"sc_deep_hoard": {"title": "The true tally", "kind": "ledger leaf",
		"text": "Faithful counted above: eleven thousand and four. Uncounted below: twice that. Sent up by the Abbot's hand to the open sky: none. Kept, for the day the sky asks for the full number: all."},
	# --- the valley ----------------------------------------------------------------------------
	"sc_sing_listen": {"title": "The listening stone", "kind": "old carving",
		"text": "Four mouths cut in a ring, and in the Rooted's hand: the stones will sing back what the small stone sings to you. Sing it wrong and they go quiet and wait."},
	"sc_sing_done": {"title": "The fifth mouth", "kind": "old carving",
		"text": "Under the roots, a verse the Order never found: we sang the wood awake each spring. It answered in lights. When the singing stopped, the lights went looking for us."},
	"sc_breath": {"title": "The hermit's slate", "kind": "slate",
		"text": "The rift breathes. Count nine and it breathes out, hot enough to lift a man who jumps into it. I have been up and down this way for nine winters. Nobody has followed. Good."},
	"sc_breath_top": {"title": "The hermit's last word", "kind": "slate",
		"text": "From up here you can watch the Crossing and nobody can watch you. I watched the pilgrims go up. I watched them come down hollow. I stayed up here where the air is warm and I did not go."},
	# --- r34 places (site_doubled_realm.gd) -------------------------------------------------------------
	"sc_landing": {"title": "Cut into the kneeling stone", "kind": "carved stone",
		"text": "We cut this where the light comes down, because the Order would not have us in the abbey. Forty-one of us went up the night the sky turned. Eleven came back down the tower stair. We put what they carried in the box and our names on the wall. Whoever kneels here: the light is not theirs. It is only falling."},
	"sc_nook": {"title": "Pinned under a chisel", "kind": "page",
		"text": "Cutters' rule: what we cut for the Stair, the Order owns. What we cut for ourselves we keep up here, where the Order's men will not climb. Take your share. Leave the chisels."},
	"sc_rank_slate": {"title": "The warden's slate", "kind": "slate",
		"text": "The ninth rank, for the lamps: first the one who walked furthest to lie here, then the one who waited longest for the sky, and last the one who never knew what she was waiting for."},
	"sc_sluice": {"title": "Scratched on the lamp-post", "kind": "carved post",
		"text": "Corvin's lamp. When they took my boat I built a road under the water to the last lamp, and let it down again behind me so the Order could not follow. C."},
	"sc_lever": {"title": "A plate on the lever", "kind": "plaque",
		"text": "SLUICE. Do not pull without leave of the lamp-brother. Under it, newer: he is not coming. Pull it."},
	# --- south marches ---
	"sc_oak_top": {"title": "A leaf of the Rooted's reckoning", "kind": "bark leaf",
		"text": "Nine springs we sang up the stair and the oak sang back, a note under the note. The Order's axes bit it on the tenth and it stopped, not dead: listening. We hid the knot where the sky sees it and the Order will not climb. Whoever climbs: sing it one line. It will know the tune."},
	"sc_well_listener": {"title": "Scratched on the cairn", "kind": "carved stone",
		"text": "I sat here nine nights with the falls at my back and listened to it answer. It does not repeat you. It tells you what you will say next. On the ninth night I said nothing, and it said my name, and I said nothing again, and it said it again. Go up. Do not answer."},
	# --- west marches (site_west_marches.gd) ---
	"sc_aldith": {"title": "Scratched on the lamp-post", "kind": "carved post",
		"text": "Aldith's lamp. The river took her roof and then the saint. I cut a road under the water to the last lamp and let it down behind me, because the ford is for the living and this is for what they paid. A."},
	"sc_aldith_ring": {"title": "A plate on the ring", "kind": "plaque",
		"text": "RING. One pull, and let go. The slabs come up on their own. Under it, in a miller's hand: the river does not mind. It was never the river's lamp."},
	# --- the east marches ---
	"sc_boat_lamp": {"title": "Scratched on a rafter", "kind": "carved beam",
		"text": "When the lamp went dark the boats stopped coming in. We left ours here, roof-deep, tied to the posts, so the lake would remember where the shore was. Oil in the loft. Take it. Carry it up."},
	"sc_boat_log": {"title": "The boat-keeper's tin", "kind": "letter",
		"text": "Forty-one nights I rowed out to see the Spire's flame from the water. It always looked nearer than it was. That is the lamp's whole art."},
	"sc_vault_slate": {"title": "The brine-clerk's slate", "kind": "slate",
		"text": "The three valves, for the strongroom, in the order the brine runs: first the east pan, where the salt is oldest; then the west, where it is whitest; last the middle, which never was a pan. Turn them wrong and the sluice floods the floor."},
	"sc_vault_plate": {"title": "A plate on the winch", "kind": "plaque",
		"text": "STRONGROOM. The works' own ash, laid by against a bad winter. It has been a bad winter for nine years. Open it."},
}

## Items handed out. relic_fragment is new (no ItemDB entry yet; the progression agent owns
## core/items/item_db.gd). Suggested definition, for them to adopt:
const ITEM_SUGGEST := {
	"relic_fragment": {"name": "Relic Fragment", "kind": "material", "shape": "shard", "tint": Color(0.78, 0.72, 0.95),
		"desc": "A sliver of something the faithful once kissed: bell-bronze, saint's bone, heartwood. The Order kept them in gold. The fires keep them better.",
		"text": "Found in the valley's hidden places. A kindled fire knows what to make of it."},
}

const REWARDS := {
	"sky_chain": {"relic_fragment": 1, "grave_ash": 35, "grave_iron": 1},
	"star_crater": {"relic_fragment": 1, "grave_ash": 35, "ember_shard": 1},
	"upward_falls": {"relic_fragment": 2, "grave_ash": 36, "ember_shard": 1},
	"bells": {"grave_ash": 30},
	"barrow": {"relic_fragment": 1, "grave_ash": 20},
	"cist": {"relic_fragment": 1, "grave_ash": 15},
	"crypt": {"relic_fragment": 1, "grave_ash": 20},
	"oak": {"relic_fragment": 1, "grave_ash": 20},
	"spill": {"relic_fragment": 1, "grave_ash": 25},
	"pell": {"grave_ash": 10},
	"cairn": {"relic_fragment": 1, "grave_ash": 15},
	"elite": {"grave_ash": 15},
	"deep_cells": {"relic_fragment": 1, "grave_ash": 20},
	"deep_sexton": {"grave_ash": 30},
	"deep_hoard": {"relic_fragment": 2, "grave_ash": 60},
	"singing": {"relic_fragment": 1, "grave_ash": 25},
	"breath": {"relic_fragment": 1, "grave_ash": 30},
	"company": {"relic_fragment": 1, "grave_ash": 30},
	"cutters_nook": {"relic_fragment": 1, "grave_ash": 25, "grave_iron": 2},
	"ninth_rank": {"relic_fragment": 1, "grave_ash": 30},
	"corvin_sluice": {"relic_fragment": 1, "grave_ash": 25},
	"last_landing": {"relic_fragment": 2, "grave_ash": 40, "ember_shard": 1},
	# --- south marches ---
	"oak_crown": {"relic_fragment": 2, "grave_ash": 35},
	"well_listener": {"relic_fragment": 1, "grave_ash": 30, "grave_iron": 1},
	# --- west marches ---
	"aldith_walk": {"relic_fragment": 1, "grave_ash": 28},
	# --- the east marches ---
	"boathouse": {"relic_fragment": 1, "grave_ash": 25, "ember_shard": 1},
	"salt_vault": {"relic_fragment": 1, "grave_ash": 30},
}


static func entry(id: String) -> Dictionary:
	return TEXTS.get(id, {})


static func item_name(id: String) -> String:
	if ItemDB.DEFS.has(id):
		return String(ItemDB.def(id).name)
	if ITEM_SUGGEST.has(id):
		return String(ITEM_SUGGEST[id].name)
	return id.capitalize()
