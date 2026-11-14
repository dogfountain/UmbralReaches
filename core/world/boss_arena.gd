class_name BossArena
extends Node3D
## The sanctum of a holy place. Walk in (within `radius`, under `ceiling`) and, if its boss is not
## yet slain and its requirements are met, the gate behind you closes, the boss rises, and a bar
## shows at the top of the screen. Kill it and the gate opens, the reward appears, and the victory
## persists (Travel.bosses_slain). Fall (hollowed) and the arena resets: boss gone, gate open.

const BossThemes := preload("res://core/life/wildlife/boss_themes.gd")

@export var boss_id := ""
@export var title := "Boss"
@export var radius := 7.0
@export var ceiling := 6.0
@export var requires_bosses: Array[String] = []
## r36 Act II: the Founder's bells answered for before the fight wakes (the Ascended Warden).
@export var requires_bells := 0
@export var subtitle := ""
@export var max_rise := 1.6             ## audit: how much the floor may step (tiered arenas allow more)
## The bar's name from a phase on (phase -> name): the Warden's bar names him at phase III.
var phase_titles: Dictionary = {}
## When the wardens' bosses are missing, what each one is called in the "Nothing answers" line.
const HOLDS := {"thornwarden": "The Ring's heart", "bone_abbot": "The crypt's crown"}
const LEAVE := 6.0          ## run this far past the edge and the fight is held (r35: it used to reset)
const WARM_STAGES := 5     ## BossKit.warm slices (the rig follows as the last step)
const WARM_GAP := 0.25      ## seconds between warm steps
const GATE_CLEAR := 1.5     ## metres past the gate line before the fight starts and the gate closes

var boss_script: GDScript
var boss_at := Vector3.ZERO
var gate: Node3D = null                 ## optional barrier that closes during the fight (its line is tested)
var gates: Array[Node3D] = []           ## further arena-mouth barriers shut with it (r30: the Ossuary chapel arch)
var on_slain: Callable                  ## reward spawner, called once (also on load if slain)
## r34 raids: the room the fight changes (core/world/henge_raid.gd, summit_raid.gd). Optional methods:
## room_begin(boss) on the pull, room_reset() on a wipe, room_won() on the kill (r35: a walk-out holds the room frozen).
var room: Node = null
var last_emote := ""                    ## the last raid-warning line shown (tests read it)
var _emote_lbl: Label
var _emote_layer: CanvasLayer           ## its own layer: the r33 unit frames hide the bar layer, not this
var intro_turn := false                ## BossFrame: he rises with his back to the wanderer and turns to him inside the title's time
var frame_look := 0.7                  ## BossFrame: the share of his height the intro view aims at (higher seats him lower, under the name card)
var _emote_t := 0.0
var _emote_wait: Array = []             ## [text, colour] held back while the title card is up

var _boss: Enemy
var _active := false
var _bar_layer: CanvasLayer
var _bar: BossBar
var _bar_name: Label
var _phase_seen := 1


## The boss bar: crimson fill, a pale trail that lags behind it so each chunk you take stays
## readable, notches where the boss changes phase, and a flash when it does.
class BossBar extends Control:
	var max_value := 1.0
	var value := 1.0
	var marks: Array[float] = []        ## hp ratios where a phase begins
	var _trail := 1.0
	var _hold := 0.0
	var _flash := 0.0
	var _last := 1.0

	func phase_flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		var r := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
		if r < _last - 0.0001:
			_hold = 0.35
		_last = r
		if _hold > 0.0:
			_hold -= delta
		else:
			_trail = move_toward(_trail, r, delta * 0.6)
		_trail = maxf(_trail, r)
		_flash = maxf(0.0, _flash - delta * 1.5)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
		draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.02, 0.07, 0.85))
		draw_rect(Rect2(0, 0, w * _trail, h), Color(1.0, 0.85, 0.75, 0.55))
		draw_rect(Rect2(0, 0, w * r, h), Color(0.7, 0.14, 0.22).lerp(Color(1.6, 0.9, 1.8), _flash))
		draw_rect(Rect2(0, 0, w * r, h * 0.3), Color(1.0, 0.45, 0.5, 0.35))
		for m in marks:
			var x := w * m
			draw_line(Vector2(x, -4), Vector2(x, h + 4), Color(0.95, 0.85, 1.0, 0.9), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, -6), Vector2(x + 5, -6), Vector2(x, 1)]), Color(0.95, 0.85, 1.0, 0.9))
		draw_rect(Rect2(0, 0, w, h), Color(0.5, 0.35, 0.7).lerp(Color(1.6, 1.0, 2.0), _flash), false, 1.0 + _flash * 2.0)
