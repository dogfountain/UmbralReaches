extends Node
## The play bot's head: what to do each physics tick, and every input it sends. Input actions only (move,
## sprint, jump, interact, the spell keys, the menu keys) and view turns as mouse motion (or the look stick when
## the mouse is not captured). It READS the world (map pins, the objective line, enemies, fires) to decide where
## to walk; it never moves the wanderer or edits state. See zz/play_bot.gd.
const Chains := preload("res://core/story/quest_chains.gd")
const Book := preload("res://core/story/quest_book.gd")
const QuestDB := preload("res://core/story/quest_db.gd")
const Giver := preload("res://core/story/quest_giver.gd")

const LATE_S := 1500.0                     ## after this much play the story's own objective comes before side tasks
const MENUS := [["world_map", "map"], ["inventory", "satchel"], ["kindling", "kindling"], ["quest_log", "quest_log"], ["codex", "journal"], ["gear", "gear"]]

var host: Node
var p: Player
var rec: RefCounted
var minutes: float
var running := false
var activity := "idle"
var game_t := 0.0
var use_mouse := true
var _held: Dictionary = {}
var _pulse: Dictionary = {}                # action -> seconds until its release
var _boot_t := 3.0

# --- goal
var goal := {}                              # {pos, kind, label, key}
var _goal_t := 0.0
var _black: Dictionary = {}                 # goal key -> game time until which it is skipped
var _path := PackedVector3Array()
var _path_t := 0.0
var _path_goal := Vector3.INF
var _no_path_logged: Dictionary = {}
var _interacts := 0                         # interact taps made at the current goal
var _goal_arrived_t := 0.0
var _goal_started := 0.0

# --- stuck / falls
var _prog_pos := Vector3.INF
var _prog_t := 0.0
var _stuck_stage := 0
var _stuck_dir := 0.0
var _stuck_spots: Array[Vector2] = []
var _last_y := 0.0
var _fell_logged := 0.0
var _random_t := 0.0

# --- fight
var _foe: Node3D
var _fight_t := 0.0
var _fight_hp := 0.0
var _fight_prog_t := 0.0
var _ignore: Dictionary = {}
var _cd: Dictionary = {}
var _strafe := 1.0
var _strafe_t := 0.0
var _strip: Array = []
var _strip_t := 0.0
var _strip_n := 0
var _fights := 0
var _kills := 0
var _deaths := 0
var _boss_deaths := 0
var _dealt: Dictionary = {}                 # foe name -> [hits, damage, hits that did 0], this fight

# --- misc
var _menu_i := 0
var _menu_next := 80.0
var _menu_state := ""
var _menu_t := 0.0
var _shot_next := 60.0
var _pin_t := 0.0
var _pin_seen: Dictionary = {}
var _prompts: Dictionary = {}
var _paused_t := 0.0
var _fire_visited: Dictionary = {}
var _rest_until := 0.0
var _dist_walked := 0.0
var _last_pos := Vector3.ZERO
var _tasks_seen: Dictionary = {}
var _accepted := 0
var _handed := 0
var _toasts: Dictionary = {}
var _was_talking := false
var _shop_t := 0.0
var _asked: Dictionary = {}                 # choice lines taken in the talk now open (so a hub is not looped)
var _last_area := ""


func _init(h: Node, pl: Player, r: RefCounted, mins: float) -> void:
	host = h
	p = pl
	rec = r
	minutes = mins
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "PlayBotBrain"


func _ready() -> void:
	_last_pos = p.global_position
	rec.pos = p.global_position
	use_mouse = host.headless or "--mouse" in OS.get_cmdline_user_args()
	if use_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		use_mouse = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED         # a headless display cannot capture
	if use_mouse:
		rec.note("INPUT", "mouse look (captured)")
	else:
		_pad_like()
		rec.note("INPUT", "look stick (a pad player): the mouse is not captured here")
	Events.hollowed.connect(func() -> void:
		_deaths += 1
		if _foe != null and is_instance_valid(_foe) and _foe.has_meta(&"boss_id"):
			_boss_deaths += 1
			if _boss_deaths % 3 == 0:
				_black["main:" + String(_foe.get_meta(&"boss_id"))] = game_t + 600.0
				rec.note("PLAN", "three deaths to %s: leaving it for ten minutes" % String(_foe.get_meta(&"boss_id")))
		rec.problem("DIED", "hollowed (death %d) near %s, gloom %.0f wounds %.0f" % [_deaths, _where(), p.gloom, p.wounds]))
	Events.respawned.connect(func(at: Vector3) -> void: rec.note("RESPAWN", "at (%.0f, %.0f, %.0f)" % [at.x, at.y, at.z]))
	Events.enemy_killed.connect(func(_e: Node) -> void: _kills += 1)
	Events.quest_changed.connect(_on_quest)
	Events.interact_hint.connect(_on_prompt)
	Events.toast.connect(_on_toast)
	Events.zone_entered.connect(func(t: String, s: String) -> void: rec.note("ZONE", "%s | %s" % [t, s]))
	Events.skill_failed.connect(func(id: StringName, why: String) -> void: _count("SKILL_FAILED %s: %s" % [id, why]))
	Events.seal_broken.connect(func(id: String) -> void: rec.note("SEAL", "broken " + id))
	Events.brazier_kindled.connect(func(b: Node3D) -> void: rec.note("FIRE", "kindled " + String(b.name)))
	Events.boss_slain.connect(func(id: String) -> void: rec.note("BOSS", "slain " + id))
	Events.combat_damage.connect(func(t: Node, amount: float, _c: bool, _sc: StringName, _at: Vector3) -> void:
		if t is Enemy:
			var k := String(t.name)
			var d: Array = _dealt.get(k, [0, 0.0, 0])
			d[0] += 1
			d[1] += amount
			if amount <= 0.0:
				d[2] += 1
			_dealt[k] = d)
	Events.boss_engaged.connect(func(_b: Node, t: String) -> void: rec.note("BOSS", "engaged " + t))


