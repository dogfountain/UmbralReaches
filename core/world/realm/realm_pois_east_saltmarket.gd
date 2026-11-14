extends RefCounted
## Saltmarket at World-of-Warcraft proportions (Luke, 14 Nov; docs/ARCH_REVIEW.md "for the next round" 7): the hamlet's
## houses, drying shed and stall (art/models/r37e_hamlet.glb) at 1.5x about their foot, re-planned inside the same
## ground as the scale pilot did at Weirford: the houses stand round the yard 18 m out, doors on the fire, the Brine
## Road (x 212) through the west of the square. The yard is dressed with modelled props (crates, barrels, sacks, firewood,
## a bench, a trough, a handcart: art/models/props through site_props.gd) at the props' 1.25, and the salt works' pieces
## (carts, a sledge, stacks of cut salt, heaps, a bin, a rack: r37e_works.glb). The plan is Pilot.SM_* (scale_pilot.gd),
## the people's walk nodes (hamlet()) follow the doors. `-- --no-scale-pilot`: the old plan at the old size.
## Built by realm_pois_east_marches.gd (`_saltmarket`, `hamlet`).

const K := preload("res://core/world/realm/east_works_kit.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")
const P := preload("res://core/world/realm/realm_pois.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const SiteProps := preload("res://core/world/realm/site_props.gd")
const OldBoxes := preload("res://core/world/realm/east_marches_boxes.gd")
const HAMLET := "res://art/models/r37e_hamlet.glb"
const W := "res://art/models/r37e_works.glb"
const FIRE := Vector2(218.0, 98.0)
const HOUSE_COL := {"House_A": "HOUSE_A_BOXES", "House_B": "HOUSE_B_BOXES", "House_C": "HOUSE_C_BOXES", "Drying_Shed": "DRYING_SHED_BOXES", "Stall": "STALL_BOXES"}
## Beside each building, in its frame before the scale (x across, z out of the door side): [prop, x, z, yaw]. Houses get the full set.
const AT_DOOR := [["barrel", -1.0, 0.9, 0.0], ["barrel", -1.0, 1.9, 0.9], ["crate", 1.2, 0.7, 0.3], ["sack", 1.8, 1.6, 2.0], ["bench", -2.2, 0.2, 1.57]]
const AT_SIDE := [["firewood", 0.0, 0.2, 1.57], ["crate", 0.2, 1.8, 0.6], ["barrel", 0.3, -1.2, 0.2]]
## Free-standing works' pieces round the yard: [piece, x, z, yaw].
const YARD := [["Salt_Cart", 208.0, 113.5, 1.5], ["Sledge", 231.5, 94.5, 2.4], ["Block_Stack", 203.0, 98.5, 1.57], ["Block_Stack", 241.5, 92.0, 0.0],
	["Salt_Mound", 243.5, 97.0, 0.5], ["Salt_Mound", 201.0, 117.0, 1.3], ["Salt_Bin", 242.0, 116.0, -1.57], ["Drying_Rack", 224.0, 78.0, 0.0]]
static var _tbl_map := {}


static func release() -> void:
	_tbl_map.clear()


## Before the flora: no tree grows in the yard (the oaks beside the houses are twice a house's height now).
static func reserve() -> void:
	var sq := Pilot.sm_square()
	Flora.tree_clear.append([sq[0] as Vector2, float(sq[1]) - 1.0])
	# and none inside or against a house: they stand 4-6 m outside the yard's disc, where a crown twice a house's height
	# came up through a roof or leaned over a door
	for id: String in Pilot.SM_HOUSES:
		var h := Pilot.sm_house(id)
		Flora.tree_clear.append([h.at as Vector2, Vector2(float(h.w), float(h.d)).length() * 0.5 * float(h.s) + 2.5])


static func _g(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


static func _at(space: PhysicsDirectSpaceState3D, p: Vector2) -> Vector3:
	return Vector3(p.x, _g(space, p.x, p.y), p.y)


static func _tbl(nm: String) -> Array:
	if _tbl_map.is_empty():
		_tbl_map = ((preload("res://core/world/realm/east_works_boxes.gd")) as Script).get_script_constant_map()
	return _tbl_map.get(nm, []) as Array


static func build(host: Node3D, space: PhysicsDirectSpaceState3D, c: Vector3) -> void:
	var pk := Pilot.prop()
	var old := (OldBoxes as Script).get_script_constant_map()
	var props := {}                                        # SiteProps file -> [Transform3D]
	var prop_cols: Array = []                              # [Transform3D, size, centre]
	for id: String in Pilot.SM_HOUSES:
		var h := Pilot.sm_house(id)
		var s: float = h.s
		var xf := K.xf(_at(space, h.at), h.yaw, s)
		K.piece(host, HAMLET, id, xf, Vector2(0, 260), true, id in ["House_A", "House_B"])
		K.cols(host, id + "Body", old[HOUSE_COL[id]], [xf])
		var w: float = h.w
		var d: float = h.d
		if id == "Stall":
			P._light(host, xf * Vector3(0, 2.2, 0.4), Color(1.0, 0.62, 0.3), 0.9, 8.0)
			P._lore(host, "r37e_market_board", xf * Vector3(2.0, 1.0, 0.4))
		if id == "House_A" or id == "House_B":
			P._light(host, xf * Vector3(0, 1.9, 3.3), Color(1.0, 0.66, 0.34), 0.7, 6.0)       # the hearth through the window
		if id == "Drying_Shed" or id == "Stall":
			continue
		# the yard against the house: the door's side and the end wall's
		for r: Array in AT_DOOR:
			_prop(space, props, prop_cols, id, float(h.dx) + float(r[1]), d * 0.5 + float(r[2]), float(h.yaw) + float(r[3]), String(r[0]), pk)
		for r: Array in AT_SIDE:
			_prop(space, props, prop_cols, id, w * 0.5 + 1.2 + float(r[1]), float(r[2]), float(h.yaw) + float(r[3]), String(r[0]), pk)
	# a bench by the fire, a trough at the stall, a handcart parked on the road's edge
	_prop_at(space, props, prop_cols, Vector2(FIRE.x + 1.8, FIRE.y + 1.6), 0.4, "bench", pk)
	_prop_at(space, props, prop_cols, Vector2(FIRE.x + 6.2, FIRE.y + 7.0), 1.9, "trough", pk)
	_prop_at(space, props, prop_cols, Vector2(207.4, 108.5), 0.7, "handcart", pk)
	_prop_at(space, props, prop_cols, Vector2(222.5, 86.0), -0.4, "handcart", pk)
	for file: String in props:
		var xfs: Array = props[file]
		for part: Dictionary in SiteProps.parts(file):
			var mmi := OssKit.multimesh(part.mesh, xfs, part.mat, true)
			mmi.name = "Yard_" + file
			mmi.visibility_range_end = 130.0
			host.add_child(mmi)
	var k := OssKit.new()
	k.keep_lanes = false
	for e: Array in prop_cols:
		LK.col_box(k, (e[0] as Transform3D) * (e[2] as Vector3), (e[1] as Vector3) * 0.95, (e[0] as Transform3D).basis.orthonormalized())
	k.commit(host, "YardBody")
	# the salt works' pieces: carts, a sledge, stacks, heaps, a bin, a rack
	var by := {}
	for r: Array in YARD:
		var q := Vector2(float(r[1]), float(r[2]))
		if RealmLayout.path_dist(q) < 3.2:
			continue
		(by.get_or_add(String(r[0]), []) as Array).append(K.xf(_at(space, q), float(r[3])))
	for kind: String in by:
		var ts: Array = by[kind]
		if kind == "Drying_Rack":
			K.multi(host, "Racks", W, kind, ts, 200.0)
		else:
			K.many(host, kind + "s", W, kind, ts, 200.0)
		K.cols(host, kind + "Body", _tbl(kind.to_upper() + "_BOXES"), ts)
	P._lore(host, "r37e_salt_marker", Vector3(c.x + 1.0, _g(space, c.x + 1.0, c.z - 15.0) + 1.0, c.z - 15.0))
	P._lore(host, "r37e_hearth_slate", Vector3(FIRE.x - 2.4, _g(space, FIRE.x - 2.4, FIRE.y) + 0.9, FIRE.y - 1.0))


## One prop in a building's frame (local x across, z out of its door side, in the building's own metres: the yard's stuff
## stands in the scaled house's proportion).
static func _prop(space: PhysicsDirectSpaceState3D, props: Dictionary, cols: Array, id: String, lx: float, lz: float, yaw: float, file: String, pk: float) -> void:
	var q := Pilot.sm_local(id, lx, lz)
	_prop_at(space, props, cols, q, yaw, file, pk)


static func _prop_at(space: PhysicsDirectSpaceState3D, props: Dictionary, cols: Array, q: Vector2, yaw: float, file: String, pk: float) -> void:
	if RealmLayout.path_dist(q) < 1.6:
		return
	var p := _at(space, q)
	var t := K.xf(p, yaw, pk)
	(props.get_or_add(file, []) as Array).append(t)
	if file in ["crate", "barrel", "handcart", "firewood"]:
		var bb := AABB()
		var first := true
		for part: Dictionary in SiteProps.parts(file):
			var a := (part.mesh as Mesh).get_aabb()
			bb = a if first else bb.merge(a)
			first = false
		cols.append([t, bb.size * pk, bb.get_center() * pk])


## Called by village.gd (after the outposts): the hamlet's walking nodes, anchors and edges, so its five people have
## routines round the fire, the stall, the doors and the drying shed. Returns true if laid.
static func hamlet(v: Node3D, space: PhysicsDirectSpaceState3D, node_xz: Dictionary, edges: Array) -> bool:
	var f := FIRE
	var n := {
		"sm_fire": f + Vector2(-1.8, 0.6), "sm_seat": f + Vector2(1.8, 2.4), "sm_stall": Pilot.sm_local("Stall", 1.2, -3.4),
		"sm_stall_w": Pilot.sm_local("Stall", 3.6, -2.2),
		"sm_w1": f + Vector2(-6.5, -5.2), "sm_w2": f + Vector2(0.0, -9.0), "sm_w3": f + Vector2(-6.5, 5.2),
		"sm_door_a": Pilot.sm_door("House_A"), "sm_door_b": Pilot.sm_door("House_B"), "sm_door_c": Pilot.sm_door("House_C"),
		"sm_shed": Pilot.sm_door("Drying_Shed"),
	}
	for k: String in n:
		node_xz[k] = n[k]
	edges.append_array([["sm_fire", "sm_seat"], ["sm_fire", "sm_w1"], ["sm_w1", "sm_w2"], ["sm_w2", "sm_w3"], ["sm_w3", "sm_fire"],
		["sm_fire", "sm_stall_w"], ["sm_w3", "sm_stall_w"], ["sm_stall_w", "sm_stall"], ["sm_stall", "sm_shed"], ["sm_w2", "sm_shed"], ["sm_w1", "sm_door_a"], ["sm_w3", "sm_door_a"],
		["sm_w3", "sm_door_b"], ["sm_fire", "sm_door_b"], ["sm_w2", "sm_door_c"], ["sm_w1", "sm_door_c"], ["sm_seat", "sm_stall_w"]])
	var gy := _g(space, f.x, f.y)
	var anchors: Dictionary = v.get("anchors")
	anchors["@sm_fire"] = Vector3(f.x, gy + 0.9, f.y)
	var st: Vector2 = n.sm_stall
	anchors["@stall"] = Vector3(st.x, _g(space, st.x, st.y) + 1.0, st.y)
	var sd: Vector2 = n.sm_shed
	anchors["@sm_shed"] = Vector3(sd.x, _g(space, sd.x, sd.y) + 1.4, sd.y)
	anchors["@spire"] = Vector3(240.0, 26.0, 8.0)
	anchors["@out_sm"] = Vector3(f.x + 6.0, gy + 1.4, f.y - 12.0)
	var oa: Dictionary = v.get("outpost_at")
	for who: String in ["marl", "ardel"]:
		oa[who] = Vector3(f.x, gy, f.y)
		anchors["@fire_" + who] = Vector3(f.x, gy + 0.2, f.y)
	return true
