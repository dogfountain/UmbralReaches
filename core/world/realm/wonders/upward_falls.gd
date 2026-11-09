extends RefCounted
## THE UPWARD FALLS (the Sorrow, above Weirford): where the river climbs.
## Lore: the Order wanted the Sorrow at the abbey, which stood higher than any river runs, so it built a weir across
## the valley and a glacis of dressed stone up its face, and the hydrographers taught the water to climb. It
## climbed for the Order as long as the Order's sky held. When the sky began to turn, the river kept the lesson
## and lost the destination: it still runs up the glacis, stands out of the weir's basin and rises into the turning
## dark, thinning to spray, and what the dark cannot keep comes back as a fine cold rain on the pool below.
## From the road it is a pale column over the Crowns' foot. Close up it is a broken aqueduct (two flood arches and
## the sluice-house, the east arches fallen) with the river going up its face. The hydrographers' stair, torn out in
## three flights, still reaches the deck: stand in the basin's spray (a secret: core/life/secrets/site_upward_falls.gd).
##
## Where: the Sorrow's upper course, x -207, z -18 (the weir), between the drowned shrine (z -40) and the camp
## (z 0), off weir_track (x -188) and the Hierarch's raid (north of z -68). The ground is the valley floor, so
## nothing is stamped: the masonry keys into the bed and the banks, the water is shader, the drops are particles.
## Collision: the weir, its arcade, the deck, the stair's ramps and the glacis (steeper than the wanderer can stand).

const Water := preload("res://core/world/realm/wonders/upward_falls/water.gd")
const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")
const NAME := "upward_falls"
const CX := -207.0                  ## the river's line at the weir
const ZC := -18.0                   ## the weir's middle
const DECK := 10.0                  ## the deck and the sluice-house roof
const SLAB := 1.2
const UNDER := DECK - SLAB
const BASE := -1.8                  ## the weir's foundation, under the bed (-0.8)
const PROBE_LAYER := 1 << 30
const STAIR_BRK := 0.6              ## each break in the hydrographers' stair: up 0.6, across 1.5 (one jump)
const STAIR_GAP := 1.5
const PLACEHOLDER_STONE := false     ## the primitive stand-in masonry (not shipped: the model replaces it)

var k: OssKit
var space: PhysicsDirectSpaceState3D
var rng := RandomNumberGenerator.new()
var report: Array[String] = []
var _cols: Array[AABB] = []
var _temp: Array[Node] = []
var _audit: Array[String] = []
var _parts: Array = []              ## [Transform3D, size, label] of every piece, for the clearance audit
var _last_hit := ""
var _stair_foot := Vector3.ZERO
var _placed: Array[AABB] = []       ## the scattered blocks, kept off each other


static func build(root: Node) -> void:
	var w = new()
	await w._run(root)


func _run(root: Node) -> void:
	rng.seed = 3801
	space = (root as Node3D).get_world_3d().direct_space_state
	k = OssKit.new()
	k.keep_lanes = false
	k.candle_lights = false
	var host := Node3D.new()
	host.name = "UpwardFalls"
	host.set_meta("site", NAME)
	root.add_child(host)
	var stone := Node3D.new()
	stone.name = "Stone"
	host.add_child(stone)
	# the ground first (before any collision of ours is in the space)
	var g_foot := _ground(-254.0, ZC)
	_collect_instances(root)
	_stand_ins(root, host)
	await root.get_tree().physics_frame
	_site()
	# The hero stone is the Blender model (art/models/upward_falls.glb, tools/blender/wonder_upward_falls.py), placed
	# once its turnaround is approved. Until then only the water, the light and the marker stand, and the primitive
	# stand-in masonry below stays off.
	if PLACEHOLDER_STONE:
		_weir()
		_arcade()
		_stair(maxf(g_foot, 0.5) + 0.1)
		_glacis()
		_basin()
		_rubble()
		_audit_parts()
	else:
		_glacis_water()
		_stair_foot = Vector3(-254.1, maxf(g_foot, 0.5) + 0.1, ZC)
	for b in _temp:
		b.queue_free()
	_temp.clear()
	k.commit(stone, "UpwardFallsBody")
	_far(stone)
	_water(host)
	_marker(host)
	report.append("clearance: %s" % ("nothing touched" if _audit.is_empty() else "; ".join(_audit)))
	for s in report:
		print("WONDER %s %s" % [NAME, s])
	await root.get_tree().physics_frame


