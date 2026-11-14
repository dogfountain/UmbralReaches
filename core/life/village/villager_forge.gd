extends RefCounted
## The forge's quieter work poses (heat the iron, quench it, grind it), split out of villager.gd. Static; `v` is the Villager
## (its rig, its clock `_t`, the act's clock `act_t` / `act_len`, `_m()` world to model space, the village's anchors). Each is
## a loop that reads from the silhouette at play distance: the whole body works (the lean, the step of the shoulders), not
## only the hands.
const B_SPINE := 1
const B_CHEST := 2
const B_ARM_R := 5
const B_FORE_R := 6


## Heat: the iron held in the coals and turned, the body rocking in to the fire and back from its heat, the free hand
## pumping the bellows in time.
static func heat(v: Variant, k: float) -> void:
	var r: Variant = v.rig
	var t: float = v._t
	var coals: Vector3 = v._m(v.village.anchor("@coals"))
	var tl: Vector3 = (r.tips[1] as Vector3) - (r.grip[1] as Vector3)
	var rock := sin(t * 1.4)                                   # in over the coals, back out of the heat
	var stir := Vector3(0.1 * sin(t * 1.9), 0.03 * rock, 0.1 * cos(t * 1.5))
	var d := (coals - Vector3(-0.1, 1.0, -0.2) * k).normalized()
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.18 - 0.16 * rock) * Quaternion(Vector3.UP, 0.1 * sin(t * 0.7)))
	r.q(B_CHEST, Quaternion(Vector3.RIGHT, -0.08 * rock))
	r.hold(1, coals + stir - d * tl.length(), d, Vector3.DOWN, Vector3(-0.9, -0.4, 0.3))
	var pump := 0.5 + 0.5 * sin(t * 2.6)                       # the bellows' handle: the right arm drawn back and driven down
	r.q(B_ARM_R, Quaternion(Vector3.RIGHT, 0.1 - 0.7 * pump) * Quaternion(Vector3.BACK, 0.12))
	r.q(B_FORE_R, Quaternion(Vector3.RIGHT, 0.5 + 0.6 * pump))


## Quench: the iron lifted out and held up (the lean back from the heat), carried over the barrel, plunged and held in the
## steam, drawn out and looked at.
static func quench(v: Variant, k: float) -> void:
	var r: Variant = v.rig
	var water: Vector3 = v._m(v.village.anchor("@water"))
	var tl: Vector3 = (r.tips[1] as Vector3) - (r.grip[1] as Vector3)
	var u: float = v.act_t / v.act_len
	var lift := smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.2, 0.34, u))          # up and out of the fire
	var dip := smoothstep(0.34, 0.46, u) * (1.0 - smoothstep(0.78, 0.9, u))          # plunged and held
	var shake := 0.03 * sin(v._t * 14.0) * dip                                       # the hiss
	var above := water + Vector3.UP * 0.45
	var tip := above.lerp(water + Vector3.DOWN * 0.08, dip) + Vector3(0.0, 0.3 * lift, 0.12 * lift) * k + Vector3(shake, 0.0, 0.0)
	var d := (tip - Vector3(-0.15, 1.0, -0.2) * k).normalized()
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.12 - 0.2 * dip + 0.12 * lift))
	r.q(B_CHEST, Quaternion(Vector3.UP, -0.2 * lift))
	r.hold(1, tip - d * tl.length(), d, Vector3.DOWN, Vector3(-0.9, -0.4, 0.3))


## Grind: the blade pressed to the wheel and drawn across it, the whole back rocking with the push and the shoulders
## following, the free hand steadying the work.
static func grind(v: Variant, k: float) -> void:
	var r: Variant = v.rig
	var t: float = v._t
	var wheel: Vector3 = v._m(v.village.anchor("@wheel"))
	var tl: Vector3 = (r.tips[1] as Vector3) - (r.grip[1] as Vector3)
	var push := sin(t * 4.0)
	var tip := wheel + Vector3(0.1 * push, 0.05, 0.0)
	var d := (tip - Vector3(-0.05, 0.95, -0.15) * k).normalized()
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.2 - 0.07 * push))
	r.q(B_CHEST, Quaternion(Vector3.UP, 0.08 * push))
	r.hold(1, tip - d * tl.length(), d, Vector3.DOWN, Vector3(-0.9, -0.4, 0.3))
	r.arm_to("r", tip + Vector3(0.12, 0.02, 0.12) * k - d * tl.length() * 0.6, Vector3(0.9, -0.4, 0.3), null)
