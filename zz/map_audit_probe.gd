extends Node
## r39 MAP AUDIT probe (docs/r39/briefs/map_audit.md): the measured half of the map audit, run headless next to the
## screenshots. It builds the real night and lists, with coordinates, what a still can hint at but not measure:
##   holes      points of the playable ground with no terrain or floor under them (a ray finds nothing)
##   float      props (meshes and MultiMesh instances under 14 m) with nothing under their foot within 0.35 m
##   sunk       props wholly under the ground
##   lights     lights with no mesh or collider within 1.2 m (a light hanging in the air), shadowed lights
##   ways       the ways' line blocked at waist height by a collider (a building, a rock, a fence across the road)
##              and stretches of way under water
##   density    lights per 40 m disc over the cap (zz/lamps_test: 14)
##   godot --headless --path . res://zz/map_audit_probe.tscn -- --out=<file> [--only=holes,float,...]
## Writes a plain report (one finding a line, grouped and clustered by 12 m) to --out (default user://map_audit_probe.txt).

const LIGHT_CAP := 14
const RealmLand := preload("res://core/world/realm/realm_land.gd")
var out_path := "user://map_audit_probe.txt"
var only: Array = []
var main: Node
var p: Node3D
var t0 := 0
var started := false
var lines: PackedStringArray = []
var _vis_cells := {}                ## Vector2i(4 m cell) -> Array of AABB (every visual's world box, for the light check)


func _ready() -> void:
	t0 = Time.get_ticks_msec()
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	Travel._busy = true
	if started:
		return
	if Time.get_ticks_msec() - t0 > 400000:
		print("MAPPROBE never got a world")
		get_tree().quit(3)
		return
	if is_instance_valid(main) and main.has_meta("realm_done"):
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if p != null:
			started = true
			_run.call_deferred()


func _want(k: String) -> bool:
	return only.is_empty() or k in only


func _space() -> PhysicsDirectSpaceState3D:
	return p.get_world_3d().direct_space_state


func _ray(a: Vector3, b: Vector3, mask := Layers.WORLD | Layers.PROPS) -> Dictionary:
	return _space().intersect_ray(PhysicsRayQueryParameters3D.create(a, b, mask))


func _cname(hit: Dictionary) -> String:
	if hit.is_empty():
		return "-"
	var n := hit.collider as Node
	if n == null:
		return "?"
	var s := String(n.name)
	var par := n.get_parent()
	for i in 3:
		if par == null:
			break
		s = String(par.name) + "/" + s
		par = par.get_parent()
	return s


