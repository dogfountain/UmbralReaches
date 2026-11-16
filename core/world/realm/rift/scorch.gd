extends RefCounted
## The Ashen Rift (the lava area), moved out to the Realm's far north-east corner (Luke, 16 Nov: "it makes no sense to
## be next to the starting village at all"; docs/far_reaches.md "The Ashen Rift, moved"). On the Night the eighth bell
## came down at the Crowns' east corner (the Bellfall) and split the mountain's foot behind its crater: the fire under
## the Crowns welled up along the split and still fills it. The night it brimmed it broke through the heaved lips at
## notches and ran down their outer faces: west into the hollow where the Founder's choir had its hall (the Choir
## House), south over the crater's rim towards the bell, and east down the crater's apron. Fire and spatter burned the
## ground round it, and the ash fell downwind (east-south-east, the foliage shader's wind) in pale drifts.
##
## One field every builder reads: the gash itself (a pit cut into the ground along SPINE, its bed under the lava, its lips
## heaved into a berm over it) and, on a 1 m grid over RECT built once (lazily, on the first single-threaded call),
## the authored flows, the burn and the ash. Readers:
##   ground(x, z, h)     the designed ground with the gash cut and the flows laid on (RealmLand._heights, after the kept core)
##   lift(x, z)          metres the flows raise the ground (and the notches cut the lips: negative)
##   ash_w(x, z)         the ground splat's ash-country weight (RealmLand._splat: cinder grit)
##   burn(x, z)          0 green .. 1 burned to the ground (flora, dressing)
##   gash_d(p)           metres outside the gash's edge (negative inside)
##   over_lava(p)        true over the open lava (spawn rules, the Director's fair ground)
##   texture()           RGBA8 over RECT for the ground shader (r ash drift, g flow, b heat, a burn)
##   under / grass_tint / tree_tint / charred / tree_keeps   the flora's hooks (realm_flora.gd)
## Static data only (deterministic for the layout), so it needs no night reset. The old chasm by Hearthward holds
## starwater now (realm_rift.gd): nothing here reaches it.

const RECT := Rect2(242.0, -162.0, 128.0, 92.0)        ## x 242..370, z -162..-70
const NX := 129
const NZ := 93
## The gash, west to east along the Crowns' foot above the Bellfall crater (RealmReaches.CRATER_C): its centreline and
## its half-width at each point. The rounded ends close it; its north wall is the mountain.
const SPINE := [Vector2(283.0, -135.5), Vector2(297.0, -139.0), Vector2(313.0, -140.5), Vector2(329.0, -139.5), Vector2(345.0, -137.5), Vector2(360.0, -135.0)]
const HALF := [6.5, 10.0, 12.0, 11.5, 10.0, 6.0]
const MID := Vector2(321.0, -139.0)                      ## the gash's middle (the burn's tongues reach out from it)
const LAVA_Y := 5.0                                      ## the lava's surface (AshLava)
const FLOOR_Y := 2.4                                     ## the gash's bed under it
const BERM := 3.4                                        ## the lips stand this far over the lava, heaved up when it split
## The lava sheet's footprint (x 276..368, z -153..-125): all ground in it and SHEET_PAD round it outside the gash
## stands over the lava (SHEET_CLEAR), so the sheet shows only in the gash (never as a sliver along its own edge where
## the crater's slope falls away) and the kill volume under it never reaches a walkable lip.
const SHEET := Rect2(276.0, -153.0, 92.0, 28.0)
const SHEET_CLEAR := 1.7
const SHEET_PAD := 3.0
const WIND := Vector2(0.8, 0.6)                          ## ash carries this way (realm_foliage.gdshader's wind)
const RING := 26.0                                       ## metres of dying turf and dry ground round the burn

