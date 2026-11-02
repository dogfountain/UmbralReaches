class_name Ossuary
extends Area
## Ossuary Terrace (docs/ZONE_PLAN.md §2.1): a candlelit burial monastery stepping down the
## east chasm wall, facing the stair. No terrain is cut: every floor sits above the baked
## heightfield, and each tier hangs on masonry piers that run down into the lava.
##
##   landing (y 12.6) ─ bone bridge (5 m broken span) ─ GATE HALL (y 12.6, brazier)
##     └ north stair ─ NICHE GALLERY (y 8.4, two aisles, skull niches)
##         └ north stair ─ CHARNEL PIT (y 4.2, round, cantilevered) ─ chain lift ↑ summit
##             └ CHAPEL (y 4.2): Bone Reliquary

const HALL_Y := 12.6
const GAL_Y := 8.4
const PIT_Y := 4.2
const PIT_C := Vector3(16.0, PIT_Y, -86.0)
const PIT_R := 8.0
const LAVA_Y := -16.5
const SUMMIT := Vector3(0.0, 24.5, -83.5)

var _rng := RandomNumberGenerator.new()
var _draws := 0
const BOUNDS := AABB(Vector3(2.0, -6.0, -106.0), Vector3(30.0, 32.0, 84.0))


func _init() -> void:
	title = "OSSUARY TERRACE"
	subtitle = "where the faithful wait in rows"


func build() -> void:
	_rng.seed = 3117
	var t0 := Time.get_ticks_usec()
	var k := OssKit.new()
	_bridge(k)
	_gate_hall(k)
	_stair_down(k, Vector3(23.0, GAL_Y, -49.0), Vector3(23.0, HALL_Y, -38.0))
	k.block("floor", Vector3(21.0, GAL_Y - 0.6, -51.2), Vector3(25.0, GAL_Y, -49.0))
	_gallery(k)
	_stair_down(k, Vector3(21.0, PIT_Y, -78.0), Vector3(21.0, GAL_Y, -67.0))
	_pit(k)
	_chapel(k)
	# the lift stops level with the summit's plinth ring; this landing bridges the lower rim
	k.block("stone", Vector3(8.6, 25.0, -84.7), Vector3(10.15, 26.56, -82.3))
	k.candle_cluster(Vector3(9.0, 26.56, -84.5), 4, 0.15, _rng)
	_draws = k.commit(self)
	_lights()
	_lift()
	_reliquary()
	_spawns()
	perf_points = [
		{"name": "ossuary_bridge", "at": Vector3(1.5, HALL_Y + 0.1, -34.0), "yaw": -PI * 0.5},
		{"name": "ossuary_gallery", "at": Vector3(22.0, GAL_Y + 0.1, -52.5), "yaw": 0.0},
		{"name": "ossuary_pit", "at": Vector3(20.5, PIT_Y + 0.1, -79.5), "yaw": 0.5},
	]
	print("OSSUARY build %.1f ms draws=%d col_tris=%d candles=%d skulls=%d" % [
		(Time.get_ticks_usec() - t0) * 0.001, _draws, k.col_faces.size() / 3, k.candles.size(), k.skulls.size()])


func _physics_process(_d: float) -> void:
	announce_if_inside(get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D, BOUNDS)


# --- pieces ---------------------------------------------------------------------------------

## A masonry pier from the lava up to `top`, with a stepped plinth and a corbel cap.
func _pier(k: OssKit, x: float, z: float, top: float, w := 1.6) -> void:
	var mid_y := lerpf(LAVA_Y, top, 0.45)
	var wl := w * 1.3
	k.block("stone", Vector3(x - wl * 0.5, LAVA_Y, z - wl * 0.5), Vector3(x + wl * 0.5, mid_y, z + wl * 0.5))
	k.block("stone", Vector3(x - w * 0.5, mid_y, z - w * 0.5), Vector3(x + w * 0.5, top - 0.6, z + w * 0.5))
	# set-off where the pier narrows, string courses every ~4 m, corbel cap
	k.box("stone", Vector3(x, mid_y + 0.1, z), Vector3(wl + 0.1, 0.35, wl + 0.1), Basis.IDENTITY, true, 0.8)
	var y := mid_y + 4.0
	while y < top - 2.0:
		k.box("stone", Vector3(x, y, z), Vector3(w + 0.22, 0.22, w + 0.22), Basis.IDENTITY, false, 0.78)
		y += 4.0
	k.block("stone", Vector3(x - w * 0.7, top - 0.9, z - w * 0.7), Vector3(x + w * 0.7, top - 0.4, z + w * 0.7), true, 0.85)


