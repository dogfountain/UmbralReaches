extends Node
## The PLAY BOT: starts a NEW game (from the title when windowed) and plays the first hour the way a player
## does, through Input actions only: it steers with the move actions, turns the view with mouse motion (or the
## look stick when the mouse is not captured), talks and accepts with the interact action, fights with the real
## spell keys, kindles fires and opens the map / satchel / Kindling. It never teleports and never edits state; it
## only READS the world (the same map pins and objective line a player sees) to choose where to walk.
##
##   tools/play_bot.sh [--minutes=60] [--scale=3]        (wrapper: watchdog, HEADLESS=1, fresh save dir)
##   godot --path . res://zz/play_bot.tscn -- --out=<dir> --minutes=60 --scale=3 [--wall=1700] [--seed=1]
##
## It logs what a player would hit (<out>/log.txt, summary.txt): stuck spots, falls, deaths, a goal it cannot
## reach, a prompt, an objective with no map pin, a frame over 33 ms. Windowed it takes a screenshot at each
## problem and every 60 s, and a contact strip of each fight. The pieces live in play_bot_*.gd.
const Brain := preload("res://zz/play_bot_brain.gd")
const Rec := preload("res://zz/play_bot_rec.gd")
const OUT_ROOT := "/private/tmp/claude-501/-Users-luke-UmbralReaches/968888c4-6238-49b1-a0f8-2ba292b49c0a/scratchpad/wave4/playbot"

var out := OUT_ROOT
var minutes := 60.0
var wall := 1700.0
var scale := 3.0
var prefer := ""                  ## --prefer=<task id>: take that task before the others (to reproduce a stuck task fast)
var headless := false
var main: Node
var brain: Brain
var rec: Rec
var t_wall := 0
var phase := "boot"
var title: Node
var tick_ms := 0
var last_us := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	headless = DisplayServer.get_name() == "headless"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--minutes="):
			minutes = float(a.trim_prefix("--minutes="))
		elif a.begins_with("--wall="):
			wall = float(a.trim_prefix("--wall="))
		elif a.begins_with("--prefer="):
			prefer = a.trim_prefix("--prefer=")
		elif a.begins_with("--scale="):
			scale = float(a.trim_prefix("--scale="))
	DirAccess.make_dir_recursive_absolute(out)
	t_wall = Time.get_ticks_msec()
	rec = Rec.new(self, out, headless)
	get_window().size = Vector2i(1280, 800)
	print("BOT start out=", out, " minutes=", minutes, " scale=", scale, " headless=", headless)
	_boot.call_deferred()


## The player's start: the title screen, New Game, a slot. Headless has no title (title_boot skips it): the
## same slot call the title makes.
func _boot() -> void:
	if headless:
		Travel.use_slot(1, true)
		_load_night()
		return
	var TitleScreen := preload("res://ui/title_screen.gd")
	title = TitleScreen.new()
	title.name = "TitleScreen"
	add_child(title)
	title.connect("chosen", func(slot: int, fresh: bool) -> void:
		rec.note("TITLE", "chosen slot %d fresh=%s" % [slot, fresh])
		Travel.use_slot(slot, fresh)
		title.queue_free()
		_load_night())
	await get_tree().create_timer(1.5).timeout
	await rec.shot("title")
	if not await _press_button("New Game"):
		rec.problem("TITLE", "no New Game button")
	await get_tree().create_timer(0.6).timeout
	await rec.shot("title_slots")
	if not await _press_button("Slot 1"):
		rec.problem("TITLE", "no Slot 1 button")


func _press_button(text: String) -> bool:
	for b in _buttons(title):
		if b.text.begins_with(text) and not b.disabled:
			b.pressed.emit()
			return true
	return false


func _buttons(n: Node) -> Array[Button]:
	var r: Array[Button] = []
	if n is Button:
		r.append(n as Button)
	for c in n.get_children():
		r.append_array(_buttons(c))
	return r


func _load_night() -> void:
	phase = "loading"
	Engine.time_scale = 1.0
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	rec.note("BOOT", "night loading")


func _process(_d: float) -> void:
	var us := Time.get_ticks_usec()
	var ms := float(us - last_us) / 1000.0
	last_us = us
	var el := float(Time.get_ticks_msec() - t_wall) / 1000.0
	if el > wall:
		rec.problem("WATCHDOG", "wall clock limit %d s reached at game %s" % [int(wall), rec.clock()])
		_finish(2)
		return
	if phase == "loading":
		if is_instance_valid(main) and main.has_meta("realm_done"):
			var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			if p != null and main.get_node_or_null("LoadingScreen") == null:
				phase = "settle"
				rec.note("BOOT", "realm built at wall %.1f s" % el)
				brain = Brain.new(self, p, rec, minutes)
				add_child(brain)
		elif el > 280.0:
			rec.problem("BOOT", "the night never finished building (280 s)")
			_finish(3)
		return
	if brain != null and brain.running:
		rec.frame(ms, brain.activity)


func _finish(code: int) -> void:
	if phase == "done":
		return
	phase = "done"
	rec.write_summary(brain)
	print("BOT done code=", code)
	get_tree().quit(code)
	if not headless:
		get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: OS.kill(OS.get_process_id()))
