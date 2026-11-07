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
##   ESCORT / HOLLOW  the two moving pieces (Oswin's walk, Father Harrow)
## House style (docs/LORE.md): terse, concrete, dark. Load by path.

# --- south marches ---
const South := preload("res://core/story/quest_chains_r37_south.gd")
## West marches: Weirford's four chains (quest_chains_r37_west.gd), listed in the blocks marked `# --- west marches ---`.
const R37WQ := preload("res://core/story/quest_chains_r37_west.gd")

## The ledger's chapters (ui/quest_log.gd), in order: [id, name].
const ZONES := [["hearth", "Hearthward"], ["road", "The Pilgrims' Road"], ["thornwood", "The Thornwood"],
	["fen", "The Hollow Fen"], ["holds", "The Rooted Holds"], ["quarry", "The Saints' Quarry"],
	["moor", "The Lanternless Moor"], ["foundry", "The Founder's Pits"], ["orchard", "The Cinder Orchard"],
	["necropolis", "The Waiting Field"], ["mere", "Corvin's Mere"],
	["ossuary", "The Ossuary"], ["summit", "The Summit of Ascension"],
	["downs", "The Southern Downs"], ["oak", "The Grandmother Oak"], ["well", "The Well of Echoes"],
	R37WQ.ZONES[0], R37WQ.ZONES[1], R37WQ.ZONES[2], R37WQ.ZONES[3],
	["stillwater", "Stillwater"], ["anchorholds", "The Anchorholds"], ["saltmarket", "Saltmarket"], ["saltpans", "The White Pans"]]

const R37E := preload("res://core/story/quest_chains_r37_east.gd")   ## the east marches: its tasks and pickups are listed in the `# --- the east marches ---` blocks

const ORDER := ["edda_tongs", "forty_first", "names_yard", "keg_thief", "slow_way",
	"hearth_ash", "road_clear", "coal_shrine", "spire_lamps", "alms_loaf",
	"thorn_door", "smoke_oaks", "ring_heart", "unpaid_toll",
	"bead_count", "drowned_bell", "count_below", "crossing_ward",
	# r34: the doubled world's hubs (a giver per new region) and the raids' attunements
	"holds_turf", "keeper_wards", "keeper_heart", "keeper_leave",
	"quarry_marks", "quarry_picks", "quarry_last", "quarry_chisel", "quarry_due",
	"moor_cairns", "moor_stumbled", "moor_shrine", "moor_hennet", "moor_wind",
	"founder_slag", "founder_clapper", "founder_moulds", "founder_peal",
	"orchard_buds", "orchard_press", "orchard_graft", "orchard_pippin", "orchard_ash",
	"field_ranks", "field_last", "abbot_roll", "abbot_cords", "abbot_names",
	"mere_lamps", "mere_chapel", "mere_light", "mere_ferryman", "mere_oil",
	# r36 Act II: the Founder's peal
	"founders_peal", "bell_holds", "bell_quarry", "bell_moor", "bell_foundry", "bell_orchard", "bell_necropolis", "bell_mere",
	# r36 the keep's standing bounties
	"keg_tab", "rare_head", "keeper_again",
	# r36 Act III: the door
	"the_latch", "still_climbing", "names_under", "full_peal",
	"shepherd_strays", "oak_song", "well_answer",
	"wf_wheel", "wf_watch", "wf_lights", "wf_crown",
	"salt_sweep", "salt_widow", "spire_coal", "anchor_names", "anchor_vow"]

## Who stands where, for the map's turn-in pins when the person is not in the night's tree.
const GIVER_NAMES := {"hild": "Hild", "fennick": "Old Fennick", "oswin": "Oswin", "nan": "Nan Wright", "abel": "Abel the sexton",
	"wyck": "Wyck", "grisel": "Grisel", "keep": "The keep", "harrow": "Ostrin Harrow", "hesk": "Hesk", "brannoc": "Brannoc",
	"ruan": "Gammer Ruan", "jory": "Jory Quell", "ysolt": "Ysolt the cairn-keeper", "elspeth": "Elspeth Fane",
	"linnet": "Linnet the grafter", "agathe": "Sister Agathe", "cadoc": "Cadoc the ferryman",
	"dunstan": "Dunstan Pike",
	"osk": "Osk the miller", "cassel": "Captain Cassel", "ennis": "Sister Ennis", "tolliver": "Old Tolliver",
	"dorrit": "Dorrit Marl", "bryn": "Bryn Gale", "wren": "Wren", "gwyn": "Gwyn the ostler",
	"marl": "Marl Pannick", "teasel": "Teasel Dray", "orrin": "Orrin Vail", "ardel": "Ardel Wick", "pip": "Pip"}

## r34: the raids' attunements (WoW's attunement chains, adapted): the last task of each pre-raid
## chain, once handed in, loosens the boss's hold (QuestBook.attuned(boss); Travel.story flag
## "attuned_<boss>"). Never required: the seals and the main story open the raids as before.
## r34: the named rares the bounties want (core/enemy/rares.gd RARES keys; checked by the audit
## against that file when it loads).
const RARE_IDS := ["old_rook", "brother_chisel", "hennet", "clapper", "old_pippin", "last_pilgrim", "ferryman",
	"bell_wether", "flint_hound",
	"drowned_reeve", "moss_mason", "gate_breaker",
	"salt_widow", "drowned_lamplighter"]

const ATTUNE := {"thornwarden": "keeper_leave", "bone_abbot": "abbot_names", "ascended_warden": "founder_peal"}

