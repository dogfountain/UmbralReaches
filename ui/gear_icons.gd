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
const LootModel := preload("res://core/items/loot_model.gd")
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
		if glyph == "":                                   # over a rendered model: only the ring and the gems
			if ring:
				draw_arc(c, size.x * 0.44, 0.0, TAU, 48, Color(col, 0.7), 3.0)
			_gems(c)
			return
		for i in 7:                                       # a soft lit disc behind the glyph
			draw_circle(c, size.x * (0.46 - 0.05 * float(i)), Color(col.r, col.g, col.b, 0.05 + 0.025 * float(i)))
		if ring:
			draw_arc(c, size.x * 0.44, 0.0, TAU, 48, Color(col, 0.7), 3.0)
		Glyphs.draw(self, glyph, c + Vector2(2.5, 3.0), u, Color(0, 0, 0, 0.55))
		Glyphs.draw(self, glyph, c, u, col.lightened(0.28))
		_gems(c)

	func _gems(_c: Vector2) -> void:
		for i in gems:                                    # one gem for each line the piece rolled
			var gp := Vector2(size.x * 0.5 + (float(i) - float(gems - 1) * 0.5) * 17.0, size.y * 0.89)
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
	return _fetch("%s|%d|%s|%s|%d" % [slot, r, set_id, str(ring), gems], String(GearDB.SLOT_GLYPH.get(slot, "prism")), tint, ring, gems, {"kind": "gear", "piece": p})


## A glyph by name in a colour (charm and relic shapes, the staff core): same cache.
func glyph_icon(glyph: String, tint: Color) -> Texture2D:
	return _fetch("g|%s|%s" % [glyph, tint.to_html(false)], glyph, tint, false, 0)


## A satchel item (charm, relic, trophy, core) by ItemDB id: its model when loot_model has one, else its shape glyph.
func item_icon(id: String) -> Texture2D:
	var d := ItemDB.def(id)
	var tint: Color = d.get("tint", Color.WHITE)
	return _fetch("i|" + id, String(d.get("shape", "")), tint, false, 0, {"kind": "item", "id": id})


func _fetch(key: String, glyph: String, col: Color, ring: bool, gems: int, entry := {}) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.disable_3d = true
	add_child(vp)
	var model: Node3D = null
	if not entry.is_empty():
		var q := LootDB.quality_color(0)
		var qi := int((entry.piece as Dictionary).get("rarity", 0)) if entry.kind == "gear" else LootDB.item_quality(String(entry.id))
		model = LootModel.build(entry, qi)
		if model != null:
			_stage(vp, model, LootDB.quality_color(qi))
			glyph = ""
			vp.disable_3d = false
			vp.own_world_3d = true
			vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.gui_disable_input = true
	var pa := Painter.new()
	pa.glyph = glyph
	pa.col = col
	pa.ring = ring
	pa.gems = gems
	pa.size = Vector2(SIZE, SIZE)
	vp.add_child(pa)
	_made += 1
	_cache[key] = vp.get_texture()
	return _cache[key]


func made() -> int:
	return _made


## Three-quarter view of the item on its own: warm key, cool rim, the rarity colour glowing behind it.
func _stage(vp: SubViewport, model: Node3D, glow: Color) -> void:
	var mi := model.get_child(0) as MeshInstance3D
	mi.rotation.y = 0.55
	var box := mi.get_aabb()
	var ctr := mi.transform * box.get_center()
	var rad := maxf((box.size * mi.scale).length() * 0.5, 0.01)
	vp.add_child(model)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.65)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.78, 0.55)
	key.light_energy = 1.7
	key.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0.0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.72, 1.0)
	rim.light_energy = 1.1
	rim.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-140.0), 0.0)
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var dir := Vector3(0.55, 0.5, 0.9).normalized()
	var dist := rad / tan(deg_to_rad(15.0)) * 0.72
	cam.look_at_from_position(ctr + dir * dist, ctr)
	cam.current = true
	var halo := MeshInstance3D.new()                       # the rarity glow: a soft disc behind the item
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * rad * 3.4
	halo.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var grad := Gradient.new()
	grad.set_color(0, Color(glow, 0.8))
	grad.set_color(1, Color(glow, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	m.albedo_texture = gt
	halo.material_override = m
	vp.add_child(halo)
	halo.global_position = ctr - dir * rad * 1.4
	halo.look_at(cam.global_position)
