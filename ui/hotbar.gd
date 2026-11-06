class_name Hotbar
extends Control
## Bottom-centre skill bar. Draws from the player's SkillBook every frame: glyph, key or pad
## button, cooldown sweep + seconds, Gloom cost, charge ring, cast flash, refusal shake and a
## ready pulse. Labels switch between keyboard and pad on the last device used.
## r28: the learned spells' glyphs (tether, well, familiar) come from the progression icons; a
## thin bar under a slot shows a spell still at work (a Bound Shade, an open Well); the staff core
## sits as a small gem on the Rift Bolt slot.

const SLOT := 78.0
const GAP := 14.0
const NAME_FADE := 14.0       ## names under the slots fade out after this many seconds
const NAME_PT := 17           ## r29: was 14 on one line (about 7 px tall at 1280x720: unreadable)
const KEY_PT := 17
const Med := preload("res://ui/medieval_style.gd")
const FRAME := Color(Med.BRONZE, 0.9)
const BG := Color(0.02, 0.012, 0.006, 0.78)
const SHADE := Color(0.01, 0.0, 0.03, 0.72)
const QUIET := Color(Med.BONE, 0.95)
const COST := Color("#C04DFF")
const Icons := preload("res://core/life/progression/icons.gd")
const DB := preload("res://core/life/progression/upgrade_db.gd")

var _book: SkillBook
var _font: Font
var _t := 0.0
var _was_ready := PackedByteArray()
var _vis: Array[int] = []      ## slots drawn: a slot still sealed (nothing taught for it yet) is not drawn at all
var _sig := ""                ## slot ids last drawn: a new loadout shows the names again
var _ready_pulse := PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://ui/fonts/Cinzel.ttf")


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_book):
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		_book = p.skills() if p else null
		if _book == null:
			return
		_was_ready.resize(_book.slots.size())
		_ready_pulse.resize(_book.slots.size())
		_was_ready.fill(1)
		offset_top = -(SLOT + 46.0 + 30.0)
		offset_bottom = -30.0             # the two-line names run a few px under the box (not clipped)
	var sig := ""
	var vis: Array[int] = []
	for i in _book.slots.size():
		var sl := _book.slots[i]
		sig += String(sl.id) + "," if sl != null else "-,"
		if sl != null and sl.id != &"sealed":
			vis.append(i)
	if vis != _vis:
		_vis = vis                       # the bar grows as spells are taught, and stays centred
		var w := _vis.size() * SLOT + maxf(0.0, _vis.size() - 1.0) * GAP
		offset_left = -w * 0.5
		offset_right = w * 0.5
	if sig != _sig:
		if _sig != "":
			_t = 0.0                     # swapped at a fire: say what is where again
		_sig = sig
	for i in _book.slots.size():
		var is_ready := _book.cooldown_left(i) <= 0.0
		if is_ready and _was_ready[i] == 0:
			_ready_pulse[i] = 1.0
		_was_ready[i] = 1 if is_ready else 0
		_ready_pulse[i] = maxf(0.0, _ready_pulse[i] - delta * 2.2)
	# redraw while something on the bar moves (a cooldown, a pulse, a glow, a charge, the name fade: _anim is what
	# the last draw saw), when the slots or the keys change, and otherwise only to look again ten times a second
	_idle -= delta
	var keys := ""
	var pulsing := false
	for i in _book.slots.size():
		keys += _book.key_label(i) + ","
		pulsing = pulsing or _ready_pulse[i] > 0.0
	var shown := "%s|%s|%s" % [sig, get_viewport_rect().size, keys]
	if _anim or pulsing or _t < NAME_FADE or shown != _shown_sig or _idle <= 0.0:
		_shown_sig = shown
		_idle = 0.1
		queue_redraw()


var _anim := true
var _idle := 0.0
var _shown_sig := ""


