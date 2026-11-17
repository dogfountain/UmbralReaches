extends CanvasLayer
## The merchants' shop (story/village; no class_name): Grisel's cart and the Keg's slate.
## Opened by the story director (core/story/story.gd `open_shop(who)`) after a conversation offers
## it. Stock and prices: core/life/village/village_shop.gd. Everything costs grave ash.
##   left: the wares, grouped (For the village / Goods), icon, name, price, how many left
##   right: the marked ware large, what it is, what it costs, why not (too poor, sold out), Buy
##   top: the merchant's name and her last line (typed and voiced); bottom: your ash
##   W/S or up/down or the mouse: choose     E / Enter / Space / click Buy: buy     Esc / B: leave
## The world pauses while it is open (like the dialogue box) and the mouse is freed.
## r33 loot (WoW's vendors): three tabs, [A/D] or click: WARES (as before), SELL (unworn gear and
## plain materials for ash, core/items/vendor.gd) and BUY BACK (what you sold, at the price paid).
## Gear and items show the shared tooltip (ui/item_tooltip.gd: quality colour, item level, set,
## flavour, and gear compared with what you wear); names are in their quality colour.

signal closed

const Shop := preload("res://core/life/village/village_shop.gd")
const Icons := preload("res://core/life/progression/icons.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const UiSound := preload("res://ui/ui_sound.gd")   ## quiet menu sounds (F)
const Vendor := preload("res://core/items/vendor.gd")          # r33 loot: sell / buy back
const LootDB := preload("res://core/items/loot_db.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const Tip := preload("res://ui/item_tooltip.gd")
const TABS := ["Wares", "Sell", "Buy back"]
const Med := preload("res://ui/medieval_style.gd")
const LANTERN := Med.GILT
const QUIET := Med.BONE_DIM
const ASH_TINT := Color(0.62, 0.58, 0.66)
const CPS := 55.0

var who := ""
var rows: Array = []
var sel := 0
var bought: Array[String] = []          ## ids bought this time (tests)
var _sell_ask := ""                      ## a named or Hallowed piece asks once: the id awaiting its second press
var tab := 0                            ## 0 wares, 1 sell, 2 buy back (r33 loot)
var _tab_btns: Array[Button] = []
var _d_rich: RichTextLabel

var _font: Font
var _panel: PanelContainer
var _title: Label
var _line: Label
var _list: VBoxContainer
var _icon_big: Control
var _d_name: Label
var _d_text: Label
var _d_price: Label
var _d_why: Label
var _buy: Button
var _ash: Label
var _ash_icon: Control
var _hint: Label
var _items: Array[Control] = []
var _open := false
var _paused_it := false
var _was_captured := false
var _shown := 0.0
var _voice_p: AudioStreamPlayer
var _voice := {}
var _syl_t := 0.0


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://ui/fonts/Cinzel.ttf")
	_build()
	Settings.input_device_changed.connect(func(_pad: bool) -> void:
		if _open:
			_refresh_hint())
	_voice_p = Voice.speaker2d(self)
	_panel.visible = false


func _label(size: int, col: Color, font := false) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -640
	_panel.offset_right = 640
	_panel.offset_top = -380
	_panel.offset_bottom = 380
	_panel.theme = Med.theme()
	var sb := Med.panel("leather", 34)
	sb.content_margin_top = 28
	sb.content_margin_bottom = 26
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_title = _label(32, LANTERN, true)
	Med.gilt(_title, 32)
	col.add_child(_title)
	_line = _label(21, Med.BONE)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 56)
	col.add_child(_line)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for i in TABS.size():
		var tb := Button.new()
		tb.text = String(TABS[i])
		tb.focus_mode = Control.FOCUS_NONE
		tb.toggle_mode = true
		tb.add_theme_font_override("font", _font)
		tb.add_theme_font_size_override("font_size", 20)
		tb.custom_minimum_size = Vector2(160, 40)
		Med.style_tab(tb)
		tb.pressed.connect(func() -> void: set_tab(i))
		tabs.add_child(tb)
		_tab_btns.append(tb)
	col.add_child(tabs)
	col.add_child(Med.rule())
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 26)
	col.add_child(row)
	# the wares
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", Med.inset(8))
	row.add_child(well)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	well.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	# the marked ware
	var det := PanelContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dsb := Med.inset(18)
	dsb.content_margin_top = 14
	det.add_theme_stylebox_override("panel", dsb)
	row.add_child(det)
	var dc := VBoxContainer.new()
	dc.add_theme_constant_override("separation", 10)
	det.add_child(dc)
	_icon_big = Control.new()
	_icon_big.custom_minimum_size = Vector2(0, 88)
	_icon_big.draw.connect(func() -> void:
		if sel >= 0 and sel < rows.size():
			_draw_icon(_icon_big, rows[sel], Vector2(_icon_big.size.x * 0.5, 44), 32.0, true))
	dc.add_child(_icon_big)
	var band := PanelContainer.new()                     # the name on its band, like the item cards
	band.add_theme_stylebox_override("panel", Med.banner())
	dc.add_child(band)
	_d_name = _label(24, LANTERN, true)
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	band.add_child(_d_name)
	dc.add_child(Med.rule())
	_d_text = _label(20, Med.BONE)
	_d_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dc.add_child(_d_text)
	_d_rich = RichTextLabel.new()
	_d_rich.bbcode_enabled = true
	_d_rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_d_rich.custom_minimum_size = Vector2(0, 150)
	_d_rich.add_theme_font_size_override("normal_font_size", 17)
	_d_rich.add_theme_font_size_override("bold_font_size", 19)
	_d_rich.add_theme_color_override("default_color", Med.BONE)
	_d_rich.visible = false
	dc.add_child(_d_rich)
	dc.add_child(Med.rule(Med.BRONZE, false))
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 10)
	dc.add_child(prow)
	prow.add_child(_ash_ctl(34.0))
	_d_price = _label(24, Med.GILT, true)
	prow.add_child(_d_price)
	_d_why = _label(18, Color(0.95, 0.55, 0.45))
	_d_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.add_child(_d_why)
	_buy = Button.new()
	_buy.text = "Buy"
	_buy.focus_mode = Control.FOCUS_NONE
	_buy.add_theme_font_override("font", _font)
	_buy.add_theme_font_size_override("font_size", 26)
	Med.style_button(_buy, 26, 16, 10)
	_buy.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	_buy.custom_minimum_size = Vector2(0, 54)
	_buy.pressed.connect(func() -> void: buy_marked())
	dc.add_child(_buy)
	# your ash, the keys
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	_ash_icon = _ash_ctl(36.0)
	foot.add_child(_ash_icon)
	_ash = _label(22, Med.GILT, true)
	foot.add_child(_ash)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fill)
	_hint = _label(17, Color(Med.BONE, 0.85))
	foot.add_child(_hint)


