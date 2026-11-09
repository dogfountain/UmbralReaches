extends RefCounted
## THE UPWARD FALLS (the Sorrow, above Weirford): where the river climbs.
## Lore: the Order wanted the Sorrow at the abbey, which stood higher than any river runs. Its hydrographers built
## a weir across the valley, drew the water in over seven broad steps and taught it to climb. It climbed for the
## Order as long as the Order's sky held. When the sky began to turn, the river kept the lesson and lost the
## destination: it still goes up the steps, gathers in the scoured bowl on the crest and stands up into the turning
## dark, thinning to spray, and what the dark cannot keep comes back as a fine cold rain on the pool below.
## From the road it is a pale column over the Crowns' foot. Close up it is a hydraulic work: the steps, the crest,
## the south wall with its two sluice bays and the Order's niche between them, the keeper's house on the west
## bank. Jump up the steps, against the water, to the crest and stand in the spray (a secret:
## core/life/secrets/site_upward_falls.gd).
##
## Where: the Sorrow's upper course, x -207, z -18 (the weir), between the drowned shrine (z -40) and the camp
## (z 0), off weir_track (x -188) and the Hierarch's raid (north of z -68). The valley floor is flat there, so nothing
## is stamped: the masonry (art/models/upward_falls.glb, tools/blender/wonder_upward_falls.py) keys into the bed and
## the banks, the water is shader, the drops are particles.
## Collision: the model's own (the body, each step, the wings, the house, the bowl's lip stones).

const Water := preload("res://core/world/realm/wonders/upward_falls/water.gd")
const Kit := preload("res://core/world/realm/r37_west_kit.gd")
const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")
const NAME := "upward_falls"
const CX := -207.0                  ## the river's line at the weir
const ZC := -18.0                   ## the weir's middle
const CREST := 4.8                  ## the crest platform's top (the model's)
const BOWL := Vector3(CX, CREST + 0.14, ZC + 0.1)
const BOWL_R := 2.05
const Y_C := 2.4                    ## the model's frame: the crest's north edge, the south wall, the steps
const Y_S := -2.6
const TREAD := 1.5
const N_STEP := 7
const PROBE_LAYER := 1 << 30

var space: PhysicsDirectSpaceState3D
var report: Array[String] = []
var _cols: Array[AABB] = []
var _temp: Array[Node] = []
var _audit: Array[String] = []
var _last_hit := ""


static func build(root: Node) -> void:
	var w = new()
	await w._run(root)


func _run(root: Node) -> void:
	space = (root as Node3D).get_world_3d().direct_space_state
	var host := Node3D.new()
	host.name = "UpwardFalls"
	host.set_meta("site", NAME)
	root.add_child(host)
	_collect_instances(root)
	_stand_ins(root, host)
	await root.get_tree().physics_frame
	_site()
	_audit_footprint()
	for b in _temp:
		b.queue_free()
	_temp.clear()
	var near := Kit.place(host, "upward_falls.glb", Transform3D(Basis.IDENTITY, Vector3(CX, 0.0, ZC)))
	if near != null:
		near.name = "Weir"
		_dress(near)
		var far_ps := Kit.scene("upward_falls_far.glb")
		if far_ps != null:
			var far_root := far_ps.instantiate() as Node3D
			for mi in far_root.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				if m.mesh != null:
					FarDetail.register(near, m.mesh, Transform3D.IDENTITY, 150.0, Kit.mat("stone"), false)
			far_root.free()
		FarDetail.near_ends(near, 150.0, 30.0)
	else:
		push_error("WONDER upward_falls: the weir model is missing")
	_water(host)
	_marker(host)
	report.append("clearance: %s" % ("nothing touched" if _audit.is_empty() else "; ".join(_audit)))
	for s in report:
		print("WONDER %s %s" % [NAME, s])
	await root.get_tree().physics_frame


