extends RefCounted
## Hearthward's well, notice board, hearth shrine and Edda's forge as modelled pieces at the village's scale
## (they were code-built box pieces at the old scale beside 4 m eaves). The models are
## tools/blender/props_hearth.py -> art/models/props/hw_*.glb, drawn at the size they stand at; the collision is a few
## boxes each. What the village reads stays where it was: the sites (Props.site_y), the inscriptions (L.scrap), the
## pages and letters, the saint, the candles and coals, the forge's light, and the walk nodes (the forge's are
## re-planned by scale_pilot.gd HW "hw_forge", the factor FORGE_S below).
## Built by hearthward.gd after the cottages, when the scale pilot is on (off: the old pieces there).

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const PropModels := preload("res://core/world/realm/prop_models.gd")

const FORGE_S := 1.25                       ## the forge's stations (the old plan's metres) go out this much (scale_pilot.gd HW)
const RANGE := 130.0

var _pm: PropModels = PropModels.new()
var _l: RefCounted


static func begin(L: RefCounted) -> RefCounted:
	var hp := new()
	hp._l = L
	hp._pm.big = true
	return hp


## Commit the meshes once every piece has been put down.
func finish() -> void:
	for mi in _pm.commit(_l.holder, "HearthwardPieces", true):
		mi.visibility_range_end = RANGE
		mi.visibility_range_end_margin = 12.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _put(file: String, at: Vector3, yaw: float, cols: Array) -> Basis:
	var b := Basis(Vector3.UP, yaw)
	_pm.add(file, Transform3D(b, at))
	for c: Array in cols:
		var cb := b * (c[2] as Basis) if c.size() > 2 else b
		LK.col_box(_l.p, at + b * (c[0] as Vector3), c[1] as Vector3, cb)
	return b


# --- the well -------------------------------------------------------------------------------------------

## The curb stands on the lowest ground under it; the village's boards, rope and bucket (village_props.gd well)
## are laid over it at the same floor.
func well(c: Vector2) -> void:
	var L := _l
	var gr: Vector2 = L.g_range(Rect2(c - Vector2(1.5, 1.5), Vector2(3.0, 3.0)))
	var y := gr.x
	L.site("hw_well", Rect2(c - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), y)
	var at := Vector3(c.x, y, c.y)
	var cols: Array = [
		[Vector3(0, 0.5, 0), Vector3(2.1, 1.0, 2.1), Basis.IDENTITY],
		[Vector3(0, 0.5, 0), Vector3(2.1, 1.0, 2.1), Basis(Vector3.UP, PI * 0.25)],
		[Vector3(-1.4, 1.3, 0), Vector3(0.3, 2.6, 0.3)],
		[Vector3(1.4, 1.3, 0), Vector3(0.3, 2.6, 0.3)]]
	_put("hw_well.glb", at, 0.0, cols)
	var pl := at + Vector3(0, 0.64, -1.355)
	L.letters(pl, Vector3.FORWARD, 0.5, 3)
	L.scrap("hw_well", at + Vector3(0, 0.3, -1.9))


# --- the notice board -----------------------------------------------------------------------------------

func notice(c: Vector2, yaw: float, ids: Array) -> void:
	var L := _l
	var at: Vector3 = L.gv(c.x, c.y)
	L.site("hw_notice", Rect2(c - Vector2(1.7, 1.7), Vector2(3.4, 3.4)), at.y)
	var b := _put("hw_notice.glb", at, yaw, [
		[Vector3(-1.15, 1.6, 0), Vector3(0.26, 3.2, 0.26)], [Vector3(1.15, 1.6, 0), Vector3(0.26, 3.2, 0.26)],
		[Vector3(0, 1.95, 0), Vector3(2.3, 1.6, 0.2)]])
	for i in 3:
		var q := at + b * Vector3(-0.7 + 0.7 * float(i), 1.98 + 0.1 * float(i % 2), -0.065)
		L.page(q, b * Vector3(0, 0, -1), 0.12)
		L.scrap(ids[i] as String, at + b * Vector3(-1.1 + 1.1 * float(i), 0.4, -1.0))
	# a scrap of red hood cloth pinned beside the LOST notice
	L.p.box("lore_cloth", at + b * Vector3(0.28, 1.6, -0.07), Vector3(0.14, 0.24, 0.012), b * Basis(Vector3.BACK, 0.3), false, 0.6)


# --- the hearth shrine ----------------------------------------------------------------------------------

