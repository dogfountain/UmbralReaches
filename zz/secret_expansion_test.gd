extends Node
## r28 secrets test (agent D): the Lower Count under the Ossuary and the valley's new secrets,
## walked with the real Player (debug_drive) and solved through their own interactables:
##   the sexton's slab (refuses while the Abbot lives), the flight into the Uncounted Cells, the
##   count wheels (wrong counts refuse), the drum (turns, carries the light only E-W), the bronze
##   mirrors and the sun-eye, the hoard, the Weighing Floor's fight, the Sexton's cage up to the
##   gallery; the Singing Stones (wrong phrase refuses), the Ash-Hermit's breath (a jump into the
##   updraft carries the wanderer to the perch), the Ninth Company's ring (opens when its three
##   writings are read); series rewards; then a REAL reload (the world is freed and built again
##   from the saved state) and every door, bridge and reward is checked again.
##   HOME=<scratch>/home godot --headless --path . res://zz/secret_expansion_test.tscn [-- --only=deep,sing]
## Travel._busy is held for the whole run: the real save is never written.
## Prints "CHECK ok|FAIL ..." and "SECRET EXPANSION TEST PASS" / "... FAIL n".

const State := preload("res://core/life/secrets/state.gd")
const Pages := preload("res://core/life/secrets/pages.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")

var main: Node
var p: Player
var fails := 0
var checks := 0
var only: Array = []
var _cull := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	Travel.set("_busy", true)
	CodexStore.persist = false
	CodexStore.use_path("user://codex_secret_test.cfg", false)
	Travel.bosses_slain.clear()
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
	if p and is_instance_valid(p):
		p.gloom = 0.0
	if _cull and Engine.get_physics_frames() % 20 == 0:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not n.has_meta("elite"):
				(n as Node).queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await _frames(int(s * 60.0))


func _deep() -> Node:
	return main.find_child("LowerCount", true, false)


func _wait_world() -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 200000:
		if main.is_inside_tree() and main.has_meta("realm_done"):
			var d := _deep()
			if d and bool(d.get("built")) and not State.site("hoard").is_empty():
				break
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	return p != null and _deep() != null and not State.site("hoard").is_empty()


func _touch(n: Node, name_part: String) -> Node:
	return n.find_child(name_part, true, false)


func _use(n: Node) -> void:
	if n:
		n.call("interact", p)


func _run() -> void:
	check("world built, Lower Count registered", await _wait_world())
	if p == null or _deep() == null:
		_finish()
		return
	await _frames(20)
	var deep := _deep()
	var ash0 := Travel.count("grave_ash")
	var frag0 := Travel.count("relic_fragment")
	if _want("deep"):
		await _deep_run(deep)
	if _want("sing"):
		await _sing_run()
	if _want("breath"):
		await _breath_run()
	if _want("company"):
		await _company_run()
	print("REWARDS gained: ash %d, fragments %d" % [Travel.count("grave_ash") - ash0, Travel.count("relic_fragment") - frag0])
	await _reload_run()
	_finish()


# --- the Lower Count ----------------------------------------------------------------------------

