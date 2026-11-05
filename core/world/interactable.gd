class_name Interactable
extends Node3D
## Something the wanderer can use with E. Add to Groups.INTERACTABLE in _ready.

func _init() -> void:
	var area := Area3D.new()
	area.name = "InteractSense"
	area.collision_layer = Layers.INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	var reach := interact_reach()
	sph.radius = reach if reach > 0.0 else 1.6
	cs.shape = sph
	area.add_child(cs)
	add_child(area)


func can_interact() -> bool:
	return false


func interact_text() -> String:
	return ""


func interact(_by: Node) -> void:
	pass


## How the wanderer acts it out: &"cast" (the staff spell gesture, burst and sound: fires, wards,
## bells), &"talk" (nothing magical: the NPC answers in its own voice), &"use" (a plain reach of the
## hand). Anything with an npc_life (`life`) is a person. Override for magic.
func interact_feel() -> StringName:
	return &"talk" if get("life") != null or is_in_group("npc") else &"use"


## Override to use a wider reach than the player's default. <= 0 means use the player range.
func interact_reach() -> float:
	return -1.0


static func prompt_key() -> String:
	if Settings.using_pad:                      # the last input was a pad: name its button
		for ev in InputMap.action_get_events("interact"):
			if ev is InputEventJoypadButton:
				return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y"}.get((ev as InputEventJoypadButton).button_index, "X")
	for ev in InputMap.action_get_events("interact"):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
		if ev is InputEventJoypadButton:
			return "X"
	return "E"
