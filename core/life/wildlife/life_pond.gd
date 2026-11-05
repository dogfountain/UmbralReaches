extends "res://core/life/wildlife/life_group.gd"
## A fen pool's life (life system): frogs on its banks calling in a chorus (a looped positional
## sound, throats pulsing with it), fish rising in rings, drizzle rings while it rains. The chorus
## falls silent when danger is near: a hollowed thing within 22 m, you close by, or thunder; it starts
## again a frog at a time once it is quiet. Walk right up and the nearest frogs leap in (plop, ring).

enum { SIT, LEAP, UNDER }

var frogs: Array[Dictionary] = []
var mmi: MultiMeshInstance3D
var rings: MultiMeshInstance3D
var ring_mat: ShaderMaterial
var splash: MeshInstance3D
var splash_age := -1.0
var chorus: AudioStreamPlayer3D
var _plop: AudioStreamPlayer3D
var pool: Dictionary
var level := 1.0                ## chorus 0..1 (eased)
var quiet_t := 0.0              ## seconds of enforced silence left (thunder, a leap)
var calling := true             ## what the chorus wants to be right now (tests read it)
var _rain_set := -1.0
var _fish_set := -1.0
const CHORUS_DB := -10.0            ## r29: was -15, 9 dB under the fen bed at 15 m
var _t_tick := 0.0             ## ctx.time at the last tick
var _gate := -1.0              ## the chorus gate the sitting frogs carry (their throats' amplitude)
var _moving := 1               ## frogs leaping or under: tick them every time
var _close := false            ## someone near enough to the bank to send frogs leaping
var _still := false
var _reach := 0.0              ## centre to the farthest frog + 7.5 m: closer than this, check each frog
const WATER := -0.9


func setup(p: Dictionary, frog_spots: Array[Vector3], seed_v: int) -> void:
	kind = "pond"
	pool = p
	rng.seed = seed_v
	var c2: Vector2 = p.center
	center = Vector3(c2.x, WATER, c2.y)
	position = center
	active_r = 70.0
	if not frog_spots.is_empty():
		mmi = LifeKit.group("frog", frog_spots.size())
		mmi.visibility_range_end = 38.0
		add_child(mmi)
		for i in frog_spots.size():
			var fp := frog_spots[i]
			var w := LifePlace.nearest_water(p, Vector2(fp.x, fp.z))
			var face := yaw_to(Vector3(fp.x - w.x, 0, fp.z - w.y)) + rng.randf_range(-0.6, 0.6)   # back to the water
			frogs.append({"home": fp, "pos": fp, "yaw": face, "state": SIT, "t": 0.0, "water": Vector3(w.x, WATER, w.y),
				"rate": rng.randf_range(4.5, 7.0), "phase": rng.randf_range(0.0, TAU), "pulse": 0.0, "start": rng.randf_range(0.0, 6.0)})
		for fp2 in frog_spots:
			_reach = maxf(_reach, Vector2(fp2.x - center.x, fp2.z - center.z).length() + 7.5)
		chorus = voice("frogs", -80.0, 7.0, 60.0)
		chorus.position = Vector3(0, 0.3, 0)
		_plop = voice("plop", -14.0, 3.0, 25.0)
	# fish rings over the deeper cells, drizzle rings everywhere
	var cells: Array = (p.cells as Array).duplicate()
	LifePlace.shuffle(cells, rng)
	var nf := clampi(cells.size() / 6, 1, 8)
	var nr := clampi(cells.size(), 2, 18)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = LifeKit.mesh("ring")
	mm.instance_count = nf + nr
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for i in nf + nr:
		var cell: Vector2 = cells[i % cells.size()]
		var at := Vector3(cell.x, WATER + 0.015, cell.y) - center
		lo = lo.min(at)
		hi = hi.max(at)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		if i < nf:
			mm.set_instance_custom_data(i, Color(rng.randf_range(5.0, 12.0), rng.randf_range(0.0, 20.0), rng.randf_range(0.45, 0.8), 0.0))
		else:
			mm.set_instance_custom_data(i, Color(rng.randf_range(0.7, 1.3), rng.randf_range(0.0, 5.0), rng.randf_range(0.12, 0.2), 1.0))
	mm.custom_aabb = AABB(lo - Vector3(3, 0.5, 3), hi - lo + Vector3(6, 1, 6))
	rings = MultiMeshInstance3D.new()
	rings.name = "Rings"
	rings.multimesh = mm
	ring_mat = (LifeKit.material("ripple").duplicate() as ShaderMaterial)
	rings.material_override = ring_mat
	rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rings.set_meta("chunked", true)
	rings.set_meta("site_owned", true)
	rings.visibility_range_end = 45.0
	add_child(rings)
	splash = MeshInstance3D.new()
	splash.name = "Splash"
	splash.mesh = LifeKit.mesh("ring")
	var sm := LifeKit.material("ripple").duplicate() as ShaderMaterial
	sm.set_shader_parameter("spread", 0.0)
	splash.material_override = sm
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splash.visible = false
	add_child(splash)
	_write()


