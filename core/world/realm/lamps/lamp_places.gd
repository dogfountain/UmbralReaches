extends RefCounted
## The Realm's lamps (module "lamps", after the settlements are dressed): where the eye wants a light.
## Two kinds, both small and warm:
##   - lamps the wanderer KINDLES (lamp.gd): hanging lamps, candle niches, standing lanterns, a cresset
##     on the March Wall's towers. Unlit until she lights them; the save remembers each.
##   - lights OTHERS keep (lamps_kept.gd): a pilgrim's camp, a ferryman's lamp, a hunter's shuttered
##     lantern, a window lit in a ruin. Pre-lit, few, and a story each.
## Neither is gameplay light (see lamp.gd): they never touch LightGrid.
##
## A spec is a Dictionary: id (the save key), look (hang | niche | post | pane | cresset), x, z, and
##   mode  "ground" (default: stand on the terrain, or `y` / `top` for a structure under the point)
##         "wall"   (find the nearest wall within 3.2 m of the point, at height `y` / `h`, and mount on it)
##         "ceil"   (hang from whatever is overhead)
##   dir   Vector2 (xz) the wall lies in, when it is not simply the nearest
##   face  "road" or a yaw (ground looks): which way the front looks
##   free  a niche on its own plinth;  light false = emissive only
## Placement is by ray (ground, wall, ceiling): nothing is floated or buried, nothing stands on a path or
## within reach of another interactable, and every refusal is printed (LAMPS skip ...).
##   `-- --no-lamps`: the world without them (before / after shots, perf A/B).

const Zones := preload("res://core/world/realm/dress_zones.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Road := preload("res://core/world/realm/lore/road.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const Kept := preload("res://core/world/realm/lamps/lamps_kept.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
const West := "res://core/world/realm/realm_pois_r37_west.gd"
const WALL_REACH := 3.2
const KEEP_OFF := 1.7                  ## from another interactable (ground lamps)

static var stats: Dictionary = {}      ## look -> count (last build; the probe and the tests)
static var skipped: Array[String] = []
static var placed := 0
static var build_ms := 0

static var _space: PhysicsDirectSpaceState3D
static var _taken: Array[Vector3] = []


static func off() -> bool:
	return "--no-lamps" in OS.get_cmdline_user_args()


static func build(root: Node) -> void:
	if off():
		return
	var t0 := Time.get_ticks_msec()
	var old := root.get_node_or_null("Lamps")
	if old:
		old.free()
	await root.get_tree().physics_frame
	_space = (root as Node3D).get_world_3d().direct_space_state
	var host := Node3D.new()
	host.name = "Lamps"
	root.add_child(host)
	stats.clear()
	skipped.clear()
	placed = 0
	_taken.clear()
	for n in root.get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Node3D:
			_taken.append((n as Node3D).global_position)
	for s: Dictionary in _specs():
		place(host, s)
	_road_lanterns(host)
	_weirford_lanterns(host)
	_wall(host, root)
	_anchorholds(host, root)
	_oak(host, root)
	_ledge(host, root)
	_siege_tower(host, root)
	Kept.build(host, root, _space, _kept_place.bind(host))
	_space = null
	build_ms = Time.get_ticks_msec() - t0
	var line := ""
	for k: String in stats:
		line += "%s %d  " % [k, int(stats[k])]
	print("LAMPS %d kindled in %d ms: %s| skipped %d" % [placed, build_ms, line, skipped.size()])
	for s: String in skipped:
		print("LAMPS skip ", s)


# --- the data ----------------------------------------------------------------------------------------

static func _s(id: String, look: String, x: float, z: float, o := {}) -> Dictionary:
	var d := o.duplicate()
	d["id"] = id
	d["look"] = look
	d["x"] = x
	d["z"] = z
	return d


static func _specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# --- Weirford: candles at the water on the bridge's flanks, lamps on the banks ---------------------------------
	# the deck is a slab sitting on the river (its underside is a hand over the water): the arches' flanks
	# are where a light can burn, reflected in the Sorrow and found from the deck above
	for xs: float in [-213.0, -203.0]:
		out.append(_s("wf_arch_n_%d" % int(-xs), "niche", xs, 62.0, {"mode": "wall", "y": 0.1, "dir": Vector2(0, 1), "light": false}))
		out.append(_s("wf_arch_s_%d" % int(-xs), "niche", xs, 69.6, {"mode": "wall", "y": 0.1, "dir": Vector2(0, -1), "light": false}))
	out.append(_s("wf_bank_w", "post", -219.4, 61.2, {"face": 0.0}))
	out.append(_s("wf_bank_e", "post", -196.6, 59.0, {"face": PI}))
	# --- the Sorrow's ford and the Siege Lines' palisade gate -------------------------------------------------------
	out.append(_s("sr_ford_post", "post", -197.6, -24.0, {"face": "road"}))
	out.append(_s("sg_gate_w", "post", -217.6, 113.0, {"face": "road"}))
	out.append(_s("sg_gate_e", "post", -210.0, 110.6, {"face": "road"}))
	# --- the Pilgrims' Road: roadside shrines, waystones, cairns, posts ----------------------------------------
	out.append(_s("rd_shrine_a", "niche", -37.4, 64.2, {"free": true, "face": "road", "light": false}))
	out.append(_s("rd_shrine_b", "niche", -30.4, 62.6, {"free": true, "face": "road", "light": false}))
	for w: Array in [["rd_way_12", -88.0, 58.0], ["rd_way_9", -56.0, 63.0], ["rd_way_e8", 64.0, 59.0], ["rd_way_e11", 88.0, 68.0]]:
		out.append(_s(String(w[0]), "niche", float(w[1]), float(w[2]), {"free": true, "face": "road", "shift": 2.4, "light": false}))
	for c: Array in [["rd_cairn_92", -91.0, 67.0], ["rd_cairn_34", -34.0, 50.0], ["rd_cairn_70", 71.0, 56.0]]:
		out.append(_s(String(c[0]), "niche", float(c[1]), float(c[2]), {"free": true, "face": "road", "shift": 1.2, "light": false}))
	# standing lanterns along the road where it has none (the old posts: _road_lanterns)
	for p: Array in [[-246.0, 1.0], [-176.0, -1.0], [-132.0, 1.0], [-110.0, -1.0], [112.0, 1.0], [134.0, -1.0], [170.0, 1.0], [244.0, -1.0]]:
		var at: Vector2 = Road.beside(float(p[0]), float(p[1]), 3.4)
		out.append(_s("rd_post_%d" % int(p[0]), "post", at.x, at.y, {"face": "road"}))
	# --- the moor's cairns ----------------------------------------------------------------------------------------
	for c: Array in [["moor_cairn_0", 131.0, 48.0], ["moor_cairn_2", 136.0, -5.0], ["moor_cairn_4", 132.0, -55.0]]:
		out.append(_s(String(c[0]), "niche", float(c[1]), float(c[2]), {"free": true, "face": "road", "shift": 1.2, "light": false}))
	# --- Stillwater's shore ------------------------------------------------------------------------------------------
	out.append(_s("sw_shore_a", "post", 207.0, 47.0, {"face": "road"}))
	out.append(_s("sw_shore_b", "post", 232.0, 34.0, {"face": "road"}))
	return out


# --- placing one --------------------------------------------------------------------------------------

static func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.PROPS))


