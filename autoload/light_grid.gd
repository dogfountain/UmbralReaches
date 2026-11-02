extends Node
## Registry of safe light zones (lit braziers, later: banners, spells).
## v0.1 has a handful of zones, so a linear scan is fastest.
## Swap the body of is_lit() for a 4 m spatial hash once zones exceed ~64.

var _zones: Array = []   # [{node: Node3D, r2: float}]


func register(node: Node3D, radius: float) -> void:
	unregister(node)
	_zones.append({"node": node, "r2": radius * radius})
	if not node.is_in_group(Groups.LIGHT_SOURCE):
		node.add_to_group(Groups.LIGHT_SOURCE)


func unregister(node: Node3D) -> void:
	_zones = _zones.filter(func(z): return z.node != node)


func is_lit(pos: Vector3) -> bool:
	for z in _zones:
		if is_instance_valid(z.node) and z.node.global_position.distance_squared_to(pos) <= z.r2:
			return true
	return false


func clear() -> void:
	_zones.clear()


func count() -> int:
	return _zones.size()
