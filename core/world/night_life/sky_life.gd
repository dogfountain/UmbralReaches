extends Node
## THE LIVING SKY (the vortex sky shader's new terms, world/sky/vortex.gdshader). Set once or twice a second, nothing per
## frame:
##   MOON PHASE      eight nights to a cycle, tied to the saved night count (Days.current()): night 0 is a full moon, then it
##                   wanes to a new moon on night 4 and waxes again. The disc is drawn as a lit sphere (the terminator by
##                   a dot product) and the moon's light scales with it (0.6 of the full at a new moon): the dark nights
##                   are darker, and every landmark shines the more.
##   ECLIPSE SKY     during the eclipse (night_registry gain_mul) the disc, corona and streaks fall to a tenth and turn copper,
##                   the stars and the constellations come up half again, the aurora swells.
##   CONSTELLATIONS  five patterns of the Realm's own lore (the Lantern, the Crown, the Bell, the Anchor, the Long Road) baked once into
##                   a small equirect texture (stars and faint lines): the sky pass pays one texture fetch.
##   AURORA NIGHTS   the veils' strength is a hash of the night count: some nights a faint thread, some a great curtain.
##   CLOUD           a deck of cloud overhead: a base cover a hash of the night count, raised by the weather's mist and rain, lit
##                   warm from below over the fires on the ground (the six strongest within 260 m, their directions given as
##                   a uniform array), darkening the stars behind it.
## Settings.night_life off puts every term back to the old sky. Load by path.

const Reg := preload("res://core/world/night_life/night_registry.gd")
const Days := preload("res://core/story/days.gd")

const CYCLE_NIGHTS := 8
const FIRE_R := 260.0
const COPPER := Vector3(1.0, 0.42, 0.22)

## [name, azimuth, elevation (degrees; azimuth 0 is north, the vortex), stars [x, y] in degrees about the centre, lines [a, b]]
const SHAPES := [
	["lantern", 118.0, 48.0, [[0, 7], [-3, 4], [3, 4], [-3, 0], [3, 0], [-4, -4], [4, -4], [0, -7]], [[0, 1], [0, 2], [1, 3], [2, 4], [3, 5], [4, 6], [5, 6], [5, 7], [6, 7]]],
	["crown", 205.0, 56.0, [[-8, -2], [-4, 2], [0, -1], [4, 2], [8, -2], [0, -5]], [[0, 1], [1, 2], [2, 3], [3, 4], [2, 5]]],
	["bell", 270.0, 38.0, [[0, 8], [-4, 2], [4, 2], [-6, -4], [6, -4], [0, -6]], [[0, 1], [0, 2], [1, 3], [2, 4], [3, 5], [4, 5]]],
	["anchor", 160.0, 30.0, [[0, 8], [0, 2], [0, -5], [-6, -2], [6, -2], [-3, 5], [3, 5]], [[0, 1], [1, 2], [2, 3], [2, 4], [5, 6]]],
	["road", 312.0, 62.0, [[-9, -4], [-5, 1], [-1, -2], [3, 3], [7, 0], [10, 5]], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5]]],
]

var env: Environment
var moon: DirectionalLight3D
var _mat: ShaderMaterial
var _tex: ImageTexture
var _tick := 0.0
var _cloud := 0.0
var _cloud_goal := 0.0
var _weather: Node
var _fire := PackedVector4Array()
var _night := -1
var _clock := 0.0


func _ready() -> void:
	_fire.resize(6)
	if env != null and env.sky != null and env.sky.sky_material is ShaderMaterial:
		_mat = env.sky.sky_material as ShaderMaterial
	if _mat == null:
		return
	_tex = _bake()
	_mat.set_shader_parameter("constellations", _tex)


