extends RefCounted
## The wanderer's procedural textures: twill wool, an embroidered rune band, leather, staff wood and
## blackened iron, each an albedo (+ a packed alpha) and a normal map. Pure Image + FastNoiseLite,
## deterministic, built once and kept in GenCache (block-compressed: S3TC/DXT for colour, RGTC for
## normals), so a warm load only decompresses ~4 MB. Load by path (no class_name):
##   const WTex := preload("res://core/player/wanderer_tex.gd")
##   WTex.tex("wool")  /  WTex.tex("wool_n")
##
## Packed alpha:  wool, leather, iron -> roughness (0..1);  trim -> rune glow mask;  wood -> roughness;
## staff -> roughness, and < 0.1 inside the carved runes (the gear shader makes those glow).
## The merged body (wanderer_body.gd) samples the gear tiles as ONE Texture2DArray (array()):
##   GEAR_LAYERS = leather, iron, wood, wool_s (trousers, wraps), strap (stitched), staff (carved runes).

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/player/wanderer_tex.gd"
const GEAR_LAYERS := ["leather", "iron", "wood", "wool_s", "strap", "staff"]
static var _mem := {}


static func tex(name: String) -> Texture2D:
	if _mem.has(name):
		return _mem[name]
	var t := ImageTexture.create_from_image(img(name))
	_mem[name] = t
	return t


## The gear tiles (all 512, same formats) as one Texture2DArray: albedo (normal = false) or normal.
static func array(normal: bool) -> Texture2DArray:
	var k := "#arr_n" if normal else "#arr"
	if _mem.has(k):
		return _mem[k]
	var imgs: Array[Image] = []
	for n: String in GEAR_LAYERS:
		imgs.append(img(n + ("_n" if normal else "")))
	var fmt := imgs[0].get_format()
	for im in imgs:
		if im.get_format() != fmt:
			fmt = -1
	if fmt == -1:                                 # S3TC picked DXT1 for one: fall back to RGBA8
		for i in imgs.size():
			var c := imgs[i].duplicate() as Image
			c.decompress()
			c.convert(Image.FORMAT_RGBA8)
			if not c.has_mipmaps():
				c.generate_mipmaps()
			imgs[i] = c
	var arr := Texture2DArray.new()
	if arr.create_from_images(imgs) != OK:
		push_error("WandererTex.array: layers differ in size or format")
	_mem[k] = arr
	return arr


## The (block-compressed, mipmapped) image behind tex(name), from GenCache or freshly made.
static func img(name: String) -> Image:
	if _mem.has("#img|" + name):
		return _mem["#img|" + name]
	var key := "wanderer_tex|" + name
	var out: Image = null
	var d: Variant = GenCache.load_var(key, SELF)
	if d is Dictionary:
		var dd := d as Dictionary
		var raw := (dd["d"] as PackedByteArray).decompress(int(dd["n"]), FileAccess.COMPRESSION_ZSTD)
		if raw.size() == int(dd["n"]):
			out = Image.create_from_data(int(dd["w"]), int(dd["h"]), true, int(dd["f"]) as Image.Format, raw)
	if out == null:
		var base := name.trim_suffix("_n")
		var pair := _make(base)                  # [albedo, normal], both RGBA8
		for i in 2:
			var im: Image = pair[i]
			im.generate_mipmaps()
			var nm := base if i == 0 else base + "_n"
			if im.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL if i == 1 else Image.COMPRESS_SOURCE_GENERIC) != OK:
				push_warning("WandererTex: %s left uncompressed" % nm)
			var bytes := im.get_data()
			GenCache.save_var("wanderer_tex|" + nm, SELF, {"w": im.get_width(), "h": im.get_height(), "f": im.get_format(), "n": bytes.size(), "d": bytes.compress(FileAccess.COMPRESSION_ZSTD)})
			if nm == name:
				out = im
	_mem["#img|" + name] = out
	return out


static func _make(base: String) -> Array:
	match base:
		"wool":
			return _wool(1024)
		"wool_s":
			return _wool(512)
		"strap":
			return _strap()
		"staff":
			return _staff()
		"trim":
			return _trim()
		"leather":
			return _leather()
		"wood":
			return _wood()
		_:
			return _iron()


