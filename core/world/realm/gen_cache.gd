extends RefCounted
## Disk cache for the Realm's procedural meshes (RockKit, TreeGen) and convex shapes. Building them
## is pure GDScript (rocks ~5-25 ms each, trees ~10-30 ms, simplified hulls ~10 ms) and was most
## of the load. Generators are deterministic for a key, so the result is saved once and loaded after.
##
## - Every run reads res://art/realm_cache/ (shipped with the export) then user://realm_cache/.
##   Only a bake writes res:// -- a dev run launched with `-- --bake-cache` (r30). Every other run,
##   dev and test runs included, writes misses to user://realm_cache/, so tests no longer churn the
##   shipped cache or its manifest. Bake before packing (umbral-pack).
## - Each entry carries a salt = hash of its generator's source, so editing a generator rebuilds its
##   entries automatically. Exported builds can't hash .gd source, so dev runs also keep a manifest
##   (_salts.bin: generator path -> current salt) that ships with the cache; an export checks entries
##   against it, so an entry a dev run did not revisit after its generator changed is rebuilt rather
##   than trusted. Run the game once with --bake-cache before exporting so the cache is complete.
## - The .bin entries (tree metadata, chunk indexes, convex hull points, the manifest) are not
##   Godot resources: export_presets.cfg ships them with include_filter "art/realm_cache/*.bin".
## - Materials that are runtime objects (no resource_path) are stripped on save; the caller
##   re-applies them (RockKit does). File-based materials (.tres) are kept as references.
## - Housekeeping: report() sizes the cache per generator and finds stale entries (generator source
##   changed or deleted) and duplicate geometry; prune() deletes the stale ones (dev only).
##   Tool: godot --headless --path . res://zz/storage_cache.tscn [-- --prune]
## Delete the folder to force a full rebuild. Load by path (no class_name):
##   const GenCache := preload("res://core/world/realm/gen_cache.gd")

const RES_DIR := "res://art/realm_cache/"
const USER_DIR := "user://realm_cache/"   ## the default; UMBRAL_CACHE_DIR overrides it (user_dir())
const MANIFEST := "_salts.bin"

static var _salts := {}
## Entries owned by no single script (the placement cache: its key hashes a whole folder of them) name a pseudo path and set its
## salt here: whatever hashes their inputs. salt() answers it first, report() / prune() judge the entries by it.
static var overrides := {}
const PLACEMENT_OWNER := "pcache://placements"
const PLACEMENT_SCRIPT := "res://core/world/realm/placement_cache.gd"
static var _shapes := {}                ## mesh -> shape (instances sharing a mesh share the hull)
static var _manifest: Variant = null    ## generator path -> salt, as last seen by a dev run
static var _primed := {}                ## key -> ArrayMesh loaded or generated ahead of load_mesh (main thread only)
static var _lock := Mutex.new()
static var enabled := true
static var _dev: Variant = null
static var _bake: Variant = null


## Dev mode = running from the project folder on disk (res://art/realm_cache/ is a real, writable
## folder). Not just "editor binary": the editor binary can also run an exported .pck, where the
## .gd sources aren't readable as text and res:// is read-only -- that is an export run.
static func dev() -> bool:
	if _dev == null:
		_dev = OS.has_feature("editor") and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://core"))
	return bool(_dev)


## Bake mode = a dev run asked to write the shipped cache: `godot --path . -- --bake-cache`.
static func baking() -> bool:
	if _bake == null:
		_bake = dev() and ("--bake-cache" in OS.get_cmdline_user_args() or "--bake-cache" in OS.get_cmdline_args())
	return bool(_bake)


static func _write_dir() -> String:
	return RES_DIR if baking() else user_dir()


static var _user_dir := ""


## Where misses are written and read after the shipped cache: user://realm_cache/, or the folder in
## UMBRAL_CACHE_DIR. tools/run_tests.sh points every test at one shared folder: each test has its own
## HOME, so user:// started empty for every test and each rebuilt the whole Realm (about 40 s of the
## doubled world's boot). Writes go to a temp file and are renamed in, so tests sharing it is safe.
static func user_dir() -> String:
	if _user_dir == "":
		var env := OS.get_environment("UMBRAL_CACHE_DIR")
		_user_dir = USER_DIR if env == "" else env.trim_suffix("/") + "/"
	return _user_dir


static func salt(script_path: String) -> int:
	if overrides.has(script_path):
		return int(overrides[script_path])
	_lock.lock()
	if not _salts.has(script_path):
		var s := 0
		if dev():
			s = FileAccess.get_file_as_string(script_path).hash()
			_note_salt(script_path, s)
		else:
			s = int(_read_manifest().get(script_path, 0))   # 0 = unknown: trust what was baked
		_salts[script_path] = s
	var out: int = _salts[script_path]
	_lock.unlock()
	return out


