extends Node
## Living-world reactions (r28) headless test:
##   godot --headless --path . res://zz/world_react_test.tscn
## Checks: graded fright (a far disturbance brings heads up, a near one sends the herd off), hoofprints
## where it ran; the fox's mousing pounce; an owl's hunt on its field mice (watch, dive, mantle, back to
## the branch) and the mice bolting from the wanderer; a lapwing flock lifting, wheeling and settling
## on new ground; moths finding a newly kindled brazier; thunder close by turning heads; a rift surge
## (bats excited, the ground light offset, crows up, everything back to base after); a will-o'-wisp
## leading to a target, waiting, arriving and going out; the white hart watching, leaving glowing
## prints and fading; a meteor shower and a bolide; lasting signs under the owls' trees.
## Ends WORLD REACT PASS / WORLD REACT FAIL n.
const RL := preload("res://core/world/realm/realm_land.gd")

var t := 0.0
var fails := 0
var main: Node
var started := false
var w: Node3D
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
	if Time.get_ticks_msec() > 560000:             # WATCHDOG (real time): never outlive a stuck step
		print("WORLD TIMEOUT after %.0f s" % (Time.get_ticks_msec() / 1000.0))
		Engine.time_scale = 1.0
		get_tree().quit(1)
		return
	if started:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).has_meta("world_fake") and not (e as Node).is_queued_for_deletion():
				(e as Node).remove_from_group(Groups.ENEMY)      # out of the wildlife's sight this frame, not at frame end
				(e as Node).queue_free()
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null:
		if t > 150.0:
			fail("Realm/Wildlife never finished")
			_end()
		return
	started = true
	# foes respawn as fast as the loop above frees them; run that loop before every other node (the
	# wildlife counted each respawn before it went, so a herd or a fox watched foes that were not there)
	process_priority = -1000
	for sp in get_tree().get_nodes_in_group(&"enemy_spawner"):    # their respawn timers outlive a disabled node
		sp.queue_free()
	var enc := main.find_child("Encounters", true, false)
	if enc:
		enc.process_mode = Node.PROCESS_MODE_DISABLED
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
	await _frames(2)


## Open dry ground about `dist` from c.
func _safe_near(c: Vector3, dist: float) -> Vector3:
	for k in 48:
		var a := float(k) / 16.0 * TAU
		var dd := dist * (1.0 + 0.1 * float(k / 16))
		var q := c + Vector3(cos(a) * dd, 0, sin(a) * dd)
		if RealmLayout.BOUNDS.grow(-6.0).has_point(Vector2(q.x, q.z)) and not RL.in_water(q.x, q.z) and RealmLayout.biome_at(q.x, q.z) not in ["ash", "crag"]:
			return q
	return RealmLayout.PLAYER_START


## Every foe gone now, and out of the wildlife's foe list: a foe left marked for deletion stayed in the
## group, and a herd or a fox watched it for the whole check (beasts mind a foe at 1.9x their alert ring).
func _no_foes() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not (e as Node).has_meta("world_fake"):
			(e as Node).remove_from_group(Groups.ENEMY)
			if (e as Node).get_parent():
				(e as Node).get_parent().remove_child(e)
			(e as Node).queue_free()
	(w.get("_enemies") as Array).clear()
	w.set("_enemy_t", 1.0e9)            # and the director does not look again until _foes_back()


func _foes_back() -> void:
	w.set("_enemy_t", 0.0)


func _group(kind: String, pred := Callable()) -> Node3D:
	for g in w.groups:
		if g.kind == kind and (not pred.is_valid() or bool(pred.call(g))):
			return g
	return null


