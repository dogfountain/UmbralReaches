extends Node3D
## Night phenomena tied to the rift (life system r28). Owned by the director ("Phenomena"); each is
## rare and stays a temporary offset or its own nodes, never the lead's sky, grade or fog values.
##   meteor showers  in clear air every 6-12 min: 70-100 s of streaks running from a radiant in the
##                   north-west (meteor.gdshader: no script time), and once per shower a slow green-
##                   gold fireball whose boom arrives seconds later
##   rift surges     every 5-9 min the wound pulses: the sky's vortex flares (surge_sky.gdshader, an
##                   additive overlay built from the same spiral), a ring runs out from its eye, a deep
##                   swell rises from the chasm, the ground light lifts a little (Weather.pulse), the
##                   bats over the rift boil up and out, crows go up and the herds look toward it
##   will-o'-wisps   in the fen, the Thornwood, the barrows and round the chapel, when the wanderer is
##                   alone: a pale light appears ahead and leads, waiting when you fall behind, to
##                   something not yet found (a secret, an unlit brazier); it circles there and goes out
##   the white hart  very rarely, at the edge of the wood or the glade: a pale stag that watches you
##                   from 40 m, then turns and walks into the trees, leaving glowing hoofprints
## Timers are deterministic per session seed; `trigger()` starts any of them now (tests, debug).

const HEARTH_C := Vector2(6.0, 38.0)          ## Hearthward (RealmLayout region "hearth")
const HEARTH_CLEAR := 50.0
const RL := preload("res://core/world/realm/realm_land.gd")
const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const LifeGroup := preload("res://core/life/wildlife/life_group.gd")
const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const METEOR_SH := preload("res://core/life/wildlife/meteor.gdshader")
const SURGE_SH := preload("res://core/life/wildlife/surge_sky.gdshader")
const WISP_SH := preload("res://world/wisp.gdshader")
const SKY_R := 60.0
const RIFT_C := Vector3(0.0, -12.0, -62.0) + Endgame.O          # the chasm (the far north-east: Endgame)
const WISP_BIOMES := ["fen", "oldforest", "glade", "ruin"]

var director: Node3D
var weather: Node3D
var showers := 0
var bolides := 0
var surges := 0
var wisps := 0
var wisp_arrivals := 0
var harts := 0
var shower := 0.0               ## current shower strength 0..1
var surge := 0.0                ## current surge 0..1
var wisp_state := "idle"        ## idle, lead, wait, arrive, fade
var wisp_target := Vector3.INF
var hart_state := "idle"        ## idle, watch, leave
var quiet := false              ## tests: no timers fire by themselves

var _rng := RandomNumberGenerator.new()
var _meteors: MultiMeshInstance3D
var _meteor_mat: ShaderMaterial
var _bolide: MultiMeshInstance3D
var _bolide_mat: ShaderMaterial
var _bolide_t := -1.0
var _boom: AudioStreamPlayer
var _boom_t := -1.0
var _shower_t := 0.0
var _shower_left := 0.0
var _shower_bolide_at := -1.0
var _surge_sky: MeshInstance3D
var _surge_mat: ShaderMaterial
var _surge_t := -1.0
var _next_surge := 0.0
var _surge_snd: AudioStreamPlayer3D
var _wisp: Node3D
var _wisp_mesh: MeshInstance3D
var _wisp_motes: GPUParticles3D
var _wisp_hum: AudioStreamPlayer3D
var _chime: AudioStreamPlayer3D
var _wisp_t := 0.0
var _wisp_next := 0.0
var _wisp_k := 0.0
var _wisp_idle := 0.0
var _wisp_visited := {}
var _hart: MultiMeshInstance3D
var _hart_next := 0.0
var _hart_t := 0.0
var _hart_pos := Vector3.ZERO
var _hart_yaw := 0.0
var _hart_head := 0.0
var _hart_gait := 0.0
var _hart_fade := 0.0
var _hart_walked := 0.0
var _hart_foot := 0
var _check_t := 0.0
var _braziers: Array = []


func setup(dir: Node3D, wx: Node3D, seed_v: int) -> void:
	name = "Phenomena"
	director = dir
	weather = wx
	_rng.seed = seed_v
	_shower_t = _rng.randf_range(240.0, 480.0)
	_next_surge = _rng.randf_range(150.0, 320.0)
	_wisp_next = _rng.randf_range(45.0, 100.0)
	_hart_next = _rng.randf_range(300.0, 600.0)
	_build_meteors()
	_build_surge()
	_build_wisp()
	_build_hart()


