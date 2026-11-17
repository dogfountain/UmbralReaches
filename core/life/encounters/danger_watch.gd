extends Node
## The danger watch: once a second it reads the ground under the wanderer. Crossing into a country whose pawns are well
## above the wanderer's level says so, once for each such country (saved in the story's "danger_warned"), in the toast lane
## with a low tolling; returning to ground that is no longer deadly says nothing. Never in a fight, a talk or a menu
## (the text director holds the toast), never while the opening plays. Added by the story director.
## Load by path (no class_name): const DangerWatch := preload("res://core/life/encounters/danger_watch.gd")

const Danger := preload("res://core/life/encounters/danger.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")

var _t := 3.0
var _last := ""


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or p.process_mode == Node.PROCESS_MODE_DISABLED or get_tree().paused:
		return
	var id := Tiers.region_id(p.global_position)
	if id == _last:
		return
	_last = id
	var why := Danger.warn_text(p.global_position)
	if why == "":
		return
	var seen: Variant = Travel.story.get("danger_warned", {})
	var d: Dictionary = seen if seen is Dictionary else {}
	var key := "%s:%d" % [id, Tiers.tier_at(p.global_position)]
	if d.has(key):
		return
	d[key] = true
	Travel.story["danger_warned"] = d
	Events.toast.emit(why)
