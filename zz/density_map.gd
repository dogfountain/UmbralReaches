extends Node
## The Realm from above as data (world density pass, realm_wayside.gd / flora_layers.gd): once the night is built,
## a 1 px = 1 m map of the whole Realm is written: the ground's height (grey), water (blue), the ways (pale), the
## undergrowth's density (green), trees (dark dots), registered sites (red), the wayside's places (by kind: a coloured
## disc, ringed white when named), and a heat layer of how far the nearest thing worth a look is (the darker red,
## the emptier). Prints the coverage numbers along the ways.
##   godot --headless --path . res://zz/density_map.tscn -- --out=<dir> [--no-density]
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Wayside := preload("res://core/world/realm/realm_wayside.gd")
const Land := preload("res://core/world/realm/realm_land.gd")

const COLORS := {"wall": Color(0.85, 0.75, 0.5), "fold": Color(0.9, 0.8, 0.45), "cottage": Color(1.0, 0.55, 0.2), "shrine": Color(1.0, 0.95, 0.3),
	"stones": Color(0.7, 0.7, 0.95), "circle": Color(0.55, 0.55, 1.0), "cairns": Color(0.8, 0.8, 0.8), "cart": Color(0.75, 0.45, 0.25),
	"camp": Color(1.0, 0.35, 0.1), "well": Color(0.3, 0.8, 1.0), "graves": Color(0.9, 0.9, 0.9), "woodpile": Color(0.55, 0.35, 0.15),
	"statue": Color(1.0, 1.0, 1.0), "blocks": Color(0.65, 0.65, 0.6), "lookout": Color(1.0, 0.2, 1.0), "battle": Color(0.8, 0.15, 0.15),
	"debris": Color(0.4, 0.3, 0.25), "barrow": Color(0.45, 0.65, 0.3), "charcoal": Color(0.2, 0.2, 0.2), "farm": Color(0.95, 0.85, 0.2),
	"milestone": Color(0.6, 0.6, 0.6), "jetty": Color(0.2, 0.5, 1.0), "bones": Color(0.95, 0.9, 0.8)}
var main: Node
var t := 0
var out := "/tmp"


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	t += 1
	if main == null or not main.has_meta("realm_done") or t < 30:
		return
	set_process(false)
	_draw()
	get_tree().quit()


