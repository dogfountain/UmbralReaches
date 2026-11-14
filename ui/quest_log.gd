extends CanvasLayer
## The tasks (story; no class_name). Added by the story director (core/story/story.gd).
##   banner   "NEW TASK" / "TASK DONE" with the task's name and who set it, top centre, on
##            Events.quest_changed (a moved-on step only flashes the objective line)
##   progress the count toast under it ("Bone ash: 3/5"), from QuestBook.bump / the runner (r33)
##   ledger   [L] (d-pad left): r33, after an MMO's quest log: the tasks under way down the left,
##            in chapters by where they lead (Hearthward, the Thornwood, ...), finished ones after;
##            the chosen task on the right: who set it and their words, the steps done (struck)
##            and the one now with its count, what it pays and the gear to choose from, how it
##            ended. [T] track / untrack it on the HUD, [X] abandon it (press twice), up/down to
##            move. The world pauses while it is open.
## Data: core/story/quest_chains.gd; state: core/story/quest_book.gd.

const PageGrid := preload("res://ui/page_grid.gd")
const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Offer := preload("res://ui/quest_offer.gd")
const UIType := preload("res://ui/type.gd")
const UiSound := preload("res://ui/ui_sound.gd")   ## quiet menu sounds (F)
const QuestMarks := preload("res://ui/quest_marks.gd")
const TextDirector := preload("res://ui/text_director.gd")
const ACTION := "quest_log"
const Med := preload("res://ui/medieval_style.gd")
const LANTERN := Med.GILT
const QUIET := Med.BONE_DIM
const INK := Med.BONE

var _font: Font
var _banner: VBoxContainer
var _b_top: Label
var _b_name: Label
var _b_sub: Label
var _b_tw: Tween
var _prog: VBoxContainer
var hosted := false                 ## r35: a page of the character screen (it owns keys and pause)
var _panel: PanelContainer
var _list: VBoxContainer
var _body: Control                  ## the list and the chosen task
var _empty: Control                 ## the calm page when nothing has been asked
var _tall := 860.0                  ## the window's height when it has tasks
var _detail: VBoxContainer
var _count: Label
var _hint: Label
var _paused_it := false
var _was_captured := false
var _last_state := {}            ## id -> [step, done] (only real changes raise a banner)
var _rows: Array = []            ## [[quest id, Button], ...] in list order
var sel := ""                    ## the task shown on the right
var _abandon_armed := ""
var _recent := PackedStringArray()   ## the last three count lines posted, newest first
var _bq: Array = []              ## banners waiting for the text director's banner lane


func _ready() -> void:
	layer = 59
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("quest_log")
	_font = load("res://ui/fonts/Cinzel.ttf")
	_build_banner()
	_build_progress()
	_build_ledger()
	for id: String in Chains.ORDER:
		_last_state[id] = [Book.step(id), Book.done(id)]
	Events.quest_changed.connect(_on_changed)


func _lbl(size: int, col: Color, font := true) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font if font else UIType.body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = 120
	_banner.offset_bottom = 260
	_banner.alignment = BoxContainer.ALIGNMENT_BEGIN
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)
	_b_top = _lbl(18, Med.GILT_DEEP)
	_b_name = _lbl(38, Med.BONE)
	_b_sub = _lbl(20, QUIET, false)
	for l: Label in [_b_top, _b_name, _b_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.add_child(l)


func _build_progress() -> void:
	_prog = VBoxContainer.new()
	_prog.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prog.offset_left = -420
	_prog.offset_right = 420
	_prog.offset_top = 270
	_prog.offset_bottom = 380
	_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prog.add_theme_constant_override("separation", 2)
	add_child(_prog)


func _frame(bg: Color, border: Color, top := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.border_width_top = top
	sb.set_corner_radius_all(4)
	return sb


func _build_ledger() -> void:
	_panel = PanelContainer.new()
	PageGrid.place(_panel)                      # the character screen's one grid cell: the ledger fills it
	_panel.theme = Med.theme()
	_panel.add_theme_stylebox_override("panel", Med.panel("leather", 36))
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := _lbl(32, LANTERN)
	Med.gilt(t, 34)
	t.text = "Tasks"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_count = _lbl(17, QUIET, false)
	_count.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_count)
	col.add_child(Med.rule())
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 520)
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	_body = row
	_empty = _build_empty()
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL      # the calm page is centred in the whole cell
	col.add_child(_empty)
	var left_well := PanelContainer.new()
	left_well.add_theme_stylebox_override("panel", Med.inset(10))
	row.add_child(left_well)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(470, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_well.add_child(left)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	left.add_child(_list)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(right)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	right.add_child(_detail)
	col.add_child(Med.rule(Color(Med.BRONZE, 0.6), false))
	_hint = _lbl(14, QUIET)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)


