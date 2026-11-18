extends RefCounted
## HIDDEN FINDS (the world pass: a reason to read the ground): thirty-two caches across the Realm, each at the end of a
## trail of three clues that starts in sight of a road. The clues point (a cairn of three stones laid as an arrow, a blaze post
## with a pale pennant, a ribbon on a stake, a scratched slab with an arrow of carved blocks, a lantern on a stake turned to the
## next, a row of fire-blackened stones) each at the next, 12-16 m apart, bending a little; the find is one of
##   buried    a mound of turned earth with a spade and a half-buried chest
##   stump     a hollow stump (a tube with its heart cut out) with the chest in it
##   slab      a leaning slab over a hollow, the chest under it
##   shore     a chest on the stones at the water's edge, a rope and a stake
##   ledge     a low cairn platform with a chest and a weathered banner
## Tiers cycle wood, wood, iron, iron, reliquary (every 8th); loot grows with the walk. Each is a kit (clues and find together,
## faded at 130 m), a discovery centred on the find (so the banner and the world events read it), group `hidden_find`
## with `find_at`. Placement: a road point, a side and a bend; every clue and the find on flat dry unclaimed ground (WK.span,
## WK.taken). Build-time only. No class_name.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const COUNT := 32
const SELF := "res://core/world/realm/wonders/r39/hidden_finds.gd"
const TIERS := ["wood", "wood", "iron", "iron", "iron", "wood", "iron", "reliquary"]

