extends Node3D
## THE LOWER COUNT (r28, agent D): what the Abbot kept under his crypt. Built by the Ossuary after
## its own tiers (time-sliced), in the Ossuary's stone. No class_name: the Ossuary loads it by path.
##
##   CHAPEL (y 4.2) ── the sexton's slab (heaves aside once the Bone Abbot is dead) ── a stair
##     down the chapel's east side, from its south wall north under its floor, into
##   THE UNCOUNTED CELLS (y 0, under the chapel): three shelves, three bronze wheels. Set each
##     wheel to the number of skulls on its shelf and the Abbot's bridge is hauled up (below).
##     The sexton's desk, his day-book, his strongbox.
##   a stair down under the pit to the deep floor (y -2) and
##   THE COUNT DRUM: a round crypt under the charnel pit that turns on its spindle. One door,
##     one slit opposite; the capstan inside turns it a quarter at a time (N, E, S, W).
##       E  the pool window: a bronze mirror over a grate catches the drowned lamp's light below (turn it)
##       S  the bone bridge (rises when the wheels are right) to the Weighing Floor
##       W  the Abbot's hoard: its bone door lifts when caught light reaches the sun-eye beside
##          it (E mirror -> through the drum, door W, slit E -> W mirror -> the eye)
##   THE WEIGHING FLOOR (y -2): a round mini-arena under the gallery; the Sexton (an elite
##     ossuant) and two wretches rise when you step on it. Put him down and the walk to
##   THE COUNTERWEIGHT CAGE opens: knock its pin out and it carries you up to the niche
##     gallery's west arcade, where a grille lifts: the shortcut from the fen door to the depths.
##   Opening the hoard ends the count: a cold flame burns in the gate hall's belfry for good,
##   seen across the valley, and the bell tolls once.
## State lives in the secrets' save (Travel.system_state("secrets")): groups open/solved/looted/
## elites plus st.deep = {drum, mirror_e, mirror_w, dials}. Texts: core/life/secrets/pages.gd.

const State := preload("res://core/life/secrets/state.gd")
const Kit := preload("res://core/life/secrets/kit.gd")
const Beam := preload("res://core/life/secrets/beam.gd")
const Lift := preload("res://world/areas/ossuary/oss_lift.gd")

const D := -2.0                                  ## the deep floor
const CELL_Y := 0.0                              ## the cells under the chapel
const CHAPEL_Y := 4.2
const DRUM := Vector3(18.0, D, -84.0)
const DRUM_R := 3.4
const DRUM_IN := 2.95
const DRUM_H := 3.4
const FLIGHT_X := 18.7                           ## the chapel stair's centre line
const FLIGHT_W := 1.6
const FLIGHT_TOP_Z := -99.65                     ## head (chapel floor, by its south wall)
const FLIGHT_FOOT_Z := -106.25                   ## foot (the cells' north end, y 0)
const HOLE := Rect2(17.9, -104.4, 1.6, 4.75)     ## the opening in the chapel floor (under the slab)
const WALK := Rect2(15.4, -99.0, 3.55, 3.0)      ## y 0, from the cells door to the stair down
const DSTAIR_HEAD_Z := -96.0
const DSTAIR_FOOT_Z := -92.2
const E_PLAT := Rect2(21.4, -86.0, 2.2, 4.0)
const E_MIRROR := Vector2(22.6, -84.0)
const S_BRIDGE := Rect2(16.9, -80.6, 2.2, 5.2)
const ARENA := Vector3(15.5, D, -71.0)
const ARENA_R := 5.5
const LIFT_AT := Vector3(15.2, D, -62.1)         ## the cage's deck centre at the bottom stop
const GAL_Y := 8.4
const W_PLAT := Rect2(5.0, -87.0, 5.8, 5.5)
const W_MIRROR := Vector2(8.6, -84.0)
const HOARD := Rect2(4.0, -93.5, 6.8, 6.5)       ## x 4..10.8, z -93.5..-87
const HOARD_DOOR_X := 6.4
const EYE := Vector2(8.6, -87.05)
const BEAM_Y := D + 1.5
const SHELVES := [[-101.2, 4], [-103.4, 2], [-105.6, 5]]   ## z, skulls on the shelf (the answer)
const BELFRY := Vector3(18.0, 25.4, -39.6)       ## the gate hall bell tower's open stage

## Lanes the Ossuary's own under-structure keeps clear of (xz rects and circles).
const CLEAR_RECTS := [
	Rect2(15.2, -106.8, 4.6, 19.6),      # chapel flight, cells walk, deep stair, north arm
	Rect2(21.2, -86.2, 2.6, 4.4),        # pool window
	Rect2(16.7, -80.8, 2.6, 5.6),        # bone bridge
	Rect2(13.6, -66.0, 3.2, 5.4),        # cage walk and cage
	Rect2(5.8, -93.7, 9.0, 12.4),        # hoard, west landing, west arm
	Rect2(11.8, -107.2, 8.4, 8.4),       # the cells
]
const CLEAR_CIRCLES := [Vector3(18.0, -84.0, 3.8), Vector3(15.5, -71.0, 5.9)]

var area: Node3D
var drum_body: AnimatableBody3D
var _rng := RandomNumberGenerator.new()
var _sync: Array[Callable] = []
var _beam_holder: Node3D
var _mirror_e: Node3D
var _mirror_w: Node3D
var _eye_mi: MeshInstance3D
var _drum_turning := false
var _drum_from := 0.0
var _drum_to := 0.0
var _drum_t := 1.0
var _arena_live: Array[Node] = []
var _arena_on := false
var _lift: Node3D
var built := false


## True when xz `p` (with `r` margin) is clear of every lane the Lower Count needs.
static func clear(p: Vector2, r: float) -> bool:
	for rc: Rect2 in CLEAR_RECTS:
		if rc.grow(r).has_point(p):
			return false
	for c: Vector3 in CLEAR_CIRCLES:
		if p.distance_to(Vector2(c.x, c.y)) < c.z + r:
			return false
	return true


## A basis from three axes, made right-handed (a mirrored basis turns every face inside out).
static func _rb(x: Vector3, y: Vector3, z: Vector3) -> Basis:
	var b := Basis(x, y, z)
	if b.determinant() < 0.0:
		b = Basis(-x, y, z)
	return b.orthonormalized()


static func deep() -> Dictionary:
	var st := State.st()
	if not (st.get("deep") is Dictionary):
		st["deep"] = {}
	var d: Dictionary = st["deep"]
	if not d.has("drum"):
		d["drum"] = 0
	if not d.has("mirror_e"):
		d["mirror_e"] = 2                # pointing north, into the dark
	if not d.has("mirror_w"):
		d["mirror_w"] = 6                # pointing south
	if not (d.get("dials") is Array) or (d.dials as Array).size() != 3:
		d["dials"] = [1, 1, 1]
	return d


func build(a: Node3D) -> void:
	area = a
	set_meta("site", "oss_lower_count")      # its own structure: StoneBodies and the audits leave it be
	_rng.seed = 9241
	var t0 := Time.get_ticks_usec()
	var k := OssKit.new()
	k.keep_lanes = false                     # no hub lanes down here: every shelf keeps its count
	_cells(k)
	await area.call("slice")
	_walks(k)
	_drum_static(k)
	await area.call("slice")
	_east(k)
	_west(k)
	await area.call("slice")
	_arena(k)
	var draws := k.commit(self, "DeepBody")
	await area.call("slice")
	_slab()
	_drum()
	_bridge()
	_dials()
	_mirrors()
	_hoard_door()
	await area.call("slice")
	_arena_logic()
	_cage()
	_beacon()
	_lights()
	_readings()
	_ranges()
	_no_moon_shadows()
	built = true
	sync(false)
	print("OSSUARY lower count %.1f ms draws=%d" % [(Time.get_ticks_usec() - t0) * 0.001, draws])
	_register()


## Small things fade out with distance (the Ossuary is seen from the summit and the gallery):
## anything under 3 m without a range gets one.
func _ranges() -> void:
	# OssKit's prop cells: down here nothing is seen from far, so they fade sooner
	for n in find_children("*", "MultiMeshInstance3D", true, false):
		var mi := n as MultiMeshInstance3D
		mi.set_meta("site_owned", true)          # WorldLanes.cull_scatter must not thin the shelves' count
		var nm := String(mi.name)
		var cap := 40.0 if (nm.begins_with("Flames") or nm.begins_with("Halos")) else (26.0 if (nm.begins_with("Candles") or nm.begins_with("Wax") or nm.begins_with("Bones") or nm.begins_with("Skulls")) else 0.0)
		if cap > 0.0 and (mi.visibility_range_end == 0.0 or mi.visibility_range_end > cap):
			mi.visibility_range_end = cap
			mi.visibility_range_end_margin = cap * 0.12
	for n in find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.visibility_range_end > 0.0 or (_beacon_node and _beacon_node.is_ancestor_of(gi)):
			continue
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh and (gi as MeshInstance3D).mesh.get_aabb().size.length() < 3.0:
			gi.visibility_range_end = 60.0
			gi.visibility_range_end_margin = 6.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func sync(animate: bool) -> void:
	for f in _sync:
		if f.is_valid():
			f.call(animate)
	_trace(animate)


# --- the cells under the chapel --------------------------------------------------------------

