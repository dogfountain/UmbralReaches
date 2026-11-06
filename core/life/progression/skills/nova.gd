extends SkillNova
## Umbral Nova with the Kindling's ranks (progression system).
##   I   Wider Ring: 7.2 m, and an ECHO ring follows 0.5 s later (0.5 damage, another shove).
##   II  Short Wick: recovers in 5.5 s (the runtime sets cooldown); every detonated Mark sends a mote
##       home to you (2 Gloom off each).
##   III Undertow: what the ring catches past 2.5 m is dragged in instead of thrown out.
## Oath of the Tally: 1.5 damage per Mark. Rites: Deep Reliquary (wider Implosion, longer Wake) and
## The Count (each detonated Mark takes 0.6 s off the recovery). A frozen foe SHATTERs (x2); three
## or more Marks at once is a DETONATION.

const CombatState := preload("res://core/skills/combat_state.gd")
const DB := preload("res://core/life/progression/upgrade_db.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const UNDERTOW_MIN := 2.5
const ECHO_DELAY := 0.5
const ECHO_DMG := 0.5
const MOTE_GLOOM := 2.0


func radius() -> float:
	return 7.2 if int(DB.get_mod("nova", 0)) >= 1 else RADIUS


func _implode(p: Player) -> void:
	var pull_r := 13.0 if bool(DB.get_mod("deep", false)) else PULL_R
	var feet := p.global_position
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := feet - e.global_position
		if absf(d.y) > V_REACH:
			continue                          # a floor above or below: the ring does not pass stone
		d.y = 0.0
		var dist := d.length()
		if dist > pull_r or dist < 0.3:
			continue
		e.add_mark(1)
		e.shove(d / dist * PULL * clampf(dist / pull_r + 0.35, 0.0, 1.0) * (pull_r / PULL_R))
	SpellFx.implosion(feet, pull_r)
	p.kick(0.4)
	var pid := p.get_instance_id()
	p.get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
		var p2 := instance_from_id(pid) as Player
		if p2 != null and p2.is_inside_tree():
			_detonate(p2))


func _wake(p: Player) -> void:
	var deep := bool(DB.get_mod("deep", false))
	var w := NovaWake.new()
	p.get_parent().add_child(w)
	w.global_position = p.global_position
	w.setup(radius() * (1.2 if deep else 1.0), 5.0 if deep else WAKE_TIME)


func _detonate(p: Player) -> void:
	var r := radius()
	var book := p.skills()
	var power := float(DB.get_mod("power", 1.0)) * (book.cast_power if book else 1.0)
	var per := (1.5 if bool(DB.get_mod("tally", false)) else 1.0) + float(DB.get_mod("mark_dmg", 0.0))
	var undertow := int(DB.get_mod("nova", 0)) >= 3
	var at := p.global_position + Vector3.UP * 0.9
	var tree := p.get_tree()
	var r2 := r * r
	var detonated: Array = []
	var marks_total := 0
	for node in tree.get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - p.global_position
		if absf(d.y) > V_REACH:
			continue
		d.y = 0.0
		if d.length_squared() > r2:
			continue
		var dist := d.length()
		var away := d / dist if dist > 0.05 else -p.global_basis.z
		var marks := e.take_marks()
		marks_total += marks
		if marks > 0:
			detonated.append(e)
			if int(DB.get_mod("nova", 0)) >= 2:
				_motes(p, e, marks)
		var ring := (1.0 + float(marks) * per) * power * Afflict.shatter(e)
		if book != null and book.combat != null:
			book.combat.deal(e, ring, &"umbral", p)
		else:
			e.take_hit(ring, p)
		if undertow and dist > UNDERTOW_MIN:
			e.shove(-away * minf(SHOVE * 1.1, (dist - 1.6) * 3.2))
			Vfx.arc(e.global_position + Vector3.UP * 0.9, at, Color(1.4, 0.6, 3.0), 0.3, 0.2)
		else:
			e.shove(away * SHOVE * (1.0 - dist / r * 0.5))
	for node in tree.get_nodes_in_group(Groups.SHADE):
		var s := node as Node3D
		if s and s.global_position.distance_squared_to(at) <= r2 * 1.4 and s.has_method("take_hit"):
			s.take_hit(1.0, p)
	for node in tree.get_nodes_in_group(Groups.ENEMY_SHOT):
		var shot := node as Node3D
		if shot and shot.global_position.distance_squared_to(at) <= r2 * 1.6 and shot.has_method("pop"):
			shot.pop()
	p.nova_fx(r, detonated)
	if undertow:
		SpellFx.implosion(p.global_position, r)
	p.kick(1.0)
	if marks_total >= 3:
		Combo.note("DETONATION", p.global_position + Vector3.UP * 2.6, Color(0.85, 0.55, 1.0), "%d Marks" % marks_total)
	if int(DB.get_mod("nova", 0)) >= 1:
		var pid := p.get_instance_id()
		p.get_tree().create_timer(ECHO_DELAY, false).timeout.connect(func() -> void:
			var p2 := instance_from_id(pid) as Player
			if p2 != null and p2.is_inside_tree():
				_echo(p2, r, undertow, power))
	if marks_total > 0 and bool(DB.get_mod("count", false)):
		_count_refund.call_deferred(p, marks_total)


