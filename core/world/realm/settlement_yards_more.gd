extends RefCounted
## More scenes for the towns' yards (settlement_yards.gd calls `scene`): wells, fences and workshops in three seeded variants each, plus
## a second washing line (blankets) and a second pen (geese). Kit boxes, tubes and quads from the same materials the other scenes use,
## so they merge into the cell's existing meshes (no new draw call); built inside the yards' GenCache'd kit. No class_name.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

const KINDS := ["well", "fence", "workshop", "linen", "geese"]


## The variant (0-2) a spot gets: a hash of where it is, so the same yard always looks the same.
static func variant(o: Vector3) -> int:
	return absi(hash(Vector3i((o * 3.0).round()))) % 3


static func scene(k: WK, kind: String, o: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var v := variant(o)
	match kind:
		"well":
			_well(k, o, b, v)
		"fence":
			_fence(k, o, b, v)
		"workshop":
			_workshop(k, o, b, v)
		"linen":
			_linen(k, o, b, v)
		_:
			_geese(k, o, b, v)


static func _well(k: WK, o: Vector3, b: Basis, v: int) -> void:
	for i in 10:                                                      # the curb: a ring of stones round dark water
		var a := TAU * float(i) / 10.0
		k.kit.box("stone_big", o + b * Vector3(cos(a) * 0.85, 0.45, sin(a) * 0.85), Vector3(0.5, 0.9, 0.34), b * Basis(Vector3.UP, -a + PI * 0.5), true, 0.82 + 0.1 * float(i % 3))
	k.kit.box("dark", o + Vector3.UP * 0.5, Vector3(1.3, 0.05, 1.3), b, false, 0.4)
	match v:
		0:                                                            # a roofed well with a windlass
			for s: float in [-1.0, 1.0]:
				k.tube("wood_big", o + b * Vector3(s * 1.0, 0.0, 0.0), o + b * Vector3(s * 1.0, 2.3, 0.0), 0.07, 0.06, 5, false, 0.7)
				k.kit.box("wood_big", o + b * Vector3(s * 0.55, 2.55, 0.0), Vector3(1.4, 0.07, 1.5), b * Basis(Vector3.BACK, s * 0.5), false, 0.65)
			k.beam("wood_big", o + b * Vector3(-1.0, 1.7, 0.0), o + b * Vector3(1.0, 1.7, 0.0), 0.09, 0.09, false, 0.65)
			Dress.rope(k, o + b * Vector3(0.0, 1.7, 0.0), o + b * Vector3(0.0, 0.75, 0.0), 0.0, 0.015, "wood_big", 3)
			k.tube("wood_big", o + b * Vector3(0.0, 0.5, 0.0), o + b * Vector3(0.0, 0.8, 0.0), 0.12, 0.1, 6, false, 0.7)
		1:                                                            # a sweep: a forked post and a long pole, a stone to balance it
			k.tube("wood_big", o + b * Vector3(1.3, 0.0, 0.0), o + b * Vector3(1.3, 2.9, 0.0), 0.09, 0.07, 5, false, 0.7)
			k.beam("wood_big", o + b * Vector3(2.4, 2.1, 0.0), o + b * Vector3(-0.9, 3.3, 0.0), 0.07, 0.07, false, 0.65)
			k.kit.box("stone_big", o + b * Vector3(2.4, 1.8, 0.0), Vector3(0.4, 0.4, 0.4), b, false, 0.8)
			Dress.rope(k, o + b * Vector3(-0.8, 3.25, 0.0), o + b * Vector3(-0.5, 0.9, 0.0), 0.1, 0.015, "wood_big", 4)
		_:                                                            # an open curb with a lid of planks half off and a bucket
			for i in 4:
				k.kit.box("wood_big", o + b * Vector3(-0.3 + 0.3 * float(i), 0.95, 0.0), Vector3(0.26, 0.06, 1.5), b * Basis(Vector3.UP, 0.1 * float(i % 2)), false, 0.7)
			Dress.barrel(k, o + b * Vector3(1.4, 0.0, 0.6), 0.0, 0.5)
	Dress.crate(k, o + b * Vector3(-1.5, 0.0, 1.0), 0.4, 0.5)


static func _fence(k: WK, o: Vector3, b: Basis, v: int) -> void:
	var n := 7
	for i in n:
		var x := -3.0 + 1.0 * float(i)
		var lean := Basis(Vector3.RIGHT, 0.03 * float((i * 5) % 3 - 1))
		match v:
			0:                                                        # post and two rails
				k.kit.box("wood_big", o + b * Vector3(x, 0.55, 0.0), Vector3(0.12, 1.1, 0.12), b * lean, i % 3 == 0, 0.7)
				if i < n - 1:
					for y: float in [0.4, 0.85]:
						k.kit.box("wood_big", o + b * Vector3(x + 0.5, y, 0.0), Vector3(1.0, 0.07, 0.06), b, false, 0.68)
			1:                                                        # wattle: stakes woven with withies in courses
				k.kit.box("wood_big", o + b * Vector3(x, 0.6, 0.0), Vector3(0.06, 1.2, 0.06), b * lean, false, 0.62)
				if i < n - 1:
					for j in 4:
						k.kit.box("wood_big", o + b * Vector3(x + 0.5, 0.25 + 0.27 * float(j), 0.04 * (1.0 if (i + j) % 2 == 0 else -1.0)), Vector3(1.0, 0.07, 0.04), b, false, 0.6 + 0.08 * float(j % 2))
			_:                                                        # pickets with pointed heads between posts, a gate leaf ajar
				if i % 3 == 0:
					k.kit.box("wood_big", o + b * Vector3(x, 0.65, 0.0), Vector3(0.14, 1.3, 0.14), b, i == 0, 0.7)
				if i < n - 1:
					for j in 3:
						var px := x + 0.2 + 0.3 * float(j)
						k.kit.box("chalk", o + b * Vector3(px, 0.5, 0.05), Vector3(0.12, 1.0, 0.03), b, false, 0.82)
						k.kit.box("chalk", o + b * Vector3(px, 1.04, 0.05), Vector3(0.09, 0.12, 0.03), b * Basis(Vector3.BACK, PI * 0.25), false, 0.82)
				if i == 3:
					k.kit.box("wood_big", o + b * Vector3(x + 0.5, 0.6, 0.6), Vector3(0.05, 0.9, 0.9), b * Basis(Vector3.UP, 0.5), false, 0.7)
	if v != 1:
		k.kit.box("cave_moss", o + b * Vector3(-2.5, 0.15, 0.3), Vector3(0.5, 0.3, 0.4), b, false, 0.8)


static func _workshop(k: WK, o: Vector3, b: Basis, v: int) -> void:
	match v:
		0:                                                            # the carpenter: a bench and vice, planks stacked on sticks, a log on trestles
			k.kit.box("wood_big", o + b * Vector3(-1.0, 0.85, 0.0), Vector3(2.0, 0.12, 0.7), b, false, 0.8)
			for s: float in [-1.0, 1.0]:
				k.kit.box("wood_big", o + b * Vector3(-1.0 + s * 0.8, 0.4, 0.0), Vector3(0.12, 0.8, 0.6), b, false, 0.65)
			k.kit.box("iron", o + b * Vector3(-1.8, 0.98, 0.25), Vector3(0.12, 0.14, 0.12), b, false, 0.55)
			for i in 5:
				k.kit.box("wood_big", o + b * Vector3(1.2, 0.08 + 0.1 * float(i), 0.0), Vector3(2.0, 0.07, 0.4), b * Basis(Vector3.UP, 0.04 * float(i % 2)), false, 0.75 + 0.05 * float(i))
			k.tube("wood_big", o + b * Vector3(-0.5, 0.35, 1.3), o + b * Vector3(0.9, 0.35, 1.3), 0.2, 0.2, 7, false, 0.7, Vector2(1.0, -1.0), true)
		1:                                                            # the cooper: barrels finished, one half-staved on its hoop
			for i in 3:
				Dress.barrel(k, o + b * Vector3(-1.4 + 1.0 * float(i), 0.0, 0.0), 0.0, 0.9)
			for i in 9:
				var a := TAU * float(i) / 9.0
				k.kit.box("wood_big", o + b * Vector3(1.6 + cos(a) * 0.42, 0.4, 0.9 + sin(a) * 0.42), Vector3(0.12, 0.8, 0.04), b * Basis(Vector3.UP, -a + PI * 0.5), false, 0.78)
			k.tube("iron", o + b * Vector3(1.6, 0.1, 0.9), o + b * Vector3(1.6, 0.16, 0.9), 0.46, 0.46, 8, false, 0.6)
		_:                                                            # the tanner: a frame stretched with hides, a vat
			for s: float in [-1.0, 1.0]:
				k.tube("wood_big", o + b * Vector3(s * 1.5, 0.0, 0.0), o + b * Vector3(s * 1.5, 2.0, 0.0), 0.06, 0.06, 5, false, 0.7)
			k.beam("wood_big", o + b * Vector3(-1.5, 1.95, 0.0), o + b * Vector3(1.5, 1.95, 0.0), 0.07, 0.07, false, 0.7)
			for i in 3:
				var x := -0.9 + 0.9 * float(i)
				var tp := o + b * Vector3(x, 1.9, 0.0)
				k.kit.quad("chalk", tp + b * Vector3(-0.35, 0.0, 0.0), tp + b * Vector3(0.35, 0.0, 0.0), tp + b * Vector3(0.3, -1.2, 0.0), tp + b * Vector3(-0.3, -1.1, 0.0), b * Vector3(0.0, 0.0, 1.0), false, 0.55 + 0.1 * float(i))
				k.kit.quad("chalk", tp + b * Vector3(-0.35, 0.0, 0.0), tp + b * Vector3(0.35, 0.0, 0.0), tp + b * Vector3(0.3, -1.2, 0.0), tp + b * Vector3(-0.3, -1.1, 0.0), b * Vector3(0.0, 0.0, -1.0), false, 0.45)
			k.tube("wood_big", o + b * Vector3(0.0, 0.0, 1.4), o + b * Vector3(0.0, 0.8, 1.4), 0.55, 0.6, 9, false, 0.7, Vector2(1.0, -1.0), true)
			k.kit.box("dark", o + b * Vector3(0.0, 0.76, 1.4), Vector3(0.9, 0.04, 0.9), b, false, 0.4)


static func _linen(k: WK, o: Vector3, b: Basis, v: int) -> void:
	for s: float in [-1.0, 1.0]:
		k.tube("wood_big", o + b * Vector3(s * 2.4, 0.0, 0.0), o + b * Vector3(s * 2.4, 2.2, 0.0), 0.07, 0.06, 5, false, 0.7)
	Dress.rope(k, o + b * Vector3(-2.4, 2.1, 0.0), o + b * Vector3(2.4, 2.1, 0.0), 0.25, 0.02, "wood_big", 6)
	for i in (2 if v == 0 else 3):                                    # whole blankets, long and heavy, hung doubled over the line
		var x := -1.4 + (2.8 if v == 0 else 1.4) * float(i)
		var tp := o + b * Vector3(x, 2.0, 0.0)
		var h := 1.2 + 0.2 * float(v)
		for side: float in [-1.0, 1.0]:
			k.kit.quad("chalk", tp + b * Vector3(-0.55, 0.0, 0.04 * side), tp + b * Vector3(0.55, 0.0, 0.04 * side), tp + b * Vector3(0.6, -h, 0.12 * side), tp + b * Vector3(-0.6, -h, 0.12 * side), b * Vector3(0.0, 0.0, side), false, 0.7 - 0.1 * float(v))


static func _geese(k: WK, o: Vector3, b: Basis, v: int) -> void:
	for i in 10:                                                      # a low hurdle ring, a trough and a straw nest
		var a := TAU * float(i) / 10.0
		var a2 := TAU * float(i + 1) / 10.0
		var p := o + b * Vector3(cos(a) * 1.8, 0.0, sin(a) * 1.5)
		var p2 := o + b * Vector3(cos(a2) * 1.8, 0.0, sin(a2) * 1.5)
		k.tube("wood_big", p, p + Vector3.UP * 0.7, 0.04, 0.04, 4, false, 0.7)
		k.beam("wood_big", p + Vector3.UP * 0.5, p2 + Vector3.UP * 0.5, 0.04, 0.04, false, 0.68)
	k.kit.box("wood_big", o + b * Vector3(-0.8, 0.15, 0.3), Vector3(0.9, 0.3, 0.3), b, false, 0.75)
	k.kit.box("chalk", o + b * Vector3(0.7, 0.08, -0.3), Vector3(0.8, 0.16, 0.7), b * Basis(Vector3.UP, 0.3 * float(v)), false, 0.85)
	for i in 3 + v:                                                   # the geese: a pale body, a neck and a head
		var gp := o + b * Vector3(rng_f(i, v) * 1.1, 0.0, rng_f(i + 7, v) * 0.9)
		var gb := Basis(Vector3.UP, float(i) * 1.9)
		k.kit.box("chalk", gp + Vector3.UP * 0.32, Vector3(0.28, 0.24, 0.5), gb, false, 0.88)
		k.kit.box("chalk", gp + gb * Vector3(0.0, 0.58, -0.22), Vector3(0.07, 0.4, 0.07), gb, false, 0.88)
		k.kit.box("iron", gp + gb * Vector3(0.0, 0.78, -0.27), Vector3(0.07, 0.07, 0.14), gb, false, 0.7)


static func rng_f(i: int, v: int) -> float:
	return float(absi(hash(Vector2i(i, v))) % 200) / 100.0 - 1.0
