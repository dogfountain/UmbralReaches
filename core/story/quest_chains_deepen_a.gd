extends RefCounted
## Writer A's deepened tasks (docs/QUEST_DEPTH.md, workstream A): Hearthward, the Thornwood, the fen and the Ossuary,
## in the quest_chains.gd manner. Each has a verb beat (docs/QUEST_VERBS.md), a choice, and something the player can
## see afterwards (a hub line, a left prop, the keep's news). Ids, givers and rewards unchanged except the two new tasks.
##
##   NAMES_YARD     Names for the Yard       the three slates say who hid them; the names are cut at the Yard's wall: with the hiders, or deep
##   FORTY_FIRST    The Forty-First Stone    after the stone's choice, a lamp lit at the green and walked to it (a post kept, or a road lit)
##   RING_HEART     What the Oaks Keep       clues + order: the Song of the Ring's four stones read, then touched in verse; the heart's owner
##   UNPAID_TOLL    The Toll Unpaid          tracks + clues: the bell-rope's drag to the post, three axe-marks; the axe to Hild or the cairn
##   BEAD_COUNT     The Lay Brothers' Beads  the beads against the Tally posts; is Brother Lisle one of the count
##   THREE_KNOCKS   Three Knocks (new)       Maud's three unsent letters; a night sat up at her door; open, leave it barred, or answer
##   FORTY_DAYS     Forty Days Late (new)    the Ninth Company's notched stakes, their burned tokens and one whole; bury it or carry it
## The pickups and conversations they use are listed in PICKUPS and in dialogue_db.gd (CONV: the pickups' `conv`).
## House style (docs/LORE.md): terse, concrete, dark.

const NAMES_YARD := {"name": "Names for the Yard", "giver": "abel", "where": "Abel the sexton, by the Kindlers' Yard", "zone": "hearth",
	"text": "The Order cut numbers where the names should be. A few of the faithful scratched the names back on slates and hid them.",
	"steps": [
		{"kind": "gather", "of": 3, "text": "Find the three name-slates: in the Glimmer Glade, on the chapel lane, in the Barrow Field ({n}/{of})"},
		{"kind": "talk", "who": "abel", "text": "Bring the names to Abel at his dig"},
		{"kind": "find", "text": "Cut the names into the Yard's wall, by Edda's stone"},
	],
	"reward": {"ash": 15, "items": {"relic_fragment": 1}},
	"leaves": {"confess": {"at": Vector2(-79.6, 46.4), "prop": "page"}},
	"outcome": {"confess": "Maren Coyle, Tam, Sister Ide: cut in the Kindlers' Yard by Edda's stone, and under each the place its slate hid, so the hiders are named with them.",
		"deep": "Maren Coyle, Tam, Sister Ide: their names are cut in the Kindlers' Yard, by Edda's stone. Only the names. As deep as the stone goes.",
		"": "Maren Coyle, Tam, Sister Ide: their names are cut in the Kindlers' Yard, by Edda's stone."}}

const FORTY_FIRST := {"name": "The Forty-First Stone", "giver": "oswin", "where": "Joram the pilgrim, on the west road", "zone": "road",
	"text": "Joram has touched forty waystones on the way to the Stair. He wants to touch the last, and his eyes are bad in the dark.",
	"steps": [
		{"kind": "escort", "text": "Walk Joram to the forty-first waystone, at the head of the north lane past the green"},
		{"kind": "talk", "who": "oswin", "text": "Speak with Joram at the forty-first stone"},
		{"kind": "find", "text": "Light a lamp at the green's fire for the forty-first stone"},
		{"kind": "lantern_walk", "from": "oswin_flame", "to": Vector2(-2.9, 16.4), "r": 4.0, "label": "The forty-first stone",
			"relight": "Light another at the green's fire.",
			"arrive": "You set the lamp at the stone's foot. Joram watches the flame settle, and does not say anything.",
			"text": "Carry the lit lamp to the forty-first stone. Walk it: a run, a roll, a blow or deep water puts it out"},
	],
	"alt": {"faith": {2: "Light a lamp at the green's fire for Joram's vigil",
			3: "Carry the lit lamp to the forty-first stone, to stand there kept"},
		"truth": {2: "Light a lamp at the green's fire to see Joram off",
			3: "Carry the lit lamp to the forty-first stone, for Joram's road home"}},
	"reward": {"ash": 12, "charm": "charm_waystone", "else": {"relic_fragment": 1}},
	"leaves": {"faith": {"at": Vector2(-1.5, 17.6), "prop": "lantern_lit"}, "truth": {"at": Vector2(-1.5, 17.6), "prop": "lantern"}},
	"outcome": {"truth": "You told Joram the Stair is gone. He stopped counting waystones, and set his staff against the wall of the road's rest. The lamp you lit stands cold at the forty-first, and his chalk arrows point west.",
		"faith": "Joram keeps his vigil at the forty-first stone, waiting for a bell. The lamp you lit burns at its foot, so the ones coming up the lane can tell it is kept."}}

