extends RefCounted
## The market's furniture (site_dress.gd stands it in the squares and yards that trade): a trestle table, a handcart under its
## load and a stack of goods (the stalls, the cross and the salt heap are modelled: props_market.py, signature_props.py).
## Each is one mesh with a surface per material (timber and stone from the Ossuary kit, cloth and sacks vertex-coloured),
## foot at y = 0, middle at the origin in xz. Built once by site_props.gd and cached there.
##   const Market := preload("res://core/world/realm/market_props.gd")

const SALT := Color(0.95, 0.97, 1.0)
const SACK := Color(0.52, 0.42, 0.28)


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


## The crates of a stack of goods: where each stands (x, y of its foot, z) and its turn. site_props.gd puts the modelled
## crate there (plain boxes read as black cubes at night).
const GOODS_CRATES := [[Vector3(-0.35, 0.0, 0.0), 0.1], [Vector3(0.35, 0.0, 0.05), -0.12], [Vector3(0.0, 0.6, 0.02), 0.3]]
const GOODS_CRATE := 0.62                ## a crate's width in the stack (m)


## A stack of goods' sacks leaning on the crates and the barrel beside (the crates: GOODS_CRATES).
static func goods(wood_mat: Material, cloth_mat: Material) -> ArrayMesh:
	var k: OssKit = null
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
