class_name Ossuant
extends Husk
## Bone-plated husk. At 0 HP it collapses into a heap and knits back together after 4 s with
## half its health -- unless it was Marked when it fell, or anything hits the heap (a bolt, the
## Lance's fire, a Nova). Teaches the follow-up: mark it first, or finish what you drop.

const REFORM_TIME := 4.0
var _heap := false
var _heap_t := 0.0
var _rig_xf := Transform3D.IDENTITY


func _init() -> void:
	super._init()
	max_hp = 4
	glow_col = Color(2.2, 1.8, 1.2)
	hp = 4.0
	walk_speed = 2.7
	strike_gloom = 28.0
	windup_time = 0.55
	hp_bar_y = 1.9


func _build() -> void:
	name = "Ossuant"
	attach_rig()
	posture({"hunch": 0.2, "crouch": 0.2, "arm_reach": 0.3, "head_jut": 0.4, "limp": 0.2, "sway": 0.35, "twitch": 0.3, "splay": 0.3})
	if _rig:
		_rig.scale = Vector3(1.04, 0.94, 1.04)
		_rig_xf = _rig.transform
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = CAPSULE_H * 0.92
		col.position.y = cap.height * 0.5
	set_flesh(EnemyBody.dress(_rig, _kind(&"ossuant")))


func _hit_sound() -> String:
	return "bone"


func voice_family() -> String:
	return "ossuant"


func _ichor() -> Color:
	return Color(0.75, 0.7, 0.6)


func is_alive() -> bool:
	return _state != DEAD or _heap


func take_hit(dmg: float, from: Node = null) -> void:
	if _heap:
		_shatter()
		return
	super.take_hit(dmg, from)


func _die() -> void:
	if _heap:
		return
	if marks > 0:
		_shatter_fx()
		super._die()
		return
	_heap = true
	_heap_t = REFORM_TIME
	cancel_moves()
	_release_token()
	_state = DEAD
	_wish = Vector3.ZERO
	velocity = Vector3.ZERO
	if _hp_bar:
		_hp_bar.visible = true
		_hp_bar.set_instance_shader_parameter(&"fill", 0.0)       # the bar climbs toward the half it rises with
		_hp_bar.set_instance_shader_parameter(&"trail", 0.0)
	var at := global_position + Vector3.UP * 0.6
	Vfx.burst(at, Color(0.85, 0.78, 0.65), {"count": 22, "life": 0.6, "speed": Vector2(1.5, 3.5), "size": 0.06, "gravity": -9.0, "additive": false})
	HitText.pop(global_position + Vector3.UP * 1.4, "it will rise", Color(0.85, 0.7, 1.0))
	Hints.once(&"ossuant_heap", "The bones will knit. Strike the heap, or kill it while it carries a Mark.")
	if _rig:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_rig, "rotation:x", -1.35, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(_rig, "position:y", _rig_xf.origin.y - 0.55, 0.35).set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	if _heap:
		_heap_t -= delta
		var urgency := 1.0 - _heap_t / REFORM_TIME
		if _hp_bar:
			_hp_bar.set_instance_shader_parameter(&"fill", 0.5 * clampf(urgency, 0.0, 1.0))
			_hp_bar.set_instance_shader_parameter(&"trail", 0.5 * clampf(urgency, 0.0, 1.0))
		_flesh_param(&"glint", 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * (4.0 + 10.0 * urgency)))
		if _heap_t <= 0.0:
			_reform()
		return
	super._physics_process(delta)


func _reform() -> void:
	_heap = false
	hp = float(max_hp) * 0.5
	_flesh_param(&"glint", 0.0)
	_set_state(IDLE)
	_refresh_hp(true)
	if _hp_bar:
		_hp_bar.visible = true
	Vfx.burst(global_position + Vector3.UP * 0.8, Color(2.2, 1.3, 0.35), {"count": 30, "life": 0.5, "speed": Vector2(0.3, 1.0), "size": 0.05, "radius": 0.9, "radial": -6.0, "gravity": 0.0})
	if _rig:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_rig, "rotation:x", _rig_xf.basis.get_euler().x, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_rig, "position:y", _rig_xf.origin.y, 0.45).set_ease(Tween.EASE_OUT)


func _shatter() -> void:
	_heap = false
	if _hp_bar:
		_hp_bar.visible = false
	_flesh_param(&"glint", 0.0)
	_shatter_fx()
	_state = IDLE        # let the base death run its full path (events, dissolve, free)
	super._die()


func _shatter_fx() -> void:
	var at := global_position + Vector3.UP * 0.5
	Vfx.burst(at, Color(0.9, 0.84, 0.72), {"count": 40, "life": 0.9, "speed": Vector2(2.5, 6.0), "size": 0.07, "gravity": -12.0, "additive": false})
	Vfx.burst(at, Color(2.4, 1.4, 0.4), {"count": 24, "life": 0.5, "speed": Vector2(2.0, 5.0), "size": 0.04, "gravity": -4.0, "trail": 0.06})