func _run() -> void:
	await _frames(5)
	w = main.get_node("Wildlife")
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	w.quiet = false
	var ph: Node3D = w.phenomena
	# no natural rift surge in the middle of a check (one turned the herd's heads up again 3 min in
	# and failed "heads go back down"); the surge is tested on purpose further down
	ph.set("_next_surge", 1.0e6)
	ph.quiet = true                             # this test starts the phenomena itself
	var amb := main.get_node_or_null("Ambience")
	if amb != null:
		amb.quiet = true
	check(w.tracks != null and ph != null, "tracks and phenomena built")
	print("WORLD counts ", w.counts)
	check(int(w.counts.get("plover", 0)) >= 18, "lapwing flocks placed (%d)" % int(w.counts.get("plover", 0)))
	check(int(w.tracks.signs) >= 8, "lasting signs under the roosts (%d)" % int(w.tracks.signs))

	# ---- graded fright: far = heads up, near = bolt (+ prints). A herd out on open ground.
	var herd := _group("deer", func(g: Node) -> bool:
		var c: Vector3 = g.center
		return RealmLayout.biome_at(c.x, c.z) in ["meadow", "heath", "glade", "oldforest"] and not Rect2(-40, -125, 80, 125).has_point(Vector2(c.x, c.z)))
	if herd == null:
		herd = _group("deer")
	if herd == null:
		fail("no deer herd")
	else:
		var lead: Vector3 = herd.positions()[0]
		await _put(_safe_near(lead, 42.0))
		_no_foes()
		await _secs(1.0)
		for i in 30:
			if herd.fleeing() == 0:
				break
			await _secs(0.5)
		for a: Dictionary in herd.animals:
			a.state = 0
			a.look_t = 0.0
		await _frames(2)
		lead = herd.positions()[0]
		var st0: int = herd.startles
		var sts := []
		for a: Dictionary in herd.animals:
			sts.append(int(a.state))
		print("WORLD herd states before the far alarm ", sts, " player ", player.global_position, " lead ", lead, " speed ", w._player_speed)
		# 70 m from the group's centre: inside the director's 88 m reach for a 0.35 alarm, and still past the
		# herd's bolt ring (18 + 30 * 0.35 m) yet inside its startle ring (60 + 110 * 0.35 m) from the lead
		w.alarm((herd.center as Vector3) + Vector3(70, 0, 0), 0.35)
		await _frames(3)
		var alert := 0
		for a: Dictionary in herd.animals:
			if int(a.state) == 1:
				alert += 1
		check(herd.startles > st0 and herd.fleeing() == 0 and alert > 0, "a far disturbance brings heads up, no running (alert %d, fleeing %d)" % [alert, herd.fleeing()])
		await _secs(10.0)
		var grazing := 0
		for a: Dictionary in herd.animals:
			if int(a.state) == 0 or int(a.state) == 2:
				grazing += 1
		if grazing == 0:
			var diag := []
			for a: Dictionary in herd.animals:
				diag.append([int(a.state), snappedf(float(a.look_t), 0.1), (a.pos as Vector3).snapped(Vector3.ONE * 0.1)])
			var en := []
			for e: Vector3 in w._enemies:
				en.append(snappedf(e.distance_to(herd.positions()[0] if not herd.positions().is_empty() else lead), 0.1))
			print("WORLD herd still up: ", diag, " visible ", herd.visible, " enemies at ", en, " player at ", snappedf(player.global_position.distance_to(lead), 0.1))
		check(grazing > 0, "heads go back down after a while (%d grazing/walking)" % grazing)
		var laid0: int = w.tracks.laid
		w.alarm(herd.positions()[0] + Vector3(6, 0, 0), 0.6)
		await _frames(2)
		check(herd.fleeing() > 0, "a near one sends the herd off (%d)" % herd.fleeing())
		await _secs(5.0)
		check(int(w.tracks.laid) - laid0 >= 8, "hoofprints where they ran (%d)" % (int(w.tracks.laid) - laid0))
		check(int(w.tracks.live()) > 0, "prints live (%d)" % int(w.tracks.live()))
		_foes_back()

	# ---- the fox's pounce
	var fox := _group("fox")
	if fox == null:
		fail("no fox")
	else:
		var fp: Vector3 = fox.positions()[0]
		await _put(_safe_near(fp, 40.0))
		_no_foes()
		await _secs(1.0)
		for a: Dictionary in fox.animals:
			a.hunt_t = 0.0
			a.t = 0.0
			if int(a.state) != 0:
				a.state = 0
		var p0: int = fox.pounces
		var stalked := false
		for i in 240:                   # r34 merge: 60 s (the green round the fox is busier; it may stalk twice)
			await _secs(0.25)
			for a: Dictionary in fox.animals:
				if int(a.state) == 5:
					stalked = true

			if fox.pounces > p0:
				break
		if not stalked:
			var diag := []
			for a: Dictionary in fox.animals:
				var fpos: Vector3 = a.pos
				diag.append([int(a.state), snappedf(float(a.hunt_t), 0.1), snappedf(float(a.t), 0.1), fpos.snapped(Vector3.ONE * 0.1), fox._ok(fpos.x, fpos.z)])
			print("WORLD fox never stalked: ", diag, " visible ", fox.visible, " player at ", snappedf(player.global_position.distance_to(fp), 0.1))
		check(stalked, "the fox creeps up on something in the grass")
		check(fox.pounces > p0, "and leaps on it (pounces %d, catches %d)" % [fox.pounces, fox.catches])
		_foes_back()

	# ---- the owl's hunt
	var owls := _group("owl", func(g: Node) -> bool: return not (g.mice as Array).is_empty())
	if owls == null:
		fail("no owl group with mice")
	else:
		print("WORLD mice ", owls.mice.size(), " at ", owls.prey_positions().slice(0, 3))
		var bad := 0
		for m: Vector3 in owls.prey_positions():
			if RL.in_water(m.x, m.z) or absf(m.y - RL.height_at(m.x, m.z)) > 0.3:
				bad += 1
		check(bad == 0, "field mice on dry ground (%d off)" % bad)
		await _put(_safe_near(owls.center, 26.0))
		await _secs(1.0)
		owls._hunt_t = 0.0
		var h0: int = owls.hunts
		var dived := false
		var mantled := false
		for i in 160:
			await _secs(0.1)
			for b: Dictionary in owls.birds:
				if int(b.state) == 7:
					dived = true
				if int(b.state) == 8:
					mantled = true
			if mantled:
				break
			if i == 40 and owls.hunts == h0:
				owls._hunt_t = 0.0
		check(owls.hunts > h0 and dived, "an owl drops off its branch onto a mouse (hunts %d)" % owls.hunts)
		check(mantled, "and mantles over it on the ground (catches %d)" % owls.catches)
		var back := false
		for i in 120:
			await _secs(0.25)
			if owls.perched_count() >= owls.birds.size():
				back = true
				break
		check(back, "then flies back up to a branch")
		# the mice bolt from you
		var mp: Array = owls.prey_positions()
		if not mp.is_empty():
			# r31: a field can sit on the rift rim; stand on level ground beside a mouse (+x off the rim
			# slid the wanderer into the rift and the mice never saw it)
			var stand := Vector3.INF
			for m0: Vector3 in mp:
				for off: Vector3 in [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, 1.5), Vector3(0, 0, -1.5)]:
					var q := m0 + off
					if absf(RL.height_at(q.x, q.z) - m0.y) < 0.4 and absf(RL.height_at(q.x + off.x, q.z + off.z) - m0.y) < 0.6:
						stand = q
						break
				if stand != Vector3.INF:
					break
			await _put(stand if stand != Vector3.INF else mp[0] + Vector3(1.5, 0, 0))
			var ran := 0
			for i in 16:                 # up to 4 s: a group out of view ticks slowly
				await _secs(0.25)
				ran = 0
				for m: Dictionary in owls.mice:
					if int(m.state) == 1 or int(m.state) == 2:
						ran += 1
				if ran > 0:
					break
			check(ran > 0, "mice run for cover from the wanderer (%d)" % ran)

	# ---- lapwings
	var flock := _group("plover")
	if flock == null:
		fail("no lapwing flock")
	else:
		await _put(_safe_near(flock.patch, 35.0))
		await _secs(1.0)
		for i in 40:
			if flock.state == 0:
				break
			await _secs(0.5)
		check(flock.state == 0, "the flock is down feeding (state %d)" % flock.state)
		var patch0: Vector3 = flock.patch
		await _put(patch0 + Vector3(4, 0, 0))
		await _secs(1.0)
		check(flock.lifts > 0 and flock.state != 0, "the flock lifts as one (state %d)" % flock.state)
		var hi := 0.0
		for i in 20:
			await _secs(0.2)
			if i % 5 == 0:
				print("WORLD flock state %d t %.1f lead %s land %s vis %s" % [flock.state, flock._t, flock._lead, flock._land, flock.visible])
			for p: Vector3 in flock.positions():
				hi = maxf(hi, p.y - RL.height_at(p.x, p.z))
		check(hi > 4.0, "and wheels above the field (%.1f m up)" % hi)
		await _put(_safe_near(patch0, 60.0))
		Engine.time_scale = 3.0
		var landed := false
		for i in 80:
			await _secs(0.5)
			if flock.state == 0:
				landed = true
				break
		Engine.time_scale = 1.0
		var off := 0.0
		for p: Vector3 in flock.positions():
			off = maxf(off, absf(p.y - RL.height_at(p.x, p.z)))
		check(landed and flock.patch.distance_to(patch0) > 12.0, "and settles on new ground %.0f m off" % flock.patch.distance_to(patch0))
		check(off < 0.3, "every bird down on the turf (%.2f m)" % off)

	# ---- moths find a kindled brazier
	var bz: Node3D = null
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier and not (n as Brazier).lit:
			bz = n
			break
	if bz == null:
		print("WORLD (no unlit brazier: moth arrival skipped)")
	else:
		await _put(_safe_near(bz.global_position, 8.0))
		bz.call("_set_lit", true, false)
		var n0: int = w.moths.size()
		w._on_kindled(bz)
		await _secs(1.5)
		check(w.moths.size() > n0 and not (w._arriving as Array).is_empty(), "moths start to come to the newly kindled flame")
		var mg: MultiMeshInstance3D = null
		for l in w.moths:
			if bz.is_ancestor_of(l):
				mg = w.moths[l]
		var a0 := float(mg.get_instance_shader_parameter("arrive")) if mg != null else -1.0
		Engine.time_scale = 4.0
		await _secs(32.0)
		Engine.time_scale = 1.0
		var a1 := float(mg.get_instance_shader_parameter("arrive")) if mg != null else -1.0
		check(a0 < 0.3 and a1 > 0.99, "and gather round it over half a minute (%.2f -> %.2f)" % [a0, a1])

	# ---- thunder close by
	if herd != null:
		var lead2: Vector3 = herd.positions()[0]
		await _put(_safe_near(lead2, 50.0))
		await _secs(2.0)
		for a: Dictionary in herd.animals:
			a.state = 0
		var s0: int = herd.startles
		var a0: int = herd.alarms
		var wx: Node3D = w.weather
		var to := lead2 - player.global_position
		wx.strike_near(600.0, atan2(to.x, to.z))
		await _secs(2.6)
		check(herd.startles > s0 or herd.alarms > a0, "a strike 600 m off turns the herd's heads (startles %d -> %d)" % [s0, herd.startles])

	# ---- the rift surging
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var wxs: Node3D = w.weather
	wxs.force("clear", true)
	await _secs(1.0)
	var amb0 := env.ambient_light_energy
	var crows := 0
	for g in w.groups:
		if g.kind == "crow":
			crows += g.alarms
	await _put(_safe_near(Vector3(RealmLayout.HENGE_C.x, 0, RealmLayout.HENGE_C.y), 22.0))
	await _secs(1.0)
	ph.trigger("surge")
	await _secs(5.0)
	var bat_ex := float(LifeKitRef.material("bat").get_shader_parameter("excite"))
	check(ph.surge > 0.5 and bat_ex > 0.5, "the rift surges: sky flares, bats boil (surge %.2f, excite %.2f)" % [ph.surge, bat_ex])
	check(env.ambient_light_energy > amb0 + 0.03, "the ground light lifts a little (%.3f -> %.3f)" % [amb0, env.ambient_light_energy])
	var crows2 := 0
	for g in w.groups:
		if g.kind == "crow":
			crows2 += g.alarms
	check(crows2 > crows, "crows go up at the surge (%d -> %d)" % [crows, crows2])
	await _secs(10.0)
	check(ph.surge == 0.0 and absf(env.ambient_light_energy - amb0) < 1e-5, "and it all settles back (%.5f vs %.5f)" % [env.ambient_light_energy, amb0])
	check(float(LifeKitRef.material("bat").get_shader_parameter("excite")) == 0.0, "bats calm again")

	# ---- a will-o'-wisp
	await _put(_safe_near(Vector3(70, 0, -10), 3.0))
	await _secs(1.0)
	var start := player.global_position
	var goal := Vector3.INF
	for k in 24:
		var a := float(k) / 24.0 * TAU
		var q := start + Vector3(cos(a), 0, sin(a)) * 45.0
		if RealmLayout.BOUNDS.grow(-8).has_point(Vector2(q.x, q.z)) and not RL.in_water(q.x, q.z):
			# r34 merge: the follow loop below skips steps that land in water, so the line to the goal
			# must be dry (the doubled bounds let the first pick run east across the fen's pools)
			var dry := true
			for j in range(1, 30):
				var s2 := start.lerp(q, float(j) / 30.0)
				if RL.in_water(s2.x, s2.z):
					dry = false
					break
			if not dry:
				continue
			goal = Vector3(q.x, RL.height_at(q.x, q.z), q.z)
			break
	var targets: Array = ph.wisp_targets(start)
	print("WORLD wisp targets from the fen: ", targets.size())
	check(ph.start_wisp(goal), "a wisp appears ahead")
	var wp0: Vector3 = ph._wisp.global_position
	check(Vector2(wp0.x - start.x, wp0.z - start.z).length() < 10.0, "close in front of the wanderer (%.1f m)" % Vector2(wp0.x - start.x, wp0.z - start.z).length())
	await _secs(4.0)
	check(ph.wisp_state == "wait", "it waits when you do not follow (%s)" % ph.wisp_state)
	# follow it: stay ~5 m behind
	var arrived := false
	for i in 120:
		var wp: Vector3 = ph._wisp.global_position
		var back_dir := (start - wp)
		back_dir.y = 0.0
		var dir := (goal - wp)
		dir.y = 0.0
		var behind := wp - dir.normalized() * 4.5 if dir.length() > 0.5 else wp + back_dir.normalized() * 6.0
		if not RL.in_water(behind.x, behind.z):
			await _put(behind)
		await _secs(0.25)
		if ph.wisp_state == "arrive":
			arrived = true
			break
	check(arrived and ph.wisp_arrivals > 0, "it leads you there and circles it")
	await _put(goal + Vector3(1.5, 0, 0))
	await _secs(4.0)
	check(ph.wisp_state == "idle", "and goes out when you reach it (%s)" % ph.wisp_state)

	# ---- the white hart
	await _put(_safe_near(Vector3(-40, 0, 30), 2.0))
	await _secs(1.0)
	var ok_h: bool = ph.start_hart(38.0)
	check(ok_h and ph.hart_state == "watch", "the white hart appears, watching")
	if ok_h:
		await _secs(4.0)
		check(float(ph._hart.get_instance_shader_parameter("fade")) > 0.9, "out of the air (fade %.2f)" % float(ph._hart.get_instance_shader_parameter("fade")))
		var laid1: int = w.tracks.laid
		await _put(ph._hart_pos + (player.global_position - ph._hart_pos).normalized() * 15.0)
		await _secs(1.0)
		check(ph.hart_state == "leave", "it turns away as you come")
		await _secs(9.0)
		check(int(w.tracks.laid) > laid1, "leaving glowing prints (%d)" % (int(w.tracks.laid) - laid1))
		await _secs(8.0)
		check(ph.hart_state == "idle", "and is gone (%s)" % ph.hart_state)

	# ---- meteors
	ph.trigger("shower")
	await _secs(7.0)
	check(ph.shower > 0.5 and ph._meteors.visible, "a meteor shower (strength %.2f)" % ph.shower)
	ph.trigger("bolide")
	await _secs(1.0)
	check(ph._bolide.visible, "a fireball crosses the sky")
	await _secs(8.5)
	check(ph.bolides > 0 and not ph._bolide.visible, "and its boom has followed")

	# ---- script time
	await _put(Vector3(70, 0, -20))
	await _secs(1.0)
	w.kind_us.clear()
	w.kind_glide_us.clear()
	var f0 := Engine.get_process_frames()
	await _secs(3.0)
	var nf := maxi(Engine.get_process_frames() - f0, 1)
	var per := {}
	for k: String in w.kind_us:
		per[k] = snappedf(float(w.kind_us[k]) / nf, 0.1)
	print("WORLD perf by kind (us/frame) ", per)
	var gl := {}
	for k: String in w.kind_glide_us:
		gl[k] = snappedf(float(w.kind_glide_us[k]) / nf, 0.1)
	print("WORLD perf of which gliding ", gl, "  director median %.0f p90 %.0f" % [w.perf_p50, w.perf_p90])
	var total: float = w.perf_us + float(w.weather.perf_us)
	print("WORLD perf %.0f us/frame (director %.0f, weather %.0f)" % [total, w.perf_us, w.weather.perf_us])
	check(total < 500.0, "script time %.0f us < 500" % total)
	_end()


func _end() -> void:
	Engine.time_scale = 1.0
	print("WORLD REACT PASS" if fails == 0 else "WORLD REACT FAIL %d" % fails)
	get_tree().quit()


const LifeKitRef := preload("res://core/life/wildlife/life_kit.gd")
