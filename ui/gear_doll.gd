extends Control
## The paper doll: the wanderer herself (her CharacterRig, in a SubViewport of its own) standing in
## candlelight, breathing, turned a little to the lantern side. Drag it (or push the right stick) to
## turn her round. The lantern's light takes the glass she wears, as it does in the night. It renders
## only while the page is open (`set_active`). Load by path:
##   const Doll := preload("res://ui/gear_doll.gd")

const Med := preload("res://ui/medieval_style.gd")
const GearDB := preload("res://core/items/gear_db.gd")

const VIEW := Vector2i(440, 680)
const REST_YAW := 0.42

var _vp: SubViewport
var _img: TextureRect
var _rig: CharacterRig
var _yaw := REST_YAW
var _vel := 0.0
var _drag := false
var _glass := -1
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	clip_contents = true
	_vp = SubViewport.new()
	_vp.size = VIEW
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.gui_disable_input = true
	add_child(_vp)
	_light()
	_img = TextureRect.new()
	_img.texture = _vp.get_texture()
	_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_img)
	set_process(false)


func _light() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.46, 0.66)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	var key := DirectionalLight3D.new()                  # candlelight from the front left
	key.light_color = Color(1.0, 0.7, 0.42)
	key.light_energy = 1.5
	key.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(150.0), 0.0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()                  # moonlight from behind, to lift the silhouette
	rim.light_color = Color(0.55, 0.7, 1.0)
	rim.light_energy = 1.1
	rim.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-25.0), 0.0)
	_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 27.0
	cam.near = 0.1
	cam.far = 30.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.3, -4.5), Vector3(0.0, 1.12, 0.0))
	cam.current = true


## The wanderer is built the first time the page is shown, not when the night loads.
func set_active(on: bool) -> void:
	if on and _rig == null:
		_rig = CharacterRig.new()
		_rig.rim_light = false
		_vp.add_child(_rig)
		_rig.rotation.y = _yaw
		_tint_lantern()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)
	if on:
		_yaw = REST_YAW
		_vel = 0.0


## The glass she wears (a rarity 0..4; -1 none) tints the lantern's light, as GearRuntime.apply_look does.
func set_glass(rarity: int) -> void:
	_glass = rarity
	_tint_lantern()


func _tint_lantern() -> void:
	if _rig == null:
		return
	var light := _rig.find_child("LanternLight", true, false) as OmniLight3D
	if light == null:
		return
	if not light.has_meta(&"base_color"):
		light.set_meta(&"base_color", light.light_color)
	var base: Color = light.get_meta(&"base_color")
	light.light_color = base if _glass < 0 else base.lerp(GearDB.rarity_color(_glass), 0.18 + 0.06 * float(_glass))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		_yaw -= (e as InputEventMouseMotion).relative.x * 0.011
		_vel = 0.0
		accept_event()


func _process(delta: float) -> void:
	if _rig == null:
		return
	_t += delta
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > 0.25:
		_yaw -= stick * 2.6 * delta
		_drag = true
	elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag = false
	if not _drag:                                       # settle back toward the rest pose, with a slow sway
		var want := REST_YAW + sin(_t * 0.45) * 0.07
		_yaw = lerp_angle(_yaw, want, 1.0 - exp(-1.2 * delta))
	_rig.rotation.y = _yaw


func _draw() -> void:
	# a pool of warm light at her feet
	var c := Vector2(size.x * 0.5, size.y * 0.9)
	for i in 8:
		var k := float(i) / 7.0
		var r := Vector2(size.x * (0.52 - 0.04 * float(i)), size.y * (0.05 - 0.004 * float(i)))
		_ellipse(c, r, Color(1.0, 0.62, 0.3, 0.035 + 0.02 * k))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
