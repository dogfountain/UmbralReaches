extends Node
## r33 combat (the WoW-feel pass), in the Realm:
##   HOME=<scratch>/home godot --headless --path . res://zz/combat_r33_test.tscn
## The cast lock (no global cooldown, no queue), cast times (finish, moved, pushback, interrupt and its
## lockout), crits and the damage feed, the Rift Surge proc (a crit, a parry) and what it empowers,
## status apply / refresh / stack / expire (Resonance, Ember Scar and its ticks), the Resonance
## spend (Gloom back, Sundered), and Tab-style target cycling with the remembered target.
## Never writes the save (Travel._busy all run). Ends: COMBAT33 PASS  /  COMBAT33 FAIL n

const RealmLand := preload("res://core/world/realm/realm_land.gd")
const CombatState := preload("res://core/skills/combat_state.gd")
const YAW := 0.94


class TSkill extends Skill:
	var n := 0

	func cast(_book: SkillBook, _charge: float) -> bool:
		n += 1
		return true


var fails := 0
var main: Node
var p: Player
var book: SkillBook
var cs: Node
var _foes: Array = []
var _events := {}               ## signal name -> Array of args
var _keep: Array[Skill] = []


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	main = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		if main.has_meta("realm_done"):
			break
	for i in 30:
		await get_tree().physics_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	book = p.skills() if p else null
	cs = p.combat() if p else null
	if p == null or book == null or cs == null:
		ok(false, "player with a SkillBook and CombatState came up")
	else:
		var enc := main.find_child("Encounters", true, false)
		if enc:
			enc.process_mode = Node.PROCESS_MODE_DISABLED
		p.set("_shade_lock", 9999.0)
		for sig: String in ["combat_damage", "status_changed", "proc_triggered", "cast_started", "cast_stopped", "spell_queued", "target_changed", "skill_cast"]:
			_events[sig] = []
			Events.connect(sig, _rec.bind(sig))
		_keep = book.slots.duplicate()
		_clear(true)
		await _place()
		await _s_gcd_queue()
		await _s_cast_time()
		await _s_status()
		await _s_crit_proc()
		await _s_spend()
		await _s_target()
		for i in _keep.size():
			book.set_slot(i, _keep[i])
	print("COMBAT33 %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	Travel._busy = true
	get_tree().quit(0 if fails == 0 else 1)


func _rec(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, sig := "") -> void:
	# bind() appends the name after the signal's own args: find it as the last String
	var args: Array = [a, b, c, d, e]
	var name := sig
	for k in range(args.size() - 1, -1, -1):
		if args[k] is String and _events.has(args[k]):
			name = args[k]
			args.resize(k)
			break
	if _events.has(name):
		(_events[name] as Array).append(args)


func _count(sig: String, first: Variant = null) -> int:
	var n := 0
	for a: Array in _events[sig]:
		if first == null or (a.size() > 0 and a[0] == first):
			n += 1
	return n


func _reset_events() -> void:
	for k: String in _events:
		(_events[k] as Array).clear()


# --- helpers -----------------------------------------------------------------------------------

func _fwd() -> Vector3:
	return Vector3(-sin(YAW), 0.0, -cos(YAW))


func _spot() -> Vector3:
	var space := p.get_world_3d().direct_space_state
	var right := _fwd().cross(Vector3.UP)
	for z in range(60, -60, -8):
		for x in range(-90, 90, 8):
			if x > -34 and x < 34 and z < -8:
				continue
			var y0 := RealmLayout.ground(space, float(x), float(z))
			var good := not RealmLand.in_water(float(x), float(z))
			for i in 9:
				if not good:
					break
				for sd: float in [-4.0, 0.0, 4.0]:
					var q := Vector3(x, 0.0, z) + _fwd() * float(i) * 2.0 + right * sd
					if LightGrid.repel(q, 2.0) != Vector3.ZERO or absf(RealmLayout.ground(space, q.x, q.z) - y0) > 0.6 or RealmLand.in_water(q.x, q.z):
						good = false
						break
			if good:
				return Vector3(x, y0, z)
	return Vector3(8.0, RealmLayout.ground(space, 8.0, 48.0), 48.0)


var _spot_c := Vector3.INF


func _place() -> void:
	if _spot_c == Vector3.INF:
		_spot_c = _spot()
	p.teleport(_spot_c + Vector3.UP * 0.3)
	p.set_view(YAW, -0.08)
	p.gloom = 0.0; p.wounds = 0.0
	p.debug_drive(Vector3.ZERO)
	for i in 6:
		await get_tree().physics_frame


func _foe(ahead: float, side := 0.0, hp := 60.0) -> Enemy:
	var w := Wretch.new()
	main.add_child(w)
	var right := _fwd().cross(Vector3.UP)
	var at := p.global_position + _fwd() * ahead + right * side
	at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.05
	w.global_position = at
	w.max_hp = int(hp)
	w.hp = hp
	w.set("strike_gloom", 0.0)
	w.set_physics_process(false)
	_foes.append(w)
	return w


func _clear(all := false) -> void:
	for e in (get_tree().get_nodes_in_group(Groups.ENEMY) if all else _foes):
		if is_instance_valid(e):
			(e as Node).queue_free()
	_foes.clear()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func _fresh() -> void:
	book._cd.fill(0.0)
	book._lock = 0.0
	cs.clear(p)
	cs.crit_chance = 0.0
	p.gloom = 0.0; p.wounds = 0.0


func _tskill(id: StringName, _unused := 0.0, cast_time := 0.0, cd := 1.0) -> TSkill:
	var s := TSkill.new()
	s.id = id
	s.title = String(id)
	s.cast_time = cast_time
	s.cooldown = cd
	return s


# --- sections ----------------------------------------------------------------------------------

func _s_gcd_queue() -> void:
	print("-- no global cooldown, no queue; a short cast lock a roll cancels")
	_fresh()
	var a := _tskill(&"t_a", 0.0, 0.0, 4.0)
	var b := _tskill(&"t_b", 0.0, 0.0, 4.0)
	book.set_slot(2, a)
	book.set_slot(3, b)
	_reset_events()
	ok(book.press(2) and a.n == 1, "a press casts at once when free")
	ok(book.gcd_left() == 0.0 and not book.on_gcd(2), "there is no shared global cooldown")
	ok(absf(book.cooldown_left(2) - 4.0) < 0.05 and book.cooldown_total(2) == 4.0, "only its own recovery (%.2f / %.2f)" % [book.cooldown_left(2), book.cooldown_total(2)])
	ok(not book.press(3) and b.n == 0, "a second spell inside the cast lock is refused, not queued")
	ok(book.queued_slot() == -1 and _count("spell_queued", &"t_b") == 0, "nothing is queued")
	book.cancel_lock()
	ok(book.press(3) and b.n == 1, "a roll cancels the cast lock: the next spell goes off at once")
	await _ticks(int(ceil(SkillBook.LOCK * 60.0)) + 3)
	book._cd.fill(0.0)
	ok(book.press(2) and a.n == 2, "after the lock lapses the spell is free again (casts %d)" % a.n)
	_fresh()
	book._cd[2] = 0.2
	ok(not book.press(2) and book.queued_slot() == -1, "a press 0.2 s before its recovery ends is refused (no queue)")


func _s_cast_time() -> void:
	print("-- cast times, movement, pushback, interrupts")
	_fresh()
	var s := _tskill(&"t_cast", 0.5, 0.6, 3.0)
	book.set_slot(2, s)
	_reset_events()
	ok(book.press(2) and s.n == 0 and book.casting_slot() == 2, "a 0.6 s spell starts casting")
	var info := book.cast_info()
	ok(info.get("id") == &"t_cast" and info.get("kind") == &"cast" and absf(float(info.get("total", 0.0)) - 0.6) < 0.01, "cast_info for the cast bar: %s" % str(info))
	ok(_count("cast_started", &"t_cast") == 1 and true, "cast_started fired")
	ok(book.move_scale() < 0.5, "a rooted cast slows the walk (%.2f)" % book.move_scale())
	await _wait(0.75)
	ok(s.n == 1 and book.casting_slot() == -1 and book.cast_info().is_empty(), "it goes off when the cast completes")
	ok(_count("cast_stopped", &"t_cast") == 1 and (_events["cast_stopped"][0] as Array)[1] == &"done", "cast_stopped(done)")
	# moving cancels a rooted cast
	_fresh()
	_reset_events()
	book.press(2)
	await _ticks(16)
	p.debug_drive(_fwd())
	await _ticks(4)
	p.debug_drive(Vector3.ZERO)
	ok(book.casting_slot() == -1 and s.n == 1 and _count("cast_stopped", &"t_cast") == 1 and (_events["cast_stopped"][0] as Array)[1] == &"moved", "moving cancels a rooted cast (no cast, cast_stopped(moved))")
	ok(book.cooldown_left(2) <= 0.0, "a cancelled cast spends no recovery")
	await _place()
	# a light blow pushes it back, a hard one interrupts and locks the slot
	_fresh()
	_reset_events()
	book.press(2)
	await _ticks(20)
	var before := float(book.cast_info().get("t", 0.0))
	p.set("_hurt_grace_until", 0.0)
	p.take_wound(8.0, p.global_position + _fwd() * 2.0)
	var after := float(book.cast_info().get("t", 0.0))
	ok(book.casting_slot() == 2 and after < before - 0.2, "a light blow pushes the cast back (%.2f -> %.2f)" % [before, after])
	p.set("_hurt_grace_until", 0.0)
	p.take_wound(SkillBook.HARD_HIT + 5.0, p.global_position + _fwd() * 2.0)
	ok(book.casting_slot() == -1 and s.n == 1, "a hard blow interrupts it")
	ok(book.cooldown_left(2) >= SkillBook.LOCKOUT - 0.05 and book.cooldown_total(2) >= SkillBook.LOCKOUT - 0.05, "the slot is locked out (%.2f / %.2f)" % [book.cooldown_left(2), book.cooldown_total(2)])
	ok(cs.has(p, &"shaken") and _count("cast_stopped", &"t_cast") == 1 and (_events["cast_stopped"][0] as Array)[1] == &"interrupted", "the wanderer is Shaken; cast_stopped(interrupted)")
	p.gloom = 0.0; p.wounds = 0.0
	# a Rift Surge makes a cast instant
	_fresh()
	cs.proc_surge(&"parry")
	ok(book.slot_lit(2), "a Rift Surge lights a cast-time slot")
	ok(book.press(2) and s.n == 2 and book.casting_slot() == -1 and not cs.has(p, &"surge"), "and makes the cast instant, spending the Surge")


func _s_status() -> void:
	print("-- statuses: apply, refresh, stack, expire")
	_fresh()
	_reset_events()
	for i in 7:
		cs.build(1)
	ok(cs.stacks(p, &"resonance") == CombatState.RES_MAX, "Resonance stacks to its max %d (%d)" % [CombatState.RES_MAX, cs.stacks(p, &"resonance")])
	ok(absf(cs.time_left(p, &"resonance") - 8.0) < 0.05, "each stack refreshes it (%.2f s)" % cs.time_left(p, &"resonance"))
	var row: Array = cs.statuses_of(p)
	var found := {}
	for r: Dictionary in row:
		if r.id == &"resonance":
			found = r
	ok(not found.is_empty() and found.stacks == 5 and found.max_stacks == 5 and found.icon == &"resonance" and found.kind == &"buff" and found.name == "Resonance", "statuses_of lists it for the HUD: %s" % str(found))
	ok(_count("status_changed", p) == 7, "status_changed per apply (%d)" % _count("status_changed", p))
	await _ticks(30)
	ok(cs.time_left(p, &"resonance") < 7.6, "the timer runs down (%.2f)" % cs.time_left(p, &"resonance"))
	cs.apply(p, &"resonance", 1, 0.3)
	await _wait(0.45)
	ok(cs.stacks(p, &"resonance") == 0, "it expires")
	var last: Array = _events["status_changed"].back()
	ok(last[0] == p and last[1] == &"resonance" and last[2] == 0, "status_changed(stacks 0) on expiry")
	# a stacking debuff that ticks on a foe
	var w := _foe(6.0)
	await _ticks(2)
	for i in 4:
		cs.apply(w, &"ember_scar")
	ok(cs.stacks(w, &"ember_scar") == 3, "Ember Scar stacks to 3 on a foe")
	var hp0 := w.hp
	_reset_events()
	await _wait(1.15)
	ok(w.hp < hp0 - 0.7 and w.hp > hp0 - 0.8, "and burns 0.25 a stack a second (%.2f -> %.2f)" % [hp0, w.hp])
	ok(_count("combat_damage", w) >= 1 and (_events["combat_damage"][0] as Array)[3] == &"ember", "its ticks are in the damage feed (school ember)")
	var marked := false
	w.add_mark(2)
	for r: Dictionary in cs.statuses_of(w):
		if r.id == &"mark" and r.stacks == 2:
			marked = true
	ok(marked, "a foe's Umbral Marks show in its status row")
	_clear()


func _s_crit_proc() -> void:
	print("-- crits, the damage feed and Rift Surge")
	_fresh()
	var w := _foe(6.0)
	await _ticks(2)
	_reset_events()
	cs.crit_chance = 0.0
	var r: Dictionary = cs.deal(w, 1.0, &"umbral", p)
	ok(not r.crit and absf(float(r.amount) - 1.0) < 0.01, "a plain hit: 1.0, no crit")
	ok(_count("combat_damage", w) == 1, "combat_damage fired")
	var ev: Array = _events["combat_damage"][0]
	ok(ev[2] == false and ev[3] == &"umbral" and ev[4] is Vector3 and absf(float(ev[1]) - 1.0) < 0.01, "with amount, crit, school and position")
	ok(cs.target == w, "hitting a foe with no target makes it the target")
	w.queue_free()
	w = _foe(6.0)
	w.set("_stagger_cd", 999.0)                          # no stagger (a broken foe takes x1.3) muddies the numbers
	await _ticks(2)
	cs.crit_chance = 1.0
	cs.rng.seed = 33
	var procd := false
	for i in 30:
		cs.set("_surge_icd", 0.0)
		r = cs.deal(w, 1.0, &"umbral", p)
		if cs.has(p, &"surge"):
			procd = true
			break
	ok(bool(r.crit) and absf(float(r.amount) - CombatState.CRIT_MULT) < 0.01, "a crit hits for x%.1f (%.2f)" % [CombatState.CRIT_MULT, float(r.amount)])
	ok(procd and _count("proc_triggered", &"surge") >= 1, "a crit procs Rift Surge (proc_triggered)")
	var icd_hits := 0
	cs.consume(p, &"surge")
	for i in 10:
		cs.deal(w, 0.1, &"umbral", p)
		if cs.has(p, &"surge"):
			icd_hits += 1
	ok(icd_hits == 0, "not again inside its internal cooldown")
	cs.crit_chance = 0.0
	# a parry lights it too, and the next Lance throws at full charge on the press
	var lance := book.slot_of(&"lance")
	for i in _keep.size():
		book.set_slot(i, _keep[i])
	lance = book.slot_of(&"lance")
	if lance < 0:
		book.set_slot(1, SkillLance.new())
		lance = 1
	_fresh()
	p.call("_surge", &"parry")
	ok(cs.has(p, &"surge") and book.slot_lit(lance), "a parry lights Rift Surge; the Lance slot lights")
	await _aim(w)
	_reset_events()
	ok(book.press(lance) and book.charging_slot() == -1 and book.cooldown_left(lance) > 0.0, "the Lance throws on the press, no charge")
	ok(not cs.has(p, &"surge"), "the Surge is spent")
	ok(_count("skill_cast", &"lance") == 1, "skill_cast(lance)")
	_clear()


func _aim(e: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye: Vector3 = cam.global_position if cam else p.global_position + Vector3.UP * 1.6
	var to: Vector3 = e.global_position + Vector3.UP * 0.9 - eye
	p.set_view(atan2(-to.x, -to.z), clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.9, 0.5))
	for i in 3:
		await get_tree().process_frame
	await get_tree().physics_frame


func _s_spend() -> void:
	print("-- the Resonance spend")
	for i in _keep.size():
		book.set_slot(i, _keep[i])
	await _place()
	var nova := book.slot_of(&"nova")
	if nova < 0:
		book.set_slot(2, SkillNova.new())
		nova = 2
	_fresh()
	var w := _foe(3.0)
	await _ticks(2)
	for i in 4:
		cs.build(1)
	p.gloom = 50.0
	p.wounds = 50.0
	var cost := book.slots[nova].gloom_cost
	var hp0 := w.hp
	ok(book.try_cast(nova, 0.0, false), "Nova goes off with 4 Resonance")
	ok(cs.stacks(p, &"resonance") == 0, "and spends every stack")
	ok(absf(p.gloom - (50.0 + cost)) < 0.5 and absf(p.wounds - (50.0 - 4.0 * CombatState.RES_GLOOM)) < 0.5, "the cost goes on the Gloom; spending mends %.1f Wounds (%.1f)" % [4.0 * CombatState.RES_GLOOM, p.wounds])
	ok(cs.has(w, &"sundered") and w.hp < hp0 - 1.0 - 4.0 * CombatState.NOVA_BURST + 0.01, "the ring Sunders the foe and the resonant burst lands (%.2f -> %.2f)" % [hp0, w.hp])
	cs.crit_chance = 0.0
	var w2 := _foe(4.0, 1.5)
	w2.set("_stagger_cd", 999.0)
	await _ticks(2)
	cs.apply(w2, &"sundered")
	var r: Dictionary = cs.deal(w2, 1.0, &"umbral", p)
	ok(absf(float(r.amount) - (1.0 + CombatState.SUNDER_VULN)) < 0.01, "a Sundered foe takes +%d%% (%.2f)" % [int(CombatState.SUNDER_VULN * 100.0), float(r.amount)])
	p.gloom = 0.0; p.wounds = 0.0
	_clear()


func _s_target() -> void:
	print("-- target cycling")
	await _place()
	_clear(true)
	await _ticks(2)
	var a := _foe(5.0, 0.6)
	var b := _foe(9.0, -0.8)
	var c := _foe(13.0, 1.0)
	await _ticks(3)
	cs.set_target(null)
	_reset_events()
	ok(p.cycle_target() == a and p.current_target() == a and p.lock_target() == a, "the first press takes the nearest")
	ok(p.cycle_target() == b, "the next press the next nearest")
	ok(p.cycle_target() == c, "then the farthest")
	ok(p.cycle_target() == a, "and it wraps")
	ok(_count("target_changed") == 4, "target_changed each time (%d)" % _count("target_changed"))
	p.call("_release_lock")
	ok(p.lock_target() == null and p.current_target() == a, "letting the lock go keeps the target")
	p.call("_toggle_lock")
	ok(p.lock_target() == a, "locking again goes back to it")
	p.call("_release_lock")
	a.hp = 0.5
	cs.crit_chance = 0.0
	cs.deal(a, 1.0, &"umbral", p)
	await _ticks(40)
	ok(p.current_target() == null, "a dead target is forgotten (alive %s, hp %.2f)" % [a.is_alive() if is_instance_valid(a) else false, a.hp if is_instance_valid(a) else -1.0])
	_clear()
