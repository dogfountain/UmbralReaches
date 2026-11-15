extends Node
## The TASK DONE banner with the XP the task paid (windowed, the real night). Never writes the save.
##   godot --path <abs worktree path> res://zz/task_banner_shot.tscn -- --tag=after [--size=1600x1000]
## -> shots/<tag>_task_done.png
const Chains := preload("res://core/story/quest_chains.gd")
var main: Node
var tag := "after"
var size := Vector2i(1600, 1000)
var _ran := false
var t := 0.0


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
	if t > 160.0:                      # hard watchdog: a windowed run never outlives two minutes
		print("TASKSHOT timeout")
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
	print("TASKSHOT ", path)


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
	var ql := get_tree().get_first_node_in_group("quest_log")
	var id := String(Chains.ORDER[0])
	ql.get("_last_state")[id] = [0, false]
	ql.call("_on_changed", id, (Chains.QUESTS[id].steps as Array).size(), true)
	await get_tree().create_timer(13.0).timeout
	await _shot("task_done")
	print("TASKSHOT xp ", ql.call("task_xp", id), " ash ", (Chains.QUESTS[id].get("reward", {}) as Dictionary).get("ash", 0))
	get_tree().quit()
