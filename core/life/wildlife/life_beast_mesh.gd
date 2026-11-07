extends RefCounted
## Four-legged wildlife meshes (deer, doe, stag, elk, fox, hare, boar). Built from lofts (smooth
## elliptical sections, one skin) rather than stacked blobs: a barrel chest tapering to a tucked waist
## and a haunch, a real neck, a wedge of a head with muzzle, ears and eyes, legs with a knee or hock
## and slim cannon bones, hooves. The coat is in the vertex colour (a dark dorsal line, a pale belly,
## throat and rump patch, dark stockings); creature.gdshader adds the fur grain on top.
## Part ids and creature facing match life_kit.gd (-Z forward, +Y up).

const BODY := 0.0
const HEAD := 1.0
const LEG_FR := 4.0
const LEG_FL := 5.0
const LEG_BR := 6.0
const LEG_BL := 7.0
const TAIL := 8.0


## Catmull-Rom resample of keys [Vector3 pos, rx, ry] to n sections: [pts, rx, ry].
static func curve(keys: Array, n: int, s: float) -> Array:
	var pts := PackedVector3Array()
	var rx := PackedFloat32Array()
	var ry := PackedFloat32Array()
	var k := keys.size()
	for j in n:
		var f := float(j) / float(n - 1) * float(k - 1)
		var i := mini(int(f), k - 2)
		var t := f - float(i)
		var a: Array = keys[maxi(i - 1, 0)]
		var b: Array = keys[i]
		var c: Array = keys[i + 1]
		var d: Array = keys[mini(i + 2, k - 1)]
		pts.append((b[0] as Vector3).cubic_interpolate(c[0], a[0], d[0], t) * s)
		var ra := Vector2(a[1], a[2])
		var rb := Vector2(b[1], b[2])
		var rc := Vector2(c[1], c[2])
		var rd := Vector2(d[1], d[2])
		var r := rb.cubic_interpolate(rc, ra, rd, t) * s
		rx.append(maxf(r.x, 0.0))
		ry.append(maxf(r.y, 0.0))
	return [pts, rx, ry]


static func key(x: float, y: float, z: float, rx: float, ry: float) -> Array:
	return [Vector3(x, y, z), rx, ry]


static func loft(cm, keys: Array, s: float, n: int, sides: int, col: Color, colfn := Callable(), part := 0.0, ref := Vector3.UP, bone := 0.0, lumps := 0.012) -> void:
	var c := curve(keys, n, s)
	cm.loft(c[0], c[1], c[2], sides, col, colfn, bone, lumps, part, ref)


## Region colouring for a coat: the back darker (a narrow dorsal line), the underside pale, an optional
## pale rump patch (t >= rump_t), pale throat (t <= throat_t on the underside), and `leg_from`.. for limbs.
static func coat_fn(coat: Color, dorsal: Color, belly: Color, rump: Color, rump_t := 2.0, throat_t := -1.0, throat: Color = Color.WHITE) -> Callable:
	return func(t: float, up: float, _side: float) -> Color:
		var c := coat
		c = c.lerp(dorsal, smoothstep(0.45, 0.92, up))
		c = c.lerp(belly, smoothstep(-0.2, -0.75, up))
		if rump_t < 1.5:
			c = c.lerp(rump, smoothstep(rump_t, rump_t + 0.08, t) * (1.0 - smoothstep(0.2, 0.75, up)))
		if throat_t > 0.0:
			c = c.lerp(throat, smoothstep(throat_t, throat_t - 0.2, t) * smoothstep(-0.1, -0.7, up))
		return c


## A leg whose colour runs coat -> dark stockings from section fraction `dark_t` on.
static func leg_fn(coat: Color, dark: Color, dark_t: float) -> Callable:
	return func(t: float, _up: float, _side: float) -> Color:
		return coat.lerp(dark, smoothstep(dark_t, dark_t + 0.12, t))


static func hoof(cm, x: float, z: float, s: float, part: float, col: Color, w := 0.026) -> void:
	loft(cm, [key(x, 0.085, z + 0.004, w * 0.82, w * 0.9), key(x, 0.04, z - 0.006, w, w * 1.3), key(x, 0.0, z - 0.024, w * 1.05, w * 1.5)],
		s, 5, 9, col, Callable(), part, Vector3.BACK, 1.0, 0.0)