## Relieving arches between piers along a substructure face (x = const), under a floor at `fy`.
func _undercroft(k: OssKit, x: float, zs: Array, fy: float, pier_w: float) -> void:
	for i in zs.size() - 1:
		var za: float = zs[i]
		var zb: float = zs[i + 1]
		var w := absf(zb - za) - pier_w
		var base := Vector3(x, fy - 0.6 - 7.5, (za + zb) * 0.5)
		k.arch_panel("stone", base, Vector3.FORWARD, w, 4.0, 7.5 - 0.6, 1.0, 0.0, 0.62, 0.0, "stone")


## Wall along a->b (horizontal), `h` tall, `t` thick, with pointed openings punched at the given
## distances along it: [{at: m from a, w, spring, sill, niche: bool}]. Niches get a dark back
## plate `depth` behind the face (toward `inward`) instead of a through-hole.
func _wall(k: OssKit, key: String, a: Vector3, b: Vector3, h: float, t: float, openings: Array, inward := Vector3.ZERO, ring := "stone") -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := d.length()
	var along := d / length
	var nrm := along.cross(Vector3.UP).normalized()
	var bas := Basis(along, Vector3.UP, nrm)
	var cursor := 0.0
	var ops := openings.duplicate()
	ops.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.at) < float(q.at))
	for o in ops:
		var w: float = o.w
		var x0: float = float(o.at) - w * 0.5
		if x0 > cursor + 0.01:
			var mid := a + along * ((cursor + x0) * 0.5) + Vector3.UP * (h * 0.5)
			k.box(key, mid, Vector3(x0 - cursor, h, t), bas)
		var base := a + along * float(o.at)
		var niche: bool = o.get("niche", false)
		k.arch_panel(key, base, along, w, float(o.spring), h, t, 0.0, float(o.get("k", 0.85)), float(o.get("sill", 0.0)), ring)
		if o.get("glow", false):
			k.glow_pane(base, along, w, float(o.get("sill", 0.0)), float(o.spring), float(o.get("k", 0.85)))
		if niche:
			var back := base + inward * (t * 0.5 + 0.35)
			var top_n: float = float(o.spring) + w * 1.3
			k.box("dark", back + Vector3.UP * (top_n * 0.5), Vector3(w + 0.2, top_n, 0.15), bas)
			# shelf + contents
			var sill: float = o.get("sill", 0.0)
			var shelf := base + inward * 0.2 + Vector3.UP * sill
			for s: float in [-0.25, 0.25]:
				if _rng.randf() < 0.85:
					k.skull(shelf + along * s * w + Vector3.UP * 0.02, atan2(inward.x, inward.z) + PI + _rng.randf_range(-0.4, 0.4), _rng.randf_range(0.9, 1.15))
			if _rng.randf() < 0.6:
				k.candle_cluster(shelf + inward * 0.1, _rng.randi_range(2, 5), 0.18, _rng)
			for j in _rng.randi_range(1, 3):
				k.bone(shelf + along * _rng.randf_range(-0.3, 0.3) * w + Vector3.UP * 0.03, Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.0))
		cursor = float(o.at) + w * 0.5
	if cursor < length - 0.01:
		var mid := a + along * ((cursor + length) * 0.5) + Vector3.UP * (h * 0.5)
		k.box(key, mid, Vector3(length - cursor, h, t), bas)


