extends Node
## Realm-wide placement probe (r39 grounding + audit). Boots the night, waits for the Realm, then walks every placed static
## mesh (MeshInstance3D islands and MultiMesh instances) and writes one TSV row per object: where it stands, how its base meets the
## TERRAIN body (rays on the terrain only), and the context checks (under an overhead solid, in water, on a way, orphaned).
## Offline ranking: tools/ground_rank.py.
##   godot --headless --path . res://zz/ground_probe.tscn -- --out=/path/probe.tsv
const SeatP := preload("res://core/world/seat_props.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const SKIP_ROOTS := ["Wildlife", "NightLife", "Progression", "Wayfarers"]
const FLORA_KEEP := ["stone", "log", "stump", "rock", "boulder", "slag", "rubble", "cairn", "mushroom"]
const SKIP_NAMES := ["terrain", "water", "river", "lava", "sky", "ring", "mist", "fog", "cloud", "star", "moon", "plume", "beacon", "shaft", "ray", "decal", "glow", "ripple", "foam", "fall"]
const FLORA_NAMES := ["grass", "fern", "blade", "pebble", "cap", "moss", "leaf", "flower", "reed", "weed", "bloom", "shroom", "bud", "clover", "litter"]
var main: Node
var t := 0
var out_path := "/tmp/ground_probe.tsv"
var space: PhysicsDirectSpaceState3D
var rows: PackedStringArray = []
var boxes: Array = []            ## [AABB, sys, idx] of non-flora items for the overlap pass
var n_rays := 0
var _t0 := 0
var skipped := {}


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	t += 1
	if not main.has_meta("realm_done") or t < 240:
		return
	set_process(false)
	run(main, out_path)
	get_tree().quit()


## The whole probe on an already built night (also called by zz/ground_shots.gd, so one Godot run measures and shoots).
func run(night: Node, path: String) -> void:
	main = night
	out_path = path
	var t0 := Time.get_ticks_msec()
	_t0 = t0
	space = (main as Node3D).get_world_3d().direct_space_state
	_walk()
	_colliders()
	_overlaps()
	_fx()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_line("sys\tkind\tflora\tx\ty\tz\tsx\tsy\tsz\tfl\tsk\tmean\tslope\ttilt\tway\twd\tsite\tover\tregion\tsup\tlone\tmeshpath\tovl")
	for r in rows:
		f.store_line(r)
	f.close()
	print("GPROBE rows %d rays %d in %d ms -> %s skipped %s" % [rows.size(), n_rays, Time.get_ticks_msec() - t0, out_path, skipped])


func _skip_node(n: Node) -> bool:
	var nm := String(n.name).to_lower()
	var top := String(main.get_path_to(n)).get_slice("/", 0)
	if top in SKIP_ROOTS:
		return true
	if nm.begins_with("flora_"):
		var keep := false
		for k: String in FLORA_KEEP:
			if nm.contains(k):
				keep = true
		return not keep
	for k: String in SKIP_NAMES:
		if nm.contains(k):
			return true
	var p := n.get_parent()
	while p != null and p != main:
		if p is CharacterBody3D or p is Player or p.is_in_group(Groups.ENEMY) or p.is_in_group(&"villager"):
			return true
		var pn := String(p.name).to_lower()
		if pn.begins_with("terrain") or pn.contains("lava") or pn.contains("ossuary"):
			return true
		p = p.get_parent()
	return false


func _sys_of(n: Node) -> String:
	var parts := String(main.get_path_to(n)).split("/")
	var keep: Array = []
	for i in mini(4, parts.size() - 1):
		var s := parts[i]
		keep.append(s)
	return "/".join(keep)


func _kind_of(n: Node, mesh: Mesh) -> String:
	var nm := String(n.name)
	var re := RegEx.new()
	re.compile("[0-9_@]+$")
	nm = re.sub(nm, "")
	if mesh != null and mesh.resource_path != "":
		nm += "|" + mesh.resource_path.get_file().get_basename()
	return nm


func _is_flora(n: Node, sz: Vector3) -> bool:
	var nm := String(n.name).to_lower()
	for k: String in FLORA_NAMES:
		if nm.begins_with(k):
			return true
	return false


## Terrain height at xz found by a ray from y0 down, skipping every other collider.
func _ground(x: float, z: float, y0: float) -> float:
	var ex: Array[RID] = []
	var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, y0, z + 0.0029), Vector3(x + 0.0037, y0 - 90.0, z + 0.0029), 1)
	for k in 10:
		q.exclude = ex
		var hit := space.intersect_ray(q)
		n_rays += 1
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return NAN


