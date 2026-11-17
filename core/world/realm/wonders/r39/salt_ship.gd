extends RefCounted
## THE SALT SHIP (the world pass): a two-masted merchantman of the Order's salt fleet, 44 m long, stranded on the White Pans
## far from any water, heeled 9 degrees on the salt it sailed in on. Lore: the pans were a bay once; the
## Order's salt fleet was loading the night the sky began to turn, and the tide went out for good. The salt crept
## up the hull and the crew's lamps are still lit.
##   - the hull: 23 stations x 5 levels of flat-shaded planking (some strakes rotted away, the ribs showing), a
##     keel, gunwale caps, an anchor-less bow; salt drifts piled against the low side, timber shores on the high
##   - the deck: boards fore and aft with a four-metre hatch open on the hold; a plank ramp to a breach in the
##     low bulwark; the stern castle (a cabin under, a roof deck over, steps up) with a lit stern window and a
##     sternpost lantern (a fire 14 m up); the stub of the mainmast with a yard and a torn pale sail, a masthead lamp
##   - the hold: a floor, a stair down from the hatch, a lamp, a chest (reliquary); the cabin: a chest (iron)
## From the road: a pale ship on the white flats with a fire at the stern. Placed by WK.find_any on the Pans (the
## flats beside the star crater); a site reserved so the flora and the wayside keep off.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

const CANDS := [Vector2(214.0, 196.0), Vector2(196.0, 214.0), Vector2(232.0, 170.0), Vector2(240.0, 220.0), Vector2(188.0, 176.0)]
const HALF := Vector2(14.0, 28.0)
const SELF := "res://core/world/realm/wonders/r39/salt_ship.gd"
const N := 22
const HALF_LEN := 22.0
const LEVELS := 4
const ROLL := 0.16
const PITCH := -0.05

var k: WK
var base := Vector3.ZERO
var rot := Basis.IDENTITY
var lvl := 0.0
var _drop := {}


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


static func _gun(s: float) -> float:
	return 5.8 + (3.0 * s * s if s < 0.0 else 2.2 * s * s)


static func _ww(s: float) -> float:
	var e := 3.2 if s < 0.0 else 2.4
	return 5.4 * pow(maxf(0.0, 1.0 - pow(absf(s), e)), 0.55)


## Half width and height of the hull at station s (-1 stern .. 1 bow), level fraction f (0 keel .. 1 gunwale).
static func _sec(s: float, f: float) -> Vector2:
	return Vector2(_ww(s) * (0.16 + 0.84 * pow(f, 0.6)), f * _gun(s))


func _w(x: float, y: float, z: float) -> Vector3:
	return base + rot * Vector3(x, y, z)


func _run(root: Node) -> void:
	# the footprint is long along z; the yaw options turn it every which way across the flats
	var f := WK.place(CANDS, HALF, [0.0, PI * 0.5, PI * 0.25, -PI * 0.25], 3.0)
	var yaw := float(f.yaw)
	var mid: Vector2 = f.pos
	# the ship's z axis lies along the footprint's long side
	rot = Basis(Vector3.UP, -yaw) * Basis(Vector3(0.0, 0.0, 1.0), ROLL) * Basis(Vector3.RIGHT, PITCH)
	# the lowest point of the keel, so the hull rests on the flats
	var low := INF
	for i in range(0, N + 1):
		var s := -1.0 + 2.0 * float(i) / float(N)
		for sx: float in [-1.0, 0.0, 1.0]:
			var sec := _sec(s, 0.0)
			low = minf(low, (rot * Vector3(sx * sec.x, sec.y, s * HALF_LEN)).y)
	lvl = (float(f.lo) + float(f.hi)) * 0.5
	base = Vector3(mid.x, lvl + 0.15 - low, mid.y)
	WorldLanes.register_terrace("wonder_salt_ship", mid, 31.0, lvl)          # the flats are levelled under the hull (the stamp), so the ship never floats or sinks
	WK.reserve("wonder_salt_ship_site", mid, HALF, yaw, lvl - 1.0, lvl + 18.0)
	k = WK.new()
	k.setup(root, "SaltShip", 5233)
	k.poi("salt_ship", "The Salt Ship", "the tide went out and the lamps were left burning", "saltpans")
	if not k.cached(WK.fp(SELF, [mid, yaw, lvl])):
		_hull()
		_deck()
		_stern()
		_mast()
		_drifts(mid)
		_dress(mid)
	var n: int = k.commit()
	var hp: Array[Vector3] = [_w(-3.4, 0.8, -12.0), _w(3.4, 4.0, -12.0), _w(-3.4, 4.0, 12.0), _w(3.4, 0.8, 12.0)]
	WK.acoustic(hp, "cave", "ship's hold")
	k.far(150.0, 0.25, Color(0.55, 0.56, 0.6))
	k.beacon(_w(0.0, 14.0, -21.0), Color(1.0, 0.7, 0.42), 1.2, 10.0, 360.0)
	print("WONDER salt_ship at %s datum %.1f: %d meshes, %d fires, %d lights, %d chests" % [mid, base.y, n, k.fires, k.lights, k.chests])


