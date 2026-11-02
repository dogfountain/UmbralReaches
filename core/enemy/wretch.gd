class_name Wretch
extends Enemy
## Fast grey-flesh dummy. Jointed body + textures from enemy_body.gd.


func _init() -> void:
	max_hp = 3
	hp = 3.0
	walk_speed = 3.6
	chase_range = 12.0
	hunt_leash = 15.0
	strike_range = 1.45
	strike_gloom = 25.0
	light_averse = true


func _build() -> void:
	name = "Wretch"
	attach_rig()
	load("res://core/enemy/enemy_body.gd").dress(_rig, &"wretch")
