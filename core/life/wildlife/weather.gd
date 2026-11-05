extends Node3D
## Weather fronts over the Realm (life system). A slow cycle of fronts (clear, mist, gusts, drizzle,
## a storm), each 100-190 s, easing into the next over ~25 s:
##   mist     FogVolume banks this node owns roll with the wind and sink into the low ground (the
##            Hollow Fen, the Thornwood's hollows, the road plain)
##   drizzle  rain streaks round the camera (off under a roof), splashes on the ground round you,
##            rings on the pools (life_pond), damp fur and feathers; the rain bed changes with what it
##            falls on: leaves in the wood, open water in the fen, a roof over your head, open ground
##   wind     gusts carry leaves (forest), seed fluff (fen, meadow) or ash flakes (the rift) past you,
##            swell a wind bed and sway the Realm's grass and trees (its two foliage materials)
##   storm    lightning: most strikes close enough to see (a branching bolt, a lit cloud, the ground
##            light jumps) and thunder arriving after the flash by distance / 343 m/s, a sharp crack
##            when it is near, a long roll when it is far; far flashes flicker behind the Crowns
## The Environment and the foliage are only nudged by temporary offsets that ease back to nothing:
## fog and volumetric density (mist, rain), ambient energy (a flash, a rift surge: `pulse()`), and
## the foliage's sway/flutter (wind). Applied as deltas, so the base values (`base`) come back
## exactly and other systems' changes are kept. Glow and the grade are never touched. Sky effects
## draw in the sky layer (sky_fx shaders: behind everything, past the 82 m far plane).
## Fronts are deterministic per session seed; `force()` / `speed` are for tests.

signal thundered(at: Vector3)

const RL := preload("res://core/world/realm/realm_land.gd")
const LifeSynth := preload("res://core/life/wildlife/life_synth.gd")
const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const BOLT_SH := preload("res://core/life/wildlife/bolt.gdshader")
const FLASH_SH := preload("res://core/life/wildlife/sky_flash.gdshader")
const VEIL_SH := preload("res://core/life/wildlife/storm_veil.gdshader")
const LEAF_MAT := "res://art/materials/realm_foliage.tres"
const GROUND_MAT := "res://art/materials/realm_foliage_ground.tres"

const FRONTS := {
	"clear": {"mist": 0.0, "rain": 0.0, "wind": 0.2, "thunder": 0.0},
	"mist": {"mist": 1.0, "rain": 0.0, "wind": 0.08, "thunder": 0.0},
	"gusts": {"mist": 0.0, "rain": 0.0, "wind": 1.0, "thunder": 0.0},
	"drizzle": {"mist": 0.45, "rain": 1.0, "wind": 0.35, "thunder": 0.0},
	"storm": {"mist": 0.25, "rain": 0.9, "wind": 0.9, "thunder": 1.0},
}
const CYCLE := ["clear", "mist", "clear", "gusts", "drizzle", "storm", "clear", "mist", "drizzle", "clear", "gusts", "storm"]
const EASE_S := 25.0
## Environment offsets at full strength (added on top of whatever the base is)
const OFF_FOG_MIST := 0.0016
const OFF_FOG_RAIN := 0.0012
const OFF_VOL_MIST := 0.004
const OFF_VOL_RAIN := 0.002
const OFF_AMBIENT_FLASH := 0.32
const MIST_REGIONS := [Rect2(42, -78, 66, 110), Rect2(-108, -68, 76, 110), Rect2(-100, 48, 200, 26),
	# r34 flora: the new low ground: Corvin's Mere, the Waiting Field, the Cinder Orchard (ash haze),
	# the Lanternless Moor's hollows, the west wood round the Rooted Holds
	Rect2(64, 90, 86, 62), Rect2(-44, 98, 86, 58), Rect2(-150, 90, 82, 62), Rect2(124, -66, 31, 106), Rect2(-150, -40, 40, 80)]
const MIST_BANKS := [4, 3, 3, 3, 2, 2, 2, 2]
const SOUND_MS := 343.0          ## the speed of sound, m/s
const SKY_R := 60.0              ## sky-layer effects are built at this radius round the camera
const SPLASH_GRID := 20
## rain bed tops (dB). r29: +7..10.5 (a storm measured only 1.6 LU over a clear night)
const RAIN_TOPS := {"rain_open": -10.5, "rain_leaves": -12.0, "rain_roof": -9.5, "rain_water": -13.0}
const SPLASH_SPAN := 24.0

var state := {"mist": 0.0, "rain": 0.0, "wind": 0.2, "thunder": 0.0}
var front := "clear"
var speed := 1.0                ## time multiplier (tests)
var gust := 0.0                 ## wind with its gusts, 0..1+
var wind_dir := Vector3(0.8, 0.0, 0.6).normalized()
var flash := 0.0
var outdoor := 1.0
var base := {}                  ## the Environment values read at start
var flashes := 0
var strikes := 0                ## near strikes (bolts) so far
var last_strike := {}           ## {at, dist, delay, t_flash, t_sound (s, -1 until heard), near}
var rain_mix := {}              ## rain bed -> gain (tests)
var surface := "open"           ## what the rain falls on round the camera: open, leaves, water, roof
var sway_k := 1.0               ## foliage sway multiplier applied now
var splash_on := false
var off := false                ## --scape-off: r23 weather only (perf A/B)

