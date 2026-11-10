extends Node
## The reward rules (core/items/rewards.gd) without a world: a boss kill pays its trophy, ash and the
## Thornwarden's attuned relic; an ordinary kill pays ash; a bell keeper's relic arrives attuned.
##   HOME=<scratch> godot --headless --path . res://zz/rewards_test.tscn
const Rewards := preload("res://core/items/rewards.gd")
var bad := 0


func check(what: String, cond: bool, extra := "") -> void:
	if cond:
		print("REWARDS ok ", what)
	else:
		bad += 1
		print("REWARDS FAIL ", what, " ", extra)


func _ready() -> void:
	Travel.use_slot(3, true)
	var r := Rewards.new()
	add_child(r)

	Events.boss_slain.emit("thornwarden")
	var trophy: String = ItemDB.BOSS_TROPHY["thornwarden"]
	check("boss: trophy", Travel.count(trophy) == 1)
	check("boss: ash", Travel.count("grave_ash") == ItemDB.ASH_PER_BOSS, str(Travel.count("grave_ash")))
	check("boss: recorded", Travel.bosses_slain.has("thornwarden"))
	check("boss: Thorn Heart attuned", Travel.relics.get("thorn") == &"splinter", str(Travel.relics))

	var ash := Travel.count("grave_ash")
	var plain := Node.new()
	add_child(plain)
	Events.enemy_killed.emit(plain)
	check("kill: ash", Travel.count("grave_ash") == ash + ItemDB.ASH_PER_KILL)
	var boss := Node.new()
	boss.set_meta(&"boss_id", "x")
	add_child(boss)
	ash = Travel.count("grave_ash")
	Events.enemy_killed.emit(boss)
	check("kill: a boss body pays no kill ash", Travel.count("grave_ash") == ash)

	Travel.give("slag_heart", 1, false)
	var rk := "slag"
	check("bell relic attuned", Travel.relics.get(rk) == (Reliquary.VARIANTS[rk] as Array)[0], str(Travel.relics))

	Travel.use_slot(1, true)
	print("REWARDS TEST ", "PASS" if bad == 0 else "FAIL %d" % bad)
	get_tree().quit(1 if bad > 0 else 0)