# --- deer / doe / stag / elk -------------------------------------------------------------------

## antler: 0 doe, 1 red stag, 2 elk (palmate). `s` scales everything (elk = 1.75).
static func deer(cm, s: float, antler: int) -> void:
	var elk := antler == 2
	var coat := Color(0.44, 0.24, 0.11) if not elk else Color(0.30, 0.18, 0.1)
	var dorsal := coat.darkened(0.55)
	var belly := Color(0.66, 0.5, 0.34) if not elk else Color(0.5, 0.4, 0.28)
	var rump := Color(0.78, 0.66, 0.47)
	var throat := Color(0.74, 0.62, 0.44)
	var leg := Color(0.2, 0.11, 0.06)
	var hoofc := Color(0.05, 0.04, 0.035)
	var mane := Color(0.2, 0.11, 0.06)
	var thick := 1.22 if antler > 0 else 1.0
	# trunk: the barrel chest deepest behind the elbow, a tucked waist, a rising haunch
	loft(cm, [key(0, 0.97, -0.52, 0.1, 0.17), key(0, 0.985, -0.43, 0.16, 0.26), key(0, 1.0, -0.26, 0.19, 0.295),
		key(0, 1.0, -0.02, 0.195, 0.285), key(0, 1.015, 0.2, 0.17, 0.235), key(0, 1.03, 0.38, 0.19, 0.255),
		key(0, 1.02, 0.52, 0.15, 0.22), key(0, 1.0, 0.62, 0.09, 0.14), key(0, 0.98, 0.68, 0.025, 0.05)],
		s, 22, 16, coat, coat_fn(coat, dorsal, belly, rump, 0.84), BODY)
	# the short white-rumped tail
	loft(cm, [key(0, 1.07, 0.66, 0.035, 0.05), key(0, 1.03, 0.71, 0.032, 0.05), key(0, 0.97, 0.725, 0.012, 0.03)],
		s, 5, 7, rump, Callable(), TAIL, Vector3.BACK)
	for side: float in [1.0, -1.0]:
		var x := 0.12 * side
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		# foreleg: shoulder, forearm, knee, cannon, fetlock, pastern
		var fl := [key(x * 0.85, 0.93, -0.36, 0.055, 0.09), key(x * 1.0, 0.82, -0.36, 0.07, 0.105), key(x, 0.6, -0.362, 0.05, 0.06),
			key(x * 0.98, 0.47, -0.365, 0.042, 0.05), key(x * 0.97, 0.37, -0.365, 0.026, 0.03), key(x * 0.97, 0.17, -0.365, 0.023, 0.027),
			key(x * 0.97, 0.12, -0.366, 0.028, 0.03), key(x * 0.97, 0.075, -0.372, 0.02, 0.022)]
		loft(cm, fl, s, 14, 9, coat, leg_fn(coat.darkened(0.1), leg, 0.38), fp, Vector3.BACK)
		hoof(cm, x * 0.97, -0.372, s, fp, hoofc)
		# hind leg: thigh, stifle, gaskin to the hock (pointing back), cannon forward-down, fetlock
		var hl := [key(x * 0.85, 0.97, 0.37, 0.07, 0.12), key(x * 1.08, 0.84, 0.4, 0.09, 0.16), key(x, 0.64, 0.46, 0.058, 0.08),
			key(x * 0.97, 0.47, 0.52, 0.04, 0.05), key(x * 0.97, 0.36, 0.5, 0.027, 0.032), key(x * 0.97, 0.17, 0.46, 0.023, 0.027),
			key(x * 0.97, 0.12, 0.452, 0.028, 0.03), key(x * 0.97, 0.075, 0.445, 0.02, 0.022)]
		loft(cm, hl, s, 14, 9, coat, leg_fn(coat.darkened(0.1), leg, 0.42), bp, Vector3.BACK)
		hoof(cm, x * 0.97, 0.445, s, bp, hoofc)
		# the dark inner face of the lower legs
		# head details: eye with a dark rim, cupped ear with a pale inner face
		var ec := Vector3(0.066 * side, 1.5, -0.875) * s
		cm.blob(ec, Vector3(0.027, 0.025, 0.022) * s, Basis.IDENTITY, hoofc, 0.0, 0.0, HEAD, 5, 7)
		cm.blob(ec + Vector3(0.012 * side, 0.0, -0.004) * s, Vector3(0.018, 0.017, 0.015) * s, Basis.IDENTITY, hoofc, 0.0, 0.0, HEAD, 4, 6, 1.0)
		var ear_b := Basis(Vector3.FORWARD, -side * (0.75 if antler == 0 else 0.95)) * Basis(Vector3.RIGHT, -0.35)
		var ear_c := Vector3(0.095 * side, 1.585, -0.82) * s
		var ear_r := Vector3(0.036, 0.09, 0.016) if antler == 0 else Vector3(0.03, 0.072, 0.014)
		cm.blob(ear_c, ear_r * s, ear_b, coat, 0.0, 0.03, HEAD, 6, 10)
		cm.blob(ear_c + ear_b * Vector3(0, 0, -0.008 * s), ear_r * Vector3(0.7, 0.8, 0.5) * s, ear_b, belly, 0.0, 0.0, HEAD, 4, 8)
		if antler == 1:
			antler_stag(cm, side, s)
		elif elk:
			antler_elk(cm, side, s, mane)
	# neck (HEAD pivots at the chest so grazing lowers it all): thick at the shoulder, a pale throat
	var neck := coat_fn(coat, dorsal, belly, rump, 2.0, 0.85, throat)
	loft(cm, [key(0, 1.0, -0.48, 0.12 * thick, 0.19), key(0, 1.12, -0.55, 0.115 * thick, 0.17), key(0, 1.27, -0.64, 0.095 * thick, 0.135),
		key(0, 1.39, -0.76, 0.075 * thick, 0.1), key(0, 1.48, -0.82, 0.062, 0.085)],
		s, 12, 14, coat, neck, HEAD)
	if antler > 0:
		# the rutting stag's shaggy throat: strands hanging from the underside of the neck
		for k in 8:
			var t := float(k) / 7.0
			var root := Vector3(0.0, lerpf(1.0, 1.36, t) - lerpf(0.17, 0.07, t), lerpf(-0.45, -0.77, t)) * s
			var tuft := Vector3(0.012 * sin(float(k) * 2.3), -0.12 + 0.04 * t, -0.03) * s
			cm.tube(PackedVector3Array([root, root + tuft * 0.5, root + tuft]), PackedFloat32Array([0.028 * s, 0.022 * s, 0.0]), 5, mane, 0.0, 0.2, HEAD, Vector2(0.5, 1.0))
	# head: a wedge from poll to muzzle, the pale lip and a dark nose pad
	var head := func(t: float, up: float, _side: float) -> Color:
		var c := coat.lerp(dorsal, smoothstep(0.6, 0.95, up) * 0.6)
		c = c.lerp(belly, smoothstep(-0.2, -0.8, up) * 0.8)
		return c.lerp(belly.lightened(0.1), smoothstep(0.72, 0.95, t))
	loft(cm, [key(0, 1.505, -0.78, 0.056, 0.078), key(0, 1.5, -0.84, 0.07, 0.09), key(0, 1.465, -0.92, 0.056, 0.07),
		key(0, 1.43, -0.99, 0.042, 0.05), key(0, 1.4, -1.05, 0.038, 0.042), key(0, 1.375, -1.082, 0.033, 0.033)],
		s, 12, 12, coat, head, HEAD)
	loft(cm, [key(0, 1.44, -0.88, 0.03, 0.025), key(0, 1.395, -0.97, 0.026, 0.02), key(0, 1.365, -1.05, 0.02, 0.016)],
		s, 5, 8, belly, Callable(), HEAD)
	cm.blob(Vector3(0, 1.38, -1.086) * s, Vector3(0.032, 0.024, 0.016) * s, Basis.IDENTITY, hoofc, 1.0, 0.0, HEAD, 4, 8)


