extends Node
## Lists the colliders around a point once the Realm is built (fresh or isolated save):
##   HOME=<scratch> godot --headless --path . res://zz/probe_point.tscn -- --at=x,y,z [--r=1.0]
var main: Node
var at := Vector3.ZERO
var r := 1.0
func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var p := a.trim_prefix("--at=").split(",")
			at = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("--r="):
			r = float(a.trim_prefix("--r="))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(1.0).timeout
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = r
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = 0xFFFFFFFF
	q.collide_with_areas = false
	for h in (main as Node3D).get_world_3d().direct_space_state.intersect_shape(q, 16):
		var n: Node = h.collider
		print("PROBE hit %s  layer %d  at %s" % [n.get_path(), int(n.get("collision_layer")), (n as Node3D).global_position if n is Node3D else Vector3.ZERO])
	# critF: every surface straight down through the point (top to bottom), all layers
	var from := at + Vector3.UP * 40.0
	var excl: Array[RID] = []
	for _i in 8:
		var rq := PhysicsRayQueryParameters3D.create(from, at + Vector3.DOWN * 60.0, 0xFFFFFFFF, excl)
		var rh := (main as Node3D).get_world_3d().direct_space_state.intersect_ray(rq)
		if rh.is_empty():
			break
		var rn: Node = rh.collider
		print("PROBE down y %.2f  %s  layer %d" % [(rh.position as Vector3).y, rn.get_path(), int(rn.get("collision_layer"))])
		excl.append(rh.rid)
		from = (rh.position as Vector3) + Vector3.DOWN * 0.01
	print("PROBE done")
	get_tree().quit()
