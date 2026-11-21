class_name Hotbar
extends Control
## Bottom-centre skill bar. Draws from the player's SkillBook every frame: glyph, key or pad
## button, cooldown sweep + seconds, Gloom cost, charge ring, cast flash, refusal shake and a
## ready pulse. Labels switch between keyboard and pad on the last device used.
## r28: the learned spells' glyphs (tether, well, familiar) come from the progression icons; a
## thin bar under a slot shows a spell still at work (a Bound Shade, an open Well); the staff core
## sits as a small gem on the Rift Bolt slot.

const SLOT := 78.0
const GAP := 26.0
const NAME_FADE := 14.0       ## the names under the slots are bright for this long after a new loadout, then settle quieter
const NAME_PT := 17          ## one row, body serif, the same size for every name
const NAME_REST := 0.62      ## how bright a name rests at
const KEY_PT := 15
const Med := preload("res://ui/medieval_style.gd")
const UIType := preload("res://ui/type.gd")
const FRAME := Color(Med.BRONZE, 0.9)
const EMBER := Color(1.0, 0.58, 0.22)
const STRIP_PAD := 14.0       ## the forged backing plate runs this far past the slots
const PLATE_TOP := 12.0
const NAME_ROW := 26.0        ## the name row sits in a trough under the slots, inside the plate
const Forge := preload("res://ui/hud_forge.gd")
const BG := Color(0.02, 0.012, 0.006, 0.78)
const SHADE := Color(0.01, 0.0, 0.03, 0.72)
const QUIET := Color(Med.BONE, 0.95)
const COST := Color("#C04DFF")
const Icons := preload("res://core/life/progression/icons.gd")
const DB := preload("res://core/life/progression/upgrade_db.gd")
const HudBake := preload("res://ui/hud_bake.gd")
## A slot's still picture as baked (ui/hud_bake.gd): its box in the slot's own units, round the socket, the cost, the key
## plate and the name under it (a long name runs past the socket).
const SLOT_BOX := Rect2(-44.0, -8.0, SLOT + 88.0, SLOT + 15.0 + NAME_ROW + 26.0)

var _book: SkillBook
var _font: Font
var _body: Font
var _t := 0.0
var _was_ready := PackedByteArray()
var _vis: Array[int] = []      ## slots drawn: a slot still sealed (nothing taught for it yet) is not drawn at all
var _sig := ""                ## slot ids last drawn: a new loadout shows the names again
var _ready_pulse := PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://ui/fonts/Cinzel.ttf")
	_body = UIType.body()
	# the staff core's gem pulses for as long as it is set: drawn on its own layer over the bar, so the pulse
	# redraws one gem a frame instead of the whole bar (sockets, icons, plates, outlined text: ~1.7 ms a frame)
	_live = Control.new()
	_live.name = "Live"
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.draw.connect(_draw_live)
	add_child(_live)
	_gem_layer = Control.new()
	_gem_layer.name = "CoreGem"
	_gem_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem_layer.draw.connect(_draw_gem_layer)
	add_child(_gem_layer)
	# the forged plate under the slots: drawn once into a texture (its rivets, finials and bevels were ~30 draw calls)
	_plate = HudBake.new()
	_plate.name = "Plate"
	_plate.art = _plate_art
	_plate.show_behind_parent = true
	add_child(_plate)


