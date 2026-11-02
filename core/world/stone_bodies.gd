extends RefCounted
## Runtime: every stone prop uses the updated stone albedo/normal and blocks the wanderer.
## No rebake. Walkable slabs (path, stair, ramps) already have bodies and stay walkable.

const STONE := "res://art/materials/stone.tres"

const SKIP_MESH := [
	"Terrain", "River", "Water", "Canopy", "Leaves", "Heart", "Glass",
	"Fire", "IronArch", "Flame", "Coals", "Bowl", "Deck", "Boards",
	"Path", "Walk", "Keel", "RampS", "RampN",
	"StoneAbut", "WoodDeck", "WoodRails", "BeamFrame",
]
const SKIP_WALK := ["Stair", "Sanctuary", "Path", "Walk", "RampS", "RampN"]
const SKIP_ANCESTOR := [
	"Player", "Visual", "Lanterns", "DressedLantern",
	"Mirror", "MirrorGate", "Gate", "Portal", "StoneFrame",
	"DressedBridge", "Bridge",
]


static func material_for(_node: Node) -> Material:
	return load(STONE)


static func harden(root: Node) -> void:
	var stone := material_for(root)
	var painted := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if _skip(mi) or not _is_stone(mi):
			continue
		mi.material_override = stone
		_ensure_collision(mi)
		painted += 1
	for node in root.find_children("*", "Node3D", true, false):
		if String(node.name).begins_with("Menhir"):
			_paint_tree(node, stone)
			solidify(node as Node3D)
	if painted > 0:
		print("STONE painted=%d" % painted)


static func solidify(node: Node3D) -> void:
	if node == null or node.has_meta("stone_solid"):
		return
	if _already_solid(node):
		node.set_meta("stone_solid", true)
		return
	var aabb := _local_aabb(node)
	if aabb.size.length() < 0.08:
		return
	var body := StaticBody3D.new()
	body.name = "StoneBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	node.add_child(body)
	var col := CollisionShape3D.new()
	col.name = "Shape"
	var wide := maxf(aabb.size.x, aabb.size.z)
	var tall := aabb.size.y > wide * 1.1
	if tall:
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(wide * 0.46, 0.12)
		cyl.height = maxf(aabb.size.y, 0.4)
		col.shape = cyl
	else:
		var box := BoxShape3D.new()
		box.size = aabb.size
		col.shape = box
	col.position = aabb.get_center()
	body.add_child(col)
	node.set_meta("stone_solid", true)


static func _ensure_collision(mi: MeshInstance3D) -> void:
	if _already_solid(mi):
		return
	var n := String(mi.name)
	if n in SKIP_WALK:
		return
	if not mi.visible or mi.mesh == null or mi.mesh.get_surface_count() < 1:
		return
	if n in ["Ring", "Ruins"]:
		_add_trimesh(mi)
		return
	var aabb := mi.get_aabb()
	if aabb.size.y < 0.35 and not n.begins_with("Pile") and not n.begins_with("Menhir"):
		return
	if aabb.size.y < maxf(aabb.size.x, aabb.size.z) * 0.7 and n in ["Ring", "Ruins"]:
		_add_trimesh(mi)
		return
	solidify(mi)


static func _add_trimesh(mi: MeshInstance3D) -> void:
	if mi.has_meta("stone_solid"):
		return
	var shape := mi.mesh.create_trimesh_shape()
	if shape == null:
		return
	var body := StaticBody3D.new()
	body.name = "StoneBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	mi.add_child(body)
	var col := CollisionShape3D.new()
	col.name = "Shape"
	col.shape = shape
	body.add_child(col)
	mi.set_meta("stone_solid", true)


static func _already_solid(node: Node) -> bool:
	if node.has_meta("stone_solid"):
		return true
	for c in node.get_children():
		if c is StaticBody3D and _enabled_shape(c as StaticBody3D):
			return true
	var p := node.get_parent()
	if p == null:
		return false
	if p is StaticBody3D and _enabled_shape(p as StaticBody3D):
		return true
	var named := p.get_node_or_null(String(node.name) + "Body") as StaticBody3D
	if named != null and _enabled_shape(named):
		return true
	for c in p.get_children():
		if c is StaticBody3D and String(c.name) == "StoneBody" and _enabled_shape(c as StaticBody3D):
			return true
	return false


static func _enabled_shape(body: StaticBody3D) -> bool:
	for s in body.get_children():
		var col := s as CollisionShape3D
		if col != null and not col.disabled and col.shape != null:
			return true
	return false


static func _is_stone(mi: MeshInstance3D) -> bool:
	var n := String(mi.name)
	if n.begins_with("Menhir") or n.begins_with("Pile") or n.begins_with("Stone"):
		return true
	if n in ["Ruins", "Sanctuary", "Stair", "Plinth"]:
		return true
	if n == "Ring":
		var p := mi.get_parent()
		if p != null and String(p.name) == "Shrine":
			return false
		return true
	var mat := mi.material_override
	if mat == null:
		return false
	var path := mat.resource_path
	return path.ends_with("stone.tres") and not path.contains("path")


static func _skip(mi: MeshInstance3D) -> bool:
	if String(mi.name) in SKIP_MESH:
		return true
	var p: Node = mi
	while p:
		if p is CharacterBody3D or String(p.name) in SKIP_ANCESTOR:
			return true
		p = p.get_parent()
	return false


static func _paint_tree(node: Node, stone: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = stone
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var n := String(child.name)
		if n.begins_with("Glass") or n.begins_with("Ember") or n.begins_with("Heart"):
			continue
		(child as MeshInstance3D).material_override = stone


static func _local_aabb(node: Node3D) -> AABB:
	var acc := AABB()
	var started := false
	var list: Array = []
	if node is MeshInstance3D:
		list.append(node)
	list.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for item in list:
		var mi := item as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := node.global_transform.affine_inverse() * mi.global_transform
		var box := xf * mi.get_aabb()
		if not started:
			acc = box
			started = true
		else:
			acc = acc.merge(box)
	return acc
