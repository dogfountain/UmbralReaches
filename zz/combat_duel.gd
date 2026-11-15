extends Node3D
## Combat duel harness: a bare floor, a real Player, and every enemy kind and boss in turn.
## Checks the melee loop (token -> telegraph cone + rig rear-up -> strike lands -> recover), hit
## feel (hit-stop freeze, knockback, flinch), poise stagger, Rift Step riposte, a real bolt hit,
## death (collapse + dissolve + enemy_killed), pack tokens (<= 2 attackers at once, the rest
## circle), the spitter's ranged loop, and each boss's phases and telegraphed moves.
##   godot --headless --path . res://zz/combat_duel.tscn            -> "COMBAT ok" / "COMBAT FAIL n"
const KINDS := {
	"wretch": "res://core/enemy/wretch.gd", "husk": "res://core/enemy/husk.gd",
	"spitter": "res://core/enemy/spitter.gd", "crawler": "res://core/enemy/crawler.gd",
	"leaper": "res://core/enemy/leaper.gd", "ossuant": "res://core/enemy/ossuant.gd",
}
const BOSSES := {
	"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd",
	"ascended_warden": "res://core/enemy/ascended_warden.gd",
}
const HunchRig := preload("res://core/enemy/hunch_rig.gd")

var p: Player
var fails := 0
var killed: Array = []
var hurts := 0


func check(n: String, ok: bool, extra := "") -> void:
	print("COMBAT ", "PASS " if ok else "FAIL ", n, (" (" + extra + ")") if extra != "" else "")
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1, 120)
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
	if ms > 4.0:
		print("COMBAT build ", e.name, " %.1f ms" % ms)
	return e


func _reset_player() -> void:
	p.global_position = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.gloom = 0.0; p.wounds = 0.0
	p._hurt_grace_until = 0.0
	p._evade_t = 0.0
	p.set_view(0.0, 0.0)


func _clear() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	for s in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
		(s as Node).queue_free()
	await _frames(3)


