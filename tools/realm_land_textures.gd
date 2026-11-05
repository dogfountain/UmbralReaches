extends SceneTree
## Ground layers for the Realm terrain (core/world/realm/realm_land.gd), as two texture arrays:
##   art/textures/land_albedo.png  RGB albedo (sRGB), A height      (N layers stacked vertically)
##   art/textures/land_normal.png  RG normal (x, z tilt, 0.5 = flat), B roughness, A ambient occlusion
## Layers (keep in step with world/realm/realm_ground.gdshader):
##   0 meadow grass-dirt  1 heath  2 forest loam / leaf litter  3 fen mud  4 ash / basalt grit
##   5 crag scree  6 ruin flagstone  7 worn path dirt  8 cliff rock (triplanar on steep slopes)
## All tileable (seamless noise, wrapped stamping). No numpy/PIL needed:
##   godot --headless --path . -s tools/realm_land_textures.gd [-- --size=512]
##   godot --headless --path . --import          (imports them as 2D arrays; .import files written here)

const LAYERS := 9
const OUT_ALB := "res://art/textures/land_albedo.png"
const OUT_NRM := "res://art/textures/land_normal.png"

var S := 1024
var M := 1023
var rng := RandomNumberGenerator.new()


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			S = int(a.trim_prefix("--size="))
	M = S - 1
	var t0 := Time.get_ticks_msec()
	var alb := Image.create(S, S * LAYERS, false, Image.FORMAT_RGBA8)
	var nrm := Image.create(S, S * LAYERS, false, Image.FORMAT_RGBA8)
	var makers := [_meadow, _heath, _loam, _mud, _ash, _scree, _flag, _path, _cliff]
	for li in LAYERS:
		rng.seed = 1000 + li * 77
		var L: Dictionary = makers[li].call()
		_emit(L, alb, nrm, li)
		print("layer %d done (%d ms)" % [li, Time.get_ticks_msec() - t0])
	alb.save_png(ProjectSettings.globalize_path(OUT_ALB))
	nrm.save_png(ProjectSettings.globalize_path(OUT_NRM))
	_import_file(OUT_ALB)
	_import_file(OUT_NRM)
	print("LAND TEXTURES %dx%d x%d in %d ms" % [S, S, LAYERS, Time.get_ticks_msec() - t0])
	quit()


func _import_file(path: String) -> void:
	if FileAccess.file_exists(path + ".import"):
		return                      # keep the uid; Godot reimports the changed png itself
	var f := FileAccess.open(ProjectSettings.globalize_path(path + ".import"), FileAccess.WRITE)
	f.store_string("""[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[deps]

source_file="%s"

[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=1
slices/vertical=%d
""" % [path, LAYERS])


# ---------------------------------------------------------------- helpers