var _env: Environment
var _rng := RandomNumberGenerator.new()
var _cycle_i := 0
var _front_t := 80.0
var _t := 0.0
var _applied := {"fog_density": 0.0, "volumetric_fog_density": 0.0, "ambient_light_energy": 0.0}
var _bank_acc := 0.0
var _step_acc := 0.0
var _bed_acc := 0.0
var _rain_dir := Vector3.ZERO
var _debris_dir := Vector3.ZERO
var _veil_sent := Vector2(-1.0, -1.0)
var _pulse := 0.0               ## ambient offset others ask for (rift surge), eased by them
var _rain: GPUParticles3D
var _splash: GPUParticles3D
var _splash_img: Image
var _splash_tex: ImageTexture
var _splash_at := Vector3.INF
var _splash_job := -1
var _splash_c := Vector3.ZERO
var _debris: GPUParticles3D
var _debris_mat: StandardMaterial3D
var _banks: Array[Dictionary] = []
var _sky_flash: MeshInstance3D
var _flash_mat: ShaderMaterial
var _flash_t := -1.0
var _flash_gain := 1.0
var _veil: MeshInstance3D       ## r29: rain clouds over the sky (storm_veil.gdshader)
var _veil_mat: ShaderMaterial
var _veil_k := 0.0
var _veil_drift := Vector2.ZERO
var _bolt: MeshInstance3D
var _bolt_mat: ShaderMaterial
var _thunder_t := 25.0
var _rumble_t := -1.0
var _rumble_at := Vector3.ZERO
var _rumble_near := false
var _rumble_dist := 0.0
var _rumble_emit := false
var _beds := {}                 ## rain_open, rain_leaves, rain_roof, rain_water, wind -> AudioStreamPlayer
var _rumble: AudioStreamPlayer3D
var _cover_t := 0.0
var _biome_t := 0.0
var _foliage: Array[Dictionary] = []    ## {mat, sway, flutter}
var _sway_t := 0.0


func setup(root: Node, seed_v: int) -> void:
	name = "Weather"
	_rng.seed = seed_v
	off = "--scape-off" in OS.get_cmdline_user_args()
	_cycle_i = 0
	_front_t = _rng.randf_range(60.0, 100.0)
	var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null:
		_env = we.environment
	if _env != null:
		for k: String in _applied:
			base[k] = float(_env.get(k))
	_build_rain()
	_build_splash()
	_build_debris()
	_build_banks()
	_build_flash()
	_build_bolt()
	_beds["rain_open"] = _bed(LifeSynth.stream("rain"))
	if not off:
		_beds["rain_leaves"] = _bed(ScapeSynth.stream("rain_leaves"))
		_beds["rain_roof"] = _bed(ScapeSynth.stream("rain_roof"))
		_beds["rain_water"] = _bed(ScapeSynth.stream("rain_water"))
		_grab_foliage()
	_beds["wind"] = _bed(LifeSynth.stream("wind"))
	_rumble = AudioStreamPlayer3D.new()
	_rumble.name = "Thunder"
	_rumble.stream = LifeSynth.stream("thunder")
	_rumble.bus = _out_bus()
	_rumble.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_rumble.panning_strength = 0.6
	_rumble.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(_rumble)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--life-weather="):          # renders / debugging: start in a given front
			force(a.trim_prefix("--life-weather="), true)


static func _out_bus() -> StringName:
	return &"AmbOut" if AudioServer.get_bus_index("AmbOut") >= 0 else &"Ambience"


## Jump to a front (tests, debug). instant = no easing.
func force(id: String, instant := false) -> void:
	front = id
	_front_t = 150.0
	if instant:
		for k: String in FRONTS[id]:
			state[k] = float(FRONTS[id][k])
		_veil_k = clampf(float(state.rain) * 0.85 + float(state.thunder) * 0.25 + float(state.mist) * 0.15, 0.0, 1.0)


func env_offsets() -> Dictionary:
	return _applied.duplicate()


## Another system's temporary ambient-light offset (the rift surge): 0 .. ~0.15, set every frame
## it changes and back to 0 when done. Added to the flash offset; removed exactly like the others.
func pulse(v: float) -> void:
	_pulse = v


var perf_us := 0.0
var _perf_acc := 0.0
var _perf_n := 0


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	# r29: ~40 steps a second is plenty for fronts, wind, rain and the beds; a lightning flash's
	# flicker and a splash grid being laid run every frame
	_step_acc += delta
	if _step_acc >= 1.0 / 40.0 or _flash_t >= 0.0 or _splash_job >= 0 or _rumble_t >= 0.0:
		_step(_step_acc)
		_step_acc = 0.0
	_perf_acc += float(Time.get_ticks_usec() - t0)
	_perf_n += 1
	if _perf_n >= 120:
		perf_us = _perf_acc / float(_perf_n)
		_perf_acc = 0.0
		_perf_n = 0


