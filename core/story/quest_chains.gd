extends RefCounted
## The tasks Hearthward's people and the Keg's regulars set the wanderer (story; no class_name).
## Data only; state lives in quest_book.gd, the world side in quest_world.gd (pickups, the escort,
## the hollowed man) and quest_runner.gd (counts, places, carried coals), the words in
## dialogue_db.gd (the Keg) and village_talk_db.gd (the village).
##   QUESTS   {id: {name, giver, where, zone, text, steps: [{text, kind, who?}], reward, alt?,
##            offer?, avail?, repeat?, choose?}}
##            kind: find (a pickup in PICKUPS), reach (go there: quest_world watches the distance),
##            gather (several pickups, `of`), talk (a conversation with `who` moves it on), escort
##            (ESCORT), kill (the hollowed man in HOLLOW), place (put something back: a pickup used
##            as a spot); r33 (quest_runner.gd):
##              slay     put down `of` foes [of `kinds` (script names)] [in `region` (RealmLayout id)]
##              collect  the same foes drop `label` with `chance`, `of` wanted
##              seal     the guards of seal `seal` (counted from Events.seal_progress; done when broken)
##              cond     a world condition holds (QuestDB terms: boss:x, seal:x ...); `at` for the map
##              visit    come within `r` of `at` (xz)
##              carry    take pickup `from` (the step before), bring it within `r` of `to` inside
##                       `time` seconds, or it goes out and the task falls back a step
##              turnin   done: bring it back to `who` (the "?" over their head; the turn-in screen)
##            `alt`: {pick: {step: text}} replaces a step's text after a choice. {n} in a step's text
##            = how many were found / put down, {of} = how many are wanted.
##            r33 "offer" tasks are not set in conversation: the giver's "!" and the accept screen
##            (ui/quest_offer.gd) start them, `avail` (a VillageState condition) says when the giver
##            has it; `repeat: "daily"` comes back each day once handed in; `choose`: gear the
##            wanderer picks one of at the turn-in (GearDB.make opts: slot, rarity, set, legend).
##            r34: a slay / collect step may want `rare: true` (only a named rare, Enemy meta
##            "rare_id", counts: core/enemy/rares.gd) or `rares: [ids]` (only those rares, anywhere:
##            a WoW rare bounty); a carry step's `lost` is the toast when it
##            goes out; `raid`: the boss whose attunement chain the task belongs to (ATTUNE).
##   PICKUPS  world things a step wants: {quest, step, near (xz), kind (mesh), name, verb, say}
##   ESCORT / HOLLOW  the two moving pieces (Joram's walk, Father Harrow)
## House style (docs/LORE.md): terse, concrete, dark. Load by path.

# --- south marches ---
const South := preload("res://core/story/quest_chains_south_marches.gd")
## West marches: Weirford's four chains (quest_chains_west_marches.gd), listed in the blocks marked `# --- west marches ---`.
const R37WQ := preload("res://core/story/quest_chains_west_marches.gd")

## The ledger's chapters (ui/quest_log.gd), in order: [id, name].
const ZONES := [["hearth", "Hearthward"], ["road", "The Pilgrims' Road"], ["thornwood", "The Thornwood"],
	["fen", "The Hollow Fen"], ["holds", "The Rooted Holds"], ["quarry", "The Saints' Quarry"],
	["moor", "The Lanternless Moor"], ["foundry", "The Founder's Pits"], ["orchard", "The Cinder Orchard"],
	["necropolis", "The Waiting Field"], ["mere", "Corvin's Mere"],
	["ossuary", "The Ossuary"], ["rift", "The Ashen Rift"], ["crags", "The Crowns"], ["summit", "The Summit of Ascension"],
	["downs", "The Southern Downs"], ["oak", "The Grandmother Oak"], ["well", "The Well of Echoes"],
	R37WQ.ZONES[0], R37WQ.ZONES[1], R37WQ.ZONES[2], R37WQ.ZONES[3],
	["stillwater", "Stillwater"], ["anchorholds", "The Anchorholds"], ["saltmarket", "Saltmarket"], ["saltpans", "The White Pans"],
	Towns.ZONES[0], Towns.ZONES[1], Towns.ZONES[2], FRW.ZONE, FRS.ZONE, FRE.ZONE]

## Act II's signature tasks, one a country (quest_chains_signature.gd), listed after the east marches' in each table.
const Sig := preload("res://core/story/quest_chains_signature.gd")
const Bells := preload("res://core/story/quest_chains_bells.gd")   ## the eight bells (the seven far countries' and the Marches'): quests and pickups
const LiveSteps := preload("res://core/story/encounter_kit.gd")
const EastChains := preload("res://core/story/quest_chains_east_marches.gd")   ## the east marches: its tasks and pickups are listed in the `# --- the east marches ---` blocks
const ThrQ := preload("res://core/story/quest_chains_threshold.gd")   ## the Pilgrims' Threshold: the chapel under the starfall
const ChainQ := preload("res://core/story/quest_chains_sky_chain.gd")   ## the Sky Chain: Elspeth's count of the links
const StarQ := preload("res://core/story/quest_chains_star_crater.gd")   ## the Star-Fall Crater: Marl's task at the Lamp
const R37UF := preload("res://core/story/quest_chains_upward_falls.gd")   ## the Upward Falls: Osk's task at the Order's weir
## twelve one-time tales in the Marches and the south (east, south, west files), listed in the blocks marked `# --- tales ---`.
const R38E := preload("res://core/story/quest_chains_r38_east.gd")
const R38S := preload("res://core/story/quest_chains_r38_south.gd")
const R38W := preload("res://core/story/quest_chains_r38_west.gd")
const Towns := preload("res://core/story/quest_chains_reach_towns.gd")   ## the towns (Reedholm, Fallowmere, Lastlight): the `# --- the towns ---` blocks
const FRW := preload("res://core/story/quest_chains_far_reaches_west.gd")   ## the three Reaches' threads and side tasks, given by the towns' people: the `# --- the reaches ---` blocks
const FRS := preload("res://core/story/quest_chains_far_reaches_south.gd")
const FRE := preload("res://core/story/quest_chains_far_reaches_east.gd")
const VQ := preload("res://core/story/quest_chains_verbs.gd")   ## Hearthward's five tasks deepened with the task verbs (docs/QUEST_VERBS.md)
const VerbKit := preload("res://core/story/verb_kit.gd")
const DC := preload("res://core/story/quest_chains_deepen_c.gd")   ## the Far Reaches' signature tasks (Relief, A Night of Charcoal, The Rope Rung Right)
const DeepB := preload("res://core/story/quest_chains_deepen_b.gd")   ## the deepened tasks (docs/QUEST_DEPTH.md)
const DA := preload("res://core/story/quest_chains_deepen_a.gd")   ## writer A: the deepened Hearthward / Thornwood / fen tasks and the two new ones (three_knocks, forty_days)

const _ORDER := ["edda_tongs", "forty_first", "names_yard", "keg_thief", "slow_way",
	"hearth_ash", "road_clear", "coal_shrine", "spire_lamps", "alms_loaf",
	"thorn_door", "smoke_oaks", "ring_heart", "unpaid_toll",
	"bead_count", "drowned_bell", "count_below", "crossing_ward", "threshold_chapel",
	# r34: the doubled world's hubs (a giver per new region) and the raids' attunements
	"holds_turf", "keeper_wards", "keeper_heart", "keeper_leave",
	"quarry_marks", "quarry_picks", "quarry_last", "quarry_chisel", "quarry_due",
	"moor_cairns", "moor_stumbled", "moor_shrine", "moor_hennet", "moor_wind",
	"founder_slag", "founder_clapper", "chain_count", "founder_moulds", "founder_peal",
	"orchard_buds", "orchard_press", "orchard_graft", "orchard_pippin", "orchard_ash",
	"field_ranks", "field_last", "abbot_roll", "abbot_cords", "abbot_names",
	"mere_lamps", "mere_chapel", "mere_light", "mere_ferryman", "mere_oil",
	# r36 Act II: the Founder's peal
	"founders_peal", "bell_spire", "bell_holds", "bell_quarry", "bell_moor", "bell_foundry", "bell_orchard", "bell_necropolis", "bell_mere",
	# r36 the keep's standing bounties
	"keg_tab", "rare_head", "keeper_again",
	# r36 Act III: the door
	"the_latch", "still_climbing", "names_under", "full_peal",
	"shepherd_strays", "oak_song", "well_answer",
	"wf_wheel", "wf_upward", "wf_watch", "wf_lights", "wf_crown",
	"salt_sweep", "salt_widow", "star_lamp", "spire_coal", "anchor_names", "anchor_vow",
	"bounds_beaten", "quarry_stone", "moor_fires", "founder_pour", "orchard_stand", "field_round", "mere_ferry",
	# --- tales ---
	"pans_hauler", "pans_pan", "salt_barrel", "bitter_mother", "drover_tally", "long_round", "bryn_iron", "wren_gran",
	"plinth_lamp", "cutters_pledge", "landing_staves", "moor_niches",
	"rh_lamps", "fm_tithe", "ll_gate", "ll_oil",          # --- the towns ---
	"wr_stand_down", "wr_kings_lamp", "wr_cold_light", "wr_fourth_stone", "wr_tansys_boat", "ds_water_road", "ds_unmade", "ds_witchs_price", "ds_clapper",
	"er_ringers_candle", "er_nave_fire", "er_halter_bell", "er_inn_slate",          # --- the reaches ---
	"wr_relief", "ds_charcoal", "er_rope",          # --- deepen C ---
	# --- deepen B ---
	"seventh_day",
	# --- deepen A ---
	"three_knocks", "forty_days"]

## The story seat's tasks, pickups and givers (quest_chains_added.gd) are merged in once, at first use: the const tables above are the older ones.
const Added := preload("res://core/story/quest_chains_added.gd")
static var ORDER: Array = _ORDER + Added.order()
static var QUESTS: Dictionary = _merge(_QUESTS, Added.quests())
static var PICKUPS: Dictionary = _merge(_PICKUPS, Added.pickups())
static var GIVER_NAMES: Dictionary = _merge(_GIVER_NAMES, Added.givers())


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := a.duplicate()
	d.merge(b)
	return d


## Who stands where, for the map's turn-in pins when the person is not in the night's tree.
const _GIVER_NAMES := {"hild": "Hild", "fennick": "Old Fennick", "oswin": "Joram", "nan": "Nan Wright", "abel": "Abel the sexton",
	"wyck": "Wyck", "grisel": "Grisel", "keep": "The keep", "harrow": "Ostrin Harrow", "hesk": "Hesk", "brannoc": "Brannoc",
	"ruan": "Gammer Ruan", "jory": "Jory Quell", "ysolt": "Ysolt the cairn-keeper", "elspeth": "Elspeth Fane",
	"linnet": "Linnet the grafter", "agathe": "Sister Agathe", "cadoc": "Cadoc the ferryman",
	"dunstan": "Dunstan Pike",
	"osk": "Osk the miller", "cassel": "Captain Cassel", "ennis": "Sister Ennis", "tolliver": "Old Tolliver",
	"dorrit": "Dorrit Marl", "bryn": "Bryn Gale", "wren": "Sedge", "gwyn": "Gwyn the ostler",
	"marl": "Marl Pannick", "teasel": "Teasel Dray", "orrin": "Orrin Vail", "ardel": "Ardel Wick", "pip": "Pip", "nella": "Nella Crake",
	"corle": "Aud Corle", "penn": "Reeve Penn", "coyle": "Serjeant Coyle", "isolde": "Old Isolde",      # --- the towns ---
	"siany": Towns.GIVER_NAMES["siany"], "ebba": Towns.GIVER_NAMES["ebba"], "hobb": Towns.GIVER_NAMES["hobb"], "dilly": Towns.GIVER_NAMES["dilly"], "hesper": Towns.GIVER_NAMES["hesper"],
	"cobb": Towns.GIVER_NAMES["cobb"], "maudlin": Towns.GIVER_NAMES["maudlin"], "wat": Towns.GIVER_NAMES["wat"], "vell": Towns.GIVER_NAMES["vell"], "fenn": Towns.GIVER_NAMES["fenn"], "gorse": Towns.GIVER_NAMES["gorse"], "wystan": Towns.GIVER_NAMES["wystan"]}      # --- the reaches ---

