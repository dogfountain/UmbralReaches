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
const Access := preload("res://ui/access.gd")
const NightFx := preload("res://core/world/night_life/night_fx.gd")

const AMBER := Color(1.0, 0.62, 0.2)
const COLD := Color(0.7, 0.88, 1.0)

var _light: OmniLight3D
var _caster: Node3D
var _dur := 0.0
var _t := 0.0
var _cold := false
var _land_budget := 3.0


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
	var col := Access.telegraph(COLD if interruptible else AMBER)        # the colour-blind palette moves the amber tell to violet
	_light.light_color = col
	_light.global_position = e.global_position + Vector3(0.0, 0.25, 0.0)
	_light.reset_physics_interpolation()
	Vfx.ring(e.global_position, 2.6, Color(col.r * 1.8, col.g * 1.8, col.b * 1.8), time, 0.09)


## What a cast that was not broken does where it lands, by the family its name says (the ground zone said where; this is the blow arriving):
## a slam or stomp throws a ring and a ground-hugging cloud, a charge or lunge a streak of dust ahead of the foe, a nova or wave a wide ring,
## anything else a small ring. Three a second at most.
func _landing(e: Node3D, cast: String) -> void:
	var p := e.global_position
	var fwd := -e.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	var dust := Color(0.4, 0.36, 0.32, 0.55)
	var warm := Access.telegraph(Color(2.0, 1.2, 0.6))
	if cast.contains("slam") or cast.contains("stomp") or cast.contains("quake") or cast.contains("smash"):
		Vfx.ring(p + fwd * 1.5, 4.0, warm, 0.5, 0.14)
		NightFx.burst(p + fwd * 1.5 + Vector3(0.0, 0.2, 0.0), dust, "dust")
	elif cast.contains("charge") or cast.contains("rush") or cast.contains("lunge") or cast.contains("pounce") or cast.contains("leap"):
		NightFx.burst(p + Vector3(0.0, 0.2, 0.0), dust, "dust", -fwd)
	elif cast.contains("nova") or cast.contains("wave") or cast.contains("ring") or cast.contains("tithe"):
		Vfx.ring(p, 7.0, warm, 0.7, 0.12)
	else:
		Vfx.ring(p + fwd * 1.2, 1.8, warm, 0.35, 0.09)


func _on_end(enemy: Node, cast: String, interrupted: bool) -> void:
	if not interrupted and Reg.enabled and enemy is Node3D and is_instance_valid(enemy) and _land_budget >= 1.0:
		_land_budget -= 1.0
		_landing(enemy as Node3D, cast.to_lower())
	if enemy != _caster:
		return
	if interrupted and Reg.enabled and _caster != null and is_instance_valid(_caster):
		var p := _caster.global_position
		NightFx.burst(p + Vector3(0.0, 1.0, 0.0), Color(1.6, 1.9, 2.4), "snap")
		Vfx.ring(p, 3.2, Color(1.6, 1.9, 2.4), 0.35, 0.12)
		Vfx.light(p + Vector3(0.0, 1.0, 0.0), COLD, 2.4, 6.0, 0.2, 2)
	_dur = 0.0
	_caster = null


## The light follows the caster on the physics tick, so the engine interpolates it with the body it stands under.
func _physics_process(_delta: float) -> void:
	if _caster != null and is_instance_valid(_caster) and _dur > 0.0:
		_light.global_position = _caster.global_position + Vector3(0.0, 0.25, 0.0)


func _process(delta: float) -> void:
	_land_budget = minf(3.0, _land_budget + delta * 3.0)
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
		pulse = 1.0 - (0.35 - 0.35 * sin(_t * 38.0)) * Access.flash()           # Reduce Flashes: the last-quarter flicker is shallow
	_light.visible = true
	_light.light_energy = (0.4 + 2.6 * u * u) * pulse * (1.3 if _cold else 1.0)
	if u >= 1.0 and _t > _dur + 0.3:
		_dur = 0.0
