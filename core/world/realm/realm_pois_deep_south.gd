extends RefCounted
## The Deep South (docs/far_reaches.md): the places of Fallowmere, the Long Arches and the Southwood, in the manner of
## realm_pois_west_marches.gd: ground reserved before the stamp and the flora (reserve), the places built after them
## (build), everything placed by ground ray. Models: tools/blender/reach_south*.py (art/models/reach_s_*.glb) through
## deep_south_kit.gd; writings: lore/deep_south_places.gd + lore/deep_south_texts.gd; people: village_cast_deep_south.gd.
##
##   arches_line   the Order's aqueduct: eleven lower bays on stacked piers, twenty-two upper bays, the channel on top
##                 (walkable), one fallen span (its rubble on the floor), the castellum at the west end with a stair
##                 up its inside to the channel; a far mesh takes over from FAR_END m.
## Built by realm_pois.gd REACH_POIS. No class_name: preload by path.

const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")
const Inscription := preload("res://core/world/realm/lore/inscription.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Kit := preload("res://core/world/realm/deep_south_kit.gd")
const P := preload("res://core/world/realm/realm_pois.gd")

const ARCHES := "reach_s_arches.glb"
const CASTELLUM := "reach_s_castellum.glb"

const LINE_Z := RealmReaches.ARCH_Z
const CAST_C := Vector2(-60.0, RealmReaches.ARCH_Z)      ## the castellum's middle
const BAY0 := -48.0                                      ## the first lower arch's middle; bays every PITCH
const PITCH := 12.0
const N_BAYS := 11
const BROKEN := 7                                        ## the fallen span (bay index): its middle is BAY0 + 7 * PITCH = 36
const DECK_ABOVE_GROUND := 15.0                          ## the castellum's top floor over its door sill
const SPRING_TO_WALK := 13.95                            ## a lower arch's springing to the walkway
const NEAR_END := 150.0
const FAR_END := 150.0

const LOOT := {
	"arches_cistern": ["iron", {"grave_ash": 16, "grave_iron": 2, "relic_fragment": 1}],
}

static var spots := {}
static var built: Array[String] = []
static var cast_ground := 0.0
static var deck_y := 0.0
static var pier_ground := {}                             ## k -> lowest ground under the pier


static func release() -> void:
	spots.clear()
	pier_ground.clear()
	Kit.release()


static func _skip() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--no-deep-south":
			return true
	return false


static func _lo(space: PhysicsDirectSpaceState3D, rc: Rect2, n := 5) -> float:
	var lo := INF
	for ix in n:
		for iz in n:
			lo = minf(lo, RealmLayout.ground(space, rc.position.x + rc.size.x * ix / float(n - 1), rc.position.y + rc.size.y * iz / float(n - 1)))
	return lo


static func _bx(c: Vector2, half: Vector2) -> Rect2:
	return Rect2(c - half, half * 2.0)


# --- reserve (before the stamp and the flora) ---------------------------------------------------------------

static func reserve(root: Node) -> void:
	spots.clear()
	pier_ground.clear()
	if _skip():
		return
	var space := (root as Node3D).get_world_3d().direct_space_state
	# the castellum: a levelled floor under the tower (its footprint 9 m, the footing and the apron round it)
	var rc := _bx(CAST_C, Vector2(7.5, 7.5))
	var lo := _lo(space, rc)
	cast_ground = lo + 0.05
	WorldLanes.register_site("ds_castellum", rc, lo + 0.05, lo)
	spots["castellum"] = {"at": Vector3(CAST_C.x, cast_ground, CAST_C.y), "rect": rc}
	deck_y = cast_ground + DECK_ABOVE_GROUND
	Flora.tree_clear.append([CAST_C, 16.0])
	# the piers: the ground under each, and the trees kept off the whole line
	for k in N_BAYS + 1:
		var x := BAY0 - PITCH * 0.5 + PITCH * k
		var g := INF
		for dx: float in [-1.8, 0.0, 1.8]:
			for dz: float in [-3.0, 0.0, 3.0]:
				g = minf(g, RealmLayout.ground(space, x + dx, LINE_Z + dz))
		pier_ground[k] = g
		Flora.tree_clear.append([Vector2(x, LINE_Z), 9.0])
	for k in N_BAYS:
		Flora.tree_clear.append([Vector2(BAY0 + PITCH * k, LINE_Z), 8.0])
	print("REALM_POI deep south reserved castellum ground %.2f deck %.2f" % [cast_ground, deck_y])


# --- build (after the flora) ------------------------------------------------------------------------------------

static func build(holder: Node3D) -> void:
	built.clear()
	if _skip():
		return
	var space := holder.get_world_3d().direct_space_state
	var host := _host(holder, "arches_line", Vector2(0.0, LINE_Z), "arches", "The Long Arches", "the water stopped when the sky did", 95.0, space)
	_aqueduct(host, space)
	_castellum(host, space)
	built.append("arches_line")
	print("REALM_POI deep south built %s" % [built])


static func _host(holder: Node3D, id: String, at: Vector2, region: String, title: String, line: String, r: float, space: PhysicsDirectSpaceState3D) -> Node3D:
	var host := Node3D.new()
	host.name = "Poi_" + id
	host.set_meta("site", "poi_" + id)
	holder.add_child(host)
	host.add_to_group("world_poi")
	host.set_meta("poi", id)
	host.set_meta("title", title)
	host.set_meta("line", line)
	host.set_meta("region", region)
	host.set_meta("centre", Vector3(at.x, RealmLayout.ground(space, at.x, at.y), at.y))
	host.set_meta("radius", r)
	return host


static func _chest(host: Node3D, id: String, at: Vector3, yaw: float) -> Node3D:
	var c: Node3D = Chest.new()
	c.name = "Chest_" + id
	c.set("chest_id", id)
	var l: Array = LOOT.get(id, ["wood", {"grave_ash": 6}])
	c.set("tier", l[0])
	c.set("loot", (l[1] as Dictionary).duplicate())
	host.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return c


static func _lore(host: Node3D, id: String, at: Vector3, mark := Vector3.INF) -> void:
	var s := Inscription.make(id)
	host.add_child(s)
	s.global_position = at
	s.set("mark", mark if mark != Vector3.INF else at)


# --- the aqueduct ---------------------------------------------------------------------------------------------

static func _xf(x: float, y: float, z: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))


