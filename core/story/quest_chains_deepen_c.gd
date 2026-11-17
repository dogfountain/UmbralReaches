extends RefCounted
## The Far Reaches' three signature tasks (docs/QUEST_DEPTH.md workstream C), in the quest_chains.gd manner: one const a task,
## listed by the shared tables' `# --- deepen C ---` blocks. They use the task verbs (docs/QUEST_VERBS.md) and a pick that
## leaves something standing. Their place choices live in the conversations the three Reach files host (wr_order, ds_nail_door,
## er_slate: their start lists branch on the step), so nothing new is registered with dialogue_db.gd.
##
##   wr_relief   Relief (Aud Corle, after Stand Down)           clues at the Signal Cairn, a vigil through the Sentry's watch, then stand it down or keep it
##   ds_charcoal A Night of Charcoal (Reeve Penn, after the Water Road)
##                                                              tracks to Hob's Stack, a vigil at the clamp, a coal walked to the Arches Beacon (lantern_walk);
##                                                              ask the burner's leave or draw the clamp
##   er_rope     The Rope Rung Right (Sister Maudlin, after the Candle)
##                                                              the ringers' rope-marks (clues), the ropes rung bottom to top (order); still the lowest or break the highest
## House style (docs/LORE.md): terse, concrete, dark.

const WR_RELIEF := {"name": "Relief", "giver": "corle", "zone": "westreach", "offer": true, "avail": "qd:wr_stand_down",
	"where": "Aud Corle, on the net-hall's gallery in Reedholm",
	"text": "The Sentry Who Was Never Relieved is down, and Aud will not write the courier's line closed. A watch ends when it is relieved, she says, not when the man on it is put to the sword, and nobody has relieved him. She wants the Signal Cairn on the fell kept the way the Order kept it, a night through, by somebody who is not a ghost, and what is said to the cairn at dawn is said by the one who kept it. She will write his name, if you can find it.",
	"steps": [
		{"kind": "visit", "at": Vector2(-298.0, -72.0), "r": 12.0, "label": "The Signal Cairn", "text": "Climb the Greyfell to the Signal Cairn, by the fell track's head under the Broken Keep"},
		{"kind": "clues", "at": Vector2(-298.0, -72.0), "r": 10.0, "need": 2, "label": "The Sentry's post",
			"text": "Read what the Sentry left at his post ({n}/{of} read)",
			"clues": [
				{"key": "notches", "at": Vector2(-300.0, -74.0), "name": "notches on the cairn", "text": "Notches cut in the cairn's lowest stone, one a dawn, in rows of nine. Three thousand, near enough. The last row is not finished. The knife was put down in the middle of a stroke."},
				{"key": "name", "at": Vector2(-295.5, -70.0), "prop": "mark", "name": "a Muster Stone", "text": "A Muster Stone dragged here from the ring and stood against the cairn. NESS, G., it says, in a clerk's hand, with a Reedholm eel cut beside it. Garrick Ness. Nobody in the book has the name. He was not a courier. He was a fisher's boy, conscripted at the ford."},
				{"key": "capstone", "at": Vector2(-298.0, -75.5), "name": "the capstone", "text": "WHEN THE SKY OPENS, BURN. And under it, scratched with a knife-point, small: IT DID. WE DIDN'T. And under that, newer, in the same hand as the notches: relieve me."},
			]},
		{"kind": "vigil", "at": Vector2(-298.0, -72.0), "r": 8.0, "time": 75.0, "gloom": 0.6, "label": "The Sentry's watch", "noun": "cairn", "prop": "cairn",
			"waves": [{"at": 18.0, "kinds": ["husk"], "n": 2, "say": "The fell sends up what it has kept for the watch's hours."},
				{"at": 38.0, "kinds": ["gaunt", "husk"], "n": 3, "say": "The garrison's dead, come to see who stands in the Sentry's place."},
				{"at": 58.0, "kinds": ["husk"], "n": 2, "say": "Before dawn, always more. The watch is long on purpose."}],
			"held": "The sky greys at the fell's edge. The watch is kept.", "away": "Go back to the cairn. A watch is stood where it was set, and by whoever stands it.",
			"text": "Keep the Sentry's watch at the Signal Cairn until dawn ({t} s)"},
		{"kind": "place", "text": "Say what the watch is at dawn: stand it down, or keep it"},
		{"kind": "turnin", "who": "corle", "text": "Tell Aud Corle how the watch ended"},
	],
	"alt": {"salute": {4: "Tell Aud Corle the watch is stood down"}, "keep": {4: "Tell Aud Corle the watch is kept"}},
	"reward": {"ash": 34, "items": {"relic_fragment": 1, "ember_shard": 1}},
	"choose": [{"set": "tally", "slot": "focus", "rarity": 2}, {"set": "tally", "slot": "vestment", "rarity": 2}, {"set": "tally", "slot": "girdle", "rarity": 2}],
	"leaves": {"salute": {"at": Vector2(-296.5, -72.0), "prop": "lantern"}, "keep": {"at": Vector2(-296.5, -72.0), "prop": "lantern_lit"}},
	"outcome": {
		"salute": "You said it at dawn to the cairn, in your own words, whatever the order had said or had not: the watch is ended. The wind dropped as it does for any order. Aud made you say it twice at her gallery rail. She wrote a name in the book's last pages, the way she writes a boat home, and shut the book on it. 'He sat down,' she said. 'Somebody ought to have said so nine winters ago.' The cold lantern stands at the cairn's foot, set down where he left his.",
		"keep": "You did not say it at dawn. You stood the watch on, and the cairn keeps a small light now that the fell can see from the keep. Aud did not like it, and wrote it down: kept, by another. 'It is not an ending,' she said. 'It is a relief. Somebody will have to come and relieve you, in turn.' She did not close the book. The last page is blank on purpose, and she has begun to trim a pen for it.",
		"": "Aud wrote one line in the lamp book, and shut it."}}

