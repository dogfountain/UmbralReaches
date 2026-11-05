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
##   PICKUPS  world things a step wants: {quest, step, near (xz), kind (mesh), name, verb, say}
##   ESCORT / HOLLOW  the two moving pieces (Oswin's walk, Father Harrow)
## House style (docs/LORE.md): terse, concrete, dark. Load by path.

## The ledger's chapters (ui/quest_log.gd), in order: [id, name].
const ZONES := [["hearth", "Hearthward"], ["road", "The Pilgrims' Road"], ["thornwood", "The Thornwood"],
	["fen", "The Hollow Fen"], ["ossuary", "The Ossuary"], ["summit", "The Summit of Ascension"]]

const ORDER := ["edda_tongs", "forty_first", "names_yard", "keg_thief", "slow_way",
	"hearth_ash", "road_clear", "coal_shrine", "spire_lamps", "alms_loaf",
	"thorn_door", "smoke_oaks", "ring_heart", "unpaid_toll",
	"bead_count", "drowned_bell", "count_below", "crossing_ward"]

## Who stands where, for the map's turn-in pins when the person is not in the night's tree.
const GIVER_NAMES := {"hild": "Hild", "fennick": "Old Fennick", "oswin": "Oswin", "nan": "Nan Wright", "abel": "Abel the sexton",
	"wyck": "Wyck", "grisel": "Grisel", "keep": "The keep", "harrow": "Ostrin Harrow", "hesk": "Hesk", "brannoc": "Brannoc"}

const QUESTS := {
	"edda_tongs": {"name": "Edda's Tongs", "giver": "hild", "where": "Hild, at Edda's forge", "zone": "hearth",
		"text": "Edda's tongs lie on her stone in the Kindlers' Yard. Hild wants them back on the anvil, and cannot make herself fetch them.",
		"steps": [
			{"kind": "find", "text": "Find Edda's tongs on her stone in the Kindlers' Yard, west past Abel's dig"},
			{"kind": "talk", "who": "hild", "text": "Bring Edda's tongs to Hild at the forge"},
			{"kind": "place", "text": "Lay Edda's tongs back on her stone in the Kindlers' Yard"},
		],
		"reward": {"ash": 10},
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
		"reward": {},
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
			{"kind": "collect", "of": 5, "chance": 0.6, "label": "Bone ash", "text": "Gather bone ash from the hollowed you put down ({n}/{of})"},
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
			{"kind": "cond", "cond": "boss:thornwarden", "at": Vector2(-72.0, -18.0), "label": "The Thornwarden",
				"text": "Cut the Thorn Heart from the Thornwarden in the Ring"},
			{"kind": "turnin", "who": "wyck", "text": "Bring a thorn to Wyck"},
		],
		"reward": {"ash": 25},
		"choose": [{"set": "kindler", "slot": "focus", "rarity": 2}, {"set": "kindler", "slot": "lantern", "rarity": 2}, {"set": "kindler", "slot": "vestment", "rarity": 2}],
		"outcome": {"": "Wyck buried the thorn face down by his fire, and sang the verse the abbey chiselled off."}},
	"unpaid_toll": {"name": "The Toll Unpaid", "giver": "hesk", "where": "Hesk the Woodcutter, at the Keg", "zone": "thornwood",
		"offer": true,
		"text": "Tollmen. Ride with the war bands, ring a bell, and the whole wood comes running. One of 'em had my brother's axe. Put two of 'em down before they ring. Then I'll drink easier.",
		"steps": [
			{"kind": "slay", "of": 2, "kinds": ["tollman"], "label": "Tollmen", "at": Vector2(-92.0, -30.0),
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
			{"kind": "collect", "of": 4, "chance": 0.75, "kinds": ["ossuant"], "label": "Tally-beads", "at": Vector2(96.0, -30.0),
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
		"outcome": {"": "Brannoc hung the drowned bell's tongue over the Keg's door. It doesn't ring. He checks."}},
	# the summit: the keep's last word
	"crossing_ward": {"name": "The Ward on the Crossing", "giver": "keep", "where": "The keep of the Kindled Keg", "zone": "summit",
		"offer": true, "avail": "boss:thornwarden,boss:bone_abbot",
		"text": "Heart and crown. The ward on the Crossing will know them. It has guards that don't sleep; put them down and it lets you through. Then the top. I'll keep your stool warm. Come back and sit on it.",
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
}

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
			if kind == "carry" and (si == 0 or not PICKUPS.has(String(qd.steps[si].get("from", ""))) or int(PICKUPS[qd.steps[si].from].step) != si - 1):
				bad.append("%s step %d carries no pickup taken the step before" % [id, si])
		if bool(qd.get("offer", false)):
			var last: Dictionary = (qd.steps as Array).back()
			if String(last.kind) != "turnin":
				bad.append("%s: an offered task ends in a turn-in" % id)
		for opts: Dictionary in qd.get("choose", []):
			if opts.has("set") and not ["kindler", "ferryman", "tally", "bell"].has(String(opts.set)):
				bad.append("%s: unknown gear set %s" % [id, opts.set])
	for k: String in PICKUPS:
		var p: Dictionary = PICKUPS[k]
		if not QUESTS.has(String(p.quest)) or int(p.step) >= (QUESTS[p.quest].steps as Array).size():
			bad.append("pickup %s: bad quest/step" % k)
	return bad