## A red deer stag's antler: beaded beam sweeping up and back, brow, bez and trez tines, a crown.
static func antler_stag(cm, side: float, s: float) -> void:
	var horn := Color(0.46, 0.27, 0.12)
	var tip := Color(0.8, 0.62, 0.38)
	var beam: Array = [Vector3(0.05 * side, 1.575, -0.83), Vector3(0.09 * side, 1.65, -0.825), Vector3(0.16 * side, 1.78, -0.79),
		Vector3(0.22 * side, 1.93, -0.72), Vector3(0.26 * side, 2.08, -0.64), Vector3(0.26 * side, 2.18, -0.59)]
	for i in beam.size():
		beam[i] = (beam[i] as Vector3) * s
	cm.blob(beam[0], Vector3(0.04, 0.025, 0.04) * s, Basis.IDENTITY, horn, 1.0, 0.3, HEAD, 4, 8)
	cm.tube(PackedVector3Array(beam), PackedFloat32Array([0.042 * s, 0.038 * s, 0.033 * s, 0.029 * s, 0.025 * s, 0.021 * s]), 7, horn, 1.0, 0.1, HEAD)
	var tines := [[1, Vector3(0.03, 0.06, -0.2), Vector3(0.02, 0.07, -0.05)], [2, Vector3(0.05, 0.05, -0.17), Vector3(0.0, 0.06, -0.04)],
		[3, Vector3(0.06, 0.06, -0.15), Vector3(0.0, 0.06, -0.03)]]
	for tn: Array in tines:
		var b: Vector3 = beam[int(tn[0])]
		var d1: Vector3 = tn[1]
		var d2: Vector3 = tn[2]
		var m: Vector3 = b + Vector3(d1.x * side, d1.y, d1.z) * s
		var e: Vector3 = m + Vector3(d2.x * side, d2.y, d2.z) * s
		cm.tube(PackedVector3Array([b, m, e]), PackedFloat32Array([0.026 * s, 0.018 * s, 0.0]), 5, horn, 1.0, 0.05, HEAD)
		cm.tube(PackedVector3Array([m.lerp(e, 0.4), e]), PackedFloat32Array([0.01 * s, 0.0]), 4, tip, 1.0, 0.0, HEAD)
	var top: Vector3 = beam[5]
	for d: Vector3 in [Vector3(0.0, 0.13, -0.06), Vector3(0.06, 0.11, 0.0), Vector3(-0.02, 0.1, 0.07)]:
		var e: Vector3 = top + Vector3(d.x * side, d.y, d.z) * s
		cm.tube(PackedVector3Array([top, e]), PackedFloat32Array([0.016 * s, 0.0]), 5, horn, 1.0, 0.05, HEAD)
		cm.tube(PackedVector3Array([top.lerp(e, 0.55), e]), PackedFloat32Array([0.008 * s, 0.0]), 4, tip, 1.0, 0.0, HEAD)


