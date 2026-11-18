extends Node
## RealmLayout.path_dist (path_index.gd: three grids of the segments near each cell) against the full scan over every
## segment, point by point: the same float, near a way, in open country and past the coarsest grid's reach.
##   godot --headless --path . res://zz/path_index_test.tscn

const POINTS := 2500

var bad := 0


func _ready() -> void:
	var segs: Array = []
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			segs.append([pts[i], pts[i + 1], float(path.w)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var area := RealmLayout.BOUNDS.grow(20.0)
	var far := 0
	for _n in POINTS:
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var want := INF
		for s: Array in segs:
			var a: Vector2 = s[0]
			var ab: Vector2 = (s[1] as Vector2) - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			want = minf(want, p.distance_to(a + ab * t) - float(s[2]))
		if want > 120.0:
			far += 1
		var got := RealmLayout.path_dist(p)
		_ok(got == want, "path_dist(%s) = %f, the full scan %f" % [p, got, want])
	print("path_index_test: %d points, %d beyond 120 m of a way, %d segments: %s" % [POINTS, far, segs.size(), "FAIL %d" % bad if bad > 0 else "PASS"])
	get_tree().quit(1 if bad > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if cond:
		return
	bad += 1
	if bad < 6:
		push_error("path_index: " + what)
