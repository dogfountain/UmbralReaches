extends RefCounted
## The lore kits' upright barrels as the modelled barrel (art/models/props/barrel.glb), batched into one MultiMesh per part in group final_seat. The kit used to
## merge a barrel into its own mesh where it was set on the build's ground; the terrain settle then lowered the yard behind the Reeds' house by 0.9 m and the barrel
## hung there in the air with its embers (the floating lit barrel by the Almonry). FinalSeat now sets it on the ground the settle leaves. No collider, as the yards'
## barrels have none. Load by path (no class_name).

const GroundSeat := preload("res://core/world/realm/ground_seat.gd")
const SiteProps := preload("res://core/world/realm/site_props.gd")
const RANGE := 70.0


static func seat(xf: Transform3D) -> Transform3D:
	var meshes: Array = []
	for pd: Dictionary in SiteProps.parts("barrel"):
		meshes.append(pd.mesh)
	return GroundSeat.seat_pts(GroundSeat.fast_fn(), GroundSeat.parts_points("lk:barrel", meshes), xf, 0.7)


static func commit(holder: Node3D, xfs: Array[Transform3D]) -> int:
	if xfs.is_empty():
		return 0
	var node := Node3D.new()
	node.name = "Barrels"
	holder.add_child(node)
	var n := 0
	for pd: Dictionary in SiteProps.parts("barrel"):
		var mmi := OssKit.multimesh(pd.mesh as Mesh, xfs, pd.mat as Material, true)
		mmi.name = "Barrel_%d" % n
		mmi.add_to_group(&"final_seat")
		mmi.visibility_range_end = RANGE
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.set_meta("site_owned", true)
		node.add_child(mmi)
		n += 1
	xfs.clear()
	return n
