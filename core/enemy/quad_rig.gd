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
	_stride = lerpf(_stride, target_stride, 1.0 - exp(-10.0 * delta))
	if on_floor:
		_phase += speed * delta / stride_len * PI
	_air = move_toward(_air, 0.0 if on_floor else 1.0, delta * 7.0)
	if on_floor and not _was_floor:
		_land = clampf(-_prev_vel.y / 8.0, 0.3, 1.0)
	_was_floor = on_floor
	_land = move_toward(_land, 0.0, delta * 3.0)
	_prev_vel = vel
	var yaw := rotation.y
	_turn = lerpf(_turn, wrapf(yaw - _prev_yaw, -PI, PI) / maxf(delta, 0.0001), 1.0 - exp(-6.0 * delta))
	_prev_yaw = yaw
	if _gesture_t >= 0.0:
		_gesture_t += delta
		# coil fast, hold it trembling for the rest of the telegraph, then let go
		var k := _gesture_t / _coil_dur
		_gesture = clampf(k * 2.2, 0.0, 1.0) * (1.0 + sin(_t * 40.0) * 0.06)
		if k > 1.15:
			_gesture_t = -1.0
			_gesture = 0.0
	if _snap_t >= 0.0:
		_snap_t += delta
		_snap = sin(clampf(_snap_t / 0.3, 0.0, 1.0) * PI)
		if _snap_t > 0.3:
			_snap_t = -1.0
			_snap = 0.0
	_flinch = move_toward(_flinch, 0.0, delta * 4.5)
	_reel = move_toward(_reel, 0.0, delta * 0.9)
	if _fold > 0.0:
		_fold = minf(_fold + delta * 1.5, 1.0)
	# coil = the crouch before a pounce; Enemy squashes the whole visual too, this bends the legs
	_coil = move_toward(_coil, _gesture, delta * 6.0)
	if _howl_t >= 0.0:
		_howl_t += delta
		_howl = sin(clampf(_howl_t / _howl_dur, 0.0, 1.0) * PI)
		if _howl_t > _howl_dur:
			_howl_t = -1.0
			_howl = 0.0

	var st := _stride
	var bob := absf(sin(_phase)) * 0.035 * st
	var breathe := sin(_t * 2.4) * 0.012 * (1.0 - clampf(st, 0.0, 1.0))
	_body.position.y = body_height + bob + breathe - _land * 0.14 - _coil * 0.16 + _air * 0.05 - _fold * body_height * 0.75 - _reel * body_height * 0.35
	_body.rotation.x = 0.06 * sin(_phase * 2.0) * st - _air * 0.12 + _coil * 0.18 + _land * 0.1 + _snap * 0.22 - _flinch * 0.3 - _howl * 0.35
	_body.rotation.z = -_turn * 0.05 + sin(_phase) * 0.04 * st + _flinch * _flinch_side * 0.35 + _fold * 0.4
	_front.rotation.y = -_turn * 0.08 + sin(_phase) * 0.05 * st
	_front.rotation.x = _snap * 0.3 - _coil * 0.2
	_head.rotation.x = -0.1 * st + _coil * 0.35 + sin(_t * 1.1) * 0.05 * (1.0 - st) - _air * 0.25 - _snap * 0.55 - _flinch * 0.5 + _fold * 0.4 - _howl * 0.9
	_head.rotation.y = sin(_t * 0.6) * 0.18 * (1.0 - clampf(st, 0.0, 1.0))
	_tail.rotation.y = sin(_phase + 1.4) * 0.35 * st + sin(_t * 1.7) * 0.12 - _turn * 0.1
	_tail.rotation.x = -0.15 + _air * 0.35 + _coil * 0.2

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
		var yaw_swing := swing * 0.42 * st
		var air_reach := (-0.65 if front else 0.75) * _air   # forelegs reach, hind legs trail
		hip.rotation.y = -sx * (yaw_swing + air_reach)
		var reach := (_snap * 0.5) if front else 0.0
		hip.rotation.z = sx * (lift * 0.38 * st - _coil * 0.25 + _land * 0.2 - _air * 0.15 + reach + _fold * 0.55 + _reel * 0.3)
		knee.rotation.z = -sx * (lift * 0.25 * st + _coil * 0.35 - _air * 0.4 - _fold * 0.3)
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
		var ph: float = _phase + float(leg.off)
		var swing := sin(ph)                  # >0 = foot behind the hip, <0 = ahead
		var lift := maxf(0.0, -cos(ph))
		var fb := 1.0 if front else -1.0
		var bend := _coil * 0.6 + _land * 0.4 + _fold * 0.5 + _howl * (0.0 if front else 0.7)
		var reach := (0.75 * _air + _snap * 0.6 + _howl * 0.5) if front else -0.85 * _air
		hip.rotation.x = -swing * 0.5 * st + reach + fb * bend * 0.55
		hip.rotation.z = sx * (_fold * 0.5 + _flinch * 0.1 + _reel * 0.3)
		hip.rotation.y = 0.0
		knee.rotation.x = -fb * (bend + lift * 0.9 * st + (0.35 if front else 0.2) * _air)
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
	var roll := _fall_side * (1.45 if upright else 2.7) * (fall - rebound)
	var rot := Basis.from_euler(Vector3(0.0, 0.0, roll))
	var base := _fall_base.basis
	var scl := base.get_scale()
	var base_rot := base.orthonormalized()
	var pivot := Vector3(0.0, body_height * 0.6, 0.0) * scl                # roll about the body, not the paws
	var lift := 0.0 if upright else body_height * 0.35 * sin(minf(fall, 1.0) * PI * 0.5)
	transform = Transform3D(base_rot * rot * Basis.from_scale(scl), _fall_base.origin + base_rot * (pivot - rot * pivot + Vector3(0.0, lift, 0.0)))


func muzzle() -> Vector3:
	return _head.global_position if _head else global_position + Vector3.UP * body_height
