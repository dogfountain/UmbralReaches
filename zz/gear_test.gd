extends Node
## Gear (core/items/gear_*.gd, ui/gear_panel.gd) end to end:
##   godot --headless --path . res://zz/gear_test.tscn
## data: rarities, affixes, names, sets, legends, costs -> the bag: auto-wear, a full bag salvages
## -> the stats hook: UpgradeDB.mods folds gear in (base, affixes, set 2/4, legends, Lash every 2nd)
## -> raise / reforge / salvage, with their refusals -> drops: elites always, pity on common foes,
## bosses once -> the world: the runtime and panel are in the Realm, worn gear tunes the live skills
## and the Gloom bar, the lantern light takes the glass's rarity, a drop is walked into and taken,
## the panel opens, wears and closes -> saved in [systems] gear and read back.
## The real save is held off (Travel._busy) except one write + read-back; the bytes go back after.
## Ends: GEAR TEST PASS  /  GEAR TEST FAIL n

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
const DB := preload("res://core/life/progression/upgrade_db.gd")
const BoltSkill := preload("res://core/life/progression/skills/bolt.gd")

var fails := 0
var _bak := {}
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
	rng.seed = 7
	_backup()
	_data()
	_bag_and_stats()
	_working()
	_drops()
	await _world()
	_persist()
	_restore()
	print("GEAR TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	Travel.set("_busy", true)
	get_tree().quit(0 if fails == 0 else 1)


func _backup() -> void:
	for suf: String in ["", ".bak"]:
		var path := Travel.SAVE_PATH + suf
		_bak[suf] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	for key: String in ["seals_broken", "bosses_slain", "items", "relics", "systems", "story", "lit_by_path", "area_lit", "checkpoints"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
		Travel.set(key, {})
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.set("_busy", true)


func _restore() -> void:
	for key: String in _travel:
		Travel.set(key, _travel[key])
	for suf: String in _bak:
		var path := Travel.SAVE_PATH + suf
		if _bak[suf] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(_bak[suf])
			f.close()
	print("  save file restored")


func _reset() -> void:
	Travel.systems.erase("gear")
	Travel.items = {}


func _data() -> void:
	print("-- data")
	for r in 5:
		var p := GearDB.make(rng, {"rarity": r, "slot": "focus"})
		ok((p.aff as Array).size() == int(GearDB.RARITY[r][2]), "%s focus rolls %d affixes (%d)" % [GearDB.rarity_name(r), GearDB.RARITY[r][2], (p.aff as Array).size()])
		var ids := {}
		for a: Array in p.aff:
			ids[a[0]] = true
			ok((GearDB.SLOT_AFFIX["focus"] as Array).has(a[0]), "  %s is a focus affix: %s" % [a[0], GearDB.affix_line(p, a)])
		ok(ids.size() == (p.aff as Array).size(), "  no affix twice")
		ok(String(p.name) != "" and GearDB.base_line(p) != "", "  named '%s', base '%s'" % [p.name, GearDB.base_line(p)])
	var s := GearDB.make(rng, {"rarity": 2, "set": "ferryman", "slot": "girdle"})
	ok(String(s.name) == "Ferryman's Tow-Rope", "a set piece takes its set name (%s)" % s.name)
	var lg := GearDB.make(rng, {"legend": "unlit_lamp", "slot": "focus"})
	ok(String(lg.slot) == "lantern" and int(lg.rarity) == 4 and (lg.aff as Array).size() == 2, "a legend forces its slot, Umbral, and one affix fewer")
	for src: String in ["kill", "tough", "elite", "umbral", "boss"]:
		var seen := {}
		for i in 200:
			seen[GearDB.drop_rarity(src, float(i) / 200.0)] = true
		ok(not seen.is_empty(), "%s drops rarities %s" % [src, str(seen.keys())])
	ok(GearDB.drop_rarity("boss", 0.0) >= 2, "a great one never drops less than Hallowed")
	var w := GearDB.make(rng, {"rarity": 0})
	ok(GearDB.reforge_cost(w).is_empty(), "a Worn piece has nothing to reforge")
	w["level"] = GearDB.max_level(w)
	ok(GearDB.upgrade_cost(w).is_empty(), "a piece at its height takes no more")


func _bag_and_stats() -> void:
	print("-- the bag and the stats hook")
	_reset()
	var base := DB.mods({})
	ok(is_equal_approx(float(base.power), 1.0) and int(base.lash_every) == 3, "nothing worn: mods untouched")
	var f := GearDB.make(rng, {"rarity": 1, "slot": "focus"})
	f.aff = [["power", 0.03]]
	var line := GearRuntime.store(f)
	var st := GearStats.state()
	ok(int(f.uid) > 0 and (st.bag as Array).size() == 1, "stored and given a uid (%d)" % int(f.uid))
	ok(int(st.worn.get("focus", -1)) == int(f.uid) and line.contains("You wear it"), "a piece for an empty slot is worn at once: \"%s\"" % line)
	var m := DB.mods({})
	var want := 1.0 + 0.03 * 1.25 + 0.03 * 1.25
	ok(is_equal_approx(float(m.power), want), "spell power folds in: %.4f (want %.4f)" % [m.power, want])
	var f2 := GearDB.make(rng, {"rarity": 3, "slot": "focus"})
	line = GearRuntime.store(f2)
	ok(int(st.worn.focus) == int(f.uid) and not line.contains("You wear it"), "a second focus goes in the bag, not on")
	# a set: two, then four
	for slot: String in ["vestment", "lantern"]:
		GearRuntime.store(GearDB.make(rng, {"rarity": 2, "set": "bell", "slot": slot}))
	m = DB.mods({})
	ok(GearStats.set_counts(st).get("bell", 0) == 2, "two Bellwright's pieces worn")
	ok(float(m.lash_power) >= 1.2 and int(m.lash_every) == 3, "2 worn: the Lash +20%% (%.2f), still every 3rd" % m.lash_power)
	var bf := GearDB.make(rng, {"rarity": 2, "set": "bell", "slot": "focus", "uid": 900})
	GearRuntime.store(bf)
	st.worn["focus"] = 900
	GearRuntime.store(GearDB.make(rng, {"rarity": 2, "set": "bell", "slot": "girdle"}))
	m = DB.mods({})
	ok(int(m.lash_every) == 2, "4 worn: the Lash every 2nd bolt")
	ok(float(m.cd) < 1.0, "4 worn: spells recover sooner (cd %.3f)" % m.cd)
	# a legend
	var leg := GearDB.make(rng, {"legend": "sunk_shroud", "uid": 901})
	GearRuntime.store(leg)
	st.worn["vestment"] = 901
	m = DB.mods({})
	ok(bool(m.bramble), "Shroud of the Sunk: the Ward roots in brambles")
	ok(GearStats.set_counts(st).get("bell", 0) == 3 and int(m.lash_every) == 3, "swapping a set piece out drops the 4-piece bonus")
	ok(not GearStats.summary(st).is_empty(), "summary: %s" % ", ".join(GearStats.summary(st)))
	# a full bag salvages
	while (st.bag as Array).size() < GearDB.BAG_CAP:
		GearRuntime.store(GearDB.make(rng, {"rarity": 0}))
	var shards := Travel.count("ember_shard")
	line = GearRuntime.store(GearDB.make(rng, {"rarity": 3}))
	ok((st.bag as Array).size() == GearDB.BAG_CAP and Travel.count("ember_shard") == shards + GearDB.SALVAGE[3], "a full bag salvages the newcomer: \"%s\"" % line)


func _working() -> void:
	print("-- raise, reforge, salvage")
	_reset()
	var rt: Node = GearRuntime.new()
	rt.rng.seed = 11
	add_child(rt)
	var p := GearDB.make(rng, {"rarity": 2, "slot": "girdle"})
	GearRuntime.store(p)
	var uid := int(p.uid)
	var why := String(rt.call("upgrade", uid, true))
	ok(why.contains("grave ash"), "no ash, no raise: \"%s\"" % why)
	Travel.items["grave_ash"] = 100
	Travel.items["ember_shard"] = 1
	why = String(rt.call("upgrade", uid, true))
	ok(why.contains("ember shards"), "no shards, no raise: \"%s\"" % why)
	Travel.items["ember_shard"] = 100
	why = String(rt.call("upgrade", uid, false))
	ok(why.contains("fire"), "only at a fire: \"%s\"" % why)
	var before := float(GearDB.base_value(p)[1])
	var c := GearDB.upgrade_cost(p)
	ok(String(rt.call("upgrade", uid, true)) == "" and int(p.level) == 1, "raised to +1")
	ok(Travel.count("grave_ash") == 100 - int(c.ash) and Travel.count("ember_shard") == 100 - int(c.shards), "it cost %d ash, %d shards" % [c.ash, c.shards])
	ok(absf(float(GearDB.base_value(p)[1])) > absf(before), "the base stat grew (%.3f -> %.3f)" % [before, GearDB.base_value(p)[1]])
	for i in 6:
		rt.call("upgrade", uid, true)
	ok(int(p.level) == GearDB.max_level(p), "it stops at +%d" % GearDB.max_level(p))
	why = String(rt.call("reforge", uid, 0, true))
	ok(why.contains("fragment"), "a Hallowed reforge needs a relic fragment: \"%s\"" % why)
	Travel.items["relic_fragment"] = 1
	var old: Array = (p.aff as Array).duplicate(true)
	ok(String(rt.call("reforge", uid, 0, true)) == "" and Travel.count("relic_fragment") == 0, "reforged the first line")
	ok((p.aff as Array).size() == old.size() and String(p.aff[1][0]) == String(old[1][0]), "the other line is kept")
	ok(String(p.aff[0][0]) != String(p.aff[1][0]), "no affix doubled by the reforge")
	var shards := Travel.count("ember_shard")
	var sv := GearDB.salvage_value(p)
	ok(String(rt.call("salvage", uid)) == "" and GearStats.find(GearStats.state(), uid).is_empty(), "salvaged")
	ok(Travel.count("ember_shard") == shards + sv and not GearStats.state().worn.has("girdle"), "+%d shards, and the slot is empty" % sv)
	rt.queue_free()


func _drops() -> void:
	print("-- drops")
	_reset()
	var rt: Node = GearRuntime.new()
	rt.rng.seed = 3
	add_child(rt)
	var e := Node3D.new()
	e.set_meta(&"elite_id", "hobb")
	ok(GearRuntime.source_of(e) == "elite", "an elite is an elite")
	for i in 10:
		var d: Dictionary = rt.call("roll_drop", "elite")
		if d.is_empty() or int(d.rarity) < 1 or i < 2:
			ok(not d.is_empty() and int(d.rarity) >= 1, "elite drop %d: %s %s" % [i, GearDB.rarity_name(int(d.get("rarity", 0))), d.get("name", "")])
	var got := 0
	for i in 400:
		if not (rt.call("roll_drop", "kill") as Dictionary).is_empty():
			got += 1
	ok(got >= 8 and got <= 60, "common foes drop now and then: %d in 400 (pity included)" % got)
	var boss: Dictionary = rt.call("roll_drop", "boss")
	ok(int(boss.rarity) >= 2 and (String(boss.set) != "" or String(boss.legend) != ""), "a great one drops a set piece or a legend: %s" % boss.name)
	e.free()
	rt.queue_free()


func _world() -> void:
	print("-- the world")
	_reset()
	var main: Node = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		if main.has_meta("realm_done"):
			break
	for i in 30:
		await get_tree().physics_frame
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	var rt := get_tree().get_first_node_in_group("gear")
	var panel := get_tree().get_first_node_in_group("gear_panel")
	for en in get_tree().get_nodes_in_group(Groups.ENEMY):
		(en as Node).queue_free()
	await get_tree().create_timer(0.8).timeout
	ok(p != null and rt != null and panel != null, "player, gear runtime and gear panel are in the Realm")
	if p == null or rt == null or panel == null:
		main.queue_free()
		return
	ok(p.skills().slots[0].get_script() != BoltSkill, "nothing worn: stock skills")
	var gmax := p.gloom_max
	var light := p.find_child("LanternLight", true, false) as OmniLight3D
	var col0 := light.light_color if light else Color.BLACK
	var v := GearDB.make(rng, {"rarity": 3, "slot": "vestment"})
	Events.toast.emit(GearRuntime.store(v))
	var glass := GearDB.make(rng, {"legend": "unlit_lamp"})
	GearRuntime.store(glass)
	await get_tree().create_timer(0.8).timeout
	ok(p.gloom_max > gmax, "a vestment raises the Gloom held (%.0f -> %.0f)" % [gmax, p.gloom_max])
	ok(p.skills().slots[0].get_script() == BoltSkill, "worn gear: the hotbar runs the tuned skills")
	ok(bool(DB.live.get("jar", false)), "the Unlit Lamp's legend is live")
	ok(light != null and light.light_color != col0, "the lantern's light takes the Umbral glass (%s -> %s)" % [col0, light.light_color if light else ""])
	ok(light != null and light.get_parent().get_node_or_null("GearMotes") != null, "an Umbral glass adds motes at the lantern")
	# a drop in the world, walked into
	var n0 := (GearStats.state().bag as Array).size()
	var d: Dictionary = rt.call("roll_drop", "elite")
	rt.call("drop_at", d, p.global_position + Vector3(2.5, 0, 0))
	await get_tree().process_frame
	ok(get_tree().get_nodes_in_group("gear_drop").size() == 1, "a drop lies in the world as a shaft of light")
	await get_tree().create_timer(1.6).timeout
	ok(get_tree().get_nodes_in_group("gear_drop").is_empty() and (GearStats.state().bag as Array).size() == n0 + 1, "it drifts to the wanderer and is taken")
	# the panel
	panel.call("open_menu")
	await get_tree().process_frame
	ok(panel.call("is_open") and get_tree().paused, "[G] opens the gear panel and pauses")
	var rows: Array = panel.get("_rows")
	ok(rows.size() == n0 + 1, "it lists every piece carried (%d)" % rows.size())
	panel.set("_sel_uid", int(v.uid))
	panel.call("_show")
	panel.call("_wear_toggle")
	ok(not GearStats.state().worn.has("vestment"), "Take off from the panel")
	panel.call("_wear_toggle")
	ok(int(GearStats.state().worn.get("vestment", -1)) == int(v.uid), "and Wear again")
	panel.call("close_menu")
	ok(not panel.call("is_open") and not get_tree().paused, "it closes and unpauses")
	main.queue_free()
	await get_tree().process_frame


func _persist() -> void:
	print("-- the save")
	var bag_n := (GearStats.state().bag as Array).size()
	var worn: Dictionary = GearStats.state().worn.duplicate()
	Travel.set("_busy", false)
	Travel.save_game()
	Travel.set("_busy", true)
	var cfg := ConfigFile.new()
	ok(cfg.load(Travel.SAVE_PATH) == OK, "the save reads back")
	var sys: Dictionary = cfg.get_value("systems", "state", {})
	ok(sys.has("gear") and (sys.gear.bag as Array).size() == bag_n, "[systems] gear holds the bag (%d)" % bag_n)
	ok((sys.get("gear", {}).get("worn", {}) as Dictionary) == worn, "and what is worn")
