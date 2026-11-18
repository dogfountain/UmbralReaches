extends RefCounted
## The wonders' placement cache. A family's SEARCH (candidate grids, WK.place / place_first / find, the way and site tests, the
## height reads) is deterministic for what it reads, and was the part of a warm boot the geometry cache (wonder_kit.gd) does not
## cover. A family asks for a key, loads its stored picks on a hit and builds straight from them (every site, flight, terrace,
## chest and light is still registered by the builders, in the same order), or searches as before and saves what it picked.
##
## The key is a SHA-256 over everything the search reads: the family's name and the salts of the scripts it runs (an edit
## retires its entry), the ground (RealmLand.ground_digest: heights and pools), the layout's tables (ways, regions, bounds),
## the reserved places (WK.protect_fp), the command-line switches and the WorldLanes sites registered so far (so every wonder
## before it, run from its own stored picks or searched, left the same list). A fresh key means a miss: the search runs and
## the entry is rewritten. Load by path (no class_name), as wonder_kit.gd is.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const Land := preload("res://core/world/realm/realm_land.gd")

## scripts every search reads beyond the family's own
const READS := [
	"res://core/world/realm/wonders/r39/wonder_kit.gd", "res://core/world/realm/wonders/r39/wonder_plan.gd",
	"res://core/world/realm/realm_land.gd", "res://core/world/realm/realm_layout.gd", "res://core/world/realm/path_index.gd",
	"res://core/world/realm/realm_reaches.gd", "res://core/world/world_lanes.gd", "res://world/areas/ossuary/oss_frame.gd",
]

static var _world_fp := ""             ## the ground and the layout's tables, hashed once per Realm build


## Forget the hashed world (the Realm build calls it first: a rebuild in one process may stand on other ground).
static func reset() -> void:
	_world_fp = ""


static func _world() -> String:
	if _world_fp == "":
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(Land.ground_digest().to_utf8_buffer())
		ctx.update(var_to_bytes([RealmLayout.PATHS, RealmLayout.REGIONS, RealmLayout.BOUNDS, RealmLayout.OLD_BOUNDS, RealmReaches.MARCH_BOUNDS]))
		_world_fp = ctx.finish().hex_encode()
	return _world_fp


## The cache key of `family` (its own script `own` and any further `scripts` it runs), for the world as it stands now.
static func key(family: String, own: String, scripts: Array = []) -> String:
	var flags: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--no-") and a != "--no-title":
			flags.append(a)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([family, flags, _world(), WK.protect_fp()]))
	var salts: Array = []
	for p: String in READS:
		salts.append(GenCache.salt(p))
	salts.append(GenCache.salt(own))
	for p: String in scripts:
		salts.append(GenCache.salt(p))
	ctx.update(var_to_bytes(salts))
	ctx.update(var_to_bytes(WorldLanes.sites))
	return "wplan|%s|%s" % [family, ctx.finish().hex_encode()]


## The stored picks for `key` (a Dictionary), or null.
static func load_plan(k: String, own: String) -> Variant:
	var v: Variant = GenCache.load_var(k, own)
	return v if v is Dictionary else null


static func save_plan(k: String, own: String, plan: Dictionary) -> void:
	GenCache.save_var(k, own, plan)
