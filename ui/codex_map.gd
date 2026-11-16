extends Control
## The journal's map page (Journal > Map): the valley north-up. Regions lit once walked (a faint outline
## otherwise) and named in Cinzel, the roads drawn heavy with a dark casing, the rift, ember diamonds for the
## secret places found, the fires, the Keg and the tasks' places as painted coins (the named ones labelled),
## and the wanderer as a gilt arrow facing the way she faces, in a ring of light, which is the one thing on the
## page that is never mistaken for a place. Not a second source of truth: ui/codex.gd fills it (marks, pins,
## regions, focus, you).
## Load by path (no class_name): const MapView := preload("res://ui/codex_map.gd")

var font: Font
var title_font: Font
var marks: Array = []
var pins: Array = []                ## braziers, the Keg, the tasks' places and the markers ({at, kind, name, mk?})
var regions: Array = []
var focus := Vector2.INF
var you := Vector2.INF
var you_dir := Vector2(0.0, -1.0)    ## the way the wanderer faces on the ground plane (north-up: -Y is north)

const M_INK := Color(0.93, 0.88, 0.8)
const M_EMBER := Color(1.0, 0.62, 0.3)
const M_EDGE := Color(0.46, 0.34, 0.26)
const M_QUIET := Color(0.6, 0.55, 0.62)
const ROAD := Color(0.92, 0.82, 0.62)
const YOU := Color(1.0, 0.9, 0.55)
## Markers that come and go with the night (gatherables, foes, chests, the traders' stalls) are not places: the
## book leaves them to the corner map, so the page is the places and not sixty dots.
const NOT_PLACES := ["gather", "foe", "chest", "vendor", "trainer", "rare"]
## Markers whose name is worth writing on the page.
const NAMED := ["travel", "watch", "boss", "bell", "keg"]


func _scale() -> float:
	var b := RealmLayout.BOUNDS
	return minf((size.x - 20.0) / b.size.x, (size.y - 20.0) / b.size.y)


func _to(p: Vector2) -> Vector2:
	var b := RealmLayout.BOUNDS
	var s := _scale()
	var off := (size - b.size * s) * 0.5
	return off + (p - b.position) * s


func _area(r: Dictionary) -> float:
	if r.has("rect"):
		return (r.rect as Rect2).get_area()
	return PI * float(r.r) * float(r.r)


## Text with a dark halo, so a name reads over a region's fill and a road alike.
func _name(f: Font, at: Vector2, t: String, pt: int, col: Color) -> void:
	draw_string_outline(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, pt, 5, Color(0.03, 0.02, 0.015, 0.92))
	draw_string(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, pt, col)


## Place a label centred on `c` unless it would land on one already written; true when it was written.
func _label(f: Font, c: Vector2, t: String, pt: int, col: Color, taken: Array[Rect2], nudge := true) -> bool:
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
	var at := c - Vector2(w * 0.5, 0)
	at.x = clampf(at.x, 6.0, size.x - w - 6.0)
	var box := Rect2(at + Vector2(-3, -pt), Vector2(w + 6, pt + 6))
	for tries in 6:
		var hit := false
		for o in taken:
			if o.intersects(box):
				hit = true
				break
		if not hit:
			taken.append(box)
			_name(f, at, t, pt, col)
			return true
		if not nudge:
			return false
		box.position.y += pt + 4.0
		at.y += pt + 4.0
	return false


