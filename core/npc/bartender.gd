class_name Bartender
extends Interactable
## Kindled Keg keep. Own dwarf mesh — not the wanderer.

@export var model_path := "res://art/models/dwarf_bartender.glb"
@export var facing := 1.5708
@export var lines: PackedStringArray = PackedStringArray([
	"The Kindled Keg. Fire stays. Hollows do not.",
	"Drink if you must — the dark still waits outside.",
	"First round's for the kindled. Second's for the lost.",
	"Keep that lantern. We don't serve the unlit.",
])

const Check := preload("res://core/debug/check.gd")

var _said := 0
var _t := 0.0


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	if Check.attach_glb(self, model_path, "Mesh") == null:
		push_error("bartender missing %s" % model_path)
	rotation.y = facing


func _process(delta: float) -> void:
	_t += delta
	rotation.y = facing + sin(_t * 0.85) * 0.04


func can_interact() -> bool:
	return true


func interact_text() -> String:
	return "[E]  Talk to the keep"


func interact_reach() -> float:
	return 2.8


func interact(_by: Node) -> void:
	if lines.is_empty():
		return
	Events.toast.emit(lines[_said % lines.size()])
	_said += 1
