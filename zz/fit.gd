extends Node
## Structure/terrain fit scan: floating edges (visible gap between a structure's underside and the
## ground at its footprint edge) and buried floors (terrain over a structure's walk surface).
const PROXY := 1 << 19
var f := 0
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _structure(mi: MeshInstance3D) -> bool:
	var q: Node = mi
	while q:
		var n := String(q.name)
		if q is CharacterBody3D or n in ["Terrain", "Player", "SkyFlare", "Sky", "Lava", "Forest", "Canopy", "CanopyFill", "Glimmers", "NightDress"] or n.begins_with("Area_"):
			return false
		q = q.get_parent()
	if not mi.is_visible_in_tree() or mi.mesh == null:
		return false
	var bb := mi.global_transform * mi.get_aabb()
	return bb.size.y > 0.15 and bb.size.x * bb.size.z > 0.2
func _physics_process(_d: float) -> void:
	f += 1
	if f != 40: return
	var root := get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
	var tb := root.find_child("TerrainBody", true, false) as CollisionObject3D
	var made := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not _structure(mi): continue
		var sh := mi.mesh.create_trimesh_shape()
		if sh == null: continue
		(sh as ConcavePolygonShape3D).backface_collision = true
		var b := StaticBody3D.new(); b.collision_layer = PROXY; b.collision_mask = 0
		b.set_meta("src", String(mi.get_path()).replace(String(root.get_path()) + "/", ""))
		var cs := CollisionShape3D.new(); cs.shape = sh; b.add_child(cs)
		root.add_child(b); b.global_transform = mi.global_transform
		made += 1
	print("FIT proxies ", made)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := (root as Node3D).get_world_3d().direct_space_state
	var float_by := {}
	var bury_by := {}
	var step := 1.0
	var x := -45.0
	while x <= 45.0:
		var z := -100.0
		while z <= 45.0:
			var tr := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 70, z), Vector3(x, -40, z), Layers.WORLD, []))
			var th := NAN
			var tq := PhysicsRayQueryParameters3D.create(Vector3(x, 70, z), Vector3(x, -40, z), Layers.WORLD)
			var excl: Array[RID] = []
			for _g in 8:
				tq.exclude = excl
				var hh := space.intersect_ray(tq)
				if hh.is_empty(): break
				if hh.collider == tb: th = hh.position.y; break
				excl.append((hh.collider as CollisionObject3D).get_rid())
			if not is_nan(th):
				# underside above the ground: ray up from just above the terrain
				var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, th + 0.02, z), Vector3(x, th + 2.5, z), PROXY))
				if up and (up.normal as Vector3).y < -0.7:
					var gap: float = up.position.y - th
					if gap > 0.06 and gap < 2.4:
						# only at a footprint edge: some neighbour column has no structure above ground
						var edge := false
						for o: Vector2 in [Vector2(step, 0), Vector2(-step, 0), Vector2(0, step), Vector2(0, -step)]:
							var nu := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + o.x, th + 0.02, z + o.y), Vector3(x + o.x, th + 3.0, z + o.y), PROXY))
							if nu.is_empty(): edge = true
						if edge:
							var src := String(up.collider.get_meta("src", "?"))
							var e: Array = float_by.get(src, [0, 0.0, Vector3.ZERO])
							e[0] += 1
							if gap > e[1]: e[1] = gap; e[2] = Vector3(x, th, z)
							(e as Array).append(Vector2(x, z))
							float_by[src] = e
				# buried: a structure's top surface within 0.6 m under the terrain
				var dn := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, th - 0.02, z), Vector3(x, th - 0.6, z), PROXY))
				if dn and absf((dn.normal as Vector3).y) > 0.7:
					var src2 := String(dn.collider.get_meta("src", "?"))
					var e2: Array = bury_by.get(src2, [0, 0.0, Vector3.ZERO])
					e2[0] += 1
					var dd: float = th - dn.position.y
					if dd > e2[1]: e2[1] = dd; e2[2] = Vector3(x, th, z)
					bury_by[src2] = e2
			z += step
		x += step
	for k in float_by:
		print("FLOAT ", k, " cells=", float_by[k][0], " max_gap=", snappedf(float_by[k][1], 0.01), " at ", float_by[k][2].snapped(Vector3.ONE * 0.1), " cells: ", (float_by[k] as Array).slice(3, 15))
	for k in bury_by:
		print("BURY ", k, " cells=", bury_by[k][0], " max_depth=", snappedf(bury_by[k][1], 0.01), " at ", bury_by[k][2].snapped(Vector3.ONE * 0.1))
	get_tree().quit()
