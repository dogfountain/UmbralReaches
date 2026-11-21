class_name PlayerCamera
extends Node
## Camera feel: FOV kick, strafe roll, landing dip, the spring arm and occluder rays.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Access := preload("res://ui/access.gd")

var _fov_kick := 0.0
var _fov_want := 0.0                    ## speed FOV kick target (physics tick); eased per rendered frame
var _fov_burst := 0.0                   ## a sudden widening (Rift Step, slide entry), eased per frame
var _land_dip_want := 0.0
var _shake_want := 0.0
var _roll_want := 0.0
var _cam_len := Player.ARM_LEN
var _cam_roll := 0.0
var _thin_hold := 0.0
var _fight_k := 0.0
var _arm_q: PhysicsShapeQueryParameters3D
var _thin_q: PhysicsShapeQueryParameters3D
var _thin_ray: PhysicsRayQueryParameters3D   ## reused by _thin_occluder (r35: five rays, no allocation each)
var _sight_ray: PhysicsRayQueryParameters3D
var _sight_hold := 0.0
const THIN_TRUNK_R := 1.2                ## m: a trunk collider thinner than this never shortens the boom on horseback (its bark fades near the lens)
const LEAD_T := 0.5                      ## s: how far ahead the boom looks (a find that far off counts for nothing yet)
var dbg := Vector4.ZERO                  ## last frame: the cast reach, the look-ahead reach, the wanted length, the length drawn (zz/horse_ride_cap reads it)
var _prev_yaw := 0.0
var _lead_keep := 99.0
var _prev_piv := Vector3.ZERO
var _piv_v := Vector3.ZERO              ## the boom pivot's velocity, flat (m/s), smoothed
var _yaw_rate := 0.0                    ## the view's turn rate (rad/s), smoothed: the boom looks ahead by it
var _len_v := 0.0                       ## the boom length's speed while it eases in
var _shoulder_v := 0.0                  ## the boom's swing across the shoulder (per second): a spring, so it has no first-frame step
var _rise := 0.0                        ## metres the camera lifts over the hood while a wall presses the arm short
var _rise_ray: PhysicsRayQueryParameters3D
var _excl: Array[RID] = []              ## what the boom's casts pass through: the wanderer and the CAMERA_PASS bodies near him
var _pass_t := 0.0


func _init(p: Player) -> void:
	player = p


func set_view(yaw: float, pitch: float) -> void:
	player._yaw = yaw
	player._pitch = pitch


func cast_impulse() -> void:
	_shake_want = maxf(_shake_want, deg_to_rad(0.15) * Access.shake())


# --- Camera ------------------------------------------------------------------

## The spring arm used to sit perfectly still whatever the player did. Two cheap reactions:
## the view opens up at a sprint, and the camera dips on a hard landing. Base FOV stays
## Settings.fov, so the settings menu remains the one source of truth and the kick rides on top.

## Physics tick: only the TARGETS (speed kick, strafe roll) and the landing event are decided here;
## _cam_frame eases FOV, roll and the landing dip every rendered frame (r29: set on the tick, they
## stepped at 60 Hz on a 120-144 Hz screen -- a sprint's FOV kick visibly ratcheted).

func _update_camera(_delta: float, horiz: Vector3, _sprint: bool, vy_before: float) -> void:
	# FOV follows real speed (walk 0 -> sprint full kick -> slides and hops a bit beyond)
	var spd := horiz.length()
	_fov_want = clampf((spd - player.walk_speed) / maxf(player.sprint_speed - player.walk_speed, 0.1), 0.0, 1.6) * Player.SPRINT_FOV_KICK
	# a slight roll into strafes (max ~3.5 degrees at a full lateral sprint)
	var right := Basis(Vector3.UP, player._yaw) * Vector3.RIGHT
	var lateral := Vector3(player.velocity.x, 0.0, player.velocity.z).dot(right)
	_roll_want = clampf(-lateral / player.sprint_speed, -1.0, 1.0) * deg_to_rad(3.5)
	if player._grounded and not player._was_floor:
		var dip := clampf(-vy_before / 9.0, 0.0, 1.0)
		_land_dip_want = maxf(_land_dip_want, dip)
		if dip > 0.25:                           # a real drop: the staff's ferrule strikes the ground too
			StaffSfx.play("tap", player.global_position, lerpf(-12.0, -4.0, dip), 0.92)
	player._was_floor = player._grounded


