extends Node
## Renders of the Kindling's PATHS and HEARTH tabs and the forge's shop (hearth.gd), in game:
##   godot --path . res://zz/hearth_shot.tscn [-- --out=<dir>]  -> <dir>/hearth_<n>.png (default user://)
## Progress is set in memory only (Travel saving held off).
const OUT_DEFAULT := "user://"
var main: Node
var out := OUT_DEFAULT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_window().size = Vector2i(1600, 1000)
	Travel.set("_busy", true)
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 120, "relic_fragment": 2}
	Travel.systems = {"progression": {"memory": 900, "paths": {"h_hands": 1, "h_breath": 1, "r_will": 1, "w_feet": 1, "w_stride": 1}},
		"hearth": {"tier": 1, "works": {"baskets": true}, "meals": {"hearty": {"id": "bread", "left": 200.0}}, "rested": 300.0}}
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if main.has_meta("realm_done"):
			break
	await get_tree().create_timer(2.0).timeout
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if (load("res://core/life/progression/hearth.gd") as GDScript).call("is_home_fire", n):
			p.teleport((n as Node).call("spawn_point"))
	await get_tree().create_timer(1.0).timeout
	var g := get_tree().get_first_node_in_group("growth")
	g.call("open_menu", true, "paths")
	await _shot("paths")
	g.call("show_tab", 8)
	await _shot("hearth")
	g.call("close_menu")
	var story := get_tree().get_first_node_in_group("story")
	story.call("open_shop", "hild")
	await get_tree().create_timer(1.5, true, false, true).timeout
	await _shot("forge")
	get_tree().quit(0)


func _shot(n: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out.path_join("hearth_%s.png" % n)
	get_viewport().get_texture().get_image().save_png(path if path.begins_with("/") else ProjectSettings.globalize_path(path))
	print("shot ", path)
