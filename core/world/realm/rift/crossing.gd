extends RefCounted
## THE CROSSING (RealmRift): the only walkable way from the rift's south rim (RealmLayout.CROSSING_FOOT)
## up to the summit ward (RealmLayout.SUMMIT_WARD), as the ruin of the pilgrims' viaduct:
##   forecourt on the rim, under a pointed gate -> a short flight onto the first round tower ->
##   an arcaded viaduct ramp (two tiers of lancet arches out of the lava) to the west tower ->
##   a gap where the viaduct fell, bridged by a fallen column -> a short flight to the Spindle ->
##   one full turn round the Spindle (a basalt stack): ramp, landing, flight, landing, ramp, landing,
##   flight, on corbels and a colonnade -> out over its own foot on a flying arch, two flights to
##   the ward landing (8 x 9 m, top 25.2) that the summit's approach stairs start from.
## Built in the old hub stair's stone (OssKit "hub" = stone.tres) with stair_column.glb columns.
## Walk surfaces: rise <= Metrics.STEP_MAX, ramps <= 21 deg, clear width >= 3.5 m, parapets
## everywhere except the fallen column (meant to feel exposed). Collision: decks, ramps, kit stair
## ramps, parapets, the Spindle (a cylinder) and the pier feet (so the lava's bank mask sees them).

const HW := 2.2                 ## half walk width (deck 4.4 m, 3.56 m between parapets)
const RAIL_T := 0.42
const RAIL_H := 1.0
const BED := -17.5              ## pier feet, sunk in the lava
const LAVA := -15.5
const DECK := 0.55
const Starlit := preload("res://core/world/realm/rift/starlit_stone.gd")
const KEY := Starlit.STONE     ## dressed ashlar (OssKit "stone", lifted: starlit_stone.gd); the hub stair's stone.tres reads blue-veined here
const HUB := "hub"              ## the hub stair's own stone: the stair_column.glb columns
const PAVE := Starlit.FLOOR
const TRIM := Starlit.STONE
const COLUMN_GLB := "res://art/models/stair_column.glb"
const Basalt := preload("res://core/world/realm/rift/basalt.gd")

const FORE := Rect2(-4.5, -14.0, 9.0, 7.0)          ## the forecourt on the rim: x -4.5..4.5, z -14..-7
const APRON := 2.4                                   ## the landing carried on from the forecourt towards the rim
const FORE_Y := 0.6                                  ## RealmLayout.CROSSING_FOOT.y
## round towers: centre x, centre z, radius, top y
const T1 := Vector4(0.0, -21.0, 3.5, 1.8)
const T2 := Vector4(-13.0, -30.0, 3.5, 4.4)
const T3 := Vector4(-1.8, -40.0, 3.5, 5.6)
const SPIN_C := Vector2(-8.3, -50.0)                 ## the Spindle (basalt stack) the crossing turns round
const SPIN_R := 6.5                                  ## centreline radius of the turn
const SPIN_CORE := 4.1                               ## the stack's radius (collision cylinder)
const SPIN_Y0 := 8.0
const SPIN_Y1 := 21.2
const LAND := Rect2(-4.0, -71.15, 8.0, 9.15)         ## ward landing x -4..4, z -71.15..-62
const LAND_Y := 25.2                                 ## RealmLayout.SUMMIT_WARD.y
const L6_X := -1.8                                   ## the last flights run north at this x

var k: OssKit
var rng := RandomNumberGenerator.new()
var space: PhysicsDirectSpaceState3D
var columns: Array[Transform3D] = []                 ## stair_column.glb instances (unit: 1 x 2 x 1)
var fires: Array = []                                ## [position, light?]
var lane: Array[Vector2] = []                        ## the walked centreline (xz): rim to the Spindle's far side
var lane_turn: Array[Vector2] = []                   ## ... round the Spindle
var lanes2: Array[Vector2] = []                      ## ... and the last flights onto the ward landing
var legs: Array[String] = []                         ## printed summary
var spin_st: SurfaceTool


func build(root: Node, host: Node3D) -> void:
	rng.seed = 51
	space = (root as Node3D).get_world_3d().direct_space_state
	Starlit.ensure()
	k = OssKit.new()
	k.keep_lanes = false
	spin_st = Basalt.new_tool()
	var c1 := Vector2(T1.x, T1.y)
	var c2 := Vector2(T2.x, T2.y)
	var c3 := Vector2(T3.x, T3.y)
	# --- forecourt and the first flight ---------------------------------------------------
	_forecourt()
	var t1s := Vector3(0.0, T1.w, T1.y + T1.z)
	_leg(Vector3(0.0, FORE_Y, FORE.position.y), t1s, "stairs", 0.0, 1.0, "L1 rim steps")
	# --- tower 1 -> arcaded viaduct ramp -> tower 2 ----------------------------------------
	var d12 := (c2 - c1).normalized()
	var a2 := Vector3(c1.x + d12.x * T1.z, T1.w, c1.y + d12.y * T1.z)
	var b2 := Vector3(c2.x - d12.x * T2.z, T2.w, c2.y - d12.y * T2.z)
	_leg(a2, b2, "ramp", 1.1, 1.1, "L2 viaduct")
	# --- tower 2 -> fallen column -> tower 3 ------------------------------------------------
	var d23 := (c3 - c2).normalized()
	var a3 := Vector3(c2.x + d23.x * T2.z, T2.w, c2.y + d23.y * T2.z)
	var b3 := Vector3(c3.x - d23.x * T3.z, T3.w, c3.y - d23.y * T3.z)
	_fallen_column(a3, b3)
	# --- tower 3 -> flight -> the Spindle ------------------------------------------------------
	var a4 := Vector3(T3.x, T3.w, T3.y - T3.z)
	var spin0 := Vector3(SPIN_C.x + SPIN_R, SPIN_Y0, SPIN_C.y)
	_leg(a4, spin0, "stairs", 1.1, 0.0, "L4 flight")
	_tower(T1, [_ang(c1, Vector2(0, FORE.position.y)), _ang(c1, c2)], [0.66, 0.66])
	_tower(T2, [_ang(c2, c1), _ang(c2, c3)], [0.66, 0.5])
	_tower(T3, [_ang(c3, c2), _ang(c3, Vector2(spin0.x, spin0.z)), deg_to_rad(-35.0)], [0.5, 0.66, 0.3])   # (the third: the Pilgrims' Stair down the tower's east side, rift/tower_stair.gd)
	# --- the turn round the Spindle -------------------------------------------------------------
	_spiral()
	# --- flying arch and the last flights to the ward landing -----------------------------------
	_last_flights()
	_landing()
	# lane (xz centreline) for WorldLanes / flora
	# (the stretches stacked over each other - the L4 flight under the turn's last metres, the turn's
	# first metres under the last flights - are left out: their flights/sites keep props off, and a
	# lane there would be audited against the deck above it)
	lane = [Vector2(0, -7), Vector2(0, -14), c1, c2, c3]
	for i in range(3, 22):
		var th := -TAU * float(i) / 24.0
		lane_turn.append(SPIN_C + Vector2(cos(th), sin(th)) * SPIN_R)
	lanes2 = [Vector2(L6_X, SPIN_C.y - 3.0)]
	lanes2.append(Vector2(L6_X, LAND.position.y + LAND.size.y))
	lanes2.append(Vector2(0, LAND.position.y + 1.0))
	# --- commit -------------------------------------------------------------------------------
	k.commit(host, "CrossingBody")
	# one mesh per material spans the whole rift: cut into 24 m cells with LODs so the far half
	# culls and the distant cells draw a fraction of their bevels
	for n in host.get_children():
		if n is MeshInstance3D and String(n.name).begins_with("Mesh_"):
			MeshChunks.split(n as MeshInstance3D)
			n.queue_free()
	_commit_columns(host)
	_commit_spindle(host)
	_commit_fires(host)
	print("SITES Crossing owns %d scatter nodes" % WorldLanes.own(host))    # its columns carry the stair: the cull must not thin them
	for s in legs:
		print("RIFT ", s)