## The flows. The night the rift brimmed the lava broke through the lips at notches (`notch`: metres the crest is cut
## down where a flow crossed it) and ran down their outer faces: west into the hollow below the Anchorholds' shoulder
## (the main flow, which took the Choir House), south over the crater's rim towards the bell (it stopped short of it),
## a short tongue beside it, and east down the crater's apron. Points from the lip outward, half-widths (m) at each,
## thickness (m). Clear of the bell, the crater's west camp, the fire and every way.
const FLOWS := [
	{"pts": [Vector2(289.0, -129.6), Vector2(285.5, -125.5), Vector2(281.5, -121.0), Vector2(277.0, -116.5), Vector2(272.5, -112.0), Vector2(268.5, -107.5), Vector2(266.0, -103.0)],
		"hw": [2.6, 4.0, 5.2, 6.2, 7.0, 7.2, 5.4], "thick": 1.3, "notch": 3.0},
	{"pts": [Vector2(315.0, -130.6), Vector2(315.5, -126.0), Vector2(315.0, -121.5), Vector2(314.2, -117.8)],
		"hw": [2.4, 3.8, 4.6, 3.6], "thick": 1.0, "notch": 2.8},
	{"pts": [Vector2(333.5, -129.8), Vector2(335.0, -125.5), Vector2(336.5, -121.5), Vector2(337.2, -118.5)],
		"hw": [2.2, 3.4, 3.8, 3.0], "thick": 0.9, "notch": 2.4},
	{"pts": [Vector2(347.0, -128.6), Vector2(350.5, -124.5), Vector2(354.5, -120.0), Vector2(358.0, -115.0), Vector2(360.5, -109.5), Vector2(361.5, -104.5)],
		"hw": [2.5, 3.8, 5.0, 5.8, 5.5, 4.2], "thick": 1.2, "notch": 3.0},
]
## The Choir House (rift_rim.gd; tools/blender/rift_choir_house.py) stands in the main west flow, on the hollow's flat
## below the crater's shoulder: its door's threshold, the way into the hall (down the flow), its length and half width,
## and the floor it was built on (the hollow is levelled to it under the hall: it stood on a terrace, not a slope).
## The crust in its nave kept the heat longest.
const CHOIR_DOOR := Vector2(278.6, -118.1)
const CHOIR_DIR := Vector2(-0.707, 0.707)
const CHOIR_LEN := 14.0
const CHOIR_HW := 3.7
const CHOIR_FLOOR := 0.5
## What the flows stop short of: the eighth bell, the crater's west camp, the crater's fire.
const KEEP_CLEAR := [[Vector2(318.0, -100.0), 14.0], [Vector2(290.0, -112.0), 7.0], [Vector2(318.0, -60.0), 9.0]]

static var _burn := PackedFloat32Array()
static var _ash := PackedFloat32Array()
static var _flow := PackedFloat32Array()
static var _heat := PackedFloat32Array()
static var _lift := PackedFloat32Array()
static var _carve := PackedFloat32Array()        ## the notches the flows cut in the lips (<= 0)
static var _near := PackedFloat32Array()         ## the burn the flows set round themselves
static var _tex: ImageTexture
static var _n_lo: FastNoiseLite
static var _n_mid: FastNoiseLite
static var _n_hi: FastNoiseLite
static var _n_drift: FastNoiseLite


# --- readers --------------------------------------------------------------------------------------

