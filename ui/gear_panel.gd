extends CanvasLayer
## Gear (docs/enshrouded/equipment.md): [O] (action "gear") opens it anywhere (the world pauses). Left: the four
## slots worn now and how far each set is woken. Middle: every piece carried, by slot, coloured by
## rarity. Right: the chosen piece (its base stat, affixes, set or legend, lore) and what can be
## done with it: wear / take off anywhere; raise, reforge an affix and salvage at a kindled fire
## (salvage works anywhere, but asks twice). Footer: what all the gear worn gives together.
## Keys: Enter wear, U raise, Y reforge, X salvage (twice), G / Esc close.
## Rules live in core/items/gear_runtime.gd; data in gear_db.gd. Fonts from ui/type.gd.
## r33 loot: the detail is the shared tooltip (ui/item_tooltip.gd: quality colour, item level,
## set pieces owned and bonuses greyed until worn, flavour, and green / red against what the slot
## holds); worn slots are framed in their piece's quality colour.

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const UIType := preload("res://ui/type.gd")
const Tip := preload("res://ui/item_tooltip.gd")
const LootDB := preload("res://core/items/loot_db.gd")

const INK := Color(0.92, 0.88, 1.0)
const QUIET := Color(0.64, 0.6, 0.74)
const DIM := Color(0.46, 0.43, 0.55)
const EDGE := Color(0.42, 0.32, 0.58)
const EMBER := Color(1.0, 0.66, 0.36)
const WARN := Color(0.95, 0.55, 0.42)
const PANEL_BG := Color(0.035, 0.02, 0.055, 0.97)

var _root: Control
var hosted := false                 ## r35: a page of the character screen (it owns keys and pause)
var _title_font: Font
var _body_font: Font
var _was_captured := false
var _fire: Node3D
var _filter := ""                     ## "" = every slot, else a slot id
var _sel_uid := -1
var _confirm_salvage := -1
var _reforge_idx := 0
var _rows: Array[int] = []            ## ItemList row -> piece uid

var _slot_btns := {}                  ## slot -> Button
var _all_btn: Button
var _sets_label: Label
var _list: ItemList
var _d_name: Label
var _d_kind: Label
var _d_body: Label
var _d_lore: Label
var _d_rich: RichTextLabel
var _b_wear: Button
var _b_up: Button
var _b_forge: Button
var _b_salv: Button
var _why: Label
var _purse: Label
var _fire_label: Label
var _sum: Label


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("gear_panel")
	# its key ("gear", O) is bound in autoload/input_setup.gd with every other action
	_title_font = UIType.title()
	_body_font = UIType.body()
	_build()
	_root.visible = false


func _runtime() -> Node:
	return get_tree().get_first_node_in_group("gear")


# --- building -----------------------------------------------------------------------------------

func _label(t: String, size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f if f else _body_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func _wrap(size: int, c: Color) -> Label:
	var l := _label("", size, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _body_font)
	b.add_theme_font_size_override("font_size", 17)
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.05, 0.13, 0.95) if st != "hover" else Color(0.16, 0.09, 0.22, 0.95)
		sb.border_color = EDGE if st != "hover" else INK
		sb.set_border_width_all(1)
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.pressed.connect(cb)
	return b


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.02, 0.76)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.5, 0.4, 0.8, 0.6)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(1180, 660)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label("GEAR", 30, INK, _title_font)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_fire_label = _label("", 16, QUIET)
	_fire_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_fire_label)
	var gap := Control.new()
	gap.custom_minimum_size.x = 24
	head.add_child(gap)
	_purse = _label("", 18, EMBER)
	_purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_purse)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	# worn slots + sets
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 290
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	left.add_child(_label("WORN", 18, QUIET, _title_font))
	for slot: String in GearDB.SLOTS:
		var b := _button("", _pick_slot.bind(slot))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(290, 58)
		b.clip_text = true
		_slot_btns[slot] = b
		left.add_child(b)
	_all_btn = _button("Show every slot", _pick_slot.bind(""))
	left.add_child(_all_btn)
	left.add_child(_label("SETS", 18, QUIET, _title_font))
	_sets_label = _wrap(15, QUIET)
	_sets_label.custom_minimum_size.x = 290
	left.add_child(_sets_label)

	# the satchel's gear
	var mid := VBoxContainer.new()
	mid.custom_minimum_size.x = 340
	body.add_child(mid)
	mid.add_child(_label("CARRIED", 18, QUIET, _title_font))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_override("font", _body_font)
	_list.add_theme_font_size_override("font_size", 17)
	_list.add_theme_color_override("font_color", INK)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.05, 0.03, 0.08, 0.9)
	lsb.border_color = EDGE
	lsb.set_border_width_all(1)
	lsb.set_content_margin_all(6)
	_list.add_theme_stylebox_override("panel", lsb)
	_list.item_selected.connect(func(i: int) -> void:
		if i >= 0 and i < _rows.size():
			_sel_uid = _rows[i]
			_confirm_salvage = -1
			_reforge_idx = 0
			UiSound.play(self, "move")
			_show())
	_list.item_activated.connect(func(_i: int) -> void: _wear_toggle())
	mid.add_child(_list)

	# detail
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_d_name = _label("", 26, INK, _title_font)
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_d_name)
	_d_kind = _label("", 16, QUIET)
	right.add_child(_d_kind)
	_d_body = _wrap(18, INK)
	right.add_child(_d_body)
	_d_lore = _wrap(16, DIM)
	right.add_child(_d_lore)
	var rs := ScrollContainer.new()
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rs)
	_d_rich = RichTextLabel.new()
	_d_rich.bbcode_enabled = true
	_d_rich.fit_content = true
	_d_rich.scroll_active = false
	_d_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_rich.add_theme_font_override("normal_font", _body_font)
	_d_rich.add_theme_font_override("bold_font", _body_font)
	_d_rich.add_theme_font_size_override("normal_font_size", 16)
	_d_rich.add_theme_color_override("default_color", INK)
	rs.add_child(_d_rich)
	_why = _wrap(16, WARN)
	right.add_child(_why)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	right.add_child(btns)
	_b_wear = _button("Wear [Enter]", _wear_toggle)
	_b_up = _button("Raise [U]", _upgrade)
	_b_forge = _button("Reforge [Y]", _reforge)
	_b_salv = _button("Salvage [X]", _salvage)
	for b: Button in [_b_wear, _b_up, _b_forge, _b_salv]:
		btns.add_child(b)

	_sum = _wrap(16, EMBER)
	col.add_child(_sum)


