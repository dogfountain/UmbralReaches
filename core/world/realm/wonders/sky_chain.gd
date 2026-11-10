extends RefCounted
## THE SKY CHAIN (a wonder, core/world/realm/realm_wonders.gd): the mooring the Order cut into the Crowns' foot when the
## sky began to turn. LORE: the Order taught that the sky was a door, and when the door began to swing inward the
## Hierarch feared it would close on the faithful still climbing. He ordered it held. The Founder, who had cast the
## three bells in the Pits just east of here, forged one more thing: a chain of a thousand and nine links, each the
## length of three men, and the faithful hauled it up the Crowns hand over hand to a capstan hewn out of the mountain's
## own foot. Its bitter end is pinned to a ring set in the living rock; the rest is wound round the drum and goes up
## into the vortex. It still holds, or seems to: the wardens count it every dusk and it comes out one short.
##
## What is built (all modelled in Blender by script, tools/blender/wonder_sky_chain.py): the bay cut into the hill (the
## ground stamp cuts it to the court's height), the court paved and worn by the chain's dragging, the capstan drum
## (14 m across, 9 m tall) bound with iron and grooved where the chain lies, the ring, the man-sized pin and the wedges
## in the rock wall, the wardens' lodge, a pilgrims' stair rising along the front past the open door to the court, hewn
## buttresses, the Order's frieze, offerings. The chain is placed from the Blender frames
## (art/models/wonders/sky_chain_chain.json): hammered, pitted, collared and cracked links, the first sixteen real
## geometry with collision, the rest cheaper meshes that sway a little and fade into the vortex (far_links.gdshader).
## The secret (the wardens' box and the tally stone) is core/life/secrets/site_sky_chain.gd.
## Clearance: stand-in bodies for the collision-less meshes near and a box query for each solid piece (the Threshold's
## way); the line "WONDER sky_chain clearance:" is printed at build.

const WestKit := preload("res://core/world/realm/west_marches_kit.gd")
const FAR_SHADER := preload("res://core/world/realm/wonders/sky_chain/far_links.gdshader")
const CLOTH_SHADER := preload("res://core/world/realm/wonders/sky_chain/cloth.gdshader")
const ANCHOR := "wonders/sky_chain_anchor.glb"
const LINKS := "res://art/models/wonders/sky_chain_link.glb"
const FRAMES := "res://art/models/wonders/sky_chain_chain.json"
const PROBE_LAYER := 1 << 30           ## stand-in bodies' physics layer while the wonder is placed
const HI_LINKS := 16                   ## links with real geometry and collision
const MID_LINKS := 36                  ## links up to here use the mid mesh

var space: PhysicsDirectSpaceState3D
var rng := RandomNumberGenerator.new()
var host: Node3D
var geo: Dictionary = {}
var frames: Array = []
var report: Array[String] = []
var _audit: Array[String] = []
var _last_hit := ""
var _temp: Array[Node] = []
var _cols: Array[AABB] = []
var _faces := PackedVector3Array()     ## the wonder's collision (one trimesh body)
var _meshes: Dictionary = {}           ## link meshes by name
var _bright: Dictionary = {}           ## the tiling sets, lifted a little for a landmark that stands out in the dark


static func build(root: Node) -> void:
	var sc := new()
	await sc._build(root)


