extends Node
## r34 raid captures (windowed): both raid rooms at rest and every phase of both fights, the boss bar
## and its emote line on screen. The fights are driven as in zz/raids_r34_test (the phase's health set,
## the move called). In memory only (saves held).
##   HOME=<scratch> godot --path . res://zz/raids_r34_shots.tscn -- --out=<dir> [--only=henge|summit]
var main: Node
var p: Player
var cam: Camera3D
var out := "/tmp"
var only := ""
var started := false


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	Travel.seals_broken.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	get_window().size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	if started:
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("realm_done") or not main.has_meta("summit_dressed"):
		return
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false):
		if (sp._slots as Array).is_empty():
			return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		if p:
			p.gloom = 0.0


func _secs(s: float) -> void:
	await _frames(int(s * 60.0))


func _tp(at: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0, Layers.WORLD)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	p.teleport(((hit.position as Vector3) if not hit.is_empty() else at) + Vector3.UP * 0.15)


func _arena(id: String) -> BossArena:
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id == id:
			return a
	return null


func _boss() -> Enemy:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"boss_id") and (e as Enemy).is_alive():
			return e
	return null


func _kill_seal(id: String) -> void:
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false):
		for slot in sp._slots:
			if slot.get("seal", "") == id and is_instance_valid(slot.pawn) and slot.pawn is Enemy:
				(slot.pawn as Enemy).take_hit(999.0)


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.current = true
	await _frames(8)
	await RenderingServer.frame_post_draw
	var path := out.path_join("raid_%s.png" % name)
	get_viewport().get_texture().get_image().save_png(path)
	print("RAIDSHOT ", path)


## Over the wanderer's shoulder toward the boss.
func _over(name: String, b: Node3D, back := 9.0, up := 4.5) -> void:
	var d := b.global_position - p.global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
	await _shot(name, p.global_position - d * back + Vector3.UP * up, b.global_position + Vector3.UP * 3.0)


func _to_hp(b: Enemy, ratio: float) -> void:
	b.set("_sig", 2)
	b.hp = float(b.max_hp) * ratio - 1.0
	b._ward_t = 0.0


func _run() -> void:
	for n: String in ["Encounters", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	cam.far = 500.0
	main.add_child(cam)
	Travel.bosses_slain["bone_abbot"] = true
	_tp(Vector3(RealmLayout.CROSSING_FOOT.x + 4.0, 2.0, RealmLayout.CROSSING_FOOT.z + 6.0))
	await _frames(30)
	_kill_seal("summit")
	_kill_seal("henge")
	await _frames(30)
	if only != "summit":
		await _henge()
	if only != "henge":
		Travel.bosses_slain["thornwarden"] = true
		await _summit()
	print("RAIDSHOT done")
	get_tree().quit()


func _henge() -> void:
	var arena := _arena("thornwarden")
	var room := arena.room
	var C := arena.global_position
	var seal := arena.gate as Node3D
	var gout := (seal.global_position - C)
	gout.y = 0.0
	gout = gout.normalized()
	var side := gout.cross(Vector3.UP)
	_tp(C + gout * 40.0 + Vector3.UP * 2.0)
	await _secs(1.0)
	await _shot("henge_overview", C + gout * 52.0 + side * 18.0 + Vector3.UP * 42.0, C)
	await _shot("henge_door", C + gout * 37.0 + side * 3.0 + Vector3.UP * 3.0, C + Vector3.UP * 3.0)
	await _shot("henge_floor", C + gout * 26.0 - side * 6.0 + Vector3.UP * 2.6, C - gout * 10.0 + Vector3.UP * 2.0)
	# the pull
	_tp(C + gout * 15.0)
	await _frames(20)
	var b := _boss()
	if b == null:
		print("RAIDSHOT no thornwarden")
		return
	await _secs(2.6)
	b.global_position = C + side * 4.0
	_tp(C + gout * 12.0 + side * 3.0)
	await _frames(10)
	b._ward_t = 0.0
	b.call("_thornstorm")
	await _secs(1.4)
	await _over("henge_p1_thornstorm", b)
	await _secs(2.2)
	b.call("_thorn_lanes")
	await _secs(0.6)
	await _over("henge_p1_volley", b, 10.0, 6.0)
	await _secs(1.0)
	_to_hp(b, 0.7)
	await _secs(15.0)
	await _shot("henge_intermission_air", C + gout * 30.0 + side * 22.0 + Vector3.UP * 36.0, C)
	var knots: Array = room.get("knots")
	if not knots.is_empty() and is_instance_valid(knots[0]):
		_tp((knots[0] as Node3D).global_position - ((knots[0] as Node3D).global_position - C).normalized() * 6.0)
		await _frames(6)
		await _over("henge_intermission_knot", knots[0] as Node3D, 7.0, 3.5)
	for kn in knots:
		if is_instance_valid(kn):
			kn.call("take_hit", 999.0, null)
	await _secs(3.0)
	b._ward_t = 0.0
	b.call("_call_stones")
	_tp(C + gout * 13.0)
	await _secs(1.5)
	await _over("henge_p2_maze", b, 10.0, 6.0)
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).get_meta(&"summoned_by", "") == "thornwarden":
			(e as Enemy).take_hit(999.0)
	_to_hp(b, 0.35)
	await _secs(3.0)
	b._ward_t = 0.0
	b.call("_bloom")
	await _secs(0.9)
	await _shot("henge_p3_bloom_air", C + gout * 26.0 + side * 18.0 + Vector3.UP * 30.0, b.global_position)
	await _secs(14.0)
	_tp(C + gout * 10.0)
	await _frames(10)
	await _over("henge_p3_briars", b, 11.0, 7.0)
	b.set_meta(&"test_no_floor", true)
	b._ward_t = 0.0
	b.take_hit(9999.0)
	await _secs(2.0)
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()


