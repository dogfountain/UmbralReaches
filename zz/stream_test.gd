extends Node
## The Realm's node streaming (core/world/realm/realm_stream.gd), headless with the stream forced on:
##   ring      at the hand-over only the build ring's flora is built (undergrowth far off is queued), the tall trees and
##             the canopy shells are all there
##   ensure    a far place's ring is built on demand (a teleport asks for it), the rest stays queued
##   drain     the queue empties; every piece is then built: the node counts equal what the emit counted
##   trunks    the trunk list read from the placement (LifePlace.trunks) is the cylinders the nodes hold
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh stream
const Flora := preload("res://core/world/realm/realm_flora.gd")

var main: Node
var t := 0.0
var done := false
var fails := 0


func _ready() -> void:
	Travel._busy = true
	RealmStream.force_on = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(what: String, ok: bool) -> void:
	print("STREAM_TEST ", "PASS " if ok else "FAIL ", what)
	if not ok:
		fails += 1


func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 240.0:
		print("STREAM_TEST FAIL timeout")
		done = true
		get_tree().quit(1)
		return
	if main == null or not main.has_meta("realm_done") or t < 2.0:
		return
	done = true
	await get_tree().physics_frame
	await _check()
	RealmStream.force_on = false
	print("STREAM_TEST %s %d" % ["DONE PASS" if fails == 0 else "DONE FAIL", fails])
	get_tree().quit(fails)


func _under_count(host: Node, centre: Vector2, r: float) -> int:
	var n := 0
	for ch in host.get_children():
		if ch is Node3D and String(ch.name).begins_with("Chunk_"):
			var p := (ch as Node3D).position
			if Vector2(p.x, p.z).distance_to(centre) <= r:
				n += 1
	return n


func _check() -> void:
	var rs := RealmStream.of(main)
	check("the night has a stream", rs != null)
	if rs == null:
		return
	var host := main.get_node("RealmFlora")
	var queued := rs.pending()
	check("pieces are queued at the hand-over (%d)" % queued, queued > 1000)
	var far := Vector2(rs.center.x + 260.0, rs.center.y - 60.0)
	if not RealmLayout.BOUNDS.grow(-20.0).has_point(far):
		far = Vector2(rs.center.x - 260.0, rs.center.y + 60.0)
	var near_n := _under_count(host, rs.center, RealmStream.RING_R - 30.0)
	var far_n := _under_count(host, far, 60.0)
	check("undergrowth chunks stand in the ring (%d)" % near_n, near_n > 10)
	check("undergrowth chunks 260 m off are not built yet (%d)" % far_n, far_n == 0)
	var shells := host.find_children("Canopy_*", "MeshInstance3D", true, false).size()
	check("every canopy shell is built (%d)" % shells, shells > 100)
	# a jump asks for its ring
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	p.teleport(Vector3(far.x, 40.0, far.y))
	var after_n := _under_count(host, far, 60.0)
	check("a teleport builds the ring it lands in (%d chunks)" % after_n, after_n > 0)
	check("... and queued less than it had", rs.pending() < queued)
	p.teleport(Vector3(rs.center.x, 3.0, rs.center.y))
	# the rest
	rs.drain()
	check("the queue is empty after drain", rs.pending() == 0 and main.has_meta(&"realm_streamed"))
	var counts: Vector2i = host.get_meta(&"flora_counts", Vector2i.ZERO)
	var mmis := host.find_children("Flora_*", "MultiMeshInstance3D", true, false).size()
	var shapes := 0
	var cyl: Array = []
	for b in host.find_children("FloraBody", "StaticBody3D", true, false):
		for c in b.get_children():
			var cs := c as CollisionShape3D
			if cs == null:
				continue
			shapes += 1
			if cs.shape is CylinderShape3D:
				cyl.append([cs.global_position - Vector3(0, (cs.shape as CylinderShape3D).height * 0.5, 0), (cs.shape as CylinderShape3D).radius, (cs.shape as CylinderShape3D).height])
	var shells2 := host.find_children("Canopy_*", "MeshInstance3D", true, false).size()
	check("the multimeshes built are the ones counted (%d + %d shells vs %d)" % [mmis, shells2, counts.x], mmis + shells2 == counts.x)
	check("the colliders built are the ones counted (%d vs %d)" % [shapes, counts.y], shapes >= counts.y)
	# trunks from the placement = the cylinders in the nodes
	var recs: Array = host.get_meta(&"trunks", [])
	check("trunk records (%d) are the cylinders built (%d)" % [recs.size(), cyl.size()], recs.size() == cyl.size())
	var key := func(v: Array) -> String:
		var q := v[0] as Vector3
		return "%d,%d,%d,%d" % [roundi(q.x * 20.0), roundi(q.y * 20.0), roundi(q.z * 20.0), roundi(float(v[1]) * 100.0)]
	var from_nodes := {}
	for v: Array in cyl:
		from_nodes[key.call(v)] = int(from_nodes.get(key.call(v), 0)) + 1
	var missing := 0
	for v: Array in recs:
		var k: String = key.call(v)
		if int(from_nodes.get(k, 0)) <= 0:
			missing += 1
		else:
			from_nodes[k] = int(from_nodes[k]) - 1
	check("every trunk record has its cylinder (%d missing)" % missing, missing == 0)
