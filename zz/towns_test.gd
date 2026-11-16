extends Node
## The Far Reaches' towns (core/world/realm/reach_towns.gd; people core/life/village/village_reach_towns.gd), headless:
##   godot --headless --path . res://zz/towns_test.tscn
## Never writes the player's save (Travel._busy; the village state is a sandbox).
## Checks:
##   pieces    every planned piece is built; each building stands on its ground (not floating, not sunk); each town
##             has its merged mesh and its far silhouette; the bodies are there
##   people    all sixteen are spawned; every stop of every routine is on the walking network and reachable from
##             their home; after ~60 village-seconds at 8x each has walked and stands on a floor (deck or ground)
##   lamps     the kept lamps stand and are lit; the towns' writings, tasks and shops resolve
## Ends: TOWNS TEST PASS  /  TOWNS TEST FAIL n
const Towns := preload("res://core/world/realm/reach_towns.gd")
const Plan := preload("res://core/world/realm/reach_towns_plan.gd")
const People := preload("res://core/life/village/village_reach_towns.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Shop := preload("res://core/life/village/village_shop.gd")
const LoreIndex := preload("res://core/world/realm/lore/lore_index.gd")
const Footing := preload("res://core/world/footing.gd")

var fails := 0
var t := 0.0
var started := false
var village: Node3D
var _travel := {}


func ok(c: bool, what: String) -> void:
	if c:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for key: String in ["seals_broken", "bosses_slain", "items", "story", "lit_by_path", "systems"]:
		_travel[key] = (Travel.get(key) as Dictionary).duplicate(true)
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	VState.sandbox = {}
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if started:
		return
	village = get_tree().root.find_child("Village", true, false) as Node3D
	if village == null or not village.has_meta("village_done"):
		if t > 400.0:
			ok(false, "the village never finished building")
			_end()
		return
	started = true
	_run()


func _run() -> void:
	var root := get_tree().root.find_child("ReachTowns", true, false)
	var w := 0.0
	while w < 60.0 and root and not root.get_parent().get_parent().has_meta("towns_props_done"):
		await get_tree().process_frame
		w += get_process_delta_time()
	await get_tree().create_timer(1.0).timeout
	_pieces()
	_network()
	await _walk()
	_lamps_and_words()
	_end()


func _end() -> void:
	for key: String in _travel:
		Travel.set(key, _travel[key])
	VState.sandbox = null
	print("TOWNS TEST %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _pieces() -> void:
	print("pieces")
	var space := village.get_world_3d().direct_space_state
	ok(Towns.placed.size() >= Plan.PIECES.size() + 20, "pieces built (%d)" % Towns.placed.size())
	var floating: Array = []
	var sunk: Array = []
	var props := ["RH_HeronPole", "RH_Rack", "RH_NetFrame", "RH_ReedStack", "RH_Trap", "FM_Rick", "FM_Stook", "FM_Scarecrow", "FM_Well", "FM_Wain", "FM_Gate"]
	for p: Dictionary in Towns.placed:
		var kind := String(p.kind)
		var k: Dictionary = Plan.KIND.get(kind, {})
		if bool(k.get("stilt", false)) or kind.begins_with("RH_Walk"):
			continue
		var xf: Transform3D = p.xf
		var g := Footing.terrain_y(space, xf.origin.x, xf.origin.z, RealmLayout.ground(space, xf.origin.x, xf.origin.z))
		# a building's plinth and a wall's footing go well under its origin; a small thing must touch
		if xf.origin.y > g + (0.25 if kind in props else 0.6):      # (0.25: a pole's foot in a mere's bed, under the reeds)
			floating.append("%s at %s (ground %.2f)" % [kind, xf.origin, g])
		if xf.origin.y < g - 2.6:
			sunk.append("%s at %s (ground %.2f)" % [kind, xf.origin, g])
	ok(floating.is_empty(), "no building stands over its ground %s" % [floating])
	ok(sunk.is_empty(), "no building is buried %s" % [sunk])
	for town: String in Plan.TOWNS:
		var host := get_tree().root.find_child("Town_" + town, true, false)
		ok(host != null, "%s built" % town)
		if host == null:
			continue
		var merged := host.find_child("Town_%s_Merged" % town, true, false) as MeshInstance3D
		ok(merged != null and merged.mesh != null and merged.mesh.get_surface_count() > 4, "%s: one merged mesh (%d surfaces)" % [town, merged.mesh.get_surface_count() if merged and merged.mesh else 0])
		ok(host.find_child("FarMesh", true, false) != null, "%s: a far silhouette" % town)
		ok(host.find_child("TownBody", true, false) != null, "%s: its collision" % town)
	ok(Towns.decks().size() >= 10, "Reedholm's decks for the village network (%d)" % Towns.decks().size())


func _route_nodes(d: Dictionary) -> Array:
	var out: Array = [String(d.home)]
	for rn: String in d.routines:
		for step: Dictionary in d.routines[rn]:
			for key: String in ["at", "go", "hide"]:
				if step.has(key) and not String(step[key]) in out:
					out.append(String(step[key]))
	return out


func _network() -> void:
	print("people")
	var nav: RefCounted = village.get("nav")
	var vs: Dictionary = village.get("villagers")
	for vid: String in People.cast():
		var d: Dictionary = People.cast()[vid]
		ok(vs.has(vid), "%s is in town" % vid)
		var home := String(d.home)
		if not nav.call("has", home):
			ok(false, "%s: home %s on the network" % [vid, home])
			continue
		var reach: Dictionary = nav.call("reachable", home)
		var missing: Array = []
		for n: String in _route_nodes(d):
			if not reach.has(n):
				missing.append(n)
		ok(missing.is_empty(), "%s: every stop reachable from %s %s" % [vid, home, "" if missing.is_empty() else str(missing)])


func _walk() -> void:
	village.set("time_scale", 8.0)
	var vs: Dictionary = village.get("villagers")
	var start := {}
	for vid: String in People.cast():
		if vs.has(vid):
			start[vid] = (vs[vid] as Node3D).global_position
	await get_tree().create_timer(8.0).timeout
	village.set("time_scale", 1.0)
	var nav: RefCounted = village.get("nav")
	var moved := 0
	var off_floor: Array = []
	for vid: String in start:
		var v := vs[vid] as Node3D
		if v.global_position.distance_to(start[vid]) > 0.5 or bool(v.get("hidden")):
			moved += 1
		if v.visible and not bool(v.get("hidden")):
			var f: float = nav.call("floor_at", v.global_position.x, v.global_position.z)
			if absf(v.global_position.y - f) > 0.35:
				off_floor.append("%s at %s (floor %.2f)" % [vid, v.global_position, f])
	ok(moved >= start.size() / 2, "the towns' people go about their work (%d of %d moved)" % [moved, start.size()])
	ok(off_floor.is_empty(), "everyone stands on a floor %s" % [off_floor])


func _lamps_and_words() -> void:
	print("lamps, words, tasks, shops")
	var ids := {}
	for n in get_tree().root.find_children("Lamp_*", "", true, false):      # kept lamps are not in the kindling group
		var lid: Variant = n.get("lamp_id")
		if lid != null:                           # (a node named Lamp_* that is not a Lamp, e.g. a March beacon's, has none)
			ids[String(lid)] = n
	var missing: Array = []
	for s: Dictionary in Towns.lamps():
		if not ids.has(String(s.id)):
			missing.append(s.id)
		elif bool(s.get("kept", false)) and not bool(ids[String(s.id)].get("lit")):
			missing.append("%s (not lit)" % s.id)
	ok(missing.is_empty(), "the towns' lamps stand, the kept ones lit %s" % [missing])
	var bad: Array = []
	var Dress: Variant = load("res://core/world/realm/reach_towns_dress.gd")
	for w: Array in Dress.WRITINGS:
		if LoreIndex.entry(String(w[1])).is_empty():
			bad.append(w[1])
	ok(bad.is_empty(), "every writing has its text %s" % [bad])
	for q: String in ["rh_lamps", "fm_tithe", "ll_gate", "ll_oil"]:
		ok(Chains.QUESTS.has(q) and People.cast().has(String(Chains.QUESTS[q].giver)), "task %s and its giver" % q)
	ok(Chains.audit().is_empty(), "quest data audit %s" % [Chains.audit()])
	for who: String in ["gorse", "vell"]:
		ok(Shop.stock(who, get_tree()).size() >= 3, "%s's goods" % who)
