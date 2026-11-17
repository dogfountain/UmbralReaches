extends RefCounted
## THE HOLLOW KING (the world pass): a dead oak 44 m tall in the Southwood, older than the Order, taller than anything the
## wood has grown since, its crown a black antler against the stars and a fire burning in the fork.
## Lore: the charcoal burners' camps stand round it because they believe nothing that cuts it down lives. It died
## standing. The root-folk (nobody knows who) took the hollow for a hall, hung lamps in its limbs and built their
## houses into its roots.
##   - the trunk: a 12-sided shaft 16 m round at the root tapering to 8 m at the fork, bark in flat facets; a doorway
##     in the south face opens on the hollow (a round hall inside, a fire, a chest, seats of root)
##   - the roots: eight buttresses running out and down; the houses stand between them (four, each walk-in: planked
##     walls, a pitched roof, a door, lit windows, a lamp; one holds a chest)
##   - the stair: 30 short flights wind round the trunk from the door to a deck in the fork (railed, 30 m up);
##     the deck is ringed with a rail, carries a cresset fire and a chest, and looks over the whole Southwood
##   - the crown: nine limbs, forked and drooping, hung with lanterns (lit glass on iron wire)
## One site (WK.find_any in the Southwood), levelled by a terrace so the houses stand flat; every piece is the kit's
## (one mesh per material, collision from the faces); about 1.4k boxes' worth of triangles, built once.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

const CANDS := [Vector2(170.0, 340.0), Vector2(130.0, 352.0), Vector2(214.0, 350.0), Vector2(150.0, 298.0), Vector2(236.0, 316.0)]
const RAD := 26.0
const DOOR := 0.0                       ## the doorway's bearing (+x)
## the trunk's profile: [height, radius]
const PROFILE := [[0.0, 8.2], [3.0, 7.0], [10.0, 5.9], [20.0, 5.1], [30.0, 4.5], [38.0, 4.0], [44.0, 3.2]]

var k
var c := Vector2.ZERO
var gy := 0.0


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _r(y: float) -> float:
	for i in PROFILE.size() - 1:
		var a: Array = PROFILE[i]
		var b: Array = PROFILE[i + 1]
		if y <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (y - float(a[0])) / (float(b[0]) - float(a[0])))
	return 3.2


func _p(ang: float, rad: float, y: float) -> Vector3:
	return Vector3(c.x + cos(ang) * rad, gy + y, c.y + sin(ang) * rad)


func _run(root: Node) -> void:
	var f := WK.find_any(CANDS, Vector2(RAD, RAD), [0.0], ["southwood"], 5.0)
	if f.is_empty():
		push_warning("WONDER hollow_king: no room in the Southwood")
		return
	c = f.pos
	gy = lerpf(float(f.lo), float(f.hi), 0.5)
	WorldLanes.register_terrace("wonder_hollow_king", c, RAD, gy)
	k = WK.new()
	k.setup(root, "HollowKing", 4417)
	k.poi("hollow_king", "The Hollow King", "it died standing, and something lit it", "southwood")
	_trunk()
	_roots()
	_houses()
	_stair()
	_crown()
	_dress()
	var n := k.commit()
	k.beacon(_p(0.0, 0.0, 42.0), Color(1.0, 0.7, 0.4), 1.6, 12.0, 400.0)
	print("WONDER hollow_king at %s ground %.1f: %d meshes, %d fires, %d lights, %d chests" % [c, gy, n, k.fires, k.lights, k.chests])


# --- the trunk and the hollow ---------------------------------------------------------------------------

