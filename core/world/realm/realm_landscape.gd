extends RefCounted
## RealmLandscape: the Far Reaches' lie of the land between their set pieces. RealmReaches gives each new region its
## own landform (a fell, a ridge, a basin, a valley) and pulls the towns flat; left at that, the open country between
## them read as level boards from above and from the road. This adds what open country has: long swells and vales a
## couple of hundred metres across, smaller hills on their backs, and dales wandering down between them, all warped so
## nothing lines up. Only beyond the Marches (outside RealmReaches.MARCH_BOUNDS): the old Realm's and the Marches'
## ground carries rounds of placements tuned to it (lore carriers, secrets, POIs, the villagers' stops), and relief
## there tipped them off their spots; the Far Reaches' slots get a level pad each.
##
## Where the ground is designed it stays as designed: the towns and the chapel, the raid floors, the kept core (rift,
## summit, Ossuary), the quarry, the Well, the crater, the keep's crag, the Grandmother Oak's knoll, the siege lines,
## the lakes, meres and fens (no new pool is made or drowned), the pans, the March Wall's line, the Crowns' wall and the
## Realm's edge cliffs. Near water and on the road's plain the ground only ever rises (no new hollow to flood, no ditch
## under a road), and low country is only ever raised (a dip under -0.6 m would be floored flat by RealmLand). Paths are levelled over it afterwards along their own smoothed profiles (RealmLand).
##
## RealmLand._base calls relief() on the macro height with the spot's biome weights (one line there); nothing else
## reads it, so RealmLayout.macro_height (the planning shape) is unchanged. Pure and thread-safe: the noises are made
## when the script loads (on the main thread), and only read after.

## Biome order of RealmLand._bw: meadow, loam, mud, ash, heath, crag, ruin, salt. How open each is to relief.
const OPEN := [1.0, 0.85, 0.0, 0.0, 1.0, 0.5, 0.45, 0.0]

## Every slot's pad (RealmLayout.SLOTS: the fires, places and camps the region builders put down): level within PAD.x,
## the relief back by PAD.y.
const PAD := Vector2(9.0, 22.0)
static var _slots := _slot_list()

## Designed ground: [centre, radius where relief is none, radius where it is whole].
const KEEP := [
	[Vector2(6.0, 38.0), 34.0, 62.0],          # Hearthward
	[Vector2(-72.0, 52.0), 18.0, 34.0],        # the Chapel of the First Kindling
	[Vector2(-205.0, 66.0), 32.0, 56.0],       # Weirford
	[Vector2(212.0, 92.0), 24.0, 46.0],        # Saltmarket
	[Vector2(322.0, 44.0), 42.0, 66.0],        # Lastlight (RealmReaches.TOWN_E)
	[Vector2(-160.0, 300.0), 52.0, 80.0],      # Fallowmere (RealmReaches.TOWN_F)
	[Vector2(-127.0, -104.0), 42.0, 62.0],     # the Saints' Quarry
	[Vector2(72.0, 204.0), 26.0, 46.0],        # the Well of Echoes
	[Vector2(-70.0, 206.0), 26.0, 42.0],       # the Grandmother Oak's knoll
	[Vector2(-206.0, 148.0), 44.0, 66.0],      # the Siege Lines' ring
	[Vector2(206.0, 4.0), 46.0, 70.0],         # Stillwater
	[Vector2(242.0, 6.0), 16.0, 28.0],         # the Spire's bluff
	[Vector2(350.0, 102.0), 20.0, 34.0],       # the Bellfall crater (RealmReaches.CRATER_C)
	[Vector2(-318.0, -108.0), 26.0, 42.0],     # the Broken Keep's crag (RealmReaches.KEEP_C)
	[Vector2(318.0, 164.0), 50.0, 74.0],       # the Drowned Nave's mere (RealmReaches.NAVE_C)
]

