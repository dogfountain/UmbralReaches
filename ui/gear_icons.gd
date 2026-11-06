extends Node
## Icons for the gear screen: one small picture per kind of piece (slot, rarity, set tint, legend), drawn
## once in a SubViewport and kept, so no cell redraws a glyph per frame. A piece's icon is a lit disc in
## its rarity colour with the slot's glyph on it; a set piece is tinted by its set, an Umbral or legend
## piece gets a second ring. Add this node to the gear panel and ask `icon(piece)` or `glyph_icon(...)`.
##   const Icons := preload("res://ui/gear_icons.gd")
## When the loot models arrive (core/items), render the model into the same viewport in `_make` and the
## cache key stays the same: callers only ever see a Texture2D.

const GearDB := preload("res://core/items/gear_db.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const Glyphs := preload("res://core/life/progression/icons.gd")
const SIZE := 128

var _cache := {}                 ## key -> ViewportTexture
var _made := 0


class Painter extends Control:
	var glyph := "prism"
	var col := Color.WHITE
	var ring := false
	var gems := 0

	func _draw() -> void:
		var c := size * 0.5
		var u := size.x * 0.3
		for i in 7:                                       # a soft lit disc behind the glyph
			draw_circle(c, size.x * (0.46 - 0.05 * float(i)), Color(col.r, col.g, col.b, 0.05 + 0.025 * float(i)))
		if ring:
			draw_arc(c, size.x * 0.44, 0.0, TAU, 48, Color(col, 0.7), 3.0)
		Glyphs.draw(self, glyph, c + Vector2(2.5, 3.0), u, Color(0, 0, 0, 0.55))
		Glyphs.draw(self, glyph, c, u, col.lightened(0.28))
		for i in gems:                                    # one gem for each line the piece rolled
			var gp := Vector2(size.x * 0.5 + (float(i) - float(gems - 1) * 0.5) * 17.0, size.y * 0.87)
			draw_circle(gp, 6.5, Color(0, 0, 0, 0.8))
			draw_circle(gp, 4.6, col.lightened(0.35))


## The icon for a gear piece ({} gives the empty-slot ghost of nothing: use `ghost`).
func icon(p: Dictionary) -> Texture2D:
	var slot := String(p.get("slot", "focus"))
	var r := clampi(int(p.get("rarity", 0)), 0, 4)
	var set_id := String(p.get("set", ""))
	var tint := LootDB.quality_color(r)
	if GearDB.SETS.has(set_id):
		tint = (GearDB.SETS[set_id].tint as Color).lerp(tint, 0.25)
	var ring := r >= 4 or String(p.get("legend", "")) != ""
	var gems := (p.get("aff", []) as Array).size()
	return _fetch("%s|%d|%s|%s|%d" % [slot, r, set_id, str(ring), gems], String(GearDB.SLOT_GLYPH.get(slot, "prism")), tint, ring, gems)


## A glyph by name in a colour (charm and relic shapes, the staff core): same cache.
func glyph_icon(glyph: String, tint: Color) -> Texture2D:
	return _fetch("g|%s|%s" % [glyph, tint.to_html(false)], glyph, tint, false, 0)


func _fetch(key: String, glyph: String, col: Color, ring: bool, gems: int) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.gui_disable_input = true
	var pa := Painter.new()
	pa.glyph = glyph
	pa.col = col
	pa.ring = ring
	pa.gems = gems
	pa.size = Vector2(SIZE, SIZE)
	vp.add_child(pa)
	add_child(vp)
	_made += 1
	_cache[key] = vp.get_texture()
	return _cache[key]


func made() -> int:
	return _made
