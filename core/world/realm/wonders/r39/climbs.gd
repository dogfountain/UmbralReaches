extends RefCounted
## CLIMBS (the world pass: verticality with a reason): twelve places to go up, each ending in a view and a find.
##   broken towers  six open, ruined watchtowers (a 6 m square shaft, 13 m, its walls breached, an outside stair of two
##                  flights with a landing climbing two faces, a top deck with a parapet gap, a fire in a ring, a chest) in the
##                  wild ground off the ways
##   cliff stairs   six stairs cut up steep ground (8-16 m of rise over ~26 m, rails on both sides, a landing half way with a
##                  lantern), ending on a viewpoint platform with a stone seat, a post lantern and a chest
## Stairs are the kit's (ramp collision under each tread), the ground over a cliff stair is cut by a WorldLanes flight, every
## step 0.36 m or less; each place is a kit (faded at 150 m), a discovery (world_poi), and sets group `climb` with `find_at`.
## Found by sampling: towers on flat dry ground 50+ m off every way (WK.find_any); stairs where the ground rises 8+ m over 26 m.
## Build-time only. No class_name.

const SELF := "res://core/world/realm/wonders/r39/climbs.gd"
const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

var _placed: Array[Vector2] = []


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7272
	var tt := {}
	var towers := 0
	var tried := 0
	for c: Vector2 in WK.grid(7272, 30.0, 24.0):
		if towers >= 6:
			break
		tried += 1
		if not _free(c, 12.0, 70.0, tt):
			continue
		if WK.wet(c.x, c.y):
			WK.rej(tt, "water")
			continue
		if WK.in_town(c, 10.0):
			WK.rej(tt, "town")
			continue
		if WK.site_hit(Rect2(c - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), 1.0):
			WK.rej(tt, "site")
			continue
		var f := WK.place_first([c], Vector2(6.0, 6.0), [0.0], 3.0)
		if bool(f.get("site", true)):
			WK.rej(tt, "site")
			continue
		_tower(root, towers, f.pos, float(f.lo), float(f.hi), rng)
		_placed.append(f.pos)
		towers += 1
	print("WONDER climbs towers: %d of 6 (%d candidates tried); rejected: %s" % [towers, tried, WK.rejected(tt)])
	# cliff stairs: every 12 m grid point is a foot; the first of eight directions that climbs 8-16 m over 26 m (then 5-16 m if too few) is the stair
	var st := {}
	var stairs := 0
	tried = 0
	var feet := WK.grid(7273, 12.0, 30.0)
	for min_rise: float in [8.0, 5.0]:
		for p: Vector2 in feet:
			if stairs >= 6:
				break
			tried += 1
			if not _free(p, 10.0, 70.0, st):
				continue
			if WK.wet(p.x, p.y):
				WK.rej(st, "water")
				continue
			var base_y := WK.h(p.x, p.y)
			var made := false
			for q in 8:
				var a := TAU * float(q) / 8.0 + p.x
				var d := Vector2(cos(a), sin(a))
				var top := p + d * 26.0
				if WK.wet(top.x, top.y) or not RealmLayout.BOUNDS.grow(-14.0).has_point(top):
					continue
				var rise := WK.h(top.x, top.y) - base_y
				if rise < min_rise or rise > 16.0:
					continue
				if WK.site_hit(Rect2(top - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), 2.0) or WK.site_hit(Rect2(p - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), 2.0):
					WK.rej(st, "site")
					continue
				_stair(root, stairs, p, top, rng)
				_placed.append(p)
				stairs += 1
				made = true
				break
			if not made:
				WK.rej(st, "rise")
		if stairs >= 6:
			break
	print("WONDER climbs stairs: %d of 6 (%d feet tried); rejected: %s" % [stairs, tried, WK.rejected(st)])


func _free(c: Vector2, path_min: float, spacing: float, t: Dictionary) -> bool:
	if RealmLayout.path_dist(c) < path_min:
		return WK.rej(t, "way")
	for q: Vector2 in _placed:
		if q.distance_to(c) < spacing:
			return WK.rej(t, "spacing")
	return true


