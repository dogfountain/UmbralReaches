extends RefCounted
## The folk's poses (folk_actor.gd calls `pose` at the villagers' distance rate): sweeping, carrying a sack and a bucket,
## fiddling, dancing, running and being caught, counting with the eyes covered, hiding, mourning, mending a net,
## talking seated, the watchman's raised lantern, a look at the eclipse, and standing about with the villagers' own
## idles (villager_idle.gd and villager_fidgets.gd). Every pose is a pure function of (act, time) on the 16 bones of the
## villager rig through its two-bone arm IK, so the actor's crossfade and low-rate easing (npc_life.gd) make every change
## and every distance continuous. A wave and a nod are overlays on any act. Static; `a` is the FolkActor.
const Life := preload("res://core/npc/npc_life.gd")
const Idle := preload("res://core/life/village/villager_idle.gd")

const SCALE := 1.1                         ## VillagerRig.SCALE
const B_SPINE := 1
const B_CHEST := 2
const B_HEAD := 3
const B_JAW := 4
const B_ARM_R := 5
const B_FORE_R := 6
const B_ARM_L := 8
const B_FORE_L := 9
const B_THIGH_R := 11
const B_SHIN_R := 12
const B_THIGH_L := 13
const B_SHIN_L := 14
const B_LID := 15
const POLE_R := Vector3(0.9, -0.5, 0.3)
const POLE_L := Vector3(-0.9, -0.5, 0.3)


static func pose(a: Variant, dt: float) -> void:
	var r: Variant = a.rig
	var k: float = r.k
	var life: Variant = a.life
	var act: String = a.act
	r.reset()
	var talking: bool = act == "sit_talk" and float(a.data.get("talk", 0.0)) > 0.5
	life.step(dt, talking)
	var old := String(a.look.get("age", "")) == "old"
	var stoop := 0.16 if old else 0.0
	var breath: float = (life.breath() - 0.5) * 0.026
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -stoop * 0.4))
	r.q(B_CHEST, Quaternion(Vector3.RIGHT, -stoop * 0.6 + breath))
	var head := stoop * 0.7
	var off := 0.0
	var free_r := String(a.look.get("r", "")) == ""
	var free_l := String(a.look.get("l", "")) == ""
	a.shift = Vector2.ZERO
	a._shift_x = 0.0
	a.data["head"] = 0.0
	match act:
		"sweep":
			off = _sweep(a, r, k)
			head += 0.4
		"sack":
			off = _carry(a, r, k, true)
		"bucket":
			off = _carry(a, r, k, false)
		"fiddle":
			off = _fiddle(a, r, k)
		"dance":
			off = _dance(a, r, k)
		"run":
			off = _run(a, r, k)
		"caught":
			off = _cheer(a, r, k)
		"count":
			off = _count(a, r, k)
			head += 0.28
		"hide":
			off = _hide(a, r, k)
		"mourn":
			off = _mourn(a, r, k)
			head += 0.55
		"mend":
			off = _mend(a, r, k)
			head += 0.5
		"sit_talk":
			off = _sit_talk(a, r, k, life)
		"lantern":
			off = _lantern_raise(a, r, k)
		"eclipse":
			off = _eclipse(a, r, k)
			head -= 0.7
		"walk":
			off = _walk(a, r, k)
		_:
			off = _stand(a, r, k, dt, free_r, free_l, breath)
	head += float(a.data.get("head", 0.0))
	# the overlays: a wave at the wanderer, a nod to someone passing
	var wv := 0.0
	if float(a.wave_t) > 0.0:
		var total := 2.6
		wv = smoothstep(0.0, 0.45, float(a.wave_t)) * smoothstep(0.0, 0.45, total - float(a.wave_t))
		_wave(a, r, k, wv, free_r, free_l)
	if float(a.nod_t) > 0.0:
		head += 0.28 * sin(PI * (1.0 - float(a.nod_t) / 1.1)) * (1.0 + sin(float(a._t) * 20.0) * 0.1)
	# the head: toward what draws the eye, jaw while talking, lids
	var lk: Vector2 = a.gaze(dt)
	var chest_q: Quaternion = r.get_q(B_CHEST)
	r.q(B_CHEST, chest_q * Quaternion(Vector3.UP, lk.x * 0.25))
	var hq := Quaternion(Vector3.UP, lk.x * 0.75) * Quaternion(Vector3.RIGHT, -(head + lk.y))
	if act == "fiddle":
		hq = hq * Quaternion(Vector3.BACK, 0.22 * float(a.phase))
	r.q(B_HEAD, hq)
	if talking:
		r.q(B_JAW, Quaternion(Vector3.RIGHT, -0.15 * life.jaw()))
	r.q(B_LID, Quaternion(Vector3.RIGHT, life.blink()))
	(a.rig as Node3D).position = Vector3(float(a.shift.x) + float(a._shift_x), off, float(a.shift.y))
	r.apply()
	r.update_glow()


