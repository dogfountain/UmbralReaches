extends CanvasLayer
## Gear (docs/enshrouded/equipment.md): [O] (action "gear") opens it anywhere (the world pauses); the
## Wanderer tab of the character screen shows it as its first page. It reads like an ARPG inventory:
##   left     the paper doll: the wanderer in her gear, turned by dragging her. Iron-rimmed sockets sit
##            round her where each is worn (Orb Focus by the staff hand, Vestment at the chest, Girdle at
##            the waist, Lantern Glass at the hip), then the staff core, charms and relics; under her the
##            sets and how far each is woken.
##   middle   the pack: an icon grid (rarity rims, item level in the corner, a marker on what is new),
##            filtered by slot and sorted; drag a piece onto its socket, or Enter / double-click.
##   right    the piece chosen as a tooltip (affix tiers as pips, set, legend, flavour) beside what the
##            slot holds now, the differences in green and red, and the actions.
## Wear / take off anywhere; raise, reforge a line and salvage at a kindled fire (salvage works anywhere,
## but asks twice). Keys: Enter wear, U raise, Y reforge, R next line, X salvage (twice), F filter, V sort.
## Mouse: click selects, double-click or right-click wears, drag to a socket. Pad: d-pad moves, A wears.
## Rules live in core/items/gear_runtime.gd; data in gear_db.gd; the card is ui/item_tooltip.gd.

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const UIType := preload("res://ui/type.gd")
const Tip := preload("res://ui/item_tooltip.gd")
const Card := preload("res://ui/item_card.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const DB := preload("res://core/life/progression/upgrade_db.gd")
const SlotView := preload("res://ui/gear_slot_view.gd")
const Doll := preload("res://ui/gear_doll.gd")
const IconCache := preload("res://ui/gear_icons.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
const W := preload("res://ui/gear_widgets.gd")
const PageGrid := preload("res://ui/page_grid.gd")
const PAGE_PT := 17                  ## the gear page's body type (the stat lines run above it at 20, the small print at 15)

const Med := preload("res://ui/medieval_style.gd")
const INK := Med.BONE
const QUIET := Med.BONE_DIM
const DIM := Med.BONE_FAINT
const EMBER := Color(1.0, 0.66, 0.36)
const WARN := Color(0.95, 0.55, 0.42)
const COLS := 6
const SORTS := ["Rarity", "Item level", "Slot", "Newest"]
## where each socket's thread meets the doll, as fractions of her picture (x, y)
const THREAD := {"core": Vector2(0.36, 0.06), "focus": Vector2(0.36, 0.43), "girdle": Vector2(0.47, 0.52),
	"vestment": Vector2(0.52, 0.32), "lantern": Vector2(0.64, 0.5)}

var _root: Control
var hosted := false                 ## a page of the character screen (it owns keys and pause)
var _title_font: Font
var _body_font: Font
var _was_captured := false
var _fire: Node3D
var _filter := ""                     ## "" = every slot, else a slot id
var _sort := 0
var _sel_uid := -1
var _sel_mini := ""                   ## a charm / relic / core id selected instead of a piece
var _sel_slot := ""                   ## an empty socket selected
var _confirm_salvage := -1
var _reforge_idx := 0
var _rows: Array[int] = []            ## grid order -> piece uid (what the filter lets through)

var _icons: IconCache
var _doll: Doll
var _stage: Control
var _sockets := {}                    ## slot (and "core") -> SlotView (a Dictionary of them: untyped)
var _cells: Array[SlotView] = []
var _chips := {}                      ## "" / slot -> Button
var _sort_btn: Button
var _count: Label
var _sets_rich: RichTextLabel
var _extras: HBoxContainer            ## charm and relic minis
var _d_name: Label
var _d_diff: RichTextLabel
var _card_a: PanelContainer
var _card_b: PanelContainer
var _cap_a: Label
var _cap_b: Label
var _b_wear: Button
var _b_up: Button
var _b_forge: Button
var _b_line: Button
var _b_salv: Button
var _why: Label
var _purse: Label
var _fire_label: Label
var _sum: RichTextLabel


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("gear_panel")
	# its key ("gear", O) is bound in autoload/input_setup.gd with every other action
	_title_font = UIType.title()
	_body_font = UIType.body()
	_icons = IconCache.new()
	add_child(_icons)
	_build()
	_root.visible = false


func _runtime() -> GearRuntime:
	return get_tree().get_first_node_in_group("gear") as GearRuntime


# --- building -----------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Med.BACKDROP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var margin := PageGrid.cell(_root)                # the character screen's one grid cell, under its tab band
	var panel := PanelContainer.new()
	panel.theme = Med.theme()
	var psb := Med.panel("leather", 20)
	panel.add_theme_stylebox_override("panel", psb)
	margin.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := W.label("GEAR", 30, Med.GILT, _title_font)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_fire_label = W.label("", 17, QUIET)
	_fire_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_fire_label)
	var gap := Control.new()
	gap.custom_minimum_size.x = 26
	head.add_child(gap)
	_purse = W.label("", 19, EMBER)
	_purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_purse)
	col.add_child(Med.rule())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_build_doll(body)
	_build_pack(body)
	_build_detail(body)


