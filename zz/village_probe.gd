extends Node
## Village map probe (village agent's planning tool): builds the Realm, then prints an ASCII map of
## a rect: '#' collider at knee/chest height (not terrain), 'S' registered site, '=' Realm path,
## '~' water, '.' open ground (digit = ground height + 1, clamped 0-9).
##   godot --headless --path . res://zz/village_probe.tscn -- --rect=x0,z0,x1,z1 [--step=1]
## Exits with OS.kill (never writes the save).
var t := 0.0
var done := false
var rect := Rect2(-40, 0, 80, 70)
var step := 1.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rect="):
			var v := a.trim_prefix("--rect=").split(",")
			rect = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
		if a.begins_with("--step="):
			step = float(a.trim_prefix("--step="))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _built() -> bool:
	for n in get_tree().root.get_children():
		if n.has_meta("realm_done"):
			return true
	return false


func _process(d: float) -> void:
	t += d
	if done or not _built():
		if t > 90.0:
			OS.kill(OS.get_process_id())
		return
	done = true
	await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(step * 0.8, 1.2, step * 0.8)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = Layers.WORLD
	var hdr := "      "
	var x := rect.position.x
	while x <= rect.end.x:
		hdr += str(absi(int(x)) / 10 % 10) if int(x) % 10 == 0 else " "
		x += step
	print("PROBE ", hdr)
	var z := rect.position.y
	while z <= rect.end.y:
		var line := "%5d " % int(z)
		x = rect.position.x
		while x <= rect.end.x:
			var gy := RealmLayout.ground(space, x, z)
			# the walkable floor: first hit going down from 1.9 m over the terrain (plinths, floors)
			var fh := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, gy + 1.9, z), Vector3(x, gy - 1.0, z), Layers.WORLD))
			if fh:
				gy = (fh.position as Vector3).y
			var ch := str(clampi(int(gy + 1.0), 0, 9))
			q.transform = Transform3D(Basis.IDENTITY, Vector3(x, gy + 0.95, z))
			var hits := space.intersect_shape(q, 4)
			var solid := false
			for h in hits:
				var c := h.collider as Node
				if c and not String(c.name).begins_with("Terrain"):
					solid = true
			var p := Vector2(x, z)
			if solid:
				ch = "#"
			elif not WorldLanes.site_at(p).is_empty():
				ch = "S"
			elif RealmLayout.path_dist(p) < 0.0:
				ch = "="
			elif gy < -0.75:
				ch = "~"
			line += ch
			x += step
		print("PROBE ", line)
		z += step
	for s in WorldLanes.sites:
		var r: Rect2 = s.rect
		if r.intersects(rect):
			print("SITE %s %s floor %.2f" % [s.name, r, float(s.floor_y)])
	OS.kill(OS.get_process_id())
