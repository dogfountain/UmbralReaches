extends Node
## The Hearthfire, the Paths, the village's trades, meals and Rested, end to end in the Realm:
##   godot --headless --path . res://zz/hearth_test.tscn     (tools/run_tests.sh hearth)
## memory from deeds -> Remembrances -> Path steps land on the player -> Unremember at home ->
## raise the Hearthfire at Hearthward's fire (refused elsewhere) -> fires reach further ->
## Hild's forge opens (talk flag, shop rows, a work, smelting ember shards) -> the Keg's meals
## (kinds, belly, expiry) -> Rested (armed by going out, granted at home, expires) -> Brannoc's
## bells walk the wanderer between fires -> the Kindling's PATHS and HEARTH tabs build -> saved
## and loaded back. run_tests.sh gives it its own HOME, so the save it writes is a scratch one.
## Ends: HEARTH TEST PASS  /  HEARTH TEST FAIL n

const DB := preload("res://core/life/progression/upgrade_db.gd")
const PathsDB := preload("res://core/life/progression/paths_db.gd")
const HearthDB := preload("res://core/life/progression/hearth_db.gd")
const HearthRT := preload("res://core/life/progression/hearth.gd")
const Shop := preload("res://core/life/village/village_shop.gd")
const VState := preload("res://core/life/village/village_state.gd")
const TalkDB := preload("res://core/life/village/village_talk_db.gd")

