extends RefCounted
## RealmLore's generated assets (no class_name: preload by path):
##  - textures: the carved-inscription atlas (8 panels: lettered tablets, the Rooted's runes and
##    cup-and-ring spirals, the Kindlers' flame roundel, the Abbot's sigil with its tally marks, the
##    open door, a milestone) as albedo + normal + groove mask (the ember in the cuts); thatch
##    straw. Drawn with Image + FastNoiseLite once, then cached (GenCache, PNG bytes).
##  - materials: a weathered stone shader (world triplanar, moss on what faces the sky and creeps
##    up from the ground, rain streaks and lichen on the sides) used for every lore stone; thatch;
##    carved panels (ember / cold).
##  - meshes, built in a landmark's local frame and cached by their parameters: layered thatch
##    roofs (courses with rolled drip edges, a scalloped ridge with liggers), individual slates.
## Everything here is deterministic for its key, so GenCache serves it warm.

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/world/realm/lore/lore_assets.gd"
const T := "res://art/textures/"

## Carve atlas: 4 x 2 cells of CELL px.
const CELL := 256
const COLS := 4
const ROWS := 2
const C_TEXT := 0
const C_TEXT2 := 1
const C_RUNES := 2
const C_SPIRAL := 3
const C_FLAME := 4
const C_SIGIL := 5
const C_DOOR := 6
const C_MILE := 7

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _noise_tex: NoiseTexture2D


## Drop the engine resources held in static vars (called when the night is torn down): statics
## outlive the renderer at quit ("RID allocations leaked at exit"). Rebuilt on next use.
static func release() -> void:
	_tex.clear()
	_mats.clear()
	_meshes.clear()
	_noise_tex = null


# =============================================================================================
# textures
# =============================================================================================

## {albedo, normal, emit} for the carve atlas.
static func carve_textures() -> Dictionary:
	if _tex.has("carve"):
		return _tex["carve"]
	var imgs := _cached_images("lore_carve_atlas_v3", ["a", "n", "e"], _gen_carve)
	var out := {"albedo": _texture(imgs.a), "normal": _texture(imgs.n), "emit": _texture(imgs.e)}
	_tex["carve"] = out
	return out


static func thatch_textures() -> Dictionary:
	if _tex.has("thatch"):
		return _tex["thatch"]
	var imgs := _cached_images("lore_thatch_v2", ["a", "n"], _gen_thatch)
	var out := {"albedo": _texture(imgs.a), "normal": _texture(imgs.n)}
	_tex["thatch"] = out
	return out


## UV rect (0..1) of atlas cell `c`, inset a texel so mips don't bleed between cells.
static func cell_uv(c: int) -> Rect2:
	var w := 1.0 / float(COLS)
	var h := 1.0 / float(ROWS)
	var px := 2.0 / float(CELL * COLS)
	return Rect2(float(c % COLS) * w + px, float(c / COLS) * h + px, w - px * 2.0, h - px * 2.0)


static func _texture(img: Image) -> ImageTexture:
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Images by name from GenCache (PNG bytes), or made by `gen` (returns {name: Image}) and saved.
static func _cached_images(key: String, names: Array, gen: Callable) -> Dictionary:
	var hit: Variant = GenCache.load_var(key, SELF)
	if hit is Dictionary:
		var out := {}
		var ok := true
		for n: String in names:
			var img := Image.new()
			if not (hit as Dictionary).has(n) or img.load_png_from_buffer((hit as Dictionary)[n]) != OK:
				ok = false
				break
			out[n] = img
		if ok:
			return out
	var t := Time.get_ticks_msec()
	var made: Dictionary = gen.call()
	var bytes := {}
	for n: String in names:
		bytes[n] = (made[n] as Image).save_png_to_buffer()
	GenCache.save_var(key, SELF, bytes)
	print("REALM_LORE generated %s in %d ms" % [key, Time.get_ticks_msec() - t])
	return made


# --- the carve atlas --------------------------------------------------------------------------