func _cells(k: OssKit) -> void:
	var y := CELL_Y
	var x0 := 12.0
	var x1 := 20.0
	var z0 := -107.0
	var z1 := -99.0
	var t := 0.7
	var h := 3.6 - y                     # up to the chapel floor's underside
	k.block("floor", Vector3(x0, y - 0.6, z0), Vector3(x1, y, z1))
	# walls: west carries the three counting shelves, east is the flight's side, south has the
	# door to the walk (the flight passes out through its own gap)
	var shelf_ops: Array = []
	for sh: Array in SHELVES:
		shelf_ops.append({"at": z1 - float(sh[0]), "w": 1.2, "spring": 1.75, "sill": 1.0, "k": 0.7})
	area.call("_wall", k, "plaster", Vector3(x0, y, z1), Vector3(x0, y, z0), h, t, shelf_ops, Vector3.LEFT, "stone", true)
	area.call("_wall", k, "plaster", Vector3(x0, y, z0), Vector3(x1, y, z0), h, t, [], Vector3.BACK, "stone", true)
	area.call("_wall", k, "plaster", Vector3(x1, y, z0), Vector3(x1, y, z1), h, t, [], Vector3.LEFT, "stone", true)
	# south wall, with the door out to the walk
	area.call("_wall", k, "plaster", Vector3(x0, y, z1), Vector3(x1, y, z1), h, t, [{"at": 16.2 - x0, "w": 1.5, "spring": 2.1}], Vector3.FORWARD, "stone", true)
	# the three counting shelves: openings through the west wall, closed behind by dark slabs;
	# each holds exactly its count of skulls (the answer: nothing else stands on them)
	for i in SHELVES.size():
		var sz: float = SHELVES[i][0]
		var n: int = SHELVES[i][1]
		k.block("dark", Vector3(x0 - t * 0.5 - 0.12, y + 0.95, sz - 0.75), Vector3(x0 - t * 0.5 + 0.02, y + 2.9, sz + 0.75), true, 0.35)
		k.box("stone", Vector3(x0 + t * 0.5 + 0.06, y + 0.95, sz), Vector3(0.14, 0.1, 1.4), Basis.IDENTITY, false, 0.95)   # shelf lip
		var before := k.skull_count()
		for j in n:
			var zz := sz - 0.44 + 0.88 * (float(j) + 0.5) / float(n)
			k.skull(Vector3(x0 + 0.05, y + 1.0, zz), PI * 0.5 + _rng.randf_range(-0.12, 0.12), 1.0, j % 2)
		if k.skull_count() - before != n:
			print("OSSUARY lower count: shelf %d holds %d of %d skulls (blocked)" % [i, k.skull_count() - before, n])
		k.candle_cluster(Vector3(x0 + 0.1, y + 1.0, sz + 0.5), 2, 0.04, _rng)
	# the rest of the room: tally marks scored down the north wall, bone shelves, the sexton's desk
	for g in 9:
		var gx := 13.0 + 0.62 * float(g)
		for m in 5:
			var mx := gx + 0.07 * float(m)
			var b := Basis.IDENTITY if m < 4 else Basis(Vector3.BACK, 1.05)
			k.box("dark", Vector3(mx if m < 4 else gx + 0.12, y + 2.1, z0 + t * 0.5 + 0.01), Vector3(0.025, 0.42, 0.02), b, false, 0.3)
	area.call("_bone_dado", k, Vector3(x0 + 0.6, y, z1 - t * 0.5), Vector3(15.2, y, z1 - t * 0.5), Vector3.FORWARD, [0.47, 0.6, -0.72])
	var desk := Vector3(15.4, y, -103.0)
	k.box("wood", desk + Vector3(0, 0.78, 0), Vector3(1.5, 0.08, 0.8), Basis.IDENTITY, true, 0.75)
	for c: Vector2 in [Vector2(-0.65, -0.32), Vector2(0.65, -0.32), Vector2(-0.65, 0.32), Vector2(0.65, 0.32)]:
		k.box("wood", desk + Vector3(c.x, 0.38, c.y), Vector3(0.08, 0.76, 0.08), Basis.IDENTITY, false, 0.7)
	k.box("wood", desk + Vector3(0.1, 0.46, 0.75), Vector3(0.5, 0.06, 0.45), Basis.IDENTITY, false, 0.7)       # stool
	k.box("plaster", desk + Vector3(-0.2, 0.84, -0.05), Vector3(0.5, 0.04, 0.36), Basis(Vector3.UP, 0.15), false, 1.05)   # open day-book
	k.box("dark", desk + Vector3(-0.2, 0.865, -0.05), Vector3(0.01, 0.01, 0.34), Basis(Vector3.UP, 0.15), false, 0.2)
	# the sexton himself, slumped over it: skull on the boards, arms and ribs fallen round the stool
	k.skull(desk + Vector3(0.25, 0.84, 0.15), PI + 0.4, 1.0, 1, 0.9)
	for j in 6:
		k.bone(desk + Vector3(_rng.randf_range(-0.3, 0.5), 0.51 + 0.02 * float(j % 2), 0.6 + _rng.randf_range(-0.15, 0.15)), Basis(Vector3.UP, _rng.randf() * TAU), 1, false)
	k.bone(desk + Vector3(0.45, 0.85, 0.05), Basis(Vector3.UP, 1.2), 0, false)
	k.bone(desk + Vector3(-0.1, 0.03, 0.9), Basis(Vector3.UP, 0.4), 0, false)
	k.candle_cluster(desk + Vector3(-0.55, 0.82, 0.2), 3, 0.08, _rng)
	k.box("glow", desk + Vector3(0.6, 0.97, -0.25), Vector3(0.16, 0.24, 0.16), Basis.IDENTITY, false, 0.5)   # lantern
	k.box("iron", desk + Vector3(0.6, 1.11, -0.25), Vector3(0.2, 0.04, 0.2), Basis.IDENTITY, false)
	# strongbox by the flight's foot wall
	k.box("wood", Vector3(16.95, y + 0.25, -100.9), Vector3(0.7, 0.5, 0.45), Basis.IDENTITY, true, 0.7)
	k.box("iron", Vector3(16.95, y + 0.27, -100.9), Vector3(0.72, 0.06, 0.47), Basis.IDENTITY, false)
	area.call("_bone_heap", k, Vector3(14.1, y, -106.0), 0.55)
	for i in 7:
		k.candle_cluster(Vector3(_rng.randf_range(13.7, 17.4), y, _rng.randf_range(-106.2, -99.9)), _rng.randi_range(2, 6), 0.25, _rng)
	# piers under the room (the chapel's own piers stand at its corners)
	area.call("_pier", k, 15.0, -103.0, y - 0.6, 2.2)


## The chapel flight, the cells walk, the stair down under the pit, the north arm.
func _walks(k: OssKit) -> void:
	var n := Metrics.steps_for(CHAPEL_Y - CELL_Y)
	k.stairs("floor", Vector3(FLIGHT_X, CELL_Y, FLIGHT_FOOT_Z), Vector3(FLIGHT_X, CHAPEL_Y, FLIGHT_TOP_Z), FLIGHT_W, n, CELL_Y - 0.6)
	# its east side is the cells' wall; a rail down its west side where the drop is worth one
	var lo := Vector3(17.84, CELL_Y, FLIGHT_FOOT_Z)
	var hi := Vector3(17.84, CHAPEL_Y, FLIGHT_TOP_Z)
	var f := (hi - lo).normalized()
	var up := Vector3.RIGHT.cross(f).normalized()
	if up.y < 0.0:
		up = -up
	var r0 := lo.lerp(hi, 0.42)
	var r1 := hi.lerp(lo, 0.06)
	k.box("stone", (r0 + r1) * 0.5 + up * 0.45, Vector3(0.18, 0.9, r0.distance_to(r1)), _rb(Vector3.RIGHT, up, f))
	# and in the chapel, a kerb of skulls along the opening's west edge (the stairhead stays open)
	k.box("stone", Vector3(HOLE.position.x - 0.12, CHAPEL_Y + 0.2, HOLE.position.y + 1.6), Vector3(0.22, 0.4, 3.2), Basis.IDENTITY, true, 0.85)
	for i in 10:
		k.skull(Vector3(HOLE.position.x - 0.12, CHAPEL_Y + 0.4, HOLE.position.y + 0.15 + 0.31 * float(i)), -PI * 0.5, 0.9, 1)
	# the walk at y 0 (x 15.4..19.6, z -99..-96) and the stair down to the deep floor
	k.block("floor", Vector3(WALK.position.x, CELL_Y - 0.6, WALK.position.y), Vector3(WALK.end.x, CELL_Y, WALK.end.y))
	k.parapet("stone", Vector3(WALK.position.x, CELL_Y, WALK.end.y - 0.2), Vector3(16.7, CELL_Y, WALK.end.y - 0.2), 0.9, 0.3)
	k.parapet("stone", Vector3(WALK.end.x - 0.15, CELL_Y, WALK.position.y + 0.4), Vector3(WALK.end.x - 0.15, CELL_Y, WALK.end.y), 0.9, 0.3)
	k.parapet("stone", Vector3(WALK.position.x + 0.15, CELL_Y, WALK.position.y + 0.4), Vector3(WALK.position.x + 0.15, CELL_Y, WALK.end.y), 0.9, 0.3)
	var m := Metrics.steps_for(CELL_Y - D)
	k.stairs("floor", Vector3(18.0, D, DSTAIR_FOOT_Z), Vector3(18.0, CELL_Y, DSTAIR_HEAD_Z), 2.2, m, D - 0.6)
	for s: float in [-1.0, 1.0]:
		var a := Vector3(18.0 + s * 1.2, D, DSTAIR_FOOT_Z)
		var b := Vector3(18.0 + s * 1.2, CELL_Y, DSTAIR_HEAD_Z)
		var ff := (b - a).normalized()
		var uu := Vector3.RIGHT.cross(ff).normalized()
		if uu.y < 0.0:
			uu = -uu
		k.box("stone", (a + b) * 0.5 + uu * 0.45, Vector3(0.3, 0.9, (b - a).length() + 0.3), _rb(Vector3.RIGHT, uu, ff))
	# the north arm, flagged, with a skull-railed parapet each side, to the drum's rim
	k.block("floor", Vector3(16.8, D - 0.5, DSTAIR_FOOT_Z), Vector3(19.2, D, DRUM.z - DRUM_R + 0.2))
	for s: float in [-1.0, 1.0]:
		var px := 18.0 + s * 1.05
		k.parapet("stone", Vector3(px, D, DSTAIR_FOOT_Z), Vector3(px, D, DRUM.z - DRUM_R - 0.2), 0.8, 0.25)
		for i in 4:
			k.skull(Vector3(px, D + 0.82, DSTAIR_FOOT_Z + 0.6 + 1.0 * float(i)), -s * PI * 0.5, 0.95, 1)
	area.call("_pier", k, 18.0, -94.0, D - 0.5, 2.0)
	area.call("_pier", k, 17.5, -97.6, CELL_Y - 0.6, 2.0)


