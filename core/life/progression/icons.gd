extends RefCounted
## Progression icons for the Kindling (ui/growth.gd), the Satchel and the shop. `draw(ci, glyph, centre,
## unit, colour)` on any CanvasItem in _draw. A glyph is painted art when ui/icons has it (a plain id
## searches the spell and kindling sets; "category/id" names one exactly, e.g. "item/thorn_heart"),
## else the old drawn shape below. The five spell glyphs match ui/hotbar.gd's.

const DB := preload("res://core/life/progression/upgrade_db.gd")
const HearthDB := preload("res://core/life/progression/hearth_db.gd")


static func draw(ci: CanvasItem, g: String, c: Vector2, u: float, col: Color) -> bool:
	var art := IconArt.art(g.get_slice("/", 0), g.get_slice("/", 1)) if g.contains("/") else IconArt.find(g)
	if art != null:
		# painted art: a round picture filling the medallion; the caller's colour only says how lit it is
		var lit := clampf(col.v * 1.15, 0.3, 1.0)
		IconArt.draw_disc(ci, art, c, u * 1.65, Color(lit, lit, lit, col.a))
		return true
	var w := maxf(1.5, u * 0.09)
	match g:
		"bolt":
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -u), c + Vector2(u * 0.55, 0), c + Vector2(0, u), c + Vector2(-u * 0.55, 0), c + Vector2(0, -u)]), col, w * 1.2)
			ci.draw_circle(c, u * 0.18, col)
			for k in 3:
				var y := (float(k) - 1.0) * u * 0.35
				ci.draw_line(c + Vector2(-u * 1.25, y), c + Vector2(-u * 0.75, y), Color(col, 0.6), w * 0.8)
		"lance":
			var a := c + Vector2(-u, u)
			var b := c + Vector2(u, -u)
			ci.draw_line(a, b, col, w * 1.4)
			ci.draw_colored_polygon(PackedVector2Array([b + Vector2(0.2, -0.2) * u, b + Vector2(-0.55, -0.05) * u, b + Vector2(0.05, 0.55) * u]), col)
			ci.draw_line(a, a + Vector2(-0.2, 0.45) * u, col, w)
			ci.draw_line(a, a + Vector2(-0.45, 0.2) * u, col, w)
		"nova":
			ci.draw_arc(c, u * 0.35, 0, TAU, 24, col, w * 1.2)
			ci.draw_arc(c, u * 0.85, 0, TAU, 32, Color(col, 0.7), w)
			for k in 8:
				var v := Vector2.from_angle(TAU * float(k) / 8.0)
				ci.draw_line(c + v * u * 0.5, c + v * u * 0.72, col, w)
		"ward":
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.25) * u, Vector2(0.9, 1.05) * u), col, false, w)
			ci.draw_line(c + Vector2(-0.25, -0.25) * u, c + Vector2(0, -0.6) * u, col, w)
			ci.draw_line(c + Vector2(0.25, -0.25) * u, c + Vector2(0, -0.6) * u, col, w)
			_flame(ci, c + Vector2(0, 0.3) * u, u * 0.5, col.lightened(0.2))
		"step":
			for k in 2:
				var x := (float(k) * 0.55 - 0.15) * u
				ci.draw_polyline(PackedVector2Array([c + Vector2(x - 0.35 * u, -0.6 * u), c + Vector2(x + 0.25 * u, 0), c + Vector2(x - 0.35 * u, 0.6 * u)]), col, w * 1.2)
			for k in 3:
				ci.draw_circle(c + Vector2(-u * (0.7 + 0.28 * float(k)), 0), u * (0.09 - 0.02 * float(k)), Color(col, 0.7 - 0.2 * float(k)))
		"hearth":
			ci.draw_line(c + Vector2(-0.8, 0.7) * u, c + Vector2(0.8, 0.7) * u, col, w * 1.3)
			ci.draw_line(c + Vector2(-0.55, 0.85) * u, c + Vector2(-0.7, 1.0) * u, col, w)
			ci.draw_line(c + Vector2(0.55, 0.85) * u, c + Vector2(0.7, 1.0) * u, col, w)
			_flame(ci, c + Vector2(0, 0.2) * u, u * 1.1, col)
			_flame(ci, c + Vector2(0, 0.35) * u, u * 0.55, col.lightened(0.45))
		"coals":
			for p: Vector2 in [Vector2(-0.45, 0.35), Vector2(0.4, 0.4), Vector2(0.0, 0.0), Vector2(-0.15, 0.55), Vector2(0.25, -0.05)]:
				ci.draw_circle(c + p * u, u * 0.26, Color(col.darkened(0.35)))
				ci.draw_circle(c + p * u + Vector2(-0.05, -0.06) * u, u * 0.12, col.lightened(0.3))
			ci.draw_arc(c + Vector2(0, 0.2) * u, u * 0.95, PI * 1.1, PI * 1.9, 18, Color(col, 0.6), w)
		"will":
			_flame(ci, c + Vector2(0, 0.25) * u, u * 1.25, col)
			ci.draw_circle(c + Vector2(0, 0.1) * u, u * 0.2, Color(0.06, 0.03, 0.08))
			for k in 4:
				var v := Vector2.from_angle(-PI * 0.5 + (float(k) - 1.5) * 0.55)
				ci.draw_line(c + v * u * 1.0, c + v * u * 1.25, Color(col, 0.7), w)
		"quick":
			ci.draw_arc(c, u * 0.75, 0, TAU, 32, Color(col, 0.55), w)
			ci.draw_line(c, c + Vector2(0, -0.55) * u, col, w * 1.2)
			ci.draw_line(c, c + Vector2(0.4, 0.15) * u, col, w * 1.2)
			_flame(ci, c + Vector2(0.75, -0.55) * u, u * 0.45, col.lightened(0.3))
		"cord":
			var pts := PackedVector2Array()
			for k in 17:
				var t := float(k) / 16.0
				pts.append(c + Vector2(lerpf(-0.95, 0.95, t), -0.55 + sin(t * PI) * 0.75) * u)
			ci.draw_polyline(pts, col, w)
			for t: float in [0.25, 0.5, 0.75]:
				var p := c + Vector2(lerpf(-0.95, 0.95, t), -0.55 + sin(t * PI) * 0.75) * u
				ci.draw_circle(p + Vector2(0, 0.22) * u, u * 0.16, col.lightened(0.25))
				ci.draw_line(p, p + Vector2(0, 0.1) * u, col, w * 0.7)
		"hollow":
			ci.draw_circle(c, u * 0.8, Color(col, 0.18))
			ci.draw_arc(c, u * 0.8, 0, TAU, 32, col, w)
			ci.draw_circle(c + Vector2(-0.3, -0.12) * u, u * 0.17, col)
			ci.draw_circle(c + Vector2(0.3, -0.12) * u, u * 0.17, col)
			ci.draw_arc(c + Vector2(0, 0.42) * u, u * 0.22, PI, TAU, 10, col, w)
		"tally":
			for k in 4:
				var x := (float(k) - 1.5) * 0.32 * u
				ci.draw_line(c + Vector2(x, -0.7 * u), c + Vector2(x, 0.7 * u), col, w * 1.2)
			ci.draw_line(c + Vector2(-0.8, 0.55) * u, c + Vector2(0.8, -0.55) * u, col.lightened(0.3), w * 1.2)
		"door":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.55, 0.9) * u, c + Vector2(-0.55, -0.35) * u, c + Vector2(0, -0.9) * u, c + Vector2(0.55, -0.35) * u, c + Vector2(0.55, 0.9) * u]), col, w * 1.2)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.55, 0.9) * u, c + Vector2(-0.55, -0.35) * u, c + Vector2(-0.1, -0.15) * u, c + Vector2(-0.1, 0.95) * u]), Color(col, 0.45))
		"bramble":
			ci.draw_arc(c, u * 0.75, 0, TAU, 28, col, w * 1.2)
			for k in 10:
				var v := Vector2.from_angle(TAU * float(k) / 10.0)
				var tip := v.rotated(0.35) * u * 1.05
				ci.draw_colored_polygon(PackedVector2Array([c + v * u * 0.68, c + v.rotated(0.2) * u * 0.8, c + tip]), col)
			ci.draw_circle(c, u * 0.22, col.lightened(0.2))
		"skull":
			ci.draw_circle(c + Vector2(0, -0.15) * u, u * 0.62, col)
			ci.draw_rect(Rect2(c + Vector2(-0.38, 0.25) * u, Vector2(0.76, 0.4) * u), col)
			ci.draw_circle(c + Vector2(-0.25, -0.2) * u, u * 0.16, Color(0.05, 0.03, 0.06))
			ci.draw_circle(c + Vector2(0.25, -0.2) * u, u * 0.16, Color(0.05, 0.03, 0.06))
		"crown":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.7, 0.45) * u, c + Vector2(0.7, 0.45) * u, c + Vector2(0.7, -0.3) * u, c + Vector2(0.35, 0.06) * u, c + Vector2(0, -0.58) * u, c + Vector2(-0.35, 0.06) * u, c + Vector2(-0.7, -0.3) * u]), col)
			for x: float in [-0.38, 0.0, 0.38]:
				ci.draw_circle(c + Vector2(x, 0.28) * u, u * 0.09, Color(0.5, 0.1, 0.15))
		"sigil":
			ci.draw_arc(c, u * 0.7, 0, TAU, 32, col, w * 1.1)
			ci.draw_arc(c, u * 0.45, 0, TAU, 24, col, w * 0.7)
			for k in 6:
				var v := Vector2.from_angle(TAU * float(k) / 6.0)
				ci.draw_line(c + v * u * 0.45, c + v * u * 0.7, col, w)
			ci.draw_circle(c, u * 0.12, col)
		"heart":
			ci.draw_circle(c + Vector2(-0.28, -0.18) * u, u * 0.38, col)
			ci.draw_circle(c + Vector2(0.28, -0.18) * u, u * 0.38, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.63, -0.05) * u, c + Vector2(0.63, -0.05) * u, c + Vector2(0, 0.7) * u]), col)
		"candle":
			ci.draw_rect(Rect2(c + Vector2(-0.22, -0.1) * u, Vector2(0.44, 0.85) * u), col.darkened(0.15))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, -0.1) * u, c + Vector2(0.22, -0.1) * u, c + Vector2(0.3, 0.05) * u, c + Vector2(0.22, 0.2) * u]), col.lightened(0.2))
			ci.draw_line(c + Vector2(0, -0.1) * u, c + Vector2(0, -0.28) * u, Color(0.1, 0.06, 0.05), w)
			_flame(ci, c + Vector2(0, -0.35) * u, u * 0.5, Color(1.0, 0.75, 0.35))
			ci.draw_rect(Rect2(c + Vector2(-0.5, 0.75) * u, Vector2(1.0, 0.14) * u), col.darkened(0.5))
		"thread":
			var pts := PackedVector2Array()
			for k in 40:
				var t := float(k) / 39.0
				pts.append(c + Vector2(cos(t * TAU * 2.5) * (0.55 - t * 0.2), sin(t * TAU * 2.5) * (0.3 - t * 0.08) + (t - 0.5) * 0.9) * u)
			ci.draw_polyline(pts, col, w * 1.1)
			ci.draw_line(pts[pts.size() - 1], pts[pts.size() - 1] + Vector2(0.35, 0.35) * u, col, w)
		"lens":
			ci.draw_circle(c, u * 0.65, Color(col, 0.28))
			ci.draw_arc(c, u * 0.65, 0, TAU, 32, col, w * 1.3)
			ci.draw_arc(c + Vector2(-0.12, -0.12) * u, u * 0.38, PI * 1.05, PI * 1.45, 8, col.lightened(0.5), w)
			ci.draw_line(c + Vector2(0.46, 0.46) * u, c + Vector2(0.8, 0.8) * u, col.darkened(0.3), w * 1.4)
		"bead":
			ci.draw_line(c + Vector2(-0.9, -0.7) * u, c + Vector2(0.9, 0.7) * u, Color(col, 0.35), w * 0.7)
			ci.draw_circle(c, u * 0.45, col)
			ci.draw_circle(c, u * 0.14, Color(0.08, 0.05, 0.08))
			for k in 6:
				var v := Vector2.from_angle(TAU * float(k) / 6.0 + 0.3)
				ci.draw_line(c + v * u * 0.24, c + v * u * 0.38, col.darkened(0.35), w * 0.6)
		"bell":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, -0.6) * u, c + Vector2(0.22, -0.6) * u, c + Vector2(0.35, 0.1) * u, c + Vector2(0.62, 0.5) * u, c + Vector2(-0.62, 0.5) * u, c + Vector2(-0.35, 0.1) * u]), col)
			ci.draw_circle(c + Vector2(0.15, 0.7) * u, u * 0.14, col.lightened(0.25))
			ci.draw_line(c + Vector2(0, -0.6) * u, c + Vector2(0, -0.8) * u, col, w)
		"ring":
			ci.draw_arc(c, u * 0.55, 0, TAU, 32, col, w * 2.4)
			ci.draw_arc(c, u * 0.55, PI * 1.15, PI * 1.5, 8, col.lightened(0.45), w)
		"fist":
			for k in 4:
				var x := (float(k) - 1.5) * 0.32
				ci.draw_arc(c + Vector2(x, -0.1) * u, u * 0.16, 0, TAU, 14, col, w * 1.3)
			ci.draw_rect(Rect2(c + Vector2(-0.62, 0.12) * u, Vector2(1.24, 0.5) * u), Color(col, 0.55))
		"tablet":
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.75) * u, Vector2(1.2, 1.5) * u), Color(col, 0.3))
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.75) * u, Vector2(1.2, 1.5) * u), col, false, w)
			for row in 3:
				var y := (-0.4 + 0.38 * float(row)) * u
				for k in (4 if row < 2 else 3):
					ci.draw_line(c + Vector2((-0.4 + 0.18 * float(k)) * u, y - 0.12 * u), c + Vector2((-0.4 + 0.18 * float(k)) * u, y + 0.12 * u), col, w * 0.8)
				if row < 2:
					ci.draw_line(c + Vector2(-0.48, 0.1) * u + Vector2(0, y), c + Vector2(0.2, -0.1) * u + Vector2(0, y), col, w * 0.8)
		"branch":
			ci.draw_line(c + Vector2(-0.2, 0.9) * u, c + Vector2(0.1, -0.85) * u, col, w * 1.6)
			for t: float in [-0.5, -0.05, 0.4]:
				var p0 := c + Vector2(-0.2 + (0.9 - t) / 1.75 * 0.3, t) * u
				var side := 1.0 if t > 0.0 else -1.0
				ci.draw_line(p0, p0 + Vector2(0.45 * side, -0.35) * u, col, w * 1.2)
				ci.draw_colored_polygon(PackedVector2Array([p0 + Vector2(0.12 * side, -0.05) * u, p0 + Vector2(0.28 * side, 0.05) * u, p0 + Vector2(0.2 * side, -0.18) * u]), col.lightened(0.2))
		"stone":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.7, 0.3) * u, c + Vector2(-0.45, -0.45) * u, c + Vector2(0.2, -0.65) * u, c + Vector2(0.7, -0.15) * u, c + Vector2(0.55, 0.5) * u, c + Vector2(-0.2, 0.62) * u]), col)
			ci.draw_line(c + Vector2(-0.9, -0.1) * u, c + Vector2(0.9, 0.15) * u, col.darkened(0.45), w * 1.3)
			_heartlet(ci, c + Vector2(0.05, 0.12) * u, u * 0.22, col.lightened(0.35))
		"lantern":
			ci.draw_arc(c + Vector2(0, -0.62) * u, u * 0.18, PI, TAU, 10, col, w)
			ci.draw_rect(Rect2(c + Vector2(-0.4, -0.45) * u, Vector2(0.8, 1.0) * u), col, false, w * 1.2)
			_flame(ci, c + Vector2(0, 0.25) * u, u * 0.55, col.lightened(0.3))
			for k in 3:
				ci.draw_circle(c + Vector2(-0.2 + 0.2 * float(k), 0.75 + 0.1 * float(k % 2)) * u, u * 0.05, Color(col, 0.6))
		"mask":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.55, -0.7) * u, c + Vector2(0.55, -0.7) * u, c + Vector2(0.6, 0.1) * u, c + Vector2(0.3, 0.7) * u, c + Vector2(-0.3, 0.7) * u, c + Vector2(-0.6, 0.1) * u]), col)
			for k in 5:
				var y := (-0.5 + 0.22 * float(k)) * u
				ci.draw_line(c + Vector2(-0.4 * u, y), c + Vector2(0.4 * u, y + 0.06 * u), col.darkened(0.3), w * 0.7)
			_flame(ci, c + Vector2(0, 0.25) * u, u * 0.35, Color(1.0, 0.6, 0.3))
		"mound":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.9, 0.55) * u, c + Vector2(-0.5, -0.05) * u, c + Vector2(0, -0.5) * u, c + Vector2(0.5, -0.05) * u, c + Vector2(0.9, 0.55) * u]), col)
			ci.draw_circle(c + Vector2(-0.25, 0.08) * u, u * 0.1, col.lightened(0.3))
			ci.draw_circle(c + Vector2(0.3, 0.25) * u, u * 0.08, col.lightened(0.3))
		# --- skills, cores and build charms (r28) ---
		"tether":
			# a hook at the top right, a chain of links down to the bottom left
			for k in 4:
				var lc := c + Vector2(-0.75 + 0.36 * float(k), 0.75 - 0.36 * float(k)) * u
				ci.draw_arc(lc, u * 0.15, 0, TAU, 12, Color(col, 0.65 + 0.1 * float(k)), w)
			var hk := c + Vector2(0.55, -0.5) * u
			ci.draw_arc(hk + Vector2(0, 0.25) * u, u * 0.32, -PI * 0.1, PI * 1.05, 14, col, w * 1.3)
			ci.draw_line(hk + Vector2(0.31, 0.2) * u, hk + Vector2(0.32, -0.35) * u, col, w * 1.3)
			ci.draw_colored_polygon(PackedVector2Array([hk + Vector2(-0.32, 0.27) * u, hk + Vector2(-0.48, 0.05) * u, hk + Vector2(-0.18, 0.1) * u]), col)
		"well":
			# a spiral falling inward to a dark heart
			var pts := PackedVector2Array()
			for k in 40:
				var t := float(k) / 39.0
				pts.append(c + Vector2.from_angle(t * TAU * 2.2) * u * (0.95 - 0.8 * t))
			ci.draw_polyline(pts, col, w)
			ci.draw_circle(c, u * 0.17, col.lightened(0.25))
			ci.draw_circle(c, u * 0.09, Color(0.02, 0.0, 0.04))
		"familiar":
			# a hooded wisp with two eyes and a curling tail
			var body := PackedVector2Array()
			for k in 13:
				var a := PI + PI * float(k) / 12.0
				body.append(c + Vector2(cos(a) * 0.5, sin(a) * 0.55 - 0.1) * u)
			body.append(c + Vector2(0.45, 0.35) * u)
			body.append(c + Vector2(0.15, 0.25) * u)
			body.append(c + Vector2(-0.05, 0.75) * u)
			body.append(c + Vector2(-0.25, 0.3) * u)
			body.append(c + Vector2(-0.5, 0.4) * u)
			ci.draw_colored_polygon(body, Color(col, 0.35))
			body.append(body[0])
			ci.draw_polyline(body, col, w)
			ci.draw_circle(c + Vector2(-0.17, -0.18) * u, u * 0.08, col.lightened(0.5))
			ci.draw_circle(c + Vector2(0.17, -0.18) * u, u * 0.08, col.lightened(0.5))
		"core":
			ci.draw_circle(c, u * 0.62, Color(col, 0.3))
			ci.draw_arc(c, u * 0.62, 0, TAU, 28, col, w)
			ci.draw_arc(c, u * 0.85, -0.4, 0.4, 8, Color(col, 0.7), w)
			ci.draw_arc(c, u * 0.85, PI - 0.4, PI + 0.4, 8, Color(col, 0.7), w)
			ci.draw_circle(c, u * 0.22, col.lightened(0.4))
		"prism":
			var tri := PackedVector2Array([c + Vector2(0, -0.8) * u, c + Vector2(0.7, 0.55) * u, c + Vector2(-0.7, 0.55) * u, c + Vector2(0, -0.8) * u])
			ci.draw_colored_polygon(tri.slice(0, 3), Color(col, 0.25))
			ci.draw_polyline(tri, col, w * 1.1)
			for k in 3:
				var a := -0.35 + 0.35 * float(k)
				ci.draw_line(c + Vector2(0.25, 0.05) * u, c + Vector2(0.25, 0.05) * u + Vector2.from_angle(a) * u * 0.75, Color(col.lightened(0.3), 0.85), w * 0.8)
		"lodestar":
			var star := PackedVector2Array()
			for k in 9:
				var a := -PI * 0.5 + TAU * float(k) / 8.0
				star.append(c + Vector2.from_angle(a) * u * (0.85 if k % 2 == 0 else 0.32))
			ci.draw_colored_polygon(star, Color(col, 0.35))
			ci.draw_polyline(star, col, w)
			ci.draw_arc(c + Vector2(0.95, 0.35) * u, u * 0.5, PI * 0.75, PI * 1.35, 8, Color(col, 0.6), w * 0.8)
		"cinder":
			_flame(ci, c + Vector2(0, 0.35) * u, u * 1.1, col)
			_flame(ci, c + Vector2(0, 0.42) * u, u * 0.55, col.lightened(0.45))
			ci.draw_arc(c + Vector2(0, 0.3) * u, u * 0.7, 0.3, PI - 0.3, 10, Color(col, 0.5), w)
		"rime":
			for k in 3:
				var v := Vector2.from_angle(PI * float(k) / 3.0) * u * 0.85
				ci.draw_line(c - v, c + v, col, w * 1.1)
				for sgn: float in [-1.0, 1.0]:
					var b := c + v * 0.55 * sgn
					ci.draw_line(b, b + v.rotated(0.7 * sgn).normalized() * u * 0.22 * sgn, col, w * 0.8)
			ci.draw_circle(c, u * 0.12, col.lightened(0.4))
		"hook":
			ci.draw_line(c + Vector2(0.2, -0.85) * u, c + Vector2(0.2, 0.2) * u, col, w * 1.3)
			ci.draw_arc(c + Vector2(-0.15, 0.2) * u, u * 0.35, 0, PI, 12, col, w * 1.3)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.5, 0.2) * u, c + Vector2(-0.62, -0.08) * u, c + Vector2(-0.3, 0.05) * u]), col)
			ci.draw_arc(c + Vector2(0.2, -0.85) * u, u * 0.12, 0, TAU, 10, col, w)
		"rosary":
			for k in 9:
				var a := PI * 0.15 + PI * 1.7 * float(k) / 8.0
				ci.draw_circle(c + Vector2(cos(a), sin(a) - 0.15) * u * 0.6, u * 0.11, col)
			ci.draw_line(c + Vector2(0, 0.45) * u, c + Vector2(0, 0.95) * u, col, w)
			ci.draw_line(c + Vector2(-0.18, 0.65) * u, c + Vector2(0.18, 0.65) * u, col, w)
		"ferrule":
			# an iron staff-shoe: a short tapered sleeve with a rivet and a ring
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.8) * u, c + Vector2(0.3, -0.8) * u, c + Vector2(0.16, 0.7) * u, c + Vector2(0, 0.95) * u, c + Vector2(-0.16, 0.7) * u]), Color(col, 0.45))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.3, -0.8) * u, c + Vector2(0.3, -0.8) * u, c + Vector2(0.16, 0.7) * u, c + Vector2(0, 0.95) * u, c + Vector2(-0.16, 0.7) * u, c + Vector2(-0.3, -0.8) * u]), col, w)
			ci.draw_line(c + Vector2(-0.32, -0.45) * u, c + Vector2(0.32, -0.45) * u, col, w * 1.3)
			ci.draw_circle(c + Vector2(0, -0.1) * u, u * 0.08, col.lightened(0.4))
		"waystone":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.45, 0.8) * u, c + Vector2(-0.4, -0.5) * u, c + Vector2(-0.1, -0.85) * u, c + Vector2(0.35, -0.6) * u, c + Vector2(0.45, 0.8) * u]), Color(col, 0.4))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.45, 0.8) * u, c + Vector2(-0.4, -0.5) * u, c + Vector2(-0.1, -0.85) * u, c + Vector2(0.35, -0.6) * u, c + Vector2(0.45, 0.8) * u]), col, w)
			ci.draw_line(c + Vector2(-0.2, -0.2) * u, c + Vector2(0.2, -0.2) * u, col, w)
			ci.draw_line(c + Vector2(0, -0.4) * u, c + Vector2(0, 0.3) * u, col, w)
		"chalk":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.7, 0.25) * u, c + Vector2(0.45, -0.6) * u, c + Vector2(0.7, -0.3) * u, c + Vector2(-0.45, 0.55) * u]), col)
			for k in 4:
				var x := -0.7 + 0.28 * float(k)
				ci.draw_line(c + Vector2(x, 0.65) * u, c + Vector2(x + 0.06, 0.95) * u, Color(col, 0.7), w * 0.8)
			ci.draw_line(c + Vector2(-0.78, 0.92) * u, c + Vector2(0.2, 0.68) * u, Color(col, 0.7), w * 0.8)
		"jar":
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.35) * u, Vector2(0.9, 1.1) * u), Color(col, 0.25))
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.35) * u, Vector2(0.9, 1.1) * u), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-0.28, -0.62) * u, Vector2(0.56, 0.27) * u), col)
			ci.draw_circle(c + Vector2(0, 0.2) * u, u * 0.2, col.lightened(0.5))
		_:
			return false
	return true