# --- the body under every act ---------------------------------------------------------------------

## Walking legs at the actor's gait (or standing with the weight on one leg, turning on the spot in steps).
static func _legs(a: Variant, r: Variant, k: float, dt: float) -> float:
	var life: Variant = a.life
	var amt: float = a.walk_amt
	var sw: float = life.sway()
	if amt > 0.001:
		life.turn_reset((a as Node3D).global_rotation.y)
	if amt <= 0.001:
		var td: float = life.turn_legs(r, (a as Node3D).global_rotation.y, dt)
		if td != INF:
			return td
		r.q(B_THIGH_R, Quaternion(Vector3.BACK, sw * 0.012) * Quaternion(Vector3.RIGHT, 0.04 * maxf(sw, 0.0)))
		r.q(B_THIGH_L, Quaternion(Vector3.BACK, sw * 0.012) * Quaternion(Vector3.RIGHT, 0.04 * maxf(-sw, 0.0)))
		r.q(B_SHIN_R, Quaternion(Vector3.RIGHT, -0.03 - 0.1 * maxf(sw, 0.0)))
		r.q(B_SHIN_L, Quaternion(Vector3.RIGHT, -0.03 - 0.1 * maxf(-sw, 0.0)))
		return -0.006 * absf(sw) * k
	var g: Array = a.gait_g
	var drop: float = Life.walk_legs(r, float(a.gait), amt, float(g[0]), float(g[1]), float(g[2]) * k)
	var c := cos(TAU * float(a.gait))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.UP, -0.06 * c * amt) * Quaternion(Vector3.FORWARD, 0.035 * c * amt))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.1 * c * amt))
	return drop


## Arm swing with the stride for a hand that is free (the stride's own swing, a settled fold at rest).
static func _swing(a: Variant, r: Variant, free_r: bool, free_l: bool, scale := 1.0) -> void:
	var g: Array = a.gait_g
	var sr := cos(TAU * float(a.gait)) * float(a.walk_amt) * float(g[3]) / 0.32 * scale
	var idle := sin(float(a._t) * 0.9) * 0.03
	if free_r:
		r.q(B_ARM_R, Quaternion(Vector3.RIGHT, -0.32 * sr + idle + 0.04) * Quaternion(Vector3.BACK, 0.1))
		r.q(B_FORE_R, Quaternion(Vector3.RIGHT, 0.22 + 0.15 * maxf(0.0, -sr)))
	if free_l:
		r.q(B_ARM_L, Quaternion(Vector3.RIGHT, 0.32 * sr - idle + 0.04) * Quaternion(Vector3.BACK, -0.1))
		r.q(B_FORE_L, Quaternion(Vector3.RIGHT, 0.22 + 0.15 * maxf(0.0, sr)))


## Bend both knees by `amt`: the drop that keeps the feet on the ground (model units, shown at SCALE).
static func _crouch(r: Variant, amt: float) -> float:
	for bt: int in [B_THIGH_R, B_THIGH_L]:
		r.q(bt, (r.get_q(bt) as Quaternion) * Quaternion(Vector3.RIGHT, amt))
		r.q(bt + 1, (r.get_q(bt + 1) as Quaternion) * Quaternion(Vector3.RIGHT, -2.0 * amt))
	return -Life.leg_len(r) * (1.0 - cos(amt)) * SCALE


