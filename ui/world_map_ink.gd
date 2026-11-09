extends Control
## The ink layer of the world map: relief, woods, ways, the wall, houses, landmarks and lettering,
## drawn once from the data the map's worker thread gathered (ui/world_map.gd).

var data: Dictionary
var cinzel: Font
var serif: Font
const K := 2.6
const O := Vector2(-310.0, -214.0)
const INK := Color(0.19, 0.12, 0.075)
const PAPER := Color(0.88, 0.8, 0.62)
const LEAF := Color(0.40, 0.50, 0.26, 0.85)
const HALO := Color(0.93, 0.86, 0.68, 0.95)

func _w(p: Vector2) -> Vector2:
	return (p - O) * K

func _hash(x: float, z: float) -> float:
	return fposmod(sin(x * 127.1 + z * 311.7) * 43758.5453, 1.0)

func _draw() -> void:
	for h: Vector3 in data.hills:
		_hill(_w(Vector2(h.x, h.y)), h.z)
	for m: Vector3 in data.peaks:
		_mountain(_w(Vector2(m.x, m.y)), m.z, _hash(m.x, m.y))
	for t: Vector3 in data.trees:
		_tree(_w(Vector2(t.x, t.y)), t.z * K)
	for q: Vector2 in data.dead:
		_stump(_w(q))
	for t: Vector3 in data.tufts:
		_tuft(_w(Vector2(t.x, t.y)), int(t.z), _hash(t.x, t.y))
	_ways()
	_wall()
	_places()
	_letters()

# -- relief

func _mountain(base: Vector2, h: float, r: float) -> void:
	var s := clampf((h - 8.0) * 0.5 + 6.0, 6.0, 15.0) * K
	var hw := s * 0.92
	var jx := (r - 0.5) * hw * 0.6
	var a := base + Vector2(jx, -s)
	var l := base + Vector2(-hw, 0.0)
	var rt := base + Vector2(hw, 0.0)
	var ls := base + Vector2(-hw * 0.5 + jx * 0.4, -s * (0.52 + r * 0.1))
	var rs := base + Vector2(hw * 0.38 + jx * 0.3, -s * 0.48)
	draw_colored_polygon(PackedVector2Array([l, ls, a, rs, rt]), Color(0.84, 0.76, 0.58))
	draw_colored_polygon(PackedVector2Array([a, rs, rt, base + Vector2(jx * 0.3, 0.0)]), Color(0.45, 0.37, 0.27, 0.34))
	draw_polyline(PackedVector2Array([l, ls, a, rs, rt]), INK, 1.6, true)
	for i in 6:
		var t := 0.12 + 0.15 * i
		var p0 := a.lerp(rs, minf(t * 2.0, 1.0)) if t < 0.5 else rs.lerp(rt, (t - 0.5) * 2.0)
		var len := s * (0.55 - t * 0.45)
		draw_line(p0 + Vector2(-1.5, 3.0), p0 + Vector2(-hw * 0.14, len), Color(INK, 0.8), 1.2, true)
	draw_line(a + Vector2(-hw * 0.12, s * 0.2), a + Vector2(-hw * 0.2, s * 0.5), Color(INK, 0.55), 1.1, true)

func _hill(base: Vector2, h: float) -> void:
	var w := clampf(h * 0.9, 8.0, 14.0) * K
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(base + Vector2(lerpf(-w, w, t), -sin(t * PI) * w * 0.34))
	var poly := pts.duplicate()
	poly.append(base + Vector2(w, 0))
	poly.append(base + Vector2(-w, 0))
	draw_colored_polygon(poly, Color(0.84, 0.76, 0.58, 0.8))
	draw_polyline(pts, INK, 1.4, true)
	for i in 3:
		var x := lerpf(0.15, 0.55, i / 2.0) * w
		draw_line(base + Vector2(x, -w * 0.18), base + Vector2(x + 2.0, -w * 0.02), Color(INK, 0.7), 1.0, true)

func _tree(p: Vector2, r: float) -> void:
	draw_line(p + Vector2(0, r * 0.2), p + Vector2(0, r * 1.2), INK, 1.3, true)
	var c := p - Vector2(0, r * 0.35)
	draw_circle(c, r, LEAF)
	draw_arc(c, r, PI * 0.78, PI * 2.22, 16, INK, 1.3, true)
	draw_arc(c + Vector2(r * 0.15, r * 0.1), r * 0.55, PI * 0.1, PI * 0.9, 8, Color(INK, 0.5), 1.0, true)

func _stump(p: Vector2) -> void:
	draw_line(p, p + Vector2(0, -7), INK, 1.6, true)
	draw_line(p + Vector2(0, -4), p + Vector2(-3, -8), INK, 1.2, true)
	draw_line(p + Vector2(0, -5), p + Vector2(3, -9), INK, 1.2, true)

