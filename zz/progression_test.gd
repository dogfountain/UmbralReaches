extends Node
## Progression (the Kindling) end to end, in the Realm:
##   godot --headless --path . res://zz/progression_test.tscn
## earn ash from kills -> stand at a lit brazier -> buy through the menu and the runtime -> the
## effects land on the player and the skills (numbers and behaviour: Undertow pulls, Mirror Flame
## turns spit, Rend bursts, the Lash comes every 2nd bolt, Cinder Scar burns) -> gates and costs
## refuse what they should -> charms (pickup, auto-wear, cords) -> the satchel hooks -> saved in
## [systems] -> reload the save and a fresh Realm and it is all still applied.
## The real save (user://savegame.cfg and .bak) is shared with every other test, so Travel's saving
## is held off (Travel._busy) for the whole run except one write + read-back, after which the
## original bytes go straight back; they are restored again at the end.
## Ends: PROGRESSION TEST PASS  /  PROGRESSION TEST FAIL n

const DB := preload("res://core/life/progression/upgrade_db.gd")
const BoltSkill := preload("res://core/life/progression/skills/bolt.gd")
const NovaSkill := preload("res://core/life/progression/skills/nova.gd")
const CinderScar := preload("res://core/life/progression/fx/cinder_scar.gd")
const RiftRend := preload("res://core/life/progression/fx/rift_rend.gd")

