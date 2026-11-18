extends RefCounted
## WATER (the world pass): what the Realm's water was missing at its edges.
##   docks     nine jetties at the shores of the lake (the White Pans' water), the Reedmere's meres and the Drowned Nave's mere:
##             a plank deck on piles running out over the water, rail posts, a bollard and a rope, a moored rowboat with an oar,
##             a lantern post (glass + a light under the cap), crates, a net draped on a frame, shore stones (and a chest
##             in the boat on every third)
##   bridges   three plank foot-bridges over the Sorrow where no way crosses it: deck on stone piers, rails, a lamp, abutments
##             that meet the banks
##   fords     two ford marks where the river is shallowest: lines of stepping stones, a staff-post with a lantern
## Found by the shore (a dry cell with water 6 and 10 m ahead in some direction, RealmLand.in_water) and along the river's
## centreline (RealmLayout.RIVER); each is a kit (faded at 150 m), placed off every way and registered site. Build-time only.
## No class_name.

const SELF := "res://core/world/realm/wonders/r39/waterworks.gd"
const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")
const Land := preload("res://core/world/realm/realm_land.gd")

const SHORES := [Rect2(170, 100, 92, 150), Rect2(-370, 236, 150, 160), Rect2(270, 120, 90, 90)]

var _ids: Array = []


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	for reg: Dictionary in RealmLayout.REGIONS:
		_ids.append(String(reg.id))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var docks := 0
	var placed: Array[Vector2] = []
	for r: Rect2 in SHORES:
		var got := 0
		var tries := 0
		while got < 3 and tries < 260:
			tries += 1
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			var dirv := _shore(p)
			if dirv == Vector2.ZERO:
				continue
			var near := false
			for q: Vector2 in placed:
				if q.distance_to(p) < 40.0:
					near = true
			if near or RealmLayout.path_dist(p) < 6.0 or WK.site_hit(Rect2(p - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), 2.0):
				continue
			placed.append(p)
			_dock(root, docks, p, dirv, rng)
			docks += 1
			got += 1
	var br := _bridges(root, rng)
	print("WONDER waterworks: %d docks, %d bridges and fords" % [docks, br])


## A unit direction from dry land `p` out over the water (water 6 m and 10 m ahead, the land at p dry and above the surface), or ZERO.
func _shore(p: Vector2) -> Vector2:
	if Land.in_water(p.x, p.y) or WK.h(p.x, p.y) < Land.water_y_at(p.x, p.y) + 0.15:
		return Vector2.ZERO
	for i in 8:
		var a := TAU * float(i) / 8.0
		var d := Vector2(cos(a), sin(a))
		var a6 := p + d * 6.0
		var a10 := p + d * 10.0
		if Land.in_water(a6.x, a6.y) and Land.in_water(a10.x, a10.y):
			var a2 := p + d * 2.0
			if not Land.in_water(a2.x, a2.y):
				return d
	return Vector2.ZERO


