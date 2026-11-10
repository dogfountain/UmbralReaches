extends Node3D
## The Upward Falls' steps, climbed by the real Player on a synthetic course (no main.tscn: ~10 s). The weir's seven
## treads (core/world/realm/wonders/upward_falls.gd, tools/blender/wonder_upward_falls.py: tops 0.95 + 0.55 k, 1.5 m
## treads, then the crest at 4.8) are boxes of the model's own dimensions, climbed from the bank (1.1) by a bot that
## walks north and presses jump when a riser is 0.45 m ahead. Passes when it stands on the crest with single jumps.
##   godot --headless --path . res://zz/upward_steps_course.tscn
## Ends: UPWARD STEPS PASS (jumps=N, t=T)  /  UPWARD STEPS FAIL reason

const WORLD := 1
const TREAD := 1.5
const N_STEP := 7
const CREST := 4.8
const Z0 := -4.0                       ## the first riser (the bank's edge)
var p: Player
var t := 0.0
var jumps := 0
var jumped_at := -9.0
var done := false


func _box(pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	b.add_child(mi)
	add_child(b)
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
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.position.y = 1.55
	pl.add_child(rig)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	rig.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	arm.position.x = 0.5
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	arm.shape = sph
	arm.spring_length = 4.4
	arm.margin = 0.25
	pitch.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	cam.fov = 58.0
	arm.add_child(cam)
	pl.position = Vector3(0, 0.1, 0)
	add_child(pl)
	p = pl as Player
	pass



func _ready() -> void:
	Travel._busy = true
	process_physics_priority = -10
	_box(Vector3(0, 0.1, Z0 * 0.5 + 8.0), Vector3(14, 2.0, 20.0))                      # the bank (top 1.1) to z = Z0 + ...
	_box(Vector3(0, -0.5, Z0 + 2.0), Vector3(14, 1.0, 12.0))
	for k in N_STEP:
		var top := 0.95 + (CREST - 0.95) * float(k) / float(N_STEP)
		var zc := Z0 - TREAD * (float(k) + 0.5)
		_box(Vector3(0, (top - 3.0) * 0.5, zc), Vector3(14, top + 3.0, TREAD))
	_box(Vector3(0, (CREST - 3.0) * 0.5, Z0 - TREAD * float(N_STEP) - 2.5), Vector3(14, CREST + 3.0, 5.0))
	_spawn_player()
	p.global_position = Vector3(0, 1.2, Z0 + 3.0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.set_view(0.0, -0.2)


func _physics_process(delta: float) -> void:
	if p == null or done or Engine.get_physics_frames() < 30:
		return
	t += delta
	p.debug_drive(Vector3(0, 0, -1), false)
	var idx := int(floorf((Z0 - p.global_position.z) / TREAD)) if p.global_position.z < Z0 else -1
	var riser := Z0 - TREAD * float(idx + 1)
	if p.is_grounded() and p.global_position.z - riser < 0.5 and t - jumped_at > 0.5 and idx < N_STEP:
		Input.action_press("jump")
		jumped_at = t
		jumps += 1
	elif t - jumped_at > 0.2:
		Input.action_release("jump")
	if p.global_position.y > CREST - 0.1 and p.is_grounded() and p.global_position.z < Z0 - TREAD * float(N_STEP) + 0.2:
		done = true
		print("UPWARD STEPS %s (jumps=%d, t=%.1f s, y=%.2f)" % ["PASS" if jumps <= N_STEP + 2 else "FAIL too many jumps", jumps, t, p.global_position.y])
		get_tree().quit()
	elif t > 25.0:
		done = true
		print("UPWARD STEPS FAIL never reached the crest (y=%.2f z=%.2f jumps=%d)" % [p.global_position.y, p.global_position.z, jumps])
		get_tree().quit()