## r34: the raids' attunements (WoW's attunement chains, adapted): the last task of each pre-raid
## chain, once handed in, loosens the boss's hold (QuestBook.attuned(boss); Travel.story flag
## "attuned_<boss>"). Never required: the seals and the main story open the raids as before.
## r34: the named rares the bounties want (core/enemy/rares.gd RARES keys; checked by the audit
## against that file when it loads).
const RARE_IDS := ["old_rook", "brother_chisel", "hennet", "clapper", "old_pippin", "last_pilgrim", "ferryman",
	"bell_wether", "flint_hound",
	"drowned_reeve", "moss_mason", "gate_breaker",
	"salt_widow", "drowned_lamplighter",
	"keep_sentry", "lamp_wick", "heron_wife", "tithe_taker", "aqueduct_hound", "cracked_tollman", "cairn_counter"]      # --- the reaches ---

const ATTUNE := {"thornwarden": "keeper_leave", "bone_abbot": "abbot_names", "ascended_warden": "founder_peal"}

const _QUESTS := {
	"edda_tongs": {"name": "Edda's Tongs", "giver": "hild", "where": "Hild, at Edda's forge", "zone": "hearth",
		"text": "Edda's tongs lie on her stone in the Kindlers' Yard. Hild wants them back on the anvil, and cannot make herself fetch them.",
		"steps": [
			{"kind": "find", "text": "Find Edda's tongs on her stone in the Kindlers' Yard, west past Abel's dig"},
			{"kind": "talk", "who": "hild", "text": "Bring Edda's tongs to Hild at the forge"},
			{"kind": "place", "text": "Lay Edda's tongs back on her stone in the Kindlers' Yard"},
		],
		"reward": {"ash": 10, "items": {"ember_shard": 1}},
		"outcome": {"forge": "Hild shod your staff with a ferrule of Edda's iron. The tongs work the forge again.",
			"stone": "Edda's tongs lie on her stone again. It stays warm."}},
	"forty_first": DA.QUESTS["forty_first"],
	"names_yard": DA.QUESTS["names_yard"],
	"keg_thief": VQ.KEG_THIEF,
	"slow_way": VQ.SLOW_WAY,
	# --- r33: tasks set by the giver's mark and the accept screen ----------------------------------
	# Hearthward: the Hearthfire's dailies and Fennick's errands
	"hearth_ash": {"name": "Ash for the Hearthfire", "giver": "fennick", "where": "Old Fennick, on his lamp round", "zone": "hearth",
		"offer": true, "repeat": "daily",
		"text": "The green's fire eats more than it used to. Ash off the hollowed burns slow and hot, if you can stand to carry it. Five handfuls. Every night, if you like. The fire won't stop being hungry.",
		"steps": [
			{"kind": "collect", "of": 5, "chance": 0.6, "label": "Bone ash", "at": Vector2(-30.0, 62.0), "text": "Gather bone ash from the hollowed you put down ({n}/{of})"},
			{"kind": "turnin", "who": "fennick", "text": "Bring the bone ash to Old Fennick"},
		],
		"reward": {"ash": 12, "items": {"ember_shard": 2}},
		"outcome": {"": "The green's fire took the bone ash and burned blue for an hour."}},
	"road_clear": {"name": "The Road Kept Clear", "giver": "grisel", "where": "Grisel the ash-wife, at her cart", "zone": "road",
		"offer": true, "repeat": "daily",
		"text": "Nobody buys from a cart they can't reach. The hollowed have the Pilgrims' Road again. Thin them, and I'll thin my prices. A little.",
		"steps": [
			{"kind": "slay", "of": 6, "region": "road", "label": "Hollowed on the Road", "at": Vector2(-30.0, 62.0),
				"text": "Put down the hollowed on the Pilgrims' Road ({n}/{of})"},
			{"kind": "turnin", "who": "grisel", "text": "Tell Grisel the road is clear"},
		],
		"reward": {"ash": 10, "items": {"relic_fragment": 1}},
		"outcome": {"": "The road is clear for a night. Grisel's cart went out as far as the third waystone."}},
	"coal_shrine": {"name": "A Coal for the Shrine", "giver": "fennick", "where": "Old Fennick, on his lamp round", "zone": "hearth",
		"offer": true,
		"text": "The shrine in the Glimmer Glade was lit from the green's fire, once, coal to coal. Carry one there. Don't dawdle; a coal won't wait for you, and the dark will try to drink it.",
		"steps": [
			{"kind": "find", "text": "Take a live coal from the green's fire"},
			{"kind": "carry", "from": "coal", "to": Vector2(-31.0, 4.0), "r": 5.0, "time": 100.0, "label": "Coal",
				"text": "Carry the coal to the shrine brazier in the Glimmer Glade before it dies ({t} s)"},
			{"kind": "turnin", "who": "fennick", "text": "Tell Old Fennick the shrine has the green's fire"},
		],
		"reward": {"ash": 10},
		"choose": [{"slot": "lantern", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
		"outcome": {"": "The shrine in the glade burns with the green's fire again, coal to coal."}},
	"spire_lamps": VQ.SPIRE_LAMPS,
	"alms_loaf": VQ.ALMS_LOAF,
	# the Thornwood: Wyck's chain toward the Ring, and Hesk's grudge
	"thorn_door": {"name": "Thorns at the Door", "giver": "wyck", "where": "Wyck, at his fire in the Thornwood", "zone": "thornwood",
		"offer": true,
		"text": "The thorn seal on the Ring's hill has guards. Hollowed things, set like stakes along the wood's edge. Put them down and the seal breaks. Then the Thornwarden will come to see who's knocking.",
		"steps": [
			{"kind": "seal", "seal": "henge", "label": "Thorn seal guards", "at": Vector2(-50.0, -8.0),
				"text": "Put down the thorn seal's guards on the Thornwood edge ({n}/{of})"},
			{"kind": "turnin", "who": "wyck", "text": "Tell Wyck the thorn seal is broken"},
		],
		"reward": {"ash": 15},
		"choose": [{"slot": "focus", "rarity": 1}, {"slot": "vestment", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
		"outcome": {"": "The thorn seal is broken. Wyck felt it in his teeth."}},
	"smoke_oaks": {"name": "Smoke Under the Oaks", "giver": "wyck", "where": "Wyck, at his fire in the Thornwood", "zone": "thornwood",
		"offer": true, "avail": "qd:thorn_door",
		"text": "Somebody's burning charcoal in the Hollow, deep under the oaks. Three clamps, and nobody tending them. The wood smells it. The hollowed come to it like it's a hearth. Go and see. Thin them on the way.",
		"steps": [
			{"kind": "visit", "at": Vector2(-86.0, -62.0), "r": 20.0, "label": "The Charcoal Hollow", "text": "Find the Charcoal Hollow deep in the Thornwood"},
			{"kind": "slay", "of": 4, "region": "thornwood", "label": "Hollowed in the Thornwood", "at": Vector2(-84.0, -30.0),
				"text": "Put down the hollowed in the Thornwood ({n}/{of})"},
			{"kind": "turnin", "who": "wyck", "text": "Tell Wyck what burns in the Hollow"},
		],
		"reward": {"ash": 15, "items": {"relic_fragment": 1}},
		"outcome": {"": "Nobody tends the clamps in the Hollow. They burn anyway. Wyck says that's worse."}},
	"ring_heart": DA.QUESTS["ring_heart"],
	"unpaid_toll": DA.QUESTS["unpaid_toll"],
	# the Hollow Fen and the Ossuary: Abel's tally, Brannoc's bell
	"bead_count": DA.QUESTS["bead_count"],
	"count_below": {"name": "The Count Below", "giver": "abel", "where": "Abel the sexton, by the Kindlers' Yard", "zone": "ossuary",
		"offer": true, "avail": "qd:bead_count",
		"text": "The Abbot's still down there counting. Every one of them a number. Break the gallery seal, go down to his mound and stop him. Then the dead can lie down without being told how many they are.",
		"steps": [
			{"kind": "seal", "seal": "oss_gallery", "label": "Gallery seal guards", "at": Vector2(34.0, -66.0),
				"text": "Break the gallery seal in the Ossuary ({n}/{of})"},
			{"kind": "cond", "cond": "boss:bone_abbot", "at": Vector2(17.0, -80.0), "label": "The Bone Abbot",
				"text": "Stop the Bone Abbot's count on the charnel floor"},
			{"kind": "turnin", "who": "abel", "text": "Tell Abel the count has stopped"},
		],
		"reward": {"ash": 25},
		"choose": [{"set": "tally", "slot": "focus", "rarity": 2}, {"set": "tally", "slot": "vestment", "rarity": 2}, {"set": "tally", "slot": "girdle", "rarity": 2}],
		"outcome": {"": "Abel dug all night and didn't count once."}},
	"drowned_bell": VQ.DROWNED_BELL,
	# the summit: the keep's last word
	"crossing_ward": {"name": "The Ward on the Crossing", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "summit",
		"offer": true, "avail": "boss:thornwarden,boss:bone_abbot,qd:founders_peal",
		"text": "Heart and crown, and a peal behind you. The ward on the Crossing will know them. It has guards that don't sleep; put them down and it lets you through. Then the top. I'll keep your stool warm. Come back and sit on it.",
		"steps": [
			{"kind": "seal", "seal": "summit", "label": "Crossing guards", "at": Vector2(0.0, -70.9) + Endgame.O2,
				"text": "Put down the guards of the summit ward on the Crossing ({n}/{of})"},
			{"kind": "cond", "cond": "boss:ascended_warden", "at": Vector2(0.0, -103.9) + Endgame.O2, "label": "The Ascended Warden",
				"text": "Face what holds the door at the summit"},
			{"kind": "turnin", "who": "keep", "text": "Sit on your stool at the Kindled Keg"},
		],
		"reward": {"ash": 40},
		"choose": [{"legend": "door_splinter"}, {"legend": "sunk_shroud"}, {"legend": "unlit_lamp"}],
		"outcome": {"": "The keep poured, and didn't say anything for a long time. Then he said: kindled."}},

	# --- r34: the doubled world (docs/r34/layout.md): a giver in each new region, a short chain on
	# its lore line, a daily where there is ground to thin, and the raids' attunements -----------
	# the Rooted Holds: Gammer Ruan, and the Thornwarden's attunement (the keeper's wards)
	"holds_turf": DeepB.HOLDS_TURF,
	"keeper_wards": DeepB.KEEPER_WARDS,
	"keeper_heart": {"name": "Heartwood", "giver": "ruan", "where": "Gammer Ruan, at her fire in the Rooted Holds", "zone": "holds",
		"offer": true, "avail": "qd:keeper_wards", "raid": "thornwarden",
		"text": "The keeper rooted in a heart and fed the wood from it. The things under the oaks are fat on it still. Bring me splinters off them: heartwood, black and warm to hold. I'll burn it in the ward-fire, and the wood will smell what it was fed and know it for a grave.",
		"steps": [
			{"kind": "collect", "of": 5, "chance": 0.6, "region": "thornwood", "label": "Heartwood splinters", "at": Vector2(-100.0, -40.0),
				"text": "Take heartwood splinters from the hollowed under the Thornwood's oaks ({n}/{of})"},
			{"kind": "turnin", "who": "ruan", "text": "Bring the heartwood to Gammer Ruan"},
		],
		"reward": {"ash": 15},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"": "The heartwood burned green in Ruan's fire. The oaks to the east went quiet while it did."}},
	"keeper_leave": {"name": "Keeper, Keep", "giver": "ruan", "where": "Gammer Ruan, at her fire in the Rooted Holds", "zone": "holds",
		"offer": true, "avail": "qd:keeper_heart", "raid": "thornwarden",
		"text": "Take a coal from my fire, lit with its own heartwood, up the Ring's stair before it dies. Lay it at the head of the stair. If the keeper still stands, it will know us by it and fight you with one hand behind its back. Not out of kindness. Out of manners. If it does not, the Ring will know us anyway.",
		"steps": [
			{"kind": "find", "text": "Take a ward-coal from Gammer Ruan's fire"},
			{"kind": "carry", "from": "coal_ruan", "to": Vector2(-57.0, -17.0), "r": 6.0, "time": 150.0, "label": "Ward-coal",
				"lost": "The ward-coal has gone out. Gammer Ruan's fire has more.",
				"text": "Carry the ward-coal to the head of the Ring's stair before it dies ({t} s)"},
			{"kind": "turnin", "who": "ruan", "text": "Tell Gammer Ruan the keeper has its coal"},
		],
		"reward": {"ash": 20},
		"choose": [{"set": "kindler", "slot": "focus", "rarity": 2}, {"slot": "vestment", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
		"outcome": {"": "The keeper took the coal. In the Ring it will remember it was asked, not owned: it holds back a hand."}},
	# the Saints' Quarry: Jory Quell, the last cutter
	"quarry_marks": {"name": "Masons' Marks", "giver": "jory", "where": "Jory Quell, at his fire by the Saints' Quarry", "zone": "quarry",
		"offer": true,
		"text": "Every cutter cut his mark on the blocks he squared, so the Order could pay him by the stone. They stopped paying on the Night. The marks are still on the blocks nobody carried. Bring me three. I'll know the men by them.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Take the masons' marks off the abandoned blocks in the quarry ({n}/{of})"},
			{"kind": "turnin", "who": "jory", "text": "Bring the marks to Jory Quell"},
		],
		"reward": {"ash": 14},
		"choose": [{"slot": "focus", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
		"outcome": {"": "Jory read the marks with his thumb. Wat, Dunny, his own brother. He said the names, and then the wages owed."}},
	"quarry_picks": {"name": "Picks Put Down", "giver": "jory", "where": "Jory Quell, at his fire by the Saints' Quarry", "zone": "quarry",
		"offer": true, "avail": "qd:quarry_marks",
		"text": "The ones who went up came back down to work. They swing at the benches in the dark, cutting steps for a stair that isn't there any more. Put the picks down. Six of them. They've earned the rest.",
		"steps": [
			{"kind": "slay", "of": 6, "region": "quarry", "label": "Cutters on the benches", "at": Vector2(-126.0, -100.0),
				"text": "Put down the hollowed cutters on the quarry's benches ({n}/{of})"},
			{"kind": "turnin", "who": "jory", "text": "Tell Jory Quell the picks are down"},
		],
		"reward": {"ash": 16, "items": {"relic_fragment": 1}},
		"outcome": {"": "The benches are quiet. Jory says he can hear the stone settle, now nobody's cutting it."}},
	"quarry_last": DeepB.QUARRY_LAST,
	"quarry_chisel": {"name": "The Four-Thousandth", "giver": "jory", "where": "Jory Quell, at his fire by the Saints' Quarry", "zone": "quarry",
		"offer": true, "avail": "qd:quarry_picks",
		"text": "Brother Chisel blessed every step we cut. Four thousand blessings, and he counted them. He came back down with the cutters and he's still at it, on the pit floor, bigger than he was, blessing stone with his fists. He was a kind man. Put him down kindly. Hard, I mean.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["brother_chisel"], "label": "Brother Chisel", "at": Vector2(-136.0, -112.0),
				"text": "Put down Brother Chisel, the Four-Thousandth, on the quarry's floor"},
			{"kind": "turnin", "who": "jory", "text": "Tell Jory Quell the blessing is done"},
		],
		"reward": {"ash": 18, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
		"outcome": {"": "Jory cut a small step for Brother Chisel and set it at the pit's mouth. Nobody is to bless it."}},
	"quarry_due": {"name": "The Cutters' Due", "giver": "jory", "where": "Jory Quell, at his fire by the Saints' Quarry", "zone": "quarry",
		"offer": true, "repeat": "daily", "avail": "qd:quarry_marks",
		"text": "Nobody pays by the stone now. I pay by the hollowed. Thin the benches and I'll find you something off the shelf. Every night, if you like. They never stop coming down.",
		"steps": [
			{"kind": "slay", "of": 5, "region": "quarry", "label": "Hollowed in the quarry", "at": Vector2(-126.0, -100.0),
				"text": "Put down the hollowed in the Saints' Quarry ({n}/{of})"},
			{"kind": "turnin", "who": "jory", "text": "Collect the cutters' due from Jory Quell"},
		],
		"reward": {"ash": 10, "items": {"ember_shard": 1}},
		"outcome": {"": "Jory paid you in ember, by the stone, and wrote it in a book nobody keeps."}},
	# the Lanternless Moor: Ysolt the cairn-keeper (Edict I)
	"moor_cairns": {"name": "Cairns in the Dark", "giver": "ysolt", "where": "Ysolt, at her fire under the tor", "zone": "moor",
		"offer": true,
		"text": "The faithful crossed this moor without lanterns, by the cairns. The edict said lanterns were for doubters. The wind takes a stone a night off every cairn. Three are down to nothing. Raise them, so the next fool in the dark finds his way.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Raise the three fallen cairns on the moor ({n}/{of})"},
			{"kind": "turnin", "who": "ysolt", "text": "Tell Ysolt the cairns are standing"},
		],
		"reward": {"ash": 14},
		"choose": [{"slot": "lantern", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
		"outcome": {"": "Ysolt walked out to each cairn in the dark and counted the stones with her hands. She added one."}},
	"moor_stumbled": {"name": "The Ones Who Stumbled", "giver": "ysolt", "where": "Ysolt, at her fire under the tor", "zone": "moor",
		"offer": true, "avail": "qd:moor_cairns",
		"text": "The moor kept the ones who fell between the cairns. They still walk it, looking for the next one. They walk into people. Put six of them down, and leave the cairns alone; they'll want them.",
		"steps": [
			{"kind": "slay", "of": 6, "region": "moor", "label": "The stumbled", "at": Vector2(142.0, -24.0),
				"text": "Put down the hollowed walking the Lanternless Moor ({n}/{of})"},
			{"kind": "turnin", "who": "ysolt", "text": "Tell Ysolt the moor is quieter"},
		],
		"reward": {"ash": 15, "items": {"relic_fragment": 1}},
		"outcome": {"": "Ysolt says the wind sounds different with fewer feet in it."}},
	"moor_shrine": DeepB.MOOR_SHRINE,
	"moor_hennet": {"name": "The Gorse-Wife", "giver": "ysolt", "where": "Ysolt, at her fire under the tor", "zone": "moor",
		"offer": true, "avail": "qd:moor_stumbled",
		"text": "Hennet kept the gorse fire on the tor, before the edict. They put it out and her with it. She walks the whole moor now, north to south and back, faster than the wind. She's the one kicking the cairns down. Stop her. I'll raise her a cairn after.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["hennet"], "label": "Gorse-Wife Hennet", "at": Vector2(140.0, -4.0),
				"text": "Put down Gorse-Wife Hennet on her walk across the moor"},
			{"kind": "turnin", "who": "ysolt", "text": "Tell Ysolt the Gorse-Wife is down"},
		],
		"reward": {"ash": 16, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"outcome": {"": "Ysolt raised a cairn for Hennet under the tor, and put a sprig of gorse on top. It is the only cairn that points nowhere."}},
	"moor_wind": {"name": "Wind Off the Moor", "giver": "ysolt", "where": "Ysolt, at her fire under the tor", "zone": "moor",
		"offer": true, "repeat": "daily", "avail": "qd:moor_cairns",
		"text": "The wind takes the stones. Bring me stones. The hollowed carry them in their fists, God knows why. Four. Every night; the wind doesn't rest and neither do I.",
		"steps": [
			{"kind": "collect", "of": 4, "chance": 0.6, "region": "moor", "label": "Cairn-stones", "at": Vector2(142.0, -24.0),
				"text": "Take cairn-stones from the hollowed on the moor ({n}/{of})"},
			{"kind": "turnin", "who": "ysolt", "text": "Bring the cairn-stones to Ysolt"},
		],
		"reward": {"ash": 10, "items": {"ember_shard": 1}},
		"outcome": {"": "The cairns stand another night."}},
	# the Founder's Pits: Elspeth Fane, and the Ascended Warden's attunement (Mother's order)
	"founder_slag": {"name": "Cold Slag", "giver": "elspeth", "where": "Elspeth Fane, at her fire in the Founder's Pits", "zone": "foundry",
		"offer": true,
		"text": "Something sleeps in the slag heaps, where the ground's still warm. Hollowed, curled up like dogs at a hearth. I'd like the heaps back. I'd like to stop hearing them breathe in there.",
		"steps": [
			{"kind": "slay", "of": 5, "region": "foundry", "label": "Hollowed in the slag", "at": Vector2(140.0, -92.0),
				"text": "Put down the hollowed sleeping in the Founder's slag heaps ({n}/{of})"},
			{"kind": "turnin", "who": "elspeth", "text": "Tell Elspeth Fane the heaps are quiet"},
		],
		"reward": {"ash": 14},
		"choose": [{"set": "bell", "slot": "girdle", "rarity": 1}, {"set": "bell", "slot": "lantern", "rarity": 1}],
		"outcome": {"": "Elspeth sat on the warm slag and ate her bread, which she says she hasn't done since the Night."}},
	"founder_clapper": DeepB.FOUNDER_CLAPPER,
	"founder_moulds": {"name": "The Founder's Moulds", "giver": "elspeth", "where": "Elspeth Fane, at her fire in the Founder's Pits", "zone": "foundry",
		"offer": true, "raid": "ascended_warden",
		"text": "Her son cast the summit's bell, in her moulds, in three cheeks of loam and iron. The Hierarch's bell. Brannoc says the thing up there holds the door with it still in its hand. Bring me the moulds. A bell's mould knows its note, and I can teach it a wrong one.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Find the three cheeks of the great bell's mould: by the furnace, in the casting pits, under the slag ({n}/{of})"},
			{"kind": "turnin", "who": "elspeth", "text": "Bring the mould to Elspeth Fane"},
		],
		"reward": {"ash": 15, "items": {"relic_fragment": 1}},
		"outcome": {"": "Elspeth fitted the cheeks together on the furnace floor. The mould hummed when the wind crossed it."}},
	"founder_peal": {"name": "Mother's Order", "giver": "elspeth", "where": "Elspeth Fane, at her fire in the Founder's Pits", "zone": "foundry",
		"offer": true, "avail": "qd:founder_moulds", "raid": "ascended_warden",
		"text": "The rim bells fell when the Stair broke. Ring them where they lie, the way she taught: the great bell first, Homecoming, then Patience, then Hope. Bottom to top. Then take the tongue I've cast in her mould, out of the furnace, to her son at the Keg. He'll know what it's for. It's for the door.",
		"steps": [
			{"kind": "cond", "cond": "secret:solved:bells", "at": Vector2(-37.6, -27.0) + Endgame.O2, "label": "The Fallen Bells", "past": "The fallen bells are already rung.",
				"text": "Ring the fallen bells by the Rift in the Founder's order: Homecoming, Patience, Hope"},
			{"kind": "find", "text": "Take the bell-tongue Elspeth cast, from the Founder's furnace"},
			{"kind": "turnin", "who": "brannoc", "text": "Bring the warm tongue to Brannoc Bellwright at the Kindled Keg"},
		],
		"reward": {"ash": 25},
		"choose": [{"set": "bell", "slot": "focus", "rarity": 2}, {"set": "bell", "slot": "vestment", "rarity": 2}, {"set": "bell", "slot": "lantern", "rarity": 2}],
		"outcome": {"": "Brannoc keeps the warm tongue by him. Up at the summit, the great bell in the Warden's hand will ring wrong, Mother's way."}},
	# the Cinder Orchard: Linnet the grafter (the Kindlers' orchard)
	"orchard_buds": {"name": "A Living Bud", "giver": "linnet", "where": "Linnet, at her fire in the Cinder Orchard", "zone": "orchard",
		"offer": true,
		"text": "They burned it so the Kindlers would have nothing. Burned wood still has a living eye in it sometimes, under the char. Find me three green buds. I'll graft them on a stock and see what grows from a heresy.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Find three living buds on the burned trees of the Cinder Orchard ({n}/{of})"},
			{"kind": "turnin", "who": "linnet", "text": "Bring the buds to Linnet"},
		],
		"reward": {"ash": 12},
		"choose": [{"set": "kindler", "slot": "girdle", "rarity": 1}, {"set": "kindler", "slot": "lantern", "rarity": 1}],
		"outcome": {"": "Linnet bound the buds into a stock with wax and wool. One of them is already greener."}},
	"orchard_press": DeepB.ORCHARD_PRESS,
	"orchard_graft": {"name": "Fire Under the Roots", "giver": "linnet", "where": "Linnet, at her fire in the Cinder Orchard", "zone": "orchard",
		"offer": true, "avail": "qd:orchard_press",
		"text": "A graft takes if the stock is warm. Nothing in this orchard's been warm since they burned it. Carry a coal from my fire to the heart of the rows and lay it under the old tree. It's the Kindlers' fire. The orchard was always theirs.",
		"steps": [
			{"kind": "find", "text": "Take a coal from Linnet's fire"},
			{"kind": "carry", "from": "coal_linnet", "to": Vector2(-84.5, 117.5), "r": 5.5, "time": 70.0, "label": "Coal",
				"lost": "The coal has gone out in the ash. Linnet's fire has more.",
				"text": "Carry the coal to the old tree at the heart of the rows before it dies ({t} s)"},
			{"kind": "turnin", "who": "linnet", "text": "Tell Linnet the old tree is warm"},
		],
		"reward": {"ash": 18},
		"choose": [{"set": "kindler", "slot": "focus", "rarity": 2}, {"set": "kindler", "slot": "vestment", "rarity": 2}, {"set": "kindler", "slot": "lantern", "rarity": 2}],
		"outcome": {"": "A coal sleeps under the old tree at the heart of the rows. Linnet swears the bark split green by morning."}},
	"orchard_pippin": {"name": "The Ash-Grub", "giver": "linnet", "where": "Linnet, at her fire in the Cinder Orchard", "zone": "orchard",
		"offer": true, "avail": "qd:orchard_press",
		"text": "Something under the rows eats roots. Big as a barrel, and it's had nine winters of nothing but ash to grow fat on. The brothers called the old tree Pippin. I think that's what's left of whoever slept under it. Dig it out.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["old_pippin"], "label": "Old Pippin, the Ash-Grub", "at": Vector2(-96.0, 140.0),
				"text": "Put down Old Pippin, the Ash-Grub, under the burned rows"},
			{"kind": "turnin", "who": "linnet", "text": "Tell Linnet the roots are safe"},
		],
		"reward": {"ash": 16, "items": {"relic_fragment": 1}},
		"choose": [{"set": "kindler", "slot": "girdle", "rarity": 2}, {"slot": "focus", "rarity": 2}],
		"outcome": {"": "Linnet planted a seed where the Ash-Grub came up. She says that's the only grave an orchard needs."}},
	"orchard_ash": {"name": "Ash for the Roots", "giver": "linnet", "where": "Linnet, at her fire in the Cinder Orchard", "zone": "orchard",
		"offer": true, "repeat": "daily", "avail": "qd:orchard_buds",
		"text": "Ash feeds a root. Ash off the hollowed feeds it hot. Five handfuls from the rows, every night you're passing. It's slow work, an orchard.",
		"steps": [
			{"kind": "collect", "of": 5, "chance": 0.6, "region": "orchard", "label": "Root ash", "at": Vector2(-110.0, 122.0),
				"text": "Gather ash from the hollowed in the Cinder Orchard ({n}/{of})"},
			{"kind": "turnin", "who": "linnet", "text": "Bring the root ash to Linnet"},
		],
		"reward": {"ash": 10, "items": {"ember_shard": 1}},
		"outcome": {"": "Linnet dug the ash in round the grafts with her hands."}},
	# the Waiting Field: Sister Agathe, and the Bone Abbot's attunement (the pilgrims' roll)
	"field_ranks": DeepB.FIELD_RANKS,
	"field_last": {"name": "The Last Pilgrim", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
		"offer": true, "avail": "qd:field_ranks",
		"text": "The last pilgrim who died on the road before the Night is buried at the end of the ranks. He got up. He walks the field looking for the gate to the Stair, and he won't believe there isn't one. Put him back in his row. He was always last; let him be first to lie down.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["last_pilgrim"], "label": "The Last Pilgrim", "at": Vector2(-12.0, 140.0),
				"text": "Put the Last Pilgrim back in his rank in the Waiting Field"},
			{"kind": "turnin", "who": "agathe", "text": "Tell Sister Agathe the last of them is lying down"},
		],
		"reward": {"ash": 16, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"outcome": {"": "Agathe turned the Last Pilgrim's stone to face the village. 'He's seen the mountain,' she said."}},
	"abbot_roll": {"name": "The Pilgrims' Roll", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
		"offer": true, "raid": "bone_abbot",
		"text": "Every pilgrim buried here was written in the roll, by name. The Abbot took the books and wrote numbers over them. Three pages got away from him. Find them. A name read aloud at the door of the count is the one thing he can't add up.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Find the three pages of the pilgrims' roll: by the mausoleum, in the ranks, at the lay brothers' lodge in the Barrow Field ({n}/{of})"},
			{"kind": "turnin", "who": "agathe", "text": "Bring the roll's pages to Sister Agathe"},
		],
		"reward": {"ash": 15, "items": {"relic_fragment": 1}},
		"outcome": {"": "Agathe sewed the three pages together with a hair from her own head. 'Names,' she said. 'Not one number.'"}},
	"abbot_cords": {"name": "Cut the Count", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
		"offer": true, "avail": "qd:abbot_roll", "raid": "bone_abbot",
		"text": "His bone-walkers carry the count on knotted cords. Every knot is somebody. Cut me four cords off them and the count goes slack. Whatever keeps it down there will feel it, a stitch dropped.",
		"steps": [
			{"kind": "collect", "of": 4, "chance": 0.75, "kinds": ["ossuant"], "label": "Tally-cords", "at": Vector2(96.0, -30.0),
				"text": "Cut tally-cords from the bone-walkers of the fen and the Barrow Field ({n}/{of})"},
			{"kind": "turnin", "who": "agathe", "text": "Bring the tally-cords to Sister Agathe"},
		],
		"reward": {"ash": 15},
		"choose": [{"set": "tally", "slot": "vestment", "rarity": 2}, {"set": "tally", "slot": "girdle", "rarity": 2}],
		"outcome": {"": "Agathe unpicked every knot, and named nobody. Some things you only undo."}},
	"abbot_names": {"name": "Called by Name", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
		"offer": true, "avail": "qd:abbot_cords", "raid": "bone_abbot",
		"text": "Take the roll down to the Ossuary's bone bridge, under the Waiting Field, and read it, all of it, into the dark. If the Abbot still counts, he goes to his count and finds it short, and a counter who comes up short begins to doubt. If he doesn't, the dead will have been read to, which is what a name is for.",
		"steps": [
			{"kind": "visit", "at": Vector2(-40.0, 146.0), "r": 10.0, "label": "The Ossuary's bone bridge", "text": "Read the pilgrims' roll aloud at the Ossuary's bone bridge"},
			{"kind": "turnin", "who": "agathe", "text": "Tell Sister Agathe the names were read"},
		],
		"reward": {"ash": 25},
		"choose": [{"set": "tally", "slot": "focus", "rarity": 2}, {"set": "tally", "slot": "lantern", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
		"outcome": {"": "Under the abbey the count stopped, and started again from one, and stopped. The Abbot doubts."}},
	# Corvin's Mere: Cadoc the ferryman (Saint Corvin's lamps)
	"mere_lamps": {"name": "Corvin's Lamps", "giver": "cadoc", "where": "Cadoc the ferryman, on the mere's north bank", "zone": "mere",
		"offer": true,
		"text": "Brother Corvin rowed fire out to the sunk dead, so they'd not lie in the dark. His lamps drift in to the banks now, cold. Bring me three. I'll fill them and row them back out. Somebody has to; he's got no hands.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Find three of Corvin's lamps drifted onto the mere's banks ({n}/{of})"},
			{"kind": "turnin", "who": "cadoc", "text": "Bring the lamps to Cadoc the ferryman"},
		],
		"reward": {"ash": 12},
		"choose": [{"set": "ferryman", "slot": "lantern", "rarity": 1}, {"set": "ferryman", "slot": "girdle", "rarity": 1}],
		"outcome": {"": "Cadoc filled the lamps from his own oil and set them on the water. They went out toward the chapel without being pushed."}},
	"mere_chapel": {"name": "The Half-Sunk Chapel", "giver": "cadoc", "where": "Cadoc the ferryman, on the mere's north bank", "zone": "mere",
		"offer": true, "avail": "qd:mere_lamps",
		"text": "Corvin's chapel is half under now. The things in the water go there to stand in the nave, like a congregation waiting for a sermon. Wade out. Thin the flock.",
		"steps": [
			{"kind": "visit", "at": Vector2(80.0, 112.0), "r": 14.0, "label": "The half-sunk chapel", "text": "Wade out to the half-sunk chapel in the west mere"},
			{"kind": "slay", "of": 5, "region": "mere", "label": "The drowned flock", "at": Vector2(100.0, 124.0),
				"text": "Put down the hollowed in Corvin's Mere ({n}/{of})"},
			{"kind": "turnin", "who": "cadoc", "text": "Tell Cadoc the nave is empty"},
		],
		"reward": {"ash": 15, "items": {"relic_fragment": 1}},
		"outcome": {"": "The chapel's nave stands empty to the knee in black water. Cadoc says Corvin preached to fish in the end, and the fish listened."}},
	"mere_light": DeepB.MERE_LIGHT,
	"mere_ferryman": DeepB.MERE_FERRYMAN,
	"mere_oil": {"name": "Oil for the Lamps", "giver": "cadoc", "where": "Cadoc the ferryman, on the mere's north bank", "zone": "mere",
		"offer": true, "repeat": "daily", "avail": "qd:mere_lamps",
		"text": "The lamps drink oil like the drowned drink dark. The hollowed in the mere carry it in their bellies, from the lamps they ate. Five. Every night. The mere is long.",
		"steps": [
			{"kind": "collect", "of": 5, "chance": 0.6, "region": "mere", "label": "Lamp-oil", "at": Vector2(100.0, 124.0),
				"text": "Take lamp-oil from the hollowed in Corvin's Mere ({n}/{of})"},
			{"kind": "turnin", "who": "cadoc", "text": "Bring the oil to Cadoc the ferryman"},
		],
		"reward": {"ash": 10, "items": {"ember_shard": 1}},
		"outcome": {"": "Corvin's lamps burn on the mere another night."}},
	# --- r36 Act II: the Founder's peal. The summit ward knows heart and crown, but the door was hung
	# to a bell: it opens to a peal (BELLS_NEEDED of the eight: one answered bell wakes it, and every further bell weakens the one who holds it). Each far country's last giver has its
	# bell; a named keeper holds it; at the bell the wanderer rings it there (the country quiets) or
	# lifts the tongue out for Hearthward (the Keg rings it when the Warden is faced: he holds less).
	"founders_peal": {"name": "The Founder's Peal", "giver": "brannoc", "where": "Brannoc Bellwright, at the Keg", "zone": "summit",
		"offer": true, "avail": "boss:thornwarden,boss:bone_abbot",
		"text": "Mother cast seven for the road up, and an eighth for the ones outside it. One for each country the pilgrims crossed, and one for the country they were shut out of. When the sky opened they went quiet, top first. The door at the summit hangs from a bell; it won't open to a heart and a crown alone. It opens to a peal. Find me one. Any one of the eight will do for the door, and I'd start with the nearest. Every bell after that is a thing the one up there will feel: the ones you ring where they hang, a little; the ones you carry down to my chimney, a good deal more. Eight, if you've the legs.",
		"steps": [
			{"kind": "cond", "cond": "peal:1", "past": "A bell of the Founder's is already answered.", "text": "Answer for a Founder's bell ({bells} of 8: one wakes the door; each more weakens the one who holds it. The nearest hangs at the Rooted Holds, Gammer Ruan's fire)"},
			{"kind": "turnin", "who": "brannoc", "text": "Tell Brannoc the door will hear a peal"},
		],
		"start_spell": "peal",          # Brannoc teaches it on the taking up (quest_book.gd start): the bells are answered with it
		"reward": {"ash": 30, "items": {"ember_shard": 2}},
		"choose": [{"set": "bell", "slot": "focus", "rarity": 3}, {"set": "bell", "slot": "vestment", "rarity": 3}, {"set": "bell", "slot": "girdle", "rarity": 3}],
		"outcome": {"": "Brannoc counted the bells on his fingers twice, the second time slower. \"She'd have liked you,\" he said. \"She liked people who finished things.\""}},
	"bell_spire": Bells.QUESTS["bell_spire"], "bell_holds": Bells.QUESTS["bell_holds"], "bell_quarry": Bells.QUESTS["bell_quarry"], "bell_moor": Bells.QUESTS["bell_moor"],
	"bell_foundry": Bells.QUESTS["bell_foundry"], "bell_orchard": Bells.QUESTS["bell_orchard"], "bell_necropolis": Bells.QUESTS["bell_necropolis"], "bell_mere": Bells.QUESTS["bell_mere"],
	# --- r36 the grind: the keep's standing bounties, every night. The Keg's tab pays for the dark
	# thinned, a named rare's head, and the bell keepers, who come back
	"keg_tab": {"name": "The Keg's Tab", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "hearth",
		"offer": true, "repeat": "daily", "avail": "flag:met_keep",
		"text": "I keep a tab for the dark. Every hollowed you put down comes off it. Twenty, and I'll stand you ember and a bed. Every night. The tab never closes.",
		"steps": [
			{"kind": "slay", "of": 20, "label": "Hollowed anywhere", "at": Vector2(-30.0, 62.0), "text": "Put down hollowed anywhere in the Reaches ({n}/{of})"},
			{"kind": "turnin", "who": "keep", "text": "Have the keep strike them off the tab"},
		],
		"reward": {"ash": 18, "items": {"ember_shard": 2}},
		"outcome": {"": "The keep made twenty marks on the slate behind the bar and wiped them off with his sleeve."}},
	"rare_head": {"name": "A Named Head", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "hearth",
		"offer": true, "repeat": "daily", "avail": "bosses:1",
		"text": "The ones with names walk the same rounds every night. Bring me word one of them's down. Any of them. I pay better for names.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["old_rook", "brother_chisel", "hennet", "clapper", "old_pippin", "last_pilgrim", "ferryman"],
				"label": "A named rare", "text": "Put down one of the named rares that walk the Reaches"},
			{"kind": "turnin", "who": "keep", "text": "Tell the keep whose name to cross out"},
		],
		"reward": {"ash": 22, "items": {"relic_fragment": 2}},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "vestment", "rarity": 2}, {"slot": "lantern", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
		"outcome": {"": "The keep crossed the name out. It'll be back on the slate tomorrow, in his handwriting."}},
	"keeper_again": {"name": "The Keepers Come Back", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "hearth",
		"offer": true, "repeat": "daily", "avail": "q:founders_peal",
		"text": "Brannoc says the things that kept his mother's bells come back to them. Of course they do. Put one down again. He'll pay in iron; I pay in ash.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["kin_caller", "bell_hewer", "fog_shepherd", "slag_born", "ash_sower", "passing_ringer", "fare_caller"],
				"label": "A bell keeper", "text": "Put down one of the bells' keepers, wherever it walks"},
			{"kind": "turnin", "who": "keep", "text": "Tell the keep which bell is quiet tonight"},
		],
		"reward": {"ash": 26, "items": {"grave_iron": 2, "ember_shard": 2}},
		"choose": [{"slot": "focus", "rarity": 3}, {"slot": "vestment", "rarity": 3}, {"slot": "lantern", "rarity": 3}, {"slot": "girdle", "rarity": 3}],
		"outcome": {"": "Brannoc paid in iron, as promised, and said nothing, which for Brannoc is thanks."}},
	# --- r36 Act III: the door. The keep thinks it shut when the Warden fell. Brannoc knows a door hung
	# to a bell is shut by a bell and held by a latch, and the latch fell out of Aurel's hand into yours.
	"the_latch": {"name": "Shut Is Not Latched", "giver": "brannoc", "where": "Brannoc Bellwright, at the Keg", "zone": "summit",
		"offer": true, "avail": "boss:ascended_warden,flag:ending_told",
		"text": "Shut, he says. Shut isn't latched. Mother hung that door, and a door she hung is held by its latch, and the latch is in your satchel. Go back up. Put it in the door, or don't. I can't tell you which. I only know which she'd have done, and she was wrong about things.",
		"steps": [
			{"kind": "visit", "at": Vector2(0.0, -103.9) + Endgame.O2, "r": 8.0, "label": "The door in the sky", "text": "Climb back to the Warden's dais, under the door"},
			{"kind": "find", "text": "Decide what the latch is for"},
			{"kind": "turnin", "who": "brannoc", "text": "Tell Brannoc what you did at the door"},
		],
		"alt": {"latched": {2: "Tell Brannoc the door is latched"}, "open": {2: "Tell Brannoc the door is left on the latch"}, "broken": {2: "Tell Brannoc the latch is broken"}},
		"reward": {"ash": 40, "items": {"relic_fragment": 3}},
		"choose": [{"legend": "door_splinter"}, {"legend": "sunk_shroud"}, {"legend": "unlit_lamp"}, {"legend": "stair_rope"}],
		"outcome": {"latched": "Brannoc nodded once. \"Then nothing new goes up. Nothing new comes through. She'd have done that. She liked things finished.\"",
			"open": "\"On the latch,\" Brannoc said. \"So the ones still climbing can turn round. That's kinder than she was.\"",
			"broken": "Brannoc looked at the two halves of the latch for a long time. \"Then it's only sky,\" he said. \"Just sky. I don't know if that's better. Nobody does.\""}},
	"still_climbing": {"name": "Those Still Climbing", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
		"offer": true, "avail": "qd:the_latch",
		"text": "Nine winters of the half-way up are still coming home down the road. The door only stopped sending more. Not all of them know they're dead. Some walk into the Field and stand in their old places. Some walk into it with their hands out. Put down the ones with their hands out.",
		"steps": [
			{"kind": "slay", "of": 8, "region": "necropolis", "label": "The ones who came down", "at": Vector2(-4.0, 124.0),
				"text": "Put down the hollowed who came down into the Waiting Field ({n}/{of})"},
			{"kind": "turnin", "who": "agathe", "text": "Tell Sister Agathe the Field is quiet"},
		],
		"reward": {"ash": 30, "items": {"ember_shard": 3}},
		"choose": [{"set": "tally", "slot": "lantern", "rarity": 3}, {"set": "tally", "slot": "focus", "rarity": 3}],
		"outcome": {"": "Agathe counted the ones who stood in their old places and didn't hold out their hands. Forty-one. She left them standing."}},
	"names_under": {"name": "Names Under the Door", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "summit",
		"offer": true, "avail": "qd:still_climbing",
		"text": "The dais stone. 'The names of the faithful who went through,' and nothing cut under it. I've been thinking about that. Ask about. Get me a name from six of the far fires, nine keep one, somebody who went up, and cut them in. Then come and sit down. For good, this time.",
		"steps": [
			{"kind": "gather", "of": 6, "text": "Ask a name of the faithful at any six fires of the far country, the Marches and the towns past the Lines among them ({n}/{of})"},
			{"kind": "find", "text": "Cut the names into the dais stone under the door"},
			{"kind": "turnin", "who": "keep", "text": "Sit on your stool at the Kindled Keg"},
		],
		"reward": {"ash": 50},
		"choose": [{"set": "bell", "slot": "focus", "rarity": 4}, {"set": "bell", "slot": "vestment", "rarity": 4}, {"set": "bell", "slot": "lantern", "rarity": 4}, {"set": "bell", "slot": "girdle", "rarity": 4}],
		"outcome": {"": "The keep poured two. He drank his and then, after a while, yours. \"Somebody should,\" he said."}},
	"full_peal": {"name": "The Full Peal", "giver": "brannoc", "where": "Brannoc Bellwright, at the Keg", "zone": "summit",
		"offer": true, "avail": "qd:the_latch",
		"text": "Four woke the door. Eight is what she cast. I'd like to hear it, once, the way she meant it: every bell answered for, top to bottom, or bottom to top, I don't care which. You've the legs. I've watched you.",
		"steps": [
			{"kind": "cond", "cond": "bells:8", "text": "Answer for all eight of the Founder's bells ({bells} of 8)"},
			{"kind": "turnin", "who": "brannoc", "text": "Tell Brannoc the peal is whole"},
		],
		"reward": {"ash": 60, "items": {"ember_shard": 5, "relic_fragment": 5}},
		"choose": [{"legend": "door_splinter"}, {"legend": "sunk_shroud"}, {"legend": "unlit_lamp"}, {"legend": "stair_rope"}],
		"leaves": {"": {"at": Vector2(8.0, 30.5), "prop": "bell"}},     # the peal's last bell hangs at the Keg's door
		"outcome": {"": "Brannoc rang the chimney tongue eight times, slowly, and the Keg went quiet for each one. Then he put his head down on the bar and laughed."}},
	"shepherd_strays": South.QUESTS["shepherd_strays"], "oak_song": South.QUESTS["oak_song"], "well_answer": South.QUESTS["well_answer"],
	"wf_wheel": R37WQ.QUESTS["wf_wheel"], "wf_watch": R37WQ.QUESTS["wf_watch"], "wf_lights": R37WQ.QUESTS["wf_lights"],
	"wf_crown": R37WQ.QUESTS["wf_crown"], "salt_sweep": EastChains.SALT_SWEEP, "salt_widow": DeepB.SALT_WIDOW,
	"spire_coal": DeepB.SPIRE_COAL, "anchor_names": EastChains.ANCHOR_NAMES, "anchor_vow": EastChains.ANCHOR_VOW,
	"bounds_beaten": Sig.BOUNDS, "quarry_stone": Sig.QUARRY_STONE, "moor_fires": Sig.MOOR_FIRES, "founder_pour": Sig.FOUNDER_POUR,
	"orchard_stand": Sig.ORCHARD_STAND, "field_round": Sig.FIELD_ROUND, "mere_ferry": Sig.MERE_FERRY,
	"threshold_chapel": ThrQ.THRESHOLD_CHAPEL, "wf_upward": R37UF.QUESTS["wf_upward"], "star_lamp": StarQ.STAR_LAMP,
	"chain_count": ChainQ.CHAIN_COUNT,
	# --- tales ---
	"pans_hauler": R38E.QUESTS["pans_hauler"], "pans_pan": R38E.QUESTS["pans_pan"], "salt_barrel": R38E.QUESTS["salt_barrel"],
	"bitter_mother": R38E.QUESTS["bitter_mother"], "drover_tally": R38S.QUESTS["drover_tally"], "long_round": R38S.QUESTS["long_round"],
	"bryn_iron": R38S.QUESTS["bryn_iron"], "wren_gran": R38S.QUESTS["wren_gran"], "plinth_lamp": R38W.QUESTS["plinth_lamp"],
	"cutters_pledge": R38W.QUESTS["cutters_pledge"], "landing_staves": R38W.QUESTS["landing_staves"], "moor_niches": R38W.QUESTS["moor_niches"],
	# --- the towns ---
	"rh_lamps": Towns.QUESTS["rh_lamps"], "fm_tithe": Towns.QUESTS["fm_tithe"], "ll_gate": Towns.QUESTS["ll_gate"], "ll_oil": Towns.QUESTS["ll_oil"],
	# --- the reaches ---
	"wr_stand_down": FRW.QUESTS["wr_stand_down"], "wr_kings_lamp": FRW.QUESTS["wr_kings_lamp"], "wr_cold_light": FRW.QUESTS["wr_cold_light"], "wr_fourth_stone": FRW.QUESTS["wr_fourth_stone"],
	"wr_tansys_boat": FRW.QUESTS["wr_tansys_boat"], "ds_water_road": FRS.QUESTS["ds_water_road"], "ds_unmade": FRS.QUESTS["ds_unmade"], "ds_witchs_price": FRS.QUESTS["ds_witchs_price"],
	"ds_clapper": FRS.QUESTS["ds_clapper"], "er_ringers_candle": FRE.QUESTS["er_ringers_candle"], "er_nave_fire": FRE.QUESTS["er_nave_fire"], "er_halter_bell": FRE.QUESTS["er_halter_bell"],
	"er_inn_slate": FRE.QUESTS["er_inn_slate"],
	# --- deepen C ---
	"wr_relief": DC.WR_RELIEF, "ds_charcoal": DC.DS_CHARCOAL, "er_rope": DC.ER_ROPE,
	# --- deepen B ---
	"seventh_day": DeepB.SEVENTH_DAY,
	# --- deepen A ---
	"three_knocks": DA.QUESTS["three_knocks"], "forty_days": DA.QUESTS["forty_days"],
}

