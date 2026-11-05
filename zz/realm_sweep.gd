extends Node
## Drops the wanderer on a grid across the whole Realm and checks every point for getting stuck or
## falling through. At each point: a ray from high above finds the top walkable surface (layers
## WORLD | PROPS), the player is placed on it and settles, then drives a short way in 4 directions.
##   FELL   settled more than 1.2 m under the surface it was dropped on (a collision hole)
##   STUCK  could move under 0.25 m in all 4 directions (a pocket / invisible wall box)
##   VOID   no surface at all under an in-bounds point (falls out of the world)
##   OUT    a drive left the Realm's bounds (+2 m) or fell below the kill height
## Prints "SWEEP <kind> x,z ..." per problem and "SWEEP DONE points=N fell=a stuck=b void=c out=d".
##   HOME=<scratch> godot --headless --path . res://zz/realm_sweep.tscn -- [--step=8] [--only=x0,z0,x1,z1] [--deep] [--cap=s]
## --deep tests every walkable layer of each column (bridges, the Ossuary's floors, the Lower Count).
## Never writes the save (Travel._busy); enemies are removed; quits itself (real-time cap 900 s, --cap=secs).
const LEG_TICKS := 16
const SETTLE_TICKS := 8
var main: Node
var p: Player
var frames := 0
var started := false
var step := 8.0
var rect := Rect2(-110.0, -150.0, 220.0, 230.0)
var pts: Array[Vector2] = []
var pi := -1
var phase := 0                 ## 0 settle, 1..4 legs
var tick := 0
var drop := Vector3.ZERO
var leg_start := Vector3.ZERO
var moved: Array[float] = []
var n_fell := 0
var n_stuck := 0
var n_void := 0
var n_out := 0
var n_ok := 0
var t0 := 0
var cap_ms := 900000
var deep := false
var _queue: Array[Vector3] = []
var n_drops := 0
const DIRS := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]


func _ready() -> void:
	Travel._busy = true
	t0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--step="):
			step = maxf(2.0, float(a.trim_prefix("--step=")))
		elif a == "--deep":
			deep = true
		elif a.begins_with("--cap="):
			cap_ms = int(float(a.trim_prefix("--cap=")) * 1000.0)
		elif a.begins_with("--only="):
			var v := a.trim_prefix("--only=").split(",")
			if v.size() == 4:
				rect = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
	var x := rect.position.x + step * 0.5
	while x < rect.end.x:
		var z := rect.position.y + step * 0.5
		while z < rect.end.y:
			pts.append(Vector2(x, z))
			z += step
		x += step
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if Time.get_ticks_msec() - t0 > cap_ms:
		print("SWEEP TIMEOUT at point %d of %d" % [pi, pts.size()])
		_finish()


func _physics_process(_delta: float) -> void:
	Travel._busy = true
	frames += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not started:
		if not main.has_meta("realm_done") or frames < 120:
			return
		started = true
		Engine.max_physics_steps_per_frame = 16
		Engine.time_scale = 4.0
		for w in main.find_children("*", "", true, false):
			if w is WardSeal:
				(w as WardSeal).release()
		_next_point()
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	p.gloom = 0.0
	tick += 1
	if phase == 0:
		if tick < SETTLE_TICKS:
			return
		# under the surface where it stands now (a slide down a steep slope is not a fall-through)
		var here := _top(Vector2(p.global_position.x, p.global_position.z))
		if p.global_position.y < drop.y - 1.2 and (here.is_empty() or p.global_position.y < (here.position as Vector3).y - 1.0):
			n_fell += 1
			print("SWEEP FELL %.0f,%.0f dropped y %.2f now %s (%s)" % [drop.x, drop.z, drop.y, p.global_position.snapped(Vector3.ONE * 0.01), _under(p.global_position)])
			_next_point()
			return
		phase = 1
		_start_leg()
		return
	if tick < LEG_TICKS:
		return
	var pos := p.global_position
	var b := RealmLayout.BOUNDS.grow(2.0)
	if not b.has_point(Vector2(pos.x, pos.z)) or pos.y < -38.0:
		n_out += 1
		print("SWEEP OUT %.0f,%.0f leg %d ended at %s" % [drop.x, drop.z, phase, pos.snapped(Vector3.ONE * 0.1)])
		_next_point()
		return
	moved.append(Vector2(pos.x - leg_start.x, pos.z - leg_start.z).length())
	if phase < 4:
		phase += 1
		p.teleport(drop)
		_start_leg()
		return
	if moved.max() < 0.25:
		n_stuck += 1
		print("SWEEP STUCK %.0f,%.0f y %.2f moved %s (%s)" % [drop.x, drop.z, drop.y, str(moved.map(func(m: float) -> float: return snappedf(m, 0.01))), _under(drop)])
	else:
		n_ok += 1
	_next_point()