const RING_HEART := {"name": "What the Oaks Keep", "giver": "wyck", "where": "Wyck, at his fire in the Thornwood", "zone": "thornwood",
	"offer": true, "avail": "qd:thorn_door",
	"text": "The Thornwarden roots in a heart. Cut it out and the wood forgets it was ever kept. I won't say do it. I won't say don't. The Rooted cut a song into four stones round the hill, one to a side, and the Order chiselled the last verse off. It has to be sung in order, hand on each, or the hill answers wrong. Read them first. Then bring me a thorn off it, after. I'll bury it face down.",
	"steps": [
		{"kind": "clues", "at": Vector2(-86.0, -24.0), "r": 70.0, "label": "The Song of the Ring",
			"text": "Read the four verse-stones round the Ring's hill, one to each side ({n}/{of} read)",
			"clues": [
				{"key": "i", "at": Vector2(-84.0, 22.0), "prop": "ward", "name": "a verse-stone", "verb": "Read",
					"text": "One stroke cut in the stone's face, and under it the Rooted's hand: THE ROOTED ASKED A THORN TO STAND WHERE THE AXE WOULD COME."},
				{"key": "ii", "at": Vector2(-60.0, -62.0), "prop": "ward", "name": "a verse-stone", "verb": "Read",
					"text": "Two strokes. IT ASKED FOR A HEART TO ROOT IN. The cut is old and clean, and wet with something that is not rain."},
				{"key": "iii", "at": Vector2(-41.0, -30.0), "prop": "ward", "name": "a verse-stone", "verb": "Read",
					"text": "Three strokes. KEEPER, KEEP. DO NOT CLIMB. Somebody has left a single oak leaf on it, face down."},
				{"key": "iv", "at": Vector2(-130.2, -25.6), "prop": "ward", "name": "a verse-stone", "verb": "Read",
					"text": "Four strokes, and then the chisel: the face is cut flat, and over the flat the Order's hand, IDOLATRY. BURN IT. It did not burn. In the grain, where the chisel missed, the old hand shows through: whose?"},
			]},
		{"kind": "order", "at": Vector2(-72.0, -18.0), "label": "The verse-stones",
			"text": "Touch the four verse-stones in the order of the song: the strokes count the verses",
			"things": [
				{"key": "i", "at": Vector2(-84.0, 22.0), "prop": "ward", "name": "the stone of one stroke", "text": "The first stone warms under your palm, a dog's warmth. The Ring's hill, far off, draws a breath."},
				{"key": "ii", "at": Vector2(-60.0, -62.0), "prop": "ward", "name": "the stone of two strokes", "text": "The second answers lower, from under the roots. Something up the hill turns toward you."},
				{"key": "iii", "at": Vector2(-41.0, -30.0), "prop": "ward", "name": "the stone of three strokes", "text": "The third is quiet, as a thing is quiet that is listening."},
				{"key": "iv", "at": Vector2(-130.2, -25.6), "prop": "ward", "name": "the chiselled stone", "text": "The chiselled stone is cold. Then, under your hand, in the place the chisel took, a little warm."},
			],
			"order": ["i", "ii", "iii", "iv"],
			"wrong": "The stone goes cold under your hand and stays cold. The song was sung out of order. In the oaks a thorn stands up.",
			"wrong_spawns": {"kind": "crawler", "n": 2},
			"done": "Four verses, in order. The hill lets go of a breath it has held a long time."},
		{"kind": "cond", "cond": "boss:thornwarden", "at": Vector2(-72.0, -18.0), "label": "The Thornwarden", "past": "The Thorn Heart is already cut.",
			"text": "Cut the Thorn Heart from the Thornwarden in the Ring"},
		{"kind": "find", "text": "Take a thorn off the Heart, and decide whose it was"},
		{"kind": "turnin", "who": "wyck", "text": "Bring a thorn to Wyck"},
	],
	"alt": {"nobody": {4: "Bring a thorn to Wyck: it was nobody's heart"}, "rooted": {4: "Bring a thorn to Wyck: it was a Rooted's heart"}},
	"reward": {"ash": 25},
	"choose": [{"set": "kindler", "slot": "focus", "rarity": 2}, {"set": "kindler", "slot": "lantern", "rarity": 2}, {"set": "kindler", "slot": "vestment", "rarity": 2}],
	"outcome": {"nobody": "Wyck buried the thorn face down and said it was nobody's: a thing the Rooted made to keep a wood, and it kept it. He sang the verse the abbey chiselled off, with no name in it.",
		"rooted": "Wyck buried the thorn face down and put a name over it, one he did not tell you. It is the first time that verse has been finished aloud since the chisel.",
		"": "Wyck buried the thorn face down, and sang the verse the abbey chiselled off."}}

