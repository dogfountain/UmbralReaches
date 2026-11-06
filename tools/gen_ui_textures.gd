extends SceneTree
## Bakes the medieval menu textures into art/ui/ (small nine-patch PNGs, all procedural, no outside art):
##   godot --headless --path . --script tools/gen_ui_textures.gd
## Leather, parchment, carved wood, forged iron and brass are noise + bevel math on an Image.
## ui/medieval_style.gd reads the PNGs back as StyleBoxTexture nine-patches.

const OUT := "res://art/ui/"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7311
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_leather(96, 96), "leather_panel")
	_save(_parchment(96, 96, true), "parchment_panel")
	_save(_parchment(48, 48, false), "parchment_slip")
	_save(_plaque(96, 48, 0), "plaque_normal")
	_save(_plaque(96, 48, 1), "plaque_hover")
	_save(_plaque(96, 48, 2), "plaque_pressed")
	_save(_plaque(96, 48, 3), "plaque_disabled")
	_save(_plaque(96, 48, 4), "plaque_focus")
	_save(_tab(80, 40, false), "tab_off")
	_save(_tab(80, 40, true), "tab_on")
	_save(_slot(56), "slot")
	_save(_iron_bar(72, 40), "iron_frame")
	_save(_banner(160, 40), "banner")
	_save(_inset(48), "inset")
	quit()


