extends Node3D
## TELLS YOU CAN SEE IN THE DARK. The ground zones (danger_zone.gdshader) say where; this says who, and when.
## When a foe begins a cast (Events.enemy_cast_started):
##   the caster is lit from below in amber, the light swelling over the whole wind-up and pulsing fast in the last
##   quarter, so the eye is drawn to the one about to strike even at the edge of the screen (one shared, unshadowed
##   light: the most recent caster holds it);
##   a ring closes on its feet over the cast time, amber for a tell, cold white-blue for one that can be interrupted
##   (the cue to answer it);
## and when a cast is broken (enemy_cast_ended, interrupted) a white snap: sparks, a ring, a flash. A cast that lands
## fades the light out in a blink. Cost: one omni, at most one ring per cast.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const AMBER := Color(1.0, 0.62, 0.2)
const COLD := Color(0.7, 0.88, 1.0)

var _light: OmniLight3D
var _caster: Node3D
var _dur := 0.0
var _t := 0.0
var _cold := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_light = OmniLight3D.new()
	_light.name = "TellLight"
	_light.shadow_enabled = false
	_light.omni_range = 7.0
	_light.omni_attenuation = 1.2
	_light.light_energy = 0.0
	_light.light_volumetric_fog_energy = 0.6
	_light.set_meta("light_class", "player_orb")
	_light.visible = false
	add_child(_light)
	Events.enemy_cast_started.connect(_on_start)
	Events.enemy_cast_ended.connect(_on_end)


func _on_start(enemy: Node, _cast: String, time: float, interruptible: bool) -> void:
	if not Reg.enabled or not (enemy is Node3D) or time <= 0.05:
		return
	var e := enemy as Node3D
	_caster = e
	_dur = time
	_t = 0.0
	_cold = interruptible
	var col := COLD if interruptible else AMBER
	_light.light_color = col
	Vfx.ring(e.global_position, 2.6, Color(col.r * 1.8, col.g * 1.8, col.b * 1.8), time, 0.09)


func _on_end(enemy: Node, _cast: String, interrupted: bool) -> void:
	if enemy != _caster:
		return
	if interrupted and Reg.enabled and _caster != null and is_instance_valid(_caster):
		var p := _caster.global_position
		Vfx.burst(p + Vector3(0.0, 1.0, 0.0), Color(1.6, 1.9, 2.4), {"count": 20, "life": 0.4, "speed": Vector2(3.0, 8.0), "size": 0.06, "gravity": -4.0, "trail": 0.1, "spread": 180.0, "damping": 3.0})
		Vfx.ring(p, 3.2, Color(1.6, 1.9, 2.4), 0.35, 0.12)
		Vfx.light(p + Vector3(0.0, 1.0, 0.0), COLD, 2.4, 6.0, 0.2, 2)
	_dur = 0.0
	_caster = null


## The light follows the caster on the physics tick, so the engine interpolates it with the body it stands under.
func _physics_process(_delta: float) -> void:
	if _caster != null and is_instance_valid(_caster) and _dur > 0.0:
		_light.global_position = _caster.global_position + Vector3(0.0, 0.25, 0.0)


func _process(delta: float) -> void:
	if _caster != null and not is_instance_valid(_caster):
		_caster = null
		_dur = 0.0
	if _caster == null or _dur <= 0.0 or not Reg.enabled:
		_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 14.0)
		_light.visible = _light.light_energy > 0.02
		return
	_t += delta
	var u := clampf(_t / _dur, 0.0, 1.0)
	var pulse := 1.0
	if u > 0.75:
		pulse = 0.65 + 0.35 * sin(_t * 38.0)
	_light.visible = true
	_light.light_energy = (0.4 + 2.6 * u * u) * pulse * (1.3 if _cold else 1.0)
	if u >= 1.0 and _t > _dur + 0.3:
		_dur = 0.0
