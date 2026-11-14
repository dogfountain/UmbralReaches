extends Node3D
## Horse course: a synthetic track (no main.tscn) with a real Player riding a palfrey driven by
## debug_drive() through the horse's own drive(). Each leg is its own little place on one long floor;
## it prints "HORSE <leg> ok|FAIL ..." and "HORSE DONE pass=N fail=M", and quits nonzero on a FAIL.
##   godot --headless --path . res://zz/horse_course_test.tscn [-- --only=wall] [-- --breed=garron]
##   (the legs are split over two scenes, horse_course_test.tscn and horse_walls_test.tscn, for the suite's time limit)
## Legs: field / field_trot (scattered boxes 0.2-0.6 m), rocks (0.8-1.2 m boulders), stump (dead ahead), kerb
## (0.5 m), log (0.45 m across the way), log_high (1.4 m, angled: slides along it), steps (0.3 m risers),
## ring (grunts in the way: shouldered aside), boss (a boss blocks), wall / thin (real walls stop it, no
## tunnelling), pocket (wedged in a dead end: it frees itself).

const HorseScript := preload("res://core/world/mount/horse.gd")
const WORLD := 1
const DT := 1.0 / 60.0
const WRETCH := "res://core/enemy/wretch.gd"

## Which legs this scene runs (comma separated): the course is split over two scenes so each fits the suite's time limit.
@export var legs_csv := "field,rocks,stump,kerb,log,log_high,steps"
var p: Player
var horse: Node3D
var root: Node3D
var only := ""
var breed := "palfrey"
var passed := 0
var failed := 0
# per-leg samples
var _rec := false
var _t := 0.0
var _speeds: Array[float] = []
var _pos: Array[Vector3] = []


func _ready() -> void:
	Travel._busy = true
	Engine.physics_ticks_per_second = 180      # 3x the speed, each tick still a 1/60 s step (time_scale 3 / 180)
	Engine.time_scale = 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a.begins_with("--breed="):
			breed = a.trim_prefix("--breed=")
	_box(Vector3(0, -0.5, -150), Vector3(80, 1, 400))
	_spawn_player()
	_run.call_deferred()


func _box(pos: Vector3, size: Vector3, rot := Vector3.ZERO, parent: Node = null) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	(parent if parent != null else self).add_child(b)
	b.position = pos
	b.rotation = rot


func _spawn_player() -> void:
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.set_script(load("res://core/player/player.gd"))
	pl.floor_max_angle = 0.80285144
	pl.floor_snap_length = 0.5
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
	var r := Node3D.new()
	r.name = "CameraRig"
	r.position.y = 1.55
	pl.add_child(r)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	r.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	pitch.add_child(arm)
	var pcam := Camera3D.new()
	pcam.name = "Camera"
	arm.add_child(pcam)
	pl.position = Vector3(0, 0.05, 2)
	add_child(pl)
	p = pl as Player


## A fresh horse at the origin facing -Z and an empty place for the leg's props.
func _begin() -> void:
	if is_instance_valid(horse):
		p.riding = null
		horse.queue_free()
	if is_instance_valid(root):
		root.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if p._hollowing:
		print("HORSE note: the rider was hollowed between legs")
	root = Node3D.new()
	add_child(root)
	horse = HorseScript.new()
	horse.breed = breed
	add_child(horse)
	horse.global_position = Vector3.ZERO
	horse.reset_physics_interpolation()


func _go() -> void:
	horse.mount(p)
	await _wait(1.5)


func _wait(sec: float) -> void:
	for i in int(sec / DT):
		await get_tree().physics_frame


func _physics_process(dt: float) -> void:
	if is_instance_valid(p):
		p.gloom = 0.0                    # the night's dark would fill the bar and hollow the rider mid-course
		p.wounds = 0.0
	if _rec and is_instance_valid(horse):
		_t += dt
		_speeds.append(float(horse.speed))
		_pos.append(horse.global_position)


