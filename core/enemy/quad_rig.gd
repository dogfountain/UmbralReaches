class_name QuadRig
extends CharacterRig
## Low crawling skeleton for the jumpers (Crawler, Leaper). Same contract Enemy uses on the
## humanoid rig -- animate(vel, on_floor, delta), cast(), socket(), muzzle() -- so Enemy code is
## unchanged. Diagonal trot gait whose phase advances with distance (feet don't skate), body bob,
## spidery knees that lift on the swing, a coiled crouch on the windup, and a stretched flight
## pose (forelegs reaching, hind legs trailing) while airborne.
##
## Layout, facing -Z:  Body ─ Front ─ Head
##                         └─ Tail
##                     Body ─ leg_{fl,fr,bl,br}_hip ─ _knee ─ _foot

@export var body_height := 0.42        ## hip height above the feet at rest
@export var body_len := 0.9
@export var hip_spread := 0.17
@export var upper_len := 0.26          ## hip → knee (goes out and up: spider knees)
@export var stride_len := 0.55         ## metres per half-cycle
## Opt-in (r30, the Leaper only): legs under the body like a hound's -- thigh down, elbow back on
## the forelegs, stifle forward and a hock on the hind legs, a lateral-sequence walk. Off by
## default, so every other rig (and the Thornwarden's fitted model) keeps the spider layout.
@export var upright := false

var _body: Node3D
var _front: Node3D
var _tail: Node3D
var _legs: Array[Dictionary] = []      ## {hip, knee, foot, side, front, phase_off}
var _coil := 0.0
var _coil_dur := 0.6
var _snap := 0.0          ## strike: head and forelegs thrown forward
var _snap_t := -1.0
var _flinch := 0.0
var _flinch_side := 0.0
var _reel := 0.0          ## stagger: belly down, legs splayed, for the whole punish
var _fold := 0.0          ## death: legs give, belly to the ground
var _fall_base := Transform3D.IDENTITY
var _fall_side := 1.0
var _howl := 0.0          ## a pack call: rears on the hind legs, head thrown up
var _howl_t := -1.0
var _howl_dur := 0.8
var _bound := 0.0         ## 0 a trot, 1 a bounding run (upright rigs)


func _build() -> void:
	_sockets.clear()
	_equipped.clear()
	_body = ProcMesh.node(self, "Body", Vector3(0, body_height, 0))
	_sockets["body"] = _body
	_sockets["chest"] = _body           # Enemy.attach_rig checks for "chest"
	_sockets["pelvis"] = _body
	_front = ProcMesh.node(_body, "Front", Vector3(0, 0.04, -body_len * 0.45))
	_sockets["front"] = _front
	_head = ProcMesh.node(_front, "Head", Vector3(0, 0.03, -0.16))
	_sockets["head"] = _head
	_tail = ProcMesh.node(_body, "Tail", Vector3(0, 0.02, body_len * 0.45))
	_sockets["tail"] = _tail
	_pelvis = _body                     # base-class guards read _pelvis / _chest / _head
	_chest = _front
	var defs := [
		["fl", -1.0, true, 0.0], ["fr", 1.0, true, PI],
		["bl", -1.0, false, PI], ["br", 1.0, false, 0.0],
	]
	if upright:
		# lateral sequence: left hind, left fore, right hind, right fore, a quarter cycle apart
		defs = [
			["fl", -1.0, true, PI * 0.5], ["fr", 1.0, true, PI * 1.5],
			["bl", -1.0, false, 0.0], ["br", 1.0, false, PI],
		]
	for d in defs:
		var tag: String = d[0]
		var sx: float = d[1]
		var is_front: bool = d[2]
		var z := -body_len * 0.36 if is_front else body_len * 0.34
		var hip := ProcMesh.node(_body, "Hip_" + tag, Vector3(sx * hip_spread, -0.02, z))
		var knee_at := Vector3(sx * upper_len, 0.1, 0.0)
		var foot_at := Vector3(sx * 0.07, -(body_height + 0.08), 0.0)
		if upright:
			var seg := (body_height - 0.05) * 0.5
			knee_at = Vector3(0.0, -seg, 0.06 if is_front else -0.08)
			foot_at = Vector3(0.0, -seg, -0.04 if is_front else 0.1)
		var knee := ProcMesh.node(hip, "Knee", knee_at)
		var foot := ProcMesh.node(knee, "Foot", foot_at)
		_sockets["leg_%s_hip" % tag] = hip
		_sockets["leg_%s_knee" % tag] = knee
		_sockets["leg_%s_foot" % tag] = foot
		_legs.append({"hip": hip, "knee": knee, "foot": foot, "side": sx, "front": is_front, "off": d[3]})