var _ids: Array = []
var _found: Array[Vector2] = []


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	for reg: Dictionary in RealmLayout.REGIONS:
		_ids.append(String(reg.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3232
	var cands := WK.grid(3232, 14.0, 16.0)       # every candidate is a find; its three clues are laid back from it along the first direction that is clear
	var t := {}
	var n := 0
	var tried := 0
	for f: Vector2 in cands:
		if n >= COUNT:
			break
		tried += 1
		if Land.in_water(f.x, f.y):
			WK.rej(t, "water")
			continue
		var close := false
		for e: Vector2 in _found:
			if e.distance_to(f) < 40.0:
				close = true
				break
		if close:
			WK.rej(t, "spacing")
			continue
		if not _spot(f, t, true):
			continue
		var c: Array[Vector2] = []
		var a0 := rng.randf() * TAU
		for k in 8:                                   # the first of eight directions whose three clues all stand on clear ground, preferring a trail that starts near a way
			var dir := Vector2(cos(a0 + TAU * float(k) / 8.0), sin(a0 + TAU * float(k) / 8.0))
			var chain: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, f]
			var q := f
			var ok := true
			for s in 3:
				q += dir.rotated(rng.randf_range(-0.35, 0.35)) * rng.randf_range(12.0, 16.0)
				if not _spot(q, t):
					ok = false
					break
				chain[2 - s] = q
			if not ok:
				continue
			if RealmLayout.path_dist(chain[0]) > 60.0 and k < 7:
				continue
			c = chain
			break
		if c.is_empty():
			WK.rej(t, "trail")
			continue
		_found.append(f)
		_build(root, n, c, rng)
		n += 1
	print("WONDER hidden_finds: %d of %d (%d of %d candidates tried); rejected: %s" % [n, COUNT, tried, cands.size(), WK.rejected(t)])


func _spot(q: Vector2, t: Dictionary, strict := false) -> bool:
	if WK.in_town(q):
		return WK.rej(t, "town")
	if not RealmLayout.BOUNDS.grow(-16.0).has_point(q):
		return WK.rej(t, "edge")
	if RealmLayout.path_dist(q) < 4.0:
		return WK.rej(t, "way")
	var sp := WK.span(q, Vector2(2.0, 2.0), 0.0)
	if sp.x == INF or sp.y - sp.x >= 2.6:
		return WK.rej(t, "slope")
	if WK.site_hit(Rect2(q - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), 1.0, strict):
		return WK.rej(t, "site")
	return true


func _g(q: Vector2) -> Vector3:
	return Vector3(q.x, WK.h(q.x, q.y), q.y)


func _build(root: Node, i: int, c: Array[Vector2], rng: RandomNumberGenerator) -> void:
	var k := WK.new()
	k.setup(root, "Find%d" % i, 7800 + i)
	var reg := WK.region_at(c[3])
	k.poi("hidden_find_%d" % i, "A Hidden Cache", "the trail ended here", reg if reg != "" else "road")
	k.host.add_to_group("hidden_find")
	var o := _g(c[3])
	var back := (c[2] - c[3]).normalized()
	var yaw := atan2(back.x, back.y)
	var b := Basis(Vector3.UP, yaw)
	WK.reserve("hidden_find_%d" % i, c[3], Vector2(3.0, 3.0), 0.0, o.y - 1.0, o.y + 4.0)
	var tier: String = TIERS[i % TIERS.size()]
	var loot := {"grave_ash": 8 + (i % 6) * 3, "grave_iron": 1 + i % 3}
	if i % 4 == 3:
		loot["relic_fragment"] = 1
	var kind := i % 5
	var at := o
	var cached := k.cached(WK.fp(SELF, [c, i, WK.tsig(c[3], 4.0)]))
	match kind:
		0: at = o + Vector3.UP * 0.25
		1: at = o + Vector3.UP * 0.95
		2: at = o + b * Vector3(0.0, 0.1, 0.35)
		3: at = o + Vector3.UP * 0.25
		_: at = o + Vector3.UP * 1.32
	if not cached:
		for j in 3:
			var to := (c[j + 1] - c[j]).normalized()
			_clue(k, (i + j) % 5, _g(c[j]), Vector3(to.x, 0.0, to.y), rng)
		match kind:
			0:
				k.kit.box("dark", o + Vector3.UP * 0.12, Vector3(2.4, 0.3, 1.6), b, false, 0.55)
				k.kit.box("cave_moss", o + Vector3(0.0, 0.3, 0.0), Vector3(1.8, 0.3, 1.2), b, false, 0.6)
				k.tube("wood_big", o + b * Vector3(1.4, 0.0, 0.0), o + b * Vector3(1.0, 1.3, 0.3), 0.04, 0.04, 4, false, 0.7)
				k.kit.box("iron", o + b * Vector3(1.0, 1.35, 0.3), Vector3(0.3, 0.28, 0.05), b, false, 0.55)
			1:
				k.tube("bark", o + Vector3.DOWN * 0.2, o + Vector3.UP * 0.9, 0.55, 0.5, 8, true, 0.75, Vector2(1.0, -1.0), true)
				k.tube("dark", o + Vector3.UP * 0.9, o + Vector3.UP * 0.95, 0.38, 0.38, 8, false, 0.4)
				Dress.rubble(k, o + b * Vector3(0.9, 0.0, 0.3), 0.9, 4, "cave_moss")
			2:
				k.kit.box("stone_big", o + b * Vector3(0.0, 0.9, -0.6), Vector3(1.8, 1.8, 0.4), b * Basis(Vector3.RIGHT, 0.45), true, 0.85)
				Dress.rubble(k, o + b * Vector3(0.0, 0.0, 0.5), 1.0, 6, "stone_big")
			3:
				k.kit.box("cave", o + Vector3.UP * 0.1, Vector3(2.0, 0.3, 1.6), b, false, 0.8)
				k.tube("wood_big", o + b * Vector3(1.3, 0.0, 0.0), o + b * Vector3(1.3, 1.1, 0.0), 0.05, 0.05, 4, false, 0.7)
				Dress.rope(k, o + b * Vector3(1.3, 1.0, 0.0), o + b * Vector3(0.2, 0.3, 0.2), 0.2, 0.03)
			_:
				for s in 4:
					k.kit.box("stone_big", o + Vector3.UP * (0.18 + 0.32 * float(s)), Vector3(2.4 - 0.3 * float(s), 0.32, 1.8 - 0.2 * float(s)), Basis(Vector3.UP, yaw + 0.2 * float(s)), true, 0.82)
				Dress.banner(k, o + b * Vector3(-0.9, 2.4, 0.0), b * Vector3(1.0, 0.0, 0.0), 1.4, 1.8, b * Vector3(0.0, 0.0, 1.0))
				k.tube("wood_big", o + b * Vector3(-0.95, 1.3, 0.0), o + b * Vector3(-0.95, 2.5, 0.0), 0.05, 0.05, 4, false, 0.7)
		k.chest("hidden_find_%d" % i, tier, at, yaw, loot)
	k.host.set_meta("find_at", at)
	k.commit(130.0)
	k.host.set_meta("centre", at)
	k.host.set_meta("no_surge", true)
	k.host.set_meta("radius", 10.0)


## One clue at `o` pointing along `to` (a unit XZ direction): five kinds.
func _clue(k, kind: int, o: Vector3, to: Vector3, rng: RandomNumberGenerator) -> void:
	var side := to.cross(Vector3.UP)
	var b := Basis(side, Vector3.UP, to)
	match kind:
		0:                                                                   # three stones laid as an arrow
			for s: float in [-1.0, 1.0]:
				k.kit.box("stone_big", o + to * -0.3 + side * (s * 0.45) + Vector3.UP * 0.12, Vector3(0.5, 0.25, 0.4), Basis(Vector3.UP, atan2(to.x, to.z) + s * 0.6), false, 0.85)
			k.kit.box("stone_big", o + to * 0.5 + Vector3.UP * 0.14, Vector3(0.6, 0.3, 0.45), b, false, 0.9)
		1:                                                                   # a blaze post with a pale pennant
			k.tube("wood_big", o, o + Vector3.UP * 1.8, 0.07, 0.06, 5, false, 0.7)
			Dress.banner(k, o + Vector3.UP * 1.7, to, 1.0, 0.5, side)
		2:                                                                   # a ribbon on a stake
			k.tube("wood_big", o, o + Vector3.UP * 1.1, 0.04, 0.04, 4, false, 0.7)
			Dress.rope(k, o + Vector3.UP * 1.05, o + to * 1.1 + Vector3.UP * 0.7, 0.1, 0.03, "chalk", 3)
		3:                                                                   # a scratched slab with an arrow of blocks
			k.kit.box("stone_big", o + Vector3.UP * 0.5, Vector3(0.9, 1.0, 0.25), b, false, 0.88)
			for s in 3:
				k.kit.box("ruin_big", o + to * (0.14 + 0.0) + Vector3.UP * (0.3 + 0.2 * float(s)), Vector3(0.5 - 0.14 * float(s), 0.1, 0.06), b, false, 0.7)
		_:                                                                   # a lantern on a stake turned to the next
			k.tube("iron", o, o + Vector3.UP * 1.5, 0.03, 0.03, 4, false, 0.6)
			k.kit.box("glow", o + Vector3.UP * 1.6 + to * 0.1, Vector3(0.22, 0.3, 0.22), b, false, 1.0)