const QUESTS := {
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
	"forty_first": {"name": "The Forty-First Stone", "giver": "oswin", "where": "Oswin the pilgrim, on the west road", "zone": "road",
		"text": "Oswin has touched forty waystones on the way to the Stair. He wants to touch the last, and his eyes are bad in the dark.",
		"steps": [
			{"kind": "escort", "text": "Walk Oswin to the forty-first waystone, at the head of the rim road south of the green"},
			{"kind": "talk", "who": "oswin", "text": "Speak with Oswin at the forty-first stone"},
		],
		"reward": {"ash": 12, "charm": "charm_waystone", "else": {"relic_fragment": 1}},
		"outcome": {"truth": "You told Oswin the Stair is gone. He took the west road home and left his staff behind.",
			"faith": "Oswin keeps his vigil at the forty-first stone, waiting for a bell."}},
	"names_yard": {"name": "Names for the Yard", "giver": "abel", "where": "Abel the sexton, by the Kindlers' Yard", "zone": "hearth",
		"text": "The Order cut numbers where the names should be. A few of the faithful scratched the names back on slates and hid them.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Find the three name-slates: in the Glimmer Glade, on the chapel lane, in the Barrow Field ({n}/{of})"},
			{"kind": "talk", "who": "abel", "text": "Bring the names to Abel at his dig"},
		],
		"reward": {"ash": 15, "items": {"relic_fragment": 1}},
		"outcome": {"": "Maren Coyle, Tam, Sister Ide: their names are cut in the Kindlers' Yard, by Edda's stone."}},
	"keg_thief": {"name": "The Keg's Missing Ale", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "hearth",
		"text": "Somebody has been lifting full mugs off the Keg's counter. The keep wants to know who before he starts guessing.",
		"steps": [
			{"kind": "find", "text": "Look behind the Kindled Keg, by the chimney, for signs of the ale thief"},
			{"kind": "find", "text": "Follow the chalk circles to the green's fire"},
			{"kind": "talk", "who": "nan", "text": "Ask Nan Wright about the chalk circles"},
			{"kind": "talk", "who": "keep", "text": "Tell the keep what you found"},
		],
		"alt": {"rats": {3: "Tell the keep it was rats"}, "covered": {3: "Square Nan's debt with the keep (10 ash)"}},
		"reward": {"items": {"ember_shard": 2, "grave_iron": 1}},
		"outcome": {"told": "The keep knows it was Nan. He leaves a mug by the green's fire himself now.",
			"covered": "You paid for Nan's mugs. The keep is watching you; Nan drew you a circle.",
			"rats": "The keep blames rats. Nan keeps her secret, and her mug by the fire."}},
	"slow_way": {"name": "The Slow Way Down", "giver": "harrow", "where": "Ostrin Harrow, at the Keg's bar", "zone": "fen",
		"text": "Ostrin's father took his lantern down the fen after the bells, six winters gone. Ostrin wants the lantern back, whatever is holding it.",
		"steps": [
			{"kind": "reach", "text": "Search the fen by the fen brazier, under the Ossuary's door, for Father Harrow's lantern", "at": Vector2(58.0, -47.0)},
			{"kind": "kill", "text": "Put the hollowed man by the lantern to rest", "at": Vector2(58.0, -47.0)},
			{"kind": "find", "text": "Take Father Harrow's lantern"},
			{"kind": "talk", "who": "harrow", "text": "Bring the lantern to Ostrin Harrow at the Kindled Keg"},
		],
		"reward": {"ash": 20, "items": {"relic_fragment": 1}},
		"outcome": {"truth": "Ostrin knows his father is at rest. The lantern burns on the Keg's counter.",
			"mercy": "Ostrin thinks his father still walks the fen. The lantern sits cold on the Keg's counter, waiting."}},

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
	"spire_lamps": {"name": "A Lamp on the Spire", "giver": "fennick", "where": "Old Fennick, on his lamp round", "zone": "summit",
		"offer": true, "avail": "kindled:1",
		"text": "The Order kept a lamp on the Watchers' Spire, up under the Crowns, to watch the sky turn. I lit it for them as a boy. Go and see if it's still there. Tell me what the sky looks like from up there.",
		"steps": [
			{"kind": "visit", "at": Vector2(-52.0, -100.0), "r": 14.0, "label": "The Watchers' Spire",
				"text": "Climb to the Watchers' Spire under the Crowns"},
			{"kind": "turnin", "who": "fennick", "text": "Tell Old Fennick what you saw from the Spire"},
		],
		"reward": {"ash": 14},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}],
		"outcome": {"": "Fennick listened to all of it with his eyes shut. The lamp on the Spire is out. He knew."}},
	"alms_loaf": {"name": "One Loaf, One Blessing", "giver": "nan", "where": "Nan Wright, on the green", "zone": "road",
		"offer": true,
		"text": "The Almonry on the road gave a loaf to every pilgrim, one a night. Pell always ate hers on the step. There might be one left on the board. There's always one left on the board.",
		"steps": [
			{"kind": "visit", "at": Vector2(46.0, 40.0), "r": 12.0, "label": "The Almonry", "text": "Go to the Almonry on the Pilgrims' Road"},
			{"kind": "find", "text": "Take the last loaf from the Almonry's board"},
			{"kind": "turnin", "who": "nan", "text": "Bring the loaf to Nan Wright"},
		],
		"reward": {"ash": 8},
		"choose": [{"slot": "vestment", "rarity": 1}, {"slot": "lantern", "rarity": 1}],
		"outcome": {"": "Nan put the loaf by the green's fire, inside a chalk circle, beside the mug."}},
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
	"ring_heart": {"name": "What the Oaks Keep", "giver": "wyck", "where": "Wyck, at his fire in the Thornwood", "zone": "thornwood",
		"offer": true, "avail": "qd:thorn_door",
		"text": "The Thornwarden roots in a heart. Cut it out and the wood forgets it was ever kept. I won't say do it. I won't say don't. Bring me a thorn off it, after. I'll bury it face down.",
		"steps": [
			{"kind": "cond", "cond": "boss:thornwarden", "at": Vector2(-72.0, -18.0), "label": "The Thornwarden", "past": "The Thorn Heart is already cut.",
				"text": "Cut the Thorn Heart from the Thornwarden in the Ring"},
			{"kind": "turnin", "who": "wyck", "text": "Bring a thorn to Wyck"},
		],
		"reward": {"ash": 25},
		"choose": [{"set": "kindler", "slot": "focus", "rarity": 2}, {"set": "kindler", "slot": "lantern", "rarity": 2}, {"set": "kindler", "slot": "vestment", "rarity": 2}],
		"outcome": {"": "Wyck buried the thorn face down, and sang the verse the abbey chiselled off."}},
	"unpaid_toll": {"name": "The Toll Unpaid", "giver": "hesk", "where": "Hesk the Woodcutter, at the Keg", "zone": "thornwood",
		"offer": true,
		"text": "Tollmen. Ride with the war bands, ring a bell, and the whole wood comes running. One of 'em had my brother's axe. Put two of 'em down before they ring. Then I'll drink easier.",
		"steps": [
			{"kind": "slay", "of": 2, "kinds": ["tollman"], "region": "thornwood,henge", "label": "Tollmen", "at": Vector2(-92.0, -30.0),
				"text": "Put down tollmen riding with the war bands ({n}/{of})"},
			{"kind": "turnin", "who": "hesk", "text": "Tell Hesk the tolls are unpaid"},
		],
		"reward": {"ash": 12},
		"choose": [{"slot": "girdle", "rarity": 1}, {"slot": "focus", "rarity": 1}],
		"outcome": {"": "Hesk drank to his brother, twice. The second was for the axe."}},
	# the Hollow Fen and the Ossuary: Abel's tally, Brannoc's bell
	"bead_count": {"name": "The Lay Brothers' Beads", "giver": "abel", "where": "Abel the sexton, by the Kindlers' Yard", "zone": "fen",
		"offer": true, "avail": "met:abel",
		"text": "The bone-walkers in the fen are the lay brothers, still counting. They carry their tally-beads on them. Bring me the beads and the count stops. I'll lay them flat. The beads, I mean. Them too.",
		"steps": [
			{"kind": "collect", "of": 4, "chance": 0.75, "kinds": ["ossuant"], "region": "fen,barrows", "label": "Tally-beads", "at": Vector2(96.0, -30.0),
				"text": "Take tally-beads from the bone-walkers of the fen and the Barrow Field ({n}/{of})"},
			{"kind": "turnin", "who": "abel", "text": "Bring the tally-beads to Abel"},
		],
		"reward": {"ash": 12},
		"choose": [{"set": "tally", "slot": "vestment", "rarity": 1}, {"set": "tally", "slot": "girdle", "rarity": 1}, {"set": "tally", "slot": "lantern", "rarity": 1}],
		"outcome": {"": "Abel buried the beads loose, so nobody can count them again."}},
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
	"drowned_bell": {"name": "The Drowned Bell", "giver": "brannoc", "where": "Brannoc Bellwright, at the Keg", "zone": "fen",
		"offer": true,
		"text": "My grandfather cast the bell in the fen tower. It rang for the sunk. When the water came up it rang by itself for a week. Then it stopped. Go and bring me its tongue. A bell that can't ring can't be made to.",
		"steps": [
			{"kind": "visit", "at": Vector2(82.0, -18.0), "r": 14.0, "label": "The Drowned Belfry", "text": "Wade out to the Drowned Belfry in the Hollow Fen"},
			{"kind": "find", "text": "Take the bell's iron tongue from the belfry"},
			{"kind": "turnin", "who": "brannoc", "text": "Bring the bell's tongue to Brannoc"},
		],
		"reward": {"ash": 14},
		"choose": [{"set": "bell", "slot": "focus", "rarity": 1}, {"set": "bell", "slot": "vestment", "rarity": 1}, {"set": "bell", "slot": "girdle", "rarity": 1}],
		"outcome": {"": "Brannoc keeps the drowned bell's tongue by him. It doesn't ring. He checks."}},
	# the summit: the keep's last word
	"crossing_ward": {"name": "The Ward on the Crossing", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "summit",
		"offer": true, "avail": "boss:thornwarden,boss:bone_abbot,qd:founders_peal",
		"text": "Heart and crown, and a peal behind you. The ward on the Crossing will know them. It has guards that don't sleep; put them down and it lets you through. Then the top. I'll keep your stool warm. Come back and sit on it.",
		"steps": [
			{"kind": "seal", "seal": "summit", "label": "Crossing guards", "at": Vector2(0.0, -70.9),
				"text": "Put down the guards of the summit ward on the Crossing ({n}/{of})"},
			{"kind": "cond", "cond": "boss:ascended_warden", "at": Vector2(0.0, -103.9), "label": "The Ascended Warden",
				"text": "Face what holds the door at the summit"},
			{"kind": "turnin", "who": "keep", "text": "Sit on your stool at the Kindled Keg"},
		],
		"reward": {"ash": 40},
		"choose": [{"legend": "door_splinter"}, {"legend": "sunk_shroud"}, {"legend": "unlit_lamp"}],
		"outcome": {"": "The keep poured, and didn't say anything for a long time. Then he said: kindled."}},

	# --- r34: the doubled world (docs/r34/layout.md): a giver in each new region, a short chain on
	# its lore line, a daily where there is ground to thin, and the raids' attunements -----------
	# the Rooted Holds: Gammer Ruan, and the Thornwarden's attunement (the keeper's wards)
	"holds_turf": {"name": "The Kin-Taker", "giver": "ruan", "where": "Gammer Ruan, at her fire in the Rooted Holds", "zone": "holds",
		"offer": true,
		"text": "Something walks round the Holds at night, tall as a door, and lifts the turf off the roofs to look in at us. The young ones named it Old Rook, when there were young ones. It took them. Put it down, and I'll sleep with the door open for once.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["old_rook"], "label": "Old Rook, the Kin-Taker", "at": Vector2(-140.0, 11.0),
				"text": "Put down Old Rook, the Kin-Taker, on its round of the Holds"},
			{"kind": "turnin", "who": "ruan", "text": "Tell Gammer Ruan the Kin-Taker is down"},
		],
		"reward": {"ash": 14},
		"choose": [{"slot": "vestment", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
		"outcome": {"": "Ruan slept with her door open. In the morning she turned the empty beds face down again, one by one."}},
	"keeper_wards": {"name": "The Keeper's Wards", "giver": "ruan", "where": "Gammer Ruan, at her fire in the Rooted Holds", "zone": "holds",
		"offer": true, "raid": "thornwarden",
		"text": "We bound the keeper into the Ring with three ward-stones, one for each way the axe could come. The abbey dug them up and threw them in the wood. While they lie loose it keeps the Ring with all its strength, like a dog with no master. Bring them to my hand.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Find the three ward-stones: in the Holds, under the Thornwood's oaks, in the Glimmer Glade ({n}/{of})"},
			{"kind": "turnin", "who": "ruan", "text": "Bring the ward-stones to Gammer Ruan"},
		],
		"reward": {"ash": 15, "items": {"relic_fragment": 1}},
		"outcome": {"": "Ruan set the three wards round her fire, face down, and sang the keeper's verse to them. Not the last verse."}},
	"keeper_heart": {"name": "Heartwood", "giver": "ruan", "where": "Gammer Ruan, at her fire in the Rooted Holds", "zone": "holds",
		"offer": true, "avail": "qd:keeper_wards", "raid": "thornwarden",
		"text": "The keeper roots in a heart and feeds the wood from it. The things under the oaks are fat on it. Bring me splinters off them: heartwood, black and warm to hold. I'll burn it in the ward-fire, and the keeper will smell itself in the smoke.",
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
		"text": "Take a coal from my fire, lit with its own heartwood, up the Ring's stair before it dies. Lay it at the head of the stair. It will know us by it. When you go in to it after, it will fight you with one hand behind its back. Not out of kindness. Out of manners.",
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
	"quarry_last": {"name": "The Last Step", "giver": "jory", "where": "Jory Quell, at his fire by the Saints' Quarry", "zone": "quarry",
		"offer": true, "avail": "qd:quarry_picks",
		"text": "One block the Order blessed and never sent: the four thousand and first step. It sits on the pit floor with a prayer cut in the top. Go down and read it to me. My eyes won't do the benches, and I want to know what they wrote on the step after the last one.",
		"steps": [
			{"kind": "visit", "at": Vector2(-128.0, -104.0), "r": 10.0, "label": "The pit floor", "text": "Climb down the benches to the quarry's pit floor"},
			{"kind": "find", "text": "Read the blessed block on the pit floor"},
			{"kind": "turnin", "who": "jory", "text": "Tell Jory Quell what the last step says"},
		],
		"reward": {"ash": 18},
		"choose": [{"slot": "vestment", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"": "\"Here the faithful step off.\" Jory laughed till he coughed. Then he asked you to say it again."}},
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
	"moor_shrine": {"name": "No Lantern", "giver": "ysolt", "where": "Ysolt, at her fire under the tor", "zone": "moor",
		"offer": true, "avail": "qd:moor_stumbled",
		"text": "There's a shrine on the south moor the Order raised for the first edict. Lanterns are for doubters, it says. Carry a coal there from my fire and set it in the shrine's lap. I've been a doubter forty years. I'd like it said in stone.",
		"steps": [
			{"kind": "find", "text": "Take a coal from Ysolt's fire"},
			{"kind": "carry", "from": "coal_ysolt", "to": Vector2(142.5, 16.0), "r": 5.0, "time": 75.0, "label": "Coal",
				"lost": "The coal has gone out on the moor. Ysolt's fire has more.",
				"text": "Carry the coal to the lanternless shrine on the south moor before it dies ({t} s)"},
			{"kind": "turnin", "who": "ysolt", "text": "Tell Ysolt the shrine has a light in its lap"},
		],
		"reward": {"ash": 18},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}],
		"outcome": {"": "A coal burns in the lap of the first edict's shrine. From the tor it is the only light on the moor."}},
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
	"founder_clapper": {"name": "The Bell-Tongue", "giver": "elspeth", "where": "Elspeth Fane, at her fire in the Founder's Pits", "zone": "foundry",
		"offer": true, "avail": "qd:founder_slag",
		"text": "Something walks the pits ringing. A cinder-thing with a bell's tongue where its head should be. It was the Founder's striker, the boy who rang the test notes. It still rings them, wrong, every one. Make it stop. I can't hear myself cast.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["clapper"], "label": "Clapper, the Bell-Tongue", "at": Vector2(124.0, -96.0),
				"text": "Put down Clapper, the Bell-Tongue, in the Founder's Pits"},
			{"kind": "turnin", "who": "elspeth", "text": "Tell Elspeth Fane the pits are quiet"},
		],
		"reward": {"ash": 16, "items": {"relic_fragment": 1}},
		"choose": [{"set": "bell", "slot": "focus", "rarity": 1}, {"set": "bell", "slot": "vestment", "rarity": 1}],
		"outcome": {"": "Elspeth struck the cooling furnace once with a hammer, the right note, for the striker. Then she went back to work."}},
	"founder_moulds": {"name": "The Founder's Moulds", "giver": "elspeth", "where": "Elspeth Fane, at her fire in the Founder's Pits", "zone": "foundry",
		"offer": true, "raid": "ascended_warden",
		"text": "She cast the summit's bell in three cheeks of loam and iron. The Hierarch's bell. Brannoc says the thing up there holds the door with it still in its hand. Bring me the moulds. A bell's mould knows its note, and I can teach it a wrong one.",
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
			{"kind": "cond", "cond": "secret:solved:bells", "at": Vector2(-37.6, -27.0), "label": "The Fallen Bells", "past": "The fallen bells are already rung.",
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
	"orchard_press": {"name": "The Press-House", "giver": "linnet", "where": "Linnet, at her fire in the Cinder Orchard", "zone": "orchard",
		"offer": true, "avail": "qd:orchard_buds",
		"text": "The press-house at the west end. The brothers pressed the fruit there and gave the road its cider. Something lives in it now, and it isn't cider. Go and look. Thin them on the way.",
		"steps": [
			{"kind": "visit", "at": Vector2(-128.0, 132.0), "r": 12.0, "label": "The press-house", "text": "Find the press-house at the orchard's west end"},
			{"kind": "slay", "of": 5, "region": "orchard", "label": "Hollowed in the rows", "at": Vector2(-120.0, 122.0),
				"text": "Put down the hollowed in the burned rows ({n}/{of})"},
			{"kind": "turnin", "who": "linnet", "text": "Tell Linnet what lives in the press-house"},
		],
		"reward": {"ash": 15, "items": {"relic_fragment": 1}},
		"outcome": {"": "Nothing lives in the press-house now. Linnet says she'll press something in it next autumn, if there is one."}},
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
	"field_ranks": {"name": "Facing the Mountain", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
		"offer": true,
		"text": "They're buried facing the Stair, so they'd be first through when the sky called. Something walks the ranks at night and the stones are turning. I turn them back. My back is not what it was. Put the walkers down.",
		"steps": [
			{"kind": "visit", "at": Vector2(-18.0, 114.0), "r": 12.0, "label": "The pilgrims' ranks", "text": "Walk the pilgrims' ranks in the Waiting Field"},
			{"kind": "slay", "of": 5, "region": "necropolis", "label": "Walkers in the ranks", "at": Vector2(-10.0, 130.0),
				"text": "Put down the hollowed walking the Waiting Field ({n}/{of})"},
			{"kind": "turnin", "who": "agathe", "text": "Tell Sister Agathe the ranks are still"},
		],
		"reward": {"ash": 14},
		"choose": [{"slot": "vestment", "rarity": 1}, {"slot": "lantern", "rarity": 1}],
		"outcome": {"": "Agathe walked the ranks with you after, and turned three stones back to face the mountain. Then, after a while, one away from it."}},
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
		"text": "His bone-walkers carry the count on knotted cords. Every knot is somebody. Cut me four cords off them and the count goes slack. He'll feel it down there, a stitch dropped.",
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
		"text": "Take the roll down to the Ossuary's fen door and read it, all of it, into the dark. Then he goes to his count and finds it short. A counter who comes up short begins to doubt. A doubting Abbot is half an Abbot.",
		"steps": [
			{"kind": "visit", "at": Vector2(48.0, -60.0), "r": 10.0, "label": "The Ossuary's fen door", "text": "Read the pilgrims' roll aloud at the Ossuary's fen door"},
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
	"mere_light": {"name": "Light for the Sunk", "giver": "cadoc", "where": "Cadoc the ferryman, on the mere's north bank", "zone": "mere",
		"offer": true, "avail": "qd:mere_chapel",
		"text": "Corvin's rite: a light for the eyes, the mouth, the heart. The Abbot's three stones were the other answer. Carry a lit lamp from my fire to the chapel before it gutters. That's all he ever did. It was enough to have his hands taken for.",
		"steps": [
			{"kind": "find", "text": "Take a lit lamp from Cadoc's fire"},
			{"kind": "carry", "from": "lamp_cadoc", "to": Vector2(79.5, 112.0), "r": 7.0, "time": 90.0, "label": "Corvin's lamp",
				"lost": "The lamp has guttered in the wet. Cadoc has another.",
				"text": "Carry the lamp to the half-sunk chapel before it gutters ({t} s)"},
			{"kind": "turnin", "who": "cadoc", "text": "Tell Cadoc the chapel has its light"},
		],
		"reward": {"ash": 20},
		"choose": [{"set": "ferryman", "slot": "focus", "rarity": 2}, {"set": "ferryman", "slot": "vestment", "rarity": 2}, {"set": "ferryman", "slot": "lantern", "rarity": 2}],
		"outcome": {"": "A lamp burns in the half-sunk chapel, for the eyes, the mouth, the heart. Cadoc rows past it every night and doesn't look."}},
	"mere_ferryman": {"name": "The Other Oar", "giver": "cadoc", "where": "Cadoc the ferryman, on the mere's north bank", "zone": "mere",
		"offer": true, "avail": "qd:mere_chapel",
		"text": "Two of us rowed for Corvin. Me and Aldous. The night they took Corvin's hands, Aldous rowed out alone with the lamps and went over. He walks the banks now without his boat, waiting to be paid. I owe him the fare. Pay it for me.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["ferryman"], "label": "The Ferryman Without a Boat", "at": Vector2(140.0, 128.0),
				"text": "Put down the Ferryman Without a Boat on the mere's east bank"},
			{"kind": "turnin", "who": "cadoc", "text": "Tell Cadoc the fare is paid"},
		],
		"reward": {"ash": 18, "items": {"relic_fragment": 1}},
		"choose": [{"set": "ferryman", "slot": "girdle", "rarity": 2}, {"set": "ferryman", "slot": "focus", "rarity": 2}],
		"outcome": {"": "Cadoc put two coins on the water by the east bank. They didn't sink straight away."}},
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
	# to a bell: it opens to a peal (BELLS_NEEDED of the seven). Each far country's last giver has its
	# bell; a named keeper holds it; at the bell the wanderer rings it there (the country quiets) or
	# lifts the tongue out for Hearthward (the Keg rings it when the Warden is faced: he holds less).
	"founders_peal": {"name": "The Founder's Peal", "giver": "brannoc", "where": "Brannoc Bellwright, at the Keg", "zone": "summit",
		"offer": true, "avail": "boss:thornwarden,boss:bone_abbot",
		"text": "Mother cast seven for the road up. One for each country the pilgrims crossed. When the sky opened they went quiet, top first. The door at the summit hangs from a bell; it won't open to a heart and a crown alone. It opens to a peal. Find me four. Seven, if you've the legs.",
		"steps": [
			{"kind": "cond", "cond": "bells:4", "past": "Four of the Founder's bells are already answered.", "text": "Answer for the Founder's bells ({bells} of 7; four wake the door)"},
			{"kind": "turnin", "who": "brannoc", "text": "Tell Brannoc the door will hear a peal"},
		],
		"reward": {"ash": 30, "items": {"ember_shard": 2}, "spell": "peal"},
		"choose": [{"set": "bell", "slot": "focus", "rarity": 3}, {"set": "bell", "slot": "vestment", "rarity": 3}, {"set": "bell", "slot": "girdle", "rarity": 3}],
		"outcome": {"": "Brannoc counted the bells on his fingers twice, the second time slower. \"She'd have liked you,\" he said. \"She liked people who finished things.\""}},
	"bell_holds": {"name": "The Kin Bell", "giver": "ruan", "where": "Gammer Ruan, at her fire in the Rooted Holds", "zone": "holds",
		"offer": true, "avail": "qd:keeper_leave,q:founders_peal",
		"text": "There's a bell in the Holds the Rooted never asked for. The Founder hung it in our oak anyway, to call the kin home at dusk. Something rings it at night now. With its hands. Put it down. Then decide what the bell's for.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["kin_caller"], "at": Vector2(-138.0, 20.0), "label": "The Kin-Caller",
				"text": "Put down the Kin-Caller, who rings the Kin Bell"},
			{"kind": "find", "text": "Answer for the Kin Bell under the oak"},
			{"kind": "turnin", "who": "ruan", "text": "Tell Gammer Ruan what you did with the bell"},
		],
		"alt": {"rung": {2: "Tell Gammer Ruan the kin were called home"}, "carried": {2: "Tell Gammer Ruan the tongue went to Hearthward"}},
		"reward": {"ash": 30},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "vestment", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"rung": "Ruan listened to the last of it with her eyes shut. \"That's dusk,\" she said. \"Nine winters late. They'll come or they won't.\"",
			"carried": "Ruan looked at the empty bell a long time. \"Take the Holds' share up with you, then. Ring it at him.\""}},
	"bell_quarry": {"name": "The Mason's Bell", "giver": "jory", "where": "Jory Quell, at his fire by the Saints' Quarry", "zone": "quarry",
		"offer": true, "avail": "qd:quarry_chisel,q:founders_peal",
		"text": "The cutters worked to a bell. Start, stop, eat, stop. It still hangs from the quarry crane, and the one who rings it rings start. Always start. They're still cutting. Make him stop.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["bell_hewer"], "at": Vector2(-120.0, -118.0), "label": "The Bell-Hewer",
				"text": "Put down the Bell-Hewer at the quarry crane"},
			{"kind": "find", "text": "Answer for the Mason's Bell on the crane"},
			{"kind": "turnin", "who": "jory", "text": "Tell Jory Quell what you did with the bell"},
		],
		"alt": {"rung": {2: "Tell Jory the cutters heard stop"}, "carried": {2: "Tell Jory the tongue went to Hearthward"}},
		"reward": {"ash": 30},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "girdle", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"rung": "Jory set his own pick down when he heard it, from habit. Then he laughed, once, and left it there.",
			"carried": "\"Stop, then, at the top,\" Jory said. \"Somebody up there owes the cutters four thousand steps of wages.\""}},
	"bell_moor": {"name": "The Wayfarer's Bell", "giver": "ysolt", "where": "Ysolt, at her fire under the tor", "zone": "moor",
		"offer": true, "avail": "qd:moor_hennet,q:founders_peal",
		"text": "The fog bell on the moor. Rung in the murk so pilgrims would walk to it and not into the bog. Nobody's rung it in nine winters, and still they walk to it. Something waits for them there.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["fog_shepherd"], "at": Vector2(146.0, -28.0), "label": "The Fog-Shepherd",
				"text": "Put down the Fog-Shepherd at the fog bell"},
			{"kind": "find", "text": "Answer for the Wayfarer's Bell on its post"},
			{"kind": "turnin", "who": "ysolt", "text": "Tell Ysolt what you did with the bell"},
		],
		"alt": {"rung": {2: "Tell Ysolt the moor has a bell again"}, "carried": {2: "Tell Ysolt the tongue went to Hearthward"}},
		"reward": {"ash": 30},
		"choose": [{"slot": "vestment", "rarity": 2}, {"slot": "girdle", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"rung": "Ysolt added a stone to the nearest cairn without looking at it. \"Now they've something to walk to that isn't the bog.\"",
			"carried": "\"Then the moor stays dark,\" Ysolt said. \"It's good at it. Make the bell worth it.\""}},
	"bell_foundry": {"name": "The Tenor", "giver": "elspeth", "where": "Elspeth Fane, at her fire in the Founder's Pits", "zone": "foundry",
		"offer": true, "avail": "qd:founder_peal,q:founders_peal",
		"text": "Her own bell. The tenor. She cast it last and best and never hung it: it stood in the pits waiting for the Stair to be finished. It wasn't. Something crawled into it out of the slag to keep warm.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["slag_born"], "at": Vector2(140.0, -90.0), "label": "The Slag-Born",
				"text": "Put down the Slag-Born curled in the Founder's tenor"},
			{"kind": "find", "text": "Answer for the Tenor in the casting pit"},
			{"kind": "turnin", "who": "elspeth", "text": "Tell Elspeth Fane what you did with the Tenor"},
		],
		"alt": {"rung": {2: "Tell Elspeth the Tenor was rung where it was cast"}, "carried": {2: "Tell Elspeth the Tenor's tongue went to her son"}},
		"reward": {"ash": 30},
		"choose": [{"set": "bell", "slot": "focus", "rarity": 2}, {"set": "bell", "slot": "lantern", "rarity": 2}],
		"outcome": {"rung": "Elspeth didn't turn from her fire. \"First time,\" she said. \"It's a better note than she said it'd be. She always undersold.\"",
			"carried": "\"Her son should have it,\" Elspeth said. \"He's been ringing nothing in that chimney for nine years.\""}},
	"bell_orchard": {"name": "The Harvest Bell", "giver": "linnet", "where": "Linnet, at her fire in the Cinder Orchard", "zone": "orchard",
		"offer": true, "avail": "qd:orchard_pippin,q:founders_peal",
		"text": "The brothers rang the harvest in. The bell hung in the press-house yard and it's still there, under ash, and something grubs round it as if it were a root. Dig it out.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["ash_sower"], "at": Vector2(-98.0, 128.0), "label": "The Ash-Sower",
				"text": "Put down the Ash-Sower in the press-house yard"},
			{"kind": "find", "text": "Answer for the Harvest Bell under the ash"},
			{"kind": "turnin", "who": "linnet", "text": "Tell Linnet what you did with the bell"},
		],
		"alt": {"rung": {2: "Tell Linnet the harvest was rung in"}, "carried": {2: "Tell Linnet the tongue went to Hearthward"}},
		"reward": {"ash": 30},
		"choose": [{"set": "kindler", "slot": "focus", "rarity": 2}, {"set": "kindler", "slot": "vestment", "rarity": 2}],
		"outcome": {"rung": "Linnet said the grafted stock put out a leaf the hour the bell rang. She said it as if she'd caught it cheating.",
			"carried": "\"Nothing to harvest anyway,\" Linnet said. \"Not this year. Take it.\""}},
	"bell_necropolis": {"name": "The Passing Bell", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
		"offer": true, "avail": "qd:abbot_names,q:founders_peal",
		"text": "One stroke for each soul gone up. The Abbot had it rung day and night till the rope wore through. They've made a new rope. Out of what, I'd rather you saw than I said.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["passing_ringer"], "at": Vector2(-4.0, 128.0), "label": "The Passing-Ringer",
				"text": "Put down the Passing-Ringer in the Waiting Field"},
			{"kind": "find", "text": "Answer for the Passing Bell and its rope"},
			{"kind": "turnin", "who": "agathe", "text": "Tell Sister Agathe what you did with the bell"},
		],
		"alt": {"rung": {2: "Tell Sister Agathe the Field heard its last stroke"}, "carried": {2: "Tell Sister Agathe the tongue went to Hearthward"}},
		"reward": {"ash": 30},
		"choose": [{"set": "tally", "slot": "vestment", "rarity": 2}, {"set": "tally", "slot": "girdle", "rarity": 2}],
		"outcome": {"rung": "Agathe counted the strokes out loud and stopped at one. \"That's for all of them,\" she said. \"He'd have hated it.\"",
			"carried": "\"Good,\" Agathe said. \"Let it pass him, for once.\""}},
	"bell_mere": {"name": "The Ferry Bell", "giver": "cadoc", "where": "Cadoc the ferryman, on the mere's north bank", "zone": "mere",
		"offer": true, "avail": "qd:mere_ferryman,q:founders_peal",
		"text": "On the far bank there's a post and a bell: ring it and the ferry comes. Corvin's bell. Somebody's been ringing it from the water side. I don't go.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["fare_caller"], "at": Vector2(132.0, 108.0), "label": "The Fare-Caller",
				"text": "Put down the Fare-Caller by the ferry post"},
			{"kind": "find", "text": "Answer for the Ferry Bell on its post"},
			{"kind": "turnin", "who": "cadoc", "text": "Tell Cadoc what you did with the bell"},
		],
		"alt": {"rung": {2: "Tell Cadoc you rang for the ferry"}, "carried": {2: "Tell Cadoc the tongue went to Hearthward"}},
		"reward": {"ash": 30},
		"choose": [{"set": "ferryman", "slot": "focus", "rarity": 2}, {"set": "ferryman", "slot": "lantern", "rarity": 2}],
		"outcome": {"rung": "Cadoc said he heard it and nearly went. Then he remembered there's no boat. Then he went anyway, as far as his knees.",
			"carried": "\"Then nobody calls me across,\" Cadoc said. \"Good. I'm tired.\""}},
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
			{"kind": "visit", "at": Vector2(0.0, -103.9), "r": 8.0, "label": "The door in the sky", "text": "Climb back to the Warden's dais, under the door"},
			{"kind": "find", "text": "Decide what the latch is for"},
			{"kind": "turnin", "who": "brannoc", "text": "Tell Brannoc what you did at the door"},
		],
		"alt": {"latched": {2: "Tell Brannoc the door is latched"}, "open": {2: "Tell Brannoc the door is left on the latch"}, "broken": {2: "Tell Brannoc the latch is broken"}},
		"reward": {"ash": 40, "items": {"relic_fragment": 3}},
		"choose": [{"legend": "door_splinter"}, {"legend": "sunk_shroud"}, {"legend": "unlit_lamp"}, {"legend": "stair_rope"}],
		"outcome": {"latched": "Brannoc nodded once. \"Then nothing more goes up. And nothing up there comes down. She'd have done that. She liked things finished.\"",
			"open": "\"On the latch,\" Brannoc said. \"So the ones still climbing can turn round. That's kinder than she was.\"",
			"broken": "Brannoc looked at the two halves of the latch for a long time. \"Then it's only sky,\" he said. \"Just sky. I don't know if that's better. Nobody does.\""}},
	"still_climbing": {"name": "Those Still Climbing", "giver": "agathe", "where": "Sister Agathe, at the gate of the Waiting Field", "zone": "necropolis",
		"offer": true, "avail": "qd:the_latch",
		"text": "Since the door, the ones who were halfway up have been coming down. Not all of them know they're dead. Some walk into the Field and stand in their old places. Some walk into it with their hands out. Put down the ones with their hands out.",
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
		"text": "The dais stone. 'The names of the faithful who went through,' and nothing cut under it. I've been thinking about that. Ask about. Get me a name from every fire in the far country, somebody who went up, and cut them in. Then come and sit down. For good, this time.",
		"steps": [
			{"kind": "gather", "of": 6, "text": "Ask a name of the faithful at the fires of the far country, the Marches and the downs among them ({n}/{of})"},
			{"kind": "find", "text": "Cut the names into the dais stone under the door"},
			{"kind": "turnin", "who": "keep", "text": "Sit on your stool at the Kindled Keg"},
		],
		"reward": {"ash": 50},
		"choose": [{"set": "bell", "slot": "focus", "rarity": 4}, {"set": "bell", "slot": "vestment", "rarity": 4}, {"set": "bell", "slot": "lantern", "rarity": 4}, {"set": "bell", "slot": "girdle", "rarity": 4}],
		"outcome": {"": "The keep poured two. He drank his and then, after a while, yours. \"Somebody should,\" he said."}},
	"full_peal": {"name": "The Full Peal", "giver": "brannoc", "where": "Brannoc Bellwright, at the Keg", "zone": "summit",
		"offer": true, "avail": "qd:the_latch",
		"text": "Four woke the door. Seven is what she cast. I'd like to hear it, once, the way she meant it: every bell answered for, top to bottom, or bottom to top, I don't care which. You've the legs. I've watched you.",
		"steps": [
			{"kind": "cond", "cond": "bells:7", "text": "Answer for all seven of the Founder's bells ({bells} of 7)"},
			{"kind": "turnin", "who": "brannoc", "text": "Tell Brannoc the peal is whole"},
		],
		"reward": {"ash": 60, "items": {"ember_shard": 5, "relic_fragment": 5}},
		"choose": [{"legend": "door_splinter"}, {"legend": "sunk_shroud"}, {"legend": "unlit_lamp"}, {"legend": "stair_rope"}],
		"outcome": {"": "Brannoc rang the chimney tongue seven times, slowly, and the Keg went quiet for each one. Then he put his head down on the bar and laughed."}},
	"shepherd_strays": South.QUESTS["shepherd_strays"], "oak_song": South.QUESTS["oak_song"], "well_answer": South.QUESTS["well_answer"],
	"wf_wheel": R37WQ.QUESTS["wf_wheel"], "wf_watch": R37WQ.QUESTS["wf_watch"], "wf_lights": R37WQ.QUESTS["wf_lights"],
	"wf_crown": R37WQ.QUESTS["wf_crown"], "salt_sweep": R37E.SALT_SWEEP, "salt_widow": R37E.SALT_WIDOW,
	"spire_coal": R37E.SPIRE_COAL, "anchor_names": R37E.ANCHOR_NAMES, "anchor_vow": R37E.ANCHOR_VOW,
}

