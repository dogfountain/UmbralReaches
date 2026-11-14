class_name Ossuary
extends Area
## The Ossuary: the Waiting Field's charnel house (docs/ZONE_PLAN.md §2.1; relocated , Luke 14 Nov: it
## hung on the rift's east wall beside the stair boss; "all bosses are on the top of the map"). A candlelit
## burial monastery stepping down the wall of a QUARRIED BONE PIT cut into the field's south slope, the
## tiers hanging on masonry piers over a dark still pool. The pit is cut by the terrain
## (RealmLayout.oss_pit_shape); the tiers stand above its bed.
##
## Everything here is built in the Ossuary's own (local) coordinates, the ones it was designed in, and the
## node carries the frame (OssFrame: a quarter turn, so the way down the terraces runs east, the bank is
## the field's rising south). Only what meets the world converts (OssFrame.w, OssWorld).
##
##   the Pilgrims' Landing (OssFrame.LANDING; world (-40, 147.5): the lane from south_track ends here)
##     └ the bone bridge (21 m over the pool) ─ GATE HALL (y 12.6, brazier, bell tower)
##         └ north stair ─ NICHE GALLERY (y 8.4, two aisles, skull niches; the bone portcullis)
##             └ north stair ─ CHARNEL PIT (y 4.2, round, cantilevered)
##                 └ CHAPEL (y 4.2): the sexton's slab ─ THE LOWER COUNT (oss_deep.gd): cells under
##                   the chapel, the Count Drum under the pit, the Weighing Floor, the hoard, and a
##                   counterweight cage back up to the gallery's west arcade
##                 └ the Counting Door in the east bank ─ THE COUNTING STAIR, eight flights down under
##                   the bank ─ the raid door ─ THE PIT HALL (oss_hall.gd, y -32): the Bone Abbot's raid
##                   room (docs//raid_crypt.md), under the Southern Downs

const HALL_Y := 12.6
const GAL_Y := 8.4
const PIT_Y := 4.2
const PIT_C := Vector3(16.0, PIT_Y, -86.0)
const PIT_R := 11.0               ## widened from 8 m: the crypt is the Bone Abbot's arena
const LAVA_Y := OssFrame.FLOOR_Y + 0.1   ## the pit's bed: the piers' feet (it was the chasm's lava)
const PIT_WALL := 1.3           ## parapet height round the pit (was 0.8, vaultable into the pool)
const PLINTH_A := 2.05          ## spitter plinths, off the entry (1.0 rad), lift (π) and chapel (-π/2) lanes
const PLINTH_B := 5.55
const OssDeep := preload("res://world/areas/ossuary/oss_deep.gd")
const OssHall := preload("res://world/areas/ossuary/oss_hall.gd")   ## r34 crypt
const COUNT_DOOR_X := 29.2                      ## r34 crypt: the Counting Door's face (the stair shaft's west wall)
const BRIDGE_X0 := -4.0                         ## the bone bridge: from the landing (x -4) to the gate hall's west wall (x 18)

var _rng := RandomNumberGenerator.new()
var _draws := 0
## the volume the tiers fill (local): the title card, the quarry's cliff and the tiers
const BOUNDS := AABB(Vector3(-6.0, -20.0, -112.0), Vector3(40.0, 48.0, 100.0))


func _init() -> void:
	title = "OSSUARY"
	subtitle = "where the faithful wait in rows"
	ambience = "ossuary"
	position = OssFrame.ORIGIN            # the frame: every builder below keeps its own coordinates
	rotation.y = OssFrame.YAW
	# the tiers themselves (not the bridge): from the gate hall door down to the chapel (local)
	ambience_bounds = AABB(Vector3(10.0, -4.0, -106.0), Vector3(22.0, 30.0, 82.0))


func build() -> void:
	_rng.seed = 3117
	var t0 := Time.get_ticks_usec()
	var k := OssKit.new()
	k.always_lanes = true                         # r34 crypt: the same clutter on every night (rebuild drift)
	# time-sliced: the full build is ~0.3-0.8 s of GDScript, so yield a frame between the big
	# sections instead of stalling one frame (geometry appears at commit, after the last slice)
	_bridge(k)
	_landing(k)
	await slice()
	_gate_hall(k)
	await slice()
	_stair_down(k, Vector3(23.0, GAL_Y, -49.0), Vector3(23.0, HALL_Y, -38.0))
	k.block("floor", Vector3(21.0, GAL_Y - 0.6, -51.2), Vector3(25.0, GAL_Y, -49.0))
	_gallery(k)
	await slice()
	_stair_down(k, Vector3(21.0, PIT_Y, -78.0), Vector3(21.0, GAL_Y, -67.0))
	_pit(k)
	await slice()
	_chapel(k)
	_draws = k.commit(self)
	# r34 crypt: the Counting Door is its own structure (site oss_count_door: the audit and the cut)
	var door_host := Node3D.new()
	door_host.name = "CountDoor"
	door_host.set_meta("site", "oss_count_door")
	add_child(door_host)
	var dk := OssKit.new()
	dk.keep_lanes = false
	_counting_door(dk)
	_draws += dk.commit(door_host, "CountDoorBody")
	_lights()
	_pool()
	_spawns()
	# r34 crypt: the Counting Stair and the pit hall under the bank, then the Abbot's arena in it
	var hall: Node3D = OssHall.new()
	hall.name = "Crypt"
	add_child(hall)
	await hall.call("build", self)
	_crypt(hall)
	# the Lower Count (r28): its own node, built over the next frames
	if not "--no-r28-secrets" in OS.get_cmdline_user_args():     # A/B switch for perf measurements
		var deep: Node3D = OssDeep.new()
		deep.name = "LowerCount"
		add_child(deep)
		await deep.call("build", self)
	if Realm.module_on("bosses"):
		_count_cut()                            # the Counting Door's walled cut (waits for the Realm's ground)
	# the benchmark stands (world coordinates)
	perf_points = [
		{"name": "ossuary_bridge", "at": OssFrame.w(Vector3(-2.0, HALL_Y + 0.1, -34.0)), "yaw": OssFrame.wyaw(-PI * 0.5)},
		{"name": "ossuary_gallery", "at": OssFrame.w(Vector3(22.0, GAL_Y + 0.1, -52.5)), "yaw": OssFrame.wyaw(0.0)},
		{"name": "ossuary_pit", "at": OssFrame.w(Vector3(20.5, PIT_Y + 0.1, -79.5)), "yaw": OssFrame.wyaw(0.5)},
		{"name": "ossuary_count", "at": OssFrame.w(Vector3(18.0, -1.9, -91.0)), "yaw": OssFrame.wyaw(0.0)},       # the Lower Count: drum, arms, hoard
		{"name": "ossuary_hall", "at": OssHall.wat(OssHall.door_ang(), 17.0, OssHall.FLOOR_Y + 0.1), "yaw": deg_to_rad(-OssHall.door_ang() - 90.0) + OssFrame.YAW},   # the pit hall from its door
	]
	print("OSSUARY build %.1f ms draws=%d col_tris=%d candles=%d skulls=%d" % [
		(Time.get_ticks_usec() - t0) * 0.001, _draws, k.col_faces.size() / 3, k.candle_count(), k.skull_count()])
	print("OSSUARY props bones=%d rejected_for_clipping=%d" % [k.bone_count(), k.rejected])


