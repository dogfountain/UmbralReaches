extends RefCounted
## A person's shadow from a lower LOD of their own body (fps pass, 20 Nov): the villagers, the Living Night's folk and the
## road's travellers were the heaviest shadow casters in the Realm, 15-24k triangles each at full detail, twenty of them in
## the moon's reach at Hearthward and sixteen at Reedholm (perf_tour --casters), while the wanderer already casts from a
## 4k-triangle proxy (character_rig.gd). The body's mesh carries LODs (villager_rig.gd _generate); its shadow now draws a
## copy of one of them (about a third of the triangles, the vertices it uses only, the body's own vertex format and
## material, so the shadow pass draws it with the pipelines the body compiled), skinned to the same skeleton and cast by
## a ShadowProxy; the body casts nothing. The shadow's outline is the body's at a third of the detail: at night, under
## a soft moon, the same shape. The body's deeper LODs come along (the shadow pass picks a LOD by distance as it did
## for the body: without them a far proxy drew its whole third where the body had drawn a tenth, +30k shadow triangles
## at the spawn). Cached per look through GenCache.
## Load by path (no class_name): const VShadow := preload("res://core/life/village/villager_shadow.gd")

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/life/village/villager_shadow.gd"
const SHARE := 0.4                       ## the first LOD with at most this share of the body's triangles

static var _mem := {}                    ## key -> the shadow's ArrayMesh


## Give the rig's body (`body`, skinned to `skel`) a ShadowProxy cast from a lower LOD of `mesh`; the body keeps casting
## if no LOD fits.
static func attach(skel: Skeleton3D, body: MeshInstance3D, key: String, mesh: ArrayMesh) -> void:
	var sm := _mesh(key, mesh)
	if sm == null:
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		return
	var sp := MeshInstance3D.new()
	sp.name = "ShadowProxy"
	sp.mesh = sm
	sp.skin = body.skin
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sp.extra_cull_margin = body.extra_cull_margin
	# the body's range (FadeGuard pushes both out alike): past it the person is not drawn, so neither is their shadow (an
	# unranged proxy cast the shadows of people nobody sees, frozen past 150 m where they are not posed)
	sp.visibility_range_begin = body.visibility_range_begin
	sp.visibility_range_begin_margin = body.visibility_range_begin_margin
	sp.visibility_range_end = body.visibility_range_end
	sp.visibility_range_end_margin = body.visibility_range_end_margin
	sp.visibility_range_fade_mode = body.visibility_range_fade_mode
	sp.lod_bias = body.lod_bias
	skel.add_child(sp)
	sp.skeleton = NodePath("..")
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func release() -> void:
	_mem.clear()


static func _mesh(key: String, mesh: ArrayMesh) -> ArrayMesh:
	var sk := key + "|shadow"
	var got: ArrayMesh = _mem.get(sk)
	if got == null:
		got = GenCache.load_mesh(sk, SELF)
		if got == null:
			got = lod_copy(mesh, SHARE)
			if got == null:
				return null
			GenCache.save_mesh(sk, SELF, got)
		got.surface_set_material(0, mesh.surface_get_material(0))
		_mem[sk] = got
	return got


## One of `mesh`'s LODs (surface 0: the first with at most `share` of its triangles) as a mesh of its own, with the
## deeper LODs as its own (at the same edge lengths), keeping only the vertices they use, in the source's vertex format.
## Null when the mesh has no such LOD.
static func lod_copy(mesh: ArrayMesh, share: float) -> ArrayMesh:
	if mesh == null or mesh.get_surface_count() != 1:
		return null
	var sd: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var base_n := int(sd.get("index_count", 0))
	var base_data: PackedByteArray = sd.get("index_data", PackedByteArray())
	if base_n <= 0 or base_data.is_empty():
		return null
	var stride := base_data.size() / base_n            # 2 or 4 bytes an index
	var pick := PackedByteArray()
	var deeper := {}                                   # edge length -> a deeper LOD's indices (in the source's numbering)
	for l: Variant in sd.get("lods", []):
		var data: PackedByteArray = (l as Dictionary).get("index_data", PackedByteArray())
		if not pick.is_empty():
			deeper[float((l as Dictionary).get("edge_length", 0.0))] = data
		elif data.size() / stride <= int(float(base_n) * share):
			pick = data
	if pick.is_empty():
		return null
	var src := mesh.surface_get_arrays(0)
	var remap := {}
	var order: Array[int] = []                         # (an Array: the helper appends to it)
	var idx := _remapped(pick, stride, remap, order)
	var lods := {}
	for e: float in deeper:
		lods[e] = _remapped(deeper[e], stride, remap, order)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var keep := PackedInt32Array(order)
	for ch in Mesh.ARRAY_MAX:
		if ch == Mesh.ARRAY_INDEX or src[ch] == null:
			continue
		arrays[ch] = MeshChunks._pick(src[ch], keep, MeshChunks._stride(ch, src))
	arrays[Mesh.ARRAY_INDEX] = idx
	var fmt := mesh.surface_get_format(0)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods, fmt & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES))
	return out


## Index bytes (2 or 4 an index) -> indices into the copy's vertices; a vertex not seen yet is appended to `order` (the
## source's vertex for each of the copy's) and `remap`.
static func _remapped(data: PackedByteArray, stride: int, remap: Dictionary, order: Array[int]) -> PackedInt32Array:
	var n := data.size() / stride
	var idx := PackedInt32Array()
	idx.resize(n)
	for i in n:
		var v := data.decode_u16(i * 2) if stride == 2 else data.decode_u32(i * 4)
		if not remap.has(v):
			remap[v] = order.size()
			order.append(v)
		idx[i] = int(remap[v])
	return idx
