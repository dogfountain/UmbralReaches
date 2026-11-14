extends Node
## Every menu page as the player sees it (windowed, the real night). Never writes the save.
##   godot --path . res://zz/menu_shots.tscn -- --tag=after [--size=1600x1000]
## -> shots/<tag>_<page>.png: hud, settings_0..3, char_<tab>_<page>, gear_panel, loot, dialogue, offer, shop, title.
const TitleScreen := preload("res://ui/title_screen.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
var main: Node
var tag := "after"
var size := Vector2i(1600, 1000)
var _ran := false
var t := 0.0
const PAGES := [["wanderer", "gear"], ["wanderer", "relics"], ["kindling", "embers"], ["kindling", "spells"], ["kindling", "loadout"],
	["pack", ""], ["journal", "journal"], ["journal", "tasks"]]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--size="):
			var v := a.trim_prefix("--size=").split("x")
			size = Vector2i(int(v[0]), int(v[1]))
	get_window().size = size
	Travel._busy = true
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 60, "relic_fragment": 2, "ember_shard": 7, "ash_bloom": 4, "grave_iron": 3, "charm_candle": 1, "thorn_heart": 1}
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 120.0:                      # hard watchdog: a windowed run never outlives two minutes
		print("MENU_SHOT timeout")
		get_tree().quit(1)
	if not _ran and is_instance_valid(main) and main.has_meta("realm_done") and t > 9.0:
		_ran = true
		_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(n: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://shots/%s_%s.png" % [tag, n])
	get_viewport().get_texture().get_image().save_png(path)
	print("MENU_SHOT ", path)


func _layer(script_end: String) -> Node:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.get_script() and String((c.get_script() as Script).resource_path).ends_with(script_end):
			return c
	return null


func _run() -> void:
	get_window().size = size
	await _frames(30)
	for en in get_tree().get_nodes_in_group(Groups.ENEMY):
		(en as Node).queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	GearRuntime.store(GearDB.make(rng, {"rarity": 1, "slot": "focus", "set": "kindler"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 2, "slot": "lantern", "set": "kindler"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 3, "slot": "focus"}))
	await _shot("hud")
	var sm := _layer("settings_menu.gd")
	for i in 4:
		if not sm.get("_root").visible:
			sm.call("open")
		sm.call("_show_tab", i)
		await _shot("settings_%d" % i)
	sm.call("close")
	var cs := get_tree().get_first_node_in_group(&"character_screen")
	for pg: Array in PAGES:
		cs.call("open_at", pg[0], pg[1])
		await _shot("char_%s_%s" % [pg[0], pg[1] if pg[1] != "" else "all"])
	cs.call("close")
	await _frames(4)
	Events.boss_slain.emit("bone_abbot")
	await get_tree().create_timer(1.0).timeout
	var bag := get_tree().get_first_node_in_group("loot_bag")
	if bag:
		bag.call("open_window")
		await _shot("loot")
		get_tree().get_first_node_in_group("loot_window").call("take_all")
	var dl := _layer("dialogue.gd")
	dl.call("open", "Grisel the Ash-Wife", {"seated": false, "seed": 911, "hat": "hood"})
	var ch: Array[String] = ["What do you sell?", "Tell me of the Ossuary.", "Farewell."]
	dl.call("line", "Grisel the Ash-Wife", "Ash for the fires, wanderer. The dead pay in it and so do the living, if they have any sense left in them.", ch)
	await get_tree().create_timer(4.0, true, false, true).timeout
	await _shot("dialogue")
	dl.call("close")
	var qo := get_tree().get_first_node_in_group("quest_offer")
	if qo:
		qo.call("open_offer", "edda_tongs", "Edda")
		await _shot("offer")
		qo.call("close")
	var story := get_tree().get_first_node_in_group("story")
	if story:
		story.call("open_shop", "grisel")
		await get_tree().create_timer(0.5, true, false, true).timeout
		await _shot("shop")
		var shop: Node = story.get("shop")
		shop.call("set_tab", 1)
		await _shot("shop_sell")
		shop.call("close")
	var ts := TitleScreen.new()
	get_tree().root.add_child(ts)
	await get_tree().create_timer(1.6, true, false, true).timeout        # at rest: the veil has lifted and the glow has breathed in
	await _shot("title")
	ts.queue_free()
	get_tree().quit(0)