func _summit() -> void:
	var arena := _arena("ascended_warden")
	var room := arena.room
	var C := arena.global_position
	_tp(C + Vector3(0, 0.3, 30.0))
	await _secs(1.0)
	await _shot("summit_overview", C + Vector3(30.0, 40.0, 52.0), C)
	await _shot("summit_deck", C + Vector3(-4.0, 3.0, 25.0), C + Vector3(0, 4.0, -10.0))
	await _shot("summit_edge", C + Vector3(14.0, 4.0, 16.0), C + Vector3(28.0, 0.0, 0.0))
	_tp(C + Vector3(0, 0.3, 10.0))
	await _frames(20)
	var b := _boss()
	if b == null:
		print("RAIDSHOT no warden (ward shut?)")
		return
	await _secs(2.6)
	b._ward_t = 0.0
	b.global_position = C + Vector3(0, 0.1, -6.0)
	b.call("_aim_fan", false)
	await _secs(0.5)
	await _over("summit_p1_fan", b, 9.0, 5.0)
	await _secs(2.0)
	_to_hp(b, 0.65)
	await _secs(4.0)
	await _shot("summit_ascension_air", C + Vector3(26.0, 30.0, 34.0), C + Vector3.UP * 4.0)
	var pyl: Array = room.get("pylons")
	_tp((pyl[2] as Node3D).global_position + Vector3(1.6, 0.3, 0))
	await _secs(1.4)
	await _over("summit_ascension_relight", b, 8.0, 3.0)
	for py in pyl:
		_tp((py as Node3D).global_position + Vector3(1.6, 0.3, 0))
		await _secs(float(room.get("RELIGHT")) + 0.3)
	await _secs(3.0)
	b._ward_t = 0.0
	b._broken_t = 0.0
	b.global_position = C + Vector3.UP * 0.1
	_tp(C + Vector3(5.0, 0.3, 4.0))
	await _frames(4)
	b.call("_begin_gale")
	await _secs(2.6)
	await _over("summit_p2_gale", b, 8.0, 4.0)
	await _secs(5.0)
	b.call("_eclipse")
	await _secs(1.2)
	await _shot("summit_p2_eclipse_air", C + Vector3(20.0, 26.0, 36.0), C)
	await _secs(3.0)
	_to_hp(b, 0.3)
	await _secs(3.0)
	await _over("summit_p3_hierarch", b, 11.0, 5.0)
	b.set_meta(&"test_no_floor", true)
	b._ward_t = 0.0
	b.take_hit(9999.0)
	await _secs(2.0)
