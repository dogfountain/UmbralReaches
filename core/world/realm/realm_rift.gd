extends RefCounted
## RealmRift (docs/REALM_PLAN.md, module "rift"): the Ashen Rift - the lava chasm under the summit, where the Stair stood - and THE
## CROSSING, the only walkable way from the rift's south rim (RealmLayout.CROSSING_FOOT) to the summit ward landing
## (RealmLayout.SUMMIT_WARD). The end of the night: it stands at the Realm's far north-east beyond Lastlight (Endgame). Its builders were
## made round the chasm under Hearthward and still build there (the land keeps the chasm at home while they do); Endgame.settle then moves
## the whole of it east and the ground at home is laid again.
## From scratch (21 Nov; rift_from_scratch.md in the docs' round-39 folder): one element, lava, born in the north (the falls off the east wall under the
## summit), molten down the east channel and in the pool under the Ward Crag, crusting over towards the village end.
##   rift/crossing.gd   the Cinder Way, modelled (tools/blender/rift_kit.py): the Lip, the Descent, the Foot, the causeway and its
##                      bridges, the Cinder Isle, the Ward Stair up the crag, the ward landing
##   rift/threshold.gd  the Watchers on their basalt plinths, the Pilgrims' Chapel at the Foot
##   rift/features.gd   the modelled basalt (shores, crust plates, islands, stacks); the rim's ash, fissures and vents
##   lava_works.gd      the lava itself: surface, its cooling, bank mask, embers, falls (told where by this module)
## Everything lives under one node with meta "site" (StoneBodies leaves it alone) and registers WorldLanes sites / flights / lanes so
## flora and props keep off the walk.

const Crossing := preload("res://core/world/realm/rift/crossing.gd")
const Features := preload("res://core/world/realm/rift/features.gd")
const Threshold := preload("res://core/world/realm/rift/threshold.gd")
const HeatHaze := preload("res://core/world/realm/rift/heat_haze.gd")
const Scorch := preload("res://core/world/realm/rift/scorch.gd")

## The lava's cooling (lava.gdshader): fully molten north of HOT_Z, crusted black with thin seams south of COOL_Z (the village end).
const HOT_Z := -46.0
const COOL_Z := -14.0

## Falls poured from the rim walls: [z, side (-1 west wall, +1 east wall)]. LavaWorks finds each lip on the real rock along that z. The
## two off the east wall by the summit are the rift's source; the west ones pour behind the Ward Crag.
const FALLS := [[-70.0, 1.0], [-82.0, -1.0], [-88.0, 1.0], [-104.0, -1.0]]
## Where the lava wells up boiling out of the channel's floor (rift coordinates, on the lava): a churn and spits, no new light.
const BOILS := [Vector3(18.0, -15.5, -78.0), Vector3(12.0, -15.5, -46.5)]


static func build(root: Node) -> void:
	if root.get_node_or_null("RealmRift") != null:
		return
	Scorch.apply_ground(root)                    # the burned land round the lip (RealmLand already took its heights and splat)
	var host := Node3D.new()
	host.name = "RealmRift"
	host.set_meta("site", "realm_rift")
	root.add_child(host)
	var t0 := Time.get_ticks_msec()
	var s0 := WorldLanes.sites.size()            # what it registers moves east with it (Endgame.settle)
	var l0 := WorldLanes.extra_lanes.size()
	var crossing := Node3D.new()
	crossing.name = "Crossing"
	host.add_child(crossing)
	var cb = Crossing.new()
	cb.build(root, crossing)
	WorldLanes.register_lane("rift_crossing", cb.lane, Crossing.HW + 0.6)
	WorldLanes.register_lane("rift_crossing_turn", cb.lane_turn, Crossing.HW + 0.6)
	WorldLanes.register_lane("rift_crossing_top", cb.lanes2, Crossing.HW + 0.6)
	WorldLanes.register_lane("rift_crossing_chapel", cb.lane_chapel, Crossing.HW + 0.6)
	var t1 := Time.get_ticks_msec()
	await root.get_tree().physics_frame          # the way's collision exists for the features' rays
	var features := Node3D.new()
	features.name = "Features"
	host.add_child(features)
	var fb = Features.new()
	fb.watchers = Threshold.WATCHERS
	await fb.build(root, features)
	var threshold := Node3D.new()
	threshold.name = "Threshold"
	host.add_child(threshold)
	await Threshold.new().build(root, threshold)
	HeatHaze.build(host)                         # the shimmer over the pool and the channel
	Endgame.settle(root, s0, l0)                 # built at home: now where the endgame stands
	# LavaWorks (attached by main.gd before the Realm builds) waits for this to lay out the lava
	var boils: Array[Vector3] = []
	for b: Vector3 in BOILS:
		boils.append(b + Endgame.O)
	root.set_meta("rift_lava", {"falls": FALLS, "cool": Vector2(COOL_Z, HOT_Z), "boils": boils, "vents": fb.vents})
	print("RIFT crossing %d ms, features %d ms" % [t1 - t0, Time.get_ticks_msec() - t1])