func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in frogs:
		if int(f.state) == SIT:
			out.append(f.pos)
	return out


func rest() -> void:
	for f in frogs:
		f.state = SIT
		f.pos = f.home
	quiet_t = 0.0
	if chorus != null and chorus.playing:
		chorus.stop()
	level = 0.6
	_moving = 1
	_gate = -1.0
	_write()


func busy() -> bool:
	if splash_age >= 0.0:
		return true
	for f in frogs:
		if int(f.state) == LEAP:
			return true
	return false


func alarm(at: Vector3, strength: float) -> void:
	if center.distance_to(at) < 30.0 + 60.0 * strength:
		quiet_t = maxf(quiet_t, 6.0 + 6.0 * strength)
		alarms += 1


func tick(dt: float, ctx: Dictionary) -> void:
	var wx: Dictionary = ctx.weather
	var rain := snappedf(float(wx.get("rain", 0.0)), 0.02)
	if rain != _rain_set:
		_rain_set = rain
		ring_mat.set_shader_parameter("rain", rain)
	quiet_t = maxf(0.0, quiet_t - dt)
	# danger silences the chorus: hollowed things near, you on the bank
	var danger := false
	for e: Vector3 in ctx.enemies:
		if e.distance_to(center) < 22.0:
			danger = true
			break
	var pl: Vector3 = ctx.player
	var near := false
	if Vector2(pl.x - center.x, pl.z - center.z).length() < _reach:
		for f in frogs:
			if Vector2(pl.x - (f.home as Vector3).x, pl.z - (f.home as Vector3).z).length() < 7.0:
				near = true
				break
	calling = not danger and not near and quiet_t <= 0.0 and not bool(ctx.get("quiet", false))
	var fish := 0.0 if (near or danger) else 1.0
	if fish != _fish_set:
		_fish_set = fish
		ring_mat.set_shader_parameter("fish", fish)
	level = move_toward(level, 1.0 if calling else 0.0, dt * (0.25 if calling else 1.2))
	if chorus != null:
		var db := CHORUS_DB + linear_to_db(maxf(level, 0.0001)) - float(wx.get("rain", 0.0)) * 4.0
		if absf(db - chorus.volume_db) > 0.05:
			chorus.volume_db = db
		if level > 0.01 and not chorus.playing:
			chorus.play(rng.randf() * 6.0)
		elif level <= 0.01 and chorus.playing:
			chorus.stop()
	var t := float(ctx.time)
	_t_tick = t
	# the throats pulse on the GPU (creature_rig throat_auto): each sitting frog carries only the
	# chorus' gate, so a calling pool that nobody walks up to costs a few lines a tick and no writes
	_close = Vector2(pl.x - center.x, pl.z - center.z).length() < _reach + 4.0
	var gate := snappedf(level, 0.05) if level > 0.2 else 0.0
	var dirty := gate != _gate
	_gate = gate
	if _moving > 0 or dirty or Vector2(pl.x - center.x, pl.z - center.z).length() < _reach:
		_moving = 0
		dirty = true
		for f in frogs:
			var st := int(f.state)
			var p: Vector3 = f.pos
			if st == SIT:
				f.pulse = gate
				if Vector2(pl.x - p.x, pl.z - p.z).length() < 2.6:
					f.state = LEAP
					f.t = 0.0
					f.from = p
					quiet_t = maxf(quiet_t, 5.0)
					_moving += 1
			elif st == LEAP:
				_moving += 1
				f.t = float(f.t) + dt / 0.45
				var a: Vector3 = f.from
				var b: Vector3 = f.water
				var k := minf(float(f.t), 1.0)
				f.pos = a.lerp(b, k) + Vector3(0, sin(k * PI) * 0.35, 0)
				f.yaw = yaw_to(b - a)
				f.pulse = 0.0
				if k >= 1.0:
					f.state = UNDER
					f.t = rng.randf_range(15.0, 30.0)
					_splash(b)
			elif st == UNDER:
				_moving += 1
				f.t = float(f.t) - dt
				if float(f.t) <= 0.0 and Vector2(pl.x - (f.home as Vector3).x, pl.z - (f.home as Vector3).z).length() > 9.0:
					f.state = SIT
					f.pos = f.home
					f.pulse = gate
	if splash_age >= 0.0:
		splash_age += dt
		splash.set_instance_shader_parameter("splash_age", splash_age)
		if splash_age > 2.6:
			splash_age = -1.0
			splash.visible = false
	if dirty:
		_write()
	_still = splash_age < 0.0 and _no_leap()