# --- helpers ------------------------------------------------------------------------------------

static func _ang(from: Vector2, to: Vector2) -> float:
	return atan2(to.y - from.y, to.x - from.x)


## Highest ground (anything on the world layer) under x,z, or BED over open lava.
func _ground(x: float, z: float, from_y := 60.0) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, BED - 2.0, z), Layers.WORLD))
	if hit.is_empty():
		return BED
	var y: float = (hit.position as Vector3).y
	return BED if y < LAVA + 0.05 else y


## Foot level for masonry under the xz box: the lowest ground under it, sunk 0.6 m.
func _foot(lo: Vector2, hi: Vector2) -> float:
	var y := INF
	for i in 4:
		for j in 4:
			y = minf(y, _ground(lerpf(lo.x, hi.x, float(i) / 3.0), lerpf(lo.y, hi.y, float(j) / 3.0)))
	return maxf(BED, y - 0.6) if y > BED else BED


## Invisible collision box (centre, size, basis).
func _col(c: Vector3, size: Vector3, b := Basis.IDENTITY) -> void:
	k._box_col(c, b.x.normalized() * size.x * 0.5, b.y.normalized() * size.y * 0.5, b.z.normalized() * size.z * 0.5)


## Pier foot collision at the lava line (the bank mask in LavaWorks rays for rock at the surface).
func _foot_col(c: Vector2, size: Vector2, foot_y: float) -> void:
	if foot_y < LAVA:
		_col(Vector3(c.x, (foot_y + LAVA + 1.0) * 0.5, c.y), Vector3(size.x, LAVA + 1.0 - foot_y, size.y))


## A parapet wall a -> b (both at floor level, may slope). Broken stretches lose their coping and
## a little height, never below 0.82 m (STEP_MAX is 0.45: you cannot walk over any of it).
func _wall(a: Vector3, b: Vector3, h := RAIL_H, coped := true, shade := 0.92) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.05:
		return
	var fwd := d / len
	var hz := Vector3(d.x, 0, d.z).normalized()
	var side := hz.cross(Vector3.UP).normalized()
	var up := side.cross(fwd).normalized()
	k.box(KEY, (a + b) * 0.5 + up * (h * 0.5), Vector3(RAIL_T, h, len + 0.03), Basis(side, up, fwd), true, shade)
	if coped:
		k.box(TRIM, (a + b) * 0.5 + up * (h + 0.06), Vector3(RAIL_T + 0.16, 0.12, len + 0.08), Basis(side, up, fwd), true, 0.98)
	else:
		# jagged broken top: a few loose blocks left on the wall
		var n := int(len / 0.9)
		for i in n:
			if rng.randf() < 0.45:
				var t := (float(i) + 0.5) / float(maxi(n, 1))
				var bh := rng.randf_range(0.1, 0.28)
				k.box(KEY, a.lerp(b, t) + up * (h + bh * 0.5), Vector3(RAIL_T * 0.9, bh, rng.randf_range(0.3, 0.6)), Basis(side, up, fwd), true, 0.85)


## Parapet along a polyline of floor points, in ~2.6 m stretches, some of them broken.
func _rail(pts: Array, posts := true, broken := 0.22) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n := maxi(1, roundi(a.distance_to(b) / 2.6))
		for j in n:
			var p0 := a.lerp(b, float(j) / float(n))
			var p1 := a.lerp(b, float(j + 1) / float(n))
			var br := rng.randf() < broken
			_wall(p0, p1, rng.randf_range(0.84, 0.92) if br else RAIL_H, not br)
			if posts and (j > 0 or i > 0) and not br:
				_post(p0)
	if posts and not pts.is_empty():
		_post(pts[0])
		_post(pts[pts.size() - 1])


func _post(p: Vector3) -> void:
	k.box(KEY, p + Vector3.UP * 0.62, Vector3(0.56, 1.24, 0.56), Basis.IDENTITY, true, 0.96)
	k.box(TRIM, p + Vector3.UP * 1.3, Vector3(0.66, 0.14, 0.66), Basis.IDENTITY, true, 1.0)


## A lantern stub: a broken column drum with an iron fire cage on top (flame added at commit).
func _lantern(p: Vector3, light := false) -> void:
	columns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.5, 0.45, 0.5)), p + Vector3.UP * 0.45))
	_col(p + Vector3.UP * 0.6, Vector3(0.55, 1.2, 0.55))
	k.box("iron", p + Vector3.UP * 0.95, Vector3(0.62, 0.08, 0.62), Basis.IDENTITY, false)
	for s in 4:
		var a := TAU * float(s) / 4.0 + PI * 0.25
		k.box("iron", p + Vector3(cos(a) * 0.27, 1.17, sin(a) * 0.27), Vector3(0.05, 0.42, 0.05), Basis.IDENTITY, false)
	k.box("iron", p + Vector3.UP * 1.38, Vector3(0.6, 0.05, 0.6), Basis.IDENTITY, false)
	fires.append([p + Vector3.UP * 1.05, light])


# --- forecourt ------------------------------------------------------------------------------------

