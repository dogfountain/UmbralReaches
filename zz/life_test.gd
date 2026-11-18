extends Node
## Life system headless test:
##   godot --headless --path . res://zz/life_test.tscn [-- --realm-modules=land,rift,bosses,lore,flora,assets,life]
## Checks: creatures placed per kind and biome; walkers and frogs off the water and inside the bounds;
## deer, crows, owls and frogs react to the wanderer (flee, take off, fall silent) and crows come back;
## a fake hollowed thing silences a chorus; the weather cycles through its fronts, thunder flushes
## birds, and the Environment returns exactly to its base values; sounds load; script time per frame.
## Ends LIFE TEST PASS / LIFE TEST FAIL n.
const RL := preload("res://core/world/realm/realm_land.gd")
const LifeSynth := preload("res://core/life/wildlife/life_synth.gd")

var t := 0.0
var fails := 0
var main: Node
var started := false
var pond_spot := Vector3.ZERO


func _ready() -> void:
	Travel._busy = true                       # never write the player's real save from a test
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func fail(msg: String) -> void:
	fails += 1
	print("LIFE FAIL ", msg)


func check(ok: bool, msg: String) -> void:
	if not ok:
		fail(msg)
	else:
		print("LIFE ok  ", msg)


func _process(d: float) -> void:
	t += d
	if started:
		# the camps keep spawning hollowed things; this test brings its own when it wants one
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).has_meta("life_fake") and not (e as Node).is_queued_for_deletion():
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


