extends RefCounted
## The small motions that make an NPC read as alive, shared by the tavern dwarves (dwarf_npc.gd,
## bartender.gd) and Hearthward's people (villager.gd); no class_name:
##   blink()     lid angle for the lid bone: a quick close (70 ms), a slower open (130 ms), every
##               2-6 s, sometimes a double blink; more often while talking
##   breath()    0..1 breathing phase value (slower and deeper at rest, quicker after work)
##   sway()      weight shift: a slow side-to-side of the pelvis with a settle on each side
##   gaze()      head yaw/pitch toward a target with a lag, small saccades while it holds
##   talk()      a speaking rhythm: syllables grouped into words and phrases with pauses; gives the
##               jaw opening and a gesture "beat" (0..1) that peaks on stressed words, for nods/hands
## And the update-rate policy (`interval`): every frame within 4 m (conversation range), 30 Hz to 11 m
## (every frame while walking), 20 Hz to 20 m (30 while walking), 12 Hz to 35 m, 2 Hz off
## screen, frozen past FREEZE_R (the pose holds; the mesh is range-culled further out anyway).
## Load by path: const Life := preload("res://core/npc/npc_life.gd")

const FREEZE_R := 35.0

var rng := RandomNumberGenerator.new()
var t := 0.0
var _blink_at := 2.0
var _blink_t := -1.0
var _double := false
var _sway := 0.0
var _sway_to := 0.0
var _sway_t := 0.0
var _gaze := Vector2.ZERO
var _sacc := Vector2.ZERO
var _sacc_t := 0.0
var _word_t := 0.0
var _word_len := 0.3
var _pause := 0.0
var _stress := 0.0
var _beat := 0.0
var breath_rate := 1.0       ## 1 at rest; raise after exertion
var words := 0               ## counts spoken words: a voice (npc_voice.gd) babbles one per change
var word_syll := 2           ## syllables in the word just begun
var word_stress := 0.0       ## its stress, 0..1


func _init(seed_v := 0) -> void:
	rng.seed = seed_v
	t = rng.randf() * 10.0
	_blink_at = rng.randf_range(0.5, 4.0)


## Advance the clocks (call once per pose update with the elapsed time since the last one).
func step(dt: float, talking := false) -> void:
	t += dt
	# blink
	if _blink_t >= 0.0:
		_blink_t += dt
		if _blink_t > 0.2:
			_blink_t = -1.0
			if _double:
				_double = false
				_blink_at = t + 0.12
			else:
				_blink_at = t + rng.randf_range(1.6, 3.2) if talking else t + rng.randf_range(2.2, 6.0)
				_double = rng.randf() < 0.15
	elif t >= _blink_at:
		_blink_t = 0.0
	# weight shift: pick a side, ease over, hold
	_sway_t -= dt
	if _sway_t <= 0.0:
		_sway_t = rng.randf_range(3.0, 8.0)
		_sway_to = rng.randf_range(0.5, 1.0) * (-1.0 if _sway_to > 0.0 else 1.0)
	_sway = lerpf(_sway, _sway_to, 1.0 - exp(-dt * 1.55))
	# saccades: small jumps of the gaze while it holds a target
	_sacc_t -= dt
	if _sacc_t <= 0.0:
		_sacc_t = rng.randf_range(0.35, 1.35)
		_sacc = Vector2(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.04, 0.04))
	# speech: words of 2-4 syllables, short gaps between words, longer between phrases
	if talking:
		_word_t += dt
		if _pause > 0.0:
			_pause -= dt
		elif _word_t > _word_len:
			_word_t = 0.0
			_word_len = rng.randf_range(0.18, 0.5)
			_stress = 1.0 if rng.randf() < 0.3 else rng.randf_range(0.2, 0.6)
			words += 1
			word_syll = clampi(roundi(_word_len / 0.13), 1, 4)
			word_stress = _stress
			_pause = rng.randf_range(0.35, 0.8) if rng.randf() < 0.18 else rng.randf_range(0.03, 0.09)
	else:
		_pause = 0.0
		_word_t = 0.0
	_beat = lerpf(_beat, _stress if talking and _pause <= 0.0 else 0.0, 1.0 - exp(-dt * 6.0))


