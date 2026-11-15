class_name RealmNav
extends RefCounted
## Realm module (last before the cull): one navigation mesh for the whole night, baked from the static
## collision on layer WORLD, so enemies (core/enemy/nav_assist.gd) can path round mazes, benches, pits
## and raid-room walls when their cheap straight-line steering is blocked.
##
## - Source geometry is parsed on the main thread (cheap next to the bake), then
##   NavigationServer3D bakes it on a worker thread. The loading screen waits at most WAIT_MS for it;
##   a bake that is late installs itself when it lands, and until then enemies simply keep flat steering.
## - The result is cached through GenCache, keyed on a hash of the parsed collision plus the bake
##   settings: identical geometry (every run of the same layout) skips the bake, any change rebuilds.
## - Cell size 0.5 (agent radius is one cell), cell height 0.2. The default map is set to match, or the
##   server refuses to merge the region's edges.

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/world/realm/realm_nav.gd"
const CELL := 0.5
const CELL_H := 0.125                     ## binary-exact, so MAX_CLIMB is a whole number of these (the bake floors the climb to voxels and warned at 0.65 / 0.2)
const AGENT_RADIUS := 0.5
const AGENT_HEIGHT := 1.8
const MAX_CLIMB := 0.625                  ## with a 0.5 m cell the ledge filter drops ramps steeper than atan(climb / cell): 0.4 lost every 27 degree stair (the fen and Counting stairs)
const MAX_SLOPE := 40.0
const WAIT_MS := 20000                    ## the loading screen never waits longer than this (twice the ground, was 12 s)
const AREA := AABB(Vector3(-382.0, -60.0, -160.0), Vector3(764.0, 320.0, 570.0))     ## BOUNDS + 12 m (was x -272..272, z -160..252)

## Last build's numbers (read by zz/nav_test).
static var info := {}


## The Realm is baked in tiles. One bake's polygon mesh holds 65,535 vertices at most: the whole Marches' Realm stood at
## 65,726 on 13 Nov, so it was split in halves north and south of SPLIT_Z (on open ground south of the Pilgrims'
## Road: no building, stair or tier stands across the line; a split at x 0 cut the Ossuary's tiers). The Far Reaches
## doubled the ground again: the middle (the Marches' width) keeps its two halves and gains a third south of
## SOUTH_Z (open fields below the downs' scarp), and the West and East Reaches are tiles of their own beyond
## x +-REACH_X (the Marches' old edges, where nothing is built across the line). Tiles overlap by SEAM metres and the
## server joins them where their polygons overlap.
const SPLIT_Z := 86.0
const SOUTH_Z := 246.0
const REACH_X := 262.0
const SEAM := 2.0


## The baking boxes (AREA cut into tiles).
static func tiles() -> Array[AABB]:
	var a := AREA
	var y0 := a.position.y
	var hy := a.size.y
	var out: Array[AABB] = []
	var xs := [[a.position.x, -REACH_X + SEAM], [-REACH_X - SEAM, REACH_X + SEAM], [REACH_X - SEAM, a.end.x]]
	for xi in xs.size():
		var x0: float = xs[xi][0]
		var x1: float = xs[xi][1]
		var zs := [[a.position.z, a.end.z]] if xi != 1 else [[a.position.z, SPLIT_Z + SEAM], [SPLIT_Z - SEAM, SOUTH_Z + SEAM], [SOUTH_Z - SEAM, a.end.z]]
		for zz: Array in zs:
			out.append(AABB(Vector3(x0, y0, float(zz[0])), Vector3(x1 - x0, hy, float(zz[1]) - float(zz[0]))))
	return out


