extends Control
## The compass strip (ENS art pass, docs/enshrouded/art.md): a thin engraved band at the top centre
## of the HUD. 180 degrees of heading across it, ticks every 15, the four winds in Cinzel (north in
## lantern gold), and the few marks worth a glance NOW. What is shown is decided by ui/compass_feed.gd (relevance by
## kind, range and the wanderer's need; Settings > Display > Compass Detail: Minimal / Standard / Full), see
## the compass doc (docs, compass.md): the followed step always; danger near; the nearest fire only when one is wanted (Gloom or wounds);
## quest givers near; far beacons as faint ticks. Marks fade with distance and merge when they overlap.
## Added by ui/hud.gd (one line). Reads the tree twice a second, draws every frame; no signals needed.
## Hidden while the tree is paused (menus, dialogue) and under the loading screen.

const LANTERN := Color("#FFB347")
const EMBER := Color("#FF6A2A")
const INK := Color(0.9, 0.84, 0.7)
const SPAN := deg_to_rad(180.0)          ## heading shown across the full width
const WIDTH := 500.0                     ## kept clear of the objective lines at the top right (1600 px wide and up)
const HEIGHT := 46.0
const STRIP_Y := 4.0                     ## the strip's top in the control
const STRIP_H := 38.0
const Forge := preload("res://ui/hud_forge.gd")
const QuestTrack := preload("res://core/story/quest_track.gd")
const Feed := preload("res://ui/compass_feed.gd")
const HudPrefs := preload("res://ui/hud_prefs.gd")
const DIST_PT := 19
const OUTLINE_TRI := Color(0.02, 0.012, 0.006)

var _font: Font
var _scan := 0.0
var _marks: Array[Dictionary] = []       ## CompassFeed.gather(): {pos, kind, col, d, range, ...}
var _alpha := 0.0
var _sig: Array = []
var _dirty := true


func _ready() -> void:
	name = "Compass"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 18.0
	offset_bottom = 18.0 + STRIP_Y + STRIP_H + 36.0
	_font = load("res://ui/fonts/Cinzel.ttf")


func _process(delta: float) -> void:
	var zone := get_tree().current_scene
	var hidden := get_tree().paused or (zone != null and zone.get_node_or_null("LoadingScreen") != null)
	_alpha = move_toward(_alpha, 0.0 if hidden else 1.0, delta * 4.0)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		_rescan()
		_dirty = true
	# redraw when the picture moves: the heading turned, the eye moved (the distance numbers), the marks
	# were re-read, or the strip fades. An invisible, settled compass is not a picture.
	var cam := get_viewport().get_camera_3d()
	var sig: Array = []
	if cam != null:
		var f := -cam.global_basis.z
		sig = [snappedf(atan2(f.x, -f.z), 0.0005), snappedf(cam.global_position.x, 0.5), snappedf(cam.global_position.z, 0.5), _alpha]
	if _dirty or sig != _sig:
		_sig = sig
		_dirty = false
		queue_redraw()


func _rescan() -> void:
	_marks.clear()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	HudPrefs.ensure()
	var tr := get_tree().get_first_node_in_group("quest_track") as QuestTrack
	var st: Dictionary = tr.current() if tr != null else {}
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var you := pl.global_position if pl != null else cam.global_position
	_marks = Feed.gather(get_tree(), cam.global_position, HudPrefs.compass_density, st, pl, you)


func _rank(kind: String) -> int:
	return {"goal": 0, "mark": 1, "danger": 2, "fire": 3, "tasker": 4}.get(kind, 5)