# --- meteors ---------------------------------------------------------------------------------------

func _build_meteors() -> void:
	_meteor_mat = ShaderMaterial.new()
	_meteor_mat.shader = METEOR_SH
	_meteor_mat.set_shader_parameter("sky_r", SKY_R)
	_meteors = _sky_mm(36, _meteor_mat, "Meteors")
	for i in 36:
		_meteors.multimesh.set_instance_transform(i, Transform3D.IDENTITY)
		_meteors.multimesh.set_instance_custom_data(i, Color(_rng.randf_range(2.5, 6.5), _rng.randf_range(0.0, 30.0), float(i) * 1.37 + 0.5, _rng.randf_range(0.45, 1.0)))
	_bolide_mat = ShaderMaterial.new()
	_bolide_mat.shader = METEOR_SH
	_bolide_mat.set_shader_parameter("sky_r", SKY_R)
	_bolide_mat.set_shader_parameter("manual", 0.0)
	_bolide = _sky_mm(1, _bolide_mat, "Bolide")
	_bolide.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	_bolide.multimesh.set_instance_custom_data(0, Color(1, 0, 0, 1))
	_boom = AudioStreamPlayer.new()
	_boom.stream = ScapeSynth.stream("bolide")
	_boom.bus = &"AmbOut" if AudioServer.get_bus_index("AmbOut") >= 0 else &"Ambience"
	add_child(_boom)


