extends Node
## r33 loot renders (windowed): a great one's hoard bag and the loot window, the gear panel's
## tooltip, the shop's SELL tab, the satchel, a gathering node in the world.
##   godot --path . res://zz/loot_r33_shot.tscn -- --out=<dir>   -> <dir>/loot_<n>.png
## Nothing is saved (Travel._busy).
const GearDB := preload("res://core/items/gear_db.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
var main: Node
var out := "user://"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_window().size = Vector2i(1600, 1000)
	Travel.set("_busy", true)
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 60, "relic_fragment": 2, "ember_shard": 7, "ash_bloom": 4, "grave_iron": 3, "charm_candle": 1, "thorn_heart": 1}
	Travel.systems = {"progression": {"memory": 300, "rested_xp": 30, "paths": {}}}
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if main.has_meta("realm_done"):
			break
	await get_tree().create_timer(2.0).timeout
	for en in get_tree().get_nodes_in_group(Groups.ENEMY):
		(en as Node).queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	GearRuntime.store(GearDB.make(rng, {"rarity": 1, "slot": "focus", "set": "kindler"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 2, "slot": "lantern", "set": "kindler"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 3, "slot": "focus"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 0, "slot": "girdle"}))
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var nodes := get_tree().get_nodes_in_group("gather_node")
	for kind: String in ["ash_bloom", "grave_iron"]:
		for g: Node3D in nodes:
			if String(g.get("kind")) == kind:
				p.call("teleport", g.global_position + Vector3(1.6, 0.3, 4.2))
				await get_tree().create_timer(1.5).timeout
				await _shot("gather_" + kind)
				break
	Events.boss_slain.emit("bone_abbot")
	await get_tree().create_timer(1.0).timeout
	await _shot("bag")
	var bag := get_tree().get_first_node_in_group("loot_bag")
	if bag:
		bag.call("open_window")
		await get_tree().create_timer(0.3).timeout
		await _shot("window")
		get_tree().get_first_node_in_group("loot_window").call("take_all")
	var gp := get_tree().get_first_node_in_group("gear_panel")
	gp.call("open_menu")
	await _shot("gear_panel")
	gp.call("close_menu")
	var story := get_tree().get_first_node_in_group("story")
	if story:
		story.call("open_shop", "grisel")
		await get_tree().create_timer(0.5, true, false, true).timeout
		var shop: Node = story.get("shop")
		shop.call("set_tab", 1)
		await _shot("shop_sell")
		shop.call("close")
	var sat := main.get_node_or_null("Satchel")
	if sat:
		sat.call("open_menu")
		sat.call("select_id", "thorn_heart")
		await _shot("satchel")
		sat.call("close_menu")
	get_tree().quit(0)


func _shot(n: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out.path_join("loot_%s.png" % n)
	get_viewport().get_texture().get_image().save_png(path if path.begins_with("/") else ProjectSettings.globalize_path(path))
	print("shot ", path)