func _draw() -> void:
	if not is_instance_valid(_book):
		return
	_anim = false
	var name_a := clampf((NAME_FADE - _t) / 2.0, 0.0, 1.0)
	for vi in _vis.size():
		var i: int = _vis[vi]
		var s := _book.slots[i]
		var shake := sin(_t * 70.0) * 4.0 * _book.denied(i)
		var o := Vector2(vi * (SLOT + GAP) + shake, 0.0)
		var r := Rect2(o, Vector2(SLOT, SLOT))
		var is_ready := _book.cooldown_left(i) <= 0.0
		draw_style_box(Med.slot(), r.grow(3.0))          # an iron-rimmed socket of leather
		_glyph(s.glyph, r.get_center(), SLOT * 0.3, s.color if is_ready else s.color.darkened(0.55))
		# cooldown sweep, clockwise from 12 o'clock, plus seconds when > 1 s
		var cr := _book.cooldown_ratio(i)
		var gcd := _gcd_ratio() if (not _book.has_method("on_gcd") or bool(_book.call("on_gcd", i))) else 0.0
		if cr > 0.0:
			_anim = true
			_pie(r, cr, SHADE)
			_sweep_edge(r, cr)
			var left := _book.cooldown_left(i)
			# r33 (WoW): whole seconds, tenths in the last three (when the wait is long enough to read)
			var total := float(_book.call("cooldown_total", i)) if _book.has_method("cooldown_total") else _book.slots[i].cooldown
			if left >= 3.0 or (left >= 0.3 and total >= 2.0):
				var txt := str(ceili(left)) if left >= 3.0 else "%.1f" % left
				var pt := 26 if left >= 3.0 else 22
				draw_string_outline(_font, r.position + Vector2(0, SLOT * 0.6), txt, HORIZONTAL_ALIGNMENT_CENTER, SLOT, pt, 5, Color(0, 0, 0, 0.8))
				draw_string(_font, r.position + Vector2(0, SLOT * 0.6), txt, HORIZONTAL_ALIGNMENT_CENTER, SLOT, pt, Color(0.95, 0.92, 1.0) if left >= 3.0 else Color(1.0, 0.85, 0.5))
		elif gcd > 0.0:
			# r33: the shared recovery after any cast sweeps every ready slot (only drawn when it is
			# long enough to see; SkillBook's is a tenth of a second today)
			_pie(r, gcd, Color(SHADE, 0.5))
		# r33: can't be cast right now (no room, no target, busy): the slot goes cold blue-grey
		var why := s.can_cast(_book) if cr <= 0.0 else ""
		if why != "":
			draw_rect(r, Color(0.12, 0.16, 0.42, 0.45))
		var ch := _charges(s)
		if ch.y > 1:
			draw_string_outline(_font, r.position + Vector2(0, SLOT - 26), str(ch.x), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 5, 20, 5, Color(0, 0, 0, 0.85))
			draw_string(_font, r.position + Vector2(0, SLOT - 26), str(ch.x), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 5, 20, Color(1.0, 0.95, 0.85) if ch.x > 0 else Color(0.7, 0.55, 0.5))
		# charge ring (Ember Lance)
		if _book.charging_slot() == i:
			_anim = true
			var c := _book.charge_ratio()
			var col := s.color.lerp(Color(1.6, 1.4, 1.0), c) if c < 1.0 else Color(1.8, 1.6, 1.2)
			draw_arc(r.get_center(), SLOT * 0.47, -PI * 0.5, -PI * 0.5 + TAU * c, 48, col, 4.0, false)
			# Ember Lance I: the Perfect window right after the full snap burns white
			var oc := _book.overcharge()
			if c >= 1.0 and oc >= 0.0 and oc <= 0.2 and int(DB.get_mod("lance", 0)) >= 1 and s.id == &"lance":
				draw_arc(r.get_center(), SLOT * 0.47, 0, TAU, 48, Color(2.0, 1.9, 1.7), 7.0, false)
				draw_rect(r.grow(4.0), Color(1.0, 0.95, 0.8, 0.5 * (1.0 - oc / 0.2)), false, 3.0)
		# frame: cast flash > ready pulse > idle
		var frame := FRAME
		var f := _book.flash(i)
		if f > 0.0 or _book.denied(i) > 0.0:
			_anim = true
		if f > 0.0:
			frame = FRAME.lerp(Color(1.4, 1.3, 1.6), f)
		elif _ready_pulse[i] > 0.0:
			frame = FRAME.lerp(s.color.lightened(0.3), _ready_pulse[i])
		if _book.denied(i) > 0.0:
			frame = frame.lerp(Color(1.0, 0.3, 0.25), _book.denied(i))
		# combo: the next cast is the empowered one (Rift Lash / a riposte) -> the slot burns
		var primed := s.primed(_book)
		var surge_lit := bool(_book.call("slot_lit", i)) if _book.has_method("slot_lit") else false
		if primed or surge_lit or _proc(s):
			_anim = true
			var glow := 0.6 + 0.4 * sin(_t * 12.0)
			frame = frame.lerp(Color(1.5, 0.9, 2.6), glow)
			draw_rect(r.grow(3.0), Color(1.2, 0.6, 2.4, 0.35 * glow), false, 3.0)
			_proc_sparks(r, s.color)
		if not frame.is_equal_approx(FRAME):
			draw_rect(r.grow(-1.5), frame, false, 2.0 + f * 2.0)        # a cast, a ready pulse or a denial lights the rim
		# r33: the press held in the spell queue fires next: a gold inner line and a notch over the slot
		if _book.has_method("queued_slot") and int(_book.call("queued_slot")) == i:
			_anim = true
			var qa := 0.6 + 0.4 * sin(_t * 18.0)
			draw_rect(r.grow(-4.0), Color(1.0, 0.82, 0.4, qa), false, 2.0)
			var qc := o + Vector2(SLOT * 0.5, -18.0)
			draw_colored_polygon(PackedVector2Array([qc + Vector2(-6, -4), qc + Vector2(6, -4), qc + Vector2(0, 3)]), Color(1.0, 0.82, 0.4, qa))
		var pip := s.pips(_book)
		if pip.y > 0:
			for k in pip.y:
				var pc := o + Vector2(SLOT * 0.5 + (float(k) - float(pip.y - 1) * 0.5) * 14.0, -9.0)
				var lit := k < pip.x or (primed and k == pip.y - 1)
				var d := PackedVector2Array([pc + Vector2(0, -5), pc + Vector2(4, 0), pc + Vector2(0, 5), pc + Vector2(-4, 0)])
				if lit:
					draw_colored_polygon(d, s.color.lightened(0.35) if k < pip.y - 1 else Color(1.6, 1.0, 2.6))
				else:
					d.append(d[0])
					draw_polyline(d, Color(s.color, 0.45), 1.5, false)
		# key chip bottom-left, gloom cost top-right
		var key := _book.key_label(i)
		var kw := maxf(28.0, _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_PT).x + 10.0)
		var kr := Rect2(o + Vector2(-4, SLOT - 20), Vector2(kw, 24))
		draw_rect(kr, Color(0.07, 0.045, 0.03, 0.97))
		draw_rect(kr, FRAME, false, 1.0)
		draw_string(_font, kr.position + Vector2(0, 18), key, HORIZONTAL_ALIGNMENT_CENTER, kw, KEY_PT, QUIET)
		if s.gloom_cost > 0.0:
			draw_string(_font, o + Vector2(0, 17), "+%d" % roundi(s.gloom_cost), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 5, 14, COST)
		var act := s.active(_book)
		if act > 0.0:
			_anim = true
			var br := Rect2(o + Vector2(4, SLOT + 3), Vector2((SLOT - 8) * act, 4))
			draw_rect(Rect2(o + Vector2(4, SLOT + 3), Vector2(SLOT - 8, 4)), Color(0.02, 0.01, 0.04, 0.8))
			draw_rect(br, Color(s.color.lightened(0.2), 0.9))
		if i == 0:
			_core_gem(o + Vector2(SLOT - 9, 9))
		if name_a > 0.0:
			# one word a line ("Ember / Lance"): at a readable size a whole name is wider than a slot
			var nc := Color(QUIET, QUIET.a * name_a)
			var words := s.title.split(" ", false)
			for w in words.size():
				var at := o + Vector2(-GAP * 0.5 + 1.0, SLOT + 25.0 + float(w) * (NAME_PT + 1.0))
				draw_string_outline(_font, at, words[w], HORIZONTAL_ALIGNMENT_CENTER, SLOT + GAP - 2.0, NAME_PT, 5, Color(0.0, 0.0, 0.02, 0.85 * name_a))
				draw_string(_font, at, words[w], HORIZONTAL_ALIGNMENT_CENTER, SLOT + GAP - 2.0, NAME_PT, nc)


