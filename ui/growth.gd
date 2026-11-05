extends CanvasLayer
## The Kindling (progression system, docs/LIFE_PLAN.md): grave ash fed to a kindled fire buys
## lasting growth. [K] opens it anywhere to plan; spending, oaths and attuning need a lit brazier
## within a few metres ([E] "Tend the fire" there opens it too, and so does the brazier's own
## "Attune"). The world pauses while it is open.
##   EMBERS  Gloom capacity, Gloom drift, spell power, recovery, a third charm cord
##   SPELLS  three ranks per spell; rank III changes how the spell behaves
##   OATHS   one of two vows per tier: builds differ
##   RELICS  attune the relics' variants, and buy the rite each relic or trophy unlocks
##   CHARMS  keepsakes found in the world, worn on cords
##   STAFF   the core in the orb (forged from relic fragments, or found): changes every Rift Bolt
##   LOADOUT which four spells sit on the hotbar beside Rift Bolt (swapped at a fire), and the
##           combos the kit can make
##   PATHS   the skill tree: three Paths (Hearth, Rift, Road) bought with Remembrances (memory
##           gathered from deeds; paths_db.gd), taken anywhere, given back at Hearthward's fire
##   HEARTH  the Hearthfire (hearth_db.gd): raise it at Hearthward's fire, see the village's
##           trades it opens, comfort, Rested and meals, and walk between fires (Brannoc's bells)
## Runtime and rules: core/life/progression/kindling.gd; data: upgrade_db.gd; icons: icons.gd.

const DB := preload("res://core/life/progression/upgrade_db.gd")
const PathsDB := preload("res://core/life/progression/paths_db.gd")
const HearthDB := preload("res://core/life/progression/hearth_db.gd")
const HearthRT := preload("res://core/life/progression/hearth.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const Icons := preload("res://core/life/progression/icons.gd")

const INK := Color(0.92, 0.88, 1.0)
const QUIET := Color(0.64, 0.6, 0.74)
const DIM := Color(0.46, 0.43, 0.55)
const LILAC := Color("#A98BFF")
const EDGE := Color(0.42, 0.32, 0.58)
const EMBER := Color(1.0, 0.66, 0.36)
const EMBER_HOT := Color(1.0, 0.84, 0.6)
const WARN := Color(0.95, 0.55, 0.42)
const PANEL_BG := Color(0.035, 0.02, 0.055, 0.97)
const TABS := [["embers", "Embers"], ["spells", "Spells"], ["oaths", "Oaths"], ["relics", "Relics"], ["charms", "Charms"], ["staff", "Staff"], ["loadout", "Loadout"], ["paths", "Paths"], ["hearth", "Hearth"]]
const Combo := preload("res://core/skills/combo.gd")
## The combos the kit can make (Loadout page): [name, what makes it, spells it needs].
const COMBOS := [
	["KINDLED RIFT", "Ember Lance bursts on a Marked foe: each Mark flares for 0.5 and the foe burns.", ["lance"]],
	["DETONATION", "Three or more Marks detonated at once: Umbral Nova, an Event Horizon, a Last Breath.", ["nova"]],
	["MAELSTROM", "Ember Lance bursts over an open Umbral Well: the well burns all it holds.", ["lance", "well"]],
	["SHATTER", "Ember Lance or Umbral Nova on a foe frozen by the Rime Core: twice the damage.", ["core_rime"]],
	["REEL", "Rift Tether III drags in a foe that already carried Marks: they burst at your feet.", ["tether"]],
	["SLIP LASH", "Rift Step II: the first bolt after a step is a Rift Lash.", ["step"]],
	["RIPOSTE LASH", "A strike passes through you mid-step: your next bolt is a Lash.", ["step"]],
]
const ROMAN := ["", "I", "II", "III"]
const RELIC_ROWS := ["thorn_heart", "bone_reliquary", "abbot_crown", "ascension_seal"]
const RELIC_FROM := {"thorn_heart": "the Thornwarden, in the Ring of Thorns", "bone_reliquary": "the Bone Abbot's charnel mound",
	"abbot_crown": "the Bone Abbot, below the Ossuary", "ascension_seal": "the Ascended Warden, at the summit"}

var _title_font: Font
var _body_font: Font
var _root: Control
var _tab := 0
var _tab_btns: Array[Button] = []
var _page_box: VBoxContainer
var _cards: Array[Card] = []
var _cols := 1
var _sel := 0
var _was_captured := false
var _ash_shown := 0.0
var _ash_label: Label
var _fire_label: Label
var _d_icon: Glyph
var _d_name: Label
var _d_kind: Label
var _d_text: Label
var _d_now: Label
var _d_lore: Label
var _d_btn: Button
var _d_why: Label
var _confirm := ""                  ## a forswear waiting for a second press
var _fx_layer: Control
var _chime: AudioStreamPlayer
var _fire: Node3D
var _slot_pick := 1                 ## Loadout: the hotbar slot a picked spell goes into
var _scroll: ScrollContainer
var _walks: Array[Node3D] = []      ## Hearth: the fires the bells can walk to, by card id


# --- the cards ----------------------------------------------------------------------------------

class Card extends Control:
	var menu: Node
	var kind := ""                   ## ember | rank | oath | rite | relic | charm | head | spell | learn | core | slot | pick
	var id := ""
	var sub := 0                     ## spell rank (1-3), oath tier
	var pick := ""                   ## oath side "a" | "b"
	var glyph := ""
	var tint := Color.WHITE
	var title := ""
	var line := ""
	var pips := Vector2i.ZERO
	var cost := 0
	var look := "open"               ## owned | open | poor | locked | forsworn | lost
	var selected := false
	var flash := 0.0
	var unit := "ASH"                ## what `cost` is counted in (a Path step costs Remembrances)
	var compact := false             ## a spell rank: numeral and name, no medallion
	var small := false               ## a narrow card (loadout, spell heads): small medallion, title may wrap
	var font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if kind == "head":
			return
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			menu.call("click_card", self)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER and kind != "head":
			menu.call("hover_card", self)

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var bg := Color(0.06, 0.035, 0.085, 0.94)
		var edge := EDGE
		var icon_col := tint
		var title_col := INK
		match look:
			"owned":
				bg = Color(0.1, 0.055, 0.06, 0.96)
				edge = Color(0.85, 0.55, 0.3, 0.9)
			"open":
				edge = LILAC
			"poor":
				edge = Color(EDGE, 0.9)
			"locked", "lost":
				bg = Color(0.035, 0.022, 0.05, 0.9)
				edge = Color(0.3, 0.24, 0.4, 0.7)
				icon_col = Color(tint.darkened(0.55), 0.7)
				title_col = DIM
			"forsworn":
				bg = Color(0.03, 0.02, 0.04, 0.9)
				edge = Color(0.28, 0.22, 0.34, 0.6)
				icon_col = Color(tint.darkened(0.6), 0.5)
				title_col = DIM
		if kind == "head":
			bg = Color(0, 0, 0, 0)
			edge = Color(0, 0, 0, 0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = edge
		sb.set_border_width_all(2 if selected else 1)
		sb.set_corner_radius_all(5)
		if selected:
			sb.border_color = edge.lightened(0.35)
			sb.shadow_color = Color(edge, 0.35)
			sb.shadow_size = 10
		draw_style_box(sb, r)
		if look == "owned" and kind != "head":
			draw_rect(Rect2(r.position + Vector2(6, 2), Vector2(r.size.x - 12, 2)), Color(1.0, 0.6, 0.3, 0.55))
		var f := font if font else ThemeDB.fallback_font
		if compact:
			_draw_compact(r, f, icon_col, title_col)
		else:
			_draw_full(r, f, icon_col, title_col)
		# the corner tag: what it costs, or what it is now
		if kind != "head":
			var tag := ""
			var tc := DIM
			if look == "owned":
				tag = {"charm": "WORN", "oath": "SWORN", "relic": "", "slot": "CHOSEN", "pick": "ON THE BAR", "core": "IN THE ORB", "spell": "",
					"path": "REMEMBERED", "service": "OPEN", "hearth": "BURNING", "walk": ""}.get(kind, "KINDLED")
				tc = Color(1.0, 0.7, 0.42, 0.95)
			elif look == "forsworn":
				tag = "FORSWORN"
			elif cost > 0:
				tag = "%d %s" % [cost, unit]
				tc = EMBER if look == "open" else (Color(WARN, 0.9) if look == "poor" else DIM)
			if tag != "":
				draw_string(f, Vector2(r.end.x - 150, r.end.y - 12), tag, HORIZONTAL_ALIGNMENT_RIGHT, 138, 13, tc)
		if flash > 0.0:
			var fl := StyleBoxFlat.new()
			fl.bg_color = Color(1.0, 0.7, 0.35, 0.35 * flash)
			fl.set_corner_radius_all(5)
			draw_style_box(fl, r)

	## Medallion on the left, title, up to three lines, rank pips along the bottom.
	func _draw_full(r: Rect2, f: Font, icon_col: Color, title_col: Color) -> void:
		var mr := minf(18.0 if small else 30.0, r.size.y * 0.28)
		var mc := Vector2(r.position.x + 16 + mr, r.position.y + r.size.y * 0.5 - (8.0 if pips.y > 0 else 0.0))
		if kind == "head":
			mc = Vector2(r.position.x + 10 + mr, r.position.y + r.size.y * 0.5)
		draw_circle(mc, mr, Color(0.02, 0.01, 0.03, 0.95))
		if look == "owned":
			draw_circle(mc, mr, Color(1.0, 0.5, 0.2, 0.12))
		draw_arc(mc, mr, 0, TAU, 40, Color(icon_col, 0.75), 1.5, true)
		Icons.draw(self, glyph, mc, mr * 0.55, icon_col)
		if look == "locked":
			_lock(mc + Vector2(mr * 0.7, mr * 0.7))
		var tx := mc.x + mr + 14
		var tw := r.end.x - tx - 10
		var ty := r.position.y + 30
		if small:
			var tl := f.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, 2).y
			draw_multiline_string(f, Vector2(tx, ty - 6), title, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, 2, title_col)
			ty += maxf(0.0, tl - 22.0) - 6.0
		else:
			draw_string(f, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, tw, 17 if kind != "head" else 16, title_col)
		if line != "":
			var lines := clampi(int((r.size.y - 52.0) / 18.0), 1, 3)
			draw_multiline_string(ThemeDB.fallback_font, Vector2(tx, ty + 22), line, HORIZONTAL_ALIGNMENT_LEFT, tw, 14, lines, Color(QUIET, 0.95 if look != "locked" and look != "forsworn" and look != "lost" else 0.62))
		if pips.y > 0:
			for i in pips.y:
				var pc := Vector2(tx + 6 + i * 22, r.end.y - 17)
				var d := PackedVector2Array([pc + Vector2(0, -6), pc + Vector2(5, 0), pc + Vector2(0, 6), pc + Vector2(-5, 0)])
				if i < pips.x:
					draw_colored_polygon(d, EMBER)
					draw_circle(pc, 2.0, EMBER_HOT)
				else:
					d.append(d[0])
					draw_polyline(d, Color(QUIET, 0.6), 1.2, true)

	## A spell rank: the numeral large, the rank's name under it, a flame on the rank that
	## changes the spell, the cost or KINDLED in the corner.
	func _draw_compact(r: Rect2, f: Font, icon_col: Color, title_col: Color) -> void:
		var num_col := EMBER if look == "owned" else (INK if look == "open" else DIM)
		draw_string(f, r.position + Vector2(14, 36), ROMAN[sub], HORIZONTAL_ALIGNMENT_LEFT, 60, 28, num_col)
		draw_string(f, r.position + Vector2(14, 64), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 16, title_col)
		if sub == 3:
			Icons.draw(self, "will", r.position + Vector2(r.size.x - 22, 22), 9.0, Color(icon_col, 0.9))
		if look == "locked":
			_lock(r.position + Vector2(r.size.x - 22 - (24.0 if sub == 3 else 0.0), 22))

	func _lock(c: Vector2) -> void:
		draw_rect(Rect2(c + Vector2(-6, -2), Vector2(12, 9)), DIM)
		draw_arc(c + Vector2(0, -2), 4.5, PI, TAU, 10, DIM, 1.8)


class Glyph extends Control:
	var glyph := ""
	var tint := Color.WHITE
	var lit := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r, Color(0.02, 0.01, 0.03, 0.95))
		if lit:
			draw_circle(c, r, Color(1.0, 0.5, 0.2, 0.14))
		draw_arc(c, r, 0, TAU, 56, Color(tint, 0.8), 2.0, true)
		draw_arc(c, r - 6, 0, TAU, 56, Color(tint, 0.25), 1.0, true)
		Icons.draw(self, glyph, c, r * 0.55, tint)


