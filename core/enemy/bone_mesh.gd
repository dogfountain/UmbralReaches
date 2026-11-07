extends RefCounted
## A long bone for things that fall or are thrown by the dead (the Bone Abbot's rain): a tapered,
## slightly bowed shaft, a knuckled knob at each end, a crack ring and a chipped splinter, in aged
## ivory that yellows toward the ends. Lit (not a glow), long axis along Z, about 0.62 m.

const IVORY := Color(0.74, 0.68, 0.54)
const YELLOW := Color(0.62, 0.5, 0.3)

static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var half := 0.31
	# the shaft: rings along z, radius waisted in the middle, a gentle bow in x, yellowing to the ends
	var rings := 8
	var prev: Array[Vector3] = []
	var prev_c := Color.WHITE
	for i in rings + 1:
		var t := float(i) / float(rings)
		var z := lerpf(-half, half, t)
		var waist := 1.0 - 0.45 * sin(t * PI)
		var r := 0.05 * waist + 0.012
		var bow := 0.015 * sin(t * PI)
		var col := IVORY.lerp(YELLOW, pow(absf(t - 0.5) * 2.0, 2.0) * 0.7)
		if i == 4:
			col = col.darkened(0.25)                          # a crack ring round the middle
		var ring: Array[Vector3] = []
		for k in sides:
			var a := TAU * float(k) / float(sides)
			ring.append(Vector3(cos(a) * r + bow, sin(a) * r * 0.85, z))
		if i > 0:
			for k in sides:
				var k2 := (k + 1) % sides
				_tri(st, prev[k], ring[k], ring[k2], prev_c, col, col)
				_tri(st, prev[k], ring[k2], prev[k2], prev_c, col, col)
		prev = ring
		prev_c = col
	# the knuckled ends: two lumps each, offset like the head of a bone
	for end: float in [-1.0, 1.0]:
		for lump: float in [-1.0, 1.0]:
			_lump(st, Vector3(lump * 0.034, lump * 0.012, end * (half + 0.028)), 0.052, YELLOW.lerp(IVORY, 0.3))
	# a chipped splinter standing off the shaft
	_lump(st, Vector3(0.05, 0.03, 0.06), 0.022, IVORY.lightened(0.1))
	st.generate_normals()
	_mesh = st.commit()
	return _mesh


static func material() -> StandardMaterial3D:
	if _mat != null:
		return _mat
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.72
	_mat.emission_enabled = true                                # pale enough to read in the dark, never over the glow threshold
	_mat.emission = Color(0.62, 0.55, 0.4)
	_mat.emission_energy_multiplier = 0.45
	_mat.rim_enabled = true
	_mat.rim = 0.5
	_mat.rim_tint = 0.4
	return _mat


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for p: Array in [[a, ca], [b, cb], [c, cc]]:
		st.set_color(p[1])
		st.add_vertex(p[0])


static func _lump(st: SurfaceTool, at: Vector3, r: float, col: Color) -> void:
	var rings := 4
	var seg := 6
	var grid: Array = []
	for i in rings + 1:
		var v := PI * float(i) / float(rings)
		var row: Array[Vector3] = []
		for k in seg:
			var a := TAU * float(k) / float(seg)
			row.append(at + Vector3(cos(a) * sin(v), sin(a) * sin(v) * 0.9, cos(v) * 0.9) * r)
		grid.append(row)
	for i in rings:
		for k in seg:
			var k2 := (k + 1) % seg
			var r0: Array = grid[i]
			var r1: Array = grid[i + 1]
			_tri(st, r0[k], r1[k], r1[k2], col, col, col)
			_tri(st, r0[k], r1[k2], r0[k2], col, col, col)


static func release() -> void:
	_mesh = null
	_mat = null
