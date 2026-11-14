extends Node
## Map survey of one rect of the Realm: a placement probe and stills, in one launch.
##   godot --path . res://zz/map_survey.tscn -- --name=<region> --rect=x0,z0,x1,z1
##       [--step=40] [--closeups=30] [--no-grid] [--no-probe] [--views="n@ax,ay,az@lx,ly,lz;..."] [--dark]
## Waits for the whole Realm (realm_done, after the terrain settle) plus SETTLE seconds, then:
##   probe   every visible mesh and multimesh instance in the rect is tested for support: one of its lowest
##           vertices within --touch (0.3 m) of the terrain or of a collider under it, or its base resting in the box of
##           a supported thing (a roof on its walls). FLOAT = a group of things nothing holds up. SUNK = a
##           thing mostly under the terrain. BODY = a rig (person, creature) whose origin is off the ground.
##   stills  a close-up of each finding (survey light on), and over a grid of the rect an aerial view (survey
##           light on) and two eye-level views in the game's own night look.
##   --views / --views-file=<path> add free views; --spots-file=<path> (name x,y,z size) two close-ups of each spot
##   --find=a,b: two close-ups of every mesh node whose name (or its parent's) contains a or b, and a spots-file
##   line for each in the report (the same views again after a change).
##   --who="x,z,r;..." lists the mesh nodes near a point (path, mesh, size, triangles).
##   (survey light on unless --dark). A y of "g1.7" in a view or spot is 1.7 m above the terrain there.
## Writes shots/survey/<name>/report.txt and *.jpg (*.png with --png). Never writes the save (Travel._busy; exits by OS.kill).
const Footing := preload("res://core/world/footing.gd")
const SETTLE := 10.0
var touch := 0.3                   ## a base vertex this near a surface stands on it (--touch=)
var settled_only := false          ## --settled-only: only things over ground the settle pass lowered
var probe_only := false            ## --probe-only: no stills (runs headless)
const SUNK_SHARE := 0.75           ## of a thing's height under the terrain
const BODY_GAP := 0.35
const SHOT_FRAMES := 16
const FX_WORDS := ["flame", "glow", "flare", "beam", "smoke", "mist", "fog", "haze", "ember", "spark", "water",
	"river", "lake", "lava", "sky", "cloud", "horizon", "canopy", "halo", "shaft", "wisp", "mote", "aura", "trail",
	"decal", "glint", "glimmer", "firefly", "moth", "bird", "corona", "_far"]

var nm := "region"
var rect := Rect2(-40, 0, 80, 80)
var step := 40.0
var max_close := 30
var do_grid := true
var do_probe := true
var dark := false
var png := false                   ## --png: lossless stills (*.png) instead of jpg
var views: Array = []
var spots: Array = []              ## [name, centre, size]
var who: Array[Vector3] = []       ## (x, radius, z)
var finds := PackedStringArray()
var main: Node
var t := 0.0
var done_t := -1.0
var cam: Camera3D
var lamp: DirectionalLight3D
var space: PhysicsDirectSpaceState3D
var dir := ""
var shots: Array = []              ## [file, cam pos, look at, light on]
var si := 0
var wait := 0
var report := PackedStringArray()
var stale := 0
var _last_hash := 0
var items: Array = []              ## probe items (Dictionary)
var _own := {}                     ## parent Node -> Array[RID] of its colliders


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"--no-grid": do_grid = false
			"--no-probe": do_probe = false
			"--dark": dark = true
			"--png": png = true
			"--settled-only": settled_only = true
			"--probe-only": probe_only = true
		if kv.size() < 2:
			continue
		match kv[0]:
			"--name": nm = kv[1]
			"--find":                        # a,b: two close-ups of every mesh node whose name (or parent's) contains a or b
				finds = kv[1].split(",", false)
			"--who":                         # x,z,r;...: name every mesh node whose box centre is within r of (x, z)
				for w in kv[1].split(";", false):
					var q := w.split(",")
					who.append(Vector3(float(q[0]), float(q[2]), float(q[1])))
			"--touch": touch = float(kv[1])
			"--step": step = float(kv[1])
			"--closeups": max_close = int(kv[1])
			"--rect":
				var v := kv[1].split(",")
				rect = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
			"--views-file":                  # one view a line: name ax,ay,az lx,ly,lz  (# comments)
				for ln in FileAccess.get_file_as_string(kv[1]).split("\n", false):
					var w := ln.strip_edges().split(" ", false)
					if w.size() >= 3 and not ln.begins_with("#"):
						views.append([w[0], _v3(w[1]), _v3(w[2])])
			"--spots-file":                  # one spot a line: name x,y,z size  -> two close-ups from clear sides
				for ln in FileAccess.get_file_as_string(kv[1]).split("\n", false):
					var w := ln.strip_edges().split(" ", false)
					if w.size() >= 3 and not ln.begins_with("#"):
						spots.append([w[0], _v3(w[1]), float(w[2])])
			"--views":
				for s in kv[1].split(";", false):
					var p := s.split("@")
					views.append([p[0], _v3(p[1]), _v3(p[2])])
	dir = ProjectSettings.globalize_path("res://shots/survey/" + nm)
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1600, 1000)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _v3(s: String) -> Vector3:
	var p := s.split(",")
	if p[1].begins_with("g"):                # "g1.7": that far above the terrain there (resolved by _gy once the world is built)
		return Vector3(float(p[0]), 10000.0 + float(p[1].substr(1)), float(p[2]))
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _gy(v: Vector3) -> Vector3:
	return Vector3(v.x, _terrain(v.x, v.z) + v.y - 10000.0, v.z) if v.y > 5000.0 else v


