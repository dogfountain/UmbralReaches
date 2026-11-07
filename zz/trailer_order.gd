extends RefCounted
## The cut of the action trailer: [id, seconds, cross-fade into it (s, 0 = hard cut), act, style].
## `godot ... res://zz/trailer.tscn -- --list` prints it; `--shot=<id>` / `--shots=a,b` renders just those.
## Styles: GAME = the game's own camera, TOP = fixed top-down, FP = first person, CIN = slow and collision-checked,
## UI = a menu over the paused world, CARD = a title card on black.
const ORDER := [
	# act I: the last fire
	["cold", 1.4, 0.0, "I", "CIN"], ["village", 2.4, 0.0, "I", "CIN"], ["tavern", 1.4, 0.0, "I", "CIN"],
	["keg_song", 1.8, 0.0, "I", "CIN"], ["run_game", 1.8, 0.0, "I", "GAME"], ["staff_heavy", 2.0, 0.0, "I", "GAME"], ["staff_parry", 2.0, 0.0, "I", "CIN"], ["spellbar", 2.2, 0.0, "I", "GAME"], ["hearth_tithe", 1.8, 0.0, "I", "UI"],
	["kindling", 2.0, 0.0, "I", "UI"], ["gear", 1.8, 0.0, "I", "UI"],
	# act II: what climbs comes down hollow
	["card_dark", 0.8, 0.0, "II", "CARD"], ["fight_otc", 3.0, 0.0, "II", "GAME"], ["fp_lance", 2.0, 0.0, "II", "FP"],
	["fight_top", 3.0, 0.0, "II", "TOP"], ["spell_ward", 2.2, 0.0, "II", "CIN"], ["spell_arcana", 2.4, 0.0, "II", "TOP"], ["familiar", 2.2, 0.0, "II", "CIN"],
	["gloom_shade", 2.4, 0.0, "II", "GAME"], ["loot", 2.2, 0.0, "II", "CIN"], ["fight_side", 2.6, 0.0, "II", "CIN"],
	["vault", 1.6, 0.0, "II", "CIN"], ["grab", 2.0, 0.0, "II", "CIN"], ["kick", 1.8, 0.0, "II", "GAME"], ["slide", 1.6, 0.0, "II", "GAME"], ["fp_run", 1.6, 0.0, "II", "FP"],
	["storm", 1.8, 0.0, "II", "CIN"], ["rain_mist", 1.6, 0.0, "II", "CIN"], ["wildlife", 1.5, 0.0, "II", "CIN"], ["wildlife_herd", 2.0, 0.0, "II", "CIN"],
	# act III: the realm widens
	["card_realm", 0.8, 0.0, "III", "CARD"], ["horse_mount", 2.0, 0.0, "III", "CIN"], ["horse_gallop", 2.4, 0.0, "III", "GAME"],
	["horse_fp", 2.2, 0.0, "III", "FP"], ["horse_jump", 1.6, 0.0, "III", "CIN"], ["horse_gallop_b", 2.2, 0.0, "III", "GAME"],
	["horse_breeds", 2.0, 0.0, "III", "CIN"],
	["thornwood", 1.2, 0.0, "III", "CIN"], ["necropolis", 1.2, 0.0, "III", "CIN"], ["mere", 1.2, 0.0, "III", "CIN"],
	["foundry", 1.2, 0.0, "III", "CIN"], ["orchard", 1.2, 0.0, "III", "CIN"], ["quarry", 1.2, 0.0, "III", "CIN"],
	["moor", 1.2, 0.0, "III", "CIN"], ["holds", 1.2, 0.0, "III", "CIN"], ["crowns", 1.4, 0.0, "III", "CIN"],
	["lamp_kindle", 2.0, 0.0, "III", "CIN"], ["weirford", 1.8, 0.0, "III", "CIN"], ["weirford_life", 2.4, 0.0, "III", "CIN"],
	["stillwater", 1.4, 0.0, "III", "CIN"], ["lamp_spire", 1.8, 0.0, "III", "FP"], ["anchorholds", 1.4, 0.0, "III", "CIN"],
	["hierarch", 1.6, 0.0, "III", "CIN"], ["siege", 1.3, 0.0, "III", "CIN"],
	["saltmarket", 1.2, 0.0, "III", "CIN"], ["saltmarket_life", 2.2, 0.0, "III", "CIN"], ["pans", 1.2, 0.0, "III", "CIN"],
	["pans_wide", 2.0, 0.0, "III", "CIN"], ["oak", 1.4, 0.0, "III", "CIN"], ["well", 1.6, 0.0, "III", "CIN"], ["downs", 1.8, 0.0, "III", "CIN"],
	["bells", 2.0, 0.0, "III", "CIN"], ["bell_ring", 2.4, 0.0, "III", "CIN"], ["shutter_fight", 2.6, 0.0, "III", "GAME"],
	["secret", 2.4, 0.0, "III", "CIN"],
	["escort", 2.0, 0.0, "III", "GAME"], ["escort_attack", 2.4, 0.0, "III", "GAME"], ["escort_top", 2.2, 0.0, "III", "TOP"],
	["defend", 2.2, 0.0, "III", "TOP"], ["defend_game", 2.2, 0.0, "III", "GAME"], ["defend_top", 2.4, 0.0, "III", "TOP"],
	["map", 1.6, 0.0, "III", "UI"], ["roam", 1.6, 0.0, "III", "CIN"], ["roam_incursion", 2.2, 0.0, "III", "TOP"], ["treasure", 1.6, 0.0, "III", "CIN"],
	# act IV: descend
	["card_depths", 0.8, 0.0, "IV", "CARD"], ["thorn_reveal", 2.2, 0.0, "IV", "CIN"], ["thorn_knots", 2.2, 0.0, "IV", "TOP"],
	["boss_reveal", 2.4, 0.0, "IV", "CIN"], ["boss_game", 2.4, 0.0, "IV", "GAME"], ["boss_wide", 2.4, 0.0, "IV", "CIN"],
	["warden", 2.0, 0.0, "IV", "CIN"], ["anchoress", 2.0, 0.0, "IV", "CIN"], ["hierarch_voice", 2.2, 0.0, "IV", "TOP"],
	["final_blow", 2.8, 0.0, "IV", "CIN"],
	["finale", 4.5, 0.0, "V", "CIN"],
]
## Shots whose subject is not the wanderer (no FRAME measurement of the wanderer).
const NO_SUBJECT := ["cold", "card_dark", "card_realm", "card_depths", "fp_run", "fp_lance", "finale", "wildlife", "tavern", "boss_reveal",
	"village", "keg_song", "wildlife_herd", "familiar", "hearth_tithe", "kindling", "gear", "map", "thornwood", "necropolis", "mere", "foundry", "orchard", "quarry", "moor", "holds", "crowns",
	"stillwater", "lamp_spire", "anchorholds", "hierarch", "siege", "saltmarket", "pans", "oak", "well", "bells", "roam", "rain_mist",
	"thorn_reveal", "thorn_knots", "warden", "anchoress", "hierarch_voice", "final_blow", "boss_low", "horse_breeds", "weirford", "defend", "spell_arcana",
	"weirford_life", "saltmarket_life", "pans_wide", "downs", "bell_ring", "secret", "escort_top", "defend_top", "roam_incursion", "horse_fp"]