static func _read_manifest() -> Dictionary:
	if _manifest == null:
		_manifest = {}
		var f := FileAccess.open(RES_DIR + MANIFEST, FileAccess.READ)
		if f:
			var d: Variant = f.get_var()
			if d is Dictionary:
				_manifest = d
	return _manifest


## Bake only: keep the shipped manifest in step with the generator sources.
static func _note_salt(script_path: String, s: int) -> void:
	if not baking():
		return
	var m := _read_manifest()
	if int(m.get(script_path, 0)) == s:
		return
	m[script_path] = s
	DirAccess.make_dir_recursive_absolute(RES_DIR)
	var f := FileAccess.open(RES_DIR + MANIFEST, FileAccess.WRITE)
	if f:
		f.store_var(m)


static func _file(dir: String, key: String, ext: String) -> String:
	return dir + key.md5_text() + ext


static func _fresh(r: Resource, script_path: String) -> bool:
	if r == null:
		return false
	var s := salt(script_path)
	return s == 0 or int(r.get_meta("gen_salt", -1)) == s


## A cached mesh for `key` from generator `script_path`, or null.
static func load_mesh(key: String, script_path: String) -> ArrayMesh:
	if _primed.has(key):
		return _primed[key]
	if not enabled:
		return null
	for dir: String in [RES_DIR, user_dir()]:
		var path := _file(dir, key, ".res")
		if ResourceLoader.exists(path):
			var m := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
			if _fresh(m, script_path):
				return m
	return null


## Hold a mesh for the next load_mesh(key): a batch that wants many entries (the rigs) loads the
## hits here and generates the misses on workers, then the ordinary load path finds them all.
static func prime(key: String, mesh: ArrayMesh) -> void:
	if mesh != null:
		_primed[key] = mesh


## Load the cached mesh for `key` ahead of use; true when it was there (and fresh).
static func prime_mesh(key: String, script_path: String) -> bool:
	var m := load_mesh(key, script_path)
	if m == null:
		return false
	_primed[key] = m
	return true


static func save_mesh(key: String, script_path: String, mesh: ArrayMesh) -> void:
	if not enabled or mesh == null:
		return
	var copy := mesh.duplicate() as ArrayMesh
	for i in copy.get_surface_count():
		var mat := copy.surface_get_material(i)
		if mat != null and mat.resource_path == "":
			copy.surface_set_material(i, null)      # runtime material: the caller re-applies it
	copy.set_meta("gen_salt", salt(script_path))
	copy.set_meta("gen_script", script_path)        # lets report()/prune() judge staleness
	copy.resource_name = key
	var dir := _write_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	# write beside it and rename over: a quit mid-write (or another game process reading the same
	# cache) never sees half a file
	var final := _file(dir, key, ".res")
	var tmp := final.trim_suffix(".res") + ".%d.tmp.res" % OS.get_process_id()
	if ResourceSaver.save(copy, tmp, ResourceSaver.FLAG_COMPRESS) == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(final))


## Any Variant (dictionaries of numbers / packed arrays) for `key`, or null.
## Every stored value for `key` whose generator is current: the user/test cache's first, then the shipped
## one. For a caller that keeps one entry under a fixed key and checks its own fingerprint (the flora
## placement): load_var stops at the first, and a stale shipped entry hid the fresh one written after it.
static func load_vars(key: String, script_path: String) -> Array:
	var out: Array = []
	if not enabled:
		return out
	for dir: String in [user_dir(), RES_DIR]:
		var path := _file(dir, key, ".bin")
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null or f.get_length() < 8:
				continue
			var d: Variant = f.get_var()
			if d is Dictionary and (salt(script_path) == 0 or int((d as Dictionary).get("gen_salt", -1)) == salt(script_path)):
				out.append((d as Dictionary).get("v"))
	return out


static func load_var(key: String, script_path: String) -> Variant:
	if not enabled:
		return null
	for dir: String in [RES_DIR, user_dir()]:
		var path := _file(dir, key, ".bin")
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null or f.get_length() < 8:
				continue                         # unreadable or empty: rebuilt and rewritten
			var d: Variant = f.get_var()
			if d is Dictionary and (salt(script_path) == 0 or int((d as Dictionary).get("gen_salt", -1)) == salt(script_path)):
				return (d as Dictionary).get("v")
	return null


static func save_var(key: String, script_path: String, v: Variant) -> void:
	if not enabled:
		return
	var dir := _write_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var final := _file(dir, key, ".bin")
	var tmp := final + ".%d.tmp" % OS.get_process_id()
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f:
		f.store_var({"gen_salt": salt(script_path), "gen_script": script_path, "v": v})
		f.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(final))


