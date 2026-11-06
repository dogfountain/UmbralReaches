extends Node
## The world map in a window (needs a renderer): the opening view with a few places walked, then the
## whole sheet with every place walked. -> shots/world_map_<n>.png. Never writes the save or the journal.
## Quits itself when done and by a hard watchdog at 110 s.
##   HOME=<scratch> godot --path . res://zz/world_map_shot.tscn
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
var main: Node
var t := 0.0
var _ran := false


func _ready() -> void:
	Travel._busy = true
	CodexStore.persist = false
	get_window().size = Vector2i(1600, 900)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 110.0:
		print("WORLDMAP_SHOT watchdog")
		get_tree().quit(1)
		return
	if not _ran and is_instance_valid(main) and main.has_meta("realm_done"):
		_ran = true
		_run()


func _run() -> void:
	var wm := get_tree().get_first_node_in_group(&"world_map")
	await get_tree().create_timer(3.0).timeout
	CodexStore.places.clear()
	for id in ["hearth", "road", "chapel", "glade", "thornwood", "henge", "fen", "crags", "rift", "weirford"]:
		CodexStore.places[id] = 1
	while not bool(wm.call("is_baked")):
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	wm.call("open")
	await get_tree().create_timer(1.0).timeout
	_snap(0)
	wm.call("close")
	for r: Dictionary in RealmLayout.REGIONS:
		CodexStore.places[String(r.id)] = 1
	wm.call("open")
	wm.set("_zoom", 0.1)
	wm.call("_layout")
	await get_tree().create_timer(1.0).timeout
	_snap(1)
	wm.set("_zoom", 3.4)
	wm.set("_cen", Vector2(-60, 40))
	wm.call("_layout")
	await get_tree().create_timer(1.0).timeout
	_snap(2)
	get_tree().quit(0)


func _snap(i: int) -> void:
	get_viewport().get_texture().get_image().save_png("res://shots/world_map_%d.png" % i)
	print("WORLDMAP_SHOT saved ", i)
