class_name Skill
extends Resource
## One hotbar ability. Data lives in the fields; behaviour lives in cast().
## SkillBook owns cooldowns, input and the hotbar contract, so a new skill is one small subclass.

enum Trigger {
	PRESS,        ## fires once on press
	HOLD_REPEAT,  ## fires every cooldown while held (Rift Bolt)
	CHARGE,       ## hold to build, release to fire; auto-fires at overcharge (Ember Lance)
}

@export var id: StringName = &"skill"
@export var title := "Skill"
@export_multiline var blurb := ""
@export var action: StringName = &""
@export var cooldown := 1.0
## Dark magic draws on the dark: this much Gloom is added when the cast lands.
@export var gloom_cost := 0.0
@export var trigger: Trigger = Trigger.PRESS
## CHARGE only: seconds to full charge.
@export var max_charge := 0.0
@export var color := Color("#A98BFF")
## Hotbar icon drawn in code (bolt, lance, nova, ward, step).
@export var glyph: StringName = &"bolt"


## "" when the cast may go ahead, otherwise a short reason shown on the hotbar.
func can_cast(_book: SkillBook) -> String:
	return ""


## Do the thing. `charge` is 0..1 for CHARGE skills, else 0. Return false to refund the cooldown.
func cast(_book: SkillBook, _charge: float) -> bool:
	return false