func _dump_pins() -> void:
	for m in get_tree().get_nodes_in_group(&"map_marker"):
		if is_instance_valid(m) and m is Node3D and String(m.get_meta("map_kind", "")).begins_with("quest"):
			var at := (m as Node3D).global_position
			rec.note("PIN", "%s quest=%s '%s' at (%.0f, %.0f, %.0f) parent=%s" % [m.get_meta("map_kind"), m.get_meta("quest", ""), m.get_meta("map_label", ""), at.x, at.y, at.z, m.get_parent().name])


func _pad_like() -> void:
	## a joypad event flips the skill book to "pad": spells fire without a captured mouse
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_TRIGGER_RIGHT
	e.axis_value = 1.0
	Input.parse_input_event(e)
	var e2 := InputEventJoypadMotion.new()
	e2.axis = JOY_AXIS_TRIGGER_RIGHT
	e2.axis_value = 0.0
	Input.parse_input_event(e2)


func _where() -> String:
	return "(%.0f, %.0f)" % [p.global_position.x, p.global_position.z]


func _count(k: String) -> void:
	_toasts[k] = int(_toasts.get(k, 0)) + 1


func _on_quest(id: String, step: int, done: bool) -> void:
	rec.note("QUEST", "%s step %d%s" % [id, step, " DONE" if done else ""])
	if done:
		_handed += 1
	elif step == 0 and not _tasks_seen.has(id):
		_accepted += 1
	_tasks_seen[id] = step


func _on_toast(t: String) -> void:
	rec.note("TOAST", t)
	if t.contains("{") or t.contains("%") or t.contains("null") or t.contains("<") or t.strip_edges() == "":
		rec.problem("BAD_TEXT", "toast reads: " + t)


func _on_prompt(t: String) -> void:
	if t == "" or _prompts.has(t):
		return
	_prompts[t] = rec.clock()
	rec.note("PROMPT", t)
	if t.contains("{") or t.contains("%") or t.contains("null") or t.contains("<") or t.contains("None") or t.contains("_"):
		rec.problem("BAD_PROMPT", "prompt reads: " + t)


# --------------------------------------------------------------------------------------------------
# input

func act(a: StringName, on: bool, strength := 1.0) -> void:
	if bool(_held.get(a, false)) == on:
		return
	_held[a] = on
	var e := InputEventAction.new()
	e.action = a
	e.pressed = on
	e.strength = strength if on else 0.0
	Input.parse_input_event(e)


## press and let go after `secs` (a key tap)
func tap(a: StringName, secs := 0.1) -> void:
	act(a, true)
	_pulse[a] = secs


func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _pulses(dt: float) -> void:
	for a: StringName in _pulse.keys():
		_pulse[a] = float(_pulse[a]) - dt
		if float(_pulse[a]) <= 0.0:
			act(a, false)
			_pulse.erase(a)


func release_all() -> void:
	for a: StringName in _held.keys():
		if bool(_held[a]):
			act(a, false)


## Turn the view by `d` radians of yaw (positive = to the left, as the yaw turns): mouse motion, or the stick.
func turn(d: float) -> void:
	if use_mouse:
		var e := InputEventMouseMotion.new()
		var step := clampf(d * 0.35, -0.14, 0.14)
		e.relative = Vector2(-step / p.mouse_sensitivity, 0.0)
		e.position = Vector2(640, 400)
		Input.parse_input_event(e)
	else:
		if absf(d) < 0.03:
			act(&"look_left", false)
			act(&"look_right", false)
		elif d > 0.0:
			act(&"look_right", false)
			act(&"look_left", true, clampf(0.35 + absf(d), 0.0, 1.0))
		else:
			act(&"look_left", false)
			act(&"look_right", true, clampf(0.35 + absf(d), 0.0, 1.0))


func face(to: Vector3) -> float:
	var v := to - p.global_position
	var want := atan2(-v.x, -v.z)
	var err := angle_difference(p._yaw, want)
	turn(err)
	return err


# --------------------------------------------------------------------------------------------------
# the tick

func _physics_process(dt: float) -> void:
	if not is_instance_valid(p):
		return
	if not running:
		_boot_t -= dt
		if _boot_t <= 0.0:
			running = true
			Engine.time_scale = host.scale
			rec.note("START", "the bot is playing (time scale %.1f)" % host.scale)
			rec.shot("start")
			get_tree().create_timer(4.0).timeout.connect(_dump_pins)
		return
	game_t += dt
	if not TimeSlow.active() and not is_equal_approx(Engine.time_scale, host.scale):
		Engine.time_scale = host.scale         # TimeSlow (hitstop) hands the clock back at 1.0 each time
	rec.game_s = game_t
	rec.pos = p.global_position
	_pulses(dt)
	if game_t >= minutes * 60.0:
		rec.note("END", "game time reached")
		host._finish(0)
		running = false
		return
	_watch(dt)
	if _ui(dt):
		return
	if _menus(dt):
		return
	if _fight(dt):
		return
	_travel(dt)


# --------------------------------------------------------------------------------------------------
# watching: falls, frames, pins, periodic shots

