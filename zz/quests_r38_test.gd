extends Node
## r38 tasks (twelve one-time tales of the east, south and west; headless, in the built world): each is started (offered
## by its giver, or found in the world), stepped through with the real pickups, conversations, lamps, live steps and
## conditions, and handed in; everything they name resolves.
##   data     the chains audit; every task has 3-5 steps, a reward and gear to choose; every place is on the map;
##            every enemy kind, rare, elite, conversation, secret and lamp they name exists; the horse runs are
##            tighter than a walk; the boss-ground runs end at or pass a boss's ground
##   givers   every giver stands in the world with the gold mark; a found task is offered by nobody
##   found    each found task starts only close to its body or grave, and leaves a lit thing standing when done
##   chains   each task played through (the hauler's tally both ways: whole and torn), handed in, paid, its outcome standing
## Never writes the player's save (Travel._busy); Travel's progress is put back before quitting.
## Ends: QUESTS R38 TEST PASS  /  QUESTS R38 TEST FAIL n

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Giver := preload("res://core/story/quest_giver.gd")
const Kit := preload("res://core/story/encounter_kit.gd")
const Runner := preload("res://core/story/quest_runner.gd")
const QuestWorld := preload("res://core/story/quest_world.gd")
const DialogueDB := preload("res://core/story/dialogue_db.gd")
const TalkDB := preload("res://core/life/village/village_talk_db.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Rares := preload("res://core/enemy/rares.gd")
const Elites := preload("res://core/life/encounters/elites.gd")
const State := preload("res://core/life/secrets/state.gd")
const GearStats := preload("res://core/items/gear_stats.gd")

const MINE := ["pans_hauler", "pans_pan", "salt_barrel", "bitter_mother", "drover_tally", "long_round", "bryn_iron", "wren_gran",
	"plinth_lamp", "cutters_pledge", "landing_staves", "moor_niches"]
const FOUND := ["pans_hauler", "drover_tally", "plinth_lamp"]
const HORSE := ["salt_barrel", "drover_tally", "long_round", "plinth_lamp"]          ## a horse's errand, or a route not otherwise taken
const BOSS_GROUND := ["bryn_iron", "wren_gran", "plinth_lamp", "landing_staves"]    ## end at, or pass, a boss's ground without the boss
const WALK := 4.5
const GALLOP := 9.5

var fails := 0
var t := 0.0
var started := false
var village: Node3D
var story: Node
var markers: Node
var runner: Node
var quests: Node
var player: Node3D
var _travel := {}
var _main: Node


func _init() -> void:
	Engine.set_meta(&"full_night", true)


func ok(c: bool, what: String) -> void:
	if c:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for key: String in ["seals_broken", "bosses_slain", "items", "story", "lit_by_path", "systems"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
	Travel.seals_broken = {}
	Travel.bosses_slain = {}
	Travel.items = {}
	Travel.lit_by_path = {}
	Travel.systems = {}
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	VState.sandbox = {}
	VState.kindled_override = 4
	Book.quiet = true
	_data()
	_main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)


func _process(d: float) -> void:
	t += d
	if started:
		return
	village = get_tree().root.find_child("Village", true, false) as Node3D
	if village == null or not village.has_meta("village_done") or not _main.has_meta("realm_done"):   # (the lamps build last)
		if t > 240.0:
			ok(false, "the village never finished building")
			_end()
		return
	started = true
	_run()


func _end() -> void:
	get_tree().paused = false
	for key: String in _travel:
		Travel.set(key, _travel[key])
	VState.sandbox = null
	VState.kindled_override = -1
	Book.day_override = ""
	Book.quiet = false
	Runner.chance_override = -1.0
	print("QUESTS R38 TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _v(id: String) -> Node3D:
	return (village.get("villagers") as Dictionary).get(id)


func _pts(id: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var qd: Dictionary = Chains.QUESTS[id]
	if qd.has("found_at"):
		out.append(qd.found_at)
	for s: Dictionary in qd.steps:
		for key: String in ["at", "to"]:
			if s.get(key) is Vector2:
				out.append(s[key])
		for p: Variant in s.get("path", []):
			out.append(p as Vector2)
	for k: String in Chains.PICKUPS:
		if String(Chains.PICKUPS[k].quest) == id:
			out.append(Chains.PICKUPS[k].near)
	return out


func _boss_near(p: Vector2) -> bool:
	for r: Dictionary in RealmLayout.RAIDS:
		if p.distance_to(r.c as Vector2) < float(r.r) + 30.0:
			return true
	var o := RealmLayout.OSSUARY
	return Rect2(o.position.x, o.position.z, o.size.x, o.size.z).grow(4.0).has_point(p)


# --- data -------------------------------------------------------------------------------------------------

func _data() -> void:
	print("data")
	ok(Chains.audit().is_empty(), "chains audit %s" % [Chains.audit()])
	ok(DialogueDB.audit().is_empty(), "dialogue audit %s" % [DialogueDB.audit()])
	ok(MINE.size() == 12, "twelve tasks")
	var kinds := 0
	for id: String in MINE:
		var qd: Dictionary = Chains.QUESTS.get(id, {})
		ok(not qd.is_empty() and id in Chains.ORDER, "%s is a task in the ledger's order" % id)
		if qd.is_empty():
			continue
		var n := (qd.steps as Array).size()
		ok(n >= 3 and n <= 5, "%s: %d steps" % [id, n])
		ok(String(qd.get("repeat", "")) == "", "%s is one-time" % id)
		ok(int((qd.get("reward", {}) as Dictionary).get("ash", 0)) >= 14 and not (qd.get("choose", []) as Array).is_empty(), "%s pays ash and offers gear" % id)
		ok(qd.has("outcome") and not (qd.outcome as Dictionary).is_empty(), "%s has an ending" % id)
		ok(_pts(id).all(func(p: Vector2) -> bool: return RealmLayout.BOUNDS.has_point(p)), "%s: every place is on the map" % id)
		ok(Chains.GIVER_NAMES.has(Chains.giver(id)) and TalkDB.CONV.has(Chains.giver(id)), "%s: giver %s has a name and talks" % [id, Chains.giver(id)])
		var who := Giver.turnin_of(id)
		ok(Chains.GIVER_NAMES.has(who) and TalkDB.CONV.has(who), "%s: the hand-in is to %s, who talks" % [id, who])
		var shapes := {}
		for s2: Dictionary in qd.steps:
			shapes[String(s2.kind)] = true
			for rid: String in s2.get("rares", []):
				ok(Rares.RARES.has(rid), "%s: rare %s exists" % [id, rid])
			var c := String(s2.get("cond", ""))
			if c.begins_with("elite:"):
				ok(Elites.ELITES.has(c.trim_prefix("elite:")), "%s: elite %s exists" % [id, c])
			var foes: Array = []
			foes.append_array(s2.get("kinds", []))
			for w: Dictionary in s2.get("waves", []):
				foes.append_array(w.kinds)
			for a: Variant in (s2.get("ambush", {}) as Dictionary).values():
				foes.append_array((a as Dictionary).kinds)
			for f: String in foes:
				ok(ResourceLoader.exists("res://core/enemy/%s.gd" % f), "%s: enemy kind %s exists" % [id, f])
		ok(shapes.size() >= 3, "%s mixes %d step kinds %s" % [id, shapes.size(), shapes.keys()])
		for r2: Variant in (qd.get("reward", {}).get("items", {}) as Dictionary):
			ok(not ItemDB.def(String(r2)).is_empty(), "%s: reward item %s exists" % [id, r2])
		for k: String in Chains.PICKUPS:
			var p: Dictionary = Chains.PICKUPS[k]
			if String(p.quest) == id and p.has("conv"):
				ok(DialogueDB.CONV.has(String(p.conv)), "%s: %s opens conversation %s" % [id, k, p.conv])
		if id in FOUND:
			kinds += 1
			ok(qd.has("found_at") and qd.has("found_say") and qd.has("found_r"), "%s is found in the world" % id)
			ok(not Giver.available(id), "%s is offered by nobody" % id)
		if id in HORSE:
			for si in (qd.steps as Array).size():
				var stp: Dictionary = qd.steps[si]
				if String(stp.kind) == "carry":
					var from: Vector2 = Chains.PICKUPS[stp.from].near
					var v := from.distance_to(stp.to as Vector2) / float(stp.time)
					print("       %s carries %.0f m in %.0f s: %.1f m/s (walk %.1f, gallop %.1f)" % [id, from.distance_to(stp.to as Vector2), float(stp.time), v, WALK, GALLOP])
					ok(v < GALLOP, "%s: a horse makes the carry" % id)
					ok(v > 3.0, "%s: the carry is no stroll" % id)
		if id in BOSS_GROUND:
			ok(_pts(id).any(func(p: Vector2) -> bool: return _boss_near(p)), "%s ends at or passes a boss's ground" % id)
			ok(not _requires_boss(id), "%s does not require the boss" % id)
	ok(kinds == 3, "three tasks are found in the world")
	ok(HORSE.size() >= 4, "%d tasks want a horse or a route not otherwise taken" % HORSE.size())
	ok(BOSS_GROUND.size() >= 3, "%d tasks end at or pass a boss's ground" % BOSS_GROUND.size())


func _requires_boss(id: String) -> bool:
	for s: Dictionary in Chains.QUESTS[id].steps:
		if String(s.get("cond", "")).begins_with("boss:"):
			return true
	return false


# --- the run ----------------------------------------------------------------------------------------------

func _run() -> void:
	story = get_tree().get_first_node_in_group("story")
	markers = story.get("markers") if story else null
	runner = story.get("runner") if story else null
	quests = village.get("quests")
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var have := story != null and markers != null and runner != null and quests != null and player != null
	ok(have, "pieces present (story, marks, runner, quests, wanderer)")
	if not have:
		_end()
		return
	village.set("clock", 600.0 * 0.2)
	village.set("time_scale", 0.0)
	await _frames(3)
	_floors()
	_lamps_and_secrets()
	_givers()
	Runner.chance_override = 1.0
	for id: String in MINE:
		await _chain(id, 0)
	await _chain("pans_hauler", 1)
	Runner.chance_override = -1.0
	_end()


func _refresh() -> void:
	markers.call("_find_givers")
	markers.call("refresh")


func _floors() -> void:
	print("floors")
	for line: String in QuestWorld.report:
		ok(false, "quest spots: %s" % line)
	for k: String in Chains.PICKUPS:
		var p: Dictionary = Chains.PICKUPS[k]
		if not String(p.quest) in MINE:
			continue
		var at: Vector3 = QuestWorld.spots.get(k, Vector3.INF)
		var near := p.near as Vector2
		var d := Vector2(at.x - near.x, at.z - near.y).length() if at != Vector3.INF else INF
		if p.has("camp"):
			var f: Vector3 = village.call("anchor", "@fire_" + String(p.camp))
			ok(f != Vector3.INF and Vector2(at.x - f.x, at.z - f.z).length() < 4.0, "%s waits by %s's fire (%.1f m)" % [k, p.camp, Vector2(at.x - f.x, at.z - f.z).length()])
		else:
			ok(at != Vector3.INF and d < 8.0, "%s found a floor %.1f m from its place" % [k, d])
	for id: String in MINE:
		var qd: Dictionary = Chains.QUESTS[id]
		for key: String in ["found_", "stand_"]:
			if (key == "found_" and qd.has("found_at")) or (key == "stand_" and qd.has("stands")):
				var want: Vector2 = qd.found_at if key == "found_" else qd.stands.at
				var at2: Vector3 = QuestWorld.spots.get(key + id, Vector3.INF)
				ok(at2 != Vector3.INF and Vector2(at2.x - want.x, at2.z - want.y).length() < 8.0, "%s: %s spot found (%.1f m)" % [id, key, Vector2(at2.x - want.x, at2.z - want.y).length() if at2 != Vector3.INF else -1.0])


func _lamp_node(lid: String) -> Node:
	for n: Node in get_tree().get_nodes_in_group(&"lamp"):
		if String(n.get("lamp_id")) == lid:
			return n
	return null


func _lamps_and_secrets() -> void:
	print("lamps and secrets")
	var site_ids := State.sites.map(func(s: Dictionary) -> String: return String(s.id))
	for id: String in MINE:
		for s: Dictionary in Chains.QUESTS[id].steps:
			var c := String(s.get("cond", ""))
			if c.begins_with("secret:lamps:"):
				var lid := c.trim_prefix("secret:lamps:")
				var ln := _lamp_node(lid)
				ok(ln != null, "%s: lamp %s stands in the world" % [id, lid])
				if ln != null:
					var at := Vector2((ln as Node3D).global_position.x, (ln as Node3D).global_position.z)
					ok(at.distance_to(s.at as Vector2) < 14.0, "%s: lamp %s is %.1f m from the step's pin" % [id, lid, at.distance_to(s.at as Vector2)])
			elif c.begins_with("secret:"):
				var sid := c.split(":")[2]
				ok(site_ids.has(sid), "%s: secret %s is registered" % [id, sid])


func _givers() -> void:
	print("givers")
	_refresh()
	for id: String in MINE:
		var qd: Dictionary = Chains.QUESTS[id]
		var giver := Chains.giver(id)
		var v := _v(giver)
		ok(v != null, "%s stands in the world (%s)" % [giver, id])
		if v == null:
			continue
		var gy := v.global_position.y
		var ground := RealmLayout.ground(v.get_world_3d().direct_space_state, v.global_position.x, v.global_position.z)
		ok(absf(gy - ground) < 1.2, "%s's feet are on the ground (%.2f over it)" % [giver, gy - ground])
		if id in FOUND:
			ok(Giver.available(id, get_tree()) == false, "%s is not on offer from %s" % [id, giver])
		else:
			ok(Giver.available(id, get_tree()), "%s is offered" % id)
			var m: Variant = markers.call("mark_of", v)
			ok(String(m) == "available", "%s wears the gold mark for %s (%s)" % [giver, id, m])
		print("       %s stands at (%.1f, %.1f)" % [giver, v.global_position.x, v.global_position.z])


## Play a task through; `choice` picks the conversation answer of a pickup that asks.
func _chain(id: String, choice: int) -> void:
	print("chain: %s (choice %d)" % [id, choice])
	var qd: Dictionary = Chains.QUESTS[id]
	if choice > 0:
		(Book.st().quests as Dictionary).erase(id)
	if id in FOUND:
		var at: Vector2 = qd.found_at
		quests.call("sync")
		await _frames(2)
		if choice == 0 and qd.has("found_prop"):
			ok((quests.get("props") as Dictionary).has("found:" + id), "%s: the body lies there, before it is found" % id)
		var keep := player.global_position
		player.global_position = Vector3(at.x + float(qd.found_r) + 25.0, keep.y, at.y)
		quests.call("_found", player)
		ok(not Book.started(id), "%s: not found from far off" % id)
		player.global_position = Vector3(at.x + 2.0, keep.y, at.y)
		quests.call("_found", player)
		await _frames(3)
		ok(Book.active(id) and Book.step(id) == 0, "%s: found by walking up to it" % id)
		player.global_position = keep
		if qd.has("found_prop"):
			ok(not (quests.get("props") as Dictionary).has("found:" + id), "%s: the body is only a body until found" % id)
	else:
		ok(Book.accept(id), "%s taken" % id)
	var guard := 0
	while Book.active(id) and not Book.ready(id) and guard < 10:
		guard += 1
		var s := Book.step(id)
		await _step(id, s, choice)
		if Book.step(id) == s and Book.active(id) and not Book.ready(id):
			ok(false, "%s: step %d (%s) did not move on" % [id, s, Chains.step(id, s).kind])
			break
	if not Book.ready(id):
		ok(false, "%s: ready to hand in" % id)
		return
	_refresh()
	var who := Giver.turnin_of(id)
	var wn := _v(who)
	if wn != null:
		ok(String(markers.call("mark_of", wn)) == "turnin", "%s wears the '?' for %s" % [who, id])
	if id == "pans_hauler":
		var txt := Chains.step_text(id, 3, Book.q(id))
		ok(txt == String(qd.alt[Book.pick(id)][3]), "%s: the hand-in reads '%s' after the choice" % [id, txt])
	var pieces: Array = Book.offered_gear(id)
	(GearStats.state().bag as Array).clear()
	var ash0 := Travel.count("grave_ash")
	ok(Book.turn_in(id, 0 if not pieces.is_empty() else -1) and Book.done(id), "%s handed in" % id)
	ok(Travel.count("grave_ash") == ash0 + int((qd.reward as Dictionary).ash), "%s paid its ash" % id)
	var o: Dictionary = qd.outcome
	var pick := Book.pick(id)
	ok(o.has(pick) and String(o[pick]) != "", "%s: its ending is written for the choice made ('%s')" % [id, pick])
	if o.has(pick):
		ok(String(o[pick]).length() <= 330, "%s: the ending fits its banner (%d chars)" % [id, String(o[pick]).length()])
	await _frames(3)
	if qd.has("stands"):
		var props: Dictionary = quests.get("props")
		ok(props.has("stand:" + id), "%s: something stands where it ended" % id)
		var key := "stand:" + id
		if props.has(key):
			var pn := props[key] as Node3D
			ok(pn.global_position.distance_to(QuestWorld.spots.get("stand_" + id, Vector3.INF)) < 0.5, "%s: it stands on the floor found for it" % id)
	ok(not Giver.available(id, get_tree()) and not Book.active(id), "%s is not offered again" % id)


func _pick_conv(idx: int) -> void:
	var st := get_tree().get_first_node_in_group("story")
	ok(st != null and st.get("ui") != null and bool(st.get("ui").call("is_open")), "the pickup asks what to do")
	if st != null:
		st.call("_on_chosen", idx)
		await _frames(1)
		st.call("_on_advanced")
		await _frames(1)


func _step(id: String, s: int, choice: int) -> void:
	var stp := Chains.step(id, s)
	match String(stp.kind):
		"slay", "collect":
			var of := int(stp.get("of", 1))
			var kinds: Array = stp.get("kinds", [])
			var kind := String(kinds[0]) if not kinds.is_empty() else "wretch"
			var at: Vector2 = _in_region(String(stp.get("region", "")), stp.get("at", Vector2.ZERO))
			if String(stp.get("region", "")) != "":
				runner.call("note_kill", kind, Vector2(0.0, -104.0))
				ok(int(Book.q(id).get("n", 0)) == 0, "%s: a kill outside %s does not count" % [id, stp.region])
			var rares: Array = stp.get("rares", [])
			if not rares.is_empty():
				runner.call("note_kill", kind, at)
				ok(int(Book.q(id).get("n", 0)) == 0, "%s: a common foe does not count for the bounty" % id)
			for i in of:
				runner.call("note_kill", kind, at, String(rares[0]) if not rares.is_empty() else "")
		"gather", "find", "place":
			await _frames(2)
			for k: String in Chains.gather_keys(id, s):
				var p: Node = (quests.get("pickups") as Dictionary).get(k)
				ok(p != null and p.is_in_group("map_marker"), "%s: %s waits in the world, on the map" % [id, k])
				if p == null:
					continue
				var pn := p as Node3D
				var gnd := RealmLayout.ground(pn.get_world_3d().direct_space_state, pn.global_position.x, pn.global_position.z)
				ok(absf(pn.global_position.y - gnd) < 1.0, "%s: %s stands on the ground (%.2f over it)" % [id, k, pn.global_position.y - gnd])
				p.call("interact", player)
				await _frames(1)
				if (Chains.PICKUPS[k] as Dictionary).has("conv"):
					await _pick_conv(choice)
					ok(Book.pick(id) == ["whole", "torn"][choice], "%s: the choice is remembered (%s)" % [id, Book.pick(id)])
		"visit":
			await _stand(stp.at as Vector2)
		"carry":
			await _stand(stp.to as Vector2)
		"defend", "escort":
			runner.call("check")
			var live: Node3D = (runner.get("_enc") as Dictionary).get(id) as Node3D
			ok(live != null, "%s: the %s step stands up in the world" % [id, stp.kind])
			var keep2 := player.global_position
			var n := 0
			while live != null and is_instance_valid(live) and not bool(live.get("done")) and n < 4000:
				n += 1
				player.global_position = live.global_position + Vector3(1.5, 0.0, 0.0)
				for f: Enemy in Kit.foes_near(get_tree(), live.global_position, 14.0):
					f.queue_free()
				live.call("tick", 0.5)
			player.global_position = keep2
			await _frames(1)
		"cond":
			var c := String(stp.cond)
			if c.begins_with("secret:lamps:"):
				var ln := _lamp_node(c.trim_prefix("secret:lamps:"))
				if ln != null:
					ln.call("interact", player)
			elif c.begins_with("secret:"):
				var parts := c.split(":")
				var sec: Dictionary = Travel.system_state("secrets")
				if not (sec.get(parts[1]) is Dictionary):
					sec[parts[1]] = {}
				(sec[parts[1]] as Dictionary)[parts[2]] = true
			elif c.begins_with("elite:"):
				var en: Dictionary = Travel.system_state("encounters")
				if not (en.get("slain") is Dictionary):
					en["slain"] = {}
				(en.slain as Dictionary)[c.trim_prefix("elite:")] = true
			runner.call("check")
			await _frames(1)


func _in_region(rid: String, at: Vector2) -> Vector2:
	if rid == "" or Runner.in_region(rid, at.x, at.y):
		return at
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == rid and r.has("c"):
			return r.c as Vector2
	return at


func _stand(at: Vector2) -> void:
	var keep := player.global_position
	player.global_position = Vector3(at.x, keep.y, at.y)
	runner.call("check")
	await _frames(1)
	player.global_position = keep
