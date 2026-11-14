extends RefCounted
## Hearthward's square, composed as a room (14 Nov: "a square is a room"; docs/ARCH_REVIEW.md, round 3).
## The Hollow Lantern holds the east side. The rest is closed by what the village does here:
##   west   a row of three awninged market stalls on the rim, their fronts to the square, their backs to Maud's yard
##          (the west way keeps its gap at the north end)
##   south  a roofed timber gate where the road's two arms meet (the way in from the Pilgrims' Road), with a low
##          stone wall and a pier at each end: the square's only mouth to the south
##   centre a stepped market cross off the brazier, between the stalls and the axis; the axis itself (the
##          road, the gate, the brazier, the stair x = 0 .. 2) stays open
##   yards  hitching rails at the gate and by the Lantern, firewood, barrels, crates and sacks against the
##          tavern's south wall and at the stalls' ends, a washing line behind Maud's, a cart at the Wrights'
## Every piece is a model from art/models/props (tools/blender/props_market.py, props_square.py), merged into one
## mesh per material set; the collision is a few boxes each. Built after the cottages (hearthward.gd).
## The notice board, the well, the benches and the lamps are authored there and in village_cast.gd.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const PropModels := preload("res://core/world/realm/prop_models.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")

const GATE := Vector2(2.3, 44.0)                   ## the gate's centre (the road's arms meet at (2, 44))
const GATE_PX := 2.7                               ## its post line, either side
const CROSS := Vector2(-3.2, 37.2)                 ## the market cross
const STALLS_X := -12.3                            ## the stalls' line
const STALLS := [[30.6, "market_stall_a.glb"], [35.2, "market_stall_c.glb"]]       # the way to Maud's door runs on south of them
const RANGE := 130.0

var _small: PropModels = PropModels.new()          ## goods and furniture (the props' finer texel density)
var _big: PropModels = PropModels.new()            ## the gate, the cross, the walls, the stalls (building density)
var _l: RefCounted


static func build(L: RefCounted) -> void:
	var sq := new()
	sq._run(L)


func _run(L: RefCounted) -> void:
	_l = L
	_big.big = true
	var pk := Pilot.prop()
	_gate()
	_cross()
	_stalls(pk)
	_yards(pk)
	var n := 0
	for pm: PropModels in [_small, _big]:
		for mi in pm.commit(L.holder, "HearthwardSquare" + ("Big" if pm.big else "Small"), true):
			mi.visibility_range_end = RANGE
			mi.visibility_range_end_margin = 12.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			n += 1
	print("REALM_LORE hearthward square: %d model meshes" % n)


## Put a model down: yaw, scale and a handful of collision boxes ([centre, size] in the model's own frame, metres,
## before the scale).
func _put(pm: PropModels, file: String, at: Vector2, yaw: float, s := 1.0, cols: Array = [], part := "") -> Vector3:
	var y: float = _l.g(at.x, at.y)
	var b := Basis(Vector3.UP, yaw)
	var xf := Transform3D(b.scaled(Vector3.ONE * s), Vector3(at.x, y, at.y))
	pm.add(file, xf, part)
	for c: Array in cols:
		LK.col_box(_l.p, xf * (c[0] as Vector3), (c[1] as Vector3) * s, b)
	return Vector3(at.x, y, at.y)


# --- the gate ---------------------------------------------------------------------------------------------

func _gate() -> void:
	var posts: Array = []
	for sx: float in [-GATE_PX, GATE_PX]:
		for sz: float in [-1.45, 1.45]:
			posts.append([Vector3(sx, 2.0, sz), Vector3(0.62, 4.0, 0.62)])
	for sx2: float in [-GATE_PX, GATE_PX]:
		posts.append([Vector3(sx2 + (0.3 if sx2 < 0.0 else -0.3), 0.6, 0.0), Vector3(0.9, 1.2, 2.4)])        # the rail and the seat inside it
	_put(_big, "village_gate.glb", GATE, 0.0, 1.0, posts)
	# the wall either side: a pier, two bays, a pier (the notice board and the lamp keep clear of the ends)
	var w0 := GATE.x - GATE_PX - 0.63 - 0.2 - 0.475            # the west pier's centre
	var e0 := GATE.x + GATE_PX + 0.63 + 0.2 + 0.475
	for side: float in [-1.0, 1.0]:
		var x0 := w0 if side < 0.0 else e0
		_put(_big, "wall_pier.glb", Vector2(x0, GATE.y), 0.0, 1.0, [[Vector3(0, 1.0, 0), Vector3(0.95, 2.0, 0.95)]])
		for i in 2:
			var cx := x0 + side * (0.475 + 1.5 + 3.0 * float(i))
			_put(_big, "wall_low.glb", Vector2(cx, GATE.y), 0.0, 1.0, [[Vector3(0, 0.65, 0), Vector3(3.0, 1.3, 0.66)]])
		_put(_big, "wall_pier.glb", Vector2(x0 + side * (0.475 + 6.0 + 0.475), GATE.y), 0.0, 1.0, [[Vector3(0, 1.0, 0), Vector3(0.95, 2.0, 0.95)]])


# --- the cross --------------------------------------------------------------------------------------------

func _cross() -> void:
	var cols: Array = []
	# three steps (a walkable stair up to the pedestal), then the pedestal and shaft as one tall box
	for i in 3:
		var r := [2.15, 1.72, 1.32][i] as float
		var half := r * cos(PI / 8.0) * 0.96
		cols.append([Vector3(0, 0.27 * (float(i) + 0.5), 0), Vector3(half * 2.0, 0.27, half * 2.0)])
	cols.append([Vector3(0, 2.2, 0), Vector3(1.0, 2.8, 1.0)])
	_put(_big, "market_cross.glb", CROSS, 0.35, 1.0, cols)


