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
## The market's stalls and cross are the square's own models too (props_market.py: the yards' were still kit boxes, the map
## audit's F28; 19 Nov), and the salt heap is modelled (signature_props.py).
const GLB := {"crate": ["crate", "crate_broken"], "barrel": ["barrel"], "firewood": ["firewood"], "bench": ["bench"],
	"trough": ["trough"], "cart": ["handcart"], "sack": ["sack", "sack_open"], "stall": ["market_stall_a"],
	"stall2": ["market_stall_b"], "stall3": ["market_stall_c"], "cross": ["market_cross"], "saltheap": ["sig_saltheap"]}

static var _meshes: Dictionary = {}
static var _cloth: StandardMaterial3D
static var _wood_m: StandardMaterial3D


static func release() -> void:
	_meshes.clear()
	_cloth = null
	_wood_m = null
	_water_m = null
	_prop_wood_m = null


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
		"trestle": d = {"mesh": Market.trestle(wood(), cloth()), "mat": null, "shadow": true}
		"goods": d = {"mesh": _goods(), "mat": null, "shadow": true}
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


## How many variants of `kind` one zone draws (the modelled ones plus one): the pool is bigger than that, and each zone takes a
## window of it (site_dress.gd), so the draw calls per zone stay what they were while the yards differ from each other. 0 = all.
static func window(kind: String) -> int:
	return (GLB[kind] as Array).size() + 1 if GLB.has(kind) and kind in More.KINDS else 0


## Which variant of a glb prop the i-th instance of `kind` is (a broken crate now and then, a slumped sack in two).
static func variant(kind: String, i: int, n: int) -> int:
	if n < 2:
		return 0
	if kind == "crate" and n == 2:
		return 1 if i % 4 == 3 else 0
	return (i * 7 + i / 3) % n                       # spread over every variant, not round-robin in a row


## The market's stack of goods: the modelled crate three times in a pyramid (market_props.gd GOODS_CRATES), then the
## sacks and the barrel. One surface per crate part, so the stack draws as before.
static func _goods() -> ArrayMesh:
	var am := Market.goods(wood(), cloth())
	var ps := parts("crate")
	if ps.is_empty():
		return am
	var box := AABB()
	for i in ps.size():
		var b: AABB = (ps[i].mesh as Mesh).get_aabb()
		box = b if i == 0 else box.merge(b)
	var sc := Market.GOODS_CRATE / maxf(0.01, maxf(box.size.x, box.size.z))
	var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var xfs: Array[Transform3D] = []
	for c: Array in Market.GOODS_CRATES:
		var b3 := Basis(Vector3.UP, float(c[1])).scaled(Vector3(sc, sc, sc))
		xfs.append(Transform3D(b3, c[0] as Vector3) * Transform3D(Basis.IDENTITY, -foot))
	for pd: Dictionary in ps:
		var m: Mesh = pd.mesh
		for si in m.get_surface_count():
			var st := SurfaceTool.new()
			for xf in xfs:
				st.append_from(m, si, xf)
			st.commit(am)
			var mat: Material = pd.mat if pd.mat != null else m.surface_get_material(si)
			am.surface_set_material(am.get_surface_count() - 1, mat)
	return am


## [{mesh, mat}] of a glb under art/models/props/ (cached): for builders that place a modelled prop themselves
## (the tavern's furniture) and draw it as one MultiMesh per entry.
static func parts(file: String) -> Array:
	var key := "glb:" + file
	if not _meshes.has(key):
		_meshes[key] = {"parts": _glb_parts(file, true)}
	return _meshes[key].parts


## The same parts with the kit's own timber (no outdoor lift): for a room that candles light (the tavern's furniture).
static func parts_indoor(file: String) -> Array:
	var key := "glb_in:" + file
	if not _meshes.has(key):
		_meshes[key] = {"parts": _glb_parts(file, false)}
	return _meshes[key].parts


## [{mesh, mat}] of a glb under art/models/props/: one per `<part>__<set>` mesh (the -colonly node is no mesh).
static func _glb_parts(file: String, lift := true) -> Array:
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
		out.append({"mesh": mi.mesh, "mat": _water() if set_name == "water" else (_prop_wood() if lift and set_name == "timber" else Kit.prop_mat(set_name))})
	root.free()
	return out


static var _water_m: StandardMaterial3D
static var _prop_wood_m: StandardMaterial3D


## The modelled props' timber (crates, barrels, benches): the kit's prop wood, lifted. Its texture is a night value (a mean of about 0.1)
## under baked vertex tone of 0.2 and less, so a modelled crate or barrel stood black even in a lamp's light at Saltmarket's doors (the
## polish pass, 20 Nov); the procedural props beside them already carry wood()'s 2.3 lift.
static func _prop_wood() -> StandardMaterial3D:
	if _prop_wood_m == null:
		_prop_wood_m = Kit.prop_mat("timber").duplicate() as StandardMaterial3D
		_prop_wood_m.albedo_color = Color(2.3, 2.05, 1.8)
	return _prop_wood_m


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
		for idx: int in [0, 2, 1, 0, 3, 2]:      # wound to face up: the other way the cards were back faces seen from above, lit from below: black diamonds on the gravel
			st.set_color(cols[i])
			st.set_normal(Vector3.UP)
			st.add_vertex(p[idx])
	return st.commit()
