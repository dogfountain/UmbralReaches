extends RefCounted
## ROADSIDE STORIES (the world pass): thirty small scenes beside the Realm's ways, each told in objects, so a walk along any
## road passes something that happened: an overturned cart with its load spilled and its ox's bones, a wayside shrine
## with offerings and a candle, a gibbet with its cage and a lantern, a toll post whose keeper is gone, an abandoned camp,
## a pilgrims' cairn hung with lanterns. Found by walking every way (RealmLayout.PATHS) every ~75 m and standing a scene
## 8-13 m off it on flat, dry, unclaimed ground (WK.span / WK.taken), 60 m apart at least; the kind follows a hash of the
## spot. Each scene is its own kit (one set of meshes, faded at 140 m), reserves its ground, carries its own light
## (a lantern or a fire with a distance fade), and a third of them hold a small chest. Build-time only.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")
const COUNT := 30
const SELF := "res://core/world/realm/wonders/r39/roadside_tableaux.gd"

var _placed: Array[Vector2] = []


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var ids: Array = []
	for reg: Dictionary in RealmLayout.REGIONS:
		ids.append(String(reg.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6007
	var n := 0
	var side := 1.0
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		var to_next := rng.randf_range(25.0, 70.0)
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg := a.distance_to(b)
			if seg < 0.1:
				continue
			var t := (b - a) / seg
			var at := 0.0
			while to_next <= seg - at and n < COUNT:
				at += to_next
				to_next = 75.0
				var p := a + t * at
				side = -side
				var c := p + Vector2(-t.y, t.x) * side * rng.randf_range(8.0, 13.0)
				if _try(root, c, t, n, ids, rng):
					n += 1
			to_next -= seg - at
	print("WONDER roadside_tableaux: %d scenes" % n)


func _try(root: Node, c: Vector2, t: Vector2, n: int, ids: Array, rng: RandomNumberGenerator) -> bool:
	for q: Vector2 in _placed:
		if q.distance_to(c) < 60.0:
			return false
	var sp := WK.span(c, Vector2(5.0, 5.0), 0.0)
	if WK.in_town(c) or sp.x == INF or sp.y - sp.x > 1.5 or WK.site_hit(Rect2(c - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), 2.0) or RealmLayout.path_dist(c) < 6.0:
		return false
	_placed.append(c)
	var k := WK.new()
	k.setup(root, "Roadside%d" % n, 6100 + n)
	WK.reserve("wonder_roadside_%d" % n, c, Vector2(5.0, 5.0), 0.0, sp.x, sp.y + 6.0)
	var g := sp.y
	var yaw := atan2(t.x, t.y) + rng.randf_range(-0.4, 0.4)
	var o := Vector3(c.x, g, c.y)
	var b := Basis(Vector3.UP, yaw)
	var kind := int(absi(hash(Vector2i(roundi(c.x), roundi(c.y)))) % 6)
	if not k.cached(WK.fp(SELF, [o, yaw, kind, n, WK.tsig(c, 6.0)])):
		k.kit.box("stone", o + Vector3.DOWN * 0.3, Vector3(10.0, 0.7, 10.0), b, false, 0.82)       # a trodden pad under the scene
		match kind:
			0: _cart(k, o, b, yaw, n)
			1: _shrine(k, o, b, yaw)
			2: _gibbet(k, o, b, yaw)
			3: _toll(k, o, b, yaw, n)
			4: _camp(k, o, b, yaw, n)
			_: _cairn(k, o, b, yaw)
	k.commit(140.0)
	return true


func _chest(k, id: String, at: Vector3, yaw: float, n: int) -> void:
	if n % 3 == 0:
		k.chest("roadside_%d" % n, "wood", at, yaw, {"grave_ash": 6 + n % 5, "grave_iron": 1})


func _cart(k, o: Vector3, b: Basis, yaw: float, n: int) -> void:
	var tilt := b * Basis(Vector3.FORWARD, 0.38)
	k.kit.box("wood_big", o + b * Vector3(0.0, 0.85, 0.0), Vector3(2.4, 0.2, 3.6), tilt, true, 0.8)
	for s: float in [-1.0, 1.0]:
		k.kit.box("wood_big", o + b * Vector3(s * 1.2, 1.2, 0.0), Vector3(0.14, 0.7, 3.6), tilt, false, 0.75)
	k.beam("wood_big", o + b * Vector3(0.0, 0.6, 1.8), o + b * Vector3(1.0, 0.5, 5.2), 0.16, 0.16, false, 0.7)         # the shaft, broken
	for s: float in [-1.0, 1.0]:
		var wc := o + b * Vector3(s * 1.5, 0.75, -0.3 if s < 0.0 else 0.4)
		var ax := b * Vector3(1.0, 0.0, 0.0)
		k.tube("wood_big", wc - ax * 0.07, wc + ax * 0.07, 0.75 if s < 0.0 else 0.4, 0.75 if s < 0.0 else 0.4, 10, false, 0.75, Vector2(1.0, -1.0), true)
		k.tube("iron", wc - ax * 0.09, wc + ax * 0.09, 0.78 if s < 0.0 else 0.42, 0.78 if s < 0.0 else 0.42, 10, false, 0.6)
	Dress.barrel(k, o + b * Vector3(-2.5, 0.0, 1.5), yaw, 1.0)
	Dress.barrel(k, o + b * Vector3(-3.4, 0.0, 0.2), yaw + 0.5, 0.9)
	Dress.crate(k, o + b * Vector3(2.8, 0.0, -1.2), yaw + 0.3, 0.9)
	Dress.rubble(k, o + b * Vector3(1.0, 0.0, 3.0), 2.0, 8, "wood_big")
	for i in 7:                                                                                   # an ox's ribs and skull
		var rx := 3.4 + 0.22 * float(i)
		k.tube("bone", o + b * Vector3(rx - 0.0, 0.1, 2.4), o + b * Vector3(rx, 0.7, 2.7), 0.04, 0.03, 4, false, 0.9)
		k.tube("bone", o + b * Vector3(rx, 0.1, 3.4), o + b * Vector3(rx, 0.7, 3.1), 0.04, 0.03, 4, false, 0.9)
	k.kit.box("bone", o + b * Vector3(5.4, 0.2, 2.9), Vector3(0.4, 0.3, 0.6), b, false, 0.95)
	k.lamp(o + b * Vector3(1.0, 1.8, 0.0), Color(0.9, 0.65, 0.4), 0.5, 5.0)
	_chest(k, "cart", o + b * Vector3(-1.2, 0.3, -1.8), yaw, n)


func _shrine(k, o: Vector3, b: Basis, yaw: float) -> void:
	k.kit.box("stone_big", o + Vector3.UP * 0.35, Vector3(2.6, 0.7, 2.6), b, true, 0.9)
	k.kit.box("stone_big", o + Vector3.UP * 1.9, Vector3(1.3, 2.6, 1.0), b, true, 0.96)
	k.kit.box("ruin_big", o + Vector3.UP * 3.4, Vector3(1.7, 0.4, 1.4), b, true, 0.86)
	k.kit.box("dark", o + b * Vector3(0.0, 2.1, -0.52), Vector3(0.7, 1.2, 0.1), b, false, 0.35)        # the niche
	k.window(o + b * Vector3(0.0, 1.55, -0.55), b * Vector3(1.0, 0.0, 0.0), b * Vector3(0.0, 0.0, -1.0), 0.4, 0.5)
	for i in 6:
		var a := TAU * float(i) / 6.0
		k.kit.box("wax", o + b * Vector3(cos(a) * 1.5, 0.12, -1.3 + sin(a) * 0.5), Vector3(0.08, 0.24, 0.08), b, false, 0.95)
	k.fire(o + b * Vector3(0.0, 0.55, -1.5), 0.35, 1.2)
	Dress.banner(k, o + b * Vector3(-1.4, 3.2, -0.3), b * Vector3(0.0, 0.0, 1.0), 1.4, 2.4, b * Vector3(-1.0, 0.0, 0.0))
	Dress.rope(k, o + b * Vector3(-1.4, 3.2, 0.9), o + b * Vector3(1.0, 3.3, 0.9), 0.4, 0.04)
	Dress.strands(k, o + b * Vector3(-0.8, 3.6, 0.0), o + b * Vector3(0.8, 3.6, 0.0), 4, 1.0)


func _gibbet(k, o: Vector3, b: Basis, yaw: float) -> void:
	k.tube("wood_big", o, o + Vector3.UP * 6.0, 0.22, 0.18, 6, true, 0.7)
	k.beam("wood_big", o + Vector3.UP * 5.8, o + b * Vector3(2.4, 5.8, 0.0), 0.2, 0.2, false, 0.7)
	k.beam("wood_big", o + b * Vector3(0.0, 4.6, 0.0), o + b * Vector3(1.6, 5.6, 0.0), 0.14, 0.14, false, 0.7)
	Dress.chain(k, o + b * Vector3(2.2, 5.8, 0.0), o + b * Vector3(2.2, 4.4, 0.0), 0.05, 0.12, 4)
	var cc := o + b * Vector3(2.2, 3.6, 0.0)
	for i in 6:
		var a := TAU * float(i) / 6.0
		k.beam("iron", cc + b * Vector3(cos(a) * 0.38, -0.7, sin(a) * 0.38), cc + b * Vector3(cos(a) * 0.3, 0.7, sin(a) * 0.3), 0.06, 0.06, false, 0.55)
	for y: float in [-0.7, 0.0, 0.7]:
		k.tube("iron", cc + Vector3.UP * y, cc + Vector3.UP * (y + 0.05), 0.4, 0.4, 8, false, 0.55)
	k.kit.box("bone", cc + Vector3.DOWN * 0.2, Vector3(0.3, 0.9, 0.2), b, false, 0.9)
	k.kit.box("bone", cc + Vector3.UP * 0.35, Vector3(0.26, 0.26, 0.26), b, false, 0.95)
	k.kit.box("glow", o + b * Vector3(0.0, 4.4, 0.35), Vector3(0.26, 0.38, 0.26), b, false, 1.0)       # a lantern on the post
	k.lamp(o + b * Vector3(0.0, 4.4, 0.35), Color(1.0, 0.68, 0.38), 1.1, 8.0)
	Dress.rubble(k, o + b * Vector3(1.0, 0.0, 1.6), 1.8, 8, "stone")


func _toll(k, o: Vector3, b: Basis, yaw: float, n: int) -> void:
	k.kit.box("wood_big", o + b * Vector3(-3.0, 1.4, 0.0), Vector3(2.6, 2.8, 2.6), b, true, 0.9)
	k.kit.box("slate", o + b * Vector3(-3.0, 3.0, 0.0), Vector3(3.3, 0.3, 3.3), b, true, 0.85)
	k.window(o + b * Vector3(-1.69, 1.1, 0.0), b * Vector3(0.0, 0.0, 1.0), b * Vector3(1.0, 0.0, 0.0), 0.8, 0.8)
	k.lamp(o + b * Vector3(-1.5, 1.6, 0.0), Color(1.0, 0.66, 0.36), 0.9, 6.0)
	k.tube("wood_big", o + b * Vector3(-1.2, 0.0, 0.0), o + b * Vector3(-1.2, 1.3, 0.0), 0.12, 0.12, 6, true, 0.7)
	k.beam("wood_big", o + b * Vector3(-1.2, 1.15, 0.0), o + b * Vector3(3.6, 1.15, 1.2), 0.14, 0.14, false, 0.75)        # the barrier, raised
	Dress.chain(k, o + b * Vector3(3.6, 1.1, 1.2), o + b * Vector3(3.9, 0.2, 1.4), 0.1, 0.12, 4)
	k.kit.box("wood_big", o + b * Vector3(2.0, 1.2, -2.2), Vector3(1.4, 1.0, 0.1), b * Basis(Vector3.UP, 0.2), false, 0.8)       # a notice board
	k.tube("wood_big", o + b * Vector3(1.5, 0.0, -2.2), o + b * Vector3(1.5, 1.8, -2.2), 0.06, 0.06, 4, false, 0.7)
	k.tube("wood_big", o + b * Vector3(2.5, 0.0, -2.2), o + b * Vector3(2.5, 1.8, -2.2), 0.06, 0.06, 4, false, 0.7)
	Dress.barrel(k, o + b * Vector3(-4.8, 0.0, 1.0), yaw)
	_chest(k, "toll", o + b * Vector3(-3.0, 0.3, 0.4), yaw + PI, n)


func _camp(k, o: Vector3, b: Basis, yaw: float, n: int) -> void:
	Dress.camp(k, o, yaw)
	for s: float in [-1.0, 1.0]:                                                                  # a lean-to of two poles and a hide
		k.beam("wood_big", o + b * Vector3(s * 1.6 - 3.5, 0.0, -2.0), o + b * Vector3(-3.5, 1.8, -1.0), 0.1, 0.1, false, 0.7)
	k.kit.quad("chalk", o + b * Vector3(-5.1, 0.0, -2.0), o + b * Vector3(-1.9, 0.0, -2.0), o + b * Vector3(-2.6, 1.8, -1.0), o + b * Vector3(-4.4, 1.8, -1.0), b * Vector3(0.0, 0.7, -1.0), false, 0.7)
	k.beam("iron", o + b * Vector3(-0.9, 1.5, 0.0), o + b * Vector3(0.9, 1.5, 0.0), 0.05, 0.05, false, 0.6)           # a spit over the fire
	k.tube("iron", o + b * Vector3(-0.9, 0.0, 0.0), o + b * Vector3(-0.9, 1.5, 0.0), 0.04, 0.04, 4, false, 0.6)
	k.tube("iron", o + b * Vector3(0.9, 0.0, 0.0), o + b * Vector3(0.9, 1.5, 0.0), 0.04, 0.04, 4, false, 0.6)
	_chest(k, "camp", o + b * Vector3(-3.2, 0.2, 0.3), yaw, n)


func _cairn(k, o: Vector3, b: Basis, yaw: float) -> void:
	var rng: RandomNumberGenerator = k.rng
	for i in 5:
		var w := 2.6 - 0.45 * float(i)
		k.kit.box("stone_big", o + Vector3.UP * (0.3 + 0.5 * float(i)), Vector3(w, 0.5, w * 0.9), Basis(Vector3.UP, yaw + rng.randf_range(-0.3, 0.3)), true, 0.85 + 0.03 * float(i))
	for i in 5:
		var a := TAU * float(i) / 5.0 + yaw
		var hp := o + Vector3(cos(a) * 1.5, 3.3, sin(a) * 1.5)
		Dress.rope(k, o + Vector3.UP * 3.0, hp, 0.1, 0.03, "wood_big", 3)
		k.kit.box("iron", hp + Vector3.UP * 0.2, Vector3(0.03, 0.4, 0.03), Basis.IDENTITY, false, 0.6)
		k.kit.box("glow", hp - Vector3.UP * 0.05, Vector3(0.24, 0.32, 0.24), Basis(Vector3.UP, a), false, 1.0)
		if i % 2 == 0:
			k.lamp(hp, Color(1.0, 0.68, 0.38), 0.7, 6.0)
	k.fire(o + b * Vector3(1.8, 0.2, 0.0), 0.5, 1.2)
