extends CanvasLayer
## The dialogue box (core/story/story.gd drives it; docs/STORY.md).
##   open(name, portrait opts) -> line(name, text, choices) ... -> close()
## A panel along the bottom: a live portrait of the speaker (his own DwarfRig in a small SubViewport,
## jaw moving while the line types), a name plate, the line typed out letter by letter, and up to
## four choices. The world pauses while it is open (get_tree().paused) and the mouse is freed.
##   interact / Space / Enter / click (pad: interact, A): finish the line, then continue    1-4: pick a choice
##   W/S or up/down (pad: d-pad): move the choice cursor, interact picks it    Esc / Menu (pad: B): close
##   The foot names the keys as bound now (the pad's buttons while the last input was a pad).
## narrate(lines): subtitles without the box and without pausing (the arrival, the ending).
## No class_name: preload by path.

signal advanced
signal chosen(index: int)
signal closed

const Foot := preload("res://ui/foot_hint.gd")
const Access := preload("res://ui/access.gd")
const UIType := preload("res://ui/type.gd")
const TextDirector := preload("res://ui/text_director.gd")
const Med := preload("res://ui/medieval_style.gd")
const LANTERN := Med.GILT
const QUIET := Med.BONE_DIM
const CPS := 52.0                          ## typed characters per second
const DwarfRigScript := preload("res://core/npc/dwarf_rig.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const UiSound := preload("res://ui/ui_sound.gd")   ## quiet menu sounds (F)
const VOICE_DB := -6.0                     ## the speaker's babble under the typing (SFX bus)

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
var _ext: Node3D                   ## a bust handed in by show_portrait()
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
var _solemn := false                      ## a grave line (a death, a grave, a confession): the babble slows, drops and softens
## words that make a line grave (the babble voices stay babble; only their pace, pitch and level follow the matter)
const SOLEMN := ["dead", "died", "death", "grave", "buried", "burial", "mourn", "weep", "wept", "tears", "forgive", "sorry", "sin", "hollow", "lost", "gone", "mother", "father", "nine winters", "never came back", "did not come back", "went up", "the night"]
var _cur_voice := {}
var _syl: Array = []                       ## [character index, pitch mult, dB] per syllable of the line
var _syl_i := 0
var _syl_last := -1.0


func _ready() -> void:
	Settings.input_device_changed.connect(func(_pad: bool) -> void:
		if _open:
			_refresh_hint())
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"dialogue")                 # the text director asks whether a box is up
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
	_panel.theme = Med.theme()
	var sb := Med.panel("leather", 36)
	sb.content_margin_left = 34
	sb.content_margin_right = 36
	sb.content_margin_top = 30
	sb.content_margin_bottom = 26
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_panel.add_child(row)
	# portrait: the speaker's own rig, lit by a candle, in a framed square
	var frame := PanelContainer.new()
	var fsb := Med.slot(Med.GILT_DEEP)
	fsb.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.custom_minimum_size = Vector2(262, 262)
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
	_portrait.self_modulate = Color(1.06, 1.03, 1.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	row.add_child(col)
	_name = Label.new()
	Med.gilt(_name, 28)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	col.add_child(name_row)
	var banner := PanelContainer.new()                  # the speaker's name on a small cloth banner
	banner.add_theme_stylebox_override("panel", Med.banner())
	banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner.add_child(_name)
	name_row.add_child(banner)
	_mood = Label.new()
	_mood.add_theme_font_override("font", UIType.body())
	_mood.add_theme_font_size_override("font_size", 18)
	_mood.add_theme_color_override("font_color", Color(QUIET, 0.85))
	_mood.size_flags_vertical = Control.SIZE_SHRINK_END
	_mood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(_mood)
	col.add_child(Med.rule())
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 96)
	_text.add_theme_font_override("normal_font", UIType.body())
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.add_theme_color_override("default_color", Med.BONE)
	_text.add_theme_constant_override("line_separation", 6)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	col.add_child(_choices)
	_hint = Label.new()
	_hint.add_theme_font_override("font", UIType.body())
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(QUIET, 0.9))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.size_flags_vertical = Control.SIZE_SHRINK_END
	col.add_child(_hint)


func _build_subtitles() -> void:
	_sub = Label.new()
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.offset_left = -480                   # the text director's lower-centre lane (text_director.gd lane_rect)
	_sub.offset_right = 480
	_sub.offset_top = -430
	_sub.offset_bottom = -270
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_font_override("font", UIType.body())   # r30: Cinzel is for names and titles
	_sub.set_meta(&"ts_base", 28)
	_sub.add_theme_font_size_override("font_size", TextDirector.px(28))
	_sub.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_sub.add_theme_constant_override("shadow_offset_x", 2)
	_sub.add_theme_constant_override("shadow_offset_y", 2)
	_sub.add_theme_stylebox_override("normal", TextDirector.backing(28, 12))
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.modulate.a = 0.0
	_root.add_child(_sub)


