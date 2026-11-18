extends Node
## Test helper: a long walk earns enough to reach a vow tier, and the vow offer pauses the night until a vow is chosen,
## which a headless test never does. This closes any open offer (runs while paused) and logs it once.
var _logged := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_d: float) -> void:
	for vp: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if vp is VowPanel and bool(vp.get("_open")):
			(vp as VowPanel).close()
			if not _logged:
				_logged = true
				print("VOWCLOSER closed a vow offer (the test cannot choose one)")
