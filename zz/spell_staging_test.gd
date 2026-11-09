extends Node
## r35: start with Rift Bolt; the story teaches the other four (core/life/progression/kindling.gd teach).
## Headless, the real night, a fresh save, staging switched on (Engine meta "staged_spells"):
##   - a new game knows only Rift Bolt; slots 1-4 are sealed (they cast nothing, say why)
##   - the Keep's first talk ("teach:ward"), the first kill, the first seal and the first great one
##     each teach one spell into its slot, once; the Kindling's ranks are refused for untaught spells
##   - a save from before staging (no "taught") knows all five
## Holds Travel._busy; quits itself (90 s).
##   HOME=<scratch> godot --headless --path . res://zz/spell_staging_test.tscn

const DB := preload("res://core/life/progression/upgrade_db.gd")
const QuestBook := preload("res://core/story/quest_book.gd")

var bad := 0
var main: Node
var t := 0.0
var _ran := false


func _ready() -> void:
	Engine.set_meta(&"staged_spells", true)
	Travel._busy = true
	# Windows user:// is not HOME-isolated: wipe the slot so a real save cannot hand every spell
	Travel.use_slot(1, true)
	# drop any taught list a prior Kindling wrote into systems before this scene ran
	var st: Dictionary = Travel.system_state("progression")
	st["taught"] = []
	st.erase("known")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 90.0:
		_ok(false, "timed out")
		_finish()
		return
	if not _ran and is_instance_valid(main) and main.has_meta("realm_done"):
		_ran = true
		_run()


func _run() -> void:
	await _frames(20)
	var k := get_tree().get_first_node_in_group(&"progression")
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	var book := p.skills()
	var st: Dictionary = k.call("state")
	_ok(st.get("taught", null) is Array and (st.taught as Array).is_empty(), "a new game has nothing taught yet")
	_ok(DB.known(st) == ["bolt"], "it knows only Rift Bolt (%s)" % str(DB.known(st)))
	_ok(book.slots[0].id == &"bolt", "slot 0 is Rift Bolt")
	var sealed := 0
	for i in range(1, 5):
		if book.slots[i].id == &"sealed":
			sealed += 1
	_ok(sealed == 4, "slots 1-4 are sealed (%d)" % sealed)
	_ok(not book.try_cast(1, 0.0, true), "a sealed slot casts nothing")
	_ok(String(k.call("why_not", "nova", true)) == "Not yet taught.", "the Kindling refuses ranks for an untaught spell")

	QuestBook.run("flag:met_keep,teach:ward")
	await _frames(2)
	_ok(DB.knows(st, "ward") and book.slot_of(&"ward") >= 1, "the Keep's first talk teaches Lantern Ward, onto the bar")
	Events.enemy_killed.emit(p)            # any kill near you (the relief reads its position)
	await _frames(2)
	_ok(DB.knows(st, "lance") and book.slot_of(&"lance") >= 1, "the first kill teaches Ember Lance")
	Events.seal_broken.emit("henge")
	await _frames(2)
	_ok(DB.knows(st, "step") and book.slot_of(&"step") >= 1, "the first seal teaches Rift Step")
	Events.boss_slain.emit("thornwarden")
	await _frames(2)
	_ok(DB.knows(st, "nova") and book.slot_of(&"nova") >= 1, "the first great one teaches Umbral Nova")
	var still := 0
	for i in range(1, 5):
		if book.slots[i].id == &"sealed":
			still += 1
	_ok(still == 0, "every slot is filled now")
	_ok(not bool(k.call("teach", "nova")), "a spell is taught once")
	_ok(DB.taught({}).size() == 4, "a save from before staging (no 'taught') knows all four")
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _finish() -> void:
	Engine.remove_meta(&"staged_spells")
	set_process(false)
	print("STAGING %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	get_tree().quit(0 if bad == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("STAGING ok   " if cond else "STAGING FAIL ") + what)
	if not cond:
		bad += 1
