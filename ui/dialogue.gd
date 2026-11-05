extends CanvasLayer
## The dialogue box (core/story/story.gd drives it; docs/STORY.md).
##   open(name, portrait opts) -> line(name, text, choices) ... -> close()
## A panel along the bottom: a live portrait of the speaker (his own DwarfRig in a small SubViewport,
## jaw moving while the line types), a name plate, the line typed out letter by letter, and up to
## four choices. The world pauses while it is open (get_tree().paused) and the mouse is freed.
##   E / Space / Enter / click: finish the line, then continue    1-4: pick a choice
##   W/S or up/down: move the choice cursor, E picks it          Esc: close
## narrate(lines): subtitles without the box and without pausing (the arrival, the ending).
## No class_name: preload by path.

signal advanced
signal chosen(index: int)
signal closed

const UIType := preload("res://ui/type.gd")
const LANTERN := Color("#FFB347")
const QUIET := Color(0.78, 0.8, 0.9)
const CPS := 52.0                          ## typed characters per second
const DwarfRigScript := preload("res://core/npc/dwarf_rig.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const UiSound := preload("res://ui/ui_sound.gd")   ## quiet menu sounds (F)
const VOICE_DB := -6.0                     ## the speaker's line-start gesture (SFX bus; r35: no babble)
var _last_speaker := ""                    ## r35: a new speaker's first line greets ("hah")

var _font: Font
var _root: Control
var _panel: PanelContainer
var _name: Label
var _mood: Label                           ## how the speaker feels about the wanderer (set_mood)
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label
var _portrait: TextureRect
var _vp: SubViewport
var _rig: Node3D
var _rig_key := ""
var _sub: Label
var _sub_queue: Array[String] = []
var _sub_t := 0.0
var _sub_tw: Tween
var _open := false
var _paused_it := false
var _was_captured := false
var _shown := 0.0                          ## characters revealed (float, for the typewriter)
var _total := 0
var _sel := 0
var _buttons: Array[Button] = []
var _t := 0.0
var _voice_p: AudioStreamPlayer
var _voices := {}                          ## speaker name -> voice profile (set_voice)
var _cur_voice := {}
var _syl: Array = []                       ## [character index, pitch mult, dB] per syllable of the line
var _syl_i := 0
var _syl_last := -1.0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://ui/fonts/Cinzel.ttf")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_box()
	_build_subtitles()
	_voice_p = Voice.speaker2d(self)        # plays while the box pauses the world (we are ALWAYS)
	_root.visible = true
	_panel.visible = false


func _build_box() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -720
	_panel.offset_right = 720
	_panel.offset_top = -330
	_panel.offset_bottom = -40
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN      # long menus grow up, never off the screen
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.06, 0.95)
	sb.border_color = Color(1.0, 0.7, 0.28, 0.55)
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 22
	sb.content_margin_right = 26
	sb.content_margin_top = 18
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_panel.add_child(row)
	# portrait: the speaker's own rig, lit by a candle, in a framed square
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	fsb.border_color = Color(1.0, 0.7, 0.28, 0.4)
	fsb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.custom_minimum_size = Vector2(250, 250)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	_vp = SubViewport.new()
	_vp.size = Vector2i(256, 256)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_portrait_set()
	_portrait = TextureRect.new()
	_portrait.texture = _vp.get_texture()
	_portrait.custom_minimum_size = Vector2(246, 246)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	row.add_child(col)
	_name = Label.new()
	_name.add_theme_font_override("font", _font)
	_name.add_theme_font_size_override("font_size", 30)
	_name.add_theme_color_override("font_color", LANTERN)
	_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_name.add_theme_constant_override("shadow_offset_x", 2)
	_name.add_theme_constant_override("shadow_offset_y", 2)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	col.add_child(name_row)
	name_row.add_child(_name)
	_mood = Label.new()
	_mood.add_theme_font_override("font", UIType.body())
	_mood.add_theme_font_size_override("font_size", 18)
	_mood.add_theme_color_override("font_color", Color(QUIET, 0.6))
	_mood.size_flags_vertical = Control.SIZE_SHRINK_END
	_mood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(_mood)
	var rule := ColorRect.new()
	rule.color = Color(1.0, 0.7, 0.28, 0.35)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 96)
	_text.add_theme_font_override("normal_font", UIType.body())
	_text.add_theme_font_size_override("normal_font_size", 27)
	_text.add_theme_color_override("default_color", Color(0.93, 0.9, 0.84))
	_text.add_theme_constant_override("line_separation", 6)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	col.add_child(_choices)
	_hint = Label.new()
	_hint.add_theme_font_override("font", UIType.body())
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(QUIET, 0.7))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.size_flags_vertical = Control.SIZE_SHRINK_END
	col.add_child(_hint)


