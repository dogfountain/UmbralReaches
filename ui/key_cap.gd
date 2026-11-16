extends Control
## A painted control-prompt cap (art: ui/icons/key, tools/icon_kit/keys.py): the bound key's name set in Cinzel on a
## slate cap in a bronze skirt, the mouse with the meant button lit, a pad's face button or thumbstick. A cap grows
## sideways for a long name (Shift, Space): its two ends are drawn whole and its plain middle stretched.
## Build one with `make(art, label, height)`, or a whole line with `line(text, ...)`, where {action} tokens become caps
## of whatever that action is bound to now (rebinding-proof, keyboard or pad by the device in hand):
##   "{move} Move   {look} Look   {sprint} Sprint"  ->  [W][A][S][D] Move  (mouse) Look  [SHIFT] Sprint
## Load by path (no class_name): const KeyCap := preload("res://ui/key_cap.gd")

const UIType := preload("res://ui/type.gd")
const INK := Color(0.96, 0.9, 0.78)
const DIM := Color(0.04, 0.03, 0.02, 0.9)
const TOKEN := "\\{([a-z_0-9]+)\\}"

var art := "cap"
var label := ""
var cap_h := 38.0


static func make(art_id: String, text: String, height := 38.0) -> Control:
	var c: Control = (load("res://ui/key_cap.gd") as GDScript).new()
	c.set("art", art_id)
	c.set("label", text)
	c.set("cap_h", height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _ready() -> void:
	update_minimum_size()


func _font_px() -> int:
	return maxi(10, roundi(cap_h * (0.44 if label.length() <= 2 else 0.34)))


func _get_minimum_size() -> Vector2:
	if art != "cap":
		var tex := IconArt.art("key", art)
		var asp := 1.0 if tex == null else float(tex.get_width()) / float(tex.get_height())
		return Vector2(cap_h * asp * (0.66 if art.begins_with("mouse") else 1.0), cap_h)
	var f := UIType.title()
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_px()).x if f else 10.0
	return Vector2(maxf(cap_h, tw + cap_h * 0.62), cap_h)


