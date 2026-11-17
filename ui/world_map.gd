extends CanvasLayer
## The world map: the whole Realm on one sheet of aged parchment, drawn the way a cartographer of the
## Order would have inked it. M opens and closes it (Esc, F2 and the pad's B close it); the night is
## paused while it is open.
##
## Live marks are drawn over the sheet. Crowded ones fold into one pin with a count (world_map_cluster.gd); beside a lit
## fire a click on another lit fire rides the Ember Road (world_map_travel.gd). Hover a mark (or put it
## under the pad's reticle) to read its name. Drag or the left stick pans, the wheel or the triggers
## zoom, Space / Home / A centre on the wanderer.
##
const LoreDB := preload("res://core/world/realm/lore_db.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const Rift := preload("res://core/world/realm/realm_rift.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const MenuGate := preload("res://ui/menu_gate.gd")
const Frame := preload("res://ui/world_map_frame.gd")
const Inker := preload("res://ui/world_map_ink.gd")
const Shaders := preload("res://ui/world_map_shaders.gd")
const Labels := preload("res://ui/world_map_labels.gd")
const Glyphs := preload("res://ui/world_map_glyphs.gd")
const Med := preload("res://ui/medieval_style.gd")
const MapTravel := preload("res://ui/world_map_travel.gd")
const MapUtil := preload("res://ui/world_map_util.gd")
const MapCluster := preload("res://ui/world_map_cluster.gd")
const Danger := preload("res://core/life/encounters/danger.gd")
const Landmarks := preload("res://ui/world_map_landmarks.gd")

const ACTION := "world_map"
const SHEET := Rect2(-420.0, -214.0, 840.0, 682.0)   ## world xz the parchment covers: the Realm and its margins
const PPM := 2.6                                      ## texture pixels per metre
const FEAT := 2.0                                     ## water / pit grid (m)
const WASH := 4.0                                     ## biome wash grid (m)
const FOG := 5.0                                      ## fog-of-war grid (m)
const ZOOM_MAX := 4.6
const PAN_SPEED := 640.0                              ## screen px per second at full stick
const BAR_H := 84.0
const PICK_R := 17.0
const INK := Color(0.19, 0.12, 0.075)
const GOLD := Color(1.0, 0.76, 0.28)
const CREAM := Color(0.96, 0.92, 0.78)
const SEAL := Color(0.78, 0.16, 0.12)

## wash colour by biome (rgb, alpha): thin watercolour over the parchment
const WASH_COL := {
	"meadow": Color(0.62, 0.68, 0.38, 0.30), "heath": Color(0.66, 0.52, 0.42, 0.30), "oldforest": Color(0.36, 0.48, 0.27, 0.42),
	"fen": Color(0.42, 0.55, 0.46, 0.36), "ruin": Color(0.58, 0.53, 0.48, 0.24), "ash": Color(0.42, 0.34, 0.32, 0.42),
	"crag": Color(0.56, 0.52, 0.47, 0.34), "glade": Color(0.42, 0.62, 0.52, 0.38), "salt": Color(0.93, 0.93, 0.88, 0.55),
}

var _open := false
var _was_captured := false
var _root: Control
var _desk: ColorRect
var _paper: TextureRect
var _ink: TextureRect
var _over: Control
var _fog_mat: ShaderMaterial
var _fog_tex: ImageTexture
var _fog := PackedByteArray()
var _cov: Dictionary = {}                 ## region id -> PackedByteArray coverage on the fog grid
var _margin := PackedByteArray()          ## 255 outside the Realm's bounds (the border always shows)
var _fw := 0
var _fh := 0
var _task := -1
var _data: Dictionary = {}
var _baked := false
var _check := 0.0
var _cinzel: Font
var _serif: Font
var _cen := Vector2.ZERO                  ## world xz at the middle of the map area
var _zoom := 1.0                          ## screen px per metre
var _zoom_min := 1.0
var _area := Rect2()
var _marks: Array[Dictionary] = []
var _you := Vector2.INF
var _facing := Vector2(0, -1)
var _hover := -1
var _press_at := Vector2.ZERO
var _cl: Dictionary = {}                  ## the folded pins (MapCluster.fold), by mark index
var _mouse := Vector2.ZERO
var _use_mouse := true
var _drag := false
var _trig := 0.0
var _pulse := 0.0
var _labels: Labels
var _art := Glyphs.new()
var _seen: Array[String] = []             ## region ids walked, as of opening
var _quest := -1                          ## index of the nearest task mark, or -1
var _here := ""                           ## the name of the ground under the wanderer


func _ready() -> void:
	layer = 64                                  # over the character screen (63), under Settings (70)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"world_map")
	_cinzel = load("res://ui/fonts/Cinzel.ttf")
	_serif = load("res://ui/fonts/body_serif.ttf")
	_labels = Labels.new(_cinzel)
	_art.cinzel = _cinzel
	_build()
	_root.visible = false
	get_viewport().size_changed.connect(_layout)


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_desk = ColorRect.new()
	_desk.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dm := ShaderMaterial.new()
	dm.shader = Shaders.make(Shaders.DESK_SHADER)
	_desk.material = dm
	_root.add_child(_desk)
	_paper = _sheet_rect()
	_root.add_child(_paper)
	_ink = _sheet_rect()
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = Shaders.make(Shaders.FOG_SHADER)
	_fog_mat.set_shader_parameter("res", SHEET.size * PPM)
	_ink.material = _fog_mat
	_root.add_child(_ink)
	var ov := Overlay.new()
	ov.painter = paint
	_over = ov
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_over)