var fails := 0
var _bak := {}
var _travel := {}
var main: Node
var p: Player
var k: Node
var g: Node


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_backup()
	await _load_world()
	if p == null or k == null:
		ok(false, "world, player and progression runtime came up")
	else:
		await _run()
	_restore()
	print("PROGRESSION TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	Travel.set("_busy", true)               # no save-on-quit over the restored file
	get_tree().quit(0 if fails == 0 else 1)


func _backup() -> void:
	for suf: String in ["", ".bak"]:
		var path := Travel.SAVE_PATH + suf
		_bak[suf] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	for key: String in ["seals_broken", "bosses_slain", "items", "relics", "systems", "story", "lit_by_path", "area_lit", "checkpoints"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
		Travel.set(key, {})
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}   # no opening narration
	Travel.set("_busy", true)               # Travel.save_game() is a no-op until the persist step


func _restore() -> void:
	for key: String in _travel:
		Travel.set(key, _travel[key])
	_restore_file()


## Put the real save's bytes back (other agents' tests read and write the same file).
func _restore_file() -> void:
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
	g = get_tree().get_first_node_in_group("growth")
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	await get_tree().create_timer(0.7).timeout       # the runtime finds the player on its 0.5 s scan
	print("  world up in %d ms" % (Time.get_ticks_msec() - t0))


func _kill(at: Vector3, n: int) -> void:
	for i in n:
		var d := Node3D.new()
		main.add_child(d)
		d.global_position = at
		Events.enemy_killed.emit(d)
		d.queue_free()


func _fire() -> Brazier:
	var best: Brazier = null
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier:
			if best == null or String(n.name) == "Sanctuary":
				best = n
	return best


func _run() -> void:
	print("-- the world")
	ok(g != null, "the Kindling menu is in the zone (group growth)")
	var spots := 0
	for n in k.get_children():
		if n.get("brazier") != null:
			spots += 1
	var braziers := 0
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier:
			braziers += 1
	ok(spots == braziers and spots >= 4, "every brazier has a Tend-the-fire spot (%d of %d)" % [spots, braziers])
	var charms := 0
	for n in k.get_children():
		if String(n.name).begins_with("Charm_"):
			charms += 1
			var c := n as Node3D
			ok(absf(c.global_position.y - (load("res://core/world/realm/realm_land.gd") as GDScript).call("height_at", c.global_position.x, c.global_position.z)) < 2.6, "%s lies on the ground at %s" % [n.name, c.global_position.snapped(Vector3.ONE * 0.1)])
	ok(charms == DB.CHARM_SPOTS.size(), "all %d charms laid in the world (%d)" % [DB.CHARM_SPOTS.size(), charms])
	var base_max := p.gloom_max
	var base_range := p.step_range
	ok(p.skills().slots[0].get_script() != BoltSkill, "nothing owned: the stock skills are untouched")

	print("-- earn ash")
	_kill(p.global_position + Vector3(0, 0, 60), 30)
	await get_tree().process_frame
	ok(Travel.count("grave_ash") == 30, "30 kills -> 30 grave ash (%d)" % Travel.count("grave_ash"))

	print("-- at the fire")
	var b := _fire()
	if not b.lit:
		b.kindle_quiet()
	p.global_position = b.spawn_point()
	for i in 6:
		await get_tree().physics_frame
	ok(k.call("at_fire") == b, "standing by a lit brazier counts as at the fire")
	var spot: Node = null
	for n in k.get_children():
		if n.get("brazier") == b:
			spot = n
	ok(spot != null and spot.call("can_interact"), "the fire offers 'Tend the fire' (no relics yet)")
	spot.call("interact", p)
	await get_tree().process_frame
	ok(g.call("is_open") and get_tree().paused, "Tend the fire opens the Kindling and pauses")
	ok(g.call("at_fire"), "the menu knows it is at a fire")

	print("-- buy through the menu")
	g.call("show_tab", 0)
	var cards: Array = g.get("_cards")
	var idx := -1
	for i in cards.size():
		if cards[i].id == "warmth":
			idx = i
	g.set("_sel", idx)
	g.call("act")
	ok(DB.rank(Travel.system_state("progression"), "warmth") == 1, "Hearth-Warmth I kindled from the menu")
	ok(Travel.count("grave_ash") == 24, "it cost 6 ash (%d left)" % Travel.count("grave_ash"))
	ok(is_equal_approx(p.gloom_max, base_max + 15.0), "Gloom capacity %.0f -> %.0f" % [base_max, p.gloom_max])
	g.call("close_menu")
	ok(not get_tree().paused and not g.call("is_open"), "the Kindling closes and unpauses")

	print("-- spells, gates, oaths")
	ok(String(k.call("buy", "bolt", true)) == "", "Rift Bolt I kindled")
	ok(p.skills().slots[0].get_script() == BoltSkill, "the hotbar's Rift Bolt is now the ranked one")
	ok(Travel.count("grave_ash") == 16, "8 ash (%d left)" % Travel.count("grave_ash"))
	var why := String(k.call("buy", "bolt", true))
	ok(why.contains("fallen") and DB.rank(Travel.system_state("progression"), "bolt") == 1, "rank II waits for a boss: \"%s\"" % why)
	why = String(k.call("buy", "warmth", false))
	ok(why != "" and Travel.count("grave_ash") == 16, "nothing is bought away from a fire: \"%s\"" % why)
	why = String(k.call("buy", "deep", true))
	ok(why.contains("Bone Reliquary"), "a rite needs its relic: \"%s\"" % why)
	ok(String(k.call("swear", 1, "b", true)) == "", "swore the Oath of the Hollow (12 ash)")
	ok(Travel.count("grave_ash") == 4, "4 ash left (%d)" % Travel.count("grave_ash"))
	ok(String(k.call("swear", 1, "a", true)) == "Sworn.", "the other vow of the tier is closed")
	p.wounds = 50.0
	_kill(p.global_position + Vector3(2, 0, 0), 1)
	await get_tree().process_frame
	ok(p.wounds <= 50.0 - 6.0 - 4.0 + 0.01, "a kill under the Hollow oath mends 10 Wounds, not 6 (%.1f)" % p.wounds)
	ok(String(k.call("buy", "will", true)).contains("grave ash"), "too poor for Kindled Will (10)")

	print("-- behaviour of the ranks (save edited directly)")
	Travel.bosses_slain = {"thornwarden": true, "bone_abbot": true}
	var st := Travel.system_state("progression")
	st.ranks["nova"] = 3
	st.ranks["step"] = 3
	st.ranks["ward"] = 3
	st.ranks["lance"] = 3
	st.oaths["2"] = "a"
	k.call("refresh")
	var book := p.skills()
	var nova: Skill = book.slots[2]
	ok(nova.get_script() == NovaSkill and is_equal_approx(nova.call("radius"), 7.2), "Nova I: ring 7.2 m")
	ok(is_equal_approx(nova.cooldown, 5.5), "Nova II: 5.5 s recovery (%.2f)" % nova.cooldown)
	ok(is_equal_approx(p.step_range, base_range + 2.0), "Step I: %.1f m" % p.step_range)
	ok(is_equal_approx(p.step_evade, 0.6), "Step II: 0.6 s untouchable")
	ok(is_equal_approx(book.slots[3].cooldown, 17.0), "Ward II: 17 s recovery")
	ok(is_equal_approx(book.slots[1].max_charge, 0.9 * 0.75), "Lance I: charges in %.3f s" % book.slots[1].max_charge)
	ok(int(DB.live.lash_every) == 2 and book.slots[0].pips(book).y == 2, "Oath of the Lash: the Lash every 2nd bolt")
	# Undertow: a wretch 5 m out is dragged in, not thrown out
	var w := Wretch.new()
	main.add_child(w)
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	w.global_position = p.global_position + fwd.normalized() * 5.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	w.set("_knock", Vector3.ZERO)
	nova.call("_detonate", p)
	var kn: Vector3 = w.get("_knock")
	var to_p := p.global_position - w.global_position
	ok(kn.length() > 1.0 and kn.dot(to_p) > 0.0, "Nova III Undertow drags a wretch at 5 m toward you (%s)" % kn.snapped(Vector3.ONE * 0.1))
	# Rend: the tear left behind hurts and marks
	w.global_position = p.global_position + fwd.normalized() * 1.5
	w.set("_knock", Vector3.ZERO)
	w.velocity = Vector3.ZERO
	w.set_physics_process(false)             # hold it still: the test is the burst, not the chase
	w.hp = 20.0
	w.marks = 0
	await get_tree().physics_frame
	RiftRend.open(p, w.global_position, 1.0)
	var rend := get_tree().current_scene.get_node_or_null("RiftRend")
	print("  (rend %s, wretch %.1f m off)" % [rend != null, w.global_position.distance_to(p.global_position)])
	await get_tree().create_timer(0.6).timeout
	ok(is_instance_valid(w) and w.hp < 20.0 and w.marks >= 1, "Step III Rend bursts: wretch hp %.1f, marks %d" % [w.hp if is_instance_valid(w) else -1.0, w.marks if is_instance_valid(w) else -1])
	# Cinder Scar burns what stands in it
	if is_instance_valid(w):
		w.set_physics_process(true)
		w.hp = 20.0
		w.marks = 0
		var scar := CinderScar.light_at(main, w.global_position)
		await get_tree().create_timer(1.2).timeout
		ok(w.hp < 20.0 and w.marks >= 1, "Lance III Cinder Scar scorches and marks (hp %.1f, marks %d)" % [w.hp, w.marks])
		if is_instance_valid(scar):
			scar.queue_free()
	# Mirror Flame: spit reaching the ward is turned back
	var ward_ok := book.try_cast(3, 0.0, false)
	await get_tree().physics_frame
	var ward := get_tree().get_first_node_in_group(&"lantern_ward") as Node3D
	ok(ward_ok and ward != null and float(ward.get("_t")) < 0.0, "Ward I: the planted ward burns longer (t starts at %.2f)" % (float(ward.get("_t")) if ward else 0.0))
	if is_instance_valid(w) and ward:
		w.hp = 20.0
		var orb := SpitOrb.launch(main, ward.global_position + Vector3(2.0, 1.2, 0.0), Vector3.LEFT, 10.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		ok(not is_instance_valid(orb) or not orb.is_in_group(Groups.ENEMY_SHOT), "Ward III Mirror Flame pops spit in its light")
		ok(w.hp < 20.0, "... and turns it on the nearest enemy (hp %.1f)" % w.hp)
	if is_instance_valid(w):
		w.queue_free()

	print("-- charms")
	Travel.give("charm_thread", 1)
	await get_tree().process_frame
	ok(DB.worn(st).has("charm_thread"), "a found charm goes on at once")
	ok(is_equal_approx(p.step_range, base_range + 2.0 + 1.5), "Pell's Red Thread: step %.1f m" % p.step_range)
	Travel.give("charm_candle", 1)
	Travel.give("charm_bead", 1)
	await get_tree().process_frame
	ok(DB.worn(st).size() == 2 and not DB.worn(st).has("charm_bead"), "two cords: the third charm waits in the satchel")
	ok(String(k.call("toggle_charm", "charm_bead")).contains("full"), "wearing a third is refused while the cords are full")
	ok(String(k.call("toggle_charm", "charm_candle")) == "" and String(k.call("toggle_charm", "charm_bead")) == "", "swap the candle for the bead")
	ok(float(DB.live.kill_relief) >= 6.0, "the bead adds kill relief (%.0f)" % float(DB.live.kill_relief))
	# an elite's bounty (encounters pays it out with Travel.give) is a charm too
	ok(String(ItemDB.def("heart_stone").kind) == "charm" and ItemDB.DEFS.has("hobbs_knuckles") and ItemDB.DEFS.has("scraped_face"), "the six elite bounties are ItemDB charms")
	k.call("toggle_charm", "charm_bead")
	var max_before := p.gloom_max
	Travel.give("heart_stone", 1, false)
	await get_tree().process_frame
	ok(DB.worn(st).has("heart_stone") and is_equal_approx(p.gloom_max, max_before + 10.0), "the Heart-Stone goes on: Gloom %.0f -> %.0f" % [max_before, p.gloom_max])
	Travel.give("hobbs_knuckles", 1, false)
	ok(not DB.worn(st).has("hobbs_knuckles"), "a bounty won with the cords full waits in the satchel")
	k.call("toggle_charm", "heart_stone")
	k.call("toggle_charm", "charm_bead")
	ok(is_equal_approx(p.gloom_max, max_before), "and comes off again")
	# the bar never reads past its capacity: fill it while a +10 charm is worn, take the charm off
	k.call("toggle_charm", "heart_stone")
	p.add_gloom(500.0)
	ok(p.gloom <= p.gloom_max + 0.001, "gloom is capped at its capacity (%.0f / %.0f)" % [p.gloom, p.gloom_max])
	k.call("toggle_charm", "heart_stone")
	ok(p.gloom <= p.gloom_max + 0.001, "and a smaller capacity pulls it down (%.0f / %.0f)" % [p.gloom, p.gloom_max])
	p.gloom = 0.0

	print("-- satchel hooks")
	var sat := main.get_node_or_null("Satchel")
	if sat:
		sat.call("open_menu", true)
		await get_tree().process_frame
		ok(g.call("is_open") and int(g.get("_tab")) == 3, "the brazier's attune opens the Kindling on Relics")
		sat.call("close_menu")
		await get_tree().process_frame
		ok(not g.call("is_open") and not get_tree().paused, "closing it unpauses")
		sat.call("open_menu")
		var groups := []
		for s in sat.get("_slots"):
			groups.append(String(ItemDB.def(String(s.id)).kind))
		ok(not groups.has("charm") and not groups.has("relic"), "r35: the Pack holds no charms or relics; they are on Wanderer (%s)" % ",".join(groups))
		sat.call("close_menu")
	else:
		ok(false, "satchel present")

	print("-- persist and reload")
	Travel.give("grave_ash", 40, false)
	ok(String(k.call("buy", "will", true)) == "", "Kindled Will I (10)")
	var want_ranks: Dictionary = (st.ranks as Dictionary).duplicate()
	var want_ash := Travel.count("grave_ash")
	Travel.set("_busy", false)
	Travel.save_game()
	Travel.set("_busy", true)
	var cfg := ConfigFile.new()
	ok(cfg.load(Travel.SAVE_PATH) == OK, "save file written")
	var sys: Dictionary = cfg.get_value("systems", "state", {})
	ok(sys.has("progression") and (sys.progression.ranks as Dictionary) == want_ranks, "ranks in [systems] progression: %s" % str(sys.get("progression", {}).get("ranks", {})))
	ok(int(sys.get("progression", {}).get("spent", 0)) == 6 + 8 + 12 + 10, "ash spent recorded (%d)" % int(sys.get("progression", {}).get("spent", 0)))
	# forget everything, read the save back, rebuild the Realm
	Travel.systems = {}
	Travel.items = {}
	Travel.load_game()
	_restore_file()                          # the real save is ours for milliseconds only
	Travel.bosses_slain = {"thornwarden": true, "bone_abbot": true}
	ok((Travel.system_state("progression").ranks as Dictionary) == want_ranks and Travel.count("grave_ash") == want_ash, "the save reads back")
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await _load_world()
	if p == null or k == null:
		ok(false, "the Realm came back")
		return
	ok(is_equal_approx(p.gloom_max, base_max + 15.0), "after reload: Gloom capacity %.0f" % p.gloom_max)
	ok(p.skills().slots[0].get_script() == BoltSkill and is_equal_approx(p.skills().slots[2].cooldown, 5.5), "after reload: ranked skills on the hotbar")
	ok(is_equal_approx(p.step_range, base_range + 2.0 + 1.5), "after reload: worn charm and Step I (%.1f m)" % p.step_range)
	ok(is_equal_approx(float(DB.live.power), 1.1), "after reload: spell power x%.2f" % float(DB.live.power))
	var laid := 0
	for n in k.get_children():
		if String(n.name).begins_with("Charm_"):
			laid += 1
	ok(laid == DB.CHARM_SPOTS.size() - 3, "charms already found are not laid again (%d left in the world)" % laid)