## Drive `wish` at `sprint` until the horse's z reaches `goal_z` or `limit` seconds; samples are kept.
func _drive(wish: Vector3, sprint: bool, goal_z: float, limit: float) -> void:
	_speeds.clear()
	_pos.clear()
	_t = 0.0
	_rec = true
	p.debug_drive(wish, sprint)
	while _t < limit and horse.global_position.z > goal_z:
		await get_tree().physics_frame
	_rec = false
	p.debug_drive(Vector3.ZERO)


## The longest stretch (s) below `v` m/s once past z = `from_z` (the horse is at its gait by then).
func _stall(v: float, from_z := -20.0) -> float:
	var best := 0.0
	var run := 0.0
	for i in _speeds.size():
		if _pos[i].z > from_z:
			continue
		if _speeds[i] < v:
			run += DT
			best = maxf(best, run)
		else:
			run = 0.0
	return best


func _min_speed(from_z := -20.0) -> float:
	var m := INF
	for i in _speeds.size():
		if _pos[i].z <= from_z:
			m = minf(m, _speeds[i])
	return m if m < INF else 0.0


func _report(leg: String, ok: bool, msg: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("HORSE %-9s %s  %s" % [leg, "ok" if ok else "FAIL", msg])


func _avg_speed(z0: float, z1: float) -> float:
	var t0 := -1.0
	var t1 := -1.0
	for i in _pos.size():
		if t0 < 0.0 and _pos[i].z <= z0:
			t0 = float(i) * DT
		if t1 < 0.0 and _pos[i].z <= z1:
			t1 = float(i) * DT
	return (z0 - z1) / (t1 - t0) if t0 >= 0.0 and t1 > t0 else 0.0


func _run() -> void:
	await get_tree().physics_frame
	var gallop := float(HorseScript.DB.BREEDS[breed].gallop)
	var legs: PackedStringArray = legs_csv.split(",") if only == "" else PackedStringArray([only])
	for leg: String in legs:
		await _begin()
		await call("_leg_" + leg, gallop)
	print("HORSE DONE pass=%d fail=%d" % [passed, failed])
	print("horse_course_test: ", "FAIL %d" % failed if failed > 0 else "PASS")
	get_tree().quit(1 if failed > 0 else 0)


func _leg_field(gallop: float) -> void:
	_scatter(14)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -75.0, 14.0)
	var reached := horse.global_position.z <= -75.0
	var avg := _avg_speed(-30.0, -70.0)
	var stall := _stall(1.5, -30.0)
	_report("field", reached and avg >= 0.6 * gallop and stall < 0.4,
		"reached %s avg %.1f m/s (want >= %.1f) longest stall %.2f s (want < 0.4)" % [reached, avg, 0.6 * gallop, stall])


func _leg_field_trot(_gallop: float) -> void:
	_scatter(14)
	await _go()
	await _drive(Vector3(0, 0, -1), false, -75.0, 22.0)
	var trot := float(HorseScript.DB.BREEDS[breed].trot)
	var reached := horse.global_position.z <= -75.0
	var avg := _avg_speed(-30.0, -70.0)
	_report("field_trot", reached and avg >= 0.6 * trot and _stall(1.0, -30.0) < 0.4,
		"reached %s avg %.1f m/s (want >= %.1f) longest stall %.2f s" % [reached, avg, 0.6 * trot, _stall(1.0, -30.0)])


## Boulders 0.8-1.2 m high (taller than a step), 1.0-1.6 m across, spread over the way.
func _leg_rocks(gallop: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var h := rng.randf_range(0.8, 1.2)
		_cyl(Vector3(rng.randf_range(-3.0, 3.0), h * 0.5, -12.0 - float(i) * 4.5), rng.randf_range(0.5, 0.8), h)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -80.0, 20.0)
	var reached := horse.global_position.z <= -80.0
	var avg := _avg_speed(-30.0, -70.0)
	_report("rocks", reached and avg >= 0.5 * gallop and _stall(1.0, -20.0) < 0.5,
		"reached %s avg %.1f m/s (want >= %.1f) longest stall %.2f s (want < 0.5)" % [reached, avg, 0.5 * gallop, _stall(1.0, -20.0)])


