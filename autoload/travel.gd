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

var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false
var _awaiting_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	await tw.finished

	var keep_mouse := Input.mouse_mode
	LightGrid.clear()
	var packed := load(path) as PackedScene
	if packed == null:
		_fail_open("missing packed scene %s" % path)
		Input.mouse_mode = keep_mouse
		return

	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		_fail_open("change_scene err=%s path=%s" % [err, path])
		Input.mouse_mode = keep_mouse
		return

	var arrived := await _wait_for_scene(path, 30.0)
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


func _wait_for_scene(path: String, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	var needle := path.get_file()
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur == null:
			continue
		var cur_path := String(cur.scene_file_path)
		if cur_path == path or cur_path.ends_with(needle):
			return true
		if String(cur.name).to_lower() == needle.get_basename().to_lower():
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
