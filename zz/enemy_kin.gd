extends Node3D
## r28 enemy test (agent A): every new kin and the new behaviours on a bare floor with a real
## Player. Each kin is spawned, must telegraph on the ground, land an attack on a still player,
## take damage and die (enemy_killed, dissolve, freed). Then the pack AI (a call wakes the pack,
## the hurt fall back, a guard stands before its caster, the caster keeps the guard between, a
## Nova shakes them), the new moves (combo chains, feints, husk slam and charge, leaper tail sweep,
## spitter lob + acid pool), the Bulwark's shield, the Chanter's sigil / shroud / slip, the
## Burrower's tunnel, the Mite swarm's own token pool, the Bone Abbot's phase 3, and the voices.
##   HOME=<scratch>/home godot --headless --path . res://zz/enemy_kin.tscn   -> "KIN ok" / "KIN FAIL n"
## Saves are held (Travel._busy) the whole run.

const KIN := {
	"bulwark": "res://core/enemy/bulwark.gd", "chanter": "res://core/enemy/chanter.gd",
	"burrower": "res://core/enemy/burrower.gd", "mite": "res://core/enemy/mite.gd",
}
const WRETCH := "res://core/enemy/wretch.gd"
const HUSK := "res://core/enemy/husk.gd"
const SPITTER := "res://core/enemy/spitter.gd"
const LEAPER := "res://core/enemy/leaper.gd"
const ABBOT := "res://core/enemy/bone_abbot.gd"
const Synth := preload("res://core/vfx/synth.gd")

var p: Player
var fails := 0
var killed: Array = []
var hurts := 0
var dangers: Array = []          ## [MeshInstance3D, frame] of every ground telegraph added


func check(n: String, ok: bool, extra := "") -> void:
	print("KIN ", "PASS " if ok else "FAIL ", n, (" (" + extra + ")") if extra != "" else "")
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		Travel._busy = true
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
	Events.enemy_killed.connect(func(e: Node) -> void: killed.append(e))
	Events.player_hurt.connect(func(_a: float, _f: Vector3) -> void: hurts += 1)
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is MeshInstance3D and (n as MeshInstance3D).material_override is ShaderMaterial and ((n as MeshInstance3D).material_override as ShaderMaterial).shader == SpellFx.DANGER:
			dangers.append(n))
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
	var t0 := Time.get_ticks_usec()
	var e := (load(path) as GDScript).new() as Enemy
	add_child(e)
	e.global_position = at
	e.home = at
	e.wake()
	var ms := (Time.get_ticks_usec() - t0) * 0.001
	if ms > 6.0:
		print("KIN build ", e.name, " %.1f ms" % ms)
	return e


func _reset_player(at := Vector3.ZERO) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.gloom = 0.0
	p._hurt_grace_until = 0.0
	p._evade_t = 0.0
	p.set_view(0.0, 0.0)
	Engine.time_scale = 1.0


func _clear() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	for e in get_children():
		if e is Enemy:
			e.queue_free()
	for s in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
		(s as Node).queue_free()
	Enemy._tokens.clear()
	Enemy._alarms.clear()
	Engine.time_scale = 1.0
	await _frames(3)


func _dangers_since(n0: int) -> Array:
	var out: Array = []
	for i in range(n0, dangers.size()):
		if is_instance_valid(dangers[i]):
			out.append(dangers[i])
	return out


