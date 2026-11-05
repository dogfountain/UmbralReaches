extends Node3D
## r29 critique probe (agent A, combat). A bare floor, a real Player, every kind and boss in turn.
##   HOME=<scratch>/home godot --headless --path . res://zz/critA_probe.tscn [-- --part=tells,ttk]
## tells  each kind fights a still player for TELL_SECS: every hit is matched to the latest ground
##        telegraph (red) made before it; "lead" is red-to-hit (the reaction window), a hit with no
##        red in the 2.5 s before it is "blind" (projectiles excepted: the spitter's orb is the tell)
## ttk    each kind (and boss) against a player who only aims and fires: Rift Bolt held ("bolt"),
##        or a full Ember Lance whenever ready and bolts between ("lance+bolt"). Time to kill,
##        shots, hit rate, and Gloom taken while standing still (the cost of facetanking).
## Prints table rows "PROBE <part> ..." and ends "PROBE DONE". Saves held (Travel._busy).

const KINDS := {
	"wretch": "res://core/enemy/wretch.gd", "husk": "res://core/enemy/husk.gd",
	"crawler": "res://core/enemy/crawler.gd", "leaper": "res://core/enemy/leaper.gd",
	"ossuant": "res://core/enemy/ossuant.gd", "spitter": "res://core/enemy/spitter.gd",
	"bulwark": "res://core/enemy/bulwark.gd", "chanter": "res://core/enemy/chanter.gd",
	"burrower": "res://core/enemy/burrower.gd", "mite": "res://core/enemy/mite.gd",
}
const BOSSES := {
	"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd",
	"ascended_warden": "res://core/enemy/ascended_warden.gd",
	"elite_hobb": "res://core/life/encounters/elite_hobb.gd", "elite_old_sunk": "res://core/life/encounters/elite_old_sunk.gd",
}
const TELL_SECS := 14.0
const TTK_CAP := 30.0
const BOSS_CAP := 90.0

var p: Player
var _dangers: Array = []          ## [msec, MeshInstance3D]
var _hurts: Array = []            ## [msec, amount]
var _parts := ["tells", "ttk"]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			_parts = a.substr(7).split(",")
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)
	var pool := BoltPool.new()
	pool.name = "BoltPool"
	add_child(pool)
	p = _make_player()
	Events.player_hurt.connect(func(a: float, _f: Vector3) -> void: _hurts.append([Time.get_ticks_msec(), a]))
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is MeshInstance3D and (n as MeshInstance3D).material_override is ShaderMaterial \
				and ((n as MeshInstance3D).material_override as ShaderMaterial).shader == SpellFx.DANGER:
			_dangers.append([Time.get_ticks_msec(), n]))
	# a hard cap: never hang
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("PROBE TIMEOUT")
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
	p.gloom = 0.0
	p._hurt_grace_until = 0.0
	p._evade_t = 0.0
	p.set_view(0.0, 0.0)


func _clear() -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	for s in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
		(s as Node).queue_free()
	await _frames(20)


func _run() -> void:
	await _frames(10)
	if _parts.has("tells"):
		print("PROBE tells  kind        hits  blind  lead_min  lead_med  gloom/10s")
		for k: String in KINDS:
			await _tells(k, KINDS[k])
		for b: String in BOSSES:
			await _tells(b, BOSSES[b])
	if _parts.has("ttk"):
		print("PROBE ttk    kind            build        ttk_s  shots  hp    dps   gloom_taken")
		for k: String in KINDS:
			await _ttk(k, KINDS[k], "bolt", TTK_CAP)
			await _ttk(k, KINDS[k], "lance+bolt", TTK_CAP)
		for b: String in BOSSES:
			await _ttk(b, BOSSES[b], "bolt", BOSS_CAP)
			await _ttk(b, BOSSES[b], "lance+bolt", BOSS_CAP)
	print("PROBE DONE")
	get_tree().quit(0)


func _tells(kind: String, path: String) -> void:
	_reset_player()
	_dangers.clear()
	_hurts.clear()
	var e := _spawn(path, Vector3(0, 0.1, -6.0))
	if e.boss:
		e.set_meta(&"boss_id", kind)
		if e.has_method("on_engaged"):
			e.call("on_engaged", self)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(TELL_SECS * 1000.0):
		await get_tree().physics_frame
		p.gloom = 0.0
		p.global_position = Vector3(0.0, p.global_position.y, 0.0)
		if not is_instance_valid(e):
			break
	var leads: Array[float] = []
	var blind := 0
	var total := 0.0
	for h: Array in _hurts:
		total += float(h[1])
		var best := -1
		for d: Array in _dangers:
			if int(d[0]) <= int(h[0]) and int(h[0]) - int(d[0]) <= 2500:
				best = maxi(best, int(d[0]))
		if best < 0:
			blind += 1
		else:
			leads.append((int(h[0]) - best) * 0.001)
	leads.sort()
	var lmin := leads[0] if not leads.is_empty() else -1.0
	var lmed := leads[leads.size() / 2] if not leads.is_empty() else -1.0
	print("PROBE tells  %-10s  %4d  %5d  %8.2f  %8.2f  %9.1f" % [kind, _hurts.size(), blind, lmin, lmed, total / TELL_SECS * 10.0])
	await _clear()


func _ttk(kind: String, path: String, build: String, cap_s: float) -> void:
	_reset_player()
	_hurts.clear()
	var e := _spawn(path, Vector3(0, 0.1, -10.0))
	var max_hp := e.max_hp
	if e.boss:
		e.set_meta(&"boss_id", kind)
		if e.has_method("on_engaged"):
			e.call("on_engaged", self)
	var book := p.skills()
	var t0 := Time.get_ticks_msec()
	var shots := 0
	var hits := 0
	var hp_last := e.hp
	var taken := 0.0
	var dead := false
	var lance_hold := 0.0
	while Time.get_ticks_msec() - t0 < int(cap_s * 1000.0):
		await get_tree().physics_frame
		for h: Array in _hurts:
			taken += float(h[1])
		_hurts.clear()
		p.gloom = 0.0
		if not is_instance_valid(e) or not e.is_alive():
			dead = true
			break
		if e.hp < hp_last - 0.001:
			hits += 1
		hp_last = e.hp
		var chest := e.global_position + Vector3.UP * (e.hp_bar_y * 0.55)
		var cam := p.global_position + Vector3.UP * 1.9
		var to := chest - cam
		p.set_view(atan2(-to.x, -to.z), clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 1.2))
		if book == null:
			continue
		if e.has_method("is_burrowed") and bool(e.call("is_burrowed")):
			continue
		if build == "lance+bolt" and book.cooldown_left(1) <= 0.0:
			lance_hold += get_physics_process_delta_time()
			if lance_hold >= 0.9:
				lance_hold = 0.0
				if book.try_cast(1, 1.0, true):
					shots += 1
			continue
		if book.try_cast(0, 0.0, true):
			shots += 1
	var secs := (Time.get_ticks_msec() - t0) * 0.001
	print("PROBE ttk    %-15s %-11s  %5s  %5d  %4d  %4.1f  %11.0f" % [kind, build, ("%.1f" % secs) if dead else ">%d" % int(cap_s), shots, max_hp, float(max_hp) / maxf(secs, 0.01), taken])
	await _clear()
