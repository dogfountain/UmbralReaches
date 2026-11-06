extends Skill
## The Founder's Peal (r36 Act II; Brannoc teaches it when the peal is answered). The bell in you is
## struck: a stroke goes out in a cone before you. Every foe in it takes a blow and a Mark and is
## staggered (the great ones are not: they take it harder at rank III); enemy spit in it is knocked
## out of the air. Ranks (UpgradeDB "peal"): I a wider, longer cone; II Resonance: a Marked foe takes
## a second Mark and 0.5 more per Mark it carried; III Great Bell: double on bosses, and a slow.
## The Last Mark (the Bell-Hewer's relic) changes it (Reliquary "mason"):
##   toll      one great stroke in a narrow cone: twice the damage, staggers twice
##   carillon  three quick rings all round you, each a light blow and a Mark
## Preload by path (no class_name).
const DB := preload("res://core/life/progression/upgrade_db.gd")
const Afflict := preload("res://core/skills/afflict.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Aim := preload("res://core/skills/aim.gd")

const REACH := 9.0
const REACH_WIDE := 11.0
const HALF := 37.5               ## degrees either side (75 in all)
const HALF_WIDE := 55.0
const HALF_TOLL := 22.0
const DMG := 1.0
const CAR_R := 6.0               ## the carillon's rings, all round
const CAR_DMG := 0.45
const CAR_GAP := 0.22
const GOLD := Color(3.2, 2.4, 1.1)

var struck := 0                  ## foes the last stroke struck (tests)


func _init() -> void:
	id = &"peal"
	title = "Founder's Peal"
	blurb = "Strike the bell in you: a cone of sound that staggers and Marks."
	action = &"skill_ward"
	cooldown = 9.0
	gloom_cost = 0.0
	color = Color("#E8C27A")
	glyph = &"peal"
	pose = &"nova"
	school = &"light"


func rank() -> int:
	return int(DB.get_mod("peal", 0))


func cast(book: SkillBook, _charge: float) -> bool:
	var p := book.player
	var r := rank()
	var power := float(DB.get_mod("power", 1.0))
	var v := Reliquary.variant("mason")
	if v == &"carillon":
		_carillon(p, r, power)
		return true
	var reach := (REACH_WIDE if r >= 1 else REACH) + float(DB.get_mod("peal_reach", 0.0))
	var half := HALF_TOLL if v == &"toll" else (HALF_WIDE if r >= 1 else HALF)
	var mult := 2.0 if v == &"toll" else 1.0
	var fwd := Aim.forward(p)
	struck = _stroke(p, p.global_position, fwd, reach, half, DMG * mult * power, r, 2 if v == &"toll" else 1)
	_stroke_fx(p, reach, half)
	# r36 gear trait: the stroke rings again half a second on, at half strength, from where it began
	if bool(DB.get_mod("peal_echo", false)):
		var pid := p.get_instance_id()
		var from := p.global_position
		p.get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
			var p2 := instance_from_id(pid) as Player
			if p2 != null and p2.is_inside_tree():
				struck += _stroke(p2, from, fwd, reach, half, DMG * mult * power * 0.5, r, 0)
				_stroke_fx(p2, reach * 0.8, half))
	p.kick(0.35)
	return true


## One stroke: every live foe within `reach` and `half` degrees of `fwd` (flat). Returns the count.
func _stroke(p: Player, from: Vector3, fwd: Vector3, reach: float, half: float, dmg: float, r: int, staggers: int) -> int:
	var f := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var cosv := cos(deg_to_rad(half))
	var n := 0
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - from
		if absf(d.y) > 3.5:
			continue
		d.y = 0.0
		var dist := d.length()
		if dist > reach or (dist > 0.5 and d.normalized().dot(f) < cosv):
			continue
		var had := e.marks
		var hit := dmg + (0.5 * float(had) if r >= 2 else 0.0)
		if e.boss and r >= 3:
			hit *= 2.0
		e.take_hit(hit, p)
		e.add_mark(2 if r >= 2 and had > 0 else 1)
		if not e.boss:
			if staggers > 0:
				e.stagger(0.6 * float(staggers - 1))   # the toll's second stagger is a longer reel, not a second "broken"
		if r >= 3:
			Afflict.slow(e, 0.5, 2.0)
		n += 1
	# spit in the cone is knocked out of the air
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
		var s := node as Node3D
		if s == null or not s.has_method("pop"):
			continue
		var ds := s.global_position - from
		ds.y = 0.0
		if ds.length() <= reach and (ds.length() < 0.5 or ds.normalized().dot(f) >= cosv):
			s.call("pop")
	return n


func _stroke_fx(p: Player, reach: float, half: float) -> void:
	var at := p.global_position + Vector3.UP * 1.1
	var f := Aim.forward(p)
	f.y = 0.0
	f = f.normalized()
	for k in 3:
		Vfx.ring(at + f * (0.6 + 0.9 * float(k)), 0.8 + reach * 0.22 * float(k + 1), GOLD * (1.0 - 0.25 * float(k)), 0.35 + 0.08 * float(k), 0.06, f, 1.0)
	Vfx.burst(at + f * 1.2, GOLD, {"count": 26, "life": 0.4, "speed": Vector2(4.0, 9.0), "size": 0.04, "gravity": 0.0, "trail": 0.08, "dir": f, "spread": half})
	# the flash is a ball that stays inside the cone: tangent to its edges, its far side at the reach
	var sn := sin(deg_to_rad(clampf(half, 5.0, 85.0)))
	var ball := reach * sn / (1.0 + sn)
	Vfx.light(at + f * (ball / sn), Color(1.0, 0.8, 0.45), 3.0, ball, 0.3)
	StaffSfx.play("nova", at, -3.0, 0.62)


## The Carillon: three quick rings all round, a light blow and a Mark each.
func _carillon(p: Player, r: int, power: float) -> void:
	struck = 0
	var pid := p.get_instance_id()
	for k in 3:
		var ring := k                       # this ring's own index, kept for its timer
		p.get_tree().create_timer(CAR_GAP * float(ring), false).timeout.connect(func() -> void:
			var p2 := instance_from_id(pid) as Player
			if p2 == null or not p2.is_inside_tree():
				return
			struck += _stroke(p2, p2.global_position, Vector3.FORWARD, CAR_R, 180.0, CAR_DMG * power, r, 0)
			Vfx.ring(p2.global_position + Vector3.UP * 0.1, CAR_R * (0.6 + 0.2 * float(ring)), GOLD, 0.3, 0.05, Vector3.UP, 1.0)
			StaffSfx.play("nova", p2.global_position, -6.0, 0.9 + 0.12 * float(ring)))