func _build_subtitles() -> void:
	_sub = Label.new()
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.offset_left = -820
	_sub.offset_right = 820
	_sub.offset_top = -290
	_sub.offset_bottom = -230
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_font_override("font", UIType.body())   # r30: Cinzel is for names and titles
	_sub.add_theme_font_size_override("font_size", 30)
	_sub.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_sub.add_theme_constant_override("shadow_offset_x", 2)
	_sub.add_theme_constant_override("shadow_offset_y", 2)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.modulate.a = 0.0
	_root.add_child(_sub)


# --- portrait ---------------------------------------------------------------------------------

func _portrait_set() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.035, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.42, 0.62)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.64, 0.34)
	key.light_energy = 2.2
	key.omni_range = 3.0
	key.position = Vector3(0.5, 1.5, -0.7)
	_vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.5, 0.7, 1.0)
	rim.light_energy = 1.1
	rim.omni_range = 3.0
	rim.position = Vector3(-0.6, 1.7, 0.6)
	_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 26.0
	_vp.add_child(cam)
	cam.position = Vector3(0.12, 1.42, -0.95)
	cam.look_at_from_position(cam.position, Vector3(0.0, 1.32, 0.0))
	cam.current = true


func _portrait_rig(opts: Dictionary) -> void:
	var key := str(opts)
	if key == _rig_key and is_instance_valid(_rig):
		return
	if is_instance_valid(_rig):
		_rig.queue_free()
	_rig = null
	_rig_key = key
	if opts.is_empty():
		return
	_rig = DwarfRigScript.make(opts)
	_vp.add_child(_rig)


# --- the box ----------------------------------------------------------------------------------

func is_open() -> bool:
	return _open


func open(speaker: String, portrait_opts: Dictionary = {}) -> void:
	_portrait_rig(portrait_opts)
	_portrait.get_parent().visible = not portrait_opts.is_empty()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_name.text = speaker
	_mood.text = ""
	_panel.visible = true
	_open = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_paused_it = not get_tree().paused
	get_tree().paused = true
	Events.interact_hint.emit("")


func close() -> void:
	if not _open:
		return
	_open = false
	_voice_stop()
	_last_speaker = ""
	_panel.visible = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _paused_it:
		get_tree().paused = false
	_paused_it = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## How the speaker feels about the wanderer (quest_book.gd attitude, -5..5): a quiet word by the
## name ("" for strangers and the indifferent). The drivers set it when a conversation opens.
func set_mood(att: int) -> void:
	var w := ""
	if att <= -3:
		w = "will not forgive you"
	elif att <= -1:
		w = "wary of you"
	elif att >= 4:
		w = "trusts you"
	elif att >= 2:
		w = "warm toward you"
	elif att == 1:
		w = "friendly"
	_mood.text = w
	_mood.add_theme_color_override("font_color", Color(0.95, 0.6, 0.5, 0.75) if att < 0 else Color(1.0, 0.78, 0.5, 0.7))


