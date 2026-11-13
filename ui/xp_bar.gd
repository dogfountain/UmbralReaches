extends Control
## The experience bar: a thin forged line along the very bottom edge of the screen, shown only once the
## game keeps experience. Ten faint ticks, a warm gradient fill, a pale rested stretch past it when one
## exists, and the level on a slim plate above its left end (the numbers join it for a few seconds after a gain).
##
## Reads (first found, all optional; re-looked for twice a second):
##   the Hearth (group "hearth", core/life/progression/hearth.gd): xp_info() -> {level, into, need,
##     frac, rested_frac, capped, last_gain, last_why} and its xp_changed signal (level.gd documents it)
##   player.xp_info() / a node in group "progression" with xp_info() -> {level, xp, next, rested}
##   player (or Travel) properties: xp + (xp_next | xp_max | xp_to_next), level
## Added by ui/hud.gd. Hidden while paused and under the loading screen.

const LANTERN := Color("#FFB347")
const INK := Color(0.93, 0.88, 0.8)
const BAR_H := 9.0             ## the line itself, at the 1920x1080 canvas
const TEXT_H := 30.0           ## room above it for the level plate
const H := BAR_H + TEXT_H
const MARGIN := 28.0           ## the plate's distance from the left edge
const PT := 14
const Forge := preload("res://ui/hud_forge.gd")
const Med := preload("res://ui/medieval_style.gd")
const UIType := preload("res://ui/type.gd")

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
var _drawn_at := 0               ## msec of the last redraw
const FramePace := preload("res://core/util/frame_pace.gd")


func _ready() -> void:
	name = "XpBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -H
	offset_bottom = 0.0
	offset_left = 0.0
	offset_right = 0.0
	_font = UIType.body()


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
	# (30 to 40 times a second while it moves, on a frame between physics ticks (FramePace): the fill's ease and
	# the number's fade read the same)
	if _dirty or absf(_shown - before) > 0.000001 or _num_t > 0.0 or _num_was or _alpha < 1.0 or _alpha != _alpha_drawn:
		_dirty = true                            # kept until the due frame draws it
		if FramePace.due(_drawn_at, 0):
			_drawn_at = Time.get_ticks_msec()
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
	var bar := Rect2(0.0, size.y - BAR_H, size.x, BAR_H)
	draw_rect(bar, Color(0.055, 0.036, 0.026, 0.96))
	var inner := Rect2(bar.position + Vector2(0.0, 2.0), bar.size - Vector2(0.0, 2.0))
	var rest := float(_info.get("rested", 0.0)) / maxf(float(_info.next), 0.001)
	if rest > 0.0:
		var rr := Rect2(inner.position + Vector2(inner.size.x * _shown, 0.0), Vector2(inner.size.x * minf(rest, 1.0 - _shown), inner.size.y))
		Forge.fill(self, rr, Color(0.5, 0.46, 0.9, 0.55), 1.0)
	Forge.fill(self, Rect2(inner.position, Vector2(inner.size.x * _shown, inner.size.y)), LANTERN.darkened(0.3), 1.0)
	for i in range(1, 10):
		var x := inner.position.x + inner.size.x * float(i) / 10.0
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0.0, 0.0, 0.0, 0.45), 1.0)
	draw_line(Vector2(0.0, bar.position.y + 0.5), Vector2(size.x, bar.position.y + 0.5), Color(Med.BRONZE, 0.95), 1.0)
	draw_line(Vector2(0.0, bar.position.y + 1.5), Vector2(size.x, bar.position.y + 1.5), Color(0, 0, 0, 0.8), 1.0)
	if not _font:
		return
	var lv := int(_info.get("level", -1))
	var t := "Level %d" % lv if lv >= 0 else ""
	var a := 1.0
	if _num_t > 0.0:
		var why := String(_info.get("why", ""))
		t += ("   ·   " if t != "" else "") + "%d / %d   +%d%s" % [roundi(float(_info.xp)), roundi(float(_info.next)), roundi(_gain), ("  " + why) if why != "" else ""]
	if t == "":
		return
	var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, PT).x
	var pr := Rect2(MARGIN, bar.position.y - 24.0, tw + 24.0, 22.0)
	Forge.tab(self, pr, a)
	Forge.label(self, _font, Vector2(pr.position.x + 12.0, pr.position.y + 16.0), t, PT, Color(INK, a), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
