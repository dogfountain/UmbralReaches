extends Node
## Realm land module check (headless):
##   godot --headless --path . res://zz/realm_land_check.tscn -- --realm --realm-modules=land
## Loads the zone, waits for the Realm build, then asserts: Terrain/TerrainBody exist (old ones
## gone), ground flat (|y| <= 0.05) within r 8 of the spawn brazier, the kept core (rift, Ossuary,
## summit) equal to the old baked heights, paths level across, no holes over BOUNDS, pools present.
const Land := preload("res://core/world/realm/realm_land.gd")
var frames := 0
var main: Node
var bad := 0
var done := false


func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	frames += 1
	if done or frames < 200 or main == null or not main.has_meta("realm_built"):
		if frames > 3000 and not done:
			_fail("realm never built")
			_finish()
		return
	if main.get_node_or_null("Zone/Terrain") == null:
		return
	done = true
	_run()
	_finish()


func _fail(msg: String) -> void:
	bad += 1
	print("LAND FAIL ", msg)


func _finish() -> void:
	print("LAND_CHECK DONE bad=", bad)
	get_tree().quit()


func _ground(x: float, z: float) -> float:
	# a ray within ~1e-9 of a triangle edge can slip through Jolt's trimesh: nudge off the grid lines
	x += 0.0037
	z += 0.0029
	var space := (main as Node3D).get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for k in 32:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 150, z), Vector3(x, -80, z), 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return NAN
		if String((hit.collider as Node).name) == "TerrainBody":
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return NAN


func _hits(x: float, z: float) -> String:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var ex: Array[RID] = []
	var out := ""
	for k in 12:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 150, z), Vector3(x, -80, z), 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		out += "%s@%.2f " % [(hit.collider as Node).get_path(), (hit.position as Vector3).y]
		ex.append(hit.rid)
	return out


