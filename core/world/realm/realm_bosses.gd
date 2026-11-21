extends RefCounted
## Realm module "bosses" (docs/REALM_PLAN.md): the progression rebuilt into the new layout.
##   - Thorn Henge on its hill at RealmLayout.HENGE_C, its pilgrim stair from west_way's end
##   - the Ossuary's quarry (under the Waiting Field, RealmLayout.OSSUARY): its ground is cut by
##     RealmLayout.oss_pit_shape; the pit and the Pilgrims' Landing are registered here as keep-out sites
##     (before the terrain stamp, the lore and the flora). The tiers are built by the Ossuary itself
##     (world/areas/ossuary/ossuary.gd), which is streamed
##   - the four checkpoint braziers (not the spawn one) moved onto the new map
##   - camps: EnemySpawner.seed_realm (world/main.gd), planted once the Realm is built
## The summit ward stays where SummitDress makes it (RealmLayout.SUMMIT_WARD, the Crossing's head).

const ScalePilot := preload("res://core/world/realm/scale_pilot.gd")

## Checkpoint braziers: Zone/Braziers/<name> (kindle memory is by node name, so names are kept: StairFoot is the meadow fire).
## [xz, the point the fire faces (the respawn spot is 1.8 m that way)]
const BRAZIERS := {
	"StairFoot": [Vector2(-5.0, -2.0), Vector2(0.0, -2.0)],        # the meadow fire, at north_lane's end (the first act's first fire; the Crossing has its own)
	"Shrine": [Vector2(-31.0, 4.0), Vector2(-36.0, 8.6)],          # the Glimmer Glade, beside west_way
	"Landing": [Vector2(84.0, -36.0), Vector2(78.0, -40.0)],       # the Barrow Field, where fen_descent starts
	"Threshold": [Vector2(50.6, -57.5), Vector2(55.6, -56.6)],     # on the fen, where fen_descent ends (the Ossuary's fen door was above it until the Ossuary moved; the fire stays: a checkpoint, off fen_descent) (was (47, -55), half a metre off the Lay Brothers' Stair's foot: the climb glanced off it; it faces east so the ember post stands south of the brazier, off the path)
}
## r34 places (docs/r34/places.md): one fire for each new region (RealmLayout.SLOTS "fire"), so the
## Ember Road and the checkpoints keep the same spacing over the doubled ground. Copies of a valley
## fire, made unlit under Zone/Braziers (kindle memory is by name; restored here, as the scene's own
## restore ran before these existed). Their names on the Road and the map come from the region.
## Camps keep 13 m off them (the enemies pass). [xz, the point the fire faces]
const R34_FIRES := {
	"QuarryFire": [Vector2(-120.0, -83.0), Vector2(-126.0, -84.0)],     # the quarry's mouth, beside west_track's end
	"HoldsFire": [Vector2(-169.0, 15.5), Vector2(-164.0, 15.0)],        # the Rooted Holds, west of west_track (the holds stand east of it)
	"FoundryFire": [Vector2(123.0, -76.0), Vector2(128.0, -74.0)],      # moor_track's end, under the first slag heap
	"MoorFire": [Vector2(126.0, -8.0), Vector2(132.0, -9.0)],           # beside moor_track, under the tor
	"OrchardFire": [Vector2(-99.0, 104.0), Vector2(-106.0, 104.0)],     # beside orchard_lane
	"FieldFire": [Vector2(8.0, 108.0), Vector2(1.0, 110.0)],            # the Waiting Field's gate, off necropolis_way
	"MereFire": [Vector2(103.0, 98.0), Vector2(98.0, 96.0)],            # the mere's north bank, by mere_causeway
	"CrossingFire": [Vector2(-5.0, -2.0) + Endgame.O2, Vector2(0.0, -2.0) + Endgame.O2],   # the Crossing's foot, by rift_rim (the far north-east: Endgame)
	# --- south marches ---
	"OakFire": [Vector2(-52.0, 199.0), Vector2(-58.0, 199.0)],          # beside downs_track (4 m south of its bend: at z 192 the track ran through the fire), in the Grandmother Oak's shade (the door looks this way); off the Charnel Abbey's tower (-44 was its foot)
	"WellFire": [Vector2(44.0, 196.4), Vector2(52.0, 199.0)],           # beside downs_track (4 m south of its bend), on the way to the Well's rim and the descent gate
	# --- west marches ---
	"WeirfordFire": [Vector2(-196.0, 74.0), Vector2(-199.0, 77.0)],     # the town square, east of the bridge
	"SorrowFire": [Vector2(-190.0, -20.0), Vector2(-196.0, -22.0)],     # a ford on weir_track
	"HierarchFire": [Vector2(-193.0, -80.0), Vector2(-203.0, -80.0)],   # where weir_track reaches the old valley, by the empty plinth (4 m off the line, where it meets crowns_west)
	"SiegeFire": [Vector2(-219.0, 94.0), Vector2(-213.0, 97.0)],        # beside siege_track outside the palisade's north gate (6 m off the line)
	# --- the east marches ---
	"StillwaterFire": [Vector2(220.0, 52.0), Vector2(214.0, 40.0)],    # the lake's south shore, off spire_track
	"AnchorFire": [Vector2(209.0, -83.0), Vector2(206.0, -100.0)],     # the foot of the cliff, beside the bend of anchor_track (it stood on the track itself)
	"SaltFire": [Vector2(218.0, 98.0), Vector2(214.0, 96.0)],          # Saltmarket's yard
	# --- the Far Reaches (RealmReaches.SLOTS "fire") ---
	"GreyfellFire": [Vector2(-310.0, -66.0), Vector2(-312.0, -76.0)],   # fell_track's head, under the keep's crag
	"LanternFire": [Vector2(-292.0, 14.0), Vector2(-298.0, 16.0)],      # beside fell_track in a lit clearing
	"BarrowFire": [Vector2(-318.0, 96.0), Vector2(-323.0, 96.0)],       # barrow_track at the ridge's north end
	"ReedFire": [Vector2(-316.0, 302.0), Vector2(-322.0, 298.0)],       # Reedholm's landing
	"FallowFire": [Vector2(-146.0, 292.0), Vector2(-152.0, 296.0)],     # Fallowmere's green
	"ArchesFire": [Vector2(-24.0, 318.0), Vector2(-24.0, 322.0)],       # beside arches_way under the arches
	"SouthwoodFire": [Vector2(150.0, 296.0), Vector2(150.0, 302.0)],    # beside arches_way at the wood's edge
	"BellfallFire": [Vector2(322.0, 96.0), Vector2(318.0, 92.0)],       # bellfall_way at the crater's west lip (under Lastlight's south wall)
	"LastlightFire": [Vector2(318.5, 55.5), Vector2(328.0, 50.0)],      # Lastlight's yard, between the gates (off bell_track), facing the inn
	"NaveFire": [Vector2(296.0, 112.0), Vector2(293.0, 118.0)],         # nave_track on the mere's north shore
	"CairnFire": [Vector2(300.0, 286.0), Vector2(304.0, 282.0)],        # southwood_way's end on the heath
}


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	ThornHenge.use_realm()
	ThornHenge.build(root)
	_reserve_raids()
	_braziers(root)
	_ossuary_sites()
	# r30: the watchtower's ground (RealmWayfinding builds it after the flora; reserved now so the
	# stamp levels it and nothing grows there)
	(load("res://core/world/realm/realm_wayfinding.gd") as GDScript).call("reserve_tower", root)
	# r31: the places worth leaving the road for (realm_pois.gd) reserve their ground the same way
	(load("res://core/world/realm/realm_pois.gd") as GDScript).call("reserve", root)
	root.set_meta("realm_bosses_done", true)
	_reseat_braziers_later(root)            # not awaited: runs on after the stamp and flora
	print("REALM bosses: henge at %s, braziers %s (%d ms)" % [
		ThornHenge.C, BRAZIERS.keys(), Time.get_ticks_msec() - t0])