var _gem_layer: Control
var _live: Control             ## the moving parts over the bar (_draw_live)
var _plate: HudBake            ## the forged plate, baked (_strip)


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
		offset_top = -(SLOT + NAME_ROW + 24.0 + 36.0)
		offset_bottom = -36.0             # the plate's foot
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
		_span = w + STRIP_PAD * 2.0
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
	# the live layer redraws while something on it moves (_anim is what its last draw saw: a sweep, a charge, a
	# flash, a glow) or a pulse or a refusal's shake runs, and otherwise looks again ten times a second (a slot
	# going cold). A slot's still picture redraws when its spell, key or ready state changes and while the names
	# fade (a shake only moves it); the plate when the slots shown or the screen change.
	_idle -= delta
	_static_idle -= delta
	var pulsing := false
	var shaking := false
	for i in _book.slots.size():
		pulsing = pulsing or _ready_pulse[i] > 0.0
		shaking = shaking or _book.denied(i) > 0.0
	# (30 to 40 times a second, on a frame between physics ticks (FramePace): a sweep or a glow reads the same at
	# that rate as at 120, and the live layer and the gem were two of the HUD's every-frame redraws in a fight)
	var now := Time.get_ticks_msec()
	if (_anim or pulsing or shaking or _idle <= 0.0) and FramePace.due(_live_at, 0):
		_idle = 0.1
		_live_at = now
		_live.queue_redraw()
	var plate := "%s|%s" % [sig, get_viewport_rect().size]
	if plate != _shown_sig:
		_shown_sig = plate
		if _slot_ci.size() != _vis.size() or _slot_ci.any(func(c: Control) -> bool: return not _vis.has(int(c.get_meta(&"slot")))):
			_sync_slot_items()
		queue_redraw()
	# a slot is baked again when what it shows changes (the names' fade in steps of 1 %), and as a catch-all every half
	# second one slot at a time, each on its own frame: all of them together were a burst of bake passes on one frame
	# twice a second, and the fade baked every slot every frame
	var refresh_vi := -1
	if _static_idle <= 0.0 and not _slot_ci.is_empty():
		_static_idle = 0.5 / float(_slot_ci.size())
		_refresh_vi = (_refresh_vi + 1) % _slot_ci.size()
		refresh_vi = _refresh_vi
	var name_a := snappedf(_name_a(), 0.01)
	for vi in _slot_ci.size():
		var c := _slot_ci[vi]
		var i := int(c.get_meta(&"slot"))
		c.position = _slot_origin(vi, i) + SLOT_BOX.position
		var ss := "%s|%s|%s|%s" % [sig, _book.key_label(i), _book.cooldown_left(i) <= 0.0, name_a]
		if vi == refresh_vi or ss != String(c.get_meta(&"sig", "")):
			c.set_meta(&"sig", ss)
			(c as HudBake).rebake()
	if (String(DB.get_mod("core", "")) != "" or _gem_drawn) and FramePace.due(_gem_at, 1):
		_gem_at = now
		_gem_layer.queue_redraw()


var _span := 0.0
var _anim := true
const FramePace := preload("res://core/util/frame_pace.gd")
var _live_at := 0                ## msec of the live layer's last redraw
var _gem_at := 0
var _idle := 0.0
var _static_idle := 0.0
var _refresh_vi := -1            ## the slot the catch-all refresh looked at last
var _shown_sig := ""


## How bright the names under the slots are (bright after a new loadout, settling quieter over two seconds).
func _name_a() -> float:
	return lerpf(NAME_REST, 1.0, clampf((NAME_FADE - _t) / 2.0, 0.0, 1.0))


## The bar in two layers. This one is the forged bar itself -- plate, sockets, bevels, rivets, the spell pictures,
## key plates, costs and names -- and redraws only when the slots, the keys, a slot going cold or ready, the names'
## fade or a refusal's shake change it. Everything that moves in a fight (cooldown sweeps and seconds, the global recovery, a slot gone
## cold, charges, the charge ring, rim flashes and glows, the queued press, pips, a spell at work) is on the live
## layer above it (_draw_live), which redraws every frame while something moves.
## (Rebuilding the whole bar each frame cost ~1.5 ms of script a frame in every fight.)
func _draw() -> void:
	if not is_instance_valid(_book) or _vis.is_empty():
		_plate.visible = false
		return
	var pr := _plate_rect().grow(24.0)               # the finials and the shadow reach past the plate
	_plate.visible = true
	_plate.position = pr.position
	_plate.size = pr.size
	_plate.refresh(_vis.size())