func _process(d: float) -> void:
	t += d
	if t > 600.0:
		print("SURVEY FAIL timed out")
		OS.kill(OS.get_process_id())
	if cam == null:
		if not main.has_meta("realm_done"):
			return
		if done_t < 0.0:
			done_t = t
		if t - done_t < SETTLE:
			return
		_begin()
		return
	if si >= shots.size():
		_finish()
		return
	var s: Array = shots[si]
	if wait == 0:
		cam.global_position = s[1]
		cam.look_at(s[2])
		lamp.visible = s[3]
		wait = SHOT_FRAMES
		return
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)          # macOS stops drawing a covered window: every still was the same frame
	wait -= 1
	if wait == 0:
		var img := get_viewport().get_texture().get_image()
		var h := hash(img.get_data())
		if h == _last_hash and si > 0 and (shots[si - 1][1] as Vector3).distance_to(s[1]) > 0.5:
			stale += 1
			print("SURVEY STALE %s: the same frame as the still before it" % s[0])
		_last_hash = h
		if png:
			img.save_png("%s/%s.png" % [dir, s[0]])
		else:
			img.save_jpg("%s/%s.jpg" % [dir, s[0]], 0.9)
		si += 1


func _begin() -> void:
	space = (main as Node3D).get_world_3d().direct_space_state if main is Node3D else get_tree().root.get_world_3d().direct_space_state
	report.append("SURVEY %s rect x %.0f..%.0f z %.0f..%.0f" % [nm, rect.position.x, rect.end.x, rect.position.y, rect.end.y])
	if do_probe:
		_probe()
	for w in who:
		_who(Vector2(w.x, w.z), w.y)
	if probe_only:
		cam = Camera3D.new()
		add_child(cam)
		_finish()
		return
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 420.0
	get_tree().root.add_child(cam)
	cam.current = true
	lamp = DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-58.0, 35.0, 0.0)
	lamp.light_energy = 1.1
	lamp.shadow_enabled = true
	lamp.directional_shadow_max_distance = 90.0
	get_tree().root.add_child(lamp)
	for v: Array in views:
		shots.append(["view_" + String(v[0]), _gy(v[1]), _gy(v[2]), not dark])
	for sp: Array in spots:
		var c: Vector3 = _gy(sp[1])
		var half := Vector3.ONE * float(sp[2]) * 0.5
		_closeup("spot_%s_a" % sp[0], AABB(c - half, half * 2.0), 0)
		_closeup("spot_%s_b" % sp[0], AABB(c - half, half * 2.0), 1)
	var nfound := 0
	for n in main.find_children("*", "MeshInstance3D", true, false) if not finds.is_empty() else []:
		var mi := n as MeshInstance3D
		var nm2 := String(mi.name) + "|" + String(mi.get_parent().name)
		for f in finds:
			if nm2.contains(f) and mi.mesh != null and nfound < 40:
				var bx := mi.global_transform * mi.mesh.get_aabb()
				var c2 := bx.get_center()
				var tag2 := "%s_%d" % [f.to_lower().replace("_", ""), nfound]
				report.append("FOUND %s  %s  spot: %s %.1f,%.1f,%.1f %.1f" % [_path(mi), bx.size.snapped(Vector3.ONE * 0.1), tag2, c2.x, c2.y, c2.z, maxf(bx.get_longest_axis_size(), 1.0)])
				_closeup("spot_%s_a" % tag2, bx, 0)
				_closeup("spot_%s_b" % tag2, bx, 1)
				nfound += 1
				break
	if do_grid:
		var z := rect.position.y + step * 0.5
		while z < rect.end.y:
			var x := rect.position.x + step * 0.5
			while x < rect.end.x:
				var g := _terrain(x, z)
				var tag := "%+04d_%+04d" % [roundi(x), roundi(z)]
				shots.append(["air_" + tag, Vector3(x, g + 15.0, z + 19.0), Vector3(x, g, z - 3.0), true])
				var e := _walk_y(x, z) + 1.7
				shots.append(["eye_%s_n" % tag, Vector3(x, e, z), Vector3(x, e - 0.25, z - 10.0), false])
				shots.append(["eye_%s_s" % tag, Vector3(x, e, z), Vector3(x + 2.0, e - 0.25, z + 10.0), false])
				x += step
			z += step
	print("SURVEY %s: %d stills" % [nm, shots.size()])


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var fa := FileAccess.open(dir + "/report.txt", FileAccess.WRITE)
	if fa != null:                              # a missing folder must not keep the window open for ever
		fa.store_string("\n".join(report) + "\n")
		fa.close()
	print("\n".join(report))
	print("SURVEY DONE %s -> %s (%d stills, %d stale)" % [nm, dir, shots.size(), stale])
	OS.kill(OS.get_process_id())