func _walk() -> void:
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MultiMeshInstance3D:
			var mmi := n as MultiMeshInstance3D
			if mmi.multimesh == null or mmi.multimesh.mesh == null or not mmi.is_visible_in_tree():
				continue
			if _skip_node(n):
				skipped["skip_mm"] = int(skipped.get("skip_mm", 0)) + 1
				continue
			_measure_mm(mmi)
		elif n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree() or mi.layers == 0:
				continue
			if _skip_node(n):
				skipped["skip_mi"] = int(skipped.get("skip_mi", 0)) + 1
				continue
			_measure_mi(mi)


func _measure_mm(mmi: MultiMeshInstance3D) -> void:
	var mm := mmi.multimesh
	var bb := mm.mesh.get_aabb()
	if mm.transform_format != MultiMesh.TRANSFORM_3D:
		return
	if maxf(bb.size.x, bb.size.z) < 0.5 and bb.size.y < 0.6:
		skipped["tiny_mm_inst"] = int(skipped.get("tiny_mm_inst", 0)) + mm.instance_count
		return
	var flora := _is_flora(mmi, bb.size)
	var kind := _kind_of(mmi, mm.mesh)
	var sysn := _sys_of(mmi)
	var cnt := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	if cnt > 4000 and flora:
		skipped["flora_mm_inst"] = int(skipped.get("flora_mm_inst", 0)) + cnt
		return
	var step := 1
	if cnt > 6000:
		step = ceili(float(cnt) / 6000.0)
	var gx := mmi.global_transform
	for i in range(0, cnt, step):
		var xf := gx * mm.get_instance_transform(i)
		_item(xf, bb, kind, sysn, flora, mmi, "mm%d" % i, PackedVector3Array())


func _measure_mi(mi: MeshInstance3D) -> void:
	var bb := mi.get_aabb()
	var kind := _kind_of(mi, mi.mesh)
	var sysn := _sys_of(mi)
	var wb := mi.global_transform * bb
	if maxf(wb.size.x, wb.size.z) > 220.0:
		skipped["huge_mi"] = int(skipped.get("huge_mi", 0)) + 1
		return
	var flora := _is_flora(mi, bb.size)
	var big := maxf(wb.size.x, wb.size.z) > 2.5 and mi.mesh.get_surface_count() > 0 and not (mi.mesh is PrimitiveMesh) and Time.get_ticks_msec() - _t0 < 150000
	if not big:
		_item(mi.global_transform, bb, kind, sysn, flora, mi, "mi", PackedVector3Array())
		return
	# a merged or large mesh: one object per welded island
	var arrays_all: Array = []
	var xf := mi.global_transform
	var nv := 0
	for s in mi.mesh.get_surface_count():
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		nv += vs.size()
		if nv > 150000:
			break
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(vs.size())
			for k in vs.size():
				idx[k] = k
		arrays_all.append([vs, idx])
	if nv > 150000 or arrays_all.is_empty():
		_item(mi.global_transform, bb, kind, sysn, flora, mi, "mi", PackedVector3Array())
		return
	var isl_n := 0
	for pair: Array in arrays_all:
		var vs: PackedVector3Array = pair[0]
		var comp := SeatP.island_of(vs, pair[1])
		var groups := {}
		for vi in vs.size():
			if comp[vi] >= 0:
				if not groups.has(comp[vi]):
					groups[comp[vi]] = PackedVector3Array()
				(groups[comp[vi]] as PackedVector3Array).append(xf * vs[vi])
		for c: int in groups:
			var pts: PackedVector3Array = groups[c]
			if pts.size() < 8:
				continue
			isl_n += 1
			var lo := pts[0]
			var hi := pts[0]
			for p in pts:
				lo = lo.min(p)
				hi = hi.max(p)
			var wbb := AABB(lo, hi - lo)
			# base verts: within 0.2 m of the island's lowest point, one per 0.75 m cell
			var cells := {}
			for p in pts:
				if p.y < lo.y + 0.2:
					var key := Vector2i(floori(p.x / 0.75), floori(p.z / 0.75))
					if not cells.has(key):
						cells[key] = p
			var base := PackedVector3Array()
			var ks := cells.keys()
			var stp := maxi(1, ks.size() / 10)
			for k in range(0, ks.size(), stp):
				base.append(cells[ks[k]])
			_item(Transform3D(Basis.IDENTITY, wbb.get_center()), AABB(-wbb.size * 0.5, wbb.size), kind, sysn, flora, mi, "isl%d" % c, base)
	skipped["islands"] = int(skipped.get("islands", 0)) + isl_n


