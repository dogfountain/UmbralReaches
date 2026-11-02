class_name Brazier
extends Interactable
## A kindle-able light: checkpoint, Gloom cleanse, and the warm accent that marks gameplay.

@export var start_lit := false
@export var light_radius := 11.0
@export var lit_energy := 4.6
@export var lit_range := 14.5

var lit := false
var _t := 0.0
var _energy := 0.0

@onready var _light: OmniLight3D = $Light
@onready var _flame: GPUParticles3D = $Flame
@onready var _coals: MeshInstance3D = $Coals
var _coal_mat: StandardMaterial3D


func _ready() -> void:
	load("res://core/world/dressed_props.gd").dress_brazier(self)
	add_to_group(Groups.INTERACTABLE)
	_t = randf() * 10.0
	# Each shadowed point light re-renders scene geometry into both faces of a dual-paraboloid map.
	# Past ~22 m the shadow is not readable anyway, so drop it there and keep the light itself.
	_light.set_meta("light_class", "beacon")
	load("res://core/world/light_policy.gd").apply_fade(_light)
	_coal_mat = (_coals.material_override as StandardMaterial3D).duplicate()
	_coals.material_override = _coal_mat
	_set_lit(start_lit, false)


func can_interact() -> bool:
	return not lit


func interact_text() -> String:
	return "[E]  Kindle the brazier"


func interact(by: Node) -> void:
	if lit:
		return
	_set_lit(true, true)
	if by.has_method("set_checkpoint"):
		by.set_checkpoint(spawn_point())
	Events.brazier_kindled.emit(self)
	Events.toast.emit("Brazier kindled. Stand in the fire. The dark leaves slowly.")


func kindle_quiet() -> void:
	if not lit:
		_set_lit(true, false)


func spawn_point() -> Vector3:
	return global_position + global_basis * Vector3(0.0, 0.3, 1.8)


func _set_lit(on: bool, animate: bool) -> void:
	lit = on
	_flame.emitting = on
	var cards := _flame.get_node_or_null("Cards")
	if cards:
		cards.visible = on
	_light.set_meta("light_class", "beacon" if on else "fill")
	load("res://core/world/light_policy.gd").apply_fade(_light)
	load("res://core/world/light_policy.gd").apply_shadows(_light)
	var target_energy := lit_energy if on else 0.25
	_light.omni_range = lit_range if on else 2.5
	if on:
		LightGrid.register(self, light_radius)
	else:
		LightGrid.unregister(self)
	if animate:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "_energy", target_energy, 0.8).from(0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(_coal_mat, "emission_energy_multiplier", 4.0, 0.8).from(0.35)
	else:
		_energy = target_energy
		_coal_mat.emission_energy_multiplier = 4.0 if on else 0.35


func _process(delta: float) -> void:
	_t += delta
	var flicker := 1.0 + (sin(_t * 11.0) * 0.06 + sin(_t * 17.3) * 0.04 if lit else sin(_t * 2.0) * 0.2)
	_light.light_energy = _energy * flicker
