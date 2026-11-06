extends Interactable
## r36 a horse (core/world/mount): one creature-shader MultiMesh instance (life_kit's horse_* meshes:
## legs and head animated on the GPU from the gait phase), a state, and the ride. Stands at its
## hitching post (or where it was left) grazing; [E] buys it there, rides it once owned; [E] while
## riding gets down. Player.riding hands the drive to `drive()` every physics frame.
##   walk / trot / gallop by the move stick and sprint; turns toward the move direction at the
##   breed's rate; follows the ground with a ray (refuses a step taller than `climb`); stops at a
##   wall; slows to a walk in water unless it wades; a draught throws the hollowed aside (trample).

const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const DB := preload("res://core/world/mount/horse_db.gd")
const VAudio := preload("res://core/life/village/village_audio.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")

var breed := "palfrey"
var at_post := true              ## standing at its hitching post (for sale until owned)
var rider: Node3D = null
var speed := 0.0
var _mmi: MultiMeshInstance3D
var _d: Dictionary
var _yaw := 0.0
var _phase := 0.0
var _phase_prev := 0.0                ## r36 smooth: the phase a tick ago (drawn blended to the frame)
var _head := 0.0                 ## head pitch (grazing lowers it)
var _graze_t := 0.0
var _sfx_t := 0.0
var _turn_v := 0.0
var _mount_t := 9.0
var _mount_from := Vector3.ZERO
const LEAVE_T := 1.0
const MOUNT_T := 1.15                ## r36: step up, foot in the stirrup, swing over, settle
const STIRRUP_Y := 0.62              ## the left stirrup's tread above the ground (x the breed's scale)
const SEAT_Y := 1.315             ## the saddle's seat top, x the breed's scale, above the horse's origin
var _space: PhysicsDirectSpaceState3D
var _leave_t := 0.0                  ## walking out of a boss ring before getting down
var _leave_dir := Vector3.ZERO
var _trampled := {}                  ## enemy instance id -> msec of the last trample on it


func _ready() -> void:
	_d = DB.BREEDS.get(breed, DB.BREEDS["palfrey"])
	add_to_group(Groups.INTERACTABLE)
	add_to_group(&"horse")
	_mmi = LifeKit.group(String(_d.mesh), 1)
	_mmi.top_level = true            # placed every rendered frame from the interpolated transform (_process)
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mmi.visibility_range_end = 120.0
	add_child(_mmi)
	_yaw = global_basis.get_euler().y
	_write()


func can_interact() -> bool:
	return true


func interact_text() -> String:
	var k := Interactable.prompt_key()
	if rider != null:
		return "[%s]  Get down" % k
	if not owned():
		return "[%s]  Buy the %s  (%d grave ash)" % [k, String(_d.name), int(_d.cost)]
	return "[%s]  Ride the %s" % [k, String(_d.name)]


func interact_reach() -> float:
	return 2.6


func interact_feel() -> StringName:
	return &"cast"


func interact(by: Node) -> void:
	var p := by as Player
	if p == null:
		return
	if rider != null:
		dismount()
		return
	if not owned():
		if Travel.count("grave_ash") < int(_d.cost):
			Events.toast.emit("%s  It wants %d grave ash; you carry %d." % [String(_d.line), int(_d.cost), Travel.count("grave_ash")])
			return
		Travel.items["grave_ash"] = Travel.count("grave_ash") - int(_d.cost)
		var st := state()
		(st.owned as Array).append(breed)
		st["ride"] = breed
		Travel.save_soon()
		Events.toast.emit("The %s is yours. Ride it, or call it with [H] wherever you are." % String(_d.name))
		return
	mount(p)


func owned() -> bool:
	return (state().owned as Array).has(breed)


static func state() -> Dictionary:
	var st := Travel.system_state("stable")
	if not (st.get("owned") is Array):
		st["owned"] = []
	if not st.has("ride"):
		st["ride"] = ""
	return st


func mount(p: Player) -> void:
	rider = p
	_mount_t = 0.0
	_mount_from = p.global_position
	at_post = false
	state()["ride"] = breed
	p.riding = self
	Sfx.play("res://art/audio/ward_chime.wav", global_position, -14.0, 0.6)


func dismount() -> void:
	var p := rider as Player
	rider = null
	speed = 0.0
	if p != null and is_instance_valid(p):
		p.riding = null
		var side := global_basis.x.normalized()
		var to := global_position + side * 1.1
		p.teleport(_ground(to) + Vector3.UP * 0.1)


