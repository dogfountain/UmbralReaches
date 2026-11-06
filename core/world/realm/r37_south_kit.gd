extends RefCounted
## The south marches: the Blender kits (tools/blender/r37_south.py) as game parts. A glb holds many named
## meshes at the origin; this loads each file once, hands out its meshes by name, and puts a mesh in
## the world (a MeshInstance3D out of the atmosphere's blanket cull, with its own fade range) and a
## collision shape from a mesh (the oak's *Col proxies). No class_name: preload by path.
##   WALL   WallSeg_A/B/C, Tower, TowerRuin, Gatehouse, BreachStub, Rubble, WallFar, TowerFar, GateFar
##   OAK    Trunk, Roots, Limbs, Crown, Stair, OakFar, TrunkCol, StairCol, RailCol, LimbCol, DeckCol
##   WELL   LedgeSlab, LedgeSlabOpen, LedgeLanding, Corbel, Pier, DescentGate, CaveMouth, Spillway,
##          EchoStone, RimPost, Rubble
##   HUT    Hut, FoldWall, FoldWallB, Hurdle, Trough, Rack, BellPost, Bench

const Data := preload("res://core/world/realm/r37_south_data.gd")
const WALL := "res://art/models/r37_south_wall.glb"
const OAK := "res://art/models/r37_south_oak.glb"
const WELL := "res://art/models/r37_south_well.glb"
const HUT := "res://art/models/r37_south_hut.glb"

static var _cache := {}          ## glb path -> {mesh name -> Mesh} (immutable resources: kept; Realm.release_caches clears it)


static func parts(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var out := {}
	var ps := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if ps == null:
		push_warning("R37South kit: %s is not imported (run godot --headless --import --quit)" % path)
	else:
		var inst := ps.instantiate()
		for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				out[String(mi.name)] = mi.mesh
		inst.free()
	_cache[path] = out
	return out


static func mesh(path: String, part: String) -> Mesh:
	return parts(path).get(part)


static func release() -> void:
	_cache.clear()


## A mesh part in the world. `vis` = [begin, end] metres (0 = no limit) with a dither fade, `shadow`
## false for small or far things. Always outside the atmosphere's blanket cull (it would clip a 40 m
## tree at 45 m): the part's own range decides.
static func put(parent: Node3D, path: String, part: String, xf: Transform3D, vis := Vector2.ZERO, shadow := true, node_name := "") -> MeshInstance3D:
	var m := mesh(path, part)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = node_name if node_name != "" else part
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(Groups.CULL_SKIP)
	parent.add_child(mi)
	mi.global_transform = xf
	ranged(mi, vis)
	return mi


static func ranged(mi: GeometryInstance3D, vis: Vector2) -> void:
	if vis.x > 0.0:
		mi.visibility_range_begin = vis.x
		mi.visibility_range_begin_margin = 14.0
	if vis.y > 0.0:
		mi.visibility_range_end = vis.y
		mi.visibility_range_end_margin = 16.0
	if vis.x > 0.0 or vis.y > 0.0:
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## A static body (the world layer) with the given shapes at global transforms.
static func body(parent: Node3D, n: String, shapes: Array) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.collision_layer = Layers.WORLD
	b.collision_mask = 0
	parent.add_child(b)
	b.global_transform = Transform3D.IDENTITY
	for s: Array in shapes:
		var cs := CollisionShape3D.new()
		cs.shape = s[0]
		b.add_child(cs)
		cs.global_transform = s[1]
	return b


static func box(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


## A trimesh collision from a proxy mesh part, double faced.
static func trimesh(path: String, part: String) -> ConcavePolygonShape3D:
	var m := mesh(path, part)
	if m == null:
		return null
	var sh := m.create_trimesh_shape()
	if sh != null:
		sh.backface_collision = true
	return sh
