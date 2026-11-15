extends RefCounted
## The West Reach's places (docs/far_reaches.md; realm_pois.gd REACH_POIS): so far the Greyfell's Broken Keep and fell shrine
## (west_reach_greyfell.gd; models tools/blender/reach_west*.py -> art/models/reach_w_*.glb). Reedholm is the towns'
## (reach_towns*.gd). `reserve(root)` before the terrain stamp and the flora, `build(holder)` after. `--no-west-reach` skips it.

const Greyfell := preload("res://core/world/realm/west_reach_greyfell.gd")

static var built: Array[String] = []


static func _off() -> bool:
	return "--no-west-reach" in OS.get_cmdline_user_args()


static func reserve(root: Node) -> void:
	if _off():
		return
	Greyfell.release()
	Greyfell.reserve((root as Node3D).get_world_3d().direct_space_state)


static func build(holder: Node3D) -> void:
	built.clear()
	if _off():
		return
	Greyfell.build(holder, holder.get_world_3d().direct_space_state)
	built.append("greyfell")
	print("REALM_POI west reach built %s" % [built])
