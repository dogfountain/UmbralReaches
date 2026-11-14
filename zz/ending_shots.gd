extends Node
## The twelve r38 tasks' endings in the real TASK DONE banner (windowed; headless cannot render): each task's ending text is
## pushed through the quest log's own banner queue in the built world, and a frame is saved once it is fully up.
##   godot --path . res://zz/ending_shots.tscn -- --size=1600x900 --out=<dir>
## -> <dir>/ending_<id>_<w>x<h>.png ; prints "ENDSHOT lines <id> <label height>" (the wrapped sub-line's height, px) and "ENDSHOT done".
const Chains := preload("res://core/story/quest_chains.gd")
const Log := preload("res://ui/quest_log.gd")
const MINE := ["pans_hauler", "pans_pan", "salt_barrel", "bitter_mother", "drover_tally", "long_round", "bryn_iron", "wren_gran",
	"plinth_lamp", "cutters_pledge", "landing_staves", "moor_niches"]
var size := Vector2i(1600, 900)
var out := "/tmp/ending_shots"
var main: Node
var qlog: Node
var i := 0
var t := 0.0
var phase := 0
var frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			var p := a.trim_prefix("--size=").split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_window().size = size
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	frames += 1
	if frames == 20 or frames == 200:
		get_window().size = size            # (project.godot's window override had put it back to 1600x900)
	if qlog == null:
		for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if n.get_script() == Log:
				qlog = n
		if qlog == null or frames < 1500 or not main.has_meta("realm_done"):
			return
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
	if i >= MINE.size():
		print("ENDSHOT done")
		get_tree().quit()
		return
	var id: String = MINE[i]
	if phase == 0:
		var qd: Dictionary = Chains.QUESTS[id]
		var o: Dictionary = qd.outcome
		var text := ""
		for v: Variant in o.values():                  # the longest of a choice's endings is the one that can overflow
			if String(v).length() > text.length():
				text = String(v)
		qlog.call("_show_banner", "TASK DONE", String(qd.name), text)
		t = 0.0
		phase = 1
	elif phase == 1:
		t += d
		if t >= 1.0:
			var sub := qlog.get("_b_sub") as Label
			var im := get_viewport().get_texture().get_image()
			im.save_png(out.path_join("ending_%s_%dx%d.png" % [id, size.x, size.y]))
			var r := sub.get_global_rect()
			print("ENDSHOT %s sub rect x %.0f..%.0f y %.0f..%.0f lines %d (screen %dx%d)" % [id, r.position.x, r.end.x, r.position.y, r.end.y, sub.get_line_count(), size.x, size.y])
			phase = 0
			i += 1
