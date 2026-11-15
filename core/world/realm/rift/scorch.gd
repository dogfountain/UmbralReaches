extends RefCounted
## The Ashen Rift's scorch: how the land round the lava burned, as one field every builder reads.
## The rift was a clean slot of fire cut into green meadow and oak wood; now the country round it tells
## what happened: the first night the rift brimmed, broke through the berms along its lips at notches and
## ran down their outer faces (west across the flat at the Crowns' foot, where it took the Choir House; east
## into the Hollow Fen's edge, whose water still steams at the flows' fronts); fire and spatter burned the
## wood round it, and the ash fell downwind (east-south-east, the foliage shader's wind) in pale drifts. The burn is deepest at the lip and
## fades out through charred snags, rust-leaved dying trees and grey grass into the living land; it
## thins to almost nothing by the Pilgrims' Threshold, where the lava cools into starwater.
##
## One 1 m grid over RECT, built once (lazily, on the first single-threaded call) from authored flows,
## the lip and noise. Readers:
##   lift(x, z)          metres the ground rises (the flows' lobes; RealmLand._heights, after the kept core)
##   ash_w(x, z)         the ground splat's ash-country weight (RealmLand._splat: cinder grit)
##   burn(x, z)          0 green .. 1 burned to the ground (flora, dressing)
##   texture()           RGBA8 over RECT for the ground shader (r ash drift, g flow, b heat, a burn)
##   under / grass_tint / tree_tint / charred / tree_keeps   the flora's hooks (realm_flora.gd)
## Static data only (deterministic for the layout), so it needs no night reset.

const RECT := Rect2(-104.0, -156.0, 208.0, 164.0)      ## x -104..104, z -156..8
const NX := 209
const NZ := 165
const LIP := Rect2(-24.0, -121.0, 48.0, 109.0)          ## the chasm's lip (x +-24, z -121..-12)
const WIND := Vector2(0.8, 0.6)                          ## ash carries this way (realm_foliage.gdshader's wind)
const HENGE := Vector2(-86.0, -24.0)                     ## Thorn Henge's hill stays green (its own place)
const MOUTH_Z := Vector2(-36.0, -6.0)                    ## the starwater mouth: the burn dies back over these z
const RING := 30.0                                       ## metres of dying wood and dry turf round the burn

## The flows. The rift's lips are berms 11-15 m high (heaved up when it tore open); the night the rift brimmed the
## lava broke through them at notches (`notch`: metres the crest is cut down where a flow crossed it) and ran down
## their outer faces: west onto the flat at the Crowns' foot (the main flow, which took the Choir House, and a second
## tongue), east in two cascades down the berm into the Hollow Fen's edge. Points from the lip outward, half-widths
## (m) at each, thickness (m). Clear of the Watchers' Spire (realm_pois.gd, between the two west flows), the Fen
## postern's crest (site_fen.gd), the Threshold fire and every way.
const FLOWS := [
	{"pts": [Vector2(-23.0, -87.5), Vector2(-29.0, -87.0), Vector2(-36.0, -86.5), Vector2(-43.0, -86.0), Vector2(-51.0, -84.6), Vector2(-59.0, -83.2), Vector2(-67.0, -84.5)],
		"hw": [2.6, 4.2, 5.2, 6.5, 7.6, 8.0, 6.0], "thick": 1.35, "notch": 4.0},
	{"pts": [Vector2(-23.0, -113.0), Vector2(-29.0, -113.5), Vector2(-36.0, -114.0), Vector2(-44.0, -114.8), Vector2(-53.0, -116.2), Vector2(-62.0, -115.5), Vector2(-69.0, -112.5)],
		"hw": [2.4, 4.0, 4.8, 5.0, 5.2, 6.0, 5.0], "thick": 1.1, "notch": 4.0},
	{"pts": [Vector2(26.0, -101.5), Vector2(32.0, -101.0), Vector2(39.0, -99.0), Vector2(47.0, -95.0), Vector2(54.0, -90.0), Vector2(58.5, -86.0)],
		"hw": [3.0, 4.5, 6.0, 7.0, 6.5, 5.5], "thick": 1.2, "notch": 3.5},
	{"pts": [Vector2(27.0, -76.5), Vector2(33.0, -77.0), Vector2(39.0, -74.5), Vector2(44.0, -70.5), Vector2(47.5, -67.5)],
		"hw": [2.6, 4.2, 5.5, 5.0, 4.4], "thick": 1.0, "notch": 3.0},
]
## The Choir House (rift_rim.gd; tools/blender/rift_choir_house.py) stands in the main west flow: its door's threshold,
## the way into the hall (down the flow), its length and half width. The crust in its nave kept the heat longest.
const CHOIR_DOOR := Vector2(-43.5, -86.0)
const CHOIR_DIR := Vector2(-0.985, 0.172)
const CHOIR_LEN := 14.0
const CHOIR_HW := 3.7
## Fire pads (RealmBosses.R34_FIRES near here) the flows stop short of.
const KEEP_CLEAR := [[Vector2(50.6, -57.5), 8.0], [Vector2(55.6, -56.6), 6.0], [Vector2(35.3, -32.6), 9.0], [Vector2(-52.0, -100.0), 9.5]]