func _ground(x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


# --- the claim ----------------------------------------------------------------------------------------

func _site() -> void:
	# nothing is cut from the ground (cut_y far above it): the site keeps the flora and the dress off
	WorldLanes.register_site(NAME, Rect2(-258.0, -33.0, 66.0, 17.5), 0.6, 60.0)
	var who := PackedStringArray()
	for p: Vector2 in [Vector2(-254, ZC), Vector2(-237, ZC), Vector2(CX, ZC), Vector2(-195, ZC), Vector2(-191, -14), Vector2(CX, -30)]:
		who.append("%s path %.1f" % [p, RealmLayout.path_dist(p)])
	report.append("paths: " + "; ".join(who))


# --- the pieces ---------------------------------------------------------------------------------------

func _b(key: String, c: Vector3, size: Vector3, b := Basis.IDENTITY, solid := true, shade := 1.0, label := "") -> void:
	k.box(key, c, size, b, solid, shade)
	if label != "":
		_parts.append([Transform3D(b, c), size, label])


## A broken run of low wall from a to b: random lengths, gaps where the stone has gone, uneven heights.
func _wall(a: Vector3, b: Vector3, h: float, t: float, gap := 0.2, label := "wall") -> void:
	var d := b - a
	var len := d.length()
	var dir := d / len
	var bas := Basis(dir, Vector3.UP, dir.cross(Vector3.UP).normalized())
	var s := 0.0
	while s < len - 0.3:
		var seg := minf(rng.randf_range(1.3, 3.2), len - s)
		if rng.randf() > gap:
			var hh := h * rng.randf_range(0.55, 1.0)
			var c := a + dir * (s + seg * 0.5) + Vector3.UP * (hh * 0.5)
			_b("stone", c, Vector3(seg, hh, t), bas, true, rng.randf_range(0.82, 1.0), label)
			if rng.randf() < 0.6:
				k.broken_crown("stone", c + Vector3.UP * (hh * 0.5), bas, seg, t, rng, 0.86)
		s += seg


func _weir() -> void:
	var zs := 3.5                                    # half depth
	# footing, the sluice-house, its cornice and roof
	_b("ruin", Vector3(CX, (BASE + 1.6) * 0.5, ZC), Vector3(17.4, 1.6 - BASE, 8.2), Basis.IDENTITY, true, 0.8, "weir plinth")
	_b("stone", Vector3(CX, (BASE + UNDER) * 0.5, ZC), Vector3(16.0, UNDER - BASE, zs * 2.0), Basis.IDENTITY, true, 0.95, "weir")
	_b("ruin", Vector3(CX, UNDER - 0.2, ZC), Vector3(16.8, 0.4, 7.8), Basis.IDENTITY, true, 0.9, "weir cornice")
	_b("stone", Vector3(CX, DECK - SLAB * 0.5, ZC), Vector3(16.6, SLAB, 7.4), Basis.IDENTITY, true, 1.0, "roof slab")
	# a string course under the niches, and pilasters up the north face either side of the glacis
	_b("ruin", Vector3(CX, 5.0, ZC + zs + 0.05), Vector3(16.3, 0.25, 0.3), Basis.IDENTITY, false, 0.9)
	for sx: float in [-1.0, 1.0]:
		for off: float in [6.6, 7.6]:
			_b("stone", Vector3(CX + sx * off, (UNDER + 1.6) * 0.5, ZC - zs - 0.22), Vector3(0.8, UNDER - 1.6, 0.5), Basis.IDENTITY, true, 0.95, "pilaster")
	# the south face: a great arched recess and two small ones, with the pool below
	var south := ZC + zs + 0.05
	k.arch_panel("stone", Vector3(CX, 1.6, south), Vector3.RIGHT, 5.5, 3.2, UNDER - 1.6, 1.0, 0.9, 0.5, 0.0, "ruin")
	for sx: float in [-1.0, 1.0]:
		k.arch_panel("stone", Vector3(CX + sx * 6.3, 1.6, south), Vector3.RIGHT, 2.4, 3.2, UNDER - 1.6, 1.0, 0.5, 0.5, 0.0, "ruin")
	_parts.append([Transform3D(Basis.IDENTITY, Vector3(CX, 5.0, south)), Vector3(16.0, 7.0, 1.0), "south recesses"])
	# the roof: parapets, the basin's plinth, the four corner pylons (two broken)
	var rz := 3.15
	_wall(Vector3(CX - 7.9, DECK, ZC + rz), Vector3(CX + 7.9, DECK, ZC + rz), 1.0, 0.45, 0.18, "roof parapet")
	_wall(Vector3(CX - 7.9, DECK, ZC - rz), Vector3(CX - 5.4, DECK, ZC - rz), 1.0, 0.45, 0.0, "roof parapet")
	_wall(Vector3(CX + 5.4, DECK, ZC - rz), Vector3(CX + 7.9, DECK, ZC - rz), 1.0, 0.45, 0.0, "roof parapet")
	_wall(Vector3(CX - 7.9, DECK, ZC - rz), Vector3(CX - 7.9, DECK, ZC + rz), 1.0, 0.45, 0.15, "roof parapet")
	_wall(Vector3(CX + 7.9, DECK, ZC - rz), Vector3(CX + 7.9, DECK, ZC + rz), 1.0, 0.45, 0.15, "roof parapet")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var base := Vector3(CX + sx * 7.45, DECK, ZC + sz * 2.95)
			if sx * sz > 0.0:
				_b("stone", base + Vector3.UP * 0.9, Vector3(1.1, 1.8, 1.1), Basis(Vector3.UP, 0.06), true, 0.88, "pylon stump")
				k.broken_crown("stone", base + Vector3.UP * 1.8, Basis.IDENTITY, 1.1, 1.1, rng, 0.84)
			else:
				k.pinnacle("stone", base, 1.0, 4.2, 1.8)
				_parts.append([Transform3D(Basis.IDENTITY, base + Vector3.UP * 3.0), Vector3(1.3, 6.0, 1.3), "pylon"])


func _arcade() -> void:
	# two flood arches west of the sluice-house, then the hydrographers' abutment
	for cxo: float in [-11.0, -19.4]:
		k.arch_panel("stone", Vector3(CX + cxo, -0.6, ZC), Vector3.RIGHT, 6.0, 4.8, UNDER + 0.6, 4.0, 1.2, 0.5, 0.0, "ruin")
		for pier: float in [-1.0, 1.0]:
			var px: float = CX + cxo + pier * 4.2
			_parts.append([Transform3D(Basis.IDENTITY, Vector3(px, 4.0, ZC)), Vector3(0.3, 8.0, 4.0), "arch pier"])
	_b("stone", Vector3(-233.8, (UNDER - 1.5) * 0.5, ZC), Vector3(6.4, UNDER + 1.5, 5.0), Basis.IDENTITY, true, 0.95, "abutment")
	_b("ruin", Vector3(-226.05, UNDER - 0.2, ZC), Vector3(22.7, 0.4, 4.6), Basis.IDENTITY, true, 0.9, "arcade cornice")
	_b("stone", Vector3(-226.05, DECK - SLAB * 0.5, ZC), Vector3(22.5, SLAB, 5.2), Basis.IDENTITY, true, 1.0, "arcade deck")
	for sz: float in [-1.0, 1.0]:
		_wall(Vector3(-237.0, DECK, ZC + sz * 2.3), Vector3(-215.0, DECK, ZC + sz * 2.3), 0.95, 0.42, 0.2, "deck parapet")
	_wall(Vector3(-237.0, DECK, ZC - 2.3), Vector3(-237.0, DECK, ZC + 2.3), 0.95, 0.42, 0.55, "deck parapet")
	# the east: the deck stops in a torn edge over where the arches stood
	_b("stone", Vector3(-197.2, DECK - SLAB * 0.5, ZC), Vector3(3.6, SLAB, 5.2), Basis.IDENTITY, true, 0.97, "deck stub")
	_b("ruin", Vector3(-197.2, UNDER - 0.2, ZC), Vector3(3.6, 0.4, 4.6), Basis.IDENTITY, true, 0.9, "stub cornice")
	for i in 5:
		var tz := ZC - 2.0 + float(i) * 1.0
		_b("stone", Vector3(-195.2 - rng.randf_range(0.0, 0.5), DECK - 0.35 - rng.randf_range(0.0, 0.5), tz), Vector3(rng.randf_range(0.8, 1.4), 0.6, 0.95), Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)) * Basis(Vector3.FORWARD, rng.randf_range(-0.1, 0.1)), false, 0.9)


