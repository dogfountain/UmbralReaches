class_name SkillBolt
extends Skill
## Rift Bolt: the spammable primary. Each hit leaves an Umbral Mark that Nova detonates.


func _init() -> void:
	id = &"bolt"
	title = "Rift Bolt"
	blurb = "Fast bolt. Hits leave an Umbral Mark (max 3)."
	action = &"skill_bolt"
	cooldown = 0.34
	trigger = Trigger.HOLD_REPEAT
	color = Color("#A98BFF")
	glyph = &"bolt"


func cast(book: SkillBook, _charge: float) -> bool:
	return book.player.fire_bolt({"dmg": 1.0, "blast": 1.2, "speed": 28.0, "marks": 1}) != null
