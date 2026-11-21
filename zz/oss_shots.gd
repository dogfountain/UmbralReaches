extends Node
## r39 Ossuary redesign: full-size night shots of named views (the real night, through the game's grade).
##   godot --path . res://zz/oss_shots.tscn -- --out=<dir> --views=<json> [--only=a,b] [--tag=before]
## <json> is a list of {name, from: [x,y,z], to: [x,y,z], local: bool (points are Ossuary-local), fov}. A "from" with
## y < -90 stands 1.7 m over the terrain. Files: <out>/<tag>_<name>.png at 1280x720.
const WIN := Vector2i(1280, 720)

var out := ""
var tag := ""
var views_file := ""
var only: PackedStringArray = []
var main: Node
var p: Player
var cam: Camera3D
var started := false
var t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t0 = Time.get_ticks_msec()
	Travel._busy = true
	Travel.bosses_slain.clear()
	Travel.seals_broken.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--views="):
			views_file = a.trim_prefix("--views=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",", false)
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	get_window().size = WIN
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	Travel._busy = true
	var el := float(Time.get_ticks_msec() - t0) / 1000.0
	if not started and el > 400.0:
		print("OSSSHOT never got a world")
		get_tree().quit(3)
	if not started and is_instance_valid(main) and main.has_meta("realm_done"):
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p == null:
			return
		started = true
		_run.call_deferred()


func _gy(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 220.0, z + 0.0029), Vector3(x + 0.0037, -120.0, z + 0.0029), Layers.WORLD | Layers.PROPS)
	var ex: Array[RID] = []
	for i in 8:
		q.exclude = ex
		var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return 0.0


func _secs(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _run() -> void:
	await _secs(6.0)
	for n: String in ["Encounters", "RoamEvents", "WorldEvents", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if not String((c as CanvasLayer).name).begins_with("Grade"):
			(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	var gc := p.get("_cam") as Camera3D
	cam.far = gc.far if gc != null else 900.0
	cam.near = 0.05
	if gc != null:
		cam.cull_mask = gc.cull_mask
		cam.attributes = gc.attributes
		cam.environment = gc.environment
	get_tree().root.add_child(cam)
	cam.make_current()
	if "--probe" in OS.get_cmdline_user_args():
		_probe()
	if views_file == "":
		get_tree().quit()
		return
	var views: Array = JSON.parse_string(FileAccess.get_file_as_string(views_file))
	for v: Dictionary in views:
		var nm := String(v.name)
		if not only.is_empty() and not (nm in only):
			continue
		var f := _pt(v.from, bool(v.get("local", false)))
		var t := _pt(v.to, bool(v.get("local", false)))
		if f.y < -90.0:
			f.y = _gy(f.x, f.z) + 1.7
		if bool(v.get("real", false)):
			await _real_shot(v, f, t, nm)
			continue
		cam.make_current()
		p.visible = false
		cam.fov = float(v.get("fov", 75.0))
		cam.near = float(v.get("near", 0.08))                 # (an aerial inside a crown asks for more: "near": 4)
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.visible = false
		p.global_position = Vector3(f.x, f.y - 1.6, f.z)
		p.reset_physics_interpolation()
		cam.global_position = f
		cam.look_at(t, Vector3.UP)
		get_viewport().use_occlusion_culling = not bool(v.get("no_occ", false))        # A/B: "no_occ": true draws the view without occlusion culling
		await _secs(float(v.get("wait", 2.5)))
		await RenderingServer.frame_post_draw
		if bool(v.get("dump", false)):
			_dump(f, float(v.get("dump_r", 25.0)))
		var img := get_viewport().get_texture().get_image()
		var path := out.path_join("%s_%s.png" % [tag, nm])
		img.save_png(path)
		print("OSSSHOT ", path)
	print("OSSSHOTS done")
	get_tree().quit()
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: OS.kill(OS.get_process_id()))


func _pt(a: Array, local: bool) -> Vector3:
	var v := Vector3(float(a[0]), float(a[1]), float(a[2]))
	return OssFrame.w(v) if local else v


## Terrain heights (local y) on a grid in the Ossuary's frame: z rows, x columns.
func _probe() -> void:
	var xs := [-30, -20, -10, 0, 4, 10, 20, 26, 29, 30, 31, 32, 34, 36, 38, 40, 44, 50, 60]
	print("OSSPROBE x: ", xs)
	var z := -10
	while z >= -124:
		var row := PackedStringArray()
		for x: int in xs:
			var w := OssFrame.w(Vector3(x, 0, z))
			row.append("%.1f" % (_gy(w.x, w.z) - OssFrame.ORIGIN.y))
		print("OSSPROBE z=%d: %s" % [z, " ".join(row)])
		z -= 6


## "real": true: the wanderer stands at `from` (feet 1.7 m under it) and the game's own camera takes the view (a third-person
## rig, as a player sees it); the wanderer is held in place while the frames settle.
func _real_shot(v: Dictionary, f: Vector3, t: Vector3, nm: String) -> void:
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.visible = true
	var gcam := p.get("_cam") as Camera3D
	gcam.make_current()
	var d := t - f
	var end := Time.get_ticks_msec() + int(float(v.get("wait", 3.0)) * 1000.0)
	p.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()) * -1.0 * float(v.get("pitch_sign", 1.0)))
	while Time.get_ticks_msec() < end:
		p.global_position = Vector3(f.x, f.y - 1.7, f.z)
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join("%s_%s.png" % [tag, nm])
	img.save_png(path)
	print("OSSSHOT ", path)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.visible = false
	cam.make_current()