# --- open / close -------------------------------------------------------------------------------

func is_open() -> bool:
	return _root.visible


func open_menu() -> void:
	if _root.visible:
		return
	if not hosted and _cs() != null:
		_cs().call("open_at", "wanderer", "gear")
		return
	var k := get_tree().get_first_node_in_group("progression")
	_fire = k.call("at_fire") if k and k.has_method("at_fire") else null
	_root.visible = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_confirm_salvage = -1
	_rebuild()
	_list.grab_focus()
	UiSound.play(self, "tab")


func close_menu() -> void:
	if not _root.visible:
		return
	_root.visible = false
	UiSound.play(self, "back")
	if get_tree().paused:
		get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func at_fire() -> bool:
	return _fire != null and is_instance_valid(_fire)


func _process(_delta: float) -> void:
	if _root.visible and not get_tree().paused:
		close_menu()                       # someone else unpaused the world


func _input(event: InputEvent) -> void:
	if _cs() != null:
		if not _root.visible or event.is_action_pressed("gear") or event.is_action_pressed("toggle_settings") \
				or event.is_action_pressed("inventory") or event.is_action_pressed("kindling"):
			return                              # the character screen owns these
	elif event.is_action_pressed("gear") and not event.is_echo():
		if _root.visible:
			close_menu()
		elif not get_tree().paused:
			open_menu()
		get_viewport().set_input_as_handled()
		return
	if not _root.visible:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("inventory") or event.is_action_pressed("kindling"):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		match (event as InputEventKey).physical_keycode:
			KEY_U:
				_upgrade()
			KEY_Y:
				_reforge()
			KEY_X:
				_salvage()
			_:
				return
		get_viewport().set_input_as_handled()


# --- contents -----------------------------------------------------------------------------------

func _st() -> Dictionary:
	return GearStats.state()


func _worn_uid(st: Dictionary, uid: int) -> bool:
	for p: Dictionary in GearStats.worn(st).values():
		if int(p.uid) == uid:
			return true
	return false


