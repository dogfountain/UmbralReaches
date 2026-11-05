extends Node
## Traversal in the real Realm. Without arguments: runs the traversal checks on real geometry
## (each a teleport + a short scripted drive), prints "TRAV <name> ok|FAIL ..." and "TRAV DONE pass=N fail=M".
## With --at=x,y,z --to=x,z [--sprint] [--secs=6]: drives from there and traces every tick (debug).
##   godot --headless --path . res://zz/trav_realm.tscn -- --realm [--only=name] [--at=.. --to=..]
## Never writes the save (Travel._busy).
var p: Player
var main: Node
var t := 0.0
var frames := 0
var started := false
var trace := false
var at := Vector3.ZERO
var to := Vector2.ZERO
var sprint := false
var secs := 6.0
var only := ""
var scan := false
var checks: Array = []          ## [name, Callable(setup) , Callable(tick) -> String ("" running, "ok ...", "FAIL ...")]
var ci := -1
var ct := 0.0
var st := {}
var passed := 0
var failed := 0


func _ready() -> void:
	Travel._busy = true
	process_physics_priority = -10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var v := a.trim_prefix("--at=").split(",")
			at = Vector3(float(v[0]), float(v[1]), float(v[2]))
			trace = true
		elif a.begins_with("--to="):
			var v := a.trim_prefix("--to=").split(",")
			to = Vector2(float(v[0]), float(v[1]))
		elif a == "--sprint":
			sprint = true
		elif a.begins_with("--secs="):
			secs = float(a.trim_prefix("--secs="))
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a == "--scan":
			scan = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(delta: float) -> void:
	Travel._busy = true
	frames += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not started:
		if not main.has_meta("summit_dressed") or frames < 200:
			return
		started = true
		for w in main.find_children("*", "", true, false):
			if w is WardSeal:
				(w as WardSeal).release()
		if scan:
			_scan()
			get_tree().quit()
			return
		if trace:
			p.teleport(at)
			var dd := Vector3(to.x - at.x, 0, to.y - at.z).normalized()
			for h in [0.3, 1.0, 1.8]:
				var hit := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * h, at + Vector3.UP * h + dd * 4.0, 0xFFFF, [p.get_rid()]))
				if not hit.is_empty():
					var c := hit.collider as Node
					print("  ahead h=%.1f: %s at %s layer %d (%s)" % [h, c.get_path() if c else "?", (hit.position as Vector3).snapped(Vector3.ONE * 0.01), (c as CollisionObject3D).collision_layer if c is CollisionObject3D else -1, c.get_script().resource_path if c and c.get_script() else ""])
		else:
			_build_checks()
			_next()
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	p.gloom = 0.0
	t += delta
	if trace:
		var d := Vector2(to.x - p.global_position.x, to.y - p.global_position.z)
		p.debug_drive(Vector3(d.x, 0, d.y).normalized() if d.length() > 0.5 else Vector3.ZERO, sprint)
		print("  t=%.2f pos=%s v=%s floor=%s ground=%s wall=%s beam=%.2f steep=%.2f vault=%.2f hang=%s roll=%.2f" % [t, p.global_position.snapped(Vector3.ONE * 0.01), p.velocity.snapped(Vector3.ONE * 0.01), p.is_on_floor(), p.is_grounded(), p.is_on_wall(), p._beam_k, p._steep_k, p._vault_t, p._hang, p._roll_t])
		if t > secs:
			get_tree().quit()
		return
	if ci >= checks.size():
		return
	ct += delta
	var r: String = (checks[ci][2] as Callable).call(delta)
	if r != "":
		print("TRAV %-12s %s" % [checks[ci][0], r])
		if r.begins_with("ok"):
			passed += 1
		else:
			failed += 1
		_next()


