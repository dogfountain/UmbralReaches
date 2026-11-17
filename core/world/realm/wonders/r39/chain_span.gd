extends RefCounted
## THE CHAIN SPAN (the world pass): the Order's chain-way over a gulf of the Far Reaches, 56 m between two gate pylons, its
## deck slung on four iron cables from piers 10 m above the road. Lore: a keeper was posted at the midspan to light
## the lamps for travellers; the keeper's brazier is still lit and the keeper is not accounted for.
##   - found by scanning the Far Reaches (outside the old Marches) for the deepest dry-ended gulf 56 m across that
##     touches no town, way or registered site (WK.taken); failing that, the flattest open ground (the pylons just
##     rise higher): the span always exists
##   - two gate pylons (twin piers 2.6 m square, a lintel, a cap with a fire on each pier: four fires), ramps up
##     to the deck from both ends, the deck of boards sagging 2.4 m to the middle
##   - four cables in 24 iron prisms with diagonal hangers, rails, lanterns every 8 m
##   - the midspan platform: widened deck, a brazier, a bench, a chest (iron); a toll hut at one end (chest, lamp)
## Built once from the kit. Reads from afar as four fires in a row and a line of lanterns hung across the dark.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

const ALLOW := ["greyfell", "lanternwood", "kingsbarrows", "reedmere", "fallow", "arches", "southwood", "bellfall", "lastlight", "nave", "cairns"]
const LEN := 56.0
const SAG := 2.4

var k: WK
var a := Vector3.ZERO                    ## the deck's west end (world, y = deck level)
var d := Vector3.RIGHT                   ## along the span
var sd := Vector3.FORWARD                ## across
var yd := 0.0


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var best_s := -INF
	var best := {}
	for q in 70:
		var c := Vector2(rng.randf_range(-362.0, 362.0), rng.randf_range(-140.0, 390.0))
		if Rect2(-262.0, -152.0, 524.0, 394.0).has_point(c):
			continue
		for di in 8:
			var ang := float(di) * PI * 0.25 + 0.2
			var dv := Vector2(cos(ang), sin(ang))
			var pa := c - dv * (LEN * 0.5)
			var pb := c + dv * (LEN * 0.5)
			if not RealmLayout.BOUNDS.grow(-16.0).has_point(pa) or not RealmLayout.BOUNDS.grow(-16.0).has_point(pb):
				continue
			var ha := WK.h(pa.x, pa.y)
			var hb := WK.h(pb.x, pb.y)
			if WK.wet(pa.x, pa.y) or WK.wet(pb.x, pb.y):
				continue
			var mn := INF
			for i in range(1, 14):
				var p := pa.lerp(pb, float(i) / 14.0)
				mn = minf(mn, WK.h(p.x, p.y))
			var sc := minf(ha, hb) - mn - absf(ha - hb) * 0.8
			if sc <= best_s:
				continue
			if WK.taken(c, Vector2(LEN * 0.5 + 10.0, 7.0), ang, ALLOW, 6.0):
				continue
			best_s = sc
			best = {"pos": c, "ang": ang}
	if best.is_empty():
		var f := WK.find_any([Vector2(-330.0, 20.0), Vector2(-330.0, 120.0), Vector2(330.0, 150.0), Vector2(160.0, 330.0), Vector2(-120.0, 340.0)], Vector2(LEN * 0.5 + 10.0, 7.0), [0.0, PI * 0.5, PI * 0.25, -PI * 0.25], ALLOW, 6.0)
		if f.is_empty():
			push_warning("WONDER chain_span: no ground for it in the Far Reaches")
			return
		best = {"pos": f.pos, "ang": f.yaw}
	var c: Vector2 = best.pos
	var ang := float(best.ang)
	var dv := Vector2(cos(ang), sin(ang))
	var pa := c - dv * (LEN * 0.5)
	var pb := c + dv * (LEN * 0.5)
	yd = maxf(WK.h(pa.x, pa.y), WK.h(pb.x, pb.y)) + 1.2
	d = Vector3(dv.x, 0.0, dv.y)
	sd = d.cross(Vector3.UP)
	a = Vector3(pa.x, yd, pa.y)
	k = WK.new()
	k.setup(root, "ChainSpan", 7312)
	var reg := WK.region_at(c)
	k.poi("chain_span", "The Chain Span", "the keeper lit the midspan lamp for travellers, and is still there", reg if reg != "" else "greyfell")
	WK.reserve("wonder_chain_span", c, Vector2(LEN * 0.5 + 12.0, 8.0), ang, minf(WK.h(pa.x, pa.y), WK.h(pb.x, pb.y)) - 8.0, yd + 12.0)
	_pylon(a - d * 0.0, true)
	_pylon(a + d * LEN, false)
	_deck()
	_cables()
	_midspan()
	_toll_hut()
	_dress()
	var n := k.commit()
	print("WONDER chain_span at %s deck %.1f: %d meshes, %d fires, %d lights, %d chests" % [c, yd, n, k.fires, k.lights, k.chests])