func _tuft(p: Vector2, kind: int, r: float) -> void:
	var col := Color(INK, 0.55)
	match kind:
		0, 3:
			draw_line(p, p + Vector2(-2.6, -4.6), col, 1.1, true)
			draw_line(p, p + Vector2(0.2, -5.4), col, 1.1, true)
			draw_line(p, p + Vector2(2.8, -4.4), col, 1.1, true)
		1:
			for dx in [-3.0, 0.0, 3.0]:
				draw_line(p + Vector2(dx, 0), p + Vector2(dx + r - 0.5, -7.0), Color(0.22, 0.3, 0.2, 0.75), 1.1, true)
			draw_line(p + Vector2(-5, 1), p + Vector2(5, 1), col, 1.0, true)
		2:
			draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), col, 1.1, true)
			draw_line(p + Vector2(2, -2), p + Vector2(-2, 2), col, 1.1, true)

# -- ways and the wall

func _dashed(pts: PackedVector2Array, dash: float, gap: float, width: float, col: Color) -> void:
	var on := true
	var remain := dash
	for i in pts.size() - 1:
		var a := pts[i]
		var seg := a.distance_to(pts[i + 1])
		if seg < 0.01:
			continue
		var dir := (pts[i + 1] - a) / seg
		var t := 0.0
		while t < seg:
			var st := minf(remain, seg - t)
			if on:
				draw_line(a + dir * t, a + dir * (t + st), col, width, true)
			t += st
			remain -= st
			if remain <= 0.001:
				on = not on
				remain = dash if on else gap

func _ways() -> void:
	for path: Dictionary in RealmLayout.PATHS:
		var pts := PackedVector2Array()
		for q: Vector2 in path.pts:
			pts.append(_w(q))
		if String(path.id) == "road":
			_dashed(pts, 11.0, 5.5, 3.2, Color(INK, 0.92))
		else:
			_dashed(pts, 2.2, 6.0, 3.0, Color(INK, 0.85))

func _wall() -> void:
	var gates: Array = RealmLayout.MARCH_GATES
	for sx in [-1, 1]:
		var src: Array = RealmMarch.WALL_WEST if sx < 0 else RealmMarch.WALL_EAST
		var gz: float = (gates[0] as Vector2).y
		var ruin_z0 := 1.0e9
		var ruin_z1 := -1.0e9
		for rn: Array in RealmMarch.RUINS:
			if int(rn[0]) == sx:
				ruin_z0 = float(rn[1])
				ruin_z1 = float(rn[2])
		var run := PackedVector2Array()
		var runs: Array[PackedVector2Array] = []
		var z := -112.0
		while z <= 242.0:
			var open := absf(z - gz) < 6.0 or (z > ruin_z0 and z < ruin_z1)
			if open:
				if run.size() > 1:
					runs.append(run)
				run = PackedVector2Array()
			else:
				run.append(_w(Vector2(RealmMarch.wall_x(sx, z), z)))
			z += 4.0
		if run.size() > 1:
			runs.append(run)
		for r: PackedVector2Array in runs:
			draw_polyline(r, Color(0.84, 0.76, 0.58, 0.9), 7.0, true)
			var off := PackedVector2Array()
			var off2 := PackedVector2Array()
			for q: Vector2 in r:
				off.append(q + Vector2(-3.5, 0))
				off2.append(q + Vector2(3.5, 0))
			draw_polyline(off, INK, 1.8, true)
			draw_polyline(off2, INK, 1.8, true)
		for sp: Dictionary in RealmMarch.SPURS:
			if int(sp.side) == sx:
				draw_line(_w(sp.base), _w(sp.tip), INK, 3.0, true)
				draw_rect(Rect2(_w(sp.tip) - Vector2(3, 3), Vector2(6, 6)), INK)
		for e: float in [gz - 6.0, gz + 6.0]:
			var g := _w(Vector2(RealmMarch.wall_x(sx, e), e))
			draw_rect(Rect2(g.x - 6.0, g.y - 6.0, 12.0, 12.0), PAPER)
			draw_rect(Rect2(g.x - 6.0, g.y - 6.0, 12.0, 12.0), INK, false, 2.0)

# -- settlements and landmarks

func _house(p: Vector2, ang: float, s := 1.0) -> void:
	var hw := 3.2 * K * s
	var hh := 2.3 * K * s
	var pts := PackedVector2Array()
	for q: Vector2 in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
		pts.append(p + q.rotated(ang))
	draw_colored_polygon(pts, Color(0.92, 0.84, 0.68))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), INK, 1.7, true)
	draw_line(p + Vector2(-hw, 0).rotated(ang), p + Vector2(hw, 0).rotated(ang), INK, 1.4, true)
	draw_rect(Rect2(p + Vector2(hw * 0.45, -hh - 3.0 * s).rotated(ang), Vector2(3.0, 4.0) * s), INK)

