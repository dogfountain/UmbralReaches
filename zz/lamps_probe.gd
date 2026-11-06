extends Node
const Land := preload("res://core/world/realm/realm_land.gd")
## Working probe for the lamps: structure facts and the placements' results, headless.
##   godot --headless --path . res://zz/lamps_probe.tscn
var main: Node
var t := 0.0
var done := false


func _ready() -> void:
	Travel.set("_busy", true)
	get_window().size = Vector2i(800, 500)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _stack(sp: PhysicsDirectSpaceState3D, x: float, z: float) -> String:
	var out := ""
	var from := Vector3(x, 60.0, z)
	for i in 8:
		var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(x, -30.0, z), 17))
		if hit.is_empty():
			break
		var p: Vector3 = hit.position
		out += " %.1f(%s)" % [p.y, String((hit.collider as Node).name).left(14)]
		from = p + Vector3(0, -0.05, 0)
	return out


func _process(d: float) -> void:
	t += d
	if t > 110.0:
		OS.kill(OS.get_process_id())
	if done or main == null or not main.has_meta("realm_done") or t < 3.0:
		return
	done = true
	var sp := (main as Node3D).get_world_3d().direct_space_state
	var names := {}
	for n in main.find_children("*", "Node3D", true, false):
		var m := n as Node3D
		if Vector2(m.global_position.x + 123.0, m.global_position.z + 36.0).length() < 16.0:
			var key := "%s <- %s" % [String(m.name).left(26), String(m.get_parent().name).left(26)]
			names[key] = int(names.get(key, 0)) + 1
	for k: String in names:
		print("NM ", k, " x", names[k])
	print("== road lamps")
	var LK := load("res://core/world/realm/lore/lore_kit.gd") as GDScript
	print("COLD ", LK.get("cold_lamps"), LK.get("cold_yaws"))
	for l in get_tree().get_nodes_in_group(&"lamp"):
		print("LAMP %s %s %s" % [l.get("lamp_id"), l.get("look"), (l as Node3D).global_position.snapped(Vector3.ONE * 0.1)])
	print("INTERACTABLES ", get_tree().get_nodes_in_group(Groups.INTERACTABLE).size())
	OS.kill(OS.get_process_id())