## r36: the bell quests (Act II), in no order; BELLS_NEEDED of them wake the summit door.
const BELLS := ["bell_spire", "bell_holds", "bell_quarry", "bell_moor", "bell_foundry", "bell_orchard", "bell_necropolis", "bell_mere"]
const BELLS_NEEDED := 1
## the bell the Marches wait for: cast for the country the Order shut out, it hangs in the Marches (no longer the door's own price)
const BELL_SHUT_OUT := "bell_spire"
## r36: the bells' keepers (rares.gd RARES keys; a bell quest's slay step wants its own).
const BELL_KEEPERS := ["lamp_shutter", "kin_caller", "bell_hewer", "fog_shepherd", "slag_born", "ash_sower", "passing_ringer", "fare_caller"]

const _PICKUPS := {
	"tongs": {"quest": "edda_tongs", "step": 0, "near": Vector2(-84.35, 44.15), "kind": "tongs", "name": "Edda's tongs", "verb": "Take",
		"say": "Smith's tongs, the jaws burned black. Somebody has wrapped the handles in new cloth."},
	"tongs_back": {"quest": "edda_tongs", "step": 2, "near": Vector2(-84.35, 44.15), "kind": "place", "name": "Edda's stone", "verb": "Lay the tongs on",
		"say": "You lay the tongs on the stone. It is warmer than it should be."},
	"slate_glade": {"quest": "names_yard", "step": 0, "near": Vector2(-35.0, 11.0), "kind": "slate", "name": "a name-slate", "verb": "Read",
		"say": "MAREN COYLE. SHE SANG THE LOW PART. Scratched with a nail, under a number somebody chiselled first. Pushed behind the offering shelf, where a choir-woman would stand: the choir hid their own."},
	"slate_lane": {"quest": "names_yard", "step": 0, "near": Vector2(-63.0, 55.5), "kind": "slate", "name": "a name-slate", "verb": "Read",
		"say": "TAM, THE CARTER'S BOY. NINE. LIKED HORSES. The number above it has been rubbed out with a thumb. Wedged in a wall-crack at a carter's height: a carter hid it, beside the cart he could not mend."},
	"slate_barrow": {"quest": "names_yard", "step": 0, "near": Vector2(80.0, -34.0), "kind": "slate", "name": "a name-slate", "verb": "Read",
		"say": "SISTER IDE, WHO KEPT THE BEES. NOT A NUMBER. The last three words are cut deeper than the rest. Under the lodge steps, where the brothers would not kneel; the bees' wax on its edge is hers."},
	"lantern": {"quest": "slow_way", "step": 2, "near": Vector2(58.0, -47.0), "kind": "lantern", "name": "Father Harrow's lantern", "verb": "Take",
		"say": "A tin lantern, the glass cracked. HARROW scratched on the base. The wick is dry. It has not been lit in a long time."},
	# r33
	"mug_fire": VQ.PICKUPS["mug_fire"], "spire_flame": VQ.PICKUPS["spire_flame"], "bell_tongue": VQ.PICKUPS["bell_tongue"],
	"coal": {"quest": "coal_shrine", "step": 0, "near": Vector2(2.6, 31.2), "kind": "coal", "name": "a live coal", "verb": "Take",
		"say": "You lift a coal from the green's fire in an iron dish. It pulses like something breathing. Go."},
	"alms": {"quest": "alms_loaf", "step": 1, "near": Vector2(42.0, 46.0), "kind": "loaf", "name": "the last loaf", "verb": "Take",
		"say": "One loaf on the Almonry's board, hard as a stone, a cross cut in the crust. There is always one left."},
	# r34. `camp`: the spot is found by that giver's outpost fire (village.gd builds it at load), `near`
	# is only the fallback.
	"coal_ruan": {"quest": "keeper_leave", "step": 0, "near": Vector2(-160.0, 6.0), "camp": "ruan", "kind": "coal", "name": "a ward-coal", "verb": "Take",
		"say": "A coal of black heartwood in a clay dish. It burns green at the edges and smells of oak in rain. Go."},
	"mark_pit": {"quest": "quarry_marks", "step": 0, "near": Vector2(-124.0, -106.0), "kind": "mark", "name": "a squared block", "verb": "Take the mark from",
		"say": "A squared block on the pit floor, ready to carry. A mark on its end: a hook and two strokes. Wat Mallow, it will turn out. He was paid for this one."},
	"mark_shelter": {"quest": "quarry_marks", "step": 0, "near": Vector2(-142.0, -115.0), "kind": "mark", "name": "a squared block", "verb": "Take the mark from",
		"say": "A block under the high bench, half buried in chips. The mark is a little ladder. Somebody has scratched a face beside it, smiling."},
	"mark_bench": {"quest": "quarry_marks", "step": 0, "near": Vector2(-117.0, -94.0), "kind": "mark", "name": "a squared block", "verb": "Take the mark from",
		"say": "A block on the east bench, split along a flaw and left. The mark is a Q with a tail. Quell. It was cut by the brother."},
	"cairn_north": {"quest": "moor_cairns", "step": 0, "near": Vector2(137.0, -42.0), "kind": "cairn", "name": "a fallen cairn", "verb": "Raise",
		"say": "You stack the stones back the way they lay. Somebody has scratched an arrow on the top one, pointing north, toward the Stair. You turn it to point home."},
	"cairn_mid": {"quest": "moor_cairns", "step": 0, "near": Vector2(147.0, 0.0), "kind": "cairn", "name": "a fallen cairn", "verb": "Raise",
		"say": "Five stones, and a sixth: a child's shoe, stuffed with heather. You build it into the middle."},
	"cairn_south": {"quest": "moor_cairns", "step": 0, "near": Vector2(135.0, 24.0), "kind": "cairn", "name": "a fallen cairn", "verb": "Raise",
		"say": "The last cairn. Its stones are warm on the downwind side, as if somebody sat against it all night."},
	"coal_ysolt": {"quest": "moor_shrine", "step": 0, "near": Vector2(132.0, -14.0), "camp": "ysolt", "kind": "coal", "name": "a coal", "verb": "Take",
		"say": "A coal from Ysolt's fire, in an iron dish. The wind leans on it the moment you lift it. Go."},
	"mould_furnace": {"quest": "founder_moulds", "step": 0, "near": Vector2(130.0, -106.0), "kind": "mould", "name": "a cheek of the mould", "verb": "Take",
		"say": "A curved cheek of fired loam in an iron cage, as long as your arm. Lettering inside it, backwards: the bell's own words, waiting to be poured."},
	"mould_pits": {"quest": "founder_moulds", "step": 0, "near": Vector2(129.0, -91.0), "kind": "mould", "name": "a cheek of the mould", "verb": "Take",
		"say": "The second cheek, in the casting pit where it was broken out of the sand. A thumbprint fired into the loam. A woman's."},
	"mould_heap": {"quest": "founder_moulds", "step": 0, "near": Vector2(137.0, -79.0), "kind": "mould", "name": "a cheek of the mould", "verb": "Take",
		"say": "The third cheek, dumped on the slag with the waste. It rings faintly when your hand closes on it."},
	"tongue_cast": {"quest": "founder_peal", "step": 1, "near": Vector2(128.0, -107.0), "kind": "clapper", "name": "the bell-tongue cast warm", "verb": "Take",
		"say": "The new tongue lies in the furnace's mouth, still warm through the cloth Elspeth wrapped it in. Your hand hums all the way to the elbow."},
	"bud_heart": {"quest": "orchard_buds", "step": 0, "near": Vector2(-88.0, 119.0), "kind": "bud", "name": "a living bud", "verb": "Cut",
		"say": "Under the char of the old tree's lowest limb, an eye of green no bigger than a fingernail. You cut it with the bark round it, the way Linnet showed you."},
	"bud_press": {"quest": "orchard_buds", "step": 0, "near": Vector2(-124.0, 128.0), "kind": "bud", "name": "a living bud", "verb": "Cut",
		"say": "A sucker growing out of a burned stump by the press-house wall. Green, and stubborn, and not supposed to be here."},
	"bud_rows": {"quest": "orchard_buds", "step": 0, "near": Vector2(-112.0, 142.0), "kind": "bud", "name": "a living bud", "verb": "Cut",
		"say": "The last bud, on a tree split by the burning. The split side is dead. The other side has been waiting nine winters for somebody to notice."},
	"coal_linnet": {"quest": "orchard_graft", "step": 0, "near": Vector2(-106.0, 112.0), "camp": "linnet", "kind": "coal", "name": "a coal", "verb": "Take",
		"say": "A coal from Linnet's fire, applewood, in an iron dish. It smells of autumn. Go."},
	"page_tomb": {"quest": "abbot_roll", "step": 0, "near": Vector2(2.0, 140.0), "kind": "page", "name": "a page of the roll", "verb": "Read",
		"say": "A page in a slot under the mausoleum's step, wrapped in oilcloth. Forty names, a column and a half, in one patient hand. Over them, in red: 3,212 - 3,251."},
	"page_ranks": {"quest": "abbot_roll", "step": 0, "near": Vector2(-20.0, 119.0), "kind": "page", "name": "a page of the roll", "verb": "Read",
		"say": "A page pressed under a grave's footstone, the ink run. You can still read most of it. Joan Pole. Her son. A dog, by name: Brindle."},
	"page_lodge": {"quest": "abbot_roll", "step": 0, "near": Vector2(84.0, -48.0), "kind": "page", "name": "a page of the roll", "verb": "Read",
		"say": "The last page, tucked behind a tally-board in the lay brothers' lodge, where the brothers would least think to look. The names are crossed through. Not out. Through."},
	"lamp_w": {"quest": "mere_lamps", "step": 0, "near": Vector2(92.0, 104.0), "kind": "lantern", "name": "one of Corvin's lamps", "verb": "Take",
		"say": "A tin lamp with a float of cork round its waist, beached in the reeds. CORVIN pricked into the tin with a nail. The wick is wet."},
	"lamp_s": {"quest": "mere_lamps", "step": 0, "near": Vector2(120.0, 140.0), "kind": "lantern", "name": "one of Corvin's lamps", "verb": "Take",
		"say": "A lamp tangled in drowned grass on the south bank. There is still oil in it, and a dead moth."},
	"lamp_e": {"quest": "mere_lamps", "step": 0, "near": Vector2(128.0, 114.0), "kind": "lantern", "name": "one of Corvin's lamps", "verb": "Take",
		"say": "A lamp on the east bank, upright, as if somebody set it down and walked into the water."},
	"lamp_cadoc": {"quest": "mere_light", "step": 0, "near": Vector2(111.0, 97.0), "camp": "cadoc", "kind": "lantern_lit", "name": "a lit lamp", "verb": "Take",
		"say": "One of Corvin's lamps, filled and lit, the cork float dry. The flame leans toward the chapel. Go."},
	# r36 Act III: the latch at the door (its conversation decides), the names asked at the far fires,
	# and the dais stone they are cut into
	"door_latch": {"quest": "the_latch", "step": 1, "near": Vector2(0.0, -101.5) + Endgame.O2, "kind": "slate", "name": "the latch-stone under the door", "verb": "Stand at", "conv": "door_latch",
		"say": "The latch-stone."},
	"name_ruan": {"quest": "names_under", "step": 0, "near": Vector2(-160.0, 6.0), "camp": "ruan", "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "Ruan says one word, and spells it, so you'll get it right. BRANN. Her brother. He wanted to see the top. She never did."},
	"name_ysolt": {"quest": "names_under", "step": 0, "near": Vector2(132.0, -14.0), "camp": "ysolt", "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "Ysolt gives you three. You tell her one. She picks the hardest: MAUD OF THE TOR, WHO CARRIED HER CAIRN-STONE UP."},
	"name_linnet": {"quest": "names_under", "step": 0, "near": Vector2(-106.0, 112.0), "camp": "linnet", "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "Linnet doesn't look up from the graft. \"Brother Anselm. He pruned. Put that. HE PRUNED.\""},
	"name_dunstan": {"quest": "names_under", "step": 0, "near": Vector2(-30.0, 222.0), "camp": "dunstan", "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "Dunstan counts on his fingers, as he counts the flock. \"Wat. He kept the lead ram. Put: WAT, WHO NEVER LOST ONE.\" He looks at the cairns while you cut it."},
	"name_ardel": {"quest": "names_under", "step": 0, "near": Vector2(218.0, 98.0), "camp": "ardel", "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "Ardel gives it without being asked twice. \"Hale. He trimmed the Spire's lamp, the last one to. HALE, AND HE LEFT IT LIT.\" He does not say how he knows."},
	"name_cadoc": {"quest": "names_under", "step": 0, "near": Vector2(111.0, 97.0), "camp": "cadoc", "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "\"Corvin,\" Cadoc says. \"He rowed them all to the foot of the Stair and then went up himself. Nobody rowed him back.\""},
	"name_corle": {"quest": "names_under", "step": 0, "near": Vector2(-316.5, 297.7), "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "Corle opens the lamp book to the line for him and turns it so you can read it. \"The courier. Nobody ever put his name down. Put: THE LAST RIDER, WHO WAS EXPECTED.\""},
	"name_penn": {"quest": "names_under", "step": 0, "near": Vector2(-147.3, 293.5), "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "Penn takes his hat off for it. \"My father lit the first beacon every harvest. ODO PENN, AND HE LIT IT EARLY.\""},
	"name_maudlin": {"quest": "names_under", "step": 0, "near": Vector2(315.5, 57.3), "kind": "slate", "name": "a name", "verb": "Ask for",
		"say": "Maudlin does not turn from the gate. \"Ivo. Second rope. He knocked, and was not let in, and went back up the road. IVO, WHO KNOCKED ONCE.\""},
	"dais_names": {"quest": "names_under", "step": 1, "near": Vector2(1.5, -101.0) + Endgame.O2, "kind": "place", "name": "the dais stone", "verb": "Cut the names into",
		"say": "You cut them under the Hierarch's line, small, as straight as you can, every name you were given, one under the next. There is room under them for a great many more."},
	"bell_spire": Bells.PICKUPS["bell_spire"], "bell_holds": Bells.PICKUPS["bell_holds"], "bell_quarry": Bells.PICKUPS["bell_quarry"], "bell_moor": Bells.PICKUPS["bell_moor"],
	"bell_foundry": Bells.PICKUPS["bell_foundry"], "bell_orchard": Bells.PICKUPS["bell_orchard"], "bell_necropolis": Bells.PICKUPS["bell_necropolis"], "bell_mere": Bells.PICKUPS["bell_mere"],
	"wf_sluice_key": R37WQ.PICKUPS["wf_sluice_key"], "wf_signal_lamp": R37WQ.PICKUPS["wf_signal_lamp"],
	"wf_rub_hand": R37WQ.PICKUPS["wf_rub_hand"], "wf_rub_shoulder": R37WQ.PICKUPS["wf_rub_shoulder"], "wf_rub_lip": R37WQ.PICKUPS["wf_rub_lip"],
	"wf_gauge": R37UF.PICKUPS["wf_gauge"], "star_book": StarQ.STAR_BOOK, "chain_tally": ChainQ.PICKUPS["chain_tally"],
	"coal_ardel": EastChains.COAL_ARDEL, "anchor_page_a": EastChains.PAGE_A, "anchor_page_b": EastChains.PAGE_B,
	"anchor_page_c": EastChains.PAGE_C,
	"foreman_stone": Sig.PICKUPS["foreman_stone"], "foreman_place": Sig.PICKUPS["foreman_place"],
	"moor_flame_fire": Sig.PICKUPS["moor_flame_fire"], "moor_flame_mid": Sig.PICKUPS["moor_flame_mid"],
	"pour_ladle": Sig.PICKUPS["pour_ladle"], "scion_linnet": Sig.PICKUPS["scion_linnet"], "ferry_lamp_out": Sig.PICKUPS["ferry_lamp_out"],
	# --- tales ---
	"pans_letter": R38E.PICKUPS["pans_letter"], "pans_tally": R38E.PICKUPS["pans_tally"], "pan_seed": R38E.PICKUPS["pan_seed"],
	"salt_barrel": R38E.PICKUPS["salt_barrel"], "skimmer_shed": R38E.PICKUPS["skimmer_shed"], "tower_marks": R38E.PICKUPS["tower_marks"],
	"skimmer_lay": R38E.PICKUPS["skimmer_lay"], "drover_stick": R38S.PICKUPS["drover_stick"], "drover_fold": R38S.PICKUPS["drover_fold"],
	"gate_lantern": R38S.PICKUPS["gate_lantern"], "bryn_tags": R38S.PICKUPS["bryn_tags"], "bryn_grave": R38S.PICKUPS["bryn_grave"],
	"plinth_lamp": R38W.PICKUPS["plinth_lamp"], "plinth_palm": R38W.PICKUPS["plinth_palm"], "cutters_roll": R38W.PICKUPS["cutters_roll"],
	"staff_a": R38W.PICKUPS["staff_a"], "staff_b": R38W.PICKUPS["staff_b"], "staff_c": R38W.PICKUPS["staff_c"],
	"staves_place": R38W.PICKUPS["staves_place"], "niche_name": R38W.PICKUPS["niche_name"],
	# --- the towns ---
	"rh_tam_lamp": Towns.PICKUPS["rh_tam_lamp"], "fm_tally_a": Towns.PICKUPS["fm_tally_a"], "fm_tally_b": Towns.PICKUPS["fm_tally_b"],
	"fm_tally_c": Towns.PICKUPS["fm_tally_c"], "fm_tally_place": Towns.PICKUPS["fm_tally_place"],
	# --- the reaches ---
	"wr_satchel": FRW.PICKUPS["wr_satchel"], "wr_shrine": FRW.PICKUPS["wr_shrine"], "wr_king_lamp": FRW.PICKUPS["wr_king_lamp"], "wr_king_door": FRW.PICKUPS["wr_king_door"],
	"wr_cap_a": FRW.PICKUPS["wr_cap_a"], "wr_cap_b": FRW.PICKUPS["wr_cap_b"], "wr_cap_c": FRW.PICKUPS["wr_cap_c"], "wr_cap_punt": FRW.PICKUPS["wr_cap_punt"],
	"wr_stones": FRW.PICKUPS["wr_stones"], "wr_ledger": FRW.PICKUPS["wr_ledger"], "wr_boat": FRW.PICKUPS["wr_boat"],
	"ds_keeper_log": FRS.PICKUPS["ds_keeper_log"], "ds_unmade_turn": FRS.PICKUPS["ds_unmade_turn"], "ds_nail": FRS.PICKUPS["ds_nail"],
	"ds_witch_door": FRS.PICKUPS["ds_witch_door"], "ds_clapper": FRS.PICKUPS["ds_clapper"], "ds_bell": FRS.PICKUPS["ds_bell"],
	"er_candle": FRE.PICKUPS["er_candle"], "er_door": FRE.PICKUPS["er_door"], "er_halter": FRE.PICKUPS["er_halter"], "er_tower": FRE.PICKUPS["er_tower"], "er_slate": FRE.PICKUPS["er_slate"],
	# --- deepen C ---
	"fm_roll": Towns.PICKUPS["fm_roll"], "ll_bar": Towns.PICKUPS["ll_bar"], "ll_nave_flame": Towns.PICKUPS["ll_nave_flame"], "ll_wick": Towns.PICKUPS["ll_wick"],
	"wr_relief_post": DC.PICKUPS["wr_relief_post"], "ds_clamp_coals": DC.PICKUPS["ds_clamp_coals"], "er_rope": DC.PICKUPS["er_rope"],
	# --- the story's long tasks ---
	# --- deepen B ---
	"turf_roof": DeepB.PICKUPS["turf_roof"], "wards_set": DeepB.PICKUPS["wards_set"], "ward_holds": DeepB.PICKUPS["ward_holds"],
	"ward_wood": DeepB.PICKUPS["ward_wood"], "ward_glade": DeepB.PICKUPS["ward_glade"], "last_step": DeepB.PICKUPS["last_step"],
	"moor_shrine_mid": DeepB.PICKUPS["moor_shrine_mid"], "shrine_lap": DeepB.PICKUPS["shrine_lap"], "press_hearth": DeepB.PICKUPS["press_hearth"],
	"ranks_turn": DeepB.PICKUPS["ranks_turn"], "mere_third": DeepB.PICKUPS["mere_third"], "mere_fare": DeepB.PICKUPS["mere_fare"],
	"well_call": DeepB.PICKUPS["well_call"], "oak_voice": DeepB.PICKUPS["oak_voice"], "widow_rake": DeepB.PICKUPS["widow_rake"],
	"spire_word": DeepB.PICKUPS["spire_word"], "seventh_slate": DeepB.PICKUPS["seventh_slate"], "bell_wether_bell": DeepB.PICKUPS["bell_wether_bell"],
	"wf_votive_a": DeepB.PICKUPS["wf_votive_a"], "wf_votive_b": DeepB.PICKUPS["wf_votive_b"], "wf_votive_c": DeepB.PICKUPS["wf_votive_c"],
	"wf_votive_place": DeepB.PICKUPS["wf_votive_place"], "wf_names": DeepB.PICKUPS["wf_names"], "wf_boy": DeepB.PICKUPS["wf_boy"],
	# --- deepen A ---
	"yard_cut": DA.PICKUPS["yard_cut"], "oswin_flame": DA.PICKUPS["oswin_flame"], "heart_thorn": DA.PICKUPS["heart_thorn"], "toll_axe": DA.PICKUPS["toll_axe"],
	"tally_post": DA.PICKUPS["tally_post"], "maud_door": DA.PICKUPS["maud_door"], "ninth_grave": DA.PICKUPS["ninth_grave"],
	"harrow_flame": VQ.PICKUPS["harrow_flame"], "belfry_flame": VQ.PICKUPS["belfry_flame"], "spire_cradle": VQ.PICKUPS["spire_cradle"],
}

## Joram's walk: from wherever he is to the waystone. He keeps 2-3 m behind you and waits when you
## run off; the step is done when he stands within `reach` of the stone.
## The forty-first waystone itself stands at `stone` (quest_world.gd puts it there for good).
const ESCORT := {"quest": "forty_first", "step": 0, "who": "oswin", "to": Vector2(-1.9, 17.4), "stone": Vector2(-2.9, 16.4), "reach": 4.5, "wait_r": 16.0}

## Father Harrow: wakes when you come within `wake` of the lantern on step 0, falls on step 1.
const HOLLOW := {"quest": "slow_way", "near": Vector2(58.0, -47.0), "wake": 24.0, "hp": 9, "title": "Father Harrow, hollowed"}

const KINDS := ["find", "gather", "talk", "escort", "kill", "place", "reach",
	"slay", "collect", "seal", "cond", "visit", "carry", "turnin", "defend", "clues", "tracks", "lantern_walk", "order", "vigil"]
## Step kinds that count up to `of` (the tracker shows n/of; progress toasts fire on them).
const COUNTED := ["gather", "slay", "collect", "seal"]


## A step's objective text for the save's state `d` ({s, p, f, n, of}).
## The 30-minute slice (core/util/slice.gd): the daily bounties and the raids' attunement chains
## are hidden (never offered) unless Slice.full(). Nothing is deleted.
static func hidden(id: String) -> bool:
	if Slice.full():
		return false
	var qd: Dictionary = QUESTS.get(id, {})
	return String(qd.get("repeat", "")) == "daily" or qd.has("raid")


## A task's `avail` condition as the slice sees it: a hidden task cannot gate another (the bell
## quests ask for the attunement chains' last tasks; in the slice they ask for the main story only).
static func avail_cond(id: String) -> String:
	var cond := String((QUESTS.get(id, {}) as Dictionary).get("avail", ""))
	if Slice.full() or cond == "":
		return cond
	var keep: PackedStringArray = []
	for part: String in cond.split(","):
		if part.begins_with("qd:") and hidden(part.trim_prefix("qd:")):
			continue
		keep.append(part)
	return ",".join(keep)


static func step_text(id: String, s: int, d: Dictionary) -> String:
	var qd: Dictionary = QUESTS.get(id, {})
	var steps: Array = qd.get("steps", [])
	if s < 0 or s >= steps.size():
		return ""
	var t := String(steps[s].text)
	var alt: Dictionary = (qd.get("alt", {}) as Dictionary).get(String(d.get("p", "")), {})
	if alt.has(s):
		t = String(alt[s])
	var c := count_of(id, s, d)
	t = t.replace("{n}", str(c[0])).replace("{of}", str(c[1]))
	if t.contains("{bells}"):
		t = t.replace("{bells}", str(int((load("res://core/story/quest_book.gd") as GDScript).call("bells"))))
	if t.contains("{t}"):
		t = t.replace("{t}", str(int(ceilf(float(d.get("left", float(steps[s].get("time", 0.0))))))))
	return t


## [have, wanted] for step `s` (wanted 0 = a step that is not counted).
static func count_of(id: String, s: int, d: Dictionary) -> Array:
	var st := step(id, s)
	if not st.is_empty() and String(st.kind) in VerbKit.COUNTED:
		return VerbKit.count(st, d)                    # clues (read of wanted), tracks (marks followed)
	if st.is_empty() or not String(st.kind) in COUNTED:
		return [0, 0]
	var of := int(st.get("of", 1))
	var n := 0
	if String(st.kind) == "gather":
		var f: Variant = d.get("f", {})
		n = (f as Dictionary).size() if f is Dictionary else 0
	else:
		n = int(d.get("n", 0))
		if String(st.kind) == "seal":
			of = maxi(int(d.get("of", 0)), 1)
	return [mini(n, of), of]


static func step(id: String, s: int) -> Dictionary:
	var steps: Array = (QUESTS.get(id, {}) as Dictionary).get("steps", [])
	return steps[s] if s >= 0 and s < steps.size() else {}


## The person who hands the task out.
static func giver(id: String) -> String:
	return String((QUESTS.get(id, {}) as Dictionary).get("giver", ""))


static func zone_name(z: String) -> String:
	for pair: Array in ZONES:
		if String(pair[0]) == z:
			return String(pair[1])
	return "Elsewhere"


## The pickups a quest's gather step counts.
static func gather_keys(id: String, s: int) -> Array[String]:
	var out: Array[String] = []
	for k: String in PICKUPS:
		var p: Dictionary = PICKUPS[k]
		if String(p.quest) == id and int(p.step) == s:
			out.append(k)
	return out


## Integrity for the tests: [] = fine.
static func audit() -> Array[String]:
	var bad: Array[String] = []
	var zones := ZONES.map(func(z: Array) -> String: return String(z[0]))
	for id: String in ORDER:
		if not QUESTS.has(id):
			bad.append("ORDER has unknown %s" % id)
	for id: String in QUESTS:
		var qd: Dictionary = QUESTS[id]
		if not id in ORDER:
			bad.append("%s missing from ORDER" % id)
		if not String(qd.get("zone", "")) in zones:
			bad.append("%s: no zone" % id)
		if String(qd.get("text", "")) == "":
			bad.append("%s: no flavour text" % id)
		for s: Dictionary in qd.steps:
			if not String(s.kind) in KINDS:
				bad.append("%s: bad step kind %s" % [id, s.kind])
			if String(s.kind) in ["talk", "turnin"] and String(s.get("who", "")) == "":
				bad.append("%s: a %s step names nobody" % [id, s.kind])
			if String(s.kind) in ["visit", "carry", "lantern_walk"] and not (s.get("at", s.get("to")) is Vector2):
				bad.append("%s: a %s step has no place" % [id, s.kind])
		for si in (qd.steps as Array).size():
			var kind := String(qd.steps[si].kind)
			if kind in ["find", "gather", "place"] and gather_keys(id, si).is_empty():
				bad.append("%s step %d (%s) has no pickup" % [id, si, kind])
			if kind == "gather" and gather_keys(id, si).size() < int(qd.steps[si].get("of", 1)):
				bad.append("%s step %d has only %d pickups for %d" % [id, si, gather_keys(id, si).size(), int(qd.steps[si].get("of", 1))])
			# every step that sends you somewhere says where, so the map's task row never goes blank (the
			# peal's steps point at the nearest unanswered bell; the two standing bounties roam)
			if kind in ["slay", "collect", "cond", "visit", "seal"] and not (qd.steps[si].get("to", qd.steps[si].get("at")) is Vector2) \
					and not String(qd.steps[si].get("cond", "")).begins_with("bells:") and not String(qd.steps[si].get("cond", "")).begins_with("peal:") and not id in ["rare_head", "keeper_again"]:
				bad.append("%s step %d (%s) has no map target" % [id, si, kind])
			bad.append_array(LiveSteps.audit(id, si, qd.steps[si]))      # escort.gd / defend.gd steps
			bad.append_array(VerbKit.audit(id, si, qd.steps[si]))        # clues, tracks, lantern_walk, order, vigil
			if kind in ["carry", "lantern_walk"] and (si == 0 or not PICKUPS.has(String(qd.steps[si].get("from", ""))) or int(PICKUPS[qd.steps[si].from].step) != si - 1):
				bad.append("%s step %d carries no pickup taken the step before" % [id, si])
		if bool(qd.get("offer", false)):
			var last: Dictionary = (qd.steps as Array).back()
			if String(last.kind) != "turnin":
				bad.append("%s: an offered task ends in a turn-in" % id)
		for st2: Dictionary in qd.steps:
			for rid: String in st2.get("rares", []):
				if not RARE_IDS.has(rid) and not BELL_KEEPERS.has(rid):
					bad.append("%s: unknown rare %s" % [id, rid])
		if qd.has("raid") and not ATTUNE.has(String(qd.raid)):
			bad.append("%s: unknown raid %s" % [id, qd.raid])
		for opts: Dictionary in qd.get("choose", []):
			if opts.has("set") and not ["kindler", "ferryman", "tally", "bell"].has(String(opts.set)):
				bad.append("%s: unknown gear set %s" % [id, opts.set])
	for k: String in PICKUPS:
		var p: Dictionary = PICKUPS[k]
		if not QUESTS.has(String(p.quest)) or int(p.step) >= (QUESTS[p.quest].steps as Array).size():
			bad.append("pickup %s: bad quest/step" % k)
		if p.has("camp") and not GIVER_NAMES.has(String(p.camp)):
			bad.append("pickup %s: no giver %s to camp by" % [k, p.camp])
	for b: String in ATTUNE:
		if not QUESTS.has(String(ATTUNE[b])) or String(QUESTS[ATTUNE[b]].get("raid", "")) != b:
			bad.append("attunement %s: %s is not its chain's last task" % [b, ATTUNE[b]])
	var rs: Script = load("res://core/enemy/rares.gd") as Script
	if rs:
		var known: Dictionary = rs.get_script_constant_map().get("RARES", {})
		for rid2: String in RARE_IDS + BELL_KEEPERS:
			if not known.has(rid2):
				bad.append("rare %s is not in rares.gd" % rid2)
	for id2: String in QUESTS:
		if not GIVER_NAMES.has(giver(id2)):
			bad.append("%s: giver %s has no name" % [id2, giver(id2)])
	return bad
