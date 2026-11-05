extends Node
## r31 enemies (docs/enshrouded/enemies.md): weak points, the BROKEN window and the poise meter,
## pack regroup, the new kinds (Gaunt dart, Quiller lane + spring-back, Tollman's toll and its
## interruption, the Brood-Mother's brood and rupture), guardians at points of interest (API,
## spawn, escort, enrage, payment), the bosses' new moves (Thornwarden heart-knot / snare / lash,
## Abbot tithe / reliquary, Warden halo / eclipse holes), and depth buying behaviour, not HP from
## the wanderer's growth.
## Run: SCRATCH=<dir> tools/run_tests.sh enemies_r31
const AT := Vector3(-24.0, 0.0, 60.0)     ## open ground outside every sanctuary light
const Tiers := preload("res://core/life/encounters/tiers.gd")
const Guardians := preload("res://core/life/encounters/guardians.gd")
var p: Player
var main: Node
var fails := 0
var started := false


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(name: String, ok: bool, detail := "") -> void:
	print("ENEMY31 %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		fails += 1


func _physics_process(_d: float) -> void:
	if started:
		return
	if Engine.get_physics_frames() > 60 * 240:
		print("ENEMY31 FAIL timeout waiting for the world")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("summit_dressed") or main.find_child("Encounters", true, false) == null:
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _gy(x: float, z: float) -> float:
	return RealmLayout.ground(p.get_world_3d().direct_space_state, x, z)


func _ground(v: Vector3) -> Vector3:
	return Vector3(v.x, _gy(v.x, v.z), v.z)


func _put_player(at: Vector3) -> void:
	p.teleport(_ground(at) + Vector3.UP * 0.3)
	p.velocity = Vector3.ZERO
	p.gloom = 0.0


func _spawn(path: String, at: Vector3) -> Enemy:
	var e := (load(path) as GDScript).new() as Enemy
	main.add_child(e)
	e.global_position = _ground(at) + Vector3.UP * 0.1
	e.home = e.global_position
	e.wake()
	return e


func _clear() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()


## A stand-in for a bolt bursting at `at` (Enemy._weak_hit reads where the blow came from).
func _shot_at(at: Vector3) -> Node3D:
	var n := Node3D.new()
	main.add_child(n)
	n.global_position = at
	n.queue_free.call_deferred()
	return n


func _run() -> void:
	var enc := main.find_child("Encounters", true, false)
	enc.process_mode = Node.PROCESS_MODE_DISABLED          # nothing of the director's interferes
	var sp := main.find_child("EnemySpawner", true, false)
	if sp:
		sp.process_mode = Node.PROCESS_MODE_DISABLED
	_clear()
	await _frames(3)
	_put_player(AT + Vector3(30, 0, 0))
	await _frames(5)
	await _weak_and_broken()
	await _regroup()
	await _gaunt()
	await _quiller()
	await _tollman()
	await _brood()
	await _guardians(enc)
	await _bosses()
	_depth()
	print("ENEMY31 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _weak_and_broken() -> void:
	var h := _spawn("res://core/enemy/husk.gd", AT)
	await _frames(3)
	var w := h.get("_weak") as Node3D
	check("husk carries a weak point on its back", w != null and w.name == "WeakPoint" and w.is_visible_in_tree())
	h.set("_stagger_cd", 9.0)                              # no stagger muddies the numbers
	var hp0 := h.hp
	h.take_hit(1.0, _shot_at(w.global_position))
	check("a burst on the weak point lands x1.6", absf(hp0 - h.hp - Enemy.WEAK_MULT) < 0.01, "%.2f" % (hp0 - h.hp))
	hp0 = h.hp
	h.take_hit(1.0, _shot_at(h.global_position + Vector3(0, 1.0, 0) - (w.global_position - h.global_position).normalized() * 3.0))
	check("a burst elsewhere is plain", absf(hp0 - h.hp - 1.0) < 0.01, "%.2f" % (hp0 - h.hp))
	h.set("_stagger_cd", 0.0)
	await _frames(12)                                      # past the hitstop
	check("the poise meter shows on the bar", float(h.get("_bar_poise")) > 0.05, "%.2f" % float(h.get("_bar_poise")))
	h.set("_stagger_cd", 0.0)
	h.stagger()
	check("a stagger leaves it broken", h.is_broken())
	hp0 = h.hp
	h.take_hit(1.0, null)
	check("a broken foe takes x1.3", absf(hp0 - h.hp - Enemy.BROKEN_MULT) < 0.01, "%.2f" % (hp0 - h.hp))
	await _frames(10)
	check("the bar burns gold while broken", float(h.get("_bar_broken")) == 1.0)
	h.queue_free()
	await _frames(2)


func _regroup() -> void:
	_put_player(AT + Vector3(6, 0, 0))
	var pack: Array[Enemy] = []
	for i in 4:
		var e := _spawn("res://core/enemy/wretch.gd", AT + Vector3(0, 0, float(i) * 1.6 - 2.4))
		e.set("can_flee", false)
		e.set("can_call", false)
		pack.append(e)
	await _frames(20)
	for e in pack:
		e.alerted(null)
	await _frames(15)
	pack[0].take_hit(99.0, null)
	pack[1].take_hit(99.0, null)
	await _frames(2)
	var re := 0
	for i in [2, 3]:
		if pack[i].is_regrouping():
			re += 1
	check("two packmates fall: the survivors regroup", re >= 1, "%d of 2" % re)
	await _frames(int(60 * (Enemy.REGROUP + 0.4)))
	var back := 0
	for i in [2, 3]:
		if is_instance_valid(pack[i]) and not pack[i].is_regrouping() and float(pack[i].get("_rally_t")) > 0.0:
			back += 1
	check("...then come again, rallied", back >= 1, "%d" % back)
	_clear()
	await _frames(3)


func _gaunt() -> void:
	_put_player(AT)
	var g := _spawn("res://core/enemy/gaunt.gd", AT + Vector3(-7.5, 0, 1.0))
	g.set("_dart_cd", 1.0)
	var darted := false
	var lane := false
	var wound := false
	for f in 60 * 8:
		await get_tree().physics_frame
		if int(g.get("_state")) == Enemy.SPECIAL:
			darted = true
			if is_instance_valid(g.get("_lane")):
				lane = true
		if int(g.get("_state")) == Enemy.WINDUP:
			wound = true
		if darted and int(g.get("_state")) == Enemy.RECOVER:
			break
	check("gaunt darts with a lane through you", darted and lane)
	check("gaunt never queues a plain rake", not wound)
	check("gaunt draws from its own turn pool", g.token_pool == &"dart")
	g.queue_free()
	await _frames(3)


func _quiller() -> void:
	_put_player(AT)
	var q := _spawn("res://core/enemy/quiller.gd", AT + Vector3(-11, 0, 0))
	q.set("_shot_cd", 0.3)
	var drew := false
	var g0 := p.gloom
	for f in 60 * 5:
		await get_tree().physics_frame
		p.velocity = Vector3.ZERO
		if int(q.get("_state")) == Enemy.WINDUP:
			drew = true
		if drew and p.gloom > g0:
			break
	check("quiller draws a lane", drew)
	check("standing in the lane, the shard lands", p.gloom > g0, "%.1f -> %.1f" % [g0, p.gloom])
	_put_player(q.global_position + Vector3(2.5, 0, 0))
	var d0 := q.global_position.distance_to(p.global_position)
	await _frames(150)
	var d1 := q.global_position.distance_to(p.global_position)
	check("crowded, it springs back out of reach", d1 > d0 + 2.0, "%.1f -> %.1f m" % [d0, d1])
	check("its skull is a weak point", q.get("_weak") != null)
	q.queue_free()
	await _frames(3)


func _tollman() -> void:
	_put_player(AT)
	var far := _spawn("res://core/enemy/wretch.gd", AT + Vector3(-30, 0, 6))
	far.set("can_call", false)
	var tm := _spawn("res://core/enemy/tollman.gd", AT + Vector3(-9, 0, 0))
	var rang := false
	for f in 60 * 7:
		await get_tree().physics_frame
		if int(tm.get("tolls")) > 0:
			rang = true
			break
	check("the tollman rings when it sees you", rang)
	await _frames(2)
	check("the toll wakes a camp past its sight", int(far.get("_state")) != Enemy.IDLE and float(far.get("_hunt_t")) > 5.0, "state %d" % int(far.get("_state")))
	tm.queue_free()
	far.queue_free()
	await _frames(3)
	var tm2 := _spawn("res://core/enemy/tollman.gd", AT + Vector3(-9, 0, 0))
	var spoiled := false
	for f in 60 * 7:
		await get_tree().physics_frame
		if int(tm2.get("_state")) == Enemy.SPECIAL and StringName(tm2.get("_act")) == &"toll" and float(tm2.get("_state_t")) > 0.5:
			tm2.take_hit(0.5, null)
			await _frames(2)
			spoiled = int(tm2.get("tolls")) == 0 and float(tm2.get("_toll_cd")) > 2.0 and int(tm2.get("_state")) != Enemy.SPECIAL
			break
	check("a blow while it rings spoils the toll", spoiled)
	tm2.queue_free()
	await _frames(3)


func _brood() -> void:
	_put_player(AT)
	var b := _spawn("res://core/enemy/brood_mother.gd", AT + Vector3(-8, 0, 0))
	await _frames(5)
	b.alerted(null)
	b.set("_brood_t", 0.0)
	for f in 30:
		await get_tree().physics_frame
		if int(b.get("_state")) == Enemy.SPECIAL:
			break
	check("brood-mother squats to brood", int(b.get("_state")) == Enemy.SPECIAL)
	await _frames(20)
	var sac := b.get("_weak") as Node3D
	b.take_hit(1.0, _shot_at(sac.global_position))
	await _frames(2)
	check("a burst on the swelling sac ruptures the brood", int(b.get("ruptures")) == 1 and b.is_broken())
	b.set("_brood_t", 0.0)
	b.set("_stagger_cd", 9.0)
	await _frames(int(60 * 4.5))
	check("left alone, the brood hatches mites", int(b.get("broods")) >= 1, str(b.get("broods")))
	b.hp = float(b.max_hp) * 0.45
	await _frames(3)
	check("below half she enrages", bool(b.get("enraged")))
	_clear()
	await _frames(3)


func _guardians(enc: Node) -> void:
	var g: Node = enc.get("guardians")
	check("the director keeps the guardians", g != null)
	if g == null:
		return
	# a site in the group (the WORLD's API) is picked up
	var mark := Node3D.new()
	mark.add_to_group(Guardians.GROUP)
	mark.set_meta("guardian", "sexton")
	mark.set_meta("site_key", "test_group_site")
	main.add_child(mark)
	mark.global_position = _ground(AT + Vector3(60, 0, -40))
	g.call("refresh_sites")
	var found := false
	for s: Dictionary in g.get("sites"):
		if s.key == "test_group_site" and s.id == "sexton":
			found = true
	check("a node in guardian_site is a site", found)
	# a site by code, spawned
	var at := _ground(AT + Vector3(-6, 0, 0))
	Guardians.add_site(at, "tithe_knight", "test_api_site")
	g.call("refresh_sites")
	var site: Dictionary = {}
	for s: Dictionary in g.get("sites"):
		if s.key == "test_api_site":
			site = s
	check("Guardians.add_site registers a site", not site.is_empty())
	var e := g.call("spawn", site) as Enemy
	await _frames(3)
	check("the guardian rises, named and grown", e != null and e.has_meta(&"guardian_id") and e._rig.scale.x > 1.3 and Guardians.title(e) == "The Tithe-Knight")
	check("with its escort", (g.get("escorts") as Dictionary).get("test_api_site", []).size() == 3)
	_put_player(AT + Vector3(2, 0, 0))
	await _frames(10)
	var n0 := get_tree().get_nodes_in_group(Groups.ENEMY).size()
	e.hp = float(e.max_hp) * 0.45
	g.call("tick", p.global_position)
	await _frames(3)
	check("at half it enrages and calls its kin", bool(e.get_meta(&"guardian_enraged", false)) and get_tree().get_nodes_in_group(Groups.ENEMY).size() >= n0 + 2)
	check("the name bar shows it", g.call("shown", p.global_position) == e)
	var ash0 := Travel.count("grave_ash")
	e.set_meta(&"test_no_floor", true)
	e.take_hit(999.0, null)
	await _frames(3)
	check("felled: recorded and paid", bool(g.call("slain", "test_api_site")) and Travel.count("grave_ash") >= ash0 + 16, "%d -> %d" % [ash0, Travel.count("grave_ash")])
	check("felled: the banner", String(enc.get("hud").call("banner_text")) == "GUARDIAN FELLED")
	var again: Variant = null
	g.call("tick", p.global_position)
	again = (g.get("nodes") as Dictionary).get("test_api_site")
	check("felled: it does not rise again", again == null or not is_instance_valid(again) or again == e)
	Guardians.reset_sites()
	mark.queue_free()
	_clear()
	await _frames(3)


func _zone_count(b: Enemy) -> int:
	var n := 0
	for m in b._moves:
		if is_instance_valid(m):
			n += 1
	return n


func _bosses() -> void:
	_put_player(AT)
	# Thornwarden: the heart-knot opens for the lanes and a burst there tears them out
	var tw := _spawn("res://core/enemy/thornwarden.gd", AT + Vector3(-8, 0, 0))
	await _frames(5)
	tw.alerted(null)
	tw._ward_t = 0.0
	tw.call("_thorn_lanes")
	await _frames(2)
	check("thornwarden: the knot opens for the lanes", tw.weak_open and (tw.get("_weak") as Node3D).is_visible_in_tree())
	var lanes := _zone_count(tw)
	tw.take_hit(1.0, _shot_at((tw.get("_weak") as Node3D).global_position))
	await _frames(2)
	check("thornwarden: a burst on the knot tears the lanes out", lanes >= 3 and _zone_count(tw) == 0 and tw.is_broken(), "%d lanes" % lanes)
	tw.set("phase", 2)
	tw.call("_snare")
	check("thornwarden: the snare rings you (with a gap)", _zone_count(tw) >= 10 and _zone_count(tw) < 14, str(_zone_count(tw)))
	tw.cancel_moves()
	tw.set("_lash_cd", 0.0)
	tw.set("_snare_t", 99.0)
	tw.set("_lanes_t", 99.0)
	tw.set("_stagger_cd", 9.0)
	var lashed := false
	for f in 120:
		await get_tree().physics_frame
		_put_player(tw.global_position + Vector3(0.6, 0, 0.4))
		tw._state = Enemy.RECOVER
		if float(tw.get("_lash_cd")) > 0.0:
			lashed = true
			break
	check("thornwarden: crowd under it and the bramble lash rings it", lashed)
	tw.queue_free()
	await _frames(3)
	# Abbot: the tithe walks out; the reliquary opens for the Requiem and two bursts break it
	_put_player(AT)
	var ab := _spawn("res://core/enemy/bone_abbot.gd", AT + Vector3(-10, 0, 0))
	await _frames(5)
	ab.alerted(null)
	ab._ward_t = 0.0
	ab.set("phase", 2)
	await _frames(2)
	ab.call("_tithe")
	check("abbot: the tithe line walks out toward you", _zone_count(ab) >= 4, str(_zone_count(ab)))
	ab.cancel_moves()
	ab.set("phase", 3)
	ab.call("_requiem")
	await _frames(2)
	check("abbot: the reliquary opens for the Requiem", ab.weak_open)
	var at := (ab.get("_weak") as Node3D).global_position
	ab.take_hit(1.0, _shot_at(at))
	ab.take_hit(1.0, _shot_at(at))
	await _frames(2)
	check("abbot: two bursts on it break the song", _zone_count(ab) == 0 and not ab.weak_open and ab.is_broken())
	ab.queue_free()
	await _frames(3)
	# Warden: the halo opens for a fan; eclipse holes are safe
	var wd := _spawn("res://core/enemy/ascended_warden.gd", AT + Vector3(-10, 0, 0))
	await _frames(5)
	wd._ward_t = 0.0
	wd.call("_aim_fan", false)
	await _frames(2)
	check("warden: the halo opens while its hands are up", wd.weak_open)
	wd.take_hit(1.0, _shot_at((wd.get("_weak") as Node3D).global_position))
	await _frames(2)
	check("warden: a burst on the halo scatters the fan", float(wd.get("_fan_t")) > 50.0 and wd.is_broken())
	var c := wd.global_position
	var holes := [[c + Vector3(5, 0, 0), 2.3]]
	check("eclipse: a pillar of light is safe", not BossKit.inside(c + Vector3(5.5, 0.5, 0), c, {"radius": 10.0, "holes": holes}))
	check("eclipse: the rest of the dais is not", BossKit.inside(c + Vector3(-5.0, 0.5, 0), c, {"radius": 10.0, "holes": holes}))
	wd.set("anchors", [c + Vector3(6, 0, 0), c + Vector3(-6, 0, 0), c + Vector3(0, 0, 6)] as Array[Vector3])
	wd.set("_arena_c", c)
	wd.call("_eclipse")
	check("warden: the eclipse fills the dais", _zone_count(wd) >= 1)
	wd.queue_free()
	await _frames(3)


func _depth() -> void:
	var keep: Variant = Travel.systems.get("progression")
	Travel.systems["progression"] = {"tier": 12}
	check("the wanderer's growth does not deepen the night", Tiers.night_depth() == Travel.bosses_slain.size())
	if keep == null:
		Travel.systems.erase("progression")
	else:
		Travel.systems["progression"] = keep
	var w := (load("res://core/enemy/wretch.gd") as GDScript).new() as Enemy
	var c0 := w.combo_chance
	var f0 := w.feint_chance
	var wt := w.windup_time
	Tiers.scale_stats(w, 4)
	check("depth buys chains and feints", w.combo_chance > c0 and w.feint_chance > f0, "%.2f %.2f" % [w.combo_chance, w.feint_chance])
	check("depth never shortens a tell", is_equal_approx(w.windup_time, wt))
	w.free()
