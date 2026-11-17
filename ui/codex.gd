extends CanvasLayer
## The Journal (codex). Three things in one layer (no class_name; RealmLore adds it to the zone):
##  1. The book: [J] / d-pad down, or the Satchel's "Journal" button, opens it (the world pauses).
##     Tabs: Wenna's Journal (pages in order, gaps kept), Stories (the multi-part series), Writings
##     (everything else read, grouped by region), Places (regions found), Relics (what the
##     satchel holds, with its flavour). Left: the list; right: the page. Q/E or A/D change tab,
##     up/down pick, Esc / J / Tab close.
##  2. The reading panel: reading an inscription (Inscription.interact -> show_reading) opens a
##     readable panel over the lower screen instead of a toast. It does not pause; it closes when
##     you walk away, read it again, get hurt, or open the book.
##  3. Region banners: entering a RealmLayout region names it; the first time, "Discovered" and
##     the place goes in the journal.
## Data: core/world/realm/lore/codex_store.gd (user://codex.cfg); texts: lore_db.gd.

const PageGrid := preload("res://ui/page_grid.gd")
const MapView := preload("res://ui/codex_map.gd")
const LoreDB := preload("res://core/world/realm/lore_db.gd")
const LoreIndex := preload("res://core/world/realm/lore/lore_index.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const ACTION := "codex"
const TABS := [["journal", "Wenna's Journal"], ["stories", "Stories"], ["writings", "Writings"], ["places", "Places"], ["map", "Map"], ["relics", "Relics"]]
const SecretState := preload("res://core/life/secrets/state.gd")
const SecretPages := preload("res://core/life/secrets/pages.gd")
const QBook := preload("res://core/story/quest_book.gd")
const QChains := preload("res://core/story/quest_chains.gd")
const QWorld := preload("res://core/story/quest_world.gd")
const VerbKit := preload("res://core/story/verb_kit.gd")
const UiSound := preload("res://ui/ui_sound.gd")   ## quiet menu sounds (F)
const TextDirector := preload("res://ui/text_director.gd")
const Banner := preload("res://core/world/realm/discovery_banner.gd")   ## r35: title_up, the title-card hold
## A finished story is worth something to a fire (once each, kept in the secrets' save as
## looted "series_<id>"): grave ash, and the Ninth Company's offering shows itself (site_company).
const SERIES_REWARD := {"grave_ash": 20}
const Med := preload("res://ui/medieval_style.gd")
const INK := Med.BONE
const PAPER := Med.BONE
const QUIET := Med.BONE_DIM
const EMBER := Color(1.0, 0.62, 0.3)
const READ_CLOSE_DIST := 4.5
const ROMAN := ["", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii"]

var _title_font: Font
var _body_font: Font
# book
var _book: Control
var hosted := false                 ## r35: a page of the character screen (it owns keys and pause)
var _head_ctl: Array[Control] = []  ## its Close link and tab strip (hidden when hosted)
const PAGE_IDS := ["journal", "stories", "writings", "places", "map", "lore"]   ## the screen's page ids by tab
var _tab := 0
var _tab_buttons: Array[Button] = []
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _counts: Label
var _p_title: Label
var _p_meta: Label
var _p_body: RichTextLabel
var _p_foot: Label
var _was_captured := false
var _first_button: Button
# reader
var _reader: PanelContainer
var _r_meta: Label
var _r_title: Label
var _r_body: RichTextLabel
var _r_foot: Label
var _r_new: Label
var _r_tw: Tween
var _r_src: Node3D
var _r_id := ""
# banners
var _banner: Control
var _b_top: Label
var _b_name: Label
var _b_line: Label
var _b_tw: Tween
var _region := ""
var _region_t := 0.0
var _banner_last: Dictionary = {}     ## region -> time of its last banner
var _clock := 0.0
var _arm_at := 6.5                     ## let the night's own title card finish first


## The night is torn down: the lore landmarks' static meshes and materials go with it.
func _exit_tree() -> void:
	for path: String in ["res://core/world/realm/lore/lore_assets.gd", "res://core/world/realm/lore/lore_kit.gd", "res://core/world/realm/lore/inscription.gd"]:
		var scr := load(path) as GDScript
		if scr:
			scr.call("release")


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("codex")
	CodexStore.ensure()
	_title_font = load("res://ui/fonts/Cinzel.ttf")
	var sf: Font = preload("res://ui/type.gd").body()
	_body_font = sf
	_build_banner()
	_build_reader()
	_build_book()
	Events.player_hurt.connect(func(_a: float, _f: Vector3) -> void: close_reading())
	Events.zone_entered.connect(_on_zone_entered)
	Events.zone_entered.connect(_on_title_card)


# --- public -----------------------------------------------------------------------------------

func is_open() -> bool:
	return _book.visible


func open_book(tab := -1) -> void:
	if not hosted and _cs() != null:
		_cs().call("open_at", "journal", PAGE_IDS[clampi(tab, 0, PAGE_IDS.size() - 1)] if tab >= 0 else "")
		return
	close_reading()
	var sat := get_tree().current_scene.get_node_or_null("Satchel") if get_tree().current_scene else null
	if sat and sat.has_method("is_open") and sat.call("is_open"):
		sat.call("close_menu")
	if tab >= 0:
		_tab = clampi(tab, 0, TABS.size() - 1)
	_book.visible = true
	if _b_tw:
		_b_tw.kill()
	_banner.modulate.a = 0.0
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_show_tab(_tab)


func close_book() -> void:
	if not _book.visible:
		return
	_book.visible = false
	if hosted:
		var cs := get_tree().get_first_node_in_group(&"character_screen")
		if cs:
			cs.release(self)                  # closed directly: the screen closes too and gives the night back
		return                              # a page of the character screen: it keeps the pause and the mouse
	UiSound.play(self, "back")
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Open the reading panel for LoreDB entry `id`, read from `src` (closes when the player leaves it).
func show_reading(id: String, src: Node3D = null, fresh := false) -> void:
	if _r_id == id and _reader.visible and _reader.modulate.a > 0.5 and not fresh:
		close_reading()                    # [E] again on the same stone puts it down
		return
	var e := LoreIndex.entry(id)
	if e.is_empty():
		return
	_r_id = id
	_r_src = src
	_r_meta.text = ("%s  ·  %s" % [LoreDB.kind_name(String(e.kind)), LoreDB.place_name(String(e.region))]).to_upper()
	_r_title.text = String(e.title)
	_r_body.text = _drop(String(e.text), 54)
	var foot := ""
	var ser := String(e.get("series", ""))
	if ser != "":
		var sd: Dictionary = LoreIndex.series().get(ser, {})
		foot = "%s  ·  part %s of %d  ·  %d found" % [sd.get("title", ser), ROMAN[int(e.part)] if int(e.part) < ROMAN.size() else str(e.part), int(sd.get("count", 0)), _found_in_series(ser)]
	_r_new.visible = fresh
	if fresh:
		note_read(id)
	_r_new.text = "New in your journal" if fresh else ""
	var key := _key_name(ACTION, "J")
	_r_foot.text = (foot + "\n" if foot != "" else "") + "[%s] read again to close   ·   [%s] journal" % [Interactable.prompt_key(), key]
	_reader.visible = true
	if _r_tw:
		_r_tw.kill()
	_reader.modulate.a = 0.0
	_r_tw = create_tween()
	_r_tw.tween_property(_reader, "modulate:a", 1.0, 0.35)


func close_reading() -> void:
	if not _reader.visible:
		return
	_r_id = ""
	_r_src = null
	if _r_tw:
		_r_tw.kill()
	_r_tw = create_tween()
	_r_tw.tween_property(_reader, "modulate:a", 0.0, 0.3)
	_r_tw.tween_callback(func() -> void: _reader.visible = false)


## A writing was read for the first time: a finished story pays out once (and says so).
func note_read(id: String) -> void:
	var s := LoreIndex.completed_series(id, func(x: String) -> bool: return CodexStore.has_read(x))
	if s == "" or SecretState.has("looted", "series_" + s):
		return
	SecretState.mark("looted", "series_" + s)
	var parts := PackedStringArray()
	for item: String in SERIES_REWARD:
		Travel.give(item, int(SERIES_REWARD[item]), false)
		parts.append("%s x%d" % [SecretPages.item_name(item), int(SERIES_REWARD[item])])
	var sd: Dictionary = LoreIndex.series().get(s, {})
	SecretState.toast("Story complete: %s.  %s" % [String(sd.get("title", s)), ", ".join(parts)])
	SecretState.banner("a story complete", String(sd.get("title", s)))


func reading_id() -> String:
	return _r_id if _reader.visible else ""


## Name the region the wanderer stands in (and journal it the first time). Tests call it directly.
func enter_region(id: String) -> void:
	if id == "" or id == _region:
		return
	_region = id
	var info: Dictionary = LoreDB.PLACE_INFO.get(id, {})
	if info.is_empty():
		return
	var fresh := CodexStore.discover(id)
	var last := float(_banner_last.get(id, -1000.0))
	if not fresh and _clock - last < 60.0:
		return
	_banner_last[id] = _clock
	if _clock < _hold_until or Banner.title_up(self) or _in_combat():
		# the zone's title card is up (arrival, the ending's card): name the place after it fades
		_held = [String(info.name), String(info.line), fresh]
		return
	_show_banner(String(info.name), String(info.line), fresh)


var _hold_until := 0.0


## A fight is on: the place banner waits (it is held, then shown when the fight ends).
func _in_combat() -> bool:
	var td := TextDirector.of(self)
	return td != null and td.in_combat()
var _held: Array = []


func _on_title_card(_t: String, _s: String) -> void:
	_hold_until = _clock + 4.6


# --- input ----------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _cs() != null:
		if not _book.visible:
			return                              # the character screen opens it (the reader is the inscriptions')
		if event.is_action_pressed(ACTION) or event.is_action_pressed("toggle_settings") or event.is_action_pressed("inventory") \
				or event.is_action_pressed("release_mouse") \
				or (event is InputEventKey and ((event as InputEventKey).physical_keycode == KEY_Q or (event as InputEventKey).physical_keycode == KEY_E)) \
				or event is InputEventJoypadButton:
			return                              # its keys, its pages and the pad's B are the screen's
	elif event.is_action_pressed(ACTION):
		if _book.visible:
			close_book()
		elif not get_tree().paused or _satchel_open():
			open_book()
		get_viewport().set_input_as_handled()
		return
	if not _book.visible:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("inventory") or event.is_action_pressed("release_mouse"):
		close_book()
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc == KEY_Q or kc == KEY_A or kc == KEY_LEFT:
			step = -1
		elif kc == KEY_E or kc == KEY_D or kc == KEY_RIGHT:
			step = 1
	elif event is InputEventJoypadButton and event.pressed:
		var jb := (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif jb == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
		elif jb == JOY_BUTTON_B:
			close_book()
			get_viewport().set_input_as_handled()
			return
	if step != 0:
		UiSound.play(self, "tab")
		_show_tab((_tab + step + TABS.size()) % TABS.size())
		get_viewport().set_input_as_handled()


func _satchel_open() -> bool:
	var sat := get_tree().current_scene.get_node_or_null("Satchel") if get_tree().current_scene else null
	return sat != null and sat.has_method("is_open") and bool(sat.call("is_open"))


func _process(delta: float) -> void:
	_clock += delta
	if not _held.is_empty() and _clock >= _hold_until and not Banner.title_up(self) and not _in_combat():
		var h := _held
		_held = []
		_show_banner(String(h[0]), String(h[1]), bool(h[2]))
	# a region banner never draws over a menu or a conversation (they pause the tree): it waits
	_banner.visible = not get_tree().paused
	if get_tree().paused:
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	# the reading panel closes when you walk away from the stone
	if _reader.visible and _r_id != "":
		if _r_src == null or not is_instance_valid(_r_src) or _r_src.global_position.distance_to(p.global_position) > READ_CLOSE_DIST:
			close_reading()
	_region_t -= delta
	if _clock < _arm_at or _region_t > 0.0:
		return
	_region_t = 0.5
	if Travel.busy():
		return
	# r33 world: the zone discovery (core/world/realm/realm_discovery.gd) names places and journals them
	if get_tree().get_first_node_in_group("realm_discovery") != null:
		return
	var id := _region_for(p.global_position)
	if id != "":
		enter_region(id)


## Region under xz with hysteresis: a new region must be clearly entered (weight >= 0.6) and the
## current one clearly left (< 0.3) before the name changes.
func _region_for(at: Vector3) -> String:
	if RealmLayout.OSSUARY_HALL.has_point(at):
		at = Vector3(-8.0, at.y, 168.0)      # the pit hall under the downs is the Ossuary's (a point in its region)
	var best := ""
	var best_w := 0.0
	var cur_w := 0.0
	var best_s := 0.0
	for r: Dictionary in RealmLayout.REGIONS:
		# the same pick as RealmLayout.region_at (most specific place), with the plateau weight for
		# the hysteresis (r30: a landmark inside a rect used to lose every tie and never be named)
		var w := RealmLayout.place_weight(r, at.x, at.z)
		var sc := RealmLayout.place_score(r, at.x, at.z)
		if String(r.id) == _region:
			cur_w = w
		if sc > best_s:
			best_s = sc
			best_w = w
			best = String(r.id)
	if best == _region or best_w < 0.6:
		return ""
	# stepping into a landmark's full ground (both at full weight, the smaller place wins) is an entry
	var into_place := best_w >= 0.99 and cur_w >= 0.99
	if _region != "" and cur_w >= 0.3 and best_w - cur_w < 0.4 and not into_place:
		return ""
	return best


func _on_zone_entered(title: String, _sub: String) -> void:
	if title.to_lower().contains("ossuary"):
		CodexStore.discover("ossuary")


# --- banner ---------------------------------------------------------------------------------

func _build_banner() -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_b_top = _label(_banner, "", 20, EMBER, _title_font, HORIZONTAL_ALIGNMENT_CENTER)
	_b_name = _label(_banner, "", 50, INK, _title_font, HORIZONTAL_ALIGNMENT_CENTER)
	_b_line = _label(_banner, "", 24, Color(0.78, 0.72, 0.86), _body_font, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 3:
		var l: Label = [_b_top, _b_name, _b_line][i]
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		l.offset_left = -900
		l.offset_right = 900
		l.offset_top = [188.0, 214.0, 282.0][i]
		l.offset_bottom = l.offset_top + [28.0, 66.0, 34.0][i]
	_b_line.add_theme_font_size_override("font_size", 24)
	_banner.modulate.a = 0.0


func _show_banner(name_text: String, line: String, fresh: bool) -> void:
	_b_top.text = "— discovered —" if fresh else ""
	_b_name.text = name_text.to_upper()
	_b_name.add_theme_font_size_override("font_size", 50 if fresh else 36)
	_b_line.text = line if fresh else ""
	if _b_tw:
		_b_tw.kill()
	_b_tw = create_tween()
	_b_tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)     # held (and hidden) while a menu pauses the world
	_b_tw.tween_property(_banner, "modulate:a", 1.0, 0.9)
	_b_tw.tween_interval(3.4 if fresh else 1.8)
	_b_tw.tween_property(_banner, "modulate:a", 0.0, 1.2)


# --- reading panel ----------------------------------------------------------------------------

func _build_reader() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_reader = PanelContainer.new()
	_reader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reader.add_theme_stylebox_override("panel", Med.panel("parchment", 40))
	_reader.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_reader.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_reader.offset_left = -440
	_reader.offset_right = 440
	_reader.offset_bottom = -232
	_reader.offset_top = -232
	root.add_child(_reader)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reader.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_r_meta = _label(head, "", 15, Med.INK_DIM, _title_font)
	_r_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_r_new = _label(head, "", 15, Med.INK_RED, _title_font, HORIZONTAL_ALIGNMENT_RIGHT)
	_r_title = _label(col, "", 30, Med.INK, _title_font)
	for ink_l: Label in [_r_meta, _r_new, _r_title]:
		_ink(ink_l, ink_l.get_theme_color("font_color"))
	col.add_child(Med.rule(Color(Med.INK_RED, 0.7)))
	_r_body = _body_rich(col, 25, 820.0, 6)
	_r_foot = _label(col, "", 15, Med.INK_DIM, _body_font)
	_ink(_r_foot, Med.INK_DIM)
	_reader.visible = false


# --- the book -------------------------------------------------------------------------------

func _build_book() -> void:
	_book = Control.new()
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_book)
	var dim := ColorRect.new()
	dim.color = Med.BACKDROP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = Med.theme()
	panel.add_theme_stylebox_override("panel", _paper_box(0.97, 30))
	_book.add_child(panel)
	PageGrid.place(panel)                              # the character screen's one grid cell: the book fills it
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	Med.gilt(_label(head, "JOURNAL", 34, INK, _title_font), 34)
	_counts = _label(head, "", 16, QUIET, _body_font)
	_counts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var close := Button.new()
	close.text = "Close  [%s]" % _key_name(ACTION, "J")
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_color_override("font_color", QUIET)
	close.add_theme_font_override("font", _title_font)
	close.pressed.connect(close_book)
	head.add_child(close)
	_head_ctl.append(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	_head_ctl.append(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = String(TABS[i][1]).to_upper()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", _title_font)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", QUIET)
		b.add_theme_color_override("font_pressed_color", EMBER)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_stylebox_override("normal", _tab_box(false))
		b.add_theme_stylebox_override("hover", _tab_box(false))
		b.add_theme_stylebox_override("pressed", _tab_box(true))
		b.add_theme_stylebox_override("hover_pressed", _tab_box(true))
		var idx := i
		b.pressed.connect(func() -> void: _show_tab(idx))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var hint := _label(tabs, "   Q / E  change page", 14, QUIET, _body_font)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(_rule())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var well := PanelContainer.new()                   # the list sits in a recess of the leather
	well.add_theme_stylebox_override("panel", Med.inset(10))
	body.add_child(well)
	_list_scroll = ScrollContainer.new()
	_list_scroll.custom_minimum_size = Vector2(420, 300)
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	well.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	var sheet := PanelContainer.new()                  # the open page: a sheet of vellum set into the leather
	sheet.add_theme_stylebox_override("panel", Med.panel("parchment", 40))
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(sheet)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_child(page)
	_p_meta = _label(page, "", 15, Med.INK_DIM, _title_font)
	_p_title = _label(page, "", 32, Med.INK, _title_font)
	_p_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ink(_p_meta, Med.INK_DIM)
	_ink(_p_title, Med.INK)
	page.add_child(Med.rule(Color(Med.INK_RED, 0.7)))
	_p_body = _body_rich(page, 24, 640.0, 7)
	_p_foot = _label(page, "", 16, Med.INK_DIM, _body_font)
	_ink(_p_foot, Med.INK_DIM)
	_p_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_p_foot.custom_minimum_size = Vector2(640, 0)
	_map_view = MapView.new()
	_map_view.custom_minimum_size = Vector2(600, 360)
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.set("font", _body_font)
	_map_view.set("title_font", _title_font)
	_map_view.visible = false
	page.add_child(_map_view)
	_book.visible = false


func _show_tab(i: int) -> void:
	_tab = i
	_map_view.visible = String(TABS[i][0]) == "map"
	for c in _map_view.get_parent().get_children():      # the map has the whole sheet: no title, rule or text above it
		if c != _map_view and c != _p_foot:
			(c as Control).visible = not _map_view.visible
	for j in _tab_buttons.size():
		_tab_buttons[j].button_pressed = j == i
	for c in _list.get_children():
		c.queue_free()
	_first_button = null
	_counts.text = _count_line()
	match String(TABS[i][0]):
		"journal":
			_fill_series("wenna", false)
		"stories":
			for s: String in LoreIndex.series():
				if s != "wenna":
					_fill_series(s, true)
		"writings":
			_fill_writings()
		"places":
			_fill_places()
		"map":
			_fill_map()
		"relics":
			_fill_relics()
	if _first_button:
		_first_button.grab_focus()
		_first_button.pressed.emit()
	else:
		_page("", "", "Nothing here yet.", "")
	_list_scroll.scroll_vertical = 0


func _fill_series(s: String, header: bool) -> void:
	var sd: Dictionary = LoreIndex.series().get(s, {})
	var ids := LoreIndex.series_ids(s)
	var have := _found_in_series(s)
	_head("%s   %d / %d" % [String(sd.title) if header else "Wenna's pages", have, ids.size()])
	var gone: Array[String] = []
	for id in ids:
		var e := LoreIndex.entry(id)
		var part := int(e.part)
		var num: String = ROMAN[part] if part < ROMAN.size() else str(part)
		if CodexStore.has_read(id):
			_entry("%s.  %s" % [num, String(e.title)], func() -> void: _show_lore(id))
		else:
			gone.append(id)
	if not gone.is_empty():              # parts not yet found: one calm line, not a row each
		_entry("%d %s%s still to find" % [gone.size(), "page" if s == "wenna" else "part", "" if gone.size() == 1 else "s"], func() -> void:
			_page(String(sd.title).to_upper(), "Not yet found", "", "Somewhere in %s, perhaps. %s" % [LoreDB.place_name(String(LoreIndex.entry(gone[0]).region)), String(sd.blurb)]), true)


func _fill_writings() -> void:
	for region: String in LoreDB.REGION_ORDER:
		var all := LoreIndex.ids_in(region)
		var got: Array[String] = []
		var total := 0
		for id in all:
			if String(LoreIndex.entry(id).get("series", "")) != "":
				continue
			total += 1
			if CodexStore.has_read(id):
				got.append(id)
		if got.is_empty():
			continue
		_head("%s   %d / %d" % [LoreDB.place_name(region), got.size(), total])
		got.sort_custom(func(a: String, b: String) -> bool: return int(CodexStore.read[a]) < int(CodexStore.read[b]))
		for id in got:
			_entry(_label_for(id), func() -> void: _show_lore(id), false, IconArt.art("lore", String(LoreIndex.entry(id).get("kind", ""))))


func _fill_places() -> void:
	var unknown := 0
	for region: String in LoreDB.REGION_ORDER:
		var info: Dictionary = LoreDB.PLACE_INFO[region]
		if CodexStore.discovered(region):
			_entry(String(info.name), func() -> void: _show_place(region))
		else:
			unknown += 1
	if unknown > 0:
		_entry("%d places still unwalked" % unknown, func() -> void: _page("", "Unknown", "", "Places you have not yet walked."), true)


func _fill_relics() -> void:
	var ids: Array[String] = []
	for id: String in ItemDB.ORDER:
		if Travel.count(id) > 0:
			ids.append(id)
	for id in Travel.items:
		if not ItemDB.ORDER.has(id) and Travel.count(String(id)) > 0:
			ids.append(String(id))
	for id in ids:
		var d := ItemDB.def(id)
		_entry(String(d.name), func() -> void: _show_item(id), false, IconArt.art("reward", "item"))
	if ids.is_empty():
		_head("Your satchel is empty")


func _show_lore(id: String) -> void:
	var e := LoreIndex.entry(id)
	var meta := "%s  ·  %s" % [LoreDB.kind_name(String(e.kind)), LoreDB.place_name(String(e.region))]
	var foot := ""
	var ser := String(e.get("series", ""))
	if ser != "":
		var sd: Dictionary = LoreIndex.series()[ser]
		foot = "%s, part %s of %d." % [String(sd.title), ROMAN[int(e.part)], int(sd.count)]
	_page(meta.to_upper(), String(e.title), String(e.text), foot)


func _show_place(region: String) -> void:
	var info: Dictionary = LoreDB.PLACE_INFO[region]
	var all := LoreIndex.ids_in(region)
	var got := 0
	for id in all:
		if CodexStore.has_read(id):
			got += 1
	var foot := ("Writings read here: %d of %d." % [got, all.size()]) if not all.is_empty() else ""
	_page(String(info.line).to_upper(), String(info.name), String(info.text), foot)


func _show_item(id: String) -> void:
	var d := ItemDB.def(id)
	var desc := String(d.get("desc", ""))
	var txt := String(d.get("text", ""))
	var kind := String(d.kind).capitalize()
	if String(d.kind) == "material":
		kind += "  ·  %d carried" % Travel.count(id)
	_page(kind.to_upper(), String(d.name), desc if desc != "" else txt, txt if desc != "" else "")


# --- the map: the valley as walked, the secret places found, how far each story has got --------

var _map_view: Control


func _fill_map() -> void:
	var found := _found_secrets()
	var marks: Array = []
	for f: Dictionary in found:
		marks.append({"at": Vector2((f.at as Vector3).x, (f.at as Vector3).z), "name": f.name})
	_map_view.set("marks", marks)
	_map_view.set("pins", _pins())
	_map_view.set("regions", _region_states())
	_map_view.set("focus", Vector2.INF)
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	_map_view.set("you", Vector2(pl.global_position.x, pl.global_position.z) if pl else Vector2.INF)
	if pl:
		var fwd := -pl.global_basis.z
		_map_view.set("you_dir", Vector2(fwd.x, fwd.z))
	_map_view.queue_redraw()
	var total := maxi(SecretState.sites.size(), SecretPages.SECRETS.size())
	_head("Secret places   %d / %d" % [found.size(), total])
	for f: Dictionary in found:
		var at := Vector2((f.at as Vector3).x, (f.at as Vector3).z)
		var nm := String(f.name)
		var region := String(SecretPages.SECRETS.get(String(f.id), {}).get("region", ""))
		_entry(nm, func() -> void:
			_map_view.set("focus", at)
			_map_view.queue_redraw()
			_page("THE VALLEY  ·  " + LoreIndex.place_name(region).to_upper(), nm, "", _map_foot()))
	if found.is_empty():
		_entry("None yet", func() -> void: _page("THE VALLEY", "Map", "", _map_foot()), true)
	# the tasks under way, each with a gold ring where it wants you
	var tasks := _task_pins()
	if not tasks.is_empty():
		_head("Tasks under way")
		for tp: Dictionary in tasks:
			var tat: Vector2 = tp.at
			var tname := String(tp.task)
			var step := String(tp.step)
			_entry(tname, func() -> void:
				_map_view.set("focus", tat)
				_map_view.queue_redraw()
				_page("A TASK", tname, "", step))
	_head("Stories")
	for sid: String in LoreIndex.series():
		var sd: Dictionary = LoreIndex.series()[sid]
		var have := _found_in_series(sid)
		var cnt := LoreIndex.series_ids(sid).size()
		var done := have >= cnt
		var label := "%s   %d / %d%s" % [String(sd.title), have, cnt, "   complete" if done else ""]
		var blurb := String(sd.blurb)
		_entry(label, func() -> void:
			_map_view.set("focus", Vector2.INF)
			_map_view.queue_redraw()
			_page("STORY", String(sd.title), "", ("Complete. " if done else "%d of %d parts found. " % [have, cnt]) + blurb), have == 0)
	_page("THE VALLEY", "Map", "", _map_foot())


func _map_foot() -> String:
	var places := 0
	for r: String in LoreDB.REGION_ORDER:
		if CodexStore.discovered(r):
			places += 1
	return "Places walked %d of %d.  Flames: the four braziers (grey until kindled).  Gold rings: your tasks.  Ember marks: secret places found.  The pale mark is you." % [places, LoreDB.REGION_ORDER.size()]


## Braziers (lit or not), the Kindled Keg, and the tasks' places: [{at, kind, name}].
func _pins() -> Array:
	var out: Array = []
	var scene := get_tree().current_scene
	var fires: Node = scene.get_node_or_null("Zone/Braziers") if scene else null
	if fires == null:
		fires = get_tree().root.find_child("Braziers", true, false)      # a night under a harness
	if fires:
		for n: String in ["StairFoot", "Shrine", "Landing", "Threshold"]:
			var b := fires.get_node_or_null(n) as Node3D
			if b:
				out.append({"at": Vector2(b.global_position.x, b.global_position.z), "kind": "fire" if bool(b.get("lit")) else "ash", "name": n})
	var keep := get_tree().get_first_node_in_group("keep") as Node3D
	if keep:
		out.append({"at": Vector2(keep.global_position.x, keep.global_position.z), "kind": "keg", "name": "The Kindled Keg"})
	for tp: Dictionary in _task_pins():
		out.append({"at": tp.at, "kind": "task", "name": tp.task})
	# the same pins the compass and the corner map read (group map_marker): a watch, a horse, a rung bell, a
	# roam event, a quest target. Not a second list: only what the book does not already draw is added.
	var drawn: Array[Vector2] = []
	for pn: Dictionary in out:
		drawn.append(pn.at)
	for m in get_tree().get_nodes_in_group(&"map_marker"):
		var m3 := m as Node3D
		if m3 == null or not m3.is_inside_tree() or not m3.has_meta(&"map_kind"):
			continue
		var kind := String(m3.get_meta(&"map_kind"))
		if kind in ["quest_available", "quest_turnin", "fire", "ash"] or (not m3.is_visible_in_tree() and not m3.has_meta(&"map_always")):
			continue
		var at := Vector2(m3.global_position.x, m3.global_position.z)
		var dup := false
		for d: Vector2 in drawn:
			dup = dup or d.distance_to(at) < 3.0
		if not dup:
			out.append({"at": at, "kind": "mark", "mk": kind, "name": String(m3.get_meta(&"map_label", kind)), "col": m3.get_meta(&"map_color", Color(1.0, 0.8, 0.4))})
	return out


## Where each task under way wants the wanderer now: the thing to find, the stone, the fen, or the
## person to talk to. [{at, task, step}]
func _task_pins() -> Array:
	var out: Array = []
	var spots: Dictionary = QWorld.spots
	var quests: Dictionary = QChains.QUESTS
	var pickups: Dictionary = QChains.PICKUPS
	var village := get_tree().root.find_child("Village", true, false)
	var people: Dictionary = village.get("villagers") if village and village.get("villagers") is Dictionary else {}
	var keep := get_tree().get_first_node_in_group("keep") as Node3D
	for id: String in QChains.ORDER:
		if not QBook.active(id):
			continue
		var s := QBook.step(id)
		var qd: Dictionary = quests[id]
		var kind := String((qd.steps as Array)[s].kind)
		var at := Vector3.INF
		match kind:
			"find", "gather", "place":
				var got: Dictionary = QBook.found(id)
				for k: String in pickups:
					var pk: Dictionary = pickups[k]
					if String(pk.quest) == id and int(pk.step) == s and not got.has(k):
						at = spots.get(k, Vector3.INF)
						break
			"escort" when not (qd.steps as Array)[s].has("path"):
				at = spots.get("stair", Vector3.INF)
			"escort", "defend":
				var live_at: Variant = ((qd.steps as Array)[s] as Dictionary).get("at")
				if live_at is Vector2:
					at = Vector3((live_at as Vector2).x, 0.0, (live_at as Vector2).y)
			"reach", "kill":
				at = spots.get("hollow", Vector3.INF)
			"clues", "tracks", "order", "lantern_walk", "vigil":
				# the task verbs: the middle of the area to search (clues, a trail), else the place the step names
				var vs: Dictionary = (qd.steps as Array)[s]
				var va := VerbKit.area(id, vs, QBook.q(id))
				var vp: Variant = va.c if not va.is_empty() else vs.get("to", vs.get("at"))
				if vp is Vector2:
					at = Vector3((vp as Vector2).x, 0.0, (vp as Vector2).y)
			"talk":
				var who := String(qd.giver)
				if s == 3 and id == "keg_thief":
					who = "nan"
				var pv: Variant = people.get(who)
				if is_instance_valid(pv) and pv is Node3D:
					at = (pv as Node3D).global_position
				elif keep:
					at = keep.global_position          # the keep and Ostrin are at the Keg
		if at == Vector3.INF:
			continue
		out.append({"at": Vector2(at.x, at.z), "task": String(qd.name), "step": QChains.step_text(id, s, QBook.q(id))})
	return out


## The secret places found so far: registered sites (with their positions) the save marks found.
func _found_secrets() -> Array:
	var out: Array = []
	for st: Dictionary in SecretState.sites:
		if SecretState.has("found", String(st.id)):
			out.append(st)
	return out


func _region_states() -> Array:
	var out: Array = []
	for r: Dictionary in RealmLayout.REGIONS:
		out.append({"r": r, "known": CodexStore.discovered(String(r.id)), "name": LoreDB.place_name(String(r.id))})
	return out


func _page(meta: String, title: String, body: String, foot: String) -> void:
	_p_meta.text = meta
	_p_title.text = title
	_p_body.text = _drop(body, 50)
	_p_foot.text = foot


func _head(t: String) -> void:
	var l := _label(_list, t.to_upper(), 17, Med.GILT_DEEP, _title_font)
	l.custom_minimum_size = Vector2(0, 40)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


func _entry(t: String, on_pick: Callable, missing := false, icon: Texture2D = null) -> void:
	var b := Button.new()
	b.text = t
	IconArt.on_button(b, icon, 24.0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = false
	b.clip_text = true
	b.custom_minimum_size = Vector2(400, 40)
	b.add_theme_font_override("font", _body_font)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", QUIET.darkened(0.1) if missing else PAPER)
	b.add_theme_color_override("font_focus_color", EMBER)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_stylebox_override("normal", _row_box(false))
	b.add_theme_stylebox_override("hover", _row_box(true))
	b.add_theme_stylebox_override("focus", _row_box(true))
	b.add_theme_stylebox_override("pressed", _row_box(true))
	b.pressed.connect(on_pick)
	b.focus_entered.connect(on_pick)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	_list.add_child(b)
	if _first_button == null and not missing:
		_first_button = b


## A list label: the entry's title, and for the many "Waystone"s and "Drowned grave"s the
## opening words too, so the list can be told apart.
func _label_for(id: String) -> String:
	var e := LoreIndex.entry(id)
	var title := String(e.title)
	var same := 0
	for other: String in LoreIndex.texts():
		if String(LoreIndex.texts()[other].title) == title:
			same += 1
	if same < 2:
		return title
	var words := String(e.text).split(" ", false)
	var lead := " ".join(words.slice(0, mini(5, words.size()))).trim_suffix(".").trim_suffix(",")
	return "%s:  %s..." % [title, lead]


func _count_line() -> String:
	var lore_total := LoreIndex.texts().size()
	var lore_read := 0
	for id: String in LoreIndex.texts():
		if CodexStore.has_read(id):
			lore_read += 1
	var places := 0
	for r: String in LoreDB.REGION_ORDER:
		if CodexStore.discovered(r):
			places += 1
	return "writings %d / %d    ·    places %d / %d    ·    pages %d / %d" % [lore_read, lore_total, places, LoreDB.REGION_ORDER.size(), _found_in_series("wenna"), int(LoreIndex.series().wenna.count)]


func _found_in_series(s: String) -> int:
	var n := 0
	for id in LoreIndex.series_ids(s):
		if CodexStore.has_read(id):
			n += 1
	return n


# --- little helpers ---------------------------------------------------------------------------

func _label(parent: Node, t: String, size: int, c: Color, font: Font, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


func _rule() -> Control:
	return Med.rule(Color(Med.BRONZE, 0.9))


## Ink on vellum: the label loses its shadow.
func _ink(l: Control, c: Color) -> void:
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))


## A body of text as a book page: first letter a dropped capital in oxblood Cinzel.
func _body_rich(parent: Node, size: int, w: float, sep: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(w, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", _body_font)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", Med.INK)
	r.add_theme_constant_override("line_separation", sep)
	parent.add_child(r)
	return r


func _drop(t: String, cap: int) -> String:
	return Med.drop_cap(t.replace("[", "[lb]"), cap) if not t.begins_with("[lb]") else t.replace("[", "[lb]")


func _paper_box(alpha: float, margin := 24) -> StyleBoxTexture:
	return Med.panel("leather", margin + 6)


func _tab_box(on: bool) -> StyleBoxTexture:
	return Med.tab(on)


func _row_box(on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.22, 0.09, 0.55) if on else Color(0, 0, 0, 0)
	sb.border_color = Med.GILT_DEEP
	sb.border_width_left = 3 if on else 0
	sb.content_margin_left = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func _key_name(action: String, fallback: String) -> String:
	if not InputMap.has_action(action):
		return fallback
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	return fallback


## r35: the character screen turns its pages.
func show_tab(i: int) -> void:
	_show_tab(clampi(i, 0, TABS.size() - 1))


## r35: hosted on the character screen, its Close link and tab strip go (the screen's replace them).
func set_hosted(on: bool) -> void:
	for c in _head_ctl:
		if is_instance_valid(c):
			c.visible = not on


## r35: the one character screen (ui/character_screen.gd), when the night has one.
func _cs() -> Node:
	return get_tree().get_first_node_in_group(&"character_screen") if is_inside_tree() else null