var _warned := false
var _warned_bells := -1
const QuestBookScript := preload("res://core/story/quest_book.gd")
var _cast_bar: CastBar
var _cast_lbl: Label


## r33: the boss's cast under its bar (Enemy.cast_info): the name, a fill, gold when it can be broken,
## pale grey with a shield edge when it cannot.
class CastBar extends Control:
	var progress := 0.0
	var interruptible := false
	var shown := false

	func _draw() -> void:
		if not shown:
			return
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.03, 0.05, 0.8))
		var col := Color(1.0, 0.72, 0.3) if interruptible else Color(0.62, 0.6, 0.66)
		draw_rect(Rect2(0, 0, w * clampf(progress, 0.0, 1.0), h), col)
		draw_rect(Rect2(0, 0, w, h), Color(0.95, 0.85, 0.6) if interruptible else Color(0.8, 0.8, 0.9), false, 1.0 if interruptible else 2.0)


static func make(host: Node3D, id: String, label: String, at: Vector3, r: float, script: GDScript, spawn_at: Vector3) -> BossArena:
	var a := BossArena.new()
	a.boss_id = id
	a.title = label
	a.radius = r
	a.boss_script = script
	a.boss_at = spawn_at
	a.name = "Arena_" + id
	host.add_child(a)
	a.global_position = at
	return a


func _ready() -> void:
	add_to_group(&"boss_arena")
	Events.hollowed.connect(_reset)
	Events.enemy_killed.connect(_on_killed)
	if Travel.bosses_slain.has(boss_id):
		call_deferred("_grant", false)


func slain() -> bool:
	return Travel.bosses_slain.has(boss_id)


func _physics_process(_d: float) -> void:
	if _active:
		_tick_emote(_d)
		if is_instance_valid(_boss):
			_tick_cast()
			if _bar:
				_bar.max_value = float(_boss.max_hp)
				_bar.value = _boss.hp
				var ph: Variant = _boss.get("phase")
				var lbl := String(_boss.get_meta(&"phase_label", ""))
				var warded := _boss is Enemy and BossKit.is_warded(_boss as Enemy)
				if _bar_name:
					_bar_name.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0) if warded else Color(0.92, 0.84, 1.0))
				if warded != bool(get_meta(&"_shown_ward", false)) and _bar_name:
					set_meta(&"_shown_ward", warded)
					set_meta(&"_shown_label", "?")            # forces the name to be rewritten below
				if lbl != String(get_meta(&"_shown_label", "")) and _bar_name:
					set_meta(&"_shown_label", lbl)        # r34: an intermission names itself on the bar
					_bar.phase_flash()
					_bar_name.text = "%s  ·  %s%s" % [_named().to_upper(), lbl if lbl != "" else ["", "I", "II", "III", "IV"][clampi(_phase_seen, 0, 4)], _ward_tag(warded)]
				if ph is int and int(ph) != _phase_seen:
					_phase_seen = int(ph)
					_bar.phase_flash()
					if _bar_name and lbl == "":
						_bar_name.text = "%s  ·  %s" % [_named().to_upper(), ["", "I", "II", "III", "IV"][clampi(_phase_seen, 0, 4)]]
			# the boss keeps to its sanctum: drawn back inside the ring if it strays out
			var bd := _boss.global_position - global_position
			var flat := Vector2(bd.x, bd.z)
			if flat.length() > radius + 0.5:
				var back := flat.normalized() * (radius - 0.5)
				_boss.global_position = Vector3(global_position.x + back.x, _boss.global_position.y, global_position.z + back.y)
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if pl:
			var pd := pl.global_position - global_position
			if Vector2(pd.x, pd.z).length() > radius + LEAVE or pd.y < -6.0:
				_hold_fight()                    # r35: a walk-out pauses the fight; it no longer resets it
		return
	if slain():
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	var d := p.global_position - global_position
	if not _warmed and Vector2(d.x, d.z).length() < radius + 24.0 and absf(d.y) < ceiling + 8.0:
		_warmed = true                          # first-use costs of the boss's moves, paid while it is quiet
		var themes := get_tree().get_first_node_in_group(&"boss_themes") as BossThemes
		if themes != null:
			themes.prepare(boss_id)             # the theme's stems read or rendered on a thread, not at the pull
		_warm_step(0)
	if Vector2(d.x, d.z).length() > radius or d.y < -1.0 or d.y > ceiling:
		return
	if not _past_gate(p.global_position):
		return                                  # still on the stair outside: the gate must not shut in your face
	for b in requires_bosses:
		if not Travel.bosses_slain.has(b):
			if not _warned:
				_warned = true
				Events.toast.emit(nothing_answers(requires_bosses))
			return
	if requires_bells > 0:
		var rung := QuestBookScript.bells()
		if not QuestBookScript.peal_open(requires_bells):
			if not _warned or rung != _warned_bells:      # a bell answered while away lets the door speak again
				_warned = true
				_warned_bells = rung
				Events.toast.emit(no_peal(rung, requires_bells))
			return
	_begin()