## One object: world transform xf of local box bb (or, with `base`, the world base points directly).
func _item(xf: Transform3D, bb: AABB, kind: String, sysn: String, flora: bool, src: Node, idn: String, base: PackedVector3Array) -> void:
	var pts := PackedVector3Array()
	var low := INF
	var top := -INF
	var ext := bb.size * xf.basis.get_scale()
	if base.is_empty():
		var c := bb.get_center()
		var hx := bb.size.x * 0.5 * 0.8
		var hz := bb.size.z * 0.5 * 0.8
		var y0 := bb.position.y
		for off: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(xf * Vector3(c.x + off.x * hx, y0, c.z + off.y * hz))
		pts.append(xf * Vector3(c.x, y0, c.z))
		if ext.x < 0.5 and ext.z < 0.5:
			pts = PackedVector3Array([xf * Vector3(c.x, y0, c.z)])
		low = INF
		for p in pts:
			low = minf(low, p.y)
		top = (xf * Vector3(c.x, bb.end.y, c.z)).y
	else:
		pts = base
		for p in base:
			low = minf(low, p.y)
		top = low + bb.size.y
	var fl := -INF
	var sk := INF
	var sum := 0.0
	var gmin := INF
	var gmax := -INF
	var nn := 0
	for p in pts:
		var g := _ground(p.x, p.z, p.y + 4.0)
		if is_nan(g):
			continue
		var gap := p.y - g
		fl = maxf(fl, gap)
		sk = minf(sk, gap)
		sum += gap
		gmin = minf(gmin, g)
		gmax = maxf(gmax, g)
		nn += 1
	if nn == 0:
		skipped["no_ground"] = int(skipped.get("no_ground", 0)) + 1
		return
	var cx := (pts[0].x + pts[pts.size() - 1].x) * 0.5 if pts.size() > 1 else pts[0].x
	var cz := (pts[0].z + pts[pts.size() - 1].z) * 0.5 if pts.size() > 1 else pts[0].z
	if not base.is_empty():
		cx = xf.origin.x
		cz = xf.origin.z
	var foot := maxf(0.3, maxf(ext.x, ext.z))
	var slope := (gmax - gmin) / foot
	var up := (xf.basis.y).normalized()
	var tilt := rad_to_deg(acos(clampf(up.y, -1.0, 1.0)))
	var p2 := Vector2(cx, cz)
	var way := RealmLayout.path_dist(p2)
	var wd := 0.0
	if Land.in_water(cx, cz):
		wd = Land.water_y_at(cx, cz) - low
	var site := String(WorldLanes.site_at(p2, 0.5).get("name", ""))
	var overhead := ""
	var sup := 0.0
	if not flora and ext.x >= 0.4:
		var q := PhysicsRayQueryParameters3D.create(Vector3(cx, top + 0.15, cz), Vector3(cx, top + 14.0, cz), Layers.WORLD)
		var ex: Array[RID] = []
		for k in 4:
			q.exclude = ex
			var h := space.intersect_ray(q)
			n_rays += 1
			if h.is_empty():
				break
			var col := h.collider as Node
			if String(col.name).begins_with("Terrain") or EnemySpawner._is_flora_body(col):
				ex.append(h.rid)
				continue
			if not (src.is_ancestor_of(col) or col.is_ancestor_of(src)):
				overhead = String(main.get_path_to(col)).left(70)
				break
			ex.append(h.rid)
		# resting on a deck or step (not terrain) when its base hovers: a solid within 0.3 m under the lowest corner
		if fl > 0.15:
			var q2 := PhysicsRayQueryParameters3D.create(Vector3(cx, low + 0.02, cz), Vector3(cx, low - 0.45, cz), Layers.WORLD)
			var h2 := space.intersect_ray(q2)
			n_rays += 1
			if not h2.is_empty() and not String((h2.collider as Node).name).begins_with("Terrain"):
				sup = low + 0.02 - (h2.position as Vector3).y
	var region := String(RealmLayout.region_at(cx, cz).get("id", ""))
	var row := "%s\t%s\t%d\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.3f\t%.3f\t%.3f\t%.3f\t%.1f\t%.1f\t%.2f\t%s\t%s\t%s\t%.2f\t0\t%s\t0" % [
		sysn, kind, 1 if flora else 0, cx, low, cz, ext.x, ext.y, ext.z, fl, sk, sum / float(nn), slope, tilt, way, wd, site, overhead, region, sup,
		String(main.get_path_to(src)).left(90) + "#" + idn]
	rows.append(row)
	if not flora and ext.x > 0.3:
		var wbb := AABB(Vector3(cx - ext.x * 0.5, low, cz - ext.z * 0.5), Vector3(ext.x, maxf(ext.y, 0.1), ext.z))
		boxes.append([wbb, sysn, rows.size() - 1])