## Wider Ring: a second, fainter ring half a second after the first.
func _echo(p: Player, r: float, undertow: bool, power: float) -> void:
	var feet := p.global_position
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - feet
		if absf(d.y) > V_REACH:
			continue
		d.y = 0.0
		var dist := d.length()
		if dist > r:
			continue
		var away := d / dist if dist > 0.05 else -p.global_basis.z
		e.take_hit(ECHO_DMG * power, p)
		e.shove((-away if undertow and dist > UNDERTOW_MIN else away) * SHOVE * 0.55)
	SpellFx.disc(feet, r, 0, SpellFx.VIOLET * 0.45, SpellFx.VIOLET_HOT * 0.6, 0.6)
	SpellFx.shell(feet + Vector3.UP * 0.9, 0.5, r * 1.05, Color(0.8, 0.35, 2.0), 0.4)
	Vfx.ring(feet + Vector3.UP * 0.1, r, Color(1.6, 0.8, 3.4), 0.45, 0.12, Vector3.UP, 1.4)
	StaffSfx.play("echo", feet + Vector3.UP, -2.0)


## Short Wick: each detonated Mark streams home as a mote and takes MOTE_GLOOM off you.
func _motes(p: Player, e: Enemy, marks: int) -> void:
	var from := e.global_position + Vector3.UP * (e.hp_bar_y * 0.6)
	for k in marks:
		var delay := 0.12 + 0.08 * float(k)
		var pid := p.get_instance_id()
		p.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			var p2 := instance_from_id(pid) as Player
			if p2 == null:
				return
			var to := p2.global_position + Vector3.UP * 1.2
			Vfx.arc(from, to, Color(1.2, 1.4, 3.2), 0.3, 0.12)
			Vfx.burst(to, Color(1.4, 1.5, 3.4), {"count": 8, "life": 0.3, "speed": Vector2(0.5, 1.5), "size": 0.035, "gravity": 0.5, "radius": 0.25})
			StaffSfx.play("mote", to, -6.0, 1.0 + 0.08 * float(k))
			p2.mend(MOTE_GLOOM))                       # r35: a mote mends Wounds


## The Count: after try_cast has set the cooldown, take 0.6 s per detonated Mark off it.
func _count_refund(p: Player, marks: int) -> void:
	if not is_instance_valid(p):
		return
	var book := p.skills()
	var i := book.slots.find(self) if book else -1
	if i < 0:
		return
	book._cd[i] = maxf(0.0, book._cd[i] - 0.6 * float(marks))
	HitText.pop(p.global_position + Vector3.UP * 2.4, "-%.1fs" % (0.6 * float(marks)), Color(0.95, 0.85, 0.55))
