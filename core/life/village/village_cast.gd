extends RefCounted
## Hearthward's people and places (village system, data only; no class_name).
##   NODES / EDGES   the walking network (VillageNav checks it against the built world)
##   LAMPS           the lamplighter's round: post xz, the node he lights it from, the set it is in
##   CAST            who lives here: rig options, when they are present, home, schedule, routines
##   RESTORE         what comes back as the wanderer progresses (VillageState evaluates, persists)
## A schedule may also name a "rain" routine (used while it rains, unless the phase's routine is in
## `all_weather`); in danger (the Gloom tide, hollowed in the village) everyone not `fearless` and not
## camped out runs into the Keg ("flee", added by villager.gd). A step's "face": "%id" visits that
## villager: they turn to each other and talk (act "chat").
## Conditions: QuestDB terms (flag:, seal:, boss:, item:, kindled:n, bosses:n) plus v:x (a village
## flag or restoration), met:x, ash:n (grave ash in the satchel), hollows:n (times the wanderer
## has come back from the fire). See village_state.gd.
## Load by path: const Cast := preload("res://core/life/village/village_cast.gd")

## Phases of the village night (fractions of VillageClock.CYCLE).
const PHASES := [[0.0, "dusk"], [0.12, "work"], [0.55, "midnight"], [0.66, "late"]]

const NODES := {
	# the Kindled Keg
	"keg": Vector2(17.6, 20.0), "keg_in": Vector2(17.6, 23.6), "keg_w": Vector2(16.1, 20.5), "keg_e": Vector2(19.1, 20.5),
	# the green round the spawn brazier (0, 0, 33)
	"green_se": Vector2(5.0, 27.5), "green_sw": Vector2(-6.0, 27.0), "green_w": Vector2(-7.0, 34.0),
	"green_nw": Vector2(-6.0, 40.0), "green_ne": Vector2(5.0, 39.0), "green_e": Vector2(6.0, 33.5),
	"green_n": Vector2(-1.0, 43.5), "hearth_s": Vector2(2.5, 25.0), "rim_head": Vector2(0.0, 20.5),
	"shrine": Vector2(-5.8, 22.4),
	"brazier_w": Vector2(-2.3, 33.4), "brazier_e": Vector2(2.3, 32.4), "brazier_n": Vector2(0.4, 35.4),
	"brazier_s": Vector2(-0.6, 30.7),
	# west: Maud's, the well, the noticeboard, the road, the Wrights'
	"maud": Vector2(-13.2, 39.0), "well": Vector2(-10.0, 46.3), "notice": Vector2(-4.0, 43.9),
	"road_w1": Vector2(-6.0, 53.2), "road_w2": Vector2(-20.0, 55.2), "pilgrim_rest": Vector2(-21.0, 52.4),
	"wright_door": Vector2(-13.8, 60.3), "road_s": Vector2(-10.0, 57.4), "chop": Vector2(-8.8, 61.0),
	# east: the road bend, the forge, the Reeds'
	"road_bend": Vector2(2.0, 45.2), "road_e1": Vector2(11.0, 48.2), "forge_front": Vector2(12.5, 56.0),
	"forge_in": Vector2(11.0, 58.6), "forge_hearth": Vector2(9.6, 60.1), "forge_anvil": Vector2(11.8, 59.45),
	"forge_quench": Vector2(12.45, 59.85), "forge_grind": Vector2(13.4, 59.6),
	"reed_door": Vector2(21.1, 38.6), "reed_s": Vector2(24.5, 37.3), "reed_se": Vector2(28.2, 39.0), "reed_garden": Vector2(28.0, 44.2),
	"reed_grave": Vector2(30.4, 46.4),
	# the Harrows' (south of the green, by the west way)
	"harrow": Vector2(-13.6, 16.6),
	# the ash-wife's cart
	"cart": Vector2(-8.6, 29.6), "cart_n": Vector2(-9.7, 32.3), "cart_s": Vector2(-9.9, 27.6),
	"well_e": Vector2(-7.4, 48.2),
}

