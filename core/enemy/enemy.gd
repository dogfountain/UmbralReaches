class_name Enemy
extends CharacterBody3D
## Melee crawler base. Flat steering, no navmesh. Strike adds Gloom; no player HP.

enum { IDLE, CHASE, WINDUP, STRIKE, RECOVER, DEAD, LEAP_PREP, AIRBORNE }

const HP_BAR_SHADER := "res://core/enemy/health_bar.gdshader"
const HP_BAR_SIZE := Vector2(0.86, 0.1)   ## metres; same value as `size` in the shader
const HP_BAR_TRAIL_HOLD := 0.28           ## seconds the pale "just lost" strip waits before draining
const HP_BAR_TRAIL_RATE := 1.4            ## ratio per second it drains at
const TURN_RATE := 10.0                   ## same turn smoothing the Player uses on its rig
const CAPSULE_R := 0.35
const CAPSULE_H := 1.7
const MARK_MAX := 3
const MARK_LIFE := 5.0
const HIT_COL := Color(0.86, 0.8, 1.0)
const HIT_BIG := Color(1.0, 0.55, 0.3)

@export var max_hp := 3
@export var walk_speed := 3.4
@export var chase_range := 11.0
@export var strike_range := 1.35
@export var strike_gloom := 25.0
@export var think_hz := 10.0
@export var sleep_range := 46.0
@export var hunt_leash := 14.0
@export var light_averse := true
@export var gravity := 16.0
@export var hp_bar_y := 2.02
@export var crawler := false
@export var leaper := false
@export_group("Leap")
@export var leap_min := 4.0             ## metres; closer than this it just walks in
@export var leap_max := 13.0            ## metres of horizontal pounce
@export var leap_apex := 1.9            ## metres above the higher end of the jump
@export var leap_prep := 0.45           ## crouch telegraph, seconds — the player's dodge window
@export var leap_cooldown := 2.6
@export var leap_lead := 0.6            ## 0 = jump at where you are, 1 = where you will be
@export var hop_len := 3.2              ## crawler hop length
@export_group("")
var home := Vector3.ZERO
var _leap_cd := 0.0
var _hop_cd := 0.0

var hp := 3.0
var _state := IDLE
var _think_cd := 0.0
var _state_t := 0.0
var _knock := Vector3.ZERO
var _flash := 0.0
var _wish := Vector3.ZERO
var _face_dir := Vector3.ZERO
var _visual: Node3D
var _face: Node3D               ## what turns to face travel; subclasses may point it at the rig itself
var _rig: CharacterRig          ## shared stride / cast; same class the Player drives
var _hp_bar: MeshInstance3D
var _hp_trail := 1.0
var _hp_trail_hold := 0.0
var _stuck_t := 0.0
var _p: Player
var _to := Vector3.ZERO
var _dist := INF
var _hitstop := 0
var marks := 0
var _mark_t := 0.0
var _pips: Array[MeshInstance3D] = []
var _ballistic := false
var _air_t := 0.0
var _pounced := false
var _squash := 0.0

var _flesh: Array[MeshInstance3D] = []
var _hit_fx := 0.0
var _glint := 0.0
var _dissolve := 0.0
var _flank := 0.0            ## per-enemy approach angle so packs surround instead of queue
var _sep := Vector3.ZERO     ## separation from packmates, refreshed at think rate
var _lit_t := 0.0            ## seconds the player has been sheltering in light

const LIGHT_MARGIN := 0.6    ## enemies stop this far outside any lit brazier / ward radius
const SFX_DIE := "res://art/audio/enemy_die.wav"
const SFX_MARK := "res://art/audio/mark_tick.wav"
const SFX_SHRIEK := "res://art/audio/pounce_shriek.wav"

static var _pip_mesh: SphereMesh

static var _hp_bar_mesh: QuadMesh


func _ready() -> void:
	add_to_group(Groups.ENEMY)
	collision_layer = Layers.HURTBOX | Layers.PROPS
	collision_mask = Layers.WORLD
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(46.0)
	hp = float(max_hp)
	_think_cd = randf() / think_hz
	_flank = randf_range(-0.55, 0.55)
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_face = _visual
	_ensure_capsule()
	_build()
	_pin_visuals()
	if _hp_bar == null:
		_make_hp_bar()
	call_deferred("_remember_home")


func _ensure_capsule() -> void:
	if get_node_or_null("Collision") != null:
		return
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_R
	cap.height = CAPSULE_H
	col.shape = cap
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)