func _draw() -> void:
	if _alpha <= 0.001:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fwd := -cam.global_basis.z
	var yaw := atan2(fwd.x, -fwd.z)                 # 0 = north (-Z), clockwise
	var cx := WIDTH * 0.5
	var sr := Rect2(0.0, STRIP_Y, WIDTH, STRIP_H)
	var band_y := sr.position.y + sr.size.y * 0.5
	Forge.strip(self, sr, _alpha, 24.0)
	# ticks along the foot of the strip and the four winds
	var winds := {0: "N", 90: "E", 180: "S", 270: "W"}
	for deg in range(0, 360, 15):
		var x := _x_for(deg_to_rad(float(deg)), yaw)
		if x < 0.0:
			continue
		var a := _edge(x / WIDTH) * _alpha
		if not winds.has(deg):
			var h := 9.0 if deg % 45 == 0 else 5.0
			draw_line(Vector2(x, sr.end.y - 4.0), Vector2(x, sr.end.y - 4.0 - h), Color(INK.r, INK.g, INK.b, a * 0.6), 1.0)
	# the notch: a gilt pointer over the heading
	var tip := Vector2(cx, sr.position.y + 12.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 7.0, sr.position.y - 1.0), Vector2(cx + 7.0, sr.position.y - 1.0), tip]), Color(OUTLINE_TRI, _alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5.0, sr.position.y + 0.5), Vector2(cx + 5.0, sr.position.y + 0.5), tip + Vector2(0, -2.0)]), Color(LANTERN, 0.95 * _alpha))
	# markers: the feed's few, by strength then distance; overlapping ones fold into one (a count), the strong win
	var eye := cam.global_position
	var shown: Array[Dictionary] = []
	for m: Dictionary in _marks:
		var p: Vector3 = m.pos
		var rel := p - eye
		if Vector2(rel.x, rel.z).length() < 0.5:
			continue
		var kind := String(m.kind)
		var x := _x_for(atan2(rel.x, -rel.z), yaw, true)
		var fd := Feed.fade(m)
		var a := maxf(_edge(x / WIDTH), 0.85 if kind == "goal" else 0.0) * fd * _alpha
		if a <= 0.02:
			continue
		var e := m.duplicate()
		e["x"] = clampf(x, 14.0, WIDTH - 14.0)
		e["a"] = a
		shown.append(e)
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := _rank(String(a.kind))
		var rb := _rank(String(b.kind))
		return ra < rb or (ra == rb and float(a.d) < float(b.d)))
	shown = Feed.fold(shown, 17.0)
	var taken: Array[Vector2] = []                  # x spans already holding a marker
	var labels: Array = []                          # [distance, x, text, alpha]
	var dens: int = HudPrefs.compass_density
	for m: Dictionary in shown:
		var x: float = m.x
		var a: float = m.a
		var kind := String(m.kind)
		var half := 15.0 if kind == "goal" else (9.0 if kind != "beacon" else (11.0 if dens == Feed.FULL else 3.0))
		taken.append(Vector2(x - half, x + half))
		var col: Color = m.col
		col.a = a
		var y := band_y + 1.0
		match kind:
			"goal":
				if not IconArt.draw_mark(self, "mark", String(m.art), Vector2(x, y), 30.0, Color(1, 1, 1, a)):
					_diamond(Vector2(x, y), 8.0, col, true)
				labels.append([float(m.d), x, "%d m" % int(round(float(m.d))), a, true])
			"mark":
				if not IconArt.draw_mark(self, "mark", "beacon", Vector2(x, y), 22.0, Color(0.8, 0.9, 1.0, a)):
					_diamond(Vector2(x, y), 6.5, col, false)
					_diamond(Vector2(x, y), 3.0, col, true)
				labels.append([float(m.d), x, "%d m" % int(round(float(m.d))), a])
			"danger":
				var tri := PackedVector2Array([Vector2(x, y - 8.0), Vector2(x + 7.0, y + 6.0), Vector2(x - 7.0, y + 6.0)])
				draw_colored_polygon(tri, Color(0.05, 0.02, 0.02, a * 0.8))
				draw_colored_polygon(PackedVector2Array([Vector2(x, y - 5.5), Vector2(x + 4.6, y + 4.2), Vector2(x - 4.6, y + 4.2)]), col)
				labels.append([float(m.d), x, "%d m" % int(round(float(m.d))), a])
			"fire":
				var lit := bool(m.get("lit", false))
				var sz := 19.0 if bool(m.get("need", false)) else 14.0
				if not IconArt.draw_mark(self, "mark", "lamp" if lit else "cold", Vector2(x, y), sz, Color(1, 1, 1, a)):
					draw_circle(Vector2(x, y), 3.0, col)
				if bool(m.get("need", false)):
					labels.append([float(m.d), x, "%d m" % int(round(float(m.d))), a])
			"tasker":
				_diamond(Vector2(x, y), 4.5, col, bool(m.get("turnin", false)))
			_:
				if dens == Feed.FULL:
					if not IconArt.draw_mark(self, "mark", "beacon", Vector2(x, y), 20.0, Color(1, 1, 1, a * 0.9)):
						_diamond(Vector2(x, y), 5.5, col, true)
					labels.append([float(m.d), x, "%d m" % int(round(float(m.d))), a])
				else:
					draw_line(Vector2(x, y - 6.0), Vector2(x, y + 6.0), Color(col.r, col.g, col.b, a * 0.55), 2.0)
		if int(m.get("count", 1)) > 1 and kind != "beacon":
			Forge.label(self, _font, Vector2(x + 7.0, y - 12.0), "x%d" % int(m.count), 12, Color(INK.r, INK.g, INK.b, a), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 2)
	# the winds go over the strip last, and give way (fade) to a marker standing on them
	for deg: int in winds:
		var x := _x_for(deg_to_rad(float(deg)), yaw)
		if x < 0.0:
			continue
		var wa := _edge(x / WIDTH) * _alpha
		for t: Vector2 in taken:
			if x > t.x - 6.0 and x < t.y + 6.0:
				wa *= 0.2
		var col := LANTERN if deg == 0 else INK
		col.a = wa
		var ws: String = winds[deg]
		var w := _font.get_string_size(ws, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
		Forge.label(self, _font, Vector2(x - w * 0.5, band_y + 3.0), ws, 20, col, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
	_draw_distances(labels, sr.end.y + 4.0)


## The distance of the one beacon nearest the centre of the strip (the one you are facing), on a small tab hung
## under it at full strength. The others carry no number: four tags at once, half of them faded to nothing at the
## strip's ends, read as noise (docs/CRITIQUE_r38.md, 12).
func _draw_distances(labels: Array, y: float) -> void:
	if labels.is_empty():
		return
	var best: Array = labels[0]
	for l: Array in labels:
		if l.size() > 4:
			best = l                                # the tracked step: its distance is the one that matters
			break
		if absf(float(l[1]) - WIDTH * 0.5) < absf(float(best[1]) - WIDTH * 0.5):
			best = l
	var text: String = best[2]
	var dw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, DIST_PT).x
	var x := clampf(float(best[1]), dw * 0.5 + 8.0, WIDTH - dw * 0.5 - 8.0)
	Forge.tab(self, Rect2(x - dw * 0.5 - 8.0, y, dw + 16.0, DIST_PT + 9.0), _alpha)
	Forge.label(self, _font, Vector2(x - dw * 0.5, y + DIST_PT + 3.0), text, DIST_PT, Color(INK.r, INK.g, INK.b, _alpha), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 2)


## Screen x for a world bearing; off-band bearings return -1 (or are pinned to the edge for markers).
func _x_for(bearing: float, yaw: float, pin := false) -> float:
	var rel := wrapf(bearing - yaw, -PI, PI)
	if absf(rel) > SPAN * 0.5:
		if not pin:
			return -1.0
		rel = signf(rel) * SPAN * 0.5
	return WIDTH * 0.5 + rel / (SPAN * 0.5) * WIDTH * 0.5


func _edge(t: float) -> float:
	return smoothstep(0.0, 0.16, t) * smoothstep(1.0, 0.84, t)


func _diamond(c: Vector2, r: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, 1.5, true)