func _physics_process(_d: float) -> void:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	announce_if_inside(p, BOUNDS)
	announce_if_inside(p, OssHall.BOX)                  # the pit hall is the Ossuary's second box (local)


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
func _wall(k: OssKit, key: String, a: Vector3, b: Vector3, h: float, t: float, openings: Array, inward := Vector3.ZERO, ring := "stone", plinth := true) -> void:
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
			if plinth:
				k.box("stone", a + along * ((cursor + x0) * 0.5) + Vector3.UP * 0.2, Vector3(x0 - cursor, 0.4, t + 0.24), bas, false, 0.85)
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
			var face := atan2(inward.x, inward.z) + PI
			for s: float in [-0.28, 0.0, 0.28]:
				if _rng.randf() < 0.8:
					k.skull(shelf + along * s * w + Vector3.UP * 0.02, face + _rng.randf_range(-0.4, 0.4), _rng.randf_range(0.9, 1.15))
			if _rng.randf() < 0.55:                  # a second skull stacked on top
				k.skull(shelf + along * _rng.randf_range(-0.15, 0.15) * w + Vector3.UP * 0.2, face + _rng.randf_range(-0.5, 0.5), 0.95, 1)
			if _rng.randf() < 0.6:
				k.candle_cluster(shelf + inward * 0.1, _rng.randi_range(2, 5), 0.18, _rng)
			for j in _rng.randi_range(1, 3):
				k.bone(shelf + along * _rng.randf_range(-0.3, 0.3) * w + inward * 0.12 + Vector3.UP * 0.03, Basis(Vector3.UP, atan2(along.x, along.z) + _rng.randf_range(-0.3, 0.3)), _rng.randi_range(0, 2), false)
		cursor = float(o.at) + w * 0.5
	if cursor < length - 0.01:
		var mid := a + along * ((cursor + length) * 0.5) + Vector3.UP * (h * 0.5)
		k.box(key, mid, Vector3(length - cursor, h, t), bas)
		if plinth:
			k.box("stone", a + along * ((cursor + length) * 0.5) + Vector3.UP * 0.2, Vector3(length - cursor, 0.4, t + 0.24), bas, false, 0.85)
	# cornice band along the whole top, a string course at two-thirds
	k.box("stone", a + along * (length * 0.5) + Vector3.UP * (h - 0.15), Vector3(length + 0.3, 0.3, t + 0.36), bas, false, 0.9)
	if h > 4.5:
		k.box("stone", a + along * (length * 0.5) + Vector3.UP * (h * 0.66), Vector3(length, 0.14, t + 0.14), bas, false, 0.88)


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
	var up := side.cross(f).normalized()
	if up.y < 0.0:
		up = -up
	for i in 5:
		for s: float in [-1.0, 1.0]:
			if (i + int(s > 0.0)) % 2 == 0:
				k.candle_cluster(lo.lerp(hi, 0.1 + 0.2 * float(i)) + side * (s * 1.85) + up * 1.1, 3, 0.08, _rng)
	# stair hall: newel pinnacles at the head and foot, an iron lantern bracket at the head
	for end: Vector3 in [lo, hi]:
		for s: float in [-1.0, 1.0]:
			k.pinnacle("stone", end + side * (s * 1.85) + Vector3.DOWN * 0.05, 0.55, 1.45, 0.6)
	for s: float in [-1.0, 1.0]:
		var b := hi + side * (s * 1.85) + Vector3.UP * 1.45
		k.box("iron", b + side * (s * 0.3) + Vector3.UP * 0.35, Vector3(0.05, 0.05, 0.6), Basis(side, Vector3.UP, dir), false)
		k.box("iron", b + Vector3.UP * 0.1, Vector3(0.05, 0.6, 0.05), Basis.IDENTITY, false)
		k.box("glow", b + side * (s * 0.3) + Vector3.UP * 0.1 + dir * 0.25, Vector3(0.18, 0.26, 0.18), Basis.IDENTITY, false, 0.6)


# --- bridge -------------------------------------------------------------------------------

static var _plate: ArrayMesh
static var _ribs: Array[ArrayMesh] = []
static var _great_rib: ArrayMesh


## One fused vertebral plate of the bridge deck: crown flush with the walking surface (y 0),
## a keel underneath, transverse bulges at the rails.
static func _plate_mesh() -> ArrayMesh:
	if _plate == null:
		var cm := CreatureMesh.new(301)
		cm.blob(Vector3(0, -0.19, 0), Vector3(0.31, 0.19, 1.52), Basis.IDENTITY, Color.WHITE, 0.25, 0.05, 0.0, 6, 12)
		cm.blob(Vector3(0, -0.5, 0), Vector3(0.2, 0.28, 0.42), Basis.IDENTITY, Color(0.9, 0.86, 0.8), 0.3, 0.07, 0.0, 5, 8)
		for s: float in [-1.0, 1.0]:
			cm.blob(Vector3(0, -0.2, s * 1.32), Vector3(0.24, 0.17, 0.32), Basis.IDENTITY, Color.WHITE, 0.3, 0.06, 0.0, 4, 8)
			cm.blob(Vector3(0, -0.3, s * 0.7), Vector3(0.12, 0.08, 0.5), Basis.IDENTITY, Color(0.85, 0.8, 0.74), 0.2, 0.05, 0.0, 3, 6)
		_plate = cm.commit()
	return _plate