func animate(vel: Vector3, on_floor: bool, delta: float) -> void:
	if _body == null or delta <= 0.0:
		return
	_t += delta
	var flat := Vector3(vel.x, 0.0, vel.z)
	var speed := flat.length()
	var target_stride := clampf(speed / maxf(walk_speed, 0.1), 0.0, 1.4)
	if not on_floor:
		target_stride = 0.0
	_stride = lerpf(_stride, target_stride, 1.0 - exp(-6.2 * delta))
	if on_floor:
		# a stride is the rig's own length: a boss at 3.8x steps 3.8x as far per cycle (a heavy beast
		# does not patter at a dog's cadence)
		_phase += speed * delta / (stride_len * maxf(scale.x, 0.25)) * PI
	_air = move_toward(_air, 0.0 if on_floor else 1.0, delta * 4.6)
	if on_floor and not _was_floor:
		_land = clampf(-_prev_vel.y / 8.0, 0.3, 1.0)
	_was_floor = on_floor
	_land = move_toward(_land, 0.0, delta * 2.2)
	_prev_vel = vel
	var yaw := rotation.y
	_turn = lerpf(_turn, wrapf(yaw - _prev_yaw, -PI, PI) / maxf(delta, 0.0001), 1.0 - exp(-4.6 * delta))
	_prev_yaw = yaw
	if _gesture_t >= 0.0:
		_gesture_t += delta
		# coil fast, hold it trembling for the rest of the telegraph, then let go
		var k := _gesture_t / _coil_dur
		var ease := smoothstep(0.0, 0.35, k) * (1.0 - smoothstep(1.0, 1.2, k))
		_gesture = ease * (1.0 + sin(_t * 12.0) * 0.03)
		if k > 1.2:
			_gesture_t = -1.0
	else:
		_gesture = move_toward(_gesture, 0.0, delta * 2.6)
	if _snap_t >= 0.0:
		_snap_t += delta
		_snap = sin(smoothstep(0.0, 1.0, clampf(_snap_t / 0.34, 0.0, 1.0)) * PI)
		if _snap_t > 0.34:
			_snap_t = -1.0
			_snap = 0.0
	_flinch = move_toward(_flinch, 0.0, delta * 3.4)
	_reel = move_toward(_reel, 0.0, delta * 0.75)
	if _fold > 0.0:
		_fold = minf(_fold + delta * 1.2, 1.0)
	# coil = the crouch before a pounce; Enemy squashes the whole visual too, this bends the legs
	_coil = move_toward(_coil, _gesture, delta * 4.4)
	if _howl_t >= 0.0:
		_howl_t += delta
		_howl = sin(smoothstep(0.0, 1.0, clampf(_howl_t / _howl_dur, 0.0, 1.0)) * PI)
		if _howl_t > _howl_dur:
			_howl_t = -1.0
			_howl = 0.0

	var st := _stride
	# hound rigs run: past a walk the gait gathers into a bound (fore pair, then hind pair) and the back flexes
	# (only a light hound bounds: past 2x its size it lopes, the gather and the back flex barely there)
	_bound = smoothstep(0.75, 1.15, st) * (1.0 - 0.75 * smoothstep(1.4, 2.6, scale.x)) if upright else 0.0
	var up := 1.0 if upright else 0.0
	var flex := sin(_phase * (1.0 if _bound > 0.5 else 2.0))          # the back's rock: twice a trot cycle, once a bound
	var bob := absf(sin(_phase)) * (0.035 + 0.03 * up + 0.05 * _bound) * st
	var breathe := sin(_t * 2.4) * 0.012 * (1.0 - clampf(st, 0.0, 1.0))
	_body.position.y = body_height + bob + breathe - _land * 0.14 - _coil * 0.16 + _air * 0.05 - _fold * body_height * 0.75 - _reel * body_height * 0.35
	_body.rotation.x = (0.06 + 0.03 * up + 0.12 * _bound) * flex * st - _air * 0.12 + _coil * 0.18 + _land * 0.1 + _snap * 0.22 - _flinch * 0.3 - _howl * 0.35
	# a stagger is not a pose held still: flat on its belly it shudders, shakes its head and scrabbles
	var shake := _reel * (1.0 - _fold)
	_body.rotation.z = -_turn * 0.05 + sin(_phase) * 0.04 * st + _flinch * _flinch_side * 0.35 + _fold * 0.4 * (1.0 - 0.7 * up) + sin(_t * 9.0) * 0.07 * shake + (0.3 * _fall_side + sin(_t * 3.4) * 0.14) * shake * up
	_body.rotation.x += 0.2 * shake * up                                   # a hound reels onto its haunch, not onto its nose
	_body.rotation.y = sin(_t * 2.7) * 0.22 * shake * up
	_body.position.x = sin(_t * 5.3) * 0.03 * shake + sin(_t * 3.4) * 0.1 * shake * up
	_front.rotation.y = -_turn * (0.08 + 0.1 * up) + sin(_phase) * (0.05 + 0.07 * up) * st * (1.0 - _bound)
	_front.rotation.x = _snap * 0.3 - _coil * 0.2 - (0.05 + 0.14 * _bound) * flex * st * up
	_head.rotation.x = -0.1 * st + (0.07 + 0.08 * _bound) * flex * st * up + _coil * 0.35 + sin(_t * 1.1) * 0.05 * (1.0 - st) - _air * 0.25 - _snap * 0.55 - _flinch * 0.5 + _fold * 0.4 - _howl * 0.9
	_head.rotation.y = sin(_t * 0.6) * 0.18 * (1.0 - clampf(st, 0.0, 1.0)) + sin(_t * 7.0) * 0.4 * shake
	_head.rotation.x += 0.35 * shake
	_tail.rotation.y = sin(_phase + 1.4) * 0.35 * st * (1.0 - 0.6 * _bound) + sin(_t * 1.7) * 0.12 - _turn * 0.1
	_tail.rotation.x = -0.15 + _air * 0.35 + _coil * 0.2 + (0.1 + 0.2 * _bound) * sin(_phase * (1.0 if _bound > 0.5 else 2.0) - 0.9) * st * up + 0.25 * _bound * st

	if upright:
		_animate_upright(st)
		if _fold > 0.0:
			_topple()
		return
	_animate_spider(st)
	if _fold > 0.0:
		_topple()