# --- the drum ---------------------------------------------------------------------------------

## Static parts: the floor disc, the central pier, the fixed lid and the spindle up into the pit.
func _drum_static(k: OssKit) -> void:
	var c := DRUM
	var n := 28
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * DRUM_R
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * DRUM_R
		k.quad("floor", c, p0, p1, c, Vector3.UP)
		var dn := Vector3.DOWN * 0.6
		k.quad("stone", c + dn, p1 + dn, p0 + dn, c + dn, Vector3.DOWN)
		var out := (Vector3(cos(a0), 0, sin(a0)) + Vector3(cos(a1), 0, sin(a1))).normalized()
		k.quad("stone", p0, p1, p1 + dn, p0 + dn, out)
		# the lid: a ring roof over the turning wall, and its rim
		var top := c.y + DRUM_H
		var q0 := c + Vector3(cos(a0), 0, sin(a0)) * (DRUM_R + 0.15) + Vector3.UP * (top + 0.05)
		var q1 := c + Vector3(cos(a1), 0, sin(a1)) * (DRUM_R + 0.15) + Vector3.UP * (top + 0.05)
		var r0 := c + Vector3(cos(a0), 0, sin(a0)) * 0.9 + Vector3.UP * (top + 0.75)
		var r1 := c + Vector3(cos(a1), 0, sin(a1)) * 0.9 + Vector3.UP * (top + 0.75)
		k.quad("slate", q0, q1, r1, r0, (out + Vector3.UP * 1.6).normalized(), false)
		k.quad("stone", q0 + Vector3.DOWN * 0.05, q1 + Vector3.DOWN * 0.05, r1 + Vector3.DOWN * 0.3, r0 + Vector3.DOWN * 0.3, Vector3.DOWN, false, 0.6)
	area.call("_pier", k, c.x, c.z, c.y - 0.6, 2.4)
	# the spindle: from the floor through the lid into the pit's underside, bound in bone
	k.block("stone", Vector3(c.x - 0.42, c.y, c.z - 0.42), Vector3(c.x + 0.42, 3.05, c.z + 0.42))
	k.block("stone", Vector3(c.x - 0.6, c.y, c.z - 0.6), Vector3(c.x + 0.6, c.y + 0.4, c.z + 0.6), true, 0.85)
	k.block("stone", Vector3(c.x - 0.95, c.y + DRUM_H + 0.7, c.z - 0.95), Vector3(c.x + 0.95, c.y + DRUM_H + 1.0, c.z + 0.95), false, 0.85)
	for i in 12:
		var a := TAU * float(i) / 12.0
		for j in 3:
			k.bone(c + Vector3(cos(a) * 0.45, 0.9 + 0.75 * float(j), sin(a) * 0.45), Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, PI * 0.5), 0, false)
	# the capstan: four bars through the spindle at waist height
	for i in 2:
		k.box("wood", c + Vector3(0, 1.05, 0), Vector3(2.1, 0.09, 0.09), Basis(Vector3.UP, float(i) * PI * 0.5 + 0.3), false, 0.8)
	for i in 4:
		var a := float(i) * PI * 0.5 + 0.3
		k.box("iron", c + Vector3(cos(a) * 1.0, 1.05, -sin(a) * 1.0), Vector3(0.12, 0.12, 0.12), Basis.IDENTITY, false)
	# a ring of candles on the floor round the spindle
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		k.candle_cluster(c + Vector3(cos(a), 0, sin(a)) * 1.55, 3, 0.12, _rng)


## The turning wall: an AnimatableBody so it carries what touches it, with its own mesh (no
## collision soup: box shapes round the ring, open at the door).
func _drum() -> void:
	drum_body = AnimatableBody3D.new()
	drum_body.name = "CountDrum"
	drum_body.sync_to_physics = true
	drum_body.collision_layer = Layers.WORLD
	drum_body.collision_mask = 0
	# placed BEFORE it enters the tree: a sync_to_physics body set afterwards is put back where its
	# physics body was created (the origin) on the next physics sync
	drum_body.position = DRUM
	add_child(drum_body)
	var k := OssKit.new()
	k.keep_lanes = false
	var n := 36
	var door_half := 0.34                # radians either side of local -z (1.6 m at r 3.2... with jambs)
	var slit_half := 0.05
	var rm := (DRUM_R + DRUM_IN) * 0.5
	var th := DRUM_R - DRUM_IN
	for i in n:
		var a := TAU * float(i) / float(n)
		var dir := Vector3(sin(a), 0, -cos(a))           # a = 0 is local -z (the door)
		var off_door := absf(angle_difference(a, 0.0))
		var off_slit := absf(angle_difference(a, PI))
		var seg := TAU * rm / float(n) + 0.03
		var b := _rb(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir)
		if off_door < door_half:
			k.box("stone", dir * rm + Vector3.UP * (DRUM_H - 0.4), Vector3(seg, 0.8, th), b, false, 0.9)   # over the door
			continue
		if off_slit < slit_half + 0.09:
			# the slit: wall below and above a narrow gap at beam height
			k.box("plaster", dir * rm + Vector3.UP * 0.55, Vector3(seg * 0.35, 1.1, th), b, false)
			k.box("plaster", dir * rm + Vector3.UP * (2.05 + (DRUM_H - 2.05) * 0.5), Vector3(seg * 0.35, DRUM_H - 2.05, th), b, false)
			for s: float in [-1.0, 1.0]:
				var side := dir.cross(Vector3.UP).normalized() * s * seg * 0.34
				k.box("plaster", dir * rm + side + Vector3.UP * DRUM_H * 0.5, Vector3(seg * 0.33, DRUM_H, th), b, false)
			var scs := CollisionShape3D.new()
			var sbs := BoxShape3D.new()
			sbs.size = Vector3(seg, DRUM_H, th + 0.1)
			scs.shape = sbs
			drum_body.add_child(scs)
			scs.transform = Transform3D(b, dir * rm + Vector3.UP * DRUM_H * 0.5)
			continue
		k.box("plaster", dir * rm + Vector3.UP * DRUM_H * 0.5, Vector3(seg, DRUM_H, th), b, false)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(seg, DRUM_H, th + 0.1)
		cs.shape = bs
		drum_body.add_child(cs)
		cs.transform = Transform3D(b, dir * rm + Vector3.UP * DRUM_H * 0.5)
	# the door's jambs and pointed head, the slit's bronze frame, ribs and skull bands outside
	var door_dir := Vector3(0, 0, -1)
	var door_b := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	for s: float in [-1.0, 1.0]:
		var jam := Vector3(sin(s * door_half), 0, -cos(s * door_half)) * (DRUM_R + 0.05)
		k.box("stone", jam + Vector3.UP * 1.4, Vector3(0.3, 2.8, th + 0.2), Basis(Vector3.UP, -s * door_half) * door_b, false, 0.85)
	k.box("stone", door_dir * (DRUM_R + 0.06) + Vector3.UP * 2.85, Vector3(2.1, 0.3, 0.3), door_b, false, 0.85)
	k.box("iron", Vector3(0, 1.5, DRUM_R + 0.05), Vector3(0.36, 1.2, 0.06), Basis.IDENTITY, false, 0.6)
	for i in 12:
		var a := TAU * float(i) / 12.0 + PI / 12.0
		var dir2 := Vector3(sin(a), 0, -cos(a))
		if absf(angle_difference(a, 0.0)) < door_half + 0.15 or absf(angle_difference(a, PI)) < 0.2:
			continue
		var b2 := _rb(dir2.cross(Vector3.UP).normalized(), Vector3.UP, dir2)
		k.box("stone", dir2 * (DRUM_R + 0.08) + Vector3.UP * DRUM_H * 0.5, Vector3(0.28, DRUM_H, 0.22), b2, false, 0.8)
	for i in 40:
		var a := TAU * (float(i) + 0.5) / 40.0
		if absf(angle_difference(a, 0.0)) < door_half + 0.08 or absf(angle_difference(a, PI)) < 0.12:
			continue
		var dir3 := Vector3(sin(a), 0, -cos(a))
		for row: float in [1.15, 2.35]:
			k.skull(dir3 * (DRUM_R + 0.04) + Vector3.UP * row, atan2(dir3.x, dir3.z), 0.95, int(row > 2.0))
	# the skin is written in drum-local space; a pivot child puts it back in world space at rest so
	# every mesh's AABB means the same as its neighbours' (audits read them as world boxes)
	var skin := Node3D.new()
	skin.name = "Skin"
	drum_body.add_child(skin)
	k.commit(skin, "DrumMeshBody")
	drum_body.rotation.y = _drum_angle(int(deep().drum))
	# the capstan: turn the count a quarter (clockwise seen from above: N, E, S, W)
	var t := OssWorld.touch(self, DRUM + Vector3(0.0, 1.0, 1.1), "", func(_by: Node) -> void: turn_drum(), 1.6)
	t.name = "Capstan"
	t.set("prompt_fn", func() -> String:
		return "" if _drum_turning else "Turn the count")


static func _drum_angle(state: int) -> float:
	return -float(posmod(state, 4)) * PI * 0.5