## A choice row: a keycap with its number on the left, a gilt lozenge when it is the marked one.
class _Choice extends Button:
	var num := 1
	var lit := false
	var mark := ""                          ## "offer" / "turnin": the painted quest mark before the text ("" = a plain choice)

	func _draw() -> void:
		var cy := size.y * 0.5
		var cap := Rect2(16.0, cy - 15.0, 34.0, 30.0)
		var hot := lit or is_hovered()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.1, 0.05, 0.95) if not hot else Color(0.45, 0.28, 0.1, 0.95)
		sb.border_color = Color(0.95, 0.78, 0.4) if hot else Color(0.62, 0.45, 0.2, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		draw_style_box(sb, cap)
		var f := load("res://ui/fonts/Cinzel.ttf") as Font
		var t := str(num)
		var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
		draw_string(f, Vector2(cap.position.x + (cap.size.x - ts.x) * 0.5, cy + ts.y * 0.3), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 19,
			Color(1.0, 0.9, 0.6) if hot else Color(0.8, 0.7, 0.5))
		if mark != "":
			var tex := IconArt.art("mark", "quest_turnin" if mark == "turnin" else "quest_available")
			if tex != null:
				draw_texture_rect(tex, Rect2(62.0, cy - 13.0, 26.0, 26.0), false, Color(1, 1, 1, 1.0 if hot else 0.85))


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


## The portrait the box owns: callers that build their own bust (villagers) hand it over here and it is shown
## in the framed square; hide_portrait() drops it and hides the frame. open() always starts from no bust.
func show_portrait(bust: Node3D) -> void:
	if is_instance_valid(_ext) and _ext != bust:
		_ext.queue_free()
	_ext = bust
	if is_instance_valid(bust) and bust.get_parent() != _vp:
		if bust.get_parent():
			bust.get_parent().remove_child(bust)
		_vp.add_child(bust)
	_portrait.get_parent().visible = true


func hide_portrait() -> void:
	if is_instance_valid(_ext):
		_ext.queue_free()
	_ext = null
	_portrait.get_parent().visible = false


func portrait_visible() -> bool:
	return _portrait.get_parent().visible


func open(speaker: String, portrait_opts: Dictionary = {}) -> void:
	hide_portrait()
	_portrait_rig(portrait_opts)
	_portrait.get_parent().visible = not portrait_opts.is_empty()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_name.text = speaker
	_mood.text = ""
	_panel.visible = true
	if not _open:                               # opened again while up (a new page): the first open owns the pause
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		_paused_it = not get_tree().paused
	_open = true
	add_to_group(&"dialogue_open")              # the Ambience ducks the music and spots while it is up
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	Events.interact_hint.emit("")


func close() -> void:
	if not _open:
		return
	_open = false
	remove_from_group(&"dialogue_open")
	_voice_stop()
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
## `marks` (parallel to `choices`, "" = none) is a choice's painted task mark: "offer" or "turnin" (QuestBook.task_mark).
func line(speaker: String, text: String, choices: Array[String] = [], marks: Array[String] = []) -> void:
	_name.text = speaker
	_text.text = text
	_total = _text.get_total_character_count()
	_voice_stop()
	_cur_voice = _voices.get(speaker, {})
	if _cur_voice.is_empty():
		_cur_voice = Voice.profile("dwarf", hash(speaker))
	_solemn = _is_solemn(text)
	_plan_syllables(_text.get_parsed_text())
	_shown = 0.0
	_text.visible_characters = 0
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_sel = 0
	for i in choices.size():
		var b := _Choice.new()
		b.num = i + 1
		b.text = String(choices[i])
		b.mark = String(marks[i]) if i < marks.size() else ""
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_override("font", UIType.body())
		b.add_theme_font_size_override("font_size", 23)
		b.add_theme_color_override("font_color", Med.BONE_DIM)
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
	var pad := Settings.using_pad
	var leave := "B" if pad else "Esc"
	Foot.style(_hint)
	if typing():
		_hint.text = "[%s]  skip" % k
	elif _buttons.is_empty():
		_hint.text = "[%s]  continue      [%s]  leave" % [k, leave]
	elif pad:
		_hint.text = "[D-pad]  move      [%s]  choose      [%s]  leave" % [k, leave]
	else:
		_hint.text = "[1-%d] or [%s]  choose      [Esc]  leave" % [_buttons.size(), k]


func _mark() -> void:
	for i in _buttons.size():
		var b := _buttons[i] as _Choice
		var task := b.mark != ""
		var lit := i == _sel
		b.lit = lit
		b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.66) if lit else (Color(0.95, 0.82, 0.6) if task else Med.BONE_DIM))
		var sb: StyleBoxTexture
		if lit:
			sb = Med.plaque("hover", 66, 4)
			sb.modulate_color = Color(1.15, 1.08, 1.0)
			sb.content_margin_left = 66 + (30 if task else 0)
		else:
			sb = Med.inset(4)
			sb.modulate_color = Color(1, 1, 1, 0.55)
			sb.content_margin_left = 66 + (30 if task else 0)
		sb.content_margin_right = 16
		for st: String in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.queue_redraw()


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


