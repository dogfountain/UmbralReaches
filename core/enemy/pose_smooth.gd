extends RefCounted
## Smoothing for rigs that are posed by formula on the physics tick (the Villager and Beast boss rigs). Two jobs:
##   MODE CROSSFADE  a pose that is a pure function of the current mode jumps when the mode changes (a wind-up cut off
##                   by a stagger, a death out of a strike). The rig fills `raw_q` / `raw_v` with the new mode's pose;
##                   `commit` blends from the last committed pose to it over `dur` seconds with an eased weight, so
##                   every transition is a short slerp, whatever mode it comes from (and a change in the middle of a
##                   blend carries on from where the blend had got to).
##   TICK INTERPOLATION  a Skeleton3D's bone poses are not physics-interpolated (only node transforms are): posed at
##                   60 Hz they step on a 120 or 144 Hz screen. `commit` keeps the last two committed poses; the rig
##                   draws `sample_q(i, f)` / `sample_v(j, f)` each rendered frame, f = the physics interpolation fraction.
## Allocation free after _init: value types in preallocated arrays. Static, no class_name (project rule).

var n := 0
var m := 0
var raw_q: Array[Quaternion] = []
var cur_q: Array[Quaternion] = []
var prev_q: Array[Quaternion] = []
var from_q: Array[Quaternion] = []
var raw_v := PackedVector3Array()
var cur_v := PackedVector3Array()
var prev_v := PackedVector3Array()
var from_v := PackedVector3Array()
var xf := 1.0
var dur := 0.2
var primed := false


func _init(bones: int, vecs: int) -> void:
	n = bones
	m = vecs
	raw_q.resize(n)
	cur_q.resize(n)
	prev_q.resize(n)
	from_q.resize(n)
	for i in n:
		raw_q[i] = Quaternion.IDENTITY
		cur_q[i] = Quaternion.IDENTITY
		prev_q[i] = Quaternion.IDENTITY
		from_q[i] = Quaternion.IDENTITY
	raw_v.resize(m)
	cur_v.resize(m)
	prev_v.resize(m)
	from_v.resize(m)


## The mode changed: blend from the pose last committed, over `blend_s` seconds.
func mode_changed(blend_s: float) -> void:
	if not primed:
		return
	for i in n:
		from_q[i] = cur_q[i]
	for j in m:
		from_v[j] = cur_v[j]
	xf = 0.0
	dur = maxf(blend_s, 0.02)


## Commit the pose in raw_q / raw_v for this tick (crossfaded from the last, if a change is under way).
func commit(dt: float) -> void:
	for i in n:
		prev_q[i] = cur_q[i]
	for j in m:
		prev_v[j] = cur_v[j]
	var w := 1.0
	if xf < 1.0:
		xf = minf(1.0, xf + dt / dur)
		w = xf * xf * (3.0 - 2.0 * xf)
	if w < 1.0:
		for i in n:
			cur_q[i] = from_q[i].slerp(raw_q[i], w)
		for j in m:
			cur_v[j] = from_v[j].lerp(raw_v[j], w)
	else:
		for i in n:
			cur_q[i] = raw_q[i]
		for j in m:
			cur_v[j] = raw_v[j]
	if not primed:
		primed = true
		for i in n:
			prev_q[i] = cur_q[i]
		for j in m:
			prev_v[j] = cur_v[j]


func sample_q(i: int, f: float) -> Quaternion:
	return prev_q[i].slerp(cur_q[i], f)


func sample_v(j: int, f: float) -> Vector3:
	return prev_v[j].lerp(cur_v[j], f)


## A spring that settles with no overshoot (critically damped), advanced by dt in two substeps at most:
## `x` and `v` in, [x, v] out via the two refs. omega ~ 14 settles in about a third of a second.
static func spring(x: float, v: float, target: float, omega: float, dt: float) -> Vector2:
	var steps := 2 if dt > 0.025 else 1
	var h := dt / float(steps)
	for _s in steps:
		v += (-omega * omega * (x - target) - 2.0 * omega * v) * h
		x += v * h
	return Vector2(x, v)
