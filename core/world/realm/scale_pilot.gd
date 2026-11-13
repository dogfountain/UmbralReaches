extends RefCounted
## The scale pilot (Luke, 13 Nov 2026: "the world should be more to the scale of wow, objects must be massive").
## One region, Weirford and its approach from the March Wall's west gate, built at World-of-Warcraft-like
## proportions so the idea can be judged in the game. The map is no larger and the wanderer is her own size:
## things are bigger beside her, in three tiers.
##   architecture   the inn, smithy, cottages, stables and watch hut (ARCH per building: a scale about the building's
##                  foot, plus taller walls and doors), the mill (MILL), the bridge (BRIDGE: half as wide again, its
##                  length and its low parapet kept), the west gatehouse and the wall beside it (wall_k)
##   flora          trees and rocks on that ground (FLORA wide, FLORA_Y tall: thicker for their height), fewer (FLORA_KEEP)
##   props          what she uses or stands beside: lanterns, the well, stalls, benches, barrels, chests, lamps (PROP)
## Every reader asks this file for its number, and for where a thing of the old plan stands in the new one (xz):
## the bigger buildings do not fit the old plots, so the town is re-planned inside the same ground.
## `-- --no-scale-pilot` builds the Realm as it was (before / after stills, perf A/B).
## Pure data and maths; no class_name: preload by path.

const RECT := Rect2(-246.0, 26.0, 102.0, 80.0)      ## the pilot's ground: x -246..-144, z 26..106
const EDGE := 14.0                                  ## flora eases back to its own size over this margin
const FLORA := 1.5
const FLORA_Y := 1.32
const FLORA_KEEP := 0.62
const STONE := 1.45
const PROP := 1.25
const CHUNK := 1.4                                  ## masonry, boards and slates are this much coarser on scaled buildings
const WALL := 1.4                                   ## the gatehouse, and the wall at the gate
const WALL_REACH := 44.0                            ## the wall is back to its own size this far along it from the gate
const GATE_Z := 67.0

## id -> the pilot's plot and proportions (realm_pois_west_marches.gd BLD holds the design): at, s (scale about the
## foot), h (wall height, design metres), door_h, door_w.
const ARCH := {
	"inn": {"at": Vector2(-181.0, 53.0), "s": 1.6, "h": 3.9, "door_h": 3.2, "door_w": 1.9},
	"smithy": {"at": Vector2(-175.0, 76.4), "s": 1.5, "h": 3.4},
	# the cottages leave the street (the inn and the smithy fill it): one faces the fire across the square's south side
	# (turned about), one stands behind the smithy. North-east of the inn the ridge is too steep for a house this size.
	"cot_a": {"at": Vector2(-199.0, 93.0), "s": 1.5, "h": 3.1, "door_h": 2.75, "door_w": 1.5, "yaw": PI, "flip": true},
	"cot_b": {"at": Vector2(-169.5, 90.5), "s": 1.5, "h": 3.1, "door_h": 2.75, "door_w": 1.5},
	# the stables turn about (they open west now, onto the ground south of the square): the old plot's south end, half as
	# long again, ran into the siege earthwork's ditch and the whole building sat a metre down in it
	"stables": {"at": Vector2(-181.5, 92.5), "s": 1.45, "h": 3.4, "yaw": -PI * 0.5, "flip": true},
	"watch_hut": {"at": Vector2(-240.0, 58.5), "s": 1.5, "h": 3.0, "door_h": 2.7, "door_w": 1.5},
	"mill_house": {"at": Vector2(-225.86, 55.2), "s": 1.45},         # the mill's levelled pad (MILL_AT + the house's -14.5 * MILL)
}
## The old plots (BLD at / size / yaw as built before the pilot): what xz() maps from.
const OLD := {
	"inn": [Vector2(-186.0, 56.0), Vector2(13.0, 9.0)], "smithy": [Vector2(-174.0, 75.0), Vector2(8.0, 6.0)],
	"cot_a": [Vector2(-165.0, 59.0), Vector2(6.5, 5.0)], "cot_b": [Vector2(-158.0, 74.0), Vector2(6.0, 5.0)],
	"stables": [Vector2(-196.0, 92.0), Vector2(7.0, 12.0)], "watch_hut": [Vector2(-230.0, 61.0), Vector2(5.0, 4.0)],
}
## The mill (r37_mill.glb, origin on the weir's line): its old origin, the new one and its scale. The wheel's
## water side stays where it was; the house grows west and north, clear of the wider bridge.
const MILL_OLD := Vector2(-207.0, 58.0)
const MILL_AT := Vector2(-204.83, 55.2)
const MILL := 1.45
## The bridge (r37_bridge.glb, centred): half as wide again. Its length is the river's and stays (a longer deck
## shut the weir track's mouth at its east end), and the parapet stays at the wanderer's waist.
const BRIDGE_C := Vector2(-208.0, 65.6)
const BRIDGE := Vector3(1.0, 1.05, 1.5)
## The square: its old disc and the new one (the fire, the well, the bench and the market move with it).
const SQUARE_OLD := [Vector2(-193.0, 71.0), 11.5]
const SQUARE := [Vector2(-192.5, 76.0), 13.0]
const STALL := Vector2(-184.5, 71.6)                ## the engineer's stall keeps its corner by the street
## The street lanterns (x, z, facing): two at each end of the wider bridge, one in the square.
const LANTERNS := [Vector3(-193.2, 60.9, PI), Vector3(-194.6, 70.4, 0.0), Vector3(-199.9, 76.0, 0.0), Vector3(-223.0, 62.0, PI), Vector3(-222.6, 70.4, 0.0)]

