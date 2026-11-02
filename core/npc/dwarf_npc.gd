class_name DwarfNpc
extends Node3D
## Short stout patron. Own mesh — not the wanderer robe or CharacterRig.

@export var model_path := "res://art/models/dwarf_patron_a.glb"
@export var facing := 0.0
@export var sway := 0.12

const Check := preload("res://core/debug/check.gd")

var _t := 0.0


func _ready() -> void:
	if Check.attach_glb(self, model_path, "Mesh") == null:
		push_error("dwarf_npc missing %s" % model_path)
	rotation.y = facing
	_t = float(hash(name) % 97) * 0.07


func _process(delta: float) -> void:
	_t += delta
	rotation.y = facing + sin(_t * 1.15) * sway * 0.35
	position.y += sin(_t * 1.7) * 0.0008
