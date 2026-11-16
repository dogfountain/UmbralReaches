extends RefCounted
## The Far Reaches' towns (docs/far_reaches.md): Reedholm on the Reedmere, Fallowmere in the low fields, Lastlight at
## the road's east end. The plan is reach_towns_plan.gd, the models art/models/reach_towns.glb (tools/blender/
## reach_towns.py), their collision and numbers reach_towns_boxes.gd. Built by realm_pois.gd (REACH_POIS):
##   reserve(root)  before the terrain stamp and the flora: each building's ground is a site (the stamp cuts the
##                  hillside out of its floor; camps, the wayside and the undergrowth keep off it); trees keep off
##                  the towns' streets and decks
##   build(holder)  after the flora: every piece by ground ray (Reedholm's by the water line), its collision, its far
##                  silhouette where it has one, the lit glass, the yards' clutter, the writings, a few warm lights
## The people's side is village.gd's: walks() lays their walking nodes and anchors, decks() tells the village's
## network where it walks on boards over water. lamps() are the towns' lamps for lamp_places.gd.
## `-- --no-towns` builds the Realm without them (perf A/B). No class_name: preload by path.

const Plan := preload("res://core/world/realm/reach_towns_plan.gd")
const Boxes := preload("res://core/world/realm/reach_towns_boxes.gd")
const Kit := preload("res://core/world/realm/south_marches_kit.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const SiteProps := preload("res://core/world/realm/site_props.gd")
const P := preload("res://core/world/realm/realm_pois.gd")
const Footing := preload("res://core/world/footing.gd")

const WATER := -0.9                 ## the fen's water line (RealmLand.WATER_Y): Reedholm's decks hang from it
const WALK_STEP_RUN := 3.0          ## RH_WalkStep's run from the walk down to the bank
const MERGE_VIS := 200.0            ## a piece whose own fade would be this far or more goes into the town's merged mesh
const NEAR_END := 230.0             ## the merged town fades to its far silhouette here
const PROPS_END := 140.0            ## and its small things end here
const FAR_COLOR := Color(0.16, 0.17, 0.2)       ## FarDetail.hull's: fog and the grade colour it

static var placed: Array[Dictionary] = []      ## last build: {kind, town, xf} (tests, stills, the people's walks)
static var walk_decks: Array[Dictionary] = []  ## {rect: Rect2, y} for village_nav (boardwalks and house decks)
static var ground_y := {}                      ## "kind@x,z" -> the ground the piece was set on (reserve -> build)
static var _box_map := {}
static var _glass := {}


static func release() -> void:
	placed.clear()
	walk_decks.clear()
	ground_y.clear()
	_box_map.clear()
	_glass.clear()


static func off() -> bool:
	return "--no-towns" in OS.get_cmdline_user_args()


static func _key(kind: String, x: float, z: float) -> String:
	return "%s@%d,%d" % [kind, roundi(x * 10.0), roundi(z * 10.0)]


## A piece's footprint corners in the world (its KIND rect turned by yaw).
static func _corners(kind: String, at: Vector2, yaw: float, grow := 0.0) -> Array[Vector2]:
	var rc: Rect2 = (Plan.KIND[kind] as Dictionary).rect
	rc = rc.grow(grow)
	var out: Array[Vector2] = []
	for c: Vector2 in [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]:
		out.append(at + _rot(c, yaw))
	return out


## Local xz -> world offset under a yaw (Basis(UP, yaw): local +z goes to (sin, cos)).
static func _rot(v: Vector2, yaw: float) -> Vector2:
	return Vector2(v.x * cos(yaw) + v.y * sin(yaw), -v.x * sin(yaw) + v.y * cos(yaw))


static func _aabb(pts: Array[Vector2]) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p: Vector2 in pts:
		r = r.expand(p)
	return r


## The terrain under a point, through whatever stands on it (a tree, a reed clump, a prop): RealmLayout.ground falls back
## to the coarse macro height when its first hit is not the terrain, a metre off in the meres.
static func _terrain(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return Footing.terrain_y(space, x, z, RealmLayout.macro_height(x, z))


## The lowest and highest ground under a piece (a 5 x 5 grid over its turned footprint).
static func _under(space: PhysicsDirectSpaceState3D, kind: String, at: Vector2, yaw: float) -> Vector2:
	var rc: Rect2 = (Plan.KIND[kind] as Dictionary).rect
	var lo := INF
	var hi := -INF
	for i in 5:
		for j in 5:
			var q := at + _rot(rc.position + rc.size * Vector2(i / 4.0, j / 4.0), yaw)
			var y := _terrain(space, q.x, q.y)
			lo = minf(lo, y)
			hi = maxf(hi, y)
	return Vector2(lo, hi)


# --- reserve (before the stamp and the flora) ------------------------------------------------------------------------

static func reserve(root: Node) -> void:
	release()
	if off():
		return
	var space := (root as Node3D).get_world_3d().direct_space_state
	for t: String in Plan.TOWNS:
		var d: Dictionary = Plan.TOWNS[t]
		# no trees in the town (the yards, the decks, the fields' edges)
		Flora.tree_clear.append([d.c as Vector2, float(d.r)])
	for c: Array in Plan.CLEAR:
		Flora.tree_clear.append([c[0] as Vector2, float(c[1])])
	for bk: Array in Plan.BANKS:
		WorldLanes.register_terrace("poi_town_bank_%d_%d" % [roundi((bk[0] as Vector2).x), roundi((bk[0] as Vector2).y)], bk[0], float(bk[1]), float(bk[2]))
	for pc: Array in _pieces():
		var kind := String(pc[1])
		var at := Vector2(float(pc[2]), float(pc[3]))
		var yaw := float(pc[4])
		var k: Dictionary = Plan.KIND[kind]
		var ul := _under(space, kind, at, yaw)
		var y := ul.x
		if bool(k.get("stilt", false)):
			continue
		ground_y[_key(kind, at.x, at.y)] = y
		var rc := _aabb(_corners(kind, at, yaw, 0.2))
		if rc.size.x * rc.size.y > 30.0 or kind.begins_with("LL_"):
			WorldLanes.register_site("poi_town_%s_%d_%d" % [kind.to_lower(), roundi(at.x), roundi(at.y)], rc, y + 0.05, y - 0.1)
	# Reedholm's decks and walks are sites too (no reeds up through the boards, no camp under them)
	for pc: Array in _pieces():
		var kind2 := String(pc[1])
		if bool((Plan.KIND[kind2] as Dictionary).get("stilt", false)) and kind2 != "RH_Punt":
			var at2 := Vector2(float(pc[2]), float(pc[3]))
			WorldLanes.register_site("poi_town_%s_%d_%d" % [kind2.to_lower(), roundi(at2.x), roundi(at2.y)], _aabb(_corners(kind2, at2, float(pc[4]), 0.3)), 2.0, 50.0)
	for w: Dictionary in Plan.WALKS:
		var pts: Array = w.pts
		for i in pts.size() - 1:
			var r := Rect2(pts[i] as Vector2, Vector2.ZERO).expand(pts[i + 1] as Vector2).grow(1.3)
			WorldLanes.register_site("poi_town_walk_%d_%d" % [roundi((pts[i] as Vector2).x), roundi((pts[i] as Vector2).y)], r, 2.0, 50.0)
	print("REACH_TOWNS reserved %d sites" % ground_y.size())


## Every piece of the plan, Lastlight's walls and towers included.
static func _pieces() -> Array:
	var out: Array = Plan.PIECES.duplicate()
	out.append_array(_wall_pieces())
	return out


## Lastlight's curtain as pieces: a tower on each corner, each side filled between them with LL_Wall (stretched a
## little to fit) round its gate or postern. Each entry: [town, kind, x, z, yaw, scale_x].
static func _wall_pieces() -> Array:
	var out: Array = []
	for c: Vector2 in Plan.WALL_CORNERS:
		out.append(["lastlight", "LL_WallTower", c.x, c.y, 0.0, 1.0])
	for w: Dictionary in Plan.WALLS:
		var a: Vector2 = Plan.WALL_CORNERS[int(w.a)]
		var b: Vector2 = Plan.WALL_CORNERS[int(w.b)]
		var dir := (b - a).normalized()
		var ln := a.distance_to(b)
		var yaw := float(w["in"])
		# the stretches between the corners' towers and the breaks
		var cuts: Array = [[Plan.TOWER_KEEP, ""]]
		for br: Array in w.breaks:
			var s := _along(a, dir, float(br[1]))
			var half := float(Plan.BREAK_W[String(br[0])]) * 0.5
			cuts.append([s - half, ""])
			cuts.append([s + half, String(br[0])])
			var m := a + dir * s
			out.append(["lastlight", String(br[0]), m.x, m.y, yaw, 1.0])
		cuts.append([ln - Plan.TOWER_KEEP, ""])
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var i := 0
		while i < cuts.size() - 1:
			var s0 := float(cuts[i][0])
			var s1 := float(cuts[i + 1][0])
			if s1 - s0 > 0.5 and not _inside_break(w, a, dir, (s0 + s1) * 0.5):
				var n := maxi(1, roundi((s1 - s0) / 10.0))
				var seg := (s1 - s0) / float(n)
				for k in n:
					var m2 := a + dir * (s0 + seg * (k + 0.5))
					out.append(["lastlight", "LL_Wall", m2.x, m2.y, yaw, seg / 10.0])
			i += 1
	return out


## How far along a side a break's coordinate is (x for a side along x, z for one along z).
static func _along(a: Vector2, dir: Vector2, coord: float) -> float:
	return (coord - a.x) / dir.x if absf(dir.x) > 0.5 else (coord - a.y) / dir.y


static func _inside_break(w: Dictionary, a: Vector2, dir: Vector2, s: float) -> bool:
	for br: Array in w.breaks:
		var c := _along(a, dir, float(br[1]))
		if absf(s - c) < float(Plan.BREAK_W[String(br[0])]) * 0.5 - 0.05:
			return true
	return false


# --- build (after the flora) -----------------------------------------------------------------------------------------

static func build(holder: Node) -> void:
	placed.clear()
	walk_decks.clear()
	if off():
		return
	var t0 := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "ReachTowns"
	root.set_meta("site", "reach_towns")
	holder.add_child(root)
	var space := root.get_world_3d().direct_space_state
	var hosts := {}
	var shapes := {}
	for t: String in Plan.TOWNS:
		var h := Node3D.new()
		h.name = "Town_" + t
		h.set_meta("site", "town_" + t)
		h.set_meta("title", (Plan.TOWNS[t] as Dictionary).name)
		h.set_meta("line", (Plan.TOWNS[t] as Dictionary).line)
		root.add_child(h)
		h.add_to_group(P.GROUP_POI)
		h.set_meta("poi", "town_" + t)
		h.set_meta("reach", true)                       # a Far Reaches place (zz/world_poi_test counts these apart from the older places)
		h.set_meta("centre", Vector3((Plan.TOWNS[t].c as Vector2).x, 0.0, (Plan.TOWNS[t].c as Vector2).y))
		h.set_meta("radius", float(Plan.TOWNS[t].r))
		hosts[t] = h
		shapes[t] = []
	var merge := {}                                   # town -> {"near": {Material: SurfaceTool}, "far": SurfaceTool}
	for t2: String in Plan.TOWNS:
		merge[t2] = {"near": {}, "far": null, "props": {}, "later": []}
	for pc: Array in _pieces():
		_piece(hosts[String(pc[0])], shapes[String(pc[0])], space, pc, merge[String(pc[0])])
	_walks(hosts["reedholm"], shapes["reedholm"], space, merge["reedholm"])
	_fields(hosts["fallowmere"], shapes["fallowmere"], space)
	for t3: String in merge:
		_commit(hosts[t3], t3, merge[t3])
	for t: String in shapes:
		Kit.body(hosts[t], "TownBody", shapes[t])
	var Dress: Variant = load("res://core/world/realm/reach_towns_dress.gd")
	Dress.dress(hosts, shapes, space)
	_props_later(holder.get_parent() if holder.get_parent() else holder, hosts, merge)
	print("REACH_TOWNS built %d pieces, %d deck rects in %d ms" % [placed.size(), walk_decks.size(), Time.get_ticks_msec() - t0])


## One piece: its place on the ground, its boxes; its mesh into the town's merged one (a building, a wall, a deck) or its
## own instance with a short range (the small things), and its far silhouette into the town's.
static func _piece(host: Node3D, shapes: Array, space: PhysicsDirectSpaceState3D, pc: Array, merge: Dictionary) -> void:
	var kind := String(pc[1])
	var at := Vector2(float(pc[2]), float(pc[3]))
	var yaw := float(pc[4])
	var sx := float(pc[5]) if pc.size() > 5 else 1.0
	var k: Dictionary = Plan.KIND.get(kind, {"rect": Rect2(-5, -1.3, 10, 2.6), "vis": 0.0})
	var y := 0.0
	if bool(k.get("stilt", false)):
		y = _stilt_y(space, kind, at, yaw)
	else:
		y = float(ground_y.get(_key(kind, at.x, at.y), NAN))
		if is_nan(y):
			y = _under(space, kind, at, yaw).x
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sx, 1.0, 1.0)), Vector3(at.x, y, at.y))
	var vis := float(k.get("vis", 0.0))
	var far := String(k.get("far", ""))
	if far != "" or vis == 0.0 or vis >= MERGE_VIS:
		var m := Kit.mesh(Plan.GLB, kind)
		if m == null:
			return
		_add_near(merge, m, xf)
		var fm: Mesh = Kit.mesh(Plan.GLB, far) if far != "" else null
		if fm == null:
			fm = FarDetail.hull(m.get_aabb(), 0.45)
		_add_far(merge, fm, xf)
	else:
		# a small thing stands on the ground as it is once the stamp and the flora are done (_props_later)
		(merge.later as Array).append([kind, at, yaw])
		return
	_cols(shapes, kind, xf)
	placed.append({"kind": kind, "town": String(pc[0]), "xf": xf})