func _step(delta: float) -> void:
	var dt := delta * speed
	_t += dt
	_front_t -= dt
	if _front_t <= 0.0:
		_cycle_i = (_cycle_i + 1) % CYCLE.size()
		front = CYCLE[_cycle_i]
		_front_t = _rng.randf_range(100.0, 190.0)
	var want: Dictionary = FRONTS[front]
	for k: String in state:
		state[k] = move_toward(float(state[k]), float(want[k]), dt / EASE_S)
	# the wind veers slowly and gusts
	wind_dir = wind_dir.rotated(Vector3.UP, sin(_t * 0.013) * dt * 0.01).normalized()
	gust = float(state.wind) * (0.55 + 0.45 * maxf(0.0, sin(_t * 0.41) * sin(_t * 0.137 + 1.0)) * 1.6)
	Sway.wind = gust                     # r36: lanterns, hooks and bells swing with it
	_thunder(dt, delta)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_follow(cam, dt)
	# slow things at a slow rate (r29): the banks drift ~1 m/s (a fog volume's froxels hide 10 Hz
	# steps), bed levels ease over seconds; the Environment offsets go out when they have moved
	# enough to matter, the flash's every frame
	_bank_acc += dt
	if _bank_acc >= 0.1:
		_banks_step(_bank_acc)
		_bank_acc = 0.0
	_apply_env()
	_bed_acc += delta
	if _bed_acc >= 1.0 / 15.0:
		_beds_step(_bed_acc)
		_bed_acc = 0.0
	_sway(delta)


func _apply_env() -> void:
	if _env == null:
		return
	var mist := float(state.mist)
	var rain := float(state.rain)
	_env_offset("fog_density", mist * OFF_FOG_MIST + rain * OFF_FOG_RAIN, 0.000008)
	_env_offset("volumetric_fog_density", mist * OFF_VOL_MIST + rain * OFF_VOL_RAIN, 0.00002)
	_env_offset("ambient_light_energy", flash * OFF_AMBIENT_FLASH * _flash_gain + _pulse, 0.0)


## Move one Environment offset to `want` once it is more than `eps` away (exactly to 0 at the end).
func _env_offset(k: String, want: float, eps: float) -> void:
	var cur := float(_applied[k])
	var d := want - cur
	if d == 0.0 or (absf(d) <= eps and want != 0.0):
		return
	_env.set(k, float(_env.get(k)) + d)
	_applied[k] = want


func _exit_tree() -> void:
	# leave the Environment and the foliage exactly as we found them
	if _env != null:
		for k: String in _applied:
			_env.set(k, float(_env.get(k)) - float(_applied[k]))
			_applied[k] = 0.0
	for f in _foliage:
		var m: ShaderMaterial = f.mat
		m.set_shader_parameter("sway", f.sway)
		m.set_shader_parameter("flutter", f.flutter)
	sway_k = 1.0


# --- rain -----------------------------------------------------------------------------------------

func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "DrizzleStreaks"
	_rain.amount = 1600
	_rain.lifetime = 1.3
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-24, -24, -24), Vector3(48, 40, 48))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.amount_ratio = 0.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(17, 0.5, 17)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 12.5
	pm.gravity = Vector3(0, -3, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	_rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.62, 0.74, 0.92, 0.2)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	q.material = m
	_rain.draw_pass_1 = q
	add_child(_rain)


## Splashes where the rain lands: tiny crowns that flick up and spread, emitted from points laid on
## the ground round the camera (a 20 x 20 jittered grid on RealmLand's heights, re-laid a slice per
## frame when the camera has moved 4 m; on water at the waterline).
func _build_splash() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "RainSplash"
	_splash.amount = 420
	_splash.lifetime = 0.28
	_splash.local_coords = false
	_splash.visibility_aabb = AABB(Vector3(-16, -8, -16), Vector3(32, 16, 32))
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_splash.amount_ratio = 0.0
	_splash.emitting = false
	_splash_img = Image.create(SPLASH_GRID * SPLASH_GRID, 1, false, Image.FORMAT_RGBF)
	_splash_tex = ImageTexture.create_from_image(_splash_img)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = _splash_tex
	pm.emission_point_count = SPLASH_GRID * SPLASH_GRID
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, -2, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1.0, 1.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_splash.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.07)
	q.center_offset = Vector3(0, 0.03, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.66, 0.76, 0.92, 0.42)
	m.albedo_texture = _crown_tex()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	q.material = m
	_splash.draw_pass_1 = q
	add_child(_splash)