## The boss's first-use costs, one slice per step a quarter second apart (BossKit.warm stages 0..4,
## then the rig), so the approach never takes them all in one frame.
func _warm_step(i: int) -> void:
	if not is_inside_tree() or slain():
		return
	var t0 := Time.get_ticks_usec()
	if i < WARM_STAGES:
		BossKit.warm(self, i, StringName(boss_id))
	elif boss_script != null:
		BossKit.warm_rig(get_parent(), boss_script)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	if ms > 4.0:
		print("BOSSWARM %s step %d %.1f ms" % [boss_id, i, ms])
	if i < WARM_STAGES:
		get_tree().create_timer(WARM_GAP, false).timeout.connect(_warm_step.bind(i + 1))


func _named() -> String:
	var named := title
	for k: int in phase_titles:
		if _phase_seen >= k:
			named = String(phase_titles[k])
	return named


## r34 raids: the boss's emote line (BossKit.emote): large, warm, under the cast bar, for 5 s.
func emote(text: String, col := Color(1.0, 0.82, 0.45)) -> void:
	# one message at a time: while the name card is up the line waits, and plays after it has faded
	if get_node_or_null("BossTitle") != null:
		_emote_wait = [text, col]
		return
	last_emote = text
	if _emote_lbl == null or not is_instance_valid(_emote_lbl):
		Events.toast.emit(text)
		return
	_emote_lbl.text = text
	_emote_lbl.add_theme_color_override("font_color", col)
	_emote_lbl.modulate.a = 1.0
	_emote_t = 5.0


func _tick_emote(d: float) -> void:
	if not _emote_wait.is_empty() and get_node_or_null("BossTitle") == null:
		var w := _emote_wait
		_emote_wait = []
		emote(String(w[0]), w[1] as Color)
	if _emote_t <= 0.0 or _emote_lbl == null or not is_instance_valid(_emote_lbl):
		return
	_emote_t -= d
	_emote_lbl.modulate.a = clampf(_emote_t / 1.2, 0.0, 1.0)


## True once the wanderer is through the gate, on the arena's side of its line. A stair or ramp that
## curls round the outside can run inside `radius` (the henge's slantwise pilgrim stair did, 1-2 m
## below the terrace lip): starting the fight there closed the seal ahead of them and locked them out.
## Only a gate on the arena's rim is a line to cross; one far off (an outer door) is not tested.
func _past_gate(at: Vector3) -> bool:
	if gate == null or not is_instance_valid(gate):
		return true
	var g := gate.global_position
	var inward := global_position - g
	inward.y = 0.0
	if inward.length() < 0.5 or inward.length() > radius + 2.0:
		return true
	var rel := at - g
	rel.y = 0.0
	return rel.dot(inward.normalized()) > GATE_CLEAR


## "Nothing answers. The crypt's crown still holds below.": names what is still missing.
## r36: the summit door waits for a peal of the Founder's bells.
static func no_peal(rung: int, need: int) -> String:
	if rung == 0:
		return "Nothing answers. The door was hung to a bell, and no bell rings below."
	if rung >= need:
		return "Nothing answers. The door hears %d of the Founder's bells, and not the one cast for the country the Order shut out. It wants that one." % rung
	return "Nothing answers. The door hears %d of the Founder's bells. It wants %d, and the Marches' among them." % [rung, need]


static func nothing_answers(req: Array) -> String:
	var missing: Array[String] = []
	for b in req:
		if not Travel.bosses_slain.has(String(b)):
			missing.append(String(HOLDS.get(String(b), "A seal")))
	if missing.is_empty():
		return "Nothing answers."
	if missing.size() == 1:
		return "Nothing answers. %s still holds below." % missing[0]
	return "Nothing answers. %s and %s still hold below." % [", ".join(missing.slice(0, missing.size() - 1)), missing[missing.size() - 1].to_lower()]