## A mesh's surfaces into the town's merged near mesh, one surface a material (a town is a dozen draws, not hundreds).
static func _add_near(merge: Dictionary, m: Mesh, xf: Transform3D, part := "near") -> void:
	var near: Dictionary = merge[part]
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		var st: SurfaceTool = near.get(mat)
		if st == null:
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(mat)
			near[mat] = st
		st.append_from(m, i, xf)


## One ArrayMesh from a {Material: SurfaceTool} set, the lit glass swapped in.
static func _merged(sts: Dictionary) -> ArrayMesh:
	var am := ArrayMesh.new()
	for mat: Variant in sts:
		(sts[mat] as SurfaceTool).commit(am)
	for i in am.get_surface_count():
		var mt := am.surface_get_material(i)
		if mt != null and String(mt.resource_name) in ["window_glass", "lamp_glass"]:
			am.surface_set_material(i, _glass_mat(String(mt.resource_name)))
	return am


static func _add_far(merge: Dictionary, fm: Mesh, xf: Transform3D) -> void:
	if merge.far == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		merge.far = st
	(merge.far as SurfaceTool).append_from(fm, 0, xf)


## The town's merged mesh (lit glass swapped in) under its own node, and its merged far silhouette taking over from
## NEAR_END (FarDetail: the near mesh fades out as the far one fades in).
## The towns' small things (racks, boats, ricks, scarecrows, a well, a wain), once the Realm is done (after the terrain
## stamp, the flora and the settle): each on the ground as it then is, then merged per town into one mesh a material on
## a short range, with its own body.
static func _props_later(root: Node, hosts: Dictionary, merge: Dictionary) -> void:
	var tree := root.get_tree()
	var t0 := Time.get_ticks_msec()
	# after the terrain settle too (the ground yields to the floors as built, and the meres' beds with it)
	while is_instance_valid(root) and not root.has_meta("realm_done") and Time.get_ticks_msec() - t0 < 240000:
		await tree.process_frame
	if not is_instance_valid(root):
		return
	await tree.physics_frame
	for town: String in merge:
		var host: Node3D = hosts[town]
		if not is_instance_valid(host):
			continue
		var space := host.get_world_3d().direct_space_state
		var shapes: Array = []
		var m: Dictionary = merge[town]
		for it: Array in m.later:
			var kind := String(it[0])
			var at: Vector2 = it[1]
			var yaw := float(it[2])
			var y := _stilt_y(space, kind, at, yaw) if bool((Plan.KIND[kind] as Dictionary).get("stilt", false)) else _under(space, kind, at, yaw).x
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, y, at.y))
			var mesh := Kit.mesh(Plan.GLB, kind)
			if mesh == null:
				continue
			_add_near(m, mesh, xf, "props")
			_cols(shapes, kind, xf)
			placed.append({"kind": kind, "town": town, "xf": xf})
		if not (m.props as Dictionary).is_empty():
			var pmi := MeshInstance3D.new()
			pmi.name = "Town_%s_Props" % town
			pmi.mesh = _merged(m.props)
			pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			pmi.visibility_range_end = PROPS_END
			pmi.visibility_range_end_margin = PROPS_END * 0.12
			pmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			pmi.add_to_group(Groups.CULL_SKIP)
			host.add_child(pmi)
		if not shapes.is_empty():
			Kit.body(host, "PropsBody", shapes)
	root.set_meta("towns_props_done", true)


