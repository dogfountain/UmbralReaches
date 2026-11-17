extends RefCounted
## The Far Reaches' towns' people (docs/far_reaches.md; the towns are core/world/realm/reach_towns.gd). Data only, in
## the village's own shapes, merged by the shared tables' `# --- the towns ---` blocks (village.gd cast and walks,
## village_talk_db.gd CONV, village_shop.gd MERCHANTS / GOODS). Each town is its own island of the walking network;
## the boards over Reedholm's meres are decks the network walks on (reach_towns.gd decks()). They are camped out (they
## do not run for Hearthward's Keg; Lastlight has its own walls and watch). Voices stay babble (NPC voices).
##   Reedholm    Aud Corle (the reed-wife, who keeps the lamp book), Hobb Wade (eels), Siany (the jetty's lamps),
##               Gorse (the smokehouse; sells), Ebba Sallow (boats; owes a pilgrim's sister one)
##   Fallowmere  Reeve Aldous Penn (the tithe barn), Hesper Lark (the farm), Cobb Lark (the fields), Dilly (the
##               scarecrows), Brother Wystan (the strips, and the dead in them)
##   Lastlight   Mother Vell (the Last Lamp inn; sells), Old Isolde (the lamp tower), Serjeant Coyle (the east watch),
##               Fenn (the road gate), Wat (the stable), Sister Maudlin (who kneels at the shut gate)
## House style (docs/LORE.md): terse, concrete, dark. Load by path.

## xz of every walk node (world metres): on the ground, or on a deck where reach_towns.gd laid one.
const NODES := {
	# --- Reedholm (the bank by the fire is raised clear of the water: reach_towns.gd BANKS) ----------------------------
	"rh_fire": Vector2(-317.4, 298.6), "rh_bank": Vector2(-314.6, 297.0), "rh_stall": Vector2(-312.8, 304.0),
	"rh_land_in": Vector2(-321.2, 302.4), "rh_land_w": Vector2(-325.0, 303.2), "rh_land_n": Vector2(-323.6, 300.4),
	"rh_b_step": Vector2(-315.6, 292.5), "rh_b_walk": Vector2(-320.4, 292.5), "rh_b_door": Vector2(-324.9, 292.5),
	"rh_smoke": Vector2(-321.6, 279.2), "rh_rack": Vector2(-321.2, 270.0), "rh_punt": Vector2(-316.4, 265.4),
	"rh_hall_step": Vector2(-315.6, 274.0), "rh_hall_walk": Vector2(-309.6, 274.0), "rh_hall_front": Vector2(-304.6, 274.0),
	"rh_hall_door": Vector2(-303.4, 274.0), "rh_hall_sw": Vector2(-304.2, 280.6), "rh_hall_se": Vector2(-300.0, 280.6),
	"rh_hall_nw": Vector2(-304.2, 267.4), "rh_hall_n": Vector2(-301.8, 267.4),
	"rh_link_h": Vector2(-300.0, 283.4), "rh_h_back": Vector2(-299.4, 286.0),
	"rh_h_step": Vector2(-315.2, 288.6), "rh_h_walk": Vector2(-309.4, 288.6), "rh_h_front": Vector2(-304.8, 288.6),
	"rh_link_l": Vector2(-301.8, 265.0), "rh_long_front": Vector2(-301.8, 262.6), "rh_long_door": Vector2(-301.8, 260.6),
	"rh_long_mid": Vector2(-301.8, 257.4), "rh_loft": Vector2(-301.9, 254.2), "rh_long_walk": Vector2(-308.0, 257.4),
	"rh_long_step": Vector2(-317.2, 257.4),
	# --- Fallowmere -----------------------------------------------------------------------------------------------
	"fm_fire": Vector2(-148.2, 294.4), "fm_green": Vector2(-143.4, 293.6), "fm_bench": Vector2(-143.7, 290.2),
	"fm_cot_a": Vector2(-137.4, 292.6), "fm_well": Vector2(-140.0, 297.4), "fm_junction": Vector2(-151.6, 297.6),
	"fm_barn_front": Vector2(-178.0, 295.4), "fm_barn_porch": Vector2(-178.0, 291.2), "fm_barn_w": Vector2(-186.4, 295.0),
	"fm_rick": Vector2(-186.0, 302.4), "fm_garden": Vector2(-175.6, 302.8), "fm_house_door": Vector2(-169.8, 303.6),
	"fm_house_nw": Vector2(-182.0, 305.4), "fm_house_w": Vector2(-182.6, 311.0), "fm_wood": Vector2(-180.6, 319.6),
	"fm_fold": Vector2(-183.0, 313.0), "fm_gate_n": Vector2(-150.0, 320.0), "fm_field": Vector2(-150.0, 326.4),
	"fm_strips": Vector2(-146.4, 334.4), "fm_gap_s": Vector2(-126.0, 339.6), "fm_gap_n": Vector2(-126.0, 344.4),
	"fm_scare": Vector2(-120.6, 348.0), "fm_road_e": Vector2(-128.0, 307.0), "fm_cot_b": Vector2(-126.6, 314.8),
	# --- Lastlight ------------------------------------------------------------------------------------------------
	"ll_fire": Vector2(316.4, 58.2), "ll_yard": Vector2(321.0, 58.6), "ll_inn_door": Vector2(328.0, 51.0),
	"ll_inn_in": Vector2(328.0, 48.2), "ll_well": Vector2(325.0, 60.8), "ll_road_mid": Vector2(332.0, 64.8),
	"ll_tower": Vector2(347.0, 50.4), "ll_tower_s": Vector2(347.4, 55.0), "ll_shrine": Vector2(348.8, 55.6),
	"ll_gate_in": Vector2(350.2, 62.8), "ll_watch_door": Vector2(341.4, 70.0), "ll_post": Vector2(332.4, 71.0),
	"ll_stable": Vector2(314.0, 69.6), "ll_stall_in": Vector2(309.6, 72.6), "ll_road_w": Vector2(306.0, 68.2),
	"ll_road_gate": Vector2(298.8, 69.6), "ll_store": Vector2(304.0, 44.0), "ll_wall_n": Vector2(318.0, 30.6),
}

