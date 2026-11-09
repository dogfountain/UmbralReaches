extends Control
## The experience bar: a forged bar seated under the hotbar and as wide as its plate, shown only once the
## game keeps experience. Ten notches, the fill in lantern gold, a pale rested stretch past it when one
## exists, and the numbers set inside it for a few seconds after a gain.
##
## Reads (first found, all optional; re-looked for twice a second):
##   the Hearth (group "hearth", core/life/progression/hearth.gd): xp_info() -> {level, into, need,
##     frac, rested_frac, capped, last_gain, last_why} and its xp_changed signal (level.gd documents it)
##   player.xp_info() / a node in group "progression" with xp_info() -> {level, xp, next, rested}
##   player (or Travel) properties: xp + (xp_next | xp_max | xp_to_next), level
## Added by ui/hud.gd. Hidden while paused and under the loading screen.

const LANTERN := Color("#FFB347")
const RIM := Color(0.62, 0.45, 0.2)
const INK := Color(0.93, 0.88, 0.8)
const H := 26.0
const BOTTOM := 8.0
const Forge := preload("res://ui/hud_forge.gd")
const Med := preload("res://ui/medieval_style.gd")

var _font: Font
var _info := {}
var _scan := 0.0
var _alpha := 0.0
var _shown := 0.0              ## eased fill
var _last_xp := -1.0
var _num_t := 0.0
var _gain := 0.0
var _dirty := true
var _num_was := false          ## the number was up last frame: one more redraw clears it
var _alpha_drawn := -1.0
var _span := 0.0
var _hotbar: Hotbar


func _ready() -> void:
	name = "XpBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_top = -H - BOTTOM
	offset_bottom = -BOTTOM
	_fit(560.0)
	_font = load("res://ui/fonts/Cinzel.ttf")


## As wide as the hotbar's plate (its finials stand outside), centred like it.
func _fit(w: float) -> void:
	if is_equal_approx(w, _span):
		return
	_span = w
	offset_left = -w * 0.5
	offset_right = w * 0.5
	_dirty = true


func _process(delta: float) -> void:
	if not is_instance_valid(_hotbar):
		_hotbar = get_parent().get_node_or_null("Hotbar") as Hotbar if get_parent() else null
	if _hotbar != null and _hotbar.span() > 0.0:
		_fit(_hotbar.span())
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		var fresh := _read()
		if fresh != _info:
			_dirty = true                # level, rested stretch or a cap changed
		_info = fresh
	var zone := get_tree().current_scene
	var hidden := _info.is_empty() or get_tree().paused or (zone != null and zone.get_node_or_null("LoadingScreen") != null)
	_alpha = move_toward(_alpha, 0.0 if hidden else 1.0, delta * 4.0)
	modulate.a = _alpha
	visible = _alpha > 0.0
	if not visible:
		return
	if _info.is_empty():
		return
	var xp := float(_info.xp) + 100000.0 * float(_info.get("level", 0))     # monotonic across a level-up
	if _last_xp >= 0.0 and xp > _last_xp + 0.001:
		_gain = float(_info.get("last_gain", xp - _last_xp))
		_num_t = 3.0
	_last_xp = xp
	_num_t = maxf(0.0, _num_t - delta)
	var want := 1.0 if bool(_info.get("capped", false)) else clampf(float(_info.xp) / maxf(float(_info.next), 0.001), 0.0, 1.0)
	var before := _shown
	_shown = want if want < _shown else lerpf(_shown, want, 1.0 - exp(-6.0 * delta))
	# a settled strip waits for the next gain: redraw while the fill moves, the number is up, or it fades
	if _dirty or absf(_shown - before) > 0.000001 or _num_t > 0.0 or _num_was or _alpha < 1.0 or _alpha != _alpha_drawn:
		_dirty = false
		_alpha_drawn = _alpha
		queue_redraw()
	_num_was = _num_t > 0.0


func _read() -> Dictionary:
	var srcs: Array = []
	var p := get_tree().get_first_node_in_group(Groups.PLAYER)
	if p:
		srcs.append(p)
	for g: StringName in [&"hearth", &"progression", &"growth"]:
		var n := get_tree().get_first_node_in_group(g)
		if n:
			srcs.append(n)
	var tr := get_node_or_null("/root/Travel")
	if tr:
		srcs.append(tr)
	for s: Object in srcs:
		if s.has_method("xp_info"):
			var d: Variant = s.call("xp_info")
			if d is Dictionary and (d as Dictionary).has("into") and (d as Dictionary).has("need"):
				var h := d as Dictionary          # the Hearth's shape: progress within the level
				return {"xp": float(h.into), "next": float(h.need), "level": int(h.get("level", -1)),
					"rested": maxf(0.0, float(h.get("rested_frac", 0.0)) - float(h.get("frac", 0.0))) * float(h.need),
					"capped": bool(h.get("capped", false)), "last_gain": int(h.get("last_gain", 0)), "why": String(h.get("last_why", ""))}
			if d is Dictionary and (d as Dictionary).has("xp") and (d as Dictionary).has("next"):
				return d
		if "xp" in s:
			for nk: String in ["xp_next", "xp_max", "xp_to_next"]:
				if nk in s:
					return {"xp": float(s.get("xp")), "next": float(s.get(nk)),
						"level": int(s.get("level")) if "level" in s else -1,
						"rested": float(s.get("xp_rested")) if "xp_rested" in s else 0.0}
	return {}


func _draw() -> void:
	if _info.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	Forge.plate(self, r, 1.0, Color.WHITE, false)
	for sx: float in [0.0, 1.0]:
		Forge.rivet(self, Vector2(lerpf(7.0, size.x - 7.0, sx), size.y * 0.5), 2.2)
	var well := Rect2(Vector2(16.0, 4.0), size - Vector2(32.0, 8.0))
	Forge.trough(self, well)
	var inner := well.grow(-2.0)
	var rest := float(_info.get("rested", 0.0)) / maxf(float(_info.next), 0.001)
	if rest > 0.0:
		var rr := Rect2(inner.position + Vector2(inner.size.x * _shown, 0.0), Vector2(inner.size.x * minf(rest, 1.0 - _shown), inner.size.y))
		Forge.fill(self, rr, Color(0.5, 0.46, 0.9, 0.55), 1.0)
	Forge.fill(self, Rect2(inner.position, Vector2(inner.size.x * _shown, inner.size.y)), LANTERN.darkened(0.38), 1.0)
	for i in range(1, 10):
		var x := inner.position.x + inner.size.x * float(i) / 10.0
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0.02, 0.012, 0.01, 0.8), 1.5)
	if _num_t > 0.0 and _font:
		var a := clampf(_num_t, 0.0, 1.0)
		var lv := int(_info.get("level", -1))
		var why := String(_info.get("why", ""))
		var t := "%s%d / %d   +%d%s" % ["Level %d   ·   " % lv if lv >= 0 else "", roundi(float(_info.xp)), roundi(float(_info.next)), roundi(_gain), ("  " + why) if why != "" else ""]
		var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		Forge.tab(self, Rect2(size.x * 0.5 - tw * 0.5 - 12.0, well.position.y + 1.0, tw + 24.0, well.size.y - 2.0), a)
		Forge.label(self, _font, Vector2(0, well.position.y + well.size.y * 0.5 + 5.5), t, 14, Color(INK, a), HORIZONTAL_ALIGNMENT_CENTER, size.x, 3)
