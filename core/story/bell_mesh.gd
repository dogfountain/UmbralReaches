extends RefCounted
## A cast bell as a surface of revolution (story; no class_name), for the Founder's bells.
## y = 0 is the hang point under the beam; the crown loop is just below it, the open mouth about 0.85 m
## down. A crown (headstock loop), a shoulder, a waist flaring out to a thick sound-bow, an open mouth with
## a visible lip, and, for the bell that still has it, the iron tongue inside.
## Load by path: const BellMesh := preload("res://core/story/bell_mesh.gd")

const SEGS := 28
## Outer wall, crown to lip: [radius, y, tone]. The tone is the bronze's value there: worn bright on the
## raised bands and the sound-bow where the clapper strikes, green-dark in the hollows.
const OUTER := [
	[0.000, -0.105, 0.78], [0.060, -0.105, 0.78], [0.085, -0.135, 0.8], [0.110, -0.185, 0.8],
	[0.150, -0.225, 0.95], [0.175, -0.250, 0.55], [0.185, -0.330, 0.8], [0.192, -0.430, 0.8],
	[0.205, -0.500, 0.82], [0.226, -0.560, 0.98], [0.232, -0.585, 0.56], [0.262, -0.650, 0.62],
	[0.310, -0.725, 0.8], [0.352, -0.790, 0.82], [0.372, -0.820, 1.0], [0.378, -0.850, 1.02],
]
## The lip: the flat ring the sound-bow ends in, then the inner wall back up to the crown's underside.
const LIP := [[0.378, -0.850, 0.9], [0.312, -0.850, 0.88]]
const INNER := [
	[0.312, -0.850, 0.5], [0.300, -0.790, 0.4], [0.262, -0.700, 0.36], [0.215, -0.600, 0.34],
	[0.165, -0.480, 0.32], [0.130, -0.360, 0.3], [0.100, -0.270, 0.3], [0.000, -0.235, 0.28],
]
## The iron tongue, hung from the crown's underside: shank, then the bulb that strikes the sound-bow.
const TONGUE := [
	[0.000, -0.235, 1.0], [0.014, -0.245, 1.0], [0.016, -0.600, 1.0], [0.034, -0.640, 1.0],
	[0.058, -0.700, 1.0], [0.064, -0.752, 1.0], [0.048, -0.805, 1.0], [0.0, -0.822, 1.0],
]

static var _cache := {}


## The bell (and its tongue when `tongue`). One surface, vertex-coloured; use `material()`.
static func mesh(tongue := true) -> ArrayMesh:
	if _cache.has(tongue):
		return _cache[tongue]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bronze := Color.WHITE
	var iron := Color(0.36, 0.34, 0.36)
	_lathe(st, OUTER, bronze, 1.0, true)
	_lathe(st, LIP, bronze, 1.0, true)
	_lathe(st, INNER, bronze, -1.0, true)
	_ring(st, Vector3(0, -0.035, 0), 0.062, 0.02, _bronze(0.8))         # the crown's hanging loop
	if tongue:
		_lathe(st, TONGUE, iron, 1.0, false)
	var m := st.commit()
	_cache[tongue] = m
	return m


static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
	m.metallic = 0.75
	m.metallic_specular = 0.6
	m.roughness = 0.4
	m.rim_enabled = true                      # reads against a dark wall in moonlight
	m.rim = 0.2
	m.rim_tint = 0.0
	m.resource_name = "bell_bronze"
	return m