func _watch(dt: float) -> void:
	var pos := p.global_position
	var flat := Vector3(pos.x - _last_pos.x, 0.0, pos.z - _last_pos.z).length()
	if flat < 3.0:
		_dist_walked += flat
	_last_pos = pos
	if int(game_t * 60.0) % 300 == 0 and game_t < 40.0:
		rec.note("DEBUG", "paused=%s vel=%s fwd=%s axis=%.2f yaw=%.2f act=%s mouse=%d" % [get_tree().paused, p.velocity, _held.get(&"move_forward"), Input.get_action_strength("move_forward"), p._yaw, activity, int(Input.mouse_mode)])
	if game_t >= _shot_next:
		_shot_next += 60.0
		rec.shot("t%03d_%s" % [int(game_t / 60.0), activity])
		rec.note("STATUS", "wall=%ds ts=%.1f act=%s goal=%s gloom=%.0f wounds=%.0f kills=%d walked=%.0fm tasks acc=%d done=%d" % [(Time.get_ticks_msec() - host.t_wall) / 1000, Engine.time_scale, activity, goal.get("label", "-"), p.gloom, p.wounds, _kills, _dist_walked, _accepted, _handed])
	# fall / off the world
	if pos.y < -45.0 and game_t - _fell_logged > 20.0:
		_fell_logged = game_t
		rec.problem("FELL_OFF_WORLD", "y=%.0f at %s, vy=%.0f" % [pos.y, _where(), p.velocity.y])
	_last_y = pos.y
	_pin_t -= dt
	if _pin_t <= 0.0:
		_pin_t = 3.0
		_audit_pins()
	if get_tree().paused:
		_paused_t += dt
	else:
		_paused_t = 0.0


## Every task the bot has taken should have a place on the map for its current step (a pin: group
## "map_marker" with meta quest = the task, or the giver's turn-in mark). Also the story spine.
func _audit_pins() -> void:
	var pins: Dictionary = {}
	for m in get_tree().get_nodes_in_group(&"map_marker"):
		if is_instance_valid(m) and m.has_meta("quest") and String(m.get_meta("quest")) != "":
			pins[String(m.get_meta("quest"))] = true
		elif is_instance_valid(m) and m.has_meta("map_label"):
			pins["label:" + String(m.get_meta("map_label")).split(":")[0]] = true      # a pickup's pin is labelled "<Task name>: <thing>"
	for id: String in Chains.ORDER:
		if not Book.active(id):
			continue
		var s := Book.step(id)
		var stp := Chains.step(id, s)
		var k := "%s:%d" % [id, s]
		if pins.has(id) or pins.has("label:" + String(Chains.QUESTS[id].name)) or _pin_seen.has(k):
			continue
		var kind := String(stp.get("kind", ""))
		if Book.ready(id):
			pass                           # waiting for the turn-in: the giver's mark is the pin
		_pin_seen[k] = true
		# a step that sends you somewhere (or to someone) must have a pin; give the world a moment to build it first
		get_tree().create_timer(5.0).timeout.connect(func() -> void:
			var again: Dictionary = {}
			for m2 in get_tree().get_nodes_in_group(&"map_marker"):
				if is_instance_valid(m2) and m2.has_meta("quest"):
					again[String(m2.get_meta("quest"))] = true
				elif is_instance_valid(m2) and m2.has_meta("map_label"):
					again["label:" + String(m2.get_meta("map_label")).split(":")[0]] = true
			if Book.active(id) and Book.step(id) == s and not again.has(id) and not again.has("label:" + String(Chains.QUESTS[id].name)):
				rec.problem("NO_MAP_PIN", "task '%s' step %d (%s: %s) has no map pin" % [id, s, kind, String(stp.get("text", ""))], false))


# --------------------------------------------------------------------------------------------------
# dialogue, offers, stray pauses

func _ui(dt: float) -> bool:
	var story := get_tree().get_first_node_in_group("story")
	var offer := get_tree().get_first_node_in_group("quest_offer")
	var talking: bool = story != null and is_instance_valid(story.ui) and story.ui.is_open()
	var offering: bool = offer != null and offer.is_open()
	var shopping: bool = story != null and is_instance_valid(story.shop) and story.shop.is_open()
	if shopping:
		activity = "shop"
		act(&"move_forward", false)
		_shop_t += dt
		if _shop_t > 1.5:
			_shop_t = 0.0
			rec.note("SHOP", "the wares screen opened from the talk; leaving it")
			rec.shot("shop")
			tap(&"toggle_settings")
		return true
	_shop_t = 0.0
	if talking or offering:
		_was_talking = true
	elif _was_talking:
		_was_talking = false
		_after_talk()
	if not talking:
		_asked.clear()
	if not (talking or offering):
		if _menu_state == "" and _paused_t > 4.0 and get_tree().paused:
			rec.problem("PAUSED_NO_UI", "the tree has been paused %.0f s with no dialogue, offer or menu of ours open" % _paused_t)
			tap(&"toggle_settings")
			_paused_t = 0.0
		return false
	activity = "dialogue" if talking else "offer"
	act(&"move_forward", false)
	act(&"sprint", false)
	_cd["ui"] = float(_cd.get("ui", 0.0)) - dt
	if float(_cd["ui"]) > 0.0:
		return true
	_cd["ui"] = 0.55
	if offering:
		if offer.mode == "turnin" and not offer._pieces.is_empty() and offer.choice < 0:
			key(KEY_1)
		else:
			tap(&"interact")
			if offer.mode == "offer":
				rec.note("OFFER", "accepting " + String(offer.quest))
	else:
		var btns: Array = story.ui._buttons
		if btns.size() > 0 and not story.ui.typing():
			var i := _pick_choice(btns)
			rec.note("CHOICE", "'%s' of %d" % [_label_of(btns[i]), btns.size()])
			key(KEY_1 + i)
		else:
			tap(&"interact")
	return true


## What a player does at a hub: take the offered task or the turn-in line ("◆", "?"), keep clear of the wares,
## otherwise the first line; if only wares are left, the last (the way out).
func _label_of(b: Button) -> String:
	var t := b.text.strip_edges()
	var re := RegEx.create_from_string("^[0-9]+\\.\\s*")
	return re.sub(t, "").strip_edges()