func _deep_run(deep: Node) -> void:
	var slab := _touch(deep, "Slab")
	_use(slab)
	check("the slab will not shift while the Abbot lives", not State.has("open", "deep_slab"))
	Travel.bosses_slain["bone_abbot"] = true
	_use(slab)
	check("the slab gives once the Abbot is dead", State.has("open", "deep_slab"))
	await _secs(3.0)
	var s := State.site("lower_count")
	check("walk down the chapel flight into the Uncounted Cells", await _walk(s))
	check("the cells are found by walking", State.has("found", "lower_count"))
	# the wheels: wrong counts refuse, the true count raises the bridge
	var wheel := [_touch(deep, "Wheel_0"), _touch(deep, "Wheel_1"), _touch(deep, "Wheel_2")]
	_use(wheel[0])
	_use(wheel[1])
	check("a wrong count does nothing", not State.has("solved", "deep_dials"))
	var want := [4, 2, 5]
	for i in 3:
		var guard := 0
		while int((deep.call("deep").dials as Array)[i]) != want[i] and guard < 6 and not State.has("solved", "deep_dials"):
			_use(wheel[i])
			guard += 1
	check("four, two, five: the count is true", State.has("solved", "deep_dials"))
	var f := Travel.count("relic_fragment")
	_use(_touch(deep, "Cache_deep_cells"))
	_use(_touch(deep, "Cache_deep_cells"))
	check("the sexton's strongbox gives one fragment", Travel.count("relic_fragment") == f + 1)
	await _secs(5.0)
	# into the drum (its door faces the north arm)
	var sd := State.site("count_drum")
	check("walk from the cells down under the pit into the Count Drum", await _walk(sd))
	var drum := deep.get("drum_body") as Node3D
	var cap := _touch(deep, "Capstan")
	_use(cap)
	await _secs(3.2)
	check("the capstan turns the drum a quarter (door east)", int(deep.call("deep").drum) == 1 and absf(angle_difference(drum.rotation.y, -PI * 0.5)) < 0.05)
	# walk out east onto the lava window, turn the mirror west
	check("walk out of the drum's east door to the lava window", await _walk_pts("drum-east", p.global_position, [Vector3(20.6, 0, -84.0), Vector3(21.9, 0, -84.9)] as Array[Vector3], false, -2.0))
	var me := _touch(deep, "TurnMirrorE")
	for i in 6:
		_use(me)
		await _secs(0.6)
	check("east mirror throws the light west (%d)" % int(deep.call("deep").mirror_e), int(deep.call("deep").mirror_e) == 4)
	check("walk back into the drum", await _walk_pts("drum-back", p.global_position, [Vector3(20.6, 0, -84.0), Vector3(18.3, 0, -84.9)] as Array[Vector3], false, -2.0))
	_use(cap)
	await _secs(3.2)
	_use(cap)
	await _secs(3.2)
	check("drum door now faces west", int(deep.call("deep").drum) == 3)
	check("the eye is not lit while the west mirror looks south", not State.has("solved", "deep_beam"))
	check("walk out west to the bronze mirror", await _walk_pts("drum-west", p.global_position, [Vector3(14.9, 0, -84.0), Vector3(10.0, 0, -84.0)] as Array[Vector3], false, -2.0))
	var mw := _touch(deep, "TurnMirrorW")
	for i in 4:
		_use(mw)
		await _secs(0.6)
	check("caught light reaches the sun-eye: the hoard's door lifts", State.has("solved", "deep_beam"))
	await _secs(2.6)
	var sh := State.site("hoard")
	check("walk into the Abbot's hoard", await _walk_pts("hoard-in", p.global_position, [Vector3(7.0, 0, -85.6), Vector3(6.4, 0, -86.4), Vector3(6.4, 0, -88.4), Vector3(7.4, 0, -90.4)] as Array[Vector3], false, -2.0))
	var ash := Travel.count("grave_ash")
	f = Travel.count("relic_fragment")
	_use(_touch(deep, "Cache_deep_hoard"))
	check("the Abbot's coffer: 2 fragments, 60 ash", Travel.count("relic_fragment") == f + 2 and Travel.count("grave_ash") == ash + 60)
	check("the count is ended (beacon in the belfry)", State.has("open", "count_ended") and (deep.find_child("CountEnded", true, false) as Node3D).visible)
	sh = sh
	# the Weighing Floor: across the risen bridge, the fight, the cage
	check("walk to the drum and turn it south", await _walk_pts("hoard-out", p.global_position, [Vector3(6.4, 0, -86.0), Vector3(8.0, 0, -84.0), Vector3(14.9, 0, -84.0), Vector3(17.0, 0, -85.3)] as Array[Vector3], false, -2.0))
	_use(cap)
	await _secs(3.2)
	_use(cap)
	await _secs(3.2)
	_use(cap)
	await _secs(3.2)
	check("drum door faces south (%d)" % int(deep.call("deep").drum), int(deep.call("deep").drum) == 2)
	_cull = false
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	var sw := State.site("weighing")
	var pts: Array[Vector3] = []
	for v: Vector3 in sw.route.pts:
		pts.append(v)
	check("cross the bone bridge onto the Weighing Floor", await _walk_pts("weighing", p.global_position, pts, false, -2.0))
	await _secs(1.0)
	var foes: Array = deep.get("_arena_live")
	check("the Sexton and two wretches rise (%d)" % foes.size(), foes.size() == 3 and bool(deep.get("_arena_on")))
	var elite_ok := false
	for e in foes:
		if is_instance_valid(e) and (e as Node).has_meta("elite"):
			elite_ok = int(e.get("max_hp")) >= 10
	check("the Sexton is an elite", elite_ok)
	check("the bridge grille is shut during the fight", (deep.get("_grille_n") as StaticBody3D).collision_layer != 0)
	ash = Travel.count("grave_ash")
	for i in 60:
		for e in foes:
			if is_instance_valid(e) and bool(e.call("is_alive")):
				e.call("take_hit", 60.0, p)
		await get_tree().physics_frame
	await _secs(1.5)
	check("the Weighing is won and remembered (+%d ash)" % (Travel.count("grave_ash") - ash), State.has("elites", "sexton") and Travel.count("grave_ash") >= ash + 30)
	check("both grilles open after the fight", (deep.get("_grille_n") as StaticBody3D).collision_layer == 0 and (deep.get("_grille_s") as StaticBody3D).collision_layer == 0)
	_cull = true
	# the cage: the top rope refuses until the pin is knocked out below
	_use(_touch(deep, "RopeTop"))
	check("the cage stays pinned from above", not State.has("open", "deep_lift"))
	check("walk to the cage's pin", await _walk_pts("cage-walk", p.global_position, [Vector3(15.3, 0, -66.5), Vector3(14.9, 0, -64.4)] as Array[Vector3], false, -2.0))
	_use(_touch(deep, "RopeBottom"))
	check("the pin is knocked out: the shortcut opens", State.has("open", "deep_lift"))
	check("walk onto the cage", await _walk_pts("cage-on", p.global_position, [Vector3(15.2, 0, -62.4)] as Array[Vector3], false, -2.0))
	_use(_touch(deep, "HaulChain"))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000 and bool((deep.get("_lift") as Node).call("moving")):
		await get_tree().physics_frame
	await _secs(0.5)
	check("ride the cage up to the gallery (y %.2f)" % p.global_position.y, absf(p.global_position.y - 8.4) < 0.5)
	check("step off through the arcade into the niche gallery", await _walk_pts("cage-off", p.global_position, [Vector3(17.2, 0, -62.1), Vector3(19.6, 0, -62.1)] as Array[Vector3], false, 8.4))
	check("every Lower Count place found (%d/4)" % _found(["lower_count", "count_drum", "weighing", "hoard"]), _found(["lower_count", "count_drum", "weighing", "hoard"]) == 4)


