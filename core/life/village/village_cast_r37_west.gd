extends RefCounted
## Weirford's people (West Marches; data only, no class_name). The living outpost at the river crossing
## (realm_pois_r37_west.gd builds the town): eight people with routines on their own walking network, merged
## into Hearthward's village system by village.gd (cast_all, extra_nodes). They are "camped out" in the
## village's terms (Weirford has its own watch; they do not flee into a Keg three hundred metres away) and are
## only spawned when their home node came through the nav's floor check. Voices stay babble (NPC voices).
## Load by path: const R37W := preload("res://core/life/village/village_cast_r37_west.gd")

## xz of every walk node (world metres). The nav drops or nudges what the built town stands on.
const NODES := {
	"wf_inn_door": Vector2(-186.0, 62.6), "wf_inn_in": Vector2(-186.0, 58.8), "wf_inn_hearth": Vector2(-181.5, 55.6),
	"wf_road_a": Vector2(-186.0, 64.8), "wf_road_b": Vector2(-177.0, 64.8), "wf_cot_a": Vector2(-165.0, 63.2),
	"wf_br_e": Vector2(-192.4, 65.6), "wf_br_m": Vector2(-206.0, 65.6), "wf_br_w": Vector2(-219.6, 65.6),
	"wf_watch_road": Vector2(-224.0, 66.6), "wf_watch": Vector2(-228.0, 67.6),
	"wf_mill_road": Vector2(-221.5, 64.4), "wf_mill_door": Vector2(-221.5, 58.6),
	"wf_sq_n": Vector2(-194.8, 69.8), "wf_fire_n": Vector2(-196.0, 71.8), "wf_fire_w": Vector2(-199.6, 74.6), "wf_fire_s": Vector2(-195.6, 77.4),
	"wf_well": Vector2(-191.0, 76.2), "wf_stall": Vector2(-185.0, 70.6),
	"wf_smith_front": Vector2(-174.0, 70.4), "wf_anvil": Vector2(-173.4, 72.4), "wf_hearth": Vector2(-176.2, 72.0),
	"wf_cot_b_pre": Vector2(-160.0, 69.0), "wf_cot_b": Vector2(-158.0, 70.4),
	"wf_stable_road": Vector2(-219.0, 70.0), "wf_stable": Vector2(-218.6, 78.0), "wf_stable_in": Vector2(-222.4, 78.0),
}

const EDGES := [
	["wf_inn_door", "wf_inn_in"], ["wf_inn_in", "wf_inn_hearth"], ["wf_inn_door", "wf_road_a"], ["wf_road_a", "wf_road_b"], ["wf_road_b", "wf_cot_a"],
	["wf_road_a", "wf_br_e"], ["wf_br_e", "wf_br_m"], ["wf_br_m", "wf_br_w"], ["wf_br_w", "wf_watch_road"], ["wf_watch_road", "wf_watch"],
	["wf_br_w", "wf_mill_road"], ["wf_mill_road", "wf_mill_door"],
	["wf_br_e", "wf_sq_n"], ["wf_sq_n", "wf_fire_n"], ["wf_fire_n", "wf_fire_w"], ["wf_fire_w", "wf_fire_s"], ["wf_fire_s", "wf_fire_n"], ["wf_fire_s", "wf_well"],
	["wf_fire_n", "wf_stall"], ["wf_stall", "wf_smith_front"], ["wf_smith_front", "wf_anvil"], ["wf_anvil", "wf_hearth"], ["wf_hearth", "wf_smith_front"],
	["wf_smith_front", "wf_cot_b_pre"], ["wf_cot_b_pre", "wf_cot_b"],
	["wf_br_w", "wf_stable_road"], ["wf_stable_road", "wf_stable"], ["wf_stable", "wf_stable_in"],
]

