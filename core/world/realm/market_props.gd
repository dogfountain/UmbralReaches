extends RefCounted
## The market's furniture (site_dress.gd stands it in the squares and yards that trade): awninged stalls, a stepped
## market cross, a salt heap, a trestle table, a handcart under its load and a stack of goods. Each is one mesh
## with a surface per material (timber and stone from the Ossuary kit, striped cloth and sacks vertex-coloured), foot at
## y = 0, middle at the origin in xz, the front of a stall on +z. Built once by site_props.gd and cached there.
##   const Market := preload("res://core/world/realm/market_props.gd")

const AWNING := [
	[Color(0.95, 0.26, 0.2), Color(1.0, 0.92, 0.72)],        # madder and cream (the cloth material dims them: vertex colours are linear)
	[Color(0.26, 0.4, 0.9), Color(1.0, 0.74, 0.28)],         # indigo and ochre
	[Color(0.3, 0.62, 0.36), Color(1.0, 0.92, 0.74)],        # moss and cream
]
const SALT := Color(0.95, 0.97, 1.0)
const SACK := Color(0.52, 0.42, 0.28)


## A stall: counter, plank back, a sagging striped awning with a scalloped valance, and its wares by variant
## (0 salt and sacks, 1 crates and jars, 2 hanging pots and a barrel).
static func stall(variant: int, wood_mat: Material, cloth_mat: Material) -> ArrayMesh:
	var k := OssKit.new()
	k.keep_lanes = false
	for sx: float in [-1.3, 1.3]:
		k.box("wood", Vector3(sx, 1.05, 0.8), Vector3(0.1, 2.1, 0.1), Basis.IDENTITY, false, 0.8)
		k.box("wood", Vector3(sx, 1.3, -0.8), Vector3(0.1, 2.6, 0.1), Basis.IDENTITY, false, 0.8)
		k.box("wood", Vector3(sx, 2.36, 0.0), Vector3(0.08, 0.08, 1.74), Basis(Vector3.RIGHT, 0.3), false, 0.75)
	k.box("wood", Vector3(0, 0.82, -0.84), Vector3(2.7, 1.45, 0.05), Basis.IDENTITY, false, 0.6)         # the plank back
	k.box("wood", Vector3(0, 0.43, 0.62), Vector3(2.5, 0.86, 0.55), Basis.IDENTITY, false, 0.78)         # the counter
	k.box("wood", Vector3(0, 0.9, 0.62), Vector3(2.66, 0.07, 0.7), Basis.IDENTITY, false, 0.95)
	k.box("wood", Vector3(0, 1.0, -0.2), Vector3(2.4, 0.05, 0.4), Basis.IDENTITY, false, 0.7)             # a shelf along the back
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: Array = AWNING[variant % AWNING.size()]
	_awning(cloth, cols[0], cols[1])
	var cm := CreatureMesh.new(61 + variant)
	match variant:
		0:
			for i in 3:
				_heap(cm, Vector3(-0.8 + 0.8 * float(i), 0.93, 0.62), 0.3 + 0.05 * float(i % 2), 0.3)
			_sack(cm, Vector3(1.0, 0.93, 0.5), 0.3)
			_sack(cm, Vector3(-1.0, 0.0, -0.45), 1.0)
			_sack(cm, Vector3(-0.7, 0.0, -0.55), 0.9)
		1:
			k.box("wood", Vector3(-0.8, 1.06, 0.62), Vector3(0.5, 0.22, 0.4), Basis(Vector3.UP, 0.1), false, 0.85)
			k.box("wood", Vector3(0.0, 1.06, 0.66), Vector3(0.5, 0.22, 0.4), Basis(Vector3.UP, -0.15), false, 0.85)
			for i in 6:
				cm.blob(Vector3(-0.92 + 0.16 * float(i % 3), 1.2, 0.58 + 0.1 * float(i / 3)), Vector3(0.07, 0.06, 0.07), Basis.IDENTITY, Color(0.62, 0.2, 0.14), 0.0, 0.1, 0.0, 3, 6)
			for i in 3:
				var jx := 0.72 + 0.2 * float(i)
				cm.tube(PackedVector3Array([Vector3(jx, 0.93, 0.62), Vector3(jx, 1.18, 0.62)]), PackedFloat32Array([0.07, 0.09]), 7, Color(0.42, 0.3, 0.22), 0.0, 0.06)
			k.box("wood", Vector3(-0.9, 0.3, -0.45), Vector3(0.6, 0.6, 0.6), Basis(Vector3.UP, 0.2), false, 0.8)
		_:
			k.box("wood", Vector3(0, 2.0, -0.4), Vector3(2.5, 0.05, 0.05), Basis.IDENTITY, false, 0.7)       # the pot rail
			for i in 6:
				var px := -1.0 + 0.4 * float(i)
				var py := 1.72 - 0.12 * float(i % 3)
				cm.tube(PackedVector3Array([Vector3(px, 2.0, -0.4), Vector3(px, py + 0.12, -0.4)]), PackedFloat32Array([0.008, 0.008]), 4, Color(0.2, 0.19, 0.18), 0.0, 0.0)
				cm.blob(Vector3(px, py, -0.4), Vector3(0.12, 0.11, 0.12), Basis.IDENTITY, Color(0.34, 0.3, 0.28), 0.0, 0.1, 0.0, 4, 8)
			cm.tube(PackedVector3Array([Vector3(1.0, 0.0, -0.45), Vector3(1.0, 0.45, -0.45), Vector3(1.0, 0.9, -0.45)]), PackedFloat32Array([0.26, 0.31, 0.26]), 9, Color(0.72, 0.58, 0.44), 0.0, 0.0)
			k.box("wood", Vector3(-0.2, 1.02, 0.6), Vector3(0.9, 0.12, 0.4), Basis.IDENTITY, false, 0.85)
	return _mesh(k, wood_mat, null, cloth, cm.commit(), cloth_mat)


