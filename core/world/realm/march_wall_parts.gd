extends RefCounted
## The March Wall's parts as the world holds them: the collision of a bay, a tower and the gatehouse (to the numbers the
## Blender kit was made with, south_marches_kit_data.gd), the tower and the gate in the world, and what Weirford grows against the wall:
## a stair up its face to a door in the parapet, and a lean-to shed at its foot. realm_pois_south_marches.gd calls these.
## No class_name: preload by path.

const Kit := preload("res://core/world/realm/south_marches_kit.gd")
const Data := preload("res://core/world/realm/south_marches_kit_data.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")

const STAIR_Z := 42.9          ## the west wall (Weirford's face): the bay whose middle is here is the stair bay (the one between the bend
const STAIR_TOL := 3.0         ## at z 34 and the gate); the stair comes out from its landing into the town
const SHED_Z := 87.3           ## and the first bay south of the gate has the lean-to at its foot
const SHED_TOL := 4.0
const STAIR_MIN_LEN := 8.6     ## a stair bay needs room for the landing
const TOWER_HALF := 4.4        ## a tower takes this much of the line either side of its middle (its footing is 9.4 m)
const GATE_HALF := 10.8        ## the gate takes this much of the line either side of its middle

static var stair_done := false
static var shed_done := false


static func reset() -> void:
	stair_done = false
	shed_done = false


## Is this bay (side, middle, length) the one that takes the stair, or the shed? Once each, on Weirford's face only.
static func wants_stair(side: int, mid: Vector2, sl: float) -> bool:
	if side >= 0 or not Pilot.on() or stair_done or sl < STAIR_MIN_LEN or absf(mid.y - STAIR_Z) > STAIR_TOL:
		return false
	stair_done = true
	print("R37S town stair: bay at %s, %.1f m" % [mid, sl])
	return true


static func wants_shed(side: int, mid: Vector2, sl: float) -> bool:
	if side >= 0 or not Pilot.on() or shed_done or sl < 8.0 or absf(mid.y - SHED_Z) > SHED_TOL:
		return false
	shed_done = true
	print("R37S town shed: bay at %s, %.1f m" % [mid, sl])
	return true


## A bay's collision: the battered footing and the body (the walk's height; the parapet is for the eye).
static func seg_shapes(mid: Vector2, by: float, yaw: float, sl: float, k: float) -> Array:
	var b := Basis(Vector3.UP, yaw)
	var top := float(Data.WALL_WALK) * k
	var o := Vector3(mid.x, by, mid.y)
	return [
		[Kit.box(Vector3(sl + 0.3, top + 3.1, 3.05 * k)), Transform3D(b, o + Vector3(0.0, (top - 3.1) * 0.5, 0.0) + b * Vector3(0.0, 0.0, 0.075 * k))],
		[Kit.box(Vector3(sl + 0.3, 2.0 * k + 3.1, 4.0 * k)), Transform3D(b, o + Vector3(0.0, (2.0 * k - 3.1) * 0.5, 0.0) + b * Vector3(0.0, 0.0, 0.15 * k))]]


## The standing end of a breach (local x -3.2..3.2, the gap end +x): the full wall, then its steps down.
static func stub_shapes(xf: Transform3D, by: float, rb: Basis) -> Array:
	var out: Array = []
	for seg: Array in [[-1.6, 3.2, 7.75], [0.4, 0.8, 7.0], [1.2, 0.8, 5.6], [1.95, 0.7, 4.2], [2.6, 0.6, 2.8], [3.05, 0.3, 1.5]]:
		var w: Vector3 = xf * Vector3(float(seg[0]), 0.0, 0.0)
		var hh := float(seg[2])
		out.append([Kit.box(Vector3(float(seg[1]), hh + 3.0, 3.0)), Transform3D(rb, Vector3(w.x, by + (hh - 3.0) * 0.5, w.z) + rb * Vector3(0.0, 0.0, 0.1))])
	return out


## A tower (the line's middle c, the yaw that puts local +Z on the outer face): the model, its far silhouette, its collision.
static func tower(wh: Node3D, shapes: Array, c: Vector2, yaw: float, by: float, ruin: bool, vis: Vector2, far_end: float) -> void:
	var k := Pilot.wall_k(-1 if c.x < 0.0 else 1, c.y)
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * k), Vector3(c.x, by, c.y))
	Kit.put(wh, Kit.WALL, "TowerRuin" if ruin else "Tower", xf, vis, true, "Tower_%d_%d" % [int(c.x), int(c.y)])
	far(wh, "TowerFar", xf, far_end)
	var b := Basis(Vector3.UP, yaw)
	var zc := float(Data.TOWER_ZC) * k
	var top := (9.6 if ruin else float(Data.TOWER_DECK) + 0.05) * k
	var o := Vector3(c.x, by, c.y) + b * Vector3(0.0, 0.0, zc)
	shapes.append([Kit.box(Vector3(9.4 * k, 2.8 * k + 3.1, 9.4 * k)), Transform3D(b, o + Vector3(0.0, (2.8 * k - 3.1) * 0.5, 0.0))])
	shapes.append([Kit.box(Vector3(8.2 * k, top + 3.1, 8.2 * k)), Transform3D(b, o + Vector3(0.0, (top - 3.1) * 0.5, 0.0))])


