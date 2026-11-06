extends RefCounted
## The small clutter of lived-in and fought-over ground (site_dress.gd places it): crates, barrels, sacks,
## firewood stacks, benches, troughs, buckets, a handcart, straw, fallen leaves, kindling, cracked
## flagstones, rubble. Every prop is one cheap mesh in the shared wood / cloth material (or a RockKit
## or OssKit mesh that exists already), so a zone draws one MultiMesh per kind. Built once, cached.
##   key -> {mesh: Mesh, mat: Material or null (null: the mesh carries its own), shadow: bool}
## Meshes are built with their foot at y = 0 and their middle at the origin in xz. Load by path:
##   const Props := preload("res://core/world/realm/site_props.gd")

const RockKit := preload("res://core/world/realm/rock_kit.gd")

static var _meshes: Dictionary = {}
static var _cloth: StandardMaterial3D
static var _wood_m: StandardMaterial3D


static func release() -> void:
	_meshes.clear()
	_cloth = null
	_wood_m = null


## Plain vertex-coloured cloth / straw / leaf material (two-sided: cards).
static func cloth() -> Material:
	if _cloth == null:
		_cloth = StandardMaterial3D.new()
		_cloth.vertex_color_use_as_albedo = true
		_cloth.roughness = 0.95
		_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _cloth


## A prop by key: "crate", "barrel", "sack", "firewood", "bench", "trough", "bucket", "cart", "log",
## "kindling", "straw", "leaf", "flag", "rubble", "stone", "bone", "skull", "hay".
static func get_prop(key: String) -> Dictionary:
	if _meshes.has(key):
		return _meshes[key]
	var d: Dictionary
	match key:
		"crate": d = _wood(_crate(), true)
		"barrel": d = _wood(_barrel(), true)
		"firewood": d = _wood(_firewood(), true)
		"bench": d = _wood(_bench(), true)
		"trough": d = _wood(_trough(), true)
		"bucket": d = _wood(_bucket(), false)
		"cart": d = _wood(_cart(), true)
		"log": d = _wood(_log(), false)
		"kindling": d = _wood(_kindling(), false)
		"sack": d = {"mesh": _sack(), "mat": cloth(), "shadow": true}
		"hay": d = {"mesh": _hay(), "mat": cloth(), "shadow": true}
		"straw": d = {"mesh": _straw(), "mat": cloth(), "shadow": false}
		"leaf": d = {"mesh": _leaves(), "mat": cloth(), "shadow": false}
		"flag": d = {"mesh": RockKit.slab(3, Vector3(1.05, 0.14, 0.8), "granite", 0.0, false), "mat": null, "shadow": false}
		"flag2": d = {"mesh": RockKit.slab(5, Vector3(0.8, 0.12, 0.62), "mossy", 0.0, false), "mat": null, "shadow": false}
		"rubble": d = {"mesh": RockKit.boulder(6, Vector3(0.42, 0.26, 0.36), "granite"), "mat": null, "shadow": false}
		"rubble2": d = {"mesh": RockKit.boulder(7, Vector3(0.42, 0.26, 0.36), "mossy"), "mat": null, "shadow": false}
		"stone": d = {"mesh": RockKit.boulder(1, Vector3(0.55, 0.34, 0.48), "granite"), "mat": null, "shadow": false}
		"stone2": d = {"mesh": RockKit.boulder(2, Vector3(0.55, 0.34, 0.48), "mossy"), "mat": null, "shadow": false}
		"bone": d = {"mesh": OssKit.bone_mesh(0), "mat": OssKit.mat("bone"), "shadow": false}
		"rib": d = {"mesh": OssKit.bone_mesh(1), "mat": OssKit.mat("bone"), "shadow": false}
		"skull": d = {"mesh": OssKit.skull_mesh(1), "mat": OssKit.mat("bone"), "shadow": false}
		_: d = {}
	_meshes[key] = d
	return d


## The Keg's weathered wood, lifted: out in the open under the night grade the kit's own tint reads black.
static func wood() -> Material:
	if _wood_m == null:
		_wood_m = (OssKit.mat("wood") as StandardMaterial3D).duplicate() as StandardMaterial3D
		_wood_m.albedo_color = Color(2.3, 2.0, 1.7)
	return _wood_m


static func _wood(m: ArrayMesh, shadow: bool) -> Dictionary:
	return {"mesh": m, "mat": wood(), "shadow": shadow}


static func _kit_mesh(k: OssKit) -> ArrayMesh:
	var am := ArrayMesh.new()
	for key: String in k._st:
		var st: SurfaceTool = k._st[key]
		st.commit(am)
	return am