func _noise(freq: float, seed_v: int, oct := 4, type := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> PackedFloat32Array:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq * 1024.0 / float(S)
	n.seed = seed_v
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if oct > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = oct
	var img := n.get_seamless_image(S, S, false, false, 0.1, true)
	img.convert(Image.FORMAT_RF)
	return img.get_data().to_float32_array()


## Seamless Voronoi on a wrapped jittered grid of `g` x `g` cells, optionally domain-warped.
## Returns [F1, F2 - F1, cell value 0..1], distances in cell units.
func _voronoi(g: int, seed_v: int, warp := 0.0) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var px := PackedFloat32Array()
	var pz := PackedFloat32Array()
	var pv := PackedFloat32Array()
	for k in g * g:
		px.append(r.randf())
		pz.append(r.randf())
		pv.append(r.randf())
	var wx := _noise(0.006, seed_v + 5, 3) if warp > 0.0 else PackedFloat32Array()
	var wz := _noise(0.006, seed_v + 6, 3) if warp > 0.0 else PackedFloat32Array()
	var f1 := PackedFloat32Array()
	f1.resize(S * S)
	var f2 := PackedFloat32Array()
	f2.resize(S * S)
	var cv := PackedFloat32Array()
	cv.resize(S * S)
	var cs := float(S) / float(g)
	for y in S:
		for x in S:
			var i := y * S + x
			var fx := float(x)
			var fy := float(y)
			if warp > 0.0:
				fx += (wx[i] - 0.5) * warp * cs
				fy += (wz[i] - 0.5) * warp * cs
			fx /= cs
			fy /= cs
			var cx := floori(fx)
			var cy := floori(fy)
			var d1 := 9.0
			var d2 := 9.0
			var v1 := 0.0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := cx + ox
					var gy := cy + oy
					var k := posmod(gy, g) * g + posmod(gx, g)
					var dx := float(gx) + px[k] - fx
					var dy := float(gy) + pz[k] - fy
					var d := sqrt(dx * dx + dy * dy)
					if d < d1:
						d2 = d1
						d1 = d
						v1 = pv[k]
					elif d < d2:
						d2 = d
			f1[i] = d1
			f2[i] = d2 - d1
			cv[i] = v1
	return [f1, f2, cv]


func _new_layer() -> Dictionary:
	var h := PackedFloat32Array()
	h.resize(S * S)
	var c := PackedColorArray()
	c.resize(S * S)
	var r := PackedFloat32Array()
	r.resize(S * S)
	r.fill(0.9)
	return {"h": h, "c": c, "r": r, "ns": 6.0}


static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Wrap-around box blur (separable, sliding sum).
func _blur(src: PackedFloat32Array, rad: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(S * S)
	var out := PackedFloat32Array()
	out.resize(S * S)
	var inv := 1.0 / float(2 * rad + 1)
	for y in S:
		var row := y * S
		var acc := 0.0
		for k in range(-rad, rad + 1):
			acc += src[row + (k & M)]
		for x in S:
			tmp[row + x] = acc * inv
			acc += src[row + ((x + rad + 1) & M)] - src[row + ((x - rad) & M)]
	for x in S:
		var acc := 0.0
		for k in range(-rad, rad + 1):
			acc += tmp[(k & M) * S + x]
		for y in S:
			out[y * S + x] = acc * inv
			acc += tmp[((y + rad + 1) & M) * S + x] - tmp[((y - rad) & M) * S + x]
	return out


## A stroke (blade, twig, reed) into height + colour, painter's order (later strokes lie on top).
func _stroke(L: Dictionary, x0: float, y0: float, ang: float, length: float, width: float, col: Color, h0: float, h1: float) -> void:
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var dx := cos(ang)
	var dy := sin(ang)
	var steps := int(length)
	var hw := width * 0.5
	for s in steps:
		var t := float(s) / float(maxi(steps, 1))
		var w := hw * (1.0 - t * 0.7)
		var px := x0 + dx * s
		var py := y0 + dy * s
		var hv := lerpf(h0, h1, t)
		var cc := col.lerp(col * 1.25, t)
		var iw := ceili(w)
		for o in range(-iw, iw + 1):
			var qx := int(px - dy * o) & M
			var qy := int(py + dx * o) & M
			var i := qy * S + qx
			var e := hv - absf(float(o)) / maxf(w, 0.5) * 0.08
			if e > h[i]:
				h[i] = e
				c[i] = cc


## A filled ellipse (leaf, pebble) with a domed top; `vein` darkens the long axis.
func _blob(L: Dictionary, cx: float, cy: float, ang: float, a: float, b: float, col: Color, base: float, dome: float, vein := 0.0, rough := -1.0) -> void:
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var r: PackedFloat32Array = L.r
	var ca := cos(ang)
	var sa := sin(ang)
	var R := ceili(maxf(a, b))
	for oy in range(-R, R + 1):
		for ox in range(-R, R + 1):
			var u := (ox * ca + oy * sa) / a
			var v := (-ox * sa + oy * ca) / b
			var d := u * u + v * v
			if d > 1.0:
				continue
			var i := ((int(cy) + oy) & M) * S + ((int(cx) + ox) & M)
			var e := base + dome * sqrt(1.0 - d)
			if e > h[i]:
				h[i] = e
				var k := col * (0.85 + 0.15 * sqrt(1.0 - d))
				if vein > 0.0 and absf(v) < 0.09 and absf(u) < 0.95:
					k = k * (1.0 - vein)
				k.a = 1.0
				c[i] = k
				if rough >= 0.0:
					r[i] = rough


func _pal(cols: Array, t: float) -> Color:
	t = clampf(t, 0.0, 0.999) * float(cols.size() - 1)
	var i := int(t)
	return (cols[i] as Color).lerp(cols[i + 1] as Color, t - float(i))


## Height -> normal (wrap), cavity AO, and pack both images for layer `li`.
func _emit(L: Dictionary, alb: Image, nrm: Image, li: int) -> void:
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var r: PackedFloat32Array = L.r
	var ns: float = L.ns
	var lo := INF
	var hi := -INF
	for v in h:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span := maxf(hi - lo, 0.0001)
	var blur := _blur(h, maxi(4, S / 64))
	var ab := PackedByteArray()
	ab.resize(S * S * 4)
	var nb := PackedByteArray()
	nb.resize(S * S * 4)
	var k := ns * float(S) / 1024.0
	for y in S:
		var ym := ((y - 1) & M) * S
		var yp := ((y + 1) & M) * S
		var row := y * S
		for x in S:
			var i := row + x
			var gx := (h[row + ((x - 1) & M)] - h[row + ((x + 1) & M)]) * k
			var gz := (h[ym + x] - h[yp + x]) * k
			var n := Vector3(gx, 1.0, gz).normalized()
			var cav := clampf((h[i] - blur[i]) / span * 3.0 + 0.5, 0.0, 1.0)
			var ao := lerpf(0.45, 1.0, _ss(0.0, 0.62, cav))
			var col := c[i]
			var o := i * 4
			ab[o] = int(clampf(col.r, 0.0, 1.0) * 255.0)
			ab[o + 1] = int(clampf(col.g, 0.0, 1.0) * 255.0)
			ab[o + 2] = int(clampf(col.b, 0.0, 1.0) * 255.0)
			ab[o + 3] = int(clampf((h[i] - lo) / span, 0.0, 1.0) * 255.0)
			nb[o] = int(clampf(n.x * 0.5 + 0.5, 0.0, 1.0) * 255.0)
			nb[o + 1] = int(clampf(n.z * 0.5 + 0.5, 0.0, 1.0) * 255.0)
			nb[o + 2] = int(clampf(r[i], 0.0, 1.0) * 255.0)
			nb[o + 3] = int(ao * 255.0)
	alb.blit_rect(Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, ab), Rect2i(0, 0, S, S), Vector2i(0, li * S))
	nrm.blit_rect(Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, nb), Rect2i(0, 0, S, S), Vector2i(0, li * S))