## The gatehouse's collision, in its own frame (x along the wall, the passage along z): a rear block and a drum a side, the
## room over the arch (clear to the springing of the vault), and the passage's front piers. The passage stays 5.6 m (x k) wide.
static func gate_shapes(o: Vector3, yaw: float, k: float) -> Array:
	var b := Basis(Vector3.UP, yaw)
	var out: Array = []
	var deck := float(Data.GATE_DECK) * k + 0.05
	var rz := float(Data.GATE_REAR_Z)
	var dz := float(Data.GATE_DRUM_Z)
	var add := func(c: Vector3, sh: Shape3D) -> void:
		out.append([sh, Transform3D(b, o + b * c)])
	for s: float in [-1.0, 1.0]:
		add.call(Vector3(s * 6.5 * k, (deck - 3.1) * 0.5, ((rz - 0.5 + dz) * 0.5) * k), Kit.box(Vector3(7.4 * k, deck + 3.1, (dz - rz + 0.5) * k)))
		add.call(Vector3(s * 6.8 * k, (2.8 * k - 3.1) * 0.5, ((rz - 0.75 + dz) * 0.5) * k), Kit.box(Vector3(8.0 * k, 2.8 * k + 3.1, (dz - rz + 0.75) * k)))
		var cyl := CylinderShape3D.new()
		cyl.radius = 3.7 * k
		cyl.height = deck + 3.1
		add.call(Vector3(s * 6.5 * k, (deck - 3.1) * 0.5, dz * k), cyl)
		var cyl2 := CylinderShape3D.new()
		cyl2.radius = 4.05 * k
		cyl2.height = 2.8 * k + 3.1
		add.call(Vector3(s * 6.85 * k, (2.8 * k - 3.1) * 0.5, dz * k), cyl2)
		var sp := float(Data.GATE_SPRING) * k
		add.call(Vector3(s * 3.2 * k, (sp - 3.1) * 0.5, 1.2 * k), Kit.box(Vector3(0.8 * k, sp + 3.1, 1.55 * k)))
	var y0 := float(Data.GATE_SPRING) * k + 0.2
	var y1 := float(Data.GATE_ROOM_WALK) * k
	var zf := float(Data.GATE_FRONT_Z)
	add.call(Vector3(0.0, (y0 + y1) * 0.5, (zf + rz) * 0.5 * k), Kit.box(Vector3(6.8 * k, y1 - y0, (zf - rz + 0.3) * k)))
	return out


## A far silhouette under `host` (core/world/far_detail.gd).
static func far(host: Node3D, part: String, xf: Transform3D, end: float, fade_host := false) -> void:
	var m := Kit.mesh(Kit.WALL, part)
	if m != null:
		FarDetail.register(host, m, host.global_transform.affine_inverse() * xf, end, null, fade_host)


## Weirford's stair: out from the stair bay's landing into the town, straight (the bay's +z), solid collision (a few big
## steps nobody can climb): it climbs to a landing under a door in the parapet and no further, she does not walk the wall.
static func town_stair(wh: Node3D, shapes: Array, mid: Vector2, by: float, yaw: float, k: float, vis: Vector2) -> void:
	var rb := Basis(Vector3.UP, yaw)
	var xf := Transform3D(rb * Basis(Vector3.UP, -PI * 0.5) * Basis.from_scale(Vector3.ONE * k), Vector3(mid.x, by, mid.y) + rb * Vector3(0.0, 0.0, float(Data.STAIR_EDGE) * k))
	Kit.put(wh, Kit.WALL, "WallStair", xf, vis, true, "WallStair")
	var ln := float(Data.STAIR_LEN)
	var h := float(Data.WALL_WALK)
	var n := 8
	for i in n - 1:
		var xa := ln * float(i) / float(n)
		var xb := ln * float(i + 1) / float(n)
		var top := h * (1.0 - float(i + 1) / float(n)) * k
		if top < 0.5:
			continue
		var c: Vector3 = xf * Vector3((xa + xb) * 0.5, 0.0, 0.0)
		shapes.append([Kit.box(Vector3((float(Data.STAIR_W) + 1.0) * k, top + 3.1, (xb - xa) * k)), Transform3D(rb, Vector3(c.x, c.y + (top - 3.1) * 0.5, c.z))])


## The lean-to shed at the wall's foot: `at` is the point on the wall's outer face line at the shed's middle, yaw puts +Z outward.
static func town_shed(wh: Node3D, shapes: Array, space: PhysicsDirectSpaceState3D, at: Vector2, yaw: float, k: float, vis: Vector2) -> void:
	var b := Basis(Vector3.UP, yaw)
	var out := Vector2(sin(yaw), cos(yaw))
	var lo := INF
	for dx: float in [-3.0, 0.0, 3.0]:
		for dz: float in [0.5, 2.5]:
			var p := at + out * dz * k + Vector2(out.y, -out.x) * dx * k
			lo = minf(lo, RealmLayout.ground(space, p.x, p.y))
	var xf := Transform3D(b * Basis.from_scale(Vector3.ONE * k), Vector3(at.x, lo - 0.02, at.y))
	Kit.put(wh, Kit.WALL, "WallShed", xf, vis, true, "WallShed")
	var l := float(Data.SHED_L)
	var d := float(Data.SHED_D)
	for px: float in [-3.4, -1.7, 0.0, 1.7, 3.4]:
		var c: Vector3 = xf * Vector3(px, 0.0, d)
		shapes.append([Kit.box(Vector3(0.5 * k, 3.4 * k + 3.0, 0.5 * k)), Transform3D(b, Vector3(c.x, c.y + (3.4 * k - 3.0) * 0.5, c.z))])
	var e: Vector3 = xf * Vector3(-l * 0.5, 0.0, d * 0.5)
	shapes.append([Kit.box(Vector3(0.3 * k, 4.0 * k + 3.0, (d + 0.3) * k)), Transform3D(b, Vector3(e.x, e.y + (4.0 * k - 3.0) * 0.5, e.z))])
