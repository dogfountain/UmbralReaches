extends RefCounted
## The land's height grid, cached. RealmLand._heights() (noise, path carving, the kept old ground, the
## rift's flows: 383 x 286 vertices of pure math) took ~7.6 s of every boot of the doubled Realm, and of
## every test. Its result depends only on the old terrain it samples and on the Realm's code, so it is
## stored once in the GenCache under a fingerprint of those and adopted after. The meshes' costly parts
## (the terrain's and the ring's normals and biome splat, the pools) are stored beside it under the same
## fingerprint: about 2.8 s more.
##
## The fingerprint is the old samples plus the source hash of every script under core/world/realm/ (and
## core/world/world_lanes.gd): conservative on purpose, so any edit to the world's code rebuilds the
## grid rather than trusting a stale one. Load by path (no class_name).

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/world/realm/land_cache.gd"
const KEY := "land|heights|v1"
const MESH_KEY := "land|meshes|v1"
const ROOTS := ["res://core/world/realm/"]
const EXTRA := ["res://core/world/world_lanes.gd", "res://world/areas/ossuary/oss_frame.gd"]   # the quarry and the landing shape the ground (an edit there did not rebuild it)

static var _sources: Array = []


## Every script under `dir`. An exported pack lists a script as its compiled .gdc and/or a .gd.remap: both name the
## same .gd, so an export finds the same list a dev run does (and the shipped entry's fingerprint matches).
static func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		var g := f.trim_suffix(".remap")
		if g.ends_with(".gdc"):
			g = g.trim_suffix("c")
		if g.ends_with(".gd") and not out.has(dir + g):
			out.append(dir + g)
	for sub: String in d.get_directories():
		_scan(dir + sub + "/", out)


static func sources() -> Array:
	if _sources.is_empty():
		var out: Array = []
		for r: String in ROOTS:
			_scan(r, out)
		out.append_array(EXTRA)
		out.sort()
		_sources = out
	return _sources


static func fingerprint(old: PackedFloat32Array, old_dims: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(old_dims))
	ctx.update(old.to_byte_array())
	for p: String in sources():
		ctx.update(var_to_bytes([p, GenCache.salt(p)]))
	return ctx.finish().hex_encode()


## [heights, wear] stored for `fp`, or [].
static func load_hit(fp: String) -> Array:
	for v: Variant in GenCache.load_vars(KEY, SELF):
		if v is Dictionary and String((v as Dictionary).get("fp", "")) == fp:
			var h: Variant = (v as Dictionary).get("h")
			var w: Variant = (v as Dictionary).get("w")
			if h is PackedFloat32Array and w is PackedFloat32Array:
				return [h, w]
	return []


static func save(fp: String, h: PackedFloat32Array, w: PackedFloat32Array) -> void:
	GenCache.save_var(KEY, SELF, {"fp": fp, "h": h, "w": w})


## [heights, wear]: the cached grid for fingerprint `fp`, or `build` (RealmLand._heights) run and its result
## stored. The lane tables _heights builds on the way are built here on a hit too.
static func heights(fp: String, n: int, build: Callable) -> Array:
	var hit := load_hit(fp)
	if hit.size() == 2 and (hit[0] as PackedFloat32Array).size() == n:
		preload("res://core/world/realm/dress_zones.gd").lane_dist(Vector2.ZERO)
		return hit
	var hw: Array = build.call()
	save(fp, hw[0], hw[1])
	return hw


## The meshes' data for fingerprint `fp` ({t, r, p}: RealmLand._terrain_data, _ring_data, _pool_data), or `build`
## run and its result stored (zstd: about 6 MB of normals, colours and UVs).
static func meshes(fp: String, build: Callable) -> Dictionary:
	for v: Variant in GenCache.load_vars(MESH_KEY, SELF):
		if v is Dictionary and String((v as Dictionary).get("fp", "")) == fp:
			var raw: PackedByteArray = (v as Dictionary).z
			var d: Variant = bytes_to_var(raw.decompress(int((v as Dictionary).n), FileAccess.COMPRESSION_ZSTD))
			if d is Dictionary and (d as Dictionary).has_all(["t", "r", "p"]):
				return d
	var made: Dictionary = build.call()
	var bytes := var_to_bytes(made)
	GenCache.save_var(MESH_KEY, SELF, {"fp": fp, "n": bytes.size(), "z": bytes.compress(FileAccess.COMPRESSION_ZSTD)})
	return made