func _trunk() -> void:
	var door := atan2(-cos(DOOR), -sin(DOOR))
	var gap := Vector2(door - 0.2, door + 0.2)
	var ys := [-3.0, 0.0, 3.0, 5.4, 10.0, 20.0, 30.0, 38.0, 44.0]
	for i in ys.size() - 1:
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		var r0 := _r(maxf(y0, 0.0))
		var r1 := _r(y1)
		var low := y1 <= 5.4
		k.tube("bark", _p(0.0, 0.0, y0), _p(0.0, 0.0, y1), r0, r1, 12, not low, 0.85 + 0.1 * float(i % 3), gap if low and y0 >= 0.0 else Vector2(1.0, -1.0), i == ys.size() - 2, -PI / 12.0)
	# the hollow: an inner shell, a floor, a ceiling; the doorway's frame
	k.tube("bark", _p(0.0, 0.0, 0.0), _p(0.0, 0.0, 5.4), 6.1, 5.6, 12, true, 0.55, gap, false, -PI / 12.0, true)
	k.disc("wood_big", _p(0.0, 0.0, 0.3), 6.2, 12, true, true, 0.8)
	k.disc("bark", _p(0.0, 0.0, 5.4), 5.6, 12, false, true, 0.5)
	for s: float in [-1.0, 1.0]:
		var ja := DOOR + s * 0.27
		k.beam("wood_big", _p(ja, 7.3, 0.2), _p(ja, 7.3, 5.4), 0.9, 0.9, true, 0.9)
	k.beam("wood_big", _p(DOOR - 0.27, 7.3, 5.4), _p(DOOR + 0.27, 7.3, 5.4), 1.0, 1.0, true, 0.9)
	# inside: seats of root, a fire, the chest, lamps
	for i in 5:
		var a := 1.1 + 0.85 * float(i)
		if absf(wrapf(a - DOOR, -PI, PI)) < 0.8:
			continue
		var sp := _p(a, 4.6, 0.3)
		k.kit.box("bark", sp + Vector3.UP * 0.4, Vector3(1.6, 0.8, 1.1), Basis(Vector3.UP, -a), true, 0.9)
	k.fire(_p(0.0, 0.0, 0.5), 1.0, 2.2)
	k.kit.box("dark", _p(0.0, 0.0, 0.5) + Vector3.DOWN * 0.1, Vector3(1.8, 0.4, 1.8), Basis.IDENTITY, false, 0.5)
	k.lamp(_p(0.0, 0.0, 3.8), Color(1.0, 0.66, 0.36), 1.6, 9.0)
	k.chest("hollow_king_root", "reliquary", _p(2.0 + PI, 4.0, 0.3), -PI * 0.5, {"grave_ash": 20, "grave_iron": 3, "relic_fragment": 2})


# --- roots and houses -----------------------------------------------------------------------------------

func _roots() -> void:
	for i in 8:
		var a := float(i) * PI * 0.25 + PI * 0.125
		var rr := 1.0 + 0.12 * sin(float(i) * 2.3)
		var pts := [_p(a, 6.4, 9.0), _p(a, 8.6 * rr, 3.2), _p(a, 11.0 * rr, 1.0), _p(a, 16.5 * rr, -0.5)]
		var rad := [2.6, 1.9, 1.3, 0.6]
		for j in 3:
			k.tube("bark", pts[j] as Vector3, pts[j + 1] as Vector3, float(rad[j]), float(rad[j + 1]), 6, j == 0, 0.8 + 0.1 * float(j))
		# a thinner root creeping on along the ground
		k.tube("bark", pts[3] as Vector3, _p(a + 0.25, 22.0, -0.8), 0.6, 0.15, 5, false, 0.75)


## Four walk-in houses between the roots: a planked box 5 x 4.2 and 2.6 high, a pitched roof, a doorway on the
## side away from the trunk, a lit window each side, a lamp; a lantern hung over the door.
func _houses() -> void:
	var angs := [PI * 0.5, PI, PI * 1.25, PI * 1.75]
	for i in 4:
		var a: float = float(angs[i])
		var cen := _p(a, 15.0 + float(i % 2) * 2.0, 0.0)
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := out.cross(Vector3.UP)
		var b := Basis(side, Vector3.UP, out)
		var hw := 2.5
		var hd := 2.1
		var wh := 2.7
		# floor, back wall (toward the trunk), side walls, the front wall with a door gap
		k.kit.box("wood_big", cen + Vector3.UP * 0.1, Vector3(hw * 2.0 + 0.6, 0.5, hd * 2.0 + 0.6), b, true, 0.85)
		k.kit.box("wood_big", cen - out * hd + Vector3.UP * (wh * 0.5 + 0.3), Vector3(hw * 2.0, wh, 0.3), b, true, 0.95)
		for s: float in [-1.0, 1.0]:
			k.kit.box("wood_big", cen + side * (s * hw) + Vector3.UP * (wh * 0.5 + 0.3), Vector3(0.3, wh, hd * 2.0), b, true, 0.95)
			k.kit.box("wood_big", cen + out * hd + side * (s * (hw * 0.5 + 0.45)) + Vector3.UP * (wh * 0.5 + 0.3), Vector3(hw - 0.9, wh, 0.3), b, true, 0.95)
			k.window(cen + side * (s * (hw + 0.17)) + Vector3.UP * 1.1, out, side * s, 1.0, 1.0)
		k.kit.box("wood_big", cen + out * hd + Vector3.UP * (wh + 0.05), Vector3(1.8, 0.6, 0.35), b, true, 0.9)
		# the roof: two planes meeting over the ridge, and gable plates
		for s: float in [-1.0, 1.0]:
			var tilt := Basis(out, s * 0.62) * b
			k.kit.box("slate", cen + side * (s * hw * 0.5) + Vector3.UP * (wh + 0.9), Vector3(hw * 1.25, 0.22, hd * 2.0 + 0.8), tilt, true, 0.85)
		k.kit.box("wood_big", cen + Vector3.UP * (wh + 1.4), Vector3(0.3, 0.3, hd * 2.0 + 0.9), b, false, 0.8)
		var lit := cen + Vector3.UP * 1.7
		k.lamp(lit, Color(1.0, 0.68, 0.38), 1.3, 8.0)
		k.kit.box("glow", cen + out * (hd + 0.45) + Vector3.UP * (wh + 0.1) + side * 1.1, Vector3(0.22, 0.34, 0.22), b, false, 1.0)
		k.kit.box("iron", cen + out * (hd + 0.45) + Vector3.UP * (wh + 0.3) + side * 1.1, Vector3(0.04, 0.4, 0.04), b, false, 0.7)
		if i == 1:
			k.chest("hollow_king_house", "wood", cen + Vector3.UP * 0.4 - out * (hd - 0.9) + side * 1.2, a, {"grave_ash": 9, "grave_iron": 1})
		# a path of flat stones from the door to the trunk's door side
		for j in 3:
			k.kit.box("floor", cen + out * (hd + 1.2 + 1.3 * float(j)) + Vector3.UP * -0.05, Vector3(1.4, 0.2, 1.1), Basis(Vector3.UP, a + 0.3 * float(j)), false, 0.85)