## Same CharacterRig the wanderer uses. dress_default off so types paint their own look.
func attach_rig(custom: CharacterRig = null) -> CharacterRig:
	var rig := custom if custom != null else CharacterRig.new()
	rig.dress_default = false
	rig.rim_light = false
	rig.driven = true
	rig.melee = true
	rig.walk_speed = walk_speed
	_visual.add_child(rig)
	if rig.socket("chest") == null:
		rig._build()
	_face = rig
	_rig = rig
	return rig


## Bare mannequin on the shared sockets. Types pass a skin; they do not walk bone paths.
func dress_dummy(skin: Material) -> void:
	if _rig == null:
		return
	_limb("chest", "Torso", ProcMesh.capsule(0.16, 0.58), Vector3(0.0, 0.02, 0.0), skin)
	_limb("head", "Head", ProcMesh.sphere(0.11, 0.18, 10, 6), Vector3(0.0, 0.04, 0.0), skin)
	_limb("shoulder_l", "ArmL", ProcMesh.cyl(0.045, 0.05, 0.58, 8, 1), Vector3(0.0, -0.28, 0.0), skin)
	_limb("shoulder_r", "ArmR", ProcMesh.cyl(0.045, 0.05, 0.58, 8, 1), Vector3(0.0, -0.28, 0.0), skin)
	_limb("hip_l", "LegL", ProcMesh.cyl(0.055, 0.048, 0.78, 8, 1), Vector3(0.0, -0.40, 0.0), skin)
	_limb("hip_r", "LegR", ProcMesh.cyl(0.055, 0.048, 0.78, 8, 1), Vector3(0.0, -0.40, 0.0), skin)


func _limb(socket_name: String, n_name: String, mesh: Mesh, at: Vector3, skin: Material) -> void:
	var joint := _rig.socket(socket_name)
	if joint == null:
		return
	ProcMesh.mesh(joint, n_name, mesh, skin, at, Vector3.ZERO, false)


## Damage comes from anything with this method (the bolt finds it by walking up from the collider).
func take_hit(dmg: float, from: Node = null) -> void:
	if _state == DEAD:
		return
	hp = maxf(hp - dmg, 0.0)
	_flash = 0.08
	_hit_fx = 1.0
	var at := global_position + Vector3.UP * (hp_bar_y * 0.6)
	Vfx.burst(at, Color(1.6, 0.8, 2.4), {"count": 14, "life": 0.35, "speed": Vector2(3.0, 6.5), "size": 0.035, "gravity": -9.0, "trail": 0.08})
	Vfx.burst(at, Color(0.35, 0.05, 0.12), {"count": 10, "life": 0.5, "speed": Vector2(1.0, 3.0), "size": 0.09, "gravity": -7.0, "additive": false})
	var big := dmg >= 3.0
	HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.35), _dmg_text(dmg), HIT_BIG if big else HIT_COL, big)
	_hitstop = 3
	_refresh_hp(true)
	var p := _player()
	if p:
		p.cast_impulse()
	if from is Node3D:
		var away := global_position - (from as Node3D).global_position
		away.y = 0.0
		if away.length() > 0.05:
			_knock = away.normalized() * 4.8
	if hp <= 0.001:
		_die()
	elif dmg >= 2.0 and (_state == WINDUP or _state == LEAP_PREP):
		# heavy hits (Lance, a marked Nova) break a windup: the reward for reading the tell
		_set_state(RECOVER)
		_state_t = -0.25
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.6), "staggered", Color(1.0, 0.8, 0.5))


static func _dmg_text(dmg: float) -> String:
	return str(roundi(dmg)) if is_equal_approx(dmg, roundf(dmg)) else "%.1f" % dmg


func station(at: Vector3) -> void:
	home = at
	global_position = at + Vector3(0.0, 0.05, 0.0)


func wake() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func sleep() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_DISABLED


func _remember_home() -> void:
	if home == Vector3.ZERO:
		home = global_position


func _pin_visuals() -> void:
	if _hp_bar == null:
		return
	_hp_bar.visibility_range_end = 0.0
	_hp_bar.extra_cull_margin = maxf(_hp_bar.extra_cull_margin, 2.4)
	_hp_bar.ignore_occlusion_culling = true


func _build() -> void:
	pass


## Body parts from EnemyBody.dress(); their flesh shader reads hit_flash / glint / dissolve.
func set_flesh(parts: Array[MeshInstance3D]) -> void:
	_flesh = parts