## Deck point at fraction t along the span, `lat` across, `up` above the deck line (sagging).
func _pt(t: float, lat: float, up: float) -> Vector3:
	var u := 2.0 * t - 1.0
	return a + d * (t * LEN) + sd * lat + Vector3.UP * (up - SAG * (1.0 - u * u))


func _pylon(at: Vector3, west: bool) -> void:
	var out := -d if west else d
	for s: float in [-1.0, 1.0]:
		var p := at + sd * (s * 3.8)
		var g := WK.h(p.x, p.z) - 0.9
		var top := yd + 9.5
		k.kit.box("stone_big", Vector3(p.x, (g + top) * 0.5, p.z), Vector3(2.8, top - g, 2.8), Basis(sd.normalized(), Vector3.UP, d.normalized()), true, 0.96)
		k.kit.box("ruin_big", Vector3(p.x, top + 0.35, p.z), Vector3(3.5, 0.7, 3.5), Basis(sd.normalized(), Vector3.UP, d.normalized()), true, 0.84)
		k.kit.box("ruin_big", Vector3(p.x, yd + 4.0, p.z), Vector3(3.2, 0.5, 3.2), Basis(sd.normalized(), Vector3.UP, d.normalized()), true, 0.84)
		# a cresset on each pier head
		k.kit.box("iron", Vector3(p.x, top + 1.0, p.z), Vector3(1.3, 0.6, 1.3), Basis.IDENTITY, false, 0.7)
		k.fire(Vector3(p.x, top + 1.3, p.z), 1.5, 3.0)
	# the lintel and the gate beneath it
	var mid := at + Vector3.UP * (yd + 7.4)
	k.kit.box("stone_big", mid, Vector3(9.2, 1.6, 2.4), Basis(sd.normalized(), Vector3.UP, d.normalized()), true, 0.94)
	# the approach: a stair from the ground to the deck outside the gate
	var run0 := at + out * 2.5
	var gh := WK.h(run0.x, run0.z)
	var rise := yd - gh
	var steps := maxi(3, int(ceilf(rise / 0.34)))
	var run := float(steps) * 0.95
	var lo := Vector3(at.x + out.x * (2.5 + run), 0.0, at.z + out.z * (2.5 + run))
	var gl := WK.h(lo.x, lo.z)
	var steps2 := maxi(3, int(ceilf((yd - gl) / 0.34)))
	k.kit.stairs("stone_big", Vector3(lo.x, gl - 0.1, lo.z), Vector3(at.x + out.x * 1.2, yd, at.z + out.z * 1.2), 4.0, steps2, gl - 1.6)


func _deck() -> void:
	var n := 28
	for i in n:
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		var p0 := _pt(t0, 0.0, -0.14)
		var p1 := _pt(t1, 0.0, -0.14)
		k.beam("wood_big", p0 - d * 0.05, p1 + d * 0.05, 4.0, 0.26, true, 0.8 + 0.12 * float(i % 2))
	for s: float in [-1.0, 1.0]:
		for i in n:
			k.beam("iron", _pt(float(i) / float(n), s * 2.05, -0.02), _pt(float(i + 1) / float(n), s * 2.05, -0.02), 0.16, 0.2, false, 0.6)
	# lantern hangers every 8 m on the rails
	for i in 6:
		var t := (float(i) + 0.5) / 6.0
		for s: float in [-1.0, 1.0]:
			var p := _pt(t, s * 2.1, 1.0)
			k.kit.box("iron", p + Vector3.UP * 0.2, Vector3(0.05, 0.4, 0.05), Basis.IDENTITY, false, 0.6)
			k.kit.box("glow", p - Vector3.UP * 0.1, Vector3(0.3, 0.42, 0.3), Basis.IDENTITY, false, 1.0)
			if (i + (0 if s < 0.0 else 1)) % 2 == 0:
				k.lamp(p, Color(1.0, 0.68, 0.38), 0.9, 7.5)


func _cables() -> void:
	var n := 24
	var top := yd + 8.4
	for s: float in [-1.0, 1.0]:
		var prev := a + sd * (s * 3.8) + Vector3.UP * top
		for i in range(1, n + 1):
			var t := float(i) / float(n)
			var u := 2.0 * t - 1.0
			var mid_y := _pt(0.5, 0.0, 0.0).y + 2.6
			var y := top - (top - mid_y) * (1.0 - u * u)
			var cur := a + d * (t * LEN) + sd * (s * 3.8) + Vector3.UP * (y - yd)
			k.tube("iron", prev, cur, 0.17, 0.17, 5, false, 0.62)
			if i % 3 == 0 and i < n:
				k.beam("iron", cur, _pt(t, s * 2.1, 1.0), 0.07, 0.07, false, 0.6)
			prev = cur


