extends Node3D
## r29 hardening test (agent A, combat): the odd states the critique found, each pinned.
##   HOME=<scratch>/home godot --headless --path . res://zz/critA_harden.tscn   -> "HARDEN ok" / "HARDEN FAIL n"
##  - a Burrower knocked out of its dig (a fall reset) comes up: visible, hittable, in the group
##  - a boss's ground zones are taken back by a phase change, by its death and by an arena reset,
##    but outlast a plain stagger
##  - a foe hauled by the Rift Tether mid-windup arrives off balance, its tell broken, no blow
##  - a base windup strikes on the frame its red fills (not up to a think later)
##  - Umbral Nova does not reach through a floor (3 m above or below)
##  - the Ascended Warden does not blink while it reels between phases
## Saves held (Travel._busy). Quits itself (hard cap 180 s).

const WRETCH := "res://core/enemy/wretch.gd"
const BURROWER := "res://core/enemy/burrower.gd"
const ABBOT := "res://core/enemy/bone_abbot.gd"
const WARDEN := "res://core/enemy/ascended_warden.gd"
const Drag := preload("res://core/skills/tether_drag.gd")

var p: Player
var fails := 0
var hurts: Array = []          ## msec of each player_hurt


func check(n: String, ok: bool, extra := "") -> void:
	print("HARDEN ", "PASS " if ok else "FAIL ", n, (" (" + extra + ")") if extra != "" else "")
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	Travel._busy = true
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(160, 1, 160)
	cs.shape = bs
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)
	var pool := BoltPool.new()
	pool.name = "BoltPool"
	add_child(pool)
	p = _make_player()
	Events.player_hurt.connect(func(_a: float, _f: Vector3) -> void: hurts.append(Time.get_ticks_msec()))
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		print("HARDEN TIMEOUT")
		get_tree().quit(2))
	_run.call_deferred()


func _make_player() -> Player:
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.set_script(load("res://core/player/player.gd"))
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	pl.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.set_script(load("res://core/player/character_rig.gd"))
	pl.add_child(vis)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.position.y = 1.55
	pl.add_child(rig)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	rig.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	arm.shape = sph
	arm.spring_length = 4.4
	pitch.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	arm.add_child(cam)
	add_child(pl)
	return pl as Player


func _spawn(path: String, at: Vector3) -> Enemy:
	var e := (load(path) as GDScript).new() as Enemy
	add_child(e)
	e.global_position = at
	e.home = at
	e.wake()
	return e


func _reset_player() -> void:
	p.global_position = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.gloom = 0.0; p.wounds = 0.0
	p._hurt_grace_until = 0.0
	p._evade_t = 0.0
	p.set_view(0.0, 0.0)
	hurts.clear()


func _clear() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY) + get_tree().get_nodes_in_group(&"burrowed"):
		(e as Node).queue_free()
	for s in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
		(s as Node).queue_free()
	await _frames(30)