## Pseudo-capitals for the Order's inscriptions (strokes in a unit box, y down).
const GLYPHS := [
	[[0.5, 0, 0.5, 1]],
	[[0.2, 0, 0.2, 1, 0.8, 1]],
	[[0.1, 0, 0.9, 0], [0.5, 0, 0.5, 1]],
	[[0.8, 0, 0.2, 0, 0.2, 1, 0.8, 1], [0.2, 0.5, 0.65, 0.5]],
	[[0.8, 0, 0.2, 0, 0.2, 1], [0.2, 0.5, 0.6, 0.5]],
	[[0.2, 0, 0.2, 1], [0.8, 0, 0.8, 1], [0.2, 0.5, 0.8, 0.5]],
	[[0.1, 1, 0.5, 0, 0.9, 1], [0.28, 0.62, 0.72, 0.62]],
	[[0.1, 0, 0.5, 1, 0.9, 0]],
	[[0.2, 1, 0.2, 0, 0.8, 1, 0.8, 0]],
	[[0.08, 1, 0.12, 0, 0.5, 0.65, 0.88, 0, 0.92, 1]],
	[[0.15, 0, 0.85, 1], [0.85, 0, 0.15, 1]],
	[[0.2, 0, 0.2, 1], [0.8, 0, 0.2, 0.55, 0.8, 1]],
	[[0.5, 0, 0.82, 0.18, 0.88, 0.5, 0.82, 0.82, 0.5, 1, 0.18, 0.82, 0.12, 0.5, 0.18, 0.18, 0.5, 0]],
	[[0.85, 0.15, 0.55, 0, 0.25, 0.12, 0.12, 0.5, 0.25, 0.88, 0.55, 1, 0.85, 0.85]],
	[[0.2, 0, 0.2, 1, 0.6, 1, 0.85, 0.7, 0.85, 0.3, 0.6, 0, 0.2, 0]],
	[[0.2, 1, 0.2, 0, 0.7, 0, 0.82, 0.25, 0.7, 0.5, 0.2, 0.5], [0.45, 0.5, 0.85, 1]],
	[[0.8, 0.12, 0.6, 0, 0.3, 0, 0.15, 0.2, 0.3, 0.45, 0.7, 0.55, 0.85, 0.8, 0.7, 1, 0.35, 1, 0.15, 0.88]],
	[[0.2, 1, 0.2, 0, 0.7, 0, 0.82, 0.25, 0.7, 0.5, 0.2, 0.5]],
	[[0.1, 0, 0.5, 0.5, 0.9, 0], [0.5, 0.5, 0.5, 1]],
]
## The Rooted's runes: staves and branches.
const RUNES := [
	[[0.3, 0, 0.3, 1], [0.3, 0.15, 0.75, 0], [0.3, 0.42, 0.75, 0.27]],
	[[0.25, 1, 0.25, 0, 0.75, 0.35, 0.75, 1]],
	[[0.3, 0, 0.3, 1], [0.3, 0.25, 0.72, 0.5, 0.3, 0.75]],
	[[0.3, 0, 0.3, 1], [0.3, 0.05, 0.75, 0.3], [0.3, 0.35, 0.75, 0.6]],
	[[0.3, 1, 0.3, 0, 0.72, 0.25, 0.3, 0.5, 0.72, 1]],
	[[0.72, 0, 0.3, 0.5, 0.72, 1]],
	[[0.15, 0, 0.85, 1], [0.85, 0, 0.15, 1]],
	[[0.25, 0, 0.25, 1], [0.75, 0, 0.75, 1], [0.25, 0.3, 0.75, 0.6]],
	[[0.5, 0, 0.5, 1], [0.3, 0.35, 0.7, 0.62]],
	[[0.5, 0, 0.5, 1], [0.2, 0.3, 0.5, 0, 0.8, 0.3]],
	[[0.3, 0, 0.3, 1], [0.3, 0, 0.72, 0.25, 0.3, 0.5, 0.72, 0.75, 0.3, 1]],
	[[0.2, 0, 0.2, 1], [0.8, 0, 0.8, 1], [0.2, 0, 0.8, 0.5], [0.8, 0, 0.2, 0.5]],
	[[0.5, 0, 0.15, 0.4, 0.5, 0.8, 0.85, 0.4, 0.5, 0], [0.15, 1, 0.5, 0.8, 0.85, 1]],
]