## Rail rib, rising from the deck edge, bowing outward (+z for side 1) and hooking back in.
static func _rib_mesh(side: int) -> ArrayMesh:
	if _ribs.is_empty():
		for sd: float in [-1.0, 1.0]:
			var cm := CreatureMesh.new(310 + int(sd))
			cm.tube(PackedVector3Array([Vector3(0, -0.15, 0), Vector3(0, 0.3, sd * 0.16), Vector3(0, 0.75, sd * 0.22), Vector3(0, 1.08, sd * 0.08), Vector3(0, 1.2, -sd * 0.1)]),
				PackedFloat32Array([0.085, 0.07, 0.055, 0.04, 0.025]), 7, Color.WHITE, 0.4, 0.05, 0.0, Vector2(1.0, 0.7))
			_ribs.append(cm.commit())
	return _ribs[0 if side < 0 else 1]


## The great rib that once carried the missing span: rises from the lava, snapped off.
static func _great_rib_mesh(top: float) -> ArrayMesh:
	if _great_rib == null:
		var cm := CreatureMesh.new(320)
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for i in 8:
			var t := float(i) / 7.0
			pts.append(Vector3(sin(t * 2.2) * 1.2, t * top, 0.0))
			rad.append(lerpf(0.5, 0.22, t))
		cm.tube(pts, rad, 9, Color.WHITE, 0.4, 0.08)
		cm.blob(pts[7], Vector3(0.26, 0.18, 0.26), Basis.IDENTITY, Color(0.8, 0.75, 0.68), 0.3, 0.35, 0.0, 4, 7)   # splintered end
		_great_rib = cm.commit()
	return _great_rib


func _bridge(k: OssKit) -> void:
	var z := -34.0
	var y := HALL_Y
	# the bone bridge: from the Pilgrims' Landing (the quarry's lip) over the pool to the gate hall's west door
	var x0 := BRIDGE_X0
	var x1 := 18.0
	var mid := (x0 + x1) * 0.5
	# walking surface: one flat invisible slab under the plate crowns, plus low rail walls
	k._ramp_faces(Vector3(mid, y - 0.25, z), Vector3(x1 - x0, 0.5, 3.0), Basis.IDENTITY)
	for s: float in [-1.0, 1.0]:
		k._ramp_faces(Vector3(mid, y + 0.55, z + s * 1.42), Vector3(x1 - x0, 1.1, 0.14), Basis.IDENTITY)
	var n := int((x1 - x0) / 0.6)
	for i in n:
		var x := x0 + (float(i) + 0.5) * (x1 - x0) / float(n)
		var tilt := Basis(Vector3.UP, _rng.randf_range(-0.04, 0.04))
		k.append_mesh("bone_cm", _plate_mesh(), Transform3D(tilt, Vector3(x, y, z)))
		for side: int in [-1, 1]:
			var sc := _rng.randf_range(0.92, 1.12)
			k.append_mesh("bone_cm", _rib_mesh(side), Transform3D(Basis(Vector3.RIGHT, _rng.randf_range(-0.05, 0.05)).scaled(Vector3(1, sc, 1)), Vector3(x, y, z + float(side) * 1.38)))
			if i % 2 == 0:
				k.skull(Vector3(x, y + 1.2 * sc + 0.01, z + float(side) * 1.33), float(side) * -PI * 0.5 + PI * 0.5 + _rng.randf_range(-0.3, 0.3), 0.95, 1)
	# candles along the deck edges, inside the rails
	for x: float in [x0 + 2.0, mid, x1 - 1.0]:
		for s: float in [-1.0, 1.0]:
			k.candle_cluster(Vector3(x, y, z + s * 1.12), 4, 0.14, _rng)
	# the great ribs that carried the span once, under it: they rise from the pool's bed, well below the deck
	for s: float in [-1.0, 1.0]:
		k.append_mesh("bone_cm", _great_rib_mesh(y - 6.0 - LAVA_Y), Transform3D(Basis(Vector3.UP, PI if s < 0.0 else 0.0), Vector3(10.5 - s * 1.6, LAVA_Y, z + s * 1.2)))
	# three masonry piers carry it (a viaduct over the pool: the same stone as the tiers)
	for x: float in [2.0, 8.5, 15.5]:
		_pier(k, x, z, y - 0.75, 1.8)


