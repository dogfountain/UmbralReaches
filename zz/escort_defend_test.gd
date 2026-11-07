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
	d.tick(9.0)
	ok(d.time_left < 82.0 and d.time_left > 80.0, "the clock runs while nobody is away (%.1f s left)" % d.time_left)
	ok(not d.foes.is_empty(), "the first wave came (%d foes)" % d.foes.size())
	# foes at the graft wound it until it breaks, and the step resets in place
	Kit.clear_foes(d.foes)
	for i in 3:
		var f := Kit.spawn_foe(d, "wretch", d.global_position, "orchard_stand")
		if f:
			d.foes.append(f)
	var t := 0.0
	while d.resets == 0 and t < 120.0:
		d.tick(0.25)
		t += 0.25
	ok(d.resets == 1, "foes at the graft break it (%.1f s)" % t)
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
	far.queue_free()
	await get_tree().process_frame


func _escort() -> void:
	_to_step("mere_ferry", 2)
	var e: Escort = runner.get("_enc").get("mere_ferry") as Escort
	ok(e != null and is_instance_valid(e), "the runner stands the passenger up on the escort step")
	if e == null:
		return
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
	# a foe on her: she stops and is wounded
	var foe := Kit.spawn_foe(e, "wretch", e.global_position, "mere_ferry")
	if foe:
		e.foes.append(foe)
	ok(foe != null, "a foe can be put in the road")
	var w0 := e.walked
	var h0 := e.hp
	for i in 6:
		e.tick(0.25)
	ok(e.walked == w0 and e.hp < h0, "under attack she stops and is hurt (%.1f -> %.1f)" % [h0, e.hp])
	# she falls and stands again at the last waypoint
	var cp := e.checkpoint
	var t := 0.0
	while e.falls == 0 and t < 60.0:
		e.tick(0.25)
		t += 0.25
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
	pl.queue_free()
	await get_tree().process_frame
