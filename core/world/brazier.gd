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
var _crackle: AudioStreamPlayer3D


func _ready() -> void:
	DressedProps.dress_brazier(self)
	add_to_group(Groups.INTERACTABLE)
	_t = randf() * 10.0
	# Each shadowed point light re-renders scene geometry into both faces of a dual-paraboloid map.
	# Past ~22 m the shadow is not readable anyway, so drop it there and keep the light itself.
	_light.set_meta("light_class", "beacon")
	LightPolicy.apply_fade(_light)
	_coal_mat = (_coals.material_override as StandardMaterial3D).duplicate()
	_coals.material_override = _coal_mat
	_set_lit(start_lit, false)
	_crackle = AudioStreamPlayer3D.new()
	_crackle.bus = &"Ambience"
	_crackle.name = "Crackle"
	var loop := (load("res://art/audio/brazier_loop.wav") as AudioStreamWAV).duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_crackle.stream = loop
	_crackle.max_distance = 22.0
	add_child(_crackle)
	if lit:
		_crackle.play()


func can_interact() -> bool:
	return not lit


func interact_text() -> String:
	return "[%s]  Kindle the brazier" % Interactable.prompt_key()


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
	var target_energy := lit_energy if on else 0.25
	_light.set_meta(&"base", {
		"e": target_energy,
		"r": lit_range if on else 2.5,
		"a": 1.0,
	})
	LightPolicy.apply_fade(_light)
	LightPolicy.apply_shadows(_light)
	LightPolicy.apply_illumination(_light)
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
	if _crackle:
		if on:
			_crackle.play()
		else:
			_crackle.stop()


func _process(delta: float) -> void:
	_t += delta
	var flicker := 1.0 + (sin(_t * 11.0) * 0.06 + sin(_t * 17.3) * 0.04 if lit else sin(_t * 2.0) * 0.2)
	var kind := StringName(str(_light.get_meta(&"light_class")))
	_light.light_energy = _energy * LightPolicy.energy_mult(kind) * flicker