## The Pilgrims' Landing: the bone bridge's head on the quarry's lip, where the lane from south_track ends.
## A paved apron and a gate of two stone pylons (a pointed arch of the Ossuary's stone, a skull over the
## keystone, candles), the first thing the lane shows: the way down is through it, over the bridge.
func _landing(k: OssKit) -> void:
	var y := HALL_Y
	var z := -34.0
	k.block("floor", Vector3(-12.0, y - 0.7, z - 3.4), Vector3(BRIDGE_X0 + 0.4, y, z + 3.4))
	k.block("stone", Vector3(-12.4, y - 0.7, z - 3.8), Vector3(BRIDGE_X0 + 0.5, y - 0.1, z + 3.8), true, 0.85)       # a kerb of dressed stone round the apron
	for s: float in [-1.0, 1.0]:
		var pz := z + s * 2.7
		k.block("stone", Vector3(-6.3, y, pz - 0.65), Vector3(-4.9, y + 6.0, pz + 0.65))
		k.block("stone", Vector3(-6.55, y, pz - 0.9), Vector3(-4.65, y + 0.6, pz + 0.9), true, 0.85)
		k.block("stone", Vector3(-6.45, y + 5.4, pz - 0.8), Vector3(-4.75, y + 5.8, pz + 0.8), true, 0.9)
		k.pinnacle("stone", Vector3(-5.6, y + 6.0, pz), 0.7, 0.9, 2.2)
		k.candelabrum(Vector3(-7.4, y, pz + s * 0.9), 1.6, _rng)
		k.candle_cluster(Vector3(-7.0, y, pz - s * 1.2), 7, 0.3, _rng)
	k.arch_panel("stone", Vector3(-5.6, y, z), Vector3.FORWARD, 4.2, 3.2, 6.0, 1.0, 0.0, 0.75, 0.0, "stone")
	for i in 7:
		k.skull(Vector3(-6.15, y + 5.1, z - 1.2 + 0.4 * float(i)), -PI * 0.5 + _rng.randf_range(-0.12, 0.12), 1.0, 1)
	k.candle_cluster(Vector3(-9.5, y, z), 12, 0.7, _rng)


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
	# (outside the hall, north of its NW corner, on its own pier: it used to stand inside the hall
	#  by the door and snagged anyone turning for the north stair)
	var tc := Vector3(18.0, y, -39.6)
	_pier(k, tc.x, tc.z, y, 2.8)
	k.block("stone", tc + Vector3(-1.4, 0, -1.4), tc + Vector3(1.4, h + 4.6, 1.4))
	var bel := y + h + 4.6
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		k.box("stone", tc + Vector3(s.x * 1.2, bel - y + 1.6, s.y * 1.2), Vector3(0.45, 3.2, 0.45))
	k.block("stone", tc + Vector3(-1.6, bel - y + 3.2, -1.6), tc + Vector3(1.6, bel - y + 3.6, 1.6), true, 0.85)
	k.pinnacle("slate", tc + Vector3(0, bel - y + 3.6, 0), 2.6, 0.4, 7.5)
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		k.pinnacle("stone", tc + Vector3(s.x * 1.45, bel - y + 3.6, s.y * 1.45), 0.4, 0.5, 1.6)
	k.candle_cluster(tc + Vector3(0, bel - y, 0), 10, 0.7, _rng)
	# bone dado under the niches (femur ends and a row of skulls, Sedlec style)
	_bone_dado(k, Vector3(x1 - t * 0.5, y, z0 + 0.5), Vector3(x1 - t * 0.5, y, z1 - 0.5), Vector3.LEFT, [0.48, 0.56, -0.66, 0.9])
	# grave slabs set in the floor down the middle
	for zz: float in [-26.2, -35.8]:
		k.box("stone", Vector3(24.0, y + 0.012, zz), Vector3(1.1, 0.024, 2.1), Basis.IDENTITY, false, 0.7)
		k.box("stone", Vector3(24.0, y + 0.02, zz), Vector3(0.9, 0.012, 1.9), Basis.IDENTITY, false, 0.95)
		k.box("dark", Vector3(24.0, y + 0.03, zz), Vector3(0.08, 0.008, 1.0), Basis.IDENTITY, false)
		k.box("dark", Vector3(24.0, y + 0.03, zz - 0.25), Vector3(0.5, 0.008, 0.08), Basis.IDENTITY, false)
	for c: Vector2 in [Vector2(22.4, -28.6), Vector2(25.6, -28.6), Vector2(22.4, -33.4), Vector2(25.6, -33.4)]:
		k.candelabrum(Vector3(c.x, y, c.y), 1.7, _rng)
	for i in 18:
		k.candle_cluster(Vector3(_rng.randf_range(19.0, 29.0), y, _rng.randf_range(-37.2, -24.8)), _rng.randi_range(4, 10), 0.3, _rng)
	k.candle_cluster(Vector3(24.0, y, -25.3), 16, 0.8, _rng)
	for zz: float in [-36.6, -25.4]:
		k.candle_cluster(Vector3(28.8, y, zz), 9, 0.4, _rng)


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
		if i == 3:       # the Sexton's cage arrives here (oss_deep.gd): a door, grilled until opened
			arcade.append({"at": 1.8 + 3.1 * float(i), "w": 2.3, "spring": 2.6, "k": 0.8})
		else:
			arcade.append({"at": 1.8 + 3.1 * float(i), "w": 2.3, "spring": 2.6, "sill": 0.95, "k": 0.8})
	_wall(k, "stone", Vector3(x0, y, z1), Vector3(x0, y, z0), h, t, arcade)
	# east: two rows of skull niches against the cliff
	var low: Array = []
	for i in 8:
		var at := 1.1 + 1.95 * float(i)
		low.append({"at": at, "w": 1.1, "spring": 1.5, "sill": 0.7, "niche": true, "k": 0.7})
	_wall(k, "plaster", Vector3(x1, y, z0), Vector3(x1, y, z1), 3.4, t, low, Vector3.RIGHT)
	_bone_dado(k, Vector3(x1 - t * 0.5, y, z0 + 0.4), Vector3(x1 - t * 0.5, y, z1 - 0.4), Vector3.LEFT, [0.47, 0.6])
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
		# transverse ribs across both aisles, springing from the spine piers
		for span: Vector2 in [Vector2(x0 + t * 0.5, xm - 0.4), Vector2(xm + 0.4, x1 - t * 0.5)]:
			k._arch_ring("stone", Vector3((span.x + span.y) * 0.5, y + h - 2.1, zc), Vector3.RIGHT, Vector3.FORWARD, span.y - span.x, 0.55, 0.32)
	k.block("dark", Vector3(x0, y + h, z0), Vector3(x1, y + h + 0.3, z1), true, 0.7)
	_gable_roof(k, Vector3(x0, 0, z0), Vector3(x1, 0, z1), y + h + 0.3, y + h + 3.4, false)
	_undercroft(k, x0 - 0.2, [z0, -59.0, z1], y, 2.2)
	for z: float in [z0 + 0.3, -59.0, z1 - 0.3]:
		k.box("stone", Vector3(x0 - 0.6, y + h * 0.45, z), Vector3(1.2, h * 0.9, 0.9), Basis.IDENTITY)
		k.pinnacle("stone", Vector3(x0 - 0.6, y + h, z), 0.7, 1.6, 2.0)
	# bone heaps in the aisles + candles
	for i in 6:
		var at := Vector3(_rng.randf_range(23.4, 26.0), y, _rng.randf_range(-66.0, -52.0))
		var hr := _rng.randf_range(0.5, 0.9)
		_bone_heap(k, at, hr)
	for zz: float in [-53.6, -57.1, -60.6, -64.1]:
		k.candelabrum(Vector3(25.4, y, zz), 1.5, _rng)
	for i in 26:
		k.candle_cluster(Vector3(_rng.randf_range(18.4, 26.2), y, _rng.randf_range(-66.3, -51.7)), _rng.randi_range(3, 9), 0.28, _rng)
	# Wenna's niche (r30 story): the second low niche from the portcullis end, one stub of candle on
	# its sill and her last word scratched beside it. Its own rng: the gallery's dressing is unchanged.
	var wz := z0 + 1.1 + 1.95
	var wr := RandomNumberGenerator.new()
	wr.seed = 9119
	k.candle_cluster(Vector3(x1 - 0.55, y + 0.7, wz), 1, 0.02, wr)
	(load("res://core/world/realm/lore/lore_more.gd") as GDScript).call("place", self, "bs_wenna_niche", Vector3(x1 - 0.9, y + 0.9, wz))


