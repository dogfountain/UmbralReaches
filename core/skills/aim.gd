extends RefCounted
## Aim helpers for the learned spells (r28): where the staff is, where the crosshair looks, the foe
## nearest the crosshair, and the ground under it. Static; preload by path.


static func muzzle(p: Node3D) -> Vector3:
	var rig: Variant = p.get("_visual")
	if rig is Object and (rig as Object).has_method("muzzle"):
		return (rig as Object).call("muzzle")
	return p.global_position + Vector3.UP * 1.5


static func forward(p: Node3D) -> Vector3:
	var cam := p.get_viewport().get_camera_3d() if p.is_inside_tree() else null
	if cam == null:
		return -p.global_basis.z
	return -cam.global_basis.z.normalized()


static func chest(e: Node3D) -> Vector3:
	var h: Variant = e.get("hp_bar_y")
	return e.global_position + Vector3.UP * (float(h) * 0.55 if h != null else 1.0)


static func clear(p: Node3D, a: Vector3, b: Vector3) -> bool:
	var space := p.get_world_3d().direct_space_state
	if space == null:
		return true
	var ex: Array[RID] = []
	if p is CollisionObject3D:
		ex.append((p as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(a, b, Layers.WORLD, ex)
	return space.intersect_ray(q).is_empty()


## The living foe best lined up with the crosshair: within `reach` of the staff and `cone`
## (cosine) of the aim, in clear sight; skips ids in `skip`. null if none.
static func pick(p: Node3D, reach: float, cone: float, skip := {}) -> Node3D:
	var from := muzzle(p)
	var aim := forward(p)
	var best: Node3D = null
	var best_s := -INF
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Node3D
		if e == null or skip.has(e.get_instance_id()) or (e.has_method("is_alive") and not e.call("is_alive")):
			continue
		var c := chest(e)
		var to := c - from
		var d := to.length()
		if d < 0.6 or d > reach:
			continue
		var dt := (to / d).dot(aim)
		if dt < cone:
			continue
		var score := dt * 4.0 - d / reach        # lined up first, then near
		if score > best_s and clear(p, from, c):
			best_s = score
			best = e
	return best


## The nearest living foe to `at` within `r`, skipping ids in `skip`.
static func nearest(tree: SceneTree, at: Vector3, r: float, skip := {}) -> Node3D:
	var best: Node3D = null
	var best_d := r
	for node in tree.get_nodes_in_group(Groups.ENEMY):
		var e := node as Node3D
		if e == null or skip.has(e.get_instance_id()) or (e.has_method("is_alive") and not e.call("is_alive")):
			continue
		var d := e.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = e
	return best


## Where the crosshair meets the ground, no further than `reach` from the wanderer (the ground
## below that point when the look goes past it or into the sky).
static func ground_at_aim(p: Node3D, reach: float) -> Vector3:
	var space := p.get_world_3d().direct_space_state
	var cam := p.get_viewport().get_camera_3d()
	var from := cam.global_position if cam else muzzle(p)
	var dir := forward(p)
	var ex: Array[RID] = []
	if p is CollisionObject3D:
		ex.append((p as CollisionObject3D).get_rid())
	var at := from + dir * (reach + from.distance_to(p.global_position))
	if space:
		var q := PhysicsRayQueryParameters3D.create(from, at, Layers.WORLD | Layers.PROPS, ex)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			at = hit.position
	var flat := Vector3(at.x - p.global_position.x, 0.0, at.z - p.global_position.z)
	if flat.length() > reach:
		flat = flat.normalized() * reach
	# looking into the sky the point can be far overhead: always come down to the ground under it
	var top := minf(maxf(at.y, p.global_position.y) + 4.0, p.global_position.y + 12.0)
	at = Vector3(p.global_position.x + flat.x, top, p.global_position.z + flat.z)
	if space:
		var q2 := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 40.0, Layers.WORLD | Layers.PROPS, ex)
		var hit2 := space.intersect_ray(q2)
		if not hit2.is_empty():
			return hit2.position
	return at