static func _top_y(p: Vector2, fallback: float) -> float:
	var hit := _ray(Vector3(p.x, 90.0, p.y), Vector3(p.x, -20.0, p.y))
	return (hit.position as Vector3).y if not hit.is_empty() else fallback


static func _toward_path(p: Vector2) -> float:
	var best := INF
	var yaw := 0.0
	for i in 16:
		var a := TAU * float(i) / 16.0
		var d := Vector2(sin(a), cos(a))
		var pd := RealmLayout.path_dist(p + d * 2.0)
		if pd < best:
			best = pd
			yaw = a
	return yaw


static func _skip(id: String, why: String, at := Vector2.ZERO) -> void:
	skipped.append("%s: %s" % [id, why])
	PlacementLog.skip("lamps", id, Vector3(at.x, 0, at.y), why.split(" at ")[0])


static func _open(p: Vector2, wall := false) -> bool:
	for q: Vector3 in _taken:
		if Vector2(q.x, q.z).distance_squared_to(p) < (KEEP_OFF * KEEP_OFF if not wall else 1.0):
			return false
	return true


## Make a lamp from a spec and stand it in the world; null (and a skip line) when the spot is bad.
static func place(host: Node3D, s: Dictionary) -> Lamp:
	var id: String = s.id
	var look: String = s.look
	var p := Vector2(float(s.x), float(s.z))
	var mode: String = s.get("mode", "ground")
	var gy := RealmLayout.ground(_space, p.x, p.y)
	var xf := Transform3D()
	var lamp := Lamp.new()
	lamp.lamp_id = id
	lamp.look = look
	lamp.want_light = bool(s.get("light", look != "niche"))
	lamp.free_niche = bool(s.get("free", false))
	lamp.kept = bool(s.get("kept", false))
	match mode:
		"wall":
			var y0 := float(s.get("y", gy + float(s.get("h", 1.9 if look == "hang" else 1.2))))
			var from := Vector3(p.x, y0, p.y)
			var dirs: Array[Vector3] = []
			if s.has("dir"):
				dirs.append(Vector3((s.dir as Vector2).x, 0.0, (s.dir as Vector2).y).normalized())
			else:
				for i in 12:
					var a := TAU * float(i) / 12.0
					dirs.append(Vector3(sin(a), 0.0, cos(a)))
			var best: Dictionary = {}
			var best_d := INF
			for d: Vector3 in dirs:
				var hit := _ray(from, from + d * float(s.get("reach", WALL_REACH)))
				if hit.is_empty():
					continue
				var n: Vector3 = hit.normal
				if absf(n.y) > 0.5:
					continue
				var dist := from.distance_to(hit.position)
				if dist < best_d:
					best_d = dist
					best = hit
			if best.is_empty():
				lamp.free()
				_skip(id, "no wall near %s at y %.1f" % [p, y0], p)
				return null
			var n2: Vector3 = best.normal
			n2.y = 0.0
			n2 = n2.normalized()
			var pos: Vector3 = best.position
			pos += n2 * 0.01
			pos.y = y0 - (0.4 if look == "niche" else 0.0)
			if look == "window":
				pos += n2 * 0.03
			xf = Transform3D(Basis(Vector3.UP, atan2(n2.x, n2.z)), pos)
			if not _open(Vector2(pos.x, pos.z), true):
				lamp.free()
				_skip(id, "on an interactable at %s" % [p], p)
				return null
		"ceil":
			var y1 := float(s.get("y", gy))
			var up := _ray(Vector3(p.x, y1 + 0.5, p.y), Vector3(p.x, y1 + 12.0, p.y))
			if up.is_empty():
				lamp.free()
				_skip(id, "nothing overhead at %s" % [p], p)
				return null
			var cy: float = (up.position as Vector3).y - 0.02
			lamp.chain = clampf(cy - 0.44 - (y1 + 2.3), 0.25, 3.0)
			xf = Transform3D(Basis(Vector3.UP, float(s.get("face", 0.0))), Vector3(p.x, cy, p.y))
		_:
			var y := gy
			if s.has("y"):
				y = float(s.y)
			elif bool(s.get("top", false)):
				y = _top_y(p, gy)
			var yaw := _yaw_of(s, p)
			if s.has("shift"):
				var sh := float(s.shift)
				# along the road, not in front of the thing it stands by
				var side := Vector2(cos(yaw), -sin(yaw))
				p += side * sh
				if not s.has("y"):
					y = RealmLayout.ground(_space, p.x, p.y)
			if not s.has("y") and Land.in_water(p.x, p.y) and not bool(s.get("wet", false)):
				lamp.free()
				_skip(id, "in the water at %s" % [p], p)
				return null
			if not bool(s.get("on_path", false)) and (RealmLayout.path_dist(p) < 0.8 or Zones.lane_dist(p) < 0.8):
				lamp.free()
				_skip(id, "on a way at %s" % [p], p)
				return null
			if not _open(p):
				lamp.free()
				_skip(id, "within reach of an interactable at %s" % [p], p)
				return null
			xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y))
	lamp.name = "Lamp_" + id
	host.add_child(lamp)
	lamp.global_transform = xf
	if mode == "ground" and look in ["post", "cresset"] and not lamp.kept:
		_pillar(lamp, 0.16 if look == "post" else 0.3, 2.2 if look == "post" else 1.0)
	_taken.append(lamp.global_position)
	placed += 1
	stats[look] = int(stats.get(look, 0)) + 1
	return lamp


