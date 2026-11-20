extends RefCounted
## A person's shadow from a lower LOD of their own body (fps pass, 20 Nov): the villagers, the Living Night's folk and the
## road's travellers were the heaviest shadow casters in the Realm, 15-24k triangles each at full detail, twenty of them in
## the moon's reach at Hearthward and sixteen at Reedholm (perf_tour --casters), while the wanderer already casts from a
## 4k-triangle proxy (character_rig.gd). The body's mesh carries LODs (villager_rig.gd _generate); its shadow now draws a
## copy of one of them (about a third of the triangles, the vertices it uses only, the body's own vertex format and
## material, so the shadow pass draws it with the pipelines the body compiled), skinned to the same skeleton and cast by
## a ShadowProxy; the body casts nothing. The shadow's outline is the body's at a third of the detail: at night, under
## a soft moon, the same shape. Cached per look through GenCache.
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


## One of `mesh`'s LODs (surface 0: the first with at most `share` of its triangles) as a mesh of its own, keeping only
## the vertices it uses, in the source's vertex format. Null when the mesh has no such LOD.
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
	for l: Variant in sd.get("lods", []):
		var data: PackedByteArray = (l as Dictionary).get("index_data", PackedByteArray())
		if data.size() / stride <= int(float(base_n) * share):
			pick = data
			break
	if pick.is_empty():
		return null
	var n := pick.size() / stride
	var src := mesh.surface_get_arrays(0)
	var remap := {}
	var order := PackedInt32Array()
	var idx := PackedInt32Array()
	idx.resize(n)
	for i in n:
		var v := pick.decode_u16(i * 2) if stride == 2 else pick.decode_u32(i * 4)
		if not remap.has(v):
			remap[v] = order.size()
			order.append(v)
		idx[i] = int(remap[v])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	for ch in Mesh.ARRAY_MAX:
		if ch == Mesh.ARRAY_INDEX or src[ch] == null:
			continue
		arrays[ch] = MeshChunks._pick(src[ch], order, MeshChunks._stride(ch, src))
	arrays[Mesh.ARRAY_INDEX] = idx
	var fmt := mesh.surface_get_format(0)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES))
	return out