## Rendered frame: FOV kick, strafe roll and the landing dip ease toward their targets here.

func _cam_frame(delta: float) -> void:
	# punches (kick, landing dip, the Rift Step's widening) arrive over ~3 frames instead of in one:
	# set on a physics tick, a one-frame snap of up to 7 degrees read as a hitch at 144 Hz
	var snap := 1.0 - exp(-38.0 * delta)
	_fov_kick = lerpf(_fov_kick, _fov_want, 1.0 - exp(-6.0 * delta))
	_fov_burst = lerpf(_fov_burst, player._fov_burst_want, snap)
	player._fov_burst_want *= exp(-4.0 * delta)
	player.fov_zoom = lerpf(player.fov_zoom, player.fov_zoom_want, 1.0 - exp(-(3.5 if player.fov_zoom_want < player.fov_zoom else 8.0) * delta))
	var fov := (Settings.fov + minf(_fov_kick + _fov_burst, 14.0)) * player.fov_zoom      # one motion: the burst rides on the speed kick
	if absf(player._cam.fov - fov) > 0.0001:
		player._cam.fov = fov
	_cam_roll = lerpf(_cam_roll, _roll_want, 1.0 - exp(-5.0 * delta))
	player._cam.rotation.z = _cam_roll
	player._land_dip = lerpf(player._land_dip, _land_dip_want, snap)
	_land_dip_want = move_toward(_land_dip_want, 0.0, delta * 3.0)
	player._shake = lerpf(player._shake, _shake_want, snap)
	_shake_want = move_toward(_shake_want, 0.0, delta * 0.12)   # ~0.15 s for a full kick


## Camera punch, 0..1. Rides the existing land-dip pitch channel.

func kick(amount: float) -> void:
	_shake_want = maxf(_shake_want, deg_to_rad(0.15 + 1.1 * clampf(amount, 0.0, 1.0)) * Access.shake())


# --- camera feel ---------------------------------------------------------------------------------------

## Physics tick: the jump hold (the view rises only part of a jump's height, then settles when you
## land, wherever that is) and the look-ahead (the view leads a run across the screen).

func _cam_feel_tick(delta: float) -> void:
	player._cam_air_prev = player._cam_air
	player._look_ahead_prev = player._look_ahead
	var want := 0.0
	if player._grounded or player._hang:
		player._air_base = player.global_position.y
	else:
		var up := player.global_position.y - player._air_base
		if up > 0.0:
			want = -minf(up * 0.45, 1.1)
		else:
			player._air_base = player.global_position.y           # below the take-off: follow the fall at once
	player._cam_air = lerpf(player._cam_air, want, 1.0 - exp(-(14.0 if want < player._cam_air else 9.0) * delta))
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var right := Basis(Vector3.UP, player._yaw) * Vector3.RIGHT
	var lead := right * flat.dot(right) * 0.065 * (0.4 + 0.6 * player._run_blend)
	if is_instance_valid(player._lock):
		lead = Vector3.ZERO
	player._look_ahead = player._look_ahead.lerp(lead.limit_length(0.45), 1.0 - exp(-6.0 * delta))


## A thin thing between the camera and the wanderer (a post, a lantern pole, a sapling) is ignored
## instead of yanking the camera in: the camera's own spot must be clear and it must cover less than
## half of the wanderer's width (THIN_RAYS parallel rays across +-THIN_HALF_W, fewer than half
## blocked). r35: it used to be "one of two edge rays gets through", so a stele or a raid standing
## stone off to one side passed as a pole: the camera stayed behind it and the stone hid the wanderer
## (shots/critB_first_review_seg_strafe.png) or filled half the screen in the henge raid.

func _thin_occluder(from: Vector3, dir: Vector3, want: float) -> bool:
	var space := player.get_world_3d().direct_space_state
	var cam_at := from + dir * want
	if _thin_q == null:
		var sph := SphereShape3D.new()
		sph.radius = Player.ARM_PROBE
		_thin_q = PhysicsShapeQueryParameters3D.new()
		_thin_q.shape = sph
		_thin_q.collision_mask = Layers.WORLD
		_thin_q.exclude = _excl
	var q := _thin_q
	q.transform = Transform3D(Basis.IDENTITY, cam_at)
	if not space.intersect_shape(q, 1).is_empty():
		return false
	if _thin_ray == null:
		_thin_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Layers.WORLD, _excl)
	var side := player._arm.global_basis.x.normalized()
	var blocked := 0
	for i in Player.THIN_RAYS:
		var a := from + side * lerpf(-Player.THIN_HALF_W, Player.THIN_HALF_W, float(i) / float(Player.THIN_RAYS - 1))
		_thin_ray.from = a
		_thin_ray.to = a + dir * want
		if not space.intersect_ray(_thin_ray).is_empty():
			blocked += 1
			if blocked * 2 >= Player.THIN_RAYS:
				return false
	return true


