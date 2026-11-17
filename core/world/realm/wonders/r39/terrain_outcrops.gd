extends RefCounted
## THE OUTCROPS (the world pass): where the benches (terrain_benches.gd) and the land's own scarps rise steeply, strata
## of stone break the slope: stratified cliff faces (RockKit.cliff: cached, LOD'd, convex collision) 5-9 m wide and
## 3-6 m high, turned to face down the hill, stood along the steep ground of the Far Reaches (outside the old Marches).
## Up to 90, found on a 12 m jittered grid where the slope is 21-50 degrees, dry, 14 m off every way and outside every
## registered site; style by the region's biome (ash, mossy in the woods and fens, granite elsewhere). Each keeps the
## trees off (RealmFlora.tree_clear) and fades out at 170 m. A few sizes only, so the meshes are shared (and cached on disk).

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const MAX := 90
const SIZES := [Vector3(6.0, 3.6, 2.4), Vector3(7.5, 4.8, 2.8), Vector3(9.0, 6.0, 3.2), Vector3(5.0, 3.0, 2.0)]


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var host := Node3D.new()
	host.name = "Outcrops"
	root.add_child(host)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var biome := {}
	for reg: Dictionary in RealmLayout.REGIONS:
		biome[String(reg.id)] = String(reg.get("biome", ""))
	var groups := {}                                  ## mesh -> {cell -> [Transform3D]}: one MultiMesh per (mesh, 96 m cell), not a draw per rock
	var mb := RealmReaches.MARCH_BOUNDS
	# one pass over a 14 m grid of the Far Reaches (about 2,000 cells, four height reads each): the steepest MAX cells, 12 m apart
	var cand: Array = []
	var gz := -138.0
	while gz < 390.0:
		var gx := -360.0
		while gx < 360.0:
			gx += 14.0
			var p := Vector2(gx + rng.randf() * 10.0, gz + rng.randf() * 10.0)
			if mb.has_point(p) or not RealmLayout.BOUNDS.grow(-12.0).has_point(p) or WK.wet(p.x, p.y):
				continue
			var gxv := (WK.h(p.x + 4.0, p.y) - WK.h(p.x - 4.0, p.y)) / 8.0
			var gzv := (WK.h(p.x, p.y + 4.0) - WK.h(p.x, p.y - 4.0)) / 8.0
			var sl := sqrt(gxv * gxv + gzv * gzv)
			if sl >= 0.2 and sl <= 1.4:
				cand.append([sl, p, gxv, gzv])
		gz += 14.0
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var kept: Array[Vector2] = []
	var placed := 0
	for e: Array in cand:
		if placed >= MAX:
			break
		var p: Vector2 = e[1]
		var close := false
		for q: Vector2 in kept:
			if q.distance_squared_to(p) < 144.0:
				close = true
				break
		if close or RealmLayout.path_dist(p) < 12.0 or WK.site_hit(Rect2(p - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), 1.0):
			continue
		kept.append(p)
		var down := Vector2(-float(e[2]), -float(e[3])).normalized()
		var reg2 := WK.region_at(p)
		var bio: String = String(biome.get(reg2, ""))
		var style := "ash" if bio == "ash" else ("mossy" if bio in ["oldforest", "fen"] else "granite")
		var sz: Vector3 = SIZES[placed % SIZES.size()]
		var mesh := RockKit.cliff(placed % 8, sz, style)
		var xf := Transform3D(Basis(Vector3.UP, atan2(down.x, down.y)), Vector3(p.x, WK.h(p.x, p.y) - 0.5, p.y))
		_add(host, mesh, xf, groups)
		placed += 1
	for mesh: Mesh in groups:
		for cell: Vector2i in (groups[mesh] as Dictionary):
			var xs: Array = (groups[mesh] as Dictionary)[cell]
			var mmi := OssKit.multimesh(mesh, xs, null, true)
			mmi.name = "Outcrops_%d_%d" % [cell.x, cell.y]
			mmi.material_override = null
			mmi.visibility_range_end = 150.0
			mmi.visibility_range_end_margin = 20.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			host.add_child(mmi)
	print("WONDER terrain_outcrops: %d scarp faces from %d steep cells" % [placed, cand.size()])


## A rock: its collision body now (a convex shape on the WORLD layer, no mesh), its picture into the (mesh, cell) group.
func _add(host: Node3D, mesh: Mesh, xf: Transform3D, groups: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "OutcropBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = RockKit.collision_shape(mesh)
	body.add_child(cs)
	host.add_child(body)
	body.transform = xf
	if not groups.has(mesh):
		groups[mesh] = {}
	var cell := Vector2i(floori(xf.origin.x / 96.0), floori(xf.origin.z / 96.0))
	if not (groups[mesh] as Dictionary).has(cell):
		(groups[mesh] as Dictionary)[cell] = []
	((groups[mesh] as Dictionary)[cell] as Array).append(xf)
