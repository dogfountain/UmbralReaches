extends Node3D
## THE PIT HALL (r34 crypt; docs/r34/raid_crypt.md): the Bone Abbot's raid room, dug down from the
## charnel pit into the layout's OSSUARY_HALL reserve (local x 26..82, y -38..-6, z -124..-68; RealmLayout
## holds the world box: the Ossuary's frame, OssFrame, stands it under the Southern Downs).
## Every number in here is LOCAL (the Ossuary's own coordinates); what the world asks about (the boss,
## the tests, a body's position) goes through wat() / WC and floor_under() (world in, local inside).
## Built by the Ossuary after its own tiers, in the Ossuary's stone. No class_name: loaded by path.
##
##   CHARNEL PIT (y 4.2) ── the east gap ── the Counting Door in the bank (Ossuary: facade + cut)
##     └ THE COUNTING STAIR (CountingStair, always drawn): a scissor stair of eight flights in a shaft
##       under the bank (x 29.4..36.6, z -97.2..-87.6), 36 m down; a slit at the fifth landing looks
##       into the hall from under its vault
##         └ the raid door: a corridor through the hall's west-south-west wall, two bone grilles that
##           shut on the pull (the outer at the wall, the inner at the floor's edge)
##   THE PIT HALL (PitHall, drawn only while you are in the crypt): a 16-sided charnel rotunda, 45 m
##     wall to wall and 23 m to the oculus. Floor (y -32): an inner disc (r 10) and eight sectors
##     (r 10..18.5) over THE UNCOUNTED DEEP (y -37.5); the sectors can fall (the Abbot's third rite).
##     Round it two tiers of bone galleries (skull walls, femur stacks, candles) and the wall's niche
##     rows; three side chapels on the diagonals (NE, SE, NW) hold the Tallies' plinths; four bells
##     hang over the galleries (N, E, S, W); the great ossuary mound (r 3.6, 5.6 m) in the middle.
## Light: candle-gold (the corona over the mound, the galleries, the door) and grave-light (the
## chapels' Tallies, the deep when it opens); nothing brighter than the candles.

const Kit := preload("res://core/life/secrets/kit.gd")

## (18 Nov, Luke: the arenas 1.6x, the world reshaped round them) every radius x1.6, the centre moved 16 m south and 19 m
## west (world) so the bigger rotunda keeps the Counting Stair's shaft outside its wall and its chapels off the Well's
## rim (it stood 2 m from it); the stair foot's corridor runs in to it (from 59, -99: the old hall)
const C := Vector3(75.0, -32.0, -80.0)        ## floor centre (local)
const BOX := AABB(Vector3(30.2, -38.0, -124.8), Vector3(89.6, 32.0, 89.6))   ## the hall's volume (local)
const FLOOR_Y := -32.0
const FLOOR_R := 29.6                          ## the fighting floor (sectors' outer edge)
const INNER_R := 16.0                          ## the inner disc never falls
const WALL_R := 36.0                           ## the wall's inner face (polygon apothem)
const WALL_T := 0.5
const SIDES := 24
const WALL_TOP := -15.0
const VAULT_TOP := -8.6                        ## oculus ring (box top is -6)
const OCULUS_R := 5.1
const TIER_A := Vector3(29.6, 32.8, -30.4)     ## inner r, outer r, top y
const TIER_B := Vector3(32.8, 36.0, -27.6)
const RAIL_H := 1.1                            ## bone balustrade on tier A's lip (2.7 m from the floor)
const DEEP_Y := -37.5
const SECTORS := 8                             ## sector k spans 45k +- 22.5 degrees
const KEEP := 4                                ## the door's tongue (180 deg: the door comes in at ~186) never falls
const FALL_III := [0, 2, 5, 7]                 ## phase III: "The Floor Remembers"
const FALL_IV := [1, 3, 6]                     ## the final count
const CHAPELS := [45.0, 315.0, 225.0]          ## SE, NE, NW (deg): the Tallies' plinths
const CHAPEL_W := 6.5
const CHAPEL_BACK := 43.8
const SOCKET_R := 41.0                         ## a Tally stands here (r) in its chapel
const BELLS := [0.0, 90.0, 190.0, 270.0]       ## E, S, W, N
const BELL_R := 33.9
const BELL_Y := -20.2                          ## the bell's mouth
const MOUND_R := 3.6
const MOUND_TOP := -26.4
const GRAVE := Color(0.62, 0.8, 0.68)          ## grave-light: pale, cold, under the glow threshold
const GOLD := Color(1.0, 0.62, 0.3)
const UNDER_LAYER := 1 << 19                   ## render layer 20: buried stone the moon must not light

## The Counting Stair (a scissor stair: lane A west, lane B east, flights 9 m, landings N and S).
const TOP_Y := 4.2                             ## the pit floor
const FLIGHTS := 8
const RISE := (TOP_Y - FLOOR_Y) / FLIGHTS      ## 4.525
const SX0 := 29.8                              ## shaft interior x 29.8..35.8
const SX1 := 35.8
const LANE_A := Vector2(29.8, 32.6)
const LANE_B := Vector2(33.0, 35.8)
const ZS := -85.2                              ## flights' south end
const ZN := -94.2                              ## flights' north end
const ZS_OUT := -82.8                          ## south landings' far edge (south is +z)
const ZN_OUT := -96.6                          ## north landings' far edge
const SHAFT_T := 0.6
const ROOF_Y := 8.3
const DOOR_Z := -84.0                          ## both shaft doors (west at the top, east at the foot), mid south landing
const GLIMPSE_Z := -95.4                       ## the slit at the fifth landing

var area: Node3D
var arena: Node                                ## the Abbot's BossArena (set by the Ossuary)
var hall: Node3D                               ## PitHall (gated)
var stair: Node3D                              ## CountingStair
var sectors: Array[Node3D] = []
var fallen: Array[bool] = []                   ## the stone is gone (collider off): floor_under() reads this
var marked: Array[bool] = []                   ## the warning has begun (the stone still stands)
var bells: Array[Node3D] = []
var sockets: Array[Vector3] = []               ## the three chapel plinth tops
var deep_lights: Array[OmniLight3D] = []
var draws := 0
var built := false
var _rng := RandomNumberGenerator.new()
var _restore_t := 0.0
var _tweens: Array[Tween] = []
var _vis_t := 0.0


static var WC: Vector3 = OssFrame.w(C)             ## the floor's centre in the world


## Floor point at `deg` (0 = local east, 90 = local south), radius `r`, height `y` (local).
static func at(deg: float, r: float, y := FLOOR_Y) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(C.x + cos(a) * r, y, C.z + sin(a) * r)


## The same point in the world (`deg` is still the hall's own angle; `y` is a local height).
static func wat(deg: float, r: float, y := FLOOR_Y) -> Vector3:
	return OssFrame.w(at(deg, r, y))


## A world position's hall angle (deg, the hall's own) and distance from the floor's centre.
static func wang_of(p: Vector3) -> float:
	return ang_of(OssFrame.l(p))


static func wflat_r(p: Vector3) -> float:
	return flat_r(OssFrame.l(p))


static func ang_of(p: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(p.z - C.z, p.x - C.x)), 360.0)


static func flat_r(p: Vector3) -> float:
	return Vector2(p.x - C.x, p.z - C.z).length()


## The raid door's radial (deg): from the stair foot's east door straight at the hall's centre.
static func door_ang() -> float:
	return ang_of(Vector3(SX1 + SHAFT_T, FLOOR_Y, DOOR_Z))


static func sector_of(p: Vector3) -> int:
	return int(floor(fposmod(ang_of(p) + 22.5, 360.0) / 45.0)) % SECTORS


## Is there floor under `p` (a WORLD position, xz)? The inner disc always; a sector while it stands.
func floor_under(wp: Vector3) -> bool:
	var p := OssFrame.l(wp)
	var r := flat_r(p)
	if r <= INNER_R + 0.05:
		return true
	if r > FLOOR_R:
		return true                              # galleries, chapels, the door: never fall
	var k := sector_of(p)
	return k >= fallen.size() or not fallen[k]


