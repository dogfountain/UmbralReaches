extends SceneTree
## Realm flora textures (docs/REALM_PLAN.md, flora module). Painted procedurally, no numpy:
##   godot --headless -s tools/gen_realm_foliage.gd
## -> art/textures/realm_foliage_atlas.png   2048 x 2048, 4 x 4 cells of 512 (alpha cards):
##      0 oak cluster    1 birch cluster   2 pine spray      3 willow strands
##      4 shrub leaves   5 bramble         6 fern frond      7 grass tuft
##      8 wildflowers    9 heather        10 reeds          11 cattails
##     12 dead twigs    13 leaf litter    14 moss mat       15 hanging moss
##    Cards that stand on the ground (6-11, 15 hangs from the top) have their root at the cell's
##    bottom edge; clusters (0-5, 12) grow from the bottom centre; 13/14 are seen from above.
## -> art/textures/realm_birch_bark_{albedo,normal}.png   512 x 1024 tileable birch bark

const CELL := 512
const N := 4
const SIZE := CELL * N
const PAD := 10

var px := PackedFloat32Array()          # RGBA premultiplied-free straight colour, painter's order
var rng := RandomNumberGenerator.new()
var ox := 0                             # current cell origin
var oy := 0


func _init() -> void:
	px.resize(SIZE * SIZE * 4)
	px.fill(0.0)
	var cells := [_oak, _birch, _pine, _willow, _shrub, _bramble, _fern, _grass,
		_flowers, _heather, _reeds, _cattails, _twigs, _litter, _moss, _hang]
	for i in cells.size():
		ox = (i % N) * CELL
		oy = (i / N) * CELL
		rng.seed = 1000 + i * 77
		(cells[i] as Callable).call()
	# transparent texels are bled by the importer (process/fix_alpha_border)
	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBAF, px.to_byte_array())
	img.convert(Image.FORMAT_RGBA8)
	img.save_png("res://art/textures/realm_foliage_atlas.png")
	_birch_bark()
	print("REALM_FOLIAGE written")
	quit()


# --- painting primitives ------------------------------------------------------------------------

func _blend(x: int, y: int, c: Color, a: float) -> void:
	if x < ox + 2 or y < oy + 2 or x >= ox + CELL - 2 or y >= oy + CELL - 2 or a <= 0.0:
		return
	var i := (y * SIZE + x) * 4
	var da := px[i + 3]
	var oa := a + da * (1.0 - a)
	if oa <= 0.0:
		return
	for k in 3:
		px[i + k] = (c[k] * a + px[i + k] * da * (1.0 - a)) / oa
	px[i + 3] = oa


## Leaf in cell-local pixels: base at (bx, by), pointing `ang` (radians, 0 = up), length, width.
## shape: 0 ovate, 1 oak (lobed), 2 lance (willow), 3 round (birch, serrated), 4 holly-ish
func _leaf(bx: float, by: float, ang: float, length: float, width: float, col: Color, shape := 0) -> void:
	var d := Vector2(sin(ang), -cos(ang))
	var nrm := Vector2(-d.y, d.x)
	var r := maxf(length, width) + 2.0
	var x0 := int(bx - r); var x1 := int(bx + r)
	var y0 := int(by - r); var y1 := int(by + r)
	var light := rng.randf_range(-0.12, 0.12)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5 - bx, y + 0.5 - by)
			var u := p.dot(d) / length
			if u < 0.0 or u > 1.0:
				continue
			var v := p.dot(nrm)
			var w := 0.0
			match shape:
				1:
					w = width * pow(sin(PI * clampf(u * 0.95 + 0.05, 0, 1)), 0.7) * (0.62 + 0.38 * absf(sin(u * PI * 3.5)))
				2:
					w = width * pow(sin(PI * u), 1.2)
				3:
					w = width * pow(sin(PI * pow(u, 0.8)), 0.6) * (0.93 + 0.07 * absf(sin(u * 40.0)))
				4:
					w = width * pow(sin(PI * u), 0.55) * (0.8 + 0.2 * absf(sin(u * PI * 4.0)))
				_:
					w = width * pow(sin(PI * pow(u, 0.75)), 0.7)
			var av := absf(v)
			if av > w + 1.0:
				continue
			var a := clampf(w + 0.5 - av, 0.0, 1.0)
			# shading: midrib dark, side veins, one half lit, edge darker, tip lighter
			var side := 0.1 if v > 0.0 else -0.06
			var rib := 1.0 - 0.35 * clampf(1.2 - av, 0.0, 1.0)
			var vein := 1.0 - 0.1 * clampf(1.0 - absf(fmod(u * 9.0 - av / maxf(w, 1.0) * 1.6, 1.0) - 0.5) * 8.0, 0.0, 1.0)
			var edge := 1.0 - 0.25 * clampf((av / maxf(w, 0.5) - 0.7) * 3.0, 0.0, 1.0)
			var f := (1.0 + side + light + u * 0.08) * rib * vein * edge
			_blend(ox + x, oy + y, Color(col.r * f, col.g * f, col.b * f), a)


