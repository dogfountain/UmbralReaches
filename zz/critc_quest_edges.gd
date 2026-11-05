extends Node
## The tasks' edge cases in the built world (critique C), headless:
##   HOME=<scratch>/home godot --headless --path . res://zz/critc_quest_edges.tscn -- --realm-modules=land,rift,bosses,lore,flora,assets,village
## Checks:
##   hollow    Father Harrow freed without dying (a reload, a cleanup) wakes again when you come
##             back; far away he doesn't; killed, the lantern can be taken
##   aside     Oswin's walk can be set aside in his own words; he goes back to his night and the
##             task can be taken up again
##   reload    every step of every task survives the save's encoding and a cold sync of the world
##             side: the right pickups exist (live or not), nothing errors
##   order     the name-slates count in any order; a pickup for a later step is refused
##   freed     a villager freed while she talks: the box closes cleanly
##   rumours   the keep never sells "nothing new": once every rumour that holds is heard, the slate
##             says so and keeps the ash
## Never writes the save (Travel._busy, a village sandbox, Travel's progress put back). Ends:
## QEDGES PASS / QEDGES FAIL n; quits by itself (180 s cap).

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const QWorld := preload("res://core/story/quest_world.gd")
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
var _travel := {}


func ok(c: bool, what: String) -> void:
	print("  ok   " if c else "  FAIL ", what)
	if not c:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for key: String in ["seals_broken", "bosses_slain", "items", "story", "lit_by_path", "systems"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
	Travel.seals_broken = {}
	Travel.bosses_slain = {}
	Travel.items = {}
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	VState.sandbox = {"met": {"oswin": true, "abel": true, "nan": true, "hild": true}}
	VState.kindled_override = 0
	Book.quiet = true
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if t > 180.0:
		ok(false, "ran out of time")
		_end()
	if started:
		return
	village = get_tree().root.find_child("Village", true, false) as Node3D
	if village == null or not village.has_meta("village_done"):
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
	Book.quiet = false
	print("QEDGES %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	quests = village.get("quests")
	story = get_tree().get_first_node_in_group("story")
	ui = story.get("ui") if story else null
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if quests == null or ui == null or player == null:
		ok(false, "world pieces present")
		_end()
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		if n != quests.get("hollow"):
			(n as Node).queue_free()
	village.set("clock", 600.0 * 0.2)
	village.set("time_scale", 0.0)
	await _frames(3)
	await _hollow()
	await _aside()
	await _reload()
	await _order()
	await _freed()
	_map_pins()
	_rumours()
	_end()


## Talk to `npc`, picking the choices whose words contain each of `picks` in turn.
func converse(npc: Node, picks: Array) -> void:
	npc.call("interact", player)
	await _frames(1)
	var pi := 0
	for guard in 60:
		if not bool(ui.call("is_open")):
			break
		ui.call("finish_line")
		var btns: Array = ui.get("_buttons")
		if btns.is_empty():
			ui.call("press")
			await _frames(1)
			continue
		var idx := -1
		if pi < picks.size():
			for i in btns.size():
				if (btns[i] as Button).text.contains(String(picks[pi])):
					idx = i
					break
		if idx < 0:
			ui.call("close")
			ui.emit_signal("closed")
			await _frames(1)
			break
		pi += 1
		ui.emit_signal("chosen", idx)
		await _frames(1)
	await _frames(2)


func _reset(id: String) -> void:
	(Book.st().quests as Dictionary).erase(id)
	quests.call("sync")


# --- the hollowed man -------------------------------------------------------------------------------

func _hollow() -> void:
	print("hollow")
	Book.start("slow_way")
	quests.call("sync")
	var at: Vector3 = QWorld.spots.get("hollow", Vector3.INF)
	if at == Vector3.INF:
		ok(false, "the fen spot exists")
		return
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var home := player.global_position
	player.global_position = at + Vector3(6.0, 1.0, 0.0)
	await get_tree().create_timer(0.6).timeout
	var h: Node3D = quests.get("hollow")
	ok(Book.step("slow_way") == 1 and is_instance_valid(h), "he wakes on approach")
	# freed without dying (a reload, a cleanup): the step stays, he stands again when you come back
	if is_instance_valid(h):
		h.queue_free()
	player.global_position = at + Vector3(80.0, 1.0, 0.0)
	await get_tree().create_timer(0.6).timeout
	ok(Book.step("slow_way") == 1 and not is_instance_valid(quests.get("hollow")), "far off (80 m): he does not stand again yet")
	player.global_position = at + Vector3(20.0, 1.0, 0.0)
	await get_tree().create_timer(0.6).timeout
	var h2: Node3D = quests.get("hollow")
	ok(is_instance_valid(h2) and Book.step("slow_way") == 1, "back within reach: he stands again")
	ok(not bool((quests.get("pickups") as Dictionary).lantern.call("can_interact")), "the lantern still can't be taken past him")
	if is_instance_valid(h2):
		Events.enemy_killed.emit(h2)
		h2.queue_free()
	await _frames(3)
	ok(Book.step("slow_way") == 2 and bool((quests.get("pickups") as Dictionary).lantern.call("can_interact")), "at rest: the lantern can be taken")
	player.global_position = home
	player.process_mode = Node.PROCESS_MODE_INHERIT
	_reset("slow_way")


# --- Oswin's walk set aside -------------------------------------------------------------------------

func _aside() -> void:
	print("aside")
	var oswin: Node3D = (village.get("villagers") as Dictionary).get("oswin")
	if oswin == null:
		ok(false, "Oswin is here")
		return
	player.global_position = oswin.global_position + Vector3(1.4, 0.3, 0.0)
	await converse(oswin, ["count the waystones", "walk with you"])
	ok(Book.active("forty_first") and oswin.get("follow") == player, "the walk begins")
	await converse(oswin, ["Another night"])
	ok(not Book.started("forty_first"), "set aside: the task is gone from the ledger")
	await _frames(3)
	ok(oswin.get("follow") == null and not bool(oswin.get("pinned")), "Oswin stops following and is his own again")
	ok(Book.lines(4).filter(func(o: Dictionary) -> bool: return String(o.id) == "quest:forty_first").is_empty(), "no objective line left")
	await converse(oswin, ["count the waystones", "walk with you"])
	ok(Book.active("forty_first") and oswin.get("follow") == player, "and it can be taken up again")
	_reset("forty_first")
	await _frames(3)
	ok(oswin.get("follow") == null, "a dropped walk releases him even without words (reload)")


# --- reload at every step -----------------------------------------------------------------------------

func _reload() -> void:
	print("reload")
	for id: String in Chains.ORDER:
		var n := (Chains.QUESTS[id].steps as Array).size()
		for s in n + 1:
			var d := {"s": s, "d": s >= n, "p": "truth" if s >= n else "", "f": {}, "t": 1}
			Travel.story["quests"] = {id: d}
			# through the save's encoding, like a quit and a load
			var cfg := ConfigFile.new()
			cfg.set_value("story", "state", Travel.story)
			var txt := cfg.encode_to_text()
			var back := ConfigFile.new()
			ok(back.parse(txt) == OK, "%s step %d encodes" % [id, s])
			Travel.story = back.get_value("story", "state", {})
			quests.call("sync")
			await _frames(1)
			var pk: Dictionary = quests.get("pickups")
			var want := 0
			for k: String in Chains.PICKUPS:
				var p: Dictionary = Chains.PICKUPS[k]
				if String(p.quest) == id and int(p.step) == s and s < n:
					want += 1
					if not pk.has(k):
						ok(false, "%s step %d: pickup %s exists after a reload" % [id, s, k])
			var mine := pk.keys().filter(func(k: String) -> bool: return String(Chains.PICKUPS[k].quest) == id)
			ok(mine.size() >= want, "%s step %d/%d: %d pickups (%d wanted)" % [id, s, n, mine.size(), want])
			for k2: String in pk:
				ok(is_instance_valid(pk[k2]), "%s step %d: pickup %s is a live node" % [id, s, k2])
		Travel.story["quests"] = {}
		quests.call("sync")
		await _frames(2)
	var oswin: Node3D = (village.get("villagers") as Dictionary).get("oswin")
	ok(oswin == null or oswin.get("follow") == null, "after the reloads Oswin is nobody's escort")


# --- out of order -----------------------------------------------------------------------------------

func _order() -> void:
	print("order")
	Book.start("names_yard")
	quests.call("sync")
	for k: String in ["slate_barrow", "slate_glade"]:
		quests.call("take", k)
	ok(Book.step("names_yard") == 0 and Book.found("names_yard").size() == 2, "two slates, any order: still gathering")
	quests.call("take", "slate_barrow")
	ok(Book.found("names_yard").size() == 2, "the same slate twice counts once")
	quests.call("take", "slate_lane")
	ok(Book.step("names_yard") == 1, "the third, any order: back to Abel")
	_reset("names_yard")
	Book.start("keg_thief")
	quests.call("take", "mug_fire")
	ok(Book.step("keg_thief") == 0, "the mug by the fire before the one behind the Keg: refused")
	_reset("keg_thief")


# --- a villager freed mid-conversation ---------------------------------------------------------------

func _freed() -> void:
	print("freed")
	var vs: Dictionary = village.get("villagers")
	var who: Node3D = vs.get("grisel")
	if who == null:
		ok(false, "Grisel is here")
		return
	who.call("interact", player)
	await _frames(1)
	ok(bool(ui.call("is_open")), "talking to her")
	vs.erase("grisel")
	who.queue_free()
	await _frames(3)
	ui.call("finish_line")
	ui.call("press")
	await _frames(2)
	ui.call("close")
	ui.emit_signal("closed")
	await _frames(2)
	var talker: Node = village.get("talker")
	ok(not bool(ui.call("is_open")) and not bool(talker.call("active")), "the box closes cleanly, the talk ends")


# --- the Journal map's task rings ---------------------------------------------------------------------

func _map_pins() -> void:
	print("map")
	var codex := get_tree().root.find_child("Codex", true, false)
	if codex == null:
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if c.has_method("_task_pins"):
				codex = c
	if codex == null:
		ok(false, "the Journal exists")
		return
	ok((codex.call("_task_pins") as Array).is_empty(), "no tasks, no rings")
	Book.start("names_yard")
	Book.start("slow_way")
	Book.start("forty_first")
	quests.call("sync")
	var pins: Array = codex.call("_task_pins")
	ok(pins.size() == 3, "three tasks under way, three rings (%d)" % pins.size())
	var all: Array = codex.call("_pins")
	ok(all.filter(func(p: Dictionary) -> bool: return String(p.kind) == "keg").size() == 1, "the Keg is on the map")
	ok(all.filter(func(p: Dictionary) -> bool: return String(p.kind) in ["fire", "ash"]).size() == 4, "the four braziers are on the map")
	for k: String in ["names_yard", "slow_way", "forty_first"]:
		_reset(k)
	(Book.st().quests as Dictionary).clear()
	quests.call("sync")


# --- rumours -------------------------------------------------------------------------------------------

func _rumours() -> void:
	print("rumours")
	Travel.items = {"grave_ash": 400}
	var bought := 0
	for i in 40:
		var row := {}
		for r: Dictionary in Shop.stock("keep", get_tree()):
			if String(r.id) == "rumour":
				row = r
		if not bool(row.get("ok", false)):
			break
		(Shop._sold as Dictionary).clear()    # a new village night each time: stock is not the limit
		var res := Shop.buy("keep", "rumour", get_tree())
		if bool(res.ok):
			bought += 1
	var ash := Travel.count("grave_ash")
	var last := Shop.buy("keep", "rumour", get_tree())
	ok(bought > 3, "rumours sold while there were new ones (%d)" % bought)
	ok(not bool(last.ok) and Travel.count("grave_ash") == ash, "then the slate says nothing new, and keeps the ash: %s" % last.say)