## Critically damped spring toward 0 (exact, any frame rate) for the camera or the visual offset.

func _spring3(cam: bool, w: float, dt: float) -> void:
	var x := player._cam_off if cam else player._vis_off
	var v := player._cam_off_v if cam else player._vis_off_v
	if x.length_squared() < 0.0000003 and v.length_squared() < 0.00003:
		x = Vector3.ZERO
		v = Vector3.ZERO
	else:
		var e := exp(-w * dt)
		var j := v + w * x
		x = (x + j * dt) * e
		v = (v - w * j * dt) * e
	if cam:
		player._cam_off = x.limit_length(0.8)
		player._cam_off_v = v
	else:
		player._vis_off = x.limit_length(0.6)
		player._vis_off_v = v


## Camera boom: our own sphere probe (the SpringArm's collision is off). Pulls in fast when
## something comes between, eases back out slowly, shortens when looking up (no ground clipping),
## and lengthens a little at a sprint.

func _update_arm(delta: float) -> void:
	# close fight (locked on, or a foe within ~4.5 m ahead): the view rises and pulls back a little so
	# what is in front of the wanderer reads over the shoulder instead of behind the robe (r29)
	var close := is_instance_valid(player._lock) or (is_instance_valid(player._look_foe) and player._look_foe.is_alive() and player._look_foe.global_position.distance_squared_to(player.global_position) < 20.0)
	_fight_k = move_toward(_fight_k, 1.0 if close else 0.0, delta * (1.6 if close else 0.8))
	var fk := smoothstep(0.0, 1.0, _fight_k)
	player._rig.global_position += Vector3.UP * 0.32 * fk
	var want := Player.ARM_LEN * lerpf(1.0, 0.62, clampf(player._pitch / player.pitch_max, 0.0, 1.0))
	want *= lerpf(1.0, 0.62, clampf((-player._pitch - 0.18) / maxf(-player.pitch_min - 0.18, 0.1), 0.0, 1.0))   # looking down shortens it too: no ground clip
	want += 0.35 * player._run_blend - 0.25 * player._slide_blend + 0.45 * fk
	var space := player.get_world_3d().direct_space_state if player.is_inside_tree() else null
	var reach := want
	var hard_reach := want                      # what is in the way of the boom NOW: the only reach the length is clamped to
	if space:
		_pass_tick(delta)
		_shoulder_tick(space, want, delta)
		if _arm_q == null:                       # one query object, not two allocations per rendered frame
			var sph := SphereShape3D.new()
			sph.radius = Player.ARM_PROBE
			_arm_q = PhysicsShapeQueryParameters3D.new()
			_arm_q.shape = sph
			_arm_q.collision_mask = Layers.WORLD
			_arm_q.exclude = _excl
		var q := _arm_q
		q.transform = Transform3D(Basis.IDENTITY, player._arm.global_position)
		q.motion = player._arm.global_basis.z.normalized() * want
		var frac: PackedFloat32Array = space.cast_motion(q)
		if frac.size() > 0:
			reach = want * frac[0]
		# on foot a post or pole is let pass for a beat (the hold); on horseback a thin trunk never counts at all (no hold to
		# end and cut the length), and what does count is eased in by the look-ahead
		var riding := player.riding != null
		var pass_thin := not riding
		if riding and reach < want - 0.05 and _thin_trunk(player._arm.global_position, player._arm.global_basis.z.normalized(), want):
			reach = want                         # a thin trunk never shortens the boom on horseback: the bark dithers out near the lens
		elif pass_thin and reach < want - 0.05 and _thin_occluder(player._arm.global_position, player._arm.global_basis.z.normalized(), want):
			_thin_hold = 0.15                    # a post or a pole: let it pass, don't yank the view in
		# a swinging view meets a trunk before the boom touches it: look where the boom will be a moment from now (by the
		# turn's own rate) and start easing in for what is coming, so the length is never cut at the wall in one frame
		hard_reach = reach
		var lead := _lead_reach(space, q, want, delta, pass_thin) if riding else want       # on foot the boom is as it was
		_lead_keep = minf(move_toward(_lead_keep, want, delta * 3.0), lead)         # held, and let go of slowly: a look that finds the trunk and loses it again does not let the length out and cut it back
		lead = _lead_keep
		dbg.x = reach
		dbg.y = lead
		if lead < reach and _thin_hold <= 0.0:
			reach = lead
		_thin_hold = maxf(0.0, _thin_hold - delta)
		if _thin_hold > 0.0:
			_thin_q.transform = Transform3D(Basis.IDENTITY, player._arm.global_position + player._arm.global_basis.z.normalized() * want)
			if not space.intersect_shape(_thin_q, 1).is_empty():
				_thin_hold = 0.0                 # strafed from the pole onto a wall: the camera spot is no longer clear
			else:
				reach = want
	reach = maxf(reach, 0.5)
	hard_reach = maxf(want if _thin_hold > 0.0 else hard_reach, 0.5)
	if not (player.riding != null):
		# on foot: as it always was (a quick first-order pull in clamped to the wall, a slow ease out)
		if reach < _cam_len:
			_cam_len = minf(lerpf(_cam_len, reach, 1.0 - exp(-28.0 * delta)), reach + 0.25)
		else:
			_cam_len = lerpf(_cam_len, reach, 1.0 - exp(-8.0 * delta))
		_len_v = 0.0
	elif reach < _cam_len:
		# riding, in: a critically damped spring (no first-frame step); the hard clamp is the wall that is right there
		var w := 12.0
		var x := _cam_len - reach
		var j := _len_v + w * x
		_len_v = (_len_v - w * j * delta) * exp(-w * delta)
		_cam_len = minf(reach + (x + j * delta) * exp(-w * delta), hard_reach + Player.ARM_PROBE)
	else:
		_len_v = 0.0
		_cam_len = lerpf(_cam_len, reach, 1.0 - exp(-4.0 * delta))
	player._arm.spring_length = _cam_len
	dbg.z = want
	dbg.w = _cam_len
	# pressed against a wall (the pit hall's, a standing stone), the camera rose no higher and the hood filled a third of
	# the view: it lifts over the shoulder as the arm shortens, as far as the space above it allows
	var squeeze := clampf((want - _cam_len) / maxf(want * 0.6, 0.1), 0.0, 1.0)
	var lift := 0.85 * squeeze
	if lift > 0.02 and space:
		if _rise_ray == null:
			_rise_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Layers.WORLD, _excl)
		var from := player._arm.global_position + player._arm.global_basis.z.normalized() * _cam_len
		_rise_ray.from = from
		_rise_ray.to = from + Vector3.UP * (lift + 0.35)
		var up_hit := space.intersect_ray(_rise_ray)
		if not up_hit.is_empty():
			lift = maxf(0.0, from.distance_to(up_hit.position) - 0.35)
	_rise = lerpf(_rise, lift, 1.0 - exp(-6.0 * delta))
	player._cam.position = Vector3(0.0, _rise, _cam_len)