## Syllables of the line: one per vowel group of each word. Sentences fall in pitch, a question lifts
## its last two syllables, an exclamation is louder and a little higher, a few syllables take stress.
func _plan_syllables(text: String) -> void:
	_syl.clear()
	_syl_i = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	var sentence: Array = []                 # syllable char indices of the sentence being read
	var in_word := false
	var prev_vowel := false
	var groups := 0                          # vowel groups met in this word
	var n := text.length()
	for i in n + 1:
		var c := text[i].to_lower() if i < n else "."
		var letter := (c >= "a" and c <= "z") or c == "'"
		var vowel := c in ["a", "e", "i", "o", "u", "y"]
		if letter:
			if not in_word:
				sentence.append(i)               # the word's first syllable starts with it
				groups = 0
			if vowel and not prev_vowel:
				groups += 1
				# each vowel group after the first is one more syllable, except a final silent e
				var nxt := text[i + 1].to_lower() if i + 1 < n else " "
				var silent_e := c == "e" and not (nxt >= "a" and nxt <= "z")   # "fire", "fire's"
				if groups > 1 and not silent_e and i - int(sentence[-1]) > 1:
					sentence.append(i)
			in_word = true
			prev_vowel = vowel
		else:
			in_word = false
			prev_vowel = false
			if c in [".", "!", "?"] and not sentence.is_empty():
				_sentence(sentence, c, rng)
				sentence = []


func _sentence(idx: Array, end: String, rng: RandomNumberGenerator) -> void:
	var k := idx.size()
	for j in k:
		var f := float(j) / maxf(float(k - 1), 1.0)
		var pitch := 1.04 - 0.08 * f
		var db := VOICE_DB
		if end == "?" and j >= k - 2:
			pitch += 0.09 * float(j - (k - 3))
		elif end == "!":
			pitch += 0.04
			db += 2.0
		if rng.randf() < 0.22:
			pitch += 0.05
			db += 1.5
		_syl.append([int(idx[j]), pitch, db])


## Called as the line types: voice each syllable the text has reached (spaced so a fast line does
## not turn into a buzz; the profile's pace sets the spacing).
func _voice_tick() -> void:
	if _syl_i >= _syl.size():
		return
	var now := Time.get_ticks_msec() * 0.001
	var gap := 0.055 / float(_cur_voice.get("pace", 1.0)) * (1.7 if _solemn else 1.0)
	while _syl_i < _syl.size() and int(_syl[_syl_i][0]) <= int(_shown):
		var s: Array = _syl[_syl_i]
		_syl_i += 1
		if now - _syl_last >= gap:
			_syl_last = now
			Voice.syllable(_voice_p, _cur_voice, float(s[1]) * (0.93 if _solemn else 1.0), float(s[2]) - (2.5 if _solemn else 0.0))


## A line is grave when two of the grave words are in it, or one and it trails off.
func _is_solemn(text: String) -> bool:
	var t := text.to_lower()
	var n := 0
	for w: String in SOLEMN:
		if t.contains(w):
			n += 1
	return n >= 2 or (n >= 1 and (t.ends_with("...") or t.ends_with("\u2026")))


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
	var td := TextDirector.of(self)
	if _open:
		return
	if _sub_t > 0.0:
		_sub_t -= delta
		var n := _sub.text.length()
		_sub.visible_characters = mini(n, int((4.2 + float(n) / CPS * 1.2 - _sub_t) * CPS * 0.8))
		if _sub_t <= 0.6 and _sub.modulate.a > 0.0 and (_sub_tw == null or not _sub_tw.is_running()):
			_sub_tw = create_tween()
			_sub_tw.tween_property(_sub, "modulate:a", 0.0, 0.55)
		if _sub_t <= 0.0 and td and _sub_queue.is_empty():
			td.end(&"narration")                  # kept up between lines: no banner may slip into the gap
		return
	if _sub_queue.is_empty():
		return
	var life := 4.2 + float(_sub_queue[0].length()) / CPS * 1.2
	if td and not td.begin(&"narration", life + 1.0, td.lane_rect(&"sub"), td.is_up(&"narration")):
		return                                 # the lane is not ours yet (a boss's emote): wait
	_sub.text = _sub_queue.pop_front()
	Access.subtitle(_sub)
	if td:
		td.plate_low(_sub, _sub.text, 960.0, -270.0)       # in a fight: the left column, off the foe and the ground round you
	else:
		TextDirector.plate(_sub, _sub.text, 960.0, -270.0)
	_sub.visible_characters = 0
	_sub_t = life
	if _sub_tw:
		_sub_tw.kill()
	_sub_tw = create_tween()
	_sub_tw.tween_property(_sub, "modulate:a", 1.0, 0.4)