func _forecourt() -> void:
	var lo := FORE.position
	var hi := FORE.end
	var foot := _foot(lo, hi)
	# paving on a plinth down to the slope
	k.block(PAVE, Vector3(lo.x, FORE_Y - 0.35, lo.y), Vector3(hi.x, FORE_Y, hi.y), true, 1.0)
	k.block(KEY, Vector3(lo.x + 0.15, foot, lo.y + 0.15), Vector3(hi.x - 0.15, FORE_Y - 0.35, hi.y - 0.15), true, 0.88)
	k.block(TRIM, Vector3(lo.x - 0.1, FORE_Y - 0.55, lo.y - 0.1), Vector3(hi.x + 0.1, FORE_Y - 0.35, hi.y + 0.1), false, 0.9)
	# the landing: the forecourt's paving carried on 2.4 m towards the rim, so the way up to the gate arrives on a broad
	# stone landing (kerbed, lit by the lanterns) and not straight on the rim's slope
	k.block(PAVE, Vector3(lo.x, FORE_Y - 0.35, hi.y), Vector3(hi.x, FORE_Y, hi.y + APRON), true, 1.0)
	k.block(KEY, Vector3(lo.x + 0.15, foot, hi.y), Vector3(hi.x - 0.15, FORE_Y - 0.35, hi.y + APRON - 0.15), true, 0.88)
	k.block(TRIM, Vector3(lo.x - 0.1, FORE_Y - 0.55, hi.y), Vector3(hi.x + 0.1, FORE_Y - 0.35, hi.y + APRON + 0.1), false, 0.9)
	# buttresses on the chasm side
	for x: float in [lo.x + 0.6, -2.9, 2.9, hi.x - 0.6]:
		var f := maxf(BED, _ground(x, lo.y - 1.0) - 0.6)
		if FORE_Y - f > 2.0:
			k.block(KEY, Vector3(x - 0.5, f, lo.y - 1.4), Vector3(x + 0.5, FORE_Y - 1.2, lo.y + 0.1), false, 0.9)
			k.box(KEY, Vector3(x, FORE_Y - 1.1, lo.y - 0.75), Vector3(1.0, 0.3, 1.5), Basis(Vector3.RIGHT, 0.35), false, 0.85)
	# parapets: east and west, the north edge either side of the gate; the south edge is the way in
	var y := FORE_Y
	_rail([Vector3(lo.x + 0.21, y, hi.y + APRON - 0.4), Vector3(lo.x + 0.21, y, lo.y + 0.21), Vector3(-3.25, y, lo.y + 0.21)])
	_rail([Vector3(hi.x - 0.21, y, hi.y + APRON - 0.4), Vector3(hi.x - 0.21, y, lo.y + 0.21), Vector3(3.25, y, lo.y + 0.21)])
	# the gate: a pointed arch over the first flight, newels on the south corners
	k.arch_panel(KEY, Vector3(0, y, lo.y + 0.45), Vector3.RIGHT, 4.5, 3.6, 6.4, 1.0, 0.85, 0.85, 0.0, TRIM)
	k.pinnacle(KEY, Vector3(lo.x + 0.4, y, hi.y + APRON - 0.4), 0.7, 1.9, 0.6)
	k.pinnacle(KEY, Vector3(hi.x - 0.4, y, hi.y + APRON - 0.4), 0.7, 1.9, 0.6)
	_lantern(Vector3(lo.x + 1.0, y, lo.y + 1.6), true)
	_lantern(Vector3(hi.x - 1.0, y, lo.y + 1.6), false)
	# the approach: if the rim path arrives lower than the forecourt, a broad flight down to it
	var z0 := hi.y + APRON
	var g0 := _ground(0.0, z0 + 0.3, FORE_Y + 3.0)
	var drop := FORE_Y - g0
	if drop > 0.35 and drop < 8.0:
		var run := 0.0
		var gy := g0
		while run < 14.0:
			run += 0.25
			gy = _ground(0.0, z0 + run, FORE_Y + 3.0)
			if gy >= FORE_Y - run * 0.42 - 0.05:
				break
		var steps := Metrics.steps_for(FORE_Y - gy)
		var foot_p := Vector3(0, gy, z0 + run)
		k.stairs(KEY, foot_p, Vector3(0, FORE_Y, z0), 6.0, steps, gy - 1.2)
		k.block(KEY, Vector3(-3.0, gy - 2.0, z0), Vector3(3.0, gy - 0.6, z0 + run), false, 0.85)
		for s: float in [-1.0, 1.0]:
			_wall(Vector3(s * 3.21, gy, z0 + run), Vector3(s * 3.21, FORE_Y, z0), RAIL_H, true)
		WorldLanes.register_flight("rift_crossing_approach", foot_p, Vector3(0, FORE_Y, z0), 3.2)
		legs.append("approach flight %d steps from y %.2f over %.1f m" % [steps, gy, run])
	else:
		legs.append("approach: rim ground at the forecourt %.2f (forecourt %.2f), no flight" % [g0, FORE_Y])
	WorldLanes.register_site("rift_forecourt", Rect2(lo, hi - lo + Vector2(0.0, APRON)).grow(0.4), FORE_Y, FORE_Y - 0.3, true)


# --- towers ---------------------------------------------------------------------------------------