func _build_doll(body: HBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 470
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(470, 440)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_stretch_ratio = 2.4
	_stage.draw.connect(_draw_threads)
	_stage.resized.connect(_layout_stage)
	left.add_child(_stage)
	_doll = Doll.new()
	_stage.add_child(_doll)
	var defs := [["core", "Staff core"], ["focus", GearDB.SLOT_NAMES.focus], ["girdle", GearDB.SLOT_NAMES.girdle],
		["vestment", GearDB.SLOT_NAMES.vestment], ["lantern", GearDB.SLOT_NAMES.lantern]]
	for d: Array in defs:
		var v := SlotView.new()
		v.setup("socket", String(d[0]), String(d[1]))
		v.ghost = "core" if d[0] == "core" else String(GearDB.SLOT_GLYPH.get(String(d[0]), "prism"))
		v.picked.connect(_on_picked)
		v.clicked.connect(_on_clicked)
		v.toggled.connect(_on_toggled)
		v.dropped.connect(_on_dropped)
		_stage.add_child(v)
		_sockets[String(d[0])] = v
	_extras = HBoxContainer.new()
	_extras.add_theme_constant_override("separation", 6)
	_extras.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(_extras)
	var sets_head := W.label("SETS", 16, QUIET, _title_font)
	left.add_child(sets_head)
	var sc := ScrollContainer.new()                    # the set notes scroll, so a short window never pushes the panel off the screen
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 150)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inset := PanelContainer.new()
	inset.add_theme_stylebox_override("panel", Med.inset(8))
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.add_child(sc)
	left.add_child(inset)
	_sets_rich = W.rich(17)
	sc.add_child(_sets_rich)


func _build_pack(body: HBoxContainer) -> void:
	var mid := VBoxContainer.new()
	mid.custom_minimum_size.x = 478
	mid.add_theme_constant_override("separation", 8)
	body.add_child(mid)
	var hrow := HBoxContainer.new()
	mid.add_child(hrow)
	var ph := W.label("PACK", 20, Med.GILT, _title_font)
	ph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(ph)
	_count = W.label("", 17, QUIET)
	hrow.add_child(_count)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 3)
	mid.add_child(chips)
	for s: String in [""] + GearDB.SLOTS:
		var label := "All" if s == "" else String(GearDB.SLOT_NAMES[s]).split(" ")[0]
		var b := W.chip(label, _pick_slot.bind(s))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chips.add_child(b)
		_chips[s] = b
	_sort_btn = Button.new()
	_sort_btn.focus_mode = Control.FOCUS_ALL
	_sort_btn.add_theme_font_override("font", _body_font)
	Med.style_button(_sort_btn, 16, 10, 4)
	_sort_btn.pressed.connect(_cycle_sort)
	mid.add_child(_sort_btn)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", Med.inset(10))
	mid.add_child(well)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	well.add_child(grid)
	for i in GearDB.BAG_CAP:
		var c := SlotView.new()
		c.setup("cell")
		c.picked.connect(_on_picked)
		c.toggled.connect(_on_toggled)
		c.dropped.connect(_on_dropped)
		grid.add_child(c)
		_cells.append(c)
	var wh := W.label("WORN GEAR GIVES", 16, QUIET, _title_font)
	mid.add_child(wh)
	var inset := PanelContainer.new()
	inset.add_theme_stylebox_override("panel", Med.inset(8))
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inset.add_child(sc)
	_sum = W.rich(17)
	sc.add_child(_sum)
	mid.add_child(inset)


