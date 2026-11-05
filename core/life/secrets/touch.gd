extends Interactable
## Generic interactable for the secrets system: a prompt and a callable. `enabled` gates it;
## `prompt_fn` (optional) supplies a prompt that depends on state. No class_name.

var prompt := ""
var prompt_fn: Callable
var action: Callable
var enabled := true
var reach := -1.0


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)


func set_reach(r: float) -> void:
	reach = r
	var area := get_node_or_null("InteractSense")
	if area:
		for cs in area.get_children():
			if cs is CollisionShape3D and (cs as CollisionShape3D).shape is SphereShape3D:
				((cs as CollisionShape3D).shape as SphereShape3D).radius = maxf(r, 1.6)


func can_interact() -> bool:
	return enabled


func interact_text() -> String:
	var p := String(prompt_fn.call()) if prompt_fn.is_valid() else prompt
	return "[%s]  %s" % [Interactable.prompt_key(), p] if p != "" else ""


func interact_feel() -> StringName:
	return &"cast"


func interact(by: Node) -> void:
	if enabled and action.is_valid():
		action.call(by)


func interact_reach() -> float:
	return reach
