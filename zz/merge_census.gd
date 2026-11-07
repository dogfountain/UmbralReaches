extends Node
## How many draws the static props could save by merging: under each top-level part, meshes grouped by (their nearest
## named host, material, draw-distance band, shadow mode, layers). Each group of n merges to 1 draw.
##   godot --headless --path . res://zz/merge_census.tscn

var main: Node
var frames := 0


func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	frames += 1
	if main == null or not main.has_meta("realm_done") or frames < 900 or frames != 900 + 0:
		if frames == 5400:
			get_tree().quit(1)
		return
	for part: String in ["RealmLore", "RealmPois", "Village", "ThornHenge", "SummitAltar", "Secrets", "RealmRift", "Area_ossuary"]:
		var root := main.find_child(part, true, false)
		if root == null:
			continue
		var groups := {}
		var total := 0
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree() or mi.get_script() != null:
				continue
			total += 1
			var host := mi.get_parent()
			var mat: Variant = mi.material_override if mi.material_override else (mi.mesh.surface_get_material(0) if mi.mesh.get_surface_count() > 0 else null)
			var key := "%s|%s|%d|%d|%d|%d" % [host.get_instance_id(), mat.get_instance_id() if mat else 0, roundi(mi.visibility_range_end), roundi(mi.visibility_range_begin), mi.cast_shadow, mi.layers]
			groups[key] = int(groups.get(key, 0)) + 1
		var after := groups.size()
		print("MERGE %-14s %5d meshes -> %5d if merged by host+material+range (saves %d draws, %d mesh surfaces)" % [part, total, after, total - after, total])
	get_tree().quit(0)
