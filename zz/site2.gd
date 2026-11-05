extends Node
const PROXY := 1 << 19
var f := 0
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(_d: float) -> void:
	f += 1
	if f != 60: return
	var root := get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	var space := (root as Node3D).get_world_3d().direct_space_state
	var tb := root.find_child("TerrainBody", true, false) as CollisionObject3D
	# solid stuff: every visible mesh AABB that is not terrain/grass
	var boxes: Array = []
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		if vi is GPUParticles3D or vi is Light3D or not vi.is_visible_in_tree(): continue
		var n := String(vi.name)
		if n in ["Terrain", "SkyFlare", "Sky"] or vi is MultiMeshInstance3D: continue
		var bb := vi.global_transform * vi.get_aabb()
		if bb.size.x > 60 or bb.size.z > 60: continue   # merged meshes handled by ray test below
		boxes.append([bb, String(vi.get_path()).get_file()])
	print("SITE boxes ", boxes.size())
	var hdr := "     "
	for xx in range(8, 31, 2): hdr += "%6d" % xx
	print("HMAP", hdr)
	for zz in range(22, 38, 2):
		var line := "z%4d" % zz
		for xx in range(8, 31, 2):
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(xx, 70, zz), Vector3(xx, -50, zz), Layers.WORLD))
			line += "%6.1f" % (hit.position.y if hit else -99.0)
		print("HMAP", line)
	get_tree().quit()