func _next() -> void:
	p.debug_drive(Vector3.ZERO)
	for a in ["jump", "slide", "dodge"]:
		Input.action_release(a)
	ci += 1
	while ci < checks.size() and only != "" and checks[ci][0] != only:
		ci += 1
	if ci >= checks.size():
		print("TRAV DONE pass=%d fail=%d" % [passed, failed])
		get_tree().quit()
		return
	ct = 0.0
	st = {}
	(checks[ci][1] as Callable).call()


func _ground(x: float, z: float) -> float:
	var space := p.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -30, z), Layers.WORLD))
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


func _drive_to(x: float, z: float, run := false) -> float:
	var d := Vector2(x - p.global_position.x, z - p.global_position.z)
	p.debug_drive(Vector3(d.x, 0, d.y).normalized() if d.length() > 0.3 else Vector3.ZERO, run)
	return d.length()


## --scan: walk a 2 m grid over the walkable Realm and list real spots for each move: a thin
## wall 0.5-1.25 m with ground beyond (vault), a face 1.2-2.2 m high with room on top (ledge
## grab + climb), a face over 3 m (wall kick).
func _scan() -> void:
	var found := _spots(Vector2.ZERO, 112.0)
	for k: String in found:
		var a: Array = found[k]
		print("SCAN %s: %d spots" % [k, a.size()])
		for i in mini(a.size(), 12):
			var e: Array = a[i * maxi(1, a.size() / 12)]
			print("  %s dir %s rise %.2f %s" % [(e[0] as Vector3).snapped(Vector3.ONE * 0.1), (e[1] as Vector3).snapped(Vector3.ONE * 0.01), e[2], e[3]])


## Spots for each move on a 2 m grid within `radius` of `c`: {kind: [[ground point, dir, rise, owner]]}.
func _spots(c: Vector2, radius: float) -> Dictionary:
	var space := p.get_world_3d().direct_space_state
	var found := {"vault": [], "grab": [], "kick": []}
	var dirs: Array[Vector3] = []
	for k in 8:
		dirs.append(Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)))
	var r := int(radius)
	for gx in range(int(c.x) - r, int(c.x) + r + 1, 2):
		for gz in range(int(c.y) - r, int(c.y) + r + 1, 2):
			if absf(gx) > 92 or absf(gz) > 112:
				continue
			var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(gx, 60, gz), Vector3(gx, -30, gz), Layers.WORLD))
			if g.is_empty() or (g.normal as Vector3).y < 0.85:
				continue
			var y0: float = (g.position as Vector3).y
			var o := Vector3(gx, y0, gz)
			for d in dirs:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3.UP * 0.35, o + Vector3.UP * 0.35 + d * 1.2, Layers.WORLD))
				if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.3:
					continue
				var face: Vector3 = hit.position
				var over := face + d * 0.12
				var top_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(over.x, y0 + 6.0, over.z), Vector3(over.x, y0 + 0.3, over.z), Layers.WORLD))
				var owner_name := String((hit.collider as Node).get_path()).get_slice("/", 3) if hit.collider else "?"
				if top_hit.is_empty():
					var tall := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3.UP * 3.0, o + Vector3.UP * 3.0 + d * 1.6, Layers.WORLD))
					var mid := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3.UP * 1.65, o + Vector3.UP * 1.65 + d * 1.6, Layers.WORLD))
					if not tall.is_empty() and not mid.is_empty():
						(found["kick"] as Array).append([o, d, 6.0, owner_name])
					continue
				var rise: float = (top_hit.position as Vector3).y - y0
				var deep := space.intersect_ray(PhysicsRayQueryParameters3D.create(over + d * 0.6 + Vector3.UP * (rise + 0.3), over + d * 0.6 + Vector3.UP * (rise - 0.25), Layers.WORLD))
				if rise >= 0.55 and rise <= 1.2 and deep.is_empty():
					var land := space.intersect_ray(PhysicsRayQueryParameters3D.create(over + d * 1.6 + Vector3.UP * (rise + 0.3), over + d * 1.6 + Vector3.UP * (rise - 2.4), Layers.WORLD))
					if not land.is_empty():
						(found["vault"] as Array).append([o, d, rise, owner_name])
				elif rise >= 1.25 and rise <= 2.15 and p._fits((top_hit.position as Vector3) + d * 0.2 + Vector3.UP * 0.05):
					(found["grab"] as Array).append([o, d, rise, owner_name])     # (and room to stand up there)
	return found