func _gable_roof(k: OssKit, lo: Vector3, hi: Vector3, eave: float, ridge: float, along_x: bool) -> void:
	# lo/hi: footprint corners (x,z); roof ridge runs along x if along_x else along z
	var over := 0.6
	var x0 := lo.x - over
	var x1 := hi.x + over
	var z0 := lo.z - over
	var z1 := hi.z + over
	var th := 0.35
	if along_x:
		var zm := (z0 + z1) * 0.5
		for side: float in [-1.0, 1.0]:
			var ze: float = z0 if side < 0.0 else z1
			var out := Vector3(0, ridge - eave, ze - zm).cross(Vector3.RIGHT).normalized()
			if out.y < 0.0:
				out = -out
			k.quad("slate", Vector3(x0, eave, ze), Vector3(x1, eave, ze), Vector3(x1, ridge, zm), Vector3(x0, ridge, zm), out)
			k.quad("slate", Vector3(x0, eave - th, ze), Vector3(x1, eave - th, ze), Vector3(x1, ridge - th, zm), Vector3(x0, ridge - th, zm), -out)
		# gable ends
		for xe: float in [x0 + over, x1 - over]:
			var n := Vector3.LEFT if xe < (x0 + x1) * 0.5 else Vector3.RIGHT
			k.quad("plaster", Vector3(xe, eave, z0 + over), Vector3(xe, eave, z1 - over), Vector3(xe, ridge - 0.2, zm), Vector3(xe, ridge - 0.2, zm), n)
	else:
		var xm := (x0 + x1) * 0.5
		for side: float in [-1.0, 1.0]:
			var xe: float = x0 if side < 0.0 else x1
			var out := Vector3(xe - xm, ridge - eave, 0).cross(Vector3.FORWARD).normalized()
			if out.y < 0.0:
				out = -out
			k.quad("slate", Vector3(xe, eave, z0), Vector3(xe, eave, z1), Vector3(xm, ridge, z1), Vector3(xm, ridge, z0), out)
			k.quad("slate", Vector3(xe, eave - th, z0), Vector3(xe, eave - th, z1), Vector3(xm, ridge - th, z1), Vector3(xm, ridge - th, z0), -out)
		for ze: float in [z0 + over, z1 - over]:
			var n := Vector3.FORWARD if ze < (z0 + z1) * 0.5 else Vector3.BACK
			k.quad("plaster", Vector3(x0 + over, eave, ze), Vector3(x1 - over, eave, ze), Vector3(xm, ridge - 0.2, ze), Vector3(xm, ridge - 0.2, ze), n)


func _stair_down(k: OssKit, lo: Vector3, hi: Vector3) -> void:
	k.stairs("floor", lo, hi, 3.2, 10)
	var dir := Vector3(hi.x - lo.x, 0.0, hi.z - lo.z).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var f := (hi - lo).normalized()
	for s: float in [-1.0, 1.0]:
		var o: Vector3 = side * (s * 1.85)
		# sloped parapet: one long box tilted with the flight
		var u := side.cross(f).normalized()
		if u.y < 0.0:
			u = -u
		k.box("stone", (lo + hi) * 0.5 + o + u * 0.55, Vector3(0.4, 1.1, (hi - lo).length() + 0.4), Basis(side, u, f))
	# a pier under the middle of the flight and one at the foot
	var mid := (lo + hi) * 0.5
	_pier(k, mid.x, mid.z, mid.y - 0.3, 2.4)
	_pier(k, lo.x, lo.z - dir.z * 0.6, lo.y, 2.6)
	for i in 4:
		k.candle_cluster(lo.lerp(hi, 0.15 + 0.23 * float(i)) + side * 1.55 + Vector3.UP * (1.1 + 0.05), 3, 0.08, _rng)


# --- bridge -------------------------------------------------------------------------------

func _bridge(k: OssKit) -> void:
	var z := -34.0
	var y := HALL_Y
	for seg in [[2.5, 8.0], [13.0, 18.0]]:
		var x0: float = seg[0]
		var x1: float = seg[1]
		k.block("bone", Vector3(x0, y - 0.55, z - 1.5), Vector3(x1, y, z + 1.5), true, 0.9)
		# vertebral keel under the deck and rib railings
		var n := int((x1 - x0) / 0.9)
		for i in n + 1:
			var x := x0 + (x1 - x0) * float(i) / float(maxi(n, 1))
			k.box("bone", Vector3(x, y - 0.9, z), Vector3(0.55, 0.6, 0.9), Basis.IDENTITY, false, 0.8)
			for s: float in [-1.0, 1.0]:
				_rib(k, Vector3(x, y, z + s * 1.45), s)
		# broken end: ragged slabs and a snapped rib hanging over the gap
		var broken: float = x1 if x0 < 5.0 else x0
		var out := 1.0 if x0 < 5.0 else -1.0
		for j in 3:
			var off := Vector3(out * (0.3 + 0.35 * float(j)), -0.25 - 0.3 * float(j), _rng.randf_range(-1.0, 1.0))
			k.box("bone", Vector3(broken, y - 0.3, z) + off, Vector3(0.7, 0.3, 0.9), Basis(Vector3.FORWARD, out * (0.3 + 0.25 * float(j))), false, 0.85)
	# the great ribs that used to carry the missing span, snapped off well below the deck
	# (low enough that they are scenery, not stepping stones: the gap is the Rift Step test)
	var rib_top := y - 6.0
	for s: float in [-1.0, 1.0]:
		var base := Vector3(10.5, LAVA_Y, z + s * 1.2)
		var seg := (rib_top - LAVA_Y) / 9.0
		for i in 9:
			var t := float(i) / 8.0
			var p := base + Vector3(0.0, seg * (float(i) + 0.5), 0.0)
			k.box("bone", p, Vector3(0.9 - t * 0.4, seg + 0.05, 0.9 - t * 0.4), Basis(Vector3.FORWARD, sin(t * 3.0) * 0.12), true, 0.75 + 0.2 * t)
	# piers under each deck segment
	for x: float in [5.0, 15.5]:
		_pier(k, x, z, y - 0.55, 1.8)
	# candles on the rail posts
	for x: float in [3.5, 6.5, 14.0, 17.0]:
		for s: float in [-1.0, 1.0]:
			k.candle_cluster(Vector3(x, y + 1.1, z + s * 1.45), 2, 0.05, _rng)