const EDGES := [
	["keg", "keg_in"], ["keg", "keg_w"], ["keg", "keg_e"], ["keg", "green_se"], ["keg", "hearth_s"], ["hearth_s", "green_se"], ["hearth_s", "rim_head"],
	["rim_head", "shrine"], ["shrine", "green_sw"], ["green_sw", "green_se"], ["green_sw", "green_w"],
	["green_w", "green_nw"], ["green_nw", "green_n"], ["green_n", "green_ne"], ["green_ne", "green_e"],
	["green_e", "green_se"], ["green_w", "brazier_w"], ["green_e", "brazier_e"], ["green_n", "brazier_n"],
	["green_sw", "brazier_s"], ["green_se", "brazier_s"], ["green_nw", "maud"], ["maud", "well"], ["green_n", "notice"],
	["road_w1", "green_n"], ["road_w1", "road_bend"], ["green_n", "road_bend"],
	["green_ne", "road_bend"], ["road_bend", "road_e1"], ["road_e1", "forge_front"], ["forge_front", "forge_in"],
	["forge_in", "forge_hearth"], ["forge_in", "forge_anvil"], ["forge_anvil", "forge_hearth"], ["forge_anvil", "forge_quench"],
	["forge_quench", "forge_grind"], ["forge_in", "forge_grind"],
	["green_ne", "reed_door"], ["reed_door", "reed_s"], ["reed_s", "reed_se"], ["reed_se", "reed_garden"], ["reed_garden", "reed_grave"],
	["road_w1", "road_w2"], ["road_w2", "pilgrim_rest"], ["road_w1", "road_s"], ["road_s", "wright_door"],
	["road_s", "chop"], ["wright_door", "chop"],
	["green_sw", "harrow"], ["green_sw", "cart_s"], ["cart_s", "cart"], ["green_w", "cart_n"], ["cart_n", "cart"],
	["well", "well_e"], ["well_e", "road_w1"],
]

## The lamplighter's lamps, in round order. set A burns from the first night; B and C are added as
## the village is restored (village_state.gd: lamps()).
const LAMPS := [
	{"id": "lamp_keg", "post": Vector2(15.4, 19.4), "spot": "keg", "set": "A"},
	{"id": "lamp_reed", "post": Vector2(19.6, 37.3), "spot": "reed_door", "set": "C"},
	{"id": "lamp_green_ne", "post": Vector2(6.8, 40.7), "spot": "green_ne", "set": "A"},
	{"id": "lamp_road", "post": Vector2(12.6, 46.3), "spot": "road_e1", "set": "B"},
	{"id": "lamp_forge", "post": Vector2(14.9, 55.8), "spot": "forge_front", "set": "B"},
	{"id": "lamp_wright", "post": Vector2(-12.4, 57.0), "spot": "road_s", "set": "C"},
	{"id": "lamp_well", "post": Vector2(-8.0, 45.2), "spot": "well", "set": "B"},
	{"id": "lamp_maud", "post": Vector2(-11.8, 37.4), "spot": "maud", "set": "A"},
	{"id": "lamp_green_sw", "post": Vector2(-7.6, 25.4), "spot": "green_sw", "set": "A"},
	{"id": "lamp_rim", "post": Vector2(1.9, 19.0), "spot": "rim_head", "set": "A"},
]

