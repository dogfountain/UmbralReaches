extends Interactable
## Encounters: a bounty notice nailed to a stake by an elite's haunt, or the bounty board at the
## Crossing's foot that carries all of them. [E] reads it in the encounters reader; on the board
## each press turns to the next notice (the first page is the tally: who is at large, who ended).
## One merged mesh (post, board, papers, nails) shared by every post; an ember glint until read.

const KIT_COLORS := {"wood": Color(0.32, 0.22, 0.15), "dark": Color(0.18, 0.12, 0.09), "paper": Color(0.78, 0.72, 0.6), "iron": Color(0.25, 0.24, 0.26)}

var director: Node                ## the encounters director (reads the notes and their status)
var elite_id := ""                ## "" = the board (every notice)
var page := 0
var _glint: MeshInstance3D

static var _meshes := {}
static var _mat: StandardMaterial3D
static var _glint_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	set_meta("site", "enc_bounty")
	var board := elite_id == ""
	var mi := MeshInstance3D.new()
	mi.name = "Post"
	mi.mesh = _mesh(board)
	mi.material_override = _material()
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.5 if board else 0.3, 2.0, 0.25)
	cs.shape = bs
	cs.position = Vector3(0, 1.0, 0)
	body.add_child(cs)
	add_child(body)
	_glint = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	_glint.mesh = q
	if _glint_mat == null:
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glint_mat.albedo_texture = Vfx.dot()
		_glint_mat.albedo_color = Color(1.4, 0.7, 0.3)
	_glint.material_override = _glint_mat
	_glint.position = Vector3(0, 2.15 if board else 1.75, 0.0)
	_glint.visibility_range_end = 26.0
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glint)


func can_interact() -> bool:
	return director != null


func interact_text() -> String:
	var key := Interactable.prompt_key()
	if elite_id == "":
		return "[%s]  Read the bounty board" % key if page == 0 else "[%s]  Next notice" % key
	return "[%s]  Read the bounty notice" % key


func interact(_by: Node) -> void:
	if director == null:
		return
	if _glint:
		_glint.queue_free()
		_glint = null
	page = director.call("read_post", self, page)


func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.9
	return _mat


static func _mesh(board: bool) -> ArrayMesh:
	if _meshes.has(board):
		return _meshes[board]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood: Color = KIT_COLORS.wood
	if board:
		for sx: float in [-0.62, 0.62]:
			_box(st, Vector3(sx, 1.0, 0), Vector3(0.12, 2.0, 0.12), wood, 0.03 * sx)
		_box(st, Vector3(0, 1.45, 0.02), Vector3(1.5, 0.82, 0.05), KIT_COLORS.dark, 0.0)
		_box(st, Vector3(0, 1.92, 0.0), Vector3(1.66, 0.1, 0.16), wood, 0.02)
		for i in 5:
			var x := -0.52 + 0.26 * float(i)
			var y := 1.5 + 0.12 * sin(float(i) * 2.1)
			_box(st, Vector3(x, y, 0.055), Vector3(0.22, 0.3, 0.008), KIT_COLORS.paper, 0.06 * sin(float(i) * 3.3))
			_box(st, Vector3(x, y + 0.12, 0.065), Vector3(0.02, 0.02, 0.02), KIT_COLORS.iron, 0.0)
	else:
		_box(st, Vector3(0, 0.8, 0), Vector3(0.11, 1.6, 0.11), wood, 0.04)
		_box(st, Vector3(0, 1.38, 0.065), Vector3(0.3, 0.38, 0.008), KIT_COLORS.paper, 0.05)
		_box(st, Vector3(0, 1.53, 0.075), Vector3(0.022, 0.022, 0.022), KIT_COLORS.iron, 0.0)
	st.generate_normals()
	var m := st.commit()
	_meshes[board] = m
	return m


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, tilt: float) -> void:
	var b := Basis(Vector3.FORWARD, tilt)
	var h := s * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(c + b * Vector3(h.x * (1.0 if i & 1 else -1.0), h.y * (1.0 if i & 2 else -1.0), h.z * (1.0 if i & 4 else -1.0)))
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	st.set_color(col)
	for f: Array in faces:
		var a: Vector3 = corners[f[0]]
		var bb: Vector3 = corners[f[1]]
		var cc: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		var centre := (a + bb + cc + d) * 0.25
		var outward := centre - c
		var n := (bb - a).cross(cc - a)
		if n.dot(outward) > 0.0:          # Godot front faces wind clockwise: flip to face out
			st.add_vertex(a); st.add_vertex(cc); st.add_vertex(bb)
			st.add_vertex(a); st.add_vertex(d); st.add_vertex(cc)
		else:
			st.add_vertex(a); st.add_vertex(bb); st.add_vertex(cc)
			st.add_vertex(a); st.add_vertex(cc); st.add_vertex(d)