## One curved rib post on the bridge rail (bone, swept outward then in).
func _rib(k: OssKit, at: Vector3, side: float) -> void:
	var prev := at
	for i in 4:
		var t := float(i + 1) / 4.0
		var p := at + Vector3(0.0, t * 1.15, side * sin(t * PI) * 0.22)
		var mid := (prev + p) * 0.5
		var d := p - prev
		var up := d.normalized()
		var x := Vector3.RIGHT
		k.box("bone", mid, Vector3(0.16 - t * 0.04, d.length() + 0.04, 0.16 - t * 0.04), Basis(x, up, x.cross(up)).orthonormalized(), i < 2)
		prev = p
	k.skull(prev + Vector3.UP * 0.02, side * PI * 0.5 + PI * 0.5, 0.9)


# --- gate hall ------------------------------------------------------------------------------

func _gate_hall(k: OssKit) -> void:
	var x0 := 18.0
	var x1 := 30.0
	var z0 := -38.0
	var z1 := -24.0
	var y := HALL_Y
	var h := 7.0
	var t := 0.8
	k.block("floor", Vector3(x0, y - 0.6, z0), Vector3(x1, y, z1))
	# substructure: corner + mid piers into the lava, a corbel band under the floor
	for p: Vector2 in [Vector2(x0, z0), Vector2(x0, z1), Vector2(x0, -31.0), Vector2(24.0, z0), Vector2(24.0, z1)]:
		_pier(k, p.x, p.y, y - 0.6, 2.2)
	k.block("stone", Vector3(x0 - 0.3, y - 1.4, z0 - 0.3), Vector3(x1, y - 0.6, z1 + 0.3), true, 0.8)
	# walls (outer faces): west faces the stair, so it carries the door and two tall lancets
	var at_y := Vector3(0, y, 0)
	_wall(k, "plaster", Vector3(x0, y, z1), Vector3(x0, y, z0), h, t, [
		{"at": 4.0, "w": 2.0, "spring": 3.0, "sill": 1.6, "k": 1.1, "glow": true},
		{"at": 10.0, "w": 3.0, "spring": 3.2},
	])
	_wall(k, "plaster", Vector3(x0, y, z0), Vector3(x1, y, z0), h, t, [
		{"at": 5.0, "w": 3.0, "spring": 3.2},
		{"at": 9.5, "w": 1.6, "spring": 3.4, "sill": 1.8, "k": 1.1, "glow": true},
	])
	_wall(k, "plaster", Vector3(x1, y, z1), Vector3(x0, y, z1), h, t, [
		{"at": 3.5, "w": 1.8, "spring": 3.0, "sill": 1.6, "k": 1.1, "glow": true},
		{"at": 8.5, "w": 1.8, "spring": 3.0, "sill": 1.6, "k": 1.1, "glow": true},
	])
	var niches: Array = []
	for i in 6:
		niches.append({"at": 1.6 + 2.15 * float(i), "w": 1.2, "spring": 1.9, "sill": 1.0, "niche": true, "k": 0.7})
	_wall(k, "plaster", Vector3(x1, y, z0), Vector3(x1, y, z1), h, t, niches, Vector3.RIGHT)
	# buttresses on the chasm side
	for z: float in [z1 + 0.3, -31.0 + 2.6, z0 - 0.3]:
		k.box("stone", Vector3(x0 - 0.7, y + h * 0.42, z), Vector3(1.4, h * 0.84, 1.0), Basis.IDENTITY)
		k.box("stone", Vector3(x0 - 0.45, y + h * 0.9, z), Vector3(0.9, h * 0.25, 0.8), Basis(Vector3.FORWARD, -0.35))
	# interior: four piers carrying ribbed arches, and a ledge round the walls
	for c: Vector2 in [Vector2(21.5, -27.5), Vector2(26.5, -27.5), Vector2(21.5, -34.5), Vector2(26.5, -34.5)]:
		k.block("stone", Vector3(c.x - 0.45, y, c.y - 0.45), Vector3(c.x + 0.45, y + h, c.y + 0.45))
		k.block("stone", Vector3(c.x - 0.65, y, c.y - 0.65), Vector3(c.x + 0.65, y + 0.5, c.y + 0.65), true, 0.85)
	for zz: float in [-27.5, -34.5]:
		k.arch_panel("stone", Vector3(24.0, y, zz), Vector3.RIGHT, 4.1, 4.3, h, 0.5, 0.0, 0.7)
	for xx: float in [21.5, 26.5]:
		k.arch_panel("stone", Vector3(xx, y, -31.0), Vector3.FORWARD, 6.1, 3.6, h, 0.5, 0.0, 0.62)
	k.block("dark", Vector3(x0, y + h, z0), Vector3(x1, y + h + 0.3, z1), true, 0.7)
	_gable_roof(k, Vector3(x0, 0, z0), Vector3(x1, 0, z1), y + h + 0.3, y + h + 4.2, false)
	_undercroft(k, x0 - 0.2, [z0, -31.0, z1], y, 2.2)
	for p: Vector2 in [Vector2(x0 - 0.5, z1 + 0.3), Vector2(x0 - 0.5, -28.4), Vector2(x1 - 0.4, z1 + 0.3)]:
		k.pinnacle("stone", Vector3(p.x, y + h, p.y), 0.8, 2.6, 2.4)
	# bell tower on the north-west corner: the landmark you see from the sanctuary
	var tc := Vector3(x0 + 1.2, y, z0 + 1.2)
	k.block("stone", tc + Vector3(-1.4, 0, -1.4), tc + Vector3(1.4, h + 4.6, 1.4))
	var bel := y + h + 4.6
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		k.box("stone", tc + Vector3(s.x * 1.2, bel - y + 1.6, s.y * 1.2), Vector3(0.45, 3.2, 0.45))
	k.block("stone", tc + Vector3(-1.6, bel - y + 3.2, -1.6), tc + Vector3(1.6, bel - y + 3.6, 1.6), true, 0.85)
	k.pinnacle("slate", tc + Vector3(0, bel - y + 3.6, 0), 2.6, 0.4, 7.5)
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		k.pinnacle("stone", tc + Vector3(s.x * 1.45, bel - y + 3.6, s.y * 1.45), 0.4, 0.5, 1.6)
	k.candle_cluster(tc + Vector3(0, bel - y, 0), 10, 0.7, _rng)
	# ossuary benches along the niche wall: stacked skulls and long bones
	for i in 22:
		var zz := z0 + 0.8 + 12.4 * float(i) / 21.0
		k.skull(Vector3(x1 - t * 0.5 - 0.35, y + 0.02, zz), -PI * 0.5 + _rng.randf_range(-0.3, 0.3), _rng.randf_range(0.95, 1.2))
		if i % 2 == 0:
			k.bone(Vector3(x1 - t * 0.5 - 0.7, y + 0.03, zz), Basis(Vector3.UP, _rng.randf_range(-0.2, 0.2)))
	for i in 10:
		k.candle_cluster(Vector3(_rng.randf_range(19.0, 29.0), y, _rng.randf_range(-37.2, -24.8)), _rng.randi_range(4, 9), 0.3, _rng)
	k.candle_cluster(Vector3(24.0, y, -24.9), 14, 0.9, _rng)


