class_name Leaper
extends Enemy
## Long-jump hunter. Holds, then closes the gap.


func _init() -> void:
	max_hp = 4
	hp = 4.0
	walk_speed = 4.1
	chase_range = 14.0
	hunt_leash = 18.0
	strike_range = 1.5
	strike_gloom = 28.0
	light_averse = true
	leaper = true
	leap_min = 4.5
	leap_max = 13.0
	leap_apex = 2.1
	leap_prep = 0.5
	leap_cooldown = 2.8
	leap_lead = 0.55
	hp_bar_y = 2.12


func _build() -> void:
	name = "Leaper"
	attach_rig()
	if _rig:
		_rig.scale = Vector3(0.92, 1.12, 0.92)
	EnemyBody.dress(_rig, &"leaper")
