extends Node
## Journal UI renders: godot --path . res://zz/lore_codex_shots.tscn -- --realm-modules=land,lore
## Uses a throwaway journal (user://codex_shots.cfg, deleted after). Saves shots/lore_codex/*.png:
## the reading panel over the world, a region banner, and each tab of the book.
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const PATH := "user://codex_shots.cfg"
const READ := ["jn_1", "jn_2", "jn_4", "jn_7", "hw_maud_1", "hw_maud_3", "tw_song_2", "br_tally_1", "br_tally_2", "rd_way_12", "rd_way_9", "ch_hearth", "ch_door", "gl_shoe", "hw_notice_lost", "rim_bell"]
var t := 0.0
var started := false


func _ready() -> void:
	CodexStore.use_path(PATH, false)
	CodexStore.reset(true)
	get_window().size = Vector2i(1600, 1000)
	get_window().always_on_top = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/lore_codex"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if started:
		return
	var rl := get_tree().root.find_child("RealmLore", true, false)
	if rl == null or not rl.has_meta("scraps"):
		if t > 150.0:
			get_tree().quit()
		return
	started = true
	_run(rl)


func _snap(n: String) -> void:
	for i in 6:
		await get_tree().process_frame
		RenderingServer.force_draw(true)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/lore_codex/%s.png" % n))
	print("SHOT ", n)


func _run(rl: Node) -> void:
	await get_tree().create_timer(7.0).timeout
	for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
	var codex := get_tree().get_first_node_in_group("codex")
	var scraps := {}
	for s in rl.find_children("Lore_*", "", true, false):
		scraps[String(s.get("lore_id"))] = s
	for id in READ:
		if scraps.has(id) and id != "hw_notice_lost":
			CodexStore.record_read(id)
	for r in ["hearth", "road", "chapel", "glade", "thornwood", "barrows", "fen"]:
		CodexStore.discover(r)
	# stand the wanderer in front of the LOST notice and read it
	var s: Node3D = scraps["hw_notice_lost"]
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p:
		p.global_position = s.global_position + Vector3.UP * 0.2
		p.look_at(Vector3(s.global_position.x - 0.0, p.global_position.y, s.global_position.z - 1.0))
	await get_tree().create_timer(1.0).timeout
	(s as Interactable).interact(null)
	await get_tree().create_timer(0.8).timeout
	await _snap("reading")
	codex.call("close_reading")
	codex.set("_region", "")
	codex.call("_show_banner", "The Barrow Field", "sealed until the sky calls", true)
	await get_tree().create_timer(1.2).timeout
	await _snap("banner")
	for i in 5:
		codex.call("open_book", i)
		await get_tree().create_timer(0.2).timeout
		await _snap("book_%d" % i)
	codex.call("close_book")
	CodexStore.reset(true)
	print("SHOTS DONE")
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())