## What the prop batches (and any small mesh) near `f` look like to the renderer: range, margin, fade, layers, visibility, bounds.
func _dump(f: Vector3, rad: float) -> void:
	var n_mm := 0
	for n: Node in main.find_children("*", "MultiMeshInstance3D", true, false):
		var g := n as MultiMeshInstance3D
		var nm := String(g.name)
		if not (nm.begins_with("Candles") or nm.begins_with("Skulls") or nm.begins_with("Bones") or nm.begins_with("Flames") or nm.begins_with("Halos") or nm.begins_with("WaxPuddles")):
			continue
		var bb: AABB = g.global_transform * g.get_aabb()
		if bb.grow(rad).has_point(f):
			n_mm += 1
			var hid := ""
			var q: Node = g
			while q != null:
				if q is Node3D and not (q as Node3D).visible:
					hid = String(q.get_path())
					break
				q = q.get_parent()
			print("OSSDUMP %s pos %s d %.1f end %.1f margin %.1f begin %.1f fade %d layers %d vis_in_tree %s hidden_by '%s' n %d custom_aabb %s aabb %s cull_margin %.1f" % [g.get_path(), g.global_position.snapped(Vector3.ONE * 0.1), g.global_position.distance_to(f), g.visibility_range_end, g.visibility_range_end_margin, g.visibility_range_begin, g.visibility_range_fade_mode, g.layers, g.is_visible_in_tree(), hid, g.multimesh.instance_count, g.custom_aabb, str(AABB(bb.position.snapped(Vector3.ONE * 0.1), bb.size.snapped(Vector3.ONE * 0.1))), g.extra_cull_margin])
	print("OSSDUMP %d prop batches within %.0f m" % [n_mm, rad])
	for n: Node in main.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		var bb2: AABB = gi.global_transform * gi.get_aabb()
		if bb2.size.length() < 4.0 and bb2.get_center().distance_to(f) < 12.0 and not (n is MultiMeshInstance3D):
			print("OSSNEAR %s %s size %s at %s" % [gi.get_class(), gi.get_path(), bb2.size.snapped(Vector3.ONE * 0.1), bb2.get_center().snapped(Vector3.ONE * 0.1)])