## A stump dead ahead, the stick straight at it: round it, do not stand there.
func _leg_stump(gallop: float) -> void:
	_cyl(Vector3(0, 0.6, -50), 0.7, 1.2)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -65.0, 12.0)
	var reached := horse.global_position.z <= -65.0
	var m := _min_speed()
	_report("stump", reached and _stall(1.0) < 0.5,
		"reached %s min speed %.1f longest stall %.2f s (want < 0.5)" % [reached, m, _stall(1.0)])


func _scatter(seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 48:
		var h := rng.randf_range(0.2, 0.6)
		_box(Vector3(rng.randf_range(-3.0, 3.0), h * 0.5, -8.0 - float(i) * 1.3), Vector3(rng.randf_range(0.4, 1.0), h, rng.randf_range(0.4, 1.0)), Vector3(0, rng.randf() * TAU, 0), root)


func _cyl(pos: Vector3, r: float, h: float) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	b.add_child(cs)
	root.add_child(b)
	b.position = pos


func _leg_kerb(gallop: float) -> void:
	_box(Vector3(0, 0.25, -50), Vector3(30, 0.5, 6), Vector3.ZERO, root)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -65.0, 14.0)
	var reached := horse.global_position.z <= -65.0
	var m := _min_speed()
	_report("kerb", reached and m >= 0.5 * gallop, "reached %s min speed %.1f (want >= %.1f)" % [reached, m, 0.5 * gallop])


func _leg_log(gallop: float) -> void:
	_box(Vector3(0, 0.225, -50), Vector3(10, 0.45, 0.5), Vector3.ZERO, root)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -65.0, 14.0)
	var reached := horse.global_position.z <= -65.0
	var m := _min_speed()
	_report("log", reached and m >= 0.5 * gallop, "reached %s min speed %.1f (want >= %.1f)" % [reached, m, 0.5 * gallop])


func _leg_log_high(gallop: float) -> void:
	_box(Vector3(0, 0.7, -50), Vector3(8, 1.4, 0.6), Vector3(0, deg_to_rad(35.0), 0), root)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -70.0, 16.0)
	var reached := horse.global_position.z <= -70.0
	var inside := _inside(Vector3(0, 0.7, -50), Vector3(8, 1.4, 0.6), deg_to_rad(35.0), 0.0)
	var m := _min_speed()
	_report("log_high", reached and not inside and m >= 0.25 * gallop and _stall(1.0) < 0.5,
		"reached %s clipped %s min speed %.1f (want >= %.1f) stall %.2f" % [reached, inside, m, 0.25 * gallop, _stall(1.0)])


func _leg_steps(gallop: float) -> void:
	for i in 6:
		_box(Vector3(0, 0.15 * float(i + 1), -50.0 - float(i) * 1.2), Vector3(20, 0.3 * float(i + 1), 1.2), Vector3.ZERO, root)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -65.0, 14.0)
	var reached := horse.global_position.z <= -65.0
	var m := _min_speed()
	_report("steps", reached and m >= 0.4 * gallop, "reached %s min speed %.1f (want >= %.1f)" % [reached, m, 0.4 * gallop])


func _grunt(at: Vector3, boss := false) -> Enemy:
	var e := (load(WRETCH) as GDScript).new() as Enemy
	e.boss = boss
	root.add_child(e)
	e.global_position = at
	e.set_physics_process(false)             # stands where it is
	return e


