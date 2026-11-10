extends SceneTree
## Dump baked night meshes to the Unreal sibling project as GLB.
## Does not save main.tscn.

const OUT := "/Users/luke/UmbralReachesUE/Content/Imported/"
const NAMES := [
	"Terrain", "TerrainHeart", "River", "Stair", "Sanctuary", "Ruins",
	"GiantTrunks", "Canopy", "DeadTrees", "Boulders", "Path", "Dock",
	"EmberCrystals", "RiftCrystals"
]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for scene in ["res://world/main.tscn"]:
		var packed := load(scene) as PackedScene
		if packed == null:
			push_error("export_unreal_meshes missing %s" % scene)
			continue
		var root := packed.instantiate()
		root.name = scene.get_file().get_basename()
		get_root().add_child(root)
		_dump_node(root, scene.get_file().get_basename())
		root.queue_free()
	print("UNREAL MESH DUMP done -> ", OUT)
	quit()


func _dump_node(node: Node, prefix: String) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var n := String(mi.name)
		var keep := false
		for key in NAMES:
			if n == key or n.begins_with(key):
				keep = true
				break
		if keep and mi.mesh:
			var path := OUT + prefix + "_" + n.validate_filename() + ".glb"
			var err := _write_glb(mi, path)
			print("DUMP ", path, " err=", err)
	for child in node.get_children():
		_dump_node(child, prefix)


func _write_glb(mi: MeshInstance3D, path: String) -> Error:
	var gstate := GLTFState.new()
	var doc := GLTFDocument.new()
	var tmp := MeshInstance3D.new()
	tmp.mesh = mi.mesh
	tmp.name = mi.name
	var holder := Node3D.new()
	holder.add_child(tmp)
	tmp.owner = holder
	var err := doc.append_from_scene(holder, gstate)
	if err == OK:
		err = doc.write_to_filesystem(gstate, path)
	holder.queue_free()
	return err
