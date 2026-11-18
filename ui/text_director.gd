extends Node
## The HUD's text arbiter (critique: up to eleven text layers drew at once). Owned by ui/hud.gd (a child of
## it, group "text_director"), not an autoload. Every transient line of text asks it before it draws.
##
## Lanes (each a fixed rectangle of the screen, see lane_rect()):
##   banner     top centre, one at a time:      boss title (core/enemy/boss_title.gd), boss emote (the arena draws it at y 168), title card, discovery banner, quest banner
##   sub        lower centre, one at a time:    narration subtitle, lesson
##   toast      bottom left corner, two at most: toasts, and the quiet line a rate-limited discovery leaves
##   objective  top right (objective_line.gd): not a queue; it stands aside while the banner lane is up
## Priority (higher wins a lane; a lower post queues while a higher one is up, in any lane):
##   boss title 7 > narration 6 > boss emote 5 > title card 4 > lesson 3 > discovery / quest 2 > toast 1 > quiet line 0
## Busy rule: while narration or a dialogue box is up, banners and toasts (and lessons) queue.
##   While locked on to a foe, only boss emotes and lessons (and narration) draw.
## Discovery banners are limited to one per DISCOVERY_GAP seconds; a discovery past the limit leaves a
## quiet small line in the corner instead (the Journal still records it).
##
## Two kinds of speaker:
##   managed   toast / lesson / quiet line: post_toast(), post_lesson(), quiet(). The director queues and draws.
##   claiming  title / discovery / quest / narration: the owner draws, but asks can_begin(kind) first, then
##             begin(kind, seconds, rect) and (optionally) end(kind). The owner keeps its own text queue.
## Load by path (no class_name): const TextDirector := preload("res://ui/text_director.gd")

## A same-lane lower kind was displaced by a higher one: its owner may fade it out.
signal bumped(kind: StringName)

const GROUP := &"text_director"
const DISCOVERY_GAP := 90.0
const MAX_TOASTS := 2
const TOAST_HOLD := 3.4
const KINDS := {
	&"narration": {"lane": &"sub", "pri": 6},
	&"boss_title": {"lane": &"banner", "pri": 7},          # the great one's name: wins the banner lane, and cuts a card or banner already up
	&"boss_emote": {"lane": &"banner", "pri": 5},
	&"title": {"lane": &"banner", "pri": 4},
	&"lesson": {"lane": &"sub", "pri": 3},
	&"quest": {"lane": &"banner", "pri": 2},
	&"discovery": {"lane": &"banner", "pri": 2},
	&"toast": {"lane": &"toast", "pri": 1},
	&"quiet": {"lane": &"toast", "pri": 0},
}
const UIType := preload("res://ui/type.gd")
const Stamina := preload("res://core/player/stamina.gd")
const KeyCap := preload("res://ui/key_cap.gd")

var enabled_fight_gate := true         ## tests switch the locked-on rule off
var opening := false                   ## a new game's staged opening is on: banners and quest cards wait (the HUD sets it)
var _clock := 0.0
var _occ: Dictionary = {}              ## kind -> {"until": float, "rect": Rect2}
var _last_discovery := -1.0e9
var banner_log: Array[float] = []      ## tests: the clock at every discovery banner
var _toast_q: Array[Dictionary] = []   ## {"text", "kind"}
var _lesson_q: Array[String] = []
var _lesson_basic: Array[String] = []      ## the queued or showing lessons that teach controls: they step aside in a fight
const TIP_UP := 282.0                      ## the lesson line rides over the interact prompt (its own lane), not on it
const ASIDE := Vector2(28.0, 420.0)        ## in a fight the lower lane's lines (lessons, the wanderer's voice) sit here
const ASIDE_W := 600.0                     ## (their left, top), clear of the banner lane above and the toasts below
var _toasts: Array[Label] = []
var _toast_box: VBoxContainer
var _tip: Label
var _tip_aside := false                    ## the lesson showing went to the fight's column (plate_low)
var _tip_raw := ""                         ## the lesson as posted ({action} tokens kept): _tip shows its plain words
var _keys_plate: PanelContainer            ## a lesson with {action} tokens draws here: painted caps and words (ui/key_cap.gd)
var _tip_t := 0.0
var _tip_cool := 0.0
var _root: Control
var _dialogue_open := false            ## a stand-in tests (and a poll of the dialogue box) set
var _locked := false
var _engaged := false                  ## a foe is awake and near (the stamina watch): place banners wait it out
var _poll := 0.0
var _emote_seen := ""


