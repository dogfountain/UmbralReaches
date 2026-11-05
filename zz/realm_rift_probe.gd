extends Node
## Probe: dumps the rift heightfield (first hit, terrain only) as a character map; "~" = under the lava.
var t := 0
var main: Node
func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(_d: float) -> void:
	t += 1
	if main == null or not main.has_meta("summit_dressed"):
		return
	if t % 60 != 0: return
	var space := (main as Node3D).get_world_3d().direct_space_state
	var z := 6.0
	while z >= -140.0:
		var line := "z%5.0f " % z
		var x := -56.0
		while x <= 56.0:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -40, z), 1)
			var y := NAN
			var ex: Array[RID] = []
			for k in 8:
				q.exclude = ex
				var hit := space.intersect_ray(q)
				if hit.is_empty(): break
				if String((hit.collider as Node).name).begins_with("Terrain"):
					y = (hit.position as Vector3).y
					break
				ex.append(hit.rid)
			line += "   ." if is_nan(y) else ("%3d%s" % [roundi(y), "~" if y < -15.5 else " "])
			x += 4.0
		print(line)
		z -= 4.0
	get_tree().quit()
