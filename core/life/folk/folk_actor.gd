extends Node3D
## One ambient person of the Realm (the folk: core/life/folk). A villager's body (the same VillagerRig, the same
## skeleton, shader and two-bone arm IK) driven by a role's script instead of a village routine: it sweeps a doorstep,
## carries water, plays tag, fiddles, keeps a watchman's round, mourns at the graves. The role (folk_roles.gd) sets
## where to go (`goal`, `speed`), which act to pose (`act`) and where to look; this node moves, turns, walks the gait,
## poses (folk_poses.gd) and smooths:
##   movement   speed eases with `1 - exp(-k dt)`, the yaw turns the same way (frame-rate independent), the legs walk the
##              villagers' heel-toe gait paced by the ground covered (no skating) and turn on the spot in steps;
##   LOD        the pose is made at the villagers' distance rates (npc_life.gd interval) and eased between updates
##              (blend_from / blend_to / blend_step), so nothing steps at 12 Hz; an act change is a 0.28 s crossfade
##              (xfade_check / xfade_apply); a person who is far, off screen or beyond range sleeps (no process);
##   overlays   a wave at the wanderer, a nod to a passer-by, applied on top of any act and eased in and out.
## Built once, at start-up (the mesh is a GenCache hit or built behind the loading cover), never mid-play.

const Rig := preload("res://core/life/village/villager_rig.gd")
const Life := preload("res://core/npc/npc_life.gd")
const Poses := preload("res://core/life/folk/folk_poses.gd")
const Roles := preload("res://core/life/folk/folk_roles.gd")

const GAITS := {"old": [0.26, 0.6, 0.011, 0.16], "child": [0.44, 1.05, 0.024, 0.42], "teen": [0.4, 0.95, 0.02, 0.34], "adult": [0.36, 0.88, 0.02, 0.3]}
const SLEEP_R := 100.0                    ## beyond this (m from the wanderer) the person does not run at all

var id := ""
var role := ""
var look := {}
var rig: Rig
var life: Life
var ctx: Dictionary = {}                  ## shared with the FolkStage: player (Vector3), eclipse (0..1), regard (0..1), alarm (bool), folk (Array of actors)
var data := {}                            ## the role's own state

# what the role asks for
var goal := Vector2.ZERO                  ## where to walk (world x, z)
var has_goal := false
var speed := 1.0                          ## top speed toward it (m/s)
var act := "stand"
var face := INF                           ## yaw to hold when standing (INF: keep it)
var look_pt := Vector3.INF                ## a world point the head follows (INF: the wanderer if near, else idle looks)
var phase := 0.0                          ## the act's own parameter (a counted second, a stroke)

# state
var _t := 0.0                             ## the person's own clock (the villagers' idle code reads it)
var speaking := false                     ## (villager_idle.gd reads these three)
var attend: Node3D = null
var _shift_x := 0.0
var act_t := 0.0                          ## seconds in the current act
var spd := 0.0                            ## smoothed ground speed
var walk_amt := 0.0
var gait := 0.0
var gait_g: Array = GAITS["adult"]
var off := 0.0                            ## the pose's root height offset
var wave_t := -1.0                        ## > 0: waving (counts down), eased by the pose
var nod_t := -1.0
var wave_cd := 0.0
var shift := Vector2.ZERO                 ## the pose's sideways / forward body shift (rig space)
var gy := 0.0
var awake := false
var held := false                         ## hidden by the stage (a flee, a far stage)

var _acc := 0.0
var _last_act := ""
var _gy_t := 0.0
var _look_to := Vector2.ZERO
var _look := Vector2.ZERO
var _look_t := 0.0
var _rng := RandomNumberGenerator.new()
var _glow_side := 0


func setup(p_id: String, p_role: String, p_look: Dictionary, p_ctx: Dictionary) -> void:
	id = p_id
	role = p_role
	look = p_look
	ctx = p_ctx
	name = "Folk_" + id
	_rng.seed = hash(id)
	_t_init()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF     # moved every rendered frame, like the villagers
	rig = Rig.create(look) as Rig
	add_child(rig)
	life = Life.new(hash(id))
	gait_g = GAITS.get(String(look.get("age", "adult")), GAITS["adult"])
	gait = float(absi(hash(id) >> 3) % 100) / 100.0
	Roles.init(self)
	set_awake(false)


func _t_init() -> void:
	_t = _rng.randf() * 10.0


## Awake: processing and visible. Asleep: nothing runs (the stage wakes people within range).
## The wanderer's position as the stage last shared it (villager_fidgets.wave reads this, as it does a villager's).
func _player_pos() -> Vector3:
	var p: Variant = ctx.get("player", Vector3.INF)
	return p if p is Vector3 else Vector3.INF


func set_awake(on: bool) -> void:
	awake = on
	visible = on and not held
	set_process(on and not held)


func hold(on: bool) -> void:
	held = on
	set_awake(awake)


var _far_acc := 0.0                ## frame time saved up while stepping every fourth frame (past 55 m)