static func _aqueduct(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var walk := deck_y
	var spring := walk - SPRING_TO_WALK
	var far_items: Array = []
	var bays := Node3D.new()
	bays.name = "Bays"
	host.add_child(bays)
	var batch: Array = []
	# the piers: a stack of courses on a footing, from the springing line down to the ground
	for k in N_BAYS + 1:
		var x := BAY0 - PITCH * 0.5 + PITCH * k
		var g: float = pier_ground.get(k, spring - 8.0)
		var n := maxi(0, ceili((spring - g - 0.1) / 1.5))
		var y_bot := spring - 1.5 * n
		for i in n:
			var yc := spring - 1.5 * (i + 1)
			Kit.add(bays, ARCHES, "PierL%d" % ((i + k) % 2), _xf(x, yc, LINE_Z), NEAR_END, true, true, batch)
		Kit.add(bays, ARCHES, "PierFoot", _xf(x, y_bot, LINE_Z), NEAR_END, true, true, batch)
		var ph := spring - (y_bot - 3.0)
		var hull := FarDetail.hull(AABB(Vector3(-1.5, 0.0, -2.5), Vector3(3.0, ph, 5.0)), 0.0, Color(0.5, 0.49, 0.45))
		far_items.append([null, hull, _xf(x, y_bot - 3.0, LINE_Z)])
	for k in N_BAYS:
		var x := BAY0 + PITCH * k
		if k == BROKEN:
			Kit.add(bays, ARCHES, "ArchLBroken", _xf(x, spring, LINE_Z), NEAR_END, true, true, batch)
			Kit.add(bays, ARCHES, "ArchUBrokenE", _xf(x - 3.0, spring + 9.1, LINE_Z), NEAR_END, true, true, batch)
			Kit.add(bays, ARCHES, "ArchUBrokenW", _xf(x + 3.0, spring + 9.1, LINE_Z), NEAR_END, true, true, batch)
			Kit.add(bays, ARCHES, "ChanBroken", _xf(x, walk, LINE_Z), NEAR_END, true, true, batch)
			continue
		Kit.add(bays, ARCHES, "ArchL", _xf(x, spring, LINE_Z), NEAR_END, true, true, batch)
		far_items.append([ARCHES, "ArchL", _xf(x, spring, LINE_Z)])
		for dx: float in [-3.0, 3.0]:
			Kit.add(bays, ARCHES, "ArchU", _xf(x + dx, spring + 9.1, LINE_Z), NEAR_END, true, true, batch)
			far_items.append([ARCHES, "ArchU", _xf(x + dx, spring + 9.1, LINE_Z)])
		Kit.add(bays, ARCHES, "Chan", _xf(x, walk, LINE_Z), NEAR_END, true, true, batch)
		far_items.append([ARCHES, "Chan", _xf(x, walk, LINE_Z)])
	var draws := Kit.merge(bays, batch, 36.0, NEAR_END)
	print("REALM_POI deep south: the arches in %d draws (%d pieces merged)" % [draws, batch.size()])
	var far := Kit.far_merged(far_items)
	FarDetail.register(host, far, Transform3D.IDENTITY, NEAR_END, null, false)
	# up on the walkway: grapple anchors on the parapet over the piers and glide perches at the ends of the span
	for k: int in [3, 5, 9]:
		var x := BAY0 + PITCH * (k - 0.5)
		P._grapple(host, Vector3(x, walk + 0.7, LINE_Z + 2.15), Vector3(x, walk + 0.05, LINE_Z + 1.5), 26.0)
		P._grapple(host, Vector3(x, walk + 0.7, LINE_Z - 2.15), Vector3(x, walk + 0.05, LINE_Z - 1.5), 26.0)
	P._perch(host, Vector3(BAY0 + PITCH * 9.5, walk + 0.6, LINE_Z), Vector3(1.0, 0.0, 0.0), 24.0)
	P._perch(host, Vector3(BAY0 + PITCH * 4.5, walk + 0.6, LINE_Z + 1.4), Vector3(0.0, 0.0, 1.0), 24.0)
	host.set_meta("deck_y", walk)


static func _castellum(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var base_y := deck_y - DECK_ABOVE_GROUND            # = the floor of the ground hall
	# the tower: z = 0 of the model is the top floor; the ground floor sits 15 m under it
	var xf := Transform3D(Basis(Vector3.UP, 0.0), Vector3(CAST_C.x, deck_y, CAST_C.y))
	var tw := Node3D.new()
	tw.name = "Castellum"
	host.add_child(tw)
	Kit.add(tw, CASTELLUM, "Tower", xf, 0.0)
	Kit.add(tw, CASTELLUM, "Roof", xf, 0.0, false)
	Kit.add(tw, CASTELLUM, "Foot", xf, 0.0)
	var far := Kit.far_merged([[CASTELLUM, "Tower", xf]])
	FarDetail.register(tw, far, Transform3D.IDENTITY, 190.0, null, false)
	P._grapple(host, Vector3(CAST_C.x + 5.0, deck_y + 4.2, CAST_C.y), Vector3(CAST_C.x + 4.3, deck_y + 0.1, CAST_C.y), 28.0)
	P._perch(host, Vector3(CAST_C.x, deck_y + 4.4, CAST_C.y - 3.0), Vector3(0.0, 0.0, -1.0), 26.0)
	_chest(host, "arches_cistern", Vector3(CAST_C.x - 1.8, deck_y + 0.02, CAST_C.y + 1.6), 0.6)
	spots["castellum_floor"] = base_y
