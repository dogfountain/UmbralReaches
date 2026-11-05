class_name StairWorks
extends RefCounted
## The Stair of Ascension as a built processional way: its solid substructure gets stepped
## buttresses every 6 m on both flanks (rising from the lava or the ground), a blind arcade of
## pointed arches between them, and a pinnacle on each buttress standing outside the rail.
## All in the stair's own stone (world-triplanar), measured from its collision so nothing floats.
## The walkway itself is untouched.

const FLANK := 2.78        ## outer face of the substructure (measured)
const STEP := 6.0
const LAVA := -15.5


static func build(root: Node) -> void:
	if root.get_node_or_null("StairWorks") != null:
		return
	var host := Node3D.new()
	host.name = "StairWorks"
	host.set_meta("site", "stair_works")
	root.add_child(host)
	var space := (root as Node3D).get_world_3d().direct_space_state
	var k := OssKit.new()
	k.keep_lanes = false
	var n := 0
	var z := -9.0
	var tops: Array = []
	while z >= -66.0:
		var top := _ray(space, Vector3(0, 60, z), -40.0)
		tops.append([z, top])
		z -= STEP
	for i in tops.size():
		var zz: float = tops[i][0]
		var top: float = tops[i][1]
		if is_nan(top) or (zz < -29.0 and zz > -39.0):
			continue                                     # the landing (and the Ossuary bridge) stay clear
		for s: float in [-1.0, 1.0]:
			var ground := _ray(space, Vector3(s * (FLANK + 0.9), top - 1.2, zz), LAVA - 1.0)
			var base := (LAVA - 0.6) if is_nan(ground) else ground - 0.6
			var cap := top - 0.85
			if cap - base < 1.5:
				continue
			_buttress(k, Vector3(s * FLANK, base, zz), s, cap - base)
			k.pinnacle("hub", Vector3(s * (FLANK + 0.35), top - 0.1, zz), 0.5, 1.25, 0.55)
			n += 1
			# blind arcade to the next buttress down the flight
			if i + 1 < tops.size():
				var z2: float = tops[i + 1][0]
				var top2: float = tops[i + 1][1]
				if is_nan(top2) or (z2 < -29.0 and z2 > -39.0):
					continue
				var zc := (zz + z2) * 0.5
				var tc := minf(top, top2) - 0.95
				var h := minf(6.5, tc - base)
				if h > 3.0:
					k.arch_panel("hub", Vector3(s * (FLANK + 0.13), tc - h, zc), Vector3.FORWARD, STEP - 2.6, h - 2.2, h, 0.26, 0.6, 0.9)
	k.commit(host, "StairWorksBody")
	print("STAIR_WORKS %d buttresses" % n)


static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to_y: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(from.x, to_y, from.z), Layers.WORLD))
	return (hit.position as Vector3).y if hit else NAN


## Three set-back tiers with sloped weatherings, against the substructure face.
static func _buttress(k: OssKit, foot: Vector3, s: float, h: float) -> void:
	var tiers := [[1.6, 1.5, 0.45], [1.15, 1.25, 0.3], [0.75, 1.0, 0.25]]
	var y := foot.y
	for t: Array in tiers:
		var depth: float = t[0]
		var width: float = t[1]
		var part: float = h * float(t[2])
		var c := Vector3(foot.x + s * depth * 0.5, y + part * 0.5, foot.z)
		k.box("hub", c, Vector3(depth, part, width), Basis.IDENTITY, true, 0.95)
		# weathering: a sloped cap shedding outward
		k.box("hub", Vector3(foot.x + s * depth * 0.45, y + part, foot.z), Vector3(depth * 0.95, 0.28, width + 0.08), Basis(Vector3.FORWARD, s * 0.38), false, 0.85)
		y += part