func _process(dt: float) -> void:
	# past 55 m a person is a few pixels: the routine steps every fourth frame with the time saved up, as a villager's
	# does (30 a second at 120 fps; a walker moves 4 cm a step)
	var cam := get_viewport().get_camera_3d()
	var far := cam != null and cam.global_position.distance_squared_to(global_position) > 3025.0
	if far:
		_far_acc += dt
		if (Engine.get_process_frames() + get_instance_id()) % 4 != 0:
			return
		dt = _far_acc
	_far_acc = 0.0
	dt = minf(dt, 0.15 if far else 0.1)
	_t += dt
	act_t += dt
	Roles.tick(self, dt)
	if act != _last_act:
		_last_act = act
		act_t = 0.0
	_move(dt)
	_ground(dt)
	_overlays(dt)
	var iv := Life.interval(cam, global_position, spd > 0.15)
	if iv < 0.0:
		return
	_acc += dt
	if _acc >= iv:
		life.blend_from(rig)
		Poses.pose(self, _acc)
		life.xfade_check(rig, act + ("+w" if wave_t > 0.0 else ""), 0.28)
		life.xfade_apply(rig, _acc)
		_acc = 0.0
		life.blend_to(rig, iv * 1.08)
	else:
		life.blend_step(rig, _acc)


## Walk toward the goal: speed, yaw and the gait all ease with dt.
func _move(dt: float) -> void:
	var here := Vector2(global_position.x, global_position.z)
	var want := 0.0
	var dir := Vector2.ZERO
	if has_goal:
		var to := goal - here
		var d := to.length()
		if d > 0.04:
			dir = to / d
			want = speed * smoothstep(0.0, 0.7, d)
	spd = lerpf(spd, want, 1.0 - exp(-6.0 * dt))
	if spd < 0.02 and want == 0.0:
		spd = 0.0
	if spd > 0.0 and dir != Vector2.ZERO:
		here += dir * minf(spd * dt, (goal - here).length())
		global_position.x = here.x
		global_position.z = here.y
	var yaw_goal := rotation.y
	if spd > 0.25 and dir != Vector2.ZERO:
		yaw_goal = atan2(-dir.x, -dir.y)
	elif face != INF:
		yaw_goal = face
	rotation.y = lerp_angle(rotation.y, yaw_goal, 1.0 - exp(-(7.0 if spd > 0.25 else 4.0) * dt))
	walk_amt = move_toward(walk_amt, 1.0 if spd > 0.2 else 0.0, dt * 2.5)
	if walk_amt > 0.05:
		var stride := Life.calib_stride(rig, float(gait_g[0]), float(gait_g[1]), float(gait_g[2]) * rig.k)
		gait = fposmod(gait + spd * dt / (stride * maxf(walk_amt, 0.35)), 1.0)


## The ground under the person, four times a second, eased (no step at a slope's break).
func _ground(dt: float) -> void:
	_gy_t -= dt
	var py := global_position.y
	if _gy_t <= 0.0:
		_gy_t = 0.25
		var world := get_world_3d()
		if world != null:
			var q := PhysicsRayQueryParameters3D.create(Vector3(global_position.x, py + 3.0, global_position.z), Vector3(global_position.x, py - 6.0, global_position.z), Layers.WORLD)
			var hit := world.direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				gy = (hit.position as Vector3).y
	global_position.y = lerpf(py, gy, 1.0 - exp(-10.0 * dt))


## A wave at the wanderer and a nod to a passer-by count down here; the stage decides when they begin.
func _overlays(dt: float) -> void:
	wave_cd = maxf(0.0, wave_cd - dt)
	if wave_t > 0.0:
		wave_t = maxf(0.0, wave_t - dt)
	if nod_t > 0.0:
		nod_t = maxf(0.0, nod_t - dt)


func start_wave(secs := 2.6) -> void:
	wave_t = secs
	wave_cd = 50.0 + _rng.randf() * 40.0


func start_nod() -> void:
	nod_t = 1.1


## The head's target (yaw, pitch in head space), eased, with the wanderer drawing the eye when near and in front.
func gaze(dt: float) -> Vector2:
	var tgt := look_pt
	if tgt == Vector3.INF:
		var pp: Vector3 = ctx.get("player", Vector3.INF)
		if pp != Vector3.INF and pp.distance_to(global_position) < 6.0 and (pp - global_position).normalized().dot(-global_basis.z) > -0.2:
			tgt = pp + Vector3.UP * 1.5
	if tgt != Vector3.INF:
		var m := global_transform.affine_inverse() * tgt
		var hc: Vector3 = rig.hc
		var d := m / Rig.SCALE - hc
		var yw := clampf(atan2(-d.x, -d.z), -1.1, 1.1)
		var pt := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.5, 0.45)
		_look_to = Vector2(yw, -pt)
	else:
		_look_t -= dt
		if _look_t <= 0.0:
			_look_t = _rng.randf_range(2.0, 5.0)
			_look_to = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.1, 0.15)) if _rng.randf() < 0.6 else Vector2.ZERO
	_look = life.gaze(_look_to, dt, 3.0)
	return _look
