class_name SkillStep
extends Skill
## Rift Step: a true teleport ~7.5 m in the move direction (camera forward with no input).
## A tear opens where you were and where you arrive; strikes, spit and a shade's touch pass
## through you for a moment, and any enemy on the line between takes an Umbral Mark.


func _init() -> void:
	id = &"step"
	title = "Rift Step"
	blurb = "Teleport ~7.5 m. Briefly untouchable. Marks everything on the line."
	action = &"skill_step"
	cooldown = 2.1
	color = Color("#7FA8FF")
	glyph = &"step"
	gcd = 0.0                   # r33: a movement escape is off the global cooldown


func can_cast(book: SkillBook) -> String:
	return "" if book.player.can_shadowstep() else "busy"


func cast(book: SkillBook, _charge: float) -> bool:
	return book.player.shadowstep()
