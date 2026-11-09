extends RefCounted
## THE PILGRIMS' STAIR: the way down from the crossing to the Pilgrims' Chapel (chapel.gd). A flight of broad stone
## steps winds down the outside of the crossing's third tower (T3, RealmRift/crossing.gd; the parapet is opened for it
## on the east side) from the deck to the starwater, 17.6 m in 44 steps of 0.4 m, and a quay carries on west across the
## pool to the chapel's forecourt. Built as a solid stone ramp (each step a column of masonry to the water, so it never
## floats), walled on both edges. Steps are boxes with real collision: 0.4 m rises are inside the player's step-up
## (0.45 m). Every step is clearance-checked by the Threshold (a step that touches something is left out and printed).

const C := Vector2(-1.8, -40.0)        ## T3's centre
const DECK := 5.6                      ## its deck
const A0 := deg_to_rad(-35.0)          ## where the stair leaves the deck (east-north-east; the parapet is opened here)
const A1 := PI                         ## and where it reaches the water (west, towards the chapel)
const R_IN := 4.4                      ## the flight's radial span: clear of the tower's foot (its collision box reaches 4.2 m on the diagonals)
const R_OUT := 6.7
const N := 44
const RISE := 0.4
const FOOT_Y := -12.0                  ## the lowest walk (and the chapel's floor)
const BASE := -16.6                    ## masonry goes down to here (into the pool floor)
const QUAY_X := [-8.4, -12.1]          ## the quay's span (east end, west end) along z = QUAY_Z
const QUAY_Z := -40.0
const QUAY_W := 2.2

var t
var k: OssKit
var steps_built := 0
var narrow_steps := 0
var spans := 0
var points: Array[Vector3] = []        ## the walking line, deck to quay (for the walk test)


## World point of the flight's centreline at step index i (0 = the landing on the deck).
static func at(i: int) -> Vector3:
	var a := A0 + (A1 - A0) * float(i) / float(N)
	var rc := (R_IN + R_OUT) * 0.5
	return Vector3(C.x + cos(a) * rc, DECK - RISE * float(i), C.y + sin(a) * rc)


func build(p_threshold) -> bool:
	t = p_threshold
	k = t.k
	var da := (A1 - A0) / float(N)
	var rc := (R_IN + R_OUT) * 0.5
	var ok := true
	for i in N + 1:
		var a := A0 + da * float(i)
		var radial := Vector3(cos(a), 0.0, sin(a))
		var tang := Vector3(-sin(a), 0.0, cos(a))
		var b := Basis(tang, Vector3.UP, -radial)
		var top := DECK - RISE * float(i)
		var h := top - BASE
		var tread := rc * da * 1.05
		if i == 0:
			# the landing on the deck: a thin slab bridging the parapet's opening, the masonry beyond it
			var lc := Vector3(C.x, 0.0, C.y) + radial * ((3.55 + R_OUT) * 0.5) + Vector3.UP * (top - 0.25)
			if t._clear(Transform3D(b, lc), Vector3(tread * 2.0, 0.5, R_OUT - 3.55), 0.02, true):
				k.box("rift_stone", lc, Vector3(tread * 2.0, 0.5, R_OUT - 3.55), b, true, 0.95)
		# the full width where it is clear; narrowed past the fallen column's snapped pier (the south-west) to what is
		var placed := false
		for r_out: float in [R_OUT, 6.2, 5.8, 5.5]:
			var w := r_out - R_IN
			var cc := Vector3(C.x, 0.0, C.y) + radial * ((R_IN + r_out) * 0.5) + Vector3.UP * (top - h * 0.5)
			var sz := Vector3(tread, h, w)
			var slab := false
			if not t._clear(Transform3D(b, cc), sz, 0.02, true):
				# past the fallen column's pier and the rubble round it: a slab (an arched span) instead of a column to the water
				sz = Vector3(tread, 1.0, w)
				cc = Vector3(C.x, 0.0, C.y) + radial * ((R_IN + r_out) * 0.5) + Vector3.UP * (top - 0.5)
				if not t._clear(Transform3D(b, cc), sz, 0.02, true):
					continue
				slab = true
			k.box("rift_stone", cc, sz, b, true, 0.92 if i % 2 == 0 else 1.0)
			if slab:
				spans += 1
			# walls both sides (the outer one only where the flight is wide), a post every fourth step; the foot's outer side is open for the quay
			for edge: float in [r_out - 0.14, R_IN + 0.14]:
				if edge > R_IN + 1.0 and (i >= N - 1 or w < 2.0):
					continue
				if edge <= R_IN + 1.0 and i <= 2:
					continue                         # the way on from the deck: the inner wall begins past the landing
				var wc := Vector3(C.x, 0.0, C.y) + radial * edge + Vector3.UP * (top + 0.42)
				k.box("rift_stone", wc, Vector3(tread, 0.84, 0.24), b, true, 0.95)
				if i % 4 == 0:
					k.box("rift_stone", wc + Vector3.UP * 0.5, Vector3(0.36, 0.3, 0.36), b, true, 1.0)
			if r_out < R_OUT:
				narrow_steps += 1
			steps_built += 1
			points.append(Vector3(C.x, 0.0, C.y) + radial * ((R_IN + r_out) * 0.5) + Vector3.UP * top)
			placed = true
			break
		if not placed:
			t._audit.append("tower stair step %d left out (%s)" % [i, t._last_hit])
			ok = false
	# the quay: a causeway on piers from the foot to the chapel's forecourt, walled on both sides
	var x0: float = QUAY_X[0]
	var x1: float = QUAY_X[1]
	var qc := Vector3((x0 + x1) * 0.5, (FOOT_Y + BASE) * 0.5, QUAY_Z)
	var qs := Vector3(absf(x1 - x0), FOOT_Y - BASE, QUAY_W)
	if t._clear(Transform3D(Basis.IDENTITY, qc), qs, 0.02, true):
		k.box("rift_stone", qc, qs, Basis.IDENTITY, true, 0.95)
		for sz: float in [QUAY_Z - QUAY_W * 0.5 + 0.13, QUAY_Z + QUAY_W * 0.5 - 0.13]:
			k.parapet("rift_stone", Vector3(x0, FOOT_Y, sz), Vector3(x1 + 0.4, FOOT_Y, sz), 0.85, 0.26)
	else:
		t._audit.append("tower stair quay touches %s" % t._last_hit)
		ok = false
	return ok
