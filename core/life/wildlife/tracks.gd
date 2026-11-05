extends MultiMeshInstance3D
## Signs on the ground (life system r28): hoofprints where the deer ran and the elk walked, a fox's
## paw marks round a pounce, the white hart's glowing slots, and the lasting signs under the owls'
## trees (pellets, a moulted feather) and the crows' stones. One MultiMesh of small quads lying on the
## terrain (track.gdshader draws the shapes and fades them); prints are a ring buffer, the lasting
## signs a fixed block at the start. The buffer is written at most 4 times a second.
## Owned by the director ("Tracks"); groups call `print_at()`. Load by path (no class_name).

const RL := preload("res://core/world/realm/realm_land.gd")
const SH := preload("res://core/life/wildlife/track.gdshader")

const N := 192
const SIGNS := 40               ## slots kept for lasting signs
const SIZE := {0: 0.12, 1: 0.08, 2: 0.15, 3: 0.16, 4: 0.05}

var now := 0.0                  ## the director's clock (s)
var laid := 0                   ## prints laid so far (tests)
var signs := 0
var _rows := PackedFloat32Array()
var _next := SIGNS
var _dirty := false
var _t := 0.0
var _mat: ShaderMaterial
var _rain := -1.0


func _init() -> void:
	name = "Tracks"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	mm.instance_count = N
	multimesh = mm
	_mat = ShaderMaterial.new()
	_mat.shader = SH
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_meta("chunked", true)
	set_meta("site_owned", true)
	add_to_group(Groups.CULL_SKIP)
	# the prints are scattered over the whole Realm: one box for all of them
	mm.custom_aabb = AABB(Vector3(-210, -40, -250), Vector3(420, 120, 430))
	_rows.resize(N * 16)
	for i in N:
		_put(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3(0, -500, 0)), Color(0, -1e6, 1.0, 0))
	_dirty = true


## Lay a print or a sign at p (on the ground under it), facing yaw. life in seconds (INF: lasting).
func print_at(p: Vector3, yaw: float, kind: int, life := 90.0, on_floor := NAN) -> void:
	var i := 0
	if life == INF:
		if signs >= SIGNS:
			return
		i = signs
		signs += 1
		life = 1e9
	else:
		i = _next
		_next += 1
		if _next >= N:
			_next = SIGNS
		laid += 1
	var y := on_floor if not is_nan(on_floor) else RL.height_at(p.x, p.z)
	if RL.in_water(p.x, p.z):
		return
	# lie on the slope
	var gx := RL.height_at(p.x + 0.4, p.z) - RL.height_at(p.x - 0.4, p.z)
	var gz := RL.height_at(p.x, p.z + 0.4) - RL.height_at(p.x, p.z - 0.4)
	var up := Vector3(-gx, 0.8, -gz).normalized() if is_nan(on_floor) else Vector3.UP
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := up.cross(-fwd).normalized()
	fwd = right.cross(up).normalized() * -1.0
	var s: float = SIZE.get(kind, 0.1)
	var b := Basis(right * s, up, -fwd * s * (1.25 if kind != 3 else 2.2))
	_put(i, Transform3D(b, Vector3(p.x, y + 0.025, p.z)), Color(float(kind), now, life, fposmod(p.x * 0.37 + p.z * 0.11, 1.0)))
	_dirty = true


func _put(i: int, xf: Transform3D, c: Color) -> void:
	var b := xf.basis
	var o := xf.origin
	var k := i * 16
	var v := [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, c.r, c.g, c.b, c.a]
	for j in 16:
		_rows[k + j] = v[j]


func step(dt: float, rain: float) -> void:
	now += dt
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.25
	_mat.set_shader_parameter("now", now)
	var r := snappedf(rain, 0.05)
	if r != _rain:
		_rain = r
		_mat.set_shader_parameter("rain", r)
	if _dirty:
		_dirty = false
		multimesh.buffer = _rows


## Live prints (laid within their life), for tests.
func live() -> int:
	var n := 0
	for i in range(SIGNS, N):
		var born := _rows[i * 16 + 13]
		var life := _rows[i * 16 + 14]
		if born > -1e5 and now - born < life:
			n += 1
	return n