static func antler_elk(cm, side: float, s: float, _mane: Color) -> void:
	var horn := Color(0.46, 0.28, 0.13)
	var tip := Color(0.8, 0.62, 0.38)
	var beam := PackedVector3Array([Vector3(0.05 * side, 1.575, -0.83), Vector3(0.16 * side, 1.65, -0.77), Vector3(0.32 * side, 1.75, -0.67), Vector3(0.46 * side, 1.89, -0.59)])
	for i in beam.size():
		beam[i] = beam[i] * s
	cm.tube(beam, PackedFloat32Array([0.042 * s, 0.036 * s, 0.03 * s, 0.025 * s]), 7, horn, 1.0, 0.08, HEAD)
	cm.blob(Vector3(0.48 * side, 1.95, -0.56) * s, Vector3(0.2, 0.14, 0.03) * s, Basis(Vector3.FORWARD, side * 0.5) * Basis(Vector3.UP, side * 0.35), horn, 1.0, 0.1, HEAD, 6, 12)
	for k in 7:
		var t0 := Vector3((0.32 + 0.055 * k) * side, 1.98 + 0.05 * sin(float(k)), -0.6 + 0.012 * k) * s
		cm.tube(PackedVector3Array([t0, t0 + Vector3(0.03 * side, 0.15, 0.0) * s]), PackedFloat32Array([0.022 * s, 0.0]), 4, tip, 1.0, 0.0, HEAD)
	cm.tube(PackedVector3Array([Vector3(0.1 * side, 1.63, -0.83) * s, Vector3(0.13 * side, 1.7, -0.99) * s]), PackedFloat32Array([0.022 * s, 0.0]), 4, horn, 1.0, 0.0, HEAD)


