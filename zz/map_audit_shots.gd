extends Node
## r39 MAP AUDIT capture harness (docs/r39/briefs/map_audit.md). It builds the real night (world/main.tscn), holds the
## save, and shoots the whole Realm at night through the game's own grade:
##   grid       a 40 m grid over RealmLayout.BOUNDS: at each point four eye-level views (1.7 m up, FOV 90: N, E, S, W)
##              and one oblique view from 25 m up and 25 m south, looking down at 45 degrees
##   places     every named place (regions, slots, world POIs, beacons, fires, lore stones, secrets, raid floors, gates and
##              approaches, the ways' ends, the March Wall's gates, deep halls and caves, watch posts, stables, lamps): four
##              eye-level views AT the place from its four sides and one aerial
##   interiors  every room you can walk into (Interiors.rooms(): the Keg, cottages, the inn...; the acoustic volumes: deep
##              halls, caves, the towers, the castellum; the Ossuary's tiers, the Counting Stair and the pit hall)
## Each spot is one contact sheet (3 x 2 cells: five views and an info card with a locator map), filed under the region
## it stands in: <out>/<region>/<spot>.jpg, its full-size frames in <out>/<region>/full/, and <out>/index.md.
##
##   godot --path . res://zz/map_audit_shots.tscn -- --out=<dir> --section=grid --rows=0-6
##   godot --path . res://zz/map_audit_shots.tscn -- --out=<dir> --section=places --part=0/3
##   godot --path . res://zz/map_audit_shots.tscn -- --out=<dir> --section=interiors
##   --only=a,b      only the spots whose name contains a or b
##   --lit           an added lamp at the camera (NOT the night grade: for where the night hides a problem)
##   --spot=name:x,z[,size]   (section "spots") named extra spots, shot as places
##   --census        list the spots of the section (no images) and quit
## Windowed only for images (headless runs the walk and the census). tools/map_audit.sh wraps it with the Godot lock.
const WIN := Vector2i(1280, 720)
const CELL := Vector2i(640, 360)
const GRID := 40.0
const EYE := 1.7
const AIR_UP := 25.0
const FOV := 90.0
const AcousticZones := preload("res://core/audio/acoustic_zones.gd")
const OssHall := preload("res://world/areas/ossuary/oss_hall.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")

var out_root := ""
var section := "grid"
var rows := Vector2i(0, 99)
var part := Vector2i(0, 1)              ## places: part k of n
var only: Array = []
var lit := false
var census := false
var extra_spots: Array = []
var headless := false
var main: Node
var p: Player
var cam: Camera3D
var lamp: OmniLight3D
var near0 := 0.05
var t_start := 0
var realm_s := -1.0
var started := false
var index: Array[String] = []
var n_shot := 0
var n_spots := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t_start = Time.get_ticks_msec()
	headless = DisplayServer.get_name() == "headless"
	Travel._busy = true
	Travel.bosses_slain.clear()
	Travel.seals_broken.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_root = a.trim_prefix("--out=")
		elif a.begins_with("--section="):
			section = a.trim_prefix("--section=")
		elif a.begins_with("--rows="):
			var r := a.trim_prefix("--rows=").split("-")
			rows = Vector2i(int(r[0]), int(r[1]))
		elif a.begins_with("--part="):
			var q := a.trim_prefix("--part=").split("/")
			part = Vector2i(int(q[0]), int(q[1]))
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
		elif a.begins_with("--spot="):
			extra_spots.append(a.trim_prefix("--spot="))
		elif a == "--lit":
			lit = true
		elif a == "--census":
			census = true
	if out_root == "":
		out_root = OS.get_environment("MAP_AUDIT_OUT")
	if out_root == "":
		out_root = "user://map_audit"
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 90}
	get_window().size = WIN
	DirAccess.make_dir_recursive_absolute(out_root)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	print("MAPAUDIT start section=", section, " out=", out_root, " headless=", headless)


func _process(_d: float) -> void:
	Travel._busy = true
	var el := float(Time.get_ticks_msec() - t_start) / 1000.0
	if not started and el > 400.0:
		print("MAPAUDIT never got a world")
		_quit(3)
		return
	if not started and is_instance_valid(main) and main.has_meta("realm_done"):
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p == null:
			return
		if realm_s < 0.0:
			realm_s = el
			print("MAPAUDIT realm built at ", snappedf(realm_s, 0.1), " s")
		if el - realm_s > 5.0:
			started = true
			_run.call_deferred()


func _physics_process(_d: float) -> void:
	if p != null and is_instance_valid(p):
		p.gloom = 0.0
		p.wounds = 0.0


func _quit(code: int) -> void:
	print("MAPAUDIT quit ", code)
	get_tree().quit(code)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: OS.kill(OS.get_process_id()))


# ------------------------------------------------------------------------------------------------------
# the runner

