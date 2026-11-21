extends "res://core/enemy/spitter.gd"
## The Answerer (encounters elite, the Well of Echoes' landing). A hooded spitter ringed with halos
## of struck bronze. Whatever it throws, the ground answers: the place you stood when it spat is
## marked, and about two seconds later it rings (a wide pale disc, then the blast). Keep moving;
## standing to dodge the orb is what the echo is for. At half health it calls two drowned wretches
## up out of the pool's dark.

const ID := "well_answer"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
const Guardians := preload("res://core/life/encounters/guardians.gd")
const ECHO_DELAY := 1.9
const ECHO_R := 2.4
const ECHO_COL := Color(0.55, 1.1, 1.8)
var _called := false


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	spit_gloom = 10.0
	spit_cooldown = 3.1
	kite_min = 6.0
	kite_max = 11.0
	fire_range = 16.0
	spit_cast = "The Calling"


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _spit() -> void:
	if _p == null:
		return
	var stood := _p.global_position
	super._spit()
	Sfx.play_stream(Kit.Synth.get_stream("bone"), stood + Vector3.UP * 1.2, -1.0, 0.55)
	BossKit.zone(get_parent(), stood, ECHO_DELAY, spit_gloom * 1.3, {"by": self, "radius": ECHO_R, "color": ECHO_COL})


func take_hit(dmg: float, from: Node = null) -> void:
	super.take_hit(dmg, from)
	if not _called and _state != DEAD and hp <= float(max_hp) * 0.5 and is_inside_tree():
		_called = true
		BossKit.roar(self, "The Answerer calls up the dark.", ECHO_COL)
		var wretch := load("res://core/enemy/wretch.gd") as GDScript
		var tier := int(get_meta(&"enc_tier", 0))
		BossKit.summon_spread(get_parent(), wretch, global_position, 2, 3.0, "elite_" + ID, func(m: Enemy) -> void:     # one a frame
			Guardians.scale_summoned([m], tier, "wretch"))