func _rebuild() -> void:
	var st := _st()
	var worn := GearStats.worn(st)
	_fire_label.text = "At the fire: gear may be raised, reforged and salvaged." if at_fire() else "Away from a fire: wear and plan here; raise and reforge at a kindled brazier."
	_fire_label.add_theme_color_override("font_color", EMBER if at_fire() else QUIET)
	_purse.text = "Ash %d    Shards %d    Fragments %d" % [Travel.count("grave_ash"), Travel.count("ember_shard"), Travel.count("relic_fragment")]
	for slot: String in GearDB.SLOTS:
		var b: Button = _slot_btns[slot]
		var p: Dictionary = worn.get(slot, {})
		if p.is_empty():
			b.text = "%s\n  (nothing worn)" % GearDB.SLOT_NAMES[slot]
			b.add_theme_color_override("font_color", DIM)
		else:
			b.text = "%s  ·  ilvl %d\n  %s%s" % [GearDB.SLOT_NAMES[slot], GearDB.item_level(p), String(p.name), _lv(p)]
			b.add_theme_color_override("font_color", GearDB.rarity_color(int(p.rarity)))
		var nsb := b.get_theme_stylebox("normal") as StyleBoxFlat
		nsb.border_color = INK if _filter == slot else (LootDB.quality_color(int(p.rarity)).darkened(0.2) if not p.is_empty() else EDGE)
		nsb.set_border_width_all(2 if not p.is_empty() else 1)
	_all_btn.disabled = _filter == ""
	# sets
	var counts := GearStats.set_counts(st)
	var lines := PackedStringArray()
	for s: String in GearDB.SET_ORDER:
		var n := int(counts.get(s, 0))
		var owned := 0
		for slot: String in GearDB.SLOTS:
			if _owns_set_piece(st, s, slot):
				owned += 1
		if owned == 0:
			continue
		var sd: Dictionary = GearDB.SETS[s]
		lines.append("%s  %d/4 worn (%d found)" % [sd.name, n, owned])
		lines.append("  %s 2: %s" % ["*" if n >= 2 else "-", sd.two.text])
		lines.append("  %s 4: %s" % ["*" if n >= 4 else "-", sd.four.text])
	_sets_label.text = "\n".join(lines) if not lines.is_empty() else "No set pieces yet. Elites and the great ones carry them."
	# list
	_list.clear()
	_rows.clear()
	var bag: Array = (st.bag as Array).duplicate()
	bag.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := GearDB.SLOTS.find(String(a.slot))
		var sb := GearDB.SLOTS.find(String(b.slot))
		if sa != sb:
			return sa < sb
		if int(a.rarity) != int(b.rarity):
			return int(a.rarity) > int(b.rarity)
		return int(a.uid) < int(b.uid))
	var keep := -1
	for p: Dictionary in bag:
		if _filter != "" and String(p.slot) != _filter:
			continue
		var tag := "  (worn)" if _worn_uid(st, int(p.uid)) else ""
		var i := _list.add_item("%s%s%s" % [String(p.name), _lv(p), tag])
		_list.set_item_custom_fg_color(i, GearDB.rarity_color(int(p.rarity)))
		_list.set_item_tooltip_enabled(i, false)
		_rows.append(int(p.uid))
		if int(p.uid) == _sel_uid:
			keep = i
	if keep < 0 and not _rows.is_empty():
		keep = 0
		_sel_uid = _rows[0]
	if keep >= 0:
		_list.select(keep)
		_list.ensure_current_is_visible()
	else:
		_sel_uid = -1
	var sum := GearStats.summary(st)
	_sum.text = ("Worn gear gives: " + ", ".join(sum) + ".") if not sum.is_empty() else "Wear gear to grow stronger beside your charms. Foes drop it; elites and the great ones always do."
	_show()


func _owns_set_piece(st: Dictionary, s: String, slot: String) -> bool:
	for p: Variant in st.bag:
		if p is Dictionary and String(p.get("set", "")) == s and String(p.slot) == slot:
			return true
	return false


func _lv(p: Dictionary) -> String:
	var lv := int(p.get("level", 0))
	return "  +%d" % lv if lv > 0 else ""


