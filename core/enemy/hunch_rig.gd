extends CharacterRig
## Enemy humanoid skeleton: the same joints and sockets as the wanderer's CharacterRig (so
## EnemyBody dresses it unchanged), but its own pose. The base rig stands upright and raises a
## staff to "cast" -- on a wretch that read as a mannequin waving at you. This one:
##   posture   a per-kind hunch, crouch, forward-hanging arms, a limp, idle sway and twitches
##   telegraph rears up for exactly the windup: claws drawn high and back, chest arched, head up
##             (the silhouette change IS the dodge cue, readable at 15 m in greyscale)
##   strike    a fast two-handed rake down and forward with a lunge of the chest
##   flinch    a snap back away from a hit, scaled by damage; stagger = a long reel, arms limp
##   collapse  folds at the knees and pitches forward while the flesh burns away
## No class_name (project rule): Enemy preloads it by path. Enemy calls telegraph/strike/flinch/
## stagger/collapse when they exist on its rig; QuadRig answers the same five.

## Forward lean of the torso, radians (wretch 0.5, husk 0.25).
var hunch := 0.3
## Knee bend at rest, 0..1 (lowers the pelvis to match).
var crouch := 0.25
## Arms carried forward of the body, radians.
var arm_reach := 0.35
## Head pushed forward against the hunch so the face still looks ahead (0..1).
var head_jut := 0.7
## 0 = even gait, 1 = a heavy drag on the left leg (husk).
var limp := 0.0
## Idle sway amplitude and nervous head twitches (0..1).
var sway := 0.5
var twitch := 0.4
## Arm splay out to the sides (radians): big shouldered things carry their arms wide.
var splay := 0.18
## 0..1: a thing that floats instead of walking (the Ascended Warden): no stride to read, so the body
## leans into its travel, hangs and bobs on a slow breath, and the arms trail.
var hover := 0.0

var _wind := 0.0          ## 0..1 raised for the windup
var _wind_dur := 0.42
var _wind_t := -1.0
var _rake := 0.0          ## strike swing 0..1..0
var _rake_t := -1.0
var _flinch := 0.0
var _flinch_side := 0.0
var _reel := 0.0          ## stagger
var _over := 0.0          ## 0..1 through the HELD part of the windup: the coil keeps tightening
var _fold := 0.0          ## death collapse
var _fall_base := Transform3D.IDENTITY   ## the rig's own transform when it began to fall
var _fall_back := false
var _howl := 0.0          ## a pack call: chest up, head back, arms flung wide and low
var _howl_t := -1.0
var _howl_dur := 0.8
var _twitch_t := 0.0
var _idle_phase := 0.0
var _breath_pitch := 0.0
var _twitch_to := Vector2.ZERO
var _twitch_at := Vector2.ZERO

const RAKE_TIME := 0.32
## The wanderer's pelvis sits at 0.94 with the foot joint 9 cm under the floor (the robe and
## boots hide it); bare enemy feet need the soles on the ground.
const PELVIS_Y := 1.04


func _ready() -> void:
	super._ready()
	_twitch_t = randf_range(0.5, 2.0)
	_idle_phase = randf() * TAU
	_t = randf() * 30.0


## The rear-up before a strike, held for `dur` seconds (Enemy passes its windup time).
func telegraph(dur: float) -> void:
	_wind_dur = maxf(dur, 0.12)
	_wind_t = 0.0 if _wind <= 0.6 else _wind * _wind_dur * 0.55     # a feint that becomes a swing stays reared


## Kept for callers that only know the base contract: a windup of the default length, and no
## staff-cast sound (the base cast() plays the wanderer's bolt sound).
func cast(_sound := "") -> void:
	telegraph(_wind_dur)


## The pack call: not a windup (arms go wide and LOW, not high and back), so it never reads as
## an attack.
func howl(dur: float) -> void:
	_howl_dur = maxf(dur, 0.2)
	_howl_t = 0.0


func strike() -> void:
	_wind_t = -1.0
	_rake_t = 0.0


## `side` -1..1: which way the hit came from (local x), for a twist away from it.
func flinch(amount: float, side := 0.0) -> void:
	_flinch = clampf(maxf(_flinch, maxf(amount, 0.45)), 0.0, 1.0)
	_flinch_side = side


func stagger() -> void:
	_reel = 1.0
	_wind_t = -1.0
	_wind = 0.0


## `back`: the killing blow was heavy, so the body is thrown onto its back instead of pitching
## forward onto its face.
func collapse(back := false) -> void:
	if _fold <= 0.0:
		_fall_base = transform
		_fall_back = back
	_fold = maxf(_fold, 0.001)


func animate(vel: Vector3, on_floor: bool, delta: float) -> void:
	if delta > 0.0:
		_tick_poses(delta)
	super.animate(vel, on_floor, delta)
	if _fold > 0.0:
		_topple()