## What stands near a point: the node path, mesh and size of every visible mesh within `r` (which builder made the box?).
func _who(at: Vector2, r: float) -> void:
	report.append("WHO %.0f,%.0f r %.0f" % [at.x, at.y, r])
	for n in main.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or _fx(g):
			continue
		var m: Mesh = (g as MeshInstance3D).mesh if g is MeshInstance3D else ((g as MultiMeshInstance3D).multimesh.mesh if g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null else null)
		if m == null:
			continue
		var xfs: Array[Transform3D] = [g.global_transform]
		if g is MultiMeshInstance3D:
			xfs.clear()
			var mm := (g as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				xfs.append(g.global_transform * mm.get_instance_transform(i))
		var hits := 0
		var first := AABB()
		for xf in xfs:
			var b := xf * m.get_aabb()
			var c := b.get_center()
			if Vector2(c.x, c.z).distance_to(at) <= r and b.get_longest_axis_size() < 60.0:
				if hits == 0:
					first = b
				hits += 1
		if hits > 0:
			var tris := m.get_faces().size() / 3
			report.append("  %s  x%d  %s  at %s size %s  %d tris" % [_path(g), hits, _mesh_name(m), first.get_center().snapped(Vector3.ONE * 0.1), first.size.snapped(Vector3.ONE * 0.1), tris])


# --- the probe ---------------------------------------------------------------------------------

func _terrain(x: float, z: float) -> float:
	return Footing.terrain_y(space, x, z, 0.0)


## The top walkable surface at (x, z): a floor or deck where there is one, else the terrain.
func _walk_y(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 120.0, z), Vector3(x, -60.0, z), 1)
	var hit := space.intersect_ray(q)
	return (hit.position as Vector3).y if hit else _terrain(x, z)


func _fx(n: Node) -> bool:
	var s := String(n.name).to_lower()
	var par := n.get_parent()
	if par != null:
		s += " " + String(par.name).to_lower()
	for w: String in FX_WORDS:
		if s.contains(w):
			return true
	return false


func _in_rig(n: Node) -> bool:
	var a := n.get_parent()
	while a != null and a != main:
		if a is Skeleton3D or a is CharacterBody3D:
			return true
		a = a.get_parent()
	return false


func _path(n: Node) -> String:
	var parts := PackedStringArray()
	var a := n
	while a != null and a != main and parts.size() < 5:
		parts.insert(0, String(a.name))
		a = a.get_parent()
	return "/".join(parts)


