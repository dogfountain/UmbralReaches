extends Node
## Registry of safe light zones (lit braziers, mirrors, the Lantern Ward).
## Static zones are binned into 8 m cells on the ground plane. A query reads only the cells near its
## point, plus the zones registered with `moves` (always scanned). Candidates come back in
## registration order, so the results equal a linear scan of every zone, bit for bit (repel() sums
## its pushes in the same order).
## A static zone's position is read when the index is built (the first query after a register or
## unregister), so a zone must be placed before it is queried and must not move afterwards.
## Measured 2026-11-10 on the built Realm: 9 zones, 216 enemies. Linear scan 1.9-2.5 us per call;
## grid 0.44-0.51 us per call; no result differs from the linear scan on 100,000 random points.
## Revisit if a light zone is ever set to move without `moves`, or the zone count passes ~200.

var _zones: Array = []   # [{node: Node3D, r2: float, r: float, kind: String, drain: float, moves: bool}]
## The same zones as parallel arrays, rebuilt on (un)register: every enemy calls repel() twice and
## is_lit() each physics frame, and the per-zone Dictionary lookups were most of its cost.
var _n: Array = []                       # Node3D (untyped: a freed node must be testable)
var _r := PackedFloat64Array()
var _r2 := PackedFloat64Array()
var _ward := PackedByteArray()           # 1 = kind WARD
var _fire := PackedByteArray()           # 1 = kind FIRE
var _drain := PackedFloat64Array()
var _moves := PackedByteArray()          # 1 = the node moves: never binned, always scanned
## The grid: static zones per 8 m cell, ascending. Rebuilt lazily (see _rebuild).
const CELL := 8.0
const _EDGE := 0.05                      # cell test is padded, so float rounding never drops a zone
var _cells: Dictionary = {}              # Vector2i -> PackedInt32Array of zone indexes
var _moving := PackedInt32Array()        # indexes of the moving zones
var _seen := PackedInt64Array()          # per zone: the query epoch that last listed it
var _epoch := 0
var _dirty := true

## Zone kinds. Only a "fire" (a lit brazier) is a rest: it refills camps, breaks a Gloom tide and
## moves the checkpoint. A "ward" (the Lantern Ward skill) and a "mirror" are light (Gloom drains,
## shades fade, ordinary foes slink) but never a rest. `drain` < 0 means the player's own rate.
const FIRE := "fire"
const WARD := "ward"
const MIRROR := "mirror"


## `moves`: the node changes position after it is registered. Such zones are scanned on every query.
func register(node: Node3D, radius: float, kind: String = FIRE, drain: float = -1.0, moves: bool = false) -> void:
	unregister(node)
	_zones.append({"node": node, "r2": radius * radius, "r": radius, "kind": kind, "drain": drain, "moves": moves})
	_pack()
	if not node.is_in_group(Groups.LIGHT_SOURCE):
		node.add_to_group(Groups.LIGHT_SOURCE)


func unregister(node: Node3D) -> void:
	_zones = _zones.filter(func(z): return z.node != node)
	_pack()


func _pack() -> void:
	var k := _zones.size()
	_n.resize(k)
	_r.resize(k)
	_r2.resize(k)
	_ward.resize(k)
	_fire.resize(k)
	_drain.resize(k)
	_moves.resize(k)
	for i in k:
		var z: Dictionary = _zones[i]
		_n[i] = z.node
		_r[i] = float(z.r)
		_r2[i] = float(z.r2)
		_ward[i] = 1 if z.kind == WARD else 0
		_fire[i] = 1 if z.kind == FIRE else 0
		_drain[i] = float(z.drain)
		_moves[i] = 1 if z.moves else 0
	_dirty = true


## Bins the zones from their live positions. Done on the first query after a change, not in _pack():
## a node's global_position is only valid once it is in the tree, and a zone is often registered
## while it is still being built.
func _rebuild() -> void:
	_cells.clear()
	_moving.clear()
	_seen.resize(_n.size())
	for i in _n.size():
		var o: Variant = _n[i]
		if _moves[i] == 1:
			_moving.append(i)
		elif is_instance_valid(o):
			_bin(i, o as Node3D, _r[i])
	_dirty = false