func shrine(c: Vector2, yaw: float) -> void:
	var L := _l
	var k: OssKit = L.k
	var at: Vector3 = L.gv(c.x, c.y)
	L.site("hw_shrine", Rect2(c - Vector2(2.2, 2.2), Vector2(4.4, 4.4)), at.y)
	var b := _put("hw_shrine.glb", at, yaw, [
		[Vector3(0, 0.4, 0), Vector3(3.5, 0.8, 2.9)],
		[Vector3(-1.12, 1.75, 0.72), Vector3(0.36, 3.5, 1.1)], [Vector3(1.12, 1.75, 0.72), Vector3(0.36, 3.5, 1.1)],
		[Vector3(0, 1.75, 1.0), Vector3(2.6, 3.5, 0.5)]])
	var s := 1.0
	var saint_at := at + Vector3.UP * 0.8 + b * Vector3(0, 0, 0.4)
	var front: Vector3 = L.saint(saint_at, yaw, 0, 0.35, s)
	# the bowl's coals still warm, candles on the two ledges, a plaque
	k.box("lore_ember", saint_at + Vector3.UP * (0.35 + 1.17 * s) + b * Vector3(0, 0, -0.33 * s), Vector3(0.16, 0.03, 0.16), b, false, 0.6)
	k.candle_cluster(at + Vector3.UP * 1.06 + b * Vector3(-1.15, 0, -0.38), 3, 0.14, L.rng)
	k.candle_cluster(at + Vector3.UP * 1.06 + b * Vector3(1.15, 0, -0.38), 2, 0.12, L.rng)
	L.letters(front + b * Vector3(0, 0, -0.02), b * Vector3(0, 0, -1), 0.55, 3)
	L.scrap("hw_shrine", at + b * Vector3(0, 0.4, -1.9))


# --- Edda's forge ---------------------------------------------------------------------------------------

## The lean-to's open side faces north (-z), to the road. Its stations sit at the old plan's places times FORGE_S
## about the old centre (the villagers' walk nodes are re-planned the same way: scale_pilot.gd hw_xz).
func forge(c: Vector2) -> void:
	var L := _l
	var k: OssKit = L.k
	var p: OssKit = L.p
	var r := Rect2(c - Vector2(4.5, 3.4), Vector2(9.0, 6.8))
	var gr: Vector2 = L.g_range(r)
	var fy := gr.y + 0.1
	L.site("hw_forge", r, fy, fy - 0.25)
	var o := Vector3(c.x, fy, c.y)
	var cols: Array = [
		[Vector3(0, 2.5, 2.85), Vector3(8.0, 4.8, 0.62)],
		[Vector3(-3.85, 0.85, 1.07), Vector3(0.52, 1.7, 2.95)], [Vector3(3.85, 0.85, 1.07), Vector3(0.52, 1.7, 2.95)],
		[Vector3(-3.85, 1.7, -2.75), Vector3(0.34, 3.4, 0.34)], [Vector3(-1.3, 1.7, -2.75), Vector3(0.34, 3.4, 0.34)],
		[Vector3(1.3, 1.7, -2.75), Vector3(0.34, 3.4, 0.34)], [Vector3(3.85, 1.7, -2.75), Vector3(0.34, 3.4, 0.34)],
		[Vector3(-1.75, 0.6, 1.75), Vector3(2.4, 1.2, 1.7)],
		[Vector3(-2.75, 2.0, 2.07), Vector3(0.4, 4.0, 0.9)], [Vector3(-0.75, 2.0, 2.07), Vector3(0.4, 4.0, 0.9)],
		[Vector3(1.0, 0.7, 0.25), Vector3(0.8, 1.4, 0.8)],
		[Vector3(2.75, 0.45, 1.15), Vector3(1.0, 0.9, 2.0)],
		[Vector3(3.0, 0.6, -1.9), Vector3(0.7, 1.2, 1.0)],
		[Vector3(-3.2, 0.45, -1.0), Vector3(0.9, 0.9, 1.2)],
		[Vector3(-3.4, 0.52, -2.4), Vector3(0.75, 1.05, 0.75)],
		[Vector3(-3.0, 0.45, 0.6), Vector3(0.9, 0.9, 1.3)]]
	_put("hw_forge.glb", o, 0.0, cols)
	# the coals on the hearth, the anvil's plaque, the old forge's light
	var fh := o + Vector3(-1.75, 0.0, 1.75)
	k.box("lore_char", fh + Vector3.UP * 1.24, Vector3(1.3, 0.05, 0.9), Basis.IDENTITY, false, 0.4)
	k.box("lore_ember", fh + Vector3(0.0, 1.27, 0.12), Vector3(0.6, 0.04, 0.4), Basis(Vector3.UP, 0.4), false, 0.55)
	var an := o + Vector3(1.0, 0.0, 0.25)
	var pl := an + Vector3(0, 0.42, -0.45)
	p.box("iron", pl, Vector3(0.34, 0.22, 0.02), Basis(Vector3.RIGHT, 0.1), false, 0.8)
	L.letters(pl + Vector3(0, 0, -0.015), Vector3(0, 0, -1), 0.26, 2)
	L.scrap("hw_forge", an + Vector3(0, 0.3, -1.1))
	L.light("ForgeEmbers", fh + Vector3(0, 1.5, -0.7), Color(1.0, 0.42, 0.14), 0.7, 5.0)
