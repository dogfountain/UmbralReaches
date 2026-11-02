class_name Leaper
extends Enemy
## Big four-legged stalker: the long jumper. Circles at range, coils for half a second (body drops,
## eyes flare, shriek) and pounces 4.5-13 m with lead on your movement. Lands hard and staggers —
## the punish window. Heavy haunches and a spined tail so it reads at distance.


func _init() -> void:
	max_hp = 4
	hp = 4.0
	walk_speed = 4.2
	chase_range = 15.0
	hunt_leash = 19.0
	strike_range = 1.6
	strike_gloom = 28.0
	light_averse = true
	leaper = true
	leap_min = 4.5
	leap_max = 13.0
	leap_apex = 2.1
	leap_prep = 0.5
	leap_cooldown = 2.8
	leap_lead = 0.55
	hp_bar_y = 1.45


func _build() -> void:
	name = "Leaper"
	var rig := QuadRig.new()
	rig.body_height = 0.56
	rig.body_len = 1.15
	rig.hip_spread = 0.2
	rig.upper_len = 0.32
	rig.stride_len = 0.7
	attach_rig(rig)
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = 1.1
		cap.radius = 0.42
		col.position.y = 0.6
	set_flesh(EnemyBody.dress(_rig, &"leaper"))
