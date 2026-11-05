extends Node
## Builds the night (optionally only some Realm modules: -- --realm-modules=land,x) and quits 2 s
## after realm_done, to find what makes Godot abort at exit. Never writes the save.
var t := 0.0
var done_t := -1.0
var main: Node
func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(d: float) -> void:
	t += d
	if main and main.has_meta("realm_done") and done_t < 0.0:
		done_t = t
		print("QUIT_PROBE realm done at %.1f s" % t)
	if (done_t >= 0.0 and t > done_t + 2.0) or t > 60.0:
		print("QUIT_PROBE quitting")
		get_tree().quit()