func _sky_mm(n: int, mat: ShaderMaterial, nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = n
	mm.custom_aabb = AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mmi.set_meta("chunked", true)
	mmi.set_meta("site_owned", true)
	mmi.add_to_group(Groups.CULL_SKIP)
	mmi.visible = false
	add_child(mmi)
	return mmi


func start_shower(seconds := 85.0) -> void:
	showers += 1
	_shower_left = seconds
	_shower_bolide_at = seconds * _rng.randf_range(0.35, 0.7)
	_meteors.visible = true


func fire_bolide() -> void:
	bolides += 1
	var az := _rng.randf_range(-PI, PI)
	var from := Vector3(cos(az), _rng.randf_range(0.55, 0.85), sin(az)).normalized()
	var dir := Vector3(-cos(az + _rng.randf_range(-0.5, 0.5)), -0.45, -sin(az + _rng.randf_range(-0.5, 0.5))).normalized()
	_bolide_mat.set_shader_parameter("bolide_from", from)
	_bolide_mat.set_shader_parameter("bolide_dir", dir)
	_bolide_t = 0.0
	_bolide.visible = true
	_boom_t = _rng.randf_range(5.0, 8.0)


func _meteors_step(dt: float) -> void:
	var clear := weather == null or (float(weather.state.rain) < 0.15 and float(weather.state.mist) < 0.5)
	if _shower_left > 0.0:
		_shower_left -= dt
		var was := _shower_left + dt
		if _shower_bolide_at > 0.0 and was >= _shower_bolide_at and _shower_left < _shower_bolide_at:
			fire_bolide()
		var want := 1.0 if _shower_left > 6.0 else 0.0
		shower = move_toward(shower, want * (1.0 if clear else 0.3), dt / 6.0)
	else:
		shower = move_toward(shower, 0.0, dt / 4.0)
		_shower_t -= dt
		if _shower_t <= 0.0 and not quiet:
			_shower_t = _rng.randf_range(360.0, 720.0)
			if clear:
				start_shower(_rng.randf_range(70.0, 100.0))
	_meteors.visible = shower > 0.005
	if _meteors.visible:
		var r := snappedf(shower * 0.55, 0.01)
		if float(_meteors.get_meta("rate", -1.0)) != r:
			_meteors.set_meta("rate", r)
			_meteor_mat.set_shader_parameter("rate", r)
	if _bolide_t >= 0.0:
		_bolide_t += dt / 2.6
		_bolide_mat.set_shader_parameter("manual", _bolide_t)
		if _bolide_t >= 1.0:
			_bolide_t = -1.0
			_bolide.visible = false
	if _boom_t >= 0.0:
		_boom_t -= dt
		if _boom_t < 0.0:
			_boom.volume_db = -9.0
			_boom.pitch_scale = _rng.randf_range(0.85, 1.0)
			_boom.play()


# --- the rift surging ---------------------------------------------------------------------------------

func _build_surge() -> void:
	_surge_mat = ShaderMaterial.new()
	_surge_mat.shader = SURGE_SH
	_surge_mat.set_shader_parameter("sky_r", SKY_R)
	var env_owner := director.get("root") as Node if director != null else null
	var we := env_owner.get_node_or_null("WorldEnvironment") as WorldEnvironment if env_owner != null else null
	if we != null and we.environment != null and we.environment.sky != null and we.environment.sky.sky_material is ShaderMaterial:
		var sm := we.environment.sky.sky_material as ShaderMaterial
		for k: String in ["vortex_dir", "twist", "arm_scale", "spin_speed", "col_rift", "col_lilac", "col_hex"]:
			var v: Variant = sm.get_shader_parameter(k)
			if v != null:
				_surge_mat.set_shader_parameter(k, v)
	_surge_sky = MeshInstance3D.new()
	_surge_sky.name = "SurgeSky"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	pm.subdivide_width = 24
	pm.subdivide_depth = 24
	_surge_sky.mesh = pm
	_surge_sky.material_override = _surge_mat
	_surge_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surge_sky.extra_cull_margin = 16384.0
	_surge_sky.visible = false
	add_child(_surge_sky)
	_surge_snd = AudioStreamPlayer3D.new()
	_surge_snd.name = "SurgeSound"
	_surge_snd.stream = ScapeSynth.stream("surge")
	_surge_snd.bus = &"Ambience"
	_surge_snd.unit_size = 70.0
	_surge_snd.max_distance = 400.0
	_surge_snd.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_surge_snd.panning_strength = 0.5
	_surge_snd.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(_surge_snd)


func start_surge() -> void:
	surges += 1
	_surge_t = 0.0
	_surge_sky.visible = true
	_surge_snd.global_position = RIFT_C
	_surge_snd.volume_db = -4.0
	_surge_snd.play()


func _surge_step(dt: float) -> void:
	if _surge_t < 0.0:
		_next_surge -= dt
		if _next_surge <= 0.0 and not quiet:
			_next_surge = _rng.randf_range(300.0, 540.0)
			start_surge()
		return
	_surge_t += dt
	# build 4 s, hold 2.5, fade 7
	var t := _surge_t
	var k := smoothstep(0.0, 4.0, t) * (1.0 - smoothstep(6.5, 13.5, t))
	var throb := 0.85 + 0.15 * sin(t * 5.0)
	surge = k * throb
	_surge_mat.set_shader_parameter("surge", surge)
	_surge_mat.set_shader_parameter("ring", maxf(0.0, (t - 3.6) * 0.38))
	if weather != null and weather.has_method("pulse"):
		weather.pulse(surge * 0.1)
	LifeKit.material("bat").set_shader_parameter("excite", surge)
	if t >= 3.6 and t - dt < 3.6 and director != null:
		director.call("on_surge", RIFT_C)
	if t >= 13.5:
		_surge_t = -1.0
		surge = 0.0
		_surge_sky.visible = false
		if weather != null and weather.has_method("pulse"):
			weather.pulse(0.0)
		LifeKit.material("bat").set_shader_parameter("excite", 0.0)


# --- will-o'-wisps -----------------------------------------------------------------------------------

func _build_wisp() -> void:
	_wisp = Node3D.new()
	_wisp.name = "Wisp"
	_wisp.visible = false
	add_child(_wisp)
	_wisp_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	_wisp_mesh.mesh = q
	var m := ShaderMaterial.new()
	m.shader = WISP_SH
	m.set_shader_parameter("color", Color(0.45, 1.25, 1.55, 1.0))
	m.set_shader_parameter("pulse_hz", 0.7)
	_wisp_mesh.material_override = m
	_wisp_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisp.add_child(_wisp_mesh)
	# a faint trail of motes
	_wisp_motes = GPUParticles3D.new()
	_wisp_motes.amount = 18
	_wisp_motes.lifetime = 1.6
	_wisp_motes.local_coords = false
	_wisp_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisp_motes.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 6, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.gravity = Vector3(0, 0.12, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.spread = 180.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_wisp_motes.process_material = pm
	var mq := QuadMesh.new()
	mq.size = Vector2(0.06, 0.06)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.vertex_color_use_as_albedo = true
	mm.albedo_color = Color(0.5, 1.2, 1.4, 0.8)
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.disable_receive_shadows = true
	mq.material = mm
	_wisp_motes.draw_pass_1 = mq
	_wisp_motes.emitting = false
	_wisp.add_child(_wisp_motes)
	_wisp_hum = AudioStreamPlayer3D.new()
	_wisp_hum.stream = ScapeSynth.stream("wisp_hum")
	_wisp_hum.bus = &"Ambience"
	_wisp_hum.unit_size = 3.0
	_wisp_hum.max_distance = 24.0
	_wisp_hum.volume_db = -14.0
	_wisp.add_child(_wisp_hum)
	_chime = AudioStreamPlayer3D.new()
	_chime.stream = ScapeSynth.stream("chime")
	_chime.bus = &"Ambience"
	_chime.unit_size = 6.0
	_chime.max_distance = 50.0
	_chime.volume_db = -9.0
	add_child(_chime)


## Something worth being led to: a secret not yet found, an unlit brazier. Nearest first, 25-150 m.
func wisp_targets(from: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var st: GDScript = load("res://core/life/secrets/state.gd") if ResourceLoader.exists("res://core/life/secrets/state.gd") else null
	if st != null:
		var sites: Variant = st.get("sites")
		if sites is Array:
			for s: Variant in sites:
				if s is Dictionary and (s as Dictionary).has("at") and (s as Dictionary).has("id"):
					var found := false
					if st.has_method("has"):
						found = bool(st.call("has", "found", String(s.id)))
					if not found:
						out.append(s.at)
	for b in _braziers:
		if is_instance_valid(b) and not bool(b.get("lit")):
			out.append((b as Node3D).global_position)
	var keep: Array[Vector3] = []
	for p in out:
		var key := "%d,%d" % [roundi(p.x), roundi(p.z)]
		if _wisp_visited.has(key):
			continue
		var d := Vector2(p.x - from.x, p.z - from.z).length()
		if d >= 25.0 and d <= 150.0 and absf(p.y - from.y) < 20.0:
			keep.append(p)
	keep.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(from) < b.distance_to(from))
	return keep


## Start a wisp now, leading the wanderer to `to` (or the nearest target). True if one appeared.
func start_wisp(to := Vector3.INF) -> bool:
	var pl := _player()
	if pl == null:
		return false
	var p := pl.global_position
	if to == Vector3.INF:
		var ts := wisp_targets(p)
		if ts.is_empty():
			return false
		to = ts[0]
	wisps += 1
	wisp_target = to
	var dir := Vector3(to.x - p.x, 0, to.z - p.z).normalized()
	var at := p + dir * 7.0 + Vector3(-dir.z, 0, dir.x) * _rng.randf_range(-2.0, 2.0)
	at.y = RL.height_at(at.x, at.z) + 1.3
	_wisp.global_position = at
	_wisp.visible = true
	_wisp_motes.emitting = true
	_wisp_hum.play()
	_wisp_k = 0.0
	_wisp_idle = 0.0
	_wisp_t = 0.0
	wisp_state = "lead"
	_chime.global_position = at
	_chime.play()
	return true


func _wisp_step(dt: float, pp: Vector3) -> void:
	if wisp_state == "idle":
		return
	var w := _wisp.global_position
	var dp := Vector2(pp.x - w.x, pp.z - w.z).length()
	var to := Vector3(wisp_target.x - w.x, 0, wisp_target.z - w.z)
	var dt_target := to.length()
	_wisp_t += dt
	match wisp_state:
		"lead", "wait":
			_wisp_k = minf(1.0, _wisp_k + dt / 1.5)
			# keep 6-12 m ahead: hurry when you are close, wait (and pulse) when you fall behind
			var sp := 0.0
			if dp < 6.0:
				sp = 2.4
			elif dp < 11.0:
				sp = 1.3
			wisp_state = "lead" if sp > 0.0 else "wait"
			if dp > 18.0:
				_wisp_idle += dt
			else:
				_wisp_idle = maxf(0.0, _wisp_idle - dt * 2.0)
			if dp > 45.0 or _wisp_idle > 25.0 or _wisp_t > 240.0:
				wisp_state = "fade"
			elif dt_target < 2.5:
				wisp_state = "arrive"
				wisp_arrivals += 1
				_wisp_t = 0.0
				_chime.global_position = w
				_chime.play()
			else:
				var step := to / maxf(dt_target, 0.001) * sp * dt
				w += step
		"arrive":
			# circle the place, brighter, until you come or a while passes
			var a := _wisp_t * 1.6
			var c := Vector3(wisp_target.x, 0, wisp_target.z)
			w = w.lerp(c + Vector3(cos(a), 0, sin(a)) * 1.2, clampf(dt * 2.0, 0.0, 1.0))
			_wisp_k = 1.0 + 0.4 * sin(_wisp_t * 4.0)
			if Vector2(pp.x - wisp_target.x, pp.z - wisp_target.z).length() < 5.0 or _wisp_t > 30.0:
				wisp_state = "fade"
				_wisp_visited["%d,%d" % [roundi(wisp_target.x), roundi(wisp_target.z)]] = true
		"fade":
			_wisp_k = move_toward(_wisp_k, 0.0, dt / 2.0)
			w.y += dt * 0.6
			if _wisp_k <= 0.0:
				wisp_state = "idle"
				_wisp.visible = false
				_wisp_motes.emitting = false
				_wisp_hum.stop()
				_wisp_next = _rng.randf_range(150.0, 320.0)
	if wisp_state != "fade" and wisp_state != "idle":
		var gy := RL.height_at(w.x, w.z)
		if RL.in_water(w.x, w.z):
			gy = RL.WATER_Y
		w.y = lerpf(w.y, gy + 1.25 + sin(_wisp_t * 1.3) * 0.22, clampf(dt * 2.0, 0.0, 1.0))
	_wisp.global_position = w
	_wisp_mesh.scale = Vector3.ONE * maxf(0.001, _wisp_k * (1.0 + (0.25 * sin(_wisp_t * 6.0) if wisp_state == "wait" else 0.0)))
	_wisp_hum.volume_db = -14.0 + linear_to_db(maxf(0.001, minf(_wisp_k, 1.0)))


# --- the white hart -------------------------------------------------------------------------------

func _build_hart() -> void:
	_hart = LifeKit.group("stag", 1, "ghost_stag")
	_hart.name = "WhiteHart"
	_hart.multimesh.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 3.5, 4))
	_hart.visible = false
	add_child(_hart)