## Pass 2: a non-flora item whose box sits mostly inside another solid's box of another system or another mesh.
func _overlaps() -> void:
	var cells := {}
	for i in boxes.size():
		var bb: AABB = boxes[i][0]
		for cx in range(floori(bb.position.x / 8.0), floori(bb.end.x / 8.0) + 1):
			for cz in range(floori(bb.position.z / 8.0), floori(bb.end.z / 8.0) + 1):
				var k := Vector2i(cx, cz)
				if not cells.has(k):
					cells[k] = PackedInt32Array()
				(cells[k] as PackedInt32Array).append(i)
	var hits := {}
	for k: Vector2i in cells:
		var lst: PackedInt32Array = cells[k]
		if lst.size() > 80:
			continue
		for a in lst.size():
			for b in range(a + 1, lst.size()):
				var i: int = lst[a]
				var j: int = lst[b]
				var ba: AABB = boxes[i][0]
				var bj: AABB = boxes[j][0]
				var ov := ba.intersection(bj)
				if ov.size.x <= 0.05 or ov.size.y <= 0.05 or ov.size.z <= 0.05:
					continue
				var va := ba.size.x * ba.size.y * ba.size.z
				var vj := bj.size.x * bj.size.y * bj.size.z
				var vo := ov.size.x * ov.size.y * ov.size.z
				var small := minf(va, vj)
				if small < 0.02 or vo / small < 0.55:
					continue
				# a small one inside a much bigger one of ANOTHER system: buried in it
				var s_i: int = i if va < vj else j
				var big_i: int = j if va < vj else i
				if String(boxes[s_i][1]) == String(boxes[big_i][1]) and maxf(va, vj) < 3.0 * small:
					continue
				var r: int = boxes[s_i][2]
				if not hits.has(r) or float(hits[r]) < vo / small:
					hits[r] = vo / small
	for r: int in hits:
		var parts := rows[r].split("\t")
		parts[parts.size() - 1] = "%.2f" % float(hits[r])
		rows[r] = "\t".join(parts)