static func _commit(host: Node3D, town: String, merge: Dictionary) -> void:
	var near: Dictionary = merge.near
	if near.is_empty():
		return
	var am := _merged(near)
	var node := Node3D.new()
	node.name = "Near"
	host.add_child(node)
	var mi := MeshInstance3D.new()
	mi.name = "Town_%s_Merged" % town
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_child(mi)
	if merge.far != null:
		# one matte silhouette colour throughout (the modelled ones carry their weathering tints, the hulls a dark one)
		var arr := (merge.far as SurfaceTool).commit_to_arrays()
		var nv := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var cols := PackedColorArray()
		cols.resize(nv)
		cols.fill(FAR_COLOR)
		arr[Mesh.ARRAY_COLOR] = cols
		var fam := ArrayMesh.new()
		fam.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		FarDetail.register(node, fam, Transform3D.IDENTITY, NEAR_END, FarDetail.far_material())
	else:
		FarDetail.near_ends(node, NEAR_END, NEAR_END * 0.12)


## Reedholm: a stilt piece hangs from the water line, or stands on whatever is higher (a hummock under its deck).
static func _stilt_y(space: PhysicsDirectSpaceState3D, kind: String, at: Vector2, yaw: float) -> float:
	var ul := _under(space, kind, at, yaw)
	match kind:
		"RH_Punt":
			return maxf(WATER, ul.y) - 0.15
		"RH_Bridge":
			return maxf(Land.water_y_at(at.x, at.y), WATER)
		"RH_Landing":
			return maxf(WATER, ul.y - 0.3)
	return maxf(WATER, ul.y - 1.1)


