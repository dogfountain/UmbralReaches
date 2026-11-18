extends RefCounted
## The nearest-path query (RealmLayout.path_dist), called tens of thousands of times by the build. PATHS' segments are packed once and
## indexed by three grids of coarser and coarser cells, each cell listing the segments that can come within its reach. A query takes the
## finest grid whose listed segments prove the answer: when the best of a cell's segments is within (reach - the widest path) of the
## point, every segment not listed is further than that, so the minimum over the listed ones IS the full scan's minimum (the same
## floats, the same result). Only a point further from every way than the coarsest grid's reach scans every segment. The finest grid
## (8 m cells, 16 m reach) serves the towns and the roads' shoulders; the 32 m grid serves ground up to ~58 m off a way (the dressing
## and the wonders' candidates in open country); the 96 m grid the rest of the Realm up to ~186 m. Load by path (no class_name).

const CELLS := [8.0, 32.0, 96.0]         ## cell sizes, finest first
const REACHES := [16.0, 64.0, 192.0]     ## how far past its cell a listed segment may lie

static var built := false
static var _a := PackedVector2Array()
static var _ab := PackedVector2Array()
static var _w := PackedFloat64Array()
static var _wmax := 0.0
static var _ox := 0.0
static var _oy := 0.0
static var _gw := PackedInt32Array()
static var _gh := PackedInt32Array()
static var _cells: Array = []            ## per level: an Array of PackedInt32Array per cell (row-major)


## Distance from p to the nearest path's edge (centreline minus half width).
static func dist(p: Vector2) -> float:
	for lv in CELLS.size():
		var cs: float = CELLS[lv]
		var cx := int(floorf((p.x - _ox) / cs))
		var cz := int(floorf((p.y - _oy) / cs))
		if cx < 0 or cz < 0 or cx >= _gw[lv] or cz >= _gh[lv]:
			continue
		var lists: Array = _cells[lv]
		var ids: PackedInt32Array = lists[cz * _gw[lv] + cx]
		var best := INF
		for j: int in ids:
			best = minf(best, _seg_d(p, j))
		# a segment not listed in this cell is further than the level's reach from all of it
		if best <= float(REACHES[lv]) - _wmax:
			return best
	var full := INF
	for j in _a.size():
		full = minf(full, _seg_d(p, j))
	return full


static func _seg_d(p: Vector2, j: int) -> float:
	var a := _a[j]
	var ab := _ab[j]
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t) - _w[j]


## Pack `paths` (RealmLayout.PATHS: {pts, w}) over `bd` (RealmLayout.BOUNDS). The index never refers back to RealmLayout (no cycle).
static func build(paths: Array, bd: Rect2) -> void:
	_a.clear()
	_ab.clear()
	_w.clear()
	_wmax = 0.0
	var boxes: Array[Rect2] = []
	for path: Dictionary in paths:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			_a.append(a)
			_ab.append(b - a)
			_w.append(float(path.w))
			_wmax = maxf(_wmax, float(path.w))
			boxes.append(Rect2(a, Vector2.ZERO).expand(b))
	_ox = bd.position.x
	_oy = bd.position.y
	_gw.resize(CELLS.size())
	_gh.resize(CELLS.size())
	_cells.clear()
	for lv in CELLS.size():
		var cs: float = CELLS[lv]
		var g: float = float(REACHES[lv]) + 0.01
		var gw := int(ceilf(bd.size.x / cs))
		var gh := int(ceilf(bd.size.y / cs))
		_gw[lv] = gw
		_gh[lv] = gh
		var lists: Array = []
		lists.resize(gw * gh)
		for k in lists.size():
			lists[k] = PackedInt32Array()
		for j in boxes.size():
			var bx := boxes[j]
			# the cells whose grown rectangle can touch the box (a cell either side of the estimate, then the exact test)
			var x0 := maxi(0, floori((bx.position.x - g - _ox) / cs) - 1)
			var x1 := mini(gw - 1, floori((bx.end.x + g - _ox) / cs) + 1)
			var z0 := maxi(0, floori((bx.position.y - g - _oy) / cs) - 1)
			var z1 := mini(gh - 1, floori((bx.end.y + g - _oy) / cs) + 1)
			for cz in range(z0, z1 + 1):
				for cx in range(x0, x1 + 1):
					var cell := Rect2(bd.position + Vector2(cx, cz) * cs, Vector2(cs, cs)).grow(g)
					if bx.intersects(cell, true):
						var ids: PackedInt32Array = lists[cz * gw + cx]
						ids.append(j)
						lists[cz * gw + cx] = ids
		_cells.append(lists)
	built = true