## The designed ground at (x, z) given the ground `h` there: the gash cut along SPINE (its bed under the lava, its walls
## up to the lips, the lips heaved into a berm over the lava), then the flows laid on and the notches cut (lift).
static func ground(x: float, z: float, h: float) -> float:
	prepare()
	var p := Vector2(x, z)
	var out := lerpf(h, CHOIR_FLOOR, _hall_pad(p))
	if SHEET.grow(16.0).has_point(p):
		var s := _spine(p)
		var e := s.x - s.y * (1.0 + 0.1 * _n_mid.get_noise_2d(x * 0.9, z * 0.9))          # metres outside the edge (it wanders)
		var crest := LAVA_Y + BERM + 0.7 * _n_hi.get_noise_2d(x * 0.5, z * 0.5)
		var base := out                              # (the land, with the Choir House's terrace)
		if e > 0.0:
			# the lip's berm: at its crest a metre or two outside the edge, back to the land over the next eight
			out = maxf(base, lerpf(crest, base, smoothstep(1.5, 9.0, e)))
		else:
			# the walls: from the bed up to the lip, steeper where the mountain stands higher over it
			var lip := maxf(base, crest)
			var band := 3.0 + 0.06 * (lip - FLOOR_Y)
			var bed := FLOOR_Y + 0.5 * _n_hi.get_noise_2d(x * 1.3 + 7.0, z * 1.3)
			out = lerpf(bed, lip, smoothstep(-band, 0.6, e))
	out += lift(x, z)
	if SHEET.grow(SHEET_PAD).has_point(p) and gash_d(p) > 1.2:
		out = maxf(out, LAVA_Y + SHEET_CLEAR)       # the sheet never shows outside the gash, its kill volume never reaches a lip
	return out


static func lift(x: float, z: float) -> float:
	prepare()
	return _sample(_lift, x, z)


static func burn(x: float, z: float) -> float:
	prepare()
	return _sample(_burn, x, z)


## Metres outside the gash's edge (negative inside).
static func gash_d(p: Vector2) -> float:
	var s := _spine(p)
	return s.x - s.y


## Over the open lava (a spawn, a tide, an event must not stand there): in the gash, below its lips.
static func over_lava(at: Vector3) -> bool:
	return SHEET.has_point(Vector2(at.x, at.z)) and at.y < LAVA_Y + 3.0 and gash_d(Vector2(at.x, at.z)) < 1.0


## Ash country in the ground splat: the burn, a little past where the green gives up.
static func ash_w(x: float, z: float) -> float:
	return smoothstep(0.42, 0.8, burn(x, z)) * 0.95


## RealmLand._splat's weights [meadow, loam, mud, ash, heath, crag, ruin, salt] with the burn turned to ash country.
static func splat(bw: PackedFloat32Array, x: float, z: float) -> PackedFloat32Array:
	var a := ash_w(x, z)
	if a <= 0.0:
		return bw
	var tot := 0.0
	for v in bw:
		tot += v
	for i in bw.size():
		bw[i] *= 1.0 - a
	bw[3] += a * maxf(tot, 0.001)
	return bw


static func ash(x: float, z: float) -> float:
	prepare()
	return _sample(_ash, x, z)


static func flow(x: float, z: float) -> float:
	prepare()
	return _sample(_flow, x, z)


static func heat(x: float, z: float) -> float:
	prepare()
	return _sample(_heat, x, z)


## The flows (for builders that dress them): Array of {pts, hw, thick}.
static func flows() -> Array:
	return FLOWS


