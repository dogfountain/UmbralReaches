extends Interactable
## r36 a horse (core/world/mount): a skinned glTF (art/models/horse_*.glb, built by
## tools/blender/horse_build.py) posed by horse_rig.gd from the gait phase, a state, and the ride. Stands at its
## hitching post (or where it was left) grazing; [E] buys it there, rides it once owned; [E] while
## riding gets down; the jump key makes the HORSE leap (try_jump). Player.riding hands the drive to
## `drive()` every physics frame.
##   walk / trot / gallop by the move stick and sprint; turns toward the move direction at the
##   breed's rate; follows the ground with a ray (refuses a step taller than `climb`); stops at a
##   wall; slows to a walk in water unless it wades; a draught throws the hollowed aside (trample).
##   Leap: a gather (haunches drop), a push-off with vertical speed under gravity (a standstill hop ~0.6 m,
##   a gallop leap ~1.2 m, times the breed's `jump`), steering eased and speed kept in the air, then the
##   ground ray catches it: landing is soft (the rig squats, dust, a thud) and a short cooldown follows.

const Foley := preload("res://core/vfx/foley.gd")
const HorseRig := preload("res://core/world/mount/horse_rig.gd")
const DB := preload("res://core/world/mount/horse_db.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const Kit := preload("res://core/life/secrets/kit.gd")
const Move := preload("res://core/world/mount/horse_move.gd")
const HorseBond := preload("res://core/world/mount/horse_bond.gd")
const Paddock := preload("res://core/world/mount/horse_paddock.gd")   ## a horse at its post strolls the paddock
var _wd := {}

const GRAVITY := 24.0                ## m/s^2 on the leap (a horse's jump is snappy, not floaty)
const HOP_H := 0.6                   ## apex of a standing hop (m)
const LEAP_H := 1.2                  ## apex of a gallop leap (m)
const GATHER_T := 0.11               ## the crouch before the push-off
const JUMP_CD := 0.35                ## after a landing
const SINK := 0.075                  ## the pelvis sits this far into the saddle (the barrel and stirrups rise by as much in the rider's frame)
const JUMP_BUFFER := 0.2             ## a press just before landing still leaps
const AIR_MAX := 2.5                 ## s: a leap that never finds ground is set down where it began

var breed := "palfrey"
var at_post := true              ## standing at its hitching post (for sale until owned)
var rider: Node3D = null
var rival := false               ## a race rival (horse_race_field.gd): driven by the race, not a horse to buy or ride
var speed := 0.0
var _rig: Node3D
var _speed_prev := 0.0
var _accel := Vector2.ZERO            ## fore-aft and sideways acceleration, for the lantern
var _d: Dictionary
var _yaw := 0.0
var _phase := 0.0
var _phase_prev := 0.0                ## r36 smooth: the phase a tick ago (drawn blended to the frame)
var _head := 0.0                 ## head pitch (grazing lowers it)
var _graze_t := 0.0
var _snort_t := 8.0                 ## seconds to the next idle breath or snort
var _surf_age := 0.0                ## seconds the cached hoof surface is trusted
var _surf: StringName = &"grass"
var _prev_fast := false             ## was at the trot or faster: a snort when it comes back to the walk
var _stride_n := 0
var _turn_v := 0.0
var _mount_t := 9.0
var _mount_from := Vector3.ZERO
const LEAVE_T := 1.0
const MOUNT_T := 1.15                ## r36: step up, foot in the stirrup, swing over, settle
## the saddle's seat top, the stirrup tread and the barrel under the rider are the breed's own metres
## (horse_db.gd: seat, stirrup_y, stirrup_x, bw / bc / bl), measured off the built model
var _space: PhysicsDirectSpaceState3D
var _leave_t := 0.0                  ## walking out of a boss ring before getting down
var _leave_dir := Vector3.ZERO
var _gather := 0.0                   ## seconds left in the crouch (> 0: about to push off)
var _air := false
var _vy := 0.0
var _air_t := 0.0
var _air_y0 := 0.0
var _land := 0.0                     ## 1 at touchdown, easing to 0: the squat
var _jump_cd := 0.0
var _jump_buf := 0.0
var _lean := 0.0                     ## the rider's lean into the leap (rad, + forward)
var _rs := Vector3.ZERO              ## the rider's damped follow of the horse: height (m), pitch (rad, + forward), roll (rad)
var _rv := Vector3.ZERO
var _vis: Node3D                     ## the rider's Visual while the horse draws it (placed each rendered frame)
var _vis_yaw := 0.0
var _vis_local := Transform3D.IDENTITY   ## the rider Visual's own place under the Player, given back on dismount
var _back := INF                     ## the back's drop, smoothed (the seat's floor)
var _mv := Move.new()                ## the way round things: probe, slide, shoulder, unwedge (horse_move.gd)
var _trampled := {}                ## enemy instance id -> msec of the last trample on it


func _ready() -> void:
	_d = DB.BREEDS.get(breed, DB.BREEDS["palfrey"])
	add_to_group(Groups.INTERACTABLE)
	add_to_group(&"horse")
	_rig = HorseRig.new()
	_rig.setup(breed, _d)
	_rig.top_level = true            # placed every rendered frame from the interpolated transform (_process)
	# and so off the physics interpolation: left on, Godot interpolated those per-frame placements again
	# between ticks, and the horse stepped at the tick rate under a rider drawn every frame
	_rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_rig)
	_yaw = global_basis.get_euler().y
	_write(NAN, 0.0)
	set_physics_process(false)                  # only while it runs to a whistle


