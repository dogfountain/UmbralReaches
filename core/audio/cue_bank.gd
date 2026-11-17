extends RefCounted
## Every one-shot the sound rework adds, as data. A cue is {"len": seconds, "layers": [layer, ...], "post": [[filter, Hz]], "db": level}
## and a layer is [kind, t, ...] (see RECIPES below; kinds are synth_kit.gd's instruments). The bank renders the whole shelf once,
## on a worker thread started at the night's load, caches each cue's bytes through GenCache, and hands out AudioStreamWAVs; until a
## cue is rendered it is simply not played (never built on the main thread: frame stutter is the top complaint).
##   CueBank.warm()                         start the worker (the Soundstage does, once)
##   CueBank.play(host, id, db, pitch)      non-positional, on the UI bus for interface cues and the SFX bus for the rest
##   CueBank.play_at(id, at, db, pitch)     positional, through the shared voice pool (Sfx)
##   CueBank.stream(id)                     the stream or null
##   CueBank.has(id) / ids()                the shelf
##   CueBank.release()                      drop every stream and the bytes (the zone leaving the tree)
## Cue groups: ui_* (menus, map, Count, Chronicle, photo shutter), world (doors, chests, pickups, fires, beacons, camp, horse),
## night (eclipse, moths, fog), combat (hurt, block, parry, crit, schools, tells), story (quest, discovery, stingers) and the
## five bosses' intro / phase / death (boss_<id>_<what>). Load by path: const CueBank := preload("res://core/audio/cue_bank.gd")