func _tower(p: Vector2, s := 1.0) -> void:
	var w := 4.0 * s
	var h := 15.0 * s
	draw_rect(Rect2(p.x - w, p.y - h, w * 2.0, h), Color(0.92, 0.84, 0.68))
	draw_rect(Rect2(p.x - w, p.y - h, w * 2.0, h), INK, false, 1.8)
	for i in 3:
		draw_rect(Rect2(p.x - w + i * w * 0.8, p.y - h - 3.0 * s, w * 0.5, 3.5 * s), INK)
	draw_rect(Rect2(p.x - 1.0, p.y - h * 0.6, 2.0, 4.0 * s), INK)

func _cross(p: Vector2, s := 1.0) -> void:
	draw_line(p + Vector2(0, -4) * s, p + Vector2(0, 4) * s, INK, 1.4, true)
	draw_line(p + Vector2(-2.5, -1.5) * s, p + Vector2(2.5, -1.5) * s, INK, 1.4, true)

func _ruin(p: Vector2, s := 1.0) -> void:
	var w := 6.0 * K * s
	var h := 3.4 * K * s
	draw_polyline(PackedVector2Array([p + Vector2(-w, h), p + Vector2(-w, -h), p + Vector2(-w * 0.2, -h)]), INK, 1.8, true)
	draw_polyline(PackedVector2Array([p + Vector2(w * 0.4, -h), p + Vector2(w, -h), p + Vector2(w, h), p + Vector2(w * 0.2, h)]), INK, 1.8, true)
	draw_line(p + Vector2(-w, h), p + Vector2(-w * 0.5, h), INK, 1.8, true)
	_cross(p + Vector2(0, -h - 5.0), s)