## A round tower out of the lava: battered plinth, drum, string course, corbel table, paved top
## with an inlaid ring, parapet broken open where the walkways join (`opens` angles, half widths).
func _tower(t: Vector4, opens: Array, halfs: Array) -> void:
	var c := Vector3(t.x, 0, t.y)
	var r := t.z
	var top := t.w
	var foot := _foot(Vector2(t.x - r, t.y - r), Vector2(t.x + r, t.y + r))
	var n := 20
	var fw := 2.0 * r * sin(PI / float(n)) + 0.08
	var plinth := minf(LAVA + 1.6, top - DECK - 2.0)
	for i in n:
		var a := TAU * (float(i) + 0.5) / float(n)
		var dir := Vector3(cos(a), 0, sin(a))
		var tan_v := Vector3(-dir.z, 0, dir.x)
		var bas := Basis(tan_v, Vector3.UP, dir)
		var h := top - DECK - foot
		k.box(KEY, c + dir * (r - 0.5) + Vector3.UP * (foot + h * 0.5), Vector3(fw, h, 1.0), bas, false, 0.88 + 0.08 * float(i % 2))
		# battered plinth in the lava
		if plinth > foot + 0.5:
			var ph := plinth - foot
			k.box("dark", c + dir * (r - 0.2) + Vector3.UP * (foot + ph * 0.5), Vector3(fw + 0.12, ph, 1.2), bas, false, 0.8)
			k.box(TRIM, c + dir * (r + 0.25) + Vector3.UP * plinth, Vector3(fw + 0.1, 0.5, 0.8), bas * Basis(Vector3.RIGHT, -0.5), false, 0.85)
		# string course half way, corbel table under the deck
		var mid := (foot + top) * 0.5
		if top - foot > 8.0:
			k.box(TRIM, c + dir * (r - 0.02) + Vector3.UP * mid, Vector3(fw + 0.02, 0.32, 0.4), bas, false, 0.95)
		k.box(TRIM, c + dir * (r + 0.05) + Vector3.UP * (top - DECK - 0.12), Vector3(fw + 0.05, 0.3, 0.5), bas, false, 0.95)
		if i % 2 == 0:
			k.box(KEY, c + dir * (r + 0.05) + Vector3.UP * (top - DECK - 0.62), Vector3(0.36, 0.7, 0.34), bas, false, 0.82)
	_foot_col(Vector2(t.x, t.y), Vector2(r * 1.7, r * 1.7), foot)
	# paved top: fan of quads, a slate ring, a kerb; rim face down to the corbels
	var rings: Array[float] = [0.0, r * 0.42, r * 0.5, r - 0.3, r]
	var keys: Array[String] = [PAVE, "slate", PAVE, TRIM]
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for ri in rings.size() - 1:
			var r0: float = rings[ri]
			var r1: float = rings[ri + 1]
			k.quad(keys[ri], c + d0 * r0 + Vector3.UP * top, c + d0 * r1 + Vector3.UP * top, c + d1 * r1 + Vector3.UP * top, c + d1 * r0 + Vector3.UP * top, Vector3.UP, true, 0.93 if i % 2 == 0 else 1.0)
		k.quad(TRIM, c + d0 * r + Vector3.UP * (top - DECK), c + d1 * r + Vector3.UP * (top - DECK), c + d1 * r + Vector3.UP * top, c + d0 * r + Vector3.UP * top, (d0 + d1) * 0.5, true, 0.9)
	# parapet: n segments on the ring, left open across each joining walkway
	var rr := r - RAIL_T * 0.5 - 0.05
	var open := func(a: float) -> bool:
		for j in opens.size():
			if absf(angle_difference(a, float(opens[j]))) < float(halfs[j]):
				return true
		return false
	var closed: Array[bool] = []
	for i in n:
		closed.append(not open.call(TAU * (float(i) + 0.5) / float(n)))
	var first := closed.find(false)
	if first < 0:
		first = 0
	var run: Array = []
	for j in n:
		var i := (first + 1 + j) % n
		if closed[i]:
			if run.is_empty():
				var a0 := TAU * float(i) / float(n)
				run.append(c + Vector3(cos(a0), 0, sin(a0)) * rr + Vector3.UP * top)
			var a1 := TAU * float(i + 1) / float(n)
			run.append(c + Vector3(cos(a1), 0, sin(a1)) * rr + Vector3.UP * top)
		elif run.size() >= 2:
			_rail(run, true, 0.18)
			run = []
	if run.size() >= 2:
		_rail(run, true, 0.18)
	WorldLanes.register_site("rift_tower_%d_%d" % [roundi(t.x), roundi(t.y)], Rect2(t.x - r, t.y - r, r * 2, r * 2), top, top - 0.3)


# --- legs -----------------------------------------------------------------------------------------

## A straight walkway a -> b (centreline points at the joining edges, floor heights): "ramp" (paved
## slab) or "stairs" (kit flight). Flat aprons `ea`/`eb` metres long run back into the structures
## at each end (just under their floors) so a diagonal joint leaves no notch to step into.
## Underneath: a sloped spine and lancet arcades down to the lava (two tiers when tall).
func _leg(a: Vector3, b: Vector3, kind: String, ea: float, eb: float, label: String) -> void:
	var dh := Vector3(b.x - a.x, 0, b.z - a.z)
	var run := dh.length()
	var dir := dh / run
	var side := dir.cross(Vector3.UP).normalized()
	var rise := b.y - a.y
	var fwd := (b - a).normalized()
	var up := side.cross(fwd).normalized()
	var slope := rise / run
	var hb := Basis(side, Vector3.UP, dir)
	var steps := 0
	if kind == "stairs":
		steps = Metrics.steps_for(rise)
		k.stairs(PAVE, a, b, HW * 2.0, steps, a.y - 0.75)
		# the kit's flight has collision on its ramp only: give the step stack its spine
		k.box(KEY, (a + b) * 0.5 - up * 0.95, Vector3(HW * 2.0 - 0.1, 0.9, (b - a).length()), Basis(side, up, fwd), false, 0.86)
	else:
		k.box(PAVE, (a + b) * 0.5 - up * (DECK * 0.5), Vector3(HW * 2.0, DECK, (b - a).length()), Basis(side, up, fwd), true, 1.0)
	if ea > 0.0:
		k.box(PAVE, a - dir * (ea * 0.5) + Vector3.UP * (-0.02 - DECK * 0.5), Vector3(HW * 2.0, DECK, ea), hb, true, 0.95)
	if eb > 0.0:
		k.box(PAVE, b + dir * (eb * 0.5) + Vector3.UP * (-0.02 - DECK * 0.5), Vector3(HW * 2.0, DECK, eb), hb, true, 0.95)
	# the spine under the walk
	var bays := maxi(1, roundi(run / 6.0))
	var bay := run / float(bays)
	var body := maxf(1.5, absf(slope) * bay + 0.6)
	var top_off := DECK + (0.75 if kind == "stairs" else 0.0)
	k.box(KEY, (a + b) * 0.5 - up * (top_off + body * 0.5), Vector3(HW * 2.0 - 0.2, body, (b - a).length()), Basis(side, up, fwd), false, 0.84)
	# string course along both faces of the spine
	for s: float in [-1.0, 1.0]:
		k.box(TRIM, (a + b) * 0.5 - up * (top_off + 0.1) + side * (s * (HW - 0.05)), Vector3(0.24, 0.26, (b - a).length()), Basis(side, up, fwd), false, 0.95)
	# arcades: one pointed arch per bay through the full width of the walk
	for i in bays:
		var x0 := bay * float(i)
		var x1 := bay * float(i + 1)
		var xm := (x0 + x1) * 0.5
		var sl := sqrt(1.0 + slope * slope)
		var under := a.y + slope * maxf(x0, x1) - (top_off + body) * sl + 0.1 if slope >= 0.0 else a.y + slope * minf(x0, x1) - (top_off + body) * sl + 0.1
		var pc := Vector2(a.x, a.z) + Vector2(dir.x, dir.z) * xm
		var foot := maxf(BED, minf(_ground(pc.x - dir.x * bay * 0.45, pc.y - dir.z * bay * 0.45), _ground(pc.x + dir.x * bay * 0.45, pc.y + dir.z * bay * 0.45)) - 0.6)
		var h := under - foot
		if h < 1.0:
			continue
		var base := Vector3(pc.x, foot, pc.y)
		var thick := HW * 2.0 - 0.3
		var open_w := bay - 1.5
		if h > 14.0:
			var h1 := h * 0.5
			_arch(base, dir, open_w + 0.3, h1, thick)
			k.box(TRIM, base + Vector3.UP * (h1 + 0.17), Vector3(thick + 0.3, 0.34, bay + 0.02), hb, false, 0.95)
			_arch(base + Vector3.UP * (h1 + 0.34), dir, open_w - 0.6, h - h1 - 0.34, thick - 0.4)
		else:
			_arch(base, dir, open_w, h, thick)
		_foot_col(pc, Vector2(thick, bay), foot)
		# cutwaters on the piers where they stand in the lava
		if foot <= BED + 0.01:
			for e: float in [x0, x1]:
				if (e == 0.0 and ea > 0.0) or (e == run and eb > 0.0):
					continue
				var pp := Vector2(a.x, a.z) + Vector2(dir.x, dir.z) * e
				for s: float in [-1.0, 1.0]:
					k.box(KEY, Vector3(pp.x, (BED + LAVA + 3.0) * 0.5, pp.y) + side * (s * (thick * 0.5 + 0.4)), Vector3(1.1, LAVA + 3.0 - BED, 1.1), Basis(Vector3.UP, PI * 0.25) * hb, false, 0.8)
	# parapets, extended over the aprons to meet the towers' rings
	for s: float in [-1.0, 1.0]:
		var o := side * (s * (HW - RAIL_T * 0.5))
		var lift := 0.0 if kind == "ramp" else 0.15
		var pts: Array = []
		if ea > 0.0:
			pts.append(a - dir * ea + o)
		pts.append(a + o + Vector3.UP * lift)
		pts.append(b + o + Vector3.UP * lift)
		if eb > 0.0:
			pts.append(b + dir * eb + o)
		_rail(pts)
	var ang := rad_to_deg(atan(slope))
	legs.append("%s: %s run %.1f m rise %.2f (%.1f deg)%s" % [label, kind, run, rise, ang, (" %d steps of %.3f" % [steps, rise / float(steps)]) if steps > 0 else ""])
	WorldLanes.register_flight("rift_" + label.get_slice(" ", 0).to_lower(), a, b, HW + 0.3)