## Bone dado along a wall face a->b: rows at the given heights above the floor. A positive
## row is femur ends pointing out of the wall; a negative row is a line of skulls at |h|.
func _bone_dado(k: OssKit, a: Vector3, b: Vector3, out: Vector3, rows: Array) -> void:
	var d := b - a
	var length := d.length()
	var along := d / length
	var face_yaw := atan2(out.x, out.z)
	for r: float in rows:
		var skull_row := r < 0.0
		var step := 0.22 if skull_row else 0.075
		var n := int(length / step)
		for i in n:
			var p := a + along * ((float(i) + 0.5) * step) + Vector3.UP * absf(r)
			if skull_row:
				k.skull(p + out * 0.06, face_yaw + PI + _rng.randf_range(-0.12, 0.12), 0.95, 1)
			else:
				var jit := Basis(Vector3.UP, face_yaw + _rng.randf_range(-0.06, 0.06)) * Basis(Vector3.FORWARD, _rng.randf() * TAU)
				k.bone(p + out * 0.02, jit, 0, false)


func _bone_heap(k: OssKit, at: Vector3, r: float) -> void:
	for i in int(r * 70.0):
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r
		var hgt := (1.0 - d / r) * r * 0.55
		var p := at + Vector3(cos(a) * d, hgt * _rng.randf_range(0.4, 1.0) + 0.03, sin(a) * d)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.5, 0.5))
		if _rng.randf() < 0.25:
			k.skull(p, _rng.randf() * TAU, _rng.randf_range(0.9, 1.1))
		else:
			k.bone(p, b, 0 if _rng.randf() < 0.45 else (1 if _rng.randf() < 0.65 else 2))


# --- charnel pit ----------------------------------------------------------------------------

func _pit(k: OssKit) -> void:
	var c := PIT_C
	var n := 40
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
	# drum and corbels underneath, down into the lava: only where the Lower Count (oss_deep.gd)
	# leaves room. Its turning drum, spindle and arms take the middle; three piers carry the rest.
	for i in 12:
		var a := TAU * float(i) / 12.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 4.8
		if OssDeep.clear(Vector2(p.x, p.z), 1.5):
			k.box("stone", Vector3(p.x, (LAVA_Y + c.y - thick) * 0.5, p.z), Vector3(2.0, c.y - thick - LAVA_Y, 2.0), Basis(Vector3.UP, a))
		var q := c + Vector3(cos(a), 0, sin(a)) * 8.8
		if OssDeep.clear(Vector2(q.x, q.z), 1.0):
			k.box("stone", q + Vector3.UP * (-thick - 1.2), Vector3(4.0, 2.4, 1.0), Basis(Vector3.UP, -a).orthonormalized() * Basis(Vector3.FORWARD, 0.0), false, 0.8)
	for sp: Vector2 in [Vector2(9.5, -79.5), Vector2(24.0, -91.0), Vector2(13.2, -95.5)]:
		_pier(k, sp.x, sp.y, c.y - thick, 2.0)
	# parapet ring with gaps: entry (towards the stair foot) and chapel (north). r30: the west "lift"
	# gap opened onto a 7 m drop over lava with no lift in it (the lift stands at 225 deg, r 4.2): closed.
	# 1.3 m high (above the vault reach, VAULT_MAX 1.25): the lava edge is a wall you see, not one you
	# vault into while dodging.
	var gaps := [_ang_to(Vector3(21.0, 0, -78.0)), -PI * 0.5, _ang_to(Vector3(COUNT_DOOR_X, 0, OssHall.DOOR_Z))]   # r34: the Counting Door (east)
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var am := (a0 + a1) * 0.5
		var skip := false
		for g in gaps:
			if absf(angle_difference(am, float(g))) < 0.2:
				skip = true
		if skip:
			continue
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * (PIT_R - 0.25)
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * (PIT_R - 0.25)
		k.parapet("stone", p0, p1, PIT_WALL, 0.4)
	# broken colonnade, bone mounds, spitter plinths
	for i in 12:
		var a := TAU * float(i) / 12.0 + 0.2
		var in_gap := false                      # keep the entry, chapel and lift lanes clear
		for g: float in gaps:
			if absf(angle_difference(a, g)) < 0.32:
				in_gap = true
		if in_gap:
			continue
		var p := c + Vector3(cos(a), 0, sin(a)) * 9.4
		var hgt := 6.5 if i % 3 == 0 else _rng.randf_range(1.6, 4.4)
		k.box("stone", p + Vector3.UP * (hgt * 0.5), Vector3(0.9, hgt, 0.9), Basis(Vector3.UP, a))
		k.box("stone", p + Vector3.UP * 0.25, Vector3(1.4, 0.5, 1.4), Basis(Vector3.UP, a), true, 0.85)
		if hgt < 6.0:
			k.candle_cluster(p + Vector3.UP * hgt, _rng.randi_range(3, 6), 0.25, _rng)
	for a: float in [0.45, 2.65, 3.15, 5.05]:
		_bone_heap(k, c + Vector3(cos(a), 0, sin(a)) * 6.2, 1.5)
	for a: float in [PLINTH_A, PLINTH_B]:
		var p := c + Vector3(cos(a), 0, sin(a)) * 7.8
		k.block("stone", p + Vector3(-1.0, 0, -1.0), p + Vector3(1.0, 1.6, 1.0))
		k.candle_cluster(p + Vector3(0, 1.6, 0), 6, 0.6, _rng)
	# charnel mound: tiers of skulls facing outward, a long-bone crown, candles all round
	for tier in 5:
		var r := 1.15 - 0.22 * float(tier)
		var cnt := maxi(3, int(TAU * r / 0.21))
		for i in cnt:
			var a := TAU * float(i) / float(cnt) + float(tier) * 0.3
			k.skull(c + Vector3(cos(a) * r, 0.02 + 0.17 * float(tier), sin(a) * r), -a - PI * 0.5 + PI, 1.05, tier % 2, -0.15)
	for i in 10:
		var a := TAU * float(i) / 10.0
		k.bone(c + Vector3(cos(a) * 0.14, 0.95, sin(a) * 0.14), Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -1.2), 0, false)
	for i in 14:
		var a := TAU * float(i) / 14.0 + 0.1
		k.candle_cluster(c + Vector3(cos(a), 0, sin(a)) * 1.75, _rng.randi_range(3, 6), 0.2, _rng)
	# (the stair now lands on the widened pit floor itself: no separate landing slab)
	_pier(k, 21.0, -79.0, PIT_Y - 0.6, 2.0)


