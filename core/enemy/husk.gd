class_name Husk
extends Enemy
## Slow, squat bruiser. With a caster in its pack it guards: stands on the line between you and
## the caster and only comes for you when you come close. Its own moves, each with a ground tell:
##   rake    the shared strike (long, obvious rear-up)
##   slam    both fists overhead, a disc fills in front of it (1-3 m away); the punish is long
##   charge  at 5-10 m it lowers its head and paws: a lane fills from its feet through you; then
##           it runs the lane. Step out of the lane. If it runs into a wall it is dazed.

@export var slam_windup := 0.85
@export var charge_windup := 0.9
@export var can_slam := true
@export var can_charge := true
const CHARGE_SPEED := 9.5
const SLAM_R := 2.2

var _slam_cd := 2.5
var _charge_cd := 3.5
var _move_id: StringName = &""
var _charge_dir := Vector3.ZERO
var _charge_len := 0.0
var _charge_from := Vector3.ZERO
var _charge_hit := false
var _slam_at := Vector3.INF
var _puff_at := 0.0
var _lane: MeshInstance3D


func _init() -> void:
	max_hp = 5
	hp = 5.0
	walk_speed = 2.35
	chase_range = 10.0
	hunt_leash = 13.0
	strike_range = 1.55
	strike_gloom = 32.0
	windup_time = 0.6           # slow and heavy: a long, obvious rear-up
	strike_arc = 85.0
	lunge = 3.5
	poise = 3.2
	recover_time = 0.7
	light_averse = true
	hp_bar_y = 1.82
	role = &"guard"
	mass = 1.4
	# r31: an ember-knot between the shoulder blades -- the guard's back is where it breaks
	weak_socket = "chest"
	weak_offset = Vector3(0.0, 0.04, 0.16)
	weak_r = 0.085


func voice_family() -> String:
	return "bellow"


func _build() -> void:
	name = "Husk"
	attach_rig()
	posture({"hunch": 0.3, "crouch": 0.2, "arm_reach": 0.2, "head_jut": 0.4, "limp": 0.7, "sway": 0.4, "twitch": 0.2, "splay": 0.32})
	if _rig:
		_rig.scale = Vector3(1.08, 0.86, 1.08)
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = CAPSULE_H * 0.86
		col.position.y = cap.height * 0.5
	set_flesh(EnemyBody.dress(_rig, _kind(&"husk")))


func _try_special(d: float) -> bool:
	var step := 1.0 / think_hz
	_slam_cd = maxf(0.0, _slam_cd - step)
	_charge_cd = maxf(0.0, _charge_cd - step)
	if _p == null or _lit_t > 0.0 or not is_on_floor():
		return false
	if can_slam and _slam_cd <= 0.0 and d >= 1.0 and d <= 3.0 and randf() < 0.45 and _take_token():
		_start_slam()
		return true
	if can_charge and _charge_cd <= 0.0 and d >= 5.0 and d <= 10.0 and absf(_p.global_position.y - global_position.y) < 1.2 \
			and _strike_clear(_p) and _take_token():
		_start_charge(d)
		return true
	return false


func _start_slam() -> void:
	_move_id = &"slam"
	_slam_cd = 6.0
	_face_dir = _to / maxf(_dist, 0.001)
	_drive = Vector3.ZERO
	_set_state(SPECIAL)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", slam_windup)
	_glint = 1.0
	Sfx.play_stream(Synth.voice(voice_family(), "tell"), global_position + Vector3.UP, 1.0, _voice_pitch() * 0.85)
	var at := global_position + _face_dir * 1.5
	_slam_at = at
	AttackKit.zone(self, at, slam_windup, strike_gloom * 1.15, {"radius": SLAM_R * maxf(_rig.scale.x if _rig else 1.0, 1.0), "fx": "slam", "color": Color(2.6, 0.5, 0.1)})


func _start_charge(d: float) -> void:
	_move_id = &"charge"
	_charge_cd = 7.5
	_charge_dir = _to / maxf(d, 0.001)
	_face_dir = _charge_dir
	_charge_len = minf(d + 2.5, 11.0)
	_charge_hit = false
	_drive = Vector3.ZERO
	_set_state(SPECIAL)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", charge_windup)
	_glint = 1.0
	Sfx.play_stream(Synth.voice(voice_family(), "call"), global_position + Vector3.UP, -4.0, _voice_pitch() * 1.1)
	# the lane shows for the windup and stays (full) while it runs
	_lane = SpellFx.danger(global_position, charge_windup, {"rect": Vector2(0.85, _charge_len * 0.5), "yaw": atan2(-_charge_dir.x, -_charge_dir.z), "color": Color(2.6, 0.62, 0.1), "hold": _charge_len / CHARGE_SPEED + 0.1})
	if _lane:
		track_move(_lane)


