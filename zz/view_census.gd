extends Node
## What draws round a spot (every direction, within each instance's range): per top-level part, the instances in range and how
## many draws merging them by (host, material, range, shadow, layers) would leave.
##   godot --headless --path . res://zz/view_census.tscn [-- --at=x,z]

var main: Node
var frames := 0
var at := Vector3(-100.8, 0.7, 103.7)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var p := a.trim_prefix("--at=").split(",")
			at = Vector3(float(p[0]), 0.7, float(p[1]))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	frames += 1
	if frames == 5400:
		get_tree().quit(1)
	if main == null or not main.has_meta("realm_done") or frames != 900:
		return
	var parts := {}
	for n in main.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var aabb := g.get_aabb()
		var c := g.global_transform * aabb.get_center()
		var d := c.distance_to(at)
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end:
			continue
		if g.visibility_range_begin > 0.0 and d < g.visibility_range_begin:
			continue
		if d > 420.0:
			continue
		var top := n
		while top.get_parent() != main and top.get_parent() != null:
			top = top.get_parent()
		var part := String(top.name)
		if not parts.has(part):
			parts[part] = {"n": 0, "mm": 0, "scr": 0, "shadow": 0, "groups": {}, "hosts": {}}
		var P: Dictionary = parts[part]
		P.n += 1
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			P.shadow += 1
		if g is MultiMeshInstance3D:
			P.mm += 1
			continue
		var mi := g as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.get_script() != null or mi.skeleton != NodePath("") and mi.get_node_or_null(mi.skeleton) is Skeleton3D:
			P.scr += 1
		var host := mi.get_parent()
		for s in mi.mesh.get_surface_count():
			var mat: Variant = mi.material_override if mi.material_override else (mi.get_active_material(s))
			var key := "%s|%s|%d|%d|%d|%d" % [host.get_instance_id(), mat.get_instance_id() if mat else 0, roundi(mi.visibility_range_end), roundi(mi.visibility_range_begin), mi.cast_shadow, mi.layers]
			P.groups[key] = int(P.groups.get(key, 0)) + 1
		var hn := String(host.name)
		P.hosts[hn] = int(P.hosts.get(hn, 0)) + 1
	var keys := parts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(parts[a].n) > int(parts[b].n))
	for k: Variant in keys:
		var P: Dictionary = parts[k]
		var surf := 0
		for v: int in P.groups.values():
			surf += v
		var hs: Array = P.hosts.keys()
		hs.sort_custom(func(a: Variant, b: Variant) -> bool: return int(P.hosts[a]) > int(P.hosts[b]))
		var top_hosts := []
		for h in hs.slice(0, 5):
			top_hosts.append("%s:%d" % [h, P.hosts[h]])
		print("VIEW %-16s inst %5d  shadow %5d  multimesh %4d  scripted/skinned %4d  surfaces %5d -> merged %5d   %s" % [k, P.n, P.shadow, P.mm, P.scr, surf, P.groups.size(), ", ".join(top_hosts)])
	get_tree().quit(0)
