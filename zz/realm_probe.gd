extends Node
## Ground probe for the realm (bosses module): prints terrain/world heights at points of interest.
##   godot --headless --path . res://zz/realm_probe.tscn -- --realm [--realm-modules=land,rift,bosses]
var t := 0
var root: Node
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	root = main
	get_tree().root.add_child.call_deferred(main)
func _hit(x: float, z: float, top := 60.0) -> String:
	var sp := (root as Node3D).get_world_3d().direct_space_state
	var h := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -60, z), 1))
	if h.is_empty(): return "MISS"
	return "%.1f%s" % [(h.position as Vector3).y, "" if String((h.collider as Node).name).begins_with("Terrain") else "*" + String((h.collider as Node).name).left(6)]
func _physics_process(_d: float) -> void:
	t += 1
	if t < 600 and not root.has_meta("summit_dressed"):
		return
	if t % 60 != 0: return
	for spec: Array in [[26.0, 46.0, -74.0, -44.0, 2.0], [-80.0, -50.0, -28.0, 0.0, 4.0]]:
		print("GRID x %s..%s z %s..%s" % [spec[0], spec[1], spec[2], spec[3]])
		var z: float = spec[2]
		while z <= spec[3]:
			var line := "z%6.1f: " % z
			var x: float = spec[0]
			while x <= spec[1]:
				line += "%8s" % _hit(x, z)
				x += spec[4]
			print(line)
			z += spec[4]
	var sp := (root as Node3D).get_world_3d().direct_space_state
	for q3: Vector3 in [Vector3(-65.25, 6.2, -3.59), Vector3(-65.6, 6.3, -4.1), Vector3(-65.9, 6.4, -4.6)]:
		var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.6
		var q := PhysicsShapeQueryParameters3D.new(); q.shape = cap; q.collision_mask = 1
		q.transform = Transform3D(Basis.IDENTITY, q3)
		for r in sp.intersect_shape(q, 8):
			print("BLOCK ", q3, " ", (r.collider as Node).get_path())
	print("STAIR ", ThornHenge.stair_pts)
	for q2: Vector2 in [Vector2(-63.3, -4.4), Vector2(-64.0, -3.6), Vector2(-64.6, -4.5), Vector2(-65.25, -3.59), Vector2(-65.6, -4.1), Vector2(-65.9, -4.6), Vector2(-66.5, -4.0)]:
		var hits := ""
		var top := 30.0
		for i in 4:
			var h := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q2.x, top, q2.y), Vector3(q2.x, -20, q2.y), 1))
			if h.is_empty(): break
			hits += " %.2f:%s" % [(h.position as Vector3).y, String((h.collider as Node).name)]
			top = (h.position as Vector3).y - 0.05
		var hs := WorldLanes.site_at(q2)
		print("COLUMN ", q2, hits, " delta ", snappedf(TerrainStamp.delta_at(q2.x, q2.y), 0.01), " site ", hs.get("name", "-"), " floor ", WorldLanes.site_floor(hs, q2) if not hs.is_empty() else NAN)
	for st in WorldLanes.sites:
		print("SITE ", st.name, " ", st.rect)
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var p2 := Vector2(c.at.x, c.at.z)
		var near := WorldLanes.site_at(p2, 4.0)
		print("CAMPCHK %s path %.1f site4m %s ground %s" % [p2, RealmLayout.path_dist(p2), near.get("name", "-"), _hit(p2.x, p2.y, 80.0)])
	for pt: Vector2 in [Vector2(-5, -2), Vector2(-31, 4), Vector2(84, -36), Vector2(47, -55)]:
		print("SLOPE ", pt, " ", _hit(pt.x, pt.y, 80.0), " ", _hit(pt.x + 1.5, pt.y, 80.0), " ", _hit(pt.x - 1.5, pt.y, 80.0), " ", _hit(pt.x, pt.y + 1.5, 80.0), " ", _hit(pt.x, pt.y - 1.5, 80.0))
	for pt: Vector2 in [Vector2(4, -4), Vector2(0, -8), Vector2(-38, 8), Vector2(-34, 12), Vector2(78, -42), Vector2(72, -38), Vector2(-58, -4), Vector2(-62, -12), Vector2(34, -66), Vector2(44, -62)]:
		print("PT ", pt, " ", _hit(pt.x, pt.y), " macro ", snappedf(RealmLayout.macro_height(pt.x, pt.y), 0.1))
	get_tree().quit()
