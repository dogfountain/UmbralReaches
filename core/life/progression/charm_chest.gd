extends RefCounted
## A small iron-bound chest, lid thrown back, for a charm lying in the world (charm_pickup.gd):
## planked oak, two iron straps, a brass lock plate, a rounded lid. Local origin on the ground,
## front toward +z. About 0.6 m wide, 0.3 m tall closed; the open lid leans back behind it.

const MeshMerge := preload("res://core/util/mesh_merge.gd")

static var _wood: StandardMaterial3D
static var _iron: StandardMaterial3D
static var _brass: StandardMaterial3D
static var _lid_mesh: ArrayMesh


static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Chest"
	parent.add_child(root)
	var wood := _wood_mat()
	var iron := _iron_mat()
	# body: planked box, a darker inner floor, a stone-dark rim line
	_box(root, Vector3(0, 0.13, 0), Vector3(0.6, 0.26, 0.38), wood)
	_box(root, Vector3(0, 0.265, 0), Vector3(0.52, 0.012, 0.3), _dark_mat())      # the hollow
	# base plinth and iron straps round the body
	_box(root, Vector3(0, 0.015, 0), Vector3(0.64, 0.03, 0.42), iron)
	for x: float in [-0.2, 0.2]:
		_box(root, Vector3(x, 0.14, 0), Vector3(0.05, 0.27, 0.4), iron)
	# corner studs
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(root, Vector3(sx * 0.3, 0.255, sz * 0.19), Vector3(0.035, 0.035, 0.035), iron)
	# lock plate and hasp on the front
	_box(root, Vector3(0, 0.2, 0.196), Vector3(0.09, 0.1, 0.014), _brass_mat())
	_box(root, Vector3(0, 0.2, 0.205), Vector3(0.016, 0.034, 0.006), _dark_mat())
	# the boxes sharing a material become one mesh (10 draws -> 4, same pixels); before the hinge, which
	# stays the last child (loot_chest.gd finds the lid there)
	MeshMerge.merge_children(root)
	# the lid: a half-barrel hinged at the back top edge, thrown back about 110 degrees
	var hinge := Node3D.new()
	hinge.position = Vector3(0, 0.26, -0.19)
	hinge.rotation.x = -deg_to_rad(105.0)
	root.add_child(hinge)
	var lid := MeshInstance3D.new()
	lid.mesh = _lid()
	lid.material_override = wood
	lid.position = Vector3(0, 0, 0.19)
	hinge.add_child(lid)
	return root


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)


## Half-barrel lid: axis along x, its flat side down (y = 0), width 0.6, depth 0.38, rise 0.12;
## the two iron bands are the same arch a little proud, as a second surface (vertex-coloured).
static func _lid() -> ArrayMesh:
	if _lid_mesh != null:
		return _lid_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := 0.3
	var hz := 0.19
	var rise := 0.13
	var n := 8
	var wood := Color(1, 1, 1)
	var band := Color(0.34, 0.34, 0.37)
	for i in n:
		var a0 := PI * float(i) / float(n)
		var a1 := PI * float(i + 1) / float(n)
		var p0 := Vector2(-cos(a0) * hz, sin(a0) * rise)       # (z, y) around the arch
		var p1 := Vector2(-cos(a1) * hz, sin(a1) * rise)
		var n0 := Vector3(0, sin((a0 + a1) * 0.5) * hz, -cos((a0 + a1) * 0.5) * rise).normalized()
		_quad(st, Vector3(-hx, p0.y, p0.x), Vector3(hx, p0.y, p0.x), Vector3(hx, p1.y, p1.x), Vector3(-hx, p1.y, p1.x), n0, wood)
		for bx: float in [-0.2, 0.2]:
			var w := 0.025
			var k := 1.07
			var q0 := Vector2(p0.x * k, p0.y * k)
			var q1 := Vector2(p1.x * k, p1.y * k)
			_quad(st, Vector3(bx - w, q0.y, q0.x), Vector3(bx + w, q0.y, q0.x), Vector3(bx + w, q1.y, q1.x), Vector3(bx - w, q1.y, q1.x), n0, band)
	# end caps (the plank ends), flat
	for sx: float in [-1.0, 1.0]:
		for i in n:
			var a0 := PI * float(i) / float(n)
			var a1 := PI * float(i + 1) / float(n)
			var c := Vector3(sx * hx, 0, 0)
			var v0 := Vector3(sx * hx, sin(a0) * rise, -cos(a0) * hz)
			var v1 := Vector3(sx * hx, sin(a1) * rise, -cos(a1) * hz)
			var tri: Array[Vector3] = [c, v0, v1]
			if sx < 0.0:
				tri = [c, v1, v0]
			for v in tri:
				st.set_color(wood)
				st.set_normal(Vector3(sx, 0, 0))
				st.add_vertex(v)
	# the underside, so the open lid is solid from below
	_quad(st, Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz), Vector3.DOWN, wood.darkened(0.4))
	_lid_mesh = st.commit()
	return _lid_mesh


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


static func _wood_mat() -> StandardMaterial3D:
	if _wood != null:
		return _wood
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.03
	nz.fractal_octaves = 3
	var g := Gradient.new()
	g.set_color(0, Color(0.16, 0.1, 0.06))
	g.set_color(1, Color(0.42, 0.28, 0.16))
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.noise = nz
	tex.color_ramp = g
	tex.seamless = true
	_wood = StandardMaterial3D.new()
	_wood.albedo_texture = tex
	_wood.vertex_color_use_as_albedo = true
	_wood.uv1_scale = Vector3(0.6, 5.0, 1.0)            # grain runs along the planks
	_wood.uv1_triplanar = true
	_wood.roughness = 0.82
	_wood.albedo_color = Color(1.15, 1.1, 1.05)
	return _wood


static func _iron_mat() -> StandardMaterial3D:
	if _iron != null:
		return _iron
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.3, 0.3, 0.33)
	_iron.metallic = 0.7
	_iron.roughness = 0.5
	return _iron


static func _brass_mat() -> StandardMaterial3D:
	if _brass != null:
		return _brass
	_brass = StandardMaterial3D.new()
	_brass.albedo_color = Color(0.62, 0.46, 0.2)
	_brass.metallic = 0.8
	_brass.roughness = 0.4
	return _brass


static func _dark_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.025, 0.025)
	m.roughness = 1.0
	return m


static func release() -> void:
	_wood = null
	_iron = null
	_brass = null
	_lid_mesh = null
