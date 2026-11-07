extends Node
## The ash tithe at the Hearthward fire (headless, no world):
##   godot --headless --path . res://zz/hearth_tithe_test.tscn     (tools/run_tests.sh hearth_tithe)
## Ash buys rested XP (half a level, capped) or a one-night ward (a modest buff in the mods table, gone when
## the village's night turns over); both are refused away from the green, below the Hearthfire I, and without
## the ash; rested XP otherwise behaves as before. Holds Travel._busy (no save) and puts the state back after.
## Ends: TITHE TEST PASS  /  TITHE TEST FAIL n

const HearthDB := preload("res://core/life/progression/hearth_db.gd")
const HearthRT := preload("res://core/life/progression/hearth.gd")
const LevelDB := preload("res://core/life/progression/level.gd")
const DB := preload("res://core/life/progression/upgrade_db.gd")

var fails := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	Travel._busy = true
	var items0: Dictionary = Travel.items.duplicate(true)
	var systems0: Dictionary = Travel.systems.duplicate(true)
	Travel.systems = {}
	Travel.items = {}
	var h := HearthRT.new()
	add_child(h)
	await get_tree().process_frame
	_data()
	_rest(h)
	_ward(h)
	h.queue_free()
	Travel.items = items0
	Travel.systems = systems0
	print("TITHE TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _data() -> void:
	ok(HearthDB.TITHES.size() == 2, "two offerings: rested XP and the night-ward")
	for t: Dictionary in HearthDB.TITHES:
		# the sink is for ash past the upgrades (under 30) and the quests (up to 60): it has to be felt
		ok(int(t.price) > 30, "%s costs more than any upgrade (%d ash)" % [t.id, int(t.price)])
	ok(int(HearthDB.tithe("ward").price) > int(HearthDB.tithe("rest").price), "the ward, which gives power as well as XP, costs more")
	var m := {"gloom_add": 0.0, "dark_mult": 1.0, "ward_life": 0.0}
	HearthDB.apply(m, {"tier": 1, "ward": true})
	ok(bool(m.get("warded", false)) and float(m.ward_life) > 0.0 and float(m.dark_mult) < 1.0, "a warded save adds the ward to the mods table")
	var m2 := {"gloom_add": 0.0, "dark_mult": 1.0, "ward_life": 0.0}
	HearthDB.apply(m2, {"tier": 1})
	ok(not m2.has("warded") and is_equal_approx(float(m2.dark_mult), 1.0), "an unwarded save does not")


func _rest(h: Node) -> void:
	var hrt := h as HearthRT
	Travel.system_state("hearth")["tier"] = 0
	Travel.items["grave_ash"] = 500
	ok(hrt.why_not_tithe("rest", true).contains("draws"), "a banked fire takes no tithe: %s" % hrt.why_not_tithe("rest", true))
	Travel.system_state("hearth")["tier"] = 1
	ok(hrt.why_not_tithe("rest", false).begins_with("Only at Hearthward"), "not away from the green")
	Travel.items["grave_ash"] = 10
	ok(hrt.why_not_tithe("rest", true).begins_with("Needs"), "not without the ash: %s" % hrt.why_not_tithe("rest", true))
	Travel.items["grave_ash"] = 500
	var ps := Travel.system_state("progression")
	ps["memory"] = 0
	ps["rested_xp"] = 0
	var price := int(HearthDB.tithe("rest").price)
	ok(hrt.tithe("rest", true) == "", "the tithe is paid")
	ok(Travel.count("grave_ash") == 500 - price, "the ash is spent (%d left)" % Travel.count("grave_ash"))
	ok(int(ps.rested_xp) == roundi(float(40) * LevelDB.REST_FILL), "half a level of rested XP is kept (%d)" % int(ps.rested_xp))
	ok(LevelDB.with_rested(ps, 10, "kill")[0] == 20, "kills pay double from it, as a rest's pool does")
	ok(hrt.tithe("rest", true) == "" and hrt.tithe("rest", true) == "" and hrt.why_not_tithe("rest", true) != "", "it fills to the cap and then refuses")
	ok(int(ps.rested_xp) <= roundi(40.0 * LevelDB.REST_CAP), "never past a level and a half (%d)" % int(ps.rested_xp))


func _ward(h: Node) -> void:
	var hrt := h as HearthRT
	var hs := Travel.system_state("hearth")
	Travel.items["grave_ash"] = 200
	ok(not hrt.ward_active(), "no ward to begin with")
	ok(hrt.tithe("ward", true) == "" and hrt.ward_active(), "the ward is given")
	ok(Travel.count("grave_ash") == 200 - int(HearthDB.tithe("ward").price), "its ash is spent")
	ok(hrt.why_not_tithe("ward", true).contains("still holds"), "a ward already up is not bought twice: %s" % hrt.why_not_tithe("ward", true))
	# the night turns over: the ward goes with it
	hs["ward_night"] = int(hs.get("ward_night", 0)) - 1
	hrt.step(1.0)
	ok(not hrt.ward_active(), "the ward ends when the night does")
	ok(hrt.why_not_tithe("ward", true) == "", "and can be given again the next night")