func _plate_art(ci: CanvasItem) -> void:
	ci.draw_set_transform(-_plate.position)
	_strip(ci)


## One slot's still picture -- socket, bevel, the spell's picture (dimmed while it cools), key plate, cost and
## name -- on its own canvas item, in its own frame: a refusal's shake moves the item, it does not redraw it.
func _draw_slot(ci: CanvasItem, i: int) -> void:
	ci.draw_set_transform(-SLOT_BOX.position)          # (the baked box starts before the socket)
	if not is_instance_valid(_book):
		return
	if i >= _book.slots.size() or _book.slots[i] == null:
		return
	var s := _book.slots[i]
	var name_a := snappedf(_name_a(), 0.01)          # (the step the slot is baked again at)
	var name_pt := _name_pt()
	var o := Vector2.ZERO
	var r := Rect2(o, Vector2(SLOT, SLOT))
	ci.draw_style_box(Med.slot(Color(1.0, 0.82, 0.56)), r.grow(3.0))          # an iron-rimmed socket of leather
	_bevel(ci, r.grow(3.0))
	var is_ready := _book.cooldown_left(i) <= 0.0
	var art := IconArt.art("spell", String(s.glyph))
	if art != null:
		IconArt.draw_square(ci, art, r.grow(-1.0), Color.WHITE if is_ready else Color(0.5, 0.48, 0.56))
		ci.draw_rect(r.grow(-1.0), Color(0, 0, 0, 0.55), false, 1.5)      # a dark inner edge seats the picture in its socket
	else:
		_glyph(ci, s.glyph, r.get_center(), SLOT * 0.3, s.color if is_ready else s.color.darkened(0.55))
	# key on a small engraved plate riveted across the bottom rim
	var key := _book.key_label(i)
	var kw := maxf(30.0, _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_PT).x + 16.0)
	var kr := Rect2(o + Vector2(SLOT * 0.5 - kw * 0.5, SLOT - 9.0), Vector2(kw, 20))
	ci.draw_style_box(_key_box(), kr)
	ci.draw_line(kr.position + Vector2(3, 1.5), kr.position + Vector2(kw - 3, 1.5), Color(Med.GILT, 0.25), 1.0)
	_rivet(ci, kr.position + Vector2(4, 10), 1.3)
	_rivet(ci, kr.position + Vector2(kw - 4, 10), 1.3)
	ci.draw_string(_font, kr.position + Vector2(0, 15), key, HORIZONTAL_ALIGNMENT_CENTER, kw, KEY_PT, QUIET)
	if s.gloom_cost > 0.0:
		ci.draw_string_outline(_font, o + Vector2(0, 17), "+%d" % roundi(s.gloom_cost), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 5, 14, 4, Color(0, 0, 0, 0.9))
		ci.draw_string(_font, o + Vector2(0, 17), "+%d" % roundi(s.gloom_cost), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 5, 14, COST.lightened(0.35))
	var nw := _body.get_string_size(s.title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_pt).x
	var np := o + Vector2(SLOT * 0.5 - nw * 0.5, SLOT + 15.0 + NAME_ROW * 0.5 + name_pt * 0.32)
	Forge.label(ci, _body, np, s.title, name_pt, Color(Med.BONE, name_a), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)


## The slots' canvas items, one per slot shown, under the live layer (made again when the shown slots change).
var _slot_ci: Array[Control] = []


func _sync_slot_items() -> void:
	for c in _slot_ci:
		c.queue_free()
	_slot_ci.clear()
	for vi in _vis.size():
		# a slot's still picture changes only when its spell, key or readiness does: baked (sockets, bevels and rivets
		# were ~25 draw calls a slot)
		var c := HudBake.new()
		c.name = "Slot%d" % vi
		c.set_meta(&"slot", _vis[vi])
		c.art = _draw_slot.bind(_vis[vi])
		c.size = SLOT_BOX.size
		add_child(c)
		move_child(c, _live.get_index())          # under the live layer and the gem
		_slot_ci.append(c)