func _run() -> void:
	await _frames(10)
	_voices()
	for kind: String in KIN:
		await _kin(kind, KIN[kind])
	await _bulwark_shield()
	await _chanter_works()
	await _burrower_tunnel()
	await _swarm_tokens()
	await _pack_call()
	await _flee()
	await _guard_and_support()
	await _nova()
	await _combo_and_feint()
	await _husk_moves()
	await _leaper_sweep()
	await _spitter_lob()
	await _knockback_mass()
	await _abbot_requiem()
	print("KIN ", "ok" if fails == 0 else "FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _voices() -> void:
	var t0 := Time.get_ticks_usec()
	Synth.prewarm()
	print("KIN synth prewarm %.0f ms (cold the first run on a checkout, GenCache after)" % ((Time.get_ticks_usec() - t0) * 0.001))
	t0 = Time.get_ticks_usec()
	var n := 0
	for act: String in Synth.ACTS:
		for take in Synth.TAKES[act]:
			Synth._creature(Synth.VOICES.rasp, Synth.SHAPES[act], take, 7 + take)
			n += 1
	print("KIN synth cold cost: one family (%d takes) %.0f ms -> all %d families ~%.0f ms" % [n, (Time.get_ticks_usec() - t0) * 0.001, Synth.VOICES.size(), (Time.get_ticks_usec() - t0) * 0.001 * Synth.VOICES.size()])
	var ok := true
	for fam: String in Synth.VOICES:
		for act: String in Synth.ACTS:
			var s := Synth.voice(fam, act)
			if s == null or s.data.size() < 1000:
				ok = false
	check("voices: every family has every act", ok)
	var last: AudioStreamWAV = null
	var repeat := false
	for i in 12:
		var s := Synth.voice("rasp", "tell")
		if s == last:
			repeat = true
		last = s
	check("voices: no take plays twice in a row", not repeat)
	check("sounds: block, burrow, chant", Synth.get_stream("block") != null and Synth.get_stream("burrow") != null and Synth.get_stream("chant") != null)


## Spawn, telegraph on the ground, land on a still player, take damage, die, dissolve.
func _kin(kind: String, path: String) -> void:
	_reset_player()
	var n0 := dangers.size()
	var e := _spawn(path, Vector3(0, 0.1, -9.0 if kind == "burrower" else -7.0))
	var hurt0 := hurts
	var saw_tell := false
	for i in 900:
		await _frames(1)
		p.gloom = 0.0
		if not is_instance_valid(e):
			break
		if dangers.size() > n0:
			saw_tell = true
		if hurts > hurt0:
			break
	check(kind + " telegraphs on the ground", saw_tell)
	check(kind + " attack lands on a still player", hurts > hurt0)
	await _frames(40)
	if not is_instance_valid(e):
		check(kind + " alive for hit tests", false)
		return
	# hit from behind (a Bulwark's shield must not turn it)
	var behind := Node3D.new()
	add_child(behind)
	var back := e._face.global_basis.z if e._face else Vector3.BACK
	behind.global_position = e.global_position + Vector3(back.x, 0, back.z).normalized() * 2.0
	for k in 60:
		if e.call("is_burrowed") if e.has_method("is_burrowed") else false:
			await _frames(5)
	var hp0 := e.hp
	killed.clear()
	e.take_hit(1.0, behind)
	check(kind + " takes damage", e.hp < hp0 or not e.is_alive(), "hp %.1f -> %.1f" % [hp0, e.hp])
	if e.is_alive():
		e.marks = 3
		e.take_hit(99.0, behind)
	check(kind + " dies (enemy_killed)", killed.has(e))
	behind.queue_free()
	await _frames(110)
	check(kind + " dissolves and frees", not is_instance_valid(e))
	await _clear()


func _bulwark_shield() -> void:
	_reset_player()
	var b := _spawn(KIN.bulwark, Vector3(0, 0.1, -6.0))
	b.chase_range = 0.0
	await _frames(20)
	b._face.rotation.y = 0.0                     # facing -Z, away from the player at the origin
	b._face.rotation.y = PI                      # now facing +Z: toward the player
	await _frames(2)
	var front := Node3D.new()
	add_child(front)
	front.global_position = b.global_position + Vector3(0, 1, 2.0)
	var hp0 := b.hp
	var sh0: float = b.get("shield_hp")
	b.take_hit(1.0, front)
	check("bulwark: a frontal blow is blocked", is_equal_approx(b.hp, hp0) and float(b.get("shield_hp")) < sh0, "hp %.1f shield %.1f" % [b.hp, float(b.get("shield_hp"))])
	await _frames(10)
	var side := Node3D.new()
	add_child(side)
	side.global_position = b.global_position + Vector3(2.0, 1, 0)
	b.take_hit(1.0, side)
	check("bulwark: a blow from the flank goes through", b.hp < hp0)
	await _frames(10)
	b._stagger_cd = 9.0
	b._face.rotation.y = PI
	b.take_hit(3.0, front)                      # heavy: counts double on the shield (5 - 6 < 0)
	check("bulwark: heavy blows break the shield", not b.call("has_shield"))
	check("bulwark: the break staggers it", b._state == Enemy.RECOVER and b._state_t < 0.0)
	await _frames(80)
	b._face.rotation.y = PI
	var hp1 := b.hp
	b.take_hit(1.0, front)
	check("bulwark: shield gone, the front is open", b.hp < hp1)
	front.queue_free()
	side.queue_free()
	await _clear()


func _chanter_works() -> void:
	# the sigil lands under the player
	_reset_player()
	var n0 := dangers.size()
	var c := _spawn(KIN.chanter, Vector3(0, 0.1, -9.0))
	var near := false
	for i in 400:
		await _frames(1)
		p.gloom = 0.0
		for d in _dangers_since(n0):
			if (d as Node3D).global_position.distance_to(p.global_position) < 0.6:
				near = true
		if near:
			break
	check("chanter: its sigil is drawn under you", near)
	await _clear()
	# it shrouds a fighting packmate
	_reset_player()
	var w := _spawn(WRETCH, Vector3(0, 0.1, -5.0))
	c = _spawn(KIN.chanter, Vector3(0, 0.1, -10.0))
	c._shot_cd = 99.0
	c.set("_shroud_cd", 0.5)
	var shrouded := false
	for i in 300:
		await _frames(1)
		p.gloom = 0.0
		if is_instance_valid(w) and w._shroud_t > 0.0:
			shrouded = true
			break
	check("chanter: shrouds a packmate", shrouded)
	if shrouded:
		var hp0 := w.hp
		w.take_hit(1.0, p)
		check("shroud: half damage", is_equal_approx(w.hp, hp0 - 0.5), "%.2f -> %.2f" % [hp0, w.hp])
	await _clear()
	# a blow breaks the working
	_reset_player()
	w = _spawn(WRETCH, Vector3(0, 0.1, -5.0))
	c = _spawn(KIN.chanter, Vector3(0, 0.1, -10.0))
	c._shot_cd = 99.0
	c.set("_shroud_cd", 0.5)
	var broke := false
	for i in 300:
		await _frames(1)
		p.gloom = 0.0
		if c._state == Enemy.SPECIAL and StringName(c.get("_act")) == &"shroud" and c._state_t > 0.3:
			c.take_hit(1.0, p)
			await _frames(80)
			broke = is_instance_valid(w) and w._shroud_t <= 0.0
			break
	check("chanter: a hit breaks the shroud", broke)
	await _clear()
	# you close in: it slips away
	_reset_player()
	c = _spawn(KIN.chanter, Vector3(0, 0.1, -2.5))
	c._shot_cd = 99.0
	c.set("_shroud_cd", 99.0)
	c.set("_slip_cd", 0.0)
	var d0 := 2.5
	var slipped := false
	for i in 200:
		await _frames(1)
		if is_instance_valid(c) and c.global_position.distance_to(p.global_position) > d0 + 4.0:
			slipped = true
			break
	check("chanter: slips away when you close in", slipped)
	await _clear()


func _burrower_tunnel() -> void:
	_reset_player()
	var n0 := dangers.size()
	var b := _spawn(KIN.burrower, Vector3(0, 0.1, -11.0))
	var under := false
	var hidden := false
	var surfaced_near := false
	for i in 500:
		await _frames(1)
		p.gloom = 0.0
		if not is_instance_valid(b):
			break
		if b.call("is_burrowed"):
			under = true
			hidden = b.collision_layer == 0 and not b.is_in_group(Groups.ENEMY)
		elif under and b._state == Enemy.RECOVER:
			surfaced_near = b.global_position.distance_to(p.global_position) < 2.5
			break
	check("burrower: goes under", under)
	check("burrower: underground it cannot be hit or targeted", hidden)
	check("burrower: surfaces under you", surfaced_near)
	var erupt := false
	for d in _dangers_since(n0):
		if (d as Node3D).global_position.distance_to(p.global_position) < 2.5:
			erupt = true
	check("burrower: its eruption is telegraphed", erupt)
	await _clear()


func _swarm_tokens() -> void:
	_reset_player()
	var swarm: Array[Enemy] = []
	for i in 5:
		var a := TAU * float(i) / 5.0
		swarm.append(_spawn(KIN.mite, Vector3(cos(a) * 4.0, 0.1, sin(a) * 4.0)))
	var w := _spawn(WRETCH, Vector3(0, 0.1, 5.0))
	w.can_call = false
	var most := 0
	var wretch_attacked := false
	for i in 420:
		await _frames(1)
		p.gloom = 0.0
		var n := 0
		for m in swarm:
			if is_instance_valid(m) and (m._state == Enemy.WINDUP or m._state == Enemy.STRIKE or m._state == Enemy.LEAP_PREP or m._state == Enemy.AIRBORNE):
				n += 1
		most = maxi(most, n)
		if is_instance_valid(w) and (w._state == Enemy.WINDUP or w._state == Enemy.FEINT) and n >= 1:
			wretch_attacked = true
	check("swarm: at most 3 mites attack at once", most >= 1 and most <= 3, "max %d" % most)
	check("swarm: its own pool leaves a melee turn for others", wretch_attacked)
	await _clear()


func _pack_call() -> void:
	_reset_player()
	var a := _spawn(WRETCH, Vector3(0, 0.1, -10.0))
	var b := _spawn(WRETCH, Vector3(0, 0.1, -22.0))      # 22 m: out of its own chase range
	var called := false
	var woke := false
	for i in 120:
		await _frames(1)
		if a._state == Enemy.CALL:
			called = true
		if b._state != Enemy.IDLE:
			woke = true
			break
	check("pack: the first to see you calls", called)
	check("pack: the call wakes the others", woke and b._rally_t > 0.0)
	await _clear()


func _flee() -> void:
	_reset_player()
	var a := _spawn(WRETCH, Vector3(0, 0.1, -4.0))
	var b := _spawn(WRETCH, Vector3(2.5, 0.1, -6.0))
	b.chase_range = 0.0
	await _frames(30)
	a._stagger_cd = 9.0
	a.take_hit(2.0, p)
	await _frames(12)
	var d0 := a.global_position.distance_to(p.global_position)
	check("pack: badly hurt with packmates near, it falls back", a._flee_t > 0.0)
	await _frames(70)
	check("pack: ...away from you", a.global_position.distance_to(p.global_position) > d0 + 0.8, "%.1f -> %.1f m" % [d0, a.global_position.distance_to(p.global_position)])
	await _clear()


func _guard_and_support() -> void:
	_reset_player()
	var s := _spawn(SPITTER, Vector3(0, 0.1, -13.0))
	var h := _spawn(HUSK, Vector3(4, 0.1, -13.0))
	s._shot_cd = 99.0
	h.set("_charge_cd", 99.0)
	await _frames(240)
	var line := (s.global_position - p.global_position)
	line.y = 0.0
	var hp := h.global_position - p.global_position
	hp.y = 0.0
	var off := (hp - line.normalized() * hp.dot(line.normalized())).length()
	check("guard: the husk stands between you and its caster", hp.length() < line.length() and off < 2.0, "off-line %.1f m, husk %.1f / spitter %.1f m" % [off, hp.length(), line.length()])
	check("support: the caster keeps the guard between", s.global_position.distance_to(p.global_position) > h.global_position.distance_to(p.global_position))
	await _clear()


func _nova() -> void:
	_reset_player()
	var w := _spawn(WRETCH, Vector3(0, 0.1, -6.0))
	w.can_call = false
	await _frames(20)
	var d0 := w.global_position.distance_to(p.global_position)
	Events.skill_cast.emit(&"nova")
	await _frames(2)
	check("nova: survivors near are shaken and wary", w._shaken_t > 0.0 and w._wary_t > 0.0)
	await _frames(40)
	check("nova: ...and back off", w.global_position.distance_to(p.global_position) > d0 - 0.2, "%.1f -> %.1f" % [d0, w.global_position.distance_to(p.global_position)])
	check("nova: a wider ring while wary", w._wait_ring() > Enemy.WAIT_RING)
	await _clear()


func _combo_and_feint() -> void:
	_reset_player()
	var w := _spawn(WRETCH, Vector3(0, 0.1, -3.0))
	w.can_call = false
	w.combo_chance = 1.0
	w.feint_chance = 0.0
	var strikes := 0
	var cones := 0
	var last := -1
	var seen_short := false
	for i in 300:
		await _frames(1)
		p.gloom = 0.0
		p._hurt_grace_until = 0.0
		if w._state != last:
			if w._state == Enemy.STRIKE:
				strikes += 1
			if w._state == Enemy.WINDUP:
				if is_instance_valid(w._danger):
					cones += 1
				if is_equal_approx(w._cur_windup, w.combo_windup):
					seen_short = true
			last = w._state
		if w._state == Enemy.RECOVER and strikes >= 1:
			break
	check("combo: a chain of blows", strikes >= 2, "%d strikes" % strikes)
	check("combo: every blow has its own cone", cones >= strikes, "%d cones" % cones)
	check("combo: chained blows have the shorter tell", seen_short)
	await _clear()
	_reset_player()
	w = _spawn(WRETCH, Vector3(0, 0.1, -3.0))
	w.can_call = false
	w.combo_chance = 0.0
	w.feint_chance = 1.0
	var feint := false
	var red_in_feint := false
	var real := false
	var n0 := dangers.size()
	for i in 300:
		await _frames(1)
		p.gloom = 0.0
		if w._state == Enemy.FEINT:
			feint = true
			if not _dangers_since(n0).is_empty():
				red_in_feint = true
		elif feint and w._state == Enemy.WINDUP and is_instance_valid(w._danger):
			real = true
			break
	check("feint: a false start", feint)
	check("feint: no red on the ground during it", not red_in_feint)
	check("feint: then the real tell", real)
	await _clear()


func _husk_moves() -> void:
	# charge from range down a lane
	_reset_player()
	var h := _spawn(HUSK, Vector3(0, 0.1, -8.0))
	h.can_call = false
	h.set("_charge_cd", 0.0)
	h.set("can_slam", false)
	var n0 := dangers.size()
	var hurt0 := hurts
	var charged := false
	for i in 300:
		await _frames(1)
		p.gloom = 0.0
		if h._state == Enemy.SPECIAL and StringName(h.get("_move_id")) == &"charge":
			charged = true
		if hurts > hurt0:
			break
	var lane := not _dangers_since(n0).is_empty()
	check("husk: charges from range", charged)
	check("husk: the charge lane is telegraphed", lane)
	check("husk: the charge hits a still player", hurts > hurt0)
	await _clear()
	# slam at close range
	_reset_player()
	h = _spawn(HUSK, Vector3(0, 0.1, -2.6))
	h.can_call = false
	h.set("_slam_cd", 0.0)
	h.set("can_charge", false)
	h.strike_range = 0.5                      # keep it from the plain rake
	var slammed := false
	hurt0 = hurts
	for i in 400:
		await _frames(1)
		p.gloom = 0.0
		p._hurt_grace_until = 0.0
		if h._state == Enemy.SPECIAL and StringName(h.get("_move_id")) == &"slam":
			slammed = true
		if slammed and hurts > hurt0:
			break
	check("husk: slams at close range", slammed)
	check("husk: the slam lands on a still player", hurts > hurt0)
	await _clear()
	# a stagger cancels the slam's tell: nothing lands
	_reset_player()
	h = _spawn(HUSK, Vector3(0, 0.1, -2.6))
	h.can_call = false
	h.set("_slam_cd", 0.0)
	h.set("can_charge", false)
	h.strike_range = 0.5
	var broke := false
	for i in 400:
		await _frames(1)
		p.gloom = 0.0
		if h._state == Enemy.SPECIAL and h._state_t > 0.2:
			hurt0 = hurts
			h._stagger_cd = 0.0
			h.take_hit(2.0, p)
			await _frames(60)
			broke = hurts == hurt0
			break
	check("husk: a heavy hit on the tell cancels the slam", broke)
	await _clear()


func _leaper_sweep() -> void:
	_reset_player()
	var l := _spawn(LEAPER, Vector3(0, 0.1, -1.8))
	l.can_call = false
	l.leap_cooldown = 99.0
	l._leap_cd = 99.0
	l.set("_sweep_cd", 0.0)
	await _frames(2)
	l._face.rotation.y = 0.0                  # facing -Z: the player (at +Z of it) is behind
	l.turn_rate = 0.0                         # and it does not get to turn first (you just stepped past it)
	l.strike_range = 0.3
	var swept := false
	var hurt0 := hurts
	for i in 200:
		await _frames(1)
		p.gloom = 0.0
		if l._state == Enemy.SPECIAL:
			swept = true
		if swept and hurts > hurt0:
			break
	check("leaper: tail sweep at its flank", swept)
	check("leaper: the sweep lands on a still player", hurts > hurt0)
	await _clear()


func _spitter_lob() -> void:
	_reset_player()
	# a wall between: no line of sight, so it lobs over
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4, 3, 0.4)
	cs.shape = bs
	wall.add_child(cs)
	add_child(wall)
	wall.global_position = Vector3(0, 1.5, -4.0)
	var s := _spawn(SPITTER, Vector3(0, 0.1, -9.0))
	s.kite_min = 1.0
	s.kite_max = 20.0
	s._shot_cd = 0.2
	var n0 := dangers.size()
	var lobbed := false
	var pool := false
	var hurt0 := hurts
	for i in 360:
		await _frames(1)
		p.gloom = 0.0
		p._hurt_grace_until = 0.0
		if bool(s.get("_lobbing")):
			lobbed = true
		for d in _dangers_since(n0):
			if (d as Node3D).global_position.distance_to(p.global_position) < 1.0:
				pool = true
		if lobbed and hurts > hurt0 + 1:
			break
	check("spitter: lobs over cover", lobbed and pool)
	check("spitter: the lob and its acid pool land", hurts >= hurt0 + 2, "%d hits" % (hurts - hurt0))
	wall.queue_free()
	await _clear()


