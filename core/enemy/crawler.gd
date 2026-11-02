class_name Crawler
extends Enemy
## Low hop-crawler. Pack hunter. Uses the wretch mesh, squashed.


func _init() -> void:
	max_hp = 2
	hp = 2.0
	walk_speed = 2.9
	chase_range = 9.5
	hunt_leash = 12.0
	strike_range = 1.2
	strike_gloom = 18.0
	light_averse = true
	crawler = true
	hp_bar_y = 0.92


func _build() -> void:
	name = "Crawler"
	attach_rig()
	if _rig:
		_rig.scale = Vector3(1.2, 0.42, 1.35)
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = 0.72
		cap.radius = 0.32
		col.position.y = 0.38
	load("res://core/enemy/enemy_body.gd").dress(_rig, &"crawler")
