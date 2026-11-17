extends RefCounted
## THE TITAN GATES (the world pass: boss-scale architecture): before each of the Realm's raid floors (RealmLayout.RAIDS: the
## Thornwarden's henge, the Hierarch's statue ring, the Anchoress's terrace) two wardens of the Order's stone stand
## 13 m outside the arena's gate, 14 m apart, 20 m tall to the spear tip, each with a fire in a bowl on its helm and eyes
## lit towards the approach: the player walks between two figures three times the size of the thing they came to fight,
## and the boss that follows (7.6-8.8 m) is read against them. (The summit's chasm-deck is left alone.)
##   - plinth, legs and belt, a broad chest, arms, a tall shield facing the approach, a spear raised to 22 m, a helm
##     with a crest; masonry in the colossal tier ("stone_big", 2-3 times a house's courses)
##   - one fire and a lit pair of eyes each (a light with a fade), the site reserved (nothing grows or is placed there)
## Built once, a kit per gate pair so each culls on its own.

const SELF := "res://core/world/realm/wonders/r39/titan_gates.gd"
const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")


static func build(root: Node) -> void:
	for r: Dictionary in RealmLayout.RAIDS:
		var id := String(r.id)
		if id == "summit":
			continue
		var w := new()
		w._gate(root, r)


func _gate(root: Node, r: Dictionary) -> void:
	var c: Vector2 = r.c
	var gate: Vector2 = r.gate
	var dir := (gate - c).normalized()
	var side := Vector2(-dir.y, dir.x)
	var k := WK.new()
	k.setup(root, "TitanGate_" + String(r.id), 8100 + int(absf(c.x)))
	var title: String = {"henge": "The Thorn Wardens", "hierarch": "The Siege Wardens", "anchorhold": "The Anchor Wardens"}.get(String(r.id), "The Wardens")
	k.poi("titan_gate_" + String(r.id), title, "two wardens of stone, and what they were set to keep out", WK.region_at(gate))
	# 30 m outside the gate, clear of the arena's seal guards and camps (their sites): nudged out 14 m at a time if a site is there
	var off := 30.0
	for t in 3:
		var bp := gate + dir * off
		if not WK.site_hit(Rect2(bp - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), 2.0):
			break
		off += 14.0
	var base := gate + dir * off
	var yaw := atan2(dir.x, dir.y)
	for s: float in [-1.0, 1.0]:
		var p := base + side * (7.0 * s)
		WK.reserve("titan_gate_%s_%d" % [String(r.id), int(s)], p, Vector2(5.0, 5.0), yaw, WK.h(p.x, p.y) - 2.0, WK.h(p.x, p.y) + 24.0)
	if not k.cached(WK.fp(SELF, [String(r.id), base, WK.tsig(base, 60.0)])):
		for s: float in [-1.0, 1.0]:
			_titan(k, base + side * (7.0 * s), dir, side, s)
		_avenue(k, base, dir, side, String(r.id))
	var n: int = k.commit(0.0)
	print("WONDER titan_gate %s at %s: %d meshes, %d fires" % [String(r.id), base, n, k.fires])


## The processional: from the wardens outward along the approach, five pairs of obelisks 12 m apart, 14 m across, taller the
## nearer the gate (9 m down to 5 m), carved bands on each, a fire on every second pair, a low kerb between the pairs: the
## last hundred feet to an arena are architecture, so the fight is foreshadowed by its place.
func _avenue(k, base: Vector2, dir: Vector2, side: Vector2, id: String) -> void:
	for i in 5:
		var at := base + dir * (14.0 + 12.0 * float(i))
		var h := 9.0 - 1.0 * float(i)
		for s: float in [-1.0, 1.0]:
			var p := at + side * (7.0 * s)
			if WK.wet(p.x, p.y) or WK.site_hit(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), 1.0):
				continue
			var g := WK.h(p.x, p.y)
			var b := Basis(Vector3(side.x, 0.0, side.y), Vector3.UP, Vector3(dir.x, 0.0, dir.y))
			k.kit.box("stone_big", Vector3(p.x, (g - 1.0 + g + 0.9) * 0.5, p.y), Vector3(2.4, 1.9, 2.4), b, true, 0.86)
			k.tube("stone_big", Vector3(p.x, g + 0.9, p.y), Vector3(p.x, g + h, p.y), 0.85, 0.5, 4, true, 0.96, Vector2(1.0, -1.0), true, PI * 0.25)
			k.tube("ruin_big", Vector3(p.x, g + h, p.y), Vector3(p.x, g + h + 0.9, p.y), 0.35, 0.02, 4, false, 0.9, Vector2(1.0, -1.0), false, PI * 0.25)
			Dress.carved_band(k, Vector3(p.x - side.x * 0.0, g + 3.0, p.y), Vector3(p.x, g + 5.0, p.y), 3, Vector3(0.45, 0.45, 0.2), "ruin_big")
			if i % 2 == 0:
				k.kit.box("iron", Vector3(p.x, g + h + 1.2, p.y), Vector3(0.8, 0.3, 0.8), b, false, 0.65)
				k.fire(Vector3(p.x, g + h + 1.4, p.y), 1.0, 2.0, i == 0)
		if i < 4:
			var mid := at + dir * 6.0
			for s: float in [-1.0, 1.0]:
				var kp := mid + side * (7.0 * s)
				if not WK.wet(kp.x, kp.y):
					k.kit.box("stone_big", Vector3(kp.x, WK.h(kp.x, kp.y) + 0.25, kp.y), Vector3(0.7, 0.7, 8.0), Basis(Vector3(side.x, 0.0, side.y), Vector3.UP, Vector3(dir.x, 0.0, dir.y)), true, 0.82)