## Bring the white hart out now, about `dist` m from the wanderer in view. True if it appeared.
func start_hart(dist := 40.0) -> bool:
	var cam := get_viewport().get_camera_3d()
	var pl := _player()
	if cam == null or pl == null:
		return false
	var p := pl.global_position
	var f := -cam.global_basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	for k in 16:
		var a := _rng.randf_range(-0.9, 0.9)
		var q := p + f.rotated(Vector3.UP, a) * dist * _rng.randf_range(0.85, 1.1)
		if not RealmLayout.BOUNDS.has_point(Vector2(q.x, q.z)) or RL.in_water(q.x, q.z):
			continue
		if not LifePlace.open_ground(q.x, q.z):
			continue
		# r29: never among the houses (a render caught it standing by the long house, lit orange by
		# the windows like a placeholder): the wild ground only, well clear of Hearthward
		if Vector2(q.x, q.z).distance_to(HEARTH_C) < HEARTH_CLEAR:
			continue
		harts += 1
		_hart_pos = Vector3(q.x, RL.height_at(q.x, q.z), q.z)
		_hart_yaw = LifeGroup.yaw_to(p - _hart_pos)
		_hart_head = 0.0
		_hart_fade = 0.0
		_hart_t = 0.0
		hart_state = "watch"
		_hart.visible = true
		_chime.global_position = _hart_pos + Vector3(0, 1.5, 0)
		_chime.pitch_scale = 0.5
		_chime.play()
		_hart_write()
		return true
	return false


