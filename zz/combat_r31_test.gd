extends Node
## r31 combat and traversal (the Enshrouded pass), in the Realm:
##   HOME=<scratch>/home godot --headless --path . res://zz/combat_r31_test.tscn
## Breath (costs, the hunted sprint, winded), the staff arts (contextual close strike, the chain and
## its finisher, the heavy, guard: parry / block / break), the perfect dodge and its riposte, the
## close-range and locked-on bolt aim, the cloak-glide (sink, Breath, updraft, no fall hurt), fall
## Gloom, the Tether line to an anchor, and the hitstop always giving time back.
## Never writes the save (Travel._busy all run). Ends: COMBAT31 PASS  /  COMBAT31 FAIL n

const Stamina := preload("res://core/player/stamina.gd")
const StaffArts := preload("res://core/player/staff_arts.gd")
const GrappleAnchor := preload("res://core/player/grapple_anchor.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const YAW := 0.94

var fails := 0
var main: Node
var p: Player
var arts: Node
var st: Node
var _foes: Array = []
var _spot_cache := Vector3.INF


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
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if main.has_meta("realm_done"):
			break
	for i in 30:
		await get_tree().physics_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null or p.arts() == null or p.stamina() == null:
		ok(false, "player with StaffArts and Stamina came up")
	else:
		arts = p.arts()
		if p.has_method("combat") and p.combat() != null:
			p.combat().set("crit_chance", 0.0)   # r33: exact strike numbers (no crits)
		st = p.stamina()
		var enc := main.find_child("Encounters", true, false)
		if enc:
			enc.process_mode = Node.PROCESS_MODE_DISABLED
		_clear(true)
		p.set("_shade_lock", 9999.0)
		await _run()
	ok(is_equal_approx(Engine.time_scale, 1.0), "time scale back to 1 at the end (%.2f)" % Engine.time_scale)
	print("COMBAT31 %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	Travel._busy = true
	get_tree().quit(0 if fails == 0 else 1)


func _run() -> void:
	await _s_breath()
	await _s_strikes()
	await _s_aim()
	await _s_guard()
	await _s_dodge()
	await _s_glide()
	await _s_fall()
	await _s_grapple()


# --- helpers -----------------------------------------------------------------------------------

func _fwd() -> Vector3:
	return Vector3(-sin(YAW), 0.0, -cos(YAW))


func _clear(all := false) -> void:
	for e in (get_tree().get_nodes_in_group(Groups.ENEMY) if all else _foes):
		if is_instance_valid(e):
			(e as Node).queue_free()
	_foes.clear()


func _spot() -> Vector3:
	if _spot_cache != Vector3.INF:
		return _spot_cache
	var space := p.get_world_3d().direct_space_state
	var right := _fwd().cross(Vector3.UP)
	for z in range(60, -60, -8):
		for x in range(-90, 90, 8):
			if x > -34 and x < 34 and z < -8:
				continue
			var y0 := RealmLayout.ground(space, x, z)
			var good := not RealmLand.in_water(x, z)
			for i in 9:
				if not good:
					break
				for sd: float in [-4.0, 0.0, 4.0]:
					var q := Vector3(x, 0.0, z) + _fwd() * float(i) * 2.0 + right * sd
					if LightGrid.repel(q, 2.0) != Vector3.ZERO or absf(RealmLayout.ground(space, q.x, q.z) - y0) > 0.6 or RealmLand.in_water(q.x, q.z):
						good = false
						break
			if good:
				_spot_cache = Vector3(x, y0, z)
				print("  test spot ", _spot_cache)
				return _spot_cache
	_spot_cache = Vector3(8.0, RealmLayout.ground(space, 8.0, 48.0), 48.0)
	return _spot_cache


func _place() -> void:
	_clear()
	arts.call("cancel")
	p.teleport(_spot() + Vector3.UP * 0.3)
	p.set_view(YAW, -0.08)
	p.gloom = 0.0; p.wounds = 0.0
	st.call("refill")
	p.set("_riposte_ready", false)
	p.set("_riposte_cd", 0.0)
	p.set("_roll_cd", 0.0)
	for i in 8:
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


# --- sections ----------------------------------------------------------------------------------

func _s_breath() -> void:
	print("-- Breath")
	await _place()
	ok(is_equal_approx(float(st.call("ratio")), 1.0), "starts full")
	var b0: float = st.get("breath")
	ok(p.call("_try_dodge", _fwd()), "a roll goes off")
	ok(absf(b0 - float(st.get("breath")) - Stamina.ROLL) < 0.5, "a roll costs %d Breath" % int(Stamina.ROLL))
	await _secs(1.4)
	ok(float(st.get("breath")) > b0 - Stamina.ROLL + 10.0, "Breath comes back after a pause (%.0f)" % float(st.get("breath")))
	st.set("breath", 6.0)
	p.set("_roll_cd", 0.0)
	await _frames(2)
	ok(not p.call("_try_dodge", _fwd()), "no roll on a sliver of Breath")
	st.call("drain", 50.0)
	ok(bool(st.get("winded")), "run dry: winded")
	ok(not bool(st.call("can", 1.0)), "winded: nothing may start")
	st.call("refill")
	# hunted sprint: only with a foe awake nearby
	await _place()
	p.debug_drive(_fwd(), true)
	await _secs(0.8)
	ok(float(st.get("breath")) > 99.0, "sprinting with no foe awake is free (%.1f)" % float(st.get("breath")))
	var w := _foe(9.0)
	w._state = Enemy.CHASE
	await _secs(1.0)
	var b := float(st.get("breath"))
	ok(b < 96.0 and b > 80.0, "sprinting with a foe awake spends Breath (%.1f)" % b)
	p.debug_drive(Vector3.ZERO)
	_clear()


func _s_strikes() -> void:
	print("-- staff arts: strikes")
	await _place()
	var far := _foe(6.0)
	await _frames(2)
	ok(not p.melee_claims_primary(), "a foe 6 m off: the trigger stays a bolt")
	_clear()
	var w := _foe(2.0, 0.3)
	await _frames(2)
	ok(p.melee_claims_primary(), "a foe 2 m ahead: the trigger is the staff")
	var hp0 := w.hp
	var b0: float = st.get("breath")
	ok(arts.call("request_strike", false), "a close strike starts")
	ok(p.skills_locked(), "no spells while the staff swings")
	await _secs(0.3)
	ok(absf(hp0 - w.hp - 1.2) < 0.05, "the sweep lands 1.2 (%.2f)" % (hp0 - w.hp))
	ok(w.marks >= 1, "and leaves an Umbral Mark")
	ok(absf(b0 - float(st.get("breath")) - Stamina.STRIKE) < 2.0, "a strike costs Breath")
	ok(Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length() < 1.9, "the strike stepped in to it")
	# the chain: buffered presses carry it through backhand and finisher
	w.hp = 60.0
	w.marks = 0
	await _secs(0.3)
	var strikes0: int = arts.get("strikes_landed")
	for i in 3:
		arts.call("request_strike", true)
		var t := 0
		while int(arts.call("phase")) >= 0 and t < 120:
			if t > 10:
				arts.call("request_strike", true)
			await get_tree().physics_frame
			t += 1
	await _secs(0.3)
	ok(int(arts.get("strikes_landed")) - strikes0 >= 3, "three strikes chained (%d)" % (int(arts.get("strikes_landed")) - strikes0))
	ok(60.0 - w.hp >= 1.2 + 1.2 + 2.3 - 0.05, "sweep + backhand + finisher (%.2f)" % (60.0 - w.hp))
	ok(is_equal_approx(Engine.time_scale, 1.0), "hitstop gave the time back")
	# heavy
	w.hp = 60.0
	st.call("refill")
	await _secs(0.4)
	w._state = Enemy.CHASE
	var e_state0 := w._state
	ok(arts.call("heavy", 1.0), "a full heavy goes off")
	await _secs(0.5)
	ok(60.0 - w.hp >= 6.4, "a full heavy hits 6.5 (%.2f)" % (60.0 - w.hp))
	ok(w._state == Enemy.RECOVER and e_state0 != Enemy.RECOVER, "and staggers it")
	_clear()
	far = null


func _s_aim() -> void:
	print("-- aim up close and locked on")
	await _place()
	var book := p.skills()
	# a foe 1.6 m off, 25 degrees off the crosshair: the close assist still finds it
	var w := _foe(1.6, 0.0)
	p.set_view(YAW + deg_to_rad(25.0), -0.08)
	await _frames(4)
	var hp0 := w.hp
	book._cd.fill(0.0)
	ok(book.try_cast(book.slot_of(&"bolt"), 0.0, false), "a bolt fires point-blank")
	await _secs(0.4)
	ok(w.hp < hp0, "the point-blank bolt hits a foe 25 deg off the crosshair (%.2f)" % (hp0 - w.hp))
	_clear()
	# locked on: the bolt goes to the target even with the view swung off it
	var t := _foe(7.0, 2.0)
	p.call("_set_lock", t)
	p.set_view(YAW - deg_to_rad(30.0), -0.08)
	p.set("_lock", t)
	var hp1 := t.hp
	book._cd.fill(0.0)
	# _lock_view swings the camera on rendered frames: fire at once, before it settles
	book.try_cast(book.slot_of(&"bolt"), 0.0, false)
	await _secs(0.6)
	ok(t.hp < hp1, "a locked-on bolt goes to the target (%.2f)" % (hp1 - t.hp))
	p.call("_release_lock")
	_clear()


func _s_guard() -> void:
	print("-- guard: parry, block, break")
	await _place()
	var w := _foe(2.0)
	await _frames(2)
	arts.set("_last_guard", -10.0)
	p.skills().using_pad = true                  # headless has no captured mouse: input counts as a pad's
	Input.action_press("guard")
	await _frames(1)
	ok(bool(arts.call("guarding")), "holding guard raises the staff")
	var wait := 0
	while not p.is_evading() and wait < 20:      # sheet 38: the window opens when the staff is across the body
		await _frames(1)
		wait += 1
	ok(p.is_evading(), "a fresh guard is a parry window (open after %d frames)" % wait)
	var b0: float = st.get("breath")
	p.on_evaded(w)
	ok(int(arts.get("parries")) == 1, "the blow is parried")
	ok(w._state == Enemy.RECOVER, "the attacker reels")
	ok(bool(p.get("_riposte_ready")), "a parry arms a riposte")
	ok(float(st.get("breath")) >= b0, "a parry costs no Breath")
	await _secs(0.3)
	ok(not p.is_evading(), "past the window the guard only blocks")
	p.set("_hurt_grace_until", 0.0)
	var g0 := p.wounds
	p.take_wound(20.0, w.global_position)
	ok(absf(p.wounds - g0 - 5.0) < 0.2, "a block lets a quarter through (%.1f)" % (p.wounds - g0))
	ok(int(arts.get("blocks")) == 1, "counted as a block")
	ok(float(st.get("breath")) < b0 - 20.0, "a block costs Breath (%.0f)" % float(st.get("breath")))
	p.set("_hurt_grace_until", 0.0)
	g0 = p.wounds
	p.take_wound(20.0, p.global_position - _fwd() * 3.0)
	ok(absf(p.wounds - g0 - 20.0) < 0.2, "a blow from behind is not blocked")
	Input.action_release("guard")
	await _frames(2)
	ok(not bool(arts.call("guarding")), "letting go lowers the guard")
	# the riposte from the parry: the next strike hits for x2.5 and staggers
	w._state = Enemy.CHASE
	w.set("_stagger_cd", 0.0)
	arts.call("cancel")
	st.call("refill")
	w.hp = 60.0
	arts.call("request_strike", true)
	await _secs(0.35)
	ok(60.0 - w.hp >= 1.2 * StaffArts.RIPOSTE_MULT - 0.05, "the riposte strike hits x%.1f (%.2f)" % [StaffArts.RIPOSTE_MULT, 60.0 - w.hp])
	# guard break
	await _secs(0.4)
	Input.action_press("guard")
	await _secs(0.3)
	ok(bool(arts.call("guarding")), "guard raised again")
	st.set("breath", 8.0)
	p.set("_hurt_grace_until", 0.0)
	g0 = p.wounds
	p.take_wound(20.0, w.global_position)
	ok(not bool(arts.call("guarding")), "a block with no Breath breaks the guard")
	ok(absf(p.wounds - g0 - 20.0) < 0.2, "and the blow lands in full")
	Input.action_release("guard")
	p.skills().using_pad = false
	arts.call("cancel")
	st.call("refill")
	_clear()


func _s_dodge() -> void:
	print("-- perfect dodge")
	await _place()
	var w := _foe(3.0)
	await _frames(2)
	p.set("_roll_cd", 0.0)
	ok(p.call("_try_dodge", _fwd().cross(Vector3.UP)), "a side roll")
	await _frames(5)
	var b0: float = st.get("breath")
	ok(p.is_evading(), "inside the roll's i-frames")
	p.on_evaded(w)
	ok(bool(p.get("_riposte_ready")), "a blow met in the roll's first instant: perfect dodge, riposte armed")
	ok(float(st.get("breath")) > b0 + 10.0, "a perfect dodge gives Breath back")
	await _secs(0.8)
	ok(is_equal_approx(Engine.time_scale, 1.0), "the perfect dodge's slow motion ends")
	# late in the roll: a plain evade
	p.set("_riposte_ready", false)
	p.set("_riposte_cd", 0.0)
	p.set("_roll_cd", 0.0)
	await _frames(2)
	p.call("_try_dodge", -_fwd().cross(Vector3.UP))
	await _secs(0.25)
	if p.is_evading():
		p.on_evaded(w)
	ok(not bool(p.get("_riposte_ready")), "a blow late in the roll is only evaded")
	_clear()


func _s_glide() -> void:
	print("-- cloak-glide")
	await _place()
	var at := _spot() + Vector3.UP * 22.0
	p.teleport(at)
	p.velocity = _fwd() * 4.0
	await _frames(3)
	p.set("_air_jumps_left", 0)
	ok(p.call("_can_glide"), "high in the air: the robe can open")
	p.call("_start_glide")
	var b0: float = st.get("breath")
	await _secs(1.2)
	ok(p.is_gliding(), "gliding")
	ok(p.velocity.y > -3.0 and p.velocity.y < -1.5, "a slow sink (%.2f m/s)" % p.velocity.y)
	var hs := Vector2(p.velocity.x, p.velocity.z).length()
	ok(hs > 7.0, "carried forward (%.1f m/s)" % hs)
	ok(float(st.get("breath")) < b0 - 6.0, "the glide spends Breath (%.0f)" % float(st.get("breath")))
	# an updraft lifts it
	var up := Node3D.new()
	up.add_to_group("updraft")
	main.add_child(up)
	up.global_position = p.global_position + Vector3.DOWN * 4.0
	up.set_meta("radius", 50.0)
	await _secs(0.6)
	ok(p.velocity.y > 0.5, "an updraft lifts the glide (%.2f)" % p.velocity.y)
	up.queue_free()
	st.call("refill")
	var t := 0
	while not p.is_grounded() and t < 60 * 20:
		st.set("breath", 100.0)
		await get_tree().physics_frame
		t += 1
	await _frames(3)
	ok(p.is_grounded() and not p.is_gliding(), "glided to the ground (%.1f s)" % (t / 60.0))
	ok(float(p.get("falls_hurt")) == 0.0, "a glide lands without a jar")


func _s_fall() -> void:
	print("-- fall Gloom")
	await _place()
	p.teleport(_spot() + Vector3.UP * 14.0)
	p.velocity = Vector3.ZERO
	var t := 0
	await _frames(2)
	while not p.is_grounded() and t < 600:
		await get_tree().physics_frame
		t += 1
	await _frames(2)
	var g := float(p.get("falls_hurt"))
	ok(g > 4.0 and g < 31.0, "a 14 m drop wounds you (%.1f)" % g)
	p.wounds = p.wounds_max - 10.0
	p.teleport(_spot() + Vector3.UP * 14.0)
	await _frames(2)
	t = 0
	while not p.is_grounded() and t < 600:
		await get_tree().physics_frame
		t += 1
	await _frames(2)
	ok(p.wounds < p.wounds_max and not bool(p.get("_hollowing")), "a fall never wounds you to the end (%.1f)" % p.wounds)
	p.gloom = 0.0; p.wounds = 0.0


func _s_grapple() -> void:
	print("-- Tether line")
	await _place()
	var g := p.grapple()
	var at := p.global_position + _fwd() * 11.0 + Vector3.UP * 7.0
	var a := GrappleAnchor.make(main, at)
	var cam := get_viewport().get_camera_3d()
	var to := at - (cam.global_position if cam else p.global_position + Vector3.UP * 1.6)
	p.set_view(atan2(-to.x, -to.z), clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.9, 0.55))
	for i in 4:
		await get_tree().process_frame
	await _secs(0.25)
	ok(g.get("target") == a, "the anchor under the crosshair is marked")
	var b0: float = st.get("breath")
	ok(g.call("try_fire"), "the Tether line bites")
	ok(absf(b0 - float(st.get("breath")) - Stamina.GRAPPLE) < 1.0, "it costs Breath")
	var t := 0
	var closest := 99.0
	while bool(g.call("pulling")) and t < 240:
		closest = minf(closest, p.global_position.distance_to(at))
		await get_tree().physics_frame
		t += 1
	ok(t < 240, "the haul ends (%.2f s)" % (t / 60.0))
	ok(closest < 2.4, "hauled up to the anchor (%.2f m)" % closest)
	ok(p.velocity.y > 3.0, "and popped up past it (%.1f m/s)" % p.velocity.y)
	a.queue_free()
	await _secs(2.0)
