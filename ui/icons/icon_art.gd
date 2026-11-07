class_name IconArt
extends RefCounted
## Painted icon art, generated offline by tools/gen_icons.py into res://ui/icons/<category>/<id>.png.
## `IconArt.art(category, id)` returns the Texture2D, or null when there is none, in which case the
## caller draws its old glyph. `draw_square` / `draw_disc` paint it on any CanvasItem in _draw.

const ROOT := "res://ui/icons/"

static var _cache: Dictionary = {}


static func art(category: String, id: String) -> Texture2D:
	if id == "":
		return null
	var key := category + "/" + id
	if _cache.has(key):
		return _cache[key]
	var path := ROOT + key + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = tex
	return tex


## Every painted icon, loaded into the cache on worker threads (the loading screen waits on this with
## `warm_done`), so a panel's or a loot bag's first draw never decodes a PNG on the frame. `await` it.
static func warm(tree: SceneTree) -> void:
	var paths: Array[String] = []
	for dir in DirAccess.get_directories_at(ROOT):
		for f in DirAccess.get_files_at(ROOT + dir):
			var fname := f.trim_suffix(".import")
			if fname.ends_with(".png") and not paths.has(ROOT + dir + "/" + fname):
				paths.append(ROOT + dir + "/" + fname)
	for path in paths:
		ResourceLoader.load_threaded_request(path)
	var t0 := Time.get_ticks_msec()
	for path in paths:
		var key := path.trim_prefix(ROOT).trim_suffix(".png")
		if _cache.has(key):
			continue
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
			if Time.get_ticks_msec() - t0 > 20000:
				return
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			_cache[key] = ResourceLoader.load_threaded_get(path) as Texture2D


## The first category that has the id (spell, then kindling).
static func find(id: String, categories: Array = ["spell", "kindling"]) -> Texture2D:
	for c in categories:
		var t := art(String(c), id)
		if t != null:
			return t
	return null


static func draw_square(ci: CanvasItem, tex: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	ci.draw_texture_rect(tex, rect, false, tint)


## A round-masked picture (for medallions): a fan polygon with the texture mapped on it.
static func draw_disc(ci: CanvasItem, tex: Texture2D, c: Vector2, radius: float, tint: Color = Color.WHITE) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var n := 40
	for i in n:
		var a := TAU * float(i) / float(n)
		var v := Vector2.from_angle(a)
		pts.append(c + v * radius)
		uvs.append(Vector2(0.5, 0.5) + v * 0.5)
	ci.draw_colored_polygon(pts, tint, uvs, tex)


## A list button's own mark (the codex rows, the quest log's pins): the icon, scaled to `size`, before the text.
static func on_button(b: Button, tex: Texture2D, size := 26.0) -> void:
	if tex == null:
		return
	b.icon = tex
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(size))
	b.add_theme_constant_override("h_separation", 10)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## A small painted medallion (category "mark", "lore", "task", "reward", "hud") centred on `c`, `size` px
## across. Returns false when there is none, so the caller draws its old glyph. The art is 64 px with
## mipmaps; the item filters with them so it stays crisp at 16 to 28 px.
static func draw_mark(ci: CanvasItem, category: String, id: String, c: Vector2, size: float, tint: Color = Color.WHITE) -> bool:
	var tex := art(category, id)
	if tex == null:
		return false
	if ci.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ci.draw_texture_rect(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), false, tint)
	return true
