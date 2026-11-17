extends RefCounted
## The West Reach's tasks (docs/far_reaches.md "The Reaches' tasks"; data only, no class_name; quest_chains.gd lists each in the
## blocks marked `# --- the reaches ---`). Reedholm's people give and close them; they carry the wanderer along the Reach's length
## (the Reedmere, the Kings' Barrows, the Lanternwood, the Greyfell). Existing step kinds only; every step names a place.
##   wr_stand_down    Stand Down (Aud Corle)             MAIN: the Order's last order, found in the mere, carried north to the fell shrine
##   wr_kings_lamp    A Lamp for the Kings' Door (Siany)  the lamp book's first lamp carried up the barrow road to the open door
##                                                        (the dungeon hook: HOOKS.kings_barrow)
##   wr_cold_light    Cold Light (Ebba Sallow)           Wick, the lamp-grown, in the ring of giant caps; caps for the punts
##   wr_fourth_stone  The Fourth Stone (Hodge Wade)        the herons touched in the verse's order (order), the fourth bird waited for (vigil),
##                                                        the Heron-Wife; the oar laid on Tam's stone or given to Hodge
##   wr_relief        Relief (Aud Corle)                 quest_chains_deepen_c.gd: the Sentry's watch at the Signal Cairn, after Stand Down
##   wr_tansys_boat   Tansy's Boat (Ebba Sallow)         FOUND at the Last Milestone's toll-house: the ledger's last line
## `found_at` tasks start when the wanderer comes within `found_r` (quest_world.gd). House style: terse, concrete, dark.

const ZONE := ["westreach", "The West Reach"]

## Where a thread ends at a dungeon's entrance (the boss dungeons are another lane's): `cond` is a QuestDB term true once the
## wanderer has reached that step (it stays true after), `done` once the task is handed in; `at` / `r` is the door's neighbourhood
## (the dungeon's own entrance replaces it; the quest's `visit`/`place` target follows these numbers).
const HOOKS := {
	"kings_barrow": {"quest": "wr_kings_lamp", "step": 2, "at": Vector2(-345.0, 167.0), "r": 14.0, "cond": "q:wr_kings_lamp:2", "done": "qd:wr_kings_lamp"},
}

