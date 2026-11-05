extends Node3D
## Lantern Ward add-ons bought at the Kindling (progression), parented to the planted ward:
##  pulse   (rank I, Long Wick): every PULSE s a warm ring runs out to the edge and throws foes
##          standing near it back out of the light.
##  kindred (rank II, Close Watch): while the wanderer stands in the light, the other spells
##          recover 30% faster (SkillBook.boost_until), and embers rise off the wanderer.
##  mirror  (rank III, Mirror Flame): spit that reaches the light pops and a bolt of flame strikes
##          the nearest spitter (else the nearest enemy) for 1 x spell power and a Mark.
##  bramble (Thorn Heart rite, Bramble Ward): an enemy inside the light is rooted (45 % speed,
##          the same metas as the Briar bolt, so the two never fight) and Marked once.

const RADIUS := 7.0                 ## LanternWard.RADIUS
const DB := preload("res://core/life/progression/upgrade_db.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const PULSE := 2.0
const PULSE_BAND := 3.0             ## foes this far inside the edge (and 1 m out) are thrown

var pulse := false
var kindred := false
var book: SkillBook
var pulses := 0                     ## tests
var mirror := false
var bramble := false
var _pulse_t := 1.0
var _kin_fx := 0.0
var life := 7.0
var _t := 0.0
var _rooted := {}
var _root_cd := 0.0


func _ready() -> void:
	if bramble:
		Vfx.ring(global_position + Vector3.UP * 0.08, RADIUS, Color(2.0, 0.3, 0.25), 0.8, 0.1, Vector3.UP, 1.2)
		var thorns := Vfx.emitter(Color(0.45, 0.07, 0.06), {"count": 40, "life": 1.4, "speed": Vector2(0.2, 0.7), "size": 0.08, "gravity": 0.6, "ring": RADIUS * 0.95, "additive": false})
		add_child(thorns)
		thorns.emitting = true


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > life:
		return
	var at := global_position
	if pulse:
		_pulse_t -= delta
		if _pulse_t <= 0.0:
			_pulse_t = PULSE
			_pulse(at)
	if kindred and book != null and is_instance_valid(book) and book.player != null:
		var pd := book.player.global_position - at
		if Vector2(pd.x, pd.z).length() <= RADIUS and absf(pd.y) < 3.0:
			book.boost_until = Time.get_ticks_msec() * 0.001 + 0.25
			_kin_fx -= delta
			if _kin_fx <= 0.0:
				_kin_fx = 0.35
				Vfx.burst(book.player.global_position + Vector3.UP * 0.9, Color(2.6, 1.4, 0.5), {"count": 6, "life": 0.7, "speed": Vector2(0.3, 1.0), "size": 0.035, "gravity": 1.6, "radius": 0.35, "trail": 0.05})
	if mirror:
		for node in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
			var shot := node as Node3D
			if shot == null or not shot.has_method("pop"):
				continue
			var d := shot.global_position - at
			if Vector2(d.x, d.z).length() > RADIUS or absf(d.y) > 4.0:
				continue
			var from := shot.global_position
			shot.pop()
			_return_fire(from)
	_root_cd -= delta
	if bramble and _root_cd <= 0.0:
		_root_cd = 0.25
		for node in get_tree().get_nodes_in_group(Groups.ENEMY):
			var e := node as Enemy
			if e == null or not e.is_alive():
				continue
			var d := e.global_position - at
			if Vector2(d.x, d.z).length() > RADIUS or absf(d.y) > 2.5:
				continue
			_root(e)


## Long Wick: a warm ring runs to the edge; foes near the edge are thrown back out.
func _pulse(at: Vector3) -> void:
	pulses += 1
	var hit := 0
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - at
		d.y = 0.0
		var dist := d.length()
		if dist > RADIUS + 1.0 or dist < RADIUS - PULSE_BAND or absf(e.global_position.y - at.y) > 2.5:
			continue
		e.shove(d / maxf(dist, 0.1) * 8.5 * (0.35 if e.boss else 1.0))
		hit += 1
	Vfx.ring(at + Vector3.UP * 0.12, RADIUS, Color(2.8, 1.5, 0.55), 0.55, 0.14, Vector3.UP, 1.3)
	SpellFx.shell(at + Vector3.UP * 0.6, 0.6, RADIUS * 0.95, Color(1.6, 0.8, 0.3), 0.5)
	Vfx.burst(at + Vector3.UP * 0.2, Color(2.6, 1.3, 0.45), {"count": 30, "life": 0.6, "speed": Vector2(0.3, 1.0), "size": 0.045, "gravity": 1.0, "ring": RADIUS * 0.9, "turbulence": true})
	StaffSfx.play("ward_pulse", at + Vector3.UP, -4.0 if hit > 0 else -9.0)


func _return_fire(from: Vector3) -> void:
	var best: Enemy = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var dist := e.global_position.distance_to(from)
		if dist > 24.0:
			continue
		if e is Spitter:
			dist -= 100.0                    # spitters first
		if dist < best_d:
			best_d = dist
			best = e
	Vfx.burst(from, Color(2.6, 1.4, 0.5), {"count": 20, "life": 0.35, "speed": Vector2(2.0, 5.0), "size": 0.04, "gravity": -3.0, "trail": 0.06})
	if best == null:
		return
	var to := best.global_position + Vector3.UP * (best.hp_bar_y * 0.55)
	Vfx.arc(from, to, Color(2.6, 1.3, 0.45), 0.3, 0.3)
	Vfx.burst(to, Color(2.8, 1.5, 0.5), {"count": 24, "life": 0.4, "speed": Vector2(2.0, 6.0), "size": 0.05, "gravity": -4.0, "trail": 0.07})
	best.add_mark(1)
	best.take_hit(1.0 * float(DB.get_mod("power", 1.0)), self)
	HitText.pop(to + Vector3.UP * 0.4, "mirrored", Color(1.0, 0.75, 0.4))


func _root(e: Enemy) -> void:
	if not e.has_meta(&"briar_base"):
		e.set_meta(&"briar_base", e.walk_speed)
	var base: float = e.get_meta(&"briar_base")
	e.walk_speed = base * 0.45
	var until := Time.get_ticks_msec() + 900
	e.set_meta(&"briar_until", until)
	var id := e.get_instance_id()
	if not _rooted.has(id):
		_rooted[id] = true
		e.add_mark(1)
		Vfx.ring(e.global_position + Vector3.UP * 0.06, 0.9, Color(2.0, 0.3, 0.25), 0.5, 0.06, Vector3.UP, 1.0)
		Vfx.burst(e.global_position + Vector3.UP * 0.3, Color(0.5, 0.08, 0.06), {"count": 12, "life": 0.6, "speed": Vector2(0.5, 1.6), "size": 0.06, "gravity": 2.0, "additive": false})
	var eid := e.get_instance_id()
	e.get_tree().create_timer(0.95, false).timeout.connect(func() -> void:
		var e2 := instance_from_id(eid) as Enemy
		if e2 != null and int(e2.get_meta(&"briar_until", 0)) <= Time.get_ticks_msec():
			e2.walk_speed = float(e2.get_meta(&"briar_base", e2.walk_speed)))