const UNPAID_TOLL := {"name": "The Toll Unpaid", "giver": "hesk", "where": "Hesk the Woodcutter, at the Keg", "zone": "thornwood",
	"offer": true,
	"text": "Tollmen. Ride with the war bands, ring a bell, and the whole wood comes running. One of 'em had my brother's axe. They drag the bell-rope behind them when they ride; follow the drag to where they hang it, and look at what they've left. Then put two of 'em down before they ring. Then I'll drink easier.",
	"steps": [
		{"kind": "tracks", "r": 12.0, "label": "The bell-rope's drag",
			"text": "Follow the bell-rope's drag from the glade into the oaks ({n}/{of})",
			"marks": [
				{"at": Vector2(-44.0, 4.0), "text": "A hank of bell-rope in the glade's grass, frayed at both ends. The grass lies flat in a line a hand wide, going south and west."},
				{"at": Vector2(-52.0, 15.0), "text": "The drag again, and a mark where it stopped and something heavy was set down: an iron-shod butt, not a boot-heel."},
				{"at": Vector2(-60.0, 23.0), "text": "A tollman's bell-cord snagged on a root, cut clean. Whoever cut it did not want to be followed by the sound."},
				{"at": Vector2(-67.0, 31.0), "text": "The drag ends at a post with a bell-hook in it. The bell is gone. The post has been notched, and there are things round it worth reading."},
			]},
		{"kind": "clues", "at": Vector2(-70.0, 34.0), "r": 10.0, "need": 2, "label": "The bell-post",
			"text": "Read the signs round the tollmen's bell-post ({n}/{of} read)",
			"clues": [
				{"key": "haft", "at": Vector2(-71.0, 35.5), "prop": "mark", "name": "a split haft", "verb": "Look at",
					"text": "An axe-haft end, split, left standing in the ground like a stake. The butt is burned with a mark you know: Hesk's family's. The head has been taken off it."},
				{"key": "bite", "at": Vector2(-68.5, 36.2), "name": "an oak's bark", "verb": "Look at",
					"text": "A bite in an oak at head height. An axe, swung once at the tree and once, a hand's breadth lower, at a man. The bark is brown with it."},
				{"key": "hook", "at": Vector2(-72.2, 32.6), "name": "a tollman's belt-hook", "verb": "Look at",
					"text": "A belt-hook with a thread of grey wool still caught in it. The bell hung here, and the axe hung by the bell. They kept it sharp. They did not know whose it was."},
			]},
		{"kind": "slay", "of": 2, "kinds": ["tollman"], "region": "thornwood,henge", "label": "Tollmen", "at": Vector2(-92.0, -30.0),
			"text": "Put down tollmen riding with the war bands ({n}/{of})"},
		{"kind": "find", "text": "Take the brother's axe-head from the bell-post"},
		{"kind": "turnin", "who": "hesk", "text": "Tell Hesk the tolls are unpaid"},
	],
	"alt": {"hild": {4: "Tell Hesk the axe is at Hild's forge"}, "cairn": {4: "Tell Hesk the axe lies on his brother's cairn"}},
	"reward": {"ash": 12},
	"choose": [{"slot": "girdle", "rarity": 1}, {"slot": "focus", "rarity": 1}],
	"leaves": {"cairn": {"at": Vector2(-62.0, 29.5), "prop": "cairn"}},
	"outcome": {"hild": "Hesk drank to his brother, twice. The second was for the axe, which Hild has reground, bright on both sides now.",
		"cairn": "Hesk drank to his brother, twice. The second was for the cairn, and the axe lying on it, and the stone somebody left beside it that was not his.",
		"": "Hesk drank to his brother, twice. The second was for the axe."}}