func _ang_to(p: Vector3) -> float:
	return atan2(p.z - PIT_C.z, p.x - PIT_C.x)


# --- chapel --------------------------------------------------------------------------------

func _chapel(k: OssKit) -> void:
	var x0 := 12.0
	var x1 := 20.0
	var z0 := -107.0
	var z1 := -99.0
	var y := PIT_Y
	var h := 6.0
	var t := 0.7
	k.block("floor", Vector3(15.0, y - 0.6, -99.0), Vector3(17.0, y, -96.6))     # walk from the pit
	# the floor, open over the sexton's stair (oss_deep.gd: a slab covers it until the Abbot falls)
	var hole: Rect2 = OssDeep.HOLE
	k.block("floor", Vector3(x0, y - 0.6, z0), Vector3(hole.position.x, y, z1))
	k.block("floor", Vector3(hole.end.x, y - 0.6, z0), Vector3(x1, y, z1))
	k.block("floor", Vector3(hole.position.x, y - 0.6, z0), Vector3(hole.end.x, y, hole.position.y))
	k.block("floor", Vector3(hole.position.x, y - 0.6, hole.end.y), Vector3(hole.end.x, y, z1))
	for p: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		_pier(k, p.x, p.y, y - 0.6, 2.0)
	_wall(k, "plaster", Vector3(x0, y, z1), Vector3(x1, y, z1), h, t, [{"at": 4.0, "w": 2.4, "spring": 2.8}])
	_wall(k, "plaster", Vector3(x1, y, z0), Vector3(x0, y, z0), h, t, [{"at": 4.0, "w": 1.4, "spring": 3.2, "sill": 1.8, "k": 1.2, "glow": true}])
	var side_n: Array = []
	for i in 3:
		side_n.append({"at": 1.6 + 2.4 * float(i), "w": 1.0, "spring": 1.6, "sill": 0.9, "niche": true, "k": 0.7})
	_wall(k, "plaster", Vector3(x0, y, z0), Vector3(x0, y, z1), h, t, side_n, Vector3.LEFT)
	_wall(k, "plaster", Vector3(x1, y, z1), Vector3(x1, y, z0), h, t, side_n, Vector3.RIGHT)
	_bone_dado(k, Vector3(x0 + t * 0.5, y, z0 + 0.5), Vector3(x0 + t * 0.5, y, z1 - 0.5), Vector3.RIGHT, [0.47, 0.6, -0.7])
	_bone_dado(k, Vector3(x1 - t * 0.5, y, z0 + 0.5), Vector3(x1 - t * 0.5, y, z1 - 0.5), Vector3.LEFT, [0.47, 0.6, -0.7])
	for c: Vector2 in [Vector2(13.6, -105.6), Vector2(18.4, -105.6)]:
		k.candelabrum(Vector3(c.x, y, c.y), 1.8, _rng)
	k.block("dark", Vector3(x0, y + h, z0), Vector3(x1, y + h + 0.3, z1), true, 0.7)
	_gable_roof(k, Vector3(x0, 0, z0), Vector3(x1, 0, z1), y + h + 0.3, y + h + 3.0, true)
	for p: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		k.pinnacle("stone", Vector3(p.x, y + h, p.y), 0.7, 1.2, 2.2)
	k.pinnacle("slate", Vector3(16.0, y + h + 3.0, -103.0), 1.0, 0.3, 4.0)
	# altar
	k.block("stone", Vector3(14.6, y, -106.2), Vector3(17.4, y + 1.0, -104.8))
	k.block("stone", Vector3(14.4, y + 1.0, -106.4), Vector3(17.6, y + 1.15, -104.6), true, 0.9)
	k.candle_cluster(Vector3(14.9, y + 1.15, -105.5), 6, 0.2, _rng)
	k.candle_cluster(Vector3(17.1, y + 1.15, -105.5), 6, 0.2, _rng)
	for i in 6:
		var cp := Vector3(_rng.randf_range(12.8, 19.2), y, _rng.randf_range(-106.3, -99.7))
		if cp.x > hole.position.x - 0.5 and cp.z > hole.position.y - 0.4:
			cp.x = hole.position.x - 0.7                # not over the stairwell
		k.candle_cluster(cp, 5, 0.3, _rng)


# --- lights, lift, reliquary, enemies -------------------------------------------------------

func _lights() -> void:
	make_brazier("OssuaryGate", OssFrame.w(Vector3(24.0, HALL_Y, -31.0)), OssFrame.YAW)
	_omni("HallFill", Vector3(24.0, HALL_Y + 4.8, -31.0), Color(1.0, 0.62, 0.3), 1.1, 11.0, false)
	_omni("GalleryA", Vector3(22.25, GAL_Y + 3.6, -54.5), Color(1.0, 0.58, 0.28), 1.3, 9.0, false)
	_omni("GalleryB", Vector3(22.25, GAL_Y + 3.6, -63.0), Color(1.0, 0.58, 0.28), 1.3, 9.0, false)
	_omni("PitCandles", PIT_C + Vector3(0, 3.6, 0), Color(1.0, 0.6, 0.3), 2.6, 18.0, false)   # unshadowed: fights here re-rendered its cube map every frame
	_omni("Chapel", Vector3(16.0, PIT_Y + 3.0, -104.0), Color(0.75, 0.45, 1.0), 1.6, 8.0, false)
	_omni("BridgeUnder", Vector3(8.0, HALL_Y - 4.0, -34.0), Color(0.55, 0.7, 1.0), 1.0, 12.0, false)      # the pool's cold glint under the bridge
	_omni("Landing", Vector3(-7.0, HALL_Y + 3.4, -34.0), Color(1.0, 0.6, 0.3), 1.5, 11.0, false)


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
	l.position = at
	LightPolicy.apply_fade(l)
	LightPolicy.apply_illumination(l)
	if not shadow:
		l.shadow_enabled = false


## The still pool in the pit: where the chasm had lava. A dark, glassy sheet over the bed (the terrain's own
## water is the shore's; this is the pit's: it takes the candle-light of the tiers), and a kill box under the
## bridge, as the lava had: the pool throws you back to the last ground you stood on.
func _pool() -> void:
	var holder := Node3D.new()
	holder.name = "Pool"
	add_child(holder)
	var kill := OssPool.new()
	kill.name = "PoolKill"
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var bx := BoxShape3D.new()
	bx.size = Vector3(42.0, 4.0, 112.0)
	cs.shape = bx
	kill.add_child(cs)
	holder.add_child(kill)
	kill.position = Vector3(8.0, OssFrame.POOL_Y - 2.4, -66.0)      # (Lava lifts its shape 1.2 m: the top face stands just under the surface)