static func _crate() -> ArrayMesh:
	var k := OssKit.new()
	k.box("wood", Vector3(0, 0.3, 0), Vector3(0.62, 0.6, 0.62), Basis.IDENTITY, false, 0.85)
	k.box("wood", Vector3(0, 0.3, 0), Vector3(0.66, 0.08, 0.66), Basis.IDENTITY, false, 0.6)      # the band round the middle
	k.box("wood", Vector3(0, 0.58, 0), Vector3(0.66, 0.06, 0.66), Basis.IDENTITY, false, 0.7)
	return _kit_mesh(k)


static func _barrel() -> ArrayMesh:
	var cm := CreatureMesh.new(11)
	var h := 0.85
	cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, h * 0.5, 0), Vector3(0, h, 0)]), PackedFloat32Array([0.26, 0.31, 0.26]), 10, Color(0.8, 0.66, 0.54), 0.0, 0.0)
	cm.blob(Vector3(0, h, 0), Vector3(0.25, 0.015, 0.25), Basis.IDENTITY, Color(0.66, 0.54, 0.44), 0.0, 0.0, 0.0, 2, 10)
	for hy: float in [0.16, 0.5, 0.84]:
		var r := lerpf(0.27, 0.32, 1.0 - absf(hy - 0.5) * 2.0) + 0.01
		cm.tube(PackedVector3Array([Vector3(0, h * hy - 0.025, 0), Vector3(0, h * hy + 0.025, 0)]), PackedFloat32Array([r, r]), 10, Color(0.3, 0.3, 0.32), 0.0, 0.0)
	return cm.commit()


static func _sack() -> ArrayMesh:
	var cm := CreatureMesh.new(23)
	cm.blob(Vector3(0, 0.15, 0), Vector3(0.3, 0.16, 0.21), Basis(Vector3.UP, 0.3), Color(0.46, 0.37, 0.25), 0.0, 0.2, 0.0, 6, 9)
	cm.blob(Vector3(0.1, 0.3, 0.02), Vector3(0.12, 0.08, 0.1), Basis(Vector3.BACK, -0.4), Color(0.4, 0.32, 0.21), 0.0, 0.25, 0.0, 4, 7)    # the slumped, tied neck
	return cm.commit()


static func _hay() -> ArrayMesh:
	var cm := CreatureMesh.new(31)
	cm.tube(PackedVector3Array([Vector3(-0.4, 0.28, 0), Vector3(0.0, 0.3, 0), Vector3(0.4, 0.28, 0)]), PackedFloat32Array([0.28, 0.3, 0.28]), 8, Color(0.5, 0.4, 0.22), 0.0, 0.1)
	cm.tube(PackedVector3Array([Vector3(-0.34, 0.28, 0), Vector3(-0.3, 0.28, 0)]), PackedFloat32Array([0.305, 0.305]), 8, Color(0.4, 0.32, 0.2), 0.0, 0.0)
	cm.tube(PackedVector3Array([Vector3(0.3, 0.28, 0), Vector3(0.34, 0.28, 0)]), PackedFloat32Array([0.305, 0.305]), 8, Color(0.4, 0.32, 0.2), 0.0, 0.0)
	return cm.commit()


static func _firewood() -> ArrayMesh:
	var cm := CreatureMesh.new(41)
	var rows := [[-0.27, 0.0, 0.0], [0.0, 0.0, 0.0], [0.27, 0.0, 0.0], [-0.135, 0.23, 0.0], [0.135, 0.23, 0.0], [0.0, 0.45, 0.0]]
	for r: Array in rows:
		var col := Color(0.6, 0.46, 0.32).lerp(Color(0.46, 0.34, 0.24), absf(sin(float(r[0]) * 9.0)))
		cm.tube(PackedVector3Array([Vector3(float(r[0]), float(r[1]) + 0.13, -0.42), Vector3(float(r[0]), float(r[1]) + 0.13, 0.42)]), PackedFloat32Array([0.125, 0.125]), 6, col, 0.0, 0.06)
	return cm.commit()


static func _log() -> ArrayMesh:
	var cm := CreatureMesh.new(43)
	cm.tube(PackedVector3Array([Vector3(0, 0.15, -0.6), Vector3(0, 0.16, 0), Vector3(0, 0.15, 0.6)]), PackedFloat32Array([0.15, 0.17, 0.15]), 7, Color(0.5, 0.4, 0.3), 0.0, 0.1)
	return cm.commit()


static func _kindling() -> ArrayMesh:
	var k := OssKit.new()
	for i in 5:
		var a := float(i) * 1.1
		k.box("wood", Vector3(cos(a) * 0.05, 0.02 + 0.025 * (i % 3), sin(a) * 0.05), Vector3(0.45, 0.035, 0.035), Basis(Vector3.UP, a * 2.3), false, 0.8)
	return _kit_mesh(k)


