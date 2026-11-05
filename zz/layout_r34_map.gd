extends Node
## r34 layout: a top-down plan of the Realm as built (heights, biomes, roads, water, sites, regions,
## raid footprints) written to a PNG, for planning and for docs/r34/layout.md. Headless is fine.
##   HOME=<scratch> godot --headless --path . res://zz/layout_r34_map.tscn -- --out=<dir> [--px=2] [--land]
## --land builds only the land module (fast). Never writes the save (Travel._busy).
const Land := preload("res://core/world/realm/realm_land.gd")

var main: Node
var out_dir := "user://"
var px := 2.0                     ## metres per pixel
var view := Rect2()
var tag := "realm_map"
var t := 0.0
var done := false


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--px="):
			px = float(a.trim_prefix("--px="))
		elif a.begins_with("--view="):
			var v := a.trim_prefix("--view=").split(",")
			view = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if done:
		return
	if t > 200.0:
		print("MAP FAIL timeout")
		get_tree().quit(1)
		return
	if main == null or not main.is_inside_tree():
		return
	var land_only := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--realm-modules="):
			land_only = true
	if not (main.has_meta("realm_done") or (land_only and t > 6.0)):
		return
	done = true
	await get_tree().physics_frame
	_draw()
	get_tree().quit()


func _col_biome(bw: Dictionary) -> Color:
	var cols := {"meadow": Color(0.42, 0.5, 0.28), "loam": Color(0.2, 0.32, 0.16), "mud": Color(0.3, 0.3, 0.24),
		"ash": Color(0.3, 0.24, 0.22), "heath": Color(0.52, 0.42, 0.3), "crag": Color(0.5, 0.5, 0.5), "ruin": Color(0.55, 0.5, 0.42)}
	var c := Color(0, 0, 0)
	for k: String in bw:
		c += cols[k] * float(bw[k])
	c.a = 1.0
	return c


func _draw() -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	if view.size == Vector2.ZERO:
		view = RealmLayout.BOUNDS.grow(24.0)
	var w := int(view.size.x / px)
	var h := int(view.size.y / px)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var hmin := INF
	var hmax := -INF
	var flat_bad := 0
	for j in h:
		for i in w:
			var x := view.position.x + (i + 0.5) * px
			var z := view.position.y + (j + 0.5) * px
			var gy := RealmLayout.ground(space, x, z)
			hmin = minf(hmin, gy)
			hmax = maxf(hmax, gy)
			var c := _col_biome(Land.biome_weights(x, z))
			# hillshade from neighbours
			var gx := RealmLayout.ground(space, x + 1.0, z) - gy
			var gz := RealmLayout.ground(space, x, z + 1.0) - gy
			var shade := clampf(0.75 - (gx * 0.6 + gz * 0.4) * 0.6, 0.25, 1.3)
			var tint := clampf((gy + 10.0) / 50.0, 0.0, 1.0)
			c = c * shade
			c = c.lerp(Color(0.95, 0.95, 1.0), tint * 0.35)
			if Land.in_water(x, z):
				c = Color(0.12, 0.2, 0.3)
			if gy < -5.0:
				c = c.lerp(Color(0.5, 0.12, 0.02), 0.6)
			if RealmLayout.path_dist(Vector2(x, z)) < 0.0:
				c = Color(0.85, 0.75, 0.55)
			if not RealmLayout.BOUNDS.has_point(Vector2(x, z)):
				c = c.darkened(0.45)
			# contour every 5 m
			if fmod(absf(gy) + 0.0001, 5.0) < 0.35 * px:
				c = c.darkened(0.25)
			img.set_pixel(i, j, c)
	var plot := func(p: Vector2, col: Color, r: float) -> void:
		var ci := int((p.x - view.position.x) / px)
		var cj := int((p.y - view.position.y) / px)
		var rr := int(ceil(r / px))
		for dj in range(-rr, rr + 1):
			for di in range(-rr, rr + 1):
				if Vector2(di, dj).length() * px <= r and ci + di >= 0 and cj + dj >= 0 and ci + di < w and cj + dj < h:
					img.set_pixel(ci + di, cj + dj, col)
	var ring := func(c: Vector2, r: float, col: Color) -> void:
		var n := int(TAU * r / px * 1.5) + 8
		for k in n:
			var a := TAU * k / n
			plot.call(c + Vector2(cos(a), sin(a)) * r, col, px * 0.6)
	# sites (outlines)
	for s: Dictionary in WorldLanes.sites:
		var r: Rect2 = s.rect
		if s.has("circle"):
			var cc: Vector3 = s.circle
			ring.call(Vector2(cc.x, cc.y), cc.z, Color(0.9, 0.3, 0.9))
			continue
		for k in 24:
			var tt := k / 24.0
			for e: Array in [[r.position, Vector2(r.end.x, r.position.y)], [r.position, Vector2(r.position.x, r.end.y)], [r.end, Vector2(r.end.x, r.position.y)], [r.end, Vector2(r.position.x, r.end.y)]]:
				plot.call((e[0] as Vector2).lerp(e[1], tt), Color(0.95, 0.45, 0.95), px * 0.4)
	# regions
	for rd: Dictionary in RealmLayout.REGIONS:
		if rd.has("rect"):
			var r: Rect2 = rd.rect
			for k in 60:
				var tt := k / 60.0
				for e: Array in [[r.position, Vector2(r.end.x, r.position.y)], [r.position, Vector2(r.position.x, r.end.y)], [r.end, Vector2(r.end.x, r.position.y)], [r.end, Vector2(r.position.x, r.end.y)]]:
					plot.call((e[0] as Vector2).lerp(e[1], tt), Color(1, 1, 0.2), px * 0.5)
		else:
			ring.call(rd.c, float(rd.r), Color(1, 1, 0.2))
	# raids
	for rd: Dictionary in (load("res://core/world/realm/realm_layout.gd") as GDScript).get_script_constant_map().get("RAIDS", []):
		ring.call(rd.c, float(rd.r), Color(1, 0.2, 0.1))
	# braziers, markers
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		var p := (b as Node3D).global_position
		plot.call(Vector2(p.x, p.z), Color(1, 0.6, 0.1), 1.6)
	for m in get_tree().get_nodes_in_group(&"map_marker"):
		if m is Node3D and not (m is Brazier):
			var p := (m as Node3D).global_position
			plot.call(Vector2(p.x, p.z), Color(0.3, 0.9, 1.0), 1.0)
	plot.call(Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z), Color(1, 1, 1), 2.0)
	# grid ticks every 50 m (10 m in a close view)
	var gs := 10 if view.size.x < 160.0 else 50
	for gxv in range(-250, 251, gs):
		for j in h:
			var i := int((gxv - view.position.x) / px)
			if i >= 0 and i < w and j % 4 == 0:
				img.set_pixel(i, j, Color(1, 1, 1))
	for gzv in range(-250, 251, gs):
		for i in w:
			var j := int((gzv - view.position.y) / px)
			if j >= 0 and j < h and i % 4 == 0:
				img.set_pixel(i, j, Color(1, 1, 1))
	var path := out_dir.path_join(tag + ".png")
	img.save_png(path)
	print("MAP saved %s (%dx%d, %.1f m/px) view %s heights %.1f..%.1f" % [path, w, h, px, view, hmin, hmax])
	for rd: Dictionary in RealmLayout.REGIONS:
		var c: Vector2 = rd.c if rd.has("c") else (rd.rect as Rect2).get_center()
		print("MAP region %-10s at %s ground %.1f" % [rd.id, c, RealmLayout.ground(space, c.x, c.y)])
	_census()