# --- fox -----------------------------------------------------------------------------------------

static func fox(cm) -> void:
	var red := Color(0.84, 0.36, 0.08)
	var dark := red.darkened(0.3)
	var white := Color(0.9, 0.87, 0.8)
	var cream := Color(0.82, 0.66, 0.46)
	var black := Color(0.05, 0.04, 0.035)
	loft(cm, [key(0, 0.34, -0.2, 0.05, 0.075), key(0, 0.345, -0.13, 0.072, 0.1), key(0, 0.34, 0.0, 0.078, 0.1), key(0, 0.335, 0.12, 0.062, 0.088),
		key(0, 0.34, 0.22, 0.07, 0.092), key(0, 0.33, 0.29, 0.04, 0.055), key(0, 0.325, 0.32, 0.01, 0.02)],
		1.0, 14, 12, red, coat_fn(red, dark, cream, red, 2.0, -1.0), BODY)
	for side: float in [1.0, -1.0]:
		var x := 0.055 * side
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		var fl := [key(x * 0.7, 0.31, -0.17, 0.034, 0.055), key(x * 1.05, 0.25, -0.172, 0.036, 0.05), key(x, 0.2, -0.178, 0.026, 0.034), key(x, 0.15, -0.185, 0.02, 0.022),
			key(x, 0.07, -0.19, 0.016, 0.018), key(x, 0.025, -0.195, 0.017, 0.019)]
		loft(cm, fl, 1.0, 12, 8, red, leg_fn(red, black, 0.4), fp, Vector3.BACK)
		cm.blob(Vector3(x, 0.012, -0.212), Vector3(0.02, 0.012, 0.03), Basis.IDENTITY, black, 0.0, 0.0, fp, 4, 7)
		var hl := [key(x * 0.7, 0.32, 0.17, 0.04, 0.07), key(x * 1.12, 0.26, 0.165, 0.05, 0.085), key(x * 1.0, 0.2, 0.155, 0.034, 0.055), key(x, 0.15, 0.2, 0.022, 0.03),
			key(x, 0.07, 0.19, 0.016, 0.019), key(x, 0.025, 0.19, 0.017, 0.019)]
		loft(cm, hl, 1.0, 12, 8, red, leg_fn(red, black, 0.45), bp, Vector3.BACK)
		cm.blob(Vector3(x, 0.012, 0.172), Vector3(0.02, 0.012, 0.03), Basis.IDENTITY, black, 0.0, 0.0, bp, 4, 7)
		# ears: pointed, black backs, cream insides; amber eyes; white cheeks
		cm.tube(PackedVector3Array([Vector3(0.036 * side, 0.488, -0.318), Vector3(0.05 * side, 0.55, -0.31), Vector3(0.064 * side, 0.62, -0.3)]),
			PackedFloat32Array([0.044, 0.03, 0.0]), 6, black, 0.0, 0.02, HEAD, Vector2(1.0, 0.4))
		cm.tube(PackedVector3Array([Vector3(0.038 * side, 0.49, -0.327), Vector3(0.054 * side, 0.57, -0.32)]),
			PackedFloat32Array([0.03, 0.0]), 4, cream, 0.0, 0.0, HEAD, Vector2(1.0, 0.3))
		cm.blob(Vector3(0.05 * side, 0.43, -0.365), Vector3(0.03, 0.028, 0.045), Basis.IDENTITY, white, 0.0, 0.05, HEAD, 5, 8)
		cm.blob(Vector3(0.036 * side, 0.466, -0.372), Vector3(0.012, 0.01, 0.009), Basis.IDENTITY, black, 0.0, 0.0, HEAD, 3, 5, 1.0)
	# neck and the head: broad cheeks, a long tapering muzzle with a black nose
	var neck := coat_fn(red, dark, white, red, 2.0, 0.9, white)
	loft(cm, [key(0, 0.35, -0.16, 0.06, 0.085), key(0, 0.405, -0.23, 0.05, 0.07), key(0, 0.44, -0.29, 0.045, 0.055)], 1.0, 6, 10, red, neck, HEAD)
	var head := func(t: float, up: float, side: float) -> Color:
		var c := red.lerp(dark, smoothstep(0.7, 1.0, up) * 0.4)
		c = c.lerp(white, smoothstep(-0.15, -0.6, up))
		c = c.lerp(white, smoothstep(0.4, 0.6, t) * smoothstep(0.2, -0.3, up))
		return c.lerp(black, smoothstep(0.93, 1.0, t))
	loft(cm, [key(0, 0.455, -0.29, 0.045, 0.05), key(0, 0.452, -0.335, 0.056, 0.054), key(0, 0.442, -0.385, 0.04, 0.04), key(0, 0.43, -0.44, 0.025, 0.026),
		key(0, 0.42, -0.488, 0.013, 0.014), key(0, 0.418, -0.5, 0.009, 0.009)], 1.0, 10, 10, red, head, HEAD)
	# the brush: thick, a white tip
	var tail := func(t: float, up: float, _side: float) -> Color:
		return red.darkened(0.08).lerp(dark, smoothstep(0.5, 1.0, up) * 0.4).lerp(white, smoothstep(0.8, 0.92, t))
	loft(cm, [key(0, 0.335, 0.26, 0.028, 0.03), key(0, 0.32, 0.34, 0.06, 0.06), key(0, 0.27, 0.46, 0.078, 0.075), key(0, 0.22, 0.56, 0.06, 0.06),
		key(0, 0.195, 0.64, 0.028, 0.03), key(0, 0.185, 0.675, 0.004, 0.006)], 1.0, 10, 10, red, tail, TAIL, Vector3.UP, 0.0, 0.03)