## The director of the tree `n` is in (null in a bare test scene).
static func of(n: Node) -> Node:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(GROUP)


## Body text size with the player's Text Scale applied.
static func px(base: int) -> int:
	return maxi(8, roundi(float(base) * clampf(Settings.text_scale, 0.85, 1.5)))


## "NEW TASK" -> "New task": running text is sentence case (Cinzel capitals are for titles).
static func sentence(s: String) -> String:
	if s.length() < 2 or s != s.to_upper() or s == s.to_lower():
		return s
	return s.substr(0, 1) + s.substr(1).to_lower()


## Give `l` a body size that follows the Text Scale (rescale() re-applies it when the setting moves).
static func scaled(l: Label, base: int) -> Label:
	l.set_meta(&"ts_base", base)
	l.add_theme_font_size_override("font_size", px(base))
	return l


## A soft dark plate behind a line of text that sits on the open world: a translucent ink pill with a faint bronze edge.
static func backing(pad_x := 20, pad_y := 9) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.012, 0.66)
	sb.border_color = Color(0.62, 0.45, 0.2, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	return sb


## Put the plate behind `l` and size the label to hug `text` (wrapped at `max_w`), centred on its anchor and sitting
## on `bottom` (an offset from the screen's bottom edge): the plate never spans the whole lane for a short line.
static func plate(l: Label, text: String, max_w: float, bottom: float) -> void:
	var sb := l.get_theme_stylebox("normal") as StyleBox
	if not sb is StyleBoxFlat:
		sb = backing()
		l.add_theme_stylebox_override("normal", sb)
	var padx := sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	var pady := sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var inner := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_w - padx, fs)
	var w := minf(inner.x + 6.0, max_w - padx) + padx
	l.offset_left = -w * 0.5
	l.offset_right = w * 0.5
	l.offset_bottom = bottom
	l.offset_top = bottom - (inner.y + pady + 4.0)


## Re-apply the Text Scale to every Label under `root` that was made with scaled().
static func rescale(root: Node) -> void:
	for n in root.find_children("*", "Label", true, false):
		if n.has_meta(&"ts_base"):
			(n as Label).add_theme_font_size_override("font_size", px(int(n.get_meta(&"ts_base"))))


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- the rectangles ----------------------------------------------------------------------------------

func _vs() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp else Vector2(1920, 1080)


func lane_rect(lane: StringName) -> Rect2:
	var v := _vs()
	match lane:
		&"banner":
			return Rect2(v.x * 0.5 - 550.0, 112.0, 1100.0, 300.0)
		&"sub":
			return Rect2(v.x * 0.5 - 480.0, v.y - 430.0, 960.0, 160.0)
		&"toast":
			return Rect2(28.0, v.y - 330.0, 280.0, 200.0)
		&"objective":
			return Rect2(v.x - 640.0, 34.0, 596.0, 386.0)
	return Rect2()


# --- claiming ----------------------------------------------------------------------------------------

func _pri(kind: StringName) -> int:
	return int((KINDS.get(kind, {"pri": 0}) as Dictionary).pri)


func _lane(kind: StringName) -> StringName:
	return (KINDS.get(kind, {"lane": &"toast"}) as Dictionary).lane


func is_up(kind: StringName) -> bool:
	return _occ.has(kind)


## Is the lane `lane` in use right now (a claim, or for the toast lane a toast showing)?
func lane_busy(lane: StringName) -> bool:
	for k: StringName in _occ:
		if _lane(k) == lane:
			return true
	return lane == &"toast" and not _toasts.is_empty()


func narration_or_dialogue() -> bool:
	return _occ.has(&"narration") or _dialogue_open


## Plate a lower-lane line (a lesson, the wanderer's voice) at `bottom`, or in a fight in the left column, as narrow as
## its words allow: the middle is the foe, the red round the wanderer and a great one's head under its bar (lifted 500 px,
## a lesson still sat on the Anchoress, under her emote).
## True when it went to the column.
func plate_low(l: Label, text: String, max_w: float, bottom: float) -> bool:
	if not in_combat():
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate(l, text, max_w, bottom)
		return false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	plate(l, text, minf(max_w, ASIDE_W), 0.0)
	var v := _vs()
	var w := l.offset_right - l.offset_left
	var h := l.offset_bottom - l.offset_top
	l.offset_left = -v.x * 0.5 + ASIDE.x                  # the labels hang from the bottom centre
	l.offset_right = l.offset_left + w
	l.offset_top = -v.y + ASIDE.y
	l.offset_bottom = l.offset_top + h
	return true