const EDGES := [
	# Reedholm: the raised bank, the landing, each house's walk and steps, the links between the decks
	["rh_fire", "rh_bank"], ["rh_fire", "rh_land_in"], ["rh_land_in", "rh_land_n"], ["rh_land_n", "rh_land_w"], ["rh_land_in", "rh_land_w"],
	["rh_bank", "rh_stall"], ["rh_bank", "rh_b_step"], ["rh_b_step", "rh_b_walk"], ["rh_b_walk", "rh_b_door"],
	["rh_b_step", "rh_h_step"], ["rh_h_step", "rh_h_walk"], ["rh_h_walk", "rh_h_front"],
	["rh_h_step", "rh_smoke"], ["rh_smoke", "rh_hall_step"], ["rh_hall_step", "rh_hall_walk"], ["rh_hall_walk", "rh_hall_front"],
	["rh_hall_front", "rh_hall_door"], ["rh_hall_front", "rh_hall_sw"], ["rh_hall_sw", "rh_hall_se"], ["rh_hall_se", "rh_link_h"],
	["rh_link_h", "rh_h_back"], ["rh_hall_front", "rh_hall_nw"], ["rh_hall_nw", "rh_hall_n"], ["rh_hall_n", "rh_link_l"],
	["rh_link_l", "rh_long_front"], ["rh_long_front", "rh_long_door"], ["rh_long_door", "rh_long_mid"], ["rh_long_mid", "rh_loft"],
	["rh_long_mid", "rh_long_walk"], ["rh_long_walk", "rh_long_step"], ["rh_long_step", "rh_rack"], ["rh_rack", "rh_hall_step"],
	["rh_long_step", "rh_punt"], ["rh_punt", "rh_rack"],
	# Fallowmere: the green, the barn, the farm, the fold and the fields (through the gaps the open gates leave)
	["fm_fire", "fm_green"], ["fm_green", "fm_bench"], ["fm_green", "fm_cot_a"], ["fm_green", "fm_well"], ["fm_well", "fm_road_e"],
	["fm_road_e", "fm_cot_b"], ["fm_fire", "fm_junction"], ["fm_junction", "fm_barn_front"], ["fm_barn_front", "fm_barn_porch"],
	["fm_barn_front", "fm_barn_w"], ["fm_barn_w", "fm_rick"], ["fm_barn_front", "fm_garden"], ["fm_garden", "fm_house_door"],
	["fm_house_door", "fm_junction"], ["fm_rick", "fm_fold"], ["fm_fold", "fm_wood"], ["fm_wood", "fm_house_w"],
	["fm_house_w", "fm_house_nw"], ["fm_house_nw", "fm_garden"], ["fm_junction", "fm_gate_n"], ["fm_gate_n", "fm_field"],
	["fm_field", "fm_strips"], ["fm_strips", "fm_gap_s"], ["fm_gap_s", "fm_gap_n"], ["fm_gap_n", "fm_scare"],
	# Lastlight: the yard, the street to the gates, the stable, the watch, the tower, the shrine
	["ll_fire", "ll_yard"], ["ll_yard", "ll_inn_door"], ["ll_inn_door", "ll_inn_in"], ["ll_yard", "ll_well"], ["ll_well", "ll_road_mid"],
	["ll_inn_door", "ll_road_mid"], ["ll_fire", "ll_road_w"], ["ll_road_w", "ll_road_gate"], ["ll_road_w", "ll_stable"],
	["ll_stable", "ll_stall_in"], ["ll_stable", "ll_well"], ["ll_road_w", "ll_store"], ["ll_store", "ll_wall_n"],
	["ll_road_mid", "ll_post"], ["ll_post", "ll_watch_door"], ["ll_road_mid", "ll_gate_in"], ["ll_gate_in", "ll_shrine"],
	["ll_road_mid", "ll_tower_s"], ["ll_tower_s", "ll_tower"], ["ll_tower_s", "ll_shrine"],
]


static func _rig(seed: int, sex: String, age: String, o: Dictionary) -> Dictionary:
	var d := {"seed": seed, "sex": sex, "age": age, "garment": "shirt", "hair": "short", "girth": 1.0,
		"cloth": Color(0.36, 0.32, 0.26), "cloth2": Color(0.3, 0.27, 0.22), "hair_c": Color(0.3, 0.2, 0.12),
		"skin": Color(0.78, 0.57, 0.43), "leather": Color(0.38, 0.24, 0.13)}
	d.merge(o, true)
	return d


