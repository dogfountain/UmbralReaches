class_name FeatureTips
extends Node
## Discoverability for the features added late: one-line lessons, once per save, in the HUD's lesson lane (ui/hints.gd), each at the
## moment it matters and naming the keys on the device in hand: the Ember Road at the second lit fire, the map's sketch after a few
## minutes' walking, the stable and the whistle and the races at the Hearthward rail, the Count after the first camp, the Gear page
## when a piece lies unworn. A two-second timer, at most one lesson a tick, and nothing at all once every lesson has been shown.
## Nothing posts over a fight, a menu, a loading screen or the opening (Hints.once and the HUD already hold those back).
## A child of the story director (class FeatureTips).

const Hints := preload("res://ui/hints.gd")
const Tally := preload("res://core/story/tally.gd")
const Courier := preload("res://core/world/mount/courier.gd")
const Days := preload("res://core/story/days.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const Horse := preload("res://core/world/mount/horse.gd")

const IDS := ["ft_road", "ft_map", "ft_stable", "ft_race", "ft_whistle", "ft_count", "ft_gear"]


func _ready() -> void:
	name = "FeatureTips"
	var t := Timer.new()
	t.wait_time = 2.0
	t.timeout.connect(_tick)
	t.autostart = true
	add_child(t)


static func _k(action: String, fallback: String) -> String:
	return Hints.key(action, fallback, Settings.using_pad)


func _done() -> bool:
	for id: String in IDS:
		if not Hints.seen(StringName(id)):
			return false
	return true


func _tick() -> void:
	if get_tree().paused or _done():
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or Player.boss_fight_active(get_tree()):
		return
	var hud: Variant = get_tree().get_first_node_in_group(&"hud")          # hud.gd has no class_name
	if hud != null and hud.lesson_busy():
		return                                             # one lesson at a time
	var st: Dictionary = Horse.state()
	var owned := (st.get("owned", []) as Array).size() > 0
	var rail := Courier.post_of(get_tree(), "palfrey")
	var near_rail := rail != null and p.global_position.distance_to(rail.global_position) < 24.0
	var ash := Travel.count("grave_ash")
	if not Hints.seen(&"ft_road") and _lit() >= 2:
		Hints.once(&"ft_road", "Lit fires are stops on the Ember Road: %s, then Hearth, then Bells, or click a lit fire on the map (%s). A short toll in grave ash is asked." % [_k("kindling", "K"), _k("world_map", "M")])
	elif not Hints.seen(&"ft_map") and Days.age() > 240.0:
		Hints.once(&"ft_map", "The map (%s) draws in the ground you have seen, and inks the places you pass. 1 to 5 hide or show tasks, fires, lamps, rares and horses." % _k("world_map", "M"))
	elif not Hints.seen(&"ft_stable") and not owned and near_rail and ash >= 40:
		Hints.once(&"ft_stable", "The palfrey at the Hearthward rail is forty grave ash. Buy it, and %s calls it to you wherever it stands." % _k("mount", "H"))
	elif not Hints.seen(&"ft_race") and owned and near_rail:
		Hints.once(&"ft_race", "At the rail, %s tends the stable: feed, groom, tack, saddlebags, parcels to carry and the Hearthward races." % _k("interact", "E"))
	elif not Hints.seen(&"ft_whistle") and owned and _horse_far(p, str(st.get("ride", ""))):
		Hints.once(&"ft_whistle", "%s whistles your horse. It comes at a run along the ground, and stands beside you." % _k("mount", "H"))
	elif not Hints.seen(&"ft_count") and int(Tally.data().get("camps", 0)) >= 1:
		Hints.once(&"ft_count", "The Count (%s) keeps your night: who you put down, the Chronicle, the eight bells, and the Long Ledger once the door is shut." % _k("tally", "B"))
	elif not Hints.seen(&"ft_gear") and _unworn_piece():
		Hints.once(&"ft_gear", "A piece of gear lies unworn in your pack: the Gear page (%s) wears it. Raise and Reforge are at a lit fire." % _k("gear", "G"))


func _lit() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if b is Brazier and (b as Brazier).lit:
			n += 1
	return n


func _horse_far(p: Node3D, breed: String) -> bool:
	if breed == "":
		return false
	var h := get_tree().get_first_node_in_group(&"stables")
	var horses: Dictionary = h.get("horses") if h != null else {}
	var n := horses.get(breed) as Node3D
	return n != null and n.global_position.distance_to(p.global_position) > 40.0 and (p.get("riding") == null)


func _unworn_piece() -> bool:
	var s := GearStats.state()
	return not (s.get("bag", []) as Array).is_empty() and GearStats.worn(s).is_empty()