func turn_drum(instant := false) -> void:
	if _drum_turning:
		return
	var d := deep()
	var s := posmod(int(d.drum) + 1, 4)
	d.drum = s
	if instant:
		drum_body.rotation.y = _drum_angle(s)
		_trace(false)
		return
	_drum_from = drum_body.rotation.y
	_drum_to = _drum_from - PI * 0.5
	_drum_t = 0.0
	_drum_turning = true
	OssWorld.play("grind", DRUM, 0.0, 0.7)
	OssWorld.play("clank", DRUM + Vector3.UP * 1.0, -4.0, 0.6)
	OssWorld.fx_dust(DRUM + Vector3.UP * DRUM_H, Color(0.45, 0.42, 0.4, 0.6), 30)
	_clear_beam()


func _physics_process(delta: float) -> void:
	if _drum_turning:
		_drum_t = minf(_drum_t + delta / 2.6, 1.0)
		drum_body.rotation.y = lerpf(_drum_from, _drum_to, smoothstep(0.0, 1.0, _drum_t))
		if _drum_t >= 1.0:
			_drum_turning = false
			drum_body.rotation.y = _drum_angle(int(deep().drum))
			OssWorld.play("clank", DRUM, -2.0, 0.5)
			_trace(true)
	if _arena_on:
		_arena_tick()


# --- east: the pool window -------------------------------------------------------------------

func _east(k: OssKit) -> void:
	var y := D
	# arm from the drum's rim to the platform
	k.block("floor", Vector3(DRUM.x + DRUM_R - 0.2, y - 0.5, -85.2), Vector3(E_PLAT.position.x, y, -82.8))
	# platform round a grated hole under the mirror (the fire's light comes up through it)
	var hx0 := E_MIRROR.x - 0.45
	var hx1 := E_MIRROR.x + 0.45
	var hz0 := E_MIRROR.y - 0.45
	var hz1 := E_MIRROR.y + 0.45
	var px0 := E_PLAT.position.x
	var px1 := E_PLAT.end.x
	var pz0 := E_PLAT.position.y
	var pz1 := E_PLAT.end.y
	k.block("floor", Vector3(px0, y - 0.5, pz0), Vector3(px1, y, hz0))
	k.block("floor", Vector3(px0, y - 0.5, hz1), Vector3(px1, y, pz1))
	k.block("floor", Vector3(px0, y - 0.5, hz0), Vector3(hx0, y, hz1))
	k.block("floor", Vector3(hx1, y - 0.5, hz0), Vector3(px1, y, hz1))
	for i in 5:
		var gx := hx0 + 0.09 + 0.18 * float(i)
		k.box("iron", Vector3(gx, y - 0.04, E_MIRROR.y), Vector3(0.05, 0.08, 0.9), Basis.IDENTITY, false)
	k.box("iron", Vector3(E_MIRROR.x, y - 0.05, E_MIRROR.y), Vector3(0.9, 0.04, 0.9), Basis.IDENTITY, true, 0.4)   # the grating (walkable)
	k.parapet("stone", Vector3(px1 - 0.15, y, pz0), Vector3(px1 - 0.15, y, pz1), 0.9, 0.3)
	k.parapet("stone", Vector3(px0, y, pz0 + 0.15), Vector3(px1, y, pz0 + 0.15), 0.9, 0.3)
	k.parapet("stone", Vector3(px0, y, pz1 - 0.15), Vector3(px1, y, pz1 - 0.15), 0.9, 0.3)
	area.call("_pier", k, E_PLAT.get_center().x + 0.4, pz1 - 0.8, y - 0.5, 1.6)
	k.candle_cluster(Vector3(px1 - 0.45, y, pz0 + 0.5), 4, 0.15, _rng)
	k.candle_cluster(Vector3(px1 - 0.45, y, pz1 - 0.5), 3, 0.15, _rng)
	# the drowned lamp's light rising through the grate to the mirror: always there (a lamp the sexton sank in the pool)
	var shaft := Node3D.new()
	shaft.name = "FireShaft"
	add_child(shaft)
	OssWorld.beam_segment(shaft, Vector3(E_MIRROR.x, OssFrame.POOL_Y + 0.3, E_MIRROR.y), Vector3(E_MIRROR.x, BEAM_Y, E_MIRROR.y), 0.55)


# --- west: the landing and the Abbot's hoard ---------------------------------------------------

func _west(k: OssKit) -> void:
	var y := D
	k.block("floor", Vector3(W_PLAT.end.x, y - 0.5, -85.2), Vector3(DRUM.x - DRUM_R + 0.2, y, -82.8))
	for s: float in [-1.0, 1.0]:
		k.parapet("stone", Vector3(W_PLAT.end.x, y, -84.0 + s * 1.05), Vector3(DRUM.x - DRUM_R - 0.2, y, -84.0 + s * 1.05), 0.8, 0.25)
	k.block("floor", Vector3(W_PLAT.position.x, y - 0.5, W_PLAT.position.y), Vector3(W_PLAT.end.x, y, W_PLAT.end.y))
	k.parapet("stone", Vector3(W_PLAT.position.x + 0.15, y, W_PLAT.position.y + 0.2), Vector3(W_PLAT.position.x + 0.15, y, W_PLAT.end.y), 0.9, 0.3)
	k.parapet("stone", Vector3(W_PLAT.position.x, y, W_PLAT.end.y - 0.15), Vector3(W_PLAT.end.x, y, W_PLAT.end.y - 0.15), 0.9, 0.3)
	k.parapet("stone", Vector3(W_PLAT.end.x - 0.15, y, -82.6), Vector3(W_PLAT.end.x - 0.15, y, W_PLAT.end.y), 0.9, 0.3)
	k.parapet("stone", Vector3(W_PLAT.end.x - 0.15, y, W_PLAT.position.y + 0.4), Vector3(W_PLAT.end.x - 0.15, y, -85.4), 0.9, 0.3)
	area.call("_pier", k, 7.4, -82.6, y - 0.5, 1.8)
	area.call("_pier", k, 12.6, -84.0, y - 0.5, 1.6)
	# the hoard: a squat vault of dressed stone with a bone-tiled roof
	var x0 := HOARD.position.x
	var x1 := HOARD.end.x
	var z0 := HOARD.position.y
	var z1 := HOARD.end.y
	var h := 3.4
	var t := 0.7
	k.block("floor", Vector3(x0, y - 0.6, z0), Vector3(x1, y, z1))
	area.call("_wall", k, "stone", Vector3(x0, y, z1), Vector3(x1, y, z1), h, t, [{"at": HOARD_DOOR_X - x0, "w": 1.6, "spring": 2.1, "k": 0.8}], Vector3.FORWARD, "stone", true)
	area.call("_wall", k, "stone", Vector3(x1, y, z1), Vector3(x1, y, z0), h, t, [], Vector3.LEFT, "stone", true)
	area.call("_wall", k, "stone", Vector3(x1, y, z0), Vector3(x0, y, z0), h, t, [
		{"at": 1.6, "w": 1.0, "spring": 1.2, "sill": 0.7, "niche": true, "k": 0.7},
		{"at": 3.4, "w": 1.0, "spring": 1.2, "sill": 0.7, "niche": true, "k": 0.7},
		{"at": 5.2, "w": 1.0, "spring": 1.2, "sill": 0.7, "niche": true, "k": 0.7},
	], Vector3.BACK, "stone", true)
	area.call("_wall", k, "stone", Vector3(x0, y, z0), Vector3(x0, y, z1), h, t, [], Vector3.RIGHT, "stone", true)
	k.block("dark", Vector3(x0, y + h, z0), Vector3(x1, y + h + 0.3, z1), true, 0.7)
	for p: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		area.call("_pier", k, p.x, p.y, y - 0.6, 1.6)
		k.pinnacle("stone", Vector3(p.x, y + h + 0.3, p.y), 0.6, 0.6, 1.0)
	# inside: caskets on a stepped dais, gilded skulls, candles everywhere
	k.block("stone", Vector3(x0 + 1.0, y, z0 + 0.4), Vector3(x1 - 1.0, y + 0.3, z0 + 2.4), true, 0.85)
	k.block("stone", Vector3(x0 + 1.6, y + 0.3, z0 + 0.4), Vector3(x1 - 1.6, y + 0.6, z0 + 1.6), true, 0.8)
	for cx: float in [5.4, 6.3, 8.5, 9.4]:
		var cz := z0 + 2.0
		k.box("wood", Vector3(cx, y + 0.52, cz), Vector3(0.7, 0.44, 0.4), Basis(Vector3.UP, _rng.randf_range(-0.1, 0.1)), false, 0.65)
		k.box("iron", Vector3(cx, y + 0.75, cz), Vector3(0.74, 0.05, 0.44), Basis.IDENTITY, false, 0.9)
		k.skull(Vector3(cx, y + 0.78, cz), _rng.randf_range(-0.3, 0.3), 1.0, 1)
	for i in 10:
		k.candle_cluster(Vector3(_rng.randf_range(x0 + 1.0, x1 - 1.0), y + (0.6 if i < 4 else 0.0), _rng.randf_range(z0 + 0.6, z1 - 1.0) if i >= 4 else z0 + 1.0), _rng.randi_range(3, 7), 0.25, _rng)
	area.call("_bone_dado", k, Vector3(x0 + t * 0.5, y, z0 + 0.5), Vector3(x0 + t * 0.5, y, z1 - 0.5), Vector3.RIGHT, [0.47, -0.66])
	area.call("_bone_dado", k, Vector3(x1 - t * 0.5, y, z0 + 0.5), Vector3(x1 - t * 0.5, y, z1 - 0.5), Vector3.LEFT, [0.47, -0.66])
	# the sun-eye beside the door: a bronze disc on the facade
	k.box("stone", Vector3(EYE.x, BEAM_Y, z1 + 0.42), Vector3(0.95, 0.95, 0.14), Basis.IDENTITY, false, 0.85)


# --- the Weighing Floor -----------------------------------------------------------------------

