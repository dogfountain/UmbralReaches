extends Node
## THE WANDERER ALIVE WHEN STILL. Standing about is not a freeze frame: the rig's own cast poses are borrowed for
## small human things, read from the night around him.
##   WARMING HIS HANDS: still for three seconds within five metres of a lit fire, he reaches a hand to it every seven to
##   ten seconds (the rig's "reach"), and a few embers lift from the fire to meet it;
##   THE MOTH: still for nine seconds anywhere, a hand goes out toward the moths round his lantern, every thirteen to
##   nineteen seconds;
##   THE ECLIPSE: while the moon is out his lantern swells (a warm light carried on him, up to a third as strong again as
##   a brazier's pool) so that the one lit thing in the black is the wanderer, and fades back with the moon.
## Posing only; walking, fighting, riding and any open menu cancel it at once.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const WARM_RANGE := 5.0

var _player: CharacterBody3D
var _rig: CharacterRig
var _halo: OmniLight3D
var _still := 0.0
var _next_warm := 0.0
var _next_moth := 0.0


func _ready() -> void:
	_next_warm = 3.0
	_next_moth = 9.0


func _find() -> void:
	_player = get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	if _player == null:
		return
	for n: Node in _player.find_children("*", "Node3D", true, false):
		if n is CharacterRig:
			_rig = n as CharacterRig
			break
	_halo = OmniLight3D.new()
	_halo.name = "EclipseLantern"
	_halo.light_color = Color(1.0, 0.68, 0.34)
	_halo.omni_range = 13.0
	_halo.omni_attenuation = 1.3
	_halo.shadow_enabled = false
	_halo.light_energy = 0.0
	_halo.light_volumetric_fog_energy = 0.6
	_halo.set_meta("light_class", "player_orb")
	_halo.visible = false
	_halo.position = Vector3(-0.3, 1.2, -0.2)
	_player.add_child(_halo)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_find()
		return
	var e := clampf((Reg.gain_mul - 1.0) / 0.55, 0.0, 1.0) if Reg.enabled else 0.0
	_halo.light_energy = move_toward(_halo.light_energy, 1.5 * e, delta * 1.0)
	_halo.visible = _halo.light_energy > 0.02
	if not Reg.enabled or _rig == null:
		return
	var moving := _player.velocity.length() > 0.5 or not _player.is_on_floor() or get_tree().paused
	if moving:
		_still = 0.0
		return
	_still += delta
	_next_warm -= delta
	_next_moth -= delta
	if _still >= 3.0 and _next_warm <= 0.0:
		var fire := _near_fire()
		if fire != Vector3.INF:
			_next_warm = randf_range(7.0, 10.0)
			_rig.cast_pose(&"reach")
			Vfx.burst(fire, Color(2.0, 0.9, 0.3), {"count": 5, "life": 1.2, "speed": Vector2(0.6, 1.8), "size": 0.05, "gravity": 0.7, "spread": 25.0, "damping": 0.6, "dir": Vector3.UP})
		else:
			_next_warm = 2.0
	if _still >= 9.0 and _next_moth <= 0.0:
		_next_moth = randf_range(13.0, 19.0)
		_rig.cast_pose(&"reach")


## The nearest lit fire within reach, or INF.
func _near_fire() -> Vector3:
	var pp := _player.global_position
	var best := WARM_RANGE * WARM_RANGE
	var at := Vector3.INF
	for i in Reg.size():
		if Reg.on[i] == 0 or int(Reg.kind[i]) != Reg.Kind.FIRE:
			continue
		var d2 := pp.distance_squared_to(Reg.pos[i])
		if d2 < best:
			best = d2
			at = Reg.pos[i]
	return at