## Player.riding: move the horse from the rider's wish (world xz) and sprint; seat the rider.
func drive(p: Player, wish: Vector3, sprint: bool, dt: float) -> void:
	_space = get_world_3d().direct_space_state
	if Player.boss_fight_active(get_tree()):
		if _leave_t <= 0.0:
			_leave_t = LEAVE_T
			_leave_dir = _away_from_ring()
			Events.toast.emit("The horse will go no nearer. It turns.")
		_leave_t -= dt
		if _leave_t <= 0.0:
			_leave_t = 0.0
			dismount()
			return
		wish = _leave_dir                       # a second of walking out, then down at the edge facing the fight
		sprint = false
	else:
		_leave_t = 0.0
	_phase_prev = _phase
	var want := 0.0
	var w := Vector3(wish.x, 0.0, wish.z)
	if _mount_t < MOUNT_T:
		w = Vector3.ZERO                       # r36: it stands while the rider climbs on
	if w.length() > 0.1:
		want = float(_d.gallop) if sprint else (float(_d.trot) if w.length() > 0.7 else float(_d.walk))
		var target_yaw := atan2(-w.x, -w.z)
		var want_turn := clampf(angle_difference(_yaw, target_yaw) * 4.0, -1.0, 1.0) * float(_d.turn) * (0.6 if speed > 8.0 else 1.0)
		_turn_v = lerpf(_turn_v, want_turn, 1.0 - exp(-8.0 * dt))       # eases into and out of a turn
	else:
		_turn_v = lerpf(_turn_v, 0.0, 1.0 - exp(-8.0 * dt))
	_yaw += _turn_v * dt
	var wading := RealmLand.in_water(global_position.x, global_position.z)
	if wading and not bool(_d.get("wade", false)):
		want = minf(want, float(_d.walk))
	speed = move_toward(speed, want, (6.0 if want > speed else 9.0) * dt)
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	if speed > 0.05:
		var step := fwd * speed * dt
		var next := global_position + step
		var g := _ground(next)
		var chest := global_position + Vector3.UP * 1.2 * _scale()
		var wall := _space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + fwd * (0.9 * _scale() + speed * dt), Layers.WORLD | Layers.PROPS, [p.get_rid()]))
		var blocked := g.y - global_position.y > float(_d.climb) or g.y - global_position.y < -6.0
		if not wall.is_empty() and not blocked:
			# a wall: slide along it (scrub off the speed into it) rather than stop dead
			var n: Vector3 = wall.normal
			n.y = 0.0
			if n.length() > 0.01:
				n = n.normalized()
				var slide := fwd - n * fwd.dot(n)
				if slide.length() > 0.2:
					var sn := global_position + slide.normalized() * speed * dt * slide.length()
					var sg := _ground(sn)
					if sg.y - global_position.y <= float(_d.climb) and sg.y - global_position.y >= -6.0:
						global_position = Vector3(sn.x, lerpf(global_position.y, sg.y, 1.0 - exp(-14.0 * dt)), sn.z)
			speed = move_toward(speed, 0.0, maxf(speed, 3.0) / 0.2 * dt)
		elif blocked:
			speed = move_toward(speed, 0.0, maxf(speed, 3.0) / 0.2 * dt)       # eased to a stop in ~0.2 s
		else:
			global_position = Vector3(next.x, lerpf(global_position.y, g.y, 1.0 - exp(-14.0 * dt)), next.z)
			_phase += speed * dt * 2.6 / _scale()            # unwrapped: a wrap would swing the legs back a frame
	if bool(_d.get("trample", false)) and speed > 6.0:
		_trample(fwd)
	global_basis = Basis(Vector3.UP, _yaw)
	_head = lerpf(_head, -0.15 if speed > 7.0 else 0.0, 1.0 - exp(-4.0 * dt))
	_write()
	_hooves(dt)
	# the rider sits the saddle, facing where the horse faces
	# the pelvis on the saddle's seat (the seat's top is 1.315 x scale above the horse's origin; the
	# rig's pelvis stands 0.955 above its feet), a hand's width behind the pommel
	var seat := global_position + Vector3.UP * (SEAT_Y * _scale() - CharacterRig.H_PELVIS + 0.02 + _bob()) + fwd * (0.04 * _scale())
	var vis := p.get_node_or_null("Visual") as Node3D
	if _mount_t < MOUNT_T:
		# r36: getting on, from the near (left) side: a step to the stirrup, the left foot in it and a
		# spring up, the right leg over the rump, down into the saddle. The rig poses the legs
		# from `mount` and its offset from the seat (character_rig _ride_legs).
		_mount_t += dt
		var m := clampf(_mount_t / MOUNT_T, 0.0, 1.0)
		var sc := _scale()
		var left := -global_basis.x.normalized()
		var side := global_position + left * 0.7 * sc + fwd * 0.03 * sc
		side.y = global_position.y
		var stand := global_position + left * 0.5 * sc + fwd * 0.03 * sc + Vector3.UP * (STIRRUP_Y * sc)
		var over := seat + Vector3.UP * 0.16 + left * 0.06 * sc
		var at: Vector3
		if m < 0.22:
			at = _mount_from.lerp(side, smoothstep(0.0, 1.0, m / 0.22))
		elif m < 0.5:
			at = side.lerp(stand, smoothstep(0.0, 1.0, (m - 0.22) / 0.28))
		elif m < 0.84:
			var e := smoothstep(0.0, 1.0, (m - 0.5) / 0.34)
			at = stand.lerp(over, e) + Vector3.UP * sin(e * PI) * 0.08
		else:
			at = over.lerp(seat, smoothstep(0.0, 1.0, (m - 0.84) / 0.16))
		if vis and "mount" in vis:
			var d := at - seat
			vis.set("mount", m if m < 1.0 else -1.0)
			vis.set("mount_off", Vector3(d.dot(-left), d.y, -d.dot(fwd)))
		seat = at
	elif vis and "mount" in vis and float(vis.get("mount")) >= 0.0:
		vis.set("mount", -1.0)
	p.global_position = seat
	if vis and "saddle" in vis:
		# the barrel under the rider, in the coat's space (origin at the pelvis): its centre 0.98 x
		# scale above the horse's origin, so (0.98 - 1.315) x scale below the seat
		var g: float = float(LifeKit.HORSES.get(breed, {}).get("girth", 1.0))
		vis.set("saddle", Vector3(0.25 * g * _scale() * 1.05, (0.98 - SEAT_Y) * _scale() - 0.02, 0.285 * _scale() * 1.05))
	if vis:
		# facing where the horse faces, in WORLD space: the player node itself turns with the camera,
		# so a local yaw sat the rider sideways
		var cur := vis.global_rotation.y
		vis.global_rotation.y = lerp_angle(cur, _yaw, 1.0 - exp(-12.0 * dt))
	p.velocity = fwd * speed