func _run() -> void:
	for n: String in ["Encounters", "RoamEvents", "WorldEvents", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)
	_clear_enemies()
	cam = Camera3D.new()
	var gc := p.get("_cam") as Camera3D
	cam.fov = FOV
	cam.far = gc.far if gc != null else 900.0
	cam.near = gc.near if gc != null else 0.05
	near0 = cam.near
	if gc != null:
		cam.cull_mask = gc.cull_mask
		cam.attributes = gc.attributes
		cam.environment = gc.environment
	get_tree().root.add_child(cam)
	cam.make_current()
	lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.92, 0.8)
	lamp.light_energy = 6.0
	lamp.omni_range = 60.0
	lamp.omni_attenuation = 0.6
	lamp.shadow_enabled = false
	lamp.visible = lit
	get_tree().root.add_child(lamp)
	var spots: Array = []
	match section:
		"grid":
			spots = _grid_spots()
		"places":
			spots = _place_spots()
		"interiors":
			spots = _interior_spots()
		"spots":
			for s: String in extra_spots:
				var nm := s.get_slice(":", 0)
				var v := s.get_slice(":", 1).split_floats(",")
				spots.append({"name": nm, "kind": "spot", "at": Vector2(v[0], v[1]), "size": v[2] if v.size() > 2 else 12.0, "names": [nm], "y": v[3] if v.size() > 3 else NAN})
		_:
			print("MAPAUDIT unknown section ", section)
	if not only.is_empty():
		spots = spots.filter(func(s: Dictionary) -> bool: return only.any(func(o: Variant) -> bool: return String(s.name).contains(String(o))))
	print("MAPAUDIT section %s: %d spots" % [section, spots.size()])
	if census:
		for s: Dictionary in spots:
			var at2: Vector2 = s.at
			print("MAPAUDIT spot %s kind %s at (%.1f, %.1f) size %.0f region %s names %s" % [s.name, s.kind, at2.x, at2.y, float(s.get("size", 0.0)), _region_id(at2), str(s.get("names", []))])
		_quit(0)
		return
	for s: Dictionary in spots:
		_clear_enemies()
		_ui_hide()
		match String(s.kind):
			"grid":
				await _shoot_grid(s)
			"room", "volume", "oss", "stair":
				await _shoot_interior(s)
			_:
				await _shoot_place(s)
		n_spots += 1
		if n_spots % 10 == 0:
			print("MAPAUDIT %d of %d spots, %d frames, %.0f s" % [n_spots, spots.size(), n_shot, float(Time.get_ticks_msec() - t_start) / 1000.0])
	_write_index()
	print("MAPAUDIT done: %d spots, %d frames" % [n_spots, n_shot])
	_quit(0)


func _clear_enemies() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()


func _ui_hide() -> void:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := c as CanvasLayer
		if String(cl.name).begins_with("Grade"):
			continue
		cl.visible = false


func _space() -> PhysicsDirectSpaceState3D:
	return p.get_world_3d().direct_space_state


## The terrain's own height (RealmLand's lattice: RealmLayout.ground falls back to the macro shape when a rock or a roof is
## the first thing its ray meets, which put eyes under the ground).
func _gy(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, 220.0, z + 0.0029), Vector3(x + 0.0037, -120.0, z + 0.0029), Layers.WORLD | Layers.PROPS)
	var ex: Array[RID] = []
	for i in 8:
		q.exclude = ex
		var hit := _space().intersect_ray(q)
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return RealmLand.height_at(x, z)


## The first solid surface under (x, from_y, z) (any WORLD/PROPS collider), or NAN.
func _floor(x: float, z: float, from_y: float, depth := 60.0) -> float:
	var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + 0.0037, from_y, z + 0.0029), Vector3(x + 0.0037, from_y - depth, z + 0.0029), Layers.WORLD | Layers.PROPS))
	return NAN if hit.is_empty() else (hit.position as Vector3).y


## The top surface a walker would stand on at (x, z): the highest WORLD/PROPS hit from above (a roof counts: see _open).
func _top(x: float, z: float) -> float:
	var y := _floor(x, z, 140.0, 220.0)
	return _gy(x, z) if is_nan(y) else y


func _region_id(at: Vector2) -> String:
	var r := RealmLayout.region_at(at.x, at.y)
	return String(r.get("id", "wild"))


func _region_name(at: Vector2) -> String:
	var r := RealmLayout.region_at(at.x, at.y)
	return String(r.get("name", "open country"))


## Something solid (not the terrain) within `rad` of `e`.
func _buried(e: Vector3, rad := 0.45) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = rad
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = Layers.WORLD | Layers.PROPS
	q.transform = Transform3D(Basis.IDENTITY, e)
	for h in _space().intersect_shape(q, 6):
		var cn := h.collider as Node
		if cn != null and not String(cn.name).begins_with("Terrain"):
			return true
	return false


# ------------------------------------------------------------------------------------------------------
# spot lists

func _grid_spots() -> Array:
	var out: Array = []
	var b := RealmLayout.BOUNDS
	var row := 0
	var z := b.position.y + 10.0
	while z < b.end.y:
		if row >= rows.x and row <= rows.y:
			var col := 0
			var x := b.position.x + 10.0
			while x < b.end.x:
				out.append({"name": "g%02d_%02d_x%d_z%d" % [row, col, int(x), int(z)], "kind": "grid", "at": Vector2(x, z), "size": GRID, "names": ["grid r%d c%d" % [row, col]]})
				x += GRID
				col += 1
		z += GRID
		row += 1
	return out


func _add(list: Array, name: String, kind: String, at: Vector2, size: float, y := NAN, merge := 8.0) -> void:
	if not RealmLayout.OUTER.has_point(at):
		return
	for s: Dictionary in list:
		var sy := float(s.get("y", NAN))
		var y_far := not is_nan(sy) and not is_nan(y) and absf(sy - y) > 6.0
		if (s.at as Vector2).distance_to(at) < merge and not y_far:
			(s.names as Array).append(name)
			s.size = maxf(float(s.size), size)
			return
	list.append({"name": name, "kind": kind, "at": at, "size": size, "names": [name], "y": y})