## The gash's centreline at p: Vector3(distance to it, its half-width there, metres along it from the west end).
static func _spine(p: Vector2) -> Vector3:
	var best := INF
	var hw := 0.0
	var al := 0.0
	var run := 0.0
	for s in SPINE.size() - 1:
		var a: Vector2 = SPINE[s]
		var b: Vector2 = SPINE[s + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			hw = lerpf(float(HALF[s]), float(HALF[s + 1]), t)
			al = run + ab.length() * t
		run += ab.length()
	return Vector3(best, hw, al)


## The point on the centreline nearest p.
static func _spine_pt(p: Vector2) -> Vector2:
	var best := INF
	var out := p
	for s in SPINE.size() - 1:
		var a: Vector2 = SPINE[s]
		var ab: Vector2 = (SPINE[s + 1] as Vector2) - a
		var q := a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(q) < best:
			best = p.distance_to(q)
			out = q
	return out


static func _sample(f: PackedFloat32Array, x: float, z: float) -> float:
	if not RECT.has_point(Vector2(x, z)) or f.is_empty():
		return 0.0
	var fx := (x - RECT.position.x)
	var fz := (z - RECT.position.y)
	var i := mini(int(fx), NX - 2)
	var j := mini(int(fz), NZ - 2)
	var tx := fx - i
	var tz := fz - j
	var a := f[j * NX + i]
	var b := f[j * NX + i + 1]
	var c := f[(j + 1) * NX + i]
	var d := f[(j + 1) * NX + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


# --- the flora's hooks (realm_flora.gd) --------------------------------------------------------------

## Undergrowth rates for one 4 m biome cell: the burned ground is bare but for ash, cinders and dead
## brush; the ring round it thinned and dry.
static func under(row: PackedFloat32Array, kinds: Array, x: float, z: float) -> PackedFloat32Array:
	var out := row.duplicate()
	var b := burn(x, z)
	if b <= 0.02:
		return out
	var dying := smoothstep(0.02, 0.42, b)
	var dead := smoothstep(0.45, 0.82, b)
	var a := ash(x, z)
	var fl := flow(x, z)
	for s in kinds.size():
		match String(kinds[s]):
			"grass":
				out[s] *= lerpf(1.0, 0.55, dying) * lerpf(1.0, 0.03, dead)
			"tallgrass", "heather":
				out[s] *= lerpf(1.0, 0.35, dying) * (1.0 - dead)
			"flowers", "fern", "moss", "mushroom", "glowcap", "litter", "bramble", "shrub", "lily", "gorse":
				out[s] *= lerpf(1.0, 0.15, dying) * (1.0 - dead)
			"ashdrift":
				out[s] += 0.05 * dead * (1.0 - fl) + 0.08 * a * dying
			"cinders":
				out[s] += 0.012 * smoothstep(0.75, 1.0, b) * (1.0 - fl)
			"deadbush":
				out[s] += 0.022 * dying * (1.0 - dead * 0.6) * (1.0 - fl)
	return out


## The grassy kinds' tint: dry straw in the ring, charred umber in the burn.
static func grass_tint(t: Color, x: float, z: float) -> Color:
	var b := burn(x, z)
	if b <= 0.02:
		return t
	var dry := t * Color(1.0, 0.78, 0.5)
	var black := t * Color(0.4, 0.35, 0.31)
	return t.lerp(dry, smoothstep(0.02, 0.22, b)).lerp(black, smoothstep(0.48, 0.85, b))


## A tree's instance tint: the ring's trees are dying, their crowns gone rust and sere.
static func tree_tint(t: Color, at: Vector2, sp: String) -> Color:
	var b := burn(at.x, at.y)
	if b <= 0.03:
		return t
	if sp == "snag":
		return t * lerpf(1.0, 0.7, smoothstep(0.2, 0.7, b))
	var k := smoothstep(0.03, 0.3, b) * (0.7 + 0.3 * _hash(at, 3.1))
	return t.lerp(t * Color(1.05, 0.55, 0.3), k)


## Trees in the burn stand as charred snags (TreeGen snag_2).
static func charred(at: Vector2) -> bool:
	var b := burn(at.x, at.y)
	return b > 0.5 + 0.18 * (_hash(at, 7.7) - 0.5)


## Saplings and young growth burned away; the deepest burn keeps half its snags; nothing stands in the gash.
static func tree_keeps(at: Vector2, sp: String, id: String) -> bool:
	var b := burn(at.x, at.y)
	if b <= 0.3:
		return true
	if RECT.has_point(at) and gash_d(at) < 2.5:
		return false
	if charred(at) and not id.begins_with("snag"):
		return false                                 # a green stand-in a clash chose: not in the burn
	if sp == "sapling" or sp == "birch":
		return b < 0.55 and _hash(at, 2.3) > (b - 0.3) * 3.0
	return b < 0.85 or _hash(at, 5.9) < 0.55


static func _hash(p: Vector2, s: float) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233 + s * 37.719) * 43758.5453, 1.0)


# --- the field ---------------------------------------------------------------------------------------