## Tapered stroke from a to b (cell-local), radii r0 -> r1.
func _stroke(a: Vector2, b: Vector2, r0: float, r1: float, c0: Color, c1 := Color(-1, 0, 0)) -> void:
	if c1.r < 0.0:
		c1 = c0
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.0001)
	var rr := maxf(r0, r1) + 2.0
	var lo := a.min(b) - Vector2(rr, rr)
	var hi := a.max(b) + Vector2(rr, rr)
	for y in range(int(lo.y), int(hi.y) + 1):
		for x in range(int(lo.x), int(hi.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var r := lerpf(r0, r1, t)
			var dist := p.distance_to(a + ab * t)
			var al := clampf(r + 0.5 - dist, 0.0, 1.0)
			if al > 0.0:
				var c := c0.lerp(c1, t)
				var sh := 1.0 - 0.3 * clampf(dist / maxf(r, 0.5), 0.0, 1.0)
				_blend(ox + x, oy + y, Color(c.r * sh, c.g * sh, c.b * sh), al)


## Curved polyline stroke (quadratic bezier a -> ctrl -> b).
func _curve(a: Vector2, ctrl: Vector2, b: Vector2, r0: float, r1: float, c0: Color, c1 := Color(-1, 0, 0), seg := 8) -> void:
	if c1.r < 0.0:
		c1 = c0
	var prev := a
	for k in range(1, seg + 1):
		var t := float(k) / seg
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		var t0 := float(k - 1) / seg
		_stroke(prev, p, lerpf(r0, r1, t0), lerpf(r0, r1, t), c0.lerp(c1, t0), c0.lerp(c1, t))
		prev = p


func _bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


func _jit(c: Color, amt: float) -> Color:
	var k := rng.randf_range(1.0 - amt, 1.0 + amt)
	return Color(c.r * k * rng.randf_range(0.95, 1.05), c.g * k, c.b * k * rng.randf_range(0.95, 1.05))


## A branching cluster: twigs from the bottom centre fanning up, leaves along them.
func _cluster(leaf_col: Color, shape: int, n_twigs: int, leaves_per: int, llen: Vector2, lw: float, twig_col: Color, spread := 1.0, droop := 0.0) -> void:
	var base := Vector2(CELL * 0.5, CELL - PAD - 4)
	var tips: Array = []
	for t in n_twigs:
		var ang := lerpf(-1.15, 1.15, (float(t) + rng.randf_range(0.1, 0.9)) / n_twigs) * spread
		var length := rng.randf_range(0.6, 0.92) * CELL * 0.82
		var tip := base + Vector2(sin(ang), -cos(ang)) * length
		tip.y += droop * length * 0.3
		var ctrl := base.lerp(tip, 0.5) + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 10))
		tips.append([base, ctrl, tip])
		_curve(base, ctrl, tip, 1.8, 0.6, twig_col)
	# leaves: back layer darker, front lighter
	for layer in 2:
		for tw: Array in tips:
			for k in leaves_per:
				var t := rng.randf_range(0.12, 1.0)
				var p := _bez(tw[0], tw[1], tw[2], t)
				var tan := (_bez(tw[0], tw[1], tw[2], minf(t + 0.05, 1.0)) - _bez(tw[0], tw[1], tw[2], maxf(t - 0.05, 0.0))).normalized()
				var ang := atan2(tan.x, -tan.y) + rng.randf_range(-1.3, 1.3)
				var l := rng.randf_range(llen.x, llen.y) * (1.0 - 0.3 * (1.0 - t))
				var c := _jit(leaf_col, 0.18) * (0.72 if layer == 0 else 1.0)
				_leaf(p.x, p.y, ang + droop * 0.6, l, l * lw, c, shape)


