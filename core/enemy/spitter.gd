class_name Spitter
extends Enemy
## Fragile ranged harasser. Keeps 6-10 m away, strafes, swells its throat sac for a visible
## windup and spits one slow teal orb. One bolt kills it; the threat is being ignored.
## Pack support: it keeps a melee packmate between itself and you when it can. When you are far,
## or out of its line of sight (behind cover), it lobs instead: a glob on a high arc, its landing
## disc filling under you from the moment the sac swells, and a pool of acid where it lands.
## A Nova near it makes it spit back at once.

const Tiers := preload("res://core/life/encounters/tiers.gd")

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
var _lobbing := false
@export var lob_windup := 0.7
@export var lob_flight := 1.0
const LOB_R := 1.7

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
	role = &"support"
	can_call = false
	mass = 0.8


func voice_family() -> String:
	return "gurgle"


func _on_nova_near() -> void:
	_shot_cd = minf(_shot_cd, 0.25)
	_shaken_t = 0.0


func _build() -> void:
	name = "Spitter"
	attach_rig()
	posture({"hunch": 0.35, "crouch": 0.3, "arm_reach": 0.25, "head_jut": 1.0, "sway": 0.7, "twitch": 0.6, "splay": 0.12})
	if _rig:
		_rig.scale = Vector3(0.86, 0.94, 0.86)
	set_flesh(EnemyBody.dress(_rig, _kind(&"spitter")))
	var chest: Node3D = _rig.socket("chest") if _rig else null
	if chest:
		if _sac_mesh == null:
			_sac_mesh = SphereMesh.new()
			_sac_mesh.radius = 0.085
			_sac_mesh.height = 0.15
			_sac_mesh.radial_segments = 24
			_sac_mesh.rings = 12
			# r30: a lit membrane with the light inside (it was an unshaded cyan disc on the chest)
			var mm := ShaderMaterial.new()
			mm.shader = preload("res://core/enemy/sac_membrane.gdshader")
			_sac_mesh.material = mm
		_sac = MeshInstance3D.new()
		_sac.name = "Sac"
		_sac.mesh = _sac_mesh
		_sac.position = Vector3(0.0, 0.25, -0.13)
		_sac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chest.add_child(_sac)
		_weak = _sac                             # r31: the swollen sac is its weak point
		weak_r = 0.14


## The windup: the sac swells (see _physics_process), the body rears, and a narrow lane fills
## along the line it will spit down -- sidestep out of it.
func _on_state(next: int) -> void:
	if next != WINDUP:
		super._on_state(next)
		return
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", _cur_wind())
	_glint = 1.0
	begin_cast("Acid Lob" if _lobbing else spit_cast, _cur_wind(), true)   # r33: a cast bar; a blow breaks it
	say("windup", global_position + Vector3.UP, -2.0, _voice_pitch())
	if _p and _lobbing:
		var target := _lob_target()
		set_meta(&"lob_at", target)
		AttackKit.zone(self, target, lob_windup + lob_flight, spit_gloom * 1.2, {"radius": LOB_R, "color": AttackKit.ACID, "fx": "acid", "release": lob_windup,
			"on_land": AttackKit.linger.bind(target, LOB_R * 0.85, 3.2, 3.0 * Tiers.dmg_of(self), 0.5, Color(0.2, 1.1, 0.75))})   # static: lands even if the spitter is dead by then
	elif _p:
		var to := _p.global_position - global_position
		to.y = 0.0
		_danger = SpellFx.danger(global_position, spit_windup, {"rect": Vector2(0.55, to.length() * 0.5 + 0.6), "yaw": atan2(-to.x, -to.z), "color": Color(0.3, 1.6, 1.1)})


## r33: the name its spit's cast bar shows (an elite names its own).
var spit_cast := "Bile Spit"


func can_cast() -> bool:
	return super.can_cast() and _lit_t <= 2.5       # no new spit at someone sheltering in light


func _chases_directly() -> bool:
	return false


func _exact_windup() -> bool:
	return false                                 # its WINDUP ends in a spit or a lob (_think)


func _cur_wind() -> float:
	return lob_windup if _lobbing else spit_windup


## Where a lob comes down: where you are, plus a little of where you are going.
func _lob_target() -> Vector3:
	var pv := Vector3(_p.velocity.x, 0.0, _p.velocity.z)
	var at := _p.global_position + pv * (lob_windup + lob_flight) * 0.35
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 4.0, Layers.WORLD))
	return (hit.position as Vector3) if not hit.is_empty() else _p.global_position


