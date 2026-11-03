extends Node
## Cross-zone travel. Mirrors hand off spawn, facing, and Gloom; this autoload
## keeps them across change_scene_to_file and fades the glass between nights.

var pending := false
var returning := false
var gloom := 0.0
var hollow_count := 0
var spawn := Vector3.ZERO
var yaw := 0.0
var lit_by_path: Dictionary = {}
var area_lit: Dictionary = {}      ## "area_id/brazier" -> true; survives streaming and travel
var relics: Dictionary = {}        ## reliquary id -> chosen variant (StringName)
var checkpoints: Dictionary = {}   ## scene path -> Vector3 (last kindled brazier's spawn point)
var saved_hollows := 0

## Progress save (user://savegame.cfg): kindles (hub + areas), relics, checkpoint, hollow count.
## Written ~0.6 s after any change; read once at boot. Launch with `-- --fresh` to ignore it.
const SAVE_PATH := "user://savegame.cfg"
var _save_queued := false

var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false
var _awaiting_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not "--fresh" in OS.get_cmdline_user_args():
		load_game()
	Events.brazier_kindled.connect(func(_b: Node3D) -> void: save_soon())
	_fade_layer = CanvasLayer.new()
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer.layer = 80
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.06, 0.01, 0.03, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)
	add_child(_fade_layer)


func busy() -> bool:
	return _busy


func consume() -> void:
	pending = false


func go(path: String, at: Vector3, facing: float, player: Node) -> void:
	if _busy:
		return
	_busy = true
	pending = true
	returning = true
	spawn = at
	yaw = facing
	_awaiting_path = path
	_remember_kindles()
	if player and is_instance_valid(player):
		gloom = player.gloom
		hollow_count = player.hollow_count
	Events.interact_hint.emit("")

	# Hold black through the whole swap — Vale dress can take seconds.
	ResourceLoader.load_threaded_request(path)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	await tw.finished

	var keep_mouse := Input.mouse_mode
	LightGrid.clear()
	var packed := await _threaded_scene(path)
	if packed == null:
		_fail_open("missing packed scene %s" % path)
		Input.mouse_mode = keep_mouse
		return

	var old_scene := get_tree().current_scene
	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		_fail_open("change_scene err=%s path=%s" % [err, path])
		Input.mouse_mode = keep_mouse
		return

	var arrived := await _wait_for_new_scene(old_scene, 30.0)
	if not arrived:
		_fail_open("timeout waiting for %s" % path)
		Input.mouse_mode = keep_mouse
		return

	# Let the new Zone finish its first deferred dress ticks before revealing.
	await get_tree().create_timer(0.35).timeout
	Input.mouse_mode = keep_mouse
	var out := create_tween()
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out.tween_property(_fade, "color:a", 0.0, 0.75)
	await out.finished
	_awaiting_path = ""
	_busy = false
	call_deferred("restore_kindles", get_tree().current_scene)
	print("Travel arrived ", path)


func _threaded_scene(path: String) -> PackedScene:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return load(path) as PackedScene
		await get_tree().process_frame
	return load(path) as PackedScene


func _wait_for_new_scene(old_scene: Node, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur != null and cur != old_scene:
			return true
	return false


func _fail_open(why: String) -> void:
	pending = false
	_awaiting_path = ""
	push_error("Travel.go failed: ", why)
	Events.toast.emit("The glass would not open.")
	var out := create_tween()
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out.tween_property(_fade, "color:a", 0.0, 0.5)
	await out.finished
	_busy = false


func _remember_kindles() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if path.is_empty():
		return
	var names := PackedStringArray()
	for node in scene.find_children("*", "Node", true, false):
		if node is Brazier and (node as Brazier).lit:
			names.append(node.name)
	lit_by_path[path] = names


func was_lit(b_name: String) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var names: PackedStringArray = lit_by_path.get(scene.scene_file_path, PackedStringArray())
	return b_name in names


func restore_kindles(root: Node) -> void:
	if root == null:
		return
	var path := root.scene_file_path
	var names: PackedStringArray = lit_by_path.get(path, PackedStringArray())
	if names.is_empty():
		return
	for node in root.find_children("*", "Node", true, false):
		if node is Brazier and node.name in names:
			(node as Brazier).kindle_quiet()


# --- progress save ---------------------------------------------------------------------------

func save_soon() -> void:
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(0.6, true, false, true).timeout.connect(func() -> void:
		_save_queued = false
		save_game())


func note_checkpoint(scene_path: String, at: Vector3) -> void:
	if scene_path != "":
		checkpoints[scene_path] = at
		save_soon()


func checkpoint_for(scene_path: String) -> Vector3:
	return checkpoints.get(scene_path, Vector3.INF)


func save_game() -> void:
	if _busy:
		return
	_remember_kindles()
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "version", 1)
	cfg.set_value("progress", "lit_by_path", lit_by_path)
	cfg.set_value("progress", "area_lit", area_lit)
	var rel := {}
	for k in relics:
		rel[k] = String(relics[k])
	cfg.set_value("progress", "relics", rel)
	cfg.set_value("progress", "checkpoints", checkpoints)
	var p := get_tree().get_first_node_in_group(Groups.PLAYER)
	if p and "hollow_count" in p:
		saved_hollows = int(p.hollow_count)
	cfg.set_value("progress", "hollows", saved_hollows)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Travel.save_game failed: %s" % err)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	lit_by_path = cfg.get_value("progress", "lit_by_path", {})
	area_lit = cfg.get_value("progress", "area_lit", {})
	relics.clear()
	var rel: Dictionary = cfg.get_value("progress", "relics", {})
	for k in rel:
		relics[k] = StringName(String(rel[k]))
	checkpoints = cfg.get_value("progress", "checkpoints", {})
	saved_hollows = int(cfg.get_value("progress", "hollows", 0))
	print("SAVE loaded: %d scenes with kindles, %d area fires, %d relics" % [lit_by_path.size(), area_lit.size(), relics.size()])


## Wipe progress (settings menu). The running night keeps its state until the next launch.
func erase_save() -> void:
	lit_by_path.clear()
	area_lit.clear()
	relics.clear()
	checkpoints.clear()
	saved_hollows = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
