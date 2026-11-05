extends SceneTree
## Giant-trunk bark (replaces tools/gen_textures.py bark_giant(), whose even sine stripes read as
## corrugated paper): deep vertical fissures between raised, wandering plates, cross-breaks across
## the plates, fine fibre grain, and moss settled in the fissures. Same cold blue-grey night palette
## and the same four maps. Tileable (seamless noise). No numpy needed:
##   godot --headless -s tools/gen_bark_giant.gd   ->  art/textures/bark_giant_{albedo,normal,ao,rough}.png

const SIZE := 1024
const OUT := "res://art/textures/bark_giant_%s.png"


func _seamless(n: FastNoiseLite, w: int, h: int) -> Image:
	var img := n.get_seamless_image(w, h, false, false, 0.2, true)
	img.convert(Image.FORMAT_RF)
	return img


func _noise(type: int, freq: float, seed_v: int, octaves := 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.seed = seed_v
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


func _init() -> void:
	# plates: cellular F2-F1 on a short, wide image stretched 4x tall -> long vertical plates;
	# domain warp makes the fissures wander
	var cells := _noise(FastNoiseLite.TYPE_CELLULAR, 0.022, 11)
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cells.cellular_jitter = 1.0
	cells.domain_warp_enabled = true
	cells.domain_warp_amplitude = 18.0
	cells.domain_warp_frequency = 0.02
	var plate_img := _seamless(cells, SIZE, SIZE / 4)
	plate_img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var plate_id_n := _noise(FastNoiseLite.TYPE_CELLULAR, 0.022, 11)
	plate_id_n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	plate_id_n.domain_warp_enabled = true
	plate_id_n.domain_warp_amplitude = 18.0
	plate_id_n.domain_warp_frequency = 0.02
	var plate_id := _seamless(plate_id_n, SIZE, SIZE / 4)
	plate_id.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	# cross-breaks: thin horizontal cracks
	var breaks_img := _seamless(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 23, 3), SIZE / 8, SIZE)
	breaks_img.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	# fibre grain (stretched tall) and broad tone
	var grain := _seamless(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 31, 4), SIZE, SIZE / 6)
	grain.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	var tone := _seamless(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.004, 41, 4), SIZE, SIZE)
	var moss_n := _seamless(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, 53, 4), SIZE, SIZE)
	var h := PackedFloat32Array()
	h.resize(SIZE * SIZE)
	var crack := PackedFloat32Array()
	crack.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var e := plate_img.get_pixel(x, y).r              # 0 at a fissure, up to ~1 mid-plate
			var fis := 1.0 - _sstep(0.04, 0.24, e)            # fissure mask
			var br := 1.0 - _sstep(0.0, 0.035, absf(breaks_img.get_pixel(x, y).r - 0.5))
			br *= _sstep(0.25, 0.6, e)                         # breaks cross plates, not fissures
			var bulge := sqrt(clampf(e * 3.0, 0.0, 1.0))      # rounded plate faces
			var g := grain.get_pixel(x, y).r
			var pid := plate_id.get_pixel(x, y).r
			var hv := bulge * 0.62 + g * 0.22 + pid * 0.1 - br * 0.22 - fis * 0.3
			h[y * SIZE + x] = hv
			crack[y * SIZE + x] = maxf(fis, br * 0.7)
	var alb := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var ao := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var rough := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var nrm := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var strength := 7.0
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var c := crack[i]
			var hv := h[i]
			var t := tone.get_pixel(x, y).r
			var pid := plate_id.get_pixel(x, y).r
			var m := _sstep(0.52, 0.72, moss_n.get_pixel(x, y).r) * clampf(c * 1.4 + 0.15, 0.0, 1.0)
			# plate faces: cold grey-blue, each plate a touch different; fissures near black
			var lum := (0.07 + hv * 0.3 + (pid - 0.5) * 0.06 + (t - 0.5) * 0.1) * (1.0 - c * 0.85)
			var col := Color(lum * 0.74, lum * 0.84, lum * 1.12)
			col = col.lerp(Color(0.05, 0.24, 0.2), m * 0.85)
			var a := 1.0 - c * 0.7 - (1.0 - clampf(hv * 1.6, 0.0, 1.0)) * 0.2
			col = col * (0.55 + 0.45 * a)
			alb.set_pixel(x, y, Color(col.r, col.g, col.b))
			ao.set_pixel(x, y, Color(a, a, a))
			var r := clampf(0.8 + c * 0.15 - m * 0.3 + (hv - 0.4) * 0.1, 0.0, 1.0)
			rough.set_pixel(x, y, Color(r, r, r))
			var dx := (h[y * SIZE + (x + 1) % SIZE] - h[y * SIZE + (x - 1 + SIZE) % SIZE]) * 0.5 * strength
			var dy := (h[((y + 1) % SIZE) * SIZE + x] - h[((y - 1 + SIZE) % SIZE) * SIZE + x]) * 0.5 * strength
			var n := Vector3(-dx, dy, 1.0).normalized() * 0.5 + Vector3(0.5, 0.5, 0.5)
			nrm.set_pixel(x, y, Color(n.x, n.y, n.z))
	alb.save_png(OUT % "albedo")
	nrm.save_png(OUT % "normal")
	ao.save_png(OUT % "ao")
	rough.save_png(OUT % "rough")
	print("BARK_GIANT written")
	quit()


func _sstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
