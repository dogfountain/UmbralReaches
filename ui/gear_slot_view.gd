extends Control
## One square of the gear screen: a pack cell, a paper-doll socket or a small charm / relic socket.
## An iron-rimmed slot with the item's icon, the rim in its rarity colour, the item level small in a
## corner, a marker for what is new, a tick for what is worn, a bar in the set's tint. An empty socket
## shows its slot's glyph, faint. Drag a piece onto its socket to wear it; drag a worn one back to the
## pack to take it off. Clicking or focusing selects (the panel shows its card); Enter / double-click
## / right-click asks to wear or take off.
##   const SlotView := preload("res://ui/gear_slot_view.gd")

signal picked(view: Control)
signal clicked(view: Control)
signal toggled(view: Control)
signal dropped(view: Control, data: Dictionary)

const Med := preload("res://ui/medieval_style.gd")
const UIType := preload("res://ui/type.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const Glyphs := preload("res://core/life/progression/icons.gd")

const CELL := 74.0
const SOCKET := 96.0
const MINI := 58.0
const CAPTION_H := 24.0

var piece := {}                     ## the gear piece shown ({} = empty)
var kind := "cell"                  ## cell | socket | mini
var slot_id := ""                   ## a socket's gear slot
var caption := ""                   ## under a socket
var tex: Texture2D                  ## the piece's icon
var ghost := ""                     ## the glyph an empty socket shows
var ghost_tint := Med.BONE_FAINT
var rim := Color.WHITE              ## override for the rim (minis: the item's tint)
var ref_id := ""                    ## a mini's item id (charm, relic, core)
var is_new := false
var is_worn := false
var selected := false
var dimmed := false
var badge := ""                     ## small gilt text bottom-left ("+2")
var corner := ""                    ## small text bottom-right (the item level)
var set_tint := Color(0, 0, 0, 0)
var _hover := false


func setup(k: String, slot := "", cap := "") -> void:
	kind = k
	slot_id = slot
	caption = cap
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	match k:
		"socket":
			custom_minimum_size = Vector2(SOCKET, SOCKET + CAPTION_H)
		"mini":
			custom_minimum_size = Vector2(MINI, MINI)
		_:
			custom_minimum_size = Vector2(CELL, CELL)
	focus_entered.connect(func() -> void: picked.emit(self))
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func uid() -> int:
	return int(piece.get("uid", -1))


func set_piece(p: Dictionary) -> void:
	piece = p
	if kind == "cell":
		focus_mode = Control.FOCUS_ALL if not p.is_empty() else Control.FOCUS_NONE
	queue_redraw()


func _box() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, size.x))


func _draw() -> void:
	var box := _box()
	var q := int(piece.get("rarity", 0))
	var has := not piece.is_empty()
	var tint := Color(0.62, 0.58, 0.55)
	if has:
		tint = LootDB.quality_color(q)
	elif ref_id != "" or kind == "mini":
		tint = rim
	var a := 0.45 if dimmed else 1.0
	draw_style_box(Med.slot(tint), box)
	var inner := box.grow(-box.size.x * 0.1)
	if has and tex != null:
		draw_texture_rect(tex, inner, false, Color(1, 1, 1, a))
	elif has:
		Glyphs.draw(self, String(GearDB.SLOT_GLYPH.get(String(piece.get("slot", "")), "prism")), box.get_center(), box.size.x * 0.27, Color(tint, a))
	elif ref_id != "" and tex != null:
		draw_texture_rect(tex, inner, false, Color(1, 1, 1, a))
	elif ghost != "":
		Glyphs.draw(self, ghost, box.get_center(), box.size.x * 0.27, Color(Med.BONE_DIM, 0.5))
	var f := UIType.body()
	if has and set_tint.a > 0.0:
		draw_rect(Rect2(box.position.x + 7, box.end.y - 8, box.size.x - 14, 3), Color(set_tint, a))
	if corner != "" and kind != "mini":
		var fs := 15 if kind == "cell" else 17
		var w := f.get_string_size(corner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(box.end.x - w - 8, box.end.y - 12)
		draw_string(f, pos + Vector2(1, 1), corner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.9))
		draw_string(f, pos, corner, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Med.BONE, a))
	if badge != "":
		var fs2 := 15
		var p2 := Vector2(box.position.x + 8, box.end.y - 12)
		draw_string(f, p2 + Vector2(1, 1), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0, 0, 0, 0.9))
		draw_string(f, p2, badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(Med.GILT, a))
	if is_new:
		var c := Vector2(box.end.x - 13, box.position.y + 13)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)]), Color(0, 0, 0, 0.8))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), Med.GILT)
	if is_worn:
		var c2 := Vector2(box.position.x + 14, box.position.y + 14)
		draw_circle(c2, 10.0, Color(0.05, 0.03, 0.02, 0.85))
		draw_arc(c2, 10.0, 0.0, TAU, 20, Med.GILT, 1.6)
		draw_polyline(PackedVector2Array([c2 + Vector2(-4.5, 0.5), c2 + Vector2(-1.2, 4), c2 + Vector2(5, -3.5)]), Med.GILT, 2.0)
	if selected or has_focus() or _hover:
		var edge := Color(1.0, 0.92, 0.62) if (selected or has_focus()) else Color(Med.GILT, 0.55)
		draw_rect(box.grow(1), edge, false, 2.5 if (selected or has_focus()) else 1.5)
		if selected or has_focus():
			draw_rect(box.grow(4), Color(Med.GILT, 0.28), false, 2.0)
	if caption != "":
		var fs3 := 14
		var tf := UIType.title()
		var s := caption.to_upper()
		var w3 := tf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
		var cc := Med.BONE_DIM if not has else tint.lerp(Med.BONE, 0.45)
		draw_string(tf, Vector2((size.x - w3) * 0.5, box.end.y + 18), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, cc)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(self)
			clicked.emit(self)
			if mb.double_click:
				toggled.emit(self)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			picked.emit(self)
			toggled.emit(self)
	elif has_focus() and e.is_action_pressed("ui_accept") and not e.is_echo():
		toggled.emit(self)
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if piece.is_empty() or kind == "mini" or tex == null:
		return null
	var holder := Control.new()
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = Vector2(72, 72)
	tr.position = Vector2(-36, -36)
	tr.modulate = Color(1, 1, 1, 0.85)
	holder.add_child(tr)
	set_drag_preview(holder)
	return {"gear_uid": uid(), "slot": String(piece.get("slot", "")), "from_socket": kind == "socket"}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not (data as Dictionary).has("gear_uid"):
		return false
	var d := data as Dictionary
	if kind == "socket":
		return slot_id == String(d.slot) and not bool(d.from_socket)
	return kind == "cell" and bool(d.from_socket)


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(self, data as Dictionary)