func _process(delta: float) -> void:
	if _mat == null:
		return
	_clock += delta
	_tick -= delta
	if _tick > 0.0:
		_cloud = lerpf(_cloud, _cloud_goal, 1.0 - exp(-0.15 * delta))
		return
	_tick = 0.5
	if not Reg.enabled:
		_reset()
		return
	var n := Days.current()
	var e := clampf((Reg.gain_mul - 1.0) / 0.55, 0.0, 1.0)
	# the phase and the light it gives
	var phase := fposmod(float(n) / float(CYCLE_NIGHTS) + 0.5, 1.0)
	var bright := 0.5 - 0.5 * cos(phase * TAU)
	Reg.moon_gain = lerpf(0.6, 1.0, bright)
	_mat.set_shader_parameter("moon_phase", phase)
	_mat.set_shader_parameter("moon_glow", lerpf(1.0, 0.08, e))
	_mat.set_shader_parameter("moon_tint", Vector3(1, 1, 1).lerp(COPPER, e))
	_mat.set_shader_parameter("const_vis", 1.0 + 0.6 * e)
	if n != _night:
		_night = n
	# the aurora of the night and the cloud of the night
	var aur := 0.5 + 1.3 * fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)
	_mat.set_shader_parameter("aurora", aur * (1.0 + 0.6 * e))
	var base := 0.45 * fposmod(sin(float(n) * 78.233) * 43758.5453, 1.0)
	var wet := 0.0
	if _weather == null:
		_weather = get_tree().current_scene.find_child("Weather", true, false)
	if _weather != null:
		var st: Dictionary = _weather.get("state")
		wet = float(st.get("mist", 0.0)) * 0.45 + float(st.get("rain", 0.0)) * 0.6
	_cloud_goal = clampf(base + wet, 0.0, 1.0)
	_mat.set_shader_parameter("cloud_cover", _cloud)
	_fires()


## The six strongest fires within reach, as directions from the camera.
func _fires() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var best := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for j in 6:
		_fire[j] = Vector4(0, 1, 0, 0)
	for i in Reg.size():
		if Reg.on[i] == 0 or int(Reg.kind[i]) != Reg.Kind.FIRE:
			continue
		var d: Vector3 = (Reg.pos[i] as Vector3) - cp
		var dist := d.length()
		if dist > FIRE_R or dist < 8.0:
			continue
		var s := clampf(float(Reg.gain[i]) * (1.0 - dist / FIRE_R) * 0.9 * (1.0 + float(Reg.boost[i])), 0.0, 1.2)
		# keep the six strongest (a small insertion)
		for j in 6:
			if s > float(best[j]):
				var k := 5
				while k > j:
					best[k] = best[k - 1]
					_fire[k] = _fire[k - 1]
					k -= 1
				best[j] = s
				var dn := d / dist
				_fire[j] = Vector4(dn.x, dn.y, dn.z, s)
				break
	_mat.set_shader_parameter("fire_glow", _fire)


func _reset() -> void:
	_mat.set_shader_parameter("moon_phase", 0.5)
	_mat.set_shader_parameter("moon_glow", 1.0)
	_mat.set_shader_parameter("moon_tint", Vector3(1, 1, 1))
	_mat.set_shader_parameter("aurora", 1.0)
	_mat.set_shader_parameter("cloud_cover", 0.0)
	_mat.set_shader_parameter("const_vis", 0.0)
	Reg.moon_gain = 1.0


## The constellations as stars and faint lines in a 512 x 256 equirect (azimuth across, polar angle down): built once.
func _bake() -> ImageTexture:
	var w := 512
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for shape: Array in SHAPES:
		var c_az: float = shape[1]
		var c_el: float = shape[2]
		var pts: Array = shape[3]
		var px := PackedVector2Array()
		for p: Array in pts:
			var el := c_el + float(p[1])
			var az := c_az + float(p[0]) / maxf(cos(deg_to_rad(el)), 0.2)
			px.append(_uv(az, el, w, h))
		for ln: Array in shape[4]:
			_line(img, px[int(ln[0])], px[int(ln[1])], Color(0.28, 0.4, 0.62, 0.0))
		for i in px.size():
			_star(img, px[i], 1.0 if i % 3 == 0 else 0.7)
	return ImageTexture.create_from_image(img)


## Azimuth (degrees, 0 = north, growing east) and elevation to a pixel of the equirect the sky shader samples.
static func _uv(az: float, el: float, w: int, h: int) -> Vector2:
	var a := wrapf(az, -180.0, 180.0)
	var u := a / 360.0 + 0.5
	var v := (90.0 - el) / 180.0
	return Vector2(u * float(w), v * float(h))


static func _star(img: Image, p: Vector2, mag: float) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := int(p.x) + dx
			var y := int(p.y) + dy
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var f := 1.0 if (dx == 0 and dy == 0) else 0.3
			var c := img.get_pixel(x, y)
			var v := minf(1.0, c.r + f * mag)
			img.set_pixel(x, y, Color(v * 0.9, v * 0.95, v, 1.0))


static func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var q := a.lerp(b, float(i) / float(maxi(n, 1)))
		var x := int(q.x)
		var y := int(q.y)
		if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
			continue
		var c := img.get_pixel(x, y)
		img.set_pixel(x, y, Color(maxf(c.r, 0.1), maxf(c.g, 0.16), maxf(c.b, 0.26), 1.0))
