extends Node
## r36 the living world, end to end in the Realm (docs/critique/r36_plan.md, steps 4-7):
##   HOME=<scratch>/home godot --headless --path . res://zz/r36_world_test.tscn
## The Kindled Watch (posts built, watchmen wake, an assault is met blade to blade), the roaming
## events (each kind starts and spawns its part), horses (stables, buying, riding forward, getting
## down, the call), the night's state (acts, a rung bell's quiet and its light, factions) and the
## keep's bounties. Counts engine errors: any error fails. Never writes the save (Travel._busy).
## Ends: R36WORLD PASS / R36WORLD FAIL n

const Chains := preload("res://core/story/quest_chains.gd")
const Book := preload("res://core/story/quest_book.gd")
const ReachState := preload("res://core/world/night/reach_state.gd")
const Horse := preload("res://core/world/mount/horse.gd")

class Errs extends Logger:
	var n := 0
	var last: Array[String] = []
	func _log_error(_f: String, _file: String, _line: int, code: String, rationale: String, _e: bool, kind: int, _bt: Array[ScriptBacktrace]) -> void:
		if kind == ERROR_TYPE_WARNING:
			return
		n += 1
		if last.size() < 6:
			last.append("%s %s" % [code, rationale])

var errs := Errs.new()
var fails := 0
var main: Node
var p: Player
var _travel := {}


const WatchPosts := preload("res://core/world/watch/watch_posts.gd")

const HorseDB := preload("res://core/world/mount/horse_db.gd")

func _init() -> void:
	Engine.set_meta(&"full_night", true)   # the 30-minute slice hides horses, watch, roaming events, dailies, attunements


