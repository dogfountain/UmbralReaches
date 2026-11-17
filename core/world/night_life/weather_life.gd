extends Node3D
## WHAT THE WEATHER DOES TO THE WORLD (the Weather node's fronts, core/life/wildlife/weather.gd, are the cause; this is
## the effect on the lit night). Read from the weather's `state` and `flash` twice a second and every frame where it eases:
##   WET GROUND      the global shader term `wetness` (realm_ground and terrain shaders) rises with rain over a minute and dries
##                   over several: rougher to glossy, a little darker; the lamps' and fires' own highlights show in it;
##   PUDDLE GLINTS   a ring of flat reflections on the ground round the wanderer (a MultiMesh of 28 soft quads on a 3 m grid, each cell
##                   with its own puddle or none, stable as he walks): pale sky blue, and where a fire or lit window stands within reach
##                   the puddle takes its colour and a bright elongated streak towards the camera;
##   DRIPS           small drops let go from the eaves of the lit windows and towers within 18 m (two a second at most);
##   FIRES IN RAIN   the fire cards gutter lower and flicker harder (night_registry rain, gust), and the nearest fire within 12 m
##                   hisses: a puff of steam now and then;
##   HALOS           mist and rain swell every far card into a halo (night_registry haze);
##   LIGHTNING       a flash lights every landmark card (registry flash) for the length of the flash;
##   DAWN MIST       at the end of the night (clock past 0.9) the Weather is told to bring in mist, and the sky pass a pale grey
##                   band low in the east (`dawn`).
## Cost: one MultiMesh draw (28 instances, rewritten at 12 Hz only while it is wet), a global shader float, a handful of pooled
## bursts a second in rain, nothing when it is dry. Settings.night_life off puts every term back to dry.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const GLINTS := 28
const CELL := 3.0
const REACH := 13.0

var env: Environment
var _weather: Variant
var _tick := 0.0
var _wet := 0.0
var _mm: MultiMeshInstance3D
var _glint_t := 0.0
var _drip_t := 0.0
var _hiss_t := 4.0
var _ys := {}                              ## cell -> ground y (cached, filled a few rays a frame)
var _dawn_told := false
var _dawn_sent := -1.0
var _sky: ShaderMaterial
static var _tex: ImageTexture


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _glint_tex()
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = GLINTS
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance3D.new()
	_mm.name = "Glints"
	_mm.multimesh = mm
	_mm.material_override = mat
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.custom_aabb = AABB(Vector3(-2000, -400, -2000), Vector3(4000, 1200, 4000))
	_mm.add_to_group(Groups.CULL_SKIP)
	_mm.visible = false
	add_child(_mm)
	if env != null and env.sky != null and env.sky.sky_material is ShaderMaterial:
		_sky = env.sky.sky_material as ShaderMaterial