func _bin(i: int, node: Node3D, r: float) -> void:
	var c := node.global_position
	var reach := r + _EDGE
	for cx in range(floori((c.x - reach) / CELL), floori((c.x + reach) / CELL) + 1):
		for cz in range(floori((c.z - reach) / CELL), floori((c.z + reach) / CELL) + 1):
			# distance from the zone's centre to the cell's nearest point
			var dx := c.x - clampf(c.x, cx * CELL, (cx + 1) * CELL)
			var dz := c.z - clampf(c.z, cz * CELL, (cz + 1) * CELL)
			if dx * dx + dz * dz > reach * reach:
				continue
			var key := Vector2i(cx, cz)
			var list: PackedInt32Array = _cells.get(key, PackedInt32Array())
			list.append(i)
			_cells[key] = list


## The zones that could reach `pos` within `reach` metres: each once, in registration order.
func _gather(pos: Vector3, reach: float) -> PackedInt32Array:
	if _dirty:
		_rebuild()
	_epoch += 1
	var out := PackedInt32Array()
	for cx in range(floori((pos.x - reach) / CELL), floori((pos.x + reach) / CELL) + 1):
		for cz in range(floori((pos.z - reach) / CELL), floori((pos.z + reach) / CELL) + 1):
			var list: Variant = _cells.get(Vector2i(cx, cz))
			if list == null:
				continue
			for i in (list as PackedInt32Array):
				if _seen[i] != _epoch:
					_seen[i] = _epoch
					out.append(i)
	out.append_array(_moving)
	out.sort()
	return out


## `ignore_wards`: bosses and elites (r30) are not held off by the wanderer's own Lantern Ward.
func is_lit(pos: Vector3, ignore_wards := false) -> bool:
	for i in _gather(pos, 0.0):
		if ignore_wards and _ward[i] == 1:
			continue
		var o: Variant = _n[i]
		if is_instance_valid(o) and (o as Node3D).global_position.distance_squared_to(pos) <= _r2[i]:
			return true
	return false


## True only inside a registered fire (a lit brazier): the rest / tide-break test.
func is_fire(pos: Vector3) -> bool:
	for i in _gather(pos, 0.0):
		var o: Variant = _n[i]
		if _fire[i] == 1 and is_instance_valid(o) and (o as Node3D).global_position.distance_squared_to(pos) <= _r2[i]:
			return true
	return false


## The zone at `pos` that drains Gloom fastest: -1.0 = the player's own (fire) rate, a positive
## number = that zone's own rate, 0.0 = not lit at all. A fire always wins over a ward.
func drain_at(pos: Vector3) -> float:
	var best := 0.0
	for i in _gather(pos, 0.0):
		var o: Variant = _n[i]
		if not is_instance_valid(o) or (o as Node3D).global_position.distance_squared_to(pos) > _r2[i]:
			continue
		var d: float = _drain[i]
		if d < 0.0:
			return -1.0
		best = maxf(best, d)
	return best


func clear() -> void:
	_zones.clear()
	_pack()


func count() -> int:
	return _zones.size()


## Horizontal push that keeps `pos` outside every safe-light zone (plus `margin`). ZERO when clear.
## Enemies call this every physics frame: lit braziers and wards are hard sanctuaries.
## A zone reaches `pos` only if its circle comes within `margin` of `pos`, so the cells within
## `margin` of `pos` hold every zone that can push it.
func repel(pos: Vector3, margin: float, ignore_wards := false) -> Vector3:
	var push := Vector3.ZERO
	for i in _gather(pos, maxf(margin, 0.0)):
		var o: Variant = _n[i]
		if not is_instance_valid(o) or ignore_wards and _ward[i] == 1:
			continue
		var c: Vector3 = (o as Node3D).global_position
		var d := Vector3(pos.x - c.x, 0.0, pos.z - c.z)
		var r: float = _r[i] + margin
		var dist := d.length()
		if dist < r:
			var n := d / dist if dist > 0.01 else Vector3.RIGHT
			push += n * (r - dist)
	return push


## `target` moved to the nearest point outside every zone (pounce and hop landings).
func outside(target: Vector3, margin: float, ignore_wards := false) -> Vector3:
	return target + repel(target, margin, ignore_wards)