## Density census (docs/r34/layout.md): per region (region_at) its ground area in BOUNDS (1 m cells),
## flora instances, trees, sites, lore inscriptions, braziers, map markers, POIs, camps; and the walked
## network's length.
func _census() -> void:
	var b := RealmLayout.BOUNDS
	var area := {}
	var x := b.position.x + 0.5
	while x < b.end.x:
		var z := b.position.y + 0.5
		while z < b.end.y:
			var id := String(RealmLayout.region_at(x, z).get("id", "-"))
			area[id] = int(area.get(id, 0)) + 4
			z += 2.0
		x += 2.0
	var rows := {}
	var add := func(id: String, key: String, n: int) -> void:
		if not rows.has(id):
			rows[id] = {}
		rows[id][key] = int(rows[id].get(key, 0)) + n
	var reg := func(p: Vector3) -> String:
		return String(RealmLayout.region_at(p.x, p.z).get("id", "-"))
	var flora_s: GDScript = load("res://core/world/realm/realm_flora.gd")
	for it: Array in flora_s.get("instances"):
		add.call(reg.call(it[1]), "flora", 1)
	for tr: Array in flora_s.get("trees"):
		add.call(reg.call(tr[0]), "trees", 1)
	for st: Dictionary in WorldLanes.sites:
		var c: Vector2 = (st.rect as Rect2).get_center()
		add.call(reg.call(Vector3(c.x, 0, c.y)), "sites", 1)
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		add.call(reg.call((n as Node3D).global_position), "fires", 1)
	var pois: Dictionary = (load("res://core/world/realm/realm_pois.gd") as GDScript).get("spots")
	for pid: String in pois:
		add.call(reg.call(pois[pid].at), "pois", 1)
	for n in get_tree().get_nodes_in_group(&"map_marker"):
		if n is Node3D and not (n is Brazier):
			add.call(reg.call((n as Node3D).global_position), "markers", 1)
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is LoreScrap:
			add.call(reg.call((n as Node3D).global_position), "scraps", 1)
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		add.call(reg.call(cp.at), "camps", 1)
	var ids := area.keys()
	ids.sort()
	var tot := {}
	for id: String in ids:
		var r: Dictionary = rows.get(id, {})
		var a := float(area[id])
		print("CENSUS %-11s area %6.0f m2  flora %6d (%.2f/m2)  trees %4d (%.2f/1000m2)  sites %3d  scraps %3d  fires %d  pois %d  markers %d  camps %d" % [
			id, a, int(r.get("flora", 0)), float(r.get("flora", 0)) / a, int(r.get("trees", 0)), 1000.0 * float(r.get("trees", 0)) / a,
			int(r.get("sites", 0)), int(r.get("scraps", 0)), int(r.get("fires", 0)), int(r.get("pois", 0)), int(r.get("markers", 0)), int(r.get("camps", 0))])
		for k: String in r:
			tot[k] = int(tot.get(k, 0)) + int(r[k])
	var plen := 0.0
	for pth: Dictionary in RealmLayout.PATHS:
		var pts: Array = pth.pts
		for i in pts.size() - 1:
			plen += (pts[i] as Vector2).distance_to(pts[i + 1])
	print("CENSUS total area %.0f m2 %s; ways %.0f m; camps per 100 m of way %.2f" % [b.get_area(), tot, plen, 100.0 * float(EnemySpawner.REALM_CAMPS.size()) / plen])