# --- niche gallery --------------------------------------------------------------------------

func _gallery(k: OssKit) -> void:
	var x0 := 17.5
	var x1 := 27.0
	var z0 := -67.0
	var z1 := -51.0
	var y := GAL_Y
	var h := 6.0
	var t := 0.7
	k.block("floor", Vector3(x0, y - 0.6, z0), Vector3(x1, y, z1))
	k.block("stone", Vector3(x0 - 0.3, y - 1.4, z0 - 0.3), Vector3(x1, y - 0.6, z1 + 0.3), true, 0.8)
	for z: float in [z0, -59.0, z1]:
		_pier(k, x0, z, y - 0.6, 2.2)
		_pier(k, 23.0, z, y - 0.6, 2.0)
	# west: open arcade over the chasm, waist-high sill so the view stays open
	var arcade: Array = []
	for i in 5:
		arcade.append({"at": 1.8 + 3.1 * float(i), "w": 2.3, "spring": 2.6, "sill": 0.95, "k": 0.8})
	_wall(k, "stone", Vector3(x0, y, z1), Vector3(x0, y, z0), h, t, arcade)
	# east: two rows of skull niches against the cliff
	var low: Array = []
	for i in 8:
		low.append({"at": 1.1 + 1.95 * float(i), "w": 1.1, "spring": 1.5, "sill": 0.7, "niche": true, "k": 0.7})
	_wall(k, "plaster", Vector3(x1, y, z0), Vector3(x1, y, z1), 3.4, t, low, Vector3.RIGHT)
	var high: Array = []
	for i in 8:
		high.append({"at": 1.1 + 1.95 * float(i), "w": 1.0, "spring": 1.2, "sill": 0.35, "niche": true, "k": 0.7})
	_wall(k, "plaster", Vector3(x1, y + 3.4, z0), Vector3(x1, y + 3.4, z1), h - 3.4, t, high, Vector3.RIGHT)
	# ends: south door from the stair, north door to the next stair
	_wall(k, "plaster", Vector3(x0, y, z1), Vector3(x1, y, z1), h, t, [{"at": 5.5, "w": 3.0, "spring": 2.9}])
	_wall(k, "plaster", Vector3(x0, y, z0), Vector3(x1, y, z0), h, t, [{"at": 3.5, "w": 3.0, "spring": 2.9}])
	# spine: piers down the middle with arches between, splitting two aisles
	var xm := 22.25
	for i in 5:
		var zc := z1 - 1.0 - 3.5 * float(i)
		k.block("stone", Vector3(xm - 0.4, y, zc - 0.4), Vector3(xm + 0.4, y + h, zc + 0.4))
		if i < 4:
			k.arch_panel("stone", Vector3(xm, y, zc - 1.75), Vector3.FORWARD, 2.7, 2.7, h, 0.5, 0.0, 0.75)
	k.block("dark", Vector3(x0, y + h, z0), Vector3(x1, y + h + 0.3, z1), true, 0.7)
	_gable_roof(k, Vector3(x0, 0, z0), Vector3(x1, 0, z1), y + h + 0.3, y + h + 3.4, false)
	_undercroft(k, x0 - 0.2, [z0, -59.0, z1], y, 2.2)
	for z: float in [z0 + 0.3, -59.0, z1 - 0.3]:
		k.box("stone", Vector3(x0 - 0.6, y + h * 0.45, z), Vector3(1.2, h * 0.9, 0.9), Basis.IDENTITY)
		k.pinnacle("stone", Vector3(x0 - 0.6, y + h, z), 0.7, 1.6, 2.0)
	# bone heaps in the aisles + candles
	for i in 6:
		var at := Vector3(_rng.randf_range(23.4, 26.0), y, _rng.randf_range(-66.0, -52.0))
		_bone_heap(k, at, _rng.randf_range(0.5, 0.9))
	for i in 14:
		k.candle_cluster(Vector3(_rng.randf_range(18.4, 26.2), y, _rng.randf_range(-66.3, -51.7)), _rng.randi_range(3, 8), 0.28, _rng)


