extends RefCounted
## (No class_name: const FinalSeat := preload("res://core/world/realm/final_seat.gd").)
## Props that were set down on the ground as it was and then stood on ground the terrain settle moved (TerrainStamp.settle lowers and raises the land under
## the floors by up to a metre): the Keg's barrels hung 0.9 m over the new turf beside it. Run after the settle with the Realm's other floors in: every
## instance of a MultiMesh in group `final_seat` whose first thing below is the terrain (not a floor, a deck, a step: those hold it up) is put on the ground
## as it now is, never moved more than MAX_MOVE, and a prop buried by more than BURIED is raised to a hand under. Build-time only.

const SeatProps := preload("res://core/world/seat_props.gd")
const MAX_MOVE := 1.3
const FLOAT_OVER := 0.07
const BURIED := 0.45

static var last := ""


static func settle(root: Node) -> int:
	var space := (root as Node3D).get_world_3d().direct_space_state
	var moved := 0
	var seen := 0
	for n in root.get_tree().get_nodes_in_group(&"final_seat"):
		var mmi := n as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or not root.is_ancestor_of(mmi) or mmi.multimesh.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		var mm := SeatProps._clone_mm(mmi.multimesh)
		var buf := mm.buffer
		var stride := SeatProps._stride(mm)
		if buf.size() != mm.instance_count * stride:
			continue
		var gx := mmi.global_transform
		var inv := gx.affine_inverse()
		var changed := 0
		for i in mm.instance_count:
			var o := i * stride
			var xf := gx * SeatProps._xf_at(buf, o)
			var p := xf.origin
			seen += 1
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * (MAX_MOVE + 0.3), Layers.WORLD))
			var g := NAN
			if h.is_empty():
				h = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * (MAX_MOVE + 0.2), p + Vector3.UP * 0.6, Layers.WORLD))      # buried: the ground is over it
				if not h.is_empty() and String((h.collider as Node).name).begins_with("Terrain"):
					g = (h.position as Vector3).y
			elif String((h.collider as Node).name).begins_with("Terrain"):
				g = (h.position as Vector3).y
			if is_nan(g):
				continue
			var dy := g - p.y
			var ny := p.y
			if dy < -FLOAT_OVER and dy >= -MAX_MOVE:
				ny = g - 0.02
			elif dy > BURIED and dy <= MAX_MOVE:
				ny = g - 0.1
			if ny != p.y:
				SeatProps._put_xf(buf, o, inv * Transform3D(xf.basis, Vector3(p.x, ny, p.z)))
				changed += 1
		if changed > 0:
			SeatProps._commit(mm, buf)
			mmi.multimesh = mm
			moved += changed
	last = "%d of %d instances put on the settled ground" % [moved, seen]
	print("FINAL_SEAT ", last)
	return moved
