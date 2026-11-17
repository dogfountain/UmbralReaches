extends RefCounted
## The dwarves' material: dwarf.gdshader with two Texture2DArrays of procedural detail maps, one
## layer per DwarfMesh.MAT_* (skin pores and mottling, wool and linen weave, leather grain and
## creases, hair strands, hammered iron, wood grain, foam bubbles, flat eyes, fur clumps).
## Generated with Image + FastNoiseLite (no external tools), tileable, 128 px a layer; the height
## maps become normal maps with Image.bump_map_to_normal_map. The source images are cached through
## GenCache (salted by this file), so after the first run this is a decode, not a generate.
## Load by path: const DwarfLook := preload("res://core/npc/dwarf_look.gd")

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/npc/dwarf_look.gd"
const SHADER_PATH := "res://core/npc/dwarf.gdshader"   ## loaded, not preloaded: a const outlives the renderer at quit
const SIZE := 128
const LAYERS := 10
const LAYER_NAMES := ["skin", "cloth", "linen", "leather", "hair", "metal", "wood", "foam", "eye", "fur"]

static var _mat: ShaderMaterial
static var _mat_out: ShaderMaterial


## Drop the engine resources held in static vars (called when the night is torn down): statics
## outlive the renderer at quit ("RID allocations leaked at exit"). Rebuilt on next use.
static func release() -> void:
	_mat = null
	_mat_out = null


## The same material for people outdoors (Hearthward's villagers): no hearth in the open, so the
## warm bounce is halved (it pushed their cloth toward orange under the grade).
static func material_outdoor() -> ShaderMaterial:
	if _mat_out:
		return _mat_out
	_mat_out = material().duplicate() as ShaderMaterial
	_mat_out.set_shader_parameter("bounce", 0.08)
	_mat_out.set_shader_parameter("moon_rim", 0.35)       # the silhouette of a dark coat on dark ground
	_mat_out.set_shader_parameter("chroma", 0.92)
	_mat_out.set_shader_parameter("skin_chroma", 0.78)    # models pass: less doll-pink
	_mat_out.set_shader_parameter("skin_bounce", 0.09)    # models pass: was 0.2: the self-glow flattened faces to one tone
	_mat_out.set_shader_parameter("skin_back", Vector3(0.22, 0.12, 0.06))
	return _mat_out


static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	var t0 := Time.get_ticks_msec()
	var baked := _baked_material()
	if baked != null:
		_mat = baked
		print("DWARF look ready in %d ms (baked maps)" % (Time.get_ticks_msec() - t0))
		return _mat
	var alb: Array[Image] = []
	var hgt: Array[Image] = []
	var cached: Variant = GenCache.load_var("dwarf_look|%d" % SIZE, SELF)
	if cached is Dictionary and (cached as Dictionary).get("alb", []).size() == LAYERS:
		for b: PackedByteArray in cached["alb"]:
			var im := Image.new()
			im.load_png_from_buffer(b)
			alb.append(im)
		for b: PackedByteArray in cached["hgt"]:
			var im2 := Image.new()
			im2.load_png_from_buffer(b)
			hgt.append(im2)
	else:
		var pa: Array[PackedByteArray] = []
		var ph: Array[PackedByteArray] = []
		for layer in LAYERS:
			var pair := _layer(layer)
			alb.append(pair[0])
			hgt.append(pair[1])
			pa.append((pair[0] as Image).save_png_to_buffer())
			ph.append((pair[1] as Image).save_png_to_buffer())
		GenCache.save_var("dwarf_look|%d" % SIZE, SELF, {"alb": pa, "hgt": ph})
	var nrm: Array[Image] = []
	for i in LAYERS:
		var a: Image = alb[i]
		a.convert(Image.FORMAT_RGBA8)
		a.generate_mipmaps()
		var h: Image = hgt[i].duplicate()
		h.convert(Image.FORMAT_RGBA8)
		h.bump_map_to_normal_map([2.0, 5.0, 3.0, 4.0, 6.0, 2.5, 3.0, 4.0, 0.0, 6.0][i])
		h.generate_mipmaps()
		nrm.append(h)
	var ta := Texture2DArray.new()
	ta.create_from_images(alb)
	var tn := Texture2DArray.new()
	tn.create_from_images(nrm)
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader
	_mat.set_shader_parameter("detail_albedo", ta)
	_mat.set_shader_parameter("detail_normal", tn)
	print("DWARF look ready in %d ms (%s)" % [Time.get_ticks_msec() - t0, "cached" if cached is Dictionary else "generated"])
	return _mat


