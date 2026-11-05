extends RefCounted
## Hexagonal basalt for the Ashen Rift (RealmRift): column bundles (the spindle the Crossing winds
## round, stacks and organ-pipe clusters in the lava), flat-shaded hex prisms with joint notches and
## tilted, chamfered tops. Written into a SurfaceTool so a whole field is one draw; the material is
## the assets agent's RockKit "basalt" (loaded by path) or OssKit's dark rock when it is missing.
## Vertex colour follows rock_kit.gdshader: r = contact AO, g = 1 (no moss), b = 1 - ember region.

const ROCK := "res://core/world/realm/rock_kit.gd"


static func material(style := "basalt") -> Material:
	if ResourceLoader.exists(ROCK):
		var rk := load(ROCK) as GDScript
		if rk != null and rk.can_instantiate():
			var m: Variant = rk.call("material", style)
			if m is Material:
				return m
	return OssKit.mat("dark")


static func rock_kit() -> GDScript:
	if not ResourceLoader.exists(ROCK):
		return null
	var rk := load(ROCK) as GDScript
	return rk if rk != null and rk.can_instantiate() else null


static func new_tool() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Flat-shaded triangle facing `n` (Godot's front faces wind clockwise seen from outside).
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var t: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(n) > 0.0:
		t = [a, c, b]
	for v in t:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(v)


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ca: Color, cb: Color) -> void:
	# a,b bottom (colour ca), c,d top (colour cb)
	var t: Array = [[a, ca], [b, ca], [c, cb], [a, ca], [c, cb], [d, cb]]
	if (b - a).cross(c - a).dot(n) > 0.0:
		t = [[a, ca], [c, cb], [b, ca], [a, ca], [d, cb], [c, cb]]
	for e: Array in t:
		st.set_normal(n)
		st.set_color(e[1])
		st.add_vertex(e[0])


## One hex column from `foot` (sunk 0.6 m) to `top_y`, radius r. `glow` > 0 marks the lowest
## metres as an ember region (the lava's edge).
static func column(st: SurfaceTool, rng: RandomNumberGenerator, foot: Vector3, r: float, top_y: float, glow := 0.0) -> void:
	var h := top_y - foot.y
	if h < 0.2:
		return
	var rot := rng.randf_range(0.0, TAU)
	var lean := Vector3(rng.randf_range(-0.025, 0.025), 1.0, rng.randf_range(-0.025, 0.025)).normalized()
	var radj: Array[float] = []
	for i in 6:
		radj.append(rng.randf_range(0.9, 1.08))
	var rings: Array = [[-0.6, 1.0]]
	var joints := rng.randi_range(1, 3) if h > 3.0 else 0
	var js: Array[float] = []
	for j in joints:
		js.append(rng.randf_range(0.15, 0.9) * h)
	js.sort()
	for jy in js:
		rings.append([jy - 0.05, 1.0])
		rings.append([jy, 0.9])
		rings.append([jy + 0.05, 1.0])
	var top_n := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)).normalized()
	var bev := minf(0.08, r * 0.16)
	var pts: Array = []
	for rr: Array in rings:
		var ring := PackedVector3Array()
		for i in 6:
			var a := rot + TAU * float(i) / 6.0
			ring.append(foot + Vector3(cos(a), 0, sin(a)) * r * radj[i] * float(rr[1]) + lean * float(rr[0]))
		pts.append(ring)
	var top_c := foot + lean * h
	var edge := PackedVector3Array()
	var cham := PackedVector3Array()
	for i in 6:
		var a := rot + TAU * float(i) / 6.0
		var o := Vector3(cos(a), 0, sin(a)) * r * radj[i]
		var dy := -(top_n.x * o.x + top_n.z * o.z) / top_n.y
		edge.append(foot + o + lean * (h + dy - bev))
		cham.append(top_c + o * (1.0 - bev / r * 1.5) + Vector3(0, dy * 0.9, 0))
	pts.append(edge)
	var colr := func(y: float) -> Color:
		var ao := clampf(0.5 + 0.5 * (y - foot.y) / maxf(h, 1.0), 0.5, 1.0)
		var em := 1.0 - (glow * clampf(1.0 - (y - foot.y) / 2.2, 0.0, 1.0) if glow > 0.0 else 0.0)
		return Color(ao, 1.0, em)
	for ri in pts.size() - 1:
		var lo: PackedVector3Array = pts[ri]
		var hi: PackedVector3Array = pts[ri + 1]
		for i in 6:
			var i1 := (i + 1) % 6
			var n := ((lo[i] + lo[i1]) * 0.5 - (foot + lean * (lo[i].y - foot.y))).normalized()
			n = Vector3(n.x, 0, n.z).normalized()
			quad(st, lo[i], lo[i1], hi[i1], hi[i], n, colr.call(lo[i].y), colr.call(hi[i].y))
	for i in 6:
		var i1 := (i + 1) % 6
		var n := ((edge[i] + edge[i1]) * 0.5 - top_c).normalized() + top_n
		quad(st, edge[i], edge[i1], cham[i1], cham[i], n.normalized(), colr.call(edge[i].y), colr.call(cham[i].y))
	var cc := Vector3.ZERO
	for v in cham:
		cc += v
	cc /= 6.0
	for i in 6:
		tri(st, cc, cham[i], cham[(i + 1) % 6], top_n, Color(1, 1, 1))


## A bundle of columns on a hex grid inside `radius` round `foot` (xz centre, y = sunk foot).
## top(d) gives each column's top y from its normalised distance d (0 centre .. 1 rim).
## `keep_out` (Callable(Vector2) -> bool) drops columns standing where they must not.
static func bundle(st: SurfaceTool, rng: RandomNumberGenerator, foot: Vector3, radius: float, col_r: float, top: Callable, glow := 0.0, keep_out := Callable()) -> int:
	var step := col_r * 1.74
	var rings := int(radius / step) + 1
	var n := 0
	for qi in range(-rings, rings + 1):
		for ri in range(-rings, rings + 1):
			var x := step * (float(qi) + float(ri) * 0.5)
			var z := step * float(ri) * 0.866
			var d := Vector2(x, z).length()
			if d > radius - col_r * 0.5:
				continue
			var p := Vector3(foot.x + x, foot.y, foot.z + z)
			if keep_out.is_valid() and bool(keep_out.call(Vector2(p.x, p.z))):
				continue
			var ty: float = top.call(d / maxf(radius, 0.01))
			column(st, rng, p, col_r * rng.randf_range(0.93, 1.05), ty, glow)
			n += 1
	return n


static func commit(st: SurfaceTool, parent: Node3D, n: String, style := "basalt", lods := true) -> MeshInstance3D:
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = MeshChunks.with_lods(mesh) if lods else mesh
	mi.material_override = material(style)
	parent.add_child(mi)
	return mi