static var _n_swell := _noise(5101, 0.0058, 2)
static var _n_hill := _noise(5102, 0.017, 2)
static var _n_dale := _noise(5103, 0.0075, 1)
static var _n_warp := _noise(5104, 0.0035, 1)
static var _n_old := _noise(5105, 0.0042, 1)
static var _n_downs := _noise(5106, 0.02, 2)


static func _slot_list() -> PackedVector2Array:
	var out := PackedVector2Array()
	for id: String in RealmLayout.SLOTS:
		for s: Dictionary in RealmLayout.SLOTS[id]:
			out.append(s.at)
	return out


## 1 away from every slot, 0 on its pad.
static func slot_free(p: Vector2) -> float:
	var f := 1.0
	for s in _slots:
		var d := p.distance_squared_to(s)
		if d < PAD.y * PAD.y:
			f = minf(f, smoothstep(PAD.x, PAD.y, sqrt(d)))
	return f


static func _noise(seed_n: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_n
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_octaves = octaves
	return n


## The macro height `h` at (x, z) with the open country's relief added. `bw`: RealmLand's biome weights there.
static func relief(x: float, z: float, h: float, bw: PackedFloat32Array) -> float:
	var open := 0.0
	for i in OPEN.size():
		open += float(OPEN[i]) * bw[i]
	if open <= 0.01:
		return h
	var p := Vector2(x, z)
	var far := smoothstep(0.0, 24.0, RealmLayout._out_dist(p, RealmReaches.MARCH_BOUNDS))
	if far <= 0.0:
		return _swells(p, h, open)
	var k := open * far * _free(p)
	if k <= 0.001:
		return h
	k *= slot_free(p)
	if k <= 0.001:
		return h
	var q := p + Vector2(_n_warp.get_noise_2d(x, z), _n_warp.get_noise_2d(x + 311.0, z - 173.0)) * 38.0
	var swell := _n_swell.get_noise_2d(q.x, q.y)
	var hills := _n_hill.get_noise_2d(q.x, q.y)
	var dale := 1.0 - absf(_n_dale.get_noise_2d(q.x, q.y))
	var r := swell * 6.0 + hills * 1.4 - smoothstep(0.8, 0.97, dale) * 2.2
	# only ground that stands high enough is cut down: RealmLand floors every dry hollow under -0.6 m flat (no stray
	# ponds), so low country that dipped would turn into flat-bottomed pans. It rises instead.
	if r < 0.0:
		r *= smoothstep(-0.3, 4.5, h)
	# near water and on the road's plain the ground only rises
	var only_up := maxf(_wet(p), _road(z))
	if only_up > 0.0:
		r = lerpf(r, maxf(r, 0.0) * 0.6, only_up)
	return h + r * k


## The old Realm's and the Marches' ground: only long, gentle swells (a quarter-kilometre across, a couple of metres
## high, never steeper than ~6 %), so the land rolls from the road without tipping any of the places, carriers and
## camps tuned to it; low ground is only raised. Off the old Realm's own set pieces too (OLD_KEEP).
const OLD_KEEP := [
	[Vector2(-28.0, 32.0), 16.0, 30.0],        # the Glimmer Glade (moved out of the henge's 1.6x skirt, 18 Nov)
	[Vector2(-165.0, 12.0), 22.0, 38.0],       # the Rooted Holds' hollow (moved west off the henge's 1.6x skirt, 18 Nov)
	[Vector2(-109.0, 121.0), 44.0, 62.0],      # the Cinder Orchard's rows
	[Vector2(131.0, -89.0), 30.0, 46.0],       # the Founder's Pits' bench
	[Vector2(-1.0, 127.0), 46.0, 66.0],        # the Waiting Field
	[Vector2(82.0, -18.0), 16.0, 30.0],        # the Drowned Belfry
	[Vector2(-86.0, -62.0), 22.0, 40.0],       # the Charcoal Hollow
	[Vector2(46.0, 40.0), 16.0, 30.0],         # the Almonry
	[Vector2(-52.0, -100.0), 16.0, 30.0],      # the Watchers' Spire
	[Vector2(141.0, -24.0), 18.0, 30.0],       # the Lanternless Moor's tor
]


static func _swells(p: Vector2, h: float, open: float) -> float:
	var k := open * _free(p)
	if k <= 0.001:
		return h
	for e: Array in OLD_KEEP:
		k *= smoothstep(float(e[1]), float(e[2]), p.distance_to(e[0]))
		if k <= 0.001:
			return h
	k *= slot_free(p)
	var q := p + Vector2(_n_warp.get_noise_2d(p.x, p.y), _n_warp.get_noise_2d(p.x + 311.0, p.y - 173.0)) * 38.0
	var r := _n_old.get_noise_2d(q.x, q.y) * 3.4
	if r < 0.0:
		r *= smoothstep(-0.3, 4.5, h)
	var only_up := maxf(_wet(p), _road(p.y))
	if only_up > 0.0:
		r = lerpf(r, maxf(r, 0.0) * 0.6, only_up)
	return h + r * k


## The Southern Downs' rolling chalk (RealmLayout._marches): the same amplitude the old sine grid had, as warped noise.
static func downs(x: float, z: float) -> float:
	var q := Vector2(x, z) + Vector2(_n_warp.get_noise_2d(x, z), _n_warp.get_noise_2d(x + 311.0, z - 173.0)) * 30.0
	return _n_downs.get_noise_2d(q.x, q.y) * 3.4 + _n_hill.get_noise_2d(x * 0.6, z * 0.6) * 0.8


## 1 in open country, 0 on designed ground, eased between.
static func _free(p: Vector2) -> float:
	var f := 1.0
	for e: Array in KEEP:
		f = minf(f, smoothstep(float(e[1]), float(e[2]), p.distance_to(e[0])))
		if f <= 0.0:
			return 0.0
	for rd: Dictionary in RealmLayout.RAIDS:
		var rr := float(rd.r) + float(rd.fall)
		f = minf(f, smoothstep(rr + 4.0, rr + 26.0, p.distance_to(rd.c)))
	# the kept core (the rift and the summit, the Ossuary's pit) and the Ossuary's quarry face
	f = minf(f, smoothstep(10.0, 30.0, RealmLayout._out_dist(p, Rect2(-30.0, -122.0, 60.0, 110.0))))
	var ob := RealmLayout.OSSUARY
	f = minf(f, smoothstep(8.0, 28.0, RealmLayout._out_dist(p, Rect2(ob.position.x, ob.position.z, ob.size.x, ob.size.z))))
	# the White Pans (flat by design)
	f = minf(f, smoothstep(6.0, 24.0, RealmLayout._out_dist(p, RealmLayout.PANS)))
	# the Crowns' wall (shaped on its own) and the Realm's edge cliffs
	f *= smoothstep(-116.0, -92.0, p.y)
	var bd := RealmLayout.BOUNDS
	f *= smoothstep(12.0, 38.0, minf(minf(p.x - bd.position.x, bd.end.x - p.x), bd.end.y - p.y))
	# the March Wall stands on its crest
	var side := -1 if p.x < 0.0 else 1
	f *= smoothstep(10.0, 30.0, absf(absf(p.x) - RealmMarch.wall_x(side, p.y)))
	return f


## Near the Sorrow (its valley and banks): 1 at the channel, 0 from 70 m off.
static func _wet(p: Vector2) -> float:
	if p.x > -150.0:
		return 0.0
	return 1.0 - smoothstep(20.0, 70.0, RealmLayout.river_near(p.x, p.y).x)


## The Pilgrims' Road's plain (z 50..80, the road running along it): 1 on it, 0 from 24 m off.
static func _road(z: float) -> float:
	return 1.0 - smoothstep(0.0, 24.0, maxf(50.0 - z, z - 80.0))
