extends RefCounted
## The story seat's tasks in one place (so quest_chains.gd and dialogue_db.gd each take one line): the five long tasks (quest_chains_story.gd),
## the four doors (quest_chains_doors.gd), the five regions' (quest_chains_regions.gd), the four favours (quest_chains_favours.gd) and the long walk
## (quest_chains_ending.gd). ORDER is the list for the ledger; QUESTS, PICKUPS and CONVS merge each file's own. Add the next file here. No class_name.

const StoryQ := preload("res://core/story/quest_chains_story.gd")
const DoorsQ := preload("res://core/story/quest_chains_doors.gd")
const RegionsQ := preload("res://core/story/quest_chains_regions.gd")
const FavoursQ := preload("res://core/story/quest_chains_favours.gd")
const EndingQ := preload("res://core/story/quest_chains_ending.gd")
const WanderQ := preload("res://core/story/quest_chains_wanderer.gd")

const FILES := [StoryQ, DoorsQ, RegionsQ, FavoursQ, EndingQ, WanderQ]

static var _order: Array = []
static var _quests := {}
static var _pickups := {}
static var _convs := {}
static var _givers := {"col": "Col Wright", "wenna": "Wenna Ashby"}
static var _built := false


static func order() -> Array:
	_build()
	return _order


static func quests() -> Dictionary:
	_build()
	return _quests


static func pickups() -> Dictionary:
	_build()
	return _pickups


static func convs() -> Dictionary:
	_build()
	return _convs


static func givers() -> Dictionary:
	_build()
	return _givers


static func _build() -> void:
	if _built:
		return
	_built = true
	for f: GDScript in FILES:
		var c: Dictionary = f.get_script_constant_map()
		_order.append_array(c.get("ORDER", []))
		_quests.merge(c.get("QUESTS", {}))
		_pickups.merge(c.get("PICKUPS", {}))
		_convs.merge(c.get("CONVS", {}))
		_givers.merge(c.get("GIVER_NAMES", {}))
