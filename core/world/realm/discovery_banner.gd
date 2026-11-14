extends CanvasLayer
## r33 world: the engraved place-name banner (WoW's zone text, in our own stone). Drawn in code, no
## textures but for a painted coin at each rule's middle: a dark slate band that fades out at both ends, two bronze rules with a lozenge at their
## middles, and the name cut into it (a dark lip above each letter, a pale one below, so it reads as
## carved rather than printed). Three sizes:
##   region   first entry: "discovered", the big carved name, the place's line under it (~5 s)
##            later entries: the name alone, smaller, no line (~2.5 s)
##   subzone  a named spot inside a region (the Crossing, the Belfry): a smaller name under where the
##            region name sits, "discovered" + its line the first time
##   event    a world event's call ("A gloom surge gathers"): ember-violet, the same plate
## Built by realm_discovery.gd (one per night, under the zone root). Load by path (no class_name).
## Held (and hidden) while a menu pauses the world; waits for a zone title card to clear first.

const TITLE_PATH := "res://ui/fonts/Cinzel.ttf"
const UIType := preload("res://ui/type.gd")
const TextDirector := preload("res://ui/text_director.gd")

const STONE := Color(0.93, 0.85, 0.68)          ## the carved letters (warm limestone in firelight)
const BRONZE := Color(0.78, 0.58, 0.34)
const EMBER := Color(1.0, 0.62, 0.3)
const LINE := Color(0.8, 0.75, 0.86)
const SURGE := Color(0.78, 0.6, 1.0)

var shown: Array[Dictionary] = []                ## tests: every banner put up {kind, name, fresh}
var _plate: Plate
var _tw: Tween
var _queue: Array[Dictionary] = []
var _hold_until := 0.0
var _clock := 0.0
var _busy_until := 0.0
const Hud := preload("res://ui/hud.gd")


## r35: the HUD's zone title card is waiting for the loading screen or still on screen (hud.gd
## title_busy). Asked, not heard: this banner is built after the arrival card is called, so the
## zone_entered hold below never covered it. The Journal's own banner (ui/codex.gd) asks the same.
static func title_up(n: Node) -> bool:
	if not n.is_inside_tree():
		return false
	var h := n.get_tree().get_first_node_in_group(&"hud") as Hud
	return h != null and h.title_busy()


