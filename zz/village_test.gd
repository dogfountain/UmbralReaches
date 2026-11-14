extends Node
## Village system test (headless):
##   godot --headless --path . res://zz/village_test.tscn -- --realm-modules=land,rift,bosses,lore,flora,assets,village
## Never writes the player's save: Travel._busy is held for the whole run and the village state is
## a sandbox dictionary; Travel's in-memory progress is put back before quitting.
## Checks:
##   data       conversations (targets, conditions), routines (nodes, anchors), restorations
##   network    every node a villager's routines use is on the walking network and reachable
##              from its home; dropped edges are listed
##   people     the first-night cast is present (7), the returning four are not
##   routines   at 10x time for ~90 village-seconds each villager finishes steps, walkers walk,
##              the phase changes, the lamplighter lights lamps, the smith strikes the anvil
##   ground     sampled every few frames: each visible villager stands on the floor (within 0.3 m),
##              its column is clear of walls and props, and it is never inside a cottage or the Keg
##   restore    progress set in memory: every restoration comes true, its overlay is built, Col, Bet,
##              Wenna and Pell arrive; clearing progress undoes nothing; the state survives the save's
##              ConfigFile encoding
##   talk       the dialogue box opens on a villager, lines advance, the ash-wife's shop sells lamp oil
## Ends: VILLAGE TEST PASS  /  VILLAGE TEST FAIL n
const VillageScript := preload("res://core/life/village/village.gd")
const Cast := preload("res://core/life/village/village_cast.gd")
const VState := preload("res://core/life/village/village_state.gd")
const TalkDB := preload("res://core/life/village/village_talk_db.gd")
const Props := preload("res://core/life/village/village_props.gd")

var fails := 0
var t := 0.0
var started := false
var village: Node3D
var _travel := {}
var samples := 0
var bad_ground := 0
var bad_inside := 0
var bad_clear := 0
var strikes := 0
var lit_before := 0


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
		if t > 150.0:
			fail_end("the village never finished building")
		return
	started = true
	_run()


func fail_end(why: String) -> void:
	ok(false, why)
	_end()


func _run() -> void:
	print("VILLAGE built in %d ms" % int(village.get("build_ms")))
	for line: String in village.get("report"):
		print("  report ", line)
	_network()
	_people()
	await _routines()
	await _restore()
	await _talk()
	_end()