const DS_CHARCOAL := {"name": "A Night of Charcoal", "giver": "penn", "zone": "deepsouth", "offer": true, "avail": "qd:ds_water_road",
	"where": "Reeve Penn, in the tithe barn's porch at Fallowmere",
	"text": "Penn lit the two beacons with brushwood, and brushwood is gone by the second night. The Order fed them charcoal, from a clamp the burners kept going in the Southwood at Hob's Stack, banked, never drawn, a winter's wood cut for a winter that came early. The clamp wants a night's tending and a coal carried, lit, to the Arches Beacon, walked, not run. Penn has heard a man is still at the stack. He has not asked what the man wants for it.",
	"steps": [
		{"kind": "tracks", "r": 10.0, "label": "Hob's cord-marks",
			"text": "Follow the cord-marks off arches_way into the Southwood to Hob's Stack ({n}/{of})",
			"marks": [
				{"at": Vector2(132.0, 300.0), "text": "A cord of wood stacked in the bracken, end-on to the way, a handwidth of moss on the top. Another, a stride beyond. Hob cut for a winter that came early, and stacked them where the cart could reach."},
				{"at": Vector2(126.0, 308.0), "text": "Cart-ruts pressed deep and filled with leaf-mould. No cart has come in nine winters. The grooves are polished at the bottom as if one went on being drawn."},
				{"at": Vector2(120.0, 314.0), "text": "The smell of smoke, thin, under the oaks. A turf-roofed lean-to with a rake in it, and a tally on the post in charcoal: twelve cords cut, eight wanted. The rest is for the year the cart doesn't come."},
				{"at": Vector2(119.0, 321.0), "text": "A long mound of turf, breathing. Hob's clamp, banked and red at its seams, and a man sat against its far side in a soot-black coat who does not look up."},
			]},
		{"kind": "vigil", "at": Vector2(118.0, 322.0), "r": 9.0, "time": 70.0, "gloom": 0.7, "label": "Hob's clamp", "noun": "clamp", "prop": "coal",
			"waves": [{"at": 14.0, "kinds": ["wretch"], "n": 2, "say": "The Southwood smells smoke, and comes to see whose."},
				{"at": 32.0, "kinds": ["gaunt"], "n": 2, "say": "Hunters, out of the holly brakes. They want the warmth, and the one who tends it."},
				{"at": 52.0, "kinds": ["husk", "wretch"], "n": 3, "say": "The clamp's red seams light the oaks. Everything in the wood is looking this way."}],
			"held": "The clamp has burned down to a hard red heart. Dawn is not far.", "away": "Go back to the clamp. A clamp is tended or it goes out.",
			"text": "Tend Hob's clamp through the night: turf the seams, keep the fire in ({t} s)"},
		{"kind": "find", "text": "Take a live coal from the clamp for the Arches Beacon"},
		{"kind": "lantern_walk", "from": "ds_clamp_coals", "to": Vector2(40.0, 249.0), "r": 8.0, "label": "The Arches Beacon",
			"relight": "Draw another coal from the clamp.",
			"arrive": "You lay the coal in the beacon's basket, and the first fire on the scarp answers it. Over the hamlet, the second turns its face this way.",
			"text": "Carry the coal, lit, to the Arches Beacon on the scarp. Walk it: a run, a roll, a blow or deep water puts it out"},
		{"kind": "turnin", "who": "penn", "text": "Tell Reeve Penn the water road is lit"},
	],
	"alt": {"spare": {4: "Tell Reeve Penn the burner keeps the clamp"}, "take": {4: "Tell Reeve Penn the clamp is drawn"}},
	"reward": {"ash": 36, "items": {"relic_fragment": 1, "ember_shard": 2}},
	"choose": [{"set": "kindler", "slot": "lantern", "rarity": 2}, {"set": "kindler", "slot": "focus", "rarity": 2}, {"set": "kindler", "slot": "girdle", "rarity": 2}],
	"leaves": {"spare": {"at": Vector2(121.0, 324.0), "prop": "lantern_lit"}, "take": {"at": Vector2(121.0, 324.0), "prop": "coal"}},
	"outcome": {
		"spare": "The beacon on the scarp burned till dawn on a coal the burner had given, and its answer came over the hamlet, and Penn stood on the barn's loft with his tally-stick and counted them both. The stack still smokes. Somebody feeds the basket at dusk, every dusk, and nobody has seen who. 'He keeps the beacons,' Penn said, and he did not say it as a question.",
			"take": "The beacon on the scarp burned the one night, a great red fire on the Order's last charcoal, and its answer came over the hamlet and stood till dawn. In the morning the basket was ash. The stack at Hob's has not smoked since. 'It was enough for one night,' Penn said. 'A night is a thing I can count.' He wrote it in the roll and did not say what he had counted it against.",
		"": "Penn watched the beacon burn until dawn."}}