static func _settings(tile := AABB()) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Layers.WORLD
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.cell_size = CELL
	nm.cell_height = CELL_H
	nm.agent_radius = AGENT_RADIUS
	nm.agent_height = AGENT_HEIGHT
	nm.agent_max_climb = MAX_CLIMB
	nm.agent_max_slope = MAX_SLOPE
	nm.region_min_size = 4.0
	nm.region_merge_size = 20.0
	nm.edge_max_length = 12.0
	nm.edge_max_error = 0.4
	var a := AREA if tile.size == Vector3.ZERO else tile
	nm.filter_baking_aabb = a
	return nm


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	info = {"polys": 0, "verts": 0, "ms": 0, "cached": false, "parse_ms": 0, "ready": false}
	var map: RID = root.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL_H)
	NavAssist.map = map
	var nm := _settings()
	var nms: Array[NavigationMesh] = []
	for tile: AABB in tiles():
		nms.append(_settings(tile))
	var source := NavigationMeshSourceGeometryData3D.new()
	# closed seals are doors, not walls: lifted for the parse so the arenas behind them are on the mesh
	var seals := root.get_tree().get_nodes_in_group(&"ward_seal")
	for sn in seals:
		(sn as WardSeal).nav_pass(true)
	NavigationServer3D.parse_source_geometry_data(nm, source, root)
	for sn in seals:
		(sn as WardSeal).nav_pass(false)
	info.parse_ms = Time.get_ticks_msec() - t0
	if not source.has_data():
		push_warning("RealmNav: no collision geometry parsed")
		return
	var key := "nav|%d|%d|%s" % [hash(source.get_vertices()), hash(source.get_indices()), [CELL, CELL_H, AGENT_RADIUS, AGENT_HEIGHT, MAX_CLIMB, MAX_SLOPE]]
	key += "|tiles|%s" % [tiles()]
	var hit: Variant = GenCache.load_var(key, SELF)
	if hit is Array and (hit as Array).size() == nms.size():
		var all := true
		for i in nms.size():
			all = all and (hit as Array)[i] is Dictionary and _fill(nms[i], (hit as Array)[i] as Dictionary)
		if all:
			info.cached = true
			_install(root, nms, t0, key, false)
			return
	var done := [false]
	# Baked on a WorkerThreadPool task this module owns (not the server's own async bake), so a quit
	# or scene change mid-bake can wait for it: the engine crashed tearing down under a live bake.
	_task = WorkerThreadPool.add_task(func() -> void:
		for one: NavigationMesh in nms:
			NavigationServer3D.bake_from_source_geometry_data(one, source)
		done[0] = true, false, "RealmNav bake")
	root.tree_exiting.connect(_finish_task, CONNECT_ONE_SHOT)
	var tree := root.get_tree()
	while not done[0] and Time.get_ticks_msec() - t0 < WAIT_MS:
		await tree.process_frame
	if done[0]:
		_finish_task()
		_install(root, nms, t0, key, true)
	else:
		print("REALM_NAV bake still running after %d ms: enemies keep flat steering until it lands" % WAIT_MS)
		_land_late(root, nms, done, t0, key)


static var _task := -1


## Block until a running bake is done (the night is being freed, or the game is quitting).
static func _finish_task() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## A late bake: poll on the tree's timer until it lands, then install it (build() does not wait).
static func _land_late(root: Node, nms: Array[NavigationMesh], done: Array, t0: int, key: String) -> void:
	var tree := root.get_tree()
	while not done[0]:
		await tree.create_timer(0.5, false).timeout
		if not is_instance_valid(root) or not root.is_inside_tree():
			return
	_finish_task()
	_install(root, nms, t0, key, true)


static func _fill(nm: NavigationMesh, d: Dictionary) -> bool:
	var v: Variant = d.get("v")
	var p: Variant = d.get("p")
	if not (v is PackedVector3Array and p is Array) or (v as PackedVector3Array).is_empty():
		return false
	nm.vertices = v
	nm.clear_polygons()
	for poly: Variant in p:
		nm.add_polygon(poly as PackedInt32Array)
	return nm.get_polygon_count() > 0


static func _install(root: Node, nms: Array[NavigationMesh], t0: int, key: String, save: bool) -> void:
	var empty := false
	for one: NavigationMesh in nms:
		empty = empty or one.get_polygon_count() == 0
	if not is_instance_valid(root) or not root.is_inside_tree() or empty:
		push_warning("RealmNav: nothing baked")
		return
	if save:
		var packed: Array = []
		for one: NavigationMesh in nms:
			var polys: Array = []
			for i in one.get_polygon_count():
				polys.append(one.get_polygon(i))
			packed.append({"v": one.vertices, "p": polys})
		GenCache.save_var(key, SELF, packed)
	info.polys = 0
	info.verts = 0
	for i in nms.size():
		var region := NavigationRegion3D.new()
		region.name = "NavRegion" if i == 0 else "NavRegion%d" % i
		region.navigation_mesh = nms[i]
		root.add_child(region)
		if i == nms.size() - 1:
			# (the probe point NavAssist waits on is on the last tile installed)
			NavAssist.set_region(region.get_instance_id(), nms[i].vertices[nms[i].get_polygon(0)[0]])
		info.polys += nms[i].get_polygon_count()
		info.verts += nms[i].vertices.size()
	info.ms = Time.get_ticks_msec() - t0
	info.ready = true
	print("REALM_NAV %d polygons, %d vertices in %d ms (parse %d ms, %s)" % [info.polys, info.verts, info.ms, info.parse_ms, "cached" if info.cached else "baked"])