func _think() -> void:
	_update_separation()
	var step := 1.0 / think_hz
	_shot_cd = maxf(0.0, _shot_cd - step)
	_strafe_t -= step
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.2)
		_strafe = -_strafe
	if _p == null and not _on_threat:
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
			if _dist > chase_range * 1.25 or from_home > hunt_leash or (_lit_t > 2.5 and _ward_lit()):
				if _lit_t > 2.5:
					_calm_t = 3.5                   # sheltered in light: it gives up the chase like a melee body
				_set_state(IDLE)
				_hold_post(from_home)
			elif _shot_cd <= 0.0 and can_cast() and _dist <= fire_range and (_on_threat or _strike_clear(_p)):
				_wish = Vector3.ZERO
				_face_dir = _to / maxf(_dist, 0.001)
				_lobbing = _dist > kite_max + 1.5 and randf() < 0.5 and not has_meta(&"elite_id")
				_set_state(WINDUP)
			elif _shot_cd <= 0.0 and can_cast() and _dist <= fire_range and not _on_threat and not has_meta(&"elite_id"):
				# no line on you (cover, a rise): lob over it
				_wish = Vector3.ZERO
				_face_dir = _to / maxf(_dist, 0.001)
				_lobbing = true
				_set_state(WINDUP)
			else:
				_kite()
		WINDUP:
			_wish = Vector3.ZERO
			_face_dir = _to / maxf(_dist, 0.001)
			if _state_t >= _cur_wind():
				if _lobbing:
					_lob()
				else:
					_spit()
				_shot_cd = spit_cooldown + randf_range(-0.3, 0.4) + (0.6 if _lobbing else 0.0)
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
	if _p != null and is_instance_valid(_shield_ally) and _shield_ally.is_alive() and _dist >= kite_min * 0.8:
		# keep a packmate between us: the spot 3.5 m behind it, on the line from you
		var a := _shield_ally.global_position
		var back := a - _p.global_position
		back.y = 0.0
		if back.length() > 1.0 and back.length() < 13.0:
			var go := a + back.normalized() * 3.5 - global_position
			go.y = 0.0
			if go.length() > 1.2:
				_wish = (go.normalized() * 0.85 + side * 0.25).normalized()
				if light_averse and LightGrid.is_lit(global_position):
					_wish *= 0.45
				return
	if _dist < kite_min:
		_wish = (-dir * 0.85 + side * 0.4).normalized()
	elif _dist > kite_max:
		_wish = (dir * 0.85 + side * 0.3).normalized()
	else:
		_wish = side
	if light_averse and LightGrid.is_lit(global_position):
		_wish *= 0.45


func _spit() -> void:
	if _p == null and not _on_threat:
		return
	var from := muzzle_point(1.45)
	var aim := _spit_aim(from)
	var orb := SpitOrb.launch(get_tree().current_scene, from, aim - from, spit_gloom)
	if orb != null:
		orb.at_ward = _on_threat
	Sfx.play_stream(EnemyAudio.kit("spit"), from, -4.0)
	Vfx.burst(from, Color(0.3, 1.6, 1.1), {"count": 14, "life": 0.3, "speed": Vector2(1.0, 3.0), "size": 0.05, "dir": (aim - from).normalized(), "spread": 30.0, "gravity": -6.0})


const MUZZLE_FWD := 0.4        ## m: a shot leaves at least this far in front of the body's centre

## Where a shot leaves: the sac (or `up` m above the feet), never behind the front of the body. The windup
## rears the chest back, and the sac with it, so a raw sac position put the orb at its back.
func muzzle_point(up: float) -> Vector3:
	var m := _sac.global_position if _sac else global_position + Vector3.UP * up
	var fwd := Vector3.ZERO
	if _face_dir.length_squared() > 0.01:
		fwd = Vector3(_face_dir.x, 0.0, _face_dir.z).normalized()
	elif _face:
		fwd = Vector3(-_face.global_basis.z.x, 0.0, -_face.global_basis.z.z).normalized()
	var along := (m - global_position).dot(fwd)
	if along < MUZZLE_FWD:
		m += fwd * (MUZZLE_FWD - along)
	return m


## The point the orb is thrown at: where you are plus half your run over its flight (the lane follows it).
func _spit_aim(from: Vector3) -> Vector3:
	if _on_threat:
		var t := _threat_node()
		var at := (t.global_position if t != null else global_position + _to) + Vector3.UP * 1.0
		return at + Vector3.UP * 0.5 * SpitOrb.SAG * pow(from.distance_to(at) / SpitOrb.SPEED, 2.0)
	var aim := _p.global_position + Vector3.UP * 1.05
	var t := from.distance_to(aim) / SpitOrb.SPEED
	var pv := Vector3(_p.velocity.x, 0.0, _p.velocity.z)
	aim += pv * t * 0.5                                 # half lead: a straight line still dodges it
	aim.y += 0.5 * SpitOrb.SAG * t * t                  # cancel the droop
	return aim


## Each windup frame the lane is laid along the line the orb will fly (it reads true to the last moment).
func _aim_lane() -> void:
	var from := global_position
	var d := _spit_aim(global_position + Vector3.UP * 1.45) - from
	d.y = 0.0
	if d.length() < 0.3:
		return
	var half := Vector2(0.55, d.length() * 0.5 + 0.6)
	var b := Basis(Vector3.UP, atan2(-d.x, -d.z))
	_danger.global_transform = Transform3D(b * Basis.from_scale(Vector3(half.x, 1.0, half.y)), from + Vector3.UP * 0.08 + b * Vector3(0.0, 0.0, -half.y))
	_danger.set_instance_shader_parameter(&"size_m", half)


## The glob leaves on a high arc toward the disc that has been filling since the sac swelled.
func _lob() -> void:
	var to: Vector3 = get_meta(&"lob_at", _p.global_position if _p else global_position)
	var from := muzzle_point(1.45)
	AttackKit.lob(from, to, lob_flight, AttackKit.ACID)
	Sfx.play_stream(EnemyAudio.kit("spit"), from, -3.0, 0.75)
	_lobbing = false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _state == WINDUP and not _lobbing and (_p != null or _on_threat) and is_instance_valid(_danger) and _hitstop == 0:
		_aim_lane()
	if _sac:
		var swell := clampf(_state_t / _cur_wind(), 0.0, 1.0) if _state == WINDUP else 0.0
		_sac.scale = Vector3.ONE * (1.0 + swell * 0.9 + sin(_state_t * 30.0) * 0.08 * swell)
		_sac.set_instance_shader_parameter(&"swell", swell)
