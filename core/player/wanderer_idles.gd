extends RefCounted
## The wanderer when he is not going anywhere (CharacterRig calls `tick` every frame). Ten small acts, chosen by the night
## round him (the rig's `idle_ctx`, kept by WandererLife from the Living Night's registry and the weather):
##   0 look about            1 the lantern lifted to peer ahead   2 weight on the staff        3 a glance back over a shoulder
##   4 warming his hands at a fire he stands by (the lantern hand out, rubbing)      5 shivering (cold, the eclipse, rain)
##   6 shaking the rain off  7 catching his breath after a sprint, hands to the knees 8 looking at a landmark or a person
##   9 a stretch.
## And the condition overlays that run whether he is still or not: a limp and a slump when hurt (`injured`), the chest
## working after a sprint (`tired`), the lantern carried higher in the dark (`dark`), a fine tremble in the cold.
## Every act is an envelope of `_ia_k` (eased in at 6/s, out at 5/s, cut by any movement), so an act that is begun
## or broken off is never a snap. All additive on the rig's own joints. Static; `r` is the CharacterRig.

const LEN := [3.8, 3.4, 4.4, 2.6, 4.6, 4.2, 3.0, 4.0, 4.0, 3.4]
const SPRINT_FRAC := 0.8


static func tick(r: Variant, speed: float, on_floor: bool, dt: float) -> void:
	var ctx: Dictionary = r.idle_ctx
	_conditions(r, ctx, speed, dt)
	var still: bool = on_floor and speed < 0.2 and r._cast_t < 0.0 and r.charge <= 0.0 and r.hang < 0.01 \
		and r._mv_t < 0.0 and not r.lock and r.slide < 0.01 and r._hit <= 0.0
	r._still = r._still + dt if still else 0.0
	if r._ia < 0:
		if still and float(ctx.get("tired", 0.0)) > 0.5:
			_begin(r, 7)
		elif r._still > r._ia_next:
			_begin(r, _choose(r, ctx))
		else:
			return
	r._ia_t += dt
	var u: float = r._ia_t / r._ia_len
	var env := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.75, 1.0, u))
	r._ia_k = minf(env, r._ia_k + dt * 6.0) if still else move_toward(r._ia_k, 0.0, dt * 5.0)
	if u >= 1.0 or (not still and r._ia_k <= 0.0):
		r._ia = -1
		r._ia_k = 0.0
		r._ia_next = r._still + r._rng.randf_range(4.0, 9.0)
		return
	_act(r, int(r._ia), float(r._ia_k), u, ctx, dt)


static func _begin(r: Variant, id: int) -> void:
	r._ia = id
	r._ia_last = id
	r._ia_t = 0.0
	r._ia_len = float(LEN[id])


## A weighted pick: the plain acts always, the others by what is round him; never the same act twice running.
static func _choose(r: Variant, ctx: Dictionary) -> int:
	var w: Array[float] = [3.0, 2.0, 2.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]
	if float(ctx.get("fire", 0.0)) > 0.5:
		w[4] = 8.0
		w[2] = 0.6
	if float(ctx.get("cold", 0.0)) > 0.5:
		w[5] = 4.0
	if float(ctx.get("rain", 0.0)) > 0.4:
		w[6] = 5.0
		w[5] += 2.0
	if float(ctx.get("dark", 0.0)) > 0.4:
		w[1] += 3.0
	if (ctx.get("look", Vector3.INF) as Vector3) != Vector3.INF:
		w[8] = 7.0
	if int(r._ia_last) >= 0:
		w[int(r._ia_last)] = 0.0
	var total := 0.0
	for x: float in w:
		total += x
	var pick: float = r._rng.randf() * total
	for i in w.size():
		pick -= w[i]
		if pick <= 0.0:
			return i
	return 0


## What he carries whatever he is doing.
static func _conditions(r: Variant, ctx: Dictionary, speed: float, dt: float) -> void:
	# exertion: a run builds it, standing lets it go (a breath is caught after about five seconds)
	var ex: float = float(ctx.get("ex", 0.0))
	if speed > r.sprint_speed * SPRINT_FRAC:
		ex = minf(1.0, ex + dt * 0.3)
	else:
		ex = maxf(0.0, ex - dt * (0.2 if speed < 0.3 else 0.08))
	ctx["ex"] = ex
	ctx["tired"] = ex if speed < 0.3 else 0.0
	if ex > 0.02:
		var pulse := sin(float(r._t) * 6.5)
		r._chest.scale += Vector3(0.012, 0.035, 0.012) * ex * pulse
		r._torso.rotation.x += 0.05 * ex
		r._head.rotation.x += 0.03 * ex * pulse
	var inj: float = float(ctx.get("injured", 0.0))
	if inj > 0.01:
		r._torso.rotation.x += 0.12 * inj
		r._head.rotation.x += 0.1 * inj
		r._pelvis.position.y -= 0.03 * inj
		r._pelvis.rotation.z += 0.06 * inj * sin(TAU * float(r._cyc)) * clampf(speed / 3.0, 0.0, 1.0)
		r._sh[0].rotation.x += 0.1 * inj
	var dark: float = float(ctx.get("dark", 0.0))
	if dark > 0.01:
		r._sh[0].rotation.x += 0.28 * dark                 # the lantern carried higher: its light goes farther
	var cold: float = float(ctx.get("cold", 0.0))
	if cold > 0.01:
		r._torso.rotation.z += sin(float(r._t) * 31.0) * 0.004 * cold
		r._sh[1].rotation.z -= 0.06 * cold
		r._sh[0].rotation.z += 0.06 * cold