func _bone_heap(k: OssKit, at: Vector3, r: float) -> void:
	for i in int(r * 34.0):
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r
		var hgt := (1.0 - d / r) * r * 0.55
		var p := at + Vector3(cos(a) * d, hgt * _rng.randf_range(0.4, 1.0) + 0.03, sin(a) * d)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.5, 0.5))
		if _rng.randf() < 0.25:
			k.skull(p, _rng.randf() * TAU, _rng.randf_range(0.9, 1.1))
		else:
			k.bone(p, b)


# --- charnel pit ----------------------------------------------------------------------------

func _pit(k: OssKit) -> void:
	var c := PIT_C
	var n := 28
	var thick := 1.2
	# floor disc (top + rim + underside) as a fan; collision included
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * PIT_R
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * PIT_R
		k.quad("floor", c, p0, p1, c, Vector3.UP)
		var dn := Vector3.DOWN * thick
		k.quad("stone", c + dn, p1 + dn, p0 + dn, c + dn, Vector3.DOWN)
		var out := (Vector3(cos(a0), 0, sin(a0)) + Vector3(cos(a1), 0, sin(a1))).normalized()
		k.quad("stone", p0, p1, p1 + dn, p0 + dn, out)
	# drum and corbels underneath, down into the lava
	for i in 8:
		var a := TAU * float(i) / 8.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 3.2
		k.box("stone", Vector3(p.x, (LAVA_Y + c.y - thick) * 0.5, p.z), Vector3(2.0, c.y - thick - LAVA_Y, 2.0), Basis(Vector3.UP, a))
		var q := c + Vector3(cos(a), 0, sin(a)) * 6.0
		k.box("stone", q + Vector3.UP * (-thick - 1.2), Vector3(4.0, 2.4, 1.0), Basis(Vector3.UP, -a).orthonormalized() * Basis(Vector3.FORWARD, 0.0), false, 0.8)
	# parapet ring with gaps: entry (towards the stair foot), chapel (north), lift (west)
	var gaps := [_ang_to(Vector3(21.0, 0, -78.0)), -PI * 0.5, PI]
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var am := (a0 + a1) * 0.5
		var skip := false
		for g in gaps:
			if absf(angle_difference(am, float(g))) < 0.28:
				skip = true
		if skip:
			continue
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * (PIT_R - 0.25)
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * (PIT_R - 0.25)
		k.parapet("stone", p0, p1, 0.8, 0.4)
	# broken colonnade, bone mounds, spitter plinths
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		var p := c + Vector3(cos(a), 0, sin(a)) * 6.6
		var hgt := 6.5 if i % 3 == 0 else _rng.randf_range(1.6, 4.4)
		k.box("stone", p + Vector3.UP * (hgt * 0.5), Vector3(0.9, hgt, 0.9), Basis(Vector3.UP, a))
		k.box("stone", p + Vector3.UP * 0.25, Vector3(1.4, 0.5, 1.4), Basis(Vector3.UP, a), true, 0.85)
		if hgt < 6.0:
			k.candle_cluster(p + Vector3.UP * hgt, _rng.randi_range(3, 6), 0.25, _rng)
	for a: float in [0.6, 2.3, 3.9, 5.1]:
		_bone_heap(k, c + Vector3(cos(a), 0, sin(a)) * 4.0, 1.2)
	for a: float in [1.2, 4.6]:
		var p := c + Vector3(cos(a), 0, sin(a)) * 5.2
		k.block("stone", p + Vector3(-1.0, 0, -1.0), p + Vector3(1.0, 1.6, 1.0))
		k.candle_cluster(p + Vector3(0, 1.6, 0), 6, 0.6, _rng)
	k.candle_cluster(c, 30, 1.3, _rng)
	# landing from the stair
	k.block("floor", Vector3(19.0, PIT_Y - 0.6, -80.0), Vector3(23.0, PIT_Y, -77.6))
	_pier(k, 21.0, -79.0, PIT_Y - 0.6, 2.0)


