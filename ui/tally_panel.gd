extends CanvasLayer
## The Count (P): what the night has cost, on one leather page. Left: the foes put down by kind, the great ones, the
## wanderer's falls, fires kindled, lamps lit, places found, bells answered, camps made and the night it is. Right: the names
## the fire remembers (core/story/tally.gd gives every hollowed thing put down a pilgrim's name; the latest fourteen are
## listed). Pauses the night while it is read, like the map. After a camp the interact key opens it for six seconds
## (arm()), which is how a pad reads it. Added by the story director. Load by path (no class_name).

const Tally := preload("res://core/story/tally.gd")
const Days := preload("res://core/story/days.gd")
const PAGES := 4
const Foot := preload("res://ui/foot_hint.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const Med := preload("res://ui/medieval_style.gd")
const UIType := preload("res://ui/type.gd")
const ReachState := preload("res://core/world/night/reach_state.gd")
const HorseBond := preload("res://core/world/mount/horse_bond.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const MenuGate := preload("res://ui/menu_gate.gd")
const UiSound := preload("res://ui/ui_sound.gd")

const INK := Color(0.93, 0.87, 0.74)
const DIM := Color(0.74, 0.66, 0.52)
const GILT := Color(1.0, 0.78, 0.4)

var _open := false
var _was_captured := false
var _armed_until := 0
var _root: Control
var _left: VBoxContainer
var _right: VBoxContainer
var _opened_ms := 0
var _led_sel := 0                    ## the posting under the cursor on the Long Night page
var _page := 0                        ## 0 the Count, 1 the Chronicle
var _title_l: Label
var _foot_l: Label


static func arm_after_camp(tree: SceneTree) -> void:
	var p := tree.get_first_node_in_group(&"tally_panel") as CanvasLayer
	if p != null:
		p.set("_armed_until", Time.get_ticks_msec() + 6000)


func _ready() -> void:
	name = "TallyPanel"
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"tally_panel")
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.012, 0.01, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Med.panel("leather", 40))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(920, 700)
	panel.offset_left = -460.0
	panel.offset_right = 460.0
	panel.offset_top = -350.0
	panel.offset_bottom = 350.0
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var title := Label.new()
	title.text = "THE COUNT"
	_title_l = title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Med.gilt(title, 34)
	col.add_child(title)
	var sub := _label("What the night has cost, and who the fire remembers", 17, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(Med.rule())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cols)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 3)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_left)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 3)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_right)
	col.add_child(Med.rule())
	var foot := _label("", 15, DIM)
	_foot_l = foot
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://ui/fonts/body_serif.ttf") as Font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _head(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	Med.gilt(l, 20, GILT)
	box.add_child(l)


func _row(box: VBoxContainer, what: String, n: String) -> void:
	var h := HBoxContainer.new()
	var a := _label(what, 18, INK)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(_label(n, 18, GILT))
	box.add_child(h)


func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _fill() -> void:
	_clear(_left)
	_clear(_right)
	_title_l.text = ["THE COUNT", "THE CHRONICLE", "THE BELLS", "THE LONG NIGHT"][_page]
	_foot_l.text = "%s (%d of %d)     %s" % [Foot.page(), _page + 1, PAGES, Foot.leave("tally", "B")]
	if _page == 1:
		_fill_chronicle()
		return
	if _page == 2:
		_fill_bells()
		return
	if _page == 3:
		_fill_ledger()
		return
	var d := Tally.data()
	_head(_left, "PUT DOWN  %d" % Tally.total())
	var rows := Tally.by_kind()
	for i in mini(rows.size(), 7):
		_row(_left, Tally.kind_name(String(rows[i][0])), str(int(rows[i][1])))
	if rows.is_empty():
		_row(_left, "Nothing yet", "")
	elif rows.size() > 7:
		var rest := 0
		for i in range(7, rows.size()):
			rest += int(rows[i][1])
		_row(_left, "Others", str(rest))
	_left.add_child(Control.new())
	_head(_left, "THE GREAT ONES")
	var great: Array = Travel.bosses_slain.keys()
	if great.is_empty():
		_row(_left, "None has fallen", "")
	for g in great:
		_row(_left, Tally.kind_name(String(g)), "fallen")
	_left.add_child(Control.new())
	_head(_right, "THE NIGHT")
	_row(_right, "Night", str(Days.current() + 1))
	_row(_right, "Camps made", str(int(d.get("camps", 0))))
	_row(_right, "Times hollowed", str(int(d.get("falls", 0))))
	_row(_right, "Places found", str(int(d.get("places", 0))))
	_row(_right, "Bells answered", "%d of %d" % [QuestBook.bells(), Chains.BELLS.size()])
	_row(_right, "Fires burning", str(_lit(Groups.BRAZIER)))
	_row(_right, "Lamps you lit", str(_lit(&"lamp")))
	var ride: String = String(Travel.system_state("stable").get("ride", ""))
	if ride != "":
		_row(_right, "%s, your horse" % HorseBond.name_of(ride), "%s, %d km" % [HorseBond.title(ride), roundi(HorseBond.metres(ride) / 1000.0)])
	if int(d.get("races", 0)) > 0:
		_row(_right, "Races run, won", "%d, %d" % [int(d.get("races", 0)), int(d.get("race_wins", 0))])
	_right.add_child(Control.new())
	_head(_right, "YOUR VOWS")
	var sworn := Vows.chosen()
	for v in sworn:
		_row(_right, String((Vows.DEFS[v] as Array)[2]), String((Vows.DEFS[v] as Array)[1]))
	if Vows.pending() >= 0:
		_row(_right, "A vow waits (Remembrance %d)" % int(Vows.TIERS[Vows.pending()]), "")
	elif sworn.is_empty():
		_row(_right, "None sworn. The first is at Remembrance 5.", "")
	_right.add_child(Control.new())
	_head(_right, "WHO KNOWS YOU")
	for f: String in ReachState.FACTIONS:
		var t := ReachState.tier(f)
		_row(_right, String(ReachState.FACTIONS[f].name).capitalize(), ["known", "friend", "kin"][t] if Slice.full() else "")
	_right.add_child(Control.new())
	_head(_right, "THE FIRE REMEMBERS")
	var names := Tally.latest(4)
	for n in names:
		_row(_right, String(n), "")
	if names.is_empty():
		_row(_right, "No one yet. The Bearers wait.", "")
	elif Tally.total() > names.size():
		_row(_right, "and %d more" % (Tally.total() - names.size()), "")


