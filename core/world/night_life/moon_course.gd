extends Node
## THE MOON'S COURSE AND THE ECLIPSE. The night is one long hour (Reg.NIGHT_LEN, 25 minutes, then it comes round
## again): the moon sets its course slowly across the sky, so every shadow in the Realm creeps round the things that cast
## it; it rides higher and whiter at midnight and lower and bluer at the ends; slow cloud veils pass over it (its light
## breathes a tenth, now and then a quarter). Landmarks are the point of the night, so the moon only ever shows the shape
## of the dark.
##
## THE ECLIPSE: once per run, at half the night (a fraction of a second never seen twice), the moon goes out:
##   a warning toast and the moon's light turning copper over 25 s;
##   TOTALITY (45 s): the moon at a tenth, the fill halved, the sky dimmed, the whole land black but for its lights:
##   every landmark card and lent light blooms to half again, so the Realm is a scatter of fires, windows and cold
##   mysteries to be walked toward;
##   the moon returning over 20 s, the sky's colour with it, a toast.
## Held while a boss is engaged (the fight is its own moment), and not played at all with the Living Night off.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const ECLIPSE_AT := 0.5
const APPROACH := 25.0 / Reg.NIGHT_LEN
const TOTAL := 45.0 / Reg.NIGHT_LEN
const RETURN := 20.0 / Reg.NIGHT_LEN
const BEARING_SWING := 20.0               ## degrees either side of the old fixed bearing
const COPPER := Color(0.95, 0.42, 0.24)

static var eclipse_done := false

var moon: DirectionalLight3D
var env: Environment
var fill: DirectionalLight3D
var _base_sky := 0.79
var _t := 0.0
var _tick := 0.0
var _boss := false
var _last := 0.0                          ## the energy this node set last
var _yield := 0.0
var _bk := 0.0                            ## a boss fight eases the eclipse out
var _eclipse := 0.0                       ## 0 none .. 1 totality
var _told := 0                            ## toasts given: 1 warning, 2 totality, 3 return


func _ready() -> void:
	Events.boss_engaged.connect(func(_b: Node, _t2: String) -> void: _boss = true)
	Events.boss_slain.connect(func(_id: String) -> void: _boss = false)
	Events.respawned.connect(func(_at: Vector3) -> void: _boss = false)
	if env != null and env.sky != null and env.sky.sky_material is ShaderMaterial:
		var v: Variant = (env.sky.sky_material as ShaderMaterial).get_shader_parameter("intensity")
		if v is float:
			_base_sky = v


func _process(delta: float) -> void:
	_t += delta
	_bk = move_toward(_bk, 1.0 if _boss else 0.0, delta * 0.5)
	if Reg.enabled:
		# the clock waits just before the eclipse while a boss is fought: the eclipse is its own moment
		var start := ECLIPSE_AT - APPROACH
		var hold := _boss and not eclipse_done and Reg.clock > start - 0.004 and Reg.clock < start
		if not hold:
			Reg.clock += delta / Reg.NIGHT_LEN
		if Reg.clock >= 1.0:
			Reg.clock -= 1.0
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.1
	_apply()


## 0 (no eclipse) .. 1 (totality). Played once per run: the night coming round shows the moon whole.
func _eclipse_amount(c: float) -> float:
	if eclipse_done:
		return 0.0
	var a := ECLIPSE_AT - APPROACH
	var z := ECLIPSE_AT + TOTAL + RETURN
	if c >= z:
		eclipse_done = true
		return 0.0
	if c < a:
		return 0.0
	if c < ECLIPSE_AT:
		return smoothstep(a, ECLIPSE_AT, c) * 0.55
	if c < ECLIPSE_AT + TOTAL:
		return lerpf(0.55, 1.0, smoothstep(ECLIPSE_AT, ECLIPSE_AT + 0.004, c))
	return 1.0 - smoothstep(ECLIPSE_AT + TOTAL, z, c)