func _midspan() -> void:
	# widened deck over t 0.43..0.57
	var p0 := _pt(0.43, 0.0, -0.14)
	var p1 := _pt(0.57, 0.0, -0.14)
	for s: float in [-1.0, 1.0]:
		k.beam("wood_big", p0 + sd * (s * 3.4) - d * 0.05, p1 + sd * (s * 3.4) + d * 0.05, 2.8, 0.26, true, 0.86)
	# the keeper's brazier and bench, and a chest
	var bp := _pt(0.5, -3.4, 0.0)
	k.kit.box("iron", bp + Vector3.UP * 0.45, Vector3(1.0, 0.9, 1.0), Basis.IDENTITY, true, 0.7)
	k.fire(bp + Vector3.UP * 1.0, 1.1, 2.4)
	k.beam("wood_big", _pt(0.47, 3.6, 0.5), _pt(0.53, 3.6, 0.5), 0.5, 0.12, true, 0.82)
	k.kit.box("wood_big", _pt(0.47, 3.6, 0.2), Vector3(0.3, 0.4, 0.3), Basis.IDENTITY, false, 0.8)
	k.kit.box("wood_big", _pt(0.53, 3.6, 0.2), Vector3(0.3, 0.4, 0.3), Basis.IDENTITY, false, 0.8)
	k.chest("chain_span_keeper", "iron", _pt(0.5, 3.6, 0.0), atan2(-sd.x, -sd.z), {"grave_ash": 14, "grave_iron": 2, "relic_fragment": 1})


func _toll_hut() -> void:
	# beside the west gate, off the approach: a hut of planks with a lamp and a chest
	var base := a - d * 7.5 + sd * 6.5
	var g := WK.h(base.x, base.z)
	var b := Basis(sd.normalized(), Vector3.UP, d.normalized())
	k.kit.box("wood_big", Vector3(base.x, g + 0.1, base.z), Vector3(4.2, 0.4, 3.6), b, true, 0.82)
	for s: float in [-1.0, 1.0]:
		k.kit.box("wood_big", Vector3(base.x, g + 1.6, base.z) + sd * (s * 2.0), Vector3(0.25, 2.8, 3.6), b, true, 0.92)
	k.kit.box("wood_big", Vector3(base.x, g + 1.6, base.z) + d * 1.7, Vector3(4.2, 2.8, 0.25), b, true, 0.92)
	k.kit.box("wood_big", Vector3(base.x, g + 3.1, base.z), Vector3(4.8, 0.3, 4.2), b, true, 0.84)
	k.window(Vector3(base.x, g + 1.2, base.z) - d * 1.8, sd, -d, 1.6, 1.2)
	k.lamp(Vector3(base.x, g + 2.2, base.z), Color(1.0, 0.66, 0.36), 1.2, 7.0)
	k.chest("chain_span_toll", "wood", Vector3(base.x, g + 0.3, base.z) + d * 0.9, atan2(-d.x, -d.z), {"grave_ash": 8, "grave_iron": 1})


# --- secondary forms -----------------------------------------------------------------------------------

func _dress() -> void:
	for at: Vector3 in [a, a + d * LEN]:
		var out := -d if at == a else d
		for s: float in [-1.0, 1.0]:
			var p := at + sd * (s * 3.8)
			Dress.rubble(k, Vector3(p.x, WK.h(p.x, p.z), p.z) + out * 3.0, 3.6, 12, "ruin_big")
			Dress.banner(k, Vector3(p.x, yd + 7.4, p.z) + out * 1.45 - sd * 0.8 * s, sd * s, 1.6, 5.0, out)
			Dress.strands(k, Vector3(p.x, yd + 3.8, p.z) - sd * 1.5 * s, Vector3(p.x, yd + 3.8, p.z) + sd * 1.5 * s, 5, 3.0)
		Dress.chain(k, at + sd * -3.4 + Vector3.UP * (yd + 7.0 - 0.0) - Vector3.UP * (-0.0), at + sd * 3.4 + Vector3.UP * yd + Vector3.UP * 7.0, 0.9, 0.2)
	var tb := a - d * 7.5 + sd * 6.5
	var tg := WK.h(tb.x, tb.z)
	Dress.barrel(k, Vector3(tb.x, tg, tb.z) + sd * 3.4, 0.0)
	Dress.barrel(k, Vector3(tb.x, tg, tb.z) + sd * 3.4 + d * 1.0, 0.0, 0.9)
	Dress.crate(k, Vector3(tb.x, tg, tb.z) - sd * 3.2 + d * 0.5, 0.4)
	Dress.rope(k, Vector3(tb.x, tg + 3.0, tb.z) + sd * 2.4, a + sd * 2.1 + Vector3.UP * 0.6 - d * 0.5, 0.8)
	Dress.strands(k, Vector3(tb.x, tg + 3.1, tb.z) - sd * 2.4, Vector3(tb.x, tg + 3.1, tb.z) + sd * 2.4, 6, 1.3)
	for i in 8:
		var t := (float(i) + 0.5) / 8.0
		Dress.crack(k, _pt(t, -1.5, -0.1), _pt(t + 0.04, 1.5, -0.1), 0.1)
	Dress.camp(k, _pt(0.5, 3.6, 0.0) + sd * 0.0 + d * 1.6, 0.3, false)