func _soil(L: Dictionary, cols: Array, seed_v: int, amp := 0.12, freq := 0.012) -> void:
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var big := _noise(freq, seed_v, 5)
	var fine := _noise(0.09, seed_v + 1, 3)
	var grit := _noise(0.45, seed_v + 2, 1, FastNoiseLite.TYPE_VALUE)
	for i in S * S:
		h[i] = big[i] * amp + fine[i] * amp * 0.35 + grit[i] * 0.025
		var col := _pal(cols, big[i] * 0.7 + fine[i] * 0.3)
		c[i] = col * (0.86 + grit[i] * 0.28)


# ---------------------------------------------------------------- layers

func _meadow() -> Dictionary:
	var L := _new_layer()
	_soil(L, [Color(0.17, 0.13, 0.09), Color(0.26, 0.2, 0.14), Color(0.31, 0.25, 0.17)], 11)
	var cover := _noise(0.006, 12, 4)
	var tint := _noise(0.01, 13, 3)
	var greens := [Color(0.09, 0.17, 0.09), Color(0.13, 0.25, 0.12), Color(0.2, 0.31, 0.14), Color(0.3, 0.34, 0.17)]
	var n := int(36000.0 * float(S * S) / 1048576.0)
	for b in n:
		var x := rng.randf() * S
		var y := rng.randf() * S
		var i := (int(y) & M) * S + (int(x) & M)
		if rng.randf() > _ss(0.3, 0.55, cover[i]) + 0.12:
			continue
		var col := _pal(greens, tint[i] * 0.75 + rng.randf() * 0.3) * rng.randf_range(0.75, 1.15)
		_stroke(L, x, y, rng.randf() * TAU, rng.randf_range(10, 34) * S / 1024.0, rng.randf_range(2.0, 3.6) * S / 1024.0, col, 0.18 + rng.randf() * 0.1, 0.32 + rng.randf() * 0.22)
	# clover / small leaves
	for b in int(900.0 * float(S * S) / 1048576.0):
		_blob(L, rng.randf() * S, rng.randf() * S, rng.randf() * TAU, 5.0 * S / 1024.0, 4.0 * S / 1024.0, Color(0.16, 0.25, 0.1), 0.3, 0.12)
	L.ns = 5.0
	return L


