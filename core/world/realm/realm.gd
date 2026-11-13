class_name Realm
extends RefCounted
## Entry point for the redesigned zone (docs/REALM_PLAN.md). Always on; `--realm` is still accepted:
##   godot --path . -- --realm                          everything
##   godot --path . -- --realm --realm-modules=land,flora   only those modules (for working on one)
## Each module is a script with `static func build(root: Node) -> void` (it may await), loaded by
## path, so a module that does not exist yet (or fails to parse) is skipped, not fatal. Order:
##   1 land (terrain, paths, water)
##   2 rift (lava, the crossing)  3 bosses (henge, ward, Ossuary access, camps)  4 tavern (kept)
##   5 lore (landmarks, villages, inscriptions)  6 TerrainStamp.apply (site floors)
##   7 flora (trees, undergrowth, ground cover)  8 summit dress, braziers, kept systems
##   9 assets (quality pass hooks)  10 cull_scatter / chunks
## Modules own their own files; this file and the hooks in glimmers.gd / main.gd belong to the lead.

const GroundFollow := preload("res://core/world/realm/ground_follow.gd")
const FadeGuard := preload("res://core/world/fade_guard.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")

const MODULES := {
	"land": "res://core/world/realm/realm_land.gd",
	"rift": "res://core/world/realm/realm_rift.gd",
	"bosses": "res://core/world/realm/realm_bosses.gd",
	"lore": "res://core/world/realm/realm_lore.gd",
	"wonders": "res://core/world/realm/realm_wonders.gd",      # landmarks seen from far off (realm_wonders.gd)
	"flora": "res://core/world/realm/realm_flora.gd",
	"assets": "res://core/world/realm/realm_assets.gd",
	# living-world systems (docs/LIFE_PLAN.md), built last, each owns its own folder
	"progression": "res://core/life/progression/progression.gd",
	"village": "res://core/life/village/village.gd",
	"life": "res://core/life/wildlife/wildlife.gd",
	"secrets": "res://core/life/secrets/secrets.gd",
	"encounters": "res://core/life/encounters/encounters.gd",
	"dress": "res://core/world/realm/site_dress.gd",            # clutter on the cleared ground, after everything it must avoid exists
	"lamps": "res://core/world/realm/lamps/lamp_places.gd",     # the lamps the wanderer kindles and the lights others keep
	# the navigation mesh enemies path on when flat steering is walled (core/enemy/nav_assist.gd)
	"nav": "res://core/world/realm/realm_nav.gd",
}

const PRELOAD := [
	"res://art/models/mossy_platform.glb", "res://art/models/summit_pillar.glb",
	# the east and south marches' kit scenes (13-17 MB each) are the biggest loads of the places pass
	"res://art/models/r37e_spire.glb", "res://art/models/r37e_saltworks.glb", "res://art/models/r37e_hamlet.glb", "res://art/models/r37e_cells.glb",
	"res://art/models/r37_south_hut.glb", "res://art/models/r37_south_oak.glb", "res://art/models/r37_south_wall.glb", "res://art/models/r37_south_well.glb",
]