static func _gen_carve() -> Dictionary:
	var W := CELL * COLS
	var H := CELL * ROWS
	var hgt := PackedFloat32Array()
	hgt.resize(W * H)
	var cut := PackedFloat32Array()             # groove depth only (letters), for the ember mask
	cut.resize(W * H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var cv := {"h": hgt, "c": cut, "w": W}
	for c in COLS * ROWS:
		var o := Vector2(float(c % COLS) * CELL, float(c / COLS) * CELL)
		match c:
			C_TEXT:
				_field(cv, o, 14.0, 0.32, 7.0)
				_text_lines(cv, rng, o + Vector2(30, 36), 196.0, [30.0, 30.0, 30.0, 30.0], 2.6, GLYPHS)
			C_TEXT2:
				_field(cv, o, 14.0, 0.32, 7.0)
				_text_lines(cv, rng, o + Vector2(34, 40), 188.0, [44.0, 30.0, 30.0], 3.2, GLYPHS)
				_stroke(cv, o + Vector2(40, 102), o + Vector2(216, 102), 1.8, 0.7)
			C_RUNES:
				_stroke(cv, o + Vector2(40, 12), o + Vector2(40, 244), 3.0, 0.9)
				_stroke(cv, o + Vector2(216, 12), o + Vector2(216, 244), 3.0, 0.9)
				for col in 2:
					var y := 20.0
					while y < 220.0:
						var g: Array = RUNES[rng.randi() % RUNES.size()]
						_glyph(cv, g, o + Vector2(66.0 + 74.0 * float(col), y), Vector2(46, 40), 3.4, 1.0)
						y += 52.0
			C_SPIRAL:
				_spiral(cv, o + Vector2(86, 90), 58.0, 3.2, 3.0)
				_spiral(cv, o + Vector2(178, 170), 50.0, 2.6, 3.0)
				for r: float in [14.0, 28.0, 42.0]:
					_ring(cv, o + Vector2(80, 196), r, 3.0, 0.95)
				_cup(cv, o + Vector2(80, 196), 7.0)
				_cup(cv, o + Vector2(190, 62), 9.0)
				_ring(cv, o + Vector2(190, 62), 22.0, 3.0, 0.9)
				_stroke(cv, o + Vector2(140, 96), o + Vector2(172, 70), 2.6, 0.8)
				_stroke(cv, o + Vector2(118, 196), o + Vector2(140, 178), 2.6, 0.8)
			C_FLAME:
				_field(cv, o, 10.0, 0.25, 6.0, true)
				_ring(cv, o + Vector2(128, 128), 104.0, 3.0, 0.9)
				_ring(cv, o + Vector2(128, 128), 92.0, 2.0, 0.7)
				# the flame: an outer tongue, an inner one, the bowl of coals, three rays above
				_poly(cv, [Vector2(128, 44), Vector2(160, 92), Vector2(166, 128), Vector2(150, 158), Vector2(128, 166), Vector2(106, 158), Vector2(90, 128), Vector2(98, 96), Vector2(116, 112), Vector2(128, 44)], o, 3.4, 1.0)
				_poly(cv, [Vector2(128, 96), Vector2(142, 128), Vector2(128, 152), Vector2(114, 128), Vector2(128, 96)], o, 2.6, 0.9)
				_poly(cv, [Vector2(80, 170), Vector2(96, 192), Vector2(160, 192), Vector2(176, 170)], o, 3.2, 1.0)
				_stroke(cv, o + Vector2(80, 170), o + Vector2(176, 170), 2.4, 0.8)
				_stroke(cv, o + Vector2(128, 206), o + Vector2(128, 222), 2.6, 0.8)
			C_SIGIL:
				_field(cv, o, 12.0, 0.3, 6.0)
				_ring(cv, o + Vector2(128, 86), 46.0, 4.0, 1.0)
				_stroke(cv, o + Vector2(128, 28), o + Vector2(128, 146), 4.2, 1.0)
				# the tally: groups of four and a slash, row after row
				for row in 3:
					var x := 36.0
					var n := 4 + row
					for gi in n:
						if x > 212.0:
							break
						for s in 4:
							_stroke(cv, o + Vector2(x + 6.0 * float(s), 160.0 + 26.0 * float(row)), o + Vector2(x + 6.0 * float(s), 180.0 + 26.0 * float(row)), 1.6, 0.85)
						_stroke(cv, o + Vector2(x - 3.0, 178.0 + 26.0 * float(row)), o + Vector2(x + 23.0, 162.0 + 26.0 * float(row)), 1.6, 0.85)
						x += 36.0
			C_DOOR:
				_field(cv, o, 12.0, 0.3, 6.0)
				var arch: Array[Vector2] = []
				for i in 13:
					var a := PI * float(i) / 12.0
					arch.append(Vector2(128.0 - cos(a) * 58.0, 104.0 - sin(a) * 74.0 + (0.0 if i == 0 or i == 12 else 0.0)))
				var path: Array[Vector2] = [Vector2(70, 214)]
				path.append_array(arch)
				path.append(Vector2(186, 214))
				_poly(cv, path, o, 3.4, 1.0)
				# the door leaf swung open (seen edge-on as a slanted panel)
				_poly(cv, [Vector2(72, 210), Vector2(44, 196), Vector2(44, 70), Vector2(72, 96)], o, 2.8, 0.9)
				# small flames at its foot
				for fx: float in [104.0, 128.0, 152.0]:
					_poly(cv, [Vector2(fx, 186), Vector2(fx + 6, 200), Vector2(fx, 206), Vector2(fx - 6, 200), Vector2(fx, 186)], o, 2.0, 0.9)
				_text_lines(cv, rng, o + Vector2(40, 226), 176.0, [16.0], 1.6, GLYPHS)
			C_MILE:
				_field(cv, o, 12.0, 0.32, 6.0)
				# big numerals over two lines of small text
				var big: Array = [GLYPHS[10], GLYPHS[0], GLYPHS[0]]
				var bx := 52.0
				for g: Array in big:
					_glyph(cv, g, o + Vector2(bx, 30), Vector2(48, 78), 5.0, 1.0)
					bx += 54.0
				_stroke(cv, o + Vector2(36, 128), o + Vector2(220, 128), 2.0, 0.7)
				_text_lines(cv, rng, o + Vector2(36, 146), 184.0, [26.0, 26.0], 2.4, GLYPHS)
	# albedo, groove mask, height image
	var noise := FastNoiseLite.new()
	noise.seed = 51
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.018
	var nimg := noise.get_image(W, H, false, false, true)
	var nb := nimg.get_data()
	var nstride := nb.size() / (W * H)
	var pit := FastNoiseLite.new()
	pit.seed = 77
	pit.frequency = 0.21
	var pimg := pit.get_image(W, H, false, false, true)
	var pb := pimg.get_data()
	var pstride := pb.size() / (W * H)
	var alb := PackedByteArray()
	alb.resize(W * H * 3)
	var em := PackedByteArray()
	em.resize(W * H)
	for i in W * H:
		var nv := float(nb[i * nstride]) / 255.0
		var pv := float(pb[i * pstride]) / 255.0
		var h: float = hgt[i]
		var c: float = cut[i]
		var pitting := 0.0
		if pv > 0.78:
			pitting = (pv - 0.78) * 2.2
			hgt[i] = h - pitting * 0.25
		var base := 0.64 + nv * 0.26 - pitting * 0.35
		var shade := base * (1.0 - c * 0.55) * (1.0 + h * 0.18 if c <= 0.0 else 1.0)
		alb[i * 3] = clampi(int(shade * 255.0 * 1.02), 0, 255)
		alb[i * 3 + 1] = clampi(int(shade * 255.0 * 0.99), 0, 255)
		alb[i * 3 + 2] = clampi(int(shade * 255.0 * 0.95), 0, 255)
		em[i] = clampi(int(smoothstep(0.12, 0.7, c) * 255.0), 0, 255)
	var a := Image.create_from_data(W, H, false, Image.FORMAT_RGB8, alb)
	var e := Image.create_from_data(W, H, false, Image.FORMAT_L8, em)
	e.convert(Image.FORMAT_RGB8)
	var n := Image.create_from_data(W, H, false, Image.FORMAT_RF, hgt.to_byte_array())
	n.bump_map_to_normal_map(5.0)
	n.convert(Image.FORMAT_RGB8)
	return {"a": a, "n": n, "e": e}


## A sunk panel field in a cell: lowered by `depth` inside a margin, bevelled over `bev` px.
static func _field(cv: Dictionary, o: Vector2, margin: float, depth: float, bev: float, round_top := false) -> void:
	var hgt: PackedFloat32Array = cv.h
	var W: int = cv.w
	for y in CELL:
		for x in CELL:
			var px := float(x)
			var py := float(y)
			var d := minf(minf(px - margin, float(CELL) - margin - px), minf(py - margin, float(CELL) - margin - py))
			if round_top:
				d = float(CELL) * 0.5 - margin - Vector2(px, py).distance_to(Vector2(CELL * 0.5, CELL * 0.5))
			if d <= 0.0:
				continue
			var v := -depth * clampf(d / bev, 0.0, 1.0)
			var i := (int(o.y) + y) * W + int(o.x) + x
			hgt[i] = minf(hgt[i], v)


## A V-cut groove from a to b (px), half width r, depth `dep` (relative to the local surface).
static func _stroke(cv: Dictionary, a: Vector2, b: Vector2, r: float, dep: float) -> void:
	var hgt: PackedFloat32Array = cv.h
	var cut: PackedFloat32Array = cv.c
	var W: int = cv.w
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * (r + 1.0)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * (r + 1.0)
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.0001)
	for y in range(maxi(0, int(lo.y)), mini(int(hi.y) + 1, CELL * ROWS)):
		for x in range(maxi(0, int(lo.x)), mini(int(hi.x) + 1, W)):
			var p := Vector2(x, y)
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d >= r:
				continue
			var v := dep * (1.0 - d / r)
			var i := y * W + x
			if v > cut[i]:
				# cut below whatever field the stroke sits in
				hgt[i] = hgt[i] - (v - cut[i])
				cut[i] = v


