class_name Hotbar
extends Control
## Bottom-centre skill bar. Draws from the player's SkillBook every frame: glyph, key or pad
## button, cooldown sweep + seconds, Gloom cost, charge ring, cast flash, refusal shake and a
## ready pulse. Labels switch between keyboard and pad on the last device used.

const SLOT := 78.0
const GAP := 14.0
const NAME_FADE := 14.0       ## names under the slots fade out after this many seconds
const FRAME := Color(0.66, 0.55, 1.0, 0.55)
const BG := Color(0.02, 0.016, 0.05, 0.78)
const SHADE := Color(0.01, 0.0, 0.03, 0.72)
const QUIET := Color(0.72, 0.74, 0.86, 0.9)
const COST := Color("#C04DFF")

var _book: SkillBook
var _font: Font
var _t := 0.0
var _was_ready := PackedByteArray()
var _ready_pulse := PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://ui/fonts/Cinzel.ttf")


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_book):
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		_book = p.skills() if p else null
		if _book == null:
			return
		_was_ready.resize(_book.slots.size())
		_ready_pulse.resize(_book.slots.size())
		_was_ready.fill(1)
		var w := _book.slots.size() * SLOT + (_book.slots.size() - 1) * GAP
		offset_left = -w * 0.5
		offset_right = w * 0.5
		offset_top = -(SLOT + 46.0 + 30.0)
		offset_bottom = -30.0
	for i in _book.slots.size():
		var is_ready := _book.cooldown_left(i) <= 0.0
		if is_ready and _was_ready[i] == 0:
			_ready_pulse[i] = 1.0
		_was_ready[i] = 1 if is_ready else 0
		_ready_pulse[i] = maxf(0.0, _ready_pulse[i] - delta * 2.2)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_book):
		return
	var name_a := clampf((NAME_FADE - _t) / 2.0, 0.0, 1.0)
	for i in _book.slots.size():
		var s := _book.slots[i]
		var shake := sin(_t * 70.0) * 4.0 * _book.denied(i)
		var o := Vector2(i * (SLOT + GAP) + shake, 0.0)
		var r := Rect2(o, Vector2(SLOT, SLOT))
		var is_ready := _book.cooldown_left(i) <= 0.0
		draw_rect(r, BG)
		_glyph(s.glyph, r.get_center(), SLOT * 0.3, s.color if is_ready else s.color.darkened(0.55))
		# cooldown sweep, clockwise from 12 o'clock, plus seconds when > 1 s
		var cr := _book.cooldown_ratio(i)
		if cr > 0.0:
			_pie(r, cr, SHADE)
			var left := _book.cooldown_left(i)
			if left >= 1.0:
				draw_string(_font, r.position + Vector2(0, SLOT * 0.6), str(ceili(left)), HORIZONTAL_ALIGNMENT_CENTER, SLOT, 26, Color(0.95, 0.92, 1.0))
		# charge ring (Ember Lance)
		if _book.charging_slot() == i:
			var c := _book.charge_ratio()
			var col := s.color.lerp(Color(1.6, 1.4, 1.0), c) if c < 1.0 else Color(1.8, 1.6, 1.2)
			draw_arc(r.get_center(), SLOT * 0.47, -PI * 0.5, -PI * 0.5 + TAU * c, 48, col, 4.0, false)
		# frame: cast flash > ready pulse > idle
		var frame := FRAME
		var f := _book.flash(i)
		if f > 0.0:
			frame = FRAME.lerp(Color(1.4, 1.3, 1.6), f)
		elif _ready_pulse[i] > 0.0:
			frame = FRAME.lerp(s.color.lightened(0.3), _ready_pulse[i])
		if _book.denied(i) > 0.0:
			frame = frame.lerp(Color(1.0, 0.3, 0.25), _book.denied(i))
		draw_rect(r, frame, false, 2.0 + f * 2.0)
		# key chip bottom-left, gloom cost top-right
		var key := _book.key_label(i)
		var kw := maxf(26.0, _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 10.0)
		var kr := Rect2(o + Vector2(-4, SLOT - 18), Vector2(kw, 22))
		draw_rect(kr, Color(0.06, 0.05, 0.12, 0.95))
		draw_rect(kr, FRAME, false, 1.0)
		draw_string(_font, kr.position + Vector2(0, 16), key, HORIZONTAL_ALIGNMENT_CENTER, kw, 15, QUIET)
		if s.gloom_cost > 0.0:
			draw_string(_font, o + Vector2(0, 17), "+%d" % roundi(s.gloom_cost), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 5, 14, COST)
		if name_a > 0.0:
			draw_string(_font, o + Vector2(-20, SLOT + 26), s.title, HORIZONTAL_ALIGNMENT_CENTER, SLOT + 40, 14, Color(QUIET, QUIET.a * name_a))