## The painted grave-ash icon as a small control `px` square.
func _ash_ctl(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: Icons.draw(c, Icons.item_glyph("grave_ash"), Vector2(px, px) * 0.5, px * 0.3, Color.WHITE if IconArt.art("item", "grave_ash") != null else ASH_TINT))
	return c


# --- open / close --------------------------------------------------------------------------------

func is_open() -> bool:
	return _open


func open(merchant: String, npc: Node3D = null) -> void:
	who = merchant
	var m: Dictionary = Shop.MERCHANTS.get(who, {"name": who.capitalize(), "greet": ""})
	_title.text = String(m.name)
	_voice = Voice.for_node(npc) if npc else Voice.profile("old_woman" if who == "grisel" else "keep", hash(who))
	_say(String(m.greet))
	sel = 0
	tab = 0
	_refresh()
	_panel.visible = true
	_open = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_paused_it = not get_tree().paused
	get_tree().paused = true
	Events.interact_hint.emit("")
	_refresh_hint()


func _refresh_hint() -> void:
	if Settings.using_pad:
		_hint.text = "[D-pad] choose / wares, sell, buy back     [%s] buy / sell     [B] leave" % Interactable.prompt_key()
	else:
		_hint.text = "[W/S] choose     [A/D] wares, sell, buy back     [%s] buy / sell     [Esc] leave" % Interactable.prompt_key()


func close() -> void:
	if not _open:
		return
	_open = false
	UiSound.play(self, "back")
	_panel.visible = false
	if _paused_it:
		get_tree().paused = false
	_paused_it = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


# --- the list --------------------------------------------------------------------------------------

func set_tab(i: int) -> void:
	_sell_ask = ""
	tab = clampi(i, 0, TABS.size() - 1)
	sel = 0
	UiSound.play(self, "tab")
	_refresh()


