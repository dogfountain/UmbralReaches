extends Node3D
## Slow bob and spin for rift debris. Uses accumulated delta so Movie Maker captures are deterministic.

@export var amplitude := 0.6
@export var period := 7.0
@export var spin := 0.05

var _base := Vector3.ZERO
var _phase := 0.0
var _t := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # r36 smooth: moved in _process, drawn as set (interpolated, it judders between ticks)
	_base = position
	_phase = fmod(position.x * 1.7 + position.z * 0.9, TAU)


func _process(delta: float) -> void:
	_t += delta
	position.y = _base.y + sin(_t * TAU / period + _phase) * amplitude
	rotate_y(spin * delta)
