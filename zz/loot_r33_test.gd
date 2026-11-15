extends Node
## r33 loot, items and progression (WoW-inspired) end to end:
##   godot --headless --path . res://zz/loot_r33_test.tscn
## data: item quality for gear and satchel items, item level, named pieces, flavour, tooltips
## (quality-coloured name, item level, set pieces x/y, set bonuses grey until worn, gold italic
## flavour, green / red comparison) -> the level: XP info, rested XP doubles kills and caps, old
## progression state reads -> vendors: sell, refuse what is worn, buy back -> gathering trades
## -> the world: the XP signals (kill by foe, level-up, discovery once, rest fills the pool), a
## great one's hoard bag (named piece off its table) opened in the loot window (take one, take all),
## a rare's bag by meta and by call (named piece only the first time), a chest's bag, gathering
## nodes laid as map markers and gathered, the shop's SELL and BUY BACK tabs, tooltips in the gear
## panel and the satchel.
## Never writes a save (Travel._busy). Ends: LOOT R33 TEST PASS  /  LOOT R33 TEST FAIL n

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const Vendor := preload("res://core/items/vendor.gd")
const Tip := preload("res://ui/item_tooltip.gd")
const LevelDB := preload("res://core/life/progression/level.gd")
const PathsDB := preload("res://core/life/progression/paths_db.gd")
const HearthDB := preload("res://core/life/progression/hearth_db.gd")
const ShopUI := preload("res://ui/shop.gd")