## A lancet arch through a pier wall: opening `w`, overall height `h` from `base`.
func _arch(base: Vector3, dir: Vector3, w: float, h: float, thick: float) -> void:
	if w < 1.0:
		k.box(KEY, base + Vector3.UP * (h * 0.5), Vector3(thick, h, w + 1.5), Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir), false, 0.86)
		return
	var curve := OssKit.arch_curve(w, 0.85, 7)
	var apex := curve[curve.size() / 2].y
	var spring := maxf(0.0, h - apex - 0.9)
	if spring < 0.8:
		k.box(KEY, base + Vector3.UP * (h * 0.5), Vector3(thick, h, w + 1.5), Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir), false, 0.86)
		return
	k.arch_panel(KEY, base, dir, w, spring, h, thick, 0.75, 0.85, 0.0, TRIM)


# --- the fallen column ------------------------------------------------------------------------------

## The viaduct's span between tower 2 and tower 3 fell into the lava; one of its great columns lies
## across the gap, its top worn flat where pilgrims have crossed (3 m wide), no parapet. Broken
## stubs of the old deck jut from both towers; a snapped pier stands in the lava under it.
func _fallen_column(a: Vector3, b: Vector3) -> void:
	var dh := Vector3(b.x - a.x, 0, b.z - a.z)
	var run := dh.length()
	var dir := dh / run
	var side := dir.cross(Vector3.UP).normalized()
	var R := 1.95
	var chord := 1.5
	var sag := sqrt(R * R - chord * chord)
	var a0 := a - dir * 1.8 + Vector3.UP * (-(b.y - a.y) / run * 1.8)    # sunk back into tower 2 (below its floor)
	var fwd := (b - a0).normalized()
	var up := side.cross(fwd).normalized()
	var axis0 := a0 - up * sag
	var axis1 := b - up * sag
	var length := axis0.distance_to(axis1)
	# drums: polygon section (circle with the top cut flat), slight wobble and gaps between drums
	var segs := 22
	var drums := maxi(3, roundi(length / 1.7))
	for di in drums:
		var t0 := float(di) / float(drums)
		var t1 := float(di + 1) / float(drums)
		var p0 := axis0.lerp(axis1, t0) + fwd * (0.03 if di > 0 else 0.0)
		var p1 := axis0.lerp(axis1, t1) - fwd * (0.03 if di < drums - 1 else 0.0)
		var rs := R * rng.randf_range(0.97, 1.0)
		var tw := rng.randf_range(-0.12, 0.12)
		var sec: Array[Vector3] = []
		for i in segs:
			var ang := TAU * float(i) / float(segs) + tw
			var v := side * cos(ang) * rs + up * sin(ang) * rs
			# flatten the top: clip to the chord plane
			if v.dot(up) > sag:
				v = v - up * (v.dot(up) - sag)
				v = v * 1.0
			sec.append(v)
		for i in segs:
			var i1 := (i + 1) % segs
			var mid := (sec[i] + sec[i1]) * 0.5
			var nrm := mid.normalized() if mid.dot(up) < sag - 0.01 else up
			k.quad(KEY if mid.dot(up) < sag - 0.01 else PAVE, p0 + sec[i], p0 + sec[i1], p1 + sec[i1], p1 + sec[i], nrm, false, 0.9 + 0.08 * float(di % 2))
		for e: Array in [[p0, -fwd], [p1, fwd]]:
			var pc: Vector3 = e[0]
			for i in segs:
				k.quad(KEY, pc, pc + sec[i], pc + sec[(i + 1) % segs], pc, e[1], false, 0.75)
	# walk surface collision: the flat top
	_col((a0 + b) * 0.5 - up * 0.25, Vector3(chord * 2.0, 0.5, a0.distance_to(b)), Basis(side, up, fwd))
	k.box(PAVE, b + dir * 0.5 + Vector3.UP * (-0.02 - 0.25), Vector3(chord * 2.0, 0.5, 1.0), Basis(side, Vector3.UP, dir), true, 0.95)
	# broken deck stubs jutting from both towers, below the column
	for e: Array in [[a, dir], [b, -dir]]:
		var p: Vector3 = e[0]
		var d: Vector3 = e[1]
		for s: float in [-1.0, 1.0]:
			var len := rng.randf_range(0.9, 1.8) + 0.9
			k.box(KEY, p + d * (len * 0.5 - 0.9) + side * (s * (chord + 0.5)) + Vector3.UP * (-0.75), Vector3(0.9, 1.0, len), Basis(side, Vector3.UP, d), false, 0.85)
	# the snapped pier in the lava under the gap, and fallen voussoirs round it
	var mid := (Vector2(a.x, a.z) + Vector2(b.x, b.z)) * 0.5
	var stump := rng.randf_range(-5.0, -3.0)
	k.block(KEY, Vector3(mid.x - 1.4, BED, mid.y - 1.4), Vector3(mid.x + 1.4, stump, mid.y + 1.4), false, 0.82)
	for i in 5:
		var off := Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
		var bh := rng.randf_range(0.4, 1.1)
		k.box(KEY, Vector3(mid.x + off.x, stump + bh * 0.5, mid.y + off.y), Vector3(rng.randf_range(0.5, 1.2), bh, rng.randf_range(0.5, 1.2)), Basis(Vector3.UP, rng.randf() * TAU), false, 0.8)
	_foot_col(mid, Vector2(2.8, 2.8), BED)
	for i in 7:
		var p := mid + Vector2(rng.randf_range(-6, 6), rng.randf_range(-5, 5))
		var s := rng.randf_range(0.8, 1.8)
		k.box(KEY, Vector3(p.x, LAVA + s * 0.15, p.y), Vector3(s * 1.6, s, s), Basis(Vector3(rng.randf(), 1, rng.randf()).normalized(), rng.randf() * TAU), false, 0.75)
	legs.append("L3 fallen column: span %.1f m rise %.2f (%.1f deg), 3.0 m flat top, no parapet" % [run, b.y - a.y, rad_to_deg(atan((b.y - a.y) / run))])
	WorldLanes.register_flight("rift_l3", a, b, chord + 0.3)


