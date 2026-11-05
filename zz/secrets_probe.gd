extends Node
## Secrets agent: a top-down map of the built Realm for choosing secret sites, plus point probes.
##   godot --headless --path . res://zz/secrets_probe.tscn [-- --map] [--pts=x,z;x,z...] [--box=x0,z0,x1,z1]
## --map writes shots/secrets_map.png (2 px per m over BOUNDS, or --box): hillshade by height,
## structures red, tree trunks green, paths white, sites yellow, interactables cyan, water blue.
var main: Node
var t := 0
var done := false


func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	t += 1
	if done or main == null or not main.has_meta("realm_done"):
		if t > 60 * 150:
			print("PROBE timeout")
			get_tree().quit()
		return
	done = true
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	var args := OS.get_cmdline_user_args()
	var box := RealmLayout.BOUNDS
	for a in args:
		if a.begins_with("--box="):
			var v := a.trim_prefix("--box=").split(",")
			box = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
	if "--map" in args:
		_map(box)
	for a in args:
		if a.begins_with("--pts="):
			for s in a.trim_prefix("--pts=").split(";"):
				var v := s.split(",")
				_probe(Vector2(float(v[0]), float(v[1])))
	for a in args:
		if a.begins_with("--grid="):
			var v := a.trim_prefix("--grid=").split(",")
			var space := (main as Node3D).get_world_3d().direct_space_state
			var stp := float(v[4])
			var hdr := "GRID   z\\x "
			var x := float(v[0])
			while x <= float(v[2]) + 0.01:
				hdr += "%6.0f" % x
				x += stp
			print(hdr)
			var z := float(v[1])
			while z <= float(v[3]) + 0.01:
				var row := "GRID %7.1f " % z
				x = float(v[0])
				while x <= float(v[2]) + 0.01:
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 120, z + 0.0029), Vector3(x, -60, z), 1))
					var s := "   -- "
					if hit:
						var nm := String((hit.collider as Node).name)
						s = "%5.1f%s" % [(hit.position as Vector3).y, " " if nm.begins_with("Terrain") else nm.substr(0, 1).to_lower()]
					row += s
					x += stp
				print(row)
				z += stp
	if "--sites" in args:
		for s in WorldLanes.sites:
			print("SITE ", s.name, " ", s.rect, " floor ", s.floor_y)
	print("PROBE done")
	get_tree().quit()


func _probe(p: Vector2) -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 120, p.y), Vector3(p.x, -60, p.y), 1))
	var what := "none"
	var y := NAN
	if hit:
		what = String((hit.collider as Node).name)
		y = (hit.position as Vector3).y
	var reg := RealmLayout.region_at(p.x, p.y)
	var site := WorldLanes.site_at(p, 1.0)
	var near_tree := INF
	var RF: GDScript = load("res://core/world/realm/realm_flora.gd")
	for tr: Array in RF.get("trees"):
		var b: Vector3 = tr[0]
		near_tree = minf(near_tree, Vector2(b.x, b.z).distance_to(p))
	var slope := 0.0
	var ys := []
	for o: Vector2 in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
		ys.append(RealmLayout.ground(space, p.x + o.x, p.y + o.y))
	slope = maxf(absf(float(ys[0]) - float(ys[1])), absf(float(ys[2]) - float(ys[3]))) / 3.0
	print("PT %s y=%.2f hit=%s region=%s path_d=%.1f site=%s tree_d=%.1f slope=%.2f ground=%.2f" % [p, y, what, reg.get("id", "?"), RealmLayout.path_dist(p), site.get("name", "-"), near_tree, slope, RealmLayout.ground(space, p.x, p.y)])