func _build_detail(body: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 700
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_d_name = W.label("", 1, INK)                        # kept for the pages that read the title; the card carries the name
	_d_name.visible = false
	right.add_child(_d_name)
	var diff_box := PanelContainer.new()
	diff_box.add_theme_stylebox_override("panel", Med.inset(8))
	right.add_child(diff_box)
	_d_diff = W.rich(21)
	diff_box.add_child(_d_diff)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(cards)
	var a := W.card("CHOSEN")
	cards.add_child(a[0])
	_card_a = a[1]
	_cap_a = a[3]
	(_card_a.get_meta(&"name") as Label).add_theme_font_size_override("font_size", 24)        # the title, the top of the page's type scale
	var b := W.card("WORN IN THIS SLOT")
	cards.add_child(b[0])
	_card_b = b[1]
	_cap_b = b[3]
	(_card_b.get_meta(&"name") as Label).add_theme_font_size_override("font_size", 24)
	_why = W.label("", 17, WARN)
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.custom_minimum_size.y = 24
	right.add_child(_why)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	right.add_child(btns)
	_b_wear = W.action("Wear", "Enter", _wear_toggle)
	_b_up = W.action("Raise", "U", _upgrade)
	_b_forge = W.action("Reforge", "Y", _reforge)
	_b_line = W.action("Line", "R", _next_line)
	_b_salv = W.action("Salvage", "X", _salvage)
	for bt: Button in [_b_wear, _b_up, _b_forge, _b_line, _b_salv]:
		bt.size_flags_stretch_ratio = 1.0        # five equal plates
		btns.add_child(bt)


# --- the doll stage -----------------------------------------------------------------------------

func _layout_stage() -> void:
	if _sockets.size() < 5:
		return                               # the stage is still being built
	var w := _stage.size.x
	var h := _stage.size.y
	var sw := SlotView.SOCKET
	var sh := SlotView.SOCKET + SlotView.CAPTION_H
	var avail := maxf(h - sh, 0.0)
	var dw := w - 2.0 * (sw + 14.0)
	_doll.position = Vector2(sw + 14.0, 0.0)
	_doll.size = Vector2(dw, h)
	var left := {"core": 0.0, "focus": 0.36, "girdle": 0.74}
	var right := {"vestment": 0.17, "lantern": 0.56}
	for k: String in left:
		(_sockets[k] as SlotView).position = Vector2(0.0, avail * float(left[k]))
		(_sockets[k] as SlotView).size = Vector2(sw, sh)
	for k: String in right:
		(_sockets[k] as SlotView).position = Vector2(w - sw, avail * float(right[k]))
		(_sockets[k] as SlotView).size = Vector2(sw, sh)
	_stage.queue_redraw()


## A thread of gilt from each socket to the part of her it belongs to.
func _draw_threads() -> void:
	if _doll == null:
		return
	for k: String in THREAD:
		var v := _sockets[k] as SlotView
		var left := v.position.x < _stage.size.x * 0.5
		var a := v.position + Vector2(v.size.x if left else 0.0, SlotView.SOCKET * 0.5)
		var t: Vector2 = THREAD[k]
		var b := _doll.position + Vector2(t.x * _doll.size.x, t.y * _doll.size.y)
		var mid := Vector2((a.x + b.x) * 0.5, a.y)
		var col := Color(Med.GILT_DEEP, 0.55)
		_stage.draw_polyline(PackedVector2Array([a, mid, b]), col, 1.5, true)
		_stage.draw_circle(b, 3.5, Med.GILT)
		_stage.draw_circle(b, 6.0, Color(Med.GILT, 0.25))


# --- open / close -------------------------------------------------------------------------------

func is_open() -> bool:
	return _root.visible


func open_menu() -> void:
	if _root.visible:
		return
	if not hosted and _cs() != null:
		_goto("wanderer", "gear")
		return
	var k := get_tree().get_first_node_in_group("progression")
	_fire = k.call("at_fire") if k and k.has_method("at_fire") else null
	_root.visible = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_confirm_salvage = -1
	_sel_mini = ""
	_sel_slot = ""
	_doll.set_active(true)
	_layout_stage.call_deferred()
	_rebuild()
	_focus_start()
	UiSound.play(self, "tab")


func close_menu() -> void:
	if not _root.visible:
		return
	_root.visible = false
	_doll.set_active(false)
	if hosted:
		var cs := get_tree().get_first_node_in_group(&"character_screen")
		if cs:
			cs.release(self)                  # closed directly: the screen closes too and gives the night back
		return                              # a page of the character screen: it keeps the pause and the mouse
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


func _focus_start() -> void:
	var want: SlotView = null
	for c: SlotView in _cells:
		if c.uid() == _sel_uid:
			want = c
	if want == null:
		for c: SlotView in _cells:
			if not c.piece.is_empty():
				want = c
				break
	if want == null:
		want = _sockets.focus as SlotView
	want.grab_focus()


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
			KEY_R:
				_next_line()
			KEY_X:
				_salvage()
			KEY_F:
				_cycle_filter()
			KEY_V:
				_cycle_sort()
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


func _sorted(bag: Array) -> Array:
	var out := bag.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := _sort_key(a)
		var kb := _sort_key(b)
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	return out


## Smaller sorts first: rarity and item level high to low, slot in the doll's order, newest first.
func _sort_key(p: Dictionary) -> Array:
	var r := -int(p.rarity)
	var il := -GearDB.item_level(p)
	var sl := GearDB.SLOTS.find(String(p.slot))
	var u := int(p.uid)
	match _sort:
		1:
			return [il, r, u]
		2:
			return [sl, r, u]
		3:
			return [-u]
	return [r, il, u]


func _rebuild() -> void:
	var st := _st()
	GearStats.seen_init(st)
	var worn := GearStats.worn(st)
	if not Slice.full():
		_fire_label.text = ""
	else:
		_fire_label.text = "At the fire: gear may be raised, reforged and salvaged." if at_fire() else "Away from a fire: wear and plan here; raise and reforge at a kindled brazier."
	_fire_label.add_theme_color_override("font_color", EMBER if at_fire() else QUIET)
	_purse.text = "Ash %d    Shards %d    Fragments %d" % [Travel.count("grave_ash"), Travel.count("ember_shard"), Travel.count("relic_fragment")]
	_doll.set_glass(int((worn.get("lantern", {}) as Dictionary).get("rarity", -1)))
	# sockets
	for slot: String in GearDB.SLOTS:
		var v := _sockets[slot] as SlotView
		var p: Dictionary = worn.get(slot, {})
		_dress(v, p, st, true)
		v.caption = String(GearDB.SLOT_NAMES[slot])
		v.selected = not p.is_empty() and int(p.uid) == _sel_uid or (p.is_empty() and _sel_slot == slot and _sel_uid < 0 and _sel_mini == "")
		v.queue_redraw()
	_dress_extras(st)
	for s: String in _chips:
		(_chips[s] as Button).button_pressed = s == _filter
	_sort_btn.text = "Sort: %s    [V]" % SORTS[_sort]
	# sets
	var counts := GearStats.set_counts(st)
	var sets := PackedStringArray()
	for s: String in GearDB.SET_ORDER:
		var owned := false
		for slot: String in GearDB.SLOTS:
			owned = owned or _owns_set_piece(st, s, slot)
		if owned:
			sets.append("\n".join(Tip.set_block(s, st)))
	_sets_rich.text = "\n\n".join(sets) if not sets.is_empty() else "[center]%s[/center]" % Tip._c(DIM, "No set pieces yet. Elites and the great ones carry them.")
	# the grid
	_rows.clear()
	var bag := _sorted(st.bag as Array)
	var shown: Array[Dictionary] = []
	for p: Dictionary in bag:
		if _filter == "" or String(p.slot) == _filter:
			shown.append(p)
			_rows.append(int(p.uid))
	_count.text = "%d / %d carried" % [(st.bag as Array).size(), GearDB.BAG_CAP]
	var chosen := GearStats.find(st, _sel_uid)
	var keep := not chosen.is_empty() and (_filter == "" or String(chosen.slot) == _filter)
	if not keep:
		_sel_uid = -1
		if _sel_mini == "" and _sel_slot == "" and not _rows.is_empty():
			_sel_uid = _rows[0]
	for i in _cells.size():
		var c := _cells[i]
		if i < shown.size():
			_dress(c, shown[i], st, false)
		else:
			_dress(c, {}, st, false)
	if _sel_uid >= 0:
		GearStats.mark_seen(st, _sel_uid)
	_sum_text(st)
	_show()


## Hand a socket or cell the piece and everything it draws from it.
func _dress(v: SlotView, p: Dictionary, st: Dictionary, socket: bool) -> void:
	v.set_piece(p)
	v.tex = _icons.icon(p) if not p.is_empty() else null
	v.corner = str(GearDB.item_level(p)) if not p.is_empty() else ""
	var lv := int(p.get("level", 0))
	v.badge = "+%d" % lv if lv > 0 else ""
	var sid := String(p.get("set", ""))
	v.set_tint = (GearDB.SETS[sid].tint as Color) if GearDB.SETS.has(sid) else Color(0, 0, 0, 0)
	var uid := int(p.get("uid", -1))
	v.is_worn = not socket and not p.is_empty() and _worn_uid(st, uid)
	v.is_new = not p.is_empty() and uid != _sel_uid and GearStats.is_new(st, uid)
	v.selected = not p.is_empty() and uid == _sel_uid
	v.queue_redraw()


func _dress_extras(st: Dictionary) -> void:
	for c in _extras.get_children():
		_extras.remove_child(c)
		c.queue_free()
	var pst := Travel.system_state("progression")
	var core := _sockets.core as SlotView
	var cid := DB.core_of(pst)
	var cd: Dictionary = {}
	for c: Dictionary in DB.CORES:
		if String(c.id) == cid:
			cd = c
	core.piece = {}
	core.ref_id = "core:" + cid
	core.rim = (cd.get("tint", Color.WHITE) as Color).lerp(Color.WHITE, 0.2)
	core.tex = _icons.item_icon(cid) if cid != "" else _icons.glyph_icon(String(cd.get("glyph", "core")), cd.get("tint", Color.WHITE))
	core.caption = String(cd.get("name", "Staff core"))
	core.corner = ""
	core.selected = _sel_mini == core.ref_id
	core.queue_redraw()
	# charms: one mini socket per cord
	_extras.add_child(W.label("CHARMS", 14, QUIET, _title_font))
	var worn_charms := DB.worn(pst)
	for i in DB.slots(pst):
		var m := _mini()
		if i < worn_charms.size():
			var id := String(worn_charms[i])
			var d := ItemDB.def(id)
			m.ref_id = id
			m.rim = (d.get("tint", Color.WHITE) as Color).lerp(Color.WHITE, 0.15)
			m.tex = _icons.item_icon(id)
			m.selected = _sel_mini == id
		else:
			m.ghost = "cord"
		_extras.add_child(m)
	var sp := Control.new()
	sp.custom_minimum_size.x = 14
	_extras.add_child(sp)
	_extras.add_child(W.label("RELICS", 14, QUIET, _title_font))
	var any := false
	for id: String in ItemDB.DEFS:
		var d2 := ItemDB.def(id)
		if String(d2.get("kind", "")) == "relic" and Travel.count(id) > 0 and _extras.get_child_count() < 16:
			var m2 := _mini()
			m2.ref_id = id
			m2.rim = (d2.get("tint", Color.WHITE) as Color).lerp(Color.WHITE, 0.15)
			m2.tex = _icons.item_icon(id)
			m2.selected = _sel_mini == id
			_extras.add_child(m2)
			any = true
	if not any:
		var m3 := _mini()
		m3.ghost = "hollow"
		_extras.add_child(m3)


func _mini() -> SlotView:
	var m := SlotView.new()
	m.setup("mini")
	m.picked.connect(_on_picked)
	m.toggled.connect(_on_toggled)
	return m


func _sum_text(st: Dictionary) -> void:
	var sum := GearStats.summary(st)
	if sum.is_empty():
		_sum.text = Tip._c(DIM, "Wear gear to grow stronger beside your charms. Foes drop it; elites and the great ones always do.")
		return
	var lines := PackedStringArray()
	for s: String in sum:
		lines.append(Tip._c(Tip.STAT, "+ " + s))
	_sum.text = "\n".join(lines)


func _owns_set_piece(st: Dictionary, s: String, slot: String) -> bool:
	for p: Variant in st.bag:
		if p is Dictionary and String(p.get("set", "")) == s and String(p.slot) == slot:
			return true
	return false


## The cards, the differences and the buttons for whatever is chosen.
func _show() -> void:
	var st := _st()
	var p := GearStats.find(st, _sel_uid)
	var has := not p.is_empty()
	_b_wear.visible = has
	for b: Button in [_b_up, _b_forge, _b_salv, _b_line]:      # the 30-minute slice hides upgrading (--full restores)
		b.visible = has and Slice.full()
	_why.text = ""
	_d_diff.text = ""
	_d_diff.get_parent().visible = has
	if not has:
		_show_other(st)
		return
	var r := int(p.rarity)
	var aff: Array = p.get("aff", [])
	_reforge_idx = clampi(_reforge_idx, 0, maxi(aff.size() - 1, 0))
	var cur: Dictionary = GearStats.worn(st).get(String(p.slot), {})
	var worn := _worn_uid(st, int(p.uid))
	_cap_a.text = "WORN" if worn else "CHOSEN"
	_d_name.text = String(p.name)                # the card's band carries the name; _d_name holds it bare for anything that reads it
	Tip.set_text(_card_a, Tip.piece(p, cur, st, {"full": true, "page": true, "no_compare": true, "head": false, "blocks": true, "reforge_idx": _reforge_idx if Slice.full() else -1}), r, String(p.name), PAGE_PT)
	_card_b.get_parent().visible = true
	if worn:
		_cap_b.text = "COMPARE"
		Tip.set_text(_card_b, "[center]\n%s[/center]" % Tip._c(DIM, "This is what you wear.\nChoose a carried piece to see it beside this one."), 0)
		_d_diff.get_parent().visible = false
	elif cur.is_empty():
		_cap_b.text = "WORN IN THIS SLOT"
		Tip.set_text(_card_b, "[center]%s[/center]\n%s\n[center]%s[/center]" % [Tip._c(DIM, "Nothing worn in %s." % GearDB.SLOT_NAMES[String(p.slot)]), Card.DIV, Tip._c(QUIET, GearDB.SLOT_WHERE[String(p.slot)])], 0, "Empty slot")
	else:
		_cap_b.text = "WORN IN THIS SLOT"
		Tip.set_text(_card_b, Tip.piece(cur, cur, st, {"full": true, "page": true, "no_compare": true, "head": false, "blocks": true}), int(cur.rarity), String(cur.name), PAGE_PT)
	if not worn:
		_d_diff.text = _diff_line(p, cur, st)
	_b_wear.disabled = false
	W.set_action(_b_wear, "Take off" if worn else "Wear", String(GearDB.SLOT_NAMES[String(p.slot)]))
	var uc := GearDB.upgrade_cost(p)
	_b_up.disabled = uc.is_empty()
	W.set_action(_b_up, "Raise", ("%d ash, %d shards" % [uc.ash, uc.shards]) if not uc.is_empty() else "At its height")
	var fc := GearDB.reforge_cost(p)
	_b_forge.disabled = fc.is_empty()
	W.set_action(_b_forge, "Reforge", ("line %d: %d shards%s" % [_reforge_idx + 1, fc.shards, " and a fragment" if int(fc.frag) > 0 else ""]) if not fc.is_empty() else "Nothing to reforge")
	_b_line.disabled = aff.size() < 2
	W.set_action(_b_line, "Line", ("next of %d" % aff.size()) if aff.size() > 1 else "")
	W.set_action(_b_salv, "Salvage: sure?" if _confirm_salvage == int(p.uid) else "Salvage", "+%d shards" % GearDB.salvage_value(p))
	var rt := _runtime()
	if rt and not uc.is_empty():
		var why := rt.why_not_upgrade(int(p.uid), at_fire())
		_why.text = ("Raise: " + why) if why != "" else ""


## The verdict, first on the page where the eye lands: what wearing the chosen piece changes, a green or red
## line each in two columns, at the stat size. Nothing more is said than the changes.
func _diff_line(p: Dictionary, cur: Dictionary, st: Dictionary) -> String:
	var diffs := GearStats.compare(p, cur, st)
	var head := "[center][font_size=15]%s[/font_size][/center]" % Tip._c(Med.GILT, ("INSTEAD OF " + String(cur.get("name", "")).to_upper()) if not cur.is_empty() else "THE SLOT IS EMPTY")
	if diffs.is_empty():
		return head + "\n[center]%s[/center]" % Tip._c(QUIET, "no change")
	var cells := ""
	for d: Array in diffs:
		cells += "[cell padding=0,1,28,1]%s[/cell]" % Tip._c(Tip.GOOD if bool(d[2]) else Tip.BAD, ("▲ " if bool(d[2]) else "▼ ") + String(d[1]))
	return head + "\n[table=2]" + cells + "[/table]"


## A charm, relic or core selected, or an empty socket.
func _show_other(st: Dictionary) -> void:
	for b: Button in [_b_up, _b_forge, _b_salv, _b_line]:
		b.visible = false
	_b_wear.visible = false
	_card_b.get_parent().visible = false
	_d_diff.get_parent().visible = false
	_cap_a.text = "CHOSEN"
	if _sel_mini.begins_with("core:"):
		var cid := _sel_mini.trim_prefix("core:")
		for c: Dictionary in DB.CORES:
			if String(c.id) == cid:
				Tip.set_text(_card_a, "[center]%s[/center]\n%s\n%s\n%s\n[center][i]%s[/i][/center]\n%s\n[center]%s[/center]" % [
					Tip._c(Tip.QUIET, "Staff core, in the orb"), Card.DIV_STRONG, Tip._c(Tip.INK, String(c.text)), Card.DIV,
					Tip._c(Tip.FLAVOUR, "\"%s\"" % String(c.get("lore", ""))), Card.DIV,
					Tip._c(Tip.QUIET, "Set at a kindled fire: Staff page.  [Enter] opens it.")], 3, String(c.name))
		return
	if _sel_mini != "":
		Tip.set_text(_card_a, Tip.item(_sel_mini, Travel.count(_sel_mini), {"head": false, "blocks": true}) + "\n" + Card.DIV + "\n[center]" + Tip._c(Tip.QUIET, "Change it in the Charms or Relics page.  [Enter] opens it.") + "[/center]",
			LootDB.item_quality(_sel_mini), String(ItemDB.def(_sel_mini).get("name", _sel_mini)))
		return
	if _sel_slot != "":
		Tip.set_text(_card_a, "[center]%s[/center]\n%s\n[center]%s[/center]" % [Tip._c(QUIET, String(GearDB.SLOT_WHERE[_sel_slot])), Card.DIV, Tip._c(QUIET, "Choose a piece from the pack, or drag one here.")], 0, "Empty: " + String(GearDB.SLOT_NAMES[_sel_slot]))
	else:
		Tip.set_text(_card_a, "[center]\n%s[/center]" % Tip._c(QUIET, "Nothing carried" if _filter == "" else "No %s carried.\n\nCommon foes now and then leave a piece behind in a shaft of light; tougher ones more often. Elites always do, and the great ones leave set pieces and, rarely, an Umbral relic." % GearDB.SLOT_NAMES[_filter]), 0)


# --- picking ------------------------------------------------------------------------------------

## Focus or a click on a square: choose what it holds.
func _on_picked(v: SlotView) -> void:
	var was := _sel_uid
	var was_other := _sel_mini + _sel_slot
	_confirm_salvage = -1
	if v.kind == "mini" or v.slot_id == "core":
		if v.ref_id == "":
			return                                  # an empty cord says nothing
		_sel_uid = -1
		_sel_slot = ""
		_sel_mini = v.ref_id
	elif v.kind == "socket" and v.piece.is_empty():
		_sel_uid = -1
		_sel_mini = ""
		_sel_slot = v.slot_id
	elif not v.piece.is_empty():
		_sel_uid = v.uid()
		_sel_mini = ""
		_sel_slot = ""
		_reforge_idx = 0 if was != _sel_uid else _reforge_idx
	else:
		return
	if was != _sel_uid or was_other != _sel_mini + _sel_slot:
		UiSound.play(self, "move")
		_refresh_marks()
		_show()


func _refresh_marks() -> void:
	var st := _st()
	if _sel_uid >= 0:
		GearStats.mark_seen(st, _sel_uid)
	for c: SlotView in _cells:
		c.selected = c.uid() >= 0 and c.uid() == _sel_uid
		c.is_new = c.uid() >= 0 and c.uid() != _sel_uid and GearStats.is_new(st, c.uid())
		c.queue_redraw()
	for slot: String in GearDB.SLOTS:
		var v := _sockets[slot] as SlotView
		v.selected = (v.uid() >= 0 and v.uid() == _sel_uid) or (v.piece.is_empty() and _sel_slot == slot)
		v.queue_redraw()
	(_sockets.core as SlotView).selected = _sel_mini == (_sockets.core as SlotView).ref_id
	_sockets.core.queue_redraw()
	for m in _extras.get_children():
		if m is SlotView:
			(m as SlotView).selected = _sel_mini != "" and (m as SlotView).ref_id == _sel_mini
			m.queue_redraw()


## A mouse click on a socket also filters the pack to its slot.
func _on_clicked(v: SlotView) -> void:
	if v.kind == "socket" and GearDB.SLOTS.has(v.slot_id) and _filter != v.slot_id:
		_pick_slot(v.slot_id)


func _on_toggled(v: SlotView) -> void:
	if v.kind == "mini" or v.slot_id == "core":
		var page := "staff" if v.slot_id == "core" else ("relics" if String(ItemDB.def(v.ref_id).get("kind", "")) == "relic" else "charms")
		_goto("wanderer", page)
		return
	if v.kind == "socket" and v.piece.is_empty():
		_pick_slot(v.slot_id)
		return
	_wear_toggle()


func _on_dropped(v: SlotView, data: Dictionary) -> void:
	var rt := _runtime()
	if rt == null:
		return
	if v.kind == "socket":
		rt.equip(int(data.gear_uid))
	else:
		rt.unequip(String(data.slot))
	_sel_uid = int(data.gear_uid)
	UiSound.play(self, "confirm")
	_rebuild()


# --- actions ------------------------------------------------------------------------------------

func _pick_slot(slot: String) -> void:
	_filter = slot
	_confirm_salvage = -1
	UiSound.play(self, "tab")
	_rebuild()


func _cycle_filter() -> void:
	var order: Array = [""] + GearDB.SLOTS
	_pick_slot(String(order[(order.find(_filter) + 1) % order.size()]))


func _cycle_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	UiSound.play(self, "tick")
	_rebuild()


func _next_line() -> void:
	var p := GearStats.find(_st(), _sel_uid)
	var n := (p.get("aff", []) as Array).size()
	if p.is_empty() or n < 2:
		return
	_reforge_idx = (_reforge_idx + 1) % n
	UiSound.play(self, "tick")
	_show()


func _wear_toggle() -> void:
	var rt := _runtime()
	var p := GearStats.find(_st(), _sel_uid)
	if rt == null or p.is_empty():
		return
	if _worn_uid(_st(), int(p.uid)):
		rt.unequip(String(p.slot))
	else:
		rt.equip(int(p.uid))
	UiSound.play(self, "confirm")
	_rebuild()


func _upgrade() -> void:
	if not Slice.full():
		return
	var rt := _runtime()
	if rt == null or _sel_uid < 0:
		return
	var res := rt.upgrade(_sel_uid, at_fire())
	UiSound.play(self, "confirm" if res == "" else "back")
	_rebuild()
	if res != "":
		_why.text = res
	else:
		var up := GearStats.find(_st(), _sel_uid)
		_why.text = "%s is now level %d." % [String(up.get("name", "It")), int(up.get("level", 0))]


func _reforge() -> void:
	if not Slice.full():
		return
	var rt := _runtime()
	var p := GearStats.find(_st(), _sel_uid)
	if rt == null or p.is_empty():
		return
	var n := (p.get("aff", []) as Array).size()
	var was := ""
	if _reforge_idx < n:
		was = GearDB.affix_line(p, (p.get("aff", []) as Array)[_reforge_idx])
	var at_idx := _reforge_idx
	var res := rt.reforge(_sel_uid, _reforge_idx, at_fire())
	if res == "" and n > 1:
		_reforge_idx = (_reforge_idx + 1) % n       # the next press reforges the next line
	UiSound.play(self, "confirm" if res == "" else "back")
	_rebuild()
	if res != "":
		_why.text = res
	else:
		# one line, the verb first: the affix that left and the one that came
		var np := GearStats.find(_st(), _sel_uid)
		var affs: Array = np.get("aff", [])
		if at_idx < affs.size():
			_why.text = "Reforged: %s becomes %s." % [was, GearDB.affix_line(np, affs[at_idx])]


func _salvage() -> void:
	if not Slice.full():
		return
	var rt := _runtime()
	if rt == null or _sel_uid < 0:
		return
	if _confirm_salvage != _sel_uid:
		_confirm_salvage = _sel_uid
		UiSound.play(self, "tick")
		_show()
		return
	_confirm_salvage = -1
	var sp := GearStats.find(_st(), _sel_uid)
	var shards := GearDB.salvage_value(sp) if not sp.is_empty() else 0
	rt.salvage(_sel_uid)
	_sel_uid = -1
	UiSound.play(self, "confirm")
	_rebuild()
	_why.text = "Salvaged: +%d shards." % shards
	_focus_start()


## The one character screen (ui/character_screen.gd), when the night has one.
func _cs() -> Node:
	return get_tree().get_first_node_in_group(&"character_screen") if is_inside_tree() else null


## Ask the character screen to turn to a page (the charms, the staff).
func _goto(top: String, page: String) -> void:
	var cs := _cs()
	if cs != null:
		cs.call("open_at", top, page)
