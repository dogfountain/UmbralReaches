extends RefCounted
## The ground under Hearthward once the endgame has gone east (Endgame): while the Crossing and the Threshold were built
## there, home held a copy of the north-east's ground (Endgame.borrow); now the land's own heights go back (meadow and
## wood up to the Crowns' foot, the ways as the land carved them), and the terrain's mesh and collision are made again
## from them. The terrain's normals and splat were made from the land's own heights before the loan, so they stand.
## Realm.build runs it right after the rift module (whether or not the rift was built). Load by path (no class_name).

const Land := preload("res://core/world/realm/realm_land.gd")
const GridMesh := preload("res://core/world/realm/grid_mesh.gd")


static func relandscape(root: Node) -> void:
	if not Endgame.at_home:
		return
	Endgame.at_home = false
	var keep := Endgame.home_keep
	Endgame.home_keep = {}
	var zone := root.get_node_or_null("Zone") as Node3D
	var terrain := zone.get_node_or_null("Terrain") as MeshInstance3D if zone != null else null
	if terrain == null or keep.is_empty() or Land._h.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	var h := Land._h
	var a: Array = TerrainStamp.terrain_arrays(terrain)        # (the build's CPU copy, as the land made it)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	for k: int in keep:
		var y: float = keep[k]
		h[k] = y
		verts[k].y = y
	Land._h = h
	a[Mesh.ARRAY_VERTEX] = verts
	var mesh := GridMesh.mesh(a)
	TerrainStamp.keep_arrays(mesh, a)
	terrain.mesh = mesh
	var t1 := Time.get_ticks_msec()
	var cs := zone.get_node_or_null("TerrainBody/Shape") as CollisionShape3D
	if cs != null and cs.shape is ConcavePolygonShape3D:
		(cs.shape as ConcavePolygonShape3D).set_faces(GridMesh.faces(verts, a[Mesh.ARRAY_INDEX]))
	print("ENDGAME the ground at home given back: %d vertices (%d ms: mesh %d, collision %d)" % [
		keep.size(), Time.get_ticks_msec() - t0, t1 - t0, Time.get_ticks_msec() - t1])
