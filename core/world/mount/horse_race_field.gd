extends RefCounted
## The rivals of the Hearthward race, built once with the stables (behind the loading screen, so no skeleton or mesh is made
## in play) and then parked: hidden, not processing, out of the interaction and map groups. The race (horse_race.gd) wakes them
## at the line and parks them again after. Three of them, in other breeds' coats. Load by path (no class_name).
const Horse := preload("res://core/world/mount/horse.gd")
const Data := preload("res://core/world/mount/horse_race_data.gd")


## Build the three parked rivals under `host` at `at` (the Hearthward rail). Returns them.
static func build(host: Node3D, at: Vector3) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in Data.BREEDS.size():
		var h: Node3D = Horse.new()
		h.name = "Rival_%d" % i
		h.set("breed", Data.BREEDS[i])
		h.set("rival", true)
		h.set("at_post", false)
		host.add_child(h)
		h.global_position = at
		h.remove_from_group(Groups.INTERACTABLE)       # not a horse to buy, ride or pin
		h.remove_from_group(&"horse")
		park(h)
		out.append(h)
	return out


static func park(h: Node3D) -> void:
	h.visible = false
	h.set("speed", 0.0)
	h.process_mode = Node.PROCESS_MODE_DISABLED


static func wake(h: Node3D, at: Vector3, yaw: float) -> void:
	h.process_mode = Node.PROCESS_MODE_INHERIT
	h.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	h.global_position = at
	h.global_rotation = Vector3(0.0, yaw, 0.0)
	h.set("speed", 0.0)
	h.visible = true
	h.reset_physics_interpolation()
