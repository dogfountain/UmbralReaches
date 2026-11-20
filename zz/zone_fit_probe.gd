extends Node
## r39 ZONE FIT probe (docs/r39/briefs/zone_fit.md): measures every JOIN of the built Realm and prints the gap, worst first.
##   stairs   every flight OssKit built (OssKit.record): its foot against the ground before it, its head against the floor past it
##   portals  every registered doorway: the ground in front of the sill against the sill
##   sites    every levelled site (rect / circle): its floor against the ground just outside it
##   raids    every raid floor: its rim's ground against the floor, and at its gate
##   godot --headless --path . res://zz/zone_fit_probe.tscn -- --out=<file> [--only=stairs,portals,sites,raids]
const RealmLand := preload("res://core/world/realm/realm_land.gd")
var out_path := "user://zone_fit_probe.txt"
var only: Array = []
var main: Node
var p: Node3D
var t0 := 0
var started := false
var cmd_dir := ""                   ## --cmd=<dir>: stay up and answer <dir>/cmd.txt with <dir>/cmd.out (then <dir>/cmd.done), until "quit" or 14 min idle
var lines: PackedStringArray = []


func _ready() -> void:
	t0 = Time.get_ticks_msec()
	Travel._busy = true
	OssKit.record = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--cmd="):
			cmd_dir = a.trim_prefix("--cmd=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	Travel._busy = true
	if started:
		return
	if Time.get_ticks_msec() - t0 > 400000:
		print("ZONEFIT never got a world")
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


## First solid under (x, y_from, z): the floor a foot would find. NAN when nothing.
func _floor(x: float, y_from: float, z: float) -> float:
	var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y_from, z), Vector3(x, y_from - 14.0, z), Layers.WORLD | Layers.PROPS))
	return (hit.position as Vector3).y if not hit.is_empty() else NAN


func _ground(x: float, z: float) -> float:
	var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80.0, z), Vector3(x, -40.0, z), Layers.WORLD))
	return (hit.position as Vector3).y if not hit.is_empty() else NAN