func _run() -> void:
	for i in 120:
		await get_tree().process_frame
	for n: String in ["Encounters", "RoamEvents", "WorldEvents", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	var tq := Time.get_ticks_msec()
	if "--sites" in OS.get_cmdline_user_args():
		_sites()
		get_tree().quit(0)
		return
	if _want("holes"):
		_holes()
	await get_tree().process_frame
	_index_visuals()
	if _want("float"):
		_props()
	await get_tree().process_frame
	if _want("lights"):
		_lights()
	if _want("ways"):
		_ways()
	print("MAPPROBE done in %.1f s, %d lines" % [float(Time.get_ticks_msec() - tq) / 1000.0, lines.size()])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	get_tree().quit(0)


## Cluster points by 12 m cells: [[centre, count, sample note]].
## --sites[=x0,z0,x1,z1]: every registered site that touches the box (name, rect or circle, floor), for placing things by hand.
func _sites() -> void:
	var box := Rect2(-370, -150, 740, 548)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--box="):
			var v := a.trim_prefix("--box=").split_floats(",")
			box = Rect2(Vector2(v[0], v[1]), Vector2(v[2] - v[0], v[3] - v[1]))
	for st: Dictionary in WorldLanes.sites:
		var r: Rect2 = st.rect
		if r.intersects(box):
			lines.append("site %s rect (%.1f,%.1f)-(%.1f,%.1f) floor %.1f%s" % [st.name, r.position.x, r.position.y, r.end.x, r.end.y, float(st.get("floor_y", 0.0)), (" circle " + str(st.circle)) if st.has("circle") else ""])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


static func _cluster(items: Array, cell := 12.0) -> Array:
	var cells := {}
	for it: Array in items:
		var q: Vector3 = it[0]
		var k := Vector2i(floori(q.x / cell), floori(q.z / cell))
		if not cells.has(k):
			cells[k] = [q, 0, String(it[1])]
		cells[k][1] += 1
	var out: Array = cells.values()
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return out


func _region(q: Vector3) -> String:
	return String(RealmLayout.region_at(q.x, q.z).get("id", "wild"))


func _holes() -> void:
	var b := RealmLayout.BOUNDS
	var found: Array = []
	var z := b.position.y + 1.0
	while z < b.end.y:
		var x := b.position.x + 1.0
		while x < b.end.x:
			var hit := _ray(Vector3(x + 0.0037, 220.0, z + 0.0029), Vector3(x + 0.0037, -140.0, z + 0.0029))
			if hit.is_empty():
				found.append([Vector3(x, RealmLand.height_at(x, z), z), "nothing under"])
			x += 2.0
		z += 2.0
	lines.append("## holes: %d points of 2 m with nothing under them" % found.size())
	for c: Array in _cluster(found):
		var q: Vector3 = c[0]
		lines.append("hole (%.0f, %.0f) %s: %d pts" % [q.x, q.z, _region(q), int(c[1])])


func _skip_name(n: Node) -> bool:
	var s := (String(n.name) + " " + String(n.get_parent().name if n.get_parent() else "")).to_lower()
	for w: String in ["glow", "flame", "halo", "glint", "mote", "spark", "fx", "smoke", "mist", "fog", "beam", "shaft", "card", "far",
			"water", "pool", "sky", "terrain", "grass", "leaf", "leaves", "canopy", "crown", "foliage", "fern", "reed", "flower",
			"moss", "ivy", "cloud", "star", "lava", "ring", "horizon", "rain", "snow", "dust", "bird", "bat", "moth", "firefl", "wisp",
			"ember", "ash", "plume", "veil", "fall", "spray", "chain", "rope", "web", "banner", "cloth", "flag", "lantern", "lamp",
			"candle", "wick", "decal", "puddle", "rut", "mark", "shadow", "light", "player", "enemy", "villager", "horse", "rig",
			"skeleton", "body", "boss", "shade", "portal", "glimmer", "shard", "crystal", "under", "ceiling", "roof", "vault", "beam"]:
		if s.contains(w):
			return true
	return false


func _index_visuals() -> void:
	for n: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		if gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.instance_count > 6000:
				continue
			var ab := mm.mesh.get_aabb()
			for i in mm.instance_count:
				_vis_add(gi.global_transform * mm.get_instance_transform(i) * ab)
		else:
			_vis_add(gi.global_transform * gi.get_aabb())


func _vis_add(bb: AABB) -> void:
	if bb.size.length() > 80.0:
		return
	var a := Vector2i(floori(bb.position.x / 4.0), floori(bb.position.z / 4.0))
	var e := Vector2i(floori(bb.end.x / 4.0), floori(bb.end.z / 4.0))
	for i in range(a.x, e.x + 1):
		for j in range(a.y, e.y + 1):
			var k := Vector2i(i, j)
			if not _vis_cells.has(k):
				_vis_cells[k] = []
			(_vis_cells[k] as Array).append(bb)


func _near_visual(q: Vector3, r: float) -> bool:
	var k := Vector2i(floori(q.x / 4.0), floori(q.z / 4.0))
	for i in range(k.x - 1, k.x + 2):
		for j in range(k.y - 1, k.y + 2):
			for bb: AABB in _vis_cells.get(Vector2i(i, j), []):
				if bb.size.length() < 0.05:
					continue
				var c := q.clamp(bb.position, bb.end)
				if c.distance_to(q) < r and not (bb.size.length() < 1.6 and bb.has_point(q)):
					return true
	return false


## A prop whose foot has nothing under it: the box's bottom centre and four inset corners each find the first surface
## below; the smallest gap counts (a prop on a slope touches at one corner).
func _foot_gap(bb: AABB) -> float:
	var best := 99.0
	var c := bb.get_center()
	var hx := bb.size.x * 0.3
	var hz := bb.size.z * 0.3
	for o: Vector2 in [Vector2.ZERO, Vector2(hx, hz), Vector2(-hx, hz), Vector2(hx, -hz), Vector2(-hx, -hz)]:
		var top := Vector3(c.x + o.x, bb.position.y + 0.05, c.z + o.y)
		var hit := _ray(top, top - Vector3(0, 4.0, 0), Layers.WORLD | Layers.PROPS)
		var g := 4.0 if hit.is_empty() else top.y - (hit.position as Vector3).y - 0.05
		var th: float = RealmLand.height_at(top.x, top.z)
		g = minf(g, maxf(bb.position.y - th, 0.0) if bb.position.y > th - 0.5 else 0.0)
		best = minf(best, g)
	return best


func _props() -> void:
	var floating: Array = []
	var sunk: Array = []
	var n_checked := 0
	for n: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree() or _skip_name(gi) or gi is GPUParticles3D or gi is CPUParticles3D:
			continue
		if gi.transparency > 0.0 or gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var boxes: Array = []
		if gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.instance_count > 3000:
				continue
			var ab := mm.mesh.get_aabb()
			for i in mm.instance_count:
				boxes.append(gi.global_transform * mm.get_instance_transform(i) * ab)
		else:
			boxes.append(gi.global_transform * gi.get_aabb())
		for bb: AABB in boxes:
			if bb.size.length() > 14.0 or bb.size.length() < 0.25:
				continue
			if not RealmLayout.BOUNDS.has_point(Vector2(bb.get_center().x, bb.get_center().z)):
				continue
			if RealmLayout.in_ossuary(bb.get_center()):
				continue
			n_checked += 1
			var th: float = RealmLand.height_at(bb.get_center().x, bb.get_center().z)
			if bb.end.y < th - 0.05 and bb.size.y > 0.3:
				sunk.append([Vector3(bb.get_center().x, bb.position.y, bb.get_center().z), "%s (%.1f m under)" % [gi.get_path(), th - bb.end.y]])
				continue
			var gap := _foot_gap(bb)
			if gap > 0.35 and gap < 3.9:
				floating.append([Vector3(bb.get_center().x, bb.position.y, bb.get_center().z), "%s gap %.2f size %.1f" % [String(gi.get_path()).right(90), gap, bb.size.length()]])
			elif gap >= 3.9:
				floating.append([Vector3(bb.get_center().x, bb.position.y, bb.get_center().z), "%s NOTHING UNDER (4 m+) size %.1f" % [String(gi.get_path()).right(90), bb.size.length()]])
	lines.append("## props checked %d; floating %d; sunk %d" % [n_checked, floating.size(), sunk.size()])
	lines.append("# floating (12 m clusters; one sample each)")
	for c: Array in _cluster(floating):
		var q: Vector3 = c[0]
		lines.append("float (%.1f, %.1f, %.1f) %s x%d: %s" % [q.x, q.y, q.z, _region(q), int(c[1]), String(c[2])])
	lines.append("# sunk")
	for c2: Array in _cluster(sunk):
		var q2: Vector3 = c2[0]
		lines.append("sunk (%.1f, %.1f, %.1f) %s x%d: %s" % [q2.x, q2.y, q2.z, _region(q2), int(c2[1]), String(c2[2])])


func _lights() -> void:
	var all: Array = []
	var shadowed := 0
	var mid_air: Array = []
	var ball := SphereShape3D.new()
	ball.radius = 1.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = Layers.WORLD | Layers.PROPS
	for n: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D or not l.is_inside_tree():
			continue
		var at := l.global_position
		if not RealmLayout.OUTER.has_point(Vector2(at.x, at.z)):
			continue
		if l.shadow_enabled:
			shadowed += 1
			lines.append("shadowed light %s at (%.1f, %.1f, %.1f)" % [l.get_path(), at.x, at.y, at.z])
		all.append(at)
		q.transform = Transform3D(Basis.IDENTITY, at)
		var touch := not _space().intersect_shape(q, 1).is_empty() or _near_visual(at, 1.2)
		if not touch:
			mid_air.append([at, "%s e %.2f r %.1f vis %s" % [String(l.get_path()).right(100), l.light_energy, l.get("omni_range") if l is OmniLight3D else 0.0, l.is_visible_in_tree()]])
	lines.append("## lights %d (shadowed %d); with nothing within 1.2 m: %d" % [all.size(), shadowed, mid_air.size()])
	for m: Array in mid_air:
		var mq: Vector3 = m[0]
		lines.append("light-in-air (%.1f, %.1f, %.1f) %s: %s (ground %.1f)" % [mq.x, mq.y, mq.z, _region(mq), String(m[1]), RealmLand.height_at(mq.x, mq.z)])
	# density: lights within any 40 m disc (centred on each light)
	var worst: Array = []
	for a: Vector3 in all:
		var k := 0
		for b: Vector3 in all:
			if Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) < 20.0:
				k += 1
		if k > LIGHT_CAP:
			worst.append([a, "%d lights in the 40 m disc" % k])
	lines.append("## light density: %d centres over %d" % [worst.size(), LIGHT_CAP])
	for c: Array in _cluster(worst, 20.0):
		var cq: Vector3 = c[0]
		lines.append("dense (%.0f, %.0f) %s: %s" % [cq.x, cq.z, _region(cq), String(c[2])])


