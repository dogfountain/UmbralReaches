extends RefCounted
## Region lettering for the world map, laid out and drawn live over the sheet (ui/world_map.gd) so it
## can follow the zoom: a name steps up with the zoom but only to a readable size, the lesser names wait
## until there is room, the greater ones recede when the view is close. Names are placed greedily by the
## region's size, never over one another and, where there is a choice, clear of the marks; a name that
## had to move off its region carries a hairline leader back to it. The map draws the marks over this.

const LoreDB := preload("res://core/world/realm/lore_db.gd")
const Landmarks := preload("res://ui/world_map_landmarks.gd")
const INK := Color(0.1, 0.055, 0.03)
const HALO := Color(0.93, 0.86, 0.68, 0.96)
const MIN_PX := [18.0, 16.0, 15.0, 14.0]             ## smallest on-screen size by tier
const MAX_PX := 32.0
const INKED := [[Vector2(-231.0, 97.0), Vector2(-224.0, 87.0)], [Vector2(-155.0, 184.0), Vector2(-155.0, 118.0)], [Vector2(155.0, 184.0), Vector2(155.0, 118.0)]]
const PAD := Vector2(9.0, 4.0)                       ## the margin round the letters (their halo) for placement

var cinzel: Font
var _items: Array[Dictionary] = []
var _placed: Array[Dictionary] = []
var _key := -1
var _marks := PackedVector2Array()
var _wall := PackedVector2Array()                   ## points along the wall; only tier 2 and 3 names avoid them
var _cands: Array[Vector2] = [Vector2.ZERO]          ## where a name may sit, in its own widths and heights from home, nearest first


func _init(font: Font) -> void:
	cinzel = font
	for dy: float in [0.0, 0.3, 0.6, 1.0, 1.4, 2.0, 3.0, 4.0]:
		for dx: float in [0.0, 0.25, 0.5, 0.75, 1.0, 1.4, 2.0]:
			for sy in ([1.0] if dy == 0.0 else [-1.0, 1.0]):
				for sx in ([1.0] if dx == 0.0 else [-1.0, 1.0]):
					if dx != 0.0 or dy != 0.0:
						_cands.append(Vector2(dx * sx, dy * sy))
	var regs: Array = RealmLayout.REGIONS.duplicate()
	regs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _area(a) > _area(b))
	for r: Dictionary in regs:
		var area := _area(r)
		var tier := 0 if area > 30000.0 else (1 if area > 9000.0 else (2 if area > 2500.0 else 3))
		var rc: Rect2 = r.rect if r.has("rect") else Rect2()
		var tall := r.has("rect") and rc.size.y > 2.3 * rc.size.x
		_items.append({
			"id": String(r.id), "text": LoreDB.place_name(String(r.id)).to_upper(), "at": rc.get_center() if r.has("rect") else r.c,
			"tier": tier, "tall": tall, "dot": not r.has("rect"), "base": [15.0, 11.5, 9.2, 7.7][tier]})
	for l: Array in Landmarks.LIST:                       # landmarks the sketch has reached are named, laid out with the rest
		_items.append({"id": String(l[0]), "text": String(l[1]).to_upper(), "at": l[2], "tier": 3, "tall": false, "dot": true, "base": 7.7})


static func _area(r: Dictionary) -> float:
	return (r.rect as Rect2).get_area() if r.has("rect") else PI * float(r.r) * float(r.r)


## Forget the layout (the marks changed).
func reset() -> void:
	_key = -1


func set_marks(at: PackedVector2Array) -> void:
	_marks = at.duplicate()
	for ln: Array in INKED:                            # lettering baked into the sheet (ui/world_map_ink.gd) is something to keep clear of too
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		for i in range(int(a.distance_to(b) / 7.0) + 1):
			_marks.append(a.lerp(b, i * 7.0 / a.distance_to(b)))
	_wall.clear()
	for sd in [-1, 1]:                                 # the March Wall's course: the lesser names keep off it (its lettering is inked on it)
		for k in range(-9, 29):
			var z := float(k) * 7.0
			_wall.append(Vector2(RealmMarch.wall_x(sd, z), z))
	_key = -1


