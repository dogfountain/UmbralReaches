extends RefCounted
## Forged pieces for the HUD, drawn in code on whatever CanvasItem is passed in: a bevelled bronze plate,
## a recessed trough, a bar with a lit fill and a lost-health trail, a strip with tapered ends, rivets and
## finials, and outlined text. Every piece takes an alpha `a` so a fading HUD fades whole.
## Load by path (no class_name): const Forge := preload("res://ui/hud_forge.gd")

const Med := preload("res://ui/medieval_style.gd")

const BODY := Color(0.055, 0.034, 0.022)
const WELL := Color(0.018, 0.011, 0.01)
const OUTLINE := Color(0.02, 0.012, 0.006)
const BEVEL_LIT := Color(0.86, 0.66, 0.34)
const BEVEL_MID := Color(0.5, 0.35, 0.16)
const BEVEL_DARK := Color(0.22, 0.14, 0.06)


static func rivet(ci: CanvasItem, c: Vector2, rad: float, a := 1.0) -> void:
	ci.draw_circle(c + Vector2(0.4, 0.7), rad, Color(0, 0, 0, 0.6 * a))
	ci.draw_circle(c, rad, Color(Med.BRONZE.darkened(0.2), a))
	ci.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.35), rad * 0.5, Color(Med.GILT, 0.9 * a))


## Text with a short dark halo (two pixels): small type stays crisp where the heavy outlines clogged it.
static func label(ci: CanvasItem, font: Font, at: Vector2, text: String, pt: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, halo := 3) -> void:
	ci.draw_string_outline(font, at, text, align, w, pt, halo, Color(0.0, 0.0, 0.0, 0.85 * col.a))
	ci.draw_string(font, at, text, align, w, pt, col)


## A bevelled bronze rim round `r` (drawn inside it): lit on top and left, in shadow below and right.
static func bevel(ci: CanvasItem, r: Rect2, a := 1.0, w := 3.0, tint := Color.WHITE) -> void:
	var lit := BEVEL_LIT * tint
	var mid := BEVEL_MID * tint
	var dark := BEVEL_DARK * tint
	ci.draw_rect(r, Color(mid.r, mid.g, mid.b, a), false, w)
	var h := w * 0.5
	var p0 := r.position + Vector2(h, h)
	var p1 := Vector2(r.end.x - h, r.position.y + h)
	var p2 := r.end - Vector2(h, h)
	var p3 := Vector2(r.position.x + h, r.end.y - h)
	ci.draw_line(p3, p0, Color(lit.r, lit.g, lit.b, 0.85 * a), 1.0)
	ci.draw_line(p0, p1, Color(lit.r, lit.g, lit.b, 0.95 * a), 1.0)
	ci.draw_line(p1, p2, Color(dark.r, dark.g, dark.b, a), 1.0)
	ci.draw_line(p2, p3, Color(dark.r, dark.g, dark.b, a), 1.0)
	ci.draw_rect(r.grow(1.0), Color(OUTLINE, 0.95 * a), false, 1.0)


## A framed plate: soft shadow, dark leather body, a bevelled bronze rim, a dark recess line and rivets.
static func plate(ci: CanvasItem, r: Rect2, a := 1.0, tint := Color.WHITE, rivets := true) -> void:
	ci.draw_rect(r.grow(3.0), Color(0, 0, 0, 0.35 * a))
	ci.draw_rect(r, Color(BODY, 0.94 * a))
	bevel(ci, r, a, 3.0, tint)
	ci.draw_rect(r.grow(-4.0), Color(0, 0, 0, 0.55 * a), false, 1.0)
	if rivets:
		for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			rivet(ci, c, 2.6, a)


## A recessed well: dark floor, a dark top edge, a faint lit lip underneath.
static func trough(ci: CanvasItem, r: Rect2, a := 1.0) -> void:
	ci.draw_rect(r, Color(WELL, 0.95 * a))
	ci.draw_line(r.position + Vector2(0, 0.5), Vector2(r.end.x, r.position.y + 0.5), Color(0, 0, 0, 0.9 * a), 1.0)
	ci.draw_line(Vector2(r.position.x, r.end.y + 0.5), Vector2(r.end.x, r.end.y + 0.5), Color(BEVEL_LIT, 0.35 * a), 1.0)
	ci.draw_rect(r, Color(Med.BRONZE.darkened(0.35), 0.9 * a), false, 1.0)


## A fill with a vertical gradient (lit at the top, deep at the foot), a sheen line and a bright leading edge.
static func fill(ci: CanvasItem, r: Rect2, col: Color, a := 1.0) -> void:
	if r.size.x < 0.5:
		return
	var top := col.lightened(0.22)
	var foot := col.darkened(0.42)
	var mid := col
	var hh := r.size.y
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + hh * 0.5), Vector2(r.position.x, r.position.y + hh * 0.5)])
	ci.draw_polygon(pts, PackedColorArray([Color(top, a), Color(top, a), Color(mid, a), Color(mid, a)]))
	var pts2 := PackedVector2Array([Vector2(r.position.x, r.position.y + hh * 0.5), Vector2(r.end.x, r.position.y + hh * 0.5), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)])
	ci.draw_polygon(pts2, PackedColorArray([Color(mid, a), Color(mid, a), Color(foot, a), Color(foot, a)]))
	ci.draw_line(r.position + Vector2(0, 1.0), Vector2(r.end.x, r.position.y + 1.0), Color(1, 1, 1, 0.2 * a), 1.0)
	if r.size.x > 3.0:
		ci.draw_line(Vector2(r.end.x - 0.5, r.position.y), Vector2(r.end.x - 0.5, r.end.y), Color(1, 0.92, 0.8, 0.4 * a), 1.0)