const BEAD_COUNT := {"name": "The Lay Brothers' Beads", "giver": "abel", "where": "Abel the sexton, by the Kindlers' Yard", "zone": "fen",
	"offer": true, "avail": "met:abel",
	"text": "The bone-walkers in the fen are the lay brothers, still counting. They carry their tally-beads on them. Bring me the beads and the count stops. Then read the Tally posts down the fen descent against them: the Abbot's number is wrong, and I want to know by how much. I'll lay the beads flat. Them too.",
	"steps": [
		{"kind": "collect", "of": 4, "chance": 0.75, "kinds": ["ossuant"], "region": "fen,barrows", "label": "Tally-beads", "at": Vector2(96.0, -30.0),
			"text": "Take tally-beads from the bone-walkers of the fen and the Barrow Field ({n}/{of})"},
		{"kind": "clues", "at": Vector2(68.0, -49.0), "r": 22.0, "need": 2, "label": "The Tally posts",
			"text": "Read the Tally against your beads: the posts down the fen descent, the board by the Landing fire ({n}/{of} read)",
			"clues": [
				{"key": "p3", "at": Vector2(64.5, -51.0), "name": "a Tally post", "verb": "Read",
					"text": "TALLY POST. 1,041, in a clerk's even hand. Under it, in a shakier one: the faithful are gathering. The bead in your hand is numbered 1,041. It is the same bead."},
				{"key": "p4", "at": Vector2(57.5, -56.5), "name": "the last Tally post", "verb": "Read",
					"text": "BROTHER LISLE WENT DOWN TO COUNT. ADD HIM. Under it the figure: ONE THOUSAND AND NINETY. The ADD HIM is in the Abbot's hand. It is a glad hand."},
				{"key": "board", "at": Vector2(81.0, -38.5), "prop": "page", "name": "the lay brothers' board", "verb": "Read",
					"text": "A slate board by the Landing fire, kept in two columns. The first ends at 1,089. In the second, one line, in Lisle's hand, not a number: I counted twice. It went up and I did not touch it. If I am the ninetieth, I did not go down willing."},
			]},
		{"kind": "find", "text": "Judge the Tally: is Brother Lisle one of the count?"},
		{"kind": "turnin", "who": "abel", "text": "Bring the tally-beads to Abel"},
	],
	"alt": {"add": {3: "Bring the beads to Abel: Lisle is counted, 1,090"}, "strike": {3: "Bring the beads to Abel: Lisle struck, 1,089"},
		"stand": {3: "Bring the beads to Abel: the count as written"}},
	"reward": {"ash": 12},
	"choose": [{"set": "tally", "slot": "vestment", "rarity": 1}, {"set": "tally", "slot": "girdle", "rarity": 1}, {"set": "tally", "slot": "lantern", "rarity": 1}],
	"leaves": {"add": {"at": Vector2(-79.0, 48.0), "prop": "slabs"}, "strike": {"at": Vector2(57.0, -55.0), "prop": "page"}},
	"outcome": {"add": "Abel buried the beads loose, so nobody can count them again, and cut one more name in the Yard under the three: Lisle's, who went down to count and was counted.",
		"strike": "Abel buried the beads loose, so nobody can count them again, and struck Lisle from the Tally on the post. 1,089. The Abbot's number is wrong, and the post says so now.",
		"stand": "Abel buried the beads loose, so nobody can count them again. He left the Tally as it was written. \"Not my sum,\" he said, and went on digging.",
		"": "Abel buried the beads loose, so nobody can count them again."}}

