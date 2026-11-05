extends Node
## Realm route walks (bosses module): drives the real Player along the walked network.
##   godot --headless --path . res://zz/realm_walks.tscn -- --realm [--realm-modules=land,rift,bosses]
## Routes (each starts from a teleport, so one failure does not hide the next):
##   henge   spawn -> west_way -> the henge stair foot -> up the pilgrim stair -> through the gate
##   henge_stair  the same stair alone, from just below its foot
##   barrows spawn -> east_way -> the Barrow Field -> fen_descent -> the Ossuary's fen door
##   crypt   the fen door's threshold -> up the stair in the cut -> the gallery door -> the gallery
## Prints "LEG ..." per waypoint, "STUCK route leg ..." on a failure, and "REALMWALK ok" / "REALMWALK FAIL n".
var p: Player
var main: Node
var t := 0
var routes: Array = []
var ri := 0
var leg := 0
var leg_t := 0.0
var fails := 0
var started := false


func _ready() -> void:
	# a ground walk, not a fight: in memory only (saves held), every boss slain and seal broken, so the
	# henge's arena gate does not drop behind the walker on a fresh save
	Travel._busy = true
	for id: String in ["bone_abbot", "thornwarden", "ascended_warden"]:
		Travel.bosses_slain[id] = true
	for id: String in ["henge", "oss_gallery", "summit"]:
		Travel.seals_broken[id] = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _pts(a: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: Vector2 in a:
		out.append(Vector3(v.x, 0, v.y))
	return out


func _path(id: String) -> Array:
	for path: Dictionary in RealmLayout.PATHS:
		if path.id == id:
			return path.pts
	return []


func _build_routes() -> void:
	var henge: Array[Vector3] = _pts(_path("west_way").slice(0, 4))
	henge.append(Vector3(RealmLayout.HENGE_STAIR_FOOT.x, 0, RealmLayout.HENGE_STAIR_FOOT.y))
	for v: Vector3 in ThornHenge.stair_pts:
		henge.append(v)
	var stair: Array[Vector3] = []
	for v: Vector3 in ThornHenge.stair_pts:
		stair.append(v)
	var f3: Vector3 = ThornHenge.stair_pts[0]
	var away := Vector3(f3.x - ThornHenge.stair_pts[3].x, 0, f3.z - ThornHenge.stair_pts[3].z).normalized()
	var barrows: Array[Vector3] = [Vector3(12.0, 0, 18.0)]      # round the tavern porch
	barrows.append_array(_pts(_path("east_way")))
	barrows.append_array(_pts(_path("fen_descent").slice(1)))
	barrows.append(Vector3(Ossuary.FEN_X + 1.0, 0, Ossuary.FEN_GATE.z))
	var crypt: Array[Vector3] = [Vector3(Ossuary.FEN_X + 1.0, 0, Ossuary.FEN_GATE.z), Vector3(Ossuary.FEN_X, 0, Ossuary.FEN_FOOT_Z + 0.4),
		Vector3(Ossuary.FEN_X, 0, Ossuary.FEN_HEAD_Z + 0.6), Vector3(28.6, 0, Ossuary.FEN_DOOR_Z), Vector3(24.6, 0, Ossuary.FEN_DOOR_Z), Vector3(23.4, 0, -62.0)]
	routes = [
		{"name": "henge", "from": RealmLayout.PLAYER_START, "pts": henge, "end_y": ThornHenge.C.y},
		{"name": "henge_stair", "from": f3 + away * 2.5 + Vector3.UP * 1.5, "pts": stair, "end_y": ThornHenge.C.y},
		{"name": "barrows", "from": RealmLayout.PLAYER_START, "pts": barrows, "end_y": Ossuary.FEN_GATE.y},
		{"name": "crypt", "from": Vector3(Ossuary.fen_out - 0.8, Ossuary.FEN_GATE.y + 0.3, Ossuary.FEN_GATE.z), "pts": crypt, "end_y": Ossuary.GAL_Y},
	]


func _start_route() -> void:
	var r: Dictionary = routes[ri]
	p.global_position = r.from
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	leg = 0
	leg_t = 0.0
	print("ROUTE ", r.name, " from ", r.from, " (", (r.pts as Array).size(), " legs)")


func _next_route(ok: bool) -> void:
	var r: Dictionary = routes[ri]
	if ok:
		var dy := absf(p.global_position.y - float(r.end_y))
		print("ROUTE %s done, end %s (expected y %.2f, off %.2f)" % [r.name, p.global_position.snapped(Vector3.ONE * 0.01), r.end_y, dy])
		if dy > 0.8:
			fails += 1
			print("STUCK %s: ended at the wrong height" % r.name)
	else:
		fails += 1
	p.debug_drive(Vector3.ZERO)
	ri += 1
	if ri >= routes.size():
		print("REALMWALK ok" if fails == 0 else "REALMWALK FAIL %d" % fails)
		get_tree().quit()
		return
	_start_route()


func _physics_process(delta: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if t % 30 == 0:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()             # the walk is about the ground, not the fights
	if not started:
		if not main.has_meta("summit_dressed") or ThornHenge.stair_pts.is_empty() or main.find_child("FenGate", true, false) == null:
			if t > 60 * 120:
				print("REALMWALK FAIL realm not ready (henge %s, fen gate %s)" % [not ThornHenge.stair_pts.is_empty(), main.find_child("FenGate", true, false) != null])
				get_tree().quit()
			return
		started = true
		# the walk is about the ground: open the ward seals, so it passes on any save (a fresh save
		# has the henge sealed and the walker stopped at its gate)
		for w in main.find_children("*", "", true, false):
			if w is WardSeal:
				(w as WardSeal).release()
		_build_routes()
		_start_route()
		return
	var r: Dictionary = routes[ri]
	var pts: Array = r.pts
	if leg >= pts.size():
		_next_route(true)
		return
	var goal: Vector3 = pts[leg]
	var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z)
	leg_t += delta
	if d.length() < 0.7:
		print("LEG %s %d reached %s in %.1fs y=%.2f" % [r.name, leg, Vector2(goal.x, goal.z), leg_t, p.global_position.y])
		leg += 1
		leg_t = 0.0
		return
	var prev: Vector3 = pts[leg - 1] if leg > 0 else (r.from as Vector3)
	if leg_t > 6.0 + Vector2(goal.x - prev.x, goal.z - prev.z).length() / 2.0:
		print("STUCK %s leg %d goal=%s at %s" % [r.name, leg, Vector2(goal.x, goal.z), p.global_position.snapped(Vector3.ONE * 0.01)])
		_next_route(false)
		return
	p.debug_drive(Vector3(d.x, 0, d.y).normalized(), true)
