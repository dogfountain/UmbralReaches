extends RefCounted
## The world map's landmarks, inked when seen. The map's baked ink shows a landmark only inside a country the wanderer has found
## (the fog); out in the charcoal-sketched ground (core/story/map_sketch.gd) a landmark the sketch has reached is drawn here, live,
## in ink: a small cream medallion with its mark, and its name (the label placer lays the names out with the region names:
## ui/world_map_labels.gd reads `ITEMS`, so a name never sits over another or a pin). Also holds the sketch's texture for the fog
## shader. Static; load by path (no class_name). Cost: a loop over fifteen landmarks while the map is open and a 23 KB texture
## update when it opens; nothing at all otherwise.

const Sketch := preload("res://core/story/map_sketch.gd")
const INK := Color(0.19, 0.12, 0.075)
const CREAM := Color(0.96, 0.92, 0.78, 0.9)
const SEEN := 0.8                                      ## the sketch must reach this at the landmark's place

## id, name, world xz, mark
const LIST := [
	["lm_keg", "The Kindled Keg", Vector2(18.0, 30.0), "house"],
	["lm_chapel", "The Chapel Ruin", Vector2(-72.0, 52.0), "ruin"],
	["lm_henge", "The Henge", Vector2(-86.0, -24.0), "ring"],
	["lm_spire", "The Spire", Vector2(242.0, 6.0), "tower"],
	["lm_well", "The Well", Vector2(72.0, 204.0), "ring"],
	["lm_oak", "The Lone Oak", Vector2(-70.0, 206.0), "tree"],
	["lm_furnace", "The Furnace", Vector2(135.0, -105.0), "house"],
	["lm_field", "The Waiting Field", Vector2(-12.0, 124.0), "crosses"],
	["lm_quarry", "The Quarry", Vector2(-128.0, -84.0), "terrace"],
	["lm_plinth", "The Empty Plinth", Vector2(-214.0, -104.0), "ruin"],
	["lm_siege", "The Siege Lines", Vector2(-206.0, 148.0), "ring"],
	["lm_pans", "The Salt Pans", Vector2(226.0, 162.0), "terrace"],
	["lm_derrick", "The Derrick", Vector2(252.0, 170.0), "tower"],
	["lm_cells", "The Anchorites' Cells", Vector2(210.0, -136.0), "terrace"],
	["lm_keep", "The Summit Keep", Vector2(310.0, -104.0), "tower"],
]

static var _tex: ImageTexture


## The landmarks the sketch has reached: [id, name, at, mark].
static func seen() -> Array:
	var out := []
	for l: Array in LIST:
		var at: Vector2 = l[2]
		if Sketch.at(at.x, at.y) >= SEEN:
			out.append(l)
	return out


static func seen_ids() -> Array[String]:
	var out: Array[String] = []
	for l: Array in seen():
		out.append(String(l[0]))
	return out


## Hand the fog shader the sketch grid (a one-channel texture on the fog grid), called when the map opens.
static func attach(mat: ShaderMaterial) -> void:
	Sketch.ensure()
	var img := Image.create_from_data(Sketch.W, Sketch.H, false, Image.FORMAT_R8, Sketch.cells)
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	mat.set_shader_parameter("sketch_tex", _tex)


## Draw the inked marks of the seen landmarks that the baked ink does not show (outside the found countries).
## `to_screen` maps world xz to the screen, `fog` is the map's own found-country grid (bytes, the sketch's grid), `view` the visible rect.
static func paint(c: Control, to_screen: Callable, view: Rect2, fog: PackedByteArray) -> void:
	for l: Array in seen():
		var at: Vector2 = l[2]
		var k := clampi(int((at.y - Sketch.ORIGIN.y) / Sketch.CELL), 0, Sketch.H - 1) * Sketch.W + clampi(int((at.x - Sketch.ORIGIN.x) / Sketch.CELL), 0, Sketch.W - 1)
		if k < fog.size() and fog[k] >= 128:
			continue                                   # a found country: the baked ink already shows it
		var p: Vector2 = to_screen.call(at)
		if not view.has_point(p):
			continue
		_mark(c, String(l[3]), p)


static func _mark(c: Control, kind: String, p: Vector2) -> void:
	c.draw_circle(p, 12.0, CREAM)
	c.draw_arc(p, 12.0, 0.0, TAU, 24, Color(INK, 0.7), 1.2, true)
	match kind:
		"house":
			c.draw_rect(Rect2(p + Vector2(-5.0, -2.0), Vector2(10.0, 7.0)), Color(INK, 0.9), false, 1.6)
			c.draw_polyline(PackedVector2Array([p + Vector2(-6.5, -2.0), p + Vector2(0.0, -7.0), p + Vector2(6.5, -2.0)]), INK, 1.6, true)
		"ruin":
			c.draw_polyline(PackedVector2Array([p + Vector2(-6.0, 6.0), p + Vector2(-6.0, -4.0), p + Vector2(-2.0, -7.0), p + Vector2(-1.0, 0.0)]), INK, 1.6, true)
			c.draw_line(p + Vector2(3.0, 6.0), p + Vector2(3.0, -3.0), INK, 1.6, true)
			c.draw_line(p + Vector2(-8.0, 6.0), p + Vector2(8.0, 6.0), INK, 1.6, true)
		"ring":
			c.draw_arc(p, 6.0, 0.0, TAU, 16, INK, 1.6, true)
			c.draw_circle(p, 1.8, INK)
		"tower":
			c.draw_rect(Rect2(p + Vector2(-3.0, -7.0), Vector2(6.0, 14.0)), Color(INK, 0.9), false, 1.6)
			c.draw_line(p + Vector2(-5.0, -7.0), p + Vector2(5.0, -7.0), INK, 2.0, true)
		"tree":
			c.draw_circle(p + Vector2(0.0, -2.0), 5.5, Color(0.40, 0.50, 0.26, 0.85))
			c.draw_arc(p + Vector2(0.0, -2.0), 5.5, 0.0, TAU, 14, INK, 1.4, true)
			c.draw_line(p + Vector2(0.0, 3.0), p + Vector2(0.0, 8.0), INK, 2.2, true)
		"crosses":
			for dx: float in [-5.0, 0.0, 5.0]:
				c.draw_line(p + Vector2(dx, -5.0), p + Vector2(dx, 3.0), INK, 1.4, true)
				c.draw_line(p + Vector2(dx - 2.0, -2.0), p + Vector2(dx + 2.0, -2.0), INK, 1.4, true)
		"terrace":
			for k in 3:
				c.draw_arc(p + Vector2(0.0, 5.0), 4.0 + 3.0 * float(k), PI * 1.1, PI * 1.9, 8, INK, 1.4, true)
