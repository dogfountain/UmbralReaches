extends Node
## Props stand on the ground. The big things placed on the terrain (the Grandmother Oak, the trees,
## the edge cliffs and boulders, the henge's stones and menhirs, the Hierarch statue) have the lowest
## vertices of their mesh sampled against the terrain's collision, and none may hang more than MAX_GAP
## over it. Trees are judged as a population (a few stand on cliffs and ravine banks, where the land
## itself is the problem), the hand-placed things one by one.
## Run: HOME=<scratch> godot --headless --path . res://zz/grounded_test.tscn [-- --verbose]
const Footing := preload("res://core/world/footing.gd")
const MAX_GAP := 0.05
const TREE_KINDS := ["oak", "pine", "snag", "windtree", "yew", "birch", "willow", "cypress"]
const TREE_SHARE := 0.15              ## at most this share of a kind's trees may be over MAX_GAP
const TREE_WORST := 2.5               ## and none further (a trunk on a cliff face)
const OAK_HOLLOW_R := 4.5
const OAK_CELL_SHARE := 0.06          ## of the cells may stand over MAX_GAP (a root laid on a 2 m grid of ground) ...
const OAK_CELL_WORST := 0.6           ## ... and none over this
const OAK_ROOT_BAND := 1.0            ## wood this near the ground is on it; higher arches over it (the doorway)

var main: Node
var frames := 0
var done := false
var verbose := false
var fails := 0


func _ready() -> void:
	verbose = "--verbose" in OS.get_cmdline_user_args()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	frames += 1
	if done:
		return
	if frames > 3600 * 3 and not main.has_meta("realm_built"):
		print("GROUNDED FAIL realm never built")
		get_tree().quit(1)
		return
	if frames < 900 or not main.has_meta("realm_built") or main.get_node_or_null("Zone/Terrain") == null:
		return
	done = true
	var space := (main as Node3D).get_world_3d().direct_space_state
	if verbose:
		for z in range(190, 204, 1):
			var row := ""
			for x in range(-78, -62, 2):
				row += " %.2f" % _ground(space, float(x), float(z))
			print("GROUNDED row z=", z, row)
	_oak(space)
	_edge_rocks(space)
	_trees(space)
	_stones(space)
	print("GROUNDED DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> void:
	fails += 1
	print("GROUNDED FAIL ", msg)


## The terrain's own height at (x, z): rays pass through props to the ground. NAN where there is none.
func _ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var ex: Array[RID] = []
	for i in 12:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 160.0, z + 0.0029), Vector3(x + 0.0037, -60.0, z + 0.0029), 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return NAN


## [worst gap, where] of a mesh's lowest points (Footing.base_points) turned by `xf` over the terrain.
func _foot_gap(space: PhysicsDirectSpaceState3D, mesh: Mesh, xf: Transform3D) -> Array:
	var worst := -99.0
	var at := Vector3.ZERO
	for v in Footing.base_points(mesh):
		var w := xf * v
		var g := _ground(space, w.x, w.z)
		if is_nan(g):
			continue
		if w.y - g > worst:
			worst = w.y - g
			at = w
	return [worst, at]


## The Oak: every 0.5 m column of its trunk and roots whose lowest vertex is within OAK_ROOT_BAND of the ground
## is on it, on every side.
func _oak(space: PhysicsDirectSpaceState3D) -> void:
	var oak := main.find_child("Poi_r37s_oak", true, false)
	if oak == null:
		_fail("the Grandmother Oak is not built")
		return
	var cols := {}
	for part: String in ["Trunk", "Roots"]:
		var mi := oak.get_node_or_null(part) as MeshInstance3D
		if mi == null or mi.mesh == null:
			_fail("the Oak has no %s" % part)
			return
		for v in mi.mesh.get_faces():
			var w := mi.global_transform * v
			var k := Vector2i(roundi(w.x * 2.0), roundi(w.z * 2.0))
			if not cols.has(k) or (cols[k] as Vector3).y > w.y:
				cols[k] = w
	# a round root lying on flat ground leaves a wedge of daylight under its flanks, so a column is not judged
	# alone: in each cell (a 15 degree sector of a 2 m band) the root's lowest point must touch the ground
	var cells := {}
	for k: Vector2i in cols:
		var w: Vector3 = cols[k]
		var g := _ground(space, w.x, w.z)
		if is_nan(g) or w.y - g > OAK_ROOT_BAND:
			continue
		var off := Vector2(w.x + 70.0, w.z - 206.0)
		if off.length() < OAK_HOLLOW_R:
			continue                          # inside the trunk: the stair's first steps stand over the floor
		var ck := Vector2i(int(off.length() / 2.0), floori(atan2(off.x, off.y) / TAU * 24.0))
		if not cells.has(ck) or (cells[ck] as Array)[0] > w.y - g:
			cells[ck] = [w.y - g, w]
	var hang := 0
	var worst := -99.0
	var where := Vector3.ZERO
	for ck: Vector2i in cells:
		var c: Array = cells[ck]
		if c[0] > worst:
			worst = c[0]
			where = c[1]
		if c[0] > MAX_GAP:
			hang += 1
			if verbose:
				print("GROUNDED   oak cell %s: lowest root %.2f over the ground at %s" % [ck, c[0], c[1]])
	print("GROUNDED oak: %d cells (15 degrees x 2 m) with wood near the ground, %d hang over %.0f cm, worst %.2f at %s" % [cells.size(), hang, MAX_GAP * 100.0, worst, where])
	if cells.size() < 60:
		_fail("the Oak's footing was not sampled (%d cells)" % cells.size())
	if float(hang) > float(cells.size()) * OAK_CELL_SHARE or worst > OAK_CELL_WORST:
		_fail("the Grandmother Oak hangs over the ground in %d of %d cells (worst %.2f m at %s)" % [hang, cells.size(), worst, where])