static func _poly(cv: Dictionary, pts: Array, o: Vector2, r: float, dep: float) -> void:
	for i in pts.size() - 1:
		_stroke(cv, o + (pts[i] as Vector2), o + (pts[i + 1] as Vector2), r, dep)


static func _ring(cv: Dictionary, c: Vector2, rad: float, r: float, dep: float) -> void:
	var n := maxi(12, int(rad * 0.8))
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		_stroke(cv, c + Vector2(cos(a0), sin(a0)) * rad, c + Vector2(cos(a1), sin(a1)) * rad, r, dep)


static func _cup(cv: Dictionary, c: Vector2, rad: float) -> void:
	_stroke(cv, c, c + Vector2(0.01, 0), rad, 1.2)


static func _spiral(cv: Dictionary, c: Vector2, rad: float, turns: float, r: float) -> void:
	var n := int(turns * 28.0)
	var prev := c
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var a := t * turns * TAU
		var q := c + Vector2(cos(a), sin(a)) * rad * t
		_stroke(cv, prev, q, r, 0.95)
		prev = q


static func _glyph(cv: Dictionary, g: Array, at: Vector2, size: Vector2, r: float, dep: float) -> void:
	for s: Array in g:
		for i in range(0, s.size() - 2, 2):
			_stroke(cv, at + Vector2(float(s[i]), float(s[i + 1])) * size, at + Vector2(float(s[i + 2]), float(s[i + 3])) * size, r, dep)


## Lines of pseudo-text from `at`, `width` px wide, line heights `lines`, stroke half width r.
static func _text_lines(cv: Dictionary, rng: RandomNumberGenerator, at: Vector2, width: float, lines: Array, r: float, set: Array) -> void:
	var y := at.y
	for li in lines.size():
		var lh: float = lines[li]
		var gh := lh * 0.66
		var gw := gh * 0.62
		var x := at.x
		var limit := at.x + (width if li < lines.size() - 1 or lines.size() == 1 else width * rng.randf_range(0.45, 0.8))
		while x + gw <= limit:
			if rng.randf() < 0.16 and x > at.x + gw:
				x += gw * 0.7                   # a word break
				continue
			_glyph(cv, set[rng.randi() % set.size()], Vector2(x, y), Vector2(gw, gh), r, 1.0)
			x += gw * 1.28
		y += lh


# --- thatch -----------------------------------------------------------------------------------

static func _gen_thatch() -> Dictionary:
	var S := 512
	var streak := FastNoiseLite.new()
	streak.seed = 19
	streak.noise_type = FastNoiseLite.TYPE_SIMPLEX
	streak.frequency = 1.0
	var patch := FastNoiseLite.new()
	patch.seed = 23
	patch.frequency = 0.012
	patch.fractal_octaves = 3
	var hgt := PackedFloat32Array()
	hgt.resize(S * S)
	var alb := PackedByteArray()
	alb.resize(S * S * 3)
	for y in S:
		for x in S:
			# straw: thin stalks along v (y), each a random brightness; seamless by wrapping x on a circle
			var ax := float(x) / float(S) * TAU
			var s1 := streak.get_noise_3d(cos(ax) * 26.0, sin(ax) * 26.0, float(y) * 0.012)
			var s2 := streak.get_noise_3d(cos(ax) * 61.0 + 7.0, sin(ax) * 61.0, float(y) * 0.03 + 3.0)
			var av := float(y) / float(S) * TAU
			var pv := patch.get_noise_3d(cos(ax) * 8.0, sin(ax) * 8.0, sin(av) * 3.0 + cos(av) * 3.0)
			var h := 0.5 + s1 * 0.35 + s2 * 0.25
			hgt[y * S + x] = h
			var dark := clampf(0.55 + 0.45 * h, 0.3, 1.0)
			var age := clampf(0.5 + pv * 0.9, 0.0, 1.0)            # weathered grey-brown patches
			var col := Color(0.66, 0.56, 0.38).lerp(Color(0.42, 0.38, 0.32), age) * dark
			var i := (y * S + x) * 3
			alb[i] = clampi(int(col.r * 255.0), 0, 255)
			alb[i + 1] = clampi(int(col.g * 255.0), 0, 255)
			alb[i + 2] = clampi(int(col.b * 255.0), 0, 255)
	var a := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, alb)
	var n := Image.create_from_data(S, S, false, Image.FORMAT_RF, hgt.to_byte_array())
	n.bump_map_to_normal_map(3.0)
	n.convert(Image.FORMAT_RGB8)
	return {"a": a, "n": n}


# =============================================================================================
# materials
# =============================================================================================

static func noise_tex() -> NoiseTexture2D:
	if _noise_tex == null:
		var fn := FastNoiseLite.new()
		fn.seed = 404
		fn.frequency = 0.012
		fn.fractal_octaves = 4
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.width = 256
		_noise_tex.height = 256
		_noise_tex.seamless = true
		_noise_tex.generate_mipmaps = true
		_noise_tex.noise = fn
	return _noise_tex


