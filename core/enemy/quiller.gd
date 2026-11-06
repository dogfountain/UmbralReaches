extends Spitter
## Quiller (r31, docs/enshrouded/enemies.md): a bone-plated Ossuant that has learned to throw its
## own ribs. The pack's marksman: it keeps 9-14 m off, behind its packmates when it can (Spitter's
## kiting), and when you close inside 4 m it springs back out of reach (no tell needed: it is
## running away).
##   draw   it rears, a rib drawn back over its shoulder, and a long narrow lane fills from its feet
##          past you (0.85 s): then the shard flies down the lane, all of it, at once. Sidestep.
##          Any blow on the draw spoils the throw (the lane fades).
##   no line  it does not lob: it strafes for a line on you (cover works against it).
## Its skull is the weak point (a bolt there, and it drops).
## No class_name (project rule): the spawner and Tiers load it by path.

const DRAW := 0.85
const LANE_LEN := 17.0
const HOP_BACK := 5.5
var look_kind := "ossuant"

var _hop_back_cd := 0.0
var _aim_yaw := 0.0
var _lane_from := Vector3.ZERO
static var _mat: ShaderMaterial


func _init() -> void:
	super._init()
	max_hp = 2
	hp = 2.0
	walk_speed = 3.0
	chase_range = 18.0
	hunt_leash = 20.0
	kite_min = 9.0
	kite_max = 14.0
	fire_range = 16.0
	spit_cooldown = 3.2
	spit_gloom = 18.0
	poise = 1.6
	hp_bar_y = 1.95
	mass = 0.9
	can_call = true
	weak_socket = "head"
	weak_offset = Vector3(0.0, 0.04, -0.04)
	weak_r = 0.08


func voice_family() -> String:
	return "quiller"


func _hit_sound() -> String:
	return "bone"


func _ichor() -> Color:
	return Color(0.75, 0.7, 0.6)


func _build() -> void:
	name = "Quiller"
	attach_rig()
	posture({"hunch": 0.28, "crouch": 0.22, "arm_reach": 0.32, "head_jut": 0.55, "limp": 0.15, "sway": 0.45, "twitch": 0.4, "splay": 0.22})
	if _rig:
		_rig.scale = Vector3(0.94, 1.0, 0.94)
	set_flesh(EnemyBody.dress(_rig, _kind(&"ossuant")))
	# its own copy of the Ossuant's look: ash-dark bone, a cold glint in the sockets
	if _mat == null and not _flesh.is_empty() and _flesh[0].material_override is ShaderMaterial:
		_mat = (_flesh[0].material_override as ShaderMaterial).duplicate() as ShaderMaterial
		_mat.set_shader_parameter("rim_col", Color(0.62, 0.78, 1.0))
		_mat.set_shader_parameter("rim_amount", 0.3)
	if _mat:
		for mi in _flesh:
			if is_instance_valid(mi):
				mi.material_override = _mat


func _think() -> void:
	_hop_back_cd = maxf(0.0, _hop_back_cd - 1.0 / think_hz)
	if _state == CHASE and _p != null and _dist < 4.0 and _hop_back_cd <= 0.0 and is_on_floor() and not _ballistic:
		_spring_back()
		return
	if _state == CHASE and _p != null and _shot_cd <= 0.0 and _dist <= fire_range and _dist <= chase_range * 1.25 and not _strike_clear(_p):
		_update_separation()
		_strafe_for_line()
		return
	super._think()


## Out of line: strafe hard one way (and back after a while) until it can see you.
func _strafe_for_line() -> void:
	_strafe_t -= 1.0 / think_hz
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.6, 2.6)
		_strafe = -_strafe
	var dir := _to / maxf(_dist, 0.001)
	_wish = Vector3(-dir.z, 0.0, dir.x) * _strafe
	if _detour != Vector3.ZERO:
		_wish = _detour
	_face_dir = dir


func _spring_back() -> void:
	_hop_back_cd = 5.0
	var away := -_to / maxf(_dist, 0.001)
	var land := LightGrid.outside(global_position + away.rotated(Vector3.UP, randf_range(-0.5, 0.5)) * HOP_BACK, LIGHT_MARGIN, _wardproof())
	var to_land := land - global_position
	to_land.y = 0.0
	if to_land.length() > 0.5:      # a short thread along the jump, painted before the body leaves
		SpellFx.danger(global_position, 0.3, {"rect": Vector2(0.42, to_land.length() * 0.5), "yaw": atan2(-to_land.x, -to_land.z), "color": Color(0.8, 0.74, 0.6)})
	get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
		if is_inside_tree() and _state != DEAD:
			launch_at(land, 1.0))
	say("flee", global_position + Vector3.UP, -6.0, _voice_pitch())
	Vfx.burst(global_position + Vector3.UP * 0.1, Color(0.3, 0.27, 0.22, 0.9), {"count": 10, "life": 0.5, "speed": Vector2(1.0, 2.5), "size": 0.1, "gravity": -6.0, "additive": false})


## The draw: the lane shows from its feet past you for the whole draw, then the shard flies down it.
func _on_state(next: int) -> void:
	if next != WINDUP:
		super._on_state(next)
		return
	_lobbing = false
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", DRAW)
	_glint = 1.0
	say("windup", global_position + Vector3.UP * 1.5, -2.0, _voice_pitch() * 1.1)
	if _p == null:
		return
	# lead a little: where you are, plus a third of where you are going
	var aim := _p.global_position + Vector3(_p.velocity.x, 0.0, _p.velocity.z) * DRAW * 0.35 - global_position
	aim.y = 0.0
	if aim.length() < 0.5:
		aim = _to
	_aim_yaw = atan2(-aim.x, -aim.z)
	_lane_from = global_position
	AttackKit.zone(self, global_position, DRAW, spit_gloom, {"rect": Vector2(0.42, LANE_LEN * 0.5), "yaw": _aim_yaw, "color": AttackKit.RED, "fx": "none",
		"h": 2.2, "on_land": _loose.bind(global_position, _aim_yaw)})


func _cur_wind() -> float:
	return DRAW


## Replaces the spit (Spitter's WINDUP ends in _spit / _lob): the zone resolves the hit itself.
func _spit() -> void:
	if _rig and _rig.has_method("strike"):
		_rig.call("strike")


func _lob() -> void:
	_spit()


## The shard's flight down the lane (visual and sound: the zone already decided the hit).
func _loose(from: Vector3, yaw: float) -> void:
	var dir := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var a := from + Vector3.UP * 1.4
	var b := from + dir * LANE_LEN + Vector3.UP * 1.1
	var pts := PackedVector3Array()
	for i in 6:
		pts.append(a.lerp(b, float(i) / 5.0))
	Vfx.ribbon(pts, 0.05, 0.01, Color(2.2, 1.9, 1.5, 0.9), 0.22)
	Sfx.play_stream(Synth.get_stream("bone"), from + Vector3.UP * 1.4, -2.0, 1.6)
	Vfx.burst(b, Color(0.85, 0.78, 0.66), {"count": 14, "life": 0.5, "speed": Vector2(1.0, 3.0), "size": 0.04, "gravity": -9.0, "additive": false})