# --- helpers ----------------------------------------------------------------------------------

static func _noise(w: int, h: int, freq: float, octaves: int, seed: int, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.seed = seed
	var im := n.get_seamless_image(w, h, false, false, 0.1, true)
	im.convert(Image.FORMAT_L8)
	return im.get_data()


static func _cells(w: int, h: int, freq: float, seed: int) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = freq
	n.seed = seed
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	var im := n.get_seamless_image(w, h, false, false, 0.1, true)
	im.convert(Image.FORMAT_L8)
	return im.get_data()


## Bilinear along rows of a (w x rows) byte field sampled at fractional row `fr` (wraps).
static func _row_lerp(d: PackedByteArray, w: int, rows: int, x: int, fr: float) -> float:
	var r0 := int(fr) % rows
	var r1 := (r0 + 1) % rows
	var t := fr - floorf(fr)
	return lerpf(float(d[r0 * w + x]), float(d[r1 * w + x]), t)


static func _col_lerp(d: PackedByteArray, w: int, h: int, fc: float, y: int) -> float:
	var c0 := int(fc) % w
	var c1 := (c0 + 1) % w
	var t := fc - floorf(fc)
	return lerpf(float(d[y * w + c0]), float(d[y * w + c1]), t)


static func _hash(i: int) -> float:
	var x := float(i) * 12.9898 + 78.233
	return fposmod(sin(x) * 43758.5453, 1.0)


## Tangent-space normal map from a height field (wraps at the edges: tiles cleanly).
static func _normal_from(hgt: PackedFloat32Array, w: int, h: int, strength: float) -> Image:
	var out := PackedByteArray()
	out.resize(w * h * 4)
	for y in h:
		var ym := ((y - 1 + h) % h) * w
		var yp := ((y + 1) % h) * w
		var yr := y * w
		for x in w:
			var xm := (x - 1 + w) % w
			var xp := (x + 1) % w
			var dx := (hgt[yr + xp] - hgt[yr + xm]) * strength
			var dy := (hgt[yp + x] - hgt[ym + x]) * strength
			var inv := 1.0 / sqrt(dx * dx + dy * dy + 1.0)
			var o := (yr + x) * 4
			out[o] = int(clampf((-dx * inv) * 0.5 + 0.5, 0.0, 1.0) * 255.0)
			out[o + 1] = int(clampf((dy * inv) * 0.5 + 0.5, 0.0, 1.0) * 255.0)   # Godot: +Y green up
			out[o + 2] = int(clampf(inv * 0.5 + 0.5, 0.0, 1.0) * 255.0)
			out[o + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


static func _put(px: PackedByteArray, i: int, c: Color, a: float) -> void:
	var o := i * 4
	px[o] = int(clampf(c.r, 0.0, 1.0) * 255.0)
	px[o + 1] = int(clampf(c.g, 0.0, 1.0) * 255.0)
	px[o + 2] = int(clampf(c.b, 0.0, 1.0) * 255.0)
	px[o + 3] = int(clampf(a, 0.0, 1.0) * 255.0)


# --- wool: a 2/2 twill of madder-wine warp and umber weft, slubs, fuzz, dye mottling and wear ------

static func _wool(size: int) -> Array:
	var w := size
	var h := size
	var pitch := 4.0                                   # px per thread: 256 threads per 1024 tile
	var mottle := _noise(w, h, 0.004, 4, 11)
	var wear := _noise(w, h, 0.006, 3, 23)
	var fuzz := _noise(w, h, 0.25, 2, 37)
	var slub_w := _noise(w, h / 8, 0.03, 2, 41)        # sampled at y/8: long along a warp thread
	var slub_f := _noise(w / 8, h, 0.03, 2, 43)        # sampled at x/8: along a weft thread
	var warp_c := Color(0.215, 0.09, 0.075)
	var weft_c := Color(0.15, 0.11, 0.085)
	var px := PackedByteArray()
	px.resize(w * h * 4)
	var hgt := PackedFloat32Array()
	hgt.resize(w * h)
	for y in h:
		var fy := float(y) / pitch
		var iy := int(fy)
		var ty := fy - float(iy)
		for x in w:
			var i := y * w + x
			var fx := float(x) / pitch
			var ix := int(fx)
			var tx := fx - float(ix)
			var k := (ix - iy) & 3                     # twill: each warp floats over two weft rows
			var warp := k < 2
			var across := tx if warp else ty
			var along := (float(k) + ty) * 0.5 if warp else (float((k + 2) & 3) + tx) * 0.5
			var prof := sqrt(maxf(sin(PI * across), 0.0))
			var dip := 0.55 + 0.45 * sqrt(maxf(sin(PI * clampf(along, 0.0, 1.0)), 0.0))
			var slub := (_row_lerp(slub_w, w, h / 8, x, float(y) / 8.0) if warp else _col_lerp(slub_f, w / 8, h, float(x) / 8.0, y)) / 255.0
			var tone := 0.84 + 0.24 * _hash(ix if warp else iy + 4096) + (slub - 0.5) * 0.18
			var m := float(mottle[i]) / 255.0
			var wr := smoothstep(0.5, 0.95, float(wear[i]) / 255.0) * 0.7
			var fz := float(fuzz[i]) / 255.0
			var weave := prof * dip
			var c := warp_c if warp else weft_c
			# the weave reads: deep shadow between threads, a sheen along each float's crown
			var lum := (0.34 + 0.86 * weave) * tone * (0.86 + 0.28 * m) + (fz - 0.5) * 0.12
			var col := c * lum + Color(0.06, 0.04, 0.028) * pow(weave, 6.0)
			# wear: rubbed flat and a little lighter / greyer
			col = col.lerp(Color(0.27, 0.21, 0.165) * (0.8 + 0.3 * weave), wr * 0.5)
			var rough := clampf(0.9 - wr * 0.18 + (fz - 0.5) * 0.08, 0.55, 1.0)
			_put(px, i, col, rough)
			hgt[i] = weave * (1.0 - wr * 0.5) + (m - 0.5) * 0.6 + (fz - 0.5) * 0.15
	var alb := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	return [alb, _normal_from(hgt, w, h, 2.6)]


# --- trim: a dark band with couched gold cords and a lozenge-and-rune border, stitched ----------

static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _rune(seed: int) -> Array:
	# a stem plus two or three branches, Futhark-like, in a unit box (x -0.5..0.5, y -0.5..0.5)
	var segs: Array = [[Vector2(0, -0.5), Vector2(0, 0.5)]]
	var r := seed
	for b in 2 + (r % 2):
		var y0 := -0.45 + 0.4 * float(b) + 0.1 * _hash(r + b)
		var side := -1.0 if _hash(r * 3 + b) < 0.5 else 1.0
		var up := 1.0 if _hash(r * 7 + b) < 0.5 else -1.0
		segs.append([Vector2(0, y0), Vector2(side * 0.42, y0 + up * 0.32)])
	if _hash(r * 13) < 0.4:
		segs.append([Vector2(-0.38, 0.0), Vector2(0.38, 0.0)])
	return segs


static func _trim() -> Array:
	var w := 1024
	var h := 256
	var rep := 128
	var cloth := _noise(w, h, 0.05, 3, 51)
	var fuzz := _noise(w, h, 0.3, 1, 53)
	var base := Color(0.085, 0.06, 0.045)
	var silver := Color(0.74, 0.56, 0.3)        # ochre-gold thread
	var violet := Color(0.96, 0.64, 0.3)        # the runes: warm amber silk
	var runes: Array = []
	for k in w / rep:
		runes.append(_rune(7 + k * 31))
	var px := PackedByteArray()
	px.resize(w * h * 4)
	var hgt := PackedFloat32Array()
	hgt.resize(w * h)
	for y in h:
		var v := float(y) / float(h)
		for x in w:
			var i := y * w + x
			var cell := x / rep
			var lx := (float(x % rep) + 0.5) / float(rep) - 0.5        # -0.5..0.5 across one motif
			var ly := v - 0.5                                            # -0.5..0.5 across the band
			# base: a tight plain weave
			var weave := 0.5 + 0.5 * sin(float(x) * 1.6) * sin(float(y) * 1.6)
			var nz := float(cloth[i]) / 255.0
			var col := base * (0.8 + 0.25 * weave + (nz - 0.5) * 0.3)
			var height := weave * 0.25 + (nz - 0.5) * 0.2
			var glow := 0.0
			var thread := 0.0
			# couched cords near both edges: a twisted rope (diagonal stripes)
			for edge: float in [0.1, 0.9]:
				var dv := absf(v - edge)
				if dv < 0.035:
					var tw := 0.5 + 0.5 * sin((float(x) + float(y) * 1.2) * 0.9)
					var prof := pow(1.0 - dv / 0.035, 0.35)
					thread = maxf(thread, prof * (0.6 + 0.4 * tw))
			# lozenge outline (tall diamond) and a small diamond between motifs
			var dd := absf(lx) / 0.42 + absf(ly) / 0.3
			var ring := absf(dd - 1.0)
			if ring < 0.085:
				thread = maxf(thread, sqrt(1.0 - ring / 0.085))
				glow = maxf(glow, 0.25 * (1.0 - ring / 0.085))
			var ex := absf(absf(lx) - 0.5)
			var small := ex / 0.07 + absf(ly) / 0.07
			if small < 1.0:
				thread = maxf(thread, 1.0 - small * 0.5)
			# the rune inside, satin-stitched, glowing
			if dd < 0.9:
				var p := Vector2(lx / 0.42, ly / 0.32) * 0.95
				var best := 9.0
				for sg: Array in runes[cell]:
					best = minf(best, _seg_d(p, sg[0], sg[1]))
				if best < 0.075:
					var k := 1.0 - best / 0.075
					thread = maxf(thread, sqrt(k))
					glow = maxf(glow, smoothstep(0.0, 0.6, k))
			if thread > 0.0:
				var satin := 0.75 + 0.25 * sin((float(x) - float(y)) * 1.9)       # stitch direction
				var tc := silver.lerp(violet, glow)
				col = col.lerp(tc * (0.65 + 0.4 * satin) * (0.9 + (float(fuzz[i]) / 255.0 - 0.5) * 0.3), clampf(thread * 1.6, 0.0, 1.0))
				height += thread * (0.8 + 0.2 * satin)
			_put(px, i, col, glow)
			hgt[i] = height
	var alb := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	return [alb, _normal_from(hgt, w, h, 4.2)]


# --- leather: pebbled grain, creases, scuffed lighter where worn -------------------------------

static func _leather() -> Array:
	var w := 512
	var h := 512
	var grain := _cells(w, h, 0.09, 61)
	var crease := _noise(w, h, 0.02, 4, 63, FastNoiseLite.TYPE_SIMPLEX)
	var mottle := _noise(w, h, 0.008, 3, 65)
	var wear := _noise(w, h, 0.012, 3, 67)
	var base := Color(0.13, 0.095, 0.075)
	var px := PackedByteArray()
	px.resize(w * h * 4)
	var hgt := PackedFloat32Array()
	hgt.resize(w * h)
	for i in w * h:
		var g := float(grain[i]) / 255.0
		var cr := 1.0 - absf(float(crease[i]) / 127.5 - 1.0)       # ridged: thin creases
		cr = pow(cr, 6.0)
		var m := float(mottle[i]) / 255.0
		var wr := smoothstep(0.6, 0.85, float(wear[i]) / 255.0)
		var col := base * (0.75 + 0.35 * g + (m - 0.5) * 0.4) * (1.0 - cr * 0.35)
		col = col.lerp(Color(0.24, 0.19, 0.15), wr * 0.5)
		var rough := clampf(0.78 - wr * 0.2 - g * 0.06, 0.4, 1.0)
		_put(px, i, col, rough)
		hgt[i] = g * 0.5 - cr * 0.8 + (m - 0.5) * 0.3
	var alb := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	return [alb, _normal_from(hgt, w, h, 2.5)]


# --- wood: dark old ash, long fibres along V, a few knots, hand-polished --------------------------

static func _wood() -> Array:
	var w := 512
	var h := 512
	var fib := _noise(w, 32, 0.08, 3, 71)                # sampled at y/16: fibres run along V
	var fine := _noise(w, h, 0.2, 2, 73)
	var big := _noise(w, h, 0.006, 3, 75)
	var knot_c := [Vector2(120, 90), Vector2(380, 300), Vector2(240, 470)]
	var base := Color(0.2, 0.145, 0.1)
	var px := PackedByteArray()
	px.resize(w * h * 4)
	var hgt := PackedFloat32Array()
	hgt.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			var p := Vector2(x, y)
			var kn := 0.0
			var warp := 0.0
			for kc: Vector2 in knot_c:
				var d := (p - kc)
				d.x = fposmod(d.x + 256.0, 512.0) - 256.0
				d.y = fposmod(d.y + 256.0, 512.0) - 256.0
				var r := Vector2(d.x, d.y * 0.45).length()
				kn = maxf(kn, smoothstep(22.0, 6.0, r))
				warp += 9.0 * exp(-r * r / 900.0) * signf(d.x)
			var fx := int(fposmod(float(x) + warp, float(w)))
			var f := _row_lerp(fib, w, 32, fx, float(y) / 16.0) / 255.0
			var ff := float(fine[i]) / 255.0
			var b := float(big[i]) / 255.0
			var streak := pow(f, 1.6)
			var col := base * (0.7 + 0.5 * streak + (ff - 0.5) * 0.25 + (b - 0.5) * 0.3)
			col = col.lerp(Color(0.07, 0.05, 0.04), kn * 0.8)
			var rough := clampf(0.62 + (1.0 - streak) * 0.2 - b * 0.1, 0.35, 1.0)
			_put(px, i, col, rough)
			hgt[i] = streak * 0.7 + ff * 0.2 - kn * 0.6
	var alb := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	return [alb, _normal_from(hgt, w, h, 3.0)]


# --- iron: blackened, hammer-dented, rust in the pits ------------------------------------------

static func _iron() -> Array:
	var w := 512
	var h := 512
	var dents := _cells(w, h, 0.025, 81)
	var rust := _noise(w, h, 0.015, 4, 83)
	var fine := _noise(w, h, 0.25, 1, 85)
	var px := PackedByteArray()
	px.resize(w * h * 4)
	var hgt := PackedFloat32Array()
	hgt.resize(w * h)
	for i in w * h:
		var d := float(dents[i]) / 255.0
		var r := smoothstep(0.62, 0.8, float(rust[i]) / 255.0) * (1.0 - d)
		var f := float(fine[i]) / 255.0
		var col := Color(0.2, 0.2, 0.22) * (0.75 + 0.4 * d + (f - 0.5) * 0.2)
		col = col.lerp(Color(0.25, 0.12, 0.06), r * 0.8)
		var rough := clampf(0.42 + r * 0.45 + (1.0 - d) * 0.12, 0.25, 1.0)
		_put(px, i, col, rough)
		hgt[i] = d * 0.6 + (f - 0.5) * 0.1 - r * 0.2
	var alb := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	return [alb, _normal_from(hgt, w, h, 1.6)]


# --- strap: leather with a burnished, darkened edge and a saddle-stitch row along each side ------
# u runs across the strap (0..1 = one width), v along it (one tile = 4 widths).

static func _strap() -> Array:
	var w := 512
	var h := 512
	var grain := _cells(w, h, 0.11, 91)
	var mottle := _noise(w, h, 0.01, 3, 93)
	var crease := _noise(w, h, 0.03, 3, 95, FastNoiseLite.TYPE_SIMPLEX)
	var base := Color(0.15, 0.105, 0.078)
	var thread := Color(0.42, 0.37, 0.3)
	var px := PackedByteArray()
	px.resize(w * h * 4)
	var hgt := PackedFloat32Array()
	hgt.resize(w * h)
	var spacing := 18.0                                  # px per stitch along v
	for y in h:
		for x in w:
			var i := y * w + x
			var u := (float(x) + 0.5) / float(w)
			var g := float(grain[i]) / 255.0
			var m := float(mottle[i]) / 255.0
			var cr := pow(1.0 - absf(float(crease[i]) / 127.5 - 1.0), 8.0) * smoothstep(0.1, 0.3, u) * smoothstep(0.9, 0.7, u)
			var edge := minf(u, 1.0 - u)
			var bevel := smoothstep(0.0, 0.06, edge)
			var col := base * (0.78 + 0.3 * g + (m - 0.5) * 0.35) * (1.0 - cr * 0.3)
			col = col.lerp(Color(0.06, 0.04, 0.03), (1.0 - bevel) * 0.75)      # burnished dark edge
			var rough := clampf(0.7 - g * 0.06 + (1.0 - bevel) * -0.15, 0.3, 1.0)
			var height := g * 0.4 - cr * 0.6 + bevel * 0.8
			# the stitch rows: a groove with slanted stitches sitting in it
			for row: float in [0.13, 0.87]:
				var du := absf(u - row) * float(w)
				if du < 9.0:
					var groove := smoothstep(9.0, 4.0, du)
					height -= groove * 0.5
					col = col * (1.0 - groove * 0.35)
					var sv := fposmod(float(y) + (u - row) * float(w) * 0.6, spacing) / spacing
					var st := smoothstep(0.0, 0.1, sv) * smoothstep(0.72, 0.6, sv) * smoothstep(5.0, 2.5, du)
					if st > 0.0:
						col = col.lerp(thread * (0.8 + 0.3 * sin(sv * PI)), st)
						height += st * 0.9
						rough = lerpf(rough, 0.85, st)
			_put(px, i, col, rough)
			hgt[i] = height
	var alb := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	return [alb, _normal_from(hgt, w, h, 3.2)]


# --- staff: dark ash with fibres along v and carved rune columns whose grooves glow ------------
# u runs once round the shaft, v along it. Rune grooves: albedo alpha < 0.1 (the gear shader
# makes them glow); everything else alpha = roughness.

static func _staff() -> Array:
	var w := 512
	var h := 512
	var fib := _noise(w, 32, 0.08, 3, 171)
	var fine := _noise(w, h, 0.2, 2, 173)
	var big := _noise(w, h, 0.006, 3, 175)
	var base := Color(0.21, 0.15, 0.105)
	var runes: Array = []
	for k in 8:
		runes.append(_rune(101 + k * 17))
	var px := PackedByteArray()
	px.resize(w * h * 4)
	var hgt := PackedFloat32Array()
	hgt.resize(w * h)
	for y in h:
		var v := (float(y) + 0.5) / float(h)
		for x in w:
			var i := y * w + x
			var u := (float(x) + 0.5) / float(w)
			var f := _row_lerp(fib, w, 32, x, float(y) / 16.0) / 255.0
			var ff := float(fine[i]) / 255.0
			var b := float(big[i]) / 255.0
			var streak := pow(f, 1.6)
			var col := base * (0.68 + 0.55 * streak + (ff - 0.5) * 0.25 + (b - 0.5) * 0.3)
			var rough := clampf(0.55 + (1.0 - streak) * 0.2 - b * 0.1, 0.3, 1.0)
			var height := streak * 0.7 + ff * 0.2
			# two rune columns (front and back of the shaft), four glyphs each per tile
			var groove := 0.0
			for col_i in 2:
				var cu := 0.5 * float(col_i)                    # front and back of the shaft
				var lu := wrapf(u - cu, -0.5, 0.5) / 0.095     # glyph box half-width in u
				if absf(lu) > 1.3:
					continue
				var slot := int(v * 4.0)
				var lv := (fposmod(v * 4.0, 1.0) - 0.5) / 0.32  # glyph box half-height in v
				if absf(lv) > 1.3:
					continue
				var p := Vector2(lu * 0.5, -lv * 0.5)
				var best := 9.0
				for sg: Array in runes[(slot + col_i * 4) % runes.size()]:
					best = minf(best, _seg_d(p, sg[0], sg[1]))
				groove = maxf(groove, smoothstep(0.13, 0.06, best))
			# a carved ring between glyph rows
			var ring := smoothstep(0.012, 0.004, absf(fposmod(v * 4.0, 1.0)))
			height -= ring * 0.4
			col = col * (1.0 - ring * 0.4)
			if groove > 0.0:
				col = col.lerp(Color(0.05, 0.05, 0.08), groove * 0.85)
				height -= groove * 1.2
				rough = lerpf(rough, 0.04, groove)      # < 0.1: the shader's glow mask
			_put(px, i, col, rough)
			hgt[i] = height
	var alb := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	return [alb, _normal_from(hgt, w, h, 3.0)]