## Weathered stone: `tex` is a base name under art/textures (albedo/normal/rough).
## moss: amount on sky-facing surfaces; foot: moss and damp creeping up from the ground (by the
## kit's contact-AO vertex shade); streak: rain streaks and lichen on the sides.
static func stone(tex: String, scale: float, tint: Color, moss := 0.35, foot := 0.3, streak := 0.6) -> ShaderMaterial:
	var key := "%s|%.2f|%s|%.2f|%.2f|%.2f" % [tex, scale, tint.to_html(), moss, foot, streak]
	if _mats.has(key):
		return _mats[key]
	if not _mats.has("_stone_shader"):
		var sh := Shader.new()
		sh.code = STONE_SHADER
		_mats["_stone_shader"] = sh
	var m := ShaderMaterial.new()
	m.shader = _mats["_stone_shader"]
	m.set_shader_parameter("albedo_tex", load(T + tex + "_albedo.png"))
	if ResourceLoader.exists(T + tex + "_normal.png"):
		m.set_shader_parameter("normal_tex", load(T + tex + "_normal.png"))
	if ResourceLoader.exists(T + tex + "_rough.png"):
		m.set_shader_parameter("rough_tex", load(T + tex + "_rough.png"))
	m.set_shader_parameter("noise_tex", noise_tex())
	m.set_shader_parameter("tex_scale", scale)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("moss_amount", moss)
	m.set_shader_parameter("foot_moss", foot)
	m.set_shader_parameter("streaks", streak)
	_mats[key] = m
	return m


static func thatch() -> StandardMaterial3D:
	if _mats.has("thatch"):
		return _mats["thatch"]
	var t := thatch_textures()
	var m := StandardMaterial3D.new()
	m.albedo_texture = t.albedo
	m.normal_enabled = true
	m.normal_texture = t.normal
	m.normal_scale = 1.4
	m.roughness = 0.96
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.05, 1.0, 0.95)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.rim_enabled = true
	m.rim = 0.12
	_mats["thatch"] = m
	return m


