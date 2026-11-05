extends "res://core/enemy/ossuant.gd"
## Brother Lisle, the Counted (encounters elite). An ossuant with tally boards strapped to his
## ribs. At half strength he calls the count once (a roar; two crawlers rise beside him). He
## heaps and knits like any ossuant, but only twice: the third fall is the last, marked or not.

const ID := "lisle"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
var _called := false
var _rises := 0


func _init() -> void:
	super._init()
	Kit.stats(self, ID)


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func take_hit(dmg: float, from: Node = null) -> void:
	super.take_hit(dmg, from)
	if not _called and _state != DEAD and hp <= float(max_hp) * 0.5 and is_inside_tree():
		_called = true
		BossKit.roar(self, "Brother Lisle calls the count.", Color(1.2, 0.55, 2.6))
		var crawler := load("res://core/enemy/crawler.gd") as GDScript
		BossKit.summon(get_parent(), crawler, global_position, 2, 3.2, "elite_" + ID)


func _die() -> void:
	if _rises >= 2 and marks <= 0:
		marks = 1                      # the count is finished: no third rising
	elif marks <= 0 and not _heap:
		_rises += 1
	super._die()