# --- the turn round the Spindle ---------------------------------------------------------------------

## One full turn, clockwise seen from above, from the Spindle's east side back over itself:
## ramp, landing, flight, landing, ramp, landing, flight (each slope 78 deg of arc, 21 deg).
func _spiral() -> void:
	var c := Vector3(SPIN_C.x, 0, SPIN_C.y)
	var land := deg_to_rad(16.0)
	var q := (TAU - 3.0 * land) / 4.0
	var dy := (SPIN_Y1 - SPIN_Y0) / 4.0
	var y := SPIN_Y0
	var th := 0.0
	var parts: Array = []        # [th0, th1, y0, y1, kind]
	for i in 4:
		parts.append([th, th - q, y, y + dy, "ramp" if i % 2 == 0 else "stairs"])
		th -= q
		y += dy
		if i < 3:
			parts.append([th, th - land, y, y, "flat"])
			th -= land
	var rail_pts: Array = []
	for p: Array in parts:
		var th0: float = p[0]
		var th1: float = p[1]
		var y0: float = p[2]
		var y1: float = p[3]
		var kind: String = p[4]
		var arc := absf(th1 - th0) * SPIN_R
		var n := maxi(2, ceili(absf(th1 - th0) / deg_to_rad(4.0)))
		if kind == "stairs":
			n = Metrics.steps_for(y1 - y0)
		var tread := arc / float(n)
		for i in n:
			var ta := lerpf(th0, th1, float(i) / float(n))
			var tb := lerpf(th0, th1, float(i + 1) / float(n))
			var tm := (ta + tb) * 0.5
			var radial := Vector3(cos(tm), 0, sin(tm))
			var tangent := Vector3(sin(tm), 0, -cos(tm))      # direction of travel (theta decreasing)
			var ya := lerpf(y0, y1, float(i) / float(n))
			var yb := lerpf(y0, y1, float(i + 1) / float(n))
			var outer_len := (SPIN_R + HW) * absf(tb - ta) + 0.06
			var ctr := c + radial * (SPIN_R - 0.15)
			if kind == "stairs":
				var top := y0 + (y1 - y0) * float(i + 1) / float(n)
				k.box(PAVE, ctr + Vector3.UP * (top - 0.35), Vector3(HW * 2.0 + 0.3, 0.7, outer_len), Basis(radial, Vector3.UP, tangent), false, 0.9 if i % 2 == 0 else 1.0)
				k.box(KEY, ctr + Vector3.UP * (top - 0.7 - 0.8), Vector3(HW * 2.0, 1.6, outer_len), Basis(radial, Vector3.UP, tangent), false, 0.84)
			else:
				var f := (tangent * (SPIN_R * absf(tb - ta)) + Vector3.UP * (yb - ya)).normalized()
				var up := radial.cross(f).normalized()
				k.box(PAVE, ctr + Vector3.UP * ((ya + yb) * 0.5) - up * (DECK * 0.5), Vector3(HW * 2.0 + 0.3, DECK, outer_len), Basis(radial, up, f), true, 0.94 if i % 2 == 0 else 1.0)
				k.box(KEY, ctr + Vector3.UP * ((ya + yb) * 0.5) - up * (DECK + 0.8), Vector3(HW * 2.0, 1.6, outer_len), Basis(radial, up, f), false, 0.84)
			# outer string course and the corbels into the stack
			k.box(TRIM, c + radial * (SPIN_R + HW - 0.02) + Vector3.UP * (minf(ya, yb) - (1.3 if kind == "stairs" else DECK + 0.1)), Vector3(0.26, 0.26, outer_len), Basis(radial, Vector3.UP, tangent), false, 0.95)
			if i % 3 == 1:
				var cy := minf(ya, yb) - (1.4 if kind == "stairs" else 1.2)
				for ci in 3:
					var w := 1.9 - 0.5 * float(ci)
					k.box(KEY, c + radial * (SPIN_R - HW - 0.2 + w * 0.5 - 0.6) + Vector3.UP * (cy - 0.8 - 0.55 * float(ci)), Vector3(w, 0.55, 0.9), Basis(radial, Vector3.UP, tangent), false, 0.8)
		# collision for the flights: the kit's ramp through the tread middles, shifted half a tread back
		if kind == "stairs":
			_curved_ramp(c, th0, th1, y0, y1, tread)
		# parapet points along the outer edge
		var m := maxi(2, ceili(absf(th1 - th0) / deg_to_rad(7.0)))
		for i in m + 1:
			if i == 0 and not rail_pts.is_empty():
				continue
			var tt := lerpf(th0, th1, float(i) / float(m))
			var yy := lerpf(y0, y1, float(i) / float(m)) + (0.15 if kind == "stairs" else 0.0)
			rail_pts.append(c + Vector3(cos(tt), 0, sin(tt)) * (SPIN_R + HW - RAIL_T * 0.5) + Vector3.UP * yy)
		if kind == "flat":
			var tm := (th0 + th1) * 0.5
			_lantern(c + Vector3(cos(tm), 0, sin(tm)) * (SPIN_R + HW - 0.75) + Vector3.UP * y0, true)
		legs.append("spindle %s: arc %.1f m rise %.2f (%.1f deg)%s" % [kind, arc, y1 - y0, rad_to_deg(atan((y1 - y0) / arc)), (" %d steps of %.3f" % [n, (y1 - y0) / float(n)]) if kind == "stairs" else ""])
	# the outer parapet, all the way round (posts on every other stretch)
	var chunk: Array = []
	var ci := 0
	for i in rail_pts.size():
		chunk.append(rail_pts[i])
		if chunk.size() == 4 or i == rail_pts.size() - 1:
			_rail(chunk, false, 0.1)
			if ci % 2 == 0:
				_post(chunk[0])
			ci += 1
			chunk = [rail_pts[i]]
	# the colonnade: stair columns under the outer edge down to the lava (not over the L4 flight)
	for i in 18:
		var tt := -TAU * (float(i) + 0.5) / 18.0
		var p := c + Vector3(cos(tt), 0, sin(tt)) * (SPIN_R + HW - 0.65)
		if p.x > -4.6 and p.z > -51.0:
			continue                                        # over the L4 flight / tower 3
		var frac := absf(tt) / TAU
		var deck_y := SPIN_Y0 + (SPIN_Y1 - SPIN_Y0) * frac - 1.6
		var foot := maxf(BED, _ground(p.x, p.z, deck_y - 1.0) - 0.5)
		var h := deck_y - foot
		columns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.1, h * 0.5, 1.1)), Vector3(p.x, foot + h * 0.5, p.z)))
		k.box(TRIM, Vector3(p.x, deck_y + 0.15, p.z), Vector3(1.5, 0.3, 1.5), Basis(Vector3.UP, -tt), false, 0.95)
	# the Spindle itself: a hex basalt stack taller than the turn, collision a cylinder
	var top_at := func(d: float) -> float: return lerpf(29.5, 23.6, d * d) + rng.randf_range(-0.6, 2.2) + (rng.randf_range(-6.0, -2.0) if d < 0.5 and rng.randf() < 0.2 else 0.0)
	var cols := Basalt.bundle(spin_st, rng, Vector3(SPIN_C.x, BED - 0.5, SPIN_C.y), SPIN_CORE - 0.3, 0.5, top_at, 0.6)
	# a few spires breaking the skyline
	for i in 3:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.5, 2.2)
		Basalt.column(spin_st, rng, Vector3(SPIN_C.x + cos(a) * d, 24.0, SPIN_C.y + sin(a) * d), 0.5, rng.randf_range(31.0, 34.0))
	legs.append("spindle: %d basalt columns, core r %.1f" % [cols, SPIN_CORE])
	WorldLanes.register_site("rift_spindle", Rect2(SPIN_C - Vector2.ONE * (SPIN_R + HW), Vector2.ONE * (SPIN_R + HW) * 2.0), SPIN_Y0, SPIN_Y0 - 0.3)


