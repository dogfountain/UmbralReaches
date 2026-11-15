extends Node3D
## Back-to-back microbenchmark in one process (machine load cancels in the ratio): the camera's six sight rays, the old
## loop against the early-out one (core/player/player_camera.gd _shoulder_tick), and an enemy's per-tick
##   godot --headless --path . res://zz/path_bench.tscn  -> "BENCH rays old/new us ... ratio", "BENCH scale ..."
const N := 4000
const SIGHT_HIDDEN := 4


func _ready() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	cs.position.y = -0.5
	body.add_child(cs)
	for i in 30:
		var cs2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = Vector3(1.5, 4, 1.5)
		cs2.shape = b2
		cs2.position = Vector3(randf_range(-10, 10), 2, randf_range(-10, 10))
		body.add_child(cs2)
	add_child(body)


func _physics_process(_d: float) -> void:
	var space := get_world_3d().direct_space_state
	var r := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Layers.WORLD)
	var cam_at := Vector3(0.5, 2.0, 12.0)
	var body := Vector3(0.2, 0.0, 0.0)
	var across := Vector3.RIGHT
	var t_old := 0
	var t_new := 0
	var sink := 0
	for round in 6:
		var t0 := Time.get_ticks_usec()
		for n in N:
			var hidden := 0
			for y: float in [1.1, 1.6]:
				for s: float in [-0.3, 0.0, 0.3]:
					r.from = cam_at
					r.to = body + Vector3.UP * y + across * s
					if not space.intersect_ray(r).is_empty():
						hidden += 1
			sink += 1 if hidden >= SIGHT_HIDDEN else 0
		var t1 := Time.get_ticks_usec()
		for n in N:
			var hidden := 0
			var clear := 0
			for y: float in [1.1, 1.6]:
				for s: float in [-0.3, 0.0, 0.3]:
					if hidden >= SIGHT_HIDDEN or clear > 6 - SIGHT_HIDDEN:
						break
					r.from = cam_at
					r.to = body + Vector3.UP * y + across * s
					if space.intersect_ray(r).is_empty():
						clear += 1
					else:
						hidden += 1
			sink += 1 if hidden >= SIGHT_HIDDEN else 0
		var t2 := Time.get_ticks_usec()
		t_old += t1 - t0
		t_new += t2 - t1
	print("BENCH rays old %.2f us  new %.2f us per call  ratio %.2f  (%d)" % [t_old / float(6 * N), t_new / float(6 * N), t_new / float(t_old), sink])
	var node := Node3D.new()
	add_child(node)
	var t_a := 0
	var t_b := 0
	for round in 6:
		var u0 := Time.get_ticks_usec()
		for n in N * 10:
			node.scale = Vector3(1.0, 1.0, 1.0)
		var u1 := Time.get_ticks_usec()
		for n in N * 10:
			var sc := Vector3(1.0, 1.0, 1.0)
			if sc != node.scale:
				node.scale = sc
		var u2 := Time.get_ticks_usec()
		t_a += u1 - u0
		t_b += u2 - u1
	print("BENCH scale assign %.3f us  compare %.3f us per call  ratio %.2f" % [t_a / float(60 * N), t_b / float(60 * N), t_b / float(t_a)])
	get_tree().quit()
