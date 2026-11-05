extends Node
## World audit (headless, ~20 s): lanes, portals, sites vs solids, seals, arenas.
## Every visible mesh gets a trimesh proxy on layer 20 (MultiMesh props only under a real renderer).
## Prints one AUDIT line per failure and ends with AUDIT PASS / AUDIT FAIL n.
const PROXY := 1 << 19
var p: Player
var t := 0
var fails := 0
var _root: Node
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _owner_site(n: Node) -> String:
	var q := n
	while q:
		if q.has_meta("site"): return String(q.get_meta("site"))
		q = q.get_parent()
	return ""
func _skip(n: Node) -> bool:
	var q: Node = n
	while q:
		var nm := String(q.name)
		if q is CharacterBody3D or q is GPUParticles3D or nm.begins_with("Halos") or nm.begins_with("Flames") or nm.begins_with("Seal_") or nm in ["SkyFlare", "Sky", "Terrain", "Lava", "Surface", "Glimmers", "grass"] or nm.begins_with("grass"):
			return true
		q = q.get_parent()
	var gi := n as GeometryInstance3D
	return gi == null or not gi.is_visible_in_tree()
func _proxies() -> int:
	var made := 0
	for node in _root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or _skip(mi): continue
		var sh := mi.mesh.create_trimesh_shape() as ConcavePolygonShape3D
		if sh == null: continue
		sh.backface_collision = true
		var b := StaticBody3D.new(); b.collision_layer = PROXY; b.collision_mask = 0
		b.set_meta("src", String(mi.get_path()).replace(String(_root.get_path()) + "/", ""))
		b.set_meta("site_of", _owner_site(mi))
		var cs := CollisionShape3D.new(); cs.shape = sh; b.add_child(cs)
		_root.add_child(b); b.global_transform = mi.global_transform
		made += 1
	for node in _root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or _skip(mmi): continue
		var mm := mmi.multimesh
		var aabb := mm.mesh.get_aabb()
		var buf := mm.buffer
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		if buf.size() < mm.instance_count * stride: continue
		var b := StaticBody3D.new(); b.collision_layer = PROXY
		b.set_meta("src", String(mmi.get_path()).replace(String(_root.get_path()) + "/", ""))
		b.set_meta("site_of", _owner_site(mmi))
		_root.add_child(b); b.global_transform = mmi.global_transform
		var real := 0
		for i in mini(mm.instance_count, 3000):
			var o := i * stride
			var bas := Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]), Vector3(buf[o + 2], buf[o + 6], buf[o + 10]))
			var org := Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			if bas.determinant() == 0.0: continue
			if org == Vector3.ZERO and bas == Basis.IDENTITY: continue    # headless dummy buffer
			real += 1
			# only the bottom 2.5 m of an instance occupies the ground: a tree's crown overhanging a
			# small site (a menhir, a brazier) is not an obstruction, its trunk and roots would be
			var box := aabb
			var sy := absf(bas.get_scale().y)
			if box.size.y * sy > 2.5:
				box.size.y = 2.5 / maxf(sy, 0.001)
				box.size.x = minf(box.size.x, maxf(box.size.y * 0.6, 1.2 / maxf(absf(bas.get_scale().x), 0.001)))
				box.size.z = minf(box.size.z, maxf(box.size.y * 0.6, 1.2 / maxf(absf(bas.get_scale().z), 0.001)))
				box.position = Vector3(aabb.get_center().x - box.size.x * 0.5, aabb.position.y, aabb.get_center().z - box.size.z * 0.5)
			var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
			bs.size = (box.size * bas.get_scale()).abs().max(Vector3.ONE * 0.02)
			cs.shape = bs
			cs.transform = Transform3D(bas.orthonormalized(), Transform3D(bas, org) * box.get_center())
			b.add_child(cs)
		made += 1
	return made
func fail(kind: String, what: String, at: Vector3) -> void:
	fails += 1
	print("AUDIT %s %s at %s" % [kind, what, at.snapped(Vector3.ONE * 0.1)])
