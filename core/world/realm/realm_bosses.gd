extends RefCounted
## Realm module "bosses" (docs/REALM_PLAN.md): the progression rebuilt into the new layout.
##   - Thorn Henge on its hill at RealmLayout.HENGE_C, its pilgrim stair from west_way's end
##   - the Ossuary's fen door at RealmLayout.OSSUARY_GATE: its cut is registered here (before the
##     terrain stamp); the door and the stair up into the niche gallery are built by the Ossuary
##     itself (world/areas/ossuary/ossuary.gd `_fen_gate`), which is streamed
##   - the four checkpoint braziers (not the spawn one) moved onto the new map
##   - camps: EnemySpawner.seed_realm (world/main.gd), planted once the Realm is built
## The summit ward stays where SummitDress makes it (RealmLayout.SUMMIT_WARD, the Crossing's head).

## Checkpoint braziers: Zone/Braziers/<name> (kindle memory is by node name, so names are kept).
## [xz, the point the fire faces (the respawn spot is 1.8 m that way)]
const BRAZIERS := {
	"StairFoot": [Vector2(-5.0, -2.0), Vector2(0.0, -2.0)],        # the Crossing's foot, by rift_rim
	"Shrine": [Vector2(-31.0, 4.0), Vector2(-36.0, 8.6)],          # the Glimmer Glade, beside west_way
	"Landing": [Vector2(84.0, -36.0), Vector2(78.0, -40.0)],       # the Barrow Field, where fen_descent starts
	"Threshold": [Vector2(47.0, -55.0), Vector2(45.0, -60.5)],     # on the fen below the Ossuary's fen door, off fen_descent
}


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	ThornHenge.use_realm()
	ThornHenge.build(root)
	_braziers(root)
	_ossuary_cut(root)
	# r30: the watchtower's ground (RealmWayfinding builds it after the flora; reserved now so the
	# stamp levels it and nothing grows there)
	(load("res://core/world/realm/realm_wayfinding.gd") as GDScript).call("reserve_tower", root)
	# r31: the places worth leaving the road for (realm_pois.gd) reserve their ground the same way
	(load("res://core/world/realm/realm_pois.gd") as GDScript).call("reserve", root)
	root.set_meta("realm_bosses_done", true)
	_reseat_braziers_later(root)            # not awaited: runs on after the stamp and flora
	print("REALM bosses: henge at %s, braziers %s, fen gate cut to x %.1f (%d ms)" % [
		ThornHenge.C, BRAZIERS.keys(), Ossuary.fen_out, Time.get_ticks_msec() - t0])


## Ground under xz: the median of five rays (the terrain, or the macro shape before it exists).
static func _ground(space: PhysicsDirectSpaceState3D, p: Vector2, r := 0.6) -> float:
	var hs: Array[float] = []
	for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		hs.append(RealmLayout.ground(space, p.x + o.x, p.y + o.y))
	hs.sort()
	return hs[2]


static func _braziers(root: Node) -> void:
	var space := (root as Node3D).get_world_3d().direct_space_state
	for n: String in BRAZIERS:
		var b := root.get_node_or_null("Zone/Braziers/" + n) as Node3D
		if b == null:
			push_warning("RealmBosses: no brazier " + n)
			continue
		var at: Vector2 = BRAZIERS[n][0]
		var face: Vector2 = BRAZIERS[n][1]
		var g := _ground(space, at)
		b.global_position = Vector3(at.x, g - 0.12, at.y)            # set into the ground like SeatProps.plant_solid
		var d := face - at
		b.global_rotation = Vector3(0.0, atan2(d.x, d.y), 0.0)        # local +z (the respawn side) towards `face`
		b.set_meta("site", "brazier_" + n.to_lower())                 # the pad below is its own
		# a small pad: the stamp shaves bumps off it, flora and lore keep their things out of the fire
		WorldLanes.register_site("brazier_" + n.to_lower(), Rect2(at - Vector2(1.4, 1.4), Vector2(2.8, 2.8)), g, g - 0.02)


## After the terrain stamp and the flora (SummitDress runs after both), stand each fire on the
## ground again: a stamp nearby may have moved it.
static func _reseat_braziers_later(root: Node) -> void:
	var tree := root.get_tree()
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(root) and not root.has_meta("summit_dressed") and Time.get_ticks_msec() - t0 < 120000:
		await tree.process_frame
	if not is_instance_valid(root):
		return
	await tree.physics_frame
	var space := (root as Node3D).get_world_3d().direct_space_state
	for n: String in BRAZIERS:
		var b := root.get_node_or_null("Zone/Braziers/" + n) as Node3D
		if b:
			var at: Vector2 = BRAZIERS[n][0]
			b.global_position.y = _ground(space, at) - 0.12


## The Ossuary's fen door: the stair inside the cliff is cut out of the ground now (hard cuts, no
## falloff, the Ossuary's retaining walls line them) so the stamp knows before it runs. The cut runs
## east past the door until it meets ground no higher than the threshold.
static func _ossuary_cut(root: Node) -> void:
	var space := (root as Node3D).get_world_3d().direct_space_state
	var gy := Ossuary.FEN_GATE.y
	var x := Ossuary.FEN_FACADE_X + 2.0
	while x < Ossuary.FEN_FACADE_X + 9.0 and _ground(space, Vector2(x, Ossuary.FEN_GATE.z), 0.8) > gy + 0.35:
		x += 1.0
	Ossuary.fen_out = x
	for r: Array in Ossuary.fen_cuts():
		WorldLanes.register_site(String(r[0]), r[1] as Rect2, float(r[2]), float(r[2]) - 0.1, true)
	var lo := Vector3(Ossuary.FEN_X, gy, Ossuary.FEN_FOOT_Z)
	var hi := Vector3(Ossuary.FEN_X, Ossuary.GAL_Y, Ossuary.FEN_HEAD_Z)
	WorldLanes.register_flight("oss_fen_stair", lo, hi, Ossuary.FEN_W * 0.5)
	WorldLanes.register_portal("oss_fen_gate", Vector3(Ossuary.FEN_FACADE_X + 0.45, Ossuary.FEN_GATE.y, Ossuary.FEN_GATE.z), Vector3.RIGHT, 1.8, 2.8)
	WorldLanes.register_portal("oss_fen_door", Vector3(27.35, Ossuary.GAL_Y, Ossuary.FEN_DOOR_Z), Vector3.RIGHT, 1.6, 2.6)
	WorldLanes.register_lane("oss_fen_way", [Vector2(Ossuary.fen_out, Ossuary.FEN_GATE.z), Vector2(Ossuary.FEN_X, Ossuary.FEN_GATE.z),
		Vector2(Ossuary.FEN_X, Ossuary.FEN_DOOR_Z), Vector2(26.0, Ossuary.FEN_DOOR_Z)], 1.2)
