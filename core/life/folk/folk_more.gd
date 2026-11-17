extends RefCounted
## More of the folk (roles and their poses): a DRUNK outside the Keg, a WOODCUTTER splitting logs on a block, a SMITH at an anvil by a forge,
## a LAMPLIGHTER who walks the lamps near a town with his pole and tends each, a SHEPHERD with a crook and a dog, a PRIEST at the chapel.
## `tick` is called by folk_roles.gd for any role it does not know (true if handled); `pose` by folk_poses.gd for any act it does not know
## (returns the root height offset, or -1e9 if the act is not one of these). The same rules as the rest of the folk: every gesture an envelope
## of the act's clock, arm IK targets blended from rest, the actor's own easing and crossfade doing the rest. Static.
const Life := preload("res://core/npc/npc_life.gd")
const NightFx := preload("res://core/world/night_life/night_fx.gd")

const B_SPINE := 1
const B_CHEST := 2
const B_THIGH_R := 11
const B_SHIN_R := 12
const B_THIGH_L := 13
const B_SHIN_L := 14
const POLE_R := Vector3(0.9, -0.5, 0.3)
const POLE_L := Vector3(-0.9, -0.5, 0.3)
const NONE := -1e9


static func tick(a: Variant, dt: float) -> bool:
	var d: Dictionary = a.data
	match String(a.role):
		"drunk":
			# a slow, aimless stagger about his spot: a new place within a metre and a half every few seconds, a long stand between
			var home: Vector2 = d.get("home", Vector2.ZERO)
			var wait: float = float(d.get("wait", 0.0)) - dt
			a.act = "drunk"
			if wait <= 0.0:
				var ang := randf() * TAU
				a.goal = home + Vector2(cos(ang), sin(ang)) * randf_range(0.3, 1.5)
				a.has_goal = true
				a.speed = 0.35
				wait = randf_range(5.0, 11.0)
			d["wait"] = wait
			return true
		"woodcutter":
			a.has_goal = false
			a.act = "chop_wood"
			a.face = float(d.get("face", 0.0))
			return true
		"smith":
			a.has_goal = false
			a.act = "hammer"
			a.face = float(d.get("face", 0.0))
			return true
		"lamplighter":
			_lamps(a, dt, d)
			return true
		"shepherd":
			_shepherd(a, dt, d)
			return true
		"priest":
			a.has_goal = false
			a.act = "bless"
			a.face = float(d.get("face", 0.0)) + 0.25 * sin(float(a._t) * 0.05)
			return true
	return false


## The lamplighter walks his lamps in order (positions in data["lamps"]), tends each for five seconds with the pole raised, and goes round again.
static func _lamps(a: Variant, dt: float, d: Dictionary) -> void:
	var lamps: Array = d.get("lamps", [])
	if lamps.is_empty():
		a.has_goal = false
		a.act = "stand"
		return
	var i: int = int(d.get("i", 0)) % lamps.size()
	var stay: float = float(d.get("stay", 0.0))
	if stay > 0.0:
		d["stay"] = stay - dt
		a.has_goal = false
		a.act = "lamp"
		return
	var here := Vector2(a.global_position.x, a.global_position.z)
	var at: Vector2 = lamps[i]
	var stand := at + (here - at).normalized() * 0.9          # beside the post, not in it
	if here.distance_to(stand) < 0.35:
		d["stay"] = 5.0
		d["i"] = i + 1
		a.face = atan2(-(at.x - here.x), -(at.y - here.y))
		return
	a.goal = stand
	a.has_goal = true
	a.speed = 0.95
	a.act = "walk"


## The shepherd walks a loop of three or four points slowly with his crook, and stops at each to lean on it and watch the dark.
static func _shepherd(a: Variant, dt: float, d: Dictionary) -> void:
	var pts: Array = d.get("pts", [])
	if pts.is_empty():
		a.has_goal = false
		a.act = "stand"
		return
	var stay: float = float(d.get("stay", 0.0))
	if stay > 0.0:
		d["stay"] = stay - dt
		a.has_goal = false
		a.act = "lean"
		return
	var i: int = int(d.get("i", 0)) % pts.size()
	var here := Vector2(a.global_position.x, a.global_position.z)
	var tgt: Vector2 = pts[i]
	if here.distance_to(tgt) < 0.4:
		d["stay"] = randf_range(8.0, 16.0)
		d["i"] = i + 1
		return
	a.goal = tgt
	a.has_goal = true
	a.speed = 0.8
	a.act = "walk"