## The staff core in the orb, as a small faceted gem on the bolt slot (none for the Hollow Core).
func _core_gem(c: Vector2) -> void:
	var core := String(DB.get_mod("core", ""))
	if core == "":
		return
	_anim = true
	var col: Color = DB.core(core).get("tint", Color.WHITE)
	var pulse := 0.8 + 0.2 * sin(_t * 3.0)
	var d := PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)])
	draw_colored_polygon(d, Color(col * pulse, 1.0))
	d.append(d[0])
	draw_polyline(d, Color(0.02, 0.01, 0.04, 0.9), 1.5, false)
	draw_line(c + Vector2(-3, -1), c + Vector2(0, -4), Color(1, 1, 1, 0.7), 1.0, false)


## r33: the shared global recovery as a 0..1 ratio left (0 when none, or too short to show).
func _gcd_ratio() -> float:
	var left := 0.0
	var total := 0.0
	if _book.has_method("gcd_left"):
		left = float(_book.call("gcd_left"))
		total = float(_book.call("gcd_total")) if _book.has_method("gcd_total") else 1.0
	elif "_gcd" in _book:
		left = float(_book.get("_gcd"))
		total = float(_book.get_script().get_script_constant_map().get("GCD", 0.1))
	if total < 0.3 or left <= 0.0:
		return 0.0
	return clampf(left / total, 0.0, 1.0)