## A fight is on (a foe awake and near, or a lock-on): place banners wait until it ends.
func in_combat() -> bool:
	return enabled_fight_gate and (_engaged or _locked)


func in_fight() -> bool:
	return enabled_fight_gate and _locked


## May `kind` start drawing now? False = hold it in your own queue and ask again later.
func can_begin(kind: StringName) -> bool:
	if _occ.has(kind):
		return false
	var p := _pri(kind)
	var lane := _lane(kind)
	if narration_or_dialogue() and kind != &"narration":
		return false
	if opening and kind in [&"discovery", &"quest"]:
		return false                                     # the title card and the opening's words go first
	if in_fight() and not kind in [&"boss_emote", &"lesson", &"narration"]:
		return false
	if kind == &"discovery" and in_combat():
		return false                                     # the carved banner waits for the fight to end
	if lane == &"sub" and _tip_cool > 0.0 and kind != &"lesson":
		return false                                     # the last lesson is still fading out
	for k: StringName in _occ:
		var kp := _pri(k)
		if kp > p:
			return false                                 # a higher post is up, anywhere: this one waits
		if kp == p and _lane(k) == lane:
			return false
	return true


## `kind` starts now (owner checked can_begin, or `force`: it draws regardless, e.g. a boss's emote).
## `seconds` is its whole life, fades included; `rect` where it draws (default: its lane).
func begin(kind: StringName, seconds: float, rect := Rect2(), force := false) -> bool:
	if not force and not can_begin(kind):
		return false
	var lane := _lane(kind)
	for k: StringName in _occ.keys():
		if k != kind and _lane(k) == lane and _pri(k) < _pri(kind):
			_occ.erase(k)
			if k == &"lesson":
				_lesson_bumped()
			bumped.emit(k)
	_occ[kind] = {"until": _clock + seconds, "rect": rect if rect.size != Vector2.ZERO else lane_rect(lane)}
	if kind == &"discovery":
		_last_discovery = _clock
		banner_log.append(_clock)
	return true


func end(kind: StringName) -> void:
	_occ.erase(kind)


## One discovery banner per DISCOVERY_GAP seconds. When this says no, call quiet() instead.
func discovery_ok() -> bool:
	return _clock - _last_discovery >= DISCOVERY_GAP


## The banner lane is in use: the objective tracker steps aside.
func banner_up() -> bool:
	return lane_busy(&"banner")


## Every rectangle that is drawing now: [{kind, rect}]. Two of these must never intersect.
func drawn() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: StringName in _occ:
		if k != &"lesson":                                # the lesson is its label, below
			out.append({"kind": k, "rect": _occ[k].rect})
	var up := 0
	for t in _toasts:
		if is_instance_valid(t):
			up += 1
	if up > 0:                                            # the stack is one rectangle: the toast lane
		out.append({"kind": &"toast", "rect": lane_rect(&"toast"), "count": up})
	if _tip and _tip_t > 0.0 and _tip.text != "":
		out.append({"kind": &"lesson", "rect": _tip_rect()})
	return out


## Names of two kinds that draw over each other right now ("" when none).
func overlap() -> String:
	var d := drawn()
	for i in d.size():
		for j in range(i + 1, d.size()):
			if (d[i].rect as Rect2).intersects(d[j].rect):
				return "%s over %s" % [d[i].kind, d[j].kind]
	return ""


# --- managed lines -----------------------------------------------------------------------------------

## Build the labels under the HUD's root (before anything else is added there).
func build(root: Control, title_font: Font) -> void:
	_root = root
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_toast_box.offset_left = 28
	_toast_box.offset_right = 308
	_toast_box.offset_top = -330
	_toast_box.offset_bottom = -130
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override("separation", 8)
	root.add_child(_toast_box)
	_tip = _make_label(24, Color(0.95, 0.91, 0.82), UIType.body())
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tip.offset_left = -480
	_tip.offset_right = 480
	_tip.offset_top = -TIP_UP - 94.0                 # three lines tall, text sits on the bottom edge: it grows upward, never onto the prompt
	_tip.offset_bottom = -TIP_UP + 36
	_tip.modulate.a = 0.0
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_stylebox_override("normal", backing(24, 10))
	root.add_child(_tip)
	_keys_plate = PanelContainer.new()
	_keys_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_plate.add_theme_stylebox_override("panel", backing(22, 7))
	_keys_plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_keys_plate.offset_left = 0.0
	_keys_plate.offset_right = 0.0
	_keys_plate.offset_top = -TIP_UP + 36.0
	_keys_plate.offset_bottom = -TIP_UP + 36.0
	_keys_plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_keys_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keys_plate.visible = false
	root.add_child(_keys_plate)


