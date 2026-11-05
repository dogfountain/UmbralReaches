extends Node
## Render the settings menu: godot --path . res://zz/settings_shot.tscn -> shots/settings_<n>.png
var t := 0.0
var shots := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true   # never write Luke's save from a capture run
	get_window().size = Vector2i(1600, 900)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	if t > 8.0 and shots == 0:
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if c.has_method("open") and c.get_script() and String(c.get_script().resource_path).ends_with("settings_menu.gd"):
				c.call("open")
		shots = 1
	elif shots >= 1 and t > 8.6 + 0.5 * shots:
		var menu: Node = null
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if c.get_script() and String(c.get_script().resource_path).ends_with("settings_menu.gd"):
				menu = c
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/settings_%d.png" % (shots - 1)))
		if shots >= 4:
			print("SETTINGS_SHOT saved")
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())
			return
		if menu and menu.has_method("_show_tab"):
			menu.call("_show_tab", shots)
		shots += 1
