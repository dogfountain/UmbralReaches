extends RefCounted
## Lathed toadstool: stem, annulus, gill blades, cap, optional spots.
## species 0 agaric, 1 wine/flat, 2 tall glow.


static func build(species: int, scale := 1.0, detail := 0, cap_col := Color("#C41E3A")) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 28 if detail > 0 else 20
	var vc: Array = [0]
	var stem: Array
	var cap: Array
	var gill_inner_r := 0.0
	var gill_inner_y := 0.0
	var gill_outer_r := 0.0
	var gill_outer_y := 0.0
	var gill_n := 10
	var spots := false
	if species == 1:
		stem = [
			Vector3(0.04 * scale, -0.07 * scale, 0.0),
			Vector3(0.22 * scale, -0.015 * scale, 0.0),
			Vector3(0.15 * scale, 0.02 * scale, 0.0),
			Vector3(0.16 * scale, 0.05 * scale, 0.0),
			Vector3(0.08 * scale, 0.12 * scale, 0.0),
			Vector3(0.07 * scale, 0.40 * scale, 0.1),
		]
		cap = [
			Vector3(0.42 * scale, 0.39 * scale, 0.9),
			Vector3(0.48 * scale, 0.45 * scale, 0.95),
			Vector3(0.40 * scale, 0.52 * scale, 1.0),
			Vector3(0.22 * scale, 0.56 * scale, 1.0),
			Vector3(0.00 * scale, 0.58 * scale, 1.0),
		]
		gill_inner_r = 0.075 * scale
		gill_inner_y = 0.40 * scale
		gill_outer_r = 0.44 * scale
		gill_outer_y = 0.385 * scale
		gill_n = 22 if detail > 0 else 16
	elif species == 2:
		stem = [
			Vector3(0.03 * scale, -0.05 * scale, 0.0),
			Vector3(0.11 * scale, -0.012 * scale, 0.0),
			Vector3(0.07 * scale, 0.02 * scale, 0.0),
			Vector3(0.055 * scale, 0.14 * scale, 0.0),
			Vector3(0.05 * scale, 0.86 * scale, 0.1),
		]
		cap = [
			Vector3(0.16 * scale, 0.84 * scale, 0.9),
			Vector3(0.22 * scale, 0.91 * scale, 0.95),
			Vector3(0.18 * scale, 1.02 * scale, 1.0),
			Vector3(0.10 * scale, 1.10 * scale, 1.0),
			Vector3(0.00 * scale, 1.14 * scale, 1.0),
		]
		gill_inner_r = 0.055 * scale
		gill_inner_y = 0.86 * scale
		gill_outer_r = 0.20 * scale
		gill_outer_y = 0.845 * scale
		gill_n = 18 if detail > 0 else 14
	else:
		stem = [
			Vector3(0.05 * scale, -0.08 * scale, 0.0),
			Vector3(0.26 * scale, -0.02 * scale, 0.0),
			Vector3(0.18 * scale, 0.02 * scale, 0.0),
			Vector3(0.22 * scale, 0.06 * scale, 0.0),
			Vector3(0.12 * scale, 0.14 * scale, 0.0),
			Vector3(0.09 * scale, 0.30 * scale, 0.0),
			Vector3(0.085 * scale, 0.72 * scale, 0.05),
			Vector3(0.16 * scale, 0.76 * scale, 0.08),
			Vector3(0.085 * scale, 0.80 * scale, 0.1),
			Vector3(0.08 * scale, 0.98 * scale, 0.12),
		]
		cap = [
			Vector3(0.44 * scale, 0.96 * scale, 0.9),
			Vector3(0.52 * scale, 1.02 * scale, 0.95),
			Vector3(0.49 * scale, 1.08 * scale, 0.98),
			Vector3(0.42 * scale, 1.16 * scale, 1.0),
			Vector3(0.24 * scale, 1.26 * scale, 1.0),
			Vector3(0.00 * scale, 1.31 * scale, 1.0),
		]
		gill_inner_r = 0.09 * scale
		gill_inner_y = 0.98 * scale
		gill_outer_r = 0.48 * scale
		gill_outer_y = 0.955 * scale
		gill_n = 18 if detail > 0 else 14
		spots = true
	_lathe(st, stem, segs, Color(0.86, 0.78, 0.62), vc)
	_lathe(st, cap, segs, cap_col, vc)
	_gills(st, gill_inner_r, gill_inner_y, gill_outer_r, gill_outer_y, gill_n, vc)
	if spots:
		var nspots := 12 if detail > 0 else 8
		for k in nspots:
			var az := float(k) * 2.399 + 0.4
			var el := 0.32 + fmod(float(k) * 0.41, 0.5)
			var rr := 0.50 * scale * sin(el) * 0.72
			var yy := 1.03 * scale + 0.27 * scale * cos(el)
			_blob(st, Vector3(cos(az) * rr, yy, sin(az) * rr), (0.075 if detail > 0 else 0.06) * scale, Color(0.96, 0.9, 0.72), vc)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _lathe(st: SurfaceTool, pts: Array, segs: int, col: Color, vert_count: Array) -> void:
	var start: int = vert_count[0]
	var rings := pts.size()
	for r in rings:
		var pr: Vector3 = pts[r]
		for s in segs:
			var a := TAU * float(s) / float(segs)
			st.set_uv(Vector2(float(s) / float(segs), float(r) / maxf(float(rings - 1), 1.0)))
			st.set_uv2(Vector2(pr.z, 0.0))
			st.set_color(col)
			st.add_vertex(Vector3(cos(a) * pr.x, pr.y, sin(a) * pr.x))
	for r in rings - 1:
		for s in segs:
			var a := start + r * segs + s
			var b := start + r * segs + ((s + 1) % segs)
			var c := start + (r + 1) * segs + s
			var d := start + (r + 1) * segs + ((s + 1) % segs)
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	vert_count[0] += rings * segs


