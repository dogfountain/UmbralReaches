class_name MeshChunks
extends RefCounted
## Zone-wide baked prop meshes (GiantTrunks spans 101 x 84 m in one 53k-triangle mesh) can never
## be frustum-culled or LOD'd: their bounds always hold the camera. `split()` cuts such a mesh into
## CELL-metre chunks by triangle centre, each its own MeshInstance3D with generated LODs, and hides
## the original. The original keeps its mesh and node path, so everything that reads it (seating,
## site clearance, audits) still works; run this last, once nothing edits the mesh any more.

const CELL := 24.0
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/world/mesh_chunks.gd"

static var _lod_cache := {}


## Mesh with generated LOD levels (all surfaces, materials kept). Cached per source mesh.
static func with_lods(m: Mesh) -> Mesh:
	if m == null:
		return null
	if _lod_cache.has(m):
		return _lod_cache[m]
	var im := ImporterMesh.new()
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_INDEX] == null:
			# LOD generation needs an index buffer
			var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var idx := PackedInt32Array()
			idx.resize(n)
			for i in n:
				idx[i] = i
			arrays[Mesh.ARRAY_INDEX] = idx
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, m.surface_get_material(s))
	var tl := Time.get_ticks_usec()
	im.generate_lods(25.0, 60.0, [])
	var out: Mesh = im.get_mesh()
	Realm.prof_add("gen: with_lods", tl)
	_lod_cache[m] = out
	return out


## `lods`: false for card meshes (leaf canopies): LOD simplification collapses flat alpha cards,
## so a chunk's leaves vanished as soon as it dropped a level. They still get frustum culling.
static func split(mi: MeshInstance3D, lods := true) -> int:
	if mi == null or mi.mesh == null or mi.has_meta("chunked"):
		return 0
	mi.set_meta("chunked", true)
	var tp := Time.get_ticks_usec()
	var xf := mi.global_transform
	# deterministic builders (the Crossing, the rift) give the same mesh every load: reuse the
	# chunks cut (and LOD'd) last time, keyed by the source's content and placement
	var ck := _content_key(mi, lods)
	var cached: Variant = GenCache.load_var(ck, SELF)
	if cached is Array:
		var ok := true
		var meshes: Array = []
		for c: Array in cached:
			var m := GenCache.load_mesh(ck + "|" + str(c[0]), SELF)
			if m == null:
				ok = false
				break
			var surf: PackedInt32Array = c[1]
			for i in mini(surf.size(), m.get_surface_count()):
				if m.surface_get_material(i) == null:
					m.surface_set_material(i, mi.mesh.surface_get_material(surf[i]))
			meshes.append([c[0], m])
		if ok:
			for e: Array in meshes:
				_add_chunk(mi, xf, e[0], e[1])
			mi.visible = false
			Realm.prof_add("gen: chunk split (disk)", tp)
			return meshes.size()
	var cells := {}                       # Vector2i -> {surface: [indices]}
	var surf_arrays: Array = []
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		surf_arrays.append(a)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		for t in range(0, idx.size(), 3):
			var c := xf * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
			var key := Vector2i(floori(c.x / CELL), floori(c.z / CELL))
			if not cells.has(key):
				cells[key] = {}
			var per: Dictionary = cells[key]
			if not per.has(s):
				per[s] = PackedInt32Array()
			var lst: PackedInt32Array = per[s]
			lst.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
			per[s] = lst
	var made := 0
	var index: Array = []                 # [cell, source surface per chunk surface] for the cache
	for key: Vector2i in cells:
		var im := ImporterMesh.new()
		var per: Dictionary = cells[key]
		for s: int in per:
			var src: Array = surf_arrays[s]
			var tri: PackedInt32Array = per[s]
			# compact the vertex set to what this chunk uses
			var remap := {}
			var order := PackedInt32Array()
			for v in tri:
				if not remap.has(v):
					remap[v] = order.size()
					order.append(v)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			for ch in Mesh.ARRAY_MAX:
				if ch == Mesh.ARRAY_INDEX or src[ch] == null:
					continue
				arrays[ch] = _pick(src[ch], order, _stride(ch, src))
			var new_idx := PackedInt32Array()
			new_idx.resize(tri.size())
			for k in tri.size():
				new_idx[k] = remap[tri[k]]
			arrays[Mesh.ARRAY_INDEX] = new_idx
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mi.mesh.surface_get_material(s))
		if lods:
			im.generate_lods(25.0, 60.0, [])
		var cm: ArrayMesh = im.get_mesh()
		_add_chunk(mi, xf, key, cm)
		GenCache.save_mesh(ck + "|" + str(key), SELF, cm)
		index.append([key, PackedInt32Array((per as Dictionary).keys())])
		made += 1
	GenCache.save_var(ck, SELF, index)
	mi.visible = false
	Realm.prof_add("gen: chunk split", tp)
	return made


