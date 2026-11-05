extends Node
## Skills, staff and progression (B, r28) end to end, in the Realm:
##   HOME=<scratch>/home godot --headless --path . res://zz/skill_test.tscn
## Casts every spell at every rank against held wretches and checks damage, cooldowns, Marks and
## the behaviour each rank adds; learns the three new spells and swaps them onto the hotbar; forges
## and sets every staff core (split, leap, burn, chill/freeze); fires every combo; opens every page
## of the Kindling. Counts engine errors through a Logger: any error fails the run.
## Never writes the save (Travel._busy all run). Ends: SKILL TEST PASS  /  SKILL TEST FAIL n

const DB := preload("res://core/life/progression/upgrade_db.gd")
const Combo := preload("res://core/skills/combo.gd")
const Afflict := preload("res://core/skills/afflict.gd")
const SPOT := Vector2(8.0, 48.0)
const RealmLand := preload("res://core/world/realm/realm_land.gd")

class ErrCount extends Logger:
	var n := 0
	var last: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var msg := "%s %s:%d %s" % [code, file, line, rationale]
		# only what B's area raised: other agents' work in progress (and the headless display
		# server's missing keyboard map) must not fail this test
		var where := file
		for bt in script_backtrace:
			for f in bt.get_frame_count():
				where += " " + bt.get_frame_file(f)
		if not _mine(where) or msg.contains("Not supported by this display server"):
			return
		n += 1
		if last.size() < 12:
			last.append("%s (%s)" % [msg, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func _mine(where: String) -> bool:
		for k: String in ["core/skills/", "core/life/progression/", "magic_bolt", "bolt_pool", "spell_fx", "core/vfx/vfx.gd", "staff_sfx",
				"core/items/", "ui/growth", "ui/hotbar", "ui/satchel", "combo_readout", "zz/skill_"]:
			if where.contains(k):
				return true
		return false

var fails := 0
var errs := ErrCount.new()
var main: Node
var p: Player
var k: Node
var g: Node
var book: SkillBook
var _travel := {}
var _foes: Array = []
var _only := ""                 ## -- --only=tether,well : run just those sections (stock, loadout always run)
var fire: Brazier


func _want(key: String) -> bool:
	return _only == "" or key == "loadout" or key == "stock" or _only.split(",").has(key)


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(errs)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.trim_prefix("--only=")
	Travel._busy = true
	for key: String in ["seals_broken", "bosses_slain", "items", "relics", "systems", "story", "lit_by_path", "area_lit", "checkpoints"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
		Travel.set(key, {})
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	await _load_world()
	if p == null or k == null or book == null:
		ok(false, "world, player, SkillBook and progression came up")
	else:
		await _run()
	for key: String in _travel:
		Travel.set(key, _travel[key])
	ok(errs.n == 0, "no engine errors during the run (%d)%s" % [errs.n, ("\n        " + "\n        ".join(errs.last)) if errs.n > 0 else ""])
	print("SKILL TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	Travel._busy = true
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
	g = get_tree().get_first_node_in_group("growth")
	book = p.skills() if p else null
	_clear_foes(true)
	await get_tree().create_timer(0.7).timeout
	print("  world up in %d ms" % (Time.get_ticks_msec() - t0))


func _clear_foes(all := false) -> void:
	for e in (get_tree().get_nodes_in_group(Groups.ENEMY) if all else _foes):
		if is_instance_valid(e):
			(e as Node).queue_free()
	_foes.clear()


## A held wretch `ahead` m in front of the wanderer (+`side` m right), with `hp`.
func _foe(ahead: float, side := 0.0, hp := 60.0, live := false) -> Enemy:
	var w := Wretch.new()
	main.add_child(w)
	var fwd := _fwd()
	var right := fwd.cross(Vector3.UP)
	var at := p.global_position + fwd * ahead + right * side
	at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.05
	w.global_position = at
	w.max_hp = int(hp)
	w.hp = hp
	w.set("strike_gloom", 0.0)
	if not live:
		w.set_physics_process(false)
	_foes.append(w)
	return w


func _fwd() -> Vector3:
	return Vector3(-sin(0.94), 0.0, -cos(0.94))


## A dark, open, level spot: lit zones are sanctuaries foes may not be dragged into
## (Enemy._light_barrier), and the core tests need foes standing level with the aim.
var _spot_cache := Vector3.INF


func _spot() -> Vector3:
	if _spot_cache != Vector3.INF:
		return _spot_cache
	var space := p.get_world_3d().direct_space_state
	var right := _fwd().cross(Vector3.UP)
	for z in range(60, -60, -8):
		for x in range(-90, 90, 8):
			if x > -34 and x < 34 and z < -8:
				continue                                  # the Rift
			var c := Vector2(x, z)
			var y0 := RealmLayout.ground(space, c.x, c.y)
			var ok_spot := not RealmLand.in_water(c.x, c.y)
			for i in 9:
				if not ok_spot:
					break
				for sd: float in [-4.0, 0.0, 4.0]:
					var q := Vector3(c.x, 0.0, c.y) + _fwd() * float(i) * 2.0 + right * sd
					if LightGrid.repel(q, 2.0) != Vector3.ZERO or absf(RealmLayout.ground(space, q.x, q.z) - y0) > 0.6 or RealmLand.in_water(q.x, q.z):
						ok_spot = false
						break
			if ok_spot:
				print("  test spot %s" % c)
				_spot_cache = Vector3(c.x, y0, c.y)
				return _spot_cache
	print("  no dark level spot found: using the meadow")
	_spot_cache = Vector3(SPOT.x, RealmLayout.ground(space, SPOT.x, SPOT.y), SPOT.y)
	return _spot_cache


func _place() -> void:
	var at := _spot()
	at.y += 0.3
	p.teleport(at)
	p.set_view(0.94, -0.08)
	p.gloom = 0.0; p.wounds = 0.0
	for i in 4:
		await get_tree().physics_frame


## Point the camera at `e`'s chest (yaw and pitch), and let the camera settle.
func _aim_at(e: Node3D, off_deg := 0.0) -> void:
	var cam := get_viewport().get_camera_3d()
	var h: float = (e as Enemy).hp_bar_y * 0.55 if e is Enemy else 1.0
	var eye: Vector3 = cam.global_position if cam else p.global_position + Vector3.UP * 1.6
	var to: Vector3 = e.global_position + Vector3.UP * h - eye
	var yaw := atan2(-to.x, -to.z) + deg_to_rad(off_deg)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	p.set_view(yaw, clampf(pitch, -0.9, 0.5))
	for i in 3:
		await get_tree().process_frame
	await get_tree().physics_frame


func _slot(id: StringName) -> int:
	return book.slot_of(id)


## Cast slot `id` now (cooldowns cleared first). Returns try_cast's answer.
func _cast(id: StringName, charge := 0.0) -> bool:
	var i := _slot(id)
	if i < 0:
		return false
	book._cd.fill(0.0)
	book._gcd = 0.0
	p.gloom = 0.0; p.wounds = 0.0
	if p.combat() != null:                   # r33: exact numbers: no crits, no Resonance spend, no Surge
		p.combat().set("crit_chance", 0.0)
		p.combat().call("clear", p)
	return book.try_cast(i, charge, false)


func _setp(ranks: Dictionary, extra := {}) -> void:
	var st := Travel.system_state("progression")
	for id: String in ranks:
		(st.ranks as Dictionary)[id] = int(ranks[id])
	for key: String in extra:
		st[key] = extra[key]
	k.call("refresh")


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func _run() -> void:
	await _place()
	Combo.reset()
	if _want("stock"):
		await _s_stock()
	if _want("loadout"):
		await _s_loadout()
	if _want("bolt"):
		await _s_bolt()
	if _want("lance"):
		await _s_lance()
	if _want("nova"):
		await _s_nova()
	if _want("ward"):
		await _s_ward()
	if _want("step"):
		await _s_step()
	if _want("tether"):
		await _s_tether()
	if _want("well"):
		await _s_well()
	if _want("shade"):
		await _s_shade()
	if _want("cores"):
		await _s_cores()
	if _want("ui"):
		await _s_ui()


func _s_stock() -> void:
	print("-- stock spells, nothing owned")
	ok(book.slots.size() == 5 and book.slots[0].action == &"skill_bolt" and book.slots[4].action == &"skill_step", "five slots on their keys")
	var w := _foe(9.0)
	await _aim_at(w)
	ok(_cast(&"bolt"), "Rift Bolt casts")
	ok(absf(book.cooldown_left(0) - book.slots[0].cooldown) < 0.05, "Rift Bolt recovery %.2f s" % book.slots[0].cooldown)
	await _wait(0.6)
	ok(w.hp <= 59.01 and w.marks >= 1, "a bolt hits for 1 and Marks (hp %.1f, marks %d)" % [w.hp, w.marks])
	w.hp = 60.0
	w.marks = 2
	ok(_cast(&"lance", 1.0), "Ember Lance casts (full)")
	await _wait(0.7)
	ok(w.hp <= 60.0 - 4.0 - 0.99, "a full Lance on 2 Marks: 4 + Kindled Rift 1.0 (hp %.1f)" % w.hp)
	ok(int(Combo.count.get("KINDLED RIFT", 0)) == 1 and Afflict.is_burning(w), "KINDLED RIFT noted, the foe burns")
	_clear_foes()
	var near: Array = []
	for i in 3:
		var e := _foe(2.5 + i * 0.8, -1.5 + 1.5 * i)
		e.marks = 1
		near.append(e)
	ok(_cast(&"nova"), "Umbral Nova casts")
	ok(absf(book.cooldown_left(2) - 7.0) < 0.05, "Nova recovery 7 s")
	var hurt := 0
	for e: Enemy in near:
		if e.hp <= 58.01:
			hurt += 1
	ok(hurt == 3 and int(Combo.count.get("DETONATION", 0)) == 1, "Nova: 1 + 1 per Mark on three foes, DETONATION (%d hurt)" % hurt)
	_clear_foes()
	await get_tree().process_frame


func _s_loadout() -> void:
	print("-- learning, the loadout")
	fire = _fire()
	if not fire.lit:
		fire.kindle_quiet()
	p.global_position = fire.spawn_point()
	for i in 6:
		await get_tree().physics_frame
	Travel.give("grave_ash", 200, false)
	ok(String(k.call("learn", "tether", true)) == "", "Rift Tether learned (14 ash)")
	ok(String(k.call("learn", "well", true)).contains("fallen"), "Umbral Well waits for a boss")
	Travel.bosses_slain = {"thornwarden": true, "bone_abbot": true}
	ok(String(k.call("learn", "well", true)) == "" and String(k.call("learn", "familiar", true)) == "", "Umbral Well and Bound Shade learned")
	ok(String(k.call("buy", "tether", false)) != "", "nothing ranked away from a fire")
	ok(String(k.call("set_loadout", 1, "tether", true)) == "" and book.slots[1].id == &"tether" and book.slots[1].action == &"skill_lance", "Rift Tether on [RMB]")
	ok(String(k.call("set_loadout", 3, "well", true)) == "" and book.slots[3].id == &"well" and book.slots[3].action == &"skill_ward", "Umbral Well on [F]")
	ok(String(k.call("set_loadout", 1, "well", true)) == "" and book.slots[1].id == &"well" and book.slots[3].id == &"tether", "putting the Well on [RMB] trades it with the Tether")
	ok(String(k.call("set_loadout", 2, "familiar", false)) != "", "the loadout changes only at a fire")
	k.call("cycle_slot", 4, true)
	ok(book.slots[4].id != &"step", "cycling [C] moves to the next known spell (%s)" % book.slots[4].id)
	_setp({}, {"loadout": ["lance", "nova", "ward", "step"]})
	ok(book.slots[1].id == &"lance" and book.slots[4].id == &"step", "back to the stock four")
	# the village's quest charms (E awards them by id)
	for id: String in ["charm_ferrule", "charm_waystone", "charm_chalk"]:
		ok(String(ItemDB.def(id).kind) == "charm" and DB.CHARM_FX.has(id) and DB.QUEST_CHARMS.has(id), "%s is a charm with an effect" % id)
	var st := Travel.system_state("progression")
	st["worn"] = []
	Travel.give("charm_ferrule", 1, false)
	Travel.give("charm_waystone", 1, false)
	ok(DB.worn(st).has("charm_ferrule") and absf(book.slots[4].cooldown - 2.1 * 0.8 * float(DB.live.cd)) < 0.01, "Edda's Ferrule: Rift Step recovers in %.2f s" % book.slots[4].cooldown)
	ok(is_equal_approx(float(DB.live.well_life), 1.5) and is_equal_approx(float(DB.live.ward_life), 1.5), "the Waystone chip: Ward and Well hold 1.5 s longer")
	k.call("toggle_charm", "charm_ferrule")
	Travel.give("charm_chalk", 1, false)                  # a free cord: it goes on at once
	ok(bool(DB.live.chalk), "Nan's Chalk worn")
	st["worn"] = []
	k.call("refresh")

	await _place()
	await get_tree().process_frame


func _s_bolt() -> void:
	print("-- Rift Bolt ranks")
	_setp({"bolt": 1})
	var w: Enemy = _foe(12.0)
	await _aim_at(w, 5.0)                    # aimed 5 degrees off: Keen bends it home
	_cast(&"bolt")
	await _wait(0.7)
	ok(w.hp < 60.0, "Bolt I Keen: a bolt aimed 5 deg off still finds the foe (hp %.1f)" % w.hp)
	_clear_foes()
	_setp({"bolt": 2})
	w = _foe(9.0)
	var side := _foe(9.0, 3.2)
	await _aim_at(w)
	var bolt: Skill = book.slots[0]
	bolt.set("_chain", 2)
	bolt.set("_last", Time.get_ticks_msec() * 0.001)
	w.marks = 0
	_cast(&"bolt")
	await _wait(0.5)
	ok(w.marks == 3, "Bolt II: the Lash leaves 3 Marks (%d)" % w.marks)
	var kn: Vector3 = side.get("_knock")
	ok(kn.dot(w.global_position - side.global_position) > 0.5, "Bolt II: the Lash rune drags a foe beside it in (%s)" % kn.snapped(Vector3.ONE * 0.1))
	_clear_foes()
	_setp({"bolt": 3})
	var a := _foe(6.0)
	var b2 := _foe(10.0)
	await _aim_at(b2)
	bolt.set("_chain", 0)
	_cast(&"bolt")
	await _wait(0.6)
	ok(a.hp < 60.0 and b2.hp < 60.0, "Bolt III Through: one bolt passes through two foes (%.1f, %.1f)" % [a.hp, b2.hp])
	_clear_foes()
	await get_tree().process_frame


func _s_lance() -> void:
	print("-- Ember Lance ranks")
	_setp({"lance": 1})
	var w: Enemy = _foe(9.0)
	await _aim_at(w)
	var lance: Skill = book.slots[1]
	book.last_overcharge = 0.05
	_cast(&"lance", 1.0)
	await _wait(0.7)
	ok(int(lance.get("perfects")) == 1 and w.hp <= 60.0 - SkillLance.DMG_FULL * 1.3 + 0.01, "Lance I: a Perfect throw hits 30%% harder (hp %.2f)" % w.hp)
	ok(absf(lance.max_charge - 0.675) < 0.01, "Lance I: charges in %.3f s" % lance.max_charge)
	book.last_overcharge = 0.6
	w.hp = 60.0
	w.set("_broken_t", 0.0)              # r31: the Perfect throw staggered it (Broken x1.3): measure clean
	_cast(&"lance", 1.0)
	await _wait(0.7)
	ok(int(lance.get("perfects")) == 1 and w.hp > 60.0 - SkillLance.DMG_FULL * 1.3, "Lance I: held too long is not Perfect (hp %.2f)" % w.hp)
	_setp({"lance": 2})
	w.hp = 60.0
	_cast(&"lance", 0.0)
	await _wait(0.4)
	ok(get_tree().current_scene.find_child("EmberCinders", true, false) != null, "Lance II: the burst throws cinders")
	await _wait(0.6)
	ok(w.hp <= 60.0 - 2.5 + 0.01, "Lance II: a tap hits for 2.5 (hp %.2f)" % w.hp)
	_setp({"lance": 3})
	w.hp = 60.0
	book.last_overcharge = 0.5
	_cast(&"lance", 1.0)
	await _wait(0.9)
	ok(get_tree().current_scene.find_child("CinderScar", true, false) != null, "Lance III: a full charge leaves a Cinder Scar")
	_clear_foes()
	await get_tree().process_frame


func _s_nova() -> void:
	print("-- Umbral Nova ranks")
	_setp({"nova": 1})
	var w: Enemy = _foe(4.0)
	_cast(&"nova")
	var after_ring := w.hp
	await _wait(0.75)
	ok(after_ring <= 59.01 and w.hp <= after_ring - 0.49, "Nova I: the ring (%.1f) and its echo (%.1f)" % [after_ring, w.hp])
	_setp({"nova": 2})
	w.hp = 60.0
	w.marks = 3
	p.wounds = 30.0
	_cast(&"nova")
	p.wounds = 30.0
	await _wait(0.6)
	ok(p.wounds <= 30.0 - 6.0 + 1.6, "Nova II: three detonated Marks stream home, 6 Wounds mended (%.1f)" % p.wounds)
	ok(absf(book.slots[2].cooldown - 5.5) < 0.01, "Nova II: 5.5 s recovery")
	_clear_foes()
	await get_tree().process_frame


func _s_ward() -> void:
	print("-- Lantern Ward ranks")
	_setp({"ward": 2})
	var w: Enemy = _foe(6.4, 0.0, 60.0, true)
	_cast(&"ward")
	var ward := get_tree().get_first_node_in_group(&"lantern_ward") as Node3D
	var aura: Node = null
	if ward:
		for c in ward.get_children():
			if c.get("pulse") != null:
				aura = c
	ok(aura != null and bool(aura.get("pulse")) and bool(aura.get("kindred")), "Ward I + II: the aura pulses and kindles")
	await _wait(2.3)
	ok(aura != null and int(aura.get("pulses")) >= 1, "Ward I: it pulsed (%d)" % (int(aura.get("pulses")) if aura else -1))
	ok(book.boost_until > Time.get_ticks_msec() * 0.001, "Ward II: standing in its light speeds the other spells")
	book._cd.fill(2.0)
	await _wait(0.5)
	ok(book.cooldown_left(0) < 2.0 - 0.5 * 1.2 and book.cooldown_left(3) > 2.0 - 0.5 * 1.1, "Ward II: other slots recover 30%% faster, the ward itself does not (%.2f / %.2f)" % [book.cooldown_left(0), book.cooldown_left(3)])
	if ward:
		ward.queue_free()
	_clear_foes()
	await get_tree().process_frame


func _s_step() -> void:
	print("-- Rift Step ranks")
	await _place()
	_setp({"step": 2})
	var w: Enemy = _foe(9.0)
	p.set_view(0.94, -0.08)
	await get_tree().physics_frame
	_cast(&"step")
	await _wait(0.2)
	ok(w.hp < 60.0, "Step I: the arrival shock hits a foe within 2.5 m (hp %.1f)" % w.hp)
	ok(bool(book.slots[0].call("primed", book)), "Step II: the next bolt is primed as a Lash")
	await _aim_at(w)
	w.marks = 0
	_cast(&"bolt")
	await _wait(0.4)
	ok(int(Combo.count.get("SLIP LASH", 0)) == 1 and w.marks >= 2, "Step II: SLIP LASH (marks %d)" % w.marks)
	_clear_foes()
	await get_tree().process_frame


func _s_tether() -> void:
	print("-- Rift Tether")
	await _place()
	_setp({"tether": 0}, {"loadout": ["tether", "well", "familiar", "step"]})
	ok(book.slots[1].id == &"tether" and book.slots[2].id == &"well" and book.slots[3].id == &"familiar", "the three learned spells on the bar")
	var w: Enemy = _foe(11.0, 0.0, 60.0, true)
	await _aim_at(w)
	ok(_cast(&"tether"), "Rift Tether casts")
	ok(absf(book.cooldown_left(1) - 6.0) < 0.1, "Tether recovery 6 s (%.2f)" % book.cooldown_left(1))
	await _wait(0.8)
	var d := Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length()
	ok(d < 4.5 and w.marks >= 1 and w.hp < 60.0, "the foe is dragged in (%.1f m), Marked and hurt" % d)
	_clear_foes()
	p.set_view(0.94 + PI, 0.4)
	await get_tree().physics_frame
	_cast(&"tether")
	await get_tree().process_frame
	await get_tree().process_frame
	ok(book.cooldown_left(1) <= 1.05, "a miss costs only a second (%.2f)" % book.cooldown_left(1))
	await _place()
	_setp({"tether": 3})
	w = _foe(10.0, 0.0, 60.0, true)
	var w2 := _foe(11.5, 2.5, 60.0, true)
	w.add_mark(2)
	await _aim_at(w)
	_cast(&"tether")
	ok(int(book.slots[1].get("hooked")) == 2, "Tether II: the chain forks to a second foe")
	await _wait(1.3)
	ok(int(Combo.count.get("REEL", 0)) >= 1, "Tether III: REEL bursts the Marks it dragged in")
	d = Vector2(w2.global_position.x - p.global_position.x, w2.global_position.z - p.global_position.z).length()
	ok(d < 5.0, "the forked foe was dragged too (%.1f m)" % d)
	_clear_foes()
	await get_tree().process_frame


func _s_well() -> void:
	print("-- Umbral Well")
	await _place()
	_setp({"well": 0}, {"loadout": ["lance", "well", "familiar", "step"]})
	var in1 := _foe(9.0, 2.5, 60.0, true)
	var in2 := _foe(10.0, -2.0, 60.0, true)
	await _aim_at(in1)
	var cam := get_viewport().get_camera_3d()
	var feet := in1.global_position - cam.global_position
	p.set_view(p.get("_yaw"), atan2(feet.y, Vector2(feet.x, feet.z).length()))
	for i in 3:
		await get_tree().process_frame
	await get_tree().physics_frame
	var r0 := in1.global_position
	ok(_cast(&"well"), "Umbral Well casts")
	var well: Node3D = book.slots[2].get("last")
	ok(well != null and float(book.slots[2].call("active", book)) > 0.5, "an open well (the hotbar shows it working)")
	var c0 := well.global_position if well else Vector3.ZERO
	await _wait(1.6)
	var dd0 := Vector2(r0.x - c0.x, r0.z - c0.z).length()
	var dd1 := Vector2(in1.global_position.x - c0.x, in1.global_position.z - c0.z).length()
	ok(dd1 < maxf(dd0 - 0.4, 1.2) and in1.marks >= 1, "it drags a foe toward its heart (%.1f -> %.1f m) and Marks it" % [dd0, dd1])
	# a Lance bursting over the well (the bolt's own burst path, placed: the throw itself is
	# covered in the Lance section and its flight depends on whatever stands in the way)
	var pool := get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	var lb := pool.take()
	lb.global_position = (well.global_position if well else in2.global_position) + Vector3.UP * 0.4
	lb.arm_with({"heavy": true, "dmg": 2.0, "blast": 3.0, "speed": 18.0})
	lb.explode(lb.global_position)
	await _wait(0.8)
	ok(well != null and is_instance_valid(well) and bool(well.get("burning")), "a Lance over the well lights a MAELSTROM (%d)" % int(Combo.count.get("MAELSTROM", 0)))
	await _wait(2.6)
	ok(well == null or not is_instance_valid(well) or bool(well.get("_done")), "the well collapses")
	ok(in1.hp < 57.0, "what it held was burned and hurt by the collapse (hp %.1f)" % in1.hp)
	_clear_foes()
	await get_tree().process_frame


func _s_shade() -> void:
	print("-- Bound Shade")
	await _place()
	_setp({"familiar": 2})
	var w: Enemy = _foe(8.0)
	await _aim_at(w)
	ok(_cast(&"familiar"), "Bound Shade casts")
	var shades: Array = book.slots[3].get("bound")
	ok(shades.size() == 2, "Shade II: two are bound")
	await _wait(1.6)
	var darts := 0
	for s: Node in shades:
		darts += int(s.get("darts"))
	ok(darts >= 2 and w.marks >= 1 and w.hp < 60.0, "they dart at the foe (%d darts, hp %.1f, marks %d)" % [darts, w.hp, w.marks])
	_setp({"familiar": 3})
	_cast(&"familiar")
	shades = book.slots[3].get("bound")
	for s: Node in shades:
		s.set("life", 0.3)
	w.marks = 3
	var before := w.hp
	await _wait(0.9)
	ok(w.hp < before - 2.0 and w.marks <= 1, "Shade III: Last Breath dives and detonates (hp %.1f -> %.1f)" % [before, w.hp])
	_clear_foes()
	await get_tree().process_frame


func _s_cores() -> void:
	print("-- staff cores")
	_setp({}, {"loadout": ["lance", "nova", "ward", "step"]})
	p.global_position = fire.spawn_point()
	for i in 4:
		await get_tree().physics_frame
	Travel.give("relic_fragment", 4, false)
	ok(String(k.call("forge", "core_prism", false)) != "", "forging needs a fire")
	ok(String(k.call("forge", "core_prism", true)) == "" and Travel.count("core_prism") == 1 and Travel.count("relic_fragment") == 2, "Prism Core forged (2 fragments)")
	ok(DB.core_of(Travel.system_state("progression")) == "core_prism", "and set in the orb")
	ok(String(k.call("forge", "core_lodestar", true)) == "" and Travel.count("relic_fragment") == 0, "Lodestar Core forged")
	ok(String(k.call("forge", "core_cinder", true)).contains("lies in"), "the Cinder Core is found, not forged")
	await _place()
	_setp({"bolt": 0}, {"core": "core_prism"})
	var f0 := _foe(12.0)
	var f1 := _foe(12.0, -1.9)
	var f2 := _foe(12.0, 1.9)
	await _aim_at(f0)
	book.slots[0].set("_chain", 0)
	_cast(&"bolt")
	await _wait(0.7)
	var split_hits := 0
	for e: Enemy in [f0, f1, f2]:
		if e.hp < 60.0:
			split_hits += 1
	ok(split_hits >= 2, "Prism: one bolt splits into a fan (%d of 3 foes hit)" % split_hits)
	_clear_foes()
	_setp({}, {"core": "core_lodestar"})
	f0 = _foe(9.0)
	f1 = _foe(9.5, 4.0)
	f2 = _foe(10.0, -3.0)
	await _aim_at(f0)
	book.slots[0].set("_chain", 0)
	_cast(&"bolt")
	await _wait(1.0)
	var leap_hits := 0
	for e: Enemy in [f0, f1, f2]:
		if e.hp < 60.0:
			leap_hits += 1
	ok(leap_hits == 3, "Lodestar: one bolt leaps through all three (%d)" % leap_hits)
	_clear_foes()
	Travel.give("core_cinder", 1, false)
	ok(String(k.call("set_core", "core_cinder", true)) == "", "set the Cinder Core")
	var w: Enemy = _foe(9.0)
	await _aim_at(w)
	book.slots[0].set("_chain", 0)
	_cast(&"bolt")
	await _wait(0.5)
	ok(Afflict.is_burning(w), "Cinder: the bolt sets the foe burning")
	var burnt := w.hp
	await _wait(1.2)
	ok(w.hp < burnt - 0.5, "and it burns (%.1f -> %.1f)" % [burnt, w.hp])
	_clear_foes()
	Travel.give("core_rime", 1, false)
	k.call("set_core", "core_rime", true)
	w = _foe(9.0)
	await _aim_at(w)
	for i in 3:
		book.slots[0].set("_chain", 0)
		_cast(&"bolt")
		await _wait(0.35)
	ok(Afflict.is_frozen(w), "Rime: the third chill freezes")
	var frozen_hp := w.hp
	_cast(&"lance", 0.0)
	await _wait(0.6)
	ok(int(Combo.count.get("SHATTER", 0)) == 1 and w.hp <= frozen_hp - 4.0 + 0.01 and not Afflict.is_frozen(w), "the Lance SHATTERs it: double damage (%.1f -> %.1f)" % [frozen_hp, w.hp])
	ok(String(k.call("set_core", "", true)) == "" and DB.core_of(Travel.system_state("progression")) == "", "the Hollow Core goes back in")
	_clear_foes()
	await get_tree().process_frame


func _s_ui() -> void:
	print("-- the Kindling's pages")
	g.call("open_menu", true)
	await get_tree().process_frame
	for t in 7:
		g.call("show_tab", t)
		var cards: Array = g.get("_cards")
		for i in cards.size():
			g.set("_sel", i)
			g.call("_show")
		await get_tree().process_frame
	ok(int(g.get("_tab")) == 6 and (g.get("_cards") as Array).size() >= 7 + 4, "every page builds and every card shows its detail")
	g.call("close_menu")
	await get_tree().process_frame
	ok(not get_tree().paused, "the Kindling closes")
	ok(Combo.count.size() >= 6, "combos seen this run: %s" % str(Combo.count.keys()))
	await get_tree().process_frame


func _fire() -> Brazier:
	var best: Brazier = null
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier:
			if best == null or String(n.name) == "Sanctuary":
				best = n
	return best