func _pt(i: int, j: int, sx: float) -> Vector3:
	var s := -1.0 + 2.0 * float(i) / float(N)
	var sec := _sec(s, float(j) / float(LEVELS))
	return _w(sx * sec.x, sec.y, s * HALF_LEN)


func _hull() -> void:
	var rng: RandomNumberGenerator = k.rng
	for i in N:
		for sx: float in [-1.0, 1.0]:
			for j in LEVELS:
				var s := -1.0 + 2.0 * (float(i) + 0.5) / float(N)
				var z := s * HALF_LEN
				# strakes rotted away: the upper levels, away from the bow and the stern posts, never the keel
				var lost := false
				if j >= 1 and i >= 3 and i <= N - 4:
					lost = rng.randf() < (0.16 if j == LEVELS - 1 else 0.1)
				# the breach in the low bulwark (the ramp's gap)
				if sx < 0.0 and j >= LEVELS - 1 and z > -11.0 and z < -5.0:
					lost = true
				var a := _pt(i, j, sx)
				var b := _pt(i + 1, j, sx)
				var c := _pt(i + 1, j + 1, sx)
				var d := _pt(i, j + 1, sx)
				var out := rot * Vector3(sx, -0.25, 0.0)
				if not lost:
					k.kit.quad("wood_big", a, b, c, d, out, true, 0.7 + 0.2 * rng.randf())
					k.kit.quad("wood_big", a, b, c, d, -out, false, 0.5)
			# ribs
		if i % 2 == 0:
			for sx: float in [-1.0, 1.0]:
				for j in LEVELS:
					var a := _pt(i, j, sx)
					var b := _pt(i, j + 1, sx)
					var rsec := _sec(-1.0 + 2.0 * float(i) / float(N), 0.5)
					var thick := 0.34 if rsec.x > 0.5 else 0.2
					k.beam("wood_big", a, b, 0.34, thick, false, 0.6)
	# the keel and the sternpost, stem
	for i in N:
		var a0 := _pt(i, 0, 0.0)
		var b0 := _pt(i + 1, 0, 0.0)
		k.beam("wood_big", a0 - Vector3.UP * 0.05, b0 - Vector3.UP * 0.05, 0.5, 0.5, true, 0.55)
	# gunwale caps
	for i in N:
		for sx: float in [-1.0, 1.0]:
			if sx < 0.0 and i >= 8 and i <= 12:
				continue
			k.beam("wood_big", _pt(i, LEVELS, sx), _pt(i + 1, LEVELS, sx), 0.42, 0.18, false, 0.75)
	# the bowsprit
	var bow := _pt(N, LEVELS, 0.0)
	k.tube("wood_big", bow - rot * Vector3(0.0, 1.0, 0.0), bow + rot * Vector3(0.0, 2.6, 7.0), 0.4, 0.18, 6, false, 0.7)


func _yd(s: float) -> float:
	return 0.78 * _gun(s)