func _save(img: Image, n: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	print("ui texture %s %dx%d -> %d" % [n, img.get_width(), img.get_height(), err])


func _noise(freq: float, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH, oct := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = oct
	n.seed = _rng.randi()
	return n


static func _mul(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1), c.a)


## Distance to the nearest edge of a w x h image, in pixels (0 on the outermost row).
static func _edge(x: int, y: int, w: int, h: int) -> int:
	return mini(mini(x, w - 1 - x), mini(y, h - 1 - y))


func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			img.set_pixel(x, y, c)


func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var o := img.get_pixel(x, y)
	img.set_pixel(x, y, o.lerp(Color(c.r, c.g, c.b, maxf(o.a, c.a)), c.a))


## A square bevelled rivet (brass or iron) with a highlight.
func _rivet(img: Image, cx: int, cy: int, r: int, base: Color) -> void:
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var d := Vector2(x, y).length()
			if d <= r + 0.5:
				var k := 1.0 - d / (r + 1.0) * 0.45
				var hl := clampf(1.0 - (Vector2(x + r * 0.4, y + r * 0.4).length() / (r * 0.9)), 0.0, 1.0)
				var c := _mul(base, k + hl * 0.55)
				c.a = 1.0
				_blend(img, cx + x, cy + y, c)
			elif d <= r + 1.5:
				_blend(img, cx + x, cy + y, Color(0, 0, 0, 0.55))


# --- leather -------------------------------------------------------------------------------------------

func _leather_fill(img: Image, base: Color, rect: Rect2i) -> void:
	var peb := _noise(0.16, FastNoiseLite.TYPE_CELLULAR, 1)
	peb.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var fine := _noise(0.5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var mott := _noise(0.025, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := (peb.get_noise_2d(x, y) + 1.0) * 0.5
			var f := fine.get_noise_2d(x, y)
			var m := mott.get_noise_2d(x, y)
			var k := 0.78 + p * 0.3 + f * 0.08 + m * 0.18
			var c := _mul(base, k)
			c.a = 1.0
			img.set_pixel(x, y, c)


func _leather(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_leather_fill(img, Color(0.17, 0.105, 0.06), Rect2i(0, 0, w, h))
	# edge burn: darker toward the rim
	for y in h:
		for x in w:
			var e := _edge(x, y, w, h)
			if e < 12:
				var o := img.get_pixel(x, y)
				img.set_pixel(x, y, _mul(o, 0.55 + 0.45 * float(e) / 12.0))
	# rim: dark outline, bronze line, dark gap
	var bronze := Color(0.62, 0.45, 0.2)
	for y in h:
		for x in w:
			var e := _edge(x, y, w, h)
			if e == 0:
				img.set_pixel(x, y, Color(0.04, 0.025, 0.015))
			elif e == 1:
				img.set_pixel(x, y, _mul(bronze, 1.0 if (x + y) % 7 != 0 else 0.7))
			elif e == 2:
				img.set_pixel(x, y, Color(0.07, 0.04, 0.02))
			elif e == 3:
				img.set_pixel(x, y, _mul(bronze, 0.55))
	# stitching: dashed thread on an inset line
	var inset := 9
	for y in range(inset, h - inset):
		for x in range(inset, w - inset):
			var e := _edge(x, y, w, h)
			if e == inset:
				var along := x if (y == inset or y == h - 1 - inset) else y
				if along % 6 < 3:
					img.set_pixel(x, y, Color(0.62, 0.5, 0.32))
				else:
					img.set_pixel(x, y, Color(0.1, 0.06, 0.03))
	# corner fittings: bronze plates and rivets
	for corner in 4:
		var sx := 1 if corner % 2 == 0 else -1
		var sy := 1 if corner < 2 else -1
		var ox := 0 if sx == 1 else w - 1
		var oy := 0 if sy == 1 else h - 1
		for i in range(0, 24):
			for j in range(0, 24 - i):
				if i < 3 and j < 3:
					continue
				var px := ox + sx * i
				var py := oy + sy * j
				var edge_d := 24 - i - j
				var c := _mul(bronze, 0.5 + 0.5 * clampf(float(edge_d) / 10.0, 0, 1))
				if edge_d <= 1:
					c = Color(0.05, 0.03, 0.02)
				elif edge_d == 2:
					c = _mul(bronze, 1.25)
				c.a = 1.0
				img.set_pixel(px, py, c)
		_rivet(img, ox + sx * 8, oy + sy * 8, 3, Color(0.78, 0.6, 0.3))
	return img


# --- parchment -----------------------------------------------------------------------------------------

func _parchment(w: int, h: int, ornate: bool) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var fibre := _noise(0.9, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var cloud := _noise(0.045, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 4)
	var stain := _noise(0.012, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var base := Color(0.79, 0.67, 0.45)
	var burn := 16 if ornate else 8
	for y in h:
		for x in w:
			var fb := fibre.get_noise_2d(x * 1.0, y * 0.3) * 0.5 + fibre.get_noise_2d(x * 0.3, y * 1.0) * 0.5
			var cl := cloud.get_noise_2d(x, y)
			var st := stain.get_noise_2d(x + 40, y + 90)
			var k := 1.0 + fb * 0.08 + cl * 0.05 - maxf(st - 0.3, 0.0) * 0.3
			var e := _edge(x, y, w, h)
			if e < burn:
				var t := float(e) / burn
				k *= 0.52 + 0.48 * t * t
			var c := _mul(base, k)
			c = Color(c.r, c.g * 0.995, c.b * 0.96, 1.0)
			img.set_pixel(x, y, c)
	# ragged edge for the slip: knock out alpha with noise
	if not ornate:
		var rag := _noise(0.5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
		for y in h:
			for x in w:
				var e := _edge(x, y, w, h)
				if e < 3 and rag.get_noise_2d(x, y) * 1.5 + float(e) * 0.5 < 0.2:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	var ink := Color(0.22, 0.13, 0.07)
	var inkd := Color(0.22, 0.13, 0.07, 0.9)
	var lines := [5, 8] if ornate else [4]
	for li in lines.size():
		var d: int = lines[li]
		for y in range(d, h - d):
			for x in range(d, w - d):
				if _edge(x, y, w, h) == d:
					_blend(img, x, y, inkd if li == 0 else Color(ink, 0.55))
	if ornate:
		# corner flourishes: a small ink curl and dot in each corner
		for corner in 4:
			var sx := 1 if corner % 2 == 0 else -1
			var sy := 1 if corner < 2 else -1
			var ox := 5 if sx == 1 else w - 6
			var oy := 5 if sy == 1 else h - 6
			for i in range(0, 18):
				_blend(img, ox + sx * i, oy + sy * 3, Color(ink, 0.9))
				_blend(img, ox + sx * 3, oy + sy * i, Color(ink, 0.9))
			for a in range(0, 16):
				var ang := a / 16.0 * PI * 0.5
				_blend(img, ox + sx * int(3 + 10 * (1.0 - cos(ang))), oy + sy * int(3 + 10 * (1.0 - sin(ang))), Color(ink, 0.8))
			_rivet(img, ox + sx * 3, oy + sy * 3, 2, Color(0.45, 0.14, 0.1))
	return img


# --- carved wood plaque --------------------------------------------------------------------------------

func _plaque(w: int, h: int, state: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var grain := _noise(0.02, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var ring := _noise(0.08, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var base := Color(0.3, 0.19, 0.1)
	if state == 1:
		base = Color(0.4, 0.25, 0.12)
	elif state == 2:
		base = Color(0.2, 0.125, 0.07)
	elif state == 3:
		base = Color(0.17, 0.13, 0.1)
	for y in h:
		for x in w:
			var g := grain.get_noise_2d(x * 0.15, y * 3.0)
			var r := ring.get_noise_2d(x * 0.2, y * 1.6)
			var k := 0.85 + g * 0.2 + r * 0.12
			if sin((y + r * 5.0) * 1.3) > 0.8:
				k *= 0.84
			var c := _mul(base, k)
			c.a = 1.0
			var e := _edge(x, y, w, h)
			# chamfer: lit top/left, shaded bottom/right
			if e < 3:
				var lit := (y < h / 2 and y == e) or (x < w / 2 and x == e)
				var shade := (y >= h / 2 and h - 1 - y == e) or (x >= w / 2 and w - 1 - x == e)
				if state == 2:
					lit = not lit and shade
					shade = false
				if lit:
					c = _mul(c, 1.35)
				elif shade:
					c = _mul(c, 0.55)
			if e == 0:
				c = Color(0.04, 0.025, 0.015)
			img.set_pixel(x, y, c)
	# carved groove inset 6 px; gilt when hovered or focused
	var groove := Color(0.05, 0.03, 0.015)
	var gilt := Color(0.86, 0.68, 0.3)
	for y in range(6, h - 6):
		for x in range(6, w - 6):
			var e := _edge(x, y, w, h)
			if e == 6:
				img.set_pixel(x, y, gilt if state == 1 else (_mul(groove, 1.0) if state != 4 else gilt))
			elif e == 7 and state != 1 and state != 4:
				img.set_pixel(x, y, _mul(img.get_pixel(x, y), 1.25))
			elif e == 7:
				img.set_pixel(x, y, _mul(gilt, 0.45))
	if state == 4:
		for y in h:
			for x in w:
				var e := _edge(x, y, w, h)
				if e == 1 or e == 2:
					img.set_pixel(x, y, gilt if e == 1 else _mul(gilt, 0.65))
	# nails
	var nail := Color(0.45, 0.42, 0.4) if state != 1 else Color(0.7, 0.55, 0.25)
	for p in [Vector2i(4, 4), Vector2i(w - 5, 4), Vector2i(4, h - 5), Vector2i(w - 5, h - 5)]:
		_rivet(img, p.x, p.y, 1, nail)
	return img


# --- leather tab ---------------------------------------------------------------------------------------

func _tab(w: int, h: int, on: bool) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base := Color(0.2, 0.12, 0.065) if on else Color(0.1, 0.062, 0.04)
	_leather_fill(img, base, Rect2i(0, 0, w, h))
	var gilt := Color(0.86, 0.68, 0.3)
	for y in h:
		for x in w:
			var corner := 9
			var cut := false
			if y < corner and x < corner:
				cut = Vector2(x, y).distance_to(Vector2(corner, corner)) > corner
			elif y < corner and x >= w - corner:
				cut = Vector2(x, y).distance_to(Vector2(w - 1 - corner, corner)) > corner
			if cut:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var e := mini(mini(x, w - 1 - x), y)
			if e == 0:
				img.set_pixel(x, y, Color(0.03, 0.02, 0.012))
			elif e == 1:
				img.set_pixel(x, y, _mul(gilt, 0.95) if on else Color(0.38, 0.28, 0.15))
			elif e == 4 and y >= 4 and (x + y) % 5 < 3:
				img.set_pixel(x, y, Color(0.66, 0.54, 0.34) if on else Color(0.3, 0.22, 0.14))
	return img


# --- slot ----------------------------------------------------------------------------------------------

func _slot(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_leather_fill(img, Color(0.07, 0.045, 0.03), Rect2i(0, 0, s, s))
	for y in s:
		for x in s:
			var e := _edge(x, y, s, s)
			if e < 5:
				# metal rim: a bevelled light ring, tinted by the caller
				var lit := (y == e or x == e) and e < 4
				var c := Color(0.82, 0.8, 0.76) if e in [1, 2] else Color(0.55, 0.53, 0.5)
				if e == 0:
					c = Color(0.1, 0.09, 0.08)
				elif e == 4:
					c = Color(0.05, 0.035, 0.025)
				elif y >= s / 2 and (s - 1 - y == e) or x >= s / 2 and (s - 1 - x == e):
					c = _mul(c, 0.6)
				elif lit:
					c = _mul(c, 1.12)
				img.set_pixel(x, y, c)
			elif e < 9:
				var o := img.get_pixel(x, y)
				img.set_pixel(x, y, _mul(o, 0.55 + 0.45 * float(e - 4) / 5.0))
	return img


func _inset(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_leather_fill(img, Color(0.055, 0.035, 0.024), Rect2i(0, 0, s, s))
	for y in s:
		for x in s:
			var e := _edge(x, y, s, s)
			if e == 0:
				img.set_pixel(x, y, Color(0.02, 0.012, 0.008))
			elif e == 1:
				img.set_pixel(x, y, Color(0.4, 0.3, 0.17) if (y > s / 2 or x > s / 2) else Color(0.1, 0.06, 0.03))
			elif e < 7:
				img.set_pixel(x, y, _mul(img.get_pixel(x, y), 0.6 + 0.4 * float(e) / 7.0))
	return img


# --- forged iron ---------------------------------------------------------------------------------------

func _iron_bar(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var hammer := _noise(0.2, FastNoiseLite.TYPE_CELLULAR, 1)
	var rust := _noise(0.09, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var fine := _noise(0.6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1)
	for y in h:
		for x in w:
			var hm := hammer.get_noise_2d(x, y) * 0.5 + 0.5
			var r := rust.get_noise_2d(x, y)
			var k := 0.5 + hm * 0.12 + fine.get_noise_2d(x, y) * 0.06
			var c := Color(0.2, 0.2, 0.22) * k * 1.6
			if r > 0.3:
				c = c.lerp(Color(0.38, 0.17, 0.07), clampf((r - 0.3) * 1.8, 0, 0.7))
			c.a = 1.0
			var e := _edge(x, y, w, h)
			if e == 0:
				c = Color(0.02, 0.02, 0.025)
			elif e == 1 or e == 2:
				var top := y <= x and y <= w - 1 - x and y < h / 2
				var left := x < w / 2 and x < y and x < h - 1 - y
				if top or left:
					c = _mul(c, 1.7)
				else:
					c = _mul(c, 0.55)
			elif e == 3:
				c = _mul(c, 0.75)
			img.set_pixel(x, y, c)
	for p in [Vector2i(8, 8), Vector2i(w - 9, 8), Vector2i(8, h - 9), Vector2i(w - 9, h - 9)]:
		_rivet(img, p.x, p.y, 2, Color(0.5, 0.48, 0.46))
	return img


# --- banner --------------------------------------------------------------------------------------------

func _banner(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var weave := _noise(0.7, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1)
	var gold := Color(0.86, 0.68, 0.3)
	var tail := 18
	for y in h:
		for x in w:
			var swallow := false
			if x > w - 1 - tail:
				var d := x - (w - 1 - tail)
				var mid := h * 0.5
				swallow = absf(y - mid) < d * (mid / float(tail))
			if swallow:
				continue
			var k := 0.9 + weave.get_noise_2d(x, y * 0.5) * 0.12 + (1.0 if (x + y) % 2 == 0 else 0.0) * 0.03
			var c := Color(0.38, 0.07, 0.06) * k
			c.a = 1.0
			var e := mini(mini(y, h - 1 - y), x)
			if x > w - 1 - tail:
				var d := x - (w - 1 - tail)
				var mid := h * 0.5
				var edge_v := d * (mid / float(tail))
				if absf(absf(y - mid) - edge_v) < 1.6:
					c = gold
			if e == 0:
				c = Color(0.04, 0.02, 0.015)
			elif e == 2 or (y == 3 or y == h - 4) and x > 2:
				c = _mul(gold, 0.9)
			img.set_pixel(x, y, c)
	_rivet(img, 6, h / 2, 2, gold)
	return img