# --- building -----------------------------------------------------------------------------------

func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("growth")
	if not InputMap.has_action("kindling"):
		InputMap.add_action("kindling")
		var k := InputEventKey.new()
		k.physical_keycode = KEY_K
		InputMap.action_add_event("kindling", k)
	_title_font = load("res://ui/fonts/Cinzel.ttf")
	var sf: Font = preload("res://ui/type.gd").body()
	_body_font = sf
	_build()
	_root.visible = false
	_chime = AudioStreamPlayer.new()
	_chime.stream = load("res://art/audio/ward_chime.wav")
	_chime.volume_db = -6.0
	if AudioServer.get_bus_index(&"SFX") >= 0:
		_chime.bus = &"SFX"
	add_child(_chime)


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
	# the fire's light from below
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.42, 0.14, 0.3))
	g.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.25)
	gt.width = 256
	gt.height = 128
	glow.texture = gt
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(glow)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.5, 0.4, 0.8, 0.6)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(1.0, 0.45, 0.15, 0.12)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	# header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	col.add_child(head)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 0)
	tbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tbox)
	tbox.add_child(_label("KINDLING", 34, INK))
	var sub := _label("Ash to ember, ember to flame.", 17, QUIET, _body_font)
	tbox.add_child(sub)
	var abox := VBoxContainer.new()
	abox.alignment = BoxContainer.ALIGNMENT_END
	abox.add_theme_constant_override("separation", 0)
	head.add_child(abox)
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_END
	arow.add_theme_constant_override("separation", 10)
	abox.add_child(arow)
	var mound := Glyph.new()
	mound.glyph = "mound"
	mound.tint = Color(0.78, 0.72, 0.82)
	mound.custom_minimum_size = Vector2(46, 46)
	arow.add_child(mound)
	_ash_label = _label("0", 34, EMBER_HOT)
	arow.add_child(_ash_label)
	var al := _label("GRAVE ASH", 14, QUIET)
	al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arow.add_child(al)
	_fire_label = _label("", 15, QUIET)
	_fire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	abox.add_child(_fire_label)
	# tabs
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	col.add_child(bar)
	for i in TABS.size():
		var b := Button.new()
		b.text = String(TABS[i][1]).to_upper()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(122, 36)
		b.add_theme_font_override("font", _title_font)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", DIM)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", LILAC)
		b.add_theme_color_override("font_hover_pressed_color", LILAC)
		var off := StyleBoxFlat.new()
		off.bg_color = Color(0.08, 0.05, 0.12, 0.7)
		off.set_corner_radius_all(3)
		var on := StyleBoxFlat.new()
		on.bg_color = Color(0.2, 0.14, 0.36, 0.9)
		on.border_color = LILAC
		on.border_width_bottom = 2
		on.set_corner_radius_all(3)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", off)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		var idx := i
		b.pressed.connect(func() -> void:
			show_tab(idx)
			UiSound.play(self, "tab"))
		bar.add_child(b)
		_tab_btns.append(b)
	var rule := ColorRect.new()
	rule.color = Color(EDGE, 0.8)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	# body: page on the left, detail on the right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	col.add_child(body)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(800, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_page_box = VBoxContainer.new()
	_page_box.add_theme_constant_override("separation", 10)
	_page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_page_box)
	var vr := ColorRect.new()
	vr.color = Color(EDGE, 0.5)
	vr.custom_minimum_size = Vector2(1, 0)
	body.add_child(vr)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(420, 0)
	info.add_theme_constant_override("separation", 10)
	body.add_child(info)
	var irow := HBoxContainer.new()
	irow.add_theme_constant_override("separation", 16)
	info.add_child(irow)
	_d_icon = Glyph.new()
	_d_icon.custom_minimum_size = Vector2(92, 92)
	irow.add_child(_d_icon)
	var nbox := VBoxContainer.new()
	nbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	irow.add_child(nbox)
	_d_name = _label("", 24, INK)
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_name.custom_minimum_size = Vector2(300, 0)
	nbox.add_child(_d_name)
	_d_kind = _label("", 13, QUIET)
	nbox.add_child(_d_kind)
	var rule2 := ColorRect.new()
	rule2.color = Color(EDGE, 0.8)
	rule2.custom_minimum_size = Vector2(0, 1)
	info.add_child(rule2)
	_d_text = _wrap(17, Color(0.86, 0.82, 0.92))
	info.add_child(_d_text)
	_d_now = _wrap(15, EMBER)
	info.add_child(_d_now)
	_d_lore = _wrap(16, Color(0.62, 0.58, 0.68), _body_font)
	info.add_child(_d_lore)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)
	_d_why = _wrap(15, WARN)
	info.add_child(_d_why)
	_d_btn = Button.new()
	_d_btn.custom_minimum_size = Vector2(0, 50)
	_d_btn.focus_mode = Control.FOCUS_NONE
	_d_btn.add_theme_font_override("font", _title_font)
	_d_btn.add_theme_font_size_override("font_size", 18)
	_d_btn.add_theme_color_override("font_color", EMBER_HOT)
	_d_btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.85))
	_d_btn.add_theme_color_override("font_disabled_color", DIM)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.3, 0.12, 0.06, 0.9)
	bn.border_color = Color(1.0, 0.6, 0.3, 0.8)
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(4)
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.45, 0.18, 0.07, 0.95)
	bh.border_color = EMBER_HOT
	var bd := bn.duplicate() as StyleBoxFlat
	bd.bg_color = Color(0.08, 0.05, 0.1, 0.8)
	bd.border_color = Color(EDGE, 0.6)
	_d_btn.add_theme_stylebox_override("normal", bn)
	_d_btn.add_theme_stylebox_override("hover", bh)
	_d_btn.add_theme_stylebox_override("pressed", bh)
	_d_btn.add_theme_stylebox_override("disabled", bd)
	_d_btn.pressed.connect(act)
	info.add_child(_d_btn)
	# footer
	var rule3 := ColorRect.new()
	rule3.color = Color(EDGE, 0.5)
	rule3.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule3)
	var foot := _label("[W A S D] choose      [Space] or click: kindle      [Q] [E] page      [K] or [Esc] leave", 14, DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)
	# particles live above everything, in screen space
	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fx_layer)