func _heath() -> Dictionary:
	var L := _new_layer()
	_soil(L, [Color(0.12, 0.09, 0.07), Color(0.19, 0.14, 0.1), Color(0.24, 0.19, 0.13)], 21)
	var clump: PackedFloat32Array = _voronoi(12, 22, 0.6)[0]
	var florets := [Color(0.27, 0.15, 0.22), Color(0.33, 0.2, 0.27), Color(0.3, 0.17, 0.11), Color(0.16, 0.2, 0.11), Color(0.21, 0.24, 0.13)]
	var n := int(70000.0 * float(S * S) / 1048576.0)
	for b in n:
		var x := rng.randf() * S
		var y := rng.randf() * S
		var i := (int(y) & M) * S + (int(x) & M)
		var inside := 1.0 - _ss(0.2, 0.6, clump[i])
		if rng.randf() > inside:
			continue
		var col := (florets[rng.randi() % florets.size()] as Color) * rng.randf_range(0.7, 1.2)
		var rad := rng.randf_range(1.5, 3.4) * S / 1024.0
		_blob(L, x, y, 0.0, rad, rad, col, 0.2 + inside * 0.45 + rng.randf() * 0.08, 0.08)
	for b in int(9000.0 * float(S * S) / 1048576.0):
		var col := Color(0.44, 0.38, 0.24) * rng.randf_range(0.6, 1.1)
		_stroke(L, rng.randf() * S, rng.randf() * S, rng.randf() * TAU, rng.randf_range(16, 44) * S / 1024.0, 2.0 * S / 1024.0, col, 0.15, 0.45)
	L.ns = 5.0
	return L


func _loam() -> Dictionary:
	var L := _new_layer()
	_soil(L, [Color(0.07, 0.055, 0.04), Color(0.12, 0.09, 0.06), Color(0.16, 0.12, 0.08)], 31)
	var moss := _noise(0.008, 32, 4)
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	for i in S * S:
		var m := _ss(0.55, 0.7, moss[i])
		if m > 0.0:
			c[i] = c[i].lerp(Color(0.1, 0.16, 0.06) * (0.8 + moss[i] * 0.5), m)
			h[i] += m * 0.12
	var leaves := [Color(0.3, 0.17, 0.08), Color(0.42, 0.27, 0.11), Color(0.2, 0.12, 0.07), Color(0.33, 0.28, 0.22), Color(0.5, 0.36, 0.16), Color(0.24, 0.2, 0.1)]
	var n := int(8000.0 * float(S * S) / 1048576.0)
	for b in n:
		var x := rng.randf() * S
		var y := rng.randf() * S
		var i := (int(y) & M) * S + (int(x) & M)
		if moss[i] > 0.66 and rng.randf() < 0.85:
			continue
		var a := rng.randf_range(10, 22) * S / 1024.0
		var col := (leaves[rng.randi() % leaves.size()] as Color) * rng.randf_range(0.7, 1.15)
		_blob(L, x, y, rng.randf() * TAU, a, a * rng.randf_range(0.4, 0.62), col, 0.12 + float(b) / float(n) * 0.35, 0.06, 0.35)
	for b in int(260.0 * float(S * S) / 1048576.0):
		var col := Color(0.24, 0.2, 0.16) * rng.randf_range(0.7, 1.2)
		var x := rng.randf() * S
		var y := rng.randf() * S
		var ang := rng.randf() * TAU
		var len := rng.randf_range(50, 160) * S / 1024.0
		_stroke(L, x, y, ang, len, rng.randf_range(3.0, 6.0) * S / 1024.0, col, 0.55, 0.6)
		if rng.randf() < 0.5:
			_stroke(L, x + cos(ang) * len * 0.5, y + sin(ang) * len * 0.5, ang + rng.randf_range(-0.8, 0.8), len * 0.4, 3.0 * S / 1024.0, col, 0.56, 0.6)
	L.ns = 5.0
	return L