static var _on := -1


## False under `-- --no-scale-pilot`: every factor is 1 and xz() returns its argument.
static func on() -> bool:
	if _on < 0:
		_on = 0 if "--no-scale-pilot" in OS.get_cmdline_user_args() else 1
	return _on == 1


## A building's effective definition: the design `d` (BLD) with the pilot's plot and proportions, and "s".
static func bld(id: String, d: Dictionary) -> Dictionary:
	if not on() or not ARCH.has(id):
		return d
	var out := d.duplicate()
	out.merge(ARCH[id], true)
	return out


static func prop() -> float:
	return PROP if on() else 1.0


## 0..1: how far inside the pilot's ground (eased over EDGE).
static func weight(x: float, z: float) -> float:
	if not on():
		return 0.0
	var dx := minf(x - RECT.position.x, RECT.end.x - x)
	var dz := minf(z - RECT.position.y, RECT.end.y - z)
	return smoothstep(0.0, EDGE, minf(dx, dz))


## A tree's extra scale at (x, z): (wide, tall).
static func tree(x: float, z: float) -> Vector2:
	var w := weight(x, z)
	return Vector2(lerpf(1.0, FLORA, w), lerpf(1.0, FLORA_Y, w))


static func stone(x: float, z: float) -> float:
	return lerpf(1.0, STONE, weight(x, z))


## Fewer but bigger: is the plant at (x, z) kept? A hash of the spot, so no random stream is drawn from.
static func keeps(x: float, z: float) -> bool:
	var w := weight(x, z)
	if w <= 0.0:
		return true
	var h := float(absi(hash(Vector2i(roundi(x * 16.0), roundi(z * 16.0)))) % 10000) / 10000.0
	return h < lerpf(1.0, FLORA_KEEP, w)


## The March Wall's scale (height and thickness) at z on the west side: WALL at the gate, 1 from WALL_REACH on.
static func wall_k(side: int, z: float) -> float:
	if not on() or side > 0:
		return 1.0
	return lerpf(WALL, 1.0, smoothstep(14.0, WALL_REACH, absf(z - GATE_Z)))


## A point of the mill's old ground (xz) in the new plan.
static func mill_xz(v: Vector2) -> Vector2:
	return MILL_AT + (v - MILL_OLD) * MILL if on() else v