func _start_leg() -> void:
	tick = 0
	leg_start = p.global_position
	p.debug_drive(DIRS[phase - 1], false)


func _next_point() -> void:
	p.debug_drive(Vector3.ZERO, false)
	while _queue.is_empty():
		pi += 1
		if pi >= pts.size():
			_finish()
			return
		var xz := pts[pi]
		var hit := _top(xz)
		if hit.is_empty():
			if RealmLayout.BOUNDS.has_point(xz):
				n_void += 1
				print("SWEEP VOID %.0f,%.0f no surface under it" % [xz.x, xz.y])
			continue
		for h: Dictionary in (_layers(xz) if deep else [hit]):
			var c := h.collider as Node
			# open water and lava are not walkable ground: skip (lava throws the player back by design)
			if c and (c.is_in_group(&"lava") or String(c.name).to_lower().contains("lava")):
				continue
			if (h.normal as Vector3).y < 0.5:
				continue
			_queue.append((h.position as Vector3) + Vector3.UP * 0.15)
	drop = _queue.pop_front()
	n_drops += 1
	phase = 0
	tick = 0
	moved.clear()
	p.teleport(drop)


## --deep: every surface down the column with 1.9 m of headroom (bridge decks and what is under
## them, the Ossuary's tiers, the Lower Count), not just the top one.
func _layers(xz: Vector2) -> Array:
	var out: Array = []
	var space := p.get_world_3d().direct_space_state
	var from := Vector3(xz.x, 90.0, xz.y)
	var excl: Array[RID] = [p.get_rid()]
	var last_y := 999.0
	for _i in 10:
		var q := PhysicsRayQueryParameters3D.create(from, Vector3(xz.x, -60.0, xz.y), Layers.WORLD | Layers.PROPS, excl)
		q.hit_back_faces = false
		var h := space.intersect_ray(q)
		if h.is_empty():
			break
		var y := (h.position as Vector3).y
		from = Vector3(xz.x, y - 0.05, xz.y)
		if (h.normal as Vector3).y > 0.5 and last_y - y > 1.9:
			out.append(h)
		last_y = y
	return out


func _top(xz: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 90.0, xz.y), Vector3(xz.x, -60.0, xz.y), Layers.WORLD | Layers.PROPS, [p.get_rid()])
	return p.get_world_3d().direct_space_state.intersect_ray(q)


func _under(at: Vector3) -> String:
	var hit := _top(Vector2(at.x, at.z))
	if hit.is_empty():
		return "nothing"
	var c := hit.collider as Node
	return "%s @%.2f" % [c.get_path() if c else "?", (hit.position as Vector3).y]


func _finish() -> void:
	set_physics_process(false)
	set_process(false)
	Engine.time_scale = 1.0
	print("SWEEP DONE points=%d drops=%d ok=%d fell=%d stuck=%d void=%d out=%d in %.0f s" % [pts.size(), n_drops, n_ok, n_fell, n_stuck, n_void, n_out, (Time.get_ticks_msec() - t0) * 0.001])
	get_tree().quit()