func build(a: Node3D) -> void:
	area = a
	set_meta("site", "oss_pit_hall")
	_rng.seed = 34034
	var t0 := Time.get_ticks_usec()
	fallen.resize(SECTORS)
	fallen.fill(false)
	marked.resize(SECTORS)
	marked.fill(false)
	stair = Node3D.new()
	stair.name = "CountingStair"
	add_child(stair)
	hall = Node3D.new()
	hall.name = "PitHall"
	add_child(hall)
	var k := _kit()
	_stair(k)
	draws += k.commit(stair, "StairBody")
	_stair_lights()
	await area.call("slice")
	k = _kit()
	_floor_and_deep(k)
	_tiers(k)
	draws += k.commit(hall, "HallBody")
	await area.call("slice")
	k = _kit()
	_walls(k)
	_door_way(k)
	draws += k.commit(hall, "WallBody")
	await area.call("slice")
	k = _kit()
	_vault(k)
	_chapels(k)
	draws += k.commit(hall, "VaultBody")
	await area.call("slice")
	k = _kit()
	_mound(k)
	draws += k.commit(hall, "MoundBody")
	await area.call("slice")
	for i in SECTORS:
		var sk := _kit()
		var n := Node3D.new()
		n.name = "Sector%d" % i
		hall.add_child(n)
		_sector(sk, i)
		draws += sk.commit(n, "SectorBody")
		n.set_meta("home", n.position)
		sectors.append(n)
	await area.call("slice")
	_bells()
	_lights()
	_catch()
	_catch_under()
	_ambience()
	_underground()
	built = true
	print("OSSUARY pit hall %.1f ms draws=%d (r %.1f floor, %d sectors, door at %.1f deg)" % [
		(Time.get_ticks_usec() - t0) * 0.001, draws, FLOOR_R, SECTORS, door_ang()])


func _kit() -> OssKit:
	var k := OssKit.new()
	k.keep_lanes = false                         # no hub lanes down here
	k.chunk = 24.0                               # the hall is one room: a few big prop cells, not dozens
	return k


# --- the Counting Stair ----------------------------------------------------------------------

func _flight_y(i: int) -> float:
	return TOP_Y - RISE * float(i)                # floor after flight i (0 = the top)


func _stair(k: OssKit) -> void:
	var n := Metrics.steps_for(RISE)
	for i in range(1, FLIGHTS + 1):
		var lane := LANE_A if i % 2 == 1 else LANE_B
		var cx := (lane.x + lane.y) * 0.5
		var top := _flight_y(i - 1)
		var bot := _flight_y(i)
		var north := i % 2 == 1                  # odd flights run north (down), even ones south
		var lo := Vector3(cx, bot, ZN if north else ZS)
		var hi := Vector3(cx, top, ZS if north else ZN)
		k.stairs("floor", lo, hi, lane.y - lane.x, n)
		# landing at the flight's foot: both lanes (the turn)
		var z0 := ZN_OUT if north else ZS
		var z1 := ZN if north else ZS_OUT
		k.block("floor", Vector3(SX0, bot - 0.6, minf(z0, z1)), Vector3(SX1, bot, maxf(z0, z1)))
		# a tally carved on the landing's back wall: the count of flights (strokes, the fifth across)
		var wall_z := ZN_OUT + 0.02 if north else ZS_OUT - 0.02
		var face := 1.0 if north else -1.0
		for s in i:
			var sx := SX0 + 1.0 + 0.32 * float(s % 5) + 2.0 * float(s / 5)
			if s % 5 == 4:
				k.box("dark", Vector3(sx - 0.64, bot + 1.7, wall_z + face * 0.01), Vector3(1.5, 0.08, 0.02), Basis(Vector3.BACK, 0.5), false)
			else:
				k.box("dark", Vector3(sx, bot + 1.7, wall_z + face * 0.01), Vector3(0.07, 0.62, 0.02), Basis.IDENTITY, false)
		# candles on every landing, a lantern bracket on every other
		k.candle_cluster(Vector3(SX0 + 0.5, bot, (z0 + z1) * 0.5 + (0.6 if north else -0.6)), 5, 0.3, _rng)
		k.candle_cluster(Vector3(SX1 - 0.5, bot, (z0 + z1) * 0.5), 4, 0.25, _rng)
		for b in _rng.randi_range(2, 4):
			k.bone(Vector3(_rng.randf_range(SX0 + 0.4, SX1 - 0.4), bot + 0.03, (z0 + z1) * 0.5 + _rng.randf_range(-0.8, 0.8)), Basis(Vector3.UP, _rng.randf() * TAU), _rng.randi_range(0, 2), false)
		if i % 2 == 0:
			var bz := (z0 + z1) * 0.5
			k.box("iron", Vector3(SX1 - 0.25, bot + 2.3, bz), Vector3(0.5, 0.05, 0.05), Basis.IDENTITY, false)
			k.box("glow", Vector3(SX1 - 0.5, bot + 2.15, bz), Vector3(0.2, 0.28, 0.2), Basis.IDENTITY, false, 0.6)
	# the top landing (lane A only, at the pit's floor)
	k.block("floor", Vector3(LANE_A.x, TOP_Y - 0.6, ZS_OUT), Vector3(LANE_A.y, TOP_Y, ZS))
	k.candle_cluster(Vector3(LANE_A.x + 0.5, TOP_Y, ZS_OUT - 0.5), 6, 0.3, _rng)
	# under the last lane-A flight: solid (no cranny under the stair at the foot)
	k.block("stone", Vector3(LANE_A.x, FLOOR_Y - 0.6, ZN), Vector3(LANE_A.y, _flight_y(7) - 0.5, ZS), true, 0.8)
	# the spine wall between the lanes, the shaft walls, the roof
	k.block("stone", Vector3(LANE_A.y, FLOOR_Y - 0.6, ZN), Vector3(LANE_B.x, ROOF_Y, ZS), true, 0.86)
	var wx0 := SX0 - SHAFT_T
	var wx1 := SX1 + SHAFT_T
	k.block("stone", Vector3(wx0, FLOOR_Y - 0.6, ZN_OUT - SHAFT_T), Vector3(wx1, ROOF_Y, ZN_OUT))       # north
	k.block("stone", Vector3(wx0, FLOOR_Y - 0.6, ZS_OUT), Vector3(wx1, ROOF_Y, ZS_OUT + SHAFT_T))       # south
	# west wall: the Counting Door at the top (the facade outside it is the Ossuary's)
	_shaft_wall(k, wx0, SX0, [[DOOR_Z, TOP_Y, 2.0, 2.5]])
	# east wall: the raid door at the foot, the slit at the fifth landing
	_shaft_wall(k, SX1, wx1, [[DOOR_Z, FLOOR_Y, 2.4, 2.9], [GLIMPSE_Z, _flight_y(5) + 0.85, 1.3, 1.1]])
	k.block("dark", Vector3(wx0, ROOF_Y, ZN_OUT - SHAFT_T), Vector3(wx1, ROOF_Y + 0.5, ZS_OUT + SHAFT_T), true, 0.7)
	k.block("floor", Vector3(SX0, FLOOR_Y - 0.6, ZS_OUT), Vector3(SX1, FLOOR_Y, ZN_OUT), true)
	# the slit's bone grille (the hall is 14 m below it: look, do not leap)
	for j in 4:
		k.box("iron", Vector3(SX1 + SHAFT_T * 0.5, _flight_y(5) + 1.4, GLIMPSE_Z - 0.45 + 0.3 * float(j)), Vector3(0.06, 1.4, 0.06))
	k.box("iron", Vector3(SX1 + SHAFT_T * 0.5, _flight_y(5) + 1.5, GLIMPSE_Z), Vector3(0.06, 0.06, 1.3))


## A shaft wall (x0..x1) from the foot to the roof, along z ZS_OUT..ZN_OUT, with doorways:
## [[z centre, floor y, width, height]] (a pointed head on each).
func _shaft_wall(k: OssKit, x0: float, x1: float, doors: Array) -> void:
	var zlo := ZN_OUT - SHAFT_T
	var zhi := ZS_OUT + SHAFT_T
	var xm := (x0 + x1) * 0.5
	var t := x1 - x0
	# solid courses between the doors' heights, panels round each door
	var cuts: Array = doors.duplicate()
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[1]) < float(q[1]))
	var y := FLOOR_Y - 0.6
	for d: Array in cuts:
		var dz: float = d[0]
		var fy: float = d[1]
		var w: float = d[2]
		var h: float = d[3]
		var panel_top := fy + h + 1.6
		if fy > y + 0.01:
			k.block("stone", Vector3(x0, y, zlo), Vector3(x1, fy, zhi), true, 0.85)
		# beside the door, full panel height
		k.block("stone", Vector3(x0, fy, zlo), Vector3(x1, panel_top, dz - w * 0.5 - 0.6), true, 0.85)
		k.block("stone", Vector3(x0, fy, dz + w * 0.5 + 0.6), Vector3(x1, panel_top, zhi), true, 0.85)
		k.arch_panel("stone", Vector3(xm, fy, dz), Vector3.BACK, w, h - w * 0.45, panel_top - fy, t, 0.6, 0.75, 0.0, "stone")
		y = panel_top
	if y < ROOF_Y:
		k.block("stone", Vector3(x0, y, zlo), Vector3(x1, ROOF_Y, zhi), true, 0.85)


func _stair_lights() -> void:
	for i: int in [0, 2, 4, 6, 8]:
		var y := _flight_y(i)
		var north: bool = i % 2 == 1
		var z := (ZN + ZN_OUT) * 0.5 if north else (ZS + ZS_OUT) * 0.5
		_omni(stair, "Stair%d" % i, Vector3(SX1 - 1.2, y + 2.6, z), GOLD, 5.0, 10.0)


