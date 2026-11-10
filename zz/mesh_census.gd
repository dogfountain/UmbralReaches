extends Node
## Biggest visible meshes after world assembly: triangles, LOD levels, visibility range, shadows.
##   godot --headless --path . res://zz/mesh_census.tscn [-- --under=Node] [-- --top=30]
## Prints the heaviest instances (MESH ...), then totals per top-level group and per flora species
## (GROUP ...), what casts shadows, and heavy meshes that have no LODs (NOLOD ...). Full-detail
## triangles: what the GPU would draw if everything were in view at LOD 0 (perf_tour has the real
## per-view numbers).
var f := 0
var top := 16


func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	f += 1
	var root: Node = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	if f < 220 or (not root.has_meta("realm_done")):
		return
	if f > 100000:
		return
	f = 100001
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--under="):
			root = root.get_node(a.trim_prefix("--under="))
		elif a.begins_with("--top="):
			top = int(a.trim_prefix("--top="))
	var rows: Array = []
	var total := 0
	var groups := {}           # group -> [tris, instances(nodes), shadow tris]
	var shadow_total := 0
	var nolod: Array = []
	var mesh_tris := {}
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree(): continue
		var mesh: Mesh = null
		var mult := 1
		if gi is MeshInstance3D: mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
			var mm := (gi as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			mult = mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		if mesh == null: continue
		var tris := 0
		var lods := 0
		if mesh_tris.has(mesh):
			tris = mesh_tris[mesh][0]
			lods = mesh_tris[mesh][1]
		else:
			for s in mesh.get_surface_count():
				var a := mesh.surface_get_arrays(s)
				var idx = a[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				lods = maxi(lods, (RenderingServer.mesh_get_surface(mesh.get_rid(), s).get("lods", []) as Array).size())
			mesh_tris[mesh] = [tris, lods]
		total += tris * mult
		var path := String(root.get_path_to(gi))
		rows.append([tris * mult, path, tris, mult, gi.visibility_range_end, lods, gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF])
		var g := path.get_slice("/", 0)
		if g == "RealmFlora":
			var nm := String(gi.name)
			g = "flora " + (nm.trim_prefix("Flora_").get_slice("_", 0) if nm.begins_with("Flora_") else nm)
		elif g == "Zone":
			g = "Zone/" + path.get_slice("/", 1)
		if not groups.has(g):
			groups[g] = [0, 0, 0]
		groups[g][0] += tris * mult
		groups[g][1] += 1
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			groups[g][2] += tris * mult
			shadow_total += tris * mult
		if lods == 0 and tris >= 2000:
			nolod.append([tris, path, mult])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, top):
		print("MESH %8d tris  %-55s  (%d x%d)  vis_end %.0f  lods %d  shadow %s" % r)
	var gk := groups.keys()
	gk.sort_custom(func(a, b): return groups[a][0] > groups[b][0])
	for k in gk:
		print("GROUP %9d tris  %4d nodes  shadow %9d  %s" % [groups[k][0], groups[k][1], groups[k][2], k])
	nolod.sort_custom(func(a, b): return a[0] > b[0])
	for r in nolod.slice(0, 12):
		print("NOLOD %7d tris  %s  x%d" % r)
	print("MESH total %d tris in %d instances; shadow casters %d tris" % [total, rows.size(), shadow_total])
	get_tree().quit()
