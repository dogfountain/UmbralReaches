extends RefCounted
## The village's own animals: a dog (floppy ears, a broad blunt muzzle, a curled tail, a saddle on a tan coat) and a cat (a round head, upright
## ears, a long tail carried up, white socks and chest on a grey tabby), each lofted like the wildlife's fox and in the fox's frame (the same hips
## and head pivot, so the creature shader's gait, head turn and tail sway are the fox's numbers). Built once and cached (GenCache, keyed on this
## file); pets.gd draws them as two small MultiMeshes. Part ids and facing as life_beast_mesh.gd (-Z forward, +Y up).

const Beast := preload("res://core/life/wildlife/life_beast_mesh.gd")

const BODY := 0.0
const HEAD := 1.0
const LEG_FR := 4.0
const LEG_FL := 5.0
const LEG_BR := 6.0
const LEG_BL := 7.0
const TAIL := 8.0


static func dog(cm) -> void:
	_pet(cm, true)


static func cat(cm) -> void:
	_pet(cm, false)


static func _k(x: float, y: float, z: float, rx: float, ry: float) -> Array:
	return Beast.key(x, y, z, rx, ry)


static func _pet(cm, dog: bool) -> void:
	var coat := Color(0.55, 0.4, 0.24) if dog else Color(0.4, 0.38, 0.36)
	var dark := coat.darkened(0.38)
	var pale := Color(0.84, 0.74, 0.58) if dog else Color(0.88, 0.86, 0.82)
	var black := Color(0.05, 0.04, 0.035)
	var w := 1.0 if dog else 0.84                  # a cat's trunk and limbs are slimmer
	Beast.loft(cm, [_k(0, 0.335, -0.2, 0.055 * w, 0.08 * w), _k(0, 0.35, -0.14, 0.085 * w, 0.11 * w), _k(0, 0.345, -0.03, 0.085 * w, 0.105 * w),
		_k(0, 0.34, 0.07, 0.075 * w, 0.095 * w), _k(0, 0.34, 0.16, 0.085 * w, 0.1 * w), _k(0, 0.335, 0.24, 0.07 * w, 0.085 * w), _k(0, 0.325, 0.31, 0.035, 0.05),
		_k(0, 0.32, 0.34, 0.008, 0.016)], 1.0, 20, 14, coat, Beast.coat_fn(coat, dark, pale, coat, 2.0, 0.3, pale), BODY)
	var sock := func(t: float, _up: float, _sd: float) -> Color:
		return coat.lerp(pale if not dog else dark, smoothstep(0.55 if not dog else 0.45, 0.7, t))
	for side: float in [1.0, -1.0]:
		var x := 0.05 * side
		var fp := LEG_FR if side > 0.0 else LEG_FL
		var bp := LEG_BR if side > 0.0 else LEG_BL
		var lw := 1.35 if dog else 1.0
		Beast.loft(cm, [_k(x * 0.55, 0.32, -0.16, 0.034 * lw, 0.05 * lw), _k(x * 0.9, 0.25, -0.17, 0.03 * lw, 0.04 * lw), _k(x, 0.17, -0.178, 0.022 * lw, 0.028 * lw),
			_k(x, 0.09, -0.186, 0.017 * lw, 0.02 * lw), _k(x, 0.04, -0.19, 0.016 * lw, 0.019 * lw)], 1.0, 12, 8, coat, sock, fp, Vector3.BACK)
		Beast.loft(cm, [_k(x, 0.04, -0.188, 0.017, 0.022), _k(x, 0.017, -0.2, 0.019, 0.028), _k(x, 0.006, -0.225, 0.015, 0.022)], 1.0, 5, 8, pale if not dog else dark, Callable(), fp, Vector3.UP)
		Beast.loft(cm, [_k(x * 0.5, 0.32, 0.17, 0.034 * lw, 0.055 * lw), _k(x * 0.85, 0.27, 0.175, 0.034 * lw, 0.05 * lw), _k(x, 0.2, 0.17, 0.025 * lw, 0.035 * lw),
			_k(x, 0.14, 0.2, 0.018 * lw, 0.022 * lw), _k(x, 0.08, 0.195, 0.016 * lw, 0.019 * lw), _k(x, 0.04, 0.19, 0.016 * lw, 0.019 * lw)], 1.0, 12, 8, coat, sock, bp, Vector3.BACK)
		Beast.loft(cm, [_k(x, 0.04, 0.188, 0.017, 0.022), _k(x, 0.017, 0.178, 0.019, 0.028), _k(x, 0.006, 0.153, 0.015, 0.022)], 1.0, 5, 8, pale if not dog else dark, Callable(), bp, Vector3.UP)
		var ear := func(t: float, up: float, _sd: float) -> Color:
			return (dark if dog else coat).lerp(Color(0.62, 0.45, 0.42), smoothstep(0.0, -0.8, up) * (0.0 if dog else 0.5)).lerp(dark, smoothstep(0.8, 0.95, t) * (0.0 if dog else 0.8))
		if dog:       # floppy: from the crown, out and down beside the cheek
			Beast.loft(cm, [_k(0.04 * side, 0.49, -0.318, 0.03, 0.026), _k(0.07 * side, 0.475, -0.312, 0.034, 0.02), _k(0.09 * side, 0.43, -0.305, 0.03, 0.014),
				_k(0.095 * side, 0.39, -0.3, 0.012, 0.006)], 1.0, 10, 8, dark, ear, HEAD, Vector3(0.7 * side, 0, 0.7))
		else:         # upright and pointed
			Beast.loft(cm, [_k(0.04 * side, 0.475, -0.322, 0.032, 0.026), _k(0.05 * side, 0.53, -0.318, 0.026, 0.02), _k(0.056 * side, 0.58, -0.314, 0.012, 0.008),
				_k(0.058 * side, 0.605, -0.312, 0.003, 0.002)], 1.0, 10, 8, coat, ear, HEAD, Vector3(0.3 * side, 0, 0.95))
		cm.blob(Vector3(0.036 * side, 0.468, -0.374), Vector3(0.012, 0.01, 0.009), Basis.IDENTITY, black, 0.0, 0.0, HEAD, 3, 5, 1.0)
	Beast.loft(cm, [_k(0, 0.35, -0.16, 0.06 * w, 0.085 * w), _k(0, 0.405, -0.23, 0.054 * w, 0.074 * w), _k(0, 0.44, -0.29, 0.05, 0.062)], 1.0, 6, 12, coat,
		Beast.coat_fn(coat, dark, pale, coat, 2.0, 0.9, pale), HEAD)
	var head := func(t: float, up: float, _side: float) -> Color:
		var c := coat.lerp(dark, smoothstep(0.7, 1.0, up) * (0.4 if dog else 0.25))
		c = c.lerp(pale, smoothstep(-0.2, -0.8, up) * 0.8)
		return c.lerp(black, smoothstep(0.9, 0.99, t) * (1.0 if dog else 0.5))
	if dog:
		Beast.loft(cm, [_k(0, 0.455, -0.29, 0.058, 0.056), _k(0, 0.45, -0.335, 0.074, 0.064), _k(0, 0.435, -0.385, 0.054, 0.047), _k(0, 0.426, -0.425, 0.038, 0.035),
			_k(0, 0.42, -0.452, 0.03, 0.028)], 1.0, 12, 12, coat, head, HEAD)
		cm.blob(Vector3(0, 0.425, -0.456), Vector3(0.022, 0.016, 0.014), Basis.IDENTITY, black, 1.0, 0.0, HEAD, 4, 7)
		Beast.loft(cm, [_k(0, 0.335, 0.26, 0.024, 0.026), _k(0, 0.36, 0.33, 0.021, 0.023), _k(0, 0.43, 0.38, 0.019, 0.021), _k(0, 0.5, 0.365, 0.013, 0.013), _k(0, 0.53, 0.33, 0.004, 0.004)],
			1.0, 12, 8, coat, Callable(), TAIL, Vector3.RIGHT)
	else:
		Beast.loft(cm, [_k(0, 0.45, -0.29, 0.05, 0.05), _k(0, 0.45, -0.33, 0.062, 0.058), _k(0, 0.44, -0.365, 0.05, 0.045), _k(0, 0.43, -0.39, 0.026, 0.026)], 1.0, 12, 12, coat, head, HEAD)
		cm.blob(Vector3(0, 0.428, -0.394), Vector3(0.012, 0.009, 0.008), Basis.IDENTITY, Color(0.62, 0.4, 0.4), 1.0, 0.0, HEAD, 4, 7)
		Beast.loft(cm, [_k(0, 0.33, 0.26, 0.02, 0.022), _k(0, 0.32, 0.36, 0.024, 0.026), _k(0, 0.36, 0.46, 0.022, 0.024), _k(0, 0.44, 0.52, 0.02, 0.02), _k(0, 0.5, 0.5, 0.014, 0.014),
			_k(0, 0.52, 0.46, 0.004, 0.006)], 1.0, 14, 8, coat.darkened(0.1), Callable(), TAIL, Vector3.RIGHT)