const CAST_SRC := {
	# --- Reedholm -------------------------------------------------------------------------------------------------
	"corle": {"name": "Corle", "title": "Aud Corle, the reed-wife", "rig": [7601, "f", "old", {"garment": "dress", "shawl": true, "hood": true, "hair": "bun",
			"girth": 1.06, "cloth": Color(0.26, 0.28, 0.27), "cloth2": Color(0.33, 0.3, 0.25), "hair_c": Color(0.76, 0.72, 0.64), "skin": Color(0.74, 0.55, 0.42)}],
		"home": "rh_hall_front", "speed": 0.7,
		"schedule": {"dusk": "nets", "work": "nets", "midnight": "book", "late": "watch"},
		"routines": {
			"nets": [{"act": "tend", "at": "rh_hall_front", "face": Vector2(-312.0, 274.0), "t": [14.0, 20.0]},
				{"act": "look_up", "at": "rh_hall_sw", "face": Vector2(-340.0, 360.0), "t": [5.0, 8.0]}, {"go": "rh_hall_front"}],
			"book": [{"hide": "rh_hall_door", "t": [24.0, 36.0]}, {"act": "read", "at": "rh_hall_front", "face": Vector2(-302.0, 274.0), "t": [8.0, 12.0]}],
			"watch": [{"go": "rh_hall_walk"}, {"act": "watch", "at": "rh_hall_walk", "face": Vector2(-322.0, 302.0), "t": [10.0, 14.0]}, {"go": "rh_hall_front"}],
		}},
	"hobb": {"name": "Hobb", "title": "Hobb Wade, the eel-man", "rig": [7602, "m", "adult", {"garment": "coat", "hat": "cap", "beard": "short", "r": "pole",
			"girth": 1.12, "cloth": Color(0.3, 0.3, 0.26), "cloth2": Color(0.26, 0.24, 0.2), "hair_c": Color(0.24, 0.16, 0.1)}],
		"home": "rh_long_door", "speed": 0.95,
		"schedule": {"dusk": "traps", "work": "traps", "midnight": "home", "late": "traps"},
		"routines": {
			"traps": [{"go": "rh_long_walk"}, {"act": "kneel", "at": "rh_punt", "face": Vector2(-313.6, 266.0), "t": [10.0, 14.0]},
				{"act": "tend", "at": "rh_rack", "face": Vector2(-325.0, 268.0), "t": [10.0, 14.0]},
				{"act": "kneel", "at": "rh_land_w", "face": Vector2(-328.0, 303.0), "t": [12.0, 16.0]},
				{"act": "look_up", "at": "rh_land_w", "face": Vector2(-298.0, 326.0), "t": [6.0, 9.0]}, {"go": "rh_long_door"}],
			"home": [{"hide": "rh_long_door", "t": [30.0, 45.0]}, {"act": "lean", "at": "rh_long_front", "face": Vector2(-310.0, 262.0), "t": [6.0, 9.0]}],
		}},
	"siany": {"name": "Siany", "title": "Siany, who keeps the jetty's lamps", "rig": [7603, "f", "teen", {"garment": "dress", "apron": "linen", "hair": "braids",
			"l": "lantern", "cloth": Color(0.34, 0.33, 0.3), "cloth2": Color(0.4, 0.34, 0.26), "hair_c": Color(0.42, 0.28, 0.14), "skin": Color(0.84, 0.64, 0.5)}],
		"home": "rh_land_in", "speed": 1.05,
		"schedule": {"dusk": "lamps", "work": "lamps", "midnight": "fire", "late": "lamps"},
		"routines": {
			"lamps": [{"act": "tend", "at": "rh_land_n", "face": Vector2(-320.5, 299.6), "t": [8.0, 12.0]},
				{"act": "look_up", "at": "rh_land_w", "face": Vector2(-345.0, 330.0), "t": [8.0, 12.0]},
				{"act": "idle", "at": "rh_land_in", "face": Vector2(-316.0, 302.0), "t": [5.0, 8.0]},
				{"act": "watch", "at": "rh_bank", "face": Vector2(-292.0, 304.0), "t": [8.0, 12.0]}],
			"fire": [{"act": "warm", "at": "rh_fire", "face": Vector2(-316.0, 302.0), "t": [24.0, 36.0]}],
		}},
	"gorse": {"name": "Gorse", "title": "Gorse, the smoker", "trader": true, "rig": [7604, "m", "old", {"garment": "shirt", "apron": "leather", "hair": "wild",
			"beard": "long", "girth": 0.98, "cloth": Color(0.32, 0.28, 0.24), "cloth2": Color(0.24, 0.2, 0.16), "hair_c": Color(0.66, 0.62, 0.56), "skin": Color(0.7, 0.5, 0.38)}],
		"home": "rh_stall", "speed": 0.8,
		"schedule": {"dusk": "sell", "work": "smoke", "midnight": "sell", "late": "smoke"},
		"routines": {
			"sell": [{"act": "sell", "at": "rh_stall", "face": Vector2(-311.4, 306.2), "t": [20.0, 30.0]}, {"act": "idle", "at": "rh_stall", "face": Vector2(-316.0, 302.0), "t": [6.0, 9.0]}],
			"smoke": [{"go": "rh_smoke"}, {"act": "tend", "at": "rh_smoke", "face": Vector2(-325.5, 279.0), "t": [12.0, 18.0]},
				{"act": "chop", "at": "rh_smoke", "face": Vector2(-321.2, 276.6), "t": [10.0, 14.0]}, {"go": "rh_stall"},
				{"act": "sell", "at": "rh_stall", "face": Vector2(-311.4, 306.2), "t": [14.0, 20.0]}],
		}},
	"ebba": {"name": "Ebba", "title": "Ebba Sallow, the boatwright", "rig": [7605, "f", "adult", {"garment": "shirt", "apron": "leather", "hat": "kerchief", "hair": "bun",
			"girth": 1.08, "cloth": Color(0.36, 0.3, 0.24), "cloth2": Color(0.3, 0.27, 0.22), "hair_c": Color(0.22, 0.14, 0.08)}],
		"home": "rh_punt", "speed": 0.9,
		"schedule": {"dusk": "boats", "work": "boats", "midnight": "fire", "late": "boats"},
		"routines": {
			"boats": [{"act": "kneel", "at": "rh_punt", "face": Vector2(-313.6, 266.0), "t": [16.0, 22.0]},
				{"act": "chop", "at": "rh_punt", "face": Vector2(-314.6, 263.6), "t": [10.0, 14.0]},
				{"act": "lean", "at": "rh_long_step", "face": Vector2(-299.0, 257.0), "t": [6.0, 9.0]}],
			"fire": [{"go": "rh_hall_step"}, {"act": "warm", "at": "rh_fire", "face": Vector2(-316.0, 302.0), "t": [20.0, 30.0]}, {"go": "rh_punt"}],
		}},
	# --- Fallowmere -----------------------------------------------------------------------------------------------
	"penn": {"name": "Penn", "title": "Reeve Aldous Penn, of the tithe barn", "rig": [7701, "m", "old", {"garment": "coat", "hat": "brim", "beard": "short", "r": "staff",
			"girth": 1.04, "cloth": Color(0.3, 0.28, 0.24), "cloth2": Color(0.36, 0.32, 0.26), "hair_c": Color(0.72, 0.68, 0.6), "skin": Color(0.76, 0.56, 0.42)}],
		"home": "fm_barn_porch", "speed": 0.75,
		"schedule": {"dusk": "tally", "work": "tally", "midnight": "strips", "late": "tally"},
		"routines": {
			"tally": [{"act": "read", "at": "fm_barn_porch", "face": Vector2(-178.0, 288.0), "t": [14.0, 20.0]},
				{"act": "look_up", "at": "fm_barn_front", "face": Vector2(-178.0, 270.0), "t": [5.0, 8.0]},
				{"act": "idle", "at": "fm_rick", "face": Vector2(-190.0, 306.5), "t": [6.0, 9.0]}, {"go": "fm_barn_porch"}],
			"strips": [{"go": "fm_gate_n"}, {"act": "mourn", "at": "fm_strips", "face": Vector2(-146.0, 340.0), "t": [12.0, 18.0]}, {"go": "fm_barn_porch"}],
		}},
	"hesper": {"name": "Hesper", "title": "Hesper Lark, the farm's goodwife", "rig": [7702, "f", "adult", {"garment": "dress", "apron": "linen", "hat": "kerchief", "hair": "bun",
			"girth": 1.14, "cloth": Color(0.36, 0.3, 0.26), "cloth2": Color(0.44, 0.4, 0.34), "hair_c": Color(0.34, 0.22, 0.12), "skin": Color(0.82, 0.6, 0.46)}],
		"home": "fm_house_door", "speed": 0.9,
		"schedule": {"dusk": "chores", "work": "chores", "midnight": "fire", "late": "chores"},
		"routines": {
			"chores": [{"act": "draw_water", "at": "fm_well", "face": Vector2(-140.0, 294.6), "t": [10.0, 14.0]},
				{"act": "garden", "at": "fm_garden", "face": Vector2(-177.0, 304.0), "t": [14.0, 20.0]},
				{"hide": "fm_house_door", "t": [16.0, 24.0]}],
			"fire": [{"act": "sit", "at": "fm_bench", "face": Vector2(-146.0, 292.0), "t": [24.0, 34.0], "seat": 0.5}],
		}},
	"cobb": {"name": "Cobb", "title": "Cobb Lark, who works the fields", "rig": [7703, "m", "adult", {"garment": "shirt", "hat": "cap", "beard": "short", "r": "spade",
			"girth": 1.2, "cloth": Color(0.4, 0.36, 0.28), "cloth2": Color(0.32, 0.28, 0.22), "hair_c": Color(0.42, 0.3, 0.18), "skin": Color(0.74, 0.52, 0.38)}],
		"home": "fm_field", "speed": 0.95,
		"schedule": {"dusk": "field", "work": "field", "midnight": "wood", "late": "field"},
		"routines": {
			"field": [{"act": "dig", "at": "fm_field", "face": Vector2(-156.0, 330.0), "t": [16.0, 22.0]},
				{"act": "tend", "at": "fm_fold", "face": Vector2(-190.0, 320.0), "t": [10.0, 14.0]},
				{"act": "lean", "at": "fm_gate_n", "face": Vector2(-150.0, 340.0), "t": [6.0, 9.0]}],
			"wood": [{"act": "chop", "at": "fm_wood", "face": Vector2(-178.0, 320.4), "t": [16.0, 22.0]}, {"act": "warm", "at": "fm_fire", "face": Vector2(-146.0, 292.0), "t": [10.0, 14.0]}],
		}},
	"dilly": {"name": "Dilly", "title": "Dilly, who dresses the scarecrows", "rig": [7704, "f", "child", {"garment": "dress", "apron": "linen", "hair": "braids", "r": "chalk",
			"cloth": Color(0.42, 0.32, 0.24), "cloth2": Color(0.36, 0.3, 0.24), "hair_c": Color(0.58, 0.42, 0.2), "skin": Color(0.86, 0.66, 0.5)}],
		"home": "fm_green", "speed": 1.15,
		"schedule": {"dusk": "play", "work": "scarecrows", "midnight": "fire", "late": "play"},
		"routines": {
			"play": [{"act": "chalk", "at": "fm_green", "face": Vector2(-142.6, 287.6), "t": [8.0, 12.0]},
				{"act": "idle", "at": "fm_well", "face": Vector2(-140.0, 294.6), "t": [5.0, 8.0]},
				{"act": "watch", "at": "fm_barn_front", "face": Vector2(-178.0, 290.0), "t": [8.0, 12.0]}],
			"scarecrows": [{"go": "fm_road_e"}, {"act": "tend", "at": "fm_scare", "face": Vector2(-122.0, 350.0), "t": [12.0, 18.0]},
				{"act": "look_up", "at": "fm_scare", "face": Vector2(-118.0, 380.0), "t": [5.0, 8.0]}, {"go": "fm_green"}],
			"fire": [{"act": "warm", "at": "fm_fire", "face": Vector2(-146.0, 292.0), "t": [30.0, 45.0]}],
		}},
	"wystan": {"name": "Wystan", "title": "Brother Wystan, who buries the strips", "rig": [7705, "m", "old", {"garment": "robe", "hood": true, "hair": "short", "r": "spade",
			"girth": 0.94, "cloth": Color(0.24, 0.23, 0.22), "cloth2": Color(0.3, 0.27, 0.23), "hair_c": Color(0.6, 0.56, 0.5), "skin": Color(0.72, 0.53, 0.4)}],
		"home": "fm_strips", "speed": 0.7,
		"schedule": {"dusk": "graves", "work": "graves", "midnight": "fire", "late": "graves"},
		"routines": {
			"graves": [{"act": "dig", "at": "fm_strips", "face": Vector2(-146.0, 338.0), "t": [14.0, 20.0]},
				{"act": "kneel", "at": "fm_strips", "face": Vector2(-146.0, 338.0), "t": [12.0, 18.0]},
				{"act": "mourn", "at": "fm_field", "face": Vector2(-120.0, 356.0), "t": [6.0, 9.0]}],
			"fire": [{"go": "fm_gate_n"}, {"act": "warm", "at": "fm_fire", "face": Vector2(-146.0, 292.0), "t": [20.0, 30.0]}, {"go": "fm_strips"}],
		}},
	# --- Lastlight ------------------------------------------------------------------------------------------------
	"vell": {"name": "Vell", "title": "Mother Vell, keeper of the Last Lamp", "trader": true, "rig": [7801, "f", "adult", {"garment": "dress", "apron": "linen", "hat": "kerchief",
			"hair": "bun", "girth": 1.2, "cloth": Color(0.34, 0.26, 0.22), "cloth2": Color(0.42, 0.38, 0.32), "hair_c": Color(0.28, 0.18, 0.1), "skin": Color(0.8, 0.58, 0.44)}],
		"home": "ll_inn_door", "speed": 0.9,
		"schedule": {"dusk": "keep", "work": "keep", "midnight": "keep", "late": "keep"},
		"routines": {
			"keep": [{"act": "sell", "at": "ll_inn_door", "face": Vector2(322.0, 56.0), "t": [16.0, 24.0]},
				{"act": "idle", "at": "ll_yard", "face": Vector2(318.0, 55.5), "t": [5.0, 8.0]}, {"go": "ll_inn_door"},
				{"hide": "ll_inn_in", "t": [14.0, 20.0]}],
		}},
	"isolde": {"name": "Isolde", "title": "Old Isolde, the lamp-keeper", "rig": [7802, "f", "old", {"garment": "robe", "hood": true, "hair": "long", "l": "lantern",
			"girth": 0.92, "cloth": Color(0.22, 0.24, 0.26), "cloth2": Color(0.32, 0.28, 0.24), "hair_c": Color(0.84, 0.82, 0.78), "skin": Color(0.76, 0.56, 0.44)}],
		"home": "ll_tower", "speed": 0.7,
		"schedule": {"dusk": "lamp", "work": "lamp", "midnight": "round", "late": "lamp"},
		"routines": {
			"lamp": [{"act": "look_up", "at": "ll_tower", "face": Vector2(347.0, 44.0), "t": [8.0, 12.0]},
				{"hide": "ll_tower", "t": [24.0, 36.0]}, {"act": "tend", "at": "ll_tower", "face": Vector2(347.0, 46.0), "t": [8.0, 12.0]}],
			"round": [{"go": "ll_gate_in"}, {"act": "watch", "at": "ll_gate_in", "face": Vector2(370.0, 62.0), "t": [8.0, 12.0]},
				{"act": "idle", "at": "ll_tower_s", "face": Vector2(318.5, 55.5), "t": [6.0, 9.0]}, {"go": "ll_tower"}],
		}},
	"coyle": {"name": "Coyle", "title": "Serjeant Coyle, of the east watch", "rig": [7803, "m", "adult", {"garment": "coat", "hood": true, "beard": "short", "r": "sword",
			"girth": 1.1, "cloth": Color(0.28, 0.28, 0.27), "cloth2": Color(0.32, 0.26, 0.2), "hair_c": Color(0.32, 0.26, 0.2), "skin": Color(0.72, 0.52, 0.38)}],
		"home": "ll_gate_in", "speed": 1.0, "fearless": true,
		"schedule": {"dusk": "post", "work": "round", "midnight": "post", "late": "round"},
		"routines": {
			"post": [{"act": "watch", "at": "ll_gate_in", "face": Vector2(370.0, 62.0), "t": [12.0, 18.0]},
				{"act": "idle", "at": "ll_gate_in", "face": Vector2(320.0, 62.0), "t": [5.0, 8.0]}],
			"round": [{"go": "ll_road_mid"}, {"act": "lean", "at": "ll_post", "face": Vector2(332.4, 75.0), "t": [8.0, 12.0]},
				{"go": "ll_watch_door"}, {"act": "idle", "at": "ll_watch_door", "face": Vector2(341.4, 75.0), "t": [6.0, 9.0]}, {"go": "ll_gate_in"}],
		}},
	"fenn": {"name": "Fenn", "title": "Fenn, on the road gate", "rig": [7804, "m", "teen", {"garment": "coat", "hat": "cap", "hair": "fringe", "r": "sword",
			"cloth": Color(0.3, 0.3, 0.28), "cloth2": Color(0.28, 0.24, 0.2), "hair_c": Color(0.5, 0.36, 0.2), "skin": Color(0.82, 0.62, 0.48)}],
		"home": "ll_road_gate", "speed": 1.05, "fearless": true,
		"schedule": {"dusk": "gate", "work": "gate", "midnight": "round", "late": "gate"},
		"routines": {
			"gate": [{"act": "watch", "at": "ll_road_gate", "face": Vector2(270.0, 72.0), "t": [12.0, 18.0]},
				{"act": "lean", "at": "ll_road_gate", "face": Vector2(290.0, 76.0), "t": [6.0, 9.0]}],
			"round": [{"go": "ll_store"}, {"act": "look_up", "at": "ll_wall_n", "face": Vector2(318.0, 20.0), "t": [5.0, 8.0]},
				{"act": "warm", "at": "ll_fire", "face": Vector2(318.5, 55.5), "t": [10.0, 14.0]}, {"go": "ll_road_gate"}],
		}},
	"wat": {"name": "Wat", "title": "Wat, the ostler", "rig": [7805, "m", "adult", {"garment": "shirt", "apron": "leather", "hat": "cap", "beard": "short", "r": "crook",
			"girth": 1.06, "cloth": Color(0.38, 0.32, 0.24), "cloth2": Color(0.3, 0.26, 0.2), "hair_c": Color(0.2, 0.13, 0.08), "skin": Color(0.7, 0.5, 0.36)}],
		"home": "ll_stable", "speed": 0.95,
		"schedule": {"dusk": "stable", "work": "stable", "midnight": "stable", "late": "stable"},
		"routines": {
			"stable": [{"act": "tend", "at": "ll_stall_in", "face": Vector2(309.6, 75.6), "t": [12.0, 16.0]},
				{"act": "idle", "at": "ll_stable", "face": Vector2(307.0, 69.8), "t": [6.0, 9.0]},
				{"act": "draw_water", "at": "ll_well", "face": Vector2(325.0, 58.2), "t": [8.0, 12.0]}, {"go": "ll_stable"}],
		}},
	"maudlin": {"name": "Maudlin", "title": "Sister Maudlin, who waits at the gate", "rig": [7806, "f", "old", {"garment": "robe", "hood": true, "hair": "bun", "r": "candle",
			"girth": 0.96, "cloth": Color(0.3, 0.29, 0.27), "cloth2": Color(0.36, 0.33, 0.28), "hair_c": Color(0.7, 0.66, 0.6), "skin": Color(0.78, 0.6, 0.46)}],
		"home": "ll_shrine", "speed": 0.65,
		"schedule": {"dusk": "vigil", "work": "vigil", "midnight": "fire", "late": "vigil"},
		"routines": {
			"vigil": [{"act": "kneel", "at": "ll_shrine", "face": Vector2(352.0, 55.6), "t": [24.0, 36.0]},
				{"act": "look_up", "at": "ll_gate_in", "face": Vector2(360.0, 62.8), "t": [8.0, 12.0]}, {"go": "ll_shrine"}],
			"fire": [{"act": "warm", "at": "ll_fire", "face": Vector2(318.5, 55.5), "t": [24.0, 34.0]}, {"go": "ll_shrine"}],
		}},
}


