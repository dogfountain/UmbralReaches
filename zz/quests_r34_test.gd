extends Node
## r34 tasks (quests & NPCs, headless, in the built world): the doubled world's hubs and the raids'
## attunements.
##   data       the chains audit; every new region (docs/r34/layout.md) has a giver camped in it and
##              a chain of 3-5 tasks in its own ledger chapter; the three bosses have attunements
##   givers     each new giver stands at an outpost fire inside their region, wears the gold mark
##              (a map marker naming the task), and their pickups found a floor
##   talk       Gammer Ruan's hub offers her task; picking it opens the accept screen; Accept starts it
##   chains     every new region's chain is played through in order (slay / collect by region and
##              kind, gather pickups, visit, carry a coal from the giver's own fire, a secret's
##              condition, turn-ins with a gear choice), each giver's next task appearing in turn
##   attune     the three pre-raid chains set QuestBook.attuned(boss); the main story's objectives,
##              seals and bosses are untouched by them
##   dailies    the new dailies come back on another day; rare-only steps count only rares
## Never writes the player's save (Travel._busy); Travel's progress is put back before quitting.
## Ends: QUESTS R34 TEST PASS  /  QUESTS R34 TEST FAIL n

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Giver := preload("res://core/story/quest_giver.gd")
const Runner := preload("res://core/story/quest_runner.gd")
const QuestDB := preload("res://core/story/quest_db.gd")
const QuestWorld := preload("res://core/story/quest_world.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Cast := preload("res://core/life/village/village_cast.gd")
const TalkDB := preload("res://core/life/village/village_talk_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")

const NEW_REGIONS := ["quarry", "holds", "foundry", "moor", "orchard", "necropolis", "mere"]

var fails := 0
var t := 0.0
var started := false
var village: Node3D
var story: Node
var ui: CanvasLayer
var offer: CanvasLayer
var markers: Node
var runner: Node
var quests: Node
var player: Node3D
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
	Book.quiet = true
	_data()
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if started:
		return
	village = get_tree().root.find_child("Village", true, false) as Node3D
	if village == null or not village.has_meta("village_done"):
		if t > 220.0:
			ok(false, "the village never finished building")
			_end()
		return
	started = true
	_run()


func _end() -> void:
	if offer and is_instance_valid(offer) and bool(offer.call("is_open")):
		offer.call("close")
	get_tree().paused = false
	for key: String in _travel:
		Travel.set(key, _travel[key])
	VState.sandbox = null
	VState.kindled_override = -1
	Book.day_override = ""
	Book.quiet = false
	Runner.chance_override = -1.0
	print("QUESTS R34 TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _v(id: String) -> Node3D:
	return (village.get("villagers") as Dictionary).get(id)


# --- data ---------------------------------------------------------------------------------------------

func _data() -> void:
	print("data")
	ok(Chains.audit().is_empty(), "chains audit %s" % [Chains.audit()])
	var zones := Chains.ZONES.map(func(z: Array) -> String: return String(z[0]))
	var region_ids := RealmLayout.REGIONS.map(func(r: Dictionary) -> String: return String(r.id))
	for rid: String in NEW_REGIONS:
		ok(region_ids.has(rid), "%s is a region of the layout" % rid)
		ok(zones.has(rid), "%s is a chapter of the ledger" % rid)
		var giver := ""
		for g: String in Cast.OUTPOSTS:
			if String(Cast.OUTPOSTS[g].region) == rid:
				giver = g
		ok(giver != "" and Cast.CAST.has(giver) and TalkDB.CONV.has(giver), "%s has a giver camped in it (%s), who talks" % [rid, giver])
		var n := 0
		for id: String in Chains.ORDER:
			if String(Chains.QUESTS[id].get("zone", "")) == rid and not id in ACT3:
				n += 1
				ok(Chains.giver(id) == giver, "%s is %s's" % [id, giver])
		ok(n >= 3 and n <= 6, "%s: a chain of %d tasks (r36: and its bell)" % [rid, n])
	for boss: String in ["thornwarden", "bone_abbot", "ascended_warden"]:
		var chain: Array = []
		for id2: String in Chains.ORDER:
			if String(Chains.QUESTS[id2].get("raid", "")) == boss:
				chain.append(id2)
		ok(chain.size() >= 2 and Chains.ATTUNE.get(boss, "") == chain.back(), "%s: a pre-raid chain %s ending in its attunement" % [boss, chain])
	for id3: String in Chains.ORDER:
		var qd: Dictionary = Chains.QUESTS[id3]
		if String(qd.get("zone", "")) in NEW_REGIONS:
			ok(QuestDB.audit_cond(String(qd.get("avail", ""))) == "", "%s: avail parses" % id3)


# --- the run --------------------------------------------------------------------------------------------

func _run() -> void:
	story = get_tree().get_first_node_in_group("story")
	ui = story.get("ui") if story else null
	offer = story.get("offer_ui") if story else null
	markers = story.get("markers") if story else null
	runner = story.get("runner") if story else null
	quests = village.get("quests")
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var have := story != null and ui != null and offer != null and markers != null and runner != null and quests != null and player != null
	ok(have, "pieces present (story, box, offer screen, marks, runner, quests, wanderer)")
	if not have:
		_end()
		return
	village.set("clock", 600.0 * 0.2)
	village.set("time_scale", 0.0)
	await _frames(3)
	_givers()
	await _talk()
	var main_before := QuestDB.active(story.call("world"), 9)
	Runner.chance_override = 1.0
	for rid: String in NEW_REGIONS:
		await _chain(rid)
	Runner.chance_override = -1.0
	_attune(main_before)
	_dailies()
	_end()


func _refresh() -> void:
	markers.call("_find_givers")
	markers.call("refresh")


func _givers() -> void:
	print("givers")
	for line: String in village.get("report"):
		if line.contains("outpost") or line.contains("not spawned"):
			ok(false, "village: %s" % line)
	for line2: String in QuestWorld.report:
		ok(false, "quest spots: %s" % line2)
	_refresh()
	var outs: Dictionary = village.get("outpost_at")
	for g: String in Cast.OUTPOSTS:
		var o: Dictionary = Cast.OUTPOSTS[g]
		var v := _v(g)
		ok(v != null, "%s stands at their outpost" % g)
		var f: Vector3 = outs.get(g, Vector3.INF)
		var reg := String(RealmLayout.region_at(f.x, f.z).get("id", "")) if f != Vector3.INF else ""
		ok(reg == String(o.region), "%s's fire is in %s (%s at %s)" % [g, o.region, reg, f])
		if v == null:
			continue
		ok(v.global_position.distance_to(f) < 8.0, "%s is by the fire (%.1f m)" % [g, v.global_position.distance_to(f)])
		ok(markers.call("mark_of", v) == "available", "%s wears the gold mark (%s)" % [g, markers.call("mark_of", v)])
		var m: Node3D = v.get_node_or_null("QuestMark")
		ok(m != null and m.is_in_group("map_marker") and String(m.get_meta("map_kind", "")) == "quest_available"
			and String(m.get_meta("map_label", "")) != "", "%s's mark is a map marker (%s)" % [g, m.get_meta("map_label", "") if m else ""])


func _talk() -> void:
	print("talk")
	var ruan := _v("ruan")
	if ruan == null:
		ok(false, "Ruan is here to talk to")
		return
	ruan.call("interact", player)
	await _frames(2)
	var picked := false
	var guard := 0
	while bool(ui.call("is_open")) and guard < 30 and not picked:
		guard += 1
		ui.call("finish_line")
		var btns: Array = ui.get("_buttons")
		if btns.is_empty():
			ui.call("press")
			await _frames(1)
			continue
		for i in btns.size():
			if (btns[i] as Button).text.contains("The Kin-Taker"):
				ui.emit_signal("chosen", i)
				picked = true
				break
		if not picked:
			ok(false, "Ruan's hub offers The Kin-Taker (have %s)" % [btns.map(func(b: Button) -> String: return b.text)])
			ui.call("close")
			ui.emit_signal("closed")
			break
	await _frames(4)
	ok(picked and VState.met("ruan"), "met Gammer Ruan; her hub offers her task")
	ok(bool(offer.call("is_open")) and offer.get("quest") == "holds_turf", "the accept screen opens for The Kin-Taker")
	if bool(offer.call("is_open")):
		offer.call("_confirm")
		await _frames(2)
	ok(Book.active("holds_turf"), "Accept starts it")
	_refresh()
	ok(markers.call("mark_of", ruan) in ["available", "progress"], "Ruan's mark follows (%s)" % markers.call("mark_of", ruan))


## Play every task of region `rid` through, in ORDER (the givers' `avail` gates come true as we go).
const ACT3 := ["still_climbing"]      # r36 Act III: offered after the Warden, not part of a region's chain


func _chain(rid: String) -> void:
	print("chain: ", rid)
	# r36 Act II: the bells are offered once Brannoc has asked for the Founder's peal
	if not Book.started("founders_peal"):
		Book.start("founders_peal")
	for id: String in Chains.ORDER:
		var qd: Dictionary = Chains.QUESTS[id]
		if String(qd.get("zone", "")) != rid or id in ACT3:
			continue
		if not Book.active(id):
			ok(Giver.available(id, get_tree()), "%s is offered" % id)
			ok(Book.accept(id), "%s taken" % id)
		var guard := 0
		while Book.active(id) and not Book.ready(id) and guard < 8:
			guard += 1
			var s := Book.step(id)
			await _step(id, s)
			if Book.step(id) == s and Book.active(id) and not Book.ready(id):
				ok(false, "%s: step %d (%s) did not move on" % [id, s, Chains.step(id, s).kind])
				break
		if not Book.ready(id):
			ok(false, "%s: ready to hand in" % id)
			continue
		_refresh()
		var who := String(Chains.step(id, Book.step(id)).get("who", ""))
		var wn: Node3D = _v(who)
		if wn != null:
			ok(markers.call("mark_of", wn) == "turnin", "%s wears the '?' for %s" % [who, id])
		var pieces: Array = Book.offered_gear(id)
		var bag0 := (GearStats.state().bag as Array).size()
		var ash0 := Travel.count("grave_ash")
		ok(Book.turn_in(id, 0 if not pieces.is_empty() else -1) and Book.done(id), "%s handed in" % id)
		ok(Travel.count("grave_ash") == ash0 + int((qd.get("reward", {}) as Dictionary).get("ash", 0)), "%s paid its ash" % id)
		if not pieces.is_empty():
			ok((GearStats.state().bag as Array).size() == bag0 + 1, "%s: the chosen piece is in the gear bag" % id)
		await _frames(1)


func _step(id: String, s: int) -> void:
	var stp := Chains.step(id, s)
	match String(stp.kind):
		"slay", "collect":
			var of := int(stp.get("of", 1))
			var kinds: Array = stp.get("kinds", [])
			var kind := String(kinds[0]) if not kinds.is_empty() else "wretch"
			var at: Vector2 = _in_region(String(stp.get("region", "")), stp.get("at", Vector2.ZERO))
			# a kill well outside the region does not count
			if String(stp.get("region", "")) != "":
				runner.call("note_kill", kind, Vector2(0.0, -104.0))
				ok(int(Book.q(id).get("n", 0)) == 0, "%s: a kill outside %s does not count" % [id, stp.region])
			var rares: Array = stp.get("rares", [])
			if not rares.is_empty():
				runner.call("note_kill", kind, at)
				ok(int(Book.q(id).get("n", 0)) == 0, "%s: a common foe does not count for the bounty" % id)
				ok(RealmLayout.region_at(at.x, at.y).get("id", "") == Chains.QUESTS[id].zone, "%s: the bounty's pin is in %s" % [id, Chains.QUESTS[id].zone])
			for i in of:
				runner.call("note_kill", kind, at, String(rares[0]) if not rares.is_empty() else "")
		"gather", "find", "place":
			await _frames(2)
			for k: String in Chains.gather_keys(id, s):
				var p: Node = (quests.get("pickups") as Dictionary).get(k)
				ok(p != null and p.is_in_group("map_marker"), "%s: %s waits in the world, on the map" % [id, k])
				if p:
					p.call("interact", player)
					await _frames(1)
					# r36: a bell opens its conversation; ring it here (choice 0), then let the line end
					if (Chains.PICKUPS[k] as Dictionary).has("conv"):
						var story := get_tree().get_first_node_in_group("story")
						ok(story != null and story.get("ui") != null and bool(story.get("ui").call("is_open")), "%s: %s asks what to do with it" % [id, k])
						if story != null:
							story.call("_on_chosen", 0)
							await _frames(1)
							story.call("_on_advanced")
							await _frames(1)
						ok(Book.pick(id) == "rung", "%s: rung where it lies" % id)
		"visit":
			await _stand(stp.at as Vector2)
		"carry":
			await _stand(stp.to as Vector2)
		"cond":
			var c := String(stp.cond)
			if c.begins_with("secret:"):
				var parts := c.split(":")
				var sec: Dictionary = Travel.system_state("secrets")
				if not (sec.get(parts[1]) is Dictionary):
					sec[parts[1]] = {}
				(sec[parts[1]] as Dictionary)[parts[2]] = true
			elif c.begins_with("boss:"):
				Travel.bosses_slain[c.trim_prefix("boss:")] = true
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


# --- attunement and the main story ----------------------------------------------------------------------

func _attune(main_before: Array) -> void:
	print("attune")
	for boss: String in Chains.ATTUNE:
		ok(Book.attuned(boss), "%s: attuned (%s handed in)" % [boss, Chains.ATTUNE[boss]])
	ok(Travel.seals_broken.is_empty(), "no seal broken by the attunements")
	# the bells' secret (founder_peal's condition) aside, nothing else in the world moved
	var bosses := Travel.bosses_slain.keys()
	ok(bosses.is_empty(), "no boss counted down by the attunements (%s)" % [bosses])
	var main_after := QuestDB.active(story.call("world"), 9)
	ok(str(main_after) == str(main_before), "the main story's objectives are the same (%s)" % [main_after.map(func(o: Dictionary) -> String: return String(o.id))])


# --- dailies and rares --------------------------------------------------------------------------------

func _dailies() -> void:
	print("dailies / rares")
	var n := 0
	for id: String in Chains.ORDER:
		if String(Chains.QUESTS[id].get("repeat", "")) != "daily" or not (String(Chains.QUESTS[id].zone) in NEW_REGIONS):
			continue
		n += 1
		ok(Book.done(id) and not Giver.available(id, get_tree()), "%s: done for today" % id)
	ok(n >= 3, "%d dailies in the new regions" % n)
	Book.day_override = "2099-01-01"
	for id2: String in ["quarry_due", "moor_wind", "orchard_ash", "mere_oil"]:
		ok(Giver.available(id2, get_tree()), "%s is back the next day" % id2)
	Book.day_override = ""
	var stp := {"kind": "slay", "rare": true, "region": "moor"}
	ok(not Runner.counts(stp, "wretch", Vector2(142, -24)) and Runner.counts(stp, "wretch", Vector2(142, -24), "moor_rare"), "a rare-only step counts only a rare")
	ok(not Runner.counts(stp, "wretch", Vector2(0, 0), "moor_rare"), "and only in its region")
