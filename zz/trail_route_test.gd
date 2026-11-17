extends Node
## Does the one waypoint follow the ways? (core/story/quest_trail.gd, ui/waypoint.gd)
##   godot --headless --path . res://zz/trail_route_test.tscn
## Builds the Realm, then for each route (Hearthward's green to a place near and far) makes the trail's own route (the
## ways' A*, the navigation mesh on and off them) and walks a wanderer along it every 2 m, as the trail's poll would
## see it. Prints each route's make-up ("ROUTE": metres on the ways, the legs onto and off them) and every checkpoint
## the mark jumps to ("MARK": where, how far ahead, how far from the nearest road, track or lane, and whether it is the
## place). "PROBE ok" when every checkpoint off the last stretch is within OFF_WAY of a way and the place shows only
## within LOOK; else "PROBE FAIL n".

const QuestTrail := preload("res://core/story/quest_trail.gd")
const TrailRoute := preload("res://core/story/trail_route.gd")
const RealmLayout := preload("res://core/world/realm/realm_layout.gd")
const OFF_WAY := 4.0

var main: Node
var t := 0
var done := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	t += 1
	if done:
		return
	if t % 30 == 0:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
	if main == null or not main.has_meta("realm_done") or not NavAssist.ready():
		if t > 60 * 180:
			print("PROBE FAIL realm or nav not ready")
			get_tree().quit()
		return
	done = true
	_run()


func _run() -> void:
	var green := Vector3(0.0, 0.2, 26.0)
	var places := [
		["the Keg's door", Vector3(18.0, 0.0, 22.0)],
		["the meadow fire", Vector3(-5.0, 0.0, -2.0)],
		["the henge", Vector3(-79.8, 9.0, -19.8)],
		["the barrows", Vector3(54.0, 0.0, -59.5)],
		["the Ossuary landing", RealmLayout.OSSUARY_GATE],
		["the Lanternwood", Vector3(-275.0, NAN, 8.0)],
		["the Long Arches", Vector3(0.0, NAN, 277.0)],
		["the Drowned Nave", Vector3(279.6, NAN, 146.4)],
	]
	var fire := Vector3(-5.0, 0.2, 1.5)                # the meadow fire, where the first act's "Pick a door" is given
	var fails := 0
	for pl: Array in places:
		var foot: Vector3 = pl[1]
		if is_nan(foot.y):
			foot.y = RealmLayout.macro_height(foot.x, foot.z)
		fails += await _probe(String(pl[0]), green, foot)
	for w in main.find_children("*", "", true, false):     # the seals the guide points at, from the meadow fire
		if w is WardSeal:
			fails += await _probe("%s (from the meadow fire)" % w.name, fire, (w as Node3D).global_position)
	print("PROBE ok" if fails == 0 else "PROBE FAIL %d" % fails)
	get_tree().quit()