func _spawns() -> void:
	# the gallery's two camps guard the crypt: kill them and the bone portcullis rises.
	# The pit itself is the Abbot's: no standing camps there any more.
	EnemySpawner._seed(self, [
		{"at": OssFrame.w(Vector3(20.0, GAL_Y + 1.0, -56.0)), "kinds": ["wretch", "wretch"], "probe": 1.5, "r": 1.6, "seal": "oss_gallery"},
		{"at": OssFrame.w(Vector3(24.6, GAL_Y + 1.0, -62.5)), "kinds": ["ossuant", "spitter"], "probe": 1.5, "r": 1.4, "seal": "oss_gallery"},
	])


## The crypt: the portcullis at the head of the pit stair (the gallery seal), and (r34) the Abbot's
## raid in the pit hall under the bank: the arena on the hall's floor, a bone grille at each end of the
## raid door that shuts on the pull, the Bone Reliquary rising before the great mound when he falls.
func _crypt(hall: Node3D) -> void:
	WardSeal.make(self, "oss_gallery", OssFrame.w(Vector3(21.0, GAL_Y, -66.7)), OssFrame.wd(Vector3.FORWARD), 3.6, 3.0, "bone", "The bone portcullis")
	var da := OssHall.door_ang()
	var inward := OssFrame.wd(Vector3(-cos(deg_to_rad(da)), 0.0, -sin(deg_to_rad(da))))
	# he rises on the door side of the mound, in the lantern light on the entry axis (he was 26 m off beyond the mound, a speck)
	var spawn := OssHall.wat(da, 11.0, OssHall.FLOOR_Y + 0.1)
	var arena := BossArena.make(self, "bone_abbot", "The Bone Abbot", OssHall.WC, 23.0, BoneAbbot, spawn)
	arena.ceiling = 4.0                          # the stair's slit and the galleries never pull him
	arena.max_rise = 6.0                         # the mound stands in the middle of the floor
	# the inner grille at the floor's edge is the line the fight starts behind; the outer one in the
	# hall's wall shuts the stair off behind it (WoW's raid door, here two bone portcullises)
	arena.gate = WardSeal.make_arena_gate(self, "abbot_door", OssHall.wat(da, OssHall.TIER_A.x + 0.3), inward, 3.4, 3.6, "bone")
	arena.gates = [WardSeal.make_arena_gate(self, "abbot_gate", OssHall.wat(da, OssHall.WALL_R + 0.4), inward, 3.4, 3.6, "bone")]
	arena.subtitle = "Abbot Osric, still counting"
	arena.phase_titles = {4: "Abbot Osric"}
	hall.set("arena", arena)
	arena.room = hall                            # r34 raids: room_begin / room_reset / room_won
	arena.on_slain = func(fresh: bool) -> void:
		hall.call("restore")
		if Travel.relics.has("bone"):
			return                                    # already taken: gone from the world for good
		var r := Reliquary.new()
		r.name = "BoneReliquary"
		r.relic_id = "bone"
		r.size = 2.4                                  # a shrine you see from the door, not a trinket
		add_child(r)
		r.global_position = OssHall.wat(da, OssHall.MOUND_R + 1.8, OssHall.FLOOR_Y + 1.15)
		if fresh:
			SpellFx.rift_in(r.global_position)
			Events.toast.emit("The Bone Reliquary rises from the mound.")


## r34 crypt (tests, tools): a standing spot on the pit hall's floor, a few metres past the raid door's
## inner grille: teleporting here pulls the Bone Abbot.
static func abbot_pull_at() -> Vector3:
	return OssHall.wat(OssHall.door_ang(), OssHall.FLOOR_R - 4.0, OssHall.FLOOR_Y + 0.4)


## r34 crypt: the Counting Door, cut into the bank east of the pit: a threshold from the pit's east gap
## to the stair shaft's west door, and a gatehouse front on the shaft's face (the shaft, the stair and
## the hall below are oss_hall.gd's). The walls of the cut are built once the Realm's ground is in.
func _counting_door(k: OssKit) -> void:
	var dz := OssHall.DOOR_Z
	var fx := COUNT_DOOR_X
	k.block("floor", Vector3(PIT_C.x + PIT_R - 0.6, PIT_Y - 0.6, dz - 1.4), Vector3(fx + 0.6, PIT_Y, dz + 1.4))
	# the front: a skin of dressed stone over the shaft's west wall, up past the ground of the bank
	var top := PIT_Y + 6.4
	_wall(k, "stone", Vector3(fx - 0.25, PIT_Y, dz + 2.4), Vector3(fx - 0.25, PIT_Y, dz - 2.4), top - PIT_Y, 0.5, [{"at": 2.4, "w": 2.0, "spring": 1.6, "k": 0.75}])
	for s: float in [-1.0, 1.0]:
		var bz := dz + s * 2.6
		k.box("stone", Vector3(fx - 0.7, PIT_Y + 3.0, bz), Vector3(1.0, 6.0, 0.8), Basis.IDENTITY)          # buttresses
		k.pinnacle("stone", Vector3(fx - 0.7, PIT_Y + 6.0, bz), 0.7, 0.9, 1.9)
		var b := Vector3(fx - 0.55, PIT_Y + 2.4, dz + s * 1.45)
		k.box("iron", b + Vector3(-0.25, 0.0, 0.0), Vector3(0.5, 0.05, 0.05), Basis.IDENTITY, false)
		k.box("glow", b + Vector3(-0.5, -0.12, 0.0), Vector3(0.2, 0.28, 0.2), Basis.IDENTITY, false, 0.6)
		k.candle_cluster(Vector3(fx - 1.2, PIT_Y, dz + s * 1.0), 5, 0.2, _rng)
	k.pinnacle("slate", Vector3(fx - 0.25, top, dz), 1.2, 0.3, 2.6)
	# a tally over the door: four strokes and the fifth across, over and over (the Abbot's count)
	for i in 4:
		for j in 5:
			var zz := dz - 1.6 + 0.85 * float(i) + 0.13 * float(j)
			if j == 4:
				k.box("dark", Vector3(fx - 0.51, PIT_Y + 3.65, zz - 0.26), Vector3(0.02, 0.07, 0.62), Basis(Vector3.RIGHT, 0.5), false)
			else:
				k.box("dark", Vector3(fx - 0.51, PIT_Y + 3.65, zz), Vector3(0.02, 0.5, 0.05), Basis.IDENTITY, false)
	for i in 9:
		k.skull(Vector3(fx - 0.6, PIT_Y + 4.2, dz - 1.2 + 0.3 * float(i)), -PI * 0.5 + _rng.randf_range(-0.15, 0.15), 1.05, 1)