func _sheet_rect() -> TextureRect:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return t


# --- open / close ---------------------------------------------------------------------------------

func is_open() -> bool:
	return _open


func is_baked() -> bool:
	return _baked


## The map can be read when the Realm stands, nothing else holds the night, and no loading card is up.
func can_open(warming := false) -> bool:
	var zone := get_parent()
	if zone == null or not zone.has_meta("realm_done") or get_tree().paused or MenuGate.blocked(self):
		return false
	return (warming or zone.get_node_or_null("LoadingScreen") == null) and get_tree().get_first_node_in_group(Groups.PLAYER) != null


func open(warming := false) -> void:
	if _open or not can_open(warming):
		return
	_open = true
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_rebuild_fog()
	_seen = revealed_regions()
	_collect()
	_layout()
	_recentre()
	_root.visible = true
	_hover = -1
	UiSound.play(self, "map_open")
	set_process(true)


func close() -> void:
	if not _open:
		return
	_open = false
	_drag = false
	_root.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	UiSound.play(self, "map_close")


## Another screen took the night over while the map was up (or the pause was lifted from outside):
## the map steps aside rather than leave the world held behind an empty frame.
func release() -> void:
	if _open:
		close()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -2
	if _open:
		get_tree().paused = false


# --- input ----------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse = mm.position
		_use_mouse = true
		if _drag:
			_cen -= mm.relative / _zoom
			_clamp_view()
			_apply()
		_pick_hover()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_at = mb.position
			elif mb.position.distance_to(_press_at) < 6.0 and _hover >= 0 and _hover < _marks.size():
				MapTravel.click(self, _marks[_hover])
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and Wayfarer.toggle_pin(get_tree(), _s2w(mb.position), _marks[_hover] if _hover >= 0 and _hover < _marks.size() else {}):
			_collect()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.16, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.16, mb.position)
		get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_settings") or event.is_action_pressed("release_mouse") \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).physical_keycode
		if MapCluster.toggle_key(k):
			pass
		elif k == KEY_SPACE or k == KEY_HOME:
			_recentre()
		elif k == KEY_EQUAL or k == KEY_KP_ADD or k == KEY_PAGEUP:
			_zoom_by(1.25, _area.get_center())
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT or k == KEY_PAGEDOWN:
			_zoom_by(0.8, _area.get_center())
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y and Wayfarer.toggle_pin(get_tree(), _s2w(_area.get_center()), _marks[_hover] if _hover >= 0 and _hover < _marks.size() else {}):
			_collect()
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER:
			MapCluster.toggle_key(KEY_1)                     # the pad's filters: LB tasks, RB fires
		elif (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER:
			MapCluster.toggle_key(KEY_2)
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			if _hover < 0 or _hover >= _marks.size() or not MapTravel.click(self, _marks[_hover]):
				_recentre()
		_use_mouse = false
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _baked:
		_bake_step(delta)
	if not _open:
		if _baked:
			set_process(false)
		return
	if not get_tree().paused:
		close()                                  # someone lifted the pause under us
		return
	_pulse += delta
	_art.pulse = _pulse
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if v != Vector2.ZERO:
		_cen += v * PAN_SPEED * delta / _zoom
		_use_mouse = _use_mouse and not _pad_in_use()
		_clamp_view()
		_apply()
		_pick_hover()
	var z := Input.get_axis("look_up", "look_down") * -1.0
	var rt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	z = clampf(z + rt, -1.0, 1.0)
	if absf(z) > 0.12:
		_zoom_by(exp(z * delta * 1.6), _area.get_center())
		_use_mouse = false
	_over.queue_redraw()


func _pad_in_use() -> bool:
	return Input.get_connected_joypads().size() > 0 and Input.get_joy_axis(0, JOY_AXIS_LEFT_X) != 0.0


# --- the view -------------------------------------------------------------------------------------

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_area = Rect2(0.0, 0.0, vs.x, vs.y - BAR_H)
	_zoom_min = minf(_area.size.x * 0.985 / SHEET.size.x, _area.size.y * 0.985 / SHEET.size.y)
	_zoom = clampf(maxf(_zoom, _zoom_min), _zoom_min, ZOOM_MAX)
	_clamp_view()
	_apply()


func _w2s(p: Vector2) -> Vector2:
	return (p - _cen) * _zoom + _area.get_center()


func _s2w(s: Vector2) -> Vector2:
	return (s - _area.get_center()) / _zoom + _cen


func _clamp_view() -> void:
	var half := _area.size * 0.5 / _zoom
	for a in 2:
		var lo := SHEET.position[a] + half[a]
		var hi := SHEET.end[a] - half[a]
		_cen[a] = (SHEET.position[a] + SHEET.size[a] * 0.5) if lo >= hi else clampf(_cen[a], lo, hi)


func _apply() -> void:
	var p := _w2s(SHEET.position)
	var s := SHEET.size * _zoom
	for t: TextureRect in [_paper, _ink]:
		t.position = p
		t.size = s
	_over.queue_redraw()


func _zoom_by(f: float, at: Vector2) -> void:
	var before := _s2w(at)
	_zoom = clampf(_zoom * f, _zoom_min, ZOOM_MAX)
	_cen += before - _s2w(at)
	_clamp_view()
	_apply()
	_pick_hover()


func _recentre() -> void:
	_cen = _you if _you != Vector2.INF else SHEET.get_center()
	_zoom = clampf(maxf(_zoom, _zoom_min * 1.35), _zoom_min, ZOOM_MAX)
	_clamp_view()
	_apply()


# --- fog of war -----------------------------------------------------------------------------------

## How much of the ground at world (x, z) the wanderer has uncovered: 1 inside walked regions (feathered
## to 0 about 25 m beyond them), 0 in the unknown.
func fog_at(x: float, z: float) -> float:
	if _fog.is_empty():
		return 0.0
	var i := clampi(int((x - SHEET.position.x) / FOG), 0, _fw - 1)
	var j := clampi(int((z - SHEET.position.y) / FOG), 0, _fh - 1)
	return float(maxi(_fog[j * _fw + i], MapSketch.cells[j * _fw + i] if MapSketch.cells.size() == _fw * _fh else 0)) / 255.0   # found countries and the charcoal sketch


## The region ids the sheet shows lettered and inked now (walked ones).
func revealed_regions() -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in RealmLayout.REGIONS:
		if CodexStore.discovered(String(r.id)):
			out.append(String(r.id))
	return out


func _rebuild_fog() -> void:
	if _fw == 0:
		return
	_fog = _margin.duplicate()
	for id: String in revealed_regions():
		var cov: PackedByteArray = _cov.get(id, PackedByteArray())
		if cov.size() != _fog.size():
			continue
		for i in _fog.size():
			if cov[i] > _fog[i]:
				_fog[i] = cov[i]
	var img := Image.create_from_data(_fw, _fh, false, Image.FORMAT_R8, _fog)
	if _fog_tex == null:
		_fog_tex = ImageTexture.create_from_image(img)
	else:
		_fog_tex.update(img)
	_fog_mat.set_shader_parameter("fog_tex", _fog_tex)
	Landmarks.attach(_fog_mat)


# --- marks ----------------------------------------------------------------------------------------

func marks() -> Array[Dictionary]:
	return _marks


## What the sheet pins now. Only what the wanderer has found is shown (a mark in unwalked ground
## waits), except her own task, which the quest log already tells her.
func _collect() -> void:
	_marks.clear()
	var tree := get_tree()
	var pl := tree.get_first_node_in_group(Groups.PLAYER) as Node3D
	_you = Vector2(pl.global_position.x, pl.global_position.z) if pl else Vector2.INF
	var vel := Vector2.ZERO
	if pl and "velocity" in pl:
		var v3: Vector3 = pl.get("velocity")
		vel = Vector2(v3.x, v3.z)
	var cam := get_viewport().get_camera_3d()
	if vel.length() > 0.6:
		_facing = vel.normalized()
	elif cam and Vector2(cam.global_basis.z.x, cam.global_basis.z.z).length() > 0.01:
		_facing = Vector2(-cam.global_basis.z.x, -cam.global_basis.z.z).normalized()
	for n in tree.get_nodes_in_group(Groups.BRAZIER):
		var b := n as Brazier
		if b == null:
			continue
		var at := Vector2(b.global_position.x, b.global_position.z)
		if not b.lit and fog_at(at.x, at.y) < 0.5:
			continue
		_marks.append({"at": at, "kind": "fire" if b.lit else "ash", "name": b.display_name(), "fire": b,
			"note": MapTravel.note(tree, b) if b.lit else "Cold ash; kindle it to rest here"})
	for n in tree.get_nodes_in_group(&"lamp"):
		var lp := n as Lamp
		if lp == null or not lp.lit or fog_at(lp.global_position.x, lp.global_position.z) < 0.5:
			continue
		_marks.append({"at": Vector2(lp.global_position.x, lp.global_position.z), "kind": "lamp", "name": "A lamp you lit", "note": "Light to find the way by; it does not drive back the dark"})
	for a in tree.get_nodes_in_group(&"boss_arena"):
		var ba := a as BossArena
		if ba == null or ba.boss_id == "":
			continue
		var bat := Vector2(ba.global_position.x, ba.global_position.z)
		var down := ba.slain()
		if fog_at(bat.x, bat.y) < 0.5 and not down:
			continue
		_marks.append({"at": bat, "kind": "boss_down" if down else "boss", "name": ba.title, "note": "Slain" if down else "Its seal holds. Suggested level %d" % Danger.boss_level(tree, ba.boss_id)})
	for w in tree.get_nodes_in_group(&"watch_post"):
		var w3 := w as Node3D
		if w3 and fog_at(w3.global_position.x, w3.global_position.z) >= 0.5:
			_marks.append({"at": Vector2(w3.global_position.x, w3.global_position.z), "kind": "watch",
				"name": String(w3.get("title")), "note": "A watch post of the Kindled Watch"})
	var owned: Array = Travel.system_state("stable").get("owned", [])
	if not owned.is_empty():
		for h in tree.get_nodes_in_group(&"horse"):
			var h3 := h as Node3D
			if h3 and owned.has(h3.get("breed")):
				_marks.append({"at": Vector2(h3.global_position.x, h3.global_position.z), "kind": "horse", "name": "Your horse", "note": ""})
	for m in tree.get_nodes_in_group(&"map_marker"):
		var m3 := m as Node3D
		if m3 == null or not m3.is_inside_tree() or not m3.has_meta(&"map_kind"):
			continue
		if not m3.is_visible_in_tree() and not m3.has_meta(&"map_always"):
			continue
		var kind := String(m3.get_meta(&"map_kind"))
		if not kind in ["quest_available", "quest_turnin", "quest_target", "rare"]:
			continue
		var mat := Vector2(m3.global_position.x, m3.global_position.z)
		if kind != "quest_target" and fog_at(mat.x, mat.y) < 0.5:
			continue
		var label := String(m3.get_meta(&"map_label", ""))
		var note := {"quest_available": "A task is offered here", "quest_turnin": "A task is finished here",
			"quest_target": "Where your task leads", "rare": "Something rare keeps here"}[kind] as String
		_marks.append({"at": mat, "kind": kind, "name": label if label != "" else note.capitalize(), "note": note if label != "" else "",
			"radius": float(m3.get_meta(&"map_radius", 0.0))})
	_marks.append_array(MapTravel.posts(tree))
	_marks.append_array(Wayfarer.pin_marks())
	if _you != Vector2.INF:
		_here = LoreDB.place_name(String(RealmLayout.region_at(_you.x, _you.y).get("id", "")))
		_marks.append({"at": _you, "kind": "you", "name": "You", "note": _here})
	_quest = -1
	var avoid := PackedVector2Array()
	var qd := INF
	for i in _marks.size():
		var mk := String(_marks[i].kind)
		if mk != "lamp":
			avoid.append(_marks[i].at)
		if mk == "quest_target" and _you != Vector2.INF and _you.distance_to(_marks[i].at) < qd:
			qd = _you.distance_to(_marks[i].at)
			_quest = i
	_labels.set_marks(avoid)
	_art.facing = _facing


func _pick_hover() -> void:
	var at := _mouse if _use_mouse else _area.get_center()
	var best := -1
	var bd := PICK_R
	for i in _marks.size():
		if not _cl.is_empty() and _cl.hide[i] == 1:
			continue
		var d := _w2s(_marks[i].at).distance_to(at)
		if d < bd:
			bd = d
			best = i
	_hover = best


# --- painting the live layer ----------------------------------------------------------------------

class Overlay extends Control:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


func paint(c: Control) -> void:
	var vs := c.size
	var edge := _area.grow(26.0)
	_labels.layout(_zoom, _zoom_min, _seen + Landmarks.seen_ids())
	_labels.draw(c, _zoom, _w2s, _area)
	_guide(c)
	Landmarks.paint(c, _w2s, _area, _fog)
	Wayfarer.paint_trail(c, _w2s, edge)
	_cl = MapCluster.fold(_marks, _w2s, edge)
	for i in _marks.size():
		var m := _marks[i]
		if String(m.kind) == "you" or _cl.hide[i] == 1:
			continue
		var p := _w2s(m.at)
		if edge.has_point(p):
			if float(m.get("radius", 0.0)) > 0.0:          # a search area (clues, a trail): where to look, not a point
				var ring := _w2s(m.at + Vector2(float(m.radius), 0.0)).distance_to(p)
				c.draw_circle(p, ring, Color(GOLD, 0.1))
				c.draw_arc(p, ring, 0.0, TAU, 48, Color(GOLD, 0.75), 2.0, true)
			_art.glyph(c, String(m.kind), p, i == _hover)
			MapCluster.badge(c, p, _cl.count[i], _serif)
	for i in _marks.size():
		if String(_marks[i].kind) == "you":
			var p := _w2s(_marks[i].at)
			_art.arrow(c, p, i == _hover)
	if _you != Vector2.INF:
		_pointer(c, _you, CREAM, "You")
	if _quest >= 0:
		_pointer(c, _marks[_quest].at, GOLD, "Task")
	_plate(c)
	if _hover >= 0 and _hover < _marks.size():
		_tip(c, _w2s(_marks[_hover].at), _marks[_hover])
	_bar(c, vs)


## A forged strip: dark leather in the kit's iron frame, bronze rule on top.
func _forge(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color(0.075, 0.048, 0.03, 0.985))
	c.draw_style_box(Med.frame(), r)
	c.draw_rect(Rect2(r.position + Vector2(8.0, 8.0), r.size - Vector2(16.0, 16.0)), Color(Med.BRONZE, 0.28), false, 1.0)


## The legend and the controls, on the forged strip at the foot.
func _bar(c: Control, vs: Vector2) -> void:
	var by := vs.y - BAR_H
	_forge(c, Rect2(0.0, by, vs.x, BAR_H))
	var pad := Input.get_connected_joypads().size() > 0 and not _use_mouse
	var close_k := InputSetup.live_label(ACTION, pad, "M")
	var txt := "Drag or stick: pan     Wheel or triggers: zoom     Space or A: find yourself     Right-click or Y: set or lift a mark     1-5: filters     %s or Esc: close" % close_k
	c.draw_string(_serif, Vector2(34.0, by + 66.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Med.BONE_DIM)
	var lamps := Lamp.tally(get_tree())
	var x := 34.0
	for it: Array in [["you", "You"], ["quest_target", "Your task"], ["quest_available", "Task offered"], ["fire", "Lit fire"],
			["lamp", "Lamps %d of %d" % [lamps.x, lamps.y]], ["boss", "Boss"], ["watch", "Outpost"], ["rare", "Rare"], ["horse", "Horse"]]:
		var p := Vector2(x + 12.0, by + 31.0)
		if String(it[0]) == "you":
			_art.arrow(c, p, false, 0.7)
		else:
			_art.glyph(c, String(it[0]), p, false, 0.85)
		c.draw_string(_serif, Vector2(x + 30.0, by + 37.0), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Med.BONE)
		x += 30.0 + _serif.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 30.0


## A gilt dotted course from the wanderer to her nearest task, under the marks.
func _guide(c: Control) -> void:
	if _quest < 0 or _you == Vector2.INF:
		return
	var a := _w2s(_you)
	var b := _w2s(_marks[_quest].at)
	c.draw_dashed_line(a, b, Color(INK, 0.55), 5.0, 9.0, false, true)
	c.draw_dashed_line(a, b, GOLD, 2.6, 9.0, false, true)


## Where the wanderer or her task lie when they are off the view: a chevron on its edge, pointing there.
func _pointer(c: Control, world: Vector2, col: Color, text: String) -> void:
	var p := _w2s(world)
	var box := _area.grow(-36.0)
	if box.has_point(p):
		return
	var ctr := _area.get_center()
	var d := p - ctr
	var t := minf(box.size.x * 0.5 / maxf(absf(d.x), 0.001), box.size.y * 0.5 / maxf(absf(d.y), 0.001))
	var q := ctr + d * t
	var u := d.normalized()
	var n := Vector2(-u.y, u.x)
	var pts := PackedVector2Array([q + u * 15.0, q - u * 9.0 + n * 11.0, q - u * 9.0 - n * 11.0])
	c.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	c.draw_polyline(pts, INK, 2.2, true)
	var w := _serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var tp := (q - u * 30.0 - Vector2(w * 0.5, -6.0)).clamp(_area.position + Vector2(6.0, 20.0), _area.end - Vector2(w + 6.0, 8.0))
	c.draw_string_outline(_serif, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 5, Color(0.05, 0.036, 0.03, 0.9))
	c.draw_string(_serif, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, col)


## The sheet's cartouche, top left: where she stands, where her task lies, and what she has found.
func _plate(c: Control) -> void:
	var rows: Array[Array] = []
	if _you != Vector2.INF:
		rows.append(["you", _here if _here != "" else "The wilds", true])
	if _quest >= 0:
		var qm := _marks[_quest]
		rows.append(["quest_target", "%s  (%d m)" % [String(qm.name), int(_you.distance_to(qm.at))] if _you != Vector2.INF else String(qm.name), false])
	rows.append(["fire", "Places found %d of %d" % [_seen.size(), RealmLayout.REGIONS.size()], false])
	var w := 0.0
	for r in rows:
		w = maxf(w, (_cinzel if r[2] else _serif).get_string_size(String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x)
	w += 76.0
	var h := 24.0 + rows.size() * 32.0
	var o := Vector2(16.0, 16.0)
	c.draw_rect(Rect2(o + Vector2(3, 5), Vector2(w, h)), Color(0, 0, 0, 0.4))
	_forge(c, Rect2(o, Vector2(w, h)))
	for i in rows.size():
		var r := rows[i]
		var y := o.y + 12.0 + i * 32.0
		if String(r[0]) == "you":
			_art.arrow(c, Vector2(o.x + 28.0, y + 16.0), false, 0.62)
		else:
			_art.glyph(c, String(r[0]), Vector2(o.x + 28.0, y + 16.0), false, 0.8)
		c.draw_string(_cinzel if r[2] else _serif, Vector2(o.x + 52.0, y + 23.0), String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Med.GILT if r[2] else Med.BONE)


func _tip(c: Control, at: Vector2, m: Dictionary) -> void:
	var name_s := String(m.name)
	var note := String(m.note)
	var w := maxf(_cinzel.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, _serif.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x) + 28.0
	var h := 40.0 if note == "" else 66.0
	var p := at + Vector2(16.0, -h - 14.0)
	p.x = clampf(p.x, 8.0, c.size.x - w - 8.0)
	p.y = clampf(p.y, 8.0, c.size.y - BAR_H - h - 8.0)
	c.draw_rect(Rect2(p + Vector2(3, 4), Vector2(w, h)), Color(0, 0, 0, 0.35))
	c.draw_rect(Rect2(p, Vector2(w, h)), Color(0.93, 0.85, 0.66, 0.97))
	c.draw_rect(Rect2(p, Vector2(w, h)), INK, false, 2.0)
	c.draw_rect(Rect2(p + Vector2(4, 4), Vector2(w - 8, h - 8)), Color(INK, 0.5), false, 1.0)
	c.draw_string(_cinzel, p + Vector2(14.0, 27.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	if note != "":
		c.draw_string(_serif, p + Vector2(14.0, 54.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 0.24, 0.15))


# --- baking the sheet -----------------------------------------------------------------------------

func _bake_step(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.4
	if _task == -1:
		var zone := get_parent()
		if zone == null or not zone.has_meta("realm_done") or Land._h.is_empty() or Land._water.is_empty():
			return
		_task = WorkerThreadPool.add_task(_compute)
	elif _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -2
		_assemble()


## Worker thread: reads RealmLand's finished static arrays and the layout; writes only `_data`.
func _compute() -> void:
	var b := RealmLayout.BOUNDS
	var fw := int(ceil(SHEET.size.x / FEAT))
	var fh := int(ceil(SHEET.size.y / FEAT))
	var water := PackedFloat32Array()
	var pit := PackedFloat32Array()
	var block := PackedByteArray()
	water.resize(fw * fh)
	pit.resize(fw * fh)
	block.resize(fw * fh)
	for j in fh:
		var z := SHEET.position.y + (j + 0.5) * FEAT
		if z < b.position.y or z > b.end.y:
			continue
		for i in fw:
			var x := SHEET.position.x + (i + 0.5) * FEAT
			if x < b.position.x or x > b.end.x:
				continue
			var h := Land.height_at(x, z)
			if Land.in_water(x, z) or (h < -13.0 and z > Rift.STAR_Z and absf(x) < 30.0):
				water[j * fw + i] = 1.0                 # (the Threshold's starwater reads as water, not the rift's pit)
				block[j * fw + i] = 1
			elif h < -4.0:
				pit[j * fw + i] = 1.0
				block[j * fw + i] = 1
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var e: Vector2 = pts[k + 1]
			var n := int(a.distance_to(e) / FEAT) + 1
			for s in n + 1:
				_stamp(block, fw, fh, a.lerp(e, float(s) / n), 3.2)
	var spots: Array[Vector2] = []
	for id: String in RealmLayout.SLOTS:
		for sl: Dictionary in RealmLayout.SLOTS[id]:
			if String(sl.kind) in ["poi", "fire", "poi_wet"]:
				spots.append(sl.at)
	for sp in spots:
		_stamp(block, fw, fh, sp, 7.0)
	var data := {}
	var names := {}
	for r: Dictionary in RealmLayout.REGIONS:
		names[String(r.id)] = LoreDB.place_name(String(r.id))
	data["names"] = names
	data["feat"] = _feature_image(water, pit, fw, fh)
	data["fw"] = fw
	data["fh"] = fh
	data["wash"] = _wash_image(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.045
	var peaks := PackedVector3Array()
	var hills := PackedVector3Array()
	var trees := PackedVector3Array()
	var tufts := PackedVector3Array()          # x, z, kind (0 heath, 1 reed, 2 salt, 3 grass)
	var step := 5.0
	var x0 := b.position.x + 2.0
	var z0 := b.position.y + 2.0
	var gx := 0
	while x0 + gx * step < b.end.x:
		var gz := 0
		while z0 + gz * step < b.end.y:
			var x := x0 + gx * step + rng.randf_range(-2.0, 2.0)
			var z := z0 + gz * step + rng.randf_range(-2.0, 2.0)
			gz += 1
			if x < b.position.x or x > b.end.x or z < b.position.y or z > b.end.y:
				continue
			var ci := int((x - SHEET.position.x) / FEAT) + int((z - SHEET.position.y) / FEAT) * fw
			if block[ci] != 0:
				continue
			var h := Land.height_at(x, z)
			if h >= 12.0:
				if rng.randf() < 0.78:
					peaks.append(Vector3(x, z, h))
				continue
			var biome := RealmLayout.biome_at(x, z)
			if h >= 7.0 and biome != "oldforest" and biome != "fen" and rng.randf() < 0.3:
				hills.append(Vector3(x, z, h))
				continue
			match biome:
				"oldforest":
					if noise.get_noise_2d(x, z) > -0.2 and rng.randf() < 0.7:
						trees.append(Vector3(x, z, rng.randf_range(1.5, 2.5)))
				"glade":
					if rng.randf() < 0.1:
						trees.append(Vector3(x, z, rng.randf_range(1.3, 1.9)))
				"meadow":
					if rng.randf() < 0.06:
						trees.append(Vector3(x, z, rng.randf_range(1.4, 2.0)))
					elif rng.randf() < 0.12:
						tufts.append(Vector3(x, z, 3.0))
				"heath":
					if rng.randf() < 0.22:
						tufts.append(Vector3(x, z, 0.0))
				"fen":
					if rng.randf() < 0.26:
						tufts.append(Vector3(x, z, 1.0))
				"salt":
					if rng.randf() < 0.07:
						tufts.append(Vector3(x, z, 2.0))
		gx += 1
	# the Cinder Orchard: rows of burned stumps
	var dead := PackedVector2Array()
	for ox in range(-146, -72, 9):
		for oz in range(94, 150, 8):
			var q := Vector2(ox, oz) + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if block[int((q.x - SHEET.position.x) / FEAT) + int((q.y - SHEET.position.y) / FEAT) * fw] == 0:
				dead.append(q)
	peaks = MapUtil.sorted_z(peaks)
	hills = MapUtil.sorted_z(hills)
	trees = MapUtil.sorted_z(trees)
	data["peaks"] = peaks
	data["hills"] = hills
	data["trees"] = trees
	data["tufts"] = tufts
	data["dead"] = dead
	data["houses"] = _houses(block, fw, fh, rng)
	data["mounds"] = _mounds(rng)
	data["cov"] = _coverage()
	_data = data


func _stamp(block: PackedByteArray, fw: int, fh: int, at: Vector2, r_m: float) -> void:
	var rc := int(ceil(r_m / FEAT))
	var ci := int((at.x - SHEET.position.x) / FEAT)
	var cj := int((at.y - SHEET.position.y) / FEAT)
	for j in range(cj - rc, cj + rc + 1):
		for i in range(ci - rc, ci + rc + 1):
			if i >= 0 and j >= 0 and i < fw and j < fh and Vector2(i - ci, j - cj).length() * FEAT <= r_m:
				block[j * fw + i] = 1


## Water and the pit as two soft channels: blurred so the shader can find a smooth shore.
func _feature_image(water: PackedFloat32Array, pit: PackedFloat32Array, fw: int, fh: int) -> Image:
	var wv := MapUtil.blur(MapUtil.blur(water, fw, fh, 2), fw, fh, 2)
	var pv := MapUtil.blur(MapUtil.blur(pit, fw, fh, 2), fw, fh, 2)
	var bytes := PackedByteArray()
	bytes.resize(fw * fh * 2)
	for i in fw * fh:
		bytes[i * 2] = int(clampf(wv[i], 0.0, 1.0) * 255.0)
		bytes[i * 2 + 1] = int(clampf(pv[i], 0.0, 1.0) * 255.0)
	return Image.create_from_data(fw, fh, false, Image.FORMAT_RG8, bytes)


func _wash_image(b: Rect2) -> Image:
	var ww := int(ceil(SHEET.size.x / WASH))
	var wh := int(ceil(SHEET.size.y / WASH))
	var bytes := PackedByteArray()
	bytes.resize(ww * wh * 4)
	for j in wh:
		var z := SHEET.position.y + (j + 0.5) * WASH
		for i in ww:
			var x := SHEET.position.x + (i + 0.5) * WASH
			if x < b.position.x - WASH or x > b.end.x + WASH or z < b.position.y - WASH or z > b.end.y + WASH:
				continue
			var col: Color = WASH_COL.get(RealmLayout.biome_at(clampf(x, b.position.x, b.end.x), clampf(z, b.position.y, b.end.y)), WASH_COL.meadow)
			var shade := clampf(1.0 - Land.height_at(clampf(x, b.position.x, b.end.x), clampf(z, b.position.y, b.end.y)) * 0.008, 0.72, 1.0)
			var k := (j * ww + i) * 4
			bytes[k] = int(col.r * shade * 255.0)
			bytes[k + 1] = int(col.g * shade * 255.0)
			bytes[k + 2] = int(col.b * shade * 255.0)
			bytes[k + 3] = int(col.a * 255.0)
	return Image.create_from_data(ww, wh, false, Image.FORMAT_RGBA8, bytes)


## Houses at the three living settlements (Hearthward, Weirford, Saltmarket) and a hut on the downs.
func _houses(block: PackedByteArray, fw: int, _fh: int, rng: RandomNumberGenerator) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s: Array in [[Vector2(6, 38), 26.0, 11], [Vector2(-205, 66), 26.0, 10], [Vector2(212, 92), 17.0, 6], [Vector2(0, 196), 5.0, 1]]:
		var c: Vector2 = s[0]
		var placed: Array[Vector2] = []
		var tries := 0
		while placed.size() < int(s[2]) and tries < 200:
			tries += 1
			var q := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * float(s[1])
			if RealmLayout.TAVERN.grow(4.0).has_point(q) and c.is_equal_approx(Vector2(6, 38)):
				continue
			if q.x < RealmLayout.BOUNDS.position.x or q.x > RealmLayout.BOUNDS.end.x:
				continue
			if block[int((q.x - SHEET.position.x) / FEAT) + int((q.y - SHEET.position.y) / FEAT) * fw] != 0:
				continue
			var near := false
			for o in placed:
				near = near or o.distance_to(q) < 9.0
			if near:
				continue
			placed.append(q)
			out.append(Vector3(q.x, q.y, rng.randf_range(-0.35, 0.35)))
	return out


func _mounds(rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 5:
		out.append(RealmLayout.BARROWS_C + Vector2.from_angle(TAU * k / 5.0 + 0.4) * rng.randf_range(7.0, 12.0))
	for k in 6:
		out.append(Vector2(-134, 12) + Vector2.from_angle(TAU * k / 6.0 + 0.2) * rng.randf_range(6.0, 12.0))
	return out


## For each region: how far each fog cell is from it, as bytes (255 inside, feathered out to ~26 m).
func _coverage() -> Dictionary:
	var b := RealmLayout.BOUNDS
	var fw := int(ceil(SHEET.size.x / FOG))
	var fh := int(ceil(SHEET.size.y / FOG))
	var out := {}
	for r: Dictionary in RealmLayout.REGIONS:
		var arr := PackedByteArray()
		arr.resize(fw * fh)
		for j in fh:
			var z := SHEET.position.y + (j + 0.5) * FOG
			for i in fw:
				var x := SHEET.position.x + (i + 0.5) * FOG
				var d := 0.0
				if r.has("rect"):
					var rc: Rect2 = r.rect
					d = Vector2(maxf(maxf(rc.position.x - x, x - rc.end.x), 0.0), maxf(maxf(rc.position.y - z, z - rc.end.y), 0.0)).length()
				else:
					d = maxf(Vector2(x, z).distance_to(r.c) - float(r.r), 0.0)
				arr[j * fw + i] = int((1.0 - smoothstep(5.0, 26.0, d)) * 255.0)
		out[String(r.id)] = arr
	var mg := PackedByteArray()
	mg.resize(fw * fh)
	for j in fh:
		var z2 := SHEET.position.y + (j + 0.5) * FOG
		for i in fw:
			var x2 := SHEET.position.x + (i + 0.5) * FOG
			mg[j * fw + i] = 0 if (x2 > b.position.x and x2 < b.end.x and z2 > b.position.y and z2 < b.end.y) else 255
	out["__margin"] = mg
	out["__w"] = fw
	out["__h"] = fh
	return out


## Main thread: hand the fog data over, draw the two layers once, read them back, free the viewports.
func _assemble() -> void:
	var cov: Dictionary = _data.cov
	_fw = int(cov["__w"])
	_fh = int(cov["__h"])
	_margin = cov["__margin"]
	cov.erase("__margin")
	_cov = cov
	if DisplayServer.get_name() == "headless":
		_baked = true
		return
	var px := Vector2i(int(ceil(SHEET.size.x * PPM)), int(ceil(SHEET.size.y * PPM)))
	var paper_vp := _viewport(px)
	var ink_vp := _viewport(px)
	var rect := ColorRect.new()
	rect.size = Vector2(px)
	var pm := ShaderMaterial.new()
	pm.shader = Shaders.make(Shaders.PAPER_SHADER)
	pm.set_shader_parameter("res", Vector2(px))
	rect.material = pm
	paper_vp.add_child(rect)
	var frame := Frame.new()
	frame.cinzel = _cinzel
	frame.serif = _serif
	frame.size = Vector2(px)
	paper_vp.add_child(frame)
	var terrain := TextureRect.new()
	terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	terrain.stretch_mode = TextureRect.STRETCH_SCALE
	var wash_t := ImageTexture.create_from_image(_data.wash)
	terrain.texture = wash_t                                            # the rect needs a texture to draw; the shader reads wash_tex
	terrain.size = Vector2(px)
	var tm := ShaderMaterial.new()
	tm.shader = Shaders.make(Shaders.TERRAIN_SHADER)
	tm.set_shader_parameter("wash_tex", wash_t)
	tm.set_shader_parameter("feat_tex", ImageTexture.create_from_image(_data.feat))
	tm.set_shader_parameter("res", Vector2(px))
	var bn := RealmLayout.BOUNDS
	tm.set_shader_parameter("bounds", Vector4((bn.position.x - SHEET.position.x) / SHEET.size.x, (bn.position.y - SHEET.position.y) / SHEET.size.y,
		(bn.end.x - SHEET.position.x) / SHEET.size.x, (bn.end.y - SHEET.position.y) / SHEET.size.y))
	terrain.material = tm
	ink_vp.add_child(terrain)
	var inker := Inker.new()
	inker.data = _data
	inker.cinzel = _cinzel
	inker.serif = _serif
	inker.size = Vector2(px)
	ink_vp.add_child(inker)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_paper.texture = _readback(paper_vp)
	_ink.texture = _readback(ink_vp)
	paper_vp.queue_free()
	ink_vp.queue_free()
	_data = {}
	_baked = true


func _viewport(px: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(vp)
	return vp


func _readback(vp: SubViewport) -> Texture2D:
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return vp.get_texture()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