# --- cells ---------------------------------------------------------------------------------------

func _oak() -> void:
	_cluster(Color(0.20, 0.33, 0.17), 1, 7, 9, Vector2(44, 70), 0.42, Color(0.18, 0.14, 0.11))


func _birch() -> void:
	_cluster(Color(0.36, 0.46, 0.18), 3, 9, 11, Vector2(24, 38), 0.55, Color(0.25, 0.2, 0.18), 1.1, 0.4)


func _pine() -> void:
	# a spray: main twig up the middle, side twigs, dense needles
	var base := Vector2(CELL * 0.5, CELL - PAD - 4)
	var top := Vector2(CELL * 0.5 + rng.randf_range(-20, 20), PAD + 30)
	var twigs: Array = [[base, base.lerp(top, 0.5) + Vector2(10, 0), top]]
	for k in 8:
		var t := 0.2 + 0.09 * k
		var p := _bez(base, base.lerp(top, 0.5), top, t)
		var s := 1.0 if k % 2 == 0 else -1.0
		var length := (1.0 - t) * 260.0 + 40.0
		var tip := p + Vector2(s * length * 0.8, -length * 0.45)
		twigs.append([p, p.lerp(tip, 0.5) + Vector2(0, -10), tip])
	for tw: Array in twigs:
		_curve(tw[0], tw[1], tw[2], 2.5, 1.0, Color(0.2, 0.15, 0.12))
	for layer in 3:
		for tw: Array in twigs:
			var length := (tw[0] as Vector2).distance_to(tw[2])
			var n := int(length / 2.5)
			for k in n:
				var t := rng.randf()
				var p := _bez(tw[0], tw[1], tw[2], t)
				var tan := (_bez(tw[0], tw[1], tw[2], minf(t + 0.03, 1.0)) - p).normalized()
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var ang := atan2(tan.x, -tan.y) + side * rng.randf_range(0.5, 1.1)
				var nl := rng.randf_range(18, 30) * (1.0 - 0.4 * t)
				var c := _jit(Color(0.12, 0.24, 0.17), 0.2) * (0.7 + 0.15 * layer)
				var d := Vector2(sin(ang), -cos(ang))
				_stroke(p, p + d * nl, 1.4, 0.6, c, c * 1.25)


func _willow() -> void:
	# three dense hanging strands from the top edge with narrow leaves: a card is a ribbon (core/world/realm/tree_gen.gd
	# make_willow lays many of them, narrow, with gaps between: at range the texture's own gaps fill in, the geometry's don't)
	for s in 3:
		var x := lerpf(110, CELL - 110, float(s) / 2.0) + rng.randf_range(-14, 14)
		var top := Vector2(x, PAD + 4)
		var bot := Vector2(x + rng.randf_range(-30, 30), CELL - PAD - rng.randf_range(4, 90))
		var ctrl := top.lerp(bot, 0.5) + Vector2(rng.randf_range(-30, 30), 0)
		_curve(top, ctrl, bot, 2.2, 1.0, Color(0.24, 0.22, 0.14))
		var n := int(top.distance_to(bot) / 7.0)
		for k in n:
			var t := float(k) / n + rng.randf_range(0, 0.03)
			var p := _bez(top, ctrl, bot, t)
			var side := 1.0 if k % 2 == 0 else -1.0
			var ang := PI + side * rng.randf_range(0.25, 0.6)
			var l := rng.randf_range(44, 72) * (0.75 + 0.25 * sin(PI * t))
			_leaf(p.x, p.y, ang, l, l * 0.2, _jit(Color(0.30, 0.38, 0.22), 0.18), 2)


func _shrub() -> void:
	_cluster(Color(0.13, 0.27, 0.16), 4, 10, 10, Vector2(30, 52), 0.5, Color(0.17, 0.13, 0.1), 1.25)