## Where slot i (the vi-th shown) is drawn this frame: a refusal shakes it.
func _slot_origin(vi: int, i: int) -> Vector2:
	return Vector2(vi * (SLOT + GAP) + sin(_t * 70.0) * 4.0 * _book.denied(i), 0.0)


var _key_sb: StyleBoxFlat


func _key_box() -> StyleBoxFlat:
	if _key_sb == null:
		_key_sb = StyleBoxFlat.new()
		_key_sb.bg_color = Color(0.06, 0.038, 0.024, 0.98)
		_key_sb.border_color = Color(Med.BRONZE, 0.95)
		_key_sb.set_border_width_all(1)
		_key_sb.set_corner_radius_all(3)
	return _key_sb


## The live layer (see _draw): what moves over the forged bar. Sets _anim while anything on it is moving.
func _draw_live() -> void:
	if not is_instance_valid(_book):
		return
	_anim = false
	for vi in _vis.size():
		var i: int = _vis[vi]
		var s := _book.slots[i]
		var o := _slot_origin(vi, i)
		var r := Rect2(o, Vector2(SLOT, SLOT))
		# cooldown sweep, clockwise from 12 o'clock, plus seconds when > 1 s
		var cr := _book.cooldown_ratio(i)
		var gcd := _gcd_ratio() if (not _book.has_method("on_gcd") or bool(_book.call("on_gcd", i))) else 0.0
		if cr > 0.0:
			_anim = true
			_pie(_live, r, cr, SHADE)
			_sweep_edge(_live, r, cr)
			var left := _book.cooldown_left(i)
			# r33 (WoW): whole seconds, tenths in the last three (when the wait is long enough to read)
			var total := float(_book.call("cooldown_total", i)) if _book.has_method("cooldown_total") else _book.slots[i].cooldown
			if left >= 3.0 or (left >= 0.3 and total >= 2.0):
				var txt := str(ceili(left)) if left >= 3.0 else "%.1f" % left
				var pt := 26 if left >= 3.0 else 22
				_live.draw_string_outline(_font, r.position + Vector2(0, SLOT * 0.6), txt, HORIZONTAL_ALIGNMENT_CENTER, SLOT, pt, 5, Color(0, 0, 0, 0.8))
				_live.draw_string(_font, r.position + Vector2(0, SLOT * 0.6), txt, HORIZONTAL_ALIGNMENT_CENTER, SLOT, pt, Color(0.95, 0.92, 1.0) if left >= 3.0 else Color(1.0, 0.85, 0.5))
		elif gcd > 0.0:
			# r33: the shared recovery after any cast sweeps every ready slot (only drawn when it is
			# long enough to see; SkillBook's is a tenth of a second today)
			_anim = true
			_pie(_live, r, gcd, Color(SHADE, 0.5))
		# r33: can't be cast right now (no room, no target, busy): the slot goes cold blue-grey
		var why := s.can_cast(_book) if cr <= 0.0 else ""
		if why != "":
			_live.draw_rect(r, Color(0.12, 0.16, 0.42, 0.45))
		var ch := _charges(s)
		if ch.y > 1:
			_live.draw_string_outline(_font, r.position + Vector2(0, SLOT - 26), str(ch.x), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 5, 20, 5, Color(0, 0, 0, 0.85))
			_live.draw_string(_font, r.position + Vector2(0, SLOT - 26), str(ch.x), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 5, 20, Color(1.0, 0.95, 0.85) if ch.x > 0 else Color(0.7, 0.55, 0.5))
		# charge ring (Ember Lance)
		if _book.charging_slot() == i:
			_anim = true
			var c := _book.charge_ratio()
			var col := s.color.lerp(Color(1.6, 1.4, 1.0), c) if c < 1.0 else Color(1.8, 1.6, 1.2)
			_live.draw_arc(r.get_center(), SLOT * 0.47, -PI * 0.5, -PI * 0.5 + TAU * c, 48, col, 4.0, false)
			# Ember Lance I: the Perfect window right after the full snap burns white
			var oc := _book.overcharge()
			if c >= 1.0 and oc >= 0.0 and oc <= 0.2 and int(DB.get_mod("lance", 0)) >= 1 and s.id == &"lance":
				_live.draw_arc(r.get_center(), SLOT * 0.47, 0, TAU, 48, Color(2.0, 1.9, 1.7), 7.0, false)
				_live.draw_rect(r.grow(4.0), Color(1.0, 0.95, 0.8, 0.5 * (1.0 - oc / 0.2)), false, 3.0)
		# frame: cast flash > ready pulse > idle
		var frame := FRAME
		var f := _book.flash(i)
		if f > 0.0 or _book.denied(i) > 0.0:
			_anim = true
		if f > 0.0:
			frame = FRAME.lerp(Color(1.4, 1.3, 1.6), f)
		elif _ready_pulse[i] > 0.0:
			frame = FRAME.lerp(Med.GILT.lightened(0.35), _ready_pulse[i])     # a warm glint on the rim, not the spell's colour
		if _book.denied(i) > 0.0:
			frame = frame.lerp(Color(1.0, 0.3, 0.25), _book.denied(i))
		# combo: the next cast is the empowered one (Rift Lash / a riposte) -> the slot burns
		var primed := s.primed(_book)
		var surge_lit := bool(_book.call("slot_lit", i)) if _book.has_method("slot_lit") else false
		if primed or surge_lit or _proc(s):
			_anim = true
			var glow := 0.6 + 0.4 * sin(_t * 12.0)
			frame = frame.lerp(Color(1.5, 0.9, 2.6), glow)
			_live.draw_rect(r.grow(3.0), Color(1.2, 0.6, 2.4, 0.35 * glow), false, 3.0)
			_proc_sparks(_live, r, s.color)
		if not frame.is_equal_approx(FRAME):
			_live.draw_rect(r.grow(-1.5), frame, false, 2.0 + f * 2.0)        # a cast, a ready pulse or a denial lights the rim
		# r33: the press held in the spell queue fires next: a gold inner line and a notch over the slot
		if _book.has_method("queued_slot") and int(_book.call("queued_slot")) == i:
			_anim = true
			var qa := 0.6 + 0.4 * sin(_t * 18.0)
			_live.draw_rect(r.grow(-4.0), Color(1.0, 0.82, 0.4, qa), false, 2.0)
			var qc := o + Vector2(SLOT * 0.5, -18.0)
			_live.draw_colored_polygon(PackedVector2Array([qc + Vector2(-6, -4), qc + Vector2(6, -4), qc + Vector2(0, 3)]), Color(1.0, 0.82, 0.4, qa))
		var pip := s.pips(_book)
		if pip.y > 0:
			for k in pip.y:
				var pc := o + Vector2(SLOT * 0.5 + (float(k) - float(pip.y - 1) * 0.5) * 14.0, -9.0)
				var lit := k < pip.x or (primed and k == pip.y - 1)
				var d := PackedVector2Array([pc + Vector2(0, -5), pc + Vector2(4, 0), pc + Vector2(0, 5), pc + Vector2(-4, 0)])
				if lit:
					_live.draw_colored_polygon(d, s.color.lightened(0.35) if k < pip.y - 1 else Color(1.6, 1.0, 2.6))
				else:
					d.append(d[0])
					_live.draw_polyline(d, Color(s.color, 0.45), 1.5, false)
		var act := s.active(_book)
		if act > 0.0:
			_anim = true
			var br := Rect2(o + Vector2(4, SLOT + 3), Vector2((SLOT - 8) * act, 4))
			_live.draw_rect(Rect2(o + Vector2(4, SLOT + 3), Vector2(SLOT - 8, 4)), Color(0.02, 0.01, 0.04, 0.8))
			_live.draw_rect(br, Color(s.color.lightened(0.2), 0.9))