func _make_label(base: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	scaled(l, base)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func post_toast(text: String) -> void:
	_enqueue_toast(sentence(text), &"toast")


## A small quiet line in the corner (a discovery past its rate limit; the Journal has it anyway).
func quiet(text: String) -> void:
	_enqueue_toast(text, &"quiet")


func _enqueue_toast(text: String, kind: StringName) -> void:
	if text == "":
		return
	for l in _toasts:
		if is_instance_valid(l) and l.text == text:
			return
	for q in _toast_q:
		if q.text == text:
			return
	if _toast_q.size() >= 6:
		var drop := -1
		for i in _toast_q.size():
			if _toast_q[i].kind == &"quiet":
				drop = i
				break
		if drop < 0:
			if kind == &"quiet":
				return                   # a quiet line never pushes a real one out (the Journal has it anyway)
			drop = 0                     # a real toast replaces the oldest waiting one: it has waited longest and is the stalest
		_toast_q.remove_at(drop)
	_toast_q.append({"text": text, "kind": kind})


## `basic`: the line teaches a control (move, jump, slide): it is dropped when a fight starts, see retire_basic().
func post_lesson(text: String, basic := false) -> void:
	text = sentence(text)
	if _lesson_q.size() < 4 and not _lesson_q.has(text) and _tip_raw != text:
		_lesson_q.append(text)
		if basic:
			_lesson_basic.append(text)


## A fight has begun: the queued control lessons are forgotten and one on screen fades at once.
func retire_basic() -> void:
	for t in _lesson_basic:
		_lesson_q.erase(t)
	if _tip_t > 0.0 and _lesson_basic.has(_tip_raw):
		_tip_t = 0.01
	_lesson_basic.clear()


func queued() -> int:
	return _toast_q.size() + _lesson_q.size()


# --- frame -------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	tick(delta)


## The director's whole frame (tests call it with a synthetic delta).
func tick(delta: float) -> void:
	_clock += delta
	for k: StringName in _occ.keys():
		if float(_occ[k].until) <= _clock:
			_occ.erase(k)
	_poll -= delta
	if _poll <= 0.0 and is_inside_tree():
		_poll = 0.15
		_poll_world()
	_toast_tick(delta)
	_lesson_tick(delta)


func _poll_world() -> void:
	var tree := get_tree()
	var dlg := tree.get_first_node_in_group(&"dialogue")
	_dialogue_open = dlg != null and dlg.has_method("is_open") and bool(dlg.call("is_open"))
	var p := tree.get_first_node_in_group(Groups.PLAYER)
	_locked = p != null and p.has_method("lock_target") and p.call("lock_target") != null
	var pl := p as Player
	var st := pl.stamina() as Stamina if pl != null else null
	_engaged = st != null and st.in_fight()
	# a boss's emote is drawn by its arena; seeing it, the director records it so lower lines wait
	for a in tree.get_nodes_in_group(&"boss_arena"):
		var e: Variant = a.get("last_emote")
		if e is String and e != "" and e != _emote_seen:
			_emote_seen = e
			begin(&"boss_emote", 5.0, Rect2(_vs().x * 0.5 - 450.0, 168.0, 900.0, 60.0), true)


func _toast_tick(delta: float) -> void:
	if _toast_box == null:
		return
	for l in _toasts.duplicate():
		if not is_instance_valid(l):
			_toasts.erase(l)
			continue
		var life: float = float(l.get_meta(&"life")) - delta
		l.set_meta(&"life", life)
		if life < 0.0:
			_toasts.erase(l)
			l.queue_free()
		elif life < 0.7:
			l.modulate.a = clampf(life / 0.7, 0.0, 1.0)
	if _toast_q.is_empty() or _toasts.size() >= MAX_TOASTS or not can_begin(&"toast"):
		return
	var item: Dictionary = _toast_q.pop_front()
	var quiet_line: bool = item.kind == &"quiet"
	var l := _make_label(17 if quiet_line else 22, Color(0.78, 0.74, 0.66, 0.85) if quiet_line else Color(0.96, 0.92, 0.82), UIType.body())
	l.add_theme_stylebox_override("normal", backing(16, 8))
	l.text = String(item.text)
	l.set_meta(&"life", TOAST_HOLD * (0.8 if quiet_line else 1.0) + (0.0 if _toast_q.is_empty() else -1.0))
	l.custom_minimum_size = Vector2(280, 0)
	l.modulate.a = 0.0
	_toast_box.add_child(l)
	_toasts.append(l)
	create_tween().tween_property(l, "modulate:a", 1.0, 0.25)


func _lesson_tick(delta: float) -> void:
	if _tip == null:
		return
	if _keys_plate.visible:
		_keys_plate.modulate.a = _tip.modulate.a
	if _tip_t > 0.0:
		_tip_t -= delta
		if _tip_t <= 0.0:
			end(&"lesson")
			_tip_fade(0.0, 0.6)
			_tip_cool = 0.7
		return
	if _tip_cool > 0.0:
		_tip_cool -= delta
		return
	if _lesson_q.is_empty() or not can_begin(&"lesson"):
		return
	_tip_raw = _lesson_q.pop_front()
	var keyed := KeyCap.has_tokens(_tip_raw)
	_tip.text = KeyCap.plain(_tip_raw, bool(Settings.using_pad)) if keyed else _tip_raw
	_tip_aside = plate_low(_tip, _tip.text, 960.0, -TIP_UP + 36.0)
	_tip.self_modulate.a = 0.0 if keyed else 1.0          # a keyed lesson keeps the label (its rect, its words for tests) unseen
	_set_keys(_tip_raw if keyed else "")
	_tip_t = 5.6
	begin(&"lesson", 8.0, _tip_rect())
	_tip_fade(1.0, 0.35)


## The lesson's fade, one at a time: a bump kills it, so a fade-in cut short by narration does not carry on under it.
var _tip_tw: Tween


func _tip_fade(to: float, secs: float) -> void:
	if _tip_tw != null and _tip_tw.is_valid():
		_tip_tw.kill()
	_tip_tw = create_tween()
	_tip_tw.tween_property(_tip, "modulate:a", to, secs)


## Narration took the lane: the lesson fades and goes back to the head of its queue.
func _lesson_bumped() -> void:
	if _tip_tw != null and _tip_tw.is_valid():
		_tip_tw.kill()
	if _tip_t > 0.0 and _tip_raw != "":
		_lesson_q.push_front(_tip_raw)
	_tip_t = 0.0
	_tip_cool = 0.0
	_tip.modulate.a = 0.0
	_keys_plate.modulate.a = 0.0


## The caps row for a keyed lesson ("" clears it).
func _set_keys(raw: String) -> void:
	for c in _keys_plate.get_children():
		c.queue_free()
	_keys_plate.visible = raw != ""
	if raw == "":
		return
	_keys_plate.add_child(KeyCap.line(raw, bool(Settings.using_pad), float(px(36)), px(23)))
	_keys_plate.modulate.a = _tip.modulate.a
	_centre_keys()
	_centre_keys.call_deferred()            # again once the row has its fonts measured


## Size the caps' plate to its row and centre it over the lesson's foot (a container left to grow only grew right).
func _centre_keys() -> void:
	var ms := _keys_plate.get_combined_minimum_size()
	_keys_plate.offset_left = -ms.x * 0.5
	_keys_plate.offset_right = ms.x * 0.5
	_keys_plate.offset_bottom = -TIP_UP + 36.0
	_keys_plate.offset_top = -TIP_UP + 36.0 - ms.y


func _tip_rect() -> Rect2:
	var v := _vs()
	if _tip_aside and _tip != null:
		return Rect2(v.x * 0.5 + _tip.offset_left, v.y + _tip.offset_top, _tip.offset_right - _tip.offset_left, _tip.offset_bottom - _tip.offset_top)
	return Rect2(v.x * 0.5 - 480.0, v.y - TIP_UP - 94.0, 960.0, 130.0)


## A lesson is on screen or queued (the guided opening waits for the move prompt's turn before it speaks on).
func lesson_busy() -> bool:
	return _tip_t > 0.0 or not _lesson_q.is_empty()


## True while a lesson is on screen or waiting (tests).
func lesson_text() -> String:
	return _tip.text if _tip and _tip_t > 0.0 else ""


## Tests drive these directly.
func test_set(dialogue_open: bool, locked: bool) -> void:
	_dialogue_open = dialogue_open
	_locked = locked
	_poll = 1.0e9
