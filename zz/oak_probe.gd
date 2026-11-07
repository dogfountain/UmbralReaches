extends Node
var main: Node
var frames := 0
var done := false
func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(_d: float) -> void:
	frames += 1
	if done or frames < 900 or not main.has_meta("realm_built") or main.get_node_or_null("Zone/Terrain") == null:
		return
	done = true
	var space := (main as Node3D).get_world_3d().direct_space_state
	var oak: Node = null
	for n in main.find_children("*oak*", "Node3D", true, false):
		print("cand ", n.get_path())
		if oak == null and String(n.name).begins_with("Poi_r37s_oak"):
			oak = n
	if oak == null:
		get_tree().quit(1)
		return
	print("OAK node ", oak.get_path(), " pos ", (oak as Node3D).global_position)
	for r in [0.0, 3.0, 6.0, 10.0, 15.0, 20.0, 30.0]:
		var s := ""
		for a in 8:
			var an := TAU * a / 8.0
			s += " %.1f/%.1f" % [tground(space, -70.0 + sin(an) * r, 206.0 + cos(an) * r), RealmLayout.macro_height(-70.0 + sin(an) * r, 206.0 + cos(an) * r)]
		print("RING r=", r, s)
	var oy := (oak as Node3D).global_position.y
	for part in ["Trunk", "Roots"]:
		var mi := oak.get_node(part) as MeshInstance3D
		var lows := {}
		for v in mi.mesh.get_faces():
			var w := mi.global_transform * v
			var rb := int(Vector2(w.x + 70.0, w.z - 206.0).length() / 2.0)
			lows[rb] = minf(lows.get(rb, 999.0), w.y - oy)
		var ks := lows.keys()
		ks.sort()
		for rb in ks:
			var ts := 0.0
			var lo := 999.0
			var hi := -999.0
			for a in 16:
				var an := TAU * a / 16.0
				var g := tground(space, -70.0 + sin(an) * (rb * 2.0 + 1.0), 206.0 + cos(an) * (rb * 2.0 + 1.0)) - oy
				ts += g / 16.0
				lo = minf(lo, g)
				hi = maxf(hi, g)
			print("PROFILE %s r %d-%d lowest mesh %.2f ground mean %.2f min %.2f max %.2f" % [part, rb * 2, rb * 2 + 2, lows[rb], ts, lo, hi])
	var cols := {}
	for mi in oak.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		print(" mesh ", m.name, " vis ", m.visible, " aabb ", m.global_transform * m.get_aabb())
		if m.name == "OakFar" or m.name == "Crown" or m.name == "Limbs" or m.name == "Stair":
			continue
		for v in m.mesh.get_faces():
			var w := m.global_transform * v
			var k := Vector2i(roundi(w.x * 2.0), roundi(w.z * 2.0))
			if not cols.has(k) or cols[k] > w.y:
				cols[k] = w.y
	var rows := []
	for k: Vector2i in cols:
		var g := tground(space, k.x * 0.5, k.y * 0.5)
		rows.append([cols[k] - g, k, g])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(25, rows.size()):
		print("hi gap %.2f at %s ground %.2f" % [rows[i][0], rows[i][1] * 0.5, rows[i][2]])
	for i in mini(8, rows.size()):
		print("lo gap %.2f at %s" % [rows[rows.size() - 1 - i][0], rows[rows.size() - 1 - i][1] * 0.5])
	get_tree().quit(0)


func tground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var ex: Array[RID] = []
	for i in 12:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 120, z + 0.0029), Vector3(x + 0.0037, -60, z + 0.0029), 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return NAN