# --- the hall: floor, deep, galleries --------------------------------------------------------

func _floor_and_deep(k: OssKit) -> void:
	var n := 40
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var p0 := C + Vector3(cos(a0), 0, sin(a0)) * INNER_R
		var p1 := C + Vector3(cos(a1), 0, sin(a1)) * INNER_R
		k.quad("floor", C, p0, p1, C, Vector3.UP)
		# the inner disc's drum, bare stone down to the deep (seen when the sectors fall)
		var out := (Vector3(cos(a0), 0, sin(a0)) + Vector3(cos(a1), 0, sin(a1))).normalized()
		k.quad("stone", p0, p1, p1 + Vector3.DOWN * (FLOOR_Y - DEEP_Y), p0 + Vector3.DOWN * (FLOOR_Y - DEEP_Y), out, true, 0.75)
		# the deep's floor (ash-dark), and its outer wall under tier A's lip
		var q0 := C + Vector3(cos(a0), 0, sin(a0)) * (FLOOR_R + 0.4) + Vector3.UP * (DEEP_Y - FLOOR_Y)
		var q1 := C + Vector3(cos(a1), 0, sin(a1)) * (FLOOR_R + 0.4) + Vector3.UP * (DEEP_Y - FLOOR_Y)
		var d0 := p0 + Vector3.UP * (DEEP_Y - FLOOR_Y)
		var d1 := p1 + Vector3.UP * (DEEP_Y - FLOOR_Y)
		k.quad("dark", d0, q0, q1, d1, Vector3.UP, true, 0.9)
		k.quad("stone", q0, q1, q1 + Vector3.UP * (FLOOR_Y - DEEP_Y), q0 + Vector3.UP * (FLOOR_Y - DEEP_Y), -out, true, 0.7)
	# the band course on the drum: where the floor broke away
	for i in 24:
		var a := TAU * float(i) / 24.0
		var p := C + Vector3(cos(a), 0, sin(a)) * (INNER_R + 0.12) + Vector3.DOWN * 1.15
		k.box("stone", p, Vector3(0.3, 0.3, INNER_R * TAU / 24.0 + 0.05), Basis(Vector3.UP, -a), false, 0.9)
	# the deep: bone drifts and grave-ash where the Uncounted were tipped
	for i in 26:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(INNER_R + 1.2, FLOOR_R - 1.0)
		var p := C + Vector3(cos(a) * r, DEEP_Y - FLOOR_Y, sin(a) * r)
		_heap(k, p, _rng.randf_range(0.6, 1.3), 36)


func _heap(k: OssKit, at: Vector3, r: float, per_m := 60) -> void:
	for i in int(r * float(per_m)):
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r
		var hgt := (1.0 - d / r) * r * 0.55
		var p := at + Vector3(cos(a) * d, hgt * _rng.randf_range(0.4, 1.0) + 0.03, sin(a) * d)
		if _rng.randf() < 0.25:
			(k.skulls[_rng.randi() % 2] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.9, 1.1)), p))
		else:
			var kind := 0 if _rng.randf() < 0.45 else (1 if _rng.randf() < 0.65 else 2)
			(k.bones[kind] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.5, 0.5)), p))


## Angular openings through the galleries and the wall: [centre deg, width m].
func _openings() -> Array:
	var out: Array = [[door_ang(), 3.4]]
	for c: float in CHAPELS:
		out.append([c, CHAPEL_W])
	return out


func _open_at(deg: float, r: float, pad := 0.0) -> bool:
	for o: Array in _openings():
		var half := rad_to_deg((float(o[1]) * 0.5 + pad) / r)
		if absf(angle_difference(deg_to_rad(deg), deg_to_rad(float(o[0])))) < deg_to_rad(half):
			return true
	return false


func _skull_row(k: OssKit, r: float, y: float, a0: float, a1: float, out := true, step := 0.24, s := 1.0) -> void:
	var span := deg_to_rad(a1 - a0)
	var n := maxi(1, int(absf(span) * r / step))
	for i in n:
		var a := deg_to_rad(a0) + span * (float(i) + 0.5) / float(n)
		var p := C + Vector3(cos(a) * r, y - FLOOR_Y, sin(a) * r)
		# a skull faces -z in its own frame: turn it to face the hall's centre (or away)
		var face := Vector3(-cos(a), 0, -sin(a)) if out else Vector3(cos(a), 0, sin(a))
		var yaw := atan2(-face.x, -face.z) + _rng.randf_range(-0.12, 0.12)
		(k.skulls[(i + int(r * 10.0)) % 2] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p))


func _femur_row(k: OssKit, r: float, y: float, a0: float, a1: float) -> void:
	var span := deg_to_rad(a1 - a0)
	var n := maxi(1, int(absf(span) * r / 0.085))
	for i in n:
		var a := deg_to_rad(a0) + span * (float(i) + 0.5) / float(n)
		var p := C + Vector3(cos(a) * r, y - FLOOR_Y, sin(a) * r)
		# femur ends out of the wall: the bone's long axis (z) along the radius
		var b := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.FORWARD, _rng.randf() * TAU)
		(k.bones[0] as Array).append(Transform3D(b, p))


## The two bone galleries: tier A (the low stacks, a balustrade on its lip) and tier B (to the wall).
func _tiers(k: OssKit) -> void:
	var segs := 64
	var step := 360.0 / float(segs)
	for i in segs:
		var a0 := step * float(i)
		var am := a0 + step * 0.5
		for tier: Vector3 in [TIER_A, TIER_B]:
			if _open_at(am, tier.x, 0.2):
				continue
			var r_out := tier.y / cos(deg_to_rad(step * 0.5))
			var rm := (tier.x + r_out) * 0.5
			var len := 2.0 * r_out * tan(deg_to_rad(step * 0.5)) + 0.04
			var a := deg_to_rad(am)
			var basis := Basis(Vector3.UP, -a)            # x along the radius, z along the ring
			var c := C + Vector3(cos(a) * rm, (tier.z - FLOOR_Y) * 0.5, sin(a) * rm)
			k.box("stone", c, Vector3(r_out - tier.x, tier.z - FLOOR_Y, len), basis, true, 0.82 if tier == TIER_A else 0.78)
			# coping on the lip
			k.box("stone", C + Vector3(cos(a) * (tier.x + 0.2), tier.z - FLOOR_Y + 0.08, sin(a) * (tier.x + 0.2)), Vector3(0.5, 0.16, len * tier.x / r_out + 0.02), basis, false, 0.95)
		# tier A's lip: the bone balustrade (the floor's edge: 2.7 m, no mantle)
		if not _open_at(am, TIER_A.x, 0.2):
			var a := deg_to_rad(am)
			var len := 2.0 * TIER_A.x * tan(deg_to_rad(step * 0.5)) + 0.05
			var bc := C + Vector3(cos(a) * (TIER_A.x + 0.25), TIER_A.z - FLOOR_Y + RAIL_H * 0.5, sin(a) * (TIER_A.x + 0.25))
			k.box("stone", bc, Vector3(0.3, RAIL_H, len), Basis(Vector3.UP, -a), true, 0.9)
			if i % 2 == 0:
				k.box("stone", bc + Vector3.UP * 0.15, Vector3(0.45, RAIL_H + 0.3, 0.45), Basis(Vector3.UP, -a), true, 0.86)
	# dressing, run by run between the openings (rows of skulls on each tier's face, femur stacks,
	# a crown of skulls along the balustrade, candles on the treads)
	var runs := _runs(TIER_A.x)
	for run: Vector2 in runs:
		for y in [FLOOR_Y + 0.35, FLOOR_Y + 0.75, FLOOR_Y + 1.15]:
			_skull_row(k, TIER_A.x - 0.06, y, run.x, run.y, true, 0.25)
		_skull_row(k, TIER_A.x + 0.2, TIER_A.z + RAIL_H + 0.02, run.x, run.y, true, 0.42)
		for y in [TIER_A.z + 0.5, TIER_A.z + 1.0, TIER_A.z + 1.5, TIER_A.z + 2.0]:
			_femur_row(k, TIER_B.x - 0.03, y, run.x, run.y)
		_skull_row(k, TIER_B.x - 0.06, TIER_A.z + 2.45, run.x, run.y, true, 0.24)
		for y in [TIER_A.z + 2.75]:
			_femur_row(k, TIER_B.x - 0.03, y, run.x, run.y)
		# candles on tier A's tread and tier B's top
		var span := run.y - run.x
		for j in int(span / 9.0):
			var a := run.x + 9.0 * (float(j) + 0.5)
			k.candle_cluster(at(a, TIER_A.x + 1.2, TIER_A.z), _rng.randi_range(4, 8), 0.4, _rng)
			if j % 2 == 0:
				k.candle_cluster(at(a + 4.5, TIER_B.x + 1.0, TIER_B.z), _rng.randi_range(3, 6), 0.4, _rng)


