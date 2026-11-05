class_name SkillLance
extends Skill
## Ember Lance: hold to charge, release to throw. Damage, blast and speed scale with charge;
## a full charge pierces every body on its line and only bursts on the world.


func _init() -> void:
	id = &"lance"
	title = "Ember Lance"
	blurb = "Hold to charge, release to throw. Full charge pierces and hits hardest."
	action = &"skill_lance"
	cooldown = 1.0              # r30: was 1.4 + 4 Gloom; the heavy verb lost to a held bolt at everything
	gloom_cost = 0.0
	trigger = Trigger.CHARGE
	max_charge = 0.9
	color = Color("#FF7A4A")
	glyph = &"lance"
	school = &"ember"


const BLAST_MIN := 3.0      ## blast radius at a tap ...
const BLAST_MAX := 4.6      ## ... and at full charge (the aim circle reads these too)
const DMG_TAP := 2.0        ## damage at a tap ...
const DMG_FULL := 6.5       ## ... and at full charge (r30: was 4; ~3.4 dps on a 1.9 s cycle vs the held bolt's ~4.8 / 3.6 hot)


## Burst radius a throw at charge `c` will have (the aim circle should read this, not the consts).
func blast_at(c: float) -> float:
	return lerpf(BLAST_MIN, BLAST_MAX, clampf(c, 0.0, 1.0))


func cast(book: SkillBook, charge: float) -> bool:
	var c := clampf(charge, 0.0, 1.0)
	var cfg := {
		"heavy": true,
		"dmg": lerpf(DMG_TAP, DMG_FULL, c),
		"blast": lerpf(BLAST_MIN, BLAST_MAX, c),
		"speed": lerpf(18.0, 30.0, c),
		"pierce": c >= 0.98,
	}
	if book.player.fire_bolt(cfg) == null:
		return false
	book.player.kick(0.25 + c * 0.6)
	return true