func can_interact() -> bool:
	return true


func interact_text() -> String:
	var k := Interactable.prompt_key()
	if rider != null:
		return "[%s]  Get down" % k
	if not owned():
		return "[%s]  Buy the %s  (%d grave ash: trots %d, gallops %d m/s; you sprint 7)" % [k, String(_d.name), int(_d.cost), roundi(float(_d.trot)), roundi(float(_d.gallop))]
	return "[%s]  Ride %s  (%s, %s)" % [k, HorseBond.name_of(breed), String(_d.name), HorseBond.title(breed)]


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
		Events.toast.emit("%s the %s is yours. Ride, or call with [%s] wherever you are. The more you ride, the better it knows you." % [HorseBond.name_of(breed), String(_d.name), InputSetup.live_label("mount", Settings.using_pad, "H")])
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
	_call_who = null
	set_physics_process(false)
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
	_gather = 0.0
	_lean = 0.0
	var rig := p.get_node_or_null("Visual") if p != null and is_instance_valid(p) else null
	_release_visual()
	_rs = Vector3.ZERO
	_rv = Vector3.ZERO
	_back = INF
	if rig != null and "ride_lean" in rig:
		rig.set("ride_lean", 0.0)
	if rig != null and "ride_roll" in rig:
		rig.set("ride_roll", 0.0)
	if p != null and is_instance_valid(p):
		p.riding = null
		var side := global_basis.x.normalized()
		var to := global_position + side * 1.1
		p.teleport(_ground(to) + Vector3.UP * 0.1)
		var left: Dictionary = state().get("left", {}) if state().get("left") is Dictionary else {}
		left[breed] = [roundi(global_position.x), roundi(global_position.z), snappedf(rotation.y, 0.01)]     # it waits where it was left
		state()["left"] = left


## The jump key on horseback (PlayerMount): a gather, then the push-off. Only from the ground, once the
## rider is seated, and not in the cooldown; a press a moment early is remembered.
func try_jump() -> void:
	if rider == null or _air or _gather > 0.0 or _mount_t < MOUNT_T or _leave_t > 0.0:
		return
	if _jump_cd > 0.0:
		_jump_buf = JUMP_BUFFER
		return
	_gather = GATHER_T * (1.0 - 0.5 * clampf(speed / float(_d.gallop), 0.0, 1.0))


## The push-off: vertical speed for an apex of HOP_H..LEAP_H by speed, times the breed's `jump`.
func _launch() -> void:
	var k := clampf(speed / float(_d.gallop), 0.0, 1.0)
	var h := lerpf(HOP_H, LEAP_H, k) * float(_d.get("jump", 1.0))
	_vy = sqrt(2.0 * GRAVITY * h)
	_air = true
	_air_t = 0.0
	_air_y0 = global_position.y
	_gather = 0.0
	if speed > float(_d.trot):
		speed = minf(speed + 0.8, float(_d.gallop) * 1.05)       # the leap carries forward
	_takeoff_sfx(k)


