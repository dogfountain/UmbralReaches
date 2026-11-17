extends Node
## The night's own days. A daily task used to come back every ten minutes of the village clock, and the count of nights was
## never saved, so a relaunch restarted it. A night now passes when the wanderer makes camp at a lit fire (core/world/camp_rite.gd)
## after at least MIN_NIGHT_S seconds of play since the last one: the number is kept in Travel.story["night_no"] and the dailies
## (core/story/quest_book.gd today()) read it. This node ticks the playtime of the current night (story["night_age"]).
## Load by path (no class_name): const Days := preload("res://core/story/days.gd")

const MIN_NIGHT_S := 600.0

var _acc := 0.0                 ## playtime not yet written to the story (written once a second: no per-frame dictionary work)


static func current() -> int:
	return int(Travel.story.get("night_no", 0))


static func today() -> String:
	return "night %d" % current()


static func age() -> float:
	return float(Travel.story.get("night_age", 0.0))


## Has enough of the night gone for a camp to begin the next one?
static func due() -> bool:
	return age() >= (300.0 if Vows.has("longnight") else MIN_NIGHT_S)


## Begin the next night. True when one passed (it needed MIN_NIGHT_S of play since the last).
static func advance() -> bool:
	if not due():
		return false
	Travel.story["night_no"] = current() + 1
	Travel.story["night_age"] = 0.0
	return true


func _ready() -> void:
	name = "Days"
	add_to_group(&"days")


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_acc += delta
	if _acc >= 1.0:
		Travel.story["night_age"] = age() + _acc
		_acc = 0.0
