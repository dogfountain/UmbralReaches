extends Node
## Input actions defined in code so the bindings live in one readable place.
## Keyboard uses physical keys (layout-independent); gamepad follows the Xbox layout.

func _ready() -> void:
	_keys("move_forward", [KEY_W, KEY_UP])
	_keys("move_back", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("sprint", [KEY_SHIFT])
	_keys("jump", [KEY_SPACE])
	_keys("interact", [KEY_E])
	_keys("cast", [KEY_Q])
	_mouse("cast", MOUSE_BUTTON_LEFT)
	_button("cast", JOY_BUTTON_RIGHT_SHOULDER)
	_axis("cast", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_keys("heavy_cast", [KEY_R])
	_mouse("heavy_cast", MOUSE_BUTTON_RIGHT)
	_axis("heavy_cast", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_keys("toggle_grade", [KEY_F1])
	_keys("toggle_debug", [KEY_F3])
	_keys("fullscreen", [KEY_F11])
	_keys("render_scale", [KEY_F4])
	_keys("demo", [KEY_F9])
	_keys("toggle_settings", [KEY_F2, KEY_ESCAPE])
	_keys("benchmark", [KEY_F8])
	_keys("release_mouse", [KEY_ESCAPE])
	_button("toggle_settings", JOY_BUTTON_START)

	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_button("jump", JOY_BUTTON_A)
	_button("interact", JOY_BUTTON_X)
	_button("sprint", JOY_BUTTON_LEFT_STICK)
	_button("toggle_debug", JOY_BUTTON_BACK)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		if not InputMap.action_has_event(action, e):
			InputMap.action_add_event(action, e)


func _button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


func _axis(action: String, axis: JoyAxis, direction: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = direction
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)