## r36: the bell quests (Act II), in no order; BELLS_NEEDED of them wake the summit door.
const BELLS := ["bell_holds", "bell_quarry", "bell_moor", "bell_foundry", "bell_orchard", "bell_necropolis", "bell_mere"]
const BELLS_NEEDED := 4
## r36: the bells' keepers (rares.gd RARES keys; a bell quest's slay step wants its own).
const BELL_KEEPERS := ["kin_caller", "bell_hewer", "fog_shepherd", "slag_born", "ash_sower", "passing_ringer", "fare_caller"]

const PICKUPS := {
	"tongs": {"quest": "edda_tongs", "step": 0, "near": Vector2(-84.35, 44.15), "kind": "tongs", "name": "Edda's tongs", "verb": "Take",
		"say": "Smith's tongs, the jaws burned black. Somebody has wrapped the handles in new cloth."},
	"tongs_back": {"quest": "edda_tongs", "step": 2, "near": Vector2(-84.35, 44.15), "kind": "place", "name": "Edda's stone", "verb": "Lay the tongs on",
		"say": "You lay the tongs on the stone. It is warmer than it should be."},
	"slate_glade": {"quest": "names_yard", "step": 0, "near": Vector2(-35.0, 11.0), "kind": "slate", "name": "a name-slate", "verb": "Read",
		"say": "MAREN COYLE. SHE SANG THE LOW PART. Scratched with a nail, under a number somebody chiselled first."},
	"slate_lane": {"quest": "names_yard", "step": 0, "near": Vector2(-63.0, 55.5), "kind": "slate", "name": "a name-slate", "verb": "Read",
		"say": "TAM, THE CARTER'S BOY. NINE. LIKED HORSES. The number above it has been rubbed out with a thumb."},
	"slate_barrow": {"quest": "names_yard", "step": 0, "near": Vector2(80.0, -34.0), "kind": "slate", "name": "a name-slate", "verb": "Read",
		"say": "SISTER IDE, WHO KEPT THE BEES. NOT A NUMBER. The last three words are cut deeper than the rest."},
	"mug_yard": {"quest": "keg_thief", "step": 0, "near": Vector2(27.5, 32.4), "kind": "mug", "name": "a dropped mug", "verb": "Look at",
		"say": "One of the Keg's mugs, dry, on its side. Round it on the flags, a circle in chalk. A child's hand. Another circle further on, toward the green."},
	"mug_fire": {"quest": "keg_thief", "step": 1, "near": Vector2(-3.3, 34.5), "kind": "mug_full", "name": "a full mug by the fire", "verb": "Look at",
		"say": "A mug of the Keg's ale, full, set down by the fire inside a chalk circle. Waiting for somebody who is not here."},
	"lantern": {"quest": "slow_way", "step": 2, "near": Vector2(58.0, -47.0), "kind": "lantern", "name": "Father Harrow's lantern", "verb": "Take",
		"say": "A tin lantern, the glass cracked. HARROW scratched on the base. The wick is dry. It has not been lit in a long time."},
	# r33
	"coal": {"quest": "coal_shrine", "step": 0, "near": Vector2(2.6, 31.2), "kind": "coal", "name": "a live coal", "verb": "Take",
		"say": "You lift a coal from the green's fire in an iron dish. It pulses like something breathing. Go."},
	"alms": {"quest": "alms_loaf", "step": 1, "near": Vector2(42.0, 46.0), "kind": "loaf", "name": "the last loaf", "verb": "Take",
		"say": "One loaf on the Almonry's board, hard as a stone, a cross cut in the crust. There is always one left."},
	"bell_tongue": {"quest": "drowned_bell", "step": 1, "near": Vector2(77.0, -12.0), "kind": "clapper", "name": "the bell's iron tongue", "verb": "Take",
		"say": "The clapper lies in the reeds where the water dropped it, a yard of black iron. It is cold, and it hums when you lift it."},
	# r34. `camp`: the spot is found by that giver's outpost fire (village.gd builds it at load), `near`
	# is only the fallback.
	"ward_holds": {"quest": "keeper_wards", "step": 0, "near": Vector2(-141.0, 4.0), "kind": "ward", "name": "a ward-stone", "verb": "Lift",
		"say": "A grey stone the size of a loaf, a spiral cut in it, lying face up in the heather. It is heavier than it should be. You turn it face down without thinking."},
	"ward_wood": {"quest": "keeper_wards", "step": 0, "near": Vector2(-66.0, 30.0), "kind": "ward", "name": "a ward-stone", "verb": "Lift",
		"say": "A ward-stone in the oak roots, an axe-bite in its edge. The Order's chisel has cut KEEPER OF NOTHING over the spiral. The spiral is deeper."},
	"ward_glade": {"quest": "keeper_wards", "step": 0, "near": Vector2(-44.0, 4.0), "kind": "ward", "name": "a ward-stone", "verb": "Lift",
		"say": "Somebody left the third ward-stone among the glade's offerings, with a candle on it. The candle is still warm."},
	"coal_ruan": {"quest": "keeper_leave", "step": 0, "near": Vector2(-129.0, 6.0), "camp": "ruan", "kind": "coal", "name": "a ward-coal", "verb": "Take",
		"say": "A coal of black heartwood in a clay dish. It burns green at the edges and smells of oak in rain. Go."},
	"mark_pit": {"quest": "quarry_marks", "step": 0, "near": Vector2(-124.0, -106.0), "kind": "mark", "name": "a squared block", "verb": "Take the mark from",
		"say": "A squared block on the pit floor, ready to carry. A mark on its end: a hook and two strokes. Wat Mallow, it will turn out. He was paid for this one."},
	"mark_shelter": {"quest": "quarry_marks", "step": 0, "near": Vector2(-142.0, -115.0), "kind": "mark", "name": "a squared block", "verb": "Take the mark from",
		"say": "A block under the high bench, half buried in chips. The mark is a little ladder. Somebody has scratched a face beside it, smiling."},
	"mark_bench": {"quest": "quarry_marks", "step": 0, "near": Vector2(-117.0, -94.0), "kind": "mark", "name": "a squared block", "verb": "Take the mark from",
		"say": "A block on the east bench, split along a flaw and left. The mark is a Q with a tail. Quell. It was cut by the brother."},
	"last_step": {"quest": "quarry_last", "step": 1, "near": Vector2(-129.0, -103.0), "kind": "mark", "name": "the blessed block", "verb": "Read",
		"say": "A step-stone, squared and dressed and blessed, never carried. Cut in its tread: HERE THE FAITHFUL STEP OFF. Under it, smaller, a cutter's hand: and the rest of us go home."},
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
	"door_latch": {"quest": "the_latch", "step": 1, "near": Vector2(0.0, -101.5), "kind": "slate", "name": "the latch-stone under the door", "verb": "Stand at", "conv": "door_latch",
		"say": "The latch-stone."},
	"name_ruan": {"quest": "names_under", "step": 0, "near": Vector2(-129.0, 6.0), "camp": "ruan", "kind": "slate", "name": "a name", "verb": "Ask for",
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
	"dais_names": {"quest": "names_under", "step": 1, "near": Vector2(1.5, -101.0), "kind": "place", "name": "the dais stone", "verb": "Cut the names into",
		"say": "You cut them under the Hierarch's line, small, as straight as you can: BRANN. MAUD OF THE TOR. BROTHER ANSELM, HE PRUNED. CORVIN. WAT, WHO NEVER LOST ONE. HALE, AND HE LEFT IT LIT. There is room under them for a great many more."},
	# r36 Act II: the Founder's bells (each opens the bell's conversation: ring it here, or carry the tongue)
	"bell_holds": {"quest": "bell_holds", "step": 1, "near": Vector2(-138.0, 20.0), "kind": "bell", "name": "the Kin Bell", "verb": "Stand at", "conv": "bell_holds",
		"say": "A small bronze bell hung in the oak's fork on a rope of plaited bark. The Rooted carved their knot into the wood above it, to say they hadn't asked for it and would keep it anyway."},
	"bell_quarry": {"quest": "bell_quarry", "step": 1, "near": Vector2(-120.0, -118.0), "kind": "bell", "name": "the Mason's Bell", "verb": "Stand at", "conv": "bell_quarry",
		"say": "A plain iron bell slung from the quarry crane's arm, its rope tied off at the stop stroke and cut through above the knot. Under it, every cutter's mark in the quarry, chiselled into one block."},
	"bell_moor": {"quest": "bell_moor", "step": 1, "near": Vector2(146.0, -28.0), "kind": "bell", "name": "the Wayfarer's Bell", "verb": "Stand at", "conv": "bell_moor",
		"say": "The fog bell on its post, green with weather. The ground round it is worn to stone by people who walked here in the murk and stood, and waited, for it to ring."},
	"bell_foundry": {"quest": "bell_foundry", "step": 1, "near": Vector2(140.0, -90.0), "kind": "bell", "name": "the Tenor", "verb": "Stand at", "conv": "bell_foundry",
		"say": "The Founder's tenor, standing mouth-down in the casting pit as she left it. Her mark on the shoulder: a hand, open. Your palm fits it."},
	"bell_orchard": {"quest": "bell_orchard", "step": 1, "near": Vector2(-98.0, 128.0), "kind": "bell", "name": "the Harvest Bell", "verb": "Stand at", "conv": "bell_orchard",
		"say": "The harvest bell, dug half out of the ash, an apple branch cast round its waist in bronze. One bronze apple has been worn bright by thumbs."},
	"bell_necropolis": {"quest": "bell_necropolis", "step": 1, "near": Vector2(-4.0, 128.0), "kind": "bell", "name": "the Passing Bell", "verb": "Stand at", "conv": "bell_necropolis",
		"say": "The Passing Bell on its frame, the new rope coiled at its foot. The rope is braided hair. Grey, brown, a child's yellow."},
	"bell_mere": {"quest": "bell_mere", "step": 1, "near": Vector2(132.0, 108.0), "kind": "bell", "name": "the Ferry Bell", "verb": "Stand at", "conv": "bell_mere",
		"say": "Corvin's ferry bell on its post at the water's edge, the bronze furred with weed below the line the mere rose to. CALL AND WAIT, cut in the post."},
	"cairn_down_1": South.PICKUPS["cairn_down_1"], "cairn_down_2": South.PICKUPS["cairn_down_2"], "cairn_down_3": South.PICKUPS["cairn_down_3"],
	"wf_sluice_key": R37WQ.PICKUPS["wf_sluice_key"], "wf_signal_lamp": R37WQ.PICKUPS["wf_signal_lamp"], "wf_votive_a": R37WQ.PICKUPS["wf_votive_a"],
	"wf_votive_b": R37WQ.PICKUPS["wf_votive_b"], "wf_votive_c": R37WQ.PICKUPS["wf_votive_c"], "wf_votive_place": R37WQ.PICKUPS["wf_votive_place"],
	"wf_rub_hand": R37WQ.PICKUPS["wf_rub_hand"], "wf_rub_shoulder": R37WQ.PICKUPS["wf_rub_shoulder"], "wf_rub_lip": R37WQ.PICKUPS["wf_rub_lip"],
	"coal_ardel": R37E.COAL_ARDEL, "anchor_page_a": R37E.PAGE_A, "anchor_page_b": R37E.PAGE_B,
	"anchor_page_c": R37E.PAGE_C,
}

## Oswin's walk: from wherever he is to the waystone. He keeps 2-3 m behind you and waits when you
## run off; the step is done when he stands within `reach` of the stone.
## The forty-first waystone itself stands at `stone` (quest_world.gd puts it there for good).
const ESCORT := {"quest": "forty_first", "step": 0, "who": "oswin", "to": Vector2(-1.9, 17.4), "stone": Vector2(-2.9, 16.4), "reach": 4.5, "wait_r": 16.0}

## Father Harrow: wakes when you come within `wake` of the lantern on step 0, falls on step 1.
const HOLLOW := {"quest": "slow_way", "near": Vector2(58.0, -47.0), "wake": 24.0, "hp": 9, "title": "Father Harrow, hollowed"}

const KINDS := ["find", "gather", "talk", "escort", "kill", "place", "reach",
	"slay", "collect", "seal", "cond", "visit", "carry", "turnin"]
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
			if String(s.kind) in ["visit", "carry"] and not (s.get("at", s.get("to")) is Vector2):
				bad.append("%s: a %s step has no place" % [id, s.kind])
		for si in (qd.steps as Array).size():
			var kind := String(qd.steps[si].kind)
			if kind in ["find", "gather", "place"] and gather_keys(id, si).is_empty():
				bad.append("%s step %d (%s) has no pickup" % [id, si, kind])
			if kind == "gather" and gather_keys(id, si).size() != int(qd.steps[si].get("of", 1)):
				bad.append("%s step %d gathers %d of %d" % [id, si, gather_keys(id, si).size(), int(qd.steps[si].get("of", 1))])
			# every step that sends you somewhere says where, so the map's task row never goes blank (the
			# peal's steps point at the nearest unanswered bell; the two standing bounties roam)
			if kind in ["slay", "collect", "cond", "visit", "seal"] and not (qd.steps[si].get("to", qd.steps[si].get("at")) is Vector2) \
					and not String(qd.steps[si].get("cond", "")).begins_with("bells:") and not id in ["rare_head", "keeper_again"]:
				bad.append("%s step %d (%s) has no map target" % [id, si, kind])
			if kind == "carry" and (si == 0 or not PICKUPS.has(String(qd.steps[si].get("from", ""))) or int(PICKUPS[qd.steps[si].from].step) != si - 1):
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
