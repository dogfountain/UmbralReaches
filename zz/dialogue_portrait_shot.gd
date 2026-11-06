extends Node
## Talks to two villagers in the real night and shoots the box twice each (the mouth moves while the line types).
##   godot --path . res://zz/dialogue_portrait_shot.tscn -- --tag=portrait   -> shots/<tag>_<n>_a/b.png
## Hard watchdog: quits itself within 120 s. Never writes the save.
var main: Node
var tag := "portrait"
var t := 0.0
var _ran := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	get_window().size = Vector2i(1600, 1000)
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 120.0:
		print("PORTRAIT_SHOT timeout")
		get_tree().quit(1)
	if not _ran and is_instance_valid(main) and main.has_meta("realm_done") and t > 9.0:
		_ran = true
		_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s_%s.png" % [tag, n]))
	print("PORTRAIT_SHOT ", n)


func _run() -> void:
	await _frames(30)
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER)
	var vs := get_tree().get_nodes_in_group("villager")
	print("PORTRAIT villagers ", vs.size())
	var done := 0
	for v: Node in vs:
		if done >= 2:
			break
		if not bool(v.call("can_interact")):
			continue
		v.call("interact", pl)
		await get_tree().create_timer(1.2, true, false, true).timeout
		await _shot("%d_a" % done)
		await get_tree().create_timer(0.35, true, false, true).timeout
		await _shot("%d_b" % done)
		var ui := get_tree().get_first_node_in_group("story").get("ui") as CanvasLayer
		print("PORTRAIT ", v.get("id"), " frame visible ", ((ui.get("_portrait") as Control).get_parent() as Control).visible)
		ui.call("close")
		await _frames(10)
		done += 1
	var story := get_tree().get_first_node_in_group("story")
	for cid: String in ["keep", "hesk"]:
		if story.call("talk", cid, null, pl):
			await get_tree().create_timer(1.2, true, false, true).timeout
			await _shot("story_%s_a" % cid)
			await get_tree().create_timer(0.35, true, false, true).timeout
			await _shot("story_%s_b" % cid)
			var ui2 := story.get("ui") as CanvasLayer
			ui2.call("close")
			await _frames(10)
	get_tree().quit(0)