func _place_spots() -> Array:
	var out: Array = []
	for r: Dictionary in RealmLayout.REGIONS:
		var c: Vector2 = (r.rect as Rect2).get_center() if r.has("rect") else (r.c as Vector2)
		var sz: float = (maxf((r.rect as Rect2).size.x, (r.rect as Rect2).size.y) * 0.5) if r.has("rect") else float(r.r)
		_add(out, "reg_" + String(r.id), "region", c, clampf(sz, 10.0, 60.0), NAN, 4.0)
	for rd: Dictionary in RealmLayout.RAIDS:
		var c2: Vector2 = rd.c
		var g: Vector2 = rd.gate
		_add(out, "raid_" + String(rd.id) + "_floor", "raid", c2, clampf(float(rd.get("arena_r", rd.r)), 14.0, 50.0), float(rd.y), 4.0)
		_add(out, "raid_" + String(rd.id) + "_gate", "gate", g, 12.0)
		_add(out, "raid_" + String(rd.id) + "_approach", "approach", g + (g - c2).normalized() * 18.0, 12.0)
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var ar := a as Node3D
		_add(out, "arena_" + String(ar.get("boss_id")), "raid", Vector2(ar.global_position.x, ar.global_position.z), clampf(float(ar.get("radius")), 12.0, 50.0), ar.global_position.y)
	for i in RealmLayout.MARCH_GATES.size():
		_add(out, "march_gate_%d" % i, "gate", RealmLayout.MARCH_GATES[i], 14.0)
	for n in get_tree().get_nodes_in_group("world_poi"):
		var at := _node_at(n as Node)
		_add(out, "poi_" + String((n as Node).get_meta("poi", (n as Node).name)), "poi", Vector2(at.x, at.z), 16.0, at.y)
	for n in get_tree().get_nodes_in_group(&"landmark_beacon"):
		var anc: Variant = (n as Node).get("anchor")
		var at3: Vector3 = anc if anc is Vector3 else (n as Node3D).global_position
		_add(out, "beacon_" + String((n as Node).name), "beacon", Vector2(at3.x, at3.z), 16.0, at3.y)
	for rid: String in RealmLayout.SLOTS:
		var sl: Array = RealmLayout.SLOTS[rid]
		for i in sl.size():
			_add(out, "slot_%s_%s_%d" % [rid, String(sl[i].kind), i], "slot", sl[i].at, 10.0)
	for id: String in preload("res://core/world/world_events.gd").EXTRA_SITES:
		_add(out, "site_" + id, "site", preload("res://core/world/world_events.gd").EXTRA_SITES[id][0], 12.0)
	var extra: Dictionary = (load("res://core/world/realm/realm_pois_doubled_realm.gd") as GDScript).get("EXTRA")
	for id2: String in extra:
		_add(out, "ground_" + id2, "site", extra[id2][0], 12.0)
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		var bz := n as Node3D
		_add(out, "fire_" + String(bz.name), "fire", Vector2(bz.global_position.x, bz.global_position.z), 9.0, bz.global_position.y)
	for n in get_tree().get_nodes_in_group(&"deep_hall") + get_tree().get_nodes_in_group(&"cave"):
		var th: Vector3 = (n as Node).get_meta("threshold_at", Vector3.ZERO)
		_add(out, "door_" + String((n as Node).name), "door", Vector2(th.x, th.z), 10.0, th.y)
	for n in get_tree().get_nodes_in_group(&"watch_post") + get_tree().get_nodes_in_group(&"hitching_post"):
		var wp := n as Node3D
		_add(out, "post_" + String(wp.name), "post", Vector2(wp.global_position.x, wp.global_position.z), 9.0, wp.global_position.y)
	for w: Dictionary in RealmLayout.PATHS:
		var pts: Array = w.pts
		_add(out, "way_%s_start" % String(w.id), "way", pts[0], 9.0)
		_add(out, "way_%s_end" % String(w.id), "way", pts[pts.size() - 1], 9.0)
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		var nd := n as Node3D
		if nd == null or not nd.is_inside_tree():
			continue
		var sp := String((nd.get_script() as Script).resource_path) if nd.get_script() != null else ""
		var kind := ""
		if nd is LoreScrap:
			kind = "lore"
		elif sp.contains("/secrets/"):
			kind = "secret"
		elif sp.contains("loot_chest"):
			kind = "chest"
		if kind == "":
			continue
		_add(out, "%s_%s" % [kind, String(nd.name)], kind, Vector2(nd.global_position.x, nd.global_position.z), 6.0, nd.global_position.y)
	for n in get_tree().get_nodes_in_group(&"lamp"):
		var lp := n as Node3D
		_add(out, "lamp_" + String(lp.name), "lamp", Vector2(lp.global_position.x, lp.global_position.z), 6.0, lp.global_position.y)
	# the ways' junctions: a way's vertex within 4 m of another way's line
	for w: Dictionary in RealmLayout.PATHS:
		for q: Vector2 in w.pts:
			for w2: Dictionary in RealmLayout.PATHS:
				if w2.id == w.id:
					continue
				var pp: Array = w2.pts
				for i in range(pp.size() - 1):
					if Geometry2D.get_closest_point_to_segment(q, pp[i], pp[i + 1]).distance_to(q) < 4.0:
						_add(out, "junction_%s_%s" % [String(w.id), String(w2.id)], "way", q, 10.0)
						break
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := _region_id(a.at)
		var rb := _region_id(b.at)
		return ra < rb if ra != rb else String(a.name) < String(b.name))
	var mine: Array = []
	for i in out.size():
		if i * part.y / out.size() == part.x:
			mine.append(out[i])
	return mine


func _node_at(n: Node) -> Vector3:
	if n.has_meta("centre"):
		return n.get_meta("centre")
	if n.has_meta("threshold_at"):
		return n.get_meta("threshold_at")
	var bb := WorldLanes.bounds(n)
	if bb.size.length() > 0.1 and bb.size.length() < 400.0:
		return bb.get_center() - Vector3(0, bb.size.y * 0.5, 0)
	return (n as Node3D).global_position if n is Node3D else Vector3.ZERO


