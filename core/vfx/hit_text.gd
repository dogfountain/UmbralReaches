class_name HitText
extends Label3D
## Floating combat numbers. Pooled per scene (dead refs from an old scene are pruned on use).

const LIFE := 0.7
const FONT := preload("res://ui/fonts/Cinzel.ttf")

static var _pool: Array[HitText] = []
## Set around a damage-over-time tick: the health steps down, the number stays quiet.
static var hush := false

var _busy := false
var _born := 0            ## msec this number began (the oldest yields when the pool is full)
var _tw: Tween


static func pop(at: Vector3, text: String, col: Color, big := false) -> void:
	if hush and not text.is_empty() and text.unicode_at(0) >= 48 and text.unicode_at(0) <= 57:
		return
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
			# the pool is full: the oldest number yields, so the hit just landed is the one on screen
			for h in _pool:
				if is_instance_valid(h) and h.get_parent() == host and (label == null or h._born < label._born):
					label = h
			if label == null:
				return
			if label._tw != null and label._tw.is_valid():
				label._tw.kill()
		else:
			label = HitText.new()
			host.add_child(label)
			_pool.append(label)
	label._show(at, text, col, big)


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = false                 # a number behind the mound stays behind the mound
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
	_born = Time.get_ticks_msec()
	text = txt
	modulate = col
	var s := 1.45 if big else 1.0
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		s *= clampf(cam.global_position.distance_to(at) / 6.0, 0.5, 1.0)   # one popped at your own shoulder ran off the screen
	# ENS art pass: the number punches in (x1.7 -> x1 in 0.12 s) so a hit lands on the beat, and a
	# big hit gets a warm outline glow instead of the plain dark rim
	scale = Vector3.ONE * s * 1.7
	outline_modulate = Color(0.35, 0.12, 0.02, 0.95) if big else Color(0.02, 0.01, 0.05, 0.9)
	global_position = at + Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
	visible = true
	var tw := create_tween().set_parallel(true)
	_tw = tw
	tw.tween_property(self, "scale", Vector3.ONE * s, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position:y", at.y + 0.8, LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55)
	tw.chain().tween_callback(_done)


func _done() -> void:
	visible = false
	_busy = false
