extends Node
var main: Node
var t := 0.0
func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	if main and main.has_meta("realm_done"):
		get_tree().quit()
	if t > 400.0:
		get_tree().quit()