## Palette: deep sRGB that holds under the grade (skin/reds at hue 15-28 deg, DwarfRig notes).
## Cloth is dyed-wool deep and only moderately saturated (the grade multiplies saturation by 1.42,
## so a pure orange went neon); grey and white hair is warm (ivory, ash), never neutral (neutral
## greys are pulled into the azure band and read blue).
const CAST := {
	"hild": {"name": "Hild", "title": "Hild, Edda's granddaughter", "when": "",
		"rig": {"seed": 4101, "sex": "f", "age": "adult", "garment": "shirt", "apron": "leather", "hat": "kerchief", "hair": "bun",
			"r": "hammer", "l": "tongs", "girth": 1.08, "cloth": Color(0.5, 0.34, 0.22), "cloth2": Color(0.3, 0.25, 0.2),
			"hair_c": Color(0.22, 0.13, 0.08), "skin": Color(0.8, 0.57, 0.41), "leather": Color(0.42, 0.26, 0.13)},
		"home": "forge_in", "speed": 1.1,
		"schedule": {"dusk": "forge", "work": "forge", "midnight": "break", "late": "forge"},
		"routines": {
			"forge": [
				{"act": "heat", "at": "forge_hearth", "face": Vector2(9.6, 61.4), "t": [5.0, 7.0]},
				{"act": "hammer", "at": "forge_anvil", "face": Vector2(11.8, 60.2), "t": [9.0, 14.0]},
				{"act": "heat", "at": "forge_hearth", "face": Vector2(9.6, 61.4), "t": [3.0, 5.0]},
				{"act": "hammer", "at": "forge_anvil", "face": Vector2(11.8, 60.2), "t": [8.0, 12.0]},
				{"act": "quench", "at": "forge_quench", "face": Vector2(13.2, 60.9), "t": [4.0, 5.0]},
				{"act": "grind", "at": "forge_grind", "face": Vector2(13.4, 58.8), "t": [5.0, 8.0]},
			],
			"break": [
				{"act": "idle", "at": "forge_front", "face": Vector2(8.0, 50.0), "t": [6.0, 9.0]},
				{"act": "draw_water", "at": "well", "face": Vector2(-10.0, 48.5), "t": [6.0, 8.0], "if": "v:well"},
				{"act": "warm", "at": "brazier_n", "face": Vector2(0.0, 33.0), "t": [8.0, 12.0]},
				{"act": "chat", "at": "cart_n", "face": "%grisel", "t": [12.0, 16.0]},
				{"go": "forge_in"},
			],
		}},
	"fennick": {"name": "Fennick", "title": "Old Fennick, the lamplighter", "when": "",
		"rig": {"seed": 4202, "sex": "m", "age": "old", "garment": "coat", "hat": "brim", "hair": "fringe", "beard": "short",
			"r": "pole", "l": "lantern", "girth": 0.95, "cloth": Color(0.2, 0.26, 0.38), "cloth2": Color(0.3, 0.28, 0.26),
			"hair_c": Color(0.74, 0.68, 0.58), "skin": Color(0.78, 0.55, 0.41), "leather": Color(0.36, 0.22, 0.12)},
		"home": "keg", "speed": 0.85, "light": true, "all_weather": ["round"],
		"schedule": {"dusk": "round", "work": "rest", "midnight": "round", "late": "rest", "rain": "wet"},
		"routines": {
			"round": [{"lamps": true}],
			"wet": [{"act": "chat", "at": "keg_w", "face": "%col", "t": [10.0, 14.0]}, {"hide": "keg_in", "t": [30.0, 45.0]}],
			"rest": [
				{"act": "chat", "at": "keg_w", "face": "%col", "t": [14.0, 20.0], "if": "v:wrights_home"},
				{"act": "idle", "at": "green_e", "face": Vector2(0.0, 33.0), "t": [10.0, 16.0]},
				{"act": "warm", "at": "brazier_e", "face": Vector2(0.0, 33.0), "t": [12.0, 18.0]},
				{"act": "idle", "at": "notice", "face": Vector2(-5.5, 45.5), "t": [6.0, 9.0]},
				{"hide": "keg_in", "t": [20.0, 30.0]},
			],
		}},
	"oswin": {"name": "Oswin", "title": "Oswin, a pilgrim", "when": "",
		"rig": {"seed": 4303, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "hair": "short", "beard": "short",
			"r": "staff", "satchel": true, "barefoot": true, "girth": 0.92, "cloth": Color(0.42, 0.38, 0.32),
			"cloth2": Color(0.32, 0.29, 0.25), "hair_c": Color(0.3, 0.2, 0.12), "skin": Color(0.7, 0.5, 0.36), "leather": Color(0.38, 0.24, 0.12)},
		"home": "pilgrim_rest", "speed": 0.9,
		"schedule": {"dusk": "rest", "work": "rest", "midnight": "pray", "late": "sleep"},
		"routines": {
			"rest": [
				{"act": "sit", "at": "pilgrim_rest", "face": Vector2(-21.0, 50.0), "t": [25.0, 40.0], "seat": 0.42},
				{"act": "look_up", "at": "road_w2", "face": Vector2(0.0, -95.0), "t": [6.0, 9.0]},
				{"act": "warm", "at": "brazier_w", "face": Vector2(0.0, 33.0), "t": [14.0, 20.0]},
				{"act": "read", "at": "notice", "face": Vector2(-5.5, 45.5), "t": [5.0, 8.0]},
			],
			"pray": [
				{"act": "kneel", "at": "road_w2", "face": Vector2(0.0, -95.0), "t": [30.0, 40.0]},
			],
			"sleep": [
				{"act": "doze", "at": "pilgrim_rest", "face": Vector2(-21.0, 50.0), "t": [60.0, 90.0], "seat": 0.42},
			],
		}},
	"nan": {"name": "Nan", "title": "Nan Wright", "when": "",
		"rig": {"seed": 4404, "sex": "f", "age": "child", "garment": "dress", "apron": "linen", "hair": "braids", "r": "chalk",
			"cloth": Color(0.42, 0.3, 0.2), "cloth2": Color(0.36, 0.3, 0.24), "hair_c": Color(0.5, 0.28, 0.12),
			"skin": Color(0.86, 0.65, 0.49), "leather": Color(0.4, 0.25, 0.13)},
		"home": "keg_in", "speed": 1.15, "home_when": {"v:wrights_home": "wright_door"},
		"schedule": {"dusk": "play", "work": "play", "midnight": "home", "late": "play", "rain": "home"},
		"routines": {
			"play": [
				{"act": "chat", "at": "brazier_s", "face": "%pell", "t": [10.0, 14.0], "if": "v:pell"},
				{"act": "chalk", "at": "maud", "face": Vector2(-14.4, 39.6), "t": [8.0, 12.0]},
				{"act": "warm", "at": "brazier_s", "face": Vector2(0.0, 33.0), "t": [8.0, 12.0]},
				{"act": "chalk", "at": "notice", "face": Vector2(-3.0, 43.0), "t": [6.0, 9.0]},
				{"act": "watch", "at": "forge_front", "face": Vector2(11.8, 60.2), "t": [10.0, 14.0]},
				{"act": "chalk", "at": "keg", "face": Vector2(17.6, 21.2), "t": [6.0, 9.0]},
				{"act": "draw_water", "at": "well", "face": Vector2(-10.0, 48.5), "t": [6.0, 8.0], "if": "v:well"},
			],
			"home": [{"hide": "@home", "t": [40.0, 60.0]}],
		}},
	"col": {"name": "Col", "title": "Col Wright", "when": "v:wrights_home",
		"rig": {"seed": 4505, "sex": "m", "age": "adult", "garment": "shirt", "hat": "cap", "hair": "short", "beard": "short",
			"r": "axe", "girth": 1.04, "cloth": Color(0.3, 0.42, 0.3), "cloth2": Color(0.34, 0.28, 0.2),
			"hair_c": Color(0.3, 0.18, 0.09), "skin": Color(0.76, 0.54, 0.38), "leather": Color(0.42, 0.27, 0.14)},
		"home": "wright_door", "speed": 1.05,
		"schedule": {"dusk": "chop", "work": "chop", "midnight": "keg", "late": "keg", "rain": "keg"},
		"routines": {
			"chop": [
				{"act": "chop", "at": "chop", "face": Vector2(-8.8, 61.9), "t": [16.0, 24.0]},
				{"act": "idle", "at": "road_s", "face": Vector2(0.0, 33.0), "t": [4.0, 6.0]},
			],
			"keg": [{"act": "warm", "at": "brazier_n", "face": Vector2(0.0, 33.0), "t": [10.0, 14.0]},
				{"act": "chat", "at": "keg_e", "face": "%fennick", "t": [16.0, 22.0]},
				{"hide": "keg_in", "t": [25.0, 35.0]}],
		}},
	"bet": {"name": "Bet", "title": "Bet Reed", "when": "v:reed_home",
		"rig": {"seed": 4606, "sex": "f", "age": "old", "garment": "dress", "shawl": true, "hat": "kerchief", "hair": "bun",
			"cloth": Color(0.24, 0.21, 0.25), "cloth2": Color(0.3, 0.26, 0.22), "hair_c": Color(0.7, 0.64, 0.55),
			"skin": Color(0.8, 0.6, 0.46), "leather": Color(0.36, 0.22, 0.12)},
		"home": "reed_door", "speed": 0.8,
		"schedule": {"dusk": "garden", "work": "garden", "midnight": "mourn", "late": "garden", "rain": "indoors"},
		"routines": {
			"garden": [
				{"act": "garden", "at": "reed_garden", "face": Vector2(29.5, 45.5), "t": [20.0, 30.0]},
				{"act": "idle", "at": "reed_door", "face": Vector2(5.0, 39.0), "t": [5.0, 8.0]},
				{"hide": "reed_door", "t": [12.0, 18.0]},
			],
			"mourn": [{"act": "mourn", "at": "reed_grave", "face": Vector2(31.6, 47.6), "t": [25.0, 35.0]}],
			"indoors": [{"hide": "reed_door", "t": [30.0, 50.0]}, {"act": "idle", "at": "reed_door", "face": Vector2(5.0, 39.0), "t": [4.0, 6.0]}],
		}},
	"wenna": {"name": "Wenna", "title": "Wenna Ashby", "when": "v:wenna",
		"rig": {"seed": 4707, "sex": "f", "age": "teen", "garment": "robe", "hair": "long", "r": "candle", "satchel": true,
			"cloth": Color(0.34, 0.33, 0.4), "cloth2": Color(0.3, 0.27, 0.24), "hair_c": Color(0.58, 0.34, 0.15),
			"skin": Color(0.84, 0.63, 0.48), "leather": Color(0.4, 0.25, 0.13)},
		"home": "harrow", "speed": 0.95,
		"schedule": {"dusk": "vigil", "work": "vigil", "midnight": "shrine", "late": "vigil"},
		"routines": {
			"vigil": [
				{"act": "sit", "at": "brazier_s", "face": Vector2(0.0, 33.0), "t": [30.0, 45.0], "seat": 0.0},
				{"act": "idle", "at": "harrow", "face": Vector2(-19.0, 13.0), "t": [8.0, 12.0]},
			],
			"shrine": [{"act": "kneel", "at": "shrine", "face": Vector2(-8.5, 19.5), "t": [30.0, 40.0]}],
		}},
	"pell": {"name": "Pell", "title": "Pell", "when": "v:pell",
		"rig": {"seed": 4808, "sex": "f", "age": "child", "garment": "robe", "hood": true, "hair": "long", "pale": true, "barefoot": true,
			"cloth": Color(0.48, 0.21, 0.13), "cloth2": Color(0.36, 0.33, 0.32), "hair_c": Color(0.42, 0.3, 0.2),
			"skin": Color(0.84, 0.66, 0.52), "leather": Color(0.36, 0.22, 0.12)},
		"home": "brazier_w", "speed": 0.7, "silent_walk": true, "fearless": true,
		"schedule": {"dusk": "fire", "work": "fire", "midnight": "door", "late": "fire"},
		"routines": {
			"fire": [{"act": "sit", "at": "brazier_w", "face": Vector2(0.0, 33.0), "t": [60.0, 90.0], "seat": 0.0}],
			"door": [{"act": "knock", "at": "maud", "face": Vector2(-14.4, 39.6), "t": [9.0, 9.0]}, {"act": "sit", "at": "brazier_w", "face": Vector2(0.0, 33.0), "t": [60.0, 60.0], "seat": 0.0}],
		}},
	"wyck": {"name": "Wyck", "title": "Wyck of the Thornwood", "when": "", "camp": "hermit",
		"rig": {"seed": 4909, "sex": "m", "age": "old", "garment": "robe", "hair": "wild", "beard": "long", "r": "staff",
			"cloth": Color(0.3, 0.32, 0.22), "cloth2": Color(0.28, 0.25, 0.2), "hair_c": Color(0.64, 0.58, 0.48),
			"skin": Color(0.72, 0.52, 0.38), "leather": Color(0.34, 0.22, 0.12)},
		"home": "h_fire", "speed": 0.75,
		"schedule": {"dusk": "camp", "work": "camp", "midnight": "walk", "late": "camp"},
		"routines": {
			"camp": [
				{"act": "tend", "at": "h_fire", "face": "@fire", "t": [8.0, 12.0]},
				{"act": "sit", "at": "h_seat", "face": "@fire", "t": [20.0, 30.0], "seat": 0.36, "work": "carve"},
				{"act": "bury", "at": "h_grave", "face": "@grave", "t": [8.0, 10.0]},
			],
			"walk": [{"go": "h_w1"}, {"act": "idle", "at": "h_w2", "face": "@out", "t": [6.0, 9.0]}, {"go": "h_w3"}, {"go": "h_fire"}],
		}},
	"abel": {"name": "Abel", "title": "Abel the sexton", "when": "", "camp": "sexton",
		"rig": {"seed": 5010, "sex": "m", "age": "adult", "garment": "coat", "hat": "brim", "hair": "short", "r": "spade",
			"girth": 1.0, "cloth": Color(0.17, 0.16, 0.17), "cloth2": Color(0.26, 0.24, 0.22), "hair_c": Color(0.2, 0.15, 0.1),
			"skin": Color(0.74, 0.53, 0.38), "leather": Color(0.3, 0.19, 0.1)},
		"home": "s_dig", "speed": 0.9,
		"schedule": {"dusk": "dig", "work": "dig", "midnight": "edda", "late": "dig"},
		"routines": {
			"dig": [
				{"act": "dig", "at": "s_dig", "face": "@pit", "t": [18.0, 26.0]},
				{"act": "lean", "at": "s_dig", "face": "@pit", "t": [5.0, 8.0]},
			],
			"edda": [{"go": "s_gate_in"}, {"act": "mourn", "at": "s_edda", "face": Vector2(-85.2, 44.0), "t": [16.0, 22.0]}, {"go": "s_dig"}],
		}},
	"grisel": {"name": "Grisel", "title": "Grisel the ash-wife", "when": "", "trader": true,
		"rig": {"seed": 5111, "sex": "f", "age": "old", "garment": "dress", "apron": "linen", "hood": true, "shawl": true, "hair": "bun",
			"r": "scoop", "cloth": Color(0.36, 0.34, 0.33), "cloth2": Color(0.3, 0.28, 0.26), "hair_c": Color(0.62, 0.56, 0.48),
			"skin": Color(0.78, 0.58, 0.44), "leather": Color(0.36, 0.22, 0.12)},
		"home": "cart", "speed": 0.8,
		"schedule": {"dusk": "sell", "work": "sell", "midnight": "sell", "late": "sell"},
		"routines": {"sell": [{"act": "sell", "at": "cart", "face": "@cart", "t": [20.0, 30.0]}, {"act": "sift", "at": "cart", "face": "@cart", "t": [10.0, 14.0]}]}},

	# --- r34: the doubled world's givers, each camped at an outpost fire in their region (OUTPOSTS;
	# village.gd builds the camp and its walks: <id>_fire, _seat, _w1.._w3, anchors @fire_<id>,
	# @out_<id>). Always present; they do not flee (camped out).
	"ruan": {"name": "Ruan", "title": "Gammer Ruan of the Holds", "when": "", "camp": "outpost",
		"rig": {"seed": 5212, "sex": "f", "age": "old", "garment": "dress", "shawl": true, "hood": true, "hair": "braids",
			"r": "spade", "girth": 1.16, "cloth": Color(0.27, 0.3, 0.22), "cloth2": Color(0.34, 0.27, 0.2),
			"hair_c": Color(0.72, 0.66, 0.56), "skin": Color(0.74, 0.54, 0.4), "leather": Color(0.34, 0.22, 0.12)},
		"home": "ruan_fire", "speed": 0.7,
		"schedule": {"dusk": "camp", "work": "camp", "midnight": "walk", "late": "camp"},
		"routines": {
			"camp": [
				{"act": "tend", "at": "ruan_fire", "face": "@fire_ruan", "t": [8.0, 12.0]},
				{"act": "sit", "at": "ruan_seat", "face": "@fire_ruan", "t": [20.0, 30.0], "seat": 0.36},
				{"act": "mourn", "at": "ruan_w2", "face": "@out_ruan", "t": [8.0, 12.0]},
			],
			"walk": [{"go": "ruan_w1"}, {"act": "idle", "at": "ruan_w2", "face": "@out_ruan", "t": [6.0, 9.0]}, {"go": "ruan_w3"}, {"go": "ruan_fire"}],
		}},
	"jory": {"name": "Jory", "title": "Jory Quell, the last cutter", "when": "", "camp": "outpost",
		"rig": {"seed": 5313, "sex": "m", "age": "old", "garment": "shirt", "apron": "leather", "hat": "cap", "hair": "fringe", "beard": "short",
			"r": "hammer", "girth": 1.02, "cloth": Color(0.36, 0.34, 0.3), "cloth2": Color(0.3, 0.26, 0.22),
			"hair_c": Color(0.7, 0.66, 0.6), "skin": Color(0.76, 0.56, 0.42), "leather": Color(0.4, 0.26, 0.14)},
		"home": "jory_fire", "speed": 0.8,
		"schedule": {"dusk": "cut", "work": "cut", "midnight": "camp", "late": "cut"},
		"routines": {
			"cut": [
				{"act": "chop", "at": "jory_block", "face": "@block_jory", "t": [14.0, 20.0]},
				{"act": "warm", "at": "jory_fire", "face": "@fire_jory", "t": [8.0, 12.0]},
			],
			"camp": [
				{"act": "sit", "at": "jory_seat", "face": "@fire_jory", "t": [20.0, 30.0], "seat": 0.36},
				{"act": "idle", "at": "jory_w2", "face": "@out_jory", "t": [6.0, 9.0]},
				{"go": "jory_w3"},
			],
		}},
	"ysolt": {"name": "Ysolt", "title": "Ysolt the cairn-keeper", "when": "", "camp": "outpost",
		"rig": {"seed": 5414, "sex": "f", "age": "old", "garment": "robe", "hood": true, "hair": "long", "r": "staff",
			"cloth": Color(0.32, 0.28, 0.3), "cloth2": Color(0.28, 0.25, 0.22), "hair_c": Color(0.76, 0.7, 0.6),
			"skin": Color(0.78, 0.58, 0.44), "leather": Color(0.36, 0.22, 0.12)},
		"home": "ysolt_fire", "speed": 0.75,
		"schedule": {"dusk": "camp", "work": "walk", "midnight": "camp", "late": "walk"},
		"routines": {
			"camp": [
				{"act": "tend", "at": "ysolt_fire", "face": "@fire_ysolt", "t": [8.0, 12.0]},
				{"act": "sit", "at": "ysolt_seat", "face": "@fire_ysolt", "t": [18.0, 26.0], "seat": 0.36},
			],
			"walk": [{"go": "ysolt_w1"}, {"act": "idle", "at": "ysolt_w2", "face": "@out_ysolt", "t": [8.0, 12.0]}, {"go": "ysolt_w3"}, {"go": "ysolt_fire"}],
		}},
	"elspeth": {"name": "Elspeth", "title": "Elspeth Fane, the Founder's journeywoman", "when": "", "camp": "outpost",
		"rig": {"seed": 5515, "sex": "f", "age": "adult", "garment": "shirt", "apron": "leather", "hat": "kerchief", "hair": "bun",
			"r": "scoop", "girth": 1.05, "cloth": Color(0.4, 0.26, 0.2), "cloth2": Color(0.3, 0.25, 0.2),
			"hair_c": Color(0.2, 0.12, 0.08), "skin": Color(0.72, 0.5, 0.36), "leather": Color(0.38, 0.24, 0.12)},
		"home": "elspeth_fire", "speed": 1.0,
		"schedule": {"dusk": "camp", "work": "camp", "midnight": "walk", "late": "camp"},
		"routines": {
			"camp": [
				{"act": "tend", "at": "elspeth_fire", "face": "@fire_elspeth", "t": [8.0, 12.0]},
				{"act": "warm", "at": "elspeth_fire", "face": "@fire_elspeth", "t": [8.0, 12.0]},
				{"act": "sit", "at": "elspeth_seat", "face": "@fire_elspeth", "t": [16.0, 24.0], "seat": 0.36},
			],
			"walk": [{"go": "elspeth_w1"}, {"act": "idle", "at": "elspeth_w2", "face": "@out_elspeth", "t": [6.0, 9.0]}, {"go": "elspeth_w3"}, {"go": "elspeth_fire"}],
		}},
	"linnet": {"name": "Linnet", "title": "Linnet the grafter", "when": "", "camp": "outpost",
		"rig": {"seed": 5616, "sex": "f", "age": "teen", "garment": "dress", "apron": "linen", "hair": "braids", "r": "crook",
			"cloth": Color(0.44, 0.3, 0.2), "cloth2": Color(0.3, 0.27, 0.22), "hair_c": Color(0.52, 0.26, 0.1),
			"skin": Color(0.84, 0.63, 0.47), "leather": Color(0.4, 0.25, 0.13)},
		"home": "linnet_fire", "speed": 1.05,
		"schedule": {"dusk": "camp", "work": "graft", "midnight": "camp", "late": "graft"},
		"routines": {
			"camp": [
				{"act": "tend", "at": "linnet_fire", "face": "@fire_linnet", "t": [8.0, 12.0]},
				{"act": "sit", "at": "linnet_seat", "face": "@fire_linnet", "t": [16.0, 24.0], "seat": 0.36},
			],
			"graft": [{"go": "linnet_w1"}, {"act": "garden", "at": "linnet_w2", "face": "@out_linnet", "t": [14.0, 20.0]}, {"go": "linnet_w3"}, {"go": "linnet_fire"}],
		}},
	"agathe": {"name": "Agathe", "title": "Sister Agathe of the Waiting Field", "when": "", "camp": "outpost",
		"rig": {"seed": 5717, "sex": "f", "age": "old", "garment": "robe", "hood": true, "hair": "bun", "r": "candle",
			"cloth": Color(0.22, 0.2, 0.22), "cloth2": Color(0.36, 0.33, 0.3), "hair_c": Color(0.78, 0.74, 0.66),
			"skin": Color(0.8, 0.6, 0.47), "leather": Color(0.32, 0.2, 0.11)},
		"home": "agathe_fire", "speed": 0.7,
		"schedule": {"dusk": "vigil", "work": "camp", "midnight": "vigil", "late": "camp"},
		"routines": {
			"camp": [
				{"act": "warm", "at": "agathe_fire", "face": "@fire_agathe", "t": [8.0, 12.0]},
				{"act": "sit", "at": "agathe_seat", "face": "@fire_agathe", "t": [18.0, 26.0], "seat": 0.36},
			],
			"vigil": [{"go": "agathe_w1"}, {"act": "kneel", "at": "agathe_w2", "face": "@out_agathe", "t": [16.0, 24.0]}, {"go": "agathe_w3"}, {"go": "agathe_fire"}],
		}},
	"cadoc": {"name": "Cadoc", "title": "Cadoc the ferryman", "when": "", "camp": "outpost",
		"rig": {"seed": 5818, "sex": "m", "age": "old", "garment": "coat", "hat": "brim", "hair": "wild", "beard": "long",
			"r": "pole", "l": "lantern", "girth": 0.96, "cloth": Color(0.2, 0.24, 0.26), "cloth2": Color(0.3, 0.27, 0.24),
			"hair_c": Color(0.66, 0.62, 0.55), "skin": Color(0.74, 0.54, 0.4), "leather": Color(0.34, 0.22, 0.12)},
		"home": "cadoc_fire", "speed": 0.8,
		"schedule": {"dusk": "camp", "work": "watch", "midnight": "camp", "late": "watch"},
		"routines": {
			"camp": [
				{"act": "warm", "at": "cadoc_fire", "face": "@fire_cadoc", "t": [8.0, 12.0]},
				{"act": "sit", "at": "cadoc_seat", "face": "@fire_cadoc", "t": [18.0, 26.0], "seat": 0.36},
			],
			"watch": [{"go": "cadoc_w1"}, {"act": "idle", "at": "cadoc_w2", "face": "@out_cadoc", "t": [10.0, 14.0]}, {"go": "cadoc_w3"}, {"go": "cadoc_fire"}],
		}},
}