## Where a point of the old town plan (xz) stands in the pilot's plan: inside a building's old plot (and a doorstep
## round it) it moves and spreads with the building, on the bridge with the deck, at the mill with the mill, in the
## square with the square. Anywhere else it stays.
static func xz(v: Vector2) -> Vector2:
	if not on():
		return v
	for id: String in OLD:
		var o: Array = OLD[id]
		var c: Vector2 = o[0]
		var half: Vector2 = (o[1] as Vector2) * 0.5 + Vector2(2.6, 2.6)
		if absf(v.x - c.x) <= half.x and absf(v.y - c.y) <= half.y:
			var a: Dictionary = ARCH[id]
			return (a.at as Vector2) + (v - c) * float(a.s) * (-1.0 if bool(a.get("flip", false)) else 1.0)
	if absf(v.x - BRIDGE_C.x) <= 14.6 and absf(v.y - BRIDGE_C.y) <= 4.4:
		return BRIDGE_C + Vector2((v.x - BRIDGE_C.x) * BRIDGE.x, (v.y - BRIDGE_C.y) * BRIDGE.z)
	if v.x > -229.5 and v.x < -211.0 and v.y > 50.0 and v.y < 64.6:
		return mill_xz(v)
	var sc: Vector2 = SQUARE_OLD[0]
	if v.distance_to(sc) <= float(SQUARE_OLD[1]) + 0.5:
		return (SQUARE[0] as Vector2) + (v - sc) * (float(SQUARE[1]) / float(SQUARE_OLD[1]))
	return v


## A facing (xz) authored at old point `at`: turned about with a building that was (the horse still looks at its stable).
static func dir(at: Vector2, d: Vector2) -> Vector2:
	if on():
		for id: String in OLD:
			var o: Array = OLD[id]
			var half: Vector2 = (o[1] as Vector2) * 0.5 + Vector2(2.6, 2.6)
			if bool((ARCH[id] as Dictionary).get("flip", false)) and absf(at.x - (o[0] as Vector2).x) <= half.x and absf(at.y - (o[0] as Vector2).y) <= half.y:
				return -d
	return d


static func xz3(v: Vector3) -> Vector3:
	var q := xz(Vector2(v.x, v.z))
	return Vector3(q.x, v.y, q.y)


# --- the scaled kit ------------------------------------------------------------------------------------

## Coarser copies of the building materials (world-triplanar: a scaled wall keeps sharp texture but its courses
## would stay the size they were; these tile CHUNK times wider, so the stone and boards grow with the building).
const COARSE := {"r37_wall": "r37p_wall", "r37_board": "r37p_board", "stone": "r37p_stone", "slate": "r37p_slate",
	"wood": "r37p_wood", "ruin": "r37p_ruin", "r37_plaster": "r37p_plaster"}


static func ensure_mats() -> void:
	if OssKit._mats.has("r37p_wall"):
		return
	for key: String in COARSE:
		var base := OssKit.mat(key) as StandardMaterial3D
		if base == null:
			continue
		var m := base.duplicate() as StandardMaterial3D
		m.uv1_scale = base.uv1_scale / CHUNK
		OssKit._mats[String(COARSE[key])] = m


## An OssKit that builds everything `s` times bigger about `origin` (positions and sizes, so the colliders,
## floors and steps it makes are the scaled ones), in the coarser materials. s = 1: an OssKit.
class SKit extends OssKit:
	var origin := Vector3.ZERO
	var to := Vector3.ZERO           ## where `origin` stands once built (the mill moves as it grows)
	var s := 1.0
	var coarse := false

	func at(o: Vector3, k: float, chunky := true) -> void:
		origin = o
		to = o
		s = k
		coarse = chunky and k > 1.01

	func box(key: String, c: Vector3, size: Vector3, b := Basis.IDENTITY, solid := true, shade := 1.0) -> void:
		if coarse and COARSE.has(key):
			key = COARSE[key]
		super.box(key, to + (c - origin) * s, size * s, b, solid, shade)