# --- hare ------------------------------------------------------------------------------------------

static func hare(cm) -> void:
	var fur := Color(0.56, 0.37, 0.19)
	var dark := Color(0.3, 0.19, 0.1)
	var belly := Color(0.74, 0.66, 0.54)
	var black := Color(0.07, 0.055, 0.045)
	var white := Color(0.9, 0.88, 0.84)
	loft(cm, [key(0, 0.17, -0.1, 0.045, 0.07), key(0, 0.2, -0.03, 0.062, 0.085), key(0, 0.225, 0.07, 0.07, 0.095), key(0, 0.2, 0.15, 0.07, 0.09),
		key(0, 0.17, 0.2, 0.04, 0.06), key(0, 0.155, 0.225, 0.01, 0.02)], 1.0, 12, 12, fur, coat_fn(fur, dark, belly, fur, 2.0), BODY, Vector3.UP, 0.0, 0.015)
	for side: float in [1.0, -1.0]:
		var x := 0.045 * side
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		loft(cm, [key(x * 0.8, 0.17, -0.1, 0.03, 0.045), key(x * 0.95, 0.12, -0.105, 0.022, 0.03), key(x * 0.95, 0.07, -0.11, 0.015, 0.018), key(x * 0.9, 0.025, -0.12, 0.012, 0.014)], 1.0, 8, 7, fur, leg_fn(fur, belly, 0.5), fp, Vector3.BACK)
		# the haunch, a short stifle, a long flat foot (the hock back, the foot forward)
		loft(cm, [key(x * 0.8, 0.2, 0.13, 0.035, 0.07), key(x * 1.2, 0.16, 0.14, 0.047, 0.09), key(x * 1.05, 0.1, 0.17, 0.034, 0.055), key(x, 0.065, 0.2, 0.02, 0.028),
			key(x * 0.95, 0.03, 0.15, 0.014, 0.04), key(x * 0.95, 0.016, 0.1, 0.014, 0.05)], 1.0, 12, 8, fur, leg_fn(fur, belly, 0.5), bp, Vector3.BACK)
		# head details: big side eyes and tall black-tipped ears laid half back
		cm.blob(Vector3(0.037 * side, 0.285, -0.19), Vector3(0.016, 0.017, 0.014), Basis.IDENTITY, black, 0.0, 0.0, HEAD, 4, 6)
		cm.blob(Vector3(0.042 * side, 0.285, -0.194), Vector3(0.011, 0.012, 0.01), Basis.IDENTITY, black, 0.0, 0.0, HEAD, 3, 5, 1.0)
		var ear := func(t: float, _up: float, _sd: float) -> Color:
			return fur.lerp(belly, 0.0).lerp(black, smoothstep(0.78, 0.95, t))
		loft(cm, [key(0.018 * side, 0.305, -0.16, 0.008, 0.018), key(0.028 * side, 0.37, -0.13, 0.008, 0.028), key(0.036 * side, 0.43, -0.1, 0.007, 0.026),
			key(0.04 * side, 0.475, -0.075, 0.005, 0.014), key(0.04 * side, 0.5, -0.062, 0.001, 0.003)], 1.0, 9, 7, fur, ear, HEAD, Vector3.BACK)
	loft(cm, [key(0, 0.2, -0.1, 0.042, 0.06), key(0, 0.235, -0.14, 0.04, 0.052)], 1.0, 4, 9, fur, Callable(), HEAD)
	var head := func(t: float, up: float, _side: float) -> Color:
		var c := fur.lerp(dark, smoothstep(0.6, 0.95, up) * 0.5)
		return c.lerp(belly, smoothstep(0.6, 0.95, t) * 0.7 + smoothstep(-0.2, -0.8, up) * 0.6)
	loft(cm, [key(0, 0.285, -0.145, 0.035, 0.045), key(0, 0.28, -0.185, 0.044, 0.049), key(0, 0.268, -0.225, 0.03, 0.033), key(0, 0.257, -0.255, 0.019, 0.02),
		key(0, 0.252, -0.268, 0.012, 0.013)], 1.0, 8, 10, fur, head, HEAD)
	cm.blob(Vector3(0, 0.253, -0.272), Vector3(0.014, 0.011, 0.008), Basis.IDENTITY, black, 1.0, 0.0, HEAD, 3, 6)
	cm.blob(Vector3(0, 0.2, 0.235), Vector3(0.036, 0.04, 0.03), Basis.IDENTITY, white, 0.0, 0.06, TAIL, 5, 8)