func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(errs)
	Travel._busy = true
	for key: String in ["bosses_slain", "items", "relics", "systems", "story"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
		Travel.set(key, {})
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		if main.has_meta("realm_done") and main.get_node_or_null("Watches") != null:
			break
	for i in 30:
		await get_tree().physics_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		ok(false, "the world and the wanderer came up")
	else:
		await _watch()
		await _roam()
		await _horses()
		_reach()
		_bounties()
	for key: String in _travel:
		Travel.set(key, _travel[key])
	ok(errs.n == 0, "no engine errors (%d)%s" % [errs.n, ("\n        " + "\n        ".join(errs.last)) if errs.n > 0 else ""])
	print("R36WORLD %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _watch() -> void:
	print("-- the Kindled Watch")
	var posts := get_tree().get_nodes_in_group(&"watch_post")
	ok(posts.size() == WatchPosts.POSTS.size(), "every watch-post stands (%d of %d)" % [posts.size(), WatchPosts.POSTS.size()])
	if posts.is_empty():
		return
	var w: Node3D = posts[0]
	p.teleport(w.global_position + Vector3(0, 0.5, 0) - (w.get("face") as Vector3) * 6.0)
	await _wait(1.6)
	var inf: Dictionary = w.call("info")
	ok(bool(inf.awake) and int(inf.men) == 3, "its three watchmen wake when you come (%s)" % inf)
	# the dark comes; the wanderer stands off and watches
	w.set("_next", 0.0)
	await _wait(1.5)
	inf = w.call("info")
	ok(int(inf.wave) >= 3, "an assault comes at the post (%d hollowed)" % int(inf.wave))
	var wave: Array = w.get("_wave")
	var hp0 := 0.0
	for e in wave:
		hp0 += float((e as Enemy).hp)
	p.teleport(w.global_position + Vector3(0, 0.5, 0) - (w.get("face") as Vector3) * 12.0)
	var hp1 := hp0
	for _k in 20:                         # a blow lands within a few swings; under a loaded machine give it up to 20 s
		await _wait(1.0)
		hp1 = 0.0
		for e in w.get("_wave"):
			if is_instance_valid(e):
				hp1 += float((e as Enemy).hp)
		inf = w.call("info")
		if hp1 < hp0 or int(inf.wave) < wave.size():
			break
	ok(hp1 < hp0 or int(inf.wave) < wave.size(), "the watchmen cut at the hollowed (%.1f -> %.1f life left)" % [hp0, hp1])
	# clean up whatever is left so the next checks start quiet
	for e in w.get("_wave"):
		if is_instance_valid(e):
			(e as Enemy).take_hit(999.0, null)
	await _wait(0.6)
	ok(int((w.call("info") as Dictionary).wave) == 0, "the wave is broken")
	var held: Dictionary = (Travel.system_state("watch").get("held", {}) as Dictionary)
	ok(int(held.get(String(w.get("id")), 0)) >= 1 or bool((w.call("info") as Dictionary).fallen), "the post holds (or fell) and remembers it")


func _roam() -> void:
	print("-- roaming events")
	var r := main.get_node_or_null("RoamEvents")
	ok(r != null, "the roaming events run")
	if r == null:
		return
	# out in the Thornwood by west_track: nothing of the dark starts within 100 m of Hearthward's roads (Director.fair_ground)
	var out_at := Vector3(-112.0, 0.0, -40.0)
	out_at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, out_at.x, out_at.z) + 0.3
	for k: String in ["procession", "tear", "pilgrim", "incursion"]:
		p.teleport(out_at)
		await _wait(0.4)
		var started := bool(r.call("start", k))
		if k == "incursion" and not started:
			print("  (no lit brazier in reach for an incursion)")
			continue
		ok(started, "%s starts" % k)
		await _wait(1.2)
		var inf: Dictionary = r.call("info")
		ok(String(inf.kind) == k and (int(inf.foes) > 0 or k == "pilgrim" or k == "tear"), "%s: it is on (%s)" % [k, inf])
		r.call("_end", false)
		await _wait(0.2)
	ok(String((r.call("info") as Dictionary).kind) == "", "an event ends and the next waits")


func _horses() -> void:
	print("-- horses")
	var hs := get_tree().get_nodes_in_group(&"horse")
	ok(hs.size() == HorseDB.BREEDS.size(), "every breed at its post (%d of %d)" % [hs.size(), HorseDB.BREEDS.size()])
	if hs.is_empty():
		return
	var h: Node3D = hs[0]
	p.teleport(h.global_position + Vector3(1.5, 0.5, 0.0))
	await _wait(0.4)
	Travel.items["grave_ash"] = 0
	# through the wanderer's own [E] (the sensor finds it), not a call on the horse
	var it: Variant = p.get("_interact_target")
	ok(it == h, "[E] finds the horse beside you (%s)" % (str((it as Node).get_path()) + " " + str((it as Node).get_script().resource_path if (it as Node).get_script() else "") if it is Node else str(it)))
	p.call("_try_interact")
	ok(not bool(h.call("owned")), "no ash, no horse")
	Travel.items["grave_ash"] = 200
	p.call("_try_interact")
	ok(bool(h.call("owned")), "bought with grave ash")
	p.call("_try_interact")
	ok(p.riding == h, "mounted")
	await _wait(1.3)                       # the climb on (horse.gd MOUNT_T): it stands meanwhile
	# ride in open ground (the meadow south of the Rift), whatever stands round the stable
	var sp := h.get_world_3d().direct_space_state
	var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40.0, 60.0, 20.0), Vector3(-40.0, -40.0, 20.0), Layers.WORLD))
	if not hit.is_empty():
		h.global_position = hit.position
	await get_tree().physics_frame
	var from := h.global_position
	var away: Vector3 = -h.global_basis.z
	var chest := h.global_position + Vector3.UP * 1.7
	var wall := sp.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + away * 3.0, Layers.WORLD | Layers.PROPS, [p.get_rid()]))
	print("  horse ride probe: ahead %s" % ("clear" if wall.is_empty() else str((wall.collider as Node).name)))
	p.set("_debug_drive", true)            # the player's own loop hands this wish to the horse
	p.set("_debug_wish", away)
	p.set("_debug_sprint", true)
	await _wait(1.5)
	p.set("_debug_drive", false)
	p.set("_debug_wish", Vector3.ZERO)
	var moved := Vector2(h.global_position.x - from.x, h.global_position.z - from.z).length()
	ok(moved > 2.0, "it carries you forward at a gallop (%.1f m)" % moved)
	ok(p.global_position.distance_to(h.global_position) < 3.0, "you sit the saddle")
	# the jump key leaps the horse (it no longer gets you down); [interact] does
	await _wait(0.8)                       # settle after the gallop
	var y0: float = h.global_position.y
	var peak := y0
	h.call("try_jump")
	var airborne := false
	for i in 90:
		await get_tree().physics_frame
		peak = maxf(peak, h.global_position.y)
		airborne = airborne or bool(h.get("_air"))
	ok(airborne and peak - y0 > 0.3, "the horse leaps (%.2f m up)" % (peak - y0))
	ok(not bool(h.get("_air")) and absf(h.global_position.y - y0) < 0.6, "and lands again, softly")
	ok(p.riding == h, "the jump did not get you down")
	await _wait(0.5)                       # the landing cooldown
	h.call("try_jump")
	var iev := InputEventAction.new()
	iev.action = "interact"
	iev.pressed = true
	p.call("_unhandled_input", iev)
	ok(p.riding == null, "and [interact] gets you down")
	# the call
	p.teleport(p.global_position + Vector3(20.0, 0.0, 0.0))
	await _wait(0.3)
	var ev := InputEventAction.new()
	ev.action = "mount"
	ev.pressed = true
	Input.parse_input_event(ev)
	for _i in 40:                              # r39: the horse runs to the whistle along the ground (no teleport under 300 m)
		await _wait(0.25)
		if h.global_position.distance_to(p.global_position) < 6.0:
			break
	ok(h.global_position.distance_to(p.global_position) < 6.0, "[H] calls your horse to you (%.1f m)" % h.global_position.distance_to(p.global_position))


