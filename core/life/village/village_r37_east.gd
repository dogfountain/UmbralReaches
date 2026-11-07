extends RefCounted
## East Marches: the people of Saltmarket (docs/r37_expansion.md). Five of them live round the
## hamlet's fire, its stall, doors and drying shed; the nodes they walk are laid by
## realm_pois_r37_east.gd hamlet() (called from village.gd); this file is their data in the village's
## own shapes, listed in the shared tables' `# --- east ---` blocks:
##   CAST        village_cast.gd CAST (rig, schedule, routines; "camp": they do not flee)
##   CONV        village_talk_db.gd CONV (what they say; NPC voices stay babble)
##   MERCHANTS / GOODS   village_shop.gd (Orrin Vail's stall)
## House style (docs/LORE.md): terse, concrete, dark. Load by path.

const MARL := {"name": "Marl", "title": "Marl Pannick, the salt-reeve", "when": "", "camp": "outpost",
	"rig": {"seed": 6101, "sex": "m", "age": "old", "garment": "coat", "hat": "cap", "hair": "fringe", "beard": "short",
		"r": "staff", "girth": 1.08, "cloth": Color(0.34, 0.33, 0.3), "cloth2": Color(0.4, 0.38, 0.33),
		"hair_c": Color(0.78, 0.76, 0.7), "skin": Color(0.74, 0.55, 0.42), "leather": Color(0.38, 0.25, 0.14)},
	"home": "sm_fire", "speed": 0.8,
	"schedule": {"dusk": "yard", "work": "yard", "midnight": "walk", "late": "yard"},
	"routines": {
		"yard": [
			{"act": "tend", "at": "sm_fire", "face": "@sm_fire", "t": [8.0, 12.0]},
			{"act": "sit", "at": "sm_seat", "face": "@sm_fire", "t": [20.0, 30.0], "seat": 0.36},
		],
		"walk": [{"go": "sm_w1"}, {"act": "idle", "at": "sm_w2", "face": "@out_sm", "t": [6.0, 9.0]}, {"go": "sm_w3"}, {"go": "sm_fire"}],
	}}

const TEASEL := {"name": "Teasel", "title": "Teasel Dray, the brine-wife", "when": "", "camp": "outpost",
	"rig": {"seed": 6202, "sex": "f", "age": "adult", "garment": "dress", "apron": "linen", "hair": "bun", "hood": false,
		"r": "scoop", "girth": 1.0, "cloth": Color(0.42, 0.4, 0.36), "cloth2": Color(0.32, 0.3, 0.27),
		"hair_c": Color(0.3, 0.2, 0.12), "skin": Color(0.78, 0.58, 0.44), "leather": Color(0.36, 0.23, 0.12)},
	"home": "sm_shed", "speed": 0.95,
	"schedule": {"dusk": "rake", "work": "rake", "midnight": "warm", "late": "rake"},
	"routines": {
		"rake": [
			{"act": "sift", "at": "sm_shed", "face": "@sm_shed", "t": [16.0, 24.0]},
			{"act": "idle", "at": "sm_shed", "face": "@out_sm", "t": [6.0, 9.0]},
		],
		"warm": [
			{"act": "warm", "at": "sm_fire", "face": "@sm_fire", "t": [10.0, 14.0]},
			{"act": "sit", "at": "sm_seat", "face": "@sm_fire", "t": [14.0, 22.0], "seat": 0.36},
		],
	}}

const ORRIN := {"name": "Orrin", "title": "Orrin Vail, the salt-trader", "when": "", "trader": true, "camp": "outpost",
	"rig": {"seed": 6303, "sex": "m", "age": "adult", "garment": "coat", "hat": "brim", "hair": "wild", "beard": "short",
		"r": "scoop", "girth": 1.1, "cloth": Color(0.3, 0.3, 0.34), "cloth2": Color(0.42, 0.34, 0.26),
		"hair_c": Color(0.42, 0.3, 0.2), "skin": Color(0.72, 0.52, 0.38), "leather": Color(0.4, 0.26, 0.14)},
	"home": "sm_stall", "speed": 0.9,
	"schedule": {"dusk": "sell", "work": "sell", "midnight": "sell", "late": "sell"},
	"routines": {"sell": [
		{"act": "sell", "at": "sm_stall", "face": "@stall", "t": [20.0, 30.0]},
		{"act": "idle", "at": "sm_stall", "face": "@sm_fire", "t": [8.0, 12.0]},
	]}}