const QUESTS := {
	"wr_stand_down": {"name": "Stand Down", "giver": "corle", "zone": "westreach", "offer": true,
		"where": "Aud Corle, on the net-hall's gallery in Reedholm",
		"text": "Nine winters ago the Order's last courier came down to the ford with a sealed order for the garrison at the Greyfell, and the lamp book has a line for him: one rider, not home. Hodge's traps have dragged his satchel up out of the heron stones' reeds. Aud has not broken the seal. Seals are the Order's business, she says, and delivery is Reedholm's. She wants the order carried the length of the Reach, to whoever is still keeping the watch.",
		"steps": [
			{"kind": "find", "text": "Take the courier's satchel from the reeds by the heron stones, in the south mere"},
			{"kind": "visit", "at": Vector2(-330.0, -8.0), "r": 16.0, "label": "The ring of giant caps",
				"text": "Take the courier's route slip north, through the Lanternwood, to the ring of giant caps"},
			{"kind": "slay", "of": 1, "rares": ["keep_sentry"], "at": Vector2(-284.0, -116.0), "label": "The Sentry Who Was Never Relieved",
				"text": "Put down the Sentry Who Was Never Relieved, at the fell shrine under the Broken Keep"},
			{"kind": "place", "text": "Deal with the order at the fell shrine's stone"},
			{"kind": "turnin", "who": "corle", "text": "Tell Aud Corle what became of the order"},
		],
		"alt": {"read": {4: "Tell Aud Corle what the order said"}, "burned": {4: "Tell Aud Corle the order is ash"}, "sealed": {4: "Tell Aud Corle the order is left sealed"}},
		"reward": {"ash": 40, "items": {"relic_fragment": 2, "ember_shard": 1}},
		"choose": [{"set": "ferryman", "slot": "lantern", "rarity": 3}, {"set": "ferryman", "slot": "vestment", "rarity": 3}, {"set": "ferryman", "slot": "girdle", "rarity": 3}],
		"leaves": {"read": {"at": Vector2(-280.0, -117.0), "prop": "lantern_lit"}, "burned": {"at": Vector2(-280.0, -117.0), "prop": "coal"}, "sealed": {"at": Vector2(-280.0, -117.0), "prop": "page"}},
		"outcome": {
			"read": "You read it at the shrine's foot, to the keep above and the fell below, and the wind dropped as it does for any order. Aud made you say it twice at her gallery rail: THE ASCENSION IS ACCOMPLISHED. THE WATCH IS ENDED. COME EAST AND BE COUNTED. 'They would have gone,' she said. 'Every one. Nobody ever got it, so they stood, and they are the only garrison in the valley that is still anything.' She wrote DELIVERED in the lamp book, crossed it out, and wrote it again.",
			"burned": "You gave the order to the fire unread. Aud asked what it had said, and you told her you did not know. She looked at you a long while over the lamp book. 'Good,' she said. 'Then it was never delivered, and nobody walked east.' She wrote the courier's line over in her own hand: not home, and not blamed.",
			"sealed": "You left the order on the shrine's stone with the wax whole. 'For whoever stands the next watch,' Aud said, and nodded, as though that were an answer. 'The Order's business. Let it stay the Order's.' She wrote in the lamp book: the Greyfell is kept.",
			"": "Aud wrote one line in the lamp book, and shut it."}},
	"wr_kings_lamp": {"name": "A Lamp for the Kings' Door", "giver": "siany", "zone": "westreach", "offer": true,
		"where": "Siany, at the jetty's lamps in Reedholm",
		"text": "The first pages of Aud's lamp book are older than the Order's tithe, and they do not count boats. They count the lamps the mere-folk carried up the barrow road to the kings' ridge, one each dusk, for the door that stands open. The Order took the duty from the fishers, and the Night took the Order, and nobody has carried a lamp since. Siany lights thirty at the jetty. She has always wondered who lit the one the book never numbers.",
		"steps": [
			{"kind": "find", "text": "Take the oldest lamp from the jetty's end, the one the book calls the king's"},
			{"kind": "carry", "from": "wr_king_lamp", "to": Vector2(-345.0, 167.0), "r": 10.0, "time": 120.0, "label": "The king's lamp",
				"lost": "The lamp gutters on the barrow road and goes out. Siany's jetty has another.",
				"text": "Carry the lamp up the barrow road to the King's Barrow's open door before it burns down ({t} s)"},
			{"kind": "place", "text": "Set the lamp on the open door's threshold"},
			{"kind": "turnin", "who": "siany", "text": "Tell Siany the king's door has its lamp"},
		],
		"reward": {"ash": 26, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"stands": {"at": Vector2(-345.0, 166.0), "kind": "lantern_lit"},
		"outcome": {"": "Siany heard it out with her hands round the jetty's thirtieth lamp. 'The door has no latch,' you said, 'and no hinge. The stone was rolled from inside.' She did not say anything for a while. Then she lit one more, unnumbered, at the jetty's end, where the book says the king's lamp always stood, and it burned no differently from the others. She set it apart from them, all the same, and every dusk since she has lit that one first."}},
	"wr_cold_light": {"name": "Cold Light", "giver": "ebba", "zone": "westreach", "offer": true,
		"where": "Ebba Sallow, at the punt slip in Reedholm",
		"text": "Reedholm burns reed-oil, and the meres have stopped giving it. Ebba has heard what the Lanternwood grows instead: caps that glow a cold steady blue and want nothing but the dark. A punt with one in its bow would be seen from the far bank and would never need filling. Wick walks the ring where they grow, a thing that has been feeding on them nine winters, and it does not share.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["lamp_wick"], "at": Vector2(-330.0, -6.0), "label": "Wick, the Lamp-Grown",
				"text": "Put down Wick, the Lamp-Grown, on its round of the ring of giant caps"},
			{"kind": "gather", "of": 3, "text": "Cut three cold caps from the lesser growth round the ring ({n}/{of})"},
			{"kind": "place", "text": "Hang the caps in the bow of Ebba's punt at the slip in Reedholm"},
			{"kind": "turnin", "who": "ebba", "text": "Tell Ebba the caps are hung"},
		],
		"reward": {"ash": 24, "items": {"ember_shard": 2}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}],
		"stands": {"at": Vector2(-319.5, 268.5), "kind": "lantern_lit"},
		"outcome": {"": "Ebba hung a cap in the bow of each of her three punts, and by midnight the slip was lit the colour of deep water. They cast no shadow, which Siany says is the only wrong thing about them. 'They don't light anything,' Ebba said. 'That is the point of them. A boat should be seen from other boats and from nowhere else.' The punts have not looked back at her from the black water since, and for a warm minute she believed it was the caps."}},
	"wr_fourth_stone": {"name": "The Fourth Stone", "giver": "hobb", "zone": "westreach", "offer": true,
		"where": "Hodge Wade, at the long house in Reedholm",
		"text": "Aud says her three boats went the night the fourth heron stone was bare. Hodge says it was the same stone and the same bird gone when his brother Tam rowed out. The seven stones in the south mere have a heron cut on each, a different thing in each beak, and a verse round the lowest slab's foot that nobody in Reedholm has read aloud in a hundred years: THE OAR FOLLOWS THE LAMP. THE LAMP FOLLOWS THE NET. THE NET FOLLOWS THE EEL. TOUCH THEM AS THEY FOLLOW, AND THE FOURTH WILL KNOW YOU. Hodge wants it read at the stones, the herons touched in the order it gives, and the fourth bird waited for.",
		"steps": [
			{"kind": "visit", "at": Vector2(-340.0, 360.0), "r": 12.0, "label": "The heron stones", "text": "Go out to the heron stones in the south mere and read the verse at the lowest slab"},
			{"kind": "order", "at": Vector2(-337.0, 356.0), "label": "The herons",
				"text": "Touch the four herons in the order the verse gave: first the eel's, then whatever follows it, down to the oar",
				"things": [
					{"key": "eel", "at": Vector2(-341.5, 352.0), "prop": "mark", "name": "the eel's heron", "text": "The eel's heron is cold and wet under your palm, and the ring of water round its stone goes still."},
					{"key": "net", "at": Vector2(-333.0, 351.0), "prop": "mark", "name": "the net's heron", "text": "The net's heron. A breath of reed-smoke from nowhere, and the smell of tar."},
					{"key": "lamp", "at": Vector2(-331.0, 359.5), "prop": "mark", "name": "the lamp's heron", "text": "The lamp's heron. For a moment the lamp in its beak is lit, and the stone beside it has a shadow it did not have."},
					{"key": "oar", "at": Vector2(-340.5, 361.0), "prop": "mark", "name": "the oar's heron", "text": "The oar's heron. The fourth stone, the bare one, is not bare: for the length of a breath there is a heron on it, grey as the water, with an oar across its beak."},
				],
				"order": ["eel", "net", "lamp", "oar"],
				"wrong": "Nothing answers. The heron under your hand turns its head away, the ring goes quiet, and the others turn away one by one. You will have to begin from the verse.",
				"wrong_spawns": {"kind": "wretch", "n": 1},
				"done": "Eel, net, lamp, oar. The ring holds its breath."},
			{"kind": "vigil", "at": Vector2(-337.0, 357.0), "r": 9.0, "time": 40.0, "gloom": 0.5, "label": "The fourth bird", "noun": "stone", "prop": "mark",
				"waves": [{"at": 14.0, "kinds": ["wretch"], "n": 2, "say": "The reeds move against the wind, as if something were stepping out of them."},
					{"at": 28.0, "kinds": ["crawler"], "n": 1, "say": "Something long comes down the channel between the stones."}],
				"held": "The fourth stone has its bird, for the length of a breath. Something in the south reeds lets out a long breath, and begins to walk.", "away": "Go back to the stones. The fourth bird comes to whoever waits.",
				"text": "Wait at the stones for the fourth bird, and keep what the waiting wakes off the ring ({t} s)"},
			{"kind": "slay", "of": 1, "rares": ["heron_wife"], "at": Vector2(-300.0, 372.0), "label": "The Heron-Wife",
				"text": "Put down the Heron-Wife, who left the fourth stone and walks the south reeds"},
			{"kind": "place", "text": "Lay the fourth heron's oar where it belongs: on Tam's stone, or in Hodge's hands"},
			{"kind": "turnin", "who": "hobb", "text": "Tell Hodge the fourth heron is back on its stone"},
		],
		"alt": {"tam": {5: "Tell Hodge the oar is on Tam's stone"}, "hobb": {5: "Bring Hodge the fourth heron's oar"}},
		"reward": {"ash": 24, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "girdle", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"leaves": {"tam": {"at": Vector2(-338.0, 358.5), "prop": "staff"}},
		"outcome": {
			"tam": "The fourth stone had its bird back by morning, grey as the water, and an oar across the stone beside it that was not the bird's. Hodge rowed out to see, and came back, and said that Tam was not in it. 'He's in the book,' he said. 'That is enough. I only wanted to know it was not the bird that took him.' It had been, and he knew. The oar on the stone is for Tam. Hodge says he won't touch it, and rows round it.",
			"hobb": "The fourth stone had its bird back by morning, grey as the water. You put the oar in Hodge's hands, and he stood with it a long time in the long house's door. 'It is not Tam's,' he said. 'It is the bird's. He would have said that was the whole joke.' He rowed out that night to put it back on the stone himself, and rowed back with only the one.",
			"": "The fourth stone had its bird back by morning, grey as the water, an oar across its beak. Hodge rowed out to see, and came back, and said that Tam was not in it. 'He's in the book,' he said. 'That is enough.'"}},
	"wr_tansys_boat": {"name": "Tansy's Boat", "giver": "ebba", "zone": "westreach", "offer": true,
		"where": "a toll-house at the Last Milestone",
		"found_at": Vector2(-350.0, 38.0), "found_r": 9.0, "found_prop": "slate",
		"found_say": "The toll-house at the road's end stands open, its table laid with a ledger under a pewter cup. The last line looks wet, though nothing has been wet in here for nine winters.",
		"text": "The toll-keeper at the Last Milestone counted every pilgrim who passed east, by name and homeland, and his ledger still lies on his table. Ebba Sallow built a punt for a woman called Tansy the autumn before the Night, and has kept it oiled under the net-hall every spring since. The woman never came for it. The ledger may say why.",
		"steps": [
			{"kind": "find", "text": "Read the last page of the toll-keeper's ledger"},
			{"kind": "place", "text": "Cut Alma Tansy's name in the bow of her boat, at Ebba's slip in Reedholm"},
			{"kind": "turnin", "who": "ebba", "text": "Tell Ebba whose boat it is"},
		],
		"reward": {"ash": 22, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "vestment", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
		"outcome": {"": "Ebba read the page twice and put her thumb on the line. 'East,' she said. 'The day before. She left it paid for and went to be counted.' She set the boat in the mere that night, on its own, with the lamp lit and nobody in it, and let it go as far as the first reed bed. Ansel Tansy will have it from the next carter, she says. Some news is best carried by someone who is going the right way anyway."}},
}

const PICKUPS := {
	"wr_satchel": {"quest": "wr_stand_down", "step": 0, "near": Vector2(-331.0, 346.0), "kind": "page", "name": "the courier's satchel", "verb": "Take",
		"say": "A satchel of the Order's black leather, the strap eaten through and the flap sealed with wax the water never reached. COURIER. WEST. BY HAND. Inside, folded small, the order, and a slip in another hand with the route on it: BY THE LANTERN RING, NOT THE WOOD'S EDGE. THE EDGE IS HUNTED."},
	"wr_shrine": {"quest": "wr_stand_down", "step": 3, "near": Vector2(-280.0, -118.5), "kind": "place", "name": "the fell shrine", "verb": "Set the order at", "conv": "wr_order",
		"say": "The fell shrine."},
	"wr_king_lamp": {"quest": "wr_kings_lamp", "step": 0, "near": Vector2(-322.5, 304.5), "kind": "lantern_lit", "name": "the king's lamp", "verb": "Take",
		"say": "A hooded boat-lamp of the old pattern, a heron cut in the tin of the hood and a nick in the foot where it was set down on the same threshold for three hundred years. The wick is new. Siany trimmed it this morning, and does not say why."},
	"wr_king_door": {"quest": "wr_kings_lamp", "step": 2, "near": Vector2(-345.0, 166.0), "kind": "place", "name": "the open door", "verb": "Set the lamp on",
		"say": "You set the lamp on the threshold, hood to the road, where three hundred years of lamps stood. The flame leans in, once, and then stands straight. The door has no latch and no hinge, and the stone that shut it lies rolled to one side with its marks on the inside face. The lamp shows the first ten feet of the passage. After that, the dark is listening."},
	"wr_cap_a": {"quest": "wr_cold_light", "step": 1, "near": Vector2(-338.0, -1.0), "kind": "bud", "name": "a cold cap", "verb": "Cut",
		"say": "A cap no bigger than a plate on a stalk of wet grey flesh, glowing a flat steady blue. It is cold as a coin and it does not flicker. When you cut it the light stays in your hand."},
	"wr_cap_b": {"quest": "wr_cold_light", "step": 1, "near": Vector2(-317.0, -6.0), "kind": "bud", "name": "a cold cap", "verb": "Cut",
		"say": "A cap among the roots of a giant, pale as a drowned face. The glow runs up the stalk as you cut it, as if trying to get back into the ground."},
	"wr_cap_c": {"quest": "wr_cold_light", "step": 1, "near": Vector2(-334.0, 6.0), "kind": "bud", "name": "a cold cap", "verb": "Cut",
		"say": "The smallest of the three, hardly a thumbnail across, and the brightest. It lit the moss round it for a yard on every side, and it is the only one that is warm."},
	"wr_cap_punt": {"quest": "wr_cold_light", "step": 2, "near": Vector2(-318.0, 267.5), "kind": "place", "name": "the punt's bow", "verb": "Hang the caps in",
		"say": "You push a cap into the cleat in the bow, and the slip comes up blue around it, wet planks and coiled rope and Ebba's hands, and nothing else. The water under the punt is for the first time in nine winters only water."},
	"wr_stones": {"quest": "wr_fourth_stone", "step": 4, "near": Vector2(-337.0, 358.5), "kind": "place", "name": "the fourth stone's oar", "verb": "Take up", "conv": "wr_herons",
		"say": "The fourth stone's oar."},
	"wr_ledger": {"quest": "wr_tansys_boat", "step": 0, "near": Vector2(-350.0, 37.0), "kind": "page", "name": "the toll-keeper's ledger", "verb": "Read",
		"say": "Every pilgrim who passed east is counted by name and homeland, three hundred years of them, the ink fading toward the end of the book. The last entry is the day before the Night: TANSY, ALMA, OF REEDHOLM. ONE. EAST. LEFT HER BOAT PAID FOR AND HER LAMP LIT. Beside it the keeper has drawn a small boat, very carefully, and nothing else."},
	"wr_boat": {"quest": "wr_tansys_boat", "step": 1, "near": Vector2(-313.5, 264.5), "kind": "place", "name": "Alma Tansy's boat", "verb": "Cut her name in",
		"say": "You cut ALMA TANSY into the bow with Ebba's own knife, the first name the boat has ever had. It sits a little lower in the water, as though it had been waiting for the weight."},
}

const CONVS := {
	"wr_order": {"name": "The Fell Shrine", "start": [["qat:wr_relief:3", "relief"], ["!qat:wr_stand_down:3", "gone"], ["", "at"]], "nodes": {
		"relief": {"say": "The Signal Cairn stands over the fell, built and never lit. The Sentry sat down at it at dawn, if sitting is what it was, and is not sitting now. His place by the stack is warm. The watch is yours to end. It is a long walk, from the Order's last word to the one who stood it.", "who": "", "choices": [
			{"text": "Salute the cairn, and stand the watch down.", "to": "salute"},
			{"text": "Keep the watch. The fell is not safe yet.", "to": "keep"},
			{"text": "Not yet.", "to": ""},
		]},
		"salute": {"say": "You put your hand flat to the cairn's capstone, WHEN THE SKY OPENS, BURN, and say it: the watch is ended. Nothing answers. Far below, on the keep's crag, a lamp goes out in a window nobody had known was lit.", "who": "", "do": "qp:wr_relief:salute,qa:wr_relief", "next": ""},
		"keep": {"say": "You take his place by the stack, and his watch with it, the way a man takes up a coat somebody has laid down. The wind finds the collar. Down on the crag a lamp in the keep's window stays lit.", "who": "", "do": "qp:wr_relief:keep,qa:wr_relief", "next": ""},
		"at": {"say": "The fell shrine's stone, under the Broken Keep's crag, and no sentry on it now. You hold the courier's order, the wax still whole, nine winters of water in the grain of the paper.", "who": "", "choices": [
			{"text": "Read it aloud, to the keep and the fell.", "to": "read"},
			{"text": "Burn it unread.", "to": "burned"},
			{"text": "Leave it sealed on the stone.", "to": "sealed"},
			{"text": "Not yet.", "to": ""},
		]},
		"read": {"say": "You break the seal. THE ASCENSION IS ACCOMPLISHED, the clerk's hand says. THE WATCH IS ENDED. STAND DOWN AND COME EAST BY THE ROAD TO BE COUNTED. Nothing on the fell answers, and the wind drops while you read it, as it does for any order.", "who": "", "do": "qp:wr_stand_down:read,qa:wr_stand_down", "next": ""},
		"burned": {"say": "The shrine's old cresset takes the paper at one corner and lets it go all at once. You do not look at what it was. Somewhere on the crag above, a watch is not told.", "who": "", "do": "qp:wr_stand_down:burned,qa:wr_stand_down", "next": ""},
		"sealed": {"say": "You lay it on the stone with the wax to the sky, and put the cresset's cold lamp on it for a weight. Whoever stands the next watch here will find it exactly as the courier left it.", "who": "", "do": "qp:wr_stand_down:sealed,qa:wr_stand_down", "next": ""},
		"gone": {"say": "The fell shrine is quiet. Whatever the order said is finished with.", "who": "", "next": ""},
	}},
	"wr_herons": {"name": "The Heron Stones", "start": [["!qat:wr_fourth_stone:4", "gone"], ["", "oar"]], "nodes": {
		"oar": {"say": "The fourth bird is gone from its stone again, and in the ring's middle, on the black water, an oar floats upright as if it stood on something. A fisher's oar, ash, the blade worn thin. Tam's pattern. Not Tam's. It is yours to lay.", "who": "", "choices": [
			{"text": "Lay it across Tam's stone, for him.", "to": "tam"},
			{"text": "Take it back to Hodge.", "to": "hobb"},
			{"text": "Not yet.", "to": ""},
		]},
		"tam": {"say": "You wade it to the lowest slab and lay it across. The water round it does not move. Somewhere behind you a heron settles its feathers, and a great deal of weight leaves the mere.", "who": "", "do": "qp:wr_fourth_stone:tam,qa:wr_fourth_stone", "next": ""},
		"hobb": {"say": "You lift it out. It is lighter than it should be and warmer than the water. Hodge will know what to do with it. He may not forgive you for bringing it.", "who": "", "do": "qp:wr_fourth_stone:hobb,qa:wr_fourth_stone", "next": ""},
		"gone": {"say_if": [["qp:wr_fourth_stone:tam", "The seven stones stand in their ring. An oar lies across the lowest slab, and the fourth bird stands over it."], ["", "The seven stones stand in their ring. The fourth has its bird, and the others do not look at it."]], "who": "", "next": ""},
	}},
}