func _found(ids: Array) -> int:
	var n := 0
	for id: String in ids:
		if State.has("found", id):
			n += 1
	return n


# --- the valley's new secrets (filled in below as they are built) ------------------------------

func _sing_run() -> void:
	var s := State.site("singing")
	if s.is_empty():
		check("the Singing Stones exist", false)
		return
	check("walk to the Singing Stones", await _walk(s))
	var node: Node = s.node
	var stones: Array = s.stones
	var phrase: Array = s.phrase
	_use(_touch(node, "Listen"))
	await _secs(0.4)
	# a wrong phrase
	for i in phrase.size():
		_use(stones[(int(phrase[i]) + 1) % stones.size()])
		await _secs(0.3)
	check("a wrong phrase does not wake the stones", not State.has("solved", "singing"))
	await _secs(1.2)
	for i in phrase.size():
		_use(stones[int(phrase[i])])
		await _secs(0.3)
	check("the phrase sung back: the stones answer", State.has("solved", "singing"))
	await _secs(2.0)
	check("the hollow under the roots opens", (s.door as StaticBody3D).collision_layer == 0)
	var f := Travel.count("relic_fragment")
	check("walk into the root hollow", await _walk_pts("hollow", p.global_position, [s.inside] as Array[Vector3], false))
	_use(_touch(node, "Cache_singing"))
	check("the hollow's offering gives a fragment", Travel.count("relic_fragment") == f + 1)
	check("the wisps keep singing (world change)", node.find_child("Wisps", true, false) != null and (node.find_child("Wisps", true, false) as Node3D).visible)