## Revolves `pts` ([radius, y, tone]) about +Y. `side` +1: the surface faces away from the axis (outer
## wall, lip); -1: toward it (inner wall). Normals come from the profile's slope; the winding is checked
## against them.
static func _lathe(st: SurfaceTool, pts: Array, col: Color, side: float, cast: bool) -> void:
	var n := pts.size()
	var nrm: Array[Vector2] = []
	for i in n:
		var a: Array = pts[maxi(i - 1, 0)]
		var b: Array = pts[mini(i + 1, n - 1)]
		var t := Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1]))
		if t.length() < 0.0001:
			nrm.append(Vector2(side, 0.0))
			continue
		t = t.normalized()
		# profile runs crown -> lip (down); for the outer wall (-dy, dr) faces out
		nrm.append(Vector2(-t.y, t.x) * side)
	# the lip's two points run outer -> inner (a flat ring): its face is down
	if n == 2 and float((pts[0] as Array)[1]) == float((pts[1] as Array)[1]):
		nrm = [Vector2(0.0, -1.0), Vector2(0.0, -1.0)]
	for s in SEGS:
		var a0 := TAU * float(s) / float(SEGS)
		var a1 := TAU * float(s + 1) / float(SEGS)
		for i in n - 1:
			var p: Array = pts[i]
			var q: Array = pts[i + 1]
			var v00 := _at(p, a0)
			var v01 := _at(p, a1)
			var v10 := _at(q, a0)
			var v11 := _at(q, a1)
			var n00 := _nv(nrm[i], a0)
			var n01 := _nv(nrm[i], a1)
			var n10 := _nv(nrm[i + 1], a0)
			var n11 := _nv(nrm[i + 1], a1)
			var c0 := _bronze(float(p[2])) if cast else col * float(p[2])
			var c1 := _bronze(float(q[2])) if cast else col * float(q[2])
			c0.a = 1.0
			c1.a = 1.0
			_tri(st, [v00, v10, v11], [n00, n10, n11], [c0, c1, c1])
			_tri(st, [v00, v11, v01], [n00, n11, n01], [c0, c1, c0])


## Old cast bronze by tone: green-grey verdigris in the recesses (low), dark bronze body, the metal
## worn bright and warm on the raised bands, the sound-bow and the lip where it is struck (high).
static func _bronze(t: float) -> Color:
	var verd := Color(0.14, 0.34, 0.24)
	var body := Color(0.36, 0.17, 0.06)
	var worn := Color(1.0, 0.7, 0.3)
	if t >= 0.9:
		return body.lerp(worn, clampf((t - 0.88) / 0.1, 0.0, 1.0))
	return verd.lerp(body, clampf((t - 0.5) / 0.3, 0.0, 1.0))


static func _at(p: Array, a: float) -> Vector3:
	return Vector3(sin(a) * float(p[0]), float(p[1]), cos(a) * float(p[0]))


static func _nv(n: Vector2, a: float) -> Vector3:
	return Vector3(sin(a) * n.x, n.y, cos(a) * n.x).normalized()


## A triangle, wound clockwise seen from the side its normals face (Godot's front face).
static func _tri(st: SurfaceTool, v: Array, nr: Array, c: Array) -> void:
	var order := [0, 1, 2]
	var geo := ((v[1] as Vector3) - (v[0] as Vector3)).cross((v[2] as Vector3) - (v[0] as Vector3))
	if geo.length() < 0.000001:
		return
	if geo.dot((nr[0] as Vector3) + (nr[1] as Vector3) + (nr[2] as Vector3)) > 0.0:
		order = [0, 2, 1]
	for k: int in order:
		st.set_color(c[k])
		st.set_normal(nr[k])
		st.add_vertex(v[k])


## A small vertical ring (a torus in the XY plane) for the crown loop.
static func _ring(st: SurfaceTool, at: Vector3, r: float, tube: float, col: Color) -> void:
	var big := 14
	var small := 6
	for i in big:
		for j in small:
			var p: Array[Vector3] = []
			var nn: Array[Vector3] = []
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var u := TAU * float(i + d.x) / float(big)
				var w := TAU * float(j + d.y) / float(small)
				var centre := Vector3(cos(u) * r, sin(u) * r, 0.0)
				var dir := Vector3(cos(u) * cos(w), sin(u) * cos(w), sin(w))
				p.append(at + centre + dir * tube)
				nn.append(dir)
			var cc := Color(col.r, col.g, col.b, 1.0)
			_tri(st, [p[0], p[1], p[2]], [nn[0], nn[1], nn[2]], [cc, cc, cc])
			_tri(st, [p[0], p[2], p[3]], [nn[0], nn[2], nn[3]], [cc, cc, cc])