class Plate extends Control:
	var k := 0.0                                 ## 0..1 the rules' reveal
	var top := ""
	var title := ""
	var line := ""
	var size_px := 56
	var width := 980.0
	var y0 := 168.0
	var tint := STONE
	var accent := EMBER
	var title_font: Font
	var body_font: Font
	var small := false

	func _draw() -> void:
		if title == "":
			return
		var cx := size.x * 0.5
		var h := float(size_px) * 1.55 + (34.0 if line != "" else 0.0) + (24.0 if top != "" else 0.0)
		var y_top := y0
		var y_bot := y0 + h
		var w := width * (0.35 + 0.65 * k)
		# the slate band: dark in the middle, gone at both ends
		var band := Color(0.045, 0.035, 0.045, 0.62 if not small else 0.42)
		var clear := Color(band, 0.0)
		var pts := PackedVector2Array([Vector2(cx - w * 0.5, y_top), Vector2(cx - w * 0.18, y_top), Vector2(cx + w * 0.18, y_top),
			Vector2(cx + w * 0.5, y_top), Vector2(cx + w * 0.5, y_bot), Vector2(cx + w * 0.18, y_bot), Vector2(cx - w * 0.18, y_bot), Vector2(cx - w * 0.5, y_bot)])
		var cols := PackedColorArray([clear, band, band, clear, clear, band, band, clear])
		draw_polygon(PackedVector2Array([pts[0], pts[1], pts[6], pts[7]]), PackedColorArray([cols[0], cols[1], cols[6], cols[7]]))
		draw_polygon(PackedVector2Array([pts[1], pts[2], pts[5], pts[6]]), PackedColorArray([cols[1], cols[2], cols[5], cols[6]]))
		draw_polygon(PackedVector2Array([pts[2], pts[3], pts[4], pts[5]]), PackedColorArray([cols[2], cols[3], cols[4], cols[5]]))
		# bronze rules, doubled, fading to the ends; a lozenge at each middle
		for y: float in [y_top, y_bot]:
			_rule(cx, y, w * 0.98, 1.6, Color(BRONZE, 0.95))
			_rule(cx, y + (4.0 if y == y_top else -4.0), w * 0.78, 1.0, Color(BRONZE, 0.55))
			_lozenge(Vector2(cx, y), 7.0 if not small else 5.0)
		# flourishes either side of the name
		var fy := y0 + (24.0 if top != "" else 0.0) + float(size_px) * 0.86
		var tw := title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x if title_font else 400.0
		for s: float in [-1.0, 1.0]:
			var x0 := cx + s * (tw * 0.5 + 22.0)
			var x1 := cx + s * (tw * 0.5 + 22.0 + 70.0 * k)
			draw_line(Vector2(x0, fy - float(size_px) * 0.32), Vector2(x1, fy - float(size_px) * 0.32), Color(BRONZE, 0.7 * k), 1.4, true)
			draw_circle(Vector2(x0 - s * 6.0, fy - float(size_px) * 0.32), 2.4, Color(BRONZE, 0.85 * k))
		var y := y0 + 4.0
		if top != "":
			_carve(top, body_font, 19, Vector2(cx, y + 18.0), Color(accent, 0.95), false)
			y += 24.0
		_carve(title, title_font, size_px, Vector2(cx, y + float(size_px) * 1.1), tint, true)
		y += float(size_px) * 1.55
		if line != "":
			_carve(line, body_font, 23, Vector2(cx, y + 22.0), LINE, false)

	func _rule(cx: float, y: float, w: float, th: float, col: Color) -> void:
		var c0 := Color(col, 0.0)
		var poly := PackedVector2Array([Vector2(cx - w * 0.5, y - th * 0.5), Vector2(cx, y - th * 0.5), Vector2(cx + w * 0.5, y - th * 0.5),
			Vector2(cx + w * 0.5, y + th * 0.5), Vector2(cx, y + th * 0.5), Vector2(cx - w * 0.5, y + th * 0.5)])
		draw_polygon(PackedVector2Array([poly[0], poly[1], poly[4], poly[5]]), PackedColorArray([c0, col, col, c0]))
		draw_polygon(PackedVector2Array([poly[1], poly[2], poly[3], poly[4]]), PackedColorArray([col, c0, c0, col]))

	func _lozenge(at: Vector2, r: float) -> void:
		# a painted coin (ui/icons/mark) where the rule is struck: a fire for a place, a gate for a world event
		if IconArt.draw_mark(self, "mark", "fire" if accent == EMBER else "travel", at, r * 3.6, Color(1, 1, 1, clampf(k * 1.5, 0.0, 1.0))):
			return
		var d := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 1.4, 0), at + Vector2(0, r), at + Vector2(-r * 1.4, 0)])
		draw_colored_polygon(d, Color(0.05, 0.035, 0.03, 0.95))
		var o := d.duplicate()
		o.append(d[0])
		draw_polyline(o, Color(BRONZE, 0.95), 1.4, true)
		draw_circle(at, r * 0.32, Color(accent, 0.9))

	## Text cut into stone: a dark lip above, a pale one below, then the face.
	func _carve(s: String, f: Font, px: int, centre_base: Vector2, col: Color, deep: bool) -> void:
		if f == null:
			return
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := Vector2(centre_base.x - w * 0.5, centre_base.y)
		var d := 2.0 if deep else 1.0
		draw_string(f, at + Vector2(0, d), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1.0, 0.92, 0.78, 0.28 * col.a))
		draw_string(f, at + Vector2(0, -d * 0.8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.0, 0.0, 0.0, 0.85 * col.a))
		if deep:
			draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 5, Color(0.04, 0.03, 0.03, 0.55 * col.a))
		draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_plate = Plate.new()
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tf := load(TITLE_PATH) as Font
	if tf:
		var fv := FontVariation.new()
		fv.base_font = tf
		fv.spacing_glyph = 4                     # carved capitals are set wide
		_plate.title_font = fv
	_plate.body_font = UIType.body()
	_plate.modulate.a = 0.0
	add_child(_plate)
	Events.zone_entered.connect(_on_title_card)


