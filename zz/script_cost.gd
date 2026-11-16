extends Node
## Headless per-script CPU cost (deterministic enough to A/B on a loaded machine, unlike --blame's
## paired frame windows): at each view, every processing script node's _process / _physics_process
## is called REPS times in a row with a 60 Hz delta and timed; per script, the median of ROUNDS
## rounds is printed in us per frame (all its nodes together). The calls run the real code, so the
## world moves on a little faster during the probe; the numbers are cost, not behaviour.
##   godot --headless --path . res://zz/script_cost.tscn [-- --only=spawn,fen --top=25 --build-only]
## (--build-only: quit once the Realm is built; its REALM_PROF lines are the build profile)
const REPS := 12
const ROUNDS := 5
var points := [
	["spawn", Vector3(0.0, NAN, 30.0)],
	["fen", Vector3(70.0, NAN, -20.0)],
	["village", Vector3(8.0, NAN, 48.0)],
	["summit", Vector3(0.0, 27.9, -92.0)],
	["fight", Vector3(62.0, NAN, 60.0)],          # the fight bench's spot
	["lastlight", Vector3(314.0, NAN, 64.0)],     # the Far Reaches: a town, its people, the east road
	["reedholm", Vector3(-316.0, NAN, 300.0)],
	["marches", Vector3(-160.0, NAN, 20.0)],
]
const CAL_REF := 150.0      # us the calibration loop takes on an idle M4 Pro (so 1 cu ~ 1 us there)
var main: Node
var p: Player
var top := 30
var detail := PackedStringArray()   ## --detail=villager.gd,lamp.gd: per node of these scripts, its cost and distance


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			var keep := a.trim_prefix("--only=").split(",")
			points = points.filter(func(e: Array) -> bool: return e[0] in keep)
		elif a.begins_with("--top="):
			top = int(a.trim_prefix("--top="))
		elif a.begins_with("--detail="):
			detail = a.trim_prefix("--detail=").split(",")
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	while not main.has_meta("realm_done"):
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--meshes="):
			for nm in a.trim_prefix("--meshes=").split(","):
				_mesh_census(nm)
	if "--build-only" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	await _secs(4.0)
	var grand := 0.0
	for pt: Array in points:
		var at: Vector3 = pt[1]
		if is_nan(at.y):
			at.y = RealmLayout.ground(p.get_world_3d().direct_space_state, at.x, at.z) + 0.15
		p.global_position = at
		p.velocity = Vector3.ZERO
		await _secs(2.5)
		_monitors(String(pt[0]))
		grand += _measure(String(pt[0]))
	print("COST total over views %.1f us" % grand)
	get_tree().quit()


## --meshes=A,B: the visible geometry under each top-level node named A, B: instances, surfaces
## (draws when all in view), by material, with their visibility range and shadow mode.
func _mesh_census(nm: String) -> void:
	var host := main.find_child(nm, true, false)
	if host == null:
		print("MESHES %s: not found" % nm)
		return
	var rows := {}
	var names := {}
	var n := 0
	var surf := 0
	for g in host.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var m: Mesh = null
		if gi is MeshInstance3D:
			m = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
			m = (gi as MultiMeshInstance3D).multimesh.mesh
		if m == null:
			continue
		n += 1
		for si in m.get_surface_count():
			surf += 1
			var mat: Material = gi.material_override
			if mat == null and gi is MeshInstance3D:
				mat = (gi as MeshInstance3D).get_active_material(si)
			elif mat == null:
				mat = m.surface_get_material(si)
			var key := "%s %s vis %.0f sh %d" % [gi.get_class(), mat.resource_path.get_file() if mat and mat.resource_path != "" else str(mat.get_instance_id() if mat else 0), gi.visibility_range_end, gi.cast_shadow]
			rows[key] = int(rows.get(key, 0)) + 1
			if not names.has(key):
				names[key] = str(host.get_path_to(gi))
	print("MESHES %s: %d instances, %d surfaces" % [nm, n, surf])
	var keys := rows.keys()
	keys.sort_custom(func(x: String, y: String) -> bool: return int(rows[x]) > int(rows[y]))
	for k: String in keys:
		print("MESHES   %4d  %s  e.g. %s" % [rows[k], k, names[k]])