## Seven rays across +-0.5 m of the boom: what they meet is thin trunks only (a cylinder collider under 1.2 m radius: the
## flora's trunks) and nothing else. A wall, a building, the ground or a great trunk anywhere in the fan makes it false. The
## camera may then sit in a thin trunk for a moment: its bark fades out within ~2 m of the lens
## (art/materials/realm_foliage_bark_*), so nothing fills the view and the boom is not cut to it.
func _thin_trunk(from: Vector3, dir: Vector3, want: float) -> bool:
	if _thin_ray == null:
		_thin_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Layers.WORLD, _excl)
	var space := player.get_world_3d().direct_space_state
	var side := player._arm.global_basis.x.normalized()
	for i in 7:
		var a := from + side * lerpf(-0.5, 0.5, float(i) / 6.0)
		_thin_ray.from = a
		_thin_ray.to = a + dir * want
		var hit := space.intersect_ray(_thin_ray)
		if hit.is_empty():
			continue
		var srid := PhysicsServer3D.body_get_shape(hit.rid as RID, int(hit.shape))
		if PhysicsServer3D.shape_get_type(srid) != PhysicsServer3D.SHAPE_CYLINDER:
			return false
		var d: Variant = PhysicsServer3D.shape_get_data(srid)
		var r := float((d as Dictionary).get("radius", 9.0)) if d is Dictionary else (float((d as Vector2).x) if d is Vector2 else 9.0)
		if r >= THIN_TRUNK_R:
			return false
	return true


