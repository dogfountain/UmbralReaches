extends Skill
## r35: a hotbar slot the story has not filled yet (docs/critique/r35_full.md: start with Rift Bolt;
## the Keep, the first kill, the first seal and the first great one teach the other four). It casts
## nothing, draws as an empty slot with no name, and says why if you press it.
## Load by path (no class_name).


func _init() -> void:
	id = &"sealed"
	title = ""
	blurb = "Not yet taught."
	cooldown = 0.0
	gcd = 0.0
	glyph = &""
	color = Color(0.32, 0.3, 0.38)


func can_cast(_book: SkillBook) -> String:
	return "Not yet taught."


func cast(_book: SkillBook, _charge: float) -> bool:
	return false