const ARDEL := {"name": "Ardel", "title": "Ardel Wick, the last lamplighter", "when": "", "camp": "outpost",
	"rig": {"seed": 6404, "sex": "m", "age": "old", "garment": "robe", "hood": true, "hair": "long", "beard": "long",
		"r": "staff", "l": "lantern", "girth": 0.94, "cloth": Color(0.22, 0.24, 0.27), "cloth2": Color(0.3, 0.28, 0.25),
		"hair_c": Color(0.82, 0.8, 0.74), "skin": Color(0.76, 0.56, 0.42), "leather": Color(0.34, 0.22, 0.12)},
	"home": "sm_fire", "speed": 0.7,
	"schedule": {"dusk": "camp", "work": "watch", "midnight": "camp", "late": "watch"},
	"routines": {
		"camp": [
			{"act": "warm", "at": "sm_fire", "face": "@sm_fire", "t": [8.0, 12.0]},
			{"act": "sit", "at": "sm_seat", "face": "@sm_fire", "t": [18.0, 26.0], "seat": 0.36},
		],
		"watch": [{"go": "sm_w2"}, {"act": "look_up", "at": "sm_w2", "face": "@spire", "t": [12.0, 18.0]}, {"go": "sm_w1"}, {"go": "sm_fire"}],
	}}

const PIP := {"name": "Pip", "title": "Pip, who hauls", "when": "", "camp": "outpost",
	"rig": {"seed": 6505, "sex": "m", "age": "teen", "garment": "shirt", "hat": "cap", "hair": "wild", "r": "crook",
		"cloth": Color(0.4, 0.34, 0.28), "cloth2": Color(0.3, 0.27, 0.24), "hair_c": Color(0.5, 0.36, 0.2),
		"skin": Color(0.82, 0.62, 0.46), "leather": Color(0.38, 0.25, 0.13)},
	"home": "sm_w3", "speed": 1.15,
	"schedule": {"dusk": "haul", "work": "haul", "midnight": "camp", "late": "haul"},
	"routines": {
		"haul": [{"go": "sm_door_c"}, {"act": "idle", "at": "sm_door_c", "face": "@sm_fire", "t": [6.0, 10.0]}, {"go": "sm_door_b"}, {"act": "idle", "at": "sm_door_b", "face": "@out_sm", "t": [6.0, 10.0]}],
		"camp": [{"act": "sit", "at": "sm_seat", "face": "@sm_fire", "t": [14.0, 22.0], "seat": 0.36}, {"act": "chat", "at": "sm_fire", "face": "@sm_fire", "t": [6.0, 9.0]}],
	}}

# --- what they say --------------------------------------------------------------------------------

const CONV_MARL := {"name": "Marl Pannick", "start": [["!met:marl", "meet"], ["", "hub"]], "nodes": {
	"meet": {"say": "Mind the doorstep. It's salted. So is the stew, the bed and the dog. Salt keeps things where you put them.", "next": "meet2"},
	"meet2": {"say": "Marl Pannick. Reeve here, which means I count the sacks and take the blame. The pans are to the south. Don't walk on the white after dusk without a reason.", "do": "met:marl", "next": "hub"},
	"hub": {"say_if": [
		["qd:salt_widow", "Corra Vane's stone has a companion now. People leave salt on them. It's all we've got to leave."],
		["qd:salt_sweep", "The pans are quiet. First night in a year I could hear the brine settle. It sounds like somebody breathing out."],
		["", "Salt keeps meat and it keeps the hollowed off a threshold. A line across the door. They stop and look at it. Nobody knows why. Nobody asks."],
	], "choices": [
		{"text": "Why a salt hamlet, in the dark?", "to": "why", "once": true},
		{"text": "What's on the Spire?", "to": "spire", "once": true},
		{"text": "Goodbye.", "to": ""},
	]},
	"why": {"say": "The pans don't care about the sky. Sun or no sun, the brine thickens. The Order bought our salt for forty years. They stopped paying the winter the Stair fell. We kept raking.", "next": "hub"},
	"spire": {"say": "The Lamplighters' light. Ardel will tell you, whether you ask or not. Lit every night of my childhood. You could see it from the pans. Nobody's seen it since.", "next": "hub"},
}}

const CONV_TEASEL := {"name": "Teasel Dray", "start": [["!met:teasel", "meet"], ["", "hub"]], "nodes": {
	"meet": {"say": "Careful of the racks. A month of work hangs on those lines and the damp's already at it.", "next": "meet2"},
	"meet2": {"say": "Teasel. I boil the brine down and I dry what's left. My sister went up to the Anchorholds, to pray. That's most of what there is to know about me.", "do": "met:teasel", "next": "hub"},
	"hub": {"say_if": [
		["boss:r37_anchoress", "She came down, the Anchoress. Stone and chain, they said. I looked for Wren in what was left of her. I won't say what I found."],
		["qd:anchor_names", "Seven days. She lasted seven. And then she heard something, and she wrote it down, and she didn't leave. I understand that better than I'd like."],
		["", "They walled themselves into the Crowns to pray the sky still. Wren said it was the only honest thing anyone was doing."],
	], "choices": [
		{"text": "What are the Anchorholds?", "to": "holds", "once": true},
		{"text": "Why salt for drying?", "to": "salt", "once": true},
		{"text": "Goodbye.", "to": ""},
	]},
	"holds": {"say": "Cells cut into the rock, a ladder to each, a wall built up behind you when you went in. You were fed through a slot. You prayed. The idea was nobody would ever ask the sky for anything again.", "next": "hub"},
	"salt": {"say": "Salt takes the water out of a thing. Meat, fish, a grief. Doesn't take it all. Leaves the shape.", "next": "hub"},
}}

