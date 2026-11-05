extends Node
## Secrets system test (core/life/secrets): every secret reachable on foot (the real Player driven
## with debug_drive, as zz/realm_walks), puzzles solve (and refuse wrong answers), rewards are
## granted once, doors/bridges/gates open and stay open, elite guardians rise and stay down, the
## world reacts to each boss, and all of it persists through a save and a reload.
##   godot --headless --path . res://zz/secrets_test.tscn [-- --only=bells,crypt]
## Travel._busy is set for the whole run, so the real save is never written.
## Prints "CHECK ok|FAIL ..." lines and "SECRETS TEST PASS" / "SECRETS TEST FAIL n".

const State := preload("res://core/life/secrets/state.gd")
const Secrets := preload("res://core/life/secrets/secrets.gd")
const SiteRim := preload("res://core/life/secrets/site_rim.gd")
const SiteFen := preload("res://core/life/secrets/site_fen.gd")
const SiteWood := preload("res://core/life/secrets/site_wood.gd")
const Reactivity := preload("res://core/life/secrets/reactivity.gd")
const Pages := preload("res://core/life/secrets/pages.gd")

var main: Node
var p: Player
var fails := 0
var checks := 0
var _saved := {}
var _cull := true
var only: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	Travel.set("_busy", true)           # never write the real save (lead's rule); persistence is
	Travel.bosses_slain.clear()         # checked through an in-memory ConfigFile round trip
	Travel.system_state("secrets").clear()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("CHECK %s %s" % ["ok  " if ok else "FAIL", label])


func _want(id: String) -> bool:
	return only.is_empty() or id in only


