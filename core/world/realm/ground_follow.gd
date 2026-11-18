extends RefCounted
## (No class_name: const GroundFollow := preload("res://core/world/realm/ground_follow.gd").)
## Chests stand on what is under them. A chest is set down at a height worked out before the place it stands in has
## its colliders and before the ground settles under the floors (TerrainStamp.settle): for some the figure was a
## guess (the Drowned Shrine's chest hung 1.4 m over its paving, the Well's 0.3 m over its landing), for others it
## went stale (the ground dropped a hand under a chest beside a house). Run after the settle pass, when every floor
## is in the physics world: each chest is lowered onto the walk surface under it. Only ever lowers, and never
## further than REACH (a surface further down is not its floor).

const VillageNav := preload("res://core/life/village/village_nav.gd")

const REACH := 2.5
const GAP := 0.03


static func settle(root: Node) -> int:
	var space := (root as Node3D).get_world_3d().direct_space_state
	var moved := 0
	var said := PackedStringArray()
	for n in root.get_tree().get_nodes_in_group(&"loot_chest"):
		var c := n as Node3D
		if c == null or not root.is_ancestor_of(c):
			continue
		var p := c.global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.35, p + Vector3.DOWN * REACH, Layers.WORLD))
		if hit.is_empty():
			continue
		var drop := p.y - (hit.position as Vector3).y
		if drop > GAP:
			c.global_position = Vector3(p.x, (hit.position as Vector3).y, p.z)
			moved += 1
			said.append("%s %.2f at (%.1f, %.1f, %.1f)" % [String(c.name).trim_prefix("Chest_"), drop, p.x, p.y - drop, p.z])
	if moved > 0:
		print("GROUND_FOLLOW %d chests lowered onto their floors (m): %s" % [moved, ", ".join(said)])
	# the village's people were set on their spots before the settle too: one who stands all night (Isolde at the
	# Lanthorn tower) kept the old ground's height, 0.8 m over the settled turf. A walker reads the floor each step.
	var village := root.get_node_or_null("Village")
	var nav: Variant = village.get("nav") if village != null else null
	if nav is VillageNav:
		var nodes_moved := (nav as VillageNav).resettle()
		if not nodes_moved.is_empty():
			print("GROUND_FOLLOW %d village spots re-floored (m): %s" % [nodes_moved.size(), ", ".join(nodes_moved)])
	var folk := PackedStringArray()
	for n in root.get_tree().get_nodes_in_group(&"villager"):
		var v := n as Node3D
		if v == null or not root.is_ancestor_of(v):
			continue
		var q := PhysicsRayQueryParameters3D.create(v.global_position + Vector3.UP * 0.35, v.global_position + Vector3.DOWN * REACH, Layers.WORLD)
		var b: Variant = v.get("body")
		if b is CollisionObject3D:
			q.exclude = [(b as CollisionObject3D).get_rid()]
		var vh := space.intersect_ray(q)
		if not vh.is_empty() and v.global_position.y - (vh.position as Vector3).y > 0.1:
			folk.append("%s %.2f" % [String(v.name), v.global_position.y - (vh.position as Vector3).y])
			v.global_position.y = (vh.position as Vector3).y
	if not folk.is_empty():
		print("GROUND_FOLLOW %d villagers set down on the settled ground (m): %s" % [folk.size(), ", ".join(folk)])
	return moved