## Arc runs (deg) of the ring at radius r between the openings.
func _runs(r: float) -> Array:
	var cuts: Array = []
	for o: Array in _openings():
		var half := rad_to_deg((float(o[1]) * 0.5 + 0.3) / r)
		cuts.append(Vector2(float(o[0]) - half, float(o[0]) + half))
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var out: Array = []
	for i in cuts.size():
		var a: Vector2 = cuts[i]
		var b: Vector2 = cuts[(i + 1) % cuts.size()]
		var end := b.x if i + 1 < cuts.size() else b.x + 360.0
		out.append(Vector2(a.y, end))
	return out


# --- the wall, the door, the vault --------------------------------------------------------------

func _side_pts(i: int, r: float) -> Array:
	var half := 180.0 / float(SIDES)
	var rv := r / cos(deg_to_rad(half))
	var a0 := 360.0 / float(SIDES) * float(i) - half
	return [at(a0, rv), at(a0 + 2.0 * half, rv)]


func _walls(k: OssKit) -> void:
	var h := WALL_TOP - FLOOR_Y
	var rc := WALL_R + WALL_T * 0.5
	for i in SIDES:
		var pts := _side_pts(i, rc)
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[1]
		var along := (b - a).normalized()
		var length := a.distance_to(b)
		var inward := (C - (a + b) * 0.5)
		inward.y = 0.0
		inward = inward.normalized()
		var ops: Array = []
		# openings through this side (the door, a chapel arch, the slit from the stair); one that
		# straddles a corner of the 16-gon (the raid door) cuts both sides back and gets a lintel
		var clip0 := 0.0
		var clip1 := length
		for o: Array in _openings():
			var oc := at(float(o[0]), rc)
			var t := (oc - a).dot(along)
			var half := float(o[1]) * 0.5
			if absf((oc - a).dot(inward)) > 1.0 or t < -half or t > length + half:
				continue
			if t - half > 0.4 and t + half < length - 0.4:
				var chapel := float(o[1]) > 4.0
				ops.append({"at": t, "w": float(o[1]), "spring": 4.4 if chapel else 3.0, "k": 0.8})
			elif t < length * 0.5:
				clip0 = maxf(clip0, t + half)
			else:
				clip1 = minf(clip1, t - half)
		if clip0 > 0.0 or clip1 < length:
			var lin := 3.6
			for e: Array in [[0.0, clip0], [clip1, length]]:
				if float(e[1]) - float(e[0]) < 0.05:
					continue
				var mid := a + along * ((float(e[0]) + float(e[1])) * 0.5)
				k.box("stone", mid + Vector3.UP * (lin + (h - lin) * 0.5), Vector3(float(e[1]) - float(e[0]) + 0.3, h - lin, WALL_T), Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized()), true, 0.9)
			for o: Dictionary in ops:
				o.at = float(o.at) - clip0
			a = a + along * clip0
			b = a + along * (clip1 - clip0)
			length = clip1 - clip0
		var glimpse := Vector3(SX1 + SHAFT_T + 0.6, FLOOR_Y, GLIMPSE_Z)
		var tg := (glimpse - a).dot(along)
		if absf(Vector2(glimpse.x - C.x, glimpse.z - C.z).angle_to(Vector2((a + b).x * 0.5 - C.x, (a + b).z * 0.5 - C.z))) < deg_to_rad(11.25) and tg > 0.5 and tg < length - 0.5:
			ops.append({"at": tg, "w": 1.3, "spring": _flight_y(5) + 1.95 - FLOOR_Y, "sill": _flight_y(5) + 0.85 - FLOOR_Y, "k": 0.75})
		# the niche rows above the galleries (skull niches; no niche across an opening)
		if ops.is_empty() or (ops.size() == 1 and float(ops[0].w) < 2.0):
			for j in 3:
				var nt := length * (float(j) + 1.0) / 4.0
				if ops.size() == 1 and absf(nt - float(ops[0].at)) < 1.6:
					continue
				ops.append({"at": nt, "w": 1.2, "spring": TIER_B.z - FLOOR_Y + 1.2, "sill": TIER_B.z - FLOOR_Y + 0.25, "niche": true, "k": 0.7})
		_wall_run(k, a, b, h, WALL_T, ops, inward)
		# the upper arcade: two tall blind lancets per side, dark, with skull shelves (a ring of
		# ghosts high in the wall), and a cornice where the vault springs
		var t := 0.12
		for j in 2:
			var lt := length * (0.3 + 0.4 * float(j))
			var skip := false
			for o: Dictionary in ops:
				if not o.get("niche", false) and absf(float(o.at) - lt) < float(o.w) * 0.5 + 1.2:
					skip = true
			if skip:
				continue
			var base := a + along * lt + inward * (WALL_T * 0.5 + t) + Vector3.UP * (h * 0.52)
			k.arch_panel("stone", base, along, 1.5, 3.4, 5.0, 0.24, 0.3, 0.8, 0.0, "stone")
			k.box("dark", base - inward * 0.12 + Vector3.UP * 2.6, Vector3(1.5, 5.0, 0.04), Basis(along, Vector3.UP, inward), false)
			for sh in 3:
				var sy := 0.6 + 1.3 * float(sh)
				k.box("stone", base + inward * 0.05 + Vector3.UP * sy, Vector3(1.5, 0.08, 0.3), Basis(along, Vector3.UP, inward), false, 0.9)
				for q in 4:
					var p := base + inward * 0.06 + along * (-0.55 + 0.37 * float(q)) + Vector3.UP * (sy + 0.04)
					(k.skulls[q % 2] as Array).append(Transform3D(Basis(Vector3.UP, atan2(-inward.x, -inward.z) + _rng.randf_range(-0.2, 0.2)), p))
		k.box("stone", a.lerp(b, 0.5) + Vector3.UP * (h - 0.2) + inward * 0.15, Vector3(length + 0.4, 0.4, WALL_T + 0.3), Basis(along, Vector3.UP, inward), false, 0.92)
	# wall shafts at the corners: from the galleries up to the vault's springing
	for i in SIDES:
		var p := at(360.0 / float(SIDES) * float(i) - 180.0 / float(SIDES), (WALL_R + 0.1) / cos(deg_to_rad(180.0 / float(SIDES))), TIER_B.z)
		var ia := deg_to_rad(360.0 / float(SIDES) * float(i) - 180.0 / float(SIDES))
		if _open_at(rad_to_deg(ia), WALL_R, 0.6):
			continue
		k.box("stone", p + Vector3.UP * ((WALL_TOP - TIER_B.z) * 0.5), Vector3(0.6, WALL_TOP - TIER_B.z, 0.6), Basis(Vector3.UP, -ia), true, 0.88)


## A wall a->b (inner face toward `inward`) with pointed openings: the Ossuary's own wall recipe
## (ossuary.gd _wall), on this builder's rng so the crypt's dressing is unchanged.
func _wall_run(k: OssKit, a: Vector3, b: Vector3, h: float, t: float, openings: Array, inward: Vector3) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := d.length()
	var along := d / length
	var nrm := along.cross(Vector3.UP).normalized()
	var bas := Basis(along, Vector3.UP, nrm)
	var cursor := 0.0
	var ops := openings.duplicate()
	ops.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.at) < float(q.at))
	for o: Dictionary in ops:
		var w: float = o.w
		var x0: float = float(o.at) - w * 0.5
		if x0 > cursor + 0.01:
			k.box("plaster", a + along * ((cursor + x0) * 0.5) + Vector3.UP * (h * 0.5), Vector3(x0 - cursor, h, t), bas)
		var base := a + along * float(o.at)
		k.arch_panel("plaster", base, along, w, float(o.spring), h, t, 0.0, float(o.get("k", 0.85)), float(o.get("sill", 0.0)), "stone")
		if o.get("niche", false):
			var back := base - inward * (t * 0.5 + 0.2)
			var top_n: float = float(o.spring) + w * 1.3
			k.box("dark", back + Vector3.UP * (top_n * 0.5), Vector3(w + 0.2, top_n, 0.15), bas)
			var sill: float = o.get("sill", 0.0)
			var shelf := base + inward * 0.2 + Vector3.UP * sill
			var face := atan2(inward.x, inward.z) + PI
			for s: float in [-0.28, 0.0, 0.28]:
				if _rng.randf() < 0.85:
					(k.skulls[_rng.randi() % 2] as Array).append(Transform3D(Basis(Vector3.UP, face + _rng.randf_range(-0.4, 0.4)), shelf + along * s * w + Vector3.UP * 0.02))
			if _rng.randf() < 0.6:
				k.candle_cluster(shelf + inward * 0.1, _rng.randi_range(2, 4), 0.16, _rng)
		cursor = float(o.at) + w * 0.5
	if cursor < length - 0.01:
		k.box("plaster", a + along * ((cursor + length) * 0.5) + Vector3.UP * (h * 0.5), Vector3(length - cursor, h, t), bas)
	k.box("stone", a + along * (length * 0.5) + Vector3.UP * 0.25, Vector3(length + 0.02, 0.5, t + 0.1), bas, false, 0.85)


