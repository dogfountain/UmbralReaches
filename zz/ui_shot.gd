extends Node
## Every UI screen at one window size, as the player sees it (needs a renderer):
##   HOME=<scratch> godot --path . res://zz/ui_shot.tscn -- --size=1280x720 [--tag=critF] [--only=settings]
## -> shots/<tag>_ui_<W>x<H>_<screen>.png: hud, settings_0..3, satchel, kindling, journal, map,
## tasks, dialogue, shop. Also prints UI_FIT <screen> lines: any visible Control whose rect
## leaves the visible canvas, and any Label whose on-screen font is under 11 physical px.
## Never writes the save (Travel._busy); quits itself (real-time cap 120 s).
var main: Node
var t := 0.0
var size := Vector2i(1600, 900)
var tag := "critF"
var only := ""
var _step := -1
var _wait := 0.0
var _steps: Array = []
var _done_steps := 0
var canvas := Vector2i.ZERO        ## --canvas=1920x1080: force the UI canvas (before/after of the r29 small-window canvas)
var layer := -1                    ## --settings-layer=50: force the settings menu's layer (before/after)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			var v := a.trim_prefix("--size=").split("x")
			size = Vector2i(int(v[0]), int(v[1]))
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a.begins_with("--canvas="):
			var c := a.trim_prefix("--canvas=").split("x")
			canvas = Vector2i(int(c[0]), int(c[1]))
		elif a.begins_with("--settings-layer="):
			layer = int(a.trim_prefix("--settings-layer="))
	get_window().size = size
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 120.0:
		print("UI_SHOT timeout")
		_quit()
		return
	if _step < 0:
		if main.has_meta("realm_done") and t > 9.0:
			get_window().size = size
			if canvas != Vector2i.ZERO:
				get_window().content_scale_size = canvas
			if layer >= 0 and _layer("settings_menu.gd"):
				(_layer("settings_menu.gd") as CanvasLayer).layer = layer
			_build_steps()
			_step = 0
			_wait = 1.0
		return
	_wait -= d
	if _wait > 0.0:
		return
	if _step >= _steps.size():
		print("UI_SHOT done %d shots at %dx%d" % [_done_steps, size.x, size.y])
		_quit()
		return
	var s: Array = _steps[_step]
	var phase: int = s[3]
	if phase == 0:
		(s[1] as Callable).call()
		s[3] = 1
		_wait = 0.6
		return
	var shot_name: String = s[0]
	if only == "" or shot_name.begins_with(only):
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://shots/%s_ui_%dx%d_%s.png" % [tag, size.x, size.y, shot_name]))
		_fit_report(shot_name)
		_done_steps += 1
	(s[2] as Callable).call()
	_step += 1
	_wait = 0.3


func _layer(script_end: String) -> Node:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.get_script() and String((c.get_script() as Script).resource_path).ends_with(script_end):
			return c
	return null


func _build_steps() -> void:
	var nop := func() -> void: pass
	_steps.append(["hud", nop, nop, 0])
	var sm := _layer("settings_menu.gd")
	if sm:
		for i in 4:
			var idx := i
			_steps.append(["settings_%d" % i, func() -> void:
				if not sm.get("_root").visible:
					sm.call("open")
				sm.call("_show_tab", idx), func() -> void:
				if idx == 3:
					sm.call("close"), 0])
	var sat := _layer("satchel.gd")
	if sat:
		_steps.append(["satchel", func() -> void: sat.call("open_menu", false), func() -> void: sat.call("close_menu"), 0])
	var gr := _layer("growth.gd")
	if gr:
		_steps.append(["kindling", func() -> void: gr.call("open_menu", false), func() -> void: gr.call("close_menu"), 0])
	var cx := _layer("codex.gd")
	if cx:
		_steps.append(["journal", func() -> void: cx.call("open_book", 0), func() -> void: cx.call("close_book"), 0])
		_steps.append(["map", func() -> void: cx.call("open_book", 4), func() -> void: cx.call("close_book"), 0])
	var ql := _layer("quest_log.gd")
	if ql:
		_steps.append(["tasks", func() -> void: ql.call("open"), func() -> void: ql.call("close"), 0])
	var dl := _layer("dialogue.gd")
	if dl:
		_steps.append(["dialogue", func() -> void:
			dl.call("open", "Grisel the Ash-Wife")
			var ch: Array[String] = ["What do you sell?", "Tell me of the Ossuary.", "Farewell."]
			dl.call("line", "Grisel the Ash-Wife", "Ash for the fires, wanderer. The dead pay in it and so do the living, if they have any sense left in them.", ch), func() -> void: dl.call("close"), 0])
	var st := get_tree().get_first_node_in_group("story")
	if st:
		_steps.append(["shop", func() -> void: st.call("open_shop", "grisel"), func() -> void:
			var sh: Node = st.get("shop")
			if is_instance_valid(sh):
				sh.call("close"), 0])


## Controls that leave the visible canvas, and text too small to read at this window size.
func _fit_report(shot_name: String) -> void:
	var vis := get_viewport().get_visible_rect()
	var phys := float(get_window().size.y) / vis.size.y          # canvas px -> window px
	var off := 0
	var small := {}
	for c in get_tree().root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl is ScrollContainer:
			continue
		var r := ctl.get_global_rect()
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		var clip := _clipped(ctl)
		if not clip and not vis.grow(1.0).encloses(r) and off < 6:
			off += 1
			print("UI_FIT %s off-canvas %s rect %s canvas %s" % [shot_name, ctl.get_path(), r, vis.size])
		if ctl is Label and (ctl as Label).text.strip_edges() != "" and (not clip or vis.intersects(r)):
			var fs := ctl.get_theme_font_size("font_size")
			var px := fs * phys
			if px < 11.0:
				var key := "%d" % fs
				small[key] = int(small.get(key, 0)) + 1
	if not small.is_empty():
		print("UI_FIT %s small text (canvas font size: labels) %s -> under 11 px at %dx%d" % [shot_name, small, size.x, size.y])


func _clipped(c: Control) -> bool:
	var n := c.get_parent()
	while n is Control:
		if n is ScrollContainer or (n as Control).clip_contents:
			return true
		n = n.get_parent()
	return false


func _quit() -> void:
	set_process(false)
	Travel._busy = true
	get_tree().quit()