func _process(delta: float) -> void:
	if not Reg.enabled:
		if _wet > 0.0 or Reg.rain > 0.0:
			_wet = 0.0
			_publish(0.0, 0.0, 0.0, 0.0)
			_mm.visible = false
		return
	if _weather == null:
		_weather = get_tree().current_scene.find_child("Weather", true, false)
	var rain := 0.0
	var mist := 0.0
	var gust := 0.0
	var flash := 0.0
	if _weather != null:
		var st: Dictionary = _weather.get("state")
		rain = float(st.get("rain", 0.0))
		mist = float(st.get("mist", 0.0))
		gust = clampf(float(_weather.get("gust")), 0.0, 1.5)
		flash = clampf(float(_weather.get("flash")), 0.0, 1.0)
	# wet: up over about a minute of rain, dry over several
	if rain > _wet:
		_wet = minf(rain, _wet + delta / 60.0)
	else:
		_wet = maxf(rain, _wet - delta / 320.0)
	Reg.rain = rain
	Reg.gust = gust
	Reg.flash = flash
	Reg.haze = clampf(rain * 0.7 + mist * 0.5, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("wetness", _wet)
	_dawn()
	if _wet < 0.05:
		_mm.visible = false
		return
	_mm.visible = true
	_glint_t -= delta
	if _glint_t <= 0.0:
		_glint_t = 1.0 / 12.0
		_glints()
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = 0.5
		if rain > 0.3 and Reg.indoor < 0.4:
			_drip()
	_hiss_t -= delta
	if _hiss_t <= 0.0:
		_hiss_t = randf_range(2.5, 5.0)
		if rain > 0.4 and Reg.indoor < 0.4:
			_hiss()


func _publish(rain: float, mist: float, gust: float, flash: float) -> void:
	Reg.rain = rain
	Reg.gust = gust
	Reg.flash = flash
	Reg.haze = mist
	RenderingServer.global_shader_parameter_set("wetness", 0.0)
	if _sky != null:
		_sky.set_shader_parameter("dawn", 0.0)


## The end of the night: a pale grey band low in the east and the Weather asked for mist, once.
func _dawn() -> void:
	var c := Reg.clock
	var dawn := maxf(smoothstep(0.88, 1.0, c), smoothstep(0.08, 0.0, c))
	if _sky != null and absf(dawn - _dawn_sent) > 0.002:
		_dawn_sent = dawn
		_sky.set_shader_parameter("dawn", dawn)
	if c > 0.9 and not _dawn_told:
		_dawn_told = true
		if _weather != null:
			_weather.force("mist")
	elif c < 0.5:
		_dawn_told = false


## A ring of puddles on a 3 m grid round the wanderer. A cell has a puddle if its hash says so, at a place and size its hash gives:
## so they stay where they are as he walks, and come and go at the edge. Their colour is the sky's, or the nearest fire's.
func _glints() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var mm := _mm.multimesh
	var cx := floori(cp.x / CELL)
	var cz := floori(cp.z / CELL)
	var n := 0
	var rays := 4
	var t := Time.get_ticks_msec() * 0.001
	var reach_cells := int(REACH / CELL) + 1
	for ix in range(cx - reach_cells, cx + reach_cells + 1):
		for iz in range(cz - reach_cells, cz + reach_cells + 1):
			var h := _hash(ix, iz)
			if h < 0.5 or n >= GLINTS:
				continue
			var cell := Vector2i(ix, iz)
			var px := (float(ix) + 0.2 + 0.6 * fposmod(h * 7.0, 1.0)) * CELL
			var pz := (float(iz) + 0.2 + 0.6 * fposmod(h * 13.0, 1.0)) * CELL
			var d2 := (px - cp.x) * (px - cp.x) + (pz - cp.z) * (pz - cp.z)
			if d2 > REACH * REACH:
				continue
			if not _ys.has(cell):
				if rays <= 0:
					continue
				rays -= 1
				_ys[cell] = _ground(px, pz, cp.y)
				if _ys.size() > 400:
					_ys.clear()
			var y: float = _ys[cell]
			if y == INF:
				continue
			var fade := 1.0 - smoothstep(REACH * 0.6, REACH, sqrt(d2))
			var size := 0.9 + 1.6 * fposmod(h * 3.0, 1.0)
			var col := Color(0.42, 0.56, 0.92)
			var streak := 0.0
			var pos := Vector3(px, y + 0.05, pz)
			# a lit thing within 8 m of the puddle shows in it: warm, and a bright streak drawn towards the camera
			var best := 64.0
			for i in Reg.size():
				if Reg.on[i] == 0 or int(Reg.kind[i]) == Reg.Kind.COLD:
					continue
				var q: Vector3 = Reg.pos[i]
				var dd := (q.x - px) * (q.x - px) + (q.z - pz) * (q.z - pz)
				if dd < best:
					best = dd
					col = Reg.colour(int(Reg.kind[i]))
					streak = 1.0 - sqrt(dd) / 8.0
			var shimmer := 0.65 + 0.35 * sin(t * 1.3 + h * 40.0)
			var a := _wet * fade * (0.1 + 0.28 * streak) * shimmer * (1.0 - Reg.indoor)
			var yaw := atan2(cp.x - px, cp.z - pz)
			var sx := size * (1.0 + 0.9 * streak)
			var sz := size * (1.0 - 0.25 * streak)
			mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sx, 1.0, sz)), pos))
			mm.set_instance_color(n, Color(col.r, col.g, col.b, a))
			n += 1
	mm.visible_instance_count = n


func _ground(x: float, z: float, ref_y: float) -> float:
	var world := get_world_3d()
	if world == null:
		return INF
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, ref_y + 4.0, z), Vector3(x, ref_y - 6.0, z), Layers.WORLD)
	var hit := world.direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else INF


static func _hash(ix: int, iz: int) -> float:
	return fposmod(sin(float(ix) * 127.1 + float(iz) * 311.7) * 43758.5453, 1.0)


## A drop from a lit eave near the wanderer.
func _drip() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var pick := -1
	var seen := 0
	for i in Reg.size():
		var k := int(Reg.kind[i])
		if Reg.on[i] == 0 or (k != Reg.Kind.WINDOW and k != Reg.Kind.TOWER):
			continue
		if cp.distance_squared_to(Reg.pos[i]) < 18.0 * 18.0:
			seen += 1
			if randi() % seen == 0:
				pick = i
	if pick >= 0:
		Vfx.burst((Reg.pos[pick] as Vector3) + Vector3(randf_range(-0.8, 0.8), -0.4, randf_range(-0.8, 0.8)), Color(0.7, 0.82, 1.0, 0.8),
			{"count": 2, "life": 0.6, "speed": Vector2(0.05, 0.3), "size": 0.025, "gravity": 9.0, "spread": 10.0, "dir": Vector3.DOWN})


## Rain on the nearest fire: steam.
func _hiss() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var best := 12.0 * 12.0
	var at := Vector3.INF
	for i in Reg.size():
		if Reg.on[i] == 0 or int(Reg.kind[i]) != Reg.Kind.FIRE:
			continue
		var d2 := cp.distance_squared_to(Reg.pos[i])
		if d2 < best:
			best = d2
			at = Reg.pos[i]
	if at != Vector3.INF:
		Vfx.burst(at + Vector3(0.0, 0.3, 0.0), Color(0.8, 0.82, 0.88, 0.45),
			{"count": 8, "life": 1.4, "speed": Vector2(0.3, 0.9), "size": 0.22, "gravity": -0.6, "spread": 40.0, "dir": Vector3.UP})


static func _glint_tex() -> ImageTexture:
	if _tex:
		return _tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(float(x) + 0.5 - n * 0.5, float(y) + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	_tex = ImageTexture.create_from_image(img)
	return _tex
