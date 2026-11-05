extends Node
## Weather drama (r28) headless test:
##   godot --headless --path . res://zz/world_weather_test.tscn
## Checks: a strike's thunder arrives distance / 343 s after its flash (343 m -> ~1 s, 1029 m -> ~3 s),
## a near strike cracks and a far one rolls; the bolt and the cloud flash show for the flash only and
## the ground light lifts and comes back; the rain bed follows what it falls on (leaves in the wood,
## water in the fen, a roof in the tavern, open ground on the heath); splashes are laid on the ground
## round the camera; gusts sway the foliage materials and calm air gives them back; mist banks sit
## low over the ground and drift; at the end the Environment and the foliage are exactly their base.
## Ends WORLD WEATHER PASS / WORLD WEATHER FAIL n.
const RL := preload("res://core/world/realm/realm_land.gd")
const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const LifeSynth := preload("res://core/life/wildlife/life_synth.gd")

var t := 0.0
var fails := 0
var main: Node
var started := false
var w: Node3D
var wx: Node3D
var player: CharacterBody3D


func _ready() -> void:
	Travel._busy = true                       # never write the player's real save from a test
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func fail(msg: String) -> void:
	fails += 1
	print("WORLD FAIL ", msg)


func check(ok: bool, msg: String) -> void:
	if not ok:
		fail(msg)
	else:
		print("WORLD ok  ", msg)


func _process(d: float) -> void:
	t += d
	if Time.get_ticks_msec() > 300000:             # WATCHDOG (real time): never outlive a stuck step
		print("WORLD TIMEOUT after %.0f s" % (Time.get_ticks_msec() / 1000.0))
		Engine.time_scale = 1.0
		get_tree().quit(1)
		return
	if started:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).is_queued_for_deletion():
				(e as Node).queue_free()
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null:
		if t > 150.0:
			fail("Realm/Wildlife never finished")
			_end()
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _put(p: Vector3) -> void:
	var y := RealmLayout.ground(player.get_world_3d().direct_space_state, p.x, p.z)
	player.global_position = Vector3(p.x, maxf(y, p.y) + 0.2, p.z)
	player.velocity = Vector3.ZERO
	await _frames(3)


