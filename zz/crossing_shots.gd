extends Node
## The Crossing's look-dev shots (free camera, full size): godot --path . res://zz/crossing_shots.tscn -- --realm --realm-modules=land,rift
##   --shots=<json>  [{"n": name, "p": [x,y,z], "t": [x,y,z], "fov": 70}, ...] in the Crossing's own coordinates (chasm on x 0:
##                   Endgame.O is added); an optional "eye": true puts the camera 1.7 m over the ground under p (a ray down)
##   --out=<dir>     where the PNGs go (default res://shots)
##   --probe         prints the chasm's walls (x of the terrain per z and height)
##   --grid=<path>   writes the terrain and built heights on a 1 m grid over the rift as JSON
##   a view's "lava_debug": true draws the lava's cooling, open lava and rafts as colour (lava.gdshader debug_view)
## Waits for the realm and the lava's second bank map, then shoots each view and quits.
var main: Node
var cam: Camera3D
var views: Array = []
var out := "res://shots"
var t := 0.0
var i := -1
var t_next := 0.0
var _ready_t := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			views = JSON.parse_string(FileAccess.get_file_as_string(a.trim_prefix("--shots=")))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if main == null or not main.has_meta("realm_done"):
		return
	if _ready_t < 0.0:
		_ready_t = t
		return
	if t < _ready_t + 14.0:
		return
	if cam == null:
		for n in get_tree().get_nodes_in_group(Groups.ENEMY):
			(n as Node).queue_free()
		if "--probe" in OS.get_cmdline_user_args():
			_probe()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--grid="):
				_grid(a.trim_prefix("--grid="))
		if "--hud" not in OS.get_cmdline_user_args():
			for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = false
		cam = Camera3D.new()
		cam.far = 500.0
		get_tree().root.add_child(cam)
		cam.current = true
		_next()
		return
	if t < t_next:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [out, views[i]["n"]]))
	print("SHOT ", views[i]["n"], " ", img.get_size())
	_next()


func _v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2]) + Endgame.O


func _next() -> void:
	i += 1
	if i >= views.size():
		print("SHOTS done")
		get_tree().quit()
		return
	var v: Dictionary = views[i]
	var p := _v3(v["p"])
	if v.get("eye", false):
		var space := (main as Node3D).get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 40.0, Layers.WORLD))
		if not hit.is_empty():
			p.y = (hit.position as Vector3).y + 1.7
	var lw := get_tree().get_first_node_in_group(&"lava_works")
	if lw != null and lw.get("_mat") is ShaderMaterial:
		(lw.get("_mat") as ShaderMaterial).set_shader_parameter("debug_view", 1 if v.get("lava_debug", false) else 0)
	cam.fov = float(v.get("fov", 70.0))
	cam.global_position = p
	cam.look_at(_v3(v["t"]))
	t_next = t + 0.9


## The chasm's walls: x of the first terrain hit going out from the middle (west / east), per z and height.
func _probe() -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	# terrain heights (terrain bodies only) on a grid round the forecourt and the south rim
	for z in range(6, -22, -2):
		var row := "gz %4d |" % z
		for x in range(-24, 25, 4):
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(Endgame.O.x + x, 40.0, z), Vector3(Endgame.O.x + x, -30.0, z), Layers.WORLD))
			var name := String((hit.collider as Node).name).substr(0, 1) if not hit.is_empty() else "-"
			row += " %6.1f%s" % [(hit.position as Vector3).y if not hit.is_empty() else 99.0, name]
		print("PROBE ", row)
	for z in range(-8, -126, -6):
		var line := "z %4d |" % z
		for y in [-12, -6, 0, 4, 8, 12, 16, 20, 25, 30]:
			var cell := ""
			for side in [-1.0, 1.0]:
				var from := Vector3(Endgame.O.x + side * 3.0, float(y), float(z))
				var res := "  -- "
				for k in 6:
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(Endgame.O.x + side * 60.0, float(y), float(z)), Layers.WORLD))
					if hit.is_empty():
						break
					if String((hit.collider as Node).name).begins_with("Terrain"):
						res = "%5.1f" % ((hit.position as Vector3).x - Endgame.O.x)
						break
					from = (hit.position as Vector3) + Vector3(side * 0.2, 0.0, 0.0)
				cell += res
			line += " y%d:%s" % [y, cell]
		print("PROBE ", line)


## Terrain and built heights on a 1 m grid over the rift (rift coordinates), as JSON: {"x0", "z0", "nx", "nz", "ground": [...], "top": [...]}
## (ground: the first Terrain hit from above, passing through anything built; top: the first WORLD hit of any kind; -99 = none).
func _grid(path: String) -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var x0 := -44
	var z0 := 8
	var nx := 89
	var nz := 141
	var ground := PackedFloat32Array()
	var top := PackedFloat32Array()
	for j in nz:
		for i in nx:
			var x := Endgame.O.x + float(x0 + i)
			var z := float(z0 - j)
			var from := Vector3(x, 70.0, z)
			var g := -99.0
			var tp := -99.0
			for k in 8:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(x, -30.0, z), Layers.WORLD))
				if hit.is_empty():
					break
				var y := (hit.position as Vector3).y
				if tp < -98.0:
					tp = y
				if String((hit.collider as Node).name).begins_with("Terrain"):
					g = y
					break
				from = Vector3(x, y - 0.05, z)
			ground.append(g)
			top.append(tp)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"x0": x0, "z0": z0, "nx": nx, "nz": nz, "ground": Array(ground), "top": Array(top)}))
	f.close()
	print("GRID written ", path)
