extends Node
## Agent D: renders the Journal's Map tab (and Stories) with some places walked, some secrets found
## and part of the Ninth Company read. Save-safe: Travel._busy, an in-memory journal.
##   HOME=<scratch>/home godot --path . res://zz/secret_journal_shot.tscn
## Writes shots/agentD_journal_map_after.png and shots/agentD_journal_stories_after.png.
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const State := preload("res://core/life/secrets/state.gd")
var main: Node
var t := 0.0
var step := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS          # the open book pauses the world
	Travel.set("_busy", true)
	CodexStore.persist = false
	CodexStore.use_path("user://codex_shot_d.cfg", false)
	Travel.system_state("secrets").clear()
	get_window().size = Vector2i(1600, 1000)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if t > 200.0:
		OS.kill(OS.get_process_id())
	if step == 0:
		if main == null or not main.has_meta("realm_done") or State.site("hoard").is_empty():
			return
		for r: String in ["hearth", "road", "glade", "thornwood", "henge", "rift", "ossuary", "fen", "barrows"]:
			CodexStore.discover(r)
		for id: String in ["bells", "spill", "crypt", "singing", "breath", "company", "lower_count", "count_drum", "pell", "oak"]:
			State.mark("found", id, false)
		for id: String in ["nc_company_1", "nc_company_2", "jn_1", "jn_2", "hw_maud_1"]:
			CodexStore.record_read(id)
		step = 1
		t = 0.0
		return
	if step == 1 and t > 2.0:
		var cx := get_tree().get_first_node_in_group("codex")
		cx.call("open_book", 4)
		step = 2
		t = 0.0
		return
	if step == 2 and t > 1.0:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/agentD_journal_map_after.png"))
		var cx2 := get_tree().get_first_node_in_group("codex")
		cx2.call("open_book", 1)
		step = 3
		t = 0.0
		return
	if step == 3 and t > 1.0:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/agentD_journal_stories_after.png"))
		print("JOURNAL_SHOT done")
		OS.kill(OS.get_process_id())
