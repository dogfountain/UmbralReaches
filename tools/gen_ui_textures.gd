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
	_save(_frame_panel(192), "leather_panel")
	_save(_parchment(96, 96, true), "parchment_panel")
	_save(_parchment(48, 48, false), "parchment_slip")
	for st in 5:
		_save(_frame_plaque(128, 40, st), "plaque_" + ["normal", "hover", "pressed", "disabled", "focus"][st])
	_save(_frame_tab(112, 40, false), "tab_off")
	_save(_frame_tab(112, 40, true), "tab_on")
	_save(_frame_slot(64), "slot")
	_save(_frame_iron(72, 40), "iron_frame")
	_save(_frame_banner(256, 44), "banner")
	_save(_frame_inset(64), "inset")
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


# --- forged frames (Luke, 9 Nov: "upgrade and polish all ui elements", PoE2 and Enshrouded as inspiration) -----
# Dark forged frames: a near-black warm fill lit softly from the top (so text reads like Enshrouded's), a
# bevelled bronze band with a gilt edge, a hairline inside it, and corner brackets with a faceted stud (PoE2's
# ornament, our own shapes). Shapes are signed distances with one pixel of coverage, so curves stay smooth
# at 1:1 (the UI canvas is 1920x1080). The parchment and its slip are unchanged.

const K_BLACK := Color(0.012, 0.009, 0.007)
const K_FILL_TOP := Color(0.085, 0.066, 0.05)
const K_FILL_BOT := Color(0.042, 0.033, 0.026)
const K_BRONZE_DK := Color(0.22, 0.15, 0.07)
const K_BRONZE := Color(0.55, 0.4, 0.18)
const K_GILT := Color(0.93, 0.76, 0.4)
const K_GILT_HI := Color(1.0, 0.92, 0.66)
const SHADOW := 4                         ## px of soft drop shadow outside a panel's frame


static func _cov(d: float) -> float:
	return clampf(0.5 - d, 0.0, 1.0)


static func _sd_diamond(p: Vector2, c: Vector2, r: float) -> float:
	return (absf(p.x - c.x) + absf(p.y - c.y) - r) * 0.7071


static func _sd_seg(p: Vector2, a: Vector2, b: Vector2, w: float) -> float:
	var pa := p - a
	var ba := b - a
	var t := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * t).length() - w * 0.5


## A ring segment of radius r between angles a0..a1 (radians, y down), w wide.
static func _sd_arc(p: Vector2, c: Vector2, r: float, w: float, a0: float, a1: float) -> float:
	var v := p - c
	var ang := atan2(v.y, v.x)
	if ang >= a0 and ang <= a1:
		return absf(v.length() - r) - w * 0.5
	var e0 := c + Vector2(cos(a0), sin(a0)) * r
	var e1 := c + Vector2(cos(a1), sin(a1)) * r
	return minf(p.distance_to(e0), p.distance_to(e1)) - w * 0.5


## Which way an edge pixel faces: true for the top and left (lit from the upper left).
static func _lit_side(x: int, y: int, w: int, h: int) -> bool:
	var m := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
	return (m == y or m == x) and not (m == h - 1 - y and y > h / 2) and not (m == w - 1 - x and x > w / 2)


## A bevelled metal band on the rows at edge distance o .. o+bw+1: black, bw rows of metal, black.
func _band(img: Image, w: int, h: int, o: int, bw: int, lit_a: Color, lit_b: Color, dark_a: Color, dark_b: Color, chamfer := 0) -> void:
	var grain := _noise(0.45, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1)
	for y in h:
		for x in w:
			var e := _cham_edge(x, y, w, h, chamfer)
			if e < o or e > o + bw + 1:
				continue
			if e == o or e == o + bw + 1:
				_blend(img, x, y, Color(K_BLACK, 0.95))
				continue
			var k := float(e - o - 1) / maxf(1.0, float(bw - 1))
			var c := lit_a.lerp(lit_b, k) if _lit_side(x, y, w, h) else dark_a.lerp(dark_b, k)
			c = _mul(c, 1.0 + grain.get_noise_2d(x, y) * 0.09)
			c.a = 1.0
			img.set_pixel(x, y, c)


