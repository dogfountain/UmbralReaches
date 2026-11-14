extends RefCounted
## A villager standing about, split out of villager.gd: a weight shift from foot to foot that moves the whole pelvis and
## shoulders, the chest turning against the head's look-around, and every 8-13 s (a slot of the villager's own) one larger
## gesture lasting about 3 s: a stretch (arms up, back arched), rubbing the hands together against the cold, adjusting a strap
## on the shoulder, or a glance up at the sky. A figure whose hands are full (a pole, a lantern, a staff) does the ones that
## need no hand: the stretch of the back and shoulders, a glance up, a shift of the pole's grip (the free shoulder rolling).
## Static; `v` is the Villager. Returns the head pitch to add (negative looks up).
const B_SPINE := 1
const B_CHEST := 2
const B_ARM_R := 5
const B_FORE_R := 6
const B_ARM_L := 8
const B_FORE_L := 9
const B_THIGH_R := 11
const B_SHIN_R := 12
const B_THIGH_L := 13
const B_SHIN_L := 14


static func stand(v: Variant, k: float, free_r: bool, free_l: bool, breath: float) -> float:
	var r: Variant = v.rig
	var t: float = v._t
	var ph := float(hash(v.id) % 628) * 0.01
	var ws := sin(t * 0.45 + ph)                                  # the weight: -1 on the left foot, +1 on the right
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.FORWARD, 0.1 * ws) * Quaternion(Vector3.RIGHT, 0.06 * sin(t * 0.37 + ph * 1.3)))
	v._shift_x = -0.035 * k * ws                                 # the hips go over the standing foot
	var head := 0.0
	if not v.speaking and v.attend == null:
		r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.14 * sin(t * 0.23 + ph * 1.7)) * Quaternion(Vector3.BACK, -0.05 * ws))
		var period := 8.0 + float(absi(hash(v.id)) % 5)
		var tt: float = t + ph * 3.0
		var slot := int(floor(tt / period))
		var u := fposmod(tt, period) / period
		var env := smoothstep(0.0, 0.07, u) * (1.0 - smoothstep(0.24, 0.32, u))
		var kind := absi(slot + hash(v.id)) % 4
		var hands_free := free_r and free_l
		if kind == 1 and not hands_free:
			kind = 0
		if kind == 2 and not (free_r or free_l):
			kind = 3
		match kind:
			0:   # stretch: the back arched, the shoulders back, the arms thrown up when they are free
				r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, 0.26 * env))
				r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.RIGHT, 0.12 * env))
				head = -0.35 * env
				if free_r:
					r.q(B_ARM_R, (r.get_q(B_ARM_R) as Quaternion) * Quaternion(Vector3.RIGHT, -2.5 * env) * Quaternion(Vector3.BACK, 0.25 * env))
				if free_l:
					r.q(B_ARM_L, (r.get_q(B_ARM_L) as Quaternion) * Quaternion(Vector3.RIGHT, -2.5 * env) * Quaternion(Vector3.FORWARD, 0.25 * env))
			1:   # hands rubbed together at the belly against the cold
				var rub := 0.05 * sin(t * 11.0)
				r.arm_to("r", Vector3(0.03 + rub, 0.98 - 0.04 * env, -0.28 * env) * k + Vector3(0, 0, -0.1) * k * (1.0 - env), Vector3(0.9, -0.6, 0.2), null)
				r.arm_to("l", Vector3(-0.03 - rub, 0.98 - 0.04 * env, -0.28 * env) * k + Vector3(0, 0, -0.1) * k * (1.0 - env), Vector3(-0.9, -0.6, 0.2), null)
				head = 0.2 * env
				r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.1 * env))
			2:   # a hand to the strap over the opposite shoulder, and a settling of the shoulders
				var side := "r" if free_r else "l"
				var sx := -0.1 if free_r else 0.1
				r.arm_to(side, Vector3(sx, 1.3, -0.12) * k, Vector3(0.9 if free_r else -0.9, -0.5, 0.3), null)
				r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, 0.08 * env * (1.0 if free_r else -1.0)))
				head = 0.12 * env
			_:   # a glance up at the sky: the head thrown back, the chest following
				head = -0.55 * env
				r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.RIGHT, 0.14 * env))
				r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, 0.08 * env))
	if free_l:
		r.q(B_ARM_L, (r.get_q(B_ARM_L) as Quaternion) * Quaternion(Vector3.BACK, -0.02 - 0.05 * breath * 12.0))
	# the standing leg locks, the other knee softens and the heel lifts a little: a hip dropped to the free side
	var rest_r := 0.13 * maxf(0.0, ws)
	var rest_l := 0.13 * maxf(0.0, -ws)
	r.q(B_THIGH_R, (r.get_q(B_THIGH_R) as Quaternion) * Quaternion(Vector3.RIGHT, rest_r))
	r.q(B_SHIN_R, (r.get_q(B_SHIN_R) as Quaternion) * Quaternion(Vector3.RIGHT, -2.0 * rest_r))
	r.q(B_THIGH_L, (r.get_q(B_THIGH_L) as Quaternion) * Quaternion(Vector3.RIGHT, rest_l))
	r.q(B_SHIN_L, (r.get_q(B_SHIN_L) as Quaternion) * Quaternion(Vector3.RIGHT, -2.0 * rest_l))
	return head
