extends RefCounted
## THE SLEEPER (the world pass): a colossus of the Order, 80 m long, lying on its back on the heather of the Far Reaches.
## Lore: the Order raised a warden of stone to stand over the road. When the sky began to turn it lay down to sleep
## and did not stand again; its furnace-heart still burns, and it holds a fire in its open hand for whoever
## is still walking. From afar: a crown of stone spikes, a bonfire cupped in a hand and a beacon over the face.
## Inside: a wound in the flank (stairs up from the ground) opens on the heart-hall, a vaulted chamber 24 m long
## round a furnace on a dais (a chest beside it); two flights climb inside the chest to a hole in the roof; the roof
## is a deck with oculi; the neck leads up steps to the head, the right arm lies out across the heather as a 34 m
## bridge to the open hand (a bonfire in a basin, a second chest, the fingers curled round it).
## Built once from the kit's boxes (about 230, one mesh per material, collision from the same faces) over ground it
## sinks its footings into. Placed by WK.find_any in the Kings' Barrows (or the Arches): nothing else is moved.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

const CANDS := [Vector2(-326.0, 118.0), Vector2(-326.0, 196.0), Vector2(-318.0, 150.0), Vector2(-30.0, 350.0), Vector2(40.0, 360.0)]
const HALF := Vector2(37.0, 49.0)               ## the footprint's half extents in the body's frame (x across with the arm, z along)
const CEN := Vector2(18.0, 5.0)                 ## where that footprint's middle lies in the body's frame
const W := 11.0                                 ## the torso's half width

var k
var o := Vector2.ZERO                           ## the body frame's origin (world xz)
var yaw := 0.0
var y0 := 0.0                                   ## the floor datum: above every bit of ground under the body
var rot := Basis.IDENTITY


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _p(x: float, y: float, z: float) -> Vector3:
	var q := rot * Vector3(x, 0.0, z)
	return Vector3(o.x + q.x, y0 + y, o.y + q.z)