## A splash crown: a bright rim with droplet spikes over a soft disc (32 x 16, RGBA).
static func _crown_tex() -> ImageTexture:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 32:
			var u := (float(x) - 15.5) / 15.5
			var v := 1.0 - float(y) / 15.0                       # 0 at the bottom (ground) .. 1 top
			var bowl := absf(u)
			var rim := exp(-pow((v - (0.15 + 0.6 * bowl * bowl)) * 7.0, 2.0)) * smoothstep(1.0, 0.7, bowl)
			var spikes := pow(maxf(0.0, cos(u * 9.0)), 6.0) * smoothstep(0.2, 0.6, v) * smoothstep(1.0, 0.75, v) * smoothstep(1.0, 0.4, bowl)
			var a := clampf(rim + spikes * 0.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _splash_step(cam_p: Vector3, fwd: Vector3, rr: float) -> void:
	var want := rr > 0.02 and not off
	if not want:
		if _splash.emitting:
			_splash.emitting = false
			_splash.amount_ratio = 0.0
		splash_on = false
		return
	var c := cam_p + fwd * 5.0
	if _splash_job < 0 and (_splash_at == Vector3.INF or Vector2(c.x - _splash_at.x, c.z - _splash_at.z).length() > 4.0):
		_splash_job = 0
		_splash_c = Vector3(snappedf(c.x, 0.5), 0.0, snappedf(c.z, 0.5))
	if _splash_job >= 0:
		# lay a slice of the grid per frame (100 points); swap it in when the last slice is done
		var n := SPLASH_GRID * SPLASH_GRID
		var r := RandomNumberGenerator.new()
		var step := SPLASH_SPAN / float(SPLASH_GRID)
		var end := mini(_splash_job + 100, n)
		for i in range(_splash_job, end):
			r.seed = i * 7919 + 13
			var gx := float(i % SPLASH_GRID) - float(SPLASH_GRID) * 0.5 + r.randf()
			var gz := float(i / SPLASH_GRID) - float(SPLASH_GRID) * 0.5 + r.randf()
			var x := _splash_c.x + gx * step
			var z := _splash_c.z + gz * step
			var y := RL.height_at(x, z)
			if RL.in_water(x, z):
				y = RL.WATER_Y
			_splash_img.set_pixel(i, 0, Color(x - _splash_c.x, y + 0.02, z - _splash_c.z))
		_splash_job = end
		if _splash_job >= n:
			_splash_job = -1
			_splash_at = _splash_c
			_splash_tex.update(_splash_img)
			_splash.global_position = Vector3(_splash_c.x, 0.0, _splash_c.z)
	if _splash_at == Vector3.INF:
		return
	_splash.amount_ratio = rr
	_splash.emitting = true
	splash_on = true


# --- wind-borne leaves, seed fluff and ash --------------------------------------------------------

func _build_debris() -> void:
	_debris = GPUParticles3D.new()
	_debris.name = "WindDebris"
	_debris.amount = 90
	_debris.lifetime = 4.5
	_debris.local_coords = false
	_debris.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 25, 60))
	_debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debris.amount_ratio = 0.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 3, 14)
	pm.direction = Vector3(1, 0.15, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -0.5, 0)
	pm.angular_velocity_min = -280.0
	pm.angular_velocity_max = 280.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.6
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.2
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	_debris.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.075, 0.05)
	_debris_mat = StandardMaterial3D.new()
	_debris_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_debris_mat.alpha_scissor_threshold = 0.5
	_debris_mat.albedo_texture = _leaf_tex()
	_debris_mat.albedo_color = Color(0.42, 0.3, 0.17)
	_debris_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_debris_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_debris_mat.roughness = 0.9
	q.material = _debris_mat
	_debris.draw_pass_1 = q
	add_child(_debris)