func _hart_step(dt: float, pp: Vector3) -> void:
	if hart_state == "idle":
		return
	_hart_t += dt
	var to := pp - _hart_pos
	match hart_state:
		"watch":
			_hart_fade = minf(1.0, _hart_fade + dt / 3.0)
			var rel := LifeGroup.wrap_angle(LifeGroup.yaw_to(to) - _hart_yaw)
			_hart_head = LifeGroup.turn(_hart_head, clampf(rel, -1.2, 1.2), dt * 1.5)
			if Vector2(to.x, to.z).length() < 20.0 or _hart_t > 45.0:
				hart_state = "leave"
				_hart_t = 0.0
		"leave":
			# turn away from you and walk off, fading
			var away := LifeGroup.yaw_to(-to)
			_hart_yaw = LifeGroup.turn(_hart_yaw, away, dt * 1.2)
			_hart_head = LifeGroup.turn(_hart_head, 0.0, dt * 2.0)
			var fwd := Vector3(-sin(_hart_yaw), 0, -cos(_hart_yaw))
			var stp := dt * 1.3
			_hart_pos += fwd * stp
			_hart_pos.y = RL.height_at(_hart_pos.x, _hart_pos.z)
			_hart_gait = fmod(_hart_gait + stp * 2.6, TAU * 64.0)
			_hart_walked += stp
			if _hart_walked > 0.75 and director != null and director.get("tracks") != null:
				_hart_walked = 0.0
				_hart_foot = 1 - _hart_foot
				var right := Vector3(cos(_hart_yaw), 0, -sin(_hart_yaw))
				(director.get("tracks") as Node).call("print_at", _hart_pos + right * (0.13 if _hart_foot == 0 else -0.13), _hart_yaw, 2, 45.0)
			if _hart_t > 4.0:
				_hart_fade = maxf(0.0, _hart_fade - dt / 6.0)
			if _hart_fade <= 0.0 and _hart_t > 4.0:
				hart_state = "idle"
				_hart.visible = false
				_hart_next = _rng.randf_range(480.0, 900.0)
	_hart_write()