func _refresh() -> void:
	match tab:
		1:
			rows = Vendor.sell_rows()
		2:
			rows = Vendor.buyback_rows()
		_:
			rows = Shop.stock(who, get_tree())
	for i in _tab_btns.size():
		_tab_btns[i].set_pressed_no_signal(i == tab)
	for c in _items:
		c.queue_free()
	_items.clear()
	var group := ""
	for i in rows.size():
		var r: Dictionary = rows[i]
		if String(r.get("group", "")) != group:
			group = String(r.get("group", ""))
			if not _items.is_empty():
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 10)
				_list.add_child(gap)
				_items.append(gap)
			var h := _label(18, Med.GILT, true)
			h.text = group.to_upper()
			h.add_theme_constant_override("outline_size", 0)
			_list.add_child(h)
			_items.append(h)
			var hr := Med.rule(Color(Med.BRONZE, 0.8), false)
			_list.add_child(hr)
			_items.append(hr)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(600, 60)
		b.mouse_entered.connect(func() -> void:
			sel = i
			_mark())
		b.pressed.connect(func() -> void:
			sel = i
			_mark())
		var ic := Control.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(8, 5)
		ic.size = Vector2(50, 50)
		ic.draw.connect(func() -> void: _draw_icon(ic, r, Vector2(25, 25), 17.0, bool(r.ok)))
		b.add_child(ic)
		var nm_col := Color(0.92, 0.88, 0.82) if bool(r.ok) else Color(0.6, 0.58, 0.6)
		if r.has("quality") or r.has("item"):
			nm_col = LootDB.quality_color(int(r.get("quality", LootDB.item_quality(String(r.get("item", "")))))).lightened(0.1)
			if not bool(r.ok):
				nm_col = nm_col.darkened(0.35)
		var nm := _label(21, nm_col)
		nm.position = Vector2(70, 5)
		nm.size = Vector2(380, 30)
		nm.text = String(r.name)
		nm.clip_text = true
		b.add_child(nm)
		var sub := _label(16, Color(0.78, 0.72, 0.62, 0.9))
		sub.position = Vector2(70, 34)
		sub.text = String(r.get("sub", "")) if r.has("sub") else (("%d left" % int(r.left)) if int(r.left) > 0 else ("sold out" if int(r.left) == 0 else "once"))
		b.add_child(sub)
		var pr := _label(22, Med.GILT if bool(r.ok) else Color(0.62, 0.5, 0.5), true)
		pr.position = Vector2(420, 14)
		pr.size = Vector2(124, 30)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pr.text = "%d" % int(r.price)
		b.add_child(pr)
		var pic := _ash_ctl(30.0)
		pic.position = Vector2(552, 14)
		if not bool(r.ok):
			pic.modulate = Color(1, 1, 1, 0.5)
		b.add_child(pic)
		b.set_meta("row", i)
		_list.add_child(b)
		_items.append(b)
	if rows.is_empty():
		var none := _label(20, QUIET)
		none.text = ["Nothing left to sell you tonight.", "Nothing you carry is worth their ash. (Worn gear stays on.)", "You have sold them nothing tonight."][tab]
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none.custom_minimum_size = Vector2(580, 220)
		_list.add_child(none)
		_items.append(none)
	sel = clampi(sel, 0, maxi(rows.size() - 1, 0))
	_ash.text = "%d grave ash" % Travel.count("grave_ash")
	_mark()


func _mark() -> void:
	for c in _items:
		if c is Button:
			var i := int(c.get_meta("row"))
			var on := i == sel
			var plate: StyleBox = Med.plaque("hover", 8, 8) if on else StyleBoxEmpty.new()
			(c as Button).add_theme_stylebox_override("normal", plate)
			(c as Button).add_theme_stylebox_override("hover", plate)
			(c as Button).add_theme_stylebox_override("pressed", plate)
	if sel < rows.size():
		var r: Dictionary = rows[sel]
		_d_name.text = String(r.name)
		_d_text.text = String(r.text)
		_d_price.text = ("sells for %d grave ash" if tab == 1 else "%d grave ash") % int(r.price)
		_d_why.text = String(r.why)
		_buy.disabled = not bool(r.ok)
		_buy.visible = true
		_buy.text = ["Buy", "Sell", "Buy back"][tab]
		# r33 loot: gear and satchel items show the shared tooltip; the name takes its quality colour
		var bb := ""
		if r.has("piece"):
			var p: Dictionary = r.piece
			var gst := GearStats.state()
			bb = Tip.piece(p, GearStats.worn(gst).get(String(p.get("slot", "")), {}), gst, {"title_size": 1})
		elif r.has("item"):
			bb = Tip.item(String(r.item), Travel.count(String(r.item)))
		var q := -1
		if r.has("quality"):
			q = int(r.quality)
		elif r.has("item"):
			q = LootDB.item_quality(String(r.item))
		_d_name.add_theme_color_override("font_color", LootDB.quality_color(q).lightened(0.1) if q >= 0 else LANTERN)
		if bb != "":
			# the tooltip's own title line is dropped: the big name above already says it
			var parts := bb.split("\n", true, 1)
			_d_rich.text = parts[1] if parts.size() > 1 else bb
		_d_rich.visible = bb != ""
		_d_text.visible = bb == ""
	else:
		_d_name.text = ""
		_d_text.text = ""
		_d_price.text = ""
		_d_why.text = ""
		_buy.visible = false
	_icon_big.queue_redraw()