# --- poses -----------------------------------------------------------------------------------------

static func pose(a: Variant, act: String, r: Variant, k: float, dt: float) -> float:
	match act:
		"drunk":
			return _drunk(a, r, k, dt)
		"chop_wood":
			return _chop(a, r, k, dt)
		"hammer":
			return _hammer(a, r, k, dt)
		"lamp":
			return _lamp(a, r, k, dt)
		"lean":
			return _lean(a, r, k, dt)
		"bless":
			return _bless(a, r, k, dt)
	return NONE


static func _legs(a: Variant, r: Variant, k: float, dt: float) -> float:
	var life: Variant = a.life
	var amt: float = a.walk_amt
	if amt > 0.001:
		life.turn_reset((a as Node3D).global_rotation.y)
		var g: Array = a.gait_g
		return Life.walk_legs(r, float(a.gait), amt, float(g[0]), float(g[1]), float(g[2]) * k)
	var td: float = life.turn_legs(r, (a as Node3D).global_rotation.y, dt)
	return td if td != INF else 0.0


## Wide-stanced and swaying, the weight lurching from foot to foot, the head lolling, a jug raised to the mouth every eleven seconds, a hiccup.
static func _drunk(a: Variant, r: Variant, k: float, dt: float) -> float:
	var t: float = a._t
	var off := _legs(a, r, k, dt)
	var sw := sin(t * 0.9)
	var roll := 0.16 * sw + 0.05 * sin(t * 2.3)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.FORWARD, roll) * Quaternion(Vector3.RIGHT, -0.08 + 0.05 * sin(t * 0.55)))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.18 * sin(t * 0.7)) * Quaternion(Vector3.FORWARD, -0.5 * roll))
	if float(a.walk_amt) < 0.1:
		r.q(B_THIGH_R, (r.get_q(B_THIGH_R) as Quaternion) * Quaternion(Vector3.BACK, 0.1 + 0.06 * sw))
		r.q(B_THIGH_L, (r.get_q(B_THIGH_L) as Quaternion) * Quaternion(Vector3.BACK, -0.1 + 0.06 * sw))
	var hic := pow(maxf(0.0, sin(t * 1.7 + 2.0)), 30.0)
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.RIGHT, -0.07 * hic))
	var c := fposmod(t, 11.0)
	var e := smoothstep(6.0, 7.0, c) * (1.0 - smoothstep(8.2, 9.2, c))
	r.hold(0, Vector3(0.27, 0.9, -0.1).lerp(Vector3(0.04, 1.4, -0.3), e) * k, Vector3(0, 0, -1).slerp(Vector3(0.2, 0.55, -0.8).normalized(), e), Vector3(0, -1, 0), POLE_R)
	r.arm_to("l", Vector3(-0.34 - 0.08 * sw, 0.98 + 0.05 * sin(t * 1.3), -0.05) * k, Vector3(-1.0, -0.2, 0.2), null)
	a.data["head"] = 0.2 * sin(t * 0.6) + 0.35 * e - 0.1
	return off