## The raid door: a corridor from the stair's foot (its east door) through the wall and the
## galleries to the floor's edge, a lintel over each mouth, candles on its sills.
func _door_way(k: OssKit) -> void:
	var da := door_ang()
	var a := deg_to_rad(da)
	var radial := Vector3(-cos(a), 0, -sin(a))           # inward, toward the centre
	var side := radial.cross(Vector3.UP).normalized()
	var w := 3.4
	var r_out := flat_r(Vector3(SX1 + SHAFT_T, 0, DOOR_Z))
	var p_out := at(da, r_out)
	var p_in := at(da, TIER_A.x - 0.1)
	var mid := (p_out + p_in) * 0.5
	var length := p_out.distance_to(p_in)
	var bas := Basis(side, Vector3.UP, radial)
	k.box("floor", mid + Vector3.DOWN * 0.3, Vector3(w + 0.2, 0.6, length + 0.4), bas)
	# side walls, the corridor's roof outside the hall (it runs under the bank)
	for s: float in [-1.0, 1.0]:
		var wc := mid + side * (s * (w * 0.5 + 0.35)) + Vector3.UP * 2.4
		k.box("stone", wc, Vector3(0.7, 4.8, length), bas, true, 0.84)
	var outer_len := r_out - WALL_R
	var oc := at(da, (r_out + WALL_R) * 0.5, FLOOR_Y + 4.5)
	k.box("stone", oc, Vector3(w + 1.4, 0.6, outer_len + 0.2), bas, true, 0.8)
	# lintels and a row of skulls over the inner mouth (the threshold of the floor)
	var lin := at(da, TIER_A.x + 0.4, FLOOR_Y + 4.2)
	k.box("stone", lin, Vector3(w + 1.6, 0.7, 0.9), bas, true, 0.9)
	for j in 11:
		var p := lin + side * (-1.5 + 0.3 * float(j)) - radial * -0.48 + Vector3.UP * 0.36
		(k.skulls[j % 2] as Array).append(Transform3D(Basis(Vector3.UP, atan2(radial.x, radial.z) + PI), p))
	for s: float in [-1.0, 1.0]:
		k.candle_cluster(p_in - radial * 1.0 + side * (s * (w * 0.5 - 0.3)), 6, 0.25, _rng)
		k.candle_cluster(at(da, WALL_R - 0.5) + side * (s * (w * 0.5 - 0.3)), 5, 0.25, _rng)
		k.candelabrum(p_in + radial * 1.4 + side * (s * 2.6), 1.8, _rng)


## The vault: sixteen ribs from the wall's cornice to the oculus, dark webs between them, the
## oculus ring and the corona (an iron wheel of candles hung on chains over the mound).
func _vault(k: OssKit) -> void:
	var steps := 9
	var rise := VAULT_TOP - WALL_TOP
	var span := WALL_R - OCULUS_R
	var prof := func(t: float) -> Vector2:     # (r, y) along a rib, t 0 at the wall
		return Vector2(OCULUS_R + span * cos(t * PI * 0.5), WALL_TOP + rise * sin(t * PI * 0.5))
	var half := 180.0 / float(SIDES)
	for i in SIDES:
		var ad := 360.0 / float(SIDES) * float(i) - half
		var a := deg_to_rad(ad)
		var dir := Vector3(cos(a), 0, sin(a))
		var a2 := deg_to_rad(ad + 2.0 * half)
		var dir2 := Vector3(cos(a2), 0, sin(a2))
		for s in steps:
			var p0: Vector2 = prof.call(float(s) / float(steps))
			var p1: Vector2 = prof.call(float(s + 1) / float(steps))
			var wa := C + dir * p0.x + Vector3.UP * (p0.y - FLOOR_Y)
			var wb := C + dir * p1.x + Vector3.UP * (p1.y - FLOOR_Y)
			var seg := wb - wa
			var f := seg.normalized()
			var side := dir.cross(Vector3.UP).normalized()
			var up := f.cross(side).normalized()
			if up.y < 0.0:
				up = -up
			k.box("stone", (wa + wb) * 0.5 - up * 0.2, Vector3(0.45, 0.5, seg.length() + 0.1), Basis(side, up, f).orthonormalized(), false, 0.9)
			# the web to the next rib (two triangles as a quad), facing down into the hall
			var na := C + dir2 * p0.x + Vector3.UP * (p0.y - FLOOR_Y)
			var nb := C + dir2 * p1.x + Vector3.UP * (p1.y - FLOOR_Y)
			k.quad("plaster", wa, na, nb, wb, Vector3.DOWN + (dir + dir2) * -0.3, false, 0.42 - 0.025 * float(s))
			k.quad("dark", wa + Vector3.UP * 0.4, wb + Vector3.UP * 0.4, nb + Vector3.UP * 0.4, na + Vector3.UP * 0.4, Vector3.UP, false, 0.6)
	# oculus: a stone ring and the dark throat above it
	for i in 24:
		var a := TAU * float(i) / 24.0
		k.box("stone", C + Vector3(cos(a) * OCULUS_R, VAULT_TOP - FLOOR_Y + 0.1, sin(a) * OCULUS_R), Vector3(0.5, 0.6, OCULUS_R * TAU / 24.0 + 0.1), Basis(Vector3.UP, -a), false, 0.9)
	k.box("dark", C + Vector3.UP * (VAULT_TOP - FLOOR_Y + 1.6), Vector3(OCULUS_R * 2.0, 0.3, OCULUS_R * 2.0), Basis.IDENTITY, false, 0.4)
	# the corona: chains from the oculus, a wheel of iron, its candles
	var cy := -19.6
	var cr := 4.6
	for i in 32:
		var a := TAU * float(i) / 32.0
		k.box("iron", C + Vector3(cos(a) * cr, cy - FLOOR_Y, sin(a) * cr), Vector3(0.16, 0.12, cr * TAU / 32.0 + 0.04), Basis(Vector3.UP, -a), false, 0.8)
		if i % 2 == 0:
			var tip := C + Vector3(cos(a) * cr, cy - FLOOR_Y + 0.06, sin(a) * cr)
			(k.candles[0] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), tip))
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var lo := C + Vector3(cos(a) * cr, cy - FLOOR_Y, sin(a) * cr)
		var hi := C + Vector3(cos(a) * OCULUS_R, VAULT_TOP - FLOOR_Y, sin(a) * OCULUS_R)
		var d := hi - lo
		k.box("iron", (lo + hi) * 0.5, Vector3(0.06, d.length(), 0.06), Basis(Quaternion(Vector3.UP, d.normalized())), false)
		k.box("iron", C + Vector3(cos(a) * cr * 0.5, cy - FLOOR_Y, sin(a) * cr * 0.5), Vector3(cr, 0.08, 0.08), Basis(Vector3.UP, -a), false)
	k.skull(C + Vector3.UP * (cy - FLOOR_Y - 0.25), 0.0, 2.2, 0)