## Lid bone rotation (rad about X; 0 open, about -1 shut).
func blink() -> float:
	if _blink_t < 0.0:
		return 0.0
	var c := smoothstep(0.0, 0.07, _blink_t) * (1.0 - smoothstep(0.07, 0.2, _blink_t))
	return -1.02 * c


func breath() -> float:
	return sin(t * 1.55 * breath_rate) * 0.5 + 0.5


## Weight shift -1..1 (which hip carries the weight).
func sway() -> float:
	return _sway


## Ease the gaze toward `want` (yaw, pitch) with saccades on top; returns the head's yaw/pitch.
func gaze(want: Vector2, dt: float, speed := 3.0) -> Vector2:
	_gaze = _gaze.lerp(want, 1.0 - exp(-dt * speed))
	return _gaze + _sacc * 0.5


## Jaw opening (0..1) for speech at this moment.
func jaw() -> float:
	if _pause > 0.0:
		return 0.0
	var syl := absf(sin(_word_t / maxf(_word_len, 0.05) * PI * 2.5))
	return syl * (0.45 + 0.55 * _stress)


## Gesture beat 0..1: high on stressed words (nods, hands).
func beat() -> float:
	return _beat


## Seconds between pose updates for an NPC at `pos` seen from `cam` (0 = every frame,
## -1 = frozen). `moving` NPCs (walking) never freeze, they drop to 5 Hz.
static var every_frame := false     ## tools: pose every NPC every frame (zz/npc_perf --nolod)

## The Kindled Keg's walls (Tavern X0..X1, Z0..Z1): from outside them its patrons are hidden (the
## windows are lit glass from the street), so they pose at 3 Hz. From inside, the windows show the
## night (one-sided panes, r29): people outside still slow down, but anyone walking stays smooth
## enough to pass a window (12 Hz).
const KEG := Rect2(10.0, 25.6, 16.0, 9.2)

static func inside_keg(p: Vector3) -> bool:
	return KEG.grow(0.3).has_point(Vector2(p.x, p.z))


## Like interval(), plus the Keg's walls: `in_keg` = the NPC is inside the tavern.
static func interval_keg(cam: Camera3D, pos: Vector3, in_keg: bool, moving := false) -> float:
	var iv := interval(cam, pos, moving)
	if iv < 0.0 or cam == null or every_frame:
		return iv
	if inside_keg(cam.global_position) != in_keg and cam.global_position.distance_to(pos) > 2.5:
		return maxf(iv, 1.0 / 12.0 if moving and not in_keg else 0.33)
	return iv


static func interval(cam: Camera3D, pos: Vector3, moving := false) -> float:
	if cam == null or every_frame:
		return 0.0
	var d := cam.global_position.distance_to(pos)
	if d > FREEZE_R:
		return 0.2 if moving else -1.0
	if d > 3.0 and not cam.is_position_in_frustum(pos + Vector3.UP):
		return 0.5
	if d < 4.0:
		return 0.0
	if d < 11.0:
		# a walker this close poses every rendered frame: at 120-144 Hz a 60 Hz stride steps visibly
		return 0.0 if moving else 1.0 / 30.0
	if d < 20.0:
		return 1.0 / 30.0 if moving else 1.0 / 20.0       # (Luke, 9 Nov: every frame to 20 m cost the frame)
	return 1.0 / 12.0