# --- the market --------------------------------------------------------------------------------------------

func _stalls(pk: float) -> void:
	for st: Array in STALLS:
		var s := pk * 1.05
		_put(_big, st[1] as String, Vector2(STALLS_X, float(st[0])), PI * 0.5, s,
			[[Vector3(0, 0.5, 0.5), Vector3(3.0, 1.0, 0.85)], [Vector3(0, 1.15, -0.86), Vector3(3.0, 2.3, 0.14)]])
	# the third stall stands against the gate's east wall, facing the square, its back to the wall
	_put(_big, "market_stall_b.glb", Vector2(9.7, 42.15), PI, pk * 1.05,
		[[Vector3(0, 0.5, 0.5), Vector3(3.0, 1.0, 0.85)], [Vector3(0, 1.15, -0.86), Vector3(3.0, 2.3, 0.14)]])
	_put(_small, "barrel.glb", Vector2(12.2, 42.9), 0.3, pk, [[Vector3(0, 0.42, 0), Vector3(0.6, 0.85, 0.6)]])
	_put(_small, "crate.glb", Vector2(12.2, 41.9), 0.2, pk, [[Vector3(0, 0.33, 0), Vector3(0.66, 0.66, 0.66)]])
	# the south end of the row: crates and a barrel where the goods wait
	var e := Vector2(STALLS_X + 0.1, 37.9)
	_put(_small, "crate.glb", e, 0.2, pk, [[Vector3(0, 0.33, 0), Vector3(0.66, 0.66, 0.66)]])
	_put(_small, "crate.glb", e + Vector2(0.8, 0.0), -0.3, pk, [[Vector3(0, 0.33, 0), Vector3(0.66, 0.66, 0.66)]])
	_put(_small, "barrel.glb", e + Vector2(-0.9, 0.0), 0.0, pk, [[Vector3(0, 0.42, 0), Vector3(0.6, 0.85, 0.6)]])
	# behind the row: what the stalls sell from, stacked against the backs
	var bx := STALLS_X - 2.0
	_put(_small, "firewood.glb", Vector2(bx, 32.2), PI * 0.5, pk, [[Vector3(0, 0.33, 0), Vector3(1.0, 0.66, 0.65)]])
	_put(_small, "barrel.glb", Vector2(bx, 36.2), 0.0, pk, [[Vector3(0, 0.42, 0), Vector3(0.6, 0.85, 0.6)]])
	_put(_small, "barrel_tipped.glb", Vector2(bx + 0.1, 37.1), 1.2, pk)
	_put(_small, "crate_broken.glb", Vector2(bx, 38.0), 0.4, pk)


# --- the yards ---------------------------------------------------------------------------------------------

func _yards(pk: float) -> void:
	# hitching rails: outside the gate on the east arm of the road, and by the Hollow Lantern's west gable
	_put(_small, "hitch_rail.glb", Vector2(8.7, 45.5), 0.0, pk * 1.1, [[Vector3(0, 0.6, 0), Vector3(2.3, 1.2, 0.3)]])
	_put(_small, "hitch_rail.glb", Vector2(8.8, 29.6), PI * 0.5, pk * 1.1, [[Vector3(0, 0.6, 0), Vector3(2.3, 1.2, 0.3)]])
	_put(_small, "bench.glb", Vector2(8.0, 32.3), PI * 0.5, pk, [[Vector3(0, 0.24, 0), Vector3(1.5, 0.48, 0.36)]])
	# the tavern's south wall: firewood to the eaves, barrels, crates
	var zs := 35.7
	_put(_small, "firewood.glb", Vector2(12.4, zs), 0.0, pk, [[Vector3(0, 0.33, 0), Vector3(1.0, 0.66, 0.65)]])
	_put(_small, "firewood.glb", Vector2(13.8, zs), 0.0, pk, [[Vector3(0, 0.33, 0), Vector3(1.0, 0.66, 0.65)]])
	_put(_small, "barrel.glb", Vector2(15.4, zs + 0.05), 0.4, pk, [[Vector3(0, 0.42, 0), Vector3(0.6, 0.85, 0.6)]])
	_put(_small, "barrel.glb", Vector2(16.3, zs), 1.9, pk, [[Vector3(0, 0.42, 0), Vector3(0.6, 0.85, 0.6)]])
	_put(_small, "crate.glb", Vector2(17.3, zs), 0.1, pk, [[Vector3(0, 0.33, 0), Vector3(0.66, 0.66, 0.66)]])
	_put(_small, "crate_broken.glb", Vector2(18.1, zs + 0.1), 0.5, pk)
	_put(_small, "sack.glb", Vector2(19.0, zs), 0.2, pk)
	# Maud's yard: a washing line behind the house, its basket under it
	_put(_small, "washing_line.glb", Vector2(-14.0, 51.0), 0.12, pk, [[Vector3(-2.4, 1.3, 0), Vector3(0.14, 2.6, 0.14)], [Vector3(2.4, 1.3, 0), Vector3(0.14, 2.6, 0.14)]])
	# the Wrights': a cart by the road, a trough
	_put(_small, "handcart.glb", Vector2(-21.8, 64.0), 0.5, pk, [[Vector3(-0.05, 0.46, 0), Vector3(1.6, 0.92, 1.0)]])
	# the Reeds': sacks and a stack of wood against the east gable
	_put(_small, "firewood.glb", Vector2(16.0, 42.0), PI * 0.5, pk, [[Vector3(0, 0.33, 0), Vector3(1.0, 0.66, 0.65)]])