func _no_leap() -> bool:
	for f in frogs:
		if int(f.state) == LEAP:
			return false
	return true


func _splash(at: Vector3) -> void:
	splash.global_position = Vector3(at.x, WATER + 0.02, at.z)
	splash.visible = true
	splash_age = 0.0
	splash.set_instance_shader_parameter("splash_age", 0.0)
	say(_plop, at, "", rng.randf_range(0.85, 1.2))


var _buf := PackedFloat32Array()
var _box := AABB()


## The throats pulse on the GPU: a pool needs its logic at 30 Hz only while someone is on its
## bank (frogs leap) or a frog is in the air; otherwise 10 Hz for the chorus' level.
func near_interval(_busy: bool) -> float:
	return 1.0 / 30.0 if _moving > 0 or _close else 0.1


## Between ticks: throats pulse on with the clock, a leaping frog flies on (see life_birds.gd).
func glide(ahead: float, _span: float) -> void:
	if splash_age >= 0.0:
		splash.set_instance_shader_parameter("splash_age", splash_age + ahead)
	if not _still:
		_write(ahead)


func _write(ahead := 0.0) -> void:
	if mmi == null:
		return
	var n := frogs.size()
	if _buf.size() != n * 16:
		_buf.resize(n * 16)
		# the box covers every frog's bank spot and its water: fixed for the pool
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for f in frogs:
			lo = lo.min(f.home)
			hi = hi.max(f.water)
			hi = hi.max(f.home)
			lo = lo.min(f.water)
		_box = AABB(lo - center - Vector3(0.5, 0.5, 0.5), hi - lo + Vector3(1.0, 1.4, 1.0))
	for i in n:
		var f: Dictionary = frogs[i]
		var st := int(f.state)
		var pulse := float(f.pulse)
		var fpos: Vector3 = f.pos
		if ahead > 0.0:
			if st == LEAP:
				var k := minf(float(f.t) + ahead / 0.45, 1.0)
				fpos = (f.from as Vector3).lerp(f.water as Vector3, k) + Vector3(0, sin(k * PI) * 0.35, 0)
		var cd := Color(pulse, 0.0, 0.0, 0.0)
		if st == LEAP:
			put(_buf, i, Basis(Vector3.UP, float(f.yaw)) * Basis(Vector3.RIGHT, 0.5), fpos - center, cd)
		else:
			put_yaw(_buf, i, float(f.yaw), 0.001 if st == UNDER else 1.0, fpos - center, cd)
	commit(mmi.multimesh, _buf, _box)


const LifePlace := preload("res://core/life/wildlife/life_place.gd")
