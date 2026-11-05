extends "res://core/enemy/leaper.gd"
## The Briar Hart (encounters elite). A leaper crowned with thorn antlers, bramble-bound. It
## pounces further; where it lands, a ring of thorns fills (0.8 s) and erupts. Step off the ring.

const ID := "briar_hart"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
var _was_air := false


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	leap_max = 15.0
	leap_prep = 0.55
	leap_cooldown = 3.2


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var air := _state == AIRBORNE
	if _was_air and not air and _state != DEAD and is_inside_tree():
		BossKit.zone(get_parent(), global_position, 0.8, strike_gloom * 0.7, {"by": self, "radius": 2.8, "spikes": "thorn", "color": BossKit.THORN})
	_was_air = air
