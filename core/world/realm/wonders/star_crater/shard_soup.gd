extends RefCounted
## A bag of flat-shaded triangles with a colour each (alpha carries "how far up the crystal": 0 at the root,
## 1 at the tip, which the crystal shader turns into glow), built into one ArrayMesh, with the faces kept so
## the solid ones can take a trimesh body. Crystals are hexagonal prisms with a slanted, faceted termination.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var centre := Vector3.ZERO     ## inside the primitive being added: every face is wound and lit to point away from it


func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		n = -n
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
	verts.append_array([a, b, c])
	norms.append_array([n, n, n])
	cols.append_array([ca, cb, cc])


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	tri(a, b, c, ca, cb, cc)
	tri(a, c, d, ca, cc, cd)


func tri_count() -> int:
	return verts.size() / 3


## One crystal from `root` along unit `dir`, `length` long, `radius` at the root, `sides` faces. `skew` leans the
## upper part sideways (a fraction of the length), `cut` slants the termination. `c_root` / `c_tip` are the
## colours at the ends (alpha is overwritten with the height). `sink` is how much of the root is buried (a
## skirt drawn down into the ground so no gap shows).
func crystal(root: Vector3, dir: Vector3, length: float, radius: float, sides: int, skew: Vector3, cut: float, c_root: Color, c_tip: Color, rng: RandomNumberGenerator, sink := 0.0) -> void:
	dir = dir.normalized()
	var e1 := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var e2 := dir.cross(e1).normalized()
	var rot := rng.randf() * TAU
	var base: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var top: Array[Vector3] = []
	var t_mid := 0.74
	var t_top := 0.92
	var p0 := root - dir * sink
	centre = root + dir * length * 0.4 + skew * length * 0.15
	for i in sides:
		var a := rot + TAU * float(i) / float(sides)
		var rr := radius * rng.randf_range(0.86, 1.14)
		var ring := e1 * cos(a) + e2 * sin(a)
		base.append(p0 + ring * rr * 1.04)
		mid.append(root + dir * length * t_mid + skew * length * 0.4 + ring * rr * 0.9)
		top.append(root + dir * length * t_top + skew * length * 0.85 + ring * rr * 0.62)
	var tip := root + dir * length + skew * length + e1 * cut * radius
	var cb := c_root
	cb.a = 0.0
	var cm := c_root.lerp(c_tip, 0.65)
	cm.a = 0.6
	var ct := c_tip.lerp(Color.WHITE, 0.2)
	ct.a = 0.88
	var cx := c_tip
	cx.a = 1.0
	for i in sides:
		var j := (i + 1) % sides
		quad(base[i], base[j], mid[j], mid[i], cb, cb, cm, cm)
		quad(mid[i], mid[j], top[j], top[i], cm, cm, ct, ct)
		tri(top[i], top[j], tip, ct, ct, cx)


## A flat hexagonal slab (top at `top`, `thick` deep, hex corner radius `r`, turned by `yaw`) with a spike
## hanging beneath it. Returns nothing; the slab's walkable shape is the caller's ConvexPolygonShape3D.
func slab(top: Vector3, r: float, thick: float, yaw: float, spike: float, c_top: Color, c_side: Color, c_spike: Color, rng: RandomNumberGenerator) -> PackedVector3Array:
	centre = top - Vector3(0.0, thick * 0.5, 0.0)
	var up: Array[Vector3] = []
	var lo: Array[Vector3] = []
	var hull := PackedVector3Array()
	for i in 6:
		var a := yaw + TAU * float(i) / 6.0
		var rr := r * rng.randf_range(0.92, 1.08)
		up.append(top + Vector3(cos(a) * rr, 0.0, sin(a) * rr))
		lo.append(top + Vector3(cos(a) * rr * 0.86, -thick, sin(a) * rr * 0.86))
		hull.append(up[i])
		hull.append(lo[i])
	var ct := c_top
	ct.a = 0.45
	var cs := c_side
	cs.a = 0.2
	var cl := c_side
	cl.a = 0.0
	for i in 6:
		var j := (i + 1) % 6
		tri(top, up[i], up[j], ct, ct, ct)
		quad(up[i], lo[i], lo[j], up[j], cs, cl, cl, cs)
	# the spike under it: a six-sided point with a little lean
	var tip := top + Vector3(rng.randf_range(-0.3, 0.3), -thick - spike, rng.randf_range(-0.3, 0.3))
	var cp := c_spike
	cp.a = 0.3
	var cq := c_spike
	cq.a = 1.0
	for i in 6:
		var j := (i + 1) % 6
		tri(lo[i], tip, lo[j], cl, cq, cl)
	hull.append(tip)
	return hull


func build() -> ArrayMesh:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