func _deck() -> void:
	var rng: RandomNumberGenerator = k.rng
	# deck boards, tilted along the sheer
	for i in N:
		if i == 10 or i == 11:
			continue                           # the hatch
		var sa := -1.0 + 2.0 * float(i) / float(N)
		var sb := -1.0 + 2.0 * float(i + 1) / float(N)
		if i >= N - 3 and rng.randf() < 0.5:
			continue                           # rotted out forward
		var ya := _yd(sa)
		var yb := _yd(sb)
		var wd := _sec((sa + sb) * 0.5, 0.78).x - 0.25
		var za := sa * HALF_LEN
		var zb := sb * HALF_LEN
		var cen := _w(0.0, (ya + yb) * 0.5 - 0.14, (za + zb) * 0.5)
		var bs := rot * Basis(Vector3.RIGHT, -atan2(yb - ya, zb - za))
		k.kit.box("wood_big", cen, Vector3(wd * 2.0, 0.28, (zb - za) + 0.06), bs, true, 0.78 + 0.15 * float(i % 2))
	# the hatch's coaming and the hold below it
	var hc := _w(0.0, _yd(0.0) + 0.2, 0.0)
	for sz: float in [-1.0, 1.0]:
		k.kit.box("wood_big", hc + rot * Vector3(0.0, 0.0, sz * 2.1), Vector3(3.6, 0.5, 0.2), rot, false, 0.7)
	for sx: float in [-1.0, 1.0]:
		k.kit.box("wood_big", hc + rot * Vector3(sx * 1.9, 0.0, 0.0), Vector3(0.2, 0.5, 4.2), rot, false, 0.7)
	for i in range(3, N - 3):
		var sa := -1.0 + 2.0 * float(i) / float(N)
		var sb := -1.0 + 2.0 * float(i + 1) / float(N)
		var wd := _sec((sa + sb) * 0.5, 0.22).x - 0.1
		var cen := _w(0.0, 1.2, (sa + sb) * 0.5 * HALF_LEN)
		k.kit.box("wood_big", cen, Vector3(wd * 2.0, 0.24, 2.0 * HALF_LEN / float(N) + 0.05), rot, true, 0.6)
	# the stair from the hold up to the hatch, and the hold's lamp, chest, barrels
	k.kit.stairs("wood_big", _w(0.0, 1.35, -9.5), _w(0.0, _yd(0.0) - 0.05, 1.9), 2.0, 12)
	k.window(_w(0.0, 1.9, 9.0), rot * Vector3(1.0, 0.0, 0.0), rot * Vector3(0.0, 0.0, -1.0), 1.4, 1.2)
	k.lamp(_w(0.0, 3.2, 3.5), Color(1.0, 0.64, 0.34), 1.8, 11.0)
	k.lamp(_w(0.0, 3.4, 9.0), Color(1.0, 0.64, 0.34), 1.0, 7.0)
	k.chest("salt_ship_hold", "reliquary", _w(2.6, 1.35, 11.0), PI, {"grave_ash": 20, "grave_iron": 3, "relic_fragment": 2})
	for i in 6:
		var bz := -6.0 - 2.2 * float(i) if i < 3 else 6.0 + 2.2 * float(i - 3)
		var bx := -2.6 if i % 2 == 0 else 2.6
		k.tube("wood_big", _w(bx, 1.35, bz), _w(bx, 2.75, bz), 0.62, 0.62, 8, false, 0.7, Vector2(1.0, -1.0), true)
	# the ramp to the breach, from the flats
	var br := _w(-_sec(-0.4, 0.78).x, _yd(-0.4) - 0.1, -0.4 * HALF_LEN)
	var out2 := (rot * Vector3(-1.0, 0.0, 0.0))
	out2.y = 0.0
	out2 = out2.normalized()
	var foot := br + out2 * 9.0
	var gh := lvl
	k.kit.stairs("wood_big", Vector3(foot.x, gh + 0.1, foot.z), Vector3(br.x - out2.x * 0.6, br.y, br.z - out2.z * 0.6), 2.2, maxi(6, int(ceilf((br.y - gh) / 0.36))), gh - 0.8)
	# timber shores on the high side
	for zi in 4:
		var s := -0.5 + 0.33 * float(zi)
		var hp := _pt(int((s + 1.0) * 0.5 * float(N)), 2, 1.0)
		var gp := hp + rot * Vector3(4.2, 0.0, 0.0)
		var gg := lvl
		k.beam("wood_big", hp, Vector3(gp.x, gg + 0.3, gp.z), 0.45, 0.45, false, 0.65)