## Hold the vertical state through the tick: the crouch, the climb and fall under gravity, the landing.
func _vertical(dt: float, ground_y: float) -> void:
	_jump_cd = maxf(0.0, _jump_cd - dt)
	_jump_buf = maxf(0.0, _jump_buf - dt)
	_land = move_toward(_land, 0.0, dt * 4.0)
	if _gather > 0.0:
		_gather -= dt
		if _gather <= 0.0:
			_launch()
	elif not _air and _jump_buf > 0.0 and _jump_cd <= 0.0 and _land < 0.6:
		_jump_buf = 0.0
		try_jump()
	if not _air:
		return
	_air_t += dt
	_vy -= GRAVITY * dt
	var ny := global_position.y + _vy * dt
	if (_vy <= 0.0 and ny <= ground_y) or _air_t > AIR_MAX:
		var impact := clampf(-_vy / 7.0, 0.0, 1.0)
		global_position.y = ground_y if _air_t <= AIR_MAX else _air_y0
		_air = false
		_vy = 0.0
		_jump_cd = JUMP_CD
		_land = 0.35 + 0.65 * impact
		_landing_sfx(impact)
		Kit.fx_dust(global_position + Vector3.UP * 0.1, Color(0.5, 0.46, 0.4, 0.55), 8 + int(10.0 * impact))
	else:
		global_position.y = ny


## While airborne the body is not lerped to the ground; on it, it follows (14/s) as before.
func _follow_y(ground_y: float, dt: float) -> float:
	return global_position.y if _air else lerpf(global_position.y, ground_y, 1.0 - exp(-14.0 * dt))


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
	var driven := w.length() > 0.3 and _mv.free_t <= 0.0
	if _mv.free_t > 0.0:
		# freeing itself: turn toward the way out (to the side, when it is backing out)
		var rt := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		w = _mv.free_dir if _mv.free_dir.dot(Vector3(-sin(_yaw), 0.0, -cos(_yaw))) > -0.2 else rt * (signf(_mv.free_dir.dot(rt)) if _mv.free_dir.dot(rt) != 0.0 else 1.0)
	if w.length() > 0.1:
		want = float(_d.gallop) if sprint else (float(_d.trot) if w.length() > 0.7 else float(_d.walk))
		var target_yaw := atan2(-w.x, -w.z)
		var want_turn := clampf(angle_difference(_yaw, target_yaw) * 4.0, -1.0, 1.0) * float(_d.turn) * (0.6 if speed > 8.0 else 1.0)
		_turn_v = lerpf(_turn_v, want_turn, 1.0 - exp(-8.0 * dt))       # eases into and out of a turn
	else:
		_turn_v = lerpf(_turn_v, 0.0, 1.0 - exp(-8.0 * dt))
	_yaw += _turn_v * dt * (0.35 if _air else 1.0)
	want *= HorseBond.mult(breed)
	if rider != null and speed > 1.0:
		var up := HorseBond.add(breed, speed * dt)
		if up > 0:
			Events.toast.emit(HorseBond.saying(breed))
	var wading := RealmLand.in_water(global_position.x, global_position.z)
	if wading and not bool(_d.get("wade", false)):
		want = minf(want, float(_d.walk))
	if _air or _gather > 0.0:
		want = maxf(want, speed)                 # nothing to push against: the stride is carried through the leap
	speed = move_toward(speed, want, (6.0 if want > speed else 9.0) * dt * lerpf(0.5, 1.0, smoothstep(0.0, 1.5, speed)) * (1.0 / float(_d.get("heft", 1.0))))
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	_advance(p, fwd, w, want, driven, dt)
	# the vertical: the crouch, the climb and fall, the landing on the ground under the hooves
	_vertical(dt, _ground(global_position).y)
	var s_air := clampf(_vy / 7.0, -1.0, 1.0)
	var lean_want := 0.0
	if _air:
		lean_want = 0.55 * maxf(s_air, 0.0) + 0.35 * (1.0 - absf(s_air)) - 0.05 * maxf(-s_air, 0.0)
	elif _gather > 0.0:
		lean_want = 0.12
	elif _land > 0.0:
		lean_want = -0.12 * _land
	_lean = lerpf(_lean, lean_want, 1.0 - exp(-14.0 * dt))
	if bool(_d.get("trample", false)) and speed > 6.0:
		_trample(fwd)
	global_basis = Basis(Vector3.UP, _yaw)
	_head = lerpf(_head, 0.0, 1.0 - exp(-4.0 * dt))
	_accel = Vector2((speed - _speed_prev) / maxf(dt, 0.001), speed * _turn_v)
	_speed_prev = speed
	_hooves(dt)
	# the rider sits the saddle, facing where the horse faces
	# the pelvis on the saddle's seat (the seat's top is `seat` above the horse's origin; the rig's
	# pelvis stands 0.955 above its feet), a hand's width behind the pommel
	var seat := global_position + Vector3.UP * _seat_lift() + fwd * (0.04 * _scale())
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
		var stand := global_position + left * float(_d.stirrup_x) + fwd * 0.03 * sc + Vector3.UP * float(_d.stirrup_y)
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
	if _mount_t >= MOUNT_T and vis != null and _vis == null:
		_claim_visual(vis)
	p.global_position = seat
	if vis and "saddle" in vis:
		# the barrel under the rider, in the coat's space (origin at the pelvis): its half width, its
		# centre below the seat, its half length
		vis.set("saddle", Vector3(float(_d.bw) * 1.05, float(_d.bc) - float(_d.seat) - 0.02 + SINK, float(_d.bl) * 1.05))
	if vis and "ride_lean" in vis:
		vis.set("ride_lean", _rs.y)
	if vis and "ride_roll" in vis:
		vis.set("ride_roll", _rs.z)
		vis.set("ride_bob", _rv.x)
	if vis and _vis == null:
		# facing where the horse faces, in WORLD space: the player node itself turns with the camera,
		# so a local yaw sat the rider sideways
		var cur := vis.global_rotation.y
		vis.global_rotation.y = lerp_angle(cur, _yaw, 1.0 - exp(-12.0 * dt))
		_vis_yaw = vis.global_rotation.y
	p.velocity = fwd * speed