static func _kneel(r: Variant, k: float, w := 1.0) -> float:
	var rests: Array = r.rests
	var knee_y: float = (rests[B_SHIN_R] as Vector3).y
	for bt: int in [B_THIGH_R, B_THIGH_L]:
		r.q(bt, Quaternion(Vector3.RIGHT, 0.1 * w))
		r.q(bt + 1, Quaternion(Vector3.RIGHT, -1.52 * w))
	return -(knee_y - 0.05 * k) * SCALE * w


## Seated on something `seat` metres high, the thighs level and the shins hanging.
static func _sit(r: Variant, seat: float) -> float:
	var rests: Array = r.rests
	var hip_y: float = (rests[B_THIGH_R] as Vector3).y
	for bt: int in [B_THIGH_R, B_THIGH_L]:
		r.q(bt, Quaternion(Vector3.RIGHT, 1.5))
		r.q(bt + 1, Quaternion(Vector3.RIGHT, -1.45))
	return (seat + 0.07) - hip_y * SCALE


# --- the acts -------------------------------------------------------------------------------------

static func _stand(a: Variant, r: Variant, k: float, dt: float, free_r: bool, free_l: bool, breath: float) -> float:
	var off := _legs(a, r, k, dt)
	_swing(a, r, free_r, free_l)
	_tool_hold(a, r, k, free_r, free_l)
	if float(a.walk_amt) < 0.1:
		a.data["head"] = Idle.stand(a, k, free_r, free_l, breath)
	return off


## The tool in each hand carried the way it is carried (the lantern at the hip, a staff planted).
static func _tool_hold(a: Variant, r: Variant, k: float, _free_r: bool, _free_l: bool) -> void:
	var g: Array = a.gait_g
	var sr := cos(TAU * float(a.gait)) * float(a.walk_amt) * float(g[3]) / 0.32
	match String(a.look.get("l", "")):
		"lantern":
			r.hold(1, Vector3(-0.24, 0.8 + 0.02 * absf(sr), -0.14 + 0.05 * sr) * k, Vector3(0, 0, -1), Vector3(0, -1, 0))
		"torch":
			r.hold(1, Vector3(-0.26, 1.02, -0.2) * k, Vector3(0.0, 1.0, -0.3), Vector3(0, 0, -1))
	match String(a.look.get("r", "")):
		"staff", "crook":
			var plant := 0.06 * sr
			r.hold(0, Vector3(0.27, 1.0, -0.2 - plant) * k, Vector3(0.04, 1.0, 0.22 - plant), Vector3(0, 0, -1))
		"broom":
			r.hold(0, Vector3(0.24, 1.0, -0.12) * k, Vector3(0.1, 0.9, 0.3), Vector3(0, 0, 1))
		"bow":
			r.hold(0, Vector3(0.24, 0.9, -0.1) * k, Vector3(0.0, -1.0, -0.2), Vector3(0, 0, 1))


static func _walk(a: Variant, r: Variant, k: float) -> float:
	var off := _legs(a, r, k, 0.016)
	_swing(a, r, String(a.look.get("r", "")) == "", String(a.look.get("l", "")) == "")
	_tool_hold(a, r, k, true, true)
	return off


static func _sweep(a: Variant, r: Variant, k: float) -> float:
	var t: float = a._t
	var s := sin(t * 2.3)
	var off := _legs(a, r, k, 0.016)
	# the stroke: the head of the broom drawn across in front, the whole back bending into it, one foot forward
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.28 - 0.04 * s) * Quaternion(Vector3.UP, 0.16 * s))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.2 * s))
	r.q(B_THIGH_L, (r.get_q(B_THIGH_L) as Quaternion) * Quaternion(Vector3.RIGHT, 0.2))
	r.q(B_SHIN_L, (r.get_q(B_SHIN_L) as Quaternion) * Quaternion(Vector3.RIGHT, -0.12))
	var g := Vector3(0.12 + 0.16 * s, 0.98, -0.3) * k
	var d := Vector3(0.16 * s, -0.62, -0.77).normalized()
	r.hold(0, g, d, Vector3(0, 0, 1), POLE_R)
	r.arm_to("l", g + d * 0.5 * k + Vector3(-0.14, 0.0, 0.04) * k, POLE_L, null)
	return off