var fails := 0
var _travel := {}
var rng := RandomNumberGenerator.new()


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 33
	Travel.set("_busy", true)
	for key: String in ["seals_broken", "bosses_slain", "items", "relics", "systems", "story", "lit_by_path", "area_lit", "checkpoints"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
		Travel.set(key, {})
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	_data()
	_tooltips()
	_level()
	_vendor()
	_trades()
	await _world()
	for key: String in _travel:
		Travel.set(key, _travel[key])
	print("LOOT R33 TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	Travel.set("_busy", true)
	get_tree().quit(0 if fails == 0 else 1)


func _data() -> void:
	print("-- quality, item level, named pieces")
	ok(LootDB.item_quality("grave_ash") == 0 and LootDB.item_quality("ember_shard") == 1, "ash is Worn, shards Kindled")
	ok(LootDB.item_quality("charm_candle") == 2 and LootDB.item_quality("hobbs_knuckles") == 3 and LootDB.item_quality("thorn_heart") == 4, "charm 2, bounty 3, relic 4")
	ok(LootDB.quality_color(3) == GearDB.rarity_color(3), "one palette for gear and items")
	var lo := GearDB.make(rng, {"rarity": 0, "slot": "focus"})
	var hi := GearDB.make(rng, {"rarity": 3, "slot": "focus"})
	ok(GearDB.item_level(hi) > GearDB.item_level(lo), "item level climbs with quality (%d > %d)" % [GearDB.item_level(hi), GearDB.item_level(lo)])
	hi["level"] = 2
	ok(GearDB.item_level(hi) == GearDB.item_level(GearDB.make(rng, {"rarity": 3, "slot": "focus"})) + 6, "and with each raise")
	for id: String in GearDB.NAMED:
		var p := GearDB.make(rng, {"named": id})
		var nd: Dictionary = GearDB.NAMED[id]
		var good: bool = String(p.name) == String(nd.name) and String(p.slot) == String(nd.slot) and int(p.rarity) == int(nd.rarity) and (p.aff as Array).size() == (nd.aff as Array).size()
		if not good:
			ok(false, "named %s: %s" % [id, p])
	ok(true, "%d named pieces make with their name, slot, quality and lines" % GearDB.NAMED.size())
	for t: String in LootDB.BOSS_TABLE:
		for nm: String in LootDB.BOSS_TABLE[t]:
			ok(GearDB.NAMED.has(nm), "boss %s table: %s" % [t, nm])
	for nm: String in LootDB.RARE_TABLE:
		if not GearDB.NAMED.has(nm):
			ok(false, "rare table: %s" % nm)
	for slot: String in GearDB.SLOTS:
		for r in 5:
			if GearDB.flavour(GearDB.make(rng, {"rarity": r, "slot": slot})) == "":
				ok(false, "flavour for %s %d" % [slot, r])
	ok(GearDB.flavour({"slot": "girdle"}) != "", "an old piece (no rarity, no named) still has flavour")
	ok(GearDB.item_level({"slot": "focus", "rarity": 1}) > 0, "and an item level")


func _tooltips() -> void:
	print("-- tooltips")
	Travel.systems.erase("gear")
	var st := GearStats.state()
	var worn := GearDB.make(rng, {"rarity": 1, "slot": "lantern", "set": "kindler", "uid": 1})
	(st.bag as Array).append(worn)
	st.worn["lantern"] = 1
	var cand := GearDB.make(rng, {"rarity": 3, "slot": "lantern", "set": "ferryman", "uid": 2})
	(st.bag as Array).append(cand)
	var bb := Tip.piece(cand, worn, st)
	ok(bb.contains(LootDB.quality_color(3).to_html(false)) and bb.contains(String(cand.name)), "the name in its quality colour")
	ok(bb.contains("Item Level %d" % GearDB.item_level(cand)), "the item level")
	ok(bb.contains("Ferryman's Weeds (1/4)"), "set pieces owned x/4")
	ok(bb.contains(Tip.GREY.to_html(false) + "]Ferryman's Hook-Ring"), "a missing set piece is grey")
	ok(bb.contains(Tip.GREY.to_html(false) + "](2) Set:"), "a set bonus not yet worn is grey")
	ok(bb.contains("[i]") and bb.contains(Tip.GOLD.to_html(false)), "gold italic flavour")
	ok(bb.contains("Instead of %s" % String(worn.name)), "compared with what is worn")
	ok(bb.contains(Tip.GOOD.to_html(false)) and bb.contains("item level"), "a better piece shows green item level")
	var diffs := GearStats.compare(worn, cand, st)
	var any_red := false
	for d: Array in diffs:
		any_red = any_red or not bool(d[2])
	ok(any_red, "a worse piece shows red lines (%s)" % str(diffs))
	var worn_tip := Tip.piece(worn, worn, st)
	ok(worn_tip.contains("Worn") and not worn_tip.contains("Instead of"), "the worn piece says so and compares with nothing")
	var it := Tip.item("relic_fragment", 3)
	ok(it.contains("Relic Fragment") and it.contains("Hallowed") and it.contains("[i]"), "a satchel item: quality, name, flavour")
	Travel.systems.erase("gear")


func _level() -> void:
	print("-- the level")
	var old := {"memory": 100, "paths": {}}                 # an old save: no rested_xp, no seen
	var info := LevelDB.info(old, 0)
	ok(int(info.level) == 1 and int(info.into) == 100 - PathsDB.need(0) and int(info.need) == PathsDB.need(1), "an old save's memory reads as level 1, %d / %d" % [info.into, info.need])
	ok(int(info.rested) == 0 and float(info.frac) > 0.0 and float(info.frac) < 1.0, "no rested, a part-filled bar")
	ok(int(info.free_points) == 1, "one Path point (a level)")
	var rs := LevelDB.with_rested({"rested_xp": 10}, 3, "kill")
	ok(int(rs[0]) == 6 and int(rs[1]) == 3, "rested: a kill gives double")
	rs = LevelDB.with_rested({"rested_xp": 10}, 60, "quest")
	ok(int(rs[0]) == 60 and int(rs[1]) == 0, "rested does not touch quests")
	rs = LevelDB.with_rested({"rested_xp": 2}, 15, "elite")
	ok(int(rs[0]) == 17 and int(rs[1]) == 2, "and only as far as the pool lasts")
	var pool := LevelDB.rest_pool({"memory": 0})
	ok(pool == roundi(PathsDB.need(0) * LevelDB.REST_FILL), "a rest fills half a level (%d)" % pool)
	ok(LevelDB.rest_pool({"memory": 0, "rested_xp": 999}) == roundi(PathsDB.need(0) * LevelDB.REST_CAP), "capped at one and a half")
	var cap := LevelDB.info({"memory": 999999}, 0)
	ok(bool(cap.capped) and float(cap.frac) == 1.0 and int(cap.level) == PathsDB.MAX_LEVEL, "max level: a full bar")


func _vendor() -> void:
	print("-- vendors")
	Travel.systems.erase("gear")
	Travel.systems.erase("vendor")
	Travel.items = {"grave_ash": 5, "ember_shard": 3}
	var a := GearDB.make(rng, {"rarity": 2, "slot": "focus"})
	GearRuntime.store(a)                                     # worn (empty slot)
	var b := GearDB.make(rng, {"rarity": 3, "slot": "focus"})
	GearRuntime.store(b)
	var rows := Vendor.sell_rows()
	var ids := rows.map(func(r: Dictionary) -> String: return String(r.id))
	ok(not ids.has("gear:%d" % int(a.uid)) and ids.has("gear:%d" % int(b.uid)), "worn gear is not offered, carried gear is")
	ok(ids.has("item:ember_shard") and not ids.has("item:grave_ash"), "shards sell, ash is the coin")
	ok(not bool(Vendor.sell("gear:%d" % int(a.uid)).ok), "selling worn gear is refused")
	var price := LootDB.sell_price_piece(b)
	var r := Vendor.sell("gear:%d" % int(b.uid))
	ok(bool(r.ok) and Travel.count("grave_ash") == 5 + price and GearStats.find(GearStats.state(), int(b.uid)).is_empty(), "sold for %d ash" % price)
	Vendor.sell("item:ember_shard")
	ok(Travel.count("ember_shard") == 2 and Travel.count("grave_ash") == 6 + price, "a shard sold for 1")
	var bb := Vendor.buyback_rows()
	ok(bb.size() == 2 and String(bb[1].name) == String(b.name), "the buyback shelf, newest first")
	var back := Vendor.buy_back(String(bb[1].id))
	ok(bool(back.ok) and not GearStats.find(GearStats.state(), int(b.uid)).is_empty() and Travel.count("grave_ash") == 6, "bought back at the price paid")
	Travel.items["grave_ash"] = 0
	ok(not bool(Vendor.buy_back("bb:0").ok), "too poor to buy back")
	Travel.systems.erase("vendor")
	ok((Vendor.state().buyback as Array).is_empty(), "an old save has an empty shelf")


func _trades() -> void:
	print("-- gathering trades")
	Travel.items = {"grave_iron": 1}
	ok(HearthDB.mats_why({"grave_iron": 2}).contains("grave-iron"), "short of grave-iron: \"%s\"" % HearthDB.mats_why({"grave_iron": 2}))
	Travel.items["grave_iron"] = 2
	ok(HearthDB.mats_why({"grave_iron": 2}) == "", "enough grave-iron")
	ok(not HearthDB.trade("smelt_iron").is_empty() and not HearthDB.meal("posset").is_empty() and not HearthDB.work("fire_dogs").is_empty(), "the trades, a dish and a work name gathered goods")
	ok(ItemDB.DEFS.has("ash_bloom") and ItemDB.DEFS.has("grave_iron") and ItemDB.ORDER.has("ash_bloom"), "ash-bloom and grave-iron are items")


func _world() -> void:
	print("-- the world")
	Travel.items = {}
	Travel.systems.erase("gear")
	var main: Node = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if main.has_meta("realm_done"):
			break
	for i in 30:
		await get_tree().physics_frame
	for en in get_tree().get_nodes_in_group(Groups.ENEMY):
		(en as Node).queue_free()
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var h := get_tree().get_first_node_in_group("hearth")
	var rt := get_tree().get_first_node_in_group("gear")
	var lw := get_tree().get_first_node_in_group("loot_window")
	ok(p != null and h != null and rt != null and lw != null, "player, hearth, gear runtime and loot window are in the Realm")
	if p == null or h == null or rt == null or lw == null:
		main.queue_free()
		return
	# --- XP signals
	var got := []
	var ups := []
	h.connect("xp_changed", func(info: Dictionary) -> void: got.append(info))
	h.connect("leveled_up", func(lv: int, pts: int) -> void: ups.append([lv, pts]))
	var ps := Travel.system_state("progression")
	ps["rested_xp"] = 0
	var m0 := int(ps.memory)
	var e := Node3D.new()
	main.add_child(e)
	e.set_meta(&"elite_id", "test_elite")
	e.global_position = p.global_position + Vector3(0, 0, 60)
	Events.enemy_killed.emit(e)
	ok(int(ps.memory) == m0 + LevelDB.XP.elite, "an elite gives %d XP (%d)" % [LevelDB.XP.elite, int(ps.memory) - m0])
	ok(not got.is_empty() and (got.back() as Dictionary).has("frac") and int(got.back().last_gain) == LevelDB.XP.elite, "xp_changed carries the bar's data")
	e.queue_free()
	# rested
	ps["rested_xp"] = 0
	h.set("armed", true)
	h.call("rest_here")
	var pool := int(ps.get("rested_xp", 0))
	ok(pool > 0, "a rest at home fills the rested pool (%d)" % pool)
	m0 = int(ps.memory)
	var plain := Node3D.new()
	main.add_child(plain)
	plain.global_position = p.global_position + Vector3(0, 0, 70)
	Events.enemy_killed.emit(plain)
	plain.queue_free()
	ok(int(ps.memory) == m0 + 2 * LevelDB.XP.kill and int(ps.rested_xp) == pool - LevelDB.XP.kill, "rested: a kill gives double, the pool drains")
	var info: Dictionary = h.call("xp_info")
	ok(float(info.rested_frac) >= float(info.frac), "the rested marker sits ahead of the bar")
	# level up
	var lv0 := int(info.level)
	h.call("give_memory", PathsDB.need(lv0) + 1, "test")
	ok(not ups.is_empty() and int(ups.back()[0]) > lv0 and int(ups.back()[1]) >= 1, "leveled_up fires with points to spend (%s)" % str(ups))
	# discovery
	m0 = int(ps.memory)
	Events.zone_entered.emit("A TEST PLACE", "nowhere")
	Events.zone_entered.emit("A TEST PLACE", "nowhere")
	ok(int(ps.memory) == m0 + LevelDB.XP.discover, "discovery XP once per place")
	# --- a great one's hoard
	print("-- loot bags and the loot window")
	for b in get_tree().get_nodes_in_group("loot_bag"):
		b.call("take_all")                                   # the elite's remains
	for d in get_tree().get_nodes_in_group("gear_drop"):
		d.queue_free()
	await get_tree().process_frame
	Travel.items = {}
	var n_bag := (GearStats.state().bag as Array).size()
	Events.boss_slain.emit("thornwarden")
	await get_tree().process_frame
	var bags := get_tree().get_nodes_in_group("loot_bag")
	ok(bags.size() == 1, "the Thornwarden leaves a hoard bag")
	if bags.size() == 1:
		var bag := bags[0] as Node3D
		var es: Array = bag.get("entries")
		var named := false
		for en: Dictionary in es:
			if String(en.kind) == "gear" and (LootDB.BOSS_TABLE.thornwarden as Array).has(String(en.piece.get("named", ""))):
				named = true
		ok(named and es.size() >= 3, "it holds a named piece off its table, a set piece and shards (%d entries)" % es.size())
		ok(bag.call("can_interact") and String(bag.call("interact_text")).contains("Loot"), "[E] Loot")
		bag.call("interact", p)
		await get_tree().process_frame
		ok(bool(lw.call("is_open")), "the loot window opens on it")
		var rt_tip := lw.get("_tip") as PanelContainer
		var tip_text := ""
		if rt_tip != null:
			for n in rt_tip.find_children("*", "RichTextLabel", true, false):     # the item card (ui/item_card.gd) lays its text out in blocks
				tip_text += (n as RichTextLabel).get_parsed_text() + "\n"
		ok(rt_tip != null and rt_tip.visible and tip_text.contains("Item Level"), "with the first thing's tooltip")
		var before := es.size()
		lw.call("take", 0)
		ok((bag.get("entries") as Array).size() == before - 1 and (GearStats.state().bag as Array).size() == n_bag + 1, "take one")
		lw.call("take_all")
		await get_tree().process_frame
		ok(not is_instance_valid(bag) or bag.is_queued_for_deletion(), "take all empties the bag and it goes")
		ok(not bool(lw.call("is_open")), "and the window closes")
		ok(Travel.count("ember_shard") >= LootDB.BOSS_SHARDS, "the shards are in the satchel")
	Events.boss_slain.emit("thornwarden")
	await get_tree().process_frame
	ok(get_tree().get_nodes_in_group("loot_bag").is_empty(), "a great one's hoard comes once")
	# --- rares
	var first: Array = rt.call("drop_rare", "test_rare", p.global_position + Vector3(3, 0, 0))
	var second: Array = rt.call("drop_rare", "test_rare", p.global_position + Vector3(-3, 0, 0))
	var f_named := first.any(func(x: Dictionary) -> bool: return String(x.kind) == "gear" and String(x.piece.get("named", "")) != "")
	var s_named := second.any(func(x: Dictionary) -> bool: return String(x.kind) == "gear" and String(x.piece.get("named", "")) != "")
	ok(f_named and not s_named, "a rare's first fall has a named piece, the next does not")
	ok(get_tree().get_nodes_in_group("loot_bag").size() == 2, "both lie as bags")
	var re := Node3D.new()
	main.add_child(re)
	re.set_meta(&"rare_id", "meta_rare")
	re.set_meta(&"rare_name", "the Meta Rare")
	re.global_position = p.global_position + Vector3(0, 0, -4)
	m0 = int(Travel.system_state("progression").memory)
	Travel.system_state("progression")["rested_xp"] = 0
	Events.enemy_killed.emit(re)
	for _i in 10:                         # under a loaded machine the XP lands a frame or two after the bag
		await get_tree().process_frame
		if int(Travel.system_state("progression").memory) == m0 + LevelDB.XP.rare:
			break
	ok(get_tree().get_nodes_in_group("loot_bag").size() == 3, "a foe carrying meta rare_id leaves a rare's bag by itself")
	ok(int(Travel.system_state("progression").memory) == m0 + LevelDB.XP.rare, "and gives rare XP")
	var titled := false
	for b in get_tree().get_nodes_in_group("loot_bag"):
		titled = titled or String(b.get("title")) == "the Meta Rare"
	ok(titled, "titled with its name")
	re.queue_free()
	for b in get_tree().get_nodes_in_group("loot_bag"):
		b.call("take_all")
	await get_tree().process_frame
	# --- a chest's piece comes as a bag, opened at once beside it
	var cp: Dictionary = rt.call("roll_chest", "iron", "test_chest")
	ok(not cp.is_empty() and int(cp.rarity) >= 1, "an iron chest always holds a piece")
	rt.call("drop_at", cp, p.global_position + Vector3(1.5, 0, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	var cb := get_tree().get_nodes_in_group("loot_bag")
	ok(cb.size() == 1 and (cb[0].get("entries") as Array).size() >= 2, "the chest's bag: its piece and the chest's extras")
	ok(bool(lw.call("is_open")), "standing beside it, the loot window opens at once")
	lw.call("take_all")
	await get_tree().process_frame
	ok(not cp.has("_chest") or (GearStats.state().bag as Array).all(func(x: Dictionary) -> bool: return not x.has("_chest")), "no marker rides into the bag")
	# --- gathering
	print("-- gathering")
	await get_tree().create_timer(0.3).timeout
	var nodes := get_tree().get_nodes_in_group("gather_node")
	var kinds := {}
	for n in nodes:
		kinds[String(n.get("kind"))] = int(kinds.get(String(n.get("kind")), 0)) + 1
	ok(int(kinds.get("ash_bloom", 0)) >= 8 and int(kinds.get("grave_iron", 0)) >= 6, "gathering nodes laid: %s" % str(kinds))
	var markers := get_tree().get_nodes_in_group("map_marker").filter(func(m: Node) -> bool: return String(m.get_meta("map_kind", "")) == "gather")
	ok(markers.size() == nodes.size(), "each is a gather map marker (%d)" % markers.size())
	if not nodes.is_empty():
		var gn: Node = nodes[0]
		var gk := String(gn.get("kind"))
		var c0 := Travel.count(gk)
		var res: Dictionary = gn.call("gather")
		ok(Travel.count(gk) > c0 and int(res.get(gk, 0)) >= 1, "gathered %s" % str(res))
		ok(not gn.call("can_interact") and not gn.is_in_group("map_marker"), "spent: off the map until it grows back")
		var far := true
		for n in nodes:
			var q := Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)
			far = far and q.distance_to(Vector2(0, 33)) > 30.0
		ok(far, "none in Hearthward")
	# --- the shop's sell and buy back tabs
	print("-- the shop")
	Travel.items["grave_ash"] = 10
	var spare := GearDB.make(rng, {"rarity": 2, "slot": "girdle"})
	GearRuntime.store(spare)
	var worn_g: Dictionary = GearStats.worn(GearStats.state()).get("girdle", {})
	if int(worn_g.get("uid", -1)) == int(spare.uid):
		GearRuntime.store(GearDB.make(rng, {"rarity": 1, "slot": "girdle"}))
		spare = GearStats.find(GearStats.state(), int((GearStats.state().bag as Array).back().uid))
	var shop: CanvasLayer = ShopUI.new()
	get_tree().root.add_child(shop)
	shop.call("open", "grisel")
	ok(bool(shop.call("is_open")) and int(shop.get("tab")) == 0, "the shop opens on its wares")
	shop.call("set_tab", 1)
	var srows: Array = shop.get("rows")
	var sid := "gear:%d" % int(spare.uid)
	ok(srows.any(func(r: Dictionary) -> bool: return String(r.id) == sid), "SELL lists carried gear")
	var ash0 := Travel.count("grave_ash")
	ok(bool(shop.call("buy", sid)) and Travel.count("grave_ash") > ash0, "sold from the shop")
	var drich := shop.get("_d_rich") as RichTextLabel
	shop.call("set_tab", 2)
	ok((shop.get("rows") as Array).size() >= 1, "BUY BACK lists it")
	ok(drich.visible and drich.text.contains("Item Level"), "with the gear tooltip")
	ok(bool(shop.call("buy", "bb:0")) and not GearStats.find(GearStats.state(), int(spare.uid)).is_empty(), "bought back")
	shop.call("close")
	shop.queue_free()
	# --- tooltips in the gear panel and the satchel
	var panel := get_tree().get_first_node_in_group("gear_panel")
	panel.call("open_menu")
	await get_tree().process_frame
	ok(_card_text(panel.get("_card_a") as Control).contains("Item Level"), "the gear panel shows the tooltip")
	panel.call("close_menu")
	var sat := main.get_node_or_null("Satchel")
	if sat:
		Travel.items["relic_fragment"] = 1
		sat.call("open_menu")
		sat.call("select_id", "relic_fragment")
		ok(_card_text(sat.get("_card") as Control).contains("[i]"), "the satchel shows gold italic flavour")
		sat.call("close_menu")
	ok(not get_tree().paused, "nothing left paused")
	main.queue_free()
	await get_tree().process_frame


## Every text block of an item card (ui/item_card.gd), as bbcode: the cards lay a tooltip out in blocks.
func _card_text(card: Control) -> String:
	var out := ""
	if card != null:
		for n in card.find_children("*", "RichTextLabel", true, false):
			out += (n as RichTextLabel).text + "\n"
	return out