## Pass 3: every effect that rises (particle emitters, the far plumes, beacons, light shafts): where it stands against the ground and the solids.
func _fx() -> void:
	var lines := PackedStringArray()
	lines.append("class\tname\tpath\tx\ty\tz\tground\th\tup_hit\tclip\tway\tregion\textra")
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var is_fx := n is GPUParticles3D or n is CPUParticles3D or n.is_in_group(&"landmark_beacon") or String(n.name).to_lower().contains("plume") or String(n.name).to_lower().contains("shaft") or String(n.name).to_lower().contains("pillar")
		if not is_fx or not (n is Node3D):
			continue
		var n3 := n as Node3D
		if n is Player or n3.get_parent() is Player:
			continue
		var pos := n3.global_position
		if String(main.get_path_to(n)).to_lower().contains("ossuary"):
			continue
		var g := _ground(pos.x, pos.z, pos.y + 6.0)
		var up_hit := -1.0
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.1, pos + Vector3.UP * 14.0, Layers.WORLD)
		var ex: Array[RID] = []
		for k in 3:
			q.exclude = ex
			var h := space.intersect_ray(q)
			if h.is_empty():
				break
			var col := h.collider as Node
			if String(col.name).begins_with("Terrain") or EnemySpawner._is_flora_body(col):
				ex.append(h.rid)
				continue
			up_hit = (h.position as Vector3).y - pos.y
			break
		var clip := 0
		for hh: float in [3.0, 8.0, 16.0, 30.0]:
			for a in 8:
				var d := Vector3(cos(TAU * a / 8.0), 0.0, sin(TAU * a / 8.0))
				var o := pos + Vector3.UP * hh
				var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 4.0, Layers.WORLD))
				if not r.is_empty() and not String((r.collider as Node).name).begins_with("Terrain"):
					clip += 1
		var emitting := ""
		if n is GPUParticles3D:
			emitting = "gpu emit=%s n=%d life=%.1f" % [(n as GPUParticles3D).emitting, (n as GPUParticles3D).amount, (n as GPUParticles3D).lifetime]
		elif n is CPUParticles3D:
			emitting = "cpu emit=%s n=%d life=%.1f" % [(n as CPUParticles3D).emitting, (n as CPUParticles3D).amount, (n as CPUParticles3D).lifetime]
		elif n3 is VisualInstance3D:
			emitting = "aabb %s" % (n3 as VisualInstance3D).get_aabb().size
		var p2 := Vector2(pos.x, pos.z)
		lines.append("%s\t%s\t%s\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%d\t%.1f\t%s\t%s\t%s" % [n.get_class(), n.name, String(main.get_path_to(n)).left(100), pos.x, pos.y, pos.z, g, pos.y - g, up_hit, clip, RealmLayout.path_dist(p2), String(RealmLayout.region_at(pos.x, pos.z).get("id", "")), emitting, "vis" if n3.is_visible_in_tree() else "hidden"])
	var f := FileAccess.open(out_path + ".fx.tsv", FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()


## Pass 1b: the solid pieces themselves. The kits' colliders are triangle soups (one box = 12 faces on 8 welded points), so welded islands of the faces are the
## boxes and pieces as built (the visual meshes are cut into cells by the build, which loses them). A base point is grounded when it is within 8 cm of the terrain
## or when another collider lies under it (a wall on its plinth); the rest hover.
func _colliders() -> void:
	var t1 := Time.get_ticks_msec()
	var n_isl := 0
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is CollisionObject3D) or n is Player or n is CharacterBody3D:
			continue
		var co := n as CollisionObject3D
		if (co.collision_layer & Layers.WORLD) == 0:
			continue
		var nm := String(n.name)
		if nm.begins_with("Terrain") or nm == "FloraBody" or String(n.get_parent().name).begins_with("Trees_") or n.is_in_group(Groups.ENEMY):
			continue
		var path := String(main.get_path_to(n))
		if path.to_lower().contains("ossuary") or Time.get_ticks_msec() - t1 > 90000:
			continue
		var sysn := _sys_of(n)
		for cs in n.get_children():
			var shp := cs as CollisionShape3D
			if shp == null or shp.shape == null or shp.disabled:
				continue
			var gx := shp.global_transform
			var verts := PackedVector3Array()
			if shp.shape is ConcavePolygonShape3D:
				var faces := (shp.shape as ConcavePolygonShape3D).get_faces()
				if faces.size() < 12 or faces.size() > 90000:
					continue
				var idx := PackedInt32Array()
				idx.resize(faces.size())
				for i in faces.size():
					idx[i] = i
				var comp := SeatP.island_of(faces, idx)
				var groups := {}
				for vi in faces.size():
					if comp[vi] >= 0:
						if not groups.has(comp[vi]):
							groups[comp[vi]] = PackedVector3Array()
						(groups[comp[vi]] as PackedVector3Array).append(gx * faces[vi])
				for g: int in groups:
					n_isl += 1
					_col_item(groups[g] as PackedVector3Array, sysn, n, nm)
			elif shp.shape is ConvexPolygonShape3D:
				for v in (shp.shape as ConvexPolygonShape3D).points:
					verts.append(gx * v)
				_col_item(verts, sysn, n, nm)
			elif shp.shape is BoxShape3D:
				var h := (shp.shape as BoxShape3D).size * 0.5
				for sx: float in [-1.0, 1.0]:
					for sy: float in [-1.0, 1.0]:
						for sz: float in [-1.0, 1.0]:
							verts.append(gx * Vector3(h.x * sx, h.y * sy, h.z * sz))
				_col_item(verts, sysn, n, nm)
	skipped["col_islands"] = n_isl