func _label(t: String, size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	var font := f if f else _title_font
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func _wrap(size: int, c: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


# --- open / close -------------------------------------------------------------------------------

func is_open() -> bool:
	return _root.visible


func _k() -> Node:
	return get_tree().get_first_node_in_group("progression")


## Open the Kindling (`tab` = "embers" | "spells" | "oaths" | "relics" | "charms" | "staff" |
## "loadout", "" keeps the last).
func open_menu(_from_fire := false, tab := "") -> void:
	if _root.visible:
		return
	var k := _k()
	_fire = k.call("at_fire") if k else null
	for i in TABS.size():
		if TABS[i][0] == tab:
			_tab = i
	_ash_shown = float(Travel.count("grave_ash"))
	_root.visible = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	show_tab(_tab)
	UiSound.play(self, "tab")


func close_menu() -> void:
	if not _root.visible:
		return
	_root.visible = false
	UiSound.play(self, "back")
	_confirm = ""
	if get_tree().paused:
		get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var k := _k()
	if k:
		k.call("celebrate")


func at_fire() -> bool:
	return _fire != null and is_instance_valid(_fire)


func _process(delta: float) -> void:
	if not _root.visible:
		return
	if not get_tree().paused:
		close_menu()                       # someone else unpaused the world (a test, a cutscene)
		return
	var ash := float(Travel.count("grave_ash"))
	if absf(_ash_shown - ash) > 0.01:
		_ash_shown = move_toward(_ash_shown, ash, maxf(1.0, absf(_ash_shown - ash)) * delta * 6.0)
	_ash_label.text = str(roundi(_ash_shown))
	for c in _cards:
		if c.flash > 0.0:
			c.flash = maxf(0.0, c.flash - delta * 1.6)
			c.queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("kindling") and not event.is_echo():
		if _root.visible:
			close_menu()
		elif not get_tree().paused:
			open_menu()
		get_viewport().set_input_as_handled()
		return
	if not _root.visible:
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("inventory"):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		step = 1
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		step = _cols
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		step = -_cols
	elif event.is_action_pressed("skill_nova") or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER):
		show_tab((_tab + TABS.size() - 1) % TABS.size())
		UiSound.play(self, "tab")
	elif event.is_action_pressed("interact") or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER):
		show_tab((_tab + 1) % TABS.size())
		UiSound.play(self, "tab")
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		act()
	else:
		return
	if step != 0 and not _cards.is_empty():
		var was := _sel
		_sel = clampi(_sel + step, 0, _cards.size() - 1)
		if _sel != was:
			UiSound.play(self, "move")
		_confirm = ""
		_show()
	get_viewport().set_input_as_handled()


# --- pages --------------------------------------------------------------------------------------

func show_tab(i: int) -> void:
	_tab = i
	_confirm = ""
	for j in _tab_btns.size():
		_tab_btns[j].button_pressed = j == i
	_rebuild()
	_sel = 0
	for j in _cards.size():
		if _cards[j].look == "open":
			_sel = j
			break
	_show()


func _rebuild() -> void:
	var keep_sel := _sel
	for c in _page_box.get_children():
		_page_box.remove_child(c)
		c.queue_free()
	_cards.clear()
	_fire_label.text = ("At the fire. Ash may be spent here." if at_fire() else "Away from a fire: plan here, spend at a kindled brazier.")
	_fire_label.add_theme_color_override("font_color", EMBER if at_fire() else QUIET)
	match String(TABS[_tab][0]):
		"embers":
			_page_embers()
		"spells":
			_page_spells()
		"oaths":
			_page_oaths()
		"relics":
			_page_relics()
		"charms":
			_page_charms()
		"staff":
			_page_staff()
		"loadout":
			_page_loadout()
		"paths":
			_page_paths()
		"hearth":
			_page_hearth()
	_sel = clampi(keep_sel, 0, maxi(_cards.size() - 1, 0))


func _heading(t: String, note := "") -> void:
	var h := HBoxContainer.new()
	var l := _label(t.to_upper(), 14, QUIET)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if note != "":
		h.add_child(_label(note, 13, DIM))
	_page_box.add_child(h)


func _card(kind: String, id: String, w: float, h: float) -> Card:
	var c := Card.new()
	c.menu = self
	c.kind = kind
	c.id = id
	c.font = _title_font
	c.custom_minimum_size = Vector2(w, h)
	if kind != "head":
		_cards.append(c)
	return c


func _look_for(why: String, owned: bool) -> String:
	if owned:
		return "owned"
	if why == "" or why == "Only at a kindled fire.":
		return "open"
	if why.begins_with("Needs ") and why.contains("grave ash"):
		return "poor"
	return "locked"


func _st() -> Dictionary:
	return Travel.system_state("progression")


func _page_embers() -> void:
	_heading("The fire's warmth", "lasting, for every spell and step")
	_cols = 2
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_page_box.add_child(grid)
	var k := _k()
	for e: Dictionary in DB.EMBERS:
		var id := String(e.id)
		var c := _card("ember", id, 384, 118)
		var r := DB.rank(_st(), id)
		var nx := DB.next_of(_st(), id)
		c.glyph = String(e.glyph)
		c.tint = EMBER
		c.title = String(e.name)
		c.line = String(e.per)
		c.pips = Vector2i(r, int(e.max))
		c.cost = int(nx.get("cost", 0))
		c.look = _look_for(String(k.call("why_not", id, true)) if k else "", nx.is_empty())
		if nx.is_empty():
			c.look = "owned"
		grid.add_child(c)


