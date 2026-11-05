extends SceneTree
## RockKit rock textures (assets module, docs/REALM_PLAN.md). Neutral grey granite-like stone that
## rock_kit.gdshader tints per style: mottled macro tone, granular grain with dark/pale mineral
## flecks, two sets of wandering fractures, tiny pits. Four maps, tileable (seamless noise):
##   godot --headless -s tools/realm_assets_textures.gd
##   -> art/textures/rockkit_{albedo,normal,rough,mask}.png
## mask: R = fracture line (ash style glows here), G = lichen patches, B = macro tone.

const SIZE := 1024
const OUT := "res://art/textures/rockkit_%s.png"


func _seamless(n: FastNoiseLite, w: int, h: int) -> Image:
	var img := n.get_seamless_image(w, h, false, false, 0.2, true)
	img.convert(Image.FORMAT_RF)
	if w != SIZE or h != SIZE:
		img.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	return img


func _noise(type: int, freq: float, seed_v: int, octaves := 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.seed = seed_v
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


func _cells(freq: float, seed_v: int, ret: int, warp := 0.0) -> FastNoiseLite:
	var c := _noise(FastNoiseLite.TYPE_CELLULAR, freq, seed_v)
	c.cellular_return_type = ret
	c.cellular_jitter = 1.0
	if warp > 0.0:
		c.domain_warp_enabled = true
		c.domain_warp_amplitude = warp
		c.domain_warp_frequency = freq * 1.6
	return c


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var macro := _seamless(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.004, 101, 5), SIZE, SIZE)
	var warm := _seamless(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, 103, 3), SIZE, SIZE)
	var grain := _seamless(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.09, 107, 3), SIZE, SIZE)
	var fleck := _seamless(_cells(0.11, 109, FastNoiseLite.RETURN_CELL_VALUE), SIZE, SIZE)
	var crack_a := _seamless(_cells(0.0055, 113, FastNoiseLite.RETURN_DISTANCE2_SUB, 26.0), SIZE, SIZE)
	var crack_b := _seamless(_cells(0.016, 127, FastNoiseLite.RETURN_DISTANCE2_SUB, 9.0), SIZE, SIZE)
	var pits := _seamless(_cells(0.05, 131, FastNoiseLite.RETURN_DISTANCE), SIZE, SIZE)
	var lich_c := _seamless(_cells(0.02, 137, FastNoiseLite.RETURN_DISTANCE, 6.0), SIZE, SIZE)
	var lich_n := _seamless(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 139, 3), SIZE, SIZE)
	print("noise ", Time.get_ticks_msec() - t0, " ms")
	var h := PackedFloat32Array()
	h.resize(SIZE * SIZE)
	var cr := PackedFloat32Array()
	cr.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var ea := crack_a.get_pixel(x, y).r
			var eb := crack_b.get_pixel(x, y).r
			var ca := 1.0 - _sstep(0.0, 0.035, ea)
			var cb := (1.0 - _sstep(0.0, 0.03, eb)) * 0.55
			var pit := 1.0 - _sstep(0.0, 0.07, pits.get_pixel(x, y).r)
			var m := macro.get_pixel(x, y).r
			var g := grain.get_pixel(x, y).r
			h[i] = m * 0.55 + g * 0.3 - ca * 0.45 - cb * 0.22 - pit * 0.12
			cr[i] = maxf(ca, cb)
	var alb := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var rough := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var nrm := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var msk := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var strength := 9.0
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var m := macro.get_pixel(x, y).r
			var g := grain.get_pixel(x, y).r
			var f := fleck.get_pixel(x, y).r
			var c := cr[i]
			var lum := 0.44 + (m - 0.5) * 0.3 + (g - 0.5) * 0.14
			# mineral flecks: a few dark (hornblende), a few pale (feldspar)
			if f < 0.12:
				lum *= 0.62
			elif f > 0.9:
				lum = lerpf(lum, 0.72, 0.6)
			lum *= 1.0 - c * 0.6
			var wv := warm.get_pixel(x, y).r - 0.5
			var col := Color(lum * (1.0 + wv * 0.14), lum * (1.0 + wv * 0.03), lum * (1.0 - wv * 0.12))
			alb.set_pixel(x, y, col)
			var r := clampf(0.72 + (g - 0.5) * 0.2 + c * 0.2 - (0.22 if f > 0.9 else 0.0), 0.0, 1.0)
			rough.set_pixel(x, y, Color(r, r, r))
			var dx := (h[y * SIZE + (x + 1) % SIZE] - h[y * SIZE + (x - 1 + SIZE) % SIZE]) * 0.5 * strength
			var dy := (h[((y + 1) % SIZE) * SIZE + x] - h[((y - 1 + SIZE) % SIZE) * SIZE + x]) * 0.5 * strength
			var n := Vector3(-dx, dy, 1.0).normalized() * 0.5 + Vector3(0.5, 0.5, 0.5)
			nrm.set_pixel(x, y, Color(n.x, n.y, n.z))
			var ember := 1.0 - _sstep(0.0, 0.07, crack_a.get_pixel(x, y).r)
			var lc := 1.0 - _sstep(0.25, 0.55, lich_c.get_pixel(x, y).r)
			var lichen := clampf(lc * _sstep(0.4, 0.7, lich_n.get_pixel(x, y).r) * 1.3, 0.0, 1.0)
			msk.set_pixel(x, y, Color(ember, lichen, m))
	alb.save_png(OUT % "albedo")
	nrm.save_png(OUT % "normal")
	rough.save_png(OUT % "rough")
	msk.save_png(OUT % "mask")
	print("ROCKKIT textures written in %d ms" % (Time.get_ticks_msec() - t0))
	quit()


func _sstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
