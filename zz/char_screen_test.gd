extends Node
## r35: the one character screen (ui/character_screen.gd). Headless, the real night:
##   - one key (inventory) opens it at Wanderer / Gear, paused, the gear panel hosted
##   - Q / E turn the pages, 1-4 the tabs; each page is the right old panel, hosted (its own tab
##     strip hidden), and only one shows at a time; the world stays paused through every switch
##   - Pack shows trophies and materials only (relics live on Wanderer / Relics)
##   - the old keys jump to their pages (K Kindling, a second K closes); the old panels' own opens
##     (a fire's Kindling, the Satchel's attune, the Journal at a page) are routed to the screen
##   - closing unpauses and leaves no panel open or hosted; a panel closed by itself closes the screen
## Holds Travel._busy; quits itself (90 s).
##   HOME=<scratch> godot --headless --path . res://zz/char_screen_test.tscn

var bad := 0
var main: Node
var t := 0.0
var _ran := false


func _ready() -> void:
	Travel._busy = true
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
	await _frames(30)
	var cs := get_tree().get_first_node_in_group(&"character_screen")
	_ok(cs != null, "the character screen is built")
	if cs == null:
		_finish()
		return
	var gear := get_tree().get_first_node_in_group(&"gear_panel")
	var growth := get_tree().get_first_node_in_group(&"growth")
	var codex := get_tree().get_first_node_in_group(&"codex")
	var tasks := get_tree().get_first_node_in_group(&"quest_log")
	var satchel: Node = null
	for n in get_tree().root.find_children("Satchel", "CanvasLayer", true, false):
		satchel = n
	_ok(gear != null and growth != null and codex != null and tasks != null and satchel != null, "all five old panels are there to host")
	var panels: Array = [gear, growth, codex, tasks, satchel]

	# one key opens it at Wanderer / Gear
	_action("inventory")
	await _frames(2)
	_ok(bool(cs.call("is_open")) and get_tree().paused, "the inventory key opens it, paused")
	_ok(cs.call("showing") == ["wanderer", "gear"], "at Wanderer / Gear (%s)" % str(cs.call("showing")))
	_ok(bool(gear.call("is_open")) and bool(gear.get("hosted")), "the gear panel is its page, hosted")
	_ok(_open_count(panels) == 1, "one page at a time")

	# pages and tabs
	_key(KEY_E)
	await _frames(2)
	_ok(cs.call("showing") == ["wanderer", "charms"] and bool(growth.call("is_open")) and not bool(gear.call("is_open")), "E turns to Charms (the Kindling's page, the gear panel closed)")
	_ok(get_tree().paused and _open_count(panels) == 1, "still paused, still one page")
	var bar: Control = growth.get("_tab_bar")
	_ok(bar != null and not bar.visible, "hosted, the Kindling's own tab strip is hidden")
	_key(KEY_2)
	await _frames(2)
	_ok(cs.call("showing")[0] == "kindling" and bool(growth.call("is_open")), "2: the Kindling tab")
	_key(KEY_E)
	await _frames(2)
	_ok(cs.call("showing") == ["kindling", "spells"], "E: Kindling / Spells (%s)" % str(cs.call("showing")))
	Travel.give("thorn_heart", 1, false)
	_key(KEY_3)
	await _frames(2)
	_ok(cs.call("showing")[0] == "pack" and bool(satchel.call("is_open")), "3: the Pack (the satchel, hosted)")
	var relic_listed := false
	for s: Variant in satchel.get("_slots"):
		var id := String((s as Dictionary).get("id", "")) if s is Dictionary else String(s.get("id")) if s is Object else ""
		if String(ItemDB.def(id).get("kind", "")) == "relic":
			relic_listed = true
	_ok(not relic_listed, "the Pack shows no relics (they are on Wanderer / Relics)")
	_key(KEY_4)
	await _frames(2)
	_ok(cs.call("showing") == ["journal", "journal"] and bool(codex.call("is_open")) and bool(codex.get("hosted")), "4: the Journal, hosted")
	_key(KEY_Q)
	await _frames(2)
	_ok(cs.call("showing") == ["journal", "tasks"] and bool(tasks.call("is_open")) and not bool(codex.call("is_open")), "Q wraps to Tasks (the ledger, the Journal closed)")
	_ok(get_tree().paused and _open_count(panels) == 1, "paused, one page, after every switch")

	# close
	_action("inventory")
	await _frames(2)
	_ok(not bool(cs.call("is_open")) and not get_tree().paused, "the inventory key closes it and unpauses")
	_ok(_open_count(panels) == 0 and not _any_hosted(panels), "no page left open or hosted")

	# the old keys jump, and toggle on their own page
	_action("kindling")
	await _frames(2)
	_ok(bool(cs.call("is_open")) and cs.call("showing")[0] == "kindling", "K opens it at the Kindling")
	_action("kindling")
	await _frames(2)
	_ok(not bool(cs.call("is_open")) and not get_tree().paused, "a second K closes it")
	_action("gear")
	await _frames(2)
	_ok(cs.call("showing") == ["wanderer", "gear"], "O opens it at Gear")
	_action("toggle_settings")
	await _frames(2)
	_ok(not bool(cs.call("is_open")), "Esc closes it")
	await _frames(2)
	var sm := _settings()
	var sr: Control = sm.get("_root") if sm else null
	if sr and sr.visible:
		sm.call("close")                      # Esc may also have reached Settings; not this test's business
		await _frames(2)

	# the old panels' own opens are routed here
	growth.call("open_menu", true)
	await _frames(2)
	_ok(bool(cs.call("is_open")) and cs.call("showing") == ["kindling", "embers"], "a fire's Kindling opens the screen at Embers (%s)" % str(cs.call("showing")))
	cs.call("close")
	await _frames(2)
	satchel.call("open_menu", true)
	await _frames(2)
	_ok(cs.call("showing") == ["wanderer", "relics"], "the Satchel's attune opens Wanderer / Relics (%s)" % str(cs.call("showing")))
	cs.call("close")
	await _frames(2)
	codex.call("open_book", 4)
	await _frames(2)
	_ok(cs.call("showing") == ["journal", "map"], "the Journal at its map page opens Journal / Map (%s)" % str(cs.call("showing")))
	# a page closed by itself closes the screen
	codex.call("close_book")
	await _frames(3)
	_ok(not bool(cs.call("is_open")) and not get_tree().paused, "a page that closes itself closes the screen and unpauses")
	_finish()


func _open_count(panels: Array) -> int:
	var n := 0
	for p: Node in panels:
		if bool(p.call("is_open")):
			n += 1
	return n


func _any_hosted(panels: Array) -> bool:
	for p: Node in panels:
		if bool(p.get("hosted")):
			return true
	return false


func _settings() -> Node:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.get_script() and String((c.get_script() as Script).resource_path).ends_with("settings_menu.gd"):
			return c
	return null


func _action(name: String) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	get_viewport().push_input(e)
	var u := InputEventAction.new()
	u.action = name
	u.pressed = false
	get_viewport().push_input(u)


func _key(kc: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = kc
	e.keycode = kc
	e.pressed = true
	get_viewport().push_input(e)
	var u := InputEventKey.new()
	u.physical_keycode = kc
	u.keycode = kc
	u.pressed = false
	get_viewport().push_input(u)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _finish() -> void:
	set_process(false)
	print("CHARSCREEN %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	get_tree().quit(0 if bad == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("CHARSCREEN ok   " if cond else "CHARSCREEN FAIL ") + what)
	if not cond:
		bad += 1