static var _cast: Dictionary = {}


## The cast in the village's shape (rigs expanded; every one camped out and present from the first night).
static func cast() -> Dictionary:
	if not _cast.is_empty():
		return _cast
	for id: String in CAST_SRC:
		var d: Dictionary = (CAST_SRC[id] as Dictionary).duplicate(true)
		var r: Array = d.rig
		d["rig"] = _rig(int(r[0]), String(r[1]), String(r[2]), r[3])
		d["when"] = ""
		d["camp"] = "outpost"
		d["fearless"] = true
		_cast[id] = d
	return _cast


# --- what they say (village_talk_db.gd CONV's shape) ---------------------------------------------------------------

const CONV := {
	"corle": {"name": "Aud Corle", "start": [["!met:corle", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Wipe your feet on the board. Not for the mud. For whatever you walked through to get here.", "next": "meet2"},
		"meet2": {"say": "Aud Corle. I keep the lamp book, and the lamp book keeps Reedholm. Thirty lamps at the jetty every night since the Night. We've not missed one.", "do": "met:corle", "next": "hub"},
		"hub": {"say_if": [
			["qd:wr_relief,qp:wr_relief:salute,qc:wr_relief:name", "Garrick Ness. I wrote it in the last pages, the way I write a boat home, and then I shut the book. A boy of the ford. His mother is in the first pages. I did not know it till I wrote it."],
			["qd:wr_relief,qp:wr_relief:salute", "He sat down, you say. I wrote 'the Sentry' where the name should go. A watch with no name is still a watch. I left room beside it."],
			["qd:wr_relief,qp:wr_relief:keep", "You kept it on. I can see your lantern from the gallery, on a clear night, a bead on the fell. Somebody will have to relieve you. I have started a page for that."],
			["qat:wr_relief:0|qat:wr_relief:1|qat:wr_relief:2|qat:wr_relief:3", "The cairn is on the fell, by the track's head under the keep. Read what he left. Then keep the hours he kept, to the grey. Somebody has to, or it was only a man standing in the cold."],
			["qp:rh_lamps:home,qd:rh_lamps,!qd:wr_stand_down", "Tam's lamp burns at the jetty's end. The book says brought home. The thirty-first. I look at it more than I count the others."],
			["qp:rh_lamps:lost,qd:rh_lamps,!qd:wr_stand_down", "Tam's lamp hangs dark at the jetty's end. The book says lost, and found. I did not ask you to write it. I am glad it was said."],
			["qd:rh_lamps,!qd:wr_stand_down", "The book has a line in it it never had before. Boats not home by dark: none. I wrote it twice, to see it."],
			["qat:rh_lamps:3", "The stones, then. Go by the east reeds, not the channel. Don't look at the herons when you take it. They look back."],
			["qat:rh_lamps:1|qat:rh_lamps:2", "Their wakes go out of the landing and end at the lowest stone. Follow them, and read what the stones kept. Tam's lamp is among them, and so is the line I did not write."],
			["qat:rh_lamps:4", "Siany will hang it. She knows what a lamp is for. Tell her whether he's home. It is yours to say, and then I write it."],
			["qd:wr_stand_down", "The courier's line is closed. Delivered, or as near as makes no difference. I don't ask what became of the order. I only ask that the Greyfell stays kept."],
			["q:wr_stand_down", "North by the barrow road, then the Lanternwood's ring, then the shrine under the keep. The slip says the ring, not the wood's edge. The edge is hunted."],
			["", "Eels, pike, reed for the roofs. We'd want for nothing, if wanting was all it took."],
		], "choices": [
			{"text": "Why the lamps?", "to": "lamps", "once": true},
			{"text": "What are the heron stones?", "to": "herons", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"lamps": {"say": "So the boats can find the jetty. And so the jetty can see what comes in on the boats. One came in the winter of the Night with nobody rowing it. It had a lamp. Lit. We took it in. You don't leave a lit lamp on the water.", "next": "hub"},
		"herons": {"say": "Seven stones in the south mere, a bird cut on each one. Old as the river. When a heron's gone off its stone in the morning, a boat's gone with it. My three went the night the fourth stone was bare.", "next": "hub"},
	}},
	"hobb": {"name": "Hobb Wade", "start": [["!met:hobb", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Mind the traps. They bite worse than what's in them.", "next": "meet2"},
		"meet2": {"say": "Hobb. Eels. That's the whole of me, near enough. My brother Tam was the clever one. He's in the book now, under the line for boats not home.", "do": "met:hobb", "next": "hub"},
		"hub": {"say_if": [
			["qp:rh_lamps:home,qd:rh_lamps", "Siany lit it at the jetty. Home, Aud wrote. I stood on the landing and watched it burn and did not row out, for the first time since. That is what home is, I think."],
			["qp:rh_lamps:lost,qd:rh_lamps", "Lost, Aud wrote. It hangs dark on the jetty. Good. A man should have his lamp, and a lamp that isn't lit can't be mistaken for him."],
			["qd:rh_lamps", "You brought his lamp back. I hung it in the loft. It doesn't light. I don't want it to."],
			["qp:wr_fourth_stone:tam,qd:wr_fourth_stone", "There's an oar across the lowest slab. Not mine. I row round it. If the bird takes it, it takes it. It's his."],
			["qp:wr_fourth_stone:hobb,qd:wr_fourth_stone", "I took the oar out to the stone myself and came home with the one. It's the bird's. Tam would have laughed at me for fetching it."],
			["qd:wr_fourth_stone", "The fourth bird's on its stone. I looked twice. I took an oar out to it, and I came home with one."],
			["qat:wr_fourth_stone:1|qat:wr_fourth_stone:2", "Eel, then net, then lamp, then oar. Aud's old book has the verse by heart and the herons have it better. Touch them as they follow. Then wait. The fourth bird comes in its own time."],
			["q:wr_fourth_stone", "The verse is round the lowest slab's foot. The herons answer in the order it gives. A wrong one turns its head away. They're not cruel. They've had a long time to wait for the right order."],
			["", "Eels don't care about the sky. They come up the Sorrow same as ever. More of them, if anything. They've been eating well."],
		], "choices": [
			{"text": "What happened to Tam?", "to": "tam", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"tam": {"say": "Went out past the stones for the big pike. Said the herons were just birds cut in rock. They are. That's not the part he should have worried about.", "next": "hub"},
	}},
	"siany": {"name": "Siany", "start": [["!met:siany", "meet"], ["qat:rh_lamps:4", "lamp"], ["", "hub"]], "nodes": {
		"lamp": {"say": "That's Tam's. I know the hood. Give it here. ...The wick's dry, nine winters. I could light it from mine. Or I could hang it as it is, and the book can say what it likes. It's your say. You found it.", "choices": [
			{"text": "Light it. He's home.", "to": "lamp_home", "do": "qp:rh_lamps:home,qa:rh_lamps"},
			{"text": "Hang it dark. He's lost, and found.", "to": "lamp_lost", "do": "qp:rh_lamps:lost,qa:rh_lamps"},
		]},
		"lamp_home": {"say": "There. Thirty-one. I'll light it first, every dusk, and not say why.", "next": "hub"},
		"lamp_lost": {"say": "Dark, then. It'll hang with the others. A lamp doesn't have to burn to be counted.", "next": "hub"},
		"meet": {"say": "Don't stand between me and the jetty. I count them lit and I count them out, and you're making me lose my place.", "next": "meet2"},
		"meet2": {"say": "Siany. The lamps are mine since my mam's knees went. Thirty. I could light them blind. Some nights I nearly have to.", "do": "met:siany", "next": "hub"},
		"hub": {"say_if": [
			["qp:rh_lamps:home,qd:rh_lamps,!qd:wr_kings_lamp", "Thirty-one at the jetty, and Tam's the last, burning. I light it first. Don't tell Hobb. He knows."],
			["qp:rh_lamps:lost,qd:rh_lamps,!qd:wr_kings_lamp", "Thirty lit and Tam's hung dark beside them. It's the only one I never trim. Somebody should. It's not mine to."],
			["qd:wr_kings_lamp", "The thirty-first burns at the jetty's end. I light it first. I don't know who I'm lighting it for. I think that is the whole point of it."],
			["q:wr_kings_lamp", "Up the barrow road, and don't stop to look at the stones. A lamp doesn't care what you found. It only cares how long you took."],
			["", "If one goes out, you go and light it. You don't wait for morning. Morning's when you find out why you should have."],
		], "choices": [
			{"text": "Does anything come up the river?", "to": "river", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"river": {"say": "Mist. Eels. Boats, some nights, with nobody in them. The lamp on the crook's the first they see. I make sure it's lit before anything else is.", "next": "hub"},
	}},
	"gorse": {"name": "Gorse", "start": [["!met:gorse", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "You smell that? That's oak and eel and forty years. Breathe it. It's the only thing here that's warm all night.", "next": "meet2"},
		"meet2": {"say": "Gorse. I smoke what Hobb brings and trade it to the carters for what they bring. Ash buys the same as bread, these days. I take ash.", "do": "met:gorse", "next": "hub"},
		"hub": {"say_if": [
			["", "The mere gives up odd things in the nets. I keep the ones that don't move."],
		], "choices": [
			{"text": "What are you selling?", "to": "shop", "do": "shop:gorse"},
			{"text": "Goodbye.", "to": ""},
		]},
		"shop": {"say": "Look all you like. Touch and you've bought it.", "next": "hub"},
	}},
	"ebba": {"name": "Ebba Sallow", "start": [["!met:ebba", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Hand me that. No, the other. You've never held an adze, have you. Put it down before it learns your name.", "next": "meet2"},
		"meet2": {"say": "Ebba Sallow. I build the punts and patch the decks. Every board you walked in on, I've had my hands on.", "do": "met:ebba", "next": "hub"},
		"hub": {"say_if": [
			["met:tansy", "A pilgrim on the road, you say? Old, looks back at the mountain every ten steps? That's Ansel Tansy. I owe his sister a boat. Tell him it's built. Tell him she never came for it."],
			["qd:wr_cold_light", "The caps are in the bows. Cold, and not a shadow under them. You won't see the boats from the shore. That's the idea."],
			["qd:wr_tansys_boat", "Alma Tansy's boat is in the mere with her name on it. I let it go as far as the first reed bed. Somebody will find it who is looking for it."],
			["q:wr_cold_light", "Wick goes round the ring where the caps grow. Put it down first, or it puts the light out of whatever you cut."],
			["", "A punt's two planks and a prayer. The prayer's the expensive part."],
		], "choices": [
			{"text": "Who owes who a boat?", "to": "boat", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"boat": {"say": "A woman called Tansy paid me for a boat the autumn before the Night. I built it. It's under the hall, dry, oiled every spring. She never came. Somebody will.", "next": "hub"},
	}},
	"penn": {"name": "Reeve Penn", "start": [["!met:penn", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Name and holding. No, I don't need it. I ask everyone. It's what a reeve is for.", "next": "meet2"},
		"meet2": {"say": "Aldous Penn, reeve of Fallowmere for the Order. The Order's gone up the mountain and not come down, and I still keep its barn. Somebody has to say what's owed.", "do": "met:penn", "next": "hub"},
		"hub": {"say_if": [
			["qd:ds_charcoal,qp:ds_charcoal:spare", "There's a lamp at the clamp in the Southwood every night, they say, and the basket on the scarp is full at dusk. I never see who. I think he keeps the beacons. I haven't gone to look. I'd rather he kept at it."],
			["qd:ds_charcoal,qp:ds_charcoal:take", "One night, and it was a great fire. You can see the black on the scarp from the barn. The stack in the Southwood doesn't smoke. I count it. I'd count it again."],
			["qat:ds_charcoal:0|qat:ds_charcoal:1|qat:ds_charcoal:2|qat:ds_charcoal:3", "Hob's Stack, off arches_way in the Southwood. Somebody keeps the clamp. Ask him for a coal or take the lot, but carry it lit to the Arches Beacon. And walk. A coal can't take a run."],
			["qp:fm_tithe:full,qd:fm_tithe", "I read my own line. Nine bushels, owed, to the far strips. I'd have struck it, and I'm glad you didn't let me. The porch keeps a lamp now. It's the first thing I see."],
			["qp:fm_tithe:strike,qd:fm_tithe", "You struck my line. I asked you not to, and I'm glad you did. I'll pay the nine bushels some other way. The roll's whole without it. It's not the same as whole."],
			["qd:fm_tithe", "The roll's whole. I read it out in the porch last night, every strip and every name in it. Nobody answered. That's as it should be."],
			["qat:fm_tithe:0", "Three tallies, in the drowned strips south. Notched sticks in clay pots. The things in the fields keep them now. Take them back."],
			["qat:fm_tithe:2", "Read the sticks on the board. All of them, if you like. I haven't. I know whose is the last one."],
			["qp:ds_unmade:turn,qd:ds_unmade", "He faces the road in Hale's coat. I go and look at him most dawns. I thought it would be worse. It's like being waved at by a man who's not coming back."],
			["qp:ds_unmade:burn,qd:ds_unmade", "You burned Hale's coat. I saw the smoke from the loft. I went through my pegs after, and I've the one coat. It's mine. It always was. Thank you for that."],
			["qd:ds_water_road", "Two fires on the scarp. I watched them till light. Nothing came, and nothing is less than I had. Tell the strips, I thought, and I did."],
			["q:ds_water_road", "The beacons stand over the hamlet and over the Arches, each in sight of the other. The keeper's log is at the castellum, at the water road's west end. The hound in the channel keeps the door."],
			["", "Half the strips are fallow. The other half we planted with what the Night left us. You'll have seen the markers."],
		], "choices": [
			{"text": "What does the barn hold now?", "to": "barn", "once": true},
			{"text": "Who are the scarecrows for?", "to": "crows", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"barn": {"say": "Seed corn, a cart, eleven winters of tally sticks and a roof I can't mend. The Order's tithe went up the road to the Stair. I count it out every night. It never comes back.", "next": "hub"},
		"crows": {"say": "Not for crows. There are no crows. Dilly dresses them so the fields look watched. Something in the far strips dressed one too, last month. In a reeve's coat. I've only the one coat.", "next": "hub"},
	}},
	"hesper": {"name": "Hesper Lark", "start": [["!met:hesper", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "If you're hungry, sit. If you're trouble, sit further off.", "next": "meet2"},
		"meet2": {"say": "Hesper Lark. That's my house, that's my husband in the field, that's my girl talking to the scarecrows. The Order's barn is the Reeve's worry. Mine is everything else.", "do": "met:hesper", "next": "hub"},
		"hub": {"say_if": [
			["qd:fm_tithe", "Aldous slept last night. First time in a year. Whatever you did, do it again."],
			["qp:ds_witchs_price:bread,qd:ds_witchs_price", "The bread rose. It's light, and it tastes of smoke, and I put a loaf on the sill every night for whoever comes. Cobb won't touch it. I eat his share."],
			["qp:ds_witchs_price:strips,qd:ds_witchs_price", "The far strips are only a field. Aldous stands at the edge of it of a morning. The bread's still grey. I'll eat grey bread. I'd rather."],
			["qp:ds_witchs_price:nothing,qd:ds_witchs_price", "You asked nothing. She'll come for the nail, I know it. There's a bright nail-head in the earth by the step I didn't put there. I step round it."],
			["qd:ds_witchs_price", "I won't ask what it was. The door-post sings at night. I have started to sing back."],
			["qat:ds_witchs_price:1|qat:ds_witchs_price:2", "Read the old nails, at her stone. My mother's is there, if you find it. She didn't tell me what she asked. The bread has been grey since."],
			["q:ds_witchs_price", "The Southwood, past the burners' ruin. Her stone is by a hollow in a fallen oak. Drive the nail yourself, and say one thing, plain. She doesn't like a list."],
			["", "The well's sweet. The bread's grey. The night's long. Two out of three."],
		], "choices": [
			{"text": "Is Fallowmere safe?", "to": "safe", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"safe": {"say": "Safe as the fire. Inside its light we're a farm. Outside it we're a field, and fields get harvested. Keep that in mind on the way out.", "next": "hub"},
	}},
	"cobb": {"name": "Cobb Lark", "start": [["!met:cobb", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Gate's open, mind it on the way through. The sheep can't get out. It's what gets in.", "next": "meet2"},
		"meet2": {"say": "Cobb. I turn the strips nobody's buried in. Fewer every spring.", "do": "met:cobb", "next": "hub"},
		"hub": {"say_if": [
			["qd:ds_clapper", "Furrow's straight. The clapper's gone, the stones lie at the gate in a row, and the plough goes where it's pushed. I'd call that a good result."],
			["q:ds_clapper", "The castellum, at the arches' west end. Hang it in the water-bell and stand by it while it tolls. Something comes to the sound."],
			["", "Plough turned up a bell clapper in the south strip. Order's mark on it. The Reeve said put it back. I put it back."],
		], "choices": [
			{"text": "What grows here now?", "to": "grow", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"grow": {"say": "Barley, thin. Beans, thinner. Stones, every year a new crop of stones. And the grave-markers. Those come up straight.", "next": "hub"},
	}},
	"dilly": {"name": "Dilly", "start": [["!met:dilly", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "That one's Old Tom and that one's the Reeve and that one's nobody. I didn't make that one.", "next": "meet2"},
		"meet2": {"say": "I'm Dilly. I make the scarecrows. Mam says they're for crows. There aren't any crows. They're for the fields, so the fields know somebody's looking.", "do": "met:dilly", "next": "hub"},
		"hub": {"say_if": [
			["qp:ds_unmade:burn,qd:ds_unmade", "There's no coat on him now. He's only a sack on a stick. I don't draw on him. Mam says that's wise. I think it's sad."],
			["qd:ds_unmade", "He faces the road now. I drew him a new face, a small one. Mam says the coat isn't mine to dress him in. I said it isn't anyone's."],
			["q:ds_unmade", "He's in the last of the far strips. Don't look at his face for long. It's mine, but it isn't me."],
			["", "The one I didn't make faces the house. Mine all face the road. Mam says don't go near it. I don't. It goes near me."],
		], "choices": [
			{"text": "Goodbye.", "to": ""},
		]},
	}},
	"wystan": {"name": "Brother Wystan", "start": [["!met:wystan", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Peace. Stand on the path. The rest of this field is spoken for.", "next": "meet2"},
		"meet2": {"say": "Wystan, of the Order once, of the strips now. When the Night came the barn had seed and no sowers. Now the strips have sowers. I dig, and I say the words, and they stay down. Mostly.", "do": "met:wystan", "next": "hub"},
		"hub": {"say_if": [
			["qp:fm_tithe:strike,qd:fm_tithe", "The Reeve's own name wasn't read. The field went quiet a breath late. I don't hold with striking a name. I'd have read it myself."],
			["qd:fm_tithe", "The Reeve read the names. I heard the field go quiet, the way a room goes quiet when its name is called."],
			["", "Every grave is a strip that won't be ploughed. Every strip that won't be ploughed is bread that won't be baked. That is the arithmetic of a farm after the end of the world."],
		], "choices": [
			{"text": "Do they stay down?", "to": "down", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"down": {"say": "If they're named. The Order taught us the dead want to be counted. So we count them. The ones in the far strips, nobody counted. Those walk.", "next": "hub"},
	}},
	"vell": {"name": "Mother Vell", "start": [["!met:vell", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "In, in. Boots off the step. The lamp's paid for, the fire's lit and the stew's what it is. Ask for nothing else and you'll get it.", "next": "meet2"},
		"meet2": {"say": "Vell. The Last Lamp's mine. Pilgrims stopped here on their way to the Stair for three hundred years and every one of them owed my family a night. None of them came back to pay it.", "do": "met:vell", "next": "hub"},
		"hub": {"say_if": [
			["qd:ll_gate", "The knocking stopped. Coyle won't say what you did. He just stood a round for the house. Coyle."],
			["qp:er_inn_slate:forgive,qd:er_inn_slate", "Nobody owes. I wrote it in my own hand, first line. The slate's black as the day it hung, and I can't stop wiping it. There's nothing there. That's the whole point."],
			["qp:er_inn_slate:keep,qd:er_inn_slate", "The slate stands. The tokens are on the shelf, one under each name. I read them in the mornings. A debt is a way of being remembered. I charge for the stew all the same."],
			["qp:er_inn_slate:paid,qd:er_inn_slate", "PAID across the lot, and every name still legible. The tokens in the window, where the road can see. Pilgrims stop and look. One asked what it meant. I said: it means welcome."],
			["qp:er_inn_slate:stranger,qd:er_inn_slate", "A bed's turned down at the end of the room every night, for the one with no name. I don't know whose. Somebody is sleeping in it. The sheets are warm in the morning."],
			["qd:er_inn_slate", "The slate says what it says now. I look at it more than I used to. Not for the names. For what is written beside them."],
			["qat:er_inn_slate:2", "Lay the tokens out on my counter and read them. All of them, if you can bear it. I never have. Somebody of mine is among them, and I have never looked."],
			["q:er_inn_slate", "The turned-back on the north cairns hold the tokens. The One Who Counted keeps their count. Put him down before you set the tokens on my counter, or he will count them again."],
			["", "Ale's warm, the beds are cold, and the rumours are free if you're drinking. Sit near the fire. The other end of the room listens."],
		], "choices": [
			{"text": "What's on the slate?", "to": "shop", "do": "shop:vell"},
			{"text": "Why is the east gate shut?", "to": "gate", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"shop": {"say": "Pay at the door, drink by the fire.", "next": "hub"},
		"gate": {"say": "Past the gate the road went up to the Stair. The night the sky turned, the road came down instead. Coyle's father barred it. Nobody's lifted a bar since. Things knock, some nights. We don't answer the door. That's the whole of the law in Lastlight.", "next": "hub"},
	}},
	"isolde": {"name": "Old Isolde", "start": [["!met:isolde", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Who are you, then. Say it. Out loud, so the lamp hears it.", "next": "meet2"},
		"meet2": {"say": "Isolde. I keep the last lamp. Sixty years. My mother kept it before me. It's been out once. That was the Night. It came back on its own, the next dark, and I've never asked it why.", "do": "met:isolde", "next": "hub"},
		"hub": {"say_if": [
			["qp:ll_oil:lit,qd:ll_oil", "Three wicks, all burning, the east one leaning at the gate. Fenn says it's looked back at. Let it. A lamp's for whoever's on the other side too. I'm too old to choose."],
			["qp:ll_oil:dark,qd:ll_oil", "Two wicks and a dark one. The gate gets nothing from me. The road gets all I have. It's a hard thing, a lamp. It's only ever for some of them."],
			["qd:ll_oil", "Full reservoir, first time since the carters stopped. She's burning white. You can read by her from the Bellfall's lip, they say."],
			["qat:ll_oil:1|qat:ll_oil:2", "Light a taper at the fire on the Nave's north shore, and carry it up. Walk it. A lamp's a thing you carry as if it were a child, and a child doesn't run."],
			["qat:ll_oil:3|qat:ll_oil:4", "Three wicks. West for the road, south for the Nave, east last, for the gate. In that order. The tower's only ever lit one way, and I've never told it to be different."],
			["qat:ll_oil:0", "Tallow. The pilgrims' candles, what they carried up and never burned. The drowned in the Nave still hold them. Bring me four."],
			["", "The lamp's for the road. For anyone still on it, coming down. If there's anyone. If there's any road."],
		], "choices": [
			{"text": "Who is the lamp for?", "to": "who", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"who": {"say": "For the ones who turned back. The cairns are full of them. And for the ones who didn't. Someone has to leave a light on for those, and I'm too old to stop.", "next": "hub"},
	}},
	"coyle": {"name": "Serjeant Coyle", "start": [["!met:coyle", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Stop there. Hands where I can see them. Good. You'll do.", "next": "meet2"},
		"meet2": {"say": "Coyle. Serjeant of the east watch, which is me, the boy on the road gate and a ladder. My father barred that gate. I keep it barred. It's not a hard job. It's just a long one.", "do": "met:coyle", "next": "hub"},
		"hub": {"say_if": [
			["qp:ll_gate:open,qd:ll_gate", "You opened the postern. I took the latch off its hook for the night and put it back at dawn. Nothing came over the sill. Something was glad of the door. I don't like that I know it."],
			["qp:ll_gate:hold,qd:ll_gate", "You held the bar. There's a cairn at the gate's foot I didn't build. I sit on the step with my back to it. A bar is a bar. I never said it didn't hold something up."],
			["qp:ll_gate:answer,qd:ll_gate,qc:ll_gate:token", "You answered. You said the four words. There's a name on the slate that's yours. And a pewter token in the gutter, the Last Lamp's, thrown back over the gate by somebody paying their way in. I didn't know the dead kept accounts."],
			["qp:ll_gate:answer,qd:ll_gate", "You answered. There's a name on the slate by the gate, in your hand. I've read it. I haven't rubbed it out. A thing that answers is a thing that can be answered."],
			["qd:ll_gate", "Quiet three nights running. I don't trust quiet. But I'll sleep in it."],
			["qc:er_inn_slate:coyle,qd:er_inn_slate", "Vell says one of the tokens was my aunt's. Maren Coyle's. The low part of the choir. I stood a round for the house. I'll stand another, if you ask."],
			["qat:ll_gate:0", "Go and stand at the gate. Listen. Three knocks, slow. Then go out the postern and find what's knocking. Read what they've thrown over."],
			["qat:ll_gate:1|qat:ll_gate:2|qat:ll_gate:3", "There'll be things at the gate's foot, thrown over. Read them. Then what you do with the bar is yours. I'll not stop you, and I'll not thank you till it's done."],
			["", "Bar's on, chain's on, portcullis is down. If you hear knocking, it's the wind. If the wind says your name, come and get me."],
		], "choices": [
			{"text": "What's past the gate?", "to": "past", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"past": {"say": "The road up to the mountain, my father said. I've looked over the wall. There's a road. It just doesn't go anywhere I'd want to.", "next": "hub"},
	}},
	"fenn": {"name": "Fenn", "start": [["!met:fenn", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Halt! Who goes... sorry. Who goes. Serjeant says I've to say it every time.", "next": "meet2"},
		"meet2": {"say": "Fenn. Road gate. I came in with the last carters and stayed. Serjeant says I've a good eye. I think he means I don't sleep.", "do": "met:fenn", "next": "hub"},
		"hub": {"say_if": [
			["qp:er_rope:low,qd:er_rope", "A pilgrim came up the east road last night, with a lamp, quite calm, like he'd only stepped out. Serjeant looked at the bar, and at him, and at the bar. Then he opened the road gate. I've never seen him do that either."],
			["qp:ll_gate:open,qd:ll_gate,!qd:er_nave_fire", "Serjeant took the latch off the postern a night, and something thanked him by not coming in. I have not slept right since. I keep thinking it was waiting for me."],
			["qp:ll_gate:answer,qd:ll_gate,!q:er_nave_fire", "You answered the gate, so the man at the Nave's fire is on my mind. Four words, every night, and now I know the cadence. Somebody should walk him up the road. It might as well be you."],
			["qd:er_nave_fire", "He is at the shrine, with her. Serjeant opened the postern without being asked, and shut it after. I have never seen him do either."],
			["q:er_nave_fire", "South on the nave road, to the fire on the north shore. He won't come the last hundred yards on his own. Say her name to him. He'll know it."],
			["", "Salt carter came through two nights back. Marra. Said the road west was clear as far as the pans. Then she counted the hollowed she'd passed, and it wasn't clear."],
		], "choices": [
			{"text": "Goodbye.", "to": ""},
		]},
	}},
	"wat": {"name": "Wat", "start": [["!met:wat", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Easy. Not you. Her. She doesn't like strangers and she likes the dark less.", "next": "meet2"},
		"meet2": {"say": "Wat. Six stalls, two horses, one of them lame. Pilgrims used to leave their beasts here before the climb. I've the bridles of forty that never came back for them.", "do": "met:wat", "next": "hub"},
		"hub": {"say_if": [
			["qd:er_halter_bell", "She's in the stall again. She hasn't gone to the door once. I thought I would be glad. I'm not sure I am."],
			["q:er_halter_bell", "South by the nave road and the cairn road, to the tower's foot. A horse would do it in a quarter of the time. Mine is lame. Hers won't leave the stall."],
			["", "Horses smell what's out there before the watch sees it. When she stamps, I wake Coyle. She's not been wrong yet."],
		], "choices": [
			{"text": "Goodbye.", "to": ""},
		]},
	}},
	"maudlin": {"name": "Sister Maudlin", "start": [["!met:maudlin", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Shh. Kneel or walk on. The gate is listening.", "next": "meet2"},
		"meet2": {"say": "Maudlin. I came to climb the Stair the year the sky turned. They shut the gate the night I arrived. I have been arriving ever since.", "do": "met:maudlin", "next": "hub"},
		"hub": {"say_if": [
			["qp:er_rope:low,qd:er_rope", "He is resting. Rope seven. A pilgrim came up the east road after, with a lamp, and knocked. Fenn let him in. I did not look round. I am facing the road, and I did not need to."],
			["qp:er_rope:high,qd:er_rope", "The highest rope is gone. Better broken than waiting, I said, and I keep saying it. I do not turn to the road. I am listening for the water now, and it is quiet."],
			["qat:er_rope:0|qat:er_rope:1|qat:er_rope:2", "The Order rang from the bottom up, and the ropes were numbered from the top. So the highest number first. Tobin's is seven. Ring it first, and the rest in turn, and do not hurry. Hurried ropes wake the Nun's choir."],
			["qd:er_nave_fire", "He kneels beside me. He does not speak. I do not need him to."],
			["qp:er_ringers_candle:set,qd:er_ringers_candle", "A candle burns on the Nave's step and nobody keeps it. I face the road now, the other way. Somebody has to listen for what is coming in, as well as what is kept out."],
			["qp:er_ringers_candle:douse,qd:er_ringers_candle", "You put it out. I did not light another. The shrine's horn cup is cold. I find I can pray in the dark. I could not, before. I face the road now."],
			["qd:er_ringers_candle", "I face the road now, the other way. Somebody has to listen for what is coming in, as well as what is kept out."],
			["qat:er_ringers_candle:2", "Read the cairn. Their hands are in the soot, the large and the small. I could not read it, myself. I knelt at the other side of it. Tell me whose hand is whose."],
			["q:er_ringers_candle", "Keep the flame to windward. The Cracked Tollman rings on the crater, and the rest of them are beyond it, on the water."],
			["boss:ascended_warden", "They say the top is quiet now. I will still kneel. The gate doesn't know yet."],
			["", "Twice a night I hear it from the other side. Somebody kneeling, the same as me. I pray they are praying."],
		], "choices": [
			{"text": "Goodbye.", "to": ""},
		]},
	}},
}


# --- what they sell (village_shop.gd's shape) ------------------------------------------------------------------------

const MERCHANTS := {
	"gorse": {"name": "Gorse's smokehouse", "greet": "Eel, smoked. Things out of the nets, dried. Ash, and no haggling: the smoke doesn't haggle."},
	"vell": {"name": "The Last Lamp", "greet": "Ale's one. Rumours are free to drinkers. What's under the counter costs what it cost the pilgrim who left it."},
}

const GOODS := {
	"gorse": [
		{"id": "grave_iron", "item": "grave_iron", "price": 10, "stock": 2, "say": "Out of the nets. Came up with a hand still on it. I took the hand off first."},
		{"id": "ash_bloom", "item": "ash_bloom", "price": 6, "stock": 3, "say": "Grows on the hall's piles. Pale as fish-belly."},
		{"id": "relic_fragment", "item": "relic_fragment", "price": 15, "stock": 1, "say": "Off the heron stones. Don't tell Aud."},
	],
	"vell": [
		{"id": "ale", "name": "A mug of the Last Lamp's ale", "glyph": "mug", "price": 1, "stock": 3,
			"text": "Dark and sour, brewed with the pilgrims' barley. Takes 14 Gloom off at once.",
			"say": "Drink it before it drinks the warmth out of you."},
		{"id": "rumour", "name": "A rumour from the road", "glyph": "scroll", "price": 2, "stock": 1,
			"text": "What the carters said, what the watch saw, where the next trouble's been seen.",
			"say": "You didn't hear it from me. You heard it from the room."},
		{"id": "relic_fragment", "item": "relic_fragment", "price": 14, "stock": 2, "say": "A pilgrim's. Left for the night's board. He's not coming back for it."},
		{"id": "ember_shard", "item": "ember_shard", "price": 9, "stock": 2, "say": "From the Bellfall's crater. Still warm, or it's my hands."},
	],
}