## One tick of travel (docs: horse_move.gd). Low things (below `climb`) are stepped onto by the ground ray, or
## hopped when the rise is a knee's; taller things are slid along (the heading eases along the face, most of
## the speed kept unless head-on); grunts are shouldered aside; bosses and real walls still stop it; driven
## and getting nowhere for ~0.6 s, it backs and turns out of it.
func _advance(p: Player, fwd: Vector3, w: Vector3, want: float, driven: bool, dt: float) -> void:
	var sc := _scale()
	var skip: Array[RID] = [p.get_rid()]
	var foes := _mv.gather(get_tree(), global_position, 2.6 * sc + speed * 0.15)
	_mv.shoulder(foes, global_position, fwd, speed, sc)
	if _mv.free_t > 0.0:
		_free_step(skip, sc, dt)
	elif speed > 0.05:
		_go(skip, fwd, w, want, sc, dt)
	if _mv.wedged(driven, global_position, dt, _air):
		_mv.way_out(_space, skip, global_position, fwd, w, sc)


func _go(skip: Array[RID], fwd: Vector3, w: Vector3, want: float, sc: float, dt: float) -> void:
	var climb := float(_d.climb)
	var reach := 1.25 * sc + speed * dt
	var hit: Dictionary = _mv.probe(_space, skip, global_position, fwd, fwd.cross(Vector3.UP), reach, climb * 0.85, 1.2 * sc, sc)
	var dir := fwd
	if not hit.is_empty():
		var sl: Dictionary = _mv.slide(hit, fwd, w, dt)
		var e := clampf((reach - float(hit.dist)) / (reach - 0.9 * sc), 0.0, 1.0)      # 0 at the edge of reach, 1 with the nose to it
		var sdir: Vector3 = sl.dir
		dir = fwd.lerp(sdir, e).normalized()
		var close := float(hit.dist)
		if close < 0.85 * sc:
			dir = (dir + (hit.n as Vector3) * clampf((0.85 * sc - close) * 3.0, 0.0, 1.0)).normalized()     # eased back out of it
		var cap := maxf(want * lerpf(1.0, float(sl.keep), e), 1.2 if float(sl.keep) > 0.0 else 0.0)
		if speed > cap:
			speed = move_toward(speed, cap, 30.0 * dt)
		if float(sl.keep) > 0.0:
			_yaw = lerp_angle(_yaw, atan2(-sdir.x, -sdir.z), (1.0 - exp(-6.0 * dt)) * e)
	if not _air and _gather <= 0.0 and speed > 3.5 and _mv.hop_cd <= 0.0 and _land < 0.3:
		# a knee-high rise right ahead (a stone, a kerb, a log): a hop over it, not a stumble
		var da := 0.55 * sc + 0.05 * speed
		var ga := _ground(global_position + dir * da).y
		var gb := _ground(global_position + dir * (da + 0.5)).y
		var rise := gb - global_position.y
		if gb - ga >= 0.18 and rise >= 0.18 and rise <= float(_d.climb) + 0.1:
			_vy = sqrt(2.0 * GRAVITY * (rise * 1.3 + 0.22))          # the arc grows with the obstacle: the hooves clear its top by 0.3 m or more
			_air = true
			_air_t = 0.0
			_air_y0 = global_position.y
			_mv.hop_cd = 0.3
	var next := global_position + dir * speed * dt
	var g := _ground(next)
	if g.y - global_position.y > climb:
		speed = move_toward(speed, 0.0, maxf(speed, 3.0) / 0.2 * dt)       # eased to a stop in ~0.2 s
		return
	global_position = Vector3(next.x, _follow_y(g.y, dt), next.z)
	_phase += TAU * _rig.freq(speed) * dt            # unwrapped: a wrap would swing the legs back a frame