func _tower(root: Node, i: int, c: Vector2, lo: float, hi: float, rng: RandomNumberGenerator) -> void:
	var k := WK.new()
	k.setup(root, "ClimbTower%d" % i, 7400 + i)
	var reg := WK.region_at(c)
	k.poi("climb_tower_%d" % i, "A Broken Watchtower", "a stair on its outside, and the whole valley from the top", reg if reg != "" else "road")
	k.host.add_to_group("climb")
	WK.reserve("climb_tower_%d" % i, c, Vector2(8.0, 8.0), 0.0, lo, hi + 16.0)
	var y0 := hi + 0.2
	var low := lo - 0.9
	var b := Basis.IDENTITY
	var o := Vector3(c.x, y0, c.y)
	if not k.cached(WK.fp(SELF, ["tower", i, o, WK.tsig(c, 10.0)])):
		k.kit.box("stone_big", Vector3(o.x, (low + y0) * 0.5, o.z), Vector3(7.4, y0 - low, 7.4), b, true, 0.86)
		# the shaft: four walls 0.9 thick, breached (one low section, a window slit each side), 13 m
		var h := 13.0
		k.kit.box("stone_big", o + Vector3(0.0, h * 0.5, -3.0), Vector3(6.0, h, 0.9), b, true, 0.98)
		k.kit.box("stone_big", o + Vector3(0.0, h * 0.5 - 2.0, 3.0), Vector3(6.0, h - 4.0, 0.9), b, true, 0.98)
		k.kit.box("stone_big", o + Vector3(-3.0, h * 0.5, 0.0), Vector3(0.9, h, 5.2), b, true, 0.98)
		k.kit.box("stone_big", o + Vector3(3.0, h * 0.5 - 3.0, 0.0), Vector3(0.9, h - 6.0, 5.2), b, true, 0.98)
		for j in 4:
			var ry := h - 0.5 - 0.8 * float(j)
			k.kit.box("ruin_big", o + Vector3(-1.2 + 1.3 * float(j % 2), ry + 0.8, 3.0), Vector3(1.2, 0.8, 0.9), b, true, 0.8)      # broken merlons
		k.window(o + Vector3(0.0, 6.0, -3.46), Vector3.RIGHT, Vector3.FORWARD, 0.7, 1.6)
		k.window(o + Vector3(-3.46, 8.0, 0.0), Vector3.BACK, Vector3.LEFT, 0.7, 1.6)
		k.lamp(o + Vector3(0.0, 6.4, -3.7), Color(1.0, 0.66, 0.36), 1.0, 8.0)
		# the outside stair: flight A up the south face (z -3.9) from the ground to a landing at 6 m, flight B up the east face to the
		# deck at 12.2 m
		var ga := WK.h(c.x - 3.0, c.y - 8.0)
		k.kit.stairs("stone_big", Vector3(o.x - 3.0, ga + 0.1, o.z - 8.4), Vector3(o.x - 3.0, y0 + 6.0, o.z - 4.4), 1.8, int(ceilf((y0 + 6.0 - ga) / 0.36)), ga - 0.8)
		k.kit.box("stone_big", o + Vector3(0.5, 5.8, -4.9), Vector3(10.0, 0.4, 2.0), b, true, 0.9)
		k.kit.box("stone_big", o + Vector3(-3.0, 3.0, -4.4), Vector3(0.8, 6.0, 0.8), b, true, 0.85)
		k.kit.box("stone_big", o + Vector3(4.8, 3.0, -5.4), Vector3(0.8, 6.0, 0.8), b, true, 0.85)
		k.kit.stairs("stone_big", Vector3(o.x + 4.6, y0 + 6.0, o.z - 4.9), Vector3(o.x + 4.6, y0 + 12.0, o.z + 5.0), 1.8, int(ceilf(6.0 / 0.36)), y0 + 5.6)
		# the deck: slabs across the top, a platform at the stair's head joined to it, a parapet in pieces, a fire in a ring, the chest
		k.kit.box("wood_big", o + Vector3(0.0, 11.85, 0.0), Vector3(5.2, 0.3, 4.4), b, true, 0.8)
		for zz: float in [-2.4, 2.4]:
			k.kit.box("ruin_big", o + Vector3(0.0, 11.45, zz), Vector3(5.2, 0.5, 0.6), b, true, 0.8)
		k.kit.box("wood_big", o + Vector3(3.9, 11.85, 2.4), Vector3(3.2, 0.3, 5.2), b, true, 0.8)
		for j in 6:
			var a := TAU * float(j) / 6.0
			k.kit.box("stone_big", o + Vector3(cos(a) * 1.2, 12.2, sin(a) * 1.2 + 0.2), Vector3(0.5, 0.35, 0.4), Basis(Vector3.UP, a), false, 0.8)
		k.fire(o + Vector3(0.0, 12.5, 0.2), 0.8, 1.6)
		k.chest("climb_tower_%d" % i, "iron", o + Vector3(-1.8, 12.0, 1.4), 0.5, {"grave_ash": 14 + i, "grave_iron": 2, "relic_fragment": 1 if i % 2 == 0 else 0})
		Dress.rubble(k, o + Vector3(5.0, 0.0, 3.0), 3.0, 12, "ruin_big")
		Dress.rubble(k, o + Vector3(-4.8, 0.0, 4.2), 2.5, 10, "ruin_big")
		Dress.strands(k, o + Vector3(-3.2, 11.0, -3.5), o + Vector3(3.2, 11.0, -3.5), 7, 3.0)
		Dress.banner(k, o + Vector3(-3.0, 11.8, 3.5), Vector3.RIGHT, 1.8, 3.6, Vector3.BACK)
	k.host.set_meta("find_at", o + Vector3(-1.8, 12.0, 1.4))
	k.commit(150.0)


