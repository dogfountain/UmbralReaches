extends Node3D
## DRIFTING MIST BANKS, LIT BY WHAT BURNS IN THEM. Twelve broad, soft banks of low mist drift across the ground
## round the wanderer on a slow wind (the wind turns now and then), wrapping at 70 m so the mist is always about him
## and never pops. They are pale and blue in the open; where a bank passes a fire or a lit window the light stains it
## warm, a glow in the fog; a mystery stains it cold. So the dark between landmarks is not empty: it moves, and every
## light has a halo of weather. Flat soft quads (a generated cloud texture), unshaded, alpha-blended, a proximity fade
## where they meet the ground so there is no hard line. One MultiMesh, twelve instances, updated by formula.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const N := 12
const HALF := 70.0
const OPEN := Color(0.36, 0.46, 0.66)

var _mm: MultiMesh
var _mi: MultiMeshInstance3D
var _off: Array[Vector2] = []
var _size: PackedFloat32Array = PackedFloat32Array()
var _lift: PackedFloat32Array = PackedFloat32Array()
var _wind := Vector2(0.45, 0.15)
var _wind_goal := Vector2(0.45, 0.15)
var _wind_t := 0.0
var _t := 0.0
var _gy := 0.0
var _tick := 0.0
static var _tex: ImageTexture


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var rng := RandomNumberGenerator.new()
	rng.seed = 77031
	for i in N:
		_off.append(Vector2(rng.randf_range(-HALF, HALF), rng.randf_range(-HALF, HALF)))
		_size.append(rng.randf_range(34.0, 62.0))
		_lift.append(rng.randf_range(0.5, 1.7))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _cloud()
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 2.5
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = N
	_mm.visible_instance_count = 0
	_mi = MultiMeshInstance3D.new()
	_mi.name = "MistBanks"
	_mi.multimesh = _mm
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.custom_aabb = AABB(Vector3(-2000, -400, -2000), Vector3(4000, 1200, 4000))
	_mi.add_to_group(Groups.CULL_SKIP)
	add_child(_mi)


func _process(delta: float) -> void:
	_t += delta
	visible = Reg.enabled
	if not Reg.enabled:
		return
	# the wind turns slowly
	_wind_t -= delta
	if _wind_t <= 0.0:
		_wind_t = randf_range(40.0, 90.0)
		var a := randf() * TAU
		_wind_goal = Vector2(cos(a), sin(a)) * randf_range(0.25, 0.7)
	_wind = _wind.lerp(_wind_goal, minf(1.0, delta * 0.05))
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if player == null:
		return
	var pp := player.global_position
	_gy = lerpf(_gy, pp.y, minf(1.0, delta * 0.6)) if _t > 1.0 else pp.y
	for i in N:
		_off[i] += _wind * delta * (0.8 + 0.4 * _size[i] / 62.0)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.05
	var n := 0
	for i in N:
		# wrap round the wanderer
		var o := _off[i]
		var rel := Vector2(fposmod(o.x - pp.x + HALF, HALF * 2.0) - HALF, fposmod(o.y - pp.z + HALF, HALF * 2.0) - HALF)
		var w := Vector3(pp.x + rel.x, _gy + _lift[i] + 0.25 * sin(_t * 0.07 + float(i)), pp.z + rel.y)
		var edge := 1.0 - smoothstep(HALF * 0.55, HALF * 0.98, maxf(absf(rel.x), absf(rel.y)))
		var tint := OPEN
		var warm := 0.0
		var cold := 0.0
		# a fire or window within the bank's reach stains it; the nearest decides
		var reach := _size[i] * 0.55
		var best := reach * reach
		for r in Reg.size():
			if Reg.on[r] == 0:
				continue
			var q: Vector3 = Reg.pos[r]
			var dx := q.x - w.x
			var dz := q.z - w.z
			var d2 := dx * dx + dz * dz
			if d2 < best:
				best = d2
				var f := 1.0 - sqrt(d2) / reach
				var k := int(Reg.kind[r])
				warm = f * Reg.gain[r] if k != Reg.Kind.MYSTERY and k != Reg.Kind.COLD else 0.0
				cold = f * Reg.gain[r] if k == Reg.Kind.MYSTERY else 0.0
		tint = tint.lerp(Color(1.0, 0.62, 0.3), clampf(warm, 0.0, 1.0) * 0.8)
		tint = tint.lerp(Color(0.4, 0.85, 1.0), clampf(cold, 0.0, 1.0) * 0.8)
		var a := (0.085 + 0.1 * maxf(warm, cold)) * edge * (0.85 + 0.15 * sin(_t * 0.11 + float(i) * 2.0))
		var s := _size[i]
		var yaw := float(i) * 0.9 + _t * 0.004
		_mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, 1.0, s)), w))
		_mm.set_instance_color(n, Color(tint.r, tint.g, tint.b, a))
		n += 1
	_mm.visible_instance_count = n


## A cloud: low-frequency noise under a round fall-off, so no bank has an edge.
static func _cloud() -> ImageTexture:
	if _tex:
		return _tex
	var n := 96
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(float(x) + 0.5 - n * 0.5, float(y) + 0.5 - n * 0.5).length() / (n * 0.5)
			var fall := 1.0 - smoothstep(0.2, 1.0, r)
			var v := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(fall * (0.25 + 0.9 * v) , 0.0, 1.0)))
	_tex = ImageTexture.create_from_image(img)
	return _tex
