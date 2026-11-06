extends Node
## Weirford: the mill's wheel turns. Its mesh nodes are modelled about the axle (Blender Y, which
## exports as Godot Z), so turning them about local Z spins the wheel. Slow, and only drawn while seen.

var targets: Array[Node3D] = []
var rate := 0.5


func _process(delta: float) -> void:
	for t in targets:
		if is_instance_valid(t) and t.is_visible_in_tree():
			t.rotate_object_local(Vector3(0, 0, 1), rate * delta)