## Collision ramp for a curved flight: a strip from the inner to the outer edge whose height runs
## from y0 (half a tread before the first nosing) to y1, then flat for the last half tread.
func _curved_ramp(c: Vector3, th0: float, th1: float, y0: float, y1: float, tread: float) -> void:
	var arc := absf(th1 - th0) * SPIN_R
	var n := maxi(4, ceili(arc / 0.35))
	var ri := SPIN_R - HW - 0.3
	var ro := SPIN_R + HW
	var yat := func(s: float) -> float: return y0 + (y1 - y0) * clampf((s + tread * 0.5) / arc, 0.0, 1.0) if s < arc - tread * 0.5 else y1
	for i in n:
		var sa := arc * float(i) / float(n)
		var sb := arc * float(i + 1) / float(n)
		var ta := th0 + (th1 - th0) * sa / arc
		var tb := th0 + (th1 - th0) * sb / arc
		var da := Vector3(cos(ta), 0, sin(ta))
		var db := Vector3(cos(tb), 0, sin(tb))
		var ya: float = yat.call(sa)
		var yb: float = yat.call(sb)
		var p := [c + da * ri + Vector3.UP * ya, c + da * ro + Vector3.UP * ya, c + db * ro + Vector3.UP * yb, c + db * ri + Vector3.UP * yb]
		k.col_faces.append_array(PackedVector3Array([p[0], p[1], p[2], p[0], p[2], p[3]]))


# --- the flying arch, the last flights and the ward landing ----------------------------------------

func _last_flights() -> void:
	var z0 := SPIN_C.y
	var z3 := LAND.position.y + LAND.size.y          # the landing's south edge (-62)
	var mid := (z0 + z3) * 0.5
	var a := Vector3(L6_X, SPIN_Y1, z0)
	var m0 := Vector3(L6_X, (SPIN_Y1 + LAND_Y) * 0.5, mid + 1.0)
	var m1 := Vector3(L6_X, m0.y, mid - 1.0)
	var b := Vector3(L6_X, LAND_Y, z3)
	_leg_flight(a, m0, "L6a flight")
	# mid landing between the two flights
	k.box(PAVE, Vector3(L6_X, m0.y - DECK * 0.5, mid), Vector3(HW * 2.0, DECK, 2.0), Basis.IDENTITY, true, 1.0)
	_leg_flight(m1, b, "L6b flight")
	for s: float in [-1.0, 1.0]:
		_rail([Vector3(L6_X + s * (HW - RAIL_T * 0.5), m0.y, mid + 1.0), Vector3(L6_X + s * (HW - RAIL_T * 0.5), m0.y, mid - 1.0)], true, 0.0)
	_lantern(Vector3(L6_X + HW - 0.75, m0.y, mid), true)
	# the flying arch under it: springs from the Spindle's side, lands on the landing tower
	var spring_y := SPIN_Y1 - 2.6 - 5.4
	k.arch_panel(KEY, Vector3(L6_X, spring_y, mid), Vector3.FORWARD, z0 - z3 - 2.4, 0.0, SPIN_Y1 - 2.0 - spring_y, HW * 2.0 - 0.3, 1.2, 0.62, 0.0, TRIM)
	# fill between the arch's flat top and the rising flights
	var fill_lo := SPIN_Y1 - 2.0
	k.block(KEY, Vector3(L6_X - HW + 0.15, fill_lo, mid + 1.0), Vector3(L6_X + HW - 0.15, SPIN_Y1 - 0.75, z0 - 0.4), false, 0.86)
	k.block(KEY, Vector3(L6_X - HW + 0.15, fill_lo, mid - 1.0), Vector3(L6_X + HW - 0.15, m0.y - 1.4, mid + 1.0), false, 0.86)
	k.block(KEY, Vector3(L6_X - HW + 0.15, fill_lo, z3), Vector3(L6_X + HW - 0.15, LAND_Y - 1.4, mid - 1.0), false, 0.86)


func _leg_flight(a: Vector3, b: Vector3, label: String) -> void:
	var rise := b.y - a.y
	var run := Vector2(b.x - a.x, b.z - a.z).length()
	var steps := Metrics.steps_for(rise)
	k.stairs(PAVE, a, b, HW * 2.0, steps, a.y - 0.75)
	for s: float in [-1.0, 1.0]:
		var o := Vector3(s * (HW - RAIL_T * 0.5), 0.15, 0)
		_rail([a + o, b + o], true, 0.25)
	legs.append("%s: stairs run %.1f m rise %.2f (%.1f deg) %d steps of %.3f" % [label, run, rise, rad_to_deg(atan(rise / run)), steps, rise / float(steps)])
	WorldLanes.register_flight("rift_" + label.get_slice(" ", 0).to_lower(), a, b, HW + 0.3)