## r33: (charges left, most) when a skill keeps charges (charges() -> Vector2i, or charges /
## max_charges properties); (0, 0) otherwise.
func _charges(s: Skill) -> Vector2i:
	if s.has_method("charges"):
		var v: Variant = s.call("charges", _book)
		if v is Vector2i:
			return v
	if "charges" in s and "max_charges" in s:
		return Vector2i(int(s.get("charges")), int(s.get("max_charges")))
	return Vector2i.ZERO


## r33: a proc (proc(book) -> bool on a skill, or its `procced` flag) lights the slot like a primed one.
func _proc(s: Skill) -> bool:
	if s.has_method("proc"):
		return bool(s.call("proc", _book))
	return "procced" in s and bool(s.get("procced"))


## r33 (WoW's proc glow, our own): two ember sparks chase round the slot's edge.
func _proc_sparks(r: Rect2, col: Color) -> void:
	var per := (r.size.x + r.size.y) * 2.0
	for k in 2:
		var d := fposmod(_t * 160.0 + per * 0.5 * float(k), per)
		var p := _edge_point(r.grow(2.0), d)
		var c := Color(minf(col.r * 1.4 + 0.3, 1.6), minf(col.g * 1.2 + 0.25, 1.4), minf(col.b + 0.2, 1.6))
		draw_circle(p, 5.0, Color(c, 0.3))
		draw_circle(p, 2.4, Color(1.6, 1.3, 1.0))


func _edge_point(r: Rect2, d: float) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	if d < w:
		return r.position + Vector2(d, 0)
	d -= w
	if d < h:
		return r.position + Vector2(w, d)
	d -= h
	if d < w:
		return r.position + Vector2(w - d, h)
	return r.position + Vector2(0, h - (d - w))


## r33: the bright leading edge of a cooldown sweep.
func _sweep_edge(r: Rect2, ratio: float) -> void:
	var c := r.get_center()
	var a := -PI * 0.5 + TAU * (1.0 - ratio)
	var dir := Vector2(cos(a), sin(a))
	var far := c + dir * SLOT
	var tx := INF
	if absf(dir.x) > 0.001:
		tx = (SLOT * 0.5) / absf(dir.x)
	var ty := INF
	if absf(dir.y) > 0.001:
		ty = (SLOT * 0.5) / absf(dir.y)
	far = c + dir * minf(tx, ty)
	draw_line(c, far, Color(1.0, 0.85, 0.55, 0.55), 1.5, true)


func _pie(r: Rect2, ratio: float, col: Color) -> void:
	var c := r.get_center()
	var rad := SLOT * 0.75                 # past the corners; clipped to the slot below
	var pts := PackedVector2Array([c])
	var steps := maxi(3, int(48.0 * ratio))
	for k in steps + 1:
		var a := -PI * 0.5 + TAU * (1.0 - ratio) + TAU * ratio * float(k) / float(steps)
		var p := c + Vector2(cos(a), sin(a)) * rad
		pts.append(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))
	draw_colored_polygon(pts, col)