## The shortest reach of the boom swung on by the view's own turn rate (five looks out to 0.45 s: a trunk is thinner than the gap between two). The sphere cast `q` is reused.
func _lead_reach(space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, want: float, delta: float, pass_thin: bool) -> float:
	var rate := angle_difference(_prev_yaw, player._yaw) / maxf(delta, 0.0001)
	_prev_yaw = player._yaw
	_yaw_rate = lerpf(_yaw_rate, rate, 1.0 - exp(-30.0 * delta))
	var piv := player._arm.global_position
	var step := piv - _prev_piv
	_prev_piv = piv
	if step.length_squared() > 4.0:             # the first frame, a teleport, a mount: not a speed
		step = Vector3.ZERO
		_lead_keep = 99.0
	var v := step / maxf(delta, 0.0001)
	v.y = 0.0
	_piv_v = _piv_v.lerp(v.limit_length(25.0), 1.0 - exp(-20.0 * delta))
	var best := want
	var dir := player._arm.global_basis.z.normalized()
	var looks: Array[Array] = []                          # [origin offset, direction, seconds ahead]
	if absf(_yaw_rate) >= 0.4:
		for t: float in [0.05, 0.1, 0.2, 0.3, 0.45]:
			looks.append([Vector3.ZERO, dir.rotated(Vector3.UP, _yaw_rate * t), t])
	if _piv_v.length_squared() > 9.0:                      # the pivot itself is carried toward a trunk at a ride's pace
		for t: float in [0.1, 0.2, 0.3, 0.45]:
			looks.append([_piv_v * t, dir, t])
	for lk: Array in looks:
		var d: Vector3 = lk[1]
		var at := piv + (lk[0] as Vector3)
		q.transform = Transform3D(Basis.IDENTITY, at)
		q.motion = d * want
		var f: PackedFloat32Array = space.cast_motion(q)
		if f.size() > 0 and f[0] < 1.0:
			# what is found t ahead counts for less the farther off it is: the target length slides in as the trunk comes
			# on (a step the spring could only chase), the full amount when it is here
			var r := want - (want - want * f[0]) * (1.0 - smoothstep(0.0, LEAD_T, float(lk[2])))
			if r < best and not ((pass_thin and _thin_occluder(at, d, want)) or (not pass_thin and _thin_trunk(at, d, want))):
				best = r
	q.transform = Transform3D(Basis.IDENTITY, piv)
	return best


## The boom's casts pass through the wanderer and through the great stones near him (Groups.CAMERA_PASS: they dissolve
## near the lens instead); the list is looked up twice a second and shared by every query of the boom.
func _pass_tick(delta: float) -> void:
	_pass_t -= delta
	if _pass_t > 0.0 and not _excl.is_empty():
		return
	_pass_t = 0.5
	var ex: Array[RID] = [player.get_rid()]
	for b in player.get_tree().get_nodes_in_group(Groups.CAMERA_PASS):
		var co := b as CollisionObject3D
		if co != null and co.global_position.distance_squared_to(player.global_position) < 1600.0:
			ex.append(co.get_rid())
	if ex != _excl:
		_excl = ex
		for q: Variant in [_arm_q, _thin_q, _thin_ray, _sight_ray, _rise_ray]:
			if q is PhysicsShapeQueryParameters3D:
				(q as PhysicsShapeQueryParameters3D).exclude = _excl
			elif q is PhysicsRayQueryParameters3D:
				(q as PhysicsRayQueryParameters3D).exclude = _excl


## r35: the boom sits SHOULDER m over the right shoulder, and the spring cast only watches the boom,
## so a stele or a raid stone to its left could stand between the camera and the wanderer without
## touching it: the view stayed behind the stone (shots/critB_first_review_seg_strafe.png). Each
## rendered frame this looks at the wanderer from where the full-shoulder camera would stand. When
## most of the body is hidden (SIGHT_HIDDEN of the six rays), or that camera would have to come in
## closer than SHOULDER_NEAR (the offset then pushes the wanderer out of frame), the boom swings in
## behind the wanderer, where the spring cast below handles whatever is still in the way; it swings
## back out once the shoulder view is clear again. Judged from the full-shoulder spot, which does not
## move with the swing, so the swing cannot feed back on itself.