## r34 layout: the raid floors (RealmLayout.RAIDS) as sites, registered before the stamp, lore and flora
## so nothing is planted on them: the henge's a level terrace (cut and fill to its y), the summit's a
## cut-only round zone (its deck is built over the chasm). The boss agents build inside them.
static func _reserve_raids() -> void:
	for r: Dictionary in RealmLayout.RAIDS:
		var n := "raid_" + String(r.id)
		if String(r.mode) == "level":
			WorldLanes.register_terrace(n, r.c, float(r.r), float(r.y))
		else:
			# the summit's own monument (SummitDress) already stands in it
			WorldLanes.register_zone(n, r.c, float(r.r), float(r.y), float(r.y) - 0.8, ["SummitAltar"])
		if r.has("rx"):
			# an elliptical floor's wings east and west and its far ends (one circle its width would take in what lies
			# north and south of it: the platform, the cliff), so nothing grows or is placed under them
			var rr := float(r.r)
			var rxx := float(r.rx)
			for sgn: float in [-1.0, 1.0]:
				var tag := "_e" if sgn > 0.0 else "_w"
				for part: Array in [[rxx - rr * 0.85, rr * 0.85 + 1.5, ""], [rxx - rr * 0.45, rr * 0.5 + 2.0, "e"]]:
					var cc: Vector2 = (r.c as Vector2) + Vector2(sgn * float(part[0]), 0.0)
					if String(r.mode) == "level":
						WorldLanes.register_terrace(n + tag + String(part[2]), cc, float(part[1]), float(r.y))
					else:
						WorldLanes.register_zone(n + tag + String(part[2]), cc, float(part[1]), float(r.y), float(r.y) - 0.8, ["SummitAltar"])


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


## The Ossuary's quarry (): the pit and the Pilgrims' Landing keep the flora, the lore and the rocks out (no
## floor of their own: the terrain's cut is RealmLayout.oss_pit_shape, the stamp leaves them alone).
static func _ossuary_sites() -> void:
	var pit := OssFrame.wrect(Rect2(OssFrame.PIT_X0, OssFrame.PIT_Z0 - 5.0, OssFrame.PIT_X1_HALL - OssFrame.PIT_X0 + 4.0, OssFrame.PIT_Z1 - OssFrame.PIT_Z0 + 10.0))    # (the north margin is 1 m: the tomb stands on the brow)
	var y := RealmLayout.OSSUARY_GATE.y
	WorldLanes.register_site("oss_pit", pit, y, y)
	WorldLanes.register_site("oss_landing", OssFrame.wrect(Rect2(-17.5, -40.0, 14.5, 12.0)), y, y)      # with the steps up from the lane
	for ab: Dictionary in preload("res://world/areas/ossuary/oss_abbey.gd").site_rects():        # the abbey on the south bank: its ground is cut to it, nothing else is placed there
		WorldLanes.register_site(String(ab.name), ab.rect, float(ab.floor_y), float(ab.cut_y))
