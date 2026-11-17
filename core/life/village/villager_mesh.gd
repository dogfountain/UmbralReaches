extends "res://core/npc/dwarf_mesh.gd"
## Mesh builder for Hearthward's villagers (village system; no class_name). DwarfMesh with one
## addition: long garments (coats, dresses, robes) can be skinned in "skirt" mode, where each vertex
## is shared between the pelvis and the thigh on its own side, more toward the thigh the lower and
## further out from the centre seam it is. The hem then follows the stride instead of the legs
## walking through the cloth, and the front/back seams stay on the pelvis so they never split.
## Load by path: const VMesh := preload("res://core/life/village/villager_mesh.gd")

const B_SPINE := 1
const B_THIGH_R := 11
const B_THIGH_L := 13

var _skirt := false
var _sk_top := 0.0
var _sk_bot := 0.0
var _sk_w := 0.7
var _sk_span := 0.12


func _init(seed_value := 0) -> void:
	super(seed_value)


## Skirt skinning from y `top` (all pelvis) down to `bot` (thigh share `w` at the sides).
func bind_skirt(top: float, bot: float, w := 0.7, span := 0.12) -> void:
	_skirt = true
	_sk_top = top
	_sk_bot = bot
	_sk_w = w
	_sk_span = span


func bind(bone: int) -> void:
	_skirt = false
	super(bone)


func bind_blend(a: int, b: int, p0: Vector3, p1: Vector3) -> void:
	_skirt = false
	super(a, b, p0, p1)


func _vert(p: Vector3, n: Vector3, uv: Vector2, col: Color, mat: int, ao := 1.0) -> int:
	if not _skirt:
		return super(p, n, uv, col, mat, ao)
	_v.append(p)
	_n.append(n)
	_uv.append(uv)
	_uv2.append(Vector2(float(mat), 0.0))
	_col.append(Color(col.r, col.g, col.b, ao))
	var down := clampf((_sk_top - p.y) / maxf(_sk_top - _sk_bot, 0.01), 0.0, 1.0)
	down = down * down * (3.0 - 2.0 * down)
	var side := clampf(absf(p.x) / _sk_span, 0.0, 1.0)
	var w := _sk_w * down * side
	var thigh := B_THIGH_R if p.x >= 0.0 else B_THIGH_L
	_bones.append_array(PackedInt32Array([B_SPINE, thigh, 0, 0]))
	_w.append_array(PackedFloat32Array([1.0 - w, w, 0.0, 0.0]))
	return _v.size() - 1


## Each tool's working end at rest, as VillagerRig._tool() places it: [along the fist's axis, along the fingers] x the
## body size. Set on the rig with its layout (17 Nov: a mesh from GenCache skipped _tool, the tips stayed at zero and a
## lantern's glow hung by the feet).
const TIP := {"hammer": [0.28, 0.045], "tongs": [0.36, 0.0], "pole": [1.8, 0.0], "staff": [-1.05, 0.0], "crook": [-1.05, 0.0],
	"spade": [1.16, 0.0], "axe": [0.52, 0.1], "sword": [0.83, 0.0], "scoop": [0.28, 0.0], "lantern": [0.0, 0.2], "candle": [0.135, 0.0],
	"broom": [1.5, 0.0], "bucket": [0.0, 0.34], "sack": [0.0, 0.4], "fiddle": [0.26, 0.0], "bow": [0.62, 0.0], "torch": [0.6, 0.0], "jug": [0.0, 0.17]}


static func tool_tips(rig: Variant) -> void:
	for side in 2:
		var t: Array = TIP.get(String((rig.cfg as Dictionary).get("r" if side == 0 else "l", "")), [])
		var ax: Vector3 = rig.grip_ax[side]
		var fd: Vector3 = (rig.grip_up[side] as Vector3).slide(ax).normalized()
		rig.tips[side] = (rig.grip[side] as Vector3) + (ax * float(t[0]) + fd * float(t[1])) * float(rig.k) if not t.is_empty() else Vector3.ZERO