## Nothing asked yet: a faint emblem, a rule and two calm lines, centred, in a window that shrinks to fit.
func _build_empty() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(0, 300)
	box.add_theme_constant_override("separation", 14)
	box.visible = false
	var em := TextureRect.new()
	em.texture = IconArt.art("lore", "ledger")
	em.custom_minimum_size = Vector2(88, 88)
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	em.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	em.modulate = Color(1, 1, 1, 0.35)
	em.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(em)
	var rl := Med.rule()
	rl.custom_minimum_size = Vector2(420, 14)
	rl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rl)
	var a := _lbl(22, Med.BONE, false)
	a.text = "Nobody has asked anything of you yet."
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(a)
	var b := _lbl(18, QUIET, false)
	b.text = "Talk to the people of Hearthward, and the regulars at the Kindled Keg. Look for the gold mark over their heads."
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(560, 0)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(b)
	return box


# --- banner and progress -----------------------------------------------------------------------------

func _on_changed(id: String, s: int, done: bool) -> void:
	var was: Array = _last_state.get(id, [-1, false])
	_last_state[id] = [s, done]
	if not Chains.QUESTS.has(id):
		return
	var qd: Dictionary = Chains.QUESTS[id]
	if (int(was[0]) < 0 or bool(was[1])) and s >= 0 and not done:
		banner("NEW TASK", String(qd.name), String(qd.where))
	elif done and not bool(was[1]):
		banner("TASK DONE", String(qd.name), outcome(id))
	elif not done and Book.ready(id) and int(was[0]) != s:
		progress("%s: return to %s" % [String(qd.name), String(Chains.GIVER_NAMES.get(String(Chains.step(id, s).get("who", "")), "the giver"))], true)
	if is_open():
		_fill()


## The banner never draws over a menu or a conversation (both pause the tree), its own ledger included.
func _process(_d: float) -> void:
	_banner.visible = not get_tree().paused
	_prog.visible = not get_tree().paused
	if not _bq.is_empty() and not get_tree().paused:
		var td := TextDirector.of(self)
		if td == null or td.begin(&"quest", 5.8, Rect2(td.lane_rect(&"banner").position + Vector2(50, 8), Vector2(1000, 150))):
			_show_banner.callv(_bq.pop_front())


## A NEW TASK / TASK DONE banner: queued, and drawn when the text director's banner lane is free.
func banner(top: String, name_text: String, sub: String) -> void:
	if _bq.size() < 4:
		_bq.append([top, name_text, sub])


func _show_banner(top: String, name_text: String, sub: String) -> void:
	_b_top.text = TextDirector.sentence(top)           # the same case rule as every other line; the name stays as the lore spells it
	_b_name.text = name_text
	_b_sub.text = TextDirector.sentence(sub)
	if _b_tw:
		_b_tw.kill()
	_b_tw = create_tween()
	_b_tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)     # a task begun in a conversation waits for it to close
	_b_tw.tween_property(_banner, "modulate:a", 1.0, 0.5)
	_b_tw.tween_interval(3.6)
	_b_tw.tween_property(_banner, "modulate:a", 0.0, 1.2)


## A count toast ("Bone ash: 3/5"), gold when the count is full; three at most, newest at the top.
func progress(text: String, full := false) -> void:
	_recent.insert(0, text)                     # newest first, three kept (progress_lines)
	if _recent.size() > 3:
		_recent.resize(3)
	var td := TextDirector.of(self)
	if td:
		td.post_toast(text)                     # the corner toast lane; two at most, queued behind higher text
		return
	var l := _lbl(24, LANTERN if full else Color(0.96, 0.9, 0.74), false)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prog.add_child(l)
	_prog.move_child(l, 0)
	while _prog.get_child_count() > 3:
		var c := _prog.get_child(_prog.get_child_count() - 1)
		_prog.remove_child(c)
		c.queue_free()
	var tw := l.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


## The progress lines showing now (tests).
## The count lines posted most recently, newest first (whether drawn here or by the text director).
func progress_lines() -> PackedStringArray:
	return _recent


static func outcome(id: String) -> String:
	var o: Dictionary = (Chains.QUESTS.get(id, {}) as Dictionary).get("outcome", {})
	return String(o.get(Book.pick(id), o.get("", "")))


# --- ledger -------------------------------------------------------------------------------------------

func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if not hosted and _cs() != null:
		_cs().call("open_at", "journal", "tasks")
		return
	_abandon_armed = ""
	_fill()
	UiSound.play(self, "tab")
	_panel.visible = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_paused_it = not get_tree().paused
	get_tree().paused = true