## Three chapels on the diagonals: a passage through the galleries into an apse with a plinth
## where a Tally stands (empty iron cage at rest; the Abbot raises the Tallies in his intermission).
func _chapels(k: OssKit) -> void:
	for cd: float in CHAPELS:
		var a := deg_to_rad(cd)
		var radial := Vector3(cos(a), 0, sin(a))             # outward
		var side := radial.cross(Vector3.UP).normalized()
		var bas := Basis(side, Vector3.UP, radial)
		var r0 := TIER_A.x - 0.2
		var r1 := CHAPEL_BACK
		var mid := C + radial * ((r0 + r1) * 0.5)
		var w := CHAPEL_W
		k.box("floor", mid + Vector3.DOWN * 0.3, Vector3(w + 0.4, 0.6, r1 - r0), bas)
		# side walls through the galleries and out to the apse, a back wall, a low vault
		var vh := 9.0
		for s: float in [-1.0, 1.0]:
			k.box("stone", mid + side * (s * (w * 0.5 + 0.35)) + Vector3.UP * (vh * 0.5), Vector3(0.7, vh, r1 - r0), bas, true, 0.84)
		var back := C + radial * (r1 + 0.35)
		k.box("plaster", back + Vector3.UP * (vh * 0.5), Vector3(w + 1.4, vh, 0.7), bas, true)
		# vault: a barrel of three arch rings and a roof slab outside the hall's wall
		var outer := C + radial * ((WALL_R + r1) * 0.5 + 0.4)
		k.box("dark", outer + Vector3.UP * (vh + 0.2), Vector3(w + 1.4, 0.4, r1 - WALL_R + 1.2), bas, true, 0.7)
		for rr: float in [WALL_R + 1.0, (WALL_R + r1) * 0.5 + 0.4, r1 - 0.3]:
			k.arch_panel("stone", C + radial * rr, side, w, 5.6, vh, 0.4, 0.3, 0.8, 0.0, "stone")
		# bone walls in the apse: skull rows on both sides, femur courses
		for s: float in [-1.0, 1.0]:
			for row in 5:
				var y := 0.4 + 0.42 * float(row)
				for j in int((r1 - WALL_R - 0.4) / 0.24):
					var p := C + radial * (WALL_R + 0.3 + 0.24 * float(j)) + side * (s * (w * 0.5 - 0.06)) + Vector3.UP * (y + FLOOR_Y - C.y)
					(k.skulls[(j + row) % 2] as Array).append(Transform3D(Basis(Vector3.UP, atan2(-s * side.x, -s * side.z) + PI + _rng.randf_range(-0.1, 0.1)), p))
		# the plinth (a stepped block) and its iron cage
		var sp := C + radial * SOCKET_R
		k.block("stone", sp + Vector3(-1.0, 0.0, -1.0), sp + Vector3(1.0, 0.9, 1.0))
		k.block("stone", sp + Vector3(-0.8, 0.9, -0.8), sp + Vector3(0.8, 1.15, 0.8), true, 0.9)
		for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			k.box("iron", sp + Vector3(q.x * 0.62, 1.15 + 0.9, q.y * 0.62), Vector3(0.07, 1.8, 0.07), Basis.IDENTITY, false)
		k.box("iron", sp + Vector3(0, 2.95, 0), Vector3(1.35, 0.08, 1.35), Basis.IDENTITY, false)
		k.box("glow", sp + Vector3(0, 1.3, 0), Vector3(0.28, 0.28, 0.28), Basis.IDENTITY, false, 0.25)
		sockets.append(sp + Vector3.UP * 1.15)
		k.candle_cluster(sp + radial * -1.6 + side * 1.4, 7, 0.35, _rng)
		k.candle_cluster(sp + radial * -1.6 - side * 1.4, 7, 0.35, _rng)
		k.candle_cluster(sp + Vector3.UP * 1.15 + radial * 0.5, 3, 0.15, _rng)
		_heap(k, sp + radial * -3.0 + side * 1.6, 0.7)


# --- the mound ------------------------------------------------------------------------------------

## The great ossuary mound: a drum of skull walls (2.6 m: past a jumping mantle), two stepped tiers,
## a crown of long bones; candles round its foot. The Abbot sinks into it between his phases.
func _mound(k: OssKit) -> void:
	var tiers := [[MOUND_R, FLOOR_Y, FLOOR_Y + 2.6], [2.6, FLOOR_Y + 2.6, FLOOR_Y + 3.9], [1.7, FLOOR_Y + 3.9, FLOOR_Y + 4.9], [0.9, FLOOR_Y + 4.9, MOUND_TOP]]
	var n := 24
	for t: Array in tiers:
		var r: float = t[0]
		var y0: float = t[1]
		var y1: float = t[2]
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			var p0 := Vector3(C.x + cos(a0) * r, y0, C.z + sin(a0) * r)
			var p1 := Vector3(C.x + cos(a1) * r, y0, C.z + sin(a1) * r)
			var out := (Vector3(cos(a0), 0, sin(a0)) + Vector3(cos(a1), 0, sin(a1))).normalized()
			k.quad("dark", p0, p1, p1 + Vector3.UP * (y1 - y0), p0 + Vector3.UP * (y1 - y0), out, true, 0.55)
			var cy := Vector3(C.x, y1, C.z)
			k.quad("dark", cy, p0 + Vector3.UP * (y1 - y0), p1 + Vector3.UP * (y1 - y0), cy, Vector3.UP, true, 0.5)
		# the faces: skulls in rows, facing out, staggered
		var rows := int((y1 - y0) / 0.21)
		for row in rows:
			var cnt := int(TAU * r / 0.205)
			for i in cnt:
				var a := TAU * (float(i) + 0.5 * float(row % 2)) / float(cnt)
				var p := Vector3(C.x + cos(a) * (r + 0.02), y0 + 0.03 + 0.21 * float(row), C.z + sin(a) * (r + 0.02))
				var yaw := atan2(-cos(a), -sin(a)) + _rng.randf_range(-0.15, 0.15)     # facing out
				(k.skulls[(row + i) % 2] as Array).append(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12)).scaled(Vector3.ONE * 1.05), p))
		# a femur course along each tier's top edge
		var fc := int(TAU * r / 0.09)
		for i in fc:
			var a := TAU * float(i) / float(fc)
			var p := Vector3(C.x + cos(a) * (r - 0.12), y1 + 0.03, C.z + sin(a) * (r - 0.12))
			(k.bones[0] as Array).append(Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p))
	# the crown: long bones leaning in, a reliquary socket of iron at the top
	for i in 14:
		var a := TAU * float(i) / 14.0
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -1.1)
		(k.bones[0] as Array).append(Transform3D(b.scaled(Vector3.ONE * 2.4), Vector3(C.x + cos(a) * 0.4, MOUND_TOP + 0.5, C.z + sin(a) * 0.4)))
	k.box("iron", Vector3(C.x, MOUND_TOP + 0.1, C.z), Vector3(0.9, 0.2, 0.9), Basis.IDENTITY, true)
	# candles: a ring round the foot, clusters on the tier treads
	for i in 20:
		var a := TAU * float(i) / 20.0 + 0.1
		k.candle_cluster(Vector3(C.x + cos(a) * (MOUND_R + 0.7), FLOOR_Y, C.z + sin(a) * (MOUND_R + 0.7)), _rng.randi_range(3, 6), 0.25, _rng)
	for t in [1, 2]:
		var tr: Array = tiers[t]
		var prev: Array = tiers[t - 1]
		var rr := (float(prev[0]) + float(tr[0])) * 0.5
		for i in 10:
			var a := TAU * float(i) / 10.0 + 0.3 * float(t)
			k.candle_cluster(Vector3(C.x + cos(a) * rr, float(tr[1]), C.z + sin(a) * rr), 3, 0.15, _rng)


# --- the sectors -----------------------------------------------------------------------------------

## Sector i: an annular wedge of floor (r INNER_R..FLOOR_R, 45 deg), 1 m thick, with its grave slabs.
func _sector(k: OssKit, i: int) -> void:
	var a0 := deg_to_rad(45.0 * float(i) - 22.5)
	var a1 := deg_to_rad(45.0 * float(i) + 22.5)
	var na := 6
	var radii := [INNER_R, 13.0, 16.0, FLOOR_R]
	var th := 1.0
	for j in na:
		var b0 := lerpf(a0, a1, float(j) / float(na))
		var b1 := lerpf(a0, a1, float(j + 1) / float(na))
		var d0 := Vector3(cos(b0), 0, sin(b0))
		var d1 := Vector3(cos(b1), 0, sin(b1))
		for q in radii.size() - 1:
			var r0: float = radii[q]
			var r1: float = radii[q + 1]
			k.quad("floor", C + d0 * r0, C + d1 * r0, C + d1 * r1, C + d0 * r1, Vector3.UP, true, 0.96 + 0.04 * float((j + q) % 2))
			k.quad("stone", C + d0 * r0 + Vector3.DOWN * th, C + d0 * r1 + Vector3.DOWN * th, C + d1 * r1 + Vector3.DOWN * th, C + d1 * r0 + Vector3.DOWN * th, Vector3.DOWN, false, 0.6)
		# rim faces, inner and outer (seen when it falls)
		var o := (d0 + d1).normalized()
		k.quad("stone", C + d0 * FLOOR_R, C + d1 * FLOOR_R, C + d1 * FLOOR_R + Vector3.DOWN * th, C + d0 * FLOOR_R + Vector3.DOWN * th, o, false, 0.7)
		k.quad("stone", C + d0 * INNER_R, C + d1 * INNER_R, C + d1 * INNER_R + Vector3.DOWN * th, C + d0 * INNER_R + Vector3.DOWN * th, -o, false, 0.7)
	for e: float in [a0, a1]:
		var d := Vector3(cos(e), 0, sin(e))
		var nrm := d.cross(Vector3.UP) * (1.0 if e == a0 else -1.0)
		k.quad("stone", C + d * INNER_R, C + d * FLOOR_R, C + d * FLOOR_R + Vector3.DOWN * th, C + d * INNER_R + Vector3.DOWN * th, nrm, false, 0.7)
		# the seam between sectors: a dark joint the eye can follow (where it will break)
		k.box("dark", C + d * ((INNER_R + FLOOR_R) * 0.5) + Vector3.UP * 0.006, Vector3(FLOOR_R - INNER_R, 0.012, 0.09), Basis(Vector3.UP, -e), false, 0.6)
	# grave slabs set in the floor, numbered with tally strokes (the Abbot's count)
	var am := (a0 + a1) * 0.5
	for g in 3:
		var ga := am + (float(g) - 1.0) * 0.26
		var gr := 14.2 + (0.9 if g == 1 else 0.0)
		var gp := C + Vector3(cos(ga) * gr, 0.012, sin(ga) * gr)
		var gb := Basis(Vector3.UP, -ga)
		k.box("stone", gp, Vector3(2.0, 0.024, 1.0), gb, false, 0.72)
		k.box("stone", gp + Vector3.UP * 0.008, Vector3(1.8, 0.012, 0.84), gb, false, 0.95)
		for s in (i + g) % 5 + 1:
			k.box("dark", gp + Vector3.UP * 0.016 + gb.z * (-0.3 + 0.15 * float(s)), Vector3(0.5, 0.008, 0.05), gb, false)