## Hold the player still at the origin for `secs`, keeping Gloom off the dark (only hits count).
func _hold(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await get_tree().physics_frame
		p.global_position = Vector3(0.0, p.global_position.y, 0.0)
		p.velocity = Vector3.ZERO
		p.gloom = 0.0; p.wounds = 0.0


func _run() -> void:
	await _frames(10)
	await _burrower_reset()
	await _boss_zones()
	await _haul()
	await _exact_windup()
	await _nova_floor()
	await _warden_reel()
	print("HARDEN ", "ok" if fails == 0 else "FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _burrower_reset() -> void:
	_reset_player()
	var e := _spawn(BURROWER, Vector3(0, 0.1, -6.0))
	e.chase_range = 0.0
	await _frames(5)
	e.call("_go_under")
	e._set_state(Enemy.SPECIAL)
	e.set("_phase", 1)
	await _frames(2)
	check("burrower: under (setup)", bool(e.call("is_burrowed")) and not e.is_in_group(Groups.ENEMY))
	e.global_position = e.home + Vector3.DOWN * 9.0          # fell through: the reset fires
	await _frames(3)
	var vis := e.get_node_or_null("Visual") as Node3D
	check("burrower: a reset brings it up", not bool(e.call("is_burrowed")) and e.is_in_group(Groups.ENEMY) and e.collision_layer != 0 and vis != null and vis.visible,
		"under %s group %s layer %d" % [e.call("is_burrowed"), e.is_in_group(Groups.ENEMY), e.collision_layer])
	await _clear()


## The Abbot's cage (a ring round you and a disc on you) is a guaranteed hit if it lands.
func _cage_then(what: String) -> bool:
	_reset_player()
	var b := _spawn(ABBOT, Vector3(0, 0.1, -9.0))
	b.set_meta(&"boss_id", "bone_abbot")
	b.chase_range = 0.0
	b.set("_spike_t", 99.0)
	b.set("_grave_t", 99.0)
	b.set("_sweep_t", 99.0)
	await _frames(20)
	b.call("_cage")
	await _frames(6)
	match what:
		"transition":
			b.take_hit(float(b.max_hp) * 0.55, p)
			await _frames(2)
			for m in get_tree().get_nodes_in_group(Groups.ENEMY):
				if m != b:
					(m as Enemy).chase_range = 0.0          # the risen faithful stay put for this check
					(m as Enemy)._calm_t = 99.0
		"death":
			b.marks = 3
			b.take_hit(99999.0, p)
		"reset":
			b.queue_free()
		"stagger":
			b.stagger()
	b = null
	hurts.clear()
	await _hold(1.9)
	var hit := not hurts.is_empty()
	await _clear()
	return hit


func _boss_zones() -> void:
	check("boss: a phase change takes its zones back", not await _cage_then("transition"))
	check("boss: its death takes its zones back", not await _cage_then("death"))
	check("boss: an arena reset (freed) takes its zones back", not await _cage_then("reset"))
	check("boss: a plain stagger does not", await _cage_then("stagger"))
	# a Rift Step through a boss's zone is a riposte (it was a bare "evaded")
	_reset_player()
	var b := _spawn(ABBOT, Vector3(0, 0.1, -9.0))
	b.chase_range = 0.0
	b.set("_spike_t", 99.0)
	b.set("_grave_t", 99.0)
	b.set("_sweep_t", 99.0)
	await _frames(20)
	b.call("_cage")
	p._riposte_ready = false
	p._riposte_cd = 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1900:
		await get_tree().physics_frame
		p.global_position = Vector3(0.0, p.global_position.y, 0.0)
		p.gloom = 0.0; p.wounds = 0.0
		p._evade_t = 0.5
		p._evade_roll = false
	p._evade_t = 0.0
	check("boss: a Rift Step through its zone is a riposte", p._riposte_ready and b.marks >= 2, "ready %s marks %d" % [p._riposte_ready, b.marks])
	p._riposte_ready = false
	await _clear()


func _haul() -> void:
	_reset_player()
	var e := _spawn(WRETCH, Vector3(0, 0.1, -1.3))
	e.feint_chance = 0.0
	e.combo_chance = 0.0
	var t0 := Time.get_ticks_msec()
	while e._state != Enemy.WINDUP and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().physics_frame
		p.gloom = 0.0; p.wounds = 0.0
	check("haul: wretch winds up (setup)", e._state == Enemy.WINDUP)
	hurts.clear()
	Drag.start(e, Vector3(0.0, 0.05, -1.4), 0.3, Callable())
	await _frames(2)
	check("haul: the tell is broken", e._state == Enemy.RECOVER and not is_instance_valid(e._danger), "state %d" % e._state)
	await _hold(0.75)
	check("haul: no blow lands from the broken tell", hurts.is_empty(), "%d hits" % hurts.size())
	await _clear()


func _exact_windup() -> void:
	_reset_player()
	var e := _spawn(WRETCH, Vector3(0, 0.1, -1.3))
	e.feint_chance = 0.0
	e.combo_chance = 0.0
	var worst := 0.0
	var n := 0
	var was := e._state
	var frames := 0
	var want := 0.0
	var t0 := Time.get_ticks_msec()
	while n < 4 and Time.get_ticks_msec() - t0 < 12000:
		await get_tree().physics_frame
		p.global_position = Vector3(0.0, p.global_position.y, 0.0)
		p.gloom = 0.0; p.wounds = 0.0
		frames += 1
		if e._state != was:
			if e._state == Enemy.WINDUP:
				frames = 0
				want = e._cur_windup
			elif e._state == Enemy.STRIKE and was == Enemy.WINDUP:
				worst = maxf(worst, absf(float(frames) / float(Engine.physics_ticks_per_second) - want))
				n += 1
			was = e._state
	check("windup: strikes on the frame the red fills", n >= 3 and worst <= 1.5 / float(Engine.physics_ticks_per_second) + 0.001,
		"%d windups, worst off by %.0f ms" % [n, worst * 1000.0])
	await _clear()


func _nova_floor() -> void:
	_reset_player()
	var above := _spawn(WRETCH, Vector3(2.0, 5.0, 0.0))
	var level := _spawn(WRETCH, Vector3(-2.0, 0.1, 0.0))
	for e: Enemy in [above, level]:
		e.chase_range = 0.0
		e.set_physics_process(false)                         # pinned where it was put
	await _frames(5)
	var h_above := above.hp
	var h_level := level.hp
	var book := p.skills()
	var slot := book.slot_of(&"nova") if book else -1
	var ok_cast := false
	if slot >= 0:
		book._cd.fill(0.0)
		book._gcd = 0.0
		ok_cast = book.try_cast(slot, 0.0, true)
	await _frames(40)                                        # a Bone Reliquary Implosion detonates 0.35 s later
	check("nova: hits a foe on its level", ok_cast and level.hp < h_level, "cast %s hp %.1f, player %s foe %s" % [ok_cast, level.hp, p.global_position, level.global_position])
	check("nova: not one on the floor above", above.hp >= h_above, "hp %.1f -> %.1f" % [h_above, above.hp])
	await _clear()


func _warden_reel() -> void:
	_reset_player()
	var w := _spawn(WARDEN, Vector3(0, 0.1, -8.0))
	w.set_meta(&"boss_id", "ascended_warden")
	w.call("on_engaged", self)
	w.set("_blink_t", 99.0)
	await _frames(20)
	w.take_hit(float(w.max_hp) * 0.45, p)
	await _frames(3)
	check("warden: phase 2 (setup)", int(w.get("phase")) == 2)
	while w._ward_t > 0.0:
		await get_tree().physics_frame
		p.gloom = 0.0; p.wounds = 0.0
	await _frames(10)
	w.set("_blink_t", 99.0)
	w.take_hit(float(w.max_hp) * 0.3, p)
	await _frames(3)
	check("warden: phase 3 (setup)", int(w.get("phase")) == 3)
	var at := w.global_position
	var moved := 0.0
	var t0 := Time.get_ticks_msec()
	while w._ward_t > 0.0 and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().physics_frame
		p.gloom = 0.0; p.wounds = 0.0
		moved = maxf(moved, w.global_position.distance_to(at))
	check("warden: no blink while it reels", moved < 1.0, "moved %.1f m" % moved)
	await _clear()
