class_name SkillBook
extends Node
## The player's hotbar: five Skill slots, their cooldowns, input, charge, and the read-only
## surface the Hotbar UI draws from. Lives as a child of Player; Player never handles cast input.
## Each slot listens to its own action (SLOT_ACTIONS): the Kindling's loadout puts any known spell
## in slots 1..4 (set_slot), so a skill's `action` is the slot's, not the spell's.

const LOCK := 0.15               ## cast lock after a spell: no second spell for this long; a roll cancels it
const MOVE_GRACE := 0.2          ## r33: a rooted cast forgives this much movement at its start
const CAST_MOVE := 0.7           ## walk speed while casting a cast_moving spell
const CAST_ROOT := 0.3           ## ... and during a rooted cast's grace
const HARD_HIT := 20.0           ## r33: a blow of this much Gloom (after the guard) interrupts a cast
const PUSHBACK := 0.3            ## a lighter blow sets the cast back this much
const LOCKOUT := 1.5             ## an interrupted spell's slot is locked this long
const SPENDERS: Array[StringName] = [&"lance", &"nova"]
const CombatState := preload("res://core/skills/combat_state.gd")
const Access := preload("res://ui/access.gd")
const Hints := preload("res://ui/hints.gd")
const OVERCHARGE := 0.9          ## seconds past full charge before a held Lance fires itself
const CHARGE_MOVE := 0.55        ## walk speed multiplier while charging
const SLOT_ACTIONS: Array[StringName] = [&"skill_bolt", &"skill_lance", &"skill_nova", &"skill_ward", &"skill_step"]
const BOOST := 1.3               ## Lantern Ward II: other spells recover this much faster in its light

const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
}

var player: Player
var slots: Array[Skill] = []
var using_pad := false

var _cd := PackedFloat32Array()
var _flash := PackedFloat32Array()
var _deny := PackedFloat32Array()
var _deny_why: Array[String] = []
var _charging := -1
var _charge_t := 0.0
var _swallow := false            ## the click that captured the mouse must not also cast
var boost_until := 0.0           ## Lantern Ward II: until this time (s) the other slots recover faster
var last_overcharge := 0.0       ## a CHARGE release: seconds it was held past full (the Lance's Perfect)
var combat: Node                 ## r33: CombatState (statuses, crits, Resonance, Rift Surge, target)
var cast_power := 1.0            ## r33: set while a spell's cast() runs: spender + Surge damage multiplier
var cast_spent := 0              ## r33: Resonance the running cast() spends (Lance: Ember Scar x2 at 3+)
var cast_surged := false         ## r33: the running cast() spends a Rift Surge
var _cd_total := PackedFloat32Array()
var _lock := 0.0
var _casting := -1
var _cast_t := 0.0
var _cast_total := 0.0


func _ready() -> void:
	player = get_parent() as Player
	if slots.is_empty():
		slots = [SkillBolt.new(), SkillLance.new(), SkillNova.new(), SkillWard.new(), SkillStep.new()]
	for i in mini(slots.size(), SLOT_ACTIONS.size()):
		slots[i].action = SLOT_ACTIONS[i]
	var n := slots.size()
	_cd.resize(n)
	_flash.resize(n)
	_deny.resize(n)
	_deny_why.resize(n)
	_deny_why.fill("")
	_cd_total.resize(n)
	combat = CombatState.new()
	combat.name = "Combat"
	add_child(combat)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_swallow = true


func _physics_process(delta: float) -> void:
	_lock = maxf(0.0, _lock - delta)
	var boosted := boost_until > Time.get_ticks_msec() * 0.001
	for i in slots.size():
		_cd[i] = maxf(0.0, _cd[i] - delta * (BOOST if boosted and slots[i].id != &"ward" else 1.0))
		_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)
		_deny[i] = maxf(0.0, _deny[i] - delta * 2.5)
	if _swallow and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_swallow = false
	if player == null or player.skills_locked():
		_cancel_charge()
		_stop_cast(&"cancel", "broken off")
		return
	_tick_cast(delta)
	if not _input_ok():
		_cancel_charge()
		return
	_heat_tick(delta)
	for i in slots.size():
		var s := slots[i]
		if s.id == &"bolt" and player.has_method("melee_claims_primary") and player.melee_claims_primary():
			continue                     # r31: a foe in your face takes the staff, not a bolt (StaffArts)
		match s.trigger:
			Skill.Trigger.PRESS:
				if Input.is_action_just_pressed(s.action):
					press(i)
			Skill.Trigger.HOLD_REPEAT:
				if Input.is_action_pressed(s.action) and _charging < 0 and _casting < 0:
					try_cast(i, 0.0, true)
			Skill.Trigger.CHARGE:
				_tick_charge(i, s, delta)
	player.set_charge_glow(charge_ratio())