## Legs and pelvis for a walk at gait phase `p` (0..1 a stride; the right heel strikes at 0), blended by `amt`,
## on any DwarfRig-shaped rig (bones 11-14 thighs/shins). Solved, not tuned: each ankle is given a PATH and
## the thigh and knee are found by two-bone IK in the leg's plane. Stance is 60 % of the cycle: the planted
## ankle sits still on the floor while the body goes over it, so it travels back under the hip at exactly the
## body's speed (a stride of 3.33 Z, Z = half the stance's sweep = the leg's length times sin(swing)); the swing
## lifts it on a Hermite that leaves and arrives at the stance's own backward speed, so a sole lands at rest
## relative to the GROUND, whatever the leg's proportions (the bone-angle gait it replaces crept 13-54 cm a
## metre on the old and the long-skirted). The pelvis drops to whichever leg is reaching furthest (smooth
## minimum), which is the bob: lowest in double support, highest over the planted foot.
## swing (rad): the stance sweep; knee: the swing's lift (0.95 = a 9 cm clearance on a 0.69 m leg); bob: unused
## (the pelvis's motion now follows from the legs). Returns the pelvis drop (m, <= 0).
static func leg_len(rig: DwarfRig) -> float:
	var hip: Vector3 = rig.rests[11]
	var kn: Vector3 = rig.rests[12]
	var ank: Vector3 = rig.ankle(1.0)
	return hip.distance_to(kn) + kn.distance_to(ank)


static func walk_legs(rig: DwarfRig, p: float, amt: float, swing: float, knee: float, _bob: float) -> float:
	if amt <= 0.001:
		return 0.0
	var hip: Vector3 = rig.rests[11]
	var kn: Vector3 = rig.rests[12]
	var ank: Vector3 = rig.ankle(1.0)
	var a := Vector2(kn.y - hip.y, kn.z - hip.z)
	var b := Vector2(ank.y - kn.y, ank.z - kn.z)
	var l1 := a.length()
	var l2 := b.length()
	var lg := l1 + l2
	var z0 := ank.z - hip.z                         # the ankle's rest offset from the hip, fore-aft (-z is forward)
	var d0 := hip.y - ank.y                         # hip height above the ankle plane at rest
	var zz := lg * sin(swing) * 0.97 * amt          # half the stance's sweep
	var lift_h := 0.105 * knee * lg / 0.69
	var reach := lerpf(d0, 0.99 * lg, amt)
	var zf: Array[float] = [0.0, 0.0]
	var lf: Array[float] = [0.0, 0.0]
	for side in 2:
		var c := fposmod(p + 0.5 * float(side), 1.0)
		if c < 0.6:
			zf[side] = zz * (1.0 - 2.0 * c / 0.6)
		else:
			# swing: a Hermite from the stance's end to its start, at the stance's own (backward) speed at both ends
			var u := (c - 0.6) / 0.4
			var u2 := u * u
			var u3 := u2 * u
			var m := -3.3333 * zz * 0.4
			zf[side] = (2.0 * u3 - 3.0 * u2 + 1.0) * -zz + (u3 - 2.0 * u2 + u) * m + (-2.0 * u3 + 3.0 * u2) * zz + (u3 - u2) * m
			lf[side] = lift_h * pow(sin(PI * u), 0.7)
	# the pelvis: the lowest height any leg can reach to its own foot (a smooth minimum, 5 mm round)
	var kk := 0.005
	var e := 0.0
	for side in 2:
		var w := z0 - zf[side]
		var hs := lf[side] + sqrt(maxf(reach * reach - w * w, 0.01))
		e += exp(-hs / kk)
	var h := minf(-kk * log(e), d0)
	for side in 2:
		var dy := lf[side] - h
		var dz := z0 - zf[side]
		var dist := clampf(sqrt(dy * dy + dz * dz), absf(l1 - l2) + 0.02, lg * 0.999)
		var cd := clampf((dist * dist - l1 * l1 - l2 * l2) / (2.0 * l1 * l2), -1.0, 1.0)
		var d_rest := angle_difference(atan2(a.y, a.x), atan2(b.y, b.x))
		var aa := atan2(a.y, a.x)
		var flex := maxf(d_rest + acos(cd), 0.0)
		var del := d_rest - flex
		var f0 := Vector2(cos(aa), sin(aa)) * l1 + Vector2(cos(aa + del), sin(aa + del)) * l2
		var th := atan2(dz, dy) - atan2(f0.y, f0.x)
		var bt := 11 if side == 0 else 13
		rig.q(bt, Quaternion(Vector3.RIGHT, th))
		rig.q(bt + 1, Quaternion(Vector3.RIGHT, -flex))
	return h - d0


