class_name StoneBodies
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


static func _skip(mi: MeshInstance3D) -> bool:
	if String(mi.name) in SKIP_MESH:
		return true
	var p: Node = mi
	while p:
		if p is CharacterBody3D or String(p.name) in SKIP_ANCESTOR or p.has_meta("site"):
			return true                          # registered builders bring their own collision
		p = p.get_parent()
	return false


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