const THREE_KNOCKS := {"name": "Three Knocks", "giver": "nan", "where": "Nan Wright, who chalks Old Maud's step", "zone": "hearth",
	"offer": true, "avail": "met:nan",
	"text": "Maud's candle is in her window every night, for Hobb, in case he looks down. Every night something knocks on her door. Three, slow, the way he did. She doesn't open. I chalk the step, but I'm not let stay. She writes him letters and never sends them: they're under her sill, on the bean-garden gate, on the chopping block at the back. Read them. Then sit up at her door, because somebody should be there who isn't her.",
	"steps": [
		{"kind": "clues", "at": Vector2(-19.0, 43.0), "r": 14.0, "label": "Maud's letters",
			"text": "Read the letters Maud wrote her son and never sent: her sill, the bean-garden gate, the back door ({n}/{of} read)",
			"clues": [
				{"key": "sill", "at": Vector2(-12.8, 42.0), "prop": "page", "name": "a letter on the sill", "verb": "Read",
					"text": "TO HOBB. The candle's lit. I trim it myself; I don't trust the wind. If you look down from wherever you are, it's the one with the lit window. You know which. The road's grown over and I haven't the legs to clear it. Your father would say come home. I'll say eat first."},
				{"key": "gate", "at": Vector2(-28.0, 46.6), "prop": "page", "name": "a letter on the gate-post", "verb": "Read",
					"text": "TO HOBB. The beans came up. They're yours; you planted them the spring before the Night, crooked, and I've not straightened a row. The Ashby girl asked to sit in the garden. I let her. She looks like she's waiting for someone too."},
				{"key": "block", "at": Vector2(-21.4, 44.6), "prop": "page", "name": "a letter on the chopping block", "verb": "Read",
					"text": "TO HOBB. Last night it knocked. Three, slow, the way you did, with the flat of your hand, because you never would use the knocker. I stood with my hand on the bar. If it is you, say my name first. If it doesn't say my name I won't lift it. Don't be angry. I'm an old woman and I know what comes down."},
			]},
		{"kind": "vigil", "at": Vector2(-12.0, 40.4), "r": 8.0, "time": 80.0, "gloom": 0.7, "label": "Maud's door", "noun": "door",
			"waves": [{"at": 16.0, "kinds": ["wretch"], "n": 1, "say": "A knock. Slow. The flat of a hand."},
				{"at": 38.0, "kinds": ["wretch"], "n": 2, "say": "Two. The candle in the window leans toward the door."},
				{"at": 60.0, "kinds": ["wretch", "crawler"], "n": 2, "say": "Three. The chalk on the step holds, for a breath."}],
			"held": "The knocking stops. On the other side of the door, something stands and waits to be answered.",
			"away": "Go back to Maud's door. It wants somebody sitting at it.",
			"text": "Sit up at Maud's door through the night; something will knock three times ({t} s)"},
		{"kind": "find", "text": "Answer the door, or don't"},
		{"kind": "turnin", "who": "nan", "text": "Tell Nan what you did at Maud's door"},
	],
	"alt": {"open": {3: "Tell Nan the door is open"}, "shut": {3: "Tell Nan the bar stayed down"}, "answer": {3: "Tell Nan you answered in Maud's voice"}, "gone": {3: "Tell Nan nothing knocked"}},
	"reward": {"ash": 14, "items": {"ember_shard": 1}},
	"choose": [{"slot": "lantern", "rarity": 1}, {"slot": "vestment", "rarity": 1}],
	"leaves": {"open": {"at": Vector2(-12.4, 41.4), "prop": "slabs"}, "shut": {"at": Vector2(-12.4, 41.4), "prop": "lantern"}, "answer": {"at": Vector2(-12.4, 41.4), "prop": "lantern_lit"}},
	"outcome": {"open": "Maud lifted the bar. Hobb came in and sat down by her fire like a cold dog, coat over his face, and she covered his shoulders, and nobody at the Keg has asked since. He will lie down when the door is shut.",
		"gone": "Nan chalked the step in the morning and nothing rubbed it out. \"It stopped,\" she said. \"Somebody stopped it. Maud sat up all night anyway.\"",
		"shut": "The bar stayed down. The knocking stops at dawn and comes back at dusk. Maud says the candle is for him, and the bar is for what he is.",
		"answer": "Maud's voice went through the door and the knocking stopped halfway into the third. Something on the step said her name, wrongly, and then rightly, and went away down the east road."}}