func _interior_spots() -> Array:
	var out: Array = []
	var rooms: Dictionary = Interiors.rooms()
	for id: String in rooms:
		var r: Dictionary = rooms[id]
		var xf: Transform3D = (r.inv as Transform3D).affine_inverse()
		out.append({"name": "room_" + id, "kind": "room", "at": Vector2(xf.origin.x, xf.origin.z), "xf": xf, "half": r.half, "names": [id], "size": 6.0})
	var zones: Array = AcousticZones._zones
	var k := 0
	for z: Array in zones:
		var bx: AABB = z[0]
		var c := bx.get_center()
		out.append({"name": "vol_%02d_%s" % [k, String(z[2])], "kind": "volume", "at": Vector2(c.x, c.z), "box": bx, "names": [String(z[1]) + " " + String(z[2])], "size": bx.size.x})
		k += 1
	for n in get_tree().get_nodes_in_group(&"deep_hall") + get_tree().get_nodes_in_group(&"cave"):
		var th: Vector3 = (n as Node).get_meta("threshold_at", Vector3.ZERO)
		var rw: Vector3 = (n as Node).get_meta("reward_at", Vector3.INF)
		if rw == Vector3.INF:
			for st: Dictionary in WorldLanes.sites:
				if st.has("seg") and ((st.seg as Array)[0] as Vector3).distance_to(th) < 0.5:
					var sa: Vector3 = (st.seg as Array)[0]
					var sb: Vector3 = (st.seg as Array)[1]
					var fw := Vector3(sb.x - sa.x, 0, sb.z - sa.z).normalized()
					rw = sb + fw * 28.0
		if rw == Vector3.INF:
			continue
		out.append({"name": "stair_" + String((n as Node).name), "kind": "stair", "at": Vector2(th.x, th.z), "from": th, "to": rw, "names": [String((n as Node).name)], "size": 8.0})
	# the Ossuary (local numbers -> world through OssFrame): the landing, the bone bridge, the gate hall, the gallery, the pit,
	# the chapel, the deep floor, the Counting Stair's top, middle and foot, the corridor and the pit hall
	var Hall := OssHall
	var oss := [
		["oss_landing", OssFrame.LANDING + Vector3(0, 0, 0), Vector3(1, 0, 0)],
		["oss_bridge_mid", Vector3(7.0, 12.6, -34.0), Vector3(1, 0, 0)],
		["oss_gate_hall", Vector3(22.0, 12.6, -34.0), Vector3(0, 0, -1)],
		["oss_gallery_n", Vector3(20.0, 8.4, -50.0), Vector3(0, 0, -1)],
		["oss_gallery_s", Vector3(20.0, 8.4, -70.0), Vector3(0, 0, -1)],
		["oss_pit", Vector3(16.0, 4.2, -80.0), Vector3(0, 0, -1)],
		["oss_pit_far", Vector3(16.0, 4.2, -92.0), Vector3(0, 0, 1)],
		["oss_chapel", Vector3(18.0, 4.2, -104.0), Vector3(0, 0, 1)],
		["oss_deep_drum", Vector3(18.0, -2.0, -78.0), Vector3(0, 0, -1)],
		["oss_deep_arena", Vector3(15.5, -2.0, -68.0), Vector3(0, 0, 1)],
		["oss_count_door", Vector3(26.5, 4.2, Hall.DOOR_Z), Vector3(1, 0, 0)],
		["oss_stair_top", Vector3(31.2, 4.2, -88.0), Vector3(0, 0, -1)],
		["oss_stair_mid", Vector3(34.4, Hall.FLOOR_Y + Hall.RISE * 4.0, -90.0), Vector3(0, 0, 1)],
		["oss_stair_foot", Vector3(34.4, Hall.FLOOR_Y, Hall.DOOR_Z), Vector3(1, 0, 0)],
		["oss_hall_door", Hall.at(Hall.door_ang(), Hall.TIER_A.x + 2.0), Vector3.ZERO],
		["oss_hall_floor", Hall.at(Hall.door_ang(), 14.0), Vector3.ZERO],
		["oss_hall_centre", Hall.C, Vector3(1, 0, 0)],
		["oss_hall_tier", Hall.at(Hall.door_ang() + 90.0, (Hall.TIER_A.x + Hall.TIER_A.y) * 0.5, Hall.TIER_A.z), Vector3.ZERO],
	]
	for o: Array in oss:
		var wl := OssFrame.w(o[1] as Vector3)
		out.append({"name": String(o[0]), "kind": "oss", "at": Vector2(wl.x, wl.z), "eye": wl, "face": OssFrame.wd(o[2] as Vector3), "names": [String(o[0])], "size": 6.0})
	return out


# ------------------------------------------------------------------------------------------------------
# shooting

## Park the (disabled, hidden) player under the camera so everything that streams or culls round the wanderer sees it there.
func _park(cam_pos: Vector3, target: Vector3, stand_y := NAN) -> void:
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.visible = false
	cam.global_position = cam_pos
	# an aerial's eye is often inside a tree's crown: the near plane is pushed past the leaves round it (only up there)
	cam.near = 5.0 if cam_pos.y - _gy(cam_pos.x, cam_pos.z) > 15.0 else near0
	if cam_pos.distance_to(target) > 0.01:
		var up := Vector3.UP if absf((target - cam_pos).normalized().y) < 0.98 else Vector3.FORWARD
		cam.look_at(target, up)
	var py := (_gy(cam_pos.x, cam_pos.z) + 0.1) if is_nan(stand_y) else stand_y
	p.global_position = Vector3(cam_pos.x, py, cam_pos.z)
	p.reset_physics_interpolation()
	lamp.global_position = cam_pos + Vector3(0, 0.5, 0)


## --near-debug: name every small drawn thing within 12 m of the camera (what are the orbs in a frame).
func _near_debug() -> void:
	var cp := cam.global_position
	for n: Node in main.get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var bb: AABB = gi.global_transform * gi.get_aabb()
		if bb.size.length() < 3.0 and bb.get_center().distance_to(cp) < 12.0:
			print("MAPAUDIT near %s %s at %s size %s" % [gi.get_class(), main.get_tree().root.get_path_to(gi), bb.get_center(), bb.size])
		elif gi is GPUParticles3D or gi is CPUParticles3D or gi is MultiMeshInstance3D:
			if bb.grow(1.0).has_point(cp):
				print("MAPAUDIT around %s %s box %s" % [gi.get_class(), main.get_tree().root.get_path_to(gi), bb])