func _arena(k: OssKit) -> void:
	var c := ARENA
	var n := 40
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * ARENA_R
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * ARENA_R
		k.quad("floor", c, p0, p1, c, Vector3.UP)
		var dn := Vector3.DOWN * 0.8
		k.quad("stone", c + dn, p1 + dn, p0 + dn, c + dn, Vector3.DOWN)
		var out := (Vector3(cos(a0), 0, sin(a0)) + Vector3(cos(a1), 0, sin(a1))).normalized()
		k.quad("stone", p0, p1, p1 + dn, p0 + dn, out)
	# parapet with two gaps: north (the bone bridge) and south (the cage walk)
	var gaps := [atan2(-1.0, 0.45), atan2(1.0, -0.06)]
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var am := (a0 + a1) * 0.5
		var skip := false
		for g: float in gaps:
			if absf(angle_difference(am, g)) < 0.24:
				skip = true
		var pm := c + Vector3(cos(am), 0, sin(am)) * (ARENA_R - 0.25)
		if skip or not _arena_rim_free(Vector2(pm.x, pm.z)):
			continue
		k.parapet("stone", c + Vector3(cos(a0), 0, sin(a0)) * (ARENA_R - 0.25), c + Vector3(cos(a1), 0, sin(a1)) * (ARENA_R - 0.25), 0.85, 0.35)
	area.call("_pier", k, c.x, c.z, c.y - 0.8, 2.6)
	for a: float in [0.6, 2.2, 3.7]:
		area.call("_pier", k, c.x + cos(a) * 3.8, c.z + sin(a) * 3.8, c.y - 0.8, 1.4)
	# the Weighing: a bronze-capped post, a beam, two pans on chains; skulls on the low pan
	var w := c + Vector3(-1.4, 0, 1.2)
	k.block("stone", w + Vector3(-0.5, 0, -0.5), w + Vector3(0.5, 0.4, 0.5), true, 0.85)
	k.box("iron", w + Vector3(0, 1.6, 0), Vector3(0.18, 2.4, 0.18), Basis.IDENTITY, true)
	var tilt := 0.22
	var beam_b := Basis(Vector3.BACK, tilt)
	k.box("iron", w + Vector3(0, 2.8, 0), Vector3(2.6, 0.12, 0.12), beam_b, false)
	for s: float in [-1.0, 1.0]:
		var end := w + Vector3(0, 2.8, 0) + beam_b * Vector3(s * 1.25, 0, 0)
		var pan_y := end.y - 1.3
		for q in 3:
			var qa := TAU * float(q) / 3.0
			var foot := Vector3(end.x + cos(qa) * 0.36, pan_y, end.z + sin(qa) * 0.36)
			var mid := (end + foot) * 0.5
			k.box("iron", mid, Vector3(0.025, end.distance_to(foot), 0.025), Basis(Quaternion(Vector3.UP, (end - foot).normalized())), false)
		k.box("iron", Vector3(end.x, pan_y, end.z), Vector3(0.8, 0.06, 0.8), Basis(Vector3.UP, 0.4), false)
		if s < 0.0:
			for j in 3:
				k.skull(Vector3(end.x - 0.15 + 0.15 * float(j), pan_y + 0.03, end.z + _rng.randf_range(-0.15, 0.15)), _rng.randf() * TAU, 0.9, j % 2)
		else:
			k.box("stone", Vector3(end.x, pan_y + 0.2, end.z), Vector3(0.36, 0.36, 0.36), Basis(Vector3.UP, 0.3), false, 0.5)
	# bone heaps at the rim, candles in rings, a grave-slab floor pattern
	for a: float in [1.2, 2.9, 4.4, 5.6]:
		area.call("_bone_heap", k, c + Vector3(cos(a), 0, sin(a)) * 4.3, 0.6)
	for i in 16:
		var a := TAU * float(i) / 16.0
		k.candle_cluster(c + Vector3(cos(a), 0, sin(a)) * 4.9, _rng.randi_range(2, 4), 0.12, _rng)
	for r: float in [2.4, 3.6]:
		for i in 24:
			var a := TAU * float(i) / 24.0
			k.box("dark", c + Vector3(cos(a) * r, 0.006, sin(a) * r), Vector3(0.05, 0.01, 0.6), Basis(Vector3.UP, -a), false, 0.3)
	# the walk south to the cage
	k.block("floor", Vector3(14.0, D - 0.5, c.z + ARENA_R - 0.4), Vector3(16.4, D, LIFT_AT.z - 1.2))
	k.parapet("stone", Vector3(14.15, D, c.z + ARENA_R - 0.2), Vector3(14.15, D, LIFT_AT.z - 1.2), 0.85, 0.3)


func _arena_rim_free(p: Vector2) -> bool:
	# the gallery's pier stands in the floor's north-east; the gallery stair's pier at its rim
	for q: Rect2 in [Rect2(16.0, -68.5, 3.0, 3.0), Rect2(19.3, -74.2, 3.4, 3.4)]:
		if q.has_point(p):
			return false
	return true


# --- the slab, the bridge, the wheels, the mirrors, the doors ----------------------------------

func _slab() -> void:
	var holder := Node3D.new()
	holder.name = "SextonSlab"
	add_child(holder)
	var stones: Array[MeshInstance3D] = []
	var nseg := 3
	var seg_len := HOLE.size.y / float(nseg)
	for i in nseg:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(HOLE.size.x - 0.04, 0.22, seg_len - 0.04)
		mi.mesh = bm
		mi.material_override = OssKit.mat("floor")
		holder.add_child(mi)
		mi.position = Vector3(HOLE.get_center().x, CHAPEL_Y - 0.11, HOLE.position.y + seg_len * (float(i) + 0.5))
		stones.append(mi)
	# the cut words on the middle stone and a cold seep of air at the seams (until opened)
	var words := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.9, 0.012, 0.5)
	words.mesh = wm
	words.material_override = OssKit.mat("dark")
	stones[1].add_child(words)
	words.position = Vector3(0, 0.11, 0)
	var body := OssWorld.box_body(holder, Vector3(HOLE.get_center().x, CHAPEL_Y - 0.15, HOLE.get_center().y), Vector3(HOLE.size.x, 0.3, HOLE.size.y))
	var seep: Array[Node3D] = []
	for i in 3:
		seep.append(OssWorld.glint(holder, Vector3(HOLE.position.x + 0.2 + 0.6 * float(i), CHAPEL_Y + 0.12, HOLE.position.y + 0.1 + seg_len * float(i + 1) - 0.05), Color(0.55, 0.75, 1.0), 0.22, 18.0))
	var t := OssWorld.touch(self, Vector3(HOLE.get_center().x - 0.3, CHAPEL_Y + 0.6, HOLE.get_center().y), "", func(_by: Node) -> void:
		if State.has("open", "deep_slab"):
			return
		if not Travel.bosses_slain.has("bone_abbot"):
			OssWorld.play("clank", Vector3(HOLE.get_center().x, CHAPEL_Y, HOLE.get_center().y), -6.0, 0.7)
			State.toast("It will not shift. Somewhere under it, something is still counting.")
			return
		State.mark("open", "deep_slab")
		State.toast("The slab gives. A stair goes down into the count.")
		State.banner("the floor gives way", "The Lower Count")
		sync(true), 2.0)
	t.name = "Slab"
	t.set("prompt_fn", func() -> String:
		return "" if State.has("open", "deep_slab") else "Heave the sexton's slab")
	_sync.append(func(animate: bool) -> void:
		var open := State.has("open", "deep_slab")
		Kit.set_body(body, not open)
		for g in seep:
			if is_instance_valid(g):
				g.visible = not open
		if not open:
			return
		if animate:
			OssWorld.play("grind", Vector3(HOLE.get_center().x, CHAPEL_Y, HOLE.get_center().y), 2.0, 0.6)
			for i in stones.size():
				var s := stones[i]
				var tw := s.create_tween()
				tw.tween_interval(0.25 * float(i))
				tw.tween_property(s, "position:y", s.position.y - 0.35, 0.5).set_trans(Tween.TRANS_SINE)
				tw.tween_property(s, "position", s.position + Vector3(-0.2, -7.0, 0.4 * float(i - 1)), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(s, "rotation", Vector3(0.9 * float(i - 1), 0.0, 1.2), 0.9)
				tw.tween_callback(func() -> void:
					s.visible = false
					OssWorld.play("clank", OssFrame.l(s.global_position), 0.0, 0.5))
			OssWorld.fx_dust(Vector3(HOLE.get_center().x, CHAPEL_Y + 0.3, HOLE.get_center().y), Color(0.5, 0.48, 0.45, 0.7), 60)
		else:
			for s in stones:
				s.visible = false)


## The bone bridge (drum south -> the Weighing Floor): its plates hang far below until the
## wheels are right, then rise one after another.
func _bridge() -> void:
	var holder := Node3D.new()
	holder.name = "BoneBridge"
	add_child(holder)
	var plate: ArrayMesh = area.call("_plate_mesh")
	var rib_l: ArrayMesh = area.call("_rib_mesh", -1)
	var rib_r: ArrayMesh = area.call("_rib_mesh", 1)
	var bm := OssKit.mat("bone_cm")
	var st := SurfaceTool.new()               # plate and its two ribs as one mesh: one draw a plate
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(plate, 0, Transform3D.IDENTITY)
	st.append_from(rib_l, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.38)))
	st.append_from(rib_r, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.38)))
	var whole := st.commit()
	var n := 9
	var up_xf: Array[Transform3D] = []
	var down_xf: Array[Transform3D] = []
	var x := S_BRIDGE.get_center().x
	for i in n:
		var z := S_BRIDGE.position.y + (float(i) + 0.5) * S_BRIDGE.size.y / float(n)
		var up := Transform3D(Basis(Vector3.UP, PI * 0.5 + _rng.randf_range(-0.04, 0.04)) * Basis.from_scale(Vector3(1.0, 1.0, 0.72)), Vector3(x, D, z))
		var down := Transform3D(Basis(Vector3.UP, PI * 0.5 + _rng.randf_range(-0.5, 0.5)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.7, 0.7)), Vector3(x + _rng.randf_range(-0.8, 0.8), D - 7.5 - float(i % 3) * 1.4, z))
		up_xf.append(up)
		down_xf.append(down)
	# all nine plates are one MultiMesh (one draw); the rise tweens each instance's transform
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = whole
	mm.instance_count = n
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Plates"
	mmi.multimesh = mm
	mmi.material_override = bm
	mmi.visibility_range_end = 70.0
	holder.add_child(mmi)
	var body := OssWorld.box_body(holder, Vector3(x, D - 0.25, S_BRIDGE.get_center().y), Vector3(S_BRIDGE.size.x, 0.5, S_BRIDGE.size.y + 0.4))
	var rails: Array[StaticBody3D] = []
	for s: float in [-1.0, 1.0]:
		rails.append(OssWorld.box_body(holder, Vector3(x + s * 1.05, D + 0.6, S_BRIDGE.get_center().y), Vector3(0.14, 1.2, S_BRIDGE.size.y)))
	_sync.append(func(animate: bool) -> void:
		var up := State.has("solved", "deep_dials")
		Kit.set_body(body, up)
		for r in rails:
			Kit.set_body(r, up)
		for i in n:
			var to: Transform3D = up_xf[i] if up else down_xf[i]
			if animate and up:
				var from: Transform3D = down_xf[i]
				var tw := mmi.create_tween()
				tw.tween_interval(0.35 * float(i))
				tw.tween_method(func(u: float) -> void: mm.set_instance_transform(i, from.interpolate_with(to, u)), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_callback(func() -> void: OssWorld.play("clank", to.origin, -6.0, 0.8 + 0.05 * float(i)))
			else:
				mm.set_instance_transform(i, to)
		if animate and up:
			OssWorld.play("grind", Vector3(x, D, S_BRIDGE.get_center().y), 2.0, 0.6))


## The three bronze wheels under the shelves. Each shows its count with lit studs (1..5).
func _dials() -> void:
	var holder := Node3D.new()
	holder.name = "CountWheels"
	add_child(holder)
	var stud := BoxMesh.new()
	stud.size = Vector3(0.05, 0.07, 0.07)
	var stud_mat := StandardMaterial3D.new()
	stud_mat.vertex_color_use_as_albedo = true
	stud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var wheels: Array[MeshInstance3D] = []
	var studs: Array[MultiMesh] = []
	for i in SHELVES.size():
		var sz: float = SHELVES[i][0]
		var face := 12.0 + 0.35
		var c := Vector3(face + 0.1, CELL_Y + 0.62, sz)
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.26
		cyl.bottom_radius = 0.26
		cyl.height = 0.08
		cyl.radial_segments = 10              # a ten-sided wheel: its turning reads
		wheel.mesh = cyl
		wheel.material_override = Kit.mat("bronze")
		holder.add_child(wheel)
		wheel.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), c)
		var wst := SurfaceTool.new()               # the wheel and its bronze handle, one mesh
		wst.begin(Mesh.PRIMITIVE_TRIANGLES)
		wst.append_from(cyl, 0, Transform3D.IDENTITY)
		var hb := BoxMesh.new()
		hb.size = Vector3(0.06, 0.4, 0.06)
		wst.append_from(hb, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0.17)))
		wheel.mesh = wst.commit()
		wheels.append(wheel)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = stud
		mm.instance_count = 5
		for j in 5:
			mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, Vector3(face + 0.03, CELL_Y + 0.95, sz - 0.3 + 0.15 * float(j))))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = stud_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)
		studs.append(mm)
		var idx := i
		var t := OssWorld.touch(holder, c + Vector3(0.3, 0.2, 0), "", func(_by: Node) -> void: turn_wheel(idx), 1.5)
		t.name = "Wheel_%d" % i
		t.set("prompt_fn", func() -> String:
			if State.has("solved", "deep_dials"):
				return ""
			return "Turn the %s wheel  (%d)" % [["first", "second", "third"][idx], int((deep().dials as Array)[idx])])
	_sync.append(func(_animate: bool) -> void:
		var vals: Array = deep().dials
		var solved := State.has("solved", "deep_dials")
		for i in wheels.size():
			var v := int(vals[i])
			wheels[i].basis = Basis(Vector3.RIGHT, float(v) * TAU / 5.0) * Basis(Vector3.FORWARD, PI * 0.5)
			for j in 5:
				var on := j < v
				var col := Color(1.0, 0.55, 0.22) * (1.25 if solved else 1.0) if on else Color(0.07, 0.05, 0.04)
				studs[i].set_instance_color(j, col))


