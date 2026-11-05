extends Node
## Flora module check (core/world/realm/realm_flora.gd). Headless is fine (physics + counts):
##   godot --headless --path . res://zz/realm_flora_check.tscn -- --realm --realm-modules=land,flora
## Prints counts per species, then FLORA_CHECK PASS / FAIL with the reasons:
##   nothing within 1 m of a path edge (non-grass: their STYLE keep-off), nothing inside a site,
##   no tree trunk floating (ground under the trunk base gap < 0.3 m), nothing but reeds in water,
##   enough of every species, build < 4 s.
const Flora := preload("res://core/world/realm/realm_flora.gd")
var t := 0.0
var done := false
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 90.0:
		print("FLORA_CHECK FAIL timeout"); _quit(); return
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		for c in get_tree().root.get_children():
			if c.has_meta("realm_built"): main = c
	if main == null or main.get_node_or_null("RealmFlora") == null:
		return
	done = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(main)
	_quit()
func _quit() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())
func _check(main: Node) -> void:
	var bad: Array[String] = []
	var keys: Array = Flora.placed.keys(); keys.sort()
	for k: String in keys: print("FLORA_CHECK count %-10s %6d" % [k, Flora.placed[k]])
	var need := {"oak": 60, "pine": 15, "birch": 20, "willow": 8, "snag": 15, "sapling": 60, "grass": 2000, "fern": 800,
		"flowers": 200, "heather": 300, "reeds": 30, "shrub": 60, "mushroom": 60, "glowcap": 10, "log": 10}
	for k: String in need:
		if int(Flora.placed.get(k, 0)) < int(need[k]): bad.append("too few %s (%d < %d)" % [k, Flora.placed.get(k, 0), need[k]])
	var on_path := 0
	var in_site := 0
	var wet := 0
	var worst := ""
	for e: Array in Flora.instances:
		var id: String = e[0]
		var p: Vector3 = e[1]
		var sp := id.substr(0, id.rfind("_"))
		var p2 := Vector2(p.x, p.z)
		var keep: float = 1.0 if sp == "grass" else float(Flora.STYLE[sp][2]) - 0.6
		var pd := RealmLayout.path_dist(p2)
		if pd < keep:
			on_path += 1
			if worst == "": worst = "%s at (%.1f, %.1f) path_dist %.2f" % [id, p.x, p.z, pd]
		if not WorldLanes.site_at(p2, 0.0).is_empty():
			in_site += 1
			if worst == "": worst = "%s at (%.1f, %.1f) in site %s" % [id, p.x, p.z, WorldLanes.site_at(p2).name]
		if p.y < Flora.WATER_Y and not (sp in ["reeds", "cattail"]): wet += 1
	if on_path > 0: bad.append("%d on paths" % on_path)
	if in_site > 0: bad.append("%d in sites" % in_site)
	if wet > 0: bad.append("%d under water" % wet)
	var space := (main as Node3D).get_world_3d().direct_space_state
	var floating := 0
	var max_gap := 0.0
	for tr: Array in Flora.trees:
		var b: Vector3 = tr[0]
		var q := PhysicsRayQueryParameters3D.create(b + Vector3(0, 0.5, 0), b + Vector3(0, -20, 0), Layers.WORLD)
		# skip the tree's own collider (cylinder from the base up)
		var hit := space.intersect_ray(q)
		while not hit.is_empty() and String((hit.collider as Node).name) == "FloraBody":
			q.exclude = q.exclude + [hit.rid]
			hit = space.intersect_ray(q)
		if hit.is_empty(): continue
		var gap := b.y - (hit.position as Vector3).y
		max_gap = maxf(max_gap, gap)
		if gap >= 0.3:
			floating += 1
			if worst == "": worst = "%s floats %.2f at %s" % [tr[1], gap, b]
	if floating > 0: bad.append("%d trunks float" % floating)
	print("FLORA_CHECK trees %d, instances %d, max trunk gap %.2f, build %d ms" % [Flora.trees.size(), Flora.instances.size(), max_gap, Flora.build_ms])
	if Flora.build_ms > 4000: bad.append("build %d ms > 4000" % Flora.build_ms)
	if worst != "": print("FLORA_CHECK first offender: ", worst)
	print("FLORA_CHECK ", "PASS" if bad.is_empty() else "FAIL " + ", ".join(bad))
