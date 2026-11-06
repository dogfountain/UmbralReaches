extends Control
## The experience bar (r33, after WoW's): a thin engraved strip along the very bottom of the screen,
## shown only once the game keeps experience. Ten notches, the fill in lantern gold, a pale rested
## stretch past it when one exists, and the numbers on it for a few seconds after a gain.
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
const H := 9.0

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


func _ready() -> void:
	name = "XpBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -H - 4.0
	offset_bottom = -4.0
	offset_left = 8.0
	offset_right = -8.0
	_font = load("res://ui/fonts/Cinzel.ttf")


func _process(delta: float) -> void:
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
	draw_rect(r.grow(2.0), Color(0.03, 0.022, 0.02, 0.85))
	var rest := float(_info.get("rested", 0.0)) / maxf(float(_info.next), 0.001)
	if rest > 0.0:
		draw_rect(Rect2(Vector2(size.x * _shown, 1), Vector2(size.x * minf(rest, 1.0 - _shown), size.y - 2.0)), Color(0.55, 0.5, 0.95, 0.5))
	draw_rect(Rect2(Vector2(0, 1), Vector2(size.x * _shown, size.y - 2.0)), Color(LANTERN, 0.92))
	draw_rect(Rect2(Vector2(0, 1), Vector2(size.x * _shown, 2.0)), Color(1, 1, 1, 0.25))
	for i in range(1, 10):
		var x := size.x * float(i) / 10.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.03, 0.02, 0.02, 0.9), 2.0)
	draw_rect(r.grow(2.0), Color(RIM, 0.9), false, 1.0)
	if _num_t > 0.0 and _font:
		var a := clampf(_num_t, 0.0, 1.0)
		var lv := int(_info.get("level", -1))
		var why := String(_info.get("why", ""))
		var t := "%s%d / %d   +%d%s" % ["Level %d   ·   " % lv if lv >= 0 else "", roundi(float(_info.xp)), roundi(float(_info.next)), roundi(_gain), ("  " + why) if why != "" else ""]
		draw_string_outline(_font, Vector2(0, -6), t, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color(0, 0, 0, 0.8 * a))
		draw_string(_font, Vector2(0, -6), t, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(INK, a))