func _draw() -> void:
	var b := RealmLayout.BOUNDS
	var s := _scale()
	var r0 := _to(b.position)
	draw_rect(Rect2(r0, b.size * s), Color(0.09, 0.065, 0.05, 0.95))
	draw_rect(Rect2(r0, b.size * s), M_EDGE, false, 2.0)
	# regions: lit once walked
	for rs: Dictionary in regions:
		var r: Dictionary = rs.r
		var known: bool = rs.known
		var fill := Color(0.62, 0.42, 0.26, 0.15) if known else Color(0.3, 0.26, 0.3, 0.05)
		var line := Color(0.7, 0.5, 0.34, 0.7) if known else Color(0.4, 0.36, 0.42, 0.25)
		if String(r.get("biome", "")) == "ash" and String(r.id) == "ashrift" and known:
			fill = Color(0.5, 0.12, 0.05, 0.3)
		if r.has("rect"):
			var rc: Rect2 = r.rect
			var a := _to(rc.position)
			var e := _to(rc.end)
			draw_rect(Rect2(a, e - a), fill)
			draw_rect(Rect2(a, e - a), line, false, 1.5)
		else:
			var c := _to(r.c)
			var rad := float(r.r) * s
			draw_circle(c, rad, fill)
			draw_arc(c, rad, 0.0, TAU, 48, line, 1.5)
	# the roads: heavy, with a dark casing, so the map reads as ways between places
	for path: Dictionary in RealmLayout.PATHS:
		var pts := PackedVector2Array()
		for q: Vector2 in path.pts:
			pts.append(_to(q))
		draw_polyline(pts, Color(0.02, 0.012, 0.008, 0.85), 7.0, true)
		draw_polyline(pts, Color(ROAD, 0.82), 3.5, true)
	# secret places
	for m: Dictionary in marks:
		var p := _to(m.at)
		var d := 6.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), M_EMBER)
	# braziers (a flame, grey until kindled), the Keg (a warm square), tasks (gold rings), the places the corner map shows
	var spots: Array[Vector2] = []
	for pn: Dictionary in pins:
		if String(pn.get("mk", "")) in NOT_PLACES:
			continue
		var pp := _to(pn.at)
		spots.append(pp)
		var icon := String(pn.get("mk", "")) if String(pn.kind) == "mark" else String(pn.kind).replace("task", "quest_target")
		if IconArt.draw_mark(self, "mark", icon, pp, 26.0):
			continue                  # (the painted coins; "mark", the secret places, have none and keep their diamond)
		match String(pn.kind):
			"fire", "ash":
				var col := M_EMBER if String(pn.kind) == "fire" else Color(0.55, 0.5, 0.52, 0.8)
				draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -9), pp + Vector2(5, 1), pp + Vector2(3, 5), pp + Vector2(-3, 5), pp + Vector2(-5, 1)]), col)
			"mark":
				var mc: Color = pn.get("col", Color(1.0, 0.8, 0.4))
				draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -6), pp + Vector2(6, 0), pp + Vector2(0, 6), pp + Vector2(-6, 0)]), mc)
	# names: the places walked (smaller first, so a big region's name never hides a small one's), then the
	# named pins that find room
	var taken: Array[Rect2] = []
	if you != Vector2.INF:
		taken.append(Rect2(_to(you) - Vector2(24, 24), Vector2(48, 48)))        # a name is not written over the wanderer
	for sp: Vector2 in spots:
		taken.append(Rect2(sp - Vector2(14, 14), Vector2(28, 28)))              # nor over a coin
	if title_font:
		var order := regions.duplicate()
		order.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return _area(a.r) < _area(c.r))
		for rs: Dictionary in order:
			if not bool(rs.known):
				continue
			var r: Dictionary = rs.r
			var c2: Vector2 = (r.rect as Rect2).get_center() if r.has("rect") else r.c
			_label(title_font, _to(c2), String(rs.name).to_upper(), 17, Color(M_INK, 0.92), taken)
	if font:
		var counts := {}
		for pn: Dictionary in pins:
			counts[String(pn.name)] = int(counts.get(String(pn.name), 0)) + 1
		for pn: Dictionary in pins:
			var mk := String(pn.get("mk", pn.kind))
			if mk in NOT_PLACES or not (mk in NAMED or String(pn.kind) in NAMED):
				continue
			var nm := String(pn.name)
			if nm == "" or nm == mk or nm.length() > 30 or int(counts[nm]) > 1 or nm in ["StairFoot", "Shrine", "Landing", "Threshold"]:
				continue                              # (a name given to a dozen fires says nothing of any one)
			_label(font, _to(pn.at) + Vector2(0, 30), nm, 15, Color(M_INK, 0.85), taken, false)
	if focus != Vector2.INF:
		var fp := _to(focus)
		draw_arc(fp, 13.0, 0.0, TAU, 24, Color(0.02, 0.012, 0.008, 0.9), 4.0, true)
		draw_arc(fp, 13.0, 0.0, TAU, 24, M_INK, 2.0, true)
		draw_arc(fp, 19.0, 0.0, TAU, 24, Color(M_INK, 0.45), 1.5, true)
	if you != Vector2.INF:
		_draw_you(_to(you))
	if title_font:
		_name(title_font, r0 + Vector2(12, 26), "N", 20, M_QUIET)


## The wanderer: a gilt arrow facing her heading in a ring of light, outlined dark so it holds over any ground.
func _draw_you(c: Vector2) -> void:
	draw_circle(c, 22.0, Color(YOU, 0.10))
	draw_circle(c, 15.0, Color(YOU, 0.16))
	draw_arc(c, 16.0, 0.0, TAU, 28, Color(0.02, 0.012, 0.008, 0.9), 4.0, true)
	draw_arc(c, 16.0, 0.0, TAU, 28, Color(YOU, 0.95), 1.8, true)
	var f := you_dir.normalized() if you_dir.length() > 0.01 else Vector2(0.0, -1.0)
	var n := Vector2(-f.y, f.x)
	var tip := c + f * 13.0
	var l := c - f * 8.0 + n * 8.0
	var r := c - f * 8.0 - n * 8.0
	var notch := c - f * 3.0
	var arrow := PackedVector2Array([tip, r, notch, l])
	var casing := PackedVector2Array([tip + f * 3.0, r - n * 2.5 - f * 2.5, notch + f * 1.5, l + n * 2.5 - f * 2.5])
	draw_colored_polygon(casing, Color(0.02, 0.012, 0.008, 0.95))
	draw_colored_polygon(arrow, YOU)
	draw_colored_polygon(PackedVector2Array([tip, notch, l]), YOU.lightened(0.45))