## A convex collision shape for `mesh` (simplified hull), cached by the mesh's resource path when
## it has one (imported GLB sub-meshes do), else built every time.
static func convex_shape(mesh: Mesh, script_path: String) -> Shape3D:
	if _shapes.has(mesh):
		return _shapes[mesh]
	var out := _convex(mesh, script_path)
	_shapes[mesh] = out
	return out


static func _convex(mesh: Mesh, script_path: String) -> Shape3D:
	var rp := mesh.resource_path
	if rp != "":
		var pts: Variant = load_var("convex|" + rp, script_path)
		if pts is PackedVector3Array:
			var sh := ConvexPolygonShape3D.new()
			sh.points = pts
			return sh
	var made := mesh.create_convex_shape(true, true)
	if rp != "" and made is ConvexPolygonShape3D:
		save_var("convex|" + rp, script_path, (made as ConvexPolygonShape3D).points)
	return made


# --- housekeeping (dev tool; see zz/storage_cache.gd) -----------------------------------------

## Salt of every script under res:// plus every generator the manifest knows (some key on a .glb),
## i.e. what a dev run would compute, for judging old entries that predate the gen_script tag.
static func _all_salts() -> Dictionary:
	var out := {}
	for p: String in _read_manifest():
		if FileAccess.file_exists(p):
			out[FileAccess.get_file_as_string(p).hash()] = p
	var stack: Array[String] = ["res://core", "res://world", "res://autoload"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var da := DirAccess.open(d)
		if da == null:
			continue
		for sub in da.get_directories():
			stack.append(d.path_join(sub))
		for f in da.get_files():
			if f.get_extension() == "gd":
				var p := d.path_join(f)
				out[FileAccess.get_file_as_string(p).hash()] = p
	return out


## One cache directory, entry by entry: {files, bytes, by_script: {path: [count, bytes]},
## stale: [file...], dupes: [[file, same_as]...]}. Stale = generator edited since (salt matches no
## current script) or deleted. Dupes = identical geometry under two keys. Dev builds only (needs source).
static func report(dir := RES_DIR) -> Dictionary:
	var salts := _all_salts()
	var out := {"files": 0, "bytes": 0, "by_script": {}, "stale": [], "dupes": []}
	var geo := {}
	var cur := {}                       ## script -> salt of its current source (read once)
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		var ext := f.get_extension()
		if f == MANIFEST or not ext in ["res", "bin"]:
			continue
		var path := dir + f
		var size := FileAccess.get_file_as_bytes(path).size()
		out.files += 1
		out.bytes += size
		var s := -1
		var script := ""
		if ext == "res":
			var r := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if r:
				s = int(r.get_meta("gen_salt", -1))
				script = String(r.get_meta("gen_script", ""))
			if r is ArrayMesh:
				var h := _geo_hash(r as ArrayMesh)
				if geo.has(h):
					(out.dupes as Array).append([f, geo[h]])
				else:
					geo[h] = f
		else:
			var fa := FileAccess.open(path, FileAccess.READ)
			var d: Variant = fa.get_var() if fa else null
			if d is Dictionary:
				s = int((d as Dictionary).get("gen_salt", -1))
				script = String((d as Dictionary).get("gen_script", ""))
		if script == "":
			script = String(salts.get(s, ""))
		if script == PLACEMENT_OWNER and not cur.has(script):
			var pc: Variant = load(PLACEMENT_SCRIPT)
			pc.code_fp()                                # (seeds overrides[PLACEMENT_OWNER] from the sources as they are now)
			cur[script] = int(overrides.get(script, 0))
		if script != "" and not cur.has(script):
			cur[script] = FileAccess.get_file_as_string(script).hash() if FileAccess.file_exists(script) else 0
		var live := script != "" and int(cur[script]) == s
		var tag := script if live else "(stale)"
		var row: Array = (out.by_script as Dictionary).get(tag, [0, 0])
		(out.by_script as Dictionary)[tag] = [int(row[0]) + 1, int(row[1]) + size]
		if not live:
			(out.stale as Array).append(f)
	return out


static func _geo_hash(m: ArrayMesh) -> int:
	var parts: Array = []
	for i in m.get_surface_count():
		var a := m.surface_get_arrays(i)
		parts.append(hash(a[Mesh.ARRAY_VERTEX]))
		parts.append(hash(a[Mesh.ARRAY_INDEX]))
		parts.append(hash(a[Mesh.ARRAY_TEX_UV]))
	return str(parts).hash()


## Delete stale entries (see report). Returns how many files were removed. Dev builds only, and
## only once the manifest exists (a dev run has listed every generator, .glb-keyed ones included).
static func prune(dir := RES_DIR) -> int:
	if not dev() or _read_manifest().is_empty():
		return 0
	var n := 0
	for f: String in report(dir).stale:
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f)) == OK:
			n += 1
	return n