func _mud() -> Dictionary:
	var L := _new_layer()
	_soil(L, [Color(0.06, 0.05, 0.04), Color(0.1, 0.085, 0.065), Color(0.17, 0.15, 0.12)], 41, 0.2, 0.008)
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var r: PackedFloat32Array = L.r
	var wet := _noise(0.007, 42, 4)
	var pock: PackedFloat32Array = _voronoi(60, 43)[0]
	for i in S * S:
		var w := _ss(0.42, 0.6, wet[i])
		h[i] = h[i] * (1.0 - w * 0.7) - w * 0.08 - (1.0 - _ss(0.0, 0.3, pock[i])) * 0.03
		c[i] = c[i].lerp(Color(0.04, 0.045, 0.035), w * 0.75)
		c[i] = c[i].lerp(Color(0.08, 0.11, 0.05), w * _ss(0.6, 0.8, wet[i]) * 0.6)
		r[i] = lerpf(0.82, 0.12, w)
	for b in int(2600.0 * float(S * S) / 1048576.0):
		var col := Color(0.36, 0.32, 0.22) * rng.randf_range(0.5, 1.0)
		_stroke(L, rng.randf() * S, rng.randf() * S, rng.randf() * TAU, rng.randf_range(30, 110) * S / 1024.0, rng.randf_range(2.0, 3.5) * S / 1024.0, col, 0.1, 0.14)
	L.ns = 4.0
	return L


func _ash() -> Dictionary:
	var L := _new_layer()
	_soil(L, [Color(0.07, 0.07, 0.075), Color(0.12, 0.115, 0.115), Color(0.16, 0.15, 0.15)], 51, 0.1)
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var r: PackedFloat32Array = L.r
	var plates: PackedFloat32Array = _voronoi(9, 52, 0.5)[1]
	var dust := _noise(0.01, 53, 4)
	for i in S * S:
		var crack := 1.0 - _ss(0.015, 0.07, plates[i])
		h[i] += _ss(0.0, 0.3, plates[i]) * 0.25 - crack * 0.12
		var d := _ss(0.45, 0.7, dust[i]) * (0.4 + crack * 0.6)
		c[i] = c[i].lerp(Color(0.33, 0.32, 0.31), d * 0.8)
		c[i] = c[i] * (1.0 - crack * 0.5)
		r[i] = lerpf(0.78, 0.95, d)
	for b in int(5000.0 * float(S * S) / 1048576.0):
		var a := rng.randf_range(2.5, 7.0) * S / 1024.0
		_blob(L, rng.randf() * S, rng.randf() * S, rng.randf() * TAU, a, a * rng.randf_range(0.6, 1.0), Color(0.09, 0.09, 0.1) * rng.randf_range(0.7, 1.6), 0.2, 0.12, 0.0, 0.6)
	L.ns = 6.0
	return L


func _scree() -> Dictionary:
	var L := _new_layer()
	_soil(L, [Color(0.08, 0.075, 0.07), Color(0.13, 0.12, 0.11)], 61)
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var r: PackedFloat32Array = L.r
	var vor := _voronoi(18, 62, 0.25)
	var dist: PackedFloat32Array = vor[1]
	var cell: PackedFloat32Array = vor[2]
	var lich := _noise(0.05, 63, 3)
	var grain := _noise(0.3, 64, 2)
	for i in S * S:
		var e := dist[i]
		var stone := _ss(0.03, 0.12, e)
		if stone <= 0.0:
			continue
		var top := sqrt(clampf(e * 2.0, 0.0, 1.0))
		h[i] = maxf(h[i], 0.1 + top * 0.6 * (0.7 + cell[i] * 0.6) + grain[i] * 0.04)
		var g := 0.16 + cell[i] * 0.15
		var col := Color(g, g * 1.02, g * 1.1) * (0.85 + grain[i] * 0.3)
		col = col.lerp(Color(0.42, 0.44, 0.3), _ss(0.68, 0.78, lich[i]) * 0.7)
		c[i] = c[i].lerp(col, stone)
		r[i] = lerpf(0.9, 0.7, stone)
	L.ns = 7.0
	return L