# --- boar ------------------------------------------------------------------------------------------

static func boar(cm) -> void:
	var coat := Color(0.2, 0.13, 0.08)
	var bristle := Color(0.38, 0.27, 0.15)
	var dark := Color(0.09, 0.07, 0.06)
	var belly := Color(0.33, 0.24, 0.16)
	var tusk := Color(0.86, 0.82, 0.7)
	var snout := Color(0.3, 0.2, 0.17)
	var body := func(t: float, up: float, _side: float) -> Color:
		var c := coat.lerp(belly, smoothstep(-0.1, -0.8, up))
		return c.lerp(bristle, smoothstep(0.6, 1.0, up) * 0.8).lerp(dark, smoothstep(0.7, 0.2, t) * 0.0)
	loft(cm, [key(0, 0.54, -0.42, 0.14, 0.21), key(0, 0.6, -0.3, 0.215, 0.31), key(0, 0.62, -0.1, 0.225, 0.31), key(0, 0.58, 0.12, 0.2, 0.275),
		key(0, 0.54, 0.32, 0.17, 0.235), key(0, 0.5, 0.48, 0.115, 0.17), key(0, 0.47, 0.57, 0.03, 0.06)], 1.0, 18, 14, coat, body, BODY, Vector3.UP, 0.0, 0.02)
	# the bristle ridge along the spine, shaggiest at the shoulders
	for k in 22:
		var t := float(k) / 21.0
		var z := lerpf(-0.55, 0.36, t)
		var y := 0.87 + 0.04 * sin(minf(t * 1.4, 1.0) * PI) - 0.17 * t * t
		var lenb := lerpf(0.13, 0.06, t)
		cm.tube(PackedVector3Array([Vector3(0, y - 0.07, z), Vector3(0, y + lenb * 0.5, z + 0.025), Vector3(0, y + lenb, z + 0.07)]), PackedFloat32Array([0.03, 0.02, 0.0]), 5, bristle.darkened(0.15 * t), 0.0, 0.0, BODY, Vector2(0.55, 1.0))
	loft(cm, [key(0, 0.5, 0.56, 0.012, 0.012), key(0, 0.5, 0.62, 0.01, 0.01), key(0, 0.44, 0.68, 0.01, 0.01)], 1.0, 3, 5, coat, Callable(), TAIL)
	cm.tube(PackedVector3Array([Vector3(0, 0.44, 0.67), Vector3(0, 0.4, 0.71)]), PackedFloat32Array([0.016, 0.0]), 4, dark, 0.0, 0.1, TAIL, Vector2(0.4, 1.0))
	for side: float in [1.0, -1.0]:
		var x := 0.135 * side
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		var fl := [key(x * 0.8, 0.6, -0.28, 0.07, 0.1), key(x * 1.0, 0.5, -0.285, 0.085, 0.12), key(x, 0.4, -0.29, 0.06, 0.08), key(x * 0.98, 0.3, -0.295, 0.042, 0.05), key(x * 0.97, 0.16, -0.3, 0.033, 0.038), key(x * 0.97, 0.08, -0.305, 0.036, 0.04)]
		loft(cm, fl, 1.0, 14, 9, coat, leg_fn(coat, dark, 0.5), fp, Vector3.BACK)
		hoof(cm, x * 0.97, -0.31, 1.0, fp, dark, 0.034)
		var hl := [key(x * 0.8, 0.6, 0.34, 0.08, 0.12), key(x * 1.08, 0.5, 0.36, 0.1, 0.15), key(x * 1.0, 0.4, 0.4, 0.07, 0.09), key(x, 0.31, 0.42, 0.045, 0.055), key(x * 0.97, 0.17, 0.4, 0.034, 0.04), key(x * 0.97, 0.08, 0.395, 0.036, 0.04)]
		loft(cm, hl, 1.0, 14, 9, coat, leg_fn(coat, dark, 0.5), bp, Vector3.BACK)
		hoof(cm, x * 0.97, 0.395, 1.0, bp, dark, 0.034)
		# small ears, small eyes, curved tusks
		cm.tube(PackedVector3Array([Vector3(0.085 * side, 0.745, -0.62), Vector3(0.12 * side, 0.81, -0.6), Vector3(0.125 * side, 0.86, -0.58)]), PackedFloat32Array([0.045, 0.03, 0.0]), 6, coat, 0.0, 0.03, HEAD, Vector2(1.0, 0.4))
		cm.blob(Vector3(0.09 * side, 0.63, -0.77), Vector3(0.012, 0.012, 0.011), Basis.IDENTITY, dark, 0.0, 0.0, HEAD, 3, 5, 1.0)
		cm.tube(PackedVector3Array([Vector3(0.05 * side, 0.4, -0.93), Vector3(0.085 * side, 0.4, -0.97), Vector3(0.1 * side, 0.46, -0.99), Vector3(0.095 * side, 0.52, -0.985)]),
			PackedFloat32Array([0.016, 0.014, 0.01, 0.0]), 5, tusk, 1.0, 0.0, HEAD)
	# the head: a heavy wedge sloping to a long snout and a flat disc nose
	var head := func(t: float, up: float, _side: float) -> Color:
		var c := coat.lerp(bristle, smoothstep(0.7, 1.0, up) * 0.5).lerp(belly, smoothstep(-0.2, -0.8, up))
		return c.lerp(snout, smoothstep(0.7, 0.95, t))
	loft(cm, [key(0, 0.58, -0.32, 0.16, 0.24), key(0, 0.58, -0.5, 0.15, 0.22), key(0, 0.55, -0.66, 0.125, 0.17), key(0, 0.48, -0.8, 0.095, 0.12),
		key(0, 0.42, -0.93, 0.07, 0.08), key(0, 0.39, -1.03, 0.058, 0.062)], 1.0, 12, 12, coat, head, HEAD)
	cm.blob(Vector3(0, 0.385, -1.05), Vector3(0.062, 0.058, 0.02), Basis.IDENTITY, dark, 1.0, 0.1, HEAD, 5, 9)