## Buy the marked ware. Returns true when it was bought.
func buy_marked() -> bool:
	if sel < 0 or sel >= rows.size():
		return false
	return buy(String(rows[sel].id))


func buy(id: String) -> bool:
	var r: Dictionary
	match tab:
		1:
			if sel < rows.size() and String(rows[sel].id) == id and bool(rows[sel].get("ask", false)) and _sell_ask != id:
				_sell_ask = id
				_say("%s for %d ash? Press again to sell." % [String(rows[sel].name), int(rows[sel].price)])
				return false
			_sell_ask = ""
			r = Vendor.sell(id)
		2:
			r = Vendor.buy_back(id)
		_:
			r = Shop.buy(who, id, get_tree())
	_say(String(r.say))
	if bool(r.ok):
		UiSound.play(self, "buy")
		bought.append(id)
		var keep := String(rows[sel].id) if sel < rows.size() else ""
		_refresh()
		for i in rows.size():
			if String(rows[i].id) == keep:
				sel = i
		_mark()
	return bool(r.ok)


# --- the merchant's line ----------------------------------------------------------------------------

func _say(s: String) -> void:
	_line.text = s
	_line.visible_characters = 0
	_shown = 0.0


func _process(delta: float) -> void:
	if not _open:
		return
	var n := _line.text.length()
	if int(_shown) < n:
		_shown = minf(_shown + delta * CPS, float(n))
		_line.visible_characters = int(_shown)
		_syl_t -= delta
		if _syl_t <= 0.0 and _line.text[mini(int(_shown), n - 1)] != " ":
			_syl_t = 0.075 / float(_voice.get("pace", 1.0))
			Voice.syllable(_voice_p, _voice, randf_range(0.96, 1.06), -7.0)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var handled := true
	if event.is_action_pressed("toggle_settings") or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		if int(_shown) < _line.text.length():
			_shown = float(_line.text.length())
			_line.visible_characters = -1
		else:
			buy_marked()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		set_tab((tab + 1) % TABS.size())
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		set_tab((tab + TABS.size() - 1) % TABS.size())
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		if not rows.is_empty():
			sel = (sel + 1) % rows.size()
			UiSound.play(self, "move")
			_mark()
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		if not rows.is_empty():
			sel = (sel + rows.size() - 1) % rows.size()
			UiSound.play(self, "move")
			_mark()
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		handled = false                     # buttons take the mouse
	elif event is InputEventKey or event is InputEventJoypadButton:
		pass                                # nothing else reaches the world while the shop is open
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# --- icons --------------------------------------------------------------------------------------------