## The collision boxes of a piece (its generated table) at its transform; a stretched wall stretches its boxes along x.
static func _cols(shapes: Array, kind: String, xf: Transform3D) -> void:
	if _box_map.is_empty():
		_box_map = (Boxes as Script).get_script_constant_map()
	var rows: Array = _box_map.get(kind.to_upper() + "_BOXES", [])
	var sc := xf.basis.get_scale()
	var rot := xf.basis.orthonormalized()
	for r: Array in rows:
		var lc := Vector3(float(r[0]) * sc.x, float(r[1]), float(r[2]))
		var size := Vector3(float(r[3]) * (sc.x if absf(float(r[6])) < 0.01 else 1.0), float(r[4]), float(r[5]))
		shapes.append([Kit.box(size), Transform3D(rot * Basis(Vector3.UP, float(r[6])), xf.origin + rot * lc)])


## Lit glass: the windows' warm glow kept under the bloom, the lamp glass brighter (the lamp tower's lantern blooms).
static func _glass_mat(nm: String) -> StandardMaterial3D:
	if _glass.has(nm):
		return _glass[nm]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.6, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.62, 0.28) if nm == "window_glass" else Color(1.0, 0.74, 0.42)
	m.emission_energy_multiplier = 0.7 if nm == "window_glass" else 1.6      # windows read across a town, still under the bloom
	m.roughness = 0.4
	_glass[nm] = m
	return m


