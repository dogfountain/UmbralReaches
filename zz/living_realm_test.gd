extends Node
## The living Realm (docs/living_realm.md), headless:
##   godot --headless --path . res://zz/living_realm_test.tscn
## Rosters: every Far Reaches region has its life. Signs: carrion, kettles, lights, eyes; the eyes and lights go out
## with a hollowed thing near; howls are called and answered. Wayfarers: parties on the safe ways (never within a
## camp's reach), made real near the camera and put away far off, walking along their way; a party greets the
## wanderer, turns back from a hollowed thing, rests at a fire it reaches.
## Ends LIVING TEST PASS / LIVING TEST FAIL n.
const Reaches := preload("res://core/life/wildlife/life_reaches.gd")

var t := 0.0
var fails := 0
var main: Node
var started := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(ok: bool, msg: String) -> void:
	if ok:
		print("LIVING ok  ", msg)
	else:
		fails += 1
		print("LIVING FAIL ", msg)


func _process(d: float) -> void:
	t += d
	if started:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).has_meta("life_fake") and not (e as Node).is_queued_for_deletion():
				(e as Node).queue_free()
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wayfarers") == null:
		if t > 220.0:
			check(false, "the Realm, the wildlife or the wayfarers never finished")
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
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	var y := RealmLayout.ground(pl.get_world_3d().direct_space_state, p.x, p.z)
	pl.global_position = Vector3(p.x, maxf(y, p.y) + 0.2, p.z)
	pl.velocity = Vector3.ZERO
	await _frames(3)


func _fake(at: Vector3) -> Node3D:
	var f := Node3D.new()
	f.add_to_group(Groups.ENEMY)
	f.set_meta("life_fake", true)
	main.add_child(f)
	f.global_position = at
	return f


