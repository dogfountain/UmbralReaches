extends Node
## Tasks, merchants and village life, end to end in the built world (headless):
##   godot --headless --path . res://zz/quest_test.tscn -- --realm-modules=land,rift,bosses,lore,flora,assets,village
## Never writes the player's save: Travel._busy is held for the whole run, the village state is a
## sandbox, Travel's in-memory progress is put back before quitting (run it with an isolated HOME).
## Checks:
##   data      quest data, every task is started and finished by somebody, every condition and
##             action parses, every pickup has a floor spot, the stair's foot is on the network
##   tasks     each of the five run start to finish through the real conversations (choices picked
##             by their words), pickups, Oswin's walk, the hollowed man; both endings where they
##             differ; rewards paid, attitudes moved, outcome props built, objective lines shown
##   save      Travel.story survives the save file's encoding; a fresh world side rebuilds the same
##             outcomes; Oswin's vigil / departure survive a reload
##   shops     Grisel's projects and goods (stock, sold out, too poor), the keep's slate (ale, a
##             rumour, a round that sets the room cheering)
##   keg       songs, dice and an argument play with their acts; every new beat poses without NaNs
##   life      the Gloom tide sends the village into the Keg and lets it out; rain sends Nan home;
##             Hild visits the ash-wife's cart
## Ends: QUEST TEST PASS  /  QUEST TEST FAIL n

