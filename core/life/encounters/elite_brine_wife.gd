extends "res://core/enemy/husk.gd"
## East Marches: the Brine-Wife, Bitter Mother (encounters elite, the White Pans' named mini-boss).
## A husk crusted white to the shoulder who has boiled the pans down for thirty years and not stopped.
## Every few seconds in close she stops, lifts her ladle, and the brine comes up through the crust round
## her: a wide ring fills for a full second, then bursts (Brine Burst: walk out of it). Past half health
## she also breaks the crust round YOU: three crystals grow out of the white at your feet a moment
## after the ring (Crystal Bloom: keep moving).

const ID := "brine_wife"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
const RING_EVERY := 6.0
const RING_TELL := 1.0
const RING_R := 3.8
const BLOOM_EVERY := 9.0
const SALTY := Color(1.5, 1.7, 2.0)
var _ring_cd := 3.0
var _bloom_cd := 7.0


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	can_slam = false           # her own move is the brine ring


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _think() -> void:
	_ring_cd -= 1.0 / think_hz
	_bloom_cd -= 1.0 / think_hz
	if _ring_cd <= 0.0 and _state == CHASE and _p != null and _dist < RING_R + 0.9 and is_on_floor():
		_ring_cd = RING_EVERY
		_set_state(RECOVER)
		_state_t = -RING_TELL
		begin_cast("Brine Burst", RING_TELL, false)
		if _rig is HunchRig:
			(_rig as HunchRig).telegraph(RING_TELL)
		_glint = 1.0
		Sfx.play_stream(Kit.Synth.get_stream("roar"), global_position + Vector3.UP * 1.5, -2.0, 0.65)
		BossKit.zone(get_parent(), global_position, RING_TELL, strike_gloom * 0.9, {"by": self, "radius": RING_R, "color": SALTY})
		return
	if _bloom_cd <= 0.0 and hp < float(max_hp) * 0.5 and _state == CHASE and _p != null and _dist < 12.0 and is_on_floor():
		_bloom_cd = BLOOM_EVERY
		begin_cast("Crystal Bloom", 1.3, false)
		var c := _p.global_position
		for i in 3:
			var a := TAU * float(i) / 3.0 + randf() * 0.8
			BossKit.zone(get_parent(), c + Vector3(cos(a), 0.0, sin(a)) * (1.2 + 0.9 * float(i)), 1.3 + 0.2 * float(i), strike_gloom * 0.7,
				{"by": self, "radius": 1.5, "spikes": "bone", "color": SALTY})
		return
	super._think()
