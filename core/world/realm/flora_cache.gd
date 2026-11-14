extends RefCounted
## Disk cache of the flora's placement (RealmFlora.build). The scatter is deterministic for its
## inputs -- the seeds, the layout, the sites / ways / portals / arenas registered before it, the
## ground -- so its output (final per-chunk instance buffers, the trees, the canopy list, the cover
## grid, the ground heights) is stored once in the GenCache and a later launch adopts it instead
## of running the scatter (about 3.5 s of the build).
##
## An entry is trusted when
##   - its fingerprint matches: SHA-256 over the registered keep-outs (sites, ways, portals,
##     arenas, tree_clear), the command-line flags, and the GenCache salts of every generator the
##     placement reads (editing one rebuilds it);
##   - a sparse re-sample of the ground matches the stored one (one ray in nine, ~70 ms): a hill,
##     rock or building that moved since shows here.
## Anything else is a miss and the scatter runs and rewrites the entry.

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const Zones := preload("res://core/world/realm/dress_zones.gd")

const SELF := "res://core/world/realm/realm_flora.gd"       ## the generator whose edits retire an entry
const KEY := "flora|placement|v1"
const STRIDE := 3                                            ## the verifying ray grid
## generators read by the placement beyond realm_flora.gd itself
const READS := [
	"res://core/world/realm/tree_gen.gd", "res://core/world/realm/flora_looks_marches.gd", "res://core/world/realm/flora_old_undergrowth.gd",
	"res://core/world/realm/dress_zones.gd", "res://core/world/realm/realm_layout.gd", "res://core/world/realm/realm_land.gd",
	"res://core/world/world_lanes.gd", "res://core/life/village/village_cast.gd", "res://core/world/realm/flora_emit.gd", "res://core/world/realm/flora_tables.gd",
	"res://core/world/realm/scale_pilot.gd",
]


static func fingerprint(root: Node) -> String:
	var arenas: Array = []
	for a in root.get_tree().get_nodes_in_group(&"boss_arena"):
		var ar := a as Node3D
		arenas.append([ar.global_position, float(ar.get("radius"))])
	var flags: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--no-") and a != "--no-title":
			flags.append(a)                         # (the A/B switches; the rest, and --no-title, are a harness's own)
	var parts: Array = [GenCache.salt(SELF), flags, WorldLanes.sites, WorldLanes.portals, WorldLanes.extra_lanes,
		Zones.lanes(), arenas, RealmLayout.PATHS, RealmLayout.REGIONS, RealmLayout.BOUNDS, RealmLayout.OLD_BOUNDS]
	for p: String in READS:
		parts.append(GenCache.salt(p))
	# the tree-free rounds the places asked for (a new one left a cached layout's oaks standing in Saltmarket's yard)
	parts.append((load(SELF) as GDScript).get("tree_clear"))
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for part: Variant in parts:
		ctx.update(var_to_bytes(part))
	return ctx.finish().hex_encode()


## The stored placement for `fp`, or {}.
static func load_hit(fp: String) -> Dictionary:
	var packed: Variant = GenCache.load_var(KEY, SELF)
	if not (packed is Dictionary) or String((packed as Dictionary).get("fp", "")) != fp:
		return {}
	var raw: PackedByteArray = (packed as Dictionary).z
	var bytes := raw.decompress(int((packed as Dictionary).n), FileAccess.COMPRESSION_ZSTD)
	var v: Variant = bytes_to_var(bytes)
	return v if v is Dictionary else {}


static func save(fp: String, payload: Dictionary) -> void:
	var bytes := var_to_bytes(payload)
	GenCache.save_var(KEY, SELF, {"fp": fp, "n": bytes.size(), "z": bytes.compress(FileAccess.COMPRESSION_ZSTD)})


## Decimated ground for the verifying samples: heights, slopes and "is the terrain" on a STRIDE grid.
static func sparse(gy: PackedFloat32Array, gn: PackedFloat32Array, ok: PackedByteArray, nx: int, nz: int) -> Dictionary:
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	var c := PackedByteArray()
	for j in range(0, nz, STRIDE):
		for i in range(0, nx, STRIDE):
			var k := j * nx + i
			a.append(gy[k])
			b.append(gn[k])
			c.append(ok[k])
	return {"gy": a, "gn": b, "ok": c}


## True when the world still holds the ground the entry was made on.
static func verify(space: PhysicsDirectSpaceState3D, sp: Dictionary, x0: float, z0: float, nx: int, nz: int, cell: float) -> bool:
	var a: PackedFloat32Array = sp.gy
	var b: PackedFloat32Array = sp.gn
	var c: PackedByteArray = sp.ok
	var q := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, Layers.WORLD | Layers.PROPS)
	var s := 0
	for j in range(0, nz, STRIDE):
		for i in range(0, nx, STRIDE):
			if s >= a.size():
				return false
			var x := x0 + i * cell
			var z := z0 + j * cell
			q.from = Vector3(x, 140.0, z)
			q.to = Vector3(x, -70.0, z)
			var hit := space.intersect_ray(q)
			var y: float
			var ny := 1.0
			var terrain := 1
			if hit.is_empty():
				y = RealmLayout.macro_height(x, z)
			else:
				y = (hit.position as Vector3).y
				ny = (hit.normal as Vector3).y
				terrain = 1 if String((hit.collider as Node).name).begins_with("Terrain") else 0
			if absf(y - a[s]) > 0.002 or absf(ny - b[s]) > 0.01 or terrain != c[s]:
				return false
			s += 1
	return s == a.size()
