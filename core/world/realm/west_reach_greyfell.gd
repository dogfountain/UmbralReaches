extends RefCounted
## The Greyfell (West Reach, NW, tier 3): the Order's Broken Keep on its crag (reach_w_keep.glb, tools/blender/reach_west.py) and
## the fell shrine under the Crowns (reach_w_shrine.glb). The keep stands on a levelled terrace cut into the fell's side; its gate
## faces south down a flight of cut steps to fell_track. The donjon has a stair spiralling up inside it to a landing with a
## chest; the curtain's east wall has a stair to the wall-walk. Garrison camps are in EnemySpawner.REALM_CAMPS.
## Same API as the Realm's other places (groups "world_poi", "loot_chest", "grapple_anchor", "glide_perch"). No class_name.

const K := preload("res://core/world/realm/west_reach_kit.gd")

const KEEP_C := Vector2(-318.0, -108.0)           ## RealmReaches.KEEP_C
const PAD_Y := 12.0                                ## the keep's terrace (the crag's top is ~15.8; the hill rises behind it)
const PAD_R := 26.5
const SHRINE_C := Vector2(-281.0, -122.0)
const SHRINE_YAW := 0.5

const POIS := {
	"broken_keep": {"at": KEEP_C, "title": "The Broken Keep", "line": "the Order's last keep in the west; the garrison never stood down", "region": "greyfell", "r": 34.0},
	"fell_shrine": {"at": SHRINE_C, "title": "The Fell Shrine", "line": "a roofless chapel the Crowns lean on", "region": "greyfell", "r": 12.0},
}

static var keep_top := Vector3.INF               ## the donjon's chest landing (world), once built


static func release() -> void:
	keep_top = Vector3.INF


static func reserve(space: PhysicsDirectSpaceState3D) -> void:
	WorldLanes.register_terrace("poi_broken_keep", KEEP_C, PAD_R, PAD_Y)
	# the approach: a cut stair from the gate (z = KEEP_C.y + 24) down toward fell_track's head
	WorldLanes.register_site("poi_keep_stair", Rect2(KEEP_C.x - 4.0, KEEP_C.y + 22.0, 8.0, 24.0), PAD_Y - 6.0, PAD_Y - 12.0)
	var g := RealmLayout.ground(space, SHRINE_C.x, SHRINE_C.y)
	WorldLanes.register_site("poi_fell_shrine", Rect2(SHRINE_C - Vector2(7.5, 7.5), Vector2(15.0, 15.0)), g + 0.05, g)
	var Flora: GDScript = load("res://core/world/realm/realm_flora.gd")
	(Flora.get("tree_clear") as Array).append([KEEP_C, 40.0])
	(Flora.get("tree_clear") as Array).append([SHRINE_C, 14.0])