## Turning on the spot, on steps. A body that yaws over planted feet drags them round (30 cm of skate for a half turn), so the
## feet are kept where they stand in the WORLD: each one's fore-aft offset in the body's frame moves with the yaw (the right foot
## goes back as the body turns left, the left forward), and when one has gone 11 cm off, it is lifted and set down on the
## other side of the hip: a shuffle step, on the same two-bone IK as the walk. At rest the feet are brought back under the body
## the same way. Call once per pose while standing (walk blend ~0), `yaw` = the body's world yaw; returns the pelvis drop (<= 0),
## or INF when the feet are home and not turning (the caller poses its own standing legs).
var _ty := INF                          ## the yaw at the last call
var _tf: Array[float] = [0.0, 0.0]      ## each planted foot's offset ahead of the hip (m): right, left
var _tsw: Array[float] = [-1.0, -1.0]   ## a foot's swing progress 0..1, -1 = planted
var _tfrom: Array[float] = [0.0, 0.0]
var _tto: Array[float] = [0.0, 0.0]
var _tquiet := 0.0
var _tgoal: Array[float] = [INF, INF]   ## offsets the feet are to be stepped to (the gait's first stance), INF = none
var _tready := false
const TURN_STEP := 0.11                 ## m a planted foot may be carried off before it steps
const TURN_SWING := 0.24                ## s a shuffle step takes


func turn_reset(yaw: float) -> void:
	_ty = yaw
	_tf = [0.0, 0.0]
	_tsw = [-1.0, -1.0]
	_tquiet = 0.0


## The walk ends (or begins) with its feet where the gait had them: take those offsets as the turn's planted feet and step them
## home (no snap of the sole, no drag as the stride's amplitude fades). `p` the gait phase, `swing` its swing angle.
func turn_adopt(rig: DwarfRig, p: float, swing: float, yaw: float) -> void:
	var zz := leg_len(rig) * sin(swing) * 0.97
	for side in 2:
		var c := fposmod(p + 0.5 * float(side), 1.0)
		var z := 0.0
		if c < 0.6:
			z = zz * (1.0 - 2.0 * c / 0.6)
		else:
			var u := (c - 0.6) / 0.4
			var u2 := u * u
			var u3 := u2 * u
			var m := -3.3333 * zz * 0.4
			z = (2.0 * u3 - 3.0 * u2 + 1.0) * -zz + (u3 - 2.0 * u2 + u) * m + (-2.0 * u3 + 3.0 * u2) * zz + (u3 - u2) * m
		_tf[side] = z
		_tsw[side] = -1.0
	_ty = yaw
	_tquiet = 1.0


## True when both planted feet are under the hips and none is stepping (the body may set off).
## Step the feet out to where the gait at phase `p0` has them (one at a time, standing); turn_ready() when both are there.
func turn_walkup(rig: DwarfRig, p0: float, swing: float) -> void:
	var zz := leg_len(rig) * sin(swing) * 0.97
	for side in 2:
		var c := fposmod(p0 + 0.5 * float(side), 1.0)
		_tgoal[side] = zz * (1.0 - 2.0 * c / 0.6) if c < 0.6 else 0.0
	_tready = false


func turn_ready() -> bool:
	return _tready


func turn_settle() -> void:
	_tquiet = maxf(_tquiet, 1.0)


func turn_home() -> bool:
	return maxf(absf(_tf[0]), absf(_tf[1])) < 0.02 and _tsw[0] < 0.0 and _tsw[1] < 0.0