func _run() -> void:
	await _frames(5)
	var w: Node3D = main.get_node("Wildlife")
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	w.quiet = false
	await _frames(3)
	# ---- counts and biomes
	var c: Dictionary = w.counts
	print("LIFE counts ", c)
	var need := {"moth": 30, "firefly": 120, "bat": 40, "crow": 12, "owl": 4, "heron": 2, "frog": 15, "fox": 2, "elk": 1, "pond": 0}
	for k: String in need:
		check(int(c.get(k, 0)) >= int(need[k]), "%s placed %d (>= %d)" % [k, int(c.get(k, 0)), int(need[k])])
	var by_biome := {}
	for g in w.groups:
		for p: Vector3 in g.positions():
			var key := "%s@%s" % [g.kind, RealmLayout.biome_at(p.x, p.z)]
			by_biome[key] = int(by_biome.get(key, 0)) + 1
	print("LIFE by biome ", by_biome)
	for g in w.groups:
		if g.kind in ["deer", "fox", "elk", "heron"]:
			print("LIFE %s %s at %s" % [g.kind, g.name, str(g.positions().slice(0, 2))])
	var fen_frogs := 0
	for k: String in by_biome:
		if k.begins_with("pond@fen"):
			fen_frogs += int(by_biome[k])
	check(fen_frogs >= 10, "frogs live in the fen (%d)" % fen_frogs)
	var rift_bats := 0
	for b: MultiMeshInstance3D in w.bats:
		if RealmLayout.biome_at(b.global_position.x, b.global_position.z) == "ash":
			rift_bats += b.multimesh.instance_count
	check(rift_bats >= 30, "bats over the rift (%d)" % rift_bats)
	var henge_crows := 0
	for g in w.groups:
		if g.kind == "crow" and (g.center as Vector3).distance_to(Vector3(RealmLayout.HENGE_C.x, 8, RealmLayout.HENGE_C.y)) < 25.0:
			henge_crows += g.birds.size()
	check(henge_crows >= 3, "crows on the henge stones (%d)" % henge_crows)
	_bounds_check(w, "at rest")
	# ---- deer flee
	var herd: Node3D = null
	for g in w.groups:
		if g.kind == "deer":
			herd = g
			break
	check(herd == null, "no deer herds (removed 14 Nov)")
	if herd != null:
		var p0: Vector3 = herd.positions()[0]
		var start := p0
		await _put(player, p0 + Vector3(9, 0, 0))
		await _secs(6.0)
		var moved := 0.0
		for p: Vector3 in herd.positions():
			moved = maxf(moved, p.distance_to(start))
		check(herd.alarms > 0, "deer herd took fright (alarms %d)" % herd.alarms)
		check(moved > 12.0, "deer ran off (%.1f m)" % moved)
		_bounds_check(w, "after the deer fled")
	# ---- crows take off and come back
	var roost: Node3D = null
	for g in w.groups:
		if g.kind == "crow":
			roost = g
			break
	if roost != null:
		var perched0: int = roost.perched_count()
		await _put(player, roost.center + Vector3(2.0, 0, 2.0))
		await _secs(1.5)
		check(roost.perched_count() < perched0, "crows took off (%d -> %d perched)" % [perched0, roost.perched_count()])
		await _put(player, _safe_near(roost.center, 34.0))
		Engine.time_scale = 4.0
		await _secs(40.0)
		Engine.time_scale = 1.0
		var sts := []
		for b: Dictionary in roost.birds:
			sts.append([int(b.state), snappedf(float(b.circle_t), 0.1), (b.pos as Vector3).snapped(Vector3.ONE * 0.1), ((roost.perches[int(b.perch)] as Array)[0] as Vector3).snapped(Vector3.ONE * 0.1)])
		print("LIFE crow states ", sts, " visible ", roost.visible, " player ", player.global_position)
		check(roost.perched_count() >= perched0 - 1, "crows came back to the roost (%d of %d)" % [roost.perched_count(), perched0])
	# ---- the roost's return, run on its own clock with nobody about (the wanderer can be hollowed
	# by the gloom while the test waits, which resets the roost instead)
	if roost != null:
		roost.alarm(roost.center, 1.0)
		var away := {"cam": roost.center + Vector3(0, 0, 50), "player": roost.center + Vector3(0, 0, 50), "player_speed": 0.0,
			"enemies": [] as Array[Vector3], "time": 0.0, "dt": 0.05, "weather": w.weather.state, "quiet": true}
		var up := 9
		for i in 1600:
			roost.tick(0.05, away)
			if i == 100:
				up = roost.perched_count()
		check(up < 3 and roost.perched_count() >= roost.birds.size() - 1, "crows wheel and land back on their own perches (%d up -> %d perched of %d)" % [roost.birds.size() - up, roost.perched_count(), roost.birds.size()])
	# ---- owls
	var owls: Node3D = null
	for g in w.groups:
		if g.kind == "owl":
			owls = g
			break
	if owls != null:
		var op: Vector3 = owls.positions()[0]
		for ob: Dictionary in owls.get("birds"):            # a perched one (an owl already up, away or hunting has nothing to startle from)
			if int(ob.state) == 0:
				op = ob.pos
				break
		await _put(player, Vector3(op.x + 3.0, op.y - 3.0, op.z))
		for _i in 10:                      # an owl mid-hunt or mid-glide takes a moment to notice: up to 5 s
			await _secs(0.5)
			if owls.alarms > 0:
				break
		if owls.alarms == 0:
			var sts: Array = []
			for ob: Dictionary in owls.get("birds"):
				sts.append([int(ob.state), (ob.pos as Vector3).distance_to(player.global_position)])
			print("LIFE owl debug: player %s, op %s, birds %s, flee_r %s, processing %s" % [player.global_position, op, sts, owls.get("flee_r"), owls.is_processing()])
		check(owls.alarms > 0, "an owl flew off (alarms %d)" % owls.alarms)
	# ---- frogs: you hush them, a hollowed thing hushes them
	var pond: Node3D = null
	for g in w.groups:
		if g.kind == "pond" and g.frogs.size() >= 3:
			pond = g
			break
	if pond != null:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			(e as Node).queue_free()
		var spot := RealmLayout.PLAYER_START
		for r in [25.0, 35.0, 45.0, 60.0]:
			var q := _safe_near(pond.center, r)
			var far := true
			for f: Dictionary in pond.frogs:
				if Vector2(q.x - (f.home as Vector3).x, q.z - (f.home as Vector3).z).length() < 16.0:
					far = false
			if far and q != RealmLayout.PLAYER_START:
				spot = q
				break
		pond_spot = spot
		await _put(player, spot)
		await _secs(2.0)
		print("LIFE pond ", pond.name, " quiet_t ", pond.quiet_t, " level ", pond.level, " visible ", pond.visible, " enemies ", w._enemies.size(), " player ", player.global_position, " centre ", pond.center)
		check(pond.calling, "chorus calling when nobody is near")
		var fake := Node3D.new()
		fake.add_to_group(Groups.ENEMY)
		fake.set_meta("life_fake", true)
		main.add_child(fake)
		fake.global_position = pond.center + Vector3(8, 0.5, 0)
		await _secs(1.5)
		check(not pond.calling, "chorus falls silent with a hollowed thing near")
		fake.queue_free()
		var f0: Vector3 = pond.frogs[0].home
		await _put(player, f0 + Vector3(0.8, 0, 0.8))
		await _secs(1.5)
		var leapt := 0
		for f: Dictionary in pond.frogs:
			if int(f.state) != 0:
				leapt += 1
		check(leapt > 0, "frogs leapt into the pool (%d)" % leapt)
		check(not pond.calling, "chorus silent with you on the bank")
	# ---- the Gloom tide (encounters' signal) stills the wild
	if pond != null and Events.has_signal("gloom_tide"):
		await _put(player, pond_spot)
		await _secs(6.5)
		print("LIFE pond again quiet_t %.1f level %.2f enemies %d player %s" % [pond.quiet_t, pond.level, w._enemies.size(), player.global_position])
		check(pond.calling, "the chorus starts again once you have gone")
		Events.gloom_tide.emit(true)
		await _secs(1.0)
		check(w.tide and not pond.calling, "the Gloom tide silences the frogs")
		Events.gloom_tide.emit(false)
		await _frames(2)
	# ---- weather
	var wx: Node3D = w.weather
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var base: Dictionary = wx.base
	print("LIFE env base ", base)
	wx.force("storm", true)
	await _frames(3)
	check(env.fog_depth_begin < float(base.fog_depth_begin) - 1.0, "storm brings the fog in (%.1f < %.1f)" % [env.fog_depth_begin, base.fog_depth_begin])
	var glow0 := [env.glow_intensity, env.glow_bloom, env.glow_hdr_threshold]
	var crows_before := 0
	for g in w.groups:
		if g.kind == "crow":
			crows_before += g.alarms
	await _put(player, Vector3(RealmLayout.HENGE_C.x + 30, 0, RealmLayout.HENGE_C.y + 20))
	await _secs(1.0)
	wx.strike()
	await _frames(2)
	check(env.ambient_light_energy > float(base.ambient_light_energy) + 0.05, "a flash lifts the ambient light")
	await _secs(1.0)
	var crows_after := 0
	for g in w.groups:
		if g.kind == "crow":
			crows_after += g.alarms
	check(crows_after > crows_before, "thunder put the crows up (%d -> %d)" % [crows_before, crows_after])
	# a fast run through the fronts
	var seen := {}
	wx.speed = 400.0
	for i in 240:
		seen[wx.front] = true
		await get_tree().process_frame
	wx.speed = 1.0
	print("LIFE fronts seen ", seen.keys())
	check(seen.size() >= 4, "weather cycles through its fronts (%d)" % seen.size())
	wx.force("clear", true)
	wx.state.wind = 0.0
	await _secs(1.5)
	for k: String in base:
		var v := float(env.get(k))
		check(absf(v - float(base[k])) < 1e-3, "env %s back to base (%.6f vs %.6f)" % [k, v, float(base[k])])
	check([env.glow_intensity, env.glow_bloom, env.glow_hdr_threshold] == glow0, "glow untouched")
	check(wx.bank_count() >= 6, "mist banks built (%d)" % wx.bank_count())
	# ---- sounds
	var missing := []
	for k: String in LifeSynth.KINDS:
		var s := LifeSynth.stream(k)
		if s == null or s.get_length() <= 0.1:
			missing.append(k)
		elif not ResourceLoader.exists(LifeSynth.DIR + k + ".wav"):
			missing.append(k + "(not imported)")
	check(missing.is_empty(), "sounds load %s" % str(missing))
	# ---- script time near the busiest spot (the fen)
	await _put(player, Vector3(70, 0, -20))
	await _secs(1.0)
	w.kind_us.clear()
	w.kind_glide_us.clear()
	var f0 := Engine.get_process_frames()
	await _secs(3.5)
	var nf := maxi(Engine.get_process_frames() - f0, 1)
	var per := {}
	for k: String in w.kind_us:
		per[k] = snappedf(float(w.kind_us[k]) / nf, 0.1)
	var active := 0
	for g in w.groups:
		if g.visible:
			active += 1
	print("LIFE perf by kind (us/frame) ", per, " active groups ", active, " frames ", nf)
	var gl := {}
	for k: String in w.kind_glide_us:
		gl[k] = snappedf(float(w.kind_glide_us[k]) / nf, 0.1)
	print("LIFE perf of which gliding ", gl, "  director median %.0f p90 %.0f" % [w.perf_p50, w.perf_p90])
	var total: float = w.perf_us + float(w.weather.perf_us)
	print("LIFE perf %.0f us/frame (director + groups %.0f, weather %.0f)" % [total, w.perf_us, w.weather.perf_us])
	check(total < 500.0, "script time %.0f us < 500" % total)
	_bounds_check(w, "at the end")
	_end()