func _build(root: Node) -> void:
	rng.seed = 3703
	var js := load(FRAMES) as JSON
	if js == null:
		push_error("WONDER sky_chain: no frames file")
		return
	geo = (js.data as Dictionary).geo
	frames = (js.data as Dictionary).links
	space = (root as Node3D).get_world_3d().direct_space_state
	host = Node3D.new()
	host.name = "RealmSkyChain"
	root.add_child(host)
	_sites()
	_collect_instances(root)
	_stand_ins(root)
	await root.get_tree().physics_frame
	_audit_footprint()
	_model()
	_collision()
	_chain()
	_offerings()
	_lights()
	_marker()
	print("SITES SkyChain owns %d scatter nodes" % WorldLanes.own(host))   # the chain, candles and cloths stand inside its sites on purpose
	for b in _temp:
		b.queue_free()
	_temp.clear()
	report.append("stair x %.1f..%.1f from y %.2f, court %.1f, %d links" % [float(geo.xs), float(geo.xt), float(geo.y0), float(geo.deck), frames.size()])
	report.append("clearance: %s" % ("nothing touched" if _audit.is_empty() else "; ".join(_audit)))
	for s in report:
		print("WONDER sky_chain ", s)
	await root.get_tree().physics_frame


# --- sites -----------------------------------------------------------------------------------------------

func _sites() -> void:
	var xs: float = geo.xs
	var deck: float = geo.deck
	# the bay: the hill behind is cut back to the court (a sheer quarried face)
	WorldLanes.register_site("sky_chain", Rect2(xs, float(geo.zn), float(geo.x1) - xs + 0.4, float(geo.zw) - float(geo.zn)), deck, deck - 0.3, true)
	# the stair: each flight is a corridor the ground is cut away under (it never pokes through a tread)
	var zmid := (float(geo.zw) + float(geo.zs)) * 0.5 - 0.25
	var i := 0
	for s: Dictionary in geo.segs:
		WorldLanes.register_flight("sky_chain_flight%d" % i, Vector3(float(s.x0), float(s.y0), zmid), Vector3(float(s.x1), float(s.y1), zmid), 2.2)
		i += 1
	WorldLanes.register_flight("sky_chain_landing", Vector3(float(geo.xt), deck, zmid), Vector3(float(geo.x1), deck, zmid), 2.2)
	# the approach and the front, kept clear of flora and dress, never cut
	WorldLanes.register_site("sky_chain_court", Rect2(xs - 8.0, float(geo.zs) + 0.5, float(geo.x1) - xs + 12.0, 12.0), 0.0, 90.0)
	for p: Vector2 in [Vector2(xs, float(geo.zs)), Vector2(float(geo.xt), float(geo.zs)), Vector2(float(geo.x1), float(geo.zw)), Vector2(xs + 15.0, float(geo.zs) + 10.0)]:
		var pd := RealmLayout.path_dist(p)
		if pd < 6.0:
			_audit.append("a path runs %.1f m from %s" % [pd, p])


# --- clearance (the Threshold's way) -------------------------------------------------------------------------

func _area() -> AABB:
	var xs: float = geo.xs
	return AABB(Vector3(xs - 12.0, -10.0, float(geo.zn) - 14.0), Vector3(float(geo.x1) - xs + 30.0, 100.0, float(geo.zs) - float(geo.zn) + 40.0))


func _collect_instances(root: Node) -> void:
	var area := _area()
	for n in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or host.is_ancestor_of(mmi):
			continue
		var path := String(mmi.get_path())
		if path.contains("Flora") or path.contains("Grass"):
			continue
		if not (mmi.global_transform * mmi.get_aabb()).intersects(area):
			continue
		var mb := mmi.multimesh.mesh.get_aabb()
		for i in mmi.multimesh.instance_count:
			var bb: AABB = mmi.global_transform * mmi.multimesh.get_instance_transform(i) * mb
			if bb.intersects(area):
				_cols.append(bb)


func _stand_ins(root: Node) -> void:
	var area := _area()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or host.is_ancestor_of(mi):
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if not bb.intersects(area) or bb.size.x * bb.size.z > 6000.0:
			continue
		var path := String(mi.get_path())
		if path.contains("Terrain") or path.contains("Flora") or path.contains("Water") or path.contains("Fall"):
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.name = "StandIn"
		body.collision_layer = PROBE_LAYER
		body.collision_mask = 0
		body.set_meta(&"stands_for", path.trim_prefix("/root/Main/"))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		host.add_child(body)
		body.global_transform = mi.global_transform
		_temp.append(body)


