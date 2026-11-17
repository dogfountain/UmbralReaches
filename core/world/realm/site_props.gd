extends RefCounted
## The small clutter of lived-in and fought-over ground (site_dress.gd places it): crates, barrels, sacks,
## firewood stacks, benches, troughs, buckets, a handcart, straw, fallen leaves, kindling, cracked
## flagstones, rubble. Every prop is one cheap mesh in the shared wood / cloth material (or a RockKit
## or OssKit mesh that exists already), so a zone draws one MultiMesh per kind. Built once, cached.
##   key -> {mesh: Mesh, mat: Material or null (null: the mesh carries its own), shadow: bool}
## Meshes are built with their foot at y = 0 and their middle at the origin in xz. Load by path:
##   const Props := preload("res://core/world/realm/site_props.gd")

const RockKit := preload("res://core/world/realm/rock_kit.gd")
const Market := preload("res://core/world/realm/market_props.gd")
const Kit := preload("res://core/world/realm/west_marches_kit.gd")
const More := preload("res://core/world/realm/site_props_more.gd")

## Props modelled in Blender (tools/blender/props_square.py, art/models/props/): key -> glb variants. Each glb is
## `<part>__<set>` meshes dressed with the prop-size PBR sets; site_dress draws one MultiMesh per (variant, set).
const GLB := {"crate": ["crate", "crate_broken"], "barrel": ["barrel"], "firewood": ["firewood"], "bench": ["bench"],
	"trough": ["trough"], "cart": ["handcart"], "sack": ["sack", "sack_open"]}

static var _meshes: Dictionary = {}
static var _cloth: StandardMaterial3D
static var _wood_m: StandardMaterial3D


static func release() -> void:
	_meshes.clear()
	_cloth = null
	_wood_m = null
	_water_m = null


## Plain vertex-coloured cloth / straw / leaf material (two-sided: cards).
static func cloth() -> Material:
	if _cloth == null:
		_cloth = StandardMaterial3D.new()
		_cloth.vertex_color_use_as_albedo = true
		_cloth.roughness = 0.95
		_cloth.albedo_color = Color(0.62, 0.62, 0.62)      # vertex colours are linear: the sacks and salt read as white eggs under the moon
		_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _cloth


## A prop by key: "crate", "barrel", "sack", "firewood", "bench", "trough", "bucket", "cart", "log",
## "kindling", "straw", "leaf", "flag", "rubble", "stone", "bone", "skull", "hay"; the market's (market_props.gd):
## "stall", "stall2", "stall3", "cross", "saltheap", "trestle", "goods", "loadcart".
static func get_prop(key: String) -> Dictionary:
	if _meshes.has(key):
		return _meshes[key]
	var d: Dictionary
	if GLB.has(key):
		var vs: Array = []
		for file: String in GLB[key]:
			vs.append(_glb_parts(file))
		if key in More.KINDS:
			vs.append_array(More.extra(key))                  # procedural variants beside the modelled ones (site_props_more.gd)
		d = {"variants": vs, "shadow": true}
		_meshes[key] = d
		return d
	match key:
		"bucket": d = _wood(_bucket(), false)
		"log": d = _wood(_log(), false)
		"kindling": d = _wood(_kindling(), false)
		"stall": d = {"mesh": Market.stall(0, wood(), cloth()), "mat": null, "shadow": true}
		"stall2": d = {"mesh": Market.stall(1, wood(), cloth()), "mat": null, "shadow": true}
		"stall3": d = {"mesh": Market.stall(2, wood(), cloth()), "mat": null, "shadow": true}
		"cross": d = {"mesh": Market.cross(OssKit.mat("stone")), "mat": null, "shadow": true}
		"saltheap": d = {"mesh": Market.saltheap(cloth()), "mat": null, "shadow": true}
		"trestle": d = {"mesh": Market.trestle(wood(), cloth()), "mat": null, "shadow": true}
		"goods": d = {"mesh": Market.goods(wood(), cloth()), "mat": null, "shadow": true}
		"loadcart": d = {"mesh": Market.load_cart(_cart(), wood(), cloth()), "mat": null, "shadow": true}
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


## Which variant of a glb prop the i-th instance of `kind` is (a broken crate now and then, a slumped sack in two).
static func variant(kind: String, i: int, n: int) -> int:
	if n < 2:
		return 0
	if kind == "crate" and n == 2:
		return 1 if i % 4 == 3 else 0
	return (i * 7 + i / 3) % n                       # spread over every variant, not round-robin in a row


## [{mesh, mat}] of a glb under art/models/props/ (cached): for builders that place a modelled prop themselves
## (the tavern's furniture) and draw it as one MultiMesh per entry.
static func parts(file: String) -> Array:
	var key := "glb:" + file
	if not _meshes.has(key):
		_meshes[key] = {"parts": _glb_parts(file)}
	return _meshes[key].parts


## [{mesh, mat}] of a glb under art/models/props/: one per `<part>__<set>` mesh (the -colonly node is no mesh).
static func _glb_parts(file: String) -> Array:
	var out: Array = []
	var ps := Kit.scene("props/%s.glb" % file)
	if ps == null:
		return out
	var root := ps.instantiate()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var parts := String(mi.name).split("__")
		if parts.size() < 2:
			continue
		var set_name := parts[parts.size() - 1].get_slice(".", 0).get_slice("_", 0)
		out.append({"mesh": mi.mesh, "mat": _water() if set_name == "water" else Kit.prop_mat(set_name)})
	root.free()
	return out


static var _water_m: StandardMaterial3D


## The trough's water: dark and glossy (the game has no still-water material that fits a trough-sized pool).
static func _water() -> Material:
	if _water_m == null:
		_water_m = StandardMaterial3D.new()
		_water_m.vertex_color_use_as_albedo = true
		_water_m.albedo_color = Color(0.5, 0.6, 0.65)
		_water_m.roughness = 0.08
		_water_m.metallic_specular = 0.9
	return _water_m


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


static func _hay() -> ArrayMesh:
	var cm := CreatureMesh.new(31)
	cm.tube(PackedVector3Array([Vector3(-0.4, 0.28, 0), Vector3(0.0, 0.3, 0), Vector3(0.4, 0.28, 0)]), PackedFloat32Array([0.28, 0.3, 0.28]), 8, Color(0.5, 0.4, 0.22), 0.0, 0.1)
	cm.tube(PackedVector3Array([Vector3(-0.34, 0.28, 0), Vector3(-0.3, 0.28, 0)]), PackedFloat32Array([0.305, 0.305]), 8, Color(0.4, 0.32, 0.2), 0.0, 0.0)
	cm.tube(PackedVector3Array([Vector3(0.3, 0.28, 0), Vector3(0.34, 0.28, 0)]), PackedFloat32Array([0.305, 0.305]), 8, Color(0.4, 0.32, 0.2), 0.0, 0.0)
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