func _special_breakable() -> bool:
	# the tell can be broken; a husk already running the lane cannot be stopped by a blow
	return not (_move_id == &"charge" and _state_t >= charge_windup)


func _special_think() -> void:
	match _move_id:
		&"slam":
			_face_dir = _face_dir
			if _state_t >= slam_windup:
				if _rig and _rig.has_method("strike"):
					_rig.call("strike")
				var p := _player()
				if p and _slam_at != Vector3.INF and Vector2(p.global_position.x - _slam_at.x, p.global_position.z - _slam_at.z).length() <= SLAM_R * maxf(_rig.scale.x if _rig else 1.0, 1.0):
					p.kick(0.45)                              # the camera answers only if the slam did
				_set_state(RECOVER)
				_state_t = -0.45                          # it has to drag its fists back up
		&"charge":
			if _state_t >= charge_windup and _drive == Vector3.ZERO:
				_charge_from = global_position
				_drive = _charge_dir * CHARGE_SPEED
				if _rig and _rig.has_method("strike"):
					_rig.call("strike")
		_:
			_set_state(RECOVER)


func _special_frame(_delta: float) -> void:
	if _move_id != &"charge" or _drive == Vector3.ZERO:
		return
	var run := global_position - _charge_from
	run.y = 0.0
	if not _charge_hit and _p != null:
		var to := _p.global_position - global_position
		var dy := to.y
		to.y = 0.0
		var rel := _p.global_position - _charge_from
		var along := rel.x * _charge_dir.x + rel.z * _charge_dir.z
		var side := absf(rel.x * -_charge_dir.z + rel.z * _charge_dir.x)
		var reached := run.x * _charge_dir.x + run.z * _charge_dir.z >= along - 1.0
		if side <= 0.85 and along >= -0.3 and along <= _charge_len and reached and absf(dy) < 1.8:
			_charge_hit = true
			if _p.is_evading():
				_p.on_evaded(self)
				return
			_p.take_wound(strike_gloom * 1.2, global_position)
			_p.kick(0.8)
			Vfx.burst(_p.global_position + Vector3.UP * 1.1, Color(0.9, 0.12, 0.1), {"count": 16, "life": 0.35, "speed": Vector2(2.0, 5.0), "size": 0.05, "gravity": -5.0, "trail": 0.06})
	if (is_on_wall() and run.length() > 0.8) or (_state_t > charge_windup + 0.25 and Vector3(velocity.x, 0.0, velocity.z).length() < 2.0):
		_end_charge(true)
	elif run.length() >= _charge_len or _state_t > charge_windup + 2.0:
		_end_charge(false)
	elif _state_t - _puff_at >= 0.08:
		_puff_at = _state_t
		Vfx.burst(global_position + Vector3.UP * 0.1, Color(0.15, 0.12, 0.1, 0.8), {"count": 4, "life": 0.6, "speed": Vector2(0.3, 1.2), "size": 0.16, "gravity": -1.0, "additive": false})


func _end_charge(wall: bool) -> void:
	_drive = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	if is_instance_valid(_lane):
		_lane.queue_free()
	_set_state(RECOVER)
	if wall:
		# ran into the stone: dazed, the long punish window
		_state_t = -1.1
		if _rig and _rig.has_method("stagger"):
			_rig.call("stagger")
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.4), "dazed", Color(1.0, 0.8, 0.5))
		Sfx.play_stream(Synth.get_stream("stagger"), global_position + Vector3.UP, 0.0, 0.8)
		Vfx.burst(global_position + Vector3.UP * 1.0 + _charge_dir * 0.6, Color(0.5, 0.45, 0.4), {"count": 20, "life": 0.6, "speed": Vector2(1.5, 4.0), "size": 0.06, "gravity": -9.0, "additive": false})
		var p := _player()
		if p and p.global_position.distance_to(global_position) < 9.0:
			p.kick(0.5)
	else:
		_state_t = -0.35