static var _burn := PackedFloat32Array()
static var _ash := PackedFloat32Array()
static var _flow := PackedFloat32Array()
static var _heat := PackedFloat32Array()
static var _lift := PackedFloat32Array()
static var _carve := PackedFloat32Array()        ## the notches the flows cut in the berms (<= 0)
static var _near := PackedFloat32Array()         ## the burn the flows set round themselves
static var _tex: ImageTexture
static var _n_lo: FastNoiseLite
static var _n_mid: FastNoiseLite
static var _n_hi: FastNoiseLite
static var _n_drift: FastNoiseLite


# --- readers --------------------------------------------------------------------------------------

static func lift(x: float, z: float) -> float:
	prepare()
	return _sample(_lift, x, z)


static func burn(x: float, z: float) -> float:
	prepare()
	return _sample(_burn, x, z)


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


## Saplings and young growth burned away; the deepest burn keeps half its snags.
static func tree_keeps(at: Vector2, sp: String, id: String) -> bool:
	var b := burn(at.x, at.y)
	if b <= 0.3:
		return true
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
	if "--no-scorch" in OS.get_cmdline_user_args():          # A/B: the rift as it was (zeros everywhere)
		_burn.fill(0.0)
		_ash.fill(0.0)
		_flow.fill(0.0)
		_heat.fill(0.0)
		_lift.fill(0.0)
		return
	_flows()
	for j in NZ:
		var z := RECT.position.y + j
		for i in NX:
			var x := RECT.position.x + i
			var k := j * NX + i
			var p := Vector2(x, z)
			var b := _burn_at(p)
			var fl := _flow[k]
			_burn[k] = maxf(maxf(b, fl * 0.9), _near[k])
			_lift[k] += _carve[k]
			_ash[k] = _ash_at(p, b) * (1.0 - smoothstep(0.05, 0.3, fl) * 0.7)
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


## Distance outside the lip (negative inside), its edge broken by a slow, wide warp (lobes, not a halo).
static func _lip_d(p: Vector2) -> float:
	var q := p + Vector2(_n_lo.get_noise_2d(p.x, p.y + 40.0), _n_lo.get_noise_2d(p.x + 70.0, p.y)) * 11.0
	var dx := maxf(LIP.position.x - q.x, q.x - LIP.end.x)
	var dz := maxf(LIP.position.y - q.y, q.y - LIP.end.y)
	if dx <= 0.0 and dz <= 0.0:
		return maxf(dx, dz)
	return Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()


## The true lip distance (no warp): inside the chasm everything is burned.
static func _in_lip(p: Vector2) -> bool:
	return LIP.has_point(p)


## How far downwind of the lip p lies (0 upwind or across, 1 straight downwind).
static func _downwind(p: Vector2) -> float:
	var c := Vector2(clampf(p.x, LIP.position.x, LIP.end.x), clampf(p.y, LIP.position.y, LIP.end.y))
	if p.distance_to(c) < 0.5:
		return 0.0
	return maxf((p - c).normalized().dot(WIND), 0.0)


