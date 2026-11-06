class_name PlayerInteraction
extends Node
## Interact sensor, the nearest usable thing and the use key.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

var _interact_near: Array[Interactable] = []


func _init(p: Player) -> void:
	player = p


# --- Interaction -------------------------------------------------------------

func _setup_interact_sensor() -> void:
	var sense := Area3D.new()
	sense.name = "InteractSensor"
	sense.collision_layer = 0
	sense.collision_mask = Layers.INTERACT
	sense.monitoring = true
	sense.monitorable = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.2
	cs.shape = sph
	sense.add_child(cs)
	player.add_child(sense)
	sense.area_entered.connect(_on_interact_in)
	sense.area_exited.connect(_on_interact_out)


func _on_interact_in(area: Area3D) -> void:
	var it := area.get_parent() as Interactable
	if it and not _interact_near.has(it):
		_interact_near.append(it)


func _on_interact_out(area: Area3D) -> void:
	var it := area.get_parent() as Interactable
	if it:
		_interact_near.erase(it)


func _scan_interactables() -> void:
	var best: Interactable = null
	var best_d := INF
	var i := 0
	while i < _interact_near.size():
		var it := _interact_near[i]
		if not is_instance_valid(it):
			_interact_near.remove_at(i)
			continue
		i += 1
		if not it.can_interact():
			continue
		var reach := it.interact_reach()
		if reach <= 0.0:
			reach = player.interact_range
		var d := player.global_position.distance_squared_to(it.global_position)
		if d < reach * reach and d < best_d and _seen(it):
			best_d = d
			best = it
	player._interact_target = best
	var hint := best.interact_text() if best else ""
	if hint != player._hint:
		player._hint = hint
		Events.interact_hint.emit(hint)


## No wall between your chest and its chest: a person on the far side of the Keg's wall is not yours to nod at.
func _seen(it: Interactable) -> bool:
	if not player.is_inside_tree():
		return true
	var a := player.global_position + Vector3.UP * 1.2
	var b := it.global_position + Vector3.UP * 1.0
	if a.distance_squared_to(b) < 0.64:
		return true
	var hit := player.locomotion._ray(a, b)
	return hit.is_empty() or (hit.position as Vector3).distance_to(b) < 0.7


func _try_interact() -> void:
	if is_instance_valid(player._interact_target) and player._interact_target.can_interact():
		match player._interact_target.interact_feel():
			&"cast":
				player._visual.cast()               # fires, wards and bells take the staff's magic
			&"talk":
				player._visual.cast_pose(&"greet")  # people get a nod, not a spell in the face
			_:
				player._visual.cast_pose(&"reach")
		player._interact_target.interact(player)