func _run() -> void:
	await _frames(5)
	w = main.get_node("Wildlife")
	wx = w.weather
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	w.phenomena.quiet = true
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var base: Dictionary = wx.base
	var glow0 := [env.glow_intensity, env.glow_bloom, env.glow_hdr_threshold]
	var leaf := load(wx.LEAF_MAT) as ShaderMaterial
	var sway0 := float(wx._foliage[0].sway) if not (wx._foliage as Array).is_empty() else -1.0
	check(sway0 > 0.0, "foliage materials found (sway %.3f)" % sway0)
	await _put(Vector3(-20, 0, 62))
	wx.force("storm", true)
	wx._thunder_t = 999.0                       # strikes only when the test asks
	await _secs(1.0)

	# ---- thunder after the flash, by distance
	for dist: float in [343.0, 1029.0]:
		wx.strike_near(dist, 0.0)
		var ls: Dictionary = wx.last_strike
		var t0: int = ls.t_flash
		await _frames(2)
		var bolt_seen: bool = wx._bolt.visible and wx._sky_flash.visible
		var amb_up := env.ambient_light_energy - float(base.ambient_light_energy)
		var heard := -1
		for i in 600:
			await get_tree().process_frame
			if int(wx.last_strike.get("t_sound", -1)) > 0:
				heard = int(wx.last_strike.t_sound) - t0
				break
		var want := dist / 343.0 * 1000.0
		check(heard > 0 and absf(float(heard) - want) < 160.0, "thunder %.0f m away heard after %d ms (want %.0f)" % [dist, heard, want])
		check(bolt_seen, "a bolt and a lit cloud at %.0f m" % dist)
		check(amb_up > 0.05, "the ground light jumps (%.3f)" % amb_up)
		var crack: bool = wx._rumble.stream == ScapeSynth.stream("crack")
		check(crack == (dist < 650.0), "%s at %.0f m" % ["a crack" if crack else "a long roll", dist])
		await _secs(1.2)
		check(not wx._bolt.visible and wx.flash == 0.0, "the flash is over after a second")

	# ---- the rain bed by surface
	var spots := {"leaves": Vector3(-80, 0, -30), "water": Vector3(75, 0, -20), "open": Vector3(-30, 0, 66), "roof": Vector3(18.0, 0, 30.2)}
	for s: String in spots:
		var p: Vector3 = spots[s]
		if s == "water":
			# dry ground in the fen
			for k in 30:
				var q := p + Vector3(float(k % 6) * 3.0 - 7.5, 0, float(k / 6) * 3.0 - 7.5)
				if not RL.in_water(q.x, q.z):
					p = q
					break
		await _put(p)
		await _secs(3.5)
		var key := "rain_open" if s == "open" else "rain_" + s
		print("WORLD rain at %s: surface %s outdoor %.0f mix %s" % [s, wx.surface, wx.outdoor, str(wx.rain_mix)])
		check(wx.surface == s and float(wx.rain_mix.get(key, 0.0)) > 0.6, "rain sounds on %s there (%s %.2f)" % [s, key, float(wx.rain_mix.get(key, 0.0))])
		if s == "roof":
			check(not wx._splash.emitting and not wx._rain.emitting, "no rain or splashes under the roof")

	# ---- splashes on the ground
	await _put(Vector3(-30, 0, 66))
	await _secs(1.5)
	check(wx.splash_on and wx._splash.emitting, "splashes where the rain lands")
	var bad := 0
	var c: Vector3 = wx._splash_at
	for i in 400:
		var px: Color = wx._splash_img.get_pixel(i, 0)
		var x := c.x + px.r
		var z := c.z + px.b
		var want := RL.WATER_Y if RL.in_water(x, z) else RL.height_at(x, z)
		if absf(px.g - 0.02 - want) > 0.05:
			bad += 1
	check(bad == 0, "every splash point on the ground (%d off)" % bad)
	var cam := get_viewport().get_camera_3d()
	check(Vector2(c.x - cam.global_position.x, c.z - cam.global_position.z).length() < 12.0, "round the camera")

	# ---- wind in the foliage
	wx.force("gusts", true)
	var kmax := 0.0
	for i in 40:
		await _secs(0.25)
		kmax = maxf(kmax, wx.sway_k)
	var now_sway := float(leaf.get_shader_parameter("sway"))
	check(kmax > 1.5, "gusts sway the grass and crowns (x%.2f)" % kmax)
	check(absf(now_sway - sway0 * wx.sway_k) < 0.002, "the material carries it (%.3f)" % now_sway)
	wx.force("clear", true)
	await _secs(1.0)
	check(absf(wx.sway_k - 1.0) < 0.15, "calm air gives the base sway back (x%.2f)" % wx.sway_k)

	# ---- mist banks in the low ground
	wx.force("mist", true)
	await _secs(1.0)
	var low := 0
	var vis := 0
	var p0 := {}
	for b: Dictionary in wx._banks:
		var fv: FogVolume = b.node
		p0[fv] = fv.position
		if fv.visible:
			vis += 1
		if absf(fv.position.y - (RL.height_at(fv.position.x, fv.position.z) + 1.3)) < 1.0:
			low += 1
	check(vis == wx.bank_count() and vis >= 9, "mist banks out (%d)" % vis)
	check(low >= vis - 2, "lying low over the ground (%d of %d)" % [low, vis])
	await _secs(4.0)
	var moved := 0
	for b: Dictionary in wx._banks:
		var fv: FogVolume = b.node
		if fv.position.distance_to(p0[fv]) > 0.5:
			moved += 1
	check(moved >= vis - 1, "and drifting (%d)" % moved)

	# ---- back to base exactly
	wx.force("clear", true)
	wx.state.wind = 0.0
	wx.pulse(0.0)
	await _secs(1.5)
	for k: String in base:
		var v := float(env.get(k))
		check(absf(v - float(base[k])) < 1e-5, "env %s back to base (%.6f vs %.6f)" % [k, v, float(base[k])])
	check([env.glow_intensity, env.glow_bloom, env.glow_hdr_threshold] == glow0, "glow untouched")
	# take the weather out: the foliage and the Environment come back exactly
	wx.force("gusts", true)
	await _secs(2.0)
	wx.get_parent().remove_child(wx)
	check(absf(float(leaf.get_shader_parameter("sway")) - sway0) < 1e-6, "foliage sway exactly its own again (%.4f)" % float(leaf.get_shader_parameter("sway")))
	for k: String in base:
		check(absf(float(env.get(k)) - float(base[k])) < 1e-5, "env %s exact after the weather leaves" % k)
	wx.queue_free()
	_end()


func _end() -> void:
	Engine.time_scale = 1.0
	print("WORLD WEATHER PASS" if fails == 0 else "WORLD WEATHER FAIL %d" % fails)
	get_tree().quit()