## A market cross: three square steps, a pillar and a short-armed head, all in dressed stone.
static func cross(stone_mat: Material) -> ArrayMesh:
	var k := OssKit.new()
	k.keep_lanes = false
	k.box("stone", Vector3(0, 0.12, 0), Vector3(3.2, 0.24, 3.2), Basis.IDENTITY, false, 0.9)
	k.box("stone", Vector3(0, 0.36, 0), Vector3(2.4, 0.24, 2.4), Basis(Vector3.UP, 0.06), false, 0.9)
	k.box("stone", Vector3(0, 0.6, 0), Vector3(1.6, 0.24, 1.6), Basis(Vector3.UP, 0.12), false, 0.9)
	k.box("stone", Vector3(0, 0.9, 0), Vector3(0.8, 0.36, 0.8), Basis(Vector3.UP, 0.12), false, 0.9)
	k.box("stone", Vector3(0, 2.4, 0), Vector3(0.36, 2.6, 0.36), Basis(Vector3.UP, 0.12), false, 0.85)
	k.box("stone", Vector3(0, 3.35, 0), Vector3(1.1, 0.26, 0.3), Basis(Vector3.UP, 0.12), false, 0.9)
	k.box("stone", Vector3(0, 3.55, 0), Vector3(0.28, 0.7, 0.3), Basis(Vector3.UP, 0.12), false, 0.9)
	return _mesh(k, null, stone_mat, null, null, null)


## A heap of salt: a pale cone with a lumpy skin, two small ones leaning on it.
static func saltheap(cloth_mat: Material) -> ArrayMesh:
	var cm := CreatureMesh.new(71)
	_heap(cm, Vector3.ZERO, 0.8, 0.95)
	_heap(cm, Vector3(0.62, 0.0, 0.28), 0.45, 0.5)
	_heap(cm, Vector3(-0.5, 0.0, -0.4), 0.38, 0.42)
	return _mesh(null, null, null, null, cm.commit(), cloth_mat)


