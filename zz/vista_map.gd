extends Node
const Land := preload("res://core/world/realm/realm_land.gd")
## A design map of the Realm's ground: hillshade from RealmLand's built heights, water, the ways and the region
## rects, 2 px per metre, written to --out=<png> (default /tmp/vista_map.png). Headless is fine.
##   godot --headless --path . res://zz/vista_map.tscn -- --out=<png> [--scale=2] [--modules=land]
var main: Node
var out := "/tmp/vista_map.png"
var sc := 2.0
var t := 0


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--scale="):
			sc = float(a.trim_prefix("--scale="))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	t += 1
	if not main.has_meta("realm_done") or t < 30:
		return
	set_process(false)
	_draw()
	get_tree().quit()


func _draw() -> void:
	var b := RealmLayout.OUTER
	var w := int(b.size.x * sc)
	var h := int(b.size.y * sc)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var sun := Vector3(-0.6, 0.7, -0.4).normalized()
	var hs := PackedFloat32Array()
	hs.resize(w * h)
	for py in h:
		var z := b.position.y + (py + 0.5) / sc
		for px in w:
			var x0 := b.position.x + (px + 0.5) / sc
			if x0 < -380.0 or x0 > 380.0 or z < -158.0 or z > 408.0:
				var bb := RealmLayout.BOUNDS.grow(-4.0)
				hs[py * w + px] = Land._base(x0, z, Land._bw(clampf(x0, bb.position.x, bb.end.x), clampf(z, bb.position.y, bb.end.y)))
			else:
				hs[py * w + px] = Land.height_at(x0, z)
	var e := 1.0 / sc
	for py in h:
		var z := b.position.y + (py + 0.5) / sc
		for px in w:
			var x := b.position.x + (px + 0.5) / sc
			var y := hs[py * w + px]
			var dx := hs[py * w + mini(px + 1, w - 1)] - hs[py * w + maxi(px - 1, 0)]
			var dz := hs[mini(py + 1, h - 1) * w + px] - hs[maxi(py - 1, 0) * w + px]
			var n := Vector3(-dx, 2.0 * e, -dz).normalized()
			var shade := clampf(n.dot(sun), 0.0, 1.0)
			var k := clampf((y + 10.0) / 70.0, 0.0, 1.0)
			var tint := Color(0.32, 0.42, 0.30).lerp(Color(0.62, 0.55, 0.40), smoothstep(0.1, 0.45, k)).lerp(Color(0.88, 0.88, 0.9), smoothstep(0.45, 0.9, k))
			var c := tint * (0.35 + 0.75 * shade)
			if Land.in_water(x, z) or (x < -164.0 and RealmLayout.river_mask(x, z) > 0.5):
				c = Color(0.18, 0.3, 0.5) * (0.6 + 0.4 * shade)
			if fposmod(y, 5.0) < 0.18:
				c = c.darkened(0.3)
			if not RealmLayout.BOUNDS.has_point(Vector2(x, z)):
				c = c.darkened(0.35)
			img.set_pixel(px, py, c)
	for pa: Dictionary in RealmLayout.PATHS:
		var pts: Array = pa.pts
		for k2 in pts.size() - 1:
			var a: Vector2 = pts[k2]
			var c2: Vector2 = pts[k2 + 1]
			var n2 := int(a.distance_to(c2) * sc) + 1
			for s in n2:
				var q := a.lerp(c2, float(s) / n2)
				var ix := int((q.x - b.position.x) * sc)
				var iz := int((q.y - b.position.y) * sc)
				if ix >= 0 and iz >= 0 and ix < w and iz < h:
					img.set_pixel(ix, iz, Color(0.95, 0.85, 0.55))
	for r: Dictionary in RealmLayout.REGIONS:
		if not r.has("rect"):
			continue
		var rc: Rect2 = r.rect
		var x0 := int((rc.position.x - b.position.x) * sc)
		var z0 := int((rc.position.y - b.position.y) * sc)
		var x1 := int((rc.end.x - b.position.x) * sc)
		var z1 := int((rc.end.y - b.position.y) * sc)
		for xx in range(x0, x1):
			for zz in [z0, z1 - 1]:
				if xx >= 0 and xx < w and zz >= 0 and zz < h and (xx / 3) % 2 == 0:
					img.set_pixel(xx, zz, Color(1, 1, 1))
		for zz2 in range(z0, z1):
			for xx2 in [x0, x1 - 1]:
				if xx2 >= 0 and xx2 < w and zz2 >= 0 and zz2 < h and (zz2 / 3) % 2 == 0:
					img.set_pixel(xx2, zz2, Color(1, 1, 1))
	img.save_png(out)
	print("VISTA_MAP ", out)