## The hydrographers' stair: three flights up the west face, each carried on a pier, a one-jump break between them.
func _stair(g0: float) -> void:
	var x_hi := -237.0 - STAIR_GAP
	var n := 14
	var run := 4.2
	var r := (DECK - g0 - 3.0 * STAIR_BRK) / (3.0 - 2.0 / float(n))
	var lo := g0
	var moves := PackedStringArray()
	_stair_foot = Vector3(x_hi - 2.0 * (run + STAIR_GAP) - run, g0, ZC)
	for f in 3:
		var hi_x := x_hi - float(2 - f) * (run + STAIR_GAP)
		var lo_x := hi_x - run
		var hi := lo + r
		var g := minf(_ground(lo_x, ZC), _ground(hi_x, ZC))
		var base_y := lo - 0.45
		if f == 0:
			base_y = minf(g - 0.4, lo - 0.45)
		k.stairs("stone", Vector3(lo_x, lo, ZC), Vector3(hi_x, hi, ZC), 2.6, n, base_y)
		_parts.append([Transform3D(Basis.IDENTITY, Vector3((lo_x + hi_x) * 0.5, (lo + hi) * 0.5, ZC)), Vector3(run, r, 2.6), "stair flight %d" % f])
		if f > 0:                                      # a pier under the flight, to the ground
			var top := lo - 0.45
			_b("ruin", Vector3((lo_x + hi_x) * 0.5, (g - 0.5 + top) * 0.5, ZC), Vector3(run - 0.3, top - g + 0.5, 2.3), Basis.IDENTITY, true, 0.82, "stair pier %d" % f)
		var next_lo := hi + STAIR_BRK - r / float(n)
		moves.append("f%d %.1f>%.1f" % [f, lo, hi])
		lo = next_lo
	report.append("stair: %s, last break up %.2f to the deck at %.1f (breaks %.1f up, %.1f across)" % [", ".join(moves), DECK - (lo - STAIR_BRK + r / float(n)), DECK, STAIR_BRK, STAIR_GAP])
	# fallen steps in the breaks
	for f in 3:
		var bx := x_hi - float(2 - f) * (run + STAIR_GAP) + STAIR_GAP * 0.5
		for i in 2:
			var s := rng.randf_range(0.5, 0.9)
			var gy := _ground(bx + rng.randf_range(-0.4, 0.4), ZC + rng.randf_range(-1.6, 1.6))
			_scatter(Vector3(bx + rng.randf_range(-0.5, 0.5), gy + s * 0.25, ZC + rng.randf_range(-1.8, 1.8)), Vector3(s, s * 0.6, s * 1.2))