## Reedholm's boardwalks: 6 m pieces stretched to fit each run, steps down to the bank at a land end.
static func _walks(host: Node3D, shapes: Array, space: PhysicsDirectSpaceState3D, merge: Dictionary) -> void:
	var deck_top: float = float((Boxes.DATA.get("hall", {}) as Dictionary).get("deck", 1.6))
	for w: Dictionary in Plan.WALKS:
		var pts: Array = w.pts
		var h := 1.0 if String(w.h) == "walk" else deck_top
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var d := b - a
			var ln := d.length()
			var yaw := atan2(-d.y, d.x)
			var n := maxi(1, roundi(ln / 6.0))
			var seg := ln / float(n)
			for k in n:
				var m := a + d * ((k + 0.5) / float(n))
				var hi := -INF
				for t: float in [0.0, 0.5, 1.0]:
					var q := a + d * ((k + t) / float(n))
					hi = maxf(hi, RealmLayout.ground(space, q.x, q.y))
				var y0 := maxf(WATER, hi + 0.35 - 1.0) + (h - 1.0)
				var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(seg / 6.0, 1.0, 1.0)), Vector3(m.x, y0, m.y))
				_add_near(merge, Kit.mesh(Plan.GLB, "RH_Walk"), xf)
				_cols(shapes, "RH_Walk", xf)
				walk_decks.append({"rect": _aabb([a + d * (k / float(n)), a + d * ((k + 1) / float(n))] as Array[Vector2]).grow(1.0), "y": y0 + 1.0})
				placed.append({"kind": "RH_Walk", "town": "reedholm", "xf": xf})
			if bool(w.get("end", false)) and i == pts.size() - 2:
				var dn := d.normalized()
				var last: Transform3D = placed[placed.size() - 1].xf
				var top := last.origin.y + 1.0
				var bank := RealmLayout.ground(space, b.x + dn.x * WALK_STEP_RUN, b.y + dn.y * WALK_STEP_RUN)
				# RH_WalkStep falls 1.0 over its run; set so its top meets the walk and its foot the bank (sunk, if the bank is high)
				var ys := top - 1.0
				var xs := Transform3D(Basis(Vector3.UP, yaw), Vector3(b.x, ys, b.y))
				_add_near(merge, Kit.mesh(Plan.GLB, "RH_WalkStep"), xs)
				_cols(shapes, "RH_WalkStep", xs)
				placed.append({"kind": "RH_WalkStep", "town": "reedholm", "xf": xs, "bank": bank})
	# the houses' decks for the village's network
	for p: Dictionary in placed:
		var kind := String(p.kind)
		if kind in ["RH_Hall", "RH_House", "RH_HouseB", "RH_HouseLong", "RH_Landing", "RH_Bridge"]:
			var xf2: Transform3D = p.xf
			var top2 := 0.6 if kind == "RH_Landing" else (1.3 if kind == "RH_Bridge" else deck_top)
			walk_decks.append({"rect": _aabb(_corners(kind, Vector2(xf2.origin.x, xf2.origin.z), xf2.basis.get_euler().y, 0.2)), "y": xf2.origin.y + top2})