func _run() -> void:
	await _secs(1.0)
	var w: Node = main.get_node("Wildlife")
	# ---- rosters
	var rep: Dictionary = Reaches.report
	var missing: Array[String] = []
	for rid: String in RealmReaches.IDS:
		if not rep.has(rid) and rid != "lastlight":
			missing.append(rid)
	check(missing.is_empty(), "every Far Reaches region has its roster's life (missing %s)" % [missing])
	var counts: Dictionary = w.get("counts")
	check(int(counts.get("crow", 0)) > 120 and int(counts.get("hare", 0)) > 40 and int(counts.get("fox", 0)) > 12, "ravens, hares and foxes across the doubled Realm (%s)" % [counts])
	# ---- signs
	var sg: Node = w.get("signs")
	check(sg != null, "the signs are built")
	if sg != null:
		check((sg.get("carrion") as Array).size() >= 3, "carrion by the far tracks (%d)" % (sg.get("carrion") as Array).size())
		check((sg.get("kettles") as Array).size() >= 10, "ravens wheeling over the dead, the landmarks and the camps (%d)" % (sg.get("kettles") as Array).size())
		check((sg.get("fields") as Array).size() >= 8, "cold lights over the meres, the barrows and the Lanternwood (%d)" % (sg.get("fields") as Array).size())
		check((sg.get("eyes") as Array).size() >= 6, "eyes at the wood edges (%d)" % (sg.get("eyes") as Array).size())
		var eye: MultiMeshInstance3D = (sg.get("eyes") as Array)[0]
		await _put(eye.global_position + Vector3(30, 0, 0))
		var f := _fake(eye.global_position + Vector3(4, 0.5, 0))
		await _secs(1.6)
		check(float(eye.get_meta(&"on", 1.0)) == 0.0, "a pair of eyes goes out with a hollowed thing near")
		f.queue_free()
		await _secs(1.6)
		check(float(eye.get_meta(&"on", 1.0)) == 1.0, "and comes back when it is gone")
		var h0 := int(sg.get("howls"))
		sg.call("call_howl", eye.global_position)
		await _secs(10.0)
		check(int(sg.get("howls")) >= h0 + 2, "a howl far off, and an answer (%d calls)" % (int(sg.get("howls")) - h0))
	# ---- wayfarers
	var wf: Node = main.get_node("Wayfarers")
	var parties: Array = wf.get("parties")
	check(parties.size() >= 15, "parties on the roads (%d)" % parties.size())
	check((wf.get("havens") as Array).size() >= 30, "havens: towns, fires, posts (%d)" % (wf.get("havens") as Array).size())
	var camps := Reaches.keep_camps()
	var near_camp := 0
	for p: Dictionary in parties:
		var line: PackedVector2Array = p.route
		for k in range(4, maxi(line.size() - 4, 4)):
			for c: Vector2 in camps:
				if line[k].distance_to(c) < 18.0:
					near_camp += 1
					break
	check(near_camp == 0, "no way walked within a camp's reach (%d points)" % near_camp)
	# far parties are put away: hidden, not processing, no collider
	var far_ok := true
	for p: Dictionary in parties:
		if not bool(p.near):
			for v: Node3D in p.people:
				if v.visible or v.process_mode != Node.PROCESS_MODE_DISABLED or int((v.get("body") as CollisionObject3D).collision_layer) != 0:
					far_ok = false
	check(far_ok, "parties far from the camera are put away (hidden, still, no collider)")
	# a walking party: go to it; its people come alive and walk
	var party: Dictionary = {}
	for p: Dictionary in parties:
		if int(p.state) == 0 and float(p.s) > 15.0 and float(p.s) < float((p.cum as PackedFloat32Array)[(p.cum as PackedFloat32Array).size() - 1]) - 40.0:
			party = p
			break
	check(not party.is_empty(), "a party out walking")
	if party.is_empty():
		_end()
		return
	var lead_xz: Vector2 = wf.call("_lead_xz", party)
	var ahead: Vector2 = wf.call("_pos", party, float(party.s) + 30.0)
	var side := (ahead - lead_xz).orthogonal().normalized() * 14.0
	await _put(Vector3(lead_xz.x + side.x, 0, lead_xz.y + side.y))
	await _secs(1.5)
	check(bool(party.near), "%s come alive near the camera" % party.name)
	var lead: Node3D = party.people[0]
	check(lead.visible and lead.process_mode == Node.PROCESS_MODE_INHERIT, "and are drawn and walking")
	var s0 := float(party.s)
	var w0 := float(lead.get("walked"))
	await _secs(4.0)
	check(float(party.s) > s0 + 1.5 and float(lead.get("walked")) > w0 + 1.5, "along their way (%.1f -> %.1f m, walked %.1f m)" % [s0, float(party.s), float(lead.get("walked")) - w0])
	# greet: stand in front of the leader
	if int(party.state) == 0:
		var g0 := int(wf.get("greets"))
		var fwd: Vector2 = (wf.call("_pos", party, float(party.s) + 5.0) as Vector2)
		await _put(Vector3(fwd.x, 0, fwd.y))
		await _secs(2.0)
		check(int(wf.get("greets")) > g0, "the leader stops and greets the wanderer")
		await _secs(3.5)
	# a hollowed thing on the way ahead: they turn back (or a patrol stands)
	var g_xz: Vector2 = wf.call("_lead_xz", party)
	await _put(Vector3(g_xz.x + side.x * 1.4, 0, g_xz.y + side.y * 1.4))
	await _secs(1.0)
	var fl0 := int(wf.get("flights"))
	var a2: Vector2 = wf.call("_pos", party, float(party.s) + float(party.dir) * 12.0)
	var foe := _fake(Vector3(a2.x, RealmLayout.ground(null, a2.x, a2.y) + 0.5, a2.y))
	await _secs(2.0)
	var st := int(party.state)
	check(int(wf.get("flights")) > fl0 or st == 4, "a hollowed thing ahead: they turn back or stand (state %d)" % st)
	if st == 3:
		var hurry := float(lead.get("hurry"))
		check(hurry > 1.5, "and hurry (x%.1f)" % hurry)
	foe.queue_free()
	# the far: put the wanderer far off; they are put away again
	await _put(Vector3(lead.global_position.x + 160.0, 0, lead.global_position.z))
	await _secs(1.5)
	check(not bool(party.near) and not lead.visible, "put away again when the camera is far")
	# a fire: force a party to arrive at a lit fire near the camera and see it rest
	var fire_h := -1
	var havens: Array = wf.get("havens")
	for hi in havens.size():
		var h: Dictionary = havens[hi]
		if String(h.kind) == "fire" and bool(wf.call("_lit", h)):
			fire_h = hi
			break
	if fire_h >= 0:
		var hp: Vector2 = havens[fire_h].at
		await _put(Vector3(hp.x + 12.0, 0, hp.y))
		await _secs(1.0)
		party.to = fire_h
		party.dir = 1.0
		wf.call("_arrive", party)
		await _secs(1.5)
		check(int(party.state) == 1 and String(party.act) != "", "%s rest at a lit fire (%s)" % [party.name, party.act])
	_end()


func _end() -> void:
	print("LIVING TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)
