class_name Enemy
extends CharacterBody3D
## Melee crawler base. Flat steering, no navmesh. Strike adds Gloom; no player HP.

enum { IDLE, CHASE, WINDUP, STRIKE, RECOVER, DEAD }

const HP_BAR_SHADER := "res://core/enemy/health_bar.gdshader"
const HP_BAR_SIZE := Vector2(0.86, 0.1)   ## metres; same value as `size` in the shader
const HP_BAR_TRAIL_HOLD := 0.28           ## seconds the pale "just lost" strip waits before draining
const HP_BAR_TRAIL_RATE := 1.4            ## ratio per second it drains at
const TURN_RATE := 10.0                   ## same turn smoothing the Player uses on its rig
const CAPSULE_R := 0.35
const CAPSULE_H := 1.7

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
var home := Vector3.ZERO
var _leap_cd := 0.0

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

static var _hp_bar_mesh: QuadMesh


func _ready() -> void:
	add_to_group(Groups.ENEMY)
	collision_layer = Layers.HURTBOX | Layers.PROPS
	collision_mask = Layers.WORLD
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(46.0)
	hp = float(max_hp)
	_think_cd = randf() / think_hz
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


## `type.new() as Enemy` is null on a dynamically loaded script. Return the node as-is.
static func spawn(type: GDScript, at: Vector3, host: Node = null) -> Node:
	if type == null:
		return null
	if host == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			host = tree.current_scene
	if host == null:
		return null
	var pawn: Node = type.new()
	if pawn == null:
		return null
	host.add_child(pawn)
	pawn.global_position = at + Vector3(0.0, 0.05, 0.0)
	return pawn


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
func attach_rig() -> CharacterRig:
	var rig := CharacterRig.new()
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
	_flash = 0.12
	_refresh_hp(true)
	if from is Node3D:
		var away := global_position - (from as Node3D).global_position
		away.y = 0.0
		if away.length() > 0.05:
			_knock = away.normalized() * 4.8
	if hp <= 0.001:
		_die()


func station(at: Vector3) -> void:
	home = at
	global_position = at + Vector3(0.0, 0.05, 0.0)


func wake() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func sleep() -> void:
	# Stay drawn on the post. Hiding here made whole camps vanish until you walked in.
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func _remember_home() -> void:
	if home == Vector3.ZERO:
		home = global_position


func _pin_visuals() -> void:
	if _visual == null:
		return
	for node in _visual.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		gi.visibility_range_end = 0.0
		gi.visibility_range_end_margin = 0.0
		gi.extra_cull_margin = maxf(gi.extra_cull_margin, 2.4)
		gi.ignore_occlusion_culling = true


func _build() -> void:
	pass


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
	if home != Vector3.ZERO and global_position.y < home.y - 8.0:
		global_position = home + Vector3(0.0, 0.1, 0.0)
		velocity = Vector3.ZERO
		_set_state(IDLE)
	_think_cd -= delta
	if _think_cd <= 0.0:
		_think_cd = 1.0 / think_hz
		_think()
	if _state == CHASE:
		_aim_at_player()
	_leap_cd = maxf(0.0, _leap_cd - delta)
	_move(delta)
	_flash_visual(delta)
	_tick_hp_trail(delta)
	if _hp_bar:
		_hp_bar.visible = _state != IDLE or hp < float(max_hp) - 0.01


func _player_planar() -> Dictionary:
	var player := _player()
	if player == null:
		return {"player": null, "to": Vector3.ZERO, "dist": INF}
	var to := player.global_position - global_position
	to.y = 0.0
	return {"player": player, "to": to, "dist": to.length()}


## Light makes them slink, it does not freeze them. Sanctuary / river zones used to pin Wretches.
func _aim_at_player() -> void:
	var info := _player_planar()
	var dist: float = info.dist
	var to: Vector3 = info.to
	if info.player == null or dist < 0.05:
		_wish = Vector3.ZERO
		return
	_wish = to / dist
	if light_averse and LightGrid.is_lit(global_position):
		_wish *= 0.45


func _think() -> void:
	var info := _player_planar()
	var player: Player = info.player
	if player == null:
		_hold_post(_home_planar())
		return
	var to: Vector3 = info.to
	var dist: float = info.dist
	var from_home := _home_planar()
	match _state:
		IDLE:
			if dist <= chase_range:
				_aim_at_player()
				_set_state(CHASE)
			else:
				_hold_post(from_home)
		CHASE:
			if dist > chase_range * 1.2 or from_home > hunt_leash:
				_set_state(IDLE)
				_hold_post(from_home)
			elif dist <= strike_range:
				_face_dir = to / maxf(dist, 0.001)
				_set_state(WINDUP)
			else:
				_aim_at_player()
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
				player.add_gloom_from_enemy(strike_gloom)
			_set_state(RECOVER)
		RECOVER:
			_wish = Vector3.ZERO
			if _state_t >= 0.55:
				_set_state(CHASE if dist <= chase_range and from_home <= hunt_leash else IDLE)


func _move(delta: float) -> void:
	_state_t += delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	var steer := _wish * walk_speed
	if _state == WINDUP or _state == STRIKE or _state == RECOVER:
		steer = Vector3.ZERO
		_stuck_t = 0.0
	elif _state == CHASE and is_on_floor() and _wish.length_squared() > 0.12:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var info := _player_planar()
		var dist: float = info.dist
		if leaper and _leap_cd <= 0.0 and dist > 3.2 and dist < 10.0:
			velocity.y = 6.8
			steer = _wish * walk_speed * 1.55
			_leap_cd = 1.85
			_stuck_t = 0.0
		elif crawler and _leap_cd <= 0.0:
			velocity.y = 3.6
			steer = _wish * walk_speed * 1.25
			_leap_cd = 0.62
			_stuck_t = 0.0
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
	velocity.x = steer.x + _knock.x
	velocity.z = steer.z + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, delta * 14.0)
	move_and_slide()
	_turn_toward(_wish if _wish.length_squared() > 0.0025 else _face_dir, delta)
	if _rig:
		var info := _player_planar()
		if info.dist < 16.0:
			_rig.animate(velocity, is_on_floor(), delta)


## Smoothed like Player.visual so the rig's turn lean and cloth swing see a real turn rate.
func _turn_toward(dir: Vector3, delta: float) -> void:
	if _face == null or dir.length_squared() < 0.0025:
		return
	_face.rotation.y = lerp_angle(_face.rotation.y, atan2(-dir.x, -dir.z), clampf(TURN_RATE * delta, 0.0, 1.0))


func _set_state(next: int) -> void:
	_state = next
	_state_t = 0.0
	_on_state(next)


## Hook for subclasses. Default: the shared rig's cast gesture on windup.
func _on_state(next: int) -> void:
	if next == WINDUP and _rig:
		_rig.cast()


func _die() -> void:
	_state = DEAD
	_wish = Vector3.ZERO
	collision_layer = 0
	if _hp_bar:
		_hp_bar.visible = false
	Events.enemy_killed.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


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
	var s := 1.0 + _flash * 0.4
	_visual.scale = Vector3(s, s, s)


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
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Player