func _end() -> void:
	for key: String in _travel:
		Travel.set(key, _travel[key])
	VState.sandbox = null
	VState.kindled_override = -1
	print("VILLAGE TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


# --- data -----------------------------------------------------------------------------------------

func _data() -> void:
	print("data")
	var bad := 0
	for cid: String in TalkDB.CONV:
		var c: Dictionary = TalkDB.CONV[cid]
		var nodes: Dictionary = c.nodes
		for pair: Array in c.start:
			if not nodes.has(String(pair[1])) or VState.audit_cond(String(pair[0])) != "":
				bad += 1
				print("    bad start ", cid, " ", pair)
		for nid: String in nodes:
			var n: Dictionary = nodes[nid]
			var nx := String(n.get("next", ""))
			if nx != "" and not nodes.has(nx):
				bad += 1
				print("    bad next ", cid, ":", nid)
			for pair2: Array in n.get("say_if", []):
				if VState.audit_cond(String(pair2[0])) != "":
					bad += 1
					print("    bad cond ", cid, ":", nid, " ", pair2[0])
			if n.has("say_if") and String((n.say_if as Array).back()[0]) != "":
				bad += 1
				print("    no fallback ", cid, ":", nid)
			for ch: Dictionary in n.get("choices", []):
				var to := String(ch.get("to", ""))
				if to != "" and not nodes.has(to):
					bad += 1
					print("    bad choice ", cid, ":", nid, " -> ", to)
				if VState.audit_cond(String(ch.get("if", ""))) != "":
					bad += 1
		if not VillageScript.cast_all().has(cid):          # Hearthward's cast and the Marches' outposts
			bad += 1
			print("    conversation without a villager ", cid)
	for vid: String in Cast.CAST:
		if not TalkDB.CONV.has(vid):
			bad += 1
			print("    villager without a conversation ", vid)
		if VState.audit_cond(String(Cast.CAST[vid].get("when", ""))) != "":
			bad += 1
	for r: Dictionary in Cast.RESTORE:
		if VState.audit_cond(String(r.when)) != "":
			bad += 1
			print("    bad restore ", r.id)
	for w: Dictionary in Cast.WARES:
		if VState.audit_cond(String(w.get("if", ""))) != "":
			bad += 1
	ok(bad == 0, "conversations, conditions, restorations and wares parse (%d conversations)" % TalkDB.CONV.size())


# --- network --------------------------------------------------------------------------------------

func _route_nodes(vid: String) -> Array:
	var d: Dictionary = Cast.CAST[vid]
	var out := [String(d.home)]
	for rname: String in d.routines:
		for s: Dictionary in d.routines[rname]:
			for key: String in ["at", "go", "hide"]:
				if s.has(key) and String(s[key]) != "@home":
					out.append(String(s[key]))
	for cond: String in d.get("home_when", {}):
		out.append(String(d.home_when[cond]))
	if vid == "fennick":
		for l: Dictionary in Cast.LAMPS:
			out.append(String(l.spot))
	return out


func _network() -> void:
	print("network")
	var nav: RefCounted = village.get("nav")
	for vid: String in Cast.CAST:
		var d: Dictionary = Cast.CAST[vid]
		var home := String(d.home)
		if not nav.call("has", home):
			ok(false, "%s: home %s on the network" % [vid, home])
			continue
		var reach: Dictionary = nav.call("reachable", home)
		var missing: Array = []
		for n: String in _route_nodes(vid):
			if not reach.has(n):
				missing.append(n)
		ok(missing.is_empty(), "%s: every stop reachable from %s %s" % [vid, home, "" if missing.is_empty() else str(missing)])
	for key: String in ["@anvil", "@coals", "@water", "@wheel", "@cart", "@fire", "@grave", "@pit", "@block_col"]:
		ok(village.call("anchor", key) != Vector3.INF, "anchor %s placed" % key)


# --- people ---------------------------------------------------------------------------------------

func _people() -> void:
	print("people")
	var vs: Dictionary = village.get("villagers")
	for vid: String in ["hild", "fennick", "oswin", "nan", "grisel", "wyck", "abel"]:
		ok(vs.has(vid), "%s is here on the first night" % vid)
	for vid2: String in ["col", "bet", "wenna", "pell"]:
		ok(not vs.has(vid2), "%s is not here yet" % vid2)


# --- routines and ground --------------------------------------------------------------------------

func _routines() -> void:
	print("routines")
	var vs: Dictionary = village.get("villagers")
	var start := {}
	for vid: String in vs:
		start[vid] = (vs[vid] as Node).call("info")
	var lit0: int = village.call("_lit_count")
	var phase0 := String(village.get("phase"))
	var phases := {phase0: true}
	village.set("time_scale", 10.0)
	village.set("clock", 600.0 * 0.53)     # start just before midnight: the routines must change over
	# the hammer: count anvil strikes through the flare
	var steps := 0
	var frames := 0
	while frames < 900:
		await get_tree().process_frame
		frames += 1
		phases[String(village.get("phase"))] = true
		if float(village.get("_flare")) > 0.95:
			strikes += 1
		if frames % 6 == 0:
			_sample(vs)
	village.set("time_scale", 1.0)
	print("    phases seen %s, lamps lit %d -> %d" % [str(phases.keys()), lit0, int(village.call("_lit_count"))])
	for vid: String in vs:
		var a: Dictionary = start[vid]
		var b: Dictionary = (vs[vid] as Node).call("info")
		print("    %-8s steps %d -> %d, walked %.1f m, now %s %s at %s" % [vid, int(a.steps), int(b.steps), float(b.walked), b.state, b.act, b.at])
		ok(int(b.steps) > int(a.steps), "%s moves on through its routine" % vid)
	var walkers := 0
	for vid2: String in vs:
		if float((vs[vid2] as Node).call("info").walked) > 3.0:
			walkers += 1
	ok(walkers >= 4, "at least four villagers walked somewhere (%d)" % walkers)
	ok(phases.size() >= 2, "the village night moved through phases (%d)" % phases.size())
	ok(strikes > 3, "Hild struck the anvil (%d flares)" % strikes)
	ok(samples > 200, "sampled %d villager positions" % samples)
	ok(bad_ground == 0, "every villager on the floor (%d off)" % bad_ground)
	ok(bad_clear == 0, "no villager inside a wall or prop (%d)" % bad_clear)
	ok(bad_inside == 0, "no villager inside a cottage or the Keg (%d)" % bad_inside)


func _sample(vs: Dictionary) -> void:
	var nav: RefCounted = village.get("nav")
	var ex: Array[RID] = []
	for vid: String in vs:
		ex.append(((vs[vid] as Node).get("body") as CollisionObject3D).get_rid())
	nav.call("use_space", village.get_world_3d().direct_space_state, ex)
	for vid2: String in vs:
		var v: Node3D = vs[vid2]
		if bool(v.get("hidden")):
			continue
		samples += 1
		var p := v.global_position
		var fy: float = nav.call("floor_at", p.x, p.z)
		if absf(fy - p.y) > 0.3:
			bad_ground += 1
			if bad_ground < 6:
				print("    off floor: %s at %s (floor %.2f)" % [vid2, p, fy])
		if String(v.get("state")) == "walk" and not bool(nav.call("clear", Vector3(p.x, fy, p.z))):
			bad_clear += 1
			if bad_clear < 6:
				print("    in a wall or prop: %s at %s (goal %s)" % [vid2, p, (v.call("info") as Dictionary).get("goal", "")])
			if bad_clear < 6:
				print("    in something: %s at %s" % [vid2, p])
		var inside := _inside_building(p)
		if inside != "":
			bad_inside += 1
			if bad_inside < 6:
				print("    inside %s: %s at %s" % [inside, vid2, p])
	nav.call("use_space", village.get_world_3d().direct_space_state, [] as Array[RID])


func _inside_building(p: Vector3) -> String:
	var homes := [["maud", Vector2(-17, 42), 6.6, 5.0, Vector2(0, 33), 0.0], ["cobb", Vector2(-33, 37.5), 7.0, 5.4, Vector2.INF, PI * 0.5 + 0.15]]
	for id: String in Props.COTTAGES:
		var xf := Props.cottage_xf(id)
		var c: Dictionary = Props.COTTAGES[id]
		var l := xf.affine_inverse() * p
		if absf(l.x) < float(c.w) * 0.5 - 0.35 and absf(l.z) < float(c.d) * 0.5 - 0.35:
			return id
	for h: Array in homes:
		var ctr: Vector2 = h[1]
		var yaw: float = h[5]
		if h[4] != Vector2.INF:
			var dd: Vector2 = (h[4] as Vector2) - ctr
			yaw = atan2(-dd.x, -dd.y)
		var l2 := Transform3D(Basis(Vector3.UP, yaw), Vector3(ctr.x, 0, ctr.y)).affine_inverse() * Vector3(p.x, 0, p.z)
		if absf(l2.x) < float(h[2]) * 0.5 - 0.35 and absf(l2.z) < float(h[3]) * 0.5 - 0.35:
			return String(h[0])
	if Rect2(10.5, 26.1, 15.0, 8.2).has_point(Vector2(p.x, p.z)):
		return "the Keg"
	return ""


# --- restoration ----------------------------------------------------------------------------------

func _restore() -> void:
	print("restore")
	var toasts: Array[String] = []
	var mine := Cast.RESTORE.map(func(r: Dictionary) -> String: return String(r.toast))
	# only the village's own announcements (other systems toast on a boss down too: remembrances)
	var cb := func(s: String) -> void:
		if s in mine:
			toasts.append(s)
	Events.toast.connect(cb)
	VState.kindled_override = 4
	(VState.data().flags as Dictionary)["oil"] = true    # sheet 156: the longer round is the oil, not three fires
	Travel.seals_broken = {"henge": true, "oss_gallery": true, "summit": true}
	Travel.bosses_slain = {"thornwarden": true, "bone_abbot": true, "ascended_warden": true}
	village.call("refresh", true)
	await get_tree().process_frame
	var d := VState.data()
	for r: Dictionary in Cast.RESTORE:
		var id := String(r.id)
		ok(VState.restored(id), "restored: %s" % id)
		ok((village.get("overlays") as Dictionary).has(id), "built: %s" % id)
	ok(toasts.size() == Cast.RESTORE.size(), "each restoration announced once (%d toasts%s)" % [toasts.size(), "" if toasts.size() == Cast.RESTORE.size() else ": " + str(toasts)])
	var vs: Dictionary = village.get("villagers")
	for vid: String in ["col", "bet", "wenna", "pell"]:
		ok(vs.has(vid), "%s has come back" % vid)
	ok(VState.lamps().size() == Cast.LAMPS.size(), "every lamp on the round (%d)" % VState.lamps().size())
	# progress cleared in memory (a test, a new game): nothing is undone, nothing re-announced
	Travel.seals_broken = {}
	Travel.bosses_slain = {}
	VState.kindled_override = 0
	village.call("refresh", true)
	ok(VState.restored("pell") and VState.restored("wrights_home"), "restorations stay after progress is cleared")
	ok(toasts.size() == Cast.RESTORE.size(), "no second announcement")
	# the state survives the save file's encoding (Travel writes [systems] state with ConfigFile)
	var cfg := ConfigFile.new()
	cfg.set_value("systems", "state", {"village": d})
	var back := ConfigFile.new()
	back.parse(cfg.encode_to_text())
	var got: Dictionary = (back.get_value("systems", "state", {}) as Dictionary).get("village", {})
	ok((got.get("restored", {}) as Dictionary).size() == Cast.RESTORE.size(), "restorations persist through the save format")
	ok((got.get("announced", {}) as Dictionary).size() == Cast.RESTORE.size(), "announcements persist")
	# and through the real Travel.system_state path
	VState.sandbox = null
	var real := VState.data()
	real["restored"] = (d.restored as Dictionary).duplicate()
	ok(Travel.system_state("village").has("restored") and (Travel.systems.village.restored as Dictionary).size() == Cast.RESTORE.size(), "Travel.system_state('village') carries the village")
	VState.sandbox = d
	Events.toast.disconnect(cb)


# --- talking --------------------------------------------------------------------------------------

func _talk() -> void:
	print("talk")
	var vs: Dictionary = village.get("villagers")
	var story := get_tree().get_first_node_in_group("story")
	var ui: Variant = story.get("ui") if story else null
	if ui == null:
		ok(false, "the story's dialogue box exists")
		return
	var talker: Node = village.get("talker")
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	# Hild: a few lines, then leave
	(vs.hild as Node).call("interact", player)
	await get_tree().process_frame
	ok(bool(ui.call("is_open")) and bool(talker.call("active")), "talking to Hild opens the box")
	for i in 6:
		ui.call("finish_line")
		if int(ui.call("choice_count")) > 0:
			break
		ui.call("press")
		await get_tree().process_frame
	ok(int(ui.call("choice_count")) >= 3, "Hild offers choices (%d)" % int(ui.call("choice_count")))
	ui.call("finish_line")
	ui.emit_signal("chosen", int(ui.call("choice_count")) - 1)
	await get_tree().process_frame
	ok(not bool(ui.call("is_open")) and not bool(talker.call("active")), "goodbye closes the box")
	ok(VState.met("hild"), "Hild remembers meeting you")
	# Grisel sells lamp oil (her conversation opens the shop, ui/shop.gd)
	VState.data().flags.erase("oil")
	VState.data().flags.erase("oil2")
	# oil is only sold while the lamps it would light are dark (critique C: it was sold, and did
	# nothing, after the braziers or the bosses had already lit Fennick's round)
	(VState.data().restored as Dictionary).erase("lamps_more")
	(VState.data().restored as Dictionary).erase("lamps_all")
	Travel.items = {"grave_ash": 20}
	(vs.grisel as Node).call("interact", player)
	await get_tree().process_frame
	var offered := false
	for j in 8:
		ui.call("finish_line")
		var said: Array = talker.get("said")
		if int(ui.call("choice_count")) > 0 and String(said.back()).contains("Ash, then"):
			ui.emit_signal("chosen", 0)          # "Show me your wares."
			offered = true
			break
		ui.call("press")
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var shop: Variant = story.get("shop")
	ok(offered and shop != null and bool((shop as Object).call("is_open")), "the ash-wife's wares are offered")
	ok(shop != null and bool((shop as Object).call("buy", "oil")), "lamp oil bought")
	ok(Travel.count("grave_ash") == 12 and VState.flag("oil"), "lamp oil bought for 8 ash (%d left)" % Travel.count("grave_ash"))
	if shop != null:
		(shop as Object).call("close")
	await get_tree().process_frame
	# talk again and leave with Esc mid-way
	(vs.grisel as Node).call("interact", player)
	await get_tree().process_frame
	ui.call("close")
	await get_tree().process_frame
	ok(not bool(talker.call("active")), "closing the box ends the conversation")
	ok(not get_tree().paused, "the world runs again")
