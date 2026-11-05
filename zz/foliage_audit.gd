extends Node
## Foliage vs terraced ground: for every baked floor scatter instance (not under a builder), ray
## down to the terrain and compare. Needs a real renderer (headless reads MultiMesh buffers as
## identity): godot --path . res://zz/foliage_audit.tscn  →  "FOLIAGE off=0 ..."
## Expected offset per kind: blades sit 0.22 under the ground, caps sink 0.16, pebbles rest on it;
## spores drift up to 4 m above and are only checked for being buried.
const TOL := 0.5
var f := 0
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(_d: float) -> void:
	f += 1
	if f != 150: return
	var root := get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	var zone := root.get_node_or_null("Zone")
	if zone == null or not root.has_meta("terrain_stamped"):
		print("FOLIAGE not ready"); get_tree().quit(1); return
	var space := (root as Node3D).get_world_3d().direct_space_state
	var total := 0
	var off := 0
	var none := 0
	var worst := {}
	for node in zone.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null or mm.instance_count == 0 or not SeatProps._baked(mmi): continue
		var kind := SeatProps._kind(String(mmi.name))
		var buf := mm.buffer
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		if buf.size() < mm.instance_count * stride: continue
		var xf := mmi.global_transform
		for i in mm.instance_count:
			var o := i * stride
			var w := xf * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			var hit := SeatProps._ground(space, w + Vector3.UP * 12.0, w + Vector3.DOWN * 20.0)
			if hit.is_empty():
				none += 1; continue
			total += 1
			var gap: float = w.y - (hit.position as Vector3).y
			var bad := false
			match kind:
				"blade": bad = absf(gap + 0.22) > TOL
				"shroom": bad = absf(gap + 0.16) > TOL
				"pebble": bad = absf(gap) > TOL
				_: bad = gap < -TOL
			if bad:
				off += 1
				var key := "%s %s" % [kind if kind != "" else "other", String(mmi.name)]
				var e: Array = worst.get(key, [0, 0.0, Vector3.ZERO])
				e[0] += 1
				if absf(gap) > absf(float(e[1])): e[1] = gap; e[2] = w
				worst[key] = e
	for k in worst:
		print("  OFF ", k, " n=", worst[k][0], " worst_gap=", snappedf(worst[k][1], 0.01), " at ", (worst[k][2] as Vector3).snapped(Vector3.ONE * 0.1))
	print("FOLIAGE off=%d of %d (no terrain under: %d)" % [off, total, none])
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())