func _flesh_param(param: StringName, v: float) -> void:
	for mi in _flesh:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(param, v)


# --- health bar ---------------------------------------------------------------------------------
# One quad, one shared mesh + material. Per-enemy state is three instance uniforms (health_bar.gdshader).

func _make_hp_bar() -> void:
	if _hp_bar_mesh == null:
		var mat := ShaderMaterial.new()
		mat.shader = load(HP_BAR_SHADER)
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE            # the shader scales it to HP_BAR_SIZE
		quad.material = mat
		_hp_bar_mesh = quad
	_hp_bar = MeshInstance3D.new()
	_hp_bar.name = "HealthBar"
	_hp_bar.mesh = _hp_bar_mesh
	_hp_bar.position = Vector3(0.0, hp_bar_y, 0.0)
	_hp_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hp_bar.extra_cull_margin = 1.2
	_hp_bar.visibility_range_end = 0.0
	_hp_bar.ignore_occlusion_culling = true
	add_child(_hp_bar)
	_hp_bar.set_instance_shader_parameter(&"segments", float(maxi(max_hp, 1)))
	_hp_trail = _hp_ratio()
	_refresh_hp(false)
	_make_pips()


## Umbral Marks: three violet beads over the bar. Shared mesh + material, toggled per stack.
func _make_pips() -> void:
	if _pip_mesh == null:
		_pip_mesh = SphereMesh.new()
		_pip_mesh.radius = 0.045
		_pip_mesh.height = 0.09
		_pip_mesh.radial_segments = 8
		_pip_mesh.rings = 4
		_pip_mesh.material = ProcMesh.glow_mat(Color(1.5, 0.6, 3.2))
	for i in MARK_MAX:
		var pip := MeshInstance3D.new()
		pip.mesh = _pip_mesh
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pip.position = Vector3((float(i) - 1.0) * 0.14, hp_bar_y + 0.16, 0.0)
		pip.visible = false
		add_child(pip)
		_pips.append(pip)


func add_mark(n := 1) -> void:
	if _state == DEAD:
		return
	marks = mini(MARK_MAX, marks + n)
	_mark_t = MARK_LIFE
	_refresh_pips()
	Sfx.play(SFX_MARK, global_position, -12.0, 0.9 + 0.12 * float(marks))
	Vfx.ring(global_position + Vector3.UP * (hp_bar_y + 0.16), 0.22 + 0.06 * float(marks), Color(1.4, 0.6, 3.0), 0.3, 0.2, Vector3.BACK)


func take_marks() -> int:
	var m := marks
	marks = 0
	_refresh_pips()
	return m


func _refresh_pips() -> void:
	for i in _pips.size():
		_pips[i].visible = i < marks


func is_alive() -> bool:
	return _state != DEAD


func shove(v: Vector3) -> void:
	_knock = Vector3(v.x, 0.0, v.z)
	if is_on_floor() and not _ballistic:
		velocity.y = 2.4


## Ballistic jump that lands on `target`. The apex sits `apex` m above the higher end, so up-stair
## and down-stair pounces both arc. Returns the flight time.
func launch_at(target: Vector3, apex: float) -> float:
	var from := global_position
	var dy := target.y - from.y
	var h := maxf(apex, dy + apex * 0.5)
	var vy := sqrt(2.0 * gravity * h)
	var t := vy / gravity + sqrt(2.0 * maxf(h - dy, 0.05) / gravity)
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	velocity = Vector3(flat.x / t, vy, flat.z / t)
	_ballistic = true
	_air_t = 0.0
	_pounced = false
	_stuck_t = 0.0
	return t


func flight_time(apex: float, dy: float) -> float:
	var h := maxf(apex, dy + apex * 0.5)
	var vy := sqrt(2.0 * gravity * h)
	return vy / gravity + sqrt(2.0 * maxf(h - dy, 0.05) / gravity)


func _hp_ratio() -> float:
	return clampf(hp / maxf(float(max_hp), 0.001), 0.0, 1.0)


## The fill is exact and instant (one third of the bar per hit with 3 HP). The pale trail behind it
## lags, so the size of the chunk you just took stays readable for a moment.
func _refresh_hp(hit: bool) -> void:
	if _hp_bar == null:
		return
	var ratio := _hp_ratio()
	_hp_bar.set_instance_shader_parameter(&"fill", ratio)
	if hit:
		_hp_trail_hold = HP_BAR_TRAIL_HOLD
	else:
		_hp_trail = ratio
	_hp_bar.set_instance_shader_parameter(&"trail", maxf(_hp_trail, ratio))