func _stern() -> void:
	var yd := _yd(-0.68)
	var yc := yd + 2.5
	var wd := _sec(-0.68, 0.78).x - 0.3
	# the castle's roof deck over the cabin, its walls, the door in the front wall
	k.kit.box("wood_big", _w(0.0, yc - 0.15, -16.7), Vector3(wd * 2.0, 0.3, 10.0), rot, true, 0.85)
	k.kit.box("wood_big", _w(-wd * 0.5 - 0.5, (yd + yc) * 0.5, -11.7), Vector3(wd - 1.0, yc - yd, 0.3), rot, true, 0.9)
	k.kit.box("wood_big", _w(wd * 0.5 + 0.5, (yd + yc) * 0.5, -11.7), Vector3(wd - 1.0, yc - yd, 0.3), rot, true, 0.9)
	k.kit.box("wood_big", _w(0.0, yc - 0.45, -11.7), Vector3(1.6, 0.5, 0.35), rot, true, 0.9)
	# the stern windows, lit: the crew's lamps are still burning
	for sx: float in [-1.0, 0.0, 1.0]:
		k.window(_w(sx * 2.4, yd + 0.9, -21.1), rot * Vector3(1.0, 0.0, 0.0), rot * Vector3(0.0, 0.0, -1.0), 1.5, 1.2)
	k.lamp(_w(0.0, yd + 1.5, -17.0), Color(1.0, 0.66, 0.36), 1.7, 9.0)
	k.chest("salt_ship_cabin", "iron", _w(1.8, yd + 0.15, -19.2), PI * 0.5, {"grave_ash": 13, "grave_iron": 2})
	k.kit.box("wood_big", _w(-2.2, yd + 0.45, -19.4), Vector3(2.0, 0.9, 1.0), rot, true, 0.8)           # a bunk
	# the steps up to the roof deck (a flight beside the door) and its rails
	k.kit.stairs("wood_big", _w(2.6, yd + 0.05, -6.0), _w(2.6, yc, -11.8), 1.8, 7)
	for sx: float in [-1.0, 1.0]:
		k.beam("wood_big", _w(sx * (wd - 0.1), yc + 0.9, -11.8), _w(sx * (wd - 0.1), yc + 0.9, -21.0), 0.14, 0.14, false, 0.8)
		for q in 5:
			k.kit.box("wood_big", _w(sx * (wd - 0.1), yc + 0.45, -12.5 - 2.1 * float(q)), Vector3(0.14, 0.9, 0.14), rot, false, 0.8)
	# the sternpost lantern: a pole with a lit glass and a fire in a cresset
	var top := _w(0.0, yc + 5.6, -20.4)
	k.tube("wood_big", _w(0.0, yc, -20.4), top, 0.28, 0.2, 6, false, 0.7)
	k.kit.box("iron", top + Vector3.UP * 0.1, Vector3(1.3, 0.2, 1.3), Basis.IDENTITY, false, 0.7)
	k.fire(top + Vector3.UP * 0.2, 1.8, 3.0)


func _mast() -> void:
	var s := 0.28
	var base_p := _w(0.0, _yd(s), s * HALF_LEN)
	var top := _w(0.0, _yd(s) + 12.5, s * HALF_LEN + 0.6)
	k.tube("wood_big", base_p, top, 0.8, 0.42, 8, true, 0.75, Vector2(1.0, -1.0), true)
	k.tube("wood_big", base_p + Vector3.UP * 0.1, base_p + Vector3.UP * 3.0, 1.1, 0.9, 8, false, 0.6)
	var yard_c := _w(0.0, _yd(s) + 9.6, s * HALF_LEN + 0.4)
	var yx := rot * Vector3(1.0, 0.0, 0.0)
	k.tube("wood_big", yard_c - yx * 5.0, yard_c + yx * 4.2 + Vector3.UP * 0.7, 0.2, 0.16, 6, false, 0.7)
	# the torn sail: three panels hanging from the yard, one ragged
	for i in 3:
		var px := -3.4 + 3.2 * float(i)
		var h := 4.8 - 1.3 * float(i % 2) - (1.2 if i == 2 else 0.0)
		var a := yard_c + yx * px + rot * Vector3(0.0, -0.15, 0.0)
		var wdt := 2.7
		k.kit.quad("chalk", a, a + yx * wdt, a + yx * (wdt - 0.1) + Vector3.DOWN * h, a + Vector3.DOWN * (h - 0.6), rot * Vector3(0.0, 0.0, 1.0), false, 0.95)
		k.kit.quad("chalk", a, a + yx * wdt, a + yx * (wdt - 0.1) + Vector3.DOWN * h, a + Vector3.DOWN * (h - 0.6), rot * Vector3(0.0, 0.0, -1.0), false, 0.8)
	# the masthead lamp
	k.kit.box("iron", top + Vector3.UP * 0.1, Vector3(0.9, 0.16, 0.9), Basis.IDENTITY, false, 0.7)
	k.kit.box("glow", top + Vector3.UP * 0.55, Vector3(0.42, 0.55, 0.42), Basis.IDENTITY, false, 1.0)
	k.lamp(top + Vector3.UP * 0.6, Color(1.0, 0.7, 0.4), 2.2, 22.0)