func _dock(root: Node, i: int, p: Vector2, d: Vector2, rng: RandomNumberGenerator) -> void:
	var k := WK.new()
	k.setup(root, "Dock%d" % i, 6200 + i)
	var wl := Land.water_y_at(p.x, p.y)
	var deck := wl + 0.6
	var d3 := Vector3(d.x, 0.0, d.y)
	var s3 := d3.cross(Vector3.UP)
	var b := Basis(s3, Vector3.UP, d3)
	var o := Vector3(p.x, 0.0, p.y)
	var ln := 11.0
	if not k.cached(WK.fp(SELF, [i, p, d, deck, WK.tsig(p, 12.0)])):
		# the deck: planks on stringers, piles every 2.4 m down to the bed, rails on one side
		for j in int(ln / 1.1):
			var v := 1.0 + 1.1 * float(j)
			var c := o + d3 * v
			k.kit.box("wood_big", Vector3(c.x, deck, c.z), Vector3(2.4, 0.14, 1.0), b, true, 0.7 + 0.2 * k.rng.randf())
		var gy := WK.h(p.x, p.y)
		k.kit.box("wood_big", Vector3(o.x + d3.x * 0.0, (gy + deck) * 0.5, o.z + d3.z * 0.0), Vector3(2.4, maxf(deck - gy, 0.3), 1.4), b, true, 0.7)
		for j in 5:
			var v := 1.2 + 2.4 * float(j)
			for sgn: float in [-1.0, 1.0]:
				var c := o + d3 * v + s3 * (sgn * 1.05)
				var bed := WK.h(c.x, c.z) - 0.6
				k.tube("wood_big", Vector3(c.x, bed, c.z), Vector3(c.x, deck + (0.9 if sgn > 0.0 else 0.35), c.z), 0.12, 0.11, 6, true, 0.65)
			if sgn_rail(j):
				var c1 := o + d3 * v + s3 * 1.05
				var c2 := o + d3 * (v + 2.4) + s3 * 1.05
				k.beam("wood_big", Vector3(c1.x, deck + 0.8, c1.z), Vector3(c2.x, deck + 0.8, c2.z), 0.08, 0.08, false, 0.7)
		# bollard and rope, the lantern post at the head, crates, a net on a frame
		var end := o + d3 * (ln - 0.6)
		k.tube("wood_big", Vector3(end.x, deck, end.z) + s3 * -0.9, Vector3(end.x, deck + 0.7, end.z) + s3 * -0.9, 0.12, 0.1, 6, false, 0.6)
		var lp := o + d3 * (ln - 0.3) + s3 * 1.05
		k.tube("wood_big", Vector3(lp.x, deck, lp.z), Vector3(lp.x, deck + 2.6, lp.z), 0.07, 0.06, 5, false, 0.65)
		k.kit.lantern(Vector3(lp.x, deck + 2.75, lp.z), Vector3(0.3, 0.4, 0.3), b)
		k.lamp(Vector3(lp.x, deck + 2.7, lp.z), Color(1.0, 0.7, 0.4), 0.9, 8.0)
		Dress.crate(k, Vector3(o.x, deck + 0.07, o.z) + d3 * 2.4 - s3 * 0.7, k.rng.randf() * TAU, 0.8)
		Dress.barrel(k, Vector3(o.x, deck + 0.07, o.z) + d3 * 3.4 - s3 * 0.8, 0.0, 0.9)
		var nf := o + d3 * 1.2 + s3 * 2.4
		k.tube("wood_big", Vector3(nf.x, WK.h(nf.x, nf.z), nf.z), Vector3(nf.x, WK.h(nf.x, nf.z) + 2.2, nf.z), 0.07, 0.07, 4, false, 0.65)
		var nf2 := nf + d3 * 3.0
		k.tube("wood_big", Vector3(nf2.x, WK.h(nf2.x, nf2.z), nf2.z), Vector3(nf2.x, WK.h(nf2.x, nf2.z) + 2.2, nf2.z), 0.07, 0.07, 4, false, 0.65)
		Dress.rope(k, Vector3(nf.x, WK.h(nf.x, nf.z) + 2.1, nf.z), Vector3(nf2.x, WK.h(nf2.x, nf2.z) + 2.1, nf2.z), 0.4, 0.03)
		Dress.strands(k, Vector3(nf.x, WK.h(nf.x, nf.z) + 2.05, nf.z), Vector3(nf2.x, WK.h(nf2.x, nf2.z) + 2.05, nf2.z), 9, 1.5, "wood_big")
		# the boat alongside: a shallow hull of planks on the water, an oar, a lantern
		var bc := o + d3 * 6.0 - s3 * 2.4
		for j in 5:
			var w := 0.55 - 0.1 * absf(float(j) - 2.0)
			var cc := bc + d3 * (float(j) * 0.8 - 1.6)
			k.kit.box("wood_big", Vector3(cc.x, wl + 0.05, cc.z), Vector3(w * 2.0, 0.12, 0.75), b, false, 0.65)
			for sgn: float in [-1.0, 1.0]:
				k.kit.box("wood_big", Vector3(cc.x, wl + 0.3, cc.z) + s3 * (sgn * w), Vector3(0.07, 0.5, 0.75), b * Basis(Vector3.FORWARD, sgn * 0.3), false, 0.6)
		k.beam("wood_big", Vector3(bc.x, wl + 0.5, bc.z) - s3 * 0.5, Vector3(bc.x, wl + 0.15, bc.z) + d3 * 1.8 + s3 * 0.5, 0.06, 0.04, false, 0.6)
		if i % 3 == 0:
			k.chest("dock_boat_%d" % i, "wood", Vector3(bc.x, wl + 0.2, bc.z), atan2(d3.x, d3.z), {"grave_ash": 8, "grave_iron": 1})
		# shore stones, half in the water, round the root of the dock
		for j in 7:
			var q := o - d3 * k.rng.randf_range(-1.0, 2.0) + s3 * k.rng.randf_range(-4.5, 4.5)
			Dress.rubble(k, Vector3(q.x, WK.h(q.x, q.z), q.z), 0.8, 2, "cave_moss")
	k.commit(150.0)


func sgn_rail(j: int) -> bool:
	return j < 4


## Three plank bridges and two fords on the Sorrow where no way crosses it.
## A registered site that is not a way's own (a flight, a lane) touching the box: the bridge stands on its way, so the way's site is no obstacle.
func _site_near(box: Rect2) -> bool:
	for st: Dictionary in WorldLanes.sites:
		if st.has("seg") or String(st.name).contains("lane") or String(st.name).contains("way"):
			continue
		if WorldLanes.site_hits_rect(st, box, 1.0):
			return true
	return false