func _physics_process(_d: float) -> void:
	if p:
		p.gloom = 0.0; p.wounds = 0.0                            # long walks in the dark: no hollowing mid-route
	if _cull and Engine.get_physics_frames() % 20 == 0:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()             # the walks are about the ground, not the fights


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while not (main.is_inside_tree() and main.has_meta("realm_done")) and Time.get_ticks_msec() - t0 < 150000:
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	check("realm built with secrets", main.has_meta("realm_done") and main.get_node_or_null("Secrets") != null and p != null)
	if p == null:
		_finish()
		return
	Events.hollowed.connect(func() -> void: print("HOLLOWED at ", p.global_position))
	Events.respawned.connect(func(at: Vector3) -> void: print("RESPAWNED at ", at))
	await _frames(10)
	check("10+ secret places registered (%d)" % State.sites.size(), State.sites.size() >= 10)
	check("3 elite guardians (%d)" % State.elites.size(), State.elites.size() >= 3)
	for s in State.sites:
		var site_ok := true
		var at: Vector3 = s.at
		var paths_d := RealmLayout.path_dist(Vector2(at.x, at.z))
		if paths_d < 2.0 and s.id != "postern":
			site_ok = false
		check("%s stays off the paths (%.1f m)" % [s.id, paths_d], site_ok)
	var ash0 := Travel.count("grave_ash")
	var frag0 := Travel.count("relic_fragment")

	# --- the fallen bells --------------------------------------------------------------------------
	if _want("bells"):
		var s := State.site("bells")
		check("walk to the bells", await _walk(s))
		var node: Node = s.node
		var great := node.find_child("Bell_great", true, false) as Node3D
		var middle := node.find_child("Bell_middle", true, false) as Node3D
		var treble := node.find_child("Bell_treble", true, false) as Node3D
		check("coffer shut before the bells", String((node.find_child("Cache_bells", true, false) as Node).call("interact_text")) == "")
		SiteRim.strike("treble", "bell_treble", treble)
		SiteRim.strike("middle", "bell_middle", middle)
		SiteRim.strike("great", "bell_great", great)
		check("wrong order does not ring up", not State.has("solved", "bells"))
		SiteRim.strike("great", "bell_great", great)
		SiteRim.strike("middle", "bell_middle", middle)
		SiteRim.strike("treble", "bell_treble", treble)
		check("bells rung from the bottom up", State.has("solved", "bells"))
		var door: StaticBody3D = State.site("barrow").door
		check("barrow door opened by the bells", door.collision_layer == 0)
		var a := Travel.count("grave_ash")
		(node.find_child("Cache_bells", true, false) as Node).call("interact", p)
		(node.find_child("Cache_bells", true, false) as Node).call("interact", p)
		check("Founder's coffer gives 30 ash once (%d)" % (Travel.count("grave_ash") - a), Travel.count("grave_ash") - a == 30)
	if _want("spill"):
		var s2 := State.site("spill")
		check("walk down the hidden stair, behind the spill (walk y %.2f)" % SiteRim.walk_y, await _walk(s2, 1.0))
		var f := Travel.count("relic_fragment")
		(s2.node.find_child("Cache_spill", true, false) as Node).call("interact", p)
		check("strongbox gives a relic fragment", Travel.count("relic_fragment") == f + 1)
	if _want("bridge"):
		var s3 := State.site("bridge")
		check("walk to the bridge landing", await _walk(s3))
		check("bridge hangs shut", not State.has("open", "bridge"))
		(s3.node.find_child("Windlass", true, false) as Node).call("interact", p)
		await _frames(4)
		check("windlass opens the bridge", State.has("open", "bridge"))
		await _frames(190)                   # the deck swings down over 2.6 s: cross once it holds
		var cross: Array = s3.cross
		var pts: Array[Vector3] = []
		for v: Vector3 in cross:
			pts.append(v)
		check("walk across the rim bridge onto the ledge (y %.2f)" % p.global_position.y, await _walk_pts("bridge-cross", p.global_position, pts, false, SiteRim.walk_y))

	# --- the fen -------------------------------------------------------------------------------------
	if _want("barrow"):
		if not State.has("solved", "bells"):
			State.mark("solved", "bells", false)
			State.refresh(false)
		var sb := State.site("barrow")
		check("walk into the upturned barrow's chamber", await _walk(sb))
		var f2 := Travel.count("relic_fragment")
		(sb.node.find_child("Cache_barrow", true, false) as Node).call("interact", p)
		(sb.node.find_child("Cache_barrow", true, false) as Node).call("interact", p)
		check("reliquary gives one fragment", Travel.count("relic_fragment") == f2 + 1)
	if _want("crypt"):
		var sc := State.site("crypt")
		check("wade to the drowned crypt", await _walk(sc))
		var lamps: Dictionary = sc.lamps
		SiteFen._toggle("eye", lamps, Vector3.ZERO)
		SiteFen._toggle("hand", lamps, Vector3.ZERO)
		SiteFen._toggle("mouth", lamps, Vector3.ZERO)
		check("wrong lamps keep the grate down", not State.has("solved", "rite") and (sc.door as StaticBody3D).collision_layer != 0)
		SiteFen._toggle("hand", lamps, Vector3.ZERO)
		SiteFen._toggle("heart", lamps, Vector3.ZERO)
		check("Corvin's rite solved", State.has("solved", "rite"))
		check("grate open", (sc.door as StaticBody3D).collision_layer == 0)
		var inside: Vector3 = sc.inside
		check("walk into the crypt", await _walk_pts("crypt-in", p.global_position, [inside] as Array[Vector3]))
		var f3 := Travel.count("relic_fragment")
		(sc.node.find_child("Cache_crypt", true, false) as Node).call("interact", p)
		check("Corvin's lamp gives a fragment", Travel.count("relic_fragment") == f3 + 1)
	if _want("postern"):
		var sp := State.site("postern")
		var gc: Vector3 = sp.gate
		var dir: Vector3 = sp.dir
		var upper := sp.node.find_child("PosternUpper", true, false) as Node
		upper.call("interact", p)
		check("postern stays barred from the ridge side", not State.has("open", "postern"))
		check("walk up from the fen to the postern", await _walk(sp))
		(sp.node.find_child("PosternBar", true, false) as Node).call("interact", p)
		check("bar lifted from the fen side", State.has("open", "postern") and (sp.door as StaticBody3D).collision_layer == 0)
		# the shortcut: Hearthward -> the ridge's south nose -> the crest -> down the stair -> the fen
		var pts2: Array[Vector3] = []
		for v2: Vector3 in sp.crest:
			pts2.append(v2)
		for v3: Vector3 in sp.stair:
			pts2.append(v3)
		var t1 := Time.get_ticks_msec()
		check("shortcut walk: rift rim -> crest -> stair -> threshold", await _walk_pts("postern-shortcut", Vector3(24.0, 0.0, 4.0), pts2, true))
		print("SHORTCUT postern walk %.1f s" % ((Time.get_ticks_msec() - t1) / 1000.0))
		gc = gc

	# --- the west ------------------------------------------------------------------------------------
	if _want("oak"):
		var so := State.site("oak")
		check("walk to the hollow oak", await _walk(so))
		check("thorn shut while the Thornwarden lives", (so.door as StaticBody3D).collision_layer != 0)
		Travel.bosses_slain["thornwarden"] = true
		Reactivity.apply(main, State.host, "thornwarden", false)
		State.refresh(false)
		check("thorn withered after the Thornwarden", (so.door as StaticBody3D).collision_layer == 0 and State.has("open", "oak"))
		check("walk into the hollow oak", await _walk_pts("oak-in", p.global_position, [so.inside] as Array[Vector3]))
		var f4 := Travel.count("relic_fragment")
		(so.node.find_child("Cache_oak", true, false) as Node).call("interact", p)
		check("the Rooted's offering gives a fragment", Travel.count("relic_fragment") == f4 + 1)
	if _want("cist"):
		var sk := State.site("cist")
		check("walk to Ansel's cist", await _walk(sk))
		var em: Dictionary = sk.embers
		SiteWood._kneel("XII", em, Vector3.ZERO)
		SiteWood._kneel("IX", em, Vector3.ZERO)
		check("wrong stone resets the kneeling", not State.has("solved", "cist"))
		SiteWood._kneel("XII", em, Vector3.ZERO)
		SiteWood._kneel("VII", em, Vector3.ZERO)
		SiteWood._kneel("III", em, Vector3.ZERO)
		check("knelt at twelve, seven, three", State.has("solved", "cist"))
		var spots: Array = sk.kneel
		var kp: Array[Vector3] = []
		# the cist stands where free ground was found, sometimes between two kneeling stones: walk
		# round it rather than into it
		var cc: Vector3 = sk.at
		var prev2: Vector2 = spots[0]
		for v4: Vector2 in [spots[0], spots[2], spots[4]]:
			var seg := v4 - prev2
			if seg.length() > 0.1:
				var tt := clampf((Vector2(cc.x, cc.z) - prev2).dot(seg) / seg.length_squared(), 0.0, 1.0)
				var near := prev2 + seg * tt
				if near.distance_to(Vector2(cc.x, cc.z)) < 2.4:
					var side := Vector2(-seg.y, seg.x).normalized()
					if side.dot(near - Vector2(cc.x, cc.z)) < 0.0:
						side = -side
					var round_pt := Vector2(cc.x, cc.z) + side * 3.2
					kp.append(Vector3(round_pt.x, 0, round_pt.y))
			kp.append(Vector3(v4.x, 0, v4.y))
			prev2 = v4
		check("walk the kneeling stones", await _walk_pts("kneel", p.global_position, kp))
		(sk.node.find_child("Cache_cist", true, false) as Node).call("interact", p)
	for id: String in ["pell", "cairn"]:
		if _want(id):
			var sx := State.site(id)
			check("walk to %s" % id, await _walk(sx))
			(sx.node.find_child("Cache_" + id, true, false) as Node).call("interact", p)

	# --- found, rewards once ------------------------------------------------------------------------
	await _frames(6)
	if only.is_empty():
		# the ten r23 secrets (the r28 ones are walked by zz/secret_expansion_test)
		var orig := 0
		for id: String in Pages.ORIGINAL:
			if State.has("found", id):
				orig += 1
		check("every secret found by walking (%d / %d)" % [orig, Pages.ORIGINAL.size()], orig == Pages.ORIGINAL.size())
		var ash := Travel.count("grave_ash") - ash0
		var frag := Travel.count("relic_fragment") - frag0
		check("rewards: %d ash, %d fragments" % [ash, frag], frag == 6 and ash >= 150)
		var before := Travel.count("grave_ash")
		for c in ["bells", "barrow", "cist", "crypt", "oak", "spill", "pell", "cairn"]:
			State.take(c, Vector3.ZERO)
		check("no cache pays twice", Travel.count("grave_ash") == before)

	# --- elite guardians ----------------------------------------------------------------------------
	if _want("elite"):
		_cull = false
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		State.mark("solved", "bells", false)
		var spec: Dictionary = State.elites[0]
		_teleport(Vector3((spec.at as Vector3).x + 6.0, 0, (spec.at as Vector3).z))
		var e: Node = null
		for i in 120:
			await get_tree().physics_frame
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				if n.has_meta("secret_elite"):
					e = n
			if e:
				break
		check("elite %s rises near its secret" % spec.id, e != null)
		if e:
			check("elite is tougher (hp %d)" % int(e.get("max_hp")), int(e.get("max_hp")) >= 10)
			var a2 := Travel.count("grave_ash")
			for i in 30:
				if is_instance_valid(e) and bool(e.call("is_alive")):
					e.call("take_hit", 50.0, p)
				await get_tree().physics_frame
			await _frames(30)
			check("elite put down, remembered, paid", State.has("elites", String(spec.id)) and Travel.count("grave_ash") >= a2 + 15)
			var again := false
			for i in 60:
				await get_tree().physics_frame
				for n in get_tree().get_nodes_in_group(Groups.ENEMY):
					if n.has_meta("secret_elite") and String(n.get_meta("secret_elite")) == String(spec.id) and bool(n.call("is_alive")):
						again = true
			check("a downed elite stays down", not again)
		_cull = true

	# --- reactivity -----------------------------------------------------------------------------------
	if _want("react"):
		Travel.bosses_slain["thornwarden"] = true
		Reactivity.apply(main, State.host, "thornwarden", false)
		var withered := 0
		for n in main.find_children("Flora_bramble*", "MultiMeshInstance3D", true, false):
			if (n as MultiMeshInstance3D).multimesh.has_meta("secrets_withered"):
				withered += 1
		check("thornwood brambles withered (%d chunks)" % withered, withered > 0)
		check("moonlight shafts in the Thornwood", State.host.get_node_or_null("MoonShafts") != null)
		var hedge := main.find_child("Brambles", true, false)
		check("henge hedge withered", hedge == null or hedge.has_meta("secrets_withered"))
		Travel.bosses_slain["bone_abbot"] = true
		Reactivity.apply(main, State.host, "bone_abbot", false)
		var water := main.find_child("FenWater", true, false)
		check("fen pools cleared", water != null and water.has_meta("secrets_clear"))
		var cn := State.host.get_node_or_null("FenCandles")
		check("candles on the drowned graves (%d meshes)" % (cn.get_child_count() if cn else 0), cn != null and cn.get_child_count() > 2)
		var sky := Reactivity.sky_material(main)
		var spin0 := float(sky.get_shader_parameter("spin_speed")) if sky else 0.0
		Travel.bosses_slain["ascended_warden"] = true
		Reactivity.apply(main, State.host, "ascended_warden", false)
		var spin1 := float(sky.get_shader_parameter("spin_speed")) if sky else 0.0
		check("vortex calms in stages (spin %.4f -> %.4f, calm %.2f)" % [spin0, spin1, Reactivity.calm], sky != null and spin1 < spin0 and is_equal_approx(Reactivity.calm, 1.0))
		for n in get_tree().get_nodes_in_group(&"ward_seal"):
			var ws := n as Node3D
			if String(ws.get("seal_id")) == "henge" and not bool(ws.call("is_open")):
				Travel.seals_broken["henge"] = true
				Events.seal_broken.emit("henge")
		await _frames(200)
		var marks := 0
		for n in get_tree().get_nodes_in_group(&"ward_seal"):
			if (n as Node).has_meta("secrets_marked"):
				marks += 1
		check("seal break leaves a mark (%d)" % marks, marks >= 1)

	# --- persistence ------------------------------------------------------------------------------------
	var snap: Dictionary = State.st().duplicate(true)
	var cfg := ConfigFile.new()
	cfg.set_value("systems", "state", Travel.systems)        # what Travel.save_game writes
	var text := cfg.encode_to_text()
	var cfg2 := ConfigFile.new()
	cfg2.parse(text)
	var sys: Dictionary = cfg2.get_value("systems", "state", {})
	var saved: Dictionary = sys.get("secrets", {})
	check("secrets state serialises with the save", saved.has("solved") and (saved.solved as Dictionary).size() == (snap.solved as Dictionary).size())
	Travel.systems = sys.duplicate(true)                     # what Travel.load_game reads back
	var st := State.st()
	var same := true
	for g: String in ["solved", "open", "looted", "pages", "found", "elites"]:
		if (st[g] as Dictionary).size() != (snap[g] as Dictionary).size():
			same = false
	check("secrets state survives a reload", same)
	State.refresh(false)
	if _want("bridge"):
		check("bridge still open after reload", State.has("open", "bridge"))
	if only.is_empty():
		check("rewards still once after reload", not State.take("bells", Vector3.ZERO) and not State.take("crypt", Vector3.ZERO))
	_finish()