## A sack (right hand) or a bucket (right hand, the left arm out to balance) carried on a walk.
static func _carry(a: Variant, r: Variant, k: float, sack: bool) -> float:
	var off := _legs(a, r, k, 0.016)
	var c := cos(TAU * float(a.gait)) * float(a.walk_amt)
	var heavy := 1.0 if sack else 0.6
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.FORWARD, -0.07 * heavy) * Quaternion(Vector3.RIGHT, -0.06 * heavy))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, 0.05 * heavy))
	var sway := 0.04 * c
	r.hold(0, Vector3(0.25 + sway, 0.9 + 0.01 * absf(c), -0.1) * k, Vector3(0, 0, -1), Vector3(0, -1, 0))
	if sack:
		r.arm_to("l", Vector3(-0.2 - 0.02 * c, 0.93, -0.04) * k, POLE_L, null)
	else:
		r.arm_to("l", Vector3(-0.36 - 0.03 * c, 0.9, -0.02) * k, Vector3(-1.0, -0.2, 0.2), null)
	a.shift = Vector2(-0.02 * heavy, 0.0)
	return off


static func _fiddle(a: Variant, r: Variant, k: float) -> float:
	var t: float = a._t
	var amp: float = a.phase                    # 0 resting between tunes .. 1 playing
	var s := sin(t * 2.7) * 0.8 + sin(t * 5.4) * 0.12
	var off := _legs(a, r, k, 0.016)
	var tap := pow(maxf(0.0, sin(t * 5.4)), 3.0) * amp
	r.q(B_THIGH_R, (r.get_q(B_THIGH_R) as Quaternion) * Quaternion(Vector3.RIGHT, 0.28 * tap))
	r.q(B_SHIN_R, (r.get_q(B_SHIN_R) as Quaternion) * Quaternion(Vector3.RIGHT, -0.4 * tap))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.FORWARD, 0.06 * s * amp) * Quaternion(Vector3.UP, -0.1))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, -0.15 + 0.05 * s * amp))
	# the fiddle up under the chin in the left hand, the bow across the strings
	r.hold(1, Vector3(-0.1, 1.36, -0.3) * k, Vector3(0.35, 0.18, -1.0), Vector3(0, -1, 0), Vector3(-1.0, 0.1, 0.3))
	var rest_bow := Vector3(0.25, 0.9, -0.1)
	var play_bow := Vector3(0.2 + 0.14 * s, 1.2 + 0.01 * sin(t * 5.4), -0.44)
	var g := rest_bow.lerp(play_bow, amp) * k
	r.hold(0, g, Vector3(-1.0, 0.04 * s * amp, -0.14).slerp(Vector3(0, -1, -0.2), 1.0 - amp), Vector3(0, 0, 1), Vector3(0.9, 0.2, 0.2))
	return off


static func _dance(a: Variant, r: Variant, k: float) -> float:
	var t: float = a._t
	var dg := fposmod(t * 0.95, 1.0)
	var off: float = Life.walk_legs(r, dg, 0.6, 0.34, 0.9, 0.02 * k)
	var sw := sin(t * TAU * 0.95)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.FORWARD, 0.08 * sw) * Quaternion(Vector3.UP, -0.08 * sw))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.18 * sw))
	r.arm_to("r", Vector3(0.38, 1.34 + 0.12 * sw, -0.12) * k, Vector3(0.9, 0.1, 0.1), null)
	r.arm_to("l", Vector3(-0.38, 1.34 - 0.12 * sw, -0.12) * k, Vector3(-0.9, 0.1, 0.1), null)
	a.shift = Vector2(0.04 * sw, 0.0)
	return off + 0.012 * sin(t * TAU * 1.9)