## Fallowmere's fields: hurdle runs (each hurdle 2.6 m, a little crooked), stooks in rows.
static func _fields(host: Node3D, shapes: Array, space: PhysicsDirectSpaceState3D) -> void:
	var hx: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261115
	for run: Array in Plan.HURDLES:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var d := b - a
		var n := maxi(1, roundi(d.length() / 2.6))
		var yaw := atan2(-d.y, d.x)
		for k in n:
			var m := a + d * ((k + 0.5) / float(n))
			if RealmLayout.path_dist(m) < 2.2 or Land.in_water(m.x, m.y):
				continue
			var y := RealmLayout.ground(space, m.x, m.y)
			var xf := Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.06, 0.06)) * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05)), Vector3(m.x, y, m.y))
			hx.append(xf)
			_cols(shapes, "FM_Hurdle", xf)
	_multi(host, "Hurdles", "FM_Hurdle", hx, 90.0, false)
	var sx: Array = []
	for f: Array in Plan.STOOK_FIELDS:
		var c: Vector2 = f[0]
		var half: Vector2 = f[1]
		var cnt := int(f[3])
		for i in cnt:
			var q := c + Vector2(lerpf(-half.x, half.x, (i + 0.5) / float(cnt)) + rng.randf_range(-0.6, 0.6), rng.randf_range(-half.y, half.y))
			if RealmLayout.path_dist(q) < 2.0 or Land.in_water(q.x, q.y) or _near_camp(q, 12.0):
				continue
			sx.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.85, 1.1)), Vector3(q.x, RealmLayout.ground(space, q.x, q.y) - 0.05, q.y)))
	_multi(host, "Stooks", "FM_Stook", sx, 90.0, false)