const CAST := {
	"dorrit": {"name": "Dorrit", "title": "Dorrit Marl, keeper of the Grey Heron", "when": "", "camp": "outpost",
		"rig": {"seed": 6101, "sex": "f", "age": "adult", "garment": "dress", "apron": "linen", "hat": "kerchief", "hair": "bun", "girth": 1.12,
			"cloth": Color(0.34, 0.27, 0.22), "cloth2": Color(0.3, 0.26, 0.22), "hair_c": Color(0.3, 0.18, 0.1),
			"skin": Color(0.8, 0.58, 0.43), "leather": Color(0.4, 0.26, 0.13)},
		"home": "wf_inn_door", "speed": 0.95, "fearless": true,
		"schedule": {"dusk": "keep", "work": "keep", "midnight": "hearth", "late": "keep"},
		"routines": {
			"keep": [
				{"act": "idle", "at": "wf_inn_door", "face": Vector2(-186.0, 72.0), "t": [8.0, 12.0]},
				{"act": "look_up", "at": "wf_road_a", "face": Vector2(-206.0, 40.0), "t": [5.0, 8.0]},
				{"hide": "wf_inn_in", "t": [16.0, 24.0]},
			],
			"hearth": [{"act": "warm", "at": "wf_inn_hearth", "face": Vector2(-180.0, 55.0), "t": [20.0, 30.0]}, {"hide": "wf_inn_in", "t": [20.0, 30.0]}],
		}},
	"osk": {"name": "Osk", "title": "Osk, the weir's miller", "when": "", "camp": "outpost",
		"rig": {"seed": 6202, "sex": "m", "age": "adult", "garment": "shirt", "apron": "linen", "hat": "cap", "hair": "short", "beard": "short", "girth": 1.2,
			"cloth": Color(0.44, 0.4, 0.34), "cloth2": Color(0.36, 0.32, 0.28), "hair_c": Color(0.5, 0.42, 0.32),
			"skin": Color(0.78, 0.56, 0.42), "leather": Color(0.38, 0.25, 0.13)},
		"home": "wf_mill_door", "speed": 0.9, "fearless": true,
		"schedule": {"dusk": "mill", "work": "mill", "midnight": "mill", "late": "mill"},
		"routines": {
			"mill": [
				{"act": "lean", "at": "wf_mill_door", "face": Vector2(-221.5, 50.0), "t": [8.0, 12.0]},
				{"act": "look_up", "at": "wf_mill_road", "face": Vector2(-206.0, 30.0), "t": [5.0, 8.0]},
				{"hide": "wf_mill_door", "t": [20.0, 30.0]},
				{"act": "idle", "at": "wf_mill_road", "face": Vector2(-206.0, 66.0), "t": [6.0, 9.0]},
			],
		}},
	"bryn": {"name": "Bryn", "title": "Bryn Gale, Weirford's smith", "when": "", "camp": "outpost",
		"rig": {"seed": 6303, "sex": "m", "age": "adult", "garment": "shirt", "apron": "leather", "hat": "", "hair": "short", "beard": "short",
			"r": "hammer", "l": "tongs", "girth": 1.18, "cloth": Color(0.4, 0.3, 0.24), "cloth2": Color(0.3, 0.25, 0.2),
			"hair_c": Color(0.18, 0.11, 0.07), "skin": Color(0.74, 0.5, 0.36), "leather": Color(0.4, 0.26, 0.14)},
		"home": "wf_smith_front", "speed": 1.05, "fearless": true,
		"schedule": {"dusk": "forge", "work": "forge", "midnight": "rest", "late": "forge"},
		"routines": {
			"forge": [
				{"act": "heat", "at": "wf_hearth", "face": Vector2(-176.2, 73.4), "t": [5.0, 7.0]},
				{"act": "hammer", "at": "wf_anvil", "face": Vector2(-173.4, 73.9), "t": [9.0, 14.0]},
				{"act": "heat", "at": "wf_hearth", "face": Vector2(-176.2, 73.4), "t": [3.0, 5.0]},
				{"act": "hammer", "at": "wf_anvil", "face": Vector2(-173.4, 73.9), "t": [8.0, 12.0]},
			],
			"rest": [
				{"act": "warm", "at": "wf_fire_n", "face": Vector2(-196.0, 74.0), "t": [12.0, 18.0]},
				{"act": "idle", "at": "wf_smith_front", "face": Vector2(-176.0, 64.0), "t": [6.0, 9.0]},
			],
		}},
	"cassel": {"name": "Cassel", "title": "Captain Cassel of the Weirford Watch", "when": "", "camp": "outpost",
		"rig": {"seed": 6404, "sex": "m", "age": "adult", "garment": "coat", "hood": true, "hair": "short", "beard": "short",
			"r": "sword", "girth": 1.06, "cloth": Color(0.3, 0.28, 0.26), "cloth2": Color(0.28, 0.25, 0.22),
			"hair_c": Color(0.35, 0.3, 0.26), "skin": Color(0.76, 0.54, 0.4), "leather": Color(0.34, 0.22, 0.12)},
		"home": "wf_watch", "speed": 1.0, "fearless": true,
		"schedule": {"dusk": "post", "work": "round", "midnight": "post", "late": "round"},
		"routines": {
			"post": [
				{"act": "idle", "at": "wf_watch", "face": Vector2(-240.0, 66.0), "t": [10.0, 14.0]},
				{"act": "look_up", "at": "wf_watch", "face": Vector2(-248.0, 54.0), "t": [5.0, 8.0]},
			],
			"round": [
				{"go": "wf_watch_road"}, {"act": "lean", "at": "wf_br_w", "face": Vector2(-206.0, 72.0), "t": [8.0, 12.0]},
				{"go": "wf_br_m"}, {"act": "idle", "at": "wf_br_m", "face": Vector2(-206.0, 40.0), "t": [6.0, 9.0]}, {"go": "wf_br_w"}, {"go": "wf_watch"},
			],
		}},
	"ennis": {"name": "Ennis", "title": "Sister Ennis, who keeps the bridge", "when": "", "camp": "outpost",
		"rig": {"seed": 6505, "sex": "f", "age": "old", "garment": "robe", "hood": true, "hair": "bun", "r": "candle", "girth": 0.96,
			"cloth": Color(0.24, 0.26, 0.28), "cloth2": Color(0.34, 0.31, 0.28), "hair_c": Color(0.74, 0.7, 0.62),
			"skin": Color(0.78, 0.58, 0.44), "leather": Color(0.34, 0.22, 0.12)},
		"home": "wf_br_m", "speed": 0.75, "fearless": true,
		"schedule": {"dusk": "vigil", "work": "vigil", "midnight": "hearth", "late": "vigil"},
		"routines": {
			"vigil": [
				{"act": "kneel", "at": "wf_br_m", "face": Vector2(-206.0, 40.0), "t": [25.0, 40.0]},
				{"act": "look_up", "at": "wf_br_m", "face": Vector2(-206.0, 100.0), "t": [6.0, 9.0]},
			],
			"hearth": [{"go": "wf_br_e"}, {"act": "warm", "at": "wf_fire_w", "face": Vector2(-196.0, 74.0), "t": [20.0, 30.0]}, {"go": "wf_br_m"}],
		}},
	"wren": {"name": "Wren", "title": "Wren, the miller's girl", "when": "", "camp": "outpost",
		"rig": {"seed": 6606, "sex": "f", "age": "child", "garment": "dress", "apron": "linen", "hair": "braids", "r": "chalk",
			"cloth": Color(0.42, 0.34, 0.26), "cloth2": Color(0.36, 0.3, 0.24), "hair_c": Color(0.46, 0.3, 0.14),
			"skin": Color(0.86, 0.66, 0.5), "leather": Color(0.4, 0.25, 0.13)},
		"home": "wf_fire_s", "speed": 1.15, "fearless": true,
		"schedule": {"dusk": "play", "work": "play", "midnight": "fire", "late": "play"},
		"routines": {
			"play": [
				{"act": "chalk", "at": "wf_sq_n", "face": Vector2(-194.8, 71.0), "t": [6.0, 9.0]},
				{"act": "idle", "at": "wf_well", "face": Vector2(-191.0, 78.0), "t": [6.0, 9.0]},
				{"act": "watch", "at": "wf_smith_front", "face": Vector2(-173.4, 73.9), "t": [10.0, 14.0]},
				{"act": "chalk", "at": "wf_br_e", "face": Vector2(-192.4, 66.4), "t": [6.0, 9.0]},
			],
			"fire": [{"act": "warm", "at": "wf_fire_s", "face": Vector2(-196.0, 74.0), "t": [30.0, 45.0]}],
		}},
	"tolliver": {"name": "Tolliver", "title": "Old Tolliver, the Marches' engineer", "when": "", "camp": "outpost",
		"rig": {"seed": 6707, "sex": "m", "age": "old", "garment": "coat", "hat": "brim", "hair": "wild", "beard": "long", "r": "staff", "girth": 0.94,
			"cloth": Color(0.3, 0.3, 0.26), "cloth2": Color(0.28, 0.25, 0.22), "hair_c": Color(0.72, 0.68, 0.6),
			"skin": Color(0.74, 0.54, 0.4), "leather": Color(0.34, 0.22, 0.12)},
		"home": "wf_stall", "speed": 0.8, "fearless": true,
		"schedule": {"dusk": "tinker", "work": "tinker", "midnight": "fire", "late": "tinker"},
		"routines": {
			"tinker": [
				{"act": "read", "at": "wf_stall", "face": Vector2(-185.0, 72.8), "t": [8.0, 12.0]},
				{"act": "look_up", "at": "wf_stall", "face": Vector2(-236.0, 170.0), "t": [8.0, 12.0]},
				{"act": "mourn", "at": "wf_stall", "face": Vector2(-214.0, -104.0), "t": [6.0, 9.0]},
			],
			"fire": [{"go": "wf_fire_n"}, {"act": "warm", "at": "wf_fire_n", "face": Vector2(-196.0, 74.0), "t": [20.0, 30.0]}, {"go": "wf_stall"}],
		}},
	"gwyn": {"name": "Gwyn", "title": "Gwyn, the ostler", "when": "", "camp": "outpost",
		"rig": {"seed": 6808, "sex": "f", "age": "teen", "garment": "shirt", "apron": "leather", "hat": "cap", "hair": "braids", "r": "crook", "girth": 1.0,
			"cloth": Color(0.36, 0.32, 0.24), "cloth2": Color(0.3, 0.26, 0.2), "hair_c": Color(0.28, 0.18, 0.1),
			"skin": Color(0.8, 0.58, 0.44), "leather": Color(0.38, 0.24, 0.13)},
		"home": "wf_stable", "speed": 1.0, "fearless": true,
		"schedule": {"dusk": "stable", "work": "stable", "midnight": "stable", "late": "stable"},
		"routines": {
			"stable": [
				{"act": "tend", "at": "wf_stable", "face": Vector2(-215.0, 79.0), "t": [8.0, 12.0]},
				{"act": "idle", "at": "wf_stable_in", "face": Vector2(-224.0, 82.0), "t": [6.0, 9.0]},
				{"act": "lean", "at": "wf_stable", "face": Vector2(-210.0, 78.0), "t": [6.0, 9.0]},
			],
		}},
}
