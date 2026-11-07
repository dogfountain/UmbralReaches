extends RefCounted
## Ledge finder for the trailer's grab shot: scans the realm's WORLD collision for edges the player's own ledge grab
## accepts (a face 1.6-2.4 m high with a flat top at least 1 m deep, the face straight for 3 m or more, and 4 m of
## level open approach), and lists them with the collider each belongs to so a person can pick the one that sits in a
## real structure. `d` is the director (zz/trailer.gd).

var d
var why := {}


func _no(k: String) -> Dictionary:
	why[k] = int(why.get(k, 0)) + 1
	return {}


func _init(director: Object) -> void:
	d = director


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD))


## Candidates as {pos (ground at the face), dir (toward the wall), rise, len, who}: best per collider, longest first.
func scan(x0: float, x1: float, z0: float, z1: float, step: float) -> Array:
	var space: PhysicsDirectSpaceState3D = (d.main as Node3D).get_world_3d().direct_space_state
	var dirs: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var best := {}
	var gx := x0
	while gx <= x1:
		var gz := z0
		while gz <= z1:
			var g := _ray(space, Vector3(gx, 80.0, gz), Vector3(gx, -30.0, gz))
			if not g.is_empty() and (g.normal as Vector3).y > 0.95:
				var o: Vector3 = g.position
				for dr in dirs:
					var c := _check(space, o, dr)
					if not c.is_empty():
						var key := "%s|%d|%d" % [c.who, int(gx / 12.0), int(gz / 12.0)]
						if not best.has(key) or float(c.len) > float(best[key].len):
							best[key] = c
			gz += step
		gx += step
	var out: Array = best.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.len) > float(b.len))
	return out


func _check(space: PhysicsDirectSpaceState3D, o: Vector3, dr: Vector3) -> Dictionary:
	var hit := _ray(space, o + Vector3.UP * 1.3, o + Vector3.UP * 1.3 + dr * 1.2)
	if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.2 or (hit.normal as Vector3).dot(-dr) < 0.9:
		return _no("r2")
	var face: Vector3 = hit.position
	var over := face + dr * 0.15
	var top := _ray(space, Vector3(over.x, o.y + 3.2, over.z), Vector3(over.x, o.y + 0.9, over.z))
	if top.is_empty() or (top.normal as Vector3).y < 0.85:
		return _no("r3")
	var rise: float = (top.position as Vector3).y - o.y
	if rise < 1.3 or rise > 2.2:
		return _no("r4")
	# the top runs back at least a metre at the same height
	for k: float in [0.45]:
		var deep := _ray(space, Vector3(over.x, o.y + rise + 0.4, over.z) + dr * k, Vector3(over.x, o.y + rise - 0.4, over.z) + dr * k)
		if deep.is_empty() or absf((deep.position as Vector3).y - (o.y + rise)) > 0.2:
			return _no("r5")
	# headroom above the top for the wanderer
	if not _ray(space, Vector3(over.x, o.y + rise + 0.1, over.z) + dr * 0.5, Vector3(over.x, o.y + rise + 2.0, over.z) + dr * 0.5).is_empty():
		return _no("r6")
	# four metres of level ground to run up on
	for k: float in [1.5, 3.0]:
		var p := o - dr * k
		var gg := _ray(space, p + Vector3.UP * 2.0, p + Vector3.DOWN * 2.0)
		if gg.is_empty() or absf((gg.position as Vector3).y - o.y) > 0.6:
			return _no("r7")
		if not _ray(space, p + Vector3.UP * 0.7, p + Vector3.UP * 1.6).is_empty():
			return _no("r8")
	# the face straight for a few metres either side
	var side := dr.cross(Vector3.UP)
	var run := 0.0
	for sgn: float in [1.0, -1.0]:
		var k := 1.0
		while k <= 6.0:
			var q := o + side * sgn * k
			var f2 := _ray(space, q + Vector3.UP * 1.3, q + Vector3.UP * 1.3 + dr * 1.2)
			if f2.is_empty() or absf(((f2.position as Vector3) - face).dot(dr)) > 0.2:
				break
			var t2 := _ray(space, Vector3(q.x, o.y + 3.2, q.z) + dr * 0.15, Vector3(q.x, o.y + 0.9, q.z) + dr * 0.15)
			if t2.is_empty() or absf((t2.position as Vector3).y - (o.y + rise)) > 0.15:
				break
			run += 1.0
			k += 1.0
	if run < 0.0:
		return _no("r9")
	var who := String((hit.collider as Node).get_path()) if hit.collider is Node else "?"
	return {"pos": o, "dir": dr, "rise": rise, "len": run, "who": who}
