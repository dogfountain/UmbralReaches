extends Node
## r35: renders of the character screen, one per page that matters (windowed, the real night).
##   HOME=<scratch> godot --path . res://zz/char_screen_shots.tscn -- --out=<dir> [--staged]
## -> <dir>/char_<tab>_<page>.png. Holds Travel._busy; quits itself.

var main: Node
var out := "res://shots"
var _ran := false
var t := 0.0
const PAGES := [["wanderer", "gear"], ["wanderer", "relics"], ["kindling", "embers"], ["kindling", "spells"], ["kindling", "loadout"],
	["pack", ""], ["journal", "journal"], ["journal", "tasks"]]


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a == "--staged":
			Engine.set_meta(&"staged_spells", true)   # r35: a new game's bar (only Rift Bolt taught)
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 120.0:
		get_tree().quit(1)
	if not _ran and is_instance_valid(main) and main.has_meta("realm_done"):
		_ran = true
		_run()


func _run() -> void:
	await _frames(60)
	Travel.give("thorn_heart", 1, false)
	Travel.give("grave_ash", 30, false)
	Travel.give("ash_bloom", 3, false)
	var cs := get_tree().get_first_node_in_group(&"character_screen")
	var hud_img := get_viewport().get_texture().get_image()
	var hp := "%s/char_hud_bar.png" % out
	hud_img.save_png(hp if hp.begins_with("/") else ProjectSettings.globalize_path(hp))
	for pg: Array in PAGES:
		cs.call("open_at", pg[0], pg[1])
		await _frames(12)
		var img := get_viewport().get_texture().get_image()
		var path := "%s/char_%s_%s.png" % [out, pg[0], pg[1] if pg[1] != "" else "all"]
		img.save_png(path if path.begins_with("/") else ProjectSettings.globalize_path(path))
		print("CHARSHOT ", path)
	cs.call("close")
	await _frames(4)
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
