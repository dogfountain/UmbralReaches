extends RefCounted
## Realm module "bosses" (docs/REALM_PLAN.md): the progression rebuilt into the new layout.
##   - Thorn Henge on its hill at RealmLayout.HENGE_C, its pilgrim stair from west_way's end
##   - the Ossuary's fen door at RealmLayout.OSSUARY_GATE: its cut is registered here (before the
##     terrain stamp); the door and the stair up into the niche gallery are built by the Ossuary
##     itself (world/areas/ossuary/ossuary.gd `_fen_gate`), which is streamed
##   - the four checkpoint braziers (not the spawn one) moved onto the new map
##   - camps: EnemySpawner.seed_realm (world/main.gd), planted once the Realm is built
## The summit ward stays where SummitDress makes it (RealmLayout.SUMMIT_WARD, the Crossing's head).

const ScalePilot := preload("res://core/world/realm/scale_pilot.gd")

## Checkpoint braziers: Zone/Braziers/<name> (kindle memory is by node name, so names are kept).
## [xz, the point the fire faces (the respawn spot is 1.8 m that way)]
const BRAZIERS := {
	"StairFoot": [Vector2(-5.0, -2.0), Vector2(0.0, -2.0)],        # the Crossing's foot, by rift_rim
	"Shrine": [Vector2(-31.0, 4.0), Vector2(-36.0, 8.6)],          # the Glimmer Glade, beside west_way
	"Landing": [Vector2(84.0, -36.0), Vector2(78.0, -40.0)],       # the Barrow Field, where fen_descent starts
	"Threshold": [Vector2(50.6, -57.5), Vector2(55.6, -56.6)],     # on the fen below the Ossuary's fen door, off fen_descent (r34: was (47, -55), half a metre off the Lay Brothers' Stair's foot: the climb glanced off it; it faces east so the ember post stands south of the brazier, off the path)
}
## r34 places (docs/r34/places.md): one fire for each new region (RealmLayout.SLOTS "fire"), so the
## Ember Road and the checkpoints keep the same spacing over the doubled ground. Copies of a valley
## fire, made unlit under Zone/Braziers (kindle memory is by name; restored here, as the scene's own
## restore ran before these existed). Their names on the Road and the map come from the region.
## Camps keep 13 m off them (the enemies pass). [xz, the point the fire faces]
const R34_FIRES := {
	"QuarryFire": [Vector2(-120.0, -83.0), Vector2(-126.0, -84.0)],     # the quarry's mouth, beside west_track's end
	"HoldsFire": [Vector2(-138.0, 15.5), Vector2(-133.0, 15.0)],        # the Rooted Holds, west of west_track (the holds stand east of it)
	"FoundryFire": [Vector2(123.0, -76.0), Vector2(128.0, -74.0)],      # moor_track's end, under the first slag heap
	"MoorFire": [Vector2(126.0, -8.0), Vector2(132.0, -9.0)],           # beside moor_track, under the tor
	"OrchardFire": [Vector2(-99.0, 104.0), Vector2(-106.0, 104.0)],     # beside orchard_lane
	"FieldFire": [Vector2(8.0, 108.0), Vector2(1.0, 110.0)],            # the Waiting Field's gate, off necropolis_way
	"MereFire": [Vector2(103.0, 98.0), Vector2(98.0, 96.0)],            # the mere's north bank, by mere_causeway
	# --- south marches ---
	"OakFire": [Vector2(-44.0, 196.4), Vector2(-52.0, 199.0)],          # beside downs_track (4 m south of its bend: at z 192 the track ran through the fire), in the Grandmother Oak's shade (the door looks this way)
	"WellFire": [Vector2(44.0, 196.4), Vector2(52.0, 199.0)],           # beside downs_track (4 m south of its bend), on the way to the Well's rim and the descent gate
	# --- west marches ---
	"WeirfordFire": [Vector2(-196.0, 74.0), Vector2(-199.0, 77.0)],     # the town square, east of the bridge
	"SorrowFire": [Vector2(-190.0, -20.0), Vector2(-196.0, -22.0)],     # a ford on weir_track
	"HierarchFire": [Vector2(-193.0, -80.0), Vector2(-203.0, -80.0)],   # where weir_track reaches the valley (4 m off the line, where it meets crowns_west)
	"SiegeFire": [Vector2(-219.0, 127.0), Vector2(-224.0, 131.0)],      # beside siege_track at the outer earthwork (5 m off the line)
	# --- the east marches ---
	"StillwaterFire": [Vector2(220.0, 52.0), Vector2(214.0, 40.0)],    # the lake's south shore, off spire_track
	"AnchorFire": [Vector2(209.0, -83.0), Vector2(206.0, -100.0)],     # the foot of the cliff, beside the bend of anchor_track (it stood on the track itself)
	"SaltFire": [Vector2(218.0, 98.0), Vector2(214.0, 96.0)],          # Saltmarket's yard
}


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	ThornHenge.use_realm()
	ThornHenge.build(root)
	_reserve_raids()
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


