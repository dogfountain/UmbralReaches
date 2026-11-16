extends Node
## A plan of a piece of the Realm as built (for laying out a town): one PNG per rect, 4 px a metre, the ground
## hill-shaded by its height (RealmLand), fen water blue, ways tan (RealmLayout.path_dist), registered sites
## outlined, encounter camps red, region fires orange, grid lines every 10 m (brighter every 50 m), and a text grid
## of heights (every 6 m) beside it.
##   godot --headless --path . res://zz/town_map.tscn -- --out=<dir> --rect=name:x0:z0:x1:z1 [--rect=...] [--ppm=4]
## North (-z) is up, east (+x) right. Never writes the save (Travel._busy).
const Land := preload("res://core/world/realm/realm_land.gd")
var main: Node
var out := "/tmp"
var rects: Array = []
var ppm := 4


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--ppm="):
			ppm = int(a.trim_prefix("--ppm="))
		elif a.begins_with("--rect="):
			var g := a.trim_prefix("--rect=").split(":")
			rects.append([g[0], Rect2(float(g[1]), float(g[2]), float(g[3]) - float(g[1]), float(g[4]) - float(g[2]))])
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(1.0).timeout
	for r: Array in rects:
		_plan(String(r[0]), r[1] as Rect2)
	print("TOWN_MAP done")
	get_tree().quit()


func _plan(nm: String, rc: Rect2) -> void:
	var w := int(rc.size.x * ppm)
	var h := int(rc.size.y * ppm)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var hs := PackedFloat32Array()
	hs.resize(w * h)
	var lo := INF
	var hi := -INF
	for j in h:
		for i in w:
			var x := rc.position.x + (i + 0.5) / ppm
			var z := rc.position.y + (j + 0.5) / ppm
			var y: float = Land.height_at(x, z)
			hs[j * w + i] = y
			lo = minf(lo, y)
			hi = maxf(hi, y)
	for j in h:
		for i in w:
			var x := rc.position.x + (i + 0.5) / ppm
			var z := rc.position.y + (j + 0.5) / ppm
			var y := hs[j * w + i]
			var t := clampf((y - lo) / maxf(hi - lo, 0.1), 0.0, 1.0)
			var yl := hs[j * w + maxi(i - 1, 0)]
			var yu := hs[maxi(j - 1, 0) * w + i]
			var shade := clampf(0.75 + (yl - y) * 1.2 + (yu - y) * 1.2, 0.35, 1.25)
			var c := Color(0.32, 0.42, 0.24).lerp(Color(0.72, 0.66, 0.5), t) * shade
			if Land.in_water(x, z):
				var dep: float = Land.water_y_at(x, z) - y
				c = Color(0.15, 0.3, 0.55).darkened(clampf(dep * 0.4, 0.0, 0.6))
			var pd := RealmLayout.path_dist(Vector2(x, z))
			if pd < 1.2:
				c = Color(0.82, 0.7, 0.48)
			elif pd < 2.0:
				c = c.lerp(Color(0.82, 0.7, 0.48), 0.4)
			var st := WorldLanes.site_at(Vector2(x, z))
			if not st.is_empty():
				c = c.lerp(Color(0.8, 0.3, 0.8), 0.18)
			var gx := fposmod(x, 10.0)
			var gz := fposmod(z, 10.0)
			if gx < 1.0 / ppm or gz < 1.0 / ppm:
				var big := fposmod(x, 50.0) < 1.0 / ppm or fposmod(z, 50.0) < 1.0 / ppm
				c = c.lerp(Color.WHITE if big else Color(0.1, 0.1, 0.1), 0.5 if big else 0.3)
			img.set_pixel(i, j, c)
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		var at: Vector3 = cp.get("at", Vector3.INF)
		_dot(img, rc, Vector2(at.x, at.z), 5, Color(0.9, 0.1, 0.1))
	for rid: String in RealmLayout.SLOTS:
		for sl: Dictionary in RealmLayout.SLOTS[rid]:
			var col := Color(1.0, 0.55, 0.1) if String(sl.kind) == "fire" else (Color(0.1, 0.9, 0.9) if String(sl.kind).begins_with("poi") else Color(0.6, 0.0, 0.0))
			_dot(img, rc, sl.at as Vector2, 3, col)
	img.save_png(out.path_join("map_%s.png" % nm))
	var txt := PackedStringArray()
	txt.append("%s %s heights %.2f..%.2f (rows z, cols x every 6 m)" % [nm, rc, lo, hi])
	var head := "      "
	var x0 := snappedf(rc.position.x, 6.0)
	var xs: Array[float] = []
	var xx := x0
	while xx <= rc.end.x:
		xs.append(xx)
		head += "%7d" % int(xx)
		xx += 6.0
	txt.append(head)
	var zz := snappedf(rc.position.y, 6.0)
	while zz <= rc.end.y:
		var line := "%6d" % int(zz)
		for x: float in xs:
			var y: float = Land.height_at(x, zz)
			line += ("%6.1f" % y) + ("~" if Land.in_water(x, zz) else (" " if RealmLayout.path_dist(Vector2(x, zz)) > 1.5 else "="))
		txt.append(line)
		zz += 6.0
	var f := FileAccess.open(out.path_join("map_%s.txt" % nm), FileAccess.WRITE)
	f.store_string("\n".join(txt))
	print("TOWN_MAP %s heights %.2f..%.2f" % [nm, lo, hi])


func _dot(img: Image, rc: Rect2, p: Vector2, r: int, c: Color) -> void:
	var cx := int((p.x - rc.position.x) * ppm)
	var cy := int((p.y - rc.position.y) * ppm)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r and cx + dx >= 0 and cy + dy >= 0 and cx + dx < img.get_width() and cy + dy < img.get_height():
				img.set_pixel(cx + dx, cy + dy, c)