## The way out of a wedge: a slow step to the side or back along `_mv.free_dir`, the way checked first.
func _free_step(skip: Array[RID], sc: float, dt: float) -> void:
	var dir: Vector3 = _mv.free_dir
	speed = move_toward(speed, 1.6, 20.0 * dt)
	var hit: Dictionary = _mv.probe(_space, skip, global_position, dir, dir.cross(Vector3.UP), 1.0 * sc, float(_d.climb) * 0.85, 1.2 * sc, sc)
	if not hit.is_empty():
		return
	var next := global_position + dir * 1.8 * dt
	var g := _ground(next)
	if g.y - global_position.y <= float(_d.climb):
		global_position = Vector3(next.x, _follow_y(g.y, dt), next.z)
		_phase += TAU * _rig.freq(speed) * dt


## The seated rider is drawn by the horse, once per rendered frame, at the same interpolated moment as the
## horse itself: the Visual is taken off the physics interpolation (the tick-placed body would step) and
## the rig blends its bones with the tick fraction anyway (CharacterRig.render_placed).
func _claim_visual(vis: Node3D) -> void:
	_vis = vis
	_vis_local = vis.transform
	_vis.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# off the Player's transform too: the body moves on ticks and is interpolated, and a child placed per
	# frame under it carried a fraction-of-a-tick wobble that changed with the frame's timing
	_vis.top_level = true
	if "render_placed" in _vis:
		_vis.set("render_placed", true)
	_vis_yaw = _vis.global_rotation.y


func _release_visual() -> void:
	if _vis != null and is_instance_valid(_vis):
		_vis.top_level = false
		_vis.transform = _vis_local
		_vis.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
		if "render_placed" in _vis:
			_vis.set("render_placed", false)
		_vis.reset_physics_interpolation()
	_vis = null


func _exit_tree() -> void:
	_release_visual()


## Where the rider's pelvis sits relative to the horse's origin at the rendered moment (m above it).
func _seat_lift() -> float:
	return float(_d.seat) - CharacterRig.H_PELVIS + 0.02 - SINK + _rs.x