const FORTY_DAYS := {"name": "Forty Days Late", "giver": "wyck", "where": "Wyck, at his fire in the Thornwood", "zone": "thornwood",
	"offer": true, "avail": "met:wyck",
	"text": "They came late. Forty days after the Night, the Ninth Company, pilgrims with their staves and their tokens, walking the rim to a Stair that wasn't there. They camped in my wood. I took them bread. Mother Seren drew a ring and they stood in it and burned their tokens, so as not to go hollow. I buried the one who didn't wake. Go and see what's left. They notched a stake for every day they were late; follow the stakes. Don't touch what's burned. There was one I did not see burn.",
	"steps": [
		{"kind": "tracks", "r": 12.0, "label": "The Ninth Company's stakes",
			"text": "Follow the Ninth Company's notched stakes north from the Shrine of the Lost ({n}/{of})",
			"marks": [
				{"at": Vector2(-42.0, 3.0), "text": "A stake driven in beside the glade's way, a strip of grey ribbon on it. Thirty-six notches, cut with a knife, each one a day. The thirty-seventh is begun and not finished."},
				{"at": Vector2(-40.0, -12.0), "text": "Another stake. Thirty-eight. A pilgrim's token has been pressed into the wood beside the notches, face out, as a pilgrim shows a gate."},
				{"at": Vector2(-34.0, -24.0), "text": "Thirty-nine. The ribbon on this one is torn off short and knotted, as for a child's wrist."},
				{"at": Vector2(-38.0, -34.0), "text": "Forty. The last stake, and no more. Past it the trees have been cleared round a ring of fire-stones. Whoever stopped counting stopped here."},
			]},
		{"kind": "clues", "at": Vector2(-46.0, -38.0), "r": 12.0, "need": 3, "label": "The Ninth Company's camp",
			"text": "Search the Ninth Company's camp for what they burned, and what they did not ({n}/{of} read)",
			"clues": [
				{"key": "seren", "at": Vector2(-47.0, -38.0), "prop": "mark", "name": "a flattened token", "verb": "Look at",
					"text": "A tin Open Door on a cord, hammered flat on the fire-stones, slowly, all the way round. A letter S is scratched on the back with a nail. Mother Seren's."},
				{"key": "aldo", "at": Vector2(-43.5, -36.0), "name": "ash in the ring", "verb": "Look at",
					"text": "Ash, and in the ash a ring of black where a cord burned. This one was Brother Aldo's. They put it in the fire for him, because he could not."},
				{"key": "child", "at": Vector2(-49.0, -40.5), "name": "a small burnt token", "verb": "Look at",
					"text": "A very small token, burned black. Somebody scratched a name on the back and did not finish it. The scratch stops at the third letter."},
				{"key": "whole", "at": Vector2(-44.0, -41.0), "name": "a whole token", "verb": "Look at",
					"text": "A tin Open Door on a cord hung on a lean-to pole, not burned, not flattened. The face is worn smooth by a thumb. Whoever hung it here did not mean it to be found, or did not mean it to be left."},
			]},
		{"kind": "find", "text": "Lay the Ninth Company to rest at Aldo's root, and decide the whole token"},
		{"kind": "turnin", "who": "wyck", "text": "Tell Wyck what the Ninth Company left"},
	],
	"alt": {"buried": {3: "Tell Wyck the Ninth Company is buried with Aldo"}, "carried": {3: "Tell Wyck you are carrying the whole token"}},
	"reward": {"ash": 20, "items": {"relic_fragment": 1}},
	"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
	"leaves": {"buried": {"at": Vector2(-56.8, -52.0), "prop": "cairn"}},
	"outcome": {"buried": "Wyck cut a bird's burial for the Ninth Company, face down, and said they had all gone home by way of the wood. He did not say it was true.",
		"carried": "Wyck turned the whole token over once and gave it back. \"They burned the rest so as not to go hollow. This one wouldn't burn, or wasn't let. Take it up or don't. Don't tell me which.\""}}