func _teleport(at: Vector3) -> void:
	var sp := (main as Node3D).get_world_3d().direct_space_state
	var y := at.y if at.y > 0.5 else RealmLayout.ground(sp, at.x, at.z) + 0.9
	p.global_position = Vector3(at.x, y, at.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _walk(s: Dictionary, end_tol := 1.2) -> bool:
	var r: Dictionary = s.route
	var pts: Array[Vector3] = []
	for v: Vector3 in r.pts:
		pts.append(v)
	var goal: Vector3 = s.goal
	return await _walk_pts(String(s.id), r.from, pts, true, goal.y if absf(goal.y) > 0.001 else NAN, end_tol)


func _walk_pts(label: String, from: Vector3, pts: Array[Vector3], teleport := true, end_y := NAN, end_tol := 1.2) -> bool:
	if teleport:
		_teleport(from)
		await _frames(8)
	var prev := p.global_position
	for i in pts.size():
		var goal := pts[i]
		var t := 0.0
		var limit := 6.0 + Vector2(goal.x - prev.x, goal.z - prev.z).length() / 2.0
		while true:
			var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
			if d.length() < 0.7:
				break
			t += get_physics_process_delta_time()
			if t > limit:
				print("STUCK %s leg %d goal %s at %s" % [label, i, Vector2(goal.x, goal.z), p.global_position.snapped(Vector3.ONE * 0.01)])
				p.debug_drive(Vector3.ZERO)
				return false
			p.debug_drive(Vector3(d.x, 0, d.y).normalized(), false)
			if Engine.get_physics_frames() % 60 == 0 and "--trace" in OS.get_cmdline_user_args():
				var hits := PackedStringArray()
				for ci in p.get_slide_collision_count():
					var col := p.get_slide_collision(ci)
					hits.append("%s@%s" % [(col.get_collider() as Node).name if col.get_collider() else "?", col.get_position().snapped(Vector3.ONE * 0.01)])
				print("TRACE %s %s %s" % [label, p.global_position.snapped(Vector3.ONE * 0.01), " ".join(hits)])
			await get_tree().physics_frame
		prev = goal
	p.debug_drive(Vector3.ZERO)
	await _frames(10)
	print("WALK %s done at %s" % [label, p.global_position.snapped(Vector3.ONE * 0.01)])
	if not is_nan(end_y) and absf(p.global_position.y - end_y) > end_tol:
		print("WALK %s ended at the wrong height (want %.2f)" % [label, end_y])
		return false
	return true


func _finish() -> void:
	# Travel._busy kept the save untouched: nothing to restore
	print("SECRETS TEST %s (%d checks)" % ["PASS" if fails == 0 else "FAIL %d" % fails, checks])
	OS.kill(OS.get_process_id())
