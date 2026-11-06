extends SceneTree
## The White Pans' ground layer (biome "salt", core/world/realm/realm_land.gd, world/realm/realm_ground.gdshader).
## Made in-house, seamless, no downloads:
##   art/textures/land_salt_albedo.png   RGB albedo (sRGB), A height
##   art/textures/land_salt_normal.png   RG tilt (x, z, 0.5 = flat), B roughness, A ambient occlusion
## A salt crust: polygonal desiccation plates (cellular noise) with raised, crumbled edges and dark cracks
## between them, a fine crystalline grit, pale pink-grey mineral staining in broad drifts, a few bright
## crystal glints. Same channel layout as tools/realm_land_textures.gd's layers.
##   godot --headless --path . -s tools/realm_salt_texture.gd [-- --size=1024]
##   godot --headless --path . --import

const OUT_ALB := "res://art/textures/land_salt_albedo.png"
const OUT_NRM := "res://art/textures/land_salt_normal.png"

var S := 1024


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			S = int(a.trim_prefix("--size="))
	var t0 := Time.get_ticks_msec()
	# plates: cellular edges (F2 - F1) -> 0 at the cracks, 1 inside a plate
	var cell: PackedFloat32Array = _voronoi(11, 7701, 0.3)[1]                 # F2 - F1, in cell units
	var cell2: PackedFloat32Array = _voronoi(27, 7702, 0.2)[1]               # smaller plates in the large
	var warp := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 7703, 3, 0)
	var grit := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.31, 7704, 2, 0)
	var grit2 := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.9, 7705, 1, 0)
	var stain := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, 7706, 4, 0)
	var puff := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 7707, 3, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7708
	var n := S * S
	var height := PackedFloat32Array()
	height.resize(n)
	var alb := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var rough := PackedFloat32Array()
	rough.resize(n)
	var ao := PackedFloat32Array()
	ao.resize(n)
	for i in n:
		var c1 := _ss(0.015, 0.09, cell[i])           # plate vs crack (large plates)
		var c2 := _ss(0.012, 0.08, cell2[i])
		var plate := c1 * 0.8 + c2 * 0.2
		# the plate's edge lifts and curls (a crust that has dried and buckled)
		var lip := _ss(0.22, 0.4, cell[i]) * (1.0 - _ss(0.4, 0.8, cell[i])) * 0.35
		var h := plate * 0.55 + lip + puff[i] * 0.25 + grit[i] * 0.06 + grit2[i] * 0.03
		height[i] = h
		var base := Color(0.80, 0.79, 0.74)
		var tone := 0.9 + 0.1 * grit[i] + 0.06 * grit2[i]
		var col := base * tone
		# broad mineral staining: grey-pink and a little ochre
		var st := stain[i]
		col = col.lerp(Color(0.84, 0.72, 0.68), _ss(0.55, 0.8, st) * 0.55)
		col = col.lerp(Color(0.70, 0.72, 0.74), _ss(0.45, 0.2, st) * 0.4)
		# cracks: dark, damp earth showing
		col = col.lerp(Color(0.36, 0.33, 0.30), (1.0 - plate) * 0.7)
		col *= 0.9 + 0.1 * plate
		alb.set_pixel(i % S, i / S, Color(col.r, col.g, col.b, clampf(h, 0.0, 1.0)))
		rough[i] = lerpf(0.9, 0.5, plate) - grit2[i] * 0.1
		ao[i] = lerpf(0.45, 1.0, _ss(0.0, 0.35, plate))
	# crystal glints
	for k in S * S / 900:
		var gx := rng.randi_range(0, S - 1)
		var gy := rng.randi_range(0, S - 1)
		var c := alb.get_pixel(gx, gy)
		alb.set_pixel(gx, gy, Color(minf(c.r * 1.2, 1.0), minf(c.g * 1.2, 1.0), minf(c.b * 1.2, 1.0), c.a))
		rough[gy * S + gx] = 0.25
	var nrm := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var m := S - 1
	for y in S:
		for x in S:
			var hl := height[y * S + ((x - 1) & m)]
			var hr := height[y * S + ((x + 1) & m)]
			var hd := height[((y - 1) & m) * S + x]
			var hu := height[((y + 1) & m) * S + x]
			var tx := clampf(0.5 + (hl - hr) * 1.6, 0.0, 1.0)
			var tz := clampf(0.5 + (hd - hu) * 1.6, 0.0, 1.0)
			var i := y * S + x
			nrm.set_pixel(x, y, Color(tx, tz, clampf(rough[i], 0.0, 1.0), clampf(ao[i], 0.0, 1.0)))
	alb.save_png(ProjectSettings.globalize_path(OUT_ALB))
	nrm.save_png(ProjectSettings.globalize_path(OUT_NRM))
	print("SALT TEXTURE %dx%d in %d ms" % [S, S, Time.get_ticks_msec() - t0])
	quit()


## A seamless noise image as floats 0..1. `ret`: for cellular, 0 = F1 distance, 1 = F2 - F1.
func _noise(type: int, freq: float, seed_v: int, oct: int, ret: int) -> PackedFloat32Array:
	var nz := FastNoiseLite.new()
	nz.noise_type = type
	nz.frequency = freq * 1024.0 / float(S)
	nz.seed = seed_v
	if type == FastNoiseLite.TYPE_CELLULAR:
		nz.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB if ret == 1 else FastNoiseLite.RETURN_DISTANCE
		nz.cellular_jitter = 0.9
	else:
		nz.fractal_type = FastNoiseLite.FRACTAL_FBM if oct > 1 else FastNoiseLite.FRACTAL_NONE
		nz.fractal_octaves = oct
	var img := nz.get_seamless_image(S, S, false, false, 0.1, true)
	img.convert(Image.FORMAT_RF)
	return img.get_data().to_float32_array()


## Seamless Voronoi on a wrapped jittered grid of g x g cells, domain-warped. Returns [F1, F2 - F1].
func _voronoi(g: int, seed_v: int, warp: float) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var px := PackedFloat32Array()
	var pz := PackedFloat32Array()
	for k in g * g:
		px.append(r.randf())
		pz.append(r.randf())
	var wx := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, seed_v + 5, 3, 0)
	var wz := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, seed_v + 6, 3, 0)
	var f1 := PackedFloat32Array()
	f1.resize(S * S)
	var f2 := PackedFloat32Array()
	f2.resize(S * S)
	var cs := float(S) / float(g)
	for y in S:
		for x in S:
			var i := y * S + x
			var fx := (float(x) + (wx[i] - 0.5) * warp * cs) / cs
			var fy := (float(y) + (wz[i] - 0.5) * warp * cs) / cs
			var cx := floori(fx)
			var cy := floori(fy)
			var d1 := 9.0
			var d2 := 9.0
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
					elif d < d2:
						d2 = d
			f1[i] = d1
			f2[i] = d2 - d1
	return [f1, f2]


static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
