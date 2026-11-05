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
## Hotbar icon drawn in code (bolt, lance, nova, ward, step, tether, well, familiar).
@export var glyph: StringName = &"bolt"
## The wanderer's cast pose (CharacterRig.cast_pose); empty = the id. Learned spells borrow one.
@export var pose: StringName = &""
## r33 combat: seconds of the shared global cooldown this spell starts (0 = off the GCD: it neither
## starts nor waits for it, like the Rift Bolt's own cadence and the Rift Step).
@export var gcd := 0.5
## r33 combat: seconds of casting before it goes off (0 = instant). A cast can be queued, pushed
## back by a blow, interrupted by a hard one, and made instant by a Rift Surge.
@export var cast_time := 0.0
## r33 combat: may the wanderer walk while casting it? false = moving cancels the cast.
@export var cast_moving := false
## r33 combat: damage school for the combat feed (&"umbral", &"ember", &"physical", &"light").
@export var school: StringName = &"umbral"


## "" when the cast may go ahead, otherwise a short reason shown on the hotbar.
func can_cast(_book: SkillBook) -> String:
	return ""


## Combo readout for the hotbar: (filled, total) pips over the slot; (0, 0) draws none.
func pips(_book: SkillBook) -> Vector2i:
	return Vector2i.ZERO


## True when the next cast is the empowered one (the hotbar lights the slot).
func primed(_book: SkillBook) -> bool:
	return false


## 0..1 while something the skill made is still working (a Bound Shade, an open Well): the hotbar
## draws it as a thin bar under the slot. 0 draws nothing.
func active(_book: SkillBook) -> float:
	return 0.0


## Do the thing. `charge` is 0..1 for CHARGE skills, else 0. Return false to refund the cooldown.
func cast(_book: SkillBook, _charge: float) -> bool:
	return false