func _process(dt: float) -> void:
	if _mmi:
		_mmi.global_transform = get_global_transform_interpolated()
	# a rider that died, was hollowed or was moved off (a respawn, travel) is no longer riding
	if rider != null and (not is_instance_valid(rider) or rider.get("riding") != self):
		rider = null
		speed = 0.0
	if rider != null:
		# ridden: drive() steps the gait on the tick; draw it at the frame's moment, as the body is
		_write(lerpf(_phase_prev, _phase, Engine.get_physics_interpolation_fraction()))
		return
	# standing: graze now and then, flick the head up
	_graze_t -= dt
	if _graze_t <= 0.0:
		_graze_t = randf_range(4.0, 9.0)
	var down := _graze_t > 2.0
	_head = lerpf(_head, 0.7 if down else 0.0, 1.0 - exp(-1.5 * dt))
	if speed > 0.0:
		speed = move_toward(speed, 0.0, 9.0 * dt)
	_write()


func _bob(ph := NAN) -> float:
	if is_nan(ph):
		ph = _phase
	var k := clampf(speed / 9.0, 0.0, 1.0)
	return absf(sin(ph)) * 0.06 * k * _scale() - 0.03 * k * _scale()


func _write(ph := NAN) -> void:
	if _mmi == null:
		return
	if is_nan(ph):
		ph = _phase
	var mm := _mmi.multimesh
	# the gait moves the whole body: a bob twice a stride and a little pitch, more at a gallop
	var k := clampf(speed / 9.0, 0.0, 1.0)
	mm.set_instance_transform(0, Transform3D(Basis(Vector3.RIGHT, sin(ph * 2.0 + 0.6) * 0.035 * k), Vector3(0, _bob(ph), 0)))
	mm.set_instance_custom_data(0, Color(0.0, 0.0, ph if speed > 0.05 else 0.0, _head))


## Flat direction from the nearest boss ring's centre out through the horse.
func _away_from_ring() -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var n := a as Node3D
		if n == null:
			continue
		var d := global_position - n.global_position
		d.y = 0.0
		if d.length() < bd:
			bd = d.length()
			best = d
	return best.normalized() if best.length() > 0.1 else -global_basis.z


func _scale() -> float:
	return float((LifeKit.RIG.get(String(_d.mesh), {}) as Dictionary).get("head_pivot", Vector3(0, 1.42, 0)).y)


func _hooves(dt: float) -> void:
	if speed < 1.0:
		return
	_sfx_t -= dt
	if _sfx_t <= 0.0:
		_sfx_t = clampf(1.6 / speed, 0.12, 0.5)
		VAudio.play("dig", global_position, -16.0 + minf(speed, 10.0) * 0.6, randf_range(0.7, 0.85))


func _trample(fwd: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive() or e.boss:
			continue
		var d := e.global_position - global_position
		if d.length() < 1.6 * _scale() and d.dot(fwd) > 0.0:
			var id := e.get_instance_id()
			var now := Time.get_ticks_msec()
			if now - int(_trampled.get(id, -9999)) < 1000:
				continue                                   # once a second per body: bodies fly and live
			_trampled[id] = now
			e.take_hit(1.0, rider)
			e.shove((fwd + d.normalized()).normalized() * 9.0)


func _ground(at: Vector3) -> Vector3:
	var sp := _space if _space else get_world_3d().direct_space_state
	var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 8.0, Layers.WORLD))
	return (hit.position as Vector3) if not hit.is_empty() else at
