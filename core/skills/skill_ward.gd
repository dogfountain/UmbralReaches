class_name SkillWard
extends Skill
## Lantern Ward: plant a warm light for a few seconds. It is a real LightGrid zone, so Gloom
## drains inside it, shades come apart on its edge, enemies slink and nothing respawns in it.


func _init() -> void:
	id = &"ward"
	title = "Lantern Ward"
	blurb = "Plant a safe light for 7 s. Drains Gloom, unmakes shades."
	action = &"skill_ward"
	cooldown = 24.0
	color = Color("#FFB347")
	glyph = &"ward"


func cast(book: SkillBook, _charge: float) -> bool:
	return LanternWard.plant(book.player) != null
