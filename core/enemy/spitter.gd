class_name Spitter
extends Enemy
## Fragile ranged harasser. Keeps 6-10 m away, strafes, swells its throat sac for a visible
## windup and spits one slow teal orb. One bolt kills it; the threat is being ignored.

@export var kite_min := 6.0
@export var kite_max := 10.0
@export var fire_range := 15.0
@export var spit_windup := 0.6
@export var spit_cooldown := 2.4
@export var spit_gloom := 10.0

var _shot_cd := 1.0
var _strafe := 1.0
var _strafe_t := 0.0
var _sac: MeshInstance3D

static var _sac_mesh: SphereMesh


func _init() -> void:
	max_hp = 1
	hp = 1.0
	walk_speed = 2.8
	chase_range = 16.0
	hunt_leash = 16.0
	strike_range = 0.0          # never melees
	strike_gloom = 0.0
	light_averse = true
	hp_bar_y = 1.9


func _build() -> void:
	name = "Spitter"
	attach_rig()
	if _rig:
		_rig.scale = Vector3(0.86, 0.94, 0.86)
	EnemyBody.dress(_rig, &"spitter")
	var chest: Node3D = _rig.socket("chest") if _rig else null
	if chest:
		if _sac_mesh == null:
			_sac_mesh = SphereMesh.new()
			_sac_mesh.radius = 0.12
			_sac_mesh.height = 0.2
			_sac_mesh.radial_segments = 12
			_sac_mesh.rings = 6
			_sac_mesh.material = ProcMesh.glow_mat(Color(0.2, 1.3, 0.9))
		_sac = MeshInstance3D.new()
		_sac.name = "Sac"
		_sac.mesh = _sac_mesh
		_sac.position = Vector3(0.0, 0.2, -0.14)
		_sac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chest.add_child(_sac)


func _chases_directly() -> bool:
	return false


func _think() -> void:
	var step := 1.0 / think_hz
	_shot_cd = maxf(0.0, _shot_cd - step)
	_strafe_t -= step
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.2)
		_strafe = -_strafe
	if _p == null:
		_hold_post(_home_planar())
		return
	var from_home := _home_planar()
	match _state:
		IDLE:
			if _dist <= chase_range:
				_set_state(CHASE)
			else:
				_hold_post(from_home)
		CHASE:
			if _dist > chase_range * 1.25 or from_home > hunt_leash:
				_set_state(IDLE)
				_hold_post(from_home)
			elif _shot_cd <= 0.0 and _dist <= fire_range and _strike_clear(_p):
				_wish = Vector3.ZERO
				_face_dir = _to / maxf(_dist, 0.001)
				_set_state(WINDUP)
			else:
				_kite()
		WINDUP:
			_wish = Vector3.ZERO
			_face_dir = _to / maxf(_dist, 0.001)
			if _state_t >= spit_windup:
				_spit()
				_shot_cd = spit_cooldown + randf_range(-0.3, 0.4)
				_set_state(RECOVER)
		RECOVER:
			_wish = Vector3.ZERO
			if _state_t >= 0.5:
				_set_state(CHASE)
		_:
			_set_state(CHASE)


func _kite() -> void:
	if _dist < 0.05:
		_wish = Vector3.ZERO
		return
	var dir := _to / _dist
	var side := Vector3(-dir.z, 0.0, dir.x) * _strafe
	if _dist < kite_min:
		_wish = (-dir * 0.85 + side * 0.4).normalized()
	elif _dist > kite_max:
		_wish = (dir * 0.85 + side * 0.3).normalized()
	else:
		_wish = side
	if light_averse and LightGrid.is_lit(global_position):
		_wish *= 0.45


func _spit() -> void:
	if _p == null:
		return
	var from := global_position + Vector3.UP * 1.45
	if _sac:
		from = _sac.global_position
	var aim := _p.global_position + Vector3.UP * 1.05
	var t := from.distance_to(aim) / SpitOrb.SPEED
	var pv := Vector3(_p.velocity.x, 0.0, _p.velocity.z)
	aim += pv * t * 0.5                                 # half lead: a straight line still dodges it
	aim.y += 0.5 * SpitOrb.SAG * t * t                  # cancel the droop
	SpitOrb.launch(get_tree().current_scene, from, aim - from, spit_gloom)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _sac:
		var swell := clampf(_state_t / spit_windup, 0.0, 1.0) if _state == WINDUP else 0.0
		_sac.scale = Vector3.ONE * (1.0 + swell * 0.9 + sin(_state_t * 30.0) * 0.08 * swell)