static func _kept_place(s: Dictionary, host: Node3D) -> Lamp:
	return place(host, s)


static func _yaw_of(s: Dictionary, p: Vector2) -> float:
	var f: Variant = s.get("face", null)
	if f is float or f is int:
		return float(f)
	if f is String and String(f) == "road":
		return _toward_path(p)
	return float(hash(String(s.id)) % 628) / 100.0


## A thin solid so the wanderer does not walk through a post (layer PROPS, nothing on the lamp's own sense).
static func _pillar(lamp: Node3D, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = Layers.PROPS
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = Vector3(0, h * 0.5, 0)
	body.add_child(cs)
	lamp.add_child(body)


# --- lamps found on what is already built ------------------------------------------------------------------------

## The cold lanterns the Pilgrims' Road already stands (lore/road.gd): kindle the glass.
static func _road_lanterns(host: Node3D) -> void:
	for i in LK.cold_lamps.size():
		var lamp := Lamp.new()
		lamp.name = "Lamp_rd_lantern_%d" % i
		lamp.lamp_id = "rd_lantern_%d" % i
		lamp.look = "pane"
		host.add_child(lamp)
		lamp.global_position = LK.cold_lamps[i]
		lamp.rotation.y = LK.cold_yaws[i]
		placed += 1
		stats["pane"] = int(stats.get("pane", 0)) + 1


## Weirford's five street lanterns (realm_pois_r37_west.gd LANTERNS): the cage was always there, the flame
## was painted on; now the wanderer lights it.
static func _weirford_lanterns(host: Node3D) -> void:
	var west: Dictionary = (load(West) as GDScript).get_script_constant_map()
	var lans: Array = west.get("LANTERNS", [])
	for i in lans.size():
		var lp: Vector3 = lans[i]
		var g := RealmLayout.ground(_space, lp.x, lp.y)
		var b := Basis(Vector3.UP, lp.z)
		var lamp := Lamp.new()
		lamp.name = "Lamp_wf_lantern_%d" % i
		lamp.lamp_id = "wf_lantern_%d" % i
		lamp.look = "pane"
		host.add_child(lamp)
		lamp.global_position = Vector3(lp.x, g, lp.y) + b * Vector3(0, 2.8, 0.6)
		lamp.rotation.y = lp.z
		placed += 1
		stats["pane"] = int(stats.get("pane", 0)) + 1


## The March Wall: a standing lantern at the foot of each tower and either side of each gate passage. Lighting
## it lights the tower's crown (a cresset on the roof, a follower): a lit tower is a beacon down the wall.
static func _wall(host: Node3D, root: Node) -> void:
	var n_tower := 0
	var towers := root.find_children("Tower_*", "MeshInstance3D", true, false)
	towers.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	var skip_i := 0
	for t in towers:
		skip_i += 1
		if skip_i % 3 == 0:
			continue                      # every third stands dark: the wall is long and the lamps few
		var m := t as Node3D
		var c := Vector2(m.global_position.x, m.global_position.z)
		var inward := Vector2(-signf(c.x), 0.0)
		var foot := c + inward * 5.6 + Vector2(0.0, 2.2)
		var top_y := _top_y(c + inward * 1.4, -100.0)
		var s := _s("wall_t_%s" % String(m.name).trim_prefix("Tower_"), "post", foot.x, foot.y, {"face": float(hash(String(m.name)) % 628) / 100.0})
		var lead := place(host, s)
		if lead == null:
			continue
		n_tower += 1
		if top_y > m.global_position.y + 6.0:
			var crown := _crown(host, Vector3(c.x + inward.x * 1.4, top_y, c.y), "wall_c_%s" % String(m.name).trim_prefix("Tower_"))
			lead.add_follower(crown)
	var n_gate := 0
	for g in root.find_children("Gatehouse", "MeshInstance3D", true, false):
		var gm := g as Node3D
		var b := gm.global_basis
		var inward3 := -(b * Vector3(0, 0, 1))
		for sx: float in [-1.0, 1.0]:
			var q: Vector3 = gm.global_position + b * Vector3(sx * 3.9, 0.0, 0.0) + inward3 * 6.0
			var gl := place(host, _s("wall_g_%d_%d" % [int(gm.global_position.x), int(sx)], "post", q.x, q.z, {"face": atan2(inward3.x, inward3.z)}))
			if gl == null:
				continue
			n_gate += 1
			var top := gm.global_position + b * Vector3(sx * 6.5, 0.0, 0.0)
			var ty := _top_y(Vector2(top.x, top.z), -100.0)
			if ty > gm.global_position.y + 8.0:
				gl.add_follower(_crown(host, Vector3(top.x, ty, top.z), "wall_gc_%d_%d" % [int(gm.global_position.x), int(sx)]))
	print("LAMPS wall: %d towers, %d gate posts" % [n_tower, n_gate])


## A cresset on a roof or a battlement, lit by its leader.
static func _crown(host: Node3D, at: Vector3, id: String) -> Lamp:
	var lamp := Lamp.new()
	lamp.name = "Lamp_" + id
	lamp.lamp_id = id
	lamp.look = "cresset"
	lamp.follower = true
	lamp.scale = Vector3.ONE * 2.6                     # a beacon over the battlements, seen from the road
	host.add_child(lamp)
	lamp.global_position = at
	stats["cresset"] = int(stats.get("cresset", 0)) + 1
	return lamp


static func _anchorholds(host: Node3D, root: Node) -> void:
	var poi := root.find_child("Poi_anchorholds", true, false)
	if poi == null:
		_skip("anchorholds", "not built")
		return
	# duplicate pieces lose their names in the tree: the mesh says what each is
	var cells: Array[MeshInstance3D] = []
	var chapel: MeshInstance3D = null
	for c in poi.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var rn := mi.mesh.resource_name
		if rn.ends_with("Cell_Portal") or rn.ends_with("Cell_Slit"):
			cells.append(mi)
		elif rn.ends_with("Chapel_Front"):
			chapel = mi
	cells.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	var i := 0
	for m in cells:
		var n := m.global_basis * Vector3(0, 0, 1)
		var side := 1.0 if i % 2 == 0 else -1.0
		for tries in 2:
			var q := m.global_position + m.global_basis * Vector3(side * 2.1, 1.3, 1.6)
			if place(host, _s("cell_%d" % i, "niche", q.x, q.z, {"mode": "wall", "y": q.y, "dir": Vector2(-n.x, -n.z), "light": false})) != null:
				break
			side = -side
			if tries == 0 and not skipped.is_empty():
				skipped.remove_at(skipped.size() - 1)
		i += 1
	if chapel != null:
		var n2 := chapel.global_basis * Vector3(0, 0, 1)
		var q2 := chapel.global_position + chapel.global_basis * Vector3(-3.4, 0.0, 2.2)
		place(host, _s("chapel_door", "post", q2.x, q2.z, {"y": chapel.global_position.y, "face": atan2(n2.x, n2.z)}))


## The Grandmother Oak's stair: a lamp on the heartwood every few turns.
static func _oak(host: Node3D, root: Node) -> void:
	var poi := root.find_child("Poi_r37s_oak", true, false) as Node3D
	if poi == null or not poi.has_meta("oak_xf"):
		_skip("oak", "no oak stair built")
		return
	var xf: Transform3D = poi.get_meta("oak_xf")
	var data := (load("res://core/world/realm/r37_south_data.gd") as GDScript).get_script_constant_map()
	var st: Dictionary = data.OAK_STAIR
	var a0 := float(st.a0)
	var a1 := float(st.a_end)
	var n := int(st.n)
	var k := 0
	for i: int in [22, 52, 82, 112, 140]:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		var y := float(st.y0) + float(st.rise) * float(i)
		var axis := xf * Vector3(0, y + 2.1, 0)
		var out := xf.basis * Vector3(sin(a), 0, cos(a))
		var at := axis
		place(host, _s("oak_%d" % k, "hang", at.x, at.z, {"mode": "wall", "y": at.y, "dir": Vector2(out.x, out.z), "reach": 9.0}))
		k += 1


## The Well's ledge path down to the pool: a lamp on the pit wall at every few slabs.
static func _ledge(host: Node3D, root: Node) -> void:
	var wc := RealmLayout.WELL_C
	var slabs := root.find_children("Slab_*", "MeshInstance3D", true, false)
	slabs.append_array(root.find_children("Landing_*", "MeshInstance3D", true, false))
	slabs.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node3D).global_position.y > (b as Node3D).global_position.y)
	var k := 0
	var every := maxi(1, slabs.size() / 6)
	for i in slabs.size():
		if i % every != 2 % every:
			continue
		var m := slabs[i] as Node3D
		var pos := m.global_position
		var out := Vector2(pos.x - wc.x, pos.z - wc.y).normalized()
		place(host, _s("ledge_%d" % k, "hang", pos.x, pos.z, {"mode": "wall", "y": pos.y + 2.3, "dir": out, "reach": 6.0}))
		k += 1


## The Siege Lines' tower: lanterns at its foot, a cresset on its roof.
static func _siege_tower(host: Node3D, root: Node) -> void:
	var c := Vector2(-236.5, 169.5)
	var roof := _top_y(c, -100.0)
	var lead: Lamp = null
	for off: Vector2 in [Vector2(-9.6, 0.0), Vector2(9.6, 0.0)]:
		var l := place(host, _s("siege_tower_%d" % int(off.x), "post", c.x + off.x, c.y + off.y, {"face": "road"}))
		if lead == null:
			lead = l
		elif l != null and lead != null:
			pass
	if lead != null and roof > 6.0:
		lead.add_follower(_crown(host, Vector3(c.x, roof, c.y), "siege_crown"))