func _glacis_water() -> void:
	var foot := Vector3(CX, -0.9, ZC - 11.5)
	var top := Vector3(CX, DECK, ZC - 3.5)
	var yd := ((top - foot).normalized()).cross(Vector3.RIGHT)
	var pts: Array = []
	var widths: Array = []
	for t: float in [0.13, 0.28, 0.45, 0.62, 0.8, 0.94, 1.0]:
		pts.append(foot.lerp(top, t) + yd * 0.08)
		widths.append(6.0)
	pts.append(Vector3(CX, DECK + 0.07, ZC - 3.1))
	widths.append(5.2)
	pts.append(Vector3(CX, DECK + 0.07, ZC - 2.55))
	widths.append(3.4)
	_climb = [pts, widths]


func _glacis() -> void:
	var foot := Vector3(CX, -0.9, ZC - 11.5)
	var top := Vector3(CX, DECK, ZC - 3.5)
	var len := foot.distance_to(top)
	var d := (top - foot) / len
	var yd := d.cross(Vector3.RIGHT)
	var bas := Basis(Vector3.RIGHT, yd, d)
	var mid := (foot + top) * 0.5
	_b("stone", mid - yd * 4.0, Vector3(6.4, 8.0, len), bas, true, 1.0, "glacis")
	for sx: float in [-1.0, 1.0]:
		_b("stone", mid + yd * (1.1 - 4.55) + Vector3.RIGHT * (sx * 3.95), Vector3(1.5, 9.1, len), bas, true, 0.92, "glacis cheek")
	# courses across the cheeks' faces and a thick lip where they meet the foot
	for sx: float in [-1.0, 1.0]:
		for i in 6:
			var t := (float(i) + 0.5) / 6.0
			_b("ruin", foot.lerp(top, t) + yd * 0.35 + Vector3.RIGHT * (sx * 3.95), Vector3(1.75, 0.18, 1.0), bas, false, 0.86)
	# the water that climbs it: from where it leaves the pond to the glacis' top, across the roof to the basin
	var pts: Array = []
	var widths: Array = []
	for t: float in [0.13, 0.28, 0.45, 0.62, 0.8, 0.94, 1.0]:
		pts.append(foot.lerp(top, t) + yd * 0.08)
		widths.append(6.0)
	pts.append(Vector3(CX, DECK + 0.07, ZC - 3.1))
	widths.append(5.2)
	pts.append(Vector3(CX, DECK + 0.07, ZC - 2.55))
	widths.append(3.4)
	_climb = [pts, widths]


