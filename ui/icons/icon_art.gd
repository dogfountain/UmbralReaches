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