## Phase III / IV: sector i shakes for `warn` seconds, then drops into the deep. Returns false if it
## had already fallen (or never falls).
func collapse(i: int, warn: float) -> bool:
	if i < 0 or i >= sectors.size() or i == KEEP or marked[i]:
		return false
	marked[i] = true                                 # the stone stands through the shake; floor_under() flips when it goes
	var n := sectors[i]
	var am := deg_to_rad(45.0 * float(i))
	var mid := OssFrame.w(C + Vector3(cos(am) * 14.2, 0.1, sin(am) * 14.2))      # (the effects are the world's)
	# the paint is the slice that will drop: a wedge from the hall's centre out to the floor's edge
	var dir := OssFrame.wd(Vector3(cos(am), 0.0, sin(am)))
	SpellFx.danger(WC, warn, {"radius": FLOOR_R, "half_angle": deg_to_rad(22.5), "yaw": atan2(-dir.x, -dir.z), "color": BossKit.BONE})
	Sfx.play_stream(BossKit.Synth.get_stream("stagger"), mid, 4.0, 0.35)
	Kit.play("grind", mid, 4.0, 0.6)
	var home: Vector3 = n.get_meta("home", Vector3.ZERO)
	var tw := n.create_tween()
	_tweens.append(tw)
	var shakes := int(warn / 0.12)
	for s in shakes:
		var amp := 0.02 + 0.07 * float(s) / float(maxi(shakes, 1))
		tw.tween_property(n, "position", home + Vector3(randf_range(-amp, amp), randf_range(-amp, amp) * 0.5, randf_range(-amp, amp)), 0.12)
	tw.tween_callback(func() -> void:
		fallen[i] = true
		_set_solid(n, false)
		Vfx.burst(mid + Vector3.UP * 0.4, Color(0.16, 0.14, 0.13, 0.9), {"count": 60, "life": 1.6, "speed": Vector2(1.0, 4.0), "size": 0.6, "gravity": 1.5, "radius": 4.0, "additive": false, "turbulence": true})
		Sfx.play_stream(BossKit.Synth.get_stream("bone"), mid, 6.0, 0.4)
		_deep_light(true))
	tw.tween_property(n, "position", home + Vector3(cos(am) * 0.6, DEEP_Y - FLOOR_Y - 1.2, sin(am) * 0.6), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "rotation", Vector3(randf_range(-0.12, 0.12), 0.0, randf_range(-0.12, 0.12)), 0.9)
	tw.tween_callback(func() -> void:
		n.visible = false
		Vfx.burst(mid + Vector3.DOWN * 5.0, Color(0.85, 0.8, 0.7), {"count": 50, "life": 0.9, "speed": Vector2(2.0, 6.0), "size": 0.07, "gravity": -9.0, "additive": false}))
	return true


# --- BossArena room hooks (r34 raids: room_begin / room_reset / room_won) -------------------------

func room_begin(_boss: Node) -> void:
	_deep_light(false)


func room_reset() -> void:
	restore()


func room_won() -> void:
	restore()


func fallen_count() -> int:
	var c := 0
	for f in marked:
		if f:
			c += 1
	return c


## Every sector back where it was (an arena reset, the kill, a reload).
func restore() -> void:
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	for i in sectors.size():
		var n := sectors[i]
		if fallen[i] or marked[i] or not n.visible or n.position != n.get_meta("home", n.position):
			n.position = n.get_meta("home", Vector3.ZERO)
			n.rotation = Vector3.ZERO
			n.visible = true
			_set_solid(n, true)
		fallen[i] = false
		marked[i] = false
	_deep_light(false)


func _set_solid(n: Node, on: bool) -> void:
	for b in n.find_children("*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = Layers.WORLD if on else 0
		(b as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _deep_light(on: bool) -> void:
	for l in deep_lights:
		l.visible = on


# --- bells -------------------------------------------------------------------------------------------

static var _bell_mesh: ArrayMesh
static var _bronze: StandardMaterial3D


static func bell_mesh() -> ArrayMesh:
	if _bell_mesh == null:
		# a lathe: crown, shoulder, waist, the flared lip (radius, y) from the top
		var prof := [Vector2(0.0, 0.0), Vector2(0.42, 0.0), Vector2(0.55, -0.12), Vector2(0.62, -0.5), Vector2(0.66, -0.95), Vector2(0.8, -1.35), Vector2(1.05, -1.62), Vector2(1.12, -1.72), Vector2(0.98, -1.74), Vector2(0.88, -1.6)]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 20
		for i in prof.size() - 1:
			var p0: Vector2 = prof[i]
			var p1: Vector2 = prof[i + 1]
			for j in n:
				var a0 := TAU * float(j) / float(n)
				var a1 := TAU * float(j + 1) / float(n)
				var v := [Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x), Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x), Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x), Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)]
				var nrm := ((v[1] as Vector3) - (v[0] as Vector3)).cross((v[3] as Vector3) - (v[0] as Vector3)).normalized()
				if nrm == Vector3.ZERO:
					nrm = Vector3.UP
				for q: int in [0, 2, 1, 0, 3, 2]:
					st.set_normal(-nrm)
					st.add_vertex(v[q])
		st.generate_normals()
		_bell_mesh = st.commit()
		_bronze = StandardMaterial3D.new()
		_bronze.albedo_color = Color(0.36, 0.26, 0.15)
		_bronze.metallic = 0.85
		_bronze.roughness = 0.42
		_bronze.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _bell_mesh


func _bells() -> void:
	var mesh := bell_mesh()
	var iron := OssKit.mat("iron")
	for bd: float in BELLS:
		var a := deg_to_rad(bd)
		var radial := Vector3(cos(a), 0, sin(a))
		var pivot := Node3D.new()
		pivot.name = "Bell%d" % int(bd)
		hall.add_child(pivot)
		pivot.position = C + radial * BELL_R + Vector3.UP * (BELL_Y + 1.9 - FLOOR_Y)
		pivot.set_meta("deg", bd)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _bronze
		mi.position = Vector3(0, -0.15, 0)
		pivot.add_child(mi)
		# the clapper and the yoke (a beam out from the wall on two brackets)
		var cl := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 0.16
		cm.height = 0.32
		cl.mesh = cm
		cl.material_override = iron
		cl.position = Vector3(0, -1.55, 0)
		pivot.add_child(cl)
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.24, 0.24, WALL_R - BELL_R + 0.6)
		beam.mesh = bm
		beam.material_override = iron
		hall.add_child(beam)
		beam.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5), C + radial * ((WALL_R + BELL_R) * 0.5 + 0.2) + Vector3.UP * (BELL_Y + 2.0 - FLOOR_Y))
		bells.append(pivot)


## Ring bell `i` (index into BELLS): it swings and booms. Visual and sound only.
func toll(i: int, swings := 3) -> void:
	if i < 0 or i >= bells.size():
		return
	var b := bells[i]
	var bd: float = b.get_meta("deg", 0.0)
	var axis := Vector3(cos(deg_to_rad(bd)), 0, sin(deg_to_rad(bd))).cross(Vector3.UP).normalized()
	var tw := b.create_tween()
	for s in swings:
		var amp := 0.42 * (1.0 - 0.18 * float(s))
		tw.tween_property(b, "quaternion", Quaternion(axis, amp), 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "quaternion", Quaternion(axis, -amp), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "quaternion", Quaternion.IDENTITY, 0.6).set_trans(Tween.TRANS_SINE)
	Kit.play("bell_great", b.global_position, 6.0, 0.72)
	Vfx.light(b.global_position + Vector3.DOWN * 1.0, Color(GOLD.r * 0.6, GOLD.g * 0.6, GOLD.b * 0.6), 2.4, 10.0, 0.8)


func bell_at(i: int) -> Vector3:
	return bells[i].global_position if i >= 0 and i < bells.size() else WC