func _secs(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _grab(settle := 3) -> Image:
	for i in settle:
		await get_tree().process_frame
	if headless:
		return null
	await RenderingServer.frame_post_draw
	n_shot += 1
	return get_viewport().get_texture().get_image()


static func _dir(yaw_deg: float) -> Vector3:
	# 0 = north (-z), 90 = east (+x), 180 = south, 270 = west
	var a := deg_to_rad(yaw_deg)
	return Vector3(sin(a), 0.0, -cos(a))


func _shoot_grid(s: Dictionary) -> void:
	var at: Vector2 = s.at
	var terr := _gy(at.x, at.y)
	var g := terr
	var eye := Vector3(at.x, g + EYE, at.y)
	var note := ""
	var wl := RealmLayout.water_level_at(at.x, at.y)
	if not is_nan(wl) and wl > g:
		eye.y = wl + EYE
		note = "in water %.1f m deep" % (wl - g)
	if _buried(eye) or _roofed(eye):
		var moved := false
		for rr: float in [2.0, 4.0, 6.0, 9.0, 13.0]:
			for k in 8:
				var q := at + Vector2(cos(TAU * k / 8.0), sin(TAU * k / 8.0)) * rr
				var e2 := Vector3(q.x, _gy(q.x, q.y) + EYE, q.y)
				if not _buried(e2) and not _roofed(e2):
					eye = e2
					moved = true
					break
			if moved:
				break
		if not moved:
			var tp := _top(at.x, at.y)
			eye = Vector3(at.x, tp + EYE, at.y)
			note += (" " if note != "" else "") + "on a structure %.1f m above the terrain" % (tp - terr)
		else:
			note += (" " if note != "" else "") + "eye moved %.0f m out of a solid or a roof" % Vector2(eye.x, eye.z).distance_to(at)
		g = eye.y - EYE
	var frames: Array = []
	var labels: Array = []
	var pitch := Vector3(0, -0.1, 0)
	_park(eye, eye + _dir(0.0) + pitch)
	await _secs(1.1)
	for yd: float in [0.0, 90.0, 180.0, 270.0]:
		_park(eye, eye + _dir(yd) + pitch)
		frames.append(await _grab(4))
		labels.append(["N", "E", "S", "W"][int(yd / 90.0)] + " FROM EYE")
	var air := _air_eye(at, g)
	_park(air[0], Vector3(at.x, g, at.y), _gy(air[0].x, air[0].z) + 0.1)
	await _secs(0.5)
	frames.append(await _grab(3))
	labels.append(String(air[1]))
	var info := ["GRID %s" % String(s.name).to_upper(), "X %.0f  Z %.0f  GROUND %.1f" % [at.x, at.y, g], _region_name(at).to_upper(),
		"BIOME " + RealmLayout.biome_at(at.x, at.y).to_upper(), "WAY %.0f M" % RealmLayout.path_dist(at), note.to_upper()]
	_save_sheet(s, frames, labels, info)


func _shoot_place(s: Dictionary) -> void:
	var at: Vector2 = s.at
	var sz: float = float(s.get("size", 12.0))
	var gy := _gy(at.x, at.y)
	var top := _top(at.x, at.y)
	var base_y: float = float(s.y) if not is_nan(float(s.get("y", NAN))) else (top if top - gy < 3.0 else gy)
	var tg := Vector3(at.x, base_y + 1.4, at.y)
	var d := clampf(sz * 0.9, 5.5, 34.0)
	var frames: Array = []
	var labels: Array = []
	var first := true
	for side: float in [0.0, 90.0, 180.0, 270.0]:
		var eye := _side_eye(at, side, d, base_y, tg)
		_park(eye, tg)
		if first:
			await _secs(1.1)
			first = false
		else:
			await _secs(0.35)
		frames.append(await _grab(3))
		labels.append("FROM " + ["N", "E", "S", "W"][int(side / 90.0)] + " %.0f M" % Vector2(eye.x, eye.z).distance_to(at))
	var air := _air_eye(at, base_y)
	_park(air[0], Vector3(at.x, base_y, at.y), _gy(air[0].x, air[0].z) + 0.1)
	await _secs(0.45)
	frames.append(await _grab(3))
	labels.append(String(air[1]))
	var names: Array = s.get("names", [s.name])
	var info := [String(s.name).to_upper(), "KIND %s  X %.1f  Z %.1f  Y %.1f" % [String(s.kind).to_upper(), at.x, at.y, base_y], _region_name(at).to_upper(),
		"WAY %.0f M  TERRAIN %.1f  TOP %.1f" % [RealmLayout.path_dist(at), gy, top]]
	var rest := ", ".join(PackedStringArray(names.slice(1, 12).map(func(v: Variant) -> String: return String(v)))).to_upper()
	if rest != "":
		info.append("ALSO: " + rest)
	_save_sheet(s, frames, labels, info)


## A roof (anything solid, not the terrain or a tree) within 7 m over `e`.
func _roofed(e: Vector3) -> bool:
	var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(e, e + Vector3(0, 7.0, 0), Layers.WORLD | Layers.PROPS))
	if hit.is_empty():
		return false
	var cn := hit.collider as Node
	return cn != null and not cn.is_in_group(Groups.NO_LEDGE) and not String(cn.name).begins_with("Terrain")


## The oblique eye: 25 m up and 25 m south looking down at 45 degrees; where the ground (the Crowns, a cliff) is in the
## way, the other sides, then higher.
func _air_eye(at: Vector2, base_y: float) -> Array:
	var tg := Vector3(at.x, base_y, at.y)
	for up: float in [AIR_UP, 40.0, 60.0]:
		for side: float in [180.0, 90.0, 270.0, 0.0]:
			var dd := _dir(side) * up
			var e := Vector3(at.x + dd.x, base_y + up, at.y + dd.z)
			if e.y < _gy(e.x, e.z) + 3.0:
				continue
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(e, tg + Vector3(0, 1.0, 0), Layers.WORLD))
			if hit.is_empty() or (hit.position as Vector3).distance_to(tg) < 6.0:
				return [e, "AIR %.0f M, FROM %s" % [up, ["N", "E", "S", "W"][int(side / 90.0)]]]
	return [Vector3(at.x, base_y + 60.0, at.y + 30.0), "AIR 60 M, FROM S (BLOCKED)"]


