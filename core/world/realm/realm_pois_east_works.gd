extends RefCounted
## The salt works of the White Pans, composed as a place (docs/ARCH_REVIEW.md "for the next round" 4; Luke, 14 Nov:
## "you should feel very small in it"). Built by realm_pois_east_marches.gd's `_saltworks`, from the modelled pieces of
## art/models/r37e_works.glb (tools/blender/r37_east_works.py, at building scale) and the old hall and derricks (r37e_saltworks.glb)
## scaled up. The plan, from Saltmarket south:
##   the Brine Road     the salt track, straight at x 212, edged in cut-stone kerbs, z 108 to 186: the main axis. It runs
##                      from Saltmarket's square past the works to the Pump Tower, 28 m over the pans at its end.
##   the spine          a trestle flume (3.2 m up: you walk under it) along x 217 from the Pump Tower north to the first
##                      pans and south to the last: the works' plumbing, and a colonnade that leads the eye down the road.
##                      A branch crosses the Road on a 10 m span (the Brine Gantry) to a cistern in the west yard.
##   the pans           two fields (realm_pois_east_marches.gd PAN_FIELDS), each with a stone channel and sluice gates down
##                      the gap between its two rows of pans, fed from the spine.
##   the boiling house  Works_Hall at 1.5x on the east side of the Road, its door on a forecourt of carts, sledges, stacks of
##                      cut salt and heaps the size of a cart-house; chimney 17 m.
##   the west yard      a row of salt sheds (10 x 15 m, a 4.6 m door under a canopy) facing the Road, and long drying racks.
## Skyline: the Pump Tower and the chimney, then the Spire's beacon beyond Saltmarket; rhythm: kerbs, bents, racks, pans.
## Switch: the East Marches switch (all of the East Marches); `--no-scale-pilot` builds the works as it was.

const K := preload("res://core/world/realm/east_works_kit.gd")
const Boxes := preload("res://core/world/realm/east_works_boxes.gd")
const OldBoxes := preload("res://core/world/realm/east_marches_boxes.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")
const P := preload("res://core/world/realm/realm_pois.gd")
const W := "res://art/models/r37e_works.glb"
const H := "res://art/models/r37e_saltworks.glb"

static var _tbl_map := {}
static var _old_map := {}


static func _tbl(nm: String) -> Array:
	if _tbl_map.is_empty():
		_tbl_map = (Boxes as Script).get_script_constant_map()
	return _tbl_map.get(nm, []) as Array


static func _old(nm: String) -> Array:
	if _old_map.is_empty():
		_old_map = (OldBoxes as Script).get_script_constant_map()
	return _old_map.get(nm, []) as Array


static func release() -> void:
	_tbl_map.clear()
	_old_map.clear()


## Footprints kept clear of flora and camps (WorldLanes sites): rect, y floor.
static func reserve(space: PhysicsDirectSpaceState3D) -> void:
	if not Pilot.on():
		return
	var tower := Rect2(Pilot.TOWER.x - 8.0, Pilot.TOWER.y - 8.0, 16.0, 16.0)
	var hall := Rect2(Pilot.WORKS_HALL.x - 8.0, Pilot.WORKS_HALL.y - 12.0, 16.0, 24.0)
	for r: Rect2 in [tower, hall]:
		WorldLanes.register_site("poi_works_%d" % int(r.position.y), r, RealmLayout.ground(space, r.get_center().x, r.get_center().y) + 0.05, 60.0)
	for sh: Vector3 in Pilot.WORKS_SHEDS:
		var rr := Rect2(sh.x - 8.0, sh.y - 6.0, 21.0, 12.0) if sin(sh.z) > 0.0 else Rect2(sh.x - 13.0, sh.y - 6.0, 21.0, 12.0)
		WorldLanes.register_site("poi_shed_%d" % int(sh.y), rr, RealmLayout.ground(space, sh.x, sh.y) + 0.05, 60.0)


