extends Node
## r34 flora probe: what grows near a point (debugging a walk).  -- --at=x,z --r=4
const Flora := preload("res://core/world/realm/realm_flora.gd")
var main: Node
var done := false
func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(_d: float) -> void:
	if done or main == null or not main.has_meta("realm_done"):
		return
	done = true
	var at := Vector2(25, 3.6)
	var r := 5.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var v := a.trim_prefix("--at=").split(",")
			at = Vector2(float(v[0]), float(v[1]))
		elif a.begins_with("--r="):
			r = float(a.trim_prefix("--r="))
	for it: Array in Flora.instance_list():
		var p: Vector3 = it[1]
		if Vector2(p.x, p.z).distance_to(at) < r:
			var sp := String(it[0])
			if not sp.begins_with("grass") and not sp.begins_with("flowers") and not sp.begins_with("heather"):
				print("PROBE ", it[0], " ", p)
	var space := (main as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, RealmLayout.ground(space, at.x, at.y) + 1.0, at.y))
	for h in space.intersect_shape(q, 64):
		print("PROBE body ", (h.collider as Node).get_path())
	get_tree().quit()
