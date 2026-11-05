extends SkillStep
## Rift Step with the Kindling's ranks (progression system).
##   I   Long Stride: 9.5 m (the runtime sets step_range), and you arrive with a SHOCK that throws
##       back every foe within 2.5 m (0.5 damage).
##   II  Slip: untouchable 0.6 s (step_evade), and the first bolt within SLIP s is a Rift Lash
##       (player meta slip_lash_until, read by the ranked Rift Bolt: combo SLIP LASH).
##   III Rend: the tear left behind bursts a moment later.
## Oath of the Open Door: every step takes 3 Gloom off you (the runtime halves the cooldown).
## Briar Antler (an elite's bounty, worn): the step roots what it passes.

const DB := preload("res://core/life/progression/upgrade_db.gd")
const RiftRend := preload("res://core/life/progression/fx/rift_rend.gd")
const StepMist := preload("res://core/life/progression/fx/step_mist.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const SHOCK_R := 2.5
const SHOCK_DMG := 0.5
const SLIP := 1.5


func cast(book: SkillBook, _charge: float) -> bool:
	var from := book.player.global_position
	if not book.player.shadowstep():
		return false
	var r := int(DB.get_mod("step", 0))
	if r >= 1:
		_shock(book.player, float(DB.get_mod("power", 1.0)))
	if bool(DB.get_mod("ferrule", false)):
		_ferrule(book.player)
	if r >= 2:
		book.player.set_meta(&"slip_lash_until", Time.get_ticks_msec() * 0.001 + SLIP)
	if r >= 3:
		RiftRend.open(book.player, from, float(DB.get_mod("power", 1.0)))
	if bool(DB.get_mod("step_briar", false)):
		_briar_path(book.player, from, book.player.global_position)
	if bool(DB.get_mod("door", false)):
		book.player.mend(3.0)                     # r35: the Door mends Wounds
	# r36 Fog-Shepherd's Crook: Harrow Marks round the arrival and recovers faster; Mist fogs the start
	match Reliquary.variant("fog"):
		&"harrow":
			_harrow(book.player)
			var i := book.slots.find(self)
			(func() -> void: book.refund(i, cooldown * HARROW_CD)).call_deferred()
		&"mist":
			_mist(book.player, from)
	return true


const HARROW_R := 3.5
const HARROW_CD := 0.3          ## share of the recovery handed back
const MIST_R := 3.0
const MIST_LIFE := 3.0


## r36 Harrow: every foe within HARROW_R of the arrival takes a Mark.
func _harrow(p: Player) -> void:
	var at := p.global_position
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e and e.is_alive() and e.global_position.distance_to(at) <= HARROW_R:
			e.add_mark(1)
	Vfx.ring(at + Vector3.UP * 0.05, HARROW_R, Color(1.2, 1.4, 3.0), 0.3, 0.06, Vector3.UP, 1.0)


## r36 Mist: the place you left fogs over for MIST_LIFE s; foes inside are slowed by half (Afflict).
func _mist(p: Player, at: Vector3) -> void:
	var host := p.get_tree().current_scene
	if host == null:
		return
	var fog := StepMist.new()
	fog.radius = MIST_R
	fog.life = MIST_LIFE
	fog.position = at                 # before entering the tree: _ready rings it where it stands
	host.add_child(fog)


## Edda's Ferrule (quest charm): the arrival rings like iron and Marks every foe within 2 m.
func _ferrule(p: Player) -> void:
	var at := p.global_position
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e and e.is_alive() and e.global_position.distance_to(at) <= 2.0:
			e.add_mark(1)
	Vfx.ring(at + Vector3.UP * 0.05, 2.0, Color(2.2, 2.1, 2.4), 0.25, 0.06, Vector3.UP, 1.0)
	StaffSfx.play("tap", at, -2.0, 0.8)


## Long Stride: the arrival throws back what stands round it.
func _shock(p: Player, power: float) -> void:
	var at := p.global_position
	var n := 0
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - at
		d.y = 0.0
		var dist := d.length()
		if dist > SHOCK_R or absf(e.global_position.y - at.y) > 2.0:
			continue
		e.take_hit(SHOCK_DMG * power, p)
		e.shove((d / dist if dist > 0.1 else -p.global_basis.z) * 9.0 * (0.35 if e.boss else 1.0))
		n += 1
	Vfx.ring(at + Vector3.UP * 0.08, SHOCK_R, Color(1.4, 1.6, 3.4), 0.3, 0.12, Vector3.UP, 1.3)
	SpellFx.shell(at + Vector3.UP * 0.7, 0.3, SHOCK_R, Color(0.8, 0.9, 2.6), 0.25)
	Vfx.burst(at + Vector3.UP * 0.15, Color(0.1, 0.09, 0.12, 0.8), {"count": 14, "life": 0.6, "speed": Vector2(2.0, 4.5), "size": 0.3, "gravity": 0.3, "damping": 4.0, "additive": false, "dir": Vector3.UP, "spread": 85.0})
	StaffSfx.play("step_shock", at, -2.0 if n > 0 else -7.0)


## Briar Antler: everything within 1.4 m of the step's line is rooted in brambles for 2 s (the same
## metas as the Thorn Heart's Briar bolt, so the slows never fight).
func _briar_path(p: Player, from: Vector3, to: Vector3) -> void:
	var a := from + Vector3.UP
	var b := to + Vector3.UP
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var c := e.global_position + Vector3.UP
		if c.distance_to(Geometry3D.get_closest_point_to_segment(c, a, b)) > 1.4:
			continue
		if not e.has_meta(&"briar_base"):
			e.set_meta(&"briar_base", e.walk_speed)
		e.walk_speed = float(e.get_meta(&"briar_base")) * 0.45
		e.set_meta(&"briar_until", Time.get_ticks_msec() + 2000)
		Vfx.ring(e.global_position + Vector3.UP * 0.06, 0.9, Color(2.0, 0.3, 0.25), 0.5, 0.06, Vector3.UP, 1.0)
		var eid := e.get_instance_id()
		e.get_tree().create_timer(2.05, false).timeout.connect(func() -> void:
			var e2 := instance_from_id(eid) as Enemy
			if e2 != null and int(e2.get_meta(&"briar_until", 0)) <= Time.get_ticks_msec():
				e2.walk_speed = float(e2.get_meta(&"briar_base", e2.walk_speed)))
