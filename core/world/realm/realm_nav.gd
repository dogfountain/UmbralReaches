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
const CELL_H := 0.2
const AGENT_RADIUS := 0.5
const AGENT_HEIGHT := 1.8
const MAX_CLIMB := 0.4
const MAX_SLOPE := 40.0
const WAIT_MS := 12000                    ## the loading screen never waits longer than this
const AREA := AABB(Vector3(-165.0, -60.0, -160.0), Vector3(330.0, 320.0, 345.0))

## Last build's numbers (read by zz/nav_test).
static var info := {}


static func _settings() -> NavigationMesh:
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
	nm.filter_baking_aabb = AREA
	return nm


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	info = {"polys": 0, "verts": 0, "ms": 0, "cached": false, "parse_ms": 0, "ready": false}
	var map: RID = root.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL_H)
	NavAssist.map = map
	var nm := _settings()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, source, root)
	info.parse_ms = Time.get_ticks_msec() - t0
	if not source.has_data():
		push_warning("RealmNav: no collision geometry parsed")
		return
	var key := "nav|%d|%d|%s" % [hash(source.get_vertices()), hash(source.get_indices()), [CELL, CELL_H, AGENT_RADIUS, AGENT_HEIGHT, MAX_CLIMB, MAX_SLOPE]]
	var hit: Variant = GenCache.load_var(key, SELF)
	if hit is Dictionary and _fill(nm, hit as Dictionary):
		info.cached = true
		_install(root, nm, t0, key, false)
		return
	var done := [false]
	NavigationServer3D.bake_from_source_geometry_data_async(nm, source, func() -> void: done[0] = true)
	var tree := root.get_tree()
	while not done[0] and Time.get_ticks_msec() - t0 < WAIT_MS:
		await tree.process_frame
	if done[0]:
		_install(root, nm, t0, key, true)
	else:
		print("REALM_NAV bake still running after %d ms: enemies keep flat steering until it lands" % WAIT_MS)
		_land_late(root, nm, done, t0, key)


## A late bake: poll on the tree's timer until it lands, then install it (build() does not wait).
static func _land_late(root: Node, nm: NavigationMesh, done: Array, t0: int, key: String) -> void:
	var tree := root.get_tree()
	while not done[0]:
		await tree.create_timer(0.5, false).timeout
		if not is_instance_valid(root) or not root.is_inside_tree():
			return
	_install(root, nm, t0, key, true)


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


static func _install(root: Node, nm: NavigationMesh, t0: int, key: String, save: bool) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree() or nm.get_polygon_count() == 0:
		push_warning("RealmNav: nothing baked")
		return
	if save:
		var polys: Array = []
		for i in nm.get_polygon_count():
			polys.append(nm.get_polygon(i))
		GenCache.save_var(key, SELF, {"v": nm.vertices, "p": polys})
	var region := NavigationRegion3D.new()
	region.name = "NavRegion"
	region.navigation_mesh = nm
	root.add_child(region)
	NavAssist.set_region(region.get_instance_id(), nm.vertices[nm.get_polygon(0)[0]])
	info.polys = nm.get_polygon_count()
	info.verts = nm.vertices.size()
	info.ms = Time.get_ticks_msec() - t0
	info.ready = true
	print("REALM_NAV %d polygons, %d vertices in %d ms (parse %d ms, %s)" % [info.polys, info.verts, info.ms, info.parse_ms, "cached" if info.cached else "baked"])