func _apply() -> void:
	if moon == null or not is_instance_valid(moon):
		return
	var c := Reg.clock
	if not Reg.enabled:
		_restore()
		return
	# someone else drives the moon (the Henge raid's brighter moon and its tweens): leave it be for a while
	if _last > 0.0 and absf(moon.light_energy - _last) > 0.03:
		_yield = 25.0
	if _yield > 0.0:
		_yield -= 0.1
		_last = moon.light_energy
		return
	var e := _eclipse_amount(c) * (1.0 - _bk)
	_toasts(c)
	_eclipse = e
	# the course: bearing swings across the night, the moon rides highest at midnight
	var bearing := Atmosphere.MOON_BEARING - BEARING_SWING + 2.0 * BEARING_SWING * c
	var elev := Atmosphere.MOON_ELEVATION - 6.0 + 9.0 * sin(PI * c)
	var el := deg_to_rad(elev)
	var b := deg_to_rad(bearing)
	var to_moon := Vector3(sin(b) * cos(el), sin(el), -cos(b) * cos(el))
	moon.global_basis = Basis.looking_at(-to_moon, Vector3.UP)
	# whiter high, bluer low
	var high := sin(PI * c)
	var col := Atmosphere.MOON_COLOR.lerp(Color(0.8, 0.88, 1.0), 0.35 * high)
	# a veil: the light breathes a tenth, and slow clouds take a quarter now and then
	var veil := 1.0 - 0.08 * (0.5 + 0.5 * sin(_t * 0.09)) - 0.17 * pow(maxf(0.0, sin(_t * 0.023 + 1.7) * sin(_t * 0.061)), 2.0)
	moon.light_energy = Atmosphere.MOON_ENERGY * veil * lerpf(1.0, 0.1, e)
	_last = moon.light_energy
	moon.light_color = col.lerp(COPPER, e)
	moon.light_volumetric_fog_energy = Atmosphere.MOON_FOG * lerpf(1.0, 0.2, e)
	if fill != null and is_instance_valid(fill):
		var fb := deg_to_rad(bearing + 180.0)
		var fe := deg_to_rad(Atmosphere.FILL_ELEVATION)
		var to_fill := Vector3(sin(fb) * cos(fe), sin(fe), -cos(fb) * cos(fe))
		fill.global_basis = Basis.looking_at(-to_fill, Vector3.UP)
		fill.light_energy = Atmosphere.FILL_ENERGY * lerpf(1.0, 0.45, e)
	if env != null and env.sky != null and env.sky.sky_material is ShaderMaterial:
		var mat := env.sky.sky_material as ShaderMaterial
		mat.set_shader_parameter("moon_dir", moon.global_basis.z)
		mat.set_shader_parameter("intensity", _base_sky * lerpf(1.0, 0.62, e))
	Reg.gain_mul = 1.0 + 0.55 * e


func _toasts(c: float) -> void:
	if eclipse_done and _told == 0:
		return
	if _boss:
		return
	if _told < 1 and c >= ECLIPSE_AT - APPROACH and c < ECLIPSE_AT:
		_told = 1
		Events.toast.emit("The moon's light turns to copper")
	elif _told < 2 and c >= ECLIPSE_AT and c < ECLIPSE_AT + TOTAL:
		_told = 2
		Events.toast.emit("The moon goes out. Follow the lights")
	elif _told < 3 and c >= ECLIPSE_AT + TOTAL:
		_told = 3
		Events.toast.emit("The moon returns")


## The Living Night switched off mid-night: the moon goes back to its fixed place and colour.
func _restore() -> void:
	var el := deg_to_rad(Atmosphere.MOON_ELEVATION)
	var b := deg_to_rad(Atmosphere.MOON_BEARING)
	var to_moon := Vector3(sin(b) * cos(el), sin(el), -cos(b) * cos(el))
	moon.global_basis = Basis.looking_at(-to_moon, Vector3.UP)
	moon.light_energy = Atmosphere.MOON_ENERGY
	moon.light_color = Atmosphere.MOON_COLOR
	moon.light_volumetric_fog_energy = Atmosphere.MOON_FOG
	if fill != null and is_instance_valid(fill):
		fill.light_energy = Atmosphere.FILL_ENERGY
	Reg.gain_mul = 1.0
