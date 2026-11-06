extends Node
## The gear page on its own (no night): the character screen band, the gear panel and a gear runtime,
## fed a staged bag. Windowed, a few seconds; the real save is held off (Travel._busy).
##   godot --path . res://zz/gear_ui_shot.tscn --resolution 1600x1000 -- --out=<dir> [--probe]
## -> <dir>/gear_<scene>_<WxH>.png. --probe runs headless-safe (no screenshots) and prints what it built.

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
const CharScreen := preload("res://ui/character_screen.gd")
const GearPanel := preload("res://ui/gear_panel.gd")

var out := "res://shots"
var probe := false
var panel: Node
var cs: Node
var rng := RandomNumberGenerator.new()
var t := 0.0


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		if a == "--probe":
			probe = true
	rng.seed = 11
	var rt := GearRuntime.new()
	rt.add_to_group("gear")
	add_child(rt)
	panel = GearPanel.new()
	add_child(panel)
	cs = CharScreen.new()
	add_child(cs)
	_run.call_deferred()


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 100.0:
		print("GEARSHOT watchdog")
		get_tree().quit(1)


func _piece(opts: Dictionary) -> Dictionary:
	var p := GearDB.make(rng, opts)
	GearRuntime.store(p)
	return p


func _stage(full: bool) -> void:
	Travel.systems.erase("gear")
	var st := GearStats.state()
	GearStats.seen_init(st)
	var k1 := _piece({"slot": "focus", "rarity": 2, "set": "kindler"})
	var v1 := _piece({"slot": "vestment", "rarity": 3, "set": "kindler"})
	var l1 := _piece({"slot": "lantern", "rarity": 1})
	var g1 := _piece({"slot": "girdle", "rarity": 2})
	# carried: a spread of rarities and slots, some set pieces, a named one and a legend
	_piece({"slot": "lantern", "rarity": 3, "set": "ferryman"})
	_piece({"slot": "focus", "rarity": 3, "named": "heartwood_cup"})
	_piece({"legend": "sunk_shroud"})
	_piece({"slot": "lantern", "rarity": 3})
	_piece({"slot": "girdle", "rarity": 4, "legend": "stair_rope"})
	for i in 11:
		_piece({"rarity": [0, 1, 1, 2, 2, 3][i % 6]})
	_piece({"slot": "focus", "rarity": 2, "set": "kindler"})
	_piece({"slot": "girdle", "rarity": 3, "set": "kindler"})
	(st.worn as Dictionary).clear()
	if full:
		st.worn["focus"] = k1.uid
		st.worn["vestment"] = v1.uid
		st.worn["lantern"] = l1.uid
		st.worn["girdle"] = g1.uid
	# every one seen but the last two, so the new marker shows on those
	var seen := GearStats.seen_init(st)
	seen.clear()
	for p: Variant in st.bag:
		seen.append(int((p as Dictionary).uid))
	seen.pop_back()
	seen.pop_back()
	Travel.give("thorn_heart", 1, false)
	Travel.give("ember_shard", 40, false)
	Travel.give("grave_ash", 120, false)
	Travel.give("relic_fragment", 3, false)


func _shot(tag: String) -> void:
	for i in 14:
		await get_tree().process_frame
	var win := DisplayServer.window_get_size()
	var img := get_viewport().get_texture().get_image()
	var path := "%s/gear_%s_%dx%d.png" % [out, tag, win.x, win.y]
	img.save_png(path if path.begins_with("/") else ProjectSettings.globalize_path(path))
	print("GEARSHOT ", path, " vp ", get_viewport().get_visible_rect().size)


func _select_first(pred: Callable) -> void:
	var st := GearStats.state()
	for p: Dictionary in st.bag:
		if pred.call(p):
			panel.set("_sel_uid", int(p.uid))
			panel.call("_rebuild")
			return