## The run as it was written (core/story/chronicle.gd), newest first, in two columns.
## The eight bells of the Founder: where each hangs, and what has been done (rung where it hangs, carried home, or not yet).
func _fill_bells() -> void:
	var got := QuestBook.bells()
	_head(_left, "THE PEAL")
	_row(_left, "Bells answered", "%d of %d" % [got, Chains.BELLS.size()])
	_row(_left, "The door needs", "one")
	_left.add_child(_label("Every bell after the first takes a hand off the Warden: three in a hundred if rung where it hangs, five if its tongue is carried to the Keg.", 16, DIM))
	_head(_right, "THE EIGHT")
	for i in Chains.BELLS.size():
		var id: String = Chains.BELLS[i]
		var pick := QuestBook.pick(id)
		var state := "rung where it hangs" if pick == "rung" else ("carried home" if pick == "carried" else ("taken up" if QuestBook.started(id) else "not yet"))
		var nm := String((Chains.QUESTS.get(id, {}) as Dictionary).get("name", id))
		_row(_right, nm, state)


## The endgame's page (core/story/long_ledger.gd): rank and marks on the left, tonight's bounties and how far each has come on the right.
func _fill_ledger() -> void:
	_head(_left, "THE LONG LEDGER")
	if not LongLedger.unlocked():
		_left.add_child(_label("The ledger is kept at the Keg and opens when the door is shut: when the Ascended Warden has fallen. After that the night does not end. It asks more, and pays.", 17, DIM))
		_head(_right, "TONIGHT'S POSTING")
		_right.add_child(_label("Nothing is posted. The door is still open.", 17, DIM))
		return
	var r := LongLedger.rank()
	var marks := LongLedger.marks()
	_row(_left, "Rank", LongLedger.rank_name())
	_row(_left, "Marks", str(marks))
	if r < LongLedger.Data.RANKS.size() - 1:
		_row(_left, "Next: %s" % String((LongLedger.Data.RANKS[r + 1] as Array)[1]), "%d marks" % int((LongLedger.Data.RANKS[r + 1] as Array)[0]))
	else:
		_row(_left, "No rank is left above you", "")
	_row(_left, "Bounties done", str(int(LongLedger.st().get("done", 0))))
	_row(_left, "Deeper Nights rung", str(LongLedger.ng()))
	_left.add_child(_label("Each Deeper Night makes the ledger ask a third more and pay a third more. Each rank pays in ember shards and adds a twentieth to every purse. A camp at a lit fire renews the posting.", 16, DIM))
	_head(_right, "TONIGHT'S POSTING")
	var list: Array = LongLedger.st().list
	if list.is_empty():
		_right.add_child(_label("Nothing is posted yet. It is written within a breath or two.", 17, DIM))
	_led_sel = clampi(_led_sel, 0, maxi(list.size() - 1, 0))
	for i in list.size():
		var b: Dictionary = list[i]
		var state := "done" if int(b.s) == 1 else ("struck" if int(b.s) == 2 else "%d of %d" % [mini(LongLedger.progress(b), int(b.n)), int(b.n)])
		_row(_right, ("> " if i == _led_sel else "   ") + ("Hard" if bool(b.hard) else "Plain") + " posting %d" % (i + 1), state)
	if not list.is_empty():                              # the detail of the one under the cursor (up and down, or the d-pad)
		var b: Dictionary = list[_led_sel]
		var rw := LongLedger.reward(b)
		_right.add_child(Control.new())
		_head(_right, "THE POSTING")
		_right.add_child(_label(LongLedger.text_of(b), 18, INK))
		var need := int(b.n)
		var got := mini(LongLedger.progress(b), need)
		_right.add_child(_label("[%s%s]  %d of %d" % ["#".repeat(roundi(10.0 * float(got) / float(maxi(need, 1)))), "-".repeat(10 - roundi(10.0 * float(got) / float(maxi(need, 1)))), got, need], 17, DIM))
		var st := "Done and paid." if int(b.s) == 1 else ("Struck from the ledger: you fell. Tomorrow's posting is fresh." if int(b.s) == 2 else "Pays %d grave ash and %d ember shards, %d mark%s." % [rw.x, rw.y, 2 if bool(b.hard) else 1, "s" if bool(b.hard) else ""])
		_right.add_child(_label(st + ("  Cleaned only if you do not fall." if String(LongLedger.Data.POOL[String(b.t)][0]) == "clean" and int(b.s) == 0 else ""), 16, DIM))
		_right.add_child(_label("[Up] [Down] or d-pad: choose a posting", 15, DIM))