## Edge distance of a box whose corners are cut at 45 degrees by `c` px (0: square).
static func _cham_edge(x: int, y: int, w: int, h: int, c: int) -> int:
	var e := _edge(x, y, w, h)
	if c <= 0:
		return e
	var dx := mini(x, w - 1 - x)
	var dy := mini(y, h - 1 - y)
	return mini(e, int(floor(float(dx + dy - c) * 0.7071)))


## One SDF shape drawn in all four corners, mirrored (the shape in top-left coordinates).
func _corners(img: Image, w: int, h: int, sdf: Callable, col: Color, grow := 0.0, off := Vector2.ZERO, reach := 64) -> void:
	for corner in 4:
		var mx := corner % 2 == 1
		var my := corner >= 2
		for ly in reach:
			for lx in reach:
				var a := _cov(float(sdf.call(Vector2(lx, ly) - off)) - grow)
				if a <= 0.0:
					continue
				_blend(img, w - 1 - lx if mx else lx, h - 1 - ly if my else ly, Color(col, col.a * a))


## A faceted diamond stud at c (image coordinates), lit from the upper left; outlined in black.
func _stud(img: Image, c: Vector2, r: float) -> void:
	var rr := int(ceil(r + 2.0))
	for y in range(int(c.y) - rr, int(c.y) + rr + 1):
		for x in range(int(c.x) - rr, int(c.x) + rr + 1):
			var p := Vector2(x, y)
			var ao := _cov(_sd_diamond(p, c, r + 1.4))
			if ao <= 0.0:
				continue
			_blend(img, x, y, Color(K_BLACK, ao))
			var a := _cov(_sd_diamond(p, c, r))
			if a <= 0.0:
				continue
			var v := p - c
			var col := K_GILT_HI if (v.x <= 0.0 and v.y <= 0.0) else (K_GILT if v.y <= 0.0 else (K_BRONZE if v.x <= 0.0 else K_BRONZE_DK))
			if absf(v.x) + absf(v.y) < r * 0.3:
				col = K_GILT_HI
			_blend(img, x, y, Color(col, a))