func _run() -> void:
	var zone := main.get_node("Zone")
	var terrain := zone.get_node_or_null("Terrain") as MeshInstance3D
	var body := zone.get_node_or_null("TerrainBody") as StaticBody3D
	if terrain == null or terrain.mesh == null or body == null:
		_fail("Terrain/TerrainBody missing")
		return
	if zone.get_node_or_null("TerrainOld") != null or zone.get_node_or_null("TerrainBodyOld") != null:
		_fail("old terrain not freed")
	if body.collision_layer != Layers.WORLD:
		_fail("TerrainBody layer %d" % body.collision_layer)
	var shapes := body.find_children("*", "CollisionShape3D", false, false)
	if shapes.size() != 1 or not ((shapes[0] as CollisionShape3D).shape is ConcavePolygonShape3D):
		_fail("TerrainBody needs one ConcavePolygonShape3D")
	print("LAND terrain verts=%d tris=%d" % [(terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
	if "--debug" in OS.get_cmdline_user_args():
		var arr := terrain.mesh.surface_get_arrays(0)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for k in vv.size():
			if vv[k].distance_to(Vector3(-20, vv[k].y, 24)) < 0.1 or vv[k].distance_to(Vector3(0, vv[k].y, 10)) < 0.1:
				print("LAND dbg ", vv[k], " col ", arr[Mesh.ARRAY_COLOR][k] if arr[Mesh.ARRAY_COLOR] != null else "-", " uv ", arr[Mesh.ARRAY_TEX_UV][k] if arr[Mesh.ARRAY_TEX_UV] != null else "-", " uv2 ", arr[Mesh.ARRAY_TEX_UV2][k] if arr[Mesh.ARRAY_TEX_UV2] != null else "-")
	# spawn flat
	var worst := 0.0
	var stamped := 0
	for r: float in [0.0, 2.0, 4.0, 6.0, 8.0]:
		for a in 16:
			var x := RealmLayout.SPAWN.x + cos(a * TAU / 16) * r
			var z := RealmLayout.SPAWN.z + sin(a * TAU / 16) * r
			var y := _ground(x, z)
			if absf(TerrainStamp.delta_at(x, z)) > 0.001:
				stamped += 1           # a later site stamp (the tavern's cut reaches x ~5.4) owns this point
				y = Land.height_at(x, z)
			if is_nan(y) or absf(y) > 0.05:
				if worst == 0.0:
					print("LAND spawn (%.1f,%.1f) y %s hits %s" % [x, z, y, _hits(x, z)])
				worst = maxf(worst, 99.0 if is_nan(y) else absf(y))
	print("LAND spawn worst |y| %.3f (%d of 80 points re-cut by a site stamp; checked pre-stamp)" % [worst, stamped])
	if worst > 0.05:
		_fail("spawn not flat: %.3f" % worst)
	# kept core = old heights (points clear of registered sites)
	var core_bad := 0
	var core_n := 0
	var core_worst := 0.0
	for p: Vector2 in [Vector2(-20, -60), Vector2(0, -40), Vector2(-10, -100), Vector2(24, -30), Vector2(-28, -20), Vector2(16, -70),
			Vector2(28, -100), Vector2(0, -118), Vector2(-26, -112), Vector2(10, -16), Vector2(-15, -85), Vector2(5, -124), Vector2(29, -50)]:
		var o := Land.old_height_at(p.x, p.y)
		var y := _ground(p.x, p.y)
		if is_nan(o):
			continue
		core_n += 1
		var dy := absf(y - o) if not is_nan(y) else 99.0
		core_worst = maxf(core_worst, dy)
		if dy > 0.03 and absf(TerrainStamp.delta_at(p.x, p.y)) < 0.001:
			core_bad += 1
			print("LAND core (%d,%d) old %.2f new %.2f" % [p.x, p.y, o, y])
	print("LAND core points %d worst %.3f" % [core_n, core_worst])
	if core_n == 0 or core_bad > 0:
		_fail("kept core differs from the old terrain (%d of %d)" % [core_bad, core_n])
	# paths: level across
	var cross_worst := 0.0
	var cross_where := ""
	var nsamp := 0
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		var w: float = path.w
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var dir := (b - a).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var segl := a.distance_to(b)
			var s := 3.0
			while s < segl - 3.0:
				var c := a + dir * s
				s += 4.0
				if Land.keep_weight(c.x, c.y) > 0.0 or absf(TerrainStamp.delta_at(c.x, c.y)) > 0.01:
					continue
				var l := c - nrm * w * 0.8
				var r2 := c + nrm * w * 0.8
				var hl := _ground(l.x, l.y)
				var hr := _ground(r2.x, r2.y)
				var slope := absf(hl - hr) / (w * 1.6)
				nsamp += 1
				if slope > cross_worst:
					cross_worst = slope
					cross_where = "%s (%.0f,%.0f)" % [path.id, c.x, c.y]
	print("LAND path cross-slope worst %.3f at %s over %d samples" % [cross_worst, cross_where, nsamp])
	if cross_worst > 0.1:
		_fail("path cross-slope %.3f at %s" % [cross_worst, cross_where])
	# no holes
	var holes := 0
	var b := RealmLayout.BOUNDS
	var x := b.position.x + 1.0
	var hmin := INF
	var hmax := -INF
	while x < b.end.x:
		var z := b.position.y + 1.0
		while z < b.end.y:
			var y := _ground(x, z)
			if is_nan(y):
				holes += 1
			else:
				hmin = minf(hmin, y)
				hmax = maxf(hmax, y)
			z += 4.0
		x += 4.0
	print("LAND holes %d, height range %.1f .. %.1f" % [holes, hmin, hmax])
	if holes > 0:
		_fail("%d holes in the terrain" % holes)
	if zone.get_node_or_null("FenWater") == null:
		_fail("no fen pools")
	for n in ["TerrainRingN", "TerrainRingS", "TerrainRingW", "TerrainRingE", "RealmBounds"]:
		if zone.get_node_or_null(n) == null:
			_fail("missing " + n)