## r34: the outposts of the doubled world (docs/r34/layout.md SLOTS): where each new giver camps.
## `near` (candidates, in order) is searched outward for a clear spot (village.gd _find_clear: off the ways, out of the sites,
## 14 m off the encounter camps); `look` is the way they stand and watch from (xz, @out_<id>);
## `style` picks the camp's dressing (village_props.gd outpost()).
const OUTPOSTS := {
	"ruan": {"near": [Vector2(-128.0, 0.0), Vector2(-120.0, 10.0), Vector2(-126.0, 25.0), Vector2(-144.0, 2.0)], "region": "holds", "style": "holds", "look": Vector2(-86.0, -24.0)},
	"jory": {"near": [Vector2(-135.0, -74.0), Vector2(-138.0, -109.0), Vector2(-120.0, -70.0)], "region": "quarry", "style": "quarry", "look": Vector2(-128.0, -104.0)},
	"ysolt": {"near": [Vector2(132.0, -14.0), Vector2(132.0, 10.0)], "region": "moor", "style": "moor", "look": Vector2(141.0, -24.0)},
	"elspeth": {"near": [Vector2(118.0, -72.0), Vector2(126.0, -70.0)], "region": "foundry", "style": "foundry", "look": Vector2(135.0, -105.0)},
	"linnet": {"near": [Vector2(-106.0, 112.0), Vector2(-96.0, 112.0)], "region": "orchard", "style": "orchard", "look": Vector2(-86.0, 122.0)},
	"agathe": {"near": [Vector2(-10.0, 108.0), Vector2(15.0, 105.0)], "region": "necropolis", "style": "necropolis", "look": Vector2(0.0, -104.0)},
	"cadoc": {"near": [Vector2(111.0, 97.0), Vector2(95.0, 100.0), Vector2(130.0, 95.0)], "region": "mere", "style": "mere", "look": Vector2(84.0, 112.0)},
}

