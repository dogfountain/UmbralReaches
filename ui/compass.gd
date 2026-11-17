extends Control
## The compass strip (ENS art pass, docs/enshrouded/art.md): a thin engraved band at the top centre
## of the HUD. 180 degrees of heading across it, ticks every 15, the four winds in Cinzel (north in
## lantern gold), and markers for what the night asks of you:
##   - landmark beacons (group "landmark_beacon", realm_wayfinding.gd beacon(), with an `anchor`), as a
##     diamond in the beacon's own colour with the distance under it;
##   - the nearest braziers (Groups.BRAZIER): a hollow ember diamond while cold, a small gold dot lit.
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
const BRAZIER_R := 110.0                 ## braziers farther than this are not shown
const MAX_BRAZIERS := 4
const DIST_PT := 19
const OUTLINE_TRI := Color(0.02, 0.012, 0.006)

var _font: Font
var _scan := 0.0
var _marks: Array[Dictionary] = []       ## {pos: Vector3, col: Color, kind: "beacon"|"cold"|"lit"}
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
	var eye := cam.global_position
	for b in get_tree().get_nodes_in_group(&"landmark_beacon"):     # core/world/realm/landmark_beacon.gd
		if not is_instance_valid(b) or b.is_queued_for_deletion() or not ("anchor" in b):
			continue
		_marks.append({"pos": b.get("anchor"), "col": _beacon_col(b), "kind": "beacon"})
	# the tracked task's step (core/story/quest_track.gd): its own painted mark, first on the strip, its distance always shown
	var tr := get_tree().get_first_node_in_group("quest_track") as QuestTrack
	var st: Dictionary = tr.current() if tr != null else {}
	if st.get("target", Vector3.INF) != Vector3.INF:
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		var tg: Vector3 = st.target
		var flat := Vector2(tg.x - pl.global_position.x, tg.z - pl.global_position.z).length() if pl else -1.0
		_marks.assign(_marks.filter(func(m: Dictionary) -> bool: return String(m.kind) != "beacon" or Vector2((m.pos as Vector3).x - tg.x, (m.pos as Vector3).z - tg.z).length() > 6.0))      # the waypoint is shown once: a beacon on the tracked place is the goal mark itself
		_marks.append({"pos": tg, "col": LANTERN, "kind": "goal", "art": String(st.get("art", "followed")), "flat": flat})
	var braz: Array = []
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		var b3 := n as Node3D
		if b3 == null or not b3.is_inside_tree():
			continue
		var d := b3.global_position.distance_to(eye)
		if d <= BRAZIER_R:
			braz.append([d, b3])
	braz.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(braz.size(), MAX_BRAZIERS):
		var b3: Node3D = braz[i][1]
		var lit := bool(b3.get("lit")) if "lit" in b3 else false
		_marks.append({"pos": b3.global_position, "col": LANTERN if lit else EMBER, "kind": "lit" if lit else "cold"})


func _beacon_col(b: Node) -> Color:
	return b.get("tint") as Color if "tint" in b else LANTERN


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
	# markers: nearest beacons first; one that would sit on a placed marker gives way (a beacon behind you pins to the end, so the rest of them are the same spot)
	var eye := cam.global_position
	var shown: Array[Dictionary] = []
	for m: Dictionary in _marks:
		var p: Vector3 = m.pos
		var rel := p - eye
		if Vector2(rel.x, rel.z).length() < 0.5:
			continue
		var x := _x_for(atan2(rel.x, -rel.z), yaw, true)
		var kind := String(m.kind)
		var a := maxf(_edge(x / WIDTH), (0.85 if kind == "goal" else 0.5) if kind in ["beacon", "goal"] else 0.0) * _alpha
		var dist: float = float(m.flat) if float(m.get("flat", -1.0)) >= 0.0 else rel.length()     # the goal reads as the waypoint does: flat, from the wanderer
		shown.append({"x": clampf(x, 14.0, WIDTH - 14.0), "a": a, "kind": kind, "col": m.col, "d": dist, "art": String(m.get("art", ""))})
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := -1 if a.kind == "goal" else (0 if a.kind == "beacon" else 1)
		var kb := -1 if b.kind == "goal" else (0 if b.kind == "beacon" else 1)
		return ka < kb or (ka == kb and float(a.d) < float(b.d)))
	var taken: Array[Vector2] = []                  # x spans already holding a marker
	var labels: Array = []                          # [distance, x, text, alpha]
	for m: Dictionary in shown:
		var x: float = m.x
		var a: float = m.a
		var half := 15.0 if m.kind == "goal" else (13.0 if m.kind == "beacon" else 8.0)
		var clash := false
		for t: Vector2 in taken:
			if x - half < t.y and t.x < x + half:
				clash = true
				break
		if clash:
			continue
		taken.append(Vector2(x - half, x + half))
		var col: Color = m.col
		col.a = a
		var y := band_y + 1.0
		match String(m.kind):
			"goal":
				if not IconArt.draw_mark(self, "mark", String(m.art), Vector2(x, y), 30.0, Color(1, 1, 1, a)):
					_diamond(Vector2(x, y), 8.0, col, true)
				labels.append([float(m.d), x, "%d m" % int(round(float(m.d))), a, true])
			"beacon":
				if not IconArt.draw_mark(self, "mark", "beacon", Vector2(x, y), 26.0, Color(1, 1, 1, a)):
					_diamond(Vector2(x, y), 7.0, col, true)
					_diamond(Vector2(x, y), 9.5, Color(0.02, 0.02, 0.04, a * 0.6), false)
				labels.append([float(m.d), x, "%d m" % int(round(float(m.d))), a])
			"cold":
				if not IconArt.draw_mark(self, "mark", "cold", Vector2(x, y), 16.0, Color(1, 1, 1, a)):
					_diamond(Vector2(x, y), 4.5, col, false)
			_:
				if not IconArt.draw_mark(self, "mark", "lamp", Vector2(x, y), 15.0, Color(1, 1, 1, a)):
					draw_circle(Vector2(x, y), 2.6, col)
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