static func _flame(ci: CanvasItem, base: Vector2, h: float, col: Color) -> void:
	# a teardrop: round at the bottom, a point on top
	var pts := PackedVector2Array()
	for k in 16:
		var a := PI * float(k) / 15.0              # 0..PI round the bottom
		pts.append(base + Vector2(cos(a) * h * 0.3, sin(a) * h * 0.3))
	pts.append(base + Vector2(-h * 0.22, -h * 0.35))
	pts.append(base + Vector2(0, -h * 0.75))
	pts.append(base + Vector2(h * 0.22, -h * 0.35))
	ci.draw_colored_polygon(pts, col)


static func _heartlet(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-r * 0.45, -r * 0.2), r * 0.5, col)
	ci.draw_circle(c + Vector2(r * 0.45, -r * 0.2), r * 0.5, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.92, 0), c + Vector2(r * 0.92, 0), c + Vector2(0, r * 0.95)]), col)


## The "category/id" glyph for painted art that exists, else `fallback` (the old drawn glyph name).
static func art_glyph(category: String, id: String, fallback: String) -> String:
	return "%s/%s" % [category, id] if IconArt.art(category, id) != null else fallback


## The glyph for an item id: its painted icon, else the shape its ItemDB entry names.
static func item_glyph(id: String) -> String:
	return art_glyph("item", id, String(ItemDB.def(id).get("shape", "mound")))