## A trestle table with a cloth, jars and loaves.
static func trestle(wood_mat: Material, cloth_mat: Material) -> ArrayMesh:
	var k := OssKit.new()
	k.keep_lanes = false
	k.box("wood", Vector3(0, 0.8, 0), Vector3(1.7, 0.06, 0.75), Basis.IDENTITY, false, 0.9)
	for sx: float in [-0.7, 0.7]:
		k.box("wood", Vector3(sx, 0.4, 0.2), Vector3(0.06, 0.82, 0.06), Basis(Vector3.RIGHT, 0.25), false, 0.75)
		k.box("wood", Vector3(sx, 0.4, -0.2), Vector3(0.06, 0.82, 0.06), Basis(Vector3.RIGHT, -0.25), false, 0.75)
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(cloth, Vector3(-0.8, 0.84, -0.37), Vector3(0.8, 0.84, -0.37), Vector3(0.8, 0.84, 0.37), Vector3(-0.8, 0.84, 0.37), Color(0.62, 0.58, 0.46))
	_quad(cloth, Vector3(-0.2, 0.84, 0.37), Vector3(0.2, 0.84, 0.37), Vector3(0.22, 0.45, 0.42), Vector3(-0.22, 0.45, 0.42), Color(0.56, 0.17, 0.14))
	var cm := CreatureMesh.new(73)
	for i in 3:
		var jx := -0.55 + 0.2 * float(i)
		cm.tube(PackedVector3Array([Vector3(jx, 0.84, -0.1), Vector3(jx, 1.05, -0.1)]), PackedFloat32Array([0.07, 0.09]), 7, Color(0.44, 0.31, 0.22), 0.0, 0.06)
	for i in 3:
		cm.blob(Vector3(0.1 + 0.2 * float(i), 0.9, 0.05 + 0.08 * float(i % 2)), Vector3(0.1, 0.06, 0.07), Basis(Vector3.UP, 0.5 * float(i)), Color(0.66, 0.5, 0.3), 0.0, 0.1, 0.0, 3, 7)
	return _mesh(k, wood_mat, null, cloth, cm.commit(), cloth_mat)


## A stack of goods: crates in a pyramid with sacks leaning on them and a barrel beside.
static func goods(wood_mat: Material, cloth_mat: Material) -> ArrayMesh:
	var k := OssKit.new()
	k.keep_lanes = false
	k.box("wood", Vector3(-0.35, 0.3, 0), Vector3(0.62, 0.6, 0.62), Basis(Vector3.UP, 0.1), false, 0.85)
	k.box("wood", Vector3(0.35, 0.3, 0.05), Vector3(0.62, 0.6, 0.62), Basis(Vector3.UP, -0.12), false, 0.85)
	k.box("wood", Vector3(0.0, 0.9, 0.02), Vector3(0.62, 0.6, 0.62), Basis(Vector3.UP, 0.3), false, 0.8)
	var cm := CreatureMesh.new(79)
	_sack(cm, Vector3(-0.9, 0.0, 0.3), 1.0)
	_sack(cm, Vector3(-0.85, 0.0, -0.3), 0.9)
	_sack(cm, Vector3(0.9, 0.0, -0.4), 1.0)
	cm.tube(PackedVector3Array([Vector3(0.95, 0.0, 0.5), Vector3(0.95, 0.42, 0.5), Vector3(0.95, 0.85, 0.5)]), PackedFloat32Array([0.26, 0.31, 0.26]), 9, Color(0.72, 0.58, 0.44), 0.0, 0.0)
	return _mesh(k, wood_mat, null, null, cm.commit(), cloth_mat)


## Sacks heaped on a handcart's bed (the cart's mesh, from site_props.gd, gets the load as a third surface).
static func load_cart(cart: ArrayMesh, wood_mat: Material, cloth_mat: Material) -> ArrayMesh:
	var cm := CreatureMesh.new(83)
	_sack(cm, Vector3(-0.35, 0.58, 0.15), 1.0)
	_sack(cm, Vector3(0.2, 0.58, -0.15), 1.0)
	_sack(cm, Vector3(-0.1, 0.8, 0.0), 0.9)
	_heap(cm, Vector3(0.4, 0.58, 0.2), 0.25, 0.25)
	cart.surface_set_material(0, wood_mat)
	cart.surface_set_material(1, cloth_mat)
	var sacks := cm.commit()
	cart.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sacks.surface_get_arrays(0))
	cart.surface_set_material(cart.get_surface_count() - 1, cloth_mat)
	return cart