func _pie(r: Rect2, ratio: float, col: Color) -> void:
	var c := r.get_center()
	var rad := SLOT * 0.75                 # past the corners; clipped to the slot below
	var pts := PackedVector2Array([c])
	var steps := maxi(3, int(48.0 * ratio))
	for k in steps + 1:
		var a := -PI * 0.5 + TAU * (1.0 - ratio) + TAU * ratio * float(k) / float(steps)
		var p := c + Vector2(cos(a), sin(a)) * rad
		pts.append(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))
	draw_colored_polygon(pts, col)


## Icons in code so the bar has no texture dependency. Simple line glyphs on a 1-unit scale.
func _glyph(g: StringName, c: Vector2, u: float, col: Color) -> void:
	match g:
		&"bolt":
			var d := PackedVector2Array([c + Vector2(0, -u), c + Vector2(u * 0.55, 0), c + Vector2(0, u), c + Vector2(-u * 0.55, 0), c + Vector2(0, -u)])
			draw_polyline(d, col, 3.0, false)
			draw_circle(c, u * 0.18, col)
			for k in 3:
				var y := (float(k) - 1.0) * u * 0.35
				draw_line(c + Vector2(-u * 1.25, y), c + Vector2(-u * 0.75, y), Color(col, 0.6), 2.0, false)
		&"lance":
			var a := c + Vector2(-u, u)
			var b := c + Vector2(u, -u)
			draw_line(a, b, col, 3.5, false)
			draw_colored_polygon(PackedVector2Array([b + Vector2(0.2, -0.2) * u, b + Vector2(-0.55, -0.05) * u, b + Vector2(0.05, 0.55) * u]), col)
			draw_line(a, a + Vector2(-0.2, 0.45) * u, col, 2.0, false)
			draw_line(a, a + Vector2(-0.45, 0.2) * u, col, 2.0, false)
		&"nova":
			draw_arc(c, u * 0.35, 0, TAU, 24, col, 3.0, false)
			draw_arc(c, u * 0.85, 0, TAU, 32, Color(col, 0.7), 2.0, false)
			for k in 8:
				var ang := TAU * float(k) / 8.0
				var v := Vector2(cos(ang), sin(ang))
				draw_line(c + v * u * 0.5, c + v * u * 0.72, col, 2.0, false)
		&"ward":
			draw_rect(Rect2(c + Vector2(-0.45, -0.25) * u, Vector2(0.9, 1.05) * u), col, false, 2.5)
			draw_line(c + Vector2(-0.25, -0.25) * u, c + Vector2(0, -0.6) * u, col, 2.0, false)
			draw_line(c + Vector2(0.25, -0.25) * u, c + Vector2(0, -0.6) * u, col, 2.0, false)
			var fl := c + Vector2(0, 0.3) * u
			draw_colored_polygon(PackedVector2Array([fl + Vector2(0, -0.42) * u, fl + Vector2(0.2, 0.05) * u, fl + Vector2(0, 0.2) * u, fl + Vector2(-0.2, 0.05) * u]), col.lightened(0.2))
			draw_arc(c + Vector2(0, 0.95) * u, u * 1.0, PI * 1.15, PI * 1.85, 16, Color(col, 0.55), 2.0, false)
		&"step":
			for k in 2:
				var x := (float(k) * 0.55 - 0.15) * u
				draw_polyline(PackedVector2Array([c + Vector2(x - 0.35 * u, -0.6 * u), c + Vector2(x + 0.25 * u, 0), c + Vector2(x - 0.35 * u, 0.6 * u)]), col, 3.0, false)
			for k in 3:
				draw_circle(c + Vector2(-u * (0.7 + 0.28 * float(k)), 0), u * (0.09 - 0.02 * float(k)), Color(col, 0.7 - 0.2 * float(k)))
		_:
			draw_circle(c, u * 0.4, col)