# --- light, the deep's catch, sound, the moon ----------------------------------------------------

func _lights() -> void:
	# candle-gold carries the room: the corona over the mound, a lamp over each gallery bay, the
	# candles round the mound's foot; grave-light only in the chapels (and the deep when it opens)
	# (map audit: the room grew 1.6x on 18 Nov but its lamps did not -- the gallery lamps hung over the fighting floor at
	# the old 17.4 m and the corona's 19 m died 17 m short of the wall, so the hall read pitch black from its own door. Every
	# lamp's place and reach x1.6 with the room; the same seven lamps, no shadows)
	# (19 Nov, the visual pass) the floor between the mound and the galleries was black: the gallery lamps' pools ended at
	# the balustrade and the corona's was spent on the vault. The same lamps (the candles on the treads, the corona's wheel)
	# reach the fighting floor now: the bays' pools 13.5 m and a little brighter, the corona a third stronger, the mound's
	# candle ring out to 9 m. No new lights.
	_omni(hall, "Corona", C + Vector3.UP * 18.0, GOLD, 4.0, 31.0, 0.3)      # ends at the wall: the path outside is the night
	_omni(hall, "MoundFoot", C + Vector3.UP * 1.4, GOLD, 3.0, 9.0, 0.8)
	for i in 8:
		var a := 22.5 + 45.0 * float(i)
		_omni(hall, "Gallery%d" % i, at(a, 27.4, FLOOR_Y + 4.0), GOLD, 2.6, 13.5, 0.6)           # a lamp local to its bay
	for j in sockets.size():
		_omni(hall, "Tally%d" % j, sockets[j] + Vector3.UP * 1.8, GRAVE, 1.8, 5.0)
	_omni(hall, "Door", at(door_ang(), WALL_R - 0.5, FLOOR_Y + 3.2), GOLD, 3.0, 5.5)
	for i in 4:
		var a := 45.0 + 90.0 * float(i)
		var l := _omni(hall, "Deep%d" % i, at(a, 22.4, DEEP_Y + 1.2), GRAVE, 3.0, 12.0)
		deep_lights.append(l)
		l.visible = false


## `att`: the falloff (1 is the policy's; a hall this size wants a flatter one for its big lamps).
func _omni(parent: Node3D, n: String, p: Vector3, col: Color, e: float, r: float, att := 1.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.light_color = col
	l.omni_range = r
	l.light_energy = e
	l.shadow_enabled = false
	l.set_meta(&"light_class", "fill")
	l.set_meta(&"base", {"e": e, "r": r, "a": 1.0})
	l.set_meta(&"ld_prio", 0.35)                # the hall's own lamps before its candles (LightDirector's budget)
	parent.add_child(l)
	l.position = p
	LightPolicy.apply_fade(l)
	LightPolicy.apply_illumination(l)
	l.omni_attenuation *= att
	l.shadow_enabled = false
	return l


## What falls into the deep: the wanderer is thrown back up onto the inner disc (a Gloom cost, like
## the lava's), the dead stay down, the Abbot is set back on his floor.
func _catch() -> void:
	var ar := Area3D.new()
	ar.name = "DeepCatch"
	ar.collision_layer = 0
	ar.collision_mask = Layers.PLAYER | Layers.HURTBOX
	ar.monitorable = false
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = FLOOR_R + 0.6
	cyl.height = 3.4
	cs.shape = cyl
	ar.add_child(cs)
	hall.add_child(ar)
	ar.position = Vector3(C.x, DEEP_Y + 1.6, C.z)
	ar.body_entered.connect(_on_caught)


## Under the fighting floor outside the deep (map audit MA1: in a combat strip the wanderer was 37 m out at 1.5 m under the
## floor's level and fell to y -58 for the rest of the fight; the wall and floor rays find no gap, so whatever let him
## through, under the floor is never a place to be): a band under the whole hall's footprint, from just under the floor to
## the bottom of the hall's box, sends him back up onto the inner disc as the deep does. The deep's own catch keeps its circle.
func _catch_under() -> void:
	var ar := Area3D.new()
	ar.name = "UnderCatch"
	ar.collision_layer = 0
	ar.collision_mask = Layers.PLAYER
	ar.monitorable = false
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	var top := FLOOR_Y - 1.3
	var bottom := BOX.position.y - 30.0
	bx.size = Vector3(BOX.size.x + 6.0, top - bottom, BOX.size.z + 6.0)
	cs.shape = bx
	ar.add_child(cs)
	hall.add_child(ar)
	ar.position = Vector3(C.x, (top + bottom) * 0.5, C.z)
	ar.body_entered.connect(func(body: Node3D) -> void:
		if wflat_r(body.global_position) < FLOOR_R + 0.6 and OssFrame.l(body.global_position).y > DEEP_Y - 1.0:
			return                                         # in the deep: its own catch
		_on_caught(body))


func _on_caught(body: Node3D) -> void:
	if wflat_r(body.global_position) < INNER_R - 0.2:
		return
	var a := deg_to_rad(wang_of(body.global_position))
	var back := OssFrame.w(Vector3(C.x + cos(a) * (INNER_R - 1.4), FLOOR_Y + 0.15, C.z + sin(a) * (INNER_R - 1.4)))
	if body.is_in_group(Groups.PLAYER):
		var p := body as Player
		if p == null:
			return
		p.call_deferred("teleport", back)
		p.add_wounds(18.0)                       # r35: the push-back wounds (Gloom is the dark's alone)
		Events.player_hurt.emit(18.0, body.global_position)
		SpellFx.rift_in(back)
		HitText.pop(back + Vector3.UP * 2.2, "the dead push you back up: the plate steps", GRAVE, true)
	elif body is Enemy:
		var e := body as Enemy
		if e.boss:
			e.set_deferred("global_position", back)
			e.velocity = Vector3.ZERO
		elif e.is_alive():
			e.set_meta(&"test_no_floor", true)
			e.marks = maxi(e.marks, 1)                 # an Ossuant does not knit down there
			e.take_hit(999.0, null)


## The hall is a room for the ambience (the crypt's reverb and muffle, no rain): a second, bodiless
## Area with the Ossuary's "ossuary" bed over the hall and the stair.
func _ambience() -> void:
	var amb := Area.new()
	amb.name = "HallAmbience"
	amb.ambience = "ossuary"
	amb.ambience_bounds = BOX                        # local: the Area converts the listener into the Ossuary's frame
	add_child(amb)
	var up := Area.new()                             # the stair above the hall box (under the bank)
	up.name = "StairAmbience"
	up.ambience = "ossuary"
	up.ambience_bounds = AABB(Vector3(SX0 - SHAFT_T, -6.0, ZN_OUT - SHAFT_T), Vector3(SX1 - SX0 + 2.0 * SHAFT_T, ROOF_Y + 6.0, ZS_OUT - ZN_OUT + 2.0 * SHAFT_T))
	add_child(up)


## Buried stone takes no moonlight (the moon's shadow reaches ~25 m; the hall is 30 m under the
## fen): its meshes go on render layer 20, which the moon is told to skip. The lamps light all layers.
func _underground() -> void:
	for gi in hall.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).layers = UNDER_LAYER
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for gi in stair.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		var box: AABB = g.global_transform * g.get_aabb()
		if box.end.y - OssFrame.ORIGIN.y < TOP_Y - 1.0 or g is MultiMeshInstance3D:
			g.layers = UNDER_LAYER
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tell_moon()


var _moons: Array[DirectionalLight3D] = []


## (re-checked with the visibility tick: a night rebuilt, or a moon made after the hall)
func _tell_moon() -> void:
	if not is_inside_tree():
		return
	if _moons.is_empty() or not is_instance_valid(_moons[0]):
		_moons.clear()
		for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			_moons.append(n as DirectionalLight3D)
	for m in _moons:
		if is_instance_valid(m) and m.light_cull_mask & UNDER_LAYER:
			m.light_cull_mask &= ~UNDER_LAYER


func _physics_process(delta: float) -> void:
	if not built:
		return
	_vis_t -= delta
	if _vis_t <= 0.0:
		_vis_t = 0.3
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		var cam := get_viewport().get_camera_3d()
		var want := false
		for q: Node3D in [p, cam]:
			if q == null:
				continue
			var lq := OssFrame.l(q.global_position)         # (local: the hall's own frame)
			if lq.x > 2.0 and lq.x < 86.0 and lq.z > -128.0 and lq.z < -20.0 and lq.y < 11.0:
				want = true
		if hall.visible != want:
			hall.visible = want
		_tell_moon()
	# the floor comes back whenever no fight holds it (a reset, the kill, a Hollowing)
	_restore_t -= delta
	if _restore_t <= 0.0:
		_restore_t = 0.5
		if fallen_count() > 0 and (arena == null or not bool(arena.get("_active"))):
			restore()
