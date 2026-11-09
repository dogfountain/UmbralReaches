extends CanvasLayer
## The accept and turn-in screens for offered tasks (story, r33; no class_name). Added by the story
## director (core/story/story.gd) as "QuestOffer", group "quest_offer". Adapts an MMO's quest
## window to the valley's own panels (the dialogue box's soot-and-lantern frame):
##   offer     the task's name and giver, the giver's words, what is wanted, what it pays, and the
##             gear to choose from at the end; [Accept] / [Decline]
##   turn-in   how it ended, what it pays; pick one piece (click, 1-4, or left/right) and [Hand in]
## The world pauses while it is open; the mouse is freed. E / Enter = the main button, Esc = back.
## Data: core/story/quest_chains.gd; state and grants: core/story/quest_book.gd.

signal accepted(id: String)
signal turned_in(id: String, choice: int)
signal dismissed

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const UIType := preload("res://ui/type.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const QuestMarks := preload("res://ui/quest_marks.gd")
const Med := preload("res://ui/medieval_style.gd")
## The offer is a sheet of vellum: ink-brown type, oxblood heads, the pay and the gear on leather.
const LANTERN := Med.INK_RED
const QUIET := Med.INK_DIM
const INK := Med.INK
const BONE := Med.BONE

var mode := ""                     ## "offer" / "turnin" / "" (closed)
var quest := ""
var choice := -1
var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _title: Label
var _giver: Label
var _text: RichTextLabel
var _obj: VBoxContainer
var _pay: Label
var _pay_icon: TextureRect
var _choose_head: Label
var _cards: HBoxContainer
var _ok: Button
var _no: Button
var _cardbtns: Array[Button] = []
var _pieces: Array = []
var _paused_it := false
var _was_captured := false


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("quest_offer")
	_build()


func _lbl(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if col.get_luminance() > 0.45:                 # light type on leather keeps its shadow; ink on vellum has none
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _frame(bg: Color, border: Color, top := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.border_width_top = top
	sb.set_corner_radius_all(4)
	return sb


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -500
	_panel.offset_right = 500
	_panel.offset_top = 0.0                    # the sheet is as tall as its words (see _fit): no page of empty vellum
	_panel.offset_bottom = 0.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.theme = Med.theme()
	var sb := Med.panel("parchment", 44)
	sb.content_margin_top = 32
	sb.content_margin_bottom = 30
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_title = _lbl(UIType.title(), 34, LANTERN)
	col.add_child(_title)
	_giver = _lbl(UIType.body(), 18, QUIET)
	col.add_child(_giver)
	col.add_child(_rule())
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	_body = body
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	_text = RichTextLabel.new()
	_text.fit_content = true
	_text.bbcode_enabled = false
	_text.scroll_active = false
	_text.add_theme_font_override("normal_font", UIType.body())
	_text.add_theme_font_size_override("normal_font_size", 23)
	_text.add_theme_color_override("default_color", INK)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_text)
	var oh := _lbl(UIType.title(), 19, Med.INK_RED)
	oh.text = "WHAT IS WANTED"
	oh.name = "ObjHead"
	body.add_child(_gap(6))
	body.add_child(oh)
	_obj = VBoxContainer.new()
	_obj.add_theme_constant_override("separation", 4)
	body.add_child(_obj)
	var rh := _lbl(UIType.title(), 19, Med.INK_RED)
	rh.text = "WHAT IT PAYS"
	body.add_child(_gap(6))
	body.add_child(rh)
	_pay = _lbl(UIType.body(), 21, INK)
	_pay_icon = QuestMarks.row(body, _pay, null, 32.0)
	_choose_head = _lbl(UIType.body(), 19, QUIET)
	body.add_child(_choose_head)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 12)
	body.add_child(_cards)
	col.add_child(_rule())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	_no = _button("Decline", false)
	_no.pressed.connect(_back)
	row.add_child(_no)
	_ok = _button("Accept", true)
	_ok.pressed.connect(_confirm)
	row.add_child(_ok)


func _rule() -> Control:
	return Med.rule(Color(Med.INK_RED, 0.7))


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The main button is the lit one (larger, gilt type); the other is a smaller, quieter plate beside it.
func _button(t: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(230, 54) if primary else Vector2(150, 46)
	b.add_theme_font_override("font", UIType.title())
	Med.style_button(b, 26 if primary else 19, 20, 8)
	if primary:
		b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	else:
		b.add_theme_color_override("font_color", Med.BONE_DIM)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


# --- opening ----------------------------------------------------------------------------------------

func is_open() -> bool:
	return _panel.visible


## The accept screen for `id` (false when it cannot be offered now).
func open_offer(id: String, giver_name := "") -> bool:
	if not Chains.QUESTS.has(id) or Book.active(id):
		return false
	mode = "offer"
	quest = id
	_fill(giver_name)
	_show()
	return true


## The turn-in screen for a ready `id`.
func open_turnin(id: String, giver_name := "") -> bool:
	if not Book.ready(id):
		return false
	mode = "turnin"
	quest = id
	_fill(giver_name)
	_show()
	return true


const RAID_NAMES := {"thornwarden": "the Thornwarden", "bone_abbot": "the Bone Abbot", "ascended_warden": "the Ascended Warden",
	# --- the east marches ---
	"r37_anchoress": "the Anchoress"}


func _fill(giver_name: String) -> void:
	var qd: Dictionary = Chains.QUESTS[quest]
	var daily := String(qd.get("repeat", "")) == "daily"
	_title.text = String(qd.name) + ("   (daily)" if daily else "")
	var who := giver_name if giver_name != "" else String(Chains.GIVER_NAMES.get(Chains.giver(quest), ""))
	_giver.text = (("Asked by " if mode == "offer" else "Handed in to ") + who + "   ·   " + Chains.zone_name(String(qd.get("zone", "")))) if who != "" else Chains.zone_name(String(qd.get("zone", "")))
	# r34: a raid's attunement chain says so (WoW's attunement quests: the raid it prepares)
	if qd.has("raid"):
		_giver.text += "   ·   Attunement: %s" % String(RAID_NAMES.get(String(qd.raid), String(qd.raid)))
	if mode == "offer":
		_text.text = String(qd.get("text", ""))
	else:
		var o: Dictionary = qd.get("outcome", {})
		_text.text = String(o.get(Book.pick(quest), o.get("", "It is done.")))
	for c in _obj.get_children():
		c.queue_free()
	(_obj.get_parent().get_node("ObjHead") as Label).visible = mode == "offer"
	_obj.visible = mode == "offer"
	if mode == "offer":
		for si in (qd.steps as Array).size():
			var stp: Dictionary = qd.steps[si]
			if String(stp.kind) == "turnin":
				continue
			var l := _lbl(UIType.body(), 21, QUIET)
			var preview := {"left": float(stp.get("time", 0.0))}
			if String(stp.kind) == "seal":
				preview["of"] = EnemySpawner.seal_total(String(stp.get("seal", "")))
			var ico := QuestMarks.task_art(String(stp.kind))
			l.text = ("" if ico != null else "  ›  ") + Chains.step_text(quest, si, preview)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			QuestMarks.row(_obj, l, ico, 32.0)
	_pay.text = pay_line(qd.get("reward", {}))
	_pieces = Book.offered_gear(quest)
	_pay_icon.texture = QuestMarks.reward_art(qd.get("reward", {}), qd.get("reward", {}).is_empty() and not _pieces.is_empty())
	_pay_icon.visible = _pay_icon.texture != null
	choice = -1
	for b in _cardbtns:
		b.queue_free()
	_cardbtns.clear()
	_choose_head.visible = not _pieces.is_empty()
	_choose_head.text = "Choose one at the end:" if mode == "offer" else "Choose one:"
	for i in _pieces.size():
		var b := _card(_pieces[i] as Dictionary, i)
		_cards.add_child(b)
		_cardbtns.append(b)
	_ok.text = "Accept" if mode == "offer" else "Hand in"
	_no.text = "Decline" if mode == "offer" else "Not yet"
	_mark()


## The fixed part of a reward as one line: "+12 grave ash · Ember Shard ×2".
static func pay_line(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(r.get("ash", 0)) > 0:
		parts.append("+%d grave ash" % int(r.ash))
	for k: String in r.get("items", {}):
		var n := int(r.items[k])
		var nm := String(ItemDB.def(k).get("name", k))
		parts.append(nm if n == 1 else "%s ×%d" % [nm, n])
	var ch := String(r.get("charm", ""))
	if ch != "":
		parts.append(String(ItemDB.def(ch).get("name", "a charm")) if ItemDB.DEFS.has(ch) else "a keepsake")
	return "   ·   ".join(parts) if not parts.is_empty() else "Nothing but thanks."


func _card(p: Dictionary, i: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(290, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = false
	var rc := GearDB.rarity_color(int(p.get("rarity", 0)))
	for st: String in ["normal", "hover", "pressed", "focus"]:
		var sb := Med.slot(rc)
		sb.set_content_margin_all(12)
		b.add_theme_stylebox_override(st, sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 10
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var nm := _lbl(UIType.title(), 18, rc)
	nm.text = "%d.  %s" % [i + 1, String(p.get("name", "Gear"))]
	v.add_child(nm)
	var sl := _lbl(UIType.body(), 15, Med.BONE_DIM)
	sl.text = "%s %s" % [GearDB.rarity_name(int(p.get("rarity", 0))), String(GearDB.SLOT_NAMES.get(String(p.get("slot", "")), ""))]
	v.add_child(sl)
	var lines: PackedStringArray = [GearDB.base_line(p)]
	for a: Array in p.get("aff", []):
		lines.append(GearDB.affix_line(p, a))
	var sid := String(p.get("set", ""))
	if sid != "" and GearDB.SETS.has(sid):
		lines.append(String(GearDB.SETS[sid].name))
	var lg := String(p.get("legend", ""))
	if lg != "" and GearDB.LEGENDS.has(lg):
		lines.append(String(GearDB.LEGENDS[lg].text))
	var ln := _lbl(UIType.body(), 15, BONE)
	ln.text = "\n".join(lines)
	v.add_child(ln)
	b.custom_minimum_size.y = maxf(150.0, 70.0 + 22.0 * float(lines.size()) + (40.0 if lg != "" else 0.0))
	b.pressed.connect(func() -> void: pick(i))
	return b


func _mark() -> void:
	for i in _cardbtns.size():
		_cardbtns[i].modulate = Color(1.25, 1.12, 0.95) if i == choice else (Color(0.8, 0.8, 0.82) if choice >= 0 else Color.WHITE)
	_ok.disabled = mode == "turnin" and not _pieces.is_empty() and choice < 0


## Pick reward `i` (the turn-in; on the accept screen it only shows what you could have).
func pick(i: int) -> void:
	if i < 0 or i >= _pieces.size():
		return
	choice = i
	UiSound.play(self, "move")
	_mark()


func _show() -> void:
	UiSound.play(self, "tab")
	var reopen := _panel.visible                # shown again while already up: the first open owns the pause
	_panel.visible = true
	_fit.call_deferred()
	if not reopen:
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		_paused_it = not get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	Events.interact_hint.emit("")


## The scroll takes the height its words need (at least a short sheet, at most what leaves the skill bar clear).
func _fit() -> void:
	_scroll.custom_minimum_size.y = 0.0
	await get_tree().process_frame               # the words wrap at the sheet's width once it is laid out
	await get_tree().process_frame
	if not _panel.visible:
		return
	var room := maxf(220.0, get_viewport().get_visible_rect().size.y - 330.0)
	_scroll.custom_minimum_size.y = clampf(_body.get_combined_minimum_size().y + 6.0, 200.0, room)
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0


func close() -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	mode = ""
	if _paused_it:
		get_tree().paused = false
	_paused_it = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The main button: accept the task, or hand it in for the chosen piece.
func _confirm() -> void:
	if not is_open():
		return
	var id := quest
	if mode == "offer":
		if Book.accept(id):
			UiSound.play(self, "confirm")
			close()
			accepted.emit(id)
		return
	if not _pieces.is_empty() and choice < 0:
		UiSound.play(self, "back")
		return
	if Book.turn_in(id, choice):
		UiSound.play(self, "confirm")
		var c := choice
		close()
		turned_in.emit(id, c)


func _back() -> void:
	UiSound.play(self, "back")
	close()
	dismissed.emit()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var handled := true
	if event.is_action_pressed("toggle_settings"):
		_back()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_confirm()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc >= KEY_1 and kc <= KEY_4:
			pick(kc - KEY_1)
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
			pick(mini(choice + 1, _pieces.size() - 1) if choice >= 0 else 0)
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
			pick(maxi(choice - 1, 0))
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var jb := (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_B:
			_back()
		elif jb == JOY_BUTTON_DPAD_RIGHT:
			pick(mini(choice + 1, _pieces.size() - 1) if choice >= 0 else 0)
		elif jb == JOY_BUTTON_DPAD_LEFT:
			pick(maxi(choice - 1, 0))
		else:
			handled = false
	else:
		handled = false                       # the mouse reaches the buttons and cards
	if handled:
		get_viewport().set_input_as_handled()