func _px(it: Dictionary, zoom: float) -> int:
	return int(clampf(float(it.base) * zoom, float(MIN_PX[int(it.tier)]), MAX_PX))


## 0 until the zoom has room for this tier, 1 once it has; the greatest names recede when close.
func _fade(tier: int, zoom: float, zmin: float) -> float:
	var open_at: float = [0.0, 0.0, 1.0, 1.25][tier] * zmin
	var a := clampf((zoom - open_at) / (0.18 * zmin) + 1.0, 0.0, 1.0)
	if tier <= 1:
		a *= 1.0 - 0.6 * clampf((zoom / zmin - 2.2) / 1.6, 0.0, 1.0)
	return a


func _lines(it: Dictionary, size: int) -> PackedStringArray:
	var s := String(it.text)
	var words := s.split(" ")
	if bool(it.tall) or s.length() <= 16 or words.size() < 3 or size < 16:
		return PackedStringArray([s])
	var best := 1
	var gap := 999
	for i in range(1, words.size()):
		var g := absi(" ".join(words.slice(0, i)).length() - " ".join(words.slice(i)).length())
		if g < gap:
			gap = g
			best = i
	return PackedStringArray([" ".join(words.slice(0, best)), " ".join(words.slice(best))])


func _width(s: String, size: int, sp: float) -> float:
	return cinzel.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + sp * maxi(s.length() - 1, 0)


## Lay the names out for this zoom (px per metre). `seen` is the set of walked region ids.
func layout(zoom: float, zmin: float, seen: Array) -> void:
	var key := int(zoom * 40.0) + seen.size() * 100000
	if key == _key:
		return
	_key = key
	_placed.clear()
	var taken: Array[Rect2] = []
	var bounds := Rect2(RealmLayout.BOUNDS.position * zoom, RealmLayout.BOUNDS.size * zoom).grow(-18.0)
	var cap := 260.0 if zoom < 1.3 * zmin else 170.0         # a name strays only so far from its region
	for it in _items:
		if not seen.has(String(it.id)):
			continue
		var fade := _fade(int(it.tier), zoom, zmin)
		if fade <= 0.02:
			continue
		var size := _px(it, zoom)
		var sp := size * (0.12 if size >= 24 else 0.05)
		var lh := size * 1.2
		# the name's own line breaks first; a lesser name that finds no clear ground in them tries a narrower stack, one word a line
		var variants: Array[PackedStringArray] = [_lines(it, size)]
		var words := String(it.text).split(" ")
		if int(it.tier) >= 2 and not bool(it.tall) and words.size() >= 3 and variants[0].size() < words.size():
			variants.append(words)
		var home: Vector2 = (it.at as Vector2) * zoom
		var best: Dictionary = {}
		for lines in variants:
			var w := 0.0
			for ln in lines:
				w = maxf(w, _width(ln, size, sp))
			var dims := Vector2(w, lh * lines.size()) + PAD * 2.0
			if it.tall:
				dims = Vector2(dims.y, dims.x)
			var fit := _fit(it, dims, home, zoom, bounds, cap, taken)
			if fit.is_empty():
				continue
			if lines.size() > variants[0].size():
				fit["score"] = float(fit.score) + 150.0           # the stack only where it clears what the name's own breaks cannot
			if best.is_empty() or float(fit.score) < float(best.score):
				fit["lines"] = lines
				fit["dims"] = dims
				best = fit
		if best.is_empty() or (int(best.loose) > 0 and int(it.tier) >= 2) or int(best.loose) > 2:      # the lesser names wait rather than sit on a mark
			continue
		taken.append(Rect2((best.pos as Vector2) - (best.dims as Vector2) * 0.5, best.dims))
		_placed.append({"lines": best.lines, "size": size, "sp": sp, "lh": lh, "tall": it.tall, "pos": best.pos, "home": home,
			"fade": fade, "moved": (best.pos as Vector2).distance_to(home) > size * 0.9, "dims": best.dims})