static func _near_camp(p: Vector2, r: float) -> bool:
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var at: Vector3 = c.get("at", Vector3.INF)
		if Vector2(at.x, at.z).distance_to(p) < r:
			return true
	return false


static func _multi(host: Node3D, nm: String, part: String, xfs: Array, view_end: float, shadow: bool) -> void:
	var m := Kit.mesh(Plan.GLB, part)
	if m == null or xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = view_end
	mmi.visibility_range_end_margin = view_end * 0.12
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.add_to_group(Groups.CULL_SKIP)
	host.add_child(mmi)


# --- the lamps (lamp_places.gd) ---------------------------------------------------------------------------------------

## The towns' lamps in lamp_places' spec shape. Kept ones (pre-lit, no prompt) are the townsfolk's own: the fishers'
## jetty lamps ("LAMPS LIT AT THE JETTY"), the watch's lanterns at Lastlight's gates. The rest the wanderer kindles.
const LAMPS := [
	# Reedholm: on the landing's deck, at the bridge, on the decks' fronts
	{"id": "rh_jetty_a", "look": "post", "x": -320.6, "z": 299.0, "top": true, "wet": true, "kept": true, "face": PI * 0.5},
	{"id": "rh_jetty_b", "look": "post", "x": -325.6, "z": 299.2, "top": true, "wet": true, "kept": true, "face": -PI * 0.5},
	{"id": "rh_jetty_c", "look": "post", "x": -325.6, "z": 308.0, "top": true, "wet": true, "kept": true, "face": -PI * 0.5},
	{"id": "rh_ford_post", "look": "post", "x": -295.0, "z": 299.4, "wet": true, "face": "road"},
	{"id": "rh_hall_lamp", "look": "post", "x": -305.0, "z": 271.0, "top": true, "wet": true, "face": -PI * 0.5},
	{"id": "rh_house_lamp", "look": "post", "x": -305.2, "z": 286.6, "top": true, "wet": true, "face": -PI * 0.5},
	{"id": "rh_long_lamp", "look": "post", "x": -302.0, "z": 255.0, "top": true, "wet": true, "face": -PI * 0.5},
	{"id": "rh_smoke_lamp", "look": "post", "x": -321.6, "z": 282.2, "face": PI * 0.5},
	# Fallowmere: the barn's porch, the farmhouse door, the green, the cottages
	{"id": "fm_barn_l", "look": "hang", "x": -174.2, "z": 294.3, "mode": "wall", "dir": Vector2(0, -1), "h": 3.2},
	{"id": "fm_house_lamp", "look": "hang", "x": -166.4, "z": 306.4, "mode": "wall", "dir": Vector2(0, 1), "h": 2.6},
	{"id": "fm_green_post", "look": "post", "x": -145.4, "z": 288.6, "face": PI * 0.75},
	{"id": "fm_cot_a_lamp", "look": "hang", "x": -134.6, "z": 291.8, "mode": "wall", "dir": Vector2(0, -1), "h": 2.4},
	{"id": "fm_cot_b_lamp", "look": "hang", "x": -129.6, "z": 315.2, "mode": "wall", "dir": Vector2(0, 1), "h": 2.4},
	# Lastlight: the road gate's brackets, the watch's lanterns at the shut gate, the inn, the tower door, the platform
	{"id": "ll_gate_w_n", "look": "hang", "x": 287.4, "z": 66.0, "mode": "wall", "dir": Vector2(1, 0), "h": 3.8},
	{"id": "ll_gate_w_s", "look": "hang", "x": 287.4, "z": 73.0, "mode": "wall", "dir": Vector2(1, 0), "h": 3.8},
	{"id": "ll_east_n", "look": "post", "x": 349.6, "z": 59.2, "kept": true, "face": -PI * 0.5},
	{"id": "ll_east_s", "look": "post", "x": 349.6, "z": 66.4, "kept": true, "face": -PI * 0.5},
	{"id": "ll_inn_l", "look": "hang", "x": 324.6, "z": 48.8, "mode": "wall", "dir": Vector2(0, -1), "h": 2.6},
	{"id": "ll_inn_r", "look": "hang", "x": 331.6, "z": 48.8, "mode": "wall", "dir": Vector2(0, -1), "h": 2.6},
	{"id": "ll_tower_door", "look": "hang", "x": 345.0, "z": 49.8, "mode": "wall", "dir": Vector2(0, -1), "h": 3.0},
	{"id": "ll_watch_cresset", "look": "cresset", "x": 333.8, "z": 73.8, "top": true, "kept": true, "face": 0.0},
	{"id": "ll_stable_lamp", "look": "post", "x": 318.8, "z": 70.2, "face": "road"},
]


static func lamps() -> Array:
	return LAMPS


# --- the people's side ------------------------------------------------------------------------------------------------

## For village_nav: the boards it walks on over water (filled by build).
static func decks() -> Array:
	return walk_decks.duplicate()


## A placed piece's transform (the first of that kind in that town), or IDENTITY.
static func piece_xf(town: String, kind: String) -> Transform3D:
	for p: Dictionary in placed:
		if String(p.town) == town and String(p.kind) == kind:
			return p.xf
	return Transform3D(Basis.IDENTITY, Vector3.INF)


## A point in a placed piece's own frame (local x, y, z) in the world.
static func local(town: String, kind: String, v: Vector3) -> Vector3:
	var xf := piece_xf(town, kind)
	if xf.origin == Vector3.INF:
		return Vector3.INF
	return xf * v