# --- pieces ------------------------------------------------------------------------------------

static func _heap(cm: CreatureMesh, at: Vector3, r: float, h: float) -> void:
	cm.tube(PackedVector3Array([at, at + Vector3(0, h * 0.35, 0), at + Vector3(0, h * 0.72, 0), at + Vector3(0, h, 0)]),
			PackedFloat32Array([r, r * 0.72, r * 0.36, 0.0]), 8, SALT, 0.0, 0.22)


static func _sack(cm: CreatureMesh, at: Vector3, s: float) -> void:
	cm.blob(at + Vector3(0, 0.15 * s, 0), Vector3(0.3, 0.16, 0.21) * s, Basis(Vector3.UP, at.x * 3.0), SACK, 0.0, 0.2, 0.0, 6, 9)
	cm.blob(at + Vector3(0.1 * s, 0.3 * s, 0.02), Vector3(0.12, 0.08, 0.1) * s, Basis(Vector3.BACK, -0.4), SACK * 0.9, 0.0, 0.25, 0.0, 4, 7)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(p)


## The awning: eight stripes over the slope from the back rail to a front edge past the posts, a little sag in the
## middle of each, and a scalloped valance hanging off the front.
static func _awning(st: SurfaceTool, c0: Color, c1: Color) -> void:
	var rear := Vector3(0, 2.63, -0.92)
	var front := Vector3(0, 1.93, 1.4)
	var n := 8
	var x0 := -1.5
	var dx := 3.0 / float(n)
	for i in n:
		var col := c0 if i % 2 == 0 else c1
		var xa := x0 + dx * float(i)
		var xb := xa + dx
		for s in 3:
			var t0 := float(s) / 3.0
			var t1 := float(s + 1) / 3.0
			var p0 := rear.lerp(front, t0) + Vector3(0, -0.11 * sin(PI * t0), 0)
			var p1 := rear.lerp(front, t1) + Vector3(0, -0.11 * sin(PI * t1), 0)
			_quad(st, Vector3(xa, p0.y, p0.z), Vector3(xb, p0.y, p0.z), Vector3(xb, p1.y, p1.z), Vector3(xa, p1.y, p1.z), col)
		var tl := Vector3(xa, front.y, front.z)
		var tr := Vector3(xb, front.y, front.z)
		var bl := Vector3(xa + 0.03, front.y - 0.2, front.z + 0.04)
		var br := Vector3(xb - 0.03, front.y - 0.2, front.z + 0.04)
		var bm := Vector3((xa + xb) * 0.5, front.y - 0.29, front.z + 0.05)
		var nrm := Vector3(0, 0.2, 1.0).normalized()
		for tri: Array in [[tl, tr, br], [tl, br, bm], [tl, bm, bl]]:
			for p: Vector3 in tri:
				st.set_normal(nrm)
				st.set_color(col * 0.92)
				st.add_vertex(p)


## One mesh from a kit's surfaces (`wood` and `stone` keys take wood_mat / stone_mat), an optional cloth SurfaceTool
## and an optional organic mesh (CreatureMesh, its own vertex layout: its own surface).
static func _mesh(k: OssKit, wood_mat: Material, stone_mat: Material, cloth: SurfaceTool, organic: ArrayMesh, cloth_mat: Material) -> ArrayMesh:
	var am := ArrayMesh.new()
	if k != null:
		for key: String in k._st:
			(k._st[key] as SurfaceTool).commit(am)
			am.surface_set_material(am.get_surface_count() - 1, stone_mat if key == "stone" else wood_mat)
	if cloth != null:
		cloth.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, cloth_mat)
	if organic != null:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, organic.surface_get_arrays(0))
		am.surface_set_material(am.get_surface_count() - 1, cloth_mat)
	return am