func turn_wheel(i: int) -> void:
	if State.has("solved", "deep_dials"):
		return
	var vals: Array = deep().dials
	vals[i] = int(vals[i]) % 5 + 1
	OssWorld.play("clank", Vector3(12.5, CELL_Y + 0.7, float(SHELVES[i][0])), -8.0, 0.9 + 0.1 * float(vals[i]))
	var ok := true
	for j in SHELVES.size():
		if int(vals[j]) != int(SHELVES[j][1]):
			ok = false
	if ok:
		State.mark("solved", "deep_dials")
		OssWorld.play("chime", Vector3(13.0, CELL_Y + 1.0, -103.4), -2.0)
		State.toast("Four, two, five. Far below, chains take up a weight.")
		State.banner("the count is true", "The Uncounted Cells")
	sync(ok)


func _mirrors() -> void:
	_mirror_e = _mirror("MirrorE", Vector3(E_MIRROR.x, D, E_MIRROR.y), "mirror_e")
	_mirror_w = _mirror("MirrorW", Vector3(W_MIRROR.x, D, W_MIRROR.y), "mirror_w")
	_beam_holder = Node3D.new()
	_beam_holder.name = "CaughtLight"
	add_child(_beam_holder)
	# the sun-eye: a ring and a crystal that wakes when the light reaches it
	var eye := Node3D.new()
	eye.name = "SunEye"
	add_child(eye)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.26
	tor.outer_radius = 0.38
	ring.mesh = tor
	ring.material_override = Kit.mat("bronze")
	eye.add_child(ring)
	ring.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(EYE.x, BEAM_Y, HOARD.end.y + 0.52))
	_eye_mi = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.17
	sph.height = 0.34
	_eye_mi.mesh = sph
	_eye_mi.material_override = Kit.mat("lamp_dark")
	eye.add_child(_eye_mi)
	_eye_mi.position = Vector3(EYE.x, BEAM_Y, HOARD.end.y + 0.55)
	var rays := SurfaceTool.new()
	rays.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rb := BoxMesh.new()
	rb.size = Vector3(0.05, 0.22, 0.03)
	rays.append_from(tor, 0, Transform3D.IDENTITY)
	for i in 8:
		var a := TAU * float(i) / 8.0
		# in the ring's frame (rotated a quarter about x): the rays lie in its local xz plane
		rays.append_from(rb, 0, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cos(a + PI * 0.5) * 0.5, 0.0, -sin(a + PI * 0.5) * 0.5)))
	ring.mesh = rays.commit()


func _mirror(n: String, base: Vector3, key: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = n
	add_child(holder)
	var k := OssKit.new()
	k.keep_lanes = false
	# a tripod of iron over the grate (east) or a stone drum (west), the yoke on top
	for i in 3:
		var a := TAU * float(i) / 3.0
		var foot := base + Vector3(cos(a) * 0.55, 0, sin(a) * 0.55)
		var top := base + Vector3(0, BEAM_Y - base.y - 0.55, 0)
		k.box("iron", (foot + top) * 0.5, Vector3(0.06, foot.distance_to(top), 0.06), Basis(Quaternion(Vector3.UP, (top - foot).normalized())), false)
	k.box("iron", base + Vector3(0, BEAM_Y - base.y - 0.55, 0), Vector3(0.22, 0.12, 0.22), Basis.IDENTITY, false)
	k.commit(holder, "MirrorBody")
	var head := Node3D.new()
	head.name = "Head"
	holder.add_child(head)
	head.position = Vector3(base.x, BEAM_Y, base.z)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.05
	cyl.radial_segments = 24
	disc.mesh = cyl
	var mm := Kit.mat("bronze").duplicate() as StandardMaterial3D
	mm.metallic = 0.45
	mm.metallic_specular = 0.8
	mm.roughness = 0.35
	mm.albedo_color = Color(1.0, 0.82, 0.55)
	mm.emission_enabled = true                  # polished: it holds a little of the fire it catches
	mm.emission = Color(1.0, 0.5, 0.2)
	mm.emission_energy_multiplier = 0.08
	disc.material_override = mm
	head.add_child(disc)
	# the disc stands upright, facing the way it throws the light (local -z), tilted a little down
	disc.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	var yoke := MeshInstance3D.new()             # the yoke and its two arms, one mesh
	var yst := SurfaceTool.new()
	yst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var yb := BoxMesh.new()
	yb.size = Vector3(1.0, 0.06, 0.06)
	yst.append_from(yb, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0.05)))
	var ab := BoxMesh.new()
	ab.size = Vector3(0.06, 0.55, 0.06)
	for s: float in [-1.0, 1.0]:
		yst.append_from(ab, 0, Transform3D(Basis.IDENTITY, Vector3(s * 0.48, -0.25, 0.05)))
	yoke.mesh = yst.commit()
	yoke.material_override = OssKit.mat("iron")
	head.add_child(yoke)
	head.rotation.y = _mirror_yaw(int(deep()[key]))
	var t := OssWorld.touch(holder, base + Vector3(0, 1.0, 0), "", func(_by: Node) -> void:
		var d := deep()
		d[key] = posmod(int(d[key]) - 1, 8)
		OssWorld.play("creak", base + Vector3.UP, -6.0, 1.3)
		var tw := head.create_tween()
		tw.tween_property(head, "rotation:y", head.rotation.y - PI * 0.25, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			head.rotation.y = _mirror_yaw(int(d[key]))
			_trace(true))
		_clear_beam(), 1.7)
	t.name = "Turn" + n
	t.set("prompt_fn", func() -> String: return "Turn the bronze mirror")
	return holder