var _climb: Array = []
const BASIN_Y := DECK + 0.62
const BASIN_R := 2.05
const BASIN_Z := ZC - 0.2


func _basin() -> void:
	var c := Vector3(CX, DECK, BASIN_Z)
	# an octagonal plinth, and the ring wall with a notch on the north where the river comes in
	for a: float in [0.0, PI * 0.25]:
		_b("stone", c + Vector3.UP * 0.15, Vector3(5.2, 0.3, 5.2), Basis(Vector3.UP, a), true, 0.92, "basin plinth")
	var n := 14
	for i in n:
		if i == 0:
			continue
		var a := -PI * 0.5 + TAU * float(i) / float(n)
		var h := 0.85
		if i == 1 or i == n - 1:
			h = 0.45
		elif i == 6:
			h = 0.6                                     # a stone gone from the ring
		var p := c + Vector3(cos(a), 0.0, sin(a)) * 2.4 + Vector3.UP * (0.3 + h * 0.5)
		_b("stone", p, Vector3(1.15, h, 0.7), Basis(Vector3.UP, -(a + PI * 0.5)), true, rng.randf_range(0.86, 1.0), "basin ring")
	# a sill the water pours over
	_b("ruin", c + Vector3(0.0, 0.3, -2.6), Vector3(1.6, 0.18, 1.0), Basis.IDENTITY, false, 0.9)