func _flag() -> Dictionary:
	var L := _new_layer()
	_soil(L, [Color(0.08, 0.09, 0.05), Color(0.12, 0.13, 0.07)], 71)
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var r: PackedFloat32Array = L.r
	var wear := _noise(0.02, 72, 4)
	var grain := _noise(0.2, 73, 3)
	var cracks: PackedFloat32Array = _voronoi(6, 74, 0.8)[1]
	var crack_on := _noise(0.012, 75, 3)
	# rows summing to S, slabs per row summing to S: seamless by construction
	var rows: Array = []
	var acc := 0
	while acc < S:
		var rh := int(rng.randf_range(0.17, 0.3) * S)
		if S - acc - rh < int(0.15 * S):
			rh = S - acc
		rows.append([acc, rh])
		acc += rh
	var gap := 7.0 * S / 1024.0
	for row: Array in rows:
		var y0: int = row[0]
		var rh: int = row[1]
		var off := rng.randi() % S
		var xs := 0
		while xs < S:
			var sw := int(rng.randf_range(0.2, 0.42) * S)
			if S - xs - sw < int(0.18 * S):
				sw = S - xs
			var tone := rng.randf_range(0.7, 1.1)
			var tilt := Vector2(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04))
			var base := Color(0.3, 0.29, 0.27).lerp(Color(0.34, 0.31, 0.25), rng.randf()) * tone
			for yy in rh:
				for xx in sw:
					var ed := minf(minf(float(xx), float(sw - 1 - xx)), minf(float(yy), float(rh - 1 - yy)))
					var i := ((y0 + yy) & M) * S + ((xs + xx + off) & M)
					var wob := grain[i] * 5.0 * S / 1024.0
					var e := ed - gap - wob
					if e <= 0.0:
						continue
					var bev := _ss(0.0, 10.0 * S / 1024.0, e)
					var cr := (1.0 - _ss(0.006, 0.02, cracks[i])) * _ss(0.5, 0.58, crack_on[i])
					var hv := 0.35 + bev * 0.35 + (tilt.x * xx + tilt.y * yy) / float(S) * 2.0 + grain[i] * 0.05 - cr * 0.2 - wear[i] * 0.1
					h[i] = hv
					var col := base * (0.8 + grain[i] * 0.35) * (1.0 - cr * 0.55)
					col = col.lerp(Color(0.16, 0.2, 0.1), _ss(0.62, 0.75, wear[i]) * 0.6)
					c[i] = col
					r[i] = 0.78
			xs += sw
	L.ns = 6.0
	return L


func _path() -> Dictionary:
	var L := _new_layer()
	_soil(L, [Color(0.19, 0.155, 0.115), Color(0.26, 0.21, 0.155), Color(0.31, 0.26, 0.2)], 81, 0.07, 0.01)
	for b in int(1800.0 * float(S * S) / 1048576.0):
		var a := rng.randf_range(3.0, 11.0) * S / 1024.0
		var g := rng.randf_range(0.18, 0.36)
		_blob(L, rng.randf() * S, rng.randf() * S, rng.randf() * TAU, a, a * rng.randf_range(0.55, 0.95), Color(g, g * 0.97, g * 0.93), 0.06, 0.08, 0.0, 0.72)
	L.ns = 5.0
	return L


func _cliff() -> Dictionary:
	var L := _new_layer()
	var h: PackedFloat32Array = L.h
	var c: PackedColorArray = L.c
	var r: PackedFloat32Array = L.r
	var warp := _noise(0.004, 91, 3)
	var strata := _noise(0.02, 92, 5)
	var blocks: PackedFloat32Array = _voronoi(5, 93, 0.8)[1]
	var lich := _noise(0.03, 94, 4)
	var grain := _noise(0.25, 95, 2)
	for y in S:
		for x in S:
			var i := y * S + x
			var band := sin((float(y) / S * 6.0 + warp[i] * 2.0) * TAU) * 0.5 + 0.5
			band = band * band
			var crack := (1.0 - _ss(0.01, 0.05, blocks[i])) * _ss(0.35, 0.6, strata[i])
			var hv := strata[i] * 0.45 + band * 0.3 + _ss(0.0, 0.25, blocks[i]) * 0.3 - crack * 0.12 + grain[i] * 0.06
			h[i] = hv
			var g := 0.17 + strata[i] * 0.12 + band * 0.1
			var col := Color(g, g * 1.01, g * 1.08) * (0.85 + grain[i] * 0.3) * (1.0 - crack * 0.3)
			col = col.lerp(Color(0.38, 0.42, 0.3), _ss(0.64, 0.74, lich[i]) * 0.55)
			c[i] = col
			r[i] = 0.82
	L.ns = 8.0
	return L
