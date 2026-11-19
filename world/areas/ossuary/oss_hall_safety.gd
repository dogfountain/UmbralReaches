extends RefCounted
## The pit hall's safety nets (oss_hall.gd; the map audit's MA1, found with zz/visual_probe.tscn: 19 Nov, the visual pass).
## No class_name: oss_hall.gd loads it by path.
##   apse_solids  each chapel's floor and walls again as convex boxes: in the apses' corners the kit's two-sided faces let a
##                walking body sink through the floor and fall out under the hall (the walk at 311 deg fell at 42.9 m, from
##                rest too); a convex box always pushes a body back out
##   catch_under  a band under the whole hall's footprint, from just under the floor to the bottom of the hall's box: under
##                the fighting floor is never a place to be, so a body that gets there is sent back up as the deep does


## `boxes`: [centre, basis, size] (the hall's local frame) for each piece.
static func apse_solids(hall: Node3D, boxes: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "ApseSolids"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	for b: Array in boxes:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = b[2] as Vector3
		cs.shape = bx
		cs.transform = Transform3D(b[1] as Basis, b[0] as Vector3)
		body.add_child(cs)
	hall.add_child(body)


## The band under `box` (the hall's volume, local) from `top` down to 30 m under the box; `entered` gets the player's body.
static func catch_under(hall: Node3D, c: Vector3, box: AABB, top: float, entered: Callable) -> void:
	var ar := Area3D.new()
	ar.name = "UnderCatch"
	ar.collision_layer = 0
	ar.collision_mask = Layers.PLAYER
	ar.monitorable = false
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	var bottom := box.position.y - 30.0
	bx.size = Vector3(box.size.x + 6.0, top - bottom, box.size.z + 6.0)
	cs.shape = bx
	ar.add_child(cs)
	hall.add_child(ar)
	ar.position = Vector3(c.x, (top + bottom) * 0.5, c.z)
	ar.body_entered.connect(entered)