func _run() -> void:
	await _frames(10)
	for kind: String in KINDS:
		await _melee_kind(kind, KINDS[kind])
	await _pack()
	await _riposte()
	await _real_bolt()
	for b: String in BOSSES:
		await _boss(b, BOSSES[b])
	print("COMBAT ", "ok" if fails == 0 else "FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


## One enemy walks in, telegraphs and strikes the idle player; then hit feel, poise and death.
func _melee_kind(kind: String, path: String) -> void:
	_reset_player()
	var e := _spawn(path, Vector3(0, 0.1, -7.0))
	var saw_windup := false
	var saw_cone := false
	var saw_rig := false
	var windup_frames := 0
	var hurt0 := hurts
	var shot := false
	for i in 600:
		await get_tree().physics_frame
		if not is_instance_valid(e):
			break
		if e._state == Enemy.WINDUP or e._state == Enemy.LEAP_PREP:
			saw_windup = true
			windup_frames += 1
			if is_instance_valid(e._danger):
				saw_cone = true
			if e._rig and (e._rig.get("_wind") is float and float(e._rig.get("_wind")) > 0.5 or e._rig.get("_gesture") is float and float(e._rig.get("_gesture")) > 0.3):
				saw_rig = true
		if not get_tree().get_nodes_in_group(Groups.ENEMY_SHOT).is_empty():
			shot = true
		if hurts > hurt0:
			break
	if kind == "spitter":
		check(kind + " spits at range", shot)
		check(kind + " windup shown", saw_windup)
	else:
		check(kind + " telegraphs (windup state)", saw_windup)
		check(kind + " telegraph cone on the ground", saw_cone)
		check(kind + " rig rears/coils on the windup", saw_rig)
	check(kind + " attack lands on a still player", hurts > hurt0)
	# hit feel
	await _frames(30)
	if not is_instance_valid(e):
		check(kind + " alive for hit tests", false)
		return
	var hp0 := e.hp
	var pos0 := e.global_position
	e.take_hit(1.0, p)
	check(kind + " hit lowers hp", is_equal_approx(e.hp, hp0 - 1.0) or e.hp <= 0.0)
	if e.hp > 0.0:
		check(kind + " hit-stop freezes it", e._hitstop >= 2)
		await _frames(1)
		var frozen := e.global_position.distance_to(pos0) < 0.05
		await _frames(8)
		var moved := Vector2(e.global_position.x - pos0.x, e.global_position.z - pos0.z).length()
		check(kind + " frozen during hit-stop then knocked back", frozen and moved > 0.12, "moved %.2f" % moved)
		# poise: a burst of hits staggers it
		if e.hp > e.poise + 0.2:
			e._stagger_cd = 0.0
			e._poise_dmg = 0.0
			e.take_hit(e.poise * 0.5 + 0.02, p)
			e.take_hit(e.poise * 0.5 + 0.02, p)
			check(kind + " poise break staggers", e._state == Enemy.RECOVER and e._state_t < -0.2 and e._stagger_cd > 0.0)
	# death
	var already := is_instance_valid(e) and not e.is_alive()
	if not already:
		killed.clear()
	if is_instance_valid(e) and e.is_alive():
		e.marks = 3
		e.take_hit(99.0, p)
	check(kind + " dies (enemy_killed)", already or killed.has(e))
	await _frames(360)                      # the body lies a beat, then burns (r33): 100 frames was the old topple
	check(kind + " dissolves and frees", not is_instance_valid(e))
	await _clear()


## Five wretches on the player: never more than two winding up or striking at once.
func _pack() -> void:
	_reset_player()
	var pack: Array[Enemy] = []
	for i in 5:
		var a := TAU * float(i) / 5.0
		pack.append(_spawn(KINDS["wretch"], Vector3(cos(a) * 6.0, 0.1, sin(a) * 6.0)))
	var most := 0
	var waited := false
	var spread := 0.0
	for i in 360:
		await get_tree().physics_frame
		p.gloom = 0.0; p.wounds = 0.0
		var n := 0
		for e in pack:
			if is_instance_valid(e) and (e._state == Enemy.WINDUP or e._state == Enemy.STRIKE):
				n += 1
			if is_instance_valid(e) and e._waiting:
				waited = true
		most = maxi(most, n)
	# bearings round the player: the widest empty arc must be well under a half circle's worth
	var angs: Array[float] = []
	var closest := INF
	for e in pack:
		var d := e.global_position - p.global_position
		angs.append(atan2(d.z, d.x))
		for o in pack:
			if o != e:
				closest = minf(closest, Vector2(e.global_position.x - o.global_position.x, e.global_position.z - o.global_position.z).length())
	angs.sort()
	var gap := 0.0
	for i in angs.size():
		var nxt := angs[(i + 1) % angs.size()] + (TAU if i == angs.size() - 1 else 0.0)
		gap = maxf(gap, nxt - angs[i])
	spread = rad_to_deg(gap)
	check("pack: at most 2 attack at once", most <= 2 and most >= 1, "max %d" % most)
	check("pack: the rest circle for an opening", waited)
	check("pack: they surround rather than stack", spread < 170.0 and closest > 0.35, "widest gap %.0f deg, closest pair %.2f m" % [spread, closest])
	for e in pack:
		print("  pack at ", e.global_position.snapped(Vector3.ONE * 0.1), " state ", e._state, " waiting ", e._waiting)
	await _clear()


## Rift Step i-frames: a strike that passes through an evading player is a riposte.
func _riposte() -> void:
	_reset_player()
	var e := _spawn(KINDS["husk"], Vector3(0, 0.1, -3.0))
	var done := false
	var hurt0 := hurts
	for i in 400:
		await get_tree().physics_frame
		if e._state == Enemy.STRIKE and not e._struck:
			p._evade_t = 0.3
			p._riposte_cd = 0.0
		if e._state == Enemy.RECOVER and e._struck:
			done = true
			break
	check("strike through Rift Step i-frames: no gloom", hurts == hurt0)
	check("riposte staggers and marks the attacker", done and e.marks >= 2 and e._state_t < 0.0)
	check("riposte arms a free Rift Lash", p.consume_riposte())
	Engine.time_scale = 1.0
	await _clear()


## A real bolt from the pool, fired at a wretch: it flies, hits, marks and damages.
func _real_bolt() -> void:
	_reset_player()
	var e := _spawn(KINDS["wretch"], Vector3(0, 0.1, -9.0))
	e.sleep()
	e.process_mode = Node.PROCESS_MODE_INHERIT
	e.chase_range = 0.0
	await _frames(5)
	var hp0 := e.hp
	var bolt := (get_tree().get_first_node_in_group("bolt_pool") as BoltPool).take()
	var from := Vector3(0, 1.2, -1.0)
	var aim := (e.global_position + Vector3.UP * 1.1 - from).normalized()
	bolt.transform = Transform3D(Basis.looking_at(aim), from)
	bolt.direction = aim
	bolt.arm_with({"dmg": 1.0, "blast": 1.8, "speed": 34.0, "marks": 1})
	bolt.add_collision_exception_with(p)
	await _frames(40)
	check("bolt hits, damages and marks", is_instance_valid(e) and e.hp < hp0 and e.marks >= 1, "hp %.1f marks %d" % [e.hp, e.marks])
	await _clear()


## Each boss: rises, fights the player, telegraphs its moves, changes phase at its thresholds.
func _boss(id: String, path: String) -> void:
	_reset_player()
	var dangers := [0]
	var count_danger := func(n: Node) -> void:
		if n is MeshInstance3D and (n as MeshInstance3D).material_override is ShaderMaterial and ((n as MeshInstance3D).material_override as ShaderMaterial).shader == SpellFx.DANGER:
			dangers[0] += 1
	get_tree().node_added.connect(count_danger)
	var b := _spawn(path, Vector3(0, 0.1, -8.0))
	b.set_meta(&"boss_id", id)
	b.set_meta(&"test_no_floor", true)          # the signature-move floor (r35 solo bosses) is not under test here
	if b.has_method("on_engaged"):
		b.call("on_engaged", self)
	check(id + " is a boss", b.boss)
	check(id + " has a boss silhouette", b._rig != null and (b._rig.find_child("Boss_*", true, false) != null or b._rig.find_child("Flesh_*", true, false) != null or b._rig.find_children("*", "MeshInstance3D", true, false).size() > 0))   # a modelled boss is one skinned body (Flesh_body), not Boss_ parts
	var phases0 := int(b.get("phase")) if b.get("phase") != null else 1
	for i in 420:
		await get_tree().physics_frame
		p.gloom = minf(p.gloom, 50.0)
		# keep the player near but moving so moves resolve both ways
		p.global_position = Vector3(sin(float(i) * 0.02) * 3.0, p.global_position.y, -3.0 + cos(float(i) * 0.02) * 2.0)
	check(id + " telegraphs its moves", dangers[0] >= 2, "%d zones" % dangers[0])
	b.take_hit(float(b.max_hp) * 0.55, p)
	await _frames(150)
	var ph := int(b.get("phase")) if b.get("phase") != null else 0
	check(id + " enters phase 2 below half", ph >= 2 and ph > phases0, "phase %d" % ph)
	var minions := 0
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e != b and (e as Node).get_meta(&"summoned_by", "") == id:
			minions += 1
	check(id + " phase 2 calls its minions", minions >= 2 or id == "ascended_warden", "%d" % minions)
	if id == "ascended_warden":
		b.take_hit(float(b.max_hp) * 0.2, p)
		await _frames(120)
		check(id + " enters phase 3", int(b.get("phase")) >= 3)
	killed.clear()
	b.marks = 3
	b.take_hit(9999.0, p)
	check(id + " dies", killed.has(b))
	get_tree().node_added.disconnect(count_danger)
	await _frames(140)
	await _clear()
