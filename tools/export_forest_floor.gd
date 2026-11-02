extends SceneTree
## Dump ForestFloor MultiMesh instance transforms. Does not save or rebake scenes.

const OUT := "/Users/luke/UmbralReachesUE/Content/Imported/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for scene in ["res://world/main.tscn"]:
		var packed := load(scene) as PackedScene
		if packed == null:
			push_error("export_forest_floor missing %s" % scene)
			continue
		var root := packed.instantiate()
		get_root().add_child(root)
		_dump(root, scene.get_file().get_basename())
		root.queue_free()
	print("FOREST FLOOR DUMP done -> ", OUT)
	quit()


func _dump(root: Node, prefix: String) -> void:
	var path := OUT + prefix + "_ForestFloor.bin"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % path)
		return
	f.store_buffer("UMFF".to_utf8_buffer())
	f.store_32(1)
	var count_at := f.get_position()
	f.store_32(0)
	var n := 0
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var kind := _kind(String(mmi.name))
		if kind < 0:
			continue
		var mm := mmi.multimesh
		if mm == null:
			continue
		var parent := mmi.global_transform
		for i in mm.instance_count:
			var xf: Transform3D = parent * mm.get_instance_transform(i)
			var sc := xf.basis.get_scale()
			f.store_8(kind)
			f.store_float(xf.origin.x)
			f.store_float(xf.origin.y)
			f.store_float(xf.origin.z)
			f.store_float(sc.x)
			f.store_float(sc.y)
			f.store_float(sc.z)
			f.store_float(xf.basis.get_euler().y)
			n += 1
	var end := f.get_position()
	f.seek(count_at)
	f.store_32(n)
	f.seek(end)
	f.close()
	print("FOREST ", prefix, " instances=", n)


func _kind(name: String) -> int:
	var n := name.to_lower()
	if n.begins_with("grass"):
		return 0
	if n.begins_with("fern"):
		return 1
	if n.begins_with("cap") or n.begins_with("glow") or n.begins_with("night"):
		return 2
	if n.begins_with("spore"):
		return 3
	return -1