## r30 staff heat: a held repeat (the Rift Bolt) fires 1.5x slower (0.28 -> 0.42 s) after HEAT_AFTER
## seconds of trigger held, until it has been let go for HEAT_COOL seconds. Rhythm (taps, the Lash,
## a Lance or a Nova between) beats holding the trigger down.
const HEAT_AFTER := 2.0
const HEAT_COOL := 1.0
const HEAT_SLOW := 1.5
var _heat_hold := 0.0
var _heat_cool := 0.0


func is_hot() -> bool:
	return _heat_hold >= HEAT_AFTER


## 0..1: how close the held trigger is to heat (1 = hot), for the HUD or the orb.
func heat() -> float:
	return clampf(_heat_hold / HEAT_AFTER, 0.0, 1.0)


func _heat_tick(delta: float) -> void:
	var held := false
	for s in slots:
		if s.trigger == Skill.Trigger.HOLD_REPEAT and InputMap.has_action(s.action) and Input.is_action_pressed(s.action):
			held = true
			break
	if held and _charging < 0:
		_heat_hold += delta
		_heat_cool = 0.0
	else:
		_heat_cool += delta
		if _heat_cool >= HEAT_COOL:
			_heat_hold = 0.0


func _tick_charge(i: int, s: Skill, delta: float) -> void:
	if _charging == i:
		_charge_t += delta
		var full := maxf(s.max_charge, 0.01)
		if not Input.is_action_pressed(s.action) or _charge_t >= full + OVERCHARGE:
			var c := clampf(_charge_t / full, 0.0, 1.0)
			last_overcharge = _charge_t - full
			_charging = -1
			_charge_t = 0.0
			Events.cast_stopped.emit(s.id, &"done")
			try_cast(i, c, false, true)      # the charge was the commitment: the release goes off at once
		return
	if _charging < 0 and Input.is_action_just_pressed(s.action):
		press(i)


func _start_charge(i: int) -> void:
	_charging = i
	_charge_t = 0.0
	Events.cast_started.emit(slots[i].id, maxf(slots[i].max_charge, 0.01))


func _cancel_charge() -> void:
	if _charging >= 0 and _charging < slots.size():
		Events.cast_stopped.emit(slots[_charging].id, &"cancel")
	_charging = -1
	_charge_t = 0.0
	if player:
		player.set_charge_glow(0.0)


func _input_ok() -> bool:
	if _swallow:
		return false
	return using_pad or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Cooldown, gloom cost and flash. Returns true if the skill went off.
## The spell goes off now (no cast time: press() is the input path).
## `_released`: a finished cast or a Lance release (kept for callers; the spell's own recovery rules).
func try_cast(i: int, charge: float, quiet: bool, _released := false) -> bool:
	if i < 0 or i >= slots.size():
		return false
	var s := slots[i]
	if _cd[i] > 0.0:
		if not quiet:
			_refuse(i, "")
		return false
	var why := s.can_cast(self)
	if why != "":
		if not quiet:
			_refuse(i, why)
		return false
	# r33: a spender spends every Resonance stack; a Rift Surge empowers the spell that uses it
	var spender := SPENDERS.has(s.id)
	var me: Node = player
	var spent: int = combat.stacks(me, &"resonance") if spender and combat else 0
	var surged: bool = combat != null and surge_fits(s) and combat.has(me, &"surge")
	cast_spent = spent
	cast_surged = surged
	cast_power = 1.0 + CombatState.RES_PER * float(spent)
	if surged and s.id == &"lance":
		cast_power *= CombatState.SURGE_LANCE
	var ok := s.cast(self, 1.0 if surged and s.trigger == Skill.Trigger.CHARGE else charge)
	cast_power = 1.0
	cast_spent = 0
	cast_surged = false
	if not ok:
		return false
	_cd[i] = s.cooldown * (HEAT_SLOW if s.trigger == Skill.Trigger.HOLD_REPEAT and is_hot() else 1.0)
	_cd_total[i] = _cd[i]
	_flash[i] = 1.0
	if s.gloom_cost > 0.0:
		player.add_gloom(s.gloom_cost)
	if combat:
		_spend(s, spent, surged)
	player.note_combat()
	Events.skill_cast.emit(s.id)
	if s.pose != &"" and s.pose != s.id:
		_show_pose(s.pose)
	return true