## What returns. `when` is checked on load and after every event; once true it stays (saved).
const RESTORE := [
	{"id": "wrights_home", "when": "kindled:1|seal:henge|seal:oss_gallery|bosses:1",
		"toast": "Smoke from the Wrights' chimney. They have come home from the Keg."},
	{"id": "well", "when": "kindled:2|bosses:1|v:paid_well", "toast": "Hearthward's well is drawn again."},
	{"id": "lamps_more", "when": "v:oil", "toast": "Fennick's round is longer tonight."},
	{"id": "lamps_all", "when": "bosses:2|v:oil2", "toast": "Every lamp in Hearthward is burning."},
	{"id": "reed_home", "when": "boss:thornwarden|boss:bone_abbot", "toast": "A light in the Reeds' window. Bet Reed has come back."},
	{"id": "reed_roof", "when": "v:paid_slates|bosses:3", "toast": "New slates on the Reeds' roof."},
	{"id": "wenna", "when": "boss:bone_abbot", "toast": "Someone sits by the green's fire with one candle."},
	{"id": "harrow_frame", "when": "bosses:2", "toast": "New rafters on the Harrows' house."},
	{"id": "harrow_roof", "when": "v:harrow_frame,v:paid_thatch|boss:ascended_warden", "toast": "The Harrows' house has a roof again. Wenna keeps a candle in it."},
	{"id": "pell", "when": "boss:ascended_warden", "toast": "A child in a red hood sits by the green's fire. She does not speak."},
]