## art pass: the maps baked by tools/blender/people_textures.py (512 px PBR layers, real normals):
## art/textures/people/people_<layer>_{albedo,normal}.png in DwarfMesh.MAT_* order. Null if any is
## missing (the generated 128 px layers below then stand in).
static func _baked_material() -> ShaderMaterial:
	var alb: Array[Image] = []
	var nrm: Array[Image] = []
	for nm: String in LAYER_NAMES:
		var ta := load("res://art/textures/people/people_%s_albedo.png" % nm) as Texture2D
		var tn := load("res://art/textures/people/people_%s_normal.png" % nm) as Texture2D
		if ta == null or tn == null:
			return null
		var ia := ta.get_image()
		var inn := tn.get_image()
		if ia == null or inn == null:
			return null
		if ia.is_compressed():
			ia.decompress()
		if inn.is_compressed():
			inn.decompress()
		ia.convert(Image.FORMAT_RGBA8)
		inn.convert(Image.FORMAT_RGBA8)
		ia.generate_mipmaps()
		inn.generate_mipmaps()
		alb.append(ia)
		nrm.append(inn)
	var arr_a := Texture2DArray.new()
	arr_a.create_from_images(alb)
	var arr_n := Texture2DArray.new()
	arr_n.create_from_images(nrm)
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH) as Shader
	m.set_shader_parameter("detail_albedo", arr_a)
	m.set_shader_parameter("detail_normal", arr_n)
	return m


static func _noise(seed_v: int, freq: float, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH, octaves := 3) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	return n.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)


static func _cells(seed_v: int, freq: float, ret := FastNoiseLite.RETURN_DISTANCE) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = freq
	n.cellular_return_type = ret
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)


static func _g(im: Image, x: int, y: int) -> float:
	return im.get_pixel(posmod(x, SIZE), posmod(y, SIZE)).r