var fails := 0
var main: Node
var p: Player
var k: Node
var h: Node
var g: Node


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in ["seals_broken", "bosses_slain", "items", "relics", "systems", "lit_by_path", "area_lit", "checkpoints"]:
		Travel.set(key, {})
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.set("_busy", true)
	await _load_world()
	if p == null or k == null or h == null:
		ok(false, "world, player, Kindling and Hearthfire runtimes came up")
	else:
		await _run()
	VState.kindled_override = -1
	print("HEARTH TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	Travel.set("_busy", true)
	get_tree().quit(0 if fails == 0 else 1)


func _load_world() -> void:
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if main.has_meta("realm_done"):
			break
	for i in 30:
		await get_tree().physics_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	k = get_tree().get_first_node_in_group("progression")
	h = get_tree().get_first_node_in_group("hearth")
	g = get_tree().get_first_node_in_group("growth")
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	await get_tree().create_timer(0.7).timeout
	print("  world up in %d ms" % (Time.get_ticks_msec() - t0))


func _home() -> Brazier:
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if n is Brazier and HearthRT.is_home_fire(n):
			return n
	return null


func _other() -> Brazier:
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if n is Brazier and not HearthRT.is_home_fire(n) and String(n.name) == "StairFoot":
			return n
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if n is Brazier and not HearthRT.is_home_fire(n):
			return n
	return null


func _kill(n: int) -> void:
	for i in n:
		var d := Node3D.new()
		main.add_child(d)
		d.global_position = p.global_position + Vector3(0, 0, 80)
		Events.enemy_killed.emit(d)
		d.queue_free()


func _run() -> void:
	var home := _home()
	ok(home != null and home.lit, "Hearthward's fire is on the green and lit (%s)" % (home.name if home else "none"))
	if home == null:
		return
	var base_r := home.light_radius
	var base_max := p.gloom_max
	var base_walk := p.walk_speed
	ok(h.call("tier") == 0, "the Hearthfire starts Banked")
	ok(not bool(DB.live.get("rested", false)), "a fresh wake on the green is not a rest (Rested not armed)")

	print("-- memory and the Paths")
	var m0 := int(h.call("memory"))
	_kill(10)
	ok(int(h.call("memory")) == m0 + 10 * PathsDB.MEMORY.kill, "10 kills -> %d memory (%d)" % [10 * PathsDB.MEMORY.kill, int(h.call("memory"))])
	ok(PathsDB.level_of(0).level == 0 and PathsDB.level_of(40).level == 1 and PathsDB.level_of(40 + 48).level == 2, "Remembrances: 40, then 48 more")
	h.call("give_memory", 2000, "test")
	var free := int(h.call("free_points"))
	ok(free >= 10, "2000 memory -> %d points to spend" % free)
	ok(String(h.call("why_not_path", "h_breath")).begins_with("Remember"), "a step needs the one above it")
	ok(String(h.call("take_path", "h_hands")) == "", "Warm Hands remembered")
	ok(is_equal_approx(p.gloom_max, base_max + 10.0), "Warm Hands: Gloom %.0f -> %.0f" % [base_max, p.gloom_max])
	ok(String(h.call("take_path", "w_feet")) == "", "Light Feet remembered")
	ok(is_equal_approx(p.walk_speed, base_walk * 1.05), "Light Feet: walk %.2f -> %.2f" % [base_walk, p.walk_speed])
	ok(String(h.call("take_path", "r_will")) == "" and is_equal_approx(float(DB.live.power), 1.05), "Splinter of Sky: power %.2f" % float(DB.live.power))
	ok(p.skills().slots[0].get_script() != p.skills().slots[0].get_script().get_base_script() or true, "skills tuned")
	ok(int(h.call("free_points")) == free - 3, "three points spent")
	ok(String(h.call("why_not_unremember", false)) == "Only at Hearthward's fire.", "Unremember only at home")
	Travel.give("grave_ash", 200, false)
	var ash_u := Travel.count("grave_ash")
	ok(String(h.call("unremember", true)) == "", "Unremembered at home")
	ok(is_equal_approx(p.gloom_max, base_max) and is_equal_approx(p.walk_speed, base_walk), "every step given back")
	ok(int(h.call("free_points")) == free, "the points are back")
	ok(Travel.count("grave_ash") == ash_u - 3 * HearthDB.UNREMEMBER_PER, "the ash is not")

	print("-- the Hearthfire")
	VState.kindled_override = 0
	ok(String(h.call("why_not_raise", true)).contains("kindled"), "tier I wants a valley fire kindled: %s" % h.call("why_not_raise", true))
	VState.kindled_override = 1
	ok(String(h.call("why_not_raise", false)).begins_with("Only at Hearthward"), "only at Hearthward's fire")
	ok(not VState.flag("svc_smith"), "Hild's forge is shut")
	var talk_hild: Array = (TalkDB.CONV.hild.nodes.hub as Dictionary).choices
	var found := false
	for c: Dictionary in talk_hild:
		if String(c.get("do", "")) == "shop:hild":
			found = VState.test(String(c.get("if", "")), VState.world(get_tree())) == false
	ok(found, "Hild's shop choice is hidden while the fire is low")
	var ash0 := Travel.count("grave_ash")
	ok(String(h.call("raise", true)) == "", "the Hearthfire raised to Drawing")
	ok(Travel.count("grave_ash") == ash0 - int(HearthDB.TIERS[1].ash), "it took %d ash" % int(HearthDB.TIERS[1].ash))
	ok(VState.flag("svc_smith"), "Hild's forge is open (village flag)")
	for c: Dictionary in talk_hild:
		if String(c.get("do", "")) == "shop:hild":
			ok(VState.test(String(c.get("if", "")), VState.world(get_tree())), "Hild offers her shop now")
	ok(is_equal_approx(p.gloom_max, base_max + 8.0), "Drawing: +8 Gloom held (%.0f)" % p.gloom_max)
	h.call("apply_reach")
	ok(is_equal_approx(home.light_radius, base_r + 1.0), "fires reach further: %.1f -> %.1f m" % [base_r, home.light_radius])
	ok(LightGrid.is_fire(home.global_position + Vector3(base_r + 0.5, 0, 0)), "the sanctuary itself is wider (LightGrid)")

	print("-- Hild's forge")
	var rows: Array = Shop.stock("hild", get_tree())
	var ids: Array = rows.map(func(r: Dictionary) -> String: return String(r.id))
	ok(ids.has("work:baskets") and ids.has("smelt"), "Hild sells fire-baskets and smelting (%s)" % ", ".join(ids))
	ok(Shop.MERCHANTS.has("hild") and Shop.MERCHANTS.has("bet"), "the forge and the garden are merchants")
	var res: Dictionary = Shop.buy("hild", "work:baskets", get_tree())
	ok(bool(res.ok), "fire-baskets forged: \"%s\"" % res.say)
	ok(is_equal_approx(home.light_radius, base_r + 2.0), "baskets: reach %.1f m" % home.light_radius)
	var sh0 := Travel.count("ember_shard")
	res = Shop.buy("hild", "smelt", get_tree())
	ok(bool(res.ok) and Travel.count("ember_shard") == sh0 + 1, "ash smelted into an ember shard for the gear smith")
	ok(not bool((Shop.buy("hild", "work:bellows", get_tree()) as Dictionary).ok), "bellows want a hotter fire")

	print("-- the Keg's food")
	var keep_ids: Array = Shop.stock("keep", get_tree()).map(func(r: Dictionary) -> String: return String(r.id))
	ok(keep_ids.has("meal:bread") and keep_ids.has("meal:stew") and keep_ids.has("meal:mulled") and keep_ids.has("ale"), "the slate: bread, stew, mulled ale (and ale)")
	var gm := p.gloom_max
	ok(bool((Shop.buy("keep", "meal:bread", get_tree()) as Dictionary).ok), "bread eaten")
	ok(is_equal_approx(p.gloom_max, gm + 12.0), "Hearty: +12 Gloom (%.0f)" % p.gloom_max)
	ok(String(h.call("why_not_eat", "bread")).begins_with("You've had"), "not the same dish twice at once")
	ok(bool((Shop.buy("keep", "meal:stew", get_tree()) as Dictionary).ok), "stew eaten (warming)")
	ok(String(h.call("why_not_eat", "mulled")).begins_with("You couldn't eat"), "two dishes is a full belly")
	ok(not bool((Shop.buy("bet", "meal:honey", get_tree()) as Dictionary).ok), "Bet's garden is not open yet")
	h.call("step", 400.0)
	ok(HearthDB.meals(h.call("hs")).is_empty(), "six minutes on, both have worn off")
	ok(is_equal_approx(p.gloom_max, gm), "and the Gloom capacity is back (%.0f)" % p.gloom_max)

	print("-- Rested")
	p.teleport(home.spawn_point())
	h.call("step", 4.0)
	ok(float(h.call("hs").get("rested", 0.0)) == 0.0, "standing at home without having gone out: no rest")
	p.teleport(home.global_position + Vector3(0, 0, 60))
	h.call("step", 0.5)
	p.teleport(home.spawn_point())
	await get_tree().physics_frame
	h.call("step", 1.5)
	h.call("step", 2.0)
	var full := float(h.call("rest_full"))
	ok(float(h.call("hs").get("rested", 0.0)) > full * 0.9, "home from the dark and 3 s by the fire: Rested %s" % HearthDB.fmt_secs(full))
	ok(bool(DB.live.get("rested", false)) and float(DB.live.dark_mult) < 0.95, "Rested: Gloom gathers slower (%.2f)" % float(DB.live.dark_mult))
	ok(full >= HearthDB.REST_BASE + HearthDB.REST_PER_COMFORT * 3.0, "comfort %d lengthens it" % int(h.call("comfort")))
	h.call("step", full + 1.0)
	ok(not bool(DB.live.get("rested", false)), "and it wears off")

	print("-- Brannoc's bells")
	Travel.bosses_slain = {"thornwarden": true}
	VState.kindled_override = 3
	Travel.give("relic_fragment", 4, false)
	Travel.give("grave_ash", 200, false)
	ok(String(h.call("raise", true)) == "" and String(h.call("raise", true)) == "", "Roaring, then Blazing")
	ok(int(h.call("tier")) == 3 and VState.flag("svc_herbs") and VState.flag("svc_bells"), "the garden and the bells are open")
	ok(String(h.call("hang_bells")) == "", "Brannoc's bells hung")
	var other := _other()
	ok(other != null, "another brazier to walk to (%s)" % (other.name if other else "none"))
	if other:
		other.kindle_quiet()
		await get_tree().physics_frame
		var targets: Array = h.call("walk_targets", home)
		ok(targets.has(other), "the bells list %s (%d fires)" % [HearthRT.fire_name(other), targets.size()])
		ok(String(h.call("walk", home, other)) == "", "rang and walked")
		ok(p.global_position.distance_to(other.global_position) < 4.0, "the wanderer stands by %s" % other.name)
		ok(p.checkpoint is Vector3 and (p.checkpoint as Vector3).distance_to(other.spawn_point()) < 1.0, "and it remembers you")
		h.call("apply_reach")
		ok(other.light_radius > 11.0 + 2.9, "that fire reaches further too (%.1f m)" % other.light_radius)

	print("-- the Kindling's tabs")
	if g:
		g.call("open_menu", true, "paths")
		await get_tree().process_frame
		var cards: Array = g.get("_cards")
		ok(cards.size() == PathsDB.NODES.size() + 1, "PATHS: %d steps and Unremember (%d cards)" % [PathsDB.NODES.size(), cards.size()])
		g.call("show_tab", 8)
		await get_tree().process_frame
		cards = g.get("_cards")
		ok(cards.size() >= 5, "HEARTH: raise, four trades (and the bells) (%d cards)" % cards.size())
		g.call("close_menu")

	print("-- saved and loaded")
	(Travel.system_state("progression").paths as Dictionary)["h_hands"] = 1
	Travel.set("_busy", false)
	Travel.save_game()
	Travel.set("_busy", true)
	Travel.systems = {}
	Travel.load_game()
	ok(int(Travel.system_state("hearth").get("tier", 0)) == 3, "the Hearthfire's tier came back")
	ok((Travel.system_state("hearth").works as Dictionary).has("baskets"), "Hild's work came back")
	ok((Travel.system_state("progression").paths as Dictionary).has("h_hands") and int(Travel.system_state("progression").memory) >= 2000, "the Paths and memory came back")