func _bramble() -> void:
	# arching thorny canes with leaflets in threes and a few dark berries
	var canes: Array = []
	for c in 7:
		var a := Vector2(rng.randf_range(80, CELL - 80), CELL - PAD - 4)
		var b := Vector2(rng.randf_range(PAD + 20, CELL - PAD - 20), rng.randf_range(CELL * 0.35, CELL * 0.8))
		var ctrl := Vector2((a.x + b.x) * 0.5 + rng.randf_range(-60, 60), rng.randf_range(PAD + 20, CELL * 0.3))
		canes.append([a, ctrl, b])
		_curve(a, ctrl, b, 4.0, 1.5, Color(0.26, 0.12, 0.13), Color(0.32, 0.18, 0.16), 14)
		for k in 18:
			var t := rng.randf()
			var p := _bez(a, ctrl, b, t)
			var tan := (_bez(a, ctrl, b, minf(t + 0.03, 1.0)) - p).normalized()
			var side := Vector2(-tan.y, tan.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			_stroke(p, p + side * 6.0 - tan * 3.0, 1.6, 0.3, Color(0.5, 0.42, 0.36))
	for cn: Array in canes:
		for k in 7:
			var t := rng.randf_range(0.15, 1.0)
			var p := _bez(cn[0], cn[1], cn[2], t)
			var ang0 := rng.randf_range(-2.5, 2.5)
			for j in 3:
				var l := rng.randf_range(24, 38) * (1.15 if j == 1 else 0.85)
				_leaf(p.x, p.y, ang0 + (j - 1) * 0.75, l, l * 0.38, _jit(Color(0.16, 0.26, 0.14), 0.2), 4)
		for k in 3:
			var p := _bez(cn[0], cn[1], cn[2], rng.randf_range(0.6, 1.0)) + Vector2(rng.randf_range(-8, 8), 6)
			for j in 5:
				var q := p + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
				_stroke(q, q + Vector2(0.1, 0.1), 3.5, 3.5, Color(0.14, 0.05, 0.12))


func _fern() -> void:
	# one frond: stipe from the bottom centre arching up, pinnae either side, tapering
	var base := Vector2(CELL * 0.5, CELL - PAD - 2)
	var tip := Vector2(CELL * 0.5 + 6, PAD + 8)
	var ctrl := Vector2(CELL * 0.5 - 20, CELL * 0.5)
	_curve(base, ctrl, tip, 3.4, 1.0, Color(0.17, 0.24, 0.12), Color(0.22, 0.34, 0.15), 12)
	var n := 21
	for k in n:
		var t := 0.1 + 0.9 * float(k) / n
		var p := _bez(base, ctrl, tip, t)
		var tan := (_bez(base, ctrl, tip, minf(t + 0.02, 1.0)) - p).normalized()
		var span := sin(PI * pow(t, 0.75)) * 170.0 + 12.0
		for side: float in [-1.0, 1.0]:
			var ang := atan2(tan.x, -tan.y) + side * 1.15
			var d := Vector2(sin(ang), -cos(ang))
			# pinna: a row of small lobes along a short rib
			var c := _jit(Color(0.20, 0.36, 0.16), 0.12)
			_stroke(p, p + d * span, 1.2, 0.5, c * 0.8)
			var m := int(span / 9.0)
			for j in m:
				var s := float(j) / maxf(m, 1)
				var q := p + d * span * s
				var ll := (1.0 - s * 0.7) * 10.0 + 2.5
				_leaf(q.x, q.y, ang - side * 0.9, ll, ll * 0.55, c * (0.9 + 0.2 * s), 0)
				_leaf(q.x, q.y, ang + side * 0.9 + PI * 0.0, ll * 0.8, ll * 0.45, c * 0.8, 0)


func _blades(n: int, col: Color, tip_col: Color, h: Vector2, w: Vector2, lean := 70.0) -> void:
	for k in n:
		var x := CELL * 0.5 + rng.randf_range(-CELL * 0.36, CELL * 0.36)
		var a := Vector2(x, CELL - PAD - 2)
		var edge := (x - CELL * 0.5) / (CELL * 0.36)
		var height := rng.randf_range(h.x, h.y) * CELL * (1.0 - 0.55 * edge * edge)
		var dx := rng.randf_range(-lean, lean) + (x - CELL * 0.5) * 0.45
		var b := Vector2(x + dx, CELL - PAD - 2 - height)
		var ctrl := Vector2(x + dx * 0.15, a.y - height * 0.65)
		var c := _jit(col, 0.2)
		_curve(a, ctrl, b, rng.randf_range(w.x, w.y), 0.5, c * 0.6, _jit(tip_col, 0.15), 10)


func _grass() -> void:
	_blades(150, Color(0.20, 0.32, 0.17), Color(0.40, 0.50, 0.30), Vector2(0.45, 0.95), Vector2(3.0, 5.5))
	# a few seed heads
	for k in 8:
		var x := rng.randf_range(CELL * 0.2, CELL * 0.8)
		var y := rng.randf_range(PAD + 10, CELL * 0.35)
		_curve(Vector2(x, CELL - PAD), Vector2(x + 10, y + 120), Vector2(x + 20, y), 1.4, 1.0, Color(0.3, 0.34, 0.22))
		for j in 9:
			_leaf(x + 20 + rng.randf_range(-3, 3), y + j * 5.0, rng.randf_range(-0.6, 0.6), 12, 3.5, Color(0.48, 0.45, 0.32), 0)


func _flowers() -> void:
	_blades(70, Color(0.20, 0.32, 0.17), Color(0.36, 0.46, 0.27), Vector2(0.3, 0.7), Vector2(2.5, 4.5))
	var cols := [Color(0.92, 0.9, 0.8), Color(0.95, 0.82, 0.35), Color(0.45, 0.55, 0.95), Color(0.85, 0.5, 0.7), Color(0.92, 0.9, 0.8)]
	for k in 16:
		var x := rng.randf_range(CELL * 0.15, CELL * 0.85)
		var top := Vector2(x + rng.randf_range(-30, 30), rng.randf_range(PAD + 30, CELL * 0.55))
		_curve(Vector2(x, CELL - PAD), Vector2(x, (top.y + CELL) * 0.5), top, 2.0, 1.4, Color(0.2, 0.3, 0.15))
		var c: Color = cols[k % cols.size()]
		var petals := 5 + rng.randi_range(0, 3)
		var r := rng.randf_range(11, 18)
		for j in petals:
			var ang := TAU * j / petals + rng.randf() * 0.3
			_leaf(top.x, top.y, ang, r, r * 0.5, _jit(c, 0.1), 0)
		_stroke(top, top + Vector2(0.1, 0), r * 0.28, r * 0.28, Color(0.9, 0.7, 0.2) if c.b < 0.8 else Color(0.95, 0.9, 0.6))


func _heather() -> void:
	# woody sprigs with dense tiny purple bells near the tips
	for k in 26:
		var x := CELL * 0.5 + rng.randf_range(-CELL * 0.38, CELL * 0.38)
		var a := Vector2(x, CELL - PAD - 2)
		var b := Vector2(x + rng.randf_range(-60, 60), rng.randf_range(PAD + 40, CELL * 0.55))
		var ctrl := a.lerp(b, 0.5) + Vector2(rng.randf_range(-25, 25), 0)
		_curve(a, ctrl, b, 2.4, 1.0, Color(0.22, 0.16, 0.12))
		for j in 40:
			var t := rng.randf_range(0.2, 1.0)
			var p := _bez(a, ctrl, b, t) + Vector2(rng.randf_range(-6, 6), 0)
			if t > 0.55:
				var c := _jit(Color(0.62, 0.32, 0.62), 0.2)
				_leaf(p.x, p.y, rng.randf_range(-2.0, 2.0), 9, 5, c, 0)
			else:
				_leaf(p.x, p.y, rng.randf_range(-1.2, 1.2), 8, 2.5, _jit(Color(0.18, 0.28, 0.15), 0.2), 2)


func _reeds() -> void:
	_blades(46, Color(0.24, 0.30, 0.16), Color(0.46, 0.46, 0.30), Vector2(0.65, 0.98), Vector2(3.5, 6.0), 40.0)


func _cattails() -> void:
	_blades(24, Color(0.24, 0.30, 0.16), Color(0.42, 0.44, 0.28), Vector2(0.5, 0.9), Vector2(4.0, 6.5), 40.0)
	for k in 6:
		var x := CELL * 0.5 + rng.randf_range(-150, 150)
		var top := Vector2(x + rng.randf_range(-15, 15), rng.randf_range(PAD + 20, CELL * 0.22))
		_stroke(Vector2(x, CELL - PAD), top, 2.4, 1.6, Color(0.28, 0.32, 0.18))
		var hb := top + Vector2(0, 30)
		_stroke(hb, hb + Vector2(0.5, 70), 9.0, 9.0, Color(0.30, 0.18, 0.10), Color(0.24, 0.14, 0.08))
		_stroke(top - Vector2(0, 18), hb, 1.2, 1.2, Color(0.4, 0.36, 0.26))


func _twigs() -> void:
	# bare forked twigs, for snags and winter crowns
	var stack: Array = [[Vector2(CELL * 0.5, CELL - PAD - 4), 0.0, 250.0, 7.5, 0]]
	while not stack.is_empty():
		var s: Array = stack.pop_back()
		var p: Vector2 = s[0]
		var ang: float = s[1]
		var length: float = s[2]
		var r: float = s[3]
		var depth: int = s[4]
		var tip := p + Vector2(sin(ang), -cos(ang)) * length
		var ctrl := p.lerp(tip, 0.5) + Vector2(rng.randf_range(-15, 15), rng.randf_range(-10, 10))
		_curve(p, ctrl, tip, r, r * 0.55, Color(0.2, 0.18, 0.17), Color(0.28, 0.26, 0.25))
		if depth < 4:
			for k in 2 + (1 if rng.randf() < 0.4 else 0):
				var t := rng.randf_range(0.45, 1.0)
				stack.append([_bez(p, ctrl, tip, t), ang + rng.randf_range(-0.9, 0.9), length * rng.randf_range(0.45, 0.7), r * 0.55, depth + 1])


func _litter() -> void:
	# fallen leaves seen from above, loose round heap with an alpha falloff
	var cols := [Color(0.30, 0.20, 0.12), Color(0.38, 0.27, 0.14), Color(0.22, 0.16, 0.11), Color(0.30, 0.30, 0.16)]
	for k in 260:
		var r := sqrt(rng.randf()) * CELL * 0.42
		var a := rng.randf() * TAU
		var p := Vector2(CELL * 0.5, CELL * 0.5) + Vector2(cos(a), sin(a)) * r
		var l := rng.randf_range(26, 44)
		_leaf(p.x, p.y, rng.randf() * TAU, l, l * 0.45, _jit(cols[k % cols.size()], 0.2) * (0.6 + 0.4 * float(k) / 260.0), 1 if k % 3 == 0 else 0)
	for k in 30:
		var a := Vector2(rng.randf_range(80, CELL - 80), rng.randf_range(80, CELL - 80))
		var b := a + Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60))
		_stroke(a, b, 2.0, 1.0, Color(0.2, 0.16, 0.12))