## The land itself at (x, z): rays that skip whatever is built over it (a limb, a roof) until the terrain body is met.
func _terrain(x: float, z: float) -> float:
	var ex: Array[RID] = []
	for i in 8:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80.0, z), Vector3(x, -40.0, z), Layers.WORLD)
		q.exclude = ex
		var hit := _space().intersect_ray(q)
		if hit.is_empty():
			return NAN
		var cn := hit.collider as CollisionObject3D
		if cn != null and String(cn.name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(cn.get_rid())
	return NAN


func _run() -> void:
	for i in 150:
		await get_tree().process_frame
	for n: String in ["Encounters", "RoamEvents", "WorldEvents", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	var tq := Time.get_ticks_msec()
	if _want("stairs"):
		_stairs()
	if _want("portals"):
		_portals()
	if _want("raids"):
		_raids()
	if _want("sites"):
		_sites()
	if _want("henge"):
		_henge()
	if _want("rooms"):
		_rooms()
	if _want("named"):
		_named()
	if _want("thresholds"):
		_thresholds()
	print("ZONEFIT done in %.1f s, %d lines" % [float(Time.get_ticks_msec() - tq) / 1000.0, lines.size()])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	if cmd_dir != "":
		await _serve()
	get_tree().quit(0)


func _stairs() -> void:
	var rows: Array = []
	for s: Dictionary in OssKit.stair_registry:
		var par := s.parent as Node3D
		if par == null or not is_instance_valid(par) or not par.is_inside_tree():
			rows.append([99.0, "STAIR %s (holder gone) lo %s" % [s.key, s.lo]])
			continue
		var xf := par.global_transform
		var lo: Vector3 = xf * (s.lo as Vector3)
		var hi: Vector3 = xf * (s.hi as Vector3)
		var d := Vector3(hi.x - lo.x, 0, hi.z - lo.z)
		if d.length() < 0.01:
			continue
		var dir := d.normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var w: float = s.w
		var tread := d.length() / float(s.n)
		var rise := (hi.y - lo.y) / float(s.n)
		var worst_f := 0.0
		var worst_h := 0.0
		var nof := false
		var noh := false
		for off: float in [-0.3, 0.0, 0.3]:
			var sd := side * off * w
			var gf := _floor(lo.x - dir.x * 1.2 + sd.x, lo.y + 1.6, lo.z - dir.z * 1.2 + sd.z)
			if is_nan(gf):
				nof = true
			elif absf(gf - lo.y) > absf(worst_f):
				worst_f = gf - lo.y
			var gh := _floor(hi.x + dir.x * 1.0 + sd.x, hi.y + 1.6, hi.z + dir.z * 1.0 + sd.z)
			if is_nan(gh):
				noh = true
			elif absf(gh - hi.y) > absf(worst_h):
				worst_h = gh - hi.y
		var score := maxf(absf(worst_f), absf(worst_h)) + (3.0 if nof or noh else 0.0)
		var reg := String(RealmLayout.region_at(lo.x, lo.z).get("id", "wild"))
		rows.append([score, "STAIR %-22s %-9s foot (%.1f,%.2f,%.1f) head (%.1f,%.2f,%.1f) w %.1f n %d rise %.2f | foot gap %+.2f%s | head gap %+.2f%s | holder %s" % [
			s.key, reg, lo.x, lo.y, lo.z, hi.x, hi.y, hi.z, w, s.n, rise, worst_f, " NOFLOOR" if nof else "", worst_h, " NOFLOOR" if noh else "", par.get_path()]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	lines.append("== stairs (%d flights) worst first" % rows.size())
	for r: Array in rows:
		lines.append("%.2f %s" % [r[0], r[1]])


func _portals() -> void:
	lines.append("== portals")
	for pt: Dictionary in WorldLanes.portals:
		var at: Vector3 = pt.at
		var out: Vector3 = pt.out
		var g1 := _floor(at.x + out.x * 1.0, at.y + 1.6, at.z + out.z * 1.0)
		var g2 := _floor(at.x + out.x * 2.5, at.y + 1.6, at.z + out.z * 2.5)
		var blk := _sweep(at + out * 3.0, at - out * 2.0)
		lines.append("PORTAL %s %s at (%.1f,%.2f,%.1f) out (%.2f,%.2f) | floor 1 m out %+.2f | 2.5 m out %+.2f" % [pt.name, ("BLOCKED by " + blk) if blk != "" else "clear", at.x, at.y, at.z, out.x, out.z, g1 - at.y, g2 - at.y])


func _raids() -> void:
	lines.append("== raids")
	for r: Dictionary in RealmLayout.RAIDS:
		var c: Vector2 = r.c
		var y: float = r.y
		var gate: Vector2 = r.gate
		var s := "RAID %s y %.2f c (%.0f,%.0f) r %.1f | " % [r.id, y, c.x, c.y, r.r]
		var gg := _ground(c.x, c.y)
		s += "ground at centre %+.2f | gate (%.1f,%.1f) ground %+.2f | rim:" % [gg - y, gate.x, gate.y, _ground(gate.x, gate.y) - y]
		for i in 8:
			var a := TAU * float(i) / 8.0
			var rx: float = r.get("rx", r.r)
			var q := c + Vector2(cos(a) * rx, sin(a) * float(r.r)) * 0.96
			s += " %+.2f" % (_ground(q.x, q.y) - y)
		lines.append(s)


func _sites() -> void:
	lines.append("== sites (levelled): floor vs the ground round the outside (min / max of 12 points 1.5 m out)")
	var rows: Array = []
	for st: Dictionary in WorldLanes.sites:
		if st.has("seg") or not WorldLanes.is_floor_site(st):
			continue
		var r: Rect2 = st.rect
		var mn := INF
		var mx := -INF
		var n := 12
		for i in n:
			var a := TAU * float(i) / float(n)
			var q: Vector2
			if st.has("circle"):
				var c: Vector3 = st.circle
				q = Vector2(c.x, c.y) + Vector2(cos(a), sin(a)) * (c.z + 1.5)
			else:
				var cc := r.get_center()
				var h := r.size * 0.5 + Vector2(1.5, 1.5)
				var dd := Vector2(cos(a), sin(a))
				var k := minf(h.x / maxf(absf(dd.x), 0.001), h.y / maxf(absf(dd.y), 0.001))
				q = cc + dd * k
			var g := _ground(q.x, q.y)
			if is_nan(g):
				continue
			mn = minf(mn, g)
			mx = maxf(mx, g)
		var fy: float = st.floor_y
		var buried := mx - fy       # ground outside higher than the floor: a door below the soil
		var hang := fy - mn         # ground outside lower than the floor: a plinth showing
		rows.append([maxf(buried * 2.0, hang), "SITE %-28s %-9s floor %.2f centre (%.0f,%.0f) | outside min %+.2f max %+.2f" % [st.name, String(RealmLayout.region_at(r.get_center().x, r.get_center().y).get("id", "wild")), fy, r.get_center().x, r.get_center().y, mn - fy, mx - fy]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for r: Array in rows:
		lines.append("%.2f %s" % [r[0], r[1]])


func _henge() -> void:
	lines.append("== henge")
	lines.append("stair_pts %s" % [ThornHenge.stair_pts])
	lines.append("C %s STAIR_R %.1f" % [ThornHenge.C, ThornHenge.STAIR_R])
	var pts := ThornHenge.stair_pts
	if pts.size() >= 4:
		var head := pts[3]
		var dir := Vector3(head.x - pts[2].x, 0, head.z - pts[2].z).normalized()
		for k in range(-3, 9):
			var q := head + dir * float(k)
			lines.append("henge head %+d m: floor %.2f ground %.2f (head y %.2f)" % [k, _floor(q.x, head.y + 2.0, q.z), _ground(q.x, q.z), head.y])


## Every Interiors room: rays from its middle at 0.5 m and 1.4 m above its floor, 72 directions; a direction clear at both
## heights out past the room's box is a way out (a door). Per opening: the floor just inside, and 1 / 2.5 / 4 m outside.
func _rooms() -> void:
	lines.append("== rooms: every opening (door) of every Interiors room and every walled site; gap = floor outside minus floor inside the sill")
	var rows: Array = []
	var ents: Array = []
	for id: String in Interiors.rooms():
		var rm: Dictionary = Interiors.rooms()[id]
		var xf := (rm.inv as Transform3D).affine_inverse()
		ents.append({"id": "room:" + id, "xf": xf, "half": rm.half, "fy": xf.origin.y - (rm.half as Vector3).y})
	for st: Dictionary in WorldLanes.sites:
		if st.has("seg") or st.has("circle") or not WorldLanes.is_floor_site(st):
			continue
		var r: Rect2 = st.rect
		if r.size.x > 60.0 or r.size.y > 60.0 or r.size.x < 2.0:
			continue
		var cc := r.get_center()
		ents.append({"id": "site:" + String(st.name), "xf": Transform3D(Basis.IDENTITY, Vector3(cc.x, float(st.floor_y) + 1.0, cc.y)), "half": Vector3(r.size.x * 0.5, 1.0, r.size.y * 0.5), "fy": float(st.floor_y)})
	for e: Dictionary in ents:
		var id: String = e.id
		var xf: Transform3D = e.xf
		var inv := xf.affine_inverse()
		var h: Vector3 = e.half
		var c: Vector3 = xf.origin
		var fy: float = e.fy
		var reach := maxf(h.x, h.z) * 1.5 + 4.0
		var open: Array = []
		for i in 72:
			var a := TAU * float(i) / 72.0
			var d := Vector3(cos(a), 0, sin(a))
			var clear := true
			for hh: float in [0.5, 1.4]:
				var o := Vector3(c.x, fy + hh, c.z)
				var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * reach, Layers.WORLD | Layers.PROPS))
				if not hit.is_empty():
					var lq: Vector3 = inv * (hit.position as Vector3)
					if absf(lq.x) <= h.x + 0.8 and absf(lq.z) <= h.z + 0.8:
						clear = false
						break
			if clear:
				open.append(a)
		if open.size() > 36:
			continue                            # open-air: not a walled room
		var groups: Array = []
		for a: float in open:
			if not groups.is_empty() and absf(a - float((groups[-1] as Array)[-1])) < TAU / 72.0 * 1.5:
				(groups[-1] as Array).append(a)
			else:
				groups.append([a])
		for g: Array in groups:
			var am: float = (float(g[0]) + float(g[-1])) * 0.5
			var d := Vector3(cos(am), 0, sin(am))
			var ex_d := 0.0
			for k in 600:
				var q := c + d * (float(k) * 0.05)
				var lq: Vector3 = inv * Vector3(q.x, c.y, q.z)
				if absf(lq.x) > h.x or absf(lq.z) > h.z:
					ex_d = float(k) * 0.05
					break
			var ex := c + d * ex_d
			var fin := _floor(ex.x - d.x * 0.6, fy + 1.4, ex.z - d.z * 0.6)
			var f1 := _floor(ex.x + d.x * 1.0, fy + 1.4, ex.z + d.z * 1.0)
			var f2 := _floor(ex.x + d.x * 2.5, fy + 1.4, ex.z + d.z * 2.5)
			var f4 := _floor(ex.x + d.x * 4.0, fy + 1.4, ex.z + d.z * 4.0)
			var worst := 0.0
			for f: float in [f1, f2, f4]:
				var gg := (f - fin) if not is_nan(f) and not is_nan(fin) else 5.0
				if absf(gg) > absf(worst):
					worst = gg
			var blk := _sweep(Vector3(ex.x + d.x * 4.0, fy, ex.z + d.z * 4.0), Vector3(ex.x - d.x * 0.8, fy, ex.z - d.z * 0.8))
			if blk != "":
				worst = 9.0
			rows.append([absf(worst), "ROOM %-30s %s door at (%.1f,%.1f) %.1f m wide | floor in %.2f | out +1 %+.2f +2.5 %+.2f +4 %+.2f" % [id, ("BLOCKED by " + blk) if blk != "" else "clear", ex.x, ex.z, float(g.size()) * TAU / 72.0 * ex_d, fin, f1 - fin, f2 - fin, f4 - fin]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for r: Array in rows:
		lines.append("%.2f %s" % [r[0], r[1]])


func _named() -> void:
	lines.append("== named entrances")
	var sm := load("res://core/world/realm/realm_pois_south_marches.gd") as GDScript
	var oak: Dictionary = sm.get("oak")
	if not oak.is_empty():
		var xf: Transform3D = oak.xf
		var dr: Vector3 = oak.door
		var cen := xf.origin
		var out := Vector3(dr.x - cen.x, 0, dr.z - cen.z).normalized()
		var g := _terrain(dr.x, dr.z)
		var blk := _sweep(Vector3(dr.x + out.x * 6.0, g, dr.z + out.z * 6.0), Vector3(dr.x - out.x * 3.0, g, dr.z - out.z * 3.0))
		lines.append("OAK door (%.1f,%.1f,%.1f) ground %.2f out (%.2f,%.2f): %s" % [dr.x, dr.y, dr.z, g, out.x, out.z, ("BLOCKED by " + blk) if blk != "" else "clear"])
	else:
		lines.append("OAK data empty")


func _thresholds() -> void:
	lines.append("== thresholds (deep halls, caves): the stair's head on the surface")
	for n in get_tree().get_nodes_in_group(&"deep_hall") + get_tree().get_nodes_in_group(&"cave"):
		var th: Vector3 = (n as Node).get_meta("threshold_at", Vector3.ZERO)
		var g := _ground(th.x, th.z)
		lines.append("THRESH %s at (%.1f,%.2f,%.1f) ground %+.2f floor %+.2f %s" % [(n as Node).name, th.x, th.y, th.z, g - th.y, _floor(th.x, th.y + 1.6, th.z) - th.y, ("BLOCKED by " + _sweep(th + Vector3(3, 0, 0), th)) if _sweep(th + Vector3(3, 0, 0), th) != "" else "clear"])


## Blockage: a player-sized capsule (r 0.35, h 1.7) walked from `a` to `b` in 0.25 m steps, riding the floor found under each step
## (+0.22 m, so a tread or the ground itself does not count). Returns "" when clear, else the first solid and where.
func _sweep(a: Vector3, b: Vector3) -> String:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Layers.WORLD | Layers.PROPS
	var n := maxi(2, int(a.distance_to(b) / 0.25))
	var fy := a.y
	for i in n + 1:
		var pt := a.lerp(b, float(i) / float(n))
		var f := _floor(pt.x, fy + 1.4, pt.z)
		if not is_nan(f):
			fy = f
		q.transform = Transform3D(Basis.IDENTITY, Vector3(pt.x, fy + 0.55 + 0.85, pt.z))
		for h in _space().intersect_shape(q, 4):
			var cn := h.collider as Node
			if cn == null or String(cn.name).begins_with("Terrain"):
				continue
			return "%s at (%.1f,%.1f,%.1f)" % [cn.get_path(), pt.x, fy, pt.z]
	return ""


# ---- command server: ask the live Realm about a spot without paying a cold load per question --------------------------------

func _serve() -> void:
	var idle := Time.get_ticks_msec()
	print("ZONEFIT serving ", cmd_dir)
	_clean_ui()
	var fr := 0
	while Time.get_ticks_msec() - idle < 14 * 60 * 1000:
		await get_tree().process_frame
		fr += 1
		if fr % 10 == 0:
			_clean_ui()
		if fr % 20 == 0:
			for en in get_tree().get_nodes_in_group(Groups.ENEMY):
				(en as Node).queue_free()          # nothing may hollow the walker between commands
		var path := cmd_dir.path_join("cmd.txt")
		if not FileAccess.file_exists(path):
			continue
		var txt := FileAccess.get_file_as_string(path)
		DirAccess.remove_absolute(path)
		idle = Time.get_ticks_msec()
		lines = PackedStringArray()
		for ln: String in txt.split("\n", false):
			var parts := ln.strip_edges().split(" ", false)
			if parts.is_empty() or ln.begins_with("#"):
				continue
			lines.append("> " + ln)
			if parts[0] == "quit":
				return
			await _cmd(parts)
		var f := FileAccess.open(cmd_dir.path_join("cmd.out"), FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
		var d := FileAccess.open(cmd_dir.path_join("cmd.done"), FileAccess.WRITE)
		d.store_string("ok")
		d.close()


func _fl(a: PackedStringArray, i: int, def := 0.0) -> float:
	return float(a[i]) if a.size() > i else def


func _cmd(a: PackedStringArray) -> void:
	match a[0]:
		"floor":                                   # floor x z : terrain, first solid from 60 m, with its name
			var x := _fl(a, 1)
			var z := _fl(a, 2)
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -40, z), Layers.WORLD | Layers.PROPS))
			lines.append("floor (%.1f,%.1f): terrain %.2f | solid-or-terrain %.2f | first solid %.2f %s" % [x, z, _terrain(x, z), _ground(x, z), (hit.position as Vector3).y if not hit.is_empty() else NAN, _nm(hit)])
		"grid":                                    # grid x0 z0 x1 z1 step [yfrom]: first solid under yfrom (default 60) and terrain
			var step := _fl(a, 5, 2.0)
			var yf := _fl(a, 6, 60.0)
			var z := _fl(a, 2)
			while z <= _fl(a, 4) + 0.001:
				var row := "z %7.1f:" % z
				var x := _fl(a, 1)
				while x <= _fl(a, 3) + 0.001:
					var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, yf, z), Vector3(x, -40, z), Layers.WORLD | Layers.PROPS))
					row += " %6.2f" % ((hit.position as Vector3).y if not hit.is_empty() else NAN)
					x += step
				lines.append(row)
				z += step
			lines.append("(x from %.1f step %.1f)" % [_fl(a, 1), step])
		"sweep":                                   # sweep x1 z1 x2 z2 : capsule walk along it, every distinct solid met
			var p1 := Vector3(_fl(a, 1), 0, _fl(a, 2))
			var p2 := Vector3(_fl(a, 3), 0, _fl(a, 4))
			var y1 := _fl(a, 5, NAN)
			p1.y = _terrain(p1.x, p1.z) if is_nan(y1) else y1
			p2.y = _floor(p2.x, p1.y + 6.0, p2.z)
			var seen := {}
			var cap := CapsuleShape3D.new()
			cap.radius = 0.33
			cap.height = 1.7
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cap
			q.collision_mask = Layers.WORLD | Layers.PROPS
			var n := maxi(2, int(p1.distance_to(p2) / 0.25))
			var fy := p1.y
			for i in n + 1:
				var pt := p1.lerp(p2, float(i) / float(n))
				var f := _floor(pt.x, fy + 1.4, pt.z)
				if not is_nan(f):
					fy = f
				q.transform = Transform3D(Basis.IDENTITY, Vector3(pt.x, fy + 0.55 + 0.85, pt.z))
				for h in _space().intersect_shape(q, 6):
					var cn := h.collider as Node
					if cn == null or String(cn.name).begins_with("Terrain"):
						continue
					var key := "%s#%d" % [cn.get_path(), int(h.shape)]
					if not seen.has(key):
						seen[key] = true
						lines.append("  hit at step %.1f m (%.1f,%.2f,%.1f): %s" % [p1.distance_to(pt), pt.x, fy, pt.z, _shape_desc(cn, int(h.shape))])
			lines.append("sweep (%.1f,%.1f)->(%.1f,%.1f): %d solids" % [p1.x, p1.z, p2.x, p2.z, seen.size()])
		"near":                                    # near x y z r : every collider within r
			var ball := SphereShape3D.new()
			ball.radius = _fl(a, 4, 1.0)
			var q2 := PhysicsShapeQueryParameters3D.new()
			q2.shape = ball
			q2.collision_mask = Layers.WORLD | Layers.PROPS
			q2.transform = Transform3D(Basis.IDENTITY, Vector3(_fl(a, 1), _fl(a, 2), _fl(a, 3)))
			for h in _space().intersect_shape(q2, 24):
				var cn := h.collider as Node
				if cn != null and not String(cn.name).begins_with("Terrain"):
					lines.append("  " + _shape_desc(cn, int(h.shape)))
		"ray":                                     # ray x y z dx dy dz len
			var o := Vector3(_fl(a, 1), _fl(a, 2), _fl(a, 3))
			var dd := Vector3(_fl(a, 4), _fl(a, 5), _fl(a, 6)).normalized()
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(o, o + dd * _fl(a, 7, 10.0), Layers.WORLD | Layers.PROPS))
			lines.append("ray hit %s at %s" % [_nm(hit), hit.get("position", "none")])
		"walkstair":                               # walkstair <substring of the holder's path> : every flight there, foot-3.5 m -> head+2.5 m
			for sr: Dictionary in OssKit.stair_registry:
				var par := sr.parent as Node3D
				if par == null or not is_instance_valid(par) or not par.is_inside_tree() or not str(par.get_path()).contains(a[1]):
					continue
				var xf := par.global_transform
				var lo: Vector3 = xf * (sr.lo as Vector3)
				var hi: Vector3 = xf * (sr.hi as Vector3)
				var dir := Vector3(hi.x - lo.x, 0, hi.z - lo.z).normalized()
				var st0 := lo - dir * 3.5
				var en := hi + dir * 2.5
				lines.append(" flight %s foot (%.1f,%.2f,%.1f) head (%.1f,%.2f,%.1f)" % [sr.key, lo.x, lo.y, lo.z, hi.x, hi.y, hi.z])
				await _walk(PackedStringArray(["walk", "%.2f,%.2f,%.2f" % [st0.x, st0.z, maxf(lo.y, _terrain(st0.x, st0.z)) + 1.2], "%.2f,%.2f,%.2f" % [lo.x, lo.z, lo.y + 0.2], "%.2f,%.2f,%.2f" % [hi.x, hi.z, hi.y + 0.2], "%.2f,%.2f,%.2f" % [en.x, en.z, hi.y + 0.2]]))
		"lampscan":                                # lampscan : props standing on a flight's centreline (a 0.4 m box 1 m to 1.8 m over the tread)
			var box := BoxShape3D.new()
			box.size = Vector3(0.4, 0.8, 0.4)
			var qb := PhysicsShapeQueryParameters3D.new()
			qb.shape = box
			qb.collision_mask = Layers.WORLD | Layers.PROPS
			for sr: Dictionary in OssKit.stair_registry:
				var par := sr.parent as Node3D
				if par == null or not is_instance_valid(par) or not par.is_inside_tree():
					continue
				var xf := par.global_transform
				var lo: Vector3 = xf * (sr.lo as Vector3)
				var hi: Vector3 = xf * (sr.hi as Vector3)
				var seen := {}
				var n := maxi(2, int(lo.distance_to(hi) / 0.4))
				for i in n + 1:
					var q := lo.lerp(hi, float(i) / float(n))
					qb.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, q.y + 1.4, q.z))
					for h in _space().intersect_shape(qb, 6):
						var cn := h.collider as Node
						if cn == null or String(cn.name).begins_with("Terrain"):
							continue
						var key := str(cn.get_path())
						if not seen.has(key):
							seen[key] = true
							lines.append("PROP ON STAIR %s %s (%.1f,%.2f,%.1f): %s" % [sr.key, par.name, q.x, q.y, q.z, _shape_desc(cn, int(h.shape))])
		"ossroute":                                # the Ossuary's own walk, bridge to chapel, in world space
			var pts := PackedStringArray(["walk"])
			var first := true
			for lp: Vector3 in [Vector3(-9, 12.6, -34), Vector3(19.6, 12.6, -34), Vector3(23, 12.6, -36.6), Vector3(23, 12.6, -39.5), Vector3(23, 8.4, -49.5), Vector3(23, 8.4, -52.5), Vector3(20, 8.4, -58), Vector3(20, 8.4, -65.5), Vector3(21, 8.4, -67.5), Vector3(21, 4.2, -78), Vector3(17.5, 4.2, -84), Vector3(16, 4.2, -95.5), Vector3(16, 4.2, -104)]:
				var w := OssFrame.w(lp)
				pts.append("%.2f,%.2f,%.2f" % [w.x, w.z, w.y + (0.6 if first else 0.0)])
				first = false
			await _walk(pts)
		"unseal":                                  # every ward seal released, as the bake's walks do
			for w in main.find_children("*", "", true, false):
				if w is WardSeal:
					(w as WardSeal).release()
		"wait":                                    # wait <seconds>: a windowed boot holds the player a while
			var tw := Time.get_ticks_msec()
			while Time.get_ticks_msec() - tw < int(_fl(a, 1, 10.0) * 1000.0):
				await get_tree().process_frame
		"oakstair":                                # oakstair : the Grandmother Oak's inner stair, walked step 10 by step 10 up to the crown
			await _oakstair(a.size() > 1 and a[1] == "swap")
		"axis":                                    # axis x0 z0 x1 z1 step yfrom : first solid along a line, with what it is
			var a0 := Vector2(_fl(a, 1), _fl(a, 2))
			var a1 := Vector2(_fl(a, 3), _fl(a, 4))
			var st := _fl(a, 5, 0.5)
			var yfr := _fl(a, 6, 60.0)
			var ll := a0.distance_to(a1)
			var m := int(ll / st)
			for i in m + 1:
				var q := a0.lerp(a1, float(i) / float(maxi(m, 1)))
				var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, yfr, q.y), Vector3(q.x, -40, q.y), Layers.WORLD | Layers.PROPS))
				var nm := _nm(hit)
				lines.append("  %+5.1f (%.1f,%.1f): solid %.2f terrain %.2f  %s" % [float(i) * st, q.x, q.y, (hit.position as Vector3).y if not hit.is_empty() else NAN, _terrain(q.x, q.y), nm.get_slice("/", nm.get_slice_count("/") - 2) + "/" + nm.get_slice("/", nm.get_slice_count("/") - 1)])
		"shot", "shotg":                           # shot name px py pz tx ty tz [fov]; shotg: py and ty are heights above the terrain there
			await _shot(a)
		"stairs":
			_stairs()
		"rooms":
			_rooms()
		"portals":
			_portals()
		"thresholds":
			_thresholds()
		"named":
			_named()
		"walk":                                    # walk x,z x,z ... : the real Player, from the first point, through the rest
			await _walk(a)
		"mesh":                                    # mesh x z r : every drawn mesh whose box reaches r of (x, z)
			var cx := _fl(a, 1)
			var cz := _fl(a, 2)
			var rr := _fl(a, 3, 3.0)
			for n2: Node in main.find_children("*", "MeshInstance3D", true, false):
				var gi := n2 as MeshInstance3D
				if not gi.is_visible_in_tree() or gi.mesh == null:
					continue
				var bb: AABB = gi.global_transform * gi.get_aabb()
				var dx := maxf(maxf(bb.position.x - cx, 0.0), cx - bb.end.x)
				var dz := maxf(maxf(bb.position.z - cz, 0.0), cz - bb.end.z)
				if Vector2(dx, dz).length() <= rr and bb.size.length() < 200.0:
					lines.append("  mesh %s box (%.1f,%.1f,%.1f)+(%.1f,%.1f,%.1f)" % [main.get_path_to(gi), bb.position.x, bb.position.y, bb.position.z, bb.size.x, bb.size.y, bb.size.z])
		_:
			lines.append("unknown command " + a[0])