static func _add_chunk(mi: MeshInstance3D, xf: Transform3D, key: Vector2i, mesh: Mesh) -> void:
	var chunk := MeshInstance3D.new()
	chunk.name = "%s_chunk_%d_%d" % [mi.name, key.x, key.y]
	chunk.mesh = mesh
	chunk.material_override = mi.material_override
	chunk.cast_shadow = mi.cast_shadow
	chunk.gi_mode = mi.gi_mode
	chunk.layers = mi.layers
	chunk.visibility_range_end = mi.visibility_range_end
	chunk.visibility_range_end_margin = mi.visibility_range_end_margin
	chunk.visibility_range_fade_mode = mi.visibility_range_fade_mode
	chunk.extra_cull_margin = 2.0
	_carry_metas(mi, chunk)
	mi.get_parent().add_child(chunk)
	chunk.global_transform = xf


## Content key: every surface's vertices and indices hashed (in C++, fast), plus where it stands.
static func _content_key(mi: MeshInstance3D, lods: bool) -> String:
	var h := str(mi.global_transform).hash()
	for sidx in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(sidx)
		h = hash([h, hash(a[Mesh.ARRAY_VERTEX]), hash(a[Mesh.ARRAY_INDEX]) if a[Mesh.ARRAY_INDEX] != null else 0])
	return "chunks|%s|%d|%s" % [mi.name, h, lods]


