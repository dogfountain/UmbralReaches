extends RefCounted
## GROUND MARKS (the world pass): what a used road looks like. Two thin meshes per 96 m cell, baked once:
##   ruts     two dark cart-wheel tracks 0.7 m either side of each way's centreline, broken by a hash so they come and go,
##            following the ground 4 cm over it (alpha-blended, no depth write), kept out of the towns' paved squares
##   puddles  irregular glassy pools in the dips beside the ways (the ground lower than its surroundings): mirror-dark
##            albedo, near-zero roughness, so the moon and the fires show in them
## Triangles: about 6,000 ruts and 2,500 puddles in the whole Realm; 80 m to 110 m visibility ranges with a dither fade
## (a rut 2 m wide is nothing past that); 2 draws per cell in view. No collision, no lights, nothing runs per frame.
## No class_name: load by path.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const TOWNS := [[Vector2(6.0, 38.0), 36.0], [Vector2(-311.0, 281.0), 32.0], [Vector2(-160.0, 300.0), 36.0], [Vector2(324.5, 53.5), 42.0], [Vector2(-205.0, 66.0), 28.0]]


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030
	var ruts := {}                           # cell -> [PackedVector3Array strips]
	var pools := {}
	var nr := 0
	var np := 0
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		var width := float(path.get("w", 1.4))
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			if seg < 0.5:
				continue
			var t := (b - a) / seg
			var n := Vector2(-t.y, t.x)
			var steps := int(seg / 1.5)
			for j in steps:
				var p := a + t * (float(j) * 1.5)
				if _in_town(p) or Land.in_water(p.x, p.y):
					continue
				var key := Vector2i(floori(p.x / 96.0), floori(p.y / 96.0))
				# ruts: a pair of strips, broken by a hash of the position
				var hv := absi(hash(Vector2i(roundi(p.x * 0.7), roundi(p.y * 0.7)))) % 100
				if hv < 72 and width >= 1.2:
					if not ruts.has(key):
						ruts[key] = []
					for s: float in [-1.0, 1.0]:
						var c0 := p + n * (s * 0.7)
						var c1 := p + t * 1.5 + n * (s * 0.7)
						(ruts[key] as Array).append([c0, c1, t])
						nr += 1
				# a puddle beside the way where the ground dips
				if hv % 11 == 0:
					var off := n * (rng.randf_range(0.4, 1.6) * (1.0 if hv % 2 == 0 else -1.0))
					var q := p + off
					var hq := WK.h(q.x, q.y)
					var avg := (WK.h(q.x + 2.5, q.y) + WK.h(q.x - 2.5, q.y) + WK.h(q.x, q.y + 2.5) + WK.h(q.x, q.y - 2.5)) * 0.25
					if hq < avg - 0.03 and not Land.in_water(q.x, q.y):
						if not pools.has(key):
							pools[key] = []
						(pools[key] as Array).append([q, t, rng.randf_range(0.5, 1.4)])
						np += 1
	var rut_mat := StandardMaterial3D.new()
	rut_mat.albedo_color = Color(0.03, 0.03, 0.04, 0.5)
	rut_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rut_mat.roughness = 0.9
	rut_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	rut_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_color = Color(0.02, 0.04, 0.07, 0.9)
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.roughness = 0.02
	pool_mat.metallic = 0.0
	pool_mat.metallic_specular = 1.0
	pool_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var host := Node3D.new()
	host.name = "GroundMarks"
	root.add_child(host)
	for key: Vector2i in ruts:
		_mesh(host, "Ruts_%d_%d" % [key.x, key.y], _rut_mesh(ruts[key] as Array), rut_mat, 90.0)
	for key: Vector2i in pools:
		_mesh(host, "Pools_%d_%d" % [key.x, key.y], _pool_mesh(pools[key] as Array, rng), pool_mat, 110.0)
	print("WONDER ground_marks: %d rut segments, %d puddles" % [nr, np])


func _in_town(p: Vector2) -> bool:
	for t: Array in TOWNS:
		if (t[0] as Vector2).distance_to(p) < float(t[1]):
			return true
	return false


func _mesh(host: Node3D, nm: String, m: ArrayMesh, mat: Material, vis: float) -> void:
	if m == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = vis
	mi.visibility_range_end_margin = vis * 0.15
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	host.add_child(mi)


func _rut_mesh(segs: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for sg: Array in segs:
		var c0: Vector2 = sg[0]
		var c1: Vector2 = sg[1]
		var t: Vector2 = sg[2]
		var n := Vector2(-t.y, t.x) * 0.13
		var i := v.size()
		for e: Array in [[c0, -1.0], [c0, 1.0], [c1, 1.0], [c1, -1.0]]:
			var c: Vector2 = e[0]
			var q := c + n * float(e[1])
			v.append(Vector3(q.x, WK.h(q.x, q.y) + 0.04, q.y))
		idx.append_array([i, i + 1, i + 2, i, i + 2, i + 3])
	return _arr(v, idx)


func _pool_mesh(list: Array, rng: RandomNumberGenerator) -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for e: Array in list:
		var c: Vector2 = e[0]
		var t: Vector2 = e[1]
		var r: float = e[2]
		var n := Vector2(-t.y, t.x)
		var ring: Array[Vector2] = []
		var low := INF
		for k in 8:
			var a := TAU * float(k) / 8.0
			var rr := r * rng.randf_range(0.7, 1.2)
			var q := c + t * (cos(a) * rr * 1.5) + n * (sin(a) * rr)
			ring.append(q)
			low = minf(low, WK.h(q.x, q.y))
		var y := low + 0.05
		var i := v.size()
		v.append(Vector3(c.x, y, c.y))
		for q: Vector2 in ring:
			v.append(Vector3(q.x, y, q.y))
		for k in 8:
			idx.append_array([i, i + 1 + k, i + 1 + (k + 1) % 8])
	return _arr(v, idx)


func _arr(v: PackedVector3Array, idx: PackedInt32Array) -> ArrayMesh:
	if v.is_empty():
		return null
	var nrm := PackedVector3Array()
	nrm.resize(v.size())
	nrm.fill(Vector3.UP)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