func _physics_process(_d: float) -> void:
	t += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if t == 24:
		_root = p.owner if p.owner else p.get_parent()
		for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
		print("AUDIT proxies ", _proxies())
	if t != 28: return
	var space := p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.5
	# 1. lanes (hub lanes ray-measured, fixed lanes at their floor, runtime lanes)
	var lanes: Array = []
	for l: Array in (WorldLanes.LANES + WorldLanes.extra_lanes if WorldLanes.legacy else WorldLanes.extra_lanes):
		var pts: Array = []
		for v: Vector2 in l[1]: pts.append(Vector3(v.x, NAN, v.y))
		lanes.append([l[0], pts])
	for l: Array in (WorldLanes.FIXED_LANES if WorldLanes.legacy else []):
		lanes.append([l[0], l[1]])
	for l: Array in lanes:
		var pts: Array = l[1]
		var seen := {}
		for k in pts.size() - 1:
			var a: Vector3 = pts[k]; var b: Vector3 = pts[k + 1]
			var n := maxi(1, int(Vector2(b.x - a.x, b.z - a.z).length() / 0.5))
			for i in n + 1:
				var s := a.lerp(b, float(i) / float(n))
				var top := 60.0 if is_nan(a.y) else s.y + 1.8
				var fh := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(s.x, top, s.z), Vector3(s.x, top - 70.0, s.z), Layers.WORLD))
				if fh.is_empty(): continue
				var q := PhysicsShapeQueryParameters3D.new(); q.shape = cap; q.collision_mask = PROXY
				q.transform = Transform3D(Basis.IDENTITY, (fh.position as Vector3) + Vector3.UP * 1.25)
				for r in space.intersect_shape(q, 6):
					var src := String((r.collider as Node).get_meta("src", "?"))
					if not seen.has(src):
						seen[src] = true
						fail("LANE", "%s blocked by %s" % [l[0], src], fh.position)
	# 2. portals: approach box must be empty of anything but the building's own threshold
	for pt in WorldLanes.portals:
		var pb: Array = WorldLanes.portal_box(pt)
		var bs := BoxShape3D.new(); bs.size = (pb[1] as Vector3) * 2.0
		var q := PhysicsShapeQueryParameters3D.new(); q.shape = bs; q.transform = pb[0]; q.collision_mask = PROXY | Layers.WORLD | Layers.PROPS
		var seen := {}
		for r in space.intersect_shape(q, 16):
			var c := r.collider as Node
			var src := String(c.get_meta("src", c.get_path()))
			if src.contains("TerrainBody") or seen.has(src): continue
			if c.get_parent() is WardSeal: continue   # r30: a seal across its own gateway IS the threshold
			seen[src] = true
			fail("PORTAL", "%s obstructed by %s" % [pt.name, src], (pb[0] as Transform3D).origin)
	# 3. sites vs solids that do not belong to the site
	for st in WorldLanes.sites:
		var r2: Rect2 = st.rect
		var bs: Shape3D
		if st.has("circle"):              # r34: a round site (terrace, raid floor) by its circle, not its box
			var cy := CylinderShape3D.new(); cy.radius = (st.circle as Vector3).z; cy.height = 6.0
			bs = cy
		else:
			var bx := BoxShape3D.new(); bx.size = Vector3(r2.size.x, 6.0, r2.size.y)
			bs = bx
		var q := PhysicsShapeQueryParameters3D.new(); q.shape = bs; q.collision_mask = PROXY | Layers.WORLD | Layers.PROPS
		q.transform = Transform3D(Basis.IDENTITY, Vector3(r2.get_center().x, float(st.floor_y) + 3.2, r2.get_center().y))
		var seen := {}
		for r in space.intersect_shape(q, 32):
			var c := r.collider as Node
			var src := String(c.get_meta("src", c.get_path()))
			var own := String(c.get_meta("site_of", ""))
			if own != "" or src.contains("TerrainBody") or seen.has(src): continue
			if src.contains("FenWater"): continue          # r34: the fen's water surface is no solid (the drowned graves stand in it)
			if (st.get("owners", []) as Array).any(func(o: String) -> bool: return src.contains(o)): continue   # r34: a zone's own builders
			var anc := c
			var mine := false
			while anc:
				if anc.has_meta("site"): mine = true; break
				anc = anc.get_parent()
			if mine: continue
			seen[src] = true
			fail("SITE", "%s overlaps %s" % [st.name, src], Vector3(r2.get_center().x, st.floor_y, r2.get_center().y))
	# 4. seals and arenas (if present)
	for s in get_tree().get_nodes_in_group(&"ward_seal"):
		if s.has_method("audit"):
			for msg: String in s.audit(): fail("SEAL", msg, (s as Node3D).global_position)
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if a.has_method("audit"):
			for msg: String in a.audit(): fail("ARENA", msg, (a as Node3D).global_position)
	print("AUDIT PASS" if fails == 0 else "AUDIT FAIL %d" % fails)
	get_tree().quit()