func _leg_ring(gallop: float) -> void:
	var foes: Array[Enemy] = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		foes.append(_grunt(Vector3(sin(a) * 3.0, 0.1, -50.0 + cos(a) * 3.0)))
	for z in [-44.0, -50.0, -56.0]:
		foes.append(_grunt(Vector3(0.0, 0.1, z)))
	await _go()
	await _drive(Vector3(0, 0, -1), true, -70.0, 16.0)
	var reached := horse.global_position.z <= -70.0
	var m := _min_speed()
	var shoved := 0
	for e in foes:
		if e._knock.length() > 0.1:
			shoved += 1
	_report("ring", reached and m >= 0.35 * gallop and _stall(1.0) < 0.5,
		"reached %s min speed %.1f (want >= %.1f) stall %.2f shoved %d of %d" % [reached, m, 0.35 * gallop, _stall(1.0), shoved, foes.size()])


func _leg_boss(_gallop: float) -> void:
	_grunt(Vector3(0, 0.1, -50.0), true)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -80.0, 8.0)
	var closest := 99.0
	for q in _pos:
		closest = minf(closest, Vector2(q.x, q.z + 50.0).length())
	_report("boss", closest > 0.55 and horse.rider == p, "closest %.2f m to a boss's centre (want > 0.55), still riding %s" % [closest, horse.rider == p])


func _leg_wall(_gallop: float) -> void:
	_box(Vector3(0, 1.5, -50), Vector3(40, 3.0, 0.4), Vector3.ZERO, root)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -80.0, 8.0)
	var z := horse.global_position.z
	_report("wall", z > -49.8 and horse.rider == p, "stopped at z %.2f (wall face -49.8), still riding %s" % [z, horse.rider == p])


func _leg_thin(_gallop: float) -> void:
	_box(Vector3(0, 1.5, -50), Vector3(40, 3.0, 0.08), Vector3.ZERO, root)
	await _go()
	await _drive(Vector3(0, 0, -1), true, -80.0, 8.0)
	var z := horse.global_position.z
	_report("thin", z > -49.96, "stopped at z %.2f (wall face -49.96)" % z)


func _leg_pocket(_gallop: float) -> void:
	# a dead end 3 m wide, 6 m deep, the horse driven into the back of it and the stick held there
	_box(Vector3(-1.9, 1.5, -10), Vector3(0.4, 3.0, 12), Vector3.ZERO, root)
	_box(Vector3(1.9, 1.5, -10), Vector3(0.4, 3.0, 12), Vector3.ZERO, root)
	_box(Vector3(0, 1.5, -16.2), Vector3(4.2, 3.0, 0.4), Vector3.ZERO, root)
	await _go()
	await _drive(Vector3(0, 0, -1), false, -90.0, 5.0)
	var at_end := horse.global_position
	# keep the stick held into the back wall: it must back off or turn, by itself
	_speeds.clear()
	_pos.clear()
	_t = 0.0
	_rec = true
	p.debug_drive(Vector3(0, 0, -1), false)
	await _wait(7.0)
	_rec = false
	p.debug_drive(Vector3.ZERO)
	var moved := 0.0
	var t_free := -1.0
	for i in _pos.size():
		var d := Vector2(_pos[i].x - at_end.x, _pos[i].z - at_end.z).length()
		moved = maxf(moved, d)
		if t_free < 0.0 and d > 0.5:
			t_free = float(i) * DT
	_report("pocket", horse.rider == p and moved > 0.8 and t_free >= 0.0 and t_free < 2.5,
		"freed itself %.2f m from where it jammed (want > 0.8), first 0.5 m after %.2f s (want < 2.5), stick held throughout (jammed at z %.2f)" % [moved, t_free, at_end.z])


func _inside(c: Vector3, size: Vector3, yaw: float, margin: float) -> bool:
	for q in _pos:
		var l := Basis(Vector3.UP, yaw).inverse() * (q - c)
		if absf(l.x) < size.x * 0.5 - margin and absf(l.z) < size.z * 0.5 - margin and q.y < c.y + size.y * 0.5 - 0.1:
			return true
	return false