func _animate_spider(st: float) -> void:
	for leg in _legs:
		var hip: Node3D = leg.hip
		var knee: Node3D = leg.knee
		var sx: float = leg.side
		var ph: float = _phase + float(leg.off)
		var swing := sin(ph)                  # >0 = foot behind the hip, <0 = ahead
		var lift := maxf(0.0, -cos(ph))       # lifted while the foot travels forward
		var front: bool = leg.front
		# fore/aft swing is a yaw on a sideways leg; lift raises the knee during the swing phase
		# the sweep is what the stride needs of a foot this far out from the hip (a fixed 0.42 rad left a
		# burrower's pillars skating at a third of the ground they covered)
		var yaw_swing := swing * clampf(stride_len * 0.5 / (upper_len + 0.07), 0.4, 0.75) * st
		var air_reach := (-0.65 if front else 0.75) * _air   # forelegs reach, hind legs trail
		hip.rotation.y = -sx * (yaw_swing + air_reach)
		var reach := (_snap * 0.5) if front else 0.0
		var scrab := maxf(0.0, sin(_t * 6.5 + float(leg.off) * 1.3 + (0.0 if front else 1.1))) * _reel * (1.0 - _fold)
		# death: the legs kick once and curl in over the belly (they stood straight up like a tipped toy)
		var curl := smoothstep(0.0, 0.5, _fold)
		var kick := sin(clampf(_fold / 0.5, 0.0, 1.0) * PI) * sin(_t * 17.0 + float(leg.off)) * 0.2
		hip.rotation.z = sx * (lift * 0.38 * st - _coil * 0.25 + _land * 0.2 - _air * 0.15 + reach + _reel * 0.3 + scrab * 0.3 + curl * 1.55 + kick)
		knee.rotation.z = -sx * (lift * 0.25 * st + _coil * 0.35 - _air * 0.4 - _fold * 0.3 + scrab * 0.35 - curl * 1.45)
		knee.rotation.x = (0.25 if front else -0.25) * _air
		(leg.foot as Node3D).rotation.z = -(hip.rotation.z + knee.rotation.z)     # the paw stays flat