func _edge_rocks(space: PhysicsDirectSpaceState3D) -> void:
	var host := main.find_child("EdgeRocks", true, false)
	if host == null:
		_fail("no EdgeRocks")
		return
	var n := 0
	var bad := 0
	var worst := -99.0
	for c in host.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or String(mi.name).begins_with("Far"):
			continue
		var r := _foot_gap(space, mi.mesh, mi.global_transform)
		if r[0] < -90.0:
			continue
		n += 1
		worst = maxf(worst, r[0])
		if r[0] > MAX_GAP:
			bad += 1
			if verbose or bad <= 5:
				print("GROUNDED   edge rock %s hangs %.2f m at %s" % [mi.get_path(), r[0], r[1]])
	print("GROUNDED edge rocks: %d sampled, %d over %.0f cm, worst %.2f" % [n, bad, MAX_GAP * 100.0, worst])
	if n < 20:
		_fail("too few edge rocks sampled (%d)" % n)
	if bad > 0:
		_fail("%d edge cliffs or boulders hang over the ground" % bad)


## Trees (the flora's MultiMesh trunks): each kind's base points against the terrain.
func _trees(space: PhysicsDirectSpaceState3D) -> void:
	var per := {}
	for n in main.find_children("Flora_*_s", "MultiMeshInstance3D", true, false):
		var kind := String(n.name).get_slice("_", 1)
		if not kind in TREE_KINDS:
			continue
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or not mm.has_meta("cpu_buffer"):
			continue
		var buf: PackedFloat32Array = mm.get_meta("cpu_buffer")
		var pts := Footing.base_points(mm.mesh)
		for i in buf.size() / 16:
			var o := i * 16
			var xf := (n as Node3D).global_transform * Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]), Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			if xf.basis.get_scale().x < 0.01:
				continue                        # a cleared slot
			var og := _ground(space, xf.origin.x, xf.origin.z)
			if is_nan(og) or absf(xf.origin.y - og) > 3.0:
				continue                        # not on the terrain (a mountain's own mesh)
			var worst := -99.0
			for v in pts:
				var w := xf * v
				var g := _ground(space, w.x, w.z)
				if not is_nan(g):
					worst = maxf(worst, w.y - g)
			if not per.has(kind):
				per[kind] = []
			per[kind].append(worst)
	for kind: String in TREE_KINDS:
		var a: Array = per.get(kind, [])
		if a.is_empty():
			continue
		var over := 0
		var worst := -99.0
		for g: float in a:
			over += 1 if g > MAX_GAP else 0
			worst = maxf(worst, g)
		var share := float(over) / float(a.size())
		print("GROUNDED trees %-8s %4d  over %.0f cm: %3d (%.0f%%)  worst %.2f" % [kind, a.size(), MAX_GAP * 100.0, over, share * 100.0, worst])
		if share > TREE_SHARE and a.size() >= 20:
			_fail("%.0f%% of the %s trees hang over the ground" % [share * 100.0, kind])
		if worst > TREE_WORST:
			_fail("an %s tree hangs %.2f m over the ground" % [kind, worst])
	if not per.has("oak") or (per["oak"] as Array).size() < 50:
		_fail("too few oaks sampled: the probe is blind")


## The henge's standing stones and menhirs and the toppled Hierarch: set on the ground, one by one.
func _stones(space: PhysicsDirectSpaceState3D) -> void:
	var n := 0
	for path: String in ["ThornHenge", "RealmPois/Poi_hierarch_statue"]:
		var root := main.find_child(path.get_slice("/", path.get_slice_count("/") - 1), true, false)
		if root == null:
			_fail("no %s" % path)
			continue
		for c in root.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var nm := String(mi.name)
			if mi.mesh == null or not (nm == "Stone" or nm.begins_with("RaidStone") or nm == "StatueBody__stone"):
				continue
			var r := _foot_gap(space, mi.mesh, mi.global_transform)
			if r[0] < -90.0:
				continue
			n += 1
			if r[0] > MAX_GAP:
				_fail("%s hangs %.2f m over the ground at %s" % [mi.get_path(), r[0], r[1]])
	print("GROUNDED stones: %d sampled" % n)
	if n < 10:
		_fail("too few stones sampled (%d)" % n)