func _clear(xf: Transform3D, size: Vector3, grow := 0.2) -> bool:
	var sh := BoxShape3D.new()
	sh.size = size + Vector3.ONE * grow * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = xf
	q.collision_mask = Layers.WORLD | PROBE_LAYER
	for hit: Dictionary in space.intersect_shape(q, 24):
		var c := hit.get("collider") as Node
		if c != null and (host.is_ancestor_of(c) or String(c.name).begins_with("Terrain")):
			continue                         # the ground is the stamp's business: the structure keys into it
		_last_hit = String(c.get_meta(&"stands_for", c.get_path())) if c else "?"
		return false
	var bb: AABB = xf * AABB(-size * 0.5 - Vector3.ONE * grow, size + Vector3.ONE * grow * 2.0)
	for cb: AABB in _cols:
		if cb.intersects(bb):
			_last_hit = "an instanced piece at %s" % cb.get_center().snapped(Vector3.ONE * 0.1)
			return false
	return true


func _check(label: String, lo: Vector3, hi: Vector3, grow := 0.2) -> void:
	if not _clear(Transform3D(Basis.IDENTITY, (lo + hi) * 0.5), hi - lo, grow):
		_audit.append("%s touches %s" % [label, _last_hit])


func _audit_footprint() -> void:
	var xs: float = geo.xs
	var deck: float = geo.deck
	_check("bay", Vector3(xs, deck - 6.0, float(geo.zn)), Vector3(float(geo.x1), deck + 14.0, float(geo.zs)), 0.0)
	_check("stair foot", Vector3(xs - 3.0, 0.0, float(geo.zs) - 1.0), Vector3(xs + 8.0, 12.0, float(geo.zs) + 6.0), 0.0)
	_check("ribs", Vector3(xs, -1.0, float(geo.zs)), Vector3(float(geo.x1), 14.0, float(geo.zs) + 6.0), 0.0)


# --- the model -----------------------------------------------------------------------------------------------

func _model() -> void:
	var root3d := WestKit.place(host, ANCHOR, Transform3D.IDENTITY, {})
	if root3d == null:
		push_error("WONDER sky_chain: no anchor model")
		return
	root3d.name = "Anchor"
	# the house stone of the Crossing and the Ossuary (OssKit's triplanar ashlar), lifted a little; the rock a shade browner
	var bright := {}
	for set_name: String in ["ashlar", "stone"]:
		var m := OssKit.mat("stone").duplicate() as StandardMaterial3D
		m.albedo_color = Color(1.5, 1.5, 1.55) if set_name == "ashlar" else Color(1.4, 1.34, 1.25)
		m.rim_enabled = false
		m.emission_enabled = false
		bright[set_name] = m
	var im := WestKit.mat("iron").duplicate() as StandardMaterial3D
	im.albedo_color = Color(1.5, 1.5, 1.55)
	im.metallic = 0.4
	bright["iron"] = im
	_bright = bright
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.025, 0.025, 0.03)
	dark.roughness = 1.0
	for n in root3d.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if String(mi.name).contains("__dark"):
			mi.material_override = dark
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for sn: String in bright:
			if String(mi.name).contains("__" + sn):
				mi.material_override = bright[sn]
		mi.mesh = MeshChunks.with_lods(mi.mesh)
		mi.add_to_group(Groups.CULL_SKIP)
	report.append("anchor model placed")


# --- collision ---------------------------------------------------------------------------------------------------