## A mirror's head yaw for its direction index (Beam.dir8: 0 = +x, 2 = -z ...): its -z faces it.
static func _mirror_yaw(i: int) -> float:
	var d := Beam.dir8(i)
	return atan2(-d.x, -d.y)


func _clear_beam() -> void:
	if _beam_holder:
		for c in _beam_holder.get_children():
			c.queue_free()


## Trace the caught light from the east mirror; open the hoard when it reaches the eye.
func _trace(animate: bool) -> void:
	if _beam_holder == null or _drum_turning:
		return
	var d := deep()
	var drum_open_ew := posmod(int(d.drum), 2) == 1
	var els: Array = [
		{"kind": "mirror", "id": "w", "at": W_MIRROR, "r": 0.45, "out": Beam.dir8(int(d.mirror_w))},
		{"kind": "block", "id": "drum", "at": Vector2(DRUM.x, DRUM.z), "r": DRUM_R,
			"pass": func(dir: Vector2) -> bool: return drum_open_ew and absf(dir.y) < 0.05},
		{"kind": "target", "id": "eye", "at": EYE, "r": 0.4},
		{"kind": "block", "id": "hoard", "at": Vector2(HOARD.get_center().x, HOARD.get_center().y - 0.6), "r": 3.0},
		{"kind": "block", "id": "cliff", "at": Vector2(30.0, -84.0), "r": 6.2},
		{"kind": "block", "id": "pier_ne", "at": Vector2(21.9, -91.9), "r": 1.1},
		{"kind": "block", "id": "pier_se", "at": Vector2(21.0, -78.6), "r": 1.7},
		{"kind": "block", "id": "cells", "at": Vector2(16.0, -103.0), "r": 4.6},
	]
	# (a free run stops at 16 m: the light thins in the dark)
	var res := Beam.trace(E_MIRROR, Beam.dir8(int(d.mirror_e)), els, 16.0)
	var pts: Array = res.pts
	OssWorld.beam_draw(_beam_holder, pts, BEAM_Y)
	var lit := String(res.hit) == "eye"
	_eye_mi.material_override = Kit.mat("lamp_glass" if lit or State.has("solved", "deep_beam") else "lamp_dark")
	if lit and not State.has("solved", "deep_beam"):
		State.mark("solved", "deep_beam")
		State.mark("open", "deep_hoard_door")
		OssWorld.play("chime", Vector3(EYE.x, BEAM_Y, EYE.y), 0.0)
		State.toast("The sun-eye takes the light. The Abbot's door lifts.")
		State.banner("light in the dark", "The Abbot's Hoard")
		sync(true)


func _hoard_door() -> void:
	var holder := Node3D.new()
	holder.name = "HoardDoor"
	add_child(holder)
	var k := OssKit.new()
	k.keep_lanes = false
	var z := HOARD.end.y
	for i in 7:
		var bx := HOARD_DOOR_X - 0.6 + 0.2 * float(i)
		k.bone(Vector3(bx, D + 1.1, z), Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * 5.6), 0, false)
	for yy: float in [0.4, 1.3, 2.0]:
		k.box("iron", Vector3(HOARD_DOOR_X, D + yy, z), Vector3(1.5, 0.07, 0.08), Basis.IDENTITY, false)
	k.commit(holder, "DoorUnused")
	var body := OssWorld.box_body(self, Vector3(HOARD_DOOR_X, D + 1.2, z), Vector3(1.6, 2.4, 0.4))
	_sync.append(func(animate: bool) -> void:
		var open := State.has("solved", "deep_beam")
		Kit.set_body(body, not open)
		var to := 2.3 if open else 0.0
		if animate and open and holder.position.y < 2.0:
			OssWorld.play("grind", Vector3(HOARD_DOOR_X, D + 1.0, z), 0.0, 1.2)
			holder.create_tween().tween_property(holder, "position:y", to, 2.4).set_trans(Tween.TRANS_SINE)
		else:
			holder.position.y = to)
	# the hoard itself
	var lid_at := Vector3(7.4, D + 0.6, HOARD.position.y + 1.0)
	var lid := OssWorld.mi(self, _box(Vector3(1.0, 0.12, 0.6)), OssKit.mat("wood"), Transform3D(Basis.IDENTITY, lid_at + Vector3.UP * 0.62), 40.0)
	k = OssKit.new()
	k.keep_lanes = false
	k.box("wood", lid_at + Vector3.UP * 0.28, Vector3(1.0, 0.56, 0.6), Basis.IDENTITY, true, 0.7)
	k.box("iron", lid_at + Vector3.UP * 0.3, Vector3(1.04, 0.07, 0.64), Basis.IDENTITY, false, 0.9)
	k.commit(holder.get_parent(), "HoardChestBody")
	OssWorld.cache(self, "deep_hoard", lid_at + Vector3.UP * 0.6, "the Abbot's coffer", func(animate: bool) -> void:
		var to := Transform3D(Basis(Vector3.RIGHT, -1.9), lid_at + Vector3(0, 0.62, -0.32))
		if animate:
			lid.create_tween().tween_property(lid, "transform", to, 0.8)
		else:
			lid.transform = to
		if not State.has("open", "count_ended"):
			State.mark("open", "count_ended")
			_end_count(animate),
		func() -> bool: return State.has("solved", "deep_beam"))
	_sync.append(func(_animate: bool) -> void:
		if State.has("looted", "deep_hoard"):
			lid.transform = Transform3D(Basis(Vector3.RIGHT, -1.9), lid_at + Vector3(0, 0.62, -0.32)))


# --- the Weighing Floor's fight ---------------------------------------------------------------

var _grille_n: StaticBody3D
var _grille_s: StaticBody3D
var _grille_n_vis: Node3D
var _grille_s_vis: Node3D


func _arena_logic() -> void:
	_grille_n_vis = _grille("GrilleNorth", Vector3(18.0, D, -75.6), Vector3.RIGHT, 2.3)
	_grille_s_vis = _grille("GrilleSouth", Vector3(15.2, D, ARENA.z + ARENA_R - 0.1), Vector3.RIGHT, 2.5)
	_grille_n = OssWorld.box_body(self, Vector3(18.0, D + 1.4, -75.6), Vector3(2.4, 2.8, 0.3))
	_grille_s = OssWorld.box_body(self, Vector3(15.2, D + 1.4, ARENA.z + ARENA_R - 0.1), Vector3(2.6, 2.8, 0.3))
	Events.hollowed.connect(_arena_reset)
	_sync.append(func(animate: bool) -> void:
		var won := State.has("elites", "sexton")
		_set_grille(_grille_s, _grille_s_vis, not won, animate)
		if not _arena_on:
			_set_grille(_grille_n, _grille_n_vis, false, false))