func _tick_hp_trail(delta: float) -> void:
	var ratio := _hp_ratio()
	if _hp_bar == null or _hp_trail <= ratio:
		return
	if _hp_trail_hold > 0.0:
		_hp_trail_hold -= delta
		return
	_hp_trail = maxf(move_toward(_hp_trail, ratio, delta * HP_BAR_TRAIL_RATE), ratio)
	_hp_bar.set_instance_shader_parameter(&"trail", _hp_trail)


# --- behaviour ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _state == DEAD:
		return
	if _hitstop > 0:
		_hitstop -= 1
		move_and_slide()
		return
	_cache_player()
	if home != Vector3.ZERO and global_position.y < home.y - 8.0:
		global_position = home + Vector3(0.0, 0.1, 0.0)
		velocity = Vector3.ZERO
		_set_state(IDLE)
	_think_cd -= delta
	if _think_cd <= 0.0:
		_think_cd = 1.0 / think_hz
		_think()
	if _state == CHASE and _chases_directly():
		_aim_at_player()
	elif _state == LEAP_PREP and _to.length_squared() > 0.01:
		_face_dir = _to.normalized()
	_leap_cd = maxf(0.0, _leap_cd - delta)
	_hop_cd = maxf(0.0, _hop_cd - delta)
	if marks > 0:
		_mark_t -= delta
		if _mark_t <= 0.0:
			marks = 0
			_refresh_pips()
	_move(delta)
	_flash_visual(delta)
	_tick_hp_trail(delta)
	if _hp_bar:
		_hp_bar.visible = _state != IDLE or hp < float(max_hp) - 0.01


func _cache_player() -> void:
	if not is_instance_valid(_p):
		_p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if _p == null:
		_to = Vector3.ZERO
		_dist = INF
		return
	_to = _p.global_position - global_position
	_to.y = 0.0
	_dist = _to.length()


func _update_separation() -> void:
	_sep = Vector3.ZERO
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		if node == self:
			continue
		var o := node as Node3D
		var d := global_position - o.global_position
		d.y = 0.0
		var l2 := d.length_squared()
		if l2 < 1.96 and l2 > 0.0001:
			_sep += d / l2 * 0.5


## Spitters kite instead of closing in; they override this to keep their own _wish.
func _chases_directly() -> bool:
	return true


## Light makes them slink, it does not freeze them. Sanctuary / river zones used to pin Wretches.
func _aim_at_player() -> void:
	if _p == null or _dist < 0.05:
		_wish = Vector3.ZERO
		return
	_wish = _to / _dist
	if _dist > 2.5:
		_wish = _wish.rotated(Vector3.UP, _flank * clampf((_dist - 2.5) / 6.0, 0.0, 1.0))
	if light_averse and LightGrid.is_lit(global_position):
		_wish *= 0.45


func _think() -> void:
	_update_separation()
	if _p != null and LightGrid.is_lit(_p.global_position):
		_lit_t += 1.0 / think_hz
	else:
		_lit_t = 0.0
	if _p == null:
		_hold_post(_home_planar())
		return
	var player := _p
	var to := _to
	var dist := _dist
	var from_home := _home_planar()
	match _state:
		IDLE:
			if dist <= chase_range:
				_aim_at_player()
				_set_state(CHASE)
			else:
				_hold_post(from_home)
		CHASE:
			if dist > chase_range * 1.2 or from_home > hunt_leash or _lit_t > 2.5:
				_set_state(IDLE)       # out of range, leashed, or the player is sheltering in light
				_hold_post(from_home)
			elif dist <= strike_range:
				_face_dir = to / maxf(dist, 0.001)
				_set_state(WINDUP)
			elif leaper and _leap_cd <= 0.0 and is_on_floor() and dist >= leap_min and dist <= leap_max and _lit_t <= 0.0 and _strike_clear(player):
				_face_dir = to / maxf(dist, 0.001)
				_set_state(LEAP_PREP)
			else:
				_aim_at_player()
		LEAP_PREP:
			_wish = Vector3.ZERO
			if dist > leap_max + 3.0:
				_set_state(CHASE)
			elif _state_t >= leap_prep:
				_pounce(player)
		AIRBORNE:
			pass
		WINDUP:
			_wish = Vector3.ZERO
			_face_dir = to / maxf(dist, 0.001)
			if dist > strike_range + 2.0:
				_set_state(CHASE)
			elif _state_t >= 0.42:
				_set_state(STRIKE)
		STRIKE:
			_wish = Vector3.ZERO
			if dist <= strike_range + 0.25 and _strike_clear(player):
				if player.is_evading():
					HitText.pop(player.global_position + Vector3.UP * 2.0, "evaded", Color(0.6, 0.75, 1.0))
				else:
					player.add_gloom_from_enemy(strike_gloom, global_position)
			_set_state(RECOVER)
		RECOVER:
			_wish = Vector3.ZERO
			if _state_t >= 0.55:
				_set_state(CHASE if dist <= chase_range and from_home <= hunt_leash else IDLE)