func _moss() -> void:
	# cushion of moss: many tiny star tufts in an irregular blob (top view)
	var blobs: Array = []
	for k in 6:
		blobs.append([Vector2(CELL * 0.5, CELL * 0.5) + Vector2(rng.randf_range(-110, 110), rng.randf_range(-110, 110)), rng.randf_range(70, 140)])
	for k in 3800:
		var b: Array = blobs[k % blobs.size()]
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * float(b[1])
		var p: Vector2 = (b[0] as Vector2) + Vector2(cos(a), sin(a)) * r
		var edge := r / float(b[1])
		var c := _jit(Color(0.20, 0.34, 0.14), 0.25) * (1.05 - 0.4 * edge)
		_leaf(p.x, p.y, rng.randf() * TAU, rng.randf_range(5, 10), 2.5, c, 2)


func _hang() -> void:
	# beard lichen / hanging moss strands from the top edge
	for s in 34:
		var x := rng.randf_range(30, CELL - 30)
		var top := Vector2(x, PAD + 2)
		var bot := Vector2(x + rng.randf_range(-25, 25), rng.randf_range(CELL * 0.35, CELL - PAD - 6))
		var ctrl := top.lerp(bot, 0.5) + Vector2(rng.randf_range(-20, 20), 0)
		var c := _jit(Color(0.36, 0.42, 0.32), 0.15)
		_curve(top, ctrl, bot, rng.randf_range(1.8, 3.2), 0.6, c * 0.8, c * 1.15, 10)
		for k in 10:
			var t := rng.randf_range(0.1, 0.9)
			var p := _bez(top, ctrl, bot, t)
			_stroke(p, p + Vector2(rng.randf_range(-14, 14), rng.randf_range(8, 24)), 1.2, 0.5, c)