## The same carvings with no light in them: decoration on stones that say nothing to read.
static func carve_plain() -> StandardMaterial3D:
	if _mats.has("carve_plain"):
		return _mats["carve_plain"]
	var m := (carve(false) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.emission_enabled = false
	m.albedo_color = Color(0.8, 0.78, 0.76)
	_mats["carve_plain"] = m
	return m


## Carved panels: the stone of the atlas, grooves lit faintly from within (ember, or cold for the
## Rooted's work). A night cue that this can be read, well under the glow threshold.
static func carve(cold := false) -> StandardMaterial3D:
	var key := "carve_cold" if cold else "carve"
	if _mats.has(key):
		return _mats[key]
	var t := carve_textures()
	var m := StandardMaterial3D.new()
	m.albedo_texture = t.albedo
	m.albedo_color = Color(0.86, 0.84, 0.82) if not cold else Color(0.74, 0.78, 0.72)
	m.vertex_color_use_as_albedo = true
	m.normal_enabled = true
	m.normal_texture = t.normal
	m.normal_scale = 1.6
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission_texture = t.emit
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY     # ember only in the cuts
	m.emission = Color(1.0, 0.42, 0.14) if not cold else Color(0.35, 0.8, 1.0)
	m.emission_energy_multiplier = 0.4 if not cold else 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


const STONE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.4;
uniform vec4 tint : source_color = vec4(1.0);
uniform float moss_amount = 0.35;
uniform float foot_moss = 0.3;
uniform float streaks = 0.6;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 1e-4);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = tri_w(n);
	vec3 p = wpos * tex_scale;
	vec3 alb = texture(albedo_tex, p.zy).rgb * w.x + texture(albedo_tex, p.xz).rgb * w.y + texture(albedo_tex, p.xy).rgb * w.z;
	float rough = texture(rough_tex, p.zy).r * w.x + texture(rough_tex, p.xz).r * w.y + texture(rough_tex, p.xy).r * w.z;
	// whiteout-blended triplanar normal
	vec3 tx = texture(normal_tex, p.zy).xyz * 2.0 - 1.0;
	vec3 ty = texture(normal_tex, p.xz).xyz * 2.0 - 1.0;
	vec3 tz = texture(normal_tex, p.xy).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 nw = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
	// large blotches and fine grain from one noise
	vec3 q = wpos * 0.35;
	float big = texture(noise_tex, q.xz * 0.5 + q.y * 0.21).r * w.y + texture(noise_tex, q.zy).r * w.x + texture(noise_tex, q.xy).r * w.z;
	float fine = texture(noise_tex, wpos.xz * 2.7 + wpos.y * 1.3).r;
	float ao = COLOR.r;
	// moss: on what faces the sky, in blotches; and creeping up from the ground in the damp
	float up = smoothstep(0.15, 0.85, n.y);
	// r38: a tight smoothstep and a moss darker than the slab read as camouflage blotches on a moonlit roof: a soft edge, a value close to the stone's
	float m_top = up * smoothstep(0.26, 0.9, big + moss_amount * 0.55 - 0.18) * 0.55 * step(0.001, moss_amount);
	float m_foot = foot_moss * smoothstep(0.7, 0.58, ao) * smoothstep(0.35, 0.6, big + fine * 0.3);
	float moss = clamp(max(m_top, m_foot) * (0.75 + 0.5 * fine), 0.0, 1.0);
	vec3 moss_col = mix(vec3(0.2, 0.26, 0.11), vec3(0.34, 0.39, 0.16), fine);
	// rain streaks down the sides, pale lichen crusts
	float side = 1.0 - up;
	float st = texture(noise_tex, vec2((wpos.x + wpos.z) * 1.7, wpos.y * 0.09)).r;
	float lichen = smoothstep(0.66, 0.9, texture(noise_tex, wpos.xz * 1.9 + wpos.zy * 1.3).r) * side * streaks;
	vec3 stone = alb * tint.rgb * COLOR.rgb;
	stone *= 1.0 - streaks * side * smoothstep(0.55, 0.85, st) * 0.22;
	stone *= 0.9 + 0.2 * big;
	stone = mix(stone, stone * vec3(0.88, 0.95, 0.8) + vec3(0.012, 0.018, 0.006), lichen * 0.5);      // a greener, darker crust, never paler than the stone
	ALBEDO = mix(stone, moss_col * (0.8 + 0.4 * ao), moss);
	ROUGHNESS = mix(clamp(rough, 0.5, 1.0), 0.98, moss);
	nw = normalize(mix(nw, n, moss * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
"""


# =============================================================================================
# meshes (local frame; cached)
# =============================================================================================

## A cached mesh for `key` built by `fn` (returns ArrayMesh): memory, then GenCache, then built.
static func cached(key: String, fn: Callable) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var m := GenCache.load_mesh(key, SELF)
	if m == null:
		m = fn.call()
		GenCache.save_mesh(key, SELF, m)
	_meshes[key] = m
	return m


## Mesh writer with UVs and vertex colours (one surface). Faces wound from their outward normal.
class MB:
	var st := SurfaceTool.new()
	var n := 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, col := Color.WHITE) -> void:
		var nn := (b - a).cross(c - a)
		if nn.dot(out) > 0.0:
			var t := b
			b = c
			c = t
			var tu := ub
			ub = uc
			uc = tu
		var fn := out.normalized()
		for v: Array in [[a, ua], [b, ub], [c, uc]]:
			st.set_normal(fn)
			st.set_color(col)
			st.set_uv(v[1])
			st.add_vertex(v[0])
		n += 1

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col := Color.WHITE) -> void:
		tri(a, b, c, out, ua, ub, uc, col)
		tri(a, c, d, out, ua, uc, ud, col)

	## Oriented box; UVs world-ish (metres) per face.
	func box(c: Vector3, size: Vector3, b: Basis, col := Color.WHITE, bottom := false) -> void:
		var h := size * 0.5
		var ax: Array[Vector3] = [b.x.normalized(), b.y.normalized(), b.z.normalized()]
		for i in 3:
			var f: Vector3 = ax[i]
			var u: Vector3 = ax[(i + 1) % 3]
			var v: Vector3 = ax[(i + 2) % 3]
			var hf: float = h[i]
			var hu: float = h[(i + 1) % 3]
			var hv: float = h[(i + 2) % 3]
			for s: float in [-1.0, 1.0]:
				if i == 1 and s < 0.0 and not bottom:
					continue
				var o := c + f * hf * s
				var shade := col * (0.62 if (i == 1 and s < 0.0) else 1.0)
				quad(o - u * hu - v * hv, o + u * hu - v * hv, o + u * hu + v * hv, o - u * hu + v * hv, f * s,
					Vector2(0, 0), Vector2(hu * 2.0, 0), Vector2(hu * 2.0, hv * 2.0), Vector2(0, hv * 2.0), shade)

	func commit() -> ArrayMesh:
		st.generate_tangents()
		return st.commit()


static func _h(a: float, b: float, s: int) -> float:
	var v := sin(a * 12.9898 + b * 78.233 + float(s) * 37.719) * 43758.5453
	return v - floorf(v)


## Layered thatch over a gable roof, cottage frame: ridge along local x at height `ridge`, eaves
## at `eave` on both sides (z = +-(d/2 + over)). Courses step down the slope; each ends in a
## rounded drip edge; a scalloped ridge cap with liggers rides the top. {thatch, under} meshes.
static func thatch_roof(w: float, d: float, eave: float, ridge: float, seed_n: int, over := 0.45, side_over := 0.4) -> Dictionary:
	var key := "lore_thatch|%.2f|%.2f|%.2f|%.2f|%d|%.2f" % [w, d, eave, ridge, seed_n, over]
	var th := cached(key + "|t", func() -> ArrayMesh: return _thatch(w, d, eave, ridge, seed_n, over, side_over, false))
	var un := cached(key + "|u", func() -> ArrayMesh: return _thatch(w, d, eave, ridge, seed_n, over, side_over, true))
	return {"thatch": th, "under": un}


static func _thatch(w: float, d: float, eave: float, ridge: float, sn: int, over: float, side_over: float, under: bool) -> ArrayMesh:
	var mb := MB.new()
	var hd := d * 0.5
	var x0 := -w * 0.5 - side_over
	var x1 := w * 0.5 + side_over
	var nx := maxi(4, int((x1 - x0) / 0.32))
	var K := 4
	for side: float in [-1.0, 1.0]:
		var top := Vector3(0, ridge + 0.05, 0)
		var drop := over * (ridge - eave) / hd
		var bot := Vector3(0, eave - drop, side * (hd + over))
		var L := top.distance_to(bot)
		var dv := (bot - top) / L                          # down the slope
		var out := Vector3(0, absf(dv.z), -dv.y * side).normalized()
		if out.y < 0.0:
			out = -out
		var at := func(x: float, s: float, hh: float) -> Vector3: return Vector3(x, 0, 0) + top + dv * s + out * hh
		if under:
			# the underside on the rafter plane, and the eave's cut face of straw seen from below
			mb.quad(at.call(x0, 0.0, 0.0), at.call(x1, 0.0, 0.0), at.call(x1, L, 0.0), at.call(x0, L, 0.0), -out,
				Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.5, 0.48, 0.46))
			continue
		var hs: Array[float] = []
		for k in K + 1:
			hs.append(0.34 + 0.075 * float(K - 1 - k) if k < K else -0.02)
		for k in K:
			var s_start := 0.0 if k == 0 else L * float(k) / float(K) - 0.05
			var s_end := L * float(k + 1) / float(K)
			var h0: float = hs[k]
			var h1: float = hs[k + 1]
			var lip := 0.11 if k < K - 1 else 0.16
			for i in nx:
				var xa := lerpf(x0, x1, float(i) / float(nx))
				var xb := lerpf(x0, x1, float(i + 1) / float(nx))
				var ja := (_h(xa, float(k), sn) - 0.5) * 0.09
				var jb := (_h(xb, float(k), sn) - 0.5) * 0.09
				if i == 0:
					ja = 0.0
				if i == nx - 1:
					jb = 0.0
				var ea := s_end + ja
				var eb := s_end + jb
				var tint := 0.86 + 0.18 * _h(float(i / 3), float(k) + side, sn + 5)
				var c_top := Color(tint, tint, tint)
				var u0 := xa * 0.7
				var u1 := xb * 0.7
				# top of the course
				mb.quad(at.call(xa, s_start, h0), at.call(xb, s_start, h0), at.call(xb, eb - lip, h0), at.call(xa, ea - lip, h0), out,
					Vector2(u0, s_start * 0.6), Vector2(u1, s_start * 0.6), Vector2(u1, (eb - lip) * 0.6), Vector2(u0, (ea - lip) * 0.6), c_top)
				# the rolled drip edge: three facets from the top over to the face below
				var prev_a: Vector3 = at.call(xa, ea - lip, h0)
				var prev_b: Vector3 = at.call(xb, eb - lip, h0)
				var prev_n := out
				for f in 3:
					var t := float(f + 1) / 3.0
					var ang := t * PI * 0.5
					var ss := sin(ang) * lip
					var hh := h0 - (1.0 - cos(ang)) * (h0 - h1 + 0.04) * 0.5 - t * t * (h0 - h1) * 0.5
					var qa: Vector3 = at.call(xa, ea - lip + ss, hh)
					var qb: Vector3 = at.call(xb, eb - lip + ss, hh)
					var fn := (out * cos(ang) + dv * sin(ang)).normalized()
					var cshade := Color(tint, tint, tint) * (1.0 - t * 0.35)
					mb.quad(prev_a, prev_b, qb, qa, (prev_n + fn).normalized(),
						Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 0.08), Vector2(u0, 0.08), cshade)
					prev_a = qa
					prev_b = qb
					prev_n = fn
				# the cut face under the drip down to the course below (shadowed)
				var fa: Vector3 = at.call(xa, ea, h1 + 0.01)
				var fb: Vector3 = at.call(xb, eb, h1 + 0.01)
				mb.quad(prev_a, prev_b, fb, fa, dv, Vector2(u0, 0.1), Vector2(u1, 0.1), Vector2(u1, 0.2), Vector2(u0, 0.2), Color(0.42, 0.4, 0.38))
			# verges: close each course's section at the gable ends
			for gx: float in [x0, x1]:
				var sn2 := Vector3(signf(gx), 0, 0)
				mb.quad(at.call(gx, s_start, 0.0), at.call(gx, s_end, 0.0), at.call(gx, s_end, h0), at.call(gx, s_start, h0), sn2,
					Vector2(s_start * 0.6, 0), Vector2(s_end * 0.6, 0), Vector2(s_end * 0.6, h0), Vector2(s_start * 0.6, h0), Color(0.62, 0.6, 0.56))
		# the eave's underside lip (seen from below)
		mb.quad(at.call(x0, L, -0.02), at.call(x1, L, -0.02), at.call(x1, L - 0.4, -0.02), at.call(x0, L - 0.4, -0.02), -out,
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.3), Vector2(0, 0.3), Color(0.45, 0.43, 0.4))
		# ridge cap: a thicker layer down to a scalloped edge, liggers along it, spars in a zigzag
		var cap_s := 0.75
		var hc: float = hs[0] + 0.12
		for i in nx:
			var xa := lerpf(x0, x1, float(i) / float(nx))
			var xb := lerpf(x0, x1, float(i + 1) / float(nx))
			var xm := (xa + xb) * 0.5
			var sc := cap_s + 0.18                      # scallop point
			mb.quad(at.call(xa, -0.02, hc), at.call(xb, -0.02, hc), at.call(xb, cap_s, hc), at.call(xa, cap_s, hc), out,
				Vector2(xa * 0.7, 0), Vector2(xb * 0.7, 0), Vector2(xb * 0.7, 0.45), Vector2(xa * 0.7, 0.45), Color(1.0, 0.97, 0.92))
			mb.tri(at.call(xa, cap_s, hc), at.call(xb, cap_s, hc), at.call(xm, sc, hc - 0.04), out,
				Vector2(xa * 0.7, 0.45), Vector2(xb * 0.7, 0.45), Vector2(xm * 0.7, 0.55), Color(0.95, 0.92, 0.86))
			# the scallop's edge faces
			for e: Array in [[xa, cap_s, xm, sc], [xm, sc, xb, cap_s]]:
				var p0: Vector3 = at.call(float(e[0]), float(e[1]), hc)
				var p1: Vector3 = at.call(float(e[2]), float(e[3]), hc - (0.04 if float(e[1]) < float(e[3]) else 0.0))
				var p2: Vector3 = at.call(float(e[2]), float(e[3]), hs[0])
				var p3: Vector3 = at.call(float(e[0]), float(e[1]), hs[0])
				mb.quad(p0, p1, p2, p3, dv, Vector2(0, 0), Vector2(0.2, 0), Vector2(0.2, 0.1), Vector2(0, 0.1), Color(0.55, 0.52, 0.48))
		# liggers: two hazel rods along the cap, cross-spars between them
		for ls: float in [0.22, 0.62]:
			var r0: Vector3 = at.call(x0 + 0.1, ls, hc + 0.025)
			var r1: Vector3 = at.call(x1 - 0.1, ls, hc + 0.025)
			mb.box((r0 + r1) * 0.5, Vector3(r0.distance_to(r1), 0.035, 0.035), Basis(Vector3.RIGHT, out, Vector3.RIGHT.cross(out)), Color(0.42, 0.33, 0.24))
		var nsp := int((x1 - x0) / 0.36)
		for i in nsp:
			var xs := x0 + 0.2 + float(i) * 0.36
			var a: Vector3 = at.call(xs, 0.22, hc + 0.03)
			var b: Vector3 = at.call(xs + 0.18, 0.62, hc + 0.03)
			var dd := b - a
			var bx := Basis(dd.normalized(), out, dd.normalized().cross(out).normalized())
			mb.box((a + b) * 0.5, Vector3(dd.length(), 0.025, 0.025), bx, Color(0.4, 0.31, 0.22))
	# the ridge roll on top
	if not under:
		var rr := 0.2
		var hc2 := ridge + 0.05 + 0.34 + 0.075 * 3.0 + 0.1
		var segs := 6
		for i in nx:
			var xa := lerpf(x0, x1, float(i) / float(nx))
			var xb := lerpf(x0, x1, float(i + 1) / float(nx))
			for j in segs:
				var a0 := PI * float(j) / float(segs)
				var a1 := PI * float(j + 1) / float(segs)
				var o0 := Vector3(0, sin(a0) * rr * 0.7, cos(a0) * rr * 1.5)
				var o1 := Vector3(0, sin(a1) * rr * 0.7, cos(a1) * rr * 1.5)
				var nn := Vector3(0, sin((a0 + a1) * 0.5), cos((a0 + a1) * 0.5))
				mb.quad(Vector3(xa, hc2, 0) + o0, Vector3(xb, hc2, 0) + o0, Vector3(xb, hc2, 0) + o1, Vector3(xa, hc2, 0) + o1, nn,
					Vector2(xa * 0.7, a0 * 0.2), Vector2(xb * 0.7, a0 * 0.2), Vector2(xb * 0.7, a1 * 0.2), Vector2(xa * 0.7, a1 * 0.2), Color(0.96, 0.93, 0.88))
		for gx: float in [x0, x1]:
			for j in segs:
				var a0 := PI * float(j) / float(segs)
				var a1 := PI * float(j + 1) / float(segs)
				mb.tri(Vector3(gx, hc2 - 0.05, 0), Vector3(gx, hc2, 0) + Vector3(0, sin(a0) * rr * 0.7, cos(a0) * rr * 1.5), Vector3(gx, hc2, 0) + Vector3(0, sin(a1) * rr * 0.7, cos(a1) * rr * 1.5),
					Vector3(signf(gx), 0, 0), Vector2(0, 0), Vector2(0.2, 0), Vector2(0.2, 0.2), Color(0.7, 0.67, 0.62))
	return mb.commit()


## Individual slates over a gable roof (same frame as thatch_roof): rows lapped down the slope,
## each slate a little lifted at its tail, jittered, a few slipped or missing (`holes` 0..1),
## and a row of ridge tiles. Laid on a dark underlay so gaps read as holes, not sky.
static func slate_roof(w: float, d: float, eave: float, ridge: float, seed_n: int, holes := 0.0, over := 0.45, side_over := 0.35) -> ArrayMesh:
	var key := "lore_slates|%.2f|%.2f|%.2f|%.2f|%d|%.2f|%.2f" % [w, d, eave, ridge, seed_n, holes, over]
	return cached(key, func() -> ArrayMesh: return _slates(w, d, eave, ridge, seed_n, holes, over, side_over))


static func _slates(w: float, d: float, eave: float, ridge: float, sn: int, holes: float, over: float, side_over: float) -> ArrayMesh:
	var mb := MB.new()
	var hd := d * 0.5
	var x0 := -w * 0.5 - side_over
	var x1 := w * 0.5 + side_over
	for side: float in [-1.0, 1.0]:
		var top := Vector3(0, ridge, 0)
		var drop := over * (ridge - eave) / hd
		var bot := Vector3(0, eave - drop, side * (hd + over))
		var L := top.distance_to(bot)
		var dv := (bot - top) / L
		var out := Vector3(0, absf(dv.z), -dv.y * side).normalized()
		if out.y < 0.0:
			out = -out
		var along := Vector3.RIGHT
		var rows := int(L / 0.21)
		for r in rows:
			var s := L - 0.02 - float(r) * 0.21          # lower edge of this row (eave first)
			var xs := x0 + (0.14 if r % 2 == 1 else 0.0)
			while xs < x1 - 0.05:
				var sw := 0.26 + 0.06 * _h(xs, float(r), sn)
				var xe := minf(xs + sw, x1)
				var hv := _h(xs * 3.1, float(r) * 1.7, sn + 11)
				if hv < holes and r > 1 and r < rows - 1:
					xs = xe
					continue
				var slip := 0.0
				if hv > 1.0 - holes * 0.3:
					slip = 0.12                      # slipped down
				var c := Vector3((xs + xe) * 0.5, 0, 0) + top + dv * (s - 0.2 + slip) + out * (0.03 + float(r % 2) * 0.004)
				var tilt := Basis(along, out, along.cross(out).normalized())
				var lift := Basis(along, 0.035 * (1.0 if side > 0.0 else -1.0) * -1.0)
				var yaw := Basis(out, (hv - 0.5) * 0.06)
				var g := 0.8 + 0.3 * _h(xs * 1.3, float(r) * 2.1, sn + 3)
				mb.box(c, Vector3(xe - xs - 0.012, 0.022, 0.42), (yaw * lift * tilt).orthonormalized(), Color(g, g, g * 1.02), true)
				xs = xe
		# underlay (dark felt and battens)
		mb.quad(top + Vector3(x0, 0, 0), top + Vector3(x1, 0, 0), bot + Vector3(x1, 0, 0), bot + Vector3(x0, 0, 0), out,
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.22, 0.2, 0.2))
		mb.quad(top + Vector3(x0, 0, 0), top + Vector3(x1, 0, 0), bot + Vector3(x1, 0, 0), bot + Vector3(x0, 0, 0), -out,
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.3, 0.27, 0.25))
	# ridge tiles: inverted V caps
	var xr := x0
	while xr < x1:
		var xe2 := minf(xr + 0.42, x1)
		for s2: float in [-1.0, 1.0]:
			var a := Vector3(xr, ridge + 0.1, 0)
			var b := Vector3(xe2, ridge + 0.1, 0)
			var lo := Vector3(0, -0.12, s2 * 0.2)
			mb.quad(a, b, b + lo, a + lo, Vector3(0, 0.7, s2 * 0.7), Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 0.2), Vector2(0, 0.2), Color(0.75, 0.74, 0.76))
		xr = xe2 + 0.01
	return mb.commit()
