extends RefCounted
## Secondary and tertiary forms for the landmarks (the deeper-models pass): what a big set piece has besides its
## mass. Every helper takes the WK instance `k` (wonder_kit.gd) and adds boxes/prisms to its kit, so it costs triangles at
## build time and nothing at runtime: rubble heaps, sagging ropes and chains (a catenary in short prisms), hung linen
## banners, hanging root-and-ivy strands, barrels and crates, a looters' camp, carved bands, cracks. Non-solid unless said
## (clutter never blocks a stair). Deterministic from the kit's rng. No class_name: preload by path.

const Frame := preload("res://core/world/realm/wonders/r39/wonder_frame.gd")


static func rubble(k, c: Vector3, r: float, n: int, key := "stone_big") -> void:
	var rng: RandomNumberGenerator = k.rng
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var sz := Vector3(rng.randf_range(0.35, 1.5), rng.randf_range(0.25, 0.9), rng.randf_range(0.35, 1.3)) * (1.0 - 0.5 * d / maxf(r, 0.1))
		var p := c + Vector3(cos(a) * d, sz.y * 0.35, sin(a) * d)
		k.kit.box(key, p, sz, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35)) * Basis(Vector3.FORWARD, rng.randf_range(-0.3, 0.3)), false, rng.randf_range(0.7, 1.0))


## A hanging line a -> b sagging `sag` in the middle, in `segs` prisms.
static func rope(k, a: Vector3, b: Vector3, sag := 0.6, thick := 0.05, key := "wood_big", segs := 6) -> void:
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / float(segs)
		var u := 2.0 * t - 1.0
		var cur := a.lerp(b, t) + Vector3.DOWN * (sag * (1.0 - u * u))
		k.beam(key, prev, cur, thick, thick, false, 0.7)
		prev = cur


static func chain(k, a: Vector3, b: Vector3, sag := 0.5, link := 0.16, segs := 8) -> void:
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / float(segs)
		var u := 2.0 * t - 1.0
		var cur := a.lerp(b, t) + Vector3.DOWN * (sag * (1.0 - u * u))
		var mid := (prev + cur) * 0.5
		var bs := Frame.of(cur - prev)
		k.kit.box("iron", mid, Vector3(link, link * 0.8, prev.distance_to(cur) * 0.9), bs, false, 0.6)
		k.kit.box("iron", mid, Vector3(link * 0.8, link, prev.distance_to(cur) * 0.5), bs, false, 0.55)
		prev = cur


## A linen banner hung from `top` (its upper-left corner) along `along`, `w` wide and `h` long, with a pole and a torn hem.
static func banner(k, top: Vector3, along: Vector3, w: float, h: float, out: Vector3, key := "chalk") -> void:
	var al := along.normalized() * w
	var dn := Vector3.DOWN * h
	k.beam("wood_big", top - al * 0.05, top + al * 1.05, 0.08, 0.08, false, 0.7)
	k.kit.quad(key, top, top + al, top + al + dn * 0.92, top + dn, out, false, 0.62)
	k.kit.quad(key, top, top + al, top + al + dn * 0.92, top + dn, -out, false, 0.5)
	k.kit.quad("iron", top + dn * 0.2, top + al + dn * 0.2, top + al + dn * 0.26, top + dn * 0.26, out, false, 0.6)      # a dark band
	k.kit.quad("wood_big", top + dn * 0.92, top + al + dn * 0.92, top + al * 0.8 + dn * 1.02, top + al * 0.15 + dn * 0.99, out, false, 0.5)   # the torn hem


## Hanging root and ivy strands under an edge: `n` strands of `len` metres spread along `a`..`b`.
static func strands(k, a: Vector3, b: Vector3, n: int, len: float, key := "bark") -> void:
	var rng: RandomNumberGenerator = k.rng
	for i in n:
		var p := a.lerp(b, (float(i) + rng.randf()) / float(n))
		var l := len * rng.randf_range(0.4, 1.0)
		var sw := Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
		k.tube(key, p, p + Vector3.DOWN * l + sw, 0.06, 0.02, 4, false, rng.randf_range(0.55, 0.9))
		if rng.randf() < 0.6:
			var lp := p + Vector3.DOWN * (l * rng.randf_range(0.3, 0.9))
			k.kit.box(key, lp, Vector3(0.28, 0.06, 0.2), Basis(Vector3.UP, rng.randf() * TAU), false, 0.9)


static func barrel(k, c: Vector3, yaw := 0.0, h := 1.0) -> void:
	k.tube("wood_big", c, c + Vector3.UP * h, 0.42, 0.42, 8, false, 0.8, Vector2(1.0, -1.0), true)
	for y: float in [0.18, 0.78]:
		k.tube("iron", c + Vector3.UP * (h * y), c + Vector3.UP * (h * y + 0.07), 0.45, 0.45, 8, false, 0.6)


static func crate(k, c: Vector3, yaw := 0.0, s := 0.9) -> void:
	var b := Basis(Vector3.UP, yaw)
	k.kit.box("wood_big", c + Vector3.UP * s * 0.5, Vector3(s, s, s), b, false, 0.85)
	k.kit.box("iron", c + Vector3.UP * s * 0.5, Vector3(s * 1.03, 0.08, s * 1.03), b, false, 0.6)


## A looters' camp: a ring of stones with a small fire, a lean of two crates and barrels, a rope line with a lantern.
static func camp(k, c: Vector3, yaw := 0.0, fire := true) -> void:
	var b := Basis(Vector3.UP, yaw)
	for i in 7:
		var a := TAU * float(i) / 7.0
		k.kit.box("stone", c + Vector3(cos(a), 0.1, sin(a)) * 0.8, Vector3(0.34, 0.26, 0.3), Basis(Vector3.UP, a), false, 0.8)
	if fire:
		k.fire(c + Vector3.UP * 0.15, 0.55, 1.4)
	crate(k, c + b * Vector3(2.0, 0.0, 0.4), yaw + 0.3)
	crate(k, c + b * Vector3(2.0, 0.9, 0.4), yaw + 0.9, 0.7)
	barrel(k, c + b * Vector3(2.9, 0.0, -0.6), yaw)
	barrel(k, c + b * Vector3(-2.4, 0.0, 0.9), yaw, 0.9)
	k.kit.box("wood_big", c + b * Vector3(-1.4, 0.15, -1.3), Vector3(1.8, 0.3, 0.8), b * Basis(Vector3.UP, 0.4), false, 0.7)      # a bedroll


## A carved band round a shaft or along a wall: `n` raised blocks in a row along a->b at a height, alternating depth.
static func carved_band(k, a: Vector3, b: Vector3, n: int, size: Vector3, key := "ruin_big") -> void:
	var d := b - a
	var bs := Frame.of(d)
	for i in n:
		var p := a + d * ((float(i) + 0.5) / float(n))
		var off := 0.0 if i % 2 == 0 else size.y * 0.5
		k.kit.box(key, p + Vector3.UP * off, size, bs, false, 0.78 if i % 2 == 0 else 0.92)


## Cracks across a face: dark thin boxes in a zig-zag from `a` to `b`.
static func crack(k, a: Vector3, b: Vector3, width := 0.12) -> void:
	var rng: RandomNumberGenerator = k.rng
	var prev := a
	for i in range(1, 6):
		var t := float(i) / 5.0
		var cur := a.lerp(b, t) + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.5, 0.5)) * (1.0 - t * 0.5)
		k.beam("dark", prev, cur, width, width * 0.6, false, 0.4)
		prev = cur