## A run-up for `kind` near `hint`: [start (4 m back along the approach), the spot, dir] or [].
func _approach(kind: String, hint: Vector2, back := 4.0) -> Array:
	var space := p.get_world_3d().direct_space_state
	for e: Array in _spots(hint, 8.0)[kind]:
		var o: Vector3 = e[0]
		var d: Vector3 = e[1]
		var s0 := o - d * back
		var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(s0 + Vector3.UP * 3.0, s0 + Vector3.DOWN * 3.0, Layers.WORLD))
		if g.is_empty() or absf((g.position as Vector3).y - o.y) > 0.4:
			continue
		# a clear run-up at body height
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(s0 + Vector3.UP * 1.0, o + Vector3.UP * 1.0, Layers.WORLD)).is_empty():
			continue
		return [(g.position as Vector3) + Vector3.UP * 0.05, o, d, e[3]]
	return []


## Real places in the Realm (found with this tool's --at/--to trace and zz/trav_probe-style rays).
func _build_checks() -> void:
	# the spawn road: plain running must not trip any of the new states (beam, steep, vault)
	checks.append(["road_run", func() -> void:
		p.teleport(Vector3(0, _ground(0, 26.5) + 0.1, 26.5)),
		func(_d: float) -> String:
			_drive_to(0.0, 4.0, true)
			if p._beam_k > 0.5 or p._steep_k > 0.5 or p._vault_t >= 0.0 or p.is_hanging():
				return "FAIL false trigger at %s beam %.2f steep %.2f" % [p.global_position, p._beam_k, p._steep_k]
			if p.global_position.z < 5.0:
				return "ok reached the rim in %.1fs" % ct
			return "FAIL slow: at %s" % p.global_position if ct > 8.0 else ""])
	# vault: a low carved wall or stone by the west way, at a sprint
	checks.append(["vault", func() -> void:
		st["a"] = _approach("vault", Vector2(-22, 10))
		if not (st["a"] as Array).is_empty():
			p.teleport(st["a"][0])
			p.set_view(atan2(-(st["a"][2] as Vector3).x, -(st["a"][2] as Vector3).z), -0.2),
		func(_d: float) -> String:
			var a: Array = st["a"]
			if a.is_empty():
				return "FAIL no vault spot found near (-22, 10)"
			p.debug_drive(a[2], true)
			if p._vault_t >= 0.0:
				st["v"] = true
			var past := ((p.global_position - (a[1] as Vector3)) as Vector3).dot(a[2]) > 1.6
			if st.has("v") and past and p.is_grounded():
				return "ok over %s, speed %.1f" % [a[3], Vector2(p.velocity.x, p.velocity.z).length()]
			return ("FAIL no vault at %s (%s)" % [a[1], a[3]]) if ct > 3.5 else ""])
	# ledge grab and climb: a 1.3-2.1 m face with room on top (Crossing towers, lore stones)
	checks.append(["grab", func() -> void:
		st["a"] = []
		for hint: Vector2 in [Vector2(-20, 12), Vector2(-32, 30), Vector2(2, -20), Vector2(-14, -28), Vector2(-64, 40)]:
			st["a"] = _approach("grab", hint, 3.0)
			if not (st["a"] as Array).is_empty():
				break
		if not (st["a"] as Array).is_empty():
			p.teleport(st["a"][0])
			p.set_view(atan2(-(st["a"][2] as Vector3).x, -(st["a"][2] as Vector3).z), -0.2),
		func(_d: float) -> String:
			var a: Array = st["a"]
			if a.is_empty():
				return "FAIL no grab spot found"
			p.debug_drive(a[2])
			var o: Vector3 = a[1]
			var to_face := ((o - p.global_position) as Vector3).dot(a[2])
			if not st.has("j") and to_face < 1.0:
				Input.action_press("jump")
				st["j"] = ct
			elif st.has("j") and ct - float(st["j"]) > 0.3:
				Input.action_release("jump")
			if p.is_hanging():
				st["h"] = true
			if st.has("h") and p.is_grounded() and p.global_position.y > o.y + 1.1:
				return "ok hung and climbed onto %s (+%.2f m)" % [a[3], p.global_position.y - o.y]
			return ("FAIL at %s hung=%s (%s)" % [p.global_position.snapped(Vector3.ONE * 0.01), st.has("h"), a[3]]) if ct > 5.0 else ""])
	# wall kick off a Crossing tower
	checks.append(["kick", func() -> void:
		st["a"] = []
		for hint: Vector2 in [Vector2(-4, -14), Vector2(-13, -30), Vector2(-1.8, -40), Vector2(4, -18), Vector2(-8, -50)]:
			st["a"] = _approach("kick", hint, 2.5)
			if not (st["a"] as Array).is_empty():
				break
		if not (st["a"] as Array).is_empty():
			p.teleport(st["a"][0])
			p.set_view(atan2(-(st["a"][2] as Vector3).x, -(st["a"][2] as Vector3).z), -0.2),
		func(_d: float) -> String:
			var a: Array = st["a"]
			if a.is_empty():
				return "FAIL no kick wall found"
			var d: Vector3 = a[2]
			if not st.has("k"):
				p.debug_drive(d)
			if not st.has("j") and ct > 0.2:
				Input.action_press("jump")
				st["j"] = ct
			elif st.has("j") and not st.has("r") and ct - float(st["j"]) > 0.25:
				Input.action_release("jump")
				st["r"] = ct
			elif st.has("r") and not st.has("k") and not p.is_grounded() and p._wall_t > 0.0:
				Input.action_press("jump")
				st["k"] = ct
				st["why"] = "can=%s coyote=%.2f steep=%.2f wall_n=%s kick_n=%s pos=%s" % [p._can_wallkick(d), p._coyote, p._steep_t, p._wall_n, p._kick_n, p.global_position.snapped(Vector3.ONE * 0.01)]
			elif st.has("k") and not st.has("o") and ct - float(st["k"]) > 0.07:
				Input.action_release("jump")
				st["o"] = Vector2(Vector3(p.velocity.x, 0, p.velocity.z).dot(p._kick_n), p.velocity.y)   # out along the kicked wall's normal
			if st.has("k") and not st.has("o") and OS.get_cmdline_user_args().has("--dbg"):
				print("   tick ct=%.3f v=%s air_jumps=%d kick_n=%s wall_t=%.2f ground=%s pressed=%s" % [ct, p.velocity.snapped(Vector3.ONE * 0.01), p._air_jumps_left, p._kick_n, p._wall_t, p.is_grounded(), Input.is_action_pressed("jump")])
			if st.has("o"):
				var o: Vector2 = st["o"]
				return ("ok kicked off %s out %.1f up %.1f" if o.x > 2.5 and o.y > 3.5 else "FAIL weak kick off %s out %.1f up %.1f " + String(st.get("why", ""))) % [a[3], o.x, o.y]
			return "FAIL never touched the wall" if ct > 3.0 else ""])
	# the Crossing's parapets (1.0 m over the lava): at a sprint you must NOT vault them
	checks.append(["parapet", func() -> void:
		p.teleport(Vector3(0, _ground(0, -10.5) + 0.1, -10.5)),
		func(_d: float) -> String:
			_drive_to(8.0, -10.5, true)
			if p._vault_t >= 0.0:
				return "FAIL vaulted a parapet over the lava"
			if p.global_position.y < -2.0:
				return "FAIL fell"
			return "ok held by the parapet at x=%.2f" % p.global_position.x if ct > 2.5 else ""])
