extends Node
## r33 tasks (quests & NPCs, headless, in the built world):
##   data      the chains audit; every offered task has a giver who stands in the night
##   marks     a giver's mark over the head: "available" (gold "!"), "turnin" ("?"), "progress"
##             (grey); the marks and the places tasks send you are map markers
##   accept    Wyck's hub gains the task's line; picking it opens the accept screen; Accept starts it
##   progress  seal guards count (n/of), kills count by kind and region, a collect step drops with
##             its chance, the count toast ("Bone ash: 3/5"), the tracker shows name and count
##   turn-in   the "?" over the giver; the turn-in screen wants a choice; the chosen piece reaches the
##             gear bag; the daily comes back on another day
##   visit / carry  a place reached moves a step on; a coal that burns out falls back a step
##   ledger    chapters by zone, track / untrack, abandon (twice)
## Never writes the player's save (Travel._busy); Travel's progress is put back before quitting.
## Ends: QUESTS R33 TEST PASS  /  QUESTS R33 TEST FAIL n

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Giver := preload("res://core/story/quest_giver.gd")
const Runner := preload("res://core/story/quest_runner.gd")
const VState := preload("res://core/life/village/village_state.gd")
const GearStats := preload("res://core/items/gear_stats.gd")

var fails := 0
var t := 0.0
var started := false
var village: Node3D
var story: Node
var ui: CanvasLayer
var offer: CanvasLayer
var qlog: CanvasLayer
var markers: Node
var runner: Node
var player: Node3D
var _travel := {}


func _init() -> void:
	Engine.set_meta(&"full_night", true)   # the 30-minute slice hides horses, watch, roaming events, dailies, attunements


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
	print("data")
	ok(Chains.audit().is_empty(), "chains audit %s" % [Chains.audit()])
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if started:
		return
	village = get_tree().root.find_child("Village", true, false) as Node3D
	if village == null or not village.has_meta("village_done"):
		if t > 200.0:
			ok(false, "the village never finished building")
			_end()
		return
	started = true
	_run()


