extends Node
## The Sky Chain, in the built world: does the ground (after the stamp) poke through the stair, the court or the landing,
## and is the walk from the road to the court continuous (no step over 0.55 m)? Ends: SKY CHAIN PROBE PASS / FAIL n
var main: Node
var fails := 0


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(2.0).timeout
	var sp: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var js := load("res://art/models/wonders/sky_chain_chain.json") as JSON
	var geo: Dictionary = (js.data as Dictionary).geo
	var zmid := (float(geo.zw) + float(geo.zs)) * 0.5 - 0.25
	var prev := NAN
	var worst_step := 0.0
	var terr := 0
	# the walk: from 3 m before the first tread up the stair centre line to the landing
	var x := float(geo.xs) - 3.0
	while x < float(geo.x1) - 1.0:
		var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, zmid), Vector3(x, -10.0, zmid), Layers.WORLD))
		if hit.is_empty():
			fails += 1
			print("  FAIL no floor at x ", x)
			break
		var y: float = (hit.position as Vector3).y
		var nm := String((hit.collider as Node).name)
		if not is_nan(prev):
			worst_step = maxf(worst_step, absf(y - prev))
		prev = y
		if nm.begins_with("Terrain") and x > float(geo.xs) - 0.2:
			terr += 1
			print("  terrain on the stair at x %.1f (y %.2f)" % [x, y])
		x += 0.15
	print("  stair walk: worst step %.2f m, terrain hits %d" % [worst_step, terr])
	if worst_step > 0.55 or terr > 0:
		fails += 1
	# the court: the first thing under the sky is never the hill
	var bad := 0
	var cx := float(geo.xs) + 1.0
	while cx < float(geo.x1) - 1.0:
		var cz := float(geo.zn) + 1.5
		while cz < float(geo.zw) - 1.0:
			var h2 := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(cx, 70.0, cz), Vector3(cx, 5.0, cz), Layers.WORLD))
			if not h2.is_empty() and String((h2.collider as Node).name).begins_with("Terrain") and (h2.position as Vector3).y > float(geo.deck) + 0.15:
				bad += 1
				if bad < 8:
					print("  hill over the court at (%.0f, %.0f): y %.1f" % [cx, cz, (h2.position as Vector3).y])
			cz += 2.0
		cx += 2.0
	print("  court points under the hill: ", bad)
	if bad > 0:
		fails += 1
	print("SKY CHAIN PROBE ", "PASS" if fails == 0 else "FAIL %d" % fails)
	get_tree().quit()
