extends RefCounted
## (No class_name: const GroundFollow := preload("res://core/world/realm/ground_follow.gd").)
## Chests stand on what is under them. A chest is set down at a height worked out before the place it stands in has
## its colliders and before the ground settles under the floors (TerrainStamp.settle): for some the figure was a
## guess (the Drowned Shrine's chest hung 1.4 m over its paving, the Well's 0.3 m over its landing), for others it
## went stale (the ground dropped a hand under a chest beside a house). Run after the settle pass, when every floor
## is in the physics world: each chest is lowered onto the walk surface under it. Only ever lowers, and never
## further than REACH (a surface further down is not its floor).

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
	return moved