func _hart_write() -> void:
	var b := Basis(Vector3.UP, _hart_yaw)
	var c := Color(0.0, _hart_head, _hart_gait, 0.15 if hart_state == "watch" else -0.1)
	_hart.multimesh.buffer = LifeGroup.row(Transform3D(b, Vector3.ZERO), c)
	_hart.global_position = _hart_pos
	_hart.set_instance_shader_parameter("fade", _hart_fade)


# --- frame --------------------------------------------------------------------------------------------

func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


func step(dt: float, pp: Vector3, enemies: Array) -> void:
	_meteors_step(dt)
	_surge_step(dt)
	_wisp_step(dt, pp)
	_hart_step(dt, pp)
	_check_t -= dt
	if _check_t > 0.0:
		return
	_check_t = 4.0
	if _braziers.is_empty() or _rng.randf() < 0.05:
		_braziers.clear()
		for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
			if n is Brazier:
				_braziers.append(n)
	if quiet:
		return
	var calm := true
	for e: Vector3 in enemies:
		if e.distance_to(pp) < 30.0:
			calm = false
			break
	var biome := RealmLayout.biome_at(pp.x, pp.z)
	_wisp_next -= 4.0
	if wisp_state == "idle" and _wisp_next <= 0.0 and calm and biome in WISP_BIOMES:
		if _rng.randf() < 0.35:
			start_wisp()
		_wisp_next = maxf(_wisp_next, 8.0)
	_hart_next -= 4.0
	if hart_state == "idle" and _hart_next <= 0.0 and calm and biome in ["oldforest", "glade", "heath", "meadow"]:
		if _rng.randf() < 0.4 and start_hart(_rng.randf_range(34.0, 44.0)):
			pass
		_hart_next = maxf(_hart_next, 30.0)


## Loading-screen warm-up: show every phenomenon at `at` so its shaders compile under the cover;
## warm(false) hides them again (nothing is started: no counters, no sounds).
func warm(on: bool, at := Vector3.ZERO) -> void:
	_meteors.visible = on or shower > 0.005
	_meteor_mat.set_shader_parameter("rate", 1.0 if on else snappedf(shower * 0.55, 0.01))
	_bolide.visible = on or _bolide_t >= 0.0
	if on:
		_bolide_mat.set_shader_parameter("manual", 0.5)
	_surge_sky.visible = on or _surge_t >= 0.0
	_wisp.visible = on or wisp_state != "idle"
	_wisp_motes.emitting = _wisp.visible
	_hart.visible = on or hart_state != "idle"
	if on:
		_wisp.global_position = at + Vector3(0, 1.0, 0)
		_wisp_mesh.scale = Vector3.ONE
		_hart.global_position = at
		_hart.set_instance_shader_parameter("fade", 0.5)
		_hart.multimesh.buffer = LifeGroup.row(Transform3D.IDENTITY, Color(0, 0, 0, 0))
	elif hart_state == "idle":
		_hart.set_instance_shader_parameter("fade", 0.0)


## Start one now (tests, debug): "shower", "bolide", "surge", "wisp", "hart".
func trigger(what: String) -> bool:
	match what:
		"shower":
			start_shower()
			return true
		"bolide":
			fire_bolide()
			return true
		"surge":
			start_surge()
			return true
		"wisp":
			return start_wisp()
		"hart":
			return start_hart()
	return false


const LifePlace := preload("res://core/life/wildlife/life_place.gd")