## The rider is not bolted to the saddle: height, pitch and roll chase the horse's through damped springs
## (so they lag and settle), with a post at the trot, a crouch into the gallop and a lean into turns.
## Stepped every rendered frame (sub-stepped for a stable spring) from the pose drawn that frame.
func _ride_follow(dt: float, ph: float) -> void:
	if _rig == null or dt <= 0.0:
		return
	var trot_w := smoothstep(float(_d.walk), float(_d.trot), speed) * (1.0 - smoothstep(float(_d.trot), float(_d.gallop), speed))
	var k := clampf(speed / float(_d.gallop), 0.0, 1.0)
	var acc := clampf(_accel.x / 6.0, -1.0, 1.0)
	var t := Vector3.ZERO
	# the seat rides the back (most of it: the hips take the rest), rises out of the saddle once a trot
	# stride (a posting trot, ~9 cm) and rocks fore-and-aft with the gallop's bound
	var gal_w := smoothstep(float(_d.trot), float(_d.gallop), speed)
	t.x = _rig.last_dy * 0.85 + trot_w * 0.045 * (1.0 + sin(ph + 0.3)) \
			+ gal_w * 0.035 * (0.5 + 0.5 * sin(ph + 1.2)) + (0.12 if _air else 0.0)
	t.y = _lean + 0.1 * smoothstep(0.35, 0.65, k) + 0.28 * smoothstep(0.6, 1.0, k) + 0.1 * _rig.rock - _rig.body_pitch * (0.2 if _air else 0.7) - acc * 0.07
	t.z = -_rig.body_roll * 0.9
	var n := clampi(ceili(dt / (1.0 / 240.0)), 1, 12)
	var d := minf(dt, 0.1) / float(n)
	# the back as the seat feels it: its quick ripples (the legs' reach) are taken out
	var raw: float = _rig.last_dy
	var prev: float = _back if _back < INF else raw
	_back = lerpf(prev, raw, 1.0 - exp(-dt / (0.008 if raw > prev else 0.04))) if _back < INF else raw
	var back_v := clampf((_back - prev) / dt, -6.0, 6.0)
	# the seat rides the whole back (it took 92 % and the horse out-bounced its rider), its quick ripples
	# (the legs' reach) taken out; the horse's own back now eases into those too (horse_rig DROP_ATTACK)
	# the seat rides the whole back (it took 92 % and the horse out-bounced its rider), its quick ripples
	# (the legs' reach) taken out, a hand's breadth clear of the floor below so the two never fight
	t.x = _back + 0.012 + (t.x - raw * 0.85)
	for _i in n:
		_rv += ((t - _rs) * Vector3(170.0, 45.0, 60.0) - _rv * Vector3(20.0, 7.0, 8.0)) * d
		_rs += _rv * d
		# never far under the saddle: pushed out by the back, its speed matched, whatever the spring lags
		var pen := _back - 0.015 - _rs.x
		if pen > 0.0:
			_rv.x += (pen * 1500.0 + (back_v - _rv.x) * 40.0) * d
			if pen > 0.04:
				_rs.x = _back - 0.06


## Draw the rider at the rendered moment: the horse's interpolated transform, the back's motion and the
## rider's spring, all of this frame.
func _place_rider(dt: float, ph: float) -> void:
	_ride_follow(dt, ph)
	if _vis == null or not is_instance_valid(_vis):
		return
	var xf := _rig.global_transform
	var yaw := atan2(xf.basis.z.x, xf.basis.z.z)        # Basis(UP, a).z = (sin a, 0, cos a): the negated form was a + PI (the rider faced the tail)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	_vis.global_position = xf.origin + Vector3.UP * _seat_lift() + fwd * (0.04 * _scale())
	_vis_yaw = lerp_angle(_vis_yaw, yaw, 1.0 - exp(-12.0 * dt))
	_vis.global_rotation.y = _vis_yaw


func _process(dt: float) -> void:
	Paddock.step(self, _wd, dt)
	if _rig:
		_rig.global_transform = get_global_transform_interpolated()
	# a rider that died, was hollowed or was moved off (a respawn, travel) is no longer riding
	if rider != null and (not is_instance_valid(rider) or rider.get("riding") != self):
		_release_visual()
		rider = null
		speed = 0.0
	if rider != null:
		# ridden: drive() steps the gait on the tick; draw it at the frame's moment, as the body is
		var ph := lerpf(_phase_prev, _phase, Engine.get_physics_interpolation_fraction())
		_write(ph, dt)
		_place_rider(dt, ph)
		return
	if _air or _land > 0.0:
		_vertical(dt, _ground(global_position).y)       # left in the air (got down mid-leap): it comes down
	# standing: graze now and then, flick the head up
	_graze_t -= dt
	if _graze_t <= 0.0:
		_graze_t = randf_range(4.0, 9.0)
	var down := _graze_t > 2.0
	_head = lerpf(_head, 0.7 if down else 0.0, 1.0 - exp(-1.5 * dt))
	if speed > 0.0 and not rival and not bool(_wd.get("moving", false)) and _call_who == null:      # not wandering its paddock, not running to a whistle
		speed = move_toward(speed, 0.0, 9.0 * dt)
	# off screen it is posed twice a second (as the villagers are: NpcLife.interval), with the time since
	_pose_acc += dt
	if _near_camera() and _pose_acc >= _pose_gap():
		_write(NAN, _pose_acc)
		_pose_acc = 0.0


var _pose_acc := 0.0


func _pose_gap() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null or speed > 0.0 or _air or _land > 0.0:
		return 0.0
	var at := global_position + Vector3.UP * 1.2
	return 0.5 if cam.global_position.distance_squared_to(at) > 36.0 and not cam.is_position_in_frustum(at) else 0.0


## Posed only when the camera could see it (the rig is a skeleton, 30 bones a frame).
func _near_camera() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam == null or cam.global_position.distance_squared_to(global_position) < 110.0 * 110.0