func _col_item(pts: PackedVector3Array, sysn: String, body: Node, nm: String) -> void:
	if pts.size() < 4:
		return
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var ext := hi - lo
	if maxf(ext.x, ext.z) > 60.0 or (ext.x < 0.2 and ext.z < 0.2) or ext.y < 0.05:
		return
	var cells := {}
	for p in pts:
		if p.y < lo.y + 0.15:
			var key := Vector2i(floori(p.x / 0.6), floori(p.z / 0.6))
			if not cells.has(key):
				cells[key] = p
	var ks := cells.keys()
	var stp := maxi(1, ks.size() / 8)
	var fl := -INF
	var sk := INF
	var sum := 0.0
	var gmin := INF
	var gmax := -INF
	var nn := 0
	var sup_n := 0
	for k in range(0, ks.size(), stp):
		var p: Vector3 = cells[ks[k]]
		var g := _ground(p.x, p.z, p.y + 4.0)
		if is_nan(g):
			continue
		var gap := p.y - g
		var supported := false
		if gap > 0.08:
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y - 0.02, p.z), Vector3(p.x, p.y - 0.3, p.z), Layers.WORLD)
			n_rays += 1
			var h := space.intersect_ray(q)
			if not h.is_empty() and not String((h.collider as Node).name).begins_with("Terrain"):
				supported = true
				sup_n += 1
		fl = maxf(fl, 0.0 if supported else gap)
		sk = minf(sk, gap)
		sum += gap
		gmin = minf(gmin, g)
		gmax = maxf(gmax, g)
		nn += 1
	if nn == 0:
		return
	var cx := (lo.x + hi.x) * 0.5
	var cz := (lo.z + hi.z) * 0.5
	var foot := maxf(0.3, maxf(ext.x, ext.z))
	var p2 := Vector2(cx, cz)
	var wd := 0.0
	if Land.in_water(cx, cz):
		wd = Land.water_y_at(cx, cz) - lo.y
	var site := String(WorldLanes.site_at(p2, 0.5).get("name", ""))
	var region := String(RealmLayout.region_at(cx, cz).get("id", ""))
	var kind := "col:" + nm.left(24)
	rows.append("%s\t%s\t0\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.3f\t%.3f\t%.3f\t%.3f\t0.0\t%.1f\t%.2f\t%s\t\t%s\t%.2f\t0\t%s\t0" % [
		sysn, kind, cx, lo.y, cz, ext.x, ext.y, ext.z, fl, sk, sum / float(nn), (gmax - gmin) / foot, RealmLayout.path_dist(p2), wd, site, region, float(sup_n), String(main.get_path_to(body)).left(90) + "#col"])