func _begin() -> void:
	if boss_script == null:
		return
	if _held and is_instance_valid(_boss):
		_resume_fight()
		return
	_active = true
	_boss = boss_script.new() as Enemy
	get_parent().add_child(_boss)
	_boss.global_position = boss_at
	_boss.set_meta(&"boss_id", boss_id)
	_boss.set_meta(&"display_name", title)      # r33: Enemy.display_name() for the HUD
	for g in _all_gates():
		if g.has_method("close"):
			g.call("close")
	_show_bar()
	BossTitle.show_for(self, title, subtitle)       # first: the boss's own emote (on_engaged) waits for the card to fade
	if room != null and is_instance_valid(room) and room.has_method("room_begin"):
		room.call("room_begin", _boss)
	if _boss.has_method("on_engaged"):
		_boss.call("on_engaged", self)
	Events.boss_engaged.emit(_boss, title)
	# the boss's name is a title in the encounter HUD's voice (BossTitle) and the view turns to him
	# (BossFrame) for the beat he rises; the hud's zone card waited out the fight and then drew late
	BossFrame.start(self, _boss, frame_look, intro_turn)
	Sfx.play("res://art/audio/ward_chime.wav", boss_at, 4.0)
	SpellFx.rift_in(boss_at)


func _on_killed(e: Node) -> void:
	if not _active or e != _boss:
		return
	_active = false
	_hide_bar()
	_open_gates()
	if room != null and is_instance_valid(room) and room.has_method("room_won"):
		room.call("room_won")
	Events.boss_slain.emit(boss_id)
	if boss_id != "ascended_warden":         # the Warden's fall is the story's beat (story.gd), not a toast
		Events.toast.emit("%s falls." % title)
	_grant(true)


func _grant(fresh: bool) -> void:
	if on_slain.is_valid():
		on_slain.call(fresh)


func _reset() -> void:
	if not _active and not _held:
		return
	_active = false
	_held = false
	_warned = false
	_freeze(false)
	if is_instance_valid(_boss):
		_boss.queue_free()
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"summoned_by") and (e as Node).get_meta(&"summoned_by") == boss_id:
			(e as Node).queue_free()             # its summons go with it
	_hide_bar()
	_open_gates()
	if room != null and is_instance_valid(room) and room.has_method("room_reset"):
		room.call("room_reset")


# --- r35: a fight is never reset mid-way ---------------------------------------------------------
# Walking (or falling) out of the arena used to free the boss and bring a fresh one, at full health,
# on the next pull. Now the fight is held as it stands: the boss, its adds and the room are frozen,
# the gates open, the bar goes away, and the dark gathers on you again out there. Coming back in
# resumes it where it was. Only being hollowed resets a fight (Events.hollowed -> _reset).

var _warmed := false                   ## BossKit.warm has run for this arena
var _held := false                     ## walked out mid-fight: boss, adds and room frozen as they were
var _held_modes: Dictionary = {}       ## node instance id -> its process_mode before the hold


func is_held() -> bool:
	return _held


func _hold_fight() -> void:
	if not _active:
		return
	_active = false
	_held = true
	_freeze(true)
	_hide_bar()
	_open_gates()
	Events.toast.emit("%s waits where you left it." % title)


func _resume_fight() -> void:
	_held = false
	_active = true
	_freeze(false)
	for g in _all_gates():
		if g.has_method("close"):
			g.call("close")
	_show_bar()
	Events.toast.emit("%s turns to you again." % title)


## Freeze (or thaw) the boss, everything it summoned, and its room.
func _freeze(on: bool) -> void:
	var nodes: Array[Node] = []
	if is_instance_valid(_boss):
		nodes.append(_boss)
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"summoned_by") and (e as Node).get_meta(&"summoned_by") == boss_id:
			nodes.append(e)
	if room != null and is_instance_valid(room):
		nodes.append(room)
	for n in nodes:
		var id := n.get_instance_id()
		if on:
			if not _held_modes.has(id):
				_held_modes[id] = n.process_mode
			n.process_mode = Node.PROCESS_MODE_DISABLED
		elif _held_modes.has(id):
			n.process_mode = int(_held_modes[id]) as Node.ProcessMode
	if not on:
		_held_modes.clear()


func _all_gates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if gate and is_instance_valid(gate):
		out.append(gate)
	for g in gates:
		if is_instance_valid(g) and not out.has(g):
			out.append(g)
	return out


## Arena gates lift; a progression seal used as a gate goes back to its own state (WardSeal.reopen),
## it is never forced open by a reset.
func _open_gates() -> void:
	for g in _all_gates():
		if g.has_method("reopen"):
			g.call("reopen")
		elif g.has_method("release"):
			g.call("release")