## Fallen masonry about the foot of the weir, the east end and the stair.
func _rubble() -> void:
	# a fallen arch ring lying where the east arches stood: voussoirs on an arc
	var centre := Vector3(-194.2, 0.0, ZC + 4.2)
	for i in 9:
		var a := PI * (0.12 + 0.76 * float(i) / 8.0) + 0.3
		var p := centre + Vector3(cos(a), 0.0, sin(a)) * 3.6
		var gy := _ground(p.x, p.z)
		var bas := Basis(Vector3.UP, -(a + PI * 0.5)) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		_scatter(Vector3(p.x, gy + 0.25, p.z), Vector3(0.95, 0.75, 1.5), bas)
	for i in 14:
		var side := rng.randf()
		var p: Vector3
		if side < 0.35:
			p = Vector3(rng.randf_range(-199.0, -191.5), 0.0, rng.randf_range(ZC - 4.5, ZC + 7.5))
		elif side < 0.7:
			p = Vector3(rng.randf_range(-216.0, -198.0), 0.0, ZC + rng.randf_range(4.8, 7.5))
		else:
			p = Vector3(rng.randf_range(-238.0, -222.0), 0.0, ZC + rng.randf_range(-6.0, 6.0))
		if absf(p.z - ZC) < 3.2 and p.x < -215.0 and p.x > -231.0:
			continue                                    # not in the arches' mouths
		if RealmLayout.river_mask(p.x, p.z) > 0.15 and p.z > ZC:
			continue                                    # not in the water
		var s := rng.randf_range(0.5, 1.5)
		var gy := _ground(p.x, p.z)
		_scatter(Vector3(p.x, gy + s * 0.2, p.z), Vector3(s, s * 0.65, s * rng.randf_range(0.8, 1.4)), Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)))


func _scatter(p: Vector3, size: Vector3, bas := Basis.IDENTITY) -> void:
	var bb := AABB(p - size * 0.8, size * 1.6)
	for o in _placed:
		if o.intersects(bb):
			return
	if not _clear(Transform3D(bas, p), size, 0.15):
		return
	_placed.append(bb)
	_b("ruin", p, size, bas, false, rng.randf_range(0.7, 0.95), "")


# --- the water ----------------------------------------------------------------------------------------

func _water(host: Node3D) -> void:
	var basin := Vector3(CX, BASIN_Y, BASIN_Z)
	Water.channel(host, _climb[0], _climb[1], Vector3(CX, BASIN_Y, BASIN_Z), BASIN_R)
	Water.column(host, basin + Vector3.UP * 0.1)
	Water.pool(host, Vector3(CX + 0.5, 0.47, ZC + 12.5), Vector2(15.0, 19.0), Vector2(CX + 0.0, ZC + 12.5), ZC + 3.6)
	Water.particles(host, basin + Vector3.UP * 0.2, Vector3(CX + 2.0, 44.0, ZC + 12.0), Vector3(CX, 0.7, ZC + 11.0))
	Water.lights(host, Vector3(CX, DECK, ZC), Vector3(CX, 0.5, ZC + 8.0))
	# a pale glow over the place, for the road: the sheet itself is lit by nothing and fades in fog
	var bn: Variant = Wayfinding.beacon(host, Vector3(CX, DECK, ZC), "", Color(0.62, 0.82, 1.0), 66.0, 0.5, 30.0, false, 340.0)
	if bn is Node:
		(bn as Node).name = "Beacon_upward_falls"


## The far mesh: from 150 m the stone is a dark hull and the water goes on.
func _far(stone: Node3D) -> void:
	var m := FarDetail.hull(AABB(Vector3(CX - 8.4, BASE, ZC - 3.6), Vector3(16.8, DECK - BASE, 7.2)), 0.0, Color(0.15, 0.16, 0.19))
	FarDetail.register(stone, m, Transform3D.IDENTITY, 150.0)
	var arc := FarDetail.hull(AABB(Vector3(-237.3, -0.8, ZC - 2.6), Vector3(22.4, DECK + 0.8, 5.2)), 0.0, Color(0.15, 0.16, 0.19))
	FarDetail.register(stone, arc, Transform3D.IDENTITY, 150.0)


