extends Node
## The Crossing walk (RealmRift): drives the Player with debug_drive from Lastlight's north postern up the rift_rim
## path, over the Crossing (forecourt, towers, viaduct, fallen column, round the Spindle, the last
## flights), onto the ward landing, up the summit's approach stairs and onto the Warden's dais. The route is in the
## Crossing's own coordinates (chasm on x 0) and walked Endgame.O east, where it stands.
## (r39: the redesigned Crossing: the causeway, the Pilgrims' Gate, the helix round the Spindle, the bridge.)
##   godot --headless --path . res://zz/realm_rift_walk.tscn -- --realm --realm-modules=land,rift
## Prints LEG lines and "RIFTWALK ok", or "STUCK" (with where) and quits.
const RealmLand := preload("res://core/world/realm/realm_land.gd")
var p: Player
var main: Node
var t := 0
var leg := 0
var leg_t := 0.0
var started := false
var route: Array = []          # [Vector3 goal (y ignored), label]
var max_drop := 0.0
var last_floor := 0.0
var last_y := 0.0
func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	var spin := Vector2(-8.3, -50.0)
	route = [
		[Vector3(0, 0, 22), "postern->rim"], [Vector3(0, 0, 4), "rift_rim"], [Vector3(0, 0, -10.5), "forecourt"],
		[Vector3(0, 0, -15.5), "gate and the first flight"], [Vector3(-0.3, 0, -21), "causeway bay 1"],
		[Vector3(-0.8, 0, -27), "causeway bay 2"], [Vector3(-1.3, 0, -33), "causeway bay 3"], [Vector3(-1.8, 0, -40), "the Pilgrims' Gate (T3)"],
		[Vector3(-1.8, 0, -49.5), "flight north to the Spindle Gate"],
	]
	for i in range(1, 25):
		var th := -TAU * float(i) / 24.0
		var q := spin + Vector2(cos(th), sin(th)) * 6.5
		route.append([Vector3(q.x, 0, q.y), "spindle %d/24" % i])
	route.append_array([[Vector3(-1.4, 0, -56), "bridge bay A"], [Vector3(-1.4, 0, -61.5), "bridge bay B"],
		[Vector3(0, 0, -66.5), "ward landing"], [Vector3(0, 0, -71.4), "landing->summit stairs"],
		[Vector3(0, 0, -77.5), "summit stairs"], [Vector3(-2.8, 0, -79.5), "round the statue"], [Vector3(-3.6, 0, -83.5), "summit deck"],
		[Vector3(-2.6, 0, -87.0), "summit deck"], [Vector3(0, 0, -89.0), "summit rear"], [Vector3(0, 0, -92.0), "onto the dais"], [Vector3(0, 0, -103.9), "dais centre"]])
	for r: Array in route:
		r[0] = Endgame.w(r[0])
func _physics_process(delta: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not started:
		if not main.has_meta("summit_dressed") or t < 200:
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
	if leg >= route.size():
		print("RIFTWALK ok end=", p.global_position.snapped(Vector3.ONE * 0.01), " biggest drop %.2f" % max_drop)
		get_tree().quit()
		return
	last_y = maxf(last_y, p.global_position.y) if leg > 3 else p.global_position.y
	if p.is_on_floor():
		max_drop = maxf(max_drop, last_floor - p.global_position.y)
		last_floor = p.global_position.y
	if p.global_position.y < -12.0 or (leg > 3 and p.global_position.y < last_y - 6.0):
		print("STUCK fell at ", p.global_position, " on leg ", leg, " ", route[leg][1])
		get_tree().quit()
		return
	var goal: Vector3 = route[leg][0]
	var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
	leg_t += delta
	if d.length() < 0.7:
		print("LEG %d %s reached (%.1f, %.1f) y=%.2f t=%.1fs" % [leg, route[leg][1], p.global_position.x, p.global_position.z, p.global_position.y, leg_t])
		leg += 1
		leg_t = 0.0
		return
	if leg_t > 16.0:
		print("STUCK leg %d %s goal=%s at %s" % [leg, route[leg][1], goal, p.global_position])
		get_tree().quit()
		return
	p.debug_drive(Vector3(d.x, 0, d.y).normalized(), false)
