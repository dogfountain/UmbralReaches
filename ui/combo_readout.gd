extends CanvasLayer
## Combo readout (skills, r28): the synergies between spells as they land, right of the
## crosshair. Newest on top, each line its combo's colour and what it did, fading after HOLD s;
## above them "COMBO xN" with a draining bar while a chain of combos is alive (Combo.WINDOW).
## Reads core/skills/combo.gd's feed; draws nothing (and costs nothing) while the feed is quiet.
## Added by the progression system next to the Kindling.

const Combo := preload("res://core/skills/combo.gd")
const HOLD := 3.5
const FADE := 0.8

var _draw: Control
var _font: Font
var _seen := 0.0


func _ready() -> void:
	layer = 4
	name = "ComboReadout"
	_font = load("res://ui/fonts/Cinzel.ttf")
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_paint)
	add_child(_draw)


func _process(_d: float) -> void:
	var now := Combo.now()
	var live := Combo.chain_left() > 0.0
	if not live and not Combo.feed.is_empty():
		live = now - float(Combo.feed[0].t) < HOLD + FADE
	if live or _seen > 0.0:
		_draw.queue_redraw()
	_seen = 1.0 if live else 0.0


func _paint() -> void:
	if Combo.feed.is_empty():
		return
	var now := Combo.now()
	var vs := _draw.size
	var x := vs.x * 0.5 + minf(vs.x * 0.09, 170.0)
	var y := vs.y * 0.5 + 24.0
	var left := Combo.chain_left()
	if Combo.chain >= 2 and left > 0.0:
		var a := clampf(left / 0.6, 0.0, 1.0)
		var pop := clampf(1.0 - (now - float(Combo.feed[0].t)) * 4.0, 0.0, 1.0)
		var size := 22 + int(6.0 * pop)
		var col := Color(1.0, 0.86, 1.0, a)
		IconArt.draw_mark(_draw, "hud", "combo", Vector2(x - 14.0, y - 5.0), 20.0, Color(1, 1, 1, a))
		_shadowed("COMBO", Vector2(x, y), 15, Color(0.75, 0.7, 0.85, a))
		_shadowed("x%d" % Combo.chain, Vector2(x + 78, y + 2), size, col)
		var bw := 120.0
		_draw.draw_rect(Rect2(x, y + 8, bw, 3), Color(0.05, 0.02, 0.08, 0.7 * a))
		_draw.draw_rect(Rect2(x, y + 8, bw * left / Combo.WINDOW, 3), Color(1.0, 0.7, 1.0, 0.85 * a))
		y += 34.0
	for i in Combo.feed.size():
		var f: Dictionary = Combo.feed[i]
		var age := now - float(f.t)
		if age > HOLD + FADE:
			break
		var a := clampf((HOLD + FADE - age) / FADE, 0.0, 1.0)
		var slide := clampf(1.0 - age * 6.0, 0.0, 1.0)
		var c: Color = f.col
		var col := Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), a)
		var px := x + slide * 18.0
		_shadowed(String(f.name), Vector2(px, y), 17 if i == 0 else 15, col)
		if String(f.detail) != "":
			var w := _font.get_string_size(String(f.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 17 if i == 0 else 15).x
			_shadowed(String(f.detail), Vector2(px + w + 10, y), 13, Color(0.82, 0.78, 0.9, a * 0.9))
		y += 24.0


func _shadowed(t: String, at: Vector2, size: int, col: Color) -> void:
	_draw.draw_string(_font, at + Vector2(1.5, 1.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.75))
	_draw.draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
