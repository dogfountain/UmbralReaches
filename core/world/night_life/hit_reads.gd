extends Node
## COMBAT HITS THAT READ AT NIGHT. enemy.gd already throws sparks on every hit; this adds the layers that tell a
## heavy blow, a critical and a kill apart in the dark, tinted by the damage school (umbral violet, ember orange,
## physical white-gold, light blue-white):
##   a HEAVY hit (a critical, or three times the usual blow) sends a shock ring along the ground under the foe;
##   a CRITICAL adds a gold starburst thrown up and a short flash light;
##   a KILL lets go a rising column of motes in the school's colour, a ring, and a flash that lights the ground for a
##   moment: a death is a small beacon, so the next foe is seen against it;
##   DAMAGE OVER TIME stays quiet (a tick is not a blow).
## Event-driven (Events.combat_damage / enemy_killed), at most eight extra effects a second, pooled bursts and the
## Vfx light cap: no cost between fights, no new particle presets after the first fight.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const BIG := 6.0
const GOLD := Color(1.9, 1.35, 0.55)

var _budget := 8.0
var _last_school := {}                    ## enemy instance id -> school of the last blow that hurt it (kill colour)


func _ready() -> void:
	Events.combat_damage.connect(_on_damage)
	Events.enemy_killed.connect(_on_killed)


func _process(delta: float) -> void:
	_budget = minf(8.0, _budget + delta * 8.0)


static func school_colour(school: StringName) -> Color:
	match school:
		&"umbral":
			return Color(1.1, 0.55, 2.0)
		&"ember":
			return Color(2.2, 0.85, 0.22)
		&"light":
			return Color(1.2, 1.6, 2.2)
	return Color(1.9, 1.6, 1.1)


func _on_damage(target: Node, amount: float, crit: bool, school: StringName, at: Vector3) -> void:
	if not Reg.enabled or target == null:
		return
	_last_school[target.get_instance_id()] = school
	if _last_school.size() > 64:
		_last_school.clear()
	if amount <= 0.0 or not (crit or amount >= BIG) or _budget < 1.0:
		return
	_budget -= 1.0
	var col := school_colour(school)
	var foot := at
	if target is Node3D:
		foot = (target as Node3D).global_position
	Vfx.ring(foot, 2.3 if crit else 1.5, col, 0.4, 0.1)
	if crit:
		Vfx.burst(at, GOLD, {"count": 22, "life": 0.55, "speed": Vector2(3.0, 8.0), "size": 0.06, "gravity": -9.0, "trail": 0.12, "spread": 70.0, "damping": 2.0})
		Vfx.light(at, GOLD, 2.0, 5.0, 0.18, 2)


func _on_killed(enemy: Node) -> void:
	if not Reg.enabled or enemy == null or not (enemy is Node3D) or _budget < 2.0:
		return
	_budget -= 2.0
	var p := (enemy as Node3D).global_position
	var school: StringName = _last_school.get(enemy.get_instance_id(), &"")
	_last_school.erase(enemy.get_instance_id())
	var col := school_colour(school)
	Vfx.ring(p, 3.0, col, 0.7, 0.12)
	Vfx.burst(p + Vector3(0.0, 0.9, 0.0), col, {"count": 18, "life": 1.5, "speed": Vector2(0.8, 2.6), "size": 0.07, "gravity": 0.9, "spread": 40.0, "damping": 1.2, "dir": Vector3.UP})
	Vfx.light(p + Vector3(0.0, 1.0, 0.0), col, 2.6, 8.0, 0.7, 2)