func _map(box: Rect2) -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var ppm := 2.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ppm="):
			ppm = float(a.trim_prefix("--ppm="))
	var names := {}
	var w := int(box.size.x * ppm)
	var h := int(box.size.y * ppm)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var hs := PackedFloat32Array()
	hs.resize(w * h)
	var kinds := PackedByteArray()
	kinds.resize(w * h)
	for j in h:
		for i in w:
			var x := box.position.x + (float(i) + 0.5) / ppm
			var z := box.position.y + (float(j) + 0.5) / ppm
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 120, z + 0.0029), Vector3(x, -60, z), 1))
			var y := -20.0
			var k := 0
			if hit:
				y = (hit.position as Vector3).y
				var nm := String((hit.collider as Node).name)
				k = 1 if nm.begins_with("Terrain") else 2
				names[nm] = int(names.get(nm, 0)) + 1
			hs[j * w + i] = y
			kinds[j * w + i] = k
	for j in h:
		for i in w:
			var y := hs[j * w + i]
			var yl := hs[j * w + maxi(i - 1, 0)]
			var yu := hs[maxi(j - 1, 0) * w + i]
			var shade := clampf(0.55 + (y - yl) * 0.6 + (y - yu) * 0.6, 0.1, 1.0)
			var base := clampf((y + 18.0) / 50.0, 0.0, 1.0)
			var c := Color(0.25 + base * 0.6, 0.25 + base * 0.55, 0.25 + base * 0.4) * shade
			if y < RealmLayout.LAVA_Y + 0.5:
				c = Color(0.6, 0.15, 0.05)
			elif (load("res://core/world/realm/realm_land.gd") as GDScript).call("in_water", box.position.x + (float(i) + 0.5) / ppm, box.position.y + (float(j) + 0.5) / ppm):
				c = Color(0.1, 0.2, 0.5)
			if kinds[j * w + i] == 2:
				c = c.lerp(Color(0.9, 0.2, 0.2), 0.6)
			# contour every 2 m
			if int(floor(y / 2.0)) != int(floor(yl / 2.0)) or int(floor(y / 2.0)) != int(floor(yu / 2.0)):
				c = c.darkened(0.35)
			img.set_pixel(i, j, c)
	var px := func(p: Vector2) -> Vector2i:
		return Vector2i(int((p.x - box.position.x) * ppm), int((p.y - box.position.y) * ppm))
	var dot := func(p: Vector2, r: int, c: Color) -> void:
		var q: Vector2i = px.call(p)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r and q.x + dx >= 0 and q.y + dy >= 0 and q.x + dx < w and q.y + dy < h:
					img.set_pixel(q.x + dx, q.y + dy, c)
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var n := int(a.distance_to(b) * ppm)
			for s in n:
				dot.call(a.lerp(b, float(s) / float(maxi(n, 1))), 1, Color(1, 1, 1))
	for s in WorldLanes.sites:
		var r: Rect2 = s.rect
		var n2 := int(r.size.x * ppm)
		for s2 in n2:
			dot.call(Vector2(r.position.x + float(s2) / ppm, r.position.y), 0, Color(1, 0.9, 0.1))
			dot.call(Vector2(r.position.x + float(s2) / ppm, r.end.y), 0, Color(1, 0.9, 0.1))
		var n3 := int(r.size.y * ppm)
		for s3 in n3:
			dot.call(Vector2(r.position.x, r.position.y + float(s3) / ppm), 0, Color(1, 0.9, 0.1))
			dot.call(Vector2(r.end.x, r.position.y + float(s3) / ppm), 0, Color(1, 0.9, 0.1))
	var RF: GDScript = load("res://core/world/realm/realm_flora.gd")
	for tr: Array in RF.get("trees"):
		var b: Vector3 = tr[0]
		dot.call(Vector2(b.x, b.z), 1, Color(0.1, 0.8, 0.2))
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		var g := (n as Node3D).global_position
		dot.call(Vector2(g.x, g.z), 1, Color(0.2, 0.9, 1.0))
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		dot.call(Vector2(c.at.x, c.at.z), 3, Color(1.0, 0.2, 1.0))
	for n in main.find_children("*", "Brazier", true, false):
		var g := (n as Node3D).global_position
		dot.call(Vector2(g.x, g.z), 3, Color(1.0, 0.6, 0.1))
	# 10 m grid ticks
	for gx in range(int(ceil(box.position.x / 10.0)) * 10, int(box.end.x), 10):
		for gz in range(int(ceil(box.position.y / 10.0)) * 10, int(box.end.y), 10):
			dot.call(Vector2(gx, gz), 0, Color(0, 0, 0) if (gx % 50 != 0 or gz % 50 != 0) else Color(1, 0, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var tag := "map"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	img.save_png(ProjectSettings.globalize_path("res://shots/secrets_%s.png" % tag))
	print("HITS ", names)
	print("MAP saved ", w, "x", h, " box ", box)