func _nm(hit: Dictionary) -> String:
	if hit.is_empty():
		return "-"
	var n := hit.collider as Node
	return str(n.get_path()) if n != null else "?"


func _shape_desc(c: Node, shape_idx: int) -> String:
	var co := c as CollisionObject3D
	if co == null:
		return str(c.get_path())
	var oid := co.shape_find_owner(shape_idx)
	var sh := co.shape_owner_get_shape(oid, 0)
	var at := (co.global_transform * co.shape_owner_get_transform(oid)).origin
	var sz := ""
	if sh is BoxShape3D:
		sz = str((sh as BoxShape3D).size)
	elif sh is CylinderShape3D:
		sz = "r %.2f h %.2f" % [(sh as CylinderShape3D).radius, (sh as CylinderShape3D).height]
	elif sh is ConcavePolygonShape3D:
		var bb := (sh as ConcavePolygonShape3D).get_debug_mesh().get_aabb()
		sz = "trimesh box %s+%s" % [(co.global_transform * bb).position.snapped(Vector3.ONE * 0.1), bb.size.snapped(Vector3.ONE * 0.1)]
	return "%s [%s at (%.1f,%.1f,%.1f) %s]" % [c.get_path(), sh.get_class(), at.x, at.y, at.z, sz]


## walk x,z x,z ...: teleport to the first point (standing on its floor) and drive the real Player through the rest; prints each leg
## and where it sticks, with what it is pressed against.
func _walk(a: PackedStringArray) -> void:
	var pl := p as Player
	var pts: Array[Vector3] = []
	for i in range(1, a.size()):
		var v := a[i].split(",")
		pts.append(Vector3(float(v[0]), float(v[2]) if v.size() > 2 else NAN, float(v[1])))
	if pts.size() < 2:
		return
	var y0 := pts[0].y if not is_nan(pts[0].y) else _terrain(pts[0].x, pts[0].z)
	pl.global_position = Vector3(pts[0].x, y0 + 0.4, pts[0].z)
	pl.velocity = Vector3.ZERO
	pl.reset_physics_interpolation()
	for i in 20:
		await get_tree().physics_frame
	for li in range(1, pts.size()):
		var goal := pts[li]
		var t := 0.0
		var ok := false
		var prev := pts[li - 1]
		var limit := 6.0 + Vector2(goal.x - prev.x, goal.z - prev.z).length() / 2.0
		while t < limit:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				(n as Node).queue_free()
			var d := Vector2(goal.x - pl.global_position.x, goal.z - pl.global_position.z)
			if d.length() < 0.7 and (is_nan(goal.y) or absf(pl.global_position.y - goal.y) < 1.1):
				ok = true
				break
			pl.debug_drive(Vector3(d.x, 0, d.y).normalized(), true)
		lines.append("  leg %d -> (%.1f,%.1f) %s in %.1f s, y %.2f%s" % [li, goal.x, goal.z, "reached" if ok else "STUCK", t, pl.global_position.y, "" if ok else " at (%.2f,%.2f)" % [pl.global_position.x, pl.global_position.z]])
		if not ok:
			_blockers(pl)
			break
	pl.debug_drive(Vector3.ZERO)