func _fill_chronicle() -> void:
	_head(_left, "NIGHT %d" % (Days.current() + 1))
	if bool((Travel.story.get("flags", {}) as Dictionary).get("ending_card", false)):
		var cr := Button.new()
		cr.text = "Read the credits"
		Med.style_button(cr, 17, 12, 5)
		cr.pressed.connect(func() -> void:
			close()
			NightPanel.panel(get_tree()).show_credits.call_deferred())
		_left.add_child(cr)
	var list := Chronicle.entries()
	if list.is_empty():
		_row(_left, "Nothing is written yet.", "")
		return
	_head(_right, "WHAT THE FIRE KEPT")
	var shown := 0
	for i in range(list.size() - 1, -1, -1):
		if shown >= 16:
			break
		var e: Dictionary = list[i]
		var box := _left if shown < 8 else _right
		var l := _label("Night %d.  %s" % [int(e.get("n", 1)), String(e.get("t", ""))], 17, INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400.0
		box.add_child(l)
		shown += 1
	if list.size() > shown:
		_row(_right, "and %d earlier lines" % (list.size() - shown), "")


func _lit(group: StringName) -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group(group):
		if b is Brazier and (b as Brazier).lit:
			n += 1
		elif b is Lamp and (b as Lamp).lit:
			n += 1
	return n


func can_open() -> bool:
	var zone := get_tree().current_scene
	if zone == null or not zone.has_meta("realm_done") or get_tree().paused or MenuGate.blocked(self):
		return false
	return zone.get_node_or_null("LoadingScreen") == null and get_tree().get_first_node_in_group(Groups.PLAYER) != null


func open() -> void:
	if _open or not can_open():
		return
	_open = true
	_opened_ms = Time.get_ticks_msec()
	_page = 0
	_armed_until = 0
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_fill()
	_root.visible = true
	UiSound.play(self, "tab")


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UiSound.play(self, "back")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tally") and not event.is_echo():
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		if Time.get_ticks_msec() < _armed_until and event.is_action_pressed("interact") and not event.is_echo():
			open()
			get_viewport().set_input_as_handled()
		return
	if Time.get_ticks_msec() - _opened_ms < 200:
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and (event.physical_keycode in [KEY_Q, KEY_E, KEY_LEFT, KEY_RIGHT]):
		_page = (_page + (PAGES - 1 if (event.physical_keycode == KEY_Q or event.physical_keycode == KEY_LEFT) else 1)) % PAGES
		_fill()
		get_viewport().set_input_as_handled()
		return
	if _page == 3 and ((event is InputEventKey and event.pressed and not event.is_echo() and (event as InputEventKey).physical_keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN])):
		var up := (event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_UP, KEY_W]) or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_DPAD_UP)
		_led_sel = maxi(0, _led_sel + (-1 if up else 1))
		UiSound.play(self, "move")
		_fill()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and ((event as InputEventJoypadButton).button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]):
		var back := (event as InputEventJoypadButton).button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT]
		_page = (_page + (PAGES - 1 if back else 1)) % PAGES
		_fill()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse") or event.is_action_pressed("interact") \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()
