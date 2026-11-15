extends Control
## The parchment's border, title, scale and compass rose, drawn once into the paper layer (ui/world_map.gd).

var cinzel: Font
var serif: Font
const K := 2.6
const INK := Color(0.19, 0.12, 0.075)
const O := Vector2(-420.0, -214.0)

func _w(p: Vector2) -> Vector2:
	return (p - O) * K

func _text_c(font: Font, s: String, c: Vector2, size: int, col: Color, spacing := 0.0) -> void:
	var w := 0.0
	for ch in s:
		w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	var x := c.x - (w - spacing) * 0.5
	for ch in s:
		draw_string(font, Vector2(x, c.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing

func _draw() -> void:
	var w := size.x
	var h := size.y
	# the double frame
	draw_rect(Rect2(26, 26, w - 52, h - 52), INK, false, 5.0)
	draw_rect(Rect2(40, 40, w - 80, h - 80), Color(INK, 0.8), false, 1.8)
	for q: Vector2 in [Vector2(26, 26), Vector2(w - 26, 26), Vector2(26, h - 26), Vector2(w - 26, h - 26)]:
		draw_circle(q, 13.0, Color(0.86, 0.77, 0.59))
		draw_arc(q, 13.0, 0.0, TAU, 24, INK, 3.0, true)
		draw_circle(q, 4.0, INK)
	# the neatline and its ruled band
	var nl := Rect2(_w(RealmLayout.BOUNDS.position), RealmLayout.BOUNDS.size * K)
	draw_rect(nl, INK, false, 2.6)
	var band := 10.0
	var seg := 25.0 * K
	var n := int(nl.size.x / seg)
	for i in n + 1:
		var x0 := nl.position.x + i * seg
		var x1 := minf(x0 + seg, nl.end.x)
		if x1 <= x0:
			continue
		if i % 2 == 0:
			draw_rect(Rect2(x0, nl.position.y - band, x1 - x0, band), INK)
			draw_rect(Rect2(x0, nl.end.y, x1 - x0, band), INK)
		draw_rect(Rect2(x0, nl.position.y - band, x1 - x0, band), INK, false, 1.4)
		draw_rect(Rect2(x0, nl.end.y, x1 - x0, band), INK, false, 1.4)
	n = int(nl.size.y / seg)
	for j in n + 1:
		var y0 := nl.position.y + j * seg
		var y1 := minf(y0 + seg, nl.end.y)
		if y1 <= y0:
			continue
		if j % 2 == 0:
			draw_rect(Rect2(nl.position.x - band, y0, band, y1 - y0), INK)
			draw_rect(Rect2(nl.end.x, y0, band, y1 - y0), INK)
		draw_rect(Rect2(nl.position.x - band, y0, band, y1 - y0), INK, false, 1.4)
		draw_rect(Rect2(nl.end.x, y0, band, y1 - y0), INK, false, 1.4)
	# the title
	_text_c(cinzel, "THE REALM OF UMBRAL REACHES", Vector2(w * 0.5, 112.0), 54, INK, 11.0)
	var ly := 128.0
	draw_line(Vector2(w * 0.5 - 380.0, ly), Vector2(w * 0.5 - 22.0, ly), INK, 2.0, true)
	draw_line(Vector2(w * 0.5 + 22.0, ly), Vector2(w * 0.5 + 380.0, ly), INK, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5, ly - 9), Vector2(w * 0.5 + 12, ly), Vector2(w * 0.5, ly + 9), Vector2(w * 0.5 - 12, ly)]), INK)
	_text_c(serif, "set down from what the wanderer has walked, and from what the dark has left her", Vector2(w * 0.5, 156.0), 22, Color(INK, 0.85))
	# the scale
	var bx := nl.position.x + 24.0
	var by := nl.end.y + 60.0
	var u := 20.0 * K
	for i in 5:
		var r := Rect2(bx + i * u, by, u, 9.0)
		if i % 2 == 0:
			draw_rect(r, INK)
		draw_rect(r, INK, false, 1.6)
	draw_string(serif, Vector2(bx - 4.0, by - 8.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_string(serif, Vector2(bx + 5.0 * u - 22.0, by - 8.0), "100 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	_text_c(cinzel, "HIC SUNT TENEBRAE", Vector2(w * 0.5, nl.end.y + 78.0), 26, Color(INK, 0.8), 7.0)
	# the compass rose
	_rose(Vector2(nl.end.x - 120.0, nl.end.y + 74.0), 56.0)

func _rose(c: Vector2, r: float) -> void:
	draw_arc(c, r * 0.5, 0.0, TAU, 40, INK, 2.0, true)
	draw_arc(c, r * 0.62, 0.0, TAU, 40, Color(INK, 0.7), 1.2, true)
	for k in 8:
		var a := TAU * k / 8.0 - PI * 0.5
		var big := k % 2 == 0
		var reach := r if big else r * 0.62
		var tip := c + Vector2.from_angle(a) * reach
		var l := c + Vector2.from_angle(a - 0.36) * r * 0.2
		var rr := c + Vector2.from_angle(a + 0.36) * r * 0.2
		draw_colored_polygon(PackedVector2Array([c, l, tip]), INK if big else Color(0.86, 0.77, 0.59))
		draw_colored_polygon(PackedVector2Array([c, tip, rr]), Color(0.86, 0.77, 0.59))
		draw_polyline(PackedVector2Array([l, tip, rr, c, l]), INK, 1.6, true)
	draw_string(cinzel, c + Vector2(-8.0, -r - 8.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)