func _blockers(pl: Player) -> void:
	var ball := SphereShape3D.new()
	ball.radius = 1.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY, pl.global_position + Vector3.UP * 0.9)
	q.exclude = [pl.get_rid()]
	for h in pl.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var cn := h.collider as Node
		if cn != null and String(cn.name) != "TerrainBody":
			lines.append("    BLOCKER " + _shape_desc(cn, int(h.shape)))


func _shot(a: PackedStringArray) -> void:
	if DisplayServer.get_name() == "headless" or a.size() < 8:
		lines.append("shot: needs a window and 7 numbers")
		return
	_clean_ui()
	var prev := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = _fl(a, 8, 75.0)
	cam.near = 0.08
	cam.far = 900.0
	var cy := _fl(a, 3)
	var ty := _fl(a, 6)
	if a[0] == "shotg":
		cy += _terrain(_fl(a, 2), _fl(a, 4))
		ty += _terrain(_fl(a, 5), _fl(a, 7))
	cam.global_position = Vector3(_fl(a, 2), cy, _fl(a, 4))
	cam.look_at(Vector3(_fl(a, 5), ty, _fl(a, 7)))
	cam.current = true
	for i in 12:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(cmd_dir.path_join("shots"))
	var path := cmd_dir.path_join("shots/%s.png" % a[1])
	img.save_png(path)
	lines.append("shot " + path)
	cam.queue_free()
	if prev != null and is_instance_valid(prev):
		prev.current = true


