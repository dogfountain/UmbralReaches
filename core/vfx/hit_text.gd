class_name HitText
extends Label3D
## Floating combat numbers. Pooled per scene (dead refs from an old scene are pruned on use).

const LIFE := 0.7
const FONT := preload("res://ui/fonts/Cinzel.ttf")

static var _pool: Array[HitText] = []

var _busy := false


static func pop(at: Vector3, text: String, col: Color, big := false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var host := tree.current_scene
	var label: HitText = null
	var i := 0
	while i < _pool.size():
		var h := _pool[i]
		if not is_instance_valid(h) or not h.is_inside_tree():
			_pool.remove_at(i)
			continue
		if not h._busy and h.get_parent() == host:
			label = h
			break
		i += 1
	if label == null:
		if _pool.size() >= 24:
			return
		label = HitText.new()
		host.add_child(label)
		_pool.append(label)
	label._show(at, text, col, big)


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	double_sided = true
	font = FONT
	font_size = 72
	outline_size = 14
	outline_modulate = Color(0.02, 0.01, 0.05, 0.9)
	pixel_size = 0.0042
	render_priority = 10
	outline_render_priority = 9
	visible = false


func _show(at: Vector3, txt: String, col: Color, big: bool) -> void:
	_busy = true
	text = txt
	modulate = col
	scale = Vector3.ONE * (1.45 if big else 1.0)
	global_position = at + Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
	visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position:y", at.y + 0.8, LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55)
	tw.chain().tween_callback(_done)


func _done() -> void:
	visible = false
	_busy = false