func _draw() -> void:
	var b := RealmLayout.BOUNDS
	var w := int(b.size.x)
	var h := int(b.size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var space := (main as Node3D).get_world_3d().direct_space_state
	var dens := PackedFloat32Array()
	dens.resize(w * h)
	var trees := PackedByteArray()
	trees.resize(w * h)
	var grass := PackedFloat32Array()
	grass.resize(w * h)
	for it: Array in Flora.instance_list():
		var p: Vector3 = it[1]
		var i := int(p.x - b.position.x)
		var j := int(p.z - b.position.y)
		if i < 0 or j < 0 or i >= w or j >= h:
			continue
		var nm := String(it[0])
		var sp := nm.substr(0, nm.rfind("_"))
		if sp in ["oak", "pine", "birch", "willow", "snag", "yew", "windtree", "fruit", "cypress"]:
			trees[j * w + i] = 1
		elif sp != "grass":
			dens[j * w + i] += 1.0
		else:
			grass[j * w + i] += 1.0
	for j in h:
		for i in w:
			var x := b.position.x + i + 0.5
			var z := b.position.y + j + 0.5
			var gy := RealmLayout.ground(space, x, z)
			var c := Color(0.18, 0.18, 0.18).lerp(Color(0.5, 0.5, 0.5), clampf((gy + 4.0) / 24.0, 0.0, 1.0))
			if Land.in_water(x, z):
				c = Color(0.1, 0.2, 0.42)
			# undergrowth (not grass) per 3x3 m
			var n := 0.0
			var gn := 0.0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := clampi(i + di, 0, w - 1)
					var jj := clampi(j + dj, 0, h - 1)
					n += dens[jj * w + ii]
					gn += grass[jj * w + ii]
			c = c.lerp(Color(0.45, 0.5, 0.2), clampf(gn / 30.0, 0.0, 0.7))        # grass alone: olive
			c = c.lerp(Color(0.2, 0.75, 0.25), clampf(n / 6.0, 0.0, 0.85))        # the layered undergrowth: green
			if RealmLayout.path_dist(Vector2(x, z)) < 0.0:
				c = Color(0.82, 0.78, 0.66)
			if trees[j * w + i] == 1:
				c = Color(0.03, 0.22, 0.06)
			img.set_pixel(i, j, c)
	for st: Dictionary in WorldLanes.sites:
		var r: Rect2 = st.rect
		var col := Color(0.9, 0.15, 0.15) if not String(st.name).begins_with("way_") else Color(1.0, 0.7, 0.7)
		_rect(img, r, col)
	for v: Dictionary in Wayside.plan:
		var a: Vector3 = v.at
		var col2: Color = COLORS.get(String(v.kind), Color(1, 0, 1))
		_disc(img, Vector2(a.x, a.z), 3.0, col2)
		if String(v.get("name", "")) != "":
			_ring(img, Vector2(a.x, a.z), 5.5, Color(1, 1, 1))
		if String(v.get("box", "")) != "":
			_disc(img, Vector2(a.x + 4.0, a.z - 4.0), 1.2, Color(1.0, 0.85, 0.1))
		if String(v.get("lore", "")) != "":
			_disc(img, Vector2(a.x - 4.0, a.z - 4.0), 1.2, Color(0.4, 0.9, 1.0))
	img.save_png(out.path_join("density_map.png"))
	# the four quarters at 2x (west/east, north/south) to read the detail
	for q in 4:
		var rx := (q % 2) * (w / 2)
		var ry := (q / 2) * (h / 2)
		var part := img.get_region(Rect2i(rx, ry, w / 2, h / 2))
		part.resize(w, h, Image.INTERPOLATE_NEAREST)
		part.save_png(out.path_join("density_%s.png" % ["nw", "ne", "sw", "se"][q]))
	# coverage along the ways: how far the nearest thing worth a look is, every 4 m
	var ds: Array[float] = []
	for p: Dictionary in RealmLayout.PATHS:
		var pts: Array = p.pts
		for k in pts.size() - 1:
			var a2: Vector2 = pts[k]
			var b2: Vector2 = pts[k + 1]
			var seg := a2.distance_to(b2)
			var s := 0.0
			while s < seg:
				ds.append(_nearest(a2.lerp(b2, s / seg)))
				s += 4.0
	ds.sort()
	var over := 0
	for d in ds:
		if d > 45.0:
			over += 1
	print("DENSITY ways: %d samples, median %.1f m, p90 %.1f m, max %.1f m to the nearest place; %d (%.0f %%) over 45 m" % [ds.size(),
		ds[ds.size() / 2], ds[int(ds.size() * 0.9)], ds[ds.size() - 1], over, 100.0 * over / maxf(ds.size(), 1)])
	print("DENSITY wayside %d places, flora layers %s" % [Wayside.plan.size(), load("res://core/world/realm/flora_layers.gd").get("counts")])
	print("DENSITY map ", out.path_join("density_map.png"))


func _nearest(q: Vector2) -> float:
	var best := 999.0
	for st: Dictionary in WorldLanes.sites:
		var r: Rect2 = st.rect
		if r.size.x > 60.0:
			continue
		var dx := maxf(maxf(r.position.x - q.x, 0.0), q.x - r.end.x)
		var dz := maxf(maxf(r.position.y - q.y, 0.0), q.y - r.end.y)
		best = minf(best, sqrt(dx * dx + dz * dz))
	return best


func _px(q: Vector2) -> Vector2i:
	var b := RealmLayout.BOUNDS
	return Vector2i(int(q.x - b.position.x), int(q.y - b.position.y))


func _rect(img: Image, r: Rect2, c: Color) -> void:
	var a := _px(r.position)
	var e := _px(r.end)
	for i in range(a.x, e.x + 1):
		for j: int in [a.y, e.y]:
			if i >= 0 and j >= 0 and i < img.get_width() and j < img.get_height():
				img.set_pixel(i, j, c)
	for j2 in range(a.y, e.y + 1):
		for i2: int in [a.x, e.x]:
			if i2 >= 0 and j2 >= 0 and i2 < img.get_width() and j2 < img.get_height():
				img.set_pixel(i2, j2, c)


func _disc(img: Image, q: Vector2, r: float, c: Color) -> void:
	var p := _px(q)
	var n := ceili(r)
	for dj in range(-n, n + 1):
		for di in range(-n, n + 1):
			if di * di + dj * dj <= r * r:
				var i := p.x + di
				var j := p.y + dj
				if i >= 0 and j >= 0 and i < img.get_width() and j < img.get_height():
					img.set_pixel(i, j, c)


func _ring(img: Image, q: Vector2, r: float, c: Color) -> void:
	for k in 48:
		var a := TAU * k / 48.0
		_disc(img, q + Vector2(cos(a), sin(a)) * r, 0.6, c)