func _box(lo: Vector3, hi: Vector3) -> void:
	var c := (lo + hi) * 0.5
	var h := (hi - lo).abs() * 0.5
	for s: float in [-1.0, 1.0]:
		for f: Array in [[Vector3(h.x, 0, 0), Vector3(0, h.y, 0), Vector3(0, 0, h.z)], [Vector3(0, h.y, 0), Vector3(h.x, 0, 0), Vector3(0, 0, h.z)], [Vector3(0, 0, h.z), Vector3(h.x, 0, 0), Vector3(0, h.y, 0)]]:
			var o: Vector3 = c + (f[0] as Vector3) * s
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var t := PackedVector3Array([o - u - v, o + u - v, o + u + v, o - u - v, o + u + v, o - u + v])
			if (t[1] - t[0]).cross(t[2] - t[0]).dot(f[0] as Vector3 * s) > 0.0:
				t = PackedVector3Array([t[0], t[2], t[1], t[3], t[5], t[4]])
			_faces.append_array(t)


func _stair_line(x: float) -> float:
	if x <= float(geo.xs):
		return float(geo.y0)
	for s: Dictionary in geo.segs:
		if x <= float(s.x1) + 0.0001:
			if not bool(s.up):
				return float(s.y0)
			return float(s.y0) + (x - float(s.x0)) * float(geo.rise) / float(geo.run)
	return float(geo.deck)


## The solid world of the wonder, as boxes: the court and its mass, the stair (every tread), the walls and parapets, the
## ribs, the lodge, the tally stone, the ring. The drum is a cylinder, the first links a trimesh (see _chain).
func _collision() -> void:
	var deck: float = geo.deck
	var xs: float = geo.xs
	var x1: float = geo.x1
	var zn: float = geo.zn
	var zw: float = geo.zw
	var zs: float = geo.zs
	var xt: float = geo.xt
	var zin := zw + 0.4
	var zout := zs - 0.9
	var base := -2.0
	_box(Vector3(xs, base, zn), Vector3(x1, deck - 0.03, zw))                  # the court and its mass
	_box(Vector3(xt, base, zw), Vector3(x1, deck - 0.03, zout))                # the landing
	_box(Vector3(xs, base, zw), Vector3(xt, deck, zin))                        # the stair's north wall
	for s: Dictionary in geo.segs:
		if bool(s.up):
			for i in int(s.n):
				var xa := float(s.x0) + float(i) * float(geo.run)
				var top := float(s.y0) + float(i + 1) * float(geo.rise)
				_box(Vector3(xa, top - 0.7, zin), Vector3(xa + float(geo.run) + 0.02, top - 0.02, zout))
		else:
			_box(Vector3(float(s.x0), float(s.y0) - 0.6, zin), Vector3(float(s.x1), float(s.y0) - 0.02, zout))
	for k in range(1, int(geo.foot_steps) + 1):                                 # the foot's lower treads
		var xa2 := xs - float(k) * float(geo.run)
		var top2 := float(geo.y0) + float(geo.rise) * float(1 - k)
		_box(Vector3(xa2, top2 - 0.7, zin), Vector3(xa2 + float(geo.run) + 0.02, top2 - 0.02, zout))
	var x := xs                                                                 # the south wall, stepped with the stair
	while x < x1 - 0.01:
		var xb := minf(x + 1.2, x1)
		var top := _stair_line(xb) + 0.95 if xb < xt else deck + 0.95
		_box(Vector3(x, base, zout), Vector3(xb, top, zs))
		x = xb
	_box(Vector3(xs, deck, zw - 0.55), Vector3(xt, deck + 1.0, zw - 0.05))      # the parapet over the stair
	_box(Vector3(x1 - 0.5, deck, zw), Vector3(x1, deck + 1.0, zout))            # the landing's east rail
	# the ribs: three boxes each, wide and deep at the foot
	for rx: float in [xs + 4.0, xs + 12.0, xs + 20.0, xs + 28.0, x1 - 2.0]:
		var gl := RealmLayout.ground(space, rx, zs + 1.0)
		var top2 := (_stair_line(rx) + 0.95 if rx < xt else deck + 0.95) - 0.25
		var h := top2 - (gl - 1.4)
		_box(Vector3(rx - 2.4, gl - 1.4, zs), Vector3(rx + 2.4, gl - 1.4 + h * 0.42, zs + 5.3))
		_box(Vector3(rx - 1.7, gl - 1.4, zs), Vector3(rx + 1.7, gl - 1.4 + h * 0.75, zs + 2.6))
		_box(Vector3(rx - 1.1, gl - 1.4, zs), Vector3(rx + 1.1, top2, zs + 1.0))
	# the lodge (walls to the eaves, the roof as two boxes), the tally and kneeling stones
	var lg: Array = geo.lodge
	var lh: float = geo.lodge_h
	_box(Vector3(float(lg[0]), deck - 1.0, float(lg[2])), Vector3(float(lg[1]), deck + lh, float(lg[3])))
	_box(Vector3(float(lg[0]), deck + lh, float(lg[2]) + 1.5), Vector3(float(lg[1]), deck + lh + 2.2, float(lg[3]) - 1.5))
	var ty: Array = geo.tally
	_box(Vector3(float(ty[0]) - 0.65, deck, float(ty[2]) - 0.2), Vector3(float(ty[0]) + 0.65, deck + 1.85, float(ty[2]) + 0.2))
	_box(Vector3(float(ty[0]) - 2.0, deck, float(ty[2]) + 0.0), Vector3(float(ty[0]) - 1.0, deck + 0.4, float(ty[2]) + 1.05))
	# the ring: four bars (it hangs from the pin in the wall)
	var rg: Array = geo.ring
	var rx2: float = rg[0]
	var ry: float = rg[1]
	var rz: float = rg[2]
	_box(Vector3(rx2 - 2.2, ry - 2.8, rz - 0.5), Vector3(rx2 + 2.2, ry - 1.8, rz + 0.5))
	_box(Vector3(rx2 - 2.2, ry + 1.8, rz - 0.5), Vector3(rx2 + 2.2, ry + 2.8, rz + 0.5))
	_box(Vector3(rx2 - 2.2, ry - 2.8, rz - 0.5), Vector3(rx2 - 1.2, ry + 2.8, rz + 0.5))
	_box(Vector3(rx2 + 1.2, ry - 2.8, rz - 0.5), Vector3(rx2 + 2.2, ry + 2.8, rz + 0.5))
	var body := StaticBody3D.new()
	body.name = "MooringBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_faces)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	host.add_child(body)
	# the drum
	var dr: Array = geo.drum
	for part: Array in [[6.6, 1.4, 0.0], [5.9, float(dr[2]) - deck - 1.0, 1.0]]:
		var cyl := CylinderShape3D.new()
		cyl.radius = float(part[0])
		cyl.height = float(part[1])
		var db := CollisionShape3D.new()
		db.shape = cyl
		body.add_child(db)
		db.position = Vector3(float(dr[0]), deck + float(part[2]) + float(part[1]) * 0.5 - (1.0 if part[2] == 0.0 else 0.0), float(dr[1]))