func _stair(root: Node, i: int, p: Vector2, top: Vector2, rng: RandomNumberGenerator) -> void:
	var k := WK.new()
	k.setup(root, "ClimbStair%d" % i, 7500 + i)
	var reg := WK.region_at(p)
	k.poi("climb_stair_%d" % i, "A Cut Stair", "someone wanted to see from up there", reg if reg != "" else "road")
	k.host.add_to_group("climb")
	var d := (top - p).normalized()
	var d3 := Vector3(d.x, 0.0, d.y)
	var s3 := d3.cross(Vector3.UP)
	var b := Basis(s3, Vector3.UP, d3)
	var yb := WK.h(p.x, p.y)
	var yt := WK.h(top.x, top.y) + 0.4
	var a3 := Vector3(p.x, yb, p.y)
	var t3 := Vector3(top.x, yt, top.y)
	WorldLanes.register_flight("climb_stair_%d" % i, a3, t3, 2.4)
	WK.reserve("climb_top_%d" % i, top, Vector2(4.0, 4.0), 0.0, yt - 3.0, yt + 6.0, 0.0)
	if not k.cached(WK.fp(SELF, ["stair", i, a3, t3, WK.tsig(p.lerp(top, 0.5), 16.0)])):
		var steps := int(ceilf((yt - yb) / 0.36))
		k.kit.stairs("stone_big", a3, t3, 2.6, steps, yb - 1.0)
		for j in 8:
			var t := (float(j) + 0.5) / 8.0
			var m := a3.lerp(t3, t)
			for sgn: float in [-1.0, 1.0]:
				var c := m + s3 * (sgn * 1.55)
				k.kit.box("stone_big", Vector3(c.x, m.y + 0.6, c.z), Vector3(0.3, 1.4, a3.distance_to(t3) / 8.0 + 0.05), b * Basis(Vector3.RIGHT, -atan2(yt - yb, 26.0)), false, 0.9)
		# a landing half way with a lantern post
		var mid := a3.lerp(t3, 0.5)
		k.kit.box("stone_big", Vector3(mid.x, mid.y - 0.1, mid.z), Vector3(3.2, 0.3, 2.2), b, true, 0.9)
		k.tube("iron", Vector3(mid.x, mid.y, mid.z) + s3 * 1.5, Vector3(mid.x, mid.y + 2.4, mid.z) + s3 * 1.5, 0.05, 0.05, 4, false, 0.6)
		k.kit.box("glow", Vector3(mid.x, mid.y + 2.5, mid.z) + s3 * 1.5, Vector3(0.26, 0.36, 0.26), b, false, 1.0)
		k.lamp(Vector3(mid.x, mid.y + 2.5, mid.z) + s3 * 1.5, Color(1.0, 0.7, 0.4), 0.8, 8.0)
		# the viewpoint: a platform, a rail on the drop side, a stone seat, a lantern post, a chest
		k.kit.box("stone_big", Vector3(t3.x + d3.x * 3.0, yt - 0.5, t3.z + d3.z * 3.0), Vector3(7.0, 1.0, 7.0), b, true, 0.9)
		for sgn: float in [-1.0, 1.0]:
			k.kit.box("stone_big", t3 + d3 * 6.0 + s3 * (sgn * 2.2) + Vector3.UP * 0.3, Vector3(2.4, 0.8, 0.3), b, true, 0.85)
		k.kit.box("stone_big", t3 + d3 * 5.2 + Vector3.UP * 0.1, Vector3(2.2, 0.5, 0.8), b, true, 0.9)
		k.tube("iron", t3 + d3 * 3.0 + s3 * 3.0, t3 + d3 * 3.0 + s3 * 3.0 + Vector3.UP * 3.0, 0.06, 0.05, 4, false, 0.6)
		k.kit.box("glow", t3 + d3 * 3.0 + s3 * 3.0 + Vector3.UP * 3.15, Vector3(0.3, 0.4, 0.3), b, false, 1.0)
		k.lamp(t3 + d3 * 3.0 + s3 * 3.0 + Vector3.UP * 3.1, Color(1.0, 0.7, 0.4), 1.0, 10.0)
		k.chest("climb_stair_%d" % i, "iron", t3 + d3 * 2.6 - s3 * 2.2 + Vector3.UP * 0.1, atan2(-d3.x, -d3.z), {"grave_ash": 12 + i, "grave_iron": 2})
		Dress.rubble(k, t3 + d3 * 7.0, 2.0, 8, "ruin_big")
	k.host.set_meta("find_at", t3 + d3 * 2.6 - s3 * 2.2)
	k.commit(150.0)