## [albedo variation RGBA (0.5 neutral, a = roughness variation), height L8]
static func _layer(layer: int) -> Array:
	var alb := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var hgt := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_L8)
	var lo := _noise(11 + layer, 0.02, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var hi := _noise(37 + layer, 0.12, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var cel: Image = null
	match layer:
		0, 3, 5, 7:
			cel = _cells(70 + layer, [0.09, 0, 0, 0.07, 0, 0.05, 0, 0.11][layer] if layer < 8 else 0.08)
		9:
			cel = _cells(79, 0.04, FastNoiseLite.RETURN_CELL_VALUE)
	var s := float(SIZE)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / s
			var v := float(y) / s
			var l := _g(lo, x, y)
			var h1 := _g(hi, x, y)
			var c := Color(0.5, 0.5, 0.5, 0.5)
			var h := 0.5
			match layer:
				0:  # skin: pores (cell centres dip), fine creases, warm mottling and freckles
					var pore := 1.0 - smoothstep(0.0, 0.18, _g(cel, x, y))
					h = 0.55 + (h1 - 0.5) * 0.25 - pore * 0.35
					var mot := (l - 0.5)
					c = Color(0.5 + mot * 0.16 + 0.02, 0.5 + mot * 0.06, 0.5 + mot * 0.02, 0.5 - pore * 0.2)
					if h1 > 0.82:
						c = c.darkened(0.12)   # freckles / blemishes
				1, 2:  # wool / linen: plain weave over-under, thread slubs, fuzz
					var n_t := 16.0 if layer == 1 else 24.0
					var cu := u * n_t
					var cv := v * n_t
					var over := (int(floor(cu)) + int(floor(cv))) % 2 == 0
					var tu := sin(fposmod(cu, 1.0) * PI)
					var tv := sin(fposmod(cv, 1.0) * PI)
					var thread := tv if over else tu
					var slub := (_g(hi, x, 3) - 0.5) * 0.5 if over else (_g(hi, 5, y) - 0.5) * 0.5
					h = 0.2 + 0.6 * thread * (0.85 + slub) + (h1 - 0.5) * 0.15
					var shade := 0.9 + 0.12 * thread + slub * 0.12 + (l - 0.5) * 0.2
					c = Color(0.5 * shade, 0.5 * shade, 0.5 * shade, 0.5 + (1.0 - thread) * 0.2)
				3:  # leather: pebbled grain, creases, scuffs
					var grain := _g(cel, x, y)
					var crease := 1.0 - absf(l - 0.5) * 2.0
					crease = pow(clampf(crease, 0.0, 1.0), 6.0)
					h = 0.4 + grain * 0.35 - crease * 0.35 + (h1 - 0.5) * 0.1
					var scuff := smoothstep(0.7, 0.85, h1)
					var k := 0.86 + grain * 0.22 - crease * 0.2 + scuff * 0.18
					c = Color(0.5 * k, 0.49 * k, 0.47 * k, 0.45 + scuff * 0.3 - grain * 0.1)
				4:  # hair: strands along v (tile is stretched in the shader), light/dark locks
					var sx := _g(hi, x, 0) * 0.7 + _g(lo, x, y) * 0.3
					var sx2 := _g(lo, x * 3, 7)
					var strand := sin((u * 46.0 + sx2 * 6.0) * TAU) * 0.5 + 0.5
					h = 0.25 + strand * 0.5 + (sx - 0.5) * 0.3
					var k2 := 0.75 + strand * 0.3 + (sx - 0.5) * 0.4
					c = Color(0.5 * k2, 0.5 * k2, 0.5 * k2, 0.5 - strand * 0.15)
				5:  # iron: hammer dents, scratches, rust in the low spots
					var dent := _g(cel, x, y)
					var scratch := smoothstep(0.96, 1.0, sin((u * 3.0 + v * 17.0 + l * 4.0) * TAU) * 0.5 + 0.5) * 0.6
					h = 0.3 + dent * 0.5 + scratch * 0.2
					var rust := smoothstep(0.58, 0.75, l) * (1.0 - dent)
					var k3 := 0.9 + dent * 0.15 + scratch * 0.3
					c = Color(0.5 * k3, 0.5 * k3, 0.5 * k3, 0.5 - scratch * 0.3).lerp(Color(0.62, 0.36, 0.2, 0.9), rust * 0.75)
				6:  # wood: grain lines running along v, staves every quarter of the tile
					var gl := sin((u * 9.0 + l * 2.2 + h1 * 0.25) * TAU) * 0.5 + 0.5
					var stave := smoothstep(0.0, 0.025, absf(fposmod(u * 4.0, 1.0) - 0.0)) * smoothstep(0.0, 0.025, absf(1.0 - fposmod(u * 4.0, 1.0)))
					h = 0.35 + gl * 0.3 + (h1 - 0.5) * 0.2 - (1.0 - stave) * 0.35
					var k4 := 0.8 + gl * 0.3 - (1.0 - stave) * 0.4
					c = Color(0.52 * k4, 0.5 * k4, 0.46 * k4, 0.5 + (1.0 - gl) * 0.2)
				7:  # foam: bubbles
					var b := _g(cel, x, y)
					h = 0.3 + smoothstep(0.0, 0.5, b) * 0.6
					c = Color(0.5 - (1.0 - b) * 0.06, 0.5 - (1.0 - b) * 0.06, 0.5 - (1.0 - b) * 0.08, 0.5)
				8:  # eye: flat and clean
					h = 0.5
					c = Color(0.5, 0.5, 0.5, 0.5)
				9:  # fur: clumped locks
					var clump := _g(cel, x, y)
					var st2 := sin((u * 30.0 + clump * 5.0 + l * 3.0) * TAU) * 0.5 + 0.5
					h = 0.2 + st2 * 0.45 + clump * 0.3
					var k5 := 0.7 + st2 * 0.3 + (clump - 0.5) * 0.4
					c = Color(0.5 * k5, 0.5 * k5, 0.5 * k5, 0.6)
			alb.set_pixel(x, y, Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0), clampf(c.a, 0.0, 1.0)))
			hgt.set_pixel(x, y, Color(h, h, h))
	return [alb, hgt]
