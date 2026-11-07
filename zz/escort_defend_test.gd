extends Node
## The live task steps, headless: godot --headless --path . res://zz/escort_defend_test.tscn
## escort (the Mere ferry's passenger) and defend (the Orchard graft, the Moor's middle cairn):
## the data audits clean; the runner stands the node up when the step is current; a defend's clock
## runs, its waves spawn, foes at it break it and the step resets in place (the task stays on the
## step); held out, the task moves on. An escort walks, waits when the wanderer is far, stops
## under attack, falls and stands again at its last waypoint, and arrives. Nothing is left behind
## when the step is over. Ends: ESCORT PASS / ESCORT FAIL n
## Holds Travel._busy (no save) and puts Travel.story back after.

const Chains := preload("res://core/story/quest_chains.gd")
const Book := preload("res://core/story/quest_book.gd")
const Runner := preload("res://core/story/quest_runner.gd")
const Kit := preload("res://core/story/encounter_kit.gd")
const Escort := preload("res://core/story/escort.gd")
const Defend := preload("res://core/story/defend.gd")

var bad := 0
var runner: Node


func ok(c: bool, what: String) -> void:
	print(("ESCORT ok   " if c else "ESCORT FAIL ") + what)
	if not c:
		bad += 1


func _init() -> void:
	Engine.set_meta(&"full_night", true)