## The dead do not hover folded at the knees: they go over. The knees give first, then the whole
## body falls about the feet, gathering speed like a weight, and settles with a small rebound.
func _topple() -> void:
	var u := clampf((_fold - 0.3) / 0.7, 0.0, 1.0)             # the knees give first (see _legacy_pose), then it goes over
	var fall := u * u * (3.0 - 2.0 * u) * 0.35 + u * u * u * 0.65           # slow start, hard finish
	var rebound := sin(clampf((_fold - 0.82) / 0.18, 0.0, 1.0) * PI) * 0.07
	var pitch := (1.38 if _fall_back else -1.42) * (fall - rebound)
	var side := _flinch_side if absf(_flinch_side) > 0.2 else (1.0 if _idle_phase > PI else -1.0)
	var roll := side * 0.3 * fall + sin(_fold * 9.0) * 0.03 * (1.0 - u)
	var rot := Basis.from_euler(Vector3(pitch, side * 0.45 * fall, roll))     # it twists as it falls: not a plank
	var base := _fall_base.basis
	var scl := base.get_scale()
	var base_rot := base.orthonormalized()
	transform = Transform3D(base_rot * rot * Basis.from_scale(scl), _fall_base.origin + base_rot * Vector3(0.0, 0.1 * fall, 0.0))


func _tick_poses(delta: float) -> void:
	if _wind_t >= 0.0:
		_wind_t += delta
		# rise fast, then hold and tremble: most of the windup is spent fully raised
		var wu := clampf(_wind_t / (_wind_dur * 0.55), 0.0, 1.0)
		_wind = smoothstep(0.0, 1.0, wu)
		_over = clampf((_wind_t - _wind_dur * 0.55) / maxf(_wind_dur * 0.45, 0.05), 0.0, 1.0)
		if _wind_t > _wind_dur + 0.25:
			_wind_t = -1.0
	else:
		_wind = move_toward(_wind, 0.0, delta * (5.0 if _rake_t >= 0.0 else 2.4))
		_over = move_toward(_over, 0.0, delta * 8.0)
	if _rake_t >= 0.0:
		_rake_t += delta
		var k := _rake_t / RAKE_TIME
		_rake = sin(smoothstep(0.0, 1.0, clampf(k, 0.0, 1.0)) * PI * 0.5) if k < 1.0 else maxf(0.0, 1.0 - (k - 1.0) * 1.35)
		if _rake <= 0.0 and k >= 1.0:
			_rake_t = -1.0
	_breath_pitch = sin(_t * 1.9) * 0.025 * sway
	_flinch = move_toward(_flinch, 0.0, delta * 1.8)
	_reel = move_toward(_reel, 0.0, delta * 0.65)
	if _howl_t >= 0.0:
		_howl_t += delta
		var hk := clampf(_howl_t / _howl_dur, 0.0, 1.0)
		_howl = smoothstep(0.0, 0.25, hk) * (1.0 - smoothstep(0.75, 1.0, hk))
		if _howl_t > _howl_dur:
			_howl_t = -1.0
			_howl = 0.0
	if _fold > 0.0:
		_fold = minf(_fold + delta * 1.15, 1.0)
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.6, 2.6) / maxf(twitch, 0.05)
		_twitch_to = Vector2(randf_range(-0.35, 0.35), randf_range(-0.6, 0.6)) * twitch
	_twitch_at = _twitch_at.lerp(_twitch_to, 1.0 - exp(-7.0 * delta))
	_twitch_to = _twitch_to.lerp(Vector2.ZERO, 1.0 - exp(-2.0 * delta))