## A talk just ended: a player does not go straight back to the same person. If the very mark that sent us is
## still over their head a second later, that is worth a line (an offer that stays offered after it was taken).
func _after_talk() -> void:
	if goal.is_empty() or not String(goal.kind) == "talk":
		return
	var key := String(goal.key)
	_black[key] = game_t + 45.0
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		for m in get_tree().get_nodes_in_group(&"map_marker"):
			if is_instance_valid(m) and m is Node3D and _key_of(m) == key and String(m.get_meta("map_kind", "")) == "quest_available" \
					and Book.active(String(m.get_meta("quest", ""))):
				rec.problem("MARK_STAYS_AFTER_TALK", "'%s' is still on the map 1.5 s after the talk with it ended" % String(m.get_meta("map_label", "?")), false)
				return)


func _pick_choice(btns: Array) -> int:
	var first_ok := -1
	for i in btns.size():
		if _label_of(btns[i]) in _asked:
			continue
		var t := _label_of(btns[i])
		if t.begins_with("?") or t.begins_with("◆"):
			return i
		var low := t.to_lower()
		var waresy := low.contains("ware") or low.contains("trade") or low.contains("shop") or low.contains("buy") or low.contains("sell")
		if first_ok < 0 and not waresy and i < btns.size() - 1:
			first_ok = i
	if first_ok >= 0:
		_asked[_label_of(btns[first_ok])] = true
	return first_ok if first_ok >= 0 else btns.size() - 1


# --------------------------------------------------------------------------------------------------
# the menus a player opens

func _menus(dt: float) -> bool:
	if _menu_state != "":
		activity = "menu_" + _menu_state
		_menu_t += dt
		var key_name: StringName = MENUS[_menu_i][0]
		if _menu_t > 1.2 and _menu_state == "open":
			rec.shot("menu_%s" % String(MENUS[_menu_i][1]))
			rec.note("MENU", "%s open, paused=%s" % [MENUS[_menu_i][1], get_tree().paused])
			tap(key_name)
			_menu_state = "closing"
			_menu_t = 0.0
		elif _menu_t > 1.0 and _menu_state == "closing":
			if get_tree().paused:
				rec.problem("MENU_STAYS_OPEN", "%s did not close on its own key" % MENUS[_menu_i][1])
				tap(&"toggle_settings")
				_menu_state = "esc"
				_menu_t = 0.0
			else:
				_menu_state = ""
				_menu_i = (_menu_i + 1) % MENUS.size()
		elif _menu_t > 1.0 and _menu_state == "esc":
			_menu_state = ""
			_menu_i = (_menu_i + 1) % MENUS.size()
			if get_tree().paused:
				tap(&"toggle_settings")
		return true
	if game_t < _menu_next or _foe != null:
		return false
	_menu_next = game_t + (50.0 if _menu_i < MENUS.size() - 1 else 400.0)
	act(&"move_forward", false)
	act(&"sprint", false)
	tap(MENUS[_menu_i][0])
	_menu_state = "open"
	_menu_t = 0.0
	return true


# --------------------------------------------------------------------------------------------------
# fighting

func _alive(e: Node) -> bool:
	if not is_instance_valid(e) or e.is_queued_for_deletion() or not (e is Node3D):
		return false
	if "hp" in e and float(e.hp) <= 0.0:
		return false
	if "_state" in e and int(e._state) == Enemy.DEAD:
		return false
	return true