func _end() -> void:
	if offer and is_instance_valid(offer) and bool(offer.call("is_open")):
		offer.call("close")
	if qlog and is_instance_valid(qlog) and bool(qlog.call("is_open")):
		qlog.call("close")
	get_tree().paused = false
	for key: String in _travel:
		Travel.set(key, _travel[key])
	VState.sandbox = null
	VState.kindled_override = -1
	Book.day_override = ""
	Runner.chance_override = -1.0
	print("QUESTS R33 TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _v(id: String) -> Node3D:
	return (village.get("villagers") as Dictionary).get(id)


func _run() -> void:
	story = get_tree().get_first_node_in_group("story")
	ui = story.get("ui") if story else null
	offer = story.get("offer_ui") if story else null
	markers = story.get("markers") if story else null
	runner = story.get("runner") if story else null
	qlog = story.get("log_ui") if story else null
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var have := story != null and ui != null and offer != null and markers != null and runner != null and qlog != null and player != null
	ok(have, "pieces present (story, box, offer screen, marks, runner, ledger, wanderer)")
	if not have:
		_end()
		return
	village.set("clock", 600.0 * 0.2)
	village.set("time_scale", 0.0)
	await _frames(3)
	for qid: String in Chains.ORDER:
		if bool(Chains.QUESTS[qid].get("offer", false)):
			var g := Chains.giver(qid)
			# a giver gated by the night's state (Col after the Wrights come home, Iorweth by his task's step) stands in the night
			# once its condition holds: here it is enough that it is in the cast with that condition (quests_r34 checks the offer itself)
			var cast: Dictionary = (load("res://core/life/village/village.gd") as GDScript).call("cast_all")
			var gated: bool = cast.has(g) and String((cast[g] as Dictionary).get("when", "")) != ""
			ok(_v(g) != null or _patron(g) != null or gated, "%s: its giver %s stands in the night (or in the cast, gated)" % [qid, g])
	await _marks_and_accept()
	await _collect_and_daily()
	await _slay_region()
	await _visit()
	await _carry()
	await _ledger()
	_end()


func _patron(talk_id: String) -> Node3D:
	for n: Node in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n.get("talk_id") == talk_id:
			return n as Node3D
	return null


func _refresh() -> void:
	markers.call("_find_givers")
	markers.call("refresh")


## Talk to `npc` and pick the choice whose text contains `pick` (pressing through lines first).
func _pick_in_talk(npc: Node, pick: String) -> bool:
	if npc.get("hidden") == true:
		npc.call("_set_hidden", false)
	npc.call("interact", player)
	await _frames(1)
	var guard := 0
	while bool(ui.call("is_open")) and guard < 30:
		guard += 1
		ui.call("finish_line")
		var btns: Array = ui.get("_buttons")
		if btns.is_empty():
			ui.call("press")
			await _frames(1)
			continue
		for i in btns.size():
			if (btns[i] as Button).text.contains(pick):
				ui.emit_signal("chosen", i)
				await _frames(3)
				return true
		var have: Array = btns.map(func(b: Button) -> String: return b.text)
		ok(false, "choice '%s' offered (have %s)" % [pick, have])
		ui.call("close")
		ui.emit_signal("closed")
		await _frames(1)
		return false
	return false


# --- marks, the accept screen, seal progress, the turn-in with a choice --------------------------------

func _marks_and_accept() -> void:
	print("marks / accept / seal / turn-in")
	var wyck := _v("wyck")
	ok(wyck != null, "Wyck stands at his fire")
	if wyck == null:
		return
	_refresh()
	ok(markers.call("mark_of", wyck) == "available", "Wyck wears the gold mark (%s)" % markers.call("mark_of", wyck))
	var m: Node3D = wyck.get_node_or_null("QuestMark")
	ok(m != null and m.is_in_group("map_marker") and String(m.get_meta("map_kind", "")) == "quest_available"
		and String(m.get_meta("map_label", "")) == "Thorns at the Door", "the mark is a map marker (quest_available, the task's name)")
	ok(m != null and (m.get_node("Glyph") as Label3D).text == "!", "the glyph is the mark")
	# the hub gains the task's line; picking it opens the accept screen
	var picked: bool = await _pick_in_talk(wyck, "Thorns at the Door")
	ok(picked, "Wyck's hub offers Thorns at the Door")
	await _frames(3)
	ok(bool(offer.call("is_open")) and offer.get("mode") == "offer" and offer.get("quest") == "thorn_door", "the accept screen opens")
	var pieces: Array = offer.get("_pieces")
	ok(pieces.size() == 3, "three pieces to choose from at the end (%d)" % pieces.size())
	offer.call("_confirm")
	await _frames(2)
	ok(Book.active("thorn_door") and not bool(offer.call("is_open")), "Accept starts it")
	_refresh()
	# (or stays gold: Forty Days Late is his too, offered once he has been met)
	var wm := String(markers.call("mark_of", wyck))
	ok(wm == "progress" or (wm == "available" and Giver.available("forty_days", get_tree())), "Wyck's mark goes grey while it is under way, unless he has another task (%s)" % wm)
	var tg := false
	for n: Node in get_tree().get_nodes_in_group("map_marker"):
		if String(n.get_meta("map_kind", "")) == "quest_target" and String(n.get_meta("quest", "")) == "thorn_door":
			tg = true
	ok(tg, "the thorn seal is a quest_target on the map")
	# seal guards count from the spawner's progress
	Events.seal_progress.emit("henge", 2, 6)
	await _frames(1)
	ok(int(Book.q("thorn_door").get("n", 0)) == 2 and int(Book.q("thorn_door").get("of", 0)) == 6, "seal guards counted 2/6")
	var lines: Array = story.call("objectives")
	var tracked := false
	for o: Dictionary in lines:
		if String(o.id) == "quest:thorn_door" and String(o.get("title", "")) == "Thorns at the Door" and int(o.get("n", -1)) == 2 and int(o.get("of", 0)) == 6:
			tracked = true
	ok(tracked, "the tracker shows the task's name and 2/6")
	var ol := get_tree().root.find_child("Objectives", true, false)
	if ol:
		ol.call("show_lines", lines)
		var txt := " ".join(ol.call("lines"))
		ok(txt.contains("2/6"), "the HUD tracker draws the count (%s)" % txt)
	Travel.seals_broken["henge"] = true
	runner.call("check")
	await _frames(1)
	ok(Book.ready("thorn_door"), "the seal broken: only the turn-in is left")
	_refresh()
	ok(markers.call("mark_of", wyck) == "turnin", "Wyck wears the '?' (%s)" % markers.call("mark_of", wyck))
	m = wyck.get_node_or_null("QuestMark")
	ok(m != null and String(m.get_meta("map_kind", "")) == "quest_turnin" and (m.get_node("Glyph") as Label3D).text == "?", "the turn-in is a map marker and a '?'")
	# the turn-in screen: a choice is wanted, the chosen piece reaches the bag
	picked = await _pick_in_talk(wyck, "Thorns at the Door")
	await _frames(3)
	ok(bool(offer.call("is_open")) and offer.get("mode") == "turnin", "the turn-in screen opens from Wyck's hub")
	offer.call("_confirm")
	await _frames(1)
	ok(not Book.done("thorn_door") and bool(offer.call("is_open")), "no piece chosen: not handed in yet")
	var want := String((offer.get("_pieces") as Array)[1].name)
	var bag0 := (GearStats.state().bag as Array).size()
	var ash0 := Travel.count("grave_ash")
	offer.call("pick", 1)
	offer.call("_confirm")
	await _frames(2)
	ok(Book.done("thorn_door"), "handed in")
	var bag: Array = GearStats.state().bag
	ok(bag.size() == bag0 + 1 and String((bag.back() as Dictionary).get("name", "")) == want, "the chosen piece (%s) is in the gear bag" % want)
	ok(Travel.count("grave_ash") == ash0 + 15, "and the ash (+15)")
	_refresh()
	ok(markers.call("mark_of", wyck) == "available", "Wyck has the next of his chain (%s)" % markers.call("mark_of", wyck))


# --- collect, the count toast, the daily ---------------------------------------------------------------

func _collect_and_daily() -> void:
	print("collect / daily")
	Runner.chance_override = 1.0
	ok(Book.accept("hearth_ash"), "Ash for the Hearthfire taken")
	for i in 3:
		runner.call("note_kill", "wretch", Vector2(0, 0))
	ok(int(Book.q("hearth_ash").get("n", 0)) == 3, "three handfuls of bone ash")
	var pl: PackedStringArray = qlog.call("progress_lines")
	ok(pl.size() > 0 and pl[0] == "Bone ash: 3/5", "the count toast (%s)" % [pl])
	for i in 2:
		runner.call("note_kill", "crawler", Vector2(50, 50))
	ok(Book.ready("hearth_ash"), "five: back to Fennick")
	_refresh()
	ok(markers.call("mark_of", _v("fennick")) == "turnin", "Fennick wears the '?'")
	ok(Book.turn_in("hearth_ash", -1) and Book.done("hearth_ash"), "handed in (no gear on this one)")
	ok(not Giver.available("hearth_ash", get_tree()), "done for today")
	Book.day_override = "2099-01-01"
	ok(Giver.available("hearth_ash", get_tree()) and Book.accept("hearth_ash") and int(Book.q("hearth_ash").get("c", 0)) == 1, "back the next day (handed in once before)")
	Book.drop("hearth_ash")
	Book.day_override = ""
	Runner.chance_override = 0.0
	Book.accept("hearth_ash")
	runner.call("note_kill", "wretch", Vector2(0, 0))
	ok(int(Book.q("hearth_ash").get("n", 0)) == 0, "a drop that does not fall does not count")
	Book.drop("hearth_ash")
	Runner.chance_override = -1.0


# --- slay by kind and region -----------------------------------------------------------------------

func _slay_region() -> void:
	print("slay")
	Book.accept("road_clear")
	runner.call("note_kill", "wretch", Vector2(-30, 62))
	runner.call("note_kill", "wretch", Vector2(0, -100) + Endgame.O2)
	ok(int(Book.q("road_clear").get("n", 0)) == 1, "a kill on the Pilgrims' Road counts, one on the summit does not")
	Book.drop("road_clear")
	Book.accept("unpaid_toll")
	Book.advance("unpaid_toll", 2)             # past the trail and the bell-post's signs: the tollmen
	runner.call("note_kill", "wretch", Vector2(-92, -30))
	runner.call("note_kill", "tollman", Vector2(-92, -30))    # sheet 193: tollmen count where they stand (thornwood, henge)
	ok(int(Book.q("unpaid_toll").get("n", 0)) == 1, "only tollmen count for the toll")
	Book.drop("unpaid_toll")


# --- visit and carry ----------------------------------------------------------------------------------

func _visit() -> void:
	print("visit, and a lit lamp carried (lantern_walk)")
	VState.kindled_override = 1
	ok(Giver.available("spire_lamps", get_tree()), "the Spire's lamp is offered once a brazier burns")
	Book.accept("spire_lamps")
	var quests: Node = village.get("quests")
	await _frames(3)
	var lamp: Node = (quests.get("pickups") as Dictionary).get("spire_flame")
	ok(lamp != null, "a lamp waits to be lit at the green's fire")
	if lamp == null:
		Book.drop("spire_lamps")
		VState.kindled_override = 0
		return
	lamp.call("interact", player)
	await _frames(3)
	ok(Book.step("spire_lamps") == 1, "the lit lamp is taken: carrying it")
	await get_tree().create_timer(0.8).timeout
	Events.player_hurt.emit(1.0, Vector3.INF)
	await _frames(3)
	ok(Book.step("spire_lamps") == 0, "a blow puts the flame out: back to the green's fire")
	await _frames(3)
	lamp = (quests.get("pickups") as Dictionary).get("spire_flame")
	if lamp:
		lamp.call("interact", player)
		await _frames(3)
	var keep := player.global_position
	player.global_position = Vector3(-52.0, keep.y, -100.0)
	await _frames(4)
	ok(Book.step("spire_lamps") == 2, "the lamp reaches the Watchers' Spire: the vigil over it begins")
	player.global_position = keep
	Book.drop("spire_lamps")
	VState.kindled_override = 0


func _carry() -> void:
	print("carry")
	var quests: Node = village.get("quests")
	Book.accept("coal_shrine")
	await _frames(3)
	var p: Node = (quests.get("pickups") as Dictionary).get("coal")
	ok(p != null and p.is_in_group("map_marker") and String(p.get_meta("map_kind", "")) == "quest_target", "the coal waits in the green's fire, pinned on the map")
	if p == null:
		Book.drop("coal_shrine")
		return
	p.call("interact", player)
	await _frames(3)
	ok(Book.step("coal_shrine") == 1, "carrying the coal")
	runner.call("check")
	Book.q("coal_shrine")["left"] = 0.01
	await _frames(3)
	ok(Book.step("coal_shrine") == 0, "it went out: back for another")
	await _frames(3)
	p = (quests.get("pickups") as Dictionary).get("coal")
	if p:
		p.call("interact", player)
		await _frames(3)
	var keep := player.global_position
	player.global_position = Vector3(-31.0, keep.y, 4.0)
	runner.call("check")
	ok(Book.ready("coal_shrine"), "the coal reaches the shrine")
	player.global_position = keep
	# a choice is needed; the bad index is refused
	ok(not Book.turn_in("coal_shrine", 7), "a turn-in without a real choice is refused")
	ok(Book.turn_in("coal_shrine", 0) and Book.done("coal_shrine"), "handed in for the first piece")


# --- the ledger -------------------------------------------------------------------------------------

func _ledger() -> void:
	print("ledger")
	Book.accept("road_clear")
	Book.accept("drowned_bell")
	qlog.call("open")
	await _frames(1)
	var ids: Array = qlog.call("entries")
	ok(ids.find("road_clear") < ids.find("drowned_bell") and ids.find("drowned_bell") < ids.find("thorn_door"), "chapters by zone, finished after (%s)" % [ids])
	qlog.call("select", "road_clear")
	ok(Book.tracked("drowned_bell") and not Book.tracked("road_clear"), "the newest task is the one followed until another is picked")
	qlog.call("toggle_track")
	ok(Book.tracked("road_clear") and Book.followed() == "road_clear" and not Book.tracked("drowned_bell"), "Track picks it, and only it")
	var track := get_tree().get_first_node_in_group("quest_track")
	ok(track != null and String(track.get("current_id")) == "road_clear", "the tracker follows the pick at once")
	var on_hud := false
	for o: Dictionary in story.call("objectives"):
		if String(o.id) == "quest:road_clear":
			on_hud = true
	ok(on_hud, "and it heads the HUD")
	qlog.call("toggle_track")
	ok(not Book.tracked("road_clear") and Book.tracked(Book.MAIN), "Untrack hands the way back to the story")
	on_hud = false
	for o2: Dictionary in story.call("objectives"):
		if String(o2.id) == "quest:road_clear":
			on_hud = true
	ok(not on_hud, "and it is off the HUD")
	qlog.call("toggle_track")
	ok(Book.tracked("road_clear"), "back on")
	qlog.call("abandon")
	ok(Book.active("road_clear"), "one press only arms Abandon")
	qlog.call("abandon")
	ok(not Book.started("road_clear"), "the second abandons it")
	qlog.call("close")
	Book.drop("drowned_bell")