func _marker(host: Node3D) -> void:
	var m := Node3D.new()
	m.name = "DeckTop"
	m.set_meta("top", Vector3(CX + 0.0, DECK, ZC + 1.9))        # south of the basin, in the spray
	m.set_meta("basin", Vector3(CX, BASIN_Y, BASIN_Z))
	m.set_meta("chest", Vector3(CX + 5.2, DECK, ZC + 1.2))
	m.set_meta("plaque", Vector3(CX - 5.4, DECK, ZC + 1.6))
	m.set_meta("stair_foot", _stair_foot)
	m.set_meta("deck", DECK)
	host.add_child(m)
	m.global_position = Vector3(CX, DECK, ZC + 1.9)


# --- clearance ----------------------------------------------------------------------------------------

func _area() -> AABB:
	return AABB(Vector3(-268.0, -10.0, -40.0), Vector3(86.0, 40.0, 50.0))


func _collect_instances(root: Node) -> void:
	var area := _area()
	for n in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or not mmi.is_visible_in_tree():
			continue
		var mb := mmi.multimesh.mesh.get_aabb()
		if not (mmi.global_transform * mmi.get_aabb()).intersects(area):
			continue
		for i in mmi.multimesh.instance_count:
			var bb: AABB = mmi.global_transform * mmi.multimesh.get_instance_transform(i) * mb
			if bb.intersects(area):
				_cols.append(bb)


func _stand_ins(root: Node, host: Node3D) -> void:
	var area := _area()
	var n_in := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or host.is_ancestor_of(mi):
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if not bb.intersects(area) or bb.size.x * bb.size.z > 6000.0:
			continue
		var path := String(mi.get_path())
		if path.contains("Terrain") or path.contains("Flora") or path.contains("FenWater") or path.contains("Lava"):
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.name = "StandIn"
		body.collision_layer = PROBE_LAYER
		body.collision_mask = 0
		body.set_meta(&"stands_for", path.trim_prefix("/root/Main/"))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		host.add_child(body)
		body.global_transform = mi.global_transform
		_temp.append(body)
		n_in += 1
	report.append("stand-ins: %d meshes, %d instance boxes near" % [n_in, _cols.size()])


## True when a box `size` at `xf` touches nothing built (the ground allowed when `ground_ok`).
func _clear(xf: Transform3D, size: Vector3, grow := 0.3, ground_ok := true) -> bool:
	var sh := BoxShape3D.new()
	sh.size = size + Vector3.ONE * grow * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = xf
	q.collision_mask = Layers.WORLD | PROBE_LAYER
	for hit: Dictionary in space.intersect_shape(q, 24):
		var c := hit.get("collider") as Node
		if ground_ok and c != null and String(c.name).begins_with("Terrain"):
			continue
		_last_hit = String(c.get_meta(&"stands_for", c.get_path())) if c else "?"
		return false
	var bb: AABB = xf * AABB(-size * 0.5 - Vector3.ONE * grow, size + Vector3.ONE * grow * 2.0)
	for cb: AABB in _cols:
		if cb.intersects(bb):
			_last_hit = "an instanced piece at %s" % cb.get_center().snapped(Vector3.ONE * 0.1)
			return false
	return true


func _audit_parts() -> void:
	var checked := 0
	for p: Array in _parts:
		var xf: Transform3D = p[0]
		var size: Vector3 = p[1]
		checked += 1
		if not _clear(xf, size, 0.0, true):
			_audit.append("%s at %s touches %s" % [p[2], xf.origin.snapped(Vector3.ONE * 0.1), _last_hit])
	report.append("audited %d pieces" % checked)