## One size for every spell name, so the row reads as a row: the largest that lets the longest name keep its column.
func _name_pt() -> int:
	var widest := 1.0
	for i: int in _vis:
		widest = maxf(widest, _body.get_string_size(_book.slots[i].title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PT).x)
	var room := SLOT + GAP - 12.0
	return clampi(floori(NAME_PT * room / widest), 14, NAME_PT) if widest > room else NAME_PT


## The bar's width, the plate included (the XP bar under it matches it).
func span() -> float:
	return _span


## One forged backing plate behind the row: bronze bevel, a finial at each end, a rivet in every gap, and a
## recessed trough under the sockets that holds the spell names.
func _plate_rect() -> Rect2:
	var n := _vis.size()
	var w := n * SLOT + maxf(0.0, n - 1.0) * GAP
	return Rect2(-STRIP_PAD, -PLATE_TOP, w + STRIP_PAD * 2.0, SLOT + PLATE_TOP + NAME_ROW + 24.0)


func _strip(ci: CanvasItem) -> void:
	if _vis.is_empty():
		return
	var n := _vis.size()
	var w := n * SLOT + maxf(0.0, n - 1.0) * GAP
	var pr := _plate_rect()
	Forge.plate(ci, pr, 1.0)
	var trough := Rect2(0.0, SLOT + 15.0, w, NAME_ROW)
	Forge.trough(ci, trough)
	for k in n + 1:
		var x := (SLOT + GAP) * float(k) - GAP * 0.5
		if k == 0:
			x = -STRIP_PAD * 0.5
		elif k == n:
			x = w + STRIP_PAD * 0.5
		_rivet(ci, Vector2(x, -PLATE_TOP * 0.5 + 0.5), 1.8)
		if k > 0 and k < n:
			var dx := trough.position.x + x
			ci.draw_line(Vector2(dx, trough.position.y + 5.0), Vector2(dx, trough.end.y - 5.0), Color(Med.BRONZE, 0.28), 1.0)
	var ym := pr.position.y + pr.size.y * 0.5
	Forge.finial(ci, Vector2(pr.position.x - 1.0, ym), -1.0, 15.0)
	Forge.finial(ci, Vector2(pr.end.x + 1.0, ym), 1.0, 15.0)