const Kit := preload("res://core/audio/synth_kit.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/audio/cue_bank.gd"
const VERSION := 1

## layer kinds and their fields:
##   ["sine", t, dur, f, f_end, a, atk, dec]      ["bell", t, f, a, dec]            ["pluck", t, f, a, dec]
##   ["noise", t, dur, a, lo, hi, atk, dec, trem] ["thud", t, f, f_end, dur, a]     ["choir", t, dur, f, a, atk]    ["horn", t, dur, f, a, atk]
const RECIPES := {
	# --- the interface ---
	"ui_open": {"len": 0.4, "db": -19.0, "layers": [["sine", 0.0, 0.2, 392.0, 0.0, 0.5, 0.004, 0.07], ["sine", 0.05, 0.25, 587.0, 0.0, 0.4, 0.004, 0.09]]},
	"ui_close": {"len": 0.4, "db": -20.0, "layers": [["sine", 0.0, 0.2, 587.0, 0.0, 0.45, 0.004, 0.06], ["sine", 0.05, 0.25, 392.0, 0.0, 0.4, 0.004, 0.09]]},
	"ui_page": {"len": 0.45, "db": -23.0, "layers": [["noise", 0.0, 0.22, 0.5, 1500.0, 6500.0, 0.02, 0.09, 0.0], ["noise", 0.11, 0.2, 0.35, 1800.0, 7000.0, 0.02, 0.08, 0.0]]},
	"ui_map_open": {"len": 0.9, "db": -18.0, "layers": [["noise", 0.0, 0.55, 0.45, 700.0, 5000.0, 0.08, 0.3, 17.0], ["thud", 0.5, 150.0, 90.0, 0.12, 0.35], ["sine", 0.52, 0.3, 523.0, 0.0, 0.2, 0.01, 0.1]]},
	"ui_map_close": {"len": 0.7, "db": -20.0, "layers": [["noise", 0.0, 0.4, 0.4, 700.0, 4500.0, 0.05, 0.2, 14.0], ["thud", 0.35, 130.0, 80.0, 0.1, 0.3]]},
	"ui_map_pin": {"len": 0.3, "db": -17.0, "layers": [["thud", 0.0, 900.0, 300.0, 0.08, 0.5], ["noise", 0.0, 0.03, 0.4, 2500.0, 9000.0, 0.001, 0.01, 0.0], ["sine", 0.02, 0.2, 1175.0, 0.0, 0.18, 0.002, 0.07]]},
	"ui_deny": {"len": 0.45, "db": -17.0, "layers": [["sine", 0.0, 0.18, 196.0, 185.0, 0.55, 0.004, 0.08], ["sine", 0.12, 0.25, 165.0, 150.0, 0.55, 0.004, 0.1]]},
	"ui_buy": {"len": 0.8, "db": -16.0, "layers": [["bell", 0.0, 1568.0, 0.35, 0.35], ["bell", 0.07, 2093.0, 0.3, 0.3], ["noise", 0.0, 0.05, 0.4, 3000.0, 9000.0, 0.001, 0.015, 0.0]]},
	"ui_equip": {"len": 0.5, "db": -18.0, "layers": [["noise", 0.0, 0.14, 0.55, 400.0, 2600.0, 0.006, 0.05, 0.0], ["thud", 0.04, 210.0, 120.0, 0.1, 0.4], ["bell", 0.1, 1319.0, 0.12, 0.15]]},
	"ui_unequip": {"len": 0.4, "db": -20.0, "layers": [["noise", 0.0, 0.1, 0.45, 400.0, 2400.0, 0.006, 0.04, 0.0], ["thud", 0.03, 180.0, 110.0, 0.08, 0.3]]},
	"ui_toast": {"len": 0.7, "db": -22.0, "layers": [["bell", 0.0, 880.0, 0.35, 0.5]]},
	"ui_count_open": {"len": 1.6, "db": -16.0, "layers": [["bell", 0.0, 220.0, 0.5, 1.2], ["noise", 0.05, 0.3, 0.3, 1500.0, 6000.0, 0.03, 0.12, 0.0], ["choir", 0.2, 1.2, 330.0, 0.18, 0.5]]},
	"ui_chronicle": {"len": 1.3, "db": -18.0, "layers": [["noise", 0.0, 0.55, 0.3, 3000.0, 9500.0, 0.05, 0.4, 22.0], ["bell", 0.5, 1047.0, 0.3, 0.7]]},
	"ui_shutter": {"len": 0.35, "db": -14.0, "layers": [["noise", 0.0, 0.02, 0.8, 1000.0, 9000.0, 0.001, 0.008, 0.0], ["thud", 0.07, 260.0, 140.0, 0.06, 0.5], ["noise", 0.13, 0.025, 0.6, 900.0, 8000.0, 0.001, 0.01, 0.0]]},
	"ui_slider": {"len": 0.08, "db": -26.0, "layers": [["sine", 0.0, 0.05, 1800.0, 1700.0, 0.4, 0.001, 0.02]]},
	# --- the world ---
	"door_open": {"len": 1.0, "db": -11.0, "layers": [["sine", 0.0, 0.7, 140.0, 215.0, 0.3, 0.05, 0.4], ["noise", 0.0, 0.7, 0.3, 200.0, 1100.0, 0.05, 0.4, 11.0], ["thud", 0.75, 120.0, 70.0, 0.12, 0.35]]},
	"door_close": {"len": 0.7, "db": -10.0, "layers": [["thud", 0.0, 130.0, 55.0, 0.2, 0.6], ["noise", 0.0, 0.08, 0.35, 500.0, 3000.0, 0.002, 0.03, 0.0], ["noise", 0.16, 0.03, 0.4, 2000.0, 7000.0, 0.001, 0.01, 0.0]]},
	"chest_open": {"len": 1.4, "db": -11.0, "layers": [["sine", 0.0, 0.6, 120.0, 190.0, 0.25, 0.04, 0.3], ["noise", 0.0, 0.5, 0.25, 250.0, 1200.0, 0.05, 0.3, 9.0], ["thud", 0.6, 100.0, 60.0, 0.15, 0.45], ["bell", 0.7, 1319.0, 0.22, 0.6]]},
	"pickup": {"len": 0.6, "db": -17.0, "layers": [["pluck", 0.0, 659.0, 0.4, 0.3], ["pluck", 0.07, 988.0, 0.35, 0.3]]},
	"pickup_rare": {"len": 1.4, "db": -13.0, "layers": [["bell", 0.0, 880.0, 0.35, 0.9], ["bell", 0.09, 1319.0, 0.3, 0.8], ["bell", 0.2, 1760.0, 0.25, 0.8]]},
	"ash_gain": {"len": 0.6, "db": -20.0, "layers": [["noise", 0.0, 0.3, 0.4, 2000.0, 8000.0, 0.002, 0.1, 40.0], ["bell", 0.05, 1568.0, 0.15, 0.3]]},
	"kindle_breath": {"len": 2.0, "db": -14.0, "layers": [["noise", 0.0, 1.8, 0.5, 200.0, 1500.0, 0.3, 0.6, 0.0], ["sine", 0.0, 1.8, 110.0, 220.0, 0.35, 0.4, 0.8]]},
	"beacon_light": {"len": 3.2, "db": -9.0, "layers": [["horn", 0.0, 2.6, 98.0, 0.5, 0.5], ["bell", 0.6, 196.0, 0.4, 1.6], ["choir", 0.8, 2.2, 392.0, 0.2, 0.7]]},
	"camp_begin": {"len": 4.0, "db": -14.0, "layers": [["choir", 0.0, 3.6, 196.0, 0.3, 1.4], ["noise", 0.0, 3.6, 0.15, 1500.0, 7000.0, 0.5, 2.5, 33.0]]},
	"camp_end": {"len": 3.0, "db": -12.0, "layers": [["bell", 0.0, 392.0, 0.4, 1.2], ["bell", 0.5, 587.0, 0.35, 1.0], ["choir", 0.3, 2.4, 294.0, 0.18, 0.8]]},
	"horse_bond": {"len": 1.8, "db": -14.0, "layers": [["sine", 0.0, 0.5, 260.0, 190.0, 0.3, 0.05, 0.25], ["noise", 0.0, 0.5, 0.25, 300.0, 1300.0, 0.05, 0.25, 14.0], ["bell", 0.6, 784.0, 0.22, 0.9]]},
	"horse_nicker": {"len": 0.7, "db": -15.0, "layers": [["sine", 0.0, 0.4, 300.0, 210.0, 0.25, 0.04, 0.2], ["noise", 0.0, 0.4, 0.3, 300.0, 1400.0, 0.04, 0.2, 16.0]]},
	"landmark_hum": {"len": 4.0, "db": -22.0, "layers": [["choir", 0.0, 3.8, 98.0, 0.3, 1.5], ["sine", 0.0, 3.8, 49.0, 0.0, 0.25, 1.0, 3.0]]},
	# --- the living night ---
	"eclipse_warn": {"len": 7.0, "db": -14.0, "layers": [["sine", 0.0, 6.5, 55.0, 0.0, 0.5, 3.0, 4.0], ["sine", 0.0, 6.5, 57.0, 0.0, 0.4, 3.0, 4.0], ["choir", 1.0, 5.5, 110.0, 0.15, 3.0]]},
	"eclipse_total": {"len": 8.0, "db": -12.0, "layers": [["choir", 0.0, 7.5, 110.0, 0.25, 2.0], ["choir", 0.0, 7.5, 165.0, 0.18, 2.0], ["bell", 0.4, 55.0, 0.5, 3.0], ["sine", 0.0, 7.5, 36.0, 0.0, 0.4, 1.5, 5.0]]},
	"eclipse_return": {"len": 5.0, "db": -11.0, "layers": [["bell", 0.0, 220.0, 0.4, 1.8], ["bell", 0.7, 330.0, 0.35, 1.6], ["bell", 1.4, 440.0, 0.3, 1.4], ["noise", 0.0, 4.0, 0.12, 2000.0, 8000.0, 1.5, 1.5, 0.0]]},
	"moth_flutter": {"len": 0.5, "db": -26.0, "layers": [["noise", 0.0, 0.35, 0.3, 3000.0, 9000.0, 0.03, 0.18, 38.0]]},
	"fog_breath": {"len": 3.2, "db": -24.0, "layers": [["noise", 0.0, 3.0, 0.5, 100.0, 700.0, 1.0, 1.2, 0.0]]},
	# --- blows and casts ---
	"hurt_body": {"len": 0.5, "db": -9.0, "layers": [["thud", 0.0, 150.0, 55.0, 0.22, 0.7], ["noise", 0.0, 0.2, 0.35, 100.0, 1000.0, 0.002, 0.08, 0.0], ["sine", 0.04, 0.25, 180.0, 120.0, 0.18, 0.01, 0.1]]},
	"parry_ring": {"len": 0.7, "db": -11.0, "layers": [["sine", 0.0, 0.5, 1760.0, 1750.0, 0.4, 0.001, 0.25], ["sine", 0.0, 0.5, 2637.0, 2630.0, 0.25, 0.001, 0.18], ["noise", 0.0, 0.02, 0.6, 2500.0, 9000.0, 0.001, 0.008, 0.0]]},
	"block_thud": {"len": 0.45, "db": -10.0, "layers": [["thud", 0.0, 170.0, 80.0, 0.18, 0.7], ["noise", 0.0, 0.1, 0.4, 300.0, 3000.0, 0.002, 0.04, 0.0], ["sine", 0.0, 0.2, 900.0, 880.0, 0.15, 0.001, 0.08]]},
	"crit_shimmer": {"len": 0.6, "db": -17.0, "layers": [["sine", 0.0, 0.4, 2093.0, 3136.0, 0.3, 0.002, 0.15], ["sine", 0.03, 0.4, 3136.0, 3135.0, 0.2, 0.002, 0.15], ["noise", 0.0, 0.2, 0.2, 6000.0, 10000.0, 0.002, 0.08, 0.0]]},
	"school_ember": {"len": 0.6, "db": -20.0, "layers": [["noise", 0.0, 0.45, 0.5, 1200.0, 6500.0, 0.01, 0.2, 31.0]]},
	"school_umbral": {"len": 0.8, "db": -18.0, "layers": [["sine", 0.0, 0.6, 110.0, 55.0, 0.5, 0.02, 0.3], ["choir", 0.0, 0.6, 130.0, 0.1, 0.1]]},
	"school_light": {"len": 0.9, "db": -20.0, "layers": [["bell", 0.0, 1568.0, 0.3, 0.6], ["sine", 0.0, 0.5, 2349.0, 2400.0, 0.12, 0.01, 0.25]]},
	"kill_flourish": {"len": 0.9, "db": -18.0, "layers": [["thud", 0.0, 90.0, 45.0, 0.35, 0.5], ["bell", 0.05, 330.0, 0.2, 0.6]]},
	"tell_windup": {"len": 0.7, "db": -22.0, "layers": [["sine", 0.0, 0.55, 220.0, 880.0, 0.3, 0.1, 0.5]]},
	"tell_heavy": {"len": 1.0, "db": -19.0, "layers": [["sine", 0.0, 0.9, 82.0, 165.0, 0.4, 0.2, 0.8], ["noise", 0.0, 0.8, 0.15, 100.0, 800.0, 0.3, 0.5, 0.0]]},
	"tell_break": {"len": 0.4, "db": -13.0, "layers": [["noise", 0.0, 0.12, 0.6, 1500.0, 9000.0, 0.001, 0.04, 0.0], ["bell", 0.0, 1319.0, 0.25, 0.25]]},
	"gloom_heart": {"len": 0.7, "db": -16.0, "layers": [["thud", 0.0, 60.0, 42.0, 0.22, 0.7], ["thud", 0.28, 55.0, 40.0, 0.25, 0.5]]},
	# --- the story ---
	"quest_step": {"len": 0.6, "db": -19.0, "layers": [["pluck", 0.0, 784.0, 0.4, 0.35], ["bell", 0.06, 1175.0, 0.2, 0.3]]},
	"stinger_victory": {"len": 3.2, "db": -12.0, "layers": [["horn", 0.0, 2.4, 147.0, 0.4, 0.3], ["bell", 0.2, 294.0, 0.4, 1.4], ["choir", 0.3, 2.4, 220.0, 0.2, 0.6]]},
	"stinger_defeat": {"len": 3.0, "db": -12.0, "layers": [["sine", 0.0, 2.6, 98.0, 65.0, 0.5, 0.1, 1.4], ["bell", 0.0, 82.0, 0.4, 2.0]]},
	"stinger_act": {"len": 5.0, "db": -10.0, "layers": [["bell", 0.0, 110.0, 0.5, 2.0], ["bell", 0.7, 165.0, 0.4, 1.8], ["bell", 1.4, 220.0, 0.4, 1.6], ["bell", 2.1, 330.0, 0.35, 1.4], ["choir", 1.2, 3.4, 220.0, 0.16, 1.0]]},
	# --- the five great ones: what they do as they wake, turn, and fall ---
	"boss_thornwarden_intro": {"len": 3.0, "db": -9.0, "layers": [["sine", 0.0, 1.6, 70.0, 95.0, 0.5, 0.2, 1.0], ["noise", 0.0, 2.0, 0.35, 150.0, 1000.0, 0.3, 1.0, 6.0], ["thud", 1.5, 80.0, 40.0, 0.3, 0.6]]},
	"boss_thornwarden_phase": {"len": 2.0, "db": -11.0, "layers": [["noise", 0.0, 1.4, 0.5, 800.0, 5500.0, 0.05, 0.7, 24.0], ["sine", 0.0, 1.0, 90.0, 130.0, 0.35, 0.1, 0.5]]},
	"boss_thornwarden_death": {"len": 3.2, "db": -10.0, "layers": [["thud", 0.0, 80.0, 35.0, 1.2, 0.6], ["noise", 0.0, 1.8, 0.3, 150.0, 2500.0, 0.05, 0.9, 12.0], ["sine", 0.8, 1.8, 330.0, 196.0, 0.18, 0.3, 0.9]]},
	"boss_bone_abbot_intro": {"len": 3.2, "db": -9.0, "layers": [["bell", 0.0, 98.0, 0.6, 2.4], ["noise", 0.5, 0.5, 0.3, 2000.0, 8500.0, 0.01, 0.2, 30.0], ["noise", 1.3, 0.4, 0.25, 2000.0, 8500.0, 0.01, 0.15, 28.0]]},
	"boss_bone_abbot_phase": {"len": 2.4, "db": -10.0, "layers": [["bell", 0.0, 98.0, 0.6, 2.0], ["noise", 0.4, 0.05, 0.5, 2500.0, 8000.0, 0.001, 0.02, 0.0], ["noise", 0.9, 0.05, 0.5, 2500.0, 8000.0, 0.001, 0.02, 0.0], ["noise", 1.4, 0.05, 0.5, 2500.0, 8000.0, 0.001, 0.02, 0.0]]},
	"boss_bone_abbot_death": {"len": 3.6, "db": -9.0, "layers": [["bell", 0.0, 98.0, 0.6, 3.0], ["noise", 0.2, 1.6, 0.35, 1500.0, 8500.0, 0.05, 0.7, 26.0], ["choir", 0.6, 2.4, 147.0, 0.12, 0.8]]},
	"boss_ascended_warden_intro": {"len": 4.0, "db": -9.0, "layers": [["choir", 0.0, 3.4, 294.0, 0.3, 1.2], ["bell", 0.4, 147.0, 0.5, 2.2]]},
	"boss_ascended_warden_phase": {"len": 3.0, "db": -10.0, "layers": [["horn", 0.0, 2.0, 147.0, 0.45, 0.3], ["bell", 0.3, 220.0, 0.4, 1.6]]},
	"boss_ascended_warden_death": {"len": 5.0, "db": -9.0, "layers": [["choir", 0.0, 3.0, 294.0, 0.28, 0.4], ["bell", 0.0, 110.0, 0.6, 3.5], ["sine", 2.0, 2.8, 220.0, 110.0, 0.12, 0.5, 1.6]]},
	"boss_r37_anchoress_intro": {"len": 3.0, "db": -10.0, "layers": [["bell", 0.0, 1175.0, 0.25, 0.18], ["bell", 0.35, 1047.0, 0.22, 0.18], ["bell", 0.75, 1245.0, 0.22, 0.16], ["sine", 0.0, 2.8, 82.0, 0.0, 0.3, 0.6, 1.5]]},
	"boss_r37_anchoress_phase": {"len": 2.2, "db": -11.0, "layers": [["noise", 0.0, 1.6, 0.4, 500.0, 3500.0, 0.1, 0.9, 9.0], ["bell", 0.2, 1175.0, 0.25, 0.2], ["bell", 0.9, 1047.0, 0.25, 0.2]]},
	"boss_r37_anchoress_death": {"len": 3.6, "db": -10.0, "layers": [["bell", 0.0, 1175.0, 0.3, 0.3], ["choir", 0.5, 2.8, 196.0, 0.16, 0.8]]},
	"boss_r37_hierarch_intro": {"len": 4.0, "db": -9.0, "layers": [["horn", 0.0, 3.2, 147.0, 0.45, 0.6], ["choir", 1.2, 2.2, 880.0, 0.07, 0.6]]},
	"boss_r37_hierarch_phase": {"len": 3.0, "db": -10.0, "layers": [["horn", 0.0, 2.4, 147.0, 0.4, 0.3], ["horn", 0.0, 2.4, 155.0, 0.3, 0.3]]},
	"boss_r37_hierarch_death": {"len": 4.0, "db": -11.0, "layers": [["horn", 0.0, 1.2, 147.0, 0.4, 0.1], ["choir", 0.3, 1.8, 784.0, 0.1, 0.3]]},
}

static var _bytes := {}                 ## id -> PackedByteArray (filled by the worker, read on the main thread)
static var _streams := {}               ## id -> AudioStreamWAV
static var _mutex := Mutex.new()
static var _task := -1
static var _done := false


static func ids() -> Array:
	return RECIPES.keys()


static func has(id: String) -> bool:
	return RECIPES.has(id)


## Start rendering the shelf on a worker thread (once). Cached cues load from disk; the rest are rendered one after another.
static func warm() -> void:
	if _task >= 0 or _done:
		return
	_task = WorkerThreadPool.add_task(_work, false, "cue_bank")


static func ready() -> bool:
	_mutex.lock()
	var n := _bytes.size()
	_mutex.unlock()
	return n >= RECIPES.size()


static func release() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_done = false
	_mutex.lock()
	_bytes.clear()
	_mutex.unlock()
	_streams.clear()


static func _key(id: String) -> String:
	return "cue_%s_v%d" % [id, VERSION]


static func _work() -> void:
	for id: String in RECIPES:
		var key := _key(id)
		var data: Variant = GenCache.load_var(key, SELF)
		var bytes: PackedByteArray
		if data is PackedByteArray and (data as PackedByteArray).size() > 64:
			bytes = data
		else:
			bytes = Kit.encode(render(id))
			GenCache.save_var(key, SELF, bytes)
		_mutex.lock()
		_bytes[id] = bytes
		_mutex.unlock()
	_done = true


## One cue's samples (peak-normalised; the cue's own `db` is its playback level). Pure: safe on any thread.
static func render(id: String) -> PackedFloat32Array:
	var r: Dictionary = RECIPES[id]
	var out := Kit.buf(float(r.len))
	var seed_v := hash(id) % 100000
	var n := 0
	for ly: Array in r.layers:
		n += 1
		var s := seed_v + n * 17
		match String(ly[0]):
			"sine":
				Kit.partial(out, float(ly[1]), float(ly[2]), float(ly[3]), float(ly[5]), float(ly[6]), float(ly[7]), float(ly[4]))
			"bell":
				Kit.bell(out, float(ly[1]), float(ly[2]), float(ly[3]), float(ly[4]))
			"pluck":
				Kit.pluck(out, float(ly[1]), float(ly[2]), float(ly[3]), float(ly[4]))
			"noise":
				Kit.noise(out, float(ly[1]), float(ly[2]), float(ly[3]), float(ly[4]), float(ly[5]), float(ly[6]), float(ly[7]), s, float(ly[8]))
			"thud":
				Kit.thud(out, float(ly[1]), float(ly[2]), float(ly[3]), float(ly[4]), float(ly[5]), s)
			"choir":
				Kit.choir(out, float(ly[1]), float(ly[2]), float(ly[3]), float(ly[4]), float(ly[5]))
			"horn":
				Kit.horn(out, float(ly[1]), float(ly[2]), float(ly[3]), float(ly[4]), float(ly[5]))
	Kit.finish(out, 0.85, 0.02)
	return out


## The stream of a cue, or null while it has not rendered yet.
static func stream(id: String) -> AudioStreamWAV:
	if _streams.has(id):
		return _streams[id]
	_mutex.lock()
	var b: Variant = _bytes.get(id)
	_mutex.unlock()
	if b == null:
		return null
	var w := Kit.wav(b as PackedByteArray)
	_streams[id] = w
	return w


static func _bus(id: String) -> StringName:
	if id.begins_with("ui_") and AudioServer.get_bus_index("UI") >= 0:
		return &"UI"
	return &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"


## A cue now, non-positional (interface, the wanderer's own body, stingers). `db` is added to the cue's own level.
static func play(host: Node, id: String, db := 0.0, pitch := 1.0) -> void:
	if host == null or not host.is_inside_tree() or not RECIPES.has(id):
		return
	var s := stream(id)
	if s == null:
		return
	var a := AudioStreamPlayer.new()
	a.name = "Cue_" + id
	a.stream = s
	a.bus = _bus(id)
	a.volume_db = float((RECIPES[id] as Dictionary).db) + db
	a.pitch_scale = pitch
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


## A cue at a place, through the shared 3D voice pool.
static func play_at(id: String, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	var s := stream(id)
	if s == null or not RECIPES.has(id):
		return
	Sfx.play_stream(s, at, float((RECIPES[id] as Dictionary).db) + db, pitch)
