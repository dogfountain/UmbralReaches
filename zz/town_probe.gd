extends Node
## What stands at some points once the Realm is built: the colliders in a 0.4 m sphere 0.9 m over the ground, the
## ground, the water. For laying walks and props in a town.
##   HOME=<scratch> godot --headless --path . res://zz/town_probe.tscn -- --at=x,z --at=x,z ...
const Land := preload("res://core/world/realm/realm_land.gd")
var main: Node
var pts: Array[Vector2] = []


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var p := a.trim_prefix("--at=").split(",")
			pts.append(Vector2(float(p[0]), float(p[1])))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(1.0).timeout
	var space := (main as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.4
	q.shape = s
	for p: Vector2 in pts:
		var gy := RealmLayout.ground(space, p.x, p.y)
		q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, gy + 0.9, p.y))
		var names: Array[String] = []
		for h: Dictionary in space.intersect_shape(q, 8):
			var c := h.collider as Node
			names.append(String(c.get_path()).replace("/root/Main/", "") if c else "?")
		print("TOWN_PROBE (%.1f, %.1f) ground %.2f water %s (%.2f) path %.1f: %s" % [p.x, p.y, gy, Land.in_water(p.x, p.y), Land.water_y_at(p.x, p.y), RealmLayout.path_dist(p), names])
	get_tree().quit()