## A zone title card (arrival, a boss's name) owns the screen: what is up bows out, the rest waits
## (here, and for as long as the HUD says the card is up: title_up).
func _on_title_card(_t: String, _s: String) -> void:
	_hold_until = _clock + 4.6
	if _plate.modulate.a > 0.01:
		if _tw:
			_tw.kill()
		_tw = create_tween()
		_tw.tween_property(_plate, "modulate:a", 0.0, 0.3)
		_busy_until = _clock + 0.3


## A region's name. `fresh` = the first time ever (big, with its line).
func show_region(title: String, line: String, fresh: bool) -> void:
	_push({"kind": "region", "name": title, "line": line, "fresh": fresh})


func show_subzone(title: String, line: String, fresh: bool) -> void:
	_push({"kind": "subzone", "name": title, "line": line, "fresh": fresh})


func show_event(title: String, line: String) -> void:
	_push({"kind": "event", "name": title, "line": line, "fresh": true})


func busy() -> bool:
	return _clock < _busy_until or not _queue.is_empty()


func _push(b: Dictionary) -> void:
	# a newer name for the same slot replaces one still waiting (walking fast through three places)
	for i in range(_queue.size() - 1, -1, -1):
		if String(_queue[i].kind) == String(b.kind) and not bool(_queue[i].fresh):
			_queue.remove_at(i)
	_queue.append(b)


func _process(delta: float) -> void:
	_clock += delta
	_plate.visible = not get_tree().paused
	var td := TextDirector.of(self)
	if td != null and (td.in_combat() or td.is_up(&"boss_title")):
		# a fight is on: a banner on screen bows out (a first discovery is kept to show again), none starts
		if _plate.modulate.a > 0.01 and not _cut:
			_cut = true
			if _tw:
				_tw.kill()
			if not _cur.is_empty() and bool(_cur.fresh):
				_queue.push_front(_cur)
			_tw = create_tween()
			_tw.tween_property(_plate, "modulate:a", 0.0, 0.35)
			_busy_until = _clock + 0.35
		return
	_cut = false
	if get_tree().paused or _queue.is_empty() or _clock < _hold_until or title_up(self):
		return
	# a fresh discovery waits for the one on screen; a plain name (revisit) cuts it short
	var b: Dictionary = _queue[0]
	if _clock < _busy_until and (bool(b.fresh) or _cur_fresh):
		return
	_queue.pop_front()
	_show(b)


var _cur_fresh := false
var _cur: Dictionary = {}              ## the banner on screen (kept to show again if a fight cuts it short)
var _cut := false


func _show(b: Dictionary) -> void:
	var kind := String(b.kind)
	var fresh := bool(b.fresh)
	shown.append({"kind": kind, "name": String(b.name), "fresh": fresh})
	_cur_fresh = fresh
	_cur = b
	var p := _plate
	p.title = String(b.name).to_upper()
	p.tint = STONE
	p.accent = EMBER
	p.small = false
	match kind:
		"region":
			p.top = "— discovered —" if fresh else ""
			p.line = String(b.line) if fresh else ""
			p.size_px = 58 if fresh else 40
			p.width = 1100.0 if fresh else 760.0
			p.y0 = 236.0
		"subzone":
			p.top = "— discovered —" if fresh else ""
			p.line = String(b.line) if fresh else ""
			p.size_px = 40 if fresh else 30
			p.width = 820.0 if fresh else 560.0
			p.y0 = 250.0
			p.small = not fresh
		_:
			p.top = "— the night stirs —"
			p.line = String(b.line)
			p.size_px = 44
			p.width = 960.0
			p.y0 = 236.0
			p.tint = Color(0.9, 0.84, 1.0)
			p.accent = SURGE
	var hold := 4.2 if fresh else 1.9
	if kind == "event":
		hold = 4.4
	_busy_until = _clock + 0.9 + hold + 1.2
	if _tw:
		_tw.kill()
	p.k = 0.0
	p.queue_redraw()
	_tw = create_tween()
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_tw.tween_property(p, "modulate:a", 1.0, 0.7 if fresh else 0.45)
	_tw.parallel().tween_method(func(v: float) -> void:
		p.k = v
		p.queue_redraw(), 0.0, 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_interval(hold)
	_tw.tween_property(p, "modulate:a", 0.0, 1.2)
