extends RefCounted
## (No class_name: const OakMound := preload("res://core/world/realm/oak_mound.gd").)
## The roots were modelled on level ground and the knoll falls away 5 m under their reach: earth is heaped
## to the underside of the roots, metre by metre outwards and 15 degrees round (TerrainStamp.mounds), the
## gaps between the roots filled by what the roots either side stand on, and blends back to the downs beyond.
const OUT := 10.0
const SINK := 1.2               ## the earth stands this far up the roots' undersides (the ground is a 2 m grid: it cannot follow a root's flank)
const BINS := 24
const DOOR_HALF := 0.35         ## radians: the doorway's land stays as it is
const RAMP := 0.22             ## slope of the approach to the door
const DOOR_EASE := 1.0          ## and eases into the heap over this much more

## `door` is the doorway's angle (atan2 of its x, z offset) and `ground` a Callable x, z -> y of the land as it is:
## the doorway and its approach (DOOR_HALF either side) keep the land as it is.
static func queue(roots: Mesh, centre: Vector2, oy: float, door: float, ground: Callable) -> void:
	if roots == null or "--no-oak-mound" in OS.get_cmdline_user_args():
		return
	var n := BINS
	var low := {}                                   ## d * n + angle bin -> the lowest root vertex there (world y)
	var far := 0
	for v: Vector3 in roots.get_faces():
		var d := int(Vector2(v.x, v.z).length())
		var ab := (floori(atan2(v.x, v.z) / TAU * float(n) + 0.5) % n + n) % n
		low[d * n + ab] = minf(float(low.get(d * n + ab, INF)), oy + v.y)
		far = maxi(far, d)
	if low.is_empty():
		return
	var rows: Array[PackedFloat32Array] = []
	var first := -1                                 ## the nearest ring with a root in it
	for d in far + 1:
		var row := PackedFloat32Array()
		row.resize(n)
		var any := false
		for a in n:
			row[a] = float(low[d * n + a]) if low.has(d * n + a) else NAN
			any = any or not is_nan(row[a])
		if any:
			first = d if first < 0 else first
			for a in n:                               # a gap between roots: round between the nearest either side
				if not is_nan(row[a]):
					continue
				var lo_a := a
				var hi_a := a
				var lo_n := 0
				var hi_n := 0
				while is_nan(row[lo_a]) and lo_n < n:
					lo_a = (lo_a - 1 + n) % n
					lo_n += 1
				while is_nan(row[hi_a]) and hi_n < n:
					hi_a = (hi_a + 1) % n
					hi_n += 1
				row[a] = lerpf(row[lo_a], row[hi_a], float(lo_n) / float(lo_n + hi_n))
		elif not rows.is_empty():
			row = rows[d - 1].duplicate()             # no root at this distance: the row before
		rows.append(row)
	for d in first:                                   # inside the first root: its row
		rows[d] = rows[first].duplicate()
	for d in far + 1:                                 # the doorway is walked through: the land stays as it is there
		for a in n:
			var ang := float(a) / float(n) * TAU
			var off := absf(wrapf(ang - door, -PI, PI))
			if off < DOOR_HALF + DOOR_EASE:
				var q := centre + Vector2(sin(ang), cos(ang)) * (float(d) + 0.5)
				var ramp := oy + 0.1 - RAMP * maxf(float(d) + 0.5 - 6.2, 0.0)         # the approach: never steeper than this, so turf holds
				var nat := maxf(float(ground.call(q.x, q.y)), ramp) - _sink(a, d, n, door)
				var keep := (1.0 - smoothstep(DOOR_HALF, DOOR_HALF + DOOR_EASE, off)) * (1.0 - smoothstep(8.0, 13.0, float(d)))
				rows[d][a] = lerpf(rows[d][a], nat, keep)
	var ring := PackedFloat32Array()
	ring.resize((far + 1) * n)
	for d in far + 1:
		for a in n:
			ring[d * n + a] = rows[d][a] + _sink(a, d, n, door) if d >= 3 and not is_nan(rows[d][a]) else NAN
	TerrainStamp.mounds.append({"c": centre, "core": float(far), "out": float(far) + OUT, "bins": n, "ring": ring, "floor": oy - 0.35, "door": door, "sill": oy + 0.05, "ramp": RAMP})


## How far up the roots the earth stands: deep, to bury what the 2 m grid cannot follow, but shallow by the door
## frame, where a deep heap would stand up as a bank beside the doorway.
static func _sink(a: int, d: int, n: int, door: float) -> float:
	var off := absf(wrapf(float(a) / float(n) * TAU - door, -PI, PI))
	var near := (1.0 - smoothstep(DOOR_HALF + 0.2, DOOR_HALF + 1.4, off)) * (1.0 - smoothstep(8.0, 13.0, float(d)))
	return lerpf(SINK, 0.35, near)