func _breath_run() -> void:
	var s := State.site("breath")
	if s.is_empty():
		check("the Ash-Hermit's Perch exists", false)
		return
	check("walk into the hermit's tower", await _walk(s))
	var node: Node = s.node
	var top: Vector3 = s.top
	# wait for an exhale, then jump into it
	var ok := false
	var t0 := Time.get_ticks_msec()
	var was := true
	while Time.get_ticks_msec() - t0 < 25000:
		var now := bool(node.get_node("Breath").call("breathing"))
		if now and not was:
			break                      # the start of an exhale
		was = now
		await get_tree().physics_frame
	var vent: Vector3 = s.vent
	_teleport(Vector3(vent.x, vent.y + 0.15, vent.z))
	await _frames(2)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	var best := p.global_position.y
	var bn := node.get_node("Breath") as Node3D
	for i in 360:
		best = maxf(best, p.global_position.y)
		if i % 15 == 0 and "--trace" in OS.get_cmdline_user_args():
			print("BREATH t%d p %s vent %s breathing %s floor %s vy %.2f" % [i, p.global_position.snapped(Vector3.ONE * 0.01), bn.global_position.snapped(Vector3.ONE * 0.01), bn.call("breathing"), p.is_on_floor(), p.velocity.y])
		var d := Vector2(top.x - p.global_position.x, top.z - p.global_position.z)
		if p.global_position.y > top.y - 0.6 and d.length() > 0.4:
			p.debug_drive(Vector3(d.x, 0, d.y).normalized())
		await get_tree().physics_frame
	p.debug_drive(Vector3.ZERO)
	await _frames(20)
	ok = absf(p.global_position.y - top.y) < 0.6
	check("the breath lifts the wanderer onto the perch (peak %.1f, now %.1f, perch %.1f)" % [best, p.global_position.y, top.y], ok)
	if not ok:
		_teleport(top + Vector3.UP * 0.2)
		await _frames(10)
	var f := Travel.count("relic_fragment")
	_use(_touch(node, "Cache_breath"))
	check("the hermit's cache gives a fragment", Travel.count("relic_fragment") == f + 1)
	check("the perch is found", State.has("found", "breath"))


func _company_run() -> void:
	var s := State.site("company")
	if s.is_empty():
		check("the Ninth Company's ring exists", false)
		return
	check("walk to the ritual ring", await _walk(s))
	var node: Node = s.node
	var cache := _touch(node, "Cache_company")
	check("the company's offering is hidden while its story is untold", cache != null and String(cache.call("interact_text")) == "")
	for id: String in ["nc_company_1", "nc_company_2", "nc_company_3"]:
		CodexStore.record_read(id)
		var codex := get_tree().get_first_node_in_group("codex")
		if codex and codex.has_method("note_read"):
			codex.call("note_read", id)
	await _frames(10)
	check("with the three letters read, the offering shows", String(cache.call("interact_text")) != "")
	var f := Travel.count("relic_fragment")
	_use(cache)
	check("the Ninth Company's offering gives a fragment", Travel.count("relic_fragment") == f + 1)
	check("story completion rewarded once", State.has("looted", "series_company"))


# --- a real reload -----------------------------------------------------------------------------