func _shoulder_tick(space: PhysicsDirectSpaceState3D, want: float, delta: float) -> void:
	var dir := player._arm.global_basis.z.normalized()
	var piv := player._pitch_node.global_transform * Vector3(Player.SHOULDER, player._arm.position.y, player._arm.position.z)
	if _sight_ray == null:
		_sight_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Layers.WORLD, _excl)
	var r := _sight_ray
	# the shoulder itself must stand in open air. With the wanderer pressed to a rock on the boom's side (the Crown's
	# earthwork after a Rift Step: map audit MA2) the full-shoulder pivot stood inside the rock, the arm's cast started
	# there and found nothing from inside, and the view sat in the stone. A pivot the head cannot see swings the boom
	# in behind the wanderer, where the spring cast below handles the rest.
	r.from = player._pitch_node.global_transform * Vector3(0.0, player._arm.position.y, player._arm.position.z)
	r.to = piv + (piv - r.from).normalized() * Player.ARM_PROBE
	if not space.intersect_ray(r).is_empty():
		_sight_hold = 0.5
	elif _piv_v.length_squared() > 4.0:
		# carried along at a ride's pace the shoulder will stand in a trunk the horse brushes past: swing in behind the
		# wanderer before it does, not once the boom's start is inside it (a cut of the whole length)
		var shoulder_dir := (piv - r.from).normalized()
		var centre := r.from
		for t: float in [0.12, 0.25, 0.4]:
			var off := _piv_v * t
			r.from = centre + off
			r.to = piv + off + shoulder_dir * Player.ARM_PROBE
			if not space.intersect_ray(r).is_empty():
				_sight_hold = maxf(_sight_hold, 0.4)
				break
	r.from = piv
	r.to = piv + dir * want
	var hit := space.intersect_ray(r)
	var reach := want if hit.is_empty() else maxf(0.0, piv.distance_to(hit.position) - Player.ARM_PROBE)
	var cam_at := piv + dir * reach
	var body := player.global_position
	var across := (body - cam_at).cross(Vector3.UP)
	across = across.normalized() if across.length_squared() > 0.0001 else player._arm.global_basis.x
	# only whether SIGHT_HIDDEN of the six are blocked matters, so the casts stop the moment that is settled
	# (a clear view is settled by the third clear ray, a hidden one by the fourth blocked): the same answer for half the rays
	var hidden := 0
	var clear := 0
	for y: float in [1.1, 1.6]:
		for s: float in [-0.3, 0.0, 0.3]:
			if hidden >= Player.SIGHT_HIDDEN or clear > 6 - Player.SIGHT_HIDDEN:
				break
			r.from = cam_at
			r.to = body + Vector3.UP * y + across * s
			if space.intersect_ray(r).is_empty():
				clear += 1
			else:
				hidden += 1
	if hidden >= Player.SIGHT_HIDDEN:
		_sight_hold = 0.5                        # stays in a beat, so the edge of a stone does not flicker it
	_sight_hold = maxf(0.0, _sight_hold - delta)
	var k_want := 0.0 if _sight_hold > 0.0 else smoothstep(Player.SHOULDER_NEAR * 0.5, Player.SHOULDER_NEAR, reach)
	if player.riding == null:
		player._shoulder_k = lerpf(player._shoulder_k, k_want, 1.0 - exp(-(9.0 if k_want < player._shoulder_k else 2.5) * delta))      # on foot: as it was
		_shoulder_v = 0.0
	else:
		# riding: a critically damped spring, not a first-order lag (the lag begins at its full speed in one frame: the boom's
		# first step was 13 cm), and a slower swing in behind the wanderer: a gallop through trees flicked the boom across the horse
		var w := 6.0 if k_want < player._shoulder_k else 3.5
		var e := exp(-w * delta)
		var x := player._shoulder_k - k_want
		var j := _shoulder_v + w * x
		_shoulder_v = (_shoulder_v - w * j * delta) * e
		player._shoulder_k = clampf(k_want + (x + j * delta) * e, 0.0, 1.0)
	player._arm.position.x = Player.SHOULDER * player._shoulder_k
	player._cam.h_offset = 0.12 * player._shoulder_k           # the crosshair side follows the boom