static func _run(a: Variant, r: Variant, k: float) -> float:
	var off := _legs(a, r, k, 0.016)
	_swing(a, r, true, true, 1.6)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.14 * float(a.walk_amt)))
	return off


static func _cheer(a: Variant, r: Variant, k: float) -> float:
	var t: float = a._t
	var hop := absf(sin(float(a.act_t) * 7.0)) * 0.07 * (1.0 - smoothstep(0.8, 1.4, float(a.act_t)))
	var off := _legs(a, r, k, 0.016)
	r.arm_to("r", Vector3(0.28, 1.78 + 0.06 * sin(t * 12.0), -0.04) * k, Vector3(0.9, 0.4, 0.0), null)
	r.arm_to("l", Vector3(-0.28, 1.78 + 0.06 * sin(t * 12.0 + 1.0), -0.04) * k, Vector3(-0.9, 0.4, 0.0), null)
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.RIGHT, 0.12))
	return off + hop


## Counting with the hands over the eyes, the face to the wall of a brazier.
static func _count(a: Variant, r: Variant, k: float) -> float:
	var off := _legs(a, r, k, 0.016)
	var t: float = a._t
	r.arm_to("r", Vector3(0.045, 1.32 + 0.004 * sin(t * 2.0), -0.2) * k, Vector3(0.9, -0.2, 0.3), null)
	r.arm_to("l", Vector3(-0.045, 1.32, -0.2) * k, Vector3(-0.9, -0.2, 0.3), null)
	var tick := pow(maxf(0.0, sin(t * 3.1)), 4.0)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.06 - 0.03 * tick))
	return off


## Crouched small behind something, arms round the knees, peeking out now and then.
static func _hide(a: Variant, r: Variant, k: float) -> float:
	var t: float = a._t
	var w := smoothstep(0.0, 0.5, float(a.act_t))
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.5 * w))
	r.q(B_CHEST, Quaternion(Vector3.RIGHT, -0.15 * w))
	var off := _crouch(r, 1.05 * w)
	var kn := Vector3(0, 0.45, -0.3)
	r.arm_to("r", Vector3(0.12, lerpf(0.86, kn.y, w), lerpf(-0.02, kn.z, w)) * k, POLE_R, null)
	r.arm_to("l", Vector3(-0.12, lerpf(0.86, kn.y, w), lerpf(-0.02, kn.z, w)) * k, POLE_L, null)
	var peek := smoothstep(0.82, 0.96, sin(t * 0.55 + float(hash(a.id) % 7)))
	a.data["head"] = -0.3 * peek
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, 0.25 * peek))
	return off


static func _mourn(a: Variant, r: Variant, k: float) -> float:
	var t: float = a._t
	var w := smoothstep(0.0, 1.2, float(a.act_t))
	var off := _kneel(r, k, w)
	var sob := sin(t * 8.5) * 0.012 * (0.4 + 0.6 * smoothstep(0.7, 1.0, sin(t * 0.21)))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.22 * w + sob))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.RIGHT, -0.12 * w + sob))
	var face := smoothstep(0.5, 0.75, sin(t * 0.13 + 1.0))       # now and then the hands go up to the face
	var lap := Vector3(0.1, 0.55, -0.3)
	var up := Vector3(0.04, 1.2, -0.2)
	r.arm_to("r", lap.lerp(up, face) * k, POLE_R, null)
	r.arm_to("l", Vector3(-lap.x, lap.y, lap.z).lerp(Vector3(-up.x, up.y, up.z), face) * k, POLE_L, null)
	return off


## Mending a net on the knees: the hands drawing the cord through, the head down.
static func _mend(a: Variant, r: Variant, k: float) -> float:
	var t: float = a._t
	var w := smoothstep(0.0, 1.0, float(a.act_t))
	var off := _kneel(r, k, w)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.2 * w))
	var p := sin(t * 4.1)
	r.arm_to("r", Vector3(0.09 + 0.07 * p, 0.55, -0.27) * k, POLE_R, null)
	r.arm_to("l", Vector3(-0.09 + 0.07 * sin(t * 4.1 + 1.6), 0.55 + 0.03 * sin(t * 2.0), -0.3) * k, POLE_L, null)
	return off


