extends Crawler
## Mite: a crawler at half size with a glowing sac on its back. They come in swarms of four or
## five: quick, short tells (a little cone, a little hop), a nibble of Gloom each. One hit kills
## one; a Nova clears a swarm. They draw their attack turns from their own pool (three at once),
## so a swarm does not stop a Wretch from coming for you too.
## No class_name (project rule): the spawner preloads it.

const KinLook := preload("res://core/enemy/kin_look.gd")
const VIS_RANGE := 45.0


func _init() -> void:
	super._init()
	max_hp = 1
	hp = 1.0
	walk_speed = 4.4
	chase_range = 13.0
	hunt_leash = 16.0
	strike_range = 0.85
	strike_gloom = 5.0
	windup_time = 0.3
	strike_arc = 60.0
	lunge = 3.5
	recover_time = 0.45
	poise = 0.5
	hop_len = 1.8
	leap_min = 2.2
	leap_max = 4.8
	leap_apex = 0.6
	leap_prep = 0.3
	leap_cooldown = 2.4
	hp_bar_y = 0.55
	role = &"swarm"
	token_pool = &"swarm"
	pool_max = 3
	can_call = false
	can_flee = false
	mass = 0.35
	sleep_range = 40.0


func _voice_pitch() -> float:
	return 1.6


func _build() -> void:
	name = "Mite"
	var rig := QuadRig.new()
	rig.body_height = 0.34
	rig.body_len = 0.72
	rig.hip_spread = 0.14
	rig.upper_len = 0.24
	rig.stride_len = 0.42
	attach_rig(rig)
	rig.scale = Vector3.ONE * 0.5
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = 0.44
		cap.radius = 0.2
		col.position.y = 0.22
	set_flesh(KinLook.dress(self, "mite"))
	# small things: drawn only within VIS_RANGE (a swarm is five bodies of ~14 parts)
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = VIS_RANGE
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
