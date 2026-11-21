extends Node
## The Last Lantern: the new game's opening shot, about 46 seconds, skippable. One authored camera (its own
## Camera3D, the way the loading screen's warm-up tour works) over Hearthward's green, with the wanderer standing
## still: the lens looks at the empty dark, rises up the Order's chain to the turning sky, comes down into the
## village's lamplight, circles the wanderer at the fire, and settles on the pose of the follow camera, which is
## given back without a cut. Nothing here builds a mesh, a material or a light, so no shader is compiled: the
## loading screen's tour has already drawn exactly this ground.
##   beat(i)     the story speaks narration line i at the moment the picture is ready for it
##   finished(skipped)
## Skip: hold the interact key (or the pad's) for 0.8 s after the first 1.5 s; skipping lands in the same state.
## Load by path (no class_name): const OpeningShot := preload("res://core/story/opening_shot.gd")

signal beat(i: int)
signal finished(skipped: bool)

const LEN := 46.0
const SKIP_AFTER := 1.5
const SKIP_HOLD := 0.8
const BARS := 0.115                       ## each letterbox bar as a fraction of the screen's height
## the beats' times (shot seconds)
## index: 0 the sky's low stroke, 1-3 the narration lines, 4 the lantern's chime
const BEATS := [0.5, 1.0, 9.0, 33.0, 34.5]

var _cam: Camera3D
var _player: Node3D
var _pcam: Camera3D
var _home: Transform3D                    ## the follow camera's pose: where the shot must end
var _origin: Vector3
var _t := 0.0
var _speed := 1.0                         ## the second night's shot runs faster (a New Game after an ending)
var _again := false
var _card: Label
var _done := false
var _hold := 0.0
var _beats_sent := 0
var _layer: CanvasLayer
var _top: ColorRect
var _bot: ColorRect
var _hint: Label
var _space: PhysicsDirectSpaceState3D


## Begin the shot over `player`. False when there is nothing to shoot (no player or no camera): the story goes on.
func begin(player: Node3D, again := false) -> bool:
	_again = again
	_speed = 1.5 if again else 1.0
	_player = player
	if _player == null or not is_inside_tree():
		return false
	_pcam = _player.get_node_or_null("CameraRig/Pitch/SpringArm/Camera") as Camera3D
	if _pcam == null:
		return false
	_home = _pcam.global_transform
	_origin = _player.global_position
	add_to_group(&"opening_shot")                 # the HUD's lessons wait while it plays (polish, 20 Nov: the WASD card drew over the sky)
	_space = _player.get_world_3d().direct_space_state
	_cam = Camera3D.new()
	_cam.name = "OpeningCam"
	_cam.fov = Settings.fov
	_cam.far = _pcam.far
	_cam.attributes = _pcam.attributes
	_cam.environment = _pcam.environment
	get_tree().current_scene.add_child(_cam)
	_cam.global_transform = _home
	_cam.current = true
	_player.process_mode = Node.PROCESS_MODE_DISABLED       # still, and deaf to input, until the lens is given back
	_bars()
	set_process(true)
	return true


func _bars() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 70
	add_child(_layer)
	_top = ColorRect.new()
	_bot = ColorRect.new()
	for r: ColorRect in [_top, _bot]:
		r.color = Color(0, 0, 0, 1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_TOP_WIDE if r == _top else Control.PRESET_BOTTOM_WIDE)
		_layer.add_child(r)
	_card = Label.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.text = "THE SECOND NIGHT\nthe latch holds, for now" if _again else "THE UMBRAL REACHES\nwhere the sky turns inward"
	_card.add_theme_font_override("font", load("res://ui/fonts/Cinzel.ttf") as Font)
	_card.add_theme_font_size_override("font_size", 46)
	_card.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4, 0.0))
	_card.add_theme_color_override("font_outline_color", Color(0.1, 0.045, 0.01, 0.0))
	_card.add_theme_constant_override("outline_size", 4)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.offset_left = -700.0
	_card.offset_right = 700.0
	_card.offset_top = -120.0
	_card.offset_bottom = 40.0
	_layer.add_child(_card)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.82, 0.76, 0.62, 0.0))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.text = "Hold [%s] to skip" % InputSetup.live_label("interact", false, "E")
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-220, -34)
	_layer.add_child(_hint)
	_size_bars(0.0)


## The game's name over the empty dark (shot seconds 2 to 7): in with the first lines, out as the lens begins to climb.
func _card_tick() -> void:
	var a := smoothstep(2.0, 3.6, _t) * (1.0 - smoothstep(5.8, 7.4, _t))
	_card.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4, a))
	_card.add_theme_color_override("font_outline_color", Color(0.1, 0.045, 0.01, a))


