extends RefCounted
## WATER EDGES (the world pass): every shore of the river, the fen, the mere and the pans gets its edge dressed. A 4 m scan of the water
## grid finds each place where water meets dry ground (refined to the metre, 3.5 m apart at most, never on a way, a ford, a dock or a
## registered site) and lays three things there, baked once per 64 m cell:
##   reeds         a clump of the flora's own reed card mesh (the fen kind), one MultiMesh per cell, faded at 90 m
##   shore stones  mossy boulders half sunk at the edge (RockKit), one MultiMesh per cell (a variant per cell, so no two shores match), faded at 70 m
##   wet band      a dark, glossy, alpha-blended patch hugging the ground where the bank is wet, one mesh per cell, faded at 80 m
## Three draws per cell with a shore, only inside those ranges; no collision, no lights, nothing per frame. Build-time only. No class_name.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const TreeGen := preload("res://core/world/realm/tree_gen.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/world/realm/wonders/r39/shorelines.gd"
const SOURCES := ["res://core/world/realm/realm_land.gd", "res://core/world/realm/realm_layout.gd", "res://core/world/realm/realm_reaches.gd"]

const STEP := 4.0
const CELL := 64.0
const SPACING := 3.5
const MAX_POINTS := 1500


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


## The shore points (the scan is cached: keyed on this file and the land sources, and on the count of registered sites it avoided).
func _shore() -> Array:
	var key := "shore|%d|%d" % [WorldLanes.sites.size(), hash([GenCache.salt(SOURCES[0]), GenCache.salt(SOURCES[1]), GenCache.salt(SOURCES[2])])]
	var disk: Variant = GenCache.load_var(key, SELF)
	if disk is PackedVector2Array:
		var flat: PackedVector2Array = disk
		var back: Array = []
		for i in range(0, flat.size() - 1, 2):
			back.append([flat[i], flat[i + 1]])
		return back
	var found := _scan()
	var pack := PackedVector2Array()
	for e: Array in found:
		pack.append(e[0] as Vector2)
		pack.append(e[1] as Vector2)
	GenCache.save_var(key, SELF, pack)
	return found


func _scan() -> Array:
	var out: Array = []
	var taken := {}
	var bd := RealmLayout.BOUNDS.grow(-6.0)
	var dirs: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	var z := bd.position.y
	while z < bd.end.y:
		var x := bd.position.x
		while x < bd.end.x:
			if Land.in_water(x, z):
				for d: Vector2 in dirs:
					var q := Vector2(x, z) + d * STEP
					if Land.in_water(q.x, q.y):
						continue
					for f in 4:                                     # refine to the metre: the first dry step towards the dry neighbour
						var r := Vector2(x, z) + d * float(f + 1)
						if not Land.in_water(r.x, r.y):
							var key := Vector2i(floori(r.x / SPACING), floori(r.y / SPACING))
							if not taken.has(key) and not RealmLayout.OLD_BOUNDS.has_point(r) and RealmLayout.path_dist(r) > 2.5 and not WK.site_hit(Rect2(r - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), 0.5):
								taken[key] = true
								out.append([r + d * 0.3, -d])
							break
			x += STEP
		z += STEP
	if out.size() > MAX_POINTS:
		var thin: Array = []
		var stride := float(out.size()) / float(MAX_POINTS)
		for i in MAX_POINTS:
			thin.append(out[int(float(i) * stride)])
		return thin
	return out


func _run(root: Node) -> void:
	var shore := _shore()
	var cells := {}
	for e: Array in shore:
		var p: Vector2 = e[0]
		var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(e)
	var reed: ArrayMesh = TreeGen.kind("reeds_0").cards
	var wet_mat := StandardMaterial3D.new()
	wet_mat.albedo_color = Color(0.03, 0.04, 0.045, 0.55)
	wet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet_mat.roughness = 0.25
	wet_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	wet_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var host := Node3D.new()
	host.name = "ShoreEdges"
	root.add_child(host)
	var nr := 0
	var ns := 0
	for key: Vector2i in cells:
		var list: Array = cells[key]
		var reeds: Array[Transform3D] = []
		var stones: Array[Transform3D] = []
		var v := PackedVector3Array()
		var idx := PackedInt32Array()
		var mesh_i := absi(hash(key)) % 4
		for e: Array in list:
			var p: Vector2 = e[0]
			var o: Vector2 = e[1]
			var hv := absi(hash(Vector2i(roundi(p.x * 1.3), roundi(p.y * 1.3)))) % 100
			var yaw := float(hv) * 0.0628
			if hv < 62:
				var q := p + o * 0.4
				reeds.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * (0.85 + 0.012 * float(hv % 40))), Vector3(q.x, WK.h(q.x, q.y) - 0.08, q.y)))
			if hv >= 50 and hv < 82:
				var q := p - o * 0.3 + Vector2(-o.y, o.x) * (float(hv % 7) - 3.0) * 0.25
				var s := 0.7 + 0.05 * float(hv % 9)
				stones.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * 0.8, s)), Vector3(q.x, WK.h(q.x, q.y) - 0.1 * s, q.y)))
			var t := Vector2(-o.y, o.x)
			var i0 := v.size()
			for c: Array in [[-1.3, -0.9], [1.3, -0.9], [1.3, 0.9], [-1.3, 0.9]]:
				var cp := p + t * float(c[0]) + o * float(c[1])
				v.append(Vector3(cp.x, WK.h(cp.x, cp.y) + 0.035, cp.y))
			idx.append_array([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3])
		var cx := (float(key.x) + 0.5) * CELL
		var cz := (float(key.y) + 0.5) * CELL
		var origin := Vector3(cx, 0.0, cz)
		_multi(host, "Reeds_%d_%d" % [key.x, key.y], reed, reeds, origin, 90.0)
		var rock := RockKit.boulder(mesh_i, Vector3(0.9, 0.55, 0.8), "mossy")
		_multi(host, "ShoreStones_%d_%d" % [key.x, key.y], rock, stones, origin, 70.0)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		for i in v.size():
			v[i] -= origin
		var nrm := PackedVector3Array()
		nrm.resize(v.size())
		nrm.fill(Vector3.UP)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "WetBand_%d_%d" % [key.x, key.y]
		mi.mesh = am
		mi.material_override = wet_mat
		mi.position = origin
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 80.0
		mi.visibility_range_end_margin = 10.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		host.add_child(mi)
		nr += reeds.size()
		ns += stones.size()
	print("WONDER shorelines: %d shore points in %d cells, %d reed clumps, %d stones" % [shore.size(), cells.size(), nr, ns])


func _multi(host: Node3D, nm: String, mesh: Mesh, xf: Array[Transform3D], origin: Vector3, vis: float) -> void:
	if xf.is_empty() or mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, Transform3D(xf[i].basis, xf[i].origin - origin))
		mm.set_instance_color(i, Color(1, 1, 1, 1))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.position = origin
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 2.0
	mmi.visibility_range_end = vis
	mmi.visibility_range_end_margin = vis * 0.1
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.set_meta("site_owned", true)
	mmi.add_to_group(Groups.CULL_SKIP)
	host.add_child(mmi)