static func _leaf_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var u := (float(x) - 15.5) / 15.5
			var v := (float(y) - 15.5) / 15.5
			var inside := u * u + v * v * 2.6 * (1.0 + 0.4 * u) < 0.85
			var vein := 1.0 - 0.3 * exp(-v * v * 60.0)
			var g := (0.8 + 0.2 * sin(u * 9.0)) * vein
			img.set_pixel(x, y, Color(g, g, g, 1.0 if inside else 0.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- the foliage in the wind -----------------------------------------------------------------------

## The Realm's grass and tree crowns share two materials; the wind's gusts scale their sway and
## flutter (amplitudes only: the shader's phase and wave are untouched, so nothing jumps).
func _grab_foliage() -> void:
	for path: String in [LEAF_MAT, GROUND_MAT]:
		if not ResourceLoader.exists(path):
			continue
		var m := load(path) as ShaderMaterial
		if m == null:
			continue
		var s: Variant = m.get_shader_parameter("sway")
		var f: Variant = m.get_shader_parameter("flutter")
		if s == null or f == null:
			continue
		_foliage.append({"mat": m, "sway": float(s), "flutter": float(f), "set": 1.0})


func _sway(dt: float) -> void:
	if _foliage.is_empty():
		return
	_sway_t -= dt
	if _sway_t > 0.0:
		return
	_sway_t = 0.1
	# calm air (the clear front's 0.2) is the material's own look; gusts up to ~2.3x, a still night 0.7x
	var k := clampf(1.0 + (gust - 0.2) * 1.5, 0.7, 2.3)
	if absf(k - sway_k) < 0.01:
		return
	sway_k = k
	for f in _foliage:
		var m: ShaderMaterial = f.mat
		m.set_shader_parameter("sway", float(f.sway) * k)
		m.set_shader_parameter("flutter", float(f.flutter) * sqrt(k))


# --- mist banks -------------------------------------------------------------------------------------

func _build_banks() -> void:
	for ri in MIST_REGIONS.size():
		if off and ri >= 2:
			break
		var r: Rect2 = MIST_REGIONS[ri]
		for k in MIST_BANKS[ri]:
			var fv := FogVolume.new()
			fv.name = "MistBank%d" % _banks.size()
			fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
			fv.size = Vector3(_rng.randf_range(30, 44), 6.0, _rng.randf_range(30, 44))
			var fm := FogMaterial.new()
			fm.density = 0.0
			fm.albedo = Color(0.6, 0.68, 0.84)
			fm.emission = Color(0.02, 0.035, 0.07)
			fm.edge_fade = 0.75
			fm.height_falloff = 0.12
			fv.material = fm
			# r29: each bank keeps a home hollow (the lowest of a few spots, away from the others):
			# mist that only drifted with the wind piled up along the region's edges and left the
			# fen itself clear (a probe found 3 of the fen's 4 banks on its west edge)
			var home := _bank_home(r)
			fv.position = Vector3(home.x, RL.height_at(home.x, home.y) + 1.6, home.y)
			fv.visible = false
			add_child(fv)
			_banks.append({"node": fv, "mat": fm, "rect": r, "home": home, "phase": _rng.randf_range(0, TAU), "dens": _rng.randf_range(0.055, 0.085) * (0.7 if ri == 2 else 1.0)})   # r29: x1.55 (renders barely showed a bank)


## A low spot in r (the lowest of 14 samples) at least 22 m from the region's other bank homes.
func _bank_home(r: Rect2) -> Vector2:
	var inner := r.grow(-6.0)
	var best := inner.get_center()
	var best_h := INF
	for k in 14:
		var q := Vector2(_rng.randf_range(inner.position.x, inner.end.x), _rng.randf_range(inner.position.y, inner.end.y))
		var ok := true
		for b in _banks:
			if b.rect == r and (b.home as Vector2).distance_to(q) < 22.0:
				ok = false
				break
		var h := RL.height_at(q.x, q.y) + (0.0 if ok else 100.0)
		if h < best_h:
			best_h = h
			best = q
	return best


func _banks_step(dt: float) -> void:
	var m := float(state.mist)
	for b in _banks:
		var fv: FogVolume = b.node
		fv.visible = m > 0.01
		if not fv.visible:
			continue
		var r: Rect2 = b.rect
		var p := fv.position
		# fog runs downhill like water: drift toward the lower ground as well as with the wind
		var gx := RL.height_at(p.x + 4.0, p.z) - RL.height_at(p.x - 4.0, p.z)
		var gz := RL.height_at(p.x, p.z + 4.0) - RL.height_at(p.x, p.z - 4.0)
		var down := Vector3(-gx, 0.0, -gz) * 0.125
		if down.length() > 1.0:
			down = down.normalized()
		# ...and keeps to its hollow: a soft pull home (it settles ~10-20 m downwind of it and
		# sways as the gusts come and go, instead of piling against the region's edge)
		var home: Vector2 = b.home
		var pull := Vector3(home.x - p.x, 0.0, home.y - p.z) * 0.06
		p += (wind_dir * (0.5 + gust * 1.2) + down * 0.7 + pull) * dt
		if not r.has_point(Vector2(p.x, p.z)):
			# rolled out of its region: comes in again from the upwind side
			p = Vector3(p.x - wind_dir.x * r.size.x * 0.9, p.y, p.z - wind_dir.z * r.size.y * 0.9)
			p.x = clampf(p.x, r.position.x, r.end.x)
			p.z = clampf(p.z, r.position.y, r.end.y)
		# it settles low in hollows and thins over rises
		var h := RL.height_at(p.x, p.z)
		p.y = lerpf(p.y, h + 1.3, clampf(dt * 0.3, 0.0, 1.0))
		fv.position = p
		var rise := clampf((h - float(b.get("h0", h))) * 0.08, -0.3, 0.4)
		if not b.has("h0"):
			b.h0 = h
		(b.mat as FogMaterial).density = float(b.dens) * m * (0.75 + 0.25 * sin(_t * 0.05 + float(b.phase))) * (1.0 - rise)


func bank_count() -> int:
	return _banks.size()


# --- lightning ----------------------------------------------------------------------------------------

func _build_flash() -> void:
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SH
	var n := FastNoiseLite.new()
	n.seed = 3
	n.frequency = 0.02
	n.fractal_octaves = 5
	var tex := ImageTexture.create_from_image(n.get_seamless_image(128, 128))
	_flash_mat.set_shader_parameter("cloud", tex)
	_sky_flash = MeshInstance3D.new()
	_sky_flash.name = "CloudFlash"
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_sky_flash.mesh = q
	_sky_flash.material_override = _flash_mat
	_sky_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky_flash.visible = false
	_sky_flash.extra_cull_margin = 16384.0
	add_child(_sky_flash)
	# the rain clouds: a sphere round the camera in the sky layer, drawn before the flash
	_veil_mat = ShaderMaterial.new()
	_veil_mat.shader = VEIL_SH
	_veil_mat.set_shader_parameter("cloud", tex)
	_veil_mat.render_priority = -1
	_veil = MeshInstance3D.new()
	_veil.name = "StormVeil"
	var sm := SphereMesh.new()
	sm.radius = SKY_R
	sm.height = SKY_R * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	_veil.mesh = sm
	_veil.material_override = _veil_mat
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_veil.extra_cull_margin = 16384.0
	_veil.visible = false
	add_child(_veil)


func _build_bolt() -> void:
	_bolt_mat = ShaderMaterial.new()
	_bolt_mat.shader = BOLT_SH
	_bolt = MeshInstance3D.new()
	_bolt.name = "LightningBolt"
	_bolt.material_override = _bolt_mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	_bolt.extra_cull_margin = 16384.0
	add_child(_bolt)


func _thunder(dt: float, real_dt: float) -> void:
	if float(state.thunder) > 0.3:
		_thunder_t -= dt
		if _thunder_t <= 0.0:
			_thunder_t = _rng.randf_range(9.0, 26.0) / float(state.thunder)
			if off or _rng.randf() < 0.3:
				strike()
			else:
				strike_near()
	if _flash_t >= 0.0:
		_flash_t += real_dt
		# a flicker: on, off, a second return stroke, a dying glow
		var f := 0.0
		if _flash_t < 0.06:
			f = 1.0
		elif _flash_t < 0.12:
			f = 0.12
		elif _flash_t < 0.2:
			f = 0.85
		elif _flash_t < 0.9:
			f = 0.85 * exp(-(_flash_t - 0.2) * 5.0)
		else:
			_flash_t = -1.0
			_sky_flash.visible = false
			_bolt.visible = false
		flash = f
		_flash_mat.set_shader_parameter("flash", f)
		_bolt_mat.set_shader_parameter("flash", f if _flash_t < 0.45 else 0.0)
	else:
		flash = 0.0
	if _rumble_t >= 0.0:
		_rumble_t -= dt
		if _rumble_t < 0.0:
			_play_thunder()


## A flash somewhere behind the Crowns (far: no bolt in view, a lit cloud, a long rumble a few
## seconds later). Startles the birds at once (the old behaviour tests rely on).
func strike() -> void:
	flashes += 1
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cp := cam.global_position if cam != null else Vector3.ZERO
	var x := _rng.randf_range(-120.0, 120.0)
	var at := Vector3(x, _rng.randf_range(75.0, 105.0), -260.0)
	_cloud_flash(cp, at, 1.6)
	_flash_gain = 1.0
	_flash_t = 0.0
	_rumble_at = at
	_rumble_dist = at.distance_to(cp)
	_rumble_near = false
	_rumble_emit = false
	_rumble_t = _rng.randf_range(1.8, 4.5) / maxf(speed, 1.0)
	last_strike = {"at": at, "dist": _rumble_dist, "delay": _rumble_t, "t_flash": Time.get_ticks_msec(), "t_sound": -1, "near": false}
	thundered.emit(at)


## A bolt you can see: `dist` metres away (default 180-1400) in direction `yaw` (default: mostly in
## front of the camera). Thunder arrives dist / 343 s later; animals react to the sound.
func strike_near(dist := -1.0, yaw := INF) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	flashes += 1
	strikes += 1
	var cp := cam.global_position
	if dist <= 0.0:
		dist = lerpf(180.0, 1400.0, pow(_rng.randf(), 1.3))
	if yaw == INF:
		var f := -cam.global_basis.z
		yaw = atan2(f.x, f.z) + _rng.randf_range(-1.0, 1.0) * (1.1 if _rng.randf() < 0.7 else PI)
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	var at := cp + dir * dist
	var ob := RealmLayout.OUTER.grow(-1.0)        # r34 layout: was the r33 OUTER's numbers
	at.y = RL.height_at(clampf(at.x, ob.position.x, ob.end.x), clampf(at.z, ob.position.y, ob.end.y)) if RealmLayout.OUTER.has_point(Vector2(at.x, at.z)) else cp.y - 4.0
	var top := Vector3(at.x, at.y + _rng.randf_range(420.0, 650.0), at.z)
	_build_bolt_mesh(cp, at, top, dist)
	_cloud_flash(cp, top, 2.4)
	_flash_gain = clampf(260.0 / dist, 0.3, 1.25)
	_flash_t = 0.0
	_rumble_at = at
	_rumble_dist = dist
	_rumble_near = dist < 650.0
	_rumble_emit = true
	_rumble_t = dist / SOUND_MS / maxf(speed, 1.0)
	last_strike = {"at": at, "dist": dist, "delay": _rumble_t, "t_flash": Time.get_ticks_msec(), "t_sound": -1, "near": true}


func _play_thunder() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cp := cam.global_position if cam != null else Vector3.ZERO
	var dir := (_rumble_at - cp)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	_rumble.global_position = cp + dir * 25.0 + Vector3(0, 6, 0)
	if _rumble_near:
		_rumble.stream = ScapeSynth.stream("crack")
		_rumble.pitch_scale = _rng.randf_range(0.92, 1.05)
		_rumble.volume_db = lerpf(-1.0, -7.0, clampf((_rumble_dist - 180.0) / 470.0, 0.0, 1.0))
	else:
		_rumble.stream = LifeSynth.stream("thunder")
		_rumble.pitch_scale = _rng.randf_range(0.8, 1.02) * lerpf(1.0, 0.85, clampf((_rumble_dist - 650.0) / 800.0, 0.0, 1.0))
		_rumble.volume_db = lerpf(-7.0, -13.0, clampf((_rumble_dist - 650.0) / 800.0, 0.0, 1.0))
	_rumble.play()
	last_strike["t_sound"] = Time.get_ticks_msec()
	if _rumble_emit:
		thundered.emit(_rumble_at)


## Place the cloud flash in the sky layer, over `at` as seen from cp.
func _cloud_flash(cp: Vector3, at: Vector3, size_k: float) -> void:
	var d := (at - cp)
	var dist := d.length()
	var dn := d / maxf(dist, 0.001)
	_sky_flash.global_position = cp + dn * SKY_R
	var s := SKY_R * size_k * clampf(300.0 / maxf(dist, 1.0), 0.35, 1.2)
	_sky_flash.global_basis = Basis.looking_at(-dn, Vector3.UP if absf(dn.y) < 0.95 else Vector3.FORWARD).scaled(Vector3(s, s * 0.55, 1.0))
	_flash_mat.set_shader_parameter("at", Vector2(_rng.randf_range(0.4, 0.6), _rng.randf_range(0.35, 0.6)))
	_sky_flash.visible = true


## A branching bolt from cloud to ground, built as camera-facing ribbons in world space, then pulled
## in toward the camera to SKY_R (the same directions, so it looks the same) and drawn in the sky layer.
func _build_bolt_mesh(cp: Vector3, ground: Vector3, top: Vector3, dist: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = _rng.randi()
	var k := SKY_R / dist
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var main := _bolt_path(r, top, ground, 26, 0.09)
	_ribbon(st, cp, main, k, 9.0, 1.0)
	for b in r.randi_range(2, 4):
		var i := r.randi_range(4, main.size() - 8)
		var from: Vector3 = main[i]
		var side := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized()
		var ln := (top.y - ground.y) * r.randf_range(0.15, 0.35)
		var to := from + side * ln * 0.8 + Vector3(0, -ln, 0)
		_ribbon(st, cp, _bolt_path(r, from, to, 10, 0.12), k, 5.0, 0.55)
	_bolt.mesh = st.commit()
	_bolt.global_transform = Transform3D(Basis.IDENTITY, cp)
	_bolt.visible = true


func _bolt_path(r: RandomNumberGenerator, a: Vector3, b: Vector3, n: int, jag: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var ln := a.distance_to(b)
	var o := Vector3.ZERO
	for i in n + 1:
		var t := float(i) / float(n)
		if i > 0 and i < n:
			o += Vector3(r.randf_range(-1, 1), r.randf_range(-0.3, 0.3), r.randf_range(-1, 1)) * ln * jag / sqrt(float(n))
			o *= 0.85
		out.append(a.lerp(b, t) + (o if i < n else Vector3.ZERO))
	return out


## Camera-facing ribbon through world points; vertices relative to cp, scaled by k (UV.x 0..1 across,
## UV.y 0 top .. 1 bottom, COLOR.a = strength).
func _ribbon(st: SurfaceTool, cp: Vector3, pts: PackedVector3Array, k: float, width: float, strength: float) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var along := (b - a).normalized()
		var view := ((a + b) * 0.5 - cp).normalized()
		var side := along.cross(view).normalized() * width * 0.5
		var va := [(a - side - cp) * k, (a + side - cp) * k, (b + side - cp) * k, (b - side - cp) * k]
		var ty := float(i) / float(pts.size() - 1)
		var ty2 := float(i + 1) / float(pts.size() - 1)
		var uvs := [Vector2(0, ty), Vector2(1, ty), Vector2(1, ty2), Vector2(0, ty2)]
		var col := Color(1, 1, 1, strength)
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_uv(uvs[idx])
			st.add_vertex(va[idx])


# --- loading-screen warm-up ---------------------------------------------------------------------------

var _warm := {}


## Show every effect this node owns at `at` (in front of the warm-up camera) so its shaders and
## particle processes compile under the loading screen; warm(false) puts everything back.
func warm(on: bool, at := Vector3.ZERO) -> void:
	if on:
		_warm = {"rain": _rain.amount_ratio, "splash": _splash.amount_ratio, "debris": _debris.amount_ratio}
		for p: GPUParticles3D in [_rain, _splash, _debris]:
			p.global_position = at
			p.amount_ratio = 1.0
			p.emitting = true
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_ribbon(st, at - Vector3(0, 0, 10), PackedVector3Array([at + Vector3(0, 2, 0), at]), 1.0, 0.2, 1.0)
		_bolt.mesh = st.commit()
		_bolt.global_transform = Transform3D(Basis.IDENTITY, at - Vector3(0, 0, 10))
		_bolt.visible = true
		_sky_flash.global_position = at
		_sky_flash.visible = true
		_warm["veil"] = true
		_veil.global_position = at
		_veil_mat.set_shader_parameter("cover", 0.5)
		_veil.visible = true
		for b in _banks:
			(b.node as FogVolume).visible = true
	else:
		_rain.amount_ratio = float(_warm.get("rain", 0.0))
		_splash.amount_ratio = float(_warm.get("splash", 0.0))
		_debris.amount_ratio = float(_warm.get("debris", 0.0))
		for p: GPUParticles3D in [_rain, _splash, _debris]:
			p.emitting = p.amount_ratio > 0.01
		_splash_at = Vector3.INF
		_bolt.visible = false
		_sky_flash.visible = false
		_warm.erase("veil")
		_veil.visible = _veil_k > 0.01
		_veil_mat.set_shader_parameter("cover", _veil_k)
		for b in _banks:
			(b.node as FogVolume).visible = float(state.mist) > 0.01


# --- following the camera ---------------------------------------------------------------------------

func _follow(cam: Camera3D, dt: float) -> void:
	var cp := cam.global_position
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	_cover_t -= dt
	if _cover_t <= 0.0:
		_cover_t = 0.4
		var covered := false
		var sp := get_world_3d().direct_space_state
		if sp != null:
			var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(cp, cp + Vector3(0, 30, 0), 1))
			covered = not hit.is_empty()
		outdoor = 0.0 if covered else 1.0
	_veil_step(cp, dt)
	_rain.global_position = cp + fwd * 7.0 + Vector3(0, 10, 0)
	var rr := float(state.rain) * outdoor
	if _rain.amount_ratio != rr:
		_rain.amount_ratio = rr
	if _rain.emitting != (rr > 0.01):
		_rain.emitting = rr > 0.01
	# a material write is a material update: only while there is rain to steer, and only once the
	# slant has changed enough to see
	if _rain.emitting:
		var rd := Vector3(wind_dir.x * gust * 0.25, -1, wind_dir.z * gust * 0.25)
		if rd.distance_squared_to(_rain_dir) > 0.0004:
			_rain_dir = rd
			(_rain.process_material as ParticleProcessMaterial).direction = rd
	_splash_step(cp, fwd, rr)
	_debris.global_position = cp + fwd * 6.0 - wind_dir * 8.0 + Vector3(0, 1.5, 0)
	var dr := clampf((gust - 0.35) * 1.4, 0.0, 1.0) * outdoor
	if _debris.amount_ratio != dr:
		_debris.amount_ratio = dr
	if _debris.emitting != (dr > 0.01):
		_debris.emitting = dr > 0.01
	if _debris.emitting:
		var dd := Vector3(wind_dir.x, 0.15, wind_dir.z)
		if dd.distance_squared_to(_debris_dir) > 0.0004:
			_debris_dir = dd
			(_debris.process_material as ParticleProcessMaterial).direction = dd
	_biome_t -= dt
	if _biome_t <= 0.0:
		_biome_t = 1.0
		var biome := RealmLayout.biome_at(cp.x, cp.z)
		match biome:
			"oldforest", "glade": _debris_mat.albedo_color = Color(0.42, 0.3, 0.16)
			"ash", "crag": _debris_mat.albedo_color = Color(0.32, 0.31, 0.31)
			"fen": _debris_mat.albedo_color = Color(0.72, 0.7, 0.62)
			_: _debris_mat.albedo_color = Color(0.45, 0.42, 0.25)
		var amb := get_node_or_null("../../Ambience")
		var crypt := amb != null and String(amb.get("reverb_zone")) == "ossuary"
		if crypt:
			surface = "under"                  # deep in the Ossuary: no rain on any roof you could hear
		elif outdoor < 0.5:
			surface = "roof"
		elif biome in ["oldforest", "glade"]:
			surface = "leaves"
		elif biome == "fen":
			surface = "water"
		else:
			surface = "open"


## The cloud deck thickens with the rain (and a storm's thunder), drifts with the wind and is lit
## from within by the flashes. A temporary effect like the others: hidden when the sky is clear.
func _veil_step(cp: Vector3, dt: float) -> void:
	if _veil == null or off:
		return
	var want := clampf(float(state.rain) * 0.85 + float(state.thunder) * 0.25 + float(state.mist) * 0.15, 0.0, 1.0)
	_veil_k = move_toward(_veil_k, want, dt / 6.0)
	var on := _veil_k > 0.01
	if _veil.visible != on and not _warm.has("veil"):
		_veil.visible = on
	if not on:
		return
	_veil.global_position = cp
	_veil_drift += Vector2(wind_dir.x, wind_dir.z) * (0.004 + gust * 0.006) * dt
	_veil_drift = Vector2(fposmod(_veil_drift.x, 64.0), fposmod(_veil_drift.y, 64.0))
	_veil_mat.set_shader_parameter("drift", _veil_drift)
	var cf := Vector2(snappedf(_veil_k, 0.004), flash * _flash_gain)
	if cf != _veil_sent:
		_veil_sent = cf
		_veil_mat.set_shader_parameter("cover", cf.x)
		_veil_mat.set_shader_parameter("flash", cf.y)


func _bed(s: AudioStream) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.bus = _out_bus()
	a.volume_db = -80.0
	add_child(a)
	return a


## The rain bed follows what the rain falls on (eased over ~2 s); the wind bed swells with gusts.
func _beds_step(dt: float) -> void:
	var rain := float(state.rain)
	var want := {"rain_open": 0.0, "rain_leaves": 0.0, "rain_roof": 0.0, "rain_water": 0.0}
	match surface:
		"roof":
			want.rain_roof = 1.0
		"leaves":
			want.rain_leaves = 0.85
			want.rain_open = 0.35
		"water":
			want.rain_water = 0.8
			want.rain_open = 0.5
		"under":
			pass
		_:
			want.rain_open = 1.0
	if off:
		want = {"rain_open": 0.35 + 0.65 * outdoor}
	# r29: +7..8 dB (a storm measured only 1.6 LU over a clear night: the rain was under the beds)
	var tops := RAIN_TOPS
	for k: String in want:
		if not _beds.has(k):
			continue
		var g := move_toward(float(rain_mix.get(k, 0.0)), float(want[k]), dt / 2.0)
		rain_mix[k] = g
		_level(_beds[k], float(tops[k]), g * rain, dt)
	_level(_beds["wind"], -15.0, clampf(gust, 0.0, 1.3) * 0.8 + 0.08, dt)
	(_beds["wind"] as AudioStreamPlayer).pitch_scale = 0.85 + 0.25 * clampf(gust, 0.0, 1.3)


static func _level(a: AudioStreamPlayer, top_db: float, g: float, _dt: float) -> void:
	if g < 0.02:
		if a.playing:
			a.stop()
		return
	a.volume_db = top_db + linear_to_db(clampf(g, 0.0001, 1.3))
	if not a.playing:
		a.play()