## Replaces the wanderer's upright stride (base animate() calls it every frame).
func _legacy_pose(s: float, c: float, st: float, breathe: float, idle: float) -> void:
	var w := _wind
	var r := _rake
	var f := _flinch
	var reel := _reel
	var fold := _fold
	# a stagger in two beats: the blow knocks it back (chest up, arms flung), then it sags forward on
	# buckling knees, head hanging and lolling, weaving on its feet until it gathers itself
	var knock := smoothstep(0.78, 1.0, reel)
	var slump := (1.0 - smoothstep(0.7, 0.95, reel)) * smoothstep(0.0, 0.3, reel)
	var weave := sin(_t * 4.2 + _idle_phase)
	var kneel := clampf(fold / 0.3, 0.0, 1.0)          # death: down onto the knees before the body goes over
	var ov := _over
	var gl := hover * clampf(st, 0.0, 1.0)
	var gait := 1.0 + limp * 0.4
	var shift := sin(_t * 0.55 + _idle_phase) * sway    # weight rolls from one foot to the other
	# legs: a bent-knee shuffle; the limp leg swings short and drags
	var knee_rest := crouch * 0.95 + w * 0.25 + ov * 0.2 + kneel * 1.75 + slump * 0.6 + knock * 0.2
	var hip_rest := crouch * 0.45 + w * 0.1 + ov * 0.08 + kneel * 0.75 + slump * 0.32
	var reach_max := 0.0
	for i in 2:
		var ps := s if i == 0 else -s
		var pc := c if i == 0 else -c
		var short := 1.0 - limp * 0.55 if i == 0 else 1.0
		var hip := ps * 0.42 * st * short + hip_rest
		var knee := maxf(0.0, pc) * 1.05 * st * short + 0.12 * st + knee_rest + _land * 0.5
		hip += _air * 0.45 + _land * 0.25
		knee += _air * 0.75
		knee += maxf(0.0, shift if i == 0 else -shift) * 0.14 * idle      # the resting leg softens
		knee += maxf(0.0, weave if i == 0 else -weave) * 0.3 * slump      # one knee, then the other, gives
		_hip[i].rotation.x = hip
		_hip[i].rotation.z = (-1.0 if i == 0 else 1.0) * (0.06 + crouch * 0.08)
		_knee[i].rotation.x = -knee
		_foot[i].rotation.x = -(hip - knee) * 0.75
		reach_max = maxf(reach_max, 0.42 * cos(hip) + 0.42 * cos(hip - knee))
	# the pelvis drops to keep the bent feet on the ground (thigh and shin are 0.42 m each)
	var bend := maxf(0.0, 0.84 - reach_max)       # down until the longer leg's foot meets the ground
	var lurch := absf(s) * limp * 0.05 * st
	_pelvis.position.y = PELVIS_Y - bend + 0.04 * st * (absf(c) - 0.6) * gait - lurch - _land * 0.13 + _air * 0.04 + breathe * 0.006 * idle
	_pelvis.position.y += sin(_t * 1.5 + _idle_phase) * 0.05 * hover
	_pelvis.position.x = -s * (0.03 + limp * 0.05) * st + sin(_t * 0.9) * 0.02 * sway * idle + shift * 0.035 * idle + weave * 0.07 * slump
	_pelvis.rotation.y = s * 0.12 * st
	_pelvis.rotation.z = -_turn * 0.02 + s * limp * 0.12 * st + sin(_t * 0.9) * 0.03 * sway * idle - shift * 0.05 * idle
	# spine: hunched, rocking with the stride; rears back on the windup, lunges on the rake
	var hw := _howl
	var lean := -hunch - 0.12 * st + w * (hunch * 0.6 + 0.55) + ov * 0.14 - r * 0.65 + f * 0.45 + knock * 0.6 - slump * 0.5 - fold * 0.5 + hw * (hunch + 0.3) - gl * 0.16
	_torso.rotation.x = lean - _land * 0.25 + _air * 0.08 + sin(_t * 1.3) * 0.05 * sway * idle + _breath_pitch * idle
	_torso.rotation.y = -s * 0.2 * st + _flinch_side * f * 0.4 + weave * 0.22 * slump + sin(_t * 31.0) * 0.012 * ov
	_torso.rotation.z = -_turn * 0.05 + sin(_t * 0.7) * 0.05 * sway * idle + shift * 0.06 * idle + s * limp * 0.1 * st + sin(_t * 4.2 + _idle_phase + 0.9) * 0.2 * slump + sin(_t * 1.1) * 0.05 * gl
	_chest.scale = Vector3(1.0 + breathe * 0.045 * idle + w * 0.05, 1.0 + breathe * 0.055 * idle, 1.0 + breathe * 0.045 * idle)
	# head: jutting forward against the hunch, twitching; thrown back on a flinch, up on the windup
	var jut := hunch * head_jut
	_head.rotation.x = jut + 0.06 * st - breathe * 0.03 * idle + _twitch_at.x - w * 0.45 + r * 0.25 - f * 0.5 - knock * 0.55 + slump * 0.75 - hw * (jut + 0.75) + gl * 0.1
	_head.rotation.y = s * 0.12 * st + _twitch_at.y * idle + sin(_t * 0.45) * 0.15 * idle * sway
	_head.rotation.z = _twitch_at.x * 0.6 + sin(_t * 3.1) * 0.38 * slump
	# arms: carried forward and out, swinging loose; drawn high and back for the windup, then
	# raked down through the strike
	var reach := arm_reach * (1.0 - slump * 0.8)
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var ps := -s if i == 0 else s
		var swing := ps * 0.5 * st
		var raise := w * 2.55 + ov * 0.16
		var rake := -r * 0.95
		var x := reach + swing + raise + rake + (0.14 * sin(_t * 1.2 + float(i)) * sway * idle)
		x = lerpf(x, 0.08 + weave * sx * 0.18, slump * 0.9) - knock * 0.7 + fold * 0.6 + sin(fold * PI) * 0.9 - gl * 0.3
		if w > 0.85:
			x += sin(_t * 28.0 + float(i) * 1.7) * (0.05 + 0.06 * ov) * w            # the held tell trembles, harder as it tightens
		x = minf(x, 2.9)
		_sh[i].rotation.x = x
		_sh[i].rotation.y = sx * (w * 0.35 - r * 0.25)
		_sh[i].rotation.z = sx * (splay + w * 0.45 + _air * 0.35 + knock * 0.95 + slump * 0.1 + hw * 0.75 + sin(fold * PI) * 0.5) + sx * f * 0.3
		_sh[i].rotation.x -= hw * 0.5
		_el[i].rotation.x = 0.35 + crouch * 0.3 + w * 0.75 + r * 0.2 + maxf(0.0, -ps) * 0.4 * st - slump * 0.25 + knock * 0.4
		_hand[i].rotation.x = 0.2 + w * 0.5 - r * 0.5