## The glyph for a shop row (ui/shop.gd): goods by item, Hearth meals/works/trades, village wares.
static func row_glyph(r: Dictionary) -> String:
	var id := String(r.get("id", ""))
	var g := String(r.get("glyph", ""))
	if r.has("item"):
		return item_glyph(String(r.item))
	if id.begins_with("meal:") or id.begins_with("work:"):
		return art_glyph("hearth", id.get_slice(":", 1), g)
	if id == "smelt":
		return item_glyph("ember_shard")
	if id.begins_with("trade:"):
		var gives: Dictionary = HearthDB.trade(id.get_slice(":", 1)).get("gives", {})
		for k: String in gives:
			return item_glyph(k)
	return art_glyph("village", g, g)


## Satchel hook: the icon for an item id (a painted square when there is one; charms and anything else
## the Satchel lacks otherwise draw their shape).
static func item(ci: CanvasItem, id: String, c: Vector2, u: float) -> bool:
	var art := IconArt.art("item", id)
	if art != null:
		IconArt.draw_square(ci, art, Rect2(c - Vector2(u, u) * 1.55, Vector2(u, u) * 3.1))
		return true
	var d := ItemDB.def(id)
	return draw(ci, String(d.get("shape", "")), c, u, d.get("tint", Color.WHITE))


## Satchel hook: an extra line under a charm's text (worn or not, and where to change it).
static func note(id: String) -> String:
	if String(ItemDB.def(id).kind) == "core":
		var cur := DB.core_of(Travel.system_state("progression"))
		return "\n\nIn the orb now." if cur == id else "\n\nNot in the orb. Set it at a kindled fire: Kindling [%s], Staff." % InputSetup.live_label("kindling", Settings.using_pad, "K")
	if String(ItemDB.def(id).kind) != "charm":
		return ""
	var st := Travel.system_state("progression")
	var w := DB.worn(st)
	if w.has(id):
		return "\n\nWorn (%d of %d cords). Take it off in the Kindling [%s]." % [w.size(), DB.slots(st), InputSetup.live_label("kindling", Settings.using_pad, "K")]
	return "\n\nNot worn (%d of %d cords). Wear it from the Kindling [%s]." % [w.size(), DB.slots(st), InputSetup.live_label("kindling", Settings.using_pad, "K")]