## An eye on `side` of the place (0 = north of it), `d` out, pulled in or nudged round until it stands clear and sees the place.
func _side_eye(at: Vector2, side: float, d: float, base_y: float, tg: Vector3) -> Vector3:
	var dir := _dir(side)
	var best := Vector3.INF
	for f: float in [1.0, 0.75, 1.3, 0.55, 1.6, 0.4]:
		for jit: float in [0.0, 20.0, -20.0, 40.0, -40.0]:
			var dd := _dir(side + jit) * d * f
			var q := at + Vector2(dd.x, dd.z)
			var gt := _gy(q.x, q.y)
			var ground := gt
			if absf(gt - base_y) > 3.0:
				var tp := _top(q.x, q.y)
				if absf(tp - base_y) < absf(gt - base_y):
					ground = tp          # the place stands on a built floor (a deck, a bridge): so does the eye
			var e := Vector3(q.x, ground + EYE, q.y)
			var wl := RealmLayout.water_level_at(q.x, q.y)
			if not is_nan(wl) and wl > ground:
				e.y = wl + EYE
			if e.y < tg.y - d * f * 1.2 - 6.0:
				e.y = tg.y - d * f * 1.2 - 6.0          # (only ever raised: an eye is never put under the ground)
			if _buried(e) or _roofed(e):
				continue
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(e, tg, Layers.WORLD | Layers.PROPS))
			var clear := hit.is_empty() or (hit.position as Vector3).distance_to(tg) < maxf(3.0, d * f * 0.35)
			if clear:
				return e
			if best == Vector3.INF:
				best = e
	if best == Vector3.INF:
		best = Vector3(at.x + dir.x * d, base_y + EYE + 3.0, at.y + dir.z * d)
	return best