static func prepare() -> void:
	if not _burn.is_empty():
		return
	_noise()
	var n := NX * NZ
	_burn.resize(n)
	_ash.resize(n)
	_flow.resize(n)
	_heat.resize(n)
	_lift.resize(n)
	_carve.resize(n)
	_near.resize(n)
	_flows()
	var bare := "--no-scorch" in OS.get_cmdline_user_args()          # A/B: the gash and its flows without the burn round them
	for j in NZ:
		var z := RECT.position.y + j
		for i in NX:
			var x := RECT.position.x + i
			var k := j * NX + i
			var p := Vector2(x, z)
			var b := 0.0 if bare else _burn_at(p)
			var fl := _flow[k]
			_burn[k] = maxf(maxf(b, fl * 0.9), 0.0 if bare else _near[k])
			_lift[k] += _carve[k]
			_ash[k] = 0.0 if bare else _ash_at(p, b) * (1.0 - smoothstep(0.05, 0.3, fl) * 0.7)
	_tex = null


static func _noise() -> void:
	_n_lo = FastNoiseLite.new()
	_n_lo.seed = 4101
	_n_lo.frequency = 0.022
	_n_mid = FastNoiseLite.new()
	_n_mid.seed = 4102
	_n_mid.frequency = 0.07
	_n_mid.fractal_octaves = 3
	_n_hi = FastNoiseLite.new()
	_n_hi.seed = 4103
	_n_hi.frequency = 0.21
	_n_hi.fractal_octaves = 2
	_n_drift = FastNoiseLite.new()
	_n_drift.seed = 4104
	_n_drift.frequency = 0.05
	_n_drift.fractal_octaves = 3


## Distance outside the gash (0 inside), its edge broken by a slow, wide warp (lobes, not a halo).
static func _lip_d(p: Vector2) -> float:
	var q := p + Vector2(_n_lo.get_noise_2d(p.x, p.y + 40.0), _n_lo.get_noise_2d(p.x + 70.0, p.y)) * 9.0
	return maxf(gash_d(q), 0.0)


## How far downwind of the gash p lies (0 upwind or across, 1 straight downwind).
static func _downwind(p: Vector2) -> float:
	var c := _spine_pt(p)
	if p.distance_to(c) < 0.5:
		return 0.0
	return maxf((p - c).normalized().dot(WIND), 0.0)


static func _burn_at(p: Vector2) -> float:
	if gash_d(p) < 0.0:
		return 1.0
	var d := _lip_d(p)
	# the fire ran downwind (east-south-east, down over the crater) and burned back less far up the mountain and west
	# towards the Anchorholds' shoulder
	var r := 20.0 if p.x < MID.x else 27.0
	r *= 0.85 + 0.3 * (_n_lo.get_noise_2d(p.x * 0.6 + 9.0, p.y * 0.6) * 0.5 + 0.5)
	r += 14.0 * _downwind(p)
	# tongues: the burn reached out further along a few bearings from the gash's middle (a scar, not a halo)
	var ang := (p - MID).angle()
	r += 18.0 * pow(maxf(_n_lo.get_noise_1d(ang * 38.0 + 400.0), 0.0) * 2.2, 1.6)
	var dd := d - _n_mid.get_noise_2d(p.x, p.y) * 8.0
	# the burn proper (charred, ash country), and round it a ring of dying turf and dry ground (never past 0.42)
	var core := 1.0 - smoothstep(r * 0.3, r, dd)
	var ring := 1.0 - smoothstep(r, r + RING, dd)
	var isl := _n_hi.get_noise_2d(p.x * 0.5, p.y * 0.5)
	core *= 1.0 - smoothstep(0.2, 0.5, isl) * (1.0 - smoothstep(0.5, 0.85, core)) * 0.85
	var b := maxf(core, ring * 0.42)
	# nothing reaches the field's own edge (the Anchorholds' shoulder, Lastlight's country)
	var edge := minf(minf(p.x - RECT.position.x, RECT.end.x + 30.0 - p.x), minf(p.y - RECT.position.y, RECT.end.y - p.y))
	b *= smoothstep(0.0, 14.0, edge)
	return clampf(b, 0.0, 1.0)


