class_name Wretch
extends Enemy
## Fast grey-flesh flanker. Works round to your side while it waits for an opening; a third of
## its windups open a chain of up to three rakes (each with its own, shorter cone), and about one
## in five starts with a feint: the rear-up without any red on the ground, cut short.


func _init() -> void:
	max_hp = 3
	hp = 3.0
	walk_speed = 3.6
	chase_range = 12.0
	hunt_leash = 15.0
	strike_range = 1.45
	strike_gloom = 25.0
	windup_time = 0.42
	lunge = 5.0
	light_averse = true
	role = &"flanker"
	combo_max = 2
	combo_chance = 0.35
	combo_windup = 0.32
	feint_chance = 0.22


func _build() -> void:
	name = "Wretch"
	attach_rig()
	posture({"hunch": 0.55, "crouch": 0.35, "arm_reach": 0.45, "head_jut": 0.8, "sway": 0.6, "twitch": 0.85, "splay": 0.15})
	set_flesh(EnemyBody.dress(_rig, _kind(&"wretch")))
