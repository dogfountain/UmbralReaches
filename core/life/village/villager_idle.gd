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
const Fidgets := preload("res://core/life/village/villager_fidgets.gd")


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
		var kind := absi(slot + hash(v.id)) % 15      # (four of the old, six of villager_fidgets.gd)
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
			4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14:
				head = Fidgets.gesture(v, kind, env, k, free_r, free_l)
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
	Fidgets.wave(v, k, free_r, free_l)
	return head


## A seated figure is never a statue at 15 m: the body rocks on its seat, the dozer's head sinks and jerks up, the sitter
## leans in now and then. Returns the head pitch to add.
static func sit_life(v: Variant, doze: bool) -> float:
	var r: Variant = v.rig
	var t: float = v._t
	var ph := float(hash(v.id) % 7)
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, 0.07 * sin(t * 0.5 + ph)) * Quaternion(Vector3.RIGHT, 0.05 * sin(t * 0.31 + ph)))
	if doze:
		var nod := fposmod(t * 0.18 + ph * 0.13, 1.0)
		r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.1 * smoothstep(0.0, 0.85, nod)))
		return 0.28 * smoothstep(0.0, 0.85, nod) - 0.55 * smoothstep(0.88, 0.93, nod) * (1.0 - smoothstep(0.93, 1.0, nod))
	var c := fposmod(t + ph * 3.0, 9.0) / 9.0
	var lean_in := smoothstep(0.0, 0.1, c) * (1.0 - smoothstep(0.25, 0.35, c))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.2 * lean_in))
	return 0.1 * lean_in


## Warming the hands (about 4.5 s), read from the body: the hands pushed out to the glow and the body leaning in after
## them, then drawn back to the chest with the shoulders hunched, the whole body turning side to side to the fire.
static func warm(v: Variant, k: float, stoop: float) -> void:
	var r: Variant = v.rig
	var t: float = v._t
	var ph := float(hash(v.id) % 5)
	var wc := fposmod(t * 0.22 + ph * 0.2, 1.0)
	var out := smoothstep(0.0, 0.2, wc) * (1.0 - smoothstep(0.55, 0.72, wc))
	var rub := sin(t * 5.0) * 0.05 * out
	var turn := sin(t * 0.8 + ph)
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.04 - 0.2 * out + 0.1 * (1.0 - out) - stoop * 0.4) * Quaternion(Vector3.UP, 0.2 * turn))
	r.q(B_CHEST, Quaternion(Vector3.UP, 0.3 * turn) * Quaternion(Vector3.RIGHT, -0.1 * (1.0 - out)) * Quaternion(Vector3.FORWARD, 0.05 * sin(t * 9.0) * (1.0 - out)))
	var hand_out := Vector3(0.13 + rub, 1.04, -0.62)
	var hand_in := Vector3(0.1, 1.2, -0.2)
	r.arm_to("r", hand_out.lerp(hand_in, 1.0 - out) * k, Vector3(0.9, -0.6, 0.2), null)
	r.arm_to("l", Vector3(-hand_out.x - rub * 2.0, hand_out.y, hand_out.z).lerp(Vector3(-hand_in.x, hand_in.y, hand_in.z), 1.0 - out) * k, Vector3(-0.9, -0.6, 0.2), null)


## Hands full at the fire: only the shoulders turn with the heat.
static func warm_turn(v: Variant) -> void:
	var r: Variant = v.rig
	var tw := sin(v._t * 0.6 + float(hash(v.id) % 5))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.1) * Quaternion(Vector3.UP, 0.25 * tw))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.2 * tw) * Quaternion(Vector3.FORWARD, 0.04 * sin(v._t * 8.0)))


## A stamp every few seconds, on alternate feet (applied after the legs are posed).
static func stamp(v: Variant) -> void:
	var r: Variant = v.rig
	var stp := pow(maxf(0.0, sin(v._t * 1.9)), 6.0)
	var sd := B_THIGH_R if sin(v._t * 0.95) > 0.0 else B_THIGH_L
	r.q(sd, (r.get_q(sd) as Quaternion) * Quaternion(Vector3.RIGHT, 0.7 * stp))
	r.q(sd + 1, (r.get_q(sd + 1) as Quaternion) * Quaternion(Vector3.RIGHT, -1.1 * stp))


## Keeping watch: the shoulders and head sweep from side to side and hold at each end, peering out (a lookout reads by the
## turn). Returns the head pitch to add.
static func watch(v: Variant) -> float:
	var r: Variant = v.rig
	var wv := sin(v._t * 0.42 + float(hash(v.id) % 7))
	var wt := signf(wv) * smoothstep(0.25, 0.8, absf(wv))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.UP, 0.4 * wt) * Quaternion(Vector3.RIGHT, -0.12 * absf(wt)))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.5 * wt) * Quaternion(Vector3.RIGHT, -0.08 * absf(wt)))
	v._shift_x = 0.05 * wt
	return 0.1 * absf(wt)