func _ways() -> void:
	var blocked: Array = []
	var wet: Array = []
	var ball := SphereShape3D.new()
	ball.radius = 0.45
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = ball
	sq.collision_mask = Layers.WORLD | Layers.PROPS
	for w: Dictionary in RealmLayout.PATHS:
		var pts: Array = w.pts
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := maxi(int(a.distance_to(b) / 1.5), 1)
			for j in n:
				var c := a.lerp(b, float(j) / float(n))
				var hit := _ray(Vector3(c.x, 160.0, c.y), Vector3(c.x, -80.0, c.y))
				if hit.is_empty():
					continue
				var top := (hit.position as Vector3).y
				var tn := _cname(hit)
				var terr: float = RealmLand.height_at(c.x, c.y)
				if top > terr + 1.6 and not tn.to_lower().contains("bridge") and not tn.to_lower().contains("deck") and not tn.to_lower().contains("plank"):
					blocked.append([Vector3(c.x, top, c.y), "%s: a solid %.1f m over the way's ground (%s)" % [String(w.id), top - terr, tn]])
					continue
				sq.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, top + 1.0, c.y))
				for h in _space().intersect_shape(sq, 4):
					var cn := h.collider as Node
					if cn == null or String(cn.name).begins_with("Terrain"):
						continue
					blocked.append([Vector3(c.x, top, c.y), "%s: waist-high %s" % [String(w.id), _cname({"collider": cn})]])
					break
				var wl := RealmLayout.water_level_at(c.x, c.y)
				if not is_nan(wl) and wl > top + 0.25:
					wet.append([Vector3(c.x, top, c.y), "%s under %.2f m of water" % [String(w.id), wl - top]])
	lines.append("## ways: %d blocked samples, %d wet samples" % [blocked.size(), wet.size()])
	for c2: Array in _cluster(blocked, 6.0):
		var q: Vector3 = c2[0]
		lines.append("way-blocked (%.1f, %.1f) %s x%d: %s" % [q.x, q.z, _region(q), int(c2[1]), String(c2[2])])
	for c3: Array in _cluster(wet, 10.0):
		var q3: Vector3 = c3[0]
		lines.append("way-wet (%.1f, %.1f) %s x%d: %s" % [q3.x, q3.z, _region(q3), int(c3[1]), String(c3[2])])
