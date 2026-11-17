class_name Crawler
extends Enemy
## Small four-legged skitterer: the pack jumper. Ballistic 3.4 m hops while chasing, plus a short
## quick-tell pounce (3.5-8.5 m). Fragile; dangerous in numbers.


func _init() -> void:
	max_hp = 2
	hp = 2.0
	walk_speed = 3.4
	chase_range = 11.0
	hunt_leash = 13.0
	strike_range = 1.15
	strike_gloom = 14.0
	light_averse = true
	crawler = true
	hop_len = 3.4
	leaper = true
	leap_min = 3.5
	leap_max = 8.5
	leap_apex = 1.1
	leap_prep = 0.4
	leap_cooldown = 3.2
	leap_lead = 0.4
	hp_bar_y = 0.95
	role = &"flanker"
	mass = 0.7


func voice_family() -> String:
	return "crawler"


func _build() -> void:
	name = "Crawler"
	var rig := QuadRig.new()
	rig.body_height = 0.34
	rig.body_len = 0.72
	rig.hip_spread = 0.14
	rig.upper_len = 0.24
	rig.stride_len = 0.42
	attach_rig(rig)
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = 0.7
		cap.radius = 0.32
		col.position.y = 0.36
	set_flesh(EnemyBody.dress(_rig, _kind(&"crawler")))


func _hit_sound() -> String:
	return "chitin"