## A bar in a trough. `trail` (when above `ratio`) is the strip that was just lost, in `lost` (darker, drains away);
## `segs` are 0..1 notches cut across it.
static func bar(ci: CanvasItem, r: Rect2, ratio: float, col: Color, a := 1.0, trail := -1.0, segs: Array = [], lost := Color(0.4, 0.07, 0.06)) -> void:
	trough(ci, r, a)
	var inner := r.grow(-2.0)
	if trail > ratio:
		ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(trail, 0.0, 1.0), inner.size.y)), Color(lost, 0.95 * a))
	fill(ci, Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y)), col, a)
	for n: float in segs:
		var x := inner.position.x + inner.size.x * n
		ci.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0.01, 0.005, 0.005, 0.95 * a), 2.0)
		ci.draw_line(Vector2(x + 1.5, inner.position.y), Vector2(x + 1.5, inner.end.y), Color(Med.GILT, 0.3 * a), 1.0)


## A lozenge finial: a bronze diamond with a gilt heart, `dir` -1 pointing left, +1 right.
static func finial(ci: CanvasItem, c: Vector2, dir: float, size: float, a := 1.0) -> void:
	var s := size
	var pts := PackedVector2Array([c + Vector2(-dir * s * 0.7, -s * 0.8), c + Vector2(dir * s * 0.9, 0), c + Vector2(-dir * s * 0.7, s * 0.8), c + Vector2(-dir * s * 0.2, 0)])
	ci.draw_colored_polygon(pts, Color(OUTLINE, a))
	var inner := PackedVector2Array([c + Vector2(-dir * s * 0.55, -s * 0.62), c + Vector2(dir * s * 0.72, 0), c + Vector2(-dir * s * 0.55, s * 0.62), c + Vector2(-dir * s * 0.12, 0)])
	ci.draw_colored_polygon(inner, Color(BEVEL_MID, a))
	ci.draw_polyline(PackedVector2Array([inner[0], inner[1], inner[2]]), Color(BEVEL_LIT, 0.9 * a), 1.0, true)
	ci.draw_circle(c + Vector2(dir * s * 0.08, 0), s * 0.2, Color(Med.GILT, a))


## A strip with tapered ends (a hexagon laid on its side): body, bronze rim, a recess line. Returns its inner rect.
static func strip(ci: CanvasItem, r: Rect2, a := 1.0, taper := 14.0, body := 0.86) -> Rect2:
	var t := minf(taper, r.size.x * 0.25)
	var ym := r.position.y + r.size.y * 0.5
	var pts := PackedVector2Array([
		Vector2(r.position.x + t, r.position.y), Vector2(r.end.x - t, r.position.y), Vector2(r.end.x, ym),
		Vector2(r.end.x - t, r.end.y), Vector2(r.position.x + t, r.end.y), Vector2(r.position.x, ym)])
	var shadow := PackedVector2Array()
	for p: Vector2 in pts:
		shadow.append(p + Vector2(0, 2.5))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3 * a))
	ci.draw_colored_polygon(pts, Color(BODY, body * a))
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(OUTLINE, 0.95 * a), 5.0, true)
	ci.draw_polyline(closed, Color(BEVEL_MID, a), 3.0, true)
	ci.draw_line(pts[5] + Vector2(1.5, 0), pts[0] + Vector2(0, 1.5), Color(BEVEL_LIT, 0.95 * a), 1.0, true)
	ci.draw_line(pts[0] + Vector2(0, 1.5), pts[1] + Vector2(0, 1.5), Color(BEVEL_LIT, 0.95 * a), 1.0, true)
	ci.draw_line(pts[1] + Vector2(0, 1.5), pts[2] + Vector2(-1.5, 0), Color(BEVEL_LIT, 0.7 * a), 1.0, true)
	ci.draw_line(pts[2] + Vector2(-1.5, 0), pts[3] + Vector2(0, -1.5), Color(BEVEL_DARK, a), 1.0, true)
	ci.draw_line(pts[3] + Vector2(0, -1.5), pts[4] + Vector2(0, -1.5), Color(BEVEL_DARK, a), 1.0, true)
	ci.draw_line(pts[4] + Vector2(0, -1.5), pts[5] + Vector2(1.5, 0), Color(BEVEL_DARK, a), 1.0, true)
	return Rect2(r.position + Vector2(t * 0.6, 3.0), r.size - Vector2(t * 1.2, 6.0))


## A small dark tab for a number or a name that sits over the world: haloed contrast, a bronze hairline.
static func tab(ci: CanvasItem, r: Rect2, a := 1.0) -> void:
	ci.draw_rect(r, Color(0.02, 0.012, 0.008, 0.72 * a))
	ci.draw_rect(r, Color(Med.BRONZE, 0.55 * a), false, 1.0)