func _probe(label: String, from: Vector3, foot: Vector3) -> int:
	var tr := QuestTrail.new()
	tr.process_mode = Node.PROCESS_MODE_DISABLED       # driven by hand here, not by the tracker
	add_child(tr)
	tr.remove_from_group("quest_trail")
	var r: Dictionary = tr._ways.route(Vector2(from.x, from.z), Vector2(foot.x, foot.z))
	var way_lo := INF                                  # the stretch of the route that is the way (arc metres)
	var way_hi := -INF
	if r.is_empty():
		print("WAYS %s: no way found" % label)
	else:
		var wp: PackedVector2Array = r.pts
		print("WAYS %s: entry %.0f m at %s, along %.0f m (%d nodes), exit %.0f m from %s" % [label, float(r.entry), wp[0].round(), float(r.length), wp.size(), float(r.exit), wp[wp.size() - 1].round()])
	tr._build(from, foot)
	var wait := 0
	while tr._pending > 0 and wait < 240:
		await get_tree().physics_frame
		wait += 1
	if tr._pending > 0:
		tr._finish_legs(true)
	var rp: PackedVector2Array = tr._rp
	var rs: PackedFloat32Array = tr._rs
	var fails := 0
	if rp.size() < 2:
		print("ROUTE %s: none (%.0f m straight)" % [label, Vector2(foot.x - from.x, foot.z - from.z).length()])
		tr.queue_free()
		return 0
	var total := rs[rs.size() - 1]
	if not r.is_empty():
		var wp: PackedVector2Array = r.pts
		way_lo = rs[_nearest(rp, wp[0])]
		way_hi = rs[_nearest(rp, wp[wp.size() - 1])]
		if Vector2(rp[_nearest(rp, wp[0])]).distance_to(wp[0]) > 6.0:
			way_lo = INF                                   # the trail did not take the way (a detour past its caps)
			print("  (the trail went across country: the way was a detour)")
	var on := 0.0
	for i in range(1, rp.size()):
		if _way_dist(rp[i]) <= OFF_WAY:
			on += rs[i] - rs[i - 1]
	var straight := Vector2(foot.x - from.x, foot.z - from.z).length()
	print("ROUTE %s: %.0f m along (%.0f straight), %.0f m on roads/tracks/lanes (%d%%)" % [label, total, straight, on, roundi(100.0 * on / total)])
	# walk it: every 2 m of the route, a wanderer on it; log each jump of the mark
	var last := Vector3(INF, INF, INF)
	var s := 0.0
	var i := 0
	while s <= total:
		while i < rs.size() - 1 and rs[i + 1] <= s:
			i += 1
		var here := Vector3(rp[i].x, 0.0, rp[i].y)
		tr._progress(here)
		tr._aim(here)
		var g: Vector3 = tr.guide
		var key := foot if g == Vector3.INF else g
		if key.distance_to(last) > 0.5:
			last = key
			var to_place := Vector2(foot.x - here.x, foot.z - here.z).length()
			if g == Vector3.INF:
				var bad := to_place > QuestTrail.LOOK + 1.0
				fails += int(bad)
				print("  MARK at %4.0f m walked: the place, %.0f m off%s" % [s, to_place, "  <-- the place shown from too far" if bad else ""])
			else:
				var wd := _way_dist(Vector2(g.x, g.z))
				var ahead := Vector2(g.x - here.x, g.z - here.z).length()
				var on_way := tr._rs[tr._gi] >= way_lo - 3.0 and tr._rs[tr._gi] <= way_hi + 3.0   # onto and off the way go across country
				var bad := wd > OFF_WAY and on_way
				fails += int(bad)
				print("  MARK at %4.0f m walked: checkpoint %s, %.0f m ahead, %.1f m from a way, %.0f m from the place%s" % [s, Vector2(g.x, g.z).round(), ahead, wd, to_place, "  <-- off the ways" if bad else ("" if on_way else "  (getting on or off the ways)")])
		s += 2.0
	tr.queue_free()
	return fails


## Metres from p to the nearest road, track, lane or walked causeway (RealmLayout.PATHS and the registered lanes).
func _way_dist(p: Vector2) -> float:
	var best := INF
	for path: Dictionary in RealmLayout.PATHS:
		best = minf(best, _poly_dist(p, path.pts))
	for l: Array in WorldLanes.extra_lanes:
		if TrailRoute.walked(String(l[0])):               # the walked ones only (a wall's reserved strip is no way)
			best = minf(best, _poly_dist(p, l[1]))
	var stair: Array = [RealmLayout.HENGE_STAIR_FOOT]       # the pilgrim stair (core/story/trail_route.gd adds it)
	for v: Vector3 in ThornHenge.stair_pts:
		stair.append(Vector2(v.x, v.z))
	return minf(best, _poly_dist(p, stair))


func _poly_dist(p: Vector2, pts: Variant) -> float:
	var best := INF
	var arr: Array = Array(pts)
	for k in range(1, arr.size()):
		var a: Vector2 = Vector2(arr[k - 1].x, arr[k - 1].y if arr[k - 1] is Vector2 else arr[k - 1].z)
		var b: Vector2 = Vector2(arr[k].x, arr[k].y if arr[k] is Vector2 else arr[k].z)
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return best


func _nearest(rp: PackedVector2Array, q: Vector2) -> int:
	var bi := 0
	var bd := INF
	for i in rp.size():
		var d := rp[i].distance_squared_to(q)
		if d < bd:
			bd = d
			bi = i
	return bi
