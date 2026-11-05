extends Interactable
## Encounters: the Bell of the Deeper Night. It stands silent until the Ascended Warden falls (the
## sky stops turning; "somewhere above the Crowns, a bell rings once"). Then [E] reads what ringing
## it means; [E] again within a few seconds rings it: the Deeper Night (NG+) begins -- the three
## who hold the valley rise again, the hollowed come back harder, the elites return Umbral.
## A black frame and a cracked iron bell, one merged mesh; a cold glint while it waits.

var director: Node
var _armed_until := 0.0
var _glow: MeshInstance3D

static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D
static var _glow_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	set_meta("site", "enc_bell")
	var mi := MeshInstance3D.new()
	mi.name = "Bell"
	mi.mesh = _build_mesh()
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.55
		_mat.metallic = 0.35
	mi.material_override = _mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	for sx: float in [-0.95, 0.95]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.22, 2.9, 0.22)
		cs.shape = bs
		cs.position = Vector3(sx, 1.45, 0)
		body.add_child(cs)
	add_child(body)
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	_glow.mesh = q
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glow_mat.albedo_texture = Vfx.dot()
		_glow_mat.albedo_color = Color(0.5, 0.8, 1.6)
	_glow.material_override = _glow_mat
	_glow.position = Vector3(0, 1.75, 0)
	_glow.visibility_range_end = 40.0
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)


func awake() -> bool:
	return Travel.bosses_slain.has("ascended_warden")


func can_interact() -> bool:
	return director != null


func interact_text() -> String:
	var key := Interactable.prompt_key()
	if not awake():
		return "[%s]  Touch the silent bell" % key
	if Time.get_ticks_msec() * 0.001 < _armed_until:
		return "[%s]  Ring it: begin the Deeper Night" % key
	return "[%s]  The bell of the Deeper Night" % key


func interact_feel() -> StringName:
	return &"cast"


func interact(_by: Node) -> void:
	if director == null:
		return
	if not awake():
		director.call("bell_note", self, false)
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < _armed_until:
		_armed_until = 0.0
		Sfx.play("res://art/audio/ward_chime.wav", global_position + Vector3.UP * 2.0, 3.0, 0.45)   # 3D players cap at max_db 3
		director.call("begin_deeper_night", true)
		return
	_armed_until = now + 8.0
	director.call("bell_note", self, true)


func _process(_d: float) -> void:
	if _glow:
		_glow.visible = awake()


static func _build_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frame := Color(0.12, 0.1, 0.11)
	var iron := Color(0.24, 0.25, 0.3)
	# two posts and a beam, a little askew
	for sx: float in [-0.95, 0.95]:
		_lathe(st, Vector3(sx, 0.0, 0.0), [[0.0, 0.13], [2.9, 0.1]], 6, frame)
	_lathe_x(st, Vector3(-1.15, 2.8, 0.0), 2.3, 0.1, frame)
	# the bell: a flared lathe profile, mouth down
	_lathe(st, Vector3(0, 0.62, 0), [[0.0, 0.47], [0.05, 0.44], [0.25, 0.36], [0.5, 0.3], [0.8, 0.26], [0.98, 0.18], [1.06, 0.06], [1.1, 0.0]], 14, iron)
	# the clapper and the rope it hangs from
	_lathe(st, Vector3(0, 0.45, 0), [[0.0, 0.0], [0.08, 0.07], [0.2, 0.04], [0.55, 0.02]], 6, Color(0.1, 0.1, 0.12))
	_lathe(st, Vector3(0, 1.72, 0), [[0.0, 0.03], [1.08, 0.03]], 4, iron)
	st.generate_normals()
	_mesh = st.commit()
	return _mesh


## A surface of revolution about +Y at `base`: profile [[height, radius], ...] bottom to top.
static func _lathe(st: SurfaceTool, base: Vector3, prof: Array, sides: int, col: Color) -> void:
	st.set_color(col)
	for i in prof.size() - 1:
		var h0 := float(prof[i][0])
		var r0 := float(prof[i][1])
		var h1 := float(prof[i + 1][0])
		var r1 := float(prof[i + 1][1])
		for s in sides:
			var a0 := TAU * float(s) / float(sides)
			var a1 := TAU * float(s + 1) / float(sides)
			var p00 := base + Vector3(cos(a0) * r0, h0, sin(a0) * r0)
			var p01 := base + Vector3(cos(a1) * r0, h0, sin(a1) * r0)
			var p10 := base + Vector3(cos(a0) * r1, h1, sin(a0) * r1)
			var p11 := base + Vector3(cos(a1) * r1, h1, sin(a1) * r1)
			_quad(st, p00, p01, p11, p10, base + Vector3(0, (h0 + h1) * 0.5, 0))


static func _lathe_x(st: SurfaceTool, from: Vector3, length: float, r: float, col: Color) -> void:
	st.set_color(col)
	var sides := 6
	for s in sides:
		var a0 := TAU * float(s) / float(sides)
		var a1 := TAU * float(s + 1) / float(sides)
		var o0 := Vector3(0, cos(a0) * r, sin(a0) * r)
		var o1 := Vector3(0, cos(a1) * r, sin(a1) * r)
		var e := Vector3(length, 0, 0)
		_quad(st, from + o0, from + o1, from + e + o1, from + e + o0, from + e * 0.5)


## A quad wound so its front faces away from `inside` (Godot fronts wind clockwise).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	var centre := (a + b + c + d) * 0.25
	var n := (b - a).cross(c - a)
	if n.dot(centre - inside) > 0.0:
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
		st.add_vertex(a); st.add_vertex(d); st.add_vertex(c)
	else:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