static func _burn_at(p: Vector2) -> float:
	if _in_lip(p):
		return 1.0
	var d := maxf(_lip_d(p), 0.0)
	# the fire ran downwind (east-south-east, over the low fen side) and up the wood's slope in tongues; the west,
	# upwind and higher, burned back less far
	var r := 26.0 if p.x < 0.0 else 34.0
	r *= 0.85 + 0.3 * (_n_lo.get_noise_2d(p.x * 0.6 + 9.0, p.y * 0.6) * 0.5 + 0.5)
	r += 16.0 * _downwind(p)
	# tongues: the burn reached out further along a few bearings from the rift's middle (a scar, not a halo)
	var ang := (p - Vector2(0.0, -66.0)).angle()
	r += 24.0 * pow(maxf(_n_lo.get_noise_1d(ang * 38.0 + 400.0), 0.0) * 2.2, 1.6)
	# the starwater mouth: the burn dies back towards Hearthward
	var mouth := smoothstep(MOUTH_Z.x, MOUTH_Z.y, p.y)
	r *= lerpf(1.0, 0.3, mouth)
	var dd := d - _n_mid.get_noise_2d(p.x, p.y) * 10.0
	# the burn proper (charred, ash country), and round it a ring of dying wood and dry turf (never past 0.42)
	var core := 1.0 - smoothstep(r * 0.3, r, dd)
	var ring := 1.0 - smoothstep(r, r + RING * lerpf(1.0, 0.4, mouth), dd)
	var isl := _n_hi.get_noise_2d(p.x * 0.5, p.y * 0.5)
	core *= 1.0 - smoothstep(0.2, 0.5, isl) * (1.0 - smoothstep(0.5, 0.85, core)) * 0.85
	var b := maxf(core, ring * 0.42)
	b *= lerpf(1.0, 0.5, mouth)
	# Thorn Henge's hill keeps its green; nothing reaches the map's own edge
	b *= smoothstep(34.0, 46.0, p.distance_to(HENGE))
	var edge := minf(minf(p.x - RECT.position.x, RECT.end.x - p.x), minf(p.y - RECT.position.y, RECT.end.y - p.y))
	b *= smoothstep(0.0, 14.0, edge)
	return clampf(b, 0.0, 1.0)


## Pale ash: it fell downwind of the rift, lying in drifts in the lee; little upwind; the hot lip is swept bare.
static func _ash_at(p: Vector2, b: float) -> float:
	var d := maxf(_lip_d(p), 0.0)
	var dw := _downwind(p)
	var reach := (16.0 if p.x < 0.0 else 30.0) + 42.0 * dw
	reach *= lerpf(1.0, 0.3, smoothstep(MOUTH_Z.x, MOUTH_Z.y, p.y))
	var base := 1.0 - smoothstep(reach * 0.2, reach, d)
	# drifts: blobs stretched a little along the wind, broken by a finer field
	var along := p.dot(WIND)
	var across := p.dot(Vector2(-WIND.y, WIND.x))
	var drift := _n_drift.get_noise_2d(along * 0.45, across * 1.0) * 0.75 + _n_hi.get_noise_2d(p.x * 0.35 + 30.0, p.y * 0.35) * 0.35
	var a := base * smoothstep(-0.1, 0.5, drift + (base - 0.5) * 0.35)
	a *= smoothstep(1.0, 7.0, d)                     # the lip's heat keeps it clear
	a *= smoothstep(30.0, 42.0, p.distance_to(HENGE))
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
				# the notch: where the flow crossed the berm's crest the crest is cut down (a breach the lava still fills)
				if notch > 0.0:
					var cut := notch * (1.0 - smoothstep(edge * 0.55, edge * 1.35, best)) * smoothstep(1.0, 6.0, al) * (1.0 - smoothstep(10.0, 17.0, al))
					_carve[k0] = minf(_carve[k0], -cut)
				var inner := clampf(1.0 - best / maxf(edge, 0.5), 0.0, 1.0)
				if inner <= 0.0:
					continue
				for kc: Array in KEEP_CLEAR:
					inner *= smoothstep(float(kc[1]), float(kc[1]) + 4.0, p.distance_to(kc[0]))
				var off := smoothstep(1.5, 4.5, RealmLayout.path_dist(p))
				var k := j * NX + i
				_flow[k] = maxf(_flow[k], inner * off)
				var src := smoothstep(0.0, 7.0, al)
				var bump := 0.18 * _n_hi.get_noise_2d(p.x * 1.7 + 11.0, p.y * 1.7)
				var h := (thick * smoothstep(0.0, 0.3, inner) + bump * inner) * src * off
				_lift[k] = maxf(_lift[k], h)
				# still warm near the lip: the crust's cracks glow for the first ~14 m; and in the Choir House's nave
				_heat[k] = maxf(_heat[k], inner * maxf(1.0 - smoothstep(3.0, 15.0, al), 0.85 * _in_hall(p)) * off)


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
	if "--no-scorch" in OS.get_cmdline_user_args():
		return
	var t := root.get_node_or_null("Zone/Terrain") as MeshInstance3D
	var m := t.material_override as ShaderMaterial if t != null else null
	if m == null:
		return
	m.set_shader_parameter("scorch_tex", texture())
	m.set_shader_parameter("scorch_rect", rect_v4())