func turn_legs(rig: DwarfRig, yaw: float, dt: float) -> float:
	if _ty == INF:
		_ty = yaw
	var dth := angle_difference(_ty, yaw)
	_ty = yaw
	var hip: Vector3 = rig.rests[11]
	var r := absf(hip.x)
	var moving := absf(dth) > 0.0008
	_tquiet = 0.0 if moving else _tquiet + dt
	for i in 2:
		if _tsw[i] < 0.0:
			_tf[i] += (-1.0 if i == 0 else 1.0) * r * dth        # planted: fixed in the world, so it slides round the body's frame
	var swinging := _tsw[0] >= 0.0 or _tsw[1] >= 0.0
	if _tgoal[0] != INF or _tgoal[1] != INF:
		if not swinging:
			var pick := -1
			var far := 0.004
			for i in 2:
				if _tgoal[i] != INF and absf(_tf[i] - _tgoal[i]) > far:
					far = absf(_tf[i] - _tgoal[i])
					pick = i
			if pick >= 0:
				_tsw[pick] = 0.0
				_tfrom[pick] = _tf[pick]
				_tto[pick] = _tgoal[pick]
			else:
				_tgoal = [INF, INF]
				_tready = true
	elif not swinging:
		var worst := 0 if absf(_tf[0]) >= absf(_tf[1]) else 1
		if absf(_tf[worst]) > TURN_STEP:
			_tsw[worst] = 0.0
			_tfrom[worst] = _tf[worst]
			_tto[worst] = -signf(_tf[worst]) * TURN_STEP * 0.6
		elif _tquiet > 0.5 and maxf(absf(_tf[0]), absf(_tf[1])) > 0.015:
			_tsw[worst] = 0.0
			_tfrom[worst] = _tf[worst]
			_tto[worst] = 0.0
	var lift := [0.0, 0.0]
	for i in 2:
		if _tsw[i] >= 0.0:
			_tsw[i] += dt / TURN_SWING
			var u := minf(_tsw[i], 1.0)
			_tf[i] = lerpf(_tfrom[i], _tto[i], u * u * (3.0 - 2.0 * u))
			lift[i] = 0.035 * sin(PI * u)
			if _tsw[i] >= 1.0:
				_tsw[i] = -1.0
	if maxf(absf(_tf[0]), absf(_tf[1])) < 0.004 and not (_tsw[0] >= 0.0 or _tsw[1] >= 0.0) and not moving:
		_tf = [0.0, 0.0]
		return INF
	var kn: Vector3 = rig.rests[12]
	var ank: Vector3 = rig.ankle(1.0)
	var av := Vector2(kn.y - hip.y, kn.z - hip.z)
	var bv := Vector2(ank.y - kn.y, ank.z - kn.z)
	var l1 := av.length()
	var l2 := bv.length()
	var z0 := ank.z - hip.z
	var d0 := hip.y - ank.y
	var lgt := l1 + l2
	var h := d0
	for side in 2:
		var wz: float = z0 - _tf[side]
		h = minf(h, lift[side] + sqrt(maxf(pow(0.99 * lgt, 2.0) - wz * wz, 0.01)))
	for side in 2:
		var dy: float = lift[side] - h
		var dz: float = z0 - _tf[side]
		var dist := clampf(sqrt(dy * dy + dz * dz), absf(l1 - l2) + 0.02, (l1 + l2) * 0.999)
		var cd := clampf((dist * dist - l1 * l1 - l2 * l2) / (2.0 * l1 * l2), -1.0, 1.0)
		var d_rest := angle_difference(atan2(av.y, av.x), atan2(bv.y, bv.x))
		var aa := atan2(av.y, av.x)
		var flex := maxf(d_rest + acos(cd), 0.0)
		var f0 := Vector2(cos(aa), sin(aa)) * l1 + Vector2(cos(aa + d_rest - flex), sin(aa + d_rest - flex)) * l2
		var th := atan2(dz, dy) - atan2(f0.y, f0.x)
		var bt := 11 if side == 0 else 13
		rig.q(bt, Quaternion(Vector3.RIGHT, th))
		rig.q(bt + 1, Quaternion(Vector3.RIGHT, -flex))
	return h - d0