func _shoot_interior(s: Dictionary) -> void:
	var frames: Array = []
	var labels: Array = []
	var info := [String(s.name).to_upper(), String(s.kind).to_upper() + "  " + ", ".join(PackedStringArray((s.names as Array).map(func(v: Variant) -> String: return String(v)))).to_upper()]
	match String(s.kind):
		"room":
			var xf: Transform3D = s.xf
			var half: Vector3 = s.half
			var c := xf.origin
			var fl := _floor(c.x, c.z, c.y + half.y - 0.3, half.y * 2.0 + 1.0)
			if is_nan(fl):
				fl = c.y - half.y
			var eye := Vector3(c.x, fl + 1.6, c.z)
			info.append("X %.1f Z %.1f FLOOR %.1f  HALF %.1f x %.1f x %.1f" % [c.x, c.z, fl, half.x, half.y, half.z])
			var first := true
			for k in 4:
				var dir := xf.basis * Vector3(sin(k * PI * 0.5), 0, -cos(k * PI * 0.5))
				var from := eye - dir * minf(half.z if k % 2 == 0 else half.x, 6.0) * 0.8
				_park(from, from + dir * 4.0 + Vector3(0, -0.4, 0), fl)
				await _secs(1.0 if first else 0.2)
				first = false
				frames.append(await _grab(3))
				labels.append("VIEW %d" % (k + 1))
			var out_eye := c + xf.basis * Vector3(0, 0, half.z + 9.0)
			out_eye.y = _top(out_eye.x, out_eye.z) + 3.0
			_park(out_eye, c)
			await _secs(0.3)
			frames.append(await _grab(3))
			labels.append("OUTSIDE")
		"volume":
			var bx: AABB = s.box
			var c2 := bx.get_center()
			var fl2 := _floor(c2.x, c2.z, bx.position.y + minf(3.2, bx.size.y - 0.2), 6.0)
			if is_nan(fl2):
				fl2 = _floor(c2.x, c2.z, bx.end.y - 0.3, bx.size.y)
			if is_nan(fl2):
				fl2 = bx.position.y + 0.6
			info.append("BOX X %.0f..%.0f Y %.1f..%.1f Z %.0f..%.0f  FLOOR %.1f" % [bx.position.x, bx.end.x, bx.position.y, bx.end.y, bx.position.z, bx.end.z, fl2])
			var eye2 := Vector3(c2.x, fl2 + 1.6, c2.z)
			var first2 := true
			for yd: float in [0.0, 90.0, 180.0, 270.0]:
				var dir2 := _dir(yd)
				var reach := minf((bx.size.z if int(yd) % 180 == 0 else bx.size.x) * 0.4, 8.0)
				var from2 := eye2 - dir2 * reach
				if _buried(from2, 0.3):
					from2 = eye2
				_park(from2, from2 + dir2 * 4.0 + Vector3(0, -0.3, 0), fl2)
				await _secs(1.0 if first2 else 0.2)
				first2 = false
				frames.append(await _grab(3))
				labels.append(["N", "E", "S", "W"][int(yd / 90.0)])
			var air2 := Vector3(c2.x, bx.end.y + 18.0, c2.z + 18.0)
			_park(air2, c2, fl2)
			await _secs(0.3)
			frames.append(await _grab(3))
			labels.append("ABOVE")
		"stair":
			var a: Vector3 = s.from
			var b: Vector3 = s.to
			var fwd := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
			info.append("THRESHOLD %.1f, %.1f, %.1f  REWARD %.1f, %.1f, %.1f" % [a.x, a.y, a.z, b.x, b.y, b.z])
			var steps := [[a - fwd * 6.0 + Vector3(0, 2.6, 0), a + fwd * 6.0 + Vector3(0, -2.0, 0), "OUTSIDE THE DOOR"],
				[a + Vector3(0, 1.7, 0), a + fwd * 8.0 + Vector3(0, -3.0, 0), "THRESHOLD, DOWN"]]
			var half_v := a.lerp(b, 0.45)
			var mid_floor := _floor(half_v.x, half_v.z, b.y + 3.0, 8.0)
			steps.append([Vector3(half_v.x, (b.y if is_nan(mid_floor) else mid_floor) + 1.6, half_v.z), Vector3(half_v.x, b.y + 1.2, half_v.z) + fwd * 6.0, "MID, ON"])
			var near_b := b - fwd * 7.0
			steps.append([Vector3(near_b.x, b.y + 1.6, near_b.z), b + Vector3(0, 0.6, 0), "TO THE REWARD"])
			steps.append([b + Vector3(0, 1.6, 0) + fwd * 1.0, b - fwd * 8.0 + Vector3(0, 1.2, 0), "REWARD ROOM, BACK"])
			var first3 := true
			for st: Array in steps:
				_park(st[0], st[1], (st[0] as Vector3).y - 1.6)
				await _secs(1.0 if first3 else 0.35)
				first3 = false
				frames.append(await _grab(3))
				labels.append(String(st[2]))
		"oss":
			var e3: Vector3 = s.eye
			var fl3 := _floor(e3.x, e3.z, e3.y + 1.5, 4.0)
			if is_nan(fl3):
				fl3 = e3.y
			var eye3 := Vector3(e3.x, fl3 + 1.6, e3.z)
			info.append("X %.1f Y %.1f Z %.1f  FLOOR %.1f" % [e3.x, e3.y, e3.z, fl3])
			var crypt := main.find_child("Crypt", true, false)
			if crypt != null:
				# the AreaStreamer runs the Ossuary only round the wanderer, who is parked and not processing here: wake every
				# disabled ancestor so the pit hall's own gate (OssHall._physics_process) can show it to the camera
				var up_n := crypt.get_parent()
				while up_n != null:
					if up_n.process_mode == Node.PROCESS_MODE_DISABLED:
						up_n.process_mode = Node.PROCESS_MODE_INHERIT
					up_n = up_n.get_parent()
				var hn := crypt.get("hall") as Node3D
				print("MAPAUDIT crypt %s: built %s hall.visible %s in_tree %s phys %s proc_mode %d cam_local %s" % [s.name, crypt.get("built"), hn.visible if hn else "-", hn.is_visible_in_tree() if hn else "-", crypt.is_physics_processing(), crypt.process_mode, OssFrame.l(cam.global_position)])
			var face: Vector3 = s.face
			var base := 0.0 if face.length() < 0.1 else rad_to_deg(atan2(face.x, -face.z))
			if face.length() < 0.1:
				var hc := OssFrame.w(OssHall.C)
				base = rad_to_deg(atan2(hc.x - eye3.x, -(hc.z - eye3.z)))
			var first4 := true
			for k2 in 4:
				var yd2 := base + 90.0 * k2
				_park(eye3, eye3 + _dir(yd2) + Vector3(0, -0.12, 0), fl3)
				await _secs(2.0 if first4 else 0.25)
				if first4 and crypt != null:
					var hn2 := crypt.get("hall") as Node3D
					var anc := crypt.get_parent()
					print("MAPAUDIT crypt after park %s: hall.visible %s in_tree %s cam_local %s cam_current %s area_mode %d area_proc %s" % [s.name, hn2.visible, hn2.is_visible_in_tree(), OssFrame.l(cam.global_position), get_viewport().get_camera_3d() == cam, anc.process_mode, anc.can_process()])
				if first4 and "--near-debug" in OS.get_cmdline_user_args():
					_near_debug()
				first4 = false
				frames.append(await _grab(3))
				labels.append(["AHEAD", "RIGHT", "BEHIND", "LEFT"][k2])
			_park(eye3 + Vector3(0, 6.0, 0) - _dir(base) * 6.0, eye3 + _dir(base) * 8.0, fl3)
			await _secs(0.3)
			frames.append(await _grab(3))
			labels.append("HIGH, BEHIND")
			await _variants(s, eye3, fl3, base)
	_save_sheet(s, frames, labels, info)


## --variants=A,B,C (the "oss" spots): the AHEAD view again with the nodes named A hidden (then B, then C: each alone), saved beside
## the sheet's frames as <stem>_v_<name>.jpg. For "what draws that pale sheet": hide the suspect and look again (polish, 20 Nov).
func _variants(s: Dictionary, eye: Vector3, floor_y: float, base: float) -> void:
	var names: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--variants="):
			names = a.trim_prefix("--variants=").split(",", false)
	if names.is_empty() or headless:
		return
	var dir := out_root.path_join(section).path_join("full")
	DirAccess.make_dir_recursive_absolute(dir)
	for nm: String in names:
		var hidden: Array[Node3D] = []
		for n in main.find_children(nm, "Node3D", true, false):
			var n3 := n as Node3D
			if n3.visible:
				n3.visible = false
				hidden.append(n3)
		_park(eye, eye + _dir(base) + Vector3(0, -0.12, 0), floor_y)
		await _secs(0.4)
		var img: Image = await _grab(3)
		if img != null:
			img.convert(Image.FORMAT_RGB8)
			img.save_jpg(dir.path_join("%s_v_%s.jpg" % [String(s.name), nm]), 0.88)
		print("MAPAUDIT variant %s hid %d nodes" % [nm, hidden.size()])
		for n3: Node3D in hidden:
			if is_instance_valid(n3):
				n3.visible = true


# ------------------------------------------------------------------------------------------------------
# the sheet

