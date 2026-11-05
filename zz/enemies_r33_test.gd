extends Node
## r33 enemies (WoW encounter design, adapted): leash and reset (evade home, immune, healed; the pack
## resets with it), pulls that take the whole camp, cast bars on casters and bosses (Enemy.cast_info,
## Events.enemy_cast_started / _ended, interrupts and the lockout), the HUD's read of a foe (name, rank,
## level, debuffs), boss mechanics firing on their telegraphs (Mandorla Flare's donut, Sap Mending
## healing unless interrupted, Raise the Faithful's adds, the soft enrage), and the named rares (spawn,
## map marker, loot).
## Run: SCRATCH=<dir> tools/run_tests.sh enemies_r33
const AT := Vector3(-24.0, 0.0, 60.0)     ## open ground outside every sanctuary light (as r31)
var p: Player
var main: Node
var fails := 0
var started := false
var _casts: Array = []
var _ends: Array = []


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(name: String, ok: bool, detail := "") -> void:
	print("ENEMY33 %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		fails += 1


func _physics_process(_d: float) -> void:
	if started:
		return
	if Engine.get_physics_frames() > 60 * 240:
		print("ENEMY33 FAIL timeout waiting for the world")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("summit_dressed") or main.find_child("Encounters", true, false) == null or main.find_child("Rares", true, false) == null:
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await _frames(int(s * 60.0))


func _ground(v: Vector3) -> Vector3:
	return Vector3(v.x, RealmLayout.ground(p.get_world_3d().direct_space_state, v.x, v.z), v.z)


func _put_player(at: Vector3) -> void:
	p.teleport(_ground(at) + Vector3.UP * 0.3)
	p.velocity = Vector3.ZERO
	p.gloom = 0.0


func _spawn(path: String, at: Vector3) -> Enemy:
	var e := (load(path) as GDScript).new() as Enemy
	main.add_child(e)
	e.global_position = _ground(at) + Vector3.UP * 0.1
	e.home = e.global_position
	e.wake()
	return e


func _clear() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()


func _zone_count(e: Enemy) -> int:
	var n := 0
	for m: Variant in e.get("_moves"):
		if is_instance_valid(m):
			n += 1
	return n


func _run() -> void:
	var enc := main.find_child("Encounters", true, false)
	enc.process_mode = Node.PROCESS_MODE_DISABLED
	var sp := main.find_child("EnemySpawner", true, false)
	if sp:
		sp.process_mode = Node.PROCESS_MODE_DISABLED
	var rares := main.find_child("Rares", true, false)
	rares.process_mode = Node.PROCESS_MODE_DISABLED       # the test spawns its rare itself
	Events.enemy_cast_started.connect(func(e: Node, n: String, t: float, i: bool) -> void: _casts.append([e, n, t, i]))
	Events.enemy_cast_ended.connect(func(e: Node, n: String, cut: bool) -> void: _ends.append([e, n, cut]))
	_clear()
	await _frames(3)
	_put_player(AT + Vector3(30, 0, 0))
	await _frames(5)
	await _leash()
	await _pull()
	await _caster()
	await _hud_read()
	await _thornwarden()
	await _abbot()
	await _warden()
	await _rare(rares)
	print("ENEMY33 %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## Dragged past its leash: it evades home (immune), heals there; its packmate resets with it.
func _leash() -> void:
	_put_player(AT + Vector3(0, 0, 8))
	var w := _spawn("res://core/enemy/wretch.gd", AT)
	var mate := _spawn("res://core/enemy/wretch.gd", AT + Vector3(3, 0, 0))
	for e in [w, mate]:
		e.can_call = false
		e.can_flee = false
	await _frames(10)
	w.alerted(null)
	await _frames(6)
	check("pulling one pulls its packmate", int(mate.get("_state")) != Enemy.IDLE, "state %d" % int(mate.get("_state")))
	w.hp = 1.0
	var home := w.home
	_put_player(AT + Vector3(36, 0, 0))                 # far: it should not re-aggro on the way back
	w.global_position = _ground(home + Vector3(28, 0, 0)) + Vector3.UP * 0.1   # dragged far off its post
	w.reset_physics_interpolation()
	var ev := false
	for f in 40:
		await get_tree().physics_frame
		if w.is_evading():
			ev = true
			break
	check("dragged past its leash it evades", ev)
	check("its packmate resets with it", mate.is_evading() or int(mate.get("_state")) == Enemy.IDLE)
	var hp0 := w.hp
	w.take_hit(1.0, null)
	check("an evading foe takes no damage", is_equal_approx(w.hp, hp0) and w.is_alive())
	check("the HUD reads it as evading", bool(w.ui_info().evading))
	for f in int(60 * (Enemy.EVADE_MAX + 1.5)):
		await get_tree().physics_frame
		if not w.is_evading():
			break
	var back := Vector2(w.global_position.x - home.x, w.global_position.z - home.z).length()
	check("it gets home and is healed in full", not w.is_evading() and is_equal_approx(w.hp, float(w.max_hp)) and back < 1.6, "hp %.1f/%d, %.1f m from home" % [w.hp, w.max_hp, back])
	_clear()
	await _frames(3)


## A pull is the camp, not the neighbourhood: a camp 20 m off stays put.
func _pull() -> void:
	_put_player(AT + Vector3(0, 0, 16))
	var camp: Array[Enemy] = []
	for i in 3:
		var e := _spawn("res://core/enemy/wretch.gd", AT + Vector3(0, 0, float(i) * 2.0))
		e.can_call = false
		camp.append(e)
	var other := _spawn("res://core/enemy/wretch.gd", AT + Vector3(-20, 0, 0))
	other.can_call = false
	await _frames(10)
	camp[0].alerted(null)
	await _frames(3)
	var woke := 0
	for e in camp:
		if int(e.get("_state")) != Enemy.IDLE:
			woke += 1
	check("the whole camp answers a pull", woke == 3, "%d of 3" % woke)
	check("the next camp does not", int(other.get("_state")) == Enemy.IDLE)
	_clear()
	await _frames(3)


## A Chanter's sigil is a cast with a bar; a blow interrupts it and locks it out.
func _caster() -> void:
	_put_player(AT)
	var c := _spawn("res://core/enemy/chanter.gd", AT + Vector3(-9, 0, 0))
	c.set("_shroud_cd", 99.0)
	c.set("_slip_cd", 99.0)
	_casts.clear()
	_ends.clear()
	var info := {}
	for f in 60 * 6:
		await get_tree().physics_frame
		c.set("_slip_cd", 99.0)
		if c.casting():
			await _frames(6)
			info = c.cast_info()
			break
	check("the chanter's sigil shows as a cast", String(info.get("name", "")) == "Grave Sigil" and bool(info.get("interruptible", false)), str(info))
	check("...with progress under way", float(info.get("progress", 0.0)) > 0.0 and float(info.get("progress", 1.0)) < 1.0, str(info.get("progress")))
	check("Events.enemy_cast_started fired", _casts.size() >= 1 and _casts[0][0] == c and String(_casts[0][1]) == "Grave Sigil")
	c.take_hit(0.5, null)
	await _frames(2)
	var cut := false
	for e: Array in _ends:
		if e[0] == c and bool(e[2]):
			cut = true
	check("a blow interrupts it (cast_ended, interrupted)", not c.casting() and cut)
	check("an interrupted caster is locked out", not c.can_cast())
	var ids: Array = []
	for d: Dictionary in c.debuffs():
		ids.append(d.id)
	check("the lockout shows among its debuffs", ids.has("silenced"), str(ids))
	c.queue_free()
	await _frames(3)


## Name, rank, level and debuffs, as the HUD reads them.
func _hud_read() -> void:
	_put_player(AT + Vector3(30, 0, 0))
	var w := _spawn("res://core/enemy/wretch.gd", AT)
	await _frames(3)
	w.add_mark(2)
	var u := w.ui_info()
	check("a camp pawn reads as a plain foe", String(u.name) == "Wretch" and String(u.rank) == "normal" and int(u.level) >= 1, "%s %s %d" % [u.name, u.rank, u.level])
	var marked := false
	for d: Dictionary in u.debuffs:
		if d.id == "umbral_mark" and int(d.stacks) == 2:
			marked = true
	check("its Marks show as a stacking debuff", marked)
	w.set_meta(&"elite_id", "x")
	check("an elite reads as elite", w.rank() == "elite" and w.level() > int(u.level))
	w.queue_free()
	await _frames(3)


## Thornlash Volley is an interruptible cast (heavy blow); Sap Mending heals unless broken; enrage.
func _thornwarden() -> void:
	_put_player(AT)
	var tw := _spawn("res://core/enemy/thornwarden.gd", AT + Vector3(-9, 0, 0))
	await _frames(5)
	tw.alerted(null)
	tw._ward_t = 0.0
	tw.call("_thorn_lanes")
	await _frames(2)
	var ci := tw.cast_info()
	check("thornwarden: the volley shows as a cast you can break", String(ci.get("name", "")) == "Thornlash Volley" and bool(ci.get("interruptible", false)))
	var lanes := _zone_count(tw)
	tw.take_hit(2.5, null)                               # a heavy blow (a Lance)
	await _frames(2)
	check("thornwarden: a heavy blow interrupts it and the lanes fade", lanes >= 3 and _zone_count(tw) == 0 and not tw.casting() and tw.is_broken(), "%d lanes" % lanes)
	tw.set("phase", 2)
	tw.set("_lanes_t", 99.0)
	tw.set("_snare_t", 99.0)
	tw.set("_wave_t", 99.0)
	tw.set("_lash_cd", 99.0)
	tw.set("_mend_t", 99.0)
	tw.set("_silence_t", 0.0)
	tw.set("_storm_t", 99.0)                             # r34 raids: Thornstorm
	var hp0 := float(tw.max_hp) * 0.5                    # r34 raids: phase II runs 70-35 % (600 HP)
	tw.hp = hp0
	_put_player(AT + Vector3(14, 0, 0))
	tw.call("_sap_mending")
	await _frames(1)
	check("thornwarden: Sap Mending is an interruptible cast", tw.cast_name == "Sap Mending" and tw.cast_interruptible and tw.weak_open)
	await _secs(3.3)
	check("thornwarden: unbroken, it mends", tw.hp > hp0 + 5.0, "%.1f" % tw.hp)
	var hp1 := tw.hp
	tw.set("_stagger_cd", 0.0)
	tw.call("_sap_mending")
	await _frames(10)
	tw.take_hit(2.5, null)
	await _secs(3.3)
	check("thornwarden: interrupted, it does not", tw.hp <= hp1 - 2.0 and tw.cast_name != "Sap Mending", "%.1f -> %.1f" % [hp1, tw.hp])
	tw.fight_t = Thornwarden.ENRAGE_AT + 1.0
	await _frames(3)
	check("thornwarden: the soft enrage comes on", tw.dmg_mult > 1.0 and float(tw.ui_info().get("enrage_left", -1.0)) == 0.0, "x%.2f" % tw.dmg_mult)
	tw.queue_free()
	await _frames(3)
	_clear()
	await _frames(3)


## Raise the Faithful: unbroken, two adds rise (named, never leashed); one heavy blow stops the next.
func _abbot() -> void:
	_put_player(AT)
	var ab := _spawn("res://core/enemy/bone_abbot.gd", AT + Vector3(-10, 0, 0))
	await _frames(5)
	ab.alerted(null)
	ab._ward_t = 0.0
	ab.set("phase", 2)
	ab.set("_raise_t", 99.0)
	await _frames(2)
	ab.call("_raise_faithful")
	await _frames(1)
	check("abbot: Raise the Faithful is an interruptible cast", ab.cast_name == "Raise the Faithful" and ab.cast_interruptible and ab.weak_open)
	await _secs(2.7)
	var adds: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		if n != ab and (n as Enemy).display_name() == "Risen Faithful":
			adds.append(n as Enemy)
	check("abbot: unbroken, the faithful rise", adds.size() == 2, str(adds.size()))
	check("abbot: its adds never leash", adds.size() > 0 and adds[0].has_meta(&"no_leash"))
	for a in adds:
		a.queue_free()
	await _frames(2)
	ab.set("_silence_t", 0.0)
	ab.call("_raise_faithful")
	await _frames(6)
	ab.take_hit(1.0, null)                              # a plain blow: no
	check("abbot: a plain blow does not break the rite", ab.casting())
	ab.take_hit(2.5, null)                              # a heavy blow: yes
	await _secs(2.7)
	var risen := 0
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		if n != ab and (n as Enemy).display_name() == "Risen Faithful":
			risen += 1
	check("abbot: interrupted, no one rises", risen == 0, str(risen))
	ab.queue_free()
	await _frames(3)
	_clear()
	await _frames(3)


## Mandorla Flare: a donut with a telegraph; it lands on you at range, not under it.
func _warden() -> void:
	_put_player(AT)
	var wd := _spawn("res://core/enemy/ascended_warden.gd", AT + Vector3(-10, 0, 0))
	await _frames(5)
	wd._ward_t = 0.0
	wd.set("phase", 2)
	wd.set("_acolytes_t", 99.0)
	wd.set("_flare_t", 99.0)
	await _frames(2)
	var c := wd.global_position
	_put_player(c + Vector3(6.5, 0, 0))
	await _frames(2)
	wd.call("_mandorla_flare")
	check("warden: Mandorla Flare telegraphs on the ground", _zone_count(wd) >= 1)
	check("warden: ...and shows as a cast that cannot be broken", wd.cast_name == "Mandorla Flare" and not wd.cast_interruptible)
	check("warden: under it is safe", not BossKit.inside(c + Vector3(1.0, 0.3, 0), c, {"radius": 11.0, "holes": [[c, 3.2]]}))
	var g0 := p.gloom
	for f in int(60 * 2.3):
		await get_tree().physics_frame
		p.global_position = Vector3(c.x + 6.5, p.global_position.y, c.z)
	check("warden: it lands on you at range", p.gloom > g0 + 5.0, "%.1f -> %.1f" % [g0, p.gloom])
	wd.queue_free()
	await _frames(3)
	_clear()
	await _frames(3)


## A named rare: spawned at its haunt, a map marker, better loot, the marker gone while it is dead.
func _rare(rares: Node) -> void:
	var haunts: Dictionary = rares.get("haunts")
	check("rares found their haunts", haunts.size() >= 2, str(haunts.keys()))
	if haunts.is_empty():
		return
	var id := String(haunts.keys()[0])
	var m := rares.call("marker", id) as Node3D
	check("its haunt is a map marker", m != null and m.is_in_group(&"map_marker") and String(m.get_meta("map_kind", "")) == "rare" and String(m.get_meta("map_label", "")) != "")
	_put_player(haunts[id] + Vector3(40, 0, 0))
	var e := rares.call("spawn_rare", id) as Enemy
	await _frames(5)
	check("the rare spawns, named, with rank rare", e != null and e.rank() == "rare" and e.display_name() == String(m.get_meta("map_label", "")), e.display_name() if e else "null")
	check("it walks a beat round its haunt", e != null and e.patrol.size() >= 2, str(e.patrol.size() if e else -1))
	var GR: GDScript = load("res://core/items/gear_runtime.gd")
	check("the loot system rolls it as better than a camp", ["rare", "elite"].has(String(GR.call("source_of", e))), String(GR.call("source_of", e)))
	var ash0 := Travel.count("grave_ash")
	e.take_hit(999.0, null)
	await _frames(3)
	check("killed, it pays better than a camp", Travel.count("grave_ash") >= ash0 + 20, "%d -> %d" % [ash0, Travel.count("grave_ash")])
	check("its marker leaves the map while it is dead", not m.is_in_group(&"map_marker"))