func _places() -> void:
	var hs: PackedVector3Array = data.houses
	for h in hs:
		_house(_w(Vector2(h.x, h.y)), h.z)
	# the Kindled Keg is the largest house in Hearthward
	var tv := RealmLayout.TAVERN
	_house(_w(tv.get_center()), 0.0, 1.9)
	for m in data.mounds as PackedVector2Array:
		var p := _w(m)
		draw_arc(p, 5.0 * K * 0.5, PI, TAU, 10, INK, 1.6, true)
		draw_line(p + Vector2(-6.5, 0), p + Vector2(6.5, 0), INK, 1.2, true)
	_ruin(_w(RealmLayout.CHAPEL_C))
	# the henge: a ring of standing stones round the altar
	var hc := _w(RealmLayout.HENGE_C)
	for k in 9:
		var q := hc + Vector2.from_angle(TAU * k / 9.0) * 9.0 * K
		draw_rect(Rect2(q.x - 2.0, q.y - 5.0, 4.0, 8.0), INK)
	draw_circle(hc, 3.0, Color(INK, 0.8))
	# the spire, the keep on the summit, the oak, the well, the furnace
	_tower(_w(RealmLayout.SPIRE_C), 1.3)
	_tower(_w(Vector2(0.0, -104.0)), 1.9)
	var oak := _w(Vector2(-70.0, 206.0))
	for k in 5:
		var lobe := oak + Vector2.from_angle(TAU * k / 5.0) * 7.0 * K
		draw_circle(lobe, 5.5 * K, LEAF)
		draw_arc(lobe, 5.5 * K, 0.0, TAU, 18, Color(INK, 0.9), 1.6, true)
	draw_circle(oak, 6.0 * K, LEAF)
	draw_arc(oak, 6.0 * K, 0.0, TAU, 18, INK, 1.8, true)
	draw_line(oak + Vector2(0, 6.0 * K), oak + Vector2(0, 11.0 * K), INK, 3.0, true)
	var wc := _w(RealmLayout.WELL_C)
	draw_arc(wc, RealmLayout.WELL_R * K, 0.0, TAU, 48, Color(INK, 0.85), 1.6, true)
	draw_arc(wc, (RealmLayout.WELL_R + 3.0) * K, 0.0, TAU, 48, Color(INK, 0.4), 1.0, true)
	var fc := _w(Vector2(135.0, -105.0))
	draw_rect(Rect2(fc.x - 12, fc.y - 7, 24, 14), Color(0.92, 0.84, 0.68))
	draw_rect(Rect2(fc.x - 12, fc.y - 7, 24, 14), INK, false, 1.8)
	draw_rect(Rect2(fc.x + 4, fc.y - 20, 5, 14), INK)
	draw_arc(fc + Vector2(8, -24), 4.0, PI * 0.8, PI * 2.2, 8, Color(INK, 0.5), 1.2, true)
	# the Waiting Field: ranks of crosses, and the mausoleum at its head
	for ix in 5:
		for iz in 3:
			_cross(_w(Vector2(-26.0 + ix * 7.0, 114.0 + iz * 7.0)), 0.9)
	_ruin(_w(Vector2(0.0, 147.0)), 0.7)
	# the quarry's terraces
	var qc := _w(Vector2(-128.0, -84.0))
	for k in 4:
		draw_arc(qc, (7.0 + k * 5.0) * K, PI * 0.12, PI * 0.88, 16, Color(INK, 0.85), 1.5, true)
	# the Fallen Hierarch, face up in his valley
	var hp := PackedVector2Array()
	for q: Vector2 in [Vector2(-249, -100), Vector2(-236, -108), Vector2(-212, -106), Vector2(-190, -112), Vector2(-184, -104),
			Vector2(-206, -97), Vector2(-232, -92), Vector2(-246, -92)]:
		hp.append(_w(q))
	draw_colored_polygon(hp, Color(0.78, 0.7, 0.54, 0.9))
	hp.append(hp[0])
	draw_polyline(hp, INK, 1.8, true)
	draw_circle(_w(Vector2(-251, -96)), 5.5 * K * 0.6, Color(0.78, 0.7, 0.54))
	draw_arc(_w(Vector2(-251, -96)), 5.5 * K * 0.6, 0.0, TAU, 14, INK, 1.6, true)
	# the siege lines: two rings of earthwork, a tower
	var sc := _w(Vector2(-218.0, 160.0))
	for rr: float in [16.0, 25.0]:
		_dashed_arc(sc, rr * K, 4.0, 4.0)
	_tower(_w(Vector2(-236.0, 170.0)), 1.0)
	# the salt pans (evaporation beds: a pale wash, ruled) and a derrick beside them
	for ix in 3:
		for iz in 2:
			var pr := Rect2(_w(Vector2(212.0 + ix * 14.0, 156.0 + iz * 11.0)), Vector2(11.0, 8.0) * K * 0.9)
			draw_rect(pr, Color(0.86, 0.82, 0.68, 0.4))
			for ry in 3:
				var yy := pr.position.y + pr.size.y * (ry + 1) / 4.0
				draw_line(Vector2(pr.position.x + 2.0, yy), Vector2(pr.end.x - 2.0, yy), Color(INK, 0.4), 1.0)
			draw_rect(pr, Color(INK, 0.9), false, 1.6)
	var dp := _w(Vector2(254.0, 148.0))
	draw_polyline(PackedVector2Array([dp + Vector2(-6, 9), dp + Vector2(0, -12), dp + Vector2(6, 9)]), INK, 1.6, true)
	draw_line(dp + Vector2(-3, 0), dp + Vector2(3, 0), INK, 1.2, true)
	# the Anchorites' cells in the cliff face
	for k in 6:
		var cp := _w(Vector2(202.0 + (k % 3) * 9.0, -142.0 + (k / 3) * 12.0))
		draw_rect(Rect2(cp.x - 3, cp.y - 2, 6, 8), INK)
		draw_arc(cp + Vector2(0, -2), 3.0, PI, TAU, 6, INK, 1.4, true)

func _dashed_arc(c: Vector2, r: float, dash_deg: float, gap_deg: float) -> void:
	var a := 0.0
	while a < 360.0:
		draw_arc(c, r, deg_to_rad(a), deg_to_rad(a + dash_deg * 2.0), 4, Color(INK, 0.85), 1.6, true)
		a += (dash_deg + gap_deg) * 2.0

# -- lettering

func _width(font: Font, s: String, size: int, spacing: float) -> float:
	var w := 0.0
	for ch in s:
		w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	return w - spacing

func _letter(font: Font, s: String, c: Vector2, size: int, col: Color, spacing: float) -> void:
	var x := c.x - _width(font, s, size, spacing) * 0.5
	for ch in s:
		var p := Vector2(x, c.y + size * 0.35)
		draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 9, HALO)
		draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		draw_string(font, p + Vector2(0.9, 0.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing

## Region names are lettered live by ui/world_map_labels.gd; only the marginal ones are inked here.
func _letters() -> void:
	# a few marginal names in the book hand
	_along(Vector2(-231.0, 97.0), Vector2(-224.0, 87.0), "the Sorrow")
	_along(Vector2(-155.0, 170.0), Vector2(-155.0, 120.0), "the March Wall")
	_along(Vector2(155.0, 190.0), Vector2(155.0, 140.0), "the March Wall")

func _along(a: Vector2, b: Vector2, text: String) -> void:
	var d := b - a
	var ang := d.angle()
	if absf(ang) > PI * 0.5:
		ang += PI
	var ctr := _w((a + b) * 0.5)
	draw_set_transform(ctr, ang, Vector2.ONE)
	_letter(serif, text, Vector2.ZERO, 34, Color(0.1, 0.055, 0.03), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
