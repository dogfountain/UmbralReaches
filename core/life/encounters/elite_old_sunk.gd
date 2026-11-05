extends "res://core/enemy/husk.gd"
## Old Sunk, Three Stones (encounters elite). A drowned husk wearing the three stones he was sunk
## under. Every few seconds in close he stops, raises his arms, and the fen rings round him: a
## wide disc fills for a full second, then slams. Walk out of the ring.

const ID := "old_sunk"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
const RING_EVERY := 6.5
const RING_TELL := 1.0
const RING_R := 3.6
var _ring_cd := 3.0


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	can_slam = false           # his own move is the fen ring (the Husk's fist slam would crowd it)


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _think() -> void:
	_ring_cd -= 1.0 / think_hz
	if _ring_cd <= 0.0 and _state == CHASE and _p != null and _dist < RING_R + 0.8 and is_on_floor():
		_ring_cd = RING_EVERY
		_set_state(RECOVER)
		_state_t = -RING_TELL                  # stands still through the tell
		begin_cast("Fen Surge", RING_TELL, false)   # r33: its cast bar (walk out of the ring)
		if _rig and _rig.has_method("telegraph"):
			_rig.call("telegraph", RING_TELL)
		_glint = 1.0
		Sfx.play_stream(Kit.Synth.get_stream("roar"), global_position + Vector3.UP * 1.5, -2.0, 0.7)
		BossKit.zone(get_parent(), global_position, RING_TELL, strike_gloom * 0.9, {"by": self, "radius": RING_R, "color": Color(0.3, 1.6, 1.2)})
		return
	super._think()
