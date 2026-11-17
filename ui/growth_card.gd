extends Control
## One socket of the Kindling book (ui/growth.gd builds them and owns the selection): an ember, a spell and its
## three ranks, an oath, a relic, a hotbar slot. The cell draws itself: a painted icon in a forged socket, the
## name in Cinzel, the line in the body serif, rank pips, and the cost or state on a small plate. The selected
## cell takes a gilt frame; the next buyable thing is lit, locked things are dim.

const Med := preload("res://ui/medieval_style.gd")
const Access := preload("res://ui/access.gd")
const UIType := preload("res://ui/type.gd")
const Icons := preload("res://core/life/progression/icons.gd")

const ROMAN := ["", "I", "II", "III"]
const INK := Med.BONE
const QUIET := Med.BONE_DIM
const DIM := Med.BONE_FAINT
const EMBER := Color(1.0, 0.66, 0.36)
const EMBER_HOT := Color(1.0, 0.84, 0.6)
const WARN := Color(0.95, 0.55, 0.42)

var menu                         ## the Kindling (ui/growth.gd)
var kind := ""                   ## ember | rank | oath | rite | relic | charm | head | spell | learn | core | slot | pick
var id := ""
var sub := 0                     ## spell rank (1-3), oath tier
var pick := ""                   ## oath side "a" | "b"
var glyph := ""
var tint := Color.WHITE
var title := ""
var line := ""
var pips := Vector2i.ZERO
var cost := 0
var look := "open"               ## owned | open | poor | locked | forsworn | lost
var selected := false
var flash := 0.0
var unit := "ASH"                ## what `cost` is counted in (a Path step costs Remembrances)
var compact := false             ## a spell rank: numeral, name and cost plate
var small := false               ## a narrow cell: icon above, name across the foot
var font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	if kind == "head":
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		menu.click_card(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER and kind != "head":
		menu.hover_card(self)


func _draw() -> void:
	var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	var f := font if font else ThemeDB.fallback_font
	var body := UIType.body()
	var dead := look in ["locked", "lost", "forsworn"]
	var rim := Color(0.86, 0.84, 0.8)
	var icon_col := tint
	var title_col := INK
	match look:
		"owned":
			rim = Color(1.0, 0.7, 0.42)
		"open":
			rim = Color(1.1, 0.92, 0.6)
		"poor":
			rim = Color(0.8, 0.74, 0.7)
		"locked", "lost":
			rim = Color(0.5, 0.46, 0.44, 0.85)
			icon_col = Color(tint.darkened(0.55), 0.7)
			title_col = DIM
		"forsworn":
			rim = Color(0.38, 0.34, 0.34, 0.8)
			icon_col = Color(tint.darkened(0.6), 0.5)
			title_col = DIM
	if selected:
		rim = Color(minf(rim.r * 1.35, 1.6), minf(rim.g * 1.35, 1.6), minf(rim.b * 1.35, 1.6), rim.a)
		if not dead:
			title_col = Med.GILT
	if kind == "head":
		draw_style_box(Med.inset(6), r)
		_draw_combo(r, f, body, icon_col, title_col)
		return
	draw_style_box(Med.slot(rim), r)
	if look == "open":
		draw_rect(r.grow(-5), Color(Med.GILT, 0.05))
	elif look == "owned":
		draw_rect(r.grow(-5), Color(EMBER, 0.06))
		draw_rect(Rect2(r.position + Vector2(8, 3), Vector2(r.size.x - 16, 2)), Color(1.0, 0.6, 0.3, 0.55))
	if compact:
		_draw_rank(r, f, body, icon_col, title_col)
	elif small:
		_draw_small(r, f, body, icon_col, title_col)
	else:
		_draw_full(r, f, body, icon_col, title_col)
	if selected:
		_gilt_frame(r)
	if flash > 0.0:
		var fl := StyleBoxFlat.new()
		fl.bg_color = Color(1.0, 0.7, 0.35, 0.35 * flash * Access.flash())
		fl.set_corner_radius_all(5)
		draw_style_box(fl, r)


## The gilt frame of the chosen cell: a bright inner line, a soft halo and a lozenge at each corner.
func _gilt_frame(r: Rect2) -> void:
	draw_rect(r.grow(-1), Color(Med.GILT, 0.95), false, 2.0)
	draw_rect(r.grow(-4), Color(Med.GILT, 0.22), false, 2.0)
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), Med.GILT)


## What the cell is worth now: "KINDLED" for a thing owned, otherwise its cost; "" when it has neither.
func _tag() -> Array:
	if look == "owned":
		if kind == "pick":
			return ["", DIM]                 # "On [F]" says it already
		var t: String = {"charm": "WORN", "oath": "SWORN", "relic": "", "slot": "CHOSEN", "pick": "ON THE BAR", "core": "IN THE ORB", "spell": "",
			"path": "REMEMBERED", "service": "OPEN", "hearth": "BURNING", "walk": "", "tithe": "WARDED"}.get(kind, "KINDLED")
		return [t, Color(1.0, 0.74, 0.46)]
	if look == "forsworn":
		return ["FORSWORN", DIM]
	if cost > 0:
		return ["%d %s" % [cost, unit], EMBER if look == "open" else (WARN if look == "poor" else QUIET)]
	return ["", DIM]