## Open dry ground about `dist` from c (so the wanderer does not land in a pool or the rift).
func _safe_near(c: Vector3, dist: float) -> Vector3:
	for k in 32:
		var a := float(k) / 32.0 * TAU * 3.0
		var d := dist * (1.0 + 0.1 * float(k / 8))
		var q := c + Vector3(cos(a) * d, 0, sin(a) * d)
		if RealmLayout.BOUNDS.grow(-6.0).has_point(Vector2(q.x, q.z)) and not RL.in_water(q.x, q.z) and RealmLayout.biome_at(q.x, q.z) not in ["ash", "crag"]:
			return q
	return RealmLayout.PLAYER_START


func _put(player: CharacterBody3D, p: Vector3) -> void:
	var y := RealmLayout.ground(player.get_world_3d().direct_space_state, p.x, p.z)
	player.global_position = Vector3(p.x, maxf(y, p.y) + 0.2, p.z)
	player.velocity = Vector3.ZERO
	await _frames(2)


func _bounds_check(w: Node3D, when: String) -> void:
	var bad := 0
	for g in w.groups:
		if g.kind not in ["deer", "fox", "elk", "pond"]:
			continue
		for p: Vector3 in g.positions():
			var inside := RealmLayout.BOUNDS.has_point(Vector2(p.x, p.z)) if g.kind != "elk" else RealmLayout.OUTER.has_point(Vector2(p.x, p.z))
			if not inside or RL.in_water(p.x, p.z):
				bad += 1
				if bad < 6:
					print("LIFE stray %s at %s (in water %s)" % [g.kind, p, RL.in_water(p.x, p.z)])
	check(bad == 0, "walkers and frogs off the water and inside the bounds %s (%d stray)" % [when, bad])


func _end() -> void:
	Engine.time_scale = 1.0
	print("LIFE TEST PASS" if fails == 0 else "LIFE TEST FAIL %d" % fails)
	get_tree().quit()