func _reload_run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("systems", "state", Travel.systems)
	var text := cfg.encode_to_text()
	var snap: Dictionary = State.st().duplicate(true)
	var ash := Travel.count("grave_ash")
	var frag := Travel.count("relic_fragment")
	var slain := Travel.bosses_slain.duplicate()
	p = null
	main.queue_free()
	await _frames(30)
	var cfg2 := ConfigFile.new()
	cfg2.parse(text)
	Travel.systems = (cfg2.get_value("systems", "state", {}) as Dictionary).duplicate(true)
	Travel.bosses_slain = slain
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child(main)
	check("world rebuilt from the saved state", await _wait_world())
	await _frames(30)
	var same := true
	for g: String in State.GROUPS:
		if (State.st()[g] as Dictionary).size() != (snap[g] as Dictionary).size():
			same = false
			print("RELOAD group %s: %d vs %d" % [g, (State.st()[g] as Dictionary).size(), (snap[g] as Dictionary).size()])
	check("secrets state survives the reload", same)
	var deep := _deep()
	if _want("deep") and deep:
		var slab_body: StaticBody3D = null
		for c in deep.get_node("SextonSlab").get_children():
			if c is StaticBody3D:
				slab_body = c
		check("after reload: slab open", slab_body != null and slab_body.collision_layer == 0)
		var bb: StaticBody3D = null
		for c in deep.get_node("BoneBridge").get_children():
			if c is StaticBody3D:
				bb = c
		check("after reload: bone bridge up", bb != null and bb.collision_layer != 0)
		check("after reload: drum where it was left (%d)" % int(deep.call("deep").drum), absf(angle_difference((deep.get("drum_body") as Node3D).rotation.y, -float(int(deep.call("deep").drum)) * PI * 0.5)) < 0.05)
		check("after reload: hoard door up, cage unpinned, beacon lit", State.has("solved", "deep_beam") and State.has("open", "deep_lift") and (deep.find_child("CountEnded", true, false) as Node3D).visible)
		check("after reload: grilles open", (deep.get("_grille_s") as StaticBody3D).collision_layer == 0)
	for c: String in ["deep_cells", "deep_hoard", "singing", "breath", "company"]:
		if State.has("looted", c):
			State.take(c, Vector3.ZERO)
	check("no cache pays twice after the reload", Travel.count("grave_ash") == ash and Travel.count("relic_fragment") == frag)
	if _want("sing") and not State.site("singing").is_empty():
		var w := State.site("singing").node.find_child("Wisps", true, false) as Node3D
		check("after reload: the wisps still sing", w != null and w.visible)


# --- walking (as zz/secrets_test) -----------------------------------------------------------------

func _teleport(at: Vector3) -> void:
	var sp := (main as Node3D).get_world_3d().direct_space_state
	var y := at.y if absf(at.y) > 0.01 else RealmLayout.ground(sp, at.x, at.z) + 0.9
	p.global_position = Vector3(at.x, y, at.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _walk(s: Dictionary, end_tol := 1.2) -> bool:
	var r: Dictionary = s.route
	var pts: Array[Vector3] = []
	for v: Vector3 in r.pts:
		pts.append(v)
	var goal: Vector3 = s.goal
	var from: Vector3 = r.from
	if absf(from.y) > 0.01:
		from.y += 0.9
	return await _walk_pts(String(s.id), from, pts, true, goal.y if absf(goal.y) > 0.001 else NAN, end_tol)


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
			if d.length() < 0.5:
				break
			t += get_physics_process_delta_time()
			if t > limit:
				print("STUCK %s leg %d goal %s at %s" % [label, i, Vector2(goal.x, goal.z), p.global_position.snapped(Vector3.ONE * 0.01)])
				p.debug_drive(Vector3.ZERO)
				return false
			p.debug_drive(Vector3(d.x, 0, d.y).normalized(), false)
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
	print("SECRET EXPANSION TEST %s (%d checks)" % ["PASS" if fails == 0 else "FAIL %d" % fails, checks])
	OS.kill(OS.get_process_id())
