extends Skill
## Umbral Well (learned at the Kindling, r28): open a well of dark where the crosshair meets the
## ground (up to 22 m). The well (umbral_well.gd) drags, slows and Marks for a few seconds, then
## collapses. Ranks (UpgradeDB.live "well"): I wider (5.5 m), stronger, 4 s; II Hungry Dark (eats
## spit, throws it back); III Event Horizon (the collapse detonates every Mark inside).
## An Ember Lance bursting over an open well lights a MAELSTROM. Preload by path (no class_name).

const DB := preload("res://core/life/progression/upgrade_db.gd")
const Aim := preload("res://core/skills/aim.gd")
const Well := preload("res://core/skills/umbral_well.gd")

const REACH := 22.0

var last: Node3D               ## the well opened by the last cast (tests, the hotbar)


func _init() -> void:
	id = &"well"
	title = "Umbral Well"
	blurb = "Open a well where you aim: it drags foes in, slows and Marks them, then collapses."
	action = &"skill_ward"
	cooldown = 11.0
	gloom_cost = 5.0
	color = Color("#8A6CFF")
	glyph = &"well"
	pose = &"nova"
	cast_time = 0.6             # r33: a rooted cast (moving cancels it)


func rank() -> int:
	return int(DB.get_mod("well", 0))


func active(_book: SkillBook) -> float:
	if last == null or not is_instance_valid(last) or bool(last.get("_done")):
		return 0.0
	var total := float(last.get("life")) + Well.OPEN
	return clampf(1.0 - float(last.get("_t")) / total, 0.0, 1.0)


func cast(book: SkillBook, _charge: float) -> bool:
	var p := book.player
	var host := p.get_tree().current_scene
	if host == null:
		return false
	var r := rank()
	var at := Aim.ground_at_aim(p, REACH)
	for old in p.get_tree().get_nodes_in_group(&"umbral_well"):
		if old is Well and not (old as Well)._done:
			(old as Well)._collapse()             # one well at a time: the old one collapses now
	var w := Well.new()
	w.radius = 5.5 if r >= 1 else 4.5
	w.life = (4.0 if r >= 1 else 3.0) + float(DB.get_mod("well_life", 0.0))
	w.hungry = r >= 2
	w.horizon = r >= 3
	w.power = float(DB.get_mod("power", 1.0))
	w.mark_dmg = float(DB.get_mod("mark_dmg", 0.0)) + (0.5 if bool(DB.get_mod("tally", false)) else 0.0)
	w.by = p
	w.position = at
	host.add_child(w)
	last = w
	# the staff throws a thread of dark down to where it opens
	Vfx.arc(Aim.muzzle(p), at + Vector3.UP * 1.1, Color(1.2, 0.5, 2.8), 0.3, 0.35)
	p.kick(0.35)
	return true