const CONV_ORRIN := {"name": "Orrin Vail", "start": [["!met:orrin", "meet"], ["", "hub"]], "nodes": {
	"meet": {"say": "Salt, rope, a few things off the road that I don't ask the history of. Everything's priced in grave ash. Don't bargain. I've heard every one of them.", "next": "meet2"},
	"meet2": {"say": "Orrin Vail. I carry to Hearthward and I carry back. Nobody's stopped me yet. I think I smell too much of salt for the hollowed.", "do": "met:orrin", "next": "hub"},
	"hub": {"say_if": [
		["boss:r37_anchoress", "Cliff road's open, they say. I won't be taking it. Open's what they said about the door, too."],
		["", "I've sold salt to Pilgrims, Kindlers and one Hierarch's cook. All three paid in coin that's worth nothing now. Ash, then. Ash is honest."],
	], "choices": [
		{"text": "What are you selling?", "to": "shop", "do": "shop:orrin"},
		{"text": "Goodbye.", "to": ""},
	]},
	"shop": {"say": "Look all you like.", "next": "hub"},
}}

const CONV_ARDEL := {"name": "Ardel Wick", "start": [["!met:ardel", "meet"], ["", "hub"]], "nodes": {
	"meet": {"say": "You'll have seen it from the road, or you won't have. The Spire. North of here, past the lake, on the bluff. It was never very high. It was high enough.", "next": "meet2"},
	"meet2": {"say": "Ardel Wick. Lamplighter, third of my line. I kept the wick trimmed and the oil full until the winter the oil stopped coming. And then I kept it trimmed anyway.", "do": "met:ardel", "next": "hub"},
	"hub": {"say_if": [
		["qp:bell_spire:rung", "I heard it from the window. Eight, Brannoc's mother cast. I would have said seven and been wrong nine winters. Three lanterns on the lake road last night. Walking toward us."],
		["qp:bell_spire:carried", "You took its tongue to the Keg. Fine. The Marches never needed ringing for. We needed someone to come and ask. You came and asked."],
		["qd:spire_coal,q:founders_peal", "There's a bell at the Spire's foot. Past the lamp. The Order left a man at it and told him to see it stayed quiet. He saw to it. He's very good. Be better."],
		["secret:open:spire_lamp", "I saw it. The glow on the lake, the first night. I sat up till dawn. It's a good light. It's still your light, you know. I only carried the wick."],
		["qd:spire_coal", "North and up. It's a long climb: fourteen flights, and the last of them is the worst. Keep the coal in the dish. The wind off the lake will take it."],
		["", "A flame that stays lit when it's looked at is a poor sort of flame. The lamp's dark, and it's waiting. It will light for anyone who carries the fire up. That's the whole of the trade."],
	], "choices": [
		{"text": "Who were the Lamplighters?", "to": "who", "once": true},
		{"text": "Why not light it yourself?", "to": "why", "once": true},
		{"text": "Goodbye.", "to": ""},
	]},
	"who": {"say": "The Marches' own. Not the Order's. The Order kept the Stair; we kept the road home. They said the sky was a door. We said it was a roof and somebody ought to put a lamp under it.", "next": "hub"},
	"why": {"say": "My knees. And a lamp lit by somebody who doesn't mean it is only a fire. It wants somebody walking up toward something.", "next": "hub"},
}}

const CONV_PIP := {"name": "Pip", "start": [["!met:pip", "meet"], ["", "hub"]], "nodes": {
	"meet": {"say": "You've got a lantern! Real flame? Can I hold it? No. All right. I'm Pip.", "do": "met:pip", "next": "hub"},
	"hub": {"say_if": [
		["secret:open:spire_lamp", "I saw it! From the roof of the shed! It's the colour of the inside of a loaf!"],
		["", "I hauled forty sacks today. Fifty, if you count the ones I carried twice. Marl says I'm to count the ones I carried twice. I don't."],
	], "choices": [
		{"text": "Anything out on the pans?", "to": "pans", "once": true},
		{"text": "Goodbye.", "to": ""},
	]},
	"pans": {"say": "White stuff that crunches. And tall shiny stones where the salt grew up wrong. Don't lick them. I did. Once.", "next": "hub"},
}}

# --- Orrin's stall (village_shop.gd) ----------------------------------------------------------------

const MERCHANT_ORRIN := {"name": "Orrin Vail's stall", "greet": "Salt, rope, off-the-road oddities. Ash, no haggling. Take your time; I have all night and no one else is awake."}
const GOODS_ORRIN := [
	{"id": "relic_fragment", "item": "relic_fragment", "price": 14, "stock": 2, "say": "Bell-bronze, or a saint. I didn't ask which."},
	{"id": "ember_shard", "item": "ember_shard", "price": 9, "stock": 3, "say": "Off a slag heap, they say. Still warm in the right hands."},
]
