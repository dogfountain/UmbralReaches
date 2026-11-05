extends RefCounted
## RealmRift (docs/REALM_PLAN.md, module "rift"): the Ashen Rift - the lava chasm between the
## village rim and the summit - and THE CROSSING, the only walkable way from the rift's south rim
## (RealmLayout.CROSSING_FOOT) to the summit ward landing (RealmLayout.SUMMIT_WARD).
##   rift/crossing.gd  the ruined viaduct (towers, arcades, fallen column, the Spindle, the landing)
##   rift/features.gd  basalt stacks and organ pipes, crust islands, ash fields, fissures, vents
##   lava_works.gd     the lava itself: surface, bank mask, embers, falls (told where by this module)
## Everything lives under one node with meta "site" (StoneBodies leaves it alone) and registers
## WorldLanes sites / flights / a lane so flora and props keep off the walk.

const Crossing := preload("res://core/world/realm/rift/crossing.gd")
const Features := preload("res://core/world/realm/rift/features.gd")

## Falls poured from the rim walls: [z, side (-1 west wall, +1 east wall)]. LavaWorks finds each
## lip on the real rock along that z (east side only south of the Ossuary).
const FALLS := [[-19.0, -1.0], [-38.0, -1.0], [-60.0, -1.0], [-82.0, -1.0], [-104.0, -1.0], [-16.0, 1.0], [-114.0, 1.0]]


static func build(root: Node) -> void:
	if root.get_node_or_null("RealmRift") != null:
		return
	var host := Node3D.new()
	host.name = "RealmRift"
	host.set_meta("site", "realm_rift")
	root.add_child(host)
	var t0 := Time.get_ticks_msec()
	var crossing := Node3D.new()
	crossing.name = "Crossing"
	host.add_child(crossing)
	var cb = Crossing.new()
	cb.build(root, crossing)
	WorldLanes.register_lane("rift_crossing", cb.lane, Crossing.HW + 0.6)
	WorldLanes.register_lane("rift_crossing_turn", cb.lane_turn, Crossing.HW + 0.6)
	WorldLanes.register_lane("rift_crossing_top", cb.lanes2, Crossing.HW + 0.6)
	var t1 := Time.get_ticks_msec()
	await root.get_tree().physics_frame          # the crossing's collision exists for the features' rays
	var features := Node3D.new()
	features.name = "Features"
	host.add_child(features)
	var fb = Features.new()
	await fb.build(root, features)
	# LavaWorks (attached by main.gd before the Realm builds) waits for this to lay out the lava
	root.set_meta("rift_lava", {"falls": FALLS, "vents": fb.vents})
	print("RIFT crossing %d ms, features %d ms" % [t1 - t0, Time.get_ticks_msec() - t1])