func close() -> void:
	if not _panel.visible:
		return
	UiSound.play(self, "back")
	_panel.visible = false
	if _paused_it:
		get_tree().paused = false
	_paused_it = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The list's order: under way by chapter, then finished (a daily done today shows as resting).
func entries() -> Array:
	var out: Array = []
	for z: Array in Chains.ZONES:
		for id: String in Chains.ORDER:
			if Book.active(id) and String(Chains.QUESTS[id].get("zone", "")) == String(z[0]):
				out.append(id)
	for id2: String in Chains.ORDER:
		if Book.done(id2):
			out.append(id2)
	return out


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	var ids := entries()
	var under := 0
	for id: String in ids:
		if Book.active(id):
			under += 1
	_count.text = "%d under way" % under
	if not sel in ids:
		sel = String(ids[0]) if not ids.is_empty() else ""
	var zone := "#"
	for id: String in ids:
		var done := Book.done(id)
		var z := "#done" if done else String(Chains.QUESTS[id].get("zone", ""))
		if z != zone:
			zone = z
			var h := _lbl(18, Med.GILT_DEEP)
			h.text = "FINISHED" if done else Chains.zone_name(z).to_upper()
			if _list.get_child_count() > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 8)
				_list.add_child(gap)
			_list.add_child(h)
		var b := _entry(id, done)
		b.pressed.connect(func() -> void: select(id))
		_list.add_child(b)
		_rows.append([id, b])
	_mark_rows()
	_fill_detail()
	_body.visible = not ids.is_empty()
	_empty.visible = ids.is_empty()
	if not hosted:
		_panel.offset_bottom = _panel.offset_top + (_tall if not ids.is_empty() else 0.0)    # shrinks to its content
	_hint.text = "[↑↓] choose      [T] track      [X] abandon      [L] close" if Book.active(sel) else ("[↑↓] choose      [L] close" if not ids.is_empty() else "[L] close")


## One task in the list: its painted mark, the name, and who set it and where, in a button that takes a gilt frame
## when chosen.
func _entry(id: String, done: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 66)
	var tag := ""
	if Book.ready(id):
		tag = "   ready"
	elif String(Chains.QUESTS[id].get("repeat", "")) == "daily":
		tag = "   (daily)"
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var pin := QuestMarks.lore_art("done" if done else ("ready" if Book.ready(id) else ("tracked" if Book.tracked(id) else "")))
	var ic := TextureRect.new()
	ic.texture = pin
	ic.custom_minimum_size = Vector2(30, 30)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := _lbl(21, INK, false)
	nm.text = String(Chains.QUESTS[id].name) + tag
	v.add_child(nm)
	var wh := _lbl(15, QUIET, false)
	wh.text = String(Chains.QUESTS[id].where)
	wh.clip_text = true
	v.add_child(wh)
	b.set_meta("name_label", nm)
	return b


func _mark_rows() -> void:
	for r: Array in _rows:
		var b: Button = r[1]
		var on := String(r[0]) == sel
		var done := Book.done(String(r[0]))
		var empty := StyleBoxEmpty.new()
		var frame := Med.slot(Color(1.1, 0.92, 0.6))
		b.add_theme_stylebox_override("normal", frame if on else empty)
		b.add_theme_stylebox_override("pressed", frame)
		b.add_theme_stylebox_override("hover", frame if on else Med.slot(Color(0.8, 0.74, 0.62)))
		b.add_theme_stylebox_override("focus", empty)
		(b.get_meta("name_label") as Label).add_theme_color_override("font_color", LANTERN if on else (Color(0.7, 0.66, 0.6) if done else INK))


func select(id: String) -> void:
	if sel != id:
		_abandon_armed = ""
	sel = id
	UiSound.play(self, "move")
	_fill()


