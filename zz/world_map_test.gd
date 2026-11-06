extends Node
## The world map (ui/world_map.gd). Headless, the real night:
##   - M (the world_map action) opens it, paused; M again closes and unpauses; Esc closes too
##   - it will not open over another held pause, and closing from outside (release) unpauses
##   - the sheet bakes (water, relief, the ways) and the fog follows the journal: a walked region is
##     uncovered, a far one is not; the border margin always shows
##   - marks: the wanderer is pinned, no cold fire in unwalked ground is
##   - N now toggles the minimap, M no longer does
## Holds Travel._busy; quits itself (90 s).
##   HOME=<scratch> godot --headless --path . res://zz/world_map_test.tscn

const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
var bad := 0
var main: Node
var t := 0.0
var _ran := false


func _ready() -> void:
	Travel._busy = true
	CodexStore.persist = false
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
	var wm := get_tree().get_first_node_in_group(&"world_map")
	_ok(wm != null, "the world map is built")
	if wm == null:
		_finish()
		return
	CodexStore.places.clear()
	CodexStore.places["hearth"] = 1
	var waited := 0
	while not bool(wm.call("is_baked")) and waited < 600:
		await _frames(10)
		waited += 10
	_ok(bool(wm.call("is_baked")), "the sheet is baked off the frame (%d frames)" % waited)
	await _frames(5)

	_ok(not get_tree().paused and not bool(wm.call("is_open")), "closed, the night runs")
	_action("world_map")
	await _frames(2)
	_ok(bool(wm.call("is_open")) and get_tree().paused, "M opens it, paused")
	_action("world_map")
	await _frames(2)
	_ok(not bool(wm.call("is_open")) and not get_tree().paused, "M closes it, unpaused")
	_action("world_map")
	await _frames(2)
	_action("toggle_settings")
	await _frames(2)
	_ok(not bool(wm.call("is_open")) and not get_tree().paused, "Esc closes it, unpaused")
	_action("world_map")
	await _frames(2)
	wm.call("release")
	await _frames(2)
	_ok(not bool(wm.call("is_open")) and not get_tree().paused, "closed from outside, the night is released")

	get_tree().paused = true
	_action("world_map")
	await _frames(2)
	_ok(not bool(wm.call("is_open")), "it does not open over another menu's pause")
	get_tree().paused = false

	_action("world_map")
	await _frames(2)
	var hearth: Vector2 = RealmLayout.REGIONS[0].c
	var far := Vector2(235.0, 190.0)            # the White Pans, unwalked
	_ok(float(wm.call("fog_at", hearth.x, hearth.y)) > 0.95, "Hearthward (walked) is uncovered")
	_ok(float(wm.call("fog_at", far.x, far.y)) < 0.05, "the White Pans (unwalked) are fogged")
	_ok(float(wm.call("fog_at", -305.0, 300.0)) > 0.95, "the border margin always shows")
	var rev: Array = wm.call("revealed_regions")
	_ok("hearth" in rev and not ("saltpans" in rev), "only walked regions are lettered")
	var kinds := {}
	var cold_far := 0
	for m: Dictionary in wm.call("marks"):
		kinds[String(m.kind)] = int(kinds.get(String(m.kind), 0)) + 1
		if String(m.kind) == "ash" and float(wm.call("fog_at", m.at.x, m.at.y)) < 0.5:
			cold_far += 1
	_ok(kinds.has("you"), "the wanderer is pinned (%s)" % str(kinds))
	_ok(cold_far == 0, "no cold fire is pinned in unwalked ground")
	_action("world_map")
	await _frames(2)
	CodexStore.places["saltpans"] = 2
	_action("world_map")
	await _frames(2)
	_ok(float(wm.call("fog_at", far.x, far.y)) > 0.95, "after walking the pans they are uncovered")
	_action("world_map")
	await _frames(2)

	var mm := get_tree().root.find_child("Minimap", true, false)
	_ok(mm != null, "the minimap is there")
	if mm:
		var r0: int = mm.get("_range_i")
		_key(KEY_M)
		await _frames(2)
		_ok(bool(wm.call("is_open")) and int(mm.get("_range_i")) == r0, "M opens the map and leaves the minimap alone")
		_key(KEY_M)
		await _frames(2)
		_key(KEY_N)
		await _frames(2)
		_ok(int(mm.get("_range_i")) == r0 + 1 and not bool(wm.call("is_open")), "N cycles the minimap")
	_finish()


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
	print("WORLDMAP %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	get_tree().quit(0 if bad == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	print(("WORLDMAP ok   " if cond else "WORLDMAP FAIL ") + what)
	if not cond:
		bad += 1