func _grille(n: String, at: Vector3, along: Vector3, w: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = n
	add_child(holder)
	var k := OssKit.new()
	k.keep_lanes = false
	var bars := int(w / 0.22)
	for i in bars:
		var p := at + along * (-w * 0.5 + 0.11 + 0.22 * float(i))
		k.box("iron", p + Vector3.UP * 1.4, Vector3(0.05, 2.8, 0.05), Basis.IDENTITY, false)
		k.box("iron", p + Vector3.UP * 2.86, Vector3(0.09, 0.14, 0.09), Basis.IDENTITY, false)
	for yy: float in [0.35, 1.4, 2.5]:
		k.box("iron", at + Vector3.UP * yy, Vector3(w, 0.07, 0.07) if along.x > 0.5 else Vector3(0.07, 0.07, w), Basis.IDENTITY, false)
	k.commit(holder, "Unused")
	return holder


func _set_grille(body: StaticBody3D, vis: Node3D, shut: bool, animate: bool) -> void:
	Kit.set_body(body, shut)
	var to := 0.0 if shut else 2.75
	if animate and absf(vis.position.y - to) > 0.1:
		OssWorld.play("grind", OssFrame.l(vis.global_position) + Vector3.UP, -2.0, 1.3)
		vis.create_tween().tween_property(vis, "position:y", to, 1.1 if shut else 2.0).set_trans(Tween.TRANS_SINE)
	else:
		vis.position.y = to


func _arena_tick() -> void:
	var alive := 0
	for e in _arena_live:
		if is_instance_valid(e) and bool(e.call("is_alive")):
			alive += 1
	if alive > 0:
		return
	_arena_on = false
	_arena_live.clear()
	State.mark("elites", "sexton")
	OssWorld.take("deep_sexton", ARENA + Vector3.UP)
	State.toast("The Sexton is weighed and found wanting. The pin of the cage hangs loose.")
	State.banner("the Weighing is done", "The Weighing Floor")
	_set_grille(_grille_n, _grille_n_vis, false, true)
	sync(true)


func _arena_reset() -> void:
	if not _arena_on:
		return
	_arena_on = false
	for e in _arena_live:
		if is_instance_valid(e):
			e.queue_free()
	_arena_live.clear()
	_set_grille(_grille_n, _grille_n_vis, false, false)


## Wake the fight (the director-like check runs in _process at a slow rate).
func start_weighing() -> void:
	if _arena_on or State.has("elites", "sexton"):
		return
	_arena_on = true
	# 60 HP (was base x5 = 15-25: down in 3-5 s of held bolt; A's r29 scale puts bosses at 72-120)
	var sx := OssWorld.spawn_elite(area, "ossuant", ARENA + Vector3(-1.0, 0.1, 2.0), "The Sexton", 60)
	sx.set_meta("deep_elite", "sexton")
	_arena_live.append(sx)
	for p: Vector3 in [ARENA + Vector3(2.6, 0.1, 1.2), ARENA + Vector3(-3.0, 0.1, -1.6)]:
		var w := Wretch.new()
		area.add_child(w)
		w.station(p)
		_arena_live.append(w)
	OssWorld.fx_dust(ARENA + Vector3.UP * 0.3, Color(0.3, 0.3, 0.32, 0.8), 60)
	_set_grille(_grille_n, _grille_n_vis, true, true)
	State.toast("The Sexton rises from the low pan.")


var _watch_t := 0.0


func _process(delta: float) -> void:
	_watch_t -= delta
	if _watch_t > 0.0 or not built:
		return
	_watch_t = 0.3
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	var at := OssFrame.l(p.global_position)               # (the Ossuary's own frame)
	if not _arena_on and not State.has("elites", "sexton") and absf(at.y - D) < 1.6 \
			and Vector2(at.x - ARENA.x, at.z - ARENA.z).length() < ARENA_R - 1.4:
		start_weighing()


# --- the cage, the beacon, lights, readings ----------------------------------------------------

func _cage() -> void:
	_lift = Lift.new()
	_lift.name = "SextonCage"
	_lift.set("bottom", LIFT_AT)
	_lift.set("top_y", GAL_Y)
	_lift.set("unlocked", func() -> bool: return State.has("open", "deep_lift"))
	_lift.set("unlock_ready", func() -> bool: return State.has("elites", "sexton"))
	_lift.set("on_unlock", func() -> void:
		State.mark("open", "deep_lift")
		OssWorld.play("clank", LIFT_AT + Vector3.UP, 2.0, 0.6)
		State.toast("The pin drops into the dark. Above, in the gallery, a grille lifts.")
		State.banner("a way back up", "The Sexton's Cage")
		sync(true))
	add_child(_lift)
	_lift.call("rope", self, Vector3(14.5, D + 1.0, LIFT_AT.z - 2.3), false)
	_lift.call("rope", self, Vector3(17.95, GAL_Y + 1.0, LIFT_AT.z - 1.5), true)
	# the gallery end: a threshold out through the arcade door and a grille in it
	var k := OssKit.new()
	k.keep_lanes = false
	k.block("floor", Vector3(16.45, GAL_Y - 0.6, LIFT_AT.z - 1.15), Vector3(17.5, GAL_Y, LIFT_AT.z + 1.15))
	k.commit(self, "CageLandingBody")
	var gv := _grille("GalleryGrille", Vector3(17.5, GAL_Y, LIFT_AT.z), Vector3.BACK, 2.3)
	var gb := OssWorld.box_body(self, Vector3(17.5, GAL_Y + 1.4, LIFT_AT.z), Vector3(0.3, 2.8, 2.4))
	_sync.append(func(animate: bool) -> void:
		_set_grille(gb, gv, not State.has("open", "deep_lift"), animate))


## The end of the count: a cold flame in the gate hall's belfry, and the bell tolls once.
var _beacon_node: Node3D


func _beacon() -> void:
	_beacon_node = Node3D.new()
	_beacon_node.name = "CountEnded"
	add_child(_beacon_node)
	var orb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.7
	sph.height = 1.4
	orb.mesh = sph
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.6, 0.85, 1.0)
	orb.material_override = m
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon_node.add_child(orb)
	orb.position = BELFRY
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(5.5, 5.5)
	halo.mesh = q
	halo.material_override = Kit.shader_mat("glint")
	halo.set_instance_shader_parameter(&"tint", Color(0.35, 0.6, 1.0))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon_node.add_child(halo)
	halo.position = BELFRY
	var l := OssWorld.omni(_beacon_node, BELFRY, Color(0.55, 0.78, 1.0), 2.2, 14.0)
	l.distance_fade_begin = 140.0
	l.distance_fade_length = 30.0
	_beacon_node.visible = false
	_sync.append(func(_animate: bool) -> void:
		_beacon_node.visible = State.has("open", "count_ended"))


func _end_count(animate: bool) -> void:
	_beacon_node.visible = true
	if animate:
		OssWorld.play("bell_great", BELFRY, 6.0, 0.8)
		State.toast("Far above, in the gate hall's tower, the bell tolls once. The count is ended.")
		State.banner("the count is ended", "The Ossuary")


## Everything below the chapel floor is sealed under stone: the moon can never cast it onto
## anything a player sees, and the deep lights cast no shadows (their last arg). It was still drawn
## into the moon's shadow map from the hub (E's census: Area_ossuary 21 shadow draws, 48.6k prims
## with 0 visible). Its own lights are unshadowed, so nothing changes down there either.
func _no_moon_shadows() -> void:
	if "--deep-shadows" in OS.get_cmdline_user_args():
		return                                   # A/B: the old behaviour
	var n := 0
	for c in find_children("*", "GeometryInstance3D", true, false):
		var gi := c as GeometryInstance3D
		if gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not gi.is_inside_tree():
			continue
		var box: AABB = gi.global_transform * gi.get_aabb()
		if box.end.y - OssFrame.ORIGIN.y < CHAPEL_Y - 0.5:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n += 1
	print("OSSUARY lower count: %d buried meshes cast no moon shadow" % n)


func _lights() -> void:
	area.call("_omni", "DeepCells", Vector3(15.0, CELL_Y + 2.6, -103.0), Color(1.0, 0.6, 0.3), 1.1, 8.0, false)
	area.call("_omni", "DeepDrum", DRUM + Vector3(0, 2.4, 0), Color(1.0, 0.58, 0.3), 1.0, 6.5, false)
	area.call("_omni", "DeepWindow", Vector3(E_MIRROR.x, D - 1.0, E_MIRROR.y), Color(1.0, 0.7, 0.4), 1.4, 7.0, false)
	area.call("_omni", "DeepWeighing", ARENA + Vector3(0, 3.2, 0), Color(1.0, 0.56, 0.28), 1.6, 11.0, false)
	area.call("_omni", "DeepHoard", Vector3(7.4, D + 2.4, -90.0), Color(1.0, 0.66, 0.34), 1.2, 7.5, false)


func _readings() -> void:
	OssWorld.reading(self, "sc_deep_slab", Vector3(HOLE.position.x - 0.5, CHAPEL_Y + 0.4, HOLE.position.y + 0.6))
	OssWorld.reading(self, "sc_deep_sexton", Vector3(15.2, CELL_Y + 1.05, -102.6))
	OssWorld.reading(self, "sc_deep_rule", Vector3(12.8, CELL_Y + 1.5, -100.0))
	OssWorld.reading(self, "sc_deep_drum", DRUM + Vector3(0.0, 1.6, -DRUM_R - 0.9))
	OssWorld.reading(self, "sc_deep_window", Vector3(E_PLAT.end.x - 0.5, D + 1.1, E_PLAT.position.y + 1.0))
	OssWorld.reading(self, "sc_deep_weigh", ARENA + Vector3(-1.4, 0.9, 2.1))
	OssWorld.reading(self, "sc_deep_hoard", Vector3(9.6, D + 1.0, HOARD.position.y + 1.1))
	OssWorld.cache(self, "deep_cells", Vector3(16.95, CELL_Y + 0.6, -100.9), "the sexton's strongbox", Callable())


func _register() -> void:
	var t0 := Time.get_ticks_msec()
	while is_inside_tree() and Time.get_ticks_msec() - t0 < 240000:
		if State.host != null and is_instance_valid(State.host) and State.host.is_inside_tree() and State.host.get_node_or_null("SecretsDirector") != null:
			break
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var chapel_in := Vector3(16.0, CHAPEL_Y, -100.6)
	var walk_cells: Array[Vector3] = [Vector3(17.3, 0, -99.95), Vector3(18.7, 0, -100.1), Vector3(18.7, 0, -105.9), Vector3(17.2, 0, -105.9), Vector3(14.3, 0, -104.6), Vector3(13.6, 0, -103.4)]
	State.register({"id": "lower_count", "name": "The Uncounted Cells", "at": OssFrame.w(Vector3(15.0, CELL_Y, -102.8)), "r": 4.5, "node": self,
		"route": OssWorld.route(chapel_in, walk_cells), "goal": OssFrame.w(Vector3(13.6, CELL_Y, -103.4)), "sync": sync})
	var walk_drum: Array[Vector3] = [Vector3(13.6, 0, -101.0), Vector3(16.2, 0, -100.0), Vector3(16.2, 0, -97.8), Vector3(18.0, 0, -97.2), Vector3(18.0, 0, -91.6), Vector3(18.0, 0, -87.0), Vector3(18.0, 0, -85.2)]
	State.register({"id": "count_drum", "name": "The Count Drum", "at": OssFrame.w(DRUM), "r": 3.0, "node": self,
		"route": OssWorld.route(Vector3(13.6, CELL_Y + 0.05, -103.4), walk_drum), "goal": OssFrame.w(Vector3(18.0, D, -85.2))})
	State.register({"id": "weighing", "name": "The Weighing Floor", "at": OssFrame.w(ARENA), "r": 4.0, "node": self,
		"route": OssWorld.route(DRUM + Vector3(0, 0.2, 0), [Vector3(18.0, 0, -79.0), Vector3(17.6, 0, -74.0), Vector3(15.5, 0, -71.0)]), "goal": OssFrame.w(ARENA)})
	State.register({"id": "hoard", "name": "The Abbot's Hoard", "at": OssFrame.w(Vector3(7.4, D, -90.0)), "r": 3.2, "node": self,
		"route": OssWorld.route(DRUM + Vector3(0, 0.2, 0), [Vector3(12.0, 0, -84.0), Vector3(HOARD_DOOR_X, 0, -85.0), Vector3(HOARD_DOOR_X, 0, -88.4), Vector3(7.4, 0, -89.6)]), "goal": OssFrame.w(Vector3(7.4, D, -89.6))})


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