func _draw() -> void:
	var tex := IconArt.art("key", art)
	var r := Rect2(Vector2.ZERO, size)
	if tex == null:
		draw_rect(r, Color(0.1, 0.08, 0.06, 0.9))
		draw_rect(r, Color(0.7, 0.5, 0.26), false, 1.5)
	elif art == "cap" and r.size.x > r.size.y * 1.02:
		# the ends whole, the plain middle stretched
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var e := r.size.y * 0.42
		var se := tw * 0.42
		draw_texture_rect_region(tex, Rect2(r.position, Vector2(e, r.size.y)), Rect2(0, 0, se, th))
		draw_texture_rect_region(tex, Rect2(r.position + Vector2(e, 0), Vector2(r.size.x - 2.0 * e, r.size.y)), Rect2(se, 0, tw - 2.0 * se, th))
		draw_texture_rect_region(tex, Rect2(Vector2(r.end.x - e, r.position.y), Vector2(e, r.size.y)), Rect2(tw - se, 0, se, th))
	elif art.begins_with("mouse"):
		# the painting's mouse fills 0.56 x 0.84 of it: drawn square and a little over the cap's height, centred on a narrow cell
		var h := r.size.y * 1.12
		draw_texture_rect(tex, Rect2(Vector2((r.size.x - h) * 0.5, (r.size.y - h) * 0.5), Vector2(h, h)), false)
	else:
		draw_texture_rect(tex, r, false)
	if label == "":
		return
	var f := UIType.title()
	if f == null:
		return
	var px := _font_px()
	var sz := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var at := Vector2((r.size.x - sz.x) * 0.5, r.size.y * 0.47 + (f.get_ascent(px) - f.get_descent(px)) * 0.5)
	draw_string(f, at + Vector2(1.5, 1.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, DIM)
	draw_string(f, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, INK)


# --- what a binding looks like -------------------------------------------------------------------------------

## [art, label] for one input event.
static func for_event(ev: InputEvent) -> Array:
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return ["mouse_l", ""]
			MOUSE_BUTTON_RIGHT:
				return ["mouse_r", ""]
			MOUSE_BUTTON_MIDDLE:
				return ["mouse_m", ""]
		return ["cap", InputSetup.event_name(ev).replace("Mouse ", "M")]
	if ev is InputEventJoypadButton:
		var b := (ev as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_LEFT_STICK:
			return ["stick", "L"]
		if b == JOY_BUTTON_RIGHT_STICK:
			return ["stick", "R"]
		if b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
			return ["button", InputSetup.event_name(ev)]
		return ["cap", InputSetup.event_name(ev).replace("D-pad ", "")]
	if ev is InputEventJoypadMotion:
		return ["cap", InputSetup.event_name(ev)]
	var name := InputSetup.event_name(ev)
	return ["cap", {"Escape": "Esc", "Control": "Ctrl", "BackSpace": "Bksp"}.get(name, name)]


## The caps for an action as bound now ([[art, label], ...]); "move" and "look" are the sticks / the four keys / the mouse.
static func for_action(action: String, pad := false) -> Array:
	if action == "move":
		if pad:
			return [["stick", "L"]]
		var out: Array = []
		for a: String in ["move_forward", "move_left", "move_back", "move_right"]:
			var ev := InputSetup.first_event(a, "key")
			out.append(["cap", InputSetup.event_name(ev) if ev else "?"])
		return out
	if action == "look":
		return [["stick", "R"]] if pad else [["mouse", ""]]
	var e := InputSetup.first_event(action, "pad" if pad else "key")
	if e == null and not pad:
		e = InputSetup.first_event(action, "pad")
	return [for_event(e)] if e != null else [["cap", "?"]]


## A prompt line: the text with each {action} drawn as its caps, the words between in the body serif.
static func line(text: String, pad := false, height := 36.0, px := 23, col := INK) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var re := RegEx.create_from_string(TOKEN)
	var at := 0
	for m in re.search_all(text):
		_words(row, text.substr(at, m.get_start() - at), px, col)
		for c: Array in for_action(m.get_string(1), pad):
			row.add_child(make(String(c[0]), String(c[1]), height))
		at = m.get_end()
	_words(row, text.substr(at), px, col)
	return row


static func _words(row: HBoxContainer, s: String, px: int, col: Color) -> void:
	if s.strip_edges() == "":
		if s != "" and row.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(px * 0.6, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
		return
	var l := Label.new()
	l.text = s.strip_edges()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UIType.body())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if s.begins_with(" ") and row.get_child_count() > 0:
		var g := Control.new()
		g.custom_minimum_size = Vector2(px * (1.4 if s.begins_with("   ") else 0.25), 0)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(g)
	row.add_child(l)
	if s.ends_with(" "):
		var g2 := Control.new()
		g2.custom_minimum_size = Vector2(px * (1.4 if s.ends_with("   ") else 0.25), 0)
		g2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(g2)


static func has_tokens(text: String) -> bool:
	return RegEx.create_from_string(TOKEN).search(text) != null


## The same line as plain words ("{jump} Jump" -> "Space Jump"): tests, logs and the narration fallback.
static func plain(text: String, pad := false) -> String:
	var re := RegEx.create_from_string(TOKEN)
	var out := text
	for m in re.search_all(text):
		var names: Array[String] = []
		for c: Array in for_action(m.get_string(1), pad):
			var lbl := String(c[1])
			names.append(lbl if lbl != "" else {"mouse_l": "LMB", "mouse_r": "RMB", "mouse_m": "MMB", "mouse": "Mouse"}.get(String(c[0]), "?"))
		out = out.replace(m.get_string(0), " ".join(names))
	return out
