class_name SkillStep
extends Skill
## Shadowstep: a short blink in the move direction (camera forward with no input). The body
## vanishes into motes, so strikes, spit and a shade's touch pass through, and any enemy you
## step through takes an Umbral Mark.


func _init() -> void:
	id = &"step"
	title = "Shadowstep"
	blurb = "Blink ~3.5 m. Untouchable while stepping. Marks what you pass through."
	action = &"skill_step"
	cooldown = 1.6
	color = Color("#7FA8FF")
	glyph = &"step"


func can_cast(book: SkillBook) -> String:
	return "" if book.player.can_shadowstep() else "busy"


func cast(book: SkillBook, _charge: float) -> bool:
	return book.player.shadowstep()
