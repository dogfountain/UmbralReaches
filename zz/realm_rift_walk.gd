extends Node
## The Crossing walk (RealmRift, the Cinder Way: docs/r39/rift_from_scratch.md): drives the Player with debug_drive from Lastlight's
## north postern up the rift_rim path onto the Lip, down the Descent, over the causeway and the Cinder Isle, up the Ward Stair's four
## traverses, onto the ward landing, up the summit's approach stairs and onto the Warden's dais. The route is the layout's own lanes
## (art/models/rift_way_layout.json, in the rift's coordinates) walked Endgame.O east, where it stands.
##   godot --headless --path . res://zz/realm_rift_walk.tscn -- --realm --realm-modules=land,rift,bosses
##   -- --stair   the branch: the Lip, the Descent, the Foot, the branch along the wall to the chapel door and the kneeling stone
##   -- --lava    over the causeway to the Cinder Isle, then off its open north-east edge into the lava: it must burn once and give the
##                Player back on solid ground (as everywhere: lava_burn to the last safe ground)
## Prints LEG lines and "RIFTWALK ok", or "STUCK" (with where) and quits.
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const Crossing := preload("res://core/world/realm/rift/crossing.gd")
const Chapel := preload("res://core/world/realm/rift/chapel.gd")
var p: Player
var main: Node
var t := 0
var leg := 0
var leg_t := 0.0
var started := false
var route: Array = []          # [Vector3 goal (y ignored), label]
var max_drop := 0.0
var last_floor := 0.0
var burns := 0
var lava := false
var after_burn := 0


func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	var args := OS.get_cmdline_user_args()
	lava = "--lava" in args
	route = [[Vector3(0, 0, 22), "postern->rim"], [Vector3(0, 0, 4), "rift_rim"]]
	var way := Crossing.lane_pts("rift_crossing")
	for i in way.size():
		route.append([Vector3(way[i].x, 0, way[i].y), "way %d" % i])
	if "--stair" in args:                      # the branch: off the way at the Foot, along the wall to the chapel
		var foot := Crossing.point("foot")
		var cut := 0
		for i in route.size():
			if Vector2((route[i][0] as Vector3).x, (route[i][0] as Vector3).z).distance_to(Vector2(foot.x, foot.z)) < 4.0:
				cut = i
				break
		route = route.slice(0, cut + 1)
		for q: Vector2 in Crossing.lane_pts("rift_crossing_chapel"):
			route.append([Vector3(q.x, 0, q.y), "branch"])
		var door := Chapel.to_world(Vector3(0.0, 0.0, 0.0))
		var stone := Chapel.to_world(Vector3(0.0, 3.4, 0.0))
		route.append_array([[Vector3(door.x + 0.8, 0, door.z), "chapel door"], [Vector3(stone.x, 0, stone.z), "the kneeling stone"]])
	elif lava:                                  # to the Cinder Isle, then off its open edge
		var isle := Crossing.point("camp")
		var cut := 0
		for i in route.size():
			if Vector2((route[i][0] as Vector3).x, (route[i][0] as Vector3).z).distance_to(Vector2(isle.x, isle.z)) < 3.0:
				cut = i
				break
		route = route.slice(0, cut + 1)
		route.append_array([[Vector3(isle.x + 1.8, 0, isle.z - 2.2), "the isle's north-east corner"], [Vector3(isle.x + 2.0, 0, isle.z - 7.2), "off its open edge into the lava"]])
	else:
		for q: Vector2 in Crossing.lane_pts("rift_crossing_turn"):
			route.append([Vector3(q.x, 0, q.y), "ward stair"])
		for q: Vector2 in Crossing.lane_pts("rift_crossing_top"):
			route.append([Vector3(q.x, 0, q.y), "ward landing"])
		route.append_array([[Vector3(0, 0, -77.5), "summit stairs"], [Vector3(-2.8, 0, -79.5), "round the statue"], [Vector3(-3.6, 0, -83.5), "summit deck"],
			[Vector3(-2.6, 0, -87.0), "summit deck"], [Vector3(0, 0, -89.0), "summit rear"], [Vector3(0, 0, -92.0), "onto the dais"], [Vector3(0, 0, -103.9), "dais centre"]])
	for r: Array in route:
		r[0] = Endgame.w(r[0])
	Events.player_hurt.connect(func(amount: float, _from: Vector3) -> void:
		if amount >= 30.0:
			burns += 1
			print("BURN %d at leg %d (%s), back at %s" % [burns, leg, route[mini(leg, route.size() - 1)][1], p.global_position.snapped(Vector3.ONE * 0.01) if p else Vector3.ZERO]))


func _physics_process(delta: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not started:
		if not main.has_meta("realm_done") or t < 200:
			return
		started = true
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		for w in main.find_children("*", "", true, false):
			if w is WardSeal:
				(w as WardSeal).release()
		var at := Endgame.w(Vector3(0.0, 0.0, 30.0))                  # outside Lastlight's north postern
		p.global_position = Vector3(at.x, RealmLand.height_at(at.x, at.z) + 0.4, at.z)
		p.reset_physics_interpolation()
		last_floor = p.global_position.y
		print("RIFTWALK start at ", p.global_position)
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	if lava and burns > 0:
		after_burn += 1                         # given back: it must be standing on something solid, out of the lava, a moment later
		p.debug_drive(Vector3.ZERO, false)
		if after_burn == 90:
			var ok := p.is_on_floor() and p.global_position.y > -14.0
			print("RIFTWALK %s lava: burned %d, given back at %s (on floor %s)" % ["ok" if ok else "STUCK", burns, p.global_position.snapped(Vector3.ONE * 0.01), p.is_on_floor()])
			get_tree().quit()
		return
	if leg >= route.size():
		print("RIFTWALK %s end=%s biggest drop %.2f burns %d" % ["ok" if burns == 0 else "STUCK", p.global_position.snapped(Vector3.ONE * 0.01), max_drop, burns])
		get_tree().quit()
		return
	if p.is_on_floor():
		max_drop = maxf(max_drop, last_floor - p.global_position.y)
		last_floor = p.global_position.y
	if burns > 0 and not lava:
		print("STUCK fell into the lava on leg ", leg, " ", route[leg][1])
		get_tree().quit()
		return
	if "--trace" in OS.get_cmdline_user_args() and t % 6 == 0:
		print("TRACE leg %d %s" % [leg, p.global_position.snapped(Vector3.ONE * 0.01)])
	var goal: Vector3 = route[leg][0]
	var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
	leg_t += delta
	if d.length() < 0.7:
		print("LEG %d %s reached (%.1f, %.1f) y=%.2f t=%.1fs" % [leg, route[leg][1], p.global_position.x - Endgame.O.x, p.global_position.z, p.global_position.y, leg_t])
		leg += 1
		leg_t = 0.0
		return
	if leg_t > 16.0:
		print("STUCK leg %d %s goal=%s at %s (floor %s, wall %s %s)" % [leg, route[leg][1], goal - Endgame.O, p.global_position - Endgame.O, p.is_on_floor(), p.is_on_wall(), p.get_wall_normal().snapped(Vector3.ONE * 0.01) if p.is_on_wall() else Vector3.ZERO])
		get_tree().quit()
		return
	p.debug_drive(Vector3(d.x, 0, d.y).normalized(), false)
