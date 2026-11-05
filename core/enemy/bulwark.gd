extends Husk
## Bulwark: a husk behind a door-shield (plank, iron bands, a skull boss). Blows from in front
## land on the shield (a dull knock, sparks, "blocked") until it breaks; blows from the flank or
## behind go through. It turns slowly while the shield is up, so the answer is to circle it, to
## riposte it (a staggered Bulwark has dropped its guard), or to break the shield (a Lance does
## it fast). Shield gone, it is a plain brute: quicker, angrier.
## It guards its pack's casters, rakes with the shield edge, and rushes shield-first down a lane.
## No class_name (project rule): the spawner preloads it.

const KinLook := preload("res://core/enemy/kin_look.gd")
const SHIELD_HP := 6.0
const GUARD_ARC := 0.3          ## dot of facing vs. the blow's source above which the shield takes it

var shield_hp := SHIELD_HP
var _shield: MeshInstance3D


func _init() -> void:
	super._init()
	max_hp = 6
	hp = 6.0
	walk_speed = 2.0
	strike_gloom = 30.0
	strike_range = 1.6
	strike_arc = 55.0
	windup_time = 0.65
	poise = 4.5
	mass = 2.0
	can_slam = false
	charge_windup = 1.0
	turn_rate = 3.0
	hp_bar_y = 1.95


func _build() -> void:
	name = "Bulwark"
	attach_rig()
	posture({"hunch": 0.22, "crouch": 0.3, "arm_reach": 0.1, "head_jut": 0.3, "limp": 0.3, "sway": 0.25, "twitch": 0.15, "splay": 0.42})
	if _rig:
		_rig.scale = Vector3(1.12, 0.92, 1.12)
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = CAPSULE_H * 0.92
		cap.radius = 0.42
		col.position.y = cap.height * 0.5
	set_flesh(KinLook.dress(self, "bulwark"))
	if _rig:
		_shield = _rig.find_child("Kin_shield_*", true, false) as MeshInstance3D


func has_shield() -> bool:
	return is_instance_valid(_shield) and shield_hp > 0.0


## In front, guard up: the shield takes it. Reeling (staggered, riposted) the guard is down.
func _absorb(dmg: float, from: Node) -> float:
	if not has_shield() or _state == DEAD or not (from is Node3D) or _face == null:
		return dmg
	if _state == RECOVER and _state_t < 0.0:
		return dmg
	var d := (from as Node3D).global_position - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return dmg
	var fwd := -_face.global_basis.z
	fwd.y = 0.0
	if fwd.normalized().dot(d.normalized()) < GUARD_ARC:
		return dmg
	shield_hp -= dmg * (2.0 if dmg >= 3.0 else 1.0)
	var at := _shield.global_position
	Sfx.play_stream(Synth.get_stream("block"), at, -3.0 + minf(dmg, 3.0), 1.0 - minf(dmg, 3.0) * 0.06)
	Vfx.burst(at, Color(2.2, 1.2, 0.5), {"count": 14, "life": 0.3, "speed": Vector2(3.0, 7.0), "size": 0.03, "gravity": -9.0, "trail": 0.05, "dir": d.normalized(), "spread": 70.0})
	Vfx.burst(at, Color(0.3, 0.22, 0.15), {"count": 6, "life": 0.5, "speed": Vector2(1.0, 3.0), "size": 0.05, "gravity": -9.0, "additive": false})
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.35), "blocked", Color(0.7, 0.7, 0.75))
	if from is MagicBolt or from is Player:
		Hints.once(&"bulwark", "The shield turns blows from the front. Circle it, or break it with a Lance.")
	_hitstop = 2
	_flash = 0.05
	if _rig and _rig.has_method("flinch"):
		_rig.call("flinch", 0.25, 0.0)
	_knock = -d.normalized() * 1.2
	if shield_hp <= 0.0:
		_break_shield(d.normalized())
	return 0.0


## The shield splits: the boards fall (a copy tumbles away and sinks), it reels, and it comes on
## faster without it.
func _break_shield(toward: Vector3) -> void:
	shield_hp = 0.0
	var host := Vfx.host()
	if host and is_instance_valid(_shield):
		var drop := MeshInstance3D.new()
		drop.mesh = _shield.mesh
		drop.material_override = _shield.material_override
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(drop)
		drop.global_transform = _shield.global_transform
		var land := drop.global_position - toward * 0.8 + Vector3.DOWN * 1.1
		var tw := drop.create_tween().set_parallel(true)
		tw.tween_property(drop, "global_position", land, 0.45).set_ease(Tween.EASE_IN)
		tw.tween_property(drop, "rotation:x", drop.rotation.x - 1.4, 0.45).set_ease(Tween.EASE_IN)
		tw.chain().tween_interval(1.5)
		tw.chain().tween_property(drop, "scale", Vector3(1.0, 0.02, 1.0), 0.6)
		tw.chain().tween_callback(drop.queue_free)
	if is_instance_valid(_shield):
		_flesh.erase(_shield)
		_shield.queue_free()
	_shield = null
	var at := global_position + Vector3.UP * 1.0 - toward * 0.4
	Vfx.burst(at, WOODCHIPS, {"count": 34, "life": 0.9, "speed": Vector2(2.0, 6.0), "size": 0.07, "gravity": -11.0, "additive": false})
	Vfx.burst(at, Color(2.2, 1.2, 0.5), {"count": 20, "life": 0.4, "speed": Vector2(3.0, 8.0), "size": 0.03, "gravity": -9.0, "trail": 0.05})
	Sfx.play_stream(Synth.get_stream("block"), at, 2.0, 0.6)
	Sfx.play_stream(Synth.get_stream("stagger"), at, 0.0, 0.8)
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.6), "shield broken", Color(1.2, 0.75, 0.4), true)
	turn_rate = TURN_RATE
	walk_speed *= 1.25
	_stagger_cd = 0.0
	stagger()

const WOODCHIPS := Color(0.36, 0.26, 0.18)