static func _stride(ch: int, src: Array) -> int:
	match ch:
		Mesh.ARRAY_TANGENT, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS:
			var nv := (src[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			return maxi(1, (src[ch] as Variant).size() / maxi(nv, 1))
	return 1


static func _pick(data: Variant, order: PackedInt32Array, stride: int) -> Variant:
	var out: Variant
	match typeof(data):
		TYPE_PACKED_VECTOR3_ARRAY: out = PackedVector3Array()
		TYPE_PACKED_VECTOR2_ARRAY: out = PackedVector2Array()
		TYPE_PACKED_COLOR_ARRAY: out = PackedColorArray()
		TYPE_PACKED_FLOAT32_ARRAY: out = PackedFloat32Array()
		TYPE_PACKED_INT32_ARRAY: out = PackedInt32Array()
		_: return null
	out.resize(order.size() * stride)
	for k in order.size():
		for j in stride:
			out[k * stride + j] = data[order[k] * stride + j]
	return out


## A MultiMesh spread over a big area (one node, usually at the origin, with world-placed instances)
## is drawn whole at the LOD its *nearest* instance needs, and its visibility range is measured to
## the node origin, not to the instances (the rift's ash drifts: 64 boulders over 110 m, all at full
## detail whenever any was close, and all hidden from the summit because the origin was far).
## split_multimesh() re-buckets the instances into `cell` cells, each its own node at the cell
## centre with the original's look and ranges, and hides the original (kept for anything that reads
## it). Needs a renderer: headless MultiMesh buffers read back empty. Returns the chunks made.
static func split_multimesh(mmi: MultiMeshInstance3D, cell := CELL, cell_y := 0.0) -> int:
	if mmi == null or mmi.multimesh == null or mmi.has_meta("chunked") or DisplayServer.get_name() == "headless":
		return 0
	if mmi.has_meta(&"live_pool"):          # a runtime pool (the far light cards, the mist banks, the wildlife): its script writes the
		return 0                             # one MultiMesh it made each frame; split by its placeholder slots it drew nothing
	var mm := mmi.multimesh
	if mm.transform_format != MultiMesh.TRANSFORM_3D or mm.instance_count < 2 or mm.mesh == null:
		return 0
	var buf: PackedFloat32Array = mm.get_meta("cpu_buffer") if mm.has_meta("cpu_buffer") else mm.buffer
	var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
	var count := mm.instance_count if mm.visible_instance_count < 0 else mini(mm.visible_instance_count, mm.instance_count)
	if buf.size() < count * stride:
		return 0
	mmi.set_meta("chunked", true)
	var cells := {}                       # Vector3i -> PackedInt32Array of instance indices
	for i in count:
		var o := i * stride
		# cell_y > 0 also splits by height (an underground area's bones and candles, surface to pit: a cell that sits
		# wholly below the ground is then culled by the terrain occluder)
		var key := Vector3i(floori(buf[o + 3] / cell), floori(buf[o + 7] / cell_y) if cell_y > 0.0 else 0, floori(buf[o + 11] / cell))
		if not cells.has(key):
			cells[key] = PackedInt32Array()
		var l: PackedInt32Array = cells[key]
		l.append(i)
		cells[key] = l
	if cells.size() < 2:
		mmi.remove_meta("chunked")
		return 0
	for key: Vector3i in cells:
		var list: PackedInt32Array = cells[key]
		var centre := Vector3.ZERO
		for i in list:
			centre += Vector3(buf[i * stride + 3], buf[i * stride + 7], buf[i * stride + 11])
		centre /= float(list.size())
		var out := PackedFloat32Array()
		out.resize(list.size() * stride)
		for k in list.size():
			var src := list[k] * stride
			for j in stride:
				out[k * stride + j] = buf[src + j]
			out[k * stride + 3] -= centre.x
			out[k * stride + 7] -= centre.y
			out[k * stride + 11] -= centre.z
		var cm := MultiMesh.new()
		cm.transform_format = MultiMesh.TRANSFORM_3D
		cm.use_colors = mm.use_colors
		cm.use_custom_data = mm.use_custom_data
		cm.mesh = mm.mesh
		cm.instance_count = list.size()
		cm.buffer = out
		cm.set_meta("cpu_buffer", out)
		var c := MultiMeshInstance3D.new()
		c.name = "%s_cell_%d_%d_%d" % [mmi.name, key.x, key.y, key.z]
		c.multimesh = cm
		c.material_override = mmi.material_override
		c.material_overlay = mmi.material_overlay
		c.cast_shadow = mmi.cast_shadow
		c.gi_mode = mmi.gi_mode
		c.layers = mmi.layers
		c.lod_bias = mmi.lod_bias
		c.transparency = mmi.transparency
		c.ignore_occlusion_culling = mmi.ignore_occlusion_culling
		c.visibility_range_begin = mmi.visibility_range_begin
		c.visibility_range_begin_margin = mmi.visibility_range_begin_margin
		c.visibility_range_end = mmi.visibility_range_end
		c.visibility_range_end_margin = mmi.visibility_range_end_margin
		c.visibility_range_fade_mode = mmi.visibility_range_fade_mode
		c.extra_cull_margin = mmi.extra_cull_margin
		for g in mmi.get_groups():
			if not String(g).begins_with("_"):
				c.add_to_group(g)
		_carry_metas(mmi, c)
		mmi.get_parent().add_child(c)
		c.transform = mmi.transform * Transform3D(Basis.IDENTITY, centre)
	mmi.visible = false
	return cells.size()


## A chunk takes its source's ranges already scaled: the fade guard's record of that (range_k, fade_orig) and the
## flora / site metas go with them, or the guard took the copied range for a builder's and pushed it out 1.5x again.
static func _carry_metas(src: Node, dst: Node) -> void:
	for m in [&"range_k", &"fade_orig", &"site_owned", &"far_detail", &"fade_end"]:
		if src.has_meta(m):
			dst.set_meta(m, src.get_meta(m))