static func _act(r: Variant, id: int, k: float, u: float, ctx: Dictionary, dt: float) -> void:
	var t: float = r._t
	match id:
		0:  # look about: left, then right
			var s := sin(u * TAU)
			r._head.rotation.y += s * 0.7 * k
			r._torso.rotation.y += s * 0.16 * k
			r._head.rotation.x += 0.06 * k
		1:  # the lantern lifted to peer into the dark ahead
			r._sh[0].rotation.x += 1.2 * k
			r._sh[0].rotation.z += 0.3 * k
			r._el[0].rotation.x += 0.35 * k
			r._head.rotation.x -= 0.08 * k
			r._head.rotation.y += 0.18 * k
			r._torso.rotation.x -= 0.08 * k
			r._torso.rotation.y += 0.1 * k
		2:  # weight onto the staff, a slow breath
			r._staff_off.x -= 0.1 * k
			r._sh[1].rotation.x += 0.28 * k
			r._el[1].rotation.x += 0.25 * k
			r._torso.rotation.z -= 0.07 * k
			r._torso.rotation.x -= 0.07 * k
			r._pelvis.position.x += 0.03 * k
			r._head.rotation.x -= 0.14 * k * (0.7 + 0.3 * sin(t * 1.2))
		3:  # a glance back over the right shoulder
			var b := smoothstep(0.08, 0.35, u) * (1.0 - smoothstep(0.62, 0.9, u))
			r._head.rotation.y -= 1.0 * b * k
			r._torso.rotation.y -= 0.32 * b * k
			r._sh[0].rotation.x += 0.12 * b * k
		4:  # warming his hands: the free hand out to the fire, turning and rubbing, the head down to the flame
			r._sh[0].rotation.x += 1.1 * k
			r._sh[0].rotation.z += 0.15 * k
			r._el[0].rotation.x += (0.7 + sin(t * 9.0) * 0.08) * k
			r._sh[1].rotation.x += 0.3 * k
			r._el[1].rotation.x += 0.4 * k
			r._torso.rotation.x += 0.08 * k
			r._head.rotation.x += 0.1 * k
			r._torso.rotation.y += sin(t * 0.8) * 0.1 * k
		5:  # shivering: hunched in, the whole body trembling, the head sunk
			r._torso.rotation.z += sin(t * 29.0) * 0.014 * k
			r._torso.rotation.x += 0.1 * k
			r._sh[0].rotation.z += 0.2 * k
			r._sh[1].rotation.z -= 0.2 * k
			r._head.rotation.x += 0.12 * k
			r._pelvis.position.y -= 0.015 * k
			for i in 2:
				r._knee[i].rotation.x -= 0.06 * k
		6:  # shaking the rain off: the head and shoulders turning in a quick, dying oscillation
			var s2 := sin(u * TAU * 3.0) * exp(-u * 3.0) * k
			r._head.rotation.y += s2 * 0.5
			r._torso.rotation.y += s2 * 0.18
			r._sh[0].rotation.z += absf(s2) * 0.2
			r._head.rotation.x += 0.1 * k
		7:  # catching his breath: bent over, a hand on the knee, the chest working
			r._torso.rotation.x += 0.38 * k
			r._head.rotation.x += 0.25 * k
			r._sh[0].rotation.x += 0.45 * k
			r._el[0].rotation.x += 0.2 * k
			r._pelvis.position.y -= 0.05 * k
			for i in 2:
				r._knee[i].rotation.x -= 0.2 * k
				r._hip[i].rotation.x += 0.1 * k
			r._chest.scale += Vector3(0.01, 0.03, 0.01) * k * sin(t * 7.0)
		8:  # looking at a landmark or a person: the head and the shoulders turn to it and hold
			var pt: Vector3 = ctx.get("look", Vector3.INF)
			var ly: float = float(ctx.get("ly", 0.0))
			var lp: float = float(ctx.get("lp", 0.0))
			var ty := 0.0
			var tp := 0.0
			if pt != Vector3.INF:
				var l: Vector3 = (r.global_basis as Basis).orthonormalized().inverse() * (pt - (r._head as Node3D).global_position)
				ty = clampf(atan2(-l.x, -l.z), -1.1, 1.1)
				tp = clampf(atan2(l.y, Vector2(l.x, l.z).length()), -0.4, 0.5)
			ly = lerpf(ly, ty, 1.0 - exp(-4.0 * dt))
			lp = lerpf(lp, tp, 1.0 - exp(-4.0 * dt))
			ctx["ly"] = ly
			ctx["lp"] = lp
			r._head.rotation.y += ly * 0.75 * k
			r._torso.rotation.y += ly * 0.25 * k
			r._head.rotation.x -= lp * 0.7 * k
			ctx["look_done"] = pt
		9:  # a stretch: an arm up, the back arched, the head back
			var b2 := smoothstep(0.05, 0.4, u) * (1.0 - smoothstep(0.7, 1.0, u))
			r._sh[0].rotation.x += 2.6 * b2 * k
			r._sh[0].rotation.z += 0.3 * b2 * k
			r._torso.rotation.x -= 0.22 * b2 * k
			r._head.rotation.x -= 0.3 * b2 * k