## The best place for a name of these dimensions: {pos, score, loose} (loose = marks truly under it), or {} when nowhere is free.
func _fit(it: Dictionary, dims: Vector2, home: Vector2, zoom: float, bounds: Rect2, cap: float, taken: Array[Rect2]) -> Dictionary:
	var out := {}
	var best_score := INF
	for k in _cands.size():
		var cd := _cands[k]
		var ctr := home + Vector2(cd.x * dims.x, cd.y * (dims.y + 4.0))
		var lo := bounds.position + dims * 0.5
		var hi := bounds.end - dims * 0.5
		if lo.x < hi.x and lo.y < hi.y:
			ctr = ctr.clamp(lo, hi)
		if k > 0 and ctr.distance_to(home) > cap * (1.4 if bool(it.dot) else 1.0):
			continue
		var box := Rect2(ctr - dims * 0.5, dims)
		var clash := false
		for o in taken:
			if o.intersects(box.grow(5.0)):
				clash = true
				break
		if clash:
			continue
		var hits := 0
		var on_dot := 0.0
		var loose := 0                          # marks truly under the lettering (the margin is the halo's, no more)
		for m in _marks:
			if box.grow(11.5).has_point(m * zoom):
				hits += 1
				if box.grow(3.0).has_point(m * zoom):
					loose += 1
		if bool(it.dot) and int(it.tier) >= 2 and box.grow(3.0).has_point(home):      # a place that is a point (a lone tree, a well) has its landmark at home: the name sits beside it
			hits += 1
			on_dot = 1000.0                      # beside its landmark if there is any room; over it only when there is none
		if int(it.tier) >= 2:
			for m in _wall:
				if box.grow(6.0).has_point(m * zoom):
					hits += 1
					loose += 1
		var score := on_dot + loose * 1000.0 + hits * 200.0 + ctr.distance_to(home)      # clear of the marks first, then as near its region as it can sit
		if score < best_score:
			best_score = score
			out = {"pos": ctr, "score": score, "loose": loose}
		if hits == 0 and k == 0:
			break
	return out


## Draw the names. `to_screen` maps a point in (metres * zoom) space to the screen.
func draw(c: Control, zoom: float, to_screen: Callable, view: Rect2) -> void:
	for p in _placed:
		var s: Vector2 = to_screen.call(p.pos / zoom)
		var dims: Vector2 = p.dims
		if not view.grow(dims.length()).has_point(s):
			continue
		var nudged := false
		if view.has_point(s):                          # a name whose middle is on the sheet stays whole: it slides in from the edge
			var lo := view.position + dims * 0.5 + Vector2(8.0, 8.0)
			var hi := view.end - dims * 0.5 - Vector2(8.0, 8.0)
			if lo.x < hi.x and lo.y < hi.y:
				var q := s.clamp(lo, hi)
				nudged = q.distance_to(s) > float(p.size) * 0.6
				s = q
		var a: float = p.fade
		if p.moved or nudged:
			var h: Vector2 = to_screen.call(p.home / zoom)
			c.draw_line(s, h, Color(INK, 0.4 * a), 1.0, true)
			c.draw_circle(h, 2.2, Color(INK, 0.55 * a))
		var lines: PackedStringArray = p.lines
		var size: int = p.size
		for li in lines.size():
			var off := Vector2(0.0, (li - (lines.size() - 1) * 0.5) * float(p.lh))
			if p.tall:
				c.draw_set_transform(s, -PI * 0.5, Vector2.ONE)
				_letter(c, lines[li], off, size, float(p.sp), a)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				_letter(c, lines[li], s + off, size, float(p.sp), a)


func _letter(c: Control, s: String, at: Vector2, size: int, sp: float, a: float) -> void:
	var x0 := at.x - _width(s, size, sp) * 0.5
	var y := at.y + size * 0.35
	for pass_i in 2:                                   # every halo first, then the letters, so no halo bites a neighbour
		var x := x0
		for ch in s:
			if pass_i == 0:
				# no plate (Luke, 9 Nov: no box round the text): a wide soft parchment halo, then a firm one
				c.draw_string_outline(cinzel, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 16, Color(HALO, HALO.a * a * 0.4))
				c.draw_string_outline(cinzel, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(HALO, HALO.a * a))
			else:
				c.draw_string(cinzel, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, a))
				c.draw_string(cinzel, Vector2(x + 0.7, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, a))
			x += cinzel.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + sp