## Splitting wood: the axe raised over the shoulder, brought down onto the block in front, chips flying at the blow, the knees giving a little.
static func _chop(a: Variant, r: Variant, k: float, dt: float) -> float:
	var off := _legs(a, r, k, dt)
	var cyc := fposmod(float(a._t), 1.8) / 1.8
	var block := Vector3(0.05, 0.36, -0.82) * k
	var tips: Array = r.tips
	var grips: Array = r.grip
	var reach := ((tips[0] as Vector3) - (grips[0] as Vector3)).length()
	var hit_d := Vector3(0.0, -0.75, -0.66).normalized()
	var hit_g := block - hit_d * reach
	var up_g := Vector3(0.06, 1.42, -0.02) * k
	var up_d := Vector3(0, 0.9, 0.45).normalized()
	var g: Vector3
	var d: Vector3
	if cyc < 0.55:
		var e := smoothstep(0.0, 0.55, cyc)
		g = hit_g.lerp(up_g, e)
		d = hit_d.slerp(up_d, e)
	elif cyc < 0.62:
		var e2 := pow((cyc - 0.55) / 0.07, 2.0)
		g = up_g.lerp(hit_g, e2)
		d = up_d.slerp(hit_d, e2)
	else:
		g = hit_g
		d = hit_d
	var wind := smoothstep(0.0, 0.5, cyc) * (1.0 - smoothstep(0.55, 0.6, cyc))
	var bend := 0.1 - 0.08 * wind + 0.32 * smoothstep(0.55, 0.62, cyc) * (1.0 - smoothstep(0.75, 1.0, cyc))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -bend))
	r.hold(0, g, d, Vector3(0, 0, -1).slide(d).normalized() if cyc < 0.55 or absf(d.y) > 0.95 else Vector3.DOWN.slide(d).normalized(), Vector3(0.9, -0.3, 0.4))
	r.hold(1, g - d * 0.1 * k, d, Vector3(0, 0, -1).slide(d).normalized() if cyc < 0.55 or absf(d.y) > 0.95 else Vector3.DOWN.slide(d).normalized(), Vector3(-0.9, -0.3, 0.4))
	var struck := cyc >= 0.58 and cyc < 0.7
	if struck and not bool(a.data.get("hit", false)):
		a.data["hit"] = true
		var node := a as Node3D
		NightFx.burst(node.to_global(block * 1.1 + Vector3(0.0, 0.1, 0.0)), Color(0.55, 0.4, 0.26, 0.9), "chips", Vector3.UP)
	elif cyc < 0.5:
		a.data["hit"] = false
	return off - 0.03 * k * smoothstep(0.55, 0.62, cyc) * (1.0 - smoothstep(0.7, 0.9, cyc))


## At the anvil: the hammer raised, brought down on the iron the tongs hold, a spark at each blow; the body throws the blow.
static func _hammer(a: Variant, r: Variant, k: float, dt: float) -> float:
	var off := _legs(a, r, k, dt)
	var cyc := fposmod(float(a._t), 0.95) / 0.95
	var anvil := Vector3(0.08, 0.84, -0.55) * k
	var tips: Array = r.tips
	var grips: Array = r.grip
	var reach := ((tips[0] as Vector3) - (grips[0] as Vector3)).length()
	var hit_d := Vector3(0.0, -0.6, -0.8).normalized()
	var hit_g := anvil - hit_d * reach * 0.98
	var up_g := Vector3(0.2, 1.5, -0.1) * k
	var up_d := Vector3(0.0, 0.7, 0.72).normalized()
	var g: Vector3
	var d: Vector3
	if cyc < 0.55:
		var e := smoothstep(0.0, 0.55, cyc)
		g = hit_g.lerp(up_g, e)
		d = hit_d.slerp(up_d, e)
	elif cyc < 0.66:
		var e2 := pow((cyc - 0.55) / 0.11, 2.0)
		g = up_g.lerp(hit_g, e2)
		d = up_d.slerp(hit_d, e2)
	else:
		g = hit_g + Vector3.UP * 0.05 * sin((cyc - 0.66) / 0.34 * PI) * k
		d = hit_d
	var wind := smoothstep(0.0, 0.5, cyc) * (1.0 - smoothstep(0.55, 0.64, cyc))
	var lean := 0.1 - 0.06 * wind + 0.18 * smoothstep(0.55, 0.66, cyc) * (1.0 - smoothstep(0.72, 1.0, cyc))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.UP, 0.08 * wind) * Quaternion(Vector3.RIGHT, -lean))
	r.hold(0, g, d, Vector3(0, 0, -1).slide(d).normalized(), Vector3(0.7, -0.7, 0.2))
	# the tongs hold the iron on the anvil
	var tl: Vector3 = (tips[1] as Vector3) - (grips[1] as Vector3)
	var td := Vector3(-0.1, -0.2, -1.0).normalized()
	r.hold(1, anvil + Vector3(-0.05, 0.03, 0.04) * k - td * tl.length(), td, Vector3.DOWN, Vector3(-0.9, -0.4, 0.3))
	var struck := cyc >= 0.64 and cyc < 0.78
	if struck and not bool(a.data.get("hit", false)):
		a.data["hit"] = true
		NightFx.burst((a as Node3D).to_global(anvil + Vector3(0.0, 0.08, 0.0)), Color(2.4, 1.4, 0.5), "spark")
	elif cyc < 0.5:
		a.data["hit"] = false
	return off