## Show a line. `choices` empty = continue on E.
func line(speaker: String, text: String, choices: Array[String] = []) -> void:
	_name.text = speaker
	_text.text = text
	_total = _text.get_total_character_count()
	_voice_stop()
	_cur_voice = _voices.get(speaker, {})
	if _cur_voice.is_empty():
		_cur_voice = Voice.profile("dwarf", hash(speaker))
	# r35: one human sound as the line starts (npc_voice.gd gesture_for), then the text types in
	# silence. It babbled a syllable per vowel group before, which read as comic under grim lines.
	_syl.clear()
	_syl_i = 0
	if speaker != "":
		var first := speaker != _last_speaker
		Voice.gesture(_voice_p, _cur_voice, Voice.gesture_for(_text.get_parsed_text(), first), VOICE_DB)
	_last_speaker = speaker
	_shown = 0.0
	_text.visible_characters = 0
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_sel = 0
	for i in choices.size():
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, choices[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UIType.body())
		b.add_theme_font_size_override("font_size", 25)
		b.add_theme_color_override("font_color", QUIET)
		b.add_theme_color_override("font_hover_color", LANTERN)
		b.mouse_entered.connect(func() -> void:
			_sel = i
			_mark())
		b.pressed.connect(func() -> void: _pick(i))
		b.visible = false
		_choices.add_child(b)
		_buttons.append(b)
	_mark()
	_refresh_hint()


func typing() -> bool:
	return _open and int(_shown) < _total


func finish_line() -> void:
	if typing():
		_voice_stop()                        # skipped: the voice stops with the text
	_shown = float(_total)
	_text.visible_characters = -1
	for b in _buttons:
		b.visible = true
	_refresh_hint()


func choice_count() -> int:
	return _buttons.size()


func _refresh_hint() -> void:
	var k := Interactable.prompt_key()
	if typing():
		_hint.text = "[%s]  skip" % k
	elif _buttons.is_empty():
		_hint.text = "[%s]  continue      [Esc]  leave" % k
	else:
		_hint.text = "[1-%d] or [%s]  choose      [Esc]  leave" % [_buttons.size(), k]


func _mark() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		var task := b.text.contains("◆")
		b.add_theme_color_override("font_color", LANTERN if i == _sel else (Color(0.95, 0.82, 0.6) if task else QUIET))
		b.text = ("›  " if i == _sel else "    ") + b.text.trim_prefix("›  ").trim_prefix("    ")


func _pick(i: int) -> void:
	if typing() or i < 0 or i >= _buttons.size():
		return
	UiSound.play(self, "confirm")
	chosen.emit(i)


