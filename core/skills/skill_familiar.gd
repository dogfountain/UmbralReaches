extends Skill
## Bound Shade (learned at the Kindling, r28): bind a shade that circles you for 14 s and looses
## darts at the foe nearest your aim (bound_shade.gd). Ranks (UpgradeDB.live "familiar"):
## I Keen Eyes (a dart every 0.75 s, curving home); II Twin Shades (two); III Last Breath (it
## dives and detonates the Marks around it when its time runs out). The Sexton's Wisp-Jar (charm)
## adds 6 s and makes darts burst on Marked foes. Casting again releases the old ones.
## Preload by path (no class_name).

const DB := preload("res://core/life/progression/upgrade_db.gd")
const Shade := preload("res://core/skills/bound_shade.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")

const LIFE := 14.0

var bound: Array = []          ## the shades from the last cast


func _init() -> void:
	id = &"familiar"
	title = "Bound Shade"
	blurb = "Bind a shade that circles you and darts at your foes, Marking them."
	action = &"skill_ward"
	cooldown = 22.0
	gloom_cost = 8.0
	color = Color("#C9B8FF")
	glyph = &"familiar"
	pose = &"ward"
	cast_time = 1.0             # r33: a rooted cast (moving cancels it)


func rank() -> int:
	return int(DB.get_mod("familiar", 0))


func active(_book: SkillBook) -> float:
	var best := 0.0
	for s: Variant in bound:
		if is_instance_valid(s) and not bool((s as Node).get("_gone")):
			best = maxf(best, float((s as Node).call("remaining")))
	return best


func cast(book: SkillBook, _charge: float) -> bool:
	var p := book.player
	var host := p.get_tree().current_scene
	if host == null:
		return false
	for s: Variant in bound:
		if is_instance_valid(s) and s is Shade and not (s as Shade)._gone:
			(s as Shade)._fade()
	bound.clear()
	var r := rank()
	var jar := bool(DB.get_mod("jar", false))
	var n := 2 if r >= 2 else 1
	for k in n:
		var s := Shade.new()
		s.owner_p = p
		s.life = LIFE + (6.0 if jar else 0.0)
		s.rate = 0.75 if r >= 1 else 1.1
		s.seek = r >= 1
		s.last_breath = r >= 3
		s.jar = jar
		s.marks = 2 if bool(DB.get_mod("chalk", false)) else 1
		s.power = float(DB.get_mod("power", 1.0))
		s.phase = PI * float(k)
		s.set("_cd", 0.5 + 0.35 * float(k))          # twins loose on alternate beats
		host.add_child(s)
		bound.append(s)
	var at := p.global_position + Vector3.UP * 1.6
	SpellFx.shell(at, 0.2, 1.6, Color(1.1, 0.8, 2.6), 0.3)
	Vfx.burst(at, Color(1.3, 1.0, 3.0), {"count": 36, "life": 0.6, "speed": Vector2(0.4, 2.0), "size": 0.045, "gravity": 0.8, "radius": 0.7, "radial": -3.0, "trail": 0.08})
	StaffSfx.play("familiar", at, -2.0)
	return true
