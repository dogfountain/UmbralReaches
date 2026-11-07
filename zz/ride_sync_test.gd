extends Node3D
## The horse and its rider are drawn as one body at the same moment every rendered frame. A real Player
## rides a palfrey over a flat floor at walk, trot and gallop; for display/physics rates 120/60, 144/60
## and 60/60 each RENDERED frame logs the horse's interpolated root and the rider's drawn pelvis (the
## skinned body's pelvis bone), in the horse's frame, and asserts:
##   (a) the pelvis-to-saddle offset is continuous: no frame-to-frame step beyond the bounce's own speed,
##       and no tick-rate stutter (the second difference stays small)
##   (b) the pelvis never sinks below the saddle surface (the barrel)
##   (c) the horse root and the rider both move on every rendered frame (no duplicated frames)
##   godot --headless --path . res://zz/ride_sync_test.tscn

const HorseScript := preload("res://core/world/mount/horse.gd")
const WORLD := 1
const CONFIGS := [[120, 60], [144, 60], [60, 60]]
const GAITS := [["walk", 0.5, false], ["trot", 1.0, false], ["gallop", 1.0, true]]
const SETTLE := 2.0
const SPAN := 2.0
const MAX_REL_SPEED := 2.5          ## m/s: the rider's own motion against the saddle (post, bounce)
const MAX_ACCEL := 120.0            ## m/s^2: change of the rider's relative velocity between consecutive frames (a 3 Hz bounce of 7 cm is ~25)

var bad := 0
var p: Player
var horse: Node3D
var _log: Array = []
var _recording := false
var _warned := false


func _ready() -> void:
	Travel._busy = true
	process_priority = 100
	_floor()
	_run.call_deferred()


func _floor() -> void:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(40, 1.0, 1200)
	cs.shape = sh
	b.add_child(cs)
	add_child(b)
	b.position = Vector3(0, -0.5, -500)


func _spawn(breed: String) -> void:
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
	horse = HorseScript.new()
	horse.breed = breed
	add_child(horse)
	horse.global_position = Vector3(0, 0.0, 0)


func _clear() -> void:
	if is_instance_valid(horse):
		horse.queue_free()
	if is_instance_valid(p):
		p.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	for cfg: Array in CONFIGS:
		Engine.max_fps = int(cfg[0])
		Engine.physics_ticks_per_second = int(cfg[1])
		await _spawn("palfrey")
		await get_tree().create_timer(0.5).timeout
		horse.mount(p)
		await get_tree().create_timer(1.6).timeout
		for g: Array in GAITS:
			var fwd := Vector3(0, 0, -1)
			p.debug_drive(fwd * float(g[1]), bool(g[2]))
			await get_tree().create_timer(SETTLE).timeout
			_log.clear()
			_recording = true
			await get_tree().create_timer(SPAN).timeout
			_recording = false
			_check("%d/%d %s" % [cfg[0], cfg[1], g[0]], _log.duplicate())
			if horse.global_position.z < -380.0:
				horse.global_position = Vector3(0, 0, 0)
				horse.reset_physics_interpolation()
		p.debug_drive(Vector3.ZERO)
		await _clear()
	print("ride_sync_test: ", "FAIL %d" % bad if bad > 0 else "PASS")
	get_tree().quit(1 if bad > 0 else 0)