## the Counting Door's front against the quarry's south face. The shaft's west wall stands in
## the bank, and the terrain's cliff passes through it: once the Realm's ground is in, the cliff's band over
## the shaft is taken out (mesh and collision), the face is carried up to the crest in dressed stone (the
## door's gatehouse front), and a paved cap closes the hole to the bank's top.
func _count_cut() -> void:
	var root := _zone_root()
	var t0 := Time.get_ticks_msec()
	while is_inside_tree() and root and not root.has_meta("realm_done") and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	if not is_inside_tree() or get_node_or_null("CountCut") != null:
		return
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var host := Node3D.new()
	host.name = "CountCut"
	host.set_meta("site", "oss_count_door")
	add_child(host)
	var k := OssKit.new()
	k.keep_lanes = false
	var dz := OssHall.DOOR_Z
	var fx := COUNT_DOOR_X - 0.25
	var z0 := OssHall.ZN_OUT - OssHall.SHAFT_T - 0.4                  # the shaft's north end (more negative)
	var z1 := OssHall.ZS_OUT + OssHall.SHAFT_T + 0.4                  # ... its south end
	# the threshold's low walls, from the pit's rim to the door
	for sd: float in [-1.0, 1.0]:
		k.parapet("stone", Vector3(PIT_C.x + PIT_R - 0.2, PIT_Y, dz + sd * 1.55), Vector3(COUNT_DOOR_X - 0.5, PIT_Y, dz + sd * 1.55), 1.0, 0.4)
	# the crest behind the face: the bank's top over the shaft
	var crest := PIT_Y + 6.4
	var z := z0
	while z <= z1:
		crest = maxf(crest, _ground_l(space, COUNT_DOOR_X + 5.4, z) + 0.45)
		z += 1.5
	var dn := 2.4
	_wall(k, "stone", Vector3(fx, PIT_Y, dz - dn), Vector3(fx, PIT_Y, z0), crest - PIT_Y, 0.5, [])      # north of the door
	_wall(k, "stone", Vector3(fx, PIT_Y, z1), Vector3(fx, PIT_Y, dz + dn), crest - PIT_Y, 0.5, [])      # south of it
	_wall(k, "stone", Vector3(fx, PIT_Y + 6.4, dz + dn), Vector3(fx, PIT_Y + 6.4, dz - dn), crest - PIT_Y - 6.4, 0.5, [])   # over the door's front
	for sd: float in [-1.0, 1.0]:                                                                    # pilasters between the door and the shaft's ends
		for off: float in [5.5, 9.5]:
			var bz := dz + sd * off
			if bz > z0 and bz < z1:
				k.box("stone", Vector3(fx - 0.45, PIT_Y + (crest - PIT_Y) * 0.5, bz), Vector3(0.9, crest - PIT_Y, 0.8), Basis.IDENTITY)
				k.pinnacle("stone", Vector3(fx - 0.45, crest, bz), 0.62, 0.8, 1.7)
	k.block("floor", Vector3(COUNT_DOOR_X, crest - 0.4, z0 - 0.3), Vector3(COUNT_DOOR_X + 5.0, crest, z1 + 0.3))   # the cap: flush with the bank's top
	k.commit(host, "CountCutBody")
	while is_inside_tree() and root and not root.has_meta("realm_done") and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	var n := punch_terrain(root, OssFrame.wrect(Rect2(COUNT_DOOR_X - 0.6, z0 + 0.2, 4.6, z1 - z0 - 0.4)))
	print("OSSUARY counting door cut: face to y %.1f, %d ground triangles lifted" % [crest, n])


## r34 crypt: take the terrain triangles whose centres lie in `r` out of Zone/Terrain and its body.
static func punch_terrain(root: Node, r: Rect2) -> int:
	var n := 0
	var terrain := root.find_child("Terrain", true, false) as MeshInstance3D
	if terrain and terrain.mesh is ArrayMesh:
		var m := terrain.mesh as ArrayMesh
		var arrays := m.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var xf := terrain.global_transform
		if not idx.is_empty():
			for t in range(0, idx.size(), 3):
				var c := xf * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
				if r.has_point(Vector2(c.x, c.z)):
					idx[t + 1] = idx[t]
					idx[t + 2] = idx[t]
					n += 1
			if n > 0:
				arrays[Mesh.ARRAY_INDEX] = idx
				var mat := m.surface_get_material(0)
				m.clear_surfaces()
				m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				if mat:
					m.surface_set_material(0, mat)
	var body := root.find_child("TerrainBody", true, false) as StaticBody3D
	if body:
		for cs in body.find_children("*", "CollisionShape3D", true, false):
			var sh := (cs as CollisionShape3D).shape as ConcavePolygonShape3D
			if sh == null:
				continue
			var faces := sh.get_faces()
			var xf := (cs as CollisionShape3D).global_transform
			var keep := PackedVector3Array()
			keep.resize(faces.size())
			var w := 0
			for t in range(0, faces.size(), 3):
				var c := xf * ((faces[t] + faces[t + 1] + faces[t + 2]) / 3.0)
				if r.has_point(Vector2(c.x, c.z)):
					continue
				keep[w] = faces[t]
				keep[w + 1] = faces[t + 1]
				keep[w + 2] = faces[t + 2]
				w += 3
			if w < faces.size():
				keep.resize(w)
				var ns := ConcavePolygonShape3D.new()
				ns.backface_collision = sh.backface_collision
				ns.set_faces(keep)
				(cs as CollisionShape3D).shape = ns
	return n

func _zone_root() -> Node:
	var n := get_parent()
	while n and not n.has_meta("realm_built"):
		n = n.get_parent()
	return n if n else get_parent()


## Ground height (local y) under a local xz: the Realm's terrain, seen through the frame.
func _ground_l(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var wp := OssFrame.w(Vector3(x, 0.0, z))
	return RealmLayout.ground(space, wp.x, wp.z) - OssFrame.ORIGIN.y