func _fill_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if sel == "" or not Chains.QUESTS.has(sel):
		return
	var qd: Dictionary = Chains.QUESTS[sel]
	var n := _lbl(30, Med.BONE)
	Med.gilt(n, 30)
	n.text = String(qd.name)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(n)
	var w := _lbl(17, QUIET, false)
	w.text = "%s   ·   %s" % [String(qd.where), Chains.zone_name(String(qd.get("zone", "")))]
	_detail.add_child(w)
	var tx := _lbl(20, Med.BONE, false)
	tx.text = String(qd.get("text", ""))
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(tx)
	var done := Book.done(sel)
	var h := _lbl(18, Med.GILT_DEEP)
	h.text = "HOW IT ENDED" if done else "WHAT IS WANTED"
	_detail.add_child(h)
	if done:
		var o := _lbl(20, INK, false)
		o.text = outcome(sel)
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(o)
		if Book.resting(sel):
			var rs := _lbl(17, Color(QUIET, 0.7), false)
			rs.text = "Done for today. Ask again tomorrow."
			_detail.add_child(rs)
	else:
		var cur := Book.step(sel)
		for si in cur + 1:
			var stp := Chains.step(sel, si)
			var st := _lbl(19, INK if si == cur else Color(0.62, 0.6, 0.56), false)
			var ico := QuestMarks.lore_art("done") if si < cur else QuestMarks.task_art(String(stp.kind))
			var lead := "" if ico != null else ("  ›  " if si == cur else "  ✓  ")
			st.text = lead + Chains.step_text(sel, si, Book.q(sel) if si == cur else {})
			if si < cur and String(stp.kind) in Chains.COUNTED:
				st.text = lead + String(stp.text).replace(" ({n}/{of})", "")
			st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			QuestMarks.row(_detail, st, ico, 24.0, si < cur)
		var ph := _lbl(18, Med.GILT_DEEP)
		ph.text = "WHAT IT PAYS"
		_detail.add_child(ph)
		var pay := _lbl(19, INK, false)
		pay.text = Offer.pay_line(qd.get("reward", {}))
		pay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var pieces := Book.offered_gear(sel)
		QuestMarks.row(_detail, pay, QuestMarks.reward_art(qd.get("reward", {}), not pieces.is_empty() and qd.get("reward", {}).is_empty()), 24.0)
		if not pieces.is_empty():
			var names: PackedStringArray = []
			for p: Dictionary in pieces:
				names.append(String(p.get("name", "gear")))
			var ch := _lbl(18, Color(QUIET, 0.85), false)
			ch.text = "Choose one at the end: " + ",  ".join(names)
			ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail.add_child(ch)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_detail.add_child(row)
		var trk := _button("Untrack" if Book.tracked(sel) else "Track")
		trk.pressed.connect(toggle_track)
		row.add_child(trk)
		var ab := _button("Abandon?  (again)" if _abandon_armed == sel else "Abandon")
		ab.pressed.connect(abandon)
		row.add_child(ab)


func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 42)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", LANTERN)
	Med.style_button(b, 19, 14, 6)
	return b


func toggle_track() -> void:
	if not Book.active(sel):
		return
	Book.set_tracked(sel, not Book.tracked(sel))
	UiSound.play(self, "confirm")
	_fill()


## Abandon the chosen task: the first press arms it, the second sets it aside (the giver can offer
## it again; a finished task is never dropped).
func abandon() -> void:
	if not Book.active(sel):
		return
	if _abandon_armed != sel:
		_abandon_armed = sel
		UiSound.play(self, "move")
		_fill()
		return
	_abandon_armed = ""
	Book.drop(sel)
	UiSound.play(self, "back")
	_fill()


func _step_sel(d: int) -> void:
	if _rows.is_empty():
		return
	var i := 0
	for j in _rows.size():
		if String(_rows[j][0]) == sel:
			i = j
	select(String(_rows[clampi(i + d, 0, _rows.size() - 1)][0]))


func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if hosted and (event.is_action_pressed(ACTION) or event.is_action_pressed("toggle_settings") or event.is_action_pressed("inventory") \
			or event.is_action_pressed("release_mouse") or event is InputEventJoypadMotion \
			or (event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_Q, KEY_E, KEY_1, KEY_2, KEY_3, KEY_4, KEY_J, KEY_K, KEY_O]) \
			or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER])):
		return                                   # the character screen's keys (it is a page of it)
	if event.is_action_pressed(ACTION) or event.is_action_pressed("toggle_settings") or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back") or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_DPAD_DOWN):
				_step_sel(1)
			elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward") or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_DPAD_UP):
				_step_sel(-1)
			elif event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_T or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
				toggle_track()
			elif event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_X or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X):
				abandon()
		get_viewport().set_input_as_handled()      # nothing reaches the world while the ledger is open


func _unhandled_input(event: InputEvent) -> void:
	if _cs() != null:
		return                                   # the character screen opens it (Journal, Tasks)
	if event.is_action_pressed(ACTION) and not _panel.visible and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


## r35: the one character screen (ui/character_screen.gd), when the night has one.
func _cs() -> Node:
	return get_tree().get_first_node_in_group(&"character_screen") if is_inside_tree() else null


## r35: hosted on the character screen, the ledger sits below its tab band (it was centred 860 tall,
## its top under the band).
func set_hosted(on: bool) -> void:
	if _panel == null:
		return
	if on:
		PageGrid.place(_panel)                  # the screen's one grid cell: the ledger fills it
		return
	_tall = 860.0
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -720.0
	_panel.offset_right = 720.0
	_panel.offset_top = -430.0
	_panel.offset_bottom = _panel.offset_top + (_tall if _body == null or _body.visible else 0.0)
