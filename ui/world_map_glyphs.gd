extends RefCounted
## The world map's mark glyphs (the wanderer's arrow, fires, bosses, tasks ...) inked on the live layer.
## ui/world_map.gd owns one and feeds it the pulse clock and the wanderer's facing.

const INK := Color(0.19, 0.12, 0.075)
const GOLD := Color(1.0, 0.76, 0.28)
const CREAM := Color(0.96, 0.92, 0.78)
const SEAL := Color(0.78, 0.16, 0.12)

var cinzel: Font
var pulse := 0.0
var facing := Vector2(0, -1)


func arrow(c: Control, p: Vector2, hot: bool, s := 1.0) -> void:
	var ang := facing.angle() + PI * 0.5
	if s < 1.0:
		ang = 0.0
	var pts := PackedVector2Array()
	for q: Vector2 in [Vector2(0, -13), Vector2(8.5, 9), Vector2(0, 4), Vector2(-8.5, 9)]:
		pts.append(p + q.rotated(ang) * s)
	if s >= 1.0:
		var pr := fmod(pulse, 1.6) / 1.6
		# A cream arrow and a cream ring on cream parchment did not read as "you are here". A dark seal behind the
		# arrow with a gilt rim, and a gilt-and-ink pulse, carry on any ground
		c.draw_arc(p, 20.0 + pr * 16.0, 0.0, TAU, 32, Color(INK, (1.0 - pr) * 0.8), 3.0, true)
		c.draw_arc(p, 20.0 + pr * 16.0, 0.0, TAU, 32, Color(GOLD, (1.0 - pr) * 0.9), 1.6, true)
		c.draw_circle(p, 18.0, Color(INK, 0.9))
		c.draw_arc(p, 18.0, 0.0, TAU, 32, GOLD, 2.0, true)
	c.draw_colored_polygon(pts, CREAM)
	var loop := pts.duplicate()
	loop.append(pts[0])
	c.draw_polyline(loop, INK, 2.2 * s if s < 1.0 else 1.2, true)
	if hot:
		c.draw_arc(p, 22.0, 0.0, TAU, 28, GOLD, 2.0, true)