func _foes(radius: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not _alive(e):
			continue
		if float(_ignore.get(e.get_instance_id(), 0.0)) > game_t:
			continue
		var d := p.global_position.distance_to((e as Node3D).global_position)
		var awake: bool = not ("_state" in e) or int(e._state) != Enemy.IDLE
		if d < radius and (awake or d < 10.0):
			out.append([d, e])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return out


func _cool(k: String, secs: float) -> bool:
	if game_t < float(_cd.get(k, 0.0)):
		return false
	_cd[k] = game_t + secs
	return true


func _fight(dt: float) -> bool:
	var foes := _foes(16.0)
	if foes.is_empty():
		if _foe != null:
			_end_fight("clear")
		return false
	var d: float = foes[0][0]
	var foe: Node3D = foes[0][1]
	if _foe == null:
		_foe = foe
		_fights += 1
		_fight_t = 0.0
		_fight_prog_t = 0.0
		_fight_hp = float(foe.hp) if "hp" in foe else 0.0
		_strip.clear()
		_strip_n = 0
		_strip_t = 0.0
		rec.note("FIGHT", "%s at %.1f m" % [foe.get_script().resource_path.get_file().get_basename() if foe.get_script() else foe.name, d])
	elif _foe != foe and _alive(_foe):
		foe = _foe
		d = p.global_position.distance_to(foe.global_position)
	else:
		_foe = foe
	activity = "fight"
	_fight_t += dt
	_strip_t -= dt
	if _strip_t <= 0.0 and _strip_n < 6:
		_strip_t = 0.35
		_strip_n += 1
		_grab_for_strip()
	# stalemate: its health has not moved for 20 s of fighting
	var hp := float(foe.hp) if "hp" in foe else 0.0
	if hp < _fight_hp - 0.01:
		_fight_hp = hp
		_fight_prog_t = 0.0
	else:
		_fight_prog_t += dt
	if _fight_prog_t > 20.0:
		rec.problem("COMBAT_STALEMATE", "%s took no damage in 20 s at %.1f m (hp %.1f); giving up on it" % [foe.name, d, hp])
		_ignore[foe.get_instance_id()] = game_t + 90.0
		_end_fight("stalemate")
		return false
	if _fight_t > 90.0:
		rec.problem("COMBAT_TOO_LONG", "%s fight over 90 s" % foe.name)
		_ignore[foe.get_instance_id()] = game_t + 60.0
		_end_fight("long")
		return false
	var err := 0.0
	if is_instance_valid(p._lock):
		err = 0.0
	else:
		err = face(foe.global_position)
		if d < 14.0 and _cool("lock", 2.0):
			tap(&"lock_on")
	var aligned := absf(err) < 0.45
	if not use_mouse and _cool("pad", 1.0):
		_pad_like()                        # a key press (the dialogue choices) flips the skill book back to "mouse"
	# the spells, as a player rotates them
	if d < 22.0 and aligned:
		act(&"skill_bolt", true)
	else:
		act(&"skill_bolt", false)
	if d < 18.0 and aligned and _cool("lance", 3.0):
		tap(&"skill_lance", 0.5)
	if (foes.size() >= 2 and float(foes[1][0]) < 7.0 or d < 3.0) and _cool("nova", 5.0):
		tap(&"skill_nova")
	if p.wounds > 55.0 and _cool("ward", 9.0):
		tap(&"skill_ward")
	if d < 2.4 and _cool("strike", 0.8):
		tap(&"staff_strike", 0.08)
	if d < 4.5 and _cool("dodge", 2.4):
		tap(&"dodge")
	# footwork
	_strafe_t -= dt
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(0.8, 2.0)
		_strafe = -_strafe
	act(&"sprint", false)
	if d < 3.5:
		act(&"move_forward", false)
		act(&"move_back", true)
		act(&"move_left", _strafe < 0.0)
		act(&"move_right", _strafe > 0.0)
	elif d > 9.5:
		act(&"move_back", false)
		act(&"move_forward", aligned)
		act(&"move_left", false)
		act(&"move_right", false)
	else:
		act(&"move_forward", false)
		act(&"move_back", false)
		act(&"move_left", _strafe < 0.0)
		act(&"move_right", _strafe > 0.0)
	return true


func _end_fight(why: String) -> void:
	rec.note("FIGHT", "over (%s) after %.0f s, wounds %.0f, kills so far %d; hits on foes (name: hits / damage / zero-damage hits): %s" % [why, _fight_t, p.wounds, _kills, str(_dealt)])
	_dealt.clear()
	if _strip.size() >= 2 and not host.headless:
		rec.strip(_strip.duplicate(), "fight_%02d_%s" % [_fights, why])
	_strip.clear()
	_foe = null
	for a: StringName in [&"skill_bolt", &"move_back", &"move_left", &"move_right", &"move_forward", &"sprint"]:
		act(a, false)
	if is_instance_valid(p._lock):
		tap(&"lock_on")


func _grab_for_strip() -> void:
	var im: Image = await rec.grab()
	if im != null:
		_strip.append(im)


# --------------------------------------------------------------------------------------------------
# goals

func _markers(kind: String) -> Array:
	var out: Array = []
	for m in get_tree().get_nodes_in_group(&"map_marker"):
		if is_instance_valid(m) and m is Node3D and m.is_inside_tree() and String(m.get_meta("map_kind", "")) == kind:
			out.append(m)
	return out


func _near(nodes: Array, skip_black := true) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n: Node3D in nodes:
		var key := _key_of(n)
		if skip_black and float(_black.get(key, 0.0)) > game_t:
			continue
		var d := p.global_position.distance_to(n.global_position)
		if d < bd:
			bd = d
			best = n
	return best


func _key_of(n: Node) -> String:
	return "%s|%s|%s" % [n.get_meta("map_kind", n.name), n.get_meta("quest", ""), n.get_meta("map_label", n.name)]


func _active_tasks() -> int:
	var c := 0
	for id: String in Chains.ORDER:
		if Book.active(id):
			c += 1
	return c


func _main_target() -> Dictionary:
	var story := get_tree().get_first_node_in_group("story")
	if story == null:
		return {}
	var objs := QuestDB.active(story.world(), 9)
	for o: Dictionary in objs:
		if not bool(o.main):
			continue
		var id := String(o.id)
		var want := {"doors": "henge", "thorn_seal": "henge", "oss_seal": "oss_gallery", "summit_seal": "summit"}
		if want.has(id):
			for s in get_tree().get_nodes_in_group(&"ward_seal"):
				if s.seal_id == want[id]:
					return {"pos": (s as Node3D).global_position, "kind": "seal", "label": "main:" + id, "key": "main:" + id}
		var bosses := {"thornwarden": "thornwarden", "bone_abbot": "bone_abbot", "warden": "ascended_warden"}
		if bosses.has(id):
			for a in get_tree().get_nodes_in_group(&"boss_arena"):
				if a.boss_id == bosses[id]:
					return {"pos": (a as Node3D).global_position, "kind": "boss", "label": "main:" + id, "key": "main:" + id}
		return {"pos": Vector3.INF, "kind": "none", "label": "main:" + id, "key": "main:" + id}
	return {}


func _unlit_fire() -> Node3D:
	var best: Node3D = null
	var bd := 28.0
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if not is_instance_valid(b) or bool(b.lit) or _fire_visited.has(b.get_instance_id()):
			continue
		var d := p.global_position.distance_to((b as Node3D).global_position)
		if d < bd:
			bd = d
			best = b
	return best


func _lit_fire() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if not is_instance_valid(b) or not bool(b.lit):
			continue
		var d := p.global_position.distance_to((b as Node3D).global_position)
		if d < bd:
			bd = d
			best = b
	return best


func _choose_goal() -> void:
	# a long errand is kept for a minute: no flip-flopping between two far places each time the Gloom sends us home
	if not goal.is_empty() and goal.kind in ["target", "seal", "boss", "hunt"] and game_t - _goal_started < 60.0 \
			and p.gloom <= 45.0 and float(_black.get(String(goal.key), 0.0)) <= game_t:
		return
	var g := {}
	var n: Node3D
	if p.gloom > 45.0 or game_t < _rest_until:
		n = _lit_fire()
		if n != null:
			g = {"pos": n.global_position, "kind": "rest", "label": "rest at " + String(n.name), "key": "rest"}
			if game_t >= _rest_until:
				_rest_until = game_t + 40.0
	if g.is_empty():
		for kind_m: String in ["quest_turnin", "quest_available"]:
			for m in _markers(kind_m):
				if String(m.get_meta("quest", "")).begins_with("main:") and float(_black.get(_key_of(m), 0.0)) <= game_t:
					g = {"pos": m.global_position, "kind": "talk", "label": "story: " + String(m.get_meta("map_label", "")), "key": _key_of(m)}
					break
			if not g.is_empty():
				break
	if g.is_empty() and host.prefer != "":
		for kind_p: String in ["quest_turnin", "quest_target", "quest_available"]:
			for m in _markers(kind_p):
				if String(m.get_meta("quest", "")) == host.prefer and float(_black.get(_key_of(m), 0.0)) <= game_t:
					g = {"pos": m.global_position, "kind": "talk" if kind_p != "quest_target" else "target", "label": "preferred: " + String(m.get_meta("map_label", "")), "key": _key_of(m)}
					break
			if not g.is_empty():
				break
	if g.is_empty():
		n = _near(_markers("quest_turnin"))
		if n != null:
			g = {"pos": n.global_position, "kind": "talk", "label": "turn in: " + String(n.get_meta("map_label", "")), "key": _key_of(n)}
	if g.is_empty():
		var f0 := _unlit_fire()
		if f0 != null and p.global_position.distance_to(f0.global_position) < 14.0:
			g = {"pos": f0.global_position, "kind": "fire", "label": "kindle " + String(f0.name), "key": "fire:%d" % f0.get_instance_id(), "node": f0}
	if g.is_empty() and game_t > LATE_S:
		var mt0 := _main_target()
		if not mt0.is_empty() and mt0.pos != Vector3.INF and float(_black.get(String(mt0.key), 0.0)) <= game_t:
			g = _main_goal(mt0)
	if g.is_empty():
		n = _near(_markers("quest_target"))
		if n != null:
			g = {"pos": n.global_position, "kind": "target", "label": String(n.get_meta("map_label", "")), "key": _key_of(n)}
			var qid := String(n.get_meta("quest", ""))
			if Book.active(qid) and String(Chains.step(qid, Book.step(qid)).get("kind", "")) in ["slay", "collect"]:
				var prey := _prey_near(n.global_position)
				if prey != null:
					g = {"pos": prey.global_position, "kind": "hunt", "label": "hunt for " + String(n.get_meta("map_label", "")), "key": "hunt:" + qid}
	if g.is_empty() and _active_tasks() < 3 and game_t < LATE_S:
		n = _near(_markers("quest_available"))
		if n != null and p.global_position.distance_to(n.global_position) < 70.0:
			g = {"pos": n.global_position, "kind": "talk", "label": "accept: " + String(n.get_meta("map_label", "")), "key": _key_of(n)}
	if g.is_empty():
		var f := _unlit_fire()
		if f != null:
			g = {"pos": f.global_position, "kind": "fire", "label": "kindle " + String(f.name), "key": "fire:%d" % f.get_instance_id(), "node": f}
	if g.is_empty():
		var mt := _main_target()
		if not mt.is_empty() and mt.pos != Vector3.INF and float(_black.get(String(mt.key), 0.0)) <= game_t:
			g = _main_goal(mt)
		elif not mt.is_empty() and not _no_path_logged.has(String(mt.key)):
			_no_path_logged[String(mt.key)] = true
			rec.problem("MAIN_TARGET_UNKNOWN", "the main objective '%s' has no place the bot can find (no seal/arena node, no map pin)" % mt.label)
	if g.is_empty():
		g = _wander_goal()
	if String(g.get("key", "")).begins_with("main:") and g.kind in ["seal", "boss"] and not _pin_seen.has(String(g.key)):
		_pin_seen[String(g.key)] = true
		var has := false
		for m3 in get_tree().get_nodes_in_group(&"map_marker"):
			if m3 is Node3D and is_instance_valid(m3) and (m3 as Node3D).global_position.distance_to(g.pos) < 30.0 and String(m3.get_meta("map_kind", "")) != "":
				has = true
		if not has:
			rec.problem("NO_MAP_PIN", "story objective '%s' (%s) has no map marker within 30 m of its %s" % [g.label, g.kind, g.kind], false)
	if goal.get("key", "") == g.get("key", "") and not g.is_empty():
		goal.pos = g.pos                      # a hunted foe moves
	if goal.get("key", "") != g.get("key", ""):
		goal = g
		_interacts = 0
		_goal_arrived_t = 0.0
		_goal_started = game_t
		_path = PackedVector3Array()
		_path_goal = Vector3.INF
		rec.note("GOAL", "%s [%s] at %s" % [g.label, g.kind, "(%.0f, %.0f)" % [g.pos.x, g.pos.z]])


## The living foe nearest a task's pin (within 70 m of it, 110 m of us): what a slay step wants.
func _prey_near(pin: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not _alive(e) or e.has_meta(&"boss_id") or float(_ignore.get(e.get_instance_id(), 0.0)) > game_t:
			continue
		var ep := (e as Node3D).global_position
		if ep.distance_to(pin) > 70.0 or ep.distance_to(p.global_position) > 110.0:
			continue
		var d := ep.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = e
	return best


## The story's place as a goal; a seal is opened by its guardians, so the bot hunts the foes near it.
func _main_goal(mt: Dictionary) -> Dictionary:
	if mt.kind == "seal":
		var guard := _prey_near(mt.pos)
		if guard != null:
			return {"pos": guard.global_position, "kind": "hunt", "label": "hunt the guardians for " + String(mt.label), "key": "hunt:" + String(mt.key)}
	return mt


func _wander_goal() -> Dictionary:
	## nothing asks anything of us: head for the nearest landmark beacon we have not stood at, as a player wanders
	var best: Node3D = null
	var bd := INF
	for b in get_tree().get_nodes_in_group(&"landmark_beacon"):
		if not is_instance_valid(b) or not ("anchor" in b):
			continue
		var key := "wander:%d" % b.get_instance_id()
		if float(_black.get(key, 0.0)) > game_t:
			continue
		var a: Vector3 = b.anchor
		var d := p.global_position.distance_to(a)
		if d > 10.0 and d < bd:
			bd = d
			best = b
	if best != null:
		return {"pos": best.anchor, "kind": "wander", "label": "wander to a landmark", "key": "wander:%d" % best.get_instance_id()}
	return {"pos": p.global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), "kind": "wander", "label": "wander", "key": "wander:rand%d" % int(game_t / 20.0)}


# --------------------------------------------------------------------------------------------------
# travelling

func _travel(dt: float) -> void:
	_goal_t -= dt
	if _goal_t <= 0.0 or goal.is_empty():
		_goal_t = 0.5
		_choose_goal()
	if goal.is_empty():
		return
	var gp: Vector3 = goal.pos + (goal.get("off", Vector3.ZERO) as Vector3)
	var flat := Vector3(gp.x - p.global_position.x, 0.0, gp.z - p.global_position.z).length()
	var kind := String(goal.kind)
	var stop := 1.0 if kind in ["talk", "fire", "target"] else (3.0 if kind == "rest" else 4.0)
	activity = "walk_" + kind
	# arrived: use the thing
	var usable_here: bool = kind in ["talk", "fire", "target"] and flat < 3.0 and p._interact_target != null \
			and is_instance_valid(p._interact_target) and p._interact_target.can_interact()
	var pinned_near: bool = kind in ["talk", "fire", "target"] and flat < 3.0 and _stuck_stage >= 1      # the last metre is walled off
	if flat < stop + 0.5 or usable_here or pinned_near:
		act(&"move_forward", false)
		act(&"sprint", false)
		_goal_arrived_t += dt
		_arrive(kind, flat)
		return
	_goal_arrived_t = 0.0
	_steer(gp, dt, flat)


func _arrive(kind: String, flat: float) -> void:
	activity = "at_" + kind
	if kind == "rest":
		if p.gloom < 6.0 and p.wounds < 10.0 or _goal_arrived_t > 25.0:
			_rest_until = 0.0
			goal = {}
		return
	if kind in ["talk", "fire", "target"] and p._interact_target != null and is_instance_valid(p._interact_target) \
			and p._interact_target.can_interact() and _cool("interact", 0.9):
		_interacts += 1
		tap(&"interact")
		if kind == "fire" and goal.has("node") and _interacts >= 2:
			_fire_visited[goal.node.get_instance_id()] = true
			goal = {}
		return
	if kind == "hunt":
		return
	if kind == "wander" or kind == "seal" or kind == "boss":
		_black[String(goal.key)] = game_t + 120.0
		goal = {}
		return
	# close but not yet in reach (the prompt needs a step more): creep towards it
	if kind in ["talk", "target", "fire"] and p._interact_target == null and flat > 0.8 and _goal_arrived_t < 5.0 and _stuck_stage == 0:
		face(goal.pos + (goal.get("off", Vector3.ZERO) as Vector3))
		act(&"move_forward", true)
		return
	# the person is right here but a wall or counter hides them from the chest-high sight line: step round them
	var blocked := _blocked_interactable()
	if blocked != null and _goal_arrived_t > 2.5 and int(goal.get("orbit", 0)) < 4:
		goal.orbit = int(goal.get("orbit", 0)) + 1
		var ang := float(goal.orbit) * PI * 0.5 + 0.6
		var spot := blocked.global_position + Vector3(cos(ang), 0.0, sin(ang)) * 1.7
		goal.off = Vector3(spot.x - float(goal.pos.x), 0.0, spot.z - float(goal.pos.z))
		_goal_arrived_t = 0.0
		if goal.orbit == 1:
			var hit: Dictionary = p.locomotion._ray(p.global_position + Vector3.UP * 1.2, blocked.global_position + Vector3.UP * 1.0)
			var what := "?"
			if not hit.is_empty():
				var col: Object = hit.collider
				what = "%s (%s) at (%.1f, %.1f, %.1f)" % [(col as Node).get_path() if col is Node else str(col), col.get_class(), hit.position.x, hit.position.y, hit.position.z]
			var ring := ""
			var ctr := blocked.global_position
			for i in 12:
				var a2 := TAU * float(i) / 12.0
				var st := ctr + Vector3(cos(a2), 0.0, sin(a2)) * 1.5
				var sp := st
				sp.y = p.global_position.y
				var h3: Dictionary = p.locomotion._ray(sp + Vector3.UP * 1.2, ctr + Vector3.UP * 1.0)
				var open_air := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sp + Vector3.UP * 0.5, sp + Vector3.DOWN * 0.5, Layers.WORLD)).is_empty()
				ring += "%d:%s%s " % [i * 30, "clear" if h3.is_empty() else "hit", "(nofloor)" if open_air else ""]
			rec.note("SIGHT_RING", "sight to '%s' from 12 points 1.5 m round it (deg from +x): %s" % [blocked.name, ring])
			rec.problem("SIGHT_BLOCKED", "'%s' (%s) at (%.1f, %.1f, %.1f) is in reach (%.1f m) but not in sight from where we stand (%.1f, %.1f, %.1f): blocked by %s" % [blocked.name, blocked.interact_text(), blocked.global_position.x, blocked.global_position.y, blocked.global_position.z, p.global_position.distance_to(blocked.global_position), p.global_position.x, p.global_position.y, p.global_position.z, what])
		return
	# standing at the goal with nothing to use for a while
	if _goal_arrived_t > 6.0:
		var why := "nothing to interact with here" if p._interact_target == null else "interact target '%s' cannot be used" % p._interact_target.interact_text()
		if kind == "target":
			why = "reached the target pin, the task did not advance (%s)" % why
		rec.problem("GOAL_NOT_USABLE", "%s [%s] at %.1f m: %s; interactables within 5 m: %s" % [goal.label, kind, flat, why, _near_interactables()])
		_black[String(goal.key)] = game_t + 150.0
		if kind == "fire" and goal.has("node"):
			_fire_visited[goal.node.get_instance_id()] = true
		goal = {}


