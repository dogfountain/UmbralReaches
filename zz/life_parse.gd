extends Node
## Life system: load every script/shader of core/life/wildlife (parse check).
func _ready() -> void:
	for f in DirAccess.get_files_at("res://core/life/wildlife"):
		if f.ends_with(".gd") or f.ends_with(".gdshader"):
			var r := load("res://core/life/wildlife/" + f)
			print("PARSE ", f, " ", "ok" if r != null and (not (r is GDScript) or (r as GDScript).can_instantiate()) else "FAIL")
	for f in ["res://zz/life_test.gd"]:
		var r := load(f) as GDScript
		print("PARSE ", f, " ", "ok" if r != null and r.can_instantiate() else "FAIL")
	const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
	for k in ["deer", "stag", "elk", "fox", "crow", "owl", "heron", "frog", "rat", "bat", "moth", "branch"]:
		var m := LifeKit.mesh(k)
		var tris := 0
		for si in m.get_surface_count():
			tris += (m as ArrayMesh).surface_get_array_index_len(si) / 3
		print("TRIS ", k, " ", tris, " aabb ", m.get_aabb())
	get_tree().quit()