static func _gills(st: SurfaceTool, inner_r: float, inner_y: float, outer_r: float, outer_y: float, count: int, vert_count: Array) -> void:
	var start: int = vert_count[0]
	for i in count:
		var a0 := TAU * float(i) / float(count)
		var a1 := a0 + 0.03
		st.set_uv2(Vector2(0.4, 0.0))
		st.set_color(Color(0.78, 0.58, 0.36))
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(Vector3(cos(a0) * inner_r, inner_y, sin(a0) * inner_r))
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(Vector3(cos(a0) * outer_r, outer_y, sin(a0) * outer_r))
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(Vector3(cos(a1) * outer_r, outer_y, sin(a1) * outer_r))
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(Vector3(cos(a1) * inner_r, inner_y, sin(a1) * inner_r))
		var b := start + i * 4
		st.add_index(b)
		st.add_index(b + 1)
		st.add_index(b + 2)
		st.add_index(b)
		st.add_index(b + 2)
		st.add_index(b + 3)
		st.add_index(b)
		st.add_index(b + 2)
		st.add_index(b + 1)
		st.add_index(b)
		st.add_index(b + 3)
		st.add_index(b + 2)
	vert_count[0] += count * 4


static func _blob(st: SurfaceTool, at: Vector3, r: float, col: Color, vert_count: Array) -> void:
	var profile: Array = [
		Vector3(r * 0.2, at.y - r * 0.28, 1.2),
		Vector3(r, at.y, 1.2),
		Vector3(r * 0.25, at.y + r * 0.42, 1.2),
		Vector3(0.0, at.y + r * 0.55, 1.2),
	]
	var start: int = vert_count[0]
	var segs := 6
	var rings := profile.size()
	for ri in rings:
		var pr: Vector3 = profile[ri]
		for s in segs:
			var a := TAU * float(s) / float(segs)
			st.set_uv(Vector2(float(s) / float(segs), float(ri) / 3.0))
			st.set_uv2(Vector2(1.2, 0.0))
			st.set_color(col)
			st.add_vertex(Vector3(at.x + cos(a) * pr.x, pr.y, at.z + sin(a) * pr.x))
	for ri in rings - 1:
		for s in segs:
			var a := start + ri * segs + s
			var b := start + ri * segs + ((s + 1) % segs)
			var c := start + (ri + 1) * segs + s
			var d := start + (ri + 1) * segs + ((s + 1) % segs)
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	vert_count[0] += rings * segs