func _move(delta: float) -> void:
	_state_t += delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _ballistic:
		_move_ballistic(delta)
		return
	var steer := _wish * walk_speed
	if _state == WINDUP or _state == STRIKE or _state == RECOVER:
		steer = Vector3.ZERO
		_stuck_t = 0.0
	elif _state == CHASE and is_on_floor() and _wish.length_squared() > 0.12:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var dist := _dist
		if crawler and _hop_cd <= 0.0 and dist > 1.6:
			# Skittering hop that actually covers ground: ballistic, momentum kept in the air.
			var hop := minf(dist - 0.9, hop_len)
			launch_at(LightGrid.outside(global_position + _wish * hop, LIGHT_MARGIN), 0.55)
			_hop_cd = 0.75
			_move_ballistic(delta)
			return
		elif flat.length() < 0.28:
			_stuck_t += delta
			if _stuck_t > 0.22:
				var side := Vector3(-_wish.z, 0.0, _wish.x)
				if int(_stuck_t * 3.0) % 2 == 1:
					side = -side
				steer = (_wish * 0.4 + side).normalized() * walk_speed
				if is_on_floor():
					velocity.y = 2.2
		else:
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	if steer.length_squared() > 0.01:
		steer += _sep * walk_speed
	velocity.x = steer.x + _knock.x
	velocity.z = steer.z + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, delta * 14.0)
	_light_barrier(delta)
	move_and_slide()
	_turn_toward(_wish if _wish.length_squared() > 0.0025 else _face_dir, delta)
	if _rig:
		if _dist < 16.0:
			_rig.animate(velocity, is_on_floor(), delta)


## Airborne: keep the launch momentum (the old code rewrote x/z to walk speed every frame,
## which is why leaps went up instead of across). A pounce lands one strike in flight.
func _move_ballistic(delta: float) -> void:
	_air_t += delta
	velocity.x += _knock.x * delta * 4.0
	velocity.z += _knock.z * delta * 4.0
	_knock = _knock.move_toward(Vector3.ZERO, delta * 14.0)
	_light_barrier(delta)
	move_and_slide()
	if is_on_wall():
		velocity.x *= 0.25
		velocity.z *= 0.25
	if _state == AIRBORNE and not _pounced and _p != null:
		var reach := _p.global_position - global_position
		if reach.length_squared() < 1.7 * 1.7:
			_pounced = true
			if _p.is_evading():
				HitText.pop(_p.global_position + Vector3.UP * 2.0, "evaded", Color(0.6, 0.75, 1.0))
			else:
				_p.add_gloom_from_enemy(strike_gloom, global_position)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_turn_toward(flat if flat.length_squared() > 0.25 else _face_dir, delta)
	if _rig and _dist < 24.0:
		_rig.animate(velocity, false, delta)
	if _air_t > 0.12 and is_on_floor():
		_ballistic = false
		velocity.x *= 0.2
		velocity.z *= 0.2
		_squash = 0.28
		if _state == AIRBORNE:
			_set_state(RECOVER)
			_state_t = -0.3        # longer stagger after a pounce: the punish window


func _pounce(player: Player) -> void:
	var dy := player.global_position.y - global_position.y
	var t := flight_time(leap_apex, dy)
	var pv := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var target := player.global_position + pv * t * leap_lead
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() > leap_max + 1.5:
		flat = flat.normalized() * (leap_max + 1.5)
	target = Vector3(global_position.x + flat.x, player.global_position.y, global_position.z + flat.z)
	launch_at(LightGrid.outside(target, LIGHT_MARGIN), leap_apex)
	Sfx.play(SFX_SHRIEK, global_position, -4.0)
	_leap_cd = leap_cooldown
	_set_state(AIRBORNE)


