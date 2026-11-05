class_name SkillWard
extends Skill
## Lantern Ward: plant a warm light for a few seconds. It is a real LightGrid zone, so Gloom
## drains inside it (slowly, capped: LanternWard.DRAIN), shades come apart on its edge, lesser
## enemies slink and nothing respawns in it. It is not a fire: no rest, no tide break, and
## bosses and elites ignore it.


func _init() -> void:
	id = &"ward"
	title = "Lantern Ward"
	blurb = "Plant a light for 7 s. Drains a little Gloom, holds lesser foes off, unmakes shades."
	action = &"skill_ward"
	cooldown = 24.0
	color = Color("#FFB347")
	glyph = &"ward"
	school = &"light"


func cast(book: SkillBook, _charge: float) -> bool:
	return LanternWard.plant(book.player) != null
