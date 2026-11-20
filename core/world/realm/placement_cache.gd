extends RefCounted
## The placement passes' cache. A pass here is a deterministic SEARCH over the ground and the
## layout (the wayside's plan, the camps' settling, the ambush sites, the secrets' spots ...): it reads the world as the Realm build has
## left it so far and returns a list of picks. A warm boot should read the picks, not solve them again.
##
## The key (`key`) is a SHA-256 over everything such a search can read:
##   - the pass name and the command-line `--no-*` switches;
##   - the source of every script under CODE_ROOTS (placement code lives in the realm, the life systems, the enemy spawner and the
##     Ossuary frame; one hash for all of them, so ANY edit to a script a pass might run re-solves every pass: over-invalidating
##     costs one slow boot, a stale world would cost the player. The salts come from GenCache, so an exported pack uses the
##     manifest a bake wrote, exactly as land_cache.gd does);
##   - the ground (RealmLand.ground_digest) and the layout's tables, as wonder_plan.gd keys them;
##   - the reserved places (WK.protect_fp), the lanes' sites registered so far (so every earlier pass, cached or solved, left the
##     same world) and whatever else the pass names in `extra` (camp tables, the brazier spots ...).
## A miss solves as before and stores the picks; a hit builds from them. `verify` (zz/placement_cache_test.gd) solves on a hit too and
## compares, and compares a fresh store with what it reads back, so a cached boot and a fresh solve are shown to agree.
## Load by path (no class_name):  const PlacementCache := preload("res://core/world/realm/placement_cache.gd")

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const SELF := "res://core/world/realm/placement_cache.gd"
const OWNER := GenCache.PLACEMENT_OWNER           ## the entries' pseudo script: its salt is the code hash, so a bake's prune retires old ones
const CODE_ROOTS := ["res://core/world/", "res://core/life/", "res://core/enemy/", "res://world/areas/ossuary/"]

static var verify := false              ## solve on a hit and compare (the equality test)
static var outcomes := {}               ## pass -> "hit" | "miss" | "match" | "stored" | "MISMATCH"
static var mismatches: Array[String] = []
static var ms_saved := {}               ## pass -> ms a hit cost (what the pass reads back)

static var _code_fp := ""
static var _world_fp := ""
static var _scripts: Array = []


static func off() -> bool:
	return "--no-placement-cache" in OS.get_cmdline_user_args() or OS.get_environment("UMBRAL_NO_PLACEMENT_CACHE") != ""


## Forget the hashed world (the Realm build calls it first: a rebuild in one process may stand on other ground).
static func reset() -> void:
	_world_fp = ""
	outcomes.clear()
	mismatches.clear()
	ms_saved.clear()


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


## One hash of every placement script's salt.
static func code_fp() -> String:
	if _code_fp == "":
		var out: Array = []
		for r: String in CODE_ROOTS:
			_scan(r, out)
		out.sort()
		_scripts = out
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		for p: String in out:
			ctx.update(var_to_bytes([p, GenCache.salt(p)]))
		ctx.update(var_to_bytes(GenCache.salt(SELF)))
		_code_fp = ctx.finish().hex_encode()
		GenCache.overrides[OWNER] = _code_fp.hash()
	return _code_fp


## True when `script_path` is one of the scripts whose source the key hashes (the test names every pass's own script).
static func covers(script_path: String) -> bool:
	code_fp()
	return _scripts.has(script_path)


static func _world() -> String:
	if _world_fp == "":
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(Land.ground_digest().to_utf8_buffer())
		ctx.update(var_to_bytes([RealmLayout.PATHS, RealmLayout.REGIONS, RealmLayout.BOUNDS, RealmLayout.OLD_BOUNDS, RealmReaches.MARCH_BOUNDS,
			RealmLayout.SLOTS, RealmReaches.SLOTS, RealmLayout.RAIDS, EnemySpawner.REALM_CAMPS]))
		ctx.update(WK.protect_fp().to_utf8_buffer())
		_world_fp = ctx.finish().hex_encode()
	return _world_fp


## The cache key of `pass_name` for the world as it stands now. `extra` is anything else the pass reads (a Variant var_to_bytes can hold).
static func key(pass_name: String, extra: Variant = null) -> String:
	var flags: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--no-") and a != "--no-title":
			flags.append(a)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([pass_name, flags, code_fp(), _world(), extra]))
	ctx.update(var_to_bytes(WorldLanes.sites))
	return "pcache|%s|%s" % [pass_name, ctx.finish().hex_encode()]


## The stored picks for `k` (a Dictionary), or null (a miss, or the cache is off).
static func load_picks(pass_name: String, k: String) -> Variant:
	if off() or not GenCache.enabled:
		return null
	var t := Time.get_ticks_usec()
	var v: Variant = GenCache.load_var(k, OWNER)
	if v is Dictionary:
		ms_saved[pass_name] = (Time.get_ticks_usec() - t) / 1000
		return v
	return null


static func save_picks(k: String, picks: Dictionary) -> void:
	if off():
		return
	GenCache.save_var(k, OWNER, picks)


## Note what a pass did (`hit`, `miss`) for the log and the test.
static func note(pass_name: String, outcome: String) -> void:
	outcomes[pass_name] = outcome


## `verify` mode: compare what a pass solved with what the cache holds (hit) or just stored (read back from disk). A difference is
## recorded and printed; it is a bug in the pass (it read something its key does not name) or in the store.
static func compare(pass_name: String, k: String, solved: Dictionary, stored: Variant) -> void:
	var same := stored is Dictionary and _same(solved, stored)
	outcomes[pass_name] = "match" if same else "MISMATCH"
	if not same:
		mismatches.append(pass_name)
		print("PCACHE MISMATCH ", pass_name, " key ", k.right(12))


## Equal as stored: dictionaries and arrays element by element, floats exactly (the store is lossless for 32-bit floats and the
## pass reads the same ones back; a Variant round trip keeps doubles bit for bit).
static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		# an Array[Dictionary] and an Array are the same list once stored
		if not (a is Array and b is Array):
			return false
	if a is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k: Variant in da:
			if not db.has(k) or not _same(da[k], db[k]):
				return false
		return true
	if a is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in aa.size():
			if not _same(aa[i], ab[i]):
				return false
		return true
	if a is float:
		return is_equal_approx(float(a), float(b)) or (is_nan(float(a)) and is_nan(float(b)))
	return a == b


## One timed line for the load log (`PCLAP`): what a placement pass cost, whatever the outcome.
static func lap(pass_name: String, since_usec: int) -> void:
	print("PCLAP %-26s %7.1f ms  %s" % [pass_name, float(Time.get_ticks_usec() - since_usec) / 1000.0, String(outcomes.get(pass_name, ""))])


## One line for the load log.
static func summary() -> String:
	return "PCACHE %s" % [outcomes]