func _frame_panel(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var grain := _noise(0.35, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var mott := _noise(0.03, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	for y in s:
		for x in s:
			var e := _edge(x, y, s, s)
			if e < SHADOW:
				img.set_pixel(x, y, Color(0, 0, 0, 0.1 + 0.12 * float(e)))
				continue
			var c := K_FILL_TOP.lerp(K_FILL_BOT, float(y) / float(s - 1))
			c = _mul(c, 1.0 + grain.get_noise_2d(x, y) * 0.05 + mott.get_noise_2d(x, y) * 0.08)
			var ie := float(e - SHADOW)
			if ie < 24.0:
				c = _mul(c, 0.58 + 0.42 * smoothstep(0.0, 24.0, ie))      # the band's shadow on the fill
			c.a = 1.0
			img.set_pixel(x, y, c)
	_band(img, s, s, SHADOW, 5, K_GILT, _mul(K_BRONZE, 0.75), _mul(K_BRONZE, 0.8), _mul(K_BRONZE_DK, 0.7))
	for y in s:
		for x in s:
			if _edge(x, y, s, s) == SHADOW + 10:
				_blend(img, x, y, Color(K_GILT, 0.22))                      # the hairline inside the band
	# corner brackets: an L of gilt along both edges ending in small diamonds, a curl inside the L, a stud
	var a := 16.0
	var arm := 40.0
	var bracket := func(p: Vector2) -> float:
		return minf(minf(_sd_seg(p, Vector2(a, a), Vector2(a + arm, a), 2.4), _sd_seg(p, Vector2(a, a), Vector2(a, a + arm), 2.4)),
			minf(_sd_diamond(p, Vector2(a + arm + 3.0, a), 3.6), _sd_diamond(p, Vector2(a, a + arm + 3.0), 3.6)))
	var curl := func(p: Vector2) -> float:
		return minf(_sd_arc(p, Vector2(a, a), 11.0, 1.8, 0.0, PI * 0.5), _sd_diamond(p, Vector2(a + 7.8, a + 7.8), 2.2))
	_corners(img, s, s, bracket, Color(0, 0, 0, 0.85), 1.2, Vector2(1, 1))   # its drop shadow
	_corners(img, s, s, bracket, Color(K_BLACK, 1.0), 1.0)
	_corners(img, s, s, bracket, _mul(K_GILT, 0.86))
	_corners(img, s, s, curl, Color(K_BLACK, 1.0), 0.9)
	_corners(img, s, s, curl, _mul(K_GILT, 0.72))
	var so := float(SHADOW) + 3.0
	for c in [Vector2(so, so), Vector2(s - 1 - so, so), Vector2(so, s - 1 - so), Vector2(s - 1 - so, s - 1 - so)]:
		_stud(img, c, 7.5)
	return img


func _frame_inset(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var grain := _noise(0.4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	for y in s:
		for x in s:
			var e := _edge(x, y, s, s)
			var c := _mul(Color(0.03, 0.024, 0.019), 1.0 + grain.get_noise_2d(x, y) * 0.06)
			if e < 9:
				var top_left := mini(x, y) == e
				c = _mul(c, 0.55 + 0.45 * float(e) / 9.0 if top_left else 0.8 + 0.2 * float(e) / 9.0)
			if e == 0:
				c = Color(0.006, 0.004, 0.003)
			elif e == 1:
				c = _mul(K_BRONZE, 0.55) if not _lit_side(x, y, s, s) else Color(0.02, 0.015, 0.01)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


## An item or ability socket. The rim is neutral steel so a rarity tint (modulate) reads true.
func _frame_slot(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var grain := _noise(0.5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1)
	var mid := Vector2(s - 1, s - 1) * 0.5
	for y in s:
		for x in s:
			var e := _edge(x, y, s, s)
			var r := Vector2(x, y).distance_to(mid) / (s * 0.5)
			var c := Color(0.075, 0.062, 0.05).lerp(Color(0.022, 0.018, 0.014), smoothstep(0.2, 1.05, r))
			c = _mul(c, 1.0 + grain.get_noise_2d(x, y) * 0.07)
			if e < 10:
				c = _mul(c, 0.6 + 0.4 * float(e) / 10.0)
			c.a = 1.0
			img.set_pixel(x, y, c)
	_band(img, s, s, 0, 3, Color(0.66, 0.64, 0.6), Color(0.42, 0.4, 0.38), Color(0.34, 0.32, 0.3), Color(0.2, 0.19, 0.18))
	for y in s:
		for x in s:
			if _edge(x, y, s, s) == 6:
				_blend(img, x, y, Color(0.8, 0.78, 0.74, 0.16))
	var notch := func(p: Vector2) -> float: return _sd_diamond(p, Vector2(2.5, 2.5), 2.6)
	_corners(img, s, s, notch, Color(K_BLACK, 1.0), 1.0, Vector2.ZERO, 12)
	_corners(img, s, s, notch, Color(0.72, 0.7, 0.66), 0.0, Vector2.ZERO, 12)
	return img


## Buttons: a chamfered forged plate. state 0 normal, 1 hover, 2 pressed, 3 disabled, 4 focus.
func _frame_plaque(w: int, h: int, state: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var grain := _noise(0.3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var tops := [Color(0.16, 0.12, 0.08), Color(0.27, 0.19, 0.11), Color(0.06, 0.045, 0.034), Color(0.09, 0.085, 0.08), Color(0.27, 0.19, 0.11)]
	var bots := [Color(0.075, 0.056, 0.04), Color(0.12, 0.085, 0.05), Color(0.11, 0.08, 0.056), Color(0.06, 0.057, 0.054), Color(0.12, 0.085, 0.05)]
	var ch := 6
	for y in h:
		for x in w:
			var e := _cham_edge(x, y, w, h, ch)
			if e < 0:
				continue
			if e < 2:
				var glow := state == 4
				img.set_pixel(x, y, Color(K_GILT, 0.35 + 0.25 * e) if glow else Color(0, 0, 0, 0.18 + 0.2 * e))
				continue
			var c: Color = (tops[state] as Color).lerp(bots[state], float(y) / float(h - 1))
			c = _mul(c, 1.0 + grain.get_noise_2d(x * 0.5, y * 2.0) * 0.07)
			c.a = 1.0
			img.set_pixel(x, y, c)
			if y == 6 and e >= 6:
				_blend(img, x, y, Color(K_GILT, [0.16, 0.34, 0.0, 0.05, 0.34][state]))
	var rim: Array = [[K_BRONZE, _mul(K_BRONZE, 0.7), K_BRONZE_DK, _mul(K_BRONZE_DK, 0.8)],
		[K_GILT_HI, K_GILT, K_BRONZE, K_BRONZE_DK],
		[K_BRONZE_DK, _mul(K_BRONZE_DK, 0.8), K_BRONZE, _mul(K_BRONZE, 0.8)],
		[Color(0.32, 0.3, 0.28), Color(0.24, 0.23, 0.22), Color(0.18, 0.17, 0.16), Color(0.14, 0.13, 0.12)],
		[K_GILT_HI, K_GILT, K_GILT, K_BRONZE]][state]
	_band(img, w, h, 2, 2, rim[0], rim[1], rim[2], rim[3], ch)
	return img


## A page tab: chamfered top corners, open at the bottom (it sits on the panel below).
func _frame_tab(w: int, h: int, on: bool) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var grain := _noise(0.3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var ch := 7
	for y in h:
		for x in w:
			var dx := mini(x, w - 1 - x)
			var e := mini(mini(dx, y), int(floor(float(dx + y - ch) * 0.7071)))
			if e < 0:
				continue
			var top := Color(0.24, 0.165, 0.095) if on else Color(0.085, 0.066, 0.05)
			var bot := Color(0.12, 0.08, 0.048) if on else Color(0.05, 0.04, 0.03)
			var c := top.lerp(bot, float(y) / float(h - 1))
			c = _mul(c, 1.0 + grain.get_noise_2d(x, y) * 0.07)
			if on and y > h - 10:
				c = c.lerp(Color(0.42, 0.27, 0.12), 0.35 * float(y - (h - 10)) / 10.0)   # the lit page below glows up
			if e == 0:
				c = K_BLACK
			elif e <= 2:
				var lit := dx > y or x < w / 2
				c = (K_GILT if lit else K_BRONZE) if on else (K_BRONZE if lit else K_BRONZE_DK)
				if e == 2:
					c = _mul(c, 0.7)
			elif e == 3:
				c = Color(K_BLACK, 1.0)
			elif on and y == 5:
				c = c.lerp(K_GILT, 0.4)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


## A name plate: oxblood cloth between gilt lines, a stud at the left, a swallowtail at the right.
func _frame_banner(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var weave := _noise(0.7, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1)
	var tail := 18
	var mid := float(h - 1) * 0.5
	for y in h:
		for x in w:
			var cut := 0.0
			if x > w - 1 - tail:
				cut = float(x - (w - 1 - tail)) * (mid / float(tail))
				if absf(y - mid) < cut - 0.5:
					continue
			var c := Color(0.4, 0.08, 0.055).lerp(Color(0.2, 0.035, 0.025), float(y) / float(h - 1))
			c = _mul(c, 0.92 + weave.get_noise_2d(x, y * 0.5) * 0.12)
			var e := mini(mini(y, h - 1 - y), x)
			if e == 0 or (cut > 0.0 and absf(absf(y - mid) - cut) < 0.9):
				c = K_BLACK
			elif e <= 2 or (cut > 0.0 and absf(absf(y - mid) - cut) < 2.4):
				c = K_GILT if y < mid else K_BRONZE
			elif e == 3:
				c = K_BLACK
			elif y == 6 or y == h - 7:
				c = c.lerp(K_GILT, 0.35)
			c.a = 1.0
			img.set_pixel(x, y, c)
	_stud(img, Vector2(9, mid), 5.0)
	return img


## A plain forged frame (the iron rod round a meter or a small readout).
func _frame_iron(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var grain := _noise(0.4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	for y in h:
		for x in w:
			var c := _mul(K_FILL_TOP.lerp(K_FILL_BOT, float(y) / float(h - 1)), 1.0 + grain.get_noise_2d(x, y) * 0.06)
			c.a = 1.0
			img.set_pixel(x, y, c)
	_band(img, w, h, 0, 3, K_GILT, K_BRONZE, K_BRONZE, K_BRONZE_DK, 4)
	return img