## Pale ash: it fell downwind of the gash, lying in drifts in the lee; little upwind; the hot lip is swept bare.
static func _ash_at(p: Vector2, b: float) -> float:
	var d := _lip_d(p)
	var dw := _downwind(p)
	var reach := (14.0 if p.x < MID.x else 26.0) + 36.0 * dw
	var base := 1.0 - smoothstep(reach * 0.2, reach, d)
	# drifts: blobs stretched a little along the wind, broken by a finer field
	var along := p.dot(WIND)
	var across := p.dot(Vector2(-WIND.y, WIND.x))
	var drift := _n_drift.get_noise_2d(along * 0.45, across * 1.0) * 0.75 + _n_hi.get_noise_2d(p.x * 0.35 + 30.0, p.y * 0.35) * 0.35
	var a := base * smoothstep(-0.1, 0.5, drift + (base - 0.5) * 0.35)
	a *= smoothstep(1.0, 6.0, d)                     # the lip's heat keeps it clear
	var edge := minf(minf(p.x - RECT.position.x, RECT.end.x + 30.0 - p.x), minf(p.y - RECT.position.y, RECT.end.y - p.y))
	a *= smoothstep(0.0, 14.0, edge)
	return clampf(maxf(a * 0.85, b * 0.12), 0.0, 1.0)


