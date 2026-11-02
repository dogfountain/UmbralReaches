class_name Husk
extends Enemy
## Slower squat dummy. Same dresser, darker palette.


func _init() -> void:
	max_hp = 5
	hp = 5.0
	walk_speed = 2.35
	chase_range = 10.0
	hunt_leash = 13.0
	strike_range = 1.55
	strike_gloom = 32.0
	light_averse = true
	hp_bar_y = 1.82


func _build() -> void:
	name = "Husk"
	attach_rig()
	if _rig:
		_rig.scale = Vector3(1.08, 0.86, 1.08)
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = CAPSULE_H * 0.86
		col.position.y = cap.height * 0.5
	set_flesh(EnemyBody.dress(_rig, &"husk"))