## Hound legs (upright): fore/aft swing is a pitch at the hip, the lift folds the knee / hock, and
## a crouch (coil, landing, death) folds every leg in a zig-zag so the paws stay on the ground.
func _animate_upright(st: float) -> void:
	for leg in _legs:
		var hip: Node3D = leg.hip
		var knee: Node3D = leg.knee
		var sx: float = leg.side
		var front: bool = leg.front
		# a bound: the fore pair lands together, then the hind pair (a small lead between left and right)
		var off_run := (0.0 if front else PI * 0.9) + (0.35 if sx > 0.0 else 0.0)
		var ph: float = _phase + lerp_angle(float(leg.off), off_run, _bound)
		var swing := sin(ph)                  # >0 = foot behind the hip, <0 = ahead
		var lift := maxf(0.0, -cos(ph))
		var push := maxf(0.0, swing) * maxf(0.0, cos(ph))      # the end of the stance: the leg straightens and drives
		var fb := 1.0 if front else -1.0
		var scrab := maxf(0.0, sin(_t * 6.5 + float(leg.off) * 1.3)) * _reel * (1.0 - _fold)
		var bend := _coil * 0.6 + _land * 0.4 + _fold * 0.5 + _howl * (0.0 if front else 0.7) + scrab * 0.5 + smoothstep(0.3, 0.9, _fold) * 0.8 + _reel * (1.0 - _fold) * 0.75
		var reach := (0.75 * _air + _snap * 0.6 + _howl * 0.5) if front else -0.85 * _air
		var sa := pow(clampf(st, 0.0, 1.4), 0.55)              # a slow walk still takes whole steps (the swing shrank with the pace)
		hip.rotation.x = -swing * (0.5 + 0.12 + 0.25 * _bound) * sa + reach + fb * bend * 0.55
		hip.rotation.z = sx * (_fold * 0.12 + _flinch * 0.1 + _reel * 0.3)
		hip.rotation.y = 0.0
		knee.rotation.x = -fb * (bend + lift * (0.9 + 0.35 * _bound) * sa - push * 0.3 * sa + (0.35 if front else 0.2) * _air)
		knee.rotation.z = 0.0
		(leg.foot as Node3D).rotation.x = -(hip.rotation.x + knee.rotation.x)


func cast(_sound := "") -> void:
	telegraph(_coil_dur)


## The crouch-and-tremble before a strike or pounce, held for `dur` seconds.
func telegraph(dur: float) -> void:
	_coil_dur = maxf(dur, 0.12)
	_gesture_t = 0.0


## A pack call: up on the haunches, head thrown back (no coil: it is not an attack).
func howl(dur: float) -> void:
	_howl_dur = maxf(dur, 0.2)
	_howl_t = 0.0


func strike() -> void:
	_gesture_t = -1.0
	_gesture = 0.0
	_snap_t = 0.0


func flinch(amount: float, side := 0.0) -> void:
	_flinch = clampf(maxf(_flinch, amount), 0.0, 1.0)
	_flinch_side = side


func stagger() -> void:
	_fall_side = -1.0 if _flinch_side < 0.0 else 1.0
	_gesture_t = -1.0
	_gesture = 0.0
	_flinch = 1.0
	_reel = 1.0


## The legs give and the body rolls over: a spider onto its back with the legs curled, a hound
## onto its side.
func collapse(_back := false) -> void:
	if _fold <= 0.0:
		_fall_base = transform
		_fall_side = -1.0 if _flinch_side < 0.0 else 1.0
	_fold = maxf(_fold, 0.001)


func _topple() -> void:
	var u := clampf((_fold - 0.1) / 0.9, 0.0, 1.0)
	var fall := u * u * (3.0 - 2.0 * u) * 0.4 + u * u * u * 0.6
	var rebound := sin(clampf((_fold - 0.8) / 0.2, 0.0, 1.0) * PI) * 0.08
	if upright:
		# a hound drops (the legs buckle first, the belly nearly on the ground), then the weight goes over
		# onto one flank and it skids a little and settles, the legs folded under it and not in the air
		var tip := clampf((_fold - 0.3) / 0.7, 0.0, 1.0)
		fall = tip * tip * (3.0 - 2.0 * tip)
		rebound = sin(clampf((_fold - 0.75) / 0.25, 0.0, 1.0) * PI) * 0.05
	var roll := _fall_side * (1.3 if upright else 1.6) * (fall - rebound)
	var rot := Basis.from_euler(Vector3(0.0, 0.0, roll))
	var base := _fall_base.basis
	var scl := base.get_scale()
	var base_rot := base.orthonormalized()
	var pivot := Vector3(0.0, body_height * 0.6, 0.0) * scl                # roll about the body, not the paws
	var lift := 0.0 if upright else body_height * 0.35 * sin(minf(fall, 1.0) * PI * 0.5)
	var skid := Vector3.ZERO
	if upright:
		lift = body_height * 0.1 * fall
		skid = Vector3(0.0, 0.0, -body_len * 0.3 * smoothstep(0.3, 1.0, _fold) * (1.0 - 0.3 * smoothstep(0.7, 1.0, _fold))) * scl.x
	transform = Transform3D(base_rot * rot * Basis.from_scale(scl), _fall_base.origin + base_rot * (pivot - rot * pivot + Vector3(0.0, lift, 0.0) + skid))


func muzzle() -> Vector3:
	return _head.global_position if _head else global_position + Vector3.UP * body_height
