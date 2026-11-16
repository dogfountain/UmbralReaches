extends RefCounted
## RealmRift (docs/REALM_PLAN.md, module "rift"): the Starwater Rift - the chasm between the village rim and the
## summit, where the Stair stood - and THE CROSSING, the only walkable way from the rift's south rim
## (RealmLayout.CROSSING_FOOT) to the summit ward landing (RealmLayout.SUMMIT_WARD). The lava that filled it moved
## out to the Ashen Rift in the far north-east (Luke, 16 Nov: "it makes no sense to be next to the starting village at
## all"; rift/scorch.gd, rift_rim.gd): the chasm holds starwater from the Threshold to the summit's foot.
##   rift/crossing.gd  the ruined viaduct (towers, arcades, fallen column, the Spindle, the landing)
##   rift/features.gd  basalt stacks and organ pipes, rock islands (its fissures, vents and ash went with the lava)
##   lava_works.gd     the sheet itself: surface, bank mask, falls (told where by this module)
## Everything lives under one node with meta "site" (StoneBodies leaves it alone) and registers
## WorldLanes sites / flights / a lane so flora and props keep off the walk.

const Crossing := preload("res://core/world/realm/rift/crossing.gd")
const Features := preload("res://core/world/realm/rift/features.gd")
const Threshold := preload("res://core/world/realm/rift/threshold.gd")
const OssRemains := preload("res://core/world/realm/rift/oss_remains.gd")
const Scorch := preload("res://core/world/realm/rift/scorch.gd")

## The Pilgrims' Threshold (Luke, 9 Nov: "I don't think the lava place should be so close to the village",
## then "make it architectural, explore, make it magical"): south of STAR_Z the rift holds starwater, a
## still pool of violet light, between terraced walls (rift/threshold.gd); the lava starts past the
## third tower, by the Spindle. The lava cools into the starwater over STAR_BAND metres either side.
const STAR_Z := -46.0
const STAR_BAND := 5.0

## The sheet turns to starwater south of this z: north of the summit's foot, so all of it (STAR_Z still bounds the
## Threshold's terraces and the basalt, which stand where they did).
const SHEET_STAR_Z := -400.0
## Falls of light poured from the rim walls: [z, side (-1 west wall, +1 east wall)]. LavaWorks finds each lip on the
## real rock along that z (east side only south of the Ossuary). The first on a terrace bay centre (rift/threshold.gd
## leaves that bay open; none by the Watchers, whose pedestals fill the mouth); two more where lava falls poured.
const STARFALLS := [[-37.0, -1.0], [-82.0, -1.0], [-114.0, 1.0]]


static func build(root: Node) -> void:
	if root.get_node_or_null("RealmRift") != null:
		return
	Scorch.apply_ground(root)                    # the burned land round the lip (RealmLand already took its heights and splat)
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
	fb.star_z = STAR_Z
	fb.volcanic = false                          # (the fissures, vents and ash fields went with the lava)
	await fb.build(root, features)
	var threshold := Node3D.new()
	threshold.name = "Threshold"
	host.add_child(threshold)
	await Threshold.new().build(root, threshold, STAR_Z, STARFALLS)
	var remains := Node3D.new()                  # the piers the Ossuary left on the east wall
	remains.name = "OssRemains"
	host.add_child(remains)
	OssRemains.build(remains)
	var kill := root.get_node_or_null("Zone/Lava/KillVolume")
	if kill is Lava:
		(kill as Lava).star_mode = 1                 # a fall in is a starwater burn (half), the violet burst
	# LavaWorks (attached by main.gd before the Realm builds) waits for this to lay out the sheet
	root.set_meta("rift_lava", {"falls": [], "starfalls": STARFALLS, "star_z": SHEET_STAR_Z, "star_band": STAR_BAND, "vents": fb.vents})
	print("RIFT crossing %d ms, features %d ms" % [t1 - t0, Time.get_ticks_msec() - t1])
