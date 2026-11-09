extends RefCounted
## Per-kind skin detail for flesh.gdshader, generated at runtime from FastNoiseLite (native, a few
## ms per map, so not worth a disk cache): a seamless height map and the normal map derived from
## it. The shader tiles them over CreatureMesh's metric UVs (CreatureMesh.TILE = one repeat), so
## every part of a body has the same texel density.
##   wretch   taut skin pulled into long wrinkles (ridged simplex, stretched)
##   husk     bloated, blistered, cracking (cellular blisters over fine wrinkles)
##   spitter  thin, wet, finely pored
##   crawler  chitin: overlapping cell plates
##   leaper   cracked hide: deep cellular fissures
##   ossuant  porous bone and dried sinew
##   thorn    bark: long fibrous ridges (Thornwarden's plates)
## Load by path (no class_name): const SkinTex := preload("res://core/enemy/skin_tex.gd")

const SIZE := 128

static var _cache := {}


## [normal: Texture2D, height: Texture2D] for `kind`.
static func maps(kind: StringName) -> Array:
	if _cache.has(kind):
		return _cache[kind]
	var h := _height(kind)
	var n := h.duplicate() as Image
	n.convert(Image.FORMAT_RGBA8)
	n.bump_map_to_normal_map(_strength(kind))
	n.generate_mipmaps()
	h.generate_mipmaps()
	var out := [ImageTexture.create_from_image(n), ImageTexture.create_from_image(h)]
	_cache[kind] = out
	return out


static func _strength(kind: StringName) -> float:
	match kind:
		&"husk", &"leaper", &"thorn":
			return 6.0
		&"crawler", &"ossuant":
			return 5.2
		&"spitter":
			return 2.8
	return 4.2


static func _height(kind: StringName) -> Image:
	var a := FastNoiseLite.new()
	a.seed = hash(kind) % 9973
	var b: FastNoiseLite = null
	match kind:
		&"husk":
			a.noise_type = FastNoiseLite.TYPE_CELLULAR
			a.frequency = 0.07
			a.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
			a.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			a.fractal_type = FastNoiseLite.FRACTAL_FBM
			a.fractal_octaves = 2
			b = _wrinkle(kind, 0.06)
		&"crawler":
			a.noise_type = FastNoiseLite.TYPE_CELLULAR
			a.frequency = 0.056
			a.cellular_distance_function = FastNoiseLite.DISTANCE_HYBRID
			a.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
			a.fractal_type = FastNoiseLite.FRACTAL_NONE
		&"leaper":
			a.noise_type = FastNoiseLite.TYPE_CELLULAR
			a.frequency = 0.044
			a.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			a.fractal_type = FastNoiseLite.FRACTAL_PING_PONG
			a.fractal_octaves = 2
			b = _wrinkle(kind, 0.04)
		&"ossuant":
			a.noise_type = FastNoiseLite.TYPE_CELLULAR
			a.frequency = 0.14
			a.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			a.fractal_type = FastNoiseLite.FRACTAL_FBM
			a.fractal_octaves = 3
		&"spitter":
			a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			a.frequency = 0.12
			a.fractal_type = FastNoiseLite.FRACTAL_FBM
			a.fractal_octaves = 4
			a.fractal_gain = 0.6
		&"thorn":
			a.noise_type = FastNoiseLite.TYPE_SIMPLEX
			a.frequency = 0.024
			a.fractal_type = FastNoiseLite.FRACTAL_RIDGED
			a.fractal_octaves = 4
			a.domain_warp_enabled = true
			a.domain_warp_amplitude = 20.0
			a.domain_warp_frequency = 0.02
		_:
			a = _wrinkle(kind, 0.05)
	var img := a.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	if kind == &"thorn":
		# bark fibres run along the part (UV.y): squash the noise across, stretch it along
		img.resize(SIZE / 4, SIZE, Image.INTERPOLATE_BILINEAR)
		img.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	if b != null:
		var w := b.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
		img.convert(Image.FORMAT_RGBA8)
		w.convert(Image.FORMAT_RGBA8)
		# fold the wrinkles in at 40 % (a constant mask; no per-pixel GDScript)
		var mask := Image.create(SIZE, SIZE, false, Image.FORMAT_LA8)
		mask.fill(Color(1, 1, 1, 0.4))
		img.blend_rect_mask(w, mask, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
	img.convert(Image.FORMAT_L8)
	return img


## Long ridged wrinkles: simplex ridged, stretched along the part.
static func _wrinkle(kind: StringName, freq: float) -> FastNoiseLite:
	var w := FastNoiseLite.new()
	w.seed = (hash(kind) + 17) % 9973
	w.noise_type = FastNoiseLite.TYPE_SIMPLEX
	w.frequency = freq
	w.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	w.fractal_octaves = 3
	w.domain_warp_enabled = true
	w.domain_warp_amplitude = 9.0
	return w
