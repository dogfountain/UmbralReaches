class_name WardTarget
extends Node3D
## Something a foe can be sent at: the walker of an escort step (escort.gd) and the standing thing
## of a defend step (defend.gd). It joins Groups.WARD_TARGET and takes blows through `threat_hit`.
## A foe made by the encounter kit (encounter_kit.gd, `ward`) goes for it; the foe's real blows
## (a rake, a spat orb) land here, where the wanderer can see and interrupt them. Foes anywhere
## else in the world never look for one.

signal struck(dmg: float)

const MELEE := 0.04            ## a foe's strike_gloom times this = the hp its rake takes
const SPIT := 0.15             ## ... and for a spat orb (spit_gloom times this)
const BODY := 0.9              ## a rake reaches this much further (the target has a body, the wanderer a capsule)

var hp := 24.0
var max_hp := 24.0
var hurt_t := 0.0              ## seconds since the last blow (the frame's flash, tests)


func _enter_tree() -> void:
	add_to_group(Groups.WARD_TARGET)


## False while it is down, broken or finished: foes sent at it turn on the wanderer.
func threat_alive() -> bool:
	return hp > 0.0


## A blow from `from` (a foe). hp only falls here; the step reads it on its next tick.
func threat_hit(dmg: float, from: Node = null) -> void:
	if not threat_alive() or dmg <= 0.0:
		return
	hp = maxf(hp - dmg, 0.0)
	hurt_t = 0.0
	_on_blow(from)
	struck.emit(dmg)
	HitText.pop(global_position + Vector3.UP * 1.9, str(int(ceilf(dmg))), Color(1.0, 0.62, 0.38))


## Subclass hook: react to a blow (the escort stops to defend herself).
func _on_blow(_from: Node) -> void:
	pass


## A foe's rake at this target, the same reach and cone as its rake at the wanderer (plus BODY).
func swing_at(foe: Enemy) -> void:
	if not threat_alive():
		return
	var to := global_position - foe.global_position
	to.y = 0.0
	var d := to.length()
	var fwd := foe._face_dir if foe._face_dir.length_squared() > 0.01 else (to / maxf(d, 0.001))
	var in_cone := d < 0.6 or fwd.normalized().dot(to / maxf(d, 0.001)) >= cos(deg_to_rad(foe.strike_arc))
	if d <= foe.strike_range + BODY and in_cone:
		threat_hit(foe.strike_gloom * foe.dmg_mult * MELEE, foe)
		Vfx.burst(global_position + Vector3.UP * 1.1, Color(0.9, 0.12, 0.1), {"count": 10, "life": 0.3, "speed": Vector2(2.0, 4.0), "size": 0.04, "gravity": -4.0, "trail": 0.06})