func _act(a: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
	for i in 3:
		await get_tree().process_frame


## Headless checks of the page's flow: controller focus, wear by accept, drag and drop, filters, sort.
func _probe() -> void:
	var fails := 0
	var f0 := get_viewport().gui_get_focus_owner()
	print("PROBE focus ", f0)
	await _act("ui_right")
	var f1 := get_viewport().gui_get_focus_owner()
	print("PROBE after right ", f1, " moved ", f1 != f0)
	if f1 == f0 or f1 == null:
		fails += 1
	for i in 3:
		await _act("ui_left")
	var f2 := get_viewport().gui_get_focus_owner()
	print("PROBE far left ", f2)
	# select a carried lantern and wear it by accept
	_select_first(func(p: Dictionary) -> bool: return String(p.slot) == "lantern" and int(p.rarity) == 3 and String(p.get("set", "")) == "")
	var uid := int(panel.get("_sel_uid"))
	for c: Control in panel.get("_cells"):
		if int(c.call("uid")) == uid:
			c.grab_focus()
	await _act("ui_accept")
	var worn := int(GearStats.state().worn.get("lantern", -1))
	print("PROBE worn lantern ", worn, " want ", uid)
	if worn != uid:
		fails += 1
	# drop a carried girdle on its socket: it is worn
	var other := 0
	for p: Dictionary in GearStats.state().bag:
		if String(p.slot) == "girdle" and int(p.uid) != int(GearStats.state().worn.get("girdle", -1)):
			other = int(p.uid)
			break
	var sock: Control = (panel.get("_sockets") as Dictionary)["girdle"]
	var data := {"gear_uid": other, "slot": "girdle", "from_socket": false}
	print("PROBE can drop ", sock.call("_can_drop_data", Vector2.ZERO, data))
	sock.call("_drop_data", Vector2.ZERO, data)
	var wg := int(GearStats.state().worn.get("girdle", -1))
	print("PROBE worn girdle ", wg, " want ", other)
	if wg != other:
		fails += 1
	var wrong := {"gear_uid": uid, "slot": "lantern", "from_socket": false}
	if bool(sock.call("_can_drop_data", Vector2.ZERO, wrong)):
		fails += 1
		print("PROBE wrong slot accepted")
	# drag a worn piece to the pack: takes it off
	var cell: Control = (panel.get("_cells") as Array)[0]
	cell.call("_drop_data", Vector2.ZERO, {"gear_uid": wg, "slot": "girdle", "from_socket": true})
	if GearStats.state().worn.has("girdle"):
		fails += 1
		print("PROBE girdle still worn")
	# filter and sort
	panel.call("_pick_slot", "focus")
	var n_focus := (panel.get("_rows") as Array).size()
	var all_focus := true
	for id: int in panel.get("_rows"):
		all_focus = all_focus and String(GearStats.find(GearStats.state(), id).slot) == "focus"
	print("PROBE focus filter ", n_focus, " all focus ", all_focus)
	if not all_focus or n_focus == 0:
		fails += 1
	panel.call("_pick_slot", "")
	panel.set("_sort", 1)
	panel.call("_rebuild")
	var last := 9999
	var sorted := true
	for id: int in panel.get("_rows"):
		var il := GearDB.item_level(GearStats.find(GearStats.state(), id))
		sorted = sorted and il <= last
		last = il
	print("PROBE ilvl sort ", sorted)
	if not sorted:
		fails += 1
	# the new marker clears once a piece is looked at
	var st := GearStats.state()
	var fresh := -1
	for p: Dictionary in st.bag:
		if GearStats.is_new(st, int(p.uid)):
			fresh = int(p.uid)
	print("PROBE new piece ", fresh)
	panel.set("_sel_uid", fresh)
	panel.call("_rebuild")
	print("PROBE new cleared ", not GearStats.is_new(GearStats.state(), fresh))
	if fresh < 0 or GearStats.is_new(GearStats.state(), fresh):
		fails += 1
	var ic: Node = panel.get("_icons")
	print("PROBE icons made ", ic.call("made"))
	print("PROBE ", ("FAIL %d" % fails) if fails > 0 else "ok")


func _run() -> void:
	await get_tree().process_frame
	_stage(true)
	cs.call("open_at", "wanderer", "gear")
	for i in 30:
		await get_tree().process_frame
	print("GEARPROBE open ", panel.call("is_open"), " cells ", (panel.get("_cells") as Array).size(), " rows ", (panel.get("_rows") as Array).size())
	if probe:
		await _probe()
		get_tree().quit(0)
		return
	# 1 full gear: a better lantern than the worn one, with the compare
	_select_first(func(p: Dictionary) -> bool: return String(p.slot) == "lantern" and int(p.rarity) == 3 and String(p.get("set", "")) == "")
	await _shot("full")
	# 2 a set piece: a Kindler piece carried while two are worn
	_select_first(func(p: Dictionary) -> bool: return String(p.get("set", "")) == "kindler" and String(p.slot) == "girdle")
	await _shot("setpiece")
	# 3 a legend
	_select_first(func(p: Dictionary) -> bool: return String(p.get("legend", "")) == "stair_rope")
	await _shot("legend")
	# 4 empty slots
	cs.call("close")
	_stage(false)
	cs.call("open_at", "wanderer", "gear")
	await _shot("empty")
	cs.call("close")
	get_tree().quit(0)