## A bevelled rim over a socket: lit top and left edges, shadowed bottom and right, and a rivet in each corner.
func _bevel(ci: CanvasItem, r: Rect2) -> void:
	var a := r.position
	var b := r.end
	ci.draw_line(a + Vector2(2, 0.5), Vector2(b.x - 2, a.y + 0.5), Color(1.0, 0.9, 0.68, 0.3), 1.0)
	ci.draw_line(a + Vector2(0.5, 2), Vector2(a.x + 0.5, b.y - 2), Color(1.0, 0.9, 0.68, 0.18), 1.0)
	ci.draw_line(Vector2(a.x + 2, b.y - 0.5), b - Vector2(2, 0.5), Color(0, 0, 0, 0.6), 1.0)
	ci.draw_line(Vector2(b.x - 0.5, a.y + 2), b - Vector2(0.5, 2), Color(0, 0, 0, 0.5), 1.0)
	for c in [a + Vector2(3, 3), Vector2(b.x - 3, a.y + 3), Vector2(a.x + 3, b.y - 3), b - Vector2(3, 3)]:
		_rivet(ci, c, 1.5)


func _rivet(ci: CanvasItem, c: Vector2, rad: float) -> void:
	ci.draw_circle(c + Vector2(0.5, 0.7), rad, Color(0, 0, 0, 0.55))
	ci.draw_circle(c, rad, Color(Med.BRONZE.darkened(0.15), 1.0))
	ci.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.35), rad * 0.45, Color(Med.GILT, 0.85))