## Flows into _flow (0 at the edge .. 1 on the spine), _lift and _heat.
static func _flows() -> void:
	_flow.fill(0.0)
	_lift.fill(0.0)
	_heat.fill(0.0)
	_carve.fill(0.0)
	_near.fill(0.0)
	for f: Dictionary in FLOWS:
		var pts: Array = f.pts
		var hws: Array = f.hw
		var thick: float = f.thick
		var notch: float = f.get("notch", 0.0)
		var box := Rect2(pts[0], Vector2.ZERO)
		var maxw := 0.0
		for q: Vector2 in pts:
			box = box.expand(q)
		for w: float in hws:
			maxw = maxf(maxw, w)
		box = box.grow(maxw + 15.0)
		var lens := PackedFloat32Array([0.0])
		for s in pts.size() - 1:
			lens.append(lens[s] + (pts[s] as Vector2).distance_to(pts[s + 1]))
		var j0 := maxi(int(box.position.y - RECT.position.y), 0)
		var j1 := mini(int(box.end.y - RECT.position.y) + 1, NZ - 1)
		var i0 := maxi(int(box.position.x - RECT.position.x), 0)
		var i1 := mini(int(box.end.x - RECT.position.x) + 1, NX - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := Vector2(RECT.position.x + i, RECT.position.y + j)
				# nearest point on the spine: distance, the half-width there, how far along
				var best := INF
				var hw := 0.0
				var al := 0.0
				for s in pts.size() - 1:
					var a: Vector2 = pts[s]
					var bq: Vector2 = pts[s + 1]
					var ab := bq - a
					var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					var dd := p.distance_to(a + ab * t)
					if dd < best:
						best = dd
						hw = lerpf(float(hws[s]), float(hws[s + 1]), t)
						al = lerpf(lens[s], lens[s + 1], t)
				# the lobe's margin wanders (toes and breakouts); the source pours thin over the lip
				var edge := hw * (1.0 + 0.22 * _n_mid.get_noise_2d(p.x * 1.3 + 50.0, p.y * 1.3)) + 0.9 * _n_hi.get_noise_2d(p.x, p.y)
				var k0 := j * NX + i
				# the fire the flow set round itself: burned ground a dozen metres either side, dying out ragged
				var near := (1.0 - smoothstep(edge * 0.6, edge + 13.0 + 5.0 * _n_mid.get_noise_2d(p.x * 0.7, p.y * 0.7 + 20.0), best)) * 0.85
				_near[k0] = maxf(_near[k0], near * smoothstep(0.0, 4.0, al))
				# the notch: where the flow crossed the lip's crest the crest is cut down (a breach the crust still fills)
				if notch > 0.0:
					var cut := notch * (1.0 - smoothstep(edge * 0.55, edge * 1.35, best)) * smoothstep(0.5, 3.5, al) * (1.0 - smoothstep(6.0, 11.0, al))
					_carve[k0] = minf(_carve[k0], -cut)
				var inner := clampf(1.0 - best / maxf(edge, 0.5), 0.0, 1.0)
				if inner <= 0.0:
					continue
				for kc: Array in KEEP_CLEAR:
					inner *= smoothstep(float(kc[1]), float(kc[1]) + 4.0, p.distance_to(kc[0]))
				var off := smoothstep(1.5, 4.5, RealmLayout.path_dist(p))
				var k := j * NX + i
				_flow[k] = maxf(_flow[k], inner * off)
				var src := smoothstep(0.0, 4.0, al)
				var bump := 0.18 * _n_hi.get_noise_2d(p.x * 1.7 + 11.0, p.y * 1.7)
				var h := (thick * smoothstep(0.0, 0.3, inner) + bump * inner) * src * off
				_lift[k] = maxf(_lift[k], h)
				# still warm near the lip: the crust's cracks glow for the first ~12 m; and in the Choir House's nave
				_heat[k] = maxf(_heat[k], inner * maxf(1.0 - smoothstep(3.0, 13.0, al), 0.85 * _in_hall(p)) * off)


## The terrace the Choir House was built on: 1 under the hall and a couple of metres round it, easing out over 5 m.
static func _hall_pad(p: Vector2) -> float:
	var q := p - CHOIR_DOOR
	var along := q.dot(CHOIR_DIR)
	var across := absf(q.dot(Vector2(-CHOIR_DIR.y, CHOIR_DIR.x)))
	var out := maxf(maxf(-2.5 - along, along - CHOIR_LEN - 2.5), across - CHOIR_HW - 2.5)
	return 1.0 - smoothstep(0.0, 5.0, out)


## 1 inside the Choir House's walls (a soft edge), 0 outside.
static func _in_hall(p: Vector2) -> float:
	var q := p - CHOIR_DOOR
	var along := q.dot(CHOIR_DIR)
	var across := absf(q.dot(Vector2(-CHOIR_DIR.y, CHOIR_DIR.x)))
	return smoothstep(0.0, 1.5, along) * (1.0 - smoothstep(CHOIR_LEN - 1.5, CHOIR_LEN, along)) * (1.0 - smoothstep(CHOIR_HW - 1.4, CHOIR_HW - 0.6, across))


## The ground shader's map over RECT (RGBA8): r ash, g flow, b heat, a burn.
static func texture() -> ImageTexture:
	if _tex != null:
		return _tex
	prepare()
	var img := Image.create(NX, NZ, false, Image.FORMAT_RGBA8)
	for j in NZ:
		for i in NX:
			var k := j * NX + i
			img.set_pixel(i, j, Color(_ash[k], _flow[k], _heat[k], _burn[k]))
	_tex = ImageTexture.create_from_image(img)
	return _tex


## RECT as the shader's vec4 (x0, z0, x1, z1).
static func rect_v4() -> Vector4:
	return Vector4(RECT.position.x, RECT.position.y, RECT.end.x, RECT.end.y)


## Hands the map to the Realm's ground material (Zone/Terrain, after RealmLand built it).
static func apply_ground(root: Node) -> void:
	var t := root.get_node_or_null("Zone/Terrain") as MeshInstance3D
	var m := t.material_override as ShaderMaterial if t != null else null
	if m == null:
		return
	m.set_shader_parameter("scorch_tex", texture())
	m.set_shader_parameter("scorch_rect", rect_v4())