## r34 layout: the raid floors (RealmLayout.RAIDS) as sites, registered before the stamp, lore and flora
## so nothing is planted on them: the henge's a level terrace (cut and fill to its y), the summit's a
## cut-only round zone (its deck is built over the chasm). The boss agents build inside them.
static func _reserve_raids() -> void:
	for r: Dictionary in RealmLayout.RAIDS:
		var n := "raid_" + String(r.id)
		if String(r.mode) == "level":
			WorldLanes.register_terrace(n, r.c, float(r.r), float(r.y))
		else:
			# the summit's own monument (SummitDress) and the Ossuary's lift tower already stand in it
			WorldLanes.register_zone(n, r.c, float(r.r), float(r.y), float(r.y) - 0.8, ["SummitAltar", "Area_ossuary"])


## r34 places: every placed fire's name (the valley's four, then the new regions' seven).
static func fire_names() -> Array[String]:
	var out: Array[String] = []
	for n: String in BRAZIERS:
		out.append(n)
	for n: String in R34_FIRES:
		out.append(n)
	return out


static func _fire(n: String) -> Array:
	var f: Array = BRAZIERS[n] if BRAZIERS.has(n) else R34_FIRES[n]
	return [ScalePilot.xz(f[0]), ScalePilot.xz(f[1])]            # Weirford's fire moves with its square (scale_pilot.gd)


## r34 places: the new regions' fires, copied from a valley fire and left cold (kindles restored).
static func _r34_fires(root: Node) -> void:
	var holder := root.get_node_or_null("Zone/Braziers")
	var src := root.get_node_or_null("Zone/Braziers/StairFoot") as Brazier
	if holder == null or src == null:
		return
	for n: String in R34_FIRES:
		if holder.get_node_or_null(n) != null:
			continue
		var b := src.duplicate() as Brazier
		b.name = n
		b.start_lit = false
		holder.add_child(b)
		if b.lit:
			b._set_lit(false, false)
		if Travel.was_lit(n):
			b.kindle_quiet()


## Ground under xz: the median of five rays (the terrain, or the macro shape before it exists).
static func _ground(space: PhysicsDirectSpaceState3D, p: Vector2, r := 0.6) -> float:
	var hs: Array[float] = []
	for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		hs.append(RealmLayout.ground(space, p.x + o.x, p.y + o.y))
	hs.sort()
	return hs[2]


static func _braziers(root: Node) -> void:
	var space := (root as Node3D).get_world_3d().direct_space_state
	_r34_fires(root)
	for n: String in fire_names():
		var b := root.get_node_or_null("Zone/Braziers/" + n) as Node3D
		if b == null:
			push_warning("RealmBosses: no brazier " + n)
			continue
		var at: Vector2 = _fire(n)[0]
		var face: Vector2 = _fire(n)[1]
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
	for n: String in fire_names():
		var b := root.get_node_or_null("Zone/Braziers/" + n) as Node3D
		if b:
			var at: Vector2 = _fire(n)[0]
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