## Pose blending between low-rate updates (r30). Past 11 m a villager poses at 30/20/12 Hz (see
## interval) while its root moves every frame, so its legs stepped at 12 Hz. Now each new pose is
## eased in over the interval until the next one, from what was on screen: one update behind, like
## the herds (life_beasts.gd), and continuous at any refresh rate. Usage, round the pose call:
##   life.blend_from(rig) ; <pose and rig.apply()> ; life.blend_to(rig, iv)   -- at a pose update
##   life.blend_step(rig, acc)                                                -- every other frame
## A pose every frame (iv <= 1/50) or a slow one (off screen, iv >= 0.3) is shown as posed.
var _bf: Array[Quaternion] = []      ## on screen when the update came (from)
var _bt: Array[Quaternion] = []      ## the update's pose (to)
var _bo := Vector2.ZERO              ## the rig's height offset: from, to
var _bspan := 0.0                    ## seconds to ease across; 0 = nothing to blend


func blend_from(rig: DwarfRig) -> void:
	var sk := rig.skeleton
	var n := DwarfRig.BONES.size()
	if _bf.size() != n:
		_bf.resize(n)
		_bt.resize(n)
	for i in n:
		_bf[i] = sk.get_bone_pose_rotation(i)
	_bo.x = (rig as Node3D).position.y


func blend_to(rig: DwarfRig, span: float) -> void:
	_bspan = 0.0
	if span <= 0.02 or span >= 0.3 or _bf.size() != DwarfRig.BONES.size():
		return
	var sk := rig.skeleton
	for i in _bf.size():
		_bt[i] = sk.get_bone_pose_rotation(i)
		sk.set_bone_pose_rotation(i, _bf[i])
	_bo.y = (rig as Node3D).position.y
	(rig as Node3D).position.y = _bo.x
	_bspan = span


func blend_step(rig: DwarfRig, acc: float) -> void:
	if _bspan <= 0.0:
		return
	var al := acc / _bspan
	if al >= 1.0:
		al = 1.0
		_bspan = 0.0                    # arrived: hold the pose until the next update
	# smoothstep ease so low-rate NPC poses do not click between updates
	al = al * al * (3.0 - 2.0 * al)
	var sk := rig.skeleton
	for i in _bf.size():
		sk.set_bone_pose_rotation(i, _bf[i].slerp(_bt[i], al))
	(rig as Node3D).position.y = lerpf(_bo.x, _bo.y, al)


## Metres covered by one full stride (two steps) for a leg of length `leg` swinging `swing` rad.
static func stride_len(leg: float, swing: float) -> float:
	return 3.33 * leg * sin(swing) * 0.97       # the stance (0.6 of a cycle) covers the sweep of one leg, 2 leg sin(swing)


## Metres of ground per full cycle for this rig at full amplitude (world scale): twice the stance's sweep over
## its 0.6 of the cycle, from the rig's own bone lengths (walk_legs plants the ankle, so this is exact).
static func calib_stride(rig: DwarfRig, swing: float, _knee := 0.0, _bob := 0.0) -> float:
	return 3.3333 * leg_len(rig) * sin(swing) * 0.97 * (rig as Node3D).scale.x


## A dialogue portrait (the box's live bust): breathing, blinks, small slow head moves with saccades,
## the jaw by syllable and nods on stressed words while the line types. Call after the caller's own
## reset/arm posing and before apply(). `jaw_amp`: 0.085 for dwarves (the beard hides the mouth),
## 0.15 for villagers.
func portrait(rig: DwarfRig, dt: float, typing: bool, jaw_amp := 0.12) -> void:
	step(dt, typing)
	var br := breath()
	rig.q(DwarfRig.B_CHEST, Quaternion(Vector3.RIGHT, (br - 0.5) * 0.03))
	var g := gaze(Vector2(sin(t * 0.37) * 0.12, 0.02 + sin(t * 0.53) * 0.03), dt, 2.0)
	rig.q(DwarfRig.B_HEAD, Quaternion(Vector3.UP, g.x) * Quaternion(Vector3.RIGHT, g.y + 0.07 * beat()))
	rig.q(DwarfRig.B_JAW, Quaternion(Vector3.RIGHT, -jaw_amp * jaw() if typing else 0.0))
	rig.q(DwarfRig.B_LID, Quaternion(Vector3.RIGHT, blink()))