func _mesh_name(m: Mesh) -> String:
	if m.resource_path != "":
		return m.resource_path.get_file()
	return m.resource_name if m.resource_name != "" else m.get_class()


func _excludes(n: Node) -> Array[RID]:
	var par := n.get_parent()
	if par == null:
		return []
	if _own.has(par):
		return _own[par]
	var out: Array[RID] = []
	for c in par.find_children("*", "CollisionObject3D", true, false):
		out.append((c as CollisionObject3D).get_rid())
		if out.size() > 64:
			out.clear()                      # a big container, not one prop: only the thing's own children
			for c2 in n.find_children("*", "CollisionObject3D", true, false):
				out.append((c2 as CollisionObject3D).get_rid())
			return out
	if par is CollisionObject3D:
		out.append((par as CollisionObject3D).get_rid())
	_own[par] = out
	return out


func _add(owner_node: Node, mesh: Mesh, xf: Transform3D, ex: Array[RID]) -> void:
	var box := xf * mesh.get_aabb()
	var c := box.get_center()
	if not rect.has_point(Vector2(c.x, c.z)):
		return
	var big := maxf(box.size.x, box.size.z)
	if big > 45.0:
		return
	var tiny := box.get_longest_axis_size() < 0.25        # holds things up, is not itself reported
	var pts := Footing.base_points(mesh)
	var stride := maxi(1, pts.size() / 16)
	var gap := INF
	var i := 0
	while i < pts.size():
		var w := xf * pts[i]
		var tg := w.y - _terrain(w.x, w.z)
		var q := PhysicsRayQueryParameters3D.create(w + Vector3.UP * 0.5, w + Vector3.DOWN * 40.0, 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		var sg := w.y - (hit.position as Vector3).y if hit else INF
		gap = minf(gap, maxf(0.0, minf(tg, sg)))      # a base vertex in the ground (tg < 0) stands on it
		i += stride
	var ty := _terrain(c.x, c.z)
	var under := (ty - box.position.y) / maxf(box.size.y, 0.01)
	items.append({"box": box, "gap": gap, "ok": gap <= touch, "under": under, "path": _path(owner_node), "mesh": _mesh_name(mesh),
		"tiny": tiny, "settle": TerrainStamp.settle_delta_at(c.x, c.z)})


func _probe() -> void:
	var t0 := Time.get_ticks_msec()
	for n in main.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or _fx(g) or _in_rig(g):
			continue
		if g is MeshInstance3D:
			var mi := g as MeshInstance3D
			if mi.mesh == null or mi.skin != null:
				continue
			_add(mi, mi.mesh, mi.global_transform, _excludes(mi))
		elif g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.mesh.get_aabb().size.y < 0.45:
				continue
			var gx := g.global_transform
			var none: Array[RID] = []
			var count := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			for i in count:
				_add(g, mm.mesh, gx * mm.get_instance_transform(i), none)
	# what rests on what: a thing's base slab inside a supported thing's box is held up by it
	var cells := {}
	for i in items.size():
		var b: AABB = items[i].box
		for cx in range(floori(b.position.x / 6.0), floori(b.end.x / 6.0) + 1):
			for cz in range(floori(b.position.z / 6.0), floori(b.end.z / 6.0) + 1):
				var k := Vector2i(cx, cz)
				if not cells.has(k):
					cells[k] = PackedInt32Array()
				(cells[k] as PackedInt32Array).append(i)
	var changed := true
	var rounds := 0
	while changed and rounds < 12:
		changed = false
		rounds += 1
		for i in items.size():
			if items[i].ok:
				continue
			var b: AABB = items[i].box
			var slab := AABB(b.position - Vector3(0.1, 0.15, 0.1), Vector3(b.size.x + 0.2, minf(b.size.y, 0.3) + 0.15, b.size.z + 0.2))
			var held := false
			for cx in range(floori(b.position.x / 6.0), floori(b.end.x / 6.0) + 1):
				for cz in range(floori(b.position.z / 6.0), floori(b.end.z / 6.0) + 1):
					for j: int in cells[Vector2i(cx, cz)]:
						if j != i and items[j].ok and slab.intersects(items[j].box):
							held = true
							break
					if held:
						break
				if held:
					break
			if held:
				items[i].ok = true
				changed = true
	var floats: Array = []
	var sunk: Array = []
	for it: Dictionary in items:
		if bool(it.tiny) or String(it.path).ends_with("_c") or String(it.path).ends_with("_fc"):
			continue                             # a tree's crown hangs on its trunk
		if settled_only and float(it.settle) > -0.04:
			continue
		if not it.ok:
			floats.append(it)
		elif float(it.under) > SUNK_SHARE and (it.box as AABB).size.y > 0.4 and not RealmLayout.in_ossuary((it.box as AABB).get_center()):
			sunk.append(it)
	var bodies := _bodies()
	report.append("PROBE %d things tested in %d ms: %d FLOAT, %d SUNK, %d BODY" % [items.size(), Time.get_ticks_msec() - t0, floats.size(), sunk.size(), bodies.size()])
	_emit("FLOAT", floats)
	_emit("SUNK", sunk)
	_emit("BODY", bodies)


## Rigs (people, creatures): the skeleton's origin against the surface under it.
func _bodies() -> Array:
	var out: Array = []
	for n in main.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		if not sk.is_visible_in_tree():
			continue
		var p := sk.global_position
		if not rect.has_point(Vector2(p.x, p.z)):
			continue
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 40.0, 1)
		var hit := space.intersect_ray(q)
		var gap := p.y - (hit.position as Vector3).y if hit else 99.0
		if absf(gap) > BODY_GAP:
			out.append({"box": AABB(p - Vector3(0.5, 0, 0.5), Vector3(1, 1.8, 1)), "gap": gap, "under": 0.0, "path": _path(sk), "mesh": "rig"})
	return out