## The engine's own process and physics times (scripts plus what the engine does round them) over 60
## frames at the view, with the processing nodes counted: the whole CPU the night asks of a frame.
func _monitors(label: String) -> void:
	var pr := 0.0
	var ph := 0.0
	for i in 60:
		await get_tree().process_frame
		pr += Performance.get_monitor(Performance.TIME_PROCESS)
		ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var idle := 0
	var phys := 0
	for nd in get_tree().root.find_children("*", "", true, false):
		if nd.can_process():
			idle += int(nd.is_processing())
			phys += int(nd.is_physics_processing())
	print("COST view %s: process %.2f ms, physics %.2f ms (monitors, mean of 60 frames), %d nodes, %d processing, %d physics-processing, %d bodies" % [label,
		pr / 60.0 * 1000.0, ph / 60.0 * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), idle, phys,
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])


func _cal() -> float:
	var best := INF
	for r in 3:
		var t0 := Time.get_ticks_usec()
		var v := Vector3.ONE
		var b := Basis()
		for k in 6000:
			v = b * v + Vector3(0.001, 0.0, 0.0)
			b = b.rotated(Vector3.UP, 0.0001)
		best = minf(best, float(Time.get_ticks_usec() - t0) + v.x * 0.0)
	return best


func _measure(label: String) -> float:
	var dt := 1.0 / 60.0
	var nodes: Array[Node] = []
	for n in get_tree().root.find_children("*", "", true, false):
		if n == self or n.get_script() == null:
			continue
		if n.can_process() and (n.is_processing() or n.is_physics_processing()):
			nodes.append(n)
	var per := {}          # script -> Array of round totals (us per frame)
	var count := {}
	var each := {}         # node -> Array of round costs (cu), for the --detail scripts
	for r in ROUNDS:
		var sums := {}
		var cal := _cal()
		for n in nodes:
			if not is_instance_valid(n) or not n.is_inside_tree() or not n.can_process():
				continue
			var key := (n.get_script() as Script).resource_path.get_file()
			if key == "":
				key = "inner:" + String(n.name).rstrip("0123456789@")
			if r == 0:
				count[key] = int(count.get(key, 0)) + 1
			var t0 := Time.get_ticks_usec()
			for k in REPS:
				if n.is_processing() and n.has_method(&"_process"):
					n.call(&"_process", dt)
				if n.is_physics_processing() and n.has_method(&"_physics_process"):
					n.call(&"_physics_process", dt)
			var us := float(Time.get_ticks_usec() - t0) / float(REPS)
			sums[key] = float(sums.get(key, 0.0)) + us
			if key in detail:
				if not each.has(n):
					each[n] = []
				(each[n] as Array).append(us * CAL_REF / maxf(cal, 1.0))
		# normalised to a fixed calibration loop timed in the same round: the machine is shared,
		# and its speed swings 2x between runs; "cu" (calibrated us) compares across runs
		var cal2 := _cal()
		var k_norm := CAL_REF / ((cal + cal2) * 0.5)
		for key: String in sums:
			sums[key] = float(sums[key]) * k_norm
		for key: String in sums:
			if not per.has(key):
				per[key] = []
			(per[key] as Array).append(float(sums[key]))
	var rows := []
	var total := 0.0
	for key: String in per:
		var a: Array = per[key]
		a.sort()
		var med := float(a[a.size() / 2])
		total += med
		rows.append([med, key])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	print("COST view %s: %.1f cu/frame over %d nodes" % [label, total, nodes.size()])
	for k in mini(top, rows.size()):
		print("COST   %-10s %8.1f cu  %-32s x%d" % [label, rows[k][0], rows[k][1], int(count.get(rows[k][1], 0))])
	if not each.is_empty():
		var cam := get_viewport().get_camera_3d()
		var drows := []
		for n: Node in each:
			if not is_instance_valid(n):
				continue
			var a: Array = each[n]
			a.sort()
			var d := cam.global_position.distance_to((n as Node3D).global_position) if cam != null and n is Node3D else -1.0
			drows.append([float(a[a.size() / 2]), (n.get_script() as Script).resource_path.get_file(), String(n.name), d])
		drows.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
		for dr: Array in drows.slice(0, 40):
			print("COST   %-10s detail %7.1f cu  %-20s %-28s %6.0f m" % [label, dr[0], dr[1], dr[2], dr[3]])
	return total