## Lit braziers and wards are hard sanctuaries: strip any velocity that points into a zone and
## push out if already inside (knockback, a ward planted on top of them, a brazier just lit).
func _light_barrier(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var ahead := LightGrid.repel(global_position + flat * delta, LIGHT_MARGIN)
	if ahead == Vector3.ZERO:
		return
	var n := ahead.normalized()
	var inward := flat.dot(-n)
	if inward > 0.0:
		flat += n * inward
	var inside := LightGrid.repel(global_position, LIGHT_MARGIN)
	if inside != Vector3.ZERO:
		flat += inside.normalized() * minf(inside.length() * 10.0, 7.0)
		if _ballistic:
			_ballistic = false            # slammed into the light mid-air: drop out of the pounce
			if _state == AIRBORNE:
				_set_state(RECOVER)
	velocity.x = flat.x
	velocity.z = flat.z


## Smoothed like Player.visual so the rig's turn lean and cloth swing see a real turn rate.
func _turn_toward(dir: Vector3, delta: float) -> void:
	if _face == null or dir.length_squared() < 0.0025:
		return
	_face.rotation.y = lerp_angle(_face.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-TURN_RATE * delta))


func _set_state(next: int) -> void:
	_state = next
	_state_t = 0.0
	_on_state(next)


## Hook for subclasses. Default: the shared rig's cast gesture on windup.
func _on_state(next: int) -> void:
	if (next == WINDUP or next == LEAP_PREP) and _rig:
		_rig.cast()
	if next == WINDUP or next == LEAP_PREP:
		_glint = 1.0


func _die() -> void:
	_state = DEAD
	_wish = Vector3.ZERO
	collision_layer = 0
	if _hp_bar:
		_hp_bar.visible = false
	for pip in _pips:
		pip.visible = false
	Events.enemy_killed.emit(self)
	var at := global_position + Vector3.UP * (hp_bar_y * 0.5)
	Sfx.play(SFX_DIE, at, -6.0)
	Vfx.burst(at, Color(0.03, 0.02, 0.05, 0.8), {"count": 26, "life": 1.4, "speed": Vector2(0.3, 1.4), "size": 0.32, "gravity": 0.9, "radius": 0.45, "additive": false, "turbulence": true})
	Vfx.burst(at, Color(1.2, 0.45, 2.4), {"count": 30, "life": 1.1, "speed": Vector2(0.5, 2.2), "size": 0.05, "gravity": 1.4, "radius": 0.5, "turbulence": true})
	Vfx.light(at, Color(0.7, 0.4, 1.0), 2.2, 4.0, 0.6)
	var tw := create_tween()
	tw.tween_method(_set_dissolve, 0.0, 1.0, 0.9)
	tw.tween_callback(queue_free)


func _set_dissolve(v: float) -> void:
	_dissolve = v
	_flesh_param(&"dissolve", v)


func _strike_clear(player: Player) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var from := global_position + Vector3.UP * 1.1
	var to := player.global_position + Vector3.UP * 1.1
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Layers.WORLD
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _flash_visual(delta: float) -> void:
	if _visual == null:
		return
	_flash = maxf(0.0, _flash - delta)
	if _hit_fx > 0.0:
		_hit_fx = maxf(0.0, _hit_fx - delta * 7.0)
		_flesh_param(&"hit_flash", _hit_fx)
	if _glint > 0.0:
		_glint = maxf(0.0, _glint - delta * 1.6)
		_flesh_param(&"glint", _glint)
	var s := 1.0 + _flash * 0.4
	if _state == LEAP_PREP:
		_squash = move_toward(_squash, 0.24, delta * 0.9)    # coil: the tell before a pounce
	else:
		_squash = move_toward(_squash, 0.0, delta * 1.6)
	_visual.scale = Vector3(s * (1.0 + _squash * 0.45), s * (1.0 - _squash), s * (1.0 + _squash * 0.45))


func _hold_post(from_home: float) -> void:
	if home == Vector3.ZERO or from_home < 0.45:
		_wish = Vector3.ZERO
		return
	var back := home - global_position
	back.y = 0.0
	_wish = back / maxf(back.length(), 0.001)


func _home_planar() -> float:
	if home == Vector3.ZERO:
		return 0.0
	var d := home - global_position
	d.y = 0.0
	return d.length()


func _player() -> Player:
	if not is_instance_valid(_p):
		_p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	return _p