## Icons in code so the bar has no texture dependency. Simple line glyphs on a 1-unit scale.
func _glyph(g: StringName, c: Vector2, u: float, col: Color) -> void:
	match g:
		&"bolt":
			var d := PackedVector2Array([c + Vector2(0, -u), c + Vector2(u * 0.55, 0), c + Vector2(0, u), c + Vector2(-u * 0.55, 0), c + Vector2(0, -u)])
			draw_polyline(d, col, 3.0, false)
			draw_circle(c, u * 0.18, col)
			for k in 3:
				var y := (float(k) - 1.0) * u * 0.35
				draw_line(c + Vector2(-u * 1.25, y), c + Vector2(-u * 0.75, y), Color(col, 0.6), 2.0, false)
		&"lance":
			var a := c + Vector2(-u, u)
			var b := c + Vector2(u, -u)
			draw_line(a, b, col, 3.5, false)
			draw_colored_polygon(PackedVector2Array([b + Vector2(0.2, -0.2) * u, b + Vector2(-0.55, -0.05) * u, b + Vector2(0.05, 0.55) * u]), col)
			draw_line(a, a + Vector2(-0.2, 0.45) * u, col, 2.0, false)
			draw_line(a, a + Vector2(-0.45, 0.2) * u, col, 2.0, false)
		&"nova":
			draw_arc(c, u * 0.35, 0, TAU, 24, col, 3.0, false)
			draw_arc(c, u * 0.85, 0, TAU, 32, Color(col, 0.7), 2.0, false)
			for k in 8:
				var ang := TAU * float(k) / 8.0
				var v := Vector2(cos(ang), sin(ang))
				draw_line(c + v * u * 0.5, c + v * u * 0.72, col, 2.0, false)
		&"ward":
			draw_rect(Rect2(c + Vector2(-0.45, -0.25) * u, Vector2(0.9, 1.05) * u), col, false, 2.5)
			draw_line(c + Vector2(-0.25, -0.25) * u, c + Vector2(0, -0.6) * u, col, 2.0, false)
			draw_line(c + Vector2(0.25, -0.25) * u, c + Vector2(0, -0.6) * u, col, 2.0, false)
			var fl := c + Vector2(0, 0.3) * u
			draw_colored_polygon(PackedVector2Array([fl + Vector2(0, -0.42) * u, fl + Vector2(0.2, 0.05) * u, fl + Vector2(0, 0.2) * u, fl + Vector2(-0.2, 0.05) * u]), col.lightened(0.2))
			draw_arc(c + Vector2(0, 0.95) * u, u * 1.0, PI * 1.15, PI * 1.85, 16, Color(col, 0.55), 2.0, false)
		&"peal":
			# r36 the Founder's Peal: a bell, its tongue, and the stroke going out
			var bell := PackedVector2Array([c + Vector2(-0.18, -0.7) * u, c + Vector2(0.18, -0.7) * u, c + Vector2(0.32, -0.2) * u,
				c + Vector2(0.38, 0.35) * u, c + Vector2(0.55, 0.5) * u, c + Vector2(-0.55, 0.5) * u, c + Vector2(-0.38, 0.35) * u,
				c + Vector2(-0.32, -0.2) * u, c + Vector2(-0.18, -0.7) * u])
			draw_polyline(bell, col, 2.5, false)
			draw_circle(c + Vector2(0, 0.66) * u, u * 0.12, col)
			for k in 2:
				var rr := u * (0.95 + 0.3 * float(k))
				draw_arc(c + Vector2(0, -0.05) * u, rr, -0.5, 0.5, 8, Color(col, 0.7 - 0.25 * float(k)), 2.0, false)
				draw_arc(c + Vector2(0, -0.05) * u, rr, PI - 0.5, PI + 0.5, 8, Color(col, 0.7 - 0.25 * float(k)), 2.0, false)
		&"step":
			for k in 2:
				var x := (float(k) * 0.55 - 0.15) * u
				draw_polyline(PackedVector2Array([c + Vector2(x - 0.35 * u, -0.6 * u), c + Vector2(x + 0.25 * u, 0), c + Vector2(x - 0.35 * u, 0.6 * u)]), col, 3.0, false)
			for k in 3:
				draw_circle(c + Vector2(-u * (0.7 + 0.28 * float(k)), 0), u * (0.09 - 0.02 * float(k)), Color(col, 0.7 - 0.2 * float(k)))
		_:
			if not Icons.draw(self, String(g), c, u, col):
				draw_circle(c, u * 0.4, col)