var _gem_drawn := false


## The gem layer: the bolt slot's gem where the bar draws that slot (its shake included), every frame.
func _draw_gem_layer() -> void:
	_gem_drawn = false
	if not is_instance_valid(_book):
		return
	var vi := _vis.find(0)
	if vi < 0:
		return
	var shake := sin(_t * 70.0) * 4.0 * _book.denied(0)
	_gem_drawn = _core_gem(_gem_layer, Vector2(vi * (SLOT + GAP) + shake, 0.0) + Vector2(SLOT - 9, 9))


## The staff core in the orb, as a small faceted gem on the bolt slot (none for the Hollow Core).
func _core_gem(ci: CanvasItem, c: Vector2) -> bool:
	var core := String(DB.get_mod("core", ""))
	if core == "":
		return false
	var col: Color = DB.core(core).get("tint", Color.WHITE)
	var pulse := 0.8 + 0.2 * sin(_t * 3.0)
	if IconArt.draw_mark(ci, "hud", "core_gem", c, 17.0, Color(col * pulse, 1.0)):
		return true
	var d := PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)])
	ci.draw_colored_polygon(d, Color(col * pulse, 1.0))
	d.append(d[0])
	ci.draw_polyline(d, Color(0.02, 0.01, 0.04, 0.9), 1.5, false)
	ci.draw_line(c + Vector2(-3, -1), c + Vector2(0, -4), Color(1, 1, 1, 0.7), 1.0, false)
	return true


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
func _proc_sparks(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var per := (r.size.x + r.size.y) * 2.0
	for k in 2:
		var d := fposmod(_t * 160.0 + per * 0.5 * float(k), per)
		var p := _edge_point(r.grow(2.0), d)
		var c := Color(minf(col.r * 1.4 + 0.3, 1.6), minf(col.g * 1.2 + 0.25, 1.4), minf(col.b + 0.2, 1.6))
		ci.draw_circle(p, 5.0, Color(c, 0.3))
		ci.draw_circle(p, 2.4, Color(1.6, 1.3, 1.0))


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
func _sweep_edge(ci: CanvasItem, r: Rect2, ratio: float) -> void:
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
	ci.draw_line(c, far, Color(EMBER, 0.28), 3.0, true)
	ci.draw_line(c, far, Color(1.0, 0.8, 0.5, 0.85), 1.2, true)


func _pie(ci: CanvasItem, r: Rect2, ratio: float, col: Color) -> void:
	var c := r.get_center()
	var rad := SLOT * 0.75                 # past the corners; clipped to the slot below
	var pts := PackedVector2Array([c])
	var steps := maxi(3, int(48.0 * ratio))
	for k in steps + 1:
		var a := -PI * 0.5 + TAU * (1.0 - ratio) + TAU * ratio * float(k) / float(steps)
		var p := c + Vector2(cos(a), sin(a)) * rad
		pts.append(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))
	ci.draw_colored_polygon(pts, col)


