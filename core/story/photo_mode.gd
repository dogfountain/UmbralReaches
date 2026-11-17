class_name PhotoMode
extends Node
## Photo mode (F12): the night holds still and the lens is yours. A free camera starts where the wanderer's was and flies
## within 45 m of her (WASD, mouse look, Space and Ctrl for up and down, Shift for fast, the wheel for the field of view, T for
## the black bars); Enter or a click keeps the view as a PNG in <saves>/photos/ (the HUD and the controls are hidden for the
## frame; a flash and a sound answer). Esc or P gives the night back exactly as it was. The lens never goes through the ground
## or a wall. Refused during the opening shot, a camp, a boss's fight, hollowing and the loading screen. Every picture is
## counted in the Count's save (Travel.story["tally"].photos) and the first is written in the Chronicle.
## Added by the story director; process_mode ALWAYS (it runs while the tree is paused). Class PhotoMode.

const Access := preload("res://ui/access.gd")
const SaveDir := preload("res://core/util/save_dir.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const Tally := preload("res://core/story/tally.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const Days := preload("res://core/story/days.gd")
const MenuGate := preload("res://ui/menu_gate.gd")

const RADIUS := 45.0
const SPEED := 7.0

var _on := false
var _cam: Camera3D
var _pcam: Camera3D
var _player: Node3D
var _hud: CanvasLayer
var _layer: CanvasLayer
var _hint: Label
var _flash: ColorRect
var _top: ColorRect
var _bot: ColorRect
var _bars := false
var _yaw := 0.0
var _pitch := 0.0
var _fov := 75.0
var _busy := false
var _was_captured := false


func _ready() -> void:
	name = "PhotoMode"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"photo_mode")
	set_process(false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("photo") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if _on:
			_leave()
		else:
			_enter()
		return
	if not _on or _busy:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.0022
		_pitch = clampf(_pitch - mm.relative.y * 0.0022, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_fov = clampf(_fov - 3.0, 25.0, 100.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_fov = clampf(_fov + 3.0, 25.0, 100.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_shoot()
	elif event is InputEventKey and event.pressed and not event.is_echo():
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_shoot()
		elif k == KEY_T:
			_bars = not _bars
			_bar_rects()
		elif k == KEY_ESCAPE:
			_leave()
			get_viewport().set_input_as_handled()


func _enter() -> void:
	var tree := get_tree()
	var scene := tree.current_scene
	_player = tree.get_first_node_in_group(Groups.PLAYER) as Node3D
	if scene == null or _player == null or not scene.has_meta("realm_done") or tree.paused or MenuGate.blocked(self):
		return
	if scene.get_node_or_null("LoadingScreen") != null or scene.get_node_or_null("OpeningCam") != null or scene.get_node_or_null("CampCam") != null:
		return
	if Player.boss_fight_active(tree):
		Events.toast.emit("There is no stillness in a warden's fight.")
		return
	_pcam = _player.get_node_or_null("CameraRig/Pitch/SpringArm/Camera") as Camera3D
	if _pcam == null:
		return
	_cam = Camera3D.new()
	_cam.name = "PhotoCam"
	_cam.attributes = _pcam.attributes
	_cam.environment = _pcam.environment
	_cam.far = _pcam.far
	_fov = Settings.fov
	_cam.fov = _fov
	scene.add_child(_cam)
	_cam.global_transform = _pcam.global_transform
	_yaw = _cam.global_rotation.y
	_pitch = _cam.global_rotation.x
	_cam.current = true
	_hud = tree.get_first_node_in_group(&"hud") as CanvasLayer
	if _hud != null:
		_hud.visible = false
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	tree.paused = true
	_build_layer()
	_on = true
	set_process(true)
	UiSound.play(self, "tab")


func _build_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_top = ColorRect.new()
	_bot = ColorRect.new()
	for r: ColorRect in [_top, _bot]:
		r.color = Color(0, 0, 0, 1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_TOP_WIDE if r == _top else Control.PRESET_BOTTOM_WIDE)
		_layer.add_child(r)
	_bars = false
	_bar_rects()
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.93, 0.87, 0.74, 0.85))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_hint.text = "WASD move   Mouse look   Space / Ctrl up and down   Shift fast   Wheel zoom   T bars   Enter or click: keep the view   P or Esc: leave"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -44.0
	_layer.add_child(_hint)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_flash)


func _bar_rects() -> void:
	var h := get_viewport().get_visible_rect().size.y * 0.12 if _bars else 0.0
	_top.offset_bottom = h
	_bot.offset_top = -h


func _process(delta: float) -> void:
	if not _on or not is_instance_valid(_cam) or not is_instance_valid(_player):
		_leave()
		return
	_cam.fov = lerpf(_cam.fov, _fov, 1.0 - exp(-10.0 * delta))
	_cam.global_rotation = Vector3(_pitch, _yaw, 0.0)
	var b := _cam.global_basis
	var v := Vector3.ZERO
	v += -b.z * (Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"))
	v += b.x * (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
	v += Vector3.UP * (float(Input.is_action_pressed("jump")) - float(Input.is_physical_key_pressed(KEY_CTRL)))
	if v.length() < 0.01:
		return
	var step := v.normalized() * SPEED * delta * (3.0 if Input.is_action_pressed("sprint") else 1.0)
	var from := _cam.global_position
	var to := from + step
	var home := _player.global_position + Vector3.UP * 1.5
	if to.distance_to(home) > RADIUS:
		to = home + (to - home).normalized() * RADIUS
	var q := PhysicsRayQueryParameters3D.create(from, to + step.normalized() * 0.5, Layers.WORLD)
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return                                              # a wall or the ground: the lens stops
	_cam.global_position = to


## Keep the view: hide what is not the picture for one drawn frame, read it back, write it.
func _shoot() -> void:
	if _busy:
		return
	_busy = true
	_layer.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_layer.visible = true
	var region := String(RealmLayout.region_at(_cam.global_position.x, _cam.global_position.z).get("id", "realm"))
	var d := Tally.data()
	var n := int(d.get("photos", 0)) + 1
	d["photos"] = n
	var dir := ProjectSettings.globalize_path(SaveDir.dir() + "photos/")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := "umbral_%s_night%d_%03d.png" % [region, Days.current() + 1, n]
	var err := img.save_png(dir + file)
	_flash.color.a = 0.55 * Access.flash()
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_flash, "color:a", 0.0, 0.45)
	UiSound.play(self, "confirm")
	if err == OK:
		Events.toast.emit("Kept: photos/%s" % file)
		Chronicle.write("photo:first", "photo", "You set the lantern down and kept a view of the night.")
	else:
		Events.toast.emit("The picture could not be written.")
	Travel.save_soon()
	_busy = false


func _leave() -> void:
	if not _on:
		return
	_on = false
	set_process(false)
	if is_instance_valid(_pcam):
		_pcam.current = true
	if is_instance_valid(_cam):
		_cam.queue_free()
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
	if _layer != null:
		_layer.queue_free()
		_layer = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _was_captured else Input.mouse_mode
	UiSound.play(self, "back")
