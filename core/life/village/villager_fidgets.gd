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
			if free_r or free_l:
				var tgt := Vector3(0.08 * sx, 1.55, 0.12 + 0.03 * sin(t * 9.0))
				r.arm_to(side, rest.lerp(tgt, env) * k, Vector3(0.9 * sx, -0.2, 0.7), null)
			head = 0.22 * env
			r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, 0.06 * env * sx))
		5:   # shading the eyes: a flat hand at the brow, the head up and slowly turning, peering into the dark
			if free_r or free_l:
				var tgt5 := Vector3(0.1 * sx, 1.52, -0.3)
				r.arm_to(side, rest.lerp(tgt5, env) * k, Vector3(0.7 * sx, -0.4, 0.2), null)
			head = -0.1 * env
			r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.5 * env * sin(t * 0.7)))
		6:   # hands on the hips, the chest turning to look round at the dark
			if free_r:
				r.arm_to("r", rest.lerp(Vector3(0.3, 1.0, -0.04), env) * k, Vector3(1.0, -0.2, 0.0), null)
			if free_l:
				r.arm_to("l", Vector3(-rest.x, rest.y, rest.z).lerp(Vector3(-0.3, 1.0, -0.04), env) * k, Vector3(-1.0, -0.2, 0.0), null)
			r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.55 * env * sin(t * 0.9)))
			r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, 0.08 * env))
			head = -0.08 * env
		7:   # a yawn: the head thrown back, the back arched, a hand to the mouth at the top of it
			var yaw := sin(clampf(env, 0.0, 1.0) * PI)
			if free_r or free_l:
				r.arm_to(side, rest.lerp(Vector3(0.04 * sx, 1.42, -0.28), yaw) * k, Vector3(0.8 * sx, -0.5, 0.3), null)
			r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, 0.2 * yaw))
			head = -0.5 * yaw + 0.25 * maxf(0.0, env - 0.7)
		8:   # blowing into cupped hands: both up at the mouth, the shoulders hunched, a little shudder
			if free_r and free_l:
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