## Continue: finish the typing, else advance (lines without choices) or pick the marked choice.
func press() -> void:
	if not _open:
		return
	if typing():
		finish_line()
	elif _buttons.is_empty():
		advanced.emit()
	else:
		_pick(_sel)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var handled := true
	if event.is_action_pressed("toggle_settings"):
		UiSound.play(self, "back")
		close()
		closed.emit()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		press()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# clicks on a choice button reach the button (GUI input runs after _input); elsewhere: continue
		if _buttons.is_empty() or typing():
			press()
		else:
			handled = false
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc >= KEY_1 and kc <= KEY_9:
			_pick(kc - KEY_1)
		elif not _buttons.is_empty() and (event.is_action_pressed("move_back") or event.is_action_pressed("ui_down")):
			_sel = (_sel + 1) % _buttons.size()
			UiSound.play(self, "move")
			_mark()
		elif not _buttons.is_empty() and (event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up")):
			_sel = (_sel + _buttons.size() - 1) % _buttons.size()
			UiSound.play(self, "move")
			_mark()
		elif event.is_action_pressed("inventory"):
			pass                               # no satchel over a conversation
		else:
			handled = false
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var jb := (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_DPAD_DOWN and not _buttons.is_empty():
			_sel = (_sel + 1) % _buttons.size()
			_mark()
		elif jb == JOY_BUTTON_DPAD_UP and not _buttons.is_empty():
			_sel = (_sel + _buttons.size() - 1) % _buttons.size()
			_mark()
		elif jb == JOY_BUTTON_B:
			close()
			closed.emit()
		else:
			handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if _open:
		if typing():
			_shown = minf(_shown + delta * CPS, float(_total))
			_text.visible_characters = int(_shown)
			_voice_tick()
			if not typing():
				finish_line()
		_animate_portrait()
	_subtitles(delta)


# --- the speaker's voice ------------------------------------------------------------------------

## The voice for `speaker` (npc_voice.gd profile). An empty profile falls back to one made from the
## name, so every speaker still sounds like someone in particular.
func set_voice(prof: Dictionary, speaker := "") -> void:
	var who := speaker if speaker != "" else _name.text
	_voices[who] = prof if not prof.is_empty() else Voice.profile("dwarf", hash(who))


## Called as the line types: voice each syllable the text has reached (spaced so a fast line does
## not turn into a buzz; the profile's pace sets the spacing).
func _voice_tick() -> void:
	if _syl_i >= _syl.size():
		return
	var now := Time.get_ticks_msec() * 0.001
	var gap := 0.055 / float(_cur_voice.get("pace", 1.0))
	while _syl_i < _syl.size() and int(_syl[_syl_i][0]) <= int(_shown):
		var s: Array = _syl[_syl_i]
		_syl_i += 1
		if now - _syl_last >= gap:
			_syl_last = now
			Voice.syllable(_voice_p, _cur_voice, float(s[1]), float(s[2]))


func _voice_stop() -> void:
	_syl_i = _syl.size()
	if is_instance_valid(_voice_p) and _voice_p.playing:
		_voice_p.stop()


func _animate_portrait() -> void:
	# the story director's live layer (npc_life.gd) drives it when it can: two drivers fought over the jaw
	if not is_instance_valid(_rig) or not _rig.has_method("q") or _rig.has_meta("live"):
		return
	var jaw := -0.08 * absf(sin(_t * 9.0 + sin(_t * 3.1) * 2.0)) if typing() else 0.0
	_rig.call("q", 4, Quaternion(Vector3.RIGHT, jaw))
	_rig.call("q", 3, Quaternion(Vector3.UP, sin(_t * 0.7) * 0.06) * Quaternion(Vector3.RIGHT, sin(_t * 1.1) * 0.03 + (0.04 if typing() else 0.0)))
	_rig.call("q", 2, Quaternion(Vector3.RIGHT, sin(_t * 1.6) * 0.015))
	_rig.call("apply")


# --- narration (no box, no pause) -------------------------------------------------------------

func narrate(lines: Array) -> void:
	for l in lines:
		_sub_queue.append(String(l))


func narrating() -> bool:
	return not _sub_queue.is_empty() or _sub_t > 0.0


func _subtitles(delta: float) -> void:
	# a conversation box covers the subtitles' place: they wait (not lost) until it closes
	_sub.visible = not _open
	if _open:
		return
	if _sub_t > 0.0:
		_sub_t -= delta
		var n := _sub.text.length()
		_sub.visible_characters = mini(n, int((4.2 + float(n) / CPS * 1.2 - _sub_t) * CPS * 0.8))
		if _sub_t <= 0.6 and _sub.modulate.a > 0.0 and (_sub_tw == null or not _sub_tw.is_running()):
			_sub_tw = create_tween()
			_sub_tw.tween_property(_sub, "modulate:a", 0.0, 0.55)
		return
	if _sub_queue.is_empty():
		return
	_sub.text = _sub_queue.pop_front()
	_sub.visible_characters = 0
	_sub_t = 4.2 + float(_sub.text.length()) / CPS * 1.2
	if _sub_tw:
		_sub_tw.kill()
	_sub_tw = create_tween()
	_sub_tw.tween_property(_sub, "modulate:a", 1.0, 0.4)
