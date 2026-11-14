class_name OssFrame
extends RefCounted
## Where the Ossuary stands (the relocation, Luke 14 Nov: "the ossuary is in a terrible place ... all
## bosses are on the top of the map"). The charnel house was built in its own coordinates on the rift's
## east wall; it now stands under the Waiting Field, and EVERY builder keeps those coordinates ("local").
## The Ossuary node carries this frame (position ORIGIN, yaw YAW), so geometry, lights and colliders
## move with it; only what talks to the world (the player, the terrain, the Realm's tables, the boss
## arena) converts, through w() / l() here.
##
## A quarter turn (yaw -90 deg): local +x (the bank, the rock the tiers hang on) is world +z (south,
## up the Waiting Field's slope), local -z (the way down the terraces: gate hall, gallery, pit,
## chapel) is world +x (east). Rects stay rects, so RealmLayout's tables and the sites convert
## without a rotation of their own. World y = local y + ORIGIN.y.

const ORIGIN := Vector3(-74.0, -7.4, 151.0)
const YAW := -PI * 0.5

## The quarried pit (local): its toe (the cliff's foot), which the terrain's cut follows. The tiers hang
## inside it over a dark pool; the cliff is cut round it (RealmLayout.oss_pit_shape).
const PIT_X0 := 2.0                      ## west lip (the Waiting Field's side; the bone bridge starts beyond it)
const PIT_X1 := 29.0                     ## east foot: the bank the gallery, the Counting Door and the stair shaft stand against
const PIT_X1_HALL := 30.6                ## ... where the gate hall's niche wall stands
const PIT_Z0 := -116.0                   ## chapel end
const PIT_Z1 := -15.0                    ## gate hall end
const POOL_Y := -16.0                    ## local y of the still pool (the pier feet stand in it)
const FLOOR_Y := -18.2                   ## local y of the pit's bed
const LANDING := Vector3(-3.5, 12.6, -34.0)   ## local: the landing the bone bridge starts from (the gate hall's west door's axis)


static func xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, YAW), ORIGIN)


## local -> world (a point).
static func w(p: Vector3) -> Vector3:
	return Vector3(ORIGIN.x - p.z, ORIGIN.y + p.y, ORIGIN.z + p.x)


## world -> local (a point).
static func l(p: Vector3) -> Vector3:
	return Vector3(p.z - ORIGIN.z, p.y - ORIGIN.y, ORIGIN.x - p.x)


## local -> world on the ground plane (xz).
static func w2(p: Vector2) -> Vector2:
	return Vector2(ORIGIN.x - p.y, ORIGIN.z + p.x)


static func l2(p: Vector2) -> Vector2:
	return Vector2(p.y - ORIGIN.z, ORIGIN.x - p.x)


## local -> world (a direction: the rotation only).
static func wd(d: Vector3) -> Vector3:
	return Vector3(-d.z, d.y, d.x)


static func ld(d: Vector3) -> Vector3:
	return Vector3(d.z, d.y, -d.x)


## A local xz rect, as the world rect it covers.
static func wrect(r: Rect2) -> Rect2:
	var a := w2(r.position)
	var b := w2(r.end)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## A local box, as the world box it covers.
static func waabb(a: AABB) -> AABB:
	var p := w(a.position)
	var q := w(a.end)
	return AABB(Vector3(minf(p.x, q.x), minf(p.y, q.y), minf(p.z, q.z)), (q - p).abs())


## A world yaw (rotation about +y) for a local one.
static func wyaw(y: float) -> float:
	return y + YAW


# --- the quarry's ground (RealmLayout.final_shape asks) -----------------------------------------------

const CLIFF := 3.2                       ## the cut's run from foot to crest (metres): a quarried face, not a slope
const LANDING_R := 7.0                   ## the Pilgrims' Landing's flat (blends out over 6 m)


## Distance outside the quarry's foot (negative inside): the pit as the Ossuary's local rectangle, its east
## foot stepping out 1.6 m where the gate hall's niche wall stands.
static func pit_d(p: Vector2) -> float:
	var q := l2(p)
	var ex := lerpf(PIT_X1, PIT_X1_HALL, smoothstep(-42.0, -38.0, q.y) * (1.0 - smoothstep(-21.0, -17.0, q.y)))
	var dx := maxf(PIT_X0 - q.x, q.x - ex)
	var dz := maxf(PIT_Z0 - q.y, q.y - PIT_Z1)
	var ox := maxf(dx, 0.0)
	var oz := maxf(dz, 0.0)
	var d := sqrt(ox * ox + oz * oz) + minf(maxf(dx, dz), 0.0)
	# the field side was ruled straight, a box stamped in the turf: a quarry's worked edge goes in and out where the
	# stone was won. Only the west lip and its corners (the east bank keeps its line: the gallery, the Counting Door
	# and the stair shaft stand against it), and only outward, never under a pier.
	var gate := RealmLayout.OSSUARY_GATE
	var west := (1.0 - smoothstep(PIT_X0 + 4.0, PIT_X0 + 9.0, q.x)) * smoothstep(LANDING_R + 4.0, LANDING_R + 10.0, p.distance_to(Vector2(gate.x, gate.z)))
	var wob := 2.0 + 1.8 * sin(q.y * 0.19 + 1.3) * sin(q.y * 0.067 + 0.4) + 0.8 * sin(q.y * 0.43)      # 0..4.6 m: on the 4 m ground lattice less did not show
	return d - maxf(wob, 0.0) * west


## The Ossuary's quarry: the Pilgrims' Landing levelled to the bone bridge's deck, then the pit cut down to its
## bed in a face (the tiers hang inside it over the still pool).
static func pit_shape(p: Vector2, h: float) -> float:
	var gate := RealmLayout.OSSUARY_GATE
	var dl := p.distance_to(Vector2(gate.x, gate.z))
	if dl < LANDING_R + 6.0:
		h = lerpf(h, gate.y - 0.04, 1.0 - smoothstep(LANDING_R, LANDING_R + 6.0, dl))
	var d := pit_d(p)
	if d > CLIFF + 0.5:
		return h
	return lerpf(ORIGIN.y + FLOOR_Y, h, smoothstep(0.0, CLIFF, d))
