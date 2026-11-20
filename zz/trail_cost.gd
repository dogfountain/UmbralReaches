extends Node
## The trail's route search in isolation (core/story/trail_route.gd): how long ensure() and route() take for a few legs.
##   godot --headless --path . res://zz/trail_cost.tscn
const TrailRoute := preload("res://core/story/trail_route.gd")


func _ready() -> void:
	var tr := TrailRoute.new()
	var t0 := Time.get_ticks_usec()
	tr.ensure()
	print("TRAILCOST ensure %.1f ms, %d nodes" % [float(Time.get_ticks_usec() - t0) / 1000.0, tr._pos.size()])
	var legs := [[Vector2(0, 30), Vector2(-150, 200)], [Vector2(-147, 195), Vector2(250, -60)], [Vector2(300, 100), Vector2(-300, -150)], [Vector2(0, 0), Vector2(60, 40)]]
	for r in 3:
		for l: Array in legs:
			var t1 := Time.get_ticks_usec()
			var res := tr.route(l[0], l[1])
			print("TRAILCOST route %s -> %s: %.1f ms (%d pts)" % [l[0], l[1], float(Time.get_ticks_usec() - t1) / 1000.0, (res.pts as PackedVector2Array).size() if not res.is_empty() else 0])
	get_tree().quit()
