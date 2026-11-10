extends CanvasLayer
## Encounters' own screen layer (layer 5: over the 3D and the colour grade, under the HUD at 10):
##   - the Gloom tide's sky: a darkening that hangs from the top of the screen, a slow vignette and
##     drifting smoke -- an overlay, the grade is untouched. Cold blue-violet in the Deeper Night.
##   - a banner for the tide, ambushes and bounties, a tide status line under the Gloom bar
##   - a small bar for a named elite you are fighting (under where a boss bar sits)
##   - the bounty-note reader (a second layer at 12, over the HUD)
##   - the Deeper Night mark beside the Gloom meter
## Costs nothing while the night is quiet: the overlay is hidden at amount 0.

const TextDirector := preload("res://ui/text_director.gd")
const TITLE_FONT := "res://ui/fonts/Cinzel.ttf"
const SKY_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
uniform vec3 tint = vec3(0.05, 0.02, 0.09);
uniform float t = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 uv = UV;
	float top = pow(1.0 - uv.y, 1.6);                         // the sky darkens from above
	vec2 c = uv - vec2(0.5, 0.55);
	float vig = smoothstep(0.25, 0.85, length(c * vec2(1.1, 1.3)));
	float smoke = n(uv * vec2(5.0, 3.0) + vec2(t * 0.05, -t * 0.03)) * 0.6 + n(uv * vec2(11.0, 7.0) - vec2(t * 0.08, 0.0)) * 0.4;
	float a = amount * (0.34 * top + 0.22 * vig + 0.06 + 0.08 * smoke * (0.4 + top));
	COLOR = vec4(tint, clamp(a, 0.0, 0.62));
}
"""

const FIGHT_WAIT := 6.0
const DUSK := Color(0.82, 0.74, 1.0)
const EMBER := Color(1.0, 0.72, 0.42)
const COLD := Color(0.62, 0.82, 1.0)

var _sky: ColorRect
var _sky_mat: ShaderMaterial
var _amount := 0.0
var _target := 0.0
var _t := 0.0
var _banner: Label
var _banner_sub: Label
var _banner_tw: Tween
var _bq: Array[Array] = []         ## banners waiting for the text director: [text, sub, colour]
var _bq_wait := 0.0
var _status: Label
var _ng: Label
var _elite_box: Control
var _elite_name: Label
var _elite_bar: ProgressBar
var _reader_layer: CanvasLayer
var _reader: PanelContainer
var _r_title: Label
var _r_body: Label
var _r_foot: Label
var _r_src: Node3D
var deeper := false


func _ready() -> void:
	layer = 5
	name = "EncounterHud"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font: Font = load(TITLE_FONT)
	_sky = ColorRect.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	_sky_mat.shader = sh
	_sky.material = _sky_mat
	_sky.visible = false
	add_child(_sky)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_banner = _label(root, "", 40, DUSK, font, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 400
	_banner.offset_bottom = 450
	_banner.offset_left = -800
	_banner.offset_right = 800
	_banner.modulate.a = 0.0
	_banner_sub = _label(root, "", 22, Color(0.8, 0.78, 0.92), font, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner_sub.offset_top = 452
	_banner_sub.offset_bottom = 486
	_banner_sub.offset_left = -800
	_banner_sub.offset_right = 800
	_banner_sub.modulate.a = 0.0
	_status = _label(root, "", 18, DUSK, font)
	_status.position = Vector2(48, 128)
	_status.size = Vector2(700, 26)
	_status.visible = false
	_ng = _label(root, "", 17, COLD, font)
	_ng.position = Vector2(150, 38)
	_ng.size = Vector2(400, 24)
	_ng.visible = false
	_elite_box = VBoxContainer.new()
	_elite_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_elite_box.offset_left = -220
	_elite_box.offset_right = 220
	_elite_box.offset_top = 96
	_elite_box.offset_bottom = 140
	_elite_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_elite_box.visible = false
	root.add_child(_elite_box)
	_elite_name = _label(_elite_box, "", 19, EMBER, font, HORIZONTAL_ALIGNMENT_CENTER)
	_elite_bar = ProgressBar.new()
	_elite_bar.show_percentage = false
	_elite_bar.custom_minimum_size = Vector2(440, 8)
	_elite_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.02, 0.07, 0.8)
	bg.border_color = Color(0.5, 0.35, 0.6, 0.8)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.72, 0.3, 0.16)
	_elite_bar.add_theme_stylebox_override("background", bg)
	_elite_bar.add_theme_stylebox_override("fill", fg)
	_elite_box.add_child(_elite_bar)
	_build_reader(font)


func _label(parent: Node, text: String, size: int, col: Color, font: Font, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


func _build_reader(font: Font) -> void:
	_reader_layer = CanvasLayer.new()
	_reader_layer.layer = 12
	add_child(_reader_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reader_layer.add_child(root)
	_reader = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.07, 0.06, 0.92)
	box.border_color = Color(0.55, 0.42, 0.3, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 18
	box.content_margin_bottom = 16
	_reader.add_theme_stylebox_override("panel", box)
	_reader.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_reader.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_reader.offset_left = -440
	_reader.offset_right = 440
	_reader.offset_bottom = -232
	_reader.offset_top = -232
	_reader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reader)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reader.add_child(col)
	_r_title = _label(col, "", 28, EMBER, font)
	_r_body = _label(col, "", 22, Color(0.9, 0.86, 0.8), null)
	_r_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_r_body.custom_minimum_size = Vector2(820, 0)
	_r_body.add_theme_constant_override("line_spacing", 5)
	_r_foot = _label(col, "", 15, Color(0.65, 0.6, 0.7), font)
	_reader.visible = false


# --- the tide sky -------------------------------------------------------------------------------

## 0 = clear, 1 = full tide. Eased over a few seconds.
func set_tide(level: float) -> void:
	_target = clampf(level, 0.0, 1.0)


func set_deeper(level: int) -> void:
	deeper = level > 0
	_ng.visible = deeper
	_ng.text = "·  THE DEEPER NIGHT" + (" " + ["", "", "II", "III", "IV", "V"][clampi(level, 0, 5)] if level > 1 else "")
	_sky_mat.set_shader_parameter("tint", Vector3(0.02, 0.05, 0.11) if deeper else Vector3(0.05, 0.02, 0.09))


func status(text: String) -> void:
	_status.visible = text != ""
	_status.text = text
	_status.add_theme_color_override("font_color", COLD if deeper else DUSK)


func _process(delta: float) -> void:
	_t += delta
	if not _bq.is_empty():
		_bq_wait += delta
		_pump_banners()
	_amount = move_toward(_amount, _target, delta / 5.0)
	_sky.visible = _amount > 0.002
	if _sky.visible:
		_sky_mat.set_shader_parameter("amount", _amount)
		_sky_mat.set_shader_parameter("t", _t)
	if _status.visible:
		_status.modulate.a = 0.65 + 0.35 * sin(_t * 3.0)
	if _reader.visible and (not is_instance_valid(_r_src) or _too_far()):
		close_note()


# --- banners --------------------------------------------------------------------------------

## Tide / ambush / bounty / guardian banners are quest-class lines (priority 2) in the text director's
## banner lane: they wait for narration, a dialogue box and the banner on screen. A lock-on fight also
## holds them, but not past FIGHT_WAIT seconds (an encounter is a fight; the line must still land).
## The queue keeps three. No director (a bare test scene): drawn now.
func banner(text: String, sub := "", col := Color(0, 0, 0, 0)) -> void:
	if TextDirector.of(self) == null:
		_show_banner(text, sub, col)
		return
	while _bq.size() >= 3:
		_bq.pop_front()
	_bq.append([text, sub, col])
	_pump_banners()


func _pump_banners() -> void:
	var td := TextDirector.of(self)
	if td == null:
		for b in _bq:
			_show_banner(String(b[0]), String(b[1]), b[2])
		_bq.clear()
		return
	var ok: bool = td.can_begin(&"quest")
	if not ok and _bq_wait >= FIGHT_WAIT and td.in_fight() and not td.narration_or_dialogue() and not td.is_up(&"quest"):
		ok = true                                      # locked on that long: draw it anyway
	if ok:
		var b: Array = _bq.pop_front()
		_bq_wait = 0.0
		td.begin(&"quest", 5.6, Rect2(), true)
		_show_banner(String(b[0]), String(b[1]), b[2])


func _show_banner(text: String, sub: String, col: Color) -> void:
	_banner.text = text
	_banner_sub.text = sub
	var c := col if col.a > 0.0 else (COLD if deeper else DUSK)
	_banner.add_theme_color_override("font_color", c)
	if _banner_tw:
		_banner_tw.kill()
	_banner_tw = create_tween().set_parallel(true)
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.6).from(0.0)
	_banner_tw.tween_property(_banner_sub, "modulate:a", 1.0, 0.9).from(0.0)
	_banner_tw.chain().tween_interval(3.2)
	_banner_tw.chain().tween_property(_banner, "modulate:a", 0.0, 1.4)
	_banner_tw.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 1.4)


## The banner raised last: the one waiting for the text director, else the one on screen.
func banner_text() -> String:
	return String(_bq.back()[0]) if not _bq.is_empty() else _banner.text


# --- the elite bar ------------------------------------------------------------------------------

func show_elite(title: String, hp: float, max_hp: float) -> void:
	_elite_box.visible = true
	_elite_name.text = TextDirector.sentence(title)
	_elite_name.add_theme_color_override("font_color", COLD if deeper else EMBER)
	_elite_bar.max_value = maxf(max_hp, 1.0)
	_elite_bar.value = hp


func hide_elite() -> void:
	_elite_box.visible = false


func elite_shown() -> bool:
	return _elite_box.visible


# --- the note reader ----------------------------------------------------------------------------

func show_note(title: String, body: String, foot: String, src: Node3D) -> void:
	_r_title.text = title
	_r_body.text = body
	_r_foot.text = foot
	_r_src = src
	_reader.visible = true
	_reader.modulate.a = 0.0
	create_tween().tween_property(_reader, "modulate:a", 1.0, 0.3)


func close_note() -> void:
	_reader.visible = false
	_r_src = null


func note_open() -> bool:
	return _reader.visible


func note_title() -> String:
	return _r_title.text if _reader.visible else ""


func _too_far() -> bool:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return p != null and p.global_position.distance_to(_r_src.global_position) > 4.5