## Push colour outward into transparent pixels so mipmaps and filtering never pull in black.
func _bleed() -> void:
	for it in 6:
		var src := px.duplicate()
		for y in range(1, SIZE - 1):
			for x in range(1, SIZE - 1):
				var i := (y * SIZE + x) * 4
				if src[i + 3] > 0.01:
					continue
				var acc := Vector3.ZERO
				var n := 0
				for o: int in [-4, 4, -SIZE * 4, SIZE * 4]:
					if src[i + o + 3] > 0.01 or (src[i + o] + src[i + o + 1] + src[i + o + 2]) > 0.0:
						acc += Vector3(src[i + o], src[i + o + 1], src[i + o + 2])
						n += 1
				if n > 0:
					acc /= n
					px[i] = acc.x
					px[i + 1] = acc.y
					px[i + 2] = acc.z


func _birch_bark() -> void:
	var w := 512
	var h := 1024
	var tone := _seamless(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.01, 3, 4, w, h)
	var lent := _seamless(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03, 7, 3, w / 8, h)    # stretched wide later
	lent.resize(w, h, Image.INTERPOLATE_CUBIC)
	var patch := _seamless(FastNoiseLite.TYPE_CELLULAR, 0.012, 9, 1, w, h)
	var grain := _seamless(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.08, 13, 3, w, h / 4)
	grain.resize(w, h, Image.INTERPOLATE_CUBIC)
	var hgt := PackedFloat32Array()
	hgt.resize(w * h)
	var alb := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var t := tone.get_pixel(x, y).r
			# lenticels: thin horizontal dark dashes
			var l := lent.get_pixel(x, y).r
			var dash := 1.0 - _sstep(0.0, 0.05, absf(l - 0.5))
			dash *= _sstep(0.45, 0.65, grain.get_pixel(x, y).r)
			var dark := _sstep(0.72, 0.9, patch.get_pixel(x, y).r) * _sstep(0.55, 0.7, t)
			var g := grain.get_pixel(x, y).r
			var lum := 0.78 + (t - 0.5) * 0.2 + (g - 0.5) * 0.08
			var col := Color(lum * 0.97, lum * 0.95, lum * 0.92)
			col = col.lerp(Color(0.08, 0.07, 0.07), clampf(dash * 0.9 + dark * 0.85, 0, 1))
			col = col.lerp(Color(0.62, 0.55, 0.45), _sstep(0.6, 0.8, t) * 0.25)
			alb.set_pixel(x, y, col)
			hgt[y * w + x] = 0.5 + (g - 0.5) * 0.3 - dash * 0.5 - dark * 0.3
	var nrm := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var dx := (hgt[y * w + (x + 1) % w] - hgt[y * w + (x - 1 + w) % w]) * 2.5
			var dy := (hgt[((y + 1) % h) * w + x] - hgt[((y - 1 + h) % h) * w + x]) * 2.5
			var n := Vector3(-dx, dy, 1.0).normalized() * 0.5 + Vector3(0.5, 0.5, 0.5)
			nrm.set_pixel(x, y, Color(n.x, n.y, n.z))
	alb.save_png("res://art/textures/realm_birch_bark_albedo.png")
	nrm.save_png("res://art/textures/realm_birch_bark_normal.png")


func _seamless(type: int, freq: float, seed_v: int, oct: int, w: int, h: int) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.seed = seed_v
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if oct > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = oct
	var img := n.get_seamless_image(w, h, false, false, 0.2, true)
	img.convert(Image.FORMAT_RF)
	return img


func _sstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
