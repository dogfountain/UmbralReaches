extends Interactable
## A cresset on the roof of one of the Wardens' towers (wardens_line.gd): cold and dark until the wanderer lights it
## with E. A lit cresset burns for good (it is saved: Travel.system_state("r39_wardens").lit[tower_id]); its flame,
## its warm lights and the far beacon above it are switched on here, once, at the moment of lighting (or when the
## tower is built, if the save says it was lit). The sixth lit tower completes the Line and pays out once.
## No class_name: preload by path.

const SID := "r39_wardens"
const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")

var tower_id := ""
var tower_no := 1
var total := 6
var flames: Array[Node3D] = []         ## flame cards, halo and the warm light: hidden until lit
var cold: Array[Node3D] = []           ## the pilot glow: shown until lit
var beacon_at := Vector3.ZERO
var beacon_parent: Node3D
var _lit := false
var _beacon: Node3D


static func state() -> Dictionary:
	var st := Travel.system_state(SID)
	if not (st.get("lit") is Dictionary):
		st["lit"] = {}
	return st


static func lit_count() -> int:
	return (state().lit as Dictionary).size()


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	_lit = (state().lit as Dictionary).has(tower_id)
	_apply()


func can_interact() -> bool:
	return not _lit


func interact_text() -> String:
	return "[%s]  Light the beacon (%d of %d)" % [Interactable.prompt_key(), tower_no, total]


func interact_feel() -> StringName:
	return &"cast"


func interact(_by: Node) -> void:
	if _lit:
		return
	_lit = true
	(state().lit as Dictionary)[tower_id] = true
	_apply()
	Sfx.play("res://art/audio/ward_chime.wav", global_position, -4.0)
	Vfx.burst(global_position + Vector3.UP * 0.6, Color(2.0, 1.2, 0.5), {"count": 40, "life": 1.4, "speed": Vector2(0.6, 2.2), "size": 0.05, "gravity": -0.8, "radius": 0.5})
	var n := lit_count()
	if n >= total:
		var done := state()
		if not done.has("paid"):
			done["paid"] = true
			Travel.give("grave_ash", 40, false, false)
			Travel.give("grave_iron", 5, false, false)
			Travel.give("relic_fragment", 3, false, false)
			Events.toast.emit("The last beacon takes. The Line is lit from end to end, and the Wardens' cache is in your satchel.")
		else:
			Events.toast.emit("The Line burns again.")
	else:
		Events.toast.emit("The beacon catches. %d of %d towers lit; the next stands %s." % [n, total, "to the east" if tower_no < 4 else "farther along the road"])
	Travel.save_soon()


func _apply() -> void:
	for f in flames:
		if is_instance_valid(f):
			f.visible = _lit
	for c in cold:
		if is_instance_valid(c):
			c.visible = not _lit
	if _lit and _beacon == null and beacon_parent != null:
		_beacon = Wayfinding.beacon(beacon_parent, beacon_at, "", Color(1.0, 0.7, 0.4), 0.0, 1.4, 14.0, true, 380.0)