## The oak's stair: local position (sin a r, y, cos a r) about the trunk's sway; the radius is found by rays (the tread nearest the
## expected height), then the real Player climbs from the door, every tenth tread.
func _oakstair(swap := false) -> void:
	var sm := load("res://core/world/realm/realm_pois_south_marches.gd") as GDScript
	var oak: Dictionary = sm.get("oak")
	if oak.is_empty():
		lines.append("oakstair: no oak")
		return
	var xf: Transform3D = oak.xf
	var data := load("res://core/world/realm/south_marches_kit_data.gd") as GDScript
	var st: Dictionary = data.get_script_constant_map()["OAK_STAIR"]
	var a0: float = st.a0
	var a1: float = st.a_end
	var n: int = st.n
	var rise: float = st.rise
	var y0: float = st.y0
	var args := PackedStringArray(["walk"])
	var door: Vector3 = oak.door
	args.append("%.2f,%.2f,%.2f" % [door.x + 0.0, door.z - 6.0, _terrain(door.x, door.z - 6.0) + 0.6])
	args.append("%.2f,%.2f" % [door.x, door.z])
	for k in range(0, n, 8):
		var yy := y0 + rise * float(k)
		var a := a0 + (a1 - a0) * float(k) / float(n)
		var sway := Vector3(1.3 * sin(yy * 0.11 + 0.4) + 0.02 * yy, 0.0, 1.1 * cos(yy * 0.09 + 1.1))
		var best := Vector3.ZERO
		var best_d := 0.3
		var r := 2.5
		while r < 6.6:
			var lp := (Vector3(cos(a) * r, 0.0, sin(a) * r) if swap else Vector3(sin(a) * r, 0.0, cos(a) * r)) + sway
			var w := xf * Vector3(lp.x, yy + 1.2, lp.z)
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(w, w + Vector3.DOWN * 2.2, Layers.WORLD | Layers.PROPS))
			if not hit.is_empty():
				var dy := absf((hit.position as Vector3).y - (xf.origin.y + yy))
				if dy < best_d:
					best_d = dy
					best = hit.position
			r += 0.25
		if best == Vector3.ZERO:
			lines.append("  tread %d (a %.2f y %.2f): no floor found at any radius" % [k, a, xf.origin.y + yy])
			continue
		args.append("%.2f,%.2f,%.2f" % [best.x, best.z, best.y])
	lines.append("oakstair: %d waypoints" % (args.size() - 1))
	await _walk(args)


## A windowed boot opens the opening shot and (at level 5) the vow menu, which pause the tree and cover every frame: out of the way.
func _clean_ui() -> void:
	get_tree().paused = false
	for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	for nm: String in ["OpeningCam", "LoadingScreen", "CampCam"]:
		var n := main.get_node_or_null(nm)
		if n != null:
			n.queue_free()