# --- the stair ------------------------------------------------------------------------------------------

func _stair() -> void:
	var th0 := PI * 0.25
	var y := 0.3
	var flights := 28
	var dth := PI / 6.0
	for i in flights:
		var a0 := th0 + dth * float(i)
		var a1 := a0 + dth
		var y1 := y + 1.08
		var ra := _r(y) + 2.3
		var rb := _r(y1) + 2.3
		var p0 := _p(a0, ra, y)
		var p1 := _p(a1, rb, y1)
		k.kit.stairs("wood_big", p0, p1, 2.4, 3, p0.y - 0.9)
		# rail on the outer edge, with a post at the joint
		var dir := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z).normalized()
		var side := dir.cross(Vector3.UP)
		var oo := Vector3(cos(a0), 0.0, sin(a0))
		var out_s := side if side.dot(oo) > 0.0 else -side
		k.beam("wood_big", p0 + out_s * 1.25 + Vector3.UP * 1.0, p1 + out_s * 1.25 + Vector3.UP * 1.0, 0.12, 0.12, true, 0.85)
		k.kit.box("wood_big", p1 + out_s * 1.25 + Vector3.UP * 0.55, Vector3(0.16, 1.1, 0.16), Basis.IDENTITY, false, 0.8)
		if i % 4 == 3:
			k.lamp(p1 + out_s * 1.4 + Vector3.UP * 1.4, Color(1.0, 0.66, 0.34), 0.9, 6.5)
			k.kit.box("glow", p1 + out_s * 1.4 + Vector3.UP * 1.25, Vector3(0.24, 0.32, 0.24), Basis.IDENTITY, false, 1.0)
		y = y1
	# the deck in the fork: a 12-gon ring of boards round the trunk at the stair's last height, railed
	var dy := y
	var rd := _r(dy)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var deg := fposmod(rad_to_deg(a), 360.0)
		if deg > 100.0 and deg < 160.0:
			continue                              # the stair arrives here: the boards start where it ends
		var mid := _p(a, rd + 1.5, dy - 0.15)
		var bs := Basis(Vector3.UP, -a - PI * 0.5)
		k.kit.box("wood_big", mid, Vector3(5.6, 0.3, 3.4), bs, true, 0.92)
		var rim := _p(a, rd + 3.3, dy + 0.5)
		k.kit.box("wood_big", rim, Vector3(3.0, 0.14, 0.14), bs, false, 0.8)
		k.kit.box("wood_big", rim + Vector3.DOWN * 0.25, Vector3(0.16, 1.0, 0.16), Basis.IDENTITY, false, 0.8)
	var cx := _p(PI * 0.5, rd + 1.5, dy)
	k.kit.box("iron", cx + Vector3.UP * 0.35, Vector3(1.8, 0.7, 1.8), Basis.IDENTITY, true, 0.7)
	k.fire(cx + Vector3.UP * 0.8, 2.4, 3.6)
	k.chest("hollow_king_crown", "reliquary", _p(PI * 1.5, rd + 1.5, dy + 0.15), -PI * 0.5, {"grave_ash": 26, "grave_iron": 4, "relic_fragment": 3})