func _bridges(root: Node, rng: RandomNumberGenerator) -> int:
	var pts: Array = RealmLayout.RIVER.pts
	var made := 0
	var want := ["bridge", "ford", "bridge", "ford", "bridge"]
	var t := {}
	var taken: Array[Vector2] = []
	var tried := 0
	var cands: Array = []                  # every river segment at five fractions, the middle ones first: the whole Sorrow is in reach
	for f: float in [0.5, 0.25, 0.75, 0.1, 0.9]:
		for i in range(pts.size() - 1):
			cands.append([i, f])
	for ce: Array in cands:
		if made >= want.size():
			break
		tried += 1
		var a: Vector2 = pts[int(ce[0])]
		var bq: Vector2 = pts[int(ce[0]) + 1]
		var m := a.lerp(bq, float(ce[1]))
		var t2 := (bq - a).normalized()
		var n := Vector2(-t2.y, t2.x)
		var close := false
		for q: Vector2 in taken:
			if q.distance_to(m) < 45.0:
				close = true
		if close:
			WK.rej(t, "spacing")
			continue
		var ea := m - n * 7.0
		var eb := m + n * 7.0
		if Land.in_water(ea.x, ea.y) or Land.in_water(eb.x, eb.y):
			WK.rej(t, "bank")
			continue
		if _site_near(Rect2(m - Vector2(9.0, 9.0), Vector2(18.0, 18.0))):
			WK.rej(t, "site")
			continue
		taken.append(m)
		var k := WK.new()
		k.setup(root, "River%d" % made, 6300 + made)
		var ya := WK.h(ea.x, ea.y)
		var yb := WK.h(eb.x, eb.y)
		var wl := Land.water_y_at(m.x, m.y)
		var deck := maxf(maxf(ya, yb), wl) + 0.45
		var d3 := Vector3(n.x, 0.0, n.y)
		var s3 := d3.cross(Vector3.UP)
		var b := Basis(s3, Vector3.UP, d3)
		var mid3 := Vector3(m.x, 0.0, m.y)
		if not k.cached(WK.fp(SELF, [String(want[made]), m, deck, WK.tsig(m, 10.0)])):
			if String(want[made]) == "bridge":
				for j in 14:
					var c := mid3 - d3 * 7.0 + d3 * (0.5 + 1.0 * float(j))
					k.kit.box("wood_big", Vector3(c.x, deck, c.z), Vector3(2.2, 0.16, 1.05), b, true, 0.7 + 0.2 * k.rng.randf())
				for j in 4:
					var c2 := mid3 - d3 * 5.2 + d3 * (3.4 * float(j))
					for sgn: float in [-1.0, 1.0]:
						var pp := c2 + s3 * (sgn * 0.95)
						var bed := WK.h(pp.x, pp.z) - 0.8
						k.kit.box("stone_big", Vector3(pp.x, (bed + deck) * 0.5, pp.z), Vector3(0.7, deck - bed, 0.7), b, true, 0.85)
				for sgn: float in [-1.0, 1.0]:
					var r1 := mid3 - d3 * 6.5 + s3 * (sgn * 1.1)
					var r2 := mid3 + d3 * 6.5 + s3 * (sgn * 1.1)
					k.beam("wood_big", Vector3(r1.x, deck + 0.95, r1.z), Vector3(r2.x, deck + 0.95, r2.z), 0.08, 0.08, true, 0.7)
					for j in 5:
						var rp := r1.lerp(r2, float(j) / 4.0)
						k.tube("wood_big", Vector3(rp.x, deck, rp.z), Vector3(rp.x, deck + 1.0, rp.z), 0.06, 0.06, 4, false, 0.65)
				for sgn: float in [-1.0, 1.0]:
					var ab := mid3 + d3 * (sgn * 7.4)
					var gy := WK.h(ab.x, ab.z)
					k.kit.box("stone_big", Vector3(ab.x, (gy - 0.6 + deck) * 0.5, ab.z), Vector3(2.8, deck - gy + 0.6, 1.4), b, true, 0.85)
				var lp := mid3 + s3 * 1.1
				k.tube("wood_big", Vector3(lp.x, deck, lp.z), Vector3(lp.x, deck + 2.4, lp.z), 0.06, 0.05, 4, false, 0.65)
				k.kit.lantern(Vector3(lp.x, deck + 2.5, lp.z), Vector3(0.28, 0.36, 0.28), b)
				k.lamp(Vector3(lp.x, deck + 2.5, lp.z), Color(1.0, 0.7, 0.4), 0.8, 8.0)
			else:
				for j in 9:
					var c := mid3 - d3 * 6.0 + d3 * (1.4 * float(j)) + s3 * (0.4 * sin(float(j) * 1.7))
					k.kit.box("stone_big", Vector3(c.x, wl + 0.1, c.z), Vector3(0.9, 0.5, 0.8), Basis(Vector3.UP, float(j)), true, 0.8)
				var sp := mid3 + d3 * 7.0 + s3 * 1.6
				k.tube("wood_big", Vector3(sp.x, WK.h(sp.x, sp.z), sp.z), Vector3(sp.x, WK.h(sp.x, sp.z) + 2.4, sp.z), 0.07, 0.06, 4, false, 0.65)
				k.kit.lantern(Vector3(sp.x, WK.h(sp.x, sp.z) + 2.5, sp.z), Vector3(0.26, 0.34, 0.26), b)
		WK.reserve("river_cross_%d" % made, m, Vector2(8.0, 8.0), 0.0, minf(ya, yb) - 2.0, deck + 4.0)
		k.commit(150.0)
		made += 1
	print("WONDER waterworks bridges/fords: %d of %d (%d candidates tried); rejected: %s" % [made, want.size(), tried, WK.rejected(t)])
	return made
