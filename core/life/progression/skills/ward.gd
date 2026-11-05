extends SkillWard
## Lantern Ward with the Kindling's ranks (progression system).
##   I   Long Wick: burns 3 s longer (and Corvin's Lamp-Glass adds 2), and its flame pulses every
##       2 s, throwing foes back off its edge (WardAura.pulse).
##   II  Close Watch: recovers in 17 s (the runtime sets cooldown); in its light your other spells
##       recover 30% faster (WardAura.kindred -> SkillBook.boost_until).
##   III Mirror Flame: spit reaching the light is turned on the nearest spitter.
## Rite of the Thorn Heart: Bramble Ward roots what crosses it.

const DB := preload("res://core/life/progression/upgrade_db.gd")
const WardAura := preload("res://core/life/progression/fx/ward_aura.gd")


func cast(book: SkillBook, _charge: float) -> bool:
	var w := LanternWard.plant(book.player)
	if w == null:
		return false
	var r := int(DB.get_mod("ward", 0))
	var extra := (3.0 if r >= 1 else 0.0) + float(DB.get_mod("ward_life", 0.0))
	if extra > 0.0:
		w.set("_t", -extra)          # LanternWard counts _t up to LIFE: starting below 0 burns longer
	var a := WardAura.new()
	a.pulse = r >= 1
	a.kindred = r >= 2
	a.mirror = r >= 3
	a.bramble = bool(DB.get_mod("bramble", false))
	a.book = book
	a.life = LanternWard.LIFE + extra
	if a.pulse or a.kindred or a.mirror or a.bramble:
		w.add_child(a)
	else:
		a.free()
	return true