func _show() -> void:
	var st := _st()
	var p := GearStats.find(st, _sel_uid)
	var has := not p.is_empty()
	for b: Button in [_b_wear, _b_up, _b_forge, _b_salv]:
		b.visible = has
	if not has:
		_d_name.text = "Nothing carried" if _filter == "" else "No %s carried" % GearDB.SLOT_NAMES[_filter]
		_d_name.add_theme_color_override("font_color", QUIET)
		_d_kind.text = ""
		_d_body.text = "Common foes now and then leave a piece behind in a shaft of light; tougher ones more often. Elites always do, and the great ones leave set pieces and, rarely, an Umbral relic."
		_d_lore.text = ""
		_d_rich.text = ""
		_d_body.visible = true
		_why.text = ""
		return
	var r := int(p.rarity)
	_d_name.text = String(p.name)
	_d_name.add_theme_color_override("font_color", GearDB.rarity_color(r))
	_d_kind.text = "%s %s   level %d of %d   %s" % [GearDB.rarity_name(r), GearDB.SLOT_NAMES[String(p.slot)], int(p.get("level", 0)), GearDB.max_level(p), GearDB.SLOT_WHERE[String(p.slot)]]
	var lines := PackedStringArray()
	lines.append(GearDB.base_line(p))
	var aff: Array = p.get("aff", [])
	for i in aff.size():
		var mark := "> " if i == _reforge_idx and aff.size() > 1 else "- "
		lines.append(mark + GearDB.affix_line(p, aff[i]))
	var lg := String(p.get("legend", ""))
	var lore := ""
	if GearDB.LEGENDS.has(lg):
		lines.append(String(GearDB.LEGENDS[lg].text))
		lore = String(GearDB.LEGENDS[lg].lore)
	if GearDB.trait_line(p) != "":
		lines.append(GearDB.trait_line(p))
	var s := String(p.get("set", ""))
	if GearDB.SETS.has(s):
		var sd: Dictionary = GearDB.SETS[s]
		var n := int(GearStats.set_counts(st).get(s, 0))
		lines.append("")
		lines.append("%s (%d/4 worn)" % [sd.name, n])
		lines.append("  2 worn: %s" % sd.two.text)
		lines.append("  4 worn: %s" % sd.four.text)
		lore = String(sd.lore)
	_d_body.text = "\n".join(lines)
	_d_lore.text = lore
	# r33 loot: the shared tooltip replaces the plain lines (kept in _d_body, hidden, for tests)
	var cur: Dictionary = GearStats.worn(st).get(String(p.slot), {})
	var tip := Tip.piece(p, cur, st)
	var parts := tip.split("\n", true, 1)
	_d_rich.text = parts[1] if parts.size() > 1 else tip
	if aff.size() > 1:
		_d_kind.text = "Reforge [Y] rerolls line %d: %s" % [_reforge_idx + 1, GearDB.affix_line(p, aff[_reforge_idx])]
	else:
		_d_kind.text = GearDB.SLOT_WHERE[String(p.slot)]
	_d_body.visible = false
	_d_lore.visible = false
	var worn := _worn_uid(st, int(p.uid))
	_b_wear.text = "Take off [Enter]" if worn else "Wear [Enter]"
	var uc := GearDB.upgrade_cost(p)
	_b_up.text = "Raise: %d ash, %d shards [U]" % [uc.ash, uc.shards] if not uc.is_empty() else "At its height"
	_b_up.disabled = uc.is_empty()
	var fc := GearDB.reforge_cost(p)
	_b_forge.text = ("Reforge a line: %d shards%s [Y]" % [fc.shards, ", 1 fragment" if int(fc.frag) > 0 else ""]) if not fc.is_empty() else "Nothing to reforge"
	_b_forge.disabled = fc.is_empty()
	_b_salv.text = ("Salvage: sure? +%d shards [X]" if _confirm_salvage == int(p.uid) else "Salvage: +%d shards [X]") % GearDB.salvage_value(p)
	var rt := _runtime()
	var why := ""
	if rt and not uc.is_empty():
		why = String(rt.call("why_not_upgrade", int(p.uid), at_fire()))
	_why.text = ("Raise: " + why) if why != "" else ""


# --- actions ------------------------------------------------------------------------------------

func _pick_slot(slot: String) -> void:
	_filter = slot
	_confirm_salvage = -1
	UiSound.play(self, "tab")
	_rebuild()


func _wear_toggle() -> void:
	var rt := _runtime()
	var p := GearStats.find(_st(), _sel_uid)
	if rt == null or p.is_empty():
		return
	if _worn_uid(_st(), int(p.uid)):
		rt.call("unequip", String(p.slot))
	else:
		rt.call("equip", int(p.uid))
	UiSound.play(self, "confirm")
	_rebuild()


func _upgrade() -> void:
	var rt := _runtime()
	if rt == null or _sel_uid < 0:
		return
	var res := String(rt.call("upgrade", _sel_uid, at_fire()))
	UiSound.play(self, "confirm" if res == "" else "back")
	_rebuild()
	if res != "":
		_why.text = res


func _reforge() -> void:
	var rt := _runtime()
	var p := GearStats.find(_st(), _sel_uid)
	if rt == null or p.is_empty():
		return
	var n := (p.get("aff", []) as Array).size()
	var res := String(rt.call("reforge", _sel_uid, _reforge_idx, at_fire()))
	if res == "" and n > 1:
		_reforge_idx = (_reforge_idx + 1) % n       # the next press reforges the next line
	UiSound.play(self, "confirm" if res == "" else "back")
	_rebuild()
	if res != "":
		_why.text = res


func _salvage() -> void:
	var rt := _runtime()
	if rt == null or _sel_uid < 0:
		return
	if _confirm_salvage != _sel_uid:
		_confirm_salvage = _sel_uid
		UiSound.play(self, "tick")
		_show()
		return
	_confirm_salvage = -1
	rt.call("salvage", _sel_uid)
	_sel_uid = -1
	UiSound.play(self, "confirm")
	_rebuild()


## r35: the one character screen (ui/character_screen.gd), when the night has one.
func _cs() -> Node:
	return get_tree().get_first_node_in_group(&"character_screen") if is_inside_tree() else null