func _ready() -> void:
	Travel._busy = true
	var story0: Dictionary = Travel.story.duplicate(true)
	Travel.story = {}
	runner = Runner.new()
	add_child(runner)
	_data()
	await _defend()
	await _escort()
	runner.queue_free()
	await get_tree().process_frame
	ok(get_tree().get_nodes_in_group("escort").is_empty() and get_tree().get_nodes_in_group("defend").is_empty(), "no live step node outlives the runner")
	Travel.story = story0
	print("ESCORT %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	get_tree().quit(0 if bad == 0 else 1)


func _data() -> void:
	ok(Chains.audit().is_empty(), "the quest audit is clean %s" % [Chains.audit()])
	var kinds := {}
	for id: String in ["mere_ferry", "orchard_stand", "moor_fires"]:
		for s: Dictionary in Chains.QUESTS[id].steps:
			kinds[String(s.kind)] = true
	ok(kinds.has("escort") and kinds.has("defend"), "the signature tasks use both live kinds")
	ok(not Chains.PICKUPS.has("ferry_lamp_back"), "the ferry's second lamp is gone with its step")


## A wide floor a metre under `at`: the bare test scene has no terrain, and foes would fall through.
func _floor(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 2.0, 400.0)
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector3(at.x, at.y - 2.0, at.z)
	return body


## Put the task on step `s` (a fresh book) and let the runner stand its node up.
func _to_step(id: String, s: int) -> void:
	Book.start(id)
	Book.advance(id, s)
	runner.check()


func _defend() -> void:
	_to_step("orchard_stand", 2)
	var d: Defend = runner.get("_enc").get("orchard_stand") as Defend
	ok(d != null and is_instance_valid(d), "the runner stands the graft up on its step")
	if d == null:
		return
	ok(Book.step("orchard_stand") == 2 and d.hp == d.max_hp, "the graft begins whole")
	var ground := _floor(d.global_position)
	d.tick(9.0)
	ok(d.time_left < 82.0 and d.time_left > 80.0, "the clock runs while nobody is away (%.1f s left)" % d.time_left)
	ok(not d.foes.is_empty(), "the first wave came (%d foes)" % d.foes.size())
	var wave_ward := true
	for f: Enemy in d.foes:
		wave_ward = wave_ward and f.ward == d and f.is_in_group(Groups.ENEMY)
	ok(wave_ward and d.is_in_group(Groups.WARD_TARGET), "the wave's foes are sent at the graft, which is a ward target")
	# foes nowhere near it do not wound it (the old proximity wound is gone)
	Kit.clear_foes(d.foes)
	var idle := Kit.spawn_foe(d, "wretch", d.global_position, "orchard_stand")
	idle.process_mode = Node.PROCESS_MODE_DISABLED
	var h_idle := d.hp
	d.tick(2.0)
	ok(d.hp >= h_idle, "a foe standing at it that is not sent at it does no harm (%.1f -> %.1f)" % [h_idle, d.hp])
	idle.queue_free()
	# a sent foe takes a swing at it: the real blow lands through threat_hit
	var foe := Kit.spawn_foe(d, "wretch", d.global_position + Vector3(3.0, 0.0, 0.0), "orchard_stand", d)
	ok(foe != null and foe.ward == d, "a foe can be sent at the graft")
	d.foes.append(foe)
	var seen := {"hits": 0, "dmg": 0.0}
	d.struck.connect(func(x: float) -> void:
		seen.hits += 1
		seen.dmg += x)
	var h0 := d.hp
	var fr := 0
	while seen.hits == 0 and fr < 900:
		await get_tree().physics_frame
		fr += 1
	ok(seen.hits > 0 and d.hp < h0, "a sent foe's swing wounds the graft (%d frames, %.1f -> %.1f)" % [fr, h0, d.hp])
	ok(foe._on_threat, "it was going for the graft, not for a wanderer")
	var h1 := d.hp
	d.threat_hit(2.5, foe)
	ok(absf((h1 - d.hp) - 2.5) < 0.01, "a hit to the graft costs it exactly that much (%.1f -> %.1f)" % [h1, d.hp])
	# a spat orb thrown at it lands too (a spitter's real shot); one not thrown at it flies through
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	var h2 := d.hp
	var stray := SpitOrb.launch(self, d.global_position + Vector3(0.0, 1.2, 4.0), Vector3(0.0, 0.0, -1.0), 10.0)
	for i in 60:
		await get_tree().physics_frame
	ok(d.hp == h2, "an orb not thrown at it does not wound it (%.1f -> %.1f)" % [h2, d.hp])
	var orb := SpitOrb.launch(self, d.global_position + Vector3(4.0, 1.2, 0.0), Vector3(-1.0, 0.0, 0.0), 10.0)
	orb.at_ward = true
	for i in 60:
		await get_tree().physics_frame
	ok(absf((h2 - d.hp) - 10.0 * WardTarget.SPIT) < 0.01, "a spat orb thrown at it wounds it through threat_hit (%.1f -> %.1f)" % [h2, d.hp])
	if is_instance_valid(stray):
		stray.queue_free()
	foe.process_mode = Node.PROCESS_MODE_INHERIT
	# hitting the foe pulls it onto the wanderer; far from her it goes back to the graft
	var hitter := Node3D.new()
	hitter.add_to_group(Groups.PLAYER)
	add_child(hitter)
	ok(foe.prefers_threat(10.0), "a wanderer ten metres off: it keeps on at the graft")
	ok(not foe.prefers_threat(3.0), "a wanderer inside the aggro range pulls it onto her")
	foe.take_hit(0.1, hitter)
	ok(not foe.prefers_threat(10.0), "a hit from the wanderer pulls it onto her")
	ok(foe.prefers_threat(20.0), "and when she is far beyond reach it goes back to the graft")
	hitter.queue_free()
	# unopposed foes at the graft break it, in a time the wanderer can answer, and the step resets in place
	Kit.clear_foes(d.foes)
	for i in 3:
		var f := Kit.spawn_foe(d, "wretch", d.global_position + Vector3(3.0, 0.0, float(i) - 1.0), "orchard_stand", d)
		if f:
			d.foes.append(f)
	var f0 := Engine.get_physics_frames()
	while is_instance_valid(d) and d.resets == 0 and Engine.get_physics_frames() - f0 < 60 * 90:
		await get_tree().physics_frame
	var t := float(Engine.get_physics_frames() - f0) / 60.0
	ok(d.resets == 1, "foes left at the graft break it (%.1f s)" % t)
	ok(t >= 10.0, "but not so fast the wanderer has no answer (%.1f s unopposed)" % t)
	ok(Book.step("orchard_stand") == 2 and Book.active("orchard_stand"), "a broken graft resets the step, not the task")
	ok(d.hp == d.max_hp and d.elapsed == 0.0 and d.foes.is_empty(), "health, clock and foes are reset")
	d.tick(4.0)
	# a wanderer who leaves stops the clock
	var far := Node3D.new()
	far.add_to_group(Groups.PLAYER)
	add_child(far)
	far.global_position = d.global_position + Vector3(60.0, 0.0, 0.0)
	var before := d.elapsed
	d.tick(5.0)
	ok(d.away and d.elapsed == before, "the clock stops while the wanderer is away")
	far.global_position = d.global_position + Vector3(2.0, 0.0, 0.0)
	# held: run it out, killing what comes
	var guard := 0
	while not d.done and guard < 600:
		Kit.clear_foes(d.foes)
		d.tick(0.5)
		guard += 1
	ok(d.done, "held out, the defend ends (elapsed %.1f, left %.1f, hp %.1f, resets %d, away %s, guard %d)" % [d.elapsed, d.time_left, d.hp, d.resets, d.away, guard])
	ok(not Book.active("orchard_stand") or Book.step("orchard_stand") == 3, "the task moved on to the turn-in")
	runner.check()
	ok(runner.get("_enc").is_empty(), "the node is released when the step moves on")
	ground.queue_free()
	far.queue_free()
	await get_tree().process_frame


func _escort() -> void:
	_to_step("mere_ferry", 2)
	var e: Escort = runner.get("_enc").get("mere_ferry") as Escort
	ok(e != null and is_instance_valid(e), "the runner stands the passenger up on the escort step")
	if e == null:
		return
	var ground := _floor(e.global_position)
	var p0: Vector2 = e.path[0]
	ok(Vector2(e.global_position.x - p0.x, e.global_position.z - p0.y).length() < 0.5, "she begins at the east landing")
	# far wanderer: she waits
	var pl := Node3D.new()
	pl.add_to_group(Groups.PLAYER)
	add_child(pl)
	pl.global_position = Vector3(p0.x + 60.0, 0.0, p0.y)
	e.tick(2.0)
	ok(e.waiting and e.walked == 0.0, "she waits while the wanderer is far")
	pl.global_position = Vector3(p0.x, 0.0, p0.y)
	for i in 8:
		e.tick(0.25)
	ok(not e.waiting and e.walked > 0.5, "she walks when the wanderer is near (%.1f m, attacked %.1f, wp %d, down %.1f)" % [e.walked, e.attacked, e.next_wp, e.down])
	# a foe sent at her: she stops, and its swing wounds her
	var foe := Kit.spawn_foe(e, "wretch", e.global_position + Vector3(3.0, 0.0, 0.0), "mere_ferry", e)
	if foe:
		e.foes.append(foe)
	ok(foe != null and foe.ward == e, "a foe can be put in the road, sent at her")
	var w0 := e.walked
	var h0 := e.hp
	var fr := 0
	while e.hp >= h0 and fr < 900:
		await get_tree().physics_frame
		fr += 1
	ok(e.walked == w0 or e.attacked > 0.0, "under attack she stops")
	ok(e.hp < h0, "its swing wounds her (%.1f -> %.1f, %d frames)" % [h0, e.hp, fr])
	var h1 := e.hp
	e.threat_hit(2.0, foe)
	ok(absf((h1 - e.hp) - 2.0) < 0.01, "a hit to her costs exactly that much (%.1f -> %.1f)" % [h1, e.hp])
	ok(not foe.prefers_threat(3.0), "the wanderer close by pulls the foe onto her")
	foe.take_hit(0.1, pl)
	ok(not foe.prefers_threat(10.0) and foe.prefers_threat(20.0), "a hit from her pulls it onto her until she is lost")
	# she falls and stands again at the last waypoint
	var cp := e.checkpoint
	e.threat_hit(e.hp + 1.0, foe)
	e.tick(0.3)
	ok(e.falls == 1 and e.down > 0.0, "she falls when her health is gone")
	ok(Book.step("mere_ferry") == 2 and Book.active("mere_ferry"), "the task stays on the step")
	e.tick(5.0)
	var cpp: Vector2 = e.path[cp]
	ok(e.down <= 0.0 and e.hp == e.max_hp, "she stands again with full health")
	ok(Vector2(e.global_position.x - cpp.x, e.global_position.z - cpp.y).length() < 1.0, "at the last waypoint reached (%d)" % cp)
	# the rest of the road
	var guard := 0
	while not e.done and guard < 4000:
		pl.global_position = e.global_position + Vector3(2.0, 0.0, 0.0)
		Kit.clear_foes(e.foes)
		for f: Enemy in Kit.foes_near(get_tree(), e.global_position, 30.0):
			f.hp = 0.0
		e.tick(0.25)
		guard += 1
	ok(e.done, "she comes to the end of the road (cp %d, wp %d, hp %.1f, falls %d, walked %.1f, waiting %s, att %.1f, guard %d)" % [e.checkpoint, e.next_wp, e.hp, e.falls, e.walked, e.waiting, e.attacked, guard])
	ok(Book.step("mere_ferry") == 3, "the task moves on to the turn-in")
	runner.check()
	ok(runner.get("_enc").is_empty(), "the passenger is released when the step moves on")
	ground.queue_free()
	pl.queue_free()
	await get_tree().process_frame