func _process(_dt: float) -> void:
	if not _recording or not is_instance_valid(horse) or not is_instance_valid(p):
		return
	var rig := p.get_node("Visual") as CharacterRig
	var hrig: Node3D = horse.get("_rig")
	var xf := hrig.global_transform
	var pel := Vector3.ZERO
	if rig.has_merged_body():
		# the skinned pelvis: the bone of the driver that carries the pelvis node (or its nearest ancestor)
		var sk: Skeleton3D = rig.get("_skel")
		var drivers: Array = rig.get("_drivers")
		var node: Node = rig.get("_pelvis")
		var bi := -1
		while node != null and node != rig and bi < 0:
			for i in drivers.size():
				if drivers[i] == node:
					bi = i
			node = node.get_parent()
		if bi >= 0:
			pel = sk.global_transform * sk.get_bone_pose(bi).origin
		else:
			pel = rig.global_position + Vector3.UP * CharacterRig.H_PELVIS
			if not _warned:
				_warned = true
				print("RIDE note: no pelvis bone, using the rig origin + H_PELVIS")
	else:
		pel = rig.global_position + Vector3.UP * CharacterRig.H_PELVIS
	var seat_top := xf.origin + Vector3.UP * (float(horse.get("_d").seat) + float(hrig.get("last_dy")))
	_log.append({
		"dt": get_process_delta_time(), "root": xf.origin, "pel": pel, "rel": xf.affine_inverse() * pel,
		"pel_y_rel": pel.y - seat_top.y, "dy": float(hrig.get("last_dy")), "rsx": float(horse.get("_rs").x),
		# both face -Z: the rider must face where the horse faces (a sign slip once sat the rider facing the tail)
		"face": (-rig.global_basis.z).normalized().dot((-xf.basis.z).normalized()),
	})


func _check(label: String, log: Array) -> void:
	var n := log.size()
	var max_step := 0.0
	var max_jerk := 0.0
	var min_y := 1e9
	var dup_root := 0
	var dup_rider := 0
	var prev_v := Vector3.ZERO
	for i in range(1, n):
		var a: Dictionary = log[i - 1]
		var b: Dictionary = log[i]
		var step: Vector3 = (b.rel as Vector3) - (a.rel as Vector3)
		var rate := step.length() / maxf(float(b.dt), 1e-4)
		max_step = maxf(max_step, rate)
		var v := step / maxf(float(b.dt), 1e-4)
		if i > 1:
			max_jerk = maxf(max_jerk, (v - prev_v).length() / maxf(float(b.dt), 1e-4))
		prev_v = v
		if (b.root as Vector3).distance_to(a.root as Vector3) < 1e-5:
			dup_root += 1
		if (b.pel as Vector3).distance_to(a.pel as Vector3) < 1e-5:
			dup_rider += 1
		min_y = minf(min_y, float(b.pel_y_rel))
	if OS.get_environment("RIDE_DUMP") == label:
		for i in mini(n, 60):
			var e: Dictionary = log[i]
			print("  f%d dt %.4f rel_y %.4f dy %.4f rsx %.4f" % [i, e.dt, (e.rel as Vector3).y, e.dy, e.rsx])
	var seat_pel := -float(HorseScript.SINK) + 0.02
	print("RIDE %-12s frames %d  max rel speed %.2f m/s  max accel %.0f m/s2  min pelvis-saddle %.1f cm  dup root %d rider %d" % [
		label, n, max_step, max_jerk, min_y * 100.0, dup_root, dup_rider])
	_ok(n >= int(SPAN * 40.0), "%s: only %d rendered frames" % [label, n])
	_ok(max_step <= MAX_REL_SPEED, "%s: the rider slides on the saddle at %.2f m/s" % [label, max_step])
	_ok(max_jerk <= MAX_ACCEL, "%s: the rider stutters against the horse (%.0f m/s2 against the saddle)" % [label, max_jerk])
	_ok(min_y >= seat_pel - 0.06, "%s: the pelvis sank %.1f cm below the saddle" % [label, min_y * 100.0])
	var min_face := 1.0
	for e: Dictionary in log:
		min_face = minf(min_face, float(e.face))
	_ok(min_face > 0.95, "%s: the rider does not face the horse's way (dot %.2f)" % [label, min_face])
	_ok(dup_root == 0, "%s: %d rendered frames did not move the horse" % [label, dup_root])
	_ok(dup_rider == 0, "%s: %d rendered frames did not move the rider" % [label, dup_rider])


func _ok(c: bool, msg: String) -> void:
	if not c:
		bad += 1
		print("FAIL ", msg)