static func _g(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


static func _at(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:
	return Vector3(x, _g(space, x, z), z)


## The works. `host` is the Poi node; returns metadata for the caller: {derricks, approach}.
static func build(host: Node3D, space: PhysicsDirectSpaceState3D) -> Dictionary:
	if not Pilot.on():
		return _legacy(host, space)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37501
	var road_x := Pilot.ROAD_X
	var spine_x := Pilot.SPINE_X
	# --- the Brine Road's kerbs: cut stone both sides, open at the forecourt ---
	var kerbs: Array = []
	var z := 108.5
	while z < Pilot.ROAD_Z1:
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and z > Pilot.FORECOURT.x and z < Pilot.FORECOURT.y:
				continue
			kerbs.append(K.xf(_at(space, road_x + side * 2.45, z), PI * 0.5))
		z += 3.0
	K.multi(host, "Kerbs", W, "Kerb_3", kerbs, 200.0)
	# --- the Pump Tower: the skyline, on the Road's axis at its end ---
	var tp := _at(space, Pilot.TOWER.x, Pilot.TOWER.y)
	var tx := K.xf(tp, -PI * 0.5)
	K.piece(host, W, "Pump_Tower", tx, Vector2(0, 330))
	K.cols(host, "TowerBody", _tbl("PUMP_TOWER_BOXES"), [tx])
	FarDetail.register(host, FarDetail.hull(AABB(Vector3(-4.6, 0.0, -4.6), Vector3(9.2, 31.0, 9.2)), 0.45), tx, 300.0, null, false)
	# --- the spine: a trestle flume along x 217, the Gantry across the Road, the west cistern ---
	var flumes: Array = []
	var bents: Array = []
	var gz := Pilot.TOWER.y                                                # the penstock's mouth
	var north := PI * 0.5                                                  # the spine runs along z: turn the pieces' x
	for i in 10:                                                           # north to the first pans' cistern
		flumes.append(K.xf(_at(space, spine_x, gz - 2.5 - 5.0 * i), north))
	for i in 11:
		bents.append(K.xf(_at(space, spine_x, gz - 5.0 * i), north))
	for i in 4:                                                            # south to the last pans'
		flumes.append(K.xf(_at(space, spine_x, gz + 2.5 + 5.0 * i), north))
	for i in 4:
		bents.append(K.xf(_at(space, spine_x, gz + 5.0 + 5.0 * i), north))
	K.piece(host, W, "Flume_10", K.xf(_at(space, spine_x - 5.0, gz), 0.0), Vector2(0, 300))        # the Gantry: 10 m over the Road
	bents.append(K.xf(_at(space, spine_x - 10.0, gz), 0.0))
	flumes.append(K.xf(_at(space, spine_x - 12.5, gz), 0.0))
	bents.append(K.xf(_at(space, spine_x - 15.0, gz), 0.0))
	var cis: Array = [K.xf(_at(space, spine_x - 17.0, gz), 0.0), K.xf(_at(space, spine_x, Pilot.FIELD_A_Z + 1.0), 0.0), K.xf(_at(space, spine_x, Pilot.FIELD_B_Z + 0.9), 0.0)]
	K.many(host, "Flumes", W, "Flume_5", flumes, 300.0)
	K.many(host, "Bents", W, "Flume_Bent", bents, 300.0)
	K.many(host, "Cisterns", W, "Flume_End", cis, 240.0)
	K.cols(host, "FlumeBody", _tbl("FLUME_BENT_BOXES"), bents)
	K.cols(host, "CisternBody", _tbl("FLUME_END_BOXES"), cis)
	# --- the pans' channels and their sluice gates ---
	var chans: Array = []
	var gates: Array = []
	for cz: float in [Pilot.FIELD_A_Z, Pilot.FIELD_B_Z]:
		var x0 := spine_x + 1.9
		for kind: String in ["c", "c", "s", "c", "c", "s"]:
			var len_m := 3.0 if kind == "s" else 6.0
			(gates if kind == "s" else chans).append(K.xf(_at(space, x0 + len_m * 0.5, cz), 0.0))
			x0 += len_m
	K.many(host, "Channels", W, "Channel_6", chans, 220.0)
	K.many(host, "Sluices", W, "Sluice_Gate", gates, 220.0)
	K.cols(host, "SluiceBody", _tbl("SLUICE_BOXES"), gates)
	# --- the boiling house, at building scale, its door on the forecourt ---
	var hk := Pilot.WORKS_HALL_K
	var hx := K.xf(_at(space, Pilot.WORKS_HALL.x, Pilot.WORKS_HALL.y), -PI * 0.5, hk)
	K.piece(host, H, "Works_Hall", hx, Vector2(0, 330))
	K.cols(host, "HallBody", _old("WORKS_HALL_BOXES"), [hx])
	FarDetail.register(host, FarDetail.hull(AABB(Vector3(-8.0, 0.0, -5.0), Vector3(16.0, 11.0, 10.0)), 0.25), hx, 300.0, null, false)
	_smoke(host, hx * Vector3(5.0, 11.4, -1.0))
	P._light(host, hx * Vector3(-3.0, 3.4, 4.6), Color(1.0, 0.6, 0.3), 1.0, 9.0)
	P._lore(host, "r37e_works_ledger", hx * Vector3(1.6, 1.3, 4.0))
	P._lore(host, "r37e_works_gate", hx * Vector3(-5.5, 1.1, 5.2))
	# --- the derricks reach over the pans' near rows ---
	var derricks: Array[Vector3] = []
	var dts: Array = []
	for d: Vector3 in Pilot.DERRICKS:
		var dp := _at(space, d.x, d.y)
		dts.append(K.xf(dp, d.z, Pilot.DERRICK_K))
		derricks.append(dp)
	for t: Transform3D in dts:
		K.piece(host, H, "Derrick", t, Vector2(0, 300))
	K.cols(host, "DerrickBody", _old("DERRICK_BOXES"), dts)
	# --- the forecourt and the yards: carts, sledges, stacks, heaps, bins, racks, sheds ---
	_things(host, space, rng)
	return {"derricks": derricks, "approach": hx * Vector3(-3.0, 0.0, 7.0)}


## Placed things by kind: "kind": [[x, z, yaw], ...] (Pilot.WORKS_PROPS).
static func _things(host: Node3D, space: PhysicsDirectSpaceState3D, rng: RandomNumberGenerator) -> void:
	for sh: Vector3 in Pilot.WORKS_SHEDS:
		var t := K.xf(_at(space, sh.x, sh.y), sh.z)
		K.piece(host, W, "Salt_Shed", t, Vector2(0, 300))
		FarDetail.register(host, FarDetail.hull(AABB(Vector3(-5.5, 0.0, -8.0), Vector3(11.0, 8.6, 16.0)), 0.3), t, 260.0, null, false)
		K.cols(host, "ShedBody", _tbl("SALT_SHED_BOXES"), [t])
	var all := {}
	for kind: String in Pilot.WORKS_PROPS:
		var rows: Array = Pilot.WORKS_PROPS[kind]
		var ts: Array = []
		for r: Vector3 in rows:
			var p := _at(space, r.x, r.y)
			if RealmLayout.path_dist(Vector2(r.x, r.y)) < 3.0:
				continue
			ts.append(K.xf(p, r.z))
		all[kind] = ts
	for kind: String in all:
		var ts: Array = all[kind]
		if kind == "Drying_Rack":
			K.multi(host, "Racks", W, kind, ts, 260.0)
		else:
			K.many(host, kind + "s", W, kind, ts, 200.0)
		K.cols(host, kind + "Body", _tbl(kind.to_upper() + "_BOXES"), ts)


## `-- --no-scale-pilot`: the hall and the three derricks at their old size and places.
static func _legacy(host: Node3D, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var hx := K.xf(_at(space, Pilot.WORKS_HALL_OLD.x, Pilot.WORKS_HALL_OLD.y), -PI * 0.5)
	K.piece(host, H, "Works_Hall", hx, Vector2(0, 260))
	K.cols(host, "HallBody", _old("WORKS_HALL_BOXES"), [hx])
	_smoke(host, hx * Vector3(5.0, 11.4, -1.0))
	P._light(host, hx * Vector3(-3.0, 3.4, 4.6), Color(1.0, 0.6, 0.3), 1.0, 9.0)
	P._lore(host, "r37e_works_ledger", hx * Vector3(1.6, 1.3, 4.0))
	P._lore(host, "r37e_works_gate", hx * Vector3(-5.5, 1.1, 5.2))
	var derricks: Array[Vector3] = []
	var dts: Array = []
	for d: Vector3 in Pilot.DERRICK_OLD:
		var dp := _at(space, d.x, d.y)
		dts.append(K.xf(dp, d.z))
		derricks.append(dp)
		K.piece(host, H, "Derrick", dts[dts.size() - 1], Vector2(0, 250))
	K.cols(host, "DerrickBody", _old("DERRICK_BOXES"), dts)
	return {"derricks": derricks, "approach": _at(space, 228.0, 162.0)}


static func _smoke(host: Node3D, at: Vector3) -> void:
	var smoke := Vfx.emitter(Color(0.55, 0.55, 0.55), {"count": 10, "life": 5.0, "speed": Vector2(0.2, 0.5), "size": 1.4, "gravity": 0.15, "radius": 0.9, "additive": false, "damping": 0.2})
	host.add_child(smoke)
	smoke.global_position = at
	smoke.emitting = true