## The weir's own stone and timber, a shade lighter and cooler than the shared sets, with a little rim: the night
## grade swallows dressed stone, and this one stands in the water's cold light.
func _dress(near: Node3D) -> void:
	var lit := {}
	for n in near.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			continue
		var key := String(mi.name).get_slice("__", 1).get_slice(".", 0).get_slice("_", 0)
		if not lit.has(key):
			var d := m.duplicate() as StandardMaterial3D
			if key == "stone":
				d.albedo_color = Color(1.25, 1.3, 1.45)
			elif key == "timber":
				d.albedo_color = Color(1.5, 1.5, 1.6)
			d.rim_enabled = true
			d.rim = 0.35
			d.rim_tint = 0.6
			lit[key] = d
		mi.material_override = lit[key]


func _ground(x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


func _site() -> void:
	# nothing is cut from the ground (cut_y far above it): the site keeps the flora and the dress off. The house
	# at the west end, the weir, the pond's steps to the north, the pool to the south.
	WorldLanes.register_site(NAME, Rect2(-216.0, -33.0, 18.0, 12.6), 0.6, 60.0)             # the steps and the cutwaters
	WorldLanes.register_site(NAME + "_weir", Rect2(-226.4, -20.6, 34.8, 8.6), 0.6, 60.0)    # the crest, the wings, the pool's head
	WorldLanes.register_site(NAME + "_house", Rect2(-233.6, -18.4, 7.4, 6.6), 0.6, 60.0)    # the keeper's house
	var who := PackedStringArray()
	for p: Vector2 in [Vector2(-233.0, -14.0), Vector2(-191.0, ZC), Vector2(CX, -32.0), Vector2(CX, -11.0), Vector2(-192.5, -14.0)]:
		who.append("%s path %.1f" % [p, RealmLayout.path_dist(p)])
	report.append("paths: " + "; ".join(who))


# --- the water ----------------------------------------------------------------------------------------

## The river's way up: the pond, seven steps (the model's heights), the crest, the bowl.
func _climb() -> Array:
	var pts: Array = []
	var widths: Array = []
	var tops := []
	for k in N_STEP:
		tops.append(0.95 + (CREST - 0.95) * float(k) / float(N_STEP))
	var raw: Array = [Vector2(Y_C + TREAD * N_STEP + 0.8, 0.65)]
	for k in N_STEP:
		var y1: float = Y_C + TREAD * float(N_STEP - k)
		raw.append(Vector2(y1 - 0.05, float(tops[k]) + 0.08))
		raw.append(Vector2(y1 - TREAD + 0.15, float(tops[k]) + 0.08))
	raw.append(Vector2(Y_C - 0.2, CREST + 0.1))
	raw.append(Vector2(-0.1 + 2.35 * 0.7, CREST + 0.1))
	for i in raw.size():
		var r: Vector2 = raw[i]
		var f := float(i) / float(raw.size() - 1)
		var hw := (5.6 - 3.2 * maxf(0.0, (f - 0.4) / 0.6)) * (1.0 if i > 0 else 0.9)
		pts.append(Vector3(CX, r.y, ZC - r.x))
		widths.append(hw * 2.0)
	return [pts, widths]


func _water(host: Node3D) -> void:
	var cl := _climb()
	Water.channel(host, cl[0], cl[1], BOWL, BOWL_R)
	Water.column(host, BOWL + Vector3.UP * 0.1)
	var south := ZC - Y_S
	Water.pool(host, Vector3(CX + 0.3, 0.66, south + 0.2), Vector2(15.0, 1.6), Vector2(CX, ZC + 11.0), south)
	Water.pool(host, Vector3(CX + 0.3, 0.47, south + 9.0), Vector2(15.0, 17.2), Vector2(CX, ZC + 11.0), south)
	Water.particles(host, BOWL + Vector3.UP * 0.2, Vector3(CX + 2.0, 44.0, ZC + 11.0), Vector3(CX, 0.7, south + 4.0))
	Water.lights(host, Vector3(CX, CREST, ZC + 1.0), Vector3(CX, 0.5, south + 5.0))
	# a pale glow over the place, for the road: the sheet itself is lit by nothing and fades in fog
	var bn: Variant = Wayfinding.beacon(host, Vector3(CX, CREST, ZC), "", Color(0.62, 0.82, 1.0), 90.0, 0.7, 44.0, false, 360.0)
	if bn is Node:
		(bn as Node).name = "Beacon_upward_falls"


func _marker(host: Node3D) -> void:
	var m := Node3D.new()
	m.name = "DeckTop"
	m.set_meta("top", Vector3(CX + 3.7, CREST, ZC + 0.6))         # the crest, east of the bowl: in the spray
	m.set_meta("basin", BOWL)
	m.set_meta("chest", Vector3(CX + 5.4, CREST, ZC + 1.5))
	m.set_meta("plaque", Vector3(CX - 5.4, CREST, ZC + 1.5))
	m.set_meta("stair_foot", Vector3(CX, _ground(CX, ZC - 14.0), ZC - 14.0))     # the foot of the steps, in the pond's shallows
	m.set_meta("deck", CREST)
	host.add_child(m)
	m.global_position = Vector3(CX + 3.7, CREST, ZC + 0.6)


# --- clearance ----------------------------------------------------------------------------------------

func _area() -> AABB:
	return AABB(Vector3(-240.0, -10.0, -40.0), Vector3(56.0, 40.0, 40.0))


func _collect_instances(root: Node) -> void:
	var area := _area()
	for n in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or not mmi.is_visible_in_tree():
			continue
		var mb := mmi.multimesh.mesh.get_aabb()
		if not (mmi.global_transform * mmi.get_aabb()).intersects(area):
			continue
		for i in mmi.multimesh.instance_count:
			var bb: AABB = mmi.global_transform * mmi.multimesh.get_instance_transform(i) * mb
			if bb.intersects(area):
				_cols.append(bb)


func _stand_ins(root: Node, host: Node3D) -> void:
	var area := _area()
	var n_in := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or host.is_ancestor_of(mi):
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if not bb.intersects(area) or bb.size.x * bb.size.z > 6000.0:
			continue
		var path := String(mi.get_path())
		if path.contains("Terrain") or path.contains("Flora") or path.contains("FenWater") or path.contains("Lava"):
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.name = "StandIn"
		body.collision_layer = PROBE_LAYER
		body.collision_mask = 0
		body.set_meta(&"stands_for", path.trim_prefix("/root/Main/"))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		host.add_child(body)
		body.global_transform = mi.global_transform
		_temp.append(body)
		n_in += 1
	report.append("stand-ins: %d meshes, %d instance boxes near" % [n_in, _cols.size()])


## True when a box `size` at `xf` touches nothing built (the ground allowed).
func _clear(xf: Transform3D, size: Vector3, grow := 0.0) -> bool:
	var sh := BoxShape3D.new()
	sh.size = size + Vector3.ONE * grow * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = xf
	q.collision_mask = Layers.WORLD | PROBE_LAYER
	for hit: Dictionary in space.intersect_shape(q, 24):
		var c := hit.get("collider") as Node
		if c != null and String(c.name).begins_with("Terrain"):
			continue
		_last_hit = String(c.get_meta(&"stands_for", c.get_path())) if c else "?"
		return false
	var bb: AABB = xf * AABB(-size * 0.5 - Vector3.ONE * grow, size + Vector3.ONE * grow * 2.0)
	for cb: AABB in _cols:
		if cb.intersects(bb):
			_last_hit = "an instanced piece at %s" % cb.get_center().snapped(Vector3.ONE * 0.1)
			return false
	return true


## The model's masses (its collision boxes) against everything already built, before it is placed.
func _audit_footprint() -> void:
	var pieces := [
		["weir body", Vector3(CX, 2.0, ZC - 1.0), Vector3(14.0, 5.5, 5.2)],
		["steps", Vector3(CX, 1.4, ZC - 8.4), Vector3(14.0, 3.2, 10.8)],
		["west wing", Vector3(CX - 13.0, 1.6, ZC), Vector3(12.0, 4.0, 5.0)],
		["east wing", Vector3(CX + 10.6, 1.4, ZC), Vector3(7.6, 3.6, 5.0)],
		["keeper's house", Vector3(CX - 23.0, 1.4, ZC + 3.4), Vector3(5.4, 3.6, 4.4)],
	]
	for p: Array in pieces:
		if not _clear(Transform3D(Basis.IDENTITY, p[1]), p[2], 0.0):
			_audit.append("%s at %s touches %s" % [p[0], (p[1] as Vector3).snapped(Vector3.ONE * 0.1), _last_hit])
	report.append("audited %d footprints" % pieces.size())
