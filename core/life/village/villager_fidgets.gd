extends RefCounted
## Six more things a villager does when standing about, added to the four of villager_idle.gd so that a market
## square is never a row of the same four gestures: scratching the back of the neck, shading the eyes to peer out into
## the dark, hands on the hips with a look round, a yawn behind the hand, blowing into cupped hands against the cold,
## and tapping a foot while glancing at the sky. Each is a pose blended in and out by `env` (0 .. 1, the gesture's
## envelope), only ever using a hand that is free. Static; `v` is the Villager; returns the head pitch to add.
## Also `greet`: a villager who has been spoken to or passed by the wanderer lifts a hand (called by villager_idle).
const B_SPINE := 1
const B_CHEST := 2
const B_THIGH_R := 11
const B_SHIN_R := 12
const B_THIGH_L := 13
const B_SHIN_L := 14

const KINDS := 6                          ## kinds 4 .. 9 of villager_idle.stand


static func gesture(v: Variant, kind: int, env: float, k: float, free_r: bool, free_l: bool) -> float:
	var r: Variant = v.rig
	var t: float = v._t
	var side := "r" if free_r else "l"
	var sx := 1.0 if free_r else -1.0
	var pole := Vector3(0.9 * sx, -0.5, 0.3)
	var rest := Vector3(0.22 * sx, 0.86, -0.02)
	var head := 0.0
	match kind:
		4:   # scratching the back of the neck: the hand goes up behind the head and rubs
			if env > 0.003 and (free_r or free_l):
				var tgt := Vector3(0.08 * sx, 1.55, 0.12 + 0.03 * sin(t * 9.0))
				r.arm_to(side, rest.lerp(tgt, env) * k, Vector3(0.9 * sx, -0.2, 0.7), null)
			head = 0.22 * env
			r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, 0.06 * env * sx))
		5:   # shading the eyes: a flat hand at the brow, the head up and slowly turning, peering into the dark
			if env > 0.003 and (free_r or free_l):
				var tgt5 := Vector3(0.1 * sx, 1.52, -0.3)
				r.arm_to(side, rest.lerp(tgt5, env) * k, Vector3(0.7 * sx, -0.4, 0.2), null)
			head = -0.1 * env
			r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.5 * env * sin(t * 0.7)))
		6:   # hands on the hips, the chest turning to look round at the dark
			if env > 0.003 and free_r:
				r.arm_to("r", rest.lerp(Vector3(0.3, 1.0, -0.04), env) * k, Vector3(1.0, -0.2, 0.0), null)
			if env > 0.003 and free_l:
				r.arm_to("l", Vector3(-rest.x, rest.y, rest.z).lerp(Vector3(-0.3, 1.0, -0.04), env) * k, Vector3(-1.0, -0.2, 0.0), null)
			r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.55 * env * sin(t * 0.9)))
			r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, 0.08 * env))
			head = -0.08 * env
		7:   # a yawn: the head thrown back, the back arched, a hand to the mouth at the top of it
			var yaw := sin(clampf(env, 0.0, 1.0) * PI)
			if env > 0.003 and (free_r or free_l):
				r.arm_to(side, rest.lerp(Vector3(0.04 * sx, 1.42, -0.28), yaw) * k, Vector3(0.8 * sx, -0.5, 0.3), null)
			r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, 0.2 * yaw))
			head = -0.5 * yaw + 0.25 * maxf(0.0, env - 0.7)
		8:   # blowing into cupped hands: both up at the mouth, the shoulders hunched, a little shudder
			if env > 0.003 and free_r and free_l:
				var puff := 0.02 * sin(t * 4.0)
				r.arm_to("r", rest.lerp(Vector3(0.05, 1.4 + puff, -0.3), env) * k, Vector3(0.9, -0.6, 0.2), null)
				r.arm_to("l", Vector3(-rest.x, rest.y, rest.z).lerp(Vector3(-0.05, 1.4 + puff, -0.3), env) * k, Vector3(-0.9, -0.6, 0.2), null)
			r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.14 * env) * Quaternion(Vector3.FORWARD, 0.03 * sin(t * 13.0) * env))
			head = 0.3 * env
		_:   # tapping a foot, glancing up at the sky and down again
			var tap := pow(maxf(0.0, sin(t * 5.5)), 3.0) * env
			r.q(B_THIGH_R, (r.get_q(B_THIGH_R) as Quaternion) * Quaternion(Vector3.RIGHT, 0.32 * tap))
			r.q(B_SHIN_R, (r.get_q(B_SHIN_R) as Quaternion) * Quaternion(Vector3.RIGHT, -0.5 * tap))
			head = -0.3 * env * sin(t * 0.8)
			r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, 0.04 * env * sin(t * 2.75)))
	return head


# --- the wave -------------------------------------------------------------------------------------
# A villager standing about lifts a hand to the wanderer when he comes near in front of them: readier the better the
# village regards him (the restorations it has recorded: 0 of 6 waves a third of the time, all six nearly always).
# One wave a minute at most per person. Eased in and out; any hand that is free.
const VillageState := preload("res://core/life/village/village_state.gd")
const WAVE_LEN := 2.4
static var _wave_at := {}                 ## villager id -> [clock the wave began (-100: none), clock it may begin again]
static var _regard := 0.0
static var _regard_ms := -100000


static func wave(v: Variant, k: float, free_r: bool, free_l: bool) -> void:
	if not (free_r or free_l) or v.speaking or v.attend != null:
		return
	var now: float = v._t
	var st: Array = _wave_at.get(v.id, [-100.0, 0.0])
	var u := (now - float(st[0])) / WAVE_LEN
	if u >= 1.0:
		# not waving: maybe begin (tested a few times a second, not every frame)
		if now < float(st[1]) or fposmod(now * 4.0, 1.0) > 0.3:
			return
		var pp: Vector3 = v._player_pos()
		if pp == Vector3.INF:
			return
		var me: Vector3 = (v as Node3D).global_position
		var d := me.distance_to(pp)
		if d < 2.2 or d > 9.0 or (pp - me).normalized().dot(-(v as Node3D).global_basis.z) < 0.25:
			return
		if Time.get_ticks_msec() - _regard_ms > 5000:
			_regard_ms = Time.get_ticks_msec()
			_regard = clampf(float((VillageState.data().restored as Dictionary).size()) / 6.0, 0.0, 1.0)
		if randf() > 0.3 + 0.65 * _regard:
			_wave_at[v.id] = [-100.0, now + 25.0]
			return
		st = [now, now + 60.0 + randf() * 40.0]
		_wave_at[v.id] = st
		u = 0.0
	var e := smoothstep(0.0, 0.2, u) * smoothstep(1.0, 0.8, u)
	if e <= 0.001:
		return
	var r: Variant = v.rig
	var side := "r" if free_r else "l"
	var sx := 1.0 if free_r else -1.0
	var hang := Vector3(0.22 * sx, 0.86, -0.02)
	var up := Vector3((0.3 + 0.07 * sin(now * 9.0)) * sx, 1.66, -0.1)
	r.arm_to(side, hang.lerp(up, e) * k, Vector3(0.9 * sx, 0.2, 0.2), null)
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, -0.2 * sx * e))
