extends "res://core/enemy/spitter.gd"
## The Cinder Cantor (encounters elite). The last voice of the Stair's choir: a spitter with a
## ruff, a halo of coals and a censer. It spits a fan of three coals (the middle one aimed), so a
## short step sideways is not enough -- close in.

const ID := "cinder_cantor"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
const FAN := 0.26


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	spit_gloom = 9.0
	spit_cooldown = 2.8
	kite_min = 7.0
	kite_max = 12.0
	fire_range = 17.0
	spit_cast = "Coal Fan"          # r33: its cast bar


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _spit() -> void:
	if _p == null:
		return
	var from := global_position + Vector3.UP * 1.8
	if _sac:
		from = _sac.global_position
	var aim := _p.global_position + Vector3.UP * 1.05
	var t := from.distance_to(aim) / SpitOrb.SPEED
	aim.y += 0.5 * SpitOrb.SAG * t * t
	var dir := aim - from
	for k in 3:
		var d := dir.rotated(Vector3.UP, FAN * float(k - 1))
		SpitOrb.launch(get_tree().current_scene, from, d, spit_gloom)
	Sfx.play("res://art/audio/spit.wav", from, -1.0, 0.8)
	Vfx.burst(from, Color(2.2, 0.8, 0.2), {"count": 24, "life": 0.35, "speed": Vector2(1.0, 3.5), "size": 0.05, "dir": dir.normalized(), "spread": 40.0, "gravity": -6.0})