static func build(holder: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	for id: String in POIS:
		var h := K.host(holder, space, id, POIS[id])
		match id:
			"broken_keep": _keep(h, space)
			"fell_shrine": _shrine(h, space)


static func _keep(h: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var at := Vector3(KEEP_C.x, PAD_Y, KEEP_C.y)
	var root := K.model(h, space, "reach_w_keep.glb", KEEP_C, 0.0, PAD_Y, {"far_node": "KeepFar", "far_from": 150.0})
	h.set_meta("centre", at + Vector3(0, 4.0, 0))
	h.set_meta("approach", Vector3(KEEP_C.x, RealmLayout.ground(space, KEEP_C.x, KEEP_C.y + 44.0), KEEP_C.y + 44.0))
	_stair(h, space)
	if root:
		root.name = "Keep"
	# the donjon's landing: the chest (model local (-3.45, 16.5, -17.95): Blender y flips to Godot -z)
	var land := at + Vector3(-3.45, 16.5, -17.95)
	keep_top = land
	K.chest(h, "keep_top", land + Vector3(0.0, 0.05, -0.1), PI * 0.5)
	# a hall chest and a note in the bailey
	K.chest(h, "keep_hall", at + Vector3(-12.0, 0.1, 4.0), 0.4)
	# grapple anchors and a perch on the highest standing stone of the donjon
	var pts := K.high_points(space, Vector2(at.x, at.z - 14.5), Vector2(7.0, 7.0), 1.0, PAD_Y + 20.0, 3, 5.0)
	for i in pts.size():
		var p: Vector3 = pts[i]
		K.anchor(h, p + Vector3(0.0, 0.9, 0.0), p + Vector3(0.0, 0.1, 0.0), 26.0)
	if pts.size() > 0:
		K.perch(h, (pts[0] as Vector3) + Vector3(0, 0.2, 0), Vector3(0.4, 0.0, 1.0), 70.0)
	# an anchor on the gatehouse's second storey and one on the SE tower, to climb the wall without the stair
	for q: Vector2 in [Vector2(0.0, 15.5), Vector2(17.0, 14.0)]:
		var t := K.top(space, at.x + q.x, at.z - q.y + 0.0, PAD_Y + 40.0)
		if t != Vector3.INF and t.y > PAD_Y + 8.0:
			K.anchor(h, t + Vector3(0.0, 0.9, 0.0), t + Vector3(0.0, 0.1, 0.0), 24.0)


## The cut stair from the gate to the fell: 0.28 m risers, each step buried to the ground under it.
static func _stair(h: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var gate_z := KEEP_C.y + 24.5
	var x := KEEP_C.x
	var run := 0.5
	var n := 0
	var z := gate_z
	var ys: Array[float] = []
	# walk south until the natural ground comes up to the foot of a step (stairs stop where they meet the land)
	while n < 60:
		var gy := RealmLayout.ground(space, x, z + run * 0.5)
		var top_y := PAD_Y - 0.28 * float(n + 1)
		ys.append(top_y)
		if top_y <= gy + 0.14:
			break
		n += 1
		z += run
	var k := OssKit.new()
	k.keep_lanes = false
	var zz := gate_z
	for i in ys.size():
		var gy := RealmLayout.ground(space, x, zz + run * 0.5)
		var top_y := ys[i]
		var bot := minf(gy, top_y - 0.5) - 0.6
		k.box("stone", Vector3(x, (top_y + bot) * 0.5, zz + run * 0.5), Vector3(4.6, top_y - bot, run * 1.02), Basis.IDENTITY, true, 0.85)
		zz += run
	# cheek walls beside the flight
	for sx: float in [-2.55, 2.55]:
		var gy0 := RealmLayout.ground(space, x + sx, gate_z + run * ys.size() * 0.5)
		var len_ := run * float(ys.size())
		var c := Vector3(x + sx, 0.0, gate_z + len_ * 0.5)
		var yb: float = minf(RealmLayout.ground(space, x + sx, c.z), PAD_Y - 0.28 * float(ys.size())) - 0.6
		var rise := 0.28 * float(ys.size())
		var ang := atan2(rise, len_)
		k.box("stone", Vector3(c.x, PAD_Y - rise * 0.5 + 0.1, c.z), Vector3(0.5, 0.9, sqrt(len_ * len_ + rise * rise)), Basis(Vector3.RIGHT, ang), false, 0.85)
		var _u := gy0 + yb
	k.commit(h, "KeepStair")


static func _shrine(h: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var g := RealmLayout.ground(space, SHRINE_C.x, SHRINE_C.y)
	K.model(h, space, "reach_w_shrine.glb", SHRINE_C, SHRINE_YAW, g, {"far": [AABB(Vector3(-5.0, 0.0, -6.0), Vector3(10.0, 7.5, 12.0)), 0.0, Color(0.2, 0.2, 0.2), 110.0]})
	var b := Basis(Vector3.UP, SHRINE_YAW)
	K.chest(h, "fell_shrine", Vector3(SHRINE_C.x, g, SHRINE_C.y) + b * Vector3(0.0, 0.55, -3.2), SHRINE_YAW + PI)
	h.set_meta("approach", Vector3(SHRINE_C.x - 6.0, RealmLayout.ground(space, SHRINE_C.x - 6.0, SHRINE_C.y + 6.0), SHRINE_C.y + 6.0))