## Seated (on a log) in talk: the speaker's hands tell it, the listener's rest on the knees and nod.
static func _sit_talk(a: Variant, r: Variant, k: float, life: Variant) -> float:
	var t: float = a._t
	var seat: float = float(a.data.get("seat", 0.45))
	var off := _sit(r, seat)
	var talk: float = float(a.data.get("talk", 0.0))
	var bt: float = life.beat() * talk
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.06 - 0.05 * bt))
	var rests: Array = r.rests
	var hip_y: float = (rests[B_THIGH_R] as Vector3).y
	var kn := Vector3(0, hip_y + 0.04, -0.3 * k)
	var gs := sin(t * 1.3)
	var speak_r := Vector3(0.18, 0.98 + 0.12 * bt, -0.3 - 0.08 * bt) * k
	var speak_l := Vector3(-0.18, 0.98 + 0.12 * bt - 0.05 * gs, -0.3 - 0.08 * bt) * k
	r.arm_to("r", (kn + Vector3(0.13, 0.04, 0.0) * k).lerp(speak_r, talk), POLE_R, null)
	r.arm_to("l", (kn + Vector3(-0.13, 0.04, 0.0) * k).lerp(speak_l, talk * 0.8), POLE_L, null)
	a.data["head"] = 0.08 * bt + (0.12 * pow(maxf(0.0, sin(t * 1.7)), 6.0) if talk < 0.5 else 0.0)
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.1 * gs * talk))
	return off


## The watchman's lantern held up and out to peer into the dark, the head sweeping.
static func _lantern_raise(a: Variant, r: Variant, k: float) -> float:
	var t: float = a._t
	var w := smoothstep(0.0, 0.6, float(a.act_t)) * (1.0 - smoothstep(float(a.data.get("len", 4.0)) - 0.6, float(a.data.get("len", 4.0)), float(a.act_t)))
	var off := _legs(a, r, k, 0.016)
	var rest := Vector3(-0.24, 0.8, -0.14)
	var up := Vector3(-0.3, 1.5, -0.34)
	r.hold(1, rest.lerp(up, w) * k, Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1.0, 0.2, 0.2))
	var sweep := sin(t * 0.8) * w
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.UP, 0.3 * sweep) * Quaternion(Vector3.RIGHT, 0.05 * w))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.3 * sweep))
	_tool_hold(a, r, k, true, false)
	return off


## The moon going out: the head thrown back, a hand to the chest and the other to the mouth.
static func _eclipse(a: Variant, r: Variant, k: float) -> float:
	var off := _legs(a, r, k, 0.016)
	var w := smoothstep(0.0, 1.0, float(a.act_t))
	r.arm_to("r", Vector3(0.22, 0.86, -0.02).lerp(Vector3(0.06, 1.12, -0.22), w) * k, POLE_R, null)
	r.arm_to("l", Vector3(-0.22, 0.86, -0.02).lerp(Vector3(-0.05, 1.3, -0.24), w) * k, POLE_L, null)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, 0.08 * w))
	_tool_hold(a, r, k, false, false)
	return off


## A raised hand and a turn of the forearm: over any act, on a hand that is free (the right, else the left).
static func _wave(a: Variant, r: Variant, k: float, w: float, free_r: bool, free_l: bool) -> void:
	if not (free_r or free_l):
		return
	var side := "r" if free_r else "l"
	var sx := 1.0 if free_r else -1.0
	var t: float = a._t
	var hang := Vector3(0.22 * sx, 0.86, -0.02)
	var up := Vector3((0.3 + 0.07 * sin(t * 9.0)) * sx, 1.66, -0.1)
	r.arm_to(side, hang.lerp(up, w) * k, Vector3(0.9 * sx, 0.2, 0.2), null)
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, -0.2 * sx * w))
