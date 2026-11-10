extends Node
## Targeted checks for the combat-QA fixes: the boss warded cue, the bolt reaching low foes, and a
## dialogue opened twice releasing the pause on close. Reuses boss_test's world setup.
var p: Player
var t := 0
var step := 0
var wait := 0
func check(name: String, ok: bool) -> void:
	print("CQATEST ", "PASS " if ok else "FAIL ", name)
func _ready() -> void:
	Travel.seals_broken.clear()
	Travel.bosses_slain.clear()
	Travel.items.clear()
	Travel.relics.clear()
	get_tree().root.add_child.call_deferred(load("res://world/main.tscn").instantiate())
func _boss() -> Enemy:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"boss_id"): return e
	return null
func _tp(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
func _kill_seal(id: String) -> void:
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false):
		for slot in sp._slots:
			if slot.get("seal", "") == id and is_instance_valid(slot.pawn) and slot.pawn is Enemy and (slot.pawn as Enemy).is_alive():
				(slot.pawn as Enemy).take_hit(999.0)
func _ready_world() -> bool:
	var main := p.owner if p.owner else p.get_parent()
	if not main.has_meta("summit_dressed"): return false
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false):
		if sp.get_parent() == main and (sp._slots as Array).size() > 0: return true
	return false
func _physics_process(_d: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	p.wounds = 0.0
	if wait > 0:
		wait -= 1
		return
	match step:
		0:
			if t < 60: return
			if not _ready_world(): return
			var dlg := get_tree().get_first_node_in_group(&"dialogue")
			get_tree().paused = false
			dlg.call("open", "Test")
			dlg.call("open", "Test")
			check("dialogue pauses the tree", get_tree().paused)
			dlg.call("close")
			check("double-open dialogue releases the pause on close", not get_tree().paused)
			_kill_seal("henge")
			step = 1; wait = 30
		1:
			_tp(ThornHenge.C + Vector3(2, 0.5, 2)); step = 2; wait = 40
		2:
			step = 3
			_run_boss_and_aim()
		99:
			get_tree().quit()
func _run_boss_and_aim() -> void:
	var b := _boss()
	check("thornwarden rose", b is Thornwarden)
	if b == null:
		step = 99
		return
	var w := b as Thornwarden
	w._ward_t = 0.0
	w.set_meta(&"test_no_floor", true)
	w._begin_rooting()
	var hp0 := w.hp
	w.take_hit(40.0, p)
	check("rooted: the blow does no damage", is_equal_approx(w.hp, hp0))
	check("rooted: ward_hint set for the boss bar", String(w.get_meta(&"ward_hint", "")) != "")
	check("rooted: the warded cue fired (text, emote, spark stamped)", w.has_meta(&"ward_pop") and w.has_meta(&"ward_emote") and w.has_meta(&"deflect_ms"))
	w._end_rooting(0)
	check("rooted ended: ward_hint cleared", not w.has_meta(&"ward_hint"))
	w._ward_t = 0.0
	w.take_hit(40.0, p)
	check("after the root: damage resumes", w.hp < hp0)
	var cx := ThornHenge.C.x + 60.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(cx, 80, ThornHenge.C.z), Vector3(cx, -40, ThornHenge.C.z), Layers.WORLD)
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	var gy: float = (h.position as Vector3).y if h else 2.0
	var base := Vector3(cx, gy + 0.6, ThornHenge.C.z)
	_tp(base)
	await get_tree().physics_frame
	for s: Script in [load("res://core/enemy/crawler.gd"), load("res://core/enemy/mite.gd")]:
		for dist: float in [5.0, 8.0, 12.0]:
			var e: Enemy = s.new()
			p.get_parent().add_child(e)
			e.global_position = Vector3(base.x + dist, gy + 0.1, base.z)
			await get_tree().physics_frame
			await get_tree().physics_frame
			var muzzle := p.global_position + Vector3.UP * 1.4
			var dir: Vector3 = p.casting._assist(muzzle, (e.global_position - muzzle).normalized())   # the crosshair on the foe's feet
			var tgt := e.global_position + Vector3.UP * (e.hp_bar_y * 0.55) - muzzle
			var off := (tgt - dir * tgt.dot(dir)).length()
			check("%s at %.0f m: aim line passes within the bolt's reach (%.2f m off)" % [e.name, dist, off], off < 0.4)
			e.queue_free()
	step = 99