func _page_spells() -> void:
	_heading("Ranks of the spells", "each rank changes how it plays; III changes it most")
	_cols = 4
	var k := _k()
	for sp: Dictionary in DB.SPELLS:
		var id := String(sp.id)
		var r := DB.rank(_st(), id)
		var learnable := sp.has("learn")
		var known := DB.knows(_st(), id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_page_box.add_child(row)
		var head := _card("learn" if learnable and not known else "spell", id, 216, 92)
		head.small = true
		head.glyph = String(sp.glyph)
		head.tint = sp.color
		head.title = String(sp.name)
		if learnable and not known:
			var lw := String(k.call("why_not_learn", id, true)) if k else ""
			head.line = "Not yet learned"
			head.cost = int((sp.learn as Dictionary).cost)
			head.look = _look_for(lw, false)
		else:
			head.line = "Rank %s" % (ROMAN[r] if r > 0 else "-")
		row.add_child(head)
		for i in 3:
			var c := _card("rank", id, 184, 92)
			c.compact = true
			c.sub = i + 1
			c.glyph = String(sp.glyph)
			c.tint = (sp.color as Color).lerp(EMBER, 0.25 * float(i))
			c.title = String(sp.ranks[i][0])
			c.line = ""
			c.cost = int(DB.SPELL_COST[i])
			if r > i:
				c.look = "owned"
			elif r == i and (known or not learnable):
				c.look = _look_for(String(k.call("why_not", id, true)) if k else "", false)
			else:
				c.look = "locked"
			row.add_child(c)


## STAFF: the core in the orb. The Hollow Core is always yours; two are forged, two are found.
func _page_staff() -> void:
	var cur := DB.core_of(_st())
	_heading("The staff's core", "one sits in the orb and changes every Rift Bolt; set at a fire")
	_cols = 2
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_page_box.add_child(grid)
	var k := _k()
	for c: Dictionary in DB.CORES:
		var id := String(c.id)
		var have := id == "" or Travel.count(id) > 0
		var card := _card("core", id, 384, 124)
		card.glyph = String(c.glyph)
		card.tint = c.tint
		card.title = String(c.name) if have or c.has("forge") else "A lost core"
		card.line = String(c.text) if have or c.has("forge") else "Somewhere in %s." % String(DB.CORE_SPOTS.get(id, {}).get("where", "the valley"))
		if id == cur:
			card.look = "owned"
		elif have:
			card.look = "open"
		elif c.has("forge"):
			card.cost = int((c.forge as Dictionary).ash)
			card.look = _look_for(String(k.call("why_not_forge", id, true)) if k else "", false)
			if card.look == "locked" and Travel.count("relic_fragment") < int((c.forge as Dictionary).frag):
				card.look = "poor"
		else:
			card.look = "lost"
		grid.add_child(card)
	_heading("Relic fragments", "%d carried: the valley's hidden places hold them" % Travel.count("relic_fragment"))


## LOADOUT: the four hotbar slots beside Rift Bolt, the known spells, and the combos.
func _page_loadout() -> void:
	var st := _st()
	var lo := DB.loadout(st)
	_heading("The hotbar", "pick a slot, then a spell below (or press a slot to cycle)")
	_cols = 4
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_page_box.add_child(row)
	for i in 4:
		var sp := DB.spell(String(lo[i]))
		var c := _card("slot", String(lo[i]), 188, 110)
		c.small = true
		c.sub = i + 1
		c.glyph = String(sp.glyph)
		c.tint = sp.color
		c.title = String(sp.name)
		c.line = "[%s]" % DB.SLOT_KEYS[i + 1]
		c.look = "owned" if i + 1 == _slot_pick else "open"
		row.add_child(c)
	_heading("Known spells", "Rift Bolt always holds [LMB]")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_page_box.add_child(grid)
	for sp: Dictionary in DB.SPELLS:
		var id := String(sp.id)
		if id == "bolt":
			continue
		var known := DB.knows(st, id)
		var c := _card("pick", id, 188, 92)
		c.small = true
		c.glyph = String(sp.glyph)
		c.tint = sp.color
		c.title = String(sp.name)
		var at := lo.find(id)
		c.line = ("On [%s]" % DB.SLOT_KEYS[at + 1]) if at >= 0 else ("Rank %s" % ROMAN[DB.rank(st, id)] if DB.rank(st, id) > 0 else ("Known" if known else "Learn it under Spells"))
		c.look = "owned" if at >= 0 else ("open" if known else "lost")
		grid.add_child(c)
	_heading("Combos", "spells that feed each other")
	for cb: Array in COMBOS:
		var h := _card("head", String(cb[0]), 784, 66)
		h.glyph = "will"
		h.tint = Color(0.9, 0.6, 1.0)
		h.title = "%s%s" % [cb[0], ("   x%d" % int(Combo.count[cb[0]])) if Combo.count.has(cb[0]) else ""]
		h.line = String(cb[1])
		var have := true
		for need: String in cb[2]:
			if need.begins_with("core_"):
				have = have and Travel.count(need) > 0
			else:
				have = have and lo.has(need)
		h.look = "open" if have else "locked"
		_page_box.add_child(h)


func _page_oaths() -> void:
	_heading("Oaths", "one of two in each tier")
	_cols = 2
	var k := _k()
	for o: Dictionary in DB.OATHS:
		var tier := int(o.tier)
		var sworn := DB.oath(_st(), tier)
		var why := String(k.call("why_not_oath", tier, true)) if k else ""
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_page_box.add_child(row)
		var tl := _label(ROMAN[tier], 30, EMBER if sworn != "" else QUIET)
		tl.custom_minimum_size = Vector2(54, 0)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(tl)
		for side: String in ["a", "b"]:
			if side == "b":
				var orl := _label("or", 15, DIM, _body_font)
				orl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				row.add_child(orl)
			var od: Dictionary = o[side]
			var c := _card("oath", String(od.id), 336, 132)
			c.sub = tier
			c.pick = side
			c.glyph = String(od.glyph)
			c.tint = Color(0.78, 0.64, 1.0) if side == "a" else Color(1.0, 0.62, 0.42)
			c.title = String(od.name)
			c.line = String(od.text)
			c.cost = int(o.cost)
			if sworn == side:
				c.look = "owned"
			elif sworn != "":
				c.look = "forsworn"
			else:
				c.look = _look_for(why, false)
			row.add_child(c)


func _page_relics() -> void:
	_heading("Relics and their rites", "attune at a fire; each unlocks a rite")
	_cols = 2
	var k := _k()
	for item: String in RELIC_ROWS:
		var d := ItemDB.def(item)
		var have := Travel.count(item) > 0
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_page_box.add_child(row)
		var c := _card("relic", item, 384, 124)
		c.glyph = String(d.shape)
		c.tint = d.tint
		c.title = String(d.name) if have else "Unclaimed"
		var rid := String(d.get("relic", ""))
		if have and rid != "" and Travel.relics.has(rid):
			c.line = "Attuned: %s" % String(Travel.relics[rid]).capitalize()
			c.look = "open"
		elif have:
			c.line = "A seal shard. Its rite is beside it."
			c.look = "owned"
		else:
			c.line = "From %s." % RELIC_FROM.get(item, "?")
			c.look = "lost"
		row.add_child(c)
		var rite: Dictionary = {}
		for r: Dictionary in DB.RITES:
			if String(r.needs) == item:
				rite = r
		if rite.is_empty():
			continue
		var rc := _card("rite", String(rite.id), 384, 124)
		rc.glyph = String(rite.glyph)
		rc.tint = (d.tint as Color).lerp(EMBER, 0.3)
		rc.title = String(rite.name)
		rc.line = String(rite.text)
		rc.cost = int(rite.cost)
		var owned := DB.rank(_st(), String(rite.id)) > 0
		rc.look = _look_for(String(k.call("why_not", String(rite.id), true)) if k else "", owned)
		row.add_child(rc)


func _page_charms() -> void:
	var w := DB.worn(_st())
	_heading("Charms", "cords worn: %d of %d" % [w.size(), DB.slots(_st())])
	_cols = 2
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_page_box.add_child(grid)
	for id: String in DB.CHARM_SPOTS.keys() + DB.ELITE_CHARMS.keys() + DB.QUEST_CHARMS.keys():
		var d := ItemDB.def(id)
		var have := Travel.count(id) > 0
		var c := _card("charm", id, 384, 104)
		c.glyph = String(d.shape)
		c.tint = d.tint
		if have:
			c.title = String(d.name)
			c.line = String(d.text).split("Worn: ")[-1]          # the effect, not the bounty's line
			c.look = "owned" if w.has(id) else "open"
		else:
			c.title = "Lost" if DB.CHARM_SPOTS.has(id) else ("Not yet earned" if DB.QUEST_CHARMS.has(id) else "Unclaimed bounty")
			c.line = ("Somewhere in %s." % DB.CHARM_SPOTS[id].where) if DB.CHARM_SPOTS.has(id) else ("%s." % String(DB.QUEST_CHARMS[id]) if DB.QUEST_CHARMS.has(id) else "%s." % DB.ELITE_CHARMS[id].trim_prefix("Bounty: "))
			c.look = "lost"
		grid.add_child(c)


# --- the Paths and the Hearthfire (paths_db.gd, hearth_db.gd, hearth.gd) --------------------------

func _h() -> Node:
	return get_tree().get_first_node_in_group("hearth")


func at_home_fire() -> bool:
	return at_fire() and HearthRT.is_home_fire(_fire)


## PATHS: three columns, one per Path, read top to bottom; a step needs the one above it.
func _page_paths() -> void:
	var st := _st()
	var h := _h()
	var lv := PathsDB.level_of(int(st.get("memory", 0)))
	var free := PathsDB.free_pts(st, Travel.bosses_slain.size())
	# r33 progression: the level reads as a level, with rested XP (level.gd)
	var rested := int(st.get("rested_xp", 0))
	_heading("Level %d (Remembrance)  ·  %d point%s to spend" % [int(lv.level), maxi(free, 0), "" if free == 1 else "s"],
		"XP %d / %d to the next%s  ·  kills, tasks, fires, seals and new places bring it back" % [int(lv.into), int(lv.need),
			("  ·  rested: +%d (kills give double)" % rested) if rested > 0 else ""])
	_cols = 3
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_page_box.add_child(grid)
	for pa: Dictionary in PathsDB.PATHS:
		var hd := _card("head", String(pa.id), 258, 70)
		hd.glyph = String(pa.glyph)
		hd.tint = pa.tint
		hd.title = String(pa.name).to_upper()
		hd.line = "%d of %d remembered" % [_taken_on(String(pa.id)), PathsDB.on_path(String(pa.id)).size()]
		hd.look = "open"
		grid.add_child(hd)
	var cols: Array = []
	for pa: Dictionary in PathsDB.PATHS:
		cols.append(PathsDB.on_path(String(pa.id)))
	for d in 8:
		for ci in cols.size():
			var list: Array = cols[ci]
			if d >= list.size():
				grid.add_child(Control.new())
				continue
			var n: Dictionary = list[d]
			var c := _card("path", String(n.id), 258, 100)
			c.small = true
			c.glyph = String(n.glyph)
			c.tint = (PathsDB.PATHS[ci].tint as Color)
			c.title = String(n.name)
			c.line = String(n.text)
			c.cost = int(n.cost)
			c.unit = "PT" if int(n.cost) == 1 else "PTS"
			var why := String(h.call("why_not_path", String(n.id))) if h else "?"
			if PathsDB.has(st, String(n.id)):
				c.look = "owned"
			elif why == "":
				c.look = "open"
			elif why.begins_with("Needs "):
				c.look = "poor"
			else:
				c.look = "locked"
			grid.add_child(c)
	_heading("Unremember", "give every step back at Hearthward's fire, for ash")
	var u := _card("unremember", "", 784, 70)
	u.glyph = "hollow"
	u.tint = QUIET
	u.title = "Unremember"
	u.line = "Every Path step comes back to be spent again. The ash does not (%d a step)." % HearthDB.UNREMEMBER_PER
	u.cost = int(h.call("unremember_cost")) if h else 0
	u.look = _look_for(String(h.call("why_not_unremember", at_home_fire())) if h else "?", false)
	_page_box.add_child(u)


func _taken_on(path_id: String) -> int:
	var n := 0
	for nd: Dictionary in PathsDB.on_path(path_id):
		if PathsDB.has(_st(), String(nd.id)):
			n += 1
	return n


## HEARTH: the Hearthfire's tier, the trades it opens, comfort, Rested and meals, the bells.
func _page_hearth() -> void:
	var h := _h()
	if h == null:
		_heading("The Hearthfire", "no fire here")
		return
	var hs: Dictionary = h.call("hs")
	var t := HearthDB.tier(hs)
	_heading("The Hearthfire  ·  %s" % String(HearthDB.TIERS[t].name), "Hearthward's own fire, on the green")
	_cols = 2
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_page_box.add_child(row)
	var now := _card("head", "now", 384, 124)
	now.glyph = "hearth"
	now.tint = EMBER
	now.title = "%s  ·  %s" % [["BANKED", "I", "II", "III", "IV"][t], String(HearthDB.TIERS[t].name)]
	now.line = "Fires reach +%.1f m  ·  +%d Gloom held  ·  comfort %d" % [HearthDB.reach(hs, float(DB.live.get("reach_add", 0.0))), int(HearthDB.TIERS[t].gloom), int(h.call("comfort"))]
	now.look = "owned"
	row.add_child(now)
	var up := _card("hearth", "raise", 384, 124)
	up.glyph = "hearth"
	up.tint = EMBER_HOT
	if t >= HearthDB.TIERS.size() - 1:
		up.title = "Burning as high as it will"
		up.line = String(HearthDB.TIERS[t].text)
		up.look = "owned"
	else:
		var nx: Dictionary = HearthDB.TIERS[t + 1]
		up.title = "Raise it: %s" % String(nx.name)
		up.line = "Needs %s%s." % [String(nx.need_text), (", %d relic fragment%s" % [int(nx.frag), "" if int(nx.frag) == 1 else "s"]) if int(nx.frag) > 0 else ""]
		up.cost = int(nx.ash)
		up.look = _look_for(String(h.call("why_not_raise", at_home_fire())).replace("Only at Hearthward's fire, on the green.", "Only at a kindled fire."), false)
	row.add_child(up)
	_heading("Hearthward's trades", "they open as the fire grows")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_page_box.add_child(grid)
	for id: String in ["smith", "herbs", "bells", "beacon"]:
		var sv: Dictionary = HearthDB.SERVICES[id]
		var c := _card("service", id, 384, 112)
		c.glyph = String(sv.glyph)
		c.tint = Color(1.0, 0.78, 0.5)
		c.title = String(sv.name)
		var why := String(h.call("service_why", id))
		c.line = String(sv.text) if why == "" else why
		if id == "bells" and why == "" and not HearthDB.works(hs).has("bells"):
			c.cost = HearthRT.BELLS_PRICE
			c.look = _look_for(String(h.call("why_not_bells")), false)
		else:
			c.look = "owned" if why == "" else "locked"
		grid.add_child(c)
	_heading("Rest and food", "Rested: come home from the dark to the green's fire or the Keg")
	var r := float(hs.get("rested", 0.0))
	var rc := _card("head", "rested", 784, 66)
	rc.glyph = "candle"
	rc.tint = Color(1.0, 0.85, 0.6)
	rc.title = ("RESTED  ·  %s left" % HearthDB.fmt_secs(r)) if r > 0.0 else "NOT RESTED"
	rc.line = "Comfort %d: a full rest lasts %s. Gloom gathers 12%% slower and spells recover 4%% sooner while it lasts." % [int(h.call("comfort")), HearthDB.fmt_secs(float(h.call("rest_full")))]
	rc.look = "owned" if r > 0.0 else "locked"
	_page_box.add_child(rc)
	var meals := HearthDB.meals(hs)
	var mc := _card("head", "meals", 784, 66)
	mc.glyph = "heart"
	mc.tint = Color(1.0, 0.7, 0.5)
	var eaten: Array[String] = []
	for kind: String in meals:
		var e: Dictionary = meals[kind]
		eaten.append("%s (%s)" % [String(HearthDB.meal(String(e.id)).get("name", "?")), HearthDB.fmt_secs(float(e.left))])
	mc.title = "MEALS  ·  %d OF %d" % [meals.size(), int(h.call("belly"))]
	mc.line = ", ".join(eaten) if not eaten.is_empty() else "Nothing eaten. The Keg's slate has bread, stew and mulled ale; Bet Reed's garden, better."
	mc.look = "owned" if not eaten.is_empty() else "locked"
	_page_box.add_child(mc)
	_walks.clear()
	if HearthDB.works(hs).has("bells") and at_fire():
		_heading("Brannoc's bells", "ring here and walk to another kindled fire")
		var wg := GridContainer.new()
		wg.columns = 2
		wg.add_theme_constant_override("h_separation", 12)
		wg.add_theme_constant_override("v_separation", 12)
		_page_box.add_child(wg)
		for b: Node3D in h.call("walk_targets", _fire):
			var wc := _card("walk", str(_walks.size()), 384, 80)
			_walks.append(b)
			wc.glyph = "bell"
			wc.tint = Color(0.95, 0.75, 0.45)
			wc.title = HearthRT.fire_name(b)
			wc.line = "%.0f m away" % b.global_position.distance_to(_fire.global_position)
			wc.look = "open"
			wg.add_child(wc)


# --- selection and detail -----------------------------------------------------------------------

func hover_card(c: Card) -> void:
	var i := _cards.find(c)
	if i >= 0 and i != _sel:
		_sel = i
		_confirm = ""
		_show()


func click_card(c: Card) -> void:
	var i := _cards.find(c)
	if i < 0:
		return
	if i == _sel:
		act()
	else:
		_sel = i
		_confirm = ""
		_show()


func _show() -> void:
	for i in _cards.size():
		_cards[i].selected = i == _sel
		_cards[i].queue_redraw()
	if _cards.is_empty():
		return
	var c := _cards[_sel]
	var k := _k()
	var st := _st()
	_d_icon.glyph = c.glyph
	_d_icon.tint = c.tint
	_d_icon.lit = c.look == "owned"
	_d_icon.queue_redraw()
	_d_lore.text = ""
	_d_now.text = ""
	var why := ""
	var verb := ""
	match c.kind:
		"ember":
			var e := DB.ember(c.id)
			var r := DB.rank(st, c.id)
			_d_name.text = String(e.name)
			_d_kind.text = "EMBER  ·  RANK %d OF %d" % [r, int(e.max)]
			_d_text.text = "Each rank: %s" % e.per
			_d_now.text = "Now: %s%s" % [_ember_value(c.id, r), ("" if r >= int(e.max) else "      Next: %s" % _ember_value(c.id, r + 1))]
			_d_lore.text = String(e.lore)
			why = String(k.call("why_not", c.id, at_fire()))
			verb = "KINDLE  ·  %d ASH" % c.cost
		"rank":
			var s := DB.spell(c.id)
			var r := DB.rank(st, c.id)
			var rk: Array = s.ranks[c.sub - 1]
			_d_name.text = "%s · %s" % [s.name, rk[0]]
			_d_kind.text = "SPELL  ·  RANK %s%s" % [ROMAN[c.sub], "  ·  CHANGES THE SPELL" if c.sub == 3 else ""]
			_d_text.text = String(rk[1])
			var parts: Array[String] = []
			for i in r:
				parts.append("%s %s" % [ROMAN[i + 1], s.ranks[i][0]])
			_d_now.text = ("Kindled: " + ", ".join(parts)) if r > 0 else "Nothing kindled in %s yet." % s.name
			_d_now.text += "\nNow: %s\nWith %s: %s" % [_stats(c.id, r), ROMAN[c.sub], _stats(c.id, maxi(r, c.sub))]
			if DB.learnable(c.id) and not DB.knows(st, c.id):
				why = "Learn %s first." % s.name
			elif r >= c.sub:
				why = "Kindled."
			elif r < c.sub - 1:
				why = "Kindle rank %s first." % ROMAN[c.sub - 1]
			else:
				why = String(k.call("why_not", c.id, at_fire()))
			verb = "KINDLE  ·  %d ASH" % c.cost
		"spell", "learn":
			var sp := DB.spell(c.id)
			var r := DB.rank(st, c.id)
			var known := DB.knows(st, c.id)
			_d_name.text = String(sp.name)
			_d_kind.text = ("SPELL  ·  RANK %s" % (ROMAN[r] if r > 0 else "-")) if known else "SPELL  ·  NOT YET LEARNED"
			_d_text.text = String(sp.get("text", _stock_text(c.id)))
			_d_now.text = "Now: %s" % _stats(c.id, r) if known else "Learned: %s" % _stats(c.id, 0)
			_d_lore.text = String(sp.get("lore", ""))
			if not known:
				why = String(k.call("why_not_learn", c.id, at_fire()))
				verb = "LEARN  ·  %d ASH" % int((sp.learn as Dictionary).cost)
			elif r < 3:
				why = String(k.call("why_not", c.id, at_fire()))
				verb = "KINDLE %s  ·  %d ASH" % [ROMAN[r + 1], int(DB.SPELL_COST[r])]
			else:
				why = "Every rank kindled."
		"core":
			var co := DB.core(c.id)
			var have := c.id == "" or Travel.count(c.id) > 0
			_d_name.text = String(co.name) if have or co.has("forge") else "A lost core"
			_d_kind.text = "STAFF CORE  ·  %s" % ("IN THE ORB" if DB.core_of(st) == c.id else ("YOURS" if have else ("FORGED AT A FIRE" if co.has("forge") else "FOUND IN THE VALLEY")))
			_d_text.text = String(co.text)
			_d_lore.text = String(co.lore)
			if co.has("forge") and not have:
				_d_now.text = "Forging takes %d relic fragments (you carry %d) and %d grave ash." % [int(co.forge.frag), Travel.count("relic_fragment"), int(co.forge.ash)]
				why = String(k.call("why_not_forge", c.id, at_fire()))
				verb = "FORGE  ·  %d FRAGMENTS, %d ASH" % [int(co.forge.frag), int(co.forge.ash)]
			elif not have:
				_d_now.text = "It lies in %s." % String(DB.CORE_SPOTS.get(c.id, {}).get("where", "the valley"))
				why = "Not found yet."
			elif DB.core_of(st) == c.id:
				why = "In the orb."
			else:
				why = "" if at_fire() else "Only at a kindled fire."
				verb = "SET IN THE ORB"
		"slot":
			var sp := DB.spell(c.id)
			_slot_pick = c.sub
			_d_name.text = "[%s]  %s" % [DB.SLOT_KEYS[c.sub], sp.name]
			_d_kind.text = "HOTBAR SLOT %d" % (c.sub + 1)
			_d_text.text = String(sp.get("text", _stock_text(c.id)))
			_d_now.text = "Now: %s" % _stats(c.id, DB.rank(st, c.id))
			_d_lore.text = "Choose a spell below to put it here, or press again to cycle what is known."
			why = "" if at_fire() else "Only at a kindled fire."
			verb = "NEXT SPELL"
		"pick":
			var sp := DB.spell(c.id)
			var lo := DB.loadout(st)
			_d_name.text = String(sp.name)
			_d_kind.text = "SPELL  ·  %s" % (("ON [%s]" % DB.SLOT_KEYS[lo.find(c.id) + 1]) if lo.has(c.id) else ("KNOWN" if DB.knows(st, c.id) else "NOT YET LEARNED"))
			_d_text.text = String(sp.get("text", _stock_text(c.id)))
			_d_now.text = "Now: %s" % _stats(c.id, DB.rank(st, c.id))
			if not DB.knows(st, c.id):
				why = "Learn it first (Spells)."
			elif lo.find(c.id) == _slot_pick - 1:
				why = "Already on [%s]." % DB.SLOT_KEYS[_slot_pick]
			else:
				why = "" if at_fire() else "Only at a kindled fire."
				verb = "PUT ON [%s]%s" % [DB.SLOT_KEYS[_slot_pick], ("  (TRADES WITH %s)" % String(DB.spell(String(lo[_slot_pick - 1])).name).to_upper()) if lo.has(c.id) else ""]
		"oath":
			var o := DB.oath_tier(c.sub)
			var od: Dictionary = o[c.pick]
			var sworn := DB.oath(st, c.sub)
			_d_name.text = String(od.name)
			_d_kind.text = "OATH  ·  TIER %s  ·  ONE OF TWO" % ROMAN[c.sub]
			_d_text.text = String(od.text)
			_d_lore.text = String(od.lore)
			var other: Dictionary = o["b" if c.pick == "a" else "a"]
			_d_now.text = "Swearing it forswears %s." % other.name if sworn == "" else ""
			if sworn == c.pick:
				if not at_fire():
					why = "Sworn. A vow is broken only at a fire."
				verb = "FORSWEAR?  THE ASH IS NOT RETURNED" if _confirm == c.id else "FORSWEAR"
			elif sworn != "":
				why = "Forsworn: you swore %s. Break that vow at a fire to choose again." % (o[sworn] as Dictionary).name
			else:
				why = String(k.call("why_not_oath", c.sub, at_fire()))
				verb = "SWEAR  ·  %d ASH" % c.cost
		"rite":
			var ri := DB.rite(c.id)
			_d_name.text = String(ri.name)
			_d_kind.text = "RITE OF THE %s" % String(ItemDB.def(String(ri.needs)).name).to_upper()
			_d_text.text = String(ri.text)
			_d_lore.text = String(ri.lore)
			why = "Kindled." if DB.rank(st, c.id) > 0 else String(k.call("why_not", c.id, at_fire()))
			verb = "KINDLE  ·  %d ASH" % c.cost
		"relic":
			var d := ItemDB.def(c.id)
			var rid := String(d.get("relic", ""))
			if Travel.count(c.id) <= 0:
				_d_name.text = "Unclaimed"
				_d_kind.text = "RELIC" if rid != "" else "TROPHY"
				_d_text.text = "Taken from %s." % RELIC_FROM.get(c.id, "?")
				why = "Not yet yours."
			else:
				_d_name.text = String(d.name)
				_d_lore.text = String(d.desc)
				if rid != "" and Travel.relics.has(rid):
					var cur: StringName = Travel.relics[rid]
					var opts: Array = Reliquary.VARIANTS.get(rid, [])
					var nxt: StringName = opts[(opts.find(cur) + 1) % opts.size()] if not opts.is_empty() else cur
					_d_kind.text = "RELIC  ·  ATTUNED: %s" % String(cur).to_upper()
					_d_text.text = String(Reliquary.TEXT.get(cur, ""))
					_d_now.text = "Attune to: %s" % String(Reliquary.TEXT.get(nxt, String(nxt)))
					why = "" if at_fire() else "Only at a kindled fire."
					verb = "ATTUNE TO %s" % String(nxt).to_upper()
				else:
					_d_kind.text = "TROPHY  ·  SEAL SHARD"
					_d_text.text = String(d.text)
					why = "Its rite is beside it."
		"charm":
			var d := ItemDB.def(c.id)
			var w := DB.worn(st)
			if Travel.count(c.id) <= 0:
				_d_name.text = "A lost charm" if DB.CHARM_SPOTS.has(c.id) else "An unclaimed bounty"
				_d_kind.text = "CHARM"
				_d_text.text = ("Somewhere in %s." % DB.CHARM_SPOTS[c.id].where) if DB.CHARM_SPOTS.has(c.id) else ("%s. Someone in Hearthward needs a hand first." % String(DB.QUEST_CHARMS[c.id]) if DB.QUEST_CHARMS.has(c.id) else "%s. The Kindled Keg's bounty board names it." % DB.ELITE_CHARMS[c.id])
				why = "Not found yet."
			else:
				_d_name.text = String(d.name)
				_d_kind.text = "CHARM  ·  %s  ·  CORDS %d OF %d" % ["WORN" if w.has(c.id) else "IN THE SATCHEL", w.size(), DB.slots(st)]
				_d_text.text = String(d.text)
				_d_lore.text = String(d.desc)
				verb = "TAKE IT OFF" if w.has(c.id) else "WEAR IT"
				if not w.has(c.id) and w.size() >= DB.slots(st):
					why = "Every cord is full. Take one off first."
		"path":
			var n := PathsDB.node(c.id)
			var pa := PathsDB.path(String(n.path))
			_d_name.text = String(n.name)
			_d_kind.text = "%s  ·  STEP %d  ·  %d REMEMBRANCE%s" % [String(pa.name).to_upper(), int(n.depth) + 1, int(n.cost), "" if int(n.cost) == 1 else "S"]
			_d_text.text = String(n.text)
			_d_lore.text = String(n.lore)
			_d_now.text = "%d Remembrance%s to spend." % [maxi(0, PathsDB.free_pts(st, Travel.bosses_slain.size())), "" if PathsDB.free_pts(st, Travel.bosses_slain.size()) == 1 else "s"]
			var hh := _h()
			why = String(hh.call("why_not_path", c.id)) if hh else "?"
			verb = "REMEMBER" if not PathsDB.has(st, c.id) else ""
		"unremember":
			var hh := _h()
			_d_name.text = "Unremember"
			_d_kind.text = "THE PATHS  ·  AT HEARTHWARD'S FIRE"
			_d_text.text = "Give every Path step back. The Remembrances return to be spent again; the ash is gone."
			_d_lore.text = "Some things you would rather carry differently. The fire on the green does not judge."
			why = String(hh.call("why_not_unremember", at_home_fire())) if hh else "?"
			verb = "UNREMEMBER  ·  %d ASH" % c.cost
		"hearth":
			var hh := _h()
			var t := int(hh.call("tier")) if hh else 0
			_d_name.text = "The Hearthfire"
			if t >= HearthDB.TIERS.size() - 1:
				_d_kind.text = "TIER IV  ·  BEACON"
				_d_text.text = String(HearthDB.TIERS[t].text)
				why = "It burns as high as it will."
			else:
				var nx: Dictionary = HearthDB.TIERS[t + 1]
				_d_kind.text = "RAISE TO %s  ·  %s" % [["", "I", "II", "III", "IV"][t + 1], String(nx.name).to_upper()]
				_d_text.text = String(nx.text)
				_d_now.text = "Kindled fires reach +%.1f m (now +%.1f); Gloom held +%d (now +%d). Needs %s." % [float(nx.reach), float(HearthDB.TIERS[t].reach), int(nx.gloom), int(HearthDB.TIERS[t].gloom), String(nx.need_text)]
				_d_lore.text = String(nx.lore)
				why = String(hh.call("why_not_raise", at_home_fire())) if hh else "?"
				verb = "FEED THE HEARTHFIRE  ·  %d ASH%s" % [int(nx.ash), (", %d FRAGMENT%s" % [int(nx.frag), "" if int(nx.frag) == 1 else "S"]) if int(nx.frag) > 0 else ""]
		"service":
			var hh := _h()
			var sv: Dictionary = HearthDB.SERVICES[c.id]
			_d_name.text = String(sv.name)
			_d_kind.text = "HEARTHWARD  ·  OPENS AT THE HEARTHFIRE %s" % ["", "I", "II", "III", "IV"][int(sv.tier)]
			_d_text.text = String(sv.text)
			var sw := String(hh.call("service_why", c.id)) if hh else "?"
			if c.id == "bells" and sw == "":
				if HearthDB.works(hh.call("hs")).has("bells"):
					why = "Hung. Ring them from this page at any kindled fire."
				else:
					_d_lore.text = "\"I cast forty for the Stair. I can cast four for the fires.\""
					why = String(hh.call("why_not_bells"))
					verb = "HANG THE BELLS  ·  %d ASH" % HearthRT.BELLS_PRICE
			elif sw == "" and String(sv.who) != "":
				why = "Open. Talk to %s in Hearthward." % ("Hild at the forge" if c.id == "smith" else "Bet Reed by her garden")
			else:
				why = sw
		"walk":
			var hh := _h()
			var i := int(c.id)
			var b: Node3D = _walks[i] if i < _walks.size() else null
			_d_name.text = HearthRT.fire_name(b)
			_d_kind.text = "BRANNOC'S BELLS  ·  WALK THERE"
			_d_text.text = "Ring the bell here; the one there answers, and you are standing by it. The fire there remembers you."
			why = String(hh.call("why_not_walk", _fire, b)) if hh else "?"
			verb = "RING AND WALK"
	_d_why.text = why if why != "Only at a kindled fire." or verb == "" else "Only at a kindled fire. You can plan here; spend where it burns."
	if _scroll and is_instance_valid(c):
		_scroll.ensure_control_visible(c)
	_d_btn.visible = verb != ""
	_d_btn.text = verb
	_d_btn.disabled = why != "" and not (c.kind == "oath" and DB.oath(st, c.sub) == c.pick and at_fire())


func _ember_value(id: String, r: int) -> String:
	match id:
		"warmth":
			return "%d Gloom" % (100 + 15 * r)
		"banked":
			return "%d%% drift" % (100 - 12 * r)
		"will":
			return "+%d%% damage" % (10 * r)
		"quick":
			return "-%d%% recovery" % (7 * r)
		"cord":
			return "%d cords" % (DB.BASE_SLOTS + r)
	return str(r)


## The stock spells' one-line description (learned spells carry their own "text").
func _stock_text(id: String) -> String:
	match id:
		"bolt":
			return "A fast bolt that Marks what it hits. Every 3rd bolt in a chain is a Rift Lash: a bigger burst and two Marks."
		"lance":
			return "Hold to charge, let go to throw. A full charge pierces every body on its line and bursts on the world."
		"nova":
			return "A ring blast round you: 1 damage, +1 for every Mark it detonates. Pops spit and unmakes shades."
		"ward":
			return "Plant a warm light: Gloom drains in it, shades come apart on its edge, foes slink from it."
		"step":
			return "Teleport a few strides; strikes pass through you for a moment, and the tear Marks what it crosses."
	return ""


## What a spell does in numbers at rank `r` (the Kindling's Now / With lines).
func _stats(id: String, r: int) -> String:
	var m := DB.live
	var pw := float(m.get("power", 1.0))
	var cd := float(m.get("cd", 1.0))
	match id:
		"bolt":
			var every := int(m.get("lash_every", 3))
			return "%.1f damage, %.1f m burst, %d m/s%s; every %s bolt a Lash (%.1f, %d Marks)%s" % [pw, 1.8 + (0.5 if r >= 1 else 0.0), int(34.0 * (1.2 if r >= 1 else 1.0)), ", seeking" if r >= 1 else "", "2nd" if every == 2 else "3rd", 2.0 * pw * float(m.get("lash_power", 1.0)), 3 if r >= 2 else 2, "; passes through bodies" if r >= 3 else ""]
		"lance":
			var ch := 0.9 * (0.75 if r >= 1 else 1.0) * float(m.get("lance_charge", 1.0))
			var bl := (1.0 if r >= 2 else 0.0) + float(m.get("lance_blast", 0.0))
			return "charges in %.2f s, %.1f to %.1f damage, %.1f to %.1f m burst%s%s%s" % [ch, (2.5 if r >= 2 else 2.0) * pw, 4.0 * pw, 3.0 + bl, 4.6 + bl, "; Perfect +30%" if r >= 1 else "", "; 3 cinders" if r >= 2 else "", "; Cinder Scar" if r >= 3 else ""]
		"nova":
			return "%.1f m ring, %.1f s recovery, %.1f per Mark%s%s%s" % [7.2 if r >= 1 else 6.0, (5.5 if r >= 2 else 7.0) * cd, (1.5 if bool(m.get("tally", false)) else 1.0) + float(m.get("mark_dmg", 0.0)), "; echo" if r >= 1 else "", "; motes 2 Gloom" if r >= 2 else "", "; Undertow" if r >= 3 else ""]
		"ward":
			return "burns %.0f s, %.0f s recovery%s%s%s" % [7.0 + (3.0 if r >= 1 else 0.0) + float(m.get("ward_life", 0.0)), (17.0 if r >= 2 else 24.0) * cd, "; pulses" if r >= 1 else "", "; spells +30% in its light" if r >= 2 else "", "; Mirror Flame" if r >= 3 else ""]
		"step":
			return "%.1f m, untouchable %.2f s, %.1f s recovery%s%s%s" % [7.5 + (2.0 if r >= 1 else 0.0) + float(m.get("step_range", 0.0)), 0.6 if r >= 2 else 0.35, 2.1 * cd * (0.5 if bool(m.get("door", false)) else 1.0), "; arrival shock" if r >= 1 else "", "; next bolt a Lash" if r >= 2 else "", "; Rend" if r >= 3 else ""]
		"tether":
			return "reaches %d m, %.1f s recovery, drags %d%s%s" % [24 if r >= 1 else 18, (6.0 - (2.0 if bool(m.get("hook", false)) else 0.0)) * cd, 2 if r >= 2 else 1, "; staggers" if r >= 1 else "", "; Reel" if r >= 3 else ""]
		"well":
			return "%.1f m for %.0f s, %.0f s recovery%s%s" % [5.5 if r >= 1 else 4.5, 4.0 if r >= 1 else 3.0, 11.0 * cd, "; eats spit" if r >= 2 else "", "; Event Horizon" if r >= 3 else ""]
		"familiar":
			return "%d shade%s for %.0f s, a dart every %.2f s (%.1f + a Mark), %.0f s recovery%s" % [2 if r >= 2 else 1, "s" if r >= 2 else "", 14.0 + (6.0 if bool(m.get("jar", false)) else 0.0), 0.75 if r >= 1 else 1.1, 0.5 * pw, 22.0 * cd, "; Last Breath" if r >= 3 else ""]
	return ""


# --- acting -------------------------------------------------------------------------------------

## The selected card's action: kindle, swear / forswear, attune, wear / take off.
func act() -> void:
	if _cards.is_empty() or not _root.visible:
		return
	var c := _cards[_sel]
	var k := _k()
	if k == null:
		return
	var res := "?"
	var bought := false
	match c.kind:
		"ember", "rite":
			res = String(k.call("buy", c.id, at_fire()))
			bought = res == ""
		"rank":
			if DB.rank(_st(), c.id) == c.sub - 1:
				res = String(k.call("buy", c.id, at_fire()))
				bought = res == ""
		"oath":
			var sworn := DB.oath(_st(), c.sub)
			if sworn == c.pick:
				if _confirm != c.id:
					_confirm = c.id
					_show()
					return
				res = String(k.call("forswear", c.sub, at_fire()))
			elif sworn == "":
				res = String(k.call("swear", c.sub, c.pick, at_fire()))
				bought = res == ""
		"relic":
			var rid := String(ItemDB.def(c.id).get("relic", ""))
			if rid != "" and Travel.relics.has(rid) and at_fire():
				Reliquary.attune(rid)
				res = ""
				bought = true
		"charm":
			res = String(k.call("toggle_charm", c.id))
		"learn":
			res = String(k.call("learn", c.id, at_fire()))
			bought = res == ""
		"spell":
			res = String(k.call("buy", c.id, at_fire()))
			bought = res == ""
		"core":
			var have := c.id == "" or Travel.count(c.id) > 0
			if not have:
				res = String(k.call("forge", c.id, at_fire()))
			else:
				res = String(k.call("set_core", c.id, at_fire()))
			bought = res == ""
		"slot":
			if _slot_pick != c.sub:
				_slot_pick = c.sub
				res = ""
			else:
				res = String(k.call("cycle_slot", c.sub, at_fire()))
		"pick":
			res = String(k.call("set_loadout", _slot_pick, c.id, at_fire()))
		"path":
			var hh := _h()
			res = String(hh.call("take_path", c.id)) if hh else "?"
			bought = res == ""
		"unremember":
			var hh := _h()
			res = String(hh.call("unremember", at_home_fire())) if hh else "?"
		"hearth":
			var hh := _h()
			res = String(hh.call("raise", at_home_fire())) if hh else "?"
			bought = res == ""
		"service":
			var hh := _h()
			if c.id == "bells" and hh:
				res = String(hh.call("hang_bells"))
				bought = res == ""
		"walk":
			var hh := _h()
			var i := int(c.id)
			var b: Node3D = _walks[i] if i < _walks.size() else null
			res = String(hh.call("why_not_walk", _fire, b)) if hh else "?"
			if res == "":
				close_menu()
				hh.call("walk", _fire, b)
				return
	_confirm = ""
	if res != "":
		UiSound.play(self, "tick")
		_deny(c)
		return
	UiSound.play(self, "confirm")
	var id := c.id
	var sub := c.sub
	var pick := c.pick
	var kind := c.kind
	_rebuild()
	for i in _cards.size():
		var n := _cards[i]
		if n.id == id and n.kind == kind and n.sub == sub and n.pick == pick:
			_sel = i
			n.flash = 1.0
			if bought:
				_burst(n)
	_show()


func _deny(c: Card) -> void:
	var tw := c.create_tween()
	var x := c.position.x
	tw.tween_property(c, "position:x", x + 6.0, 0.04)
	tw.tween_property(c, "position:x", x - 6.0, 0.06)
	tw.tween_property(c, "position:x", x, 0.04)


## Embers up out of the card, the card flares, the fire chimes.
func _burst(c: Card) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 70
	p.lifetime = 1.1
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = c.size * 0.42
	p.direction = Vector2.UP
	p.spread = 55.0
	p.gravity = Vector2(0, -140)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 260.0
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.32
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	p.texture = tex
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.6, 0.25, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.15, 0.3, 0.0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	_fx_layer.add_child(p)
	p.global_position = c.global_position + c.size * 0.5
	p.emitting = true
	get_tree().create_timer(1.6, true, false, true).timeout.connect(p.queue_free)
	if _chime:
		_chime.pitch_scale = randf_range(0.85, 1.05)
		_chime.play()