## The staff pose for `kind` (CharacterRig.cast_pose), if the wanderer has a rig.
func _show_pose(kind: StringName) -> void:
	var rig: Variant = player.get("_visual")
	if rig is Object and (rig as Object).has_method("cast_pose"):
		(rig as Object).call("cast_pose", kind)


# --- cast lock, cast times, interrupts, the spend -----------------------------------------------

## The input path for a press of slot `i`: casts now if it is ready, otherwise refuses (each
## spell has its own recovery; there is no shared cooldown and no queue). Tests call this to
## simulate a key press.
func press(i: int) -> bool:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return false
	if wait_for(i) <= 0.0 and _lock <= 0.0:
		return _begin(i)
	_refuse(i, "")
	return false


## A dodge roll cancels the cast lock so the next spell can follow the roll at once.
## Every spell ready again (the loading screen's warm-up casts each one once, then clears them).
func reset_cooldowns() -> void:
	_cd.fill(0.0)


func cancel_lock() -> void:
	_lock = 0.0


## Seconds until slot `i` could start: its own recovery, a cast in progress.
func wait_for(i: int) -> float:
	var s := slots[i]
	var w := _cd[i]
	if _casting >= 0:
		w = maxf(w, _cast_total - _cast_t)
	if _charging >= 0 and _charging != i and s.trigger == Skill.Trigger.CHARGE:
		w = maxf(w, 99.0)
	return w


## Start slot `i` (it is free): a charge, a cast with a cast time, or straight off.
func _begin(i: int) -> bool:
	var s := slots[i]
	var why := s.can_cast(self)
	if why != "":
		_refuse(i, why)
		return false
	if s.trigger == Skill.Trigger.CHARGE and player.riding != null:
		_refuse(i, "")                                    # a charge does not fill from a saddle: the slot flashes and says no
		return false
	_lock = LOCK
	var surged: bool = combat != null and surge_fits(s) and combat.has(player, &"surge")
	if s.trigger == Skill.Trigger.CHARGE:
		if surged:
			last_overcharge = -1.0                        # not a Perfect as well: the Surge is its own reward
			return try_cast(i, 1.0, false, true)          # Rift Surge: the Lance flies at full charge now
		if _charging >= 0:
			return false
		_start_charge(i)
		return true
	if s.cast_time > 0.0 and not surged:
		if _casting >= 0 or _charging >= 0:
			_refuse(i, "")                                # one cast at a time
			return false
		_casting = i
		_cast_t = 0.0
		_cast_total = s.cast_time
		Events.cast_started.emit(s.id, s.cast_time)
		_show_pose(s.pose if s.pose != &"" else s.id)     # the channel has its pose from the first instant
		return true
	return try_cast(i, 0.0, false)


func _tick_cast(delta: float) -> void:
	if _casting < 0:
		return
	var s := slots[_casting]
	_cast_t += delta
	if not s.cast_moving and _cast_t > MOVE_GRACE and player.has_method("move_intent") and float(player.call("move_intent")) > 0.3:
		_stop_cast(&"moved")
		return
	if _cast_t >= _cast_total:
		var i := _casting
		_casting = -1
		_cast_t = 0.0
		Events.cast_stopped.emit(s.id, &"done")
		try_cast(i, 0.0, false, true)


func _stop_cast(reason: StringName, word := "") -> void:
	if _casting < 0:
		return
	var id := slots[_casting].id if _casting < slots.size() else &""
	_casting = -1
	_cast_t = 0.0
	Events.cast_stopped.emit(id, reason)
	if reason == &"moved":
		word = "moved"
	if word != "" and player:
		HitText.pop(player.global_position + Vector3.UP * 2.3, word, Color(0.75, 0.8, 0.95))