func _steer(gp: Vector3, dt: float, flat: float) -> void:
	var pos := p.global_position
	_path_t -= dt
	if _path_t <= 0.0 or _path_goal.distance_to(gp) > 1.0:
		_path_t = 0.8
		_path_goal = gp
		if NavAssist.ready():
			_path = NavigationServer3D.map_get_path(NavAssist.map, pos, gp, true)
			if _path.size() >= 2 and Vector3(_path[_path.size() - 1].x - gp.x, 0.0, _path[_path.size() - 1].z - gp.z).length() > 8.0:
				if not _no_path_logged.has(String(goal.key)):
					_no_path_logged[String(goal.key)] = true
					rec.problem("NO_NAV_PATH", "goal '%s' [%s] at (%.0f, %.0f): the path ends %.0f m short of it" % [goal.label, goal.kind, gp.x, gp.z, Vector3(_path[_path.size() - 1].x - gp.x, 0.0, _path[_path.size() - 1].z - gp.z).length()])
		else:
			_path = PackedVector3Array()
	var aim := gp
	if _path.size() >= 2:
		for i in range(1, _path.size()):
			var c := _path[i]
			if Vector3(c.x - pos.x, 0.0, c.z - pos.z).length() > 1.6:
				aim = c
				break
	# stuck handling
	_random_t -= dt
	if _random_t > 0.0:
		var e := angle_difference(p._yaw, _stuck_dir)
		turn(e)
		act(&"move_forward", absf(e) < 1.0)
		act(&"sprint", false)
		_check_stuck(dt, flat, false)
		return
	var err := face(aim)
	var go := absf(err) < 0.8
	act(&"move_forward", go)
	var sprint_ok := flat > 14.0 and absf(err) < 0.25 and p.wounds < 80.0
	act(&"sprint", sprint_ok)
	_check_stuck(dt, flat, go)