func glyph(c: Control, kind: String, p: Vector2, hot: bool, s := 1.0) -> void:
	if hot:
		c.draw_circle(p, 17.0 * s, Color(CREAM, 0.55))
		c.draw_arc(p, 17.0 * s, 0.0, TAU, 28, INK, 1.6, true)
	if _medal(c, kind, p, s):
		return
	if kind != "lamp" and s >= 1.0 and not hot:
		c.draw_circle(p, 13.0, Color(CREAM, 0.38))
	match kind:
		"fire", "ash":
			var lit := kind == "fire"
			var pts := PackedVector2Array()
			for q: Vector2 in [Vector2(0, -12), Vector2(5.5, -2), Vector2(4.5, 5), Vector2(0, 8), Vector2(-4.5, 5), Vector2(-5.5, -2), Vector2(-1.5, -5)]:
				pts.append(p + q * s)
			if lit:
				c.draw_colored_polygon(pts, GOLD)
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3) * s, p + Vector2(2.6, 3) * s, p + Vector2(0, 6) * s, p + Vector2(-2.6, 3) * s]), Color(1.0, 0.93, 0.62))
			var loop := pts.duplicate()
			loop.append(pts[0])
			c.draw_polyline(loop, INK if lit else Color(INK, 0.7), 2.0 * s, true)
		"boss", "boss_down":
			var down := kind == "boss_down"
			var pts := PackedVector2Array()
			for q: Vector2 in [Vector2(-8, 6), Vector2(-8, -4), Vector2(-4, 0), Vector2(0, -8), Vector2(4, 0), Vector2(8, -4), Vector2(8, 6)]:
				pts.append(p + q * s)
			c.draw_colored_polygon(pts, Color(0.55, 0.5, 0.45) if down else SEAL)
			var loop := pts.duplicate()
			loop.append(pts[0])
			c.draw_polyline(loop, INK, 2.0 * s, true)
			if down:
				c.draw_line(p + Vector2(-10, 9) * s, p + Vector2(10, -9) * s, INK, 2.6 * s, true)
		"lamp":
			c.draw_circle(p, 4.6 * s, Color(1.0, 0.72, 0.34))
			c.draw_circle(p, 2.0 * s, Color(1.0, 0.95, 0.74))
			c.draw_arc(p, 4.6 * s, 0.0, TAU, 14, INK, 1.4 * s, true)
		"watch":
			c.draw_line(p + Vector2(-5, 9) * s, p + Vector2(-5, -10) * s, INK, 2.2 * s, true)
			var fl := PackedVector2Array([p + Vector2(-5, -10) * s, p + Vector2(8, -6) * s, p + Vector2(-5, -1) * s])
			c.draw_colored_polygon(fl, Color(0.3, 0.52, 0.62))
			c.draw_polyline(PackedVector2Array([fl[0], fl[1], fl[2], fl[0]]), INK, 1.8 * s, true)
		"horse":
			c.draw_arc(p + Vector2(0, -1) * s, 7.0 * s, 0.0, PI, 14, Color(0.42, 0.27, 0.15), 3.6 * s, true)
			c.draw_arc(p + Vector2(0, -1) * s, 7.0 * s, 0.0, PI, 14, INK, 1.2 * s, true)
			c.draw_circle(p + Vector2(-6.5, -2) * s, 1.4 * s, INK)
			c.draw_circle(p + Vector2(6.5, -2) * s, 1.4 * s, INK)
		"quest_available", "quest_turnin":
			c.draw_circle(p, 9.5 * s, GOLD)
			c.draw_arc(p, 9.5 * s, 0.0, TAU, 24, INK, 2.0 * s, true)
			c.draw_string(cinzel, p + Vector2(-4.6, 5.8) * s, "!" if kind == "quest_available" else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * s), INK)
		"quest_target":
			var pr := 0.5 + 0.5 * sin(pulse * 3.0)
			c.draw_arc(p, (10.0 + pr * 2.5) * s, 0.0, TAU, 28, Color(GOLD, 0.95), 3.2 * s, true)
			c.draw_arc(p, (10.0 + pr * 2.5) * s + 2.0, 0.0, TAU, 28, INK, 1.2 * s, true)
			c.draw_circle(p, 3.2 * s, GOLD)
		"rare":
			var st := PackedVector2Array()
			for k in 8:
				var a := PI * 0.25 * k - PI * 0.5
				st.append(p + Vector2(cos(a), sin(a)) * (10.0 if k % 2 == 0 else 3.6) * s)
			c.draw_colored_polygon(st, Color(0.82, 0.88, 1.0))
			st.append(st[0])
			c.draw_polyline(st, INK, 1.8 * s, true)


## The painted medallion for a kind (ui/icons/mark, from tools/icon_kit/marks.py): a dark-outlined coin that
## reads on the parchment at 26 px. A task's target keeps its pulsing ring around it. False when none exists.
func _medal(c: Control, kind: String, p: Vector2, s: float) -> bool:
	var sz := 30.0 * s
	if kind == "lamp":
		sz = 20.0 * s
	elif kind == "boss" or kind == "boss_down":
		sz = 34.0 * s
	if kind == "quest_target":
		var pr := 0.5 + 0.5 * sin(pulse * 3.0)
		c.draw_arc(p, (15.0 + pr * 3.0) * s, 0.0, TAU, 28, Color(GOLD, 0.95), 3.0 * s, true)
		c.draw_arc(p, (15.0 + pr * 3.0) * s + 2.0, 0.0, TAU, 28, INK, 1.2 * s, true)
		sz = 24.0 * s
	return IconArt.draw_mark(c, "mark", kind, p, sz)