## A small plate holding a cost or a state, its right end at `right` and its foot at `bottom`.
func _plate(right: float, bottom: float, text: String, col: Color, lit: bool) -> void:
	var f := UIType.body()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0
	var pr := Rect2(right - w, bottom - 24.0, w, 24.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.015, 0.01, 0.92)
	sb.border_color = Color(col, 0.75 if lit else 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	draw_style_box(sb, pr)
	draw_string(f, Vector2(pr.position.x + 9.0, pr.end.y - 7.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


func _plate_tag(r: Rect2) -> void:
	var t := _tag()
	if String(t[0]) != "":
		_plate(r.end.x - 8.0, r.end.y - 6.0, String(t[0]), t[1], look in ["open", "owned"])


## A painted icon in a forged socket, centred on c.
func _socket(c: Vector2, mr: float, icon_col: Color, rim: Color) -> void:
	draw_style_box(Med.slot(rim), Rect2(c - Vector2(mr + 6, mr + 6), Vector2(mr + 6, mr + 6) * 2.0))
	draw_circle(c, mr, Color(0.02, 0.01, 0.03, 0.95))
	if look == "owned":
		draw_circle(c, mr, Color(1.0, 0.5, 0.2, 0.12))
	if look == "lost":
		_dashed_ring(c, mr + 1.0, Color(Med.BRONZE, 0.7))
	else:
		draw_arc(c, mr, 0, TAU, 40, Color(icon_col, 0.75), 1.5, true)
	Icons.draw(self, glyph, c, mr * 0.55, icon_col)
	if look == "locked":
		_lock(c + Vector2(mr * 0.7, mr * 0.7), 1.0)


## An unclaimed thing: its silhouette inside a dashed ring, plainly waiting for its owner.
func _dashed_ring(c: Vector2, rad: float, col: Color) -> void:
	for i in 20:
		draw_arc(c, rad, TAU * float(i) / 20.0, TAU * (float(i) + 0.55) / 20.0, 4, col, 1.6, true)


func _fit(f: Font, text: String, w: float, sz: int, lo: int) -> int:
	while sz > lo and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w:
		sz -= 1
	return sz


## Icon socket on the left, the name, up to three lines of text, rank pips; the plate sits in the corner.
func _draw_full(r: Rect2, f: Font, body: Font, icon_col: Color, title_col: Color) -> void:
	var mr := minf(30.0 if r.size.x > 300.0 else 22.0, r.size.y * 0.27)
	var mc := Vector2(r.position.x + 18 + mr, r.position.y + r.size.y * 0.5 - (6.0 if pips.y > 0 else 0.0))
	_socket(mc, mr, icon_col, Color(0.86, 0.84, 0.8) if look != "owned" else Color(1.0, 0.7, 0.42))
	var tx := mc.x + mr + (20.0 if mr > 22.0 else 16.0)
	var tw := r.end.x - tx - 10.0
	draw_string(f, Vector2(tx, r.position.y + 32), title, HORIZONTAL_ALIGNMENT_LEFT, tw, _fit(f, title, tw, 19, 16), title_col)
	var foot := 30.0 if (pips.y > 0 or String(_tag()[0]) != "") else 8.0
	if line != "":
		var lines := clampi(int((r.size.y - foot - 63.0) / 20.0) + 1, 1, 4)
		draw_multiline_string(body, Vector2(tx, r.position.y + 58), line, HORIZONTAL_ALIGNMENT_LEFT, tw, 16, lines, Color(QUIET, 0.62 if dead_look() else 1.0))
	if pips.y > 0:
		for i in pips.y:
			var pc := Vector2(tx + 8 + i * 24, r.end.y - 18)
			var d := PackedVector2Array([pc + Vector2(0, -8), pc + Vector2(7, 0), pc + Vector2(0, 8), pc + Vector2(-7, 0)])
			if i < pips.x:
				draw_colored_polygon(d, EMBER)
				draw_circle(pc, 2.5, EMBER_HOT)
			else:
				d.append(d[0])
				draw_polyline(d, Color(QUIET, 0.7), 1.5, true)
	_plate_tag(r)


## Icon at the top left, the line beside it, the name across the foot, the plate in the corner. Pips for a spell head.
func _draw_small(r: Rect2, f: Font, body: Font, icon_col: Color, title_col: Color) -> void:
	var mr := 22.0
	var mc := Vector2(r.position.x + 12 + mr + 6, r.position.y + 12 + mr + 6)
	_socket(mc, mr, icon_col, Color(0.86, 0.84, 0.8) if look != "owned" else Color(1.0, 0.7, 0.42))
	var tx := mc.x + mr + 14.0
	var tw := r.end.x - tx - 8.0
	var tall := r.size.y > 120.0           # a roomy cell (a Path step): the text beside the icon, the plate on the name's line
	var t := _tag()
	var pw := 0.0
	if String(t[0]) != "":
		pw = UIType.body().get_string_size(String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 26.0
	if line != "":
		draw_multiline_string(body, Vector2(tx, mc.y - 6 if not tall else r.position.y + 26), line, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, 3 if tall else 2, Color(QUIET, 0.62 if dead_look() else 1.0))
	var nw := r.size.x - 26.0 - (pw if tall else 0.0)
	var ny := r.end.y - 16.0 if tall else r.position.y + 88
	draw_string(f, Vector2(r.position.x + 13, ny), title, HORIZONTAL_ALIGNMENT_LEFT, nw, _fit(f, title, nw, 18, 14), title_col)
	if String(t[0]) != "":
		_plate(r.end.x - 8.0, r.end.y - 8.0 if tall else mc.y + 25.0, String(t[0]), t[1], look in ["open", "owned"])


## A spell rank: its numeral in a medallion, the rank's name, the cost on a plate. The rank that can be bought
## now is lit gilt; kindled ranks glow ember; locked ranks are dim behind a lock. Rank III changes the spell.
func _draw_rank(r: Rect2, f: Font, body: Font, icon_col: Color, title_col: Color) -> void:
	var nc := r.position + Vector2(30, 28)
	var ring := DIM
	var num_col := DIM
	var fill := Color(0.02, 0.012, 0.02, 0.95)
	match look:
		"owned":
			ring = EMBER
			num_col = Color(0.1, 0.05, 0.02)
			fill = Color(EMBER, 0.95)
		"open", "poor":
			ring = Med.GILT
			num_col = Med.GILT
			title_col = Med.BONE if not selected else Med.GILT
	draw_circle(nc, 18, Color(0, 0, 0, 0.5))
	draw_circle(nc, 17, fill)
	if look == "open":
		draw_circle(nc, 17, Color(Med.GILT, 0.12))
	draw_arc(nc, 17, 0, TAU, 32, ring, 2.0, true)
	var nw := f.get_string_size(ROMAN[sub], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	draw_string(f, nc + Vector2(-nw * 0.5, 7), ROMAN[sub], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, num_col)
	if sub == 3:
		Icons.draw(self, "will", r.position + Vector2(r.size.x - 62, 28), 8.0, Color(icon_col, 0.9 if look != "locked" else 0.45))
	if look == "locked":
		_lock(r.position + Vector2(r.size.x - 26, 28), 1.5)
	var tw := r.size.x - 22.0
	draw_string(f, r.position + Vector2(11, 64), title, HORIZONTAL_ALIGNMENT_LEFT, tw, _fit(f, title, tw, 17, 14), title_col)
	var t := _tag()
	if String(t[0]) != "":
		_plate(r.end.x - 8.0, r.end.y - 5.0, String(t[0]), t[1], look in ["open", "owned"])


## A combo: its icon in a socket, the name, the rule in the body serif. Dim when the spells are not on the bar.
func _draw_combo(r: Rect2, f: Font, body: Font, icon_col: Color, title_col: Color) -> void:
	var mr := 20.0
	var mc := Vector2(r.position.x + 20 + mr, r.position.y + r.size.y * 0.5)
	_socket(mc, mr, icon_col, Color(0.86, 0.84, 0.8) if look == "open" else Color(0.5, 0.46, 0.44, 0.85))
	var tx := mc.x + mr + 20.0
	var tw := r.end.x - tx - 14.0
	draw_string(f, Vector2(tx, r.position.y + 28), title, HORIZONTAL_ALIGNMENT_LEFT, tw, 18, Med.GILT if look == "open" else DIM)
	draw_multiline_string(body, Vector2(tx, r.position.y + 52), line, HORIZONTAL_ALIGNMENT_LEFT, tw, 16, 2 if r.size.y > 80.0 else 1, Color(QUIET, 0.7 if look == "locked" else 1.0))


func dead_look() -> bool:
	return look in ["locked", "lost", "forsworn"]


func _lock(c: Vector2, k: float) -> void:
	draw_rect(Rect2(c + Vector2(-6, -2) * k, Vector2(12, 9) * k), DIM)
	draw_arc(c + Vector2(0, -2) * k, 4.5 * k, PI, TAU, 10, DIM, 1.8 * k)


## The detail column's icon: the painted art in a forged socket.
class Glyph extends Control:
	var glyph := ""
	var tint := Color.WHITE
	var lit := false
	var socket := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - (12.0 if socket else 3.0)
		if socket:
			draw_style_box(Med.slot(Color(1.0, 0.7, 0.42) if lit else Color(0.9, 0.86, 0.78)), Rect2(Vector2.ZERO, size))
		draw_circle(c, r, Color(0.02, 0.01, 0.03, 0.95))
		if lit:
			draw_circle(c, r, Color(1.0, 0.5, 0.2, 0.14))
		draw_arc(c, r, 0, TAU, 56, Color(tint, 0.8), 2.0, true)
		if not socket:
			draw_arc(c, r - 6, 0, TAU, 56, Color(tint, 0.25), 1.0, true)
		Icons.draw(self, glyph, c, r * 0.55, tint)