## The lamplighter at a post: the pole raised to the lamp's glass, the head up, a small trimming turn of the hook; the lantern low in the other hand.
static func _lamp(a: Variant, r: Variant, k: float, dt: float) -> float:
	var off := _legs(a, r, k, dt)
	var t: float = a._t
	var e := smoothstep(0.0, 0.8, float(a.act_t)) * (1.0 - smoothstep(4.2, 5.0, float(a.act_t)))
	var rest_g := Vector3(0.27, 0.95, -0.17)
	var up_g := Vector3(0.2, 1.25, -0.3)
	var rest_d := Vector3(0.03, 1.0, -0.1)
	var up_d := Vector3(0.03, 1.0, -0.55)
	var trim := sin(t * 5.0) * 0.04 * e
	r.hold(0, rest_g.lerp(up_g, e) * k, (rest_d.lerp(up_d, e) + Vector3(trim, 0, 0)).normalized(), Vector3(0, 0, -1), POLE_R)
	r.hold(1, Vector3(-0.24, 0.8, -0.14) * k, Vector3(0, 0, -1), Vector3(0, -1, 0), POLE_L)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, 0.06 * e))
	a.data["head"] = -0.5 * e
	return off


## Leaning on a crook: the weight on it, the other hip dropped, the head turning slowly out into the dark.
static func _lean(a: Variant, r: Variant, k: float, dt: float) -> float:
	var off := _legs(a, r, k, dt)
	var t: float = a._t
	var w := smoothstep(0.0, 0.8, float(a.act_t))
	var up := smoothstep(0.0, 0.08, fposmod(t * 0.14, 1.0)) * (1.0 - smoothstep(0.2, 0.3, fposmod(t * 0.14, 1.0)))
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, (-0.12 + 0.2 * up) * w) * Quaternion(Vector3.FORWARD, 0.06 * sin(t * 0.45) * w))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.25 * sin(t * 0.21) * w))
	var d := Vector3(0, -1, -0.05).normalized()
	var gp := Vector3(0.0, 1.0, -0.32)
	r.hold(0, Vector3(0.27, 1.0, -0.2).lerp(gp, w) * k, Vector3(0.04, 1.0, 0.22).normalized().slerp(d, w), Vector3(0, 0, -1), POLE_R)
	r.arm_to("l", (gp + Vector3(-0.04, 0.06, 0.02)).lerp(Vector3(-0.22, 0.86, -0.02), 1.0 - w) * k, POLE_L, null)
	return off


## The priest: twenty-four seconds in three parts: hands clasped and the head bowed in prayer; the arms raised out and up in a benediction; and a quiet
## standing with the candle held at the chest, the head turning slowly over the dark.
static func _bless(a: Variant, r: Variant, k: float, dt: float) -> float:
	var off := _legs(a, r, k, dt)
	var c := fposmod(float(a._t), 24.0)
	var pray := smoothstep(0.0, 1.5, c) * (1.0 - smoothstep(7.0, 8.5, c))
	var bene := smoothstep(8.0, 10.0, c) * (1.0 - smoothstep(14.5, 16.0, c))
	var sway := sin(float(a._t) * 0.8)
	var rest_r := Vector3(0.22, 0.86, -0.02)
	var rest_l := Vector3(-0.22, 0.86, -0.02)
	var clasp := Vector3(0.03, 1.1, -0.26)
	var raise_r := Vector3(0.5, 1.55 + 0.04 * sway, -0.08)
	var raise_l := Vector3(-0.5, 1.55 - 0.04 * sway, -0.08)
	var ar := rest_r.lerp(clasp, pray).lerp(raise_r, bene)
	var al := rest_l.lerp(Vector3(-clasp.x, clasp.y, clasp.z), pray).lerp(raise_l, bene)
	if String((a.look as Dictionary).get("l", "")) == "candle":
		r.hold(1, al.lerp(Vector3(-0.1, 1.05, -0.3), 1.0 - pray - bene) * k, Vector3(0, 1, 0), Vector3(-1, 0, -0.2), POLE_L)
	else:
		r.arm_to("l", al * k, POLE_L, null)
	r.arm_to("r", ar * k, POLE_R, null)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.12 * pray + 0.1 * bene))
	a.data["head"] = 0.45 * pray - 0.35 * bene
	return off