const Book := preload("res://core/story/quest_book.gd")
const QuestDB := preload("res://core/story/quest_db.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const QWorld := preload("res://core/story/quest_world.gd")
const DialogueDB := preload("res://core/story/dialogue_db.gd")
const TalkDB := preload("res://core/life/village/village_talk_db.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Shop := preload("res://core/life/village/village_shop.gd")

var fails := 0
var t := 0.0
var started := false
var village: Node3D
var quests: Node3D
var story: Node
var ui: CanvasLayer
var player: Node3D
var tavern: Node3D
var _travel := {}


func ok(c: bool, what: String) -> void:
	if c:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true                       # never write the player's real save
	for key: String in ["seals_broken", "bosses_slain", "items", "story", "lit_by_path", "systems"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
	Travel.seals_broken = {}
	Travel.bosses_slain = {}
	Travel.items = {}
	Travel.lit_by_path = {}
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	VState.sandbox = {}
	VState.kindled_override = 0
	_data()
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if started:
		return
	village = get_tree().root.find_child("Village", true, false) as Node3D
	if village == null or not village.has_meta("village_done"):
		if t > 180.0:
			ok(false, "the village never finished building")
			_end()
		return
	started = true
	_run()


func _end() -> void:
	if ui and is_instance_valid(ui) and bool(ui.call("is_open")):
		ui.call("close")
	get_tree().paused = false
	for key: String in _travel:
		Travel.set(key, _travel[key])
	VState.sandbox = null
	VState.kindled_override = -1
	print("QUEST TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _run() -> void:
	quests = village.get("quests")
	story = get_tree().get_first_node_in_group("story")
	ui = story.get("ui") if story else null
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	tavern = get_tree().root.find_child("HollowLantern", true, false) as Node3D
	var have := quests != null and story != null and ui != null and player != null and tavern != null
	ok(have, "world pieces present (quests, story, box, wanderer, Keg)")
	if not have:
		_end()
		return
	_spots()
	village.set("clock", 600.0 * 0.2)
	village.set("time_scale", 0.0)            # the village holds still while we talk (nobody goes indoors)
	await _frames(3)
	await _edda()
	await _names()
	await _keg_thief()
	await _slow_way()
	await _forty_first()
	await _save()
	await _shops()
	await _keg()
	await _life()
	_end()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- helpers ------------------------------------------------------------------------------------------

## Talk to `npc`, picking choices whose text contains each of `picks` in turn; lines without
## choices are pressed through. Returns the box's lines seen. Closes the box when the picks run out.
func converse(npc: Node, picks: Array) -> Array[String]:
	var seen: Array[String] = []
	if npc.get("hidden") == true:
		npc.call("_set_hidden", false)
	npc.call("interact", player)
	await _frames(1)
	var pi := 0
	var guard := 0
	while bool(ui.call("is_open")) and guard < 80:
		guard += 1
		ui.call("finish_line")
		var txt: String = (ui.get("_text") as RichTextLabel).text
		if seen.is_empty() or seen.back() != txt:
			seen.append(txt)
		var btns: Array = ui.get("_buttons")
		if btns.is_empty():
			ui.call("press")
			await _frames(1)
			continue
		if pi >= picks.size():
			ui.call("close")
			ui.emit_signal("closed")
			await _frames(1)
			break
		# the next pick offered here (a pick that isn't can be skipped: a meeting came first, or not)
		var idx := -1
		var want := String(picks[pi])
		for pj in range(pi, picks.size()):
			for i in btns.size():
				if (btns[i] as Button).text.contains(String(picks[pj])):
					idx = i
					break
			if idx >= 0:
				pi = pj
				break
		if idx < 0:
			var have: Array = btns.map(func(b: Button) -> String: return b.text)
			ok(false, "choice '%s' offered (have %s)" % [want, have])
			ui.call("close")
			ui.emit_signal("closed")
			await _frames(1)
			break
		pi += 1
		ui.emit_signal("chosen", idx)
		await _frames(1)
	await _frames(2)
	return seen


func _v(id: String) -> Node3D:
	return (village.get("villagers") as Dictionary).get(id)


func _patron(talk_id: String) -> Node3D:
	if talk_id == "keep":
		return tavern.get_node_or_null("Keep") as Node3D
	for c in tavern.get_children():
		if c.get("talk_id") == talk_id:
			return c as Node3D
	return null


func _take(k: String) -> bool:
	var p: Node = (quests.get("pickups") as Dictionary).get(k)
	if p == null or not bool(p.call("can_interact")):
		return false
	p.call("interact", player)
	await _frames(2)
	return true


func _obj_has(qid: String) -> bool:
	for o: Dictionary in story.call("objectives"):
		if String(o.id) == "quest:" + qid:
			return true
	return false


func _reset(qid: String) -> void:
	(Book.st().quests as Dictionary).erase(qid)
	Events.quest_changed.emit(qid, -1, false)


# --- data -------------------------------------------------------------------------------------------

func _data() -> void:
	print("data")
	ok(Chains.audit().is_empty(), "quest data audit %s" % [Chains.audit()])
	ok(DialogueDB.audit().is_empty(), "the Keg's conversations audit %s" % [DialogueDB.audit()])
	# the keep never sends a wanderer with heart and crown but no peal to the gated Crossing
	var both := {"thornwarden": true, "bone_abbot": true}
	var nx := DialogueDB.text_of(DialogueDB.node("keep", "next"), {"flags": {}, "kindled": 0, "seals": {}, "bosses": both, "items": {}})
	ok(nx.contains("bells") and not nx.contains("Crossing"), "the keep names the bells (not the Crossing) while the peal is short: %s" % nx)
	var four := {"flags": {}, "kindled": 0, "seals": {}, "bosses": both, "items": {}}
	var ndx := DialogueDB.text_of(DialogueDB.node("keep", "next"), four)
	ok(ndx.contains("Brannoc") or ndx.contains("bells"), "the keep sends the wanderer to Brannoc or the bells before the Crossing: %s" % ndx)
	var LevelDB := preload("res://core/life/progression/level.gd")
	ok(LevelDB.quest_xp(10) < LevelDB.quest_xp(60) and LevelDB.quest_xp(10, true) < LevelDB.quest_xp(10), "task XP scales with the errand and a repeat pays less")
	# every action and condition in both databases parses; every task is started and finished
	var starts := {}
	var ends := {}
	var bad: Array[String] = []
	var dbs := [DialogueDB.CONV, TalkDB.CONV]
	for db: Dictionary in dbs:
		for cid: String in db:
			for nid: String in db[cid].nodes:
				var n: Dictionary = db[cid].nodes[nid]
				var acts: Array[String] = [String(n.get("do", ""))]
				for ch: Dictionary in n.get("choices", []):
					acts.append(String(ch.get("do", "")))
					if VState.audit_cond(String(ch.get("if", ""))) != "":
						bad.append("%s/%s if %s" % [cid, nid, ch["if"]])
				for pair: Array in n.get("say_if", []):
					if VState.audit_cond(String(pair[0])) != "":
						bad.append("%s/%s say_if %s" % [cid, nid, pair[0]])
				for a: String in acts:
					for term in a.split(","):
						term = term.strip_edges()
						var p := term.split(":")
						if p[0] in ["qs", "qa", "qt", "qc", "qp"] and not Chains.QUESTS.has(p[1]):
							bad.append("%s/%s action %s: no such task" % [cid, nid, term])
						if p[0] == "qs":
							starts[p[1]] = true
						if p[0] == "qc":
							ends[p[1]] = true
						if p[0] in ["give", "grant"] and p.size() > 2 and p[0] == "give" and not ItemDB.DEFS.has(p[1]):
							bad.append("%s/%s gives unknown %s" % [cid, nid, p[1]])
	ok(bad.is_empty(), "conditions and actions parse %s" % [bad])
	for qid: String in Chains.QUESTS:
		if bool(Chains.QUESTS[qid].get("offer", false)):
			continue        # r33: set by the giver's mark and the accept screen (zz/quests_r33_test)
		ok(starts.has(qid), "%s: somebody starts it" % qid)
		# edda can also end by putting the tongs back (a pickup); the others in talk
		ok(ends.has(qid) or qid == "edda_tongs", "%s: somebody finishes it" % qid)


func _spots() -> void:
	print("spots")
	for k: String in Chains.PICKUPS:
		var p: Vector3 = QWorld.spots.get(k, Vector3.INF)
		var near: Vector2 = Chains.PICKUPS[k].near
		if Chains.PICKUPS[k].has("camp"):
			# r34: taken from a giver's outpost fire, wherever the camp was found
			var f: Vector3 = village.call("anchor", "@fire_" + String(Chains.PICKUPS[k].camp))
			near = Vector2(f.x, f.z) if f != Vector3.INF else near
		ok(p != Vector3.INF and Vector2(p.x, p.z).distance_to(near) < 6.5, "%s: floor spot near its place %s" % [k, p])
	ok(QWorld.spots.get("stair", Vector3.INF) != Vector3.INF and (village.get("nav") as RefCounted).call("has", "q_stair"), "the stair's foot is on the network")
	for line: String in QWorld.report:
		print("    report ", line)


# --- the tasks ----------------------------------------------------------------------------------------

func _edda() -> void:
	print("Edda's Tongs")
	var hild := _v("hild")
	Travel.items = {}
	await converse(hild, ["want something", "I'll fetch them", "Goodbye"])
	ok(Book.active("edda_tongs") and Book.step("edda_tongs") == 0, "Hild sets the task")
	ok(_obj_has("edda_tongs"), "the objective line shows it")
	ok((quests.get("pickups") as Dictionary).has("tongs"), "the tongs lie on Edda's stone")
	ok(await _take("tongs"), "take the tongs")
	ok(Book.step("edda_tongs") == 1, "step: bring them to Hild")
	await converse(hild, ["back on her stone"])
	ok(Book.step("edda_tongs") == 2 and Book.pick("edda_tongs") == "stone", "choice remembered: back on the stone")
	ok(await _take("tongs_back"), "lay them on the stone")
	ok(Book.done("edda_tongs"), "Edda's Tongs done")
	ok(Travel.count("grave_ash") == 10 and Travel.count("relic_fragment") == 1, "reward: 10 ash and a relic fragment (%d, %d)" % [Travel.count("grave_ash"), Travel.count("relic_fragment")])
	ok(Book.att("abel") >= 2, "Abel remembers (%d)" % Book.att("abel"))
	await _frames(2)
	ok((quests.get("props") as Dictionary).has("tongs"), "the tongs stay on her stone")
	var seen := await converse(hild, [])
	ok(seen.size() > 0 and seen[0].contains("warm"), "Hild talks about the stone afterwards")
	# the other ending
	_reset("edda_tongs")
	Book.start("edda_tongs")
	Book.advance("edda_tongs")
	var before := Travel.count("relic_fragment")
	await converse(hild, ["Forge with them"])
	ok(Book.done("edda_tongs") and Book.pick("edda_tongs") == "forge", "forge ending")
	ok(Travel.count("charm_ferrule") == 1 or Travel.count("relic_fragment") == before + 2, "the ferrule (or its fragments) given")
	await _frames(2)
	var prop: Node = (quests.get("props") as Dictionary).get("tongs")
	ok(prop != null and String(prop.get_meta("v", "")) == "forge", "the tongs moved to the forge")


func _names() -> void:
	print("Names for the Yard")
	var abel := _v("abel")
	await converse(abel, ["anything I can do", "I'll find them", "Goodbye"])
	ok(Book.active("names_yard"), "Abel sets the task")
	for k: String in ["slate_glade", "slate_lane", "slate_barrow"]:
		ok(await _take(k), "read %s" % k)
	ok(Book.step("names_yard") == 1, "three names found: back to Abel")
	var line := Chains.step_text("names_yard", 0, {"f": {"a": true}})
	ok(line.contains("(1/3)"), "gather count in the line: %s" % line)
	await converse(abel, [])
	ok(Book.step("names_yard") == 2, "Abel sends you to the Yard's wall")
	Book.run("qp:names_yard:deep,qa:names_yard")        # the wall's conversation (dialogue_db.gd yard_cut)
	ok(Book.done("names_yard") and Book.pick("names_yard") == "deep", "Names for the Yard done")
	await _frames(2)
	ok((quests.get("props") as Dictionary).has("names"), "the names stand in the Yard")


func _keg_thief() -> void:
	print("The Keg's Missing Ale")
	var keep := _patron("keep")
	await converse(keep, ["troubled", "find your thief", "Goodbye"])
	ok(Book.active("keg_thief"), "the keep sets the task")
	# a clues step (verb_world.gd): two of the four signs behind the Keg
	var verbs: Node = quests.get_node("Verbs")
	ok(Book.step("keg_thief") == 0 and (verbs.call("info") as Dictionary).nodes.size() == 4, "four signs stand behind the Keg")
	ok(bool(verbs.call("examine", "keg_thief", "circle")) and Book.step("keg_thief") == 0, "the dropped mug: one of two read")
	ok(bool(verbs.call("examine", "keg_thief", "prints")) and Book.step("keg_thief") == 1, "the spilled ale: two read, on to the ale's way")
	ok(Book.found("keg_thief").has("c:prints") and QuestDB.test("qc:keg_thief:prints,!qc:keg_thief:gnaw", {}), "what was read is remembered (qc:)")
	await _frames(2)
	for i in 4:
		verbs.call("_reveal", "keg_thief", i)
	ok(Book.step("keg_thief") == 2, "four ale-drops followed: the last circle")
	await _frames(2)
	ok(await _take("mug_fire"), "the full mug by the green's fire")
	ok(Book.step("keg_thief") == 3, "step: ask Nan")
	var nan := _v("nan")
	await converse(nan, ["chalk circles", "Bare feet", "secret's safe"])
	ok(Book.step("keg_thief") == 4 and Book.pick("keg_thief") == "covered", "Nan's secret kept")
	ok(Book.att("nan") >= 2, "Nan likes that (%d)" % Book.att("nan"))
	Travel.items["grave_ash"] = 4
	var seen := await converse(keep, ["my slate"])
	ok(seen.any(func(s: String) -> bool: return s.contains("haven't the ash")), "too poor to pay: the keep says so")
	ok(not Book.done("keg_thief"), "still owing")
	Travel.items["grave_ash"] = 20
	await converse(keep, ["my slate", "Goodbye"])
	ok(Book.done("keg_thief") and Travel.count("grave_ash") == 10, "paid 10 ash, done (%d left)" % Travel.count("grave_ash"))
	await _frames(2)
	ok((quests.get("props") as Dictionary).has("mug"), "a mug stays by the fire")
	var nl := await converse(nan, [])
	ok(nl.size() > 0 and nl[0].contains("circle"), "Nan remembers: %s" % (nl[0] if nl.size() > 0 else ""))


func _slow_way() -> void:
	print("The Slow Way Down")
	var ostrin := _patron("harrow")
	await converse(ostrin, ["father went down", "find him", "Neither"])
	ok(Book.active("slow_way"), "Ostrin sets the task")
	ok((quests.get("pickups") as Dictionary).has("lantern"), "the lantern lies in the fen (not yet takeable)")
	ok(not bool((quests.get("pickups") as Dictionary).lantern.call("can_interact")), "it can't be taken while he stands over it")
	# a tracks step (verb_world.gd): four marks of lantern oil lead from the fen graves to the lantern
	var verbs: Node = quests.get_node("Verbs")
	ok(Book.step("slow_way") == 0 and int((verbs.call("info") as Dictionary).track) == 1, "the first of Harrow's marks lies at the fen graves")
	for i in 4:
		verbs.call("_reveal", "slow_way", i)
	ok(Book.step("slow_way") == 1, "four marks followed: the trail ends at the lantern")
	var at: Vector3 = QWorld.spots.hollow
	var home := player.global_position
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = at + Vector3(6.0, 1.0, 0.0)
	await get_tree().create_timer(0.6).timeout
	var h: Node3D = quests.get("hollow")
	ok(Book.step("slow_way") == 1 and h != null and is_instance_valid(h), "Father Harrow wakes over the lantern")
	if h:
		ok(h.is_in_group(Groups.ENEMY) or h.has_method("station"), "he is one of the hollowed")
		Events.enemy_killed.emit(h)
		h.queue_free()
	await _frames(3)
	ok(Book.step("slow_way") == 2, "put to rest: take the lantern")
	ok(await _take("lantern"), "take the lantern")
	ok(Book.step("slow_way") == 3, "the lantern is dry: light it at the fen's fire")
	ok(await _take("harrow_flame"), "light it at the fen's fire")
	ok(Book.step("slow_way") == 4, "carry it home lit (lantern_walk)")
	Book.advance("slow_way")                                 # (the walk itself: quest_verbs_test)
	ok(Book.step("slow_way") == 5, "home: tell Ostrin")
	player.global_position = home
	player.process_mode = Node.PROCESS_MODE_INHERIT
	await converse(ostrin, ["It was him", "lamp-glass"])
	ok(Book.done("slow_way") and Book.pick("slow_way") == "truth", "Slow Way done, truth told")
	await _frames(2)
	var lp: Node = (quests.get("props") as Dictionary).get("lantern")
	ok(lp != null and String(lp.get_meta("v", "")) == "lit", "the lantern burns on the counter")


func _forty_first() -> void:
	print("The Forty-First Stone")
	var oswin := _v("oswin")
	await converse(oswin, ["count the waystones", "walk with you"])
	ok(Book.active("forty_first") and oswin.get("follow") == player, "Oswin falls in behind the wanderer")
	# walk him there: a stand-in leads (the wanderer's controller isn't driven here)
	var lead := Node3D.new()
	add_child(lead)
	oswin.set("follow", lead)
	# the wanderer waits where the old new-game start was, near the stone end of the walk (a new game now wakes out
	# on the Pilgrims' Road, and the escort holds for a wanderer that far behind)
	player.global_position = Vector3(0.0, 0.15, 26.5)
	village.set("time_scale", 3.0)
	var route := [Vector2(-8.0, 54.0), Vector2(-2.0, 46.0), Vector2(-5.0, 39.0), Vector2(-4.5, 27.0), Vector2(-1.0, 21.0), Vector2(-1.2, 16.0)]
	var space := village.get_world_3d().direct_space_state
	for wp: Vector2 in route:
		lead.global_position = Vector3(wp.x, RealmLayout.ground(space, wp.x, wp.y), wp.y)
		for i in 400:
			await get_tree().process_frame
			var dd := Vector2(oswin.global_position.x - wp.x, oswin.global_position.z - wp.y).length()
			if dd < 3.4 or not Book.active("forty_first") or Book.step("forty_first") > 0:
				break
		if Book.step("forty_first") > 0:
			break
	village.set("time_scale", 1.0)
	await _frames(4)
	print("    oswin at %s, walked %.1f m" % [oswin.global_position, float(oswin.get("walked"))])
	ok(Book.step("forty_first") == 1, "Oswin reaches the forty-first stone")
	for i in 300:
		await get_tree().process_frame
		if String(oswin.get("act")) == "kneel" and oswin.get("follow") == null:
			break
	ok(bool(oswin.get("pinned")) and String(oswin.get("act")) == "kneel", "he kneels at it")
	oswin.set("follow", null)
	await converse(oswin, ["Wait here"])
	ok(Book.pick("forty_first") == "faith" and Book.step("forty_first") == 2, "faith: the lamp for his stone is next")
	Book.advance("forty_first", 4)                           # (the lamp and its walk: quest_verbs_test)
	ok(Book.done("forty_first") and Book.pick("forty_first") == "faith", "faith: he keeps his vigil")
	await _frames(3)
	ok(String(oswin.get("routine")) == "vigil" and (oswin.global_position - QWorld.spots.stair).length() < 1.0, "vigil at the waystone (%s)" % oswin.get("routine"))
	ok(Travel.count("charm_waystone") == 1 or Travel.count("relic_fragment") >= 1, "his chip of stone given")
	# the other ending: he goes home
	_reset("forty_first")
	Book.start("forty_first")
	oswin.set("follow", lead)
	var t1 := Time.get_ticks_msec()
	while Book.step("forty_first") < 1 and Time.get_ticks_msec() - t1 < 4000:
		await get_tree().process_frame
	ok(Book.step("forty_first") == 1, "(again) at the stone")
	await converse(oswin, ["The Stair is broken"])
	ok(Book.pick("forty_first") == "truth", "truth: he goes home")
	Book.advance("forty_first", 4)                           # the lamp walked: done, and he leaves
	var gone := false
	village.set("time_scale", 1.0)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 32000:
		await get_tree().process_frame
		if _v("oswin") == null:
			gone = true
			break
	ok(gone, "Oswin takes the west road and is gone")
	ok(QWorld.override("oswin", {"home": "x"}).is_empty(), "and stays gone on a reload")
	await _frames(2)
	ok((quests.get("props") as Dictionary).has("staff"), "his staff is left on the west road")
	lead.queue_free()


# --- save -----------------------------------------------------------------------------------------------

func _save() -> void:
	print("save")
	var cfg := ConfigFile.new()
	cfg.set_value("story", "state", Travel.story)
	var back := ConfigFile.new()
	back.parse(cfg.encode_to_text())
	var st: Dictionary = back.get_value("story", "state", {})
	ok((st.get("quests", {}) as Dictionary).size() == 5, "five tasks in the [story] section")
	var same := true
	for qid: String in Chains.QUESTS:
		var a: Dictionary = (st.quests as Dictionary).get(qid, {})
		if bool(a.get("d", false)) != Book.done(qid) or String(a.get("p", "")) != Book.pick(qid):
			same = false
	ok(same, "done and choices survive the save format")
	var att_ok := true
	for npc: String in Book.st().att:
		if int((st.get("att", {}) as Dictionary).get(npc, -99)) != Book.att(npc):
			att_ok = false
	ok(att_ok and not (Book.st().att as Dictionary).is_empty(), "attitudes survive %s" % [st.get("att")])
	# a fresh world side from the loaded state builds the same outcomes
	var before: Array = (quests.get("props") as Dictionary).keys()
	before.sort()
	var keep_story := Travel.story
	Travel.story = st.duplicate(true)
	var q2: Node3D = QWorld.new()
	q2.name = "QuestsReloaded"
	q2.set("village", village)
	village.add_child(q2)
	await _frames(2)
	var after: Array = (q2.get("props") as Dictionary).keys()
	after.sort()
	ok(before == after, "outcomes rebuilt from the save %s" % [after])
	q2.queue_free()
	Travel.story = keep_story
	await _frames(1)


# --- shops ----------------------------------------------------------------------------------------------

func _shops() -> void:
	print("shops")
	VState.data().flags.erase("oil")
	Travel.items = {"grave_ash": 40}
	await converse(_v("grisel"), ["Show me your wares"])
	await _frames(2)
	var shop: CanvasLayer = story.get("shop")
	ok(shop != null and bool(shop.call("is_open")), "Grisel's shop opens")
	ok(get_tree().paused, "the world pauses for it")
	var rows: Array = shop.get("rows")
	ok(rows.any(func(r: Dictionary) -> bool: return String(r.id) == "oil"), "lamp oil on offer")
	ok(bool(shop.call("buy", "oil")) and VState.flag("oil") and Travel.count("grave_ash") == 32, "oil bought for 8 (%d left)" % Travel.count("grave_ash"))
	ok(bool(shop.call("buy", "relic_fragment")) and bool(shop.call("buy", "relic_fragment")), "two relic fragments")
	ok(not bool(shop.call("buy", "relic_fragment")), "the third is sold out")
	Travel.items["grave_ash"] = 3
	shop.call("_refresh")
	var poor: Array = (shop.get("rows") as Array).filter(func(r: Dictionary) -> bool: return not bool(r.ok))
	ok(not poor.is_empty() and String(poor[0].why).contains("more grave ash"), "too poor: says how much more")
	shop.call("close")
	await _frames(1)
	ok(not get_tree().paused, "leaving the shop lets the world run")
	# the keep's slate
	Travel.items["grave_ash"] = 20
	await converse(_patron("keep"), ["on the slate"])
	await _frames(2)
	ok(bool(shop.call("is_open")) and String(shop.get("who")) == "keep", "the keep's slate opens")
	var r := Shop.buy("keep", "rumour", get_tree())
	ok(bool(r.ok) and String(r.say).length() > 20, "a rumour: %s" % r.say)
	ok(bool(shop.call("buy", "round")), "a round for the room")
	shop.call("close")
	await _frames(3)
	var ks := get_tree().get_first_node_in_group("keg_scenes")
	ok(ks != null and (ks.get("played") as Array).has("round"), "the room raises its mugs")
	ok(Book.att("hesk") >= 1 and Book.att("brannoc") >= 1, "the regulars remember the round")


# --- the Keg's scenes ----------------------------------------------------------------------------------

func _keg() -> void:
	print("keg scenes")
	var ks := get_tree().get_first_node_in_group("keg_scenes")
	await get_tree().create_timer(3.0).timeout
	ks.call("_finish")
	for id: String in ["dice", "argue", "song"]:
		var played := bool(ks.call("play", id))
		ok(played, "%s plays" % id)
		await get_tree().create_timer(1.2).timeout
		var cast: Array = ks.get("_cast")
		var acts: Array = cast.map(func(d: Node) -> String: return String(d.get("_act")))
		var want := {"dice": ["dice", "listen"], "argue": ["argue", "listen"], "song": ["sing"]}[id] as Array
		ok(acts.any(func(a: String) -> bool: return a in want), "%s: the cast acts it (%s)" % [id, acts])
		if id == "dice":
			await get_tree().create_timer(1.6).timeout
			var dice: Array = ks.get("_dice")
			var on_board := dice.size() == 2
			for dm: Node3D in dice:
				var c0: Node3D = cast[0]
				on_board = on_board and absf(dm.global_position.y - (c0.global_position.y + float(c0.get("table_top")))) < 0.06 and dm.global_position.distance_to(c0.global_position) < 1.6
			ok(on_board, "two dice land on the board %s" % [dice.map(func(m: Node3D) -> Vector3: return m.global_position)])
		ks.call("_finish")
		await _frames(2)
	# every new beat poses cleanly
	var d: Node = _patron("hesk")
	var bad := 0
	for act: String in ["sing", "argue", "dice", "cheer", "groan"]:
		d.call("cue", act, 2.0)
		for i in 12:
			d.call("animate", 0.16)
			for c in d.find_children("*", "Skeleton3D", true, false):
				var sk := c as Skeleton3D
				for b in sk.get_bone_count():
					var o := sk.get_bone_global_pose(b).origin
					if not (is_finite(o.x) and is_finite(o.y) and is_finite(o.z)):
						bad += 1
	ok(bad == 0, "sing, argue, dice, cheer and groan pose without NaNs")


# --- village life ---------------------------------------------------------------------------------------

func _life() -> void:
	print("village life")
	village.set("time_scale", 1.0)
	village.set("_tide", true)
	village.set("_mode_t", 0.0)
	await get_tree().create_timer(1.3).timeout
	ok(String(village.get("mode")) == "danger", "the Gloom tide: danger")
	await _frames(5)
	var fled := 0
	var stayed: Array[String] = []
	for id: String in village.get("villagers"):
		var v: Node = _v(id)
		if String(v.get("routine")) == "flee":
			fled += 1
		else:
			stayed.append(id)
	await get_tree().create_timer(4.0).timeout
	fled = 0
	stayed.clear()
	for id2: String in village.get("villagers"):
		if String(_v(id2).get("routine")) == "flee":
			fled += 1
		else:
			stayed.append(id2)
	ok(fled >= 4, "the village runs for the Keg (%d; stayed %s)" % [fled, stayed])
	ok("wyck" in stayed and "abel" in stayed, "the hermit and the sexton keep to their camps")
	village.set("_tide", false)
	village.set("_mode_t", 0.0)
	await get_tree().create_timer(1.3).timeout
	ok(String(village.get("mode")) != "danger", "the tide breaks")
	# rain
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar state := {\"rain\": 1.0, \"mist\": 0.0, \"wind\": 0.3, \"thunder\": 0.0}\n"
	gs.reload()
	var wet: Node = gs.new()
	add_child(wet)
	village.set("_weather", wet)
	village.set("_mode_t", 0.0)
	village.set("phase", "work")
	await get_tree().create_timer(1.3).timeout
	ok(String(village.get("mode")) == "rain", "rain")
	await _frames(5)
	ok(String(village.call("routine_for", "nan")) == "home", "rain sends Nan home")
	ok(String(village.call("routine_for", "hild")) in ["forge", "break"], "Hild works on under the forge roof (%s)" % village.call("routine_for", "hild"))
	wet.queue_free()
	village.set("_weather", null)
	village.set("_mode_t", 0.0)
	await get_tree().create_timer(1.3).timeout
	# a visit: Hild at the ash-wife's cart
	var hild := _v("hild")
	hild.call("release")
	var steps: Array = (hild.get("data").routines as Dictionary)["break"]
	hild.set("routine", "break")
	hild.set("steps", steps)
	for i in steps.size():
		if str((steps[i] as Dictionary).get("face", "")) == "%grisel":   # face may be a Vector3
			hild.set("step_i", i - 1)
	hild.call("_next_step")
	village.set("time_scale", 4.0)
	var visited := false
	for i in 2400:
		await get_tree().process_frame
		if String(hild.get("act")) == "chat" and hild.get("visiting") == _v("grisel"):
			visited = true
			break
	village.set("time_scale", 1.0)
	ok(visited, "Hild visits Grisel's cart and they talk (%s %s)" % [hild.get("state"), hild.get("act")])
	ok(not visited or _v("grisel").get("visited_by") == hild, "Grisel turns to her")