## The player was struck for `amount` Gloom (after the guard): a hard blow interrupts a cast or a
## Lance charge and locks that slot; a lighter one pushes the cast back.
func on_hurt(amount: float) -> void:
	if _casting < 0 and _charging < 0:
		return
	if amount >= HARD_HIT:
		var i := _casting if _casting >= 0 else _charging
		var id := slots[i].id
		if _casting >= 0:
			_stop_cast(&"interrupted")
		else:
			_charging = -1
			_charge_t = 0.0
			player.set_charge_glow(0.0)
			Events.cast_stopped.emit(id, &"interrupted")
		_cd[i] = maxf(_cd[i], LOCKOUT)
		if _cd[i] <= LOCKOUT:
			_cd_total[i] = LOCKOUT
		if combat:
			combat.apply(player, &"shaken", 1, LOCKOUT)
		HitText.pop(player.global_position + Vector3.UP * 2.3, "INTERRUPTED", Color(1.4, 0.4, 0.35), true)
		Hints.once(&"interrupted", "A hard blow breaks a cast. Guard, dodge, or cast from cover.")
	elif _casting >= 0:
		_cast_t = maxf(0.0, _cast_t - PUSHBACK)
		HitText.pop(player.global_position + Vector3.UP * 2.3, "set back", Color(0.75, 0.8, 0.95))


## Does a Rift Surge empower `s`? (the Lance, the Nova, any spell with a cast time)
func surge_fits(s: Skill) -> bool:
	return s != null and (s.id == &"lance" or s.id == &"nova" or s.cast_time > 0.0)


## After a spell went off: the spender's Resonance, the Surge, the Nova's resonant burst.
func _spend(s: Skill, spent: int, surged: bool) -> void:
	if surged:
		combat.consume(player, &"surge")
	if spent > 0:
		combat.consume(player, &"resonance")
		var closed := minf(CombatState.RES_GLOOM * float(spent), maxf(0.0, player.wounds))
		player.mend(CombatState.RES_GLOOM * float(spent))     # spent Resonance mends Wounds
		_heat_hold = 0.0                                  # spending vents the staff's heat
		var breath := 0.0
		if spent >= 3:
			var st: Node = player.stamina() if player.has_method("stamina") else null
			if st != null:
				breath = CombatState.RES_BREATH * float(spent)
				st.refund(breath)
		var word := "RESONANCE x%d" % spent if spent >= 3 else ""
		var gain := ""                                   # under the word, a line of its own: one long line ran off the screen
		if closed > 0.0:
			gain = "mends %s" % _num(closed)
		if breath > 0.0:
			gain += ("  " if gain != "" else "") + "breath %s" % _num(breath)
		if gain != "":
			word += ("\n" if word != "" else "") + gain
		if word != "" and player.is_inside_tree():
			# beside the wanderer on the screen's left, small and muted: centred at the shoulder it sat big and pink over the
			# foe for its whole life (combat V1/warden_s41; 19 Nov, the visual pass)
			var side := Vector3.ZERO
			var cam := player.get_viewport().get_camera_3d()
			if cam != null:
				side = -cam.global_basis.x * 0.9
			HitText.pop(player.global_position + Vector3.UP * 1.6 + side, word, Color(0.92, 0.66, 1.55), false)
	if s.id == &"nova":
		var r: float = float(s.call("radius")) if s.has_method("radius") else SkillNova.RADIUS
		combat.nova_burst(r, spent, surged)


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _now() -> float:
	return Time.get_ticks_msec() * 0.001


## Put `s` in slot `i` (the Kindling's loadout): it listens to the slot's key. A new spell in the
## slot starts ready; the same spell keeps its recovery.
func set_slot(i: int, s: Skill) -> void:
	if i < 0 or i >= slots.size() or s == null:
		return
	var same := slots[i] != null and slots[i].id == s.id
	slots[i] = s
	s.action = SLOT_ACTIONS[i] if i < SLOT_ACTIONS.size() else s.action
	if not same:
		_cd[i] = 0.0
		if _charging == i:
			_cancel_charge()
		if _casting == i:
			_stop_cast(&"cancel")


## Take `secs` off slot `i`'s recovery (The Count, combos).
func refund(i: int, secs: float) -> void:
	if i >= 0 and i < _cd.size():
		_cd[i] = maxf(0.0, _cd[i] - secs)


func slot_of(id: StringName) -> int:
	for i in slots.size():
		if slots[i] != null and slots[i].id == id:
			return i
	return -1