## Salt drifts: pale lumps banked against the hull on the low side, a scatter along the waterline of the old tide.
func _drifts(mid: Vector2) -> void:
	var rng: RandomNumberGenerator = k.rng
	for q in 34:
		var s := rng.randf_range(-0.9, 0.9)
		var sx := -1.0 if rng.randf() < 0.65 else 1.0
		var sec := _sec(s, 0.2)
		var p := _w(sx * (sec.x + rng.randf_range(0.6, 3.4)), 0.0, s * HALF_LEN)
		var g := lvl
		var sz := Vector3(rng.randf_range(1.6, 4.4), rng.randf_range(0.7, 1.9), rng.randf_range(1.4, 3.2))
		k.kit.box("chalk", Vector3(p.x, g + sz.y * 0.3, p.z), sz, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), false, 0.9 + 0.1 * rng.randf())
	var _m := mid


# --- secondary forms: rigging, nets, stores, a flag, an anchor chain ---------------------------------------

func _dress(mid: Vector2) -> void:
	var s := 0.28
	var top := _w(0.0, _yd(s) + 12.5, s * HALF_LEN + 0.6)
	for sx: float in [-1.0, 1.0]:
		Dress.rope(k, top - Vector3.UP * 0.4, _pt(int(float(N) * (s + 1.0) * 0.5) + 1, LEVELS, sx), 0.25, 0.06, "wood_big", 7)       # shrouds to the gunwale
		Dress.rope(k, top - Vector3.UP * 0.4, _pt(int(float(N) * (s + 1.0) * 0.5) - 2, LEVELS, sx), 0.25, 0.06, "wood_big", 7)
	Dress.rope(k, top, _w(0.0, 8.0, 21.0), 0.8, 0.07, "wood_big", 10)                                                         # the forestay to the bowsprit
	Dress.rope(k, top, _w(0.0, 10.0, -19.0), 1.0, 0.07, "wood_big", 10)
	Dress.banner(k, top + Vector3.UP * 0.05 - rot * Vector3(0.0, 0.0, 0.0), rot * Vector3(0.0, 0.0, -1.0), 2.4, 1.2, rot * Vector3(1.0, 0.0, 0.0))
	for q: Vector3 in [Vector3(-2.8, 0.0, 6.0), Vector3(3.0, 0.0, 7.5), Vector3(-3.1, 0.0, -4.0)]:
		var p := _w(q.x, _yd(q.z / HALF_LEN), q.z)
		Dress.barrel(k, p, 0.3, 1.0)
	Dress.crate(k, _w(2.6, _yd(0.2), 8.8), 0.2)
	Dress.crate(k, _w(2.7, _yd(0.2) + 0.9, 8.8), 0.6, 0.7)
	Dress.crate(k, _w(-2.9, _yd(-0.3), -6.8), -0.3, 0.85)
	var bow := _pt(N, LEVELS - 1, 1.0)
	var gp := Vector3(bow.x + rot.z.x * 4.0, 0.0, bow.z + rot.z.z * 4.0)
	Dress.chain(k, bow, Vector3(gp.x, lvl + 0.4, gp.z), 0.7, 0.22, 10)                                         # the anchor cable
	k.tube("iron", Vector3(gp.x, lvl + 0.2, gp.z), Vector3(gp.x, lvl + 2.4, gp.z), 0.14, 0.12, 5, false, 0.6)
	k.beam("iron", Vector3(gp.x - 1.0, lvl + 0.3, gp.z), Vector3(gp.x + 1.0, lvl + 0.3, gp.z), 0.2, 0.2, false, 0.6)
	var low := _w(0.0, 0.0, -3.0)
	Dress.rubble(k, Vector3(mid.x, lvl, mid.y), 18.0, 26, "chalk")
	Dress.strands(k, _pt(8, LEVELS, -1.0), _pt(14, LEVELS, -1.0), 6, 2.2, "wood_big")
	var _l := low