func _knockback_mass() -> void:
	_reset_player()
	var m := _spawn(KIN.mite, Vector3(-3, 0.1, -12.0))
	var h := _spawn(HUSK, Vector3(3, 0.1, -12.0))
	m.chase_range = 0.0
	h.chase_range = 0.0
	await _frames(20)
	m.max_hp = 9
	m.hp = 9.0
	var mp := m.global_position
	var hp := h.global_position
	m.take_hit(1.0, p)
	h.take_hit(1.0, p)
	await _frames(20)
	var dm := Vector2(m.global_position.x - mp.x, m.global_position.z - mp.z).length()
	var dh := Vector2(h.global_position.x - hp.x, h.global_position.z - hp.z).length()
	check("hit feel: light things fly further than heavy ones", dm > dh * 1.8, "mite %.2f m, husk %.2f m" % [dm, dh])
	await _clear()


func _abbot_requiem() -> void:
	_reset_player()
	var b := _spawn(ABBOT, Vector3(0, 0.1, -8.0))
	b.set_meta(&"boss_id", "bone_abbot")
	await _frames(30)
	b.take_hit(float(b.max_hp) * 0.55, p)
	await _frames(2)
	check("abbot: phase 2 opens with a reeling transition", int(b.get("phase")) == 2 and b._ward_t > 0.0)
	var hp0 := b.hp
	b.take_hit(4.0, p)
	check("abbot: blows are mostly turned while it reels", hp0 - b.hp < 1.0, "%.2f" % (hp0 - b.hp))
	await _frames(120)
	b.take_hit(b.hp - float(b.max_hp) * 0.2, p)
	await _frames(2)
	check("abbot: phase 3 below a quarter", int(b.get("phase")) == 3)
	var n0 := dangers.size()
	for i in 360:
		await _frames(1)
		p.gloom = minf(p.gloom, 40.0)
		p.global_position = Vector3(sin(float(i) * 0.03) * 4.0, p.global_position.y, -3.0 + cos(float(i) * 0.03) * 2.0)
	var zones := _dangers_since(n0).size()
	check("abbot: the Requiem raises its rings (and the cage)", dangers.size() - n0 >= 30, "%d zones" % (dangers.size() - n0))
	killed.clear()
	b.marks = 3
	b.take_hit(9999.0, p)
	check("abbot: dies", killed.has(b))
	await _frames(140)
	await _clear()
	print("  (live danger meshes at the end: %d)" % zones)