## Findings of one kind, grouped by what made them (owner name + mesh), the worst of each group first.
func _emit(kind: String, list: Array) -> void:
	var groups := {}
	for it: Dictionary in list:
		var owner_name := String(it.path).get_slice("/", maxi(0, String(it.path).get_slice_count("/") - 2))
		var k := "%s | %s" % [owner_name.rstrip("0123456789_"), it.mesh]
		if not groups.has(k):
			groups[k] = []
		(groups[k] as Array).append(it)
	var keys := groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return (groups[a] as Array).size() > (groups[b] as Array).size())
	var closeups := 0
	for k: String in keys:
		var g: Array = groups[k]
		g.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return absf(float(a.gap)) > absf(float(b.gap)) if kind != "SUNK" else float(a.under) > float(b.under))
		report.append("%s x%d  [%s]" % [kind, g.size(), k])
		for i in mini(g.size(), 4):
			var it: Dictionary = g[i]
			var b: AABB = it.box
			var c := b.get_center()
			var line := "    at (%.1f, %.1f, %.1f) size %.1fx%.1fx%.1f gap %.2f under %.0f%% settled %.2f node %s" % [c.x, b.position.y, c.z, b.size.x, b.size.y, b.size.z, float(it.gap), float(it.under) * 100.0, float(it.get("settle", 0.0)), it.path]
			if i < 2 and closeups < max_close / 3 + (max_close / 3 if kind == "FLOAT" else 0):
				var file := "%s_%02d" % [kind.to_lower(), closeups]
				closeups += 1
				_closeup(file, b)
				line += "  still " + file + (".png" if png else ".jpg")
			report.append(line)


func _closeup(file: String, b: AABB, rank := 0) -> void:
	var c := b.get_center()
	var dist := clampf(b.get_longest_axis_size() * 2.4, 3.5, 34.0)
	var cands: Array = []                    # [free share, camera]
	for k in 8:
		var ang := TAU * float(k) / 8.0 + 0.4
		var from := c + Vector3(cos(ang), 0.42, sin(ang)).normalized() * dist
		from.y = maxf(from.y, _terrain(from.x, from.z) + 1.0)       # never from under the ground (the land has no underside)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, c, 1))
		cands.append([from.distance_to(hit.position as Vector3) / dist if hit else 1.0, from])
	cands.sort_custom(func(a: Array, bb: Array) -> bool: return float(a[0]) > float(bb[0]))
	var best: Vector3 = cands[0][1]
	if rank > 0:                             # the clearest view from another side (a quarter turn or more away)
		for cd: Array in cands:
			var v: Vector3 = cd[1]
			if Vector2(v.x - c.x, v.z - c.z).normalized().dot(Vector2(best.x - c.x, best.z - c.z).normalized()) < 0.1:
				best = v
				break
	shots.append([file, best, c, not dark])