func _ang_to(p: Vector3) -> float:
	return atan2(p.z - PIT_C.z, p.x - PIT_C.x)


# --- chapel --------------------------------------------------------------------------------

func _chapel(k: OssKit) -> void:
	var x0 := 12.0
	var x1 := 20.0
	var z0 := -104.0
	var z1 := -96.0
	var y := PIT_Y
	var h := 6.0
	var t := 0.7
	k.block("floor", Vector3(15.0, y - 0.6, -96.0), Vector3(17.0, y, -93.8))     # walk from the pit
	k.block("floor", Vector3(x0, y - 0.6, z0), Vector3(x1, y, z1))
	for p: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		_pier(k, p.x, p.y, y - 0.6, 2.0)
	_wall(k, "plaster", Vector3(x0, y, z1), Vector3(x1, y, z1), h, t, [{"at": 4.0, "w": 2.4, "spring": 2.8}])
	_wall(k, "plaster", Vector3(x1, y, z0), Vector3(x0, y, z0), h, t, [{"at": 4.0, "w": 1.4, "spring": 3.2, "sill": 1.8, "k": 1.2, "glow": true}])
	var side_n: Array = []
	for i in 3:
		side_n.append({"at": 1.6 + 2.4 * float(i), "w": 1.0, "spring": 1.6, "sill": 0.9, "niche": true, "k": 0.7})
	_wall(k, "plaster", Vector3(x0, y, z0), Vector3(x0, y, z1), h, t, side_n, Vector3.LEFT)
	_wall(k, "plaster", Vector3(x1, y, z1), Vector3(x1, y, z0), h, t, side_n, Vector3.RIGHT)
	k.block("dark", Vector3(x0, y + h, z0), Vector3(x1, y + h + 0.3, z1), true, 0.7)
	_gable_roof(k, Vector3(x0, 0, z0), Vector3(x1, 0, z1), y + h + 0.3, y + h + 3.0, true)
	for p: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		k.pinnacle("stone", Vector3(p.x, y + h, p.y), 0.7, 1.2, 2.2)
	k.pinnacle("slate", Vector3(16.0, y + h + 3.0, -100.0), 1.0, 0.3, 4.0)
	# altar
	k.block("stone", Vector3(14.6, y, -103.2), Vector3(17.4, y + 1.0, -101.8))
	k.block("stone", Vector3(14.4, y + 1.0, -103.4), Vector3(17.6, y + 1.15, -101.6), true, 0.9)
	k.candle_cluster(Vector3(14.9, y + 1.15, -102.5), 6, 0.2, _rng)
	k.candle_cluster(Vector3(17.1, y + 1.15, -102.5), 6, 0.2, _rng)
	for i in 6:
		k.candle_cluster(Vector3(_rng.randf_range(12.8, 19.2), y, _rng.randf_range(-103.3, -96.7)), 5, 0.3, _rng)