func _draw_icon(ci: Control, r: Dictionary, c: Vector2, u: float, ok: bool) -> void:
	ci.draw_circle(c, u * 1.35, Color(0.0, 0.0, 0.0, 0.35))
	ci.draw_arc(c, u * 1.35, 0.0, TAU, 32, Color(1.0, 0.7, 0.28, 0.35 if ok else 0.15), 1.5)
	var dim := 1.0 if ok else 0.5
	if r.has("piece"):                       # r33 loot: gear, its slot glyph in its quality colour
		var qc := LootDB.quality_color(int(r.get("quality", 0))) * Color(dim, dim, dim, 1.0)
		ci.draw_arc(c, u * 1.35, 0.0, TAU, 32, qc, 2.0)
		Icons.draw(ci, String(GearDB.SLOT_GLYPH.get(String((r.piece as Dictionary).get("slot", "")), "prism")), c, u, qc.lightened(0.15))
		return
	var rg := Icons.row_glyph(r)
	if rg.contains("/"):                       # painted art: a round picture in the medallion
		Icons.draw(ci, rg, c, u * 0.8, Color(dim, dim, dim, 1.0))
		return
	if r.has("item"):
		var d := ItemDB.def(String(r.item))
		var tint := (d.get("tint", Color.WHITE) as Color) * Color(dim, dim, dim, 1.0)
		if not Icons.draw(ci, String(d.get("shape", "mound")), c, u, tint):
			# a shard: a long splinter with a bright edge
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u), c + Vector2(u * 0.42, -u * 0.1), c + Vector2(u * 0.12, u), c + Vector2(-u * 0.38, u * 0.15)]), tint)
			ci.draw_line(c + Vector2(0, -u), c + Vector2(u * 0.12, u), Color(1, 1, 1, 0.45 * dim), maxf(1.0, u * 0.06))
		return
	var col := Color(0.95, 0.78, 0.5) * Color(dim, dim, dim, 1.0)
	var w := maxf(1.5, u * 0.11)
	match String(r.get("glyph", "")):
		"oil":
			ci.draw_circle(c + Vector2(0, u * 0.25), u * 0.62, col)
			ci.draw_rect(Rect2(c + Vector2(-u * 0.18, -u * 0.85), Vector2(u * 0.36, u * 0.6)), col)
			ci.draw_rect(Rect2(c + Vector2(-u * 0.26, -u * 0.98), Vector2(u * 0.52, u * 0.16)), col.darkened(0.3))
			ci.draw_circle(c + Vector2(-u * 0.2, u * 0.1), u * 0.14, Color(1, 1, 1, 0.35 * dim))
		"rope":
			for k in 3:
				ci.draw_arc(c, u * (0.35 + 0.22 * float(k)), 0.4 * float(k), TAU * 0.92 + 0.4 * float(k), 28, col, w)
			ci.draw_line(c + Vector2(u * 0.8, 0), c + Vector2(u * 1.1, u * 0.7), col, w)
		"slates":
			for k in 3:
				var o := Vector2(-u * 0.1 * float(k), -u * 0.32 * float(k) + u * 0.4)
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(-u * 0.8, 0), c + o + Vector2(u * 0.6, -u * 0.12), c + o + Vector2(u * 0.75, u * 0.1), c + o + Vector2(-u * 0.65, u * 0.22)]), Color(0.6, 0.66, 0.78) * Color(dim, dim, dim, 1.0))
		"thatch":
			for k in 9:
				var x := (float(k) - 4.0) * u * 0.16
				ci.draw_line(c + Vector2(x * 0.5, -u * 0.9), c + Vector2(x * 1.3, u * 0.9), Color(0.85, 0.7, 0.38) * Color(dim, dim, dim, 1.0), w * 0.8)
			ci.draw_line(c + Vector2(-u * 0.45, -u * 0.1), c + Vector2(u * 0.45, -u * 0.1), col.darkened(0.4), w * 1.5)
		"mug", "mugs":
			var n := 2 if String(r.glyph) == "mugs" else 1
			for k in n:
				var o2 := Vector2((float(k) - 0.5 * float(n - 1)) * u * 0.95, float(k) * u * 0.12)
				ci.draw_rect(Rect2(c + o2 + Vector2(-u * 0.38, -u * 0.6), Vector2(u * 0.76, u * 1.2)), Color(0.6, 0.42, 0.25) * Color(dim, dim, dim, 1.0))
				ci.draw_rect(Rect2(c + o2 + Vector2(-u * 0.42, -u * 0.75), Vector2(u * 0.84, u * 0.2)), Color(0.96, 0.92, 0.82) * Color(dim, dim, dim, 1.0))
				ci.draw_arc(c + o2 + Vector2(u * 0.45, 0), u * 0.26, -PI * 0.5, PI * 0.5, 12, Color(0.6, 0.42, 0.25) * Color(dim, dim, dim, 1.0), w)
		"ear":
			for s: float in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(s * u * 0.32, -u * 0.1), u * 0.3, PI * 0.5 - 0.2, PI * 1.6, 14, col, w * 1.3)
				ci.draw_circle(c + Vector2(s * u * 0.32 + u * 0.05, -u * 0.38), u * 0.12, col)
		_:
			# the Hearthfire's trades name Kindling glyphs (hearth_db.gd); anything else is ash
			if not Icons.draw(ci, String(r.get("glyph", "")), c, u, col):
				Icons.draw(ci, "mound", c, u, ASH_TINT)