func _landing() -> void:
	var lo := LAND.position
	var hi := LAND.end
	var y := LAND_Y
	var foot := _foot(lo, hi)
	# paved deck with a slate border, on a square tower with corner buttresses and blind arcades
	k.block(PAVE, Vector3(lo.x + 0.5, y - 0.35, lo.y), Vector3(hi.x - 0.5, y, hi.y - 0.5), true, 1.0)
	k.block("slate", Vector3(lo.x, y - 0.35, lo.y), Vector3(lo.x + 0.5, y, hi.y), true, 0.95)
	k.block("slate", Vector3(hi.x - 0.5, y - 0.35, lo.y), Vector3(hi.x, y, hi.y), true, 0.95)
	k.block("slate", Vector3(lo.x + 0.5, y - 0.35, hi.y - 0.5), Vector3(hi.x - 0.5, y, hi.y), true, 0.95)
	k.block(KEY, Vector3(lo.x + 0.2, foot, lo.y + 0.2), Vector3(hi.x - 0.2, y - 0.35, hi.y - 0.2), false, 0.86)
	k.block(TRIM, Vector3(lo.x - 0.1, y - 0.75, lo.y), Vector3(hi.x + 0.1, y - 0.35, hi.y + 0.1), false, 0.95)
	_foot_col((lo + hi) * 0.5, hi - lo, foot)
	for cx: float in [lo.x, hi.x]:
		for cz: float in [hi.y]:
			k.block(KEY, Vector3(cx - 0.8, foot, cz - 0.8), Vector3(cx + 0.8, y - 3.0, cz + 0.8), false, 0.9)
			k.box(KEY, Vector3(cx, y - 2.8, cz), Vector3(1.7, 0.5, 1.7), Basis(Vector3(1, 0, 1).normalized(), 0.0), false, 0.85)
	# blind arcades on the three open faces, two tiers
	var h := y - 0.8 - foot
	for face: Array in [[Vector3(lo.x - 0.05, 0, (lo.y + hi.y) * 0.5), Vector3.FORWARD, hi.y - lo.y], [Vector3(hi.x + 0.05, 0, (lo.y + hi.y) * 0.5), Vector3.FORWARD, hi.y - lo.y], [Vector3(0, 0, hi.y + 0.05), Vector3.RIGHT, hi.x - lo.x]]:
		var p: Vector3 = face[0]
		var along: Vector3 = face[1]
		var w: float = face[2]
		var h1 := h * 0.52
		var w1 := w - 2.8
		k.arch_panel(KEY, Vector3(p.x, foot, p.z), along, w1, maxf(0.5, h1 - _apex(w1, 0.9) - 0.6), h1, 0.5, 1.4, 0.9)
		k.box(TRIM, Vector3(p.x, foot + h1 + 0.15, p.z), Vector3(0.7 if along == Vector3.FORWARD else w, 0.3, w if along == Vector3.FORWARD else 0.7), Basis.IDENTITY, false, 0.95)
		var w2 := w - 3.6
		var h2 := h - h1 - 0.3
		k.arch_panel(KEY, Vector3(p.x, foot + h1 + 0.3, p.z), along, w2, maxf(0.5, h2 - _apex(w2, 0.9) - 0.6), h2, 0.5, 1.8, 0.9)
	# parapets: west and east full length, the south either side of the flight's arrival,
	# the north open onto the summit's approach stairs (pinnacles at its corners)
	_rail([Vector3(lo.x + 0.21, y, hi.y - 0.21), Vector3(lo.x + 0.21, y, lo.y + 0.6)])
	_rail([Vector3(hi.x - 0.21, y, hi.y - 0.21), Vector3(hi.x - 0.21, y, lo.y + 0.6)])
	_rail([Vector3(L6_X + HW - 0.21, y, hi.y - 0.21), Vector3(hi.x - 0.21, y, hi.y - 0.21)])
	k.pinnacle(KEY, Vector3(lo.x + 0.4, y, lo.y + 0.45), 0.7, 2.2, 0.7)
	k.pinnacle(KEY, Vector3(hi.x - 0.4, y, lo.y + 0.45), 0.7, 2.2, 0.7)
	_lantern(Vector3(hi.x - 0.9, y, hi.y - 0.9), true)
	_lantern(Vector3(lo.x + 0.9, y, lo.y + 2.2), false)
	_lantern(Vector3(hi.x - 0.9, y, lo.y + 2.2), false)
	# registered short of the north edge: the summit's approach stairs' collision ramp starts half a
	# tread before their foot, i.e. just inside the landing (the site audit would see it as an intruder)
	WorldLanes.register_site("rift_ward_landing", Rect2(lo + Vector2(0, 0.8), hi - lo - Vector2(0, 0.8)), y, y - 0.3, true)
	legs.append("ward landing %.1f x %.1f m top %.2f, north edge z %.2f" % [hi.x - lo.x, hi.y - lo.y, y, lo.y])


static func _apex(w: float, kk: float) -> float:
	var c := OssKit.arch_curve(w, kk, 7)
	return c[c.size() / 2].y


# --- commit -----------------------------------------------------------------------------------------

func _commit_columns(host: Node3D) -> void:
	if columns.is_empty():
		return
	var mesh: Mesh = null
	if ResourceLoader.exists(COLUMN_GLB):
		var s := (load(COLUMN_GLB) as PackedScene).instantiate()
		for n in s.find_children("*", "MeshInstance3D", true, false):
			mesh = (n as MeshInstance3D).mesh
			break
		s.free()
	if mesh == null:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.52
		cm.height = 2.0
		mesh = cm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = columns.size()
	for i in columns.size():
		mm.set_instance_transform(i, columns[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Columns"
	mmi.multimesh = mm
	mmi.material_override = OssKit.mat(HUB)
	host.add_child(mmi)


func _commit_spindle(host: Node3D) -> void:
	var sp := Basalt.commit(spin_st, host, "Spindle", "basalt", false)
	if sp:
		MeshChunks.split(sp)
		sp.queue_free()
	var body := StaticBody3D.new()
	body.name = "SpindleBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = SPIN_CORE
	cyl.height = 30.0 - BED
	cs.shape = cyl
	cs.position = Vector3(SPIN_C.x, (30.0 + BED) * 0.5, SPIN_C.y)
	body.add_child(cs)
	host.add_child(body)


func _commit_fires(host: Node3D) -> void:
	var lit := 0
	for f: Array in fires:
		var p: Vector3 = f[0]
		var flame := Vfx.emitter(Color(1.9, 0.75, 0.22), {"count": 26, "life": 0.75, "speed": Vector2(0.3, 0.9), "size": 0.2, "gravity": 2.2, "radius": 0.14, "spread": 14.0, "grow": 1.0})
		if flame:
			flame.name = "Flame"
			host.add_child(flame)
			flame.global_position = p
			flame.emitting = true
		if bool(f[1]):
			var l := OmniLight3D.new()
			l.name = "LanternLight"
			l.light_color = Color(1.0, 0.6, 0.3)
			l.light_energy = 1.6
			l.omni_range = 9.0
			l.shadow_enabled = false
			l.set_meta("light_class", "prop")
			host.add_child(l)
			l.global_position = p + Vector3.UP * 0.5
			lit += 1
	legs.append("lanterns %d (%d lit)" % [fires.size(), lit])
