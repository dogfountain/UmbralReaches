extends Node
## Registry of safe light zones (lit braziers, later: banners, spells).
## v0.1 has a handful of zones, so a linear scan is fastest.
## Swap the body of is_lit() for a 4 m spatial hash once zones exceed ~64.

var _zones: Array = []   # [{node: Node3D, r2: float, r: float, kind: String, drain: float}]

## Zone kinds. Only a "fire" (a lit brazier) is a rest: it refills camps, breaks a Gloom tide and
## moves the checkpoint. A "ward" (the Lantern Ward skill) and a "mirror" are light (Gloom drains,
## shades fade, ordinary foes slink) but never a rest. `drain` < 0 means the player's own rate.
const FIRE := "fire"
const WARD := "ward"
const MIRROR := "mirror"


func register(node: Node3D, radius: float, kind: String = FIRE, drain: float = -1.0) -> void:
	unregister(node)
	_zones.append({"node": node, "r2": radius * radius, "r": radius, "kind": kind, "drain": drain})
	if not node.is_in_group(Groups.LIGHT_SOURCE):
		node.add_to_group(Groups.LIGHT_SOURCE)


func unregister(node: Node3D) -> void:
	_zones = _zones.filter(func(z): return z.node != node)


## `ignore_wards`: bosses and elites (r30) are not held off by the wanderer's own Lantern Ward.
func is_lit(pos: Vector3, ignore_wards := false) -> bool:
	for z in _zones:
		if ignore_wards and z.kind == WARD:
			continue
		if is_instance_valid(z.node) and z.node.global_position.distance_squared_to(pos) <= z.r2:
			return true
	return false


## True only inside a registered fire (a lit brazier): the rest / tide-break test.
func is_fire(pos: Vector3) -> bool:
	for z in _zones:
		if z.kind == FIRE and is_instance_valid(z.node) and z.node.global_position.distance_squared_to(pos) <= z.r2:
			return true
	return false


## The zone at `pos` that drains Gloom fastest: -1.0 = the player's own (fire) rate, a positive
## number = that zone's own rate, 0.0 = not lit at all. A fire always wins over a ward.
func drain_at(pos: Vector3) -> float:
	var best := 0.0
	for z in _zones:
		if not is_instance_valid(z.node) or z.node.global_position.distance_squared_to(pos) > z.r2:
			continue
		var d: float = z.drain
		if d < 0.0:
			return -1.0
		best = maxf(best, d)
	return best


func clear() -> void:
	_zones.clear()


func count() -> int:
	return _zones.size()


## Horizontal push that keeps `pos` outside every safe-light zone (plus `margin`). ZERO when clear.
## Enemies call this every physics frame: lit braziers and wards are hard sanctuaries.
func repel(pos: Vector3, margin: float, ignore_wards := false) -> Vector3:
	var push := Vector3.ZERO
	for z in _zones:
		if not is_instance_valid(z.node) or ignore_wards and z.kind == WARD:
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
func outside(target: Vector3, margin: float, ignore_wards := false) -> Vector3:
	return target + repel(target, margin, ignore_wards)