# --- the chain ----------------------------------------------------------------------------------------------------

func _link_meshes() -> void:
	var ps := load(LINKS) as PackedScene
	if ps == null:
		return
	var inst := ps.instantiate()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		_meshes[String(mi.name).get_slice("__", 0)] = mi.mesh
	inst.free()


func _chain() -> void:
	_link_meshes()
	# the near links: the house iron (the cages' and lanterns' set) over the rust vertex colours, a little less metal so the night
	# has something to light, a thin rim; the far ones keep the vortex-lit shader
	var iron := WestKit.mat("iron").duplicate() as StandardMaterial3D
	iron.albedo_color = Color(2.3, 2.3, 2.3)
	iron.metallic = 0.2
	iron.roughness = 0.75
	iron.rim_enabled = true
	iron.rim = 0.7
	iron.rim_tint = 0.5
	var groups: Dictionary = {}
	var coll_faces := PackedVector3Array()
	for k in frames.size():
		var f: Dictionary = frames[k]
		var p: Array = f.p
		var w := Vector3(float(f.w[0]), float(f.w[1]), float(f.w[2]))
		var t := Vector3(float(f.t[0]), float(f.t[1]), float(f.t[2]))
		var thk := w.cross(t).normalized()
		var sc := float(f.s)
		var xf := Transform3D(Basis(w * sc, t * sc, thk * sc), Vector3(float(p[0]), float(p[1]), float(p[2])))
		var key: String
		if k < HI_LINKS:
			key = "SkyChainLinkHi%d" % (k % 4)
		elif k < MID_LINKS:
			key = "SkyChainLinkMid%d" % (k % 2)
		else:
			key = "SkyChainLinkLo"
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf)
		if k < HI_LINKS and _meshes.has(key):
			var fc: PackedVector3Array = (_meshes[key] as Mesh).get_faces()
			for i in fc.size():
				coll_faces.append(xf * fc[i])
			_check("link %d" % k, xf.origin - Vector3.ONE * 2.2, xf.origin + Vector3.ONE * 2.2, 0.0)
	var far := ShaderMaterial.new()
	far.shader = FAR_SHADER
	far.set_shader_parameter("rim_gain", 4.0)
	far.set_shader_parameter("iron", Color(0.34, 0.33, 0.37))
	var counts: Array[String] = []
	# the first links are merged into one mesh each (a multimesh this small keeps an empty box in the engine and is culled
	# for good); the high links, many and far apart, stay a multimesh (the Realm's pass splits it into cells)
	for part: Array in [["SkyChainNear", "SkyChainLinkHi", true], ["SkyChainMid", "SkyChainLinkMid", false]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 0
		for key: String in groups:
			if key.begins_with(String(part[1])) and _meshes.has(key):
				for xf: Transform3D in groups[key]:
					st.append_from(_meshes[key] as Mesh, 0, xf)
					n += 1
		if n == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = st.commit()
		mi.material_override = iron
		if not bool(part[2]):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_to_group(Groups.CULL_SKIP)
		host.add_child(mi)
		counts.append("%s %d" % [String(part[0]).trim_prefix("SkyChain"), n])
	if groups.has("SkyChainLinkLo") and _meshes.has("SkyChainLinkLo"):
		var list: Array = groups["SkyChainLinkLo"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes["SkyChainLinkLo"]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "SkyChainFar"
		mmi.multimesh = mm
		mmi.material_override = far
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.add_to_group(Groups.CULL_SKIP)
		mmi.ignore_occlusion_culling = true
		host.add_child(mmi)
		counts.append("Far %d" % list.size())
	if coll_faces.size() >= 3:
		var body := StaticBody3D.new()
		body.name = "ChainBody"
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(coll_faces)
		shape.backface_collision = true
		cs.shape = shape
		body.add_child(cs)
		host.add_child(body)
	var top: Dictionary = frames[frames.size() - 1]
	report.append("chain: %s, top at y %.0f" % [", ".join(counts), float(top.p[1])])


# --- offerings, lights, marker -------------------------------------------------------------------------------------

func _ribbon(length: float, w: float, col: Color, seed_v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var rows := 6
	var twist := r.randf_range(-0.5, 0.5)
	for i in rows + 1:
		var t := float(i) / float(rows)
		var ang := twist * t
		var dx := Vector3(cos(ang), 0.0, sin(ang)) * (w * 0.5 * (1.0 - 0.15 * t))
		var cut := length * 0.12 if i == rows else 0.0
		verts.append(Vector3(0.0, -length * t + cut, 0.0) - dx)
		verts.append(Vector3(0.0, -length * t + cut, 0.0) + dx)
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
		norms.append(Vector3(-sin(ang), 0.0, cos(ang)))
		norms.append(Vector3(-sin(ang), 0.0, cos(ang)))
		var tone := col * r.randf_range(0.86, 1.06)
		cols.append(tone)
		cols.append(tone)
	for i in rows:
		idx.append_array(PackedInt32Array([i * 2, i * 2 + 2, i * 2 + 1, i * 2 + 1, i * 2 + 2, i * 2 + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _offerings() -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	k.candle_lights = false
	var deck: float = geo.deck
	var dr: Array = geo.door
	var dy := float(dr[1]) + 0.22
	var zw: float = geo.zw
	# the open door's threshold: pilgrims lit a candle for each of theirs
	for dx: float in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		k.candle_cluster(Vector3(float(dr[0]) + dx, dy, zw + 1.3), rng.randi_range(4, 8), 0.28, rng)
	var ty: Array = geo.tally
	k.candle_cluster(Vector3(float(ty[0]) - 1.5, deck + 0.4, float(ty[2]) + 0.55), 5, 0.22, rng)
	k.candle_cluster(Vector3(float(ty[0]) + 1.0, deck, float(ty[2]) + 0.6), 4, 0.25, rng)
	var lg: Array = geo.lodge
	k.candle_cluster(Vector3((float(lg[0]) + float(lg[1])) * 0.5 + 1.6, deck, float(lg[3]) + 0.8), 4, 0.2, rng)
	k.commit(host, "Candles")
	# cloths tied to the stair's newels
	var cols := [Color(0.62, 0.16, 0.12), Color(0.72, 0.62, 0.46), Color(0.55, 0.42, 0.18), Color(0.28, 0.36, 0.5)]
	var mat := ShaderMaterial.new()
	mat.shader = CLOTH_SHADER
	var by: Dictionary = {}
	var newels: Array[float] = []
	for s: Dictionary in geo.segs:
		newels.append(float(s.x1))
	newels.append(float(geo.x1) - 0.5)
	for nx: float in newels:
		if rng.randf() < 0.85:
			var top := (_stair_line(nx - 0.01) + 0.95 if nx < float(geo.xt) else deck + 0.95) + 1.2
			var ci := rng.randi() % cols.size()
			if not by.has(ci):
				by[ci] = []
			(by[ci] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(nx, top, float(geo.zs) - 0.4)))
	for ci: int in by:
		var list: Array = by[ci]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _ribbon(rng.randf_range(1.0, 1.6), rng.randf_range(0.22, 0.34), cols[ci], ci + 3)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Cloths%d" % ci
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 150.0
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		host.add_child(mmi)


func _lights() -> void:
	var dr: Array = geo.door
	var dc: Array = geo.drum
	var spec := [
		[Vector3(float(dr[0]), float(dr[1]) + 1.6, float(geo.zw) + 2.2), Color(1.0, 0.62, 0.32), 1.0, 12.0, "DoorCandles"],
		[Vector3(float(dc[0]) - 2.0, float(dc[2]) - 1.0, float(dc[1]) - 1.0), Color(0.68, 0.64, 0.92), 2.6, 46.0, "ChainGlow"],
		[Vector3(float(dc[0]), float(geo.deck) - 1.0, float(geo.zs) + 3.0), Color(0.7, 0.74, 0.95), 3.0, 46.0, "FaceFill"],
	]
	for s: Array in spec:
		var l := OmniLight3D.new()
		l.name = s[4]
		l.light_color = s[1]
		l.light_energy = s[2]
		l.omni_range = s[3]
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 70.0
		l.distance_fade_length = 24.0
		l.set_meta(&"light_class", &"fill")
		host.add_child(l)
		l.position = s[0]


func _marker() -> void:
	var mark := Node3D.new()
	mark.name = "ChainTop"
	var ty: Array = geo.tally
	var tally := Vector3(float(ty[0]), float(ty[1]), float(ty[2]))
	mark.set_meta("top", tally)
	mark.set_meta("basis", Basis.IDENTITY)
	mark.set_meta("deck", float(geo.deck))
	host.add_child(mark)
	mark.global_position = tally