func _check_stuck(dt: float, flat: float, trying: bool) -> void:
	if not trying and _random_t <= 0.0:
		_prog_t = 0.0
		return
	var pos := p.global_position
	if _prog_pos == Vector3.INF:
		_prog_pos = pos
	_prog_t += dt
	if Vector3(pos.x - _prog_pos.x, 0.0, pos.z - _prog_pos.z).length() > 1.4:
		_prog_pos = pos
		_prog_t = 0.0
		_stuck_stage = 0
		return
	if _prog_t > 1.2 and _stuck_stage == 0:
		_stuck_stage = 1
		tap(&"jump")
	elif _prog_t > 3.0 and _stuck_stage == 1:
		_stuck_stage = 2
		_stuck_dir = p._yaw + (PI * 0.5 if randf() < 0.5 else -PI * 0.5)
		_random_t = 1.6
		tap(&"jump")
	elif _prog_t > 7.0 and _stuck_stage == 2:
		_stuck_stage = 3
		_stuck_spots.append(Vector2(pos.x, pos.z))
		rec.problem("STUCK", "no progress for 7 s heading to '%s' [%s] (%.1f m away), on %s; interactables within 5 m: %s" % [goal.get("label", "?"), goal.get("kind", "?"), flat, _ground_desc(), _near_interactables()])
		_stuck_dir = p._yaw + PI
		_random_t = 2.5
	elif _prog_t > 16.0 and _stuck_stage == 3:
		_stuck_stage = 4
		rec.problem("STUCK_LONG", "still stuck after 16 s heading to '%s'; skipping that goal for 3 minutes" % goal.get("label", "?"))
		_black[String(goal.get("key", ""))] = game_t + 180.0
		goal = {}
		_stuck_dir = randf() * TAU
		_random_t = 3.0
	elif _prog_t > 30.0:
		_prog_t = 0.0
		_stuck_stage = 0
		_prog_pos = pos