## A footing-deep block in the body's frame: x0..x1 across, z0..z1 along, top `top` over the datum; its foot goes down
## into the ground (the lowest of nine samples), so the colossus lies on the land, not over it.
func _seg(key: String, x0: float, x1: float, z0: float, z1: float, top: float, shade := 1.0, bottom := NAN) -> void:
	var lo := INF
	for i in 3:
		for j in 3:
			var pw := _p(lerpf(x0, x1, float(i) / 2.0), 0.0, lerpf(z0, z1, float(j) / 2.0))
			lo = minf(lo, WK.h(pw.x, pw.z))
	var bot := (lo - 0.9) if is_nan(bottom) else y0 + bottom
	var ytop := y0 + top
	var c := _p((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	k.kit.box(key, Vector3(c.x, (bot + ytop) * 0.5, c.z), Vector3(x1 - x0, ytop - bot, z1 - z0), Basis(Vector3.UP, yaw), true, shade)


## A block floating at a height (a slab, a lintel): from y_lo to y_hi over the datum.
func _slab(key: String, x0: float, x1: float, z0: float, z1: float, y_lo: float, y_hi: float, shade := 1.0) -> void:
	var c := _p((x0 + x1) * 0.5, (y_lo + y_hi) * 0.5, (z0 + z1) * 0.5)
	k.kit.box(key, c, Vector3(x1 - x0, y_hi - y_lo, z1 - z0), Basis(Vector3.UP, yaw), true, shade)


func _flight(key: String, a: Vector3, b: Vector3, width: float, base: float) -> void:
	var rise := absf(b.y - a.y)
	var steps := maxi(3, int(ceilf(rise / 0.36)))
	k.kit.stairs(key, a, b, width, steps, y0 + base)


func _run(root: Node) -> void:
	var f := WK.find_any(CANDS, HALF, [0.0, PI * 0.25, PI * 0.5, PI * 0.75, PI, PI * 1.25, PI * 1.5, PI * 1.75], ["kingsbarrows", "arches"], 9.0)
	if f.is_empty():
		push_warning("WONDER the_sleeper: no room in the Far Reaches")
		return
	var fy := float(f.yaw)
	yaw = -fy                                      # the footprint's x axis is (cos, sin) in (x, z): a turn about +y by -yaw
	rot = Basis(Vector3.UP, yaw)
	var mid: Vector2 = f.pos
	var q := rot * Vector3(CEN.x, 0.0, CEN.y)
	o = mid - Vector2(q.x, q.z)
	y0 = float(f.hi) + 0.4
	k = WK.new()
	k.setup(root, "TheSleeper", 3901)
	k.poi("sleeper", "The Sleeper", "it lay down to sleep, and its heart never went out", "kingsbarrows")
	WK.reserve("wonder_sleeper", mid, HALF, fy, float(f.lo), float(f.hi) + 16.0)
	_legs()
	_torso()
	_arms()
	_head()
	_dress()
	var n := k.commit()
	k.beacon(_p(0.0, 14.0, 40.0), Color(1.0, 0.72, 0.42), 1.4, 14.0, 380.0)
	print("WONDER the_sleeper at %s yaw %.2f datum %.1f: %d meshes, %d fires, %d lights, %d chests" % [mid, yaw, y0, n, k.fires, k.lights, k.chests])


# --- the legs and hips ----------------------------------------------------------------------------------

func _legs() -> void:
	for s: float in [-1.0, 1.0]:
		var xa := s * 1.4
		var xb := s * 9.2
		var x0 := minf(xa, xb)
		var x1 := maxf(xa, xb)
		_seg("stone_big", x0, x1, -42.0, -35.0, 6.4, 0.9)             # the boot, toe up
		_seg("ruin_big", x0 + 0.5 * absf(s), x1 - 0.5 * absf(s), -41.0, -36.0, 7.6, 0.8)
		_seg("stone_big", x0, x1, -35.0, -22.0, 4.6, 1.0)             # the shin
		_seg("ruin_big", x0 - 0.3, x1 + 0.3, -29.0, -27.0, 5.0, 0.84)  # a greave band
		_seg("stone_big", x0 - 0.4, x1 + 0.4, -22.0, -10.0, 6.8, 1.0)  # the thigh
		_slab("brick_big", x0 - 0.4, x1 + 0.4, -22.0, -10.0, 6.8, 7.4, 0.9)
	_seg("stone_big", -10.5, 10.5, -10.0, 0.0, 8.0, 0.95)           # the hips
	_slab("ruin_big", -11.0, 11.0, -6.0, -2.0, 8.0, 9.0, 0.82)      # the belt
	for i in 7:
		var bx := -9.0 + 3.0 * float(i)
		_slab("iron", bx - 0.5, bx + 0.5, -6.1, -1.9, 9.0, 9.9, 0.7)   # buckle studs along the belt


# --- the heart-hall -------------------------------------------------------------------------------------

func _torso() -> void:
	var fl := 0.3
	_seg("floor", -9.0, 9.0, 0.0, 26.0, fl, 0.9)                          # the hall's floor
	for s: float in [-1.0, 1.0]:
		var xa := s * 9.0
		var xb := s * 11.0
		var x0 := minf(xa, xb)
		var x1 := maxf(xa, xb)
		if s < 0.0:
			_seg("stone_big", x0, x1, 0.0, 26.0, 11.0, 1.0)
		else:                                                             # the east flank has the wound: z 6..11, 4.6 m high
			_seg("stone_big", x0, x1, 0.0, 6.0, 11.0, 1.0)
			_seg("stone_big", x0, x1, 11.0, 26.0, 11.0, 1.0)
			_slab("stone_big", x0, x1, 6.0, 11.0, 4.6, 11.0, 0.96)       # over the wound
			_slab("ruin_big", x0 - 0.3, x1 + 0.3, 5.6, 6.0, 0.3, 4.6, 0.8)   # the wound's jambs
			_slab("ruin_big", x0 - 0.3, x1 + 0.3, 11.0, 11.4, 0.3, 4.6, 0.8)
	_seg("stone_big", -11.0, 11.0, 26.0, 28.0, 11.0, 0.98)               # the shoulder wall
	_seg("stone_big", -11.0, 11.0, -0.5, 1.0, 11.0, 0.98)                # the waist wall
	# the roof: a slab y 10..11 with the stair's well open and three oculi
	_slab("stone_big", -11.0, 11.0, 1.0, 3.0, 10.0, 11.0, 0.96)
	_slab("stone_big", -11.0, -7.0, 3.0, 12.0, 10.0, 11.0, 0.96)
	_slab("stone_big", -2.0, 11.0, 3.0, 12.0, 10.0, 11.0, 0.96)
	var holes := [Vector2i(1, 1), Vector2i(3, 2), Vector2i(2, 4)]
	for ci in 5:
		for cj in 5:
			var hx := -9.0 + 4.0 * float(ci)
			var hz := 12.0 + 3.0 * float(cj)
			if holes.has(Vector2i(ci, cj)):
				continue
			_slab("stone_big", hx - 2.0, hx + 2.0, hz, hz + 3.0, 10.0, 11.0, 0.9 + 0.1 * float((ci + cj) % 2))
	_slab("stone_big", 9.0, 11.0, 12.0, 26.0, 10.0, 11.0, 0.96)
	# ribs under the roof, and a cross-beam with the hung lamps
	for zi in 4:
		var bz := 4.0 + 6.0 * float(zi)
		_slab("wood_big", -9.0, 9.0, bz, bz + 0.7, 9.3, 10.0, 0.9)
	# the two flights: A runs up the west side to a landing, B comes back through the roof's well
	var a0 := _p(-6.5, fl, 2.5)
	var a1 := _p(-6.5, 5.6, 17.0)
	_flight("stone_big", a0, a1, 2.2, fl)
	_slab("stone_big", -9.0, -3.0, 17.0, 20.5, fl, 5.6, 0.95)           # the landing
	var b0 := _p(-4.2, 5.6, 18.0)
	var b1 := _p(-4.2, 10.9, 3.4)
	_flight("stone_big", b0, b1, 2.2, 5.6)
	# the heart: a dais, a furnace of glowing facets over a fire basin, a chest beside it
	_seg("ruin_big", 0.0, 7.0, 13.0, 21.0, 1.3, 0.9, 0.0)
	_seg("stone_big", 0.6, 6.4, 13.6, 20.4, 1.8, 1.0, 0.0)
	var hc := _p(3.5, 3.4, 17.0)
	k.kit.box("glow", hc, Vector3(1.8, 1.8, 1.8), Basis(Vector3.UP, yaw + PI * 0.25) * Basis(Vector3.RIGHT, PI * 0.25), false)
	k.kit.box("iron", hc + Vector3.DOWN * 1.5, Vector3(0.5, 1.4, 0.5), Basis(Vector3.UP, yaw), false)
	for i in 4:
		var a := TAU * float(i) / 4.0 + yaw
		k.kit.box("iron", hc + Vector3(cos(a) * 1.4, -0.3, sin(a) * 1.4), Vector3(0.14, 2.6, 0.14), Basis(Vector3.UP, a), false)
	k.fire(_p(3.5, 1.9, 17.0), 1.5, 2.6)
	k.lamp(hc + Vector3.UP * 0.8, Color(1.0, 0.5, 0.24), 2.4, 15.0)
	var cp := _p(5.9, 1.8, 14.2)
	k.chest("sleeper_heart", "reliquary", cp, yaw + PI, {"grave_ash": 22, "grave_iron": 3, "relic_fragment": 2})
	# lamps down the hall, braziers by the wound, lit slits in the flanks
	k.lamp(_p(-3.0, 8.4, 6.0), Color(1.0, 0.68, 0.4), 1.1, 9.0)
	k.lamp(_p(0.0, 8.4, 22.0), Color(1.0, 0.68, 0.4), 1.1, 9.0)
	k.fire(_p(8.0, 0.3, 8.5), 0.6, 1.3)
	for zi in 4:
		var wz := 3.0 + 6.5 * float(zi)
		k.window(_p(-8.95, 5.2, wz), rot * Vector3(0.0, 0.0, 1.0), rot * Vector3(1.0, 0.0, 0.0), 1.3, 3.0)
		k.window(_p(-11.05, 5.2, wz), rot * Vector3(0.0, 0.0, 1.0), rot * Vector3(-1.0, 0.0, 0.0), 1.3, 3.0)     # the lit slit seen from outside
		if absf(wz - 8.5) > 3.6:
			k.window(_p(11.05, 5.2, wz), rot * Vector3(0.0, 0.0, 1.0), rot * Vector3(1.0, 0.0, 0.0), 1.3, 3.0)
	# the wound's sill, and the stair up to it from the ground east of the flank
	_seg("floor", 9.0, 11.0, 6.0, 11.0, fl, 0.9)
	var g0 := WK.h(_p(20.0, 0.0, 8.5).x, _p(20.0, 0.0, 8.5).z)
	var steps := maxi(3, int(ceilf((y0 + fl - g0 + 0.2) / 0.36)))
	var run := float(steps) * 0.95
	var lo_s := _p(11.0 + run, 0.0, 8.5)
	var g1 := WK.h(lo_s.x, lo_s.z)
	k.kit.stairs("stone_big", Vector3(lo_s.x, g1 - 0.2, lo_s.z), _p(11.0, fl, 8.5), 3.2, steps, g1 - 1.5)
	k.fire(_p(12.0, fl + 1.0, 5.2), 0.8, 1.5)
	k.fire(_p(12.0, fl + 1.0, 11.8), 0.8, 1.5)


# --- the arms -------------------------------------------------------------------------------------------

func _arms() -> void:
	# the left arm folded along the flank, the fist on the belly's edge
	_seg("stone_big", -17.0, -11.0, 2.0, 20.0, 7.0, 0.96)
	_seg("ruin_big", -17.5, -10.5, 18.0, 25.0, 8.2, 0.88)
	_slab("stone_big", -17.0, -11.0, 14.0, 20.0, 7.0, 8.0, 0.9)
	# the right arm, out across the heather: shoulder deck 11, steps down to the forearm 9, the hand at 9
	_seg("stone_big", 11.0, 18.0, 17.0, 27.0, 11.0, 1.0)
	_slab("ruin_big", 11.0, 18.0, 16.8, 17.4, 9.0, 11.6, 0.8)
	_seg("stone_big", 18.0, 23.0, 18.5, 26.0, 8.0, 0.9)
	_flight("stone_big", _p(18.0, 11.0, 22.0), _p(23.0, 9.0, 22.0), 5.0, 8.0)
	_seg("stone_big", 23.0, 34.0, 18.5, 26.0, 9.0, 0.98)
	_slab("brick_big", 23.0, 34.0, 18.5, 19.2, 9.0, 9.9, 0.84)           # low parapets along the forearm
	_slab("brick_big", 23.0, 34.0, 25.3, 26.0, 9.0, 9.9, 0.84)
	# the hand: the palm, the thumb, four fingers curled round the fire in the basin
	_seg("stone_big", 34.0, 46.0, 14.0, 30.0, 9.0, 1.0)
	_seg("stone_big", 34.0, 40.0, 10.0, 14.0, 9.6, 0.94)                  # the thumb
	for i in 4:
		var fz := 14.5 + 4.4 * float(i)
		_seg("stone_big", 46.0, 53.0, fz, fz + 3.2, 10.4 + 0.5 * float(i % 2), 0.96)
		_slab("ruin_big", 49.0, 53.0, fz + 0.2, fz + 3.0, 10.4, 12.0 - 0.4 * float(i % 2), 0.9)
	var bc := Vector3(0.0, 0.0, 0.0)
	var palm := _p(41.0, 9.0, 22.0)
	bc = palm
	k.kit.box("iron", bc + Vector3.UP * 0.45, Vector3(3.4, 0.9, 3.4), Basis(Vector3.UP, yaw + 0.4), true, 0.8)
	k.kit.box("dark", bc + Vector3.UP * 0.95, Vector3(2.6, 0.3, 2.6), Basis(Vector3.UP, yaw + 0.4), false, 0.5)
	k.fire(bc + Vector3.UP * 1.1, 3.4, 4.2)
	k.chest("sleeper_hand", "iron", _p(37.0, 9.0, 27.0), yaw + PI * 0.6, {"grave_ash": 12, "grave_iron": 2})
	k.lamp(bc + Vector3.UP * 3.0, Color(1.0, 0.6, 0.3), 2.6, 24.0)


# --- the neck and the head -----------------------------------------------------------------------------

func _head() -> void:
	_seg("stone_big", -5.0, 5.0, 28.0, 36.0, 11.0, 0.96)                  # the neck
	_flight("stone_big", _p(0.0, 11.0, 28.5), _p(0.0, 14.2, 35.0), 3.0, 10.6)
	_seg("stone_big", -8.0, 8.0, 36.0, 52.0, 14.2, 1.0)                    # the head (the face looks up)
	_slab("ruin_big", -8.4, 8.4, 51.4, 52.0, 14.2, 14.9, 0.84)          # the brow rim: the back and the sides, the front (the stair's side) open
	_slab("ruin_big", -8.4, -7.8, 36.6, 52.0, 14.2, 14.9, 0.84)
	_slab("ruin_big", 7.8, 8.4, 36.6, 52.0, 14.2, 14.9, 0.84)
	# the face: a nose ridge, two lit eyes, a mouth line
	_slab("stone_big", -0.9, 0.9, 40.0, 46.0, 14.2, 15.6, 0.9)
	for s: float in [-1.0, 1.0]:
		var e := _p(s * 3.6, 14.25, 44.0)
		var ex := rot * Vector3(1.5, 0.0, 0.0)
		var ez := rot * Vector3(0.0, 0.0, 0.7)
		k.kit.quad("glow", e - ex - ez, e + ex - ez, e + ex + ez, e - ex + ez, Vector3.UP, false, 1.0)
		k.lamp(e + Vector3.UP * 2.2, Color(1.0, 0.62, 0.3), 1.2, 8.0)
	_slab("dark", -3.5, 3.5, 37.2, 38.0, 14.2, 14.45, 0.5)
	# the crown: a ring of stone spikes rising from the head's far end, and two great horns
	for i in 9:
		var a := PI * (0.12 + 0.76 * float(i) / 8.0)
		var base := _p(cos(a) * 6.6, 14.2, 50.0 - sin(a) * 3.0)
		var tip := base + Vector3(0.0, 5.0 + 3.0 * absf(sin(float(i) * 1.7)) + (3.0 if i % 2 == 0 else 0.0), 0.0) + rot * Vector3(cos(a) * 1.2, 0.0, 0.0)
		k.tube("stone_big", base, tip, 0.9, 0.12, 5, false, 0.95)
	for s: float in [-1.0, 1.0]:
		var hb := _p(s * 8.4, 13.0, 41.0)
		k.tube("ruin_big", hb, hb + rot * Vector3(s * 6.5, 0.0, 3.0) + Vector3(0.0, 9.0, 0.0), 1.6, 0.2, 6, false, 0.9)
	k.fire(_p(0.0, 14.2, 49.0), 1.4, 2.0)                                 # a small fire on the crown: the sleeper's brow lit


# --- secondary forms: rubble, ivy, banners, chains, cracks, a looters' camp -----------------------------------

func _g(x: float, z: float) -> Vector3:
	var p := _p(x, 0.0, z)
	return Vector3(p.x, WK.h(p.x, p.z), p.z)


func _dress() -> void:
	var al := rot * Vector3(0.0, 0.0, 1.0)
	var ac := rot * Vector3(1.0, 0.0, 0.0)
	for q: Vector3 in [Vector3(-5.0, 0.0, -44.0), Vector3(5.0, 0.0, -45.0), Vector3(-14.0, 0.0, -20.0), Vector3(15.0, 0.0, -14.0), Vector3(-21.0, 0.0, 12.0), Vector3(40.0, 0.0, 6.0)]:
		Dress.rubble(k, _g(q.x, q.z), 4.5, 12, "ruin_big")
	Dress.camp(k, _g(21.0, 3.0), yaw + 0.6)
	Dress.rope(k, _p(15.0, 5.0, 3.0), _p(15.0, 5.0, 9.0), 0.4)
	Dress.strands(k, _p(23.0, 8.8, 18.5), _p(34.0, 8.8, 18.5), 9, 5.5)
	Dress.strands(k, _p(11.0, 10.9, 2.0), _p(11.0, 10.9, 26.0), 12, 8.0)
	Dress.strands(k, _p(-11.0, 10.9, 2.0), _p(-11.0, 10.9, 26.0), 10, 7.0)
	Dress.strands(k, _p(-8.0, 14.1, 36.0), _p(8.0, 14.1, 36.0), 8, 4.0)
	Dress.banner(k, _p(49.0, 12.2, 15.0), al, 3.0, 6.5, ac)
	Dress.banner(k, _p(49.0, 12.2, 24.0), al, 3.0, 5.5, ac)
	Dress.chain(k, _p(51.0, 11.8, 17.5), _p(51.0, 11.8, 24.5), 1.3)
	Dress.chain(k, _p(-8.0, 10.9, 36.0), _p(8.0, 10.9, 36.0), 1.0)
	Dress.crack(k, _p(-6.0, 11.03, 5.0), _p(8.0, 11.03, 24.0), 0.16)
	Dress.crack(k, _p(-9.0, 7.1, 2.0), _p(-11.2, 4.0, 20.0), 0.14)
	Dress.carved_band(k, _p(-10.0, 8.6, -7.3), _p(10.0, 8.6, -7.3), 12, Vector3(1.3, 0.5, 0.35))
	Dress.carved_band(k, _p(-10.5, 10.6, 27.6), _p(10.5, 10.6, 27.6), 12, Vector3(1.3, 0.5, 0.35))