func _titan(k, p: Vector2, dir: Vector2, side: Vector2, s: float) -> void:
	var g := WK.h(p.x, p.y)
	var f3 := Vector3(dir.x, 0.0, dir.y)
	var s3 := Vector3(side.x, 0.0, side.y)
	var b := Basis(s3, Vector3.UP, f3)
	var c := Vector3(p.x, g, p.y)
	var low := g - 1.0
	k.kit.box("stone_big", Vector3(c.x, (low + g + 1.7) * 0.5, c.z), Vector3(6.4, g + 1.7 - low, 6.4), b, true, 0.86)           # the plinth
	k.kit.box("ruin_big", c + Vector3.UP * 1.85, Vector3(5.4, 0.4, 5.4), b, true, 0.8)
	k.kit.box("stone_big", c + Vector3.UP * 6.5, Vector3(3.8, 9.0, 3.2), b, true, 0.98)             # the legs and body
	k.kit.box("ruin_big", c + Vector3.UP * 6.6, Vector3(4.3, 0.6, 3.7), b, true, 0.82)             # the belt
	k.kit.box("stone_big", c + Vector3.UP * 12.2, Vector3(5.8, 3.4, 3.6), b, true, 1.0)            # the chest and shoulders
	k.kit.box("stone_big", c + Vector3.UP * 14.9, Vector3(2.6, 2.4, 2.6), b, true, 0.96)           # the helm
	k.kit.box("ruin_big", c + Vector3.UP * 16.3, Vector3(3.0, 0.5, 3.0), b, true, 0.84)
	for q: float in [-1.0, 1.0]:
		k.kit.box("stone_big", c + s3 * (q * 3.7) + Vector3.UP * 9.4, Vector3(1.5, 7.2, 1.7), b, true, 0.94)    # the arms
	# the shield on the approach side: a tall slab before the left arm; the spear in the right hand
	k.kit.box("stone_big", c + s3 * (-3.6 * s) + f3 * 2.1 + Vector3.UP * 8.2, Vector3(3.6, 7.0, 0.7), b, true, 0.92)
	k.kit.box("iron", c + s3 * (-3.6 * s) + f3 * 2.5 + Vector3.UP * 8.2, Vector3(1.6, 4.0, 0.2), b, false, 0.6)
	var hand := c + s3 * (3.7 * s) + f3 * 0.6 + Vector3.UP * 7.0
	k.tube("wood_big", hand - Vector3.UP * 4.5, hand + Vector3.UP * 15.6, 0.26, 0.2, 6, false, 0.7)
	k.tube("iron", hand + Vector3.UP * 15.4, hand + Vector3.UP * 17.8, 0.3, 0.02, 4, false, 0.65)
	# the eyes, lit, on the approach face of the helm; the crest behind
	for q: float in [-0.55, 0.55]:
		var e := c + s3 * q + f3 * 1.31 + Vector3.UP * 15.2
		k.kit.quad("glow", e - s3 * 0.3, e + s3 * 0.3, e + s3 * 0.3 + Vector3.UP * 0.32, e - s3 * 0.3 + Vector3.UP * 0.32, f3, false, 1.0)
	k.tube("ruin_big", c - f3 * 0.8 + Vector3.UP * 16.4, c - f3 * 1.6 + Vector3.UP * 19.6, 0.5, 0.1, 5, false, 0.86)
	# the fire in the bowl on the helm
	var bowl := c + Vector3.UP * 16.8
	k.kit.box("iron", bowl + Vector3.UP * 0.2, Vector3(1.5, 0.4, 1.5), b, false, 0.65)
	k.fire(bowl + Vector3.UP * 0.5, 1.9, 3.6)
	_dress(k, c, f3, s3, s)


# --- secondary forms: a cloak of chain, a banner on the spear, rubble at the plinth, ivy on the shield ------

func _dress(k, c: Vector3, f3: Vector3, s3: Vector3, s: float) -> void:
	Dress.rubble(k, c + f3 * 3.0, 4.5, 14, "ruin_big")
	Dress.rubble(k, c - f3 * 2.0 + s3 * 3.0, 3.5, 9, "ruin_big")
	Dress.chain(k, c + s3 * -2.6 + Vector3.UP * 13.2 - f3 * 1.8, c + s3 * 2.6 + Vector3.UP * 13.2 - f3 * 1.8, 1.4, 0.24, 9)
	Dress.chain(k, c + s3 * -2.4 + Vector3.UP * 11.0 - f3 * 1.8, c + s3 * 2.4 + Vector3.UP * 11.0 - f3 * 1.8, 1.8, 0.22, 9)
	var hand := c + s3 * (3.7 * s) + f3 * 0.6 + Vector3.UP * 7.0
	Dress.banner(k, hand + Vector3.UP * 13.0, -f3, 3.2, 4.0, s3 * s)
	Dress.strands(k, c + s3 * (-3.6 * s) + f3 * 2.1 + Vector3.UP * 11.6 - s3 * 1.8, c + s3 * (-3.6 * s) + f3 * 2.1 + Vector3.UP * 11.6 + s3 * 1.8, 7, 4.5)
	Dress.crack(k, c + f3 * 1.7 + Vector3.UP * 3.0, c + f3 * 1.7 + s3 * 1.0 + Vector3.UP * 9.0, 0.16)
	Dress.carved_band(k, c + Vector3.UP * 12.2 + s3 * -2.6 + f3 * 1.85, c + Vector3.UP * 12.2 + s3 * 2.6 + f3 * 1.85, 7, Vector3(0.7, 0.45, 0.3))
	Dress.carved_band(k, c + Vector3.UP * 4.0 + s3 * -1.6 + f3 * 1.65, c + Vector3.UP * 4.0 + s3 * 1.6 + f3 * 1.65, 5, Vector3(0.6, 0.4, 0.3))