func _blocked_interactable() -> Interactable:
	for it in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if it is Interactable and is_instance_valid(it) and it.can_interact() \
				and p.global_position.distance_to((it as Node3D).global_position) < maxf(it.interact_reach(), p.interact_range) and not p.interaction._seen(it):
			return it
	return null


func _near_interactables() -> String:
	var near: Array[String] = []
	for it in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if is_instance_valid(it) and it is Node3D and p.global_position.distance_to((it as Node3D).global_position) < 5.0:
			var seen := "?"
			if it is Interactable:
				seen = str(p.interaction._seen(it as Interactable))
			near.append("%s %.1fm can=%s reach=%.1f seen=%s hidden=%s" % [it.name, p.global_position.distance_to((it as Node3D).global_position), it.can_interact(), it.interact_reach(), seen, it.get("hidden")])
	return "; ".join(near)


func _ground_desc() -> String:
	var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP, p.global_position + Vector3.DOWN * 3.0, Layers.WORLD)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "no ground below"
	var col: Object = hit.collider
	return "%s (slope %.0f deg)" % [String(col.get("name")) if col != null else "?", rad_to_deg(acos(clampf((hit.normal as Vector3).y, -1.0, 1.0)))]


func stats_lines() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("walked %.0f m, fights %d, kills %d, deaths %d" % [_dist_walked, _fights, _kills, _deaths])
	out.append("tasks accepted %d, handed in %d: %s" % [_accepted, _handed, ", ".join(_tasks_seen.keys())])
	out.append("final goal: %s | story lines: %s" % [goal.get("label", "-"), _story_lines()])
	out.append("stuck spots: %s" % str(_stuck_spots))
	out.append("prompts seen: %d" % _prompts.size())
	for k: String in _prompts:
		out.append("   prompt '%s' first at %s" % [k, _prompts[k]])
	for k2: String in _toasts:
		out.append("   skill/text event %s x%d" % [k2, int(_toasts[k2])])
	return out


func _story_lines() -> String:
	var story := get_tree().get_first_node_in_group("story")
	if story == null:
		return "-"
	var parts: Array[String] = []
	for o: Dictionary in story.objectives():
		parts.append(String(o.text))
	return " / ".join(parts)