## The pickups these tasks want (quest_chains.gd PICKUPS lists them). `conv` ones open a conversation (dialogue_db.gd) whose choice moves the task on.
const PICKUPS := {
	"yard_cut": {"quest": "names_yard", "step": 2, "near": Vector2(-80.4, 42.6), "kind": "slabs", "name": "the Yard's wall", "verb": "Cut the names into", "conv": "yard_cut",
		"say": "The chisel lies on the wall's sill, and the three slates beside it."},
	"oswin_flame": {"quest": "forty_first", "step": 2, "near": Vector2(-1.6, 35.4), "kind": "lantern_lit", "name": "a lamp at the green's fire", "verb": "Light",
		"say": "You hold the wick to the green's fire until it takes. A small flame, leaning. Walk it."},
	"heart_thorn": {"quest": "ring_heart", "step": 3, "near": Vector2(-70.0, -18.0), "kind": "thorn", "name": "a thorn of the Heart", "verb": "Take", "conv": "heart_whose",
		"say": "A thorn, long as a finger, still warm."},
	"toll_axe": {"quest": "unpaid_toll", "step": 3, "near": Vector2(-70.4, 33.8), "kind": "clapper", "name": "the brother's axe-head", "verb": "Take", "conv": "toll_axe",
		"say": "An axe-head on a hook, bright on one side."},
	"tally_post": {"quest": "bead_count", "step": 2, "near": Vector2(58.5, -55.4), "kind": "slate", "name": "the Tally post", "verb": "Judge", "conv": "tally_judge",
		"say": "The last Tally post. Brother Lisle's name is the last line on it."},
	"maud_door": {"quest": "three_knocks", "step": 2, "near": Vector2(-13.2, 40.8), "kind": "page", "name": "Maud's door", "verb": "Answer", "conv": "maud_door",
		"say": "The bar is down. Something breathes on the other side."},
	"ninth_grave": {"quest": "forty_days", "step": 2, "near": Vector2(-55.4, -52.4), "kind": "mark", "name": "Aldo's root", "verb": "Kneel at", "conv": "ninth_token",
		"say": "A long mound under an oak's root, a name cut in the wood: ALDO OF THE NINTH."},
}

const QUESTS := {"names_yard": NAMES_YARD, "forty_first": FORTY_FIRST, "ring_heart": RING_HEART, "unpaid_toll": UNPAID_TOLL,
	"bead_count": BEAD_COUNT, "three_knocks": THREE_KNOCKS, "forty_days": FORTY_DAYS}
## the two new tasks, appended to the ledger's order
const ORDER := ["three_knocks", "forty_days"]
