extends Node
## Registry of safe light zones (lit braziers, later: banners, spells).
## v0.1 has a handful of zones, so a linear scan is fastest.
## Swap the body of is_lit() for a 4 m spatial hash once zones exceed ~64.

var _zones: Array = []   # [{node: Node3D, r2: float}]


func register(node: Node3D, radius: float) -> void:
	unregister(node)
	_zones.append({"node": node, "r2": radius * radius, "r": radius})
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


## Horizontal push that keeps `pos` outside every safe-light zone (plus `margin`). ZERO when clear.
## Enemies call this every physics frame: lit braziers and wards are hard sanctuaries.
func repel(pos: Vector3, margin: float) -> Vector3:
	var push := Vector3.ZERO
	for z in _zones:
		if not is_instance_valid(z.node):
			continue
		var c: Vector3 = (z.node as Node3D).global_position
		var d := Vector3(pos.x - c.x, 0.0, pos.z - c.z)
		var r: float = float(z.r) + margin
		var dist := d.length()
		if dist < r:
			var n := d / dist if dist > 0.01 else Vector3.RIGHT
			push += n * (r - dist)
	return push


## `target` moved to the nearest point outside every zone (pounce and hop landings).
func outside(target: Vector3, margin: float) -> Vector3:
	return target + repel(target, margin)