func _write(ph := NAN, dt := 0.0) -> void:
	if _rig == null:
		return
	if is_nan(ph):
		ph = _phase
	_rig.air = 1.0 if _air else 0.0
	_rig.vy = _vy
	_rig.gather = clampf(_gather / GATHER_T, 0.0, 1.0) if _gather > 0.0 else 0.0
	_rig.land = _land
	_rig.pose(ph, speed, _head, dt, _accel)


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
	return float(_d.seat) / 1.315                  # the old unit (deer-built horses), for the reach and trample distances


## Hoofbeats off the gait's own footfalls (horse_rig.footfalls): which hoof, where under the body, how hard.
## Nothing sounds in the gallop's suspension because no hoof plants then. Breed heft makes the draught
## heavier and lower, the fen pony lighter. Tack and breath ride the stride; a snort marks a start and a halt.
func _hooves(dt: float) -> void:
	_snort_t -= dt
	var heft := float(_d.get("heft", 1.0))
	var gait := clampf((speed - float(_d.walk)) / maxf(float(_d.gallop) - float(_d.walk), 0.1), 0.0, 1.0)
	if _air:
		return
	if _surf_age > 0.0:
		_surf_age -= dt
	var steps: Array[int] = []
	if _rig != null:
		steps = _rig.footfalls(_phase_prev, _phase, speed)
	if not steps.is_empty():
		if _surf_age <= 0.0:
			_surf_age = 0.25
			_surf = Foley.surface_at(_space, global_position)
	var fwd := -global_basis.z
	var side := global_basis.x
	var sc := _scale()
	for i: int in steps:
		var hind := i >= 2
		var at := global_position + fwd * (-0.8 if hind else 0.85) * sc + side * (0.16 if i % 2 == 1 else -0.16) * sc
		Foley.hoof(at, _surf, heft, gait, hind)
		if i == 0:
			_tack(at, gait, heft)
	if _prev_fast and speed < float(_d.walk) + 0.6:
		_prev_fast = false
		Foley.horse_sfx("snort", global_position + fwd * 1.2 * sc + Vector3.UP * 1.3 * sc, -10.0, pow(heft, -0.3))
	elif speed > float(_d.trot) + 0.8:
		_prev_fast = true
	if _snort_t <= 0.0:
		_snort_t = randf_range(11.0, 26.0)
		if speed < 3.0 and rider != null:
			Foley.horse_sfx("breath" if randf() < 0.5 else "snort", global_position + fwd * 1.2 * sc + Vector3.UP * 1.3 * sc, -17.0, pow(heft, -0.3))


## Once a stride (the near fore plants): bit, buckles and stirrup iron, leather at the walk, a blown breath at the gallop.
func _tack(at: Vector3, gait: float, heft: float) -> void:
	var up := at + Vector3.UP * 1.3 * _scale()
	_stride_n += 1
	var gp := pow(heft, -0.2)
	Foley.horse_sfx("jingle", up, lerpf(-27.0, -17.0, gait), gp * lerpf(0.95, 1.1, gait))
	if gait < 0.3 and _stride_n % 2 == 0:
		Foley.horse_sfx("creak", up, -26.0, gp)
	if gait > 0.7:
		Foley.horse_sfx("breath", up, -16.0, gp)


## The push-off: a grunt of effort, the hind hooves driving into the ground.
func _takeoff_sfx(k: float) -> void:
	var heft := float(_d.get("heft", 1.0))
	var up := global_position + Vector3.UP * 1.3 * _scale()
	Foley.horse_sfx("grunt", up + (-global_basis.z) * 1.0, lerpf(-16.0, -10.0, k), pow(heft, -0.3))
	var sc := _scale()
	for n in 2:
		Foley.hoof(global_position + global_basis.x * (0.16 if n == 1 else -0.16) * sc - global_basis.z * -0.8 * sc, _surf, heft, 0.5 + 0.5 * k, true)
	Foley.horse_sfx("jingle", up, -18.0, 1.0)