## Icons in code so the bar has no texture dependency. Simple line glyphs on a 1-unit scale.
func _glyph(ci: CanvasItem, g: StringName, c: Vector2, u: float, col: Color) -> void:
	match g:
		&"bolt":
			var d := PackedVector2Array([c + Vector2(0, -u), c + Vector2(u * 0.55, 0), c + Vector2(0, u), c + Vector2(-u * 0.55, 0), c + Vector2(0, -u)])
			ci.draw_polyline(d, col, 3.0, false)
			ci.draw_circle(c, u * 0.18, col)
			for k in 3:
				var y := (float(k) - 1.0) * u * 0.35
				ci.draw_line(c + Vector2(-u * 1.25, y), c + Vector2(-u * 0.75, y), Color(col, 0.6), 2.0, false)
		&"lance":
			var a := c + Vector2(-u, u)
			var b := c + Vector2(u, -u)
			ci.draw_line(a, b, col, 3.5, false)
			ci.draw_colored_polygon(PackedVector2Array([b + Vector2(0.2, -0.2) * u, b + Vector2(-0.55, -0.05) * u, b + Vector2(0.05, 0.55) * u]), col)
			ci.draw_line(a, a + Vector2(-0.2, 0.45) * u, col, 2.0, false)
			ci.draw_line(a, a + Vector2(-0.45, 0.2) * u, col, 2.0, false)
		&"nova":
			ci.draw_arc(c, u * 0.35, 0, TAU, 24, col, 3.0, false)
			ci.draw_arc(c, u * 0.85, 0, TAU, 32, Color(col, 0.7), 2.0, false)
			for k in 8:
				var ang := TAU * float(k) / 8.0
				var v := Vector2(cos(ang), sin(ang))
				ci.draw_line(c + v * u * 0.5, c + v * u * 0.72, col, 2.0, false)
		&"ward":
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.25) * u, Vector2(0.9, 1.05) * u), col, false, 2.5)
			ci.draw_line(c + Vector2(-0.25, -0.25) * u, c + Vector2(0, -0.6) * u, col, 2.0, false)
			ci.draw_line(c + Vector2(0.25, -0.25) * u, c + Vector2(0, -0.6) * u, col, 2.0, false)
			var fl := c + Vector2(0, 0.3) * u
			ci.draw_colored_polygon(PackedVector2Array([fl + Vector2(0, -0.42) * u, fl + Vector2(0.2, 0.05) * u, fl + Vector2(0, 0.2) * u, fl + Vector2(-0.2, 0.05) * u]), col.lightened(0.2))
			ci.draw_arc(c + Vector2(0, 0.95) * u, u * 1.0, PI * 1.15, PI * 1.85, 16, Color(col, 0.55), 2.0, false)
		&"peal":
			# r36 the Founder's Peal: a bell, its tongue, and the stroke going out
			var bell := PackedVector2Array([c + Vector2(-0.18, -0.7) * u, c + Vector2(0.18, -0.7) * u, c + Vector2(0.32, -0.2) * u,
				c + Vector2(0.38, 0.35) * u, c + Vector2(0.55, 0.5) * u, c + Vector2(-0.55, 0.5) * u, c + Vector2(-0.38, 0.35) * u,
				c + Vector2(-0.32, -0.2) * u, c + Vector2(-0.18, -0.7) * u])
			ci.draw_polyline(bell, col, 2.5, false)
			ci.draw_circle(c + Vector2(0, 0.66) * u, u * 0.12, col)
			for k in 2:
				var rr := u * (0.95 + 0.3 * float(k))
				ci.draw_arc(c + Vector2(0, -0.05) * u, rr, -0.5, 0.5, 8, Color(col, 0.7 - 0.25 * float(k)), 2.0, false)
				ci.draw_arc(c + Vector2(0, -0.05) * u, rr, PI - 0.5, PI + 0.5, 8, Color(col, 0.7 - 0.25 * float(k)), 2.0, false)
		&"step":
			for k in 2:
				var x := (float(k) * 0.55 - 0.15) * u
				ci.draw_polyline(PackedVector2Array([c + Vector2(x - 0.35 * u, -0.6 * u), c + Vector2(x + 0.25 * u, 0), c + Vector2(x - 0.35 * u, 0.6 * u)]), col, 3.0, false)
			for k in 3:
				ci.draw_circle(c + Vector2(-u * (0.7 + 0.28 * float(k)), 0), u * (0.09 - 0.02 * float(k)), Color(col, 0.7 - 0.2 * float(k)))
		_:
			if not Icons.draw(self, String(g), c, u, col):
				ci.draw_circle(c, u * 0.4, col)