func _save_sheet(s: Dictionary, frames: Array, labels: Array, info: Array) -> void:
	var at: Vector2 = s.at
	var reg := _region_id(at)
	var dir := out_root.path_join(section if section in ["interiors"] else reg)
	DirAccess.make_dir_recursive_absolute(dir.path_join("full"))
	var stem := String(s.name).replace(" ", "_").replace("/", "_").replace("'", "")
	index.append("| %s | %s | %s | (%.0f, %.0f) | %s | %s |" % [stem, reg, String(s.kind), at.x, at.y, ", ".join(PackedStringArray((s.get("names", []) as Array).map(func(v: Variant) -> String: return String(v)))).left(160), " / ".join(PackedStringArray(info.slice(3).map(func(v: Variant) -> String: return String(v))))])
	if headless:
		return
	var sheet := Image.create(CELL.x * 3, CELL.y * 2, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.07))
	for i in frames.size():
		var img := frames[i] as Image
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(dir.path_join("full").path_join("%s_%d.jpg" % [stem, i]), 0.88)
		var small := img.duplicate() as Image
		small.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		var cx := (i % 3) * CELL.x
		var cy := (i / 3) * CELL.y
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, CELL), Vector2i(cx, cy))
		_text(sheet, String(labels[i]), Vector2i(cx + 6, cy + 6), 2)
		_frame(sheet, Rect2i(cx, cy, CELL.x, CELL.y), Color(0.2, 0.2, 0.22))
	# the info card: text and a locator map
	var ix := 2 * CELL.x
	var iy := CELL.y
	var ty := iy + 10
	for line: Variant in info:
		for chunk: String in _wrap(String(line), 50):
			_text(sheet, chunk, Vector2i(ix + 10, ty), 2)
			ty += 20
	var mr := Rect2i(ix + 10, iy + CELL.y - 160, 270, 150)
	_map(sheet, mr, at)
	if lit:
		_text(sheet, "LIT: ADDED LAMP, NOT THE NIGHT GRADE", Vector2i(ix + 290, iy + CELL.y - 30), 1)
	sheet.save_jpg(dir.path_join(stem + ".jpg"), 0.9)


func _map(img: Image, r: Rect2i, at: Vector2) -> void:
	var b := RealmLayout.BOUNDS
	img.fill_rect(r, Color(0.13, 0.14, 0.16))
	var to_px := func(q: Vector2) -> Vector2i:
		return Vector2i(r.position.x + int((q.x - b.position.x) / b.size.x * r.size.x), r.position.y + int((q.y - b.position.y) / b.size.y * r.size.y))
	for reg: Dictionary in RealmLayout.REGIONS:
		if reg.has("rect"):
			var rr: Rect2 = reg.rect
			var a: Vector2i = to_px.call(rr.position)
			var e: Vector2i = to_px.call(rr.end)
			_frame(img, Rect2i(a, e - a).intersection(r), Color(0.3, 0.3, 0.34))
	for w: Dictionary in RealmLayout.PATHS:
		var pts: Array = w.pts
		for i in range(pts.size() - 1):
			for t in 12:
				var q: Vector2i = to_px.call((pts[i] as Vector2).lerp(pts[i + 1], float(t) / 12.0))
				if r.has_point(q):
					img.set_pixelv(q, Color(0.55, 0.45, 0.3))
	var c: Vector2i = to_px.call(at)
	img.fill_rect(Rect2i(c - Vector2i(3, 3), Vector2i(7, 7)).intersection(r), Color(1.0, 0.25, 0.2))
	_frame(img, r, Color(0.5, 0.5, 0.55))


func _frame(img: Image, r: Rect2i, col: Color) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), col)
	img.fill_rect(Rect2i(r.position + Vector2i(0, r.size.y - 1), Vector2i(r.size.x, 1)), col)
	img.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), col)
	img.fill_rect(Rect2i(r.position + Vector2i(r.size.x - 1, 0), Vector2i(1, r.size.y)), col)


static func _wrap(s: String, n: int) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in s.split(" "):
		if cur.length() + word.length() + 1 > n and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = word if cur == "" else cur + " " + word
	if cur != "":
		out.append(cur)
	return out


func _text(img: Image, text: String, at: Vector2i, sc := 2) -> void:
	var w := text.length() * 6 * sc + 4
	var h := 7 * sc + 4
	var bg := Rect2i(at, Vector2i(w, h)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if bg.size.x > 0:
		img.fill_rect(bg, Color(0, 0, 0))
	var x0 := at.x + 2
	for ch in text.to_upper():
		var g: Array = FONT.get(ch, FONT["?"])
		for gy in 7:
			var row := String(g[gy])
			for gx in 5:
				if row[gx] == "1":
					var px := Rect2i(x0 + gx * sc, at.y + 2 + gy * sc, sc, sc)
					if Rect2i(Vector2i.ZERO, img.get_size()).encloses(px):
						img.fill_rect(px, Color(0.95, 0.92, 0.8))
		x0 += 6 * sc


func _write_index() -> void:
	var f := FileAccess.open(out_root.path_join("index_%s%s.md" % [section, ("_" + str(rows.x)) if section == "grid" else (("_" + str(part.x)) if section == "places" else "")]), FileAccess.WRITE)
	if f == null:
		return
	f.store_string("| spot | region | kind | at | names | notes |\n|---|---|---|---|---|---|\n" + "\n".join(PackedStringArray(index)) + "\n")
	f.close()


const FONT := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"], "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"], "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"], "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"], "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"], "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"], "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"], "N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"], "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"], "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"], "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"], "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"], "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"], "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"], "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"], "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"], "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"], "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"], "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"], "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"], ",": ["00000", "00000", "00000", "00000", "01100", "00100", "01000"],
	":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"], "(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
	")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"], "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	"_": ["00000", "00000", "00000", "00000", "00000", "00000", "11111"], "'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
	"+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"], "=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
	"#": ["01010", "01010", "11111", "01010", "11111", "01010", "01010"], "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
	"!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
}
