class_name SkillBook
extends Node
## The player's hotbar: five Skill slots, their cooldowns, input, charge, and the read-only
## surface the Hotbar UI draws from. Lives as a child of Player; Player never handles cast input.

const GCD := 0.1                 ## tiny global lock so two buttons on one frame don't double-cast
const OVERCHARGE := 0.9          ## seconds past full charge before a held Lance fires itself
const CHARGE_MOVE := 0.55        ## walk speed multiplier while charging

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
var _gcd := 0.0
var _charging := -1
var _charge_t := 0.0
var _swallow := false            ## the click that captured the mouse must not also cast


func _ready() -> void:
	player = get_parent() as Player
	if slots.is_empty():
		slots = [SkillBolt.new(), SkillLance.new(), SkillNova.new(), SkillWard.new(), SkillStep.new()]
	var n := slots.size()
	_cd.resize(n)
	_flash.resize(n)
	_deny.resize(n)
	_deny_why.resize(n)
	_deny_why.fill("")


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_swallow = true


func _physics_process(delta: float) -> void:
	_gcd = maxf(0.0, _gcd - delta)
	for i in slots.size():
		_cd[i] = maxf(0.0, _cd[i] - delta)
		_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)
		_deny[i] = maxf(0.0, _deny[i] - delta * 2.5)
	if _swallow and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_swallow = false
	if player == null or not _input_ok() or player.skills_locked():
		_cancel_charge()
		return
	for i in slots.size():
		var s := slots[i]
		match s.trigger:
			Skill.Trigger.PRESS:
				if Input.is_action_just_pressed(s.action):
					try_cast(i, 0.0, false)
			Skill.Trigger.HOLD_REPEAT:
				if Input.is_action_pressed(s.action) and _charging < 0:
					try_cast(i, 0.0, true)
			Skill.Trigger.CHARGE:
				_tick_charge(i, s, delta)
	player.set_charge_glow(charge_ratio())


func _tick_charge(i: int, s: Skill, delta: float) -> void:
	if _charging == i:
		_charge_t += delta
		var full := maxf(s.max_charge, 0.01)
		if not Input.is_action_pressed(s.action) or _charge_t >= full + OVERCHARGE:
			var c := clampf(_charge_t / full, 0.0, 1.0)
			_charging = -1
			_charge_t = 0.0
			try_cast(i, c, false)
		return
	if _charging < 0 and Input.is_action_just_pressed(s.action):
		if _cd[i] > 0.0:
			_refuse(i, "")
			return
		var why := s.can_cast(self)
		if why != "":
			_refuse(i, why)
			return
		_charging = i
		_charge_t = 0.0


func _cancel_charge() -> void:
	_charging = -1
	_charge_t = 0.0
	if player:
		player.set_charge_glow(0.0)


func _input_ok() -> bool:
	if _swallow:
		return false
	return using_pad or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Cooldown, gloom cost, flash and the global lock. Returns true if the skill went off.
func try_cast(i: int, charge: float, quiet: bool) -> bool:
	if i < 0 or i >= slots.size():
		return false
	var s := slots[i]
	if _cd[i] > 0.0 or _gcd > 0.0:
		if not quiet:
			_refuse(i, "")
		return false
	var why := s.can_cast(self)
	if why != "":
		if not quiet:
			_refuse(i, why)
		return false
	if not s.cast(self, charge):
		return false
	_cd[i] = s.cooldown
	_gcd = GCD
	_flash[i] = 1.0
	if s.gloom_cost > 0.0:
		player.add_gloom(s.gloom_cost)
	player.note_combat()
	Events.skill_cast.emit(s.id)
	return true


func _refuse(i: int, why: String) -> void:
	_deny[i] = 1.0
	_deny_why[i] = why
	if why != "":
		Events.skill_failed.emit(slots[i].id, why)


# --- read-only surface for the Hotbar ---------------------------------------------------------

func cooldown_left(i: int) -> float:
	return _cd[i]


func cooldown_ratio(i: int) -> float:
	var full := slots[i].cooldown
	return clampf(_cd[i] / full, 0.0, 1.0) if full > 0.0 else 0.0


func charging_slot() -> int:
	return _charging


func charge_ratio() -> float:
	if _charging < 0:
		return 0.0
	return clampf(_charge_t / maxf(slots[_charging].max_charge, 0.01), 0.0, 1.0)


func flash(i: int) -> float:
	return _flash[i]


func denied(i: int) -> float:
	return _deny[i]


func move_scale() -> float:
	return CHARGE_MOVE if _charging >= 0 else 1.0


func key_label(i: int) -> String:
	return action_label(slots[i].action, using_pad)


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
				if k.physical_keycode != KEY_NONE:
					code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
				return OS.get_keycode_string(code)
	return "—"