static func module_on(id: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--realm-modules="):
			return id in a.trim_prefix("--realm-modules=").split(",")
	return true


## Build-time profile: accumulated microseconds per key (stages and shared generators), printed
## at the end of build. Cheap enough to leave on.
static var prof := {}
## Build progress for the loading screen (ui/loading_screen.gd): 0..1 and the step now running.
static var progress := 0.0
static var stage := ""
const STEPS := 18
const STAGE_NAMES := {
	"land": "Raising the land", "rift": "Opening the rift", "bosses": "Waking the wardens",
	"tavern": "Lighting the Keg", "lore": "Carving the stones", "wonders": "Raising the wonders", "stamp": "Settling the ground",
	"flora": "Growing the wood", "summit": "Dressing the summit", "assets": "Placing the relics",
	"progression": "Kindling the fires", "village": "Waking the village", "life": "Stirring the wild",
	"secrets": "Hiding what is hidden", "encounters": "Gathering the dark", "dress": "Setting out the yards", "lamps": "Hanging the lamps", "nav": "Marking the ways",
}
static var _step := 0


static func _mark(id: String) -> void:
	stage = String(STAGE_NAMES.get(id, id))
	progress = float(_step) / float(STEPS)
	_step += 1


static func prof_add(key: String, since_usec: int) -> void:
	prof[key] = int(prof.get(key, 0)) + (Time.get_ticks_usec() - since_usec)


## Forget what the last build registered (called when its night is torn down: world/main.gd
## _exit_tree). The Deeper Night rebuilds the Realm in the same process (Travel.go to the same
## scene), and the site registry is static: the first build's sites stayed, so the second build's
## lore saw every spot as taken by itself and skipped 35 of 92 inscriptions and 55 of 96 sites
## (road waystones and mileposts, the barrows, Thornwood's relics, field walls, the cart...).
static func reset_registries() -> void:
	WorldLanes.sites.clear()
	WorldLanes.extra_lanes.clear()
	WorldLanes.portals.clear()
	WorldLanes.clear_cache()
	prof.clear()
	progress = 0.0
	stage = ""
	_step = 0


## Engine resources the world's builders keep in static vars (meshes, materials, shapes). Statics
## outlive the renderer at quit ("RID allocations leaked at exit", "resources still in use"), and a
## rebuild should not inherit the last night's. Dropped with the night (world/main.gd _exit_tree);
## rebuilt on next use (GenCache makes that fast).
const _STATIC_CACHES := {
	"res://core/world/mage_statue.gd": ["_figure", "_pedestal", "_runes", "_mats"],
	"res://core/world/gothic.gd": ["_gobo"],
	"res://core/world/realm/realm_assets.gd": ["_mats", "_meshes"],
	"res://core/world/realm/rock_kit.gd": ["_meshes", "_mats", "_shapes"],
	"res://core/world/realm/tree_gen.gd": ["_cache"],
	"res://core/world/mesh_chunks.gd": ["_lod_cache"],
	"res://core/world/realm/gen_cache.gd": ["_shapes", "_primed"],
	"res://core/world/far_detail.gd": ["_shell_mat", "_far_mat"],
	"res://world/areas/ossuary/oss_kit.gd": ["_mats", "_skulls", "_bones", "_candles", "_puddle", "_flame_mesh", "_halo_mesh"],
	"res://world/areas/ossuary/ossuary.gd": ["_plate", "_ribs", "_great_rib"],
	# --- south marches ---
	"res://core/world/realm/south_marches_kit.gd": ["_cache"],
	"res://core/world/realm/site_props.gd": ["_meshes", "_cloth"],
	"res://core/world/realm/lamps/lamp.gd": ["_meshes", "_mats"],
}


static func release_caches() -> void:
	for path: String in _STATIC_CACHES:
		var s := load(path) as GDScript
		if s == null:
			continue
		for v: String in _STATIC_CACHES[path]:
			var cur: Variant = s.get(v)
			if cur is Dictionary:
				(cur as Dictionary).clear()
			elif cur is Array:
				(cur as Array).clear()
			elif cur != null:
				s.set(v, null)


static func build(root: Node) -> void:
	if root.has_meta("realm_built"):
		return
	root.set_meta("realm_built", true)
	PlacementLog.reset()
	prof.clear()
	_step = 0
	progress = 0.0
	var t0 := Time.get_ticks_msec()
	# big scenes needed late in the build (summit platform, pillars, mage) load on worker threads
	# while the modules run; SummitDress's load() then picks them up ready instead of blocking
	for path: String in PRELOAD:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path, "", true)
	root.tree_exiting.connect(DwarfRig.warm_abandon_all, CONNECT_ONE_SHOT)
	await _run("land", root)
	# the Keg's people are the longest cache misses (a mesh each, 0.6 s of GDScript): they build on
	# worker threads beside the rift and the wardens (not beside the land, whose own threads they slow)
	DwarfRig.warm_batches["tavern"] = Tavern.warm_start()
	var village_script: Variant = load("res://core/life/village/village.gd")      # no preload: a cycle through Realm
	DwarfRig.warm_batches["village"] = village_script.warm_start()
	var t := Time.get_ticks_usec()
	await root.get_tree().physics_frame
	prof_add("stage: frame wait", t)
	await _run("rift", root)
	await _run("bosses", root)
	t = Time.get_ticks_usec()
	_mark("tavern")
	await root.get_tree().process_frame     # let the loading screen draw this step
	await Tavern.prewarm_rigs(root)
	Tavern.build(root)
	prof_add("stage: tavern", t)
	await _run("lore", root)
	await _run("wonders", root)
	t = Time.get_ticks_usec()
	_mark("stamp")
	await root.get_tree().process_frame     # let the loading screen draw this step
	await TerrainStamp.apply(root)
	prof_add("stage: terrain stamp", t)
	# the village's people are done before the wood grows (their threads would slow it past its budget)
	await DwarfRig.warm_finish(DwarfRig.warm_batches.get("village", {}), root.get_tree())
	await _run("flora", root)
	t = Time.get_ticks_usec()
	_mark("summit")
	await root.get_tree().process_frame     # let the loading screen draw this step
	SummitDress.dress(root)
	prof_add("stage: summit dress", t)
	await _run("assets", root)
	for id: String in ["progression", "village", "life", "secrets", "encounters"]:
		await _run(id, root)
	await _run("dress", root)
	await _run("lamps", root)
	t = Time.get_ticks_usec()
	await TerrainStamp.settle(root)              # the ground yields to the floors as built (after every building and its dress, before the nav)
	GroundFollow.settle(root)                    # chests stand on the floors as built and the ground as settled
	prof_add("stage: terrain settle", t)
	await _run("nav", root)                      # after every collider is in; waits a bounded time for the bake
	t = Time.get_ticks_usec()
	print("REALM cull ", WorldLanes.cull_scatter(root))
	prof_add("stage: cull scatter", t)
	var keys := prof.keys()
	keys.sort_custom(func(a, b) -> bool: return int(prof[a]) > int(prof[b]))
	for k: String in keys:
		print("REALM_PROF %7.1f ms  %s" % [float(prof[k]) / 1000.0, k])
	progress = 1.0
	print("FADE_GUARD %d ranged meshes pushed out and faded after the build" % FadeGuard.sweep(root))
	print("PLACEMENT %d skipped" % PlacementLog.entries.size())
	root.set_meta("realm_done", true)              # waiters (camps, tests) can key on this
	print("REALM built in %d ms" % (Time.get_ticks_msec() - t0))


static func _run(id: String, root: Node) -> void:
	_mark(id)
	if id != "land":                            # land first, before main.gd's _ready carries on
		await root.get_tree().process_frame     # let the loading screen draw this step
	if not module_on(id):
		print("REALM skip ", id, " (--realm-modules)")
		return
	var path: String = MODULES[id]
	if not ResourceLoader.exists(path):
		print("REALM skip ", id, " (not written yet)")
		return
	var s := load(path) as GDScript
	if s == null or not s.can_instantiate():
		push_error("REALM %s failed to load" % id)
		return
	var t := Time.get_ticks_msec()
	var tu := Time.get_ticks_usec()
	await s.call("build", root)
	prof_add("module: " + id, tu)
	print("REALM %s in %d ms" % [id, Time.get_ticks_msec() - t])

