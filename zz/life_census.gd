extends Node
## Per-region census of the living world: what lives in each region (wildlife groups by kind, shader flocks,
## villagers, wayfarers, the Far Reaches' life), so "dotted" and "alive" can be told apart by numbers before
## any frame is judged.
##   godot --headless --path . res://zz/life_census.tscn [-- --wait=20]
## Prints "CENSUS <region> <kind>=<n> ..." per region and "CENSUS done".
var main: Node
var t := 0.0
var wait_s := 6.0
var done_t := -1.0
var dump: PackedStringArray = []          ## --dump=a,b: every group's kind and centre in these regions


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wait="):
			wait_s = float(a.trim_prefix("--wait="))
		elif a.begins_with("--dump="):
			dump = a.trim_prefix("--dump=").split(",")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null:
		if t > 240.0:
			print("CENSUS FAIL the Realm never finished")
			get_tree().quit(1)
		return
	if done_t < 0.0:
		done_t = t
		return
	if t - done_t < wait_s:
		return
	set_process(false)
	_count()
	get_tree().quit(0)


func _region(p: Vector3) -> String:
	return String(RealmLayout.region_at(p.x, p.z).get("id", "?"))


func _add(per: Dictionary, reg: String, k: String, n: int) -> void:
	if not per.has(reg):
		per[reg] = {}
	(per[reg] as Dictionary)[k] = int((per[reg] as Dictionary).get(k, 0)) + n


func _count() -> void:
	var per := {}
	var w := main.get_node("Wildlife")
	for g: Node in w.get("groups"):
		if not is_instance_valid(g):
			continue
		var c: Vector3 = g.get("center")
		var n: int = (g.call("positions") as Array).size()
		_add(per, _region(c), String(g.get("kind")), maxi(n, 1))
		if _region(c) in dump:
			print("CENSUS_AT %s %s %d (%.0f, %.1f, %.0f)" % [_region(c), String(g.get("kind")), n, c.x, c.y, c.z])
	for arr: String in ["fireflies", "bats"]:
		for m: Node in w.get(arr):
			var mm := m as MultiMeshInstance3D
			_add(per, _region(mm.global_position), arr, mm.multimesh.instance_count)
			if _region(mm.global_position) in dump:
				print("CENSUS_AT %s %s %d %s" % [_region(mm.global_position), arr, mm.multimesh.instance_count, mm.global_position.round()])
	var sg: Node = w.get("signs")
	if sg != null and not dump.is_empty():
		for arr: String in ["eyes", "fields", "kettles"]:
			for m: Node in sg.get(arr):
				var mp := (m as Node3D).global_position
				if _region(mp) in dump:
					print("CENSUS_AT %s %s %s" % [_region(mp), arr, mp.round()])
	for l: Node in (w.get("moths") as Dictionary).keys():
		_add(per, _region((l as Node3D).global_position), "moth_lights", 1)
	for v: Node in get_tree().get_nodes_in_group("villager"):
		_add(per, _region((v as Node3D).global_position), "villagers", 1)
	for v: Node in get_tree().get_nodes_in_group(&"wayfarer"):
		_add(per, _region((v as Node3D).global_position), "wayfarers", 1)
	for n: Node in get_tree().get_nodes_in_group(&"life_census"):
		var info: Dictionary = n.call("census")
		for reg: String in info:
			for k: String in info[reg]:
				_add(per, reg, k, int(info[reg][k]))
	var ids: Array = []
	for r: Dictionary in RealmLayout.REGIONS:
		ids.append(String(r.id))
	for reg: String in ids:
		var parts: Array[String] = []
		var d: Dictionary = per.get(reg, {})
		var keys := d.keys()
		keys.sort()
		for k: String in keys:
			parts.append("%s=%d" % [k, int(d[k])])
		print("CENSUS %-14s %s" % [reg, " ".join(parts) if not parts.is_empty() else "(nothing)"])
	print("CENSUS done")
