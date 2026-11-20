extends Node
## The placement cache (core/world/realm/placement_cache.gd): a cached boot and a fresh solve give the same placements.
## `PlacementCache.verify` makes every cached pass solve in full as well: on a hit it compares the stored picks with the solve, on a miss it
## stores the solve and compares it with what it reads back from disk. So after one Realm build every pass is shown equal both ways, and the
## test also checks that the passes are all there (a pass that quietly stopped using the cache would not report) and that the key moves with
## what a pass reads.
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh placement_cache
const PlacementCache := preload("res://core/world/realm/placement_cache.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")

## every pass that stores its picks (a new one is added here and to the load_bake checklist)
const PASSES := ["wayside_plan", "site_dress", "terrain_settle", "camps_plant", "camps_settle", "ambush_sites"]

var main: Node
var t := 0.0
var done := false
var fails := 0


func _ready() -> void:
	Travel._busy = true
	CodexStore.persist = false
	CodexStore.use_path("user://codex_pcache_test.cfg", false)
	PlacementCache.verify = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(what: String, ok: bool) -> void:
	print("PCACHE_T ", "PASS " if ok else "FAIL ", what)
	if not ok:
		fails += 1


func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 300.0:
		print("PCACHE_T FAIL timeout")
		done = true
		get_tree().quit(1)
		return
	if main == null or not main.has_meta("realm_done") or t < 2.0:
		return
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner") as EnemySpawner
	if spawner != null and not spawner.settled:
		return                          # the camps' second pass runs after the Realm
	if PlacementCache.outcomes.get("ambush_sites", "") == "":
		if t < 120.0:
			return                      # the director plans its ambushes once the night starts
	done = true
	_check()
	print("PCACHE_T %s %d" % ["DONE PASS" if fails == 0 else "DONE FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


func _check() -> void:
	print(PlacementCache.summary())
	for p: String in PASSES:
		var o := String(PlacementCache.outcomes.get(p, "none"))
		check("%s: stored picks equal the fresh solve (%s)" % [p, o], o == "match")
	check("no pass differed (%s)" % [PlacementCache.mismatches], PlacementCache.mismatches.is_empty())
	# an edit to any script a pass runs retires its entry: the key hashes the source of each of them
	for sp: String in ["res://core/world/realm/realm_wayside.gd", "res://core/world/realm/site_dress.gd", "res://core/world/terrain_stamp.gd",
			"res://core/enemy/enemy_spawner.gd", "res://core/life/encounters/director.gd", "res://core/life/encounters/ambush_sites.gd",
			"res://core/life/encounters/spawn_rules.gd", "res://core/world/realm/wayside_themes.gd", "res://core/world/realm/placement_cache.gd"]:
		check("the key hashes %s" % sp.get_file(), PlacementCache.covers(sp))
	# the key moves with what a pass reads, and with nothing else
	var a := PlacementCache.key("probe", [1, 2])
	check("the same inputs give the same key", a == PlacementCache.key("probe", [1, 2]))
	check("another input gives another key", a != PlacementCache.key("probe", [1, 3]))
	check("another pass gives another key", a != PlacementCache.key("probe2", [1, 2]))
	WorldLanes.register_site("pcache_probe", Rect2(1000.0, 1000.0, 2.0, 2.0), 0.0, 1.0)
	var moved := PlacementCache.key("probe", [1, 2])
	check("a new site moves the key", a != moved)
	WorldLanes.sites.pop_back()
	check("and back again", a == PlacementCache.key("probe", [1, 2]))