## Touchdown: the forehand takes it, the hindquarters a beat behind, the weight in a thump, tack jangling.
func _landing_sfx(impact: float) -> void:
	var heft := float(_d.get("heft", 1.0))
	var sc := _scale()
	_surf = Foley.surface_at(_space, global_position)
	var g := 0.45 + 0.55 * impact
	var base := global_position
	var fwd := -global_basis.z
	var side := global_basis.x
	for n in 2:
		Foley.hoof(base + fwd * 0.85 * sc + side * (0.16 if n == 1 else -0.16) * sc, _surf, heft, g, false)
	Foley.horse_sfx("thump", base, -12.0 + 7.0 * impact + 4.0 * log(maxf(heft, 0.3)), pow(heft, -0.4))
	Foley.horse_sfx("jingle", base + Vector3.UP * 1.3 * sc, -14.0 + 3.0 * impact, 1.0)
	var hind := get_tree().create_timer(0.07)
	hind.timeout.connect(func() -> void:
		if is_inside_tree():
			for n in 2:
				Foley.hoof(global_position - global_basis.z * -0.8 * sc + global_basis.x * (0.16 if n == 1 else -0.16) * sc, _surf, heft, g, true))


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

# --- the whistle: the horse runs to its rider -------------------------------------------------------

var _call_who: Node3D = null            ## the wanderer it is running to (null: standing)
var _call_t := 0.0                      ## seconds it has been running
var _stuck_t := 0.0                     ## seconds without getting anywhere
const CALL_STOP := 3.2                  ## it halts this far from the wanderer
const CALL_GIVE_UP := 45.0              ## a run longer than this ends where the old whistle did: beside the wanderer
const CALL_FAR := 320.0                 ## farther than this it is too far to hear: the whistle brings it beside her at once


## Start running to `who`. False when it cannot (ridden, or already there).
func call_to(who: Node3D) -> bool:
	if rider != null or who == null or global_position.distance_to(who.global_position) < CALL_STOP + 1.0:
		return false
	_call_who = who
	set_physics_process(true)
	_call_t = 0.0
	_stuck_t = 0.0
	at_post = false
	_gather = 0.0
	Foley.horse_sfx("snort", global_position + Vector3.UP * 1.3, -8.0, pow(float(_d.get("heft", 1.0)), -0.3))
	return true


func calling() -> bool:
	return _call_who != null


func _stop_call() -> void:
	_call_who = null
	set_physics_process(false)
	_stuck_t = 0.0


func _physics_process(dt: float) -> void:
	if _call_who == null:
		return
	if rider != null or not is_instance_valid(_call_who):
		_stop_call()
		return
	_space = get_world_3d().direct_space_state
	_call_t += dt
	var to := _call_who.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < CALL_STOP:
		_stop_call()                       # it slows to a halt on the speed's own decay (the standing branch of _process)
		return
	if _call_t > CALL_GIVE_UP or _stuck_t > 1.6:
		_arrive_beside()
		return
	var dir := to / dist
	var base := global_position + Vector3.UP * 0.9
	var pick := dir
	var free := false
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var d := dir.rotated(Vector3.UP, turn)
		var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(base, base + d * 2.4, Layers.WORLD))
		if hit.is_empty():
			pick = d
			free = true
			break
	_stuck_t = 0.0 if free else _stuck_t + dt
	var wading := RealmLand.in_water(global_position.x, global_position.z) and not bool(_d.get("wade", false))
	var top := float(_d.gallop) * HorseBond.mult(breed)
	var want := minf(top, float(_d.walk)) if wading else (top if dist > 14.0 else float(_d.trot))
	if not free:
		want = 0.0
	speed = move_toward(speed, want, 7.0 * dt)
	_yaw = lerp_angle(_yaw, atan2(-pick.x, -pick.z), 1.0 - exp(-7.0 * dt))
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var np := global_position + fwd * speed * dt
	var g := _ground(np)
	if g.y - global_position.y > float(_d.climb) + 0.5:
		_stuck_t += dt                      # a wall of earth: it does not climb it
		np = global_position
	np.y = lerpf(global_position.y, g.y, 1.0 - exp(-14.0 * dt))
	global_position = np
	global_basis = Basis(Vector3.UP, _yaw)
	_phase_prev = _phase
	_phase += TAU * _rig.freq(speed) * dt
	_accel = Vector2((speed - _speed_prev) / maxf(dt, 0.001), 0.0)
	_speed_prev = speed
	_hooves(dt)


## Gave up on the way: stand beside the wanderer, as the first whistle did.
func _arrive_beside() -> void:
	var who := _call_who
	_stop_call()
	if who == null:
		return
	var back := -who.global_basis.z
	back.y = 0.0
	var to := who.global_position - back.normalized() * 3.0
	global_position = _ground(to)
	speed = 0.0
