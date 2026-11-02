class_name SkillLance
extends Skill
## Ember Lance: hold to charge, release to throw. Damage, blast and speed scale with charge;
## a full charge pierces every body on its line and only bursts on the world.


func _init() -> void:
	id = &"lance"
	title = "Ember Lance"
	blurb = "Hold to charge, release to throw. Full charge pierces."
	action = &"skill_lance"
	cooldown = 1.4
	gloom_cost = 4.0
	trigger = Trigger.CHARGE
	max_charge = 0.9
	color = Color("#FF7A4A")
	glyph = &"lance"


func cast(book: SkillBook, charge: float) -> bool:
	var c := clampf(charge, 0.0, 1.0)
	var cfg := {
		"heavy": true,
		"dmg": lerpf(2.0, 4.0, c),
		"blast": lerpf(2.0, 3.2, c),
		"speed": lerpf(18.0, 30.0, c),
		"pierce": c >= 0.98,
	}
	if book.player.fire_bolt(cfg) == null:
		return false
	book.player.kick(0.25 + c * 0.6)
	return true