func _refuse(i: int, why: String) -> void:
	_deny[i] = 1.0
	_deny_why[i] = why
	if why != "":
		Events.skill_failed.emit(slots[i].id, why)


# --- read-only surface for the Hotbar ---------------------------------------------------------

func cooldown_left(i: int) -> float:
	return _cd[i]


func cooldown_ratio(i: int) -> float:
	var full := maxf(slots[i].cooldown, _cd_total[i])
	return clampf(_cd[i] / full, 0.0, 1.0) if full > 0.0 else 0.0


## r33: the recovery that is running on slot `i` (its cooldown, or an interrupt lockout).
func cooldown_total(i: int) -> float:
	return maxf(_cd_total[i], 0.0) if _cd[i] > 0.0 else slots[i].cooldown


## No shared cooldown and no spell queue any more; the Hotbar still asks, so these answer "none".
func on_gcd(_i: int) -> bool:
	return false


func gcd_left() -> float:
	return 0.0


func gcd_total() -> float:
	return 0.0


func queued_slot() -> int:
	return -1


## Light slot `i`: its own primed() or a Rift Surge it would spend.
func slot_lit(i: int) -> bool:
	var s := slots[i]
	if s == null:
		return false
	if s.primed(self):
		return true
	return combat != null and surge_fits(s) and combat.has(player, &"surge")


func casting_slot() -> int:
	return _casting


## The cast bar: {} when idle.
func cast_info() -> Dictionary:
	if _casting >= 0:
		var s := slots[_casting]
		return {"id": s.id, "name": s.title, "t": _cast_t, "total": _cast_total, "kind": &"cast", "moving_ok": s.cast_moving, "slot": _casting, "color": s.color}
	if _charging >= 0:
		var c := slots[_charging]
		return {"id": c.id, "name": c.title, "t": _charge_t, "total": maxf(c.max_charge, 0.01), "kind": &"charge", "moving_ok": true, "slot": _charging, "color": c.color}
	return {}


func charging_slot() -> int:
	return _charging


func charge_ratio() -> float:
	if _charging < 0:
		return 0.0
	return clampf(_charge_t / maxf(slots[_charging].max_charge, 0.01), 0.0, 1.0)


## Seconds the held charge has gone past full (negative while still filling, 0 when not charging).
func overcharge() -> float:
	if _charging < 0:
		return 0.0
	return _charge_t - maxf(slots[_charging].max_charge, 0.01)


func flash(i: int) -> float:
	return _flash[i] * Access.flash()


func denied(i: int) -> float:
	return _deny[i]


func move_scale() -> float:
	if _casting >= 0:
		return CAST_MOVE if slots[_casting].cast_moving else CAST_ROOT
	return CHARGE_MOVE if _charging >= 0 else 1.0


## The hotbar asks for these every frame; resolving through InputMap + DisplayServer each time is
## wasted work, so labels are cached and refreshed twice a second (rebinding still shows quickly).
var _label_cache := {}
var _label_t := 0


func key_label(i: int) -> String:
	var now := Time.get_ticks_msec()
	if now - _label_t > 500:
		_label_cache.clear()
		_label_t = now
	var pad := Settings.using_pad      # the last device in hand (Settings hears every change, menus and mouse motion included)
	var key := "%d/%s" % [i, pad]
	if not _label_cache.has(key):
		_label_cache[key] = action_label(slots[i].action, pad)
	return _label_cache[key]


static func action_label(action: StringName, pad: bool) -> String:
	for ev in InputMap.action_get_events(action):
		if pad:
			if ev is InputEventJoypadButton:
				return PAD_NAMES.get((ev as InputEventJoypadButton).button_index, "Pad")
			if ev is InputEventJoypadMotion:
				var axis := (ev as InputEventJoypadMotion).axis
				if axis == JOY_AXIS_TRIGGER_RIGHT:
					return "RT"
				if axis == JOY_AXIS_TRIGGER_LEFT:
					return "LT"
		else:
			if ev is InputEventMouseButton:
				match (ev as InputEventMouseButton).button_index:
					MOUSE_BUTTON_LEFT:
						return "LMB"
					MOUSE_BUTTON_RIGHT:
						return "RMB"
					MOUSE_BUTTON_MIDDLE:
						return "MMB"
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var code := k.keycode
				if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
					code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
				return OS.get_keycode_string(code)
	return "—"