## The bar's lock state while the boss turns every blow: what to do instead, when it says.
func _ward_tag(warded: bool) -> String:
	if not warded:
		return ""
	var hint := String(_boss.get_meta(&"ward_hint", ""))
	return "   [WARDED: %s]" % hint.to_upper() if hint != "" else "   [WARDED]"


func _show_bar() -> void:
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 40
	add_child(_bar_layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-320, 36)
	box.custom_minimum_size = Vector2(640, 0)
	_bar_layer.add_child(box)
	_bar_name = Label.new()
	_bar_name.text = title.to_upper()
	_bar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_name.add_theme_color_override("font_color", Color(0.92, 0.84, 1.0))
	_bar_name.add_theme_font_size_override("font_size", 22)
	box.add_child(_bar_name)
	_bar = BossBar.new()
	_bar.custom_minimum_size = Vector2(640, 14)
	_bar.max_value = float(_boss.max_hp)
	_bar.value = _boss.hp
	if _boss.has_method("phase_marks"):
		for m: float in _boss.call("phase_marks"):
			_bar.marks.append(m)
	_phase_seen = 1
	box.add_child(_bar)
	_cast_lbl = Label.new()
	_cast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_lbl.add_theme_font_size_override("font_size", 16)
	_cast_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	box.add_child(_cast_lbl)
	_cast_bar = CastBar.new()
	_cast_bar.custom_minimum_size = Vector2(360, 8)
	_cast_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_cast_bar)
	# r34: the raid-warning line (BossKit.emote), WoW's boss emote: big, warm, fading; on its own layer
	# under the boss frame (the r33 unit frames hide _bar_layer and draw their own boss plate)
	_emote_layer = CanvasLayer.new()
	_emote_layer.layer = 41
	add_child(_emote_layer)
	_emote_lbl = Label.new()
	_emote_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_emote_lbl.position = Vector2(-450, 190)   # its own band: under the bar, over the name card's row (the card has faded by then), above where his head may rise (BossFrame.TOP_LIMIT)
	_emote_lbl.size = Vector2(900, 60)
	_emote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_emote_lbl.custom_minimum_size = Vector2(900, 0)
	_emote_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emote_lbl.add_theme_font_size_override("font_size", 21)
	_emote_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02, 0.9))
	_emote_lbl.add_theme_constant_override("outline_size", 6)
	_emote_lbl.text = " "
	_emote_lbl.modulate.a = 0.0
	_emote_layer.add_child(_emote_lbl)
	if has_meta(&"_shown_label"):
		remove_meta(&"_shown_label")


func _tick_cast() -> void:
	if _cast_bar == null or not is_instance_valid(_cast_bar):
		return
	var c := _boss.cast_info()
	_cast_bar.shown = not c.is_empty()
	if _cast_bar.shown:
		_cast_bar.progress = float(c.progress)
		_cast_bar.interruptible = bool(c.interruptible)
		_cast_lbl.text = String(c.name) + ("" if bool(c.interruptible) else "  (cannot be broken)")
		_cast_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55) if bool(c.interruptible) else Color(0.82, 0.8, 0.88))
	else:
		_cast_lbl.text = " "
	_cast_bar.queue_redraw()


func _hide_bar() -> void:
	if is_instance_valid(_bar_layer):
		_bar_layer.queue_free()
	_bar_layer = null
	if is_instance_valid(_emote_layer):
		_emote_layer.queue_free()
	_emote_layer = null
	_emote_lbl = null
	_emote_t = 0.0


## Audit hook: the arena floor must be walkable and flat enough, the boss spawn clear.
func audit() -> Array[String]:
	var out: Array[String] = []
	var space := get_world_3d().direct_space_state
	var lo := INF
	var hi := -INF
	for i in 12:
		var a := TAU * float(i) / 12.0
		for rr: float in [0.0, radius * 0.5, radius * 0.85]:
			var p := global_position + Vector3(cos(a) * rr, 0, sin(a) * rr)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 4.0, Layers.WORLD))
			if hit.is_empty():
				out.append("%s: no floor at %s" % [boss_id, p.snapped(Vector3.ONE * 0.1)])
				continue
			lo = minf(lo, (hit.position as Vector3).y)
			hi = maxf(hi, (hit.position as Vector3).y)
	if hi - lo > max_rise:
		out.append("%s: floor varies %.2f m" % [boss_id, hi - lo])
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 3.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, boss_at + Vector3.UP * 1.7)
	q.collision_mask = Layers.WORLD | Layers.PROPS
	if not space.intersect_shape(q, 1).is_empty():
		out.append("%s: boss spawn %s is inside geometry" % [boss_id, boss_at.snapped(Vector3.ONE * 0.1)])
	return out
