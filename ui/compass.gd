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
const BRAZIER_R := 110.0                 ## braziers farther than this are not shown
const MAX_BRAZIERS := 4
const LABEL_GAP := 4.0                   ## px kept clear between two distance numbers

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
	offset_bottom = 18.0 + HEIGHT + 18.0
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
	for c in b.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.material_override is StandardMaterial3D:
			var col := (mi.material_override as StandardMaterial3D).albedo_color
			col.a = 1.0
			return col
	return LANTERN


func _draw() -> void:
	if _alpha <= 0.001:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fwd := -cam.global_basis.z
	var yaw := atan2(fwd.x, -fwd.z)                 # 0 = north (-Z), clockwise
	var cx := WIDTH * 0.5
	var band_y := 14.0
	# backing: a dark band that fades out at both ends, hairlines above and below
	var steps := 24
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var a := _edge(lerpf(t0, t1, 0.5)) * 0.42 * _alpha
		draw_rect(Rect2(t0 * WIDTH, band_y - 12.0, (t1 - t0) * WIDTH + 0.5, 26.0), Color(0.035, 0.022, 0.012, a))
		var la := _edge(lerpf(t0, t1, 0.5)) * 0.55 * _alpha
		draw_line(Vector2(t0 * WIDTH, band_y - 12.0), Vector2(t1 * WIDTH, band_y - 12.0), Color(0.62, 0.45, 0.2, la * 0.8), 1.5)
		draw_line(Vector2(t0 * WIDTH, band_y + 14.0), Vector2(t1 * WIDTH, band_y + 14.0), Color(0.62, 0.45, 0.2, la * 0.8), 1.5)
	# ticks and winds
	var winds := {0: "N", 90: "E", 180: "S", 270: "W"}
	for deg in range(0, 360, 15):
		var x := _x_for(deg_to_rad(float(deg)), yaw)
		if x < 0.0:
			continue
		var a := _edge(x / WIDTH) * _alpha
		if winds.has(deg):
			var s: String = winds[deg]
			var col := LANTERN if deg == 0 else INK
			col.a = a
			var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
			draw_string(_font, Vector2(x - w * 0.5, band_y + 6.0), s, HORIZONTAL_ALIGNMENT_CENTER, -1, 17, col)
		else:
			var h := 7.0 if deg % 45 == 0 else 4.0
			draw_line(Vector2(x, band_y - h * 0.5 + 1.0), Vector2(x, band_y + h * 0.5 + 1.0), Color(INK.r, INK.g, INK.b, a * 0.55), 1.0)
	# centre notch
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5.0, band_y - 13.0), Vector2(cx + 5.0, band_y - 13.0), Vector2(cx, band_y - 7.0)]), Color(LANTERN.r, LANTERN.g, LANTERN.b, 0.9 * _alpha))
	# markers
	var eye := cam.global_position
	var labels: Array = []                          # [distance, x, text, alpha]: placed after, nearest first
	for m: Dictionary in _marks:
		var p: Vector3 = m.pos
		var rel := p - eye
		if Vector2(rel.x, rel.z).length() < 0.5:
			continue
		var bearing := atan2(rel.x, -rel.z)
		var x := _x_for(bearing, yaw, true)
		# a beacon behind you stays pinned to the band's end, dimmed, so the way back is never lost
		var a := maxf(_edge(x / WIDTH), 0.5 if String(m.kind) == "beacon" else 0.0) * _alpha
		x = clampf(x, 10.0, WIDTH - 10.0)
		var col: Color = m.col
		col.a = a
		var y := band_y + 1.0
		match String(m.kind):
			"beacon":
				_diamond(Vector2(x, y), 7.0, col, true)
				_diamond(Vector2(x, y), 9.5, Color(0.02, 0.02, 0.04, a * 0.6), false)
				labels.append([rel.length(), x, "%d m" % int(round(rel.length())), a])
			"cold":
				_diamond(Vector2(x, y), 4.5, col, false)
			_:
				draw_circle(Vector2(x, y), 2.6, col)
	_draw_distances(labels, band_y + 33.0)


## r35: beacons a few degrees apart printed their distances over each other ("179283 M"). The nearest
## beacon keeps its number; any other whose number would touch a placed one goes without.
func _draw_distances(labels: Array, y: float) -> void:
	labels.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var taken: Array[Vector2] = []                  # placed spans: x = left, y = right
	for l: Array in labels:
		var x: float = l[1]
		var text: String = l[2]
		var dw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
		var span := Vector2(x - dw * 0.5 - LABEL_GAP, x + dw * 0.5 + LABEL_GAP)
		var free := true
		for t: Vector2 in taken:
			if span.x < t.y and t.x < span.y:
				free = false
				break
		if not free:
			continue
		taken.append(span)
		var pos := Vector2(x - dw * 0.5, y)
		draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, 4, Color(0.0, 0.0, 0.0, float(l[3]) * 0.8))
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color(INK.r, INK.g, INK.b, float(l[3]) * 0.95))


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