func _reach() -> void:
	print("-- the night progresses")
	ok(ReachState.act() == 1, "act 1 to begin with")
	Travel.bosses_slain["thornwarden"] = true
	Travel.bosses_slain["bone_abbot"] = true
	ok(ReachState.act() == 2 and ReachState.pressure() > 1.0, "act 2 once both keepers fall; the dark presses harder")
	Book.start("bell_holds")
	Book.choose("bell_holds", "rung")
	ok(ReachState.quiet("holds"), "a rung bell quiets its country")
	var at := Vector3(-138.0, 3.0, 20.0)
	ok(ReachState.respawn_mult(at) >= 3.0, "its camps come back slower (x%.1f)" % ReachState.respawn_mult(at))
	var rs := main.get_node_or_null("ReachState")
	if rs:
		rs.call("refresh")
		ok((rs.call("info") as Dictionary).lit.has("bell_holds"), "the bell stands lit where it hung")
	for id: String in ["holds_turf", "keeper_wards", "keeper_heart"]:
		Book.start(id)
		Book.complete(id)
	ok(ReachState.tier("rooted") >= 1, "the Rooted call you friend (standing %d)" % ReachState.standing("rooted"))
	# one source of truth: every bell, and every region with a bell, belongs to exactly one faction
	for b: String in Chains.BELLS:
		var owners := 0
		for f: String in ReachState.FACTIONS:
			if (ReachState.FACTIONS[f].bells as Array).has(b):
				owners += 1
		ok(owners == 1, "%s belongs to exactly one faction (%d)" % [b, owners])
		var region := String(ReachState.BELL_REGION.get(b, ""))
		var rowners := 0
		for f: String in ReachState.FACTION_REGIONS:
			if (ReachState.FACTION_REGIONS[f] as Array).has(region):
				rowners += 1
		ok(region != "" and rowners == 1 and ReachState.faction_of_region(region) == ReachState.faction_of_bell(b),
			"%s: its region %s is held by the same faction (%d)" % [b, region, rowners])


func _bounties() -> void:
	print("-- the keep's bounties")
	ok(Chains.audit().is_empty(), "the quest audit is clean %s" % [Chains.audit()])
	for id: String in ["keg_tab", "rare_head", "keeper_again"]:
		ok(String(Chains.QUESTS[id].get("repeat", "")) == "daily" and Chains.giver(id) == "keep", "%s: the keep's, every night" % id)
	ok(InputMap.has_action("mount"), "the call has its key")