# --- the crown ------------------------------------------------------------------------------------------

func _crown() -> void:
	var top := _p(0.0, 0.0, 44.0)
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.3
		var h0 := 30.0 + 5.0 * float(i % 3)
		var r0 := _r(h0)
		var s0 := _p(a, r0 * 0.7, h0)
		var m1 := _p(a, r0 + 7.0, h0 + 7.0 + 2.0 * float(i % 2))
		var m2 := _p(a + 0.15, r0 + 15.0 + 3.0 * float(i % 3), h0 + 12.0 + 3.0 * float(i % 2))
		var m3 := _p(a + 0.3, r0 + 21.0, h0 + 8.0 + 4.0 * float(i % 3))
		k.tube("bark", s0, m1, 1.5, 1.0, 6, false, 0.8)
		k.tube("bark", m1, m2, 1.0, 0.55, 6, false, 0.85)
		k.tube("bark", m2, m3, 0.55, 0.12, 5, false, 0.9)
		var fk := m1 + (m2 - m1) * 0.5
		k.tube("bark", fk, fk + Vector3(cos(a - 0.7), 0.5, sin(a - 0.7)) * 6.0, 0.5, 0.1, 5, false, 0.85)
		# lanterns hung from the limbs on wire: lit glass, a light each third
		var hang := m2 + (m3 - m2) * 0.4
		k.kit.box("iron", hang + Vector3.DOWN * 1.1, Vector3(0.03, 2.2, 0.03), Basis.IDENTITY, false, 0.6)
		k.kit.box("glow", hang + Vector3.DOWN * 2.35, Vector3(0.34, 0.46, 0.34), Basis(Vector3.UP, a), false, 1.0)
		if i % 3 == 0:
			k.lamp(hang + Vector3.DOWN * 2.3, Color(1.0, 0.66, 0.36), 1.2, 9.0)
	k.tube("bark", _p(0.0, 0.0, 40.0), top + Vector3.UP * 5.0, 2.6, 0.3, 8, false, 0.85)


# --- secondary forms -----------------------------------------------------------------------------------

func _dress() -> void:
	Dress.camp(k, _p(-0.5, 11.0, 0.0), 0.4)
	Dress.rubble(k, _p(PI * 1.5, 11.0, 0.0), 5.0, 14, "bark")
	Dress.rubble(k, _p(PI * 0.7, 12.0, 0.0), 4.0, 10, "bark")
	for i in 4:
		var a := [PI * 0.5, PI, PI * 1.25, PI * 1.75][i] as float
		var cen := _p(a, 15.0 + float(i % 2) * 2.0, 0.0)
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := out.cross(Vector3.UP)
		Dress.barrel(k, cen + out * 3.6 + side * 2.2, a, 1.0)
		Dress.crate(k, cen + out * 3.8 - side * 2.0, a + 0.4, 0.8)
		Dress.rope(k, cen + out * 2.0 + Vector3.UP * 3.3 + side * 2.0, cen + out * 2.0 + Vector3.UP * 3.3 - side * 2.0, 0.5)
		Dress.strands(k, cen - out * 2.1 + Vector3.UP * 3.6 - side * 2.4, cen - out * 2.1 + Vector3.UP * 3.6 + side * 2.4, 6, 1.6)
	# ropes from the stair's lamps to the root houses, and strands under the crown deck and the limbs
	for i in 12:
		var a := TAU * float(i) / 12.0
		if fposmod(rad_to_deg(a), 360.0) > 100.0 and fposmod(rad_to_deg(a), 360.0) < 160.0:
			continue
		Dress.strands(k, _p(a - 0.15, 7.6, 30.2), _p(a + 0.15, 7.6, 30.2), 3, 3.2)
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.3
		Dress.strands(k, _p(a, 15.0, 36.0), _p(a + 0.15, 20.0, 40.0), 6, 4.5)
	for i in 6:
		var a := float(i) * 1.05
		Dress.crack(k, _p(a, 7.1, 6.0 + 3.0 * float(i)), _p(a + 0.12, 7.2, 12.0 + 3.0 * float(i)), 0.13)
	for i in 5:
		var a := 0.8 + float(i) * 1.1
		for j in 3:
			var p := _p(a, 7.0 - 0.3 * float(j), 4.0 + 5.0 * float(j) + float(i))
			k.kit.box("chalk", p, Vector3(1.0 - 0.15 * float(j), 0.14, 0.7), Basis(Vector3.UP, -a), false, 0.85)      # bracket fungus on the trunk