## The ash-wife's wares: village projects (do: v flags) and, automatically, any ItemDB entry that
## carries a "price" (progression's consumables when they exist).
const WARES := [
	{"id": "oil", "text": "Lamp oil for Fennick's round", "price": 8, "glyph": "oil", "info": "Three more lamps on Fennick's round: the road bend, the forge, the well. More light, fewer things knocking.", "if": "!v:oil,!v:lamps_more", "do": "v:oil", "say": "Oil. He'll walk further tonight, and complain about his knees."},
	{"id": "oil2", "text": "More lamp oil", "price": 12, "glyph": "oil", "info": "Every lamp in Hearthward lit: the Reeds' door and the Wrights' lane too.", "if": "!v:oil2,!v:lamps_all,v:oil|!v:oil2,!v:lamps_all,v:lamps_more", "do": "v:oil2", "say": "That's every lamp he's got. The dark will have to go round."},
	{"id": "rope", "text": "A new rope for the well", "price": 10, "glyph": "rope", "info": "The well by Maud's has had no rope since the Night. Col will hang it; Hild and Nan will draw from it.", "if": "!v:well", "do": "v:paid_well", "say": "Rope. Col will hang it. Water tastes of nothing, these days, but it's wet."},
	{"id": "slates", "text": "Slates for the Reeds' roof", "price": 18, "glyph": "slates", "info": "Bet Reed's roof lets in the rain over Tobin's old bed. A stack of good slate, and a ladder borrowed from the Keg.", "if": "v:reed_home,!v:reed_roof", "do": "v:paid_slates", "say": "Slates. Bet will pretend she didn't want them."},
	{"id": "thatch", "text": "Thatch for the Harrows' house", "price": 24, "glyph": "thatch", "info": "The Harrows' new rafters want a roof. Reed thatch from the fen edge, and Col's bad knees.", "if": "v:harrow_frame,!v:harrow_roof", "do": "v:paid_thatch", "say": "Thatch. The girl needs a roof more than she needs a candle. Don't tell her I said so."},
]