func _size_bars(k: float) -> void:
	var h := get_viewport().get_visible_rect().size.y * BARS * k
	_top.offset_top = 0.0
	_top.offset_bottom = h
	_bot.offset_top = -h
	_bot.offset_bottom = 0.0


func _process(delta: float) -> void:
	if _done or _cam == null:
		return
	_t += delta * _speed
	_card_tick()
	while _beats_sent < BEATS.size() and _t >= float(BEATS[_beats_sent]):
		beat.emit(_beats_sent)
		_beats_sent += 1
	# the bars slide in over 1.5 s and out over the last 1.2 s
	_size_bars(smoothstep(0.0, 1.5, _t) * (1.0 - smoothstep(LEN - 1.2, LEN, _t)))
	if _t > SKIP_AFTER:
		var c := _hint.get_theme_color("font_color")
		c.a = move_toward(c.a, 0.75 if _t < LEN - 4.0 else 0.0, delta * 1.5)
		_hint.add_theme_color_override("font_color", c)
		if Input.is_action_pressed("interact"):
			_hold += delta
			if _hold >= SKIP_HOLD:
				_end(true)
				return
		else:
			_hold = maxf(0.0, _hold - delta * 2.0)
	if _t >= LEN:
		_end(false)
		return
	_pose()


## The camera for time t: four shots, each a pure function of the clock, joined by smoothstep blends.
func _pose() -> void:
	var o := _origin
	var head := o + Vector3.UP * 1.5
	var north := Vector3(0.0, 0.0, -1.0)
	var from := _home.origin
	var to := head
	if _t < 17.0:
		# 1. the empty dark, then up the chain: the lens stands 4 m in front of the wanderer on the green, 1.7 m high, and rises
		var k := smoothstep(0.0, 17.0, _t)
		from = o + Vector3(3.0, 1.7, 2.0).lerp(Vector3(5.0, 13.0, -1.0), k)
		var pitch := lerpf(0.04, 0.62, smoothstep(2.0, 15.0, _t))
		var look := from + Vector3(-0.15, sin(pitch), -cos(pitch)).normalized() * 30.0
		_apply(from, look)
		return
	if _t < 33.0:
		# 2. down into the lamplight and round the wanderer, a half turn from the north to the east (the Keg's side)
		var k2 := smoothstep(17.0, 33.0, _t)
		var ang := lerpf(-0.35, 1.45, k2)                         # radians from the north, toward the east
		var r := lerpf(7.5, 4.6, k2)
		var h := lerpf(9.0, 2.1, smoothstep(17.0, 26.0, _t))
		var rim := north.rotated(Vector3.UP, -ang)
		from = o + rim * r + Vector3.UP * h
		to = head + Vector3.UP * lerpf(2.0, 0.1, k2)
		# the first five seconds blend from where the crane ended (no cut)
		var w := 1.0 - smoothstep(17.0, 22.0, _t)
		if w > 0.0:
			var end_from := o + Vector3(5.0, 13.0, -1.0)
			var end_look := end_from + Vector3(-0.15, sin(0.62), -cos(0.62)).normalized() * 30.0
			from = from.lerp(end_from, w)
			to = to.lerp(end_look, w)
		_apply(_clear(head, from), to)
		return
	# 3. settle on the follow camera's pose and give it back
	var k3 := smoothstep(33.0, LEN - 0.4, _t)
	var a: Vector3 = o + north.rotated(Vector3.UP, -1.45) * 4.6 + Vector3.UP * 2.1
	var pos := a.lerp(_home.origin, k3)
	var look3 := head.lerp(_home.origin - _home.basis.z * 8.0, k3)
	_apply(_clear(head, pos), look3)
	if k3 > 0.98:
		_cam.global_transform = _home


func _apply(pos: Vector3, look: Vector3) -> void:
	if pos.distance_to(look) < 0.05:
		return
	_cam.global_position = pos
	_cam.look_at(look, Vector3.UP)


## The lens never ends up inside a wall or a roof: if the world is between the wanderer's head and the lens, it stops short.
func _clear(from_head: Vector3, want: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from_head, want, Layers.WORLD)
	var hit := _space.intersect_ray(q)
	if hit.is_empty():
		return want
	var p: Vector3 = hit.position
	return p + (from_head - p).normalized() * 0.35


func _end(skipped: bool) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_pcam):
		_pcam.current = true
	if is_instance_valid(_cam):
		_cam.queue_free()
	if is_instance_valid(_player):
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		_player.reset_physics_interpolation()
	if _layer != null:
		_layer.queue_free()
	finished.emit(skipped)
	queue_free()