static func _bench() -> ArrayMesh:
	var k := OssKit.new()
	k.box("wood", Vector3(0, 0.44, 0), Vector3(1.5, 0.07, 0.34), Basis.IDENTITY, false, 0.9)
	for sx: float in [-0.6, 0.6]:
		k.box("wood", Vector3(sx, 0.2, 0), Vector3(0.08, 0.4, 0.3), Basis.IDENTITY, false, 0.8)
	return _kit_mesh(k)


static func _trough() -> ArrayMesh:
	var k := OssKit.new()
	k.box("wood", Vector3(0, 0.12, 0), Vector3(1.3, 0.05, 0.45), Basis.IDENTITY, false, 0.8)
	for sz: float in [-0.2, 0.2]:
		k.box("wood", Vector3(0, 0.3, sz), Vector3(1.3, 0.32, 0.05), Basis.IDENTITY, false, 0.85)
	for sx: float in [-0.63, 0.63]:
		k.box("wood", Vector3(sx, 0.3, 0), Vector3(0.05, 0.32, 0.45), Basis.IDENTITY, false, 0.85)
		k.box("wood", Vector3(sx * 0.9, 0.1, 0), Vector3(0.1, 0.2, 0.5), Basis.IDENTITY, false, 0.7)
	return _kit_mesh(k)


static func _bucket() -> ArrayMesh:
	var cm := CreatureMesh.new(47)
	cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.28, 0)]), PackedFloat32Array([0.15, 0.2]), 8, Color(0.62, 0.5, 0.38), 0.0, 0.0)
	cm.tube(PackedVector3Array([Vector3(0, 0.13, 0), Vector3(0, 0.16, 0)]), PackedFloat32Array([0.185, 0.185]), 8, Color(0.3, 0.3, 0.32), 0.0, 0.0)
	return cm.commit()


static func _cart() -> ArrayMesh:
	var k := OssKit.new()
	k.box("wood", Vector3(0, 0.55, 0), Vector3(1.5, 0.08, 0.9), Basis.IDENTITY, false, 0.85)
	for sz: float in [-0.42, 0.42]:
		k.box("wood", Vector3(0, 0.75, sz), Vector3(1.5, 0.32, 0.06), Basis.IDENTITY, false, 0.9)
	k.box("wood", Vector3(-0.72, 0.75, 0), Vector3(0.06, 0.32, 0.9), Basis.IDENTITY, false, 0.9)
	for sz: float in [-0.5, 0.5]:
		k.box("wood", Vector3(0, 0.62, sz), Vector3(0.08, 0.08, 0.14), Basis.IDENTITY, false, 0.6)
	# the shafts lie on the ground (an unharnessed cart)
	k.box("wood", Vector3(1.25, 0.34, -0.3), Vector3(1.2, 0.06, 0.06), Basis(Vector3.BACK, -0.28), false, 0.8)
	k.box("wood", Vector3(1.25, 0.34, 0.3), Vector3(1.2, 0.06, 0.06), Basis(Vector3.BACK, -0.28), false, 0.8)
	var cm := CreatureMesh.new(53)
	for sz: float in [-0.52, 0.52]:
		cm.tube(PackedVector3Array([Vector3(-0.1, 0.36, sz - 0.03), Vector3(-0.1, 0.36, sz + 0.03)]), PackedFloat32Array([0.36, 0.36]), 12, Color(0.5, 0.4, 0.3), 0.0, 0.0)
	var am := _kit_mesh(k)
	var wheels := cm.commit()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wheels.surface_get_arrays(0))
	return am


## A tuft of straw: five thin blades crossed on the ground.
static func _straw() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := float(i) * 1.05
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.012
		var o := Vector3(sin(a * 3.1) * 0.06, 0.012 + 0.006 * i, cos(a * 2.3) * 0.06)
		var col := Color(0.72, 0.6, 0.34).lerp(Color(0.55, 0.45, 0.26), float(i % 3) / 3.0)
		var p: Array[Vector3] = [o - d * 0.24 - side, o + d * 0.24 - side, o + d * 0.24 + side, o - d * 0.24 + side]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.add_vertex(p[idx])
	return st.commit()


## Three dead leaves, flat cards, a little apart.
static func _leaves() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := [Color(0.5, 0.36, 0.2), Color(0.42, 0.3, 0.17), Color(0.58, 0.44, 0.24)]
	for i in 3:
		var a := float(i) * 2.1 + 0.4
		var c := Vector3(cos(a) * 0.14, 0.012 + 0.004 * i, sin(a) * 0.14)
		var d := Vector3(cos(a * 1.7), 0, sin(a * 1.7))
		var s := Vector3(-d.z, 0, d.x)
		var p: Array[Vector3] = [c - d * 0.075, c + s * 0.05, c + d * 0.085, c - s * 0.05]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(cols[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(p[idx])
	return st.commit()