const ER_ROPE := {"name": "The Rope Rung Right", "giver": "maudlin", "zone": "eastreach", "offer": true, "avail": "qd:er_ringers_candle",
	"where": "Sister Maudlin, at the pilgrims' shrine in Lastlight",
	"text": "The Order rang its bells from the bottom up, Maudlin says, so the lowest rope spoke first and the highest last, and the Night stopped them the other way about: top first, and the ringers on the bottom ropes were left to ring on alone. Tobin's was the lowest, the seventh. The ropes hang over the black water at the Nave's shore, nine winters frayed, numbered from the top. Ring them right, bottom to top, and he can stop. Ring them wrong, and the Bell-Rope Nun's chanters come up out of the water to ring them for you.",
	"steps": [
		{"kind": "clues", "at": Vector2(299.0, 133.0), "r": 10.0, "need": 2, "label": "The ringers' rope-marks",
			"text": "Read the rope-marks on the posts and gantry at the Nave's shore: whose rope was which ({n}/{of} read)",
			"clues": [
				{"key": "low", "at": Vector2(293.5, 129.0), "name": "the lowest rope's post", "text": "A post worn smooth at a child's height, a boy's, a hand that was always up. Cut deep with a spoon: SEVEN. The ropes were numbered from the top, so the lowest has the largest number. He did not mind being last."},
				{"key": "mid", "at": Vector2(298.0, 132.0), "prop": "mark", "name": "the middle posts", "text": "Two posts, FIVE and THREE, worn the same at their feet. The ringers on these two rang in turn and not together, so the peal would not come down on a single beat. A rule of the Order's: no two ropes at once."},
				{"key": "top", "at": Vector2(305.0, 137.0), "name": "the highest rope's post", "text": "A post with ONE cut in it and nothing worn at all. Nobody rang it from here. It was rung from above, from the top of the Stair, and the Night took it first."},
			]},
		{"kind": "order", "at": Vector2(299.0, 134.0), "label": "The four ropes",
			"text": "Touch the four ropes from the bottom up, as the Order rang them down: the lowest first, and the highest last",
			"things": [
				{"key": "seven", "at": Vector2(293.0, 127.5), "prop": "mark", "name": "the rope marked SEVEN", "verb": "Ring", "text": "The seventh rope takes your weight and hums once, flat, like a held breath. Somewhere out on the water someone rests his hands."},
				{"key": "five", "at": Vector2(297.6, 131.8), "prop": "mark", "name": "the rope marked FIVE", "verb": "Ring", "text": "The fifth rope rings, a hand's breadth higher in the note."},
				{"key": "three", "at": Vector2(302.0, 135.0), "prop": "mark", "name": "the rope marked THREE", "verb": "Ring", "text": "The third rope. The note climbs, and the shore listens, and the water in the Nave begins to still."},
				{"key": "one", "at": Vector2(306.5, 138.5), "prop": "mark", "name": "the rope marked ONE", "verb": "Ring", "text": "The first rope, the highest, rung last for the first time in nine winters. The peal goes up the water and does not come back."},
			],
			"order": ["seven", "five", "three", "one"],
			"wrong": "The rope goes slack in your hand, and the peal comes out of the water wrong, top before bottom, as it did on the Night. The Nun's chanters stand up in the shallows and take up the ropes.",
			"wrong_spawns": {"kind": "chanter", "n": 2},
			"done": "Seven, five, three, one. The peal goes up the water, and the ropes begin to settle."},
		{"kind": "place", "text": "The ropes still hum: still the lowest, or pull the highest once more"},
		{"kind": "turnin", "who": "maudlin", "text": "Tell Sister Maudlin the ropes are rung"},
	],
	"alt": {"low": {3: "Tell Sister Maudlin the lowest rope is stilled"}, "high": {3: "Tell Sister Maudlin the highest rope broke"}},
	"reward": {"ash": 38, "items": {"relic_fragment": 1, "ember_shard": 1}},
	"choose": [{"set": "bell", "slot": "lantern", "rarity": 2}, {"set": "bell", "slot": "focus", "rarity": 2}, {"set": "bell", "slot": "vestment", "rarity": 2}],
	"leaves": {"low": {"at": Vector2(292.0, 92.0), "prop": "lantern_lit"}, "high": {"at": Vector2(299.0, 134.0), "prop": "mark"}},
	"outcome": {
		"low": "You closed your hand on the lowest rope, and the hum went out of the others top to bottom. Maudlin heard it out on her knees and turned, slowly, to face the road. 'He is resting,' she said. 'Rope seven. He would not have been a boy to stop.' In the night a pilgrim came up the east road, a stranger, with a lamp, and knocked at the road gate; Fenn let him in, and Coyle did not ask where he had been, and a lamp stands at the nave road's head where he turned.",
		"high": "You hauled the highest rope down and it parted at the sheave, a great crack over the water, and the ringing stopped at once, all of it. Maudlin said nothing for a long time, on her knees. 'It was never going to be rung again,' she said at last. 'Better broken than waiting.' She did not turn to the road. A stump of rope stands at the shore, the end frayed fresh, and the shore does not hum.",
		"": "Maudlin heard it out on her knees, and turned, slowly, to face the road."}}

const PICKUPS := {
	"wr_relief_post": {"quest": "wr_relief", "step": 3, "near": Vector2(-297.0, -73.0), "kind": "place", "name": "the Signal Cairn's capstone", "verb": "Speak at", "conv": "wr_order",
		"say": "The Signal Cairn's capstone."},
	"ds_clamp_coals": {"quest": "ds_charcoal", "step": 2, "near": Vector2(120.5, 323.0), "kind": "lantern_lit", "name": "Hob's clamp", "verb": "Draw a coal from", "conv": "ds_nail_door",
		"say": "Hob's clamp."},
	"er_rope": {"quest": "er_rope", "step": 2, "near": Vector2(299.0, 134.5), "kind": "place", "name": "the ropes' last hum", "verb": "Take hold of", "conv": "er_slate",
		"say": "The ropes' last hum."},
}