# --- lights, lift, reliquary, enemies -------------------------------------------------------

func _lights() -> void:
	make_brazier("OssuaryGate", Vector3(24.0, HALL_Y, -31.0), 0.0)
	_omni("HallFill", Vector3(24.0, HALL_Y + 4.8, -31.0), Color(1.0, 0.62, 0.3), 1.1, 11.0, false)
	_omni("GalleryA", Vector3(22.25, GAL_Y + 3.6, -54.5), Color(1.0, 0.58, 0.28), 1.3, 9.0, false)
	_omni("GalleryB", Vector3(22.25, GAL_Y + 3.6, -63.0), Color(1.0, 0.58, 0.28), 1.3, 9.0, false)
	_omni("PitCandles", PIT_C + Vector3(0, 3.2, 0), Color(1.0, 0.6, 0.3), 2.2, 13.0, true)
	_omni("Chapel", Vector3(16.0, PIT_Y + 3.0, -101.0), Color(0.75, 0.45, 1.0), 1.6, 8.0, false)
	_omni("BridgeUnder", Vector3(10.5, HALL_Y - 4.0, -34.0), Color(1.0, 0.45, 0.15), 1.4, 10.0, false)


func _omni(n: String, at: Vector3, col: Color, e: float, r: float, shadow: bool) -> void:
	var l := OmniLight3D.new()
	l.name = n
	l.light_color = col
	l.omni_range = r
	l.light_energy = e
	l.shadow_enabled = shadow
	l.set_meta(&"light_class", "fill")
	l.set_meta(&"base", {"e": e, "r": r, "a": 1.0})
	add_child(l)
	l.global_position = at
	LightPolicy.apply_fade(l)
	LightPolicy.apply_illumination(l)
	if not shadow:
		l.shadow_enabled = false


func _lift() -> void:
	var lift := ChainLift.new()
	lift.name = "ChainLift"
	lift.bottom = Vector3(11.45, PIT_Y, -83.5)   # west deck edge meets the summit rim (x ≈ 10.1)
	lift.top_y = 26.56                          # summit plinth ring top (measured)
	add_child(lift)


func _reliquary() -> void:
	var r := Reliquary.new()
	r.name = "BoneReliquary"
	r.relic_id = "bone"
	add_child(r)
	r.global_position = Vector3(16.0, PIT_Y + 1.15, -102.5)


func _spawns() -> void:
	EnemySpawner._seed(self, [
		{"at": Vector3(16.6, HALL_Y + 1.0, -34.0), "kinds": ["spitter"], "probe": 1.5},
		{"at": Vector3(20.0, GAL_Y + 1.0, -56.0), "kinds": ["wretch", "wretch"], "probe": 1.5, "r": 1.6},
		{"at": Vector3(24.6, GAL_Y + 1.0, -62.5), "kinds": ["ossuant", "spitter"], "probe": 1.5, "r": 1.4},
		{"at": PIT_C + Vector3(0.0, 1.0, -1.5), "kinds": ["ossuant", "ossuant", "husk"], "probe": 1.5, "r": 2.2},
		{"at": PIT_C + Vector3(cos(1.2) * 5.2, 2.6, sin(1.2) * 5.2), "kinds": ["spitter"], "probe": 1.5},
		{"at": PIT_C + Vector3(cos(4.6) * 5.2, 2.6, sin(4.6) * 5.2), "kinds": ["spitter"], "probe": 1.5},
	])
